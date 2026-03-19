# PRD-AH-009C: Conversation ↔ Workflow Object Linking (MVP)

Source: `knowledge_base/epics/Agent-hub/vision-agent_hub-workflow.md` §11 → `PRD-MVP-03`.

---

## Problem

Agent Hub must remain conversation-centric, but actions must operate on linked workflow objects.

## User story

As the owner, a conversation can be linked to a workflow run and an active artifact, and the link persists across persona tab switches.

---

## A) What SAP/CWA produce (workflow output)

- SAP/CWA do not “produce” linking; they rely on it.
- Their output benefits from it: conversation context stays attached to the correct artifact/run across persona tab navigation.

---

## B) What we build (platform/engineering work)

- Add/define linking fields (conversation ↔ workflow run ↔ artifact IDs)
- Ensure link persistence across persona tab switches
- Add deep links to Workflow UI

---

## C) UI elements introduced/changed

- Agent Hub: minimal **artifact link card** displayed in the conversation view
- Workflow UI: artifact detail page that can be linked to

---

## Functional requirements

- Add linking fields to conversations (via `metadata` or explicit columns):
  - `ai_workflow_run_id` (optional)
  - `active_artifact_id`
  - `linked_artifact_ids[]`
- Display a minimal “link card” in Agent Hub showing:
  - current artifact ID + name + phase
  - link to Workflow UI view

---

## Acceptance criteria

- AC1: Switching persona tabs does not lose the active conversation’s `active_artifact_id`.
- AC2: The conversation shows the active artifact phase.
