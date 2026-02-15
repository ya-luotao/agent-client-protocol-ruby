# frozen_string_literal: true

module AgentClientProtocol
  class Decoder
    DecodedPayload = Struct.new(
      :kind,
      :side,
      :method,
      :id,
      :schema_name,
      :payload,
      :typed_payload,
      :extension,
      keyword_init: true
    ) do
      def extension?
        extension
      end

      def typed?
        !typed_payload.nil?
      end

      def to_h
        {
          kind: kind,
          side: side,
          method: method,
          id: id,
          schema_name: schema_name,
          payload: payload,
          typed_payload: typed_payload,
          extension: extension
        }
      end
    end

    VALID_SIDES = %i[agent client protocol].freeze

    attr_reader :side, :unstable, :validate_schema

    def initialize(side:, unstable: false, validate_schema: true)
      normalized_side = side.to_sym
      unless VALID_SIDES.include?(normalized_side)
        raise ArgumentError, "side must be one of: #{VALID_SIDES.join(', ')}"
      end

      @side = normalized_side
      @unstable = unstable
      @validate_schema = validate_schema
      @catalog = SchemaRegistry.method_catalog(unstable: unstable).fetch(normalized_side, {})
    end

    def decode_request(method:, params:)
      decode(kind: :request, method: method, payload: params, require_payload: true)
    end

    def decode_notification(method:, params:)
      decode(kind: :notification, method: method, payload: params, require_payload: true)
    end

    def decode_response(method:, result:)
      decode(kind: :response, method: method, payload: result, require_payload: false)
    end

    private

    def decode(kind:, method:, payload:, require_payload:)
      method_name = String(method)

      if extension_method?(method_name)
        return DecodedPayload.new(
          kind: kind,
          side: side,
          method: method_name,
          id: nil,
          schema_name: extension_schema_name(kind),
          payload: payload,
          typed_payload: nil,
          extension: true
        )
      end

      schema_name = @catalog.dig(method_name, kind)
      raise Error.method_not_found("unknown #{kind} method: #{method_name}") if schema_name.nil?

      if require_payload && payload.nil?
        raise Error.invalid_params("#{kind} #{method_name} requires params")
      end

      validate_payload_schema(schema_name, payload) if validate_schema

      DecodedPayload.new(
        kind: kind,
        side: side,
        method: method_name,
        id: nil,
        schema_name: schema_name,
        payload: payload,
        typed_payload: build_typed_payload(schema_name, payload),
        extension: false
      )
    end

    def extension_method?(method_name)
      method_name.start_with?("_")
    end

    def extension_schema_name(kind)
      case kind
      when :request
        "ExtRequest"
      when :response
        "ExtResponse"
      when :notification
        "ExtNotification"
      else
        raise ArgumentError, "unsupported kind: #{kind}"
      end
    end

    def validate_payload_schema(schema_name, payload)
      Validator.validate(schema_name, payload, unstable: unstable)
    end

    def build_typed_payload(schema_name, payload)
      TypeRegistry.build(schema_name, payload, unstable: unstable)
    rescue StandardError => e
      raise e if e.is_a?(Error)

      raise Error.invalid_params("invalid payload for #{schema_name}: #{e.message}")
    end
  end
end
