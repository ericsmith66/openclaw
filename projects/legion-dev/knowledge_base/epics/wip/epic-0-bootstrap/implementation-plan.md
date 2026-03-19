# Epic 0 — Implementation Plan

**Created:** 2026-03-05
**Owner:** Lead Developer (manual execution for PRD-0-01, Rails Lead for PRD-0-02–04)
**Epic:** Legion Bootstrap
**Branch Strategy:** `epic-0/prd-01-kb-curation` (PRD-01), `epic-0/prd-02-rails-bootstrap` (PRD-02 + PRD-03 shared), `epic-0/prd-04-agent-config` (PRD-04)

---

## Execution Order

All PRDs are sequential. Each depends on the previous being complete.

```
PRD-0-01 (KB Curation)        ← Manual, ~1-2 hours
    │
    ▼
PRD-0-02 (Rails Bootstrap)    ← Rails Lead, ~1-2 hours
    │
    ▼
PRD-0-03 (Asset Cherry-Pick)  ← Rails Lead, ~2-3 hours (gem path fixes)
    │
    ▼
PRD-0-04 (Agent Config)       ← Rails Lead + manual SmartProxy, ~2-3 hours
```

**Estimated total:** 6–10 hours across 4 sessions.

---

## PRD-0-01: Knowledge Base Curation

### What Already Exists (Partially Complete)

| Item | Status |
|------|--------|
| `knowledge_base/` directory structure | ✅ Exists |
| `README.md` | ✅ Complete |
| `knowledge_base/overview/project-context.md` | ✅ Complete |
| `knowledge_base/instructions/RULES.md` | ⚠️ Exists but has "Junie" refs |
| 5 templates in `knowledge_base/templates/` | ⚠️ Exist but have "Junie" refs |
| `knowledge_base/smart-proxy.md` | ✅ Complete |
| `knowledge_base/ai-instructions/log-requirement.md` | ⚠️ Exists but has "Junie" refs |
| `knowledge_base/instructions/plan-ownership-and-naming.md` | ✅ Copied (has some Junie refs in examples) |
| `knowledge_base/instructions/epic-prd-best-practices.md` | ✅ Copied (has Junie refs in audit data) |
| `knowledge_base/architecture/storage-persistence-strategy.md` | ✅ Copied |
| `knowledge_base/epics/Ideas/aider-desk-integration-ideas.md` | ✅ Copied |
| `knowledge_base/epics/reference/epic-4c-summary.md` | ✅ Created |
| `knowledge_base/ai-instructions/agent-guidelines.md` | ❌ Not yet created |
| `knowledge_base/ai-instructions/task-log-requirement.md` | ❌ Not yet created |
| `knowledge_base/task-logs/` directory | ❌ Not yet created |

### Step-by-Step Actions

#### Step 1: Create `agent-guidelines.md`
- **Source:** `/Users/ericsmith66/development/agent-forge/.junie/guidelines.md`
- **Destination:** `knowledge_base/ai-instructions/agent-guidelines.md`
- **Adaptations required:**
  - Replace "agent-forge" → "Legion" throughout
  - Replace "Junie" → "Agent" / "Coding Agent" / "Lead Developer" as appropriate
  - Update "Ruby on Rails 7+" → "Ruby on Rails 8.1"
  - Remove server IP/port details (192.168.4.200:3017) — not relevant to Legion
  - Keep `projects/` sub-project structure rules (Section 2) — relevant for future non-Legion work
  - Keep safety rails (Section 4), implementation conventions (Section 5), testing expectations (Section 6)
  - Strip AiderDesk-specific UI debugging (turbo_frame_tag troubleshooting, browser_debug.log, clobber assets) — no UI until Epic 4
  - Update knowledge base paths: `.junie/guidelines.md` → `knowledge_base/ai-instructions/agent-guidelines.md`
  - Update `junie-log-requirement.md` → `task-log-requirement.md`

