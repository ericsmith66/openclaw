# Junie Task Log — PRD-0160 Account + Transaction STI
Date: 2026-01-21  
Mode: Brave  
Branch: epic-1-Plaid-Sync-Integrity  
Owner: Junie

## 1. Goal
- Enable Rails STI on `Account` and `Transaction` per `knowledge_base/epics/nexgen/Epic-1/0160-PRD-1-10.md`, preserving Plaid raw type fields safely and ensuring the test suite remains green.

## 2. Context
- PRD: `knowledge_base/epics/nexgen/Epic-1/0160-PRD-1-10.md`
- Prior work: PRD-0150 completed and committed; PRD-0160 is next.
- Constraint: Account changes (0160.01) must land before Transaction changes (0160.02).

## 3. Plan
1. Run required greps for `account.type` usage and record results.
2. Implement PRD-0160.01:
   - Add `accounts.plaid_account_type` + index.
   - Backfill from existing `accounts.type` in batches.
   - Replace `account.type` usage in code/tests/views with `account.plaid_account_type`.
   - Remove STI disable from `Account` and add helper predicates.
   - Run migrations + tests; fix failures.
3. Implement PRD-0160.02:
   - Run required greps for `transaction.type` usage and record results.
   - Add transaction STI migrations/backfills with a fail-fast dependency check on `accounts.plaid_account_type`.
   - Update code/tests accordingly.
   - Run migrations + tests; fix failures.
4. Final verification: run a broader test suite, ensure only intended changes remain.

## 4. Work Log (Chronological)
- 2026-01-21: Created task log; opened PRD-0160 and confirmed `Account` currently disables STI via `self.inheritance_column = :_type_disabled`.
- 2026-01-21: Ran required greps for `account.type` usage (see Commands Run).

## 5. Files Changed
- `app/models/account.rb` — re-enabled STI (removed `inheritance_column` override), added `plaid_account_type` predicate helpers.
- `app/models/transaction.rb` — added STI `type` immutability validation and defaulted `type` to `RegularTransaction` on create.
- `app/models/investment_transaction.rb` — new STI subclass.
- `app/models/credit_transaction.rb` — new STI subclass.
- `app/models/regular_transaction.rb` — new STI subclass.
- `app/models/transaction_correction.rb` — new model for correction linkage.
- `app/services/plaid_accounts_sync_service.rb` — write/read `plaid_account_type` instead of `type`.
- `app/services/plaid_holdings_sync_service.rb` — write/read `plaid_account_type` instead of `type`.
- `app/services/csv_accounts_importer.rb` — write `plaid_account_type` instead of `type`.
- `app/services/csv_transactions_importer.rb` — use `plaid_account_type` for account selection and set STI `transactions.type` in bulk upserts.
- `app/controllers/admin/accounts_controller.rb` — permit `plaid_account_type`.
- `app/controllers/accounts_controller.rb` — permit `plaid_account_type`.
- `app/components/account_table_component.html.erb` — display `plaid_account_type`.
- `app/components/account_show_component.html.erb` — display `plaid_account_type`.
- `app/views/admin/accounts/index.html.erb` — table column uses `plaid_account_type`.
- `app/views/admin/accounts/show.html.erb` — display `plaid_account_type`.
- `db/migrate/20260121110000_add_plaid_account_type_to_accounts.rb` — add `accounts.plaid_account_type` + index.
- `db/migrate/20260121111000_backfill_plaid_account_type_on_accounts.rb` — backfill from legacy `accounts.type`.
- `db/migrate/20260121112000_clear_accounts_type_for_sti.rb` — clear legacy `accounts.type` to enable STI.
- `db/migrate/20260121120000_add_type_to_transactions.rb` — add `transactions.type` + index.
- `db/migrate/20260121121000_backfill_transaction_sti_type.rb` — backfill STI types with fail-fast checks.
- `db/migrate/20260121122000_make_transactions_type_not_null.rb` — enforce NOT NULL for STI.
- `db/migrate/20260121123000_create_transaction_corrections.rb` — add `transaction_corrections` table.
- `script/prd_0160_02_queries.rb` — helper to run pre-implementation distribution queries.
- Tests updated:
  - `test/jobs/sync_holdings_job_test.rb`
  - `test/jobs/sync_transactions_job_test.rb`
  - `test/jobs/sync_accounts_job_test.rb`
  - `test/jobs/null_field_detection_job_test.rb`
  - `test/models/transaction_test.rb`
  - `test/models/enriched_transaction_test.rb`
  - `test/models/plaid_item_test.rb`
  - `test/services/csv_accounts_importer_test.rb`
  - `test/services/csv_holdings_importer_test.rb`
  - `test/services/csv_transactions_importer_test.rb`
  - `test/services/plaid_holdings_sync_service_test.rb`
  - `test/controllers/mission_control_controller_test.rb`

## 6. Commands Run
- `grep -rn "\btype\b" app/ test/ | grep -i account | grep -v plaid_account_type | grep -v "type:" | grep -v "inheritance_column"` — found usages in:
  - `app/components/account_table_component.html.erb` (`account.type`)
  - `app/components/account_show_component.html.erb` (`@account.type`)
  - `app/views/admin/accounts/*` (`@account.type` and columns `:type`)
  - `app/controllers/admin/accounts_controller.rb` + `app/controllers/accounts_controller.rb` (strong params permit `:type`)
  - `app/services/plaid_accounts_sync_service.rb` + `app/services/plaid_holdings_sync_service.rb` (assigning `acc.type = plaid_account.type`)
  - `test/jobs/sync_holdings_job_test.rb` (asserting `account.type`)
  - `test/services/csv_accounts_importer_test.rb` (asserting `account.type`)
