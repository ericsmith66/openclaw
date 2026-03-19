# Epic 2: Implementation Status & Readiness

**Date**: 2026-01-24
**Status**: ✅ **READY FOR IMPLEMENTATION**
**Branch**: `feature/epic-2-financial-snapshots`

---

## 📋 Document Structure Confirmation

All Epic 2 documents have been created following Epic 1 naming convention:

### Core Documents
- ✅ `0000.overview-epic-2.md` - Epic overview with all context, policies, and JSON structure
- ✅ `0010-PRD-2-01.md` - FinancialSnapshot Model & Migration (IMPLEMENTED ✅)
- ✅ `0015-PRD-2-01b.md` - Reporting::DataProvider Service (IMPLEMENTED ✅)
- ✅ `0020-PRD-2-02.md` - FinancialSnapshotJob Core Aggregates (IMPLEMENTED ✅)
- ✅ `0030-PRD-2-03.md` - Asset Allocation Breakdown (IMPLEMENTED ✅)
- ✅ `0040-PRD-2-04.md` - Sector Weights (IMPLEMENTED ✅)
- ✅ `0050-PRD-2-05.md` - Holdings & Transactions Summary (IMPLEMENTED ✅)
- ✅ `0060-PRD-2-06.md` - Historical Trends (IMPLEMENTED ✅)
- ✅ `0070-PRD-2-07.md` - Admin Preview & Validation (IMPLEMENTED ✅)
- ✅ `0080-PRD-2-08.md` - Export API with RAG Context (IMPLEMENTED ✅)
- ✅ `0090-PRD-2-09.md` - Net Worth Dashboard UI (with lifecycle test)
- ✅ `0100-additional-questions.md` - Clarifications for Eric (10 questions with recommendations)

### Supporting Documents
- ✅ `Epic-2-JSON-Snapshots-feedback.md` - Original feedback from Junie
- ✅ `Epic-2-grok_eric_comments.md` - First round of Eric/Grok responses
- ✅ `Epic-2-grok_eric_comments-2.md` - Second round confirming all changes incorporated

---

## ✅ PRD-2-01 Implementation Notes (2026-01-24)

Implemented foundational storage for daily per-user financial snapshots.

- Added `FinancialSnapshot` ActiveRecord model with CST-day normalization, enums, validations, scopes, rollback.
- Added migration + schema updates for `financial_snapshots` with JSONB GIN index and per-user uniqueness.
- Uniqueness is enforced via application-level CST normalization (`snapshot_at` is coerced to CST beginning-of-day) plus a standard unique index on `[:user_id, :snapshot_at]`.
- Added `Reporting::SnapshotAdapter` scaffold and minimal `Reporting::DataQualityValidator`.
- Added Minitest coverage.

Key files:
- `app/models/financial_snapshot.rb`
- `db/migrate/20260124134000_create_financial_snapshots.rb`
- `db/schema.rb`
- `app/services/reporting/snapshot_adapter.rb`
- `app/services/reporting/data_quality_validator.rb`
- `test/models/financial_snapshot_test.rb`
- `config/initializers/constants.rb`

Verification:
- `RAILS_ENV=test bin/rails test test/models/financial_snapshot_test.rb` (✅ passing)

## ✅ PRD-2-01b Implementation Notes (2026-01-24)

Implemented `Reporting::DataProvider` service scaffold for centralized snapshot aggregate queries.

- Added `Reporting::DataProvider` with strict user scoping via joins through `PlaidItem`.
- Implemented chainable date filtering (`with_date_range`) and memoized aggregate methods.
- Implemented `build_snapshot_hash` orchestration and export stubs (`to_json`, `to_csv`, `to_tableau_json`).

Key files:
- `app/services/reporting/data_provider.rb`
- `test/services/reporting/data_provider_test.rb`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-01b-reporting-data-provider.md`

Verification:
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb` (✅ passing)

## ✅ PRD-2-02 Implementation Notes (2026-01-24)

Implemented daily `FinancialSnapshotJob` to compute and persist core net worth aggregates per user.

