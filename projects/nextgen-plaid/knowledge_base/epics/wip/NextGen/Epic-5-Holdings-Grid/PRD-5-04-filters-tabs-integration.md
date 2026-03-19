# PRD 5-04: Holdings Grid – Account Filter & Asset Class Tabs Integration

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Integrate saved account filter selector and asset class tabs into the holdings grid UI. Ensure filters compose with data provider and reset pagination appropriately.

## Requirements

### Functional
- **Saved account filter selector** (using ViewComponent from PRD 5-01) at top of grid
- **DaisyUI tabs**: All Positions | Stocks & ETFs | Mutual Funds | Bonds, CDs & MMFs
- **Asset class mapping**:
  - All Positions → all asset_class values
  - Stocks & ETFs → equity, etf
  - Mutual Funds → mutual_fund
  - Bonds, CDs & MMFs → bond, fixed_income, cd, money_market
- On selection/change: update params, reload via Turbo/Hotwire or full request
- Default: "All Accounts" + "All Positions"
- Reset to page 1 on any filter change
- Preserve other params (sort, snapshot, search)

### Non-Functional
- Responsive tabs (stack on mobile if needed)
- Preserve state in URL params for bookmarking
- DaisyUI professional styling (no playful elements)

## Architectural Context
Update HoldingsController to handle filter params (account_filter_id, asset_class). Use ViewComponent for tabs and selector. Hotwire Turbo Frames for seamless updates. Pass params to data provider service.

## Acceptance Criteria
- Selecting a saved filter shows only matching holdings
- Asset class tab filters correctly to mapped values
- Combined filters (account + asset class) work correctly
- Page resets to 1 on any filter change
- UI reflects active selections (highlighted tab, selected filter)
- URL params update to reflect current state
- Totals update to match filtered set

## Test Cases
- **Controller**: filter params passed correctly to data provider
- **View**: tabs highlight active; selector shows selected filter
- **Capybara**:
  - Click tab → verify filtered rows and updated totals
  - Select filter → verify results match criteria
  - Combine filters → verify intersection logic
  - Change filter → verify page reset to 1
- **Edge**: no matching holdings (show empty state), all filters cleared

## Manual Testing Steps
1. Load holdings grid → verify "All Accounts" + "All Positions" selected
2. Select "Trust Accounts" filter → verify only trust account holdings shown
3. Click "Stocks & ETFs" tab → verify only equity/etf holdings shown
4. Combine both filters → verify intersection (trust accounts AND stocks/etfs)
5. Verify totals reflect filtered set (not all holdings)
6. Navigate to page 3, then change filter → verify page resets to 1
7. Bookmark URL → reload → verify filters preserved
8. Clear all filters → verify full holdings set shown
9. Mobile: verify tabs stack or scroll horizontally

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-04-filters-tabs-integration`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-01 (SavedAccountFilter model and selector component)
- PRD 5-02 (Data provider service)
- PRD 5-03 (Core table structure)

## Blocked By
- PRD 5-03 must be complete

## Blocks
- PRD 5-05 (Search/sort will extend this filtering)
- PRD 5-12 (Comparison mode uses same filter controls)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-01: Saved Account Filters](./PRD-5-01-saved-account-filters.md)
- [PRD 5-02: Data Provider Service](./PRD-5-02-data-provider-service.md)
- [PRD 5-03: Core Table Pagination](./PRD-5-03-core-table-pagination.md)
