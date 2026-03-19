# Feedback v2: Post-Revision Review + Workflow Critique

Date: 2026-02-21

This document provides feedback after incorporating all feedback-v1 findings into the implementation plan and aligning all epic-workflow documents. It also includes a critical assessment of the underlying workflow design.

---

## Part 1: Feedback-v1 Resolution Status

All 12 items from feedback-v1 have been addressed in the updated documents:

| # | Item | Status | Where Addressed |
|---|------|--------|-----------------|
| 1 | Three human command files must be created | ✅ Resolved | Plan Section A, steps 1–3; TOC marks them "TO CREATE" |
| 2 | Agent prompts/rules are HomeKit-specific | ✅ Resolved | Plan Section B, steps 6–7 |
| 3 | `/plan-epic` trigger mechanism unclear | ✅ Resolved | `/finalize-epic` prompt now explicitly delegates to Architect for `/plan-epic` |
| 4 | `/plan-epic` vs `/plan-prds` overlap | ✅ Resolved | prompt-definitions clarifies: `/plan-epic` = strategic (Architect), `/plan-prds` = tactical (Coding Agent inside `/implement-prd`) |
| 5 | Commit policy contradicted by source config | ✅ Resolved | Plan Section B, step 8; explicit update tasks for `rails-base-rules.md` and `delegation-rules.md` |
| 6 | RSpec remnants check | ✅ Resolved | Plan Section G, step 15 |
| 7 | `implement-plan.md` keep or remove | ✅ Resolved | Keep as agent-internal shortcut (Plan Section A, step 5) |
| 8 | `review-epic.md` repurpose or replace | ✅ Resolved | Repurpose as internal architect delegation target (Plan Section A, step 5) |
| 9 | `RULES.md` doesn't exist | ✅ Resolved | Plan Section C, step 9 — explicit create/link task |
| 10 | Prompt definitions not linked to command files | ✅ Resolved | Plan Section F, step 13; prompt-definitions now shows command file mapping |
| 11 | Utility commands have wrong agent IDs | ✅ Resolved | Plan Section A, step 5; TOC marks them for update |
| 12 | TOC asterisks incomplete | ✅ Resolved | TOC now shows all new/modified/removed files with asterisks |

---

## Part 2: Remaining Questions

### Q1: RULES.md Content
The plan says "create or link" `RULES.md`, but doesn't specify what goes in it. Does a canonical `RULES.md` already exist in the Agent-Forge root that we can link/copy? If not, someone needs to author it. This is the single biggest blocker — every prompt references it, and the epic/PRD template, QA rubric, and phase definitions all depend on it.

**Recommendation**: If it exists in Agent-Forge, symlink it. If not, the first implementation task should be to draft it based on the 14-phase workflow and QA rubric already described in `workflow.md`.

### Q2: Agent-Internal Commands — Command Files or Inline?
The plan says to "decide if agent-internal commands need command files or are invoked via `subagents---run_task` with inline prompts." This decision hasn't been made yet.

**Recommendation**: Agent-internal steps (`/plan-epic`, `/plan-prds`, `/architect-review-plan`, `/qa-score`, `/debug-triage`, `/log-task`, `/update-implementation-status`) should **not** have command files in the `commands/` directory — they should be invoked via sub-agent delegation with inline prompts from the parent command. This keeps the command directory clean (only human-facing commands) and avoids confusion about what's human-triggerable.

### Q3: `.aider-desk` Runtime vs Source Config Divergence
The TOC lists both `ror-agent-config/` (source) and `.aider-desk/` (runtime) files. The runtime files are different from the source (e.g., `.aider-desk/agents/` has `translation-manager`, `test-writer`, `code-checker`, `code-reviewer` — none of which exist in `ror-agent-config/agents/`). This means the sync script isn't the only source of `.aider-desk/` content.

**Question**: Are the `.aider-desk/` runtime files managed independently of the sync script? If so, the workflow plan should clarify which files come from sync and which are project-local.

### Q4: `/finalize-epic` Double Duty
`/finalize-epic` now does a lot: confirm feedback addressed, create PRD files, build PRD plan, delegate to Architect for `/plan-epic`, and commit. This is the heaviest command in the workflow.

**Question**: Is this acceptable as a single command, or should the Architect plan step be a separate human trigger? (Current design: single command, which is simpler for the human but complex for the agent.)

---

## Part 3: Critique of the Underlying Workflow

