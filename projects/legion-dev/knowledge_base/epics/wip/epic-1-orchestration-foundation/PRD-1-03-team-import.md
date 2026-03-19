#### PRD-1-03: Team Import

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-03-team-import-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Build the import pipeline that reads agent configurations from the `.aider-desk` filesystem structure and persists them as database records (Project, AgentTeam, TeamMembership). This bridges the existing agent-forge/AiderDesk configuration format with Legion's database-backed orchestration layer.

The import is the entry point for getting agents into the system. Without it, there are no TeamMemberships to dispatch, no configs to assemble into Profiles, and no way to run agents through the CLI. It must support dry-run (preview without writing), re-import (upsert — update existing records), and produce clear output showing what was imported.

---

### Requirements

#### Functional

**Import Service (`app/services/legion/team_import_service.rb`):**
- `TeamImportService.call(aider_desk_path:, project_path:, team_name:, dry_run: false)`
- Reads `order.json` from `{aider_desk_path}/agents/` to determine agent ordering
- For each agent directory listed in `order.json`:
  - Reads `config.json`
  - Extracts full agent config (provider, model, maxIterations, use_* flags, toolApprovals, toolSettings, customInstructions, subagent config)
  - Validates required fields (id, name, provider, model)
- Creates or finds Project record (upsert by path)
- Creates or finds AgentTeam record (upsert by name + project)
- Creates or updates TeamMembership records (upsert by config `id` within team):
  - Match existing membership by `config->>'id'` within the team
  - Update config JSONB if membership exists (preserving any Legion-specific additions)
  - Create new membership if not found
  - Set position from `order.json` ordering
- Returns a result object with: `{ project:, team:, memberships: [], created: N, updated: N, skipped: N, errors: [] }`

**Dry-run mode:**
- Reads all configs, validates, reports what would happen
- Does NOT write to database
- Prints: "Would create/update N memberships for team X"

**Rake task (`lib/tasks/teams.rake`):**
- `rake teams:import[PATH]` — imports from given path (default `~/.aider-desk`)
- `rake teams:import[PATH,--dry-run]` — dry-run mode
- `rake teams:import[PATH,--team-name=ROR]` — custom team name (default: derived from directory name or "Default")
- Prints summary table showing each agent imported with: name, provider, model, position, status (created/updated/unchanged)
- Exits with non-zero status on errors

**Console output format:**
```
Importing agents from /Users/ericsmith66/.aider-desk
Project: Legion (/Users/ericsmith66/development/legion)
Team: ROR

  #  Agent                     Provider   Model               Status
  1  Rails Lead (Legion)       deepseek   deepseek-reasoner   created
  2  Architect (Legion)        anthropic  claude-opus-4-...   created
  3  QA (Legion)               anthropic  claude-sonnet-4-... created
  4  Debug (Legion)            anthropic  claude-sonnet-4-... created

Imported 4 agents (4 created, 0 updated, 0 errors)
```

**Re-import behavior:**
- Running import again with same source updates configs that changed
- Preserves TeamMembership IDs (important for WorkflowRun FK references)
- Reports "updated" vs "unchanged" per agent

#### Non-Functional

- Import must be idempotent — running twice produces the same result
- Must handle missing `order.json` gracefully (fall back to alphabetical directory listing)
- Must handle malformed `config.json` gracefully (skip agent, report error, continue with others)
- Must not import agents with missing required fields — report as error

#### Rails / Implementation Notes

- Service: `app/services/legion/team_import_service.rb`
- Rake task: `lib/tasks/teams.rake`
- Uses `AgentDesk::Agent::ProfileManager` internally to read configs (leverage existing gem code)
- OR reads config.json directly with `JSON.parse(File.read(...))` — simpler and more predictable
- Recommended: Read directly. ProfileManager normalizes keys which may lose data. We want the raw config.json stored as-is in JSONB.
- Wrap all creates/updates in a transaction — all-or-nothing per import run

---

### Error Scenarios & Fallbacks

- `aider_desk_path` does not exist → Raise with clear message: "Directory not found: #{path}"
- `agents/` subdirectory missing → Raise: "No agents directory found at #{path}/agents/"
- `order.json` missing → Fall back to alphabetical ordering of agent directories. Log warning.
- `config.json` missing in an agent directory → Skip agent, add to errors array, continue with next agent
- `config.json` malformed (not valid JSON) → Skip agent, add to errors array with parse error message
- Config missing required fields (id, name, provider, model) → Skip agent, add to errors array listing missing fields
- Database constraint violation → Transaction rolls back, all changes reverted, errors reported
- Team name collision across projects → Team name is scoped to project, so this is fine

---

### Architectural Context

The Team Import sits at the boundary between the filesystem-based AiderDesk world and Legion's database-backed orchestration. It's a one-way bridge: read from `.aider-desk`, write to PostgreSQL.

