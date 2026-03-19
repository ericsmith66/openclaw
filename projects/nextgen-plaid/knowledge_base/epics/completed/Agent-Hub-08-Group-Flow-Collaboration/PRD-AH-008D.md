# PRD-AH-008D: Dynamic Autocomplete
## Overview
Enhance the input bar autocomplete to dynamically suggest commands based on the active persona's capabilities and current context.

## Requirements
- **Functional**: Fetch valid commands from the backend; Context-aware suggestions (e.g., `/approve` only when pending).
- **Non-Functional**: Zero-latency perception.
- **Rails Guidance**: Dedicated endpoint or data-attribute in `InputBarComponent` for valid commands.
- **Traceability**: Original Spec (Input Bar); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Typing `/` in the input bar shows a list of commands relevant to the active persona.
- The list updates if the persona is switched.
- High-risk commands (e.g., `/delete`) are clearly labeled or styled.

## Test Cases
- **Integration**: On the SAP tab, type `/`; verify `/handoff` is suggested. On the Workflow Monitor, verify no commands are suggested (read-only).
