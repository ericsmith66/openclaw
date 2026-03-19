#### PRD-7-01: Transaction Grid Data Provider & Controller Wiring

**Log Requirements**
- Junie: read `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Replace all mock data paths in `TransactionsController` with live database queries via a new `TransactionGridDataProvider` service. This service mirrors `HoldingsGridDataProvider` — it owns user scoping, pagination, sorting, filtering, and returns a clean Result struct. Additionally, fix STI reclassification in the sync service so transactions are correctly typed (`InvestmentTransaction`, `CreditTransaction`, `RegularTransaction`) based on their account type, add a one-time backfill rake task for existing data, add a composite database index for query performance, and completely remove all mock data infrastructure.

**User Story:** As a user, I want to see my real Plaid-synced transactions in all views (cash, credit, investments, transfers, summary) so that I'm viewing actual financial data instead of static mock data.

---

### Requirements

#### Functional

1. **`TransactionGridDataProvider` service** (`app/services/transaction_grid_data_provider.rb`):
   - Initialize with `(user, params)` — mirrors `HoldingsGridDataProvider` signature
   - Return `Result` struct with: `transactions`, `summary` (totals hash), `total_count`
   - User scoping: `Transaction.joins(account: :plaid_item).where(plaid_items: { user_id: user.id })`
   - STI type filtering: accept `type_filter` param mapping to STI classes (`RegularTransaction`, `InvestmentTransaction`, `CreditTransaction`)
   - Transfer filtering: `personal_finance_category_label LIKE 'TRANSFER%'` with `account.plaid_account_type != 'investment'` exclusion
   - Pagination: Kaminari `.page(n).per(per_page)` on ActiveRecord relation (not in-memory)
   - Sorting: server-side `ORDER BY` with column whitelist (`date`, `name`, `amount`, `merchant_name`, `type`, `subtype`)
   - Date range filtering: `date >= date_from AND date <= date_to`
   - Search: `WHERE name ILIKE '%term%' OR merchant_name ILIKE '%term%'`
   - Account filtering: accept `account_filter_id` param, resolve via `user.saved_account_filters`
   - Summary stats: total inflow, total outflow, net, transaction count for current filter

2. **Controller refactor** (`app/controllers/transactions_controller.rb`):
   - Remove `USE_MOCK_DATA` flag and all conditional branches
   - Remove `process_mock_transactions`, `sort_transactions`, `extract_account_names`, `deduplicate_transfers` private methods
   - Each action (`regular`, `investment`, `credit`, `transfers`, `summary`) delegates to `TransactionGridDataProvider.new(current_user, params.merge(type_filter: X)).call`
   - Assign `@transactions`, `@total_count`, `@page`, `@per_page`, `@sort`, `@dir` etc. from Result
   - Keep `index`, `show`, `new`, `edit`, `create`, `update`, `destroy` CRUD actions unchanged

3. **STI reclassification in sync service** (`app/services/plaid_transaction_sync_service.rb`):
   - After `transaction.save!` in `process_added`, add:
     ```ruby
     if transaction.account&.investment? && transaction.type == "RegularTransaction"
       transaction.update_column(:type, "InvestmentTransaction")
     end
     if transaction.account&.credit? && transaction.type == "RegularTransaction"
       transaction.update_column(:type, "CreditTransaction")
     end
     ```
   - Uses `update_column` to bypass `type_immutable` validation (PRD-0160.02)

4. **Backfill rake task** (`lib/tasks/transactions.rake`):
   - `rake transactions:backfill_sti_types`
   - Iterates `Transaction.find_in_batches(batch_size: 1000)`, reclassifies based on `account.plaid_account_type`
   - Idempotent — only changes `RegularTransaction` → specific type if account type matches
   - Respects `default_scope { where(deleted_at: nil) }` — skips soft-deleted
   - Outputs progress dots and final count

5. **Database migration**:
   - Add composite index: `add_index :transactions, [:type, :account_id, :date], name: "idx_transactions_type_account_date"`

6. **Mock data removal**:
   - Delete `app/services/mock_transaction_data_provider.rb`
   - Delete `config/mock_transactions/` directory (all YAML files)
   - Remove `USE_MOCK_DATA` constant from controller
   - Remove `process_mock_transactions` and related helper methods
   - Remove `TransactionRecurringDetector` calls from controller (recurring handled by `RecurringTransaction` model in PRD-7.4)

#### Non-Functional

- All queries scoped to `current_user` via `plaid_items.user_id` join — enforced at service layer
- Pagination via Kaminari on ActiveRecord relation (not in-memory array slicing)
- `.includes(:account)` on all queries to prevent N+1
- Sort column whitelist to prevent SQL injection via `Arel.sql`
- Response time < 500ms for 25-per-page queries on 13k+ transactions

#### Rails / Implementation Notes

- **Models**: No schema changes to `Transaction`. STI subclasses (`InvestmentTransaction`, `CreditTransaction`, `RegularTransaction`) already exist as empty subclasses.
- **Service**: `app/services/transaction_grid_data_provider.rb` — new file, ~200-300 lines
- **Controller**: `app/controllers/transactions_controller.rb` — major refactor (remove ~150 lines of mock logic, replace with ~5 lines per action)
- **Migration**: `db/migrate/YYYYMMDD_add_composite_index_to_transactions.rb`
- **Rake**: `lib/tasks/transactions.rake` — new file
- **Routes**: No changes (all routes already exist)
- **Views**: No changes needed — views already render `Transactions::GridComponent` which accepts the same params

---

### Error Scenarios & Fallbacks

| Scenario | Expected Behavior |
|----------|------------------|
| User has zero synced transactions | Empty state: "No transactions synced yet. Link an account to get started." |
| Account filter returns zero results | Empty state: "No transactions found for this account. Try adjusting filters." |
| Invalid sort column param | Fallback to default sort (`date DESC`) |
| Invalid page/per_page param | Fallback to page 1, 25 per page |
| Database timeout on large result set | Pagination enforced; `per_page` capped at 100 (except "all") |
| Plaid sync in progress | Show stale data with "Last synced X minutes ago" indicator (from `plaid_item.last_transactions_sync`) |
| Soft-deleted transaction in results | Excluded by `default_scope { where(deleted_at: nil) }` — no action needed |
| STI backfill encounters nil account | Skip row (log warning), continue batch |

---

### Architectural Context

This PRD establishes the data foundation for all subsequent PRDs. It replaces in-memory mock data processing with proper ActiveRecord query patterns. The service object pattern mirrors `HoldingsGridDataProvider` (574 lines) which handles user scoping, saved account filters, pagination, sorting, asset class filtering, snapshot mode, and multi-account grouping — all returning a clean `Result` struct consumed by `Portfolio::HoldingsGridComponent`.

The `TransactionGridDataProvider` is simpler (no snapshot mode, no multi-account grouping) but follows the same contract: `initialize(user, params)` → `call` → `Result`. Controllers become thin delegators. Views continue to receive the same data shape they already expect from mock data processing.

STI reclassification is critical because currently all 13,332 transactions are `RegularTransaction` despite ~73% being investment transactions (buy/sell/interest/dividend). Without the backfill + sync fix, investment and credit views will show zero results.

---

### Acceptance Criteria

- [ ] `TransactionGridDataProvider` service exists, returns `Result` struct with `transactions`, `summary`, `total_count`
- [ ] All transaction queries are scoped to `current_user` via `plaid_items.user_id` join — verified by test
- [ ] `USE_MOCK_DATA` flag removed from `TransactionsController`
- [ ] `MockTransactionDataProvider` service deleted
- [ ] `config/mock_transactions/` directory deleted
- [ ] `process_mock_transactions` and related helper methods removed from controller
- [ ] Each controller action (`regular`, `investment`, `credit`, `transfers`, `summary`) delegates to data provider
- [ ] STI reclassification logic added to `PlaidTransactionSyncService#process_added`
- [ ] `rake transactions:backfill_sti_types` exists and is idempotent
- [ ] After running backfill: `InvestmentTransaction.count > 0` (verified in `rails console`)
- [ ] After running backfill: `CreditTransaction.count > 0` if credit accounts exist
- [ ] Composite index `[:type, :account_id, :date]` exists in schema
- [ ] Pagination works via Kaminari on ActiveRecord relation (not in-memory)
- [ ] Sort by date/name/amount works server-side via `ORDER BY`
- [ ] All existing views render with live data (no visual regressions from mock data)
- [ ] No N+1 queries in development log for transaction list pages

