# Implementation Plan: PRD-7-04 Summary View & Recurring Section

**Date:** 2026-02-22  
**PRD:** knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/PRD-7-04-summary-recurring.md  
**Implementer:** AiderDesk  
**Status:** Pending Architect Approval

---

## Overview

Replace mock-data-driven Summary view with live aggregate SQL queries and integrate Plaid's RecurringTransaction model for authoritative recurring expense tracking. This plan ensures <500ms page load with 13k+ transactions through efficient aggregate queries on indexed columns.

---

## Current State Analysis

### Existing Implementation
- **Summary View:** Uses `@summary_data` from mock YAML via MockTransactionDataProvider
- **Recurring Data:** Uses `TransactionRecurringDetector.top_recurring` (heuristic, in-memory)
- **Data Provider:** `TransactionGridDataProvider` exists with user-scoping and account filtering
- **Component:** `Transactions::SummaryCardComponent` exists but is NOT used in summary view
- **Model:** `RecurringTransaction` model exists with Plaid-synced data

### Architectural Context
- `TransactionGridDataProvider` follows `HoldingsGridDataProvider` pattern
- Existing composite index: `[:type, :account_id, :date]` on transactions table
- `RecurringTransaction` has unique index on `[:plaid_item_id, :stream_id]`
- Account filtering via `SavedAccountFilter` criteria already implemented

---

## Implementation Phases

### Phase 1: Enhance TransactionGridDataProvider with Summary Mode

**File:** `app/services/transaction_grid_data_provider.rb`

**Objective:** Add summary_mode that returns pre-computed aggregate statistics instead of paginated rows.

**Changes:**

1. **Modify `call` method:**
   ```ruby
   def call
     if summary_mode?
       compute_summary
     else
       # existing pagination logic
     end
   end
   ```

2. **Add `summary_mode?` check:**
   ```ruby
   def summary_mode?
     params[:summary_mode] == true || params[:summary_mode] == "true"
   end
   ```

3. **Add `compute_summary` method:**
   ```ruby
   def compute_summary
     rel = filtered_relation
     
     Result.new(
       transactions: [],
       summary: {
         total_inflow: total_inflow(rel),
         total_outflow: total_outflow(rel),
         net: net_amount(rel),
         count: rel.count,
         top_categories: top_categories(rel),
         top_merchants: top_merchants(rel),
         monthly_totals: monthly_totals(rel)
       },
       total_count: rel.count
     )
   end
   ```

4. **Add aggregate query methods:**

   ```ruby
   private
   
   def total_inflow(rel)
     rel.where("amount > 0").sum(:amount).to_f
   end
   
   def total_outflow(rel)
     rel.where("amount < 0").sum(:amount).to_f
   end
   
   def net_amount(rel)
     rel.sum(:amount).to_f
   end
   
   def top_categories(rel)
     # GROUP BY primary category segment before "→"
     rel
       .where.not(personal_finance_category_label: nil)
       .group(:personal_finance_category_label)
       .select("personal_finance_category_label AS name, COUNT(*) AS count, SUM(amount) AS total")
       .order("count DESC")
       .limit(10)
       .map { |r| { name: r.name, count: r.count, total: r.total.to_f } }
   end
   
   def top_merchants(rel)
     rel
       .where.not(merchant_name: nil)
       .group(:merchant_name)
       .select("merchant_name AS name, COUNT(*) AS count, SUM(amount) AS total")
       .order("count DESC")
       .limit(10)
       .map { |r| { name: r.name, count: r.count, total: r.total.to_f } }
   end
   
   def monthly_totals(rel)
     # PostgreSQL DATE_TRUNC for month grouping
     rel
       .group("DATE_TRUNC('month', transactions.date)")
       .select("DATE_TRUNC('month', transactions.date) AS month, SUM(amount) AS total")
       .order("month DESC")
       .map { |r| [r.month.strftime("%b %Y"), r.total.to_f] }
   end
   ```

