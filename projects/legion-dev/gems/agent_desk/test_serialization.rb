#!/usr/bin/env ruby
# frozen_string_literal: true

# Test to see exactly what JSON is being serialized

require "bundler/setup"
require "agent_desk"
require "json"

# Simulate a tool call response from LLM
tool_call_from_llm = {
  id: "call_abc123",
  type: "function",
  function: {
    name: "power---glob",
    arguments: { pattern: "*.gemspec" }
  }
}

# Build assistant message as Runner does
assistant_msg = {
  role: "assistant",
  tool_calls: [ tool_call_from_llm ]
}
# content is nil, so we don't add it

puts "Assistant message (Ruby hash):"
puts assistant_msg.inspect
puts

# Build conversation with user, assistant, and tool messages
conversation = [
  { role: "system", content: "You are a helpful assistant." },
  { role: "user", content: "Find gemspec files" },
  assistant_msg,
  { role: "tool", tool_call_id: "call_abc123", content: "agent_desk.gemspec" }
]

# Now simulate what ModelManager does
mm = AgentDesk::Models::ModelManager.new(
  provider: :smart_proxy,
  api_key: "test",
  model: "test-model"
)

body = {
  model: "test-model",
  messages: conversation,
  tools: [
    {
      type: "function",
      function: {
        name: "power---glob",
        description: "Find files",
        parameters: {
          type: "object",
          properties: {
            pattern: { type: "string" }
          },
          required: [ "pattern" ]
        }
      }
    }
  ]
}

normalized = mm.send(:normalize_body, body)

puts "Normalized body (before JSON):"
puts normalized.inspect
puts

puts "Final JSON that would be sent:"
json_output = normalized.to_json
puts JSON.pretty_generate(JSON.parse(json_output))
puts

# Check for any nil values
puts "Checking for nil/null values in JSON:"
json_string = normalized.to_json
if json_string.include?(":null") || json_string.include?("null,") || json_string.match?(/null\s*[,}\]]/)
  puts "WARNING: Found null values in JSON!"
  puts "   This may cause 400 errors with Anthropic models"
else
  puts "OK: No null values found"
end
