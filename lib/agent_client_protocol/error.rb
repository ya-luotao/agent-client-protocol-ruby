# frozen_string_literal: true

module AgentClientProtocol
  module ErrorCode
    PARSE_ERROR = -32_700
    INVALID_REQUEST = -32_600
    METHOD_NOT_FOUND = -32_601
    INVALID_PARAMS = -32_602
    INTERNAL_ERROR = -32_603
    REQUEST_CANCELLED = -32_800
    AUTH_REQUIRED = -32_000
    RESOURCE_NOT_FOUND = -32_002

    DEFAULT_MESSAGES = {
      PARSE_ERROR => "Parse error",
      INVALID_REQUEST => "Invalid request",
      METHOD_NOT_FOUND => "Method not found",
      INVALID_PARAMS => "Invalid params",
      INTERNAL_ERROR => "Internal error",
      REQUEST_CANCELLED => "Request cancelled",
      AUTH_REQUIRED => "Authentication required",
      RESOURCE_NOT_FOUND => "Resource not found"
    }.freeze

    module_function

    def default_message(code)
      DEFAULT_MESSAGES.fetch(code, "Unknown error")
    end
  end

  class Error < StandardError
    attr_reader :code, :data

    def initialize(code:, message: nil, data: nil)
      @code = Integer(code)
      @data = data
      super(message || ErrorCode.default_message(@code))
    end

    def to_h
      error = {
        "code" => code,
        "message" => message
      }
      error["data"] = data unless data.nil?
      error
    end

    class << self
      def from_h(hash)
        normalized = stringify_keys(hash)
        new(
          code: normalized.fetch("code"),
          message: normalized["message"],
          data: normalized["data"]
        )
      end

      def parse_error(data = nil)
        new(code: ErrorCode::PARSE_ERROR, data: data)
      end

      def invalid_request(data = nil)
        new(code: ErrorCode::INVALID_REQUEST, data: data)
      end

      def method_not_found(data = nil)
        new(code: ErrorCode::METHOD_NOT_FOUND, data: data)
      end

      def invalid_params(data = nil)
        new(code: ErrorCode::INVALID_PARAMS, data: data)
      end

      def internal_error(data = nil)
        new(code: ErrorCode::INTERNAL_ERROR, data: data)
      end

      def request_cancelled(data = nil)
        new(code: ErrorCode::REQUEST_CANCELLED, data: data)
      end

      def auth_required(data = nil)
        new(code: ErrorCode::AUTH_REQUIRED, data: data)
      end

      def resource_not_found(uri = nil)
        payload = uri.nil? ? nil : { "uri" => uri }
        new(code: ErrorCode::RESOURCE_NOT_FOUND, data: payload)
      end

      private

      def stringify_keys(value)
        return value unless value.is_a?(Hash)

        value.each_with_object({}) do |(k, v), acc|
          acc[k.to_s] = v
        end
      end
    end
  end
end
