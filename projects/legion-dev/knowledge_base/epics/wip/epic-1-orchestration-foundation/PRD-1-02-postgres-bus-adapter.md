#### PRD-1-02: PostgresBus Adapter

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-02-postgres-bus-adapter-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Create `Legion::PostgresBus`, a MessageBus adapter that bridges the `agent_desk` gem's in-memory event system with PostgreSQL persistence. Every event the gem publishes during an agent run (tool calls, responses, budget warnings, handoffs) gets persisted as a `WorkflowEvent` record, providing a complete forensic trail of every agent execution.

The adapter implements `AgentDesk::MessageBus::MessageBusInterface` (4 abstract methods), wraps a `CallbackBus` for in-process subscriber delivery (needed by orchestrator hooks in PRD-1-05), and includes a Solid Cable broadcast stub that will be activated in Epic 4 for real-time UI updates.

---

### Requirements

#### Functional

**PostgresBus class (`app/services/legion/postgres_bus.rb`):**
- Implements `AgentDesk::MessageBus::MessageBusInterface` (include the module)
- Constructor accepts `workflow_run:` — the WorkflowRun record to associate events with
- Internally creates a `AgentDesk::MessageBus::CallbackBus` for in-process subscriber management

**`publish(channel, event)` method:**
1. Persist event to database: Create `WorkflowEvent` record with:
   - `workflow_run_id` from constructor
   - `event_type` from `event.type`
   - `channel` from the channel argument
   - `agent_id` from `event.agent_id`
   - `task_id` from `event.task_id`
   - `payload` from `event.payload` (already a hash)
   - `recorded_at` from `event.timestamp`
2. Forward to CallbackBus: `@callback_bus.publish(channel, event)` — delivers to in-process subscribers (orchestrator hooks)
3. Solid Cable broadcast stub: `broadcast_event(channel, event)` — private method, currently a no-op with a TODO comment for Epic 4
4. Error handling: If DB write fails, log the error but still deliver to CallbackBus (event observation must not break the agent run)

**`subscribe(channel_pattern, &block)` method:**
- Delegates to `@callback_bus.subscribe(channel_pattern, &block)`
- Supports wildcard patterns (e.g., `agent.*`, `tool.*`) — handled by CallbackBus/Channel

**`unsubscribe(subscription_id)` method:**
- Delegates to `@callback_bus.unsubscribe(subscription_id)`

**`clear` method:**
- Delegates to `@callback_bus.clear`
- Does NOT delete WorkflowEvent records (persistence is permanent)

**Configuration options:**
- `skip_event_types:` — array of event types to skip persisting (e.g., `["response.chunk"]` for high-frequency streaming events). Default: `[]` (persist everything).
- `batch_mode:` — boolean, default false. When true, buffers events and writes in a single INSERT at the end of the run. For future optimization if `response.chunk` throughput becomes an issue.

#### Non-Functional

- Thread-safe: The CallbackBus is already mutex-protected. PostgresBus must not introduce additional thread-safety issues.
- Resilient: Database write failures must not crash the agent run. Log and continue.
- Performance: Single INSERT per event is acceptable for Epic 1. Batch mode is a stub for future optimization.
- The adapter must work with any gem event — it should not assume a fixed set of event types.

#### Rails / Implementation Notes

- Service: `app/services/legion/postgres_bus.rb` (namespaced under `Legion::`)
- The gem's `Event` is a `Data.define` struct with: `type`, `source`, `agent_id`, `task_id`, `timestamp`, `payload`
- The gem's `CallbackBus` handles subscriber matching via `Channel.match?(pattern, channel)`
- The gem's `MessageBusInterface` defines 4 abstract methods: `publish`, `subscribe`, `unsubscribe`, `clear`
- Solid Cable broadcast will use `ActionCable.server.broadcast` in Epic 4 — stub should make this obvious

---

### Error Scenarios & Fallbacks

- Database write failure during `publish` → Log error with `Rails.logger.error`, include event type and workflow_run_id. Still forward to CallbackBus so hooks fire. Do NOT raise.
- WorkflowRun record deleted mid-run → Foreign key violation on INSERT. Caught by rescue, logged, CallbackBus delivery continues.
- Malformed event payload (not serializable to JSON) → ActiveRecord will raise on JSONB column. Catch, log the event type, store `{ "error": "payload not serializable" }` as payload.
- Very large payload (e.g., full file content in tool.result) → PostgreSQL handles large JSONB values. No truncation in Epic 1. Monitor in PRD-1-08 validation.

---

### Architectural Context

PostgresBus sits between the `agent_desk` gem's Runner and Legion's database. It's the bridge that turns ephemeral in-process events into queryable history.

