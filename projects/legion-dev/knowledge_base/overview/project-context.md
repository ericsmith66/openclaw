# Legion — Project Context & Lineage

**Status:** Active — Epic 1 (Orchestration Foundation)
**Created:** March 5, 2026
**Author:** Eric Smith + AI Architecture Review

---

## 1. What is Legion?

Legion is a **CLI-first Rails 8 application** that orchestrates AI agent teams to execute structured software development workflows. It automates the 14-phase RULES.md lifecycle (Idea → Retrospective) by dispatching tasks to specialized agents through the `agent_desk` Ruby gem, which communicates with LLM providers via SmartProxy.

### Core Proposition

| Layer | What | Technology |
|-------|------|------------|
| **Orchestration** | WorkflowEngine state machine — strings tasks into phases | Rails models + Solid Queue |
| **Execution** | agent_desk gem — Agent Runner, Tools, Hooks, MessageBus | Pure Ruby gem (Faraday, Liquid) |
| **LLM Communication** | SmartProxy — reverse proxy to Claude, Deepseek, Ollama, etc. | External Sinatra service (port 3002) |
| **Storage** | PostgreSQL — epics, PRDs, tasks, metrics, artifacts | Rails 8 Active Record |
| **UI** (Epic 4+) | Workspace layout with Turbo Streams | ViewComponent + DaisyUI + Stimulus |

### CLI-First Architecture

Epics 0–3 are entirely CLI/backend. The UI comes in Epic 4. This ensures the orchestration engine is solid before adding visual layers.

---

## 2. Lineage — Where Legion Comes From

Legion is a **clean-start successor** to the `agent-forge` project (`/Users/ericsmith66/development/agent-forge`). Agent-forge was an exploratory project that produced significant working assets but accumulated architectural baggage that made incremental improvement costlier than a fresh start.

### Why Start Fresh (Not Refactor)?

| Factor | Agent-Forge State | Legion Decision |
|--------|-------------------|-----------------|
| **Dead code** | 1,543 LOC dead AiderDesk lib + 2,687 LOC dead tests | Start clean — zero dead code |
| **View layer** | Most views need refactoring; no cohesive UI strategy | CLI-first; bring UI in Epic 4 with clean ViewComponents |
| **Authentication** | Devise in Gemfile but never implemented | Skip auth — single-user CLI app |
| **Database** | 22 migrations, 14 tables — never in production | Design schema from scratch with relationship architecture PRD |
| **Coordinator** | AiderDesk-coupled coordinator service | Build WorkflowEngine natively for agent_desk gem |
| **Knowledge base** | Valuable content mixed with abandoned/outdated docs | Curate and cherry-pick only what's relevant |
| **Gem** | agent_desk gem is mature (5,192 LOC, 50 lib files, 64 tests) | Copy into Legion — crown jewel |

### What Agent-Forge Produced (Historical)