#### Step 2: Create `task-log-requirement.md`
- **Source:** `knowledge_base/ai-instructions/log-requirement.md` (already in Legion)
- **Action:** Copy to `knowledge_base/ai-instructions/task-log-requirement.md`, then:
  - Replace "Junie" → "Agent" throughout
  - Replace "Junie Task Log" → "Agent Task Log"
  - Replace `knowledge_base/prds-junie-log/` → `knowledge_base/task-logs/`
  - Update Mode from "Brave" to remove Junie-specific mode references
- **Then:** Delete the old `log-requirement.md` (or keep as redirect)

#### Step 3: Create `task-logs/` directory
```bash
mkdir -p knowledge_base/task-logs
touch knowledge_base/task-logs/.gitkeep
```

#### Step 4: Junie → Agent naming refactor in existing files
Run `grep -ri "junie" knowledge_base/ --include='*.md' -l` to identify all files needing updates.

**Files requiring edits (9 files identified):**

| File | What to Change |
|------|----------------|
| `knowledge_base/instructions/RULES.md` | `prds-junie-log/` → `task-logs/`, "Junie Task Log" → "Agent Task Log", `junie-log-requirement.md` → `task-log-requirement.md` |
| `knowledge_base/instructions/epic-prd-best-practices.md` | "junie-feedback" → "agent-feedback" in naming examples, "Junie" → "Agent" in audit references |
| `knowledge_base/ai-instructions/log-requirement.md` | Will be replaced by `task-log-requirement.md` in Step 2 |
| `knowledge_base/templates/PRD-template.md` | "Junie" → "Agent", `prds-junie-log/` → `task-logs/` |
| `knowledge_base/templates/0001-IMPLEMENTATION-STATUS-template.md` | "Junie" → "Agent" if present |
| `knowledge_base/templates/retrospective-report-template.md` | "Junie" → "Agent" if present |
| `knowledge_base/epics/wip/epic-0-bootstrap/0000-epic.md` | Only references Junie in the refactor description — intentional, leave as-is |
| `knowledge_base/epics/wip/epic-0-bootstrap/PRD-0-01-knowledge-base-curation.md` | Only references Junie in the refactor task description — intentional, leave as-is |
| `knowledge_base/epics/wip/epic-0-bootstrap/0001-IMPLEMENTATION-STATUS.md` | "Junie" → "Agent" if present in notes |

#### Step 5: Verify
```bash
# Must return empty (excluding epic docs that describe the refactor itself):
grep -ri "junie" knowledge_base/ --include='*.md' | grep -v "epic-0-bootstrap"
```

### Test Checklist (PRD-0-01)
- [ ] T1: `find knowledge_base/ -type d | sort` — verify complete directory structure
- [ ] T2: `grep -ri "junie" knowledge_base/ --include='*.md' | grep -v "epic-0-bootstrap"` — returns empty
- [ ] T3: `knowledge_base/ai-instructions/agent-guidelines.md` exists with Legion references
- [ ] T4: `knowledge_base/ai-instructions/task-log-requirement.md` exists, references `task-logs/`
- [ ] T5: `knowledge_base/task-logs/.gitkeep` exists
- [ ] T6: All 5 templates present in `knowledge_base/templates/`
- [ ] T7: RULES.md references `task-logs/` (not `prds-junie-log/`)

---

## PRD-0-02: Rails Project Bootstrap

### File-by-File Changes

#### New files (generated by `rails new`):
- Standard Rails 8 directory structure (`app/`, `config/`, `db/`, `test/`, `lib/`, `bin/`, etc.)
- `Gemfile` — with all required gems
- `config/database.yml` — PostgreSQL config