```
Runner.run()
  → publishes events via @message_bus
  → PostgresBus.publish(channel, event)
      → INSERT into workflow_events (persistence)
      → CallbackBus.publish(channel, event) (in-process delivery)
      → broadcast_event(channel, event) (Solid Cable stub)
```

**Why wrap CallbackBus instead of replacing it?**
The orchestrator hooks (PRD-1-05) need in-process, synchronous event delivery during `runner.run()`. They subscribe to events and can return `HookResult(blocked: true)` to stop tool execution. Database persistence alone can't provide this — by the time you query the DB, the moment has passed. The CallbackBus provides the synchronous delivery channel; PostgresBus adds persistence on top.

**Non-goals:**
- No Solid Cable integration (Epic 4)
- No event replay/streaming from DB
- No event aggregation or analytics

---

### Acceptance Criteria

- [ ] AC1: `Legion::PostgresBus` includes `AgentDesk::MessageBus::MessageBusInterface`
- [ ] AC2: `publish(channel, event)` creates a `WorkflowEvent` record with correct field mapping
- [ ] AC3: `publish` forwards to internal CallbackBus after DB write
- [ ] AC4: Subscribers registered via `subscribe` receive events through CallbackBus
- [ ] AC5: Wildcard channel patterns work (e.g., `agent.*` matches `agent.started`)
- [ ] AC6: `unsubscribe` removes subscriber from CallbackBus
- [ ] AC7: `clear` removes all subscribers but does NOT delete WorkflowEvent records
- [ ] AC8: Database write failure is logged but does not raise — CallbackBus delivery still occurs
- [ ] AC9: `skip_event_types` option prevents specified event types from being persisted (but still delivered to CallbackBus)
- [ ] AC10: Solid Cable broadcast stub exists as a private method with Epic 4 TODO
- [ ] AC11: All event types from the gem (11 types) can be persisted without error
- [ ] AC12: `rails test` — zero failures for PostgresBus tests

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/postgres_bus_test.rb`:
  - Creates WorkflowEvent on publish with correct field mapping (event_type, channel, agent_id, task_id, payload, recorded_at)
  - Forwards event to CallbackBus subscribers
  - Wildcard subscription receives matching events
  - Unsubscribe stops delivery
  - Clear removes subscribers, does not delete DB records
  - DB failure logged but does not raise
  - DB failure still delivers to CallbackBus
  - `skip_event_types` prevents DB write for skipped types
  - `skip_event_types` still delivers skipped types to CallbackBus
  - Handles all 11 gem event types (create one of each, verify all persisted)
  - Malformed payload stored with error marker

#### Integration (Minitest)

- `test/integration/postgres_bus_integration_test.rb`:
  - Full cycle: Create WorkflowRun → Create PostgresBus → Publish multiple events → Verify WorkflowEvent records in DB → Verify subscriber received all events
  - Event ordering: Publish 10 events rapidly, verify `recorded_at` ordering preserved in DB
  - WorkflowEvent.by_type scope returns correct subset after mixed event publishing

#### System / Smoke

- N/A — PostgresBus is an internal service, not directly user-facing. Validated through PRD-1-04 CLI dispatch.

---

### Manual Verification

1. Open `rails console`:
   ```ruby
   project = Project.create!(name: "Test", path: "/tmp/test")
   team = AgentTeam.create!(name: "ROR", project: project)
   tm = team.team_memberships.create!(config: { "id" => "test", "name" => "Test", "provider" => "openai", "model" => "gpt-4" })
   run = WorkflowRun.create!(project: project, team_membership: tm, prompt: "test", status: :running)
   bus = Legion::PostgresBus.new(workflow_run: run)

   # Publish a test event
   event = AgentDesk::MessageBus::Events.agent_started(agent_id: "test", task_id: nil)
   bus.publish("agent.started", event)

   # Verify persistence
   WorkflowEvent.last
   # => #<WorkflowEvent event_type: "agent.started", ...>
   ```
2. Run `rails test test/services/legion/` — expected: all tests pass

**Expected:** Events published through PostgresBus are persisted to WorkflowEvent table and delivered to in-process subscribers.

---

### Dependencies

- **Blocked By:** PRD-1-01 (Schema Foundation — needs WorkflowEvent and WorkflowRun models)
- **Blocks:** PRD-1-04 (CLI Dispatch uses PostgresBus), PRD-1-05 (Hooks subscribe via PostgresBus)

---

### Estimated Complexity

**Medium** — Clear interface contract from gem, straightforward delegation pattern. Main complexity is error resilience and ensuring DB failures don't break agent runs.

**Effort:** 1 week

### Agent Assignment

**Rails Lead** (DeepSeek Reasoner) — primary implementer
