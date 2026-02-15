# frozen_string_literal: true

require_relative "test_helper"

class MethodsTest < Minitest::Test
  def test_stable_agent_methods_match_schema_meta
    assert_equal "initialize", AgentClientProtocol::AGENT_METHOD_NAMES[:initialize]
    assert_equal "session/prompt", AgentClientProtocol::AGENT_METHOD_NAMES[:session_prompt]
  end

  def test_stable_client_methods_match_schema_meta
    assert_equal "session/update", AgentClientProtocol::CLIENT_METHOD_NAMES[:session_update]
    assert_equal "terminal/create", AgentClientProtocol::CLIENT_METHOD_NAMES[:terminal_create]
  end

  def test_unstable_methods_include_protocol_extensions
    assert_equal "session/list", AgentClientProtocol::UNSTABLE_AGENT_METHOD_NAMES[:session_list]
    assert_equal "$/cancel_request", AgentClientProtocol::PROTOCOL_METHOD_NAMES[:cancel_request]
  end
end