- `grep -rn "account\.type\|account\[:type\]\|account\[\"type\"\]\|account\['type'\]" app/ test/` — confirmed direct reads in views/components and tests; plus Plaid sync services.
- `bin/rails db:migrate` — ✅ applied PRD-0160.01 migrations in development (added `accounts.plaid_account_type`, backfilled, then cleared `accounts.type`).
- `bin/rails runner script/prd_0160_02_queries.rb` — ✅ ran PRD-0160.02 pre-implementation distribution queries.
- `bin/rails db:migrate RAILS_ENV=test` — ✅ pass (applied PRD-0160.01 + PRD-0160.02 migrations in test DB)
- `bundle exec rails test test/services/csv_transactions_importer_test.rb` — ✅ pass
- `bundle exec rails test test/jobs/sync_accounts_job_test.rb test/jobs/null_field_detection_job_test.rb` — ✅ pass
- `bundle exec rails test` — ✅ pass (571 runs)

## 7. Tests
- `bin/rails db:migrate RAILS_ENV=test` — ✅ pass
- `bundle exec rails test test/jobs/sync_holdings_job_test.rb test/jobs/sync_transactions_job_test.rb` — ✅ pass
- `bundle exec rails test test/services/csv_accounts_importer_test.rb test/services/csv_holdings_importer_test.rb test/services/csv_transactions_importer_test.rb` — ✅ pass
- `bundle exec rails test test/jobs/sync_accounts_job_test.rb test/jobs/null_field_detection_job_test.rb` — ✅ pass
- `bundle exec rails test` — ✅ pass (571 runs, 0 failures, 0 errors)

## PRD-0160.02 Pre-Implementation Query Results

```text
-- proposed_type distribution
[{"proposed_type"=>"CreditTransaction", "count"=>60, "percentage"=>0.76e0},
 {"proposed_type"=>"RegularTransaction", "count"=>47, "percentage"=>0.59e0},
 {"proposed_type"=>"InvestmentTransaction", "count"=>7824, "percentage"=>0.9865e2}]

-- ambiguous_count
[{"ambiguous_count"=>0, "percentage"=>0.0}]

-- orphaned_count
[{"orphaned_count"=>0}]

-- invalid_dividend_count
[{"invalid_dividend_count"=>0}]
```

## 8. Decisions & Rationale
- Decision: Follow PRD sequencing strictly (Account first, then Transaction).
    - Rationale: Transaction backfill depends on `accounts.plaid_account_type`.

## 9. Risks / Tradeoffs
- Risk: Enabling STI on `Account` repurposes `accounts.type`; any lingering `account.type` reads could change meaning or break filtering.
  - Mitigation: comprehensive grep + test coverage for all sync jobs that filter by account type.

## 10. Follow-ups
- [ ] Ensure VCR cassettes exist/updated for sync jobs across account types (credit/investment/depository).
- [ ] Verify no lingering `account.type` usage remains after refactor.

## 11. Outcome
- `Account` now uses STI safely by moving Plaid raw account type values into `accounts.plaid_account_type` and clearing legacy `accounts.type`.
- `Transaction` now uses STI via `transactions.type` with three initial subclasses (`InvestmentTransaction`, `CreditTransaction`, `RegularTransaction`) and a NOT NULL constraint.
- Added `transaction_corrections` persistence table + model.
- Updated sync/importers/controllers/views/tests to use `plaid_account_type` and ensured CSV transaction bulk upserts set STI `transactions.type`.
- Test suite is green.

## 12. Commit(s)
- Pending (awaiting review/approval)

---

## Manual Test Steps (Detailed)

### Account STI (PRD-0160.01)
1. Run migrations:
   - `bin/rails db:migrate`
   - Expected: `accounts.plaid_account_type` column exists and is backfilled (no NULLs).
2. Rails console verification:
   - `a = Account.first`
   - Expected: `a.plaid_account_type` contains previous raw Plaid type (e.g., `"credit"`, `"investment"`, `"depository"`).
   - Expected: `a.credit?`/`a.investment?`/`a.depository?` return booleans consistent with `plaid_account_type`.
3. Trigger sync paths (dev/test environment as appropriate):
   - Run jobs that filter by account type (at minimum): `SyncLiabilitiesJob`, `SyncTransactionsJob`, `SyncHoldingsJob`.
   - Expected: jobs complete without exceptions; filtering uses `plaid_account_type`.

### Transaction STI (PRD-0160.02)
1. Run migrations:
   - `bin/rails db:migrate`
   - Expected: transaction backfill refuses to run if `accounts.plaid_account_type` is missing.
2. Rails console verification:
   - Pick a few transactions and confirm their Ruby class matches STI mapping:
     - `t = Transaction.first; t.class.name`
   - Expected: class is a Transaction subclass per PRD mapping (or `Transaction` where appropriate).
3. Run transaction sync job:
   - `SyncTransactionsJob.perform_now(<plaid_item_id>)` (in an environment with stubbed/VCR Plaid calls)
   - Expected: transactions are created/updated with correct subclass `type` values; no STI errors.
