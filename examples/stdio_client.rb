#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "mcp"
require "mcp/client/transports/stdio"

# Create a client with stdio transport
transport = MCP::Client::Transports::Stdio.new(timeout: 10)
client = MCP::Client.new(transport: transport)

begin
  # Initialize the session
  result = client.initialize_session(
    protocol_version: "2025-03-26",
    capabilities: {},
    client_info: {
      name: "example_stdio_client",
      version: "1.0.0",
    },
  )

  puts "Connected to server: #{result[:serverInfo][:name]} v#{result[:serverInfo][:version]}"
  puts "Server capabilities: #{result[:capabilities].keys.join(", ")}"

  # Test ping
  ping_result = client.ping
  puts "Ping successful: #{ping_result}"

  # List available tools
  tools_result = client.list_tools
  puts "Available tools:"
  tools_result[:tools].each do |tool|
    puts "  - #{tool[:name]}: #{tool[:description]}"
  end

  # Call a tool if available
  if tools_result[:tools].any?
    tool_name = tools_result[:tools].first[:name]
    puts "\nCalling tool: #{tool_name}"

    # Example arguments - adjust based on the actual tool
    tool_result = client.call_tool(
      name: tool_name,
      arguments: tool_name == "echo" ? { message: "Hello from stdio client!" } : {},
    )

    puts "Tool result:"
    tool_result[:content].each do |content|
      puts "  #{content[:text]}" if content[:type] == "text"
    end
  end
rescue MCP::Client::ClientError => e
  puts "Client error: #{e.message}"
  puts "Error type: #{e.error_type}"
rescue MCP::Client::Transports::Stdio::StdioError => e
  puts "Stdio transport error: #{e.message}"
  puts "Original error: #{e.original_error}" if e.original_error
rescue StandardError => e
  puts "Unexpected error: #{e.message}"
  puts e.backtrace.join("\n")
end
