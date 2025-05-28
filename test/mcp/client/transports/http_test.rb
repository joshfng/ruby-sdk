# frozen_string_literal: true

require "test_helper"
require "json"
require "webmock/minitest"

module MCP
  class Client
    module Transports
      class HTTPTest < ActiveSupport::TestCase
        setup do
          @url = "http://localhost:3000/mcp"
          @transport = HTTP.new(url: @url)
        end

        test "initializes with default values" do
          transport = HTTP.new(url: @url)

          assert_equal @url, transport.url
          assert_equal 30, transport.timeout
          assert_equal "application/json", transport.headers["Content-Type"]
          assert_equal "application/json", transport.headers["Accept"]
        end

        test "initializes with custom timeout and headers" do
          custom_headers = { "Authorization" => "Bearer token123", "X-Custom" => "value" }
          transport = HTTP.new(url: @url, timeout: 60, headers: custom_headers)

          assert_equal @url, transport.url
          assert_equal 60, transport.timeout
          assert_equal "Bearer token123", transport.headers["Authorization"]
          assert_equal "value", transport.headers["X-Custom"]
          # Should still have default headers
          assert_equal "application/json", transport.headers["Content-Type"]
          assert_equal "application/json", transport.headers["Accept"]
        end

        test "custom headers override default headers" do
          custom_headers = { "Content-Type" => "application/vnd.api+json" }
          transport = HTTP.new(url: @url, headers: custom_headers)

          assert_equal "application/vnd.api+json", transport.headers["Content-Type"]
          assert_equal "application/json", transport.headers["Accept"]
        end

        test "send_request makes POST request with correct headers and body" do
          request = {
            jsonrpc: "2.0",
            method: "ping",
            id: 1,
          }

          response_body = {
            jsonrpc: "2.0",
            id: 1,
            result: {},
          }

          stub_request(:post, @url)
            .with(
              body: JSON.generate(request),
              headers: {
                "Content-Type" => "application/json",
                "Accept" => "application/json",
              },
            )
            .to_return(
              status: 200,
              body: JSON.generate(response_body),
              headers: { "Content-Type" => "application/json" },
            )

          result = @transport.send_request(request)

          assert_equal response_body, result
        end

        test "send_request includes custom headers in request" do
          custom_headers = { "Authorization" => "Bearer token123" }
          transport = HTTP.new(url: @url, headers: custom_headers)

          request = { jsonrpc: "2.0", method: "ping", id: 1 }

          stub_request(:post, @url)
            .with(
              headers: {
                "Content-Type" => "application/json",
                "Accept" => "application/json",
                "Authorization" => "Bearer token123",
              },
            )
            .to_return(status: 200, body: '{"jsonrpc":"2.0","id":1,"result":{}}')

          transport.send_request(request)

          # WebMock will verify the headers were sent correctly
        end

        test "send_request parses JSON response with symbolized names" do
          request = { jsonrpc: "2.0", method: "ping", id: 1 }
          response_body = {
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => {
              "serverInfo" => { "name" => "test_server" },
              "capabilities" => { "tools" => {} },
            },
          }

          stub_request(:post, @url)
            .to_return(
              status: 200,
              body: JSON.generate(response_body),
              headers: { "Content-Type" => "application/json" },
            )

          result = @transport.send_request(request)

          # Should have symbolized keys
          assert_equal "2.0", result[:jsonrpc]
          assert_equal 1, result[:id]
          assert_equal "test_server", result[:result][:serverInfo][:name]
          assert_equal({}, result[:result][:capabilities][:tools])
        end

        test "send_request raises HTTPError on connection failure" do
          stub_request(:post, @url).to_raise(Faraday::ConnectionFailed.new("Connection refused"))

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          assert_includes error.message, "Connection failed"
          assert_includes error.message, "Connection refused"
          assert_nil error.status_code
          assert_nil error.response_body
        end

        test "send_request raises HTTPError on timeout" do
          stub_request(:post, @url).to_timeout

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          # WebMock's timeout simulation is caught as a connection failure
          assert_includes error.message, "Connection failed"
          assert_includes error.message, "execution expired"
          assert_nil error.status_code
          assert_nil error.response_body
        end

        test "send_request raises HTTPError on Faraday timeout error" do
          stub_request(:post, @url).to_raise(Faraday::TimeoutError.new("Request timed out"))

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          assert_includes error.message, "Request timeout"
          assert_includes error.message, "Request timed out"
          assert_nil error.status_code
          assert_nil error.response_body
        end

        test "send_request raises HTTPError on other Faraday errors" do
          stub_request(:post, @url).to_raise(Faraday::SSLError.new("SSL verification failed"))

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          assert_includes error.message, "HTTP error"
          assert_includes error.message, "SSL verification failed"
        end

        test "send_request raises HTTPError on non-success HTTP status" do
          stub_request(:post, @url)
            .to_return(
              status: 500,
              body: "Internal Server Error",
              headers: { "Content-Type" => "text/plain" },
            )

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          assert_includes error.message, "HTTP 500"
          assert_equal 500, error.status_code
          assert_equal "Internal Server Error", error.response_body
        end

        test "send_request raises HTTPError on 404 status" do
          stub_request(:post, @url)
            .to_return(
              status: 404,
              body: "Not Found",
              headers: { "Content-Type" => "text/plain" },
            )

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          assert_includes error.message, "HTTP 404"
          assert_equal 404, error.status_code
          assert_equal "Not Found", error.response_body
        end

        test "send_request raises HTTPError on invalid JSON response" do
          stub_request(:post, @url)
            .to_return(
              status: 200,
              body: "invalid json response",
              headers: { "Content-Type" => "application/json" },
            )

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          assert_includes error.message, "Invalid JSON response"
          assert_nil error.status_code
          assert_equal "invalid json response", error.response_body
        end

        test "send_request raises HTTPError on empty response body" do
          stub_request(:post, @url)
            .to_return(
              status: 200,
              body: "",
              headers: { "Content-Type" => "application/json" },
            )

          error = assert_raises(HTTP::HTTPError) do
            @transport.send_request({ jsonrpc: "2.0", method: "ping", id: 1 })
          end

          assert_includes error.message, "Invalid JSON response"
          assert_equal "", error.response_body
        end

        test "send_request handles complex request objects" do
          complex_request = {
            jsonrpc: "2.0",
            method: "tools/call",
            id: "complex-123",
            params: {
              name: "test_tool",
              arguments: {
                message: "Hello, world!",
                options: {
                  format: "json",
                  nested: {
                    array: [1, 2, 3],
                    boolean: true,
                    null_value: nil,
                  },
                },
              },
            },
          }

          response_body = {
            jsonrpc: "2.0",
            id: "complex-123",
            result: {
              content: [
                {
                  type: "text",
                  text: "Tool executed successfully",
                },
              ],
              isError: false,
            },
          }

          stub_request(:post, @url)
            .with(body: JSON.generate(complex_request))
            .to_return(
              status: 200,
              body: JSON.generate(response_body),
              headers: { "Content-Type" => "application/json" },
            )

          result = @transport.send_request(complex_request)

          assert_equal "complex-123", result[:id]
          assert_equal "Tool executed successfully", result[:result][:content][0][:text]
          assert_equal false, result[:result][:isError]
        end

        test "send_request handles unicode characters" do
          request = {
            jsonrpc: "2.0",
            method: "tools/call",
            id: 1,
            params: {
              name: "unicode_test",
              arguments: {
                message: "Hello 世界! 🌍 Café naïve résumé",
              },
            },
          }

          response_body = {
            jsonrpc: "2.0",
            id: 1,
            result: {
              content: [{ type: "text", text: "Processed: Hello 世界! 🌍 Café naïve résumé" }],
            },
          }

          stub_request(:post, @url)
            .with(body: JSON.generate(request))
            .to_return(
              status: 200,
              body: JSON.generate(response_body),
              headers: { "Content-Type" => "application/json; charset=utf-8" },
            )

          result = @transport.send_request(request)

          assert_equal "Processed: Hello 世界! 🌍 Café naïve résumé", result[:result][:content][0][:text]
        end

        test "HTTPError stores all error information" do
          error = HTTP::HTTPError.new(
            "Test error message",
            status_code: 422,
            response_body: '{"error": "validation failed"}',
          )

          assert_equal "Test error message", error.message
          assert_equal 422, error.status_code
          assert_equal '{"error": "validation failed"}', error.response_body
        end

        test "HTTPError works with minimal information" do
          error = HTTP::HTTPError.new("Simple error")

          assert_equal "Simple error", error.message
          assert_nil error.status_code
          assert_nil error.response_body
        end

        test "build_connection configures Faraday correctly" do
          transport = HTTP.new(url: @url, timeout: 45)

          # Access the private connection to verify configuration
          connection = transport.instance_variable_get(:@connection)

          assert_equal @url, connection.url_prefix.to_s
          assert_equal 45, connection.options.timeout
          assert_equal 45, connection.options.open_timeout
        end

        test "default_headers returns correct headers" do
          transport = HTTP.new(url: @url)

          # Access private method for testing
          default_headers = transport.send(:default_headers)

          expected_headers = {
            "Content-Type" => "application/json",
            "Accept" => "application/json",
          }

          assert_equal expected_headers, default_headers
        end

        test "handles response with different content types" do
          request = { jsonrpc: "2.0", method: "ping", id: 1 }
          response_body = { jsonrpc: "2.0", id: 1, result: {} }

          # Test with different content type headers
          ["application/json", "application/json; charset=utf-8", "application/vnd.api+json"].each do |content_type|
            stub_request(:post, @url)
              .to_return(
                status: 200,
                body: JSON.generate(response_body),
                headers: { "Content-Type" => content_type },
              )

            result = @transport.send_request(request)
            assert_equal response_body, result

            # Clear stubs for next iteration
            WebMock.reset!
          end
        end

        test "handles large response bodies" do
          request = { jsonrpc: "2.0", method: "ping", id: 1 }

          # Create a large response
          large_data = "x" * 10000 # 10KB of data
          response_body = {
            jsonrpc: "2.0",
            id: 1,
            result: {
              data: large_data,
              size: large_data.length,
            },
          }

          stub_request(:post, @url)
            .to_return(
              status: 200,
              body: JSON.generate(response_body),
              headers: { "Content-Type" => "application/json" },
            )

          result = @transport.send_request(request)

          assert_equal large_data, result[:result][:data]
          assert_equal 10000, result[:result][:size]
        end

        test "preserves request ID types" do
          # Test with string ID
          string_request = { jsonrpc: "2.0", method: "ping", id: "string-id-123" }
          stub_request(:post, @url)
            .to_return(status: 200, body: '{"jsonrpc":"2.0","id":"string-id-123","result":{}}')

          result = @transport.send_request(string_request)
          assert_equal "string-id-123", result[:id]

          WebMock.reset!

          # Test with numeric ID
          numeric_request = { jsonrpc: "2.0", method: "ping", id: 42 }
          stub_request(:post, @url)
            .to_return(status: 200, body: '{"jsonrpc":"2.0","id":42,"result":{}}')

          result = @transport.send_request(numeric_request)
          assert_equal 42, result[:id]
        end
      end
    end
  end
end
