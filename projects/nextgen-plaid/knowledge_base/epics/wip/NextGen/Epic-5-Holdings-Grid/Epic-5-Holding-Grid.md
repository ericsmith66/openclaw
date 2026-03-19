Here is the updated and consolidated **Epic: Investment Holdings Grid View**, with all relevant comments, answers, objections, suggestions, and refinements from Junie's feedback incorporated inline where they affect scope, decisions, architecture, UX, or priorities.

### Epic: Investment Holdings Grid View

**Goal**
Deliver a professional, interactive, server-side holdings/positions grid focused on investment accounts, providing real-time and historical views, powerful filtering, multi-account visibility, security-level detail pages (with related transactions), and reliable full-dataset summaries — serving as the core portfolio analysis interface for HNW users.

**Business Value**
Enables fast insight into portfolio composition, gains/losses, concentration, and historical performance. Provides clean data foundation for AI advisor prompts and Python curriculum simulators (Monte Carlo, estate tax, GRAT, etc.).

**Core Principles**
- All totals, filtering, sorting, aggregation and calculations operate on the **full filtered dataset** (never just the visible page)
- Server-side everything via dedicated data provider service
- Reusable saved account filters across app (holdings, net worth, transactions, etc.)
- Point-in-time holdings snapshots for historical views and comparisons
- Institutional UX (Tailwind + DaisyUI, professional, no playful elements)
- Privacy-first: user-scoped, PostgreSQL RLS policies (not just app-level), attr_encrypted for sensitive fields
- Performance-first: monitor slow queries, add caching where needed, accept short-term trade-offs for low user count (<10 users)
- Data freshness & disclaimers clearly visible

**Key Decisions from Feedback**
- **Snapshot storage**: Full jsonb snapshots for now; retention policy, delta storage, monitoring deferred until real usage data shows need
- **Enrichment source**: Financial Modeling Prep (FMP) → document rate limits & tier in knowledge_base
- **Multi-account cost basis**: Phase 1 = single-account aggregation only (sum qty, sum value, sum G/L $); weighted average cost & accurate % deferred to future PRD
- **RLS**: PostgreSQL native RLS policies (user_id = current_setting('app.current_user_id')) + app-level scoping in data provider
- **"All" rows per page**: Keep option; add subtle warning toast when >400 rows
- **Totals caching**: Nightly invalidation + short TTL Rails.cache (4h) for user/filter totals
- **Snapshot creation**: Real-time for v1; move to Solid Queue + progress if >1.5–2s in practice
- **Snapshot schedule**: Daily at ~1:30 AM CST (after US after-hours)
- **Enrichment freshness colors**: <1 business day = green, 1–3 business days = yellow/amber, >3 = red
- **Security detail route**: `/portfolio/securities/:security_id`
- **Historical securities**: Keep accessible if in snapshots or have transactions
- **Transactions grid**: Show all txns with matching `security_id` (no filtering by investment vs non-investment)
- **Stale holdings**: Show last known + enrichment age prominently
- **Deleted accounts**: Preserve name/mask in snapshot JSON
- **Defaults**: “All Accounts” filter default; reset to page 1 on filter/sort/per-page change

**User Capabilities**
- Apply saved account filters (reusable across app)
- Filter by asset class tabs
- Global/per-column search & sort
- Choose rows per page: 25 / 50 (default) / 100 / 500 / All
- View accurate grand totals reflecting full filtered set
- See enrichment last-updated timestamp with color coding
- Expand multi-account securities to see per-account breakdown
- Navigate to security detail page (enrichment + per-account holdings + transactions grid)
- View holdings as of past snapshots
- Compare snapshots (or snapshot vs live) with period returns & visual diffs
- Manage manual snapshots

**Key Screen Components**

1. **Main Holdings Grid** (`/portfolio/holdings`)
   - Top controls: saved account filter selector, asset class tabs, snapshot selector, compare-to selector, global search
   - Summary cards: Portfolio Value, Total G/L ($/%), Period Return %, Day’s G/L (live), Est. Annual Income — **always full filtered set**
   - Table: expandable rows for multi-account, clickable → security detail
   - Footer: showing X–Y of Z, rows-per-page dropdown, pagination
   - Warning toast when showing >400 rows on “All”

