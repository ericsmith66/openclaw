# Epic & PRD Rules — Authoritative Reference

**Status:** Canonical — all AI agents and humans follow these rules
**Last Updated:** February 20, 2026
**Companion docs:** Adapted from agent-forge RULES.md for the Legion project.

> **This is the single source of truth.** When in doubt, follow this document.
> Templates live in `knowledge_base/templates/`. This document tells you *when* and *how* to use them.

---

## Part 1: Actors & Responsibilities

Five actors participate. **No actor does everything.** Each has a lane.

| Actor | Lane | Does NOT do |
|-------|------|-------------|
| **Eric** (Human) | Idea origination, epic approval, feedback responses, final smoke test, merge | Write code, break out PRD files, score implementations |
| **High-Reasoning AI** (Grok, Claude, etc.) | Epic drafting, PRD expansion, feedback response synthesis | Review architecture, write code, score plans |
| **Architect Agent** | Epic review, feedback with solutions, plan scoring | Write code, draft epics, break out files |
| **Coding Agent** (Rails Lead via agent_desk gem) | PRD file breakout, implementation planning, coding, testing, task logging | Draft epics, review architecture, score QA |
| **QA Agent** | Validate implementation, score 0-100, end-of-epic report | Write code, draft epics, plan architecture |

---

## Part 2: The 14 Phases — Rules Per Phase

### Φ1 — Idea

| | |
|-|-|
| **Actor** | Eric |
| **Output** | Rough idea (any format) |
| **Rule** | No structure required. Can be a sentence, a paragraph, or a conversation snippet. |

---

### Φ2 — Epic Drafting (Atomic PRD Summaries)

| | |
|-|-|
| **Actors** | Eric + High-Reasoning AI |
| **Output** | Preliminary epic with PRD summary table |
| **Template** | `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md` (for structure reference only — this phase produces a lightweight draft, not the full template) |

**Rules:**
1. Each PRD summary is **2-3 sentences maximum** — define WHAT, not HOW
2. PRDs must be **atomic** — independently implementable and testable
3. Include a PRD summary table with columns: `#`, `Title`, `Summary (2-3 sentences)`
4. Include epic goal, scope, and non-goals (even if rough)
5. Do NOT expand PRDs into full detail yet — that happens in Φ4
6. Do NOT create individual PRD files yet — that happens in Φ7

---

### Φ3 — Eric Approval

| | |
|-|-|
| **Actor** | Eric |
| **Output** | Approved or revised epic skeleton |

**Rules:**
1. Eric may approve, tweak (reorder/split/merge PRDs), or reject
2. **No work proceeds past this phase** without Eric's explicit approval
3. If rejected → return to Φ2 with new direction

---

### Φ4 — Full Expansion

| | |
|-|-|
| **Actors** | Eric + High-Reasoning AI |
| **Output** | **One consolidated document** — epic overview + all fully detailed PRDs |

**Rules:**
1. Output is a **single file** — epic and all PRDs together. NOT individual files.
2. Each PRD section must include all sections from the PRD template:
   - Overview, User Story, Functional Requirements, Non-Functional Requirements
   - Architectural Context, Acceptance Criteria, Test Cases
   - Manual Testing Steps, Dependencies (Blocked By / Blocks)
   - Error Scenarios & Fallbacks
3. Acceptance criteria must be **specific and testable** — not vague
   - ❌ "Recognizes commands"
   - ✅ "Given input `/search nvidia`, the parser returns `{type: :search, args: 'nvidia'}`"
4. Manual testing steps must include **expected results** for each step
5. PRDs must declare dependency chains: `Blocked By` and `Blocks`
6. Reference the PRD template: `knowledge_base/templates/PRD-template.md`

---

### Φ5 — Architect Review

| | |
|-|-|
| **Actor** | Architect Agent |
| **Input** | Consolidated epic + PRD document from Φ4 |
| **Output** | Feedback document: `{epic-name}-feedback-V{N}.md` |

**Rules:**
1. Feedback must be organized into three categories:
   - **Questions** — clarifications needed
   - **Suggestions** — improvements (optional adoption)
   - **Objections** — design concerns that should be addressed
2. **Every objection MUST include a potential solution.** Never raise a problem without offering a fix.
3. Feedback document goes in the epic's directory (or `feedback/` subfolder)
4. Filename: `{epic-name}-feedback-V{N}.md` where N increments per cycle

