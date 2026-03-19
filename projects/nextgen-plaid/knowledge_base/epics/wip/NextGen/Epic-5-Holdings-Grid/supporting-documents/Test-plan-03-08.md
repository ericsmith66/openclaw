### Manual Test Plan — PRD-5-02 thru PRD-5-08 (Epic 5 Holdings Grid)

This is a **human-executable** test plan focused on **what to click/check** and **expected results**. It assumes Epic 5 items are “Implemented (Awaiting Review)” as shown in `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md`.

---

### 0) Preconditions / Test Data Setup (do once)
You need a user with multiple investment accounts, holdings, enrichments, and some transactions.

#### 0.1 Minimum accounts
Create/verify at least **3 investment accounts** for the same user:
- `Brokerage (mask 1234)`
- `IRA (mask 5678)`
- `Trust (mask 9999)`

Also have at least 1 **non-investment** account (checking/credit) to confirm “investment-only” filtering.

#### 0.2 Minimum holdings
Ensure holdings include these scenarios:
- **Multi-account security** (same `security_id`) held in at least 2–3 accounts
    - Example: `AAPL` in Brokerage + IRA + Trust
- **Single-account security**
    - Example: `MSFT` only in Brokerage
- A security with **missing enrichment** (no `security_enrichments` row)
    - Example: `NOENR`
- If possible: enough total holdings to exceed **400** (or at least simulate) to trigger the “All may be slow” toast.

#### 0.3 Enrichment freshness cases
For at least 3 securities, set enrichment timestamps so you can visually validate color thresholds:
- Enriched “today” (< 1 day) → should render **green**
- Enriched 2 days ago → should render **amber/yellow**
- Enriched 7 days ago → should render **red**

#### 0.4 Saved account filters (from PRD 5-01 dependency)
Create at least two saved filters:
- `All Accounts` (default)
- `Trust Accounts` (should include only the Trust account)
- Optional: `Empty Filter` (matches zero investment accounts) to validate empty state.

#### 0.5 Transactions (for PRD-5-07)
For at least one security (e.g., `AAPL`), ensure transactions exist across accounts:
- 2 buys
- 1 sell
- 1 dividend (type/subtype containing “dividend” per PRD)
- Include transactions for a *different* security to ensure filtering works

#### 0.6 Snapshots (PRD-5-08)
Create at least 2 snapshots:
- A **user-level** snapshot (all accounts)
- An **account-level** snapshot (one account)

---

### 1) PRD-5-03 — Holdings Grid route + pagination + per-page selector
**Page**: `GET /portfolio/holdings`

#### 1.1 Basic load
Steps:
1. Navigate to `/portfolio/holdings`

Expected:
- Page loads successfully (no error)
- Holdings table is visible
- Summary cards show totals (Portfolio Value, Total G/L, etc. per PRD)
- Footer shows “Showing X–Y of Z holdings”

#### 1.2 Default per-page
Steps:
1. Observe default per-page value (expected per PRD: 50)

Expected:
- Exactly 50 rows shown (unless total < 50)
- Pagination controls visible (unless total <= per-page)

#### 1.3 Change per-page resets to page 1
Steps:
1. Navigate to page 2 or 3 (if available)
2. Change per-page from 50 → 100

Expected:
- You return to **page 1**
- Row count updates to 100 (or fewer if not enough holdings)
- URL params reflect per-page change

#### 1.4 “All” disables pagination
Steps:
1. Set per-page to `All`

Expected:
- Pagination controls are hidden/disabled
- All filtered holdings render

#### 1.5 Large “All” warning toast
(Only if count > 400 as specified)

Steps:
1. With >400 holdings in current filters, select per-page `All`

Expected:
- A dismissible warning toast appears:
    - “Showing all holdings may be slow on your device — consider using filters”

Steps:
2. Dismiss the toast
3. Refresh page

Expected:
- Toast does **not** reappear after refresh (dismissal persisted in session)

Steps:
4. Change filters (e.g., asset class tab or saved filter)
5. Select `All` again

Expected:
- Toast reappears (because filter change resets the “dismissed” behavior per PRD)

#### 1.6 Empty state
Steps:
1. Apply a filter that yields zero holdings (e.g., `Empty Filter`)

Expected:
- “No holdings found” empty state appears
- No errors

---

### 2) PRD-5-04 — Saved account filter selector + asset class tabs
#### 2.1 Default filter state
Steps:
1. Load `/portfolio/holdings` with no params

Expected:
- Saved filter shows `All Accounts`
- Asset class tab shows `All Positions`

#### 2.2 Saved account filter applies
Steps:
1. Select saved filter `Trust Accounts`

Expected:
- Only holdings from Trust account appear
- Totals/cards update to reflect the filtered set
- Page resets to 1

#### 2.3 Asset class tabs apply
Steps:
1. With `All Accounts`, click `Stocks & ETFs`

Expected:
- Only holdings with asset_class in `{equity, etf}` appear
- Totals/cards update
- Page resets to 1

Steps:
2. Click `Mutual Funds`

Expected:
- Only `mutual_fund`

