# PRD-REFACTOR-001C: Extract AgentHubChannel Business Logic

Part of Epic REFACTOR-001: Codebase Architectural Refactoring.

---

## Overview

Extract business logic from `AgentHubChannel` (599 lines) into service layer classes, leaving only channel-specific concerns (subscriptions, broadcasts, parameter handling).

This refactoring follows the "Fat Model, Skinny Controller" principle adapted for ActionCable channels.

---

## Problem statement

The current `AgentHubChannel` (`app/channels/agent_hub_channel.rb`) violates separation of concerns by containing:

1. **Chat handling** (lines 435-598: message formatting, LLM calls, conversation management)
2. **Command parsing and execution** (lines 264-317: command routing, confirmation bubbles)
3. **Autonomous command orchestration** (lines 163-236: spike/plan execution)
4. **Backlog management** (lines 238-262: backlog item creation)
5. **Artifact inspection/saving** (lines 319-414: artifact CRUD operations)
6. **Workflow bridge integration** (lines 536-565: intent parsing, transition execution)
7. **Mention parsing** (lines 134-142: agent mention detection)

This makes the channel:
- Difficult to test (requires ActionCable setup)
- Hard to reuse logic (embedded in channel)
- Violates SRP (too many responsibilities)
- Impossible to use logic outside WebSocket context

---

## Proposed solution

### A) Extract service classes

Create three focused service classes:

1. **`AgentHub::ChatHandler`**
   - Methods: `handle_chat`, `build_messages`, `stream_response`, `detect_intents`, `execute_intent_actions`
   - Responsibility: Chat orchestration, LLM interaction, response streaming
   - Location: `app/services/agent_hub/chat_handler.rb`

2. **`AgentHub::CommandExecutor`**
   - Methods: `execute_command`, `execute_inspect`, `execute_save`, `execute_approve`, `execute_reject`, `execute_backlog`
   - Responsibility: Slash command execution, artifact operations
   - Location: `app/services/agent_hub/command_executor.rb`

3. **`AgentHub::AutonomousCommandService`**
   - Methods: `execute_autonomous_command`, `prepare_artifact`, `launch_workflow`
   - Responsibility: Spike/plan autonomous execution
   - Location: `app/services/agent_hub/autonomous_command_service.rb`

### B) Keep in channel (ActionCable-specific)

- Subscription management (`subscribed`, `unsubscribed`)
- ActionCable broadcasts (`broadcast_confirmation`, `ActionCable.server.broadcast`)
- Parameter extraction from `data`
- User authentication (`current_user`)
- Stream management (`stream_from`)

### C) Simplify AgentHubChannel

The channel becomes a thin adapter that:
- Routes incoming messages to appropriate services
- Broadcasts service results via ActionCable
- Handles authentication and subscriptions
- Passes `current_user` and ActionCable broadcast callback to services

Target: Reduce `AgentHubChannel` to < 200 lines.

---

## Implementation plan

### Step 1: Extract ChatHandler
- Create `app/services/agent_hub/chat_handler.rb`
- Move `handle_chat` method logic (lines 435-598)
- Extract message building, LLM call, streaming, intent detection
- Inject broadcast callback (Proc) for streaming
- Update channel to delegate to handler
- Run existing tests

### Step 2: Extract CommandExecutor
- Create `app/services/agent_hub/command_executor.rb`
- Move command execution logic (lines 264-317, 319-414)
- Handle inspect, save, approve, reject, backlog commands
- Return structured results (not broadcast directly)
- Update channel to delegate and broadcast results
- Run existing tests

### Step 3: Extract AutonomousCommandService
- Create `app/services/agent_hub/autonomous_command_service.rb`
- Move autonomous command logic (lines 163-236)
- Handle spike/plan orchestration
- Return status/messages for channel to broadcast
- Update channel to delegate
- Run existing tests

### Step 4: Refactor channel
- Simplify `speak` method to route to services
- Simplify `confirm_action` to delegate to CommandExecutor
- Keep only broadcast/subscription logic in channel
- Run existing tests

### Step 5: Extract shared concerns
- Consider extracting `AgentHub::BroadcastHelper` for common broadcast patterns
- Extract `AgentHub::ArtifactFinder` for finding active artifacts
- Run existing tests