---

### Φ6 — Feedback Response

| | |
|-|-|
| **Actors** | Eric + High-Reasoning AI |
| **Input** | Architect's feedback document |
| **Output** | Response document: `{epic-name}-response-V{N}.md` |

**Rules:**
1. Respond to **every** question, suggestion, and objection — do not skip any
2. Format: reproduce the architect's point, then provide the response inline
3. Eric provides domain decisions; the High-Reasoning AI articulates and integrates
4. Filename: `{epic-name}-response-V{N}.md`
5. **Repeat Φ5 → Φ6** until:
   - Architect has no remaining objections
   - Eric has locked in all key decisions
   - Typically 1-2 cycles. Maximum 3.

---

### Φ7 — PRD Breakout + Epic Update

| | |
|-|-|
| **Actor** | Coding Agent |
| **Input** | Finalized consolidated document + all feedback/response docs |
| **Output** | `0000-epic.md` + individual `PRD-*.md` files + `0001-IMPLEMENTATION-STATUS.md` |

**Rules:**
1. **Read all feedback/response documents** before starting — integrate locked-in decisions
2. Update `0000-epic.md` with:
   - "Key Decisions Locked In" section incorporating all resolved feedback
   - Updated PRD summary table with status = "Not Started"
3. Create individual PRD files following naming convention:
   - `PRD-{epic-id}-{seq}-{slug}.md`
   - No spaces in filenames. Lowercase kebab-case for slugs.
   - Sequential numbering: `01`, `02`, `03`...
4. Create `0001-IMPLEMENTATION-STATUS.md` from template:
   - `knowledge_base/templates/0001-IMPLEMENTATION-STATUS-template.md`
   - All PRDs listed as "Not Started"
5. Each PRD file must be self-contained — a new reader should understand it without reading other PRDs

### Directory structure after Φ7:

```
knowledge_base/epics/wip/{Stream}/{Epic-ID}/
  ├── 0000-epic.md
  ├── 0001-implementation-status.md
  ├── PRD-{epic}-01-{slug}.md
  ├── PRD-{epic}-02-{slug}.md
  ├── PRD-{epic}-03-{slug}.md
  └── feedback/
      ├── {epic}-feedback-V1.md
      ├── {epic}-response-V1.md
      └── (additional cycles if any)
```

---

### Φ8 — Implementation Plan

| | |
|-|-|
| **Actor** | Coding Agent |
| **Output** | Implementation plan document |

**Rules:**
1. Create **before writing any code**
2. Plan must cover:
   - File-by-file changes planned (models, migrations, services, controllers, components, tests)
   - Dependency order — which PRD first, what unblocks what
   - Test strategy — which test types for which components
   - Risk areas and mitigation
   - Estimated complexity per PRD
3. Plan must reference the specific PRD acceptance criteria it will satisfy
4. Store as: `{epic-dir}/implementation-plan.md` or within the implementation status doc

---

### Φ9 — Plan Review + Scoring (★ ARCHITECT GATE)

| | |
|-|-|
| **Actor** | Architect Agent |
| **Input** | Implementation plan from Φ8 |
| **Output** | Reviewed plan + score |

**Rules:**
1. Architect reviews against this rubric:

| Criteria | Weight | Description |
|----------|--------|-------------|
| **Completeness** | 25% | Does the plan cover ALL PRD requirements and acceptance criteria? |
| **Architecture Alignment** | 25% | Does it follow established patterns (ViewComponents, service objects, Minitest)? |
| **Risk Awareness** | 20% | Are edge cases, failure modes, and error scenarios addressed? |
| **Test Strategy** | 15% | Is test coverage appropriate (unit, integration, system)? |
| **Dependency Ordering** | 15% | Will things build in the correct sequence? No forward references? |

2. Architect may **modify** the plan (reorder steps, add considerations, flag risks)
3. **★ GATE:** Plan must be approved before Φ10 proceeds
4. If plan is fundamentally flawed → return to Coding Agent (Φ8) with specific issues
5. Store architect review as: `{epic-dir}/feedback/plan-review.md`

---

### Φ10 — Implementation

