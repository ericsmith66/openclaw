---

# Junie Task Log — PRD-1-01 Plaid Sync Completeness & Balance Assurance
Date: 2026-01-19  
Mode: Brave  
Branch: epic-1-Plaid-Sync-Integrity  
Owner: junie

## 1. Goal
- Ensure Plaid `/accounts/get` is called consistently to upsert account balances (`current_balance`, `available_balance`) and to record account-level sync status/timestamps, with warning-only logging for missing balances.

## 2. Context
- Source PRD: `knowledge_base/epics/nexgen/Epic-1/0010-PRD-1-01.md`
- Repo convention: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`
- Prior constraint agreed with stakeholder: “Active accounts” means Plaid-linked accounts; missing balances should be warning-only; job runs daily so we can rely on next run rather than an immediate retry loop for the new balances sync.

## 3. Plan
1. Inspect existing Plaid sync jobs/services and `Account` schema to understand current balance persistence.
2. Add missing DB fields needed by PRD-1-01 (`available_balance` + balance sync status/timestamps at account level).
3. Implement idempotent balances sync via Plaid `/accounts/get` (service + job), integrating into the existing daily sync flow.
4. Add warning-only logging for null balances on Plaid-linked accounts.
5. Add/adjust tests and run the full test suite to ensure it passes.

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- 2026-01-19: Located existing orchestration in `DailyPlaidSyncJob` and product-specific jobs.
- 2026-01-19: Verified `accounts.current_balance` already exists and is updated during holdings sync; identified remaining gaps for `available_balance` and account-level balance sync metadata.
- 2026-01-19: Added migration for `available_balance` + `balances_last_*` account-level sync metadata.
- 2026-01-19: Implemented `PlaidAccountsSyncService` calling Plaid `/accounts/get` to upsert accounts and balances (idempotent updates).
- 2026-01-19: Implemented `SyncAccountsJob` (no immediate retry loop) and wired it into `DailyPlaidSyncJob`.
- 2026-01-19: Added tests for service/job and updated daily sync job enqueue tests.
- 2026-01-19: Ran full test suite to confirm all tests pass.

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `app/jobs/daily_plaid_sync_job.rb` — enqueue `SyncAccountsJob` for stale Plaid items
- `app/jobs/sync_accounts_job.rb` — new job to sync balances via `/accounts/get` and record account-level sync status
- `app/services/plaid_accounts_sync_service.rb` — new service calling Plaid `/accounts/get` and upserting balances + sync metadata
- `db/migrate/20260119094500_add_balance_sync_fields_to_accounts.rb` — adds `available_balance` and `balances_last_*` columns
- `db/schema.rb` — updated schema after migration
- `test/jobs/daily_plaid_sync_job_test.rb` — updated expectations to include `SyncAccountsJob`
- `test/jobs/sync_accounts_job_test.rb` — new tests for the accounts sync job
- `test/services/plaid_accounts_sync_service_test.rb` — new tests for `/accounts/get` balance upsert + warning-only missing balances
- `knowledge_base/prds-junie-log/2026-01-19__prd-1-01-sync-balances.md` — task log (this file)

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.  
Use placeholders for any sensitive arguments.

- `ls knowledge_base/prds-junie-log | head` — listed existing task logs
- `bin/rails db:migrate` — ✅ migrated
- `bin/rails test test/services/plaid_accounts_sync_service_test.rb test/jobs/sync_accounts_job_test.rb test/jobs/daily_plaid_sync_job_test.rb` — ✅ pass
- `bin/rails test` — ✅ pass (full suite)

## 7. Tests
Record tests that were run and results.

- `bin/rails test test/services/plaid_accounts_sync_service_test.rb test/jobs/sync_accounts_job_test.rb test/jobs/daily_plaid_sync_job_test.rb` — ✅ pass
- `bin/rails test` — ✅ pass

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Decision: Implement a dedicated balances sync via Plaid `/accounts/get` (rather than relying only on investments endpoints).
    - Rationale: Ensures balances update even for Items without the investments product or when holdings sync is skipped.

## 9. Risks / Tradeoffs
- Some Plaid accounts/institutions may omit `available` (or even `current`) balances; we will log warnings rather than failing the sync.

## 10. Follow-ups
Use checkboxes.

- [x] Implement migrations + service/job for `/accounts/get` balance sync
- [x] Add tests and run full suite
- [x] Update this log with commit(s)

## 11. Outcome
- Plaid balances are now synced via Plaid `/accounts/get` and persisted to `accounts.current_balance` and `accounts.available_balance`.
- Each Plaid-linked account records balance sync attempt time/status in `balances_last_synced_at` / `balances_last_sync_status` / `balances_last_sync_error`.
- Missing balances are logged as warnings (warning-only; does not fail the sync).

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- `feat: sync Plaid account balances via /accounts/get` — `94694f4`

---
