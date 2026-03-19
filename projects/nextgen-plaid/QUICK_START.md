# Epic-7 Bug Squash: Quick Start Guide

**For the impatient developer who just wants to know what to do next.**

---

## TL;DR

✅ **Code changes complete** - Chart.js fixed, cleanup done  
⚠️ **Manual steps required** - Run diagnostic and backfill tasks  
📋 **Testing needed** - 20-point checklist in deployment guide  

---

## Deploy in 5 Steps

### 1. Deploy Code (2 minutes)
```bash
git pull origin main
bundle install
rails assets:precompile
# Restart app (systemctl/passenger/etc.)
```

### 2. Verify Charts Work (30 seconds)
Open `/net_worth/dashboard` in browser:
- Charts should render (no "Loading..." stuck)
- No JavaScript errors in console
- Pie/bar toggle works

**If broken:** See rollback section in `EPIC_7_DEPLOYMENT_GUIDE.md`

### 3. Run Diagnostic (1 minute)
```bash
rails transactions:debug_sync
```

**Look for:**
- ✅ Latest transaction date is recent (< 48 hours)
- ✅ InvestmentTransaction count > 0 (if you have investment accounts)
- ✅ Transfer count > 0

### 4. Backfill STI Types (if needed) (2-5 minutes)
**Only run if diagnostic shows:**
- `InvestmentTransaction: 0` but `From investment accounts: >0`

```bash
rails transactions:backfill_sti
```

**Expected:** "Updated: X transactions, Errors: 0"

### 5. Spot Check (2 minutes)
Visit these URLs and verify data appears:
- `/transactions/regular` ✓
- `/transactions/investment` ✓
- `/transactions/credit` ✓
- `/transactions/transfers` ✓
- `/transactions/summary` ✓

---

## What If...

### Charts don't render?
```javascript
// Open browser console, type:
window.Chart
window.Chartkick

// Should both return objects, not undefined
```

**If undefined:** Chart.js didn't load. Check script tag in layout.  
**Rollback:** See `EPIC_7_DEPLOYMENT_GUIDE.md` section "Rollback Plan"

### Investment transactions still empty after backfill?
```bash
# Check if investment accounts exist
rails runner "puts Account.where(plaid_account_type: 'investment').count"
```

**If 0:** No investment accounts linked (expected)  
**If > 0:** Check Plaid sync status with diagnostic task

### No transfers appear?
```bash
# Check raw count
rails runner "puts Transaction.where('personal_finance_category_label ILIKE ?', 'TRANSFER%').count"
```

**If 0:** Plaid may not be labeling them correctly. See troubleshooting in deployment guide.  
**If > 0:** Filter may be excluding them. Check data provider logic.

### Transaction data is stale (last sync > 48 hours ago)?
```bash
# Check sync job status
rails runner "puts SyncLog.where(job_type: 'sync_transactions').last.inspect"

# Manually trigger sync
rails runner "SyncTransactionsJob.perform_now"
```

---

## Files You Changed

**Modified (4):**
- `app/views/layouts/application.html.erb` - Added Chart.js script tag
- `app/javascript/application.js` - Removed Chart.js import
- `config/importmap.rb` - Commented out Chart.js pin
- `app/components/transactions/filter_bar_component.rb` - Cleaned up unused code

**Created (2):**
- `lib/tasks/debug_transactions.rake` - Diagnostic tool
- `lib/tasks/backfill_sti.rake` - STI type fixer

---

## Full Regression Test

**Copy this checklist and run through it:**

```
□ Dashboard charts render
□ Sector charts render
□ Chart toggle works
□ Regular transactions page loads
□ Pagination works (click Next)
□ Date filters show current month
□ Investment transactions show (if applicable)
□ Credit transactions show (if applicable)
□ Transfers show
□ Transfer badges (Internal/External) correct
□ Summary page has filter bar
□ No "Type" dropdown anywhere
```

**If all checked:** ✅ Deployment successful  
**If any fail:** See `EPIC_7_DEPLOYMENT_GUIDE.md` for troubleshooting

---

## Need Help?

**Documents:**
1. `EPIC_7_DEPLOYMENT_GUIDE.md` - Full playbook with troubleshooting
2. `EPIC_7_IMPLEMENTATION_SUMMARY.md` - What changed and why
3. `knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/squash-bug-plan.md` - Original plan

**Diagnostic Commands:**
```bash
rails transactions:debug_sync        # See everything
rails transactions:backfill_sti      # Fix investment/credit types
rails runner "puts Transaction.maximum(:date)"  # Check latest sync
```

**Emergency Rollback:**
```bash
git revert <commit_hash>
git push origin main
# Redeploy
```

---

## Success Criteria

🎯 **Charts render** - No JavaScript errors  
🎯 **All transaction views show data** - Investment, credit, transfers, regular  
🎯 **Pagination works** - Page 2+ shows data  
🎯 **Date filters work** - Default to current month  

**All good?** You're done! 🎉

**Issues?** Read the deployment guide for detailed troubleshooting.
