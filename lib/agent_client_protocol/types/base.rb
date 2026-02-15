# frozen_string_literal: true
require "json"
require "set"

module AgentClientProtocol
  module Types
    class Base
      class << self
        attr_reader :definition_name, :schema, :properties, :required_keys, :ruby_property_map, :ruby_to_json_property_map,
                    :additional_properties, :property_schemas, :unstable

        def configure(definition_name:, schema:, unstable: false)
          @definition_name = definition_name
          @schema = schema
          @unstable = unstable

          @properties = (schema["properties"] || {}).keys.freeze
          @property_schemas = (schema["properties"] || {}).freeze
          @required_keys = (schema["required"] || []).freeze
          @additional_properties = schema["additionalProperties"]
          @ruby_property_map = build_ruby_property_map(@properties)
          @ruby_to_json_property_map = @ruby_property_map.each_with_object({}) do |(json_key, ruby_key), acc|
            acc[ruby_key.to_s] = json_key
          end.freeze

          define_property_readers!
          freeze
        end

        def coerce(value)
          return value if value.is_a?(self)

          new(value)
        end

        def build(attributes = nil, **kwargs)
          if attributes && !kwargs.empty?
            raise ArgumentError, "pass either attributes Hash or keyword args, not both"
          end

          payload = attributes || kwargs
          new(payload)
        end

        private

        def build_ruby_property_map(property_names)
          reserved = instance_methods.map(&:to_s).to_set
          mapping = {}

          property_names.each do |json_key|
            candidate = ruby_identifier_for(json_key)
            candidate = "field" if candidate.empty?
            candidate = "_#{candidate}" if candidate.match?(/\A\d/)

            while reserved.include?(candidate)
              candidate = "#{candidate}_field"
            end

            reserved.add(candidate)
            mapping[json_key] = candidate.to_sym
          end

          mapping.freeze
        end

        def ruby_identifier_for(json_key)
          sanitized = json_key.to_s.sub(/\A_+/, "")
          step_one = sanitized.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
          step_two = step_one.gsub(/([a-z\d])([A-Z])/, '\1_\2')
          step_two.tr("-", "_").downcase
        end

        def define_property_readers!
          @ruby_property_map.each do |json_key, ruby_key|
            next if method_defined?(ruby_key)

            define_method(ruby_key) do
              @attributes[json_key]
            end
          end
        end
      end

      def initialize(attributes = nil)
        unless attributes.nil? || attributes.is_a?(Hash)
          raise ArgumentError, "#{self.class.definition_name} expects a Hash payload"
        end

        attributes ||= {}
        normalized = normalize_attributes(attributes)

        missing = self.class.required_keys.reject { |key| normalized.key?(key) }
        unless missing.empty?
          raise ::AgentClientProtocol::Error.invalid_params(
            "#{self.class.definition_name} missing required keys: #{missing.join(', ')}"
          )
        end

        if self.class.additional_properties == false
          unknown_keys = normalized.keys - self.class.properties
          unless unknown_keys.empty?
            raise ::AgentClientProtocol::Error.invalid_params(
              "#{self.class.definition_name} unknown keys: #{unknown_keys.join(', ')}"
            )
          end
        end

        @attributes = normalized.freeze
        freeze
      end

      def [](key)
        json_key = self.class.ruby_to_json_property_map[key.to_s] || key.to_s
        @attributes[json_key]
      end

      def fetch(key, *args)
        json_key = self.class.ruby_to_json_property_map[key.to_s] || key.to_s
        @attributes.fetch(json_key, *args)
      end

      def key?(key)
        json_key = self.class.ruby_to_json_property_map[key.to_s] || key.to_s
        @attributes.key?(json_key)
      end

      def to_h
        deep_to_h(@attributes)
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def ==(other)
        other.is_a?(self.class) && other.to_h == to_h
      end

      alias eql? ==

      def hash
        [self.class, @attributes].hash
      end

      private

      def normalize_attributes(attributes)
        attributes.each_with_object({}) do |(k, v), acc|
          key = normalize_input_key(k)
          schema = self.class.property_schemas[key]
          acc[key] = normalize_input_value(v, schema)
        end
      end

      def normalize_input_key(key)
        key_str = key.to_s
        return key_str if self.class.properties.include?(key_str)

        self.class.ruby_to_json_property_map[key_str] || key_str
      end

      def normalize_input_value(value, schema = nil)
        return self.class.coerce_for_schema(value, schema, unstable: self.class.unstable) unless schema.nil?

        if value.is_a?(Base) || value.is_a?(Scalar)
          value
        elsif value.is_a?(Hash)
          value.transform_keys(&:to_s).transform_values { |nested| normalize_input_value(nested) }
        elsif value.is_a?(Array)
          value.map { |item| normalize_input_value(item) }
        else
          value
        end
      end

      def deep_to_h(value)
        case value
        when Base
          value.to_h
        when Scalar
          value.to_h
        when Hash
          value.each_with_object({}) do |(k, v), acc|
            acc[k] = deep_to_h(v)
          end
        when Array
          value.map { |item| deep_to_h(item) }
        else
          value
        end
      end

      class << self
        def coerce_for_schema(value, schema, unstable:)
          return value if schema.nil?

          if schema["$ref"]
            return coerce_ref(value, schema["$ref"], unstable: unstable)
          end

          if schema["type"] == "array" && value.is_a?(Array)
            item_schema = schema["items"]
            return value.map { |item| coerce_for_schema(item, item_schema, unstable: unstable) }
          end

          if schema["type"] == "object" && value.is_a?(Hash)
            inline_properties = schema["properties"] || {}
            normalized = value.transform_keys(&:to_s)
            return normalized.each_with_object({}) do |(k, v), acc|
              acc[k] = coerce_for_schema(v, inline_properties[k], unstable: unstable)
            end
          end

          if schema["anyOf"].is_a?(Array)
            return coerce_union(value, schema["anyOf"], unstable: unstable)
          end

          if schema["oneOf"].is_a?(Array)
            return coerce_union(value, schema["oneOf"], unstable: unstable)
          end

          if schema["allOf"].is_a?(Array)
            return schema["allOf"].reduce(value) do |memo, sub_schema|
              coerce_for_schema(memo, sub_schema, unstable: unstable)
            end
          end

          value
        end

        private

        def coerce_ref(value, ref, unstable:)
          definition_name = parse_ref_definition(ref)
          return value if definition_name.nil?

          klass = ::AgentClientProtocol::TypeRegistry.fetch(definition_name, unstable: unstable)
          return value if klass.nil?

          klass.coerce(value)
        end

        def coerce_union(value, schemas, unstable:)
          return nil if value.nil? && schemas.any? { |s| s["type"] == "null" }

          schemas.each do |sub_schema|
            next if sub_schema["type"] == "null"

            coerced = coerce_for_schema(value, sub_schema, unstable: unstable)
            return coerced unless coerced.equal?(value)
          rescue StandardError
            next
          end

          value
        end

        def parse_ref_definition(ref)
          match = ref.match(%r{\A#/\$defs/([^/]+)\z})
          return nil if match.nil?

          match[1]
        end
      end
    end

    class Scalar
      class << self
        attr_reader :definition_name, :schema, :unstable, :coercer

        def configure(definition_name:, schema:, unstable: false, coercer: nil)
          @definition_name = definition_name
          @schema = schema
          @unstable = unstable
          @coercer = coercer
          freeze
        end

        def coerce(value)
          return value if value.is_a?(self)

          normalized = coercer.nil? ? value : coercer.call(value)
          new(normalized)
        end
      end

      attr_reader :value

      def initialize(value)
        @value = value
        freeze
      end

      def to_h
        value
      end

      def to_json(*args)
        value.to_json(*args)
      end

      def ==(other)
        other.is_a?(self.class) && other.value == value
      end

      alias eql? ==

      def hash
        [self.class, value].hash
      end
    end
  end
end
