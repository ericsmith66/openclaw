The RAG (Retrieval-Augmented Generation) process in our project is implemented as a **Simple Concat RAG** framework. This system ensures the AI (SAP Agent) has up-to-date project context, history, and vision while maintaining data privacy and performance.

### 1. The Generation Phase (Knowledge Collection)
The foundation of our RAG is the `FinancialSnapshotJob` (located in `app/jobs/financial_snapshot_job.rb`), which runs daily to capture the current state of the project.

*   **History Extraction**: It scans git logs for "Merged PRD" messages to build a timeline of completed features.
*   **Vision Sync**: It pulls key excerpts from the Master Control Plan (`knowledge_base/static_docs/MCP.md`).
*   **Backlog Integration**: It parses the current project priorities from `knowledge_base/backlog.json`.
*   **Code State Minification**: It generates a compressed version of `db/schema.rb` (listing tables and columns without noise) and summarizes the `Gemfile`.

These snapshots are stored as dated JSON files in `knowledge_base/snapshots/` (retained for 7 days) and synchronized to the `snapshots` database table for fast access.

### 2. The Retrieval & Processing Phase
When you interact with the SAP Agent, the `SapAgent::RagProvider` (in `app/services/sap_agent/rag_provider.rb`) handles the context retrieval:

*   **Smart Selection**: It uses a `context_map.md` to decide which static documents are relevant based on your query type (e.g., a "generate" query might pull different docs than a "research" query).
*   **PII Anonymization**: Before sending data to the LLM, the provider automatically redacts sensitive information like account numbers, balances, and official names.
*   **Context Truncation**: To prevent token overflow, it caps the total context at **4,000 characters**, prioritizing the most recent and relevant data.

### 3. The Injection Phase (Prompt Building)
The final step occurs in `SapAgent::Command` (and its subclasses like `ArtifactCommand`):

1.  **Prefix Building**: The `RagProvider` generates a formatted string containing the `[CONTEXT START]` and `[CONTEXT END]` markers.
2.  **Prompt Concatenation**: This prefix is prepended to the system prompt or your specific query.
3.  **LLM Routing**: The enriched prompt is sent to the appropriate model (Grok for complex reasoning or Ollama for local tasks) via the `AiFinancialAdvisor`.

### Monitoring & Maintenance
*   **Logs**: All RAG operations (summaries, truncations, and errors) are logged in `agent_logs/sap.log`.
*   **Rake Tasks**: You can manually trigger snapshots or inspect the generated context using:
    *   `rake sap:rag:snapshot` (Generates a new snapshot)
    *   `rake sap:rag:inspect` (Shows exactly what context would be sent to the LLM)
*   **Automation**: Scheduled via `config/recurring.yml` to run every day at 3 AM.