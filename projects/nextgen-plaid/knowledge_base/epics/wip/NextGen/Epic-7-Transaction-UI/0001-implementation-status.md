# Epic 7: Implementation Status

**Epic**: Real Transaction Views Implementation
**Status**: Not Started
**Last Updated**: 2026-02-20

---

## Overview

Track completion status, blockers, key decisions, and branch merges for Epic 7 PRDs.

Update this document after each PRD completion per `.junie/guidelines.md`.

---

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Completion Date | QA Score | Notes |
|-----|-------|--------|--------|--------|-----------------|----------|-------|
| 7-01 | Transaction Grid Data Provider & Controller Wiring | Not Started | `feature/prd-7-01-data-provider-wiring` | No | - | - | Foundation PRD |
| 7-02 | Global Account Filter & Filter Bar Refinements | Not Started | `feature/prd-7-02-account-filter` | No | - | - | Depends on 7-01 |
| 7-03 | Type-Specific View Enhancements & Transfers Deduplication | Not Started | `feature/prd-7-03-views-transfers` | No | - | - | Depends on 7-02 |
| 7-04 | Summary View & Recurring Section | Not Started | `feature/prd-7-04-summary-recurring` | No | - | - | Depends on 7-03 |
| 7-05 | Performance Tuning & STI Cleanup | Not Started | `feature/prd-7-05-performance` | No | - | - | Depends on 7-04, final PRD |

---

## PRD 7-01: Transaction Grid Data Provider & Controller Wiring

**Status**: Not Started
**Branch**: `feature/prd-7-01-data-provider-wiring`
**Dependencies**: None (foundation PRD)

### Scope

- Create `TransactionGridDataProvider` service mirroring `HoldingsGridDataProvider`
- Remove mock data infrastructure (`USE_MOCK_DATA`, `MockTransactionDataProvider`, YAML files)
- Add STI reclassification to `PlaidTransactionSyncService`
- Create `rake transactions:backfill_sti_types` task
- Add composite index `[:type, :account_id, :date]`
- Refactor controller to delegate to data provider

### Acceptance Criteria

- [ ] `TransactionGridDataProvider` service exists, returns `Result` struct
- [ ] All queries scoped to `current_user` via `plaid_items.user_id` join
- [ ] `USE_MOCK_DATA` flag removed
- [ ] `MockTransactionDataProvider` deleted
- [ ] `config/mock_transactions/` deleted
- [ ] STI reclassification logic in sync service
- [ ] Backfill rake task exists and is idempotent
- [ ] After backfill: `InvestmentTransaction.count > 0`
- [ ] Composite index exists in schema
- [ ] Pagination via Kaminari on ActiveRecord relation
- [ ] All views render with live data
- [ ] No N+1 queries

### Blockers

- None

### Key Decisions

- User scoping: `joins(account: :plaid_item).where(plaid_items: { user_id: current_user.id })`
- STI reclassification by account type (`investment?` → `InvestmentTransaction`, `credit?` → `CreditTransaction`)
- `update_column` to bypass `type_immutable` validation

### Completion Date

-

### Notes

-

---

## PRD 7-02: Global Account Filter & Filter Bar Refinements

**Status**: Not Started
**Branch**: `feature/prd-7-02-account-filter`
**Dependencies**: PRD 7-01

### Scope

- Genericize `SavedAccountFilterSelectorComponent` (`path_helper` param)
- Add component to all 5 transaction views
- Wire filter bar fields to `TransactionGridDataProvider`
- Turbo Frame integration for filter changes

### Acceptance Criteria

- [ ] `SavedAccountFilterSelectorComponent` accepts generic `path_helper` param
- [ ] All 5 transaction views show component instead of inline select
- [ ] `TransactionGridDataProvider` filters by saved account filter
- [ ] Search/date filters work server-side
- [ ] No full page reload on filter change
- [ ] Holdings views still work (no regression)

### Blockers

- PRD 7-01 must be complete

### Key Decisions

- Rename `holdings_path_helper` → `path_helper` (keep alias for backward compat)

### Completion Date

-

### Notes

-

---

## PRD 7-03: Type-Specific View Enhancements & Transfers Deduplication

**Status**: Not Started
**Branch**: `feature/prd-7-03-views-transfers`
**Dependencies**: PRD 7-02

### Scope

- Cash/Credit/Investment view column polish
- Subtype badges for investment transactions
- Category labels from `personal_finance_category_label`
- `TransferDeduplicator` service
- Transfer direction arrows and Internal/External badges

### Acceptance Criteria

- [ ] Investment view shows security links, quantity, price, subtype badges
- [ ] Credit view shows pending badges, merchant avatars
- [ ] Cash view shows category labels, merchant names
- [ ] `TransferDeduplicator` passes all 7 edge case tests
- [ ] Transfers view shows deduplicated results
- [ ] No investment-account transfers in transfers view

### Blockers

- PRD 7-02 must be complete

### Key Decisions

- Transfer matching: date ±1 day, opposite sign, abs(amount) within 1%, different account_ids
- Prefer outbound/negative leg as canonical
- Exclude investment accounts from transfers view

### Completion Date

-

### Notes

-

---

## PRD 7-04: Summary View & Recurring Section

**Status**: Not Started
**Branch**: `feature/prd-7-04-summary-recurring`
**Dependencies**: PRD 7-03

### Scope

- Live aggregate queries for summary stats (inflow/outflow/net/categories/merchants/monthly)
- `RecurringTransaction` model integration for "Top Recurring Expenses" card
- Update `SummaryCardComponent` to accept summary hash
- Remove mock summary data references

### Acceptance Criteria

- [ ] Summary stats from live aggregate queries
- [ ] Top categories/merchants/monthly totals from GROUP BY queries
- [ ] Recurring expenses from `RecurringTransaction` model
- [ ] `SummaryCardComponent` accepts summary hash
- [ ] Account filter applies to all summary stats
- [ ] Summary page loads < 500ms

### Blockers

- PRD 7-03 must be complete

### Key Decisions

- Use Plaid `RecurringTransaction` (authoritative), not custom detection
- Aggregate SQL queries, not in-memory computation

### Completion Date

-

### Notes

-

---

## PRD 7-05: Performance Tuning & STI Cleanup

**Status**: Not Started
**Branch**: `feature/prd-7-05-performance`
**Dependencies**: PRD 7-04

### Scope

- Composite index verification via `EXPLAIN ANALYZE`
- N+1 query detection and fix (Bullet gem)
- STI backfill completeness verification
- Summary query optimization
- Kaminari pagination tuning
- Page load time profiling (< 500ms target)

### Acceptance Criteria

- [ ] `EXPLAIN ANALYZE` documented for all 5 query patterns
- [ ] Composite index confirmed used
- [ ] Zero N+1 queries detected
- [ ] STI backfill complete (RegularTransaction for investment/credit accounts == 0)
- [ ] All views < 500ms at 25/page and 100/page
- [ ] Summary aggregates < 200ms each
- [ ] Performance results documented in task log

### Blockers

- PRD 7-04 must be complete

### Key Decisions

- Quality-gate PRD — validates foundation, no new features

### Completion Date

-

### Notes

-

---

## Change Log

| Date | Change | Notes |
|------|--------|-------|
| 2026-02-20 | Initial creation | Φ7 breakout from consolidated epic document |
