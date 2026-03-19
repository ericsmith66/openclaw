# Draft Vision — Agent Hub + Workflow (Artifacts, Phases, and Collaboration)

This document is a **draft vision** for how `Agent Hub` (collaboration UI) and `Workflow UI/background execution` work together.

It incorporates the decisions captured in:

- `knowledge_base/epics/Agent-hub/functional_gaps.md`
- `knowledge_base/epics/Agent-hub/gap_feedback.md`

It is intentionally *workflow-shaped* because we are defining the SDLC workflow we want to automate.

---

## 1) North Star

Provide a single cohesive owner-facing experience where:

1. Humans collaborate with multiple agents (SAP / Conductor / CWA) in **conversations**.
2. The work produced by agents is captured as **artifacts**.
3. Artifacts move through **phases** (SDLC) via explicit **status mover actions** (e.g., `/approve`, `/reject`, `move to SAP`).
4. **Execution** (planning, implementation, tooling) happens in the Workflow UI and/or background processing.
5. Agent Hub displays the outcomes via links + status updates, without becoming a workflow rules engine.

---

## 2) User-level capabilities (what the user can do)

### A) Collaboration (Agent Hub)

- Select a **persona tab** (SAP / Conductor / CWA) to route messages and view context.
- Create/select **conversations**.
- Send messages (with optional mentions and attachments).
- Receive responses and see inter-agent collaboration.
- Trigger **status mover actions** from the conversation stream:
  - `/approve` (approve artifact for phase transition)
  - `/reject`
  - `move to SAP` / `handoff` (route to another persona or next workflow owner)
  - `/backlog` (set artifact phase to backlog)

### B) Workflow administration and execution (Workflow UI/background)

- View workflow runs and their linked artifacts.
- See artifact current phase/state.
- Execute planned work:
  - Coordinator planning
  - CWA code implementation (tools, code changes)
- Manage “non-conversational” administration:
  - workflow lifecycle
  - queues
  - approvals audit
  - viewing backlog lists

---

## 3) Key decisions (current)

These are the working decisions reflected in `gap_feedback.md`.

1. **Agent Hub primary object = Conversations**
   - Sidebar selects conversations (persisted threads; currently `SapRun`).
   - Agent Hub provides **status movers** (actions), not a rules engine.

2. **Objects are linked between Agent Hub and Workflow UI**
   - Agent Hub conversation references workflow objects by stable IDs.
   - Workflow UI executes and updates state; Agent Hub displays updates.

3. **Artifacts are stored in a DB table with structured + unstructured data**
   - Structured: `id`, `name`, `artifact_type`, `state/phase`, etc.
   - Unstructured: `jsonb` payload (document-store style) for artifact content.

4. **`/approve` = approve for a phase transition**
   - Approvals are repeatable across phases (SAP → Coordinator → back to SAP → approve again → ready for dev → …).

5. **Backlog is an artifact phase**
   - Backlog is not a separate subsystem; it is a phase in the SDLC artifact lifecycle.

6. **Agent Hub does not execute `ai-agents` workflows**
   - Agent Hub posts messages/actions; execution happens in Workflow UI/background.

7. **RAG “good enough” (Phase 1) acceptance**
   - Static RAG (e.g., `knowledge_base/static_docs/eric_grok_static_rag.md`) is “good enough” if a **simple PRD** can traverse the SDLC loop end-to-end.

---

## 4) Conceptual model (domain objects)

This section describes the core objects and how they relate.

### 4.1 Conversation

A conversation is the unit of collaboration.

- Current implementation: `SapRun` + `SapMessage`
- Holds message history, persona context, attachments, and links to workflow objects.

### 4.2 Workflow run

A workflow run represents an execution container that can:

- track lifecycle status
- capture audit events
- coordinate planning + development

- Current implementation: `AiWorkflowRun`

### 4.3 Artifact

An artifact is the durable “thing” that moves through SDLC.

Examples:

- Idea
- PRD
- Epic (containing PRDs)
- Plan
- Code change proposal
- QA report

Artifacts have:

- a current **phase** (SDLC)
- an optional **owner persona/role** (SAP / Coordinator / CWA)
- a **version history** / audit trail

### 4.4 Phase transitions

Phases represent SDLC states. A transition is:

- triggered by a status mover action (e.g., `/approve`, `/reject`, `/backlog`, `move to SAP`)
- applied to an artifact
- recorded as an audit event
- broadcast back to Agent Hub

---

## 5) Artifact phases (SDLC)

This is a draft phase set (names can evolve). The key requirement is that artifacts have a **single source of truth phase**, and the phase changes are auditable.

Example phases:

- `backlog`
- `ready_for_analysis`
- `in_analysis`
- `ready_for_development_feedback`
- `ready_for_development`
- `in_development`
- `ready_for_qa`
- `complete`

Phase change semantics:

- `/approve` advances an artifact to the next phase for its current workflow step.
- `/reject` moves an artifact back to a prior phase or to a “rework” state (to be defined).
- `move to SAP` routes the artifact/conversation back to SAP for revision.
- `/backlog` moves an artifact to `backlog`.

---

## 6) Workflows (end-to-end loops)

### 6.1 “Simple PRD through full SDLC” (Phase 1 acceptance flow)

Goal: prove the end-to-end loop works with the current static RAG.

1. **SAP** drafts a PRD artifact.
2. `/approve` transitions it to a planning phase and routes to **Coordinator**.
3. **Coordinator** adds plan + feedback and may route back to **SAP**.
4. SAP revises PRD and `/approve` again.
5. Artifact transitions to **ready for development**.
6. Coordinator hands plan to **CWA**.
7. **CWA** implements and updates workflow status.
8. Artifact moves to **ready for QA** then **complete**.

Agent Hub responsibilities during this loop:

- show the conversation context
- show artifact links + current phase
- provide status movers
- show results/status updates from workflow execution

Workflow UI/background responsibilities:

- execute planning/development
- manage phase transitions + audit
- manage tool traces/results

---

## 7) Schemas (draft)

These are draft schemas for the relevant objects. They reflect the “structured + unstructured” artifact store decision.

### 7.1 `sap_runs` (Conversation)

Current (simplified):

- `id`
- `user_id`
- `correlation_id`
- `title`
- `status` (chat runtime: pending/running/…)
- `conversation_type`
- `created_at`, `updated_at`

Proposed additions (draft):

- `metadata` (`jsonb`) to store linking info such as:
  - `ai_workflow_run_id`
  - `active_artifact_id`
  - `linked_artifact_ids[]`

### 7.2 `sap_messages` (Conversation messages)

- `id`
- `sap_run_id`
- `role` (user/assistant)
- `content`
- timestamps

### 7.3 `ai_workflow_runs` (Workflow run)

Current:

- `id`
- `user_id`
- `status` (`draft`, `pending`, `approved`, `failed`)
- `metadata` (`jsonb`) with transitions/audit
- `archived_at`
- timestamps

Proposed (draft):

- link to primary conversation:
  - `sap_run_id` (optional) or store in metadata

### 7.4 `artifacts` (new)

Draft table:

- `id` (PK)
- `user_id` (owner)
- `name` (structured)
- `artifact_type` (structured enum-ish string)
  - examples: `idea`, `epic`, `prd`, `plan`, `qa_report`, `code_change`
- `phase` / `state` (structured)
  - examples: `backlog`, `ready_for_analysis`, …
- `payload` (`jsonb`, unstructured document)
  - markdown body, sections, embedded data, references
- `current_version` (integer) or `version` string
- timestamps

### 7.5 `artifact_transitions` (optional but recommended)

If we want strong audit and phase history:

- `id`
- `artifact_id`
- `from_phase`
- `to_phase`
- `action` (e.g., `approve`, `reject`, `backlog`, `handoff`)
- `actor_user_id` (human)
- `actor_persona_id` (SAP/Coordinator/CWA)
- `notes` (text)
- `metadata` (`jsonb`) (version hash, links, etc.)
- timestamp

### 7.6 Linking overview

