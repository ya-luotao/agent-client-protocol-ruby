# frozen_string_literal: true

require_relative "test_helper"

class RpcTest < Minitest::Test
  def test_parses_request_message
    parsed = AgentClientProtocol::RPC.parse(
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => { "protocolVersion" => 1 }
    )

    assert_instance_of AgentClientProtocol::RPC::Request, parsed
    assert_equal 1, parsed.id
    assert_equal "initialize", parsed.method
  end

  def test_parses_notification_message
    parsed = AgentClientProtocol::RPC.parse(
      "jsonrpc" => "2.0",
      "method" => "session/update",
      "params" => { "sessionId" => "s1" }
    )

    assert_instance_of AgentClientProtocol::RPC::Notification, parsed
  end

  def test_round_trips_error_response
    err = AgentClientProtocol::Error.invalid_params("bad")
    response = AgentClientProtocol::RPC::Response.new(id: "abc", error: err)

    serialized = response.to_h
    parsed = AgentClientProtocol::RPC.parse(serialized)

    assert_instance_of AgentClientProtocol::RPC::Response, parsed
    assert parsed.failure?
    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, parsed.error.code
  end
end
