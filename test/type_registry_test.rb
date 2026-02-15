# frozen_string_literal: true

require_relative "test_helper"

class TypeRegistryTest < Minitest::Test
  Registry = AgentClientProtocol::TypeRegistry

  # --- fetch ---

  def test_fetch_known_type
    klass = Registry.fetch("InitializeRequest", unstable: false)
    refute_nil klass
    assert_equal "InitializeRequest", klass.definition_name
  end

  def test_fetch_unknown_type_returns_nil
    assert_nil Registry.fetch("CompletelyBogusType", unstable: false)
  end

  def test_fetch_scalar_type
    klass = Registry.fetch("ProtocolVersion", unstable: false)
    refute_nil klass
    assert(klass < AgentClientProtocol::Types::Scalar)
  end

  def test_fetch_object_type
    klass = Registry.fetch("InitializeRequest", unstable: false)
    assert(klass < AgentClientProtocol::Types::Base)
  end

  # --- all ---

  def test_all_returns_hash_of_types
    types = Registry.all(unstable: false)
    assert_kind_of Hash, types
    assert types.key?("InitializeRequest")
    assert types.key?("ProtocolVersion")
  end

  def test_all_unstable_has_more_types
    stable_count = Registry.all(unstable: false).size
    unstable_count = Registry.all(unstable: true).size
    assert(unstable_count >= stable_count)
  end

  # --- build ---

  def test_build_known_type
    payload = { "protocolVersion" => 1, "clientCapabilities" => {} }
    result = Registry.build("InitializeRequest", payload, unstable: false)
    assert_kind_of AgentClientProtocol::Types::Base, result
  end

  def test_build_unknown_type_returns_payload_as_is
    payload = { "foo" => "bar" }
    result = Registry.build("NoSuchType", payload, unstable: false)
    assert_equal payload, result
  end

  def test_build_scalar_coerces_protocol_version
    result = Registry.build("ProtocolVersion", 1, unstable: false)
    assert_kind_of AgentClientProtocol::Types::Scalar, result
    assert_equal 1, result.value
  end

  def test_build_scalar_coerces_legacy_string_version
    result = Registry.build("ProtocolVersion", "2024-01-01", unstable: false)
    assert_equal 0, result.value
  end

  # --- Namespace isolation ---

  def test_stable_and_unstable_use_separate_namespaces
    stable_klass = Registry.fetch("InitializeRequest", unstable: false)
    unstable_klass = Registry.fetch("InitializeRequest", unstable: true)
    refute_equal stable_klass.object_id, unstable_klass.object_id
  end
end
