# PRD-0090: Agent Runner Loop

**PRD ID**: PRD-0090
**Status**: Draft
**Priority**: Critical
**Created**: 2026-02-26
**Milestone**: M1 (Tool Loop)
**Depends On**: PRD-0020, PRD-0030

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/agent.ts:610-1140` — `runAgent()` (main entry point)
- `src/main/agent/agent.ts:350-447` — `buildToolSet()` (assembles tools from profile)
- `src/main/agent/agent.ts:1502-1616` — `processStep()` (handles each step's tool results)
- `src/main/agent/agent.ts:764-780` — `repairToolCall` (handles missing/invalid tools)
- `src/main/agent/optimizer.ts` — Message optimization, duplicate tool call detection

**Output Files** (Ruby):
- `lib/agent_desk/agent/runner.rb` — Main agent execution loop
- `lib/agent_desk/agent/tool_set_builder.rb` — Assembles tools from profile
- `lib/agent_desk/models/model_manager.rb` — LLM provider abstraction
- `spec/agent_desk/agent/runner_spec.rb`

---

## 1. Problem Statement

This is the heart of the framework — the loop that:
1. Takes a user prompt + conversation history
2. Builds a system prompt from the profile/rules/template
3. Assembles the tool set based on the profile
4. Sends everything to an LLM with function-calling capability
5. Processes the response: if the LLM calls a tool, executes it and loops
6. Continues until the LLM produces a final text response or hits `max_iterations`
7. Fires hooks at each lifecycle point

AiderDesk uses Vercel AI SDK's `streamText`/`generateText` which handles the multi-step tool-calling loop internally. In Ruby, we need to implement this loop ourselves using the OpenAI/Anthropic API directly.

---

## 2. Design

### 2.1 The Agent Runner

```ruby
# lib/agent_desk/agent/runner.rb
module AgentDesk
  module Agent
    class Runner
      attr_reader :hook_manager

      def initialize(
        model_manager:,
        prompts_manager: nil,
        profile_manager: nil,
        hook_manager: Hooks::HookManager.new
      )
        @model_manager = model_manager
        @prompts_manager = prompts_manager
        @profile_manager = profile_manager
        @hook_manager = hook_manager
      end

      # Main entry point
      # Returns Array of messages (the full conversation including tool calls/results)
      def run(
        profile:,
        prompt:,
        project_dir:,
        messages: [],          # Prior conversation context
        system_prompt: nil,    # Override; if nil, built from profile
        tool_set: nil,         # Override; if nil, built from profile
        max_iterations: nil,
        on_message: nil        # Callback: ->(message) { } for streaming
      )
        max_iterations ||= profile.max_iterations

        # Hook: on_agent_started
        hook_result = @hook_manager.trigger(:on_agent_started, { prompt: prompt })
        return [] if hook_result.blocked
        prompt = hook_result.event[:prompt] || prompt

        # Build system prompt if not provided
        system_prompt ||= build_system_prompt(profile, project_dir)

        # Build tool set if not provided
        tool_set ||= build_tool_set(profile, project_dir)

        # Wrap tools with hooks
        wrapped_tools = wrap_tools_with_hooks(tool_set)

        # Build approval manager
        approval_manager = Tools::ApprovalManager.new(
          tool_approvals: profile.tool_approvals,
          auto_approve: false # TODO: configurable
        )

        # Initialize conversation
        conversation = messages.dup
        conversation << { role: 'user', content: prompt } if prompt

        # The loop
        iteration = 0
        loop do
          iteration += 1
          break if iteration > max_iterations

          # Call LLM
          response = @model_manager.chat(
            model: profile.model,
            provider: profile.provider,
            system_prompt: system_prompt,
            messages: conversation,
            tools: tool_set.to_function_definitions,
            temperature: profile.temperature
          )

          # Add assistant response to conversation
          assistant_message = response[:message]
          conversation << assistant_message
          on_message&.call(assistant_message)

          # Check if LLM wants to call tools
          tool_calls = extract_tool_calls(assistant_message)
          break if tool_calls.empty? # LLM is done — final text response

          # Execute each tool call
          tool_results = tool_calls.map do |tc|
            execute_tool_call(tc, wrapped_tools, approval_manager, on_message: on_message)
          end

          # Add tool results to conversation
          tool_results.each do |result|
            tool_message = {
              role: 'tool',
              tool_call_id: result[:tool_call_id],
              content: result[:output].is_a?(String) ? result[:output] : JSON.generate(result[:output])
            }
            conversation << tool_message
            on_message&.call(tool_message)
          end
        end

        conversation
      end

      private

      def build_system_prompt(profile, project_dir)
        return '' unless @prompts_manager
        @prompts_manager.system_prompt(profile: profile, project_dir: project_dir)
      end

      def build_tool_set(profile, project_dir)
        builder = ToolSetBuilder.new(profile: profile, project_dir: project_dir)
        builder.build
      end

      def wrap_tools_with_hooks(tool_set)
        # Return a modified tool_set where each tool's execute is wrapped
        # with on_tool_called / on_tool_finished hooks
        # (See PRD-0030 for the wrapping pattern)
        tool_set # For M1, hooks are optional
      end

      def extract_tool_calls(assistant_message)
        # OpenAI format: message[:tool_calls] array
        # Anthropic format: content blocks with type: 'tool_use'
        # Normalize to: [{ id:, name:, arguments: }]
        calls = assistant_message.dig(:tool_calls) || []
        calls.map do |tc|
          {
            id: tc[:id] || tc['id'],
            name: tc.dig(:function, :name) || tc.dig('function', 'name'),
            arguments: parse_arguments(tc.dig(:function, :arguments) || tc.dig('function', 'arguments'))
          }
        end
      end

      def parse_arguments(args)
        return {} if args.nil?
        return args if args.is_a?(Hash)
        JSON.parse(args)
      rescue JSON::ParserError
        {}
      end

      def execute_tool_call(tool_call, tool_set, approval_manager, on_message: nil)
        tool = tool_set[tool_call[:name]]

        # Handle missing tool (like AiderDesk's repairToolCall for NoSuchToolError)
        unless tool
          return {
            tool_call_id: tool_call[:id],
            output: "Error: Tool '#{tool_call[:name]}' not found. Available tools: #{tool_set.map(&:full_name).join(', ')}"
          }
        end

        # Check approval
        approved, user_input = approval_manager.check_approval(
          tool.full_name,
          text: "Approve #{tool.name}?",
          subject: tool_call[:arguments].to_s
        )

        unless approved
          return {
            tool_call_id: tool_call[:id],
            output: "Tool execution denied.#{user_input ? " Reason: #{user_input}" : ''}"
          }
        end

        # Execute
        begin
          output = tool.execute(tool_call[:arguments])
          { tool_call_id: tool_call[:id], output: output }
        rescue StandardError => e
          { tool_call_id: tool_call[:id], output: "Error executing #{tool.name}: #{e.message}" }
        end
      end
    end
  end
