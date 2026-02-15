# frozen_string_literal: true

require_relative "test_helper"

class TypesBaseTest < Minitest::Test
  ACP = AgentClientProtocol

  def init_klass
    ACP::TypeRegistry.fetch("InitializeRequest", unstable: false)
  end

  def build_init(overrides = {})
    init_klass.build({ "protocolVersion" => 1, "clientCapabilities" => {} }.merge(overrides))
  end

  # --- Accessors ---

  def test_bracket_accessor_with_json_key
    obj = build_init
    assert_equal 1, obj["protocolVersion"].value
  end

  def test_bracket_accessor_with_ruby_key
    obj = build_init
    assert_equal 1, obj[:protocol_version].value
  end

  def test_fetch_existing_key
    obj = build_init
    assert_equal 1, obj.fetch("protocolVersion").value
  end

  def test_fetch_missing_key_with_default
    obj = build_init
    assert_equal "fallback", obj.fetch("nonexistent", "fallback")
  end

  def test_fetch_missing_key_without_default_raises
    obj = build_init
    assert_raises(KeyError) { obj.fetch("nonexistent") }
  end

  def test_key_present
    obj = build_init
    assert obj.key?("protocolVersion")
    assert obj.key?(:protocol_version)
  end

  def test_key_absent
    obj = build_init
    refute obj.key?("nonexistent")
  end

  # --- Equality ---

  def test_equal_objects
    a = build_init
    b = build_init
    assert_equal a, b
  end

  def test_unequal_objects
    a = build_init
    b = build_init("protocolVersion" => 0)
    refute_equal a, b
  end

  def test_eql_alias
    a = build_init
    b = build_init
    assert a.eql?(b)
  end

  def test_hash_equal_for_equal_objects
    a = build_init
    b = build_init
    assert_equal a.hash, b.hash
  end

  # --- Serialization ---

  def test_to_h_returns_plain_hash
    obj = build_init
    h = obj.to_h
    assert_kind_of Hash, h
    assert_equal 1, h["protocolVersion"]
    assert_kind_of Hash, h["clientCapabilities"]
  end

  def test_to_json_returns_json_string
    obj = build_init
    json = obj.to_json
    parsed = JSON.parse(json)
    assert_equal 1, parsed["protocolVersion"]
  end

  # --- Validation ---

  def test_missing_required_key_raises
    err = assert_raises(ACP::Error) do
      init_klass.build("clientCapabilities" => {})
    end
    assert_equal ACP::ErrorCode::INVALID_PARAMS, err.code
  end

  def test_non_hash_payload_raises
    assert_raises(ArgumentError) do
      init_klass.new("not a hash")
    end
  end

  def test_nil_payload_uses_empty_hash
    # Will raise for missing required keys, but should not raise ArgumentError
    err = assert_raises(ACP::Error) do
      init_klass.new(nil)
    end
    assert_equal ACP::ErrorCode::INVALID_PARAMS, err.code
  end

  # --- Coerce ---

  def test_coerce_returns_self_if_same_type
    obj = build_init
    assert_same obj, init_klass.coerce(obj)
  end

  def test_coerce_from_hash
    result = init_klass.coerce("protocolVersion" => 1, "clientCapabilities" => {})
    assert_kind_of init_klass, result
  end

  # --- Frozen ---

  def test_instance_is_frozen
    obj = build_init
    assert obj.frozen?
  end
end