2. **Security Detail Page** (`/portfolio/securities/:security_id`)
   - Header: Ticker + Name + Logo + Price + Enrichment Updated (colored)
   - Sections: Core Data, Market & Valuation, Fundamentals, Holdings Summary, Per-Account Breakdown
   - Transactions Grid: all txns with matching security_id
     - Columns: Date, Type, Description, Amount, Quantity, Price, Fees, Source, Account
     - Pagination, sort (date desc default), rows-per-page selector
     - Grand totals (invested, proceeds, net cash flow, dividends)

**Holdings Grid Columns** (updated with feedback)

| Column                  | Source / Behavior                              | Comparison Extra               | Sortable | Searchable | Notes / Style                        |
|-------------------------|------------------------------------------------|--------------------------------|----------|------------|--------------------------------------|
| Symbol                  | ticker_symbol                                  | Highlight added/removed        | Yes      | Yes        | Bold                                 |
| Description             | name                                           | Highlight changes              | Yes      | Yes        | Truncate                             |
| Asset Class             | asset_class                                    | —                              | Yes      | Yes        | Badge                                |
| Price                   | institution_price                              | Delta $/%                      | Yes      | No         | Currency                             |
| Quantity                | quantity (sum if multi-account)                | Delta quantity                 | Yes      | No         | Commas                               |
| Value                   | market_value (sum if multi-account)            | Delta $/%                      | Yes      | No         | Bold currency                        |
| Cost Basis              | cost_basis (sum only in phase 1)               | —                              | Yes      | No         | Currency                             |
| Unrealized G/L ($)      | unrealized_gain_loss (sum)                     | Delta $                        | Yes      | No         | Green/red                            |
| Unrealized G/L (%)      | calculated                                     | Delta %                        | Yes      | No         | Green/red                            |
| Period Return %         | —                                              | (end-start)/start *100         | Yes      | No         | Bold green/red                       |
| Period Delta Value      | —                                              | end-start                      | Yes      | No         | Green/red                            |
| Enrichment Updated      | security_enrichments.enriched_at               | —                              | Yes      | No         | Color: green/yellow/red thresholds   |
| % of Portfolio          | (value / total portfolio value) * 100          | —                              | Yes      | No         | Percentage, 2 decimals               |

**Style Guide**
- Professional institutional (JPMC/Schwab style)
- Gains: Emerald #10B981
- Losses: Rose #EF4444
- Accents: Indigo #6366F1
- Tables: zebra, hover, sticky header
- Expand: DaisyUI collapse + chevron
- Disclaimers: visible for estimates, educational use only

**PRD #1: Holdings Grid – Data Provider Service**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Create a dedicated service class (HoldingsGridDataProvider) that centralizes all data querying, filtering, search, sort, aggregation, multi-account grouping, snapshot loading, enrichment joins, and full-dataset summary calculations. This keeps controllers thin, promotes testability, and ensures totals always reflect the full filtered result set.

**Requirements**:
- **Functional**:
  - Accepts params hash: account_filter_id (or criteria), asset_class, snapshot_id (or :live), search_term, sort_column/dir, page, per_page (25/50/100/500/all)
  - Filters to investment accounts only (plaid_account_type in investment categories)
  - Supports saved account filters via JSON criteria (institution_ids, ownership_types, asset_strategy, trust_code, etc.)
  - Loads from HoldingsSnapshot JSON when snapshot_id present (else live Holdings)
  - Joins security_enrichments for enriched_at and other data
  - Aggregates multi-account holdings (sum qty/value/G/L $; phase 1: no weighted cost basis)
  - Computes full-dataset totals: portfolio_value, total_gl_dollars, total_gl_pct, period_return_pct (if comparison), etc.
  - Returns: paginated holdings relation/array + summary hash + total_count
- **Non-Functional**:
  - Uses Rails.cache with 4h TTL for totals (keyed by user_id + filter_hash); nightly invalidation
  - Server-side only; efficient indexes assumed (add if missing on security_id, account_id, asset_class, date)
  - Handles "All" per_page by disabling pagination
  - RLS enforced automatically via Postgres policies
  - Graceful handling of empty results, no snapshots, missing enrichment

