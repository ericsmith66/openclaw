# PRD-AH-006D: Context Inspect (Eye Icon & Overlay)
## Overview
Provide visibility into the AI's current context (RAG snapshots, prompt prefixes) via an inspection eye icon and a modal overlay.

## Requirements
- **Functional**: Eye icon in chat pane header; Modal overlay showing formatted JSON of RAG context.
- **Non-Functional**: Read-only; Secure (mask sensitive keys).
- **Rails Guidance**: DaisyUI Modal; Stimulus controller to fetch context from `RagProvider`.
- **Traceability**: Original Spec (Main Chat Pane); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Eye icon visible next to message bubbles or in the pane header.
- Clicking the eye opens a modal with a "Context Snapshot" title.
- Overlay displays the `correlation_id` and associated RAG context.
- Users can close the modal easily.

## Test Cases
- **Integration**: Click the eye icon; verify modal appears with non-empty JSON content.
