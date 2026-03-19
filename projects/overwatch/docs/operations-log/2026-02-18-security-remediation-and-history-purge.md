# Operations Log: Security Remediation & Git History Purge
**Date:** February 18, 2026  
**Operator:** AiderDesk (automated) + Eric Smith (manual steps)  
**Systems Affected:** nextgen-plaid (dev machine, GitHub, production server 192.168.4.253)  
**Duration:** ~1.5 hours  
**Severity:** Critical (security — sensitive data in git history)

---

## Background

Epic 8 security remediation required purging PostgreSQL database dumps (`.sql` files) from the entire git history of `nextgen-plaid` using `git filter-repo`. This rewrites all commit SHAs, making the repository incompatible with any existing clones.

Additionally, the `feature/epic-6` branch (transaction UI mocks and architecture) had been merged into `main` prior to this work.

### Pre-Existing State
| Location | Branch | HEAD | State |
|---|---|---|---|
| Dev machine | `main` | `4260ba5` | Clean (purged history), no remote |
| GitHub | `main` | `fbc0064` | Dirty (old history with SQL blobs) |
| Prod server (192.168.4.253) | `main` | `fbc0064` | Dirty history + 14 uncommitted files (holdings migration) |

---

## Actions Performed

### Step 1 — Preserve Uncommitted Work on Production Server
**Status:** ✅ Complete

Production had 14 uncommitted files comprising the holdings migration feature (moving Holdings nav to Portfolio, simplifying Net Worth summary). Three backup layers created:

| Layer | Location on Prod | Purpose |
|---|---|---|
| Unified patch (907 lines) | `/tmp/nextgen-plaid-holdings-migration.patch` | Primary re-apply path |
| 14 individual patches | `/tmp/nextgen-plaid-patches/*.patch` | Granular fallback |
| 14 raw file copies | `/tmp/nextgen-plaid-raw-files/` | Last resort |
| Stash list | `/tmp/nextgen-plaid-stash-list.txt` | Reference (5 stashes from older work) |

**Files preserved:**
- `app/components/navigation/sidebar_component.html.erb`
- `app/components/net_worth/holdings_summary_component.html.erb`
- `app/components/net_worth/holdings_summary_component.rb`
- `app/components/portfolio/holdings_grid_component.html.erb`
- `app/controllers/net_worth/dashboard_controller.rb`
- `app/controllers/net_worth/holdings_controller.rb`
- `app/views/net_worth/dashboard/show.html.erb`
- `app/views/net_worth/holdings/show.html.erb`
- `config/agent_prompts/sap_system.md`
- `knowledge_base/schemas/null_fields_report.md`
- `test/components/navigation/sidebar_component_test.rb`
- `test/components/net_worth/holdings_summary_component_test.rb`
- `test/components/portfolio/holdings_grid_component_test.rb`
- `test/integration/net_worth_holdings_frame_test.rb`

### Step 2 — Re-add Remote & Force-Push Clean History to GitHub
**Status:** ✅ Complete

On dev machine:
```
git remote add origin https://github.com/ericsmith66/nextgen-plaid.git
git push origin main --force
```
Result: GitHub `main` updated `fbc0064` → `4260ba5` (forced update).

### Step 3 — Re-clone on Production Server
**Status:** ✅ Complete

**Issue encountered:** SSH key on prod (`id_ed25519`) has a passphrase and is not recognized by GitHub. HTTPS clone also failed (no credentials in non-interactive session).

**Solution:** Used `git bundle` to transfer the clean repo:
1. Created bundle on dev: `git bundle create /tmp/nextgen-plaid-clean.bundle main`
2. SCP'd bundle to prod: `scp /tmp/nextgen-plaid-clean.bundle 192.168.4.253:/tmp/`
3. Cloned from bundle on prod: `git clone /tmp/nextgen-plaid-clean.bundle nextgen-plaid`
4. Set remote: `git remote set-url origin git@github.com:ericsmith66/nextgen-plaid.git`

**Restored files from old backup:**
- `.env` (secrets — 1381 bytes)
- `.env.production` (733 bytes)
- `.env.example` (719 bytes)
- `config/master.key` (32 bytes) — MD5 verified matches dev machine: `1428f4b005cee6cbe3db188907e4b340`
- `config/credentials.yml.enc` (796 bytes) — MD5 verified matches dev machine: `f5659cd31978a64bae0e9efaa771ef05`

### Step 4 — Re-apply Holdings Migration Patch
**Status:** ✅ Complete

Unified patch applied cleanly on first attempt:
```
git apply --check /tmp/nextgen-plaid-holdings-migration.patch  # dry-run: OK
git apply /tmp/nextgen-plaid-holdings-migration.patch          # applied: 14 files, 220+, 409-
```

