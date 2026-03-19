# PRD-AH-008C: File Uploads & Active Storage
## Overview
Integrate `Active Storage` to allow users to upload files (logs, schemas, documents) directly into an `AiWorkflowRun` via the Agent Hub input bar.

## Requirements
- **Functional**: Upload button in input bar; Associate uploads with `AiWorkflowRun`; Pass file metadata/content to AI if applicable.
- **Non-Functional**: Secure storage; Cap file sizes.
- **Rails Guidance**: `has_many_attached :attachments` in `AiWorkflowRun`.
- **Traceability**: Original Spec (Input Bar); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Upload button (plus icon) in the input bar is functional.
- Selecting a file and submitting the message attaches the file to the current `AiWorkflowRun`.
- The UI shows a preview or name of the attached file in the chat bubble.
- Files are stored securely using the configured Active Storage backend.

## Test Cases
- **Integration**: Attach a small text file; submit; verify it appears in the chat history and is attached to the record in the DB.