| | |
|-|-|
| **Actor** | Coding Agent (Deepseek-Reasoner (Rails Lead)) |
| **Input** | Architect-approved plan + individual PRD files |
| **Output** | Code, tests, migrations, components |

**Rules:**
1. Follow the architect-approved plan — do not deviate without documenting why
2. Follow `knowledge_base/ai-instructions/agent-guidelines.md`:
   - **Minitest** (never RSpec unless explicitly requested)
   - **ViewComponents** for UI
   - **DaisyUI/Tailwind** for styling
   - **Never commit** without explicit human request
   - **Never run destructive DB commands** (drop, reset, truncate) without confirmation
3. Each PRD's acceptance criteria are the definition of done for that PRD
4. Write tests alongside code — not after
5. All code must be green (tests passing) before moving to Φ11
6. **MANDATORY:** Complete Pre-QA Checklist (Part 9) before submitting to QA
   - Template: `knowledge_base/templates/pre-qa-checklist-template.md`
   - Save as: `{epic-dir}/feedback/pre-qa-checklist-PRD-{id}.md`
   - All mandatory items must pass — if any fail, fix before QA submission
   - This checklist catches 80% of common failures and improves first-pass rate

---

### Φ11 — QA Validation + Scoring (★ QUALITY GATE)

| | |
|-|-|
| **Actor** | QA Agent |
| **Input** | Implemented code + original PRDs + implementation plan |
| **Output** | QA report + score (0-100) |

**Rules:**
1. QA Agent validates against this rubric:

| Criteria | Points | Description |
|----------|--------|-------------|
| **Acceptance Criteria Compliance** | 30 | Every AC in every PRD checked. Each unmet AC = deduction. |
| **Test Coverage** | 30 | Unit tests for models/services, integration tests for controllers, system tests for UI. Missing test types = deduction. |
| **Code Quality** | 20 | Patterns followed, edge cases handled, no obvious bugs, clean structure. |
| **Plan Adherence** | 20 | Was the architect-approved plan actually followed? Unexplained deviations = deduction. |
| **TOTAL** | **100** | |

2. **★ GATE:**
   - **≥ 90** → ✅ Pass — proceed to Φ12
   - **< 90** → ❌ Fail — kicked back to Coding Agent (Φ10)
3. On failure, QA Agent must provide:
   - Exact score with per-criteria breakdown
   - Which acceptance criteria are unmet (list each one)
   - Which test coverage gaps exist
   - Specific remediation steps
4. **Maximum 3 QA cycles** (Φ10 → Φ11 loops). If still < 90 after 3 cycles → escalate to Eric
5. Store QA report as: `{epic-dir}/feedback/qa-report.md`

---

### Φ12 — Task Logging + Status Update

| | |
|-|-|
| **Actor** | Coding Agent |
| **Output** | Task log + updated implementation status |

**Rules:**
1. Create/update task log at `knowledge_base/task-logs/YYYY-MM-DD__task-slug.md`
   - Follow template: `knowledge_base/ai-instructions/task-log-requirement.md`
   - Must include: Goal, Context, Plan, Work Log, Files Changed, Commands Run, Tests, Decisions, Manual Verification Steps, Outcome
2. Update `0001-IMPLEMENTATION-STATUS.md`:
   - PRD status → Implemented
   - Record QA score
   - Record branch name, completion date
   - Note any deviations from plan with rationale

---

### Φ13 — Epic Closeout

| | |
|-|-|
| **Actors** | QA Agent (report) + Eric (smoke test + approval) |
| **Output** | `feedback/end-of-epic-report.md` |

**Rules:**
1. QA Agent generates end-of-epic report with:
   - Observations (what worked well)
   - Suggestions (what could improve)
   - Capabilities delivered (checklist from epic overview)
   - All QA scores summary table
   - Manual verification results
2. Eric performs final smoke test using manual verification steps
3. Eric approves → epic moved from `wip/` to `completed/`
4. Implementation status finalized — all PRDs marked complete

---

### Φ14 — Retrospective & Pattern Analysis

| | |
|-|-|
| **Actors** | QA Agent + Lead Developer + Architect Agent (as needed) |
| **Input** | All QA reports, implementation logs, task logs from completed epic |
| **Output** | `feedback/retrospective-report.md` + Updated Pre-QA Checklist |

