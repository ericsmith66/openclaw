# PRD-AH-011B: WorkflowBridge & Intent Detection

Part of Epic 11: Consolidated SDLC Spike & Core Bridge.

---

## Problem

Using slash commands (`/approve`, `/plan`) is unintuitive for a natural language agent interface. We need a way for agents to trigger workflow actions via natural language and structured tags.

## User story

As a developer, I want the system to detect agent intent from their responses so that the appropriate UI actions (like confirmation buttons) are automatically presented to the user.

---

## A) What SAP/CWA produce (workflow output)

Agents will include structured intent tags in their Markdown responses.

- Format: `[ACTION: <INTENT>: <ID>]`
- Example: `[ACTION: MOVE_TO_ANALYSIS: 123]`
- These tags are used by the Bridge to trigger UI state.

---

## B) What we build (platform/engineering work)

- **Action Tag Registry:** The Bridge MUST use a centralized registry of valid `<INTENT>` strings. Any intent detected that is not in the registry should be ignored or logged as a hallucination.
- **Silent vs. Human Actions:** The Bridge MUST support:
  - **Human-in-the-loop Actions:** Trigger a confirmation button in the UI (default).
  - **Silent Actions:** Automate backend state changes (e.g., updating a task status) without requiring human clicking, but providing a notification message.
- **Tag Collision Mitigation:** The Bridge parser MUST only scan messages where `role: assistant`. User messages containing action tags MUST be ignored to prevent accidental or malicious workflow triggers.
- **Execution Feedback (Collaboration):** When the Bridge triggers a background workflow (like a CWA build), the agent MUST respond in the Agent Hub with a natural language summary of what was initiated and what the user can expect.
- **Deprecation:** Remove slash command logic from `AgentHubChannel` in favor of the Bridge.

---

## C) UI elements introduced/changed

- **Confirmation Bubbles:** Triggered automatically when the Bridge detects an intent tag.

---

## Functional requirements

- Create `AgentHub::WorkflowBridge`.
- Implement parsing for `[ACTION: <INTENT>: <ID>]` in agent response streams.
- Bridge should link `Conversation` IDs to `Artifact` IDs.

---

## Acceptance criteria

- AC1: Typing a natural language request that causes an agent to respond with an ACTION tag triggers the correct UI button.
- AC2: Slash commands are no longer the primary way to advance state.
- AC3: The bridge correctly identifies the `Artifact` associated with the current `Conversation`.
- AC4: Agents provide "Collaborative Feedback" by messaging the human when background tasks (like builds) are started or completed.

---

### Testing Steps for AH-011B Workflow Bridge

To test the natural language intent detection and workflow progression, follow these exact steps. Since your `artifacts` table is empty, we will start by bootstrapping a record.

#### 1. Bootstrap Data (Create a Backlog Item)
Since there are no records, you must create one first. You can do this using the legacy slash command (which is still supported for creation).
*   Go to the **Agent Hub** and select the **SAP** persona.
*   **Action:** Type `/backlog Build a responsive navigation menu`
*   **Expected Result:** You should see a response like: `Successfully added to backlog: Build a responsive navigation menu (ID: 1)`.
*   *Note: Remember the ID (e.g., 1).*

#### 2. Test Natural Language Intent Detection (Human-in-the-Loop)
This verifies that the agent can detect your intent and present a confirmation button.
*   **Action:** Type "Let's move item 1 to analysis."
*   **Expected Result:**
    *   The agent responds with a natural language message (e.g., "I've flagged item 1 for analysis. Please confirm the transition.").
    *   A **"Move to Analysis"** button appears automatically at the bottom of the agent's response bubble.
*   **Action:** Click the **"Move to Analysis"** button.
*   **Verification:** The button changes to "Confirmed," and a system notification appears: `Artifact '...' moved to phase: Ready for analysis.`

#### 3. Test Phase Progression (Moving the Artifact Forward)
You can advance the artifact through its entire lifecycle by chatting. Each "Approve" style intent moves the artifact to the next phase in the sequence.

| Current Phase | Goal Phase | Suggested User Message | Intent Tag Detected |
| :--- | :--- | :--- | :--- |
| **Backlog** | `ready_for_analysis` | "Move item 1 to analysis." | `MOVE_TO_ANALYSIS` |
| **Ready for Analysis** | `in_analysis` | "Start analyzing item 1." | `MOVE_TO_ANALYSIS` |
| **In Analysis** | `ready_for_dev_feedback` | "The analysis for item 1 is done." | `APPROVE_PRD` |
| **Ready for Dev Feedback**| `ready_for_development` | "Move item 1 to dev." | `READY_FOR_DEV` |
| **Ready for Development** | `in_development` | "Start development on item 1." | `START_DEV` |
| **In Development** | `ready_for_qa` | "Item 1 is ready for QA." | `COMPLETE_DEV` |
| **Ready for QA** | `complete` | "Approve the QA for item 1." | `APPROVE_QA` |

#### 4. Test Silent Actions (No Human Interaction)
Some actions are "silent" and update the backend state immediately without showing a button.
*   **Action:** Type "Start the build for item 1."
*   **Expected Result:** The agent responds with a confirmation, and you immediately see a notification: `⚡ [System Notification]: Automated action START_BUILD executed. Artifact moved to...`

#### 5. Verification Check
At any point, you can verify the state by typing `/inspect`.
*   **Action:** Type `/inspect`
*   **Expected Result:** A detailed summary of the current artifact, including its phase, owner, and audit trail, will be displayed.

#### Summary of Phases & Work expected

The artifact moves through these phases in order when "approved". Each phase involves specific work performed by either an AI agent or a Human.

1.  **`backlog`**
    *   **Owner:** SAP / Human
    *   **Work:** Initial feature request capture. The user provides a high-level goal or requirement. SAP summarizes the request and ensures it is properly added to the system with a clear title and ID.
2.  **`ready_for_analysis`**
    *   **Owner:** SAP
    *   **Work:** Prioritization and grooming. SAP confirms the item is sufficiently defined to be picked up for technical analysis. This phase acts as a queue for the Coordinator.
3.  **`in_analysis`**
    *   **Owner:** Coordinator
    *   **Work:** Requirements engineering and planning. The Coordinator (or specialized Planner) performs a deep dive, generating a structured PRD, technical breakdown, and a list of micro-tasks required for implementation.
4.  **`ready_for_development_feedback`**
    *   **Owner:** SAP / Human
    *   **Work:** Quality gate for the plan. The human or SAP reviews the PRD and micro-tasks generated by the Coordinator to ensure technical feasibility and alignment with original business requirements.
5.  **`ready_for_development`**
    *   **Owner:** CWA (Coordinator/Conductor handoff)
    *   **Work:** Implementation preparation. Final sign-off on the technical plan. The environment is prepared, and the artifact is queued for the Coding Workflow Agent (CWA).
6.  **`in_development`**
    *   **Owner:** CWA
    *   **Work:** Active implementation. CWA executes the micro-tasks defined in the plan, writing code, creating tests, and performing local linting/verification of the features.
7.  **`ready_for_qa`**
    *   **Owner:** Coordinator
    *   **Work:** Verification and testing. The Coordinator reviews the completed work, runs the full suite of automated tests, and verifies that the implementation matches the PRD specifications.
8.  **`complete`** (Final Phase)
    *   **Owner:** Human
    *   **Work:** Final validation and sign-off. The human user verifies the feature in the application. Once satisfied, the artifact is marked as complete and moved out of the active workflow.
