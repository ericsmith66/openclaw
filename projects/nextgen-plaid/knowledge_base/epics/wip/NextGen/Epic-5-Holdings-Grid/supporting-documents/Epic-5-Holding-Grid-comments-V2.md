
Here is **Junie's Feedback V2 document**, with your previous answers carried forward where relevant, and my responses added as **grok_eas:** inline comments on **every single point** she raised (even when the answer is simply agreement, deferral, or a small clarification). I’ve answered or addressed all 23 questions and all suggestions/objections/improvements.

# Epic-5-Holding-Grid — Feedback V2

## Overview Assessment
Excellent integration of feedback. The epic is comprehensive, well-structured, and ready for implementation. All 15 PRDs have clear requirements, acceptance criteria, test cases, and workflows.

→ **grok_eas:** fully agree — thank you for the thorough review

## Questions

### PRD #1 (Data Provider Service)

1. **Snapshot JSON Structure**: Will snapshots include enrichment data inline, or will we join to `security_enrichments` table even in snapshot mode? This affects whether enrichment freshness is frozen at snapshot time or always shows current data.  
   **grok_eas:** For v1: snapshots **do not** embed enrichment data — they store core holding fields (ticker_symbol, quantity, market_value, cost_basis, unrealized_gl, asset_class, security_id, etc.). When viewing a snapshot, we **join** to the current `security_enrichments` table for freshness, sector, etc. This means **enrichment freshness is current**, not frozen. If we later want frozen enrichment, we can add it to snapshot JSON in v2.

2. **Multi-Account Grouping Key**: When aggregating multi-account holdings, are we grouping by `security_id` or `ticker_symbol`? Different securities can share tickers (e.g., CUSIP changes after merger), and same security might have missing ticker. Recommend grouping by `security_id`.  
   **grok_eas:** Agreed — group **by `security_id`** (not ticker_symbol). `security_id` is the stable Plaid identifier. If `security_id` is missing (rare), fall back to `ticker_symbol` + `name` hash for grouping, but log it as warning.

3. **Cache Key Strategy**: The 4h TTL cache mentions `filter_hash`. How is this hash computed? SHA256 of sorted params JSON? Need to ensure different filter combinations don't collide.  
   **grok_eas:** Cache key = `"holdings_totals:v1:user:#{user.id}:filters:#{Digest::SHA256.hexdigest(sorted_filter_json)}:snapshot:#{snapshot_id || 'live'}"`  
   sorted_filter_json = JSON.dump(params.slice(:account_filter_id, :asset_class, :search_term, :sort).sort.to_h)  
   → collision-safe, versioned, explicit.

### PRD #2 (Saved Account Filters)

4. **Filter Criteria Schema**: The jsonb `criteria` field is flexible but undefined. Should we document the expected schema? Example: {...}  
   **grok_eas:** Yes — document in `knowledge_base/data-dictionary.md` and add comment in model:
   ```json
   {
     "account_ids": [integer],
     "institution_ids": [integer],
     "ownership_types": ["Individual", "Trust", "Other"],
     "asset_strategy": string,
     "trust_code": string,
     "holder_category": string
   }
   ```  
   We’ll validate presence of at least one key in create/update.

5. **Cross-App Filter Application**: When used in net worth or transactions views, will the same SavedAccountFilter model work, or do those features need different filter fields? Should we make this extensible?  
   **grok_eas:** Same model, same criteria jsonb. Make extensible: add optional `context` string (e.g. "holdings", "transactions", "net_worth") to filter future usage. For v1 we apply universally — later add context-specific validation.

### PRD #3 (Core Table)

6. **Toast Warning Mechanism**: For the >400 rows warning, should this be dismissible? Should it remember dismissal per session? Consider user annoyance if they regularly work with large portfolios.  
   **grok_eas:** Yes — make it dismissible. Store dismissal in session (session[:dismissed_large_grid_warning] = true). Persist for current session only (not permanent). Re-show if user chooses "All" again after filter change.

### PRD #4 (Filters & Tabs)

7. **Asset Class Mapping**: What are the exact Plaid `asset_class` values we're mapping to the 3 tabs? Need to ensure comprehensive coverage (crypto, options, alternatives, cash equivalents).  
   **grok_eas:** Tabs map as follows (based on Plaid + FMP enrichment):
    - Stocks & ETFs → equity, etf
    - Mutual Funds → mutual_fund
    - Bonds, CDs & MMFs → bond, fixed_income, cd, money_market
    - All Positions → catch-all (including crypto, alternative, option, other)
      Future tab for "Alternatives & Other" if demand grows.

### PRD #5 (Search & Sort)

8. **Business Day Calculation**: For enrichment freshness, how do we handle market holidays (not just weekends)? Should we integrate a market calendar or use a simple heuristic (5 business days = 7 calendar days)?  
   **grok_eas:** For v1: simple heuristic — >1 calendar day = yellow, >3 calendar days = red.  
   Defer real business-day logic (with holiday calendar) to future PRD — can use `holidays` gem or static US NYSE calendar later.

9. **Search Performance**: Global search with ILIKE on multiple columns can be slow. Have we considered full-text search (tsvector/tsquery) or Postgres trigram indexes (pg_trgm)?  
   **grok_eas:** Yes — good call. For v1 we’ll use ILIKE (with indexes on symbol, name).  
   If slow in testing, add `pg_trgm` extension + trigram indexes on searchable columns as quick win before full tsvector.

### PRD #6 (Multi-Account Expansion)

10. **Expand State Persistence**: How do we preserve expand/collapse state across pagination/filter changes? Storing in session? URL params? Stimulus controller with localStorage?  
    **grok_eas:** Simplest for v1: **no persistence** — expand/collapse resets on page/filter/sort change.  
    If users complain, v2: Stimulus controller + localStorage keyed by user + filter hash.

