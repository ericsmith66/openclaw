# Manual Setup Steps - Production Configuration

**Status:** ⚠️ **DEPRECATED** — See current documentation below

---

## ⚠️ **DEPRECATION NOTICE**

**This document is OBSOLETE. The procedures described here have been replaced.**

📄 **For current setup procedures, see:**
- `/Users/ericsmith66/Development/nextgen-plaid/RUNBOOK.md` (v2.0)
- `docs/deployments/nextgen-plaid-current-state-2026-02-25.md`

**This document is retained for historical reference only.**

---

## ✅ **Already Complete (Automated)**

- ✅ PostgreSQL password generated (32 characters)
- ✅ Local PostgreSQL user `nextgen_plaid` password set
- ✅ Password stored in local Keychain
- ✅ Local database connection tested successfully

**Your password is:** `gaMLXyYf4YDKfYkmkMiGDWseXFJBoPWn3K3GPInc0zM=`

---

## ⏳ **Steps YOU Need to Complete**

### **Step 1: Make Scripts Executable (2 minutes)**

Run these commands on your **dev machine**:

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
chmod +x bin/sync-from-prod
chmod +x bin/prod
chmod +x bin/deploy-prod
chmod +x scripts/backup-database.sh
chmod +x scripts/restore-database.sh
chmod +x scripts/setup-keychain.sh
```

---

### **Step 2: Setup Production PostgreSQL Password (5 minutes)**

**On your dev machine**, copy the password:
```bash
security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w
```

**Output:** `gaMLXyYf4YDKfYkmkMiGDWseXFJBoPWn3K3GPInc0zM=`

**SSH to production:**
```bash
ssh ericsmith66@192.168.4.253
```

**On production server, run these commands:**
```bash
# Set the password variable (paste the password from above)
PROD_DB_PASS="gaMLXyYf4YDKfYkmkMiGDWseXFJBoPWn3K3GPInc0zM="

# Set PostgreSQL password
psql -U ericsmith66 -d postgres <<EOSQL
ALTER USER nextgen_plaid WITH PASSWORD \$\$${PROD_DB_PASS}\$\$;
EOSQL

# Store in Keychain
security delete-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' 2>/dev/null || true
security add-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w "${PROD_DB_PASS}"

# Test connection
PGPASSWORD="${PROD_DB_PASS}" psql -U nextgen_plaid -d postgres -c "SELECT 1;"
```

**Expected output:**
```
ALTER ROLE
 ?column? 
----------
        1
(1 row)
```

---

### **Step 3: Setup Application Secrets on Production (10 minutes)**

**Still on production server (192.168.4.253):**

```bash
cd /Users/ericsmith66/Development/nextgen-plaid
chmod +x scripts/setup-keychain.sh
./scripts/setup-keychain.sh
```

**When prompted, enter these values:**

| Secret | Value | Where to Get It |
|--------|-------|-----------------|
| `DATABASE_PASSWORD` | `gaMLXyYf4YDKfYkmkMiGDWseXFJBoPWn3K3GPInc0zM=` | From Step 2 above |
| `PLAID_CLIENT_ID` | (your Plaid client ID) | https://dashboard.plaid.com/developers/keys |
| `PLAID_SECRET` | (your Plaid secret) | https://dashboard.plaid.com/developers/keys |
| `CLAUDE_API_KEY` | (your Claude API key) | https://console.anthropic.com/settings/keys |
| `RAILS_MASTER_KEY` | (from config/master.key) | See below |

**To get RAILS_MASTER_KEY:**
```bash
# On dev machine
cat /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/config/master.key
```

---

### **Step 4: Setup SSH Deployment Key (10 minutes)**

**On production server (192.168.4.253):**

```bash
# Generate deployment SSH key
ssh-keygen -t ed25519 -C "github-actions-deploy-nextgen-plaid" -f ~/.ssh/github_deploy_nextgen_plaid

# Press ENTER for no passphrase (twice)

# Add public key to authorized_keys
cat ~/.ssh/github_deploy_nextgen_plaid.pub >> ~/.ssh/authorized_keys