**Purpose:** Self-improvement through systematic analysis of failure patterns and quality trends.

**Rules:**
1. **Trigger:** Conducted after every 3-5 completed epics OR after an epic with 2+ QA failures
2. **QA Agent** analyzes all QA scoring events from recent epics:
   - Common failure patterns (RuboCop offenses, missing tests, dead code paths, etc.)
   - Average QA score trends (improving vs declining)
   - Time-to-pass metrics (first-attempt pass rate)
   - Recurring deductions by category
3. **Pattern Registry**: Maintain a living document tracking:
   - Pattern frequency (how often each issue appears)
   - Average point deduction per pattern
   - Fix difficulty (trivial, medium, hard)
   - Prevention strategies (checklist items, instruction tweaks)
4. **Actionable Outputs:**
   - Update Pre-QA Checklist with new items (see Part 9)
   - Propose instruction refinements for Lead Developer
   - Propose instruction refinements for Architect (if planning gaps identified)
   - Store patterns in memory for cross-project learning
5. **Report Structure:**
   ```markdown
   # Retrospective Report: Epic {ID} to {ID}
   
   ## Score Summary
   - Epics analyzed: N
   - QA events: N
   - First-attempt pass rate: X%
   - Average score: X/100
   
   ## Top 5 Recurring Patterns
   1. Pattern name (frequency %, avg deduction, fix difficulty)
      - Evidence: [PRD-X, PRD-Y]
      - Impact: Description
      - Prevention: Specific checklist item or instruction change
   
   ## Instruction Updates
   ### Lead Developer
   - NEW MANDATORY: [specific requirement]
   - UPDATED: [clarification to existing rule]
   
   ### Architect
   - NEW: [planning template addition]
   
   ## Success Patterns (Celebrate)
   - What worked well across multiple PRDs
   
   ## Recommendations
   - High-priority improvements
   - Low-hanging fruit
   ```
6. **Continuous Improvement Loop:**
   - Patterns → Checklist updates → Reduced failures → Better first-pass rates
   - Track improvement metrics over time (e.g., RuboCop offenses trend)
7. **Memory Storage:** After retrospective, store:
   - Stable, reusable patterns (e.g., "RuboCop must pass before submission")
   - Instruction updates that apply across projects
   - Do NOT store: individual PRD details, one-off bugs, temporary notes

---

### Φ15 — Next Epic

| | |
|-|-|
| **Actor** | Eric |

Eric selects the next epic from the backlog. Returns to Φ1.

---

## Part 3: Naming Conventions

### Epic Folders

**Pattern:** `{ID}-{Descriptive-Slug}`

| ✅ Do | ❌ Don't |
|-------|----------|
| `Epic-5-Holdings-Grid` | `Epic-5` (no description) |
| `Agent-Hub-05-Smart-Command-Model` | `AGENT-05` (too cryptic) |
| `Platform-01-Shared-Identity` | `shared identity stuff` (no ID) |

**Rules:** Always include a numeric ID + human-readable slug. Kebab-case (hyphens).

### PRD Files

**Pattern:** `PRD-{epic-id}-{seq}-{slug}.md`

| ✅ Do | ❌ Don't |
|-------|----------|
| `PRD-5-03-core-table-pagination.md` | `0030-PRD-3-12.md` (redundant numbering) |
| `PRD-AH-009B-artifact-store.md` | `PRD AGENT-01.md` (spaces!) |

**Rules:** No spaces. Include epic ID. Lowercase kebab-case. Sequential numbering.

### Feedback Files

| Type | Pattern | Location |
|------|---------|----------|
| Architect feedback (Φ5) | `{epic}-feedback-V{N}.md` | `feedback/` |
| Eric + AI response (Φ6) | `{epic}-response-V{N}.md` | `feedback/` |
| Architect plan review (Φ9) | `plan-review.md` | `feedback/` |
| Pre-QA checklist (Φ10) | `pre-qa-checklist-PRD-{id}.md` | `feedback/` |
| QA report (Φ11) | `qa-report.md` | `feedback/` |
| End-of-epic report (Φ13) | `end-of-epic-report.md` | `feedback/` |
| Retrospective report (Φ14) | `retrospective-report.md` | `feedback/` (or project root) |

### Other Files

