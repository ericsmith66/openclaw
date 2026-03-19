#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple test runner: sends a prompt to an LLM via agent_desk gem + SmartProxy
#
# Usage:
#   cd projects/legion-test
#   ruby run_test.rb [prompt_number] [model_name]
#
# Examples:
#   ruby run_test.rb 1
#   ruby run_test.rb 1 deepseek-chat
#   MODEL=claude-sonnet-4-6 ruby run_test.rb 2

$LOAD_PATH.unshift File.join(__dir__, "..", "..", "gems", "agent_desk", "lib")
require "agent_desk"

PROXY_URL   = ENV.fetch("SMART_PROXY_URL", "http://192.168.4.253:3001")
PROXY_TOKEN = ENV.fetch("SMART_PROXY_TOKEN") { abort "Set SMART_PROXY_TOKEN" }
MODEL       = ARGV[1] || ENV.fetch("MODEL", "qwen3-coder-next:latest")
PROJECT_DIR = __dir__
MAX_ITER    = ENV.fetch("MAX_ITER", "200").to_i

# ---------------------------------------------------------------------------
# Prompts — rewritten for agentic execution (not simulation)
# ---------------------------------------------------------------------------

PROMPTS = {
  "1" => <<~PROMPT,
    You are inside a Rails 8 application at: #{PROJECT_DIR}
    The app uses SQLite3. The database already exists.

    YOUR TASK: Create a User model with these requirements:
    - Attributes: name (string), email (string with a unique index), age (integer)
    - Presence validations for name and email
    - Email uniqueness validation (model + database level)

    STEPS — execute each one using the tools available to you:
    1. Run: rails generate model User name:string email:string:uniq age:integer
    2. Run: rails db:migrate
    3. Add validations to app/models/user.rb (presence for name/email, uniqueness for email)
    4. Verify by reading the migration file and schema.rb
    5. Run a Rails runner script to test:
       - Create a valid user
       - Try to create a duplicate email (should fail)
       - Print results

    Use the bash tool for shell commands and file_read/file_write for code.
    Do NOT simulate — execute everything for real.
  PROMPT

  "2" => <<~PROMPT,
    You are inside a Rails 8 application at: #{PROJECT_DIR}
    The app uses SQLite3. The database already exists.
    A Post model exists with: title (string), content (text). Migration is already run.

    YOUR TASK: Implement a complete RESTful JSON API controller for Posts:
    - Routes: full resourceful routes (index, show, create, update, destroy)
    - PostsController with all CRUD actions returning JSON
    - Strong parameters
    - Handle not-found cases with 404
    - Create/update return the post or errors (422)

    STEPS:
    1. Add resourceful routes to config/routes.rb
    2. Create app/controllers/posts_controller.rb with all 5 actions
    3. Verify by running: rails routes | grep posts
    4. Test with Rails runner scripts that simulate requests

    Use the bash tool for shell commands. Execute everything for real.
  PROMPT

  "3" => <<~PROMPT,
    You are inside a Rails 8 application at: #{PROJECT_DIR}
    The app uses SQLite3. A Product model exists with: name (string), price (decimal), stock (integer).

    YOUR TASK: Add validations and proper JSON error handling:
    1. Add model validations to Product:
       - name: presence
       - price: presence, greater than 0
       - stock: presence, greater than or equal to 0
    2. Update ProductsController create/update to return JSON:
       - Success create: 201 with product
       - Success update: 200 with product
       - Failure: 422 with { errors: { field: ["message"] } }
    3. Test with Rails runner scripts

    Use the bash tool for shell commands. Execute everything for real.
  PROMPT

  "4" => <<~PROMPT,
    You are inside a Rails 8 application at: #{PROJECT_DIR}
    The app uses SQLite3 (not PostgreSQL — adapt accordingly, skip JSONB).

    Existing models: User (email:string:uniq), Post (title:string, content:text, user:references),
    Comment (body:text, commentable:references{polymorphic}, user:references).

    YOUR TASK: Implement soft deletion with cascading and auditable recovery:
    1. Add deleted_at:datetime to Post and Comment
    2. Default scope excludes deleted records
    3. When Post is soft-deleted, cascade to all its Comments (atomic, single transaction)
    4. When Post is restored, restore only the Comments that were cascade-deleted with it
       (not independently deleted comments)
    5. Use a deletion_group_id column on Comment to track cascade groups
    6. Log restored comments via Rails.logger.info
    7. Handle edge cases: independent comment deletion, multiple delete/restore cycles

    STEPS:
    1. Generate and run migrations
    2. Create a SoftDeletable concern
    3. Update Post and Comment models
    4. Test with Rails runner scripts proving all edge cases

    Use the bash tool for shell commands. Execute everything for real.
  PROMPT
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

prompt_num = ARGV[0] || "1"
prompt_text = PROMPTS[prompt_num]
abort "Unknown prompt: #{prompt_num}. Valid: #{PROMPTS.keys.join(', ')}" unless prompt_text

puts "=" * 70
puts " Agent Desk Test Runner"
puts "=" * 70
puts "  Model:      #{MODEL}"
puts "  Prompt:     ##{prompt_num}"
puts "  Project:    #{PROJECT_DIR}"
puts "  Max iters:  #{MAX_ITER}"
puts "=" * 70
puts

# Build components
profile = AgentDesk::Agent::Profile.new(
  name: "Test Runner",
  provider: "smart_proxy",
  model: MODEL,
  use_power_tools: true,
  use_aider_tools: false,
  use_todo_tools: false,
  use_memory_tools: false,
  use_skills_tools: false,
  use_subagents: false,
  use_task_tools: false,
  max_iterations: MAX_ITER
)

model_manager = AgentDesk::Models::ModelManager.new(
  provider: :smart_proxy,
  api_key: PROXY_TOKEN,
  base_url: PROXY_URL,
  model: MODEL,
  timeout: 180
)

bus = AgentDesk::MessageBus::CallbackBus.new
events = Hash.new(0)
bus.subscribe("*") { |channel, _| events[channel] += 1 }

runner = AgentDesk::Agent::Runner.new(
  model_manager: model_manager,
  message_bus: bus,
  hook_manager: AgentDesk::Hooks::HookManager.new
)

tool_set = AgentDesk::Tools::PowerTools.create(project_dir: PROJECT_DIR, profile: profile)

system_prompt = <<~SYS
  You are an expert Ruby on Rails developer executing tasks in a real Rails application.
  You have access to these tools: file_read, file_write, file_edit, glob, grep, bash, fetch.

  CRITICAL RULES:
  - Use the bash tool to run ALL shell commands (rails generate, rails db:migrate, etc.)
  - Use file_write to create new files, file_edit to modify existing files
  - Do NOT simulate or describe commands — EXECUTE them using tools
  - Do NOT rename, move, or delete the project directory
  - The working directory is: #{PROJECT_DIR}
  - Always cd to #{PROJECT_DIR} before running commands
  - After completing the task, summarize what you did and the results
SYS

puts "Sending prompt ##{prompt_num} (#{prompt_text.length} chars)..."
puts

start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

conversation = runner.run(
  prompt: prompt_text,
  project_dir: PROJECT_DIR,
  system_prompt: system_prompt,
  tool_set: tool_set,
  max_iterations: MAX_ITER
)

elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(1)

# Print results
puts
puts "=" * 70
puts " Results"
puts "=" * 70
puts "  Duration:      #{elapsed}s"
puts "  Messages:      #{conversation.size}"
puts "  Tool calls:    #{conversation.count { |m| m[:role] == 'tool' }}"
puts "  Asst messages: #{conversation.count { |m| m[:role] == 'assistant' }}"
puts "  Events:        #{events.sort_by { |_, v| -v }.map { |k, v| "#{k}:#{v}" }.join(', ')}"
puts

# Print final assistant message
final = conversation.reverse.find { |m| m[:role] == "assistant" && m[:content] && !m[:content].strip.empty? }
if final
  puts "--- Final Response (last 2000 chars) ---"
  text = final[:content].strip
  puts text.length > 2000 ? "...#{text[-2000..]}" : text
  puts "--- End ---"
end

# Check what was created
puts
puts "--- Files in project ---"
system("find #{PROJECT_DIR} -name '*.rb' -path '*/app/*' -o -name 'schema.rb' | sort")
