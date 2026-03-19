# Junie Task Log — PRD 7-02: Global Account Filter & Filter Bar Refinements
Date: 2026-02-21  
Mode: Brave  
Branch: (main)  
Owner: Eric

## 1. Goal
Implement PRD 7-02: Genericize `SavedAccountFilterSelectorComponent` to accept any path helper, add the component to all five transaction views (regular, investment, credit, transfers, summary) replacing inline account select dropdown, wire `TransactionGridDataProvider` to accept `saved_account_filter_id` param, wire `Transactions::FilterBarComponent` fields to data provider, ensure Turbo Frame integration for filter changes.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/PRD-7-02-account-filter.md`
- Existing `SavedAccountFilterSelectorComponent` only works with holdings views.
- Transaction views currently have inline `<select>` account filter.
- `TransactionGridDataProvider` already supports `account_filter_id` param (used by holdings).
- `Transactions::FilterBarComponent` already includes search, date range, type filter fields.

## 3. Plan
1. Genericize `SavedAccountFilterSelectorComponent`: rename `holdings_path_helper` param to `path_helper` (keep alias), rename internal method `holdings_path` to `target_path`, update template.
2. Update existing Holdings view call sites (`NetWorth::HoldingsSummaryComponent`, `Portfolio::HoldingsGridComponent`) to use `path_helper` param.
3. Add `SavedAccountFilterSelectorComponent` to all five transaction view templates, passing appropriate `path_helper` and `turbo_frame_id`.
4. Add `@saved_account_filters` and `@saved_account_filter_id` to transaction controller actions via `before_action`.
5. Update `TransactionGridDataProvider` to accept `saved_account_filter_id` param (alias of `account_filter_id`).
6. Update `Transactions::FilterBarComponent` template: add hidden field for `saved_account_filter_id`, remove hidden field for `account`.
7. Ensure Turbo Frame integration: wrap grid and filter bar in a Turbo Frame with id `transactions_grid`.
8. Update unit tests for component, data provider, controller, and system tests.
9. Create Junie task log.

## 4. Work Log (Chronological)
- **2026-02-21 12:00** Analyzed PRD and codebase, drafted implementation plan.
- **2026-02-21 12:15** Genericized `SavedAccountFilterSelectorComponent`:
  - Modified `app/components/saved_account_filter_selector_component.rb`: added `path_helper` param, kept backward compatibility, renamed internal method.
  - Updated `app/components/saved_account_filter_selector_component.html.erb`: changed `holdings_path` to `target_path`.
- **2026-02-21 12:20** Updated existing Holdings view call sites:
  - `app/components/net_worth/holdings_summary_component.html.erb`: added `path_helper: :net_worth_holdings_path`.
  - `app/components/portfolio/holdings_grid_component.html.erb`: changed `holdings_path_helper` to `path_helper`.
- **2026-02-21 12:25** Added component to all five transaction views:
  - Replaced inline `<form>` with `<select>` in `regular.html.erb`, `investment.html.erb`, `credit.html.erb`, `transfers.html.erb`, `summary.html.erb`.
  - Passed `saved_account_filters: @saved_account_filters`, `selected_id: @saved_account_filter_id`, `base_params: request.query_parameters`, `turbo_frame_id: Transactions::GridComponent::TRANSACTIONS_GRID_TURBO_FRAME_ID`, appropriate `path_helper`.
- **2026-02-21 12:35** Added controller support:
  - Added `before_action :set_saved_account_filters` to `TransactionsController` for relevant actions.
  - Defined `set_saved_account_filters` method loading `@saved_account_filters` and `@saved_account_filter_id`.
- **2026-02-21 12:40** Updated `TransactionGridDataProvider`:
  - Modified `account_filter_id` method to read `params[:saved_account_filter_id]` first, then `params[:account_filter_id]`.
- **2026-02-21 12:45** Updated `Transactions::FilterBarComponent` template:
  - Removed hidden field for `account`.
  - Added hidden field for `saved_account_filter_id`.
- **2026-02-21 12:50** Added Turbo Frame wrapper to transaction views (except summary):
  - Wrapped container div with `<%= turbo_frame_tag Transactions::GridComponent::TRANSACTIONS_GRID_TURBO_FRAME_ID do %>` in `regular.html.erb`, `investment.html.erb`, `credit.html.erb`, `transfers.html.erb`.
- **2026-02-21 13:00** Created Junie task log (this file).
- **2026-02-21 13:05** (Pending) Run tests, update unit tests, verify functionality.

## 5. Files Changed
- `app/components/saved_account_filter_selector_component.rb`
- `app/components/saved_account_filter_selector_component.html.erb`
- `app/components/net_worth/holdings_summary_component.html.erb`
- `app/components/portfolio/holdings_grid_component.html.erb`
- `app/views/transactions/regular.html.erb`
- `app/views/transactions/investment.html.erb`
- `app/views/transactions/credit.html.erb`
- `app/views/transactions/transfers.html.erb`
- `app/views/transactions/summary.html.erb`
- `app/controllers/transactions_controller.rb`
- `app/services/transaction_grid_data_provider.rb`
- `app/components/transactions/filter_bar_component.html.erb`
- (test files pending)

## 6. Commands Run
- `find . -name \"*7-02*\"` (locate PRD)
- `grep -r \"SavedAccountFilterSelectorComponent\" app`
- Various `file_read` and `file_edit` tool calls.

## 7. Test Results & Verification
Pending.

## 8. Notes / Decisions
- Kept backward compatibility for `holdings_path_helper` param.
- Used `request.query_parameters` for `base_params` in transaction views (simpler than constructing hash).
- The `summary` view does not have a grid or filter bar, but still uses the account filter component (no Turbo Frame).
- Decided to keep `accounts` and `selected_account` parameters in `FilterBarComponent` for now (unused).