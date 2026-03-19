# Application Architecture & Capability Overview

This document provides a comprehensive technical and functional overview of the NextGen Wealth Advisor platform, covering user interactions, backend systems, architecture, and AI agent integration.
Ok that was veryly litteral. In detail lets describe all the capabilitys of the application divide them between user interaction , backend functions, integrations. describe the system architecure , describe the schema and what each table is used for. descipe the UI/UX structure . Describe the test coverage and tools that are used and describe the architecure. finaly explain how the different ai agents interact with the system .
---

## 1. Capabilities Overview

### User Interaction (Frontend)
*   **Mission Control (Admin Dashboard)**: Located at `/mission_control`. Provides real-time visibility into Plaid syncs (Holdings, Transactions, Liabilities), manual "Refresh Everything" triggers, Plaid Item management (relink/remove), and API cost tracking.
*   **sap_collaborate (Direct Agent Chat)**: Located at `/admin/sap_collaborate`. An interactive interface for direct communication with the SAP (Strategic Analysis Persona). It maintains a conversation history via `sap_runs` and `sap_messages`.
*   **Agent Hub**: A centralized interface for managing the AI-driven SDLC. It allows users to view artifacts, monitor agent progress, and approve transitions between phases (e.g., Analysis to Planning).
*   **UI/UX Components**: Built with Rails 8, Tailwind CSS, and DaisyUI. Uses `ViewComponent` for modularity. Features a left-right-top format with a scrollable center and a chat box at the bottom.

### Backend Functions
*   **Plaid Sync Engine**: Handles the synchronization of financial data (Accounts, Transactions, Holdings, Liabilities) using the `plaid-ruby` gem.
*   **RAG Provider (`SapAgent::RagProvider`)**: Dynamically constructs context prefixes for AI agents by injecting vision statements, project structure, database schemas, and user data snapshots (sanitized).
*   **AI Workflow Service (`AiWorkflowService`)**: Orchestrates the multi-turn interaction between personas (SAP, Coordinator, Planner, CWA). It manages state transitions, ball-with tracking, and handoffs.
*   **Snapshotting**: The `FinancialSnapshotJob` (via Solid Queue) generates daily JSON snapshots of user financial states for RAG injection.

### Integrations
*   **Plaid**: Primary data source for banking and investment data.
*   **Ollama / SmartProxy**: Local AI inference layer. The `SmartProxyClient` routes requests to local models (Llama 3.1 70B/405B) ensuring zero data leakage.
*   **Chatwoot**: Integrated for user-facing conversational support, with webhooks routing complex queries back to internal agents.
*   **Solid Queue**: The Rails 8 default for background job processing and recurring tasks.

---

## 2. System Architecture

The application follows a **Rails 8 MVC architecture** with a specialized **Agent-Based Workflow Layer**.

*   **Layer 1: Rails Core**: Standard MVC for data persistence, authentication (Devise), and routing.
*   **Layer 2: Service Layer**: Contains business logic for Plaid syncs and AI orchestration (`AiWorkflowService`, `SapAgentJob`).
*   **Layer 3: Agent Framework**: Leverages a registry-based pattern (`Agents::Registry`) to initialize personas with specific instructions and toolsets.
*   **Layer 4: Local AI Proxy**: All AI communication goes through `SmartProxy`, maintaining the "local-first, private" technical philosophy.

---

## 3. Database Schema & Table Usage

| Table | Purpose |
| :--- | :--- |
| `users` | Manages authentication and user roles (Parent/Heir). |
| `plaid_items` | Stores encrypted access tokens and sync status for bank connections. |
| `accounts` | Represents individual bank/investment accounts linked via Plaid. |
| `transactions` | Stores financial transactions with enrichment data. |
| `holdings` | Tracks investment securities and quantities. |
| `artifacts` | The core unit of work in the SDLC (e.g., PRDs, Plans). Stores phase and owner. |
| `ai_workflow_runs` | Tracks the lifecycle of an autonomous agent run. |
| `sap_runs` / `sap_messages` | Persists conversation history for agent interactions. |
| `snapshots` | Stores the daily JSON snapshots used for AI context. |

---

## 4. AI Agent Interactions

The system uses a **Persona-Driven SDLC** where agents hand off the "ball" to each other based on the phase of the project.

### The Personas
1.  **SAP (Strategic Analysis Persona)**: (INTJ) Senior PM/Architect. Transforms intent into PRDs.
2.  **Coordinator**: (ENFJ) Project Manager. Oversees transitions and assigns work.
3.  **Planner**: (ENTJ) Technical Architect. Breaks PRDs into atomic micro-tasks.
4.  **CWA (Coder With Attitude)**: (INTP) Developer. Implements code, runs tests, and creates local commits.

### The Handoff Mechanism
*   **Ball-with Tracking**: Every workflow response identifies which persona currently "owns" the task.
*   **Action Tags**: Agents use specific tags like `[ACTION: MOVE_TO_ANALYSIS: ID]` to trigger state transitions in the `artifacts` table.
*   **Context Injection**: The `RagProvider` ensures that when the "ball" is handed to a new agent, they receive the full history (PRD, Plan, and previous conversation) in their prompt.

---

## 5. Testing & Tools

*   **Test Framework**: Minitest (Rails 8 default).
*   **Mocking**: `WebMock` and `VCR` are used to stub external API calls (Plaid, AI Proxy) for deterministic testing.
*   **Code Quality**: `Rubocop` is enforced via a `CodeAnalysisTool` that agents can use to verify their own work.
*   **Safe Execution**: `safe_exec` allowlist and dry-runs ensure that CWA cannot execute destructive shell commands.
*   **Observability**: Agent runs are logged to `agent_logs/ai_workflow/` in NDJSON format for real-time monitoring and debugging.
