# Feedback: Epic 4 - Workflow Persistence & Management

### Summary
Connecting the UI to `AiWorkflowRun` ensures that conversations are durable and audit-able.

### Key Strengths
- **Traceability**: Audit logs for approvals are critical for financial compliance.
- **State Management**: Explicit "Pending" vs "Approved" states facilitate human-in-the-loop control.

### Recommended Improvements
- **Safety Gates**: Add a "Stop Workflow" button to the Workflow Monitor pane even if it is read-only.
- **Time Machine Sidebar**: Group runs by date or "Active vs Archived" to prevent a wall of text.

### Checklist
- [x] PRD-AH-004A: AiWorkflowRun Model & Migration
- [x] PRD-AH-004B: Run Status Transitions
- [x] PRD-AH-004C: Metadata & Audit Storage
