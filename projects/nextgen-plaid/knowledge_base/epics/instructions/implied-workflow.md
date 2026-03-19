# Development Workflow — agent-forge Ecosystem

**Created:** February 20, 2026
**Last Updated:** February 20, 2026
**Status:** Canonical reference — reflects Eric's corrected workflow as of this date
**Derived from:** Eric's direct description + analysis of Vision 2026, .junie/guidelines.md, knowledge_base/templates/, 200+ PRDs, 60+ epics, feedback loops, SDLC stage contracts, and agent architecture

---

## Table of Contents

1. [Overview](#1-overview)
2. [The Five Actors](#2-the-five-actors)
3. [The Workflow (14 Phases)](#3-the-workflow-14-phases)
4. [Phase Details](#4-phase-details)
5. [Scoring Gates](#5-scoring-gates)
6. [Document Flow Summary](#6-document-flow-summary)
7. [Agent SDLC (In-App Automated Loop)](#7-agent-sdlc-in-app-automated-loop)
8. [Key Workflow Rules](#8-key-workflow-rules)
9. [Gaps & Recommendations](#9-gaps--recommendations)

---

## 1. Overview

The agent-forge ecosystem uses a **document-driven, multi-agent SDLC** where five distinct actors collaborate through structured phases with explicit **scoring gates** that enforce quality. The workflow is designed for a single human product owner (Eric) orchestrating multiple specialized AI agents, each with a distinct role.

The core principle: **no actor does everything**. Ideas flow through reasoning, architecture, implementation, and QA as separate concerns handled by separate agents, with Eric as the human-in-the-loop at critical decision points.

---

## 2. The Five Actors

| Actor | Role | Specialty | When Active |
|-------|------|-----------|-------------|
| **Eric** (Human) | Product owner, decision-maker, final approver | Domain knowledge, business judgment, approval gates | Idea origination, epic approval, feedback responses, final acceptance |
| **High-Reasoning AI** (e.g., Grok, Claude) | Co-architect, epic designer, PRD author | Deep reasoning, structured document generation, question-asking | Epic drafting, PRD expansion, feedback response synthesis |
| **Architect Agent** | Reviewer, critic, plan scorer | Architecture review, objections with solutions, plan scoring | Epic review cycles, implementation plan scoring |
| **Coding Agent** (e.g., Qwen3-Coder, Junie, AiderDesk) | Implementer, plan builder | Code writing, test writing, PRD file breakout, detailed planning | PRD file creation, implementation planning, code implementation |
| **QA Agent** | Validator, test coverage auditor, effort scorer | Test verification, coverage analysis, quality scoring | Post-implementation validation, scoring (0-100 gate) |

### Actor Relationships

```
Eric (Human)
  │
  ├──► High-Reasoning AI    (thinks with Eric, produces documents)
  │         │
  │         ▼
  │    Architect Agent       (reviews, questions, scores)
  │         │
  │         ▼
  │    Coding Agent          (breaks out files, plans, implements)
  │         │
  │         ▼
  └──► QA Agent              (validates, scores, gates)
              │
              └──► Back to Coding Agent (if score < 90)
```

---

## 3. The Workflow (14 Phases)

```
┌─────────────────────────────────────────────────────────────────┐
│  Φ1  IDEA                                                       │
│  Eric has an idea                                               │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ2  EPIC DRAFTING (Atomic PRD Summaries)                       │
│  Eric + High-Reasoning AI → Epic with 2-3 sentence PRD stubs   │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ3  ERIC APPROVAL OF PRELIMINARY EPIC                          │
│  Eric reviews, tweaks, approves the structure                   │
│  (Loop back to Φ2 if not right)                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ4  FULL EXPANSION                                             │
│  High-Reasoning AI → Expands summaries into full epic + PRDs    │
│  (One consolidated document: epic overview + detailed PRDs)     │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ5  ARCHITECT REVIEW                                           │
│  Architect Agent → Reviews, questions, objections + solutions   │
│  Output: feedback document                                      │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ6  FEEDBACK RESPONSE                                          │
│  Eric + High-Reasoning AI → Response doc with inline answers    │
│  (Repeat Φ5-Φ6 for 1-2 cycles until all parties satisfied)     │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ7  PRD BREAKOUT + EPIC UPDATE                                 │
│  Coding Agent → Updates epic doc, breaks each PRD into own file │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ8  IMPLEMENTATION WRITEN PLAN                                 │
│  Coding Agent → Detailed plan to implement the epic             │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ9  PLAN REVIEW + SCORING                                      │
│  Architect Agent → Reviews, modifies, SCORES the plan           │
│  ★ SCORING GATE: Architect must approve plan before coding      │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ10 IMPLEMENTATION                                             │
│  Coding Agent (Qwen3-Coder) → Writes code, tests, migrations   │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ11 QA VALIDATION + SCORING                                    │
│  QA Agent → Validates plan compliance + test coverage           │
│  ★ SCORING GATE: Score 0-100. Must achieve ≥90 to pass.        │
│  If < 90 → kick back to Coding Agent (Φ10) to address gaps     │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ12 TASK LOGGING + STATUS UPDATE                               │
│  Coding Agent → Task log + update implementation status         │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ13 EPIC CLOSEOUT                                              │
│  End-of-epic report, final smoke test, move to completed/  ERIC  Manual verification     │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Φ14 NEXT EPIC                                                  │
│  Eric → Evaluate backlog, select next, return to Φ1             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Phase Details

### Φ1 — Idea

**Actor:** Eric
**Output:** Rough idea (verbal, notes, or chat message)
**Duration:** Minutes

Eric identifies a need — from the product vision, a production pain point, a user request, or a new capability he wants. This is informal and unstructured. The idea could be a sentence or a paragraph.

**Examples from the codebase:**
- "I need a holdings grid for investment accounts"
- "SAP agent needs code review capability"
- "We need a shared task manager across all apps"

---

### Φ2 — Epic Drafting (Atomic PRD Summaries)

**Actors:** Eric + High-Reasoning AI
**Output:** Preliminary epic with PRD summary table
**Duration:** 1 session (30-60 min)

Eric collaborates with a high-reasoning AI (Grok, Claude, etc.) to transform the rough idea into a structured epic. At this stage, PRDs are intentionally kept to **2-3 sentence summaries** — just enough to define the atomic units of work.

**What gets produced:**
- Epic goal and business value
- Scope and non-goals
- PRD summary table:

| # | PRD Title | Summary (2-3 sentences) |
|---|-----------|------------------------|
| 01 | Saved Account Filters | Create a reusable filter model that persists user-defined account groupings. Filters apply across holdings, net worth, and transaction views. |
| 02 | Data Provider Service | Service object that queries holdings with filtering, sorting, pagination, and caching. Supports both live and snapshot modes. |
| 03 | Core Table + Pagination | Main grid view with pagination, per-page selector, and summary cards showing full-dataset totals. |

**Key principle:** Keep it lightweight. This is a skeleton, not the final document. The goal is to get the **structure and sequencing** right before investing in detail.

---

### Φ3 — Eric Approval of Preliminary Epic

**Actor:** Eric
**Output:** Approved (possibly tweaked) epic skeleton
**Duration:** Minutes to hours

Eric reviews the preliminary epic and either:
- **Approves** it as-is → proceed to Φ4
- **Tweaks** it (reorders PRDs, adjusts scope, splits/merges items) → revised, then approved
- **Rejects** it → back to Φ2 with new direction

**This is the first human gate.** No work proceeds until Eric is satisfied with the atomic breakdown and sequencing.

---

### Φ4 — Full Expansion

**Actors:** Eric + High-Reasoning AI
**Output:** One consolidated document containing the full epic overview + fully detailed PRDs
**Duration:** 1-2 sessions

Once the skeleton is approved, the High-Reasoning AI expands every 2-3 sentence summary into a fully detailed PRD with:
- Overview and user story
- Functional and non-functional requirements
- Architectural context
- Acceptance criteria
- Test cases
- Manual testing steps
- Dependencies (blocked by / blocks)

**Important:** At this stage, the output is **one consolidated document** — the epic and all its PRDs live together in a single file. The breakout into individual files happens later (Φ7).

**Template reference:** `knowledge_base/templates/PRD-template.md`

---

### Φ5 — Architect Review

**Actor:** Architect Agent
**Input:** The consolidated epic + PRD document from Φ4
**Output:** Feedback document
**Duration:** 1 session

The Architect Agent reviews the entire document and produces a structured feedback file containing:
- **Questions** — clarifications needed ("What happens if security_id is missing?")
- **Suggestions** — improvements ("Consider pg_trgm indexes for search performance")
- **Objections** — design concerns ("The 4h cache TTL is too long for live portfolio data")

**Critical rule:** The Architect **always provides potential solutions** alongside objections. It never just says "this is wrong" — it says "this is wrong, and here's how to fix it."

**Output filename pattern:** `{epic-name}-feedback-V{N}.md`

---

### Φ6 — Feedback Response

**Actors:** Eric + High-Reasoning AI
**Input:** Architect's feedback document
**Output:** Response document with inline answers
**Duration:** 1 session per cycle

Eric and the High-Reasoning AI review the Architect's feedback together and produce a response document with answers inline. Eric provides domain decisions; the AI helps articulate and integrate them.

**Inline format observed:**
```markdown
**Architect Question:** What's the cache key strategy for filter combinations?
**Eric + AI Response:** SHA256 of sorted params JSON. Key format:
`holdings_totals:v1:user:#{user_id}:filters:#{SHA256}:snapshot:#{id||'live'}`
with 1h TTL and after_commit invalidation.
```

**This cycle repeats 1-2 times** (Φ5 → Φ6 → Φ5 → Φ6) until all parties are satisfied:
- Architect has no remaining objections
- Eric has locked in all key decisions
- The document is comprehensive enough for implementation

**Output filename pattern:** `{epic-name}-comments-V{N}.md`

---

### Φ7 — PRD Breakout + Epic Update

**Actor:** Coding Agent
**Input:** Finalized consolidated document + all feedback/response docs
**Output:** Updated epic overview file + individual PRD files
**Duration:** 1 session

The Coding Agent performs two tasks:

1. **Updates the epic overview** (`0000-epic.md`) to reflect all decisions locked in during the review cycles — integrating answers from the feedback responses into a "Key Decisions" section

2. **Breaks each PRD into its own file** following the naming convention:
   - `PRD-{epic}-01-{slug}.md`
   - `PRD-{epic}-02-{slug}.md`
   - etc.

**This is also when `0001-IMPLEMENTATION-STATUS.md` is created** with all PRDs listed as "Not Started."

---

### Φ8 — Implementation Plan

**Actor:** Coding Agent
**Output:** Detailed implementation plan document
**Duration:** 1 session

Before writing any code, the Coding Agent produces a **detailed implementation plan** covering:
- File-by-file changes planned
- Models, migrations, services, controllers, components to create/modify
- Test strategy (which test types for which components)
- Dependency order (which PRD first, what unblocks what)
- Risk areas and mitigation

**This plan is the contract** between the Coding Agent and the Architect. It must be reviewed and scored before coding begins.

---

### Φ9 — Plan Review + Scoring (★ ARCHITECT GATE)

**Actor:** Architect Agent
**Input:** Implementation plan from Φ8
**Output:** Reviewed/modified plan + **score**
**Duration:** 1 session

The Architect Agent reviews the implementation plan and:
- **Modifies** it if needed (reorders steps, adds missing considerations, flags risks)
- **Scores** the plan

**★ This is a scoring gate.** The Architect must approve the plan before the Coding Agent proceeds. If the plan is fundamentally flawed, it goes back to the Coding Agent for revision.

**Scoring criteria (Architect):**
- Completeness — does the plan cover all PRD requirements?
- Architecture alignment — does it follow established patterns?
- Risk awareness — are edge cases and failure modes addressed?
- Test strategy — is coverage appropriate?
- Dependency ordering — will things build in the right sequence?

---

### Φ10 — Implementation

**Actor:** Coding Agent (Qwen3-Coder latest)
**Input:** Architect-approved implementation plan + individual PRD files
**Output:** Code, tests, migrations, components
**Duration:** Hours to days per PRD
**Rules:** `.junie/guidelines.md`

The Coding Agent implements the code following:
1. The architect-approved plan
2. The individual PRD acceptance criteria
3. Project conventions (`.junie/guidelines.md`):
   - Minitest (not RSpec)
   - ViewComponents for UI
   - DaisyUI/Tailwind for styling
   - Never commit without human request
   - Never run destructive DB commands without confirmation

**Model:** Qwen3-Coder (latest) is the current preferred coding model.

---

### Φ11 — QA Validation + Scoring (★ QUALITY GATE)

**Actor:** QA Agent
**Input:** Implemented code + original PRDs + implementation plan
**Output:** Validation report + **score (0-100)**
**Duration:** 1 session per PRD or per epic

The QA Agent validates:
1. **Plan compliance** — was the architect-approved plan actually followed?
2. **PRD compliance** — do acceptance criteria pass?
3. **Test coverage** — are there appropriate unit, integration, and system tests?
4. **Code quality** — are patterns followed, edge cases handled?

**★ SCORING GATE:**

| Score | Outcome |
|-------|---------|
| **≥ 90** | ✅ **Pass** — proceed to Φ12 |
| **< 90** | ❌ **Fail** — kicked back to Coding Agent (Φ10) with specific gaps to address |

**The QA Agent must identify exactly what's missing** — it doesn't just say "72/100." It provides:
- Which acceptance criteria are unmet
- Which test coverage gaps exist
- Which code quality issues need fixing
- Specific remediation steps

**The Coding Agent addresses the gaps and resubmits for QA.** This loop (Φ10 → Φ11 → Φ10 → Φ11) repeats until ≥ 90 is achieved.

---

### Φ12 — Task Logging + Status Update

**Actor:** Coding Agent
**Artifacts:**
- Task log: `knowledge_base/prds-junie-log/YYYY-MM-DD__task-slug.md`
- Status: `0001-IMPLEMENTATION-STATUS.md`

After QA passes (≥ 90), the Coding Agent:

1. **Creates/updates the Junie Task Log** with:
   - Goal, context, plan
   - Work log (chronological)
   - Files changed, commands run
   - Tests run + results
   - Decisions & rationale
   - Manual verification steps
   - Commits

2. **Updates Implementation Status** tracker:
   - PRD status → Implemented
   - QA score recorded
   - Branch name, completion date, notes

---

### Φ13 — Epic Closeout

**Actors:** QA Agent (report), Eric (final approval)
**Artifacts:** `feedback/end-of-epic-report.md`

When all PRDs in an epic have passed QA:

1. **End-of-epic report** generated with:
   - Observations (what worked well)
   - Suggestions (what could improve)
   - Capabilities delivered (checklist)
   - All QA scores summary
   - Manual verification results

2. **Eric's final smoke test** — runs through post-epic test plan

3. **Epic moved** from `wip/` to `completed/`

4. **Implementation status** finalized — all PRDs marked complete, all branches merged

---

### Φ14 — Next Epic

**Actor:** Eric
**Inputs:** Vision 2026, backlog, production state, user feedback

Eric evaluates the backlog and selects the next epic. Returns to Φ1.

---

## 5. Scoring Gates

The workflow has **two explicit scoring gates** that enforce quality:

### Gate 1: Architect Plan Score (Φ9)

```
                    Coding Agent
                         │
                    Detailed Plan
                         │
                         ▼
                  ┌──────────────┐
                  │  Architect   │
                  │  Review +    │──── Score + Modifications
                  │  Score       │
                  └──────┬───────┘
                         │
                    ┌────▼────┐
                    │ Approved │──── ✅ Proceed to Φ10
                    │  Plan?   │
                    └────┬────┘
                         │ No
                         ▼
                  Back to Coding Agent (Φ8)
```

### Gate 2: QA Score (Φ11)

```
                    Coding Agent
                         │
                    Implemented Code
                         │
                         ▼
                  ┌──────────────┐
                  │  QA Agent    │
                  │  Validate +  │──── Score 0-100
                  │  Score       │
                  └──────┬───────┘
                         │
                    ┌────▼────┐
                    │ ≥ 90 ?  │──── ✅ Pass → Φ12
                    └────┬────┘
                         │ No (< 90)
                         ▼
                  Back to Coding Agent (Φ10)
                  with specific gaps identified
```

### Scoring Summary

| Gate | Actor | Scoring | Pass Threshold | Fail Action |
|------|-------|---------|---------------|-------------|
| Architect Plan Review | Architect Agent | Plan quality score | Architect approval | Revise plan (Φ8) |
| QA Validation | QA Agent | 0-100 numeric score | ≥ 90 | Fix gaps, resubmit (Φ10) |

---

## 6. Document Flow Summary

```
Φ1  Eric's Idea (informal)
     │
Φ2  ├──► Preliminary Epic (2-3 sentence PRD summaries)
     │    [Eric + High-Reasoning AI]
     │
Φ3  ├──► Eric Approval (tweak or approve)
     │
Φ4  ├──► Consolidated Epic + Full PRDs (one document)
     │    [Eric + High-Reasoning AI]
     │
Φ5  ├──► Architect Feedback doc (questions, objections + solutions)
     │    [Architect Agent]
     │
Φ6  ├──► Response doc (Eric answers inline)
     │    [Eric + High-Reasoning AI]
     │    (Repeat Φ5-Φ6 for 1-2 cycles)
     │
Φ7  ├──► Updated 0000-epic.md + individual PRD-*.md files
     │    + 0001-IMPLEMENTATION-STATUS.md
     │    [Coding Agent]
     │
Φ8  ├──► Implementation Plan document
     │    [Coding Agent]
     │
Φ9  ├──► ★ Architect scores plan → approved or revision
     │    [Architect Agent]
     │
Φ10 ├──► Code + Tests + Migrations
     │    [Coding Agent — Qwen3-Coder]
     │
Φ11 ├──► ★ QA scores 0-100 → ≥90 pass or kick back
     │    [QA Agent]
     │
Φ12 ├──► Task Log + Implementation Status Update
     │    [Coding Agent]
     │
Φ13 ├──► End-of-Epic Report → Eric smoke test → move to completed/
     │
Φ14 └──► Next Epic (Eric selects from backlog → Φ1)
```

---

## 7. Agent SDLC (In-App Automated Loop)

In addition to the development workflow above, the app itself implements an **agent-driven SDLC** for autonomous work within the Agent Hub:

```
Artifact phases (from SdlcStageContracts):
  backlog → ready_for_analysis → in_analysis →
  ready_for_development_feedback → ready_for_development →
  in_development → ready_for_qa → complete
```

**In-app agent roles:**
- **SAP** (Senior Advisory Partner): Writes PRDs, performs code reviews, manages backlog
- **Conductor**: Routes work between agents, manages lifecycle
- **CWA** (Coder Workflow Agent): Implements approved PRDs → green branches
- **CSO** (Chief Security Officer): Privacy guardian (human-led)

**Status movers:** `/approve`, `/reject`, `/handoff`, `/backlog` — triggered from Agent Hub UI

**Relationship to development workflow:** The development workflow (Φ1-Φ14) is the "outer loop" — how the product is planned and built. The Agent SDLC is the "inner loop" — how agents work autonomously within the running application. Over time, the goal is for the inner loop to increasingly automate parts of the outer loop.

---

## 8. Key Workflow Rules

### From `.junie/guidelines.md`

| Rule | Source |
|------|--------|
| Never commit without explicit human request | §3 Git safety |
| Never run destructive DB commands without confirmation | §3 Database safety |
| Use Minitest, not RSpec | §5 Testing |
| Use ViewComponents for UI | §4 Components |
| Use DaisyUI/Tailwind for styling | §4 Styling |
| Create task log before or alongside first code change | Junie log requirements |
| Update implementation status after each PRD | §6 and §9 |
| When asked to review, create feedback doc in same directory | §8 |
| When done, post "STATUS: DONE — awaiting review" and stop | §2 |

### Workflow-Specific Rules

| Rule | Phase |
|------|-------|
| PRD summaries are 2-3 sentences max during Φ2 | Φ2 |
| Eric must approve the preliminary epic before expansion | Φ3 |
| Consolidated document (epic + PRDs) before individual files | Φ4 |
| Architect always provides solutions with objections | Φ5 |
| Feedback cycles repeat 1-2 times until all parties satisfied | Φ5-Φ6 |
| Coding Agent breaks out PRDs into files (not the Reasoning AI) | Φ7 |
| Implementation plan must be architect-approved before coding | Φ9 |
| Preferred coding model: Qwen3-Coder (latest) | Φ10 |
| QA score must be ≥ 90 to pass | Φ11 |
| Failed QA kicks back to Coding Agent with specific gaps | Φ11 |

---

## 9. Gaps & Recommendations

| Gap | Impact | Recommendation |
|-----|--------|---------------|
| **Architect scoring criteria not formalized** | Subjective plan approval | Define a rubric (completeness, architecture, risk, tests, ordering) with numeric scoring |
| **QA scoring rubric not documented** | Inconsistent scoring | Document the 100-point breakdown (e.g., 30 pts AC compliance, 30 pts test coverage, 20 pts code quality, 20 pts plan adherence) |
| **No maximum Φ10↔Φ11 loop count** | Risk of infinite revision loop | Cap at 3 cycles; escalate to Eric if still < 90 |
| **No formal epic kickoff document** | Context may be lost between Φ6 and Φ7 | Coding Agent should read all feedback/response docs before breakout |
| **No automated CI gate** | Tests are run manually | Add GitHub Actions or local pre-merge hook |
| **Feedback naming inconsistent** | 12+ patterns in codebase | Standardize: `{epic}-feedback-V{N}.md` and `{epic}-response-V{N}.md` |
| **No cross-epic dependency tracking** | Epic-5 references Epic-4 decisions without formal link | Add "Depends on Epics" section to epic template |
| **No aggregate progress dashboard** | No bird's-eye view across all epics | Consider `knowledge_base/epics/STATUS.md` master tracker |
| **Implementation plan template missing** | Plans may vary in quality | Create `knowledge_base/templates/IMPLEMENTATION-PLAN-template.md` |
| **No rollback plan in PRDs** | If feature breaks production, no documented recovery | Add optional "Rollback" section to PRD template |
