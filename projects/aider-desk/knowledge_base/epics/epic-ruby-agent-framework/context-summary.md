# Epic Context Summary — Ruby Agent Framework

**Purpose**: Capture all context needed to resume this epic in a new thread.
**Last Updated**: 2026-02-26

---

## 1. What This Epic Is

A standalone Ruby gem (`agent_desk`) that replicates AiderDesk's backend agent orchestration architecture — specifically the **agent profile → tool calling → skill activation → rule loading → prompt templating → hook interception** pipeline. **No UI.** Backend framework only.

---

## 2. Origin & Motivation

- Eric asked to "port AiderDesk to Ruby" — clarified to mean duplicating the **agent/skill/rule/command/tool-calling structure**, not the Electron UI.
- Goal: Ruby applications can run LLM agents with the same structured, extensible framework as AiderDesk.
- Delivery strategy: **useful code early, iterate over the full featureset** — not a big-bang.

---

## 3. AiderDesk Architecture Analyzed

The following AiderDesk source files were deeply analyzed to inform the design:

### Core Types & Constants
- `src/common/tools.ts` — All tool group names, tool names, separator (`---`), descriptions
- `src/common/types.ts` — `ToolApprovalState`, `AgentProfile` interface, `ContextMessage`, `SubagentConfig`, etc.
- `src/common/agent.ts` — `LlmProviderName`, `DEFAULT_AGENT_PROFILE`, default tool approvals, provider type definitions

### Agent System
- `src/main/agent/agent.ts` — `Agent` class: `buildToolSet()` (lines 350-447), `wrapToolsWithHooks()` (449-473), `runAgent()` (610-1140), `processStep()` (1502-1616), `repairToolCall` (764-780)
- `src/main/agent/agent-profile-manager.ts` — Profile loading from filesystem, rule file discovery (`getRuleFilesForAgent`, `getAllRuleFilesForProfile`), file watching
- `src/main/agent/optimizer.ts` — Message optimization, duplicate tool call detection

### Tool Groups
- `src/main/agent/tools/power.ts` — file_read, file_write, file_edit, glob, grep, bash, fetch, semantic_search
- `src/main/agent/tools/approval-manager.ts` — Approval flow: always/ask/never + per-run memory
- `src/main/agent/tools/todo.ts` — set_items, get_items, update_item_completion, clear_items
- `src/main/agent/tools/memory.ts` — store, retrieve, delete, list, update
- `src/main/agent/tools/skills.ts` — `loadSkillsFromDir`, `getActivateSkillDescription`, `createSkillsToolset`
- `src/main/agent/tools/tasks.ts` — list_tasks, get_task, create_task, delete_task, search_task
- `src/main/agent/tools/helpers.ts` — no_such_tool, invalid_tool_arguments
- `src/main/agent/tools/aider.ts` — get_context_files, add_context_files, drop_context_files, run_prompt
- `src/main/agent/tools/subagents.ts` — run_task (subagent delegation)

### Prompt System
- `src/main/prompts/prompts-manager.ts` — Template compilation (Handlebars), rendering, global/project override chain, `calculateToolPermissions`, `getSystemPrompt`
- `src/main/prompts/types.ts` — `PromptTemplateData`, `ToolPermissions`
- `resources/prompts/system-prompt.hbs` — Full system prompt template (XML structure with conditional sections)
- `resources/prompts/workflow.hbs` — Workflow steps sub-template

### Skills
- `.aider-desk/skills/*/SKILL.md` — YAML frontmatter (`name`, `description`) + markdown body
- Discovery from `~/.aider-desk/skills/` (global) and `{project}/.aider-desk/skills/` (project)

### Rules
- Three-tier rule loading: global agent rules → project rules → project agent rules
- Markdown files injected as CDATA XML into system prompt `<Knowledge><Rules>` section

### Hook System
- `on_agent_started` — before agent loop (can block/modify prompt)
- `on_tool_called` — before tool execution (can block/modify args)
- `on_tool_finished` — after tool execution (notification)
- `on_handle_approval` — override approval decision

### Key Architectural Patterns
- Tools organized into named groups with `---` separator: `power---file_read`, `skills---activate_skill`
- Per-tool approval state in profile: `always` (auto), `ask` (prompt user), `never` (excluded from toolset)
- System prompt assembled from Handlebars templates with conditional sections based on enabled tool groups
- Agent runner loop: send messages+tools to LLM → process tool calls → execute → loop until text response or max_iterations
- Hook wrapping on every tool execution for lifecycle interception

---

## 4. Nextgen-Plaid Framework Context

