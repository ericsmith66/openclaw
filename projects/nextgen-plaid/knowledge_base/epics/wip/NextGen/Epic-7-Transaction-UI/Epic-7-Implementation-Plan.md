# Epic 7: Real Transaction Views — Comprehensive Implementation Plan

**Epic:** Real Transaction Views Implementation
**Created:** February 20, 2026
**Status:** Ready for Architect Review (Φ9)
**Workflow Phase:** Φ8 — Coding Agent creates detailed implementation plan

---

## Document Purpose

This is the **single implementation plan** for all 5 PRDs in Epic 7. Each PRD is broken into atomic, ordered deliverables. PRDs are implemented sequentially (7-01 → 7-02 → 7-03 → 7-04 → 7-05) because each depends on the prior. Within each PRD, deliverables are ordered by dependency and should be completed in sequence.

**Execution model:** One PRD at a time. Each PRD must pass QA (≥90) before the next PRD begins. Each PRD ships on its own feature branch and merges to `main` before the next PRD starts.

---

## Reference Files (Locked-In Context)

| Reference | Path |
|-----------|------|
| Epic overview | `knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/0000-epic.md` |
| Architect signoff | `knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/feedback/Epic-7-architect-signoff-V1.md` |
| Implementation status tracker | `knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/0001-implementation-status.md` |
| HoldingsGridDataProvider (pattern to mirror) | `app/services/holdings_grid_data_provider.rb` |
| TransactionsController (to refactor) | `app/controllers/transactions_controller.rb` |
| PlaidTransactionSyncService (STI fix target) | `app/services/plaid_transaction_sync_service.rb` |
| Existing components | `app/components/transactions/*.rb` |
| SavedAccountFilterSelectorComponent | `app/components/saved_account_filter_selector_component.rb` |
| Transaction views | `app/views/transactions/*.html.erb` |
| Existing tests | `test/controllers/transactions_controller_test.rb`, `test/components/transactions/` |

### Key Decisions (Do Not Re-Litigate)

All architectural decisions are locked in per the Architect Signoff V1 (Feb 20, 2026). See `feedback/Epic-7-architect-signoff-V1.md` for full details. Key constraints:

- User scoping: `joins(account: :plaid_item).where(plaid_items: { user_id: user.id })` — enforced at service layer
- STI reclassification: `update_column(:type, ...)` to bypass `type_immutable` validation
- Transfer filter: `personal_finance_category_label LIKE 'TRANSFER%'`, exclude investment accounts
- Transfer dedup: date ±1 day, opposite sign, abs(amount) within 1%, different account_ids
- Recurring: Plaid `RecurringTransaction` model (authoritative), not custom heuristic
- Testing: Minitest + Capybara exclusively. Test files in `test/` directory.
- Components: Enhance existing Epic-6 components, do not rebuild.

---

## PRD Dependency Chain

```
PRD-7.01 (Foundation: Data Provider + Mock Removal + STI Fix)
  └─→ PRD-7.02 (Account Filter + Filter Bar Wiring)
        └─→ PRD-7.03 (View Enhancements + Transfer Dedup)
              └─→ PRD-7.04 (Summary View + Recurring)
                    └─→ PRD-7.05 (Performance Tuning + Verification)
```

---

---

# PRD 7-01: Transaction Grid Data Provider & Controller Wiring

**Branch:** `feature/prd-7-01-data-provider-wiring`
**Estimated effort:** 2–3 days
**Dependencies:** None (foundation PRD)
**Blocks:** All other PRDs

---

## Deliverable 7-01-A: Database Migration — Composite Index

**Goal:** Add the composite index required by all subsequent query patterns.

**Tasks:**
1. Generate migration: `rails generate migration AddCompositeIndexToTransactions`
2. Add composite index:
   ```ruby
   add_index :transactions, [:type, :account_id, :date],
             name: "idx_transactions_type_account_date",
             algorithm: :concurrently
   ```
3. Run `rails db:migrate` and verify index appears in `db/schema.rb`
4. Verify with `rails dbconsole`: `\d transactions` shows the new index

**Files created/modified:**
- `db/migrate/YYYYMMDD_add_composite_index_to_transactions.rb` (new)
- `db/schema.rb` (auto-updated)

**Acceptance criteria:**
- [ ] Composite index `idx_transactions_type_account_date` exists in schema
- [ ] Migration is reversible

---

## Deliverable 7-01-B: STI Reclassification in Sync Service

**Goal:** Ensure newly synced transactions get the correct STI type based on their account type.

**Tasks:**
1. Read `app/services/plaid_transaction_sync_service.rb` — locate `process_added` method
2. After `transaction.save!` (or `create_or_find_by!`) in `process_added`, add STI reclassification logic:
   ```ruby
   if transaction.account&.investment? && transaction.type == "RegularTransaction"
     transaction.update_column(:type, "InvestmentTransaction")
   end
   if transaction.account&.credit? && transaction.type == "RegularTransaction"
     transaction.update_column(:type, "CreditTransaction")
   end
   ```
3. Add `Rails.logger.error` for any reclassification failure (e.g., nil account)
4. Write unit test: `test/services/plaid_transaction_sync_service_test.rb` — new test cases:
   - Transaction for investment account → type becomes `InvestmentTransaction`
   - Transaction for credit account → type becomes `CreditTransaction`
   - Transaction for depository account → type remains `RegularTransaction`
   - Transaction with nil account → no error, type unchanged

**Files modified:**
- `app/services/plaid_transaction_sync_service.rb`
- `test/services/plaid_transaction_sync_service_test.rb` (add tests)

**Acceptance criteria:**
- [ ] STI reclassification logic added to `process_added`
- [ ] Uses `update_column` to bypass `type_immutable` validation
- [ ] Logs errors for edge cases (nil account)
- [ ] 4 new unit tests pass

---

## Deliverable 7-01-C: Backfill Rake Task

**Goal:** Reclassify all existing `RegularTransaction` records whose account type indicates they should be `InvestmentTransaction` or `CreditTransaction`.

**Tasks:**
1. Create `lib/tasks/transactions.rake`
2. Implement `rake transactions:backfill_sti_types`:
   - `Transaction.find_in_batches(batch_size: 1000)` — respects `default_scope { where(deleted_at: nil) }`
   - For each transaction: check `transaction.account&.plaid_account_type`
   - If `investment?` and type is `RegularTransaction` → `update_column(:type, "InvestmentTransaction")`
   - If `credit?` and type is `RegularTransaction` → `update_column(:type, "CreditTransaction")`
   - Skip rows with nil account (log warning, continue)
   - Output progress dots every 100 rows and final summary count
3. Make idempotent: only changes `RegularTransaction` → specific type (already reclassified rows are skipped)
4. Write test: `test/tasks/transactions_rake_test.rb`:
   - Backfill reclassifies investment account transactions
   - Backfill reclassifies credit account transactions
   - Backfill skips already-reclassified transactions (idempotent)
   - Backfill skips soft-deleted transactions

**Files created:**
- `lib/tasks/transactions.rake` (new)
- `test/tasks/transactions_rake_test.rb` (new)

