# frozen_string_literal: true

require_relative "lib/agent_client_protocol/version"

Gem::Specification.new do |spec|
  spec.name          = "agent-client-protocol"
  spec.version       = AgentClientProtocol::VERSION
  spec.authors       = ["Agent Client Protocol"]
  spec.email         = ["hi@zed.dev"]

  spec.summary       = "Ruby schema/runtime helpers for the Agent Client Protocol (ACP)"
  spec.description   = "JSON-RPC message models, method constants, protocol version handling, and side-aware decode helpers for ACP."
  spec.homepage      = "https://github.com/agentclientprotocol/agent-client-protocol"
  spec.license       = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir[
    "lib/**/*.rb",
    "schema/*.json",
    "README.md",
    "LICENSE"
  ]

  spec.require_paths = ["lib"]

  spec.metadata["source_code_uri"] = "https://github.com/agentclientprotocol/agent-client-protocol"
  spec.metadata["homepage_uri"] = "https://agentclientprotocol.com"
end
