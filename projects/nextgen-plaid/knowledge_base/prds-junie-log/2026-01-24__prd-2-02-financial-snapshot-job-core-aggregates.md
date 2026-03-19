# Junie Task Log — PRD-2-02 FinancialSnapshotJob (Core Aggregates)
Date: 2026-01-24  
Mode: Brave  
Branch: feature/epic-2-financial-snapshots  
Owner: Junie

## 1. Goal
- Implement the daily `FinancialSnapshotJob` that computes core net worth aggregates via `Reporting::DataProvider` and persists a per-user daily `FinancialSnapshot` record.

## 2. Context
- Epic 2 requires daily JSON snapshots to power Epic 3 dashboards.
- PRD reference: `knowledge_base/epics/wip/NextGen/Epic-2/0020-PRD-2-02.md`
- Dependencies: PRD-2-01 (`FinancialSnapshot` model/table), PRD-2-01b (`Reporting::DataProvider`).
- Scheduling uses Solid Queue recurring config: `config/recurring.yml`.

## 3. Plan
1. Update `FinancialSnapshotJob` to generate daily per-user `FinancialSnapshot` rows.
2. Ensure the snapshot JSON includes `total_net_worth`, `delta_day`, `delta_30d`, `as_of`, and `disclaimer`.
3. Add idempotency, empty-data and stale-data status logic, and robust error handling.
4. Update the recurring schedule to run daily at midnight.
5. Add Minitest coverage.
6. Run targeted tests and update Epic implementation tracker.

## 4. Work Log (Chronological)
- Implemented `FinancialSnapshotJob` to persist daily per-user snapshots using `Reporting::DataProvider` core aggregates.
- Updated `Reporting::DataProvider` to read net worth from both flat and nested snapshot JSON for backward/forward compatibility.
- Added Solid Queue recurring entry to run `FinancialSnapshotJob` daily.
- Added Minitest coverage for job behavior (core creation, deltas, stale/empty, idempotency, error snapshot).

## 5. Files Changed
- `app/jobs/financial_snapshot_job.rb` — Implement daily `FinancialSnapshot` persistence with statuses and error handling.
- `app/services/reporting/data_provider.rb` — Allow reading net worth from both flat and nested snapshot JSON.
- `config/recurring.yml` — Add daily recurring schedule for `FinancialSnapshotJob`.
- `test/jobs/financial_snapshot_job_test.rb` — Add job test coverage.

## 6. Commands Run
- `RAILS_ENV=test bin/rails test test/jobs/financial_snapshot_job_test.rb test/services/reporting/data_provider_test.rb` — ✅ completed

## 7. Tests
- `RAILS_ENV=test bin/rails test test/jobs/financial_snapshot_job_test.rb test/services/reporting/data_provider_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Store PRD-2-02 output in a flat JSON shape (`data['total_net_worth']`, etc.).
  - Rationale: PRD-2-02 explicitly specifies flat keys and example tests reference this format.
- Decision: Make `Reporting::DataProvider` tolerant of both flat and nested snapshot formats.
  - Rationale: Preserve compatibility with existing `build_snapshot_hash` structure while allowing PRD-2-02 storage format.

## 9. Risks / Tradeoffs
- Recurring schedule uses `at 12am every day`; actual timezone depends on server/runtime configuration.
  - Mitigation: `APP_TIMEZONE` is used for snapshot date boundaries; runtime schedule can be adjusted if server timezone differs.

## 10. Follow-ups
- [ ] Confirm production timezone / Solid Queue recurring scheduler timezone behavior matches “midnight CST” intent.
- [ ] Consider extracting the previous non-financial “project snapshot” job (if still needed) into a separate class.

## 11. Outcome
- `FinancialSnapshotJob` now generates daily per-user financial snapshots with core aggregates and status handling.

## 12. Commit(s)
- `Implement PRD-2-02 financial snapshot job` — `7a3354d`

## 13. Manual steps to verify and what user should see
1. Ensure the test database has schema loaded/migrated.
2. Run: `RAILS_ENV=test bin/rails test test/jobs/financial_snapshot_job_test.rb`
3. In Rails console (development), create a user with synced Plaid data (accounts/holdings).
4. Run: `FinancialSnapshotJob.perform_now(user)`
5. Expected: A `FinancialSnapshot` row exists for today (CST day) with `status` of `complete` (or `stale`/`empty`) and `data` containing `total_net_worth`, `delta_day`, `delta_30d`, `as_of`, and `disclaimer`.
