# frozen_string_literal: true

require "faraday"
require "json"

module MCP
  class Client
    module Transports
      class HTTP
        class HTTPError < StandardError
          attr_reader :status_code, :response_body

          def initialize(message, status_code: nil, response_body: nil)
            super(message)
            @status_code = status_code
            @response_body = response_body
          end
        end

        attr_reader :url, :timeout, :headers

        def initialize(url:, timeout: 30, headers: {})
          @url = url
          @timeout = timeout
          @headers = default_headers.merge(headers)
          @connection = build_connection
        end

        def send_request(request)
          json_request = JSON.generate(request)

          begin
            response = @connection.post do |req|
              req.body = json_request
              req.headers.update(@headers)
            end

            handle_response(response)
          rescue Faraday::TimeoutError => e
            raise HTTPError.new("Request timeout: #{e.message}")
          rescue Faraday::ConnectionFailed => e
            raise HTTPError.new("Connection failed: #{e.message}")
          rescue Faraday::Error => e
            raise HTTPError.new("HTTP error: #{e.message}")
          end
        end

        private

        def build_connection
          Faraday.new(url: @url) do |conn|
            conn.options.timeout = @timeout
            conn.options.open_timeout = @timeout
            conn.adapter(Faraday.default_adapter)
          end
        end

        def default_headers
          {
            "Content-Type" => "application/json",
            "Accept" => "application/json",
          }
        end

        def handle_response(response)
          unless response.success?
            raise HTTPError.new(
              "HTTP #{response.status}: #{response.reason_phrase}",
              status_code: response.status,
              response_body: response.body,
            )
          end

          begin
            JSON.parse(response.body, symbolize_names: true)
          rescue JSON::ParserError => e
            raise HTTPError.new("Invalid JSON response: #{e.message}", response_body: response.body)
          end
        end
      end
    end
  end
end
