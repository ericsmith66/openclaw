# End-of-Epic Report: Agent-Hub-09-AgentHub-Workflow-MVP

## 1. Overview
This epic successfully established the foundational platform capabilities for the Agent Hub Workflow MVP. The focus was on creating a "happy path" SDLC loop (the Spike) that allows artifacts to move from idea to completion through structured phases, tracked by persona ownership.

## 2. Completed PRDs
- **PRD-AH-009A (System Health):** Implemented an Admin Health Dashboard to monitor critical components (Proxy, Workers, ActionCable, Cloudflare).
- **PRD-AH-009B (Artifact Store):** Created the `artifacts` table with `owner_persona`, `phase`, and `payload` (jsonb). Integrated optimistic locking via `lock_version`.
- **PRD-AH-009C (Linking):** Enabled linking between `AiWorkflowRun` (conversations) and `Artifacts`. Added a dynamic "link card" to the Agent Hub UI.
- **PRD-AH-009D (Status Movers):** Implemented slash commands (`/approve`, `/reject`, `/backlog`) that trigger deterministic phase transitions and update ownership.
- **PRD-AH-009E (Workflow UI Hooks):** Developed a minimal Workflow UI to manage artifacts, view their payloads, and inspect the audit trail of transitions.

## 3. Observations
- **Single Agent with the Ball:** The `owner_persona` field effectively manages handoffs between SAP, Coordinator, and CWA.
- **Audit Traceability:** The `audit_trail` in the artifact payload provides a clear history of who did what and when, which is critical for SDLC accountability.
- **Spike Efficiency:** By focusing on the "happy path" and deferring advanced validation (YAGNI), we've proven the end-to-end loop quickly.

## 4. Inclusions for Future Stories
- **Automated Validation Hooks:** Implement the "Ready for..." checks mentioned in the feedback (e.g., ensuring PRD content exists before moving to development).
- **Versioning/Hashing:** Add content hashing to the audit trail to ensure the exact version approved is the one developed.
- **Real-time UI Updates:** Use ActionCable to live-update the Workflow UI and Agent Hub link card when phases change in the background.
- **Soft Deletion:** Implement the soft-delete logic for artifacts as mentioned in the feedback.
- **Enhanced Role-Based Access:** Restrict certain phase transitions to specific personas or human roles.

## 5. Explicit Test Criteria (Human-in-the-Loop)

### Test A: The "Happy Path" Loop
1. **Setup:** Create a new conversation in Agent Hub (Persona: SAP).
2. **Action:** SAP proposes a new feature.
3. **Action:** Human types `/approve`.
4. **Expected Result:** 
   - Confirmation bubble "Approve Now" appears.
   - User clicks "Approve Now".
   - System message: "Artifact '...' moved to phase: Ready for analysis. Assigned to: SAP."
   - Link card in header updates to reflect the new phase.
5. **Action:** Human types `/approve` again.
6. **Expected Result:** Artifact moves to `in_analysis`, assigned to `Coordinator`.

### Test B: Rejection and Rework
1. **Setup:** Artifact is in `in_analysis`.
2. **Action:** Human types `/reject`.
3. **Expected Result:**
   - Confirmation bubble "Reject/Rework" appears.
   - User clicks "Reject/Rework".
   - System message: "Artifact '...' moved to phase: Ready for analysis. Assigned to: SAP."
   - Audit trail shows the rejection and transition back to SAP.

### Test C: Workflow UI Visibility
1. **Setup:** Artifact exists with several transitions.
2. **Action:** Navigate to `/admin/ai_workflow`.
3. **Expected Result:**
   - Artifact list shows the current artifact.
   - Selecting the artifact displays its payload content and the full Audit Trail.
   - The Audit Trail matches the actions taken in Agent Hub.

### Test D: System Health
1. **Action:** Navigate to `/admin/health`.
2. **Expected Result:**
   - Dashboard shows status for Proxy, Workers, ActionCable, and Cloudflare.
   - Timestamps reflect the time of the check.
   - If `CLOUDFLARE_CHECK_ENDPOINTS` is set, specific endpoint results are visible.