| Type | Filename | Required? |
|------|----------|-----------|
| Epic overview | `0000-epic.md` | **Yes — always** |
| Implementation status | `0001-implementation-status.md` | **Yes — all WIP epics** |
| Implementation plan | `implementation-plan.md` | **Yes — before coding** |
| Task log | `knowledge_base/task-logs/YYYY-MM-DD__task-slug.md` | **Yes — per task** |
| Test plan | `testing/test-plan.md` | Recommended |
| Supporting docs | `supporting/*.md` | Optional |

---

## Part 3B: Git Branching Strategy

### Branch Naming

```
epic-{N}/prd-{number}-{slug}
```

### Grouping Rule

Tightly coupled PRDs within the same milestone that share the same domain (e.g., backend API + UI for the same resource) **SHOULD** share a single branch. The branch is named after the **first PRD** in the group.

**When to reuse a branch:**
- ✅ Next PRD directly extends the same controllers, views, or models
- ✅ Next PRD is blocked-by the current one and they share the same milestone

**When to create a new branch:**
- ❌ PRD targets a different domain/resource (e.g., skills vs. profiles)
- ❌ Merging to main between PRDs to keep the diff reviewable

### Commit Convention

Each commit MUST be prefixed with the PRD number it implements:
```
PRD-5010: Initial API controllers and routes
PRD-5020: Agent Profile UI Components — implementation + QA fixes (93/100 PASS)
```

### Workflow

```
1. If starting new group:   git checkout -b epic-{N}/prd-{first}-{slug}
   If continuing group:     stay on existing branch
2. Implement PRD
3. Commit with prefix:      git commit -m "PRD-{N}: {description}"
4. Run tests, QA review (≥ 90/100)
5. If more PRDs in group:   repeat from step 2
6. Eric smoke test → merge → delete branch → update status
```

---

## Part 4: Directory Structure

```
knowledge_base/epics/
  ├── instructions/              # THIS FOLDER — rules & workflow docs
  │   ├── RULES.md               # ← You are here
  │   ├── implied-workflow.md     # Full 14-phase workflow details
  │   └── epic-prd-best-practices.md  # Audit & historical analysis
  │
  ├── completed/                 # Finished epics
  │   └── {Epic-ID}/
  │       ├── 0000-epic.md
  │       ├── 0001-implementation-status.md
  │       ├── PRD-{epic}-{seq}-{slug}.md
  │       ├── implementation-plan.md
  │       ├── feedback/
  │       │   ├── {epic}-feedback-V1.md
  │       │   ├── {epic}-response-V1.md
  │       │   ├── plan-review.md
  │       │   ├── qa-report.md
  │       │   └── end-of-epic-report.md
  │       ├── testing/
  │       │   ├── test-plan.md
  │       │   └── manual-test-results.md
  │       └── supporting/
  │
  ├── wip/                       # In-progress epics
  │   └── {Stream}/{Epic-ID}/
  │       └── (same structure as completed/)
  │
  └── backlog/                   # Planned but not started
      └── {Epic-ID}/
          └── 0000-epic.md (minimum)
```

**Rules:**
1. One folder per epic — no loose PRDs in parent directories
2. `feedback/` subfolder for ALL feedback/review/QA docs — never in root
3. `testing/` subfolder for test plans and results
4. `supporting/` subfolder for research, spikes, reference material
5. Move to `completed/` when epic is done — don't leave in `wip/`

---

## Part 5: Anti-Patterns (What NOT to Do)

### Epic Anti-Patterns
| ❌ Anti-Pattern | Why It's Bad | ✅ Instead |
|----------------|-------------|-----------|
| Wall-of-text epic with no sections | Agents can't parse; humans skip it | Use the epic template with clear sections |
| Skipping non-goals | Scope creep | Always define what's OUT of scope |
| 15+ PRDs in one epic | Too large to manage; blocks testing | Split into sub-epics of 5-8 PRDs |
| Mixing HOW into the epic | Epic is WHAT and WHY; not implementation | Save HOW for the implementation plan (Φ8) |

