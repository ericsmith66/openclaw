# Gap Feedback — Agent Hub (Agent-06 / CWA Interface)

This document is a companion to `functional_gaps.md`.

Purpose:

1. Capture **feedback questions** that still need answers to unblock design decisions.
2. Record **objections / risks** so tradeoffs are explicit.
3. Convert the current “winners” into **clear next-step implementation choices** (what we build first, what we defer).

Scope note: this is focused on *making the Agent Hub a coherent interface for Agent-06/CWA collaboration*, while keeping “administration” UIs (workflow monitoring, approvals, backlog lists) on separate pages where appropriate.

---

## Decision log (fill-in)

Use this section to mark decisions as they are made. The intent is to prevent re-litigating the same design questions and to make downstream implementation choices consistent.

**Terminology used in this doc:**

- **Persona**: the agent identity (e.g., SAP / Conductor / CWA).
- **Persona tab**: the UI tab you click to view/route messages as a persona.
- **Conversation**: a persisted conversation thread (currently `SapRun`).
- **Workflow run**: a workflow lifecycle object (currently `AiWorkflowRun`).

| ID | Decision question | Status (Pending/Decided) | Chosen option | Notes / rationale | Consequences to accept |
|---:|---|---|---|---|---|
| Q1 | What is Agent Hub’s primary object (sidebar selects Conversations vs Workflow runs)? | Decided | Conversations (`SapRun`) | Agent Hub is the collaboration surface. Sidebar selects conversations. Action bubbles are **status movers** (approve/reject/move to SAP), not a workflow rules engine embedded in the chat UI. | Must keep workflow rules/state machine out of Agent Hub UI; provide links/IDs so status moves apply to the correct linked workflow object/artifact. |
| Q2 | How do we link a Conversation (`SapRun`) to a Workflow run (`AiWorkflowRun`)? | Decided | Link objects between Agent Hub and Workflow UI | Agent Hub remains collaboration; workflow UI remains separate. The bridge is explicit linking between objects so actions/approvals operate on the linked workflow object. | Must implement stable IDs + deep links + consistent status labels across both UIs. |
| Q3 | Where do PRD artifacts live (DB/jsonb vs separate DB vs files)? | Decided | DB-backed artifacts table (structured columns + `jsonb` document payload) | Store artifacts in a table with structured fields for `id`, `name`, `state`, `artifact_type`, plus an unstructured `jsonb` payload for the artifact body/content. | Requires schema/migrations and a clear export/commit strategy if artifacts eventually become repo files. |
| Q4 | What does “approve” transition (run-level vs artifact-phase/version)? | Decided | Approve = phase transition for an artifact | `/approve` moves an artifact from its current phase to the next phase. The same artifact may return to a prior phase and require re-approval again (multi-pass review loop). | Must model phases explicitly and preserve history/versioning; UI must show current phase and what approval applies to. |
| Q5 | What is backlog semantics (stash vs operational queue)? | Decided | Backlog is an artifact state | Backlog means “this artifact is not being worked on right now.” Backlog applies to any artifact type (idea, PRD, epic containing PRDs). Backlog is a **state/phase** in the artifact lifecycle. | Must model artifact states/phases as a first-class lifecycle (SDLC). Backlog items must remain linkable/resumable (clear transition out of backlog). |
| Q6 | Does Agent Hub execute `ai-agents` runs, or is it collaboration-only with links? | Decided | Collaboration-only: posts messages/actions; execution in Workflow UI/background | Agent Hub is a collaboration surface that emits messages and “status mover” actions. Workflow execution (including `ai-agents` / CWA runs) happens outside Agent Hub (Workflow UI or background processing). | Must provide reliable deep links and state updates back into the conversation so users can see outcomes without embedding workflow logic in Agent Hub. |
| Q7 | What is “good enough” RAG for Phase 1 (acceptance criteria)? | Decided | “Good enough” = supports one simple PRD through full SDLC | RAG quality directly impacts Epic/PRD/code quality (esp. CWA output). For Phase 1 we accept static RAG (e.g., `eric_grok_static_rag.md`) as sufficient if it can produce a **simple PRD** and move it through the full SDLC loop (phase transitions, planning, handoff) end-to-end. | Complex stories may fail or be low quality; we must explicitly defer “RAG improvements” to a later epic and track failures as RAG-driven quality issues. |

## 0) Quick read: what your `winner` column implies

From `functional_gaps.md`, you’ve already indicated several strong preferences:

