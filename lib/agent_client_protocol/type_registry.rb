# frozen_string_literal: true

module AgentClientProtocol
  module Types
    module Unstable
    end
  end

  class TypeRegistry
    class << self
      def fetch(definition_name, unstable: false)
        ensure_loaded!(unstable: unstable)
        namespace = unstable ? Types::Unstable : Types
        return nil unless namespace.const_defined?(definition_name, false)

        namespace.const_get(definition_name, false)
      end

      def all(unstable: false)
        ensure_loaded!(unstable: unstable)
        namespace = unstable ? Types::Unstable : Types

        namespace.constants(false).sort.each_with_object({}) do |const_name, acc|
          klass = namespace.const_get(const_name, false)
          next unless klass.is_a?(Class)
          next unless klass.respond_to?(:definition_name)
          next if klass.definition_name.nil?

          acc[const_name.to_s] = klass
        end
      end

      def build(definition_name, payload, unstable: false)
        klass = fetch(definition_name, unstable: unstable)
        return payload if klass.nil?

        klass.coerce(payload)
      end

      private

      def ensure_loaded!(unstable: false)
        key = unstable ? :unstable : :stable
        @loaded ||= {}
        return if @loaded[key]

        namespace = unstable ? Types::Unstable : Types
        definitions = SchemaRegistry.defs(unstable: unstable)
        build_types!(namespace, definitions, unstable: unstable)

        @loaded[key] = true
      end

      def build_types!(namespace, definitions, unstable:)
        definitions.each do |definition_name, schema|
          next if namespace.const_defined?(definition_name, false)

          parent = object_schema?(schema) ? Types::Base : Types::Scalar
          klass = Class.new(parent)
          if parent == Types::Scalar
            klass.configure(
              definition_name: definition_name,
              schema: schema,
              unstable: unstable,
              coercer: scalar_coercer_for(definition_name)
            )
          else
            klass.configure(
              definition_name: definition_name,
              schema: schema,
              unstable: unstable
            )
          end

          namespace.const_set(definition_name, klass)
        end
      end

      def object_schema?(schema)
        schema["type"] == "object" || schema.key?("properties")
      end

      def scalar_coercer_for(definition_name)
        case definition_name
        when "ProtocolVersion"
          lambda { |value| ::AgentClientProtocol::ProtocolVersion.parse(value).to_i }
        else
          nil
        end
      end
    end
  end
end
