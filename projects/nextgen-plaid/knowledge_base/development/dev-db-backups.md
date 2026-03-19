### Development database backups (automated)

#### What gets backed up
The script `script/backup_dev_databases.sh` creates daily PostgreSQL dumps for the development databases defined in `config/database.yml`:

- `nextgen_plaid_development`
- `nextgen_plaid_development_queue`
- `nextgen_plaid_development_cable`

Backups are written to:

`/Users/ericsmith66/Library/Mobile Documents/com~apple~CloudDocs/Dev-Backups/M3-UltraServer`

and the last 7 days are retained (older files are deleted).

#### Run it manually
From the repo root:

```bash
./script/backup_dev_databases.sh
```

Optional overrides:

- `DEST_DIR` (backup destination directory)
- `RETENTION_DAYS` (default: `7`)

```bash
DEST_DIR=/tmp/dev-db-backups RETENTION_DAYS=3 ./script/backup_dev_databases.sh
```

#### Schedule it (cron)
An example cron entry is provided in `script/backup_dev_databases.cron.example`.

To install:

```bash
crontab -e
```

Then paste the example line.

#### Restore
Pick the dump you want and restore with `pg_restore`.

Example (restore into an existing DB; adjust as needed):

```bash
createdb nextgen_plaid_development
pg_restore --no-owner --no-acl --clean --if-exists --dbname nextgen_plaid_development /path/to/nextgen-plaid__dev__nextgen_plaid_development__YYYY-MM-DD_HHMMSS.dump
```