- **`AiWorkflowRun` wins** as the workflow container (don’t “bundle workflow into chat”).
- Agent Hub should stay the **collaboration surface**, not the workflow admin surface.
- **Storage follows the active conversation** (not “persona tab”), meaning a conversation can be opened from multiple UI contexts.
- RAG should remain **static for now** (use `knowledge_base/static_docs/eric_grok_static_rag.md`) until end-to-end is proven.

This is a valid direction, but it creates an architectural requirement:

> We must explicitly define the *link* between a collaboration conversation (`SapRun`) and a workflow object (`AiWorkflowRun`) and ensure all “action bubbles” operate on that linked object.

If we don’t define/link the objects, the UI will continue to show buttons without durable meaning.

---

## 1) Cross-cutting objections / risks to address early

### A) “Collaboration UI separate from workflow UI” can work — **only if linking is first-class**

Objection:
- If Agent Hub remains chat/conversation-centric, but approvals/backlog/PRDs live elsewhere, you still need:
  - stable IDs
  - deep links
  - consistent state labels
  - an audit trail visible from both sides

Risk if ignored:
- Users will not know “what object the chat is about” and action bubbles will continue to feel like they do nothing.

Minimum requirement:
- A consistent concept of “this conversation is about workflow run X and artifact Y”.

### B) Avoid adding a third workflow engine

Objection:
- There are already two lifecycle systems:
  - `SapRun.status` (chat runtime)
  - `AiWorkflowRun.status` (workflow lifecycle)

Risk if we introduce a third “artifact workflow” state machine without clear ownership:
- contradictions and debugging complexity.

Minimum requirement:
- declare ownership: what states mean what, and what the UI should show.

---

## 2) Feedback questions (what you must decide)

Below are the decisions that will determine whether the next steps are clean and non-duplicative.

Each question includes a recommended direction aligned with your `winner` notes, plus pros/cons and consequences.

### Q1) What is Agent Hub’s primary “object”?

Your note: “neither; it’s the human interaction with the agents… administration should be on other pages”.

**Decision needed:** What does the Agent Hub sidebar list and select?

**Decision (Decided):** The Agent Hub sidebar selects **Conversations** (persisted threads, currently `SapRun`).

Additionally, the interaction model in Agent Hub should be:

- **Status movers**: discrete actions like `approve`, `reject`, `move to SAP`, `handoff`, etc.
- **Not** a rules engine / workflow state manager embedded inside the chat UI.

Options:

1. **Conversations (`SapRun`)** (collaboration surface) + links to workflow objects.
2. **Workflow runs (`AiWorkflowRun`)** (workflow surface) + a chat pane per run.

**Recommendation (aligned with your decision):** Option 1.

Pros:
- Keeps Agent Hub light and conversational.
- Matches your “evite” mental model: chat = invitation/context; workflow = separate UI.

Cons:
- Requires explicit linking to `AiWorkflowRun` and artifacts, or approvals/PRDs won’t be testable.

Consequence if not decided:
- Ongoing confusion about what is being approved, archived, or handed off.

### Q2) What is the *linking model* between conversation and workflow?

**Decision needed:** How do we link `SapRun` to `AiWorkflowRun`?

**Decision (Decided):** Objects are explicitly linked between Agent Hub (collaboration) and the Workflow UI (administration/execution). Agent Hub action bubbles and links must operate on the linked workflow object.

Options:

1. `SapRun.metadata["ai_workflow_run_id"] = <id>` (lightweight, quick)
2. Add `sap_runs.ai_workflow_run_id` foreign key (stronger integrity)
3. Separate join model (supports many-to-many)

**Recommendation:** Implement explicit linking as a first-class concept. Start lightweight if needed (e.g., metadata), but ensure the link is stable and discoverable from both UIs.

Pros:
- Fast iteration; minimal migrations.

Cons:
- Weaker referential integrity.

Consequence if you skip linking entirely:
- Action bubbles can’t reliably operate on the correct run/artifact.

### Q3) What is the canonical artifact store for PRDs?

Your note: “DB table in a document store like jsonb… PRDs shouldn’t be in dev/prod DB; their own DB.”

**Decision needed:** Where do PRD artifacts live during the workflow?

**Decision (Decided):** Artifacts are stored in a dedicated table with:

- **Structured columns**: identifiers and workflow-relevant fields like `id`, `name`, `state`, and `artifact_type`
- **Unstructured payload**: the artifact body/content stored as `jsonb` (document-store style)

