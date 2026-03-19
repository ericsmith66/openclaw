# Junie Task Log — PRD-0170 SecurityEnrichment First-Class Columns
Date: 2026-01-21  
Mode: Brave  
Branch: feature/prd-0170-security-enrichment-columns  
Owner: ericsmith66

## 1. Goal
- Add first-class DB columns + backfill + indexes for critical FMP fields on `security_enrichments`, update write-path and model helpers, and keep the `data` JSONB as the raw source of truth while ensuring all tests pass.

## 2. Context
- PRD: `knowledge_base/epics/nexgen/Epic-1/0170-PRD-01-10.md`
- Existing system stores enrichment payload in `security_enrichments.data` JSONB and exposes some keys via `store_accessor`.
- New requirement is to denormalize high-use keys into typed columns for performance/indexing and reduce JSONB `dig` churn.

## 3. Plan
1. Add Phase 1 migration to create 22 nullable columns on `security_enrichments` with specified types.
2. Add Phase 2 migration to backfill new columns from existing `data` JSONB (flattened keys first; fallback to `raw_response`).
3. Add Phase 3 migration to add indexes (single, compound, trigram) and ensure `pg_trgm` extension exists.
4. Update `SecurityEnrichment` model (remove overlapping `store_accessor`, keep typed helper aliases).
5. Update enrichment write-path (job/service) so new columns are populated on create/update.
6. Update/add tests and ensure full suite passes.

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- 2026-01-21: Read PRD-0170 and Junie log requirements; inspected current `SecurityEnrichment` model, `FmpEnricherService`, `HoldingsEnrichmentJob`, and existing migrations.
- 2026-01-21: Implemented 3-phase DB migrations:
  - Phase 1: added new typed columns to `security_enrichments`
  - Phase 2: backfilled columns from existing `data` JSONB (flattened keys first, then `raw_response` fallback)
  - Phase 3: enabled `pg_trgm` and added indexes (single, compound, trigram GIN)
- 2026-01-21: Updated `SecurityEnrichment` model to remove overlapping `store_accessor` and added typed helper alias methods.
- 2026-01-21: Updated `FmpEnricherService` to flatten additional profile/quote/ratio fields needed for column population.
- 2026-01-21: Updated `HoldingsEnrichmentJob` write-path to populate new columns from flattened enrichment data.
- 2026-01-21: Updated minitest coverage for model and job; ran full test suite successfully.

Manual verification steps (expected results):
1. Run migrations (dev): `bin/rails db:migrate`
   - Expect: migrations complete without errors; `security_enrichments` has new columns and indexes.
2. Trigger enrichment for a known equity holding:
   - Option A (job): `HoldingsEnrichmentJob.perform_now` (via rails console)
   - Option B (app flow): run whatever flow schedules the enrichment job.
   - Expect: a `SecurityEnrichment` row exists for the holding’s `security_id` with `status: "success"`.
3. Verify columns are populated (rails console):
   - `se = SecurityEnrichment.find_by!(security_id: <security_id>)`
   - Expect: `se.sector`, `se.industry`, `se.price`, `se.market_cap`, `se.company_name` are present when available from FMP.
   - Expect: `se.data["raw_response"]` remains present and contains the full FMP payload.
4. Verify helper aliases:
   - Expect: `se.price_d` returns a `BigDecimal` and matches `se.price`.
   - Expect: `se.market_cap_i` returns an `Integer` and matches `se.market_cap`.
5. Quick query sanity:
   - Expect: `SecurityEnrichment.where(sector: "Technology", status: "success").limit(10)` works (no JSONB `dig` needed).
   - Expect: `SecurityEnrichment.where("company_name ILIKE ?", "%Apple%").limit(10)` returns matches.

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `knowledge_base/prds-junie-log/2026-01-21__prd-0170-security-enrichment-columns.md` — created task log.
- `db/migrate/20260121131100_add_columns_to_security_enrichments.rb` — Phase 1: added new typed columns.
- `db/migrate/20260121131200_backfill_security_enrichment_columns.rb` — Phase 2: backfilled columns from `data`.
- `db/migrate/20260121131300_add_indexes_to_security_enrichments.rb` — Phase 3: enabled `pg_trgm` and added indexes.
- `app/models/security_enrichment.rb` — removed `store_accessor`; added typed helper aliases.
- `app/services/fmp_enricher_service.rb` — expanded extracted/flattened keys.
- `app/jobs/holdings_enrichment_job.rb` — populate new columns on upsert.
- `test/models/security_enrichment_test.rb` — added tests for helpers and indexes.
- `test/jobs/holdings_enrichment_job_test.rb` — added assertions for column population.

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.  
Use placeholders for any sensitive arguments.

- `bin/rails db:migrate RAILS_ENV=test` — ✅ applied pending migrations in test env.
- `bundle exec rails test` — ✅ pass.

## 7. Tests
Record tests that were run and results.

- `bundle exec rails test` — ✅ pass (573 runs, 0 failures, 0 errors).

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Decision: Use a 3-phase migration strategy (add nullable columns → backfill in batches → add indexes).
  - Rationale: supports zero-downtime deployment and avoids long locks.

## 9. Risks / Tradeoffs
- Backfill performance / lock risk on large tables.
- Trigram index requires `pg_trgm` extension; must be enabled safely.

## 10. Follow-ups
Use checkboxes.

- [ ] Confirm exact JSON paths for fields not currently extracted/flattened by `FmpEnricherService` (e.g., `company_name`, `website`, `description`, `image_url`, and metric fields not yet in extraction).
- [ ] Confirm whether `status` column is strictly required vs. existing `security_enrichments.status` already covers it.

## 11. Outcome
- `security_enrichments` now has first-class typed columns for critical FMP fields, is backfilled for existing rows, and has supporting indexes (including trigram search on `company_name`).
- Enrichment write-path now populates both JSONB `data` and the denormalized columns.
- All tests are passing.

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- Pending
