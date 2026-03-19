# PRD-AH-008A: Workflow Monitor (Inter-agent View)
## Overview
Implement the "Workflow Monitor" tab as a read-only view that captures the "back and forth" communication between multiple agents, providing high visibility into collaborative workflows.

## Requirements
- **Functional**: Dedicated "Workflow Monitor" persona tab; Read-only chat pane; Filter messages to show multi-agent interactions.
- **Non-Functional**: "Less is more" (EAS: Start with the back and forth between agents); Real-time updates.
- **Rails Guidance**: Dedicated scope in `AiWorkflowRun` or message-level filtering for inter-agent broadcasts.
- **Traceability**: Original Spec (Persona Tabs); Remaining Capabilities Doc (User Capabilities & EAS Feedback).

## Acceptance Criteria
- "Workflow Monitor" tab visible in the Persona bar.
- Selecting the tab displays a read-only feed of agent-to-agent messages (e.g., SAP handing off to Conductor).
- User input is disabled in this view.
- Real-time broadcasts from all relevant agents are visible here.

## Test Cases
- **Integration**: Trigger a handoff between two agents; verify the handoff message appears in the Workflow Monitor tab.
