# Review & Feedback: Epic 11 - Consolidated SDLC Spike & Core Bridge

This document provides a technical and structural review of the Epic 11 PRDs, identifying strengths, potential risks, and areas for refinement.

---

## 1. General Comments & Suggestions

### Strengths:
*   **Decoupling:** The shift from slash commands to a centralized `WorkflowBridge` (PRD-AH-011B/F) is a significant architectural improvement that reduces "spaghetti" logic in the channels.
*   **High Traceability:** The inclusion of `rag_request_id` and audit trails (PRD-AH-011G) ensures the system is verifiable and debuggable during development.
*   **Context Continuity:** Guaranteeing the injection of the "Active Artifact" (PRD-AH-011D) solves the "agent blindness" issue seen in earlier spikes.

### Suggestions:
*   **(EAS) Agree - Action Tag Registry:** We should maintain a central registry (perhaps in code or a shared doc) of all valid `<INTENT>` strings for the `[ACTION: <INTENT>: <ID>]` tag to prevent agents from making up their own (hallucinated) actions.
*   **(EAS) Agree - Developer Debug View:** Since we are logging `rag_request_id`, we should add a "Developer Mode" toggle in the Agent Hub UI that allows us to click a message and see exactly what context was sent to the LLM (the RAG payload).

---

## 2. PRD-Specific Feedback

### PRD-AH-011B: WorkflowBridge & Intent Detection
*   **Comment:** The `[ACTION: <INTENT>: <ID>]` format is robust. 
*   **Question:** How should the system handle cases where an agent includes *multiple* action tags in one response? Should it show multiple buttons, or only the first one?
*   **Suggestion:** (EAS) Agree - Ensure the Bridge can handle "Silent Actions" (e.g., auto-updating a task status) vs "Human-in-the-loop Actions" (requiring a button click).

### PRD-AH-011E: SDLC Visibility (Artifact Preview)
*   **Risk (Payload Size):** If a PRD or Technical Plan becomes very large (e.g., 50KB+), broadcasting the entire Markdown content over ActionCable for every small change might cause UI stutter or network overhead.
*   **Suggestion:** Implement (EAS) disagree we are still spiking YAGNI - **Debouncing** on the broadcast and consider sending only the "Diff" or requiring the frontend to fetch the latest version upon receiving a "refresh" signal, rather than pushing the full text every time.

### PRD-AH-011G: RAG Generation & Verification
*   **Objection/Gap:** You noted that **CWA (Coder)** currently falls back to the SAP prompt. This is a high-risk gap. SAP is an analyst; CWA needs technical execution instructions (e.g., "Use standard library over external gems").
*   **Suggestion:** We MUST create (EAS) Agree -`config/agent_prompts/cwa_system.md` as part of this epic to ensure CWA doesn't hallucinate analytical roles.
*   **Question on Anonymization:** (EAS) disagree YAGNI -For financial data, is "masking" sufficient, or should we be using "Synthetic Data Injection" to allow the agent to perform math on fake numbers that map back to real ones? Masking (`[REDACTED]`) might break logic that depends on comparing values.

---

## 3. Potential Risks & Objections

### 1. Tag Collision
If a user happens to type `[ACTION: MOVE_TO_ANALYSIS: 123]` in their message, will the Bridge mistake it for an agent intent? 
*   **Mitigation:** (EAS) disagree -The Bridge parser MUST only scan messages where `role: assistant`.

### 2. The "Stale Context" Problem
If a human clicks "Move to Analysis", the database updates, but the *LLM's memory* of the conversation still thinks it's in "Draft" mode until the next turn.
*   **Suggestion:** (EAS) agree When a state transition occurs via a button click, we should optionally inject a "System Message" into the conversation (e.g., `[SYSTEM: Phase changed to Analysis]`) so the agent is immediately aware of the world state change.

### 3. CWA Fallback
(EAS) agree I strongly object to proceeding with CWA implementation using the SAP prompt. The CWA needs a dedicated system prompt that emphasizes code integrity, file paths, and adherence to the Technical Plan.

---

## 4. Summary of Suggested Next Steps
1.  **Create `cwa_system.md`** immediately to close the persona gap.
2.  **Define the Action Registry** in `WorkflowBridge` to whitelist valid intents.
3.  **Implement ActionCable Debouncing** for the Artifact Preview to handle large documents.
4.  **Confirm the Redaction Strategy** (Redacted vs Synthetic) for financial calculations.
