# PRD-1-03 Team Import Implementation Plan

## Overview
Implement the team import pipeline to read agent configurations from `.aider-desk` filesystem and persist as database records. Supports dry-run, re-import (upsert), and clear console output.

## File-by-File Changes

### 1. app/services/legion/team_import_service.rb (New)
- Implement `TeamImportService.call(aider_desk_path:, project_path:, team_name:, dry_run: false)`
- Read `order.json` for agent ordering, fallback to alphabetical if missing.
- For each agent: read `config.json`, validate required fields, upsert records.
- Wrap in transaction for all-or-nothing.
- Return result object with counts and errors.
- Dry-run: validate and report without writing.

### 2. lib/tasks/teams.rake (New)
- `rake teams:import[PATH]` with options `--dry-run`, `--team-name=NAME`
- Call TeamImportService, print summary table and counts.
- Exit non-zero on errors.

### 3. test/services/legion/team_import_service_test.rb (New)
- Unit tests for all service logic, error cases, dry-run, re-import.

### 4. test/integration/team_import_integration_test.rb (New)
- Integration tests with fixture directory, verify to_profile works, transaction rollback.

### 5. test/fixtures/aider_desk/ (New)
- Fixture directory with order.json and agent config.json files mirroring real structure.

## Numbered Test Checklist (MUST-IMPLEMENT)

1. AC1: rake teams:import creates Project, AgentTeam, 4 TeamMemberships
2. AC2: Each TeamMembership config JSONB contains full config.json
3. AC3: Positions match order.json ordering
4. AC4: to_profile returns valid Profile
5. AC5: Dry-run reports without writing
6. AC6: Re-import updates changed configs, preserves IDs
7. AC7: Missing order.json falls back to alphabetical with warning
8. AC8: Malformed config.json skipped with error
9. AC9: Missing required fields skipped with error
10. AC10: Console output shows summary table
11. AC11: All writes in transaction
12. AC12: rails test zero failures
13. Unit test: imports from fixture → correct records
14. Unit test: dry-run no records created
15. Unit test: re-import updates, preserves IDs
16. Unit test: missing order.json alphabetical fallback
17. Unit test: missing config.json skipped
18. Unit test: malformed JSON skipped
19. Unit test: missing required fields skipped
20. Unit test: empty agents dir error
21. Unit test: position assignment correct
22. Unit test: project upsert by path
23. Unit test: team upsert by name+project
24. Integration: import from fixture, verify to_profile
25. Integration: re-import stable IDs, updated config
26. Integration: inject DB error → rollback, no partial records

## Error Path Matrix

| Scenario | Input | Handling | Output |
|----------|-------|----------|--------|
| aider_desk_path not exist | invalid path | Raise ArgumentError | "Directory not found: #{path}" |
| agents/ missing | no agents dir | Raise ArgumentError | "No agents directory found at #{path}/agents/" |
| order.json missing | no order.json | Log warning, use alphabetical | Warning logged |
| config.json missing | agent dir without config | Skip agent, add to errors | Error in result.errors |
| config.json malformed | invalid JSON | Skip agent, add parse error | Error with parse message |
| Missing required fields | config without id/name/provider/model | Skip agent, list missing | Error listing missing fields |
| DB constraint violation | duplicate unique key | Transaction rollback | Errors reported, no partial writes |

## Migration Steps
None — schema from PRD-1-01 already exists.

## Pre-QA Checklist Acknowledgment
I acknowledge that the Pre-QA Checklist will be completed and all issues fixed before submitting to QA for scoring.

---

## Architect Review & Amendments
**Reviewer:** Architect Agent
**Date:** 2026-03-07
**Verdict:** APPROVED (with mandatory amendments)

### Summary Assessment
The plan covers the correct surface area and aligns well with PRD-1-03. The test checklist is thorough (26 items), the error path matrix is complete, and the file layout is appropriate. However, there are several critical gaps in the implementation specification that must be addressed before coding begins. Two are BLOCKERs — implementing without these fixes will produce incorrect behavior against real `.aider-desk` data.

### Amendments Made (tracked for retrospective)

#### 1. [BLOCKER — CHANGED] `order.json` format is a Hash map, not an Array

The plan says "Read `order.json` for agent ordering" without specifying the actual data format. The real `order.json` files are **hash maps** of `{ "directory_name": position_integer }`:

