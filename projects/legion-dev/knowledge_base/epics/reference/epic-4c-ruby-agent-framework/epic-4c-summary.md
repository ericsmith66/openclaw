# Epic 4C Summary — Ruby Agent Framework (`agent_desk` gem)

**Source:** `agent-forge/knowledge_base/epics/wip/epic-4c-ruby-agent-framework/`
**Status:** Complete (all 16 PRDs implemented, QA passed)
**Purpose:** Reference document for Legion — captures what was built, key decisions, and deferred work

---

## What Was Built

Epic 4C created the `agent_desk` Ruby gem — the core execution engine that Legion inherits. It was split into two sub-epics:

### 4C-Core (M0–M1) — 9 PRDs, all complete

| PRD | Title | QA Score | What It Delivers |
|-----|-------|----------|-----------------|
| 0010 | Core Types, Constants & Scaffold | 95 | Gem structure, constants, types (`ToolApprovalState`, `ReasoningEffort`, `ContextFile`, `ContextMessage`, `SubagentConfig`), `TOOL_DESCRIPTIONS` (32 entries) |
| 0005 | Test Harness & Contract Tests | 93 | Minitest setup, SimpleCov, `MockModelManager`, contract test stubs for all PRDs |
| 0020 | Tool Framework & Approval System | 93 | `BaseTool`, `ToolSet`, `ToolSetBuilder`, `ApprovalManager`, deep-frozen schemas |
| 0030 | Hook System | 90 | `HookManager`, `HookResult`, lifecycle events (`on_agent_started`, `on_tool_called`, `on_tool_finished`, `on_handle_approval`) |
| 0095 | Message Bus | 93 | `MessageBusInterface`, `CallbackBus` (in-memory, thread-safe, zero deps), `Event`, `Events` (8 types), `Channel` (wildcard matching) |
| 0091 | Model Manager (SmartProxy Client) | 95 | Faraday HTTP client, SSE streaming, response normalization, error hierarchy |
| 0090 | Agent Runner Loop | 99 | Core execution loop — send messages + tools to LLM → process tool calls → execute → loop. Streaming, hook integration, MessageBus events |
| 0092a | Token & Cost Tracking | 93 | `TokenBudgetTracker`, `CostCalculator`, `UsageLogger` |
| 0092b | Compaction & Graceful Handoff | 93 | `StateSnapshot`, `CompactStrategy`, `HandoffStrategy`, `TieredStrategy`, Runner integration |

### 4C-Features (M2–M6) — 7 PRDs, all complete

| PRD | Title | QA Score | What It Delivers |
|-----|-------|----------|-----------------|
| 0040 | Agent Profile System | 97 | `Profile` data structure, `ProfileManager` (filesystem loading from `.aider-desk/agents/`) |
| 0050 | Power Tools | 94 | 7 tools: `file_read`, `file_write`, `file_edit`, `glob`, `grep`, `bash`, `fetch` |
| 0060 | Prompt Templating & System Prompt Assembly | pending | `ToolPermissions`, `PromptTemplateData`, `PromptsManager` (Liquid templates, override chain: project → global → bundled) |
| 0070 | Rules System | - | `RulesLoader`, 3-tier discovery (global → project → agent-specific), CDATA formatting |
| 0080 | Skills System | 97 | `SkillLoader`, SKILL.md parsing (YAML frontmatter + markdown), `activate_skill` tool |
| 0100 | Memory System | 95 | `MemoryStore` (JSON file persistence), 5 memory tools (store, retrieve, delete, list, update) |
| 0110 | Todo, Task & Helper Tool Groups | 98 | 13 tools: 4 todo + 2 helper (`no_such_tool`, `invalid_tool_arguments`) + 7 task tools |

### Final Stats
- **508 runs, 997 assertions, 0 failures** (4C-Core)
- **744 runs, 2000 assertions, 0 failures** (4C-Features, final)
- **All QA scores ≥ 90** (range: 90–99)
- **Dependencies:** `faraday ~> 2.0`, `liquid ~> 5.0` (runtime); `rake`, `minitest`, `simplecov` (dev)

---