### Strengths
1. **Clear human/agent boundary**: The four-command model is clean. The human adds value at idea inception, feedback review, finalization approval, and implementation kickoff — exactly where human judgment matters.
2. **Delegation model is sound**: Coding Agent as lead with Architect/QA as sub-agents mirrors real team dynamics. The Blueprint inner loop (Plan → Approve → Code → Score) is a proven pattern.
3. **Commit policy is pragmatic**: "Commit plans always; commit code when green" balances traceability with safety.
4. **Single source of truth**: Having `workflow.md` as the canonical reference with precedence rules prevents config drift.

### Concerns

#### C1: RULES.md Is a Single Point of Failure
Every prompt, every gate, every template references `RULES.md`. If it's missing, incomplete, or ambiguous, the entire workflow breaks. The QA rubric, epic template, PRD template, and phase definitions all live there (or should). This is a lot of weight on one file.

**Risk**: If `RULES.md` is too long, agents will lose context. If it's too short, agents will improvise.
**Mitigation**: Consider splitting `RULES.md` into focused files (`RULES-epic-template.md`, `RULES-qa-rubric.md`, `RULES-phases.md`) with a master index. Or keep it as one file but enforce a strict length limit.

#### C2: No Explicit Error Recovery Path
The workflow handles QA < 90 (debug-triage → remediate → re-score), but doesn't address:
- What happens if the Architect repeatedly returns `PLAN-REVISE`? Is there a max iteration count?
- What happens if `/turn-idea-into-epic` produces a draft that's fundamentally flawed? The human runs `/get-feedback-on-epic` repeatedly, but there's no "abandon epic" path.
- What happens if `/implement-prd` fails mid-way (e.g., agent context limit hit)? Can it resume, or must it restart?

**Recommendation**: Add explicit loop limits and escape hatches. E.g., "If Architect returns PLAN-REVISE 3 times, escalate to human." "If QA < 90 after 2 debug cycles, escalate to human."

#### C3: No Versioning or Audit Trail for Plans
The workflow produces plans (epic plan, PRD plan, implementation plan) but doesn't specify how they're versioned. If the Architect revises a plan, is the old version preserved? If `/implement-prd` deviates from the plan, is that tracked?

**Recommendation**: Require plan files to use sequential numbering or timestamps. The task log should reference the exact plan version used.

#### C4: The "Coding Agent as Lead" Assumption
The entire delegation model assumes the Coding Agent can reliably orchestrate sub-agents. In practice, this depends on AiderDesk's `subagents---run_task` capability working correctly. If the Coding Agent can't reliably invoke sub-agents (e.g., context limits, tool failures), the workflow collapses to manual orchestration.

**Recommendation**: The implementation plan should include a validation step: "Verify that the Coding Agent can successfully delegate to Architect and QA sub-agents in a test scenario before deploying the full workflow."

#### C5: Workflow Is Rails-Specific but Claims to Be Generic
The workflow references Rails 8, Minitest, ViewComponents, DaisyUI/Tailwind, and Service Objects. The agent IDs use `ror-*` (Ruby on Rails). But the workflow structure (epic → PRD → plan → implement → QA) is framework-agnostic.

**Question**: Is this workflow intended to be reusable across projects (e.g., a TypeScript project), or is it permanently Rails-specific? If reusable, the Rails-specific bits should be in project-level config overlays, not in the core workflow.

#### C6: No Metrics or Success Criteria for the Workflow Itself
The workflow defines QA scoring for implementations (0–100), but there's no way to measure whether the workflow itself is working well. How do you know if the four-command model is efficient? How do you track cycle time from idea to implementation?

**Recommendation**: Add a lightweight workflow retrospective step (e.g., after each epic closeout, record: number of feedback rounds, number of plan revisions, QA score on first pass, total time). This data will help refine the workflow over time.

---

## Part 4: Document Consistency Check

After the updates, all five epic-workflow documents are now consistent:

| Document | Four Human Commands | Agent-Internal Steps | Commit Policy | RULES.md Reference | Prompt ↔ Command Mapping |
|----------|--------------------|--------------------|---------------|--------------------|-----------------------|
| `workflow.md` | ✅ | ✅ | ✅ | ✅ (must exist) | ✅ (references plan) |
| `how-to-use-workflow.md` | ✅ | ✅ (explained) | ✅ | ✅ | N/A (human guide) |
| `workflow-implementaion-plan.md` | ✅ | ✅ | ✅ (fix task) | ✅ (create task) | ✅ (translate task) |
| `workflow-table-of-contence.md` | ✅ (TO CREATE) | N/A | N/A | ✅ (TO CREATE) | ✅ (files listed) |
| `prompt-definitions.md` | ✅ (with file mapping) | ✅ (with invocation) | ✅ | ✅ | ✅ (explicit) |

No contradictions found between documents after this revision.
