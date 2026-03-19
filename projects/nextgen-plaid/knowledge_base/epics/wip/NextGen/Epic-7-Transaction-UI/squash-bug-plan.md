# Epic-7 Bug Squash Plan

**Created:** 2026-02-23  
**Status:** Ready for Execution  
**Source:** `bug-list.md`  
**Total Bugs:** 13  
**Estimated Phases:** 5  

---

## Execution Strategy

Bugs are grouped into **dependency-ordered phases** so that foundational issues (data availability, import errors) are resolved before UI-layer issues (filters, cards, columns). Each phase can be verified independently before moving to the next.

---

## Phase 1: Data Availability & Sync (P0 — blocks everything)

### 1A. BUG-7-012: Transactions Missing — Last Sync Feb 16
-- ensure that solid-queue is running and jobs are scheduled
> **Why first:** If transaction data is stale, every other bug may be a symptom rather than a real issue. Restoring sync gives us accurate data for all subsequent investigations.

**Verify:**
```bash
rails runner "puts Transaction.maximum(:date)"
rails runner "puts SyncLog.where(job_type: 'sync_transactions').order(created_at: :desc).limit(5).pluck(:created_at, :status, :error_message).inspect"
rails runner "puts PlaidItem.pluck(:id, :status, :error_code, :updated_at).inspect"
```
- If `MAX(date)` is Feb 16, the sync has genuinely stopped.
- Check SyncLog for errors. Check PlaidItem for `ITEM_LOGIN_REQUIRED` or similar.
- Check Sidekiq / Solid Queue dashboard for stuck or failed jobs.

**Fix path (depending on diagnosis):**
1. **Plaid item in error state** → Re-auth via Link update flow, then trigger manual sync from Mission Control (`/mission_control/sync_transactions_now`).
2. **Job scheduler stopped** → Restart Sidekiq / cron and verify `config/recurring.yml` or `config/sidekiq.yml` has the recurring schedule.
3. **Sync service bug** → Inspect `PlaidTransactionSyncService` for cursor or date-range logic errors; patch and re-run.
4. **Data exists but hidden** → This becomes a filter/type issue (see Phase 2).

**Acceptance:**
- `Transaction.maximum(:date)` returns today or yesterday.
- SyncLog shows a successful run after the fix.

---

### 1B. BUG-7-004 & BUG-7-005: No Investment / Credit Transactions

> **Why now:** These may be caused by missing STI types rather than missing data. Must verify before touching filters.

**Verify:**
```bash
rails runner "
  puts 'Total transactions: ' + Transaction.unscoped.count.to_s
  puts 'RegularTransaction: ' + Transaction.unscoped.where(type: 'RegularTransaction').count.to_s
  puts 'InvestmentTransaction: ' + Transaction.unscoped.where(type: 'InvestmentTransaction').count.to_s
  puts 'CreditTransaction: ' + Transaction.unscoped.where(type: 'CreditTransaction').count.to_s
  puts 'NULL type: ' + Transaction.unscoped.where(type: nil).count.to_s
  puts 'Investment accounts txns: ' + Transaction.unscoped.joins(account: :plaid_item).where(accounts: { plaid_account_type: 'investment' }).count.to_s
  puts 'Credit accounts txns: ' + Transaction.unscoped.joins(account: :plaid_item).where(accounts: { plaid_account_type: 'credit' }).count.to_s
"
```

**Scenario A — STI types never backfilled:**
- Run the backfill migration or create a rake task:
```ruby
# lib/tasks/backfill_sti.rake
namespace :transactions do
  task backfill_sti: :environment do
    Transaction.unscoped.includes(account: :plaid_item).find_each do |txn|
      correct_type = case txn.account&.plaid_account_type
                     when "investment" then "InvestmentTransaction"
                     when "credit"     then "CreditTransaction"
                     else "RegularTransaction"
                     end
      txn.update_column(:type, correct_type) if txn.type != correct_type
    end
  end
end
```

**Scenario B — STI types exist but sync doesn't assign them to new rows:**
- Patch `PlaidTransactionSyncService` to set `type` based on `account.plaid_account_type` when creating new transactions.
- Ensure `Transaction#default_sti_type` callback does the right thing (currently defaults to `RegularTransaction`; needs account-type awareness).

