### SDLC Agent lifecycle (what “moves” through the system)

In this codebase, the durable thing that moves through SDLC is an `Artifact` record (`app/models/artifact.rb`). Conversations and agent runs *produce and update* the artifact, but the artifact’s `phase` is the SDLC “source of truth”.

The lifecycle is implemented as:

- **A finite set of phases** (`Artifact::PHASES`)
- **Explicit transitions** via `Artifact#transition_to(action, actor_persona)`
- **Owner routing** via `owner_persona` (who should act next)
- **Audit trail** written into `artifact.payload["audit_trail"]`

The phases currently defined are:

```ruby
backlog
ready_for_analysis
in_analysis
ready_for_development_feedback
ready_for_development
in_development
ready_for_qa
complete
```

---

### 1) Phase-by-phase: inputs, processing, and outputs

Below, “inputs” are the *minimum* required signals/data to advance, “processing” is what the system does, and “outputs” are the artifacts/events produced.

#### Phase: `backlog`
- **Owner (`owner_persona`)**: `SAP` (set by `Artifact#determine_next_owner`)
- **Typical inputs**:
    - A new artifact (often created from conversation context in `AgentHubChannel#confirm_action` when an `approve` happens and no artifact exists yet)
    - Content/PRD text stored in `artifact.payload["content"]` (required for autonomous execution)
- **Processing**:
    - No autonomous execution by default; it’s a holding state.
    - `approve` transition moves to `ready_for_analysis`.
- **Outputs**:
    - Persisted `Artifact` row; `payload["audit_trail"]` updated on transitions.

#### Phase: `ready_for_analysis`
- **Owner**: `SAP`
- **Inputs**:
    - A user (or automation) indicates readiness to start analysis (`approve`).
- **Processing**:
    - `approve` moves to `in_analysis`.
    - `reject` moves back to `backlog`.
- **Outputs**:
    - Updated `artifact.phase`, updated `artifact.owner_persona`, audit trail entry.

#### Phase: `in_analysis`
- **Owner**: `Coordinator`
- **Inputs**:
    - A sufficiently clear PRD / requirement statement (typically stored in `artifact.payload["content"]`).
    - A trigger to run analysis/planning: either a human action in Agent Hub, or an autonomous command.
- **Processing** (two modes):
    1) **Human-driven**: humans/agents discuss; user can `approve` to advance.
    2) **Autonomous run** (Agent Hub → Workflow): `AgentHubChannel#handle_autonomous_command` can pre-advance from `backlog`/`ready_for_analysis` into `in_analysis` and then call `AiWorkflowService.run(prompt: prd_content, correlation_id: run.id)`.
- **Outputs**:
    - Chat tokens broadcast to ActionCable streams (Agent Hub UI updates).
    - A workflow run result persisted to run artifacts/logs (see `AiWorkflowService::ArtifactWriter`).
    - Potential handoff to Planner/CWA inside the autonomous loop.

#### Phase: `ready_for_development_feedback`
- **Owner**: `SAP`
- **Inputs**:
    - Coordinator (or system) signals that analysis is done and feedback/approval is needed.
- **Processing**:
    - `approve` → `ready_for_development`
    - `reject` → `in_analysis`
- **Outputs**:
    - Phase + owner update; audit trail.

#### Phase: `ready_for_development`
- **Owner**: `CWA`
- **Inputs**:
    - Approved plan / scope.
    - Typically a task breakdown exists (in the autonomous loop, Planner is forced to use tools for breakdown).
- **Processing**:
    - `approve` → `in_development`
    - `reject` → `ready_for_development_feedback`
- **Outputs**:
    - Phase + owner update; audit trail.

#### Phase: `in_development`
- **Owner**: `CWA`
- **Inputs**:
    - Concrete implementation tasks.
    - Tool execution enabled (note `AgentHubChannel#handle_autonomous_command` sets `ENV["AI_TOOLS_EXECUTE"] = "true"` for the spike).