#### Custom files to create:
| File | Purpose |
|------|---------|
| `app/controllers/pages_controller.rb` | `#home` action |
| `app/views/pages/home.html.erb` | "Legion — Agent Orchestration" content |
| `config/routes.rb` | `root "pages#home"` |
| `.env` | Secrets: `SMART_PROXY_URL`, `SMART_PROXY_PORT`, `SMART_PROXY_HOST`, `SMART_PROXY_TOKEN` |
| `.env.example` | Placeholder documentation for all env vars |
| `scripts/pre-qa-validate.sh` | Adapted from agent-forge |
| `test/controllers/pages_controller_test.rb` | GET / returns 200, body contains "Legion" |

### Step-by-Step Actions

#### Step 1: Rails new (inside existing repo)
```bash
cd /Users/ericsmith66/development/legion
rails new . --database=postgresql --css=tailwind --skip-jbuilder \
  --skip-action-mailbox --skip-action-mailer --skip-action-text \
  --force  # force because repo already has files
```
- `--force` will skip conflicting files (README.md, .gitignore) — we'll manually merge

#### Step 2: Merge .gitignore
- Rails will generate a new `.gitignore` — merge with our existing one
- Ensure `.env`, `.env.local`, `.env.*.local` entries remain
- Ensure `.aider-desk/tasks/` and `.aider-desk/tmp/` entries remain
- Add `projects/` if not present (for future sub-project support)

#### Step 3: Gemfile additions
Add to generated Gemfile:
```ruby
gem "view_component", "~> 3.0"
gem "dotenv-rails"
gem "redcarpet", "~> 3.6"

group :development, :test do
  gem "rubocop-rails-omakase"
  gem "bundler-audit"
  gem "brakeman"
end

group :test do
  gem "simplecov", require: false
  gem "webmock"
  gem "vcr"
  gem "capybara"
  gem "selenium-webdriver"
end
```
Note: `solid_cache`, `solid_queue`, `solid_cable` should be included by `rails new` for Rails 8.

#### Step 4: Bundle install
```bash
bundle install
```

#### Step 5: Database config + creation
- Verify `config/database.yml` uses PostgreSQL with `legion_development`, `legion_test`, `legion_production`
```bash
rails db:create
```

#### Step 6: Create `.env` and `.env.example`

`.env` (real secrets — NOT committed):
```
SMART_PROXY_URL=http://localhost:3002
SMART_PROXY_PORT=3002
SMART_PROXY_HOST=localhost
SMART_PROXY_TOKEN=<actual-token-here>
```

`.env.example` (committed):
```
# SmartProxy connection (required for agent dispatch)
SMART_PROXY_URL=http://localhost:3002
SMART_PROXY_PORT=3002
SMART_PROXY_HOST=localhost
SMART_PROXY_TOKEN=<your-smartproxy-token>
```

#### Step 7: Verify .gitignore
```bash
grep "\.env" .gitignore
# Must show: .env, .env.local, .env.*.local
git status .env
# Must show: .env is not tracked
```

#### Step 8: Create PagesController + home page

`app/controllers/pages_controller.rb`:
```ruby
# frozen_string_literal: true

class PagesController < ApplicationController
  def home
  end
end
```

`app/views/pages/home.html.erb`:
```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content text-center">
    <div class="max-w-md">
      <h1 class="text-5xl font-bold">Legion</h1>
      <p class="py-6">AI Agent Orchestration Engine</p>
    </div>
  </div>
</div>
```

`config/routes.rb` — add: `root "pages#home"`

#### Step 9: Copy and adapt `pre-qa-validate.sh`
- **Source:** `/Users/ericsmith66/development/agent-forge/scripts/pre-qa-validate.sh`
- **Destination:** `scripts/pre-qa-validate.sh`
- **Adaptations:** None needed — script already uses relative paths and auto-discovers `app/`, `lib/`, `test/`, `gems/`
```bash
mkdir -p scripts
cp /Users/ericsmith66/development/agent-forge/scripts/pre-qa-validate.sh scripts/
chmod +x scripts/pre-qa-validate.sh
```

#### Step 10: Write controller test

`test/controllers/pages_controller_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get root_url
    assert_response :success
    assert_match "Legion", response.body
  end
end
```

