# PRD-AH-001B: Basic Turbo Frame Structure
## Overview
Turbo Frames, header/footer for persistence/navigation—seamless per Vision 2026.
## Requirements
- Functional: Header link; footer text.
- Non-Functional: Responsive; no reload.
- Rails Guidance: agent_hub.html.erb; DaisyUI.
- Logging: None.
- Disclaimers: Footer "Educational—consult CFP/CPA".
## Architectural Context
Turbo for SPA; RAG snapshots.
## Acceptance Criteria
- Header with link.
- Link redirects turbo.
- Footer visible.
- Frames wrap.
- No degraded errors.
- <500ms.
## Test Cases
- RSpec: have_link "Mission Control".
- Integration: click_link; assert path.
## Workflow for Junie
- Pull main; branch feature/prd-ah-001b.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