**Scenario C — Data doesn't exist at all:**
- Verify Plaid items include investment/credit products. If not, re-link with correct products.

**Acceptance:**
- `InvestmentTransaction.count > 0` and `CreditTransaction.count > 0`.
- `/transactions/investment` and `/transactions/credit` show rows.

---

### 1C. BUG-7-011: Transfers Are Missing

**Verify:**
```bash
rails runner "
  puts 'TRANSFER% label count: ' + Transaction.where('personal_finance_category_label ILIKE ?', 'TRANSFER%').count.to_s
  puts 'Sample labels: ' + Transaction.where('personal_finance_category_label ILIKE ?', '%transfer%').distinct.pluck(:personal_finance_category_label).first(20).inspect
  puts 'All distinct labels: ' + Transaction.distinct.pluck(:personal_finance_category_label).compact.sort.inspect
"
```

**Possible issues & fixes:**
1. **Label not set** — Plaid may use `personal_finance_category` JSON hash instead of the label column. Check if `personal_finance_category_label` is populated during sync; fix sync service if not.
2. **Label uses different pattern** — e.g., `"TRANSFER_IN"`, `"TRANSFER_OUT"`, or `"Transfer"` (case mismatch). The `ILIKE 'TRANSFER%'` should handle case, but verify exact values.
3. **Investment exclusion too aggressive** — `filter_by_transfer` excludes `plaid_account_type: "investment"`. If user has investment account transfers, they'll be excluded. **Fix:** Allow investment transfers but tag them appropriately.
4. **TransferDeduplicator over-filtering** — After deduplication, if all transactions are marked external and then filtered out, nothing shows. **Fix:** Verify deduplicator returns results regardless of match status.

**Acceptance:**
- `/transactions/transfers` shows transfer transactions.
- Both internal and external transfers are visible.

---

## Phase 2: Chart Rendering (P0 — independent of transaction data)

### 2A. BUG-7-001: Chart.js Import Error

**Verify:**
1. Open browser console on `/net_worth/dashboard`.
2. Confirm error: `SyntaxError: Importing binding name 'default' cannot be resolved by star export entries`.
3. Check if `window.Chart` is defined (type `window.Chart` in console).

**Root Cause:**
The vendored `chart.js.js` (from JSPM ESM build) starts with:
```js
import{r as t,c as e,...}from"../_/MwoWUuIu.js";
```
This imports from a JSPM chunk URL (`/_/MwoWUuIu.js`) that doesn't exist in this app. The `importmap.rb` also pins `chart.js` to a CDN UMD build. There's a conflict between:
- `vendor/javascript/chart.js.js` (broken JSPM ESM with missing chunks)
- CDN pin `https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js`

Meanwhile, `chartkick` ESM module does `export{m as default}` which works fine. The error is coming from the Chart.js side.

**Fix — Option 3 (Vendor a working build):**
1. Remove the broken JSPM ESM file:
   ```bash
   rm vendor/javascript/chart.js.js
   ```
2. Download the auto-register UMD build and wrap it as ESM:
   ```bash
   curl -o vendor/javascript/chart.js.js \
     "https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js"
   ```
3. Add an ESM export wrapper at the end of the vendored file:
   ```js
   // ESM shim for importmap compatibility
   if (typeof window !== "undefined" && window.Chart) {
     export default window.Chart;
   }
   ```
   *Or* create a thin shim file:
   ```js
   // vendor/javascript/chart.js.js
   import "https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js";
   export default window.Chart;
   ```
4. Update `config/importmap.rb`:
   ```ruby
   pin "chart.js", to: "chart.js.js"   # local vendor, not CDN
   ```
5. Ensure `app/javascript/application.js` import still works:
   ```js
   import Chartkick from "chartkick"
   import Chart from "chart.js"
   Chartkick.use(Chart)
   ```

**Alternative — Simpler CDN approach:**
If vendoring is complex, use a `<script>` tag in layout to load Chart.js globally before importmap boots, then remove the `import "chart.js"` line:
```erb
<!-- app/views/layouts/application.html.erb, before importmap tags -->
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js"></script>
```
```js
// app/javascript/application.js
import Chartkick from "chartkick"
Chartkick.use(window.Chart)
```

