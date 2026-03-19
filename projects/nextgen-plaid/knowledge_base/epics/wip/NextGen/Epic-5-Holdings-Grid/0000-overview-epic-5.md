# Epic 5: Investment Holdings Grid View

## Goal
Deliver a professional, interactive, server-side holdings/positions grid focused on investment accounts, providing real-time and historical views, powerful filtering, multi-account visibility, security-level detail pages (with related transactions), and reliable full-dataset summaries — serving as the core portfolio analysis interface for HNW users.

## Business Value
Enables fast insight into portfolio composition, gains/losses, concentration, and historical performance. Provides clean data foundation for AI advisor prompts and Python curriculum simulators (Monte Carlo, estate tax, GRAT, etc.).

## Core Principles
- All totals, filtering, sorting, aggregation and calculations operate on the **full filtered dataset** (never just the visible page)
- Server-side everything via dedicated data provider service
- Reusable saved account filters across app (holdings, net worth, transactions, etc.)
- Point-in-time holdings snapshots for historical views and comparisons
- Institutional UX (Tailwind + DaisyUI, professional, no playful elements)
- Privacy-first: user-scoped, PostgreSQL RLS policies (not just app-level), attr_encrypted for sensitive fields
- Performance-first: monitor slow queries, add caching where needed, accept short-term trade-offs for low user count (<10 users)
- Data freshness & disclaimers clearly visible

## Key Decisions from Feedback V1 & V2

### Data Architecture
- **Snapshot storage**: Full jsonb snapshots for now; retention policy, delta storage, monitoring deferred until real usage data shows need
- **Snapshot JSON structure**: Core holding fields only (no embedded enrichment); join to current `security_enrichments` table for freshness
- **Enrichment source**: Financial Modeling Prep (FMP) → document rate limits & tier in knowledge_base/data-sources.md
- **Multi-account cost basis**: Phase 1 = sum only (no weighted average); hide Unrealized G/L (%) on aggregated rows; prioritize weighted average as PRD #16
- **Multi-account grouping**: Group by `security_id` (not ticker_symbol); fallback to ticker+name hash if security_id missing
- **RLS**: PostgreSQL native RLS policies (user_id = current_setting('app.current_user_id')) + app-level scoping in data provider
- **Cache strategy**: `"holdings_totals:v1:user:#{user_id}:filters:#{SHA256}:snapshot:#{snapshot_id||'live'}"` with 1h TTL (not 4h), invalidate on holdings update via after_commit

### User Experience
- **"All" rows per page**: Keep option; add dismissible warning toast when >400 rows (session-scoped)
- **Totals caching**: 1h TTL Rails.cache + after_commit invalidation + manual refresh button
- **Snapshot creation**: Async via Solid Queue (not real-time)
- **Snapshot schedule**: Daily at ~1:30 AM CST (after US after-hours)
- **Enrichment freshness colors**: <1 calendar day = green, 1–3 calendar days = yellow, >3 = red (v1 simple heuristic; defer market holiday calendar)
- **Asset class tabs**: Stocks & ETFs (equity, etf) | Mutual Funds (mutual_fund) | Bonds, CDs & MMFs (bond, fixed_income, cd, money_market) | All Positions (catch-all)
- **Expand state persistence**: No persistence in v1 (resets on page/filter change); defer to v2 if requested
- **Snapshot selector**: Show last 50 snapshots + "View all" link
- **Security detail route**: `/portfolio/securities/:security_id`
- **Historical securities**: Keep accessible if in snapshots or have transactions
- **Transactions grid**: Show all txns with matching `security_id` (no filtering by investment vs non-investment)
- **Stale holdings**: Show last known + enrichment age prominently
- **Deleted accounts**: Preserve name/mask in snapshot JSON
- **Defaults**: "All Accounts" filter default; reset to page 1 on filter/sort/per-page change

### Technical Details
- **Filter criteria schema**: Document in knowledge_base/data-dictionary.md: `{account_ids: [int], institution_ids: [int], ownership_types: [str], asset_strategy: str, trust_code: str, holder_category: str, context: str}`
- **Snapshot naming**: Auto = "Daily #{date}", manual = "Manual Snapshot [time]"
- **Snapshot scope**: Binary: user-level (account_id nil) or single-account (account_id present)
- **Idempotency**: Per scope: user-level or user+account; skip if <24h unless forced
- **Job retries (Solid Queue / ActiveJob)**: 3 attempts exponential backoff; on final failure → log + admin alert
- **Security matching**: Primary `security_id`, fallback ticker_symbol+name
- **Return calculation edge cases**: Start value = 0 → "N/A"; negative cost basis → show with disclaimer; moved accounts → treated as removed+added
- **Transaction totals**: Invested = sum(buy/contribution amounts); Proceeds = sum(sell/distribution); Net = proceeds - invested; Dividends = sum(dividend types)
- **Export async threshold**: >500 holdings → Solid Queue job + email signed link
- **Mobile**: Full feature parity but prioritize scrollable table + stacked cards

