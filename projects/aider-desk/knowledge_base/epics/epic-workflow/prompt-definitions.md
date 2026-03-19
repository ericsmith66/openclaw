# Prompt Definitions (Workflow Commands)

This document lists the **exact prompt text** to be used for each workflow command. It aligns with the four **human‑run** commands and the **agent‑internal** steps delegated by the Coding Agent.

These prompts are the **source** for the actual AiderDesk command `.md` files in `ror-agent-config/commands/`. Each human command must have a corresponding command file created from these definitions.

All prompts reference `knowledge_base/epics/instructions/RULES.md` as the authoritative source for phases, rubrics, templates, naming conventions, and anti-patterns.

---

## Human‑Run Commands (Only These Are Triggered by the Human)

### `/turn-idea-into-epic` — RULES.md Φ1–Φ2
**Command file**: `ror-agent-config/commands/turn-idea-into-epic.md` (TO CREATE)
```
ROLE: Coding Agent (lead)
GOAL: Convert a raw idea into a structured epic draft with atomic PRD summaries.

RULES.md PHASES: Φ1 (Idea) → Φ2 (Epic Drafting)

INSTRUCTIONS:
- Read the provided idea (Φ1 — any format accepted).
- Produce a structured epic draft following RULES.md Φ2 rules:
  - Each PRD summary is 2–3 sentences maximum — define WHAT, not HOW.
  - PRDs must be atomic — independently implementable and testable.
  - Include a PRD summary table with columns: #, Title, Summary.
  - Include epic goal, scope, and non-goals (even if rough).
  - Do NOT expand PRDs into full detail (that happens in Φ4).
  - Do NOT create individual PRD files (that happens in Φ7).
- Reference the epic template: `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md` (structure reference only).
- Produce a PRD summary as part of the epic output.
- Identify missing inputs, dependencies, risks, and assumptions.
- If critical info is missing, list explicit questions under "Open Questions."

OUTPUT:
- A complete epic draft ready for Eric approval (Φ3) and then Architect feedback (Φ5).
```

### `/get-feedback-on-epic` — RULES.md Φ4–Φ6
**Command file**: `ror-agent-config/commands/get-feedback-on-epic.md` (TO CREATE)
```
ROLE: Coding Agent (lead) + Architect sub‑agent
GOAL: Expand the epic into a full consolidated document and collect Architect feedback.

RULES.md PHASES: Φ4 (Full Expansion) → Φ5 (Architect Review) → Φ6 (Feedback Response)

INSTRUCTIONS:
- If the epic has not been fully expanded yet (Φ4):
  - Expand into a single consolidated document — epic overview + all fully detailed PRDs.
  - Each PRD section must include all sections from the PRD template (RULES.md Φ4 rule 2):
    Overview, User Story, Functional Requirements, Non-Functional Requirements,
    Architectural Context, Acceptance Criteria, Test Cases,
    Manual Testing Steps, Dependencies (Blocked By / Blocks), Error Scenarios & Fallbacks.
  - Acceptance criteria must be specific and testable (RULES.md Φ4 rule 3).
  - Reference the PRD template: `knowledge_base/templates/PRD-template.md`.
- Delegate to Architect (ror-architect) for review (Φ5):
  - Architect must organize feedback as Questions / Suggestions / Objections.
  - Every objection MUST include a potential solution (RULES.md Φ5 rule 2).
  - Review the PRDs embedded in the epic as part of the feedback.
  - Feedback filename: `{epic-name}-feedback-V{N}.md` in `feedback/` subfolder.
- Return consolidated feedback with clear revisions.
- Eric + High-Reasoning AI respond to feedback (Φ6).
- Repeat Φ5 → Φ6 until no remaining objections. Maximum 3 cycles (RULES.md Φ6 rule 5).

OUTPUT:
- Architect feedback document
- Required revisions (if any)
- Updated consolidated epic if revisions are straightforward
```

