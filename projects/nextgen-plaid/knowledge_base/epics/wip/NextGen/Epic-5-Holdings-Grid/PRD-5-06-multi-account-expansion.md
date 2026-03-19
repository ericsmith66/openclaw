# PRD 5-06: Holdings Grid – Multi-Account Row Expansion & Aggregation

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Enable expandable rows in the holdings grid for securities held across multiple accounts, showing aggregated parent row totals and a collapsible sub-table with per-account breakdown (quantity, value, cost basis, unrealized G/L).

## Requirements

### Functional
- **In data provider**:
  - Detect securities with count > 1 across accounts
  - Group by `security_id` (fallback to ticker_symbol + name hash if security_id missing)
  - Return aggregated parent row:
    - Sum quantity
    - Sum market value
    - Sum unrealized G/L ($)
    - Phase 1: sum cost basis only (no weighted average)
    - Calculated unrealized G/L (%) = (sum G/L $ / sum cost basis) * 100
  - Return children array with per-account details
- **Render chevron icon** on qualifying rows (DaisyUI collapse component)
- **On expand**: show sub-table indented with lighter background
  - Columns: Account (name/mask), Quantity, Value, Cost Basis, Unrealized G/L ($), Unrealized G/L (%)
  - Optional: Acquisition Date (if varies)
- **Parent row aggregates** remain visible when expanded
- **Sub-rows** do not duplicate full metadata (no ticker/price, just account breakdown)
- **Clickable parent row** navigates to security detail page
- **Works in live and snapshot modes**
- **Expand/collapse state**: v1 does NOT persist (resets on page/filter/sort change); v2 can add localStorage persistence if needed

### Non-Functional
- No N+1 queries (preload accounts via joins or eager load)
- Sub-table responsive (stack columns on mobile if needed)
- DaisyUI collapse with smooth animation
- Expand icon (chevron-right → chevron-down on expand)

### Important Note: G/L % Accuracy
- For aggregated multi-account rows, the calculated G/L % is **approximate** (sum of G/L $ / sum of cost basis)
- This is NOT the true weighted average return (which requires cost basis weighting)
- Add tooltip on aggregated G/L %: "Approximate. Expand for per-account accuracy."
- Per-account expanded rows show accurate G/L % for that account

## Architectural Context
HoldingsGridDataProvider returns nested structure:
```ruby
{
  ticker_symbol: "AAPL",
  aggregated: true,
  accounts_count: 3,
  total_quantity: 300,
  total_value: 45000,
  total_cost_basis: 38000,
  total_unrealized_gl: 7000,
  approx_unrealized_gl_pct: 18.42,
  children: [
    { account_name: "Brokerage", account_mask: "1234", quantity: 100, value: 15000, ... },
    { account_name: "IRA", account_mask: "5678", quantity: 200, value: 30000, ... }
  ]
}
```

ViewComponent for expandable row and sub-table. Use DaisyUI collapse/accordion with chevron icons. Stimulus controller for expand/collapse interaction (optional for v1).

## Acceptance Criteria
- Security held in 3 accounts shows chevron and aggregates correctly (sums)
- Expand reveals sub-table with correct per-account details
- Parent aggregates update with filters/snapshot changes
- Navigation from parent row ticker link goes to security detail page
- No performance regression on expand (preloaded data)
- Single-account securities show no chevron (not expandable)
- Tooltip on aggregated G/L % explains approximation
- Sub-table columns are clear and formatted consistently

## Test Cases
- **Service**:
  - Mock multi-account holdings
  - Assert aggregated parent: sum qty, value, cost, G/L $
  - Assert children array contains per-account records
  - Verify grouping by security_id
  - Verify fallback grouping if security_id missing
- **ViewComponent**:
  - Renders chevron only when accounts_count > 1
  - Sub-table matches children data
  - Tooltip present on aggregated G/L %
- **Capybara**:
  - Click chevron → sub-table visible
  - Verify sub-table values match expected
  - Click parent ticker → navigates to detail page
  - Collapse → sub-table hidden
  - Filter/sort/paginate → expand state resets
- **Edge**:
  - Single-account (no chevron)
  - Zero holdings after filter
  - Snapshot with historical multi-account
  - Security with missing security_id

## Manual Testing Steps
1. Create holdings: security AAPL in 3 accounts (Brokerage, IRA, Trust)
2. Load holdings grid → verify AAPL row shows chevron
3. Verify parent row totals = sum of 3 accounts
4. Click chevron → verify sub-table expands with 3 rows
5. Verify each sub-row shows correct account name, qty, value, G/L
6. Hover over aggregated G/L % → verify tooltip explaining approximation
7. Click AAPL ticker in parent → navigates to security detail page
8. Collapse row → verify sub-table hidden
9. Change filter → verify expand state resets
10. Paginate → verify expand state resets
11. Mobile: verify sub-table scrolls or stacks appropriately

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-06-multi-account-expansion`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-02 (Data provider service aggregation logic)
- PRD 5-03 (Core table structure)

## Blocked By
- PRD 5-03 must be complete

## Blocks
- PRD 5-07 (Security detail page shows per-account breakdown similarly)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-02: Data Provider Service](./PRD-5-02-data-provider-service.md)
- [Feedback V2 - Multi-Account G/L % Objection](./Epic-5-Holding-Grid-feedback-V2.md#objection-4)