- Updated `FinancialSnapshotJob` to create/update a per-user daily `FinancialSnapshot` (CST day) with flat JSON fields: `total_net_worth`, `delta_day`, `delta_30d`, `as_of`, `disclaimer`.
- Implemented idempotency (skip already-`complete` snapshots unless forced), and explicit statuses for `:stale`, `:empty`, and `:error`.
- Added Solid Queue recurring schedule entry for daily midnight runs.
- Updated `Reporting::DataProvider` to read net worth from both flat and nested snapshot formats for delta/trends compatibility.
- Added Minitest job coverage.

Key files:
- `app/jobs/financial_snapshot_job.rb`
- `app/services/reporting/data_provider.rb`
- `config/recurring.yml`
- `test/jobs/financial_snapshot_job_test.rb`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-02-financial-snapshot-job-core-aggregates.md`

Verification:
- `RAILS_ENV=test bin/rails test test/jobs/financial_snapshot_job_test.rb test/services/reporting/data_provider_test.rb` (✅ passing)

## ✅ PRD-2-03 Implementation Notes (2026-01-24)

Implemented asset allocation breakdown percentages and persisted them into daily snapshots.

- Updated `Reporting::DataProvider#asset_allocation_breakdown` to bucket holdings into stable keys (`equity`, `fixed_income`, `cash`, `alternative`, `other`).
- Added explicit `other` bucket for nil/blank/unknown `asset_class` values.
- Rounds to 4 decimals and adjusts the largest bucket to force sum to `1.0` within tolerance.
- Updated `FinancialSnapshotJob` to persist `asset_allocation` into `FinancialSnapshot.data`.
- Added Minitest coverage for snapshot inclusion and `other` bucket behavior.

Key files:
- `app/services/reporting/data_provider.rb`
- `app/jobs/financial_snapshot_job.rb`
- `test/services/reporting/data_provider_test.rb`
- `test/jobs/financial_snapshot_job_test.rb`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-03-asset-allocation-breakdown.md`

Verification:
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` (✅ passing)

## ✅ PRD-2-04 Implementation Notes (2026-01-24)

Implemented equity sector weights and persisted them into daily financial snapshots.

- Updated `Reporting::DataProvider#sector_weights` to compute **equity-only** sector weights.
- Buckets nil/blank sectors into `unknown` and normalizes keys to lowercase for stability.
- Returns `nil` (not `{}`) when the user has no equity holdings.
- Updated `FinancialSnapshotJob` to persist `sector_weights` into `FinancialSnapshot.data`.
- Added Minitest coverage for provider + job behavior.

Key files:
- `app/services/reporting/data_provider.rb`
- `app/jobs/financial_snapshot_job.rb`
- `test/services/reporting/data_provider_test.rb`
- `test/jobs/financial_snapshot_job_test.rb`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-04-sector-weights.md`

Verification:
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` (✅ passing)

## ✅ PRD-2-05 Implementation Notes (2026-01-24)

Implemented daily snapshot extensions for holdings and transaction summaries.

- Updated `Reporting::DataProvider#top_holdings` to return top 10 holdings by value with `pct_portfolio`.
- Updated `Reporting::DataProvider#monthly_transaction_summary` to compute last-30-day `income`, `expenses`, and `top_categories` (top 5 by absolute amount).
- Updated `FinancialSnapshotJob` to persist `top_holdings` and `monthly_transaction_summary` into `FinancialSnapshot.data`.
- Added Minitest coverage for provider + job behavior.

Key files:
- `app/services/reporting/data_provider.rb`
- `app/jobs/financial_snapshot_job.rb`
- `test/services/reporting/data_provider_test.rb`
- `test/jobs/financial_snapshot_job_test.rb`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-05-holdings-transactions-summary.md`

Verification:
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` (✅ passing)

## ✅ PRD-2-06 Implementation Notes (2026-01-24)

Implemented historical net worth trend support in daily snapshots.

- Updated `Reporting::DataProvider#historical_trends` to fetch up to 30 prior `complete` snapshots via `FinancialSnapshot.recent_for_user(user, 30)`.
- Uses a narrow `pluck` of `snapshot_at` and `data->>'total_net_worth'` for efficiency.
- Updated `FinancialSnapshotJob` to persist `historical_net_worth` as `[{"date","value"}, ...]` sorted ascending by date.
- Added Minitest coverage for provider + job behavior.

