# PRD-AH-011F: Reversion & Clean-room Bridge Migration

Part of Epic 11: Consolidated SDLC Spike & Core Bridge.

---

## Problem

The current SDLC logic is scattered across `AgentHubChannel`, `AiWorkflowService`, and various controllers, making it brittle and hard to extend.

## User story

As a maintainer, I want a single source of truth for SDLC state transitions so that the system remains robust and predictable.

---

## A) What SAP/CWA produce (workflow output)

No direct agent output; this is an architectural cleanup.

---

## B) What we build (platform/engineering work)

- **Consolidation:** Move all SDLC logic (phase transitions, artifact updates) to `AgentHub::WorkflowBridge`.
- **Cleanup:** Remove manual state transitions and "spaghetti" code from `AgentHubChannel` and `AiWorkflowService`.
- **Validation:** Ensure all existing "happy path" workflows still function correctly under the new architecture.
- **Automated test coverage:** to ensure no regressions during the refactor. test should be implemented before the refactor.
---

## C) UI elements introduced/changed

- No direct UI changes.

---

## Functional requirements

- Centralized state machine or transition logic in `WorkflowBridge`.
- Decouple `AgentHubChannel` from direct database updates of `Artifact` records.
- Comprehensive logging of all Bridge-mediated transitions.

---

## Acceptance criteria

- AC1: Manual state transitions are removed from `AgentHubChannel`.
- AC2: The "Happy Path" (Draft -> Analysis -> Planning -> Implementation) is fully functional via the Bridge.
- AC3: Codebase is cleaner and follows the new architectural pattern.

---

## Human Testing Steps & Expected Results

1.  **Step:** Perform a full SDLC loop (Draft -> Analysis -> Planning -> Implementation) and check the database/logs.
    *   **Expected Result:** Every transition is logged as being handled by `AgentHub::WorkflowBridge`.
2.  **Step:** Search the codebase for `artifact.update(phase:` outside of the `WorkflowBridge`.
    *   **Expected Result:** No occurrences in `AgentHubChannel` or `AiWorkflowService`.
3.  **Step:** Attempt to use an old slash command like `/approve`.
    *   **Expected Result:** The system should either ignore it, provide a deprecation warning, or route it through the new Bridge, but it should NOT bypass the Bridge logic.
