# Overwatch Deployment Instructions - Epic-7 Fixes

**From:** Eric  
**To:** Overwatch Agent  
**Project:** nextgen-plaid  
**Target:** Production server 192.168.4.253  

---

## 🎯 **What to Tell Overwatch:**

```
Deploy Epic-7 fixes to nextgen-plaid production (192.168.4.253).

Commit: 665b072
Branch: main
Project: nextgen-plaid
Server: 192.168.4.253
User: ericsmith66
App Path: /Users/ericsmith66/Development/nextgen-plaid

Steps:
1. Pull latest code from main branch
2. Run asset precompilation (RAILS_ENV=production)
3. Restart Puma gracefully
4. Verify charts render on dashboard
5. Verify investment transactions show (should be 10,485)
6. Verify credit transactions show (should be 1,749)

Reference: README_DEPLOYMENT.md in repository root
```

---

## 📋 **Detailed Instructions for Overwatch:**

### **Context:**
```
This deployment fixes 11 bugs from Epic-7, including:
- Chart.js import error (BUG-7-001)
- Empty investment transactions (BUG-7-004) - already backfilled
- Empty credit transactions (BUG-7-005) - already backfilled
- Redundant UI elements (BUG-7-008)

The STI backfill already ran successfully in production today.
This deployment only needs to push code changes.
```

### **Server Details:**
```
Host: 192.168.4.253
Hostname: nextgen
User: ericsmith66
App Directory: /Users/ericsmith66/Development/nextgen-plaid
Rails Environment: production
Web Server: Puma (port 3000)
Process: puma 7.1.0 (tcp://0.0.0.0:3000) [nextgen-plaid]
```

### **Deployment Commands:**
```bash
# Connect
ssh ericsmith66@192.168.4.253

# Navigate to app
cd /Users/ericsmith66/Development/nextgen-plaid

# Pull latest code
git pull origin main

# Precompile assets (critical for Chart.js fix)
RAILS_ENV=production bin/rails assets:precompile

# Restart Puma gracefully
kill -USR2 $(cat tmp/pids/puma.pid)

# Verify Puma restarted
ps aux | grep puma | grep nextgen-plaid
```

### **Verification Steps:**
```bash
# 1. Check transaction counts
RAILS_ENV=production bin/rails runner "
  puts 'InvestmentTransaction: ' + InvestmentTransaction.count.to_s + ' (expect 10485)'
  puts 'CreditTransaction: ' + CreditTransaction.count.to_s + ' (expect 1749)'
  puts 'RegularTransaction: ' + RegularTransaction.count.to_s + ' (expect ~1092)'
"

# 2. Test URLs in browser
# http://192.168.4.253:3000/net_worth/dashboard (charts should render)
# http://192.168.4.253:3000/transactions/investment (should show 10,485 transactions)
# http://192.168.4.253:3000/transactions/credit (should show 1,749 transactions)
```

### **Expected Results:**
```
✅ git pull: Shows 16 files changed, 2769 insertions
✅ assets:precompile: Completes without errors
✅ Puma restart: Process restarts successfully
✅ Transaction counts: Match expected values
✅ Dashboard: Charts render without JavaScript errors
✅ Investment view: Shows transactions with pagination
✅ Credit view: Shows transactions with pagination
```

### **Files Changed in This Deployment:**
```
Modified (4 files):
  app/views/layouts/application.html.erb
  app/javascript/application.js
  config/importmap.rb
  app/components/transactions/filter_bar_component.rb

New (11 files):
  lib/tasks/debug_transactions.rake
  lib/tasks/backfill_sti.rake
  DEPLOY_TO_PRODUCTION.md
  EPIC_7_DEPLOYMENT_GUIDE.md
  EPIC_7_IMPLEMENTATION_SUMMARY.md
  PRODUCTION_VALIDATION_RESULTS.md
  QUICK_START.md
  README_DEPLOYMENT.md
  validate_investments_prod.rb
  validate_production_investments.sh
  (+ 2 snapshot scripts)
```

### **Critical Notes:**
```
⚠️ IMPORTANT:
1. Asset precompilation is REQUIRED (Chart.js fix won't work without it)
2. Database backfill already complete - no database changes needed
3. If Puma won't restart gracefully, use: pkill -USR2 -f "puma.*nextgen-plaid"
4. Charts require CDN access to: cdn.jsdelivr.net
```