### `/finalize-epic` — RULES.md Φ7
**Command file**: `ror-agent-config/commands/finalize-epic.md` (TO CREATE)
```
ROLE: Coding Agent (lead) + Architect sub‑agent
GOAL: Break out PRD files, update the epic, and prepare for implementation.

RULES.md PHASE: Φ7 (PRD Breakout + Epic Update)

INSTRUCTIONS:
- Read ALL feedback/response documents before starting — integrate locked-in decisions (RULES.md Φ7 rule 1).
- Update `0000-epic.md` with:
  - "Key Decisions Locked In" section incorporating all resolved feedback.
  - Updated PRD summary table with status = "Not Started".
- Create individual PRD files following naming convention (RULES.md Part 3):
  - Pattern: `PRD-{epic-id}-{seq}-{slug}.md`
  - No spaces. Lowercase kebab-case. Sequential numbering: 01, 02, 03...
  - Each PRD must be self-contained.
  - Each PRD must follow the template: `knowledge_base/templates/PRD-template.md`.
- Create `0001-IMPLEMENTATION-STATUS.md` from template:
  - `knowledge_base/templates/0001-IMPLEMENTATION-STATUS-template.md`
  - All PRDs listed as "Not Started".
- Delegate to Architect (ror-architect) to produce the PRD implementation plan (/plan-epic).
- Commit the finalized epic, PRDs, status tracker, and plan per commit policy (commit plans always).
- Follow the directory structure defined in RULES.md Φ7.

OUTPUT:
- Finalized `0000-epic.md`
- Individual `PRD-*.md` files
- `0001-IMPLEMENTATION-STATUS.md`
- PRD implementation plan (produced by Architect)
- All committed
```

### `/implement-prd` — RULES.md Φ8–Φ12
**Command file**: `ror-agent-config/commands/implement-prd.md` (TO UPDATE)
```
ROLE: Coding Agent (lead) + Architect/QA sub‑agents
GOAL: Implement the approved PRD plan using the Blueprint inner loop.

RULES.md PHASES: Φ8 (Plan) → Φ9 (Architect Gate) → Φ10 (Implementation) → Φ11 (QA Gate) → Φ12 (Logging)

INSTRUCTIONS:
- Locate the **approved PRD plan** created after epic finalization.
- **Adhere strictly to the approved PRD plan** for implementation steps.
- Run the internal Blueprint loop:

  Φ8 — PLAN:
  - Write implementation plan covering: file-by-file changes, dependency order, test strategy, risks, complexity (RULES.md Φ8).
  - Plan must reference specific PRD acceptance criteria.
  - Store as: `{epic-dir}/implementation-plan.md`.

  Φ9 — APPROVE (★ ARCHITECT GATE):
  - Delegate to Architect (ror-architect) for plan review (/architect-review-plan).
  - Architect scores against rubric: Completeness 25%, Architecture Alignment 25%, Risk Awareness 20%, Test Strategy 15%, Dependency Ordering 15% (RULES.md Φ9).
  - If PLAN-REVISE, update plan and re-submit. If 3 revisions → escalate to Eric.

  Φ10 — CODE:
  - Follow the architect-approved plan — do not deviate without documenting why.
  - Write tests alongside code — not after.
  - Use Minitest (never RSpec unless explicitly requested).
  - All code must be green before moving to QA.

  Φ11 — SCORE (★ QUALITY GATE):
  - Delegate to QA (ror-qa) for scoring (/qa-score).
  - QA rubric: Acceptance Criteria 30, Test Coverage 30, Code Quality 20, Plan Adherence 20 (RULES.md Φ11).
  - ≥ 90 → Pass. < 90 → Fail, kicked back to CODE.
  - If < 90, delegate to Debug Agent (ror-debug) for triage (/debug-triage), then remediate and re-score.
  - Maximum 3 QA cycles. If still < 90 → escalate to Eric.

  Φ12 — LOG:
  - Create task log at `knowledge_base/prds-junie-log/YYYY-MM-DD__task-slug.md` (RULES.md Φ12).
  - Update `0001-IMPLEMENTATION-STATUS.md`: PRD status, QA score, branch, date, deviations.

- Follow commit policy: **commit plans always; commit code when green (tests pass)**.

OUTPUT:
- Implemented changes per PRD plan
- Test results and QA score (with per-criteria breakdown)
- Task log entry and updated implementation status
```

---

## Agent‑Internal Commands (Invoked by the Coding Agent — Never by the Human)

