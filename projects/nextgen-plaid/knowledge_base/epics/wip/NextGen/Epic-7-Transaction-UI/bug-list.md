# Epic-7 Bug List

**Last Updated:** 2026-02-23  
**Status:** Active Investigation  
**Related Epic:** Epic-7 Transaction UI Implementation

## Summary

This document tracks all known bugs discovered during Epic-7 Transaction UI implementation and user testing.

**Critical Issues (P0):** 3
- BUG-7-001: Chart.js import error (asset allocation & sector charts)
- BUG-7-011: Transfers are missing
- BUG-7-012: Transactions missing (last sync Feb 16, current date Feb 23)

**High Priority (P1):** 8
- BUG-7-002: Pagination not working (page 2+ shows no transactions)
- BUG-7-003: All date filters should default to current month
- BUG-7-004: No investment transactions showing
- BUG-7-005: No credit transactions showing
- BUG-7-006: Summary cards not respecting filters
- BUG-7-009: All transfers showing as "External" - missing intra-account transfers
- BUG-7-010: Transfer summary cards show incorrect metrics (not transfer-specific)

**Medium Priority (P2):** 3
- BUG-7-007: Filters not present on summary page
- BUG-7-008: Remove redundant type filter
- BUG-7-013: Transfer description field not displayed

**Total:** 13 bugs documented

---

## Critical Bugs

### BUG-7-001: Chart.js Import Error - Asset Allocation and Sector Charts Not Rendering

**Severity:** Critical  
**Priority:** P0  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Asset allocation charts not rendering on dashboard (`/net_worth/dashboard`)
- Sector weight charts not rendering on dashboard
- Sector page charts not rendering (`/net_worth/sectors`)
- Browser console showing JavaScript error

#### Error Details
```
SyntaxError: Importing binding name 'default' cannot be resolved by star export entries.
```

#### Affected Components
1. **Asset Allocation Component** (`app/components/net_worth/asset_allocation_component.html.erb`)
   - Pie chart not rendering
   - Bar chart not rendering
   - Chart toggle functionality affected

2. **Sector Weights Component** (`app/components/net_worth/sector_weights_component.html.erb`)
   - Bar chart not rendering on dashboard
   - Bar chart not rendering on dedicated sector page

#### Technical Context

**Current JavaScript Setup:**
- File: `app/javascript/application.js`
- Chartkick imported as ESM module: `import Chartkick from "chartkick"`
- Chart.js imported as UMD build: `import "chart.js"`
- Chart.js pinned to CDN in `config/importmap.rb`: `https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js`

**Import Configuration (config/importmap.rb):**
```ruby
pin "chartkick" # @5.0.1
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js"
```

**Application Setup (app/javascript/application.js):**
```javascript
import Chartkick from "chartkick"
import "chart.js" // UMD build (sets `window.Chart`)

Chartkick.use(window.Chart)
window.Chartkick = Chartkick
window.Chart = window.Chart
```

#### Root Cause Analysis
The error "Importing binding name 'default' cannot be resolved by star export entries" typically occurs when:

1. **Module Format Mismatch**: Attempting to import a UMD/CommonJS module as an ES6 module with default export
2. **Chartkick ESM Import Issue**: Chartkick (ESM) may be trying to import Chart.js with a default export, but the UMD build doesn't expose it correctly in the import map context
3. **Import Map Resolution**: The import map may not be correctly resolving the Chart.js module for Chartkick's internal imports

#### Possible Causes
- Chart.js UMD build from CDN may not be compatible with ES6 import syntax in import maps
- Chartkick's internal import of Chart.js may be looking for a different module format
- Star export (`export *`) conflict between Chartkick and Chart.js module systems
- Import map shimming issue with UMD → ESM conversion

