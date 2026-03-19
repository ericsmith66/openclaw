# PRD 5-05: Holdings Grid – Columnar Search, Sort & Enrichment Freshness Column

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Implement server-side global + columnar search, sortable columns, and the "Enrichment Updated" column with conditional coloring based on data freshness thresholds.

## Requirements

### Functional
- **Global search** across symbol, name/description, sector (ILIKE for v1)
- **Per-column sort** (click headers to toggle asc/desc):
  - Symbol, Description, Asset Class
  - Price, Quantity, Value, Cost Basis
  - Unrealized G/L ($), Unrealized G/L (%)
  - Enrichment Updated, % of Portfolio
- **Enrichment Updated column**:
  - Display: formatted datetime from security_enrichments.enriched_at
  - Color coding:
    - Green: < 1 calendar day old
    - Yellow/Amber: 1-3 calendar days old
    - Red: > 3 calendar days old
    - Gray/N/A: no enrichment data
- Search/sort apply to full dataset (with pagination maintained)
- Preserve search/sort state across pagination, filter changes
- Visual indicators: sort arrows in headers, search icon/badge

### Non-Functional
- **Performance**:
  - Use database indexes on searchable columns (symbol, name)
  - For v1: ILIKE with column indexes
  - If slow in testing: add pg_trgm extension + trigram indexes
- Efficient joins (no N+1 queries)
- Left join security_enrichments to handle missing data gracefully
- Business day calculation: v1 uses simple calendar days; defer holiday-aware logic to future

## Architectural Context
Extend HoldingsGridDataProvider service with search (ILIKE or full-text) and sort params. Use manual SQL or light Ransack-lite for flexibility. ViewComponent for sortable header cells with chevron icons. DaisyUI styling for search input and sort indicators.

## Database Indexes Required

```ruby
# Add these indexes if missing
add_index :holdings, [:ticker_symbol], using: :gin, opclass: :gin_trgm_ops # if using pg_trgm
add_index :holdings, [:name], using: :gin, opclass: :gin_trgm_ops # if using pg_trgm
add_index :security_enrichments, [:enriched_at]
add_index :security_enrichments, [:security_id, :enriched_at]
```

## Enrichment Freshness Logic

```ruby
# In view helper or ViewComponent
def enrichment_freshness_class(enriched_at)
  return 'text-gray-400' unless enriched_at

  age_days = (Time.current - enriched_at).to_i / 1.day
  case age_days
  when 0 then 'text-green-600 bg-green-50'
  when 1..3 then 'text-amber-600 bg-amber-50'
  else 'text-red-600 bg-red-50'
  end
end
```

## Acceptance Criteria
- Search term filters rows correctly (case-insensitive)
- Clicking column header toggles sort direction (asc/desc)
- Sort indicator (chevron/arrow) shows current direction
- Enrichment column displays correct datetime and color badge
- Sort/search work in snapshot mode and with multi-account aggregation
- Performance remains acceptable (<500ms for search/sort on 500 holdings)
- Search/sort state preserved in URL params
- Empty search results show appropriate message

## Test Cases
- **Service**:
  - Mock search/sort params → assert correct SQL/query generated
  - Verify search matches symbol, name, sector
  - Verify sort applies to correct column
- **View**:
  - Headers show sort icons (up/down chevrons)
  - Enrichment cells have correct color classes
  - Search input renders with proper styling
- **Capybara**:
  - Enter search term → verify filtered results
  - Click sort header → verify ordered rows
  - Click again → verify reverse order
  - Search + sort + filter → verify all compose correctly
- **Edge**:
  - No enrichment data (N/A + gray color)
  - Business day calculation across weekends
  - Special characters in search term
  - Sort by null values (enrichment missing)

## Manual Testing Steps
1. Load holdings grid with 50+ holdings
2. Enter search "AAPL" → verify only Apple holdings shown
3. Clear search → verify all holdings return
4. Click "Value" header → verify sorted by value ascending
5. Click again → verify sorted descending
6. Sort by "Enrichment Updated" → verify oldest/newest ordering
7. Verify enrichment colors:
   - Fresh data (today) → green badge
   - 2 days old → yellow badge
   - Week old → red badge
   - No enrichment → gray/N/A
8. Combine search + sort + asset class filter → verify all work together
9. Paginate while search active → verify search maintained
10. Check URL params reflect search/sort state

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-05-search-sort-enrichment`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-02 (Data provider service)
- PRD 5-03 (Core table structure)
- PRD 5-04 (Filters integration)

## Blocked By
- PRD 5-04 must be complete

## Blocks
- PRD 5-06 (Multi-account expansion will use same sort logic)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-02: Data Provider Service](./PRD-5-02-data-provider-service.md)
- [PRD 5-03: Core Table Pagination](./PRD-5-03-core-table-pagination.md)
