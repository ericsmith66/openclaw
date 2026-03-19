#### PRD-0-03: Asset Cherry-Pick

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Bring the valuable code assets from agent-forge into Legion. The crown jewel is the `agent_desk` gem (5,192 LOC, 50 lib files, 64 test files) including its `bin/` scripts (interactive CLI, smoke test, model compatibility test). Additionally, copy the Workspace layout component and shared UI components for future Epic 4 use.

---

### Requirements

#### Functional

**Gem copy:**
- Copy `agent-forge/gems/agent_desk/` → `legion/gems/agent_desk/`
- Add to Gemfile: `gem "agent_desk", path: "gems/agent_desk"`
- Verify `bundle install` resolves the gem
- Verify `require 'agent_desk'` works in Rails console
- Verify `AgentDesk::VERSION` returns a version string

**Gem bin scripts (carry forward):**
- `gems/agent_desk/bin/agent_desk_cli` — interactive REPL for SmartProxy chat + tools
- `gems/agent_desk/bin/smoke_test` — 10-step end-to-end pipeline test
- `gems/agent_desk/bin/model_compatibility_test` — 12-test matrix across SmartProxy models
- Update any hardcoded agent-forge paths in scripts

**Workspace component copy:**
- Copy `agent-forge/app/components/workspace/layout_component.rb` → `legion/app/components/workspace/`
- Copy `agent-forge/app/components/workspace/layout_component.html.erb` → same
- Copy `agent-forge/app/components/workspace/README.md` → same
- Copy `agent-forge/docs/mocks/workspace-mock.html` → `legion/docs/mocks/`
- These won't render yet (Epic 4) but should be loadable

**Shared components:**
- Review `agent-forge/app/components/shared/` for toast, modal, loading components
- Copy any that are self-contained (no agent-forge model dependencies)

**Gem tests:**
- Run `cd gems/agent_desk && bundle install && bundle exec rake test`
- All 64 test files should pass
- Fix any path-related failures (grep for `/agent-forge/` and update)

#### Non-Functional

- No hardcoded agent-forge paths remain in the gem after copy
- Gem dependencies (`faraday ~> 2.0`, `liquid ~> 5.0`) must resolve cleanly
- Gem's MessageBus is in-memory (no PostgreSQL dependency)
- Gem's MemoryStore is file-based JSON (no PostgreSQL dependency)

#### Rails / Implementation Notes

- Gemfile addition: `gem "agent_desk", path: "gems/agent_desk"`
- Gem gemspec declares: `faraday ~> 2.0`, `liquid ~> 5.0` as runtime deps
- Gem gemspec declares: `rake ~> 13.0`, `minitest ~> 5.0`, `simplecov ~> 0.22` as dev deps

---

### Error Scenarios & Fallbacks

- Gem tests fail due to hardcoded paths → Run `grep -r "agent-forge" gems/agent_desk/` to find and fix all occurrences
- `bundle install` fails due to dependency conflicts → Check Gemfile.lock, resolve version pins
- ViewComponent version mismatch → Pin `view_component ~> 3.0` (same as agent-forge)
- Workspace component references agent-forge models → Remove model dependencies, leave as structural template

---

### Architectural Context

The `agent_desk` gem is the core execution engine — 100% of agent dispatch runs through it. It is a pure Ruby gem with only `faraday` and `liquid` as runtime dependencies. It has zero Rails/ActiveRecord dependencies, which is intentional — the gem should work standalone (as the CLI demonstrates).

The Workspace component is copied now but won't be wired into the UI until Epic 4. It's included in this PRD to avoid a second cherry-pick pass later.

---

### Acceptance Criteria

- [ ] AC1: Gemfile references `agent_desk` via `path: "gems/agent_desk"`
- [ ] AC2: `bundle install` succeeds
- [ ] AC3: `rails console` → `AgentDesk::VERSION` returns a string
- [ ] AC4: `rails console` → `AgentDesk::Agent::Runner` is defined
- [ ] AC5: `cd gems/agent_desk && bundle exec rake test` — zero failures, zero errors
- [ ] AC6: `gems/agent_desk/bin/agent_desk_cli` exists and is executable
- [ ] AC7: `gems/agent_desk/bin/smoke_test` exists and is executable
- [ ] AC8: `gems/agent_desk/bin/model_compatibility_test` exists and is executable
- [ ] AC9: Workspace component files exist at `app/components/workspace/`
- [ ] AC10: Workspace mock HTML exists at `docs/mocks/workspace-mock.html`
- [ ] AC11: `grep -r "agent-forge" gems/agent_desk/lib/` returns empty (no hardcoded paths)

---

### Test Cases

#### Unit (Minitest)

- Gem's existing 64 test files: `cd gems/agent_desk && bundle exec rake test`

#### Integration (Minitest)

- `test/integration/agent_desk_gem_test.rb`: Verify `AgentDesk::VERSION` is defined, `AgentDesk::Agent::Runner` is defined, `AgentDesk::MessageBus::CallbackBus` is defined

---

### Manual Verification

1. Run `bundle install` — expected: success
2. Run `rails console` → type `AgentDesk::VERSION` — expected: version string (e.g., "0.1.0")
3. Run `rails console` → type `AgentDesk::Agent::Runner` — expected: class definition, no error
4. Run `cd gems/agent_desk && bundle exec rake test` — expected: 64 files, 0 failures, 0 errors
5. Run `grep -r "agent-forge" gems/agent_desk/lib/` — expected: no results
6. Run `test -x gems/agent_desk/bin/agent_desk_cli && echo OK` — expected: "OK"
7. Run `test -x gems/agent_desk/bin/smoke_test && echo OK` — expected: "OK"
8. Run `ls app/components/workspace/layout_component.rb` — expected: file exists
9. Run `ls docs/mocks/workspace-mock.html` — expected: file exists

**Expected:** All checks pass. Gem is fully integrated and tests green.

---

### Dependencies

- **Blocked By:** PRD-0-02 (Rails Project Bootstrap)
- **Blocks:** PRD-0-04 (Agent Configuration & Gem Integration)

---

### Estimated Complexity

Medium (gem path fixes may require debugging)

### Agent Assignment

Rails Lead
