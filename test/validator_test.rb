# frozen_string_literal: true

require_relative "test_helper"

class ValidatorTest < Minitest::Test
  CUSTOM_DEFS = {
    "StrictPayload" => {
      "type" => "object",
      "required" => %w[params count name tags choice kind nullable],
      "additionalProperties" => false,
      "properties" => {
        "params" => { "$ref" => "#/$defs/StrictParams" },
        "count" => { "type" => "integer", "minimum" => 1, "maximum" => 3 },
        "name" => { "type" => "string", "minLength" => 2, "maxLength" => 4 },
        "tags" => { "type" => "array", "minItems" => 1, "maxItems" => 2, "items" => { "type" => "number" } },
        "choice" => { "oneOf" => [{ "const" => "a" }, { "const" => "b" }] },
        "kind" => { "enum" => %w[x y] },
        "nullable" => { "anyOf" => [{ "type" => "null" }, { "type" => "string" }] }
      }
    },
    "StrictParams" => {
      "allOf" => [
        { "$ref" => "#/$defs/SessionParams" },
        {
          "type" => "object",
          "required" => ["mode"],
          "properties" => {
            "mode" => { "const" => "strict" }
          }
        }
      ]
    },
    "SessionParams" => {
      "type" => "object",
      "required" => ["sessionId"],
      "properties" => {
        "sessionId" => { "type" => "string" }
      }
    },
    "FormatPayload" => {
      "type" => "object",
      "required" => %w[int64v uint64v int32v uint32v],
      "properties" => {
        "int64v" => { "type" => "integer", "format" => "int64" },
        "uint64v" => { "type" => "integer", "format" => "uint64" },
        "int32v" => { "type" => "integer", "format" => "int32" },
        "uint32v" => { "type" => "integer", "format" => "uint32" }
      }
    }
  }.freeze

  def test_validate_accepts_valid_acp_payload
    payload = { "protocolVersion" => 1, "clientCapabilities" => {} }

    assert AgentClientProtocol::Validator.validate("InitializeRequest", payload)
    assert AgentClientProtocol.validate("InitializeRequest", payload)
  end

  def test_validate_rejects_invalid_acp_payload_with_path
    error = assert_raises(AgentClientProtocol::Error) do
      AgentClientProtocol::Validator.validate("InitializeRequest", { "protocolVersion" => true })
    end

    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, error.code
    assert_match(/\$\.protocolVersion/, error.data.to_s)
  end

  def test_validate_accepts_legacy_protocol_version_string
    payload = { "protocolVersion" => "1.0.0", "clientCapabilities" => {} }
    assert AgentClientProtocol::Validator.validate("InitializeRequest", payload)
  end

  def test_validate_enforces_core_json_schema_keywords
    with_custom_defs do
      assert AgentClientProtocol::Validator.validate("StrictPayload", valid_custom_payload)
      assert_invalid("StrictPayload", valid_custom_payload.merge("count" => 1.5), "$.count")
      assert_invalid("StrictPayload", valid_custom_payload.merge("name" => "x"), "$.name")
      assert_invalid("StrictPayload", valid_custom_payload.merge("tags" => []), "$.tags")
      assert_invalid("StrictPayload", valid_custom_payload.merge("tags" => ["x"]), "$.tags[0]")
      assert_invalid("StrictPayload", valid_custom_payload.merge("choice" => "c"), "$.choice")
      assert_invalid("StrictPayload", valid_custom_payload.merge("kind" => "z"), "$.kind")
      assert_invalid("StrictPayload", valid_custom_payload.merge("nullable" => 123), "$.nullable")
      assert_invalid(
        "StrictPayload",
        valid_custom_payload.merge("params" => { "sessionId" => 1, "mode" => "strict" }),
        "$.params.sessionId"
      )
      assert_invalid(
        "StrictPayload",
        valid_custom_payload.merge("params" => { "sessionId" => "s1", "mode" => "loose" }),
        "$.params.mode"
      )
      assert_invalid("StrictPayload", valid_custom_payload.merge("extra" => true), "$.extra")
    end
  end

  def test_validate_enforces_numeric_formats
    with_custom_defs do
      assert AgentClientProtocol::Validator.validate(
        "FormatPayload",
        {
          "int64v" => (2**63) - 1,
          "uint64v" => (2**64) - 1,
          "int32v" => (2**31) - 1,
          "uint32v" => (2**32) - 1
        }
      )

      assert_invalid("FormatPayload", valid_format_payload.merge("int64v" => 2**63), "$.int64v")
      assert_invalid("FormatPayload", valid_format_payload.merge("uint64v" => -1), "$.uint64v")
      assert_invalid("FormatPayload", valid_format_payload.merge("int32v" => 2**31), "$.int32v")
      assert_invalid("FormatPayload", valid_format_payload.merge("uint32v" => -1), "$.uint32v")
    end
  end

  private

  def with_custom_defs
    schema_registry = AgentClientProtocol::SchemaRegistry
    singleton = class << schema_registry; self; end
    original_defs = schema_registry.method(:defs)

    singleton.send(:remove_method, :defs)
    singleton.send(:define_method, :defs) do |unstable: false|
      CUSTOM_DEFS
    end

    yield
  ensure
    singleton.send(:remove_method, :defs)
    singleton.send(:define_method, :defs, original_defs)
  end

  def valid_custom_payload
    {
      "params" => { "sessionId" => "s1", "mode" => "strict" },
      "count" => 2,
      "name" => "good",
      "tags" => [1, 2.5],
      "choice" => "a",
      "kind" => "x",
      "nullable" => nil
    }
  end

  def valid_format_payload
    {
      "int64v" => 1,
      "uint64v" => 1,
      "int32v" => 1,
      "uint32v" => 1
    }
  end

  def assert_invalid(definition_name, payload, expected_path)
    error = assert_raises(AgentClientProtocol::Error) do
      AgentClientProtocol::Validator.validate(definition_name, payload)
    end

    assert_equal AgentClientProtocol::ErrorCode::INVALID_PARAMS, error.code
    assert_match(/#{Regexp.escape(expected_path)}/, error.data.to_s)
  end
end
