# PRD-AH-002B: Fallback Polling Integration
## Overview
Polling for degraded, reliable escalations per Vision 2026.
## Requirements
- Functional: 5s poll on disconnect.
- Non-Functional: Graceful; low CPU.
- Rails Guidance: Turbo config; reuse.
- Logging: JSON triggers.
- Disclaimers: None.
## Architectural Context
Cable fallback; no deps.
## Acceptance Criteria
- Poll on disconnect.
- Updates pane.
- No loops.
- Reconnect preferred.
- Logs events.
- Performance same.
- Mobile tested.
## Test Cases
- Integration: disconnect; assert poll.
- RSpec: Turbo receive poll.
## Workflow for Junie
- Pull main; branch feature/prd-ah-002b.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