#### Impact
- **User Impact:** HIGH - Dashboard primary visualizations completely broken
- **Business Impact:** HIGH - Key feature (asset allocation and sector analysis) unusable
- **Data Impact:** NONE - Data is present, only visualization broken
- **Pages Affected:**
  - `/net_worth/dashboard` (dashboard view)
  - `/net_worth/sectors` (sector detail page)
  - `/net_worth/allocations` (allocation detail page - assumed)

#### Related Files
```
app/javascript/application.js
config/importmap.rb
app/components/net_worth/asset_allocation_component.html.erb
app/components/net_worth/asset_allocation_component.rb
app/components/net_worth/sector_weights_component.html.erb
app/components/net_worth/sector_weights_component.rb
app/controllers/net_worth/dashboard_controller.rb
app/controllers/net_worth/sectors_controller.rb
app/controllers/net_worth/allocations_controller.rb
```

#### Investigation Steps
1. [ ] Check browser console for full error stack trace
2. [ ] Verify import map is generating correct module URLs
3. [ ] Test Chart.js UMD build loads correctly in browser (check `window.Chart`)
4. [ ] Inspect Chartkick source to understand how it imports Chart.js
5. [ ] Test with alternative Chart.js builds (ESM vs UMD)
6. [ ] Review importmap-rails documentation for UMD module handling
7. [ ] Check if Chartkick needs explicit adapter configuration beyond `Chartkick.use(window.Chart)`

#### Potential Solutions

**Option 1: Use Chart.js ESM Build**
- Replace UMD build with official ESM build
- Update import map to point to ESM version
- May require updating Chartkick configuration

**Option 2: Fix Import Map Shim**
- Add explicit shim configuration for Chart.js UMD module
- Configure import map to properly expose default export
- May need to use `preload` or custom shim script

**Option 3: Vendor Chart.js Locally**
- Download and vendor Chart.js in `vendor/javascript/`
- Ensure proper ES6 module format
- Pin to local file instead of CDN

**Option 4: Use Alternative Chart Library**
- Consider ApexCharts or other libraries with better import map support
- May require rewriting chart components

**Option 5: Rollback to Asset Pipeline**
- Move Chart.js back to asset pipeline (non-ESM)
- Use traditional script tags instead of import maps
- Simpler but less modern approach

#### Testing Requirements
Once fixed, must verify:
- [ ] Asset allocation pie chart renders on dashboard
- [ ] Asset allocation bar chart renders on dashboard
- [ ] Chart toggle button switches between pie and bar views
- [ ] Sector weights bar chart renders on dashboard
- [ ] Sector weights bar chart renders on `/net_worth/sectors` page
- [ ] Charts render correctly after Turbo navigation
- [ ] Charts redraw correctly in Turbo Frames
- [ ] No console errors on page load
- [ ] Charts display correct data from controllers

#### Related Issues
- None currently

#### Related PRDs
- PRD-3-11: Asset Allocation View
- PRD-3-12: Sector Weights View
- PRD-2-09: Net Worth Dashboard Layout

#### Notes
- Tables with data still render correctly (fallback working)
- Chart.js was intentionally switched to UMD build to avoid 404 errors from JSPM ESM chunks
- Previous implementation note in importmap.rb mentions JSPM ESM build issues
- This regression may have been introduced when switching from JSPM to CDN UMD build

---

## High Priority Bugs

### BUG-7-002: Transaction Pagination Not Working - Page 2+ Shows No Transactions

**Severity:** High  
**Priority:** P1  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Pagination controls show multiple pages (e.g., "Page 1 of 5")
- "Next" button appears clickable and navigation works
- **Clicking "Next" successfully navigates to page 2**
- **Page 2 (and subsequent pages) show "No transactions found"**
- Page 1 shows transactions correctly
- Pagination footer shows correct counts (e.g., "Showing 26-50 of 150 transactions")
- But transaction table is empty on page 2+

#### Affected Pages
- `/transactions/regular` (Cash & Checking)
- `/transactions/investment` (Investments)
- `/transactions/credit` (Credit)
- `/transactions/transfers` (Transfers)