```
~/.aider-desk/agents/
  ├── order.json
  ├── ror-rails-legion/config.json    →  TeamMembership (config JSONB)
  ├── ror-architect-legion/config.json →  TeamMembership (config JSONB)
  ├── ror-qa-legion/config.json       →  TeamMembership (config JSONB)
  └── ror-debug-legion/config.json    →  TeamMembership (config JSONB)

  + Project record (Legion)
  + AgentTeam record (ROR)
```

The import stores the **raw** config.json content as JSONB, not a normalized subset. This means:
- `to_profile` handles the mapping to gem Profile objects
- New config fields added to AiderDesk automatically flow through on re-import
- No schema migration needed when agent configs evolve

**Relationship to `bin/legion execute`:** The CLI dispatch (PRD-1-04) looks up TeamMembership by team name + agent name/id, calls `to_profile`, and feeds the Profile into the assembly pipeline. The import must produce TeamMemberships that `to_profile` can handle.

**Non-goals:**
- No export (DB → filesystem)
- No UI for import management
- No automatic sync / file watching

---

### Acceptance Criteria

- [ ] AC1: `rake teams:import[~/.aider-desk]` creates Project, AgentTeam, and 4 TeamMemberships
- [ ] AC2: Each TeamMembership's `config` JSONB contains the full config.json content (provider, model, toolApprovals, customInstructions, etc.)
- [ ] AC3: TeamMembership positions match `order.json` ordering
- [ ] AC4: `to_profile` on each imported membership returns a valid `AgentDesk::Agent::Profile`
- [ ] AC5: Dry-run mode reports what would happen without writing to DB
- [ ] AC6: Re-import (second run) updates changed configs, preserves membership IDs, reports "updated" or "unchanged"
- [ ] AC7: Missing `order.json` falls back to alphabetical ordering with warning
- [ ] AC8: Malformed config.json skipped with error, other agents still imported
- [ ] AC9: Missing required fields (id, name, provider, model) → agent skipped with error
- [ ] AC10: Console output shows summary table with agent names, providers, models, statuses
- [ ] AC11: All database writes wrapped in transaction
- [ ] AC12: `rails test` — zero failures for import tests

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/team_import_service_test.rb`:
  - Imports from fixture directory with 4 agent configs → creates correct records
  - Dry-run mode creates no records, returns correct preview
  - Re-import updates changed config, preserves IDs
  - Re-import with unchanged config reports "unchanged"
  - Missing order.json → alphabetical fallback with warning
  - Missing config.json → agent skipped, others imported, error reported
  - Malformed JSON → agent skipped, error includes parse message
  - Missing required fields → agent skipped, error lists missing fields
  - Empty agents directory → error, no records created
  - Position assignment matches order.json sequence
  - Project upsert by path (finds existing, doesn't duplicate)
  - Team upsert by name+project (finds existing, doesn't duplicate)

#### Integration (Minitest)

- `test/integration/team_import_integration_test.rb`:
  - Import from real `.aider-desk` directory (test fixtures mirroring actual structure)
  - Verify `to_profile` on each imported membership against expected Profile attributes
  - Import → re-import → verify IDs stable, config updated
  - Transaction rollback: inject DB error mid-import → verify no partial records

#### System / Smoke

- N/A for automated system tests. Manual verification with real `.aider-desk` directory below.

---

### Manual Verification

1. Run `rake teams:import[~/.aider-desk]` — expected: summary table showing 4 agents created
2. Run `rails console`:
   - `AgentTeam.find_by(name: "ROR").team_memberships.count` — expected: 4
   - `AgentTeam.find_by(name: "ROR").team_memberships.ordered.map { |m| m.config["name"] }` — expected: ordered agent names
   - `AgentTeam.find_by(name: "ROR").team_memberships.first.to_profile.provider` — expected: agent's provider
3. Run `rake teams:import[~/.aider-desk,--dry-run]` — expected: preview output, no new DB records
4. Run `rake teams:import[~/.aider-desk]` again — expected: "0 created, 0 updated" (idempotent)
5. Modify one agent's config.json, re-run import — expected: "1 updated"

**Expected:** Full ROR team importable from filesystem, round-trippable through `to_profile`, idempotent on re-run.

---

### Dependencies

- **Blocked By:** PRD-1-01 (Schema Foundation — needs Project, AgentTeam, TeamMembership models)
- **Blocks:** PRD-1-04 (CLI Dispatch needs imported team data)

---

### Estimated Complexity

**Low-Medium** — Straightforward file reading and DB writing. Main complexity is upsert logic and error handling for malformed configs.

**Effort:** 0.5 week

### Agent Assignment

**Rails Lead** (DeepSeek Reasoner) — primary implementer
