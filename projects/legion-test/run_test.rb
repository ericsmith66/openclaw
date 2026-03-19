#!/usr/bin/env ruby
# frozen_string_literal: true

# Agentic coding test runner for agent_desk gem.
# Usage:
#   ruby run_test.rb <prompt_number>
#   ruby run_test.rb <prompt_number> <model_name>
#
# Environment:
#   SMART_PROXY_TOKEN  - Bearer token for SmartProxy
#   MAX_ITER           - Override max iterations (default: 200)
#   TIMEOUT            - Override timeout in seconds (default: 900)

require "json"
require "time"

$LOAD_PATH.unshift File.join(__dir__, "..", "..", "gems", "agent_desk", "lib")
require "agent_desk"

PROJECT_DIR = __dir__
MAX_ITER    = Integer(ENV.fetch("MAX_ITER", "200"))
TIMEOUT_SEC = Integer(ENV.fetch("TIMEOUT", "900"))
PROXY_URL   = "http://192.168.4.253:3001"
PROXY_TOKEN = ENV.fetch("SMART_PROXY_TOKEN") { abort "SMART_PROXY_TOKEN not set" }

# ---------------------------------------------------------------------------
# Prompts — rewritten for real agentic execution (use tools, don't simulate)
# ---------------------------------------------------------------------------
PROMPTS = {
  "1" => {
    name: "Model + Migration",
    text: <<~PROMPT
      You are inside a Rails 8+ application at #{PROJECT_DIR}.

      Create a User model with:
      - name (string), email (string, unique index), age (integer)
      - Presence validations for name and email
      - Database-level uniqueness on email

      Steps:
      1. Run: rails generate model User name:string email:string age:integer
      2. Add the unique index to the migration if not present
      3. Run: rails db:migrate
      4. Add validations to app/models/user.rb
      5. Verify by running: rails runner "User.create!(name: 'Test', email: 'test@example.com', age: 25); puts User.count"
    PROMPT
  },
  "2" => {
    name: "CRUD Controller",
    text: <<~PROMPT
      You are inside a Rails 8+ application at #{PROJECT_DIR}.
      A Post model already exists with title (string) and content (text).

      Create a complete RESTful JSON API controller for Posts:
      1. Generate or create PostsController with index, show, create, update, destroy
      2. Add resourceful routes in config/routes.rb
      3. All responses JSON format
      4. Use strong parameters
      5. Handle not-found with 404 JSON response
      6. Verify by running: rails runner "Post.create!(title: 'Hello', content: 'World'); puts Post.count"
    PROMPT
  },
  "3" => {
    name: "Validations + JSON Errors",
    text: <<~PROMPT
      You are inside a Rails 8+ application at #{PROJECT_DIR}.
      A Product model exists with name (string), price (decimal), stock (integer).
      A basic ProductsController with scaffold-style CRUD already exists.

      Your task:
      1. Add model validations to app/models/product.rb:
         - name: presence
         - price: presence, greater than 0
         - stock: presence, greater than or equal to 0
      2. Update create action: return 201 on success, 422 with {errors: {field: [msgs]}} on failure
      3. Update update action: return 200 on success, 422 with errors on failure
      4. Verify by running: rails runner "p = Product.new(name: '', price: -1, stock: -1); puts p.valid?; puts p.errors.full_messages"
    PROMPT
  },
  "4" => {
    name: "Soft Delete (Hard Mode)",
    text: <<~PROMPT
      You are inside a Rails 8+ application at #{PROJECT_DIR}.
      Models exist: User, Post (belongs_to :user), Comment (polymorphic commentable, belongs_to :user).

      Implement soft deletion:
      1. Add deleted_at:datetime to Post and Comment via migrations
      2. Add a boolean column cascade_deleted to Comment (default false) to track cascaded deletes
      3. Default scope on both: exclude deleted records (where(deleted_at: nil))
      4. Add scope :with_deleted that removes the default scope filter
      5. Post#soft_delete: in a transaction, set deleted_at on the post, then update_all
         associated comments to set deleted_at and cascade_deleted=true
      6. Post#restore: in a transaction, clear deleted_at on the post, then update_all
         comments where cascade_deleted=true to clear deleted_at and cascade_deleted
      7. Comment#soft_delete: just set deleted_at (cascade_deleted stays false)
      8. Run migrations
      9. Verify by running:
         rails runner "
           u = User.create!(email: 'test@test.com');
           p = Post.create!(title: 'Test', content: 'Body', user: u);
           c1 = Comment.unscoped.create!(body: 'C1', commentable: p, user: u);
           c2 = Comment.unscoped.create!(body: 'C2', commentable: p, user: u);
           c3 = Comment.unscoped.create!(body: 'Manual', commentable: p, user: u);
           c3.update!(deleted_at: Time.current);
           p.soft_delete;
           puts 'Posts visible: ' + Post.count.to_s;
           puts 'Comments visible: ' + Comment.count.to_s;
           p.restore;
           puts 'After restore posts: ' + Post.count.to_s;
           puts 'After restore comments: ' + Comment.count.to_s;
           puts 'Manual still deleted: ' + Comment.unscoped.find(c3.id).deleted_at.present?.to_s;
         "
    PROMPT
  }
}.freeze