### Step 5 — SmartProxy Bundle Install
**Status:** ✅ Complete

The fresh clone required `bundle install` in both the main app and `smart_proxy/` subdirectory.

### Step 6 — Service Restart Attempts
**Status:** ⚠️ Partial — Required Manual Restart

**Issues encountered with non-interactive startup:**
1. **Port conflict:** `bin/dev` defaults to port 3016, not 3000. Cloudflare Tunnel expects 3000.
2. **Foreman + nohup:** Tailwind CSS watcher exits when no TTY is present, causing foreman to SIGTERM all processes.
3. **Orphaned processes:** Multiple failed start attempts left orphaned puma/smartproxy processes on ports.

**Resolution:** 
- Fixed `bin/dev` to default to port 3000 (`export PORT="${PORT:-3000}"`)
- Killed all orphaned processes
- User restarted manually from RubyMine (normal startup procedure)

### Step 7 — Create feature/holdings Branch & Push
**Status:** ✅ Complete

On prod server:
1. Created `feature/holdings` from `main`
2. Committed all 15 files (14 holdings migration + bin/dev fix) as `de48347`
3. Switched back to `main`
4. User pushed via RubyMine: `git push --set-upstream origin feature/holdings`

Verified on GitHub: `de48347c47ebb5d40a863e039219767473b0ba43` at `refs/heads/feature/holdings`

---

## Issues Discovered

### 1. SSH Key Not Registered with GitHub (Prod Server)
- **Impact:** Cannot `git clone`, `git pull`, or `git push` non-interactively from prod
- **Key:** `~/.ssh/id_ed25519` with passphrase
- **Workaround used:** Git bundle for clone; RubyMine for push
- **Action needed:** Register SSH key with GitHub or configure HTTPS credential caching

### 2. bin/dev Default Port was 3016
- **Impact:** Rails started on wrong port; Cloudflare Tunnel couldn't reach it
- **Fix applied:** Changed default from 3016 to 3000 in `bin/dev`
- **Committed on:** `feature/holdings` branch (`de48347`)

### 3. Non-Interactive Service Startup Unreliable
- **Impact:** Cannot start nextgen-plaid reliably via SSH/nohup/screen
- **Root cause:** Tailwind CSS watcher requires TTY; foreman kills all children when one exits
- **Current workaround:** Manual start from RubyMine
- **Action needed:** Implement `Procfile.prod` and `bin/prod` (see stabilization plan TASK 1.1, 1.2)

### 4. credentials.yml.enc Not in Git History After Purge
- **Impact:** Fresh clones missing Rails credentials
- **Workaround:** Copied from old backup; verified MD5 match with dev machine
- **Action needed:** Ensure `credentials.yml.enc` is committed to the repo (it's encrypted, safe for git)

### 5. Stale Processes on Prod
- **Found:** Orphaned `rails test` process (PID 8786) running since Jan 21
- **Action:** Killed during cleanup

---

## Post-Operation State

| Location | Branch | HEAD | State |
|---|---|---|---|
| Dev machine | `main` | `4260ba5` | Clean, remote configured |
| GitHub | `main` | `4260ba5` | Clean history (SQL blobs purged) |
| GitHub | `feature/holdings` | `de48347` | Holdings migration + bin/dev fix |
| Prod server | `main` | `4260ba5` | Clean working tree, services running via RubyMine |

### Backup Artifacts on Prod (to be cleaned up)
- `~/Development/nextgen-plaid-old-backup/` — full old repo with stashes
- `/tmp/nextgen-plaid-holdings-migration.patch`
- `/tmp/nextgen-plaid-patches/` (14 individual patches)
- `/tmp/nextgen-plaid-raw-files/` (14 raw files)
- `/tmp/nextgen-plaid-stash-list.txt`
- `/tmp/nextgen-plaid-clean.bundle`

---

## Stabilization Plan Updates Required

The following items should be added to `plan-stabilize-nextgen-plaid.md`:

1. **Automate service startup** — Current reliance on RubyMine interactive session is fragile. `Procfile.prod` + `bin/prod` + launchd plist (already in plan as TASKs 1.1, 1.2, 1.5) is critical.
2. **Fix SSH key on prod** — Either register with GitHub or configure HTTPS credential caching for non-interactive git operations.
3. **Commit `credentials.yml.enc`** — Ensure it's tracked in git (currently missing from clean history).
4. **Clean up `/tmp/` backup artifacts** — After confirming everything is stable.
5. **Remove `nextgen-plaid-old-backup`** — After confirming everything is stable.
