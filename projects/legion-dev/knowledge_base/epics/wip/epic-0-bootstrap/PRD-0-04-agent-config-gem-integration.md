#### PRD-0-04: Agent Configuration & Gem Integration

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Configure the full ROR agent team (Rails Lead, Architect, QA, Debug) and verify end-to-end gem operation through SmartProxy. This is the capstone PRD — when complete, Legion has a fully operational agent dispatch pipeline verified by automated tests, the interactive CLI, and the smoke test.

---

### Requirements

#### Functional

**Copy `.aider-desk` config:**
- Agent profiles: Copy all 4 `ror-*` directories from `agent-forge/.aider-desk/agents/` → `legion/.aider-desk/agents/`
- Update `projectDir` in each `config.json` to `/Users/ericsmith66/development/legion`
- Update agent IDs from `*-agent-forge` to `*-legion` (e.g., `ror-rails-legion`)
- Copy `order.json` and update agent IDs
- Copy `rules/rails-base-rules.md`
- Copy all 10 skill directories from `skills/`
- Copy relevant commands: `implement-prd.md`, `review-epic.md`, `roll-call.md`, `validate-installation.md`
- Copy `prompts/delegation-rules.md`

**Create Rails initializer:**
- `config/initializers/agent_desk.rb`
- Configure gem with project directory, SmartProxy host/port from ENV (via `dotenv-rails`)
- Verify initializer runs on `rails s` without errors

**Write integration tests:**
- Test: `ProfileManager.new(project_dir).profiles` returns 4 agents
- Test: Each profile has valid `provider`, `model`, `maxIterations`
- Test: `RulesLoader` loads `rails-base-rules.md`
- Test: `SkillLoader` loads all 10 skills
- VCR-recorded integration test: Runner dispatches a simple prompt to SmartProxy and receives a response

**End-to-end verification (manual, requires live SmartProxy):**
- `bin/agent_desk_cli` launches, connects to SmartProxy, completes a chat turn
- `bin/smoke_test` passes all 10 pipeline steps

#### Non-Functional

- All agent profile `projectDir` values must point to Legion (not agent-forge)
- Agent IDs must use `-legion` suffix (not `-agent-forge`)
- SmartProxy is assumed always-on at `localhost:3002` — tests use VCR for offline replay
- `scripts/pre-qa-validate.sh` must pass against the full Legion codebase

#### Rails / Implementation Notes

- Initializer: `config/initializers/agent_desk.rb`
- ENV vars used: `SMART_PROXY_URL`, `SMART_PROXY_HOST`, `SMART_PROXY_PORT`, `SMART_PROXY_TOKEN` (from `.env`)
- VCR cassettes stored in `test/vcr_cassettes/`
- Agent profiles read from `.aider-desk/agents/` by `AgentDesk::Agent::ProfileManager`

---

### Error Scenarios & Fallbacks

- SmartProxy not running during VCR recording → Document that first test run requires live SmartProxy; subsequent runs use recorded cassettes
- Agent profile `projectDir` mismatch → Automated test validates all profiles point to `/Users/ericsmith66/development/legion`
- `bin/agent_desk_cli` fails to connect → Check `.env` has correct `SMART_PROXY_URL` and `SMART_PROXY_TOKEN`; verify SmartProxy is reachable with `curl http://localhost:3002/v1/models`
- Skill directory missing → `SkillLoader` test enumerates expected 10 directories; failure identifies which is missing

---

### Architectural Context

This PRD completes the Epic 0 bootstrap. After this PRD, Legion has:
- A running Rails 8 app
- The `agent_desk` gem integrated with all 4 agent profiles configured
- End-to-end verified pipeline: Profile → PromptsManager → ToolSet → Runner → SmartProxy → LLM response
- The interactive CLI and smoke test as ongoing verification tools

The `.aider-desk/` directory is a project-level config directory that the gem's `ProfileManager` discovers automatically. Global agent profiles at `~/.aider-desk/agents/` are shared and don't need copying.

---

### Acceptance Criteria

