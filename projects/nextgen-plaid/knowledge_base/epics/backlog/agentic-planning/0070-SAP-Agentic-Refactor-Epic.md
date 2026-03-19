### 0070-SAP-Agentic-Refactor-Epic.md

#### Overview
This Epic proposes a fundamental architectural shift for the SAP Agent: moving from a "Zero-Shot + Validation" (Reactive) model to an "Agentic Planning" (Proactive) model. Inspired by the Junie workflow, this refactor introduces a deliberate Thinking/Planning phase before artifact generation and modularizes the RAG system into pluggable strategies to ensure high-fidelity context injection tailored to specific tasks.

#### Goals
1.  **Introduce Thinking Phase**: Implement a mandatory `plan` step in the `SapAgent::Command` lifecycle.
2.  **Pluggable RAG Strategies**: Move beyond the single "Daily Snapshot" to a strategy-based RAG system (e.g., `SchemaRAG`, `HistoryRAG`, `StaticDocRAG`) that can be combined dynamically.
3.  **Proactive Verification**: Shift validation from a post-generation "Retry" loop to a pre-generation "Verification" check.
4.  **Enhanced Transparency**: Log the internal "plan" and "reasoning" steps to `agent_logs/sap.log` for better observability.

#### Proposed Architecture
- **`SapAgent::Command` Lifecycle**:
    1.  **`research`**: Gather raw data (pluggable RAG).
    2.  **`plan`**: AI generates a "mini-plan" for the artifact.
    3.  **`verify`**: Check plan against existing constraints (schema, PRDs).
    4.  **`execute`**: Generate final artifact based on the verified plan.
    5.  **`validate`**: Final structural check.

- **Pluggable RAG (`SapAgent::RagStrategy`)**:
    - `SnapshotStrategy`: Current daily JSON blob.
    - `LiveSchemaStrategy`: Real-time minified `schema.rb`.
    - `GitHistoryStrategy`: Dynamic regex search for related PRDs.
    - `BacklogStrategy`: Targeted JSON parsing of priorities.

#### Acceptance Criteria
1.  `SapAgent::Command` executes a `plan` step before `call_proxy`.
2.  `RagProvider` supports selecting multiple strategies via a registry.
3.  The agent can "self-correct" its plan if the `verify` step finds a conflict (e.g., trying to use a non-existent database column).
4.  PRD generation success rate (passing validation on first `execute`) increases by >30%.
5.  All planning and reasoning steps are captured in structured logs.

#### Pros, Cons, and Challenges

**Pros:**
- **Higher Accuracy**: Planning reduces hallucinations by forcing the model to commit to a logic path before writing prose.
- **Better Context**: Pluggable RAG allows the agent to ignore irrelevant data, saving tokens and improving focus.
- **Maintainability**: New artifact types (e.g., Bug Reports, Test Plans) can be added simply by defining a new Strategy and Planning prompt.
- **Consistency**: Proactive verification ensures the agent doesn't propose changes that contradict the Master Control Plan (MCP).

**Cons:**
- **Increased Latency**: Adding a Planning phase typically adds one extra LLM call, increasing total generation time by 3-7 seconds.
- **Higher Token Usage**: Multi-step workflows consume more tokens than single-pass prompts.
- **Complexity**: The codebase moves from a simple procedural loop to a state-aware pipeline.

**Challenges:**
- **State Management**: Ensuring the "Plan" is successfully passed from the thinking phase to the execution phase without loss of detail.
- **Small Model Compatibility**: Local models (like Llama 3 8B) may struggle with the "thinking" step compared to Grok or Llama 70B.
- **RAG Orchestration**: Determining which RAG strategies are "required" vs "optional" for a given query to avoid context bloating.