```json
// Project-level .aider-desk/agents/order.json
{
  "ror-architect-legion": 0,
  "ror-rails-legion": 1,
  "ror-qa-legion": 2,
  "ror-debug-legion": 3
}

// Global ~/.aider-desk/agents/order.json  
{
  "default": 0,
  "aider": 1,
  "aider-power-tools": 2,
  "ror-architect": 3,
  "ror-debug": 4,
  "72430f6f-36db-4bae-8f62-286d717f930a": 5,
  "ror-qa": 6,
  "ror-rails": 7,
  "b552cf97-8199-4059-ac05-5d655d58153e": 8
}
```

**Required implementation:**
- Parse `order.json` as `Hash<String, Integer>`
- Sort entries by value (ascending) to get ordered directory names
- For each directory name in order: look up `{agents_dir}/{dirname}/config.json`
- Use the **hash value** as the `position` for the `TeamMembership` record
- Directories present on disk but NOT in `order.json` should be appended at the end (position = max_order_value + 1, incrementing), with a warning logged
- `order.json` entries referencing non-existent directories should be silently skipped (they may be UUIDs for deleted agents)

#### 2. [BLOCKER — ADDED] Two `.aider-desk` locations: project-level vs global

The project has **two** `.aider-desk` directories with different agent sets:
- **Project-level:** `{project_root}/.aider-desk/agents/` — 4 agents (ror-architect-legion, ror-rails-legion, ror-qa-legion, ror-debug-legion)
- **Global:** `~/.aider-desk/agents/` — 9 agents including non-ROR agents (aider, power-tools, master-architect, etc.)

The PRD says default path is `~/.aider-desk`, but the **project-level** `.aider-desk` is the correct import source for a project's team. The rake task must:
- Accept an explicit path as first arg (as designed)
- Default to `{project_path}/.aider-desk` if no path given, falling back to `~/.aider-desk` only if the project-level one doesn't exist
- The `project_path` parameter in the service should default to `Rails.root.to_s` in the rake task

#### 3. [CHANGED] Rake task argument syntax — Rake doesn't support `--flags`

The plan specifies `rake teams:import[PATH,--dry-run]` and `--team-name=NAME`. Rake task arguments are **positional**, not flag-style. The implementation must use one of:

**Option A (Recommended): Positional args**
```ruby
task :import, [:path, :team_name, :dry_run] => :environment do |_t, args|
  # rake teams:import[.aider-desk,ROR,true]
end
```

**Option B: Environment variables**
```ruby
task import: :environment do
  # DRY_RUN=1 TEAM_NAME=ROR rake teams:import[.aider-desk]
end
```

**Recommended: Use Option A for `path`, Option B (ENV) for `dry_run` and `team_name`.** This gives:
```
rake teams:import                          # project .aider-desk, default team name
rake teams:import[~/.aider-desk]           # explicit path
DRY_RUN=1 rake teams:import               # dry run
TEAM_NAME=ROR rake teams:import            # custom team name
```

This is idiomatic Rails and avoids comma-parsing issues in rake args.

#### 4. [ADDED] Result object must be a defined Struct/PORO

The plan says "Return result object with counts and errors" but doesn't specify the class. Define:

```ruby
module Legion
  class TeamImportService
    Result = Struct.new(:project, :team, :memberships, :created, :updated, :skipped, :unchanged, :errors, keyword_init: true)
    # ...
  end
end
```

Note the addition of `:unchanged` — PRD AC6 requires distinguishing "updated" from "unchanged" on re-import.

#### 5. [ADDED] "Unchanged" detection for re-import (AC6)

The PRD requires reporting "unchanged" vs "updated" per agent. The plan mentions re-import but doesn't specify detection logic. Implementation must:
- On upsert, compare the existing `config` JSONB with the incoming parsed JSON
- If the hash is identical (`==` comparison on the Ruby Hash), mark as "unchanged"
- If different, update and mark as "updated"
- The console output must show per-agent status: "created", "updated", or "unchanged"

#### 6. [ADDED] Test fixture directory structure specification

The plan mentions `test/fixtures/aider_desk/` but doesn't describe contents. Create:

```
test/fixtures/aider_desk/
├── valid_team/
│   └── agents/
│       ├── order.json                    # {"agent-a": 0, "agent-b": 1, "agent-c": 2}
│       ├── agent-a/config.json           # valid config
│       ├── agent-b/config.json           # valid config
│       └── agent-c/config.json           # valid config
├── no_order/
│   └── agents/
│       ├── beta/config.json              # alphabetical: beta first
│       └── alpha/config.json             # alphabetical: alpha second → but sorted = alpha, beta
├── malformed/
│   └── agents/
│       ├── order.json
│       ├── good-agent/config.json        # valid
│       └── bad-agent/config.json         # invalid JSON: "{ not json"
├── missing_fields/
│   └── agents/
│       ├── order.json
│       └── incomplete/config.json        # missing "provider" and "model"
├── missing_config/
│   └── agents/
│       ├── order.json
│       └── no-config/                    # directory with NO config.json
└── empty_agents/
    └── agents/                           # empty directory
```

