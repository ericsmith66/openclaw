### SDLC Agent Lifecycle Explanation

The SDLC (Software Development Lifecycle) Agent lifecycle in the nextgen-plaid application is a phased workflow for autonomous feature development, managed primarily through the `Artifact` model (which tracks state) and orchestrated by `AiWorkflowService`. It involves agents like SAP (Senior Architect/Product Manager), Coordinator (for orchestration and planning), Planner (task breakdown), and CWA (Code Writing Agent). The lifecycle is designed for fully autonomous execution where possible, with escalations to human only on errors or blocks (e.g., via `EscalateToHumanError`). Phases advance via explicit transitions (e.g., "approve" or "reject" actions), and inter-agent communication occurs through structured handoffs (e.g., JSON payloads with micro-tasks). LLM interactions happen via a thin proxy (SmartProxy/Ollama), with retries and guardrails to limit calls.

The lifecycle draws from PRD-AH-009 and related epics, emphasizing local AI (Ollama models like Llama 3.1 70B), Rails MVC integration, and filesystem/DB persistence for artifacts/logs. It runs in a REPL-like multi-turn setup (max 5 turns default per run), where each turn typically involves 1 LLM call but can include tool invocations (e.g., GitTool for CWA). Full runs are triggered via `AiWorkflowService.run` or `resolve_feedback`, persisting context in `ai_workflow_runs` table and agent_logs filesystem.

#### Phases, Inputs/Outputs, Inter-Agent Communication, and LLM Calls/Turns

Phases are defined in `Artifact::PHASES` as an array of strings, with owners assigned dynamically. Each phase processes an `Artifact` record (DB-backed, with JSONB `payload` for audit trails, micro-tasks, implementation notes). Inputs are typically the artifact's current state plus prompts/context from prior phases. Outputs update the artifact (e.g., add to payload) and may produce filesystem artifacts (e.g., logs in `agent_logs/ai_workflow/<correlation_id>`). Inter-agent comm is via handoff payloads (JSON structs like `{correlation_id, micro_tasks, reason}`), routed through agent configurations (e.g., SAP hands off to Coordinator). LLM calls occur per agent turn in `Agents::Runner.run`, with 1 call per turn (prompt to response); runs can have multiple turns (up to max_turns=5 default), and retries (up to 3) add extra calls. Total calls per phase vary by complexity but are guardrailed to prevent excess.

- **backlog** (Owner: SAP)
    - **Inputs**: Initial user query/prompt (string), optional research flag; RAG context from knowledge_base (e.g., backlog.json, MCP.md, project snapshots).
    - **Outputs**: Draft artifact (e.g., PRD Markdown stored in payload or filesystem via strategy like PrdStrategy); updated artifact record with name, type, payload["audit_trail"].
    - **Inter-Agent Comm**: None (initial phase); SAP may prepare handoff payload if routing to Coordinator.
    - **LLM Calls/Turns**: 1-3 calls (1 main generation via SapAgent::ArtifactCommand.call_proxy; up to 2 retries on validation failure). Single run/turn typically, as SAP focuses on artifact creation.

- **ready_for_analysis** (Owner: SAP)
    - **Inputs**: Approved backlog artifact (from transition "approve"); refined prompt if rejected prior.
    - **Outputs**: Queued artifact for analysis, potentially with enhanced payload (e.g., research results if flagged).
    - **Inter-Agent Comm**: SAP can handoff to Coordinator (JSON: {correlation_id, query}) if prompt indicates implementation need.
    - **LLM Calls/Turns**: 0-1 call (routing decision via Ai::RoutingPolicy.call; if research needed, adds 1 call to SmartProxyClient.research). Minimal turns, as this is a transitional queuing phase.

- **in_analysis** (Owner: Coordinator)
    - **Inputs**: Artifact from prior phase; handoff payload from SAP (e.g., query, research_results); context incl. feedback_history.
    - **Outputs**: Broken-down micro-tasks (array in payload["micro_tasks"], e.g., [{id, title, estimate}]); plan summary broadcast to Agent Hub.
    - **Inter-Agent Comm**: Handoff to Planner (for task breakdown) or directly to CWA; uses structured JSON (e.g., handoff_to_cwa with micro_tasks). Broadcasts via ActionCable for visibility (e.g., plan_summary).
    - **LLM Calls/Turns**: 1-5 calls (Coordinator LLM for orchestration; Planner adds 1+ for TaskBreakdownTool). Up to max_turns=5 per run, with each turn potentially invoking tools (non-LLM) like handoff.

