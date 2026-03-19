---
description: Implements a specific PRD following the Blueprint Workflow.
arguments:
  - description: The path to the PRD file to implement.
    required: true
---
I need you to implement the following PRD: **{{1}}**.

You must follow the **Blueprint Workflow** as defined in `prompts/delegation-rules.md`:

1. **PLAN**: Analyze the PRD and the current codebase. If an epic master plan exists (`0002-master-implementation-plan.md`), read it first for context. Then create your PRD implementation plan:
   - **Filename**: `PRD-{id}-implementation-plan.md` (e.g., `PRD-5010-implementation-plan.md`)
   - **Location**: Same directory as the PRD file (`{epic-dir}/`)
   - **Must include**: File-by-file changes, numbered test checklist (MUST-IMPLEMENT), error path matrix, migration steps (if Rails), Pre-QA checklist acknowledgment
   - COMMIT the plan file.
2. **APPROVE**: Submit the plan to the `architect` sub-agent. The Architect will review and append an `## Architect Review & Amendments` section to your plan file, tracking any additions/changes/removals. Wait for `PLAN-APPROVED`. After approval, **re-read your plan file** — the Architect may have amended it.
3. **CODE**: Implement per the approved (possibly amended) plan using the `aider` tool.
4. **PRE-QA**: Run the Pre-QA Checklist before requesting scoring. This is MANDATORY — do NOT skip.
   - Run `bash scripts/pre-qa-validate.sh` OR manually complete all checks in `knowledge_base/templates/pre-qa-checklist-template.md`
   - Fix ALL issues found (rubocop offenses, missing frozen_string_literal, test failures)
   - Save completed checklist to `{epic-dir}/feedback/pre-qa-checklist-PRD-{id}.md`
   - ALL mandatory items must pass before step 5
5. **SCORE**: Once PRE-QA checklist is clean, submit your work to the `qa` for a Quality Score. Include the pre-qa-checklist file path. The QA agent will save its scoring report to `{epic-dir}/feedback/qa-report-PRD-{id}.md`.
6.  **DEBUG**: If the QA score is < 90, delegate fixes to the `ror-debug` agent.

**Mandatory Requirements:**
- **Plan Naming**: PRD plans MUST be named `PRD-{id}-implementation-plan.md` in `{epic-dir}/`. No other naming.
- **Pre-QA Checklist**: You MUST complete and save the pre-qa-checklist before requesting QA scoring.
- **QA Report**: The QA agent MUST save its scoring report to `{epic-dir}/feedback/qa-report-PRD-{id}.md`. Verify this file exists after scoring. If missing, request QA to save it.
- **Agent Task Log**: You MUST create and maintain a task log in `knowledge_base/task-logs/` as per `knowledge_base/ai-instructions/task-log-requirement.md`.
- **Update Status**: Update the implementation status. Include the QA score from the report.
- **Commits**: Follow the commit rules in the delegation rules.
- **Tests**: Ensure tests are written or updated as specified in the PRD. No skips, no stubs, no placeholders.
- **End**: Once complete give a status and next steps.