#### Technical Context
**Pagination Implementation:**
- Component: `app/components/transactions/grid_component.rb`
- Uses `link_to` for Previous/Next buttons
- Pagination logic in `TransactionGridDataProvider#paginate`
- Uses Kaminari for pagination (`.page(page).per(per_page.to_i)`)

**Potential Root Causes:**
1. **Client-Side Pagination Bug**: `paginated_transactions` method in GridComponent is slicing already-paginated data
   - Controller passes paginated transactions from Kaminari (25 records)
   - GridComponent's `paginated_transactions` method tries to re-paginate the already-paginated subset
   - On page 2: Controller returns records 26-50, but GridComponent calculates offset as `(2-1) * 25 = 25` and tries to slice starting at index 25 from a 25-record array → empty result
2. **Double Pagination**: Data is paginated in data provider, then re-paginated in component
3. **Kaminari Relation Not Passed Through**: Component may be receiving an array instead of Kaminari relation

#### Related Files
```
app/components/transactions/grid_component.rb
app/components/transactions/grid_component.html.erb
app/services/transaction_grid_data_provider.rb
app/controllers/transactions_controller.rb
app/views/transactions/regular.html.erb
app/views/transactions/investment.html.erb
app/views/transactions/credit.html.erb
app/views/transactions/transfers.html.erb
```

#### Root Cause Analysis
**CONFIRMED: Double Pagination Bug**

The issue is in `app/components/transactions/grid_component.rb`:

```ruby
def paginated_transactions
  return transactions if all_view?

  offset = (page - 1) * per_page_value
  transactions.slice(offset, per_page_value) || []
end
```

**What's happening:**
1. Controller calls `TransactionGridDataProvider` which paginates data with Kaminari: `.page(page).per(per_page)`
2. Controller passes paginated result (25 records for page 1, next 25 for page 2, etc.) to GridComponent
3. GridComponent's `paginated_transactions` method tries to paginate AGAIN on the already-paginated array
4. **On Page 1:** Offset = 0, slice(0, 25) works → shows transactions
5. **On Page 2:** Offset = 25, but array only has 25 records (indexes 0-24), slice(25, 25) returns empty

**Solution:**
Remove `paginated_transactions` method entirely and iterate over `transactions` directly in the template. The data is already paginated by the data provider.

#### Investigation Steps
1. [x] **CONFIRMED**: GridComponent is re-paginating already-paginated data
2. [ ] Remove `paginated_transactions` method from GridComponent
3. [ ] Update template to use `transactions` instead of `paginated_transactions`
4. [ ] Test pagination works on all pages
5. [ ] Verify "all" view still works correctly

---

### BUG-7-003: All Date Filters Should Default to Current Calendar Month

**Severity:** Medium  
**Priority:** P1  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Date range filters across the application start empty (no default)
- Users must manually enter date range for every view
- Expected: All date filters should default to current month (e.g., Feb 1, 2026 - Feb 28, 2026)
- Actual: Filter shows no default dates

#### Scope
**This applies to ALL date filters in the application, not just transactions:**
- Transaction views (Cash, Investment, Credit, Transfers, Summary)
- Holdings views (if date filters exist)
- Any other views with date range filtering

#### Affected Pages
- All transaction views: `/transactions/regular`, `/transactions/investment`, `/transactions/credit`, `/transactions/transfers`, `/transactions/summary`
- Any other pages with date range filters

#### Technical Context
**Current Implementation:**
- Transaction filter: `app/components/transactions/filter_bar_component.rb`
- Transaction data provider: `app/services/transaction_grid_data_provider.rb`
- Holdings filter: (location TBD - search for date filters in holdings views)
- Date range applied via `apply_date_range(rel)` method
- No default dates set when `date_from` and `date_to` are blank

**Proposed Solution:**
Implement default date logic application-wide:

