# Epic & PRD Document Standards — Best Practices

**Created:** February 20, 2026
**Derived from:** Analysis of ~200 PRDs, ~60 Epics, ~50 feedback docs, test plans, and implementation status trackers across `knowledge_base/epics/completed/` and `knowledge_base/epics/wip/`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Directory Structure Standard](#2-directory-structure-standard)
3. [Document Types & Templates](#3-document-types--templates)
4. [Epic Document Standard](#4-epic-document-standard)
5. [PRD Document Standard](#5-prd-document-standard)
6. [Feedback Document Standard](#6-feedback-document-standard)
7. [Implementation Status Standard](#7-implementation-status-standard)
8. [Test Plan Standard](#8-test-plan-standard)
9. [Naming Conventions](#9-naming-conventions)
10. [Review of Current State — What's Good & What Needs Work](#10-review-of-current-state)
11. [Migration Recommendations](#11-migration-recommendations)

---

## 1. Executive Summary

### What works well (keep doing)
- **Numbered PRD ordering** (`0010`, `0020`, `0030`) — enables clear dependency chains
- **Epic overview as `0000-*.md`** — always the first file alphabetically
- **Acceptance criteria in PRDs** — present in nearly all PRDs, good habit
- **Feedback docs** — capturing end-of-epic learnings is valuable
- **Implementation status trackers** — `0001-IMPLEMENTATION-STATUS.md` in WIP epics is excellent
- **Cross-references** between PRDs (Dependencies, Blocked By, Blocks)

### What needs standardization
- **Inconsistent naming** — some use `0000-Epic.md`, others `AGENT-04-Epic.md`, others `EPIC-4.5.md`
- **Inconsistent structure** — early PRDs (AGENT-01) are walls of text; later ones (Epic 5) have clean sections
- **Feedback naming chaos** — `feedback.md`, `Feedback.md`, `agent-feedback.md`, `end-of-epic-feedback.md`, `feedback-agent.md`, `eric-grok.feedback.md`
- **Supporting docs scattered** — some in `supporting-document/`, some in `background/`, some in root
- **No consistent "done" checklist** in completed epics
- **Missing test plans** in many completed epics
- **EOPRD (End-of-PRD) docs** appear inconsistently — good concept, needs standardization

---

## 2. Directory Structure Standard

### Canonical Layout

```
knowledge_base/epics/
  ├── completed/                        # Finished epics (moved here after completion)
  │   └── {EPIC-ID}/                    # e.g., Agent-Hub-05-Smart-Command-Model/
  │       ├── 0000-epic.md              # Epic overview (ALWAYS present)
  │       ├── 0001-implementation-status.md  # Final status snapshot
  │       ├── PRD-{ID}-{slug}.md        # Atomic PRDs (numbered by priority)
  │       ├── feedback/                  # All feedback in one subfolder
  │       │   ├── end-of-epic-report.md  # Summary of learnings
  │       │   ├── prd-{id}-feedback.md   # Per-PRD feedback (if any)
  │       │   └── review-{source}.md     # Reviews (e.g., review-agent.md, review-eric.md)
  │       ├── testing/                   # Test artifacts in one subfolder
  │       │   ├── test-plan.md           # Overall epic test plan
  │       │   └── manual-test-results.md # Manual smoke test results
  │       └── supporting/               # Reference docs, research, spikes
  │           └── *.md
  │
  ├── wip/                              # In-progress epics
  │   └── {STREAM}/{EPIC-ID}/           # e.g., NextGen/Epic-5-Holdings-Grid/
  │       ├── (same structure as above)
  │       └── 0001-implementation-status.md  # REQUIRED — updated after each PRD
  │
  └── backlog/                          # Planned but not started
      └── {EPIC-ID}/
          ├── 0000-epic.md              # At minimum, the epic overview
          └── *.md                      # Draft PRDs, research
```

### Rules
1. **One folder per epic** — never put an epic's PRDs loose in a parent folder
2. **`0000-epic.md` is mandatory** — always the overview document
3. **`0001-implementation-status.md` is mandatory for WIP** — updated after each PRD completion
4. **Feedback goes in `feedback/`** — not in root alongside PRDs
5. **Tests go in `testing/`** — not mixed with PRDs
6. **Supporting research goes in `supporting/`** — not in root
7. **Move to `completed/` when done** — don't leave finished work in `wip/`

---

## 3. Document Types & Templates

| Type | Filename Pattern | Required? | Purpose |
|------|-----------------|-----------|---------|
| Epic Overview | `0000-epic.md` | **Yes** | Goal, scope, PRD table, dependencies, risks |
| Implementation Status | `0001-implementation-status.md` | **Yes (WIP)** | Live tracker of PRD completion |
| PRD | `PRD-{epic-id}-{seq}-{slug}.md` | **Yes** | Atomic unit of work |
| End-of-Epic Report | `feedback/end-of-epic-report.md` | **Yes (completed)** | Observations, suggestions, learnings |
| Per-PRD Feedback | `feedback/prd-{seq}-feedback.md` | Optional | Feedback on specific PRD |
| Test Plan | `testing/test-plan.md` | Recommended | Post-epic validation cases |
| Manual Test Results | `testing/manual-test-results.md` | Recommended | Actual test execution results |
| EOPRD (End-of-PRD) | `PRD-{id}-EOPRD.md` | Optional | Post-implementation delta/learnings per PRD |
| Supporting Docs | `supporting/*.md` | Optional | Research, spikes, comparisons |

---

## 4. Epic Document Standard

### Filename: `0000-epic.md`

### Required Sections

```markdown
# Epic {ID}: {Title}

## Goal
One paragraph: what this epic delivers and why it matters.

## Business Value
Who benefits and how. Tie to product vision.

## Scope
What IS included.

## Non-Goals / Out of Scope
What is explicitly NOT included.

## Dependencies
Which epics/PRDs/systems must exist first.

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|

## Core Principles / Key Decisions
Bullet list of architectural and UX decisions made during planning.
(Include feedback from reviews that changed the approach.)

## PRD Table
| Priority | PRD ID | Title | Status | Dependencies | Blocks |
|----------|--------|-------|--------|-------------|--------|
| 1 | PRD-{epic}-01 | {title} | Not Started | None | PRD-02 |
| 2 | PRD-{epic}-02 | {title} | Not Started | PRD-01 | PRD-03 |

## End-of-Epic Capabilities
Bullet list: what a user/agent CAN DO after all PRDs are complete.

## Post-Epic Validation
Link to `testing/test-plan.md` or inline test scenarios.
```

### What the best epics do (model: Epic-5, Agent-Hub-09)
- **Extensive key decisions section** with rationale (Epic-5 has 40+ decisions from feedback rounds)
- **Column-level specs** for data-heavy features
- **Database schema** included directly when relevant
- **Style guide** section for UI epics
- **Traceability** to vision docs and prior feedback

### What weak epics do (avoid)
- Omit scope/non-goals (AGENT-02C — leads to scope creep)
- Wall-of-text requirements without sections (AGENT-01 PRDs)
- No PRD table — just prose describing what to build
- Mix implementation details into the epic (belongs in PRDs)

---

## 5. PRD Document Standard

### Filename: `PRD-{epic-id}-{seq}-{slug}.md`

Examples:
- `PRD-5-03-core-table-pagination.md`
- `PRD-AH-009B-artifact-store.md`
- `PRD-8-01-gitignore-env-example.md`

### Required Sections

```markdown
# PRD {Epic}-{Seq}: {Title}

## Log Requirements
Agent: Read `<project root>/knowledge_base/ai-instructions/task-log-requirement.md`
and log your plan/questions.

## Overview
2-3 sentences: what this PRD delivers and why.

## User Story (if applicable)
As a {role}, I can {action}, so that {benefit}.

## Requirements

### Functional
- Bullet list of what the system must do
- Be specific: routes, models, services, UI elements

### Non-Functional
- Performance, security, accessibility, responsive design

## Architectural Context
Where this fits: which models/services/controllers are affected.
Reference existing patterns in the codebase.

## Acceptance Criteria
- AC1: {Specific, testable statement}
- AC2: ...
(Use checkboxes in WIP: `- [ ] AC1: ...`)

## Test Cases
- **Unit**: Model/service-level tests
- **Integration**: Controller/end-to-end
- **Capybara/System**: Browser-level tests (if UI)
- **Edge cases**: Boundary conditions, error states

## Manual Testing Steps
Numbered steps a human can follow to verify.
Include expected results for each step.

## Dependencies
- PRD-{id} must be complete (link)

## Blocked By
- {What must exist before this can start}

## Blocks
- {What cannot start until this is done}

## Workflow
Agent: {model preference}. Branch: `feature/{branch-name}`.
Plan before code. Commit green only.
```

### Quality Tiers Observed

| Tier | Example | Quality | Issue |
|------|---------|---------|-------|
| **Gold** | PRD-5-03, PRD-AH-009B | Complete sections, manual test steps, dependency chain, edge cases | — |
| **Silver** | PRD-AH-005A, PRD-AH-006A | Has all sections but some are terse ("Fast." for non-functional) | Flesh out non-functional requirements |
| **Bronze** | PRD AGENT-01, PRD AGENT-02 | Wall of text, no clear sections, requirements buried in prose | Needs restructuring |

### PRD Anti-Patterns (observed in codebase)
1. **The Wall** — PRD AGENT-01 is a single unbroken block of text. Hard for both humans and agents to parse.
2. **Missing Manual Test Steps** — About 40% of completed PRDs lack manual verification steps.
3. **Vague Acceptance Criteria** — "Recognizes /." (from PRD-AH-005A). Should be: "Given input `/search nvidia`, the parser returns `{type: :search, args: 'nvidia'}`."
4. **No Dependency Chain** — Early PRDs don't declare what they block/are blocked by, causing ordering confusion.
5. **Mixed Concerns** — Some PRDs include implementation details (specific code) rather than requirements. PRDs should say WHAT, not HOW.

---

## 6. Feedback Document Standard

### Current chaos
The codebase has 50+ feedback files with 12+ naming variations:
`feedback.md`, `Feedback.md`, `agent-feedback.md`, `feedback-agent.md`, `end-of-epic-feedback.md`, `end-of-epic-report.md`, `eric-grok.feedback.md`, `review-feedback-epic-11.md`, `feedback-v2.md`, `final-feedback.md`, `0040-PRD-0-04-feedback.md`, `gap_feedback.md`

### Standard: Two types only

#### 1. End-of-Epic Report: `feedback/end-of-epic-report.md`

```markdown
# End-of-Epic Report: {Epic ID} — {Title}

## Observations
What worked well. Architectural wins. Good patterns established.

## Suggestions
What could be improved. Technical debt created. Future enhancements.

## Capabilities Delivered
- [x] {Capability 1 from epic overview}
- [x] {Capability 2}
- [ ] {Capability 3 — deferred to next epic}

## Manual Verification
| Test | Result | Notes |
|------|--------|-------|
| {Test case} | ✅ Pass / ❌ Fail | {details} |

## Completion Checklist
- [x] All PRDs implemented
- [x] Tests passing
- [x] Manual smoke test completed
- [x] Implementation status updated
- [x] Epic moved to `completed/`
- [ ] Technical debt logged (if any)
```

#### 2. Per-PRD Feedback: `feedback/prd-{seq}-feedback.md`

```markdown
# Feedback: PRD {Epic}-{Seq} — {Title}

## Review Source
{Who reviewed: Eric, Coding Agent, Grok, SAP, etc.}

## Issues Found
- {Issue 1}: {description} → {resolution}

## Changes Made
- {What was adjusted post-implementation}

## Deferred Items
- {What was punted to a future PRD/epic}
```

---

## 7. Implementation Status Standard

### Filename: `0001-implementation-status.md`

### Required for all WIP epics. Updated after each PRD completion.

**Best example in codebase:** `Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md`

```markdown
# {Epic ID}: Implementation Status

**Epic**: {Epic title}
**Status**: {Not Started | In Progress | Complete}
**Last Updated**: {YYYY-MM-DD}

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Date | Notes |
|-----|-------|--------|--------|--------|------|-------|
| {seq} | {title} | {Not Started / In Progress / Implemented / Blocked} | {branch} | {Yes/No} | {date} | {notes} |

## Key Decisions Made During Implementation
- {Decision and rationale — captures deviations from the PRD}

## Blockers
- {Current blockers, if any}

## Technical Debt
- {Shortcuts taken that need future cleanup}
```

---

## 8. Test Plan Standard

### Filename: `testing/test-plan.md`

**Best example:** `Agent-Hub-09/test-plan.md`

```markdown
# Test Plan: {Epic ID} — {Title}

## Scope
What this test plan validates.

## Prerequisites
- Environment setup, data requirements, running services

## Test Cases

### {Category 1}: {e.g., System Readiness}

| # | Test | Steps | Expected Result | Status |
|---|------|-------|-----------------|--------|
| 1 | {name} | {steps} | {expected} | ⬜ |

### {Category 2}: {e.g., Happy Path}

| # | Test | Steps | Expected Result | Status |
|---|------|-------|-----------------|--------|
| 2 | {name} | {steps} | {expected} | ⬜ |

### {Category 3}: {e.g., Edge Cases / Error Handling}

| # | Test | Steps | Expected Result | Status |
|---|------|-------|-----------------|--------|
| 3 | {name} | {steps} | {expected} | ⬜ |

## CLI Alternatives
{For tests that can be run from console/rake}
```

---

## 9. Naming Conventions

### Epic Folder Names

**Pattern:** `{ID}-{Descriptive-Slug}`

| ✅ Good | ❌ Avoid |
|---------|----------|
| `Agent-Hub-05-Smart-Command-Model` | `AGENT-05` (too cryptic) |
| `Epic-5-Holdings-Grid` | `Epic-5` (what is Epic 5?) |
| `AGENT-02C` (OK if well-known series) | `ollama-tool-use` (no ID prefix) |

**Rules:**
- Always include a numeric/alphanumeric ID
- Always include a human-readable slug
- Use kebab-case (hyphens, not spaces or underscores)

### PRD Filenames

**Pattern:** `PRD-{epic-id}-{seq}-{slug}.md`

| ✅ Good | ❌ Avoid |
|---------|----------|
| `PRD-5-03-core-table-pagination.md` | `0030-PRD-3-12.md` (redundant numbering) |
| `PRD-AH-009B-artifact-store.md` | `PRD AGENT-01.md` (spaces in filenames) |
| `PRD-8-01-gitignore-env-example.md` | `Agenti-PRD-Generation.md` (no ID) |

**Rules:**
- No spaces in filenames (use hyphens)
- Include the epic ID prefix for traceability
- Lowercase kebab-case for slugs
- Sequential numbering: `01`, `02`, ... (or `A`, `B`, `C` for sub-PRDs)

### Document Filenames

| Type | Pattern |
|------|---------|
| Epic overview | `0000-epic.md` |
| Implementation status | `0001-implementation-status.md` |
| PRD | `PRD-{epic}-{seq}-{slug}.md` |
| End-of-epic report | `feedback/end-of-epic-report.md` |
| Per-PRD feedback | `feedback/prd-{seq}-feedback.md` |
| Test plan | `testing/test-plan.md` |
| Manual test results | `testing/manual-test-results.md` |
| Supporting docs | `supporting/{descriptive-name}.md` |

---

## 10. Review of Current State

### Completed Epics — Audit

| Epic | Structure | PRD Quality | Feedback | Test Artifacts | Rating |
|------|-----------|-------------|----------|---------------|--------|
| **Agent-Hub-05** | ✅ Clean: `0000-Epic.md` + 3 PRDs + feedback | 🟡 Silver (terse sections) | ✅ Good end-of-epic report | ❌ No test plan | ⭐⭐⭐ |
| **Agent-Hub-06** | ✅ Clean: `0000-Epic.md` + 5 PRDs + feedback/ | 🟢 Gold | ✅ Detailed end-of-epic report | ❌ No test plan | ⭐⭐⭐⭐ |
| **Agent-Hub-09** | ✅ Clean: `0000-Epic.md` + 5 PRDs + test plan | 🟢 Gold | ✅ Feedback + test guide | ✅ test-plan.md | ⭐⭐⭐⭐⭐ |
| **Agent-Hub-11** | 🟡 Mixed: good PRDs but also loose supporting docs | 🟢 Gold | ✅ Review feedback | ✅ Test plan | ⭐⭐⭐⭐ |
| **Agent-Hub-12** | 🟡 Mixed: PRDs + EOPRDs + scratch + learning docs all in root | 🟢 Gold (has EOPRDs) | ✅ Agent feedback | ❌ Scattered | ⭐⭐⭐ |
| **AGENT-02A** | 🟡 OK: overview + 4 PRDs + feedback | 🟡 Silver | ✅ Feedback.md | ❌ No tests | ⭐⭐⭐ |
| **AGENT-02B** | 🟡 OK: 4 PRDs + feedback + impl plan | 🟡 Silver | ✅ feedback.md | ❌ No tests | ⭐⭐⭐ |
| **AGENT-02C** | ✅ Clean: overview + 4 PRDs + feedback | 🟡 Silver | ✅ Multiple feedbacks | ✅ Manual Test.md | ⭐⭐⭐⭐ |
| **AGENT-03** | ✅ Clean: overview + 5 PRDs + feedback | 🟡 Silver | ✅ Multi-source feedback | ✅ Manual Test.md | ⭐⭐⭐⭐ |
| **AGENT-04** | ✅ Clean: epic + 4 PRDs | 🟡 Silver | ✅ Agent feedback | ❌ No tests | ⭐⭐⭐ |
| **AGENT-05** | ✅ Clean: epic + 6 PRDs + feedback | 🟢 Gold | ✅ Feedback | ✅ Manual Test for 0050D | ⭐⭐⭐⭐ |
| **AGENT-06** | ✅ Clean: overview + 5 PRDs + test artifacts | 🟢 Gold | ✅ Feedback | ✅ test_plan + testing_progress | ⭐⭐⭐⭐⭐ |
| **full-fetch** | ✅ Clean: overview + 6 PRDs | 🟡 Silver | ❌ No feedback | ❌ No tests | ⭐⭐ |
| **SAP Agent** | ✅ Clean: overview + 4 PRDs + review | 🟡 Silver | ✅ Review | ❌ No tests | ⭐⭐⭐ |
| **agents/ (loose PRDs)** | ❌ Loose: 5 PRDs not in epic folders | 🔴 Bronze (walls of text) | ❌ None | ❌ None | ⭐ |
| **refactor** | ✅ Clean: epic + 7 PRDs + impl summary | 🟢 Gold | ❌ No feedback | ❌ No tests | ⭐⭐⭐ |
| **ollama-tool-use** | 🟡 Mixed: epic + 8 PRDs + background/ folder | 🟢 Gold | ✅ Multiple feedbacks | ❌ Scattered | ⭐⭐⭐ |

### WIP Epics — Audit

| Epic | Structure | PRD Quality | Status Tracking | Rating |
|------|-----------|-------------|-----------------|--------|
| **Epic-0** | 🟡 PRDs + many feedback files in root | 🟡 Silver | ❌ No status tracker | ⭐⭐ |
| **Epic-1** | 🟡 17+ PRDs (largest epic) + consolidated doc | 🟡 Silver | ❌ No status tracker | ⭐⭐ |
| **Epic-2** | 🟡 10 PRDs + consolidated + feedbacks in root | 🟢 Gold | ✅ Implementation status | ⭐⭐⭐ |
| **Epic-3** | ✅ Clean: overview + 9 PRDs + supporting/ | 🟢 Gold | ✅ Implementation status | ⭐⭐⭐⭐ |
| **Epic-4** | ✅ Clean: overview + 5 PRDs + docs/ | 🟢 Gold | ✅ Implementation status | ⭐⭐⭐⭐ |
| **Epic-5** | ✅ Excellent: overview + 15 PRDs + supporting/ | 🟢 Gold (best in codebase) | ✅ Detailed status | ⭐⭐⭐⭐⭐ |
| **Epic-6** | 🟡 Smaller: overview + 1 PRD + analysis docs | 🟢 Gold | ❌ No status tracker | ⭐⭐⭐ |
| **Epic-8** | ✅ Clean: overview + 3 PRDs + logs/ | 🟢 Gold | ✅ Implementation status | ⭐⭐⭐⭐ |

### Key Findings

1. **Clear maturity progression** — earliest epics (AGENT-01 era) are walls of text; latest (Epic-5, Agent-Hub-09) are highly structured. The team has naturally converged on good patterns.

2. **Best-in-class examples to emulate:**
   - **Epic structure:** `Epic-5-Holdings-Grid` and `Agent-Hub-09-AgentHub-Workflow-MVP`
   - **PRD structure:** `PRD-5-03-core-table-pagination.md` and `PRD-AH-009B-artifact-store.md`
   - **Feedback:** `Agent-Hub-06/feedback/end-of-epic-report.md`
   - **Test plan:** `Agent-Hub-09/test-plan.md`
   - **Implementation status:** `Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md`

3. **Biggest consistency gaps:**
   - Feedback files scattered in root (should be in `feedback/` subfolder)
   - Supporting docs sometimes in root, sometimes in `supporting/` or `background/`
   - Epic-1 has 17+ PRDs — likely should have been split into sub-epics
   - Some completed epics never got a test plan or end-of-epic report

---

## 11. Migration Recommendations

### Priority 1: Adopt for all NEW epics immediately
- Use the templates in sections 4-8 above
- Enforce directory structure from section 2
- Every WIP epic must have `0001-implementation-status.md`

### Priority 2: Normalize existing WIP epics (low effort)
- Add `0001-implementation-status.md` to Epic-0, Epic-1, Epic-6 (currently missing)
- Move scattered feedback files into `feedback/` subfolders
- Move supporting docs into `supporting/` subfolders

### Priority 3: Retroactively clean completed epics (optional)
- Only if they're frequently referenced for RAG context
- Focus on the loose `agents/PRD AGENT-01.md` through `PRD AGENT-05.md` — these should be in epic folders
- Low priority — completed work is done

### DO NOT
- Rename files that are referenced by other documents without updating all references
- Retroactively restructure completed epics that no one reads anymore
- Over-engineer — the templates above are the maximum structure needed. Smaller epics can skip optional sections.
