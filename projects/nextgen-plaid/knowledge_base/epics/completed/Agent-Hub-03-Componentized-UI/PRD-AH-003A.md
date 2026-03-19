# PRD-AH-003A: Persona Tabs & Switching
## Overview
Tabs for context, efficient multi-agent per Vision 2026.
## Requirements
- Functional: Update session; broadcast.
- Non-Functional: Colors; wrap.
- Rails Guidance: PersonaTabsComponent.
- Logging: JSON switches.
- Disclaimers: None.
## Architectural Context
Session; Cable updates.
## Acceptance Criteria
- Colors (SAP blue).
- Update pane.
- Broadcast "…".
- No reload.
- Logs persona/id.
- Mobile wrap.
- Default SAP.
## Test Cases
- RSpec: css ".bg-blue-500".
- Integration: click "Conductor"; assert session.
## Workflow for Junie
- Pull main; branch feature/prd-ah-003a.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