### **Rollback Plan (If Needed):**
```bash
cd /Users/ericsmith66/Development/nextgen-plaid
git revert 665b072
git push origin main
# Then pull on production and restart
```

### **Success Criteria:**
```
✅ No errors during deployment
✅ Puma running and responding
✅ Charts visible on dashboard (no JavaScript errors)
✅ InvestmentTransaction count: 10,485
✅ CreditTransaction count: 1,749
✅ /transactions/investment shows data
✅ /transactions/credit shows data
✅ Pagination works on all views
```

### **Troubleshooting:**
```
If charts don't render:
  - Check browser console for JavaScript errors
  - Verify CDN is accessible: curl -I https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js
  - Check page source for script tag before importmap

If transactions disappear:
  - Run: RAILS_ENV=production bin/rails transactions:debug_sync
  - Transaction data is safe in database (backfill already complete)
  - Likely a code issue that can be rolled back

If Puma won't restart:
  - Check logs: tail -f log/production.log
  - Force restart: pkill -9 <PID> && RAILS_ENV=production bin/rails server -p 3000 -d
```

---

## 🤖 **Copy-Paste for Overwatch:**

```
Hey Overwatch,

Please deploy Epic-7 fixes to nextgen-plaid production.

Server: 192.168.4.253
User: ericsmith66
Path: /Users/ericsmith66/Development/nextgen-plaid
Branch: main
Commit: 665b072

Commands:
1. ssh ericsmith66@192.168.4.253
2. cd /Users/ericsmith66/Development/nextgen-plaid
3. git pull origin main
4. RAILS_ENV=production bin/rails assets:precompile
5. kill -USR2 $(cat tmp/pids/puma.pid)

Verify:
- Charts render at: http://192.168.4.253:3000/net_worth/dashboard
- Investment transactions: http://192.168.4.253:3000/transactions/investment
- Should show 10,485 investment transactions

Critical: Asset precompilation is required for Chart.js fix to work.

Reference docs in repo:
- README_DEPLOYMENT.md (quick overview)
- DEPLOY_TO_PRODUCTION.md (detailed steps)
- QUICK_START.md (commands)

The database backfill already ran successfully today - no DB changes needed.

Questions? See EPIC_7_DEPLOYMENT_GUIDE.md for full troubleshooting.
```

---

## 📞 **If Overwatch Asks Questions:**

### Q: "Do I need to run any migrations?"
**A:** No, the database backfill already ran successfully. Just code deployment.

### Q: "What about the backfill_sti task?"
**A:** Already completed manually in production today. The rake task is included as a tool for future use only.

### Q: "Should I restart Sidekiq/background jobs?"
**A:** Not necessary for this deployment. Only Puma needs restart.

### Q: "What if asset precompilation fails?"
**A:** Check Node.js is available (`node --version`). Try cleaning first: `RAILS_ENV=production bin/rails assets:clobber` then retry.

### Q: "Charts still don't show after deploy?"
**A:** 
1. Check browser console for errors (F12)
2. Verify script tag in page source: `<script src="https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js"></script>`
3. Test CDN: `curl -I https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js`

### Q: "Investment transactions show 0 after deploy?"
**A:** Don't panic! Run: `RAILS_ENV=production bin/rails runner "puts InvestmentTransaction.count"`. Should show 10485. If it does, it's a UI issue, not data loss. Check for JavaScript errors.

---

## ✅ **Post-Deployment Report Request:**

Ask Overwatch to provide:
```
1. Deployment status (success/failure)
2. Any errors encountered
3. Screenshot or confirmation that:
   - Dashboard charts render
   - Investment view shows transactions
   - Credit view shows transactions
4. Transaction counts from database
5. Any warnings or concerns
```

---

## 🎯 **TL;DR for Overwatch:**

```
What: Deploy Epic-7 bug fixes
Where: 192.168.4.253:/Users/ericsmith66/Development/nextgen-plaid
How: git pull + asset precompile + Puma restart
Why: Fix charts, enable 10,485 investment + 1,749 credit transactions
Risk: Low (backfill already done, code changes only)
Time: 10-15 minutes
Docs: README_DEPLOYMENT.md in repo
```

---

**That's everything Overwatch needs to know!** 🚀