### Step 6: Final cleanup
- Remove extracted code from channel
- Update YARD documentation
- Ensure all tests pass
- Measure final line count

---

## Service class designs

### ChatHandler

```ruby
module AgentHub
  class ChatHandler
    attr_reader :user, :conversation, :broadcast_callback

    def initialize(user:, conversation:, broadcast_callback:)
      @user = user
      @conversation = conversation
      @broadcast_callback = broadcast_callback
    end

    def call(content:, model:, target_agent_id:, client_agent_id:)
      # Build RAG context
      # Build messages array
      # Call SmartProxyClient
      # Stream to client via broadcast_callback
      # Detect intents
      # Execute intent actions
      # Return result hash
    end

    private

    def build_messages(content:, target_agent_id:)
      # Load conversation history
      # Add RAG context
      # Return messages array
    end

    def detect_intents(response_text:)
      AgentHub::WorkflowBridge.parse(response_text, role: "assistant", conversation: @conversation)
    end
  end
end
```

### CommandExecutor

```ruby
module AgentHub
  class CommandExecutor
    attr_reader :user, :agent_id

    def initialize(user:, agent_id:)
      @user = user
      @agent_id = agent_id
    end

    def execute(command:, args: nil, artifact: nil)
      case command
      when "inspect" then execute_inspect(artifact)
      when "save" then execute_save(artifact, args)
      when "approve" then execute_approve(artifact)
      when "reject" then execute_reject(artifact)
      when "backlog" then execute_backlog(args)
      else { status: :unknown, message: "Unknown command: #{command}" }
      end
    end

    private

    def execute_inspect(artifact)
      return { status: :error, message: "No artifact" } unless artifact

      {
        status: :ok,
        message_type: :formatted,
        content: format_artifact_inspection(artifact)
      }
    end

    # ... other execute_* methods
  end
end
```

### AutonomousCommandService

```ruby
module AgentHub
  class AutonomousCommandService
    attr_reader :user, :agent_id

    def initialize(user:, agent_id:)
      @user = user
      @agent_id = agent_id
    end

    def execute(command:, artifact:)
      return { status: :error, message: "No artifact" } unless artifact
      return { status: :error, message: "No PRD content" } if artifact.payload["content"].blank?

      prepare_artifact_phase(artifact)

      # Launch in background thread
      Thread.new do
        begin
          ENV["AI_TOOLS_EXECUTE"] = "true"

          run = AiWorkflowRun.for_user(user).active.order(updated_at: :desc).first
          AiWorkflowService.run(
            prompt: artifact.payload["content"],
            correlation_id: run.id,
            model: ENV["AI_DEV_MODEL"]
          )

          { status: :completed, artifact: artifact }
        rescue => e
          { status: :error, message: e.message }
        end
      end

      { status: :launched, artifact: artifact }
    end

    private

    def prepare_artifact_phase(artifact)
      # Transition through phases if needed
    end
  end
end
```

---

## Channel refactoring example

**Before** (599 lines):
```ruby
class AgentHubChannel < ApplicationCable::Channel
  def speak(data)
    content = data["content"]
    model = data["model"]

    # ... 150+ lines of inline logic
  end

  private

  def handle_chat(content, model, target_agent_id, client_agent_id)
    # ... 160+ lines of inline logic
  end
end
```

