# End-of-Epic Feedback: Agent-Hub-04-Workflow-Persistence

## Observations
- The `AiWorkflowRun` model provides a solid foundation for persisting AI-driven workflows.
- Using `JSONB` for metadata and audit logs allows for flexibility as the system evolves without requiring frequent schema changes.
- The state machine implementation ensures that runs follow a logical progression (draft -> pending -> approved).
- Fixtures for `User` were missing and had to be added to support model testing.

## Suggestions
- Consider adding a `name` or `description` field to `AiWorkflowRun` for easier identification in the UI.
- As the audit log grows, consider extracting it to a separate `AuditLog` table if performance becomes an issue with large `JSONB` blobs.
- Implement a cleanup worker to handle orphaned or very old runs as mentioned in the Epic risks.
- consider adding a different model than draft pending approval to incompase other reviews for feedback between agents 

## User Capabilities
- **Persistence**: Conversations/runs now persist across sessions in the database.
- **Human-in-the-Loop**: Users can submit runs for approval and admins/approvers can approve them.
- **Auditability**: Every status change is logged with a timestamp and optional details (like approver ID).
- **Flexibility**: AI model parameters and other run-specific metadata are stored alongside the run.

## Manual Testing Steps

### 1. Create a new Run
- **Action**: Use the Rails console to create a run.
  ```ruby
  user = User.first
  run = AiWorkflowRun.create(user: user, metadata: { parameters: { temp: 0.7 } })
  ```
- **Expected Output**: A new run is created with status `draft` and the specified metadata.

### 2. Transition to Pending
- **Action**: Call `submit_for_approval!` on the run.
  ```ruby
  run.submit_for_approval!(note: "Ready for review")
  ```
- **Expected Output**: Run status changes to `pending`. `metadata['audit_log']` contains the transition event.

### 3. Approve the Run
- **Action**: Call `approve!` with an approver.
  ```ruby
  approver = User.last
  run.approve!(approver, note: "Approved for execution")
  ```
- **Expected Output**: Run status changes to `approved`. `metadata['audit_log']` contains the approval details including `approver_id`.

### 4. Verify Scopes
- **Action**: Query runs by status.
  ```ruby
  AiWorkflowRun.approved.count
  ```
- **Expected Output**: Returns the count of approved runs.

## Conclusion
Epic 4 successfully establishes the persistence and management layer for AI workflows, enabling more complex, multi-step, and human-verified operations in future epics.
