# Agent Hub — End-to-End (Happy Path) Manual Test

This document is a **full lifecycle happy-path manual test** for the Agent Hub, intended to exercise the major user-facing behaviors described across the Agent Hub epics and PRDs under `knowledge_base/epics/Agent-hub/**`.

It is written as:

1. **Setup / prerequisites**
2. **A single “golden path” run** that touches the key capabilities end-to-end
3. **Verification checkpoints** (UI + logs + DB)
4. **Debug / interrogation tools** (PRD-AH-002C)

---

## 0) Prerequisites

### Accounts / Auth

1. You must be able to sign in as the **owner** (owner-only feature).
   - `ENV["OWNER_EMAIL"]` must match your login email.

### Services

1. Start the full dev stack:

```bash
bin/dev
```

Expected results:

- Rails server is listening (typically `http://0.0.0.0:3000`).
- Smart proxy is running (in this repo it typically binds on `http://0.0.0.0:3002`).

### Browser

- Use Chrome for the debugging steps (DevTools tooling is best).
- Open DevTools → **Network** tab → check **Disable cache** during debugging sessions.

---

## 1) Golden Path: Full Lifecycle Test

### Step 1 — Load Agent Hub (base scaffold + auth)

1. Navigate to:

```
/agent_hub
```

Expected UI results:

- If not authenticated, you are redirected to sign-in.
- If authenticated as owner, you see the Agent Hub layout.
- Persona tabs are visible (e.g., `SAP`, `Conductor`, `CWA`, `AiFinancialAdvisor`, `Workflow Monitor`, `Debug`).

Expected server results:

- Rails log includes an `agent_hub_persona_switch` JSON event with:
  - `persona_id`
  - `conversation_id` (may be `null` if none exist yet for that persona)
  - `conversations_count`

---

### Step 2 — Create a conversation for a persona (PRD-AH-008E)

This validates that each persona can have its own conversation list.

1. Click the **SAP** tab.
2. Click **New Conversation**.

Expected UI results:

- The page reloads to include a `conversation_id` param (e.g. `?persona_id=sap&conversation_id=123`).
- The sidebar shows the new conversation (title initially `New Conversation`).
- The conversation shows a **red `!` badge** while it is in `pending` status (expected).
- Chat pane is empty.

Expected DB results:

- A `SapRun` row is created.
- Its `correlation_id` matches:

```
agent-hub-{persona_id}-{user_id}-{uuid}
```

- `title` is `New Conversation`.
- `status` is `pending`.
- `conversation_type` is `single_persona`.

Optional DB check:

```bash
bin/rails runner 'u=User.find_by(email: ENV["OWNER_EMAIL"] || "ericsmith66@me.com"); r=SapRun.where(user_id: u.id).order(created_at: :desc).first; puts({id:r.id, title:r.title, status:r.status, correlation_id:r.correlation_id}.inspect)'
```

---

### Step 3 — Send the first message (streaming + persistence)

1. In the input bar, enter:

```
Hello SAP. Please summarize what Agent Hub does in one sentence.
```

2. Click **Send**.

Expected UI results:

- Your message appears immediately in a “You” bubble.
- A typing indicator appears (“Agent is thinking…”).
- A streamed response appears in an assistant bubble.

Expected server/log results:

- Rails log event `agent_hub_message_received` includes:
  - `agent_id: "sap-agent"`
  - `content` matching the prompt
  - `conversation_id` matching the active conversation
- Rails log lines:
  - `[handle_chat] Received conversation_id: <ID>, user_id: <owner_id>`
  - `[handle_chat] Using sap_run_id: <same ID>`

Expected DB results:

- Two `SapMessage` rows are created under the conversation:
  - `role: user` with your prompt
  - `role: assistant` with the response
- The `SapRun` status transitions `pending → running`.
- The red `!` badge disappears after the first send (because status is no longer `pending`). EAS - Fails 
- The conversation title auto-updates to the first ~50 chars of the first user message (truncate with `...`). ( EAS Fails) 

---

### Step 4 — Create a second conversation (isolation)

1. Click **New Conversation** again.
2. Send:

```
In this thread, only answer with the word "OK".
```

Expected UI results:

- Sidebar now shows **two** conversations.
- The newest conversation becomes active.
- The second conversation’s content is isolated (you should not see the SAP summary from the first conversation).

Expected DB results:

- A second `SapRun` exists for `persona_id=sap`.
- Messages sent in conversation 2 have `sap_run_id = conversation_2.id`.

---

### Step 5 — Switch back and forth between conversations

