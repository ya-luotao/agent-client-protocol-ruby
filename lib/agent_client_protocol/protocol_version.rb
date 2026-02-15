# frozen_string_literal: true

module AgentClientProtocol
  class ProtocolVersion
    include Comparable

    V0 = 0
    V1 = 1
    LATEST = V1
    MAX_VALUE = 65_535

    attr_reader :value

    def initialize(value)
      unless value.is_a?(Integer) && value >= 0 && value <= MAX_VALUE
        raise ArgumentError, "protocol version must be an Integer between 0 and #{MAX_VALUE}"
      end

      @value = value
    end

    def self.parse(raw)
      case raw
      when Integer
        new(raw)
      when String
        # ACP legacy behavior: old string versions map to protocol version 0.
        new(V0)
      else
        raise ArgumentError, "protocol version must be an Integer or String"
      end
    end

    def <=>(other)
      other_value = other.is_a?(ProtocolVersion) ? other.value : other
      value <=> other_value
    end

    def ==(other)
      other_value = other.is_a?(ProtocolVersion) ? other.value : other
      value == other_value
    end

    def to_i
      value
    end

    def to_h
      value
    end

    def to_s
      value.to_s
    end
  end
end
