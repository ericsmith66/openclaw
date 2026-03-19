# PRD-1.5-01 — Test Repo Scaffold & Knowledge Base

**PRD ID:** PRD-1.5-01
**Epic:** Epic 1.5 — LLM Benchmark
**Status:** Draft
**Created:** 2026-03-07
**Depends On:** None
**Blocks:** PRD-1.5-02, PRD-1.5-03

---

## User Story

As a benchmark operator, I want a clean `legion-test` repo with the Epic 4C PRDs and an empty gem skeleton, so that each LLM team starts from the same known-good baseline with no code contamination.

---

## Acceptance Criteria

1. `legion-test` repo exists as a Rails 8 app with PostgreSQL, Propshaft, importmap, Stimulus, Tailwind
2. `gems/agent_desk/` directory exists with a valid empty gem skeleton:
   - `agent_desk.gemspec` (name, version 0.1.0, required_ruby_version >= 3.2)
   - `lib/agent_desk.rb` (empty module)
   - `lib/agent_desk/version.rb`
   - `test/test_helper.rb` (Minitest setup)
   - `Rakefile` (test task)
   - `Gemfile` (source + gemspec)
3. `knowledge_base/epic-4c/` contains the filtered PRD set (see epic 0000 for exact list):
   - `context-summary.md`
   - `4C-Core/0000-epic.md`
   - 9 PRD files (0005, 0010, 0020, 0030, 0090, 0091, 0092a, 0092b, 0095)
   - `recommendations.md`
   - `deferred.md`
   - NO implementation plans, NO supporting reference code, NO status files
4. A `BENCHMARK-NOTES.md` file exists at repo root with:
   - "AiderDesk TypeScript source references in PRDs are informational only. Implement Ruby equivalents based on acceptance criteria."
   - SmartProxy connection info
   - Ollama endpoint info
5. `Gemfile` includes `gem 'agent_desk', path: 'gems/agent_desk'`
6. `bundle install` succeeds
7. `cd gems/agent_desk && bundle exec rake test` runs with 0 tests, 0 failures (empty but functional)
8. Repo is initialized with git, initial commit made

---

## Non-Functional Requirements

- Repo must be at `/Users/ericsmith66/development/legion-test`
- Ruby >= 3.2 (match Legion's requirement)
- No code from agent-forge's `agent_desk` implementation — only PRD text
- Gem skeleton must be structurally identical to what PRD-0010 would produce (so it's a fair starting point, not a head start)

---

## Error Scenarios

| Scenario | Expected Behavior |
|----------|------------------|
| `rails new` fails (wrong Ruby version) | Verify `ruby --version` >= 3.2 first |
| `bundle install` fails (gem dependency issues) | Gem skeleton has zero runtime dependencies initially |
| PRD files have broken internal references | Expected — AiderDesk TS references are intentional noise |

---

## Manual Testing Steps

1. `cd /Users/ericsmith66/development/legion-test`
2. `bundle exec rails --version` → Rails 8.x
3. `ls gems/agent_desk/lib/agent_desk.rb` → exists
4. `ls knowledge_base/epic-4c/4C-Core/PRD-4c-0090-agent-runner-loop-with-streaming.md` → exists
5. `ls knowledge_base/epic-4c/4C-Core/implementation-plan*.md` → no results (excluded)
6. `cd gems/agent_desk && bundle exec rake test` → 0 runs, 0 assertions, 0 failures
7. `cat BENCHMARK-NOTES.md` → contains SmartProxy and AiderDesk reference notes
