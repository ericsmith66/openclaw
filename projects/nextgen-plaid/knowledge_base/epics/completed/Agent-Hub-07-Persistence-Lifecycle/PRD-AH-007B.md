# PRD-AH-007B: Auto-titling & Pending Badges
## Overview
Automatically generate titles for `AiWorkflowRun` records based on their content and implement red "Pending" badges in the sidebar for runs requiring human attention.

## Requirements
- **Functional**: Logic to extract/generate title (e.g., first 5 words or AI-summarized); Red badge for `status: :pending`.
- **Non-Functional**: No delay in sidebar rendering.
- **Rails Guidance**: `AiWorkflowRun` model callback or background job for titling.
- **Traceability**: Original Spec (Conversations Sidebar); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Conversations in the sidebar show descriptive titles instead of IDs or timestamps.
- Any `AiWorkflowRun` with `pending` status displays a red DaisyUI badge.
- Sidebar search works against these generated titles.

## Test Cases
- **Integration**: Start a conversation about "Tax Strategy"; verify the sidebar entry eventually titles itself "Tax Strategy...".
- **RSpec**: Verify red badge appears only for `pending` status.
