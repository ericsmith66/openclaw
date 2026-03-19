# PRD-AH-001A: Agent Hub Routing & Auth
## Overview
Secure route for /agent_hub, owner-only, no Plaid overlap—aligns with Vision 2026 privacy.
## Requirements
- Functional: GET loads controller; non-owners redirect.
- Non-Functional: <500ms; RLS ready.
- Rails Guidance: AgentHubsController#show; Devise/Pundit.
- Logging: JSON access.
- Disclaimers: None.
## Architectural Context
MVC; local Ollama prep.
## Acceptance Criteria
- Route works for owners.
- 403 for others.
- Empty layout loads.
- Routes include /agent_hub.
- No Plaid interference.
- Logs user_id.
## Test Cases
- RSpec: expect(get("/agent_hub")).to redirect for non-owner.
- Integration: sign_in owner; visit /agent_hub; success.
## Workflow for Junie
- Pull main; branch feature/prd-ah-001a.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
