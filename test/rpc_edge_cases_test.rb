# frozen_string_literal: true

require_relative "test_helper"

class RpcEdgeCasesTest < Minitest::Test
  RPC = AgentClientProtocol::RPC
  Error = AgentClientProtocol::Error

  # --- parse edge cases ---

  def test_parse_rejects_wrong_jsonrpc_version
    assert_raises(Error) do
      RPC.parse({ "jsonrpc" => "1.0", "method" => "foo", "id" => 1 })
    end
  end

  def test_parse_rejects_unrecognized_message
    assert_raises(Error) do
      RPC.parse({ "jsonrpc" => "2.0" })
    end
  end

  def test_parse_json_rejects_invalid_json
    assert_raises(Error) do
      RPC.parse_json("not json{{{")
    end
  end

  def test_parse_rejects_non_hash_non_string
    assert_raises(ArgumentError) do
      RPC.parse(42)
    end
  end

  # --- Response edge cases ---

  def test_response_rejects_both_result_and_error
    assert_raises(ArgumentError) do
      RPC::Response.new(id: 1, result: "ok", error: { "code" => -1, "message" => "err" })
    end
  end

  def test_response_rejects_neither_result_nor_error
    assert_raises(ArgumentError) do
      RPC::Response.new(id: 1)
    end
  end

  def test_response_with_nil_result_is_valid
    resp = RPC::Response.new(id: 1, result: nil)
    assert resp.success?
    assert_nil resp.result
  end

  # --- RequestId edge cases ---

  def test_request_id_rejects_float
    assert_raises(ArgumentError) do
      RPC::RequestId.coerce(3.14)
    end
  end

  def test_request_id_accepts_nil
    assert_nil RPC::RequestId.coerce(nil)
  end

  def test_request_id_accepts_string
    assert_equal "abc", RPC::RequestId.coerce("abc")
  end

  def test_request_id_accepts_integer
    assert_equal 42, RPC::RequestId.coerce(42)
  end

  # --- to_h formatting ---

  def test_request_to_h_omits_nil_params
    req = RPC::Request.new(id: 1, method: "test")
    h = req.to_h
    refute h.key?("params")
    assert_equal "2.0", h["jsonrpc"]
  end

  def test_request_to_h_without_jsonrpc
    req = RPC::Request.new(id: 1, method: "test", params: { "a" => 1 })
    h = req.to_h(include_jsonrpc: false)
    refute h.key?("jsonrpc")
    assert_equal({ "a" => 1 }, h["params"])
  end

  def test_notification_to_h_omits_nil_params
    n = RPC::Notification.new(method: "test")
    h = n.to_h
    refute h.key?("params")
    assert_equal "2.0", h["jsonrpc"]
  end

  def test_response_error_to_h
    err = Error.new(code: -32_600, message: "bad")
    resp = RPC::Response.new(id: 1, error: err)
    h = resp.to_h
    assert_equal(-32_600, h["error"]["code"])
    assert_equal "bad", h["error"]["message"]
    refute h.key?("result")
  end
end
