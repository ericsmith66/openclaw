# Epic-7 Feedback Response — V1

**Respondents:** Eric + Grok (High-Reasoning AI)  
**Date:** February 20, 2026  
**In Response To:** `Epic-7-feedback-V1.md` (Architect Agent, Φ5)  
**Phase:** Φ6 — Feedback Response  

---

## Executive Summary Response

> Agreed — the initial doc was a lightweight scaffold to capture direction quickly while live views are already rendering. Full Φ4-compliant expansion (all PRDs with complete sections) will be done before next hand-off.

---

## Questions

### Q1: Epic-6 mock data state
**Response:** Epic-6 complete for original scope. **Remove mock path completely** as step #1 of Epic-7. Delete `USE_MOCK_DATA` flag, `MockTransactionDataProvider`, `process_mock_transactions` helper, and `config/mock_transactions/*.yml`. No fallback needed — live sync is reliable.

### Q2: User scoping
**Response:** Critical gap acknowledged. Use efficient join:
```ruby
Transaction.joins(account: :plaid_item)
           .where(plaid_items: { user_id: current_user.id })
```
Enforced in `TransactionGridDataProvider` so controllers cannot leak unscoped data.

### Q3: Transfer definition
**Response:** Prioritized matching in `TransferDeduplicator` service:
1. **Primary:** `personal_finance_category.primary == "TRANSFER"` OR `detailed.start_with?("TRANSFER_")`
2. **Hint:** `subtype.in?(%w[transfer deposit withdrawal])`
3. **Exclusion:** Skip if `account.plaid_account_type == "investment"` (internal portfolio activity)
4. **Deduplication:** Match legs by near-identical date (±1 day), opposite sign, similar absolute amount. Prefer outbound/negative as canonical. Unmatched externals get "External" badge.

### Q4: Recurring detection
**Response:** Primary: **Use Plaid's `/transactions/recurring/get`** (already synced to `RecurringTransaction` model). Fallback: page-only in-memory heuristic for display badges only. No new batch job or `recurring` flag on Transaction table.

### Q5: STI Fix
**Response:** Post-sync reclassification. Fix in sync service:
```ruby
if transaction.account&.investment? && transaction.type == "RegularTransaction"
  transaction.update_column(:type, "InvestmentTransaction")
end
```
One-time rake task for legacy data (outside PRD scope).

### Q6: SavedAccountFilter reuse
**Response:** Make component **fully generic** — pass appropriate path helper as param. No transaction-specific variant needed.

---

## Suggestions

| # | Response |
|---|----------|
| S1 | **Strongly agree** — `TransactionGridDataProvider` becomes cornerstone, mirroring holdings provider. |
| S2 | **Yes** — add composite index `[:type, :account_id, :date]` in first wiring PRD. |
| S3 | **Correct** — PRDs scoped as enhance + wire to live data, not create from scratch. |
| S4 | **Agreed** — merge PRD-7.3 and PRD-7.4 into single PRD. Reduces to 5 PRDs. |
| S5 | **Fixed** — filename typo will be corrected. |

---

## Objections

| # | Response |
|---|----------|
| O1 | **Acknowledged** — returning to Φ4 for full expansion of all PRDs. |
| O2 | **Valid** — reframed as "PRD-7.1: Transaction Grid Data Provider & Controller Wiring". |
| O3 | **Fixed** — all test references updated to Minitest + Capybara. |
| O4 | **Critical, addressed** — explicit NF requirement in every PRD for `current_user` scoping via join. |
| O5 | **Agreed** — revised dependency chain: 7.1 (Data Provider) → 7.2 (Account Filter) → 7.3 (Views + Transfers) → 7.4 (Summary + Recurring) → 7.5 (Performance + Cleanup). |
| O6 | **Added** — mock removal in PRD-7.1 acceptance criteria. |
| O7 | **Will add** — Error Scenarios & Fallbacks section in every PRD. |

---

## Decisions Locked In

1. **Mock data removal:** Complete deletion in PRD-7.1, no fallback
2. **User scoping:** Via `joins(account: :plaid_item).where(plaid_items: { user_id: current_user.id })`
3. **Transfer definition:** `personal_finance_category_label LIKE 'TRANSFER%'` primary, exclude investment accounts
4. **Recurring detection:** Plaid `RecurringTransaction` model primary, in-memory heuristic fallback (display only)
5. **STI reclassification:** Account-type driven (`account.investment?` → `InvestmentTransaction`, `account.credit?` → `CreditTransaction`)
6. **SavedAccountFilter:** Generic path_helper param, no duplication
7. **Test framework:** Minitest + Capybara exclusively
8. **PRD count:** 5 PRDs (merged 7.3+7.4), renumbered
9. **Dependency order:** Foundation first (data provider, indexes, scoping), views second, optimization last
10. **Composite index:** `[:type, :account_id, :date]` added in first PRD
11. **CreditTransaction reclassification:** Mirror investment rule — `account.credit?` → `CreditTransaction` in same sync hook
12. **STI backfill rake task:** In PRD-7.1 scope — `rake transactions:backfill_sti_types`, idempotent, manual post-deploy step
13. **Transfer dedup matching key:** date ±1 day, opposite sign, abs amount within 1%, prefer outbound leg. 7 edge cases defined for test coverage.
14. **Test file paths:** `test/services/` (Minitest), never `spec/` (no RSpec in project)
