# PRD-0030: Hook System

**PRD ID**: PRD-0030
**Status**: Draft
**Priority**: High
**Created**: 2026-02-26
**Milestone**: M1 (Tool Loop)
**Depends On**: PRD-0010

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/agent.ts:449-473` — `wrapToolsWithHooks` (wraps every tool's execute with hook triggers)
- `src/main/agent/agent.ts:610-626` — `on_agent_started` hook in `runAgent`
- Hook trigger pattern: `task.hookManager.trigger('onToolCalled', { toolName, args }, task, project)`
- Hook result: `{ blocked: boolean, event: { ...modified_args }, result?: any }`

**Output Files** (Ruby):
- `lib/agent_desk/hooks/hook_manager.rb`
- `lib/agent_desk/hooks/hook_result.rb`
- `spec/agent_desk/hooks/hook_manager_spec.rb`

---

## 1. Problem Statement

The agent system needs lifecycle interception points so that:
1. **External code** can block or modify tool arguments before execution
2. **External code** can observe tool results after execution
3. **External code** can block or modify the initial agent prompt
4. **Approval logic** can be overridden by hooks (before reaching the user prompt)

AiderDesk triggers hooks at:
- `on_agent_started` — before the agent loop begins (can block, can modify prompt)
- `on_tool_called` — before a tool executes (can block, can modify args)
- `on_tool_finished` — after a tool executes (notification only)
- `on_handle_approval` — inside approval flow (can override approval decision)

---

## 2. Design

### 2.1 HookResult

```ruby
# lib/agent_desk/hooks/hook_result.rb
module AgentDesk
  module Hooks
    HookResult = Data.define(:blocked, :event, :result) do
      def initialize(blocked: false, event: {}, result: nil)
        super
      end
    end
  end
end
```

### 2.2 HookManager

```ruby
# lib/agent_desk/hooks/hook_manager.rb
module AgentDesk
  module Hooks
    class HookManager
      EVENTS = %i[
        on_agent_started
        on_tool_called
        on_tool_finished
        on_handle_approval
      ].freeze

      def initialize
        @handlers = EVENTS.each_with_object({}) { |event, h| h[event] = [] }
      end

      # Register a handler for an event.
      # Handler is a callable that receives (event_data, context)
      # and returns a HookResult (or nil to pass through).
      def on(event, &handler)
        validate_event!(event)
        @handlers[event] << handler
        self
      end

      # Trigger an event. Runs all handlers in registration order.
      # If any handler returns blocked: true, short-circuits.
      # Handlers can modify event data by returning a new event hash.
      def trigger(event, event_data = {}, context = {})
        validate_event!(event)

        current_event = event_data.dup
        result = nil

        @handlers[event].each do |handler|
          hook_result = handler.call(current_event, context)
          next unless hook_result.is_a?(HookResult)

          if hook_result.blocked
            return HookResult.new(blocked: true, event: current_event, result: hook_result.result)
          end

          # Allow handler to modify event data
          current_event = hook_result.event unless hook_result.event.empty?
          result = hook_result.result
        end

        HookResult.new(blocked: false, event: current_event, result: result)
      end

      # Remove all handlers for an event (or all events)
      def clear(event = nil)
        if event
          validate_event!(event)
          @handlers[event].clear
        else
          @handlers.each_value(&:clear)
        end
      end

      private

      def validate_event!(event)
        raise ArgumentError, "Unknown hook event: #{event}. Valid: #{EVENTS.join(', ')}" unless EVENTS.include?(event)
      end
    end
  end
end
```

### 2.3 Integration with Tool Execution

The agent runner (PRD-0090) wraps every tool in a hook-aware wrapper, equivalent to AiderDesk's `wrapToolsWithHooks`:

```ruby
# Pseudocode — actual implementation in PRD-0090
def wrap_tool_with_hooks(tool, hook_manager, context)
  original_execute = tool.method(:execute)

  # Return a new proc that wraps execution
  wrapped = ->(args, ctx) {
    # Pre-execution hook
    result = hook_manager.trigger(:on_tool_called, { tool_name: tool.full_name, args: args }, context)
    return 'Tool execution blocked by hook.' if result.blocked

    effective_args = result.event[:args] || args

    # Execute
    output = original_execute.call(effective_args, context: ctx)

    # Post-execution hook (fire and forget)
    hook_manager.trigger(:on_tool_finished, { tool_name: tool.full_name, args: effective_args, result: output }, context)

    output
  }

  wrapped
end
```

---

## 3. Acceptance Criteria

- ✅ `HookManager` supports registering handlers for all four event types
- ✅ `trigger` returns `HookResult` with `blocked: false` when no handlers block
- ✅ `trigger` short-circuits and returns `blocked: true` when a handler blocks
- ✅ Handlers can modify event data (e.g., change tool args) via returned `HookResult.event`
- ✅ `on_handle_approval` hook can return a boolean result that overrides approval logic
- ✅ Invalid event names raise `ArgumentError`
- ✅ `clear` removes handlers

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Hooks::HookManager do
  subject(:manager) { described_class.new }

  it 'triggers handlers and returns unblocked result' do
    manager.on(:on_tool_called) { |event, _ctx| AgentDesk::Hooks::HookResult.new(event: event) }
    result = manager.trigger(:on_tool_called, { tool_name: 'power---bash', args: { command: 'ls' } })
    expect(result.blocked).to be false
    expect(result.event[:tool_name]).to eq('power---bash')
  end

  it 'blocks execution when handler returns blocked' do
    manager.on(:on_tool_called) do |_event, _ctx|
      AgentDesk::Hooks::HookResult.new(blocked: true)
    end
    result = manager.trigger(:on_tool_called, { tool_name: 'power---bash' })
    expect(result.blocked).to be true
  end

  it 'allows handlers to modify args' do
    manager.on(:on_tool_called) do |event, _ctx|
      modified = event.merge(args: { command: 'echo safe' })
      AgentDesk::Hooks::HookResult.new(event: modified)
    end
    result = manager.trigger(:on_tool_called, { tool_name: 'power---bash', args: { command: 'rm -rf /' } })
    expect(result.event[:args][:command]).to eq('echo safe')
  end

  it 'short-circuits on first blocking handler' do
    call_count = 0
    manager.on(:on_tool_called) { |_, _| call_count += 1; AgentDesk::Hooks::HookResult.new(blocked: true) }
    manager.on(:on_tool_called) { |_, _| call_count += 1; AgentDesk::Hooks::HookResult.new }
    manager.trigger(:on_tool_called)
    expect(call_count).to eq(1)
  end

  it 'raises on invalid event' do
    expect { manager.on(:on_invalid_event) {} }.to raise_error(ArgumentError)
  end
end
```

---

## 5. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `HookManager#on` | `task.hookManager.register(event, handler)` |
| `HookManager#trigger` | `task.hookManager.trigger('onToolCalled', ...)` |
| `HookResult.blocked` | `hookResult.blocked` |
| `HookResult.event` | `hookResult.event` (modified args) |
| `HookResult.result` | `hookResult.result` (for approval override) |
| `:on_agent_started` | `'onAgentStarted'` |
| `:on_tool_called` | `'onToolCalled'` |
| `:on_tool_finished` | `'onToolFinished'` |
| `:on_handle_approval` | `'onHandleApproval'` |

---

**Next**: PRD-0090 (Agent Runner Loop) uses hooks + tools to run the LLM agent loop.