Key files:
- `app/services/reporting/data_provider.rb`
- `app/jobs/financial_snapshot_job.rb`
- `test/services/reporting/data_provider_test.rb`
- `test/jobs/financial_snapshot_job_test.rb`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-06-historical-trends.md`

Verification:
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` (✅ passing)

## ✅ PRD-2-07 Implementation Notes (2026-01-24)

Implemented an admin-only preview UI for `FinancialSnapshot` plus basic validation warnings.

- Added `/admin/snapshots` index (paginated) for recent snapshots across users.
- Added `/admin/snapshots/:id` show page with snapshot metadata, warnings, and pretty-printed JSON.
- Added job-time validations (stored as `data['data_quality']['warnings']`):
  - Asset allocation sum ≈ 1.0 (tolerance 0.01 when present)
  - Net worth sanity check (>= -10,000,000)

Key files:
- `config/routes.rb`
- `app/controllers/admin/snapshots_controller.rb`
- `app/views/admin/snapshots/index.html.erb`
- `app/views/admin/snapshots/show.html.erb`
- `app/jobs/financial_snapshot_job.rb`
- `test/controllers/admin/snapshots_controller_test.rb`
- `test/jobs/financial_snapshot_job_test.rb`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-07-admin-preview-validation.md`

Verification:
- `RAILS_ENV=test bin/rails test test/controllers/admin/snapshots_controller_test.rb test/jobs/financial_snapshot_job_test.rb test/services/reporting/data_provider_test.rb` (✅ passing)

## ✅ PRD-2-08 Implementation Notes (2026-01-24)

Implemented API endpoints for exporting stored `FinancialSnapshot` JSON, plus a sanitized RAG context export.

- Added `/api/snapshots/:id/download` endpoint:
  - Uses `send_data` to return full `snapshot.data` JSON
  - Owner-only access (403 for non-owners)
  - Filename: `financial-snapshot-YYYY-MM-DD.json`
- Added `/api/snapshots/:id/rag_context` endpoint:
  - Admin-only by default, or API-key access via `X-Api-Key` when `RAG_EXPORT_API_KEY` is configured
  - Uses `Reporting::DataProvider#to_rag_context(snapshot.data)` to:
    - Strip sensitive keys (`account_numbers`, `institution_ids`, `raw_transaction_data`) when present
    - Add `user_id_hash` (SHA256 of `user.id` + `ENV['RAG_SALT']`)
    - Add `exported_at` and an enhanced disclaimer
- Updated `Reporting::DataProvider#to_tableau_json` to return a flattened hash for BI ingestion (v1 stub).

Key files:
- `config/routes.rb`
- `app/controllers/api/snapshots_controller.rb`
- `app/services/reporting/data_provider.rb`
- `test/controllers/api/snapshots_controller_test.rb`
- `test/services/reporting/data_provider_test.rb`
- `.env.example`
- `knowledge_base/prds-junie-log/2026-01-24__prd-2-08-snapshot-export-api.md`

Verification:
- `RAILS_ENV=test bin/rails test test/controllers/api/snapshots_controller_test.rb test/services/reporting/data_provider_test.rb` (✅ passing)

## ✅ PRD-2-09 Implementation Notes (2026-01-24)

Implemented the user-facing Net Worth dashboard UI backed by stored `FinancialSnapshot` JSON (with `Reporting::DataProvider` fallback) and added a Capybara smoke test.

- Updated `NetWorth::DashboardController#show` to:
  - Enforce the `ENABLE_NEW_LAYOUT` feature flag (returns `404` when disabled to avoid authenticated-root redirect loops)
  - Load latest complete snapshot via `FinancialSnapshot.latest_for_user(current_user)`
  - Fallback to `Reporting::DataProvider#build_snapshot_hash` (normalized to flat keys) when no snapshot exists
  - Expose `@snapshot_data` and a stale banner flag for the view