- **Epic 1:** Bootstrap — Rails 8 project scaffolding
- **Epic 2:** UI Foundation — Basic layout and components
- **Epic 3:** AiderDesk spike — Integration exploration
- **Epic 4:** AiderDesk implementation → pivoted to 4C (Ruby Agent Framework = agent_desk gem)
- **Epic 5:** File Maintenance UI (completed Φ5 architect review, never coded)
- **Epic 6:** WorkflowEngine (spec'd extensively, never started — architecture review identified gaps)

The Epic 6 architecture review (by Eric + AI) surfaced fundamental questions about orchestration, skill/rule mapping, and PRD sizing that led to the decision to start Legion fresh rather than build on top of agent-forge's accumulated complexity.

---

## 3. Cherry-Pick Inventory — What Carries Forward

### 3.1 The Gem: `agent_desk` (CRITICAL)

**Source:** `agent-forge/gems/agent_desk/`
**Destination:** `legion/gems/agent_desk/`
**Why:** This is the core execution engine. 100% of agent dispatch runs through it.

| Module | LOC | Purpose |
|--------|-----|---------|
| `Agent::Runner` | ~200 | Core execution loop — sends prompts, processes tool calls, iterates |
| `Agent::Profile` | ~50 | Data structure for agent configuration |
| `Agent::ProfileManager` | ~80 | Loads agent profiles from `~/.aider-desk/agents/` and `.aider-desk/agents/` |
| `Models::ModelManager` | ~150 | Communicates with SmartProxy; handles SSE streaming |
| `Models::ResponseNormalizer` | ~100 | Normalizes LLM responses across providers |
| `Models::SSEParser` | ~80 | Server-Sent Events parser for streaming |
| `Prompts::PromptsManager` | ~120 | Loads and applies Liquid templates for system prompts |
| `Rules::RulesLoader` | ~60 | Loads `.md` rule files from `.aider-desk/rules/` |
| `Skills::SkillLoader` | ~70 | Loads skill definitions from `.aider-desk/skills/` |
| `Skills::Skill` | ~50 | Skill data structure |
| `Tools::*` | ~500 | Tool framework (BaseTool, PowerTools, MemoryTools, TodoTools, etc.) |
| `Hooks::HookManager` | ~80 | Pre/post-execution hooks |
| `MessageBus::*` | ~200 | Event system (CallbackBus, Channel, Event) |
| `Memory::MemoryStore` | ~60 | Agent memory persistence |

**Dependencies:** `faraday ~> 2.0`, `liquid ~> 5.0`
**Test files:** 64 Minitest files

### 3.2 Workspace Component (VALUABLE)

**Source:** `agent-forge/app/components/workspace/`
**Destination:** `legion/app/components/workspace/` (Epic 4)

| File | LOC | What |
|------|-----|------|
| `layout_component.rb` | 119 | 3-panel layout with slots: left panel, center chat, right panel, drawers, toolbar |
| `layout_component.html.erb` | 213 | Tailwind/DaisyUI template with responsive breakpoints |
| `README.md` | ~50 | Component documentation and usage |

**Also:** `agent-forge/docs/mocks/workspace-mock.html` — standalone HTML mockup for design reference.

### 3.3 Knowledge Base Content (CURATED)

| Item | Source Path | Carry Forward? | Notes |
|------|-------------|---------------|-------|
| RULES.md (14-phase lifecycle) | `knowledge_base/instructions/RULES.md` | ✅ YES — adapt for Legion | Core workflow definition; needs Legion-specific updates |
| PRD template | `knowledge_base/templates/PRD-template.md` | ✅ YES | Standard format |
| Epic overview template | `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md` | ✅ YES | Standard format |
| Implementation status template | `knowledge_base/templates/0001-IMPLEMENTATION-STATUS-template.md` | ✅ YES | Standard format |
| Pre-QA checklist template | `knowledge_base/templates/pre-qa-checklist-template.md` | ✅ YES | Quality gate tool |
| Retrospective template | `knowledge_base/templates/retrospective-report-template.md` | ✅ YES | For Φ14 |
| SmartProxy docs | `knowledge_base/smart-proxy.md` | ✅ YES — reference doc | External service docs |
| AI instructions (logging) | `knowledge_base/ai-instructions/log-requirement.md` | ✅ YES | Agent behavior rules |
| Architecture docs | `knowledge_base/architecture/` | ⚠️ REVIEW | Storage strategy may need rewrite for Legion's schema |
| Epic 5 PRDs | `knowledge_base/epics/wip/epic-5/` | 📦 ARCHIVE | Reference for UI ideas; not directly applicable |
| Epic 6 specs | `knowledge_base/epics/wip/epic-6-workflow-engine/` | 📦 ARCHIVE | Input to Legion Epics 2–5; architecture was reviewed |
| Epic 1-4 content | Various | ❌ NO | Historical only |

### 3.4 `.aider-desk` Configuration (ESSENTIAL)

This is required for the gem to function. Legion needs its own `.aider-desk/` config:

| Item | Source | Notes |
|------|--------|-------|
| **Agent profiles** (project-level) | `.aider-desk/agents/ror-{rails,architect,qa,debug}/config.json` | Copy and update `projectDir` to Legion path |
| **Agent profiles** (global) | `~/.aider-desk/agents/ror-{rails,architect,qa,debug}/` | Shared — no copy needed |
| **Agent order** | `.aider-desk/agents/order.json` | Copy |
| **Rules** | `.aider-desk/rules/rails-base-rules.md` | Copy and adapt for Legion |
| **Skills** (10 dirs) | `.aider-desk/skills/` | Copy all 10 skill directories |
| **Commands** (6 files) | `.aider-desk/commands/` | Copy relevant ones (implement-prd, review-epic, roll-call, validate-installation) |
| **Prompts** | `.aider-desk/prompts/delegation-rules.md` | Copy — this is the Blueprint Workflow |

---

## 4. The ROR Agent Team

Four specialized agents form the development team. Each has a dedicated LLM provider/model optimized for its role:

| Agent | ID | Provider | Model | Max Iterations | Role |
|-------|-----|----------|-------|---------------|------|
| **Rails Lead** | `ror-rails-agent-forge` | Deepseek | `deepseek-reasoner` | 200 | Implementation — writes code, creates PRD plans, runs pre-QA |
| **Architect** | `ror-architect-agent-forge` | Anthropic | `claude-opus-4-6` | 197 | Reviews plans, creates epic master plans, architecture decisions |
| **QA** | `ror-qa-agent-forge` | Anthropic | `claude-sonnet-4-6` | 200 | Scores implementations 0-100, runs verification checks |
| **Debug** | `ror-debug-agent-forge` | Anthropic | `claude-sonnet-4-6` | 66 | Troubleshooting specialist — delegated to on failures |

### How They Work Together (Blueprint Workflow)

```
PLAN → APPROVE → CODE → PRE-QA → SCORE → DEBUG (if <90)
  │        │        │       │        │         │
  Lead   Architect  Lead   Lead     QA      Debug
```

1. **Lead** creates `PRD-{id}-implementation-plan.md` and commits it
2. **Architect** reviews, appends `## Architect Review & Amendments`, returns `PLAN-APPROVED`
3. **Lead** re-reads (plan may be amended), implements code + tests
4. **Lead** runs Pre-QA checklist (rubocop, frozen_string_literal, full test suite)
5. **QA** scores 0-100 with per-criteria breakdown, saves report
6. **Debug** fixes issues if score < 90 — then re-submit to QA

### Communication Path

```
Legion WorkflowEngine (state machine)
  └── dispatches Task to gem Runner with agent Profile
        └── Runner calls SmartProxy via ModelManager (Faraday HTTP)
              └── SmartProxy routes to LLM (Claude/Deepseek/Ollama)
                    └── Response streams back via SSE
```

SmartProxy runs at `localhost:3002` and accepts OpenAI-compatible `/v1/chat/completions` requests. It handles provider authentication, routing, rate limiting, and fallback logic transparently.

---

## 5. Technology Stack

| Category | Technology | Notes |
|----------|-----------|-------|
| **Framework** | Rails 8.1 | Latest |
| **Ruby** | 3.3+ | Modern syntax features |
| **Database** | PostgreSQL | Via `pg` gem |
| **Asset Pipeline** | Propshaft | Rails 8 default |
| **CSS** | Tailwind CSS + DaisyUI | Utility-first + component library |
| **JS** | Importmap + Stimulus | No webpack/esbuild |
| **Real-time** | Turbo (Frames + Streams) | Server-driven UI updates |
| **Background Jobs** | Solid Queue | Rails 8 default, DB-backed |
| **WebSockets** | Solid Cable | Rails 8 default, DB-backed |
| **Cache** | Solid Cache | Rails 8 default, DB-backed |
| **Components** | ViewComponent ~> 3.0 | Modular UI |
| **Testing** | Minitest + Capybara + VCR + WebMock | Never RSpec |
| **Factories** | FactoryBot | Test data setup |
| **Code Quality** | RuboCop (Rails Omakase) | Automated linting |
| **LLM Proxy** | SmartProxy (external) | Sinatra service on port 3002 |
| **Agent Framework** | agent_desk gem | In-repo at `gems/agent_desk/` |

### NOT in Stack (Intentional Omissions)

| Omitted | Why |
|---------|-----|
| Devise | Single-user CLI app — no auth needed |
| RSpec | Project standard is Minitest |
| Webpack/esbuild | Importmap is sufficient |
| Redis | Solid Queue/Cable/Cache use PostgreSQL |

---

## 6. Epic Roadmap (High Level)

| Epic | Name | Focus | Depends On |
|------|------|-------|------------|
| **0** | Bootstrap | KB curation, `rails new`, gem integration, `.aider-desk` config | — |
| **1** | Orchestration Foundation | Schema (7 models), PostgresBus, CLI dispatch, task decomposition with dependency DAG, plan execution | Epic 0 |
| **2** | WorkflowEngine Core | State machine, automatic chaining, parallel dispatch, auto-decomposition | Epic 1 |
| **3** | Quality & Human Gates | QA scoring, approval workflows, metrics capture | Epic 2 |
| **4** | UI & Observability | Workspace layout, real-time streaming, dashboards | Epic 3 |

**Epics 0–3:** CLI only
**Epic 4:** UI layer added

---

## 7. Key Architectural Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| **AD-1** | CLI-first, UI later | Validate orchestration engine before visual complexity |
| **AD-2** | Gem copied into repo (not external) | Legion owns its copy; avoids cross-repo dependency management |
| **AD-3** | SmartProxy is external | It's a shared service; gem communicates via HTTP — no coupling |
| **AD-4** | Relationship architecture PRD before any code (Epic 1) | Prevent the schema sprawl that happened in agent-forge |
| **AD-5** | Retrospective (Φ14) is manual | Metrics captured during execution; human does the synthesis |
| **AD-6** | No Devise | Single-user dev tool; auth adds complexity without value |
| **AD-7** | PRDs ≤ 400 lines | AI agents struggle with large PRDs; right-size everything |
| **AD-8** | Fresh DB schema | Agent-forge's 14 tables were never in production; design clean |

---

## 8. SmartProxy Reference

SmartProxy is a **Sinatra-based reverse proxy** from the `nextgen-plaid` project that provides a single OpenAI-compatible endpoint for multiple LLM backends.

| Property | Value |
|----------|-------|
| **Repo** | `github.com/ericsmith66/nextgen-plaid` (smart_proxy directory) |
| **Port** | 3002 (default, via `SMART_PROXY_PORT`) |
| **Endpoint** | `POST /v1/chat/completions` |
| **Supported Backends** | Claude (Anthropic), Deepseek, Fireworks AI, Ollama (local) |
| **Protocol** | OpenAI-compatible; supports SSE streaming |

The gem's `ModelManager` sends requests to SmartProxy. The agent profile specifies `provider` and `model`; SmartProxy handles the actual routing and authentication.

---

## 9. Glossary

| Term | Definition |
|------|-----------|
| **Blueprint Workflow** | Plan → Approve → Code → Pre-QA → Score → Debug cycle |
| **RULES.md** | 14-phase lifecycle (Φ1–Φ14) governing epic/PRD progression |
| **WorkflowEngine** | State machine that orchestrates phases and dispatches tasks |
| **SmartProxy** | Reverse LLM proxy — the gem's HTTP backend for all LLM calls |
| **agent_desk gem** | Ruby gem providing Agent Runner, Tools, Hooks, MessageBus |
| **Profile** | Agent configuration (provider, model, system prompt, tool permissions) |
| **Task** | A unit of work dispatched to an agent (e.g., "implement PRD-0-02") |
| **Phase (Φ)** | A step in the 14-phase lifecycle (Idea, Drafting, Review, etc.) |
| **Skill** | A markdown knowledge file loaded into agent context for specialized tasks |
| **Rule** | A markdown file defining constraints agents must follow |
| **PRD** | Product Requirements Document — atomic, independently implementable unit |

---

*This document is the primary context source for any AI agent or human starting work on Legion.*
