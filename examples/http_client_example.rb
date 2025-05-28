#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/mcp"

# Example of using the MCP HTTP client
def main
  # Create an HTTP transport pointing to your MCP server
  transport = MCP::Client::Transports::HTTP.new(
    url: "http://localhost:3000/mcp",
    timeout: 30,
    headers: {
      "Authorization" => "Bearer your-token-here", # Optional authentication
    },
  )

  # Create the client with the transport
  client = MCP::Client.new(transport: transport)

  begin
    puts "Pinging..."
    client.ping(request_id: "ping-001")

    # Initialize the session
    puts "Initializing session..."
    result = client.initialize_session(
      protocol_version: "2025-03-26",
      capabilities: {},
      client_info: {
        name: "example_client",
        version: "1.0.0",
      },
      request_id: "init-001", # Custom request ID
    )

    puts "Connected to server: #{client.server_info[:name]} v#{client.server_info[:version]}"
    puts "Protocol version: #{result[:protocolVersion]}"
    puts "Server capabilities: #{client.capabilities.keys.join(", ")}"

    # List available tools
    if client.capabilities[:tools]
      puts "Listing tools..."
      tools_result = client.list_tools(request_id: "tools-list-001")
      tools = tools_result[:tools] || []
      if tools.any?
        tools.each do |tool|
          puts "- #{tool[:name]}: #{tool[:description]}"
        end
      else
        puts "No tools available"
      end
      puts

      # Call a tool if available
      if tools.any?
        tool_name = tools.first[:name]
        puts "Calling tool: #{tool_name}"
        begin
          result = client.call_tool(
            name: tool_name,
            arguments: {},
            request_id: "tool-call-001", # Custom request ID
          )
          puts "Tool result: #{result}"
        rescue MCP::Client::ClientError => e
          puts "Tool call failed: #{e.message}"
        end
        puts
      end
    end

    # List available prompts (using auto-incrementing ID)
    if client.capabilities[:prompts]
      puts "Listing prompts..."
      prompts_result = client.list_prompts # No custom ID - will auto-increment
      prompts = prompts_result[:prompts] || []
      if prompts.any?
        prompts.each do |prompt|
          puts "- #{prompt[:name]}: #{prompt[:description]}"
        end
      else
        puts "No prompts available"
      end
      puts

      # Get a prompt if available
      if prompts.any?
        prompt_name = prompts.first[:name]
        puts "Getting prompt: #{prompt_name}"
        begin
          result = client.get_prompt(
            name: prompt_name,
            arguments: {},
            request_id: "prompt-get-001", # Custom request ID
          )
          puts "Prompt result: #{result[:description]}"
          puts "Messages: #{result[:messages].length} message(s)"
        rescue MCP::Client::ClientError => e
          puts "Prompt get failed: #{e.message}"
        end
        puts
      end
    end

    # List available resources
    if client.capabilities[:resources]
      puts "Listing resources..."
      resources_result = client.list_resources # Auto-incrementing ID
      resources = resources_result[:resources] || []
      if resources.any?
        resources.each do |resource|
          puts "- #{resource[:uri]}: #{resource[:name]} (#{resource[:mimeType]})"
        end
      else
        puts "No resources available"
      end
      puts

      # Read a resource if available
      if resources.any?
        resource_uri = resources.first[:uri]
        puts "Reading resource: #{resource_uri}"
        begin
          result = client.read_resource(
            uri: resource_uri,
            request_id: "resource-read-001", # Custom request ID
          )
          contents = result[:contents] || []
          contents.each do |content|
            puts "Content type: #{content[:mimeType]}"
            if content[:text]
              puts "Text content: #{content[:text][0..100]}#{"..." if content[:text].length > 100}"
            elsif content[:blob]
              puts "Binary content: #{content[:blob].length} bytes"
            end
          end
        rescue MCP::Client::ClientError => e
          puts "Resource read failed: #{e.message}"
        end
        puts
      end
    end
  rescue MCP::Client::ClientError => e
    puts "Client error: #{e.message}"
    exit(1)
  rescue MCP::Client::Transports::HTTP::HTTPError => e
    puts "HTTP error: #{e.message}"
    puts "Status code: #{e.status_code}" if e.status_code
    exit(1)
  rescue => e
    puts "Unexpected error: #{e.message}"
    puts e.backtrace.join("\n")
    exit(1)
  end
end

if __FILE__ == $0
  main
end