- Replaced the dashboard placeholder view with a responsive DaisyUI/Tailwind layout rendering ViewComponent cards:
  - `NetWorthHeroComponent` (total net worth + deltas)
  - `AssetAllocationChartComponent` (simple progress-bar visualization)
  - `SectorWeightsComponent` (null-safe)
  - `RecentActivityComponent` (monthly transaction summary)
  - `PerformancePlaceholderComponent` (trend placeholder with last points)
- Added minimal Capybara system-test harness and smoke coverage for:
  - Snapshot present → expected values render
  - No snapshot → “Generating your first snapshot…” message
  - Flag disabled → `404`

Key files:
- `app/controllers/net_worth/dashboard_controller.rb`
- `app/views/net_worth/dashboard/show.html.erb`
- `app/components/net_worth_hero_component.rb`
- `app/components/asset_allocation_chart_component.rb`
- `app/components/sector_weights_component.rb`
- `app/components/recent_activity_component.rb`
- `app/components/performance_placeholder_component.rb`
- `test/application_system_test_case.rb`
- `test/smoke/net_worth_dashboard_capybara_test.rb`
- `test/integration/net_worth_wireframe_test.rb`

Verification:
- `RAILS_ENV=test bin/rails test test/smoke/net_worth_dashboard_capybara_test.rb test/integration/net_worth_wireframe_test.rb` (✅ passing)

## ✅ All Feedback Incorporated

### From Epic-2-grok_eric_comments.md
1. ✅ **Arel Removal**: All PRDs use ActiveRecord exclusively
2. ✅ **Schema Versioning**: Full policy with `SnapshotAdapter` pattern
3. ✅ **Timezone Handling**: `APP_TIMEZONE` constant, normalization callbacks, functional index
4. ✅ **Unique Constraint**: CST-aware functional index
5. ✅ **Data Quality**: `DataQualityValidator` service with weighted checks
6. ✅ **Percentage Normalization**: Force sum=1.0 in `normalize_percentages`
7. ✅ **Job Staggering**: Documented for future (v1 simple OK)
8. ✅ **Performance Baselines**: 500 positions, 1000 txns, <5s
9. ✅ **Composite Indexes**: `[:user_id, :snapshot_at]` for efficient queries
10. ✅ **Missing Data Handling**: `:empty` status, explicit fallbacks
11. ✅ **Retry Strategy**: Exponential backoff, discard duplicates
12. ✅ **Stale Detection**: >36h threshold via `sync_freshness`
13. ✅ **Application-Level RLS**: `current_user.financial_snapshots` scoping
14. ✅ **Role-Based Auth**: User role enum for admin
15. ✅ **RAG Sanitization**: SHA256 hashing, field exclusions
16. ✅ **Factory Definitions**: Full factories with traits
17. ✅ **Lifecycle Test**: End-to-end integration test in PRD-2-09
18. ✅ **Edge Cases**: Negative NW, concurrency, leap years
19. ✅ **Single Branch**: `feature/epic-2-financial-snapshots`
20. ✅ **Rollback Method**: `rollback_to_date` class method

### From Epic-2-grok_eric_comments-2.md
All confirmations received - no new changes required. Ready to proceed.

---

## 📦 Prerequisites Checklist

Before starting PRD-2-01, these must be in place:

### Required Migrations/Files
- [ ] **User Role Migration** (for PRD-2-07 admin auth)
  ```ruby
  # db/migrate/XXXXXX_add_role_to_users.rb
  add_column :users, :role, :integer, default: 0, null: false
  add_index :users, :role
  # Enums: 0=intern, 1=advisor, 2=admin
  ```

- [ ] **APP_TIMEZONE Constant**
  ```ruby
  # config/initializers/constants.rb
  APP_TIMEZONE = 'America/Chicago'.freeze
  ```

- [ ] **Rails Timezone Config**
  ```ruby
  # config/application.rb
  config.time_zone = 'America/Chicago'
  ```

- [ ] **Snapshot Schema Policy Doc**
  ```bash
  # knowledge_base/data/snapshot-schema-policy.md
  # Content in 0100-additional-questions.md section 5
  ```

