#### PRD-0-01: Knowledge Base Curation

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Legion starts with a clean, curated knowledge base — not a dump of everything from agent-forge. This PRD covers selecting, migrating, and adapting valuable content from the predecessor project, establishing the directory structure, and performing the Junie → Agent naming refactor across all carried-forward documents.

---

### Requirements

#### Functional

- Migrate `RULES.md` (14-phase lifecycle) and adapt all references from "agent-forge" to "Legion"
- Migrate all 5 templates (epic overview, PRD, implementation status, pre-qa checklist, retrospective)
- Migrate `smart-proxy.md` external service reference documentation
- Adapt `.junie/guidelines.md` → `knowledge_base/ai-instructions/agent-guidelines.md` (update: agent-forge → Legion, Rails 7 → Rails 8, strip AiderDesk-specific UI debugging, keep `projects/` sub-project structure)
- Adapt `log-requirement.md` → `knowledge_base/ai-instructions/task-log-requirement.md`
- Rename all "Junie" references: `prds-junie-log/` → `task-logs/`, "Junie Task Log" → "Agent Task Log" in templates and RULES.md
- Create `knowledge_base/overview/project-context.md` (✅ already done)
- Create project root `README.md` (✅ already done)

#### Non-Functional

- No abandoned or outdated agent-forge content in the knowledge base
- All documents must be internally consistent (no dangling references to old paths)

---

### Error Scenarios & Fallbacks

- Missing source file in agent-forge → Document the gap, create placeholder, flag for manual resolution
- Ambiguous "Junie" reference in content → Default to "Agent" unless context requires "Coding Agent" or "Lead Developer"

---

### Architectural Context

This is the foundation PRD — all subsequent PRDs depend on having a clean, organized knowledge base. The directory structure established here persists for the lifetime of the project. The naming refactor ensures no legacy naming leaks into Legion's identity.

---

### Acceptance Criteria

- [ ] AC1: `knowledge_base/` directory structure exists with subdirectories: `ai-instructions/`, `epics/`, `instructions/`, `overview/`, `templates/`, `task-logs/`
- [ ] AC2: `RULES.md` is present, references Legion (not agent-forge), contains no "Junie" references
- [ ] AC3: All 5 templates present in `knowledge_base/templates/` (epic overview, PRD, implementation status, pre-qa checklist, retrospective)
- [ ] AC4: `knowledge_base/smart-proxy.md` exists
- [ ] AC5: `knowledge_base/ai-instructions/agent-guidelines.md` exists — adapted from `.junie/guidelines.md`, no "Junie" or "agent-forge" references
- [ ] AC6: `knowledge_base/ai-instructions/task-log-requirement.md` exists — no "Junie" references
- [ ] AC7: `knowledge_base/overview/project-context.md` is present and accurate
- [ ] AC8: No abandoned or outdated agent-forge content exists in the KB
- [ ] AC9: No legacy "Junie" naming anywhere in the knowledge base (`grep -ri "junie" knowledge_base/` returns empty)
- [ ] AC10: Project root `README.md` exists with project description

---

### Test Cases

#### Manual Verification

- `grep -ri "junie" knowledge_base/` — must return empty
- `grep -ri "agent-forge" knowledge_base/instructions/RULES.md` — must return empty (except historical context references if any)
- Verify each template file exists: `ls knowledge_base/templates/`
- Verify AI instructions: `ls knowledge_base/ai-instructions/`

---

### Manual Verification

1. Run `find knowledge_base/ -type d | sort` — verify directory structure matches expected layout
2. Run `grep -ri "junie" knowledge_base/` — expected: no results
3. Open `knowledge_base/instructions/RULES.md` — verify it references "Legion" and `knowledge_base/task-logs/` (not `prds-junie-log/`)
4. Open `knowledge_base/ai-instructions/agent-guidelines.md` — verify it references Legion, Rails 8, contains `projects/` structure
5. Open `knowledge_base/ai-instructions/task-log-requirement.md` — verify "Agent Task Log" header, `knowledge_base/task-logs/` path
6. Count templates: `ls knowledge_base/templates/*.md | wc -l` — expected: 5

**Expected:** All checks pass, zero legacy naming, complete directory structure.

---

### Dependencies

- **Blocked By:** None — this is the first PRD
- **Blocks:** PRD-0-02, PRD-0-03, PRD-0-04

---

### Estimated Complexity

Low

### Agent Assignment

Manual (Eric + AI) — curation requires human judgment
