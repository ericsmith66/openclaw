# Epic 6-01 Missing Features Analysis & Remediation Plan

**Date:** February 17, 2026  
**Analysis By:** AiderDesk  
**Status:** Ready for Implementation  
**Updated:** February 17, 2026 - Corrected filter bar interpretation per original feedback (Option A: filter above stats, account next to search). Added Summary card & sidebar issues.

---

## Quick Summary

**Total Missing Features:** 7 critical + 3 partial + 1 BLOCKER  
**Implementation Status:** ~55% complete  
**Estimated Fix Time:** 5.5-7 hours total

### 🚨 BLOCKER FOUND:
**Root Cause:** `config/mock_transactions/cash.yml` is empty (contains only `transactions: []`)

**Immediate Fix Required:** Populate cash.yml with 20-30 mock transactions (~30 min)

### BLOCKER Issues:
1. 🔴 **BLOCKER: Empty cash.yml** - Cash view shows "No transactions found" because YAML file has no data

### Critical Issues Found:
2. ❌ **Sidebar Navigation Still Nested** - "Transactions" parent menu-title not removed
3. ❌ **Account Filter Not Next to Search** - Should be "immediately right of Search input", currently separate grid column
4. ❌ **Summary View Missing** - No "Top 5 Recurring Expenses" card (code exists, `@top_recurring` empty — blocked by empty cash.yml)
5. ❌ **Investments View** - Merchant column still showing (not removed)
6. ❌ **Transfers View** - Merchant column still showing (not removed)
7. ❌ **Transfers View** - Table structure incorrect (too many columns: should be Date | Type | From→To | Amount)
8. ⚠️ **Credit View** - Pending badge needs verification

---

## Executive Summary

After reviewing the implementation of PRD-6-01 (Transaction Views UI Polish) against the original feedback document (`UI-Mocks-feedback.md`) and actual HTML output, I've identified **7 critical missing features** and **3 partial implementations** that need to be completed. The implemented work successfully covers approximately 55% of the requested feedback, with the remaining 45% requiring targeted fixes.

**Key Findings:**
1. **Account Filter Mispositioned** - Should be "immediately right of the Search input" per feedback; currently a separate grid column
2. **Summary View Missing Card** - Top 5 Recurring Expenses card not displaying (code exists but `@top_recurring` is empty/nil — likely because cash.yml has no data for recurring detection)
3. **Data Blocker** - cash.yml is empty (`transactions: []`), preventing Cash view testing AND blocking recurring detection for Summary view

---

## ✅ Successfully Implemented Features

