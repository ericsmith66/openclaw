# PRD-0020: Tool Framework & Approval System

**PRD ID**: PRD-0020
**Status**: Draft
**Priority**: Critical
**Created**: 2026-02-26
**Milestone**: M1 (Tool Loop)
**Depends On**: PRD-0010

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/tools/approval-manager.ts` — Approval flow (always/ask/never + per-run memory)
- `src/main/agent/agent.ts:350-447` — Tool set assembly (`buildToolSet`)
- `src/main/agent/agent.ts:449-473` — Hook wrapping (`wrapToolsWithHooks`)
- Vercel AI SDK `tool()` function pattern — Each tool has `description`, `inputSchema`, `execute`

**Output Files** (Ruby):
- `lib/agent_desk/tools/base_tool.rb` — Abstract tool interface
- `lib/agent_desk/tools/tool_set.rb` — Named collection of tools
- `lib/agent_desk/tools/approval_manager.rb` — Approval flow
- `spec/agent_desk/tools/base_tool_spec.rb`
- `spec/agent_desk/tools/tool_set_spec.rb`
- `spec/agent_desk/tools/approval_manager_spec.rb`

---

## 1. Problem Statement

The agent needs a uniform way to:
1. **Define tools** with a name, description, JSON Schema for input, and an execute block
2. **Collect tools** into a named set that the LLM sees as available functions
3. **Enforce approval** before executing a tool (always allow, ask user, or never allow)
4. **Filter tools** based on profile settings (tools with `never` approval are excluded entirely)

This is the foundation every tool group (power, todo, memory, skills, etc.) builds upon.

---

## 2. Design

### 2.1 BaseTool

Each tool is a simple object with:
- `name` (String) — e.g., `'file_read'`
- `group_name` (String) — e.g., `'power'`
- `full_name` (String) — e.g., `'power---file_read'` (derived)
- `description` (String) — shown to the LLM
- `input_schema` (Hash) — JSON Schema defining accepted parameters
- `execute` (Proc/Block) — the implementation

```ruby
# lib/agent_desk/tools/base_tool.rb
module AgentDesk
  module Tools
    class BaseTool
      attr_reader :name, :group_name, :description, :input_schema

      def initialize(name:, group_name:, description:, input_schema: {}, &execute_block)
        @name = name.freeze
        @group_name = group_name.freeze
        @description = description.freeze
        @input_schema = input_schema.freeze
        @execute_block = execute_block
      end

      def full_name
        AgentDesk.tool_id(group_name, name)
      end

      # Execute the tool. Args is a Hash matching input_schema.
      # Context provides task, tool_call_id, etc.
      def execute(args = {}, context: {})
        raise NotImplementedError, 'No execute block provided' unless @execute_block
        @execute_block.call(args, context)
      end

      # Serialize for LLM function-calling API
      def to_function_definition
        {
          name: full_name,
          description: description,
          parameters: {
            type: 'object',
            properties: input_schema.fetch(:properties, {}),
            required: input_schema.fetch(:required, []),
            additionalProperties: false
          }
        }
      end
    end
  end
end
```

### 2.2 ToolSet

A registry of tools, keyed by `full_name`. Supports filtering by approval state.

```ruby
# lib/agent_desk/tools/tool_set.rb
module AgentDesk
  module Tools
    class ToolSet
      include Enumerable

      def initialize
        @tools = {}
      end

      def add(tool)
        @tools[tool.full_name] = tool
      end

      def merge!(other_tool_set)
        other_tool_set.each { |tool| add(tool) }
        self
      end

      def [](full_name)
        @tools[full_name]
      end

      def each(&block)
        @tools.values.each(&block)
      end

      def size
        @tools.size
      end

      # Remove tools that the profile marks as 'never'
      def filter_by_approvals(tool_approvals)
        rejected = @tools.keys.select do |full_name|
          tool_approvals[full_name] == ToolApprovalState::NEVER
        end
        rejected.each { |name| @tools.delete(name) }
        self
      end

      # Convert to array of function definitions for LLM API
      def to_function_definitions
        @tools.values.map(&:to_function_definition)
      end
    end
  end
end
```

### 2.3 ApprovalManager

Mirrors AiderDesk's `ApprovalManager` — checks approval state, prompts user if needed, remembers "always for this run" decisions.

```ruby
# lib/agent_desk/tools/approval_manager.rb
module AgentDesk
  module Tools
    class ApprovalManager
      def initialize(tool_approvals:, auto_approve: false, &ask_user_block)
        @tool_approvals = tool_approvals          # Hash: full_name => ToolApprovalState
        @auto_approve = auto_approve
        @ask_user_block = ask_user_block           # ->(text, subject) { 'y'|'n'|'a'|'r' }
        @always_for_run = Set.new
      end

      # Returns [approved (bool), user_input (String or nil)]
      def check_approval(tool_full_name, text:, subject: nil)
        # Auto-approve mode
        return [true, nil] if @auto_approve

        # Already approved for this run
        return [true, nil] if @always_for_run.include?(tool_full_name)

        # Check profile approval state
        state = @tool_approvals.fetch(tool_full_name, ToolApprovalState::ALWAYS)
        return [true, nil] if state == ToolApprovalState::ALWAYS

        # Tool should never run (should have been filtered, but safety check)
        return [false, 'Tool is disabled'] if state == ToolApprovalState::NEVER

        # Ask user
        answer = @ask_user_block&.call(text, subject)
        case answer
        when 'y', 'a'
          [true, nil]
        when 'r'
          @always_for_run.add(tool_full_name)
          [true, nil]
        else
          [false, answer]
        end
      end
    end
  end