### PRD #7 (Security Detail Page)

11. **Transaction Grand Totals Logic**: What exactly goes into "total invested" vs "proceeds" vs "net cash flow"? Need clear definitions...  
    **grok_eas:** Definitions:
- Total Invested = sum(amount) where type == "buy" or "contribution" (positive cash out)
- Proceeds = sum(amount) where type == "sell" or "distribution" (positive cash in)
- Net Cash Flow = proceeds - invested
- Dividends = sum(amount) where type/subtype includes "dividend"
  All signed appropriately (buys negative, sells positive).

12. **Security Not Found**: What happens if someone navigates to `/portfolio/securities/99999`? 404? Redirect with message?  
    **grok_eas:** 404 with friendly message: “Security not found or no longer accessible.”

### PRD #8 (Snapshots Model)

13. **Snapshot Naming**: The `name` field is optional. When auto-generated by scheduled job, what's the naming convention? "Daily Snapshot 2026-02-04"? Or just rely on created_at?  
    **grok_eas:** Auto-generated name = "Daily #{created_at.to_date}" (e.g. "Daily 2026-02-04").  
    Manual snapshots default to "Manual Snapshot [time]".

14. **Account-Level vs User-Level**: Can a single snapshot be mixed-scope (some accounts but not all)? Or is it binary...  
    **grok_eas:** Binary for v1: either user-level (account_id nil = all investment accounts) or single-account (account_id present). Mixed partial snapshots deferred.

### PRD #9 (Snapshot Creation)

15. **Idempotency Check**: The "<24h skip unless forced" logic — is this per user or per user+account combination? ...  
    **grok_eas:** Per scope:
- User-level snapshot: skip if <24h exists for user_id where account_id is null
- Account-level: skip if <24h exists for user_id + account_id  
  Forced flag bypasses check.

16. **Solid Queue Failure Handling**: If snapshot creation fails (Plaid down, DB issue), what's the retry strategy? Exponential backoff? Alert admin?  
    **grok_eas:** ActiveJob/Solid Queue exponential backoff (up to 3 attempts).  
    On final failure: log error + enqueue admin notification job (email or Slack webhook).

### PRD #10 (Snapshot Comparison)

17. **Security Matching Logic**: When comparing snapshots, do we match by `security_id`, `ticker_symbol`, or both? ...  
    **grok_eas:** Primary: `security_id`.  
    Fallback: `ticker_symbol` + `name` if security_id missing in one snapshot.  
    Log mismatch for investigation.

18. **Return Calculation Edge Cases**: How do we handle: division by zero, negative cost basis, positions that moved accounts...?  
    **grok_eas:**
- Start value = 0 → return_pct = "N/A" (or infinite symbol if UI supports)
- Negative cost basis → show as-is (with disclaimer)
- Moved accounts → treated as removed from old + added to new (normal behavior)

### PRD #11 (Snapshot Selector)

19. **Snapshot List Size**: If a user has 1000+ snapshots (multi-year daily), the dropdown will be unwieldy...  
    **grok_eas:** For v1: show last 50 snapshots + “View all snapshots” link to management page.  
    Later: add date range picker or search.

### PRD #12 (Comparison Mode)

20. **Comparison Performance**: For 500 holdings compared, will this be computed on every page load or cached? ...  
    **grok_eas:** Computed on-demand per request for v1.  
    Cache result for 30 min (keyed by start_id + end_id + filter_hash) if perf issue appears in testing.

### PRD #14 (Export)

21. **Large Export Handling**: For portfolios with 1000+ holdings, CSV generation could timeout...  
    **grok_eas:** Yes — if total_count > 500 → async via ExportHoldingsJob → email signed ActiveStorage link.

22. **Export Comparison Data**: When in comparison mode, does the CSV export include the delta columns? Or just the current view?  
    **grok_eas:** Include delta columns when comparison active. Otherwise standard columns.

### PRD #15 (Mobile)

23. **Mobile Feature Parity**: Should mobile support all features... or subset for v1?  
    **grok_eas:** Full feature parity for v1 — but prioritize scrollable table + stacked cards.  
    Complex interactions (expand, dropdowns) remain functional, but may be less elegant on small screens.

## Suggestions / Objections / Improvements

All suggestions, objections, and proposed solutions have been reviewed:

→ **grok_eas:** Most are excellent and should be incorporated:
- Materialized view for totals → consider after v1 perf data
- Background job observability → yes, add structured logging to Solid Queue
- Security enrichment backfill → on-demand at sync + nightly batch
- Indexes → explicitly list in acceptance criteria of each PRD
- Keyboard nav, loading states, tooltips, breadcrumbs → nice-to-have, defer
- Empty state variations → mandatory
- Performance benchmarks in CI → yes
- RLS coverage → yes, add integration tests
- Data dictionary & runbooks → yes, in knowledge_base
- RLS middleware → yes, add before_action in ApplicationController
- Snapshot JSON queryability → accept Ruby parsing for v1
- Cache invalidation timing → use after_commit + manual refresh button
- Multi-account G/L % → hide % on aggregated rows, show per-account only
- Snapshot monitoring → add size metrics + alert threshold
- Async export → yes, already planned

**Final go/no-go readiness**: High confidence to start with PRD #2 → #1 → #3.

**Next step**  
Which PRD should Junie start implementing first?  
I recommend **PRD #2 (Saved Account Filters)** — it’s standalone, low risk, and immediately usable in other views — then **PRD #1 (Data Provider)** as the foundation.

Let me know your preference.