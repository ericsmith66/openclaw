### Gap → Epic/PRD mapping (Agent Hub as the interface for Agent-06 / CWA)

**Terminology used in this doc:**

- **Persona**: the agent identity (e.g., SAP / Conductor / CWA).
- **Persona tab**: the UI tab you click to view/route messages as a persona.
- **Conversation**: a persisted conversation thread (currently `SapRun`).
- **Workflow run**: a workflow lifecycle object (currently `AiWorkflowRun`).

| Gap | What you’re experiencing (EAS) | Likely Epic/PRD owner | Evidence in code today | Why it blocks Agent-06 interface | What “done” looks like (minimum)| winner                                                                                                                                                                   
|---|---|---|---|---|---|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Split container model (`SapRun` vs `AiWorkflowRun`) | Confusing lifecycle: conversations work, but “workflow” actions don’t | Epic 7 (Lifecycle) + overall architecture decision | `SapRun` + `SapMessage` used for chat (`app/models/sap_run.rb`, `app/channels/agent_hub_channel.rb`); approvals/state machine on `AiWorkflowRun` (`app/models/ai_workflow_run.rb`) | Agent-06 needs one traceable object: generate PRD → review → approve → handoff → implement | Pick canonical container and link everything to it (either make Agent Hub run-centric or create a “workflow artifact” linked to conversation)| Aiworkflowrunner wins we dont want to bundle the workflow into chat                                                                                                      |
| “No meaningful RAG” | Context doesn’t feel relevant or adaptive | RAG refactor (not Epic 6; called out as future) | `SapAgent::RagProvider` is snapshot + static docs, truncated (`app/services/sap_agent/rag_provider.rb`) | Agent-06 PRD drafting needs reliable, *query-relevant* retrieval from repo/knowledge | Add retrieval step (embeddings + top-k snippets) and show “sources used” in UI/logs| Use static rag now and [eric_grok_static_rag.md](../../static_docs/eric_grok_static_rag.md) that will be good enough for end to end testing then refactor rag generation |
| Backlog feels missing | `/backlog` either not usable or not discoverable in UI | Epic 7 (Backlog persistence) | Backlog DB exists (`BacklogItem` + migration) and service exists (`AgentHub::BacklogService`) | Without a backlog UI and linkage, it’s not an operational queue for Agent-06 | Add Backlog tab/view + link backlog items to run/conversation in `metadata` + ability to open item| Add back log view on seperate page no more bloat on agent hub . Agent should be aware of the backlog - send to backlog and get from backlog and list backlog             |
| Can’t generate a PRD | No command/output pipeline for PRD artifacts | Epic 6 “Structured outputs” (not done) + Epic 7 artifact persistence | No clear PRD artifact model + no PRD rendering cards (not found in the Agent Hub stream) | Agent-06’s core output is PRDs; without a durable artifact you can’t review/approve/handoff | Add “PRD artifact” creation (persist markdown), render as a card, allow export/save|Agree but we also need handle epics might be a table with jsonb document to store the artifact |
| Can’t test approvals | Confirmation bubbles exist but nothing transitions | Epic 7 (Human-in-loop approvals) | Confirmation UI exists (`/approve` etc) but no clear binding to a record transition; `AiWorkflowRun` has transitions | Approvals must change state in DB and update UI; otherwise it’s UI-only | Wire confirmation click → server action → `AiWorkflowRun#approve!` (or artifact approval) → broadcast sidebar update| agree but down stream agents need to be able to ask questions and collaborate with agents and humans|
| Workflow between SAP / Conductor / CWA is functional, but semantics unclear | Routing works, but storage/thread ownership feels ambiguous | Epic 8 (mentions/routing) + architectural decision | Mentions are parsed and routed in `AgentHubChannel#speak` | Agent-06 needs traceability across personas; ambiguous storage breaks audit trail | Decide: “routing affects responder; storage follows active thread/run” and encode it in UI + DB| storage follows active conversation (not persona tab)|
| Chatwoot/`ai-agents` not tied in | Agent Hub doesn’t feel like the UI for the workflow engine | Agent-05/06 work + Epic 7 integration | `ai-agents` configured and CWA registered (`config/initializers/ai_agents.rb`), but Agent Hub uses its own ActionCable + SmartProxy loop | If Agent Hub doesn’t drive `ai-agents`, you won’t see tool traces, step logs, or workflow artifacts as runs | Either wire Agent Hub to execute `Agents::Registry.fetch(:cwa)` per run, or explicitly keep them separate| workflow UI is seperate Agent-hub is the collaboration - a conversation can have links to the workflow UI but not man utilitu for administring workflow )|
| State-machining vs workflow | Unsure if duplication conflicts | Architecture decision | `AiWorkflowRun` state machine + `SapRun.status` enum | Two status systems can diverge and confuse “what is approved/ready” | Define ownership: `AiWorkflowRun.status` for approvals; `SapRun.status` for chat runtime (or collapse into one)| AiWorkflowRun Wins|

---

### Consolidated decision questions you must answer (with recommendation, pros/cons, consequences)

#### 1) What is the **canonical container** in Agent Hub?
**Question:** Is Agent Hub fundamentally a UI around `AiWorkflowRun` (workflow runs), or around `SapRun` (conversations)?| (EAS)  neither its the human interaction with the agents tooling and non conversational administration should be on other pages . Agent has actions or can point to the other UIs

**Recommendation:** Make Agent Hub **run-centric** (`AiWorkflowRun`) and treat conversation messages as part of a run (or link `SapRun` 1:1 to `AiWorkflowRun`).

**Pros:**
- Aligns with approvals, lifecycle, audit, handoff, artifacts.
- Natural fit for Agent-06 (CWA) workflows (PRD → implement).

