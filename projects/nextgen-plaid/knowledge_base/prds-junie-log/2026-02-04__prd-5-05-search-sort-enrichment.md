# Junie Task Log — PRD 5-05: Holdings Grid – Columnar Search, Sort & Enrichment Freshness
Date: 2026-02-04  
Mode: Brave  
Branch: <current-branch>  
Owner: Junie

## 1. Goal
- Add server-side global search + full column sorting to `/portfolio/holdings`.
- Add the “Enrichment Updated” column formatting + freshness coloring.
- Preserve search/sort in URL and across pagination/filter changes.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-05-search-sort-enrichment.md`
- Depends on PRDs 5-02, 5-03, 5-04.

## 3. Plan
1. Add search UI (DaisyUI input) to the grid.
2. Extend `HoldingsGridDataProvider` search:
   - Live: `ticker_symbol`, `name`, enrichment `sector` (ILIKE).
   - Snapshot: search within snapshot rows, plus enrichment sector when present.
3. Extend `HoldingsGridDataProvider` sorting:
   - Add computed sorts: `price`, `unrealized_gl_pct`, `% of portfolio`.
   - Add null-safe sort on `security_enrichments.enriched_at`.
4. Add enrichment freshness badge classes (<1 day green, 1–3 amber, >3 red, nil gray).
5. Add DB indexes as needed (`security_enrichments.enriched_at` minimum).
6. Tests: service + capybara smoke.

## 4. Manual Testing Steps (what to do / expected)
1. Visit `GET /portfolio/holdings`.
2. Search for `AAPL` → only Apple rows remain.
3. Clear search → all rows return.
4. Click “Value” header → sorts asc; click again → desc; state preserved in URL.
5. Sort by “Enrichment Updated” → oldest/newest ordering; N/A values sort last.
6. Verify enrichment colors:
   - today → green
   - 2 days → amber
   - >3 days → red
   - missing → gray N/A
7. Paginate while search active → search preserved.
8. Combine with asset tab + saved account filter → intersection works.

## 5. Outcome
- PRD 5-05 implemented (awaiting review): global search + column sorting + enrichment freshness badge are live on `/portfolio/holdings`, with state preserved in URL and across pagination.

## 6. Files Changed
- `app/services/holdings_grid_data_provider.rb` — search across sector + enrichment sector; additional sort mappings; post-group sorting for computed % metrics
- `app/controllers/portfolio/holdings_controller.rb` — pass through `search_term` + preserve state
- `app/views/portfolio/holdings/index.html.erb` — pass `search_term`/`snapshot_id` into component
- `app/components/portfolio/holdings_grid_component.rb` — search/sort helpers, sort indicators, enrichment freshness badge helpers
- `app/components/portfolio/holdings_grid_component.html.erb` — search form, sortable headers, enrichment badges, added GL% column
- `db/migrate/20260204195500_add_security_enrichments_enriched_at_index.rb` — add index on `security_enrichments.enriched_at`
- `test/services/holdings_grid_data_provider_test.rb` — sector search coverage
- `test/smoke/portfolio_holdings_grid_capybara_test.rb` — search, sort toggle, and enrichment badge smoke coverage
- `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md` — mark PRD 5-05 implemented

## 7. Commands Run
- `RAILS_ENV=test bin/rails db:migrate`
- `RAILS_ENV=test bin/rails test test/services/holdings_grid_data_provider_test.rb test/controllers/portfolio/holdings_controller_test.rb test/smoke/portfolio_holdings_grid_capybara_test.rb`