- [ ] **ENV Variables** (add to `.env.example`)
  ```bash
  ENABLE_NEW_LAYOUT=true
  RAG_SALT=your-random-salt-here
  ```

### Nice to Have (Can Be Created During PRDs)
- [ ] DataQualityValidator service (PRD-2-01 or PRD-2-02)
- [ ] SnapshotAdapter module (PRD-2-01)
- [ ] Chart library decision (PRD-2-09)

---

## 🎯 Implementation Order

### Phase 1: Foundation (PRD-2-01, 2-01b)
1. **PRD-2-01**: FinancialSnapshot Model
   - Migration with indexes
   - Scopes and methods
   - Factory with traits
   - Model specs (comprehensive)
   - SnapshotAdapter stub
   - DataQualityValidator service (optional here)

2. **PRD-2-01b**: DataProvider Service
   - Core aggregates method
   - Chainable `with_date_range` example
   - `normalize_percentages` helper
   - Memoization pattern
   - Export stubs (to_json, to_csv, to_tableau_json)
   - Service specs with memoization tests
   - Benchmark spec

### Phase 2: Job & Data (PRD-2-02 through 2-06)
3. **PRD-2-02**: FinancialSnapshotJob Core
4. **PRD-2-03**: Asset Allocation
5. **PRD-2-04**: Sector Weights
6. **PRD-2-05**: Holdings & Transactions
7. **PRD-2-06**: Historical Trends

### Phase 3: Admin & Export (PRD-2-07, 2-08)
8. **PRD-2-07**: Admin Preview
9. **PRD-2-08**: Export API

### Phase 4: User Interface (PRD-2-09)
10. **PRD-2-09**: Dashboard UI with lifecycle test

---

## 🔍 Key Design Decisions Confirmed

### Architecture
- **No Arel in v1**: Pure ActiveRecord scopes and relations
- **Service Layer**: `Reporting::DataProvider` centralizes all aggregations
- **Adapter Pattern**: `Reporting::SnapshotAdapter` for schema evolution
- **Application-Level Security**: No PostgreSQL RLS, use AR associations

### Data Integrity
- **Timezone**: All dates in CST via `APP_TIMEZONE`, UTC storage
- **Uniqueness**: Functional index on CST date per user
- **Percentages**: Always sum to exactly 1.0 via `normalize_percentages`
- **Enums**: `[:pending, :complete, :error, :stale, :empty, :rolled_back]`

### Performance
- **Baselines**: <5s per user, 500 positions, 1000 transactions
- **Memoization**: Throughout DataProvider methods
- **Indexes**: Composite `[:user_id, :snapshot_at]`, GIN on `data`
- **Job Scheduling**: Simple midnight cron for v1 (10-50 users OK)

### Error Handling
- **Retry**: Exponential backoff, 3 attempts
- **Discard**: Duplicates (RecordNotUnique)
- **Status**: Explicit states for error conditions
- **Stale**: >36h since last sync

### Security
- **Authorization**: Role-based (`current_user.admin?`)
- **Scoping**: `current_user.financial_snapshots` everywhere
- **RAG**: SHA256 hashing, field sanitization

---

## 🧪 Testing Strategy

### Test Coverage Requirements
Each PRD must include:
- ✅ Model specs (if applicable)
- ✅ Service specs
- ✅ Job specs (if applicable)
- ✅ Controller specs (if applicable)
- ✅ Feature specs (PRD-2-09)
- ✅ Component specs (PRD-2-09)
- ✅ Edge case tests
- 🔄 Benchmark specs (optional but recommended)

### Edge Cases to Test
- ✅ Negative net worth
- ✅ Very large portfolios (>$1B)
- ✅ Leap year dates
- ✅ Concurrent snapshot creation
- ✅ Empty/missing data
- ✅ Stale syncs
- ✅ Permission boundaries

### Integration Tests
- ✅ Full lifecycle test in PRD-2-09
- ✅ End-to-end: Seed → Job → Admin → Download → Dashboard

---

## 📝 Workflow Confirmation

