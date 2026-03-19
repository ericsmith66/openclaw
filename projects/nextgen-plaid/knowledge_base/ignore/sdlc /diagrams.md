### Handoff graph (LLM multi-agent routing) — `AiWorkflowService.run`

```mermaid
graph TD
  %% Entry
  Run[AiWorkflowService.run(prompt:, correlation_id:, max_turns:)] --> Runner[Agents::Runner.with_agents(...)]

  %% Agent construction
  Run --> BuildSAP[AiWorkflowService.build_agent(name: "SAP", ...)]
  Run --> BuildCoord[AiWorkflowService.build_agent(name: "Coordinator", ...)]
  Run --> BuildPlanner[AiWorkflowService.build_agent(name: "Planner", tools: [TaskBreakdownTool])] 
  Run --> FetchCWA[Agents::Registry.fetch(:cwa, ...)]

  %% Runner executes the turn loop
  Runner -->|runner.run(prompt, context:, max_turns:, headers:)| TurnLoop[(Turn loop / max_turns)]

  %% Handoff edges (explicitly configured via handoff_agents)
  BuildSAP --> SAP[SAP agent]
  BuildCoord --> COORD[Coordinator agent]
  BuildPlanner --> PLAN[Planner agent]
  FetchCWA --> CWA[CWA agent]

  SAP -->|handoff_agents: [Coordinator]| COORD
  COORD -->|handoff_agents: [Planner, CWA]| PLAN
  COORD -->|handoff_agents: [Planner, CWA]| CWA
  PLAN -->|handoff_agents: [CWA]| CWA

  %% Tool use (Planner)
  PLAN -->|tools: [TaskBreakdownTool]| Tool[TaskBreakdownTool]

  %% End-of-run finalization
  TurnLoop --> Result[result]
  Result --> Finalize[AiWorkflowService.finalize_hybrid_handoff!(result, artifacts:)]
  Finalize --> ArtifactPhase[Artifact#transition_to(action, actor_persona)]
```

#### Notes tied to concrete code
- Agent graph is built in `AiWorkflowService.run` (see calls to `build_agent(...)` and `Agents::Registry.fetch(:cwa, ...)`).
- “SAP must route” is enforced by SAP’s instructions: `"You are a routing agent... MUST call handoff_to_coordinator"`.
- Turn budget is passed into `runner.run(..., max_turns: max_turns, ...)`.

---

### Event + broadcast flow (UI + monitoring + run artifacts)

This diagram shows the *event plane* (ActionCable broadcasts) plus the *run artifact logging plane* (callbacks in `AiWorkflowService::ArtifactWriter`).

```mermaid
sequenceDiagram
  autonumber
  actor Human as Human (Agent Hub UI)
  participant AH as AgentHubChannel
  participant AC as ActionCable.server
  participant DB as DB (Artifact/AiWorkflowRun)
  participant AWS as AiWorkflowService
  participant AR as Agents::Runner
  participant AW as AiWorkflowService::ArtifactWriter

  %% Subscription streams
  Human->>AH: subscribed
  AH-->>AC: stream_from("agent_hub_channel_#{agent_id}")
  AH-->>AC: stream_from("agent_hub_channel_all_agents")
  AH-->>AC: stream_from("agent_hub_channel_workflow_monitor")

  %% Phase transition via UI confirm
  Human->>AH: confirm_action({command: approve|reject|backlog, artifact_id})
  AH-->>AC: broadcast("agent_hub_channel_#{agent_id}", {type: "confirmed", message_id})
  AH->>DB: Artifact.find_by(...) / Artifact.create!(...) (when needed)
  AH->>DB: Artifact#transition_to(command, actor_persona)
  AH-->>AC: broadcast(... token/status update ...)

  %% Autonomous run start
  Human->>AH: handle_autonomous_command({command: "autonomous_*"}, agent_id)
  AH->>DB: run = AiWorkflowRun.for_user(...).active.first
  AH->>DB: artifact = run.active_artifact
  AH-->>AC: broadcast("agent_hub_channel_#{agent_id}", {type:"token", token:"Launching autonomous..."})

  %% Optional pre-advance into in_analysis
  AH->>DB: Artifact#transition_to("approve", agent_id) (possibly twice)

  %% Threaded workflow execution
  AH->>AWS: (Thread.new) AiWorkflowService.run(prompt: prd_content, correlation_id: run.id)

  %% Run artifact logging + callbacks
  AWS->>AW: artifacts = ArtifactWriter.new(correlation_id)
  AWS->>AR: runner = Agents::Runner.with_agents(...)
  AWS->>AW: ArtifactWriter#attach_callbacks!(runner)
  AWS->>AR: runner.run(prompt, context:, max_turns:, headers:)

  %% Callback events (representative)
  AR-->>AW: on_run_start(agent_name, input, context)
  AR-->>AW: on_agent_thinking(agent_name, input)
  AR-->>AW: on_agent_handoff(from_agent, to_agent, reason)
  AR-->>AW: on_tool_start(tool_name, args)
  AR-->>AW: on_tool_complete(tool_name, result)
  AR-->>AW: on_agent_complete(agent_name, result, error, context)
  AR-->>AW: on_run_complete(agent_name, result, context)

  %% ArtifactWriter effects
  AW->>DB: write_event / write_run_json (filesystem under runs/, plus any DB lookups it performs)
  AW-->>AC: broadcast_event(event) to "agent_hub_channel_workflow_monitor" (and/or other streams)

  %% Finalize + possible SDLC phase changes + broadcasts
  AWS->>AWS: finalize_hybrid_handoff!(result, artifacts:)
  AWS->>DB: (optional) Artifact#transition_to("approve"|"reject", actor_persona)
  AWS-->>AC: broadcast("agent_hub_channel_all_agents", {type:"token", ...}) (e.g., failure notice)

  %% Completion notice back to UI
  AH-->>AC: broadcast("agent_hub_channel_#{agent_id}", {type:"token", token:"✅ Autonomous ... completed"})
```

#### Concrete broadcast channels involved
- Persona stream: `"agent_hub_channel_#{params[:agent_id]}"` (set in `AgentHubChannel#subscribed`).
- Global stream: `"agent_hub_channel_all_agents"` (used for sidebar/global status; also used in `AiWorkflowService` failure broadcast).
- Monitor stream: `"agent_hub_channel_workflow_monitor"` (subscribed in `AgentHubChannel#subscribed`; events emitted via `AiWorkflowService::ArtifactWriter#broadcast_event`).

---

### If you want the diagram to be *strictly complete*

To fully ground “turn” semantics and exactly which events are broadcast to which stream, the remaining source of truth is the `Agents::Runner` and `Agents::Registry` implementation (where “turn” is incremented and where callbacks fire). If you tell me where those live (likely under `app/services/agents` or `lib/agents`), I can extend the diagrams to include those concrete methods too.