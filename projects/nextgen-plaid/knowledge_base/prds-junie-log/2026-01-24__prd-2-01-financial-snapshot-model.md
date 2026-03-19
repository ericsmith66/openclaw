# Junie Task Log — PRD-2-01 FinancialSnapshot Model & Migration
Date: 2026-01-24  
Mode: Brave  
Branch: feature/epic-2-financial-snapshots  
Owner: Junie

## 1. Goal
- Implement PRD-2-01 by adding the `FinancialSnapshot` storage model (table + indexes), adapter scaffold, and tests.

## 2. Context
- Epic 2 requires daily per-user JSON snapshots as the foundation for later aggregate computation and Epic 3 UI reads.
- Reference: `knowledge_base/epics/wip/NextGen/Epic-2/0010-PRD-2-01.md`

## 3. Plan
1. Add `APP_TIMEZONE` constant (CST) and wire `FinancialSnapshot` timestamp normalization.
2. Create `financial_snapshots` table with required indexes (including CST-day uniqueness).
3. Implement `FinancialSnapshot` model (enum, validations, scopes, rollback).
4. Add `Reporting::SnapshotAdapter` + minimal `Reporting::DataQualityValidator`.
5. Add Minitest coverage for acceptance criteria.

## 4. Work Log (Chronological)
- Implemented `APP_TIMEZONE` constant and `FinancialSnapshot` normalization to CST beginning-of-day.
- Added migration to create `financial_snapshots` and indexes (including functional unique index enforcing one snapshot per CST day).
- Implemented `FinancialSnapshot` model API (scopes, warnings, rollback, data quality delegation).
- Added `Reporting::SnapshotAdapter` and a minimal `Reporting::DataQualityValidator`.
- Added Minitest model tests for uniqueness, schema version validation, scopes, rollback, and normalization.

## 5. Files Changed
- `config/initializers/constants.rb` — added `APP_TIMEZONE`.
- `db/migrate/20260124134000_create_financial_snapshots.rb` — new table + indexes.
- `app/models/financial_snapshot.rb` — new model.
- `app/models/user.rb` — added `has_many :financial_snapshots` association.
- `app/services/reporting/snapshot_adapter.rb` — adapter scaffold.
- `app/services/reporting/data_quality_validator.rb` — minimal validator.
- `test/models/financial_snapshot_test.rb` — new model tests.
- `db/schema.rb` — added `financial_snapshots` table + indexes for schema-load based test setup.
- `knowledge_base/epics/wip/NextGen/Epic-2/0001-IMPLEMENTATION-STATUS.md` — marked PRD-2-01 implemented.

## 6. Commands Run
- Reset and prepare test DB:
  - `psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname IN ('nextgen_plaid_test','nextgen_plaid_test_queue','nextgen_plaid_test_cable') AND pid <> pg_backend_pid();"`
  - `psql -d postgres -c "DROP DATABASE IF EXISTS nextgen_plaid_test;"`
  - `psql -d postgres -c "DROP DATABASE IF EXISTS nextgen_plaid_test_queue;"`
  - `psql -d postgres -c "DROP DATABASE IF EXISTS nextgen_plaid_test_cable;"`
  - `RAILS_ENV=test bin/rails db:create`
  - `RAILS_ENV=test bin/rails db:schema:load`
- Run tests:
  - `RAILS_ENV=test bin/rails test test/models/financial_snapshot_test.rb`

## 7. Tests
- `RAILS_ENV=test bin/rails test test/models/financial_snapshot_test.rb`
  - Result: ✅ 10 runs, 17 assertions, 0 failures, 0 errors, 0 skips

## 8. Decisions & Rationale
- Decision: Use Minitest (existing repo standard) rather than adding RSpec for PRD examples.
  - Rationale: Keep test stack consistent and avoid introducing new dependencies.
- Decision: Implement a functional unique index for CST-day uniqueness.
  - Rationale: Guarantees correctness at DB level regardless of application timezones.

- Revision: Dropped the functional index approach and implemented uniqueness via `snapshot_at` normalization + standard unique index.
  - Rationale: Rails `schema.rb` does not dump custom SQL functions reliably, which breaks test DB schema loads. Normalizing `snapshot_at` to CST beginning-of-day ensures a standard unique index correctly enforces “one per CST day” for all application-created records.

## 9. Risks / Tradeoffs
- Functional unique index uses `AT TIME ZONE 'America/Chicago'` which assumes PostgreSQL and the timezone name exists.
- `Reporting::DataQualityValidator` is minimal here; richer scoring is expected in later PRDs.

## 10. Follow-ups
- [ ] Expand `Reporting::DataQualityValidator` scoring rules in PRD-2-02 if/when required.
- [ ] Confirm any global Rails timezone configuration decisions (keep in UTC vs set to Central).

## 11. Outcome
- `FinancialSnapshot` model + DB schema are in place with CST-day uniqueness, basic query helpers, and adapter scaffold.

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Run `bin/rails db:migrate`.
   - Expected: migration succeeds and `financial_snapshots` table exists with indexes.
2. In `bin/rails console`, create a user and create a snapshot:
   - `u = User.first || User.create!(email: "test@example.com", password: "password")`
   - `FinancialSnapshot.create!(user: u, snapshot_at: Date.current, data: {}, schema_version: 1)`
   - Expected: record persists; `status` defaults to `pending`; `snapshot_at` is normalized to CST beginning of day.
3. Attempt to create a second snapshot for the same CST day:
   - Expected: PostgreSQL uniqueness violation (`ActiveRecord::RecordNotUnique`).
4. Run `bin/rails test test/models/financial_snapshot_test.rb`.
   - Expected: all tests pass.
