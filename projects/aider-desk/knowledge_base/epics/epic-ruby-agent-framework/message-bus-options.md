# Message Bus Architecture — Options & Recommendation

**Created**: 2026-02-26
**Updated**: 2026-02-26 (Revised with Agent-Forge context)

---

## The Real System

The Ruby Agent Framework (`agent_desk` gem) is **not a standalone tool**. It integrates into **Agent-Forge**, a Rails 8 orchestration hub that coordinates AI agents across multiple domains and multiple execution backends.

### The Participants

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Agent-Forge                                   │
│                    (Rails 8 / PostgreSQL / Solid Queue)              │
│                                                                      │
│  Domains:                    Execution Backends:                     │
│  ├── Software Dev (RoR)      ├── AiderDesk (coding via Electron)    │
│  ├── Software Dev (Swift)    ├── SmartProxy (reasoning via LLMs)    │
│  ├── Software Dev (Python)   └── agent_desk gem (native Ruby)       │
│  ├── Tax & Finance                                                   │
│  ├── Home Automation                                                 │
│  └── Security                                                        │
│                                                                      │
│  Sub-projects (in projects/):                                        │
│  ├── aider-desk          (this repo - Electron app)                 │
│  ├── eureka-homekit       (home automation Rails app)               │
│  ├── nextgen-plaid        (financial Rails app)                     │
│  ├── SmartProxy           (LLM routing proxy)                       │
│  ├── overwatch            (monitoring)                              │
│  └── prefab               (feature flags)                           │
│                                                                      │
│  Infrastructure already running:                                     │
│  ├── PostgreSQL (database)                                          │
│  ├── Solid Queue (background jobs - PostgreSQL-backed)              │
│  ├── Solid Cable (ActionCable - PostgreSQL-backed)                  │
│  ├── Solid Cache (caching - PostgreSQL-backed)                      │
│  └── Turbo Streams + DaisyUI (real-time UI)                        │
└─────────────────────────────────────────────────────────────────────┘
```

### What Already Exists (Epic 4A — Walking Skeleton)

Agent-Forge **already has** a working integration pattern:

1. **`AiderDesk::AgentManager`** — Ruby client for AiderDesk REST API + Socket.IO events
2. **`AgentDispatchJob`** — Solid Queue job that dispatches prompts to AiderDesk and waits for results
3. **`AgentTaskChannel`** — ActionCable channel streaming per-task events to the browser via Turbo
4. **`AiderDesk::EventRelay`** — Bridges Socket.IO events from AiderDesk → ActionCable → browser
5. **`AgentTask` model** — PostgreSQL-backed state machine (`queued → running → completed/failed`)
6. **`Coordinator`** — Handles `/agent <prompt>` chat commands, routes to dispatch job

### What's Coming (Epic 4B — Workflow Engine)

Epic 4B adds the **WorkflowEngine** — a server-side state machine that enforces the RULES.md 14-phase lifecycle. Key additions:

1. **`WorkflowEngine`** — Sequences phases (Φ1-Φ13), enforces quality gates
2. **`TaskRouter`** — Routes phases to AiderDesk (coding) vs SmartProxy (reasoning)
3. **`AgentProfile` model** — DB-managed profiles with skills, rules, model tier, routing config
4. **`PromptBuilder`** — Constructs phase-specific prompts from DB templates + context
5. **`ResultEvaluator`** — Parses agent output for gate decisions (QA score ≥90, architect approval)
6. **Human-in-the-loop gates** — UI for approval/feedback phases
7. **Multi-domain agent configs** — ror, swift, python, devops, tax, home-automation, security

### Critical Design Decision from Epic 4B

> "**Agent-Forge is the orchestrator.** AiderDesk and SmartProxy are execution backends. Agents receive focused, single-purpose prompts and return results. They don't know about the 14-phase workflow."

This means the message bus doesn't just connect agents — it connects **Agent-Forge's WorkflowEngine** to multiple execution backends and to the user's browser.

---

## What the Message Bus Must Connect

```
                    ┌──────────────────────┐
                    │   Browser / Turbo    │
                    │  (DaisyUI + Streams)  │
                    └──────────┬───────────┘
                               │ ActionCable / Turbo Streams
                               │