## User Capabilities
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
- Manage manual snapshots (create, delete, list)
- Export filtered holdings to CSV

## Key Screen Components

### 1. Main Holdings Grid (`/portfolio/holdings`)
- **Top controls**: saved account filter selector, asset class tabs, snapshot selector, compare-to selector, global search
- **Summary cards**: Portfolio Value, Total G/L ($/%), Period Return %, Day's G/L (live), Est. Annual Income — **always full filtered set**
- **Table**: expandable rows for multi-account, clickable → security detail
- **Footer**: showing X–Y of Z, rows-per-page dropdown, pagination
- **Warning toast**: when showing >400 rows on "All" (dismissible, session-scoped)

### 2. Security Detail Page (`/portfolio/securities/:security_id`)
- **Header**: Ticker + Name + Logo + Price + Enrichment Updated (colored)
- **Sections**: Core Data, Market & Valuation, Fundamentals, Holdings Summary, Per-Account Breakdown
- **Transactions Grid**: all txns with matching security_id
  - Columns: Date, Type, Description, Amount, Quantity, Price, Fees, Source, Account
  - Pagination, sort (date desc default), rows-per-page selector
  - Grand totals (invested, proceeds, net cash flow, dividends)
- **Navigation**: Breadcrumb back to holdings grid (preserving filters)

## Holdings Grid Columns

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
| Unrealized G/L (%)      | calculated (hidden on aggregated rows v1)      | Delta %                        | Yes      | No         | Green/red (per-account only)         |
| Period Return %         | —                                              | (end-start)/start *100         | Yes      | No         | Bold green/red                       |
| Period Delta Value      | —                                              | end-start                      | Yes      | No         | Green/red                            |
| Enrichment Updated      | security_enrichments.enriched_at               | —                              | Yes      | No         | Color: green/yellow/red thresholds   |
| % of Portfolio          | (value / total portfolio value) * 100          | —                              | Yes      | No         | Percentage, 2 decimals               |

## Style Guide
- Professional institutional (JPMC/Schwab style)
- Gains: Emerald #10B981
- Losses: Rose #EF4444
- Accents: Indigo #6366F1
- Tables: zebra, hover, sticky header
- Expand: DaisyUI collapse + chevron
- Disclaimers: visible for estimates, educational use only

## Database Schema

```ruby
# db/schema.rb (proposed additions)

create_table "holdings_snapshots", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.bigint "account_id"
  t.jsonb "snapshot_data", null: false
  t.string "name"
  t.datetime "created_at", null: false
  t.index ["user_id", "created_at"], order: { created_at: :desc }
  t.index ["account_id", "created_at"], order: { created_at: :desc }
  t.check_constraint "octet_length(snapshot_data::text) < 1048576", name: "snapshot_size_limit"
end

create_table "saved_account_filters", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.string "name", null: false
  t.jsonb "criteria", null: false, default: {}
  t.string "context" # optional: "holdings", "transactions", "net_worth"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["user_id", "name"], unique: true
  t.index ["user_id", "created_at"]
end

# Add to existing security_enrichments table
add_index :security_enrichments, [:security_id, :enriched_at]
add_index :security_enrichments, [:enriched_at], where: "enriched_at > NOW() - INTERVAL '7 days'"

# Add to existing holdings table
add_index :holdings, [:user_id, :security_id, :account_id]
add_index :holdings, [:security_id, :market_value]

# RLS Policies
execute <<-SQL
  ALTER TABLE holdings_snapshots ENABLE ROW LEVEL SECURITY;
  CREATE POLICY user_snapshots ON holdings_snapshots
    USING (user_id = current_setting('app.current_user_id', true)::bigint);

  ALTER TABLE saved_account_filters ENABLE ROW LEVEL SECURITY;
  CREATE POLICY user_filters ON saved_account_filters
    USING (user_id = current_setting('app.current_user_id', true)::bigint);
SQL
```

## Error Handling Strategy

### Data Provider Errors
- Missing enrichment → Use stale data + show warning
- Snapshot not found → 404 with message "Snapshot no longer available"
- Invalid filter criteria → Default to "All Accounts" + toast warning
- Cache failure → Log error, compute fresh (graceful degradation)