- **Processing**:
    - In the autonomous loop, `AiWorkflowService` coordinates a multi-agent run:
        - `SAP` is configured as a **routing agent** only.
        - `Coordinator` hands off to `Planner` then `CWA`.
        - `Planner` is instructed to use tools (`TaskBreakdownTool`).
    - On success, the service can advance the artifact (example in `AiWorkflowService` shows `approve` from `in_development` → `ready_for_qa`).
    - On failure/escalation, the service can move the artifact backward (`reject`) and broadcast a failure notice.
- **Outputs**:
    - Tool start/complete events; run start/complete events; handoff events, all written/broadcast via `AiWorkflowService::ArtifactWriter`.
    - Updated artifact phase on success/failure (when those code paths run).

#### Phase: `ready_for_qa`
- **Owner**: `Coordinator`
- **Inputs**:
    - A completed implementation needing review/QA.
- **Processing**:
    - `approve` → `complete`
    - `reject` → `in_development`
- **Outputs**:
    - Phase + owner update; audit trail.

#### Phase: `complete`
- **Owner**: `Human`
- **Inputs**:
    - Final approval.
- **Processing**:
    - Terminal state in the current phase machine.
- **Outputs**:
    - Artifact marked complete; audit trail contains full history.

---

### 2) Inter-agent communication: what’s possible

There are two distinct “communication planes” in this system:

#### A) UI/event communication (Agent Hub via ActionCable)
Implemented in `app/channels/agent_hub_channel.rb`:

- **Human → system**: user actions sent over the channel (e.g., `confirm_action`, `handle_command` and related helpers).
- **System → human**: broadcasts back to:
    - `agent_hub_channel_<agent_id>` (persona-specific stream)
    - `agent_hub_channel_all_agents` (sidebar/global updates)
    - `agent_hub_channel_workflow_monitor` (monitoring stream)

This plane is used for:
- Token streaming (“status” text updates)
- Confirmations
- Monitoring/interrogation (`interrogate`, `report_state`)

#### B) LLM multi-agent “handoff” communication (inside a workflow run)
Implemented primarily in `app/services/ai_workflow_service.rb`:

- `AiWorkflowService.build_agent(...)` builds agents with:
    - a `name`
    - `instructions`
    - a model
    - `handoff_agents` (who it can pass control to)
    - optional `tools`
- `Agents::Runner.with_agents(...)` executes the run.
- Handoffs are explicit and observable via callbacks:
    - `AiWorkflowService::ArtifactWriter#on_agent_handoff(from_agent, to_agent, reason)`

This plane supports:
- **Agent → agent handoff** (SAP → Coordinator → Planner → CWA)
- **Agent → tool invocation** (Planner uses `TaskBreakdownTool`, etc.)
- **Agent → escalation** (raising an error or entering a state that forces human ownership)

---

### 3) LLM calls / “turns” per phase (what the code actually constrains)

The code does not hardcode “N calls per phase” because phases are *business states* while LLM calls are *runtime execution steps*. Instead, it constrains calls using a **turn budget**.

#### Where turns are controlled
- `AiWorkflowService.run(prompt:, ..., max_turns: ...)` passes `max_turns:` into `runner.run(...)`.
- The service normalizes and records turn counts:
    - It reads `result.context[:turn_count]` and stores it as `result.context[:turns_count]`.
- It enforces guardrails in `AiWorkflowService.enforce_turn_guardrails!(...)` (method exists in the file structure).

So, **per autonomous execution**, the upper bound is:
- `<= max_turns` **LLM turns** (each “turn” is typically one model call producing the next agent action/message; exact semantics depend on the `Agents::Runner` implementation).

#### What happens in purely phase-transition steps
- A user clicking `approve` / `reject` / `backlog` in the Agent Hub UI triggers `Artifact#transition_to`.
- That produces **0 LLM calls**; it’s a DB update + broadcast.