### Global Changes
1. ❌ **Sidebar Navigation** - STILL NESTED - Shows "Transactions" menu-title parent (see Missing Feature #7)
2. ✅ **Page Titles / Breadcrumbs** - Clean multi-level breadcrumbs implemented (`Home > Transactions > [Subtype]`)
3. ✅ **Filter Bar Placement** - Filter bar IS above stats (correct per feedback). Sticky positioning applied (`sticky top-0 z-10`). View order: Tabs → Filter → Stats → Grid ✓
4. ⚠️ **Account Filter** - Account dropdown exists but NOT "immediately right of the Search input". Currently it's a separate column in the grid. Needs to be repositioned directly next to Search (see Missing Feature #1)
5. ✅ **Search Placeholder** - Dynamic per view (implemented in `FilterBarComponent`)
6. ✅ **Recurring Detection** - `TransactionRecurringDetector` fully implemented with heuristic logic

### View-Specific Features
7. ✅ **Cash View** - Recurring badge ("RR") implemented
8. ✅ **Investments View** - Account column added after Date, made prominent/bold
9. ✅ **Investments View** - Security icon/logo (letter avatar) implemented
10. ✅ **Investments View** - Security name clickable with stub link
11. ✅ **Investments View** - All columns sortable (Date, Account, Security, Quantity, Price, Amount)
12. ✅ **Credit View** - Recurring badge ("RR") implemented
13. ✅ **Credit View** - Merchant icon/logo (letter avatar) implemented
14. ✅ **Transfers View** - Deduplication implemented (show only source leg)
15. ✅ **Transfers View** - Direction arrow (green inbound/red outbound)
16. ✅ **Transfers View** - External/Internal badge
17. ❌ **Summary View** - NO Top 5 Recurring Expenses card (see Missing Feature #3)

---

## 🔴 BLOCKER Issue

### 0. Mock Data Not Loading (CRITICAL BLOCKER)
**Observed Behavior:**
All transaction views (Cash, Investments, Credit, Transfers) show "No transactions found" empty state.

**Evidence from HTML:**
```html
<div class="stat-value">0</div>  <!-- Total Transactions -->
<turbo-frame id="transactions_grid">
  <div class="card bg-base-100 shadow">
    <div class="card-body">
      <div class="font-medium">No transactions found</div>
      <div class="text-sm opacity-80">Try adjusting filters.</div>
    </div>
  </div>
</turbo-frame>
```

**Root Cause IDENTIFIED:**
The file `config/mock_transactions/cash.yml` exists but contains **NO DATA** (only `transactions: []`).

**File Status:**
- ✅ `config/mock_transactions/cash.yml` - EXISTS but EMPTY (2 lines: `---` and `transactions: []`)
- ✅ `config/mock_transactions/credit.yml` - EXISTS with data (29 lines)
- ✅ `config/mock_transactions/investments.yml` - EXISTS with data (31 lines)
- ✅ `config/mock_transactions/transfers.yml` - EXISTS with data (23 lines)
- ✅ `config/mock_transactions/summary.yml` - EXISTS with data (24 lines)

**Confirmed Issue:**
Cash view is the ONLY view with an empty YAML file. Other views likely have data and should work.

**Impact:** CRITICAL - Blocks all testing and verification of UI features

**Location:**
- `config/mock_transactions/cash.yml` - Check if exists
- `config/mock_transactions/investments.yml` - Check if exists
- `config/mock_transactions/credit.yml` - Check if exists
- `config/mock_transactions/transfers.yml` - Check if exists
- `app/services/mock_transaction_data_provider.rb` - Check loading logic
- `app/controllers/transactions_controller.rb` - Check data flow

**Fix Required:**
1. Verify YAML files exist and contain data
2. Check YAML file permissions (readable)
3. Verify YAML structure matches expected format
4. Debug `MockTransactionDataProvider` loading logic
5. Add error logging to identify exact failure point
6. Test with minimal YAML data first

**Priority:** MUST FIX FIRST before any UI fixes can be validated

---

## ❌ Missing Features (Critical)

### 1. Account Filter: Not Immediately Right of Search (CRITICAL)
**Feedback Requirement (line 29):**
> Add **Account** dropdown immediately right of the Search input:
> - Default: "All Accounts"
> - Options: list of linked account names (same format/order as holdings selector)
> - On change: filter the displayed transactions to only that account
> - Same dropdown appears identically on **all five** views

**Feedback also says (lines 26-28):**
> Move entire filter bar **above** the summary stats cards row.
> Make filter bar sticky on scroll

**Current State:**
The current view order is already: Tabs → Filter Bar → Stats → Grid (correct).
The filter bar IS sticky (correct).
BUT the Account dropdown is a **separate grid column** (3rd of 5 columns) instead of being **immediately right of the Search input**.

**Current filter bar grid layout (5 columns):**
```
| Search | Account | Type | Date Range | Apply/Clear |
```

**Required layout — Account immediately right of Search:**
```
| Search  Account | Type | Date Range | Apply/Clear |
```
The Search input and Account dropdown should appear as a paired group (e.g., in a single flex row or joined input-group) so the Account filter is visually "immediately right of" Search.

**Impact:** Medium - Layout adjustment within FilterBarComponent

**Location:**
- `app/components/transactions/filter_bar_component.html.erb` - Restructure grid

**Fix Required:**
- Group Search + Account into a single column/flex container
- Reduce grid from 5 columns to 4:
  ```
  Column 1: Search + Account (flex row or input-group)
  Column 2: Type dropdown
  Column 3: Date Range (from/to)
  Column 4: Apply / Clear buttons
  ```
- Ensure the pairing looks natural (e.g., Search takes ~60% width, Account takes ~40%)

---

### 2. Summary View: Missing Top 5 Recurring Expenses Card
**Feedback Requirement:**
> **Summary View** - Add new card/section below main stats: **"Top 5 Recurring Expenses"**
> - Sort by estimated yearly spend descending.
> - Simple list or small table: Name • Frequency (e.g., Monthly) • Amount • Yearly Total
> - Right-align "See all recurring →" link that applies `recurring=true` filter to main list view.

**Current State:**
- Summary view exists at `/transactions/summary`
- Shows basic stats cards (Total Transactions, Total Amount, Net Amount)
- Shows Categories breakdown
- Shows Top Merchants
- Shows Monthly Totals
- **MISSING:** Top 5 Recurring Expenses card

**Impact:** HIGH - Key feature explicitly requested

**Location:**
- `app/views/transactions/summary.html.erb`
- Controller already has `@top_recurring` variable prepared

**Evidence from Code Review:**
Looking at the summary.html.erb, there IS a section for Top 5 Recurring:
```erb
<%# Top 5 Recurring Expenses %>
<% if @top_recurring.present? %>
  <div class="card bg-base-100 shadow mb-6">
    <!-- card content -->
  </div>
<% end %>
```

**Actual Issue:**
The code exists BUT `@top_recurring` is likely empty/nil, so the section doesn't render.

**Root Cause:**
Need to verify:
1. Controller populates `@top_recurring` correctly
2. `TransactionRecurringDetector.top_recurring` returns data
3. Enough recurring transactions in mock data

**Fix Required:**
1. Verify controller logic in `transactions_controller.rb` summary action
2. Ensure mock data has recurring transactions (same merchant, monthly)
3. Test `TransactionRecurringDetector.top_recurring(all_cash, limit: 5)` in console
4. Add fallback message if no recurring transactions found

---

### 3. Investments View: Merchant Column Not Removed
**Feedback Requirement:**
> **Investments View** - **Remove** Merchant column completely.

**Current State:**
- The merchant column is conditionally hidden via `show_merchant_column?` helper
- BUT it only hides on mobile (`hidden lg:table-cell`)
- The column still appears on desktop/large screens for Investments view

**Impact:** Medium - Shows incorrect column structure for investments

**Location:**
- `app/components/transactions/grid_component.rb`
- `app/components/transactions/grid_component.html.erb` (line ~55)
- `app/components/transactions/row_component.html.erb` (line ~92)

**Fix Required:**
```ruby
# In grid_component.rb, the condition should be:
def show_merchant_column?
  !investments_view? && !transfers_view?
end
```

---

### 4. Transfers View: Merchant Column Not Removed
**Feedback Requirement:**
> **Transfers View** - **Remove** Merchant column.

**Current State:**
- Similar to Investments, the merchant column is conditionally hidden but still appears
- The `show_merchant_column?` method doesn't account for transfers view

**Impact:** Medium - Shows incorrect column structure for transfers

**Location:**
- Same as above

**Fix Required:**
- Same condition update as #1 above

---

### 5. Transfers View: Row Structure Not Fully Correct
**Feedback Requirement:**
> Restructure row to: Date | Type ("Transfer") | From (icon) → To (icon) | Amount (positive, right-aligned).

**Current State:**
- The "Type" column still exists and shows transaction type badge
- The "Details" column contains From → To information (partially correct)
- BUT the structure doesn't match spec: Date | Type | From→To | Amount
- Currently: Date | Name | Type | Details | Account | Amount

**Impact:** High - Table structure doesn't match the specified design

**Location:**
- `app/components/transactions/grid_component.html.erb`
- `app/components/transactions/row_component.html.erb`

**Fix Required:**
- Adjust column headers for transfers view to show: Date | Type | Details | Amount
- Remove Name and Account columns for transfers view
- Ensure Type column shows "Transfer" label consistently
- Simplify the row to only show required columns

---

### 6. Credit View: Pending Badge Styling
**Feedback Requirement:**
> Keep pending badge styling.

**Current State:**
- Pending badge is implemented: `<span class="badge badge-warning badge-xs">Pending</span>`
- This IS working correctly, but needs verification that it applies to credit view

**Impact:** Low - Feature appears implemented but needs testing verification

**Location:**
- `app/components/transactions/row_component.html.erb` (line ~27)

**Status:** Needs verification during manual testing phase

---

### 7. Sidebar Navigation: Still Nested (CRITICAL)
**Feedback Requirement:**
> **Sidebar Navigation** - Flatten: Remove double-nesting under "Transactions".
> Direct children only: Summary, Cash, Credit, Transfers, Investments.

**Current State:**
- The sidebar STILL shows nested structure:
  ```html
  <li class="menu-title"><span>Transactions</span></li>
  <li><a href="/transactions/summary">Summary</a></li>
  <li><a href="/transactions/regular">Cash</a></li>
  <li><a href="/transactions/credit">Credit</a></li>
  <li><a href="/transactions/transfers">Transfers</a></li>
  <li><a href="/transactions/investment">Investments</a></li>
  ```
- The `<li class="menu-title">` creates the nested parent heading

**Impact:** HIGH - This was explicitly called out in the feedback as needing to be flattened

**Location:**
- `app/components/layout_component.html.erb` (sidebar section)

**Fix Required:**
- Remove the `<li class="menu-title"><span>Transactions</span></li>` line
- Keep the five transaction links as direct siblings to Dashboard and Portfolio
- Result should be flat list: Dashboard, Portfolio, Summary, Cash, Credit, Transfers, Investments, Accounts, etc.

**Before:**
```html
<li><a href="/dashboard">Dashboard</a></li>
<li><a href="/portfolio/holdings">Portfolio</a></li>
<li class="menu-title"><span>Transactions</span></li>  <!-- REMOVE THIS -->
<li><a href="/transactions/summary">Summary</a></li>
...
```

**After:**
```html
<li><a href="/dashboard">Dashboard</a></li>
<li><a href="/portfolio/holdings">Portfolio</a></li>
<li><a href="/transactions/summary">Summary</a></li>
...
```

---

## ⚠️ Partial Implementations (Needs Enhancement)

### 8. Investments View: Security Tooltip (Optional)
**Feedback Requirement:**
> Optional (low priority): hover tooltip on security name showing stub "Current: $XXX | Unrealized: +$YYY (+Z%)" — use mock fields if needed.

**Current State:**
- Not implemented
- Security link exists but no tooltip

**Impact:** Low - Marked as optional in feedback

**Recommendation:** Defer to Phase 2 or mark as out-of-scope unless explicitly requested

---

### 9. Recurring Detection: Plaid Flag Integration
**Feedback Requirement:**
> Bonus: respect Plaid's recurring flag if present in data.

**Current State:**
- Partially implemented in `TransactionRecurringDetector`
- Code checks for `txn.recurring` but may need verification with actual Plaid data

**Impact:** Low - Heuristic works, Plaid flag is bonus

**Recommendation:** Test with real Plaid data in production

---

### 10. Icons: Real Logo Support
**Feedback Requirement:**
> Add 20px security icon/logo left of security name (pull from enrichment if available; fallback to letter avatar via DaisyUI).
> Add 20px icon/logo left of merchant name (card logo if present, e.g., Chase Sapphire / Amex; fallback letter avatar).

**Current State:**
- Letter avatars (fallback) implemented correctly
- Real logos from enrichment NOT implemented (requires enrichment service integration)

**Impact:** Medium - Current implementation is acceptable fallback

**Recommendation:** 
- Current state is acceptable for MVP
- Real logo integration requires enrichment service work (separate epic)
- Document as future enhancement

---

## 📋 Remediation Plan

### Phase 0: BLOCKER - Fix Mock Data Loading (1 hour)
**Priority:** CRITICAL - MUST DO FIRST  
**Goal:** Populate cash.yml with mock transaction data

**Root Cause:** `cash.yml` is empty (only contains `transactions: []`)

#### Task 0.1: Populate cash.yml with Mock Data (30 min)
- **File:** `config/mock_transactions/cash.yml`
- **Current State:** Empty file with only `transactions: []`
- **Action:** Add realistic mock transaction data
- **Requirements:**
  - Minimum 20-30 transactions
  - Mix of expenses (negative) and income (positive)
  - Include recurring transactions (same merchant, similar amounts)
  - Include pending transactions (pending: true)
  - Various categories (FOOD_AND_DRINK, GENERAL_MERCHANDISE, INCOME, etc.)
  - Date range: Last 30-60 days
- **Expected structure:**
  ```yaml
  transactions:
    - date: "2026-02-15"
      name: "Whole Foods"
      amount: -45.32
      merchant_name: "Whole Foods Market"
      account_name: "Chase Checking"
      category: "FOOD_AND_DRINK"
      pending: false
      transaction_id: "mock_cash_001"
      source: "manual"
    # ... more transactions
  ```
- **Reference:** Copy/adapt structure from `credit.yml` or `investments.yml` which DO have data

#### Task 0.2: Verify Other Views Load Data (15 min)
- **Action:** Test each view to confirm data loads
- **Test:**
  1. Navigate to `/transactions/credit` - Should show transactions
  2. Navigate to `/transactions/investment` - Should show transactions
  3. Navigate to `/transactions/transfers` - Should show transactions
  4. Navigate to `/transactions/summary` - Should show summary data
- **If any fail:** Debug that specific YAML file

#### Task 0.3: Test Cash View with New Data (15 min)
- **Action:** Reload cash view after populating data
- **Test:** Navigate to `/transactions/regular`
- **Expected Results:**
  - Transaction count > 0 in summary stats
  - Transaction table displays with rows
  - Pagination appears if > 20 transactions
  - Filters work (search, account, date range)
  - Recurring badges appear on matching transactions
- **If still empty:** Check Rails logs for errors in MockTransactionDataProvider

---

### Phase 1: Critical Fixes (3.5-4.5 hours)
**Priority:** HIGH  
**Goal:** Fix missing/incorrect structures
**Prerequisites:** Phase 0 complete (mock data loading)

#### Task 1.1: Reposition Account Filter Next to Search (45 min)
- **File:** `app/components/transactions/filter_bar_component.html.erb`
- **Change:** Group Search + Account into a single flex container within the filter bar grid
- **Current grid (5 equal columns):**
  ```
  | Search | Account | Type | Date Range | Apply/Clear |
  ```
- **New grid (4 columns, Search+Account paired):**
  ```
  | [Search] [Account] | Type | Date Range | Apply/Clear |
  ```
- **Implementation:** Change grid from `md:grid-cols-5` to `md:grid-cols-4`, merge first two form-controls into one `<div class="form-control"><div class="flex gap-2">...</div></div>`
- **No changes needed to:** view files, tabs partial, component Ruby class
- **Testing:**
  - Account dropdown appears directly right of Search input
  - Filter bar still sticky above stats
  - Account filtering still works
  - Consistent on all five views

#### Task 1.2: Fix Summary View Top 5 Recurring Card (45 min)
- **File:** `app/views/transactions/summary.html.erb`
- **Issue:** Card code exists but `@top_recurring` is empty
- **Debug:**
  1. Check controller `summary` action
  2. Verify `TransactionRecurringDetector.top_recurring` works
  3. Ensure cash.yml has recurring transactions
- **Fix:** Add recurring transactions to cash.yml if missing
- **Add:** Fallback message if no recurring found
- **Testing:** Summary view shows Top 5 Recurring Expenses card with data

#### Task 1.3: Flatten Sidebar Navigation (30 min)
- **File:** `app/components/layout_component.html.erb`
- **Change:** Remove the `<li class="menu-title"><span>Transactions</span></li>` line
- **Result:** Direct flat list without nested "Transactions" parent
- **Testing:** Verify sidebar shows flat structure across all pages

#### Task 1.4: Fix Merchant Column Visibility (30 min)
- **File:** `app/components/transactions/grid_component.rb`
- **Change:** Update `show_merchant_column?` method:
  ```ruby
  def show_merchant_column?
    !investments_view? && !transfers_view?
  end
  ```
- **Testing:** Verify Investments and Transfers views don't show Merchant column

#### Task 1.5: Restructure Transfers View Table (1.5 hours)
- **Files:**
  - `app/components/transactions/grid_component.html.erb`
  - `app/components/transactions/row_component.html.erb`
  - `app/components/transactions/row_component.rb`
- **Changes:**
  1. Add conditional column headers for transfers:
     - Hide Name column when `transfers_view?`
     - Hide Account column when `transfers_view?`
     - Show Type column with "Transfer" label
  2. Update row rendering to match structure
  3. Ensure Type badge shows "Transfer" consistently
- **Testing:** 
  - Verify transfers table shows: Date | Type | Details | Amount
  - Verify From→To arrow direction and badges work correctly

#### Task 1.6: Verify Pending Badge (30 min)
- **File:** `app/components/transactions/row_component.rb`
- **Change:** Verify `pending?` method works correctly for credit transactions
- **Testing:** Check credit view with pending transactions shows badge

### Phase 2: Documentation & Testing (1-2 hours)
**Priority:** MEDIUM

#### Task 2.1: Update Test Data (30 min)
- Ensure mock data in `config/mock_transactions/*.yml` includes:
  - Pending credit transactions
  - Recurring transactions across all views
  - Transfer transactions with proper from/to data

#### Task 2.2: Manual Testing (1 hour)
- Test all five views (Summary, Cash, Credit, Transfers, Investments)
- Verify each requirement from feedback document
- Document any additional issues

#### Task 2.3: Update Documentation (30 min)
- Update `CHANGES-SUMMARY.md` with remaining fixes
- Mark feedback items as complete in tracking document
- Update PRD acceptance criteria

### Phase 3: Optional Enhancements (Future)
**Priority:** LOW - Defer unless explicitly requested

- Security hover tooltips (investments view)
- Real logo integration from enrichment service
- Enhanced Plaid recurring flag integration

---

## 🧪 Testing Checklist

After implementing fixes, verify:

### Global Tests
- [ ] Sidebar shows flattened structure WITHOUT "Transactions" parent menu-title
- [ ] Sidebar shows: Dashboard, Portfolio, Summary, Cash, Credit, Transfers, Investments (as flat siblings)
- [ ] Breadcrumbs display correctly on all views (`Home > Transactions > [Subtype]`)
- [ ] Filter bar appears ABOVE summary stats cards (Tabs → Filter → Stats → Grid)
- [ ] Filter bar is sticky on scroll (`position: sticky; top: 0;`)
- [ ] **Account dropdown is immediately right of the Search input** (paired in same row/group)
- [ ] Account dropdown defaults to "All Accounts"
- [ ] Account dropdown lists linked account names
- [ ] Account dropdown filters transactions on change
- [ ] Account dropdown appears identically on all five views
- [ ] Search placeholder: "Search by name, merchant…" (Cash/Credit/Transfers/Summary)
- [ ] Search placeholder: "Search by name, security…" (Investments)

### Cash View
- [ ] Shows recurring badge ("RR") on recurring transactions
- [ ] No merchant column issues
- [ ] Table structure: Date | Name | Type | Merchant | Account | Amount

### Investments View
- [ ] ❌ NO merchant column visible (desktop or mobile)
- [ ] Account column appears after Date (bold/prominent)
- [ ] Security icon (letter avatar) displays
- [ ] Security name is clickable link
- [ ] All columns sortable (6 columns)
- [ ] Table structure: Date | Account | Name | Type | Security | Quantity | Price | Amount

### Credit View
- [ ] Merchant icon (letter avatar) displays
- [ ] Pending badge shows on pending transactions
- [ ] Recurring badge ("RR") shows on recurring transactions
- [ ] Table structure: Date | Name | Type | Merchant | Account | Amount

### Transfers View
- [ ] ❌ NO merchant column visible
- [ ] Only source leg shows (destination deduplicated)
- [ ] Direction arrow correct (green inbound, red outbound)
- [ ] External/Internal badge displays correctly
- [ ] ✅ Table structure: Date | Type | Details (From→To) | Amount
- [ ] Amount always positive, right-aligned

### Summary View
- [ ] **Top 5 Recurring Expenses card displays below main stats (currently missing)**
- [ ] "See all recurring →" link right-aligned, navigates to cash view with `recurring=true` filter
- [ ] Recurring expenses sorted by estimated yearly spend (descending)
- [ ] Shows: Name • Frequency • Amount • Yearly Total
- [ ] Category breakdown displays (kept as-is per feedback)
- [ ] Stats cards show correct data
- [ ] Layout: Tabs → Filter Bar (with Account) → Stats → Top 5 Recurring → Category Breakdown

---

## 🔧 Implementation Notes

### Code Quality
- Follow existing DaisyUI component patterns
- Maintain accessibility attributes (ARIA labels, roles)
- Keep business theme styling consistent
- Ensure responsive design (mobile/desktop)

### Data Considerations
- Verify mock YAML data covers all edge cases
- Test with empty states (no transactions)
- Test with missing fields (account_name, merchant_name, etc.)

### Performance
- No new database queries needed (all mock data)
- Ensure table rendering remains fast with pagination

---

## 📊 Completion Estimate

| Phase | Tasks | Estimated Time | Dependencies |
|-------|-------|----------------|--------------|
| **Phase 0: BLOCKER - Data Fix** | **3** | **1 hour** | **None - DO FIRST** |
| Phase 1: Critical Fixes | 6 | 3.5-4.5 hours | Phase 0 |
| Phase 2: Documentation & Testing | 3 | 1-2 hours | Phase 1 |
| Phase 3: Optional Enhancements | - | Deferred | - |
| **Total** | **12** | **5.5-7.5 hours** | - |

---

## 🎯 Success Criteria

Implementation is complete when:

1. ✅ All 7 critical missing features are implemented and tested
2. ✅ Manual testing checklist 100% passed
3. ✅ All five views match feedback requirements exactly
4. ✅ No regressions in existing functionality
5. ✅ Documentation updated (CHANGES-SUMMARY.md)
6. ✅ Screenshots captured and shared

---

## 📝 Next Steps

1. **Get Approval:** Review this analysis with user/stakeholder
2. **Prioritize:** Confirm Phase 1 (critical fixes) should proceed immediately
3. **Branch:** Create branch `fix/epic-6-01-missing-features`
4. **Implement:** Execute Phase 1 tasks in sequence
5. **Test:** Complete manual testing checklist
6. **Document:** Update tracking documents
7. **Deploy:** Merge to main after approval

---

## Appendix: Quick Reference

### Files That Need Changes

**Phase 0 BLOCKER - Data Fix:**
1. `config/mock_transactions/cash.yml` - Create/verify exists with data
2. `config/mock_transactions/investments.yml` - Create/verify exists with data
3. `config/mock_transactions/credit.yml` - Create/verify exists with data
4. `config/mock_transactions/transfers.yml` - Create/verify exists with data
5. `config/mock_transactions/summary.yml` - Create/verify exists with data
6. `app/services/mock_transaction_data_provider.rb` - Debug/verify loading logic
7. `app/controllers/transactions_controller.rb` - Verify data flow

**Phase 1 Critical Fixes:**
1. `app/components/transactions/filter_bar_component.html.erb` - Group Search + Account together
2. `app/views/transactions/summary.html.erb` - Debug/fix Top 5 Recurring card
3. `app/controllers/transactions_controller.rb` - Verify `@top_recurring` is populated
4. `app/components/layout_component.html.erb` - Remove nested "Transactions" menu-title
5. `app/components/transactions/grid_component.rb` - Update `show_merchant_column?`
6. `app/components/transactions/grid_component.html.erb` - Adjust transfers column headers, hide Name/Account for transfers
7. `app/components/transactions/row_component.html.erb` - Adjust transfers row rendering
8. `app/components/transactions/row_component.rb` - Verify pending/transfer helper methods

**Phase 2 Testing:**
5. `config/mock_transactions/*.yml` - Verify test data coverage
6. `knowledge_base/epics/wip/NextGen/Epic-6-transaction-ui/CHANGES-SUMMARY.md` - Update docs

### Key Methods to Review
- `show_merchant_column?` - Needs fix for investments/transfers
- `transfers_view?` - Already exists, use it
- `investments_view?` - Already exists, use it
- `pending?` - Verify logic
- `transfer_badge` - Already implemented
- `transfer_outbound?` - Already implemented

---

**End of Analysis**
