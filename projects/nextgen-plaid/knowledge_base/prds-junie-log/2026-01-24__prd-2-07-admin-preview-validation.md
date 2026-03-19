# Junie Task Log — PRD-2-07 Snapshot Validation & Admin Preview
Date: 2026-01-24  
Mode: Brave  
Branch: feature/epic-2-financial-snapshots  
Owner: Junie

## 1. Goal
- Add an admin-only interface to list/view `FinancialSnapshot` records and add basic snapshot validation warnings for debugging before Epic 3.

## 2. Context
- PRD reference: `knowledge_base/epics/wip/NextGen/Epic-2/0070-PRD-2-07.md`
- Existing snapshot pipeline (PRD-2-01..2-06): `FinancialSnapshotJob` writes daily per-user snapshots.
- Existing admin patterns:
  - Admin controllers already exist under `Admin::` with `before_action :authenticate_user!`.
  - `User#admin?` is currently role-string based (`users.roles` includes `"admin"`).

## 3. Plan
1. Add admin routes + controller for snapshot index/show.
2. Build admin views for listing snapshots and showing pretty JSON.
3. Add job-time validation warnings:
   - Allocation sum sanity check
   - Net worth sanity check
4. Add Minitest coverage for admin access + validation warnings.
5. Run targeted tests.
6. Update Epic tracker and commit.

## 4. Work Log (Chronological)
- Added `Admin::SnapshotsController` with admin-only access (403 for non-admin) and pagination.
- Added admin views:
  - Index table for recent snapshots
  - Show page with snapshot metadata, warnings, and pretty JSON
- Added validation warnings inside `FinancialSnapshotJob`:
  - Asset allocation sum must be within 0.01 of 1.0 when present
  - Net worth must be >= -10,000,000
- Added integration tests for admin/non-admin access.
- Added job tests that stub `Reporting::DataProvider` to force validation warnings.

## 5. Files Changed
- `config/routes.rb` — Add `admin/snapshots` routes.
- `app/controllers/admin/snapshots_controller.rb` — Admin-only snapshots index/show.
- `app/views/admin/snapshots/index.html.erb` — Snapshot list table.
- `app/views/admin/snapshots/show.html.erb` — Pretty JSON + warnings.
- `app/jobs/financial_snapshot_job.rb` — Add validation warnings during snapshot generation.
- `test/controllers/admin/snapshots_controller_test.rb` — Admin access + 403 coverage.
- `test/jobs/financial_snapshot_job_test.rb` — Validation warning coverage.
- `knowledge_base/epics/wip/NextGen/Epic-2/0001-IMPLEMENTATION-STATUS.md` — Mark PRD-2-07 implemented.

## 6. Commands Run
- `RAILS_ENV=test bin/rails test test/controllers/admin/snapshots_controller_test.rb test/jobs/financial_snapshot_job_test.rb test/services/reporting/data_provider_test.rb` — ✅ pass

## 7. Tests
- `RAILS_ENV=test bin/rails test test/controllers/admin/snapshots_controller_test.rb test/jobs/financial_snapshot_job_test.rb test/services/reporting/data_provider_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Use `head :forbidden` for non-admin access.
  - Rationale: PRD requires 403 behavior and this matches existing patterns in some admin controllers.
- Decision: Store validation results as warning strings in `data['data_quality']['warnings']`.
  - Rationale: Avoids adding a new enum/status + migration; keeps validation information visible in admin preview.

## 9. Risks / Tradeoffs
- Admin auth currently uses `users.roles` string parsing, not the PRD-suggested integer enum.
  - Mitigation: PRD acceptance criteria focuses on `current_user.admin?`; current implementation already supports it.

## 10. Follow-ups
- [ ] If/when `users.role` enum is introduced, ensure `User#admin?` remains correct and update tests.
- [ ] Consider adding a dedicated `data_quality.score` calculation in `Reporting::DataQualityValidator` (currently minimal).

## 11. Outcome
- Admins can list and view financial snapshots at `/admin/snapshots`.
- Admin preview shows pretty JSON and any validation warnings.
- Snapshot job now appends validation warnings for allocation-sum and net-worth sanity failures.

## 12. Commit(s)
- `Implement PRD-2-07 admin snapshot preview & validation` — `230373c`

## 13. Manual steps to verify and what user should see
1. Sign in as an admin user (`current_user.admin?` returns true).
2. Visit `/admin/snapshots`.
   - Expected: A table of recent snapshots with User/Date/Status/Net Worth/Quality Score and a View action.
3. Click “View” on a snapshot.
   - Expected: Snapshot metadata (user/date/status), any warnings, and pretty-printed JSON.
4. Sign in as a non-admin user and visit `/admin/snapshots`.
   - Expected: HTTP 403 Forbidden.
