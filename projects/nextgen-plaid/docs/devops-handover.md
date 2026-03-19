# nextgen-plaid — DevOps Handover Document

**Date:** February 25, 2026  
**Application:** nextgen-plaid  
**Prepared by:** Eric Smith

---

## 1. Environment Overview

| | Development | Production |
|---|---|---|
| **Machine** | Local MacBook | 192.168.4.253 (M3 Ultra) |
| **User** | ericsmith66 | ericsmith66 |
| **App Path** | `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid` | `/Users/ericsmith66/Development/nextgen-plaid` |
| **Rails Env** | development | production |
| **Port** | 3016 | 3000 |
| **Branch** | main | main |

---

## 2. Stack

| Component | Version / Detail |
|---|---|
| **Ruby** | 3.3.10 (managed via rbenv) |
| **Rails** | 8.1.1 |
| **Database** | PostgreSQL 16 |
| **Web Server** | Puma (via Foreman) |
| **Background Jobs** | Solid Queue |
| **Action Cable** | Database-backed |
| **Cache** | Solid Cache |
| **Process Manager** | Foreman (Phase 1 — launchd planned for Phase 2) |

---

## 3. Databases

```
nextgen_plaid_production          # Main application database
nextgen_plaid_production_queue    # Solid Queue background jobs
nextgen_plaid_production_cable    # Action Cable connections
nextgen_plaid_production_cache    # Solid Cache entries
```

- **Host:** localhost (PostgreSQL runs on the production machine itself)
- **Port:** 5432
- **User:** nextgen_plaid
- **Auth:** Password (stored in macOS Keychain — see Section 6)

---

## 4. Starting & Stopping the Application

### Start Production
```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
bin/prod
```

`bin/prod` does the following automatically:
- Sources `~/.zprofile` (rbenv, Homebrew paths)
- Loads all secrets from macOS Keychain
- Verifies PostgreSQL connectivity
- Checks pending migrations
- Starts Puma (port 3000) + SolidQueue via Foreman using `Procfile.prod`

### Stop Production
```bash
# Graceful
pkill -TERM -f "puma.*production"

# Force
pkill -9 -f "puma.*production"
```

### Check Status
```bash
ps aux | grep puma | grep -v grep
lsof -i :3000
```

### Health Check
```bash
curl http://192.168.4.253:3000/health
# Expected: {"status":"ok"} with HTTP 200
```

---

## 5. Deployment (Code Updates)

### SSH into prod and pull
```bash
ssh ericsmith66@192.168.4.253
cd /Users/ericsmith66/Development/nextgen-plaid
git pull
```

### Full deployment steps
```bash
git pull
bundle install
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails assets:precompile
pkill -TERM -f "puma.*production"
sleep 2
bin/prod
```

### Automated deployment (from dev machine)
```bash
bin/deploy-prod
```

Options:
```bash
bin/deploy-prod --skip-tests    # Skip test suite
bin/deploy-prod --skip-backup   # Skip DB backup (not recommended)
```

---

## 6. Secrets Management

All secrets are stored in **macOS Keychain** on the production machine (192.168.4.253). There are no `.env` files in production.

### Retrieve a secret
```bash
security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-<KEY>' -w
```

### Available secrets
| Key | Description |
|---|---|
| `DATABASE_PASSWORD` | PostgreSQL password for nextgen_plaid user |
| `PLAID_CLIENT_ID` | Plaid API Client ID |
| `PLAID_SECRET` | Plaid API Secret |
| `CLAUDE_API_KEY` | Anthropic Claude API Key |
| `RAILS_MASTER_KEY` | Rails credentials encryption key |

### ⚠️ Keychain access in SSH sessions

The macOS Keychain is locked by default in SSH sessions. `bin/prod` must be run from a **GUI terminal session** on the production machine (not via SSH) to allow Keychain access.

If you need to run `bin/prod` via SSH, unlock the keychain first:
```bash
security unlock-keychain -p '<login-password>' ~/Library/Keychains/login.keychain-db
```