Minimum viable linking:

- Conversation (`sap_runs`) references Workflow run (`ai_workflow_runs`) and current Artifact (`artifacts`).
- Workflow run references its artifacts and optionally the primary conversation.

---

## 8) Clarifying questions

These are the questions that still need crisp answers before breaking epics/PRDs into their own documents.

### A) Phases and transitions

1. What is the canonical phase list (names + meanings)?
2. Which transitions require `/approve` vs which are automatic?
3. What exactly does `/reject` do (send back one phase? send to a `needs_clarification` phase? send to `backlog`)?
4. Do we require approvals to pin to a specific artifact version/content hash?

### B) Roles and ownership

1. Who is “Coordinator” (persona, human role, or both)?
2. When a PRD is with Coordinator, can SAP still message in the same conversation?
3. How do we represent “owner” of an artifact phase (persona vs human)?

### C) Linking and navigation

1. Does every conversation always have a linked workflow run?
2. Can a conversation link to multiple artifacts concurrently?
3. What is the minimal “workflow link card” that appears in Agent Hub (run ID, artifact ID, current phase, links)?

### D) Execution model

1. What triggers background execution?
   - a phase transition?
   - an explicit “run” button in workflow UI?
2. How do we stream results back to Agent Hub (events, websockets, polling)?

### E) RAG acceptance

1. What is the canonical “simple PRD” example we will use as the acceptance test?
2. What constitutes pass/fail for “good enough RAG” in Phase 1?

---

## 9) Risks, objections, and alternatives

### Risk: fragmented user experience

If Agent Hub and Workflow UI are separate, users may feel they are jumping between tools.

Mitigation:

- Ensure first-class deep links.
- Ensure status changes and results are visible in Agent Hub without navigating.

### Risk: unclear source of truth

Multiple models can represent state (`SapRun.status`, `AiWorkflowRun.status`, `Artifact.phase`).

Mitigation:

- Treat `Artifact.phase` as the SDLC source of truth.
- Treat `AiWorkflowRun.status` as workflow execution health.
- Treat `SapRun.status` as chat runtime.

### Objection: “we’re building a workflow engine twice”

Alternative:

- Make Workflow UI the only place phase transitions happen; Agent Hub only posts “requests” and shows results.

Tradeoff:

- Cleaner separation, but slower user loop if Agent Hub can’t move phases.

### Alternative architecture: Run-centric UI

Instead of conversation-centric Agent Hub:

- Sidebar selects workflow runs.
- Chat is embedded in runs.

Pros:

- Single container model.

Cons:

- More UI bloat and couples chat to execution.

---

## 10) Next step after this document

### Proposed approach: smallest feature set to run SDLC for 1–2 “simple stories”

Your proposal (smallest feature set first) is the right way to de-risk this.

Instead of building the full vision up-front, we should identify the minimum surface area required to:

1. Create an artifact (PRD) from a conversation
2. Move it through a few SDLC phases (including “back to SAP for re-approval”)
3. Hand it off to CWA for implementation
4. Mark it QA-ready and complete

This yields real hands-on experience and forces clarity on:

- linking (conversation ↔ workflow run ↔ artifact)
- phase semantics (`/approve`, `/reject`, `backlog`)
- what the UI must show vs what can remain “workflow UI/background”

### Minimal feature set (MVP) — Phase 1

#### A) Artifact store (required)

- `artifacts` table (structured + `jsonb` payload)
  - structured: `id`, `name`, `artifact_type`, `phase`, timestamps
  - unstructured: `payload` (`jsonb`) containing markdown + references

#### B) Linking (required)

- Conversation (`SapRun`) can link to:
  - `active_artifact_id`
  - `linked_artifact_ids`
  - optionally `ai_workflow_run_id`

#### C) Phase transitions + audit (required)

- Implement phase transitions on artifacts:
  - `/approve` = advance to next phase (and/or route to next owner)
  - `/reject` = move to prior phase (or a defined rework phase)
  - `/backlog` = set phase to `backlog`
