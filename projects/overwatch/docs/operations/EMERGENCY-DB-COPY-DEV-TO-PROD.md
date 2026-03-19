# Emergency Database Copy: Development → Production (Same Server)

**Date:** February 22, 2026  
**Server:** 192.168.4.253 (ericsmith66)  
**Task:** Copy development databases to production databases on the SAME server

---

## ⚠️ CRITICAL WARNING

**THIS WILL OVERWRITE ALL PRODUCTION DATA!**

You are about to:
- **DELETE** all data in production databases
- **COPY** all data from development databases to production databases
- This is **IRREVERSIBLE** without a backup

**Only proceed if:**
- ✅ Production database is empty (which it currently is)
- ✅ Development database has the data you want in production
- ✅ You have reviewed what's in development

---

## Pre-Flight Checks

### 1. Verify Current Database State

```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid
source ~/.zprofile
eval "$(rbenv init -)"

# Check production data (should be empty)
RAILS_ENV=production bundle exec rails runner "
  puts 'Production Database Status:'
  puts 'Users: ' + User.count.to_s
  puts 'Plaid Items: ' + PlaidItem.count.to_s
  puts 'Accounts: ' + Account.count.to_s
  puts 'Transactions: ' + Transaction.count.to_s
"

# Check development data (this is what will be copied)
RAILS_ENV=development bundle exec rails runner "
  puts 'Development Database Status:'
  puts 'Users: ' + User.count.to_s
  puts 'Plaid Items: ' + PlaidItem.count.to_s
  puts 'Accounts: ' + Account.count.to_s
  puts 'Transactions: ' + Transaction.count.to_s
"
```

### 2. Stop Production Application

```bash
# Find and kill the production Rails process
ps aux | grep "rails server -e production"

# Kill it (replace PID with actual process ID)
kill <PID>

# Verify it's stopped
ps aux | grep "rails server -e production"
```

---

## Database Copy Process

### Step 1: Backup Production (Safety Precaution)

Even though production is empty, create a backup:

```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid

# Create backup directory if needed
mkdir -p ~/backups/nextgen-plaid

# Backup production databases (will be empty but good practice)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  -f ~/backups/nextgen-plaid/nextgen_plaid_production_${TIMESTAMP}.dump \
  nextgen_plaid_production

/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  -f ~/backups/nextgen-plaid/nextgen_plaid_production_queue_${TIMESTAMP}.dump \
  nextgen_plaid_production_queue

/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  -f ~/backups/nextgen-plaid/nextgen_plaid_production_cache_${TIMESTAMP}.dump \
  nextgen_plaid_production_cache

/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  -f ~/backups/nextgen-plaid/nextgen_plaid_production_cable_${TIMESTAMP}.dump \
  nextgen_plaid_production_cable

echo "Backup timestamp: ${TIMESTAMP}"
```

### Step 2: Copy Development → Production

**Method A: Using pg_dump and pg_restore (RECOMMENDED)**

```bash
ssh ericsmith66@192.168.4.253

# Get database password from .env or Keychain
DB_PASS=$(grep DATABASE_PASSWORD ~/Development/nextgen-plaid/.env.production | cut -d '=' -f2)

# Export for pg commands
export PGPASSWORD="${DB_PASS}"

# Copy main database
echo "Copying main database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  nextgen_plaid_development | \
/opt/homebrew/bin/pg_restore \
  -U nextgen_plaid \
  -d nextgen_plaid_production \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl

# Copy queue database
echo "Copying queue database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  nextgen_plaid_development_queue | \
/opt/homebrew/bin/pg_restore \
  -U nextgen_plaid \
  -d nextgen_plaid_production_queue \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl

# Copy cache database
echo "Copying cache database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  nextgen_plaid_development_cache | \
/opt/homebrew/bin/pg_restore \
  -U nextgen_plaid \
  -d nextgen_plaid_production_cache \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl

# Copy cable database
echo "Copying cable database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  -Fc \
  nextgen_plaid_development_cable | \
/opt/homebrew/bin/pg_restore \
  -U nextgen_plaid \
  -d nextgen_plaid_production_cable \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl

# Clear password from environment
unset PGPASSWORD

echo "✅ Database copy complete!"
```

**Method B: Using SQL dump (Alternative if Method A has issues)**