- **ready_for_development_feedback** (Owner: SAP)
    - **Inputs**: Analyzed artifact with micro-tasks; optional feedback from prior run (via resolve_feedback).
    - **Outputs**: Feedback-ready artifact; if auto-approved, transitions directly to next.
    - **Inter-Agent Comm**: Potential reverse handoff to Coordinator if rejection needed; otherwise, prepares for CWA.
    - **LLM Calls/Turns**: 0-2 calls (if feedback provided, 1 for resolution; optional routing call). Low turns, as autonomous mode auto-approves on success.

- **ready_for_development** (Owner: CWA)
    - **Inputs**: Approved artifact with micro-tasks; handoff from Coordinator (JSON incl. reason, workflow_state).
    - **Outputs**: Task-assigned artifact, ready for coding; updates context[:state] for in-progress tracking.
    - **Inter-Agent Comm**: None outgoing; receives handoff JSON.
    - **LLM Calls/Turns**: 0-1 call (setup/context load; no heavy processing). Transitional, minimal turns.

- **in_development** (Owner: CWA)
    - **Inputs**: Dev-ready artifact; tools config (e.g., GitTool for branching/commits, SafeShellTool for tests); persona instructions from personas.yml.
    - **Outputs**: Implemented code (e.g., git diffs, test results in payload["implementation_notes"]); logs tool events. On success, transitions to ready_for_qa.
    - **Inter-Agent Comm**: Tool-based (non-agent comm); can escalate to Coordinator/Human on blocks (e.g., GuardrailError). Broadcasts status via ActionCable.
    - **LLM Calls/Turns**: 1-10 calls (CWA multi-turn loop: 1 per turn for code gen/tool decisions; max_turns=5, but tools like Git diff add non-LLM steps). Retries on errors add 1-2. Most intensive phase.

- **ready_for_qa** (Owner: Coordinator)
    - **Inputs**: Developed artifact with notes/diffs; test results from CWA tools.
    - **Outputs**: QA-ready artifact; heuristic checks (e.g., test status) or escalation if failed.
    - **Inter-Agent Comm**: Handoff back to SAP/Human if issues; broadcasts failure messages.
    - **LLM Calls/Turns**: 1-3 calls (validation/scoring via optional Ollama call; 1 for resolution if feedback loop). Up to 2 turns for error handling.

- **complete** (Owner: Human)
    - **Inputs**: QA-passed artifact.
    - **Outputs**: Finalized artifact (e.g., committed code, full logs/artifacts in filesystem); context[:workflow_state]="resolved".
    - **Inter-Agent Comm**: None (terminal); may trigger human review broadcast.
    - **LLM Calls/Turns**: 0 calls (post-processing only; no agent involvement).

Across phases, total LLM calls per full SDLC run: 5-20 (averaged over multi-agent orchestration), with guardrails (e.g., max_turns=5, timeouts). Autonomous mode skips human-await states via auto-approve on success.

#### Implementation in Code: Methods and Responsibilities

The lifecycle is implemented via Rails models/services, with Agents gem for multi-agent runs. Key classes/methods handle state, orchestration, and execution:

- **Artifact Model (app/models/artifact.rb)**: Core state tracker.
    - `transition_to(action, actor_persona)`: Advances/reverts phase based on action ("approve"/"reject"); updates owner via `determine_next_owner`; appends to payload["audit_trail"]. Responsible for phase validation and persistence.
    - `determine_next_phase(action)`: Case logic for phase progression (e.g., "approve" from in_development → ready_for_qa).
    - `set_defaults`: Initializes new artifacts to "backlog" with SAP owner.
    - Integrates with DB (validates presence, inclusion); used in services for transitions (e.g., auto-approve in finalize_hybrid_handoff!).

