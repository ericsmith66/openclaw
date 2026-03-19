# Epic-7 Bug Squash Deployment Guide

**Date:** 2026-02-25  
**Status:** Ready for Deployment  
**Related Epic:** Epic-7 Transaction UI Bug Fixes

## Summary of Changes

This deployment addresses 11 of 13 bugs identified in the Epic-7 bug squash plan:

### ✅ **Completed Fixes**

1. **BUG-7-001 (P0):** Chart.js import error - Fixed by loading Chart.js via script tag
2. **BUG-7-002 (P1):** Pagination - Already fixed (no double-slicing present)
3. **BUG-7-003 (P1):** Date defaults - Already implemented via `DefaultDateRange` concern
4. **BUG-7-006 (P1):** Summary cards respect filters - Already functional
5. **BUG-7-007 (P2):** Filters on summary page - Already present
6. **BUG-7-008 (P2):** Redundant type filter - Removed and cleaned up
7. **BUG-7-009 (P1):** Transfer classification - Already implemented via TransferDeduplicator
8. **BUG-7-010 (P1):** Transfer summary cards - Already using TransferSummaryCardComponent
9. **BUG-7-013 (P2):** Transfer description - Already displayed

### 🔧 **New Diagnostic Tools**

1. **Rake Task:** `rails transactions:debug_sync` - Comprehensive sync status report
2. **Rake Task:** `rails transactions:backfill_sti` - Fix STI type assignments

### ⚠️ **Remaining Manual Tasks**

1. **BUG-7-004/005 (P1):** Investment/Credit transactions empty - Run STI backfill after deployment
2. **BUG-7-011 (P0):** Missing transfers - Investigate with debug_sync task
3. **BUG-7-012 (P0):** Stale transaction data - Verify sync jobs are running

---

## Files Changed

### Modified Files
```
app/views/layouts/application.html.erb
app/javascript/application.js
config/importmap.rb
app/components/transactions/filter_bar_component.rb
```

### New Files
```
lib/tasks/debug_transactions.rake
lib/tasks/backfill_sti.rake
```

### Already Implemented (No Changes Needed)
```
app/controllers/concerns/default_date_range.rb
app/controllers/transactions_controller.rb
app/components/transactions/grid_component.rb
app/components/transactions/grid_component.html.erb
app/components/transactions/row_component.rb
app/components/transactions/row_component.html.erb
app/components/transactions/transfer_summary_card_component.rb
app/components/transactions/transfer_summary_card_component.html.erb
app/views/transactions/summary.html.erb
app/views/transactions/_summary_content.html.erb
app/views/transactions/transfers.html.erb
app/services/transfer_deduplicator.rb
```

---

## Pre-Deployment Checklist

- [ ] All tests pass locally
- [ ] Asset precompilation succeeds
- [ ] Chart.js loads in production environment
- [ ] Database has recent backup
- [ ] Rollback plan documented

---

## Deployment Steps

### 1. Deploy Code Changes

```bash
# Pull latest changes
git pull origin main

# Install dependencies (if needed)
bundle install

# Precompile assets
rails assets:precompile

# Restart application
# (Method depends on your deployment: systemctl, passenger, etc.)
```

### 2. Verify Chart.js Loading

Open any page with charts (`/net_worth/dashboard`) and verify:
```javascript
// In browser console
window.Chart // Should return Chart.js constructor
window.Chartkick // Should return Chartkick object
```

**Expected Result:** No JavaScript errors, charts render correctly

### 3. Run Diagnostic Report

```bash
rails transactions:debug_sync
```

**Review Output:**
- Latest transaction date (should be recent)
- STI type counts (InvestmentTransaction, CreditTransaction counts)
- Transfer transaction counts
- Plaid item status
- Sync log status

### 4. Backfill STI Types (If Needed)

**Run ONLY if diagnostic shows:**
- `InvestmentTransaction: 0` but `From investment accounts: >0`
- `CreditTransaction: 0` but `From credit accounts: >0`

```bash
rails transactions:backfill_sti
```

**Expected Output:**
```
Updated: X transactions
Skipped: Y transactions
Errors: 0
```

### 5. Verify Investment/Credit Views

Visit:
- `/transactions/investment` - Should show investment transactions
- `/transactions/credit` - Should show credit transactions

**If still empty after backfill:**
- Check if investment/credit accounts exist: `rails console`
  ```ruby
  Account.where(plaid_account_type: ['investment', 'credit']).count
  ```
- Review Plaid sync configuration
- Check transaction sync logs for errors

### 6. Verify Transfer Detection

Visit `/transactions/transfers`

**Expected:**
- Transfers appear (check count in diagnostic report)
- Internal transfers show "Internal" badge
- External transfers show "External" badge
- Transfer details show From → To with arrows

**If no transfers appear:**
```bash
# Check if transfers exist with different labels
rails runner "
  puts Transaction.distinct.pluck(:personal_finance_category_label).compact.grep(/transfer/i)
"
```

### 7. Verify Sync Status (BUG-7-012)

**Check latest sync:**
```bash
rails runner "
  puts 'Latest transaction: ' + Transaction.maximum(:date).to_s
  puts 'Expected: within last 24-48 hours'
"
```

**If stale:**
- Check sync job scheduler (Solid Queue, Sidekiq, cron)
- Manually trigger sync via Mission Control or:
  ```bash
  rails runner "SyncTransactionsJob.perform_now"
  ```