**Option 1: Controller-level defaults**
```ruby
# In each controller action
def set_default_date_range
  @date_from ||= params[:date_from].presence || Date.current.beginning_of_month.to_s
  @date_to ||= params[:date_to].presence || Date.current.end_of_month.to_s
end
```

**Option 2: Data provider defaults**
```ruby
# In TransactionGridDataProvider and similar classes
def date_from
  params[:date_from].presence || Date.current.beginning_of_month.to_s
end

def date_to
  params[:date_to].presence || Date.current.end_of_month.to_s
end
```

**Option 3: Application-wide concern**
```ruby
# Create app/controllers/concerns/date_range_filtering.rb
module DateRangeFiltering
  extend ActiveSupport::Concern
  
  included do
    before_action :set_default_date_range
  end
  
  private
  
  def set_default_date_range
    @date_from = params[:date_from].presence || Date.current.beginning_of_month.to_s
    @date_to = params[:date_to].presence || Date.current.end_of_month.to_s
  end
end
```

**Recommendation:** Use Option 3 (concern) for consistency across all controllers with date filtering.

#### Impact
- **User Experience:** HIGH - Users see all historical data by default, causing confusion and slow load times
- **Performance:** HIGH - Large datasets load without date filtering, causing slowness
- **Usability:** HIGH - Users expect to see current month by default for financial data
- **Scope:** Application-wide change affecting multiple views

#### Related Files
```
app/components/transactions/filter_bar_component.rb
app/services/transaction_grid_data_provider.rb
app/controllers/transactions_controller.rb
app/controllers/concerns/date_range_filtering.rb (to be created)
app/controllers/portfolio/holdings_controller.rb (if applicable)
app/controllers/net_worth/*_controller.rb (check for date filters)
```

---

### BUG-7-004: No Investment Transactions Showing in Investment View

**Severity:** High  
**Priority:** P1  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Investment transactions view shows "No transactions found"
- Expected: Investment transactions (buy, sell, dividend, etc.) should appear
- Database may contain investment transactions that aren't appearing

#### Affected Pages
- `/transactions/investment` (Investment view)

#### Technical Context
**STI Type Filtering:**
- Data provider filters by `type: "InvestmentTransaction"` for investment view
- Controller action: `transactions_controller.rb#investment`
- Calls `TransactionGridDataProvider.new(current_user, permitted.merge(view_type: "investment"))`

**Potential Root Causes:**
1. **STI Type Column Issue**: `transactions.type` column may not be properly set to "InvestmentTransaction"
2. **Migration Issue**: Backfill migration may not have run or may have incorrect logic
3. **Plaid Sync Issue**: New transactions may not be getting correct STI type assigned
4. **Account Type Logic**: Investment transactions may be filtered out by account type

#### Investigation Steps
1. [ ] Check database: `SELECT COUNT(*) FROM transactions WHERE type = 'InvestmentTransaction'`
2. [ ] Check for transactions with investment columns: `SELECT COUNT(*) FROM transactions WHERE security_name IS NOT NULL`
3. [ ] Review backfill migration: `db/migrate/*_backfill_transaction_sti_type.rb`
4. [ ] Check transaction sync service: Does it set STI type correctly?
5. [ ] Review account type filtering in data provider

#### Related Files
```
app/services/transaction_grid_data_provider.rb
app/models/transaction.rb
app/models/investment_transaction.rb
app/services/plaid_transaction_sync_service.rb
db/migrate/*_backfill_transaction_sti_type.rb
```

---

### BUG-7-005: No Credit Transactions Showing in Credit View

**Severity:** High  
**Priority:** P1  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Credit transactions view shows "No transactions found"
- Expected: Credit card transactions should appear
- Similar to investment transaction issue

#### Affected Pages
- `/transactions/credit` (Credit view)

#### Technical Context
Same as BUG-7-004, but for `CreditTransaction` STI type.

