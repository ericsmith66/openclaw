# Detailed System Overview — NextGen Wealth Advisor (Agent Hub 11)

This document is a **code-backed** overview of the NextGen Wealth Advisor Rails application, with emphasis on Agent Hub 11 (AI workflow) functionality.

Scope requested:

* Capabilities divided between **user interaction**, **backend functions**, and **integrations**
* **System architecture** (how parts fit together)
* **Database schema** (what each table is used for)
* **UI/UX structure**
* **Test coverage and tools**
* **How AI agents interact**
* **Every route** and what it is used for

Where possible, references point to concrete files.

---

## 1. Capabilities Overview

### 1.1 User Interaction (Frontend / UI)

#### A) Public + authentication
* **Welcome page**: public landing page at `root "welcome#index"`.
* **Authentication**: handled by Devise (`devise_for :users`).
* **Authenticated root**: signed-in users land on `DashboardController#index` (`root "dashboard#index"`).

#### B) Dashboard
* **Dashboard**: `GET /dashboard` → `DashboardController#index` (authenticated).
* Primary purpose: end-user “home” after login (exact widgets depend on the dashboard view/controller).

#### C) Agent Hub (owner-only)
* **Agent Hub main screen**: `GET /agent_hub` → `AgentHubsController#show`.
  * Enforces `authenticate_user!` + `require_owner`.
  * UI layout is composed from ViewComponents and Turbo Frames.
* **Personas switcher**: driven by `@personas` in `app/controllers/agent_hubs_controller.rb`.
  * Known persona IDs in code: `sap`, `conductor`, `cwa`, `ai_financial_advisor`, `workflow_monitor`, `debug`.
* **Conversations**: Agent Hub uses `SapRun` records as “conversations” (with `SapMessage` history).
  * Create conversation: `POST /agent_hubs/create_conversation`.
  * Switch conversation: `POST /agent_hubs/switch_conversation` (Turbo Stream replacement of the chat pane).
  * Archive conversation: `DELETE /agent_hubs/archive_conversation`.
* **Chat + input**: rendered by components in `app/views/agent_hubs/show.html.erb`.
  * Chat is suppressed for `workflow_monitor` (read-only).
* **Artifact preview panel**: right-side panel that shows the active SDLC artifact.
  * Subscribes to Turbo stream `active_artifacts_user_<user_id>` when there is no active artifact and/or for updates.
* **Model selection override**:
  * `POST /agent_hubs/update_model` stores `session[:global_model_override]`.
* **RAG context inspection**:
  * `GET /agent_hubs/inspect_context` returns JSON containing the computed RAG prefix via `SapAgent::RagProvider.build_prefix(...)`.

#### D) Mission Control (owner-only operational console)
* **Mission Control screen**: `GET /mission_control` → `MissionControlController#index`.
  * Shows Plaid items, accounts, holdings, recent transactions, recurring transactions, sync logs, webhook logs.
  * Supports filtering sync logs by `job_type`, `status`, date range; paginates results.
* **Operational actions** (enqueue jobs / maintenance):
  * `POST /mission_control/nuke` deletes all Plaid-synced domain data (but preserves cost history in `plaid_api_calls`).
  * `POST /mission_control/sync_holdings_now`, `.../sync_transactions_now`, `.../sync_liabilities_now` enqueue corresponding sync jobs for all items.
  * `POST /mission_control/refresh_everything_now` enqueues all syncs.
  * Additional item-level actions exist (relink, remove, fire webhook, update webhook URL) and costs reporting endpoints.

#### E) Admin namespace (owner/admin tools)
Routes are under `/admin/*`:

* `GET /admin/users`, `GET /admin/accounts`: CRUD-style admin screens.
* `GET /admin/ai_workflow`: AI workflow “orchestration UI”.
* `GET /admin/health`: internal health UI.
* `GET /admin/rag_inspector`: RAG inspection UI.
* `GET /admin/sap_collaborate`: direct SAP chat page.
* `POST /admin/sap_collaborate/ask`: sends a prompt, persists it, enqueues `SapAgentJob`.

#### F) Model inspection screens
`resources :holdings`, `resources :transactions`, `resources :accounts` provide standard CRUD-ish views used for inspection/debugging.

#### G) Real-time + fallback behaviors
* **ActionCable websocket** at `/cable` (mounted in `config/routes.rb`).
* Agent Hub uses broadcasts (ActionCable + Turbo Streams) to stream tokens/events to the UI.
* Agent Hub also includes a **polling stub** route `GET /agent_hub/messages/:agent_id` → `AgentHubsController#messages` that appends “polled” messages via Turbo Streams.