- **AiWorkflowService (app/services/ai_workflow_service.rb)**: Orchestrates full runs, builds agents, handles contexts/errors.
    - `run(prompt:, correlation_id:, max_turns:, model:)`: Entry for autonomous execution; builds agents (SAP → Coordinator → Planner → CWA) with handoff_agents/tools; invokes Agents::Runner.run for multi-turn processing; finalizes via `finalize_hybrid_handoff!` (updates phases, broadcasts). Responsible for context loading (`load_existing_context`), error handling (e.g., GuardrailError), and logging.
    - `resolve_feedback(prompt:, feedback:, ...)`: Handles multi-turn feedback loops; runs initial then resolved passes; manages awaiting_feedback/escalated states.
    - `finalize_hybrid_handoff!(result, artifacts:)`: Post-run logic; syncs micro-tasks to artifact.payload; transitions phases (e.g., approve on CWA success); gathers diffs/tests from events; broadcasts updates. Responsible for terminal states and human escalations.
    - `build_initial_context`, `persona_instructions`, `build_agent`: Setup helpers; load personas.yml for instructions; configure handoffs/tools (e.g., TaskBreakdownTool for Planner).
    - `handoff_to_cwa`: Formats JSON handoff payloads.

- **SapAgent::ArtifactCommand (app/services/sap_agent/artifact_command.rb)**: SAP-specific generation.
    - `execute`: Validates, optionally researches, calls LLM (via `call_proxy`), parses/stores via strategy (e.g., PrdStrategy for validation/parse/store). Handles retries (up to 3). Responsible for prompt rendering (ERB with RAG) and lifecycle logging.
    - `prompt`: Builds system prompt with RAG (backlog.json, MCP.md, snapshots); substitutes via ERB/gsub.
    - `validate_artifact!`, `parse_response`, `store_artifact`: Delegate to strategy_module for type-specific logic.

- **Agents::Runner (implied from gem)**: Executes multi-turn agent loops; each turn: LLM call → tool/handoff invocation. Integrated via `runner.run` in service.

- **ArtifactWriter (referenced)**: Filesystem logging (run.json, events); attaches callbacks to runner for event recording (e.g., routing_decision, feedback_requested).

Overall, code ensures autonomy by auto-transitioning on success, persisting via DB/filesystem, and limiting LLM exposure with max_turns/retries. For CLI testing (from prior context), this integrates with rake tasks overriding prompts/models at phase entry points.

Next steps: Compare with Junie's answer? Zoom in on a phase for code examples?


### Comparison and Contrast of Answers on SDLC Agent Lifecycle

Both responses provide a comprehensive breakdown of the SDLC Agent lifecycle in the nextgen-plaid repo, drawing from the same core elements: the `Artifact` model as the central state tracker, phased progression via transitions, agent orchestration through `AiWorkflowService`, and integration with UI (Agent Hub) and autonomous runs. They align closely on the phase list (from `backlog` to `complete`), owners (e.g., SAP for early phases, CWA for development), and key code responsibilities (e.g., `Artifact#transition_to`, `AiWorkflowService.run`). Both emphasize autonomy (no humans in loop by default) and guardrails like max_turns. However, differences emerge in structure, depth, emphasis, and specifics—my answer leans toward runtime/LLM mechanics and broader architectural ties, while Junie's focuses on UI-driven flows, practical expectations, and a streamlined end-to-end view.

#### Similarities
- **Core Framework**: Both identify `Artifact` as the "durable thing" moving through SDLC, with phases from `Artifact::PHASES`, transitions via `Artifact#transition_to(action, actor_persona)`, owner routing, and audit trails in `payload["audit_trail"]`. We agree on phase owners and basic inputs/outputs (e.g., PRD content in early phases, micro-tasks in analysis, diffs/notes in development).
- **Phase Breakdown**: High overlap in per-phase details—e.g., `backlog` as holding state (inputs: query/PRD; outputs: persisted artifact); `in_analysis` involving Coordinator/Planner handoffs; `in_development` as tool-heavy CWA execution; terminal `complete` with human owner. Both note 0 LLM calls for pure transitions (approve/reject) and variable calls (1-max_turns) in active phases like analysis/development.
- **Inter-Agent Communication**: Consensus on two planes: UI broadcasts via ActionCable (human-system interaction) and LLM handoffs within runs (e.g., SAP → Coordinator → Planner → CWA via JSON payloads/reasons). Tools (e.g., TaskBreakdownTool) and escalations (e.g., to human on errors) are highlighted similarly.
- **LLM Calls/Turns**: Both tie calls to `max_turns` in `AiWorkflowService.run`, with 0 for transitional phases and 1+ (bounded) for processing phases. Retries/escalations add extras; practical estimates align (e.g., multi-turn in development).
- **Code Responsibilities**: Shared mapping—`artifact.rb` for state machine; `agent_hub_channel.rb` for UI bridges/actions; `ai_workflow_service.rb` for run orchestration, context building, handoffs, and finalization (e.g., `finalize_hybrid_handoff!`). Callbacks/logging via `ArtifactWriter` are noted in both.
- **Autonomy Focus**: Emphasis on full runs via `AiWorkflowService` (e.g., auto-approve on success), with DB persistence (artifacts, runs) and filesystem logs.