#### Step 11: Run checks
```bash
rails test                    # 0 failures
rubocop                       # 0 offenses
rails s                       # visit localhost:3000, verify "Legion" renders
```

### Test Checklist (PRD-0-02)
- [ ] T1: `bundle install` succeeds
- [ ] T2: `rails db:create` succeeds (dev + test)
- [ ] T3: `rails s` → visit localhost:3000 → "Legion" renders
- [ ] T4: `rubocop` → 0 offenses
- [ ] T5: `.env` exists, not tracked by git
- [ ] T6: `.env.example` exists, committed
- [ ] T7: `test -x scripts/pre-qa-validate.sh` → OK
- [ ] T8: `rails test` → 0 failures, 0 errors

---

## PRD-0-03: Asset Cherry-Pick

### File-by-File Changes

#### Gem copy:
| Source | Destination |
|--------|-------------|
| `agent-forge/gems/agent_desk/` (entire directory) | `legion/gems/agent_desk/` |

#### Workspace component copy:
| Source | Destination |
|--------|-------------|
| `agent-forge/app/components/workspace/layout_component.rb` | `app/components/workspace/layout_component.rb` |
| `agent-forge/app/components/workspace/layout_component.html.erb` | `app/components/workspace/layout_component.html.erb` |
| `agent-forge/app/components/workspace/README.md` | `app/components/workspace/README.md` |
| `agent-forge/docs/mocks/workspace-mock.html` | `docs/mocks/workspace-mock.html` |

#### Shared component copy:
| Source | Destination | Notes |
|--------|-------------|-------|
| `agent-forge/app/components/shared/loading_component.rb` | `app/components/shared/loading_component.rb` | Self-contained |
| `agent-forge/app/components/shared/loading_component.html.erb` | `app/components/shared/loading_component.html.erb` | Self-contained |
| `agent-forge/app/components/shared/modal_component.rb` | `app/components/shared/modal_component.rb` | Self-contained |
| `agent-forge/app/components/shared/modal_component.html.erb` | `app/components/shared/modal_component.html.erb` | Self-contained |
| `agent-forge/app/components/shared/toast_component.rb` | `app/components/shared/toast_component.rb` | Self-contained |
| `agent-forge/app/components/shared/toast_component.html.erb` | `app/components/shared/toast_component.html.erb` | Self-contained |
| `agent-forge/app/components/shared/navbar_component.rb` | **SKIP** | Likely has agent-forge model deps |
| `agent-forge/app/components/shared/navbar_component.html.erb` | **SKIP** | Likely has agent-forge model deps |

### Step-by-Step Actions

#### Step 1: Copy gem
```bash
cp -R /Users/ericsmith66/development/agent-forge/gems/agent_desk gems/
```

#### Step 2: Add to Gemfile
Add to `Gemfile`:
```ruby
gem "agent_desk", path: "gems/agent_desk"
```
```bash
bundle install
```

#### Step 3: Fix hardcoded paths in gem
```bash
grep -r "agent-forge" gems/agent_desk/lib/ --include='*.rb'
```
Known hits (comments only in `message_bus/events.rb` and `message_bus/message_bus.rb`):
- `Agent-Forge` in comments → update to `Legion` for consistency

Also check gemspec:
```bash
grep -i "agent-forge\|agent_forge" gems/agent_desk/agent_desk.gemspec
```
- Update `homepage`, `source_code_uri`, author info to reflect Legion

#### Step 4: Verify gem loads
```bash
rails console
> AgentDesk::VERSION
> AgentDesk::Agent::Runner
> AgentDesk::MessageBus::CallbackBus
```

#### Step 5: Run gem tests
```bash
cd gems/agent_desk && bundle install && bundle exec rake test
# Expected: 66 test files, 0 failures, 0 errors
```