**Acceptance:**
- No JS errors in console on `/net_worth/dashboard`.
- Asset allocation pie/bar charts render.
- Sector weights bar chart renders on dashboard and `/net_worth/sectors`.
- Chart toggle (pie ↔ bar) works.
- Charts redraw after Turbo navigation.

---

## Phase 3: Pagination & Date Defaults (P1 — core UX fixes)

### 3A. BUG-7-002: Pagination — Page 2+ Empty

**Root Cause (confirmed):**
`TransactionGridDataProvider` paginates with Kaminari (`.page(page).per(per_page)`), returning only 25 records for page N. Then `GridComponent#paginated_transactions` re-slices:
```ruby
def paginated_transactions
  return transactions if all_view?
  offset = (page - 1) * per_page_value
  transactions.slice(offset, per_page_value) || []
end
```
On page 2: offset = 25, array has 25 items → empty result.

**Fix:**

1. **`app/components/transactions/grid_component.rb`** — Remove `paginated_transactions` method entirely.

2. **`app/components/transactions/grid_component.html.erb`** — Replace `paginated_transactions` with `transactions`:
   ```erb
   <%# Change this line: %>
   <% paginated_transactions.each do |transaction| %>
   <%# To: %>
   <% transactions.each do |transaction| %>
   ```

3. **Verify `all_view?` still works:** When `per_page=all`, the data provider skips Kaminari and returns all records. The template iterates `transactions` directly — no re-slicing needed. Works correctly.

**Files changed:**
- `app/components/transactions/grid_component.rb` — delete `paginated_transactions` method
- `app/components/transactions/grid_component.html.erb` — update iterator

**Acceptance:**
- Navigate to `/transactions/regular`, click Next → page 2 shows transactions.
- Pagination counts are accurate.
- "All" view still works.
- All views (regular, investment, credit, transfers) paginate correctly.

---

### 3B. BUG-7-003: All Date Filters Default to Current Month

**Fix:**

1. **Create concern `app/controllers/concerns/default_date_range.rb`:**
   ```ruby
   module DefaultDateRange
     extend ActiveSupport::Concern

     private

     def apply_default_date_range
       @date_from = params[:date_from].presence || Date.current.beginning_of_month.iso8601
       @date_to   = params[:date_to].presence   || Date.current.end_of_month.iso8601
     end
   end
   ```

2. **Include in `TransactionsController`:**
   ```ruby
   class TransactionsController < ApplicationController
     include DefaultDateRange
     before_action :apply_default_date_range, only: [:regular, :investment, :credit, :transfers, :summary]
   ```

3. **Pass defaults to data provider** — Update each action to merge `@date_from` / `@date_to` into params passed to `TransactionGridDataProvider`:
   ```ruby
   def regular
     permitted = params.permit!
     merged = permitted.merge(date_from: @date_from, date_to: @date_to)
     result = TransactionGridDataProvider.new(current_user, merged.merge(view_type: "regular")).call
     assign_from_result(result, merged)
   end
   ```
   Repeat for `investment`, `credit`, `transfers`, `summary`.

4. **Filter bar shows defaults** — The filter bar component already receives `@date_from` and `@date_to` as props. With defaults set in controller, the HTML date inputs will be pre-populated.

5. **"Clear" button behavior** — The "Clear" link currently resets to `request.path` (no params). After clearing, the controller will re-apply defaults on the next request. This is correct behavior — "Clear" means "reset to defaults", not "show all time".

**Files changed:**
- `app/controllers/concerns/default_date_range.rb` (new)
- `app/controllers/transactions_controller.rb` (include concern, update actions)

**Acceptance:**
- All transaction views load with current month pre-selected in date inputs.
- Filter bar shows `2026-02-01` to `2026-02-28` by default.
- User can still change dates and filter.
- "Clear" resets to current month defaults.

---

## Phase 4: Summary & Filter UI (P1/P2 — polish)

### 4A. BUG-7-007: Filters Not Present on Summary Page

**Root Cause:**
The `summary` controller action doesn't set `@search_term`, `@date_from`, `@date_to`, or render the `FilterBarComponent`. The `_summary_content.html.erb` partial doesn't include it.

**Fix:**