---

### 1.2 Backend Functions (Core Services / Jobs)

#### A) Plaid sync engine
Backend supports:
* Creating Plaid Link token (`POST /plaid/link_token`)
* Exchanging `public_token` into `access_token` and persisting connection as `PlaidItem` (`POST /plaid/exchange`)
* Running product sync jobs:
  * `SyncHoldingsJob`
  * `SyncTransactionsJob`
  * `SyncLiabilitiesJob`
* Reacting to Plaid webhooks (`POST /plaid/webhook`) by enqueuing the correct jobs based on webhook type/code.

Operational telemetry:
* `SyncLog` table for job-level outcomes.
* `WebhookLog` table for inbound webhook processing results.
* `PlaidApiCall` table for endpoint-level cost/usage tracking.

#### B) AI workflow orchestration
The SDLC workflow is orchestrated by `AiWorkflowService` (`app/services/ai_workflow_service.rb`). Confirmed behaviors include:

* **Run context persistence**: can reload prior context from `agent_logs/ai_workflow/<correlation_id>/run.json` (`AiWorkflowService.load_existing_context`).
* **Handoff payload schema**: explicit `handoff_to_cwa(...)` helper that packages `correlation_id`, `micro_tasks`, `workflow_state`, etc.
* **Hybrid handoff finalization**:
  * Syncs newly generated micro-tasks into the active `Artifact` via `AgentHub::WorkflowBridge.execute_transition(...)`.
  * Broadcasts plan summaries to ActionCable channels (including `agent_hub_channel_all_agents`).
  * When CWA completes, transitions to `workflow_state = awaiting_review` and `ball_with = Human`.

#### C) Conversation persistence and async agent responses
* Conversations are stored as `SapRun` + `SapMessage` records.
* Admin direct chat (`Admin::SapCollaborateController`) persists messages and enqueues `SapAgentJob`.

#### D) Context/RAG generation
* `AgentHubsController#inspect_context` calls `SapAgent::RagProvider.build_prefix(...)` to build a context prefix used in prompts.

---

### 1.3 Integrations

#### A) Plaid
Primary financial data provider.

Touchpoints:
* Link token creation and token exchange (`PlaidController`).
* OAuth callback flow (`PlaidOauthController`).
* Webhooks (`PlaidWebhookController`).

#### B) GitHub webhooks (knowledge base refresh trigger)
`PlaidWebhookController` also detects GitHub webhook requests (`X-GitHub-Event`).

* On `push` to `main` affecting `knowledge_base/`, it enqueues `SapRefreshJob`.

#### C) ActionCable (real-time streaming)
* Mounted at `/cable`.
* Used for:
  * Agent Hub streaming tokens/status.
  * “All agents” broadcast channel updates.
  * Artifact preview updates and other Turbo stream subscriptions.

#### D) Background jobs
The app enqueues jobs using ActiveJob (Rails 8 defaults; the project may use a queue adapter such as Solid Queue depending on environment configuration).

---

## 2. System Architecture

At a high level this is a Rails 8 MVC app with:

1. **Web/UI layer**
   * Rails controllers + views and ViewComponents.
   * Turbo (Turbo Frames / Turbo Streams) for partial updates.
   * ActionCable websockets for streaming.

2. **Domain layer**
   * Plaid domain models: `PlaidItem`, `Account`, `Transaction`, `Holding`, etc.
   * AI workflow models: `AiWorkflowRun`, `Artifact`, `SapRun`, `SapMessage`, `AgentLog`.

3. **Service + job layer**
   * Sync jobs triggered from UI actions and from webhooks.
   * AI workflow service orchestrating persona handoffs and state transitions.
   * RAG provider building contextual prompts.

4. **Integration boundary**
   * Plaid API
   * Webhooks (Plaid + GitHub)
   * Realtime via ActionCable

### Concrete example flows

#### Flow 1: User connects Plaid account
1. Browser calls `POST /plaid/link_token` to obtain a Plaid link token.
2. After Plaid Link returns `public_token`, browser calls `POST /plaid/exchange`.
3. Server creates `PlaidItem` and enqueues the sync jobs.
4. Jobs persist `Account` / `Transaction` / `Holding` data and produce `SyncLog` entries.

#### Flow 2: Plaid webhook triggers an update
1. Plaid sends webhook to `POST /plaid/webhook`.
2. Controller finds `PlaidItem` by `item_id`.
3. Depending on webhook type/code, enqueues sync jobs.
4. Creates a `WebhookLog` record and updates `PlaidItem.last_webhook_at`.

