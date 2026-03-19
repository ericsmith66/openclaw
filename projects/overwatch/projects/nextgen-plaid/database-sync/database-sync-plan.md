# Database Sync Script Plan
**Version:** 2.0  
**Last Updated:** February 16, 2026  
**Target:** NextGen Plaid Database Synchronization  
**Revision Note:** v2.0 — corrected database names, user, and addressed all data-loss risks identified in safety review.

## Overview

Create a Ruby script to sync **development databases** from the remote server (192.168.4.253) to the local development environment for NextGen Plaid. The remote server runs a **development Rails environment** (not production). There are no production databases on the remote server. The script must guarantee **zero data loss** by enforcing verified backups before any destructive operation.

## Requirements Analysis

### Verified Remote Environment (from inspection 2026-02-16)
- **Server:** 192.168.4.253 (M3 Ultra, macOS, 256 GB RAM)
- **Rails Environment:** Development (`RAILS_ENV=development`)
- **Git Branch:** `main` @ `fbc0064` (Merge pull request #102)
- **PostgreSQL:** 16.11 (Homebrew), owner `ericsmith66`
- **Schema Version:** `2026_02_04_195500`

### Database Configuration

**Remote Databases (192.168.4.253) — development only:**
- `nextgen_plaid_development` (primary) — owner: `ericsmith66`
- `nextgen_plaid_development_queue` (Solid Queue) — owner: `ericsmith66`
- `nextgen_plaid_development_cable` (Action Cable) — owner: `ericsmith66`

**Local Databases (localhost) — development:**
- `nextgen_plaid_development` (primary) — owner: `ericsmith66`
- `nextgen_plaid_development_queue` (Solid Queue) — owner: `ericsmith66`
- `nextgen_plaid_development_cable` (Action Cable) — owner: `ericsmith66`

> ⚠️ **No production databases exist on the remote server.** Previous references to `nextgen_plaid_production*` databases were incorrect. The remote server uses production Plaid API keys inside a development Rails environment.

### Verified Assumptions
1. ✅ SSH access to 192.168.4.253 via key authentication (user: `ericsmith66`)
2. ✅ PostgreSQL 16.11 running on remote server (Homebrew)
3. ✅ Local PostgreSQL instance with create/drop privileges
4. ✅ Database owner is `ericsmith66` on both servers (not `nextgen_plaid`)
5. ✅ Remote and local schema versions match (`2026_02_04_195500`)
6. ✅ Local database size is ~50 MB (manageable for backup/restore)

## Design Decisions

### 1. Script Language: Ruby
- **Rationale:** Project preference, integrates well with Rails ecosystem
- **Dependencies:** Only Ruby stdlib (`open3`, `fileutils`, `optparse`) — no additional gems required

### 2. Synchronization Approach: SSH Streaming (pipe)
**Selected:** Remote `pg_dump` piped over SSH directly into local `pg_restore`
- Most efficient: no intermediate files on either server
- Reduces disk I/O and time
- Requires careful exit-code handling (see Safety section)

### 3. Safety-First Design
Every destructive operation is gated behind a verified precondition:

| Destructive Action | Required Precondition |
|---|---|
| DROP local database | Backup file exists AND file size > 0 |
| Restore from stream | Local database freshly created AND remote db verified to exist |
| Skip backup (`--no-backup`) | Requires additional `--force` flag |

### 4. Configuration Management
- **Defaults:** Hardcoded to match verified environment (no guessing)
- **Environment variables:** Override any default
- **Command-line flags:** Override everything
- **No interactive prompts:** Script is fully non-interactive for automation

## Script Architecture

### Core Components

#### 1. Configuration Module
```ruby
module DatabaseSync
  class Config
    def initialize
      @remote_host = ENV['REMOTE_HOST'] || '192.168.4.253'
      @remote_user = ENV['REMOTE_USER'] || 'ericsmith66'
      @ssh_port = ENV['SSH_PORT'] || '22'
      # PostgreSQL paths (Homebrew)
      @remote_pg_dump_path = ENV['REMOTE_PG_DUMP_PATH'] || '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump'
      @remote_psql_path = ENV['REMOTE_PSQL_PATH'] || '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql'
      @local_psql_path = ENV['LOCAL_PSQL_PATH'] || '/opt/homebrew/opt/postgresql@16/bin/psql'
      @local_pg_dump_path = ENV['LOCAL_PG_DUMP_PATH'] || '/opt/homebrew/opt/postgresql@16/bin/pg_dump'
      @local_pg_restore_path = ENV['LOCAL_PG_RESTORE_PATH'] || '/opt/homebrew/opt/postgresql@16/bin/pg_restore'
      @backup_dir = ENV['BACKUP_DIR'] || './tmp/db_backups'
      @dry_run = false
      @backup_existing = true
      @force = false
    end
  end
end
```

> **Note:** Database user defaults to `ericsmith66` (the actual owner), not `nextgen_plaid`.

#### 2. Database Registry
```ruby
DATABASES = {
  primary: {
    remote: 'nextgen_plaid_development',
    local: 'nextgen_plaid_development',
    shard: :primary
  },
  queue: {
    remote: 'nextgen_plaid_development_queue',
    local: 'nextgen_plaid_development_queue',
    shard: :solid_queue
  },
  cable: {
    remote: 'nextgen_plaid_development_cable',
    local: 'nextgen_plaid_development_cable',
    shard: :cable
  }
}
```

> **Note:** Remote and local names are identical — both are development databases.

#### 3. Safe Sync Workflow (per database)
```
PRE-FLIGHT (abort-on-fail):
  1. Verify SSH connectivity
  2. Verify remote PostgreSQL is reachable
  3. Verify local PostgreSQL is reachable
  4. Verify remote database exists (pg_dump --schema-only test)
  5. Check local disk space (backup_dir has room)
  6. Compare schema versions (warn on mismatch, abort on major difference)
  7. Warn if local Rails server / Solid Queue is running

PER-DATABASE SYNC (abort-on-fail, with rollback):
  1. Backup local database to file (pg_dump --format=custom)
  2. Verify backup file exists AND size > 0
     → If backup fails: ABORT this database, do NOT proceed to drop
  3. Capture remote table count for post-restore comparison
  4. Terminate local connections to database
  5. Drop local database
  6. Create fresh local database
  7. Stream: ssh pg_dump | pg_restore (using bash -o pipefail)
  8. Verify BOTH sides of pipe succeeded (PIPESTATUS check)
     → If stream fails: auto-restore from backup file
  9. Post-restore verification: compare table count with remote
     → If mismatch: warn (do not auto-rollback, data may still be valid)

POST-SYNC:
  1. Print summary (databases synced, backup locations, any warnings)
  2. Keep backup files (do NOT auto-delete — retention handled separately)
```

### Command-Line Interface
```bash
# Sync all three databases (with backup)
ruby script/sync_databases.rb

# Dry run — show what would happen, no changes
ruby script/sync_databases.rb --dry-run

# Sync specific databases only
ruby script/sync_databases.rb --databases=primary,queue

# Skip backup (requires --force as safety gate)
ruby script/sync_databases.rb --no-backup --force

# Custom remote host
ruby script/sync_databases.rb --remote-host=192.168.100.50

# Help
ruby script/sync_databases.rb --help
```

### Environment File (.env.sync.example)
```bash
# SSH Configuration
REMOTE_HOST=192.168.4.253
REMOTE_USER=ericsmith66
SSH_PORT=22

# PostgreSQL Paths (Homebrew defaults)
REMOTE_PG_DUMP_PATH=/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump
REMOTE_PSQL_PATH=/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql
LOCAL_PSQL_PATH=/opt/homebrew/opt/postgresql@16/bin/psql
LOCAL_PG_DUMP_PATH=/opt/homebrew/opt/postgresql@16/bin/pg_dump
LOCAL_PG_RESTORE_PATH=/opt/homebrew/opt/postgresql@16/bin/pg_restore

# Paths
BACKUP_DIR=./tmp/db_backups
```

## Data Loss Prevention Checklist

### 🔴 CRITICAL — Must be implemented

| # | Risk | Mitigation | Implementation |
|---|------|-----------|----------------|
| 1 | Backup fails silently, then DROP destroys data | Verify backup file exists AND size > 0 before DROP | Hard gate: `abort` if backup verification fails |
| 2 | SSH pipe fails mid-stream, local DB already dropped | Auto-restore from verified backup on pipe failure | Rescue block wraps stream; calls `pg_restore` from backup file |
| 3 | `pg_dump` fails on remote but `pg_restore` exit code is 0 | Use `bash -o pipefail` for pipe commands | Wrap pipe in `bash -c 'set -o pipefail; cmd1 | cmd2'` |
| 4 | `--no-backup` removes only safety net | Require `--force` in combination with `--no-backup` | OptionParser validation: abort if `--no-backup` without `--force` |
| 5 | Wrong database names cause empty dump → empty restore | Verify remote database exists before sync | Pre-flight: `pg_dump --schema-only` test on remote |
| 6 | Disk full prevents backup write | Check available disk space before starting | Pre-flight: compare `df` output against estimated backup size |

### 🟠 HIGH — Should be implemented

| # | Risk | Mitigation |
|---|------|-----------|
| 7 | Running Rails/Solid Queue reconnects after terminate | Warn user if local Puma/Solid Queue processes detected |
| 8 | Schema version mismatch causes corrupt restore | Compare `ActiveRecord::Schema` versions pre-sync; warn on mismatch |
| 9 | Backup binary path derived incorrectly | Use explicit `local_pg_dump_path` config (not string substitution on pg_restore path) |

### 🟡 MEDIUM — Nice to have

| # | Risk | Mitigation |
|---|------|-----------|
| 10 | Git branch divergence causes data/code mismatch | Log remote and local git branch/SHA in output; warn if different |
| 11 | No rollback after partial multi-db sync | Track per-database success/failure; report which have valid backups |

## Implementation Plan

### Phase 1: Foundation
1. Script skeleton with Config, CLI parsing (OptionParser), and logging
2. Pre-flight checks (SSH, PostgreSQL remote/local, disk space)
3. Remote database existence verification

### Phase 2: Safe Backup & Restore
1. Local backup with file verification gate
2. Stream sync with `pipefail` and exit code checking
3. Auto-rollback from backup on stream failure

### Phase 3: Verification & Safety
1. Post-restore table count comparison
2. `--no-backup --force` safety gate
3. Running process detection (Puma, Solid Queue)
4. Schema version comparison

### Phase 4: Polish
1. Dry-run mode (full pre-flight, no destructive ops)
2. Per-database selection (`--databases=`)
3. Summary report with backup file locations
4. README and usage documentation

## File Structure
```
nextgen-plaid/
├── script/
│   ├── sync_databases.rb          # Main script (single file, no gem deps)
│   └── .env.sync.example          # Example configuration
└── README-DB-SYNC.md              # Usage documentation
```

### Dependencies
**None beyond Ruby stdlib.** The script uses only:
- `open3` — subprocess execution with exit codes
- `fileutils` — directory creation
- `optparse` — CLI argument parsing
- `time` — timestamps for backup filenames

No additional gems required. All database operations use `pg_dump`, `pg_restore`, and `psql` binaries directly via shell.

## Testing Strategy

### Manual Testing Steps
```bash
# 1. Dry run — verify pre-flight checks, no changes made
ruby script/sync_databases.rb --dry-run

# 2. Single database sync with backup
ruby script/sync_databases.rb --databases=cable

# 3. Full sync (all three databases)
ruby script/sync_databases.rb

# 4. Verify data after sync
bin/rails runner "puts Account.count"
bin/rails runner "puts SolidQueue::Job.count"

# 5. Verify backup files exist
ls -la tmp/db_backups/
```

### Failure Scenario Tests
```bash
# 1. Test backup verification gate: fill disk, attempt sync
# 2. Test auto-rollback: kill SSH mid-stream, verify backup restored
# 3. Test --no-backup without --force: should abort
# 4. Test with wrong remote host: should fail at pre-flight
# 5. Test with Rails server running: should warn
```

## Success Criteria

### Functional Requirements
- [ ] Syncs all three development databases from remote to local
- [ ] Backs up local databases before overwrite (verified backup)
- [ ] Auto-restores from backup if stream fails
- [ ] Supports dry-run mode
- [ ] Supports individual database selection
- [ ] Handles errors gracefully with clear messages
- [ ] Provides progress feedback

### Data Safety Requirements
- [ ] **NEVER drops a database without a verified backup on disk** (unless `--no-backup --force`)
- [ ] **Verifies pipe exit codes** (both pg_dump and pg_restore sides)
- [ ] **Auto-restores from backup** on stream failure
- [ ] **Aborts before destructive ops** if any pre-flight check fails
- [ ] **Verifies remote database exists** before attempting sync
- [ ] **Warns about schema version mismatches**
- [ ] **Warns about running local Rails processes**

### Non-Functional Requirements
- [ ] Completes within 30 minutes for typical database sizes (~50 MB)
- [ ] No additional gem dependencies
- [ ] Clear, timestamped log output
- [ ] Backup files retained for manual rollback

## Risks and Mitigations

### Risk: Data Loss (CRITICAL)
- **Mitigation 1:** Verified backup gate — backup file must exist AND size > 0 before DROP
- **Mitigation 2:** Auto-rollback — stream failure triggers automatic restore from backup
- **Mitigation 3:** `pipefail` — catches remote-side failures that would otherwise be hidden
- **Mitigation 4:** `--no-backup` requires `--force` — prevents accidental unprotected syncs
- **Mitigation 5:** Pre-flight remote DB existence check — prevents empty-dump scenarios

### Risk: Network Interruption
- **Mitigation:** Auto-rollback from backup on stream failure
- **Mitigation:** SSH connection timeout (5 seconds for pre-flight)

### Risk: Schema Incompatibility
- **Mitigation:** Pre-flight schema version comparison
- **Mitigation:** Warn on mismatch, user decides whether to proceed

### Risk: Active Connections Interfere
- **Mitigation:** Terminate connections before DROP
- **Mitigation:** Warn if Puma/Solid Queue processes detected locally

## References

1. **Existing Backup Script:** `script/backup_dev_databases.sh`
2. **Remote Inspection Report:** `knowledge_base/remote-instance-inspection.md`
3. **Database Configuration:** `config/database.yml`
4. **PostgreSQL Docs:** pg_dump, pg_restore, PIPESTATUS

---

**Plan Status:** Reviewed & Approved for Implementation  
**Estimated Implementation Time:** 1 day  
**Primary Developer:** DevOps Engineer  
**Safety Review:** Complete (v2.0 — all data-loss vectors addressed)
