# Epic-7 Architect Review — Feedback V1

**Reviewer:** Architect Agent  
**Date:** February 20, 2026  
**Input Document:** `Epic-7-Transactions-UI-Implementaion.md`  
**Phase:** Φ5 — Architect Review  

---

## Executive Summary

Epic-7 has a clear goal: replace mock transaction data with live Plaid-synced queries and polish the five transaction views. The direction is sound and well-scoped. However, the consolidated document has **significant structural gaps** relative to the Φ4 template requirements (RULES.md Part 2, Φ4). Only PRD-7.1 is partially expanded; PRDs 7.2–7.6 are missing entirely. Additionally, several architectural decisions need clarification before implementation planning can proceed.

---

## Questions

### Q1: What is the current state of Epic-6 mock data?

The `TransactionsController` currently has a `USE_MOCK_DATA` flag defaulting to `true`, and the `else` branches in every action (regular, investment, credit, transfers, summary) **duplicate the mock data path identically**. Is Epic-6 considered complete? Should Epic-7's first task be removing the mock data path entirely, or should the flag remain as a fallback during development?

### Q2: User scoping for transactions

The current `TransactionsController#index` action queries `Transaction.includes(:account)` with **no user scoping**. The epic mentions "Use existing auth/RLS" but the controller has no `current_user` scoping. Holdings uses `current_user.holdings` via the data provider. How should transactions be scoped — via `current_user.plaid_items.flat_map(&:accounts).flat_map(&:transactions)` or a more efficient join? This is a security-critical gap that must be addressed in the plan.

### Q3: What defines a "transfer" transaction? *(PARTIALLY ANSWERED — data analysis below)*

The epic mentions "transfers deduplication (prefer source leg)" but doesn't define how transfers are identified in the live data. The mock data has a dedicated `transfers.yml` file. In the real Transaction model, there is no `type: 'TransferTransaction'` STI subclass.

**Database analysis (Feb 20, 2026):** The live data has two transfer signals:
- **`subtype = 'transfer'`** → 357 rows
- **`personal_finance_category_label LIKE 'TRANSFER%'`** → 483 rows with rich subcategories (TRANSFER_IN_ACCOUNT_TRANSFER: 233, TRANSFER_OUT_ACCOUNT_TRANSFER: 97, TRANSFER_OUT_FROM_APPS: 67, TRANSFER_OUT_WITHDRAWAL: 49, etc.)

**Architect recommendation:** Use `personal_finance_category_label LIKE 'TRANSFER%'` as primary filter — it's Plaid-classified, richer (483 vs 357 rows), and provides IN/OUT direction needed for deduplication. The `subtype` field can be a secondary signal. The deduplication logic should match TRANSFER_IN + TRANSFER_OUT pairs by amount/date/account for internal transfers.

**Remaining question for Eric:** Should all TRANSFER-prefixed categories be shown in the transfers view, or should withdrawals/deposits that happen to be categorized as transfers be excluded (e.g., only show ACCOUNT_TRANSFER subtypes)?

### Q4: Recurring detection — database vs. in-memory?

`TransactionRecurringDetector` currently works on in-memory collections (OpenStruct arrays from mock data). For live data with potentially thousands of transactions, should this:
- Continue as in-memory detection on paginated results (loses cross-page detection)?
- Become a batch job that sets a `recurring` flag on Transaction records?
- Use Plaid's recurring transaction API (`/transactions/recurring/get`) which is already synced to `RecurringTransaction` model?

### Q5: What is "STI Fix" in PRD-7.6? *(PARTIALLY ANSWERED — data analysis below)*

The backlog table lists "STI Fix" under PRD-7.6. The current Transaction model already has `default_sti_type` setting `RegularTransaction`, and there's a `type NOT NULL` constraint.

**Database analysis (Feb 20, 2026):** All 13,332 transactions are `RegularTransaction`. Zero rows exist for `InvestmentTransaction` or `CreditTransaction` despite the data clearly containing investment transactions (3,892 buys, 2,759 sells, 2,459 interest, 405 dividends) and likely credit transactions. The `default_sti_type` callback sets everything to `RegularTransaction` and the sync service never reclassifies.

**Architect assessment:** The "STI Fix" is confirmed as **post-sync reclassification**. This is a foundational concern — if views filter by `type: 'InvestmentTransaction'`, they'll get zero results with current data. This must be addressed **early** (not in the final PRD-7.6) via either:
1. A migration/backfill that reclassifies existing rows based on `subtype` (buy/sell/dividend → InvestmentTransaction) or account type
2. Updating `PlaidTransactionSyncService` to set the correct STI type at sync time
3. Both (backfill + fix forward)

**Remaining question for Eric:** What is the reclassification rule? Options:
- **By subtype:** buy/sell/dividend/interest/split/etc. → `InvestmentTransaction`; all others → `RegularTransaction` (no credit signal in current data)
- **By account type:** If `account.type == 'investment'` → `InvestmentTransaction`; if `account.subtype == 'credit card'` → `CreditTransaction`
- **Hybrid:** Account type as primary, subtype as secondary override

### Q6: SavedAccountFilter reuse — which path_helper?