## Key Architectural Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Gem lives in-repo (`gems/agent_desk/`) | Avoids cross-repo dependency; Legion owns its copy |
| 2 | Minitest only (never RSpec) | Project convention |
| 3 | WorkflowEngine NOT in gem | Gem provides primitives; orchestration is a Rails service |
| 4 | `liquid` for templates (not Handlebars) | `handlebars.rb` abandoned; Liquid is well-maintained |
| 5 | MessageBus is in-memory (`CallbackBus`) | Zero dependencies; external adapters (PostgresBus) can be added later |
| 6 | MemoryStore is file-based (JSON) | Portable, survives restarts, no DB dependency |
| 7 | Single accumulating branch (`epic-4c/foundation`) | Per-PRD branches caused cross-contamination |
| 8 | Tool groups use `---` separator | Matches AiderDesk convention: `power---file_read`, `skills---activate_skill` |
| 9 | Profile approval states: `always`/`ask`/`never` | Per-tool granularity in agent config |

---

## Deferred Features (Not Built — Potential Future Work)

### Still Deferred (Relevant to Legion)

| ID | Feature | Impact | Effort | Notes |
|----|---------|--------|--------|-------|
| **D5** | Hook Configuration UI | Low | Low | Hooks are a developer API, not end-user configurable. May be intentionally out of scope |
| **D6** | Prompt Template Preview UI | Medium | Low | Would help debug agent behavior — see assembled prompt for a given profile |
| **D7** | MCP Client Support | High | High | Connecting gem to external MCP servers. Not in scope for Legion bootstrap |
| **D9** | Subagent/Task Delegation | High | Medium | Multi-agent orchestration (one agent spawning subtasks on different profiles). `subagents---run_task` exists in AiderDesk but not fully replicated in gem |

### Addressed by Epic 5 (Agent-Forge, NOT carried to Legion)

These were deferred from 4C but addressed by Epic 5's File Maintenance UI in agent-forge. Legion does NOT inherit Epic 5 — these would need new epics if wanted:

| ID | Feature | Epic 5 Resolution | Legion Status |
|----|---------|-------------------|---------------|
| D1 | Agent Profile UI | PRD-5020, PRD-5025 — web UI with Turbo Streams | **Not planned** — CLI-first, filesystem config |
| D2 | Skill Management UI | PRD-5030, PRD-5035 — browser, editor, activation tracking | **Not planned** — filesystem skills |
| D3 | Rule File Management UI | PRD-5040, PRD-5045, PRD-5048 — hierarchy visualizer, assembly cache | **Not planned** — filesystem rules |
| D4 | Custom Command UI | PRD-5050 — browser, editor, usage history | **Not planned** — filesystem commands |

### Ideas Backlog (from agent-forge)

From `aider-desk-integration-ideas.md`:
- **RAG Engine** for advanced context injection
- **Cost Tracking** across providers and task types
- **Batch Processing** of multiple tasks in parallel (git worktree approach)
- **Webhook Notifications** for task completion
- **Custom Failure Classifiers** (plug-in architecture)
- **Multi-project Concurrency** management
- **Workflow Automation** (chaining multiple agents automatically)
- **Agent Marketplace** (sharing/importing community agent profiles)

---

## Storage Architecture (from agent-forge)

The gem uses a **tri-storage architecture**:

| Layer | What's Stored | Legion Relevance |
|-------|---------------|-----------------|
| **Filesystem** (`.aider-desk/`) | Agent profiles (JSON), rules (MD), skills (MD), commands (MD), prompts (Liquid), memory (JSON) | ✅ Primary — gem loads all config from filesystem |
| **PostgreSQL** (Rails) | Agent-forge stored profiles, skills, rules in DB with Turbo Streams UI | ❌ Not applicable until Legion adds UI (Epic 4) |
| **In-Memory** | Todo list, task registry, conversation history, tool approval state, streaming chunks | ✅ Used during agent runs — ephemeral |

**Key principle:** Gem is filesystem-first. A Rails app (like Legion, eventually) can add a DB layer via adapter pattern, but the gem itself has zero ActiveRecord dependencies.

---

## What This Means for Legion

1. **Epic 0** copies the completed gem as-is — all 16 PRDs already implemented and tested
2. **Epic 1** (Data Model) can design schema knowing the gem has no DB coupling
3. **Epic 2** (WorkflowEngine) builds on the gem's Runner, MessageBus, and Hook primitives
4. **Epic 3** (Quality Gates) can use the Hook system for gate enforcement
5. **Epic 4** (UI) can reference the Workspace component and agent-forge's Epic 5 UI patterns if desired
6. **Deferred D7 (MCP)** and **D9 (Subagent Delegation)** are the highest-impact future features to consider

---

*This document is a reference summary. Full source material is in `agent-forge/knowledge_base/epics/wip/epic-4c-ruby-agent-framework/`.*
