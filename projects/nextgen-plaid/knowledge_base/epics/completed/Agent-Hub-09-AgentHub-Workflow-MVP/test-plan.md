# Epic 9 Test Plan — Agent Hub + Workflow MVP (Phase 1)

Source: `knowledge_base/epics/Agent-hub/vision-agent_hub-workflow.md` §11.3.

This is the post-epic validation suite. These are **test cases**, not implementation work.

---

## A) Six post-epic test cases

System readiness:

1. Proxy server health
2. Worker health + code/version consistency
3. Cloudflare availability

SDLC loop:

4. Artifact SDLC happy path
5. Loop-back + re-approval
6. Linking integrity across persona tab switches

---

## B) Role-based workflow test script (Human + personas)

Assumptions:

- Conversations are created/selected in Agent Hub.
- A conversation is linked to an active artifact (PRD).
- Phase transitions are executed via status movers (e.g., `/approve`) and reflected in Workflow UI.

### Test A — “Create PRD with SAP” (Human + SAP)

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

### Test B — “SAP incorporates feedback and uses the template” (Human + SAP)

Steps:

1. (Human) Provide feedback on the PRD (missing ACs, unclear scope, edge cases).
2. (SAP) Update the PRD artifact payload to match the PRD template expectations.

Expected results:

- PRD artifact payload is updated (versioning/audit recorded if implemented).
- PRD remains linked to the same conversation.
- Changes are visible in Workflow UI artifact detail view.

### Test C — “Human approval advances phase” (Human)

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

### Test D — “Coordinator review and questions (loop-back)” (Coordinator + SAP)

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

### Test E — “Ready for development → Coordinator plan → handoff to CWA” (Coordinator + CWA)

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

### Test F — “System readiness checks” (Human)

Steps:

1. (Human) Open the Admin System Health page.

Expected results:

- Proxy health check returns OK or actionable failure.
- Worker health shows workers alive and matching code version with web.
- Cloudflare endpoint checks return OK or actionable failure.
- (Optional) artifact counts by phase and recent transitions are visible.
