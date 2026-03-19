# Junie Task Log — PRD-3-16: Snapshot Export Button
Date: 2026-01-27  
Mode: Brave  
Branch: feature/prd-3-16-export-button  
Owner: junie

## 1. Goal
- Add a DaisyUI dropdown "Export Snapshot" on the Net Worth dashboard that downloads the latest snapshot as JSON or CSV via the existing PRD-2-08 export endpoint.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-3/0070-PRD-3-16.md`
- Must leverage existing API endpoint (`/api/snapshots/:id/download`) and produce:
  - JSON: full `snapshot.data`
  - CSV: `Account,Symbol,Name,Value,Percentage`
- Must be user-scoped (no cross-user export) and use `data: { turbo: false }` for downloads.

## 3. Plan
1. Confirm existing PRD-2-08 download endpoint behavior and constraints.
2. Add CSV support and PRD-3-16 filenames on the existing endpoint.
3. Ensure snapshot payload contains export-friendly holdings rows (with account name) going forward.
4. Add dashboard UI dropdown (ViewComponent + preview).
5. Add tests for JSON/CSV downloads and component rendering.

## 4. Work Log (Chronological)
- Inspected PRD-3-16 requirements and confirmed the existing route `GET /api/snapshots/:id/download`.
- Extended `Api::SnapshotsController#download` to:
  - Use PRD filename `networth-snapshot-YYYY-MM-DD.*`
  - Support CSV downloads via `format=csv`
- Added `Reporting::DataProvider#holdings_export_rows` and persisted `holdings_export` into snapshots via `FinancialSnapshotJob`.
- Added `NetWorth::ExportSnapshotDropdownComponent` + ViewComponent preview for enabled/disabled states.
- Wired dashboard header to render the component.
- Added/updated tests for API download responses and component rendering.
- Ran a broader `FinancialSnapshotJob` test suite and fixed surfaced issues (removed retry scheduling + made holdings export optional for stubs).
- Fixed export button being disabled when the latest persisted snapshot is `stale` (previously `latest_for_user` only returned `complete`).
- Fixed JSON export for older snapshots to backfill missing keys (`holdings_export`, `transactions_summary`) at download time so the exported file is more complete even when historical snapshot payloads are sparse.
- Adjusted JSON export UX to avoid “looks like only holdings”: default JSON download now omits the large `holdings_export` payload (summary JSON). Added a separate “full JSON” option that includes `holdings_export` via `include_holdings_export=true`.

## 5. Files Changed
- `app/controllers/api/snapshots_controller.rb` — Added CSV support and updated filenames to `networth-snapshot-YYYY-MM-DD`.
- `app/services/reporting/data_provider.rb` — Added `holdings_export_rows` for CSV export (includes account name).
- `app/jobs/financial_snapshot_job.rb` — Persisted `holdings_export` into `snapshot.data` (with safe fallback).
- `app/components/net_worth/export_snapshot_dropdown_component.rb` — New export dropdown component.
- `app/components/net_worth/export_snapshot_dropdown_component.html.erb` — New component template (Turbo-disabled download links).
- `app/views/net_worth/dashboard/show.html.erb` — Render export component in header.
- `test/controllers/api/snapshots_controller_test.rb` — Updated JSON filename assertion + added CSV download test.
- `test/components/net_worth/export_snapshot_dropdown_component_test.rb` — Component unit tests.
- `test/components/previews/net_worth/export_snapshot_dropdown_component_preview.rb` — Component previews.
- `app/models/financial_snapshot.rb` — Treat `stale` snapshots as exportable for `latest_for_user`.
- `test/models/financial_snapshot_test.rb` — Coverage for `latest_for_user` returning `stale` snapshots.

## 6. Commands Run
- `bin/rails test test/controllers/api/snapshots_controller_test.rb` — pass
- `bin/rails test test/components/net_worth/export_snapshot_dropdown_component_test.rb` — pass
- `bin/rails test test/jobs/financial_snapshot_job_test.rb` — pass
- `RAILS_ENV=test bin/rails test test/models/financial_snapshot_test.rb` — pass

## 7. Tests
- `bin/rails test test/controllers/api/snapshots_controller_test.rb` — ✅ pass
- `bin/rails test test/components/net_worth/export_snapshot_dropdown_component_test.rb` — ✅ pass
- `bin/rails test test/jobs/financial_snapshot_job_test.rb` — ✅ pass
- `RAILS_ENV=test bin/rails test test/models/financial_snapshot_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Add a new `holdings_export` array to `FinancialSnapshot.data`.
  - Rationale: PRD CSV requires an `Account` column, which is not present in `top_holdings`/UI holdings hashes.
  - Alternatives considered: Build CSV from live DB queries at download time (rejected to keep export tied to snapshot payload and avoid expensive joins during download).
- Decision: Implement the UI as a ViewComponent.
  - Rationale: Matches repo conventions and enables previews for enabled/disabled states.

## 9. Risks / Tradeoffs
- Existing snapshots created before this change may not contain `holdings_export`.
  - Mitigation: CSV generator falls back to `top_holdings` with a blank `Account` column; JSON export now also backfills `holdings_export` on download.
- CSV "Percentage" formatting is derived from portfolio fraction when available.
  - Mitigation: Defensive conversions; values default to `0` if missing.

## 10. Follow-ups
- [ ] Consider adding a flash/retry UX for download failures (API downloads are not easily flash-driven).
- [ ] Consider adding ZIP export if multiple CSVs are needed (holdings/transactions/accounts) as noted in PRD.

## 11. Outcome
- Net Worth dashboard includes an "Export Snapshot" dropdown.
- JSON and CSV downloads work via the existing API route and use the required filename format.
- CSV exports holdings rows with headers `Account,Symbol,Name,Value,Percentage`.

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Sign in as a user with an existing `FinancialSnapshot`.
2. Visit `/net_worth`.
3. In the header, open the "Export Snapshot" dropdown.
4. Click "Download JSON (summary)" → browser downloads `networth-snapshot-YYYY-MM-DD.json` (snapshot summary data, omitting `holdings_export`).
5. Click "Download JSON (full)" → browser downloads `networth-snapshot-YYYY-MM-DD.json` including `holdings_export`.
6. Click "Download CSV" → browser downloads `networth-snapshot-YYYY-MM-DD.csv` with headers `Account,Symbol,Name,Value,Percentage`.
7. If no snapshot exists, the button is disabled with tooltip "No snapshot available yet".
