# Unified Workflow Implementation Plan (Agent-Forge Source of Truth)

## Purpose
Create a single, reconciled workflow and command system for a single developer/product manager coordinating multiple AI agents. This plan aligns:
- `knowledge_base/epics/instructions/RULES.md` (canonical 14-phase rules — **authoritative**)
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/*` (source AiderDesk config starting point)

**Source of truth**: this document lives in `agent-forge/knowledge_base/workflow.md` and governs Agent-Forge + subprojects.

## Canonical Precedence (Conflict Resolution)
1. `knowledge_base/epics/instructions/RULES.md` (14-phase workflow + artifact rules) — **authoritative**
2. This document (`workflow.md`) — **implementation bridge** between RULES.md and AiderDesk config
3. AiderDesk config (agents/commands/prompts/skills) — **runtime implementation** sourced from `ror-agent-config`

If a lower-level source conflicts with a higher one, update the lower-level source to match `RULES.md`.

> **Legacy note**: `.junie/guidelines.md` is deprecated for subprojects. Agent-Forge root only. Delete in subprojects once `knowledge_base/epics/instructions` is authoritative.

---

## Actors (from RULES.md Part 1)

Five actors participate. Each has a lane — no actor does everything.

| Actor | Lane | AiderDesk Mapping |
|-------|------|-------------------|
| **Eric** (Human) | Idea origination, epic approval, feedback responses, final smoke test, merge, push, PR | Human triggers commands |
| **High-Reasoning AI** (Grok, Claude, etc.) | Epic drafting, PRD expansion, feedback response synthesis | External tool (not an AiderDesk agent) |
| **Architect Agent** | Epic review, feedback with solutions, plan scoring | `ror-architect` |
| **Coding Agent** | PRD breakout, implementation planning, coding, testing, task logging | `ror-rails` |
| **QA Agent** | Validate implementation, score 0-100, end-of-epic report | `ror-qa` |

Additionally: **Debug Agent** (`ror-debug`) — reproduces issues, isolates root cause, proposes minimal fix. Executes after QA < 90 or critical bug.

---

## Reconciled Workflow (14 Phases → 4 Human Commands)

### Outer Loop (RULES.md 14 Phases)
Φ1 Idea → Φ2 Atomic PRD summaries → Φ3 Eric approval → Φ4 Full expansion (single consolidated doc)
→ Φ5 Architect review → Φ6 Feedback response → Φ7 PRD breakout + epic update
→ Φ8 Implementation plan → Φ9 Architect plan gate → Φ10 Implementation
→ Φ11 QA score gate → Φ12 Task log + status update → Φ13 Closeout → Φ14 Next epic

### Phase-to-Command Mapping

| Human Command | RULES.md Phases | What Happens |
|---------------|-----------------|--------------|
| `/turn-idea-into-epic` | Φ1–Φ2 | Eric provides idea; Coding Agent drafts epic with atomic PRD summaries following template. Eric approves (Φ3) outside the command. |
| `/get-feedback-on-epic` | Φ4–Φ6 | Coding Agent delegates to Architect for review. Architect returns Questions/Suggestions/Objections (with solutions). Eric + High-Reasoning AI respond. Repeat 1–3 cycles. |
| `/finalize-epic` | Φ7 | Coding Agent reads all feedback/response docs, creates individual PRD files, updates `0000-epic.md`, creates `0001-IMPLEMENTATION-STATUS.md`, delegates to Architect for plan review, commits artifacts. |
| `/implement-prd` | Φ8–Φ12 | Coding Agent writes implementation plan (Φ8), delegates to Architect for approval (Φ9), implements code (Φ10), delegates to QA for scoring (Φ11), logs task and updates status (Φ12). |

**Φ13 (Closeout)** and **Φ14 (Next Epic)** are human-driven outside the command system.

### Inner Loop (Blueprint Workflow — AiderDesk config)
**Plan → Approve → Code → Score** maps directly to Φ8–Φ11:
- **PLAN** = Φ8 (Implementation Plan)
- **APPROVE** = Φ9 (Architect Gate)
- **CODE** = Φ10 (Implementation)
- **SCORE** = Φ11 (QA Gate)

**Delegation rule**: the **Coding Agent** acts as lead and delegates to Architect and QA sub-agents. The human only triggers the command; agents execute all steps internally.

**Rule**: If Blueprint instructions conflict with Φ8–Φ11, defer to `RULES.md`.

---

## Agent Roles (Unified)

### Architect (`ror-architect`)
- Reviews consolidated epics (Φ5) and implementation plans (Φ9)
- Provides questions/suggestions/objections **with solutions** (RULES.md Φ5 rule 2)
- May edit plan for clarity and ordering to prevent unnecessary turns
- Scores plans against the rubric in RULES.md Φ9

### Coding Agent (`ror-rails`)
- Performs Φ7–Φ12 work: PRD breakout, implementation plan, code, tests, logging
- Follows conventions: **Minitest**, ViewComponents, DaisyUI/Tailwind
- Orchestrates sub-agent delegation (Architect for review, QA for scoring)

### QA Agent (`ror-qa`)
- Scores implementation 0–100 (Φ11) using the rubric in RULES.md Φ11
- Must use **Minitest** as the test framework
- Must provide explicit remediation steps when < 90
- Maximum 3 QA cycles before escalation to Eric (RULES.md Φ11 rule 4)

### Debug Agent (`ror-debug`)
- Reproduces issues, isolates root cause, proposes minimal fix plan
- Must provide reproduction steps, root-cause analysis, minimal fix plan, and verification tests
- Executes only after QA < 90 or critical bug encountered

---

## Prompt & Command Reconciliation

### Required Prompt Alignment
1. **Agent IDs**: Template agent IDs remain `ror-*`. The sync script appends the project suffix at runtime:
   - `id`: `ror-architect-<project>`
   - `name`: `Architect (<project>)`
   Commands/prompts must use **template IDs** (`ror-architect`, etc.); the sync script handles suffixing.
2. **Commit rules**: **Commit plans always; commit code when green (tests pass)**. Remove any "no commits unless Eric explicitly asks" or "NEVER commit without explicit user confirmation" language from all config files.
   > ✅ RULES.md Φ10 has been updated to: "Commit plans always; commit code when tests pass (green)."
3. **Rules reference**: Canonical rules live in `knowledge_base/epics/instructions/RULES.md`. This file now exists.
4. **Testing stack**: All skills/prompts must reference **Minitest** (not RSpec). Grep and replace any RSpec references.

### Human Commands (Only Human-Run)
These are the **only** commands the human triggers directly:
- `/turn-idea-into-epic` — convert idea to epic draft (Φ1–Φ2)
- `/get-feedback-on-epic` — gather Architect feedback (Φ4–Φ6)
- `/finalize-epic` — lock epic, create PRD files, build PRD plan, commit (Φ7)
- `/implement-prd` — execute Blueprint inner loop end-to-end (Φ8–Φ12)

### Agent-Internal Steps (Delegated by Coding Agent)
These are **never** triggered by the human; they happen inside the agent loop:
- `/plan-epic` — Architect produces PRD implementation plan after epic finalization (inside `/finalize-epic`)
- `/plan-prds` — Coding Agent breaks PRDs into executable steps (inside `/implement-prd`)
- `/architect-review-plan` — Φ9 gate, emits `PLAN-APPROVED` or `PLAN-REVISE`
- `/qa-score` — Φ11 gate, scores 0–100
- `/debug-triage` — post-fail remediation
- `/log-task` — Φ12 task log (byproduct of implementation)
- `/update-implementation-status` — Φ12 status tracker (byproduct of implementation)

---

## Required Changes (Concrete Implementation Tasks)

See `workflow-implementaion-plan.md` for the full detailed change list. Key items:

### A) Command Files (BLOCKING)
- **Create** three missing command files: `turn-idea-into-epic.md`, `get-feedback-on-epic.md`, `finalize-epic.md`.
- **Update** `implement-prd.md` to enforce PRD plan adherence and reference RULES.md phases.
- **Remove** `audit-homekit.md`.
- **Repurpose** `review-epic.md` as internal architect delegation target.
- **Keep** `implement-plan.md` as agent-internal shortcut.

### B) Generalize Configs (BLOCKING)
- **Generalize** `rails-base-rules.md` — remove HomeKit references.
- **Fix** commit policy contradiction in `rails-base-rules.md` and `delegation-rules.md`.
- **Strengthen** `ror-debug` system prompt.
- **Add Minitest** to `ror-qa` system prompt.

### C) RULES.md Alignment
- ✅ `RULES.md` created at `knowledge_base/epics/instructions/RULES.md`.
- ✅ Φ10 commit policy updated to "commit plans always; commit code when green."
- ✅ Φ10 `.junie/guidelines.md` reference replaced with `knowledge_base/epics/instructions/RULES.md`.

### D) Testing Framework
- **Grep and replace** any RSpec references with Minitest.

---

## Implementation Sequence (Recommended Order)
1. ✅ RULES.md created — unblocks all prompts.
2. Update RULES.md Φ10 commit policy and `.junie` reference.
3. Generalize `rails-base-rules.md` — remove HomeKit, fix commit policy.
4. Create three missing command files from `prompt-definitions.md`.
5. Update `implement-prd.md` for PRD plan adherence.
6. Update agent system prompts.
7. Update `delegation-rules.md` commit policy.
8. Handle existing commands (remove/repurpose/update IDs).
9. Grep for RSpec, replace with Minitest.
10. Update documentation (`how-to-use-workflow.md`, `prompt-definitions.md`).
11. Update Table of Contents.
12. Run validation checklist.

---

## Definition of Done
- One canonical workflow that maps Blueprint → Φ8–Φ11 without contradictions.
- RULES.md exists and is consistent with all workflow documents.
- All four human commands have corresponding command files.
- All commands reference the correct agent IDs (template IDs; sync handles suffixing).
- Commit policy reflects "commit plans always; commit code when green" in RULES.md and all configs.
- Minitest is the stated default in skills/prompts/QA criteria.
- No HomeKit-specific references in generic config files.
- Command set covers Φ1–Φ12 end-to-end for a single-dev workflow.
