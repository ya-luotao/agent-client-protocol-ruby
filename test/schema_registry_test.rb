# frozen_string_literal: true

require_relative "test_helper"

class SchemaRegistryTest < Minitest::Test
  Registry = AgentClientProtocol::SchemaRegistry

  # --- Schema loading ---

  def test_stable_schema_has_defs
    defs = Registry.defs(unstable: false)
    assert_kind_of Hash, defs
    refute_empty defs
    assert defs.key?("InitializeRequest")
  end

  def test_unstable_schema_has_additional_defs
    stable_keys = Registry.defs(unstable: false).keys
    unstable_keys = Registry.defs(unstable: true).keys
    assert(unstable_keys.length >= stable_keys.length)
  end

  # --- Meta ---

  def test_agent_methods_stable
    methods = Registry.agent_methods(unstable: false)
    assert_kind_of Hash, methods
    assert methods.key?(:initialize)
    assert_equal "initialize", methods[:initialize]
  end

  def test_client_methods_stable
    methods = Registry.client_methods(unstable: false)
    assert methods.key?(:session_update)
    assert_equal "session/update", methods[:session_update]
  end

  def test_protocol_methods_stable_is_empty
    methods = Registry.protocol_methods(unstable: false)
    assert_empty methods
  end

  def test_protocol_methods_unstable_has_cancel
    methods = Registry.protocol_methods(unstable: true)
    assert methods.key?(:cancel_request)
    assert_equal "$/cancel_request", methods[:cancel_request]
  end

  # --- Method catalog ---

  def test_method_catalog_has_agent_side
    catalog = Registry.method_catalog(unstable: false)
    assert catalog.key?(:agent)
    assert catalog[:agent].key?("initialize")
    assert_equal "InitializeRequest", catalog[:agent]["initialize"][:request]
  end

  def test_method_catalog_has_client_side
    catalog = Registry.method_catalog(unstable: false)
    assert catalog.key?(:client)
    assert catalog[:client].key?("session/update")
  end

  # --- schema_for ---

  def test_schema_for_known_definition
    schema = Registry.schema_for("InitializeRequest", unstable: false)
    assert_kind_of Hash, schema
    assert schema.key?("properties")
  end

  def test_schema_for_unknown_definition_raises
    assert_raises(KeyError) do
      Registry.schema_for("NoSuchDefinition", unstable: false)
    end
  end
end
