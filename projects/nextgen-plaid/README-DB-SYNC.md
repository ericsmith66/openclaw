# Database Sync — NextGen Plaid

Sync development databases from the remote server (192.168.4.253) to your local machine.

## Quick Start

```bash
# Preview what will happen (no changes)
ruby script/sync_databases.rb --dry-run

# Sync all three databases (with automatic backup)
ruby script/sync_databases.rb

# Sync only the primary database
ruby script/sync_databases.rb --databases=primary
```

## What It Does

1. **Pre-flight checks** — verifies SSH, PostgreSQL (remote & local), remote database existence, disk space, schema version, and warns about running Rails processes.
2. **Backs up** each local database to `tmp/db_backups/` (pg_dump custom format) and **verifies** the backup file before proceeding.
3. **Drops & recreates** the local database, then **streams** the remote data via SSH pipe (`pg_dump | pg_restore`) with `pipefail` to catch remote failures.
4. **Auto-rolls back** from the backup if the stream fails.
5. **Verifies** the restore by comparing table counts.

## Databases Synced

| Key | Database Name | Purpose |
|-----|--------------|---------|
| `primary` | `nextgen_plaid_development` | Main application data |
| `queue` | `nextgen_plaid_development_queue` | Solid Queue jobs |
| `cable` | `nextgen_plaid_development_cable` | Action Cable |

## Options

```
--dry-run              Preview actions without making changes
--databases=LIST       Comma-separated: primary,queue,cable (default: all)
--no-backup            Skip local backup (requires --force)
--force                Allow dangerous operations
--remote-host=HOST     Override remote host (default: 192.168.4.253)
--remote-user=USER     Override remote user (default: ericsmith66)
-h, --help             Show help
```

## Safety Guarantees

- **Backup verification gate** — the local database is NEVER dropped unless a backup file exists on disk with size > 0.
- **pipefail** — if `pg_dump` fails on the remote side, the error is caught (not hidden by `pg_restore`'s exit code).
- **Auto-rollback** — if the stream fails, the script automatically restores from the backup.
- **--no-backup requires --force** — prevents accidentally running without a safety net.
- **Pre-flight remote DB check** — confirms the remote database actually exists before attempting to sync.

## Environment Variables

All settings have sensible defaults. Override via environment variables if needed:

```bash
REMOTE_HOST=192.168.4.253
REMOTE_USER=ericsmith66
SSH_PORT=22
REMOTE_PG_DUMP_PATH=/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump
REMOTE_PSQL_PATH=/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql
LOCAL_PSQL_PATH=/opt/homebrew/opt/postgresql@16/bin/psql
LOCAL_PG_DUMP_PATH=/opt/homebrew/opt/postgresql@16/bin/pg_dump
LOCAL_PG_RESTORE_PATH=/opt/homebrew/opt/postgresql@16/bin/pg_restore
BACKUP_DIR=./tmp/db_backups
```

## Dependencies

**None beyond Ruby stdlib.** No additional gems required. Uses `pg_dump`, `pg_restore`, and `psql` binaries directly.

## Backup & Recovery

Backups are stored in `tmp/db_backups/` with timestamped filenames:
```
tmp/db_backups/nextgen_plaid_development_20260216_143000.dump
```

To manually restore a backup:
```bash
/opt/homebrew/opt/postgresql@16/bin/psql -c "DROP DATABASE IF EXISTS nextgen_plaid_development;" postgres
/opt/homebrew/opt/postgresql@16/bin/psql -c "CREATE DATABASE nextgen_plaid_development;" postgres
/opt/homebrew/opt/postgresql@16/bin/pg_restore --no-owner --no-acl -d nextgen_plaid_development tmp/db_backups/nextgen_plaid_development_20260216_143000.dump
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SSH connection fails | Verify: `ssh ericsmith66@192.168.4.253 'echo ok'` |
| DROP DATABASE fails | Stop local Rails server and Solid Queue first |
| Disk space check fails | Free up space or set `BACKUP_DIR` to a volume with more room |
| Schema version mismatch warning | Run `bin/rails db:migrate` locally to align schemas |