- Record transitions (either in `artifact_transitions` table or in a structured `jsonb` audit log)

#### D) “Workflow execution” integration (minimal)

- Agent Hub **does not** execute workflows.
- Workflow UI/background only needs to support:
  - Coordinator can attach a “plan artifact” (or plan section in payload)
  - CWA can mark “in development” → “ready for QA” → “complete”

#### E) Simple system health dashboard (recommended)

To keep the SDLC test loop reliable, build a small “Admin System Health” page that shows:

- Smart proxy connectivity / last response
- ActionCable connected status
- Job queue health (SolidQueue)
- Artifact counts by phase
- Recent phase transitions (last 20)

This is intentionally minimal and exists to support learning and iteration.

### MVP acceptance criteria

We consider Phase 1 successful if we can take a small set of “system readiness” stories plus at least 1–2 workflow stories end-to-end.

#### A) “System readiness” stories (you nominated)

1. **Proxy server health**: the proxy server is up and can serve the LLMs.
2. **Worker health + deploy consistency**: workers are running and on the same codebase/version as web.
3. **Cloudflare availability**: Cloudflare endpoints are available.

#### B) Three additional nominated stories (to round out the SDLC test loop)

4. **Artifact SDLC happy path**: create a simple PRD artifact and move it through phases to `complete`.
   - Minimum: `ready_for_analysis → in_analysis → ready_for_development → in_development → ready_for_qa → complete`.

5. **Loop-back + re-approval**: Coordinator requests changes and routes back to SAP; SAP revises and `/approve`s again.
   - Minimum: at least one “back to SAP” loop and a second approval.

6. **Linking integrity**: a conversation stays correctly linked to the right workflow run + active artifact across persona tab switches.
   - Minimum: switching persona tabs does not lose the active conversation’s linked IDs.

### After MVP: split into Epics/PRDs

Once MVP is proven, we break into separate epics/PRDs:

1. Artifact model hardening (versions, stronger audit, export/commit)
2. Agent Hub ↔ Workflow deep-link UX (cards, sidebar badges)
3. Workflow UI build-out (views, filters, ownership)
4. Status mover actions polish (confirmations, permissions, guardrails)
5. Backlog experience (backlog list + search + resume)
6. RAG improvements epic (after E2E loop passes)

---

## 11) Draft Epic + PRDs (assumptions included)

This section proposes an Epic and a small set of PRDs that implement the Phase 1 MVP described above.

**Re-org note:** The goal here is to separate:

1. **Capability stories** (what the agent/human can do in the product)
2. **Enabling work** (what we must build in the system to make those capabilities possible)
3. **UI changes** (what screens/components are introduced or modified)

Assumptions (please confirm/correct):

1. **Agent Hub is conversation-centric** (sidebar selects conversations).
2. **Agent Hub is collaboration + status movers** (not a rules engine).
3. **Execution happens in Workflow UI/background**.
4. **Artifacts are DB-backed** with structured columns + `jsonb` payload.
5. **Backlog is a phase** in the artifact SDLC.
6. Phase names below are representative; we can rename as needed.

### Epic: Agent Hub + Workflow MVP (Phase 1)

**Epic goal**: Enable the **Agent Hub + Workflow system** so we can run a small set of **test cases** (the six stories in §10) through the full SDLC loop and get hands-on experience.

This epic is **not** “the work SAP does”. SAP/Coordinator/CWA are roles in the process; the epic delivers the **platform capabilities** that allow those roles to operate.

#### How this epic maps to `gap_feedback.md` (what we do next)

This epic is the “next step” implied by the decisions already recorded in `knowledge_base/epics/Agent-hub/gap_feedback.md`:

- **Q1 (Decided)**: Agent Hub is conversation-centric and provides **status movers** (not a rules engine)
  - Epic focus: keep Agent Hub lightweight; add only the minimum artifact context + action affordances.
- **Q2 (Decided)**: Objects are **linked** between Agent Hub and Workflow UI
  - Epic focus: implement stable linking (conversation ↔ workflow run ↔ artifact IDs) and deep links.