**Cons:**
- Requires refactor of current conversation-first UI.
- Requires decisions on how to store “chat history” inside a run.

**Consequences if you don’t decide:**
- You’ll keep building features twice (once in `SapRun`, once in `AiWorkflowRun`) and “approve/generate PRD” will remain hard to make real. (EAS) we only build action bubbles we dont embed workflow in the UI tool. More akin to an evite. I have a thing an invitation and I can workflow it approve , reject, route. they are not inhernite in the interface but the object being workflowed  .

---

#### 2) How should **persona routing** relate to **persistence**?
**Question:** When Conductor mentions `@SAP`, do we save the messages under Conductor’s active thread/run, or under SAP’s? (eas) it follows the conversation not the persona tab. one conversation could persist on two more than one tab 

**Recommendation:** Save under the **active thread/run** (the one the user is “in”), but label responses with the responder persona. (eas) agree

**Pros:**
- User sees one continuous workflow thread.
- Preserves “what I was doing” context and audit trail.

**Cons:**
- SAP persona’s own conversation list won’t contain those messages unless you cross-link.

**Consequences if you save under target persona instead:**
- Users will experience “messages disappear into another tab/thread” and it becomes hard to review/approve in one place.

---

#### 3) What is the **artifact model** for PRDs and outputs?
**Question:** Where does a generated PRD live (DB table? file in repo? both)? (eas) DB table in a document store like jsonb. fielded but not structured ( think mongodb like ) . With structured fields to manage state . another queston how are epics stored ? PRDs are still evolving but db is better than files system . Also feel like they should not be in a development database or production but there own db. 

**Recommendation:** Store PRD markdown in DB as an **Artifact** linked to the canonical run, then optionally allow “export to file” for committing.

**Pros:**
- Enables review/approve UX without Git operations.
- Supports audit, versions, approvals, status.

**Cons:**
- Requires a new model + UI rendering.

**Consequences if PRDs are only files:**
- Approval UX becomes “out of band” (Git-driven), harder to test in Agent Hub.

---

#### 4) What does “approval” approve? (eas) an artifact is approved for a phase transition, I send the PRD to Coordinator but the artafact is only approved for the phase that its in. eventually it gets to a termianl state ( PRD is finished or chosen not to implement but it can go forward an back to diffent phases under review ready for dev etc ) Versioning is inporate but can be incorporated into the document store. ( mongodb like ) 
**Question:** Are you approving:
- a PRD artifact,
- an `AiWorkflowRun` status,
- or a code-change plan?

**Recommendation:** Approve a **specific artifact version** (e.g., PRD v3) and have that drive `AiWorkflowRun.status`.

**Pros:**
- Clear audit trail: what was approved.
- Enables re-approval after edits.

**Cons:**
- More modeling work (artifact versions).

**Consequences if you approve only the run:**
- Ambiguity: what exactly was approved (content may change after approval).

---

#### 5) What is the backlog’s role in Agent-06 workflows?
**Question:** Is backlog a “todo list”, an “artifact inbox”, or a “handoff queue”?. (EAS) Its a stash for uncompletd work. good ideas underdeveloped or bad ideas , or YAGNI 

**Recommendation:** Treat backlog as a **handoff queue** with strong linkage to run/artifact IDs.

**Pros:**
- Backlog becomes actionable (open item → resume run).

**Cons:**
- Needs UI and navigation.

**Consequences if backlog is only a DB sink:**
- `/backlog` will continue to feel like it “does nothing” operationally.

---

#### 6) What is “meaningful RAG” for your target? (eas) we start with a static rag until we have finished agent_hub then its the next epic . rag is about fine tunning. 
**Question:** Do you want RAG over:
- `knowledge_base/**` only,
- the Rails codebase,
- or both?

**Recommendation:** Start with curated `knowledge_base/**` + a small set of architectural code files, then expand.

**Pros:**
- Higher relevance, less noise, faster.

**Cons:**
- Requires curation and indexing.

**Consequences if you keep static prefix only:**
- PRDs will remain generic and miss repo-specific details.

---

#### 7) Should Agent Hub be the UI for `ai-agents` (Chatwoot SDK) or a separate chat system? (eas) I dont know . agent-hub is about collaboration workflow is a separate thing.
**Question:** Do you want Agent Hub to execute the same engine used by Chatwoot workflows?

**Recommendation:** Yes—Agent Hub should become a **first-class UI for `ai-agents` runs**, at least for Agent-06/CWA.

**Pros:**
- Unified traces, tools, workflow state.
- Easier to reason about “what ran” and why.

**Cons:**
- Integration work: drive `Agents::Registry.fetch(:cwa)` and stream outputs.

**Consequences if kept separate:**
- You’ll maintain two “agent systems” and never get full visibility/traces in one place.

---

#### 8) How do you want state machines to coexist?
**Question:** Do we keep both `SapRun.status` and `AiWorkflowRun.status`? (eas) I did not choose to bring it in so we need to figure out if its helping or adding yet another workflow engine

**Recommendation:** Keep both only if they represent different layers:
- `SapRun.status` = chat execution lifecycle
- `AiWorkflowRun.status` = human approval lifecycle

**Pros:**
- Cleaner separation of concerns.

**Cons:**
- Needs careful UI labels to avoid confusion.

**Consequences if both represent “approval readiness”:**
- You’ll get contradictions (“chat says running but workflow says approved”).

---

### Next step (if you want me to continue)
If you tell me your answers for Questions 1, 2, 3, and 4, I can propose a concrete “Phase 1 build-out” that makes Agent Hub genuinely functional for Agent-06 (with a minimal acceptance-test checklist matching the epics/PRDs).