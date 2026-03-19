#### PRD-WF-02: Create Human Command Files

**Log Requirements**
- Create/update a task log under `knowledge_base/prds-junie-log/` on completion.
- Include detailed manual verification steps and expected results.

---

### Overview

Three of the four human-run workflow commands do not have corresponding command files in `ror-agent-config/commands/`. Only `implement-prd.md` exists. This PRD creates the missing command files (`turn-idea-into-epic.md`, `get-feedback-on-epic.md`, `finalize-epic.md`) using the exact prompt text from `prompt-definitions.md`.

---

### Requirements

#### Functional

1. **Create `commands/turn-idea-into-epic.md`**
   - Source: `prompt-definitions.md` → `/turn-idea-into-epic` section.
   - Must reference RULES.md Φ1–Φ2.
   - Must require PRD summary table output.
   - Must reference epic template: `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md`.
   - Must use `{{1}}` templating for the idea input if supported.

2. **Create `commands/get-feedback-on-epic.md`**
   - Source: `prompt-definitions.md` → `/get-feedback-on-epic` section.
   - Must reference RULES.md Φ4–Φ6.
   - Must delegate to Architect (`ror-architect`) for review.
   - Must require feedback organized as Questions / Suggestions / Objections.
   - Must require every objection to include a solution.
   - Must reference PRD template: `knowledge_base/templates/PRD-template.md`.
   - Feedback filename convention: `{epic-name}-feedback-V{N}.md` in `feedback/` subfolder.

3. **Create `commands/finalize-epic.md`**
   - Source: `prompt-definitions.md` → `/finalize-epic` section.
   - Must reference RULES.md Φ7.
   - Must create individual PRD files following RULES.md Part 3 naming conventions.
   - Must create `0001-IMPLEMENTATION-STATUS.md` from template.
   - Must delegate to Architect (`ror-architect`) for `/plan-epic`.
   - Must commit all artifacts per commit policy.
   - Must follow RULES.md Φ7 directory structure.

#### Non-Functional

- Command files must follow the same Markdown format as existing commands (e.g., `implement-prd.md`).
- Agent IDs must use template format (`ror-architect`, not `ror-architect-<project>`).
- All changes target `ror-agent-config/commands/`, not `.aider-desk/commands/`.

---

### Error Scenarios & Fallbacks

- **Prompt text drift**: If `prompt-definitions.md` is updated after command files are created, the command files become stale. Mitigation: the TOC and implementation plan note that `prompt-definitions.md` is the source of truth; command files should be regenerated on prompt changes.
- **Missing RULES.md reference**: If a command file doesn't reference RULES.md, agents won't know the phase rules. Every command file must include a `RULES.md PHASES:` line.

---

### Architectural Context

These three command files are the human-facing entry points to the workflow. They are the only commands a human should trigger. Each command delegates internally to agents for the actual work. The command files live in `ror-agent-config/commands/` and are synced to `.aider-desk/commands/` by the sync script.

**Blocked by**: WF-01 (commit policy must be correct before commands reference it).

---

### Acceptance Criteria

- [ ] `ror-agent-config/commands/turn-idea-into-epic.md` exists.
- [ ] `turn-idea-into-epic.md` references RULES.md Φ1–Φ2.
- [ ] `turn-idea-into-epic.md` requires PRD summary table and epic template.
- [ ] `ror-agent-config/commands/get-feedback-on-epic.md` exists.
- [ ] `get-feedback-on-epic.md` references RULES.md Φ4–Φ6.
- [ ] `get-feedback-on-epic.md` delegates to `ror-architect` for review.
- [ ] `get-feedback-on-epic.md` requires Questions / Suggestions / Objections format with solutions.
- [ ] `ror-agent-config/commands/finalize-epic.md` exists.
- [ ] `finalize-epic.md` references RULES.md Φ7.
- [ ] `finalize-epic.md` creates PRD files following Part 3 naming.
- [ ] `finalize-epic.md` delegates to `ror-architect` for `/plan-epic`.
- [ ] `finalize-epic.md` commits artifacts per policy.
- [ ] All three files use template agent IDs (no project suffix).
- [ ] All three files follow the same Markdown format as `implement-prd.md`.

---

### Test Cases

#### Validation (file existence and content checks)

- `test -f ror-agent-config/commands/turn-idea-into-epic.md`: expect success.
- `test -f ror-agent-config/commands/get-feedback-on-epic.md`: expect success.
- `test -f ror-agent-config/commands/finalize-epic.md`: expect success.
- `grep -l "RULES.md" ror-agent-config/commands/turn-idea-into-epic.md`: expect match.
- `grep -l "RULES.md" ror-agent-config/commands/get-feedback-on-epic.md`: expect match.
- `grep -l "RULES.md" ror-agent-config/commands/finalize-epic.md`: expect match.
- `grep -l "ror-architect" ror-agent-config/commands/get-feedback-on-epic.md`: expect match.
- `grep -l "ror-architect" ror-agent-config/commands/finalize-epic.md`: expect match.

---

### Manual Verification

1. Open each of the three new command files.
2. Compare content against the corresponding section in `prompt-definitions.md`.
3. Confirm RULES.md phase references are present.
4. Confirm agent IDs use template format.
5. Confirm commit policy language matches "commit plans always; commit code when green."
6. Confirm the format matches `implement-prd.md` style.

**Expected**
- Three new command files exist, match prompt-definitions, and reference RULES.md correctly.
