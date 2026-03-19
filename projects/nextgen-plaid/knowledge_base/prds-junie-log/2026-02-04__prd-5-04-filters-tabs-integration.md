# Junie Task Log — PRD 5-04: Holdings Grid – Account Filter & Asset Class Tabs Integration
Date: 2026-02-04  
Mode: Brave  
Branch: <current-branch>  
Owner: Junie

## 1. Goal
- Integrate saved account filter selector and asset class tabs into `/portfolio/holdings` grid.
- Ensure filters compose (account filter + asset tab), preserve URL state, reset pagination to page 1, and totals always reflect the filtered set.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-04-filters-tabs-integration.md`
- Depends on:
  - PRD 5-01 (`SavedAccountFilter`, selector component)
  - PRD 5-02 (`HoldingsGridDataProvider`)
  - PRD 5-03 (core grid page)

## 3. Plan
1. Add DaisyUI tabs above the table:
   - All Positions | Stocks & ETFs | Mutual Funds | Bonds, CDs & MMFs
2. Implement tab → asset class mapping.
3. Extend `HoldingsGridDataProvider` to accept multi-asset filtering (`asset_classes: []`) in live + snapshot modes.
4. Update `Portfolio::HoldingsController` and `Portfolio::HoldingsGridComponent` to:
   - Preserve params in URL (saved filter, sort/dir, per_page, snapshot/search).
   - Reset page to 1 on any tab/filter change (reuse existing query signature mechanism).
5. Add tests:
   - Integration/controller tests for param plumbing and page reset.
   - Capybara smoke test to click tabs and observe filtered rows + URL params.
6. Run tests and update Epic implementation status + this log.

## 4. Manual Testing Steps (what to do / expected)
1. Visit `GET /portfolio/holdings`.
   - Expected: “All Accounts” selected, “All Positions” tab active.
2. Click “Stocks & ETFs”.
   - Expected: only `asset_class` in `equity`/`etf`; page resets to 1; URL reflects selection.
3. Click “Mutual Funds”.
   - Expected: only `mutual_fund`.
4. Click “Bonds, CDs & MMFs”.
   - Expected: only `bond`/`fixed_income`/`cd`/`money_market`.
5. Select a saved account filter.
   - Expected: holdings now reflect intersection of account filter + asset tab.
6. Navigate to page 2, change tab.
   - Expected: page resets to 1.
7. Bookmark URL and reload.
   - Expected: same tab + filter remain active.
8. Verify totals (summary cards) change to match the filtered set.
9. Mobile viewport:
   - Expected: tabs remain usable (wrap/scroll) without breaking layout.

## 5. Outcome
- PRD 5-04 implemented (awaiting review): asset-class tabs + saved account filter compose correctly, URL state preserved, pagination resets to page 1 on filter changes, and totals update to the filtered set.

## 6. Files Changed
- `app/services/holdings_grid_data_provider.rb` — add `asset_classes` support for multi-asset filtering
- `app/controllers/portfolio/holdings_controller.rb` — add `asset_tab` param, map tabs to `asset_classes`, include `asset_tab` in query signature
- `app/views/portfolio/holdings/index.html.erb` — pass `asset_tab` into grid component
- `app/components/portfolio/holdings_grid_component.rb` — accept/render tabs, include `asset_tab` in `base_params`
- `app/components/portfolio/holdings_grid_component.html.erb` — DaisyUI tabs UI
- `test/controllers/portfolio/holdings_controller_test.rb` — asserts tab mapping → provider params
- `test/smoke/portfolio_holdings_grid_capybara_test.rb` — clicks tabs and verifies filtering
- `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md` — mark PRD 5-04 implemented

## 7. Commands Run
- `RAILS_ENV=test bin/rails test test/services/holdings_grid_data_provider_test.rb test/controllers/portfolio/holdings_controller_test.rb test/smoke/portfolio_holdings_grid_capybara_test.rb`