#### Step 6: Verify bin scripts are executable
```bash
test -x gems/agent_desk/bin/agent_desk_cli && echo "CLI OK"
test -x gems/agent_desk/bin/smoke_test && echo "Smoke OK"
test -x gems/agent_desk/bin/model_compatibility_test && echo "Compat OK"
```
If not executable:
```bash
chmod +x gems/agent_desk/bin/agent_desk_cli gems/agent_desk/bin/smoke_test gems/agent_desk/bin/model_compatibility_test
```

#### Step 7: Copy Workspace component
```bash
mkdir -p app/components/workspace
cp /Users/ericsmith66/development/agent-forge/app/components/workspace/layout_component.rb app/components/workspace/
cp /Users/ericsmith66/development/agent-forge/app/components/workspace/layout_component.html.erb app/components/workspace/
cp /Users/ericsmith66/development/agent-forge/app/components/workspace/README.md app/components/workspace/

mkdir -p docs/mocks
cp /Users/ericsmith66/development/agent-forge/docs/mocks/workspace-mock.html docs/mocks/
```

#### Step 8: Copy shared components (self-contained only)
```bash
mkdir -p app/components/shared
for comp in loading modal toast; do
  cp /Users/ericsmith66/development/agent-forge/app/components/shared/${comp}_component.rb app/components/shared/
  cp /Users/ericsmith66/development/agent-forge/app/components/shared/${comp}_component.html.erb app/components/shared/
done
```
Review each for agent-forge model dependencies before committing.

#### Step 9: Write integration test
`test/integration/agent_desk_gem_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

class AgentDeskGemTest < ActionDispatch::IntegrationTest
  test "AgentDesk::VERSION is defined" do
    assert_kind_of String, AgentDesk::VERSION
    refute_empty AgentDesk::VERSION
  end

  test "AgentDesk::Agent::Runner is defined" do
    assert defined?(AgentDesk::Agent::Runner)
  end

  test "AgentDesk::MessageBus::CallbackBus is defined" do
    assert defined?(AgentDesk::MessageBus::CallbackBus)
  end
end
```

#### Step 10: Run full test suite
```bash
rails test                    # Includes new integration test
cd gems/agent_desk && bundle exec rake test   # Gem tests
```

### Test Checklist (PRD-0-03)
- [ ] T1: `bundle install` succeeds with gem path reference
- [ ] T2: `rails console` → `AgentDesk::VERSION` returns string
- [ ] T3: `rails console` → `AgentDesk::Agent::Runner` is defined
- [ ] T4: Gem tests: 0 failures, 0 errors
- [ ] T5: `grep -r "agent-forge" gems/agent_desk/lib/` — no code-path hits (comments updated)
- [ ] T6: All 3 bin scripts exist and are executable
- [ ] T7: Workspace component files exist at `app/components/workspace/`
- [ ] T8: `docs/mocks/workspace-mock.html` exists
- [ ] T9: `rails test` — 0 failures (includes integration test)

---

## PRD-0-04: Agent Configuration & Gem Integration

### File-by-File Changes

#### `.aider-desk/` config files to copy and adapt:

