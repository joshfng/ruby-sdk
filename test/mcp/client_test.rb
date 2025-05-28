# frozen_string_literal: true

require "test_helper"
require "json"
require "webmock/minitest"

module MCP
  class ClientTest < ActiveSupport::TestCase
    setup do
      @server_url = "http://localhost:3000/mcp"
      @http_transport = Client::Transports::HTTP.new(url: @server_url)
      @client = Client.new(transport: @http_transport)
    end

    test "initialize_session sends initialize request and stores server info" do
      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: {
          protocolVersion: "2025-03-26",
          capabilities: { tools: {}, prompts: {}, resources: {} },
          serverInfo: { name: "test_server", version: "1.0.0" },
        },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "initialize",
            id: 1,
            params: hash_including(
              protocolVersion: "2025-03-26",
              capabilities: {},
              clientInfo: { name: "test_client", version: "1.0.0" },
            ),
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.initialize_session(client_info: { name: "test_client", version: "1.0.0" })

      assert_equal "2025-03-26", result[:protocolVersion]
      assert_equal "test_server", @client.server_info[:name]
      assert_equal "1.0.0", @client.server_info[:version]
      assert_not_nil @client.capabilities
    end

    test "ping sends ping request and returns empty result" do
      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: {},
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "ping",
            id: 1,
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.ping
      assert_equal({}, result)
    end

    test "list_tools sends tools/list request and returns tools array" do
      tools = [
        { name: "test_tool", description: "Test tool", inputSchema: {} },
      ]

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: { tools: tools },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "tools/list",
            id: 1,
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.list_tools
      assert_equal({ tools: tools }, result)
    end

    test "call_tool sends tools/call request with name and arguments" do
      tool_response = { content: "Tool executed successfully", isError: false }

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: tool_response,
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "tools/call",
            id: 1,
            params: {
              name: "test_tool",
              arguments: { message: "hello" },
            },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.call_tool(name: "test_tool", arguments: { message: "hello" })
      assert_equal tool_response, result
    end

    test "list_prompts sends prompts/list request and returns prompts array" do
      prompts = [
        { name: "test_prompt", description: "Test prompt", arguments: [] },
      ]

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: { prompts: prompts },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "prompts/list",
            id: 1,
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.list_prompts
      assert_equal({ prompts: prompts }, result)
    end

    test "get_prompt sends prompts/get request with name and arguments" do
      prompt_result = {
        description: "Test prompt result",
        messages: [{ role: "user", content: { text: "Hello, world!", type: "text" } }],
      }

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: prompt_result,
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "prompts/get",
            id: 1,
            params: {
              name: "test_prompt",
              arguments: { name: "World" },
            },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.get_prompt(name: "test_prompt", arguments: { name: "World" })
      assert_equal prompt_result, result
    end

    test "list_resources sends resources/list request and returns resources array" do
      resources = [
        { uri: "test_resource", name: "Test resource", description: "Test resource" },
      ]

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: { resources: resources },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "resources/list",
            id: 1,
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.list_resources
      assert_equal({ resources: resources }, result)
    end

    test "read_resource sends resources/read request with uri" do
      contents = [
        { uri: "test_resource", mimeType: "text/plain", text: "Resource content" },
      ]

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: { contents: contents },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "resources/read",
            id: 1,
            params: { uri: "test_resource" },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.read_resource(uri: "test_resource")
      assert_equal({ contents: contents }, result)
    end

    test "raises ClientError when server returns error response" do
      error_response = {
        jsonrpc: "2.0",
        id: 1,
        error: {
          code: -32601,
          message: "Method not found",
          data: "unknown_method",
        },
      }

      stub_request(:post, @server_url)
        .to_return(
          status: 200,
          body: JSON.generate(error_response),
          headers: { "Content-Type" => "application/json" },
        )

      error = assert_raises(Client::ClientError) do
        @client.ping
      end

      assert_includes error.message, "Method not found"
    end

    test "HTTP transport raises HTTPError on connection failure" do
      stub_request(:post, @server_url).to_raise(Faraday::ConnectionFailed.new("Connection refused"))

      error = assert_raises(Client::Transports::HTTP::HTTPError) do
        @client.ping
      end

      assert_includes error.message, "Connection failed"
    end

    test "HTTP transport raises HTTPError on timeout" do
      stub_request(:post, @server_url).to_timeout

      error = assert_raises(Client::Transports::HTTP::HTTPError) do
        @client.ping
      end

      assert_includes error.message, "Connection failed"
    end

    test "HTTP transport raises HTTPError on non-200 status" do
      stub_request(:post, @server_url)
        .to_return(status: 500, body: "Internal Server Error")

      error = assert_raises(Client::Transports::HTTP::HTTPError) do
        @client.ping
      end

      assert_includes error.message, "HTTP 500"
      assert_equal 500, error.status_code
    end

    test "HTTP transport raises HTTPError on invalid JSON response" do
      stub_request(:post, @server_url)
        .to_return(
          status: 200,
          body: "invalid json",
          headers: { "Content-Type" => "application/json" },
        )

      error = assert_raises(Client::Transports::HTTP::HTTPError) do
        @client.ping
      end

      assert_includes error.message, "Invalid JSON response"
    end

    test "HTTP transport can be configured with custom headers and timeout" do
      custom_headers = { "Authorization" => "Bearer token123" }
      custom_timeout = 60

      transport = Client::Transports::HTTP.new(
        url: @server_url,
        timeout: custom_timeout,
        headers: custom_headers,
      )

      assert_equal @server_url, transport.url
      assert_equal custom_timeout, transport.timeout
      assert_includes transport.headers, "Authorization"
      assert_equal "Bearer token123", transport.headers["Authorization"]
    end

    test "client methods accept custom request_id parameter" do
      custom_id = "custom-123"

      server_response = {
        jsonrpc: "2.0",
        id: custom_id,
        result: {},
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "ping",
            id: custom_id,
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.ping(request_id: custom_id)
      assert_equal({}, result)
    end

    test "client methods use auto-incrementing IDs when request_id is not provided" do
      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: {},
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "ping",
            id: 1,
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.ping
      assert_equal({}, result)
    end

    test "initialize_session accepts custom request_id" do
      custom_id = "init-456"

      server_response = {
        jsonrpc: "2.0",
        id: custom_id,
        result: {
          protocolVersion: "2025-03-26",
          capabilities: { tools: {}, prompts: {}, resources: {} },
          serverInfo: { name: "test_server", version: "1.0.0" },
        },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "initialize",
            id: custom_id,
            params: hash_including(
              protocolVersion: "2025-03-26",
              capabilities: {},
              clientInfo: { name: "test_client", version: "1.0.0" },
            ),
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.initialize_session(
        client_info: { name: "test_client", version: "1.0.0" },
        request_id: custom_id,
      )

      assert_equal "2025-03-26", result[:protocolVersion]
    end

    test "call_tool accepts custom request_id" do
      custom_id = "tool-789"
      tool_response = { content: "Tool executed successfully", isError: false }

      server_response = {
        jsonrpc: "2.0",
        id: custom_id,
        result: tool_response,
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "tools/call",
            id: custom_id,
            params: {
              name: "test_tool",
              arguments: { message: "hello" },
            },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.call_tool(
        name: "test_tool",
        arguments: { message: "hello" },
        request_id: custom_id,
      )
      assert_equal tool_response, result
    end

    test "list_tools accepts custom request_id" do
      custom_id = "list-tools-123"
      tools = [{ name: "test_tool", description: "Test tool", inputSchema: {} }]

      server_response = {
        jsonrpc: "2.0",
        id: custom_id,
        result: { tools: tools },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "tools/list",
            id: custom_id,
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.list_tools(request_id: custom_id)
      assert_equal({ tools: tools }, result)
    end

    test "get_prompt accepts custom request_id" do
      custom_id = "prompt-456"
      prompt_result = {
        description: "Test prompt result",
        messages: [{ role: "user", content: { text: "Hello, world!", type: "text" } }],
      }

      server_response = {
        jsonrpc: "2.0",
        id: custom_id,
        result: prompt_result,
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "prompts/get",
            id: custom_id,
            params: {
              name: "test_prompt",
              arguments: { name: "World" },
            },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.get_prompt(
        name: "test_prompt",
        arguments: { name: "World" },
        request_id: custom_id,
      )
      assert_equal prompt_result, result
    end

    test "read_resource accepts custom request_id" do
      custom_id = "resource-789"
      contents = [{ uri: "test_resource", mimeType: "text/plain", text: "Resource content" }]

      server_response = {
        jsonrpc: "2.0",
        id: custom_id,
        result: { contents: contents },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "resources/read",
            id: custom_id,
            params: { uri: "test_resource" },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.read_resource(uri: "test_resource", request_id: custom_id)
      assert_equal({ contents: contents }, result)
    end

    test "list_tools supports pagination with cursor" do
      tools = [{ name: "test_tool", description: "Test tool", inputSchema: {} }]
      cursor = "next-page-token"

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: { tools: tools, nextCursor: "next-token" },
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "tools/list",
            id: 1,
            params: { cursor: cursor },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.list_tools(cursor: cursor)
      assert_equal({ tools: tools, nextCursor: "next-token" }, result)
    end

    test "subscribe_resource sends resources/subscribe request" do
      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: {},
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "resources/subscribe",
            id: 1,
            params: { uri: "test_resource" },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.subscribe_resource(uri: "test_resource")
      assert_equal({}, result)
    end

    test "unsubscribe_resource sends resources/unsubscribe request" do
      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: {},
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "resources/unsubscribe",
            id: 1,
            params: { uri: "test_resource" },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.unsubscribe_resource(uri: "test_resource")
      assert_equal({}, result)
    end

    test "set_logging_level sends logging/setLevel request" do
      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: {},
      }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "logging/setLevel",
            id: 1,
            params: { level: "info" },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.set_logging_level(level: "info")
      assert_equal({}, result)
    end

    test "complete sends completion/complete request" do
      completion_result = {
        completion: {
          values: ["option1", "option2"],
          total: 2,
          hasMore: false,
        },
      }

      server_response = {
        jsonrpc: "2.0",
        id: 1,
        result: completion_result,
      }

      ref = { type: "ref/prompt", name: "test_prompt" }
      argument = { name: "arg1", value: "partial" }

      stub_request(:post, @server_url)
        .with(
          body: hash_including(
            jsonrpc: "2.0",
            method: "completion/complete",
            id: 1,
            params: {
              ref: ref,
              argument: argument,
            },
          ),
        )
        .to_return(
          status: 200,
          body: JSON.generate(server_response),
          headers: { "Content-Type" => "application/json" },
        )

      result = @client.complete(ref: ref, argument: argument)
      assert_equal(completion_result, result)
    end
  end
end
