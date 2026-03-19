---

# Junie Task Log — PRD-1-05 Null Field Detection & Logging
Date: 2026-01-19  
Mode: Brave  
Branch: epic-1-Plaid-Sync-Integrity  
Owner: junie

## 1. Goal
- Add an institution-aware weekly job that scans `Holding`, `Transaction`, and liabilities data for persistent null fields and writes a human-readable report to `knowledge_base/schemas/null_fields_report.md`.

## 2. Context
- Source PRD: `knowledge_base/epics/nexgen/Epic-1/0050-PRD-1-05.md`
- PRD requirement: group null patterns by `PlaidItem.institution_id` so an admin can identify institution-specific missing fields (e.g., “Schwab holdings always null for cost_basis”).
- Repo reality: liabilities are stored on `Account` (no standalone `Liability` model/table).
- Scheduler: Solid Queue recurring schedule is defined in `config/recurring.yml` (production section).

## 3. Plan
1. Confirm how to join holdings/transactions/liability data back to `PlaidItem.institution_id`.
2. Implement `NullFieldDetectionJob` using SQL aggregates per institution to keep runtime low.
3. Generate `knowledge_base/null_fields_report.md` with counts/percentages and “always/mostly null” pattern labels.
4. Add a weekly schedule entry via Solid Queue.
5. Add tests and run the full suite.

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- 2026-01-19: Confirmed liabilities are synced into `Account` fields via `PlaidLiabilitiesService`.
- 2026-01-19: Implemented `NullFieldDetectionJob` with per-institution SQL aggregates and markdown report output.
- 2026-01-19: Added Solid Queue weekly recurring schedule entry for the job.
- 2026-01-19: Added job tests for report generation and empty-data behavior.

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `app/jobs/null_field_detection_job.rb` — new weekly job that aggregates null counts/ratios by institution and writes a markdown report
- `config/recurring.yml` — schedules `NullFieldDetectionJob` weekly in production
- `test/jobs/null_field_detection_job_test.rb` — tests report creation and institution grouping
- `knowledge_base/prds-junie-log/2026-01-19__prd-1-05-null-field-detection.md` — task log (this file)

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.  
Use placeholders for any sensitive arguments.

- `bin/rails test test/jobs/null_field_detection_job_test.rb` — ✅ pass
- `bin/rails test test/jobs/null_field_detection_job_test.rb` — ✅ pass (after changing default report path to `knowledge_base/schemas/`)
- `bin/rails test` — ✅ pass (full suite)
- `bin/rails test test/services/sap_agent/artifact_command_test.rb` — ✅ pass (after prompt hardening)

## 7. Tests
Record tests that were run and results.

- `bin/rails test test/jobs/null_field_detection_job_test.rb` — ✅ pass
- `bin/rails test test/services/sap_agent/artifact_command_test.rb` — ✅ pass
- `bin/rails test` — ✅ pass

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Decision: Treat “Liabilities” as liability-related fields stored on `Account` (rather than introducing a new `Liability` model).
    - Rationale: The repo already persists liabilities on `Account` (e.g., `apr_percentage`, `min_payment_amount`, `next_payment_due_date`, `liability_details`) and syncs them via `PlaidLiabilitiesService`.
- Decision: Use SQL conditional aggregates (one query per model) for per-institution null counting.
    - Rationale: Keeps runtime predictable and reduces N×M query explosion for weekly runs.

## 9. Risks / Tradeoffs
- Some fields are optional by design and may appear as null-heavy “patterns”; report is intended for admin review to decide exclusions.
- Restricting liabilities scan to likely-liability accounts (type `credit`/`loan` or `liability_details` present) trades completeness for signal/noise.

## 10. Follow-ups
Use checkboxes.

- [x] Run targeted and full test suite; update this log with commands/results
- [ ] Update `Commit(s)` once you instruct me to commit

## 11. Outcome
- `NullFieldDetectionJob` generates an institution-aware markdown report of null fields for holdings/transactions/liability-account fields.
- Job is scheduled weekly in production via Solid Queue recurring schedule.
- Full test suite is green.

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- `feat: add null field detection report job` — `34dd0c4`
- `chore: harden sap artifact prompt context` — `b5b7a60`

---