### PRD Anti-Patterns
| ❌ Anti-Pattern | Why It's Bad | ✅ Instead |
|----------------|-------------|-----------|
| Vague acceptance criteria | Can't verify; QA can't score | Specific, testable: "Given X, then Y" |
| Missing manual test steps | Eric can't smoke test; QA can't validate | Always include numbered steps + expected results |
| No dependency chain | PRDs built in wrong order | Always declare Blocked By / Blocks |
| PRD includes code snippets | Mixes requirements with implementation | PRDs say WHAT, not HOW. Implementation plan says HOW. |
| Missing error scenarios | Happy path only; production breaks | Always include Error Scenarios & Fallbacks section |

### Process Anti-Patterns
| ❌ Anti-Pattern | Why It's Bad | ✅ Instead |
|----------------|-------------|-----------|
| Coding before plan is architect-approved | Rework when architecture is wrong | Always complete Φ9 before Φ10 |
| Skipping QA scoring | No quality gate; bugs ship | Always run Φ11 with numeric score |
| Architect raises objection without solution | Blocks progress with no path forward | Always provide a solution with every objection |
| More than 3 QA loops | Diminishing returns; likely a PRD problem | Escalate to Eric after 3 failed cycles |
| Feedback files scattered in epic root | Can't find anything; naming chaos | Always use `feedback/` subfolder |

---

## Part 6: Templates Quick Reference

| Template | Location | Used In Phase |
|----------|----------|--------------|
| Epic Overview | `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md` | Φ2, Φ7 |
| PRD | `knowledge_base/templates/PRD-template.md` | Φ4, Φ7 |
| Implementation Status | `knowledge_base/templates/0001-IMPLEMENTATION-STATUS-template.md` | Φ7, Φ12 |
| Pre-QA Checklist | `knowledge_base/templates/pre-qa-checklist-template.md` | Φ10 (before Φ11) |
| Agent Task Log | `knowledge_base/ai-instructions/task-log-requirement.md` | Φ12 |
| Retrospective Report | `knowledge_base/templates/retrospective-report-template.md` | Φ14 |

---

## Part 7: Quick Checklists

### Before starting any phase, the responsible actor must confirm:

**Coding Agent — Before Φ7 (PRD Breakout):**
- [ ] I have read the consolidated epic document
- [ ] I have read ALL feedback/response documents
- [ ] I understand which decisions are locked in

**Coding Agent — Before Φ10 (Implementation):**
- [ ] The implementation plan has been architect-approved (Φ9)
- [ ] I have the individual PRD files with acceptance criteria
- [ ] I know the dependency order (which PRD first)

**QA Agent — Before Φ11 (Validation):**
- [ ] I have the original PRD files with acceptance criteria
- [ ] I have the architect-approved implementation plan
- [ ] I have access to the implemented code and tests
- [ ] I know the scoring rubric (Part 2, Φ11)

**Architect Agent — Before Φ5 (Review):**
- [ ] I have the full consolidated epic + PRD document
- [ ] I will provide solutions with every objection
- [ ] I will organize feedback as Questions / Suggestions / Objections

---

## Part 8: Summary Flow (One Page)

```
Eric has idea (Φ1)
  → Eric + Reasoning AI draft epic (2-3 sentence PRD summaries) (Φ2)
    → Eric approves structure (Φ3)
      → Reasoning AI expands into full consolidated doc (Φ4)
        → Architect reviews → feedback doc (Φ5)
          → Eric + Reasoning AI respond (1-2 cycles) (Φ6)
            → Coding Agent breaks out PRD files + creates status tracker (Φ7)
              → Coding Agent writes implementation plan (Φ8)
                → ★ Architect scores plan (must approve) (Φ9)
                  → Coding Agent implements (Rails Lead) (Φ10)
                    → ★ QA scores 0-100 (must get ≥90, max 3 tries) (Φ11)
                      → Task log + status update (Φ12)
                        → End-of-epic report → Eric smoke test (Φ13)
                          → Retrospective & pattern analysis (every 3-5 epics) (Φ14)
                            → Move to completed/ → Next epic (Φ15)
```

---

## Part 9: Pre-QA Checklist (Continuous Improvement)

**Purpose:** Catch common failure patterns BEFORE QA submission to improve first-attempt pass rates.

**Location:** `knowledge_base/templates/pre-qa-checklist.md`

**When:** Lead Developer runs this checklist immediately before submitting work to QA Agent (Φ11)

### Mandatory Checklist Items (Based on Retrospective Analysis)