**Acceptance criteria:**
- [ ] `rake transactions:backfill_sti_types` exists and runs without error
- [ ] Idempotent — running twice produces same result
- [ ] After backfill: `InvestmentTransaction.count > 0`
- [ ] After backfill: `CreditTransaction.count > 0` (if credit accounts exist)
- [ ] Skips soft-deleted rows
- [ ] Outputs progress and summary

---

## Deliverable 7-01-D: TransactionGridDataProvider Service

**Goal:** Create the core data provider service that replaces all mock data logic with live ActiveRecord queries.

**Tasks:**
1. Read `app/services/holdings_grid_data_provider.rb` to understand the pattern (Result struct, initialize/call, user scoping, pagination, sorting, filtering)
2. Create `app/services/transaction_grid_data_provider.rb`:
   - `initialize(user, params)` — mirror HoldingsGridDataProvider signature
   - `call` → returns `Result` struct with `transactions`, `summary`, `total_count`
   - **User scoping:** `Transaction.joins(account: :plaid_item).where(plaid_items: { user_id: user.id })`
   - **STI type filtering:** `type_filter` param → `.where(type: type_class_name)`
   - **Transfer filtering:** `personal_finance_category_label LIKE 'TRANSFER%'` AND exclude investment accounts
   - **Pagination:** Kaminari `.page(n).per(per_page)` on ActiveRecord relation
   - **Sorting:** Server-side `ORDER BY` with column whitelist (`date`, `name`, `amount`, `merchant_name`, `type`, `subtype`). Default: `date DESC`
   - **Date range filtering:** `date >= date_from AND date <= date_to`
   - **Search:** `WHERE name ILIKE '%term%' OR merchant_name ILIKE '%term%'`
   - **Account filter:** Accept `account_filter_id` (stub for PRD-7.02 wiring)
   - **Eager loading:** `.includes(:account)` on all queries
   - **Summary stats:** Total inflow (`amount > 0`), total outflow (`amount < 0`), net, count
   - **Sort whitelist enforcement:** Invalid sort column → fallback to `date DESC`
   - **Param sanitization:** Invalid page/per_page → defaults (page 1, 25 per page)

3. Write comprehensive unit tests: `test/services/transaction_grid_data_provider_test.rb`:
   - Returns scoped transactions for user (other users excluded)
   - Filters by STI type correctly (RegularTransaction, InvestmentTransaction, CreditTransaction)
   - Filters transfers by `personal_finance_category_label LIKE 'TRANSFER%'` excluding investment accounts
   - Paginates correctly (page 1 returns first N, page 2 returns next N)
   - Sorts by date DESC by default
   - Sorts by name/amount when requested
   - Returns correct summary stats (inflow, outflow, net, count)
   - Handles empty result set gracefully
   - Applies date range filter correctly
   - Applies search term filter (ILIKE on name/merchant_name)
   - Invalid sort column falls back to default
   - Invalid page/per_page falls back to defaults

**Files created:**
- `app/services/transaction_grid_data_provider.rb` (new)
- `test/services/transaction_grid_data_provider_test.rb` (new)

**Acceptance criteria:**
- [ ] `TransactionGridDataProvider` service exists with `initialize(user, params)` → `call` → `Result`
- [ ] All queries scoped to `current_user` via `plaid_items.user_id` join
- [ ] STI type filtering works
- [ ] Transfer filtering works (with investment account exclusion)
- [ ] Pagination via Kaminari on ActiveRecord relation
- [ ] Server-side sorting with whitelist
- [ ] Date range and search filters work
- [ ] Summary stats returned (inflow, outflow, net, count)
- [ ] `.includes(:account)` prevents N+1
- [ ] All unit tests pass (12+ tests)

---

## Deliverable 7-01-E: Controller Refactor — Replace Mock Data with Data Provider

**Goal:** Remove all mock data infrastructure from the controller and delegate to `TransactionGridDataProvider`.

**Tasks:**
1. Read current `app/controllers/transactions_controller.rb` to understand mock data paths
2. Remove the following from the controller:
   - `USE_MOCK_DATA` constant/flag
   - `process_mock_transactions` private method
   - `sort_transactions` private method (sorting now in data provider)
   - `extract_account_names` private method (accounts from associations now)
   - `deduplicate_transfers` private method (moves to `TransferDeduplicator` in PRD-7.03)
   - Any `MockTransactionDataProvider` references
   - `TransactionRecurringDetector` calls from controller (recurring handled in PRD-7.04)
3. Refactor each action to delegate to data provider:
   - `regular`: `TransactionGridDataProvider.new(current_user, params.merge(type_filter: 'RegularTransaction')).call`
   - `investment`: `TransactionGridDataProvider.new(current_user, params.merge(type_filter: 'InvestmentTransaction')).call`
   - `credit`: `TransactionGridDataProvider.new(current_user, params.merge(type_filter: 'CreditTransaction')).call`
   - `transfers`: `TransactionGridDataProvider.new(current_user, params.merge(transfer_mode: true)).call`
   - `summary`: `TransactionGridDataProvider.new(current_user, params).call` (full summary mode in PRD-7.04)
4. Assign instance variables from Result: `@transactions`, `@total_count`, `@page`, `@per_page`, `@sort`, `@dir`
5. Keep CRUD actions (`index`, `show`, `new`, `edit`, `create`, `update`, `destroy`) unchanged
6. Update integration tests: `test/controllers/transactions_controller_test.rb`:
   - `GET /transactions/regular` returns 200 with live data
   - `GET /transactions/investment` returns 200 with InvestmentTransaction records
   - `GET /transactions/credit` returns 200 with CreditTransaction records
   - `GET /transactions/transfers` returns 200
   - `GET /transactions/summary` returns 200
   - User A cannot see User B's transactions
   - Pagination params work correctly
   - Sort params work correctly
   - Invalid params fall back to defaults

**Files modified:**
- `app/controllers/transactions_controller.rb` (major refactor)
- `test/controllers/transactions_controller_test.rb` (update/add tests)

**Acceptance criteria:**
- [ ] `USE_MOCK_DATA` flag removed
- [ ] `process_mock_transactions` and related helper methods removed
- [ ] Each action delegates to `TransactionGridDataProvider` in ~5 lines
- [ ] All views render with live data
- [ ] Integration tests pass (9+ tests)

---

## Deliverable 7-01-F: Mock Data Infrastructure Removal

**Goal:** Completely remove all mock data files and services.

**Tasks:**
1. Delete `app/services/mock_transaction_data_provider.rb`
2. Delete `config/mock_transactions/` directory and all YAML files within
3. Search entire codebase for any remaining references to:
   - `MockTransactionDataProvider`
   - `USE_MOCK_DATA`
   - `mock_transactions`
   - `process_mock_transactions`
4. Remove any found references
5. Run full test suite to confirm nothing breaks: `rails test`

**Files deleted:**
- `app/services/mock_transaction_data_provider.rb`
- `config/mock_transactions/*.yml` (entire directory)

**Files potentially modified:**
- Any file referencing deleted mock infrastructure (grep to find)

