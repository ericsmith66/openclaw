# How to Use the Workflow (Human Guide)

This guide explains **how a human (Eric) should use the workflow** to coordinate the agents. It is the practical, step‑by‑step companion to `workflow.md` and `knowledge_base/epics/instructions/RULES.md`.

## Core Principle
The **human only jump‑starts or gates the process**. The **Coding Agent leads** and **delegates to Architect and QA** as part of the internal loop.

Five actors participate (see RULES.md Part 1):
- **Eric** — idea origination, approval, feedback responses, smoke test, merge/push/PR
- **High-Reasoning AI** (Grok, Claude, etc.) — epic drafting, PRD expansion, feedback synthesis (external tool, not an AiderDesk agent)
- **Architect Agent** — epic review, plan scoring
- **Coding Agent** — PRD breakout, implementation, testing, logging
- **QA Agent** — validation, scoring 0–100

## When You (Human) Act
You should run a command **only when it adds human value or starts a new phase**. Everything else happens inside the agent loop.

### Human‑Initiated Commands (Jump‑Start / Gate)
These are the only commands you should trigger:

1. **`/turn-idea-into-epic`** — RULES.md Φ1–Φ2
   - Convert a raw idea into an epic draft with atomic PRD summaries (2–3 sentences each).
   - The agent follows the epic template from RULES.md Φ2.
   - Output: structured epic draft with PRD summary table, goal, scope, non-goals.
   - **You then approve (Φ3)** — approve, tweak, or reject outside the command.

2. **`/get-feedback-on-epic`** — RULES.md Φ4–Φ6
   - First run: expands the approved epic into a full consolidated document (Φ4) with all PRD sections.
   - Then delegates to Architect for review (Φ5): Questions/Suggestions/Objections with solutions.
   - You + High-Reasoning AI respond to feedback (Φ6).
   - Repeat 1–3 cycles until Architect has no remaining objections.

3. **`/finalize-epic`** — RULES.md Φ7
   - Lock the epic for implementation.
   - Coding Agent reads all feedback/response docs and integrates locked-in decisions.
   - Creates: `0000-epic.md`, individual `PRD-*.md` files, `0001-IMPLEMENTATION-STATUS.md`.
   - Delegates to Architect for PRD implementation plan.
   - Commits all artifacts per commit policy.
   - Output: finalized epic + PRD files + implementation plan, committed.

4. **`/implement-prd`** — RULES.md Φ8–Φ12
   - Start implementation; the Coding Agent runs the Blueprint loop internally:
     - Φ8: Write implementation plan
     - Φ9: Architect reviews and approves (★ GATE)
     - Φ10: Implement code + tests (must follow approved plan)
     - Φ11: QA scores 0–100 (★ GATE — must get ≥ 90, max 3 tries)
     - Φ12: Task log + status update (byproducts)
   - If QA < 90 after 3 cycles → escalated to you.
   - Output: implemented changes, test results, QA score, updated logs/status.

All other actions are performed by agents inside the loop.

## Standard Flow (Human View)
```
1. /turn-idea-into-epic     → Draft epic (Φ1–Φ2)
2. [Approve or revise]      → Eric approval (Φ3)
3. /get-feedback-on-epic    → Expand + Architect review (Φ4–Φ6, repeat 1–3x)
4. /finalize-epic           → PRD breakout + plan (Φ7)
5. /implement-prd           → Build it (Φ8–Φ12)
6. [Smoke test + merge]     → Closeout (Φ13–Φ14)
```

## What Happens Inside the Agent Loop (You Don't Trigger These)
After `/finalize-epic`:
- **Architect** produces the PRD implementation plan (`/plan-epic`).

During `/implement-prd`:
- **Coding Agent** breaks PRDs into tasks (`/plan-prds`).
- **Architect** reviews the plan (`/architect-review-plan` → `PLAN-APPROVED` or `PLAN-REVISE`).
  - If `PLAN-REVISE` 3 times → escalate to Eric.
- **Coding Agent** implements code and tests following the approved plan.
- **QA Agent** scores 0–100 (`/qa-score`) using RULES.md Φ11 rubric.
- If QA < 90: **Debug Agent** triages (`/debug-triage`), then re-implement and re-score.
- **Coding Agent** logs tasks and updates status as byproducts.

## Notes & Conventions
- **Agent IDs** use template format (`ror-architect`, etc.); the sync script adds project suffixes at runtime.
- **Commit policy**: commit plans always; commit code when green (tests pass).
- **Testing**: Minitest is the default test framework.
- **Config source**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/` is the starting point for runtime sync.
- **RULES.md**: exists at `knowledge_base/epics/instructions/RULES.md` — all prompts reference it.

If this guide conflicts with `workflow.md` or `RULES.md`, **RULES.md wins** (see precedence in `workflow.md`).