**Architectural Context**: Plain Ruby service class in app/services/. Uses Holdings.joins(:account, :security_enrichment).where(...). For snapshots: parses JSON and applies same filters in Ruby or PG jsonb queries. Integrates with SavedAccountFilters model. Prepares for future Ransack or manual SQL for search/sort.

**Acceptance Criteria**:
- Totals always match full filtered set (verified via count & SUM queries)
- Snapshot mode returns historical data matching stored JSON
- Multi-account securities return aggregated parent + expandable details
- Per-page "All" returns all records without pagination
- Cache hit/miss behaves correctly; totals update after nightly sync
- Filters to investment accounts only

**Test Cases**:
- RSpec: mock params with various filters/snapshot_id; assert correct relation, totals, pagination
- Cache: verify fetch vs compute on repeated calls
- Edge: empty portfolio, no enrichment, multi-account with differing cost bases (phase 1 sums only), "All" per_page
- Performance: benchmark totals query <200ms for 500 holdings

**Workflow**: Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch feature/prd-1-holdings-grid-data-provider. Ask questions/plan in log. Commit green code only.

---

**PRD #2: Saved Account Filters – Model, CRUD & UI Selector**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Implement model, CRUD interfaces, and reusable selector component for saved account filter sets. These are reusable across holdings, net worth, transactions, and future reports.