**Edge Cases Handled:**
- Nil categories: `WHERE.not(personal_finance_category_label: nil)` or show "Uncategorized"
- Nil merchants: `WHERE.not(merchant_name: nil)`
- Zero transactions: All sums return 0.0, arrays return []
- Account filter: Uses existing `filtered_relation` which applies account filter

---

### Phase 2: Add RecurringTransaction Query Method

**File:** `app/controllers/transactions_controller.rb`

**Objective:** Query RecurringTransaction model for top 5 outflow streams scoped to current user.

**Changes:**

1. **Update `summary` action:**
   ```ruby
   def summary
     permitted = params.permit!
     result = TransactionGridDataProvider.new(current_user, permitted.merge(summary_mode: true)).call
     
     @summary = result.summary
     @total_count = result.total_count
     @top_recurring = top_recurring_expenses
   end
   ```

2. **Add private method `top_recurring_expenses`:**
   ```ruby
   private
   
   def top_recurring_expenses
     recurring = RecurringTransaction
       .joins(:plaid_item)
       .where(plaid_items: { user_id: current_user.id })
       .where(stream_type: 'outflow')
       .order(average_amount: :desc)
       .limit(5)
     
     recurring.map do |r|
       {
         description: r.description || r.merchant_name || "Unknown",
         merchant_name: r.merchant_name,
         frequency: r.frequency,
         average_amount: r.average_amount.to_f,
         last_date: r.last_date
       }
     end
   end
   ```

**Edge Cases:**
- No recurring transactions: Returns empty array `[]`
- Missing description: Falls back to merchant_name, then "Unknown"
- Nil average_amount: `to_f` converts to 0.0

---

### Phase 3: Remove Mock Data Dependencies

**Files:**
- `app/controllers/transactions_controller.rb`

**Changes:**

1. Remove any references to:
   - `MockTransactionDataProvider.summary`
   - `TransactionRecurringDetector.top_recurring`

2. **Keep (DO NOT DELETE):**
   - `TransactionRecurringDetector` module - used for per-row `is_recurring` badges in regular/investment/credit views
   - `MockTransactionDataProvider` file - keep for reference, just don't use in summary action

---

### Phase 4: Update Summary View

**File:** `app/views/transactions/_summary_content.html.erb`

**Objective:** Replace @summary_data with @summary from live data provider.

**Changes:**

1. **Update top stat cards:**
   ```erb
   <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
     <div class="card bg-base-100 shadow">
       <div class="card-body">
         <h2 class="card-title text-sm opacity-70">Total Transactions</h2>
         <p class="text-3xl font-bold"><%= @summary[:count] || 0 %></p>
       </div>
     </div>
     <div class="card bg-base-100 shadow">
       <div class="card-body">
         <h2 class="card-title text-sm opacity-70">Total Inflow</h2>
         <p class="text-3xl font-bold text-success">
           <%= number_to_currency(@summary[:total_inflow] || 0) %>
         </p>
       </div>
     </div>
     <div class="card bg-base-100 shadow">
       <div class="card-body">
         <h2 class="card-title text-sm opacity-70">Total Outflow</h2>
         <p class="text-3xl font-bold text-error">
           <%= number_to_currency(@summary[:total_outflow] || 0) %>
         </p>
       </div>
     </div>
     <div class="card bg-base-100 shadow">
       <div class="card-body">
         <h2 class="card-title text-sm opacity-70">Net</h2>
         <p class="text-3xl font-bold <%= (@summary[:net].to_f >= 0) ? 'text-success' : 'text-error' %>">
           <%= number_to_currency(@summary[:net] || 0) %>
         </p>
       </div>
     </div>
   </div>
   ```

