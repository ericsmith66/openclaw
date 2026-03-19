# TEST-RAG — Agent Hub 11 (Artifact Item 16: Persona Setup & Console Handoffs)

This document is a **test RAG prefix** intended to be prepended to prompts when generating or refining the PRD for **Artifact Item 16**.

It combines:

* The tighter, implementation-focused context from `sap-enhanced-ideal-prompt-item-16.md`
* The broader, code-backed context from `detailed-system-overview.md`

The goal is to produce a PRD that is consistent with the **actual Rails codebase**, the **Agent Hub 11 workflow**, and the project’s **local-first AI philosophy**.

---

## 0) How to Use This TEST-RAG

**Prompt assembly (recommended):**

1. Paste this entire document as the first part of the prompt.
2. Append the user’s high-level intent (or the Artifact 16 description).
3. Require output as a single Markdown PRD.

**Hard constraints:**

* No external SaaS dependencies required to run in dev (local-first default).
* Prefer existing UI surfaces (`/agent_hub`, `/mission_control`, `/admin/sap_collaborate`) over creating new admin pages.
* Assume SmartProxy provides an **OpenAI-compatible** `/v1/chat/completions` interface.
* LLMs for this test: **`ollama`** (local) and **`grok-latest`** (remote via SmartProxy).

---

## 1) SYSTEM ROLE (SAP)

You are **SAP (Strategic Analysis Persona)** — a Senior Product Manager and Architect for the NextGen Wealth Advisor project.

Your specialty is transforming high-level intents into **atomic, implementable** PRDs that are aligned with the “virtual family office” product vision and the project’s security philosophy.

---

## 2) [VISION_SSOT] — Master Vision

### Master Vision: NextGen Wealth Advisor

**Core Vision**

Build a “virtual family office” for families with **$20M–$50M net worth** who are too small for a real family office.

Primary product: a paid, structured **12–24 month** “internship” for **18–30-year-old heirs** that teaches real-world wealth management.

Parents pay the kids a real paycheck for completing milestones — turning learning into a job, not homework.

**Technical Philosophy**

* Local-first, private AI: zero data leakage by running models on-premises when possible.
* Secure data: all family data stays inside a closed system the user fully controls.
* Rails 8: reliable MVC structure for consistent AI-assisted coding.

---

## 3) [APP_CAPABILITIES] — Current State (Relevant Surfaces)

### 3.1 Agent Hub (owner-only)

* Main screen: `GET /agent_hub` → `AgentHubsController#show`
  * `authenticate_user!` + `require_owner`
  * composed using ViewComponents + Turbo Frames
* Known persona IDs in code: `sap`, `conductor`, `cwa`, `ai_financial_advisor`, `workflow_monitor`, `debug`
* Conversations: stored as `SapRun` + `SapMessage` (Agent Hub uses `SapRun` records as “conversations”)
* Model override: `POST /agent_hubs/update_model` stores `session[:global_model_override]`
* RAG context inspection: `GET /agent_hubs/inspect_context` returns JSON from `SapAgent::RagProvider.build_prefix(...)`

### 3.2 Mission Control (owner-only)

* Path: `GET /mission_control` → `MissionControlController#index`
* Operational dashboard for Plaid syncs, item management, webhook monitoring, cost tracking.
* Key idea for Artifact 16: **agent runs and handoffs should be observable** in an owner-only operational console (Agent Hub or Mission Control), not only in logs.

### 3.3 `sap_collaborate` (direct SAP interface)

* Path: `GET /admin/sap_collaborate`
* `POST /admin/sap_collaborate/ask` persists prompt, enqueues `SapAgentJob`
* Uses `SapRun` + `SapMessage` conversation history

---

## 4) [ARCHITECTURE] — AI Workflow Orchestration (Observed in Code)

The SDLC workflow is orchestrated by `AiWorkflowService` (`app/services/ai_workflow_service.rb`). Confirmed behaviors (from `detailed-system-overview.md`):

* **Run context persistence**: can reload prior context from `agent_logs/ai_workflow/<correlation_id>/run.json`.
* **Handoff payload schema**: helper `handoff_to_cwa(...)` packages `correlation_id`, `micro_tasks`, `workflow_state`, etc.
* **Hybrid handoff finalization**:
  * Syncs newly generated micro-tasks into the active `Artifact`.
  * Broadcasts plan summaries to ActionCable channels.
  * Completion transitions to `workflow_state = awaiting_review` and `ball_with = Human`.

Implication for Artifact 16: the “console runner” and the `ai-agents` gem proof should **reuse** these concepts (`correlation_id`, `ball_with`, `workflow_state`, durable artifacts) rather than inventing an incompatible parallel system.

---

## 5) [DATABASE_SCHEMA] — Minimum Relevant Tables

The PRD must remain consistent with the following schema reality:

* `artifacts`:
  * `name`, `artifact_type`, `phase`, `owner_persona`, `payload (jsonb)`
* `ai_workflow_runs`:
  * `name`, `status (default: draft)`, `metadata (jsonb)`
* `sap_runs`:
  * `correlation_id (required)`, `status (default: pending)`, `title`, `output_json (jsonb)`
* `sap_messages`:
  * `content`, `role`, `sap_run_id`

---

## 6) [PROJECT_STRUCTURE] — Relevant Paths

* `app/services/ai_workflow_service.rb`
* `app/models/artifact.rb`
* `app/controllers/agent_hubs_controller.rb`
* `app/controllers/mission_control_controller.rb`
* `app/controllers/admin/sap_collaborate_controller.rb`
* `config/agent_prompts/sap_system.md`
* `knowledge_base/epics/Agent-hub/agent-hub-11/`

---

## 7) [LLM_RUNTIME] — Required LLMs for This Test

This test PRD must specify **two** model backends:

1. **Ollama** (local)
2. **Grok** via SmartProxy, model id: **`grok-latest`**

All provider calls must go through SmartProxy’s OpenAI-compatible endpoint:

* `POST /v1/chat/completions`
* `Authorization: Bearer <token>` (if configured)

Model selection must be configurable via environment/session settings, consistent with existing “model override” patterns.

---

## 8) [ACTIVE_ARTIFACT] — Item 16

* **ID**: 16
* **Artifact table reference**: this is `artifacts.id = 16` (canonical anchor for workflow linkage)
* **Name**: Agent-05 PRD 0010: Persona Setup & Console Handoffs
* **Status**: Todo
* **Description**: Spike — Persona Setup & Console Handoffs (gem validation + minimal runner; multi-provider proof). Establish foundation for multi-agent setup.

---

## 9) PRD OUTPUT REQUIREMENTS (for SAP)

As SAP, refine Item 16 into a full, implementation-ready PRD.

**The PRD must explicitly cover:**

1. **Bridge to UI**: How this spike integrates with or paves the way for **Agent Hub**, **Mission Control**, and/or **sap_collaborate**.
2. **Schema utilization**: Whether `artifacts` or `ai_workflow_runs` require extension to store gem metadata and handoff state.
3. **Agent registration**: Register SAP/Coordinator/CWA using a registry pattern (compatible with the selected gem).
4. **Handoff logic**: Define the payload (at minimum `correlation_id`, `ball_with`, `workflow_state`, `micro_tasks`) and where it is persisted.
5. **Private AI focus**: Default to local inference (Ollama) via SmartProxy; allow `grok-latest` selection for comparison.

**Output format:**

* Return only the Markdown content of the PRD.
* Include the tag `[ACTION: FINALIZE_PRD: 16]` at the end.
