# PRD-AH-004B: Run Status Transitions
## Overview
State management for human-in-the-loop per Vision 2026.
## Requirements
- Functional: Transition draft->pending->approved.
- Non-Functional: Atomic.
- Rails Guidance: AASM or simple enum.
- Logging: JSON state change.
- Disclaimers: None.
## Architectural Context
Approval workflow.
## Acceptance Criteria
- Transitions valid.
- Invalid raise.
- Callback triggers.
- UI button updates.
- Broadcast status.
- Logs transition.
- Scopes for UI.
## Test Cases
- RSpec: aasm state transitions.
- Integration: click "Approve"; assert status approved.
## Workflow for Junie
- Pull main; branch feature/prd-ah-004b.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