```bash
ssh ericsmith66@192.168.4.253

# Get database password
DB_PASS=$(grep DATABASE_PASSWORD ~/Development/nextgen-plaid/.env.production | cut -d '=' -f2)
export PGPASSWORD="${DB_PASS}"

# Copy main database
echo "Copying main database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  nextgen_plaid_development | \
/opt/homebrew/bin/psql \
  -U nextgen_plaid \
  -d nextgen_plaid_production

# Copy queue database
echo "Copying queue database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  nextgen_plaid_development_queue | \
/opt/homebrew/bin/psql \
  -U nextgen_plaid \
  -d nextgen_plaid_production_queue

# Copy cache database
echo "Copying cache database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  nextgen_plaid_development_cache | \
/opt/homebrew/bin/psql \
  -U nextgen_plaid \
  -d nextgen_plaid_production_cache

# Copy cable database
echo "Copying cable database..."
/opt/homebrew/bin/pg_dump \
  -U nextgen_plaid \
  nextgen_plaid_development_cable | \
/opt/homebrew/bin/psql \
  -U nextgen_plaid \
  -d nextgen_plaid_production_cable

unset PGPASSWORD

echo "✅ Database copy complete!"
```

### Step 3: Verify Data Was Copied

```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid
source ~/.zprofile
eval "$(rbenv init -)"

# Check production now has data
RAILS_ENV=production bundle exec rails runner "
  puts '=== Production Database After Copy ==='
  puts 'Users: ' + User.count.to_s
  puts 'Plaid Items: ' + PlaidItem.count.to_s
  puts 'Accounts: ' + Account.count.to_s
  puts 'Transactions: ' + Transaction.count.to_s
  puts 'Holdings: ' + Holding.count.to_s
  
  if User.count > 0
    puts ''
    puts 'Sample User:'
    user = User.first
    puts \"  Email: #{user.email}\"
    puts \"  Created: #{user.created_at}\"
  end
"
```

---

## Post-Copy Actions

### 1. Start Production Application

```bash
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid
source ~/.zprofile
eval "$(rbenv init -)"

# Start in background
nohup bundle exec rails server -e production -p 3000 > log/production.log 2>&1 &

# Get the PID
echo $! > tmp/pids/server.pid

# Verify it started
tail -f log/production.log
```

### 2. Test Application

```bash
# Health check (from your dev machine or server)
curl http://192.168.4.253:3000/admin/health

# Try accessing login page
curl -I http://192.168.4.253:3000/users/sign_in
```

### 3. Test Login

Try logging in with a user account from your development database.

---

## Troubleshooting

### Issue: "permission denied" during pg_restore

**Cause:** User doesn't have DROP privileges

**Solution:** Add `--no-owner --no-acl` flags (already in commands above)

### Issue: "database is being accessed by other users"

**Cause:** Rails is still connected to the database

**Solution:**
```bash
# Kill all connections to production database
/opt/homebrew/bin/psql -U nextgen_plaid -d postgres -c "
  SELECT pg_terminate_backend(pid) 
  FROM pg_stat_activity 
  WHERE datname = 'nextgen_plaid_production' 
    AND pid <> pg_backend_pid();
"
```

### Issue: Foreign key constraint errors

**Cause:** Data inconsistencies or order of operations

**Solution:** Use `--clean --if-exists` flags (already in commands above)

---

## Rollback (If Something Goes Wrong)

If the copy fails or produces bad results:

```bash
ssh ericsmith66@192.168.4.253

# Find your backup timestamp
ls -lh ~/backups/nextgen-plaid/

# Restore from backup
TIMESTAMP=20260222_HHMMSS  # Replace with actual timestamp

DB_PASS=$(grep DATABASE_PASSWORD ~/Development/nextgen-plaid/.env.production | cut -d '=' -f2)
export PGPASSWORD="${DB_PASS}"

# Stop application first
ps aux | grep "rails server -e production" | grep -v grep | awk '{print $2}' | xargs kill

# Drop and recreate databases
/opt/homebrew/bin/psql -U nextgen_plaid -d postgres -c "
  DROP DATABASE IF EXISTS nextgen_plaid_production;
  CREATE DATABASE nextgen_plaid_production OWNER nextgen_plaid;
"

# Restore
/opt/homebrew/bin/pg_restore \
  -U nextgen_plaid \
  -d nextgen_plaid_production \
  ~/backups/nextgen-plaid/nextgen_plaid_production_${TIMESTAMP}.dump

unset PGPASSWORD
```

---

## Summary Checklist

- [ ] Verified development database has correct data
- [ ] Verified production database is empty
- [ ] Stopped production application
- [ ] Created backup of production (even if empty)
- [ ] Copied development → production (all 4 databases)
- [ ] Verified data in production databases
- [ ] Started production application
- [ ] Tested health check endpoint
- [ ] Tested user login
- [ ] Monitored logs for errors

---

## Expected Results

**Before Copy:**
- Production databases: 0 users, 0 accounts, 0 transactions
- Development databases: XXX users, XXX accounts, XXX transactions

**After Copy:**
- Production databases: XXX users, XXX accounts, XXX transactions (matches development)
- Application runs successfully with production data

---

**Document Created:** February 22, 2026  
**Next Review:** After successful database copy