### `/plan-epic` (Architect‑run, after `/finalize-epic`) — RULES.md Φ8–Φ9
**Invocation**: delegated from `/finalize-epic` to `ror-architect`
```
ROLE: Architect
GOAL: Produce the PRD‑level implementation plan required by `/implement-prd`.

INSTRUCTIONS:
- Run only after the epic is finalized (Φ7 complete).
- Produce a step‑by‑step implementation plan aligned to RULES.md Φ8.
- Cover: file-by-file changes, dependency order, test strategy, risks, complexity.
- Reference specific PRD acceptance criteria.
- Score against the Φ9 rubric (self-review).

OUTPUT:
- Approved PRD plan for implementation
- Stored as: `{epic-dir}/implementation-plan.md`
```

### `/plan-prds` (inside `/implement-prd`)
**Invocation**: run by Coding Agent within `/implement-prd`
```
ROLE: Coding Agent (lead)
GOAL: Break approved PRDs into executable implementation steps.

INSTRUCTIONS:
- Use the finalized epic and approved PRD plan as input.
- Produce a task‑level plan that the implementation will follow.
- Keep steps small enough to execute in sequence with verification.
- Reference PRD acceptance criteria as definition of done per step.

OUTPUT:
- PRD task breakdown and execution sequence
```

### `/architect-review-plan` — RULES.md Φ9
**Invocation**: delegated from Coding Agent to `ror-architect` during `/implement-prd`
```
ROLE: Architect
GOAL: Gate the implementation plan using RULES.md Φ9 rubric.

INSTRUCTIONS:
- Review against rubric: Completeness 25%, Architecture Alignment 25%, Risk Awareness 20%, Test Strategy 15%, Dependency Ordering 15%.
- May modify the plan (reorder steps, add considerations, flag risks).
- Respond with one of:
  - PLAN-APPROVED
  - PLAN-REVISE (with exact fixes and solutions)
- Store review as: `{epic-dir}/feedback/plan-review.md`.

OUTPUT:
- PLAN-APPROVED or PLAN-REVISE with required changes
```

### `/qa-score` — RULES.md Φ11
**Invocation**: delegated from Coding Agent to `ror-qa` during `/implement-prd`
```
ROLE: QA Agent
GOAL: Score the implementation 0–100 using the RULES.md Φ11 rubric.

INSTRUCTIONS:
- Apply rubric: Acceptance Criteria Compliance 30, Test Coverage 30, Code Quality 20, Plan Adherence 20.
- Use Minitest as the test framework.
- ≥ 90 → Pass. < 90 → Fail.
- On failure, provide:
  - Exact score with per-criteria breakdown.
  - Which acceptance criteria are unmet.
  - Which test coverage gaps exist.
  - Specific remediation steps.
- Store QA report as: `{epic-dir}/feedback/qa-report.md`.

OUTPUT:
- QA score with per-criteria breakdown
- Pass/fail status
- Remediation steps if < 90
```

### `/debug-triage`
**Invocation**: delegated from Coding Agent to `ror-debug` when QA < 90
```
ROLE: Debug Agent
GOAL: Reproduce issues, isolate root cause, and propose a minimal fix plan.

INSTRUCTIONS:
- Reproduce the issue (steps + expected/actual).
- Identify root cause with evidence.
- Propose the minimal fix plan and exact tests to run.

OUTPUT:
- Reproduction steps
- Root cause
- Minimal fix plan
- Verification test list
```

### `/log-task` — RULES.md Φ12
**Invocation**: run by Coding Agent as byproduct of `/implement-prd`
```
ROLE: Coding Agent (lead)
GOAL: Append a task summary to the task log as a byproduct of implementation.

INSTRUCTIONS:
- Follow template: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`.
- Must include: Goal, Context, Plan, Work Log, Files Changed, Commands Run, Tests, Decisions, Manual Verification Steps, Outcome.
- Record PRD/epic reference, plan version, tests run, QA score, and status.

OUTPUT:
- Task log entry at `knowledge_base/prds-junie-log/YYYY-MM-DD__task-slug.md`
```

### `/update-implementation-status` — RULES.md Φ12
**Invocation**: run by Coding Agent as byproduct of `/implement-prd`
```
ROLE: Coding Agent (lead)
GOAL: Update the implementation status tracker as a byproduct of implementation.

INSTRUCTIONS:
- Update `0001-IMPLEMENTATION-STATUS.md`:
  - PRD status → Implemented
  - Record QA score
  - Record branch name, completion date
  - Note any deviations from plan with rationale

OUTPUT:
- Updated `0001-IMPLEMENTATION-STATUS.md`
```
