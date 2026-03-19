# Junie Task Log — PRD-2-03 Asset Allocation Breakdown
Date: 2026-01-24  
Mode: Brave  
Branch: feature/epic-2-financial-snapshots  
Owner: Junie

## 1. Goal
- Add asset allocation breakdown percentages to the daily `FinancialSnapshot` JSON via `Reporting::DataProvider`, and persist it from `FinancialSnapshotJob`.

## 2. Context
- Epic 2 snapshots power Epic 3 dashboard components.
- PRD reference: `knowledge_base/epics/wip/NextGen/Epic-2/0030-PRD-2-03.md`
- Dependencies: PRD-2-02 (`FinancialSnapshotJob` core aggregates) already implemented.
- Existing code already had `Reporting::DataProvider#asset_allocation_breakdown` (holdings-based) but it needed an explicit `other` bucket and rounding/normalization guarantees.

## 3. Plan
1. Update `Reporting::DataProvider#asset_allocation_breakdown` to bucket/normalize asset classes and return percentages that sum to 1.0.
2. Update `FinancialSnapshotJob` to persist `asset_allocation` into snapshot JSON.
3. Add/extend Minitest coverage for allocation behavior.
4. Run targeted tests.
5. Update Epic implementation tracker.

## 4. Work Log (Chronological)
- Updated `Reporting::DataProvider#asset_allocation_breakdown` to:
  - Normalize asset classes into stable buckets (`equity`, `fixed_income`, `cash`, `alternative`, `other`).
  - Bucket nil/blank/unknown values into `other`.
  - Round to 4 decimals and adjust the largest bucket to force sum to `1.0` within tolerance.
- Updated `FinancialSnapshotJob` to include `asset_allocation` in persisted snapshot JSON.
- Added tests for `other` bucket handling and for snapshot JSON including allocation.

## 5. Files Changed
- `app/services/reporting/data_provider.rb` — Enhance allocation bucketing + rounding/normalization.
- `app/jobs/financial_snapshot_job.rb` — Persist `asset_allocation` in `FinancialSnapshot.data`.
- `test/services/reporting/data_provider_test.rb` — Add coverage for `other` bucket.
- `test/jobs/financial_snapshot_job_test.rb` — Assert allocation is present/sums to 1.0; add `other` bucket coverage.
- `knowledge_base/epics/wip/NextGen/Epic-2/0001-IMPLEMENTATION-STATUS.md` — Mark PRD-2-03 implemented.

## 6. Commands Run
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` — ✅ completed

## 7. Tests
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Use `Holding.market_value` grouped by `asset_class` for allocation.
  - Rationale: This codebase stores investment positions as `Holding` rows; PRD language references “Position”, but the equivalent source of truth is holdings.
- Decision: Force stable bucket keys and add `other`.
  - Rationale: Downstream UI expects a consistent shape and needs to handle uncategorized holdings safely.

## 9. Risks / Tradeoffs
- Asset class categorization quality depends on upstream enrichment/import (the `asset_class` stored on holdings).
  - Mitigation: `other` bucket prevents failures and still provides a truthful allocation.

## 10. Follow-ups
- [ ] If/when `SecurityEnrichment` becomes the canonical source for `asset_class`, revisit `normalize_asset_class` to prefer enrichment data.

## 11. Outcome
- Daily snapshots now include `data['asset_allocation']` with normalized buckets and percentages summing to 1.0.

## 12. Commit(s)
- `Implement PRD-2-03 asset allocation breakdown` — `64e1139`

## 13. Manual steps to verify and what user should see
1. In Rails console, ensure a user has holdings with multiple `asset_class` values (and optionally one nil/unknown).
2. Run: `FinancialSnapshotJob.perform_now(user)`
3. Inspect the latest `FinancialSnapshot` for the user.
4. Expected:
   - `snapshot.data['asset_allocation']` is a hash.
   - Values are decimals 0–1 and sum to ~1.0.
   - Nil/unknown classes appear under `other`.
