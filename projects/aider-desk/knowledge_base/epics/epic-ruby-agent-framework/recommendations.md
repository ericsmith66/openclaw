# Recommendations — Ruby Agent Framework Epic

**Created**: 2026-02-26
**Source**: Analysis of design docs against nextgen-plaid's 14-phase workflow and epic/PRD standards

---

## Part 1: Structural Improvements (Before Implementation)

### R1. Run Through Architect Review (Φ5)

The PRDs were written directly without going through the **Φ4 → Φ5 → Φ6** cycle (consolidated expansion → architect review → feedback response). Before implementing:

1. Consolidate all PRDs into a single expansion document (or treat the current set as the Φ4 output)
2. Submit to the **Architect agent** for structural review
3. Resolve feedback in a response document
4. Then proceed to Φ7 (breakout — already done) and Φ8 (implementation plan)

**Why**: The Architect may catch structural issues (e.g., thread-safety concerns, missing error boundaries, API design flaws) that are cheaper to fix in documents than in code.

---

### R2. Strip Code from PRDs → Supporting Documents

Every PRD (0020–0110) contains full Ruby implementation code. Per `RULES.md`:
> *"PRD Anti-Pattern: PRD includes code snippets — Mixes requirements with implementation."*

**Action**: Create a `supporting/` subdirectory and move the Ruby code into reference architecture files:

```
epic-ruby-agent-framework/
  ├── supporting/
  │   ├── reference-0020-tool-framework.md    # Ruby code from PRD-0020
  │   ├── reference-0040-profile-system.md    # Ruby code from PRD-0040
  │   ├── reference-0050-power-tools.md       # Ruby code from PRD-0050
  │   ├── reference-0090-agent-runner.md      # Ruby code from PRD-0090
  │   └── ...
```

The PRDs themselves should retain only:
- Functional requirements (what the module must do)
- Acceptance criteria (Given X, Then Y)
- Test cases (what to verify)
- AiderDesk source mapping (which files to reference)

**Why**: Keeps PRDs focused on requirements. The code serves as a reference for the Coding Agent during Φ10 but doesn't constrain the implementation.

---

### R3. Add Missing PRD Sections

Per the `PRD-template.md` standard, each PRD should include:

| Missing Section | What to Add |
|----------------|-------------|
| **User Story** | "As a Ruby developer, I want to define tools with schemas and approval policies, so that I can control what my agent can execute." |
| **Non-Functional Requirements** | Thread-safety, memory usage, Ruby version compatibility, startup time |
| **Error Scenarios & Fallbacks** | What happens when: LLM returns invalid JSON, tool raises exception, approval times out, template file is malformed |
| **Manual Testing Steps** | Numbered steps with expected results for each PRD |
| **Blocked By / Blocks** | Formal dependency declarations (currently prose, should be structured) |
| **Workflow** | Branch naming, commit strategy, model preference |

---

### R4. Add Implementation Status Tracker

Create `0001-implementation-status.md` per the standard:

```markdown
# Ruby Agent Framework: Implementation Status

**Epic**: epic-ruby-agent-framework
**Status**: Not Started
**Last Updated**: 2026-02-26

| PRD | Title | Status | Branch | QA Score | Date | Notes |
|-----|-------|--------|--------|----------|------|-------|
| 0010 | Core Types & Scaffold | Not Started | — | — | — | — |
| 0020 | Tool Framework | Not Started | — | — | — | — |
| 0030 | Hook System | Not Started | — | — | — | — |
| ... | ... | ... | ... | ... | ... | ... |
```

---

### R5. Create Project-Specific Delegation Rules

