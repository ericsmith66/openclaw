# PRD-0095: Message Bus

**PRD ID**: PRD-0095
**Status**: Draft
**Priority**: Critical
**Created**: 2026-02-26
**Milestone**: M1 (Tool Loop)
**Depends On**: PRD-0010

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/events/event-manager.ts` — Central event hub (30+ event types, dual IPC + Socket.IO transport)
- `src/main/task/task.ts:1252-1254` — `sendResponseCompleted()` event emission pattern
- `src/main/agent/agent.ts:915-930` — `onStepFinish` callback emitting step events
- `src/main/connector/connector-manager.ts` — Socket.IO connector for external consumers

**Agent-Forge Source Files** (existing integration to align with):
- `app/jobs/agent_dispatch_job.rb` — Solid Queue job dispatching prompts to AiderDesk
- `app/channels/agent_task_channel.rb` — ActionCable channel for per-task streaming
- `lib/aider_desk/event_relay.rb` — Bridges Socket.IO events → ActionCable
- `app/models/agent_task.rb` — PostgreSQL-backed task state machine

**Output Files** (Ruby gem):
- `lib/agent_desk/message_bus.rb` — Abstract bus interface
- `lib/agent_desk/message_bus/callback_bus.rb` — In-process adapter (default)
- `lib/agent_desk/message_bus/postgres_bus.rb` — PostgreSQL LISTEN/NOTIFY adapter
- `lib/agent_desk/message_bus/event.rb` — Typed event structs (Ruby 3.2 Data classes)
- `lib/agent_desk/message_bus/channel.rb` — Channel naming + pattern matching
- `spec/agent_desk/message_bus/callback_bus_spec.rb`
- `spec/agent_desk/message_bus/postgres_bus_spec.rb`
- `spec/agent_desk/message_bus/event_spec.rb`

---

## 1. Problem Statement

The agent framework needs a messaging layer so that:

1. **Agents can emit events** — response chunks, tool calls, completions, errors — in a structured way that any consumer can receive
2. **External systems can subscribe** — Agent-Forge's WorkflowEngine, browser UI (via Turbo Streams), chatbots, monitoring dashboards
3. **Agents can coordinate** — a QA agent observes a coder agent's output; a tax agent requests data from a home automation agent
4. **Human-in-the-loop flows work** — tool approval requests reach users and responses flow back to the waiting agent
5. **Everything is auditable** — events can be logged to a persistent store for replay, debugging, and analytics

The current design (PRD-0090) has only a single `on_message` callback lambda — no channels, no fan-out, no external transport, no event typing.

### Integration Context

This gem integrates into **Agent-Forge**, a Rails 8 app that orchestrates agents across multiple domains (software dev, tax/finance, home automation, security) and multiple execution backends (AiderDesk, SmartProxy, native `agent_desk` gem). Agent-Forge runs:

- **PostgreSQL** — database, the single shared infrastructure
- **Solid Queue** — background job processing (PostgreSQL-backed)
- **Solid Cable** — ActionCable adapter (PostgreSQL-backed)
- **Turbo Streams + DaisyUI** — real-time browser UI

The message bus must work **standalone** (for scripts using the gem directly) and **integrated** (when running inside Agent-Forge with PostgreSQL).

---

## 2. Design

### 2.1 Core MessageBus Interface

The bus provides two operations: **publish** and **subscribe**. It is adapter-based — the core interface has no external dependencies.

```ruby
# lib/agent_desk/message_bus.rb
module AgentDesk
  class MessageBus
    # Publish a typed event to a named channel
    # @param channel [String] dot-delimited channel name, e.g. "agent.qa.response.chunk"
    # @param event [AgentDesk::MessageBus::Event] typed event struct
    def publish(channel, event)
      raise NotImplementedError
    end

    # Subscribe to channels matching a pattern
    # @param pattern [String] dot-delimited pattern with optional wildcard, e.g. "agent.qa.*" or "workflow.*"
    # @yield [channel, event] called for each matching event
    def subscribe(pattern, &block)
      raise NotImplementedError
    end

    # Unsubscribe all listeners for a pattern
    def unsubscribe(pattern)
      raise NotImplementedError
    end

    # Unsubscribe all listeners
    def clear
      raise NotImplementedError
    end
  end
