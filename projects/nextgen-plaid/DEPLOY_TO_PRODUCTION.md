# Deploy Epic-7 Fixes to Production (192.168.4.253)

**Target Server:** 192.168.4.253 (nextgen)  
**App Path:** `/Users/ericsmith66/Development/nextgen-plaid`  
**User:** ericsmith66  
**Status:** ✅ STI Backfill Complete, Code Changes Pending  

---

## What's Already Done ✅

- ✅ **Investment/Credit transactions fixed** (10,485 + 1,749 reclassified)
- ✅ **Database is good** - backfill ran successfully
- ✅ **App is running** - Puma on port 3000

---

## What Needs Deployment 📦

### Files to Add/Update on Production

**New Files (2):**
```
lib/tasks/debug_transactions.rake
lib/tasks/backfill_sti.rake
```

**Modified Files (4):**
```
app/views/layouts/application.html.erb
app/javascript/application.js
config/importmap.rb
app/components/transactions/filter_bar_component.rb
```

**Documentation (7):**
```
EPIC_7_DEPLOYMENT_GUIDE.md
EPIC_7_IMPLEMENTATION_SUMMARY.md
PRODUCTION_VALIDATION_RESULTS.md
QUICK_START.md
validate_investments_prod.rb
validate_production_investments.sh
DEPLOY_TO_PRODUCTION.md (this file)
```

---

## Deployment Steps

### Option 1: Git Push/Pull (Recommended)

If your local repo is connected to the production repo:

#### On Your Local Machine:
```bash
# 1. Check current status
git status

# 2. Add all Epic-7 changes
git add -A

# 3. Commit with clear message
git commit -m "Epic-7: Fix chart.js, add diagnostic tools, backfill complete

- Fix Chart.js import error (BUG-7-001) via script tag
- Remove redundant type filter (BUG-7-008)
- Add transaction diagnostic rake tasks
- Add comprehensive deployment documentation
- STI backfill already run in production (10,485 investment + 1,749 credit transactions)

11 of 13 bugs addressed. See PRODUCTION_VALIDATION_RESULTS.md"

# 4. Push to repository
git push origin main
```

#### On Production Server (192.168.4.253):
```bash
# SSH to production
ssh ericsmith66@192.168.4.253

# Navigate to app
cd /Users/ericsmith66/Development/nextgen-plaid

# Pull latest changes
git pull origin main

# Precompile assets (for Chart.js changes)
RAILS_ENV=production bin/rails assets:precompile

# Restart Puma gracefully (preserves connections)
kill -USR2 $(cat tmp/pids/puma.pid)

# Or force restart if needed
pkill -USR2 -f "puma.*nextgen-plaid"

# Verify app is running
ps aux | grep puma | grep nextgen-plaid
```

---

### Option 2: Manual File Copy (If Git Not Available)

If production isn't connected to Git:

#### Copy Files via SCP:
```bash
# From your local machine

# Create temp directory for transfer
mkdir -p /tmp/epic7-deploy

# Copy modified files
cp app/views/layouts/application.html.erb /tmp/epic7-deploy/
cp app/javascript/application.js /tmp/epic7-deploy/
cp config/importmap.rb /tmp/epic7-deploy/
cp app/components/transactions/filter_bar_component.rb /tmp/epic7-deploy/

# Copy new files
cp lib/tasks/debug_transactions.rake /tmp/epic7-deploy/
cp lib/tasks/backfill_sti.rake /tmp/epic7-deploy/

# Copy documentation
cp EPIC_7_*.md /tmp/epic7-deploy/
cp PRODUCTION_VALIDATION_RESULTS.md /tmp/epic7-deploy/
cp QUICK_START.md /tmp/epic7-deploy/

# Transfer to production
scp -r /tmp/epic7-deploy/* ericsmith66@192.168.4.253:/tmp/

# SSH to production
ssh ericsmith66@192.168.4.253

# On production, copy files to correct locations
cd /Users/ericsmith66/Development/nextgen-plaid

# Backup originals first
cp app/views/layouts/application.html.erb app/views/layouts/application.html.erb.backup
cp app/javascript/application.js app/javascript/application.js.backup
cp config/importmap.rb config/importmap.rb.backup
cp app/components/transactions/filter_bar_component.rb app/components/transactions/filter_bar_component.rb.backup

# Copy new files
cp /tmp/debug_transactions.rake lib/tasks/
cp /tmp/backfill_sti.rake lib/tasks/
cp /tmp/application.html.erb app/views/layouts/
cp /tmp/application.js app/javascript/
cp /tmp/importmap.rb config/
cp /tmp/filter_bar_component.rb app/components/transactions/

# Copy docs to root
cp /tmp/*.md ./

# Precompile assets
RAILS_ENV=production bin/rails assets:precompile

# Restart Puma
kill -USR2 $(cat tmp/pids/puma.pid)
```

