# Workflow Table of Contents (AiderDesk)

This is the complete table of contents for the workflow and its implementation assets. Items marked with `*` will be modified or created as part of the workflow implementation plan.

## Workflow Core (Source of Truth)
- * `knowledge_base/workflow.md` — canonical workflow definition (phases, ownership, delegation, precedence).
- * `knowledge_base/how-to-use-workflow.md` — human-facing usage guide (four human-run commands).
- * `knowledge_base/workflow-implementaion-plan.md` — concrete change list to implement/align the workflow.
- `knowledge_base/workflow-table-of-contence.md` — this table of contents.
- * `knowledge_base/epics/epic-workflow/prompt-definitions.md` — exact prompt text for all commands.

## Agent-Forge Source Assets (Starting Point)
These are the authoritative sources that the AiderDesk runtime syncs from.
- ✅ `knowledge_base/epics/instructions/RULES.md` — canonical 14-phase workflow rules (created). Contains actors, phases, rubrics, naming conventions, templates, anti-patterns.
- * `knowledge_base/epics/instructions/RULES.md` Φ10 — commit policy must be updated to match agreed policy.
- * `agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/` — source AiderDesk config bundle.
- * `agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/rules/rails-base-rules.md` — base rules file; must be generalized (remove HomeKit references) and commit policy fixed.
- * `agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/prompts/delegation-rules.md` — delegation rules; commit policy must be updated.

## AiderDesk Source Commands (`ror-agent-config/commands/`)
- * `commands/turn-idea-into-epic.md` — **TO CREATE** (human command).
- * `commands/get-feedback-on-epic.md` — **TO CREATE** (human command).
- * `commands/finalize-epic.md` — **TO CREATE** (human command).
- * `commands/implement-prd.md` — **TO UPDATE** (human command; enforce PRD plan adherence).
- * `commands/implement-plan.md` — keep as agent-internal shortcut; document as internal-only.
- * `commands/review-epic.md` — **TO REPURPOSE** as internal architect delegation target.
- * `commands/audit-homekit.md` — **TO REMOVE** (HomeKit-specific).
- * `commands/roll-call.md` — update agent IDs to `ror-*` prefix.
- * `commands/validate-installation.md` — update agent IDs to `ror-*` prefix.

## AiderDesk Source Agents (`ror-agent-config/agents/`)
- `agents/order.json` — agent execution order.
- `agents/ror-architect/config.json` — Architect agent config.
- * `agents/ror-qa/config.json` — QA agent config; add Minitest mention.
- `agents/ror-rails/config.json` — Coding Agent config.
- * `agents/ror-debug/config.json` — Debug agent config; strengthen prompt.

## AiderDesk Source Prompts (`ror-agent-config/prompts/`)
- * `prompts/delegation-rules.md` — delegation and commit rules; update commit policy.

## AiderDesk Source Rules (`ror-agent-config/rules/`)
- * `rules/rails-base-rules.md` — base rules; generalize and fix commit policy.

## AiderDesk Source Skills (`ror-agent-config/skills/`)
- `skills/agent-forge-logging/` — logging skill.
- `skills/rails-best-practices/` — Rails best practices.
- `skills/rails-service-patterns/` — service patterns.
- `skills/rails-minitest-vcr/` — Minitest + VCR skill (aligned with workflow).
- `skills/rails-capybara-system-testing/` — system testing.
- `skills/rails-tailwind-ui/` — Tailwind UI.
- `skills/rails-daisyui-components/` — DaisyUI components.
- `skills/rails-turbo-hotwire/` — Turbo/Hotwire.
- `skills/rails-error-handling-logging/` — error handling.
- `skills/rails-view-components/` — ViewComponents.

## AiderDesk Runtime Implementation (.aider-desk)
These files are synced from the source config at runtime.

### Tasks / State
- `.aider-desk/tasks/internal/context.json` — internal task context state.

### Agents
- `.aider-desk/agents/order.json` — agent execution order.
- `.aider-desk/agents/translation-manager/config.json` — translation manager agent config.
- `.aider-desk/agents/test-writer/config.json` — test writer agent config.
- `.aider-desk/agents/code-checker/config.json` — code checker agent config.
- `.aider-desk/agents/code-reviewer/config.json` — code reviewer agent config.

### Rules
- `.aider-desk/rules/CONVENTIONS.md` — runtime conventions/rules.

### Commands
- `.aider-desk/commands/analyze.md` — analysis command.
- `.aider-desk/commands/clarify.md` — clarification command.
- `.aider-desk/commands/commit-message.md` — commit message helper.
- `.aider-desk/commands/constitution.md` — constitution/constraints.
- `.aider-desk/commands/implement.md` — implementation command.
- `.aider-desk/commands/plan.md` — planning command.
- `.aider-desk/commands/review/uncommited.md` — review uncommitted changes.
- `.aider-desk/commands/specify.md` — specification command.
- `.aider-desk/commands/squash.md` — squash command.
- `.aider-desk/commands/tasks.md` — task management command.
- `.aider-desk/commands/update-changelog.md` — changelog update command.

### Skills
- `.aider-desk/skills/theme-factory/SKILL.md` — theme factory skill.
- `.aider-desk/skills/agent-creator/SKILL.md` — agent creator skill.
- `.aider-desk/skills/skill-creator/SKILL.md` — skill creator skill.
- `.aider-desk/skills/writing-tests/SKILL.md` — writing tests skill.

### Hooks
- `.aider-desk/hooks/wakatime-hooks.js` — WakaTime hook integration.
