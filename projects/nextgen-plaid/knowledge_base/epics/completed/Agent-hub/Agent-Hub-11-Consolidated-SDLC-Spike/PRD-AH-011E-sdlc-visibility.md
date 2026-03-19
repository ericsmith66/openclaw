# PRD-AH-011E: SDLC Visibility (Artifact Preview)

Part of Epic 11: Consolidated SDLC Spike & Core Bridge.

---

## Problem

Users need a persistent view of the "Current State of Work" (the PRD, the Plan, the Status) without having to scroll back through a long conversation.

## User story

As a user, I want a persistent preview of the active Artifact so I can see the current phase, owner, and requirements at a glance.

---

## A) What SAP/CWA produce (workflow output)

Agents update the `Artifact` content (PRD/Plan) and metadata. These updates are instantly reflected in the Preview.

---

## B) What we build (platform/engineering work)

- **Artifact Preview Component:** A dedicated UI section (e.g., a sidebar or collapsible panel) in the Agent Hub.
- **Real-time Sync:** Use ActionCable to push updates to the Preview whenever the `Artifact` record changes.
- **Toggleable Views:** Allow switching between "PRD view" and "Technical Plan view".

---

## C) UI elements introduced/changed

- **Artifact Preview Sidebar:** Displays Name, Phase, Owner, and a Markdown-rendered view of the PRD/Plan.
- **Phase indicator:** Visual representation of the current SDLC phase.

---

## Functional requirements

- Real-time updates via ActionCable.
- Markdown rendering within the Preview component.
- Display key metadata (Owner, Last Updated, Phase).

---

## Acceptance criteria

- AC1: The Preview window updates instantly after an agent saves a draft PRD.
- AC2: The Preview window updates instantly when a human clicks a status mover button.
- AC3: The user can toggle between the full PRD and the list of tasks (Technical Plan).
- AC4: The sidebar displays the specific "Build Artifacts" or "Status Notes" provided by the CWA after a run, eliminating the need to check logs.

---

## Human Testing Steps & Expected Results

1.  **Step:** Open the Agent Hub and ensure the "Artifact Preview" sidebar is visible.
    *   **Expected Result:** The sidebar shows the current phase (e.g., "Draft") and basic artifact info.
2.  **Step:** Ask the agent to "Update the PRD with a new section on Performance."
    *   **Expected Result:** As soon as the agent confirms the update, the "Artifact Preview" content refreshes (via ActionCable) to show the new "Performance" section without a page reload.
3.  **Step:** Click a "Move to Analysis" button in the chat.
    *   **Expected Result:** The "Phase" indicator in the sidebar instantly changes from "Draft" to "Analysis".
4.  **Step:** Toggle the sidebar view (if implemented).
    *   **Expected Result:** The view switches between the Markdown PRD and the Technical Plan/Task list.
5.  **Step:** After a CWA run completes, check the sidebar for "Implementation Notes".
    *   **Expected Result:** The sidebar displays a summary of the code built (e.g., "Created /admin route, Added Dashboard view") without needing to check `agent_logs/`.
