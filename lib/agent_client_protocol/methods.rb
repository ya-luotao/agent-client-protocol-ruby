# frozen_string_literal: true

module AgentClientProtocol
  module Methods
    module_function

    def agent(unstable: false)
      SchemaRegistry.agent_methods(unstable: unstable)
    end

    def client(unstable: false)
      SchemaRegistry.client_methods(unstable: unstable)
    end

    def protocol(unstable: false)
      SchemaRegistry.protocol_methods(unstable: unstable)
    end
  end
end
