# PRD-AH-011D: Robust Artifact Context & RAG Injection

Part of Epic 11: Consolidated SDLC Spike & Core Bridge.

---

## Problem

Agents (Coordinator, CWA) often lack the immediate context of the current PRD or Technical Plan, leading to hallucination or redundant questions.

## User story

As a developer, I want agents to always have the latest Artifact content in their context window so they can provide accurate and context-aware assistance.

---

## A) What SAP/CWA produce (workflow output)

Agents leverage the injected context to:
- Summarize existing PRDs.
- Reference specific tasks in a Technical Plan.
- Ensure new code aligns with the approved PRD.
- Provide "Collaborative Feedback" by accurately reporting completed tasks back to the human.

---

## B) What we build (platform/engineering work)

- **`SapAgent::RagProvider` Enhancement:** Inject the `active_artifact` payload as the **Primary System Context**.
- **Context Routing:**
  - Coordinator turns MUST include the `PRD` content.
  - CWA turns MUST include the `PRD` + `Technical Plan`.
- **Baseline Context:** Consistently apply `MCP.md` and `eric_grok_static_rag.md`.

---

## C) UI elements introduced/changed

- No direct UI changes (backend context injection).

---

## Functional requirements

- `RagProvider` fetches the `Artifact` associated with the current `Conversation`.
- Context is formatted as a system prompt addition.
- Ensure token limits are managed while prioritizing the `active_artifact`.

---

## Acceptance criteria

- AC1: Coordinator can accurately summarize a PRD that was generated in a previous turn or session.
- AC2: CWA can reference specific requirements from the PRD when writing code.
- AC3: The system context includes the `Artifact` payload for every agent turn if an artifact is linked.
- AC4: CWA uses the PRD/Technical Plan context to notify the human specifically about which requirements have been satisfied.

---

## Human Testing Steps & Expected Results

1.  **Step:** Start a new conversation, link an existing PRD (Artifact), and ask: "What are the main requirements of this project?"
    *   **Expected Result:** The agent (Coordinator) provides an accurate summary of the linked PRD without the user having to paste the text. This proves the `active_artifact` is in the context.
2.  **Step:** During the Implementation phase, ask the CWA: "Does this code meet the security requirements in our PRD?"
    *   **Expected Result:** The CWA references specific security sections from the PRD to justify its answer.
3.  **Step:** Check the `agent_logs` (or debug console) for the system prompt being sent to the LLM.
    *   **Expected Result:** The prompt should contain a block labeled something like `[ACTIVE_ARTIFACT]` containing the full text of the PRD/Technical Plan.
