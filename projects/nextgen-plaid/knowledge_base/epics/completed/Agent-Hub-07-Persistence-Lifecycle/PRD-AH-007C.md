# PRD-AH-007C: Soft-Delete & Archive Lifecycle
## Overview
Implement a soft-delete mechanism for `AiWorkflowRun` records, allowing users to archive conversations from the sidebar without permanently removing data.

## Requirements
- **Functional**: Trash icon in sidebar; Confirmation modal; Mark as `archived` or use `deleted_at` timestamp.
- **Non-Functional**: Filter archived runs from default sidebar view.
- **Rails Guidance**: Add `archived_at` column to `AiWorkflowRuns`; Scopes for active vs archived.
- **Traceability**: Original Spec (User Capabilities); Remaining Capabilities Doc (Decisions & EAS Feedback).

## Acceptance Criteria
- Clicking trash icon on a sidebar entry opens a DaisyUI confirmation modal.
- Confirming the delete hides the run from the sidebar immediately.
- The record remains in the database with an `archived_at` timestamp (EAS: Soft delete only).

## Test Cases
- **Integration**: Delete a run; verify it disappears from sidebar; verify it still exists in DB with `archived_at` set.
