# PRD-AH-005A: Command Parser Service
## Overview
Regex parser for /commands per Vision 2026.
## Requirements
- Functional: Parse /handoff, /search.
- Non-Functional: Fast.
- Rails Guidance: AgentCommandParser.
- Logging: JSON parsed.
- Disclaimers: None.
## Architectural Context
Input routing.
## Acceptance Criteria
- Recognizes /.
- Extracts args.
- Returns service object.
- Handles invalid.
- Logs command.
- Scoped to Hub.
- No Plaid.
## Test Cases
- RSpec: parser.call("/search x") eq :search.
- Integration: submit command; assert route.
## Workflow for Junie
- Pull main; branch feature/prd-ah-005a.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
