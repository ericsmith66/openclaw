# PRD 5-07: Security Detail Page

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Build a dedicated page for individual securities showing comprehensive enrichment data, aggregated holdings across accounts, and a full transactions grid for all activity linked to the security_id.

## Requirements

### Functional
- **Route**: GET /portfolio/securities/:security_id
- **Header Section**:
  - Ticker Symbol (bold, large)
  - Company Name
  - Logo (if available from enrichment)
  - Current Price (formatted currency)
  - Enrichment Updated timestamp with color badge (green/yellow/red per thresholds)
- **Sections** (DaisyUI cards/accordion):
  1. **Core Data**: type, sector, industry, CUSIP/ISIN, description
  2. **Market & Valuation**: price, market cap, 52-week high/low, volume
  3. **Fundamentals**: P/E ratio, beta, dividend yield, EPS
  4. **Holdings Summary**:
     - Total quantity across all accounts
     - Total market value
     - Average cost (sum for phase 1, note limitation)
     - Total unrealized G/L ($ and %)
  5. **Per-Account Breakdown Table**:
     - Columns: Account (name/mask), Quantity, Value, Cost Basis, Unrealized G/L ($), Unrealized G/L (%)
     - Same structure as multi-account expansion sub-table
  6. **Transactions Grid**: all Transaction.where(security_id: params[:security_id])
     - Columns: Date, Type, Description, Amount (green/red), Quantity, Price, Fees, Source, Account
     - Sort: date descending (default)
     - Pagination: 25/50/100/All rows per page
     - Grand totals row at bottom:
       - Total Invested = sum(amount) where type in ["buy", "contribution"]
       - Proceeds = sum(amount) where type in ["sell", "distribution"]
       - Net Cash Flow = proceeds - invested
       - Dividends = sum(amount) where type/subtype includes "dividend"
- **Back Link**: "← Back to Holdings" (preserves grid filters/snapshot if possible via referrer or URL params)
- **Historical securities**: Show page even if security no longer held (if exists in snapshots or has transactions)
- **Security not found**: 404 with friendly message "Security not found or no longer accessible"

### Non-Functional
- Joins: holdings, accounts, security_enrichments, transactions
- Responsive layout (stack sections on mobile, horizontal scroll on transactions table)
- DaisyUI professional styling
- No N+1 queries (preload associations)
- Handle missing enrichment gracefully (show N/A or placeholders)

## Architectural Context
SecuritiesController#show. Use ViewComponents for sections and transaction table. Reuse data provider logic where possible for holdings summary (or create SecurityDetailDataProvider service). Turbo Frames for transaction pagination if needed. Hotwire for smooth interactions.

## Transaction Grand Totals Definitions

```ruby
# In service or helper
def transaction_totals(transactions)
  {
    invested: transactions.where(type: ['buy', 'contribution']).sum(:amount).abs,
    proceeds: transactions.where(type: ['sell', 'distribution']).sum(:amount),
    net_cash_flow: proceeds - invested,
    dividends: transactions.where("type LIKE '%dividend%'").sum(:amount)
  }
end
```

## Acceptance Criteria
- Page loads with correct security data and enrichment freshness color
- Holdings summary aggregates correctly across accounts
- Per-account breakdown table matches holdings
- Transactions grid shows only transactions with matching security_id
- Transaction grand totals calculate correctly
- All sections render gracefully if data missing (show N/A, empty states)
- Pagination works on transactions grid
- Navigation back to holdings grid preserves state (filters, page, etc.)
- 404 page shows for invalid security_id
- Responsive on mobile (sections stack, tables scroll)

## Test Cases
- **Controller**:
  - Fetches correct security by ID
  - Preloads associations (holdings, accounts, enrichments, transactions)
  - Returns 404 for missing security
- **View**:
  - Header displays ticker, name, price, enrichment badge with correct color
  - Holdings summary aggregates match expected totals
  - Per-account breakdown renders correctly
  - Transactions grid paginates
  - Grand totals row shows correct calculations
- **Capybara**:
  - Visit page → verify all sections present
  - Paginate transactions → verify correct rows
  - Click back link → returns to holdings (state preserved)
  - Visit invalid ID → verify 404 message
- **Edge**:
  - No transactions (show empty state placeholder)
  - Sold security (historical, still shows data)
  - No enrichment data (N/A placeholders)
  - Single account holding (breakdown table has 1 row)

## Manual Testing Steps
1. Navigate to security detail from holdings grid (click AAPL row)
2. Verify header shows: AAPL, Apple Inc., current price, green freshness badge
3. Verify enrichment sections display data (sector, P/E, etc.)
4. Verify holdings summary: total qty, value, cost, G/L match holdings grid aggregation
5. Verify per-account breakdown table: 3 rows (Brokerage, IRA, Trust) with correct values
6. Scroll to transactions grid → verify all AAPL transactions shown
7. Verify grand totals: invested, proceeds, net, dividends calculated correctly
8. Change rows per page → verify pagination updates
9. Click "Back to Holdings" → verify returns to grid with filters preserved
10. Visit /portfolio/securities/99999 → verify 404 message
11. Mobile: verify sections stack, tables scroll horizontally
12. Visit historical security (sold months ago) → verify page still loads with data

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-07-security-detail-page`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-02 (Data provider service for holdings logic)
- PRD 5-03 (Core table/pagination components reusable)
- PRD 5-06 (Per-account breakdown similar to multi-account expansion)

## Blocked By
- PRD 5-03 must be complete

## Blocks
- None (standalone detail page)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-02: Data Provider Service](./PRD-5-02-data-provider-service.md)
- [PRD 5-06: Multi-Account Expansion](./PRD-5-06-multi-account-expansion.md)
- [Feedback V2 - Transaction Grand Totals](./Epic-5-Holding-Grid-feedback-V2.md#prd-7-security-detail-page)