The `SavedAccountFilterSelectorComponent` currently uses `holdings_path_helper` parameter (defaulting to `:net_worth_holdings_path`). For transactions, this needs to point to transaction routes. Is the intent to make this component fully generic (accepting any path helper), or to create a transaction-specific variant?

---

## Suggestions

### S1: Create a `TransactionGridDataProvider` service (like `HoldingsGridDataProvider`)

The `HoldingsGridDataProvider` is a well-structured service object (574 lines) that handles user scoping, pagination, sorting, filtering, grouping, snapshot mode, and saved account filters — all returning a clean `Result` struct. **Strongly recommend** creating an analogous `TransactionGridDataProvider` to:
- Encapsulate user-scoped queries with proper joins
- Handle STI type filtering
- Handle pagination, sorting, date ranges, and amount filters
- Return `Result` struct with transactions, summary stats, and total_count
- Keep the controller thin (single-line delegation like Holdings does)

This would replace the current `process_mock_transactions` method which does sorting/pagination/filtering in-memory on mock data.

### S2: Add composite index on `[type, account_id, date]`

The epic correctly identifies query performance as a risk. The schema currently has individual indexes on `type`, `account_id`, and `subtype` but **no composite index** for the most common query pattern: `Transaction.where(type: X).where(account_id: [ids]).order(date: :desc)`. Add:
```sql
add_index :transactions, [:type, :account_id, :date], name: "idx_transactions_type_account_date"
```

### S3: Leverage existing `Transactions::GridComponent` and `Transactions::RowComponent`

Epic-6 already created rich transaction-specific components (`Transactions::GridComponent`, `Transactions::RowComponent`, `Transactions::FilterBarComponent`, `Transactions::SummaryCardComponent`, `Transactions::MonthlyGroupComponent`). These follow the `Portfolio::HoldingsGridComponent` pattern and support investment columns, transfer arrows, recurring badges, etc. The epic should explicitly acknowledge this existing infrastructure and scope PRDs as **enhancement/live-data wiring** rather than creating new components from scratch.

### S4: Consider combining PRD-7.3 and PRD-7.4

PRD-7.3 (Type-Specific View Polish for Cash, Credit, Investments) and PRD-7.4 (Transfers View & Deduplication) are both about type-specific view enhancements. The deduplication logic is the only unique piece in PRD-7.4. Consider combining them into a single PRD with deduplication as a sub-requirement, reducing epic overhead from 6 PRDs to 5.

### S5: Rename the epic document file

The current filename has a typo: `Epic-7-Transactions-UI-Implementaion.md` (missing 't' in Implementation). Should be corrected before Φ7 breakout.

---

## Objections

### O1: **CRITICAL — PRDs 7.2–7.6 are not expanded** (violates Φ4 rules)

**The Problem:** RULES.md Φ4 requires the consolidated document to include **all PRDs fully detailed** with: Overview, User Story, Functional Requirements, Non-Functional Requirements, Architectural Context, Acceptance Criteria, Test Cases, Manual Testing Steps, Dependencies (Blocked By / Blocks), and Error Scenarios & Fallbacks. Currently, only PRD-7.1 has partial expansion (missing User Story, Error Scenarios, Manual Testing Steps, Dependencies section). PRDs 7.2–7.6 exist only as one-line entries in the backlog table.

**Solution:** Before this review can be considered complete and before Φ7 (PRD breakout) can proceed, the consolidated document needs full expansion of all 6 PRDs using the PRD template sections. This is the responsibility of Eric + High-Reasoning AI (Φ4 actors). Return the document to Φ4 for completion.

### O2: **PRD-7.1 is a planning document, not a feature PRD** (architectural concern)

**The Problem:** PRD-7.1 "Architectural Alignment & Implementation Plan" is essentially asking the Coding Agent to create an implementation plan — which is **Φ8's responsibility**, not a PRD deliverable. A PRD defines WHAT to build (user-facing feature), not HOW to build it. Having a "plan PRD" conflates the planning phase with a deliverable and creates confusion about what "done" means for PRD-7.1.

**Solution:** Remove PRD-7.1 from the backlog. The architectural alignment work it describes should be the **implementation plan document** (Φ8) that the Coding Agent produces after PRD breakout. The "Key Decisions Locked In" section of the epic overview should capture the alignment decisions. Renumber remaining PRDs to 7.1–7.5. If the intent is to have a foundational "data provider wiring" PRD, reframe it as: "PRD-7.1: Transaction Data Provider & Controller Wiring" — a concrete deliverable that replaces mock data with live queries.

### O3: **Test cases reference RSpec — project uses Minitest** (violates guidelines)

**The Problem:** PRD-7.1's test cases section states "RSpec: Controller scopes return expected records with account filter." The project's `.junie/guidelines.md` and established patterns use **Minitest**, not RSpec. This is a direct contradiction.

**Solution:** Replace all RSpec references with Minitest. Test cases should read: "Minitest: Controller integration tests verify scoped queries return expected records with account filter applied." Ensure all PRDs when expanded specify Minitest for unit/integration tests and Capybara + Minitest for system tests.

