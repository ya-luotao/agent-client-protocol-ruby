# frozen_string_literal: true

module AgentClientProtocol
  class Validator
    class ValidationError < StandardError
      attr_reader :path

      def initialize(path, message)
        @path = path
        super(message)
      end
    end

    class << self
      def validate(definition_name, payload, unstable: false)
        definitions = SchemaRegistry.defs(unstable: unstable)
        definition_key = definition_name.to_s
        schema = definitions.fetch(definition_key) do
          raise ValidationError.new("$", "unknown schema definition #{definition_key}")
        end

        validate_schema(schema, payload, definitions, "$")
        true
      rescue ValidationError => e
        raise Error.invalid_params("invalid payload for #{definition_name} at #{e.path}: #{e.message}")
      end

      private

      def validate_schema(schema, value, definitions, path)
        return if schema.nil? || schema == true
        raise ValidationError.new(path, "value is not allowed") if schema == false
        raise ValidationError.new(path, "invalid schema node") unless schema.is_a?(Hash)

        if (ref = schema["$ref"])
          validate_schema(resolve_ref(ref, definitions, path), value, definitions, path)
        end

        return if protocol_version_legacy_string?(schema, value, definitions)

        validate_type(schema["type"], value, path) if schema.key?("type")
        validate_format(schema["format"], value, path) if schema.key?("format")
        validate_enum(schema["enum"], value, path) if schema.key?("enum")
        validate_const(schema["const"], value, path) if schema.key?("const")
        validate_numeric_bounds(schema, value, path)
        validate_string_bounds(schema, value, path)
        validate_array_bounds(schema, value, path)

        validate_object(schema, value, definitions, path)
        validate_items(schema["items"], value, definitions, path) if schema.key?("items")

        validate_all_of(schema["allOf"], value, definitions, path) if schema["allOf"].is_a?(Array)
        validate_any_of(schema["anyOf"], value, definitions, path) if schema["anyOf"].is_a?(Array)
        validate_one_of(schema["oneOf"], value, definitions, path) if schema["oneOf"].is_a?(Array)
      end

      def resolve_ref(ref, definitions, path)
        match = ref.to_s.match(%r{\A#/\$defs/([^/]+)\z})
        raise ValidationError.new(path, "unsupported $ref #{ref.inspect}") if match.nil?

        definition_key = match[1]
        definitions.fetch(definition_key) do
          raise ValidationError.new(path, "unknown $ref #{ref}")
        end
      end

      def validate_type(type_spec, value, path)
        types = Array(type_spec).map(&:to_s)
        return if types.any? { |type| type_match?(type, value) }

        raise ValidationError.new(path, "expected #{types.join(' or ')}, got #{json_type(value)}")
      end

      def type_match?(type, value)
        case type
        when "null"
          value.nil?
        when "boolean"
          value == true || value == false
        when "string"
          value.is_a?(String)
        when "integer"
          value.is_a?(Integer)
        when "number"
          value.is_a?(Numeric)
        when "object"
          value.is_a?(Hash)
        when "array"
          value.is_a?(Array)
        else
          false
        end
      end

      def json_type(value)
        case value
        when nil
          "null"
        when Hash
          "object"
        when Array
          "array"
        when String
          "string"
        when Integer
          "integer"
        when Numeric
          "number"
        when TrueClass, FalseClass
          "boolean"
        else
          value.class.name
        end
      end

      def validate_enum(options, value, path)
        return if options.include?(value)

        raise ValidationError.new(path, "must be one of #{options.inspect}")
      end

      def validate_const(expected, value, path)
        return if value == expected

        raise ValidationError.new(path, "must be #{expected.inspect}")
      end

      def validate_format(format, value, path)
        case format
        when "int32"
          validate_integer_range(value, path, -(2**31), (2**31) - 1)
        when "uint32"
          validate_integer_range(value, path, 0, (2**32) - 1)
        when "int64"
          validate_integer_range(value, path, -(2**63), (2**63) - 1)
        when "uint64"
          validate_integer_range(value, path, 0, (2**64) - 1)
        when "uint16"
          validate_integer_range(value, path, 0, 65_535)
        when "double"
          unless value.is_a?(Numeric)
            raise ValidationError.new(path, "must be a number for format double")
          end
        end
      end

      def validate_integer_range(value, path, min, max)
        return unless value.is_a?(Integer)
        return if value >= min && value <= max

        raise ValidationError.new(path, "must be between #{min} and #{max}")
      end

      def validate_numeric_bounds(schema, value, path)
        return unless value.is_a?(Numeric)

        if schema.key?("minimum") && value < schema["minimum"]
          raise ValidationError.new(path, "must be >= #{schema['minimum']}")
        end
        if schema.key?("maximum") && value > schema["maximum"]
          raise ValidationError.new(path, "must be <= #{schema['maximum']}")
        end
      end

      def validate_string_bounds(schema, value, path)
        return unless value.is_a?(String)

        if schema.key?("minLength") && value.length < schema["minLength"]
          raise ValidationError.new(path, "length must be >= #{schema['minLength']}")
        end
        if schema.key?("maxLength") && value.length > schema["maxLength"]
          raise ValidationError.new(path, "length must be <= #{schema['maxLength']}")
        end
      end

      def validate_array_bounds(schema, value, path)
        return unless value.is_a?(Array)

        if schema.key?("minItems") && value.length < schema["minItems"]
          raise ValidationError.new(path, "item count must be >= #{schema['minItems']}")
        end
        if schema.key?("maxItems") && value.length > schema["maxItems"]
          raise ValidationError.new(path, "item count must be <= #{schema['maxItems']}")
        end
      end

      def validate_object(schema, value, definitions, path)
        return unless value.is_a?(Hash)

        required = Array(schema["required"])
        properties = schema["properties"].is_a?(Hash) ? schema["properties"] : {}
        additional = schema.key?("additionalProperties") ? schema["additionalProperties"] : true
        object = value.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }

        required.each do |key|
          next if object.key?(key)

          raise ValidationError.new(path_for_key(path, key), "is required")
        end

        object.each do |key, nested_value|
          nested_path = path_for_key(path, key)
          if properties.key?(key)
            validate_schema(properties[key], nested_value, definitions, nested_path)
            next
          end

          if additional == false
            raise ValidationError.new(nested_path, "additional property is not allowed")
          end

          validate_schema(additional, nested_value, definitions, nested_path) if additional.is_a?(Hash)
        end
      end

      def validate_items(items_schema, value, definitions, path)
        return unless value.is_a?(Array)

        case items_schema
        when Array
          items_schema.each_with_index do |item_schema, index|
            break if index >= value.length

            validate_schema(item_schema, value[index], definitions, "#{path}[#{index}]")
          end
        else
          value.each_with_index do |item, index|
            validate_schema(items_schema, item, definitions, "#{path}[#{index}]")
          end
        end
      end

      def validate_all_of(schemas, value, definitions, path)
        schemas.each do |sub_schema|
          validate_schema(sub_schema, value, definitions, path)
        end
      end

      def validate_any_of(schemas, value, definitions, path)
        errors = []
        schemas.each do |sub_schema|
          validate_schema(sub_schema, value, definitions, path)
          return
        rescue ValidationError => e
          errors << e
        end

        closest = closest_error(errors, path)
        raise ValidationError.new(
          path,
          "must match anyOf (closest mismatch at #{closest.path}: #{closest.message})"
        )
      end

      def validate_one_of(schemas, value, definitions, path)
        matches = 0
        errors = []

        schemas.each do |sub_schema|
          validate_schema(sub_schema, value, definitions, path)
          matches += 1
        rescue ValidationError => e
          errors << e
        end

        return if matches == 1

        if matches.zero?
          closest = closest_error(errors, path)
          raise ValidationError.new(
            path,
            "must match exactly one schema in oneOf (closest mismatch at #{closest.path}: #{closest.message})"
          )
        end

        raise ValidationError.new(path, "must match exactly one schema in oneOf (matched #{matches})")
      end

      def closest_error(errors, path)
        errors.max_by { |error| error.path.length } || ValidationError.new(path, "is invalid")
      end

      def path_for_key(path, key)
        key = key.to_s
        return "#{path}.#{key}" if key.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/)

        "#{path}[#{key.inspect}]"
      end

      def protocol_version_legacy_string?(schema, value, definitions)
        return false unless value.is_a?(String)

        protocol_version_schema = definitions["ProtocolVersion"]
        return false if protocol_version_schema.nil?

        schema.equal?(protocol_version_schema) || schema == protocol_version_schema
      end
    end
  end
end