**Investigation Steps:**
1. [ ] Check database: `SELECT COUNT(*) FROM transactions WHERE type = 'CreditTransaction'`
2. [ ] Verify credit account transactions exist in database
3. [ ] Review STI type assignment logic in sync service

#### Related Files
Same as BUG-7-004, plus:
```
app/models/credit_transaction.rb
```

---

### BUG-7-006: Summary Page Cards Should Respect Active Filters

**Severity:** Medium  
**Priority:** P1  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Summary page shows totals/statistics cards at top
- When filters are applied (date range, account filter), cards don't update
- Expected: Cards should show filtered totals
- Actual: Cards show all-time totals regardless of filters

#### Affected Pages
- `/transactions/summary` (Summary view)

#### Technical Context
**Current Implementation:**
- Summary cards component: `app/components/transactions/summary_card_component.rb` (assumed)
- Data provider has `compute_summary` method that should respect filters
- Controller may not be passing filter params to summary computation

**Potential Root Causes:**
1. **Summary Cards Not Using Filtered Data**: Cards may be computing totals from unfiltered relation
2. **Controller Not Passing Filters**: Summary controller action may not pass filter params to data provider
3. **Component Using Raw Transaction Count**: Component may be calling `.count` on transactions directly instead of using filtered totals

#### Investigation Steps
1. [ ] Review summary controller action implementation
2. [ ] Check if summary_mode is properly enabled when computing summary data
3. [ ] Verify filter params (date_from, date_to, account_filter_id) are passed to data provider
4. [ ] Inspect `TransactionGridDataProvider#compute_summary` to ensure it uses filtered_relation

#### Related Files
```
app/controllers/transactions_controller.rb (summary action)
app/components/transactions/summary_card_component.rb
app/views/transactions/summary.html.erb
app/views/transactions/_summary_content.html.erb
app/services/transaction_grid_data_provider.rb
```

---

### BUG-7-007: Filters Not Preset on Summary Page

**Severity:** Medium  
**Priority:** P2  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Summary page loads without any filter UI
- User cannot filter summary data by date range, account, etc.
- Expected: Filter bar should be present and functional on summary page
- Actual: No filter controls visible

#### Affected Pages
- `/transactions/summary` (Summary view)

#### Technical Context
**Current Implementation:**
- Other views render `Transactions::FilterBarComponent`
- Summary view may be missing filter bar component render
- View: `app/views/transactions/summary.html.erb` or `_summary_content.html.erb`

**Proposed Solution:**
Add filter bar component to summary view:
```erb
<%= render Transactions::FilterBarComponent.new(
  search_term: @search_term,
  date_from: @date_from,
  date_to: @date_to,
  view_type: "summary"
) %>
```

#### Impact
- **User Experience:** MEDIUM - Cannot filter summary statistics
- **Functionality:** HIGH - Filter functionality completely missing from summary page

#### Related Files
```
app/views/transactions/summary.html.erb
app/views/transactions/_summary_content.html.erb
app/components/transactions/filter_bar_component.rb
```

---

### BUG-7-008: Remove Type Filter from All Transaction Filter Bars

**Severity:** Low  
**Priority:** P2  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Filter bar shows "Type" dropdown with options: All Types, Cash, Investment, Credit, Transfer
- This is redundant because view tabs already filter by type
- Expected: Type filter should not be visible
- Actual: Type filter appears on all transaction views

#### Affected Pages
- All transaction views (Cash, Investment, Credit, Transfers)

#### Technical Context
**Current Implementation:**
- Filter component: `app/components/transactions/filter_bar_component.rb`
- Defines `TYPE_FILTER_OPTIONS` constant
- Filter bar template renders type select dropdown
- Each view already has its own type filter via `view_type` param

**Proposed Solution:**
1. Remove type filter dropdown from filter bar component template
2. Keep internal type filtering logic (controlled by view_type)
3. Remove `TYPE_FILTER_OPTIONS` constant if no longer needed

#### Impact
- **User Experience:** LOW - Minor UI cleanup, reduces confusion
- **Functionality:** NONE - No functional impact, purely cosmetic

