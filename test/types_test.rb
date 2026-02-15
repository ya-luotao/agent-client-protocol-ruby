# frozen_string_literal: true

require_relative "test_helper"

class TypesTest < Minitest::Test
  def test_generates_classes_for_all_stable_definitions
    schema_defs_count = AgentClientProtocol::SchemaRegistry.defs.keys.length
    generated_count = AgentClientProtocol::TypeRegistry.all.keys.length

    assert_equal schema_defs_count, generated_count
  end

  def test_builds_initialize_request_typed_model
    klass = AgentClientProtocol.type_for("InitializeRequest")

    model = klass.build(protocol_version: 1, client_capabilities: {})

    assert_instance_of AgentClientProtocol.type_for("ProtocolVersion"), model.protocol_version
    assert_equal 1, model.protocol_version.to_h
    assert_instance_of AgentClientProtocol.type_for("ClientCapabilities"), model.client_capabilities
    assert_equal({}, model.client_capabilities.to_h)
    assert_equal(
      {
        "protocolVersion" => 1,
        "clientCapabilities" => {}
      },
      model.to_h
    )
  end

  def test_protocol_version_type_coerces_legacy_string
    klass = AgentClientProtocol.type_for("ProtocolVersion")
    model = klass.coerce("1.0.0")

    assert_equal 0, model.to_h
  end

  def test_coerces_nested_refs_and_union_payloads
    klass = AgentClientProtocol.type_for("AgentRequest")
    request = klass.new(
      id: "req-1",
      method: "fs/read_text_file",
      params: {
        "sessionId" => "s1",
        "path" => "README.md"
      }
    )

    assert_instance_of AgentClientProtocol.type_for("RequestId"), request.id
    assert_instance_of AgentClientProtocol.type_for("ReadTextFileRequest"), request.params
    assert_equal "req-1", request.id.to_h
    assert_equal "README.md", request.params.path
  end

  def test_exposes_unstable_only_types_under_unstable_namespace
    assert_nil AgentClientProtocol.type_for("ListSessionsRequest")

    unstable_klass = AgentClientProtocol.type_for("ListSessionsRequest", unstable: true)
    refute_nil unstable_klass

    model = unstable_klass.new({})
    assert_equal({}, model.to_h)
  end
end
