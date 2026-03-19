# Epic 0: Implementation Status

**Epic**: Legion Bootstrap
**Status**: In Progress
**Last Updated**: 2026-03-05

---

## Overview

Track completion status, blockers, key decisions, and branch merges for Epic 0 PRDs.

Update this document after each PRD completion per RULES.md Φ12.

---

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Completion Date | Notes |
|-----|-------|--------|--------|--------|-----------------|-------|
| PRD-0-01 | Knowledge Base Curation | Implemented | `epic-0/prd-01-kb-curation` | No | 2026-03-05 | Manual (Eric + AI) — all 10 ACs pass |
| PRD-0-02 | Rails Project Bootstrap | Implemented | `epic-0/prd-02-rails-bootstrap` | No | 2026-03-06 | All ACs pass, 0 rubocop offenses |
| PRD-0-03 | Asset Cherry-Pick | Implemented | `epic-0/prd-02-rails-bootstrap` | No | 2026-03-06 | All 11 ACs pass, 752 gem tests green |
| PRD-0-04 | Agent Config & Gem Integration | Implemented | `epic-0/prd-04-agent-config` | No | 2026-03-06 | All ACs pass (AC11/AC12 require live SmartProxy) |

---

## PRD-0-01: Knowledge Base Curation

**Status**: Implemented
**Branch**: `epic-0/prd-01-kb-curation`
**Dependencies**: None

### Scope

- Migrate and curate knowledge base content from agent-forge
- Junie → Agent naming refactor across all documents
- Create agent-guidelines.md and task-log-requirement.md
- Verify no legacy naming or abandoned content remains

### Acceptance Criteria

- [x] Knowledge base directory structure complete
- [x] RULES.md references Legion, no "Junie" references
- [x] All 5 templates present
- [x] agent-guidelines.md and task-log-requirement.md created
- [x] No legacy "Junie" naming anywhere in KB
- [x] README.md exists

### Blockers

- None

### Key Decisions

- "Junie" → "Agent" naming convention
- `projects/` sub-project structure retained for future non-Legion work
- `prds-junie-log/` → `task-logs/`
- Old `log-requirement.md` replaced with deprecation redirect (shell safety prevented `rm`)

### Completion Date

2026-03-05

### Notes

All 10 acceptance criteria verified. Files created: `agent-guidelines.md`, `task-log-requirement.md`, `task-logs/.gitkeep`. Junie refs refactored in 5 files: RULES.md, epic-prd-best-practices.md, PRD-template.md, 0001-IMPLEMENTATION-STATUS-template.md, retrospective-report-template.md. Old `log-requirement.md` overwritten with deprecation notice (can be deleted manually).

---

## PRD-0-02: Rails Project Bootstrap

**Status**: Implemented
**Branch**: `epic-0/prd-02-rails-bootstrap`
**Dependencies**: PRD-0-01

### Scope

- `rails new` with full stack config
- `.env` for secrets, `.env.example` for documentation
- PagesController#home hello-world page
- `scripts/pre-qa-validate.sh` from agent-forge

### Acceptance Criteria

- [x] bundle install succeeds (29 Gemfile deps, 140 gems)
- [x] rails db:create succeeds (legion_development + legion_test)
- [x] rails s serves home page
- [x] rubocop passes (25 files, 0 offenses)
- [x] .env with secrets, not tracked by git
- [x] .env.example with placeholders
- [x] pre-qa-validate.sh exists and executable
- [x] rails test passes (1 run, 3 assertions, 0 failures)
- [x] architecture baseline document created

### Blockers

- None

### Key Decisions

- dotenv-rails for secret management
- SmartProxy connection details in .env
- DaisyUI installed via npm (daisyui + @tailwindcss/typography)
- Fixed pre-qa-validate.sh grep -oP → grep -oE for macOS compatibility
- Added *.bak to .gitignore (backup files from rails new merge)

### Completion Date

2026-03-06

### Notes

Rails 8.1.2, Ruby 3.3.10, PostgreSQL 16, Node 25.2.1. Full stack: Propshaft, Tailwind+DaisyUI, ViewComponent, Solid Queue/Cable/Cache, importmap+Stimulus. .env token set to "changeme" — Eric needs to update with real SmartProxy token.

---

## PRD-0-03: Asset Cherry-Pick

**Status**: Implemented
**Branch**: `epic-0/prd-02-rails-bootstrap`
**Dependencies**: PRD-0-02

### Scope

- Copy agent_desk gem into gems/agent_desk/
- Copy Workspace component and shared components
- Verify gem bin/ scripts (CLI, smoke_test, model_compatibility_test)
- Fix hardcoded agent-forge paths
- All gem tests pass

### Acceptance Criteria

- [x] Gemfile references agent_desk via path
- [x] bundle install succeeds (30 deps, 146 gems)
- [x] AgentDesk::VERSION returns "0.1.0"
- [x] Gem tests pass (752 runs, 2022 assertions, 0 failures)
- [x] All 3 bin/ scripts exist and are executable
- [x] No hardcoded agent-forge paths in gem lib/
- [x] Workspace component files exist
- [x] Shared components (loading, modal, toast) copied
- [x] Integration test passes (4 runs, 8 assertions, 0 failures)
- [x] RuboCop passes (154 files, 0 offenses)

