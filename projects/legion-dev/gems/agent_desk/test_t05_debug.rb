#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for T05 Power Tools test

require "bundler/setup"
require "agent_desk"
require "json"

PROXY_URL = ENV.fetch("SMART_PROXY_URL") { "http://192.168.4.253:3001" }
PROXY_TOKEN = ENV.fetch("SMART_PROXY_TOKEN") { abort "Set SMART_PROXY_TOKEN" }
MODEL = ENV.fetch("MODEL") { "claude-opus-4-6" }

puts "Testing #{MODEL}..."
puts "Endpoint: #{PROXY_URL}"
puts

# Build components
profile = AgentDesk::Agent::Profile.new(
  name: "Test Agent",
  provider: "smart_proxy",
  model: MODEL,
  use_power_tools: true,
  use_aider_tools: false,
  use_todo_tools: false,
  use_memory_tools: false,
  use_skills_tools: false,
  use_subagents: false,
  use_task_tools: false,
  max_iterations: 5
)

model_manager = AgentDesk::Models::ModelManager.new(
  provider: :smart_proxy,
  api_key: PROXY_TOKEN,
  base_url: PROXY_URL,
  model: MODEL,
  timeout: 120
)

tool_set = AgentDesk::Tools::PowerTools.create(
  project_dir: Dir.pwd,
  profile: profile
)

prompts_manager = AgentDesk::Prompts::PromptsManager.new
system_prompt = prompts_manager.system_prompt(
  profile: profile,
  project_dir: Dir.pwd,
  rules_content: "",
  custom_instructions: "You are a test agent. Follow instructions exactly. Be very brief."
)

runner = AgentDesk::Agent::Runner.new(
  model_manager: model_manager
)

puts "Running T05 test..."
puts

begin
  conversation = runner.run(
    prompt: "Use the glob tool to find files matching '*.gemspec' in the project. Report what you find.",
    project_dir: Dir.pwd,
    system_prompt: system_prompt,
    tool_set: tool_set,
    max_iterations: 5
  )

  puts "Success! Conversation has #{conversation.size} messages:"
  conversation.each_with_index do |msg, i|
    role = msg[:role]
    content_preview = msg[:content].to_s[0..80]
    tool_calls = msg[:tool_calls] ? " [#{msg[:tool_calls].size} tool calls]" : ""
    puts "  #{i+1}. #{role}#{tool_calls}: #{content_preview}"
  end

  tool_msgs = conversation.select { |m| m[:role] == "tool" }
  assistant_msgs = conversation.select { |m| m[:role] == "assistant" }

  if tool_msgs.any? && assistant_msgs.any?
    puts "\n✅ T05 PASS"
  else
    puts "\n❌ T05 FAIL: No tools called or no final response"
  end
rescue => e
  puts "\n❌ T05 ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).map { |l| "  #{l}" }.join("\n") if ENV["DEBUG"]

  if e.is_a?(AgentDesk::LLMError) && e.respond_to?(:response_body)
    puts "\nResponse body:"
    begin
      body = JSON.parse(e.response_body)
      puts JSON.pretty_generate(body)
    rescue
      puts e.response_body
    end
  end
end
