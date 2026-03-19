# Workflow Implementation Plan (Detailed Change List)

## Purpose
Provide a concrete, step‑by‑step list of changes required to implement the workflow defined in `knowledge_base/workflow.md` and used by humans via `knowledge_base/how-to-use-workflow.md`.

## Scope & Assumptions
- **Human‑initiated commands** are limited to:
  - `/turn-idea-into-epic`
  - `/get-feedback-on-epic`
  - `/finalize-epic`
  - `/implement-prd`
- All other actions are **agent‑internal** (delegated by the Coding Agent).
- `/plan-epic` is **Architect‑run after an epic is finalized** (internal).
- `/plan-prds` happens **inside** `/implement-prd` (internal).
- `/implement-prd` must instruct the Coding Agent to **adhere to the approved PRD plan**.
- `/log-task` and `/update-implementation-status` are **byproducts** of implementation (internal).
- The **starting point** for all AiderDesk config is `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/`.

---

## A) Create Missing Command Files (BLOCKING)

**Context**: Only `implement-prd.md` exists in the source config. The other three human commands must be created.

1. **Create `commands/turn-idea-into-epic.md`**
   - Location: `ror-agent-config/commands/turn-idea-into-epic.md`
   - Content: use the prompt from `prompt-definitions.md` `/turn-idea-into-epic`
   - Must reference `RULES.md` for epic/PRD template and require PRD summary output.

2. **Create `commands/get-feedback-on-epic.md`**
   - Location: `ror-agent-config/commands/get-feedback-on-epic.md`
   - Content: use the prompt from `prompt-definitions.md` `/get-feedback-on-epic`
   - Repurpose content from existing `review-epic.md` (architect discovery + plan review) as the internal delegation target.

3. **Create `commands/finalize-epic.md`**
   - Location: `ror-agent-config/commands/finalize-epic.md`
   - Content: use the prompt from `prompt-definitions.md` `/finalize-epic`
   - Must create individual PRD files, build PRD plan consistent with epic, and commit per policy.

4. **Update `commands/implement-prd.md`**
   - Ensure prompt explicitly instructs the Coding Agent to locate and adhere to the approved PRD plan.
   - Add log/status update as byproducts.
   - Align with `prompt-definitions.md` `/implement-prd`.

5. **Decide fate of existing commands**
   - `implement-plan.md`: Keep as agent-internal shortcut (used after PLAN-APPROVED for re-runs). Document as internal-only.
   - `review-epic.md`: Repurpose as the internal architect delegation target for `/get-feedback-on-epic`. Update content to match prompt-definitions spec.
   - `audit-homekit.md`: Remove (HomeKit-specific; no backward-compatible alias needed).
   - `roll-call.md`: Keep as utility; update agent IDs to use `ror-*` prefix.
   - `validate-installation.md`: Keep as utility; update agent IDs to use `ror-*` prefix.

---

## B) Generalize Agent Configs and Rules (BLOCKING)

**Context**: Agent system prompts and `rails-base-rules.md` contain HomeKit-specific references that must be generalized.

6. **Generalize `rails-base-rules.md`**
   - Remove all HomeKit-specific references (`Eureka HomeKit`, `characteristic_uuid`, `LockControlComponent`, HomeKit webhooks).
   - Keep generic Rails 8 conventions (idiomatic Ruby, Minitest, service objects, ViewComponents).
   - If project-specific rules are needed later, create a separate `project-rules.md` overlay.

7. **Update agent system prompts**
   - `ror-architect`: Already generic enough (Rails conventions). No change needed.
   - `ror-qa`: Add explicit Minitest mention (currently says RuboCop only).
   - `ror-rails`: Remove HomeKit-specific references if any; keep Rails 8 + ViewComponents + DaisyUI/Tailwind.
   - `ror-debug`: Strengthen prompt to require reproduction steps, root-cause analysis, minimal fix plan, and verification tests (per prompt-definitions.md).

8. **Resolve commit policy contradiction**
   - `rails-base-rules.md` says "NEVER commit without explicit user confirmation" — this **contradicts** the workflow policy.
   - Update to: "Commit plans always; commit code when tests pass (green)."
   - Also update `delegation-rules.md` to add the green gate for code commits.
   - Also update `ror-rails` system prompt commit logic to reflect the policy.

---

## C) RULES.md (✅ CREATED — Alignment Needed)

**Context**: `knowledge_base/epics/instructions/RULES.md` now exists with the full 14-phase workflow (actors, phases, rubrics, naming conventions, templates, anti-patterns, checklists).

9. ✅ **`knowledge_base/epics/instructions/RULES.md` created** — unblocks all prompts.

10. ✅ **RULES.md Φ10 commit policy updated**
    - Changed from "Never commit without explicit human request" to "Commit plans always; commit code when tests pass (green)."
    - Updated `.junie/guidelines.md` reference to `knowledge_base/epics/instructions/RULES.md`.