| Source | Destination | Adaptations |
|--------|-------------|-------------|
| `agent-forge/.aider-desk/agents/ror-rails/` | `.aider-desk/agents/ror-rails/` | `id`: `ror-rails-legion`, `name`: `Rails Lead (Legion)`, `projectDir`: Legion path |
| `agent-forge/.aider-desk/agents/ror-architect/` | `.aider-desk/agents/ror-architect/` | `id`: `ror-architect-legion`, `name`: `Architect (Legion)`, `projectDir`: Legion path |
| `agent-forge/.aider-desk/agents/ror-qa/` | `.aider-desk/agents/ror-qa/` | `id`: `ror-qa-legion`, `name`: `QA Agent (Legion)`, `projectDir`: Legion path |
| `agent-forge/.aider-desk/agents/ror-debug/` | `.aider-desk/agents/ror-debug/` | `id`: `ror-debug-legion`, `name`: `Debug Agent (Legion)`, `projectDir`: Legion path |
| `agent-forge/.aider-desk/agents/order.json` | `.aider-desk/agents/order.json` | Update all IDs: `*-agent-forge` → `*-legion` |
| `agent-forge/.aider-desk/rules/rails-base-rules.md` | `.aider-desk/rules/rails-base-rules.md` | Review for agent-forge-specific content |
| `agent-forge/.aider-desk/skills/` (10 dirs) | `.aider-desk/skills/` | Copy all 10 skill directories as-is |
| `agent-forge/.aider-desk/commands/implement-prd.md` | `.aider-desk/commands/implement-prd.md` | Review paths |
| `agent-forge/.aider-desk/commands/implement-plan.md` | `.aider-desk/commands/implement-plan.md` | Review paths |
| `agent-forge/.aider-desk/commands/review-epic.md` | `.aider-desk/commands/review-epic.md` | Review paths |
| `agent-forge/.aider-desk/commands/roll-call.md` | `.aider-desk/commands/roll-call.md` | Minimal changes |
| `agent-forge/.aider-desk/commands/validate-installation.md` | `.aider-desk/commands/validate-installation.md` | Review paths |
| `agent-forge/.aider-desk/prompts/delegation-rules.md` | `.aider-desk/prompts/delegation-rules.md` | Review for agent-forge refs |

#### New Rails files:

| File | Purpose |
|------|---------|
| `config/initializers/agent_desk.rb` | Configure gem with project dir, SmartProxy from ENV |
| `test/lib/agent_desk/profile_manager_test.rb` | ProfileManager loads 4 agents |
| `test/lib/agent_desk/rules_loader_test.rb` | RulesLoader finds rules |
| `test/lib/agent_desk/skill_loader_test.rb` | SkillLoader loads 10 skills |
| `test/integration/agent_desk_runner_test.rb` | Runner dispatches via SmartProxy (VCR) |
| `test/vcr_cassettes/` | VCR cassette directory |

### Step-by-Step Actions

#### Step 1: Copy agent profiles
```bash
for agent in ror-rails ror-architect ror-qa ror-debug; do
  cp -R /Users/ericsmith66/development/agent-forge/.aider-desk/agents/$agent .aider-desk/agents/
done
cp /Users/ericsmith66/development/agent-forge/.aider-desk/agents/order.json .aider-desk/agents/
```

#### Step 2: Update agent configs
For each agent's `config.json`:
- `"id"`: `"ror-{role}-agent-forge"` → `"ror-{role}-legion"`
- `"name"`: `"{Role} (agent-forge)"` → `"{Role} (Legion)"`
- `"projectDir"`: `"/Users/ericsmith66/development/agent-forge"` → `"/Users/ericsmith66/development/legion"`

Update `order.json`:
```json
{
  "ror-architect-legion": 0,
  "ror-rails-legion": 1,
  "ror-qa-legion": 2,
  "ror-debug-legion": 3
}
```

#### Step 3: Copy rules, skills, commands, prompts
```bash
cp /Users/ericsmith66/development/agent-forge/.aider-desk/rules/rails-base-rules.md .aider-desk/rules/

cp -R /Users/ericsmith66/development/agent-forge/.aider-desk/skills/* .aider-desk/skills/

for cmd in implement-prd implement-plan review-epic roll-call validate-installation; do
  cp /Users/ericsmith66/development/agent-forge/.aider-desk/commands/$cmd.md .aider-desk/commands/
done

cp /Users/ericsmith66/development/agent-forge/.aider-desk/prompts/delegation-rules.md .aider-desk/prompts/
```

#### Step 4: Create Rails initializer

