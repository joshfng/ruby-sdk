# frozen_string_literal: true

require "json"
require_relative "methods"

module MCP
  class Client
    class ClientError < StandardError
      attr_reader :error_type, :original_error

      def initialize(message, error_type: :client_error, original_error: nil)
        super(message)
        @error_type = error_type
        @original_error = original_error
      end
    end

    attr_reader :transport, :server_info, :capabilities

    def initialize(transport:)
      @transport = transport
      @request_id = 0
      @server_info = nil
      @capabilities = nil
    end

    def initialize_session(protocol_version: "2025-03-26", capabilities: {}, client_info: {}, request_id: nil)
      params = {
        protocolVersion: protocol_version,
        capabilities: capabilities,
        clientInfo: client_info,
      }

      request = build_request(Methods::INITIALIZE, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new(
          "Failed to initialize: #{response[:error][:message]}",
          error_type: :initialization_error,
        )
      end

      result = response[:result]
      @server_info = result[:serverInfo]
      @capabilities = result[:capabilities]

      result
    end

    def ping(request_id: nil)
      request = build_request(Methods::PING, nil, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Ping failed: #{response[:error][:message]}")
      end

      response[:result]
    end

    def list_tools(cursor: nil, request_id: nil)
      params = cursor ? { cursor: cursor } : nil
      request = build_request(Methods::TOOLS_LIST, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to list tools: #{response[:error][:message]}")
      end

      response[:result]
    end

    def call_tool(name:, arguments: {}, request_id: nil)
      params = { name: name }
      params[:arguments] = arguments unless arguments.empty?

      request = build_request(Methods::TOOLS_CALL, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to call tool '#{name}': #{response[:error][:message]}")
      end

      response[:result]
    end

    def list_prompts(cursor: nil, request_id: nil)
      params = cursor ? { cursor: cursor } : nil
      request = build_request(Methods::PROMPTS_LIST, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to list prompts: #{response[:error][:message]}")
      end

      response[:result]
    end

    def get_prompt(name:, arguments: {}, request_id: nil)
      params = { name: name }
      params[:arguments] = arguments unless arguments.empty?

      request = build_request(Methods::PROMPTS_GET, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to get prompt '#{name}': #{response[:error][:message]}")
      end

      response[:result]
    end

    def list_resources(cursor: nil, request_id: nil)
      params = cursor ? { cursor: cursor } : nil
      request = build_request(Methods::RESOURCES_LIST, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to list resources: #{response[:error][:message]}")
      end

      response[:result]
    end

    def read_resource(uri:, request_id: nil)
      request = build_request(Methods::RESOURCES_READ, { uri: uri }, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to read resource '#{uri}': #{response[:error][:message]}")
      end

      response[:result]
    end

    def list_resource_templates(cursor: nil, request_id: nil)
      params = cursor ? { cursor: cursor } : nil
      request = build_request(Methods::RESOURCES_TEMPLATES_LIST, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to list resource templates: #{response[:error][:message]}")
      end

      response[:result]
    end

    def subscribe_resource(uri:, request_id: nil)
      request = build_request(Methods::RESOURCES_SUBSCRIBE, { uri: uri }, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to subscribe to resource '#{uri}': #{response[:error][:message]}")
      end

      response[:result]
    end

    def unsubscribe_resource(uri:, request_id: nil)
      request = build_request(Methods::RESOURCES_UNSUBSCRIBE, { uri: uri }, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to unsubscribe from resource '#{uri}': #{response[:error][:message]}")
      end

      response[:result]
    end

    def set_logging_level(level:, request_id: nil)
      request = build_request(Methods::LOGGING_SET_LEVEL, { level: level }, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to set logging level: #{response[:error][:message]}")
      end

      response[:result]
    end

    def complete(ref:, argument:, request_id: nil)
      params = {
        ref: ref,
        argument: argument,
      }

      request = build_request(Methods::COMPLETION_COMPLETE, params, request_id)
      response = @transport.send_request(request)

      if response[:error]
        raise ClientError.new("Failed to get completions: #{response[:error][:message]}")
      end

      response[:result]
    end

    private

    def build_request(method, params = nil, request_id = nil)
      request = {
        jsonrpc: "2.0",
        method: method,
        id: request_id.nil? ? next_request_id : request_id,
      }

      request[:params] = params if params
      request
    end

    def next_request_id
      @request_id += 1
    end
  end
end
