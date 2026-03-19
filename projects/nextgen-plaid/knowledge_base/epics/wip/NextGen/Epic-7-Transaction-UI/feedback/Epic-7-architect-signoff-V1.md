# Epic-7 Architect Sign-Off — Φ5/Φ6 Cycle V1

**Reviewer:** Architect Agent  
**Date:** February 20, 2026  
**Cycle:** V1 (Feedback V1 → Response V1)  
**Phase:** Φ5/Φ6 Assessment  

---

## Resolution Status

### Questions — All Answered ✅

| # | Topic | Status | Notes |
|---|-------|--------|-------|
| Q1 | Epic-6 mock data state | ✅ Resolved | Remove entirely in PRD-7.1. Clear, no ambiguity. |
| Q2 | User scoping | ✅ Resolved | Join-based scoping in data provider. Verified `Account` has `investment?`/`credit?` helpers and `plaid_account_type` field. |
| Q3 | Transfer definition | ✅ Resolved | `personal_finance_category_label LIKE 'TRANSFER%'` primary, investment accounts excluded. Dedup logic defined. DB analysis confirmed 483 transfer-categorized rows. |
| Q4 | Recurring detection | ✅ Resolved | Plaid `RecurringTransaction` model (already synced) as primary. No new schema changes. |
| Q5 | STI Fix | ✅ Resolved | Account-type-driven reclassification in sync service. One-time rake backfill outside PRD scope. Verified sync service (`PlaidTransactionSyncService#process_added`) currently has no STI logic — uses `create_or_find_by!` which triggers `default_sti_type` → `RegularTransaction` for all rows. |
| Q6 | SavedAccountFilter | ✅ Resolved | Generic path_helper param. No new component needed. |

### Suggestions — All Accepted ✅

| # | Topic | Status |
|---|-------|--------|
| S1 | TransactionGridDataProvider | ✅ Accepted — cornerstone service |
| S2 | Composite index | ✅ Accepted — in first PRD |
| S3 | Leverage Epic-6 components | ✅ Accepted — enhance, not rebuild |
| S4 | Merge PRD-7.3 + 7.4 | ✅ Accepted — 5 PRDs total |
| S5 | Fix filename typo | ✅ Accepted |

### Objections — All Resolved ✅

| # | Topic | Status | Architect Assessment |
|---|-------|--------|---------------------|
| O1 | PRDs not expanded | ✅ Returning to Φ4 | Correct action. Full expansion required before Φ7. |
| O2 | PRD-7.1 was a plan, not feature | ✅ Reframed | "Data Provider & Controller Wiring" — concrete deliverable. Good. |
| O3 | RSpec references | ✅ Fixed | Minitest + Capybara exclusively. |
| O4 | No user scoping | ✅ Addressed | Enforced at service level via join. Verified `plaid_items.user_id` is indexed. |
| O5 | Dependency chain inverted | ✅ Reordered | Foundation first. Revised 5-PRD chain is sound. |
| O6 | Mock removal undefined | ✅ Added to PRD-7.1 AC | Explicit deletion of flag, provider, helper, YAMLs. |
| O7 | Missing Error Scenarios | ✅ Committed | Will add to every PRD in Φ4 expansion. |

---

## Architect Verification Notes

Codebase checks performed during review:

1. **`PlaidTransactionSyncService`** (lines 72-89): Confirmed no STI type logic — `create_or_find_by!(transaction_id:, source: "plaid")` triggers `default_sti_type` callback which sets all to `RegularTransaction`. Eric's proposed fix (account-type check post-save) is the correct approach.

2. **`Account` model**: Confirmed `investment?`, `credit?`, `depository?` helpers exist based on `plaid_account_type` field. Ready for STI reclassification logic.

3. **`RecurringTransaction` model**: Exists with `belongs_to :plaid_item`, `stream_id` uniqueness. Viable as primary recurring data source (Plaid-authoritative).

4. **Database indexes**: Transactions table has individual indexes on `type`, `account_id`, `subtype`, `security_id`, `personal_finance_category_label` but **no composite index** for the primary query pattern. The proposed `[:type, :account_id, :date]` composite index is confirmed as needed.