`config/initializers/agent_desk.rb`:
```ruby
# frozen_string_literal: true

# Configure the agent_desk gem for Legion
Rails.application.config.after_initialize do
  AgentDesk.configure do |config|
    config.project_dir = Rails.root.to_s
    config.smart_proxy_url = ENV.fetch("SMART_PROXY_URL", "http://localhost:3002")
    config.smart_proxy_token = ENV.fetch("SMART_PROXY_TOKEN", nil)
  end
end if defined?(AgentDesk) && AgentDesk.respond_to?(:configure)
```
Note: The gem may not have a `configure` block yet. If not, create a simple initializer that just verifies the gem loads:
```ruby
# frozen_string_literal: true

# Verify agent_desk gem loads on Rails startup
Rails.logger.info "AgentDesk v#{AgentDesk::VERSION} loaded" if defined?(AgentDesk::VERSION)
```

#### Step 5: Configure VCR

`test/support/vcr_setup.rb`:
```ruby
# frozen_string_literal: true

require "vcr"
require "webmock/minitest"

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<SMART_PROXY_TOKEN>") { ENV.fetch("SMART_PROXY_TOKEN", "test-token") }
  config.default_cassette_options = { record: :once }
end
```

Ensure `test/test_helper.rb` requires this:
```ruby
require "support/vcr_setup"
```

#### Step 6: Write integration tests

`test/lib/agent_desk/profile_manager_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

class ProfileManagerTest < ActiveSupport::TestCase
  test "loads 4 ROR agent profiles" do
    manager = AgentDesk::Agent::ProfileManager.new(Rails.root.to_s)
    profiles = manager.profiles
    assert_equal 4, profiles.size
  end

  test "each profile has valid provider and model" do
    manager = AgentDesk::Agent::ProfileManager.new(Rails.root.to_s)
    manager.profiles.each do |profile|
      refute_nil profile.provider, "#{profile.name} missing provider"
      refute_nil profile.model, "#{profile.name} missing model"
    end
  end

  test "all profile IDs use -legion suffix" do
    manager = AgentDesk::Agent::ProfileManager.new(Rails.root.to_s)
    manager.profiles.each do |profile|
      assert_match(/-legion$/, profile.id, "#{profile.id} should end with -legion")
    end
  end

  test "all profiles point to Legion project dir" do
    manager = AgentDesk::Agent::ProfileManager.new(Rails.root.to_s)
    manager.profiles.each do |profile|
      assert_includes profile.project_dir.to_s, "legion",
        "#{profile.name} projectDir should reference legion"
    end
  end
end
```

`test/integration/agent_desk_runner_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

class AgentDeskRunnerTest < ActionDispatch::IntegrationTest
  test "Runner dispatches prompt to SmartProxy and gets response" do
    VCR.use_cassette("smartproxy_simple_prompt") do
      model_manager = AgentDesk::Models::ModelManager.new(
        provider: :smart_proxy,
        api_key: ENV.fetch("SMART_PROXY_TOKEN", "test-token"),
        base_url: ENV.fetch("SMART_PROXY_URL", "http://localhost:3002"),
        model: "llama3.1:8b",
        timeout: 60
      )

      bus = AgentDesk::MessageBus::CallbackBus.new
      hook_manager = AgentDesk::Hooks::HookManager.new
      runner = AgentDesk::Agent::Runner.new(
        model_manager: model_manager,
        message_bus: bus,
        hook_manager: hook_manager
      )

      conversation = runner.run(
        prompt: "Reply with exactly: PONG",
        project_dir: Rails.root.to_s,
        system_prompt: "You are a test agent. Follow instructions exactly."
      )

      last = conversation.last
      assert_equal "assistant", last[:role]
      refute_empty last[:content].to_s.strip
    end
  end
end
```

#### Step 7: Record VCR cassettes (requires live SmartProxy)
```bash
# First run with live SmartProxy to record cassettes:
SMART_PROXY_URL=http://localhost:3002 SMART_PROXY_TOKEN=<token> rails test test/integration/agent_desk_runner_test.rb
```

