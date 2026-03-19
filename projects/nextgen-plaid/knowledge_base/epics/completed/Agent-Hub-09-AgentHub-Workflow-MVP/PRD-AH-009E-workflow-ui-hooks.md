# PRD-AH-009E: Minimal Workflow UI/Background Hooks (Coordinator + CWA) (MVP)

Source: `knowledge_base/epics/Agent-hub/vision-agent_hub-workflow.md` §11 → `PRD-MVP-05`.

---

## Problem

Execution happens outside Agent Hub; we still need a minimal loop to simulate/drive SDLC completion.

## User story

As the owner (and/or Coordinator), I can add a plan and mark artifacts through dev/QA phases; CWA can pick up “ready for development” items.

---

## A) What SAP/CWA produce (workflow output)

- Coordinator produces a plan (plan artifact or plan section in artifact payload).
- CWA produces code/work artifacts and marks phase progression during execution.

---

## B) What we build (platform/engineering work)

- Minimal workflow UI pages + endpoints
- Background hooks (if needed) to update phases and publish results back to the linked conversation

---

## C) UI elements introduced/changed

- Workflow UI: artifact list (by phase), artifact detail, phase transition controls
- Agent Hub: receives “status update” messages/cards from workflow execution (minimal)

---

## Functional requirements

- Minimal Workflow UI views:
  - list artifacts by phase
  - show artifact detail (payload)
  - set phase transitions (dev/qa/complete)
- Minimal “handoff to CWA” mechanism:
  - mark `ready_for_development`
  - show in a “CWA queue”

---

## Acceptance criteria

- AC1: Coordinator can attach a plan (either a plan artifact or plan section in payload).
- AC2: CWA can mark `in_development` → `ready_for_qa` → `complete`.
