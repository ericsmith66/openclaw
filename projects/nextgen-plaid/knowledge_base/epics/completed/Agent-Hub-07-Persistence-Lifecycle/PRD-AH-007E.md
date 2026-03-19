# PRD-AH-007E: Run Enhancements & Cleanup Worker
## Overview
Enhance the `AiWorkflowRun` model with identification fields and implement a background cleanup worker for old/orphaned runs.

## Requirements
- **Functional**: Add `name` and `description` to `AiWorkflowRun`; Cleanup job for runs >30 days old.
- **Non-Functional**: Automated maintenance.
- **Rails Guidance**: `SolidQueue` (ActiveJob) for the cleanup worker.
- **Traceability**: Remaining Capabilities Doc (Suggestions & EAS Feedback).

## Acceptance Criteria
- `AiWorkflowRun` schema includes `name` and `description` string fields.
- A background job runs periodically to archive or delete runs older than 30 days.
- Cleanup thresholds are configurable via ENV.

## Test Cases
- **RSpec**: Verify cleanup worker deletes/archives a run older than the threshold.
