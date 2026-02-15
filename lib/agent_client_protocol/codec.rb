# frozen_string_literal: true

module AgentClientProtocol
  class Codec
    attr_reader :side, :unstable

    def initialize(side:, unstable: false, validate_schema: true)
      @decoder = Decoder.new(side: side, unstable: unstable, validate_schema: validate_schema)
      @protocol_decoder = Decoder.new(side: :protocol, unstable: unstable, validate_schema: validate_schema)
      @side = @decoder.side
      @unstable = @decoder.unstable
    end

    def decode_rpc(message)
      parsed = parse_message(message)

      case parsed
      when RPC::Request
        decoded = @decoder.decode_request(method: parsed.method, params: parsed.params)
        decoded.id = parsed.id
        decoded
      when RPC::Notification
        decode_notification(parsed)
      when RPC::Response
        parsed
      else
        raise Error.invalid_request("unsupported rpc message")
      end
    end

    def decode_response_for(method:, message:)
      response = parse_response(message)
      return response if response.failure?

      decoded = @decoder.decode_response(method: method, result: response.result)
      RPC::Response.new(id: response.id, result: decoded.typed_payload || decoded.payload)
    end

    def encode_request(method:, id:, params:)
      payload = serialize_payload(params)
      decoded = @decoder.decode_request(method: method, params: payload)
      encoded_params = decoded.typed_payload.nil? ? payload : decoded.typed_payload.to_h
      RPC::Request.new(id: id, method: method, params: encoded_params).to_h
    end

    def encode_notification(method:, params:)
      payload = serialize_payload(params)
      decoded = notification_decoder_for(method).decode_notification(method: method, params: payload)
      encoded_params = decoded.typed_payload.nil? ? payload : decoded.typed_payload.to_h
      RPC::Notification.new(method: method, params: encoded_params).to_h
    end

    def encode_result(id:, method:, result:)
      payload = serialize_payload(result)
      decoded = @decoder.decode_response(method: method, result: payload)
      encoded_result = decoded.typed_payload.nil? ? payload : decoded.typed_payload.to_h
      RPC::Response.new(id: id, result: encoded_result).to_h
    end

    def encode_error(id:, error:)
      RPC::Response.new(id: id, error: normalize_error(error)).to_h
    end

    private

    def parse_message(message)
      return message if message.is_a?(RPC::Request) || message.is_a?(RPC::Notification) || message.is_a?(RPC::Response)

      RPC.parse(message)
    end

    def parse_response(message)
      parsed = parse_message(message)
      return parsed if parsed.is_a?(RPC::Response)

      raise Error.invalid_request("message is not a response")
    end

    def decode_notification(parsed_notification)
      decoder = notification_decoder_for(parsed_notification.method)
      decoded = decoder.decode_notification(
        method: parsed_notification.method,
        params: parsed_notification.params
      )
      decoded.id = nil
      decoded
    rescue Error => e
      if parsed_notification.method.start_with?("$/") && e.code == ErrorCode::METHOD_NOT_FOUND
        # Protocol-level notifications are implementation-dependent and may be ignored.
        return parsed_notification
      end

      raise
    end

    def notification_decoder_for(method)
      method.to_s.start_with?("$/") ? @protocol_decoder : @decoder
    end

    def serialize_payload(payload)
      payload.respond_to?(:to_h) ? payload.to_h : payload
    end

    def normalize_error(error)
      return error if error.is_a?(Error)
      return Error.from_h(error) if error.is_a?(Hash)

      raise ArgumentError, "error must be an AgentClientProtocol::Error or a Hash"
    end
  end
end
