# Epic 7: Real Transaction Views Implementation

**Epic Overview**

Build production-ready transaction views (Cash, Credit, Investments, Transfers, Summary) using real Plaid-synced data from the Transaction model. Replace all mock data paths with live database queries via a new `TransactionGridDataProvider` service mirroring the `HoldingsGridDataProvider` pattern. Enhance existing `Transactions::*` ViewComponents (delivered in Epic-6) with live data wiring, user-scoped queries, STI reclassification, account filtering, recurring detection via Plaid's `RecurringTransaction` model, transfers deduplication, and aggregated summary views.

**User Capabilities**
- View all transaction types (cash, credit, investment, transfers) filtered by account
- See real Plaid-synced data with proper STI categorization (no mock data)
- Filter transactions by account using the reusable SavedAccountFilter component
- Identify recurring expenses via Plaid's authoritative recurring detection
- View deduplicated internal transfers (outbound leg canonical, inbound suppressed)
- See aggregated summary with spending totals, top categories, and recurring expenses

**Fit into Big Picture**

Enables HNW families to see full cash flow patterns (spending vampires, internal transfers, recurring liabilities) alongside holdings/net worth — core to the AI tutor curriculum for wealth preservation. Completes the transition from static mockups (Epic-6) to production-ready views backed by live Plaid data. Follows Epic-5 (Holdings Grid) patterns for consistency across the portfolio platform.

**Reference Documents**
- Epic-5: Investment Holdings Grid View (`knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/`)
- Epic-6: Transaction UI Mocks (`knowledge_base/epics/wip/NextGen/Epic-6-transaction-ui-mocks/`)
- `HoldingsGridDataProvider` — service pattern to mirror (`app/services/holdings_grid_data_provider.rb`)
- `Transactions::GridComponent` — existing component to wire (`app/components/transactions/grid_component.rb`)
- Φ5/Φ6 feedback cycle: `feedback/Epic-7-feedback-V1.md`, `feedback/Epic-7-response-V1.md`, `feedback/Epic-7-architect-signoff-V1.md`

---

### Key Decisions Locked In

Decisions from Φ5/Φ6 Cycle V1 (Feb 20, 2026). **Do not re-litigate.**

**Architecture / Boundaries**
- New service: `TransactionGridDataProvider` mirroring `HoldingsGridDataProvider` (user scoping, pagination, sorting, filtering, Result struct)
- New service: `TransferDeduplicator` for matching transfer leg pairs
- STI reclassification added to `PlaidTransactionSyncService` (account-type driven, uses `update_column` to bypass `type_immutable` validation)
- One-time `rake transactions:backfill_sti_types` task in PRD-7.1 scope
- Complete removal of mock data infrastructure: `USE_MOCK_DATA` flag, `MockTransactionDataProvider`, `process_mock_transactions` helper, `config/mock_transactions/*.yml`
- `SavedAccountFilterSelectorComponent` made fully generic (pass any `path_helper` as param), no transaction-specific variant
- Recurring detection via Plaid's `RecurringTransaction` model (already synced), in-memory heuristic as display-only fallback
- No new models/migrations except: composite index `[:type, :account_id, :date]` and STI reclassification logic
- Existing Epic-6 components (`Transactions::GridComponent`, `RowComponent`, `FilterBarComponent`, `SummaryCardComponent`, `MonthlyGroupComponent`) are enhanced, not rebuilt

**Data / Security**
- All transaction queries MUST be scoped to `current_user`:
  ```ruby
  Transaction.joins(account: :plaid_item)
             .where(plaid_items: { user_id: current_user.id })
  ```
- Scoping enforced at service layer (`TransactionGridDataProvider`) — controllers cannot accidentally leak unscoped data
- STI reclassification rules (both use `update_column` to bypass `type_immutable`):
  - `account.investment?` → `InvestmentTransaction`
  - `account.credit?` → `CreditTransaction`
  - All others remain `RegularTransaction`

**Transfer Definition**
- Primary filter: `personal_finance_category_label LIKE 'TRANSFER%'` (483 rows in dev, richer than subtype-only)
- Secondary hint: `subtype IN ('transfer', 'deposit', 'withdrawal')`
- Exclusion: Skip if `account.plaid_account_type == 'investment'` (brokerage internal activity)
- Dedup matching key: date ±1 day, opposite sign, abs(amount) within 1%, different account_ids
- Canonical leg: outbound/negative shown, inbound/positive suppressed if matched
- Unmatched externals: show with "External" badge

**Testing**
- Minitest exclusively for unit and integration tests (never RSpec)
- Capybara + Minitest for system tests
- Test files in `test/` directory (never `spec/`)

**Observability**
- `Rails.logger.error` for sync service failures and reclassification issues
- No new Sentry/metrics in this epic scope

---

### High-Level Scope & Non-Goals

**In scope**
- `TransactionGridDataProvider` service with user-scoped queries, pagination, sorting, filtering
- STI reclassification in sync service + one-time backfill rake task
- Mock data infrastructure removal
- Composite database index for query performance
- Global account filter integration via generic `SavedAccountFilterSelectorComponent`
- Type-specific view enhancements (cash, credit, investment columns/badges)
- Transfer view with deduplication logic
- Summary view with aggregated stats and recurring expenses from `RecurringTransaction`
- Performance tuning (N+1 detection, query optimization)

**Non-goals / deferred**
- Advanced AI analysis of spending patterns (post-stability)
- CSV transaction export
- Full-text search backend (Elasticsearch/pg_search)
- Custom recurring detection engine (use Plaid's)
- Transaction enrichment beyond what Plaid provides
- Multi-family/household transaction aggregation

---

### PRD Summary Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Status |
|----------|-----------|-------|--------------|------------------|--------|
| 7-01 | Transaction Grid Data Provider & Controller Wiring | Data provider service, mock removal, STI fix in sync, backfill rake, composite index, controller refactor | None | `feature/prd-7-01-data-provider-wiring` | Not Started |
| 7-02 | Global Account Filter & Filter Bar Refinements | SavedAccountFilter generic reuse, Turbo filter updates, filter bar wiring to live data | PRD-7.1 | `feature/prd-7-02-account-filter` | Not Started |
| 7-03 | Type-Specific View Enhancements & Transfers Deduplication | Cash/Credit/Investment view polish, TransferDeduplicator service, badges, direction arrows | PRD-7.2 | `feature/prd-7-03-views-transfers` | Not Started |
| 7-04 | Summary View & Recurring Section | Aggregated summary stats, RecurringTransaction integration, top expenses card | PRD-7.3 | `feature/prd-7-04-summary-recurring` | Not Started |
| 7-05 | Performance Tuning & STI Cleanup | Query optimization, N+1 detection, caching strategy, backfill verification | PRD-7.4 | `feature/prd-7-05-performance` | Not Started |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**: Mirror `HoldingsGridDataProvider` → `TransactionGridDataProvider`. Controllers delegate in one line. Services own query logic.
- **Components**: Enhance existing `app/components/transactions/` namespace. Follow `Portfolio::HoldingsGridComponent` patterns.
- **Data Access**: User scoping via join chain (`plaid_items.user_id`). Use `.includes(:account)` to prevent N+1. Paginate via Kaminari on ActiveRecord relations.
- **Error Handling**: Empty state for zero transactions. "Sync in progress" indicator if last sync < 5 min. Graceful handling of soft-deleted transactions (`deleted_at` default scope). Invalid filter params → safe defaults.
- **Empty States**: Every view must show a meaningful empty state ("No transactions found. Try adjusting filters." or "No transactions synced yet for this account.").
- **Accessibility**: DaisyUI table with `role="table"`, `aria-label`. Keyboard-navigable filter controls.
- **Mobile**: Mobile-first DaisyUI responsive tables. Horizontal scroll on narrow viewports. Touch-friendly filter controls (min 44px targets).
- **Security**: All queries scoped to `current_user` via service layer. `authenticate_user!` already present on controller.

---

### Success Metrics

- All 5 transaction views render live Plaid data with zero mock data references
- `InvestmentTransaction.count > 0` and `CreditTransaction.count > 0` after backfill (if credit accounts exist)
- Page load < 500ms for paginated transaction views (25 per page)
- Zero N+1 queries detected in development logs
- Transfer dedup correctly suppresses matched inbound legs

---

### Estimated Timeline

- PRD 7-01: 2-3 days (foundation — data provider, mock removal, STI fix)
- PRD 7-02: 1-2 days (account filter wiring)
- PRD 7-03: 2-3 days (view enhancements + transfer dedup)
- PRD 7-04: 1-2 days (summary + recurring)
- PRD 7-05: 1-2 days (performance pass)
- **Total: ~7-12 days**

---

### Detailed PRDs

---

## PRD-7-01: Transaction Grid Data Provider & Controller Wiring

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

## PRD-7-02: Global Account Filter & Filter Bar Refinements

**Log Requirements**
- Junie: read `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Wire the existing `SavedAccountFilterSelectorComponent` to all transaction views, replacing the current inline `<select>` account dropdown in each view template. Make the component fully generic by renaming the `holdings_path_helper` param to `path_helper` (or accepting any callable) so it works across holdings, transactions, and future views without duplication. Wire the `Transactions::FilterBarComponent` search, date range, and amount fields to the `TransactionGridDataProvider` query params so all filters flow through the data provider as server-side queries.

**User Story:** As a user, I want to filter transactions by my saved account groups (e.g., "Family Trust Accounts", "Brokerage Only") and apply search/date filters, so that I can quickly find specific transactions across any view.

---

### Requirements

#### Functional

1. **Genericize `SavedAccountFilterSelectorComponent`** (`app/components/saved_account_filter_selector_component.rb`):
   - Rename `holdings_path_helper` parameter to `path_helper` (keep `holdings_path_helper` as deprecated alias for backward compatibility during transition)
   - Rename internal `holdings_path` method to `target_path`
   - Update all existing call sites in Holdings views to use new param name
   - Component must work with any route helper (e.g., `:transactions_regular_path`, `:transactions_investment_path`, `:portfolio_holdings_path`)

2. **Add `SavedAccountFilterSelectorComponent` to all transaction views**:
   - Replace the inline `<select name="account">` dropdown in `regular.html.erb`, `investment.html.erb`, `credit.html.erb`, `transfers.html.erb`, `summary.html.erb`
   - Pass `saved_account_filters: current_user.saved_account_filters`, `selected_id: params[:saved_account_filter_id]`, appropriate `path_helper`, and `turbo_frame_id: Transactions::GridComponent::TRANSACTIONS_GRID_TURBO_FRAME_ID`
   - Controller loads `@saved_account_filters = current_user.saved_account_filters` and `@saved_account_filter_id = params[:saved_account_filter_id]`

3. **Wire `TransactionGridDataProvider` to accept `saved_account_filter_id`**:
   - Resolve filter via `user.saved_account_filters.find_by(id: params[:saved_account_filter_id])`
   - Apply criteria (account_ids, institution_ids) to filter the account scope of the transaction query
   - Mirror the `apply_account_filter` pattern from `HoldingsGridDataProvider`

4. **Wire `Transactions::FilterBarComponent` fields to data provider**:
   - `search_term` → data provider's ILIKE query on `name`/`merchant_name`
   - `date_from`/`date_to` → data provider's date range WHERE clause
   - `type_filter` → data provider's STI type filter (for views that show multiple types)
   - Ensure hidden fields preserve `saved_account_filter_id` across filter submissions
   - Add `saved_account_filter_id` to `FilterBarComponent`'s hidden fields

5. **Turbo Frame integration**:
   - Account filter changes and filter bar submissions target `Transactions::GridComponent::TRANSACTIONS_GRID_TURBO_FRAME_ID`
   - Grid + filter bar wrapped in matching Turbo Frame
   - No full page reload on filter change

#### Non-Functional

- All queries scoped to `current_user` via `TransactionGridDataProvider` (inherited from PRD-7.1)
- Filter changes must not cause full page reload (Turbo Frame)
- Account filter dropdown renders in < 50ms (saved filters are lightweight)
- Backward compatible — Holdings views continue to work with renamed param

#### Rails / Implementation Notes

- **Components**: Modify `app/components/saved_account_filter_selector_component.rb` and `.html.erb`
- **Views**: Modify all 5 transaction view templates (`regular`, `investment`, `credit`, `transfers`, `summary`)
- **Controller**: Add `@saved_account_filters` and `@saved_account_filter_id` to each action
- **Service**: Add `saved_account_filter` resolution to `TransactionGridDataProvider`
- **Filter Bar**: Modify `app/components/transactions/filter_bar_component.rb` and `.html.erb` to include `saved_account_filter_id` hidden field

---

### Error Scenarios & Fallbacks

| Scenario | Expected Behavior |
|----------|------------------|
| Invalid `saved_account_filter_id` (deleted or other user's filter) | Ignored — show all accounts (no filter applied) |
| User has zero saved account filters | Dropdown shows only "All Accounts" option + "Manage saved filters" link |
| Filter + search combination returns zero results | Empty state: "No transactions match your filters." |
| Date range where `date_from > date_to` | Treat as invalid — ignore date filter, show all dates |
| Turbo Frame target missing | Graceful degradation — full page reload |

---

### Architectural Context

The `SavedAccountFilterSelectorComponent` is a reusable dropdown that currently only works with Holdings views because it hardcodes `holdings_path_helper`. This PRD genericizes it so any view can use it by passing the appropriate path helper. The component already handles rendering filter options, "All Accounts" reset, and "Manage saved filters" link — no structural changes needed, just the path generation.

The `Transactions::FilterBarComponent` already has search, type filter, and date range fields. It currently includes hidden fields for `sort`, `dir`, `page`, `per_page`, and `account` — we need to add `saved_account_filter_id` and remove the old `account` param (which was for the inline select, now replaced by the SavedAccountFilter component).

---

### Acceptance Criteria

- [ ] `SavedAccountFilterSelectorComponent` accepts generic `path_helper` param (not just holdings)
- [ ] All existing Holdings view call sites updated to use new param name (no regressions)
- [ ] All 5 transaction views show `SavedAccountFilterSelectorComponent` instead of inline `<select>`
- [ ] Selecting a saved filter reloads the grid via Turbo Frame with filtered transactions
- [ ] "All Accounts" option resets filter (no `saved_account_filter_id` param)
- [ ] `TransactionGridDataProvider` filters by saved account filter criteria when `saved_account_filter_id` is present
- [ ] `Transactions::FilterBarComponent` preserves `saved_account_filter_id` in hidden field during search/date submissions
- [ ] Search term filters transactions by name/merchant_name (server-side ILIKE)
- [ ] Date range filters transactions by date (server-side WHERE)
- [ ] Combined filters work (account filter + search + date range)
- [ ] No full page reload on any filter change (Turbo Frame)

---

### Test Cases

#### Unit (Minitest)

- `test/components/saved_account_filter_selector_component_test.rb`:
  - Renders with transaction path helper (`:transactions_regular_path`)
  - Renders with holdings path helper (backward compat)
  - "All Accounts" link uses correct path helper
  - Filter links include `saved_account_filter_id` param

- `test/services/transaction_grid_data_provider_test.rb` (additions):
  - With `saved_account_filter_id`: returns only transactions from matching accounts
  - With `search_term`: returns only matching name/merchant transactions
  - With `date_from`/`date_to`: returns only transactions in range
  - Combined filters: account + search + date all apply correctly

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb` (additions):
  - `GET /transactions/regular?saved_account_filter_id=X` returns filtered results
  - `GET /transactions/regular?search_term=coffee` returns search-filtered results
  - `GET /transactions/regular?date_from=2026-01-01&date_to=2026-01-31` returns date-filtered results

#### System / Smoke (Capybara)

- `test/system/transactions_filter_test.rb`:
  - Visit `/transactions/regular` → account filter dropdown visible
  - Select a saved filter → grid refreshes without full page reload
  - Enter search term + click Apply → grid shows filtered results
  - Click Clear → all filters reset

---

### Manual Verification

1. Visit `/transactions/regular`
2. Verify "Accounts" dropdown shows saved account filters (if any exist)
3. Select a saved filter → transactions reload in Turbo Frame (no full page flash)
4. Enter "interest" in search → click Apply → only interest-related transactions show
5. Set date range to last 30 days → click Apply → only recent transactions show
6. Click Clear → all filters removed, full transaction list shown
7. Visit `/transactions/investment` → repeat steps 2-6
8. Visit `/portfolio/holdings` → verify account filter still works (no regression)

**Expected**
- Account filter dropdown renders on all transaction views
- Filters apply server-side (URL params change, data updates)
- No full page reload — Turbo Frame updates smoothly
- Holdings view still works with the renamed component param

---

### Dependencies

- **Blocked By:** PRD-7.1 (data provider must exist)
- **Blocks:** PRD-7.3 (view enhancements build on filter wiring)

---

### Rollout / Deployment Notes

- No migrations
- Backward-compatible component change (old `holdings_path_helper` param can remain as alias)
- Test Holdings views after deploy to confirm no regression

---

## PRD-7-03: Type-Specific View Enhancements & Transfers Deduplication

**Log Requirements**
- Junie: read `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Polish the Cash, Credit, and Investment transaction views with type-appropriate enhancements (investment-specific columns, credit pending indicators, merchant avatars) and create the `TransferDeduplicator` service that matches transfer leg pairs and shows only the canonical outbound leg. The existing `Transactions::RowComponent` already supports view-type-specific rendering (investment columns, transfer arrows, credit avatars) — this PRD wires those features to live data and builds the deduplication engine.

**User Story:** As a user, I want each transaction view to show relevant columns and details for that type (security info for investments, pending status for credit, direction arrows for transfers with deduplication), so that I can quickly understand my financial activity in context.

---

### Requirements

#### Functional

1. **Cash view polish** (`/transactions/regular`):
   - Show: Date, Name (with recurring badge if applicable), Type badge, Merchant, Account, Amount
   - Category badge from `personal_finance_category_label` (first segment before "→")
   - Merchant column populated from `merchant_name` field on Transaction model

2. **Investment view polish** (`/transactions/investment`):
   - Show: Date, Account (bold), Name, Type badge, Security (icon + link), Quantity, Price, Amount
   - Security link uses `/portfolio/securities/:security_id` path (existing `security_link` method in `RowComponent`)
   - Subtype badge for buy/sell/dividend/interest/split
   - `show_investment_columns: true` already wired in view template

3. **Credit view polish** (`/transactions/credit`):
   - Show: Date, Name (with merchant avatar + pending badge), Type badge, Merchant, Account, Amount
   - Pending transactions highlighted with warning badge (already in `RowComponent#pending?`)
   - Category label from `personal_finance_category_label`

4. **`TransferDeduplicator` service** (`app/services/transfer_deduplicator.rb`):
   - Input: array of transfer transactions (from `TransactionGridDataProvider`)
   - Matching key: date ±1 day, opposite sign, abs(amount) within 1% tolerance, different `account_id`s
   - Output: deduplicated array — outbound/negative leg kept, matched inbound/positive suppressed
   - Unmatched transactions kept with `external: true` flag for "External" badge
   - Investment account transactions excluded before processing (handled by data provider filter)

5. **Transfers view** (`/transactions/transfers`):
   - Wire `TransferDeduplicator` in controller (or data provider) after query
   - Show: Date, Type badge, Transfer Details (From → To with direction arrow + badge), Amount (absolute value)
   - `RowComponent` transfer helpers already exist: `transfer_outbound?`, `transfer_from`, `transfer_to`, `transfer_badge`
   - Update `transfer_from`/`transfer_to` to use `transaction.account.name` (live data) instead of `transaction.account_name` (mock field)

6. **Subtype badge additions to `RowComponent`**:
   - Investment subtypes: "Buy" (green), "Sell" (red), "Dividend" (blue), "Interest" (purple), "Transfer" (gray)
   - Render in a new `subtype_badge` helper method, shown next to type badge

#### Non-Functional

- All queries scoped to `current_user` (inherited from PRD-7.1)
- Transfer deduplication runs in O(n) time (single pass with hash-based matching)
- No additional database queries for deduplication (works on in-memory result set)
- Responsive columns: Merchant/Account columns hidden on mobile (`hidden lg:table-cell` already in template)

#### Rails / Implementation Notes

- **Service**: `app/services/transfer_deduplicator.rb` — new file, ~80-120 lines
- **Component**: Modify `app/components/transactions/row_component.rb` — add `subtype_badge`, update `transfer_from`/`transfer_to` for live data
- **Component template**: Modify `app/components/transactions/row_component.html.erb` — add subtype badge rendering, category label
- **Controller/Data Provider**: Call `TransferDeduplicator` on transfer query results
- **Views**: Minor updates to pass additional params if needed

---

### Error Scenarios & Fallbacks

| Scenario | Expected Behavior |
|----------|------------------|
| Transfer with no matching opposite leg | Show with "External" badge |
| Multiple same-amount transfers on same day between different accounts | Match first pair found; extras remain as unmatched externals |
| Transfer from investment account (brokerage internal) | Excluded by data provider filter (not shown in transfers view) |
| Transaction missing `account` association (orphaned) | Skip in deduplicator; show in view with "—" for account name |
| Transaction with nil amount | Skip in dedup matching; show as-is in view |
| Security ID not found for investment transaction | Show "—" for security; no link |
| `personal_finance_category_label` is nil | Skip category badge rendering |

---

### Architectural Context

The `Transactions::RowComponent` was designed in Epic-6 with view-type awareness — it already supports investment columns (`show_investment_columns`), transfer direction arrows (`transfers_view?`), credit merchant avatars (`credit_view?`), and pending/recurring badges. This PRD completes the wiring to live data where mock data previously provided `account_name`, `security_name`, `target_account_name` as flat strings. With live data, these come from associations (`transaction.account.name`, joined security enrichments).

The `TransferDeduplicator` is a pure-Ruby service that processes an array of transactions and returns a deduplicated array. It does not touch the database — it operates on the result set returned by `TransactionGridDataProvider`.

---

### Acceptance Criteria

- [ ] Cash view shows category label from `personal_finance_category_label` (primary segment)
- [ ] Cash view shows `merchant_name` in Merchant column from Transaction model field
- [ ] Investment view shows Security column with icon and clickable link to `/portfolio/securities/:security_id`
- [ ] Investment view shows Quantity and Price columns from Transaction model fields
- [ ] Investment view shows subtype badge (Buy/Sell/Dividend/Interest/Split) with appropriate colors
- [ ] Credit view shows pending badge on pending transactions
- [ ] Credit view shows merchant avatar (letter initial) next to transaction name
- [ ] `TransferDeduplicator` service exists and passes all 7 edge case tests
- [ ] Transfers view shows deduplicated results (matched inbound legs suppressed)
- [ ] Transfers view shows direction arrows (outbound red →, inbound green ←)
- [ ] Transfers view shows "External" badge for unmatched transfer legs
- [ ] Transfers view shows "Internal" badge for matched internal transfer legs
- [ ] Transfer amounts displayed as absolute values
- [ ] No investment-account transfers appear in transfers view

---

### Test Cases

#### Unit (Minitest)

- `test/services/transfer_deduplicator_test.rb`:
  1. Internal exact match: $1000 out + $1000 in, same day → only outbound returned
  2. Near-amount match: $1000.00 out + $999.87 in → matched, inbound suppressed
  3. Date offset: out Feb 17, in Feb 18 → matched
  4. External: $500 out, no matching inbound → returned with `external: true`
  5. Investment account excluded: brokerage "transfer" → not in input set
  6. Self-transfer (same account): treated as outbound if negative
  7. Multi-leg (wire fee split): amounts don't match → both kept as unmatched

- `test/components/transactions/row_component_test.rb` (additions):
  - Renders subtype badge for investment transactions
  - Renders category label for cash transactions
  - Renders pending badge for credit transactions
  - Renders transfer direction arrow and badge

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb` (additions):
  - `GET /transactions/transfers` returns deduplicated results
  - `GET /transactions/investment` includes investment-specific columns in response

#### System / Smoke (Capybara)

- `test/system/transactions_views_test.rb`:
  - Visit `/transactions/investment` → security links are clickable
  - Visit `/transactions/transfers` → direction arrows visible
  - Visit `/transactions/credit` → pending badges visible on pending transactions

---

### Manual Verification

1. Visit `/transactions/regular` → verify merchant names display from live data, category labels visible
2. Visit `/transactions/investment` → verify security names with icons, subtype badges (Buy/Sell/Dividend), quantity/price columns
3. Click a security link → navigates to `/portfolio/securities/:id`
4. Visit `/transactions/credit` → verify pending badges on pending transactions, merchant avatars
5. Visit `/transactions/transfers` → verify deduplicated list (count should be less than raw transfer count)
6. Verify direction arrows (red → for outbound, green ← for inbound)
7. Verify "External"/"Internal" badges on transfer rows
8. In `rails console`: compare `TransferDeduplicator.new(transfers).call.size` vs raw transfer count

**Expected**
- Each view type shows relevant columns with live data
- Investment securities are clickable links
- Transfers are deduplicated — fewer rows than raw count
- External transfers badged correctly
- No visual regressions from Epic-6 mock views

---

### Dependencies

- **Blocked By:** PRD-7.2 (filter bar must be wired to data provider)
- **Blocks:** PRD-7.4 (summary view uses aggregated data from all views)

---

### Rollout / Deployment Notes

- No migrations
- `TransferDeduplicator` is a new service file — no impact on existing code
- Component changes are additive (new badges/labels) — low regression risk

---

## PRD-7-04: Summary View & Recurring Section

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

## PRD-7-05: Performance Tuning & STI Cleanup

**Log Requirements**
- Junie: read `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Final optimization pass across all transaction views and the data provider. Verify composite index usage, detect and fix N+1 queries, evaluate caching for summary aggregates, confirm STI backfill completeness, and profile page load times against the 500ms target. This is a quality-gate PRD — it validates that the foundation built in PRDs 7.1–7.4 performs well at scale.

**User Story:** As a user, I want transaction pages to load quickly (< 500ms) even with thousands of transactions, so that navigating my financial data feels responsive.

---

### Requirements

#### Functional

1. **Composite index verification**:
   - Run `EXPLAIN ANALYZE` on the 5 primary query patterns (regular, investment, credit, transfers, summary)
   - Confirm `idx_transactions_type_account_date` is used in all type-filtered queries
   - If not used, investigate and fix (query planner may prefer sequential scan on small tables)
   - Document EXPLAIN output in task log

2. **N+1 query detection and fix**:
   - Enable `Bullet` gem (or manual log inspection) in development
   - Load each transaction view with 25, 50, 100 results per page
   - Fix any detected N+1 queries with appropriate `.includes()`, `.preload()`, or `.eager_load()`
   - Expected eager loads: `:account` (already), potentially `account: :plaid_item` for institution name

3. **STI backfill completeness verification**:
   - Run: `Transaction.where(type: 'RegularTransaction').joins(:account).where(accounts: { plaid_account_type: ['investment', 'credit'] }).count`
   - Expected: 0 (all investment/credit account transactions should be reclassified)
   - If > 0: re-run `rake transactions:backfill_sti_types` and investigate why rows were missed
   - Add a monitoring check (rake task or console snippet) for ongoing verification

4. **Summary query optimization**:
   - Profile summary aggregate queries (`SUM`, `GROUP BY`) with `EXPLAIN ANALYZE`
   - If any aggregate exceeds 200ms, consider:
     - Adding partial indexes (e.g., `WHERE amount > 0` for inflow queries)
     - Caching summary results with `Rails.cache` (TTL: 5 minutes)
     - Materializing monthly totals in a background job

5. **Kaminari pagination tuning**:
   - Verify `page` and `per_page` defaults are sensible (25 default, max 100 for non-"all")
   - Verify `per_page = "all"` doesn't cause memory issues with 13k+ transactions
   - Add warning/cap if "all" is selected and count > 500 (mirror Holdings grid pattern)

6. **Counter cache evaluation**:
   - Assess whether `Account` should have `transactions_count` counter cache
   - If summary views frequently show "X transactions in Account Y", add counter cache
   - If not needed, document decision and skip

7. **Page load time profiling**:
   - Profile all 5 transaction views at 25/page and 100/page
   - Target: < 500ms server response time (measured via `Rails.logger` or `rack-mini-profiler`)
   - Document results in task log with before/after if optimizations applied

#### Non-Functional

- All optimizations must not change user-facing behavior (same data, same rendering)
- Caching (if added) must be invalidated on new transaction sync
- No new dependencies (Bullet gem is development-only)
- Performance results documented for future reference

#### Rails / Implementation Notes

- **Gem**: Add `bullet` to development group in `Gemfile` if not present
- **Config**: Enable Bullet in `config/environments/development.rb`
- **Service**: Potential `.includes()` additions to `TransactionGridDataProvider`
- **Migration**: Potential partial indexes if needed (e.g., `WHERE amount > 0`)
- **Cache**: Potential `Rails.cache.fetch` wrappers in data provider summary mode
- **Rake**: Potential `rake transactions:verify_sti_completeness` task

---

### Error Scenarios & Fallbacks

| Scenario | Expected Behavior |
|----------|------------------|
| Composite index not used by query planner | Force with optimizer hint, or add more specific partial index |
| N+1 detected on `account.plaid_item.institution_name` | Add `.includes(account: :plaid_item)` to data provider |
| STI backfill missed rows (count > 0) | Re-run backfill; investigate `default_sti_type` callback interference |
| Summary cache stale after sync | Invalidate cache key in `SyncTransactionsJob` after successful sync |
| "All" per_page causes OOM on large dataset | Add cap at 1000 rows or show warning like Holdings grid |
| Bullet gem raises false positives | Whitelist specific known patterns in Bullet config |

---

### Architectural Context

This PRD is a quality gate — it validates that the data provider, controller refactor, and view wiring from PRDs 7.1–7.4 perform well under real data volumes. The development database has 13,332 transactions across multiple accounts. Production may have significantly more over time (Plaid syncs accumulate history). Performance tuning now prevents scaling issues later.

The Holdings Grid has a similar performance validation pattern — `HoldingsGridDataProvider` uses `.includes()`, composite indexes, and pagination to maintain sub-500ms response times across thousands of holdings.

---

### Acceptance Criteria

- [ ] `EXPLAIN ANALYZE` output documented for all 5 primary query patterns
- [ ] Composite index `idx_transactions_type_account_date` confirmed used in type-filtered queries
- [ ] Zero N+1 queries detected by Bullet (or manual log inspection) across all views
- [ ] STI backfill completeness: `RegularTransaction` count for investment/credit accounts == 0
- [ ] All 5 transaction views load in < 500ms server response time at 25/page
- [ ] All 5 transaction views load in < 500ms at 100/page
- [ ] Summary view aggregate queries each < 200ms
- [ ] `per_page = "all"` shows warning if count > 500 (like Holdings grid)
- [ ] Counter cache decision documented (added or explicitly deferred with rationale)
- [ ] Performance profiling results documented in task log
- [ ] No user-facing behavior changes (data and rendering identical before/after)

---

### Test Cases

#### Unit (Minitest)

- `test/services/transaction_grid_data_provider_test.rb` (additions):
  - Verify `.includes(:account)` prevents N+1 (use `assert_queries` helper if available)
  - Verify "all" per_page returns complete result set
  - Verify summary mode aggregate queries return correct results (unchanged from PRD-7.4)

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb` (additions):
  - All views respond in < 1 second (generous for test environment)
  - `per_page=all` returns 200 (not error or timeout)

#### System / Smoke (Capybara)

- `test/system/transactions_performance_test.rb`:
  - Visit each view → page loads without timeout
  - Navigate to page 2, page 3 → each loads without delay
  - Select "100" per page → renders without timeout

---

### Manual Verification

1. Open `rails console`:
   - `Transaction.where(type: 'RegularTransaction').joins(:account).where(accounts: { plaid_account_type: ['investment', 'credit'] }).count` → expected: 0
2. Start server with Bullet enabled
3. Visit each transaction view (regular, investment, credit, transfers, summary) with 25/page
4. Check Rails log for Bullet warnings — should be zero N+1 alerts
5. Check Rails log for response times — all < 500ms
6. Visit `/transactions/regular?per_page=100` → loads within 500ms
7. Visit `/transactions/summary` → all stat cards load quickly
8. Run `EXPLAIN ANALYZE` in `rails dbconsole`:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM transactions
   WHERE type = 'RegularTransaction'
   AND account_id IN (SELECT id FROM accounts WHERE id IN (SELECT account_id FROM plaid_items WHERE user_id = 1))
   ORDER BY date DESC
   LIMIT 25;
   ```
   → Confirm index scan (not sequential scan)

**Expected**
- All views load in < 500ms
- Zero N+1 warnings
- Composite index used in query plans
- STI backfill complete
- Performance results documented

---

### Dependencies

- **Blocked By:** PRD-7.4 (all views and data wiring must be complete)
- **Blocks:** None (final PRD in epic)

---

### Rollout / Deployment Notes

- Potential migration if partial indexes added (non-breaking, concurrent creation)
- Bullet gem is development-only — no production impact
- Cache additions (if any) require `Rails.cache` backend configured (already present via Solid Cache or Redis)
- Document performance baseline in task log for future comparison

---

### Next Steps

1. ✅ Epic directory confirmed: `knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/`
2. Architect reviews PRD-7.1 for template compliance (brief Φ5 V2)
3. Eric approves → Coding Agent creates `0001-IMPLEMENTATION-STATUS.md` and individual PRD files (Φ7)
4. Coding Agent creates implementation plan (Φ8)
5. Architect scores plan (Φ9 gate)
6. Proceed with PRD-7.1 implementation