#### Related Files
```
app/components/transactions/filter_bar_component.rb
app/components/transactions/filter_bar_component.html.erb
```

---

### BUG-7-009: All Transfers Showing as "External" - Missing Intra-Account Transfers

**Severity:** High  
**Priority:** P1  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- All transfers in transfers view show as "External"
- Intra-account transfers (transfers between user's own accounts) are not visible or not labeled correctly
- Expected: Transfers between own accounts should show as "Internal" or show both account names
- Actual: All transfers labeled as "External"

#### Affected Pages
- `/transactions/transfers` (Transfers view)

#### Technical Context
**Transfer Detection Logic:**
- Data provider filters by: `personal_finance_category_label ILIKE 'TRANSFER%'`
- TransferDeduplicator service removes duplicate transfer legs
- Transfer categorization may depend on Plaid's category or custom logic

**Potential Root Causes:**
1. **Missing Transfer Classification Logic**: No logic to distinguish internal vs external transfers
2. **Plaid Category Limitation**: Plaid may not provide enough metadata to distinguish transfer types
3. **Account Matching Logic Missing**: Need to match transfer pairs by checking if both accounts belong to same user
4. **Display Logic Issue**: Transfer type may be determined but not displayed correctly

**Proposed Solution:**
Add transfer classification logic:
```ruby
# In Transaction model or helper
def transfer_type
  return nil unless transfer?
  
  # Check if counterparty account belongs to same user
  if counterparty_account&.user_id == account.user_id
    "Internal"
  else
    "External"
  end
end
```

#### Investigation Steps
1. [ ] Review Transaction model for transfer detection logic
2. [ ] Check if Plaid provides counterparty account information
3. [ ] Review TransferDeduplicator logic
4. [ ] Check if intra-account transfers exist in database
5. [ ] Verify transfer matching logic identifies both legs of internal transfers
6. [ ] Add transfer_type classification method
7. [ ] Update transfer row component to display transfer type

#### Related Files
```
app/models/transaction.rb
app/services/transfer_deduplicator.rb
app/components/transactions/row_component.rb
app/services/transaction_grid_data_provider.rb
```

---

### BUG-7-010: Transfer Summary Cards Show Incorrect Metrics

**Severity:** High  
**Priority:** P1  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Transfer view shows summary cards with incorrect/misleading metrics
- Current cards show:
  - Net Amount: -$135,530.58 (labeled as "Sum of all transactions")
  - Average Transaction: -$6,453.84 (labeled as "Mean amount")
  - Largest Expense: $50,000.00 (labeled as "Top spending category: FOOD_AND_DRINK")
- **Problems:**
  1. "Net Amount" for transfers doesn't make sense (should be zero for internal transfers after deduplication)
  2. "Average Transaction" not useful for transfers
  3. "Largest Expense" with spending category (FOOD_AND_DRINK) is wrong - transfers aren't expenses
  4. Missing key transfer metrics

#### Expected Behavior
Transfer summary cards should show:
- **Net Inflows to All Accounts**: Total amount transferred INTO user's accounts
- **Net Outflows to External Accounts**: Total amount transferred OUT to external accounts
- **Internal Transfers**: Total amount moved between user's own accounts
- Remove spending category references (not applicable to transfers)

#### Affected Pages
- `/transactions/transfers` (Transfers view)

#### Technical Context
**Current Implementation:**
- Summary card component: `app/components/transactions/summary_card_component.rb`
- Uses generic transaction metrics not suited for transfers
- Likely reusing same component across all transaction views
- Need transfer-specific summary card component or conditional logic

**Transfer-Specific Metrics Calculation:**
```ruby
# In TransactionGridDataProvider or new TransferSummaryCalculator
def transfer_summary
  {
    total_inflows: filtered_relation.where("amount > 0").sum(:amount),
    total_outflows: filtered_relation.where("amount < 0").sum(:amount).abs,
    internal_transfers: calculate_internal_transfers,
    external_outflows: calculate_external_outflows,
    count: filtered_relation.count
  }
end

def calculate_internal_transfers
  # Sum of transfers between user's own accounts
  # After deduplication, this should be the outbound legs only
  filtered_relation
    .joins("INNER JOIN accounts counterparty ON counterparty.account_id = transactions.counterparty_account_id")
    .where("counterparty.user_id = accounts.user_id")
    .where("amount < 0")
    .sum(:amount)
    .abs
end

def calculate_external_outflows
  # Sum of transfers to external accounts (not owned by user)
  filtered_relation
    .where("amount < 0")
    .where.not(id: internal_transfer_ids)
    .sum(:amount)
    .abs
end
```

**Proposed Solution:**
1. Create `Transactions::TransferSummaryCardComponent` separate from generic summary card
2. Calculate transfer-specific metrics in data provider
3. Update transfers view to render transfer-specific summary component
4. Remove category/merchant metrics from transfer summaries

#### Impact
- **User Experience:** HIGH - Misleading information confuses users
- **Data Accuracy:** HIGH - Shows incorrect financial metrics
- **Trust:** HIGH - Incorrect metrics undermine confidence in application

#### Related Files
```
app/components/transactions/summary_card_component.rb
app/components/transactions/transfer_summary_card_component.rb (to be created)
app/services/transaction_grid_data_provider.rb
app/views/transactions/transfers.html.erb
app/controllers/transactions_controller.rb (transfers action)
```

---

### BUG-7-013: Transfer Description Field Not Displayed

**Severity:** Medium  
**Priority:** P2  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Transfer transactions have a description field with useful information
- Description field is not displayed on transfers view
- Expected: Description should be visible to help identify transfers
- Actual: Description column/field is missing

#### Affected Pages
- `/transactions/transfers` (Transfers view)

#### Technical Context
**Current Implementation:**
- Transfer row component: `app/components/transactions/row_component.rb`
- Transfer view template: `app/views/transactions/transfers.html.erb`
- Transfer grid component: `app/components/transactions/grid_component.rb`

**Transaction fields available:**
- `name` (transaction name)
- `merchant_name` (merchant name, if applicable)
- `description` (additional description text)
- `personal_finance_category_label` (e.g., "TRANSFER_IN", "TRANSFER_OUT")

**Proposed Solution:**
1. Add "Description" column to transfers table header in GridComponent template
2. Update RowComponent to display description for transfer view
3. Consider showing description in place of merchant (which is N/A for transfers)

#### Related Files
```
app/components/transactions/grid_component.html.erb
app/components/transactions/row_component.rb
app/components/transactions/row_component.html.erb
app/views/transactions/transfers.html.erb
```

---

### BUG-7-011: Transfers Are Missing

**Severity:** Critical  
**Priority:** P0  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Transfer transactions are not appearing in transfers view
- Expected: Transfers between accounts should be visible
- Actual: No transfers or very few transfers showing

#### Affected Pages
- `/transactions/transfers` (Transfers view)

#### Technical Context
**Transfer Filtering Logic:**
```ruby
def filter_by_transfer(relation)
  relation.where("personal_finance_category_label ILIKE ?", "TRANSFER%")
          .where.not(accounts: { plaid_account_type: "investment" })
end
```

**Potential Root Causes:**
1. **Category Label Issue**: Transactions may not have `personal_finance_category_label` set to "TRANSFER%"
2. **Investment Account Filter**: Filter excludes investment accounts, but user may have investment transfers
3. **Plaid Categorization**: Plaid may not be categorizing transfers correctly
4. **STI Type Filter Conflict**: Transfer filtering may conflict with STI type filtering
5. **Missing Data**: Transfers may not have been synced from Plaid
6. **TransferDeduplicator Over-filtering**: Deduplicator may be removing too many transactions

#### Investigation Steps
1. [ ] Check database for transfer transactions: `SELECT COUNT(*) FROM transactions WHERE personal_finance_category_label ILIKE 'TRANSFER%'`
2. [ ] Check if transfers exist but have different category labels
3. [ ] Review Plaid API response for transfer categorization
4. [ ] Test with investment account filter removed
5. [ ] Check TransferDeduplicator logic for over-aggressive filtering
6. [ ] Verify transfer transactions are being synced from Plaid
7. [ ] Check if transfers are categorized differently (e.g., "BANK_FEES", "PAYMENT", etc.)

#### Related Files
```
app/services/transaction_grid_data_provider.rb
app/services/transfer_deduplicator.rb
app/services/plaid_transaction_sync_service.rb
app/models/transaction.rb
app/controllers/transactions_controller.rb (transfers action)
```

---

### BUG-7-012: Transactions Missing - Last Transaction Showing Feb 16

**Severity:** Critical  
**Priority:** P0  
**Status:** Open  
**Reported:** 2026-02-23

#### Symptoms
- Most recent transaction visible is dated Feb 16, 2026
- Today is Feb 23, 2026 (7 days of missing transactions)
- Expected: Transactions should be current (last 24-48 hours)
- Actual: Transactions appear outdated

#### Affected Pages
- All transaction views

#### Technical Context
**Transaction Sync:**
- Sync job: `app/jobs/sync_transactions_job.rb`
- Sync service: `app/services/plaid_transaction_sync_service.rb`
- Plaid API transactions endpoint
- Should sync daily or on-demand

**Potential Root Causes:**
1. **Sync Job Not Running**: Daily sync job may have stopped or failed
2. **Plaid API Error**: Plaid sync may be failing silently
3. **Job Queue Issue**: Background jobs may not be processing
4. **Plaid Item Connection Issue**: Plaid connection may be in error state
5. **Date Range Issue**: Sync may be requesting wrong date range
6. **Transaction Already Synced**: Transactions may exist but not showing due to filter/type issue

#### Investigation Steps
1. [ ] Check sync logs: `SyncLog.where(job_type: "sync_transactions").order(created_at: :desc).limit(10)`
2. [ ] Check for failed jobs in Sidekiq/ActiveJob
3. [ ] Verify Plaid item status: `PlaidItem.all.pluck(:id, :status, :error_code)`
4. [ ] Check raw transaction count: `SELECT MAX(date) FROM transactions`
5. [ ] Review last sync timestamps in Mission Control
6. [ ] Manually trigger sync and monitor for errors
7. [ ] Check Plaid API logs for any errors

#### Impact
- **User Impact:** CRITICAL - Core feature (transaction tracking) is stale
- **Data Impact:** HIGH - Missing week of financial data
- **Business Impact:** CRITICAL - Users cannot trust data accuracy

#### Related Files
```
app/jobs/sync_transactions_job.rb
app/services/plaid_transaction_sync_service.rb
app/models/plaid_item.rb
app/models/transaction.rb
config/sidekiq.yml (or job scheduler config)
```

#### Related PRDs
- Epic-7 PRD-7-01: Transaction Data Provider Wiring
- Original Transaction Sync PRDs from earlier epics

---

## Open Questions
1. What browser(s) is the error occurring in? (Chrome, Safari, Firefox, etc.)
2. Does the error occur in development and production, or just one environment?
3. When did this regression occur? (After a specific deployment or change?)
4. Are there any additional errors in the browser console beyond the import error?
5. Does `window.Chart` exist when inspecting in browser console?
6. Does `window.Chartkick` exist when inspecting in browser console?

---

## Investigation Log

### 2026-02-23 - Initial Report
- User reported asset allocation and sector charts not rendering
- Error: `SyntaxError: Importing binding name 'default' cannot be resolved by star export entries`
- Confirmed issue affects both dashboard and dedicated sector page
- Created bug list document for Epic-7

