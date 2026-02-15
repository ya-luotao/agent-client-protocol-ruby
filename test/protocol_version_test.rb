# frozen_string_literal: true

require_relative "test_helper"

class ProtocolVersionTest < Minitest::Test
  def test_parses_integer_versions
    version = AgentClientProtocol::ProtocolVersion.parse(1)
    assert_equal 1, version.to_i
  end

  def test_maps_legacy_string_versions_to_zero
    version = AgentClientProtocol::ProtocolVersion.parse("1.0.0")
    assert_equal AgentClientProtocol::ProtocolVersion::V0, version.to_i
  end

  def test_rejects_large_versions
    assert_raises(ArgumentError) do
      AgentClientProtocol::ProtocolVersion.parse(100_000)
    end
  end
end
