# Junie Task Log — PRD-1-05.5 Complete Field Mapping + Daily Balance Snapshots + Enrichment Denormalization
Date: 2026-01-19  
Mode: Brave  
Branch: feature/prd-1-05-5-complete-field-mapping  
Owner: eric/junie

## 1. Goal
- Ensure we persist Plaid fields currently dropped (accounts/transactions/holdings), create daily account balance snapshots, and denormalize enrichment data onto `transactions` while keeping the legacy `enriched_transactions` table for now.

## 2. Context
- PRD: `knowledge_base/epics/nexgen/Epic-1/0055-PRD-1-05-5.md`
- Epic overview: `knowledge_base/epics/nexgen/Epic-1/0000.overview-epic-1.md`
- Constraints/decisions confirmed:
  - Use `transactions.investment_type` (not `transactions.type`) to avoid Rails STI.
  - No backfill for `AccountBalanceSnapshot`.
  - Migrate enrichment data back to `transactions` now; drop `enriched_transactions` later in a follow-up.

## 3. Plan
1. Add missing columns + indexes (accounts/transactions/holdings) and create `account_balance_snapshots`.
2. Update sync services to populate new fields and create daily snapshots on sync.
3. Denormalize enrichment: write/maintain enrichment data on `transactions` and migrate existing `enriched_transactions` fields back.
4. Extend null-field reporting to cover the new columns and add snapshot health signals.
5. Add/update tests and run `bin/rails test` to green.

## 4. Work Log (Chronological)
- 2026-01-19: Created task log; reviewed PRD + existing schema/services/tests; confirmed rollout decisions (no STI column `type`, no snapshot backfill, defer dropping `enriched_transactions`).

## 5. Files Changed
- `db/migrate/20260119160000_add_missing_plaid_fields_to_accounts.rb`
- `db/migrate/20260119160010_add_missing_plaid_fields_to_transactions.rb`
- `db/migrate/20260119160020_add_missing_plaid_fields_to_holdings.rb`
- `db/migrate/20260119160030_create_account_balance_snapshots.rb`
- `db/migrate/20260119160040_migrate_enriched_transactions_back_to_transactions.rb`
- `db/migrate/20260119170000_add_personal_finance_category_to_transactions.rb`
- `db/migrate/20260119170010_backfill_transactions_personal_finance_category_from_enriched_transactions.rb`
- `db/migrate/20260119171000_rename_transactions_personal_finance_category_to_label.rb`
- `app/models/account.rb`
- `app/models/account_balance_snapshot.rb`
- `app/services/plaid_accounts_sync_service.rb`
- `app/services/plaid_holdings_sync_service.rb`
- `app/services/plaid_transaction_sync_service.rb`
- `app/jobs/sync_transactions_job.rb`
- `app/jobs/null_field_detection_job.rb`
- `test/jobs/sync_transactions_job_test.rb`
- `test/jobs/null_field_detection_job_test.rb`
- `db/schema.rb`

## 6. Commands Run
- `bin/rails db:migrate`
- `bin/rails test test/jobs/null_field_detection_job_test.rb test/jobs/sync_transactions_job_test.rb`
- `bin/rails test`

## 7. Tests
- ✅ `bin/rails test test/jobs/null_field_detection_job_test.rb test/jobs/sync_transactions_job_test.rb`
- ✅ `bin/rails test`
  - Result: `554 runs, 1850 assertions, 0 failures, 0 errors, 18 skips`

## 8. Decisions & Rationale
- Decision: Use `transactions.investment_type` instead of `transactions.type`.
  - Rationale: Avoid Rails STI behavior (YAGNI).
  - Alternatives considered: Disable STI via `inheritance_column`.
- Decision: No snapshot backfill.
  - Rationale: Keep implementation simple; snapshots begin on next sync.
- Decision: Migrate enrichment data back now but keep `enriched_transactions` until later.
  - Rationale: Safer rollout; allows follow-up deploy to drop table after confidence.

## 9. Risks / Tradeoffs
- Risk: Sync services/tests may still rely on `enriched_transactions`; need to keep compatibility until follow-up.
- Risk: New columns may require VCR cassette updates if tests assert full payload mapping.

## 10. Follow-ups
- [ ] Drop `enriched_transactions` table/model after a deploy cycle and after confirming no remaining references.
- [ ] Consider adding a dedicated snapshot health job if null-field job becomes too broad.

## 11. Outcome
- Implemented PRD-1-05.5 core deliverables:
  - Persist missing Plaid fields for `accounts`, `transactions` (investment), and `holdings`.
  - Added `AccountBalanceSnapshot` and created an upsert path for daily snapshots on accounts sync.
  - Denormalized Plaid enrichment fields onto `transactions` (legacy `enriched_transactions` retained for now) and added a data migration to copy existing values back.
  - Added `transactions.personal_finance_category_label` (denormalized string) and backfilled it from `enriched_transactions.personal_finance_category`.
  - Extended `NullFieldDetectionJob` to include Accounts + Balance Snapshots sections.

## 13. Manual Test Steps
1. Run accounts sync and confirm account fields + snapshot:
   - `PlaidAccountsSyncService.new(item).sync`
   - Verify `AccountBalanceSnapshot.where(account: ...).order(snapshot_date: :desc).first` exists for today.
2. Run transactions sync with enrichment enabled:
   - Set `PLAID_ENRICH_ENABLED=true`
   - Run `PlaidTransactionSyncService.new(item).sync`
   - Verify `transactions.logo_url`, `transactions.website`, `transactions.merchant_name`, `personal_finance_category_confidence_level`, and `personal_finance_category_label` are populated.
3. Run holdings sync and confirm new security fields:
   - `PlaidHoldingsSyncService.new(item).sync`
   - Verify holdings have `ticker_symbol`, `close_price`, `market_identifier_code`, etc.
4. Generate null field report:
   - `NullFieldDetectionJob.perform_now`
   - Inspect `knowledge_base/schemas/null_fields_report.md` for Accounts + Balance Snapshots sections.

## 12. Commit(s)
- Pending