┌──────────────────────────────┼──────────────────────────────┐
│               Agent-Forge (Rails 8)                          │
│                              │                               │
│  ┌──────────────┐  ┌────────┴────────┐  ┌───────────────┐  │
│  │ WorkflowEngine│  │  Message Bus    │  │ Coordinator   │  │
│  │ (state machine)│─▶│                │◀─│ (/agent, etc) │  │
│  └──────────────┘  │  Channels:      │  └───────────────┘  │
│                     │  agent.*        │                      │
│  ┌──────────────┐  │  workflow.*     │  ┌───────────────┐  │
│  │ PromptBuilder│  │  system.*      │  │ ResultEvaluator│  │
│  │              │─▶│  task.*        │◀─│               │  │
│  └──────────────┘  │  ui.*          │  └───────────────┘  │
│                     └──┬─────┬──┬───┘                      │
│                        │     │  │                           │
└────────────────────────┼─────┼──┼───────────────────────────┘
                         │     │  │
              ┌──────────┘     │  └──────────┐
              ▼                ▼              ▼
     ┌────────────┐   ┌────────────┐  ┌────────────┐
     │ AiderDesk   │   │ SmartProxy │  │ agent_desk │
     │ (Electron)  │   │ (LLM proxy)│  │ (Ruby gem) │
     │ Socket.IO   │   │ HTTP API   │  │ in-process │
     └────────────┘   └────────────┘  └────────────┘
```

### The Five Communication Patterns

| # | Pattern | Example | Required Properties |
|---|---------|---------|-------------------|
| 1 | **Command → Backend** | WorkflowEngine dispatches "implement this PRD" to AiderDesk | Durable, retryable, routable |
| 2 | **Backend → Streaming** | AiderDesk streams response tokens back to browser | Real-time, low-latency, lossy OK |
| 3 | **Backend → Result** | Agent completes, returns structured result for gate evaluation | Durable, parseable |
| 4 | **Human ↔ Agent** | Approval request → human reviews → approve/reject | Persistent, resumable, bidirectional |
| 5 | **Agent ↔ Agent** | Tax agent needs home automation data; QA agent reviews coder's output | Cross-domain, context-sharing |

---

## Revised Options (with Agent-Forge Context)

### ~~Option 1: In-Process Pub/Sub (Wisper/dry-events)~~ — ELIMINATED

Single-process only. Agent-Forge needs to communicate with AiderDesk (separate Node process), SmartProxy (separate process), and potentially the `agent_desk` gem running in Solid Queue workers. Eliminated.

### ~~Option 5: External Broker (RabbitMQ/Kafka)~~ — ELIMINATED

Agent-Forge already runs PostgreSQL + Solid Queue + Solid Cable. Adding RabbitMQ would be a redundant broker. Eliminated.

### Option A: PostgreSQL-Native Stack (RECOMMENDED)

**You already have all the infrastructure.** The message bus is built from components already running:

| Need | Solution | Already Running? |
|------|----------|:---:|
| Durable task dispatch | **Solid Queue** (Active Job on PostgreSQL) | ✅ |
| Real-time browser streaming | **Solid Cable** (ActionCable on PostgreSQL) | ✅ |
| Real-time backend-to-backend | **PostgreSQL LISTEN/NOTIFY** | ✅ (built into pg) |
| Event log / audit trail | **PostgreSQL table** (`agent_events`) | ✅ (just a migration) |
| Cross-process fan-out | **PostgreSQL LISTEN/NOTIFY** | ✅ |
| Human-in-the-loop persistence | **PostgreSQL** (`workflow_runs`, `agent_tasks`) | ✅ |

**Architecture**:

```ruby
# Agent-Forge already has these layers:

# Layer 1: Durable dispatch (ALREADY EXISTS — AgentDispatchJob)
AgentDispatchJob.perform_later(prompt:, project_id:, ...)

# Layer 2: Real-time UI streaming (ALREADY EXISTS — AgentTaskChannel)
ActionCable.server.broadcast("task_#{id}", { type: "chunk", text: token })

# Layer 3: Cross-process events (NEW — thin wrapper around pg LISTEN/NOTIFY)
AgentForge::MessageBus.publish("agent.qa.response.complete", payload)
AgentForge::MessageBus.subscribe("agent.*.response.*") { |event| ... }

