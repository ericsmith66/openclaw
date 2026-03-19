#### PRD-7-02: Global Account Filter & Filter Bar Refinements

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
