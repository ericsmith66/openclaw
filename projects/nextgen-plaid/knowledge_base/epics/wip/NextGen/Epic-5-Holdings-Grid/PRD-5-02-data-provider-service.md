# PRD 5-02: Holdings Grid – Data Provider Service

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Create a dedicated service class (HoldingsGridDataProvider) that centralizes all data querying, filtering, search, sort, aggregation, multi-account grouping, snapshot loading, enrichment joins, and full-dataset summary calculations. This keeps controllers thin, promotes testability, and ensures totals always reflect the full filtered result set.

## Requirements

### Functional
- **Accepts params hash**:
  - account_filter_id (or criteria)
  - asset_class
  - snapshot_id (or :live)
  - search_term
  - sort_column/dir
  - page
  - per_page (25/50/100/500/all)
- **Filters to investment accounts only** (plaid_account_type in investment categories)
- **Supports saved account filters** via JSON criteria (institution_ids, ownership_types, asset_strategy, trust_code, etc.)
- **Loads from HoldingsSnapshot JSON** when snapshot_id present (else live Holdings)
- **Joins security_enrichments** for enriched_at and other data (left join to handle missing enrichment)
- **Aggregates multi-account holdings**:
  - Group by `security_id` (fallback to ticker_symbol + name hash if security_id missing)
  - Sum qty/value/unrealized G/L $
  - Phase 1: sum cost basis only (no weighted average)
  - Return aggregated parent + children array for expandable rows
- **Computes full-dataset totals**: portfolio_value, total_gl_dollars, total_gl_pct, period_return_pct (if comparison), etc.
- **Returns**: paginated holdings relation/array + summary hash + total_count

### Non-Functional
- **Caching strategy**:
  - Key: `"holdings_totals:v1:user:#{user_id}:filters:#{Digest::SHA256.hexdigest(sorted_filter_json)}:snapshot:#{snapshot_id || 'live'}"`
  - sorted_filter_json = JSON.dump(params.slice(:account_filter_id, :asset_class, :search_term, :sort).sort.to_h)
  - TTL: 1 hour (not 4h)
  - Invalidate on holdings update via after_commit hook
- **Server-side only**: efficient indexes assumed
- **Required indexes** (add if missing):
  - `holdings(user_id, security_id, account_id)`
  - `holdings(security_id, market_value)`
  - `security_enrichments(security_id, enriched_at)`
- **Handles "All" per_page** by disabling pagination
- **RLS enforced** automatically via Postgres policies
- **Graceful handling** of empty results, no snapshots, missing enrichment

## Architectural Context
Plain Ruby service class in `app/services/holdings_grid_data_provider.rb`. Uses `Holdings.joins(:account, :security_enrichment).where(...)`. For snapshots: parses JSON and applies same filters in Ruby or PG jsonb queries. Integrates with SavedAccountFilters model. Prepares for future Ransack or manual SQL for search/sort.

## Cache Invalidation Hook

Add to Holdings model:
```ruby
after_commit :invalidate_portfolio_cache, on: [:create, :update, :destroy]

def invalidate_portfolio_cache
  Rails.cache.delete_matched("holdings_totals:v1:user:#{user_id}:*")
end
```

## Snapshot JSON Structure

Snapshots store core holding fields only (no embedded enrichment):
```json
{
  "holdings": [
    {
      "security_id": "abc123",
      "ticker_symbol": "AAPL",
      "name": "Apple Inc.",
      "quantity": 100,
      "market_value": 15000.00,
      "cost_basis": 12000.00,
      "unrealized_gain_loss": 3000.00,
      "asset_class": "equity",
      "account_id": 123,
      "account_name": "Brokerage",
      "account_mask": "1234"
    }
  ],
  "totals": {
    "portfolio_value": 250000.00,
    "total_gl_dollars": 45000.00,
    "total_gl_pct": 21.95
  }
}
```

When viewing snapshot, join to current `security_enrichments` table for freshness (enrichment freshness is current, not frozen).

## Acceptance Criteria
- Totals always match full filtered set (verified via count & SUM queries)
- Snapshot mode returns historical data matching stored JSON
- Multi-account securities return aggregated parent + expandable children array
- Per-page "All" returns all records without pagination
- Cache hit/miss behaves correctly; totals update after holdings change
- Filters to investment accounts only
- Missing enrichment handled gracefully (shows N/A)
- Performance: totals query < 200ms for 500 holdings

## Test Cases
- **Service**: mock params with various filters/snapshot_id; assert correct relation, totals, pagination
- **Cache**: verify fetch vs compute on repeated calls; verify invalidation on holdings update
- **Edge cases**:
  - Empty portfolio (zero holdings)
  - No enrichment for security (left join returns nil)
  - Multi-account with differing cost bases (phase 1 sums only)
  - "All" per_page returns unpaginated results
  - Security with missing security_id (fallback grouping)
- **Performance**: benchmark totals query <200ms for 500 holdings

## Manual Testing Steps
1. Create holdings for user with multiple accounts
2. Call data provider with no filters → verify all holdings + correct totals
3. Apply account filter → verify filtered holdings + updated totals
4. Apply asset class filter → verify subset returned
5. Change per_page to "All" → verify all records returned
6. Create snapshot → call data provider with snapshot_id → verify historical data
7. Update a holding → verify cache invalidated (totals reflect change on next call)
8. Search for ticker "AAPL" → verify filtered results
9. Sort by value descending → verify order
10. Check multi-account security → verify aggregated parent + children array

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-02-data-provider-service`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-01 (SavedAccountFilter model)

## Blocked By
- PRD 5-01 must be complete

## Blocks
- PRD 5-03 (Core Table needs data provider)
- PRD 5-04 (Filters integration needs data provider)
- PRD 5-05 (Search/sort needs data provider)
- PRD 5-06 (Multi-account expansion needs data provider)
- PRD 5-07 (Security detail needs data provider logic)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-01: Saved Account Filters](./PRD-5-01-saved-account-filters.md)
