# Legion

**AI Agent Orchestration Engine** — CLI-first Rails 8 application that orchestrates specialized AI agent teams through structured software development workflows.

## What It Does

Legion automates the 14-phase RULES.md lifecycle (Idea → Retrospective) by:
1. **Orchestrating** phases via a WorkflowEngine state machine
2. **Dispatching** tasks to specialized agents (Rails Lead, Architect, QA, Debug) through the `agent_desk` Ruby gem
3. **Communicating** with LLM providers (Claude, Deepseek, Ollama) via SmartProxy reverse proxy
4. **Tracking** metrics, scores, and quality gates throughout the development cycle

## Architecture

```
Legion WorkflowEngine (state machine)
  └── dispatches Task → agent_desk gem Runner (with agent Profile)
        └── Runner → SmartProxy (192.168.4.253:3002) → LLM Provider
              └── Response streams back via SSE
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Rails 8.1 + Ruby 3.3+ |
| Database | PostgreSQL |
| Assets | Propshaft + Tailwind CSS + DaisyUI |
| JS | Importmap + Stimulus |
| Real-time | Turbo + Solid Cable |
| Jobs | Solid Queue |
| Components | ViewComponent |
| Testing | Minitest + Capybara + VCR |
| Agent Framework | agent_desk gem (in-repo) |
| LLM Proxy | SmartProxy (external) |

## Epic Roadmap

| Epic | Focus | Status |
|------|-------|--------|
| 0 - Bootstrap | KB curation, Rails new, gem integration | 🟡 In Progress |
| 1 - Data Model | Relationship architecture, schema, gem↔DB | Planned |
| 2 - WorkflowEngine Core | State machine, task dispatch, phases | Planned |
| 3 - Quality & Human Gates | QA scoring, approvals, metrics | Planned |
| 4 - UI & Observability | Workspace layout, streaming, dashboards | Planned |

## Lineage

Legion is a clean-start successor to the [agent-forge](https://github.com/ericsmith66/agent-forge) project. See `knowledge_base/overview/project-context.md` for full lineage and architectural decisions.

## Prerequisites

- Ruby 3.3+
- PostgreSQL
- SmartProxy running on port 3002
- Node.js (for Tailwind CSS build)

## Getting Started

```bash
# After Epic 0 is complete:
bundle install
rails db:create db:migrate
rails s
```

## License

Private — All rights reserved.