# Layer 4: Queryable event log (NEW — PostgreSQL table)
AgentEvent.create!(channel: "agent.qa.tool.called", payload: { tool: "bash", args: "..." })
```

**What's new vs what's already built**:

| Component | Status | Effort |
|-----------|--------|--------|
| Solid Queue dispatch | ✅ Exists (`AgentDispatchJob`) | 0 |
| ActionCable streaming | ✅ Exists (`AgentTaskChannel`) | 0 |
| EventRelay (Socket.IO → ActionCable) | ✅ Exists (`AiderDesk::EventRelay`) | 0 |
| `AgentForge::MessageBus` (LISTEN/NOTIFY wrapper) | 🆕 New | ~2 days |
| `agent_events` table + model | 🆕 New | ~1 day |
| AiderDesk bridge (Socket.IO ↔ LISTEN/NOTIFY) | 🆕 New | ~2 days |
| SmartProxy bridge (HTTP callback → LISTEN/NOTIFY) | 🆕 New | ~1 day |
| `agent_desk` gem transport adapter | 🆕 New | ~1 day |
| Channel schema + event types | 🆕 New | ~1 day |

**Total new work: ~8 days** — and it sits on infrastructure that's already running and maintained.

### Option B: Redis Pub/Sub + Streams

Add Redis as a dedicated message broker alongside PostgreSQL.

**Pros**: Slightly lower latency for pub/sub (~0.5ms vs ~1ms for LISTEN/NOTIFY). Richer pub/sub features (patterns, consumer groups). Familiar to many developers.

**Cons**: 
- **New infrastructure** — Redis needs to run, be monitored, backed up
- **Redundant** — Solid Queue, Solid Cable, and Solid Cache already provide everything Redis would, on PostgreSQL
- **Conflicts with Rails 8 philosophy** — Rails 8 explicitly moved to Solid Queue/Cable/Cache to *eliminate* Redis. Adding it back goes against the grain.
- **Two sources of truth** — Events in Redis + state in PostgreSQL = sync complexity

**Verdict**: Only choose this if PostgreSQL LISTEN/NOTIFY proves insufficient at scale (>1000 events/second). For Agent-Forge's agent orchestration workload, PostgreSQL is more than adequate.

### Option C: Async Channels (fiber-based)

Use Ruby's `async` gem for concurrent agent execution within a single process.

**Verdict**: Doesn't solve cross-process communication (AiderDesk, SmartProxy). Could be useful *inside* the `agent_desk` gem for concurrent tool execution, but doesn't replace the bus. Not eliminated but **orthogonal** — it's a runtime pattern, not a messaging pattern.

---

## Recommendation: Option A — PostgreSQL-Native Stack

### Why This Wins

1. **Zero new infrastructure** — Everything runs on PostgreSQL, which is already your database, job queue, cable adapter, and cache backend. No Redis, no RabbitMQ, no NATS.

2. **You're 60% built** — Solid Queue dispatch, ActionCable streaming, EventRelay, AgentTask model — all exist from Epic 4A. The message bus is the remaining 40%.

3. **Turbo Streams integration is native** — Agent events published to ActionCable channels render directly as Turbo Stream updates in DaisyUI components. No custom WebSocket handling needed.

4. **Works for ALL your domains** — Tax agents, home automation agents, security agents, coding agents — they all publish to the same bus. The WorkflowEngine subscribes to the channels it needs. A tax agent doesn't need to know about AiderDesk.

5. **Queryable audit trail** — `SELECT * FROM agent_events WHERE channel LIKE 'workflow.%' AND created_at > '2026-02-26'` — try doing that with Redis pub/sub.

6. **Aligns with Epic 4B** — The WorkflowEngine needs durable state (Solid Queue), real-time UI (Solid Cable), and event-driven transitions (LISTEN/NOTIFY). The bus provides all three.

### Proposed Channel Schema

```
# Agent lifecycle (any agent, any domain)
agent.{agent_id}.started
agent.{agent_id}.completed
agent.{agent_id}.failed

# Streaming (real-time tokens from LLM)
agent.{agent_id}.response.chunk        → also routed to ActionCable
agent.{agent_id}.response.complete

# Tool activity
agent.{agent_id}.tool.called
agent.{agent_id}.tool.result
agent.{agent_id}.tool.error

# Workflow (Epic 4B WorkflowEngine)
workflow.{run_id}.phase.started         — e.g., Φ9 architect review started
workflow.{run_id}.phase.completed       — phase finished with result
workflow.{run_id}.gate.pending          — waiting for human or auto-evaluation
workflow.{run_id}.gate.passed           — QA ≥90, architect approved
workflow.{run_id}.gate.failed           — retry or escalate
workflow.{run_id}.escalation            — retry limit exceeded

# Human interaction
system.approval.request                 — gate needs human decision
system.approval.response                — human approved/rejected
system.question.ask                     — agent needs user input
system.question.answer                  — user provided answer

