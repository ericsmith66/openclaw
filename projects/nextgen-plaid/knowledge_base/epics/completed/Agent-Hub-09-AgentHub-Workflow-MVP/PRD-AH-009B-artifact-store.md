# PRD-AH-009B: Artifact Store (structured + `jsonb`) + SDLC Phases (MVP)

Source: `knowledge_base/epics/Agent-hub/vision-agent_hub-workflow.md` §11 → `PRD-MVP-02`.

---

## Problem

We need a durable unit of work that moves through SDLC phases independent of chat.

## User story

As the owner, I can create an artifact (PRD/idea/epic), store it durably, and see its current phase.

---

## A) What SAP/CWA produce (workflow output)

- SAP produces an **artifact payload** (e.g., PRD markdown) stored in the artifact.
- CWA produces updates to artifact phase during development (e.g., `in_development → ready_for_qa → complete`) and may attach implementation notes/results.

---

## B) What we build (platform/engineering work)

- New `artifacts` persistence model (structured columns + `payload jsonb`)
- Phase/state definition and validation
- Optional transition/audit storage

---

## C) UI elements introduced/changed

- Workflow UI (minimal) will need to be able to view/edit artifact payload and phase
- Agent Hub will later show an artifact link card (handled in PRD-AH-009C/009D)

---

## Functional requirements

- Create `artifacts` storage (structured columns + `jsonb` payload)
  - Structured fields: `name`, `artifact_type`, `phase`, timestamps
  - Unstructured: `payload` (`jsonb`) for artifact document content (markdown)
- Define a Phase 1 phase set (draft):
  - `backlog`, `ready_for_analysis`, `in_analysis`, `ready_for_development_feedback`, `ready_for_development`, `in_development`, `ready_for_qa`, `complete`

---

## Acceptance criteria

- AC1: An artifact can be created with `artifact_type=prd` and stored with markdown in `payload`.
- AC2: Artifact phase can be set to `backlog` and later moved out of backlog.
- AC3: Artifact phase is the SDLC source of truth.
