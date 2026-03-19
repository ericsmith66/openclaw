# Feedback v1: Workflow Implementation Plan Review

Date: 2026-02-21

This document reviews all epic-workflow planning documents against the actual `ror-agent-config` source assets and calls out questions, objections, gray areas, and proposed solutions.

---

## 1. CRITICAL: Source Commands Don't Match the Four Human Commands

**Finding**: The `ror-agent-config/commands/` directory contains:
- `implement-prd.md` ✅ (matches `/implement-prd`)
- `implement-plan.md` (no workflow equivalent — skips architect review)
- `review-epic.md` (partially maps to `/get-feedback-on-epic`)
- `audit-homekit.md` (HomeKit-specific; agreed to rename/remove)
- `roll-call.md` (utility — not in workflow)
- `validate-installation.md` (utility — not in workflow)

**Missing from source config**:
- `/turn-idea-into-epic` — **no command file exists**
- `/get-feedback-on-epic` — **no command file exists** (only `review-epic.md` which is architect-focused, not the full feedback loop)
- `/finalize-epic` — **no command file exists**

**Gray area**: The implementation plan (Section C) says "Verify command definitions reflect ownership" but does not explicitly state that three new command files must be **created**. It reads as if they already exist.

**Solution**: Add explicit tasks to Section C:
- Create `commands/turn-idea-into-epic.md`
- Create `commands/get-feedback-on-epic.md` (replace or repurpose `review-epic.md`)
- Create `commands/finalize-epic.md`
- Decide fate of `implement-plan.md` (keep as internal shortcut or remove)
- Rename or remove `audit-homekit.md`

---

## 2. CRITICAL: Agent System Prompts Are HomeKit-Specific

**Finding**: The agent configs in `ror-agent-config/agents/` contain HomeKit-specific language:
- `ror-architect` system prompt: "Rails conventions" (generic enough)
- `ror-qa` system prompt: references "RuboCop standards and Rails conventions" — no mention of Minitest explicitly
- `ror-rails` system prompt: references "Ruby on Rails 8 development", "Service Objects and ViewComponents"
- `ror-debug` system prompt: just "Troubleshooting Specialist" (too thin)

**Gray area**: `rails-base-rules.md` is titled "Rails 8 Base Rules for **Eureka HomeKit**" and contains HomeKit-specific rules (e.g., `characteristic_uuid`, "HomeKit webhooks", `LockControlComponent`). The workflow says this should be the base rules file, but it's domain-specific.

**Solution**: The implementation plan must include:
- Generalize `rails-base-rules.md` — remove HomeKit references, keep Rails 8 conventions
- Or create a new generic `base-rules.md` and keep `rails-base-rules.md` as project-specific
- Update `ror-debug` system prompt to match the prompt-definitions.md spec (reproduction, root cause, minimal fix)
- Confirm QA agent system prompt mentions Minitest (currently says RuboCop only)

---

## 3. OBJECTION: `/plan-epic` Ownership Conflict

**Finding**: `prompt-definitions.md` says `/plan-epic` is "Architect-run, after `/finalize-epic`". But `workflow.md` lists it under "Agent-Internal Steps (Delegated by Coding Agent)". The implementation plan says "/plan-epic is Architect-run after an epic is finalized (internal)."

**Gray area**: Who actually invokes `/plan-epic`? Is it:
- (a) The Coding Agent delegates to Architect during `/finalize-epic`, or
- (b) The Architect runs it independently after finalization?

If (a), then `/finalize-epic` prompt should explicitly include the delegation step.
If (b), there's no trigger mechanism — the human would need to invoke it or the Coding Agent would need to call it.

**Solution**: Clarify in both `workflow.md` and `prompt-definitions.md`:
- `/finalize-epic` should include a step: "Delegate to Architect to produce the PRD implementation plan (`/plan-epic`)."
- This makes the Coding Agent the orchestrator and the Architect the executor, consistent with the delegation model.

---

## 4. QUESTION: `/plan-prds` vs `/plan-epic` Overlap

**Finding**: Both `/plan-epic` and `/plan-prds` produce implementation plans:
- `/plan-epic`: "Produce the PRD-level implementation plan"
- `/plan-prds`: "Break approved PRDs into executable implementation steps"

**Gray area**: What's the difference? Is `/plan-epic` the high-level plan and `/plan-prds` the task-level breakdown? If so, this isn't clear. If they're the same thing at different granularities, the relationship should be explicit.

**Solution**: Clarify in `prompt-definitions.md`:
- `/plan-epic` = strategic plan (milestones, risks, dependencies) — produced by Architect
- `/plan-prds` = tactical task breakdown (step-by-step execution) — produced by Coding Agent inside `/implement-prd`
- State that `/plan-prds` takes the `/plan-epic` output as input

---

## 5. OBJECTION: Commit Policy Not Reflected in Source Config

**Finding**: The workflow says "commit plans always; commit code when green." But the actual source configs say:
- `delegation-rules.md`: "COMMIT it to git" (plans) and "COMMIT your code changes when finished" (no green gate)
- `ror-rails` system prompt: "COMMIT LOGIC: Use structured commit messages" (no green gate)
- `rails-base-rules.md`: "NEVER run destructive git commands or commit without explicit user confirmation" — **directly contradicts** the workflow commit policy

**Solution**: The implementation plan must include:
- Update `delegation-rules.md` to state "commit code only when tests pass (green)"
- Update `rails-base-rules.md` to remove "commit without explicit user confirmation" and replace with the workflow commit policy
- Update `ror-rails` system prompt to reflect the commit policy

---

## 6. QUESTION: Testing Framework — Minitest vs RSpec Remnants

**Finding**: The workflow confirms Minitest. The skills directory has `rails-minitest-vcr` (good). But:
- `ror-qa` system prompt doesn't mention Minitest
- `rails-base-rules.md` correctly says Minitest
- No skill references RSpec (good)

**Gray area**: Are there any prompt or skill files that still reference RSpec?

**Solution**: Add a validation step to the implementation plan: "Grep all config files for 'RSpec' and replace with 'Minitest'."

---

## 7. GRAY AREA: `implement-plan.md` Command — Keep or Remove?

**Finding**: `implement-plan.md` explicitly says "SKIP ARCHITECT" and executes a pre-approved plan. This is useful for re-running after architect approval but could bypass the workflow gate.

**Question**: Is this an intentional escape hatch for re-implementation, or should it be removed to prevent gate-skipping?

**Solution**: Either:
- (a) Keep it and document it as "agent-internal only, used after PLAN-APPROVED" — not exposed to human
- (b) Remove it and have `/implement-prd` handle re-runs internally

---

## 8. GRAY AREA: `review-epic.md` — Repurpose or Replace?

**Finding**: `review-epic.md` does interactive architect review with discovery questions and plan generation. This partially overlaps with `/get-feedback-on-epic` but is more structured (two-phase: discovery then plan).

**Question**: Should `/get-feedback-on-epic` replace `review-epic.md` entirely, or should `review-epic.md` be kept as the internal architect delegation target?

**Solution**: Repurpose `review-epic.md` as the internal prompt that `/get-feedback-on-epic` delegates to the Architect. Update its content to match the `prompt-definitions.md` spec.

---

## 9. MISSING: No `RULES.md` in This Repo

**Finding**: Every document references `knowledge_base/epics/instructions/RULES.md` but:
- The directory `knowledge_base/epics/instructions/` does not exist in this repo
- The implementation plan says "add/link here as needed" but doesn't include a concrete task to create it

**Solution**: Add an explicit task: "Create `knowledge_base/epics/instructions/RULES.md` (or symlink to the Agent-Forge source)." Without this, every prompt that references RULES.md will fail at runtime.

---

## 10. MISSING: Prompt Definitions Not Linked to Command Files

**Finding**: `prompt-definitions.md` defines exact prompt text for all commands, but the implementation plan doesn't include a step to **copy these prompts into the actual command `.md` files** in the config.

**Gray area**: Are the prompt-definitions meant to be the source that gets translated into AiderDesk command files, or are they documentation-only?

**Solution**: Add explicit tasks:
- For each human command, create/update the corresponding `.md` file in `ror-agent-config/commands/`
- For agent-internal commands, decide if they need command files or are invoked via `subagents---run_task` with inline prompts

---

## 11. MINOR: `roll-call.md` and `validate-installation.md` References

**Finding**: These utility commands reference hardcoded agent IDs (`architect`, `qa`, `debug`, `rails`) without the `ror-` prefix. The sync script adds project suffixes. These commands would fail at runtime.

**Solution**: Update these commands to use the correct `ror-*` prefixed IDs, or note that they need updating as part of the ID alignment task.

---

## 12. MINOR: Table of Contents Asterisks Incomplete

**Finding**: The TOC marks `commands/implement.md` and `commands/plan.md` with asterisks. But:
- The four new human commands aren't listed (they don't exist yet)
- `audit-homekit.md` should be marked for removal/rename
- `review-epic.md` should be marked for repurpose

**Solution**: Update the TOC to include the new command files that will be created and mark existing ones for modification/removal.

---

## Summary: Items Requiring Resolution Before Implementation

| # | Type | Item | Blocking? |
|---|------|------|-----------|
| 1 | Critical | Three human command files must be created (not just verified) | Yes |
| 2 | Critical | Agent prompts and rules are HomeKit-specific, need generalization | Yes |
| 3 | Objection | `/plan-epic` trigger mechanism unclear | Yes |
| 4 | Question | `/plan-epic` vs `/plan-prds` overlap | No (clarification) |
| 5 | Objection | Commit policy contradicted by source config | Yes |
| 6 | Question | RSpec remnants check needed | No (validation) |
| 7 | Gray area | `implement-plan.md` keep or remove | No |
| 8 | Gray area | `review-epic.md` repurpose or replace | No |
| 9 | Missing | `RULES.md` doesn't exist in repo | Yes |
| 10 | Missing | Prompt definitions not linked to command files | Yes |
| 11 | Minor | Utility commands have wrong agent IDs | No |
| 12 | Minor | TOC asterisks incomplete | No |
