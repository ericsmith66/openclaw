# PRD-AH-007A: Sidebar Real-Data Wiring
## Overview
Replace the hardcoded stub data in the Conversations Sidebar with real `AiWorkflowRun` records from the database, scoped to the current owner.

## Requirements
- **Functional**: Fetch `AiWorkflowRun` records; Scope to `current_user`; Order by `updated_at DESC`.
- **Non-Functional**: Efficient querying; Real-time updates via Action Cable.
- **Rails Guidance**: Update `AgentHubsController#show` and `ConversationSidebarComponent`.
- **Traceability**: Original Spec (Conversations Sidebar); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Sidebar lists actual `AiWorkflowRun` records from the database.
- Clicking a conversation loads it into the main chat pane (using existing Turbo Frame).
- New runs appear at the top of the list immediately upon creation.

## Test Cases
- **Integration**: Create a run in the console; refresh `/agent_hub`; verify it appears in the sidebar.