#### Contrasts
- **Structure and Emphasis**:
    - My answer integrates inputs/outputs/comm/turns into one per-phase block for cohesion, with a separate code section for methods. It ties to broader context (e.g., `AiWorkflowRun` table, error classes like `GuardrailError`, RAG from knowledge_base).
    - Junie's separates into distinct sections (phase-by-phase, comm, turns, code map) plus an explicit end-to-end summary, making it more modular and UI-centric (e.g., heavy on `AgentHubChannel` methods like `confirm_action`, `handle_autonomous_command` for triggering runs).
- **Depth on Inputs/Processing/Outputs**:
    - My answer details RAG/context injection (e.g., backlog.json, MCP.md), tool configs (e.g., GitTool), and outputs like broadcasts/diffs. It specifies LLM calls more granularly (e.g., 1-10 in development with tool loops; retries up to 3).
    - Junie's adds "processing" explicitly per phase (e.g., human vs. autonomous modes in analysis), with practical notes (e.g., ENV for tool execution in spike). It focuses on minimal inputs for advancement and UI signals (e.g., user clicks for transitions), but omits some runtime details like `build_initial_context` or error backtracking.
- **Inter-Agent Communication**:
    - My answer covers escalations/errors more (e.g., `EscalateToHumanError`), and ties handoffs to `Agents::Runner` execution.
    - Junie's distinguishes planes clearly (UI/event vs. LLM handoff), with examples like `on_agent_handoff` callback, but less on tools/escalations.
- **LLM Calls/Turns**:
    - My answer quantifies totals per full run (5-20 calls) and per phase (e.g., 1-5 in analysis), including non-LLM steps (tools).
    - Junie's stresses no hardcoding per phase (phases as business states vs. runtime turns), with "practical expectations" (e.g., 1..max_turns in active phases) and enforcement via `enforce_turn_guardrails!`. It notes 0 turns if human-only, aligning but with more caveats.
- **Code Implementation**:
    - My answer lists more methods (e.g., `determine_next_phase`, `resolve_feedback`, `persona_instructions`) and ties to gems (Agents for Runner).
    - Junie's provides a tighter "responsibility map" with code snippets (e.g., phase array) and UI integration (e.g., threading in `handle_autonomous_command`), plus notes on artifact creation from conversations.
- **End-to-End View**:
    - My answer implies it via phase sequencing but lacks a dedicated summary.
    - Junie's includes a "quick end-to-end" happy path, making it more narrative for quick grasp.
- **Gaps/Assumptions**:
    - My answer assumes more from epics/PRDs (e.g., AH-009), potentially broader but risking over-inference without fresh repo browse.
    - Junie's is more grounded in specific file paths/methods (e.g., `payload["content"]` for PRD), with spike notes (e.g., ENV toggle), suggesting closer code inspection—though both could benefit from verification via browse_page on key files like ai_workflow_service.rb.

Overall, the answers complement: Mine offers deeper LLM/runtime insights for architecting enhancements; Junie's excels in UI/autonomous triggers and phase mechanics for implementation guidance. Combined, they cover ~90% overlap, with contrasts highlighting UI vs. backend focus.

Next steps: Any specific discrepancies to resolve via repo browse (e.g., confirm max_turns default or exact handoff JSON)? Or proceed to CLI PRD updates incorporating this?