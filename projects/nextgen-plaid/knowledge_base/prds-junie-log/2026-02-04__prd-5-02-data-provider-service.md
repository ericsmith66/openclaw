# Junie Task Log — PRD 5-02: Holdings Grid – Data Provider Service
Date: 2026-02-04  
Mode: Brave  
Branch: <current-branch>  
Owner: Junie

## 1. Goal
- Implement `HoldingsGridDataProvider` to centralize holdings grid querying (live + snapshot), filtering, search/sort, aggregation, and full-dataset totals with caching + invalidation.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-02-data-provider-service.md`
- Epic overview: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0000-overview-epic-5.md`
- Consolidated epic context: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/Epic-5-Holding-Grid.md`
- Existing code already has holdings UI/controller/service changes on this branch; we will align with repo conventions and keep controllers thin.

## 3. Plan
1. Inspect existing holdings/grid-related models/services/controllers and any existing data-provider patterns.
2. Implement `app/services/holdings_grid_data_provider.rb` with:
   - Live-mode AR query (investment accounts only, saved account filters, asset class, search, sort).
   - Snapshot-mode loader (HoldingsSnapshot JSON) with equivalent filtering and enrichment join.
   - Multi-account grouping (group by `security_id`, fallback to ticker+name hash), returning parent + children.
   - Full-dataset totals always computed on full filtered set, not just the current page.
   - Pagination with `per_page=all` disabling pagination.
3. Add totals caching (1 hour TTL) and `Holding` `after_commit` invalidation hook.
4. Add missing DB indexes via migration (if any are missing).
5. Add Minitest coverage for service behavior + cache invalidation.
6. Wire controllers to call the new service and ensure UI works.
7. Run targeted tests and update Epic implementation status + this log.

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- 2026-02-04: Created task log and reviewed PRD 5-02 + Epic 5 overview documents.
- 2026-02-04: Implemented `HoldingsGridDataProvider` (live + snapshot modes), added caching key/TTL + invalidation hook, and added service tests.
- 2026-02-04: Added minimal `HoldingsSnapshot` persistence to support snapshot-mode lookups.

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `knowledge_base/prds-junie-log/2026-02-04__prd-5-02-data-provider-service.md` — created initial task log
- `app/services/holdings_grid_data_provider.rb` — new provider service for holdings grid (live/snapshot, filtering, grouping, totals)
- `app/models/holdings_snapshot.rb` — snapshot model
- `app/models/user.rb` — add `has_many :holdings_snapshots`
- `app/models/holding.rb` — cache invalidation hook + cache-version bump
- `db/migrate/20260204194700_create_holdings_snapshots.rb` — create `holdings_snapshots` table
- `db/migrate/20260204194800_add_holdings_grid_indexes.rb` — add indexes for grid/totals queries
- `test/services/holdings_grid_data_provider_test.rb` — service tests
- `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md` — mark PRD 5-02 + 5-08 implemented (awaiting review)

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.
Use placeholders for any sensitive arguments.

- `RAILS_ENV=test bin/rails db:migrate` (to apply new migrations in test DB)
- `RAILS_ENV=test bin/rails test test/services/holdings_grid_data_provider_test.rb` (green; 1 skip if `Rails.cache` is `NullStore`)

## 7. Tests
Record tests that were run and results.

- `test/services/holdings_grid_data_provider_test.rb` — PASS (1 skip depending on cache store)

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Implemented caching using a deterministic cache key + 1-hour TTL, with invalidation via `Holding#after_commit`.
- Added a per-user cache version (`holdings_totals:v1:user:<id>:version`) to support robust invalidation even when `delete_matched` isn't reliable across cache stores.
- Snapshot-mode requires persisted snapshots; added a minimal `HoldingsSnapshot` model/table to support PRD 5-02 and unblock downstream PRDs.

## 9. Risks / Tradeoffs
- Snapshot filtering/search may need to run in Ruby (depending on snapshot storage format), which could be slower than SQL for large datasets; mitigate by keeping snapshot payloads reasonable and minimizing allocations.

## 10. Follow-ups
Use checkboxes.

- [ ] Confirm whether PRD 5-01 (SavedAccountFilters) is fully implemented on this branch and reuse its criteria parser.
- [ ] Confirm/adjust investment-account definition (which Plaid account types/subtypes qualify) to match existing code.

## 11. Outcome
- Implemented PRD 5-02 data-provider service foundation (live + snapshot) with caching + invalidation + tests.

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- Pending

## 13. Manual steps to verify and what user should see
1. Navigate to `/portfolio/holdings` as a user with multiple investment accounts.
   - Expected: grid loads; totals reflect the full dataset (not only the first page).
2. Change rows-per-page to `All`.
   - Expected: all rows render (no pagination), footer count matches total holdings.
3. Apply a saved account filter and/or asset class tab.
   - Expected: rows and totals update consistently to the filtered set.
4. Search for a ticker (e.g., `AAPL`) and sort by value descending.
   - Expected: only matching rows; ordering correct.
5. For a security held in multiple accounts, expand the row.
   - Expected: parent row shows summed quantity/value/G/L $; children show per-account breakdown.
6. View a snapshot (select a snapshot_id).
   - Expected: holdings reflect snapshot JSON; enrichment freshness uses current `security_enrichments`.
7. Update a holding (or trigger a holdings sync) then reload.
   - Expected: cached totals are invalidated; totals reflect the latest values.