#### Flow 3: Admin SAP Collaborate prompt
1. Admin posts prompt to `POST /admin/sap_collaborate/ask`.
2. Controller persists messages (`SapMessage` user + placeholder assistant message).
3. Enqueues `SapAgentJob` to generate assistant response asynchronously.

#### Flow 4: Agent Hub artifact-centric workflow
1. Owner opens `GET /agent_hub`.
2. Server selects persona + conversation (`SapRun`) + active workflow run/artifact.
3. Central chat pane shows conversation history; artifact preview shows current artifact.
4. As agents run, `AiWorkflowService` broadcasts updates over ActionCable and transitions artifacts via `AgentHub::WorkflowBridge`.

---

## 3. Database Schema (What Each Table Is Used For)

This section is derived from `db/schema.rb`.

### 3.1 Financial / Plaid domain tables

* `plaid_items`
  * A single Plaid “Item” (connection) for a user.
  * Stores encrypted access token, item metadata, sync timestamps/cursor, status, last error.

* `accounts`
  * Accounts under a Plaid item (`plaid_item_id`).
  * Stores balances and (per PRD note in Mission Control) liability details in `liability_details` JSONB.

* `transactions`
  * Individual transactions (linked to `account_id`).
  * Enrichment appears via `enriched_transactions`.

* `enriched_transactions`
  * 1:1 enrichment record for a transaction (`transaction_id`, unique).
  * Stores merchant name, PFC category, logo URL, confidence, website.

* `holdings`
  * Investment holdings under an account (`account_id`).
  * Includes cost basis, price, market value, sector/industry, flags like `high_cost_flag`.
  * Has subtype-specific children:
    * `fixed_incomes` (bond-like metadata: maturity, yield, face value)
    * `option_contracts` (options metadata: strike, expiry, underlying)

* `recurring_transactions`
  * Plaid recurring streams tied to `plaid_item_id`.
  * Stores stream frequency, average/last amounts, status.

* `merchants`
  * Merchant directory keyed by `merchant_entity_id`.
  * Stores name, logo, website, long description.

* `personal_finance_categories`
  * Lookup table for Plaid personal finance categories: `primary` + `detailed`.

* `transaction_codes`
  * Lookup/normalization for transaction codes (used by `transactions`).

### 3.2 Sync observability / audit

* `sync_logs`
  * Records outcomes of sync jobs: job type, status, errors, timestamps; linked to `plaid_item_id`.

* `webhook_logs`
  * Records inbound webhook events per plaid item: event type, payload, success/failure, error message.

* `plaid_api_calls`
  * Records Plaid endpoint usage: endpoint, product, request_id, counts, and costs.
  * Explicitly preserved during “nuke” operations from Mission Control.

### 3.3 AI / Agent Hub workflow tables

* `ai_workflow_runs`
  * Tracks a workflow run; contains `status`, descriptive metadata, and is user-scoped.
  * Supports archival via `archived_at`.

* `artifacts`
  * Core SDLC artifact (PRD/plan/etc): stores `artifact_type`, `phase`, `owner_persona`, and JSON `payload`.
  * Uses optimistic locking via `lock_version`.

* `sap_runs`
  * Conversation / run record for SAP-style interactions.
  * Stores correlation identifiers, run status/phase, optional `artifact_id` linkage, and structured output JSON.

* `sap_messages`
  * Message log for a `sap_run_id`.
  * Stores role (`user`/`assistant`), content, model, and `rag_request_id` for traceability.

* `snapshots`
  * Per-user JSON snapshots (for context injection / historical comparison).

* `agent_logs`
  * Structured event log capturing agent actions by persona/task.
  * Unique index on `[task_id, persona, action]` suggests idempotent or “one event per action” semantics.

* `backlog_items`
  * User-scoped backlog items with priority + metadata.

### 3.4 Users + platform tables

* `users`
  * Devise-authenticated user records.

* ActiveStorage tables
  * `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records` support file uploads.

---

## 4. UI/UX Structure

### 4.1 Primary screens

* **Welcome** (`/` public)
* **Dashboard** (`/dashboard` and authenticated root)
* **Agent Hub** (`/agent_hub`, owner-only)
* **Mission Control** (`/mission_control`, owner-only)
* **Admin tools** (`/admin/*`)

### 4.2 Agent Hub layout (confirmed)
From `app/views/agent_hubs/show.html.erb`:

* Outer Turbo frame: `turbo_frame_tag "agent_hub_content"`.
* Layout: three-column within a bordered container:
  1. **Left**: `ConversationSidebarComponent` (lists conversations; includes persona context).
  2. **Center**: header + `ChatPaneComponent` + (optional) `InputBarComponent`.
  3. **Right**: `ArtifactPreviewComponent` (or placeholder “No active artifact”).
* Real-time: subscribes to `turbo_stream_from "active_artifacts_user_<id>"`.

### 4.3 Interaction patterns

* Persona switching changes `session[:active_persona_id]` and optionally emits a “typing start” broadcast.
* Conversation switching uses Turbo Streams to replace the chat pane.
* Messages can be streamed via ActionCable channels or appended via the polling stub endpoint.

---

## 5. Test Coverage and Tooling

### 5.1 Frameworks and harness
From `test/test_helper.rb`:

* **Minitest** (`rails/test_help`)
* **Parallel tests** enabled (`parallelize(workers: :number_of_processors)`)
* **Authentication helpers**: Warden + Devise integration helpers
* **HTTP stubbing/recording**:
  * `webmock/minitest`
  * `vcr` with cassette dir `test/vcr_cassettes`
  * Sensitive data filtering for `GROK_API_KEY` and `GROK_API_KEY_SAP`
* Helpers to stub `Rails.application.config.x.plaid_client` for deterministic Plaid tests.

### 5.2 What is covered (evidence in repo)

Examples of covered areas (non-exhaustive but concrete):

* AI workflow service behavior:
  * `test/services/ai_workflow_service_test.rb`
  * `test/services/ai_workflow_service_planner_test.rb`
  * `test/services/ai_workflow_service_broadcast_test.rb`
* Controller-level flows for:
  * Plaid endpoints (`test/controllers/plaid_controller_test.rb`, oauth/refresh/webhook tests)
  * Agent Hub (`test/controllers/agent_hubs_controller_test.rb`)
  * Mission Control (`test/controllers/mission_control_controller_test.rb`)
* VCR cassettes used for deterministic agent research flows (`test/vcr_cassettes/*`).

The repository also contains “smoke” and “integration” tests that may intentionally disable VCR/WebMock for live connectivity checks (e.g., smart proxy / LLM endpoints), based on search hits in `test/smoke/*` and `test/integration/*`.

---

## 6. AI Agents: How They Interact With the System

### 6.1 Key concepts

* **Personas**: the UI exposes multiple personas (SAP, Conductor, CWA, etc.).
* **Conversation persistence**: `SapRun` + `SapMessage` store conversational history.
* **Workflow runs + artifacts**:
  * `AiWorkflowRun` represents a run lifecycle.
  * `Artifact` represents the SDLC artifact being produced/refined.
* **Orchestration**:
  * `AiWorkflowService` controls handoffs, state transitions, and broadcasts.
  * `AgentHub::WorkflowBridge.execute_transition` is used to apply state changes and payload updates onto artifacts.

### 6.2 Handoff / lifecycle (confirmed mechanics)

* Context may be reloaded from filesystem logs (`agent_logs/ai_workflow/<correlation_id>/run.json`).
* When a planning step generates micro-tasks, those are synced into the active artifact’s payload and broadcast to Agent Hub.
* When CWA completes implementation work, the system:
  * sets `workflow_state` to `awaiting_review`
  * sets `ball_with` to `Human`
  * attaches implementation notes (optionally including git diff and test output evidence extracted from tool traces)

### 6.3 Context/RAG injection

* Agent Hub provides a JSON endpoint (`/agent_hubs/inspect_context`) that returns a `context_prefix` built by `SapAgent::RagProvider.build_prefix`.
* Messages (`sap_messages`) store `rag_request_id` for traceability.

---

## 7. Routes (Complete List + Purpose)

Derived from `config/routes.rb`.

### 7.1 Realtime
* `GET /cable` → ActionCable websocket endpoint.

### 7.2 Plaid + financial ingestion
* `POST /plaid_items/:id/refresh` → `PlaidRefreshesController#create`
  * Manual item refresh trigger (item-scoped).
* `GET /plaid_oauth/initiate` → `PlaidOauthController#initiate`
  * Create OAuth-oriented link token (authenticated).
* `GET /plaid_oauth/callback` → `PlaidOauthController#callback`
  * OAuth callback receiver; exchanges token and redirects.
* `POST /plaid/link_token` → `PlaidController#link_token`
  * Creates Plaid Link token.
* `POST /plaid/exchange` → `PlaidController#exchange`
  * Exchanges `public_token` for an access token and creates `PlaidItem`; enqueues initial sync jobs.
