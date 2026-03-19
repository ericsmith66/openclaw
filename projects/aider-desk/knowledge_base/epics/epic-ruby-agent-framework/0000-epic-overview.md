# Epic: Ruby Agent Framework

**Epic ID**: epic-ruby-agent-framework
**Status**: Active
**Priority**: High
**Created**: 2026-02-26
**Owner**: Engineering Team

---

## 🎯 Epic Goal

Build a standalone Ruby gem (`agent_desk`) that replicates the core agent orchestration architecture from AiderDesk — specifically the **agent profile → tool calling → skill activation → rule loading → prompt templating → hook interception** pipeline — so that Ruby applications can run LLM agents with the same structured, extensible framework.

**This is NOT a UI port.** It is a backend framework for agent orchestration.

---

## 📋 Problem Statement

AiderDesk's agent system has matured into a well-structured architecture for:
- Defining agent capabilities via **profiles** (which tools, which LLM, what rules)
- Organizing tools into **named groups** with per-tool **approval policies**
- Loading project/agent **rules** from the filesystem and injecting them into prompts
- Discovering and activating **skills** from markdown files at runtime
- Assembling **system prompts** from Handlebars templates with conditional sections
- Running an **agent loop** that streams LLM responses and executes tool calls
- Intercepting agent/tool lifecycle events via **hooks**

We want this same architecture available in Ruby for:
1. Ruby-based CLI agents and automation scripts
2. Ruby API servers that need structured agent orchestration
3. Teams that prefer Ruby but want AiderDesk-grade agent tooling

---

## 💡 Strategic Approach: Iterative Milestones

### Core Philosophy: **Useful Code Early, Full Feature Set Iteratively**

Each PRD delivers a **runnable, testable increment**. After PRD-0010 + PRD-0020 + PRD-0090, you have a working agent that can call tools and talk to an LLM. Later PRDs add skills, rules, memory, etc.

### Milestone Map

| Milestone | PRDs | Deliverable | You Can... |
|-----------|------|-------------|------------|
| **M0: Scaffold** | 0010 | Gem structure, types, constants | `require 'agent_desk'` and reference all tool constants |
| **M1: Tool Loop** | 0020, 0030, 0090, 0092, 0095 | Tool framework + hooks + agent runner + token budget + message bus | Run an agent that calls tools against an LLM with event publishing and graceful context management |
| **M2: Profiles** | 0040 | Agent profile system | Configure different agents with different tool sets |
| **M3: Power Tools** | 0050 | File/bash/search tools | Agent can read/write files, run commands, search code |
| **M4: Prompt System** | 0060, 0070 | Templating + rules | Full system prompt assembly with project rules |
| **M5: Skills & Memory** | 0080, 0100 | Skills + memory | Agent activates skills and remembers across sessions |
| **M6: Full Parity** | 0110 | Todo, task, helper tools | Complete tool group parity with AiderDesk |

---

## 📊 Key Metrics

### Success Criteria
- ✅ After M1: A Ruby script can run an LLM agent that calls custom tools and returns results
- ✅ After M2: Multiple agent profiles with different tool permissions
- ✅ After M3: Agent can read files, run bash, search code in a project directory
- ✅ After M4: System prompt matches AiderDesk's XML structure with conditional sections
- ✅ After M5: Skills discovered from filesystem and activated; memory persisted to SQLite/JSON
- ✅ After M6: Feature parity with AiderDesk's agent backend (minus Electron/React UI)

### Quality Gates (every PRD)
- Unit tests with >80% coverage for new code
- Type annotations (Sorbet or YARD) for public interfaces
- README with usage example updated per milestone

---

## 🗂️ PRD Inventory

| PRD | Name | Milestone | Status | Depends On |
|-----|------|-----------|--------|------------|
| 0010 | Core Types, Constants & Project Scaffold | M0 | Draft | — |
| 0020 | Tool Framework & Approval System | M1 | Draft | 0010 |
| 0030 | Hook System | M1 | Draft | 0010 |
| 0040 | Agent Profile System | M2 | Draft | 0010, 0020 |
| 0050 | Power Tools | M3 | Draft | 0020 |
| 0060 | Prompt Templating & System Prompt | M4 | Draft | 0010, 0040 |
| 0070 | Rules System | M4 | Draft | 0060 |
| 0080 | Skills System | M5 | Draft | 0020, 0060 |
| 0090 | Agent Runner Loop | M1 | Draft | 0020, 0030 |
| 0092 | Token Budget Management & Graceful Handoff | M1 | Draft | 0090, 0030, 0095 |
| 0095 | Message Bus | M1 | Draft | 0010 |
| 0100 | Memory System | M5 | Draft | 0020 |
| 0110 | Todo, Task & Helper Tool Groups | M6 | Draft | 0020 |