Options:

1. Rails DB table (e.g., `artifacts` with `jsonb`) in the same DB
2. Separate database/schema for artifacts
3. Files only (`knowledge_base/**`) with git as the source of truth

**Recommendation:** DB-backed artifact table with `jsonb` payload as Phase 1. Keep the option open to move artifacts to a separate DB later if governance/scale requires it.

Pros:
- Enables end-to-end testing quickly (generate → review → approve).
- Can include versioning + phase status within `jsonb`.

Cons:
- Governance question: what belongs in prod DB vs “knowledge DB”.

Consequence if you start with files-only:
- Approval UX becomes “out of band” (git-driven), hard to validate in the Agent Hub.

### Q4) What does “approve” mean (scope + phase)?

Your note: “artifact is approved for a phase transition… can go forward/back… eventually terminal”.

**Decision needed:** What exactly does the `/approve` bubble transition?

**Decision (Decided):** `/approve` means **approved for a phase transition** on an artifact.

Intended lifecycle (high-level):

1. Artifact (e.g., PRD) is drafted.
2. `/approve` advances it to the next phase and can route it to the next owner.
3. It can move to **Coordinator** for planning and feedback.
4. It can return to **SAP** for revisions and then requires `/approve` again.
5. Once ready for development, the **Coordinator** builds a plan and hands it to **CWA**.

This implies:

- Approvals are **repeatable** across phases.
- A phase transition should record: who approved, when, and what version/content hash was approved.

Options:

1. Approve **a workflow run** (`AiWorkflowRun.status`)
2. Approve **a specific artifact version for a specific phase** (recommended by your note)

**Recommendation:** Option 2.

Pros:
- Clear audit trail (what content was approved).
- Fits multi-phase review cycles.

Cons:
- Requires modeling of artifact versions and phases.

Consequence if approval is only run-level:
- Ambiguity: content can change after “approval”, undermining trust.

### Q5) Backlog semantics: stash vs handoff queue?

Your note: “stash for incomplete work… good ideas… bad ideas… YAGNI”.

**Decision needed:** Is backlog an operational queue that agents pull from, or a passive stash?

**Decision (Decided):** Backlog is **a state/phase of an artifact** meaning: *we are not going to work on this artifact right now*.

Backlog can apply to **any artifact type**, for example:

- an idea
- a PRD
- an epic artifact that contains/organizes PRDs

This implies backlog is not “a separate system”; it is one of the lifecycle phases an artifact can be in.

Example SDLC-style phase progression (illustrative, names can be adjusted):

`backlog → ready_for_analysis → in_analysis → ready_for_development_feedback → ready_for_development → in_development → ready_for_qa → complete`

Options:

1. Passive stash (capture only; no SLA)
2. Operational handoff queue (agents pull/resume from backlog)

**Recommendation:** Model backlog as an artifact phase within a single artifact lifecycle. Ensure there is a clear and auditable transition out of `backlog` (e.g., `backlog → ready_for_analysis`).

Pros:
- Minimal UX to deliver value.

Cons:
- Requires agreement on phase naming and transitions.
- Without a view/list UI, backlog will still feel invisible.

Consequence if backlog is “just a command”:
- It won’t be used reliably.

### Q6) Is Agent Hub an execution surface for `ai-agents` or only collaboration?

Your note: “Agent Hub posts messages and actions; execution happens in workflow UI/background”.

**Decision needed:** Do we execute `Agents::Registry.fetch(:cwa)` from Agent Hub?

**Decision (Decided):** Agent Hub does **not** execute workflows. It posts messages and action intents; execution happens in the Workflow UI or background processing.

Minimum implications:

- Agent Hub must be able to create/reference a workflow object ID (run/artifact) and include it with posted actions.
- Agent Hub must receive updates back (status changes, artifact links, results) and display them in the active conversation.

Options:

1. Yes (Agent Hub = workflow executor UI)
2. No (Agent Hub posts messages and actions; execution happens in workflow UI/background)

**Recommendation (aligned with your decision):** Option 2.

Pros:
- Keeps responsibilities clean.
- Avoids duplicating the workflow engine inside Agent Hub.

Cons:
- You must still surface execution results back into the conversation (links, summaries, state changes).

Consequence if neither UI owns execution:
- Workflows become untestable/opaque.

### Q7) RAG: what is “good enough” for Phase 1?

