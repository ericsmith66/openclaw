# PRD-AH-011C: SDLC Action Buttons & Descriptive Labels

Part of Epic 11: Consolidated SDLC Spike & Core Bridge.

---

## Problem

Generic "Approve" buttons are ambiguous. Users need to know exactly what state transition they are authorizing.

## User story

As a user, I want to see descriptive labels on action buttons (e.g., "Save to Backlog", "Finalize PRD") so I can confidently manage the SDLC flow.

---

## A) What SAP/CWA produce (workflow output)

Agents trigger these buttons via the `[ACTION: <INTENT>: <ID>]` tags defined in PRD-11B.

---

## B) What we build (platform/engineering work)

- **System Message Injection:** When a state transition occurs via a button click, the system MUST inject a hidden or visible "System Message" into the conversation (e.g., `[SYSTEM: Phase changed to Analysis]`). This ensures the LLM's context is immediately updated regarding the world state change.
- Update `ConfirmationBubbleComponent` to support dynamic, descriptive labels.
- Map `INTENT` tags to specific human-readable labels and backend actions.
- Ensure each action performs a hard-save to the `Artifact` database record.

---

## C) UI elements introduced/changed

- **Confirmation Buttons:** Now use descriptive labels:
  - `Save to Backlog`
  - `Move to Analysis`
  - `Finalize PRD`
  - `Approve Plan`
  - `Start Implementation`

---

## Functional requirements

- Dynamic label mapping in the UI.
- Direct `Artifact` state updates on button click.
- Visual feedback in the Artifact Preview (PRD-11E) when an action is taken.

---

## Acceptance criteria

- AC1: Buttons show "Move to Analysis" instead of "Approve" when an agent proposes moving to analysis.
- AC2: Clicking the button updates the `Artifact` phase in the database.
- AC3: The UI reflects the new phase immediately.

---

## Human Testing Steps & Expected Results

1.  **Step:** Trigger a state transition (e.g., move from Draft to Analysis).
    *   **Expected Result:** A button appears with the specific text "Move to Analysis" rather than a generic "Confirm" or "Approve".
2.  **Step:** Click the "Move to Analysis" button.
    *   **Expected Result:** The button should indicate it has been clicked (e.g., disappear or change to "Confirmed"). The sidebar/Artifact Preview should update its status to "Analysis".
3.  **Step:** Refresh the page after clicking the button.
    *   **Expected Result:** The Artifact should remain in the "Analysis" phase, proving the change was persisted to the database via the `WorkflowBridge`.
