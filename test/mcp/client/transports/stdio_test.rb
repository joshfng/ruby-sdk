# frozen_string_literal: true

require "test_helper"
require "mcp/client/transports/stdio"
require "json"

module MCP
  class Client
    module Transports
      class StdioTest < ActiveSupport::TestCase
        setup do
          @transport = Stdio.new(timeout: 1)
        end

        test "initializes with default timeout" do
          transport = Stdio.new
          assert_equal 30, transport.timeout
        end

        test "initializes with custom timeout" do
          transport = Stdio.new(timeout: 10)
          assert_equal 10, transport.timeout
        end

        test "sends request and receives response successfully" do
          request = {
            jsonrpc: "2.0",
            method: "ping",
            id: 1,
          }

          response = {
            jsonrpc: "2.0",
            id: 1,
            result: {},
          }

          # Mock stdin and stdout
          mock_stdin = StringIO.new(JSON.generate(response) + "\n")
          mock_stdout = StringIO.new

          @transport.instance_variable_set(:@stdin, mock_stdin)
          @transport.instance_variable_set(:@stdout, mock_stdout)

          result = @transport.send_request(request)

          # Verify request was sent to stdout
          assert_equal JSON.generate(request) + "\n", mock_stdout.string

          # Verify response was parsed correctly
          assert_equal response, result
        end

        test "raises error on timeout" do
          request = { jsonrpc: "2.0", method: "ping", id: 1 }

          # Mock stdin that never returns data
          mock_stdin = StringIO.new("")
          mock_stdout = StringIO.new

          @transport.instance_variable_set(:@stdin, mock_stdin)
          @transport.instance_variable_set(:@stdout, mock_stdout)

          error = assert_raises(Stdio::StdioError) do
            @transport.send_request(request)
          end
          assert_match(/No response received within 1 seconds/, error.message)
        end

        test "raises error on invalid JSON response" do
          request = { jsonrpc: "2.0", method: "ping", id: 1 }

          # Mock stdin with invalid JSON
          mock_stdin = StringIO.new("invalid json\n")
          mock_stdout = StringIO.new

          @transport.instance_variable_set(:@stdin, mock_stdin)
          @transport.instance_variable_set(:@stdout, mock_stdout)

          error = assert_raises(Stdio::StdioError) do
            @transport.send_request(request)
          end
          assert_match(/Invalid JSON response/, error.message)
          assert_instance_of JSON::ParserError, error.original_error
        end

        test "raises error on broken pipe" do
          request = { jsonrpc: "2.0", method: "ping", id: 1 }

          mock_stdout = StringIO.new
          @transport.instance_variable_set(:@stdout, mock_stdout)

          # Mock puts to raise EPIPE
          mock_stdout.define_singleton_method(:puts) do |*args|
            raise Errno::EPIPE.new("Broken pipe")
          end

          error = assert_raises(Stdio::StdioError) do
            @transport.send_request(request)
          end
          assert_match(/Broken pipe/, error.message)
          assert_instance_of Errno::EPIPE, error.original_error
        end

        test "raises error on IO error" do
          request = { jsonrpc: "2.0", method: "ping", id: 1 }

          mock_stdout = StringIO.new
          @transport.instance_variable_set(:@stdout, mock_stdout)

          # Mock puts to raise IOError
          mock_stdout.define_singleton_method(:puts) do |*args|
            raise IOError.new("IO error")
          end

          error = assert_raises(Stdio::StdioError) do
            @transport.send_request(request)
          end
          assert_match(/IO error/, error.message)
          assert_instance_of IOError, error.original_error
        end
      end
    end
  end
end