---

## D) Workflow Documentation Updates (Source of Truth)

11. **Ensure command ownership is consistent in `workflow.md`**
    - Keep only the four human‑run commands as explicitly human‑initiated.
    - List all other commands as agent‑internal (delegated by the Coding Agent).
    - Explicitly state:
      - `/plan-epic` is Architect‑run after `/finalize-epic`.
      - `/plan-prds` occurs inside `/implement-prd`.
      - `/implement-prd` must follow the approved PRD plan.
      - `/log-task` and `/update-implementation-status` are byproducts.

12. **Keep the delegation rule explicit in `workflow.md`**
    - Coding Agent leads and delegates to Architect and QA.
    - Human only jump‑starts/gates the workflow via the four commands.

---

## E) Human Guide Alignment (How‑To)

13. **Align `how-to-use-workflow.md` with the four‑command model**
    - Only commands shown to the human: the four human commands.
    - Clarify internal steps that are not human‑run.
    - State that `/get-feedback-on-epic` gathers Architect feedback internally by default.

---

## F) Prompt Alignment

14. **Translate `prompt-definitions.md` into actual command files**
    - For each human command: create/update the `.md` file in `ror-agent-config/commands/` using the exact prompt text from `prompt-definitions.md`.
    - For agent-internal commands: decide if they need command files or are invoked via `subagents---run_task` with inline prompts. Document the decision.

15. **Ensure all prompts reference correct agent IDs**
    - Template IDs: `ror-architect`, `ror-qa`, `ror-debug`, `ror-rails`.
    - Runtime IDs (after sync): `ror-architect-<project>`, etc.
    - Commands/prompts must use template IDs (sync handles suffixing).

---

## G) Testing Framework Validation

16. **Grep all config files for RSpec references**
    - Replace any RSpec references with Minitest.
    - Confirm skills (`rails-minitest-vcr`) align with Minitest.

---

## H) Consistency Checks

17. **Confirm rules precedence matches workflow**
    - `workflow.md` and `RULES.md` are authoritative.
    - `.junie/guidelines.md` remains legacy and Agent‑Forge‑only. Delete in subprojects.

18. **Update Table of Contents**
    - Add the three new command files to the TOC with asterisks.
    - Mark `audit-homekit.md` for removal.
    - Mark `review-epic.md` for repurpose.

---

## I) Validation Checklist

19. **Manual verification**
    - [ ] `workflow.md` and `how-to-use-workflow.md` describe the same four human‑run commands.
    - [ ] Internal steps are only described as agent‑internal.
    - [ ] `/implement-prd` explicitly enforces adherence to the PRD plan.
    - [ ] Three new command files exist in `ror-agent-config/commands/`.
    - [ ] `rails-base-rules.md` has no HomeKit-specific references.
    - [ ] Commit policy is consistent across all config files.
    - [x] `RULES.md` exists at `knowledge_base/epics/instructions/RULES.md`.
    - [x] RULES.md Φ10 commit policy updated to match agreed policy.
    - [ ] No RSpec references remain in config files.
    - [ ] Agent IDs in utility commands use `ror-*` prefix.
    - [ ] TOC reflects all changes.

---

## Implementation Sequence (Recommended Order)
1. ✅ `RULES.md` created — unblocks all prompts.
2. ✅ RULES.md Φ10 commit policy and `.junie` reference updated.
3. Generalize `rails-base-rules.md` — remove HomeKit references, fix commit policy.
4. Create the three missing command files from `prompt-definitions.md`.
5. Update `implement-prd.md` to enforce PRD plan adherence.
6. Update agent system prompts (QA → Minitest, Debug → strengthen).
7. Update `delegation-rules.md` commit policy.
8. Decide and document fate of `implement-plan.md`, `review-epic.md`, `audit-homekit.md`.
9. Update utility commands (`roll-call.md`, `validate-installation.md`) agent IDs.
10. Grep for RSpec, replace with Minitest.
11. Update `workflow.md`, `how-to-use-workflow.md`, `prompt-definitions.md` for consistency.
12. Update Table of Contents.
13. Run validation checklist.

## Definition of Done
- The workflow documents and prompts clearly separate **human‑run** commands from **agent‑internal** actions.
- `/implement-prd` is explicitly bound to the **approved PRD plan**.
- The human guide shows only the four commands the human should run.
- Three new command files exist (`turn-idea-into-epic.md`, `get-feedback-on-epic.md`, `finalize-epic.md`).
- `rails-base-rules.md` is generalized (no HomeKit references).
- Commit policy is consistent: "commit plans always; commit code when green."
- `RULES.md` exists and Φ10 commit policy is aligned.
- Minitest is the stated default everywhere.
- Agent IDs are correct in all commands.
- TOC is complete and accurate.