5. **Transaction count**: 13,332 rows, all `RegularTransaction`. Subtype breakdown shows ~73% investment-related (buy/sell/interest/dividend), ~22% NULL/empty (likely depository), ~3% transfer. STI reclassification will redistribute ~9,500+ rows to `InvestmentTransaction`.

---

## Remaining Concerns — RESOLVED (Feb 20, 2026 — Eric+Grok Follow-Up)

### RC1: STI reclassification for CreditTransaction ✅ RESOLVED
**Eric's resolution:** Mirror the InvestmentTransaction rule symmetrically:
```ruby
if transaction.account&.credit? && transaction.type == "RegularTransaction"
  transaction.update_column(:type, "CreditTransaction")
end
```
**Architect verification:** ✅ Confirmed `Account#credit?` exists (`plaid_account_type == "credit"`). Both rules use `update_column` which correctly bypasses the `type_immutable` validation (PRD-0160.02) that prevents `type` changes via normal `.update`. Both rules go in the same sync service method. Locked in for PRD-7.1 acceptance criteria.

### RC2: Rake backfill in PRD-7.1 scope ✅ RESOLVED
**Eric's resolution:** Include `rake transactions:backfill_sti_types` in PRD-7.1 scope. Idempotent, batch-processed, manual human step post-deploy.
**Architect verification:** ✅ Approach is sound. `Transaction.find_in_batches` correctly respects `default_scope { where(deleted_at: nil) }` — soft-deleted rows are excluded (desired). Rake task pattern is consistent with existing `lib/tasks/` structure (16 existing rake files). Using `update_column` bypasses `type_immutable` validation correctly. PRD-7.1 AC should include: "After backfill, `InvestmentTransaction.count > 0` and `CreditTransaction.count > 0` (if credit accounts exist)."

### RC3: Transfer dedup matching key ✅ RESOLVED
**Eric's resolution:** Full matching key defined (date ±1 day, opposite sign, abs amount within 1%, counterparty similarity). 7 edge cases specified for test coverage. Prefer outbound/negative leg as canonical.
**Architect verification:** ✅ Logic is well-specified. One minor correction needed: Eric's response references `spec/services/transfer_deduplicator_spec.rb` — this must be `test/services/transfer_deduplicator_test.rb` (Minitest, not RSpec — project has no `spec/` directory). Edge case coverage is thorough. Locked in for PRD-7.3 test cases.

---

## Decision

**✅ Φ5/Φ6 Cycle V1 FULLY COMPLETE — All objections, questions, and remaining concerns resolved.**

- 7/7 objections resolved
- 6/6 questions answered
- 5/5 suggestions accepted
- 3/3 remaining concerns resolved (RC1-RC3 follow-up, Feb 20)

**No further Φ5/Φ6 cycles required.** All architectural decisions are locked in.

**Next Step:** Eric + High-Reasoning AI proceed to **Φ4 full expansion** — produce the consolidated epic document with all 5 PRDs (complete template sections including Error Scenarios, Manual Testing Steps, Dependencies, etc.), incorporating all locked-in decisions from this cycle. Once complete, the Architect will perform a **brief Φ5 V2 review** focused on template compliance only (not re-litigating decisions) before Φ7 breakout proceeds.

---

## Revised PRD Structure (Locked In)

```
PRD-7.1: Transaction Grid Data Provider & Controller Wiring
         (mock removal, user scoping, data provider service, indexes, STI fix in sync)
  → PRD-7.2: Global Account Filter & Filter Bar Refinements
             (SavedAccountFilter generic reuse, Turbo filter updates)
    → PRD-7.3: Type-Specific View Enhancements & Transfers Deduplication
               (Cash/Credit/Investment view polish, transfer dedup logic, badges)
      → PRD-7.4: Summary View & Recurring Section
                 (aggregated summary, RecurringTransaction integration, top expenses)
        → PRD-7.5: Performance Tuning & STI Cleanup
                   (query optimization, N+1 detection, caching, backfill verification)
```