If this gem will be built by the agent team, create:
- `.aider-desk/prompts/delegation-rules.md` for the Ruby gem project (adapted from nextgen-plaid's Blueprint Workflow)
- Agent configs adapted for pure Ruby gem development

**Open Decision**: Should this gem use **RSpec** (as currently specified in PRDs) or **Minitest** (per nextgen-plaid's `.junie/guidelines.md`)? The PRDs assume RSpec but your established convention is Minitest. Decide before implementation.

---

### R6. Create Custom Commands

Matching nextgen-plaid's pattern, create commands for this project:
- `/implement-prd` — adapted for Ruby gem PRDs
- `/validate-gem` — verify gem builds, tests pass, constants match AiderDesk
- `/review-epic` — architect review of the full epic

---

## Part 2: Parallelization Strategy

### Dependency Graph (Corrected — includes PRD-0095 Message Bus)

```
Wave 1:  0010
            │
Wave 2:  0020 ──── 0030 ──── 0095   (parallel: all three depend only on 0010)
            │         │        │
Wave 3:  0040  0050  0080  0090*  0100  0110   (parallel: all 6)
            │                   │                │
Wave 3b:                       0092**            │
            │                                    │
Wave 4:  0060                                    │
            │                                    │
Wave 5:  0070                                    │

* 0090 (agent runner) depends on 0020 + 0030
** 0092 (token budget / handoff) depends on 0090 + 0030 + 0095
```

### Detailed Parallel Schedule

| Wave | PRDs | Depends On | Can Run In Parallel | Est. Effort Each |
|------|------|------------|---------------------|-----------------|
| **1** | 0010 | — | Solo | 2-4 hrs |
| **2** | 0020, 0030, 0095 | 0010 | ✅ Yes (3 parallel) | 4-6 hrs each |
| **3** | 0040, 0050, 0080, 0090, 0100, 0110 | 0020 (+0030 for 0090) | ✅ Yes (up to 6 parallel) | 3-6 hrs each |
| **3b** | 0092 | 0090, 0030, 0095 | After 0090 completes (0030+0095 already done in Wave 2) | 4-6 hrs |
| **4** | 0060 | 0040 | Solo | 6-8 hrs |
| **5** | 0070 | 0060 | Solo | 2-4 hrs |

### Why Wave 3 Has 6 Parallel PRDs

- **0040** (Profiles) depends on 0020 (tool framework) — needs `ToolApprovalState` and tool constants
- **0050** (Power Tools) depends on 0020 — needs `BaseTool`, `ToolSet`, `build_group` DSL
- **0080** (Skills) depends on 0020 — needs `BaseTool` for the `activate_skill` tool
- **0090** (Agent Runner) depends on 0020 + 0030 — needs tool execution + hooks
- **0100** (Memory) depends on 0020 — needs `BaseTool` for memory tools
- **0110** (Todo/Task/Helpers) depends on 0020 — needs `BaseTool` for all three groups

None of these 6 depend on each other. They all just need the tool framework (0020) to exist.

### Serial vs Parallel Timeline

| Strategy | Total Elapsed Time |
|----------|--------------------|
| **Fully serial** (one PRD at a time) | ~50 hrs |
| **Parallel by waves** | ~22 hrs (Wave 3 dominates: 6 PRDs done in the time of 1) |
| **Optimal** (2 coding agents) | ~28 hrs (Wave 3 in 3 batches of 2) |

### Recommended Execution Order (If Serial)

If only one coding agent is available, prioritize by "earliest usable milestone":

1. **0010** → gem exists
2. **0020** → can define and register tools
3. **0030** → hooks work
4. **0090** → **🎉 agent runs!** (M1 core — first usable milestone)
5. **0092** → agent gracefully handles token limits (M1 complete)
6. **0050** → agent can read files, run bash (most immediately useful tools)
7. **0040** → multiple profiles
8. **0060** → system prompt templating
9. **0070** → project rules loaded
10. **0110** → todo/task/helpers
11. **0080** → skills
12. **0100** → memory

---

## Part 3: Open Decisions Needed Before Φ8

| # | Decision | Options | Impact |
|---|----------|---------|--------|
| 1 | **Test framework** | RSpec (PRDs assume this) vs Minitest (nextgen-plaid convention) | Affects all PRD test sections |
| 2 | **Template engine** | Handlebars.rb (direct port, same `.hbs` files) vs Liquid (more idiomatic Ruby) | Affects PRD-0060 |
| 3 | **Where does the gem live?** | Inside aider-desk repo (`ruby-agent-framework/`) vs standalone repo | Affects CI, publishing, development workflow |
| 4 | **LLM provider priority** | OpenAI-compatible first vs Anthropic first vs both simultaneously | Affects PRD-0090 scope |
| 5 | **Streaming support** | Required in M1 vs deferred to later milestone | Affects PRD-0090 complexity |
| 6 | **MCP client support** | In scope (future PRD) vs out of scope entirely | Affects epic non-goals |

---

## Part 4: Checklist — Before Starting Φ8 (Implementation Plan)

- [ ] Eric decides on open questions above (Part 3)
- [ ] PRDs sent through Architect review (Φ5) — or Eric explicitly waives this
- [ ] Code moved from PRDs to `supporting/` reference docs (R2)
- [ ] Missing PRD sections added (R3) — or Eric explicitly waives this
- [ ] `0001-implementation-status.md` created (R4)
- [ ] Testing framework decision locked in (RSpec vs Minitest)
- [ ] Gem location decided (aider-desk repo vs standalone)
- [ ] `ruby-agent-framework/` premature scaffold cleaned up or adopted

---

**Next Action**: Eric reviews these recommendations, makes the open decisions, and either:
- **Fast path**: Waive Φ5 review, accept PRDs as-is, proceed to Φ8 (implementation plan)
- **Standard path**: Send consolidated doc to Architect agent, do 1 feedback cycle, then Φ8
