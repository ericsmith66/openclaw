# Remaining Capabilities & Components: Agent Hub Phase 2

This document tracks the features and UI elements from the original Agent Hub specification that are either partially implemented or not yet started. It also incorporates suggestions from the End-of-Epic feedback reports for Epics 1-5 and user feedback (EAS).

## 1. UI Elements (Gaps)

### Persona Tabs (Top Horizontal Bar)
- **Status**: ✅ Complete
- **Remaining**:
    - [x] **Individual Color-coding**: Implement specific colors for each persona (SAP: blue #3B82F6, Conductor: emerald #10B981, CWA: amber #F59E0B, AiFinancialAdvisor: violet #8B5CF6, Debug: red #EF4444). [Epic 6]
    - [x] **Gear Icon Dropdown**: Global model override menu (Grok, Grok with live search, Claude, Ollama). [Epic 6]
    - [ ] **Workflow Monitor Tab**: A read-only "inter-agent group chat" view. [Epic 8]

### Conversations Sidebar (Right, 25% Width)
- **Status**: ⚠️ Partial
- **Remaining**:
    - [ ] **Real Data Wiring**: Replace stub data with real `AiWorkflowRun` records. [Epic 7]
    - [ ] **Auto-titling**: Logic to generate titles (e.g., "PRD-0070 Draft") based on content. [Epic 7]
    - [ ] **Red Badge**: "Human attention required" (DaisyUI error variant) for pending approvals. [Epic 7]
    - [ ] **Delete Icon**: Trash icon per entry with a confirmation modal (Soft Delete). [Epic 7]
    - [ ] **Persistent Search**: Maintain search state when switching personas. [Epic 7]

### Main Chat Pane (Central, 75% Width)
- **Status**: ✅ Complete
- **Remaining**:
    - [x] **Gray "Thought" Bubbles**: Separate agent thoughts/tool usage from the main response tokens using gray bubbles. [Epic 6]
    - [x] **Confirmation Bubbles**: Inline buttons (Green/Yellow/Red) for /approve, /delete, or /handoff. [Epic 6]
    - [x] **Context Inspect (Eye Icon)**: Overlay to view RAG context and snapshots. [Epic 6]
    - [ ] **Structured Outputs**: Render markdown PRDs as visual "cards" in the stream. [Epic 6] - *Note: Partially achieved via better bubble styling, full cards deferred.*

### Input Bar (Bottom Fixed)
- **Status**: ⚠️ Partial
- **Remaining**:
    - [ ] **File Upload Button**: Active Storage integration to attach logs/schemas to runs. [Epic 8]
    - [ ] **@mentions**: Logic to trigger specific personas via "@SAP", etc. [Epic 8]
    - [ ] **Dynamic Autocomplete**: Fetch commands based on the active persona's capabilities. [Epic 8]

## 2. User Capabilities (Gaps)

### Workflow Management
- [ ] **Backlog Send**: `/backlog` command to persist artifacts to an external DB-backed backlog (JSONB). [Epic 7]
- [ ] **Human-in-the-Loop Approvals**: Clicking inline buttons to transition `AiWorkflowRun` status. [Epic 7]
- [x] **Context Inspection**: Viewing RAG snapshots via the eye icon or `/inspect`. [Epic 6]

### Advanced Interaction
- [x] **"#Hey Grok!"**: Explicit routing to Grok for research/escalations via SmartProxy. [Epic 6]
- [ ] **Inter-agent Monitoring**: Read-only streams in the "Workflow Monitor" tab focusing on agent "back and forth". [Epic 8]

## 3. Integrated Suggestions & EAS Feedback

### Architecture & Backend
- **Action Cable State**: Move active stream tracking from class variables to a shared store (Redis). (EAS: OK) [Epic 7]
- **Interrogation Payloads**: Add metrics to track latency. (EAS: Done) [Epic 6]
- **AiWorkflowRun Enhancements**: Add `name` and `description` fields. (EAS: Agree) [Epic 7]
- **Cleanup Worker**: Implement background job for orphaned/old runs. (EAS: Agree) [Epic 7]
- **Rate Limiting**: Measure latency before implementing. (EAS: Wait) [Hold]
- **Persistent Persona Selection**: Ensure persona state is robust across reloads. (EAS: Agree) [Epic 7]

### UI/UX
- **Dynamic Status**: Broadcast "Searching..." or "Processing..." status. (EAS: Done) [Epic 6]
- **Model Metadata**: Hold for RAG refactor. (EAS: Refactor first) [Hold]

## 4. Decisions & Traceability

- **Backlog**: DB-backed, persistent outside environment, JSONB-centric. [Epic 7]
- **Delete Policy**: Soft delete only. [Epic 7]
- **Workflow Monitor**: Focus on inter-agent communication visibility. [Epic 8]

## 5. Planned Epics

- **Epic 6: Advanced UI & Interaction (Agent-Hub-06)**
- **Epic 7: Persistence Wiring & Lifecycle (Agent-Hub-07)**
- **Epic 8: Group Flow & Collaboration (Agent-Hub-08)**
