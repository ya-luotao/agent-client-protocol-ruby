# frozen_string_literal: true

require "json"

module AgentClientProtocol
  module RPC
    JSONRPC_VERSION = "2.0"

    module_function

    def parse(message)
      normalized = normalize_input(message)

      if normalized.key?("jsonrpc") && normalized["jsonrpc"] != JSONRPC_VERSION
        raise Error.invalid_request("unsupported jsonrpc version: #{normalized['jsonrpc']}")
      end

      if normalized.key?("method")
        return Request.new(
          id: normalized["id"],
          method: normalized["method"],
          params: normalized["params"]
        ) if normalized.key?("id")

        return Notification.new(method: normalized["method"], params: normalized["params"])
      end

      if normalized.key?("result") || normalized.key?("error")
        response_kwargs = { id: normalized["id"] }
        response_kwargs[:result] = normalized["result"] if normalized.key?("result")
        response_kwargs[:error] = normalized["error"] if normalized.key?("error")
        return Response.new(**response_kwargs)
      end

      raise Error.invalid_request("message is neither request, response, nor notification")
    end

    def parse_json(json)
      parse(JSON.parse(json))
    rescue JSON::ParserError => e
      raise Error.parse_error(e.message)
    end

    def normalize_input(message)
      case message
      when String
        JSON.parse(message)
      when Hash
        deep_stringify_keys(message)
      else
        raise ArgumentError, "message must be a Hash or JSON String"
      end
    end

    def deep_stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), result|
          result[k.to_s] = deep_stringify_keys(v)
        end
      when Array
        value.map { |item| deep_stringify_keys(item) }
      else
        value
      end
    end

    class Request
      attr_reader :id, :method, :params

      def initialize(id:, method:, params: nil)
        @id = RequestId.coerce(id)
        @method = String(method)
        @params = params
      end

      def to_h(include_jsonrpc: true)
        payload = {
          "id" => id,
          "method" => method
        }
        payload["params"] = params unless params.nil?
        include_jsonrpc ? { "jsonrpc" => JSONRPC_VERSION }.merge(payload) : payload
      end
    end

    class Notification
      attr_reader :method, :params

      def initialize(method:, params: nil)
        @method = String(method)
        @params = params
      end

      def to_h(include_jsonrpc: true)
        payload = { "method" => method }
        payload["params"] = params unless params.nil?
        include_jsonrpc ? { "jsonrpc" => JSONRPC_VERSION }.merge(payload) : payload
      end
    end

    class Response
      attr_reader :id, :result, :error

      def initialize(id:, result: :__undefined__, error: :__undefined__)
        @id = RequestId.coerce(id)
        has_result = result != :__undefined__
        has_error = error != :__undefined__

        if has_result == has_error
          raise ArgumentError, "response must have exactly one of result or error"
        end

        @result = has_result ? result : nil
        @error = normalize_error(error) if has_error
      end

      def success?
        error.nil?
      end

      def failure?
        !success?
      end

      def to_h(include_jsonrpc: true)
        payload = { "id" => id }
        if success?
          payload["result"] = result
        else
          payload["error"] = error.is_a?(Error) ? error.to_h : error
        end

        include_jsonrpc ? { "jsonrpc" => JSONRPC_VERSION }.merge(payload) : payload
      end

      private

      def normalize_error(error)
        return error if error.is_a?(Error)
        return Error.from_h(error) if error.is_a?(Hash)

        raise ArgumentError, "error must be an AgentClientProtocol::Error or a Hash"
      end
    end

    module RequestId
      module_function

      def coerce(value)
        case value
        when nil, String, Integer
          value
        else
          raise ArgumentError, "request id must be nil, String, or Integer"
        end
      end
    end
  end
end