end
```

### 2.2 Event Types

Events are typed using Ruby 3.2 `Data` classes for immutability and pattern matching.

```ruby
# lib/agent_desk/message_bus/event.rb
module AgentDesk
  class MessageBus
    # Base event — all events share these fields
    Event = Data.define(
      :type,          # String — event type identifier
      :source,        # String — "agent_desk_gem", "aider_desk", "smart_proxy"
      :agent_id,      # String or nil
      :task_id,       # String or nil
      :timestamp,     # Time
      :payload        # Hash — event-specific data
    )

    # Convenience constructors for common event types
    module Events
      def self.response_chunk(agent_id:, task_id:, text:, source: "agent_desk_gem")
        Event.new(
          type: "response.chunk",
          source: source,
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { text: text }
        )
      end

      def self.response_complete(agent_id:, task_id:, content:, source: "agent_desk_gem")
        Event.new(
          type: "response.complete",
          source: source,
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { content: content }
        )
      end

      def self.tool_called(agent_id:, task_id:, tool_name:, arguments:, source: "agent_desk_gem")
        Event.new(
          type: "tool.called",
          source: source,
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { tool_name: tool_name, arguments: arguments }
        )
      end

      def self.tool_result(agent_id:, task_id:, tool_name:, output:, source: "agent_desk_gem")
        Event.new(
          type: "tool.result",
          source: source,
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { tool_name: tool_name, output: output }
        )
      end

      def self.agent_started(agent_id:, task_id:, profile_name:, source: "agent_desk_gem")
        Event.new(
          type: "agent.started",
          source: source,
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { profile_name: profile_name }
        )
      end

      def self.agent_completed(agent_id:, task_id:, message_count:, source: "agent_desk_gem")
        Event.new(
          type: "agent.completed",
          source: source,
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { message_count: message_count }
        )
      end

      def self.approval_request(agent_id:, task_id:, tool_name:, description:)
        Event.new(
          type: "approval.request",
          source: "agent_desk_gem",
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { tool_name: tool_name, description: description }
        )
      end

      def self.approval_response(agent_id:, task_id:, approved:, reason: nil)
        Event.new(
          type: "approval.response",
          source: "user",
          agent_id: agent_id,
          task_id: task_id,
          timestamp: Time.now,
          payload: { approved: approved, reason: reason }
        )
      end
    end
  end
end
```

### 2.3 Channel Naming & Pattern Matching

Channels use dot-delimited hierarchical names. Subscriptions support prefix wildcards.

```ruby
# lib/agent_desk/message_bus/channel.rb
module AgentDesk
  class MessageBus
    module Channel
      # Check if a channel matches a subscription pattern
      # "agent.qa.response.chunk" matches:
      #   "agent.qa.response.chunk"  (exact)
      #   "agent.qa.response.*"      (wildcard last segment)
      #   "agent.qa.*"               (wildcard from 3rd segment)
      #   "agent.*"                  (wildcard from 2nd segment)
      #   "*"                        (match everything)
      def self.matches?(pattern, channel)
        return true if pattern == "*"
        return true if pattern == channel

        pattern_parts = pattern.split(".")
        channel_parts = channel.split(".")

        pattern_parts.each_with_index do |part, i|
          return true if part == "*"
          return false if i >= channel_parts.length
          return false if part != channel_parts[i]
        end

        pattern_parts.length == channel_parts.length
      end
    end
  end
end
```

### 2.4 CallbackBus (Default — No Dependencies)

For standalone scripts and testing. Pure in-process pub/sub.

```ruby
# lib/agent_desk/message_bus/callback_bus.rb
module AgentDesk
  class MessageBus
    class CallbackBus < MessageBus
      def initialize
        @subscriptions = {}
        @mutex = Mutex.new
      end

      def publish(channel, event)
        @mutex.synchronize do
          @subscriptions.each do |pattern, callbacks|
            next unless Channel.matches?(pattern, channel)
            callbacks.each { |cb| cb.call(channel, event) }
          end
        end
      end

      def subscribe(pattern, &block)
        @mutex.synchronize do
          @subscriptions[pattern] ||= []
          @subscriptions[pattern] << block
        end
      end

      def unsubscribe(pattern)
        @mutex.synchronize { @subscriptions.delete(pattern) }
      end

      def clear
        @mutex.synchronize { @subscriptions.clear }
      end
    end
  end
