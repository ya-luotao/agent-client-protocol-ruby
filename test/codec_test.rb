# frozen_string_literal: true

require_relative "test_helper"
require "json"

class CodecTest < Minitest::Test
  def test_round_trips_initialize_request
    codec = AgentClientProtocol::Codec.new(side: :agent)

    request = codec.encode_request(
      method: "initialize",
      id: "req-1",
      params: {
        "protocolVersion" => 1,
        "clientCapabilities" => {}
      }
    )
    decoded = codec.decode_rpc(JSON.generate(request))

    assert_equal :request, decoded.kind
    assert_equal "req-1", decoded.id
    assert_equal "initialize", decoded.method
    assert_equal "InitializeRequest", decoded.schema_name
    assert_instance_of AgentClientProtocol.type_for("InitializeRequest"), decoded.typed_payload
    assert_equal 1, decoded.typed_payload.protocol_version.to_h
  end

  def test_round_trips_prompt_response_with_method_aware_decoding
    codec = AgentClientProtocol::Codec.new(side: :agent)

    response = codec.encode_result(
      id: "req-2",
      method: "session/prompt",
      result: { "stopReason" => "end_turn" }
    )

    parsed = codec.decode_rpc(response)
    assert_instance_of AgentClientProtocol::RPC::Response, parsed
    assert_equal "req-2", parsed.id
    assert_equal({ "stopReason" => "end_turn" }, parsed.result)

    decoded = codec.decode_response_for(method: "session/prompt", message: JSON.generate(response))

    assert_instance_of AgentClientProtocol::RPC::Response, decoded
    assert decoded.success?
    assert_equal "req-2", decoded.id
    assert_instance_of AgentClientProtocol.type_for("PromptResponse"), decoded.result
    assert_equal "end_turn", decoded.result.stop_reason.to_h
  end

  def test_round_trips_error_response
    codec = AgentClientProtocol::Codec.new(side: :agent)

    response = codec.encode_error(
      id: "req-3",
      error: AgentClientProtocol::Error.invalid_params("bad prompt")
    )

    parsed = codec.decode_rpc(response)
    assert_instance_of AgentClientProtocol::RPC::Response, parsed
    assert parsed.failure?
    assert_equal "req-3", parsed.id
    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, parsed.error.code

    decoded = codec.decode_response_for(method: "session/prompt", message: response)

    assert decoded.failure?
    assert_equal "req-3", decoded.id
    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, decoded.error.code
  end

  def test_rejects_invalid_request_payload_during_encode
    codec = AgentClientProtocol::Codec.new(side: :agent)

    error = assert_raises(AgentClientProtocol::Error) do
      codec.encode_request(
        method: "initialize",
        id: "req-4",
        params: { "protocolVersion" => true }
      )
    end

    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, error.code
    assert_match(/\$\.protocolVersion/, error.data.to_s)
  end

  def test_rejects_invalid_result_payload_during_encode
    codec = AgentClientProtocol::Codec.new(side: :agent)

    error = assert_raises(AgentClientProtocol::Error) do
      codec.encode_result(
        id: "req-5",
        method: "session/prompt",
        result: { "stopReason" => "not_a_valid_stop_reason" }
      )
    end

    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, error.code
    assert_match(/\$\.stopReason/, error.data.to_s)
  end

  def test_accepts_legacy_protocol_version_string
    codec = AgentClientProtocol::Codec.new(side: :agent)
    request = codec.encode_request(
      method: "initialize",
      id: "req-legacy",
      params: { "protocolVersion" => "1.0.0", "clientCapabilities" => {} }
    )

    decoded = codec.decode_rpc(request)

    assert_equal "req-legacy", decoded.id
    assert_equal 0, decoded.typed_payload.protocol_version.to_h
  end

  def test_decodes_protocol_level_notification
    codec = AgentClientProtocol::Codec.new(side: :agent, unstable: true)
    notification = codec.encode_notification(
      method: "$/cancel_request",
      params: { "requestId" => "req-1" }
    )

    decoded = codec.decode_rpc(notification)

    assert_equal :notification, decoded.kind
    assert_equal :protocol, decoded.side
    assert_equal "$/cancel_request", decoded.method
    assert_equal "CancelRequestNotification", decoded.schema_name
  end
end
