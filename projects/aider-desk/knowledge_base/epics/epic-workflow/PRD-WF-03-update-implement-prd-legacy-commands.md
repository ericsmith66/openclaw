#### PRD-WF-03: Update implement-prd and Legacy Commands

**Log Requirements**
- Create/update a task log under `knowledge_base/prds-junie-log/` on completion.
- Include detailed manual verification steps and expected results.

---

### Overview

The existing `implement-prd.md` command needs to be updated to enforce adherence to the approved PRD plan and include the full Blueprint inner loop (Φ8–Φ12). Additionally, several legacy commands need disposition: `review-epic.md` should be repurposed as an internal architect delegation target, `implement-plan.md` should be documented as internal-only, `audit-homekit.md` should be removed, and utility commands (`roll-call.md`, `validate-installation.md`) need their agent IDs corrected to use the `ror-*` prefix.

---

### Requirements

#### Functional

1. **Update `commands/implement-prd.md`**
   - Replace current content with the prompt from `prompt-definitions.md` → `/implement-prd` section.
   - Must explicitly instruct the Coding Agent to locate and adhere to the approved PRD plan.
   - Must include the full Blueprint loop: Φ8 (Plan) → Φ9 (Architect Gate) → Φ10 (Code) → Φ11 (QA Gate) → Φ12 (Log).
   - Must reference RULES.md Φ8–Φ12 with rubric weights.
   - Must include escalation paths: 3 plan revisions → escalate to Eric; 3 QA cycles → escalate to Eric.
   - Must include `/log-task` and `/update-implementation-status` as byproducts.
   - Must state commit policy: "commit plans always; commit code when green."

2. **Repurpose `commands/review-epic.md`**
   - Update content to serve as the internal architect delegation target for `/get-feedback-on-epic`.
   - Add a header comment: "INTERNAL — invoked by `/get-feedback-on-epic`, not by humans directly."
   - Align content with `prompt-definitions.md` → `/architect-review-plan` or the architect review portion of `/get-feedback-on-epic`.

3. **Document `commands/implement-plan.md` as internal-only**
   - Add a header comment: "INTERNAL — used after PLAN-APPROVED for re-runs. Not a human command."
   - Keep existing content but ensure it references the approved plan.

4. **Remove `commands/audit-homekit.md`**
   - Delete the file. No backward-compatible alias needed (confirmed by Eric).

5. **Update `commands/roll-call.md` agent IDs**
   - Replace any bare agent IDs (`architect`, `qa`, `debug`, `rails`) with `ror-architect`, `ror-qa`, `ror-debug`, `ror-rails`.

6. **Update `commands/validate-installation.md` agent IDs**
   - Same as roll-call: replace bare agent IDs with `ror-*` prefixed versions.

#### Non-Functional

- All changes target `ror-agent-config/commands/`, not `.aider-desk/commands/`.
- Internal commands must be clearly marked so humans don't trigger them.

---

### Error Scenarios & Fallbacks

- **Plan not found**: If `/implement-prd` can't locate the approved PRD plan, it should fail with a clear message: "No approved PRD plan found. Run `/finalize-epic` first."
- **Agent ID mismatch**: If utility commands use bare IDs, the sync script will append the project suffix to the wrong base, causing runtime failures. Grep for bare IDs after changes.

---

### Architectural Context

`implement-prd.md` is the most complex command — it orchestrates the entire Blueprint inner loop with sub-agent delegation. The legacy commands are artifacts from earlier iterations that need cleanup to avoid confusion about what's human-triggerable vs agent-internal.

**Blocked by**: WF-01 (commit policy must be correct).

---

### Acceptance Criteria

- [ ] `implement-prd.md` references RULES.md Φ8–Φ12.
- [ ] `implement-prd.md` explicitly requires adherence to the approved PRD plan.
- [ ] `implement-prd.md` includes the full Blueprint loop (Plan → Approve → Code → Score → Log).
- [ ] `implement-prd.md` includes escalation paths (3 revisions, 3 QA cycles).
- [ ] `implement-prd.md` includes `/log-task` and `/update-implementation-status` as byproducts.
- [ ] `implement-prd.md` states commit policy correctly.
- [ ] `review-epic.md` is marked as INTERNAL with updated content.
- [ ] `implement-plan.md` is marked as INTERNAL.
- [ ] `audit-homekit.md` is deleted.
- [ ] `roll-call.md` uses `ror-*` prefixed agent IDs.
- [ ] `validate-installation.md` uses `ror-*` prefixed agent IDs.
- [ ] Grep for bare agent IDs (`"architect"`, `"qa"`, `"debug"`, `"rails"` without `ror-` prefix) in utility commands returns zero results.

---

### Test Cases

#### Validation

- `grep -c "RULES.md" ror-agent-config/commands/implement-prd.md`: expect ≥ 1.
- `grep -c "approved PRD plan\|PRD plan" ror-agent-config/commands/implement-prd.md`: expect ≥ 1.
- `grep -c "INTERNAL" ror-agent-config/commands/review-epic.md`: expect ≥ 1.
- `grep -c "INTERNAL" ror-agent-config/commands/implement-plan.md`: expect ≥ 1.
- `test ! -f ror-agent-config/commands/audit-homekit.md`: expect success (file deleted).
- `grep -c "ror-architect\|ror-qa\|ror-debug\|ror-rails" ror-agent-config/commands/roll-call.md`: expect ≥ 1.

---

### Manual Verification

1. Open `implement-prd.md` — confirm Blueprint loop phases are listed with RULES.md references.
2. Open `review-epic.md` — confirm "INTERNAL" header is present.
3. Open `implement-plan.md` — confirm "INTERNAL" header is present.
4. Confirm `audit-homekit.md` does not exist.
5. Open `roll-call.md` — confirm all agent IDs use `ror-*` prefix.
6. Open `validate-installation.md` — confirm all agent IDs use `ror-*` prefix.

**Expected**
- `implement-prd.md` is the full Blueprint command. Legacy commands are cleaned up. Utility commands have correct IDs.
