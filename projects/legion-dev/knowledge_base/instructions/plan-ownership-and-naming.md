# Plan Ownership & Naming — Definitive Reference

**Status:** Canonical — all AI agents and humans follow these rules  
**Last Updated:** March 3, 2026  
**Companion docs:** `RULES.md` (full workflow), `implied-workflow.md` (14-phase details)

> **This document defines WHO creates WHICH plan, WHERE it lives, and HOW amendments are tracked.**

---

## Plan Types & Ownership

| Plan | Owner | Filename | Location | When Created |
|------|-------|----------|----------|-------------|
| **Epic Master Plan** | Architect | `0002-master-implementation-plan.md` | `{epic-dir}/` | `/review-epic` → Architect creates after discovery + user feedback |
| **PRD Implementation Plan** | Lead Developer | `PRD-{id}-implementation-plan.md` | `{epic-dir}/` | `/implement-prd` → Lead creates as Blueprint step 1 |
| **Architect Amendments** | Architect | Appended to `PRD-{id}-implementation-plan.md` | In-place | Blueprint step 2 — tracked with tags |

### Examples

```
knowledge_base/epics/wip/epic-5/epic-5-file-maintenance-ui/
  ├── 0002-master-implementation-plan.md          ← Architect owns this
  ├── PRD-5000-implementation-plan.md             ← Lead owns this
  ├── PRD-5005-implementation-plan.md             ← Lead owns this
  ├── PRD-5010-implementation-plan.md             ← Lead owns this
  └── PRD-5020-implementation-plan.md             ← Lead owns this
```

---

## Epic Master Plan (Architect Creates)

**Trigger:** `/review-epic {N}` or delegation from Eric  
**Filename:** `{epic-dir}/0002-master-implementation-plan.md`  
**Owner:** Architect Agent

### Must Include:
- PRD sequencing and dependency order
- Cross-PRD architectural decisions and risks
- Overall test strategy (Backend, Frontend, QA, UI-UX)
- Per-PRD summary of scope and complexity estimate

### Purpose:
This is the **strategic roadmap**. It tells the Lead Developer WHAT order to implement PRDs and WHY. The Lead references this when creating individual PRD plans.

---

## PRD Implementation Plan (Lead Creates)

**Trigger:** `/implement-prd {path}` or direct task assignment  
**Filename:** `{epic-dir}/PRD-{id}-implementation-plan.md`  
**Owner:** Lead Developer

### Must Include:
1. **File-by-file changes** — models, migrations, services, controllers, components, tests
2. **Numbered Test Checklist** — every test listed and numbered, marked `MUST-IMPLEMENT`
3. **Error Path Matrix** — every `rescue`/`raise`/error class maps to a specific test
4. **Rails Migration Verification Step** (Rails PRDs only) — explicit step to verify from scratch
5. **Pre-QA Checklist Acknowledgment** — references `knowledge_base/templates/pre-qa-checklist-template.md`

### Before Writing:
- If an epic master plan exists (`0002-master-implementation-plan.md`), **read it first** for context
- Read the PRD file and its acceptance criteria
- Check dependency chain — what must exist before this PRD can be built

---

## Architect Review & Amendment Tracking

When the Architect reviews a PRD implementation plan, they **append** a section to the same file (never replace):

```markdown
---
## Architect Review & Amendments
**Reviewer:** Architect Agent
**Date:** YYYY-MM-DD
**Verdict:** APPROVED / REVISE

### Amendments Made (tracked for retrospective)
1. [ADDED] Description of what was added and why
2. [CHANGED] What was modified and why
3. [REMOVED] What was removed and why

### Items Requiring Lead Revision (if REVISE)
- Item and specific guidance

PLAN-APPROVED
```

### Rules:
- **NEVER silently amend** — every change must be listed under `Amendments Made`
- Tags: `[ADDED]`, `[CHANGED]`, `[REMOVED]` — these are searchable for retrospective analysis
- After `PLAN-APPROVED`, the Lead **must re-read** the plan file before coding — it may have been amended
- If `PLAN-REVISE`, the Lead must address the listed items and resubmit

### Why Track Amendments?
The `Amendments Made` section feeds into Φ14 (Retrospective). By grepping for `[ADDED]` across all plans, we can identify:
- What the Lead consistently misses (→ update Lead instructions)
- What the Architect consistently adds (→ bake into plan template)
- Trends over time (→ measure improvement)

---

## Workflow Flow

```
/review-epic {N}
    → Architect builds {epic-dir}/0002-master-implementation-plan.md
    ↓
/implement-prd {path-to-PRD}
    → Lead reads master plan for context
    → Lead creates {epic-dir}/PRD-{id}-implementation-plan.md
    → Architect reviews, appends amendments (tracked), PLAN-APPROVED
    → Lead re-reads amended plan
    → Lead implements code
    → Lead runs Pre-QA Checklist
    → QA scores → report saved to {epic-dir}/feedback/qa-report-PRD-{id}.md
    → Done
    
/implement-plan {path-to-plan}
    → Skips architect review
    → Executes any already-approved plan directly (epic or PRD level)
    → Pre-QA → QA Score → Done
```

---

## Commands Reference

| Command | What It Does | Plan Type |
|---------|-------------|-----------|
| `/review-epic {N}` | Architect reviews epic, creates master plan | Epic Master Plan |
| `/implement-prd {path}` | Lead creates PRD plan → Architect approves → Lead implements | PRD Implementation Plan |
| `/implement-plan {path}` | Execute an already-approved plan (skip architect) | Either type |

---

## Artifact Output Summary

After a full PRD implementation cycle, the epic directory contains:

```
{epic-dir}/
  ├── 0000-epic.md
  ├── 0001-implementation-status.md
  ├── 0002-master-implementation-plan.md              ← Architect
  ├── PRD-{id}.md                                     ← PRD spec
  ├── PRD-{id}-implementation-plan.md                 ← Lead + Architect amendments
  └── feedback/
      ├── pre-qa-checklist-PRD-{id}.md                ← Lead (before QA)
      ├── qa-report-PRD-{id}.md                       ← QA Agent (scoring)
      ├── {epic}-feedback-V{N}.md                     ← Architect (epic review)
      ├── {epic}-response-V{N}.md                     ← Eric + AI (feedback response)
      ├── plan-review.md                              ← Architect (plan scoring)
      ├── end-of-epic-report.md                       ← QA Agent (closeout)
      └── retrospective-report.md                     ← QA Agent (Φ14)
```
