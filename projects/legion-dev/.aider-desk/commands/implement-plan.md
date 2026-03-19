---
description: Execute an already approved implementation plan (epic master plan or PRD plan) without re-requesting Architect review.
arguments:
  - description: The path to the plan file to implement (e.g., epic master plan or PRD implementation plan).
    required: true
---

# Command: Implement Existing Plan

This command directs the agent to execute an already approved implementation plan. This can be either:
- **Epic Master Plan**: `{epic-dir}/0002-master-implementation-plan.md` (created by Architect)
- **PRD Implementation Plan**: `{epic-dir}/PRD-{id}-implementation-plan.md` (created by Lead, approved by Architect)

## Workflow Execution:
1.  **LOAD PLAN**: Read the provided plan file: **{{1}}**
    - Check for an `## Architect Review & Amendments` section — if present, the plan was already reviewed and possibly amended. Follow the amended version.
    - If the plan references other PRDs or an epic master plan, read those for context.
2.  **SKIP ARCHITECT**: Do NOT request an Architect review. Treat the provided plan as already approved.
3.  **IMPLEMENT**:
    - Execute the code changes specified in the plan.
    - Follow `rules/rails-base-rules.md` and use relevant skills (Service Objects, ViewComponents).
    - Commit changes in logical, atomic units with descriptive messages.
4.  **PRE-QA**: Run the Pre-QA Checklist (MANDATORY — do NOT skip).
    - Run `bash scripts/pre-qa-validate.sh` OR manually complete all checks in `knowledge_base/templates/pre-qa-checklist-template.md`
    - Save completed checklist to `{epic-dir}/feedback/pre-qa-checklist-PRD-{id}.md`
    - ALL mandatory items must pass before step 5
5.  **SCORE**: Once implementation is complete, call the `ror-qa` agent to score the work. The QA agent will save its report to `{epic-dir}/feedback/qa-report-PRD-{id}.md`.
6.  **DEBUG**: If the QA score is < 90, delegate fixes to the `ror-debug` agent.

## Usage:
/implement-plan {path_to_plan.md}