---

## Verification Steps (5 minutes)

### 1. Verify App Restarted ✅
```bash
# Check Puma is running
ps aux | grep puma | grep nextgen-plaid

# Should see something like:
# ericsmith66  2185  puma 7.1.0 (tcp://0.0.0.0:3000) [nextgen-plaid]
```

### 2. Verify Charts Work ✅
Open in browser: http://192.168.4.253:3000/net_worth/dashboard

**Check:**
- [ ] Asset allocation pie chart renders
- [ ] No JavaScript errors in console (F12)
- [ ] Chart toggle (pie ↔ bar) works
- [ ] Sector charts render

**If charts don't render:**
```bash
# Check browser console for errors
# Should see window.Chart defined
# Type in console: window.Chart
```

### 3. Verify Investment Transactions ✅
Open: http://192.168.4.253:3000/transactions/investment

**Check:**
- [ ] Shows 10,485 transactions (or filtered subset)
- [ ] Pagination works (page 2+)
- [ ] Date filters work
- [ ] No "No transactions found" message

### 4. Verify Credit Transactions ✅
Open: http://192.168.4.253:3000/transactions/credit

**Check:**
- [ ] Shows 1,749 transactions (or filtered subset)
- [ ] Pagination works
- [ ] Cards show correctly

### 5. Verify Regular Transactions ✅
Open: http://192.168.4.253:3000/transactions/regular

**Check:**
- [ ] Shows ~1,092 cash/checking transactions
- [ ] Date filters default to current month
- [ ] No "Type" dropdown in filter bar (removed)

### 6. Test Diagnostic Tasks ✅
```bash
cd /Users/ericsmith66/Development/nextgen-plaid

# Run diagnostic
RAILS_ENV=production bin/rails transactions:debug_sync

# Should show:
# - InvestmentTransaction: 10485
# - CreditTransaction: 1749
# - Latest transaction date
```

---

## Expected Results

After deployment:

✅ **Charts render** - Dashboard shows pie/bar charts  
✅ **Investment view populated** - 10,485 transactions  
✅ **Credit view populated** - 1,749 transactions  
✅ **Pagination works** - Can navigate through pages  
✅ **Date filters work** - Default to current month  
✅ **No type dropdown** - Cleaner UI  
✅ **Diagnostic tasks available** - Can troubleshoot easily  

---

## Rollback Plan (If Needed)

### If Charts Break:
```bash
cd /Users/ericsmith66/Development/nextgen-plaid

# Restore backups
cp app/views/layouts/application.html.erb.backup app/views/layouts/application.html.erb
cp app/javascript/application.js.backup app/javascript/application.js
cp config/importmap.rb.backup config/importmap.rb

# Recompile
RAILS_ENV=production bin/rails assets:precompile

# Restart
kill -USR2 $(cat tmp/pids/puma.pid)
```