- Review Plaid item status for errors

---

## Post-Deployment Verification

### Regression Test Checklist

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1 | Visit `/net_worth/dashboard` | Charts render, no JS errors | ⬜ |
| 2 | Visit `/net_worth/sectors` | Sector chart renders | ⬜ |
| 3 | Toggle pie ↔ bar on allocation chart | Charts switch | ⬜ |
| 4 | Visit `/transactions/regular` | Shows current month's cash transactions | ⬜ |
| 5 | Click "Next" on page 1 | Page 2 shows transactions | ⬜ |
| 6 | Date filters pre-populated | Current month filled in | ⬜ |
| 7 | Change date range, click Apply | Table updates | ⬜ |
| 8 | Click "Clear" | Resets to current month | ⬜ |
| 9 | Visit `/transactions/investment` | Shows investment transactions | ⬜ |
| 10 | Visit `/transactions/credit` | Shows credit transactions | ⬜ |
| 11 | Visit `/transactions/transfers` | Shows transfers | ⬜ |
| 12 | Transfer summary cards | Show Inflows/Outflows/Internal | ⬜ |
| 13 | Transfer rows | Show Internal/External badges | ⬜ |
| 14 | Transfer rows | Show Description column | ⬜ |
| 15 | Visit `/transactions/summary` | Filter bar present | ⬜ |
| 16 | Change dates on summary | Cards update | ⬜ |
| 17 | No "Type" dropdown in filter bar | Removed from all views | ⬜ |
| 18 | Recent transaction date | Within last 24-48 hours | ⬜ |
| 19 | Turbo navigation between tabs | No broken state | ⬜ |
| 20 | Charts redraw after Turbo | Charts visible after navigation | ⬜ |

---

## Rollback Plan

### If Charts Break
```bash
# Revert Chart.js changes
git revert <commit_hash>
git push origin main
# Redeploy

# OR manual fix in production:
# 1. Remove script tag from app/views/layouts/application.html.erb
# 2. Restore import in app/javascript/application.js
# 3. Restore pin in config/importmap.rb
```

### If STI Backfill Causes Issues
```bash
# Revert types back to RegularTransaction
rails runner "
  Transaction.where(type: ['InvestmentTransaction', 'CreditTransaction'])
             .update_all(type: 'RegularTransaction')
"
```

---

## Known Issues & Workarounds

### Issue: Transfers Still Missing After Deployment
**Potential Causes:**
1. Plaid doesn't label them as "TRANSFER%" in `personal_finance_category_label`
2. Investment account filter is too aggressive
3. TransferDeduplicator is over-filtering

**Workaround:**
```bash
# Check raw transfer data
rails runner "
  count = Transaction.where('personal_finance_category_label ILIKE ?', 'TRANSFER%').count
  puts 'Transfers with TRANSFER% label: ' + count.to_s
"

# If zero, check alternative labels
rails runner "
  Transaction.distinct.pluck(:personal_finance_category_label)
             .compact
             .grep(/transfer|payment|bank/i)
             .each { |l| puts l }
"
```

### Issue: Investment Transactions Still Empty After Backfill
**Potential Causes:**
1. No investment accounts linked
2. Investment accounts not syncing transactions
3. Plaid product not enabled for investments

**Verification:**
```bash
rails runner "
  inv = Account.where(plaid_account_type: 'investment')
  puts 'Investment accounts: ' + inv.count.to_s
  inv.each do |a|
    puts '  ' + a.name + ': ' + a.transactions.count.to_s + ' transactions'
  end
"
```

---

## Support & Troubleshooting

### Get Detailed Transaction Info
```bash
rails runner "
  txn = Transaction.last
  puts 'ID: ' + txn.id.to_s
  puts 'Type: ' + txn.type.to_s
  puts 'Account type: ' + txn.account.plaid_account_type.to_s
  puts 'Category: ' + txn.personal_finance_category_label.to_s
  puts 'Investment fields: ' + [txn.investment_transaction_id, txn.investment_type, txn.security_id].compact.inspect
"
```

### Check Plaid Sync Health
```bash
rails runner "
  PlaidItem.find_each do |item|
    puts item.institution_name
    puts '  Status: ' + item.status.to_s
    puts '  Error: ' + item.error_code.to_s
    puts '  Last sync: ' + item.updated_at.to_s
    puts '  Accounts: ' + item.accounts.count.to_s
    puts '  Transactions: ' + Transaction.joins(account: :plaid_item).where(plaid_items: { id: item.id }).count.to_s
  end
"
```

### Re-trigger Full Sync
```bash
# Careful: This may take time and hit API limits
rails runner "
  PlaidItem.find_each do |item|
    SyncAccountsJob.perform_later(item.id)
    SyncTransactionsJob.perform_later(item.id)
  end
"
```

---

## Success Criteria

Deployment is successful when:

✅ All charts render without JavaScript errors  
✅ Investment transactions appear (if investment accounts exist)  
✅ Credit transactions appear (if credit accounts exist)  
✅ Transfers appear with correct Internal/External badges  
✅ Pagination works on all pages  
✅ Date filters default to current month  
✅ Summary page has filter bar and updates with filters  
✅ No "Type" dropdown in filter bars  
✅ Transaction data is current (within 48 hours)  

---

## Contact

For deployment issues, contact:
- **Engineering Lead:** [Your contact info]
- **On-call:** [On-call contact]
- **Documentation:** `knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/`
