#### PRD-7-04: Summary View & Recurring Section

**Log Requirements**
- Junie: read `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Replace the mock-data-driven Summary view with live aggregated queries. Build the summary stats (total inflow, total outflow, net, top categories, top merchants, monthly totals) from `TransactionGridDataProvider` aggregate queries. Integrate Plaid's `RecurringTransaction` model (already synced via `/transactions/recurring/get`) to populate the "Top Recurring Expenses" card with authoritative recurring data. The existing `TransactionRecurringDetector` module is kept as a lightweight display-only fallback for per-row recurring badges on paginated views.

**User Story:** As a user, I want to see a summary dashboard of my transaction activity with spending totals, top categories, top merchants, monthly trends, and top recurring expenses, so that I can quickly understand where my money goes.

---

### Requirements

#### Functional

1. **Summary stats from live data** (controller or data provider):
   - Total inflow: `SUM(amount) WHERE amount > 0` (scoped to user)
   - Total outflow: `SUM(amount) WHERE amount < 0` (scoped to user)
   - Net: inflow + outflow
   - Total transaction count
   - All queries scoped to `current_user` and optionally to `saved_account_filter_id`

2. **Top categories card**:
   - `GROUP BY personal_finance_category_label` (primary segment before "→")
   - `ORDER BY COUNT(*) DESC LIMIT 10`
   - Display: category name, count, total amount

3. **Top merchants card**:
   - `GROUP BY merchant_name WHERE merchant_name IS NOT NULL`
   - `ORDER BY COUNT(*) DESC LIMIT 10`
   - Display: merchant name, count, total amount

4. **Monthly totals card**:
   - `GROUP BY DATE_TRUNC('month', date)` ordered by month DESC
   - Display: month label (e.g., "Jan 2026"), total amount, color-coded positive/negative

5. **Top Recurring Expenses card** (from `RecurringTransaction` model):
   - Query: `RecurringTransaction.joins(:plaid_item).where(plaid_items: { user_id: current_user.id }).where(stream_type: 'outflow').order(average_amount: :desc).limit(5)`
   - Display: description/merchant_name, frequency, average_amount, last_date
   - "See all recurring →" link to `/transactions/regular?recurring=true` (or dedicated recurring page)
   - Replace current mock `TransactionRecurringDetector.top_recurring` call in controller

6. **Update `Transactions::SummaryCardComponent`** (`app/components/transactions/summary_card_component.rb`):
   - Replace in-memory calculations with pre-computed summary hash from data provider
   - Accept `summary:` hash instead of `transactions:` array
   - Update template to render from hash keys

7. **Per-row recurring badge** (display-only fallback):
   - Keep `TransactionRecurringDetector` for marking `is_recurring` on paginated row sets in non-summary views
   - No database writes — purely display convenience
   - Cross-reference with `RecurringTransaction` stream_ids if feasible (match by merchant_name)

#### Non-Functional

- Summary queries should use aggregate SQL (`SUM`, `GROUP BY`) — not load all transactions into memory
- Summary page load < 500ms (aggregate queries on indexed columns)
- `RecurringTransaction` query uses existing `plaid_item_id` + `stream_id` unique index
- Account filter applies to all summary stats (user sees summary for filtered accounts only)

#### Rails / Implementation Notes

- **Controller**: `summary` action delegates to `TransactionGridDataProvider.new(current_user, params.merge(summary_mode: true)).call`
- **Data Provider**: Add `summary_mode` that returns aggregate stats hash instead of paginated rows
- **Component**: Modify `app/components/transactions/summary_card_component.rb` to accept summary hash
- **View**: Modify `app/views/transactions/summary.html.erb` to use live data, remove `@summary_data` (mock hash)
- **RecurringTransaction query**: New method on controller or small service, querying `RecurringTransaction` model directly
- **No new models or migrations**

---

### Error Scenarios & Fallbacks

| Scenario | Expected Behavior |
|----------|------------------|
| User has zero transactions | Summary shows all zeroes: "$0.00 inflow, $0.00 outflow, $0.00 net" |
| No `RecurringTransaction` records synced | "Top Recurring" card hidden or shows "No recurring data available" |
| `personal_finance_category_label` is nil on many transactions | Category card shows "Uncategorized" bucket for nil/blank labels |
| `merchant_name` is nil on many transactions | Merchant card excludes nil merchants (query has `WHERE merchant_name IS NOT NULL`) |
| Account filter returns zero matching transactions | Summary shows all zeroes for that filter |
| Aggregate query timeout on very large transaction set | Indexes on `type`, `account_id`, `date`, `personal_finance_category_label` should keep under 500ms |

---

### Architectural Context

The current `summary.html.erb` view reads from `@summary_data` (a mock hash from YAML) and `@top_recurring` (computed by `TransactionRecurringDetector` on mock arrays). This PRD replaces both with live data: aggregate SQL queries for stats and the `RecurringTransaction` model for recurring expenses.

The `RecurringTransaction` model (schema: `stream_id`, `plaid_item_id`, `description`, `merchant_name`, `frequency`, `average_amount`, `last_amount`, `last_date`, `status`, `stream_type`, `category`) provides Plaid-authoritative recurring data that's far more accurate than any heuristic detection. The `stream_type` field distinguishes `inflow` from `outflow` streams.

The `Transactions::SummaryCardComponent` currently computes stats from an in-memory transactions array. This PRD changes it to accept a pre-computed summary hash so the component is purely presentational (no computation).

---

### Acceptance Criteria

- [ ] Summary view shows total inflow, total outflow, and net from live aggregate queries
- [ ] Summary view shows total transaction count from live data
- [ ] "Top Categories" card shows top 10 categories by count from `personal_finance_category_label`
- [ ] "Top Merchants" card shows top 10 merchants by count from `merchant_name`
- [ ] "Monthly Totals" card shows per-month totals from `DATE_TRUNC('month', date)` aggregation
- [ ] "Top Recurring Expenses" card populated from `RecurringTransaction` model (not mock detector)
- [ ] Recurring card shows: description, frequency, average_amount, last_date
- [ ] Account filter applies to all summary stats (filtered summary matches filtered view counts)
- [ ] `Transactions::SummaryCardComponent` accepts summary hash (not transactions array)
- [ ] No `MockTransactionDataProvider.summary` references remain in controller
- [ ] No `TransactionRecurringDetector.top_recurring` call in summary action (replaced by RecurringTransaction query)
- [ ] Summary page loads < 500ms with 13k+ transactions

---

### Test Cases

#### Unit (Minitest)

- `test/services/transaction_grid_data_provider_test.rb` (additions):
  - Summary mode returns aggregate hash with `total_inflow`, `total_outflow`, `net`, `count`
  - Summary mode returns `top_categories` array
  - Summary mode returns `top_merchants` array
  - Summary mode returns `monthly_totals` hash
  - Summary mode respects `saved_account_filter_id`

- `test/components/transactions/summary_card_component_test.rb`:
  - Renders with summary hash (new interface)
  - Shows "$0.00" for zero values
  - Color-codes positive (green) and negative (red) amounts

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb` (additions):
  - `GET /transactions/summary` returns 200 with live aggregate data
  - `GET /transactions/summary?saved_account_filter_id=X` returns filtered aggregates
  - Response includes recurring expenses from `RecurringTransaction` model

#### System / Smoke (Capybara)

- `test/system/transactions_summary_test.rb`:
  - Visit `/transactions/summary` → stat cards show non-zero values
  - Top categories card visible with real category labels
  - Recurring expenses card shows data (if RecurringTransaction records exist)

---

### Manual Verification

1. Visit `/transactions/summary`
2. Verify total inflow/outflow/net match expected values (cross-check in `rails console`: `Transaction.joins(account: :plaid_item).where(plaid_items: { user_id: User.first.id }).where("amount > 0").sum(:amount)`)
3. Verify "Top Categories" shows real Plaid categories (not "FOOD_AND_DRINK" placeholder)
4. Verify "Top Merchants" shows real merchant names from synced data
5. Verify "Monthly Totals" shows month-by-month breakdown
6. Verify "Top Recurring Expenses" shows data from `RecurringTransaction` (if synced)
7. Apply an account filter → verify all summary stats update to reflect filtered data
8. Compare recurring card data with `rails console`: `RecurringTransaction.joins(:plaid_item).where(plaid_items: { user_id: User.first.id }).where(stream_type: 'outflow').order(average_amount: :desc).limit(5)`

**Expected**
- All stat cards show real numbers from live data
- Categories reflect Plaid's `personal_finance_category_label` taxonomy
- Recurring expenses match `RecurringTransaction` model data
- Account filter updates all cards simultaneously
- No mock data references visible

---

### Dependencies

- **Blocked By:** PRD-7.3 (view enhancements and data wiring complete)
- **Blocks:** PRD-7.5 (performance tuning validates summary query performance)

---

### Rollout / Deployment Notes

- No migrations
- Ensure `RecurringTransaction` data is synced before deploy (run `SyncRecurringTransactionsJob` if not already scheduled)
- Summary component interface change (`transactions:` → `summary:`) — update all call sites in same deploy

---
