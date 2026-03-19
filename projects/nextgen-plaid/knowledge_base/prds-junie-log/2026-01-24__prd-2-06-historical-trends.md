# Junie Task Log — PRD-2-06 Historical Trends
Date: 2026-01-24  
Mode: Brave  
Branch: feature/epic-2-financial-snapshots  
Owner: Junie

## 1. Goal
- Add a compact 30-day historical net worth series to the daily `FinancialSnapshot` JSON so Epic 3 can render basic trend/performance visuals.

## 2. Context
- PRD reference: `knowledge_base/epics/wip/NextGen/Epic-2/0060-PRD-2-06.md`
- Existing: `Reporting::DataProvider#historical_trends` already existed, but PRD-2-06 requires:
  - JSON field name: `historical_net_worth`
  - Up to 30 prior `complete` snapshots
  - Sorted ascending by date
  - Narrow query (pluck only `snapshot_at` + net worth value)
  - Return `[]` when no history

## 3. Plan
1. Update `Reporting::DataProvider#historical_trends` to fetch the last 30 complete snapshots and return the PRD shape.
2. Persist `historical_net_worth` into `FinancialSnapshotJob` output JSON.
3. Add/extend Minitest coverage for provider + job.
4. Run targeted tests.
5. Update Epic implementation tracker and commit.

## 4. Work Log (Chronological)
- Implemented `Reporting::DataProvider#historical_trends` to return a compact 30-entry net worth series sourced from prior `FinancialSnapshot` rows.
- Updated `FinancialSnapshotJob` to persist `historical_net_worth` in the daily snapshot JSON.
- Added Minitest coverage for provider + job trend behavior.
- Ran targeted tests to verify behavior.

## 5. Files Changed
- `app/services/reporting/data_provider.rb` — Update `#historical_trends` to fetch up to 30 prior complete snapshots and pluck `snapshot_at` + `data->>'total_net_worth'`.
- `app/jobs/financial_snapshot_job.rb` — Persist `historical_net_worth` in snapshot JSON.
- `test/services/reporting/data_provider_test.rb` — Add tests for historical trends ordering and empty history.
- `test/jobs/financial_snapshot_job_test.rb` — Add tests for `historical_net_worth` inclusion and correctness.
- `knowledge_base/epics/wip/NextGen/Epic-2/0001-IMPLEMENTATION-STATUS.md` — Mark PRD-2-06 implemented and add implementation notes.
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-06-historical-trends.md` — This log.

## 6. Commands Run
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` — ✅ pass

## 7. Tests
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Store the trend array under `data['historical_net_worth']` as `[{"date","value"}, ...]`.
  - Rationale: Matches PRD-2-06 required output and keeps JSON compact.
- Decision: Query snapshot history via `FinancialSnapshot.recent_for_user(user, 30).complete_only.limit(30)` and pluck only required fields.
  - Rationale: Uses existing composite index and avoids loading full JSON blobs.

## 9. Risks / Tradeoffs
- If historical snapshots used nested schema formats in the future, `data->>'total_net_worth'` would miss values.
  - Mitigation: PRD-2-02+ stores flat `total_net_worth`; if nested formats are reintroduced later, we can extend the query to coalesce nested paths.

## 10. Follow-ups
- [ ] Consider adding an optional backfill job (future Epic 2.5) to guarantee a full 30-day history.

## 11. Outcome
- Daily snapshots now include `data['historical_net_worth']` containing up to 30 prior net worth points sorted ascending by date.

## 12. Commit(s)
- `Implement PRD-2-06 historical trends` — `ac7b918`
- `Update PRD-2-06 docs` — `558dd55`

## 13. Manual steps to verify and what user should see
1. Ensure there are at least a few prior `FinancialSnapshot` rows with `status: :complete` for a user.
2. Run in Rails console:
   - `FinancialSnapshotJob.perform_now(user)`
3. Inspect:
   - `snap = user.financial_snapshots.order(snapshot_at: :desc).first`
4. Expected:
   - `snap.data['historical_net_worth']` is an array
   - Entries are sorted ascending by `date`
   - Each entry has `date` (YYYY-MM-DD) and `value` (numeric net worth)
   - If the user has no prior `complete` snapshots, the array is empty.