- [ ] AC1: `.aider-desk/agents/` contains 4 agent directories + `order.json`
- [ ] AC2: Each agent's `config.json` has `projectDir` set to `/Users/ericsmith66/development/legion`
- [ ] AC3: Each agent's ID uses `-legion` suffix (not `-agent-forge`)
- [ ] AC4: `.aider-desk/rules/` contains `rails-base-rules.md`
- [ ] AC5: `.aider-desk/skills/` contains 10 skill directories
- [ ] AC6: `.aider-desk/commands/` contains at minimum `implement-prd.md` and `review-epic.md`
- [ ] AC7: `.aider-desk/prompts/` contains `delegation-rules.md`
- [ ] AC8: `config/initializers/agent_desk.rb` exists and loads without error on `rails s`
- [ ] AC9: Integration test: `ProfileManager` loads 4 agents — PASSES
- [ ] AC10: Integration test: Runner executes via SmartProxy — PASSES (VCR-recorded)
- [ ] AC11: `bin/agent_desk_cli` launches, connects to SmartProxy, completes a chat turn (manual verification)
- [ ] AC12: `bin/smoke_test` passes all 10 pipeline steps (manual verification — requires live SmartProxy)
- [ ] AC13: `rails test` — zero failures, zero errors, zero skips
- [ ] AC14: `cd gems/agent_desk && bundle exec rake test` — zero failures
- [ ] AC15: `scripts/pre-qa-validate.sh` runs and passes against the Legion codebase

---

### Test Cases

#### Unit (Minitest)

- `test/lib/agent_desk/profile_manager_test.rb`: ProfileManager loads 4 agents, each with valid provider/model/maxIterations
- `test/lib/agent_desk/rules_loader_test.rb`: RulesLoader finds and loads `rails-base-rules.md`
- `test/lib/agent_desk/skill_loader_test.rb`: SkillLoader loads exactly 10 skills

#### Integration (Minitest)

- `test/integration/agent_desk_runner_test.rb`: Runner dispatches prompt to SmartProxy, receives assistant response with non-empty content (VCR-recorded)
- `test/integration/agent_desk_initializer_test.rb`: Rails initializer configures gem without errors

#### Manual / Smoke

- `bin/smoke_test`: 10-step pipeline verification (requires live SmartProxy)
- `bin/agent_desk_cli`: Interactive chat turn (requires live SmartProxy)

---

### Manual Verification

1. Run `ls .aider-desk/agents/` — expected: 4 directories (`ror-rails-legion/`, `ror-architect-legion/`, `ror-qa-legion/`, `ror-debug-legion/`) + `order.json`
2. Run `cat .aider-desk/agents/ror-rails-legion/config.json | grep projectDir` — expected: `/Users/ericsmith66/development/legion`
3. Run `ls .aider-desk/skills/ | wc -l` — expected: 10
4. Run `ls .aider-desk/rules/` — expected: `rails-base-rules.md`
5. Run `rails s` — expected: starts without initializer errors
6. Run `rails test` — expected: 0 failures, 0 errors, 0 skips
7. Run `cd gems/agent_desk && bundle exec rake test` — expected: 0 failures
8. Run `cd gems/agent_desk && SMART_PROXY_URL=http://localhost:3002 SMART_PROXY_TOKEN=<token> bundle exec ruby bin/smoke_test` — expected: all 10 steps pass
9. Run `cd gems/agent_desk && SMART_PROXY_URL=http://localhost:3002 SMART_PROXY_TOKEN=<token> bundle exec ruby bin/agent_desk_cli` → type "hello" → expected: assistant response
10. Run `bash scripts/pre-qa-validate.sh` — expected: all checks pass

**Expected:** Full pipeline operational. Legion is bootstrapped and ready for Epic 1.

---

### Dependencies

- **Blocked By:** PRD-0-03 (Asset Cherry-Pick)
- **Blocks:** Epic 1 (Data Model & Architecture)

---

### Estimated Complexity

Medium-High (VCR setup for SmartProxy, path updates across configs)

### Agent Assignment

Rails Lead + manual SmartProxy verification
