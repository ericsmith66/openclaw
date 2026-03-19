# PRD-AH-006C: Confirmation Bubbles (Inline Buttons)
## Overview
Implement inline confirmation buttons for high-risk or multi-step agent commands (e.g., approve, delete, handoff), ensuring human-in-the-loop control.

## Requirements
- **Functional**: Render Green (Low), Yellow (Medium), and Red (High) buttons in response to specific commands.
- **Non-Functional**: Stimulus-powered clicks; Turbo Stream updates.
- **Rails Guidance**: partials for `ConfirmationBubble`; Action Cable broadcasts.
- **Traceability**: Original Spec (Main Chat Pane); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Commands like `/approve` or `/delete` trigger a confirmation bubble.
- Buttons are color-coded: Green for read/save, Yellow for handoffs, Red for deletes/merges.
- Clicking a button executes the associated action (e.g., updating `AiWorkflowRun` status) and updates the bubble to a "Confirmed" state.

## Test Cases
- **Integration**: Type `/handoff`; verify a Yellow "Confirm Handoff" button appears. Click it and verify the handoff proceeds.
