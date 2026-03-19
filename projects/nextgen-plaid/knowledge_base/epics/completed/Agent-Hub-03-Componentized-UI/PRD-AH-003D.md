# PRD-AH-003D: Sidebar Search & Filter
## Overview
Search for volume, quick access per Vision 2026.
## Requirements
- Functional: Filter title/id.
- Non-Functional: Real-time.
- Rails Guidance: Stimulus; scopes.
- Logging: JSON searches.
- Disclaimers: None.
## Architectural Context
AiWorkflowRun queries.
## Acceptance Criteria
- Filter list.
- Match title/snippet.
- Clear empty.
- Broadcast updates.
- No hit.
- Logs query.
- Mobile works.
## Test Cases
- RSpec: scope search "PRD" match [mock].
- Integration: fill search; assert filtered.
## Workflow for Junie
- Pull main; branch feature/prd-ah-003d.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