- **Q3 (Decided)**: Artifacts live in a table with **structured fields + `jsonb` payload**
  - Epic focus: create the artifact store and make phase/state queryable.
- **Q4 (Decided)**: `/approve` = **approve for phase transition**, repeatable across loop-backs
  - Epic focus: implement phase transitions + re-approval loop semantics.
- **Q5 (Decided)**: Backlog is an **artifact phase**
  - Epic focus: treat backlog as a lifecycle phase, not a separate system.
- **Q6 (Decided)**: Agent Hub posts messages/actions; execution happens in Workflow UI/background
  - Epic focus: minimal workflow UI hooks + status updates back into the conversation.
- **Q7 (Decided)**: Static RAG is “good enough” if a simple PRD can traverse SDLC
  - Epic focus: do not expand RAG; use it to validate the SDLC loop.

Put simply: **this epic operationalizes the gap-feedback decisions into shippable platform capabilities + minimal UI surfaces.**

**Non-goals (Phase 1)**:

- “Meaningful” retrieval-based RAG
- Full workflow UI parity (filters, dashboards, heavy admin)
- Complex multi-artifact orchestration
- Deep structured output cards beyond a minimal artifact link card

### 11.1 Capabilities we are building (platform capabilities)

These are the product capabilities delivered by this epic (independent of any single persona’s work).

#### Capability C1 — System health visibility

- Owner can verify runtime readiness (proxy/workers/cable/cloudflare) from one minimal page.
- SAP/CWA can also **run and improve** these checks over time (adding endpoints, tightening checks, improving diagnostics).

#### Capability C2 — Artifact store + SDLC phases

- Artifacts exist as first-class objects with a single SDLC phase source of truth.
- Backlog is a phase (not a separate subsystem).

#### Capability C3 — Conversation ↔ workflow linking

- Conversations link to workflow objects (run/artifact IDs) and the link persists across persona tab switches.

#### Capability C4 — Status mover actions

- Agent Hub provides actions like `/approve`, `/reject`, `/backlog`, and routing (e.g., “move to SAP”).
- These actions trigger phase transitions and/or ownership routing, without embedding a rules engine in Agent Hub.

#### Capability C5 — Minimal workflow execution surface (outside Agent Hub)

- Workflow UI/background can advance artifacts through dev/QA/complete and publish status/results back to the linked conversation.

### 11.2 UI changes (explicit)

This lists the UI surface area introduced/changed by the epic.

#### UI-1: Agent Hub (existing) — add minimal artifact context

- Add a minimal artifact “link card” in the active conversation view:
  - Artifact ID, name, phase
  - Deep link to Workflow UI artifact detail

#### UI-2: Agent Hub (existing) — status mover actions

- Extend the command/confirmation pattern to support:
  - `/approve`, `/reject`, `/backlog`
  - routing actions (e.g., “move to SAP” / “handoff”)

#### UI-3: Workflow UI (new/minimal)

- Minimal pages:
  - artifact list (filter by phase)
  - artifact detail (view/edit payload)
  - buttons/actions to advance dev/QA/complete

#### UI-4: Admin System Health (new/minimal)

- Minimal health page (operator-facing):
  - proxy health
  - worker health + code version
  - cloudflare endpoint availability
  - optional: artifact counts by phase + recent transitions

### 11.3 Post-epic test criteria (the six test cases we will run)

After the epic is implemented, we will validate it by running the **six stories in §10** as test cases end-to-end.

- System readiness:
  1. Proxy server health
  2. Worker health + code/version consistency
  3. Cloudflare availability
- SDLC loop:
  4. Artifact SDLC happy path
  5. Loop-back + re-approval
  6. Linking integrity across persona tab switches

These stories are **test criteria**, not “persona work plans”.

#### 11.3.1 Human + persona workflow test script (role-based)

This is the same post-epic validation suite, rewritten as a **role-based script** so it’s clearer how the Agent Hub + Workflow surfaces are used.

Assumptions:

- Conversations are created/selected in Agent Hub.
- A conversation is linked to an active artifact (PRD).
- Phase transitions are executed via status movers (e.g., `/approve`) and reflected in Workflow UI.