### O4: **No user scoping in controller — security risk**

**The Problem:** The current `TransactionsController` has no `authenticate_user!` before_action on the type-specific actions (regular, investment, credit, transfers, summary), and the `index` action queries `Transaction.includes(:account)` without any user scope. If Epic-7 switches to live data without adding user scoping, **any authenticated user could see all transactions in the system** (assuming `authenticate_user!` is added but user-scoping is missed). Even with PostgreSQL RLS, the application layer should enforce scoping.

**Solution:** Every PRD must include as a non-functional requirement: "All queries must be scoped to `current_user` through the Account → PlaidItem → User association chain." The data provider service (S1) should enforce this at the service level, making it impossible to accidentally query unscoped data. Specifically:
```ruby
Transaction.joins(account: :plaid_item)
           .where(plaid_items: { user_id: current_user.id })
```

### O5: **Dependency chain has PRD-7.6 (performance) last — should be earlier**

**The Problem:** PRD-7.6 (Live Data Optimizations — STI Fix, Pagination, Sorting) is listed as the last PRD with dependency on PRD-7.5. However, performance optimizations (composite indexes, proper database pagination via `page`/`per` with Kaminari, server-side sorting) should be in place **before** building all the views on top of live data. Building 4 view PRDs on top of in-memory pagination (current mock data approach) and then optimizing last means potentially reworking all views.

**Solution:** Split PRD-7.6 into two concerns:
1. **Foundation (move to PRD-7.1 or new PRD-7.2):** Database indexes, user-scoped queries, Kaminari/Pagy pagination on ActiveRecord relations, server-side sorting via `ORDER BY`. This is the data provider service — it must exist before any view PRD.
2. **Late-stage optimization (keep as final PRD):** STI reclassification fix (if needed), query tuning, N+1 detection, caching.

The revised dependency chain would be:
```
PRD-7.1: Data Provider & Controller Wiring (indexes, scoping, pagination)
  → PRD-7.2: Global Account Filter & Filter Bar (builds on data provider)
    → PRD-7.3: Type-Specific View Polish (Cash, Credit, Investments)
    → PRD-7.4: Transfers View & Deduplication
      → PRD-7.5: Summary View & Recurring Section
        → PRD-7.6: Performance Tuning & STI Cleanup
```

### O6: **Mock data removal strategy not defined**

**The Problem:** The epic overview says "No mocks—YAML/provider layer skipped since live sync is functional" but the current controller **defaults to mock data** (`USE_MOCK_DATA = true`). There's no PRD that explicitly covers removing `MockTransactionDataProvider`, the YAML files, the `USE_MOCK_DATA` flag, and the in-memory `process_mock_transactions` helper. Leaving this undefined risks mock code persisting in production.

**Solution:** The first implementation PRD (data provider wiring) must include as an acceptance criterion: "The `USE_MOCK_DATA` flag, `MockTransactionDataProvider` service, `process_mock_transactions` helper, and `config/mock_transactions/*.yml` files are removed or deprecated behind a clearly-marked cleanup TODO. All controller actions use live database queries exclusively."

### O7: **Missing Error Scenarios across all PRDs**

**The Problem:** The Φ4 template requires Error Scenarios & Fallbacks for each PRD. PRD-7.1 has none. Key error scenarios for transaction views include:
- Account with no synced transactions → empty state
- Plaid sync in progress → stale data indicator
- Transaction deleted upstream (Plaid soft-delete via `deleted_at`) → handle gracefully
- Database timeout on large transaction sets → pagination/limit guard
- Invalid filter params → safe defaults

**Solution:** Each expanded PRD must include an Error Scenarios section. At minimum, the epic overview should list global error patterns that all PRDs inherit.

---

## Summary of Required Actions

| # | Type | Action | Responsible |
|---|------|--------|-------------|
| 1 | Objection | Expand PRDs 7.2–7.6 with full template sections | Eric + High-Reasoning AI (Φ4) |
| 2 | Objection | Remove or reframe PRD-7.1 as a concrete deliverable | Eric + High-Reasoning AI (Φ4) |
| 3 | Objection | Replace RSpec references with Minitest | Eric + High-Reasoning AI (Φ4) |
| 4 | Objection | Add user-scoping requirement to all PRDs | Eric + High-Reasoning AI (Φ4) |
| 5 | Objection | Reorder dependency chain (foundation first) | Eric + High-Reasoning AI (Φ4) |
| 6 | Objection | Define mock data removal in acceptance criteria | Eric + High-Reasoning AI (Φ4) |
| 7 | Objection | Add Error Scenarios to all PRDs | Eric + High-Reasoning AI (Φ4) |
| 8 | Question | Clarify Q1–Q6 (transfer definition, recurring strategy, STI fix, etc.) | Eric |
| 9 | Suggestion | Create TransactionGridDataProvider service | Coding Agent (Φ8) |
| 10 | Suggestion | Add composite database index | Coding Agent (Φ8) |
| 11 | Suggestion | Fix filename typo | Anyone |

**Recommendation:** Return to Φ4 for expansion. The epic direction is excellent; the document just needs to be fully fleshed out before Φ7 breakout can proceed.
