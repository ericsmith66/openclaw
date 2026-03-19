# PRD-AH-006E: Thought Bubbles & Latency Metrics
## Overview
Separate agent "thoughts" from final output using distinct gray bubbles and implement metrics to track Action Cable latency, specifically for the "Interrogation" payload.

## Requirements
- **Functional**: Separate broadcast type for `thought`; Render gray, italicized bubbles for thoughts; Log latency for `report_state` events.
- **Non-Functional**: Transparent reasoning; Data-driven optimization.
- **Rails Guidance**: Update `AgentHubChannel#report_state` to calculate time delta; Update `chat_pane_controller.js` to handle thoughts.
- **Traceability**: Original Spec (Main Chat Pane); Remaining Capabilities Doc (Suggestions & EAS Feedback).

## Acceptance Criteria
- Agent thoughts appear in gray bubbles with a distinct "Thought" header or style.
- Thoughts are omitted from the final "User-facing" summary if applicable.
- Rails logs include `event: "interrogation_latency"` with a `ms` duration for every interrogation report.

## Test Cases
- **RSpec**: Verify `AgentHubChannel` logs latency on `report_state`.
- **Integration**: Simulate a stream with thoughts; verify they appear in gray.