# Task lifecycle
task.{task_id}.created
task.{task_id}.dispatched               — sent to AiderDesk or SmartProxy
task.{task_id}.completed
task.{task_id}.failed

# Cross-domain context sharing
context.{project_id}.file.changed
context.share.request                   — "tax agent needs homekit data"
context.share.response
```

### The `agent_events` Table

```sql
CREATE TABLE agent_events (
  id              BIGSERIAL PRIMARY KEY,
  channel         VARCHAR(255) NOT NULL,    -- "agent.qa.tool.called"
  event_type      VARCHAR(100) NOT NULL,    -- "tool_called"
  source          VARCHAR(100),             -- "aider_desk", "smart_proxy", "agent_desk_gem"
  agent_id        VARCHAR(100),
  task_id         BIGINT REFERENCES agent_tasks(id),
  workflow_run_id BIGINT,                   -- FK when Epic 4B lands
  project_id      BIGINT REFERENCES projects(id),
  domain          VARCHAR(50),              -- "ror", "tax", "homekit", "security"
  payload         JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_agent_events_channel ON agent_events (channel);
CREATE INDEX idx_agent_events_task_id ON agent_events (task_id);
CREATE INDEX idx_agent_events_workflow ON agent_events (workflow_run_id);
CREATE INDEX idx_agent_events_created ON agent_events (created_at);
```

### How Each Backend Connects

| Backend | Publishes via | Subscribes via |
|---------|--------------|----------------|
| **AiderDesk** (Electron/Node) | Socket.IO → EventRelay → LISTEN/NOTIFY | LISTEN/NOTIFY (via `pg-listen` npm package) |
| **SmartProxy** | HTTP callback → Rails endpoint → LISTEN/NOTIFY | N/A (request-response only) |
| **`agent_desk` gem** (in Solid Queue worker) | Direct LISTEN/NOTIFY (same PostgreSQL connection) | Direct LISTEN (same process) |
| **Browser** | ActionCable send | Turbo Streams / ActionCable receive |
| **WorkflowEngine** | LISTEN/NOTIFY | LISTEN/NOTIFY + ActiveRecord queries |

### PostgreSQL LISTEN/NOTIFY — Key Properties

- **Payload limit**: 8KB per NOTIFY (plenty for event metadata; large payloads go in `agent_events` table with just the ID in the notification)
- **Latency**: ~1ms within same host
- **Durability**: None (fire-and-forget). Durable events go through `agent_events` table + Solid Queue.
- **Fan-out**: All listeners on a channel receive the notification
- **Cross-process**: Any PostgreSQL client can LISTEN/NOTIFY — Ruby, Node, Python
- **No extra infrastructure**: Built into PostgreSQL, always available

### Implementation in the `agent_desk` Gem

The gem stays dependency-free at its core. When used inside Agent-Forge:

```ruby
# In the gem: abstract MessageBus interface
module AgentDesk
  class MessageBus
    def publish(channel, event); end
    def subscribe(pattern, &block); end
  end
  
  # Default: in-process callback (for standalone scripts)
  class CallbackBus < MessageBus; end
  
  # Agent-Forge adapter: PostgreSQL LISTEN/NOTIFY
  class PostgresBus < MessageBus; end
end

# In Agent-Forge: wire it up
AgentDesk.configure do |config|
  config.message_bus = AgentDesk::PostgresBus.new(
    connection: ActiveRecord::Base.connection
  )
end
```

---

## Open Decisions

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | Should `agent_events` be write-heavy (every chunk) or summary-only? | Every event vs aggregated | **Summary + opt-in verbose** — log tool calls and completions always; chunks only when debugging |
| 2 | LISTEN/NOTIFY channel naming: flat or hierarchical? | `agent_qa_response_chunk` vs `agent.qa.response.chunk` | **Dot-hierarchical** — matches AiderDesk's tool naming convention, enables prefix subscriptions |
| 3 | Where does the bus live in Agent-Forge code? | `lib/agent_forge/message_bus.rb` vs `app/services/` | **`lib/`** — it's infrastructure, not a domain service |
| 4 | Event schema format | Hashes vs Ruby Data classes vs JSON Schema | **Data classes (Ruby 3.2+)** in the gem; **JSONB** in PostgreSQL |
| 5 | Should the bus be a PRD in this epic or in Epic 4B? | Ruby gem epic vs Agent-Forge epic | **Both** — PRD-0095 defines the gem's `MessageBus` interface + adapters; Epic 4B PRD defines Agent-Forge's wiring |
