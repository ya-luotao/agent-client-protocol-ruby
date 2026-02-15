# frozen_string_literal: true

require_relative "test_helper"

class DecoderTest < Minitest::Test
  def test_decodes_agent_side_request
    decoder = AgentClientProtocol::Decoder.new(side: :agent)
    decoded = decoder.decode_request(method: "initialize", params: { "protocolVersion" => 1 })

    assert_equal :request, decoded.kind
    assert_equal "InitializeRequest", decoded.schema_name
    assert_instance_of AgentClientProtocol.type_for("InitializeRequest"), decoded.typed_payload
    assert_instance_of AgentClientProtocol.type_for("ProtocolVersion"), decoded.typed_payload.protocol_version
    assert_equal 1, decoded.typed_payload.protocol_version.to_h
    refute decoded.extension?
  end

  def test_decodes_legacy_protocol_version_string_as_v0
    decoder = AgentClientProtocol::Decoder.new(side: :agent)
    decoded = decoder.decode_request(method: "initialize", params: { "protocolVersion" => "1.0.0" })

    assert_equal 0, decoded.typed_payload.protocol_version.to_h
  end

  def test_decodes_client_side_request
    decoder = AgentClientProtocol::Decoder.new(side: :client)
    decoded = decoder.decode_request(
      method: "terminal/create",
      params: { "sessionId" => "s1", "command" => "ls" }
    )

    assert_equal "CreateTerminalRequest", decoded.schema_name
    assert_instance_of AgentClientProtocol.type_for("CreateTerminalRequest"), decoded.typed_payload
  end

  def test_decodes_extension_method
    decoder = AgentClientProtocol::Decoder.new(side: :agent)
    decoded = decoder.decode_request(method: "_vendor/custom", params: { "x" => 1 })

    assert_equal "ExtRequest", decoded.schema_name
    assert_nil decoded.typed_payload
    assert decoded.extension?
  end

  def test_decodes_unstable_method_when_enabled
    decoder = AgentClientProtocol::Decoder.new(side: :agent, unstable: true)
    decoded = decoder.decode_request(method: "session/list", params: {})

    assert_equal "ListSessionsRequest", decoded.schema_name
    assert_instance_of AgentClientProtocol.type_for("ListSessionsRequest", unstable: true), decoded.typed_payload
  end

  def test_decodes_unstable_protocol_level_notification
    decoder = AgentClientProtocol::Decoder.new(side: :protocol, unstable: true)
    decoded = decoder.decode_notification(method: "$/cancel_request", params: { "requestId" => "req-1" })

    assert_equal :notification, decoded.kind
    assert_equal "$/cancel_request", decoded.method
    assert_equal "CancelRequestNotification", decoded.schema_name
  end

  def test_rejects_unknown_method
    decoder = AgentClientProtocol::Decoder.new(side: :agent)

    error = assert_raises(AgentClientProtocol::Error) do
      decoder.decode_request(method: "not/a/method", params: {})
    end

    assert_equal AgentClientProtocol::ErrorCode::METHOD_NOT_FOUND, error.code
  end

  def test_rejects_missing_params_for_requests
    decoder = AgentClientProtocol::Decoder.new(side: :client)

    error = assert_raises(AgentClientProtocol::Error) do
      decoder.decode_request(method: "terminal/output", params: nil)
    end

    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, error.code
  end
end
