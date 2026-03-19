
# BLUEPRINT WORKFLOW & SCORING DIRECTIVE

You must follow the Blueprint Workflow for all implementation tasks.

## 0. PLAN TYPES & OWNERSHIP
Two types of plans exist. Know which you are creating:

| Plan | Owner | Filename | Purpose |
|------|-------|----------|---------|
| **Epic Master Plan** | Architect | `{epic-dir}/0002-master-implementation-plan.md` | PRD sequencing, cross-PRD risks, architecture decisions, dependency order |
| **PRD Implementation Plan** | Lead Developer | `{epic-dir}/PRD-{id}-implementation-plan.md` | File-by-file changes, test checklist, error path matrix, migration steps |

- The Architect creates the epic master plan (via /review-epic or delegation).
- The Lead creates PRD plans. The Architect reviews, amends (with tracked changes), and approves.
- If an epic master plan exists, the Lead MUST read it before writing a PRD plan.

## 1. THE BLUEPRINT WORKFLOW (GIT-TRACEABLE)
- **PHASE 1: Planning**: Create `{epic-dir}/PRD-{id}-implementation-plan.md` with: file-by-file changes, numbered test checklist, error path matrix, migration steps (if Rails), Pre-QA checklist acknowledgment. COMMIT it with message: 'Lead: PRD-{id} implementation plan'.
- **PHASE 2: Approval & Collaboration**: Submit the plan to the `architect`. The Architect will review and APPEND an `## Architect Review & Amendments` section to your plan file, tracking every addition/change/removal with `[ADDED]`, `[CHANGED]`, `[REMOVED]` tags. This creates a permanent record for retrospective analysis. After receiving PLAN-APPROVED, RE-READ your plan file — it may have been amended.
- **PHASE 3: Implementation**: Once you receive **PLAN-APPROVED**, re-read the plan and execute. COMMIT your code changes when finished.
- **PHASE 3.5: Pre-QA Hygiene (MANDATORY — DO NOT SKIP)**:
  After implementation and before scoring, run the Pre-QA Checklist:
  1. `rubocop -A` on all new/modified .rb files — 0 offenses required
  2. `grep -rL 'frozen_string_literal' [dirs] --include='*.rb'` — must return empty
  3. Full test suite passing — 0 failures, 0 errors, 0 skips on PRD tests
  4. All tests from implementation plan implemented (no stubs/placeholders)
  5. All rescue/raise blocks have corresponding tests
  6. (Rails only) Migrations verified from scratch
  Or run: `bash scripts/pre-qa-validate.sh` for automated checks 1-3.
  Save checklist to `{epic-dir}/feedback/pre-qa-checklist-PRD-{id}.md`.
  DO NOT proceed to Phase 4/5 until all items pass.
- **PHASE 4: Troubleshooting (Conditional)**: If you encounter a bug during implementation, or if `qa` gives you a score below 90, you MUST use `subagents---run_task` to delegate the troubleshooting to the `debug` agent.
- **PHASE 5: Scoring**: Submit for final scoring. Include pre-qa-checklist file path.
  The `qa` agent MUST save its scoring report to `{epic-dir}/feedback/qa-report-PRD-{id}.md`.
  After scoring, verify this file exists. If missing, request QA to save it.

## 2. SCORING & EFFICIENCY RULES:
1. ONLY the `qa` agent is authorized to award Quality Points (0-100). The QA agent MUST persist every score to `{epic-dir}/feedback/qa-report-PRD-{id}.md`.
2. **THE 90% PASS RULE**: If your score is 90 or higher, you have passed. You are NOT required to iterate further for a 100% score unless you choose to.
3. **CRITICAL BLOCKS**: You MUST iterate if the score is below 90 OR if `qa` identifies a 'CRITICAL' security or architectural flaw.
4. You are prohibited from self-awarding points.

Failure to follow the **Plan -> Approve -> Code -> Score** sequence is a violation, but efficiency is valued—get to 90+ and ship it.
