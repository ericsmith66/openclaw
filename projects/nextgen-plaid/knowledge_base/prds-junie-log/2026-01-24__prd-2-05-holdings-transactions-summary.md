# Junie Task Log — PRD-2-05 Holdings & Transactions Summary
Date: 2026-01-24  
Mode: Brave  
Branch: feature/epic-2-financial-snapshots  
Owner: Junie

## 1. Goal
- Extend daily `FinancialSnapshot` JSON to include (1) a top holdings summary and (2) a monthly transaction summary for Epic 3 previews.

## 2. Context
- PRD reference: `knowledge_base/epics/wip/NextGen/Epic-2/0050-PRD-2-05.md`
- Dependencies: PRD-2-04 implemented (sector weights).
- Aggregation layer is `Reporting::DataProvider`; persistence layer is `FinancialSnapshotJob`.

## 3. Plan
1. Update `Reporting::DataProvider#top_holdings` to return top 10 holdings by value with `pct_portfolio`.
2. Update `Reporting::DataProvider#monthly_transaction_summary` to compute last-30-days income/expenses and top categories.
3. Persist both fields into `FinancialSnapshotJob` snapshot JSON.
4. Add/extend Minitest coverage for service + job.
5. Run targeted tests.
6. Update Epic implementation tracker and commit changes.

## 4. Work Log (Chronological)
- Updated `Reporting::DataProvider#top_holdings` to return PRD-2-05 structure: `[{ticker, name, value, pct_portfolio}]`, top 10 by `market_value`.
- Updated `Reporting::DataProvider#monthly_transaction_summary` to compute last-30-day `income` (sum of positive `amount`), `expenses` (absolute sum of negative `amount`), and `top_categories` (top 5 by absolute amount).
- Updated `FinancialSnapshotJob` to persist both `top_holdings` and `monthly_transaction_summary` into `FinancialSnapshot.data`.
- Extended Minitest coverage for both the provider and job.

## 5. Files Changed
- `app/services/reporting/data_provider.rb` — Implement PRD-2-05 `top_holdings` + `monthly_transaction_summary` shapes and calculations.
- `app/jobs/financial_snapshot_job.rb` — Persist `top_holdings` and `monthly_transaction_summary` into snapshot JSON.
- `test/services/reporting/data_provider_test.rb` — Add tests for PRD-2-05 holdings/transactions summary.
- `test/jobs/financial_snapshot_job_test.rb` — Assert snapshot persists PRD-2-05 fields.
- `knowledge_base/epics/wip/NextGen/Epic-2/0001-IMPLEMENTATION-STATUS.md` — Mark PRD-2-05 implemented (with verification command).

## 6. Commands Run
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` — ✅ pass

## 7. Tests
- `RAILS_ENV=test bin/rails test test/services/reporting/data_provider_test.rb test/jobs/financial_snapshot_job_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Compute top holdings from `Holding.market_value` (not `Position.current_value`).
  - Rationale: Epic 2 implementation already uses `Holding` for allocations and sector weights; maintaining a single holdings source keeps queries consistent and avoids introducing a parallel “positions” data source.
- Decision: Implement monthly transaction sign handling per PRD-2-05 (`income` uses positive amounts; `expenses` uses abs of negative amounts).
  - Rationale: Matches the PRD explicitly; UI can interpret/present the values without inferring sign.

## 9. Risks / Tradeoffs
- The app may contain legacy/Plaid-style sign conventions (positive outflow). PRD-2-05 uses the opposite.
  - Mitigation: Keep the summary output explicit and tested; revisit sign conventions globally if needed (or normalize at ingestion/UI).

## 10. Follow-ups
- [ ] Confirm expected transaction sign convention across Plaid ingestion + manual entry and align PRDs/UI if needed.

## 11. Outcome
- Daily snapshots now include `data['top_holdings']` (top 10 with `pct_portfolio`) and `data['monthly_transaction_summary']` (income/expenses/top categories).

## 12. Commit(s)
- `Implement PRD-2-05 holdings & transactions summary` — `527dfab`

## 13. Manual steps to verify and what user should see
1. In Rails console with a user that has holdings + transactions, run:
   - `FinancialSnapshotJob.perform_now(user)`
2. Inspect latest snapshot:
   - `snap = user.financial_snapshots.order(snapshot_at: :desc).first`
3. Expected:
   - `snap.data['top_holdings']` is an array (max 10), sorted descending by `value`, with each element containing `ticker`, `name`, `value`, `pct_portfolio`.
   - `snap.data['monthly_transaction_summary']` contains `income`, `expenses`, and `top_categories` (max 5) for the last 30 days.