### Snapshot Creation Errors
- Plaid timeout → Retry 3x exponential backoff, then log failure + alert
- Holdings query failure → Capture partial data if possible, flag as incomplete
- JSON serialization error → Log stack trace, skip snapshot
- Disk full → Alert immediately, block further snapshots

### Comparison Errors
- Missing snapshot → Show error message in UI
- Mismatched structure → Attempt best-effort comparison, show warning
- Division by zero → Treat as infinite return, display "N/A"

## PRD Summary & Build Order

Based on dependency analysis, the recommended build order is:

### Foundation (Sprint 1)
- **[PRD 5-01](./PRD-5-01-saved-account-filters.md)**: Saved Account Filters – Model, CRUD & UI Selector
- **[PRD 5-02](./PRD-5-02-data-provider-service.md)**: Holdings Grid – Data Provider Service

### Core Grid (Sprint 2)
- **[PRD 5-03](./PRD-5-03-core-table-pagination.md)**: Holdings Grid – Core Table, Pagination & Per-Page Selector
- **[PRD 5-04](./PRD-5-04-filters-tabs-integration.md)**: Holdings Grid – Account Filter & Asset Class Tabs Integration
- **[PRD 5-05](./PRD-5-05-search-sort-enrichment.md)**: Holdings Grid – Columnar Search, Sort & Enrichment Freshness Column

### Advanced Features (Sprint 3)
- **[PRD 5-06](./PRD-5-06-multi-account-expansion.md)**: Holdings Grid – Multi-Account Row Expansion & Aggregation
- **[PRD 5-07](./PRD-5-07-security-detail-page.md)**: Security Detail Page

### Snapshots Backend (Sprint 4)
- **[PRD 5-08](./PRD-5-08-holdings-snapshots-model.md)**: Holdings Snapshots – Model & JSON Storage
- **[PRD 5-09](./PRD-5-09-snapshot-creation-service.md)**: Holdings Snapshots – Creation Service & Scheduled Job
- **[PRD 5-10](./PRD-5-10-snapshot-comparison-service.md)**: Holdings Snapshots – Comparison & Performance Calculation Service

### Snapshots UI (Sprint 5)
- **[PRD 5-11](./PRD-5-11-snapshot-selector-ui.md)**: Holdings Grid – Snapshot Selector & Historical View Mode
- **[PRD 5-12](./PRD-5-12-comparison-mode-ui.md)**: Holdings Grid – Comparison Mode UI & Visual Diffs
- **[PRD 5-13](./PRD-5-13-snapshot-management-ui.md)**: Holdings Snapshots – Management UI

### Polish (Sprint 6)
- **[PRD 5-14](./PRD-5-14-holdings-export-csv.md)**: Holdings Grid – Export & Reporting
- **[PRD 5-15](./PRD-5-15-mobile-responsive.md)**: Holdings Grid – Mobile Responsive View

### Future (Deferred)
- **PRD 5-16**: Multi-Account Weighted Average Cost Basis (high value, moderate complexity)
- **PRD 5-17**: Snapshot Retention Policy & Storage Monitoring
- **PRD 5-18**: Market Holiday Calendar for Business Day Calculations

## Implementation Notes

### RLS Setup
Add to ApplicationController:
```ruby
before_action :set_rls_context

def set_rls_context
  ActiveRecord::Base.connection.execute(
    "SET LOCAL app.current_user_id = #{current_user.id}"
  )
end
```

### Required Documentation
- `knowledge_base/data-dictionary.md` - jsonb schemas, enums
- `knowledge_base/data-sources.md` - FMP rate limits & tier
- `knowledge_base/architecture/rls-setup.md` - RLS policy configuration
- `knowledge_base/runbooks/snapshots-operations.md` - snapshot troubleshooting

### Performance Targets
- Data provider with 500 holdings < 500ms
- Snapshot comparison < 2s
- Grid render with "All" at 1000 holdings < 3s
- Totals query < 200ms

## Estimated Effort
6-8 sprints (12-16 weeks) for full epic with 1-2 developers.

## Related Documentation
- [Implementation Status](./0001-IMPLEMENTATION-STATUS.md)
- [Feedback V1](./Epic-5-Holding-Grid-feedback-V1.md)
- [Feedback V2](./Epic-5-Holding-Grid-feedback-V2.md)
- [Comments V1](./Epic-5-Holding-Grid-comments-V1.md)
- [Comments V2](./Epic-5-Holding-Grid-comments-V2.md)