##### Test A — “Create PRD with SAP” (Human + SAP)

Steps:

1. (Human) Open Agent Hub and select the `SAP` persona tab.
2. (Human) Create a new conversation.
3. (Human) Ask SAP to draft a PRD for a simple story (use the Phase 1 “simple PRD” candidate).

Expected results:

- A new conversation exists and is active.
- A PRD artifact is created (or can be created) and linked to the active conversation.
- Artifact has:
  - `artifact_type = prd`
  - `phase = ready_for_analysis` (or equivalent starting phase)
  - a `payload` containing PRD markdown (at minimum: overview + ACs).
- Agent Hub displays a minimal artifact link card (ID, name, phase) for the conversation.

##### Test B — “SAP incorporates feedback and uses the template” (Human + SAP)

Steps:

1. (Human) Provide feedback on the PRD (missing ACs, unclear scope, edge cases).
2. (SAP) Update the PRD artifact payload to match the PRD template expectations.

Expected results:

- PRD artifact payload is updated (versioning/audit recorded if implemented).
- PRD remains linked to the same conversation.
- Changes are visible in Workflow UI artifact detail view.

##### Test C — “Human approval advances phase” (Human)

Steps:

1. (Human) In Agent Hub, issue `/approve` for the PRD.

Expected results:

- Artifact phase transitions forward (e.g., `ready_for_analysis → in_analysis` or to a defined next phase/owner).
- Approval is recorded with:
  - actor (human)
  - timestamp
  - from/to phase
  - artifact version/hash (if available)
- Agent Hub reflects the updated phase on the artifact link card.

##### Test D — “Coordinator review and questions (loop-back)” (Coordinator + SAP)

Steps:

1. (Coordinator) Open Workflow UI artifact detail and review PRD.
2. (Coordinator) Ask clarifying questions and/or request changes.
3. (Coordinator) Route the artifact back to SAP (or transition to a phase that implies SAP revision).
4. (SAP) Revise PRD.
5. (Human) `/approve` again.

Expected results:

- Coordinator feedback is captured (comment/notes artifact section or audit log).
- Artifact returns to a SAP-owned revision phase (or equivalent).
- After SAP revision, a second `/approve` advances phase again.
- Audit trail shows at least one loop-back and two approvals.

##### Test E — “Ready for development → Coordinator plan → handoff to CWA” (Coordinator + CWA)

Steps:

1. (Coordinator) Move PRD/artifact to `ready_for_development`.
2. (Coordinator) Attach a plan (plan artifact or plan section).
3. (Coordinator) Handoff to CWA.
4. (CWA) Mark `in_development`, then `ready_for_qa`, then `complete`.

Expected results:

- Artifact phase progresses through development and QA phases.
- Workflow UI shows phase changes and plan content.
- Agent Hub conversation receives status updates (link card phase changes at minimum).
- Final state shows `phase = complete`.

##### Test F — “System readiness checks” (Human)

Steps:

1. (Human) Open the Admin System Health page.

Expected results:

- Proxy health check returns OK or actionable failure.
- Worker health shows workers alive and matching code version with web.
- Cloudflare endpoint checks return OK or actionable failure.
- (Optional) artifact counts by phase and recent transitions are visible.

---

### PRD-MVP-01: System Health Dashboard (minimal)

**Problem**: We need a fast way to validate that the system can support SDLC iteration (proxy/queue/cable/cloudflare).

**User story**: As the owner, I can open a simple system health page and see whether the critical runtime components are healthy.

#### A) What SAP/CWA produce (workflow output)

For this PRD, SAP/CWA do more than “interpret results”. They also help define, evolve, and validate the health checks.

Expected SAP/CWA contributions:

- **Define health checks** (what “healthy” means for proxy/workers/cable/cloudflare).
- **Build or extend endpoints/checks** as needed (either in the app or by calling existing endpoints).
- **Interpret results** and decide whether it’s safe to proceed with SDLC work.

Examples of SAP/CWA behavior:

- If proxy is unhealthy, do not proceed with SDLC work; create a backlog artifact or escalation note.
- If workers are on a different version than web, halt workflow execution until reconciled.
- If Cloudflare endpoints fail, route to infrastructure troubleshooting.

#### B) What we build (platform/engineering work)

We (the product/engineering implementation) build the health dashboard page, plus an extensible way to add/maintain checks.

Minimum platform implementation:

- A health controller/page that aggregates check results
- Check implementations for:
  - Proxy
  - Worker/version consistency
  - ActionCable
  - Cloudflare endpoints
- A place to configure endpoints (env) and a place to add new checks later

**Functional requirements**:

- A minimal “Admin System Health” page that shows:
  - Proxy server reachable and serving model list/chat (or last successful check)
  - Job queue/worker health and whether workers are alive
  - ActionCable websocket connectivity status
  - Cloudflare endpoint reachability (HTTP ok) (env-configured)
  - Optional: artifact counts by phase + recent transitions (if artifact table exists)

#### C) UI elements introduced/changed

- New page: **Admin System Health** (operator-facing; simple table/cards)
- No changes required to the Agent Hub conversation UI for this PRD (other than adding a link, if desired)

**Acceptance criteria**:

- AC1: Proxy health: page shows OK/Fail with timestamp of last check.
- AC2: Worker health: page shows worker status and code version (git SHA or build identifier) for web + worker.
- AC3: Cloudflare health: page shows OK/Fail for configured endpoints.

**Additional acceptance criteria (to match your intent)**:

- AC4: Health checks are extensible: SAP/CWA can add at least one new check (or tighten an existing check) without refactoring the whole page.
- AC5: Failures include actionable diagnostics (e.g., error message / last successful timestamp / endpoint tested).

**Notes/assumptions**:

- “Same codebase” means “same git SHA” (or similar deploy identifier).
- Cloudflare endpoints list is configured via env.

---

### PRD-MVP-02: Artifact Store (structured + `jsonb`) + SDLC Phases

**Problem**: We need a durable unit of work that moves through SDLC phases independent of chat.

**User story**: As the owner, I can create an artifact (PRD/idea/epic), store it durably, and see its current phase.

#### A) What SAP/CWA produce (workflow output)

- SAP produces an **artifact payload** (e.g., PRD markdown) stored in the artifact.
- CWA produces updates to artifact phase during development (e.g., `in_development → ready_for_qa → complete`) and may attach implementation notes/results.

#### B) What we build (platform/engineering work)

- New `artifacts` persistence model (structured columns + `payload jsonb`)
- Phase/state definition and validation
- Optional transition/audit storage

#### C) UI elements introduced/changed

- Workflow UI (minimal) will need to be able to view/edit artifact payload and phase
- Agent Hub will later show an artifact link card (handled in PRD-MVP-03/04)

**Functional requirements**:

- Create `artifacts` storage (structured columns + `jsonb` payload)
  - Structured fields: `name`, `artifact_type`, `phase`, timestamps
  - Unstructured: `payload` (`jsonb`) for artifact document content (markdown)
- Define a Phase 1 phase set (draft):
  - `backlog`, `ready_for_analysis`, `in_analysis`, `ready_for_development_feedback`, `ready_for_development`, `in_development`, `ready_for_qa`, `complete`

**Acceptance criteria**:

- AC1: An artifact can be created with `artifact_type=prd` and stored with markdown in `payload`.
- AC2: Artifact phase can be set to `backlog` and later moved out of backlog.
- AC3: Artifact phase is the SDLC source of truth.

---

### PRD-MVP-03: Conversation ↔ Workflow Object Linking

**Problem**: Agent Hub must remain conversation-centric, but actions must operate on linked workflow objects.

**User story**: As the owner, a conversation can be linked to a workflow run and an active artifact, and the link persists across persona tab switches.

#### A) What SAP/CWA produce (workflow output)

- SAP/CWA do not “produce” linking; they rely on it.
- Their output benefits from it: conversation context stays attached to the correct artifact/run across persona tab navigation.

