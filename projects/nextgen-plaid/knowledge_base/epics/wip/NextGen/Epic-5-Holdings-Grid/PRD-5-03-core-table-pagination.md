# PRD 5-03: Holdings Grid – Core Table, Pagination & Per-Page Selector

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Build the main holdings grid view, route, and controller using the data provider. Include pagination, per-page selector, full-dataset totals display, and warning for large "All" views.

## Requirements

### Functional
- **Route**: GET /portfolio/holdings
- **Controller** uses HoldingsGridDataProvider with params
- **Displays summary cards** with full totals:
  - Portfolio Value
  - Total Gain/Loss ($/%)
  - Day's Gain/Loss (live only)
  - Estimated Annual Income
- **Table renders** paginated holdings (or all if selected)
- **Columns** (see Epic overview for full spec):
  - Symbol, Description, Asset Class, Price, Quantity, Value
  - Cost Basis, Unrealized G/L ($), Enrichment Updated, % of Portfolio
- **Footer**:
  - "Showing 1–50 of 342 holdings"
  - Rows-per-page dropdown (25/50/100/500/All) - default 50
  - Pagination controls (hidden when "All" selected)
- **Reset to page 1** on filter/per-page/sort change
- **Toast warning** if count >400 and "All" selected:
  - Message: "Showing all holdings may be slow on your device — consider using filters"
  - Dismissible (store in session: `session[:dismissed_large_grid_warning] = true`)
  - Re-show if user chooses "All" again after filter change

### Non-Functional
- Responsive (horizontal scroll on table for mobile/desktop)
- Uses DaisyUI table (zebra stripes, hover, sticky header)
- Professional styling (Emerald #10B981 gains, Rose #EF4444 losses)
- Empty state: "No holdings found" with suggestion to sync accounts

## Architectural Context
HoldingsController#index. Uses ViewComponents for summary cards, table rows, footer. Pagination via pagy or kaminari. Hotwire/Turbo for dynamic updates where possible.

## Acceptance Criteria
- Grid loads with default 50 per page and "All Accounts" filter
- Changing per-page updates table and resets pagination to page 1
- "All" disables pagination controls and shows all records
- Totals always match full filtered count (not just page)
- Warning toast appears for large "All" views (>400), is dismissible, and persists dismissal in session
- Empty state displays when no holdings present
- Table is horizontally scrollable on small screens

## Test Cases
- **Controller**: params handling, data provider call, assigns correct instance variables
- **View**: renders columns, summary cards, footer correctly; totals match full dataset
- **Capybara**:
  - Change per-page → verify row count updates, page resets to 1
  - Select "All" → verify no pagination, warning toast appears
  - Dismiss toast → verify `session[:dismissed_large_grid_warning]` set
  - Reload with >400 holdings + "All" → toast does not reappear if dismissed
  - Change filter → toast reappears on next "All" selection
- **Edge**:
  - 0 holdings (empty state)
  - Very large set (1000+ holdings with "All")
  - Pagination boundary (last page with partial results)

## Manual Testing Steps
1. Navigate to `/portfolio/holdings`
2. Verify grid loads with 50 holdings per page (default)
3. Verify summary cards show totals for all holdings (not just page 1)
4. Change per-page to 100 → verify 100 rows displayed, pagination updated
5. Select "All" → verify all holdings displayed, pagination hidden
6. If >400 holdings, verify warning toast appears
7. Dismiss toast → verify it doesn't reappear on page refresh
8. Change filter → select "All" again → verify toast reappears
9. Test horizontal scroll on mobile viewport
10. Remove all holdings → verify empty state displays

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-03-core-table-pagination`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-01 (SavedAccountFilter model for default filter)
- PRD 5-02 (HoldingsGridDataProvider)

## Blocked By
- PRD 5-02 must be complete

## Blocks
- PRD 5-04 (Filters integration needs base table)
- PRD 5-05 (Search/sort needs base table)
- PRD 5-06 (Multi-account expansion needs base table)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-02: Data Provider Service](./PRD-5-02-data-provider-service.md)