1. Click conversation 1 in the sidebar.
2. Confirm the SAP summary messages appear.
3. Click conversation 2.
4. Confirm only the “OK” thread messages appear.

Expected results:

- Switching shows correct message history for each conversation.
- No cross-contamination between message histories.
- Switching is effectively instantaneous.

---

### Step 6 — Persona isolation

1. Switch to the **Conductor** tab.
2. Click **New Conversation**.
3. Send:

```
@SAP Please answer: What is the density of iron?
```

Expected results (UI):

- The Conductor tab remains the active tab.
- The response should appear in the current chat pane (per mention routing behavior).

Expected results (logs):

- Rails logs show `mention_detected` with `target_agent_id: "sap-agent"`. (EAS Fails) 
- The chat request is routed appropriately.

Expected results (DB):

- Messages are still saved under the **current active conversation** (the Conductor conversation) unless your implementation explicitly stores by target agent. The key correctness requirement is:
  - the `SapMessage.sap_run_id` matches the active conversation you are viewing/using.

---

### Step 7 — Smart commands happy path (PRD-AH-005*)

In any non-Workflow-Monitor persona conversation:

1. Type:

```
/backlog Follow up on density answer with sources
```

2. Press Enter.

Expected UI results:

- The command is recognized.
- You receive a confirmation token message indicating backlog item creation (or an error token if it fails).

Expected server results:

- Rails logs show command parsing/handling events.

---

### Step 8 — Upload a file (PRD-AH-008C)

In an active conversation (not `Workflow Monitor`):

1. Click the upload icon.
2. Select a small text file (e.g., `sample.txt`).
3. Send a message:

```
Please read the attached file and summarize it.
```

Expected UI results:

- File badge(s) appear before sending.
- After sending, message bubble shows attachment link(s).

Expected server results:

- Upload request succeeds (HTTP 200/201) and returns attachment metadata.
- The message send includes `attachment_ids`.

---

### Step 9 — Workflow Monitor is read-only (PRD-AH-008A)

1. Click the **Workflow Monitor** tab.

Expected UI results:

- The page indicates read-only mode.
- The input bar is not rendered.

Expected behavior:

- No ability to send messages.

---

### Step 10 — Archive a conversation (PRD-AH-008E)

1. Hover a conversation in the sidebar.
2. Click the archive/trash icon.
3. Confirm.

Expected UI results:

- The conversation disappears from the sidebar.

Expected DB results:

- The conversation `SapRun.status` becomes `aborted`.
- The conversation is excluded from active conversation list.

---

## 2) Debug / Interrogation (PRD-AH-002C)

Use this when you suspect a mismatch between browser state and server behavior.

### A) Confirm Stimulus sees the conversation id

In DevTools Console:

```js
const el = document.querySelector('[data-controller="input-bar"]')
el?.getAttribute('data-input-bar-run-id-value')
```

Expected:

- When a conversation exists and is active: returns a numeric string like `"123"`.
- If you are on a persona with **no conversations yet**: attribute may be missing; then `null` is expected.

### B) Confirm ActionCable payload contains `conversation_id`

In Rails logs, look for:

- `{"event":"agent_hub_message_received", ... "conversation_id": <ID> }`
- `[handle_chat] Received conversation_id: <ID>`
- `[handle_chat] Using sap_run_id: <ID>`

If `conversation_id` is `null`, the server will fall back to legacy correlation-id behavior.

---

## 3) Pass/Fail Summary Checklist

Mark the run **PASS** only if all are true:

- You can create multiple conversations per persona.
- Messages are saved to the correct conversation (`SapMessage.sap_run_id` matches the active conversation).
- Switching conversations shows correct isolated history.
- Persona tabs isolate conversation lists.
- Mentions route responses without breaking the active conversation association.
- Workflow Monitor is read-only.
- Archiving removes conversation from the active list and marks status `aborted`.

---

## 4) Notes

- Some behaviors may be “implemented but still evolving” depending on which PRDs have been fully delivered. This doc is intentionally written as a **happy path**; edge cases and negative testing should be documented separately.


- EAS findings 
- it does not look like any meaningful rag has been implement 
- it does not look like there is any backlog functionality 
- we cant generate a prd 
- cant test if we can approve anything 
- workflow between SAP / Conductor /CWA is functional 
- Can your review the Agent-hub and see if thie was overlooked and is not yet implemented
- It does not seem like chat/woot is tied into the agent hub hi
- It looks like we implement state-maching does that complement or is in contradiction to the exsisting workflow 