### Add or update a secret
```bash
# Delete existing
security delete-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-<KEY>'

# Add new value
security add-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-<KEY>' -w '<VALUE>'
```

---

## 7. SSH Access to Production

```bash
ssh ericsmith66@192.168.4.253
```

Key: `~/.ssh/id_ed25519` (passphrase protected, stored in macOS Keychain via `ssh-add --apple-use-keychain`)

### SSH agent setup (already configured on prod)
- `~/.ssh/config` has `UseKeychain yes` and `AddKeysToAgent yes` for `github.com`
- `~/.zshenv` exports `SSH_AUTH_SOCK` pointing to the macOS GUI agent socket so SSH sessions inherit it
- `~/.zshenv` initialises rbenv so the correct Ruby (3.3.10) is used in all sessions

### Git pull from GitHub
```bash
# Works without passphrase prompt (key cached in Keychain)
git pull
```

---

## 8. Ruby Environment

Ruby is managed via **rbenv** on both machines.

| | Detail |
|---|---|
| **Version** | 3.3.10 |
| **Manager** | rbenv |
| **Homebrew prefix** | `/opt/homebrew` |
| **rbenv init** | Configured in `~/.zshenv` (all sessions) and `~/.zshrc` (interactive) |

The system Ruby (2.6.10 at `/usr/bin/ruby`) must **never** be used — it lacks bundler 2.7.1 and will fail.

Verify correct Ruby in any session:
```bash
ruby -v        # Should show 3.3.10
which ruby     # Should show /Users/ericsmith66/.rbenv/shims/ruby
```

---

## 9. Database Backups

### Manual backup
```bash
cd /Users/ericsmith66/Development/nextgen-plaid
./scripts/backup-database.sh
```

Backups are stored at: `~/backups/nextgen-plaid/`  
Format: `YYYYMMDD_HHMMSS_<database>.dump`  
Retention: 30 days (auto-cleaned)

### List backups
```bash
./scripts/restore-database.sh --list
```

### Restore from backup
```bash
./scripts/restore-database.sh <TIMESTAMP>
# Example:
./scripts/restore-database.sh 20260222_143015
```

---

## 10. Logs

| Log | Location |
|---|---|
| Rails application | `log/production.log` |
| Puma stdout | `log/puma.stdout.log` |
| Puma stderr | `log/puma.stderr.log` |
| PostgreSQL | `/opt/homebrew/var/log/postgresql@16.log` |

```bash
# Live tail
tail -f log/production.log
```

---

## 11. Known Issues & Workarounds

| Issue | Status | Workaround |
|---|---|---|
| Keychain locked in SSH sessions | Open | Run `bin/prod` from GUI terminal, or unlock keychain manually via `security unlock-keychain` |
| `RAILS_ENV` not set globally | By design | Set explicitly or rely on `bin/prod` which sets it |
| Process manager is Foreman (Phase 1) | In progress | Will migrate to launchd in Phase 2 for auto-restart on reboot |
| No external reverse proxy / SSL termination | Planned | Cloudflare Tunnel to `plaid.api.higroundsolution.com` (TBD) |

---

## 12. Scripts Reference

| Script | Purpose |
|---|---|
| `bin/dev` | Start development server (port 3016) |
| `bin/prod` | Start production server (port 3000) |
| `bin/deploy-prod` | Full automated deployment from dev machine |
| `bin/sync-from-prod` | Sync production DB to local dev (⚠️ overwrites local) |
| `scripts/backup-database.sh` | Manual database backup |
| `scripts/restore-database.sh` | Restore database from backup |
| `scripts/setup-keychain.sh` | First-time Keychain secrets setup |

---

## 13. GitHub Repository

```
git@github.com:ericsmith66/nextgen-plaid.git
```

- Default branch: `main`
- Deployment branch: `main`
- No CI/CD pipeline currently configured (GitHub Actions secrets prepared but not active)

---

*For questions contact Eric Smith.*
