# Deployment Setup Guide

**Version:** 1.0  
**Last Updated:** February 22, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Phase 0: PostgreSQL Password Setup](#phase-0-postgresql-password-setup)
4. [Phase 4: SSH Deployment Key Setup](#phase-4-ssh-deployment-key-setup)
5. [Phase 6: Testing & Validation](#phase-6-testing--validation)
6. [Troubleshooting](#troubleshooting)

---

## Overview

This guide walks through the manual setup steps required to enable automated deployments to production for nextgen-plaid.

**What you'll set up:**
- PostgreSQL passwords for production database
- SSH deployment keys for GitHub Actions
- GitHub repository secrets for automated deployments

---

## Prerequisites

- [x] Access to production server (192.168.4.253)
- [x] SSH access configured (SSH keys already set up)
- [x] Access to GitHub repository settings
- [x] PostgreSQL running on production server
- [x] nextgen-plaid repository cloned on production

---

## Phase 0: PostgreSQL Password Setup

### Step 1: Run Password Setup Script

On your **development machine**:

```bash
cd /Users/ericsmith66/development/agent-forge/projects/overwatch
chmod +x scripts/setup-postgres-passwords.sh
./scripts/setup-postgres-passwords.sh
```

**What it does:**
1. Generates a secure 32-character password
2. Sets password for `nextgen_plaid` PostgreSQL user (local)
3. Stores password in macOS Keychain (local)
4. Prompts to configure production server
5. Sets password on production PostgreSQL
6. Stores password in production Keychain
7. Tests database connectivity

### Step 2: Verify Local Setup

```bash
# Retrieve password from Keychain
PGPASS=$(security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w)

# Test connection
PGPASSWORD="${PGPASS}" psql -U nextgen_plaid -d postgres -c "SELECT 1;"
```

**Expected output:**
```
 ?column? 
----------
        1
(1 row)
```

### Step 3: Verify Production Setup

```bash
# SSH to production
ssh ericsmith66@192.168.4.253

# Retrieve password from Keychain
PGPASS=$(security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w)

# Test connection
PGPASSWORD="${PGPASS}" psql -U nextgen_plaid -d postgres -c "SELECT 1;"
```

**Expected output:**
```
 ?column? 
----------
        1
(1 row)
```

### Step 4: Setup Application Secrets

On **production server** (192.168.4.253):

```bash
cd /Users/ericsmith66/Development/nextgen-plaid
chmod +x scripts/setup-keychain.sh
./scripts/setup-keychain.sh
```

**Required secrets:**
- `DATABASE_PASSWORD` - Use the PostgreSQL password from above
- `PLAID_CLIENT_ID` - From Plaid dashboard
- `PLAID_SECRET` - From Plaid dashboard
- `CLAUDE_API_KEY` - From Anthropic console
- `RAILS_MASTER_KEY` - From `config/master.key` or generate new

**Retrieve values if needed:**
```bash
# On dev machine, get database password
security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w

# Get Rails master key (if exists)
cat config/master.key
```

---

## Phase 4: SSH Deployment Key Setup

### Step 1: Generate Deployment SSH Key

On **production server** (192.168.4.253):

```bash
# SSH to production
ssh ericsmith66@192.168.4.253

# Generate ED25519 key (modern, secure)
ssh-keygen -t ed25519 -C "github-actions-deploy-nextgen-plaid" -f ~/.ssh/github_deploy_nextgen_plaid

# Press Enter when prompted for passphrase (no passphrase for automation)
```

**Output:**
```
Generating public/private ed25519 key pair.
Enter passphrase (empty for no passphrase): [ENTER]
Enter same passphrase again: [ENTER]
Your identification has been saved in /Users/ericsmith66/.ssh/github_deploy_nextgen_plaid
Your public key has been saved in /Users/ericsmith66/.ssh/github_deploy_nextgen_plaid.pub
```

### Step 2: Add Public Key to Authorized Keys

Still on **production server**:

```bash
# Add public key to authorized_keys
cat ~/.ssh/github_deploy_nextgen_plaid.pub >> ~/.ssh/authorized_keys

# Verify permissions
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

# View the public key (for verification)
cat ~/.ssh/github_deploy_nextgen_plaid.pub
```

**Expected format:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... github-actions-deploy-nextgen-plaid
```

### Step 3: Retrieve Private Key

Still on **production server**:

```bash
# Display private key (copy this entire output)
cat ~/.ssh/github_deploy_nextgen_plaid
```

**IMPORTANT:** Copy the **ENTIRE** private key, including:
```
-----BEGIN OPENSSH PRIVATE KEY-----
[base64 encoded key content]
-----END OPENSSH PRIVATE KEY-----
```

### Step 4: Test SSH Connection Locally

On your **development machine**:

```bash
# Copy private key to temporary location (for testing)
ssh ericsmith66@192.168.4.253 "cat ~/.ssh/github_deploy_nextgen_plaid" > /tmp/test_deploy_key

# Set permissions
chmod 600 /tmp/test_deploy_key

# Test connection
ssh -i /tmp/test_deploy_key ericsmith66@192.168.4.253 "echo 'SSH connection successful'"

# Clean up test key
rm /tmp/test_deploy_key
```

**Expected output:**
```
SSH connection successful
```

### Step 5: Configure GitHub Secrets

1. **Navigate to GitHub Repository:**
   - Go to https://github.com/YOUR_ORG/nextgen-plaid
   - Click "Settings" tab
   - Click "Secrets and variables" → "Actions"

2. **Add Secret: PROD_DEPLOY_KEY**
   - Click "New repository secret"
   - Name: `PROD_DEPLOY_KEY`
   - Value: Paste the **entire private key** from Step 3
   - Click "Add secret"

3. **Add Secret: PROD_HOST**
   - Click "New repository secret"
   - Name: `PROD_HOST`
   - Value: `192.168.4.253`
   - Click "Add secret"

4. **Add Secret: PROD_USER**
   - Click "New repository secret"
   - Name: `PROD_USER`
   - Value: `ericsmith66`
   - Click "Add secret"

### Step 6: Verify GitHub Secrets

**Verify secrets are configured:**
1. Go to repository → Settings → Secrets and variables → Actions
2. You should see:
   - ✓ `PROD_DEPLOY_KEY` (hidden value)
   - ✓ `PROD_HOST` (hidden value)
   - ✓ `PROD_USER` (hidden value)

---

## Phase 6: Testing & Validation

### Test 1: Database Sync Script (Dry Run)

On your **development machine**:

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid

# Dry run (no changes made)
bin/sync-from-prod --dry-run
```

**Expected output:**
```
═══════════════════════════════════════════════════
  Database Sync from Production to Development
═══════════════════════════════════════════════════
Production: 192.168.4.253
Mode: DRY RUN
...
→ Testing SSH connectivity...
  ✓ Success
→ Testing remote PostgreSQL connection...
  ✓ Success
...
```

### Test 2: Database Sync Script (Actual Sync)

**⚠️ WARNING:** This will overwrite your local development databases!

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid

# Full sync
bin/sync-from-prod

# When prompted, type "yes" to confirm
```

**Expected results:**
- Local databases backed up to `tmp/db_backups/`
- Production databases dumped and downloaded
- Local databases replaced with production data
- Verification shows table counts

### Test 3: Database Backup/Restore Cycle

On **production server** (192.168.4.253):

```bash
cd /Users/ericsmith66/Development/nextgen-plaid

# Create backup
./scripts/backup-database.sh

# List backups
./scripts/restore-database.sh --list

# Expected output shows timestamp, files, and sizes
```

### Test 4: Manual Deployment

On your **development machine**:

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid

# Deploy to production
bin/deploy-prod
```

**Expected phases:**
1. ✓ Pre-flight checks (30s)
2. ✓ Database backup (2-5 min)
3. ✓ Pull latest code (15s)
4. ✓ Install dependencies (30-60s)
5. ✓ Run migrations (1-5 min)
6. ✓ Precompile assets (30-90s)
7. ✓ Restart service (10s)

**Expected final output:**
```
═══════════════════════════════════════════════════
  Deployment Successful! ✓
═══════════════════════════════════════════════════
```

### Test 5: GitHub Actions Deployment

1. **Navigate to GitHub Actions:**
   - Go to https://github.com/YOUR_ORG/nextgen-plaid/actions
   - Click "Deploy to Production" workflow

2. **Trigger Manual Deployment:**
   - Click "Run workflow" button
   - Select branch: `main`
   - Options:
     - Environment: `production`
     - Skip backup: `false` (unchecked)
     - Skip tests: `false` (unchecked)
   - Click "Run workflow"

3. **Monitor Deployment:**
   - Watch workflow progress
   - All steps should complete successfully
   - Check "Deployment summary" at the bottom

**Expected output in GitHub Actions:**
```
✓ Checkout code
✓ Setup Ruby
✓ Run pre-deployment checks
✓ Run tests
✓ Run Brakeman security scan
✓ Run RuboCop linter
✓ Configure SSH
✓ Test SSH connection
✓ Deploy to production
✓ Verify deployment
✓ Deployment summary
```

### Test 6: Manual Rollback

**Scenario:** Test rollback to previous commit (no database restore needed)

On **production server** (192.168.4.253):

```bash
cd /Users/ericsmith66/Development/nextgen-plaid

# Get previous commit (saved during deployment)
PREV_COMMIT=$(cat .last_commit)
echo "Previous commit: ${PREV_COMMIT}"

# Rollback code
git reset --hard ${PREV_COMMIT}

# Restart application
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid

# Wait for startup
sleep 8

# Verify health
curl http://localhost:3000/health
```

**Expected output:**
```
{"status":"ok"}
```

---

## Troubleshooting

### Issue: PostgreSQL Password Authentication Fails

**Symptoms:**
```
FATAL: password authentication failed for user "nextgen_plaid"
```

**Solution:**
```bash
# Verify password is stored in Keychain
security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w

# If missing or wrong, re-run setup
./scripts/setup-postgres-passwords.sh
```

### Issue: SSH Deployment Key Not Working

**Symptoms:**
```
Permission denied (publickey)
```

**Solution:**
```bash
# On production server, verify public key is in authorized_keys
grep "github-actions-deploy" ~/.ssh/authorized_keys

# If missing, add it again
cat ~/.ssh/github_deploy_nextgen_plaid.pub >> ~/.ssh/authorized_keys

# Verify permissions
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### Issue: GitHub Actions Fails on SSH Connection

**Symptoms:**
```
Error: Failed to connect to production server
```

**Solution:**
1. Verify `PROD_DEPLOY_KEY` secret contains **entire** private key (including BEGIN/END lines)
2. Verify `PROD_HOST` is `192.168.4.253`
3. Verify `PROD_USER` is `ericsmith66`
4. Check production server is online: `ping 192.168.4.253`

### Issue: Database Backup Fails During Deployment

**Symptoms:**
```
✗ Database backup failed
Deployment aborted
```

**Solution:**
```bash
# SSH to production
ssh ericsmith66@192.168.4.253

# Manually test backup
cd Development/nextgen-plaid
./scripts/backup-database.sh

# Check for errors in output
# Common issues:
# - Insufficient disk space
# - PostgreSQL not running
# - Permission issues on backup directory
```

### Issue: Health Check Fails After Deployment

**Symptoms:**
```
✗ Health check failed (HTTP 500)
```

**Solution:**
```bash
# SSH to production
ssh ericsmith66@192.168.4.253

# Check application logs
cd Development/nextgen-plaid
tail -100 log/production.log

# Check if Puma is running
ps aux | grep puma | grep production

# Manually restart if needed
launchctl kickstart -k gui/$(id -u)/com.agentforge.nextgen-plaid
```

---

## Next Steps

After completing all tests successfully:

1. ✅ PostgreSQL passwords configured (dev + prod)
2. ✅ Application secrets stored in Keychain
3. ✅ SSH deployment key configured
4. ✅ GitHub secrets configured
5. ✅ Database sync tested
6. ✅ Database backup/restore tested
7. ✅ Manual deployment tested
8. ✅ GitHub Actions deployment tested
9. ✅ Rollback procedures tested

**You can now:**
- Deploy to production via GitHub Actions UI
- Deploy to production via `bin/deploy-prod`
- Sync production data to dev via `bin/sync-from-prod`
- Restore from backups if needed
- Rollback deployments if issues arise

---

## Documentation References

- **RUNBOOK.md** - Operational procedures and troubleshooting
- **README.md** - Application overview and development setup
- **.github/workflows/deploy.yml** - Deployment workflow configuration

---

**Document End**

*For questions or issues, contact the Agent Forge team.*
