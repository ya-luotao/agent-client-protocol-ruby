# frozen_string_literal: true

module AgentClientProtocol
  # Convenience constants for enum-like schema values.
  #
  # Auto-extracted from the JSON Schema at load time so they stay in sync
  # with the canonical definitions. Use them instead of raw strings:
  #
  #   AgentClientProtocol::ToolKind::READ        # => "read"
  #   AgentClientProtocol::ToolCallStatus::FAILED # => "failed"
  #   AgentClientProtocol::StopReason::END_TURN   # => "end_turn"
  #
  module Constants
    # Names already defined elsewhere (e.g. ErrorCode in error.rb).
    SKIP = %w[ErrorCode].freeze

    module_function

    def define_all!(unstable: false)
      defs = SchemaRegistry.defs(unstable: unstable)
      target = unstable ? Unstable : self

      defs.each do |name, schema|
        next if SKIP.include?(name)

        values = extract_enum_values(schema)
        next if values.empty?
        next if target.const_defined?(name, false)

        target.const_set(name, build_constants_module(values))
      end
    end

    def extract_enum_values(schema)
      if schema["enum"].is_a?(Array)
        return schema["enum"].select { |v| v.is_a?(String) || v.is_a?(Integer) }
      end

      variants = schema["oneOf"] || schema["anyOf"]
      return [] unless variants.is_a?(Array)

      consts = variants.filter_map { |v| v["const"] }
      consts.select { |c| c.is_a?(String) || c.is_a?(Integer) }
    end

    def build_constants_module(values)
      mod = Module.new
      values.each do |value|
        mod.const_set(ruby_const_name(value), value.freeze)
      end
      mod.freeze
    end

    def ruby_const_name(value)
      value.to_s
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .tr("-", "_")
        .upcase
    end

    module Unstable
    end
  end

  Constants.define_all!(unstable: false)
  Constants.define_all!(unstable: true)

  # Re-export at the top-level namespace for convenient access.
  %i[
    Role ToolKind ToolCallStatus PlanEntryStatus PlanEntryPriority
    StopReason PermissionOptionKind SessionConfigOptionCategory
  ].each do |name|
    if Constants.const_defined?(name, false)
      const_set(name, Constants.const_get(name, false)) unless const_defined?(name, false)
    end
  end
end