1. **Update `summary` action in `TransactionsController`:**
   ```ruby
   def summary
     permitted = params.permit!
     merged = permitted.merge(date_from: @date_from, date_to: @date_to, summary_mode: true)
     result = TransactionGridDataProvider.new(current_user, merged).call
     @summary = result.summary
     @total_count = result.total_count
     @top_recurring = top_recurring_expenses
     @warning = result.warning
     @search_term = merged[:search_term]
     @date_from = merged[:date_from]
     @date_to = merged[:date_to]
   end
   ```

2. **Add FilterBarComponent to `_summary_content.html.erb`** (or to `summary.html.erb` inside the turbo frame):
   ```erb
   <%= render Transactions::FilterBarComponent.new(
     search_term: @search_term,
     date_from: @date_from,
     date_to: @date_to,
     view_type: "summary"
   ) %>
   ```

**Acceptance:**
- `/transactions/summary` shows filter bar with date range inputs.
- Changing dates reloads summary with filtered data.

---

### 4B. BUG-7-006: Summary Cards Don't Respect Filters

**Root Cause:**
The `summary` action passes `summary_mode: true`, which calls `compute_summary` on the `filtered_relation`. This DOES respect filters — **but only if filter params are actually passed to the data provider.** 

With Phase 3B (date defaults) and Phase 4A (filter bar on summary), filter params will now flow through correctly. **This bug is resolved by 3B + 4A combined.**

**Verify after 3B + 4A:**
- Set date range to a specific month on summary page.
- Confirm Total Transactions, Inflow, Outflow, Net change to match the filtered period.
- Apply a saved account filter → confirm cards update.

---

### 4C. BUG-7-008: Remove Redundant Type Filter

**Fix:**

1. **`app/components/transactions/filter_bar_component.html.erb`** — Remove the type filter `<div>`:
   ```erb
   <%# DELETE this entire block: %>
   <div class="form-control">
     <label class="label" for="type_filter">
       <span class="label-text">Type</span>
     </label>
     <%= select_tag :type_filter, options_for_select(TYPE_FILTER_OPTIONS, type_filter), ... %>
   </div>
   ```

2. **`app/components/transactions/filter_bar_component.rb`** — Optionally remove `TYPE_FILTER_OPTIONS` constant and `type_filter` attr if no longer used anywhere. Keep the `@type_filter` instance variable since it's still used internally by the data provider via `view_type`.

3. **Update grid layout** — With one fewer column in the filter bar, adjust the grid: change `grid-cols-1 md:grid-cols-4` to `grid-cols-1 md:grid-cols-3`.

**Files changed:**
- `app/components/transactions/filter_bar_component.html.erb`
- `app/components/transactions/filter_bar_component.rb` (cleanup)

**Acceptance:**
- No "Type" dropdown visible on any transaction view.
- Tabs still correctly filter by type.
- Search, date range, and Apply/Clear still work.

---

## Phase 5: Transfer-Specific Fixes (P0/P1/P2 — transfer UX overhaul)

### 5A. BUG-7-009: All Transfers Show as "External"

**Root Cause:**
In `TransferDeduplicator#mark_external_transfers`, the `@_external` flag is set based on whether a match was found. But `RowComponent#transfer_badge` has a fallback heuristic:
```ruby
if transaction.instance_variable_defined?(:@_external)
  external = transaction.instance_variable_get(:@_external)
  # ...
end
# Fallback: default to "External"
```
If the deduplicator runs but no inbound match exists (because intra-account transfers have the same `account_id` — the deduplicator skips same-account matches), they get flagged as external.

**Fix:**
1. **Improve match logic in `TransferDeduplicator`** — Currently `next if inbound_txn.account_id == out_account_id` prevents matching within the same account. For intra-account transfers between the USER's accounts (different `account_id` but same user), this should work. The issue may be that the matching window (±1 day, ±1% amount) is too tight. Loosen or add a secondary match pass.

2. **Add user-level account lookup** — After deduplication, check if unmatched outbound transactions have a counterparty that is one of the user's own accounts. If so, mark as internal.

3. **Update RowComponent** — Ensure `transfer_badge` respects the flag correctly and has a meaningful fallback:
   ```ruby
   def transfer_badge
     if transaction.instance_variable_defined?(:@_external)
       external = transaction.instance_variable_get(:@_external)
       if external
         { class: "badge badge-warning badge-sm", label: "External" }
       else
         { class: "badge badge-info badge-sm", label: "Internal" }
       end
     else
       { class: "badge badge-ghost badge-sm", label: "Unknown" }
     end
   end
   ```