**Acceptance criteria:**
- [ ] `MockTransactionDataProvider` service deleted
- [ ] `config/mock_transactions/` directory deleted
- [ ] Zero references to mock data infrastructure in codebase (verified by grep)
- [ ] Full test suite passes

---

## Deliverable 7-01-G: System Tests & End-to-End Verification

**Goal:** Capybara system tests confirming live data renders in browser.

**Tasks:**
1. Create/update `test/system/transactions_test.rb`:
   - Visit `/transactions/regular` → sees transaction table with real data
   - Visit `/transactions/investment` → sees investment transactions (if any exist after backfill)
   - Sort by amount → table reorders correctly
   - Navigate to page 2 → different transactions shown
2. Run system tests: `rails test:system`
3. Manual verification per PRD-7.01 manual steps:
   - Run `rake transactions:backfill_sti_types`
   - Verify `Transaction.group(:type).count` in console
   - Visit all 5 views, confirm live data renders
   - Log out/in as different user → confirm data isolation

**Files created/modified:**
- `test/system/transactions_test.rb` (create or update)

**Acceptance criteria:**
- [ ] System tests pass
- [ ] Manual verification completed and documented in task log
- [ ] No visual regressions from mock data views

---

## PRD 7-01 Completion Checklist

Before moving to PRD 7-02, ALL must be true:
- [ ] All deliverables 7-01-A through 7-01-G complete
- [ ] All unit tests pass (`rails test test/services/transaction_grid_data_provider_test.rb`)
- [ ] All integration tests pass (`rails test test/controllers/transactions_controller_test.rb`)
- [ ] All system tests pass (`rails test test/system/transactions_test.rb`)
- [ ] Full test suite green (`rails test`)
- [ ] `rake transactions:backfill_sti_types` has been run
- [ ] `InvestmentTransaction.count > 0` verified
- [ ] No N+1 queries in development log
- [ ] QA Agent score ≥ 90
- [ ] Branch `feature/prd-7-01-data-provider-wiring` merged to `main`
- [ ] `0001-implementation-status.md` updated

---

---

# PRD 7-02: Global Account Filter & Filter Bar Refinements

**Branch:** `feature/prd-7-02-account-filter`
**Estimated effort:** 1–2 days
**Dependencies:** PRD 7-01 complete and merged
**Blocks:** PRD 7-03

---

## Deliverable 7-02-A: Genericize SavedAccountFilterSelectorComponent

**Goal:** Make the account filter component reusable across any view (not just Holdings).

**Tasks:**
1. Read `app/components/saved_account_filter_selector_component.rb` and its template
2. Rename `holdings_path_helper` parameter to `path_helper`
3. Keep `holdings_path_helper` as a deprecated alias for backward compatibility:
   ```ruby
   def initialize(path_helper: nil, holdings_path_helper: nil, **opts)
     @path_helper = path_helper || holdings_path_helper
     # ...
   end
   ```
4. Rename internal `holdings_path` method to `target_path`
5. Update all existing call sites in Holdings views to use new `path_helper:` param name
6. Write unit tests: `test/components/saved_account_filter_selector_component_test.rb`:
   - Renders with transaction path helper (`:transactions_regular_path`)
   - Renders with holdings path helper (backward compat)
   - "All Accounts" link uses correct path helper
   - Filter links include `saved_account_filter_id` param
7. Run Holdings system tests to confirm no regression

**Files modified:**
- `app/components/saved_account_filter_selector_component.rb`
- `app/components/saved_account_filter_selector_component.html.erb` (if template references old method name)
- All Holdings view files that call the component (update param name)
- `test/components/saved_account_filter_selector_component_test.rb` (add/update tests)

**Acceptance criteria:**
- [ ] Component accepts generic `path_helper` param
- [ ] Backward compatible `holdings_path_helper` alias works
- [ ] All Holdings views still work (no regression)
- [ ] 4 new/updated unit tests pass

---

## Deliverable 7-02-B: Add Account Filter to All Transaction Views

**Goal:** Replace inline `<select>` account dropdowns with the generic `SavedAccountFilterSelectorComponent` in all 5 transaction views.

**Tasks:**
1. Read all 5 transaction view templates (`regular.html.erb`, `investment.html.erb`, `credit.html.erb`, `transfers.html.erb`, `summary.html.erb`)
2. In each view, replace the inline `<select name="account">` dropdown with:
   ```erb
   <%= render SavedAccountFilterSelectorComponent.new(
     saved_account_filters: @saved_account_filters,
     selected_id: @saved_account_filter_id,
     path_helper: :transactions_regular_path,  # (varies per view)
     turbo_frame_id: Transactions::GridComponent::TRANSACTIONS_GRID_TURBO_FRAME_ID
   ) %>
   ```
3. In each controller action, add:
   ```ruby
   @saved_account_filters = current_user.saved_account_filters
   @saved_account_filter_id = params[:saved_account_filter_id]
   ```
4. Ensure grid + filter bar are wrapped in the matching Turbo Frame
5. Update controller tests to verify `@saved_account_filters` is assigned

**Files modified:**
- `app/views/transactions/regular.html.erb`
- `app/views/transactions/investment.html.erb`
- `app/views/transactions/credit.html.erb`
- `app/views/transactions/transfers.html.erb`
- `app/views/transactions/summary.html.erb`
- `app/controllers/transactions_controller.rb` (add filter loading to each action)
- `test/controllers/transactions_controller_test.rb` (verify filter assignment)

**Acceptance criteria:**
- [ ] All 5 transaction views show `SavedAccountFilterSelectorComponent`
- [ ] Inline `<select>` account dropdown removed from all views
- [ ] Controller loads `@saved_account_filters` and `@saved_account_filter_id` in each action
- [ ] Turbo Frame target is set correctly

---

## Deliverable 7-02-C: Wire Account Filter to TransactionGridDataProvider

**Goal:** Make the data provider filter transactions by saved account filter criteria.

**Tasks:**
1. Add `saved_account_filter_id` handling to `TransactionGridDataProvider`:
   - Resolve: `user.saved_account_filters.find_by(id: params[:saved_account_filter_id])`
   - If found: apply filter criteria (account_ids, institution_ids) to scope the query
   - If not found or nil: no filter applied (show all accounts)
   - Mirror `apply_account_filter` pattern from `HoldingsGridDataProvider`
2. Write unit tests:
   - With `saved_account_filter_id`: returns only transactions from matching accounts
   - With invalid `saved_account_filter_id`: returns all transactions (no filter)
   - With another user's filter ID: ignored (user.saved_account_filters won't find it)
3. Write integration test:
   - `GET /transactions/regular?saved_account_filter_id=X` returns filtered results

**Files modified:**
- `app/services/transaction_grid_data_provider.rb` (add account filter logic)
- `test/services/transaction_grid_data_provider_test.rb` (add tests)
- `test/controllers/transactions_controller_test.rb` (add integration test)

**Acceptance criteria:**
- [ ] Data provider filters by saved account filter when param present
- [ ] Invalid/missing filter ID → no filter (show all)
- [ ] Other user's filter ID → ignored
- [ ] 3+ new tests pass

