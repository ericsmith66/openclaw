### 0080-SAP-Agentic-Refactor-Epic-v2.md

#### Overview
This Epic refines the architectural shift of the SAP Agent from a "Zero-Shot" model to an "Agentic Planning" model. The core requirement is to ensure the Agent performs deep business and technical analysis before generation. It must explicitly identify whether a task is "Greenfield" or a "Refactor" and validate its understanding of UX/UI constraints, user interactions, and existing codebase dependencies.

#### Goals
1.  **Fundamental Business Alignment**: Force the Agent to state its understanding of the business requirement before proposing code/PRDs.
2.  **Interaction & UX/UI Guardrails**: Integrate explicit checks for user flow and design consistency.
3.  **Proactive Scope Identification**: Detect if the request involves a "Refactor" (requiring legacy awareness) or "Greenfield" (requiring architectural consistency).
4.  **Strategic RAG Injection**: Use pluggable RAG to fetch UI/UX templates, existing business rules, and relevant code sections for refactoring analysis.

#### Proposed Agentic Lifecycle (The "Thinking" Loop)
1.  **Research & Discovery**:
    - Identify project type: **Greenfield** vs. **Refactor**.
    - Pull relevant RAG strategies: `BusinessRules`, `UXTemplates`, `LegacyCodeContext`, `MasterVision`.
2.  **Analysis & Intent Confirmation**:
    - Generate an **"Intent Summary"**:
        - *Business Requirement*: What problem are we solving?
        - *User Interaction*: How does the user experience this?
        - *Change Impact*: Which parts of the app are being modified (if refactor)?
3.  **Strategic Planning**:
    - AI generates a detailed execution plan including UI/UX considerations and data model changes.
4.  **Architectural Alignment (CWA Handshake)**:
    - **SAP Feedback Phase**: The SAP Agent reviews the CWA's execution plan.
    - **Validation**: Does the plan meet the original PRD's business intent? Does it violate any UI/UX guardrails?
    - **Alternatives**: SAP proposes alternative technical paths if the CWA's plan is suboptimal.
5.  **Proactive Verification**:
    - Cross-reference the verified plan against the Master Control Plan (MCP) and current `schema.rb`.
6.  **Artifact Execution**:
    - Final PRD/Artifact generation or Code Implementation based on the SAP-approved business and technical plan.

#### Pluggable RAG Strategies (Updated)
- `VisionSSOT`: Deep dive into `static_docs/` for long-term business goals.
- `UXDesignStrategy`: Pulls existing UI components and CSS/DaisyUI guidelines.
- `InteractionMap`: Pulls current routes and controller logic for refactor impact analysis.
- `TechnicalDebtScan`: Identifies parts of the application marked for change or deprecation.

#### Acceptance Criteria
1.  `SapAgent::Command` must generate an **Intent & Impact Report** before the final artifact.
2.  The "Intent" must explicitly classify the task as **Greenfield** or **Refactor**.
3.  The agent must identify at least 3 "UI/UX Considerations" for any frontend-facing PRD.
4.  If a **Refactor** is identified, the agent must list the specific existing files/classes that will be modified.
5.  Validation fails if the "Business Requirement" summary contradicts the Master Control Plan.

#### Pros, Cons, and Challenges

**Pros:**
- **Business Accuracy**: Ensures the AI doesn't just write code, but solves the right business problem.
- **UI/UX Consistency**: Prevents "Frankenstein UI" by forcing the agent to consider existing design patterns.
- **Refactor Safety**: Reduces risk during refactors by identifying dependencies upfront.

**Cons:**
- **Step Count**: Increases to 5+ LLM interactions, significantly increasing latency.
- **Complexity**: Requires a sophisticated "Analysis Prompt" that can handle diverse business contexts.

**Challenges:**
- **Ambiguity Management**: How the agent should handle vague user requests (it must ask for clarification instead of guessing).
- **Context Window Management**: Combining Business Rules, UI Guidelines, and Legacy Code might exceed the 4k-8k token "Goldilocks" zone for local models.