#### Step 8: Manual end-to-end verification
```bash
# CLI test:
cd gems/agent_desk
SMART_PROXY_URL=http://localhost:3002 SMART_PROXY_TOKEN=<token> bundle exec ruby bin/agent_desk_cli
# Type "hello", verify response, type /quit

# Smoke test:
SMART_PROXY_URL=http://localhost:3002 SMART_PROXY_TOKEN=<token> bundle exec ruby bin/smoke_test
# All 10 steps should pass
```

#### Step 9: Run full validation
```bash
rails test                                              # 0 failures
cd gems/agent_desk && bundle exec rake test             # 0 failures
cd /Users/ericsmith66/development/legion
bash scripts/pre-qa-validate.sh                         # All checks pass
```

### Test Checklist (PRD-0-04)
- [ ] T1: `.aider-desk/agents/` has 4 dirs + `order.json`
- [ ] T2: Each config.json `projectDir` → `/Users/ericsmith66/development/legion`
- [ ] T3: Each config.json `id` ends with `-legion`
- [ ] T4: `.aider-desk/skills/` has 10 directories
- [ ] T5: `.aider-desk/rules/rails-base-rules.md` exists
- [ ] T6: `.aider-desk/commands/` has implement-prd, review-epic + others
- [ ] T7: `.aider-desk/prompts/delegation-rules.md` exists
- [ ] T8: `config/initializers/agent_desk.rb` exists, `rails s` starts clean
- [ ] T9: ProfileManager test passes (4 agents, valid config, -legion IDs)
- [ ] T10: Runner integration test passes (VCR)
- [ ] T11: `bin/agent_desk_cli` manual test — chat turn works
- [ ] T12: `bin/smoke_test` manual test — all 10 steps pass
- [ ] T13: `rails test` — 0 failures, 0 errors, 0 skips
- [ ] T14: Gem tests — 0 failures
- [ ] T15: `scripts/pre-qa-validate.sh` — passes

---

## Risk Mitigation Plan

| Risk | Likelihood | Detection | Mitigation |
|------|-----------|-----------|------------|
| R1: `rails new .` overwrites existing files | Medium | Files changed after rails new | Use `--force` carefully; review git diff before committing; restore README.md and .gitignore from git if overwritten |
| R2: Gem tests fail from hardcoded paths | Medium | `grep -r "agent-forge" gems/` | Only 2 comment-level hits found — update comments |
| R3: SmartProxy down during VCR recording | Low | Connection refused | SmartProxy is 24/7 infrastructure; retry later if down |
| R4: ViewComponent version conflict | Low | `bundle install` failure | Pin `~> 3.0` to match agent-forge |
| R5: Tailwind/DaisyUI setup issues | Low | CSS not rendering | Run `rails assets:precompile` to verify; check Node.js |
| R6: Shared components have model deps | Medium | LoadError on `rails test` | Review each before copying; skip navbar_component |
| R7: Agent profile config.json schema mismatch | Low | ProfileManager test fails | Compare against gem's `Profile.new` expected fields |

---

## Acceptance Criteria Cross-Reference

| SC | Description | Verified By |
|----|-------------|-------------|
| SC1 | `rails s` serves hello-world | PRD-02 T3 |
| SC2 | `rails test` passes | PRD-04 T13 |
| SC3 | Gem tests pass | PRD-04 T14 |
| SC4 | ProfileManager loads 4 agents | PRD-04 T9 |
| SC5 | Runner dispatches to SmartProxy | PRD-04 T10 |
| SC6 | Knowledge base organized | PRD-01 T1–T7 |
| SC7 | `.aider-desk/` config complete | PRD-04 T1–T7 |
| SC8 | `bin/agent_desk_cli` works | PRD-04 T11 |
| SC9 | `bin/smoke_test` passes | PRD-04 T12 |
| SC10 | `.env` with secrets, in .gitignore | PRD-02 T5, T6 |
| SC11 | `pre-qa-validate.sh` passes | PRD-04 T15 |

---

*Ready for Φ9 (Architect Plan Review) — or proceed directly to Φ10 (Implementation) given bootstrap exception.*