**Requirements**:
- **Functional**:
  - Model: user_id, name (unique per user), criteria (jsonb: account_ids array, institution_ids, ownership_types ["Individual","Trust","Other"], asset_strategy, trust_code, holder_category, etc.)
  - CRUD: index (list user's filters), new/edit (form for name + multi-select accounts or criteria builder), create/update/delete
  - Selector: ViewComponent dropdown/pills showing user's filters + "All Accounts" default
  - When selected, passes criteria to data provider
- **Non-Functional**:
  - Validates name uniqueness per user
  - JSON schema validation on criteria (optional)
  - Scoped to current_user only (RLS + app scoping)
  - Reusable component for other views

**Architectural Context**: Rails model `SavedAccountFilter` belongs_to :user. Controller in app/controllers/saved_account_filters_controller.rb. ViewComponent for selector. Criteria serialized as JSON for flexibility.

**Acceptance Criteria**:
- User can create filter named "Trust Assets" selecting trust-owned accounts
- Selector appears in holdings grid and applies filter correctly
- Default "All Accounts" selected on first visit
- Delete works; list shows only own filters
- Criteria persists and deserializes correctly

**Test Cases**:
- Model: valid/invalid criteria, uniqueness
- Controller: CRUD actions, authorization
- ViewComponent: renders dropdown with options
- Integration: select filter → holdings grid shows only matching accounts
- Edge: empty criteria = all accounts

**Workflow**: Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch feature/prd-2-saved-account-filters. Ask questions/plan in log. Commit green code only.

---

**PRD #3: Holdings Grid – Core Table, Pagination & Per-Page Selector**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Build the main holdings grid view, route, and controller using the data provider. Include pagination, per-page selector, full-dataset totals display, and warning for large "All" views.

**Requirements**:
- **Functional**:
  - Route: GET /portfolio/holdings
  - Controller uses DataProvider with params
  - Displays summary cards with full totals
  - Table renders paginated holdings (or all if selected)
  - Footer: "Showing 1–50 of 342 holdings", rows-per-page dropdown (25/50/100/500/All), pagination
  - Reset to page 1 on filter/per-page/sort change
  - Toast warning if count >400 and "All" selected
- **Non-Functional**:
  - Responsive (horizontal scroll on table for mobile/desktop)
  - Uses DaisyUI table (zebra stripes, hover, sticky header)

**Architectural Context**: HoldingsController#index. Uses ViewComponents for summary cards, table rows, footer. Pagination via pagy or kaminari. Hotwire/Turbo for dynamic updates where possible.

**Acceptance Criteria**:
- Grid loads with default 50 per page and "All Accounts"
- Changing per-page updates table and resets pagination
- "All" disables pagination controls and shows all records
- Totals always match full filtered count
- Warning toast appears for large "All" views

**Test Cases**:
- Controller: params handling, data provider call
- View: renders columns, summary, footer correctly
- Capybara: change per-page, verify row count; select "All", verify no pagination
- Edge: 0 holdings (empty state), very large set

**Workflow**: Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch feature/prd-3-holdings-grid-core-table. Ask questions/plan in log. Commit green code only.

---

**PRD #4: Holdings Grid – Account Filter & Asset Class Tabs Integration**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Integrate saved account filter selector and asset class tabs into the holdings grid UI. Ensure filters compose with data provider and reset pagination appropriately.

**Requirements**:
- **Functional**:
  - Saved account filter selector (using ViewComponent from PRD #2) at top
  - DaisyUI tabs: All Positions | Stocks & ETFs | Mutual Funds | Bonds, CDs & MMFs (map to asset_class values)
  - On selection/change: update params, reload via Turbo/Hotwire or full request
  - Default: "All Accounts" + "All Positions"
  - Reset to page 1 on any filter change
- **Non-Functional**:
  - Responsive tabs (stack on mobile if needed)
  - Preserve other params (sort, snapshot, etc.)

**Architectural Context**: Update HoldingsController to handle filter params. Use ViewComponent for tabs and selector. Hotwire Turbo Frames for seamless updates.

**Acceptance Criteria**:
- Selecting a saved filter shows only matching holdings
- Asset class tab filters correctly
- Combined filters (account + asset class) work
- Page resets to 1 on change
- UI reflects active selections

**Test Cases**:
- Controller: filter params passed to data provider
- View: tabs highlight active; selector shows selected
- Capybara: click tab → verify filtered rows; select filter → verify results
- Edge: no matching holdings (empty state)

**Workflow**: Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch feature/prd-4-account-filter-tabs. Ask questions/plan in log. Commit green code only.

---

**PRD #5: Holdings Grid – Columnar Search, Sort & Enrichment Freshness Column**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Implement server-side global + columnar search, sortable columns, and the "Enrichment Updated" column with conditional coloring.

**Requirements**:
- **Functional**:
  - Global search across symbol, description, sector
  - Per-column sort (click headers): price, value, gains %, quantity, enrichment_updated, % of Portfolio, etc.
  - "Enrichment Updated" column: formatted datetime from enriched_at; color badge (green <1 business day, yellow 1–3, red >3)
  - Search/sort apply to full dataset (with pagination)
  - Preserve search/sort across pagination and filter changes
- **Non-Functional**:
  - Efficient (use indexes, avoid N+1)
  - Join security_enrichments safely (left join)

**Architectural Context**: Extend DataProvider with search (ILIKE or full-text) and sort params. Use manual SQL or Ransack-lite for flexibility. ViewComponent for sortable header cells.

**Acceptance Criteria**:
- Search term filters rows correctly
- Clicking column header toggles asc/desc
- Enrichment column shows correct datetime and color
- Sort/search work in snapshot mode and with multi-account aggregation
- Performance remains acceptable

**Test Cases**:
- Service: search/sort params produce correct query/results
- View: headers show sort icons; enrichment cells have correct classes/colors
- Capybara: enter search → filtered results; click sort → ordered rows
- Edge: no enrichment (N/A + red), business day calculation across weekends

**Workflow**: Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch feature/prd-5-search-sort-enrichment. Ask questions/plan in log. Commit green code only.



**PRD #6: Holdings Grid – Multi-Account Row Expansion & Aggregation**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Enable expandable rows in the holdings grid for securities held across multiple accounts, showing aggregated parent row totals and a collapsible sub-table with per-account breakdown (quantity, value, cost basis, unrealized G/L).

**Requirements**:
- **Functional**:
  - In data provider: detect securities with count >1 across accounts; return aggregated parent (sum quantity, sum value, weighted cost basis placeholder or sum only in phase 1, sum G/L $)
  - Render chevron icon on qualifying rows (DaisyUI collapse component)
  - On expand: show sub-table indented/lighter background with columns: Account (name/mask), Quantity, Value, Cost Basis, Unrealized G/L ($/%), Acquisition Date (if varies)
  - Parent row aggregates remain visible; sub-rows do not duplicate full metadata
  - Clickable parent row still navigates to security detail page
  - Works in live and snapshot modes
- **Non-Functional**:
  - No N+1 queries (preload accounts via joins or eager load)
  - Sub-table responsive (stack on mobile)
  - Expand/collapse state preserved on pagination/filter changes (via Turbo or client-side if feasible)

**Architectural Context**: DataProvider returns nested structure (parent + children array for multi-account). ViewComponent for expandable row and sub-table. Use DaisyUI collapse/accordion with chevron icons. Hotwire Turbo for smooth expand without reload.

**Acceptance Criteria**:
- Security held in 3 accounts shows chevron and aggregates correctly (sums)
- Expand reveals sub-table with correct per-account details
- Parent aggregates update with filters/snapshot
- Navigation from parent row goes to detail page
- No performance regression on expand

**Test Cases**:
- Service: mock multi-account holdings; assert aggregated parent + children array
- ViewComponent: renders chevron only when >1 account; sub-table matches data
- Capybara: click chevron → sub-table visible; verify values; click parent → navigates
- Edge: single-account (no chevron), zero holdings, snapshot with historical multi-account

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-6-multi-account-expansion. Ask questions/plan in log. Commit green code only.

---

**PRD #7: Security Detail Page**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Build a dedicated page for individual securities showing comprehensive enrichment data, aggregated holdings across accounts, and a full transactions grid for all activity linked to the security_id.

**Requirements**:
- **Functional**:
  - Route: GET /portfolio/securities/:security_id
  - Header: Ticker + Name + Logo (if enriched) + Current Price + Enrichment Updated (colored per thresholds)
  - Sections (DaisyUI cards/accordion):
    - Core: type, sector, industry, CUSIP/ISIN, description
    - Market: price, market cap, etc.
    - Fundamentals: P/E, beta, dividend yield, etc.
    - Holdings Summary: total qty/value, avg cost (sum phase 1), total G/L
    - Per-Account Breakdown table: Account, Qty, Value, Cost, G/L
    - Transactions Grid: all Transaction.where(security_id: params[:security_id]), sorted date desc
      - Columns: Date, Type, Description, Amount (green/red), Quantity, Price, Fees, Source, Account
      - Pagination, rows-per-page (25/50/100/All), grand totals (invested/proceeds/net/dividends)
  - Back link preserves grid filters/snapshot
  - Shows historical securities if in snapshots or transactions
- **Non-Functional**:
  - Joins: holdings, accounts, security_enrichments, transactions
  - Responsive layout (stack sections on mobile)

**Architectural Context**: SecuritiesController#show. Use ViewComponents for sections and transaction table. Reuse data provider logic where possible for holdings summary. Turbo Frames for transaction pagination if needed.

**Acceptance Criteria**:
- Page loads with correct security data and freshness color
- Holdings summary aggregates across accounts
- Transactions grid shows only matching security_id txns
- All sections render gracefully if data missing
- Navigation back to grid preserves state

**Test Cases**:
- Controller: fetches correct security, preloads associations
- View: header colors match thresholds; transactions paginate
- Capybara: visit page → verify sections; paginate txns → correct rows
- Edge: no transactions (placeholder), sold security (still shows), no enrichment

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-7-security-detail-page. Ask questions/plan in log. Commit green code only.

---

**PRD #8: Holdings Snapshots – Model & JSON Storage**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Define the HoldingsSnapshot model to store point-in-time JSON representations of holdings data per user or per account, enabling historical views and comparisons.

**Requirements**:
- **Functional**:
  - Fields: user_id (bigint, fk), account_id (bigint, fk, optional), snapshot_data (jsonb, not null), name (string, optional), created_at
  - JSON structure: {holdings: [{ticker_symbol:, quantity:, market_value:, cost_basis:, unrealized_gl:, asset_class:, security_id:, ...}], totals: {portfolio_value:, gl_dollars:, ...}}
  - Scopes: by_user, by_date_range, recent_first, per_account
- **Non-Functional**:
  - Index on user_id + created_at, account_id
  - RLS policy: USING (user_id = current_setting('app.current_user_id')::bigint)
  - Validate jsonb structure minimally (array present)
  - Limit size <1MB per record (validation)

**Architectural Context**: rails g model HoldingsSnapshot user:references account:references snapshot_data:jsonb name:string. Migration with indexes. Postgres jsonb for queryability (e.g., jsonb_path_query).

**Acceptance Criteria**:
- Snapshot creatable with valid JSON via console
- Queryable by user/date/account
- RLS prevents cross-user access
- JSON round-trips without loss
- Size validation prevents huge records

**Test Cases**:
- Model: valid/invalid JSON, scopes return correct records
- RSpec: RLS test (Pundit or manual), jsonb queries
- FactoryBot: create snapshot, assert structure
- Edge: empty holdings array, no account_id (user-level)

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-8-holdings-snapshots-model. Ask questions/plan in log. Commit green code only.

---

**PRD #9: Holdings Snapshots – Creation Service & Scheduled Job**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Implement a service and Solid Queue (ActiveJob) job to capture current holdings as JSON snapshots, supporting manual triggers and daily scheduled runs (~1:30 AM CST).

**Requirements**:
- **Functional**:
  - CreateHoldingsSnapshotService: input user_id, optional account_id; fetches via data provider (live mode), serializes to JSON, saves record
  - Job: CreateHoldingsSnapshotsJob.perform_later(user_id: , account_id: nil) – async creation
  - Schedule: daily at 1:30 AM CST (via Solid Queue recurring tasks in `config/recurring.yml`)
  - Idempotent: skip if recent snapshot (<24h) unless forced
  - Manual trigger via console or future UI button
- **Non-Functional**:
  - Solid Queue for background processing
  - Error handling: retry on transient failures, log Plaid issues
  - Timestamps accurate (created_at = Time.current)

**Architectural Context**: app/services/create_holdings_snapshot_service.rb. Rails job: rails g job CreateHoldingsSnapshots. Use data provider in :live mode. Schedule via Solid Queue recurring tasks (`config/recurring.yml`).

**Acceptance Criteria**:
- Service creates snapshot matching current holdings
- Job enqueues and processes async
- Daily schedule runs at correct time
- Recent duplicate skipped unless forced
- Handles empty portfolios gracefully

**Test Cases**:
- Service: mock data provider; assert JSON saved correctly
- Job: enqueue, perform, verify DB insert
- VCR/WebMock: mock any external calls
- Edge: Plaid error (logs, no save), very large portfolio

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-9-snapshots-creation-job. Ask questions/plan in log. Commit green code only.

---

**PRD #10: Holdings Snapshots – Comparison & Performance Calculation Service**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Build a service to compare two snapshots (or one snapshot vs current live) and compute performance metrics (period return %, value deltas, added/removed positions).

**Requirements**:
- **Functional**:
  - HoldingsSnapshotComparator service: input start_snapshot_id, end_snapshot_id (or :current for live)
  - Output JSON/hash: overall {period_return_pct:, delta_value:, delta_pct:}, by_ticker {AAPL: {delta_qty:, delta_value:, return_pct:, status: :added/:removed/:changed}}
  - Simple return: (end_value - start_value) / start_value * 100
  - Match holdings by ticker_symbol or security_id
  - Flag added/removed/changed positions
- **Non-Functional**:
  - Efficient Ruby comparison (O(n) via hashes)
  - Real-time for v1; monitor for future async
  - Handles mismatched structures gracefully

**Architectural Context**: Plain service app/services/holdings_snapshot_comparator.rb. Fetches snapshots, parses JSON, compares. For :current uses data provider live fetch.

**Acceptance Criteria**:
- Compares two snapshots accurately (return %, deltas)
- Snapshot vs live works
- Correctly flags added/removed/changed
- Output structured and valid
- Performance acceptable for 500 holdings

**Test Cases**:
- Service: setup fixtures (two snapshots); assert diffs, returns, flags
- Edge: no overlap, added/removed only, quantity change, zero start value
- Integration: call with real IDs, verify output

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-10-snapshots-comparison. Ask questions/plan in log. Commit green code only.

Next steps:
- Which PRD would you like to prioritize for implementation first (e.g., #1 Data Provider as foundation, or #7 Security Detail for quick user value)?
- Or do you want PRDs 11–13 next?

Let me know.
Here are the remaining PRDs for the **Epic: Investment Holdings Grid View** (PRD #11 through #13, plus the two additional ones we identified earlier as #14 and #15).

These complete the full set of atomic PRDs we outlined in the epic.

**PRD #11: Holdings Grid – Snapshot Selector & Historical View Mode**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Add UI controls to the holdings grid to select and display holdings as of a specific historical snapshot date (or latest live data), integrating with the data provider to load snapshot data instead of live holdings when selected.

**Requirements**:
- **Functional**:
  - Dropdown selector in grid header: “Latest (live)” + list of available snapshot dates/times (sorted descending)
  - On selection: pass snapshot_id to data provider; load holdings from JSON instead of live query
  - Preserve current filters (account, asset class, search, sort) when switching snapshots
  - Show “Historical view as of [date/time]” label when not live
  - Default: Latest (live)
- **Non-Functional**:
  - Responsive dropdown (DaisyUI select)
  - Use Turbo/Hotwire for seamless reload without full page refresh
  - Handle no snapshots available (disable selector or show message)

**Architectural Context**: Update HoldingsController to accept snapshot_id param and pass to DataProvider. ViewComponent for snapshot selector. DataProvider handles :live vs snapshot_id logic (JSON parsing + filtering in Ruby or PG jsonb when feasible).

**Acceptance Criteria**:
- Dropdown lists recent snapshots + “Latest (live)”
- Selecting a snapshot reloads grid with matching historical data
- Filters and sort persist across snapshot changes
- Live mode shows current holdings correctly
- Empty snapshot list shows graceful message

**Test Cases**:
- Controller: snapshot_id param → correct data provider call
- View: selector renders options; active snapshot highlighted
- Capybara: select past date → verify table reflects snapshot data
- Edge: no snapshots, switch back to live, snapshot with missing securities

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-11-snapshot-selector-historical. Ask questions/plan in log. Commit green code only.

---

**PRD #12: Holdings Grid – Comparison Mode UI & Visual Diffs**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Add a “Compare to” selector in the grid header that triggers comparison mode, displaying period return %, value deltas, and visual highlighting (added/removed/changed rows) using data from the comparison service.

**Requirements**:
- **Functional**:
  - Secondary dropdown: “Compare to” → list of snapshot dates + “Current live”
  - When selected: call HoldingsSnapshotComparator with start (current/snapshot) and end, get diffs
  - Add columns: Period Return %, Period Delta Value (green/red)
  - Row highlighting: green tint = added, red tint + strikethrough = removed, amber cells = changed quantity/value
  - Summary section adds “Period Return %” and “Period Delta $”
  - Toggle to exit comparison mode (reset to single view)
- **Non-Functional**:
  - Real-time comparison for v1; monitor performance
  - Clear visual distinction between added/removed/changed
  - Responsive (extra columns scroll horizontally if needed)

**Architectural Context**: Extend HoldingsController to handle compare_to param, call comparator service, merge diff data into view. Use ViewComponent for diff columns and row highlighting classes. DaisyUI color utilities for green/red/amber.

**Acceptance Criteria**:
- Comparison mode activates with correct extra columns
- Rows highlight added/removed/changed accurately
- Summary shows period metrics
- Exit comparison returns to normal view
- Works with account/asset filters

**Test Cases**:
- Service integration: mock comparator output; assert diff columns populated
- View: correct classes applied to rows/cells
- Capybara: select compare → verify highlights & extra columns
- Edge: no changes (no highlights), only added/removed, snapshot vs live

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-12-comparison-mode-ui. Ask questions/plan in log. Commit green code only.

---

**PRD #13: Holdings Snapshots – Management UI**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Provide a simple interface for users to view, manually create, and delete their holdings snapshots.

**Requirements**:
- **Functional**:
  - Route: GET /portfolio/snapshots (or nested under /portfolio)
  - List table: Date/Time, Scope (All / Per-account name), Manual/Auto, Holdings count
  - Button: “Create Snapshot Now” → triggers CreateHoldingsSnapshotService (user-level or selected accounts)
  - Delete button per snapshot with confirmation modal
  - Pagination if many snapshots
- **Non-Functional**:
  - Scoped to current_user only (RLS)
  - Simple, professional DaisyUI table + buttons
  - Success/error toasts on create/delete

**Architectural Context**: SnapshotsController#index, #create, #destroy. Uses HoldingsSnapshot model. Solid Queue (ActiveJob) for async create. ViewComponent for list rows and create button.

**Acceptance Criteria**:
- List shows user’s snapshots correctly
- Create button generates new snapshot
- Delete removes record after confirmation
- Toasts confirm actions
- No access to other users’ snapshots

**Test Cases**:
- Controller: CRUD actions, authorization
- View: table renders dates, counts, buttons
- Capybara: click create → snapshot appears; delete → removed
- Edge: no snapshots (empty state), create fails (toast error)

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-13-snapshots-management-ui. Ask questions/plan in log. Commit green code only.

---

**PRD #14: Holdings Grid – Export & Reporting**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Add CSV export functionality for the current filtered holdings dataset (including all columns and full totals).

**Requirements**:
- **Functional**:
  - Button/link in grid header/footer: “Export CSV”
  - Downloads file with full filtered set (not just visible page)
  - Columns match grid (Symbol, Description, Asset Class, Price, Quantity, Value, Cost Basis, G/L $, %, Enrichment Updated, % of Portfolio, etc.)
  - Include summary row at top/bottom with totals
  - Filename: e.g. “holdings-export-2026-02-04.csv”
  - Works with snapshot/comparison modes
- **Non-Functional**:
  - Use CSV generation library (e.g., csv-ruby)
  - Server-side generation to avoid browser memory issues
  - Send as attachment via send_data

**Architectural Context**: Add #export action in HoldingsController. Use data provider to fetch full dataset (no pagination). Render CSV in controller.

**Acceptance Criteria**:
- Export button triggers download
- CSV contains full filtered dataset + totals
- Columns and formatting match grid
- Snapshot mode exports historical data
- File name includes date

**Test Cases**:
- Controller: export action sends CSV with correct content
- Integration: apply filter → export → verify CSV matches filtered view
- Edge: empty set (empty CSV), large set (>1000 rows)

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-14-holdings-export. Ask questions/plan in log. Commit green code only.

---

**PRD #15: Holdings Grid – Mobile Responsive View**

**log requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**: Make the holdings grid usable on mobile devices with a simplified, responsive layout while preserving core functionality.

**Requirements**:
- **Functional**:
  - Horizontal scroll on table for wide columns
  - Stack summary cards vertically on small screens
  - Collapsible filter controls (account filter, tabs, snapshot selector) into a top bar or drawer
  - Ensure expandable rows, pagination, and per-page selector remain accessible
  - Touch-friendly buttons and dropdowns
- **Non-Functional**:
  - Tailwind responsive classes (sm:, md:, lg:)
  - DaisyUI mobile-friendly components
  - Maintain readability (font sizes, padding)

**Architectural Context**: Update grid view with responsive Tailwind/DaisyUI utilities. No new controller logic — purely view-level. Optional: mobile-specific ViewComponent variants.

**Acceptance Criteria**:
- Grid usable on mobile (tested at 375–768px widths)
- Horizontal scroll works on table
- Filters collapse gracefully
- All interactive elements (expand, sort, pagination) remain functional
- Summary cards stack vertically

**Test Cases**:
- View: responsive classes applied correctly
- Capybara (with viewport resize): verify layout changes
- Manual: test on real device (scroll, tap expand, change per-page)
- Edge: very small screen, many columns

**Workflow**: Junie: Use Claude Sonnet 4.5. Pull from master, branch feature/prd-15-holdings-mobile-responsive. Ask questions/plan in log. Commit green code only.

---

The full epic is now covered with PRDs 1–15.