Steps:
3. Click `Bonds, CDs & MMFs`

Expected:
- Only asset_class in `{bond, fixed_income, cd, money_market}`

#### 2.4 Filters compose (intersection)
Steps:
1. Select `Trust Accounts`
2. Select `Stocks & ETFs`

Expected:
- Results match **Trust** AND **equity/etf**
- Totals/cards reflect intersection

#### 2.5 URL state preserved
Steps:
1. Apply a saved filter + tab + per-page + (if present) search/sort
2. Copy the URL and open it in a new tab

Expected:
- Same state is restored (selector/tab/per-page reflected)

---

### 3) PRD-5-05 — Search + sort + enrichment freshness column
#### 3.1 Global search filters correctly
Steps:
1. Enter global search term `AAPL`

Expected:
- Only rows matching symbol/name/sector (case-insensitive) remain
- Totals/cards update to match filtered set

Steps:
2. Search by sector (e.g., `Technology`)

Expected:
- Rows where sector matches are returned

Steps:
3. Clear search

Expected:
- Full filtered set returns

#### 3.2 Sort toggles asc/desc
Steps:
1. Click `Value` column header

Expected:
- Rows reorder by Value ascending (or whichever direction is defined as first-click)
- A sort indicator appears (arrow/chevron)

Steps:
2. Click `Value` header again

Expected:
- Sort direction reverses
- Sort indicator flips

Repeat spot-check with:
- `Symbol`
- `Unrealized G/L (%)`
- `% of Portfolio`
- `Enrichment Updated`

#### 3.3 Search + sort preserved through pagination
Steps:
1. Search `AAPL`
2. Sort by `Value`
3. Navigate to next page (if multiple pages remain)

Expected:
- Search term persists
- Sort persists
- URL params reflect both

#### 3.4 Enrichment freshness badge colors
Steps:
1. Locate security enriched today

Expected:
- Enrichment badge/cell shows **green** styling

Steps:
2. Locate security enriched ~2 days ago

Expected:
- **amber/yellow** styling

Steps:
3. Locate security enriched >3 days ago

Expected:
- **red** styling

Steps:
4. Locate security with no enrichment

Expected:
- Shows `N/A` (or similar placeholder)
- **gray** styling
- No crash

---

### 4) PRD-5-06 — Multi-account row expansion & aggregation
#### 4.1 Chevron only for multi-account
Steps:
1. Find `AAPL` (multi-account)

Expected:
- Row shows chevron/expand affordance

Steps:
2. Find `MSFT` (single-account)

Expected:
- No chevron/expand affordance

#### 4.2 Parent row aggregates are correct
Steps:
1. For multi-account security, record child account values (after expanding) for:
    - Quantity
    - Market Value
    - Cost Basis
    - Unrealized G/L ($)
2. Compare to parent row

Expected:
- Parent = sum(children) for each numeric field

#### 4.3 Expanded sub-table renders per-account breakdown
Steps:
1. Click chevron/expand

Expected:
- Sub-table appears with one row per account
- Columns include Account (name/mask), Quantity, Value, Cost Basis, Unrealized G/L ($), Unrealized G/L (%)

#### 4.4 Tooltip on aggregated G/L %
Steps:
1. Hover aggregated G/L % in parent row

Expected:
- Tooltip text indicates it’s approximate and suggests expanding for per-account accuracy

#### 4.5 Expand state resets on navigation
Steps:
1. Expand a multi-account row
2. Change filter/search/sort or paginate

Expected:
- Expanded state resets (collapsed)

#### 4.6 Parent row navigates to security detail
Steps:
1. Click parent row ticker/symbol (or the clickable region)

Expected:
- Navigates to `/portfolio/securities/:security_id` for that security

---

### 5) PRD-5-07 — Security detail page
**Page**: `GET /portfolio/securities/:security_id`

#### 5.1 Navigate from grid
Steps:
1. From holdings grid, click a security (e.g., `AAPL`)

Expected:
- Security detail page loads
- URL matches `/portfolio/securities/<security_id>`

#### 5.2 Header renders core elements
Expected header elements:
- Ticker symbol (prominent)
- Company name
- Logo if available
- Current price formatted as currency
- Enrichment updated timestamp with color badge

Expected:
- No missing-data crash; if logo/enrichment missing shows placeholder/N/A

#### 5.3 Sections present and readable
Verify these sections exist (cards/accordion):
- Core Data
- Market & Valuation
- Fundamentals
- Holdings Summary
- Per-Account Breakdown Table
- Transactions Grid

Expected:
- Layout is responsive; tables horizontally scroll when needed

#### 5.4 Holdings Summary aggregation
Steps:
1. Compare totals on detail page vs grid aggregates for same security

Expected:
- Total quantity/value/cost/unrealized G/L match expected sums across accounts

#### 5.5 Per-account breakdown matches expanded rows
Steps:
1. Compare per-account table on detail page vs the grid’s expanded sub-table

Expected:
- Same accounts appear
- Values match (qty/value/cost/G/L)