# Set correct permissions
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

# Display private key (copy this for GitHub)
echo "=== COPY THIS ENTIRE OUTPUT FOR GITHUB ==="
cat ~/.ssh/github_deploy_nextgen_plaid
echo "=== END OF PRIVATE KEY ==="
```

**Copy the entire private key** including the `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----` lines.

---

### **Step 5: Configure GitHub Secrets (5 minutes)**

1. **Go to GitHub repository:**
   - Navigate to your nextgen-plaid repository on GitHub
   - Click **Settings** tab
   - Click **Secrets and variables** → **Actions**

2. **Add three secrets:**

   **Secret 1: PROD_DEPLOY_KEY**
   - Click "New repository secret"
   - Name: `PROD_DEPLOY_KEY`
   - Value: Paste the **entire private key** from Step 4
   - Click "Add secret"

   **Secret 2: PROD_HOST**
   - Click "New repository secret"
   - Name: `PROD_HOST`
   - Value: `192.168.4.253`
   - Click "Add secret"

   **Secret 3: PROD_USER**
   - Click "New repository secret"
   - Name: `PROD_USER`
   - Value: `ericsmith66`
   - Click "Add secret"

---

### **Step 6: Test Database Sync (5 minutes)**

**On your dev machine:**

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid

# Dry run first (no changes)
bin/sync-from-prod --dry-run
```

**Expected output:**
```
→ Testing SSH connectivity...
  ✓ Success
→ Testing remote PostgreSQL connection...
  ✓ Success
→ Testing local PostgreSQL connection...
  ✓ Success
```

**If dry-run succeeds, try actual sync:**
```bash
# This will OVERWRITE your local dev databases!
bin/sync-from-prod
```

Type `yes` when prompted.

---

### **Step 7: Test Manual Deployment (10 minutes)**

**On your dev machine:**

```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
bin/deploy-prod
```

**Expected phases:**
```
→ [1/7] Running pre-flight checks...
→ [2/7] Creating database backups...
→ [3/7] Updating production code...
→ [4/7] Installing dependencies...
→ [5/7] Running database migrations...
→ [6/7] Precompiling assets...
→ [7/7] Restarting application...
→ Verifying deployment...

═══════════════════════════════════════════════════
  Deployment Successful! ✓
═══════════════════════════════════════════════════
```

---

### **Step 8: Test GitHub Actions Deployment (5 minutes)**

1. **Go to GitHub repository → Actions tab**
2. **Click "Deploy to Production" workflow**
3. **Click "Run workflow" button**
4. **Leave defaults:**
   - Environment: `production`
   - Skip backup: `unchecked`
   - Skip tests: `unchecked`
5. **Click "Run workflow"**
6. **Watch the workflow run** - all steps should pass

---

## ✅ **Verification Checklist**

After completing all steps:

- [ ] Local PostgreSQL password set and tested
- [ ] Production PostgreSQL password set and tested
- [ ] Application secrets stored on production
- [ ] SSH deployment key generated and added to GitHub
- [ ] Database sync dry-run successful
- [ ] Manual deployment successful
- [ ] GitHub Actions deployment successful

---

## 🆘 **Troubleshooting**

### Issue: PostgreSQL connection fails
```bash
# Check if PostgreSQL is running
ps aux | grep postgres

# Check if user exists
psql -U ericsmith66 -d postgres -c "\du"
```

### Issue: SSH connection fails
```bash
# Test SSH
ssh ericsmith66@192.168.4.253 "echo 'SSH OK'"

# Check SSH keys
ls -la ~/.ssh/
```

### Issue: Keychain access denied
```bash
# On production, test keychain
security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w
```

---

## 📚 **Reference Documentation**

- **Full Operations Guide:** `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/RUNBOOK.md`
- **Detailed Setup Guide:** `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/docs/DEPLOYMENT_SETUP.md`
- **Quick Reference:** `/Users/ericsmith66/development/agent-forge/projects/overwatch/QUICK_START.md`

---

**Ready to start? Begin with Step 1!** 🚀
