# PRD-AH-009D: Status Movers + Phase Transitions (MVP)

Source: `knowledge_base/epics/Agent-hub/vision-agent_hub-workflow.md` §11 → `PRD-MVP-04`.

---

## Problem

We need repeatable phase transitions and loop-back re-approval (SAP ⇄ Coordinator ⇢ ready for dev ⇢ CWA ⇢ QA ⇢ complete).

## User story

As the owner, I can use simple actions in Agent Hub to move an artifact through phases, including sending it back to SAP for revision and requiring re-approval.

---

## A) What SAP/CWA produce (workflow output)

- SAP produces revisions to artifacts when routed back (and re-approval readiness).
- CWA produces implementation progress updates reflected by phase changes.

---

## B) What we build (platform/engineering work)

- Status mover commands and confirmation UX
- Phase transition rules (minimal, deterministic)
- Audit trail of transitions (actor, from/to, timestamps)
- Routing metadata (e.g., “assigned to SAP/Coordinator/CWA”)

---

## C) UI elements introduced/changed

- Agent Hub: confirmation bubble/actions for `/approve`, `/reject`, `/backlog`, routing
- Agent Hub: visible “current phase/assignment” (via link card or small badge)

---

## Functional requirements

- `/approve` transitions an artifact to the next phase (or next owner) and records audit.
- `/reject` transitions to a prior phase (or a defined rework phase) and records audit.
- `/backlog` sets phase to `backlog`.
- “move to SAP” (or equivalent) routes the artifact back to SAP for revisions.
- Audit events are recorded (table or `jsonb` log) with:
  - from_phase, to_phase
  - action
  - actor (user + persona)
  - artifact version/hash (if available)

---

## Acceptance criteria

- AC1: Loop-back works: SAP → approve → Coordinator feedback → back to SAP → approve again.
- AC2: Phase transitions are persisted and visible.