#### 5.6 Transactions grid filters by `security_id`
Steps:
1. Confirm only transactions for that security appear

Expected:
- No unrelated security transactions

#### 5.7 Transaction totals row calculations
Using the PRD definitions:
- Invested = sum(amount) where type in `[buy, contribution]` (abs)
- Proceeds = sum(amount) where type in `[sell, distribution]`
- Net Cash Flow = proceeds - invested
- Dividends = sum(amount) where type/subtype includes “dividend”

Steps:
1. Manually compute totals from the visible dataset (or compare to known seeded values)

Expected:
- Totals row matches computed numbers

#### 5.8 Pagination / per-page on transactions
Steps:
1. Change rows per page 25 → 50 → 100 → All

Expected:
- Row count changes
- Pagination behaves appropriately
- Sort order default = date descending

#### 5.9 Back link behavior
Steps:
1. From holdings grid apply filters/search/sort
2. Navigate to security detail
3. Click “← Back to Holdings”

Expected:
- Returns to holdings grid
- Preserves state if implemented via referrer or URL params (at minimum: you don’t lose context unexpectedly)

#### 5.10 Missing security 404
Steps:
1. Visit `/portfolio/securities/999999999` (invalid)

Expected:
- 404
- Friendly message: “Security not found or no longer accessible”

#### 5.11 Historical security
Steps:
1. Pick a security that is no longer held but exists in snapshots or has transactions
2. Visit its detail page

Expected:
- Page still loads and shows what data is available

---

### 6) PRD-5-08 — Holdings snapshots model & JSON storage
This is mostly data integrity + basic retrieval.

#### 6.1 Create a valid snapshot (console or UI/admin if exists)
Steps (console example conceptually):
1. Create a snapshot for the user with `snapshot_data` containing:
    - `holdings: []` array
    - `totals: { ... }`

Expected:
- Record saves successfully
- Name auto-generates if blank
- `created_at` present

#### 6.2 Validate snapshot JSON structure
Steps:
1. Attempt to create snapshot missing `holdings` key

Expected:
- Validation fails with clear error

Steps:
2. Create snapshot with `holdings: []`

Expected:
- Valid (empty holdings array should be acceptable)

#### 6.3 User-level vs account-level distinction
Steps:
1. Create one snapshot with `account_id: nil`
2. Create one snapshot with `account_id` set

Expected:
- User-level snapshot appears in user-level scope/list
- Account-level snapshot appears in account-level scope/list

#### 6.4 Size limit behavior (< 1MB)
Steps:
1. Attempt to create an oversized snapshot payload (>1MB)

Expected:
- Database constraint or model validation prevents save
- Clear error surfaced (may be exception if DB constraint)

#### 6.5 Snapshot mode consumption (ties back to PRD-5-02)
Steps:
1. Load holdings grid in snapshot mode (however snapshot selection is currently implemented)

Expected:
- Holdings shown match snapshot JSON (point-in-time)
- Enrichment freshness still reflects **current** enrichment table per PRD guidance (not frozen)

---

### 7) PRD-5-02 — Data provider behaviors (manual validation via UI)
Even though it’s a service, you can validate key behaviors via the grid + detail page.

#### 7.1 Investment-only filtering
Steps:
1. Ensure user has a non-investment account with holdings-like data or at least exists
2. Load holdings grid

Expected:
- Only investment accounts contribute to results/totals

#### 7.2 Totals reflect full dataset (not just current page)
Steps:
1. Set per-page to 25 and note summary totals
2. Go to next page

Expected:
- Summary totals remain the same (because they represent full filtered dataset)

#### 7.3 Cache invalidation (if caching is present)
Manual-ish check (best effort):
Steps:
1. Load holdings grid and note totals
2. Change a holding value (via console/admin) for the same user
3. Reload holdings grid

Expected:
- Totals reflect the new values (cache invalidated)

---

### 8) Mobile/responsiveness spot-check (PRD-5-03/5-07 non-functional)
Steps:
1. Use browser dev tools mobile viewport
2. Visit holdings grid and security detail page

Expected:
- Tables are horizontally scrollable (no layout break)
- Sections stack appropriately

---

### Open questions (so I can adjust this plan to your current UI)
1. How do you currently select `snapshot_id` in the UI (URL param, dropdown, or not yet surfaced until PRD-5-11)? If it’s not in UI yet, I can rewrite snapshot verification steps to be **console-only**.
2. Do you have a seeded persona/demo dataset you prefer for manual testing (so the plan can reference exact symbols/accounts you know exist)?

STATUS: DONE — awaiting review (no commit yet)

Notes
confusion between the portfolio page and the networth holdins page sugjest replacing networth/holdings page with the portfolio page but open to discussion

Selecting filter on portfolio holdings takes you to the networth page
columns dont line up on the portfolio holdings page
Paging on the portfolio holdings page does not seem to work
filter for ETF's mutual funds and bonds does now appear to work
should use icon next to symbol from FMP
open close for multiple holdins should be on the left not right
unrealized gains and loss does not have a dollar amount ( tried sorting up and sorting down )