end
```

### 2.4 Tool DSL (convenience builder)

A DSL for defining tools within a group, matching the ergonomics of AiderDesk's `createPowerToolset` pattern:

```ruby
module AgentDesk
  module Tools
    class ToolSetBuilder
      def initialize(group_name)
        @group_name = group_name
        @tool_set = ToolSet.new
      end

      def tool(name, description:, input_schema: {}, &block)
        @tool_set.add(
          BaseTool.new(
            name: name,
            group_name: @group_name,
            description: description,
            input_schema: input_schema,
            &block
          )
        )
      end

      def build
        @tool_set
      end
    end

    def self.build_group(group_name, &block)
      builder = ToolSetBuilder.new(group_name)
      builder.instance_eval(&block)
      builder.build
    end
  end
end
```

**Usage**:
```ruby
power_tools = AgentDesk::Tools.build_group('power') do
  tool 'file_read',
       description: 'Reads a file',
       input_schema: { properties: { path: { type: 'string' } }, required: ['path'] } do |args, ctx|
    File.read(args['path'])
  end
end
```

---

## 3. Acceptance Criteria

- ✅ `BaseTool` can be instantiated with name, group, description, schema, and execute block
- ✅ `BaseTool#full_name` returns `"group---name"` format
- ✅ `BaseTool#execute` invokes the block with args and context
- ✅ `BaseTool#to_function_definition` returns OpenAI-compatible function schema
- ✅ `ToolSet` collects tools, supports enumeration, filtering by approval, and serialization
- ✅ `ApprovalManager#check_approval` returns `[true, nil]` for always-approved tools
- ✅ `ApprovalManager#check_approval` calls the ask block for ask-state tools
- ✅ `ApprovalManager` remembers "always for run" decisions
- ✅ `Tools.build_group` DSL creates a ToolSet with the given tools

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Tools::BaseTool do
  subject(:tool) do
    described_class.new(
      name: 'file_read', group_name: 'power',
      description: 'Reads a file',
      input_schema: { properties: { path: { type: 'string' } }, required: ['path'] }
    ) { |args, _ctx| "content of #{args['path']}" }
  end

  it 'computes full_name' do
    expect(tool.full_name).to eq('power---file_read')
  end

  it 'executes the block' do
    expect(tool.execute({ 'path' => 'foo.txt' })).to eq('content of foo.txt')
  end

  it 'serializes to function definition' do
    defn = tool.to_function_definition
    expect(defn[:name]).to eq('power---file_read')
    expect(defn[:parameters][:properties]).to have_key(:path)
  end
end

RSpec.describe AgentDesk::Tools::ToolSet do
  it 'filters out never-approved tools' do
    set = AgentDesk::Tools::ToolSet.new
    tool = AgentDesk::Tools::BaseTool.new(name: 'bash', group_name: 'power', description: 'run') {}
    set.add(tool)
    set.filter_by_approvals({ 'power---bash' => AgentDesk::ToolApprovalState::NEVER })
    expect(set.size).to eq(0)
  end
end

RSpec.describe AgentDesk::Tools::ApprovalManager do
  it 'auto-approves always-state tools' do
    mgr = described_class.new(tool_approvals: { 'power---bash' => 'always' })
    approved, _ = mgr.check_approval('power---bash', text: 'Run bash?')
    expect(approved).to be true
  end

  it 'asks user for ask-state tools' do
    mgr = described_class.new(tool_approvals: { 'power---bash' => 'ask' }) { |_text, _subject| 'y' }
    approved, _ = mgr.check_approval('power---bash', text: 'Run bash?')
    expect(approved).to be true
  end

  it 'remembers always-for-run decisions' do
    call_count = 0
    mgr = described_class.new(tool_approvals: { 'power---bash' => 'ask' }) { call_count += 1; 'r' }
    mgr.check_approval('power---bash', text: 'Run?')
    mgr.check_approval('power---bash', text: 'Run again?')
    expect(call_count).to eq(1) # Only asked once
  end
end
```

---

## 5. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `BaseTool` | Vercel AI SDK `tool({ description, inputSchema, execute })` |
| `BaseTool#full_name` | `${groupName}${TOOL_GROUP_NAME_SEPARATOR}${toolName}` |
| `ToolSet` | Plain `ToolSet` object (`Record<string, Tool>`) |
| `ToolSet#filter_by_approvals` | Check in `buildToolSet` that skips `ToolApprovalState.Never` |
| `ApprovalManager` | `src/main/agent/tools/approval-manager.ts` |
| `Tools.build_group` | `createPowerToolset()`, `createTodoToolset()`, etc. |

---

**Next**: PRD-0030 (Hook System) adds lifecycle interception that wraps tool execution.