**Acceptance:**
- Transfers between user's own accounts show "Internal" badge.
- Transfers to/from external accounts show "External" badge.

---

### 5B. BUG-7-010: Transfer Summary Cards Show Wrong Metrics

**Root Cause:**
`transfers.html.erb` renders `Transactions::SummaryCardComponent` which computes generic metrics (net amount, average, largest expense with hardcoded "FOOD_AND_DRINK" category). These are meaningless for transfers.

**Fix:**

1. **Create `app/components/transactions/transfer_summary_card_component.rb`:**
   ```ruby
   module Transactions
     class TransferSummaryCardComponent < ViewComponent::Base
       include ActionView::Helpers::NumberHelper

       def initialize(transactions:)
         @transactions = Array(transactions)
       end

       private

       attr_reader :transactions

       def total_count
         transactions.size
       end

       def total_inflows
         transactions.select { |t| t.amount.to_f.positive? }.sum { |t| t.amount.to_f }
       end

       def total_outflows_external
         transactions.select { |t| t.amount.to_f.negative? && external?(t) }.sum { |t| t.amount.to_f.abs }
       end

       def total_internal
         transactions.select { |t| !external?(t) }.sum { |t| t.amount.to_f.abs }
       end

       def external?(txn)
         txn.instance_variable_defined?(:@_external) && txn.instance_variable_get(:@_external)
       end
     end
   end
   ```

2. **Create `app/components/transactions/transfer_summary_card_component.html.erb`:**
   ```erb
   <div class="stats stats-vertical lg:stats-horizontal shadow w-full mb-6">
     <div class="stat">
       <div class="stat-title">Total Transfers</div>
       <div class="stat-value"><%= total_count %></div>
       <div class="stat-desc">in this view</div>
     </div>
     <div class="stat">
       <div class="stat-title">Net Inflows</div>
       <div class="stat-value text-success"><%= number_to_currency(total_inflows) %></div>
       <div class="stat-desc">Into your accounts</div>
     </div>
     <div class="stat">
       <div class="stat-title">External Outflows</div>
       <div class="stat-value text-error"><%= number_to_currency(total_outflows_external) %></div>
       <div class="stat-desc">To external accounts</div>
     </div>
     <div class="stat">
       <div class="stat-title">Internal Moves</div>
       <div class="stat-value"><%= number_to_currency(total_internal) %></div>
       <div class="stat-desc">Between your accounts</div>
     </div>
   </div>
   ```

3. **Update `transfers.html.erb`** — Replace both instances of:
   ```erb
   <%= render Transactions::SummaryCardComponent.new(transactions: @transactions) %>
   ```
   With:
   ```erb
   <%= render Transactions::TransferSummaryCardComponent.new(transactions: @transactions) %>
   ```

**Files changed:**
- `app/components/transactions/transfer_summary_card_component.rb` (new)
- `app/components/transactions/transfer_summary_card_component.html.erb` (new)
- `app/views/transactions/transfers.html.erb` (update component reference × 2)

**Acceptance:**
- Transfer view shows: Total Transfers, Net Inflows, External Outflows, Internal Moves.
- No mention of "Largest Expense" or spending categories.
- Numbers make sense relative to the transfer data.

---

### 5C. BUG-7-013: Transfer Description Field Not Displayed

**Fix:**

1. **`app/components/transactions/grid_component.html.erb`** — In the transfers-specific `<th>` section, after the "Details" column, add a "Description" header:
   ```erb
   <% if transfers_view? %>
     <th class="px-3 py-2 text-left">Details</th>
     <th class="px-3 py-2 text-left">Description</th>
   <% end %>
   ```

2. **`app/components/transactions/row_component.html.erb`** — In the transfers-specific `<td>` section, after the details cell, add:
   ```erb
   <% if transfers_view? %>
     <%# Existing transfer details cell (From → To with arrow) %>
     <td role="cell" class="px-3 py-2 text-sm">
       ...existing content...
     </td>
     <%# NEW: Description cell %>
     <td role="cell" class="px-3 py-2 text-sm text-base-content/70">
       <%= transaction.name.presence || '—' %>
     </td>
   <% end %>
   ```
   Note: The `name` field typically contains the transaction description from Plaid. If there's a separate `description` column, use that instead.