---

## Deliverable 7-02-D: Wire Filter Bar Fields to Data Provider

**Goal:** Connect search, date range, and type filter fields in the `FilterBarComponent` to server-side queries.

**Tasks:**
1. Read `app/components/transactions/filter_bar_component.rb` and its template
2. Ensure hidden field for `saved_account_filter_id` is included in the filter form so it's preserved across filter submissions
3. Remove old `account` hidden field (replaced by `saved_account_filter_id`)
4. Verify these params flow through to `TransactionGridDataProvider`:
   - `search_term` → ILIKE query on name/merchant_name
   - `date_from` / `date_to` → date range WHERE clause
   - `type_filter` → STI type filter (if applicable)
5. Ensure filter bar form targets the Turbo Frame (no full page reload)
6. Write unit tests for `FilterBarComponent`:
   - Renders hidden `saved_account_filter_id` field
   - Search input submits `search_term` param
   - Date range inputs submit `date_from` / `date_to` params
7. Write integration tests:
   - `GET /transactions/regular?search_term=coffee` returns filtered results
   - `GET /transactions/regular?date_from=2026-01-01&date_to=2026-01-31` returns date-filtered results
   - Combined filters work (account + search + date)

**Files modified:**
- `app/components/transactions/filter_bar_component.rb`
- `app/components/transactions/filter_bar_component.html.erb`
- `test/components/transactions/filter_bar_component_test.rb` (add tests)
- `test/controllers/transactions_controller_test.rb` (add integration tests)

**Acceptance criteria:**
- [ ] Hidden `saved_account_filter_id` field preserved in filter form
- [ ] Old `account` param removed
- [ ] Search, date range, type filter all flow to data provider
- [ ] No full page reload on filter submission (Turbo Frame)
- [ ] Combined filters work correctly
- [ ] Unit and integration tests pass

---

## Deliverable 7-02-E: System Tests & Verification

**Goal:** End-to-end tests for filter functionality.

**Tasks:**
1. Create `test/system/transactions_filter_test.rb`:
   - Visit `/transactions/regular` → account filter dropdown visible
   - Select a saved filter → grid refreshes without full page reload
   - Enter search term + click Apply → grid shows filtered results
   - Click Clear → all filters reset
2. Manual verification:
   - Visit each transaction view, verify account filter dropdown appears
   - Select a filter → data updates via Turbo Frame
   - Enter search → results filter
   - Set date range → results filter
   - Visit Holdings → confirm account filter still works (no regression)

**Files created:**
- `test/system/transactions_filter_test.rb` (new)

**Acceptance criteria:**
- [ ] System tests pass
- [ ] Manual verification completed
- [ ] Holdings views unaffected (no regression)

---

## PRD 7-02 Completion Checklist

Before moving to PRD 7-03, ALL must be true:
- [ ] All deliverables 7-02-A through 7-02-E complete
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All system tests pass (including Holdings regression)
- [ ] Full test suite green (`rails test`)
- [ ] QA Agent score ≥ 90
- [ ] Branch `feature/prd-7-02-account-filter` merged to `main`
- [ ] `0001-implementation-status.md` updated

---

---

# PRD 7-03: Type-Specific View Enhancements & Transfers Deduplication

**Branch:** `feature/prd-7-03-views-transfers`
**Estimated effort:** 2–3 days
**Dependencies:** PRD 7-02 complete and merged
**Blocks:** PRD 7-04

---

## Deliverable 7-03-A: Cash View Polish

**Goal:** Enhance the cash/regular transaction view with category labels and merchant names from live data.

**Tasks:**
1. Read `app/components/transactions/row_component.rb` and its template
2. Add category badge rendering:
   - Extract primary category from `personal_finance_category_label` (first segment before "→" or first word)
   - Render as a DaisyUI badge in the row
   - Handle nil `personal_finance_category_label` gracefully (skip badge)
3. Ensure Merchant column populates from `merchant_name` field on Transaction model (not mock `account_name`)
4. Write unit test in `test/components/transactions/row_component_test.rb`:
   - Renders category badge for cash transactions with `personal_finance_category_label`
   - Skips category badge when `personal_finance_category_label` is nil
   - Renders merchant name from `merchant_name` field

**Files modified:**
- `app/components/transactions/row_component.rb` (add category extraction helper)
- `app/components/transactions/row_component.html.erb` (render category badge, merchant)
- `test/components/transactions/row_component_test.rb` (add tests)

**Acceptance criteria:**
- [ ] Cash view shows category label from `personal_finance_category_label`
- [ ] Cash view shows `merchant_name` in Merchant column
- [ ] Nil category handled gracefully (no badge, no error)
- [ ] Unit tests pass

---

## Deliverable 7-03-B: Investment View Polish

**Goal:** Enhance investment transaction view with security links, quantity/price columns, and subtype badges.

**Tasks:**
1. Verify `show_investment_columns: true` is already wired in investment view template
2. Update `RowComponent` to render investment-specific data from live associations:
   - Security column: icon + link to `/portfolio/securities/:security_id` (existing `security_link` method — verify it works with live data)
   - Quantity column from Transaction model field
   - Price column from Transaction model field
3. Add `subtype_badge` helper method to `RowComponent`:
   - "Buy" → green badge
   - "Sell" → red badge
   - "Dividend" → blue badge
   - "Interest" → purple badge
   - "Split" → gray badge
   - "Transfer" → gray badge
   - Other/nil → no badge
4. Render subtype badge in row template next to type badge
5. Write unit tests:
   - Renders subtype badge for each investment subtype with correct color
   - Renders security link when security_id is present
   - Shows "—" when security_id is nil
   - Renders quantity and price columns

**Files modified:**
- `app/components/transactions/row_component.rb` (add `subtype_badge` method)
- `app/components/transactions/row_component.html.erb` (render subtype badge, verify investment columns)
- `test/components/transactions/row_component_test.rb` (add tests)

**Acceptance criteria:**
- [ ] Investment view shows Security column with icon and clickable link
- [ ] Investment view shows Quantity and Price columns
- [ ] Investment view shows subtype badge with appropriate colors
- [ ] Security link navigates to `/portfolio/securities/:security_id`
- [ ] Nil security_id shows "—" (no error)
- [ ] Unit tests pass

---

## Deliverable 7-03-C: Credit View Polish

**Goal:** Enhance credit transaction view with pending badges and merchant avatars.

**Tasks:**
1. Verify `RowComponent#pending?` method works with live data (checks `pending` field on Transaction)
2. Ensure pending transactions show warning badge (already in `RowComponent` — verify rendering)
3. Add merchant avatar (letter initial) rendering:
   - Extract first letter of `merchant_name` or `name`
   - Render as a small circular badge before the transaction name
   - Handle nil merchant gracefully (use first letter of name)
4. Ensure category label from `personal_finance_category_label` renders (shared with cash view from Deliverable 7-03-A)
5. Write unit tests:
   - Renders pending badge on pending transactions
   - Renders merchant avatar (letter initial) next to name
   - Handles nil merchant_name gracefully