**After** (< 200 lines):
```ruby
class AgentHubChannel < ApplicationCable::Channel
  def speak(data)
    content = data["content"]
    model = data["model"]

    mention_data = AgentHub::MentionParser.call(content)
    target_agent_id = mention_data&.dig(:agent_id) || params[:agent_id]

    command = AgentHub::CommandParser.call(content)

    if command
      handle_command(command, target_agent_id)
    else
      handle_chat(content, model, target_agent_id)
    end
  end

  private

  def handle_chat(content, model, target_agent_id)
    conversation = find_or_create_conversation(target_agent_id)

    result = AgentHub::ChatHandler.new(
      user: current_user,
      conversation: conversation,
      broadcast_callback: method(:broadcast_to_agent)
    ).call(
      content: content,
      model: model,
      target_agent_id: target_agent_id,
      client_agent_id: params[:agent_id]
    )

    broadcast_result(result, params[:agent_id])
  end

  def handle_command(command_data, agent_id)
    artifact = find_active_artifact

    result = AgentHub::CommandExecutor.new(
      user: current_user,
      agent_id: agent_id
    ).execute(
      command: command_data[:command],
      args: command_data[:args],
      artifact: artifact
    )

    broadcast_result(result, agent_id)
  end

  def broadcast_to_agent(agent_id, payload)
    ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", payload)
  end

  def broadcast_result(result, agent_id)
    case result[:message_type]
    when :formatted
      broadcast_to_agent(agent_id, { type: "token", message_id: "msg-#{Time.now.to_i}", token: result[:content] })
    when :error
      broadcast_to_agent(agent_id, { type: "error", message: result[:message] })
    else
      # ... other message types
    end
  end
end
```

---

## Backward compatibility strategy

All existing client-side JavaScript remains unchanged:
- Same WebSocket message formats
- Same broadcast payloads
- Same subscription channels
- Same ActionCable API

The refactoring is **transparent to clients**.

---

## Testing strategy

### Unit tests (new)
- Test each service in isolation (no ActionCable)
- Mock dependencies (LLM client, database, artifact finder)
- Fast tests (< 0.1s each)

**New test files**:
- `test/services/agent_hub/chat_handler_test.rb`
- `test/services/agent_hub/command_executor_test.rb`
- `test/services/agent_hub/autonomous_command_service_test.rb`

### Integration tests (existing)
- Keep existing channel tests in `test/channels/agent_hub_channel_test.rb`
- Tests verify end-to-end flow (client → channel → service → broadcast)
- No changes to test assertions

### Acceptance criteria for testing
- All existing channel tests pass unchanged
- New service unit tests achieve 100% coverage
- Integration tests verify service delegation

---

## File structure after refactoring

```
app/channels/
  agent_hub_channel.rb (< 200 lines)

app/services/agent_hub/
  chat_handler.rb
  command_executor.rb
  autonomous_command_service.rb
  mention_parser.rb (existing)
  command_parser.rb (existing)
  workflow_bridge.rb (existing)
  smart_proxy_client.rb (existing)
```

---

## Acceptance criteria

- AC1: `AgentHubChannel` reduced to < 200 lines
- AC2: Three new service classes created in `agent_hub/` namespace
- AC3: All existing channel tests pass without modification
- AC4: New unit tests added for each service (100% coverage)
- AC5: No changes to client-side JavaScript or WebSocket protocol
- AC6: Business logic fully testable without ActionCable
- AC7: YARD documentation added to all services
- AC8: Code review confirms proper separation of concerns

---

## Risks and mitigation

### Risk: Breaking WebSocket communication
- **Mitigation**: Maintain exact broadcast formats; comprehensive integration tests
- **Validation**: Test with real WebSocket client; monitor staging

### Risk: Callback hell from streaming
- **Mitigation**: Use explicit broadcast_callback Proc; keep interface clean
- **Validation**: Test streaming behavior; ensure no memory leaks

### Risk: Lost ActionCable context
- **Mitigation**: Pass necessary context (user, agent_id) explicitly
- **Validation**: Verify authentication still works; test subscriptions

---

## Success metrics

- Lines of code: Reduced from 599 to < 200 lines (67% reduction)
- Test speed: Service tests run in < 1s (vs 5s+ for channel tests)
- Reusability: Business logic usable in controllers, jobs, rake tasks
- Developer feedback: Improved testability scores

---

## Out of scope

- Changing WebSocket protocol or message formats
- Modifying client-side JavaScript
- Adding new features
- Performance optimization (beyond preventing regression)
- Extracting MentionParser/CommandParser (already separate)

---

## Rollout plan

1. Create feature branch `refactor/extract-channel-logic`
2. Implement Steps 1-6 incrementally with tests
3. Code review with 2+ approvers
4. Test in staging environment with real WebSocket clients
5. Merge to main after CI passes
6. Monitor production WebSocket connections for 24 hours
7. Rollback if any issues detected (message delivery, authentication, streaming)