* `GET /plaid/sync_logs` → `PlaidController#sync_logs`
  * Displays recent sync logs.
* `POST /plaid/webhook` → `PlaidWebhookController#create`
  * Receives Plaid webhooks; enqueues sync jobs and records `WebhookLog`.
  * Also handles GitHub webhooks for KB refresh.

### 7.3 Auth + entrypoints
* `devise_for :users` → standard Devise routes.
* Authenticated root: `GET /` → `DashboardController#index` (when signed in).
* Public root: `GET /` → `WelcomeController#index` (when signed out).
* `GET /dashboard` → `DashboardController#index`.

### 7.4 Agent Hub (owner-only)
* `GET /agent_hub` → `AgentHubsController#show`
  * Main Agent Hub screen.
* `GET /agent_hub/messages/:agent_id` → `AgentHubsController#messages`
  * Turbo Stream polling stub that appends a “polled at …” message.
* `POST /agent_hub/uploads` → `AgentHub::UploadsController#create`
  * File uploads into Agent Hub context (ActiveStorage-backed).

Collection routes under `resources :agent_hubs, only: []`:
* `POST /agent_hubs/update_model` → `AgentHubsController#update_model`
  * Set/unset global model override in session.
* `GET /agent_hubs/inspect_context` → `AgentHubsController#inspect_context`
  * Returns JSON RAG context prefix for current persona.
* `DELETE /agent_hubs/archive_run` → `AgentHubsController#archive_run`
  * Archives an `AiWorkflowRun`.
* `POST /agent_hubs/create_conversation` → `AgentHubsController#create_conversation`
  * Creates a new persona-scoped `SapRun` conversation.
* `POST /agent_hubs/switch_conversation` → `AgentHubsController#switch_conversation`
  * Sets active conversation; replaces chat pane via Turbo Stream.
* `DELETE /agent_hubs/archive_conversation` → `AgentHubsController#archive_conversation`
  * Aborts/archives a conversation.

### 7.5 Mission Control (owner-only)
* `GET /mission_control` → `MissionControlController#index`
  * Operational console.
* `POST /mission_control/nuke` → `MissionControlController#nuke`
  * Deletes synced data (except `plaid_api_calls`).
* `POST /mission_control/sync_holdings_now` → `MissionControlController#sync_holdings_now`
* `POST /mission_control/sync_transactions_now` → `MissionControlController#sync_transactions_now`
* `POST /mission_control/sync_liabilities_now` → `MissionControlController#sync_liabilities_now`
* `POST /mission_control/refresh_everything_now` → `MissionControlController#refresh_everything_now`
* `POST /mission_control/relink/:id` → `MissionControlController#relink`
* `POST /mission_control/relink_success/:id` → `MissionControlController#relink_success`
* `POST /mission_control/remove_item/:id` → `MissionControlController#remove_item`
* `POST /mission_control/fire_webhook/:id` → `MissionControlController#fire_webhook`
* `POST /mission_control/update_webhook_url/:id` → `MissionControlController#update_webhook_url`
* `GET /mission_control/logs` → `MissionControlController#logs` (JSON)
* `GET /mission_control/costs` → `MissionControlController#costs`
* `GET /mission_control/costs/export.csv` → `MissionControlController#export_costs`

### 7.6 Agent monitoring
* `GET /agents/monitor` → `Agents::MonitorController#index`
  * Monitoring screen (purpose: operational visibility into agent activity).

### 7.7 Model inspection resources
* `resources :holdings`
* `resources :transactions`
* `resources :accounts`

### 7.8 Admin namespace
* `resources /admin/users`
* `resources /admin/accounts`
* `GET /admin/ai_workflow` → `Admin::AiWorkflowController#index`
* `GET /admin/health` → `Admin::HealthController#index`
* `GET /admin/rag_inspector` → `Admin::RagInspectorController#index`
* `GET /admin/sap_collaborate` → `Admin::SapCollaborateController#index`
* `POST /admin/sap_collaborate/ask` → `Admin::SapCollaborateController#ask`

---

## 8. Notes / Known Gaps

This overview is grounded in the inspected code paths and schema. If you want an even more “pixel-perfect” UX description (exact components, layout classes, and JS controllers across all screens), the next step would be to inventory:

* `app/views/layouts/*` (especially `agent_hub` and `admin` layouts)
* `app/components/*` (Persona tabs, conversation sidebar, chat pane, artifact preview, input bar)
* `app/javascript/controllers/*` (Stimulus controllers)