### If Investment/Credit Views Break:
**Don't worry!** The data is already fixed. The views breaking would mean a code issue, not data.

```bash
# Check if data is still good
RAILS_ENV=production bin/rails runner "puts InvestmentTransaction.count"
# Should still show 10485
```

---

## Troubleshooting

### Chart.js Not Loading
**Symptoms:** Charts show "Loading..." forever

**Check:**
```bash
# View page source, find this line:
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js"></script>

# Open browser console, type:
window.Chart

# Should return Chart.js object, not undefined
```

**Fix:** Clear browser cache or check CDN accessibility

### Assets Not Compiling
**Symptoms:** Error during `rails assets:precompile`

**Check:**
```bash
# Check Node.js is available
node --version

# Check disk space
df -h

# Try cleaning first
RAILS_ENV=production bin/rails assets:clobber
RAILS_ENV=production bin/rails assets:precompile
```

### Puma Won't Restart
**Symptoms:** `kill -USR2` doesn't work

**Force restart:**
```bash
# Find PID
ps aux | grep puma | grep nextgen-plaid

# Kill gracefully
kill -TERM <PID>

# Wait 5 seconds, then check
ps aux | grep puma | grep nextgen-plaid

# If still running, force kill
kill -9 <PID>

# Start Puma (adjust command to match your setup)
cd /Users/ericsmith66/Development/nextgen-plaid
RAILS_ENV=production bin/rails server -p 3000 -d
```

---

## Post-Deployment Tasks

### 1. Monitor Logs
```bash
cd /Users/ericsmith66/Development/nextgen-plaid

# Watch production logs
tail -f log/production.log

# Look for:
# - No JavaScript errors
# - Successful page loads
# - No 500 errors
```

### 2. Run Full Regression Test
Use the 20-point checklist in `EPIC_7_DEPLOYMENT_GUIDE.md`

### 3. Investigate Remaining Issues

**BUG-7-011: Missing Transfers**
```bash
RAILS_ENV=production bin/rails runner "
  puts Transaction.where('personal_finance_category_label ILIKE ?', 'TRANSFER%').count
"
```

**BUG-7-012: Stale Sync**
```bash
RAILS_ENV=production bin/rails runner "
  puts 'Latest: ' + Transaction.maximum(:date).to_s
  puts 'Today: ' + Date.current.to_s
"
```

---

## Timeline

**Estimated Time:** 15-30 minutes

- Git pull/push: 2 minutes
- Asset precompilation: 3-5 minutes
- Puma restart: 1 minute
- Verification: 5-10 minutes
- Testing: 5-10 minutes

---

## Success Criteria

✅ All checks pass in Verification Steps  
✅ No errors in logs  
✅ Charts render on dashboard  
✅ Investment/credit/regular views show data  
✅ Pagination works  
✅ No user-facing errors  

---

## Need Help?

**Reference Documentation:**
- `QUICK_START.md` - Quick commands
- `EPIC_7_DEPLOYMENT_GUIDE.md` - Detailed guide
- `PRODUCTION_VALIDATION_RESULTS.md` - What we fixed

**Key Commands:**
```bash
# Check app status
ps aux | grep puma | grep nextgen-plaid

# Check transaction counts
RAILS_ENV=production bin/rails runner "
  puts \"Investment: #{InvestmentTransaction.count}\"
  puts \"Credit: #{CreditTransaction.count}\"
  puts \"Regular: #{RegularTransaction.count}\"
"

# Restart app
kill -USR2 $(cat tmp/pids/puma.pid)

# View logs
tail -f log/production.log
```

---

## Final Notes

1. **STI Backfill Already Complete** ✅ - No database changes needed
2. **Changes Are Low Risk** ✅ - Mostly UI improvements and bug fixes
3. **Easy Rollback** ✅ - Backups created, can revert quickly
4. **Production Tested** ✅ - Backfill ran successfully with 0 errors

**You're ready to deploy!** 🚀
