# frozen_string_literal: true

require_relative "agent_client_protocol/version"
require_relative "agent_client_protocol/protocol_version"
require_relative "agent_client_protocol/error"
require_relative "agent_client_protocol/schema_registry"
require_relative "agent_client_protocol/methods"
require_relative "agent_client_protocol/types"
require_relative "agent_client_protocol/type_registry"
require_relative "agent_client_protocol/validator"
require_relative "agent_client_protocol/rpc"
require_relative "agent_client_protocol/decoder"
require_relative "agent_client_protocol/codec"

module AgentClientProtocol
  AGENT_METHOD_NAMES = Methods.agent.freeze
  CLIENT_METHOD_NAMES = Methods.client.freeze

  UNSTABLE_AGENT_METHOD_NAMES = Methods.agent(unstable: true).freeze
  UNSTABLE_CLIENT_METHOD_NAMES = Methods.client(unstable: true).freeze
  PROTOCOL_METHOD_NAMES = Methods.protocol(unstable: true).freeze

  module_function

  def type_for(definition_name, unstable: false)
    TypeRegistry.fetch(definition_name, unstable: unstable)
  end

  def build_typed(definition_name, payload, unstable: false)
    TypeRegistry.build(definition_name, payload, unstable: unstable)
  end

  def validate(definition_name, payload, unstable: false)
    Validator.validate(definition_name, payload, unstable: unstable)
  end

  def codec(side:, unstable: false, validate_schema: true)
    Codec.new(side: side, unstable: unstable, validate_schema: validate_schema)
  end
end