end
```

### 2.2 ToolSetBuilder

Assembles the complete tool set from a profile (which groups are enabled):

```ruby
# lib/agent_desk/agent/tool_set_builder.rb
module AgentDesk
  module Agent
    class ToolSetBuilder
      def initialize(profile:, project_dir:)
        @profile = profile
        @project_dir = project_dir
      end

      def build
        tool_set = Tools::ToolSet.new

        if @profile.use_power_tools
          tool_set.merge!(Tools::PowerTools.create(project_dir: @project_dir, profile: @profile))
        end

        if @profile.use_todo_tools
          tool_set.merge!(Tools::TodoTools.create)  # PRD-0110
        end

        if @profile.use_memory_tools
          tool_set.merge!(Tools::MemoryTools.create) # PRD-0100
        end

        if @profile.use_skills_tools
          tool_set.merge!(Tools::SkillsTools.create(project_dir: @project_dir)) # PRD-0080
        end

        # Always add helper tools
        tool_set.merge!(Tools::HelperTools.create) # PRD-0110

        # Filter out never-approved tools
        tool_set.filter_by_approvals(@profile.tool_approvals)

        tool_set
      end
    end
  end
end
```

### 2.3 ModelManager (minimal for M1)

```ruby
# lib/agent_desk/models/model_manager.rb
module AgentDesk
  module Models
    class ModelManager
      def initialize(providers: {})
        @providers = providers # { provider_name => client_instance }
      end

      # Unified chat interface — abstracts OpenAI vs Anthropic
      def chat(model:, provider:, system_prompt:, messages:, tools: [], temperature: nil)
        client = @providers[provider]
        raise "Provider '#{provider}' not configured" unless client

        # Dispatch to provider-specific implementation
        case provider
        when 'openai', 'openai-compatible', 'openrouter', 'deepseek', 'groq'
          openai_chat(client, model: model, system_prompt: system_prompt,
                      messages: messages, tools: tools, temperature: temperature)
        when 'anthropic'
          anthropic_chat(client, model: model, system_prompt: system_prompt,
                         messages: messages, tools: tools, temperature: temperature)
        else
          raise "Unsupported provider: #{provider}"
        end
      end

      private

      def openai_chat(client, model:, system_prompt:, messages:, tools:, temperature:)
        request = {
          model: model,
          messages: [{ role: 'system', content: system_prompt }] + messages,
          temperature: temperature || 0.0
        }

        # Add tools if any
        unless tools.empty?
          request[:tools] = tools.map do |t|
            { type: 'function', function: t }
          end
        end

        response = client.chat(parameters: request)
        choice = response.dig('choices', 0, 'message')

        { message: symbolize_message(choice), usage: response['usage'] }
      end

      def anthropic_chat(client, model:, system_prompt:, messages:, tools:, temperature:)
        # Anthropic uses a different API shape — tools are top-level, system is separate
        request = {
          model: model,
          system: system_prompt,
          messages: messages,
          max_tokens: 8192,
          temperature: temperature || 0.0
        }

        unless tools.empty?
          request[:tools] = tools.map do |t|
            { name: t[:name], description: t[:description], input_schema: t[:parameters] }
          end
        end

        response = client.messages(parameters: request)
        # Normalize Anthropic response to OpenAI-like format
        normalize_anthropic_response(response)
      end

      def symbolize_message(msg)
        return {} unless msg
        msg.transform_keys(&:to_sym)
      end

      def normalize_anthropic_response(response)
        # Convert Anthropic's content blocks to OpenAI-style message
        # This is a significant normalization — details in implementation
        { message: {}, usage: {} }
      end
    end
  end
end
```

---

## 3. Acceptance Criteria

- ✅ `Runner#run` sends a prompt to an LLM and returns the conversation
- ✅ When the LLM calls a tool, the tool is executed and the result sent back
- ✅ The loop continues until the LLM produces a text-only response
- ✅ `max_iterations` prevents infinite loops
- ✅ Missing tools return a helpful error message (not a crash)
- ✅ Tool approval is checked before execution
- ✅ `on_agent_started` hook can block the run
- ✅ `on_message` callback fires for each message (assistant and tool results)
- ✅ Works with at least one LLM provider (OpenAI-compatible)

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Agent::Runner do
  let(:mock_model_manager) do
    manager = instance_double(AgentDesk::Models::ModelManager)
    allow(manager).to receive(:chat).and_return({
      message: { role: 'assistant', content: 'Hello, I can help!' }
    })
    manager
  end

  let(:runner) { described_class.new(model_manager: mock_model_manager) }
  let(:profile) { AgentDesk::Agent::Profile.new }

  it 'returns conversation with user prompt and assistant response' do
    result = runner.run(profile: profile, prompt: 'Hello', project_dir: '/tmp')
    expect(result.last[:role]).to eq('assistant')
    expect(result.last[:content]).to include('Hello')
  end

  it 'executes tool calls and loops' do
    call_count = 0
    allow(mock_model_manager).to receive(:chat) do
      call_count += 1
      if call_count == 1
        # First call: LLM wants to call a tool
        { message: {
          role: 'assistant', content: nil,
          tool_calls: [{ id: 'tc1', function: { name: 'power---file_read', arguments: '{"file_path":"test.txt"}' } }]
        } }
      else
        # Second call: LLM responds with text
        { message: { role: 'assistant', content: 'The file contains: hello' } }
      end
    end

    tool_set = AgentDesk::Tools::ToolSet.new
    tool_set.add(AgentDesk::Tools::BaseTool.new(
      name: 'file_read', group_name: 'power', description: 'Read file'
    ) { |_args, _ctx| 'hello' })

    result = runner.run(profile: profile, prompt: 'Read test.txt', project_dir: '/tmp', tool_set: tool_set)
    expect(result.length).to be >= 4 # user, assistant(tool_call), tool_result, assistant(final)
  end

  it 'respects max_iterations' do
    allow(mock_model_manager).to receive(:chat).and_return({
      message: {
        role: 'assistant', content: nil,
        tool_calls: [{ id: 'tc1', function: { name: 'power---bash', arguments: '{}' } }]
      }
    })

    result = runner.run(profile: profile, prompt: 'Loop', project_dir: '/tmp', max_iterations: 3)
    # Should stop after 3 iterations
  end
end
```

---

## 5. Usage Example (M1 end-to-end)

After PRD-0010 + PRD-0020 + PRD-0030 + PRD-0090, you can run:

```ruby
require 'agent_desk'
require 'openai'

# 1. Configure LLM provider
openai = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
model_manager = AgentDesk::Models::ModelManager.new(providers: { 'openai' => openai })

# 2. Create a profile
profile = AgentDesk::Agent::Profile.new(
  provider: 'openai',
  model: 'gpt-4o',
  use_power_tools: true
)

# 3. Create runner
runner = AgentDesk::Agent::Runner.new(model_manager: model_manager)

# 4. Run!
conversation = runner.run(
  profile: profile,
  prompt: 'List all Ruby files in the current directory',
  project_dir: Dir.pwd,
  on_message: ->(msg) { puts "#{msg[:role]}: #{msg[:content] || '(tool call)'}" }
)
```

---

## 6. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `Runner#run` | `Agent#runAgent()` |
| `ToolSetBuilder#build` | `Agent#buildToolSet()` |
| `Runner#execute_tool_call` | `Agent#processStep()` |
| `Runner#extract_tool_calls` | AI SDK's internal tool call parsing |
| Missing tool handling | `repairToolCall` with `NoSuchToolError` |
| `ModelManager#chat` | Vercel AI SDK `streamText`/`generateText` |
| `on_message` callback | Event emission to renderer via IPC |

---

**Next**: PRD-0100 (Memory System) and PRD-0110 (Todo/Task/Helper tools) add the remaining tool groups.
