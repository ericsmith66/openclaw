#### PRD-0-02: Rails Project Bootstrap

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Stand up a running Rails 8 application with the complete technology stack configured. This includes PostgreSQL, Propshaft, Tailwind CSS + DaisyUI, ViewComponent, Solid Queue/Cable/Cache, importmap, dotenv, and Minitest. The app serves a hello-world page, secrets are managed via `.env`, and the `pre-qa-validate.sh` script is available for quality checks.

---

### Requirements

#### Functional

- Run `rails new legion --database=postgresql --css=tailwind --skip-jbuilder --skip-action-mailbox --skip-action-mailer --skip-action-text` (from within the repo)
- Configure Gemfile with: `view_component ~> 3.0`, `solid_cache`, `solid_queue`, `solid_cable`, `dotenv-rails`, `simplecov` (test), `webmock`, `vcr`, `capybara`, `selenium-webdriver` (test), `rubocop-rails-omakase` (dev+test), `bundler-audit`, `brakeman` (dev+test), `redcarpet ~> 3.6`
- Configure `database.yml` for PostgreSQL (dev, test, production)
- Create `.env` with secrets: `SMART_PROXY_URL`, `SMART_PROXY_PORT`, `SMART_PROXY_HOST`, `SMART_PROXY_TOKEN`
- Create `.env.example` with placeholder values (no real secrets)
- Verify `.gitignore` includes `.env`, `.env.local`, `.env.*.local`
- Create `PagesController#home` with "Legion — Agent Orchestration" content
- Set `root "pages#home"` in routes
- Copy `scripts/pre-qa-validate.sh` from agent-forge — adapt paths for Legion
- add an architecture document knowledge_base/architecture on the baseline tools used in the project

#### Non-Functional

- `rubocop` passes with zero offenses
- `rails test` passes (even if only default test file)
- `.env` must NOT be tracked by git
- `pre-qa-validate.sh` must be executable (`chmod +x`)

#### Rails / Implementation Notes

- Routes: `root "pages#home"`
- Controllers: `PagesController#home`
- Views: `app/views/pages/home.html.erb`
- No models or migrations needed (beyond what `rails new` generates for Solid Queue/Cable/Cache)

---

### Error Scenarios & Fallbacks

- PostgreSQL not running → `rails db:create` fails with clear error; document prerequisite
- Tailwind build fails → Run `rails assets:precompile` to verify; check Node.js availability
- `.env` accidentally committed → `.gitignore` already covers it; verify with `git status`

---

### Architectural Context

This PRD establishes the Rails foundation that all subsequent PRDs build on. The technology choices (Propshaft, Tailwind, DaisyUI, ViewComponent, Solid Queue/Cable/Cache, importmap) are locked in per project-context.md and cannot be changed without revisiting the architecture.

The `.env` approach uses `dotenv-rails` to load environment variables. SmartProxy connection details live here because the gem's `bin/` scripts and the Rails initializer (PRD-0-04) both read from ENV.

---

### Acceptance Criteria

- [ ] AC1: `bundle install` succeeds with all gems resolved
- [ ] AC2: `rails db:create` succeeds for development and test databases
- [ ] AC3: `rails s` starts Puma and serves the home page at `localhost:3000`
- [ ] AC4: Home page renders "Legion" text (verifiable via system test or manual check)
- [ ] AC5: `rubocop` passes with zero offenses
- [ ] AC6: `.env` exists with secrets (SmartProxy URL, token, etc.) and is NOT tracked by git
- [ ] AC7: `.env.example` exists with documented placeholder variables (no real secrets)
- [ ] AC8: `.gitignore` contains `.env` entries (verified via `grep "\.env" .gitignore`)
- [ ] AC9: `scripts/pre-qa-validate.sh` exists and is executable (`test -x scripts/pre-qa-validate.sh`)
- [ ] AC10: `rails test` passes (even if only the default test file)
- [ ] AC10: `architecture` add architecture document knowledge_base/architecture on the baseline tools used in the project
---

### Test Cases

#### Unit (Minitest)

- `test/controllers/pages_controller_test.rb`: GET / returns 200, response body contains "Legion"

#### System / Smoke (Capybara)

- `test/system/home_page_test.rb`: Visit root, assert "Legion" text visible

---

### Manual Verification

1. Run `bundle install` — expected: success, all gems resolved
2. Run `rails db:create` — expected: `legion_development` and `legion_test` databases created
3. Run `rails s` — expected: Puma starts on port 3000
4. Visit `http://localhost:3000` in browser — expected: page renders with "Legion" text
5. Run `rubocop` — expected: zero offenses
6. Run `cat .env` — expected: contains `SMART_PROXY_URL`, `SMART_PROXY_TOKEN` (real values)
7. Run `cat .env.example` — expected: contains placeholder values like `<your-token-here>`
8. Run `git status .env` — expected: `.env` is not tracked
9. Run `bash scripts/pre-qa-validate.sh` — expected: script runs (may warn about missing test files, but executes)
10. Run `rails test` — expected: 0 failures, 0 errors

**Expected:** All steps pass. Rails app is fully operational.

---

### Dependencies

- **Blocked By:** PRD-0-01 (Knowledge Base Curation)
- **Blocks:** PRD-0-03 (Asset Cherry-Pick)

---

### Estimated Complexity

Low

### Agent Assignment

Rails Lead (or manual)
