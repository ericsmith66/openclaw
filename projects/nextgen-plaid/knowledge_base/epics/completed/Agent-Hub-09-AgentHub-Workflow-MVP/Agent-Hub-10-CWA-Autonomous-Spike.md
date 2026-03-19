# Epic 10: CWA Autonomous Implementation Spike

**Source:** Derived from `vision-agent_hub-workflow.md` §10/11 and `functional_gaps.md`.
**Goal:** Bridge the gap between the **Epic 9 Artifact Store** and the **Agent-06 Autonomous CWA Engine** to measure end-to-end code generation performance.

---

## 1. Problem Statement
Epic 9 successfully built the "Tracks" (Artifact Store, Phase Transitions, Persona Ownership). Agent-06 verified the "Engine" (Autonomous CWA, White-listed tools, Sandbox). However, they are not yet connected. To prove the vision, we need to "Launch" the autonomous engine from a verified PRD artifact and measure the results.

## 2. User Story
As an owner, I can `/approve` a PRD artifact to the `ready_for_development` phase, then trigger an **Autonomous Spike** where CWA takes the PRD, sets up a sandbox, writes code, and runs tests without further human intervention.

---

## 3. Orchestration & Handover
This spike bridges the human-collaboration space (Agent Hub) with the background-execution space (AiWorkflowService), involving both the **Coordinator** and **CWA**.

### 3.1 The "Launch" Hook
- **Trigger:** A new slash command `/spike` or `/plan` in the Agent Hub.
- **Orchestration Logic:**
  1. Fetch the `active_artifact` linked to the current `SapRun`.
  2. Extract the `payload['content']` (the PRD markdown).
  3. Invoke `AiWorkflowService.run(prompt: prd_content, correlation_id: current_run_id)`.
  4. Set `AI_TOOLS_EXECUTE=true` in the execution environment.

### 3.2 Coordinator Planning Phase
- When triggered via `/plan` or as the first step of `/spike`, the **Coordinator** takes the PRD.
- The Coordinator MUST hand off to the **Planner** to generate micro-tasks.
- The Planner uses the `TaskBreakdownTool` to produce the technical implementation plan.
- The Coordinator then hands off to **CWA** for the implementation phase.

### 3.3 Handover Data
| Source Field | Target Mapping |
| :--- | :--- |
| `Artifact.payload['content']` | `AiWorkflowService` initial prompt |
| `AiWorkflowRun.id` | `correlation_id` (ensures audit log parity) |
| `Artifact.id` | Passed in context to track which object is being implemented |

---

## 4. Context & RAG Injection
To ensure CWA has the necessary technical and project context, we will inject a multi-layered RAG prefix.

### 4.1 Static RAG (Project Baseline)
- Use `SapAgent::RagProvider.build_prefix("default")` to inject:
  - `MCP.md` (Tooling definitions)
  - `0_AI_THINKING_CONTEXT.md` (Reasoning protocols)

### 4.2 Eric Grok Static RAG (Implementation Baseline)
- Explicitly inject `knowledge_base/static_docs/eric_grok_static_rag.md` into the CWA agent's system prompt.
- This provides the "Grok-4 approved" architectural patterns and coding standards used in the successful `run_bulk_test_0004.sh`.

---

## 5. CWA Execution (The "Engine")
- **Sandbox:** CWA will use `AgentSandboxRunner` to create a per-run worktree.
- **Tools:** CWA will use its verified white-listed tools:
  - `SafeShellTool`: Run `bundle exec rails test`.
  - `GitTool`: Create branch, add files, and commit ONLY if tests pass.
  - `ProjectSearchTool`: Discover existing class definitions.
  - `VcTool`: Perform read-only git operations.

---

## 6. Spike Measurement (Success Criteria)
The primary goal of this spike is to measure:

1.  **Success Rate:** Does CWA commit a passing test and implementation to the sandbox branch for the given PRD?
2.  **Latency:** Total time from `/spike` trigger to terminal state (`ready_for_qa` or `failed`).
3.  **Tool Efficacy:** Ratio of successful tool calls to failed/blocked calls.
4.  **Audit Fidelity:** Does the `AiWorkflowRun` audit log correctly capture the autonomous tool-steps alongside the human approvals?

## 7. Post-Spike Result Loopback
- Upon completion, `AiWorkflowService` must:
  1. Transition the `Artifact` phase to `ready_for_qa` (Success) or `in_analysis` (Failure).
  2. Attach the `git diff` and `test results` to the `Artifact.payload['implementation_notes']`.
  3. Broadcast a completion message to the `AgentHubChannel`.