2. **Update Top Recurring Expenses card:**
   ```erb
   <% if @top_recurring.present? %>
     <div class="card bg-base-100 shadow mb-6">
       <div class="card-body">
         <div class="flex justify-between items-center mb-2">
           <h2 class="card-title text-sm">Top Recurring Expenses</h2>
           <%= link_to "See all recurring →", transactions_regular_path(recurring: true), class: "text-sm link link-primary" %>
         </div>
         <div class="overflow-x-auto">
           <table class="table table-zebra table-sm">
             <thead>
               <tr>
                 <th>Description</th>
                 <th>Frequency</th>
                 <th class="text-right">Avg Amount</th>
                 <th>Last Date</th>
               </tr>
             </thead>
             <tbody>
               <% @top_recurring.each do |item| %>
                 <tr>
                   <td class="font-medium"><%= item[:description] %></td>
                   <td><span class="badge badge-ghost badge-sm"><%= item[:frequency] %></span></td>
                   <td class="text-right text-error"><%= number_to_currency(item[:average_amount].abs) %></td>
                   <td class="text-sm opacity-70"><%= item[:last_date]&.strftime("%b %d, %Y") || "N/A" %></td>
                 </tr>
               <% end %>
             </tbody>
           </table>
         </div>
       </div>
     </div>
   <% end %>
   ```

3. **Update Top Categories card:**
   ```erb
   <% if @summary[:top_categories].present? %>
     <div class="card bg-base-100 shadow mb-6">
       <div class="card-body">
         <h2 class="card-title text-sm">Top Categories</h2>
         <div class="overflow-x-auto">
           <table class="table table-zebra table-sm">
             <thead>
               <tr>
                 <th>Category</th>
                 <th class="text-right">Count</th>
                 <th class="text-right">Total</th>
               </tr>
             </thead>
             <tbody>
               <% @summary[:top_categories].each do |cat| %>
                 <tr>
                   <td><%= cat[:name] %></td>
                   <td class="text-right"><%= cat[:count] %></td>
                   <td class="text-right <%= cat[:total].to_f >= 0 ? 'text-success' : 'text-error' %>">
                     <%= number_to_currency(cat[:total]) %>
                   </td>
                 </tr>
               <% end %>
             </tbody>
           </table>
         </div>
       </div>
     </div>
   <% end %>
   ```

4. **Update Top Merchants card:**
   ```erb
   <% if @summary[:top_merchants].present? %>
     <div class="card bg-base-100 shadow mb-6">
       <div class="card-body">
         <h2 class="card-title text-sm">Top Merchants</h2>
         <div class="overflow-x-auto">
           <table class="table table-zebra table-sm">
             <thead>
               <tr>
                 <th>Merchant</th>
                 <th class="text-right">Count</th>
                 <th class="text-right">Total</th>
               </tr>
             </thead>
             <tbody>
               <% @summary[:top_merchants].each do |merchant| %>
                 <tr>
                   <td><%= merchant[:name] %></td>
                   <td class="text-right"><%= merchant[:count] %></td>
                   <td class="text-right <%= merchant[:total].to_f >= 0 ? 'text-success' : 'text-error' %>">
                     <%= number_to_currency(merchant[:total]) %>
                   </td>
                 </tr>
               <% end %>
             </tbody>
           </table>
         </div>
       </div>
     </div>
   <% end %>
   ```

5. **Update Monthly Totals card:**
   ```erb
   <% if @summary[:monthly_totals].present? %>
     <div class="card bg-base-100 shadow">
       <div class="card-body">
         <h2 class="card-title text-sm">Monthly Totals</h2>
         <div class="overflow-x-auto">
           <table class="table table-zebra table-sm">
             <thead>
               <tr>
                 <th>Month</th>
                 <th class="text-right">Total</th>
               </tr>
             </thead>
             <tbody>
               <% @summary[:monthly_totals].each do |month, total| %>
                 <tr>
                   <td><%= month %></td>
                   <td class="text-right <%= total.to_f >= 0 ? 'text-success' : 'text-error' %>">
                     <%= number_to_currency(total) %>
                   </td>
                 </tr>
               <% end %>
             </tbody>
           </table>
         </div>
       </div>
     </div>
   <% end %>
   ```

6. **Add fallback for no data:**
   ```erb
   <% if @summary.blank? || @summary[:count].to_i == 0 %>
     <div class="alert alert-info">
       <div>
         <span>No transactions found. Summary will appear once transactions are synced.</span>
       </div>
     </div>
   <% end %>
   ```

---

### Phase 5: Testing

#### Unit Tests

**File:** `test/services/transaction_grid_data_provider_test.rb`

**New Tests:**