**Files modified:**
- `app/components/transactions/row_component.rb` (add merchant avatar helper if needed)
- `app/components/transactions/row_component.html.erb` (verify pending badge, add avatar)
- `test/components/transactions/row_component_test.rb` (add tests)

**Acceptance criteria:**
- [ ] Credit view shows pending badge on pending transactions
- [ ] Credit view shows merchant avatar (letter initial) next to name
- [ ] Category labels render on credit view
- [ ] Nil merchant handled gracefully
- [ ] Unit tests pass

---

## Deliverable 7-03-D: TransferDeduplicator Service

**Goal:** Create the deduplication engine that matches internal transfer leg pairs.

**Tasks:**
1. Create `app/services/transfer_deduplicator.rb`:
   - `initialize(transactions)` — accepts array of transfer transactions
   - `call` → returns deduplicated array
   - **Matching algorithm (O(n) single pass with hash):**
     - Build hash keyed by normalized amount (`abs(amount).round(2)`)
     - For each transaction, check for a match: date ±1 day, opposite sign, abs(amount) within 1%, different `account_id`
     - Matched pairs: keep outbound/negative leg, mark inbound/positive as suppressed
     - Mark matched legs with `internal: true`
     - Unmatched transactions: keep with `external: true` flag
   - Handle edge cases:
     - Multiple same-amount transfers on same day → match first pair, extras remain unmatched
     - Self-transfer (same account) → keep as outbound
     - Nil amount → skip dedup, keep as-is
     - Transaction missing account association → skip, show with "—" for account name
2. Write comprehensive unit tests: `test/services/transfer_deduplicator_test.rb`:
   1. Internal exact match: $1000 out + $1000 in, same day → only outbound returned
   2. Near-amount match: $1000.00 out + $999.87 in → matched, inbound suppressed
   3. Date offset: out Feb 17, in Feb 18 → matched
   4. External: $500 out, no matching inbound → returned with `external: true`
   5. Investment account excluded (already handled by data provider — but verify service handles if passed)
   6. Self-transfer (same account): treated as outbound
   7. Multi-leg (wire fee split): amounts don't match → both kept as unmatched

**Files created:**
- `app/services/transfer_deduplicator.rb` (new)
- `test/services/transfer_deduplicator_test.rb` (new)

**Acceptance criteria:**
- [ ] `TransferDeduplicator` service exists
- [ ] All 7 edge case tests pass
- [ ] O(n) time complexity (single pass)
- [ ] No additional database queries (works on in-memory array)
- [ ] Outbound/negative leg kept as canonical
- [ ] Matched pairs marked `internal: true`
- [ ] Unmatched legs marked `external: true`

---

## Deliverable 7-03-E: Transfers View Wiring

**Goal:** Wire the TransferDeduplicator into the transfers view and enhance RowComponent for transfer display.

**Tasks:**
1. Wire `TransferDeduplicator` in the controller's `transfers` action (or in `TransactionGridDataProvider` when `transfer_mode: true`):
   ```ruby
   result = TransactionGridDataProvider.new(current_user, params.merge(transfer_mode: true)).call
   @transactions = TransferDeduplicator.new(result.transactions).call
   ```
2. Update `RowComponent` transfer helpers for live data:
   - `transfer_from` → use `transaction.account.name` (live association, not mock `account_name`)
   - `transfer_to` → use matched leg's `account.name` (if available from dedup result)
   - `transfer_badge` → render "Internal" (green) or "External" (amber) badge based on dedup flag
3. Ensure direction arrows render: outbound red →, inbound green ←
4. Display amounts as absolute values in transfers view
5. Verify no investment-account transfers appear (excluded by data provider)
6. Write integration test:
   - `GET /transactions/transfers` returns deduplicated results
7. Write unit tests for RowComponent:
   - Renders transfer direction arrow and badge
   - Renders "Internal" badge for matched transfers
   - Renders "External" badge for unmatched transfers
   - Shows absolute value for amounts

**Files modified:**
- `app/controllers/transactions_controller.rb` (wire TransferDeduplicator in `transfers` action)
- `app/components/transactions/row_component.rb` (update transfer helpers for live data)
- `app/components/transactions/row_component.html.erb` (verify transfer rendering)
- `test/controllers/transactions_controller_test.rb` (add integration test)
- `test/components/transactions/row_component_test.rb` (add transfer tests)

**Acceptance criteria:**
- [ ] Transfers view shows deduplicated results
- [ ] Direction arrows render (outbound red →, inbound green ←)
- [ ] "Internal"/"External" badges display correctly
- [ ] Amounts shown as absolute values
- [ ] No investment-account transfers in view
- [ ] Integration and unit tests pass

---

## Deliverable 7-03-F: System Tests & Verification

**Goal:** End-to-end tests for all type-specific views.

**Tasks:**
1. Create/update `test/system/transactions_views_test.rb`:
   - Visit `/transactions/investment` → security links are clickable
   - Visit `/transactions/transfers` → direction arrows visible
   - Visit `/transactions/credit` → pending badges visible (if pending transactions exist)
   - Visit `/transactions/regular` → category labels visible
2. Manual verification per PRD-7.03 manual steps:
   - Visit each view, verify type-specific columns render with live data
   - Click a security link → navigates correctly
   - Verify transfer dedup count (fewer rows than raw transfer count)
   - Verify direction arrows and badges
   - In console: `TransferDeduplicator.new(transfers).call.size` vs raw count

**Files created/modified:**
- `test/system/transactions_views_test.rb` (new or updated)

**Acceptance criteria:**
- [ ] System tests pass
- [ ] Manual verification completed
- [ ] No visual regressions from Epic-6 mock views

---

## PRD 7-03 Completion Checklist

Before moving to PRD 7-04, ALL must be true:
- [ ] All deliverables 7-03-A through 7-03-F complete
- [ ] All unit tests pass (RowComponent, TransferDeduplicator)
- [ ] All integration tests pass
- [ ] All system tests pass
- [ ] Full test suite green (`rails test`)
- [ ] QA Agent score ≥ 90
- [ ] Branch `feature/prd-7-03-views-transfers` merged to `main`
- [ ] `0001-implementation-status.md` updated

---

---

# PRD 7-04: Summary View & Recurring Section

**Branch:** `feature/prd-7-04-summary-recurring`
**Estimated effort:** 1–2 days
**Dependencies:** PRD 7-03 complete and merged
**Blocks:** PRD 7-05

---

## Deliverable 7-04-A: Summary Mode in TransactionGridDataProvider

**Goal:** Add aggregate query capability to the data provider for summary statistics.

