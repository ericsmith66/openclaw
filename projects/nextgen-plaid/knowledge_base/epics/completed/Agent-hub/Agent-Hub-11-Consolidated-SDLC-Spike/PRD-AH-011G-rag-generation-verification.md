# PRD-AH-011G: RAG Generation & Verification

Part of Epic 11: Consolidated SDLC Spike & Core Bridge.

---

## Problem

While we have basic context injection, we lack a formal standard for how RAG content is generated for specific personas and how to verify that the injected context is both accurate and sufficient for the agent to perform its role without hallucinations.

## User story

As a system architect, I want to define explicit RAG requirements for each persona and have a way to verify the quality of the generated context, so that I can ensure agents always have the right information at the right time.

---

## A) Persona Articulation & Prompt Mapping

Each agent persona is defined by a specific role and a corresponding system prompt that guides its behavior and context utilization.

### 1. SAP (Strategic Analysis Persona)
- **Role:** The entry point for new ideas. Acts as a Product Manager and Analyst.
- **Responsibilities:**
    - Capture initial human intent.
    - Draft the first version of a PRD.
    - Manage the high-level backlog.
- **System Prompt:** `config/agent_prompts/sap_system.md`
- **Prompt Logic:** Focuses on `[CONTEXT_BACKLOG]` and `[PROJECT_CONTEXT]` to provide strategic insights and backlog management tags (`APPROVE_ARTIFACT`).
- **Content:**
```markdown
System Prompt
[ACTIVE_ARTIFACT]
[CONTEXT_BACKLOG]
[VISION_SSOT]
--- USER DATA SNAPSHOT ---
[PROJECT_CONTEXT]
```

### 2. Coordinator
- **Role:** The Project Manager of the implementation phase.
- **Responsibilities:**
    - Oversee the transition from "Analysis" to "Planning".
    - Manage assigned artifacts during implementation.
    - Ensure smooth handoffs between the human and execution agents.
- **System Prompt:** `config/agent_prompts/coordinator_system.md`
- **Prompt Logic:** Uses `[CONTEXT_BACKLOG]` to track assigned items and provides implementation-specific action tags.
- **Content:**
```markdown
System Prompt
[ACTIVE_ARTIFACT]
[CONTEXT_BACKLOG]
[VISION_SSOT]
--- USER DATA SNAPSHOT ---
[PROJECT_CONTEXT]
---
## Coordinator Persona Instructions
You are the Coordinator Persona. Your role is to oversee the implementation phase, manage assigned artifacts, and ensure handoffs between agents (like CWA and Planner) are smooth.
### Artifact Management
- When asked "show my assigned items" or similar, summarize the items provided in the `[CONTEXT_BACKLOG]` section (which contains your assigned artifacts).
- To advance an artifact, identify its ID from the context and you MUST include the appropriate tag (with brackets):
  - For PRD approval: `[ACTION: APPROVE_PRD: ID]`
  - for QA approval: `[ACTION: APPROVE_QA: ID]`
  - for general approval: `[ACTION: APPROVE_ARTIFACT: ID]`
- Replace `ID` with the actual numerical ID of the artifact.
- Including these tags correctly will prompt the user with a confirmation button to move the artifact to the next phase.
- Always provide a brief explanation of the next steps for this artifact.
```

### 3. Conductor
- **Role:** The Workflow Orchestrator.
- **Responsibilities:**
    - Detect state transitions in the SDLC.
    - Provide "meta-commentary" on the progress of a workflow run.
    - Coordinate between CWA and the human for approvals.
- **System Prompt:** `config/agent_prompts/coordinator_system.md` (Shared with Coordinator)
- **Prompt Logic:** Inherits Coordinator logic but focuses on workflow state transitions and dependency management.

### 4. CWA (Coder With Attitude / Agent)
- **Role:** The Technical Executor.
- **Responsibilities:**
    - Implement code based on a Technical Plan.
    - Adhere strictly to PRD requirements.
    - Provide technical feedback on feasibility.
- **System Prompt:** `config/agent_prompts/cwa_system.md`
- **Prompt Logic:** Requires high-density technical context including File Maps and specific Technical Plan sections. Emphasizes code integrity, file paths, and adherence to the Technical Plan.
- **Content:**
```markdown
System Prompt
[ACTIVE_ARTIFACT]
[CONTEXT_BACKLOG]
[VISION_SSOT]
--- USER DATA SNAPSHOT ---
[PROJECT_CONTEXT]
---
## CWA Persona Instructions
You are the CWA Persona (Coder With Attitude). Your role is to execute the technical implementation based on the provided Technical Plan and PRD.
### Execution Guidelines
- **Technical Adherence:** You MUST strictly follow the requirements in the PRD and the implementation steps in the Technical Plan.
- **Code Integrity:** Emphasize clean, maintainable code. Prefer standard library solutions over adding new dependencies unless explicitly required.
- **File Management:** Always reference specific file paths when discussing code changes or structure.
- **Progress Reporting:** When you complete a task or a build, provide a concise summary of what was changed and where it can be verified.
### Context Utilization
- Use the `[ACTIVE_ARTIFACT]` section to understand the current PRD/Plan.
- If the context is truncated, acknowledge it and ask for specific details if needed to maintain technical accuracy.
- Report any technical blockers or deviations from the plan to the human immediately.
```

