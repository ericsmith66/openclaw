# PRD-AH-007F: Robust State & Redis Support
## Overview
Improve the resilience of the Agent Hub by ensuring persona state is robust and moving Action Cable stream tracking to a shared store (Redis) for production readiness.

## Requirements
- **Functional**: Move active stream tracking to Redis; Persist active persona across sessions/reloads.
- **Non-Functional**: Production-grade stability.
- **Rails Guidance**: Update `AgentHubChannel` to use `Redis` for global `active_streams` count (EAS: OK).
- **Traceability**: Remaining Capabilities Doc (Suggestions & EAS Feedback).

## Acceptance Criteria
- Multiple server instances share the `active_streams` count accurately via Redis.
- Refreshing the page maintains the last selected persona (SAP, Conductor, etc.).
- Persona selection is stored in `User#preferences` or a dedicated session-backed store.

## Test Cases
- **Integration**: Switch to "Conductor"; reload; verify "Conductor" is still active.
- **RSpec**: Mock Redis and verify `AgentHubChannel` updates the global count correctly.
