# Junie Task Log — PRD-6-01 Transaction Views UI Polish
Date: 2026-02-16  
Mode: Brave  
Branch: feature/prd-6-01-transaction-ui-polish  
Owner: junie

## 1. Goal
- Implement PRD-6-01: Apply targeted UI polish to the five transaction views (Cash, Investments, Credit, Transfers, Summary) built during Epic-6.
- Sidebar navigation flattening, breadcrumb cleanup, sticky filter bar, account filter, recurring detection, and view-specific enhancements.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-6-transaction-ui/PRD-6-01-transaction-views-ui-polish.md`
- Existing components: `Transactions::GridComponent`, `RowComponent`, `FilterBarComponent`, `SummaryCardComponent`
- Controller: `TransactionsController` with mock data provider
- Mock data: `config/mock_transactions/*.yml`

## 3. Implementation Plan
1. Global: Flatten sidebar navigation, remove duplicate h1 titles, fix breadcrumbs
2. Global: Move filter bar above stats, make sticky, add Account dropdown
3. Global: Dynamic search placeholder per view
4. Service: Create `TransactionRecurringDetector` helper
5. Cash view: Add "RR" recurring badge
6. Investments view: Remove Merchant column, add Account column, security icon, clickable links, all columns sortable
7. Credit view: Add merchant icon and recurring badge
8. Transfers view: Remove Merchant, add direction arrows and External/Internal badges, deduplicate
9. Summary view: Add "Top 5 Recurring Expenses" card
10. Tests: Update component tests, add controller tests, add system tests

## 4. Work Log (Chronological)
- 10:00: Started PRD-6-01 work; reviewed all components, templates, controller, mock data
- 10:15: Implementation plan created and submitted for architect review

## 5. Files Changed

### New Files
- `app/helpers/transaction_recurring_detector.rb` — Recurring transaction detection heuristic
- `test/helpers/transaction_recurring_detector_test.rb` — Unit tests for recurring detector (9 tests)
- `test/controllers/transactions_controller_test.rb` — Integration tests for all five actions (14 tests)

### Modified Files
- `app/components/layout_component.rb` — Added breadcrumb_segments parameter
- `app/components/layout_component.html.erb` — Sidebar navigation flattened (Summary, Cash, Credit, Transfers, Investments), breadcrumbs support multi-level segments, removed duplicate h1 title
- `app/components/transactions/grid_component.rb` — Added view_type parameter, investments/transfers view helpers, expanded sort columns
- `app/components/transactions/grid_component.html.erb` — Conditional columns per view type, investment Account column (bold), transfers Details column, removed Merchant for investments/transfers
- `app/components/transactions/row_component.rb` — Added recurring badge, security icon, merchant icon, transfer direction/badge helpers, view_type support
- `app/components/transactions/row_component.html.erb` — RR recurring badge, security letter avatar with clickable link, merchant icon for credit, transfer From→To with direction arrow and External/Internal badge
- `app/components/transactions/filter_bar_component.rb` — Added Account dropdown, dynamic search placeholder per view_type, accounts/selected_account/view_type params
- `app/components/transactions/filter_bar_component.html.erb` — Sticky filter bar, Account dropdown, dynamic placeholder, ARIA labels
- `app/controllers/transactions_controller.rb` — Recurring detection integration, account list extraction, account filtering, search filtering, transfer deduplication, additional sort columns
- `app/views/transactions/regular.html.erb` — Multi-level breadcrumbs, filter bar above stats, view_type param
- `app/views/transactions/investment.html.erb` — Multi-level breadcrumbs, filter bar above stats, view_type param
- `app/views/transactions/credit.html.erb` — Multi-level breadcrumbs, filter bar above stats, view_type param
- `app/views/transactions/transfers.html.erb` — Multi-level breadcrumbs, filter bar above stats, view_type param
- `app/views/transactions/summary.html.erb` — Multi-level breadcrumbs, Top 5 Recurring Expenses card with See all recurring link
- `app/views/transactions/_tabs.html.erb` — Reordered tabs: Summary, Cash, Credit, Transfers, Investments
- `config/mock_transactions/cash.yml` — Added recurring transaction entries (Netflix, Spotify Premium, Planet Fitness, Comcast, Geico)
- `test/components/transactions/grid_component_test.rb` — Updated for view_type, investments/transfers column tests, sortable columns (8 tests)
- `test/components/transactions/row_component_test.rb` — Added recurring badge, security icon, transfer direction/badge, credit merchant icon tests (14 tests)
- `test/components/transactions/filter_bar_component_test.rb` — Added Account dropdown, dynamic placeholder, sticky filter tests (10 tests)

## 6. Manual Test Steps

### Global Checks
1. Start Rails server: `bin/rails server`
2. Navigate to `http://localhost:3000/transactions/regular`
3. Confirm sidebar shows direct links: Summary, Cash, Credit, Transfers, Investments (no nested "Transactions" parent)
4. Click each link; verify breadcrumb reads `Home > Transactions > [Subtype]` and title area is minimal
5. On any view, scroll down; filter bar should stay sticky at top
6. See Account dropdown right of Search input; select an account; transactions should filter to that account
7. Check placeholder text: Cash view says "Search by name, merchant…"; Investments view says "Search by name, security…"

### Cash View
8. Navigate to `/transactions/regular`
9. Identify recurring transactions (same merchant, similar amount, monthly). Should have grey "RR" pill badge

### Investments View
10. Navigate to `/transactions/investment`
11. Merchant column absent. Account column appears after Date
12. Security name has a 20px icon to its left
13. Click security name; browser should navigate to stub URL
14. Click each column header (Date, Account, Security, Quantity, Price, Amount); sort direction indicator toggles

### Credit View
15. Navigate to `/transactions/credit`
16. Merchant names have card/logo icon left of them
17. Recurring transactions show "RR" badge

### Transfers View
18. Navigate to `/transactions/transfers`
19. Merchant column absent
20. Each row shows "Transfer" type, From → To with arrow icon
21. External/internal badge appears correctly
22. Only one row per transfer pair (source leg only)

### Summary View
23. Navigate to `/transactions/summary`
24. "Top 5 Recurring Expenses" card appears below main stats
25. List shows Name, Frequency, Amount, Yearly Total sorted by yearly spend
26. "See all recurring →" link is present

### Expected Results
- All five views render without JavaScript errors
- UI matches DaisyUI business theme, dense tables, professional appearance
- All new features (badges, icons, sorting, filtering) work as described
- No regression in existing pagination, search, or type filtering
