# frozen_string_literal: true

require "json"

module AgentClientProtocol
  class SchemaRegistry
    ROOT = File.expand_path("../..", __dir__)
    STABLE_SCHEMA_PATH = File.join(ROOT, "schema", "schema.json")
    UNSTABLE_SCHEMA_PATH = File.join(ROOT, "schema", "schema.unstable.json")
    STABLE_META_PATH = File.join(ROOT, "schema", "meta.json")
    UNSTABLE_META_PATH = File.join(ROOT, "schema", "meta.unstable.json")

    class << self
      def stable_schema
        @stable_schema ||= load_json(STABLE_SCHEMA_PATH)
      end

      def unstable_schema
        @unstable_schema ||= load_json(UNSTABLE_SCHEMA_PATH)
      end

      def stable_meta
        @stable_meta ||= symbolize_keys(load_json(STABLE_META_PATH))
      end

      def unstable_meta
        @unstable_meta ||= symbolize_keys(load_json(UNSTABLE_META_PATH))
      end

      def defs(unstable: false)
        schema = unstable ? unstable_schema : stable_schema
        schema.fetch("$defs")
      end

      def method_catalog(unstable: false)
        key = unstable ? :unstable : :stable
        @method_catalog ||= {}
        @method_catalog[key] ||= build_method_catalog(defs(unstable: unstable))
      end

      def agent_methods(unstable: false)
        meta = unstable ? unstable_meta : stable_meta
        (meta[:agentMethods] || {}).dup
      end

      def client_methods(unstable: false)
        meta = unstable ? unstable_meta : stable_meta
        (meta[:clientMethods] || {}).dup
      end

      def protocol_methods(unstable: false)
        meta = unstable ? unstable_meta : stable_meta
        (meta[:protocolMethods] || {}).dup
      end

      def schema_for(definition_name, unstable: false)
        defs(unstable: unstable).fetch(definition_name)
      end

      private

      def load_json(path)
        JSON.parse(File.read(path))
      end

      def build_method_catalog(definitions)
        catalog = Hash.new { |h, side| h[side] = {} }

        definitions.each do |definition_name, schema|
          side = schema["x-side"]
          method = schema["x-method"]
          next if side.nil? || method.nil?

          kind = infer_kind(definition_name)
          next if kind.nil?

          side_key = side.to_sym
          method_entry = catalog[side_key][method] ||= {}
          method_entry[kind] = definition_name
        end

        catalog.each_value do |methods|
          methods.each_value(&:freeze)
          methods.freeze
        end

        catalog.freeze
      end

      def infer_kind(definition_name)
        return :request if definition_name.end_with?("Request")
        return :response if definition_name.end_with?("Response")
        return :notification if definition_name.end_with?("Notification")

        nil
      end

      def symbolize_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(k, v), result|
            result[k.to_sym] = symbolize_keys(v)
          end
        when Array
          value.map { |item| symbolize_keys(item) }
        else
          value
        end
      end
    end
  end
end