### 5. AiFinancialAdvisor
- **Role:** Financial Specialist.
- **Responsibilities:**
    - Analyze financial data from snapshots.
    - Provide investment or savings advice.
- **System Prompt:** `config/agent_prompts/sap_system.md` (Default)
- **Prompt Logic:** Uses SAP base prompt with a persona identity injected via the chat channel: "You are AIFINANCIALADVISOR."

### 6. Workflow Monitor
- **Role:** Read-only Observer.
- **Responsibilities:**
    - Provide visibility into the current SDLC state without interfering.
- **System Prompt:** `config/agent_prompts/sap_system.md` (Default)
- **Prompt Logic:** Persona identity: "You are WORKFLOW_MONITOR."

### 7. Debug
- **Role:** System Troubleshooter.
- **Responsibilities:**
    - Assist developers in inspecting RAG payloads and system state.
- **System Prompt:** `config/agent_prompts/sap_system.md` (Default)
- **Prompt Logic:** Persona identity: "You are DEBUG."

---

## B) Autonomous Command Prompts (Inline)

In addition to system prompts, specific autonomous commands use inline prompts for targeted tasks:

### 1. QA Command (`SapAgent::QACommand`)
```markdown
You are the SAP Agent (Senior Architect and Product Manager).
Answer the following question from the development team:
#{question}
Context:
#{context}
```

### 2. Debug Command (`SapAgent::DebugCommand`)
```markdown
You are the SAP Agent (Senior Architect and Product Manager).
Analyze the following logs and provide a fix proposal for the issue.
Issue: #{issue}
Logs:
#{logs}
```

---

## C) Persona-Specific RAG Expectations

Each agent persona requires a tailored set of RAG data to function effectively within the SDLC Bridge.

| Persona | Primary RAG Data | Secondary RAG Data | Expectation |
| :--- | :--- | :--- | :--- |
| **Coordinator** | Active PRD, Vision (MCP.md) | User History, Static Docs | Maintain project alignment and detect high-level intent. |
| **Conductor** | Workflow State, Active Artifacts | Agent Logs, Dependencies | Coordinate between CWA and human; manage state transitions. |
| **CWA (Coder)** | Technical Plan, File Map | Code Snippets, PRD requirements | Execute implementation with 100% adherence to the Technical Plan. |
| **SAP (Analyst)** | Financial Snapshot, Backlog | Market Research, Static Docs | Analyze data and generate initial PRD drafts/Discovery documents. |

---

## D) RAG Generation Logic

The `SapAgent::RagProvider` must follow these generation rules:

1.  **Priority 1: Active Artifact.** The currently active PRD or Technical Plan MUST be injected at the top of the context.
2.  **Priority 2: Persona System Prompt.** The specific system prompt for the agent (e.g., `coordinator_system.md`) must be loaded and populated.
3.  **Priority 3: Relevant Static Docs.** Use the `context_map.md` to pull only relevant documentation based on the current `query_type`.
4.  **Priority 4: Project Snapshot.** Inject anonymized user/project data (financials, etc.) for SAP-specific turns.

---

## E) RAG Verification & Traceability

To ensure RAG quality and allow for SDLC replaying during development, the following mechanisms are implemented:

1.  **Context Logging:** Every RAG payload generated must be logged in `agent_logs/sap.log` with a unique `request_id`, `persona_id`, and `length` metadata.
2.  **Developer Debug View:** The Agent Hub UI MUST include a "Developer Mode" toggle that allows users to click a message and view the exact RAG payload (context) sent to the LLM for that specific turn, using the `rag_request_id`.
3.  **Artifact Traceability (Development):** When an artifact is created or its phase is modified, the `audit_trail` in the artifact's payload MUST include a reference (e.g., `rag_request_id` or a hash of the context) to the RAG state that triggered or accompanied the change.
4.  **Traceability:** The LLM response should occasionally (or via debug flag) cite which part of the RAG context it used (e.g., "According to the PRD...").
5.  **Truncation Warning:** If the context exceeds `MAX_CONTEXT_CHARS`, a clear `[TRUNCATED]` tag must be appended, and an alert should be logged to prevent "silent context loss".
6.  **Verification Test Suite:** Integration tests (see `Agent-hub-11-test-plan.md`) must verify that the `active_artifact` ID is present in the outgoing payload and linked in the audit trail.

---

## F) Functional Requirements

-   **Persona-Aware Routing:** `RagProvider` must correctly identify the persona from the request and fetch the appropriate data.
-   **Artifact Integrity:** Ensure the `active_artifact` injected is the *latest* version from the database.
-   **Anonymization:** Maintain strict redaction (masking) of sensitive financial data (balances, account numbers) within the RAG payload. Synthetic data is not required (YAGNI).
-   **Development Replay Support:** The system must support re-injecting a logged RAG payload into a test environment to verify agent behavior against specific historical contexts.

---

## G) Acceptance Criteria

-   **AC1:** The Coordinator agent receives the PRD content in its context window during the Analysis phase.
-   **AC2:** The CWA agent receives both the PRD and Technical Plan during the Implementation phase.
-   **AC3:** All RAG generation events are logged with sufficient detail for debugging context issues.
-   **AC4:** Verification tests in `sdlc_bridge_flow_test.rb` confirm that the RAG payload contains the expected Artifact content for at least two different personas.
