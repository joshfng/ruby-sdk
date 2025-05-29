# frozen_string_literal: true

require "json"
require "stringio"

module MCP
  class Client
    module Transports
      class Stdio
        class StdioError < StandardError
          attr_reader :original_error

          def initialize(message, original_error: nil)
            super(message)
            @original_error = original_error
          end
        end

        attr_reader :timeout

        def initialize(timeout: 30)
          @timeout = timeout
          @stdin = $stdin
          @stdout = $stdout
          @stdin.set_encoding("UTF-8")
          @stdout.set_encoding("UTF-8")
        end

        def send_request(request)
          json_request = JSON.generate(request)

          begin
            # Send request to stdout
            @stdout.puts(json_request)
            @stdout.flush

            # Read response from stdin with timeout
            response_line = read_with_timeout(@timeout)

            unless response_line
              raise StdioError.new("No response received within #{@timeout} seconds")
            end

            # Parse the JSON response
            JSON.parse(response_line.strip, symbolize_names: true)
          rescue JSON::ParserError => e
            raise StdioError.new("Invalid JSON response: #{e.message}", original_error: e)
          rescue Errno::EPIPE => e
            raise StdioError.new("Broken pipe: #{e.message}", original_error: e)
          rescue IOError => e
            raise StdioError.new("IO error: #{e.message}", original_error: e)
          rescue StandardError => e
            raise StdioError.new("Stdio transport error: #{e.message}", original_error: e)
          end
        end

        private

        def read_with_timeout(timeout)
          # Handle StringIO for testing
          if @stdin.is_a?(StringIO)
            @stdin.gets
          elsif IO.select([@stdin], nil, nil, timeout)
            @stdin.gets
          else
            nil
          end
        end
      end
    end
  end
end
