# Legion — Baseline Technology Stack

**Created:** 2026-03-06
**Status:** Locked (Epic 0 Bootstrap)
**Applies to:** All Legion development

---

## Core Framework

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Language** | Ruby | 3.3.10 | Runtime language |
| **Framework** | Ruby on Rails | 8.1.2 | Web framework, MVC, ORM |
| **Server** | Puma | ≥ 5.0 | HTTP server |
| **Database** | PostgreSQL | 16 | Primary data store |
| **Asset Pipeline** | Propshaft | (bundled) | Asset serving (replaces Sprockets) |

---

## Frontend Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **CSS Framework** | Tailwind CSS | Utility-first styling |
| **Component Library** | DaisyUI | Pre-built Tailwind components |
| **Typography** | @tailwindcss/typography | Prose styling for markdown content |
| **JavaScript** | Importmap | ESM import maps (no Node.js bundler in production) |
| **SPA-like Navigation** | Turbo (Hotwire) | Page acceleration, Turbo Frames, Turbo Streams |
| **JS Framework** | Stimulus (Hotwire) | Modest JavaScript controllers |
| **View Components** | ViewComponent ~> 3.0 | Encapsulated, testable view components |

---

## Background & Real-time Infrastructure

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Job Queue** | Solid Queue | Database-backed Active Job adapter |
| **Caching** | Solid Cache | Database-backed Rails.cache adapter |
| **WebSocket** | Solid Cable | Database-backed Action Cable adapter |

> All three Solid adapters use PostgreSQL as their backing store, eliminating the need for Redis.

---

## AI / Agent Infrastructure

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Agent Gem** | agent_desk (in-repo) | Agent profiles, runners, message bus, memory store |
| **LLM Proxy** | SmartProxy (external) | Sinatra reverse proxy on port 3002, OpenAI-compatible API |
| **LLM Providers** | Claude, Deepseek, Grok, Ollama | Routed via SmartProxy |
| **Agent Config** | .aider-desk/ (filesystem) | Agent profiles, rules, skills, commands, prompts |

---

## Secrets & Configuration

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Environment Variables** | dotenv-rails | Loads `.env` in development/test |
| **Credentials** | Rails credentials | Encrypted secrets for production |
| **Env File** | `.env` (gitignored) | SmartProxy URL, token, port, host |
| **Env Template** | `.env.example` (committed) | Documentation of required env vars |

---

## Testing Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Test Framework** | Minitest | Unit, integration, system tests (**never RSpec**) |
| **System Tests** | Capybara + Selenium | Browser-based end-to-end tests |
| **HTTP Mocking** | WebMock | Stub external HTTP requests in tests |
| **HTTP Recording** | VCR | Record and replay SmartProxy interactions |
| **Code Coverage** | SimpleCov | Coverage reporting |

---

## Code Quality & Security

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Linter** | RuboCop (rails-omakase) | Ruby style enforcement |
| **Security Scanner** | Brakeman | Static analysis for Rails security |
| **Dependency Audit** | bundler-audit | Known vulnerability detection |
| **Pre-QA Script** | `scripts/pre-qa-validate.sh` | Automated hygiene checks before QA |
| **Markdown Rendering** | Redcarpet ~> 3.6 | Server-side markdown to HTML |

---

## Deployment

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Container** | Docker (Dockerfile) | Containerized deployment |
| **Deployment Tool** | Kamal | Zero-downtime Docker deployment |
| **Reverse Proxy** | Thruster | HTTP caching/compression for Puma |

---

## Key Architectural Decisions

1. **No Redis** — Solid Queue/Cache/Cable use PostgreSQL, simplifying infrastructure.
2. **No Node.js bundler** — Importmap eliminates Webpack/esbuild. Node.js is only needed for Tailwind CSS build.
3. **In-repo gem** — `agent_desk` lives at `gems/agent_desk/` for tight coupling during development.
4. **File-based agent config** — `.aider-desk/` directory structure, not database-backed.
5. **In-memory message bus** — `CallbackBus` (thread-safe, zero dependencies), not PostgreSQL-backed.
6. **File-based memory store** — JSON persistence, not PostgreSQL-backed.
7. **SmartProxy is external infrastructure** — Always-on Sinatra service, not part of Legion's Rails app.
8. **Minitest only** — No RSpec under any circumstances unless explicitly requested by Eric.

---

## Database Schema

At bootstrap, only Rails-generated schemas exist:
- `db/cache_schema.rb` — Solid Cache tables
- `db/queue_schema.rb` — Solid Queue tables
- `db/cable_schema.rb` — Solid Cable tables

Application models are introduced in Epic 1 (Data Model).