end
```

### 2.5 PostgresBus (Agent-Forge Integration)

For use inside Agent-Forge (or any app with PostgreSQL). Uses LISTEN/NOTIFY for cross-process fan-out.

```ruby
# lib/agent_desk/message_bus/postgres_bus.rb
module AgentDesk
  class MessageBus
    class PostgresBus < MessageBus
      # @param connection_pool [ActiveRecord::ConnectionAdapters::ConnectionPool]
      #   or a Proc that returns a PG::Connection
      # @param logger [Logger, nil]
      def initialize(connection_pool:, logger: nil)
        @connection_pool = connection_pool
        @logger = logger
        @subscriptions = {}
        @mutex = Mutex.new
        @listening = false
        @listener_thread = nil
      end

      def publish(channel, event)
        payload = JSON.generate({
          type: event.type,
          source: event.source,
          agent_id: event.agent_id,
          task_id: event.task_id,
          timestamp: event.timestamp.iso8601,
          payload: event.payload
        })

        # NOTIFY on the normalized channel name
        # PostgreSQL channel names can't contain dots — use underscores
        pg_channel = normalize_channel(channel)

        @connection_pool.with_connection do |conn|
          conn.execute("NOTIFY #{conn.quote_column_name(pg_channel)}, #{conn.quote(payload)}")
        end

        # Also notify in-process subscribers (for same-process listeners)
        notify_local(channel, event)
      end

      def subscribe(pattern, &block)
        @mutex.synchronize do
          @subscriptions[pattern] ||= []
          @subscriptions[pattern] << block
        end

        # Start the listener thread if not already running
        ensure_listening
      end

      def unsubscribe(pattern)
        @mutex.synchronize { @subscriptions.delete(pattern) }
      end

      def clear
        @mutex.synchronize { @subscriptions.clear }
        stop_listening
      end

      def stop
        stop_listening
      end

      private

      def normalize_channel(channel)
        # PostgreSQL identifiers: replace dots with double underscores
        channel.gsub(".", "__")
      end

      def denormalize_channel(pg_channel)
        pg_channel.gsub("__", ".")
      end

      def notify_local(channel, event)
        @mutex.synchronize do
          @subscriptions.each do |pattern, callbacks|
            next unless Channel.matches?(pattern, channel)
            callbacks.each { |cb| cb.call(channel, event) }
          end
        end
      end

      def ensure_listening
        return if @listening

        @listening = true
        @listener_thread = Thread.new { listen_loop }
        @listener_thread.abort_on_exception = false
      end

      def stop_listening
        @listening = false
        @listener_thread&.kill
        @listener_thread = nil
      end

      def listen_loop
        # Use a dedicated raw PG connection for LISTEN (can't share with ActiveRecord pool)
        raw_conn = create_raw_connection

        # LISTEN on a wildcard-ish approach: listen to a "bus" channel
        # and use application-level routing
        raw_conn.exec("LISTEN agent_desk_bus")

        while @listening
          raw_conn.wait_for_notify(1) do |_pg_channel, _pid, payload|
            process_notification(payload)
          end
        end
      rescue => e
        @logger&.error("[PostgresBus] Listener error: #{e.message}")
        retry if @listening
      ensure
        raw_conn&.close
      end

      def create_raw_connection
        db_config = @connection_pool.db_config.configuration_hash
        PG.connect(
          host: db_config[:host] || "localhost",
          port: db_config[:port] || 5432,
          dbname: db_config[:database],
          user: db_config[:username],
          password: db_config[:password]
        )
      end

      def process_notification(raw_payload)
        data = JSON.parse(raw_payload, symbolize_names: true)
        channel = data.delete(:_channel)
        event = Event.new(**data.slice(:type, :source, :agent_id, :task_id, :payload).merge(
          timestamp: Time.parse(data[:timestamp])
        ))

        notify_local(channel, event)
      rescue JSON::ParserError, ArgumentError => e
        @logger&.warn("[PostgresBus] Failed to parse notification: #{e.message}")
      end
    end
  end
end
```

### 2.6 Gem Configuration

```ruby
# lib/agent_desk/configuration.rb (extend existing)
module AgentDesk
  class Configuration
    attr_accessor :message_bus

    def initialize
      @message_bus = MessageBus::CallbackBus.new  # default: in-process
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def bus
      configuration.message_bus
    end
  end
