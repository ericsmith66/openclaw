# Feedback v3: Epic & PRD Review

Date: 2026-02-21

This document provides feedback on the newly created epic (`0000-epic.md`) and five atomic PRDs (`PRD-WF-01` through `PRD-WF-05`) for implementing the workflow framework.

---

## Part 1: Epic Assessment

### Strengths

1. **Clean PRD decomposition**: Five PRDs with clear dependency chain (WF-01 blocks all, WF-05 validates all). No circular dependencies.
2. **Follows RULES.md structure**: Epic uses the template format with Key Decisions, Scope/Non-Goals, PRD Summary Table, and Success Metrics.
3. **Explicit out-of-scope**: Clearly states what's deferred (RULES.md splitting, workflow metrics, framework-agnostic support).
4. **Actionable success metrics**: Every metric is grep-verifiable or checklist-verifiable — no subjective criteria.

### Concerns

#### E1: Epic Is Config/Documentation Only — No Application Code
This is unusual for an epic. All five PRDs modify Markdown files and JSON configs. There are no models, controllers, migrations, or tests in the traditional sense. The RULES.md template (designed for Rails app epics) has sections like "Rails / Implementation Notes", "Unit (Minitest)", "Integration (Minitest)", "System / Smoke (Capybara)" that don't apply here.

**Impact**: Low. The PRDs adapt the template sensibly — using grep-based validation instead of test suites. But it's worth noting that the QA rubric (Φ11) doesn't cleanly apply to config-only changes. The QA agent would need to understand that "Test Coverage 30" means "grep validation coverage" for this epic.

**Recommendation**: Add a note to the epic overview: "This is a config/documentation epic. QA scoring should interpret 'test coverage' as 'validation coverage' (grep checks, file existence, JSON validity)."

#### E2: No Explicit "Sync and Verify" Step
After all config changes are made to `ror-agent-config/`, someone needs to run the sync script and verify the runtime `.aider-desk/` files are correct. None of the PRDs include this step.

**Recommendation**: Add to WF-05 or as a post-epic step: "Run `scripts/sync-aider-config.sh projects/aider-desk ror` and verify `.aider-desk/commands/` contains the four human commands."

#### E3: Templates May Not Exist
The epic references `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md`, `PRD-template.md`, and `0001-IMPLEMENTATION-STATUS-template.md`. These exist in the Agent-Forge repo but the PRD commands reference them as if they're in the project repo. If agents can't find them at runtime, `/turn-idea-into-epic` and `/finalize-epic` will fail.

**Recommendation**: Verify that the template paths are accessible from the project's working directory, or add a step to WF-02 to confirm template accessibility.

---

## Part 2: PRD-Level Feedback

### PRD-WF-01: Generalize Base Rules & Fix Commit Policy ✅
- **Solid**: Clear acceptance criteria with grep-based validation.
- **One gap**: Doesn't mention checking `ror-architect` or `ror-qa` system prompts for commit policy references. These are covered in WF-04, but the commit policy fix should be comprehensive in WF-01.
- **Suggestion**: Add an AC: "Grep all `config.json` system prompts for commit-related language and confirm alignment."

### PRD-WF-02: Create Human Command Files ✅
- **Solid**: Clear file-by-file creation plan with source traceability to `prompt-definitions.md`.
- **One gap**: Doesn't specify the exact Markdown format/structure to follow. It says "follow the same format as `implement-prd.md`" but the current `implement-prd.md` format may change in WF-03.
- **Suggestion**: Create WF-02 files using `prompt-definitions.md` as the canonical source, not the current `implement-prd.md` format. The format should match whatever `implement-prd.md` becomes after WF-03.

### PRD-WF-03: Update implement-prd and Legacy Commands ✅
- **Solid**: Comprehensive — covers the main command update plus all legacy command dispositions.
- **One concern**: This PRD does a lot (update 1 command, repurpose 1, document 1, delete 1, fix IDs in 2). Consider whether it should be split. However, since these are all small text changes in the same directory, keeping them together is pragmatic.
- **No changes needed**.

### PRD-WF-04: Update Agent System Prompts ✅
- **Solid**: Targeted changes with JSON validation step.
- **One gap**: The JSON field name for system prompts may not be `systemPrompt`. The actual field in the config files should be verified before writing test cases.
- **Suggestion**: Verify the actual JSON key name in `config.json` files and update test cases accordingly.

### PRD-WF-05: Validate & Align Documentation ✅
- **Solid**: Serves as the quality gate for the entire epic.
- **One gap**: Missing the sync-and-verify step (see E2 above).
- **Suggestion**: Add sync script execution and runtime verification to this PRD.

---

## Part 3: Dependency & Ordering Assessment

```
WF-01 (rules + commit policy)
  ├── WF-02 (create commands)     ─┐
  ├── WF-03 (update commands)      ├── WF-05 (validate all)
  └── WF-04 (agent prompts)       ─┘
```

- **WF-01 must be first** — correct. All other PRDs depend on the commit policy and generalized rules being in place.
- **WF-02, WF-03, WF-04 can run in parallel** — correct. They touch different files.
- **WF-05 must be last** — correct. It validates everything.
- **No circular dependencies** — confirmed.
- **Estimated effort**: WF-01 is the heaviest (multiple files, policy reconciliation). WF-02 is straightforward (copy from prompt-definitions). WF-03 is moderate (update + cleanup). WF-04 is small (JSON edits). WF-05 is mechanical (grep + checklist).

---

## Part 4: Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Templates not accessible at runtime | Medium | High — commands fail | Verify template paths in WF-02 |
| Sync script not run after changes | High | Medium — runtime stale | Add sync step to WF-05 |
| JSON syntax broken in agent configs | Low | High — agents won't load | `jq` validation in WF-04 |
| Prompt-definitions drift from command files | Medium | Medium — inconsistency | Note in TOC that prompt-definitions is source of truth |
| RULES.md too long for agent context | Low | Medium — agents lose rules | Monitor; split if needed (deferred) |

---

## Part 5: Summary

The epic and PRDs are well-structured, follow the RULES.md template conventions, and map cleanly to the implementation plan sections A–I. Three minor gaps identified:

1. **Add sync-and-verify step** to WF-05 (run sync script, check runtime files).
2. **Add commit policy grep across all config.json** to WF-01 acceptance criteria.
3. **Verify template path accessibility** in WF-02.

None of these are blocking — they can be incorporated as minor AC additions before implementation begins.

**Overall assessment**: Ready for Architect review (Φ5). The epic is implementable as-is with the three suggested additions.