**Tasks:**
1. Add `summary_mode` parameter handling to `TransactionGridDataProvider`:
   - When `summary_mode: true`, return aggregate stats hash instead of paginated rows
   - **Total inflow:** `SUM(amount) WHERE amount > 0` (scoped to user + filters)
   - **Total outflow:** `SUM(amount) WHERE amount < 0` (scoped to user + filters)
   - **Net:** inflow + outflow
   - **Total transaction count**
   - **Top categories:** `GROUP BY personal_finance_category_label` (primary segment), `ORDER BY COUNT(*) DESC LIMIT 10` — returns array of `{name:, count:, total_amount:}`
   - **Top merchants:** `GROUP BY merchant_name WHERE merchant_name IS NOT NULL`, `ORDER BY COUNT(*) DESC LIMIT 10` — returns array of `{name:, count:, total_amount:}`
   - **Monthly totals:** `GROUP BY DATE_TRUNC('month', date)` ordered by month DESC — returns hash of `{month_label: total_amount}`
2. Ensure all aggregates respect `saved_account_filter_id` (if present)
3. Use aggregate SQL queries (not in-memory computation on loaded records)
4. Write unit tests:
   - Summary mode returns aggregate hash with `total_inflow`, `total_outflow`, `net`, `count`
   - Summary mode returns `top_categories` array (max 10)
   - Summary mode returns `top_merchants` array (max 10)
   - Summary mode returns `monthly_totals` hash
   - Summary mode respects `saved_account_filter_id`
   - Empty dataset returns all zeroes

**Files modified:**
- `app/services/transaction_grid_data_provider.rb` (add summary mode)
- `test/services/transaction_grid_data_provider_test.rb` (add summary tests)

**Acceptance criteria:**
- [ ] Summary mode returns aggregate stats hash
- [ ] Aggregates use SQL (not in-memory)
- [ ] Account filter applies to all aggregates
- [ ] Top categories and merchants limited to 10
- [ ] Monthly totals grouped correctly
- [ ] All unit tests pass (6+ new tests)

---

## Deliverable 7-04-B: Recurring Expenses from RecurringTransaction Model

**Goal:** Query Plaid's authoritative recurring data for the "Top Recurring Expenses" card.

**Tasks:**
1. Read the `RecurringTransaction` model and schema
2. Add a method (in controller or a small query object) to load top recurring expenses:
   ```ruby
   @top_recurring = RecurringTransaction
     .joins(:plaid_item)
     .where(plaid_items: { user_id: current_user.id })
     .where(stream_type: 'outflow')
     .order(average_amount: :desc)
     .limit(5)
   ```