**Files changed:**
- `app/components/transactions/grid_component.html.erb`
- `app/components/transactions/row_component.html.erb`

**Acceptance:**
- Transfers view shows a "Description" column with transaction descriptions.

---

## Verification Checklist (Full Regression)

After all phases are complete, run through this checklist:

| # | Test | Expected | Pass? |
|---|------|----------|-------|
| 1 | Visit `/net_worth/dashboard` | Charts render, no JS errors | |
| 2 | Visit `/net_worth/sectors` | Sector chart renders | |
| 3 | Toggle pie ↔ bar on allocation chart | Charts switch | |
| 4 | Visit `/transactions/regular` | Shows current month's cash transactions | |
| 5 | Click "Next" on page 1 | Page 2 shows transactions | |
| 6 | Click through all pages | Each page shows data | |
| 7 | Date filters pre-populated with current month | Both fields filled | |
| 8 | Change date range, click Apply | Table updates to match range | |
| 9 | Click "Clear" | Resets to current month | |
| 10 | Visit `/transactions/investment` | Shows investment transactions | |
| 11 | Visit `/transactions/credit` | Shows credit transactions | |
| 12 | Visit `/transactions/transfers` | Shows transfer transactions | |
| 13 | Transfer summary cards | Show Inflows / External Outflows / Internal Moves | |
| 14 | Transfer rows show Internal/External badges | Correct classification | |
| 15 | Transfer rows show Description column | Descriptions visible | |
| 16 | Visit `/transactions/summary` | Filter bar present, cards show filtered data | |
| 17 | Change dates on summary page | Cards and tables update | |
| 18 | No "Type" dropdown in any filter bar | Removed from all views | |
| 19 | Recent transaction date | Within last 24-48 hours | |
| 20 | Turbo Frame navigation between tabs | No broken state, charts redraw | |

---

## Files Changed Summary

| Phase | New Files | Modified Files |
|-------|-----------|----------------|
| 1A | — | Depends on diagnosis (sync service, jobs, Plaid items) |
| 1B | `lib/tasks/backfill_sti.rake` (possibly) | `app/services/plaid_transaction_sync_service.rb`, `app/models/transaction.rb` |
| 1C | — | `app/services/transaction_grid_data_provider.rb`, `app/services/transfer_deduplicator.rb` |
| 2A | — | `vendor/javascript/chart.js.js`, `config/importmap.rb`, `app/javascript/application.js` |
| 3A | — | `app/components/transactions/grid_component.rb`, `app/components/transactions/grid_component.html.erb` |
| 3B | `app/controllers/concerns/default_date_range.rb` | `app/controllers/transactions_controller.rb` |
| 4A | — | `app/controllers/transactions_controller.rb`, `app/views/transactions/_summary_content.html.erb` or `summary.html.erb` |
| 4B | — | (Resolved by 3B + 4A) |
| 4C | — | `app/components/transactions/filter_bar_component.html.erb`, `app/components/transactions/filter_bar_component.rb` |
| 5A | — | `app/services/transfer_deduplicator.rb`, `app/components/transactions/row_component.rb` |
| 5B | `app/components/transactions/transfer_summary_card_component.rb`, `app/components/transactions/transfer_summary_card_component.html.erb` | `app/views/transactions/transfers.html.erb` |
| 5C | — | `app/components/transactions/grid_component.html.erb`, `app/components/transactions/row_component.html.erb` |

---

## Risk Notes

1. **Phase 1A** is diagnostic — the fix depends on what's broken. Budget time for investigation.
2. **Phase 1B** STI backfill must be tested carefully — wrong type assignments break views.
3. **Phase 2A** Chart.js import fix may need iteration. Have the `<script>` tag fallback ready.
4. **Phase 3B** date defaults change behavior for all users. Ensure "all time" view is still accessible (user can clear and submit with empty dates — handle this edge case in the concern by checking for explicit blank params).
5. **Phase 5A** transfer classification is heuristic-based. Plaid doesn't always provide counterparty info. Accept that some transfers may be "Unknown" rather than force a guess.
