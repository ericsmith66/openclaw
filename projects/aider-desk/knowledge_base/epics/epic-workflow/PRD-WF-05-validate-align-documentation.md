#### PRD-WF-05: Validate & Align Documentation

**Log Requirements**
- Create/update a task log under `knowledge_base/prds-junie-log/` on completion.
- Include detailed manual verification steps and expected results.

---

### Overview

After PRDs WF-01 through WF-04 are complete, a final validation pass ensures everything is consistent. This PRD covers: grepping for RSpec remnants across all config files, confirming all workflow documents describe the same four-command model, updating the Table of Contents to reflect all changes, and running the full validation checklist from the implementation plan.

---

### Requirements

#### Functional

1. **Grep for RSpec remnants**
   - Search all files in `ror-agent-config/` for "RSpec", "rspec", "spec_helper".
   - Replace any found references with Minitest equivalents.
   - Confirm `rails-minitest-vcr` skill is aligned.

2. **Verify four-command model consistency**
   - `workflow.md` lists exactly four human-run commands.
   - `how-to-use-workflow.md` describes exactly four human-run commands.
   - `prompt-definitions.md` has prompt text for exactly four human commands + agent-internal commands.
   - All three documents agree on command names, descriptions, and RULES.md phase mappings.

3. **Update Table of Contents (`workflow-table-of-contence.md`)**
   - Add the three new command files (created in WF-02).
   - Mark `audit-homekit.md` as removed (WF-03).
   - Mark `review-epic.md` as repurposed to internal (WF-03).
   - Mark `implement-plan.md` as internal-only (WF-03).
   - Update agent entries to reflect prompt changes (WF-04).
   - Remove asterisks from completed items; add ✅ markers.

4. **Run the full validation checklist**
   - Execute every item in `workflow-implementaion-plan.md` Section I.
   - Mark each item as [x] when verified.
   - Document any failures with remediation steps.

5. **Verify RULES.md alignment**
   - Confirm `RULES.md` Φ10 commit policy matches all config files.
   - Confirm RULES.md phase references in all command files are correct.
   - Confirm RULES.md Part 3 naming conventions are referenced in `/finalize-epic`.

6. **Update workflow documentation for final consistency**
   - If any discrepancies are found during validation, update `workflow.md`, `how-to-use-workflow.md`, or `prompt-definitions.md` as needed.
   - Ensure the implementation plan's Definition of Done is fully satisfied.

#### Non-Functional

- This PRD produces no new config files — it validates and aligns existing ones.
- All changes are documentation/config text only.

---

### Error Scenarios & Fallbacks

- **RSpec reference found**: Replace with Minitest equivalent and re-validate.
- **Document inconsistency found**: Update the inconsistent document and note the change in the task log.
- **Validation checklist item fails**: Document the failure, fix it, and re-run the check.

---

### Architectural Context

This is the final PRD in the epic — it serves as the quality gate for the entire workflow implementation. No new functionality is added; this PRD confirms that WF-01 through WF-04 were executed correctly and that all documents are mutually consistent.

**Blocked by**: WF-01, WF-02, WF-03, WF-04 (all must be complete).

---

### Acceptance Criteria

- [ ] Zero RSpec references in any `ror-agent-config/` file.
- [ ] `workflow.md`, `how-to-use-workflow.md`, and `prompt-definitions.md` all describe the same four human commands.
- [ ] `workflow-table-of-contence.md` reflects all file changes (new, removed, repurposed, updated).
- [ ] All items in `workflow-implementaion-plan.md` Section I validation checklist are marked [x].
- [ ] RULES.md Φ10 commit policy matches all config files.
- [ ] RULES.md phase references in command files are correct.
- [ ] Implementation plan Definition of Done is fully satisfied.
- [ ] No contradictions exist between any two workflow documents.

---

### Test Cases

#### Validation

- `grep -ri "rspec\|spec_helper" ror-agent-config/`: expect zero results.
- `grep -c "/turn-idea-into-epic\|/get-feedback-on-epic\|/finalize-epic\|/implement-prd" knowledge_base/epics/epic-workflow/workflow.md`: expect ≥ 4.
- `grep -c "/turn-idea-into-epic\|/get-feedback-on-epic\|/finalize-epic\|/implement-prd" knowledge_base/epics/epic-workflow/how-to-use-workflow.md`: expect ≥ 4.
- `grep -c "TO CREATE\|TO UPDATE\|TO REMOVE\|TO REPURPOSE" knowledge_base/epics/epic-workflow/workflow-table-of-contence.md`: expect zero (all resolved to ✅).

---

### Manual Verification

1. Open `workflow-implementaion-plan.md` Section I — confirm all checklist items are [x].
2. Open `workflow-table-of-contence.md` — confirm no remaining asterisks or "TO CREATE/UPDATE/REMOVE" markers.
3. Open `workflow.md` — confirm four human commands listed with correct phase mappings.
4. Open `how-to-use-workflow.md` — confirm same four commands with matching descriptions.
5. Open `prompt-definitions.md` — confirm four human commands + agent-internal commands with file mappings.
6. Run `grep -ri "rspec" ror-agent-config/` — confirm zero results.

**Expected**
- All documents are consistent. All checklist items pass. Zero RSpec remnants. TOC is clean.
