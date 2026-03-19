# Junie Task Log — PRD 0150: Enforce `security_id`-unique `SecurityEnrichment` (FMP-only) + Remove Finnhub
Date: 2026-01-21  \
Mode: Brave  \
Branch: <pending>  \
Owner: Junie

## 1. Goal
- Make `SecurityEnrichment` deterministic and unique per `security_id` (FMP-only), remove Finnhub support, and ensure all tests pass.

## 2. Context
- PRD: `knowledge_base/epics/nexgen/Epic-1/0150-PRD-1-10.md`
- Current system enriches equities via `HoldingsEnrichmentJob` after Plaid holdings sync.
- Data model requirement: **many `Holding` rows can share the same `security_id`**, but there must be **only one `SecurityEnrichment` per `security_id`**.
- Zero-downtime sequencing required: stop Finnhub creation → cleanup (delete Finnhub + dedupe) → add unique index → later drop `source` column.

## 3. Plan
1. Update model associations to security-level 1:1 (`Holding has_one :security_enrichment`; `SecurityEnrichment has_many :holdings`) and remove Finnhub-only model logic.
2. Refactor enrichment to FMP-only and upsert by `security_id` (no `source` in key); add `ActiveRecord::RecordNotUnique` handling.
3. Add cleanup rake task to delete Finnhub rows and dedupe remaining duplicates per `security_id`.
4. Add DB unique index on `security_enrichments.security_id` (ensure no conflicting composite unique index remains).
5. Remove Finnhub configuration/code references, update tests, and run the test suite until green.

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- 2026-01-21: Created task log and mapped current enrichment flow (`SyncHoldingsJob` → `PlaidHoldingsSyncService` → `HoldingsEnrichmentJob`).
- 2026-01-21: Updated models to enforce security-level 1:1 (`Holding has_one :security_enrichment`; `SecurityEnrichment has_many :holdings`) and removed Finnhub-only logic.
- 2026-01-21: Refactored `HoldingsEnrichmentJob` to be FMP-only and upsert by `security_id` (with `ActiveRecord::RecordNotUnique` handling).
- 2026-01-21: Added cleanup rake task `security_enrichments:cleanup_finnhub_and_dedupe` and added migration to enforce unique index on `security_enrichments.security_id`.
- 2026-01-21: Removed Finnhub service + config references and updated/added tests; verified tests green.

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `knowledge_base/prds/prds-junie-log/2026-01-21__0150-security-enrichment-security-id-unique-remove-finnhub.md` — task log (this file)
- `app/models/security_enrichment.rb` — FMP-only sources, `security_id` uniqueness validation, association inverse fix, removed Finnhub-only accessors
- `app/models/holding.rb` — `has_one :security_enrichment` via `security_id`; removed Finnhub fallback logic; simplified latest enrichment helpers
- `app/jobs/holdings_enrichment_job.rb` — upsert by `security_id` only; FMP-only; `RecordNotUnique` handling
- `db/migrate/20260121072200_make_security_enrichments_security_id_unique.rb` — replace composite unique index with unique index on `security_id`
- `lib/tasks/security_enrichments.rake` — cleanup task (delete Finnhub rows + dedupe)
- `test/test_helper.rb` — removed `FINNHUB_API_KEY` filter
- `test/jobs/holdings_enrichment_job_test.rb` — updated for `security_id`-unique enrichment; removed Finnhub wording
- `test/models/holding_test.rb` — added test for two holdings sharing one enrichment
- `test/models/security_enrichment_test.rb` — added `security_id` uniqueness test; updated source inclusion
- `test/tasks/security_enrichments_rake_test.rb` — added cleanup task test
- `app/services/finnhub_enricher_service.rb` — deleted

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.  \
Use placeholders for any sensitive arguments.

- `bin/rails db:migrate RAILS_ENV=test` — ✅ applied pending migration
- `bundle exec rails test test/models/security_enrichment_test.rb test/models/holding_test.rb test/jobs/holdings_enrichment_job_test.rb test/tasks/security_enrichments_rake_test.rb` — ✅ pass

## 7. Tests
Record tests that were run and results.

- `bundle exec rails test test/models/security_enrichment_test.rb test/models/holding_test.rb test/jobs/holdings_enrichment_job_test.rb test/tasks/security_enrichments_rake_test.rb` — ✅ pass

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Decision: Enforce uniqueness at the DB level with a unique index on `security_enrichments.security_id`.
  - Rationale: Model-level uniqueness validations are not sufficient under concurrency; the DB constraint guarantees correctness.
- Decision: Keep `source` column (if present) for now, but stop using it for upsert keys.
  - Rationale: Supports a safer rollout with a cleanup phase; column removal can be a separate migration later.

## 9. Risks / Tradeoffs
- Adding a unique index will fail if duplicates exist; must run cleanup first in production.
- Some Finnhub-derived fields may become `nil`; callers/views must tolerate missing data.

## 10. Follow-ups
Use checkboxes.

- [ ] Confirm whether any production dashboards/alerts depend on Finnhub-specific fields.
- [ ] Plan separate PRD/migration to drop `security_enrichments.source` column after stability window.

## 11. Outcome
- `SecurityEnrichment` is now enforced as one row per `security_id` (app-level validation + DB unique index migration).
- `Holding` deterministically resolves enrichment via `security_id`.
- Finnhub service/config references removed; enrichment job is FMP-only.
- Cleanup task exists to delete Finnhub rows and dedupe any remaining duplicates.
- Targeted tests are green.

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- Pending

---

## Quality Bar (Acceptance Criteria)
- `Holding.first.security_enrichment` resolves deterministically via `security_id` and returns a single record (or `nil`).
- `SecurityEnrichment.first.holdings.count` reflects all holdings with matching `security_id`.
- Two holdings with the same `security_id` resolve the same single `security_enrichment`.
- `SecurityEnrichment` is unique per `security_id` at the DB level (unique index).
- No Finnhub code paths remain; Finnhub config is not referenced.
- Tests are green.