The nextgen-plaid project (Eric's Rails app) has a mature agent orchestration setup that informed how this epic should be executed:

### Agents (4 profiles)
- **ror-architect** — Plan reviewer, structural integrity, security
- **ror-rails** — Lead implementation, Blueprint Workflow, Service Objects + ViewComponents
- **ror-qa** — Score implementations 0-100, test coverage audit
- **ror-debug** — Troubleshooting specialist

### Blueprint Workflow (delegation-rules.md)
1. **PLAN** → Draft implementation plan, commit to git
2. **APPROVE** → Architect reviews, may amend
3. **CODE** → Implement after receiving PLAN-APPROVED
4. **SCORE** → QA scores 0-100 (≥90 to pass)
5. **DEBUG** → If <90, delegate to debug agent

### 14-Phase Workflow (knowledge_base/epics/instructions/RULES.md)
Φ1 Idea → Φ2 Epic Draft → Φ3 Eric Approval → Φ4 Full Expansion → Φ5 Architect Review → Φ6 Feedback Response → Φ7 PRD Breakout → Φ8 Implementation Plan → Φ9 Architect Plan Score → Φ10 Implementation → Φ11 QA Score (≥90 gate) → Φ12 Task Log → Φ13 Closeout → Φ14 Next Epic

### Key Rules
- PRDs say WHAT, not HOW (no code in PRDs)
- Architect always provides solutions with objections
- Max 3 QA cycles before escalation
- 5 actors with distinct lanes (Eric, High-Reasoning AI, Architect, Coding Agent, QA)

### Skills (10 project-specific)
rails-best-practices, rails-service-patterns, rails-minitest-vcr, rails-capybara-system-testing, rails-view-components, rails-tailwind-ui, rails-daisyui-components, rails-turbo-hotwire, rails-error-handling-logging, agent-forge-logging

### Commands (6 custom)
/audit-homekit, /implement-plan, /implement-prd, /review-epic, /roll-call, /validate-installation

---

## 5. Current State of Design Docs

12 documents created in `knowledge_base/epics/epic-ruby-agent-framework/`:

| File | Content | Status |
|------|---------|--------|
| `0000-epic-overview.md` | Epic goals, milestone map, dependency graph, tech decisions | Complete |
| `0010-core-types-constants-scaffold.md` | Gem scaffold, constants, types | Complete |
| `0020-tool-framework-approval.md` | BaseTool, ToolSet, ApprovalManager, DSL | Complete |
| `0030-hook-system.md` | HookManager, HookResult, lifecycle events | Complete |
| `0040-agent-profile-system.md` | Profile data structure, ProfileManager, filesystem loading | Complete |
| `0050-power-tools.md` | file_read, file_write, file_edit, glob, grep, bash, fetch | Complete |
| `0060-prompt-templating.md` | PromptsManager, ToolPermissions, template override chain | Complete |
| `0070-rules-system.md` | RulesLoader, 3-tier rule discovery, CDATA formatting | Complete |
| `0080-skills-system.md` | SkillLoader, SKILL.md parsing, activate_skill tool | Complete |
| `0090-agent-runner-loop.md` | Runner, ToolSetBuilder, ModelManager, LLM loop | Complete |
| `0092-token-budget-graceful-handoff.md` | TokenBudgetTracker, StateSnapshot, CompactionStrategy (compact/handoff/tiered), hooks, runner integration | Complete |
| `0095-message-bus.md` | MessageBus interface, CallbackBus, PostgresBus, typed events, channel schema | Complete |
| `0100-memory-system.md` | MemoryStore (JSON), memory tools | Complete |
| `0110-todo-task-helper-tools.md` | TodoTools, TaskTools, HelperTools | Complete |

### Also exists (premature scaffold — should be replaced)
`ruby-agent-framework/` directory at project root with partial Gemfile, gemspec, ARCHITECTURE.md, and empty directory structure. Created before the epic/PRD approach was requested. Should be cleaned up or replaced by PRD-0010 implementation.

---

## 6. Technology Decisions Made

| Concern | Decision |
|---------|----------|
| Language | Ruby >= 3.2 |
| LLM Clients | `ruby-openai` + `anthropic` gems |
| Template Engine | Liquid or Handlebars.rb (TBD) |
| JSON Schema Validation | `json_schemer` |
| File Watching | `listen` gem |
| Testing | RSpec (note: nextgen-plaid uses Minitest — decision needed) |
| Type Annotations | YARD docs |
| Packaging | RubyGem |
| Memory Persistence | JSON file (upgrade to SQLite later) |

---

## 7. Milestone Map

| Milestone | PRDs | Deliverable |
|-----------|------|-------------|
| M0: Scaffold | 0010 | `require 'agent_desk'` works, all constants available |
| M1: Tool Loop | 0020, 0030, 0090, 0092, 0095 | Working agent that calls tools against an LLM with event publishing and graceful context management |
| M2: Profiles | 0040 | Multiple agent configurations |
| M3: Power Tools | 0050 | Agent reads/writes files, runs commands |
| M4: Prompt System | 0060, 0070 | Full system prompt with rules |
| M5: Skills & Memory | 0080, 0100 | Skill activation + persistent memory |
| M6: Full Parity | 0110 | All tool groups |

---

## 8. Next Steps

See `recommendations.md` in this directory for the full list of improvements and the parallelization strategy before implementation begins.
