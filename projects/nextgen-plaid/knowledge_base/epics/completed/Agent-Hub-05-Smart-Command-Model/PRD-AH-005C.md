# PRD-AH-005C: Dynamic Model Discovery
## Overview
Fetch local models for Hub per Vision 2026.
## Requirements
- Functional: Populate dropdown.
- Non-Functional: Cached 1h.
- Rails Guidance: ModelDiscoveryService.
- Logging: JSON models.
- Disclaimers: None.
## Architectural Context
Ollama /v1/models.
## Acceptance Criteria
- Get list.
- Map names.
- Refresh on load.
- Fallback ENV.
- Logs count.
- UI dropdown.
- Mobile scrollable.
## Test Cases
- RSpec: discovery.call includes "llama3".
- Integration: open dropdown; assert list.
## Workflow for Junie
- Pull main; branch feature/prd-ah-005c.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