Each config.json must include the 4 required keys (id, name, provider, model) plus at least one optional field to verify full JSONB storage.

#### 7. [ADDED] `project_path` and `team_name` derivation in rake task

The plan doesn't specify how `project_path` and `team_name` are derived when not explicit:
- `project_path`: Default to `Rails.root.to_s` — this is the current project
- `team_name`: Default to `"Default"`. The PRD says "derived from directory name or Default". To derive from directory: use `File.basename(project_path)` only if it looks like a project name, otherwise "Default". **Simpler: default to "Default" and let the user override via ENV.** The PRD is ambiguous here — "Default" is safe.

#### 8. [ADDED] Logger integration for warnings

The plan's Error Path Matrix says "Warning logged" for missing `order.json` but doesn't specify which logger. Use `Rails.logger.warn` for all service-level warnings. For console output in the rake task, use `$stdout.puts`. These are separate concerns:
- Service: uses `Rails.logger` for warnings/errors, returns `Result` object
- Rake task: reads `Result`, formats console output to `$stdout`

This separation allows the service to be called from non-rake contexts (e.g., future UI) without console noise.

#### 9. [ADDED] Transaction boundary clarification

The plan says "Wrap in transaction for all-or-nothing" but the PRD also says "Skip agent, add to errors, continue with others" for malformed configs. These seem contradictory. Clarification:
- **Validation phase** (outside transaction): Read all config.json files, validate, collect valid configs and errors
- **Persistence phase** (inside transaction): Create/update all valid agents atomically
- If the **persistence** phase fails (DB error), roll back everything
- If individual configs are **invalid**, they're skipped during validation — the transaction only covers valid ones
- This means: malformed configs → skipped (errors reported) + valid configs → all-or-nothing transaction

#### 10. [ADDED] Missing error path: `order.json` itself is malformed JSON

The Error Path Matrix covers missing `order.json` but not **malformed** `order.json` (valid file but invalid JSON). Add:

| Scenario | Input | Handling | Output |
|----------|-------|----------|--------|
| order.json malformed | invalid JSON in order.json | Log warning, fall back to alphabetical | Warning with parse error |

#### 11. [ADDED] Missing test: "unchanged" re-import status

Add to test checklist:
- **Test #27 (MUST-IMPLEMENT):** Unit test: re-import with identical config reports "unchanged" count and per-agent "unchanged" status
- **Test #28 (MUST-IMPLEMENT):** Unit test: order.json with entries for non-existent directories silently skips them
- **Test #29 (MUST-IMPLEMENT):** Unit test: agent directories on disk but not in order.json are appended with warning

#### 12. [CHANGED] Error Path Matrix — add malformed order.json row

Updated Error Path Matrix (add this row):

| Scenario | Input | Handling | Output |
|----------|-------|----------|--------|
| order.json malformed | invalid JSON in order.json | Log warning, fall back to alphabetical | Warning with parse error message |

### Updated Test Count
Original: 26 tests (22 unit + 3 integration + AC checks)
Added: 3 tests (#27, #28, #29)
**Final: 29 tests minimum**

### Items NOT Requiring Revision (plan got these right)
- Service namespace `Legion::TeamImportService` — correct
- File locations (service, rake, tests) — correct
- Error Path Matrix structure — solid (with the one addition above)
- Test coverage for core scenarios — comprehensive
- No migration needed — correct, PRD-1-01 schema suffices
- Pre-QA Checklist acknowledged — present

### Architecture Notes for Implementer
1. The service should be callable independently of the rake task (dependency injection friendly)
2. Do NOT use `AgentDesk::Agent::ProfileManager` to read configs — read `config.json` directly with `JSON.parse(File.read(...))` as the PRD recommends. ProfileManager normalizes keys which loses data.
3. The `config` JSONB should store the **raw** parsed JSON hash — no key transformations, no cherry-picking fields
4. The `position` value from `order.json` maps directly to `TeamMembership#position`
5. Use `find_or_initialize_by` pattern for upserts rather than `find_or_create_by` to allow detecting created vs updated

PLAN-APPROVED