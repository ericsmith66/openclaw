# PRD-AH-003C: Input Bar & Basic Interactions
## Overview
Input for convos/commands, initiation per Vision 2026.
## Requirements
- Functional: Enqueue; hints.
- Non-Functional: Attach uploads.
- Rails Guidance: InputBarComponent; Stimulus.
- Logging: JSON submits.
- Disclaimers: None.
## Architectural Context
Active Storage; AiFinancialAdvisor.
## Acceptance Criteria
- Create run.
- Suggest /commands.
- Attach to run.
- Broadcast pane.
- No invalid.
- Logs payload.
- Mobile friendly.
## Test Cases
- RSpec: parser /handoff eq :handoff.
- Integration: submit; assert new run.
## Workflow for Junie
- Pull main; branch feature/prd-ah-003c.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
