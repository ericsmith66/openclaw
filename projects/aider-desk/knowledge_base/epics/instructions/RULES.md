# Epic & PRD Rules — Authoritative Reference

**Status:** Canonical — all AI agents and humans follow these rules
**Last Updated:** February 20, 2026
**Companion docs:** `implied-workflow.md` (full workflow details), `epic-prd-best-practices.md` (audit & history)

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
| **Coding Agent** (Qwen3-Coder, Junie, AiderDesk) | PRD file breakout, implementation planning, coding, testing, task logging | Draft epics, review architecture, score QA |
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
| **Actor** | Coding Agent (Qwen3-Coder latest) |
| **Input** | Architect-approved plan + individual PRD files |
| **Output** | Code, tests, migrations, components |

**Rules:**
1. Follow the architect-approved plan — do not deviate without documenting why
2. Follow these conventions (see also `knowledge_base/epics/instructions/RULES.md`):
   - **Minitest** (never RSpec unless explicitly requested)
   - **ViewComponents** for UI
   - **DaisyUI/Tailwind** for styling
   - **Commit plans always; commit code when tests pass (green)**
   - **Never run destructive DB commands** (drop, reset, truncate) without confirmation
3. Each PRD's acceptance criteria are the definition of done for that PRD
4. Write tests alongside code — not after
5. All code must be green (tests passing) before moving to Φ11

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
1. Create/update task log at `knowledge_base/prds-junie-log/YYYY-MM-DD__task-slug.md`
   - Follow template: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`
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

### Φ14 — Next Epic

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
| QA report (Φ11) | `qa-report.md` | `feedback/` |
| End-of-epic report (Φ13) | `end-of-epic-report.md` | `feedback/` |

### Other Files

| Type | Filename | Required? |
|------|----------|-----------|
| Epic overview | `0000-epic.md` | **Yes — always** |
| Implementation status | `0001-implementation-status.md` | **Yes — all WIP epics** |
| Implementation plan | `implementation-plan.md` | **Yes — before coding** |
| Task log | `knowledge_base/prds-junie-log/YYYY-MM-DD__task-slug.md` | **Yes — per task** |
| Test plan | `testing/test-plan.md` | Recommended |
| Supporting docs | `supporting/*.md` | Optional |

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
| Junie Task Log | `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` | Φ12 |

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
Eric has idea
  → Eric + Reasoning AI draft epic (2-3 sentence PRD summaries)
    → Eric approves structure
      → Reasoning AI expands into full consolidated doc
        → Architect reviews → feedback doc
          → Eric + Reasoning AI respond (1-2 cycles)
            → Coding Agent breaks out PRD files + creates status tracker
              → Coding Agent writes implementation plan
                → ★ Architect scores plan (must approve)
                  → Coding Agent implements (Qwen3-Coder)
                    → ★ QA scores 0-100 (must get ≥90, max 3 tries)
                      → Task log + status update
                        → End-of-epic report → Eric smoke test
                          → Move to completed/ → Next epic
```