---

### Test Cases

#### Unit (Minitest)

- `test/services/transaction_grid_data_provider_test.rb`:
  - Returns scoped transactions for user (other users' transactions excluded)
  - Filters by STI type correctly (`RegularTransaction`, `InvestmentTransaction`, `CreditTransaction`)
  - Filters transfers by `personal_finance_category_label LIKE 'TRANSFER%'` excluding investment accounts
  - Paginates correctly (page 1 returns first N, page 2 returns next N)
  - Sorts by date DESC by default
  - Sorts by name/amount when requested
  - Returns correct summary stats (inflow, outflow, net, count)
  - Handles empty result set gracefully
  - Applies date range filter correctly
  - Applies search term filter (ILIKE on name/merchant_name)

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb`:
  - `GET /transactions/regular` returns 200 with live data (no mock references)
  - `GET /transactions/investment` returns 200 with `InvestmentTransaction` records only
  - `GET /transactions/credit` returns 200 with `CreditTransaction` records only
  - `GET /transactions/transfers` returns 200 with transfer-categorized records
  - `GET /transactions/summary` returns 200
  - User A cannot see User B's transactions
  - Pagination params (`page`, `per_page`) work correctly
  - Sort params (`sort`, `dir`) work correctly
  - Invalid params fall back to defaults

#### System / Smoke (Capybara)

- `test/system/transactions_test.rb`:
  - Visit `/transactions/regular` → sees transaction table with real data
  - Visit `/transactions/investment` → sees investment transactions (if any exist after backfill)
  - Sort by amount → table reorders correctly
  - Navigate to page 2 → different transactions shown

---

### Manual Verification

1. Run `rake transactions:backfill_sti_types`
2. Open `rails console`:
   - `Transaction.group(:type).count` → should show distribution across types
   - `InvestmentTransaction.count` → should be > 0
3. Visit `/transactions/regular` — see real depository transactions
4. Visit `/transactions/investment` — see real investment transactions (buy/sell/dividend)
5. Visit `/transactions/credit` — see real credit card transactions (if credit accounts linked)
6. Visit `/transactions/transfers` — see transfer-categorized transactions
7. Visit `/transactions/summary` — see summary stats
8. Log out and log in as different user → confirm data isolation

**Expected**
- All views show real Plaid data, not mock YAML data
- No "Starbucks"/"Whole Foods" mock entries visible
- Investment view shows buy/sell/dividend transactions from brokerage accounts
- Transaction counts match `rails console` queries
- No errors in Rails development log

---

### Dependencies

- **Blocked By:** None (this is the foundation PRD)
- **Blocks:** PRD-7.2 (Account Filter), PRD-7.3 (Views + Transfers), PRD-7.4 (Summary + Recurring), PRD-7.5 (Performance)

---

### Rollout / Deployment Notes

- **Migration:** `add_index :transactions, [:type, :account_id, :date]` — safe to run in production (concurrent index creation recommended for large tables)
- **Post-deploy human step:** Run `rake transactions:backfill_sti_types` once to reclassify existing transactions
- **Monitoring:** Check `Rails.logger` for any backfill warnings (nil account rows skipped)
- **Rollback:** If data provider has issues, mock data code will already be deleted — ensure branch is tested thoroughly before merge

---