end
```

### 2.7 Integration with Runner (PRD-0090)

The Runner publishes events through the bus instead of (or in addition to) the `on_message` callback.

```ruby
# In Runner#run — replace bare on_message with bus publishing
def run(profile:, prompt:, project_dir:, messages: [], ...)
  agent_id = profile.id || SecureRandom.uuid
  task_id = SecureRandom.uuid

  # Publish agent started
  AgentDesk.bus.publish(
    "agent.#{agent_id}.started",
    MessageBus::Events.agent_started(agent_id: agent_id, task_id: task_id, profile_name: profile.name)
  )

  # ... in the loop, for each assistant message:
  AgentDesk.bus.publish(
    "agent.#{agent_id}.response.chunk",
    MessageBus::Events.response_chunk(agent_id: agent_id, task_id: task_id, text: chunk)
  )

  # ... for each tool call:
  AgentDesk.bus.publish(
    "agent.#{agent_id}.tool.called",
    MessageBus::Events.tool_called(agent_id: agent_id, task_id: task_id, tool_name: name, arguments: args)
  )

  # ... on completion:
  AgentDesk.bus.publish(
    "agent.#{agent_id}.completed",
    MessageBus::Events.agent_completed(agent_id: agent_id, task_id: task_id, message_count: conversation.length)
  )
end
```

---

## 3. Channel Schema

```
# Agent lifecycle
agent.{agent_id}.started
agent.{agent_id}.completed
agent.{agent_id}.failed

# Streaming
agent.{agent_id}.response.chunk
agent.{agent_id}.response.complete

# Tool activity
agent.{agent_id}.tool.called
agent.{agent_id}.tool.result
agent.{agent_id}.tool.error

# Inter-agent delegation
agent.{agent_id}.delegate
agent.{agent_id}.delegate.result

# Human interaction
system.approval.request
system.approval.response
system.question.ask
system.question.answer

# Task lifecycle
task.{task_id}.created
task.{task_id}.dispatched
task.{task_id}.completed
task.{task_id}.failed

# Workflow (consumed by Agent-Forge WorkflowEngine)
workflow.{run_id}.phase.started
workflow.{run_id}.phase.completed
workflow.{run_id}.gate.pending
workflow.{run_id}.gate.passed
workflow.{run_id}.gate.failed
workflow.{run_id}.escalation

# Cross-domain context sharing
context.{project_id}.file.changed
context.share.request
context.share.response
```

---

## 4. Acceptance Criteria

- ✅ `CallbackBus` — publish/subscribe works in-process with no external dependencies
- ✅ `CallbackBus` — wildcard pattern matching (`agent.*`, `agent.qa.*`, `*`)
- ✅ `CallbackBus` — thread-safe (Mutex-protected)
- ✅ `PostgresBus` — publish sends NOTIFY to PostgreSQL
- ✅ `PostgresBus` — subscribe receives NOTIFY events on a background thread
- ✅ `PostgresBus` — also notifies in-process subscribers (local + remote fan-out)
- ✅ `PostgresBus` — handles connection drops gracefully (auto-reconnect)
- ✅ `Event` — Data class with immutable fields, JSON serializable
- ✅ `Events` module — convenience constructors for all common event types
- ✅ `Channel.matches?` — correct pattern matching for all wildcard cases
- ✅ `AgentDesk.bus` — global accessor defaults to `CallbackBus`
- ✅ `AgentDesk.configure` — allows swapping in `PostgresBus`
- ✅ Runner (PRD-0090) publishes all lifecycle events through the bus
- ✅ Backward compatible — existing `on_message` callback still works (bus is additive)

---

## 5. Test Plan

```ruby
RSpec.describe AgentDesk::MessageBus::CallbackBus do
  let(:bus) { described_class.new }

  it "delivers events to matching subscribers" do
    received = []
    bus.subscribe("agent.qa.*") { |channel, event| received << [channel, event] }

    event = AgentDesk::MessageBus::Events.response_chunk(agent_id: "qa", task_id: "t1", text: "Hello")
    bus.publish("agent.qa.response.chunk", event)

    expect(received.length).to eq(1)
    expect(received.first[0]).to eq("agent.qa.response.chunk")
    expect(received.first[1].payload[:text]).to eq("Hello")
  end

  it "does not deliver events to non-matching subscribers" do
    received = []
    bus.subscribe("agent.coder.*") { |channel, event| received << [channel, event] }

    event = AgentDesk::MessageBus::Events.response_chunk(agent_id: "qa", task_id: "t1", text: "Hello")
    bus.publish("agent.qa.response.chunk", event)

    expect(received).to be_empty
  end

  it "supports exact channel matching" do
    received = []
    bus.subscribe("system.approval.request") { |_, e| received << e }

    bus.publish("system.approval.request", AgentDesk::MessageBus::Events.approval_request(
      agent_id: "qa", task_id: "t1", tool_name: "bash", description: "Run tests"
    ))

    expect(received.length).to eq(1)
  end

  it "supports global wildcard" do
    received = []
    bus.subscribe("*") { |_, e| received << e }

    bus.publish("anything.here", AgentDesk::MessageBus::Event.new(
      type: "test", source: "test", agent_id: nil, task_id: nil,
      timestamp: Time.now, payload: {}
    ))

    expect(received.length).to eq(1)
  end

  it "is thread-safe under concurrent publish/subscribe" do
    # Stress test with 10 threads publishing and subscribing concurrently
    errors = []
    threads = 10.times.map do |i|
      Thread.new do
        bus.subscribe("stress.#{i}.*") { |_, _| }
        100.times do
          bus.publish("stress.#{i}.test", AgentDesk::MessageBus::Event.new(
            type: "stress", source: "test", agent_id: nil, task_id: nil,
            timestamp: Time.now, payload: { i: i }
          ))
        end
      rescue => e
        errors << e
      end
    end
    threads.each(&:join)
    expect(errors).to be_empty
  end