### Git Branch Strategy
```bash
# Single long-running branch for entire epic
git checkout -b feature/epic-2-financial-snapshots

# Sequential commits per PRD
git commit -m "feat(PRD-2-01): Add FinancialSnapshot model..."
git commit -m "feat(PRD-2-01b): Add DataProvider service..."
# ... etc

# Push for incremental review
git push origin feature/epic-2-financial-snapshots

# Final merge when epic complete
git checkout main
git merge --squash feature/epic-2-financial-snapshots
git commit -m "feat(Epic-2): Complete financial snapshots system"
```

### Commit Requirements
- ✅ All tests green before commit
- ✅ No N+1 queries
- ✅ Proper indexing verified
- ✅ Memoization working
- ✅ Error handling comprehensive

### Review Checkpoints
After each PRD commit, human reviews:
1. Diff for quality/correctness
2. Test coverage completeness
3. Performance considerations
4. Error handling sufficiency
5. Documentation clarity

---

## ❓ Outstanding Questions (from 0100-additional-questions.md)

All questions have **recommended defaults** — Junie can proceed without blocking:

1. **User role migration timing**: ✅ Recommended before PRD-2-01
2. **DataQualityValidator creation**: ✅ Recommended in PRD-2-01
3. **Chart library**: ✅ Recommended Chartkick (simplest)
4. **ENV variables**: ✅ Add in PRD-2-08
5. **Schema policy doc**: ✅ Create in PRD-2-01
6. **Performance benchmarks**: ✅ Add but don't fail CI
7. **Sidekiq dashboard**: ✅ Defer to post-v1
8. **Manual regeneration**: ✅ Defer to post-v1
9. **Mobile responsive**: ✅ Basic responsive, not optimized
10. **Error notifications**: ✅ Admin-only for v1

---

## ✅ READY FOR IMPLEMENTATION

### Junie - Next Steps
1. **Review this status document**
2. **Complete prerequisites** (user role migration, constants, config)
3. **Start PRD-2-01** on `feature/epic-2-financial-snapshots` branch
4. **Log plan/questions** per Junie log requirements
5. **Commit only green code**
6. **Push for Eric's review**

### Eric - Next Steps
1. **Confirm prerequisites** are acceptable
2. **Answer any blocking questions** from 0100-additional-questions.md
3. **Review Junie's PRD-2-01 commits** incrementally
4. **Provide feedback** for adjustments

---

## 📊 Epic 2 Success Criteria

Epic 2 is complete when:
1. ✅ All 9 PRDs (2-01 through 2-09) implemented and tested
2. ✅ Daily job generating valid snapshots for all test users
3. ✅ Admin can preview/validate snapshot data
4. ✅ Users can download snapshots via API
5. ✅ Net worth dashboard renders using snapshot data
6. ✅ All tests green (unit, integration, feature)
7. ✅ Performance within baselines (<5s per user)
8. ✅ Data quality scores >90 for test users
9. ✅ Lifecycle integration test passes
10. ✅ PRD-2-00 scaffold integrated with real data

---

## 🎉 Summary

**Status**: All feedback incorporated, all PRDs created, structure matches Epic 1 format.
**Blocking Issues**: None
**Prerequisites**: 4 items (user role, constant, config, doc) — all straightforward
**Questions**: 10 non-blocking questions with recommendations
**Recommendation**: **Proceed with implementation immediately**

**Estimated Timeline** (with Junie + Claude Sonnet 4.5):
- PRD-2-01: 2-3 hours (model, migration, specs, factory)
- PRD-2-01b: 2-3 hours (service, specs, benchmarks)
- PRD-2-02: 3-4 hours (job, complex specs)
- PRD-2-03 to 2-06: 1-2 hours each (incremental additions)
- PRD-2-07: 2-3 hours (admin UI)
- PRD-2-08: 2-3 hours (API endpoints)
- PRD-2-09: 4-5 hours (dashboard UI, components, lifecycle test)

**Total**: ~25-35 hours of focused implementation time

With incremental commits and reviews, Epic 2 can be completed within **1-2 weeks** of dedicated work.

---

**Last Updated**: 2026-01-24 13:35 CST
**Next Action**: Eric to confirm prerequisites, Junie to start PRD-2-01