### Dependency Graph

```
0010 (types/constants)
 ├── 0020 (tool framework)
 │    ├── 0050 (power tools)
 │    ├── 0080 (skills tools)
 │    ├── 0100 (memory tools)
 │    └── 0110 (todo/task/helper tools)
 ├── 0030 (hooks)
 ├── 0040 (profiles) ← 0020
 ├── 0060 (prompts) ← 0040
 │    └── 0070 (rules)
 └── 0095 (message bus)

0090 (agent runner) ← 0020, 0030
0092 (token budget / handoff) ← 0090, 0030, 0095
```

---

## 🔗 AiderDesk Source Mapping

Each PRD maps to specific AiderDesk source files for reference:

| Ruby Module | AiderDesk Source |
|-------------|-----------------|
| `AgentDesk::Types` | `src/common/types.ts`, `src/common/tools.ts` |
| `AgentDesk::Tools::*` | `src/main/agent/tools/*.ts` |
| `AgentDesk::Agent::Profile` | `src/common/agent.ts`, `src/main/agent/agent-profile-manager.ts` |
| `AgentDesk::Agent::Runner` | `src/main/agent/agent.ts` (runAgent, processStep) |
| `AgentDesk::Hooks::Manager` | Hook trigger/block pattern in `agent.ts` |
| `AgentDesk::Prompts::Manager` | `src/main/prompts/prompts-manager.ts` |
| `AgentDesk::Rules::Loader` | Rule loading in `agent-profile-manager.ts` |
| `AgentDesk::Skills::Loader` | `src/main/agent/tools/skills.ts` |
| `AgentDesk::Tools::ApprovalManager` | `src/main/agent/tools/approval-manager.ts` |
| `AgentDesk::Memory::Manager` | Memory tools in `src/main/agent/tools/memory.ts` |
| `AgentDesk::MessageBus` | `src/main/events/event-manager.ts` (EventManager) |

---

## 🏗️ Technology Decisions

| Concern | Decision | Rationale |
|---------|----------|-----------|
| Language | Ruby >= 3.2 | Target audience, modern features (pattern matching, etc.) |
| LLM Client | `ruby-openai` + `anthropic` gems | OpenAI-compatible API covers most providers; Anthropic for Claude |
| Template Engine | `liquid` or `handlebars.rb` | Match AiderDesk's Handlebars approach |
| JSON Schema | `json_schemer` | Tool input validation (matches AI SDK's Zod schemas) |
| File Watching | `listen` gem | Rules/skills hot-reload (matches AiderDesk's chokidar) |
| Testing | RSpec | Ruby standard |
| Type Annotations | YARD docs | Pragmatic for Ruby (Sorbet optional) |
| Packaging | RubyGem | Standard distribution |

---

## 📅 Estimated Timeline

| Milestone | Estimated Effort | Cumulative |
|-----------|-----------------|------------|
| M0: Scaffold | 2-4 hours | 2-4 hours |
| M1: Tool Loop (incl. Message Bus + Token Budget) | 16-22 hours | 18-26 hours |
| M2: Profiles | 4-6 hours | 14-22 hours |
| M3: Power Tools | 6-8 hours | 20-30 hours |
| M4: Prompt System | 6-8 hours | 26-38 hours |
| M5: Skills & Memory | 6-8 hours | 32-46 hours |
| M6: Full Parity | 4-6 hours | 36-52 hours |

**Total**: ~36-52 hours of implementation work

---

## 🎯 Non-Goals (Explicit Exclusions)

1. **No Electron/desktop UI** — this is backend-only
2. **No Aider Python integration** — AiderDesk's `connector.py` is a separate concern; Ruby tools replace it
3. **No MCP server** — MCP client (connecting to external MCP servers) is a future enhancement, not in initial scope
4. **No real-time WebSocket events** — CLI/API output only initially
5. **No database** — File-based persistence (JSON profiles, SQLite for memory if needed)

---

## 📝 Notes

- The Ruby framework should feel idiomatic Ruby, not a line-for-line TypeScript translation
- Use Ruby conventions: snake_case, blocks, modules, duck typing
- Each PRD includes the specific AiderDesk source files to reference during implementation
- The `ruby-agent-framework/` directory already exists with a premature scaffold — it should be replaced by PRD-0010's proper scaffold

---

**Last Updated**: 2026-02-26
**Next Review**: After M1 completion