end

RSpec.describe AgentDesk::MessageBus::Channel do
  describe ".matches?" do
    it { expect(described_class.matches?("agent.qa.response.chunk", "agent.qa.response.chunk")).to be true }
    it { expect(described_class.matches?("agent.qa.*", "agent.qa.response.chunk")).to be true }
    it { expect(described_class.matches?("agent.*", "agent.qa.response.chunk")).to be true }
    it { expect(described_class.matches?("*", "anything")).to be true }
    it { expect(described_class.matches?("agent.coder.*", "agent.qa.response.chunk")).to be false }
    it { expect(described_class.matches?("agent.qa.response.chunk", "agent.qa.response")).to be false }
  end
end

RSpec.describe AgentDesk::MessageBus::Event do
  it "is immutable" do
    event = AgentDesk::MessageBus::Events.response_chunk(agent_id: "qa", task_id: "t1", text: "Hello")
    expect { event.instance_variable_set(:@type, "changed") }.to raise_error(FrozenError)
  end

  it "serializes to JSON" do
    event = AgentDesk::MessageBus::Events.tool_called(
      agent_id: "qa", task_id: "t1", tool_name: "bash", arguments: { command: "ls" }
    )
    json = JSON.generate(event.to_h)
    parsed = JSON.parse(json, symbolize_names: true)
    expect(parsed[:type]).to eq("tool.called")
    expect(parsed[:payload][:tool_name]).to eq("bash")
  end
end
```

---

## 6. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `AgentDesk::MessageBus` | `EventManager` (`src/main/events/event-manager.ts`) |
| `CallbackBus` | IPC transport (`sendToMainWindow`) |
| `PostgresBus` | Socket.IO transport (`broadcastToEventConnectors`) |
| `Event` data classes | Typed event data interfaces (`ResponseChunkData`, etc.) |
| `Channel.matches?` | Socket.IO event type filtering |
| `Events.response_chunk` | `sendResponseChunk(data)` |
| `Events.tool_called` | `sendTool(data)` |
| `Events.agent_completed` | `sendTaskCompleted(data)` |
| `Events.approval_request` | `sendAskQuestion(questionData)` |

---

## 7. Agent-Forge Integration Notes

This PRD defines the **gem-side** bus interface and adapters. The Agent-Forge side (wiring the bus into WorkflowEngine, ActionCable, Turbo Streams, and the `agent_events` table) will be specified in **Epic 4B PRDs**. Key integration points:

1. **Agent-Forge configures `PostgresBus`** in `config/initializers/agent_desk.rb`
2. **`AgentDispatchJob`** subscribes to agent channels to relay events to `AgentTaskChannel` (ActionCable)
3. **WorkflowEngine** subscribes to `workflow.*` channels for gate decisions
4. **`agent_events` table** is populated by an Agent-Forge-side subscriber (not in the gem)
5. **AiderDesk bridge** — `EventRelay` forwards Socket.IO events from AiderDesk by publishing them to the `PostgresBus`

---

**Next**: PRD-0100 (Memory System) and PRD-0110 (Todo/Task/Helper tools) add the remaining tool groups.