### Analysis of Wiring: SAP Coordinator CWA and RAG (Static) in Epic 9

Based on the review of the implementation for Epic 9 (Agent-Hub-09-AgentHub-Workflow-MVP), here is the status of the wiring for the SAP Coordinator CWA and the RAG (static) components.

#### 1. SAP, Coordinator, and CWA Wiring
These three personas are fully wired into the core "Happy Path" loop of the workflow system.

*   **Artifact Ownership:** The `Artifact` model (`app/models/artifact.rb`) contains deterministic logic that reassigns the `owner_persona` during state transitions:
   *   **SAP:** Owns the `backlog` and `ready_for_analysis` phases, as well as `ready_for_development_feedback`.
   *   **Coordinator:** Owns the `in_analysis` and `ready_for_qa` phases.
   *   **CWA:** Owns the `ready_for_development` and `in_development` phases.
*   **Command Handoffs:** The `AgentHubChannel` (`app/channels/agent_hub_channel.rb`) processes slash commands (`/approve`, `/reject`) that trigger these transitions and automatically broadcast the new ownership to the UI.
*   **Multi-Agent Workflow:** The `AiWorkflowService` (verified in symbols/text) uses these personas as distinct agents with tool-calling capabilities (`handoff_to_coordinator`, `handoff_to_cwa`) to move the "ball" between them during autonomous runs.

#### 2. RAG (Static) Wiring
The RAG system is wired into the Agent Hub to provide context to the AI personas, but it is currently in a "Static" phase.

*   **RagProvider Integration:** Both `AgentHubsController` and `AgentHubChannel` call `SapAgent::RagProvider.build_prefix("default", user_id)` to inject context into every AI interaction.
*   **Static Documents:** The `RagProvider` fetches a fixed set of documents defined in `knowledge_base/static_docs/context_map.md`. For a "default" query, it pulls `MCP.md` and `0_AI_THINKING_CONTEXT.md`.
*   **Static User Snapshot:** It also pulls a "static" snapshot of the user's financial data (redacted) from the `snapshots` table. It is static in the sense that it uses the *last* captured snapshot rather than performing a live, real-time query of the database for every message.

---

### Identified Gaps

While the wiring is functional, the following gaps exist in the current MVP implementation:

1.  **Context Injection Gaps:**
   *   **Static Mapping:** The `context_map.md` is hardcoded. Adding new PRDs or project-specific documents requires a manual update to the markdown table in that file; the system does not yet "discover" relevant documents dynamically.
   *   **Persona-Blind RAG:** The `RagProvider` currently uses a generic `"default"` or `"generate"` query type for all personas. It does not yet differentiate the *documentation* context specifically for the Coordinator vs. the CWA (e.g., CWA doesn't automatically get the latest technical specs unless they are in the default map).

2.  **State Logic Gaps:**
   *   **Validation Hooks:** There is no "hard" validation before transitions. For example, the system allows moving an artifact to `ready_for_development` even if the `payload` is empty or missing a technical plan.
   *   **Soft-Deletion:** As noted in the end-of-epic report, soft-deletion for artifacts is not yet implemented.

3.  **UI Feedback Gaps:**
   *   **Real-time RAG Visibility:** While users can "Inspect Context" via the UI, there is no live indicator showing *exactly* which static files were injected into the last AI response without manually checking the logs.

Overall, the **wiring is complete for the "Happy Path" loop**, ensuring the right agent "has the ball" at the right time with a baseline of static project context.

### Will CWA Write Code in Epic 9?

**Short Answer: No.**

In the **Epic 9 (Agent-Hub-09-AgentHub-Workflow-MVP)** feature set, the CWA (Coding-With-Agent) persona does **not** yet perform autonomous code generation or implementation.

#### CWA's Role in Epic 9:
In this epic, CWA's role is strictly limited to **workflow participation** and **ownership assignment**:

*   **Ownership Placeholder:** CWA is "wired" into the system so that when an artifact moves to the `ready_for_development` or `in_development` phases, the `owner_persona` is automatically updated to `CWA`.
*   **Workflow Verification:** CWA's primary function here is to prove the **"Happy Path" SDLC loop**. It serves as a target for the Coordinator to hand off the "ball" once planning is complete.
*   **Manual Triggering:** While the state machine (`Artifact#determine_next_owner`) assigns the ball to CWA, any "progress" within the development phase is currently simulated or manually moved via slash commands (`/approve`) rather than being driven by an autonomous CWA agent writing code.

#### When will CWA write code?
Autonomous implementation, tool-calling for file edits, and test execution are the primary focus of **Agent-06** and **Agent-05** (specifically the PRDs related to CWA as an autonomous implementer).

**In summary:** Epic 9 builds the **"Railway Tracks"** (the workflow platform and artifact store) that CWA will eventually run on. It does not include the **"Engine"** (the code-writing logic) for CWA itself.

### Wiring CWA for the Spike: Connecting Agent-06 Engine to Epic 9 Tracks

After a deep review of `run_bulk_test_0004.sh` and the Agent-06 implementation, it is clear that **CWA is already fully capable of autonomous code writing**. The sandbox, white-listed tools, and the `AiWorkflowService` are all verified and "combat-ready."

The missing link for the spike is the **Runtime Bridge** between the Epic 9 UI (the Artifact Store) and the Agent-06 Engine (the Autonomous Runner).

#### 1. What is already "Combat-Ready" (Agent-06):
*   **The Toolbox:** `SafeShellTool`, `GitTool`, and `VcTool` are already configured in `config/initializers/ai_agents.rb`. They are wired to the `AgentSandboxRunner`.
*   **The Engine:** `AiWorkflowService.run` already knows how to coordinate CWA, Planner, and Coordinator.
*   **The Evidence:** `script/run_bulk_test_0004.sh` proves that the `smart_proxy` can handle the high-level context required to drive these tools.

#### 2. What we need to do to "Wire the Spike":
To measure CWA's performance in the spike, we need to bridge the UI to the engine:

1.  **The "Launch" Hook:**
   *   We need to add a trigger (either a `/launch_cwa` slash command or an "Execute Spike" button in the Admin UI).
   *   This trigger must call `AiWorkflowService.run` using the **PRD content** from the `Artifact` payload as the input prompt.

2.  **The Context Bridge:**
   *   We need to ensure the `correlation_id` used by the `AiWorkflowRun` (Epic 9) is passed into the `AiWorkflowService`. This ensures that all autonomous logs, sandbox branches, and tool events are associated with the same Artifact.

3.  **The Result Loopback:**
   *   Currently, `AiWorkflowService` writes results to `bulk_test/` or `tmp/`. To complete the spike measurement, we must ensure the final state (e.g., "Code Written & Tests Passed") is written back into the `Artifact#payload` and the phase is moved to `ready_for_qa`.

4.  **Security Gate (The "Safety"):**
   *   By default, tools are in `dry_run` mode. For the spike, we must ensure the background worker or the thread executing the service has `AI_TOOLS_EXECUTE=true` set in its environment.

### Concrete Action Plan for the Spike:
*   **Step 1:** In `AgentHubChannel`, create a `/spike` command.
*   **Step 2:** This command fetches the `active_artifact`, pulls its `payload['content']` (the PRD), and starts a background thread running `AiWorkflowService.run(prompt: prd_content, correlation_id: run.id)`.
*   **Step 3:** Measure the **Success Rate** (Did CWA commit a passing test to the sandbox?) and **Latency** (How long from `/spike` to `git commit`?).

**Summary:** The "Engine" (CWA) and "Workplace" (Sandbox) are finished. We just need to pull the **"Starter Cord"** from the Epic 9 UI.