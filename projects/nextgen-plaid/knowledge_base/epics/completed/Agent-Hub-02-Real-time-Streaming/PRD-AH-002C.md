# PRD-AH-002C: Browser Interrogation Cable
## Overview
Bidirectional cable commands to fetch browser-side state (DOM/Console/Stimulus) for debugging—improves visibility for Junie and developers per Vision 2026.
## Requirements
- Functional: `interrogate` command in Action Cable; return structured JSON (DOM snapshot, console logs).
- Non-Functional: Secure (owner-only); <200ms latency for small snapshots.
- Rails Guidance: `AgentHubChannel#interrogate`; Stimulus `DebugController`.
- Logging: JSON payload in Rails logs.
- Disclaimers: None.
## Architectural Context
Action Cable bidirectional; Stimulus state management.
## Acceptance Criteria
- Request DOM snapshot via cable.
- Receive console logs payload.
- Log to Rails development log.
- Only works for authenticated owner.
- No impact on Plaid syncs.
## Test Cases
- RSpec: `broadcast_to` channel triggers response.
- Integration: Trigger interrogation; assert log entry.
## Workflow for Junie
- Pull main; branch feature/prd-ah-002c.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