#### B) What we build (platform/engineering work)

- Add/define linking fields (conversation ↔ workflow run ↔ artifact IDs)
- Ensure link persistence across persona tab switches
- Add deep links to Workflow UI

#### C) UI elements introduced/changed

- Agent Hub: minimal **artifact link card** displayed in the conversation view
- Workflow UI: artifact detail page that can be linked to

**Functional requirements**:

- Add linking fields to conversations (via `metadata` or explicit columns):
  - `ai_workflow_run_id` (optional)
  - `active_artifact_id`
  - `linked_artifact_ids[]`
- Display a minimal “link card” in Agent Hub showing:
  - current artifact ID + name + phase
  - link to Workflow UI view

**Acceptance criteria**:

- AC1: Switching persona tabs does not lose the active conversation’s `active_artifact_id`.
- AC2: The conversation shows the active artifact phase.

---

### PRD-MVP-04: Status Movers + Phase Transitions (`/approve`, `/reject`, `/backlog`, route)

**Problem**: We need repeatable phase transitions and loop-back re-approval (SAP ⇄ Coordinator ⇢ ready for dev ⇢ CWA ⇢ QA ⇢ complete).

**User story**: As the owner, I can use simple actions in Agent Hub to move an artifact through phases, including sending it back to SAP for revision and requiring re-approval.

#### A) What SAP/CWA produce (workflow output)

- SAP produces revisions to artifacts when routed back (and re-approval readiness).
- CWA produces implementation progress updates reflected by phase changes.

#### B) What we build (platform/engineering work)

- Status mover commands and confirmation UX
- Phase transition rules (minimal, deterministic)
- Audit trail of transitions (actor, from/to, timestamps)
- Routing metadata (e.g., “assigned to SAP/Coordinator/CWA”)

#### C) UI elements introduced/changed

- Agent Hub: confirmation bubble/actions for `/approve`, `/reject`, `/backlog`, routing
- Agent Hub: visible “current phase/assignment” (via link card or small badge)

**Functional requirements**:

- `/approve` transitions an artifact to the next phase (or next owner) and records audit.
- `/reject` transitions to a prior phase (or a defined rework phase) and records audit.
- `/backlog` sets phase to `backlog`.
- “move to SAP” (or equivalent) routes the artifact back to SAP for revisions.
- Audit events are recorded (table or `jsonb` log) with:
  - from_phase, to_phase
  - action
  - actor (user + persona)
  - artifact version/hash (if available)

**Acceptance criteria**:

- AC1: Loop-back works: SAP → approve → Coordinator feedback → back to SAP → approve again.
- AC2: Phase transitions are persisted and visible.

---

### PRD-MVP-05: Minimal Workflow UI/Background Hooks (Coordinator + CWA)

**Problem**: Execution happens outside Agent Hub; we still need a minimal loop to simulate/drive SDLC completion.

**User story**: As the owner (and/or Coordinator), I can add a plan and mark artifacts through dev/QA phases; CWA can pick up “ready for development” items.

#### A) What SAP/CWA produce (workflow output)

- Coordinator produces a plan (plan artifact or plan section in artifact payload).
- CWA produces code/work artifacts and marks phase progression during execution.

#### B) What we build (platform/engineering work)

- Minimal workflow UI pages + endpoints
- Background hooks (if needed) to update phases and publish results back to the linked conversation

#### C) UI elements introduced/changed

- Workflow UI: artifact list (by phase), artifact detail, phase transition controls
- Agent Hub: receives “status update” messages/cards from workflow execution (minimal)

**Functional requirements**:

- Minimal Workflow UI views:
  - list artifacts by phase
  - show artifact detail (payload)
  - set phase transitions (dev/qa/complete)
- Minimal “handoff to CWA” mechanism:
  - mark `ready_for_development`
  - show in a “CWA queue”

**Acceptance criteria**:

- AC1: Coordinator can attach a plan (either a plan artifact or plan section in payload).
- AC2: CWA can mark `in_development` → `ready_for_qa` → `complete`.