#### 1. Code Quality & Linting
- [ ] **RuboCop Clean**: Run `rubocop -A` on ALL modified files (source + tests). Zero offenses.
  - Command: `rubocop -A app/ lib/ test/ --only-recognized-file-types`
  - Include RuboCop output in commit message or task log as proof
  - **Deduction if failed:** -5 to -8 points

#### 2. Test Coverage & Completeness
- [ ] **All Planned Tests Implemented**: Every test in the implementation plan is written (no skips, no stubs)
  - Cross-reference implementation plan test checklist
  - If a test cannot be implemented, document blocker AND provide alternative
  - **Deduction if failed:** -8 to -15 points
- [ ] **Test Suite Passes**: Run full test suite: `rails test` or `rake test`
  - 0 failures, 0 errors, 0 skips on PRD-specific tests
  - Include test summary output in task log
  - **Deduction if failed:** -10 to -20 points
- [ ] **Edge Case Coverage**: Every `rescue` block and error class has a test that triggers it
  - Grep for `rescue` and `raise` — verify each has corresponding test
  - **Deduction if failed:** -2 to -5 points

#### 3. Ruby Standards
- [ ] **`frozen_string_literal: true`**: Every `.rb` file starts with this pragma (line 1)
  - Verify command: `grep -rL 'frozen_string_literal' lib/ app/ test/ --include='*.rb'`
  - No exceptions: source files, test files, Rakefiles, migrations, support files
  - **Deduction if failed:** -1 to -3 points

#### 4. Rails-Specific (if applicable)
- [ ] **Migration Integrity**: Migrations work from scratch
  - Run: `rails db:drop db:create db:migrate db:seed`
  - Include output in task log
  - Never edit committed migrations — create new ones
  - **Deduction if failed:** -5 to -8 points
- [ ] **Model Association Tests**: New associations have corresponding tests
  - Check `has_many`, `belongs_to`, `has_one` additions
  - **Deduction if failed:** -3 to -5 points

#### 5. Architecture & Design
- [ ] **No Dead Code**: Every defined error class, rescue block, or code path is exercised
  - Search for unreachable code, unused variables, shadowed variables
  - **Deduction if failed:** -2 to -5 points
- [ ] **Mock/Stub Compatibility**: Mocks return same structure as real implementations
  - If you created test doubles, verify they match production return types
  - **Deduction if failed:** -3 to -5 points

#### 6. Documentation & Manual Testing
- [ ] **Manual Test Steps Work**: Run through manual verification steps from PRD
  - Document results in task log
  - Screenshot or output evidence for critical features
- [ ] **Acceptance Criteria Verified**: Every AC in every PRD has been checked off
  - Create AC checklist and mark each explicitly

### Checklist Output Template

Create file: `{epic-dir}/feedback/pre-qa-checklist-PRD-{id}.md`

```markdown
# Pre-QA Checklist: PRD-{ID}
**Date:** YYYY-MM-DD
**Submitted by:** Lead Developer

## 1. Code Quality & Linting
- [x] RuboCop clean (0 offenses)
  - Output: [paste rubocop summary]

## 2. Test Coverage & Completeness  
- [x] All planned tests implemented
  - Missing: None
- [x] Test suite passes (0 failures, 0 errors, 0 skips)
  - Output: [paste test summary]
- [x] Edge cases covered
  - Error paths tested: [list]

## 3. Ruby Standards
- [x] frozen_string_literal on all files
  - Verified with grep: 0 missing

## 4. Rails-Specific
- [x] Migrations work from scratch
  - Output: [paste db:migrate output]
- [x] Association tests present

## 5. Architecture & Design
- [x] No dead code
  - All rescue/raise blocks tested
- [x] Mock compatibility verified

## 6. Documentation & Manual Testing
- [x] Manual test steps completed
  - Results: [summary]
- [x] All acceptance criteria met
  - AC checklist: [link or inline]

## Ready for QA: YES/NO
```

### Evolution of the Checklist

This checklist is **living documentation** — it grows based on Retrospective findings (Φ14):

1. **After each retrospective**, add new items for recurring patterns
2. **Track metrics**: % of pre-QA checklists that catch issues vs slip through
3. **Remove items** that haven't triggered in 10+ PRDs (false positives)
4. **Refine thresholds** based on actual score impacts
