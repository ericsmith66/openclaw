# Junie Task Log — PRD 5-06: Holdings Grid – Multi-Account Row Expansion & Aggregation
Date: 2026-02-04  
Mode: Brave  
Branch: <current-branch>  
Owner: Junie

## 1. Goal
- Add expandable parent rows for securities held across multiple accounts.
- Render per-account child rows in an indented sub-table.
- Add tooltip clarifying aggregated G/L % is approximate.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-06-multi-account-expansion.md`
- Depends on:
  - PRD 5-02 (`HoldingsGridDataProvider` grouping)
  - PRD 5-03 (grid table)
  - PRD 5-05 (GL% column + sorting)

## 3. Plan
1. Ensure provider returns grouped structure usable by UI:
   - `{ parent:, children: }` where `children` contains per-account holdings.
2. Update `Portfolio::HoldingsGridComponent` to render DaisyUI expandable/collapsible rows:
   - Chevron shown only when `children.any?`.
   - Parent row remains visible when expanded.
   - Child sub-table rendered below parent with lighter background.
3. Child sub-table columns:
   - Account (name + mask)
   - Quantity, Value, Cost Basis, Unrealized G/L ($), Unrealized G/L (%)
4. Parent aggregated G/L (%) shows tooltip: `Approximate. Expand for per-account accuracy.`
5. Add tests: service + component + capybara.

## 4. Manual Testing Steps (what to do / expected)
1. Have a security (e.g., `AAPL`) held in 2+ accounts.
2. Visit `GET /portfolio/holdings`.
   - Expected: `AAPL` shows a chevron/expand affordance.
3. Verify parent totals = sums across accounts.
4. Expand.
   - Expected: child sub-table shows one row per account with correct per-account metrics.
5. Hover the parent G/L %.
   - Expected: tooltip explaining approximation.
6. Collapse.
   - Expected: sub-table hidden.
7. Change sort/filter/pagination.
   - Expected: any expanded rows reset (v1: no persistence).

## 5. Outcome
- PRD 5-06 implemented (awaiting review): holdings held across multiple accounts are expandable into a per-account sub-table, with aggregated parent totals and an “approximate” tooltip for parent G/L %.

## 6. Files Changed
- `app/components/portfolio/holdings_grid_component.rb` — add helpers for parent/child G/L % and account labels
- `app/components/portfolio/holdings_grid_component.html.erb` — render expandable multi-account rows using `details/summary` and a per-account sub-table
- `app/services/holdings_grid_data_provider.rb` — ensure grouped sorting uses aggregated parent values (so multi-account groups sort correctly)
- `test/services/holdings_grid_data_provider_test.rb` — assert multi-account groups include account-loaded children
- `test/smoke/portfolio_holdings_grid_capybara_test.rb` — expand/collapse smoke test and updated sort expectations under multi-account grouping
- `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md` — mark PRD 5-06 implemented

## 7. Commands Run
- `RAILS_ENV=test bin/rails test test/services/holdings_grid_data_provider_test.rb test/smoke/portfolio_holdings_grid_capybara_test.rb`