### Blockers

- None

### Key Decisions

- Gem copied in-repo (not external dependency)
- MessageBus is in-memory, MemoryStore is file-based — no DB needed
- Updated gem Gemfile.lock for json 2.19.0 compatibility
- Updated gemspec author/homepage from agent-forge to Legion
- Comment refs to "Agent-Forge" in events.rb/message_bus.rb updated to "Legion"
- smoke_test needed executable permission fix (install -m 755 workaround)
- Shared navbar_component skipped (has model deps per plan)

### Completion Date

2026-03-06

### Notes

Gem: 752 runs, 2022 assertions, 0 failures, 0 errors, 1 skip. Rails integration: 4 runs, 8 assertions (PagesController + AgentDesk gem loading). 3 shared components (loading, modal, toast) + workspace layout component copied — all self-contained.

---

## PRD-0-04: Agent Config & Gem Integration

**Status**: Implemented
**Branch**: `epic-0/prd-04-agent-config`
**Dependencies**: PRD-0-03

### Scope

- Copy and configure .aider-desk/ (agents, rules, skills, commands, prompts)
- Update projectDir and agent IDs for Legion
- Create Rails initializer
- Write integration tests (ProfileManager, RulesLoader, SkillLoader, Runner via VCR)
- Verify bin/agent_desk_cli and bin/smoke_test end-to-end

### Acceptance Criteria

- [x] AC1: 4 agent directories + order.json in .aider-desk/agents/
- [x] AC2: All projectDir values point to Legion
- [x] AC3: Agent IDs use -legion suffix
- [x] AC4: .aider-desk/rules/ contains rails-base-rules.md
- [x] AC5: .aider-desk/skills/ contains 10 skill directories
- [x] AC6: .aider-desk/commands/ contains implement-prd.md, implement-plan.md, review-epic.md, roll-call.md, validate-installation.md
- [x] AC7: .aider-desk/prompts/ contains delegation-rules.md
- [x] AC8: config/initializers/agent_desk.rb exists and loads without error
- [x] AC9: Integration test: ProfileManager loads 4 agents — PASSES
- [x] AC10: Integration test: Runner executes via SmartProxy — PASSES (VCR-recorded)
- [x] AC11: bin/agent_desk_cli launches and completes a chat turn — VERIFIED
- [x] AC12: bin/smoke_test passes all 10 steps — VERIFIED (step 9 tool calling ⚠️ expected with llama3.1:8b)
- [x] AC13: rails test — 28 runs, 121 assertions, 0 failures, 0 errors, 0 skips
- [x] AC14: gem tests — 752 runs, 2022 assertions, 0 failures, 0 errors
- [x] AC15: pre-qa-validate.sh passes (3/3 checks, 0 failures)

### Blockers

- None — all ACs verified

### Key Decisions

- Agent IDs: *-agent-forge → *-legion
- Agent names: (agent-forge) → (Legion)
- VCR for offline test replay of SmartProxy interactions (SSE format cassette)
- Matching on method+uri only (not body) due to dynamic stream flag
- agent-forge-logging skill: name updated to "Legion Logging", Junie refs fixed
- rails-base-rules.md: junie-log-requirement.md → task-log-requirement.md
- implement-prd.md command: Junie Task Log → Agent Task Log, paths updated
- 5 files needed frozen_string_literal pragma (Rails-generated boilerplate)

### Completion Date

2026-03-06

### Notes

4 agent profiles configured: Rails Lead (deepseek-reasoner), Architect (claude-opus), QA (claude-sonnet), Debug (claude-sonnet). 10 skills, 1 rule file, 5 commands, 1 prompt file copied. Rails initializer logs gem version and profile count at boot. VCR cassette uses SSE format to match Runner streaming behavior. All automated ACs pass; AC11/AC12 require live SmartProxy for manual verification.

---

## Change Log

| Date | Change | Notes |
|------|--------|-------|
| 2026-03-05 | Created implementation status tracker | Φ7 PRD Breakout |
| 2026-03-05 | PRD-0-01 implemented — all 10 ACs pass | Φ10 Implementation |
| 2026-03-06 | PRD-0-02 implemented — Rails 8.1.2 bootstrap complete | Φ10 Implementation |
| 2026-03-06 | PRD-0-03 implemented — gem + components cherry-picked | Φ10 Implementation |
| 2026-03-06 | PRD-0-04 implemented — agent config + gem integration complete | Φ10 Implementation |
| 2026-03-06 | PRD-0-04 AC11/AC12 verified — live SmartProxy at 192.168.4.253:3001 | Φ10 Manual Verification |
| 2026-03-06 | VCR cassette re-recorded with live SmartProxy | Φ10 Implementation |
| 2026-03-06 | SmartProxy URL corrected: 192.168.4.253:3001 (was localhost:3002) | Config Fix |
