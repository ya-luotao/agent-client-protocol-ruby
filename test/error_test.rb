# frozen_string_literal: true

require_relative "test_helper"

class ErrorTest < Minitest::Test
  ACP = AgentClientProtocol

  # --- ErrorCode defaults ---

  def test_default_message_for_known_codes
    assert_equal "Parse error", ACP::ErrorCode.default_message(-32_700)
    assert_equal "Internal error", ACP::ErrorCode.default_message(-32_603)
  end

  def test_default_message_for_unknown_code
    assert_equal "Unknown error", ACP::ErrorCode.default_message(9999)
  end

  # --- Error construction ---

  def test_new_with_code_and_message
    err = ACP::Error.new(code: -32_600, message: "custom msg")
    assert_equal(-32_600, err.code)
    assert_equal "custom msg", err.message
    assert_nil err.data
  end

  def test_new_with_code_only_uses_default_message
    err = ACP::Error.new(code: -32_700)
    assert_equal "Parse error", err.message
  end

  def test_new_with_data
    err = ACP::Error.new(code: -32_603, data: { "detail" => "boom" })
    assert_equal({ "detail" => "boom" }, err.data)
  end

  def test_new_coerces_code_to_integer
    err = ACP::Error.new(code: "-32601")
    assert_equal(-32_601, err.code)
  end

  # --- Serialization ---

  def test_to_h_without_data
    err = ACP::Error.new(code: -32_600, message: "bad")
    expected = { "code" => -32_600, "message" => "bad" }
    assert_equal expected, err.to_h
  end

  def test_to_h_with_data
    err = ACP::Error.new(code: -32_603, message: "err", data: "extra")
    h = err.to_h
    assert_equal "extra", h["data"]
  end

  # --- Deserialization ---

  def test_from_h_with_string_keys
    h = { "code" => -32_700, "message" => "Parse error", "data" => "x" }
    err = ACP::Error.from_h(h)
    assert_equal(-32_700, err.code)
    assert_equal "Parse error", err.message
    assert_equal "x", err.data
  end

  def test_from_h_with_symbol_keys
    h = { code: -32_601, message: "Method not found" }
    err = ACP::Error.from_h(h)
    assert_equal(-32_601, err.code)
    assert_equal "Method not found", err.message
  end

  def test_from_h_round_trip
    original = ACP::Error.new(code: -32_602, message: "Invalid params", data: [1, 2])
    restored = ACP::Error.from_h(original.to_h)
    assert_equal original.code, restored.code
    assert_equal original.message, restored.message
    assert_equal original.data, restored.data
  end

  # --- Factory methods ---

  def test_parse_error_factory
    err = ACP::Error.parse_error("bad json")
    assert_equal(-32_700, err.code)
    assert_equal "Parse error", err.message
    assert_equal "bad json", err.data
  end

  def test_invalid_request_factory
    err = ACP::Error.invalid_request
    assert_equal(-32_600, err.code)
    assert_nil err.data
  end

  def test_method_not_found_factory
    err = ACP::Error.method_not_found("no such")
    assert_equal(-32_601, err.code)
  end

  def test_invalid_params_factory
    err = ACP::Error.invalid_params
    assert_equal(-32_602, err.code)
  end

  def test_internal_error_factory
    err = ACP::Error.internal_error("oops")
    assert_equal(-32_603, err.code)
    assert_equal "oops", err.data
  end

  def test_request_cancelled_factory
    err = ACP::Error.request_cancelled
    assert_equal(-32_800, err.code)
  end

  def test_auth_required_factory
    err = ACP::Error.auth_required
    assert_equal(-32_000, err.code)
  end

  def test_resource_not_found_without_uri
    err = ACP::Error.resource_not_found
    assert_equal(-32_002, err.code)
    assert_nil err.data
  end

  def test_resource_not_found_with_uri
    err = ACP::Error.resource_not_found("file:///tmp/x")
    assert_equal({ "uri" => "file:///tmp/x" }, err.data)
  end

  # --- Error is a StandardError ---

  def test_error_is_a_standard_error
    err = ACP::Error.new(code: -32_603)
    assert_kind_of StandardError, err
  end

  def test_error_can_be_raised_and_rescued
    assert_raises(ACP::Error) do
      raise ACP::Error.new(code: -32_603)
    end
  end
end
