# PRD-AH-001C: Mobile Layout Spike
## Overview
Responsive spike for mobile usability—on-the-go oversight per Vision 2026.
## Requirements
- Functional: Collapse sidebar; wrap tabs.
- Non-Functional: 375px test; touch.
- Rails Guidance: Tailwind updates.
- Logging: None.
- Disclaimers: Inherit.
## Architectural Context
DaisyUI mobile; no Plaid.
## Acceptance Criteria
- Hamburger toggles.
- Tabs wrap.
- No overlaps at 375px.
- Capybara mobile pass.
- Load unchanged.
- Footer visible.
- Tappable links.
## Test Cases
- Integration: mobile true; assert ".collapsed".
- RSpec: preview mobile viewport.
## Workflow for Junie
- Pull main; branch feature/prd-ah-001c.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
