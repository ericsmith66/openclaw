# PRD-AH-003B: Conversation Sidebar
## Overview
Sidebar for monitoring, badges per Vision 2026.
## Requirements
- Functional: List/load from run.
- Non-Functional: Collapsible; badges pending.
- Rails Guidance: ConversationSidebarComponent; scopes.
- Logging: JSON selections.
- Disclaimers: None.
## Architectural Context
AiWorkflowRun; Cable refresh.
## Acceptance Criteria
- List with titles/snippets.
- Badges on pending.
- Load pane.
- Mobile collapse.
- Auto-refresh.
- No leak.
- Logs id.
## Test Cases
- RSpec: scope pending include mock.
- Integration: css ".badge-error".
## Workflow for Junie
- Pull main; branch feature/prd-ah-003b.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
