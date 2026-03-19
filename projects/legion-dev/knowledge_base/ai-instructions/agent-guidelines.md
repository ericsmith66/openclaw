# Agent Guidelines — Legion

Updated 2026-03-05: Adapted from the predecessor project for Legion.

These are **project-specific operating rules** for AI coding agents (Claude, Deepseek, Grok, etc.) working in this repository.

They are written to be:
- **Actionable** (clear do/don't)
- **Safe** (avoid destructive commands, repo corruption)
- **Consistent** (match Rails + Legion conventions)

Legion is a **CLI-first Rails 8 AI agent orchestration engine**. Primary stack: Ruby on Rails 8.1.

---

## 1) Repo overview (what this is)

- Ruby on Rails 8.1 application (API + web for agent orchestration/dashboard).
- UI work frequently uses:
  - Hotwire/Turbo (`turbo_frame_tag`, `turbo_stream`)
  - ViewComponent (`app/components/`)
  - DaisyUI + Tailwind CSS for styling
- Tests use **Minitest** (`test/` folder), including `ViewComponent::TestCase` and system tests with Capybara.
- Persistent knowledge & planning live in `knowledge_base/`:
  - `ai-instructions/agent-guidelines.md` (this file — global agent rules)
  - `ai-instructions/task-log-requirement.md` (logging standards)
  - Templates for Epics/PRDs/status trackers
  - Active epics, PRDs, implementation logs
- The `agent_desk` gem (in-repo at `gems/agent_desk/`) provides:
  - Agent profiles, runners, message bus, memory store
  - SmartProxy integration for LLM dispatch
- Agents interact with repo via:
  - Local file read/write
  - Git operations (safe only)
  - Future: GitHub API for PR creation/review

---

## 2) Git & Sub-Project Structure Rules

All sub-projects managed by Legion live under the `projects/` directory (e.g. `projects/eureka-homekit-rebuild`, etc.).

### Rules:

1. **Independent git repositories**
   - Every sub-project folder is its own independent git repository (has its own `.git/` directory).
   - Never nest git repositories inside Legion's root repo.
   - The parent Legion repository must **never** track files inside `projects/`.

2. **Root .gitignore update**
   Add or update the following lines in the **root** `.gitignore` of Legion:
   ```
   # Ignore all sub-projects — they are separate git repositories
   projects/*
   !projects/.gitignore
   !projects/README.md
   ```
   This prevents Legion from committing sub-project files accidentally.

3. **Per-project .gitignore**
   - Each sub-project must have its own normal `.gitignore` (e.g. Rails default: ignore `tmp/`, `log/`, `vendor/`, `.env`, etc.).
   - Do not override or remove any standard Rails ignores.

4. **Project creation / initialization**
   When creating a new sub-project (via chat command, UI, or agent action):
   - Create the folder: `projects/<project-name>`
   - Run inside it:
     ```bash
     git init
     # Add at least one file (e.g. README.md)
     echo "# <project-name> - Created by Legion" > README.md
     git add README.md
     git commit -m "Initial commit – created by Legion"
     ```
   - Optional: If GitHub integration is enabled, push to remote:
     ```bash
     gh repo create ericsmith66/<project-name> --private --source=. --remote=origin
     git push -u origin main
     ```

5. **Safety rails for git operations**
   - **Never** run `git commit`, `git push`, `git add .`, or destructive git commands without explicit user confirmation (e.g. "/commit" command in chat).
   - **Never** modify the root Legion .gitignore or .git from inside a sub-project task.
   - When editing files in a sub-project, always operate within the projectDir scope.
   - Prefer AiderDesk / Aider for code changes — it handles git diffs and commits safely (preview mode only until approved).
   - Log all git-related actions in the task log and implementation status.
   - **Single-agent concurrency rule:** Only one coding agent session may operate on Legion at a time. Never start a coding session if another agent is active on the repo. See the cross-epic execution plan for details.

6. **Existing projects (e.g. cloning external repos)**
   - Clone directly into projects/:
     ```bash
     cd projects
     git clone https://github.com/ericsmith66/<project-name>.git <project-name>
     ```
   - Do not use git submodules unless explicitly requested.

---

## 3) Critical communication rule (prevents loops)

Agent sessions may show timeout/keep-alive prompts.

### Interpretation rule
- A bare message like `continue` (or similar) is **keep-alive only**.
- **Do not** re-run tests, re-check status, or repeat updates on bare `continue`.
- When task is complete and no further action needed:
  - Post **exactly once**:
    ```
    STATUS: DONE — awaiting review (no commit yet)
    ```
  - Then stop / quit the task.

---

## 4) Safety rails (protect the project)

### Database safety (high priority)
- **Never** run destructive DB commands without explicit human confirmation:
  - `db:drop`, `db:reset`, `db:truncate`, `db:migrate:reset`, etc.
- Prefer test environment scoping:
  - `RAILS_ENV=test bin/rails db:migrate`
  - `RAILS_ENV=test bin/rails test`
- If a command could affect development DB, **ask first**.

### Git & repo safety
- **Do not** `git commit`, `git push`, or generate commits/PRs unless explicitly instructed.
- Avoid unrelated diffs (whitespace, formatting only).
- When proposing code changes:
  - Output full file paths + diffs
  - Use clear commit message suggestions
  - Wait for human approval before any git action.

### LLM & agent safety
- Never fabricate API keys, tokens, or credentials.
- When switching LLMs (Claude → Deepseek → Grok), log the switch and reason.
- Do not run infinite agent loops without human oversight.

---

## 5) Implementation conventions

### Agent & orchestration patterns
- Prefer explicit agent roles (Coder, Planner, Reviewer, Orchestrator).
- Use `lib/agents/` or `app/services/agents/` for core logic.
- Implement LLM dispatcher early (support Claude, Deepseek, Grok/xAI API, Ollama/local).
- Use file-based memory first → later vector DB/Rails model for long-term recall.

### Components & UI
- Prefer ViewComponents for agent dashboards, task views, logs.
- Mirror patterns in `app/components/` once established.
- Defensive data handling: tolerate missing keys, empty states, log errors (`Rails.logger`).

### Styling
- DaisyUI + Tailwind utility classes.
- Mobile-first responsive design.

### Accessibility
- Meaningful headings, labels, `aria-*` attributes.
- Non-visual fallbacks for data-heavy views (tables alongside charts).

---

## 6) Testing expectations

### Default test stack
- **Minitest** only (no RSpec unless requested).

### What to add
- New services/agents → unit tests (`test/services/`, `test/lib/`)
- New ViewComponents → `test/components/...`
- Integration/wiring → `test/integration/...`
- End-to-end agent flows → system/smoke tests `test/system/`

### How to run
- Smallest relevant set first:
  - `bin/rails test test/lib/agents/...`
  - `bin/rails test test/components/...`
  - Full suite only when needed: `bin/rails test`

Log test results in status trackers or task output.

---

## 7) Documentation & knowledge base workflow

### Always reference knowledge_base first
- Read `knowledge_base/ai-instructions/agent-guidelines.md` (this file) on every major task.
- Then `knowledge_base/ai-instructions/task-log-requirement.md` for logging rules.
- Then relevant Epic/PRD + `*-IMPLEMENTATION-STATUS.md`.

### Use templates
- Create new Epics/PRDs from `knowledge_base/templates/`
  - Epic overview: `0000-EPIC-OVERVIEW-template.md`
  - Status tracker: `0001-IMPLEMENTATION-STATUS-template.md`
  - PRD: `PRD-template.md`

### Self-improvement rule
- When improving agents, tools, or architecture:
  - Also propose updates to this file, `ai-instructions/`, or templates.
  - Use the Epic/PRD → implementation → review loop.

---

Last updated: 2026-03-05
Project: Legion — CLI-first AI agent orchestration engine