Your note: “start with static rag until finished agent_hub; next epic is RAG fine tuning”.

**Decision needed:** What is the acceptance test for “RAG is good enough”?

**Decision (Decided):** “Good enough” means the current static RAG (notably `knowledge_base/static_docs/eric_grok_static_rag.md`) is sufficient to:

1. Produce a **simple PRD** (non-complicated story)
2. Move that PRD/artifact through the **full SDLC lifecycle** end-to-end (phase transitions, planning/feedback, and handoff to development)

Quality expectations:

- The output may have room for improvement.
- The intent is not “perfect PRDs for complex work” yet.
- We explicitly treat RAG upgrades as a later epic once the end-to-end loop is proven.

**Recommendation:** Keep static RAG for Phase 1, and define a minimal E2E acceptance test: “a simple PRD can successfully traverse the SDLC loop.” Add lightweight observability (what context/docs were included) so failures can be attributed to RAG vs workflow logic.

Pros:
- Keeps complexity low.

Cons:
- Quality may be inconsistent without retrieval.

Consequence if no acceptance criteria:
- RAG will remain a vague complaint rather than a measurable improvement.

---

## 3) Gap-by-gap objections and clarifying questions

This section mirrors the table rows and focuses on what could go wrong even with your chosen “winner”.

### Gap: Split container model (`SapRun` vs `AiWorkflowRun`) — Winner: `AiWorkflowRun`

Objection:
- If `AiWorkflowRun` “wins” but Agent Hub remains conversation/collaboration, we still need to define:
  - when an `AiWorkflowRun` is created
  - where its ID is stored
  - how the conversation knows which run it is collaborating on

Clarifying questions:
- When a user clicks “New Conversation”, should that also create a new `AiWorkflowRun`?
- Or does a conversation link to an existing run?

### Gap: “No meaningful RAG” — Winner: Static for now

Objection:
- Static context can hide failures (“it’s there but not used”).

Clarifying questions:
- Do we require the model prompt payload to log:
  - which static docs were included
  - snapshot timestamp
  - truncation info

### Gap: Backlog feels missing — Winner: separate page

Objection:
- “Separate page” is good, but backlog must still be discoverable from Agent Hub.

Clarifying questions:
- Should Agent Hub show:
  - a link to backlog list
  - last 3 backlog items
  - backlog count badge

### Gap: Can’t generate a PRD — Winner: artifact store w/ `jsonb`

Objection:
- If PRDs are DB-backed, you need a migration path to “commit to repo” when ready.

Clarifying questions:
- What is the “official” PRD location eventually?
- Who commits PRDs: the agent (via tool) or the human?

### Gap: Can’t test approvals — Winner: phase transitions

Objection:
- Approval must be tied to a specific artifact + phase; otherwise it’s untestable.

Clarifying questions:
- Do we need a “questions back” mechanism where downstream agents request clarification before approval?
- Should that create a new phase state (e.g., `needs_clarification`)?

### Gap: Workflow semantics unclear — Winner: storage follows conversation

Objection:
- “Conversation can persist across more than one persona tab/view” implies a need for stable IDs and clear UI to show which conversation is active.

Clarifying questions:
- Should the URL always include `conversation_id`?
- Should persona tabs show the same conversation if it is multi-persona, or is that future?

### Gap: Chatwoot/`ai-agents` not tied in — Winner: separate workflow UI

Objection:
- If the workflow engine runs elsewhere, Agent Hub must still show:
  - run status updates
  - artifact links
  - tool trace summaries

Clarifying questions:
- What minimum “workflow link card” should appear in the conversation when a run starts?

### Gap: State-machining vs workflow — Winner: `AiWorkflowRun`

Objection:
- If `SapRun` also has status changes (`pending → running`), users may confuse it with workflow lifecycle.

Clarifying questions:
- Should `SapRun.status` be renamed or hidden in UI to avoid implying approval lifecycle?

---

## 4) Proposed Phase 1 “clarity-first” next steps (non-binding)

If the goal is “end-to-end functional loop” without UI bloat:

1. Implement explicit linking: conversation ↔ workflow run.
2. Implement PRD artifact persistence (`jsonb`) + render as a card + link to separate “artifact view” page.
3. Implement approval as “artifact-phase transition” (real DB transition) and broadcast state updates.
4. Implement backlog list page + link from Agent Hub, with backlog items linked to artifacts/runs.
5. Keep RAG static, but add visibility/logging about what context was included.