3. Optionally filter by account if `saved_account_filter_id` is present (join through plaid_item → accounts → saved_account_filter criteria)
4. Remove any `TransactionRecurringDetector.top_recurring` calls from the summary action (if any remain from PRD-7.01)
5. Write tests:
   - Returns top 5 outflow recurring transactions for user
   - Scoped to user (other users' recurring excluded)
   - Returns empty array if no RecurringTransaction records
   - Respects account filter (if applicable)

**Files modified:**
- `app/controllers/transactions_controller.rb` (add `@top_recurring` to summary action)
- `test/controllers/transactions_controller_test.rb` (add recurring tests)

**Acceptance criteria:**
- [ ] Top recurring expenses loaded from `RecurringTransaction` model
- [ ] Scoped to current user via `plaid_items.user_id`
- [ ] Only outflow stream type
- [ ] Ordered by average_amount DESC, limited to 5
- [ ] No `TransactionRecurringDetector.top_recurring` in summary action
- [ ] Tests pass

---

## Deliverable 7-04-C: Update SummaryCardComponent Interface

**Goal:** Change the component to accept a pre-computed summary hash instead of a transactions array.

**Tasks:**
1. Read `app/components/transactions/summary_card_component.rb` and template
2. Change `initialize` to accept `summary:` hash parameter instead of (or in addition to) `transactions:` array:
   ```ruby
   def initialize(summary:)
     @summary = summary
   end
   ```
3. Update template to render from hash keys:
   - `@summary[:total_inflow]`, `@summary[:total_outflow]`, `@summary[:net]`, `@summary[:count]`
   - Color-code: positive amounts green, negative amounts red
4. Handle zero/nil values gracefully (display "$0.00")
5. Write unit tests: `test/components/transactions/summary_card_component_test.rb`:
   - Renders with summary hash (new interface)
   - Shows "$0.00" for zero values
   - Color-codes positive (green) and negative (red) amounts
   - Handles nil values gracefully

**Files modified:**
- `app/components/transactions/summary_card_component.rb`
- `app/components/transactions/summary_card_component.html.erb`
- `test/components/transactions/summary_card_component_test.rb` (add/update tests)

**Acceptance criteria:**
- [ ] Component accepts `summary:` hash
- [ ] Renders inflow/outflow/net/count from hash
- [ ] Color-coding works (green/red)
- [ ] Zero/nil values display "$0.00"
- [ ] Unit tests pass

---

## Deliverable 7-04-D: Wire Summary View to Live Data

**Goal:** Connect the summary view template to the data provider's summary mode and the recurring query.

**Tasks:**
1. Update `summary` action in controller:
   ```ruby
   def summary
     result = TransactionGridDataProvider.new(current_user, params.merge(summary_mode: true)).call
     @summary = result.summary
     @top_categories = result.summary[:top_categories]
     @top_merchants = result.summary[:top_merchants]
     @monthly_totals = result.summary[:monthly_totals]
     @top_recurring = RecurringTransaction.joins(:plaid_item)
                        .where(plaid_items: { user_id: current_user.id })
                        .where(stream_type: 'outflow')
                        .order(average_amount: :desc).limit(5)
     @saved_account_filters = current_user.saved_account_filters
     @saved_account_filter_id = params[:saved_account_filter_id]
   end
   ```
2. Update `app/views/transactions/summary.html.erb`:
   - Replace mock `@summary_data` references with `@summary`
   - Render `SummaryCardComponent.new(summary: @summary)`
   - Render "Top Categories" card from `@top_categories`
   - Render "Top Merchants" card from `@top_merchants`
   - Render "Monthly Totals" card from `@monthly_totals`
   - Render "Top Recurring Expenses" card from `@top_recurring`:
     - Each row: description/merchant_name, frequency, average_amount, last_date
     - "See all recurring →" link
   - Render `SavedAccountFilterSelectorComponent` (already from PRD-7.02)
3. Remove any remaining mock summary data references
4. Write integration tests:
   - `GET /transactions/summary` returns 200 with live aggregate data
   - `GET /transactions/summary?saved_account_filter_id=X` returns filtered aggregates
   - Response includes recurring expenses section

**Files modified:**
- `app/controllers/transactions_controller.rb` (update summary action)
- `app/views/transactions/summary.html.erb` (wire to live data)
- `test/controllers/transactions_controller_test.rb` (add integration tests)

**Acceptance criteria:**
- [ ] Summary view renders from live aggregate queries
- [ ] Top categories card shows real categories
- [ ] Top merchants card shows real merchants
- [ ] Monthly totals card shows month-by-month breakdown
- [ ] Top recurring expenses card populated from `RecurringTransaction` model
- [ ] Account filter applies to all summary stats
- [ ] No mock data references remain
- [ ] Integration tests pass

---

## Deliverable 7-04-E: System Tests & Verification

**Goal:** End-to-end tests and manual verification of the summary view.

**Tasks:**
1. Create `test/system/transactions_summary_test.rb`:
   - Visit `/transactions/summary` → stat cards show non-zero values
   - Top categories card visible with real category labels
   - Recurring expenses card shows data (if RecurringTransaction records exist)
2. Manual verification per PRD-7.04 manual steps:
   - Verify totals match console queries
   - Verify categories reflect Plaid taxonomy
   - Verify recurring data matches `RecurringTransaction` query
   - Apply account filter → verify all cards update

**Files created:**
- `test/system/transactions_summary_test.rb` (new)

**Acceptance criteria:**
- [ ] System tests pass
- [ ] Manual verification completed
- [ ] Summary page loads < 500ms

---

## PRD 7-04 Completion Checklist

Before moving to PRD 7-05, ALL must be true:
- [ ] All deliverables 7-04-A through 7-04-E complete
- [ ] All unit tests pass (data provider summary, SummaryCardComponent)
- [ ] All integration tests pass
- [ ] All system tests pass
- [ ] Full test suite green (`rails test`)
- [ ] QA Agent score ≥ 90
- [ ] Branch `feature/prd-7-04-summary-recurring` merged to `main`
- [ ] `0001-implementation-status.md` updated

---

---

# PRD 7-05: Performance Tuning & STI Cleanup

**Branch:** `feature/prd-7-05-performance`
**Estimated effort:** 1–2 days
**Dependencies:** PRD 7-04 complete and merged
**Blocks:** None (final PRD)

---

## Deliverable 7-05-A: Composite Index Verification

**Goal:** Confirm the composite index is being used by the query planner.

**Tasks:**
1. Run `EXPLAIN ANALYZE` on the 5 primary query patterns in `rails dbconsole`:
   - Regular transactions query (type = 'RegularTransaction', ordered by date)
   - Investment transactions query (type = 'InvestmentTransaction', ordered by date)
   - Credit transactions query (type = 'CreditTransaction', ordered by date)
   - Transfer transactions query (personal_finance_category_label LIKE 'TRANSFER%')
   - Summary aggregate query (SUM, GROUP BY)
2. Document each `EXPLAIN ANALYZE` output in the task log
3. Confirm `idx_transactions_type_account_date` appears in type-filtered query plans
4. If index not used:
   - Check if table stats are stale (`ANALYZE transactions;`)
   - Consider partial indexes if needed
   - Document decision and rationale

**Files created:**
- Task log documentation (EXPLAIN ANALYZE outputs)

**Acceptance criteria:**
- [ ] `EXPLAIN ANALYZE` output documented for all 5 query patterns
- [ ] Composite index confirmed used in type-filtered queries (or documented reason why not + remediation)

---

## Deliverable 7-05-B: N+1 Query Detection & Fix

**Goal:** Ensure zero N+1 queries across all transaction views.

**Tasks:**
1. Add `bullet` gem to development group in `Gemfile` (if not already present):
   ```ruby
   group :development do
     gem 'bullet'
   end
   ```
2. Configure Bullet in `config/environments/development.rb`:
   ```ruby
   config.after_initialize do
     Bullet.enable = true
     Bullet.rails_logger = true
     Bullet.add_whitelist type: :unused_eager_loading, ... # if needed
   end
   ```
3. Run `bundle install`
4. Start development server and visit each transaction view with 25, 50, 100 results per page
5. Check Rails log for Bullet warnings
6. Fix any detected N+1 queries:
   - Expected: may need `.includes(account: :plaid_item)` for institution name
   - Add appropriate `.includes()`, `.preload()`, or `.eager_load()` to `TransactionGridDataProvider`
7. Re-run and confirm zero warnings
8. Write test (if `assert_queries` helper available):
   - Verify query count doesn't scale with result count

**Files modified:**
- `Gemfile` (add bullet gem if needed)
- `config/environments/development.rb` (Bullet config)
- `app/services/transaction_grid_data_provider.rb` (add .includes if needed)

**Acceptance criteria:**
- [ ] Bullet gem configured in development
- [ ] Zero N+1 warnings across all views at 25/50/100 per page
- [ ] Any fixes documented

---

## Deliverable 7-05-C: STI Backfill Completeness Verification

**Goal:** Confirm all transactions have correct STI types.

**Tasks:**
1. Run verification query:
   ```ruby
   count = Transaction.where(type: 'RegularTransaction')
                      .joins(:account)
                      .where(accounts: { plaid_account_type: ['investment', 'credit'] })
                      .count
   ```
2. Expected result: 0
3. If > 0: re-run `rake transactions:backfill_sti_types` and investigate missed rows
4. Create verification rake task `rake transactions:verify_sti_completeness`:
   - Runs the above query
   - Outputs "PASS: All transactions correctly typed" or "FAIL: X transactions need reclassification"
   - Can be run periodically for ongoing verification
5. Document results in task log

**Files created:**
- `lib/tasks/transactions.rake` (add `verify_sti_completeness` task to existing file)

**Acceptance criteria:**
- [ ] `RegularTransaction` count for investment/credit accounts == 0
- [ ] `rake transactions:verify_sti_completeness` task exists
- [ ] Results documented

---

## Deliverable 7-05-D: Summary Query Optimization

**Goal:** Ensure all summary aggregate queries execute under 200ms.

**Tasks:**
1. Profile each summary aggregate query with `EXPLAIN ANALYZE`:
   - Total inflow query
   - Total outflow query
   - Top categories GROUP BY
   - Top merchants GROUP BY
   - Monthly totals GROUP BY
2. If any query exceeds 200ms, apply optimizations:
   - **Option A:** Add partial index (e.g., `WHERE amount > 0` for inflow)
   - **Option B:** Add `Rails.cache.fetch` wrapper with 5-minute TTL:
     ```ruby
     Rails.cache.fetch("transactions_summary/#{user.id}/#{filter_key}", expires_in: 5.minutes) do
       # aggregate query
     end
     ```
   - **Option C:** Materialize monthly totals in background job (last resort)
3. If caching added: ensure cache invalidation on new transaction sync (add `Rails.cache.delete` to `SyncTransactionsJob`)
4. Document profiling results and optimization decisions

**Files potentially modified:**
- `app/services/transaction_grid_data_provider.rb` (add caching if needed)
- `db/migrate/` (new migration if partial indexes needed)
- Sync job (add cache invalidation if caching added)

**Acceptance criteria:**
- [ ] All summary aggregates < 200ms (profiled and documented)
- [ ] Optimization decisions documented (applied or explicitly deferred with rationale)
- [ ] Cache invalidation wired if caching added

---

## Deliverable 7-05-E: Pagination Tuning & "All" Cap

**Goal:** Ensure pagination is safe and performant.

**Tasks:**
1. Verify `page` and `per_page` defaults are sensible (25 default, max 100)
2. Implement `per_page = "all"` cap:
   - If count > 500, show warning indicator (mirror Holdings grid pattern)
   - Cap at 1000 rows to prevent OOM
3. Test `per_page=all` doesn't cause memory issues with 13k+ transactions
4. Write integration test:
   - `per_page=all` with count > 500 shows cap behavior
   - `per_page=all` returns 200 (not error/timeout)

**Files modified:**
- `app/services/transaction_grid_data_provider.rb` (add "all" cap logic)
- `test/services/transaction_grid_data_provider_test.rb` (add test)
- `test/controllers/transactions_controller_test.rb` (add integration test)

**Acceptance criteria:**
- [ ] `per_page = "all"` shows warning if count > 500
- [ ] `per_page = "all"` capped at 1000 rows
- [ ] Tests pass

---

## Deliverable 7-05-F: Counter Cache Decision & Documentation

**Goal:** Assess and document whether `Account` needs a `transactions_count` counter cache.

**Tasks:**
1. Review summary and list views — do any show "X transactions in Account Y"?
2. If yes and the query is slow: add counter cache migration
3. If no or query is fast: document decision to defer with rationale
4. Document decision in task log

**Files potentially modified:**
- `db/migrate/` (new migration if counter cache added)
- `app/models/account.rb` (add counter_cache if needed)
- `app/models/transaction.rb` (add `belongs_to :account, counter_cache: true` if needed)

**Acceptance criteria:**
- [ ] Counter cache decision documented (added or deferred with rationale)

---

## Deliverable 7-05-G: Page Load Time Profiling

**Goal:** Verify all views meet the < 500ms target.

**Tasks:**
1. Profile all 5 transaction views at 25/page:
   - `/transactions/regular`
   - `/transactions/investment`
   - `/transactions/credit`
   - `/transactions/transfers`
   - `/transactions/summary`
2. Profile all 5 views at 100/page
3. Measure server response time via Rails logger or `rack-mini-profiler`
4. **Target:** All < 500ms
5. If any exceed 500ms: investigate and optimize (add indexes, reduce eager loads, simplify queries)
6. Document all profiling results (view, per_page, response time) in task log

**Files potentially modified:**
- Any file requiring optimization based on profiling results

**Acceptance criteria:**
- [ ] All 5 views < 500ms at 25/page (documented)
- [ ] All 5 views < 500ms at 100/page (documented)
- [ ] Performance results documented in task log with timestamps

---

## Deliverable 7-05-H: System Tests & Final Verification

**Goal:** Final system tests confirming performance and correctness.

**Tasks:**
1. Create `test/system/transactions_performance_test.rb`:
   - Visit each view → page loads without timeout
   - Navigate to page 2, page 3 → each loads
   - Select "100" per page → renders without timeout
2. Run full test suite: `rails test`
3. Final manual verification:
   - All 5 views render with live data
   - Zero N+1 warnings in Bullet
   - STI backfill complete
   - Performance targets met

**Files created:**
- `test/system/transactions_performance_test.rb` (new)

**Acceptance criteria:**
- [ ] System tests pass
- [ ] Full test suite green
- [ ] All manual verification steps completed

---

## PRD 7-05 Completion Checklist

This is the final PRD. ALL must be true to close Epic 7:
- [ ] All deliverables 7-05-A through 7-05-H complete
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All system tests pass
- [ ] Full test suite green (`rails test`)
- [ ] Performance results documented
- [ ] QA Agent score ≥ 90
- [ ] Branch `feature/prd-7-05-performance` merged to `main`
- [ ] `0001-implementation-status.md` updated — all PRDs marked complete

---

---

# Epic 7 — Full Deliverable Summary

| PRD | Deliverable | Description | New Files | Modified Files |
|-----|------------|-------------|-----------|----------------|
| 7-01 | A | Composite index migration | 1 migration | schema.rb |
| 7-01 | B | STI reclassification in sync service | — | sync service, sync test |
| 7-01 | C | Backfill rake task | rake file, rake test | — |
| 7-01 | D | TransactionGridDataProvider service | service, service test | — |
| 7-01 | E | Controller refactor (mock → data provider) | — | controller, controller test |
| 7-01 | F | Mock data infrastructure removal | — (deletions) | any remaining refs |
| 7-01 | G | System tests & E2E verification | system test | — |
| 7-02 | A | Genericize SavedAccountFilterSelectorComponent | — | component, component test, holdings views |
| 7-02 | B | Add account filter to all transaction views | — | 5 views, controller, controller test |
| 7-02 | C | Wire account filter to data provider | — | data provider, data provider test, controller test |
| 7-02 | D | Wire filter bar fields to data provider | — | filter bar component, component test, controller test |
| 7-02 | E | System tests & verification | system test | — |
| 7-03 | A | Cash view polish (category labels, merchant) | — | row component, row component test |
| 7-03 | B | Investment view polish (security, subtype badges) | — | row component, row component test |
| 7-03 | C | Credit view polish (pending, avatars) | — | row component, row component test |
| 7-03 | D | TransferDeduplicator service | service, service test | — |
| 7-03 | E | Transfers view wiring | — | controller, row component, tests |
| 7-03 | F | System tests & verification | system test | — |
| 7-04 | A | Summary mode in data provider | — | data provider, data provider test |
| 7-04 | B | Recurring expenses from RecurringTransaction | — | controller, controller test |
| 7-04 | C | Update SummaryCardComponent interface | — | component, component test |
| 7-04 | D | Wire summary view to live data | — | controller, view, controller test |
| 7-04 | E | System tests & verification | system test | — |
| 7-05 | A | Composite index verification (EXPLAIN ANALYZE) | — | task log |
| 7-05 | B | N+1 query detection & fix (Bullet) | — | Gemfile, config, data provider |
| 7-05 | C | STI backfill completeness verification | — | rake file |
| 7-05 | D | Summary query optimization | — | data provider, potentially migration |
| 7-05 | E | Pagination tuning & "all" cap | — | data provider, tests |
| 7-05 | F | Counter cache decision & documentation | — | potentially migration, models |
| 7-05 | G | Page load time profiling | — | task log |
| 7-05 | H | System tests & final verification | system test | — |

**Total: 5 PRDs, 31 deliverables**

---

# Epic 7 — Success Metrics (Final Gate)

All must be true to close Epic 7:

- [ ] All 5 transaction views render live Plaid data with zero mock data references
- [ ] `InvestmentTransaction.count > 0` and `CreditTransaction.count > 0` after backfill
- [ ] Page load < 500ms for paginated transaction views (25 per page)
- [ ] Zero N+1 queries detected in development logs
- [ ] Transfer dedup correctly suppresses matched inbound legs
- [ ] Summary aggregates from SQL (not in-memory)
- [ ] Recurring expenses from `RecurringTransaction` model (Plaid authoritative)
- [ ] All tests green (`rails test`)
- [ ] All 5 PRDs scored ≥ 90 by QA Agent
- [ ] All 5 branches merged to `main`
- [ ] `0001-implementation-status.md` fully updated

---

# Estimated Timeline

| PRD | Effort | Cumulative |
|-----|--------|-----------|
| 7-01 | 2–3 days | 2–3 days |
| 7-02 | 1–2 days | 3–5 days |
| 7-03 | 2–3 days | 5–8 days |
| 7-04 | 1–2 days | 6–10 days |
| 7-05 | 1–2 days | 7–12 days |

**Total: ~7–12 days**