# ---------------------------------------------------------------------------
# Prerequisite setup per prompt
# ---------------------------------------------------------------------------
def setup_prerequisites(prompt_num)
  case prompt_num
  when "2"
    # Prompt 2 needs a Post model
    system("cd #{PROJECT_DIR} && bin/rails generate model Post title:string content:text --no-test-framework --force 2>&1")
    system("cd #{PROJECT_DIR} && bin/rails db:migrate 2>&1")
  when "3"
    # Prompt 3 needs a Product model + scaffold controller
    system("cd #{PROJECT_DIR} && bin/rails generate scaffold Product name:string price:decimal stock:integer --no-test-framework --force 2>&1")
    system("cd #{PROJECT_DIR} && bin/rails db:migrate 2>&1")
  when "4"
    # Prompt 4 needs User, Post, Comment
    system("cd #{PROJECT_DIR} && bin/rails generate model User email:string --no-test-framework --force 2>&1")
    system("cd #{PROJECT_DIR} && bin/rails generate model Post title:string content:text user:references --no-test-framework --force 2>&1")
    system("cd #{PROJECT_DIR} && bin/rails generate model Comment body:text commentable:references{polymorphic} user:references --no-test-framework --force 2>&1")
    system("cd #{PROJECT_DIR} && bin/rails db:migrate 2>&1")
  end
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
prompt_num = ARGV[0]
model_name = ARGV[1] || "qwen3-coder-next:latest"

unless PROMPTS.key?(prompt_num)
  abort "Usage: ruby run_test.rb <1|2|3|4> [model_name]\nAvailable prompts: #{PROMPTS.keys.join(', ')}"
end

prompt_info = PROMPTS[prompt_num]
puts "=" * 70
puts "AGENTIC TEST: Prompt #{prompt_num} — #{prompt_info[:name]}"
puts "Model: #{model_name}"
puts "Max iterations: #{MAX_ITER} | Timeout: #{TIMEOUT_SEC}s"
puts "Project dir: #{PROJECT_DIR}"
puts "=" * 70

# Setup prerequisites
puts "\n[SETUP] Running prerequisites for prompt #{prompt_num}..."
setup_prerequisites(prompt_num)
puts "[SETUP] Done.\n\n"

# Build components
model_manager = AgentDesk::Models::ModelManager.new(
  provider: :smart_proxy,
  api_key: PROXY_TOKEN,
  base_url: PROXY_URL,
  model: model_name,
  timeout: TIMEOUT_SEC
)

tool_set = AgentDesk::Tools::PowerTools.create(project_dir: PROJECT_DIR)

runner = AgentDesk::Agent::Runner.new(model_manager: model_manager)

system_prompt = <<~SYS
  You are an expert Ruby on Rails developer working in a strict agentic workflow.
  You have access to tools for reading/writing/editing files and executing shell commands.

  CRITICAL RULES:
  - Use the bash tool to run ALL shell commands. NEVER just describe what to run — EXECUTE it.
  - Do NOT simulate output. Every command must be executed via the bash tool.
  - Do NOT rename, move, or delete the project directory itself.
  - The project is at: #{PROJECT_DIR}
  - Always use absolute paths or cd to #{PROJECT_DIR} before running commands.
  - When done, state "TASK COMPLETE" clearly.
SYS

# Track metrics
start_time = Time.now
iteration_count = 0
tool_call_count = 0

puts "[RUN] Starting agent loop..."

begin
  conversation = runner.run(
    prompt: prompt_info[:text],
    project_dir: PROJECT_DIR,
    system_prompt: system_prompt,
    tool_set: tool_set,
    max_iterations: MAX_ITER,
    on_message: ->(msg) {
      if msg[:role] == "assistant"
        iteration_count += 1
        if msg[:tool_calls]
          msg[:tool_calls].each do |tc|
            tool_call_count += 1
            name = tc.dig(:function, :name) || tc.dig("function", "name") || "unknown"
            puts "  [TOOL ##{tool_call_count}] #{name}"
          end
        else
          content = msg[:content].to_s
          preview = content.length > 200 ? "#{content[0..200]}..." : content
          puts "  [ASSISTANT] #{preview}"
        end
      end
    }
  )

  elapsed = Time.now - start_time

  puts "\n#{'=' * 70}"
  puts "RESULT: Prompt #{prompt_num} — #{prompt_info[:name]}"
  puts "Model: #{model_name}"
  puts "Duration: #{elapsed.round(1)}s"
  puts "Iterations: #{iteration_count}"
  puts "Tool calls: #{tool_call_count}"
  puts "Final message preview:"
  last_assistant = conversation.reverse.find { |m| m[:role] == "assistant" && m[:content] }
  if last_assistant
    puts last_assistant[:content].to_s[0..500]
  end
  puts "=" * 70

  # Write result to JSON
  result = {
    prompt: prompt_num,
    prompt_name: prompt_info[:name],
    model: model_name,
    duration_seconds: elapsed.round(1),
    iterations: iteration_count,
    tool_calls: tool_call_count,
    timestamp: Time.now.iso8601,
    status: "completed"
  }

  results_file = File.join(PROJECT_DIR, "results.json")
  existing = File.exist?(results_file) ? JSON.parse(File.read(results_file)) : []
  existing << result
  File.write(results_file, JSON.pretty_generate(existing))
  puts "\n[SAVED] Result appended to results.json"

rescue => e
  elapsed = Time.now - start_time
  puts "\n[ERROR] #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")

  result = {
    prompt: prompt_num,
    prompt_name: prompt_info[:name],
    model: model_name,
    duration_seconds: elapsed.round(1),
    iterations: iteration_count,
    tool_calls: tool_call_count,
    timestamp: Time.now.iso8601,
    status: "error",
    error: "#{e.class}: #{e.message}"
  }

  results_file = File.join(PROJECT_DIR, "results.json")
  existing = File.exist?(results_file) ? JSON.parse(File.read(results_file)) : []
  existing << result
  File.write(results_file, JSON.pretty_generate(existing))
  puts "[SAVED] Error result appended to results.json"
end