#### Typical turn usage by SDLC segment (practical expectation)
Given the configured agent roles in `AiWorkflowService.run`:
- **Analysis / planning segment (`in_analysis`)**: multiple turns as the Coordinator routes and Planner uses tools.
- **Implementation segment (`in_development`)**: multiple turns as CWA performs steps, may use tools, may iterate with guardrails.
- **QA / completion (`ready_for_qa`)**: may be 0 LLM calls if humans approve, or could be additional turns if you run another autonomous loop for verification.

A reasonable way to describe “turns per phase” with this architecture is:

- `backlog` / `ready_for_analysis` / `ready_for_development_feedback` / `ready_for_development` / `ready_for_qa`:
    - **0 turns** if only human actions occur.
    - **Some turns** if you invoke an autonomous run while the artifact is in (or moved into) the corresponding working phase.
- `in_analysis` and `in_development`:
    - **1..max_turns** (bounded by `max_turns`) depending on complexity and whether tools are used.

---

### 4) How this is accomplished in code (responsibility map)

#### `app/models/artifact.rb`
- `Artifact::PHASES`: the SDLC phase vocabulary.
- `Artifact#transition_to(action, actor_persona)`:
    - Computes `next_phase` (`determine_next_phase`)
    - Updates `phase` + `owner_persona` (`determine_next_owner`)
    - Appends an audit record into `payload["audit_trail"]`
    - Persists via `save!`

This is the core SDLC state machine.

#### `app/channels/agent_hub_channel.rb`
- `subscribed` / `unsubscribed`: controls who can connect and what streams they get.
- `confirm_action(data)`:
    - Confirms UI actions
    - For `approve/reject/backlog`, finds or creates an `Artifact` and calls `artifact.transition_to(...)`
    - Broadcasts outcomes back to the UI
- `handle_autonomous_command(command_data, agent_id)`:
    - Ensures an active artifact exists and has PRD content
    - Optionally advances phase into `in_analysis` to ensure correct “assignment/context”
    - Kicks off an autonomous workflow in a thread via `AiWorkflowService.run(...)`

This is the “bridge” from human UI interaction → artifact SDLC changes → launching autonomous work.

#### `app/services/ai_workflow_service.rb`
- `AiWorkflowService.run(...)`:
    - Loads/builds context (`load_existing_context` / `build_initial_context`)
    - Builds agents with explicit handoff graph:
        - `SAP` (router)
        - `Coordinator`
        - `Planner` (tool-using)
        - `CWA`
    - Runs them with `Agents::Runner.with_agents(...).run(...)`
    - Records events via `ArtifactWriter` callbacks (`on_run_start`, `on_agent_handoff`, `on_tool_start`, etc.)
    - Tracks and enforces `max_turns`
    - Finalizes handoff/phase changes on terminal outcomes (`finalize_hybrid_handoff!`), including moving artifacts backward on failure and broadcasting status.

This is the runtime execution engine for the multi-agent loop.

---

### 5) Quick “end-to-end” lifecycle summary (one happy-path loop)

1. **Human creates/starts** work in Agent Hub (conversation exists; artifact may be created on first `approve`).
2. Artifact is in `backlog` (owner `SAP`).
3. User clicks `approve` → `ready_for_analysis` → `in_analysis` (owner becomes `Coordinator`).
4. User triggers an autonomous command (or otherwise starts a run): `AgentHubChannel#handle_autonomous_command` calls `AiWorkflowService.run`.
5. Within the run, **handoffs** happen: `SAP` routes → `Coordinator` → `Planner` (tool breakdown) → `CWA` (implementation).
6. On success, artifact transitions forward (e.g., `in_development` → `ready_for_qa`) and can be approved to `complete`.
7. Audit trail in `artifact.payload["audit_trail"]` contains each phase transition with actor and timestamp.

---

If you want, I can also:
- Extract the exact default `DEFAULT_MAX_TURNS` value and how `Agents::Runner` defines a “turn” (that’s the only missing piece to give you *exact* numeric call counts), or
- Draw the handoff graph and event/broadcast flow as a diagram using the concrete method names shown above.