1. **test "summary_mode returns aggregate hash"**
   - Create 10 transactions with varied amounts, dates, categories, merchants
   - Call provider with summary_mode: true
   - Assert summary[:count], summary[:total_inflow], summary[:total_outflow], summary[:net]
   - Assert summary[:top_categories] is array with name/count/total
   - Assert summary[:top_merchants] is array
   - Assert summary[:monthly_totals] is array of [month, total]

2. **test "summary_mode respects saved_account_filter_id"**
   - Create transactions across 2 accounts
   - Create SavedAccountFilter for account A only
   - Call provider with summary_mode: true, saved_account_filter_id: filter.id
   - Assert summary stats only include account A transactions

3. **test "summary_mode with zero transactions"**
   - Call provider with summary_mode: true on user with no transactions
   - Assert summary[:count] == 0
   - Assert summary[:total_inflow] == 0.0
   - Assert summary[:top_categories] == []

4. **test "top_categories excludes nil category labels"**
   - Create transactions with nil personal_finance_category_label
   - Call provider with summary_mode: true
   - Assert summary[:top_categories] does not include nil entries

5. **test "top_merchants excludes nil merchant names"**
   - Create transactions with nil merchant_name
   - Call provider with summary_mode: true
   - Assert summary[:top_merchants] does not include nil entries

#### Integration Tests

**File:** `test/controllers/transactions_controller_test.rb`

**New Tests:**

1. **test "GET summary returns 200 with live data"**
   - Create transactions for current_user
   - GET transactions_summary_path
   - Assert response 200
   - Assert assigns(:summary) present
   - Assert assigns(:summary)[:count] > 0

2. **test "GET summary with saved_account_filter_id"**
   - Create SavedAccountFilter
   - GET transactions_summary_path(saved_account_filter_id: filter.id)
   - Assert response 200
   - Assert filtered stats

3. **test "GET summary with no transactions"**
   - Ensure current_user has no transactions
   - GET transactions_summary_path
   - Assert response 200
   - Assert assigns(:summary)[:count] == 0

4. **test "GET summary populates top_recurring from RecurringTransaction model"**
   - Create RecurringTransaction records for current_user's plaid_item
   - GET transactions_summary_path
   - Assert assigns(:top_recurring).present?
   - Assert assigns(:top_recurring).first[:description]

#### System Tests

**File:** `test/system/transactions_summary_test.rb` (new file)

**Tests:**

1. **test "visiting summary page shows stat cards"**
   - sign_in as user
   - visit transactions_summary_path
   - assert_selector ".stat", count: 4
   - assert_text "Total Transactions"
   - assert_text "Total Inflow"

2. **test "summary page shows top categories card"**
   - Create transactions with categories
   - visit transactions_summary_path
   - assert_selector "h2", text: "Top Categories"
   - assert_selector "table"

3. **test "summary page shows top recurring expenses if data exists"**
   - Create RecurringTransaction for user
   - visit transactions_summary_path
   - assert_selector "h2", text: "Top Recurring Expenses"

4. **test "summary page with no transactions shows fallback message"**
   - Ensure user has no transactions
   - visit transactions_summary_path
   - assert_text "No transactions found"

---

## Dependency Order

1. **Phase 1** (Data Provider) - foundation for all other changes
2. **Phase 2** (Recurring Query) - independent, can be parallel with Phase 1
3. **Phase 3** (Remove Mock) - depends on Phase 1 & 2 being complete
4. **Phase 4** (Update View) - depends on Phase 1 & 2 being complete
5. **Phase 5** (Testing) - depends on all implementation phases

---

## Performance Considerations

### Query Optimization
- **Inflow/Outflow:** Simple SUM with WHERE clause - O(n) scan with existing index
- **Categories:** GROUP BY with index on personal_finance_category_label (may need index)
- **Merchants:** GROUP BY merchant_name (may need index if slow)
- **Monthly:** DATE_TRUNC with GROUP BY - leverages date index

### Index Recommendations
- **Existing:** `[:type, :account_id, :date]` - used by filtered_relation
- **Potential Add:** Index on `personal_finance_category_label` if category aggregation is slow
- **Potential Add:** Index on `merchant_name` if merchant aggregation is slow

### Expected Performance
- With 13k transactions, aggregate queries should complete in <100ms
- Monthly grouping: ~12 groups (months) - very fast
- Category grouping: ~20-30 unique categories - fast
- Merchant grouping: ~100-500 unique merchants - acceptable

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Aggregate queries timeout on large dataset | Use existing indexes; add category/merchant indexes if needed |
| RecurringTransaction data not synced | Graceful fallback: hide card if @top_recurring.blank? |
| Nil categories/merchants break grouping | WHERE.not(column: nil) in queries |
| Zero transactions edge case | All aggregates return 0.0 or [], view shows fallback |
| Account filter not applied | Use filtered_relation as base for all aggregates |
| Component interface change breaks other views | SummaryCardComponent not used in summary view, no impact |

---

## Files to Modify

1. ✅ `app/services/transaction_grid_data_provider.rb` - Add summary_mode
2. ✅ `app/controllers/transactions_controller.rb` - Update summary action
3. ✅ `app/views/transactions/_summary_content.html.erb` - Use live data
4. ✅ `test/services/transaction_grid_data_provider_test.rb` - Add summary tests
5. ✅ `test/controllers/transactions_controller_test.rb` - Add summary controller tests
6. ✅ `test/system/transactions_summary_test.rb` - Add system tests (new file)

## Files NOT Modified

- ❌ `app/components/transactions/summary_card_component.rb` - Not used in summary view
- ❌ `app/services/mock_transaction_data_provider.rb` - Keep for reference
- ❌ `app/helpers/transaction_recurring_detector.rb` - Keep for per-row badges

---

## Acceptance Criteria Checklist

- [ ] Summary view shows total inflow, total outflow, and net from live aggregate queries
- [ ] Summary view shows total transaction count from live data
- [ ] "Top Categories" card shows top 10 categories by count from `personal_finance_category_label`
- [ ] "Top Merchants" card shows top 10 merchants by count from `merchant_name`
- [ ] "Monthly Totals" card shows per-month totals from `DATE_TRUNC('month', date)` aggregation
- [ ] "Top Recurring Expenses" card populated from `RecurringTransaction` model (not mock detector)
- [ ] Recurring card shows: description, frequency, average_amount, last_date
- [ ] Account filter applies to all summary stats (filtered summary matches filtered view counts)
- [ ] `Transactions::SummaryCardComponent` accepts summary hash (DEFERRED - not used in view)
- [ ] No `MockTransactionDataProvider.summary` references remain in controller
- [ ] No `TransactionRecurringDetector.top_recurring` call in summary action (replaced by RecurringTransaction query)
- [ ] Summary page loads < 500ms with 13k+ transactions

---

## Manual Verification Steps

1. Visit `/transactions/summary` → Verify all stat cards show non-zero values
2. Cross-check total_inflow in rails console: `Transaction.joins(account: :plaid_item).where(plaid_items: { user_id: User.first.id }).where("amount > 0").sum(:amount)`
3. Verify "Top Categories" shows real Plaid category labels (not placeholders)
4. Verify "Top Merchants" shows real merchant names from synced data
5. Verify "Monthly Totals" shows month-by-month breakdown in DESC order
6. Verify "Top Recurring Expenses" matches console query: `RecurringTransaction.joins(:plaid_item).where(plaid_items: { user_id: User.first.id }).where(stream_type: 'outflow').order(average_amount: :desc).limit(5)`
7. Apply an account filter → Verify all summary stats update to reflect filtered data
8. Filter to accounts with zero transactions → Verify summary shows all $0.00

---

## Completion Definition

Implementation is complete when:
1. All acceptance criteria are met
2. All unit tests pass (including new summary_mode tests)
3. All integration tests pass
4. All system tests pass
5. Manual verification steps confirm expected behavior
6. No mock data references remain in summary controller action
7. RecurringTransaction query replaces TransactionRecurringDetector in summary view
8. Summary page loads in <500ms with 13k+ transactions (verified via rails console timing)
