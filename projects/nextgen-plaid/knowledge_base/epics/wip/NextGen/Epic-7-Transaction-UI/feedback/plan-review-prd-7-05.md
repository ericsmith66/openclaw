# Architect Plan Review: PRD-7-05 Performance Tuning & STI Cleanup

**Date:** 2026-02-22  
**Reviewer:** Principal Architect  
**Plan:** `implementation-plan-prd-7-05.md`  
**PRD:** `PRD-7-05-performance.md`  
**Status:** ✅ APPROVED WITH MODIFICATIONS

---

## Scoring Summary

| Criteria | Weight | Score | Notes |
|----------|--------|-------|-------|
| **Completeness** | 25% | 23/25 | All 11 PRD ACs mapped to steps. Minor gap: Holdings grid warning pattern doesn't exist yet (see Mod #1). |
| **Architecture Alignment** | 25% | 24/25 | Follows existing patterns (service objects, Minitest, ViewComponents). Minor: Result struct change needs backward-compatibility consideration. |
| **Risk Awareness** | 20% | 19/20 | Solid risk matrix. Caching appropriately deferred unless thresholds exceeded. Cache invalidation plan is sound. |
| **Test Strategy** | 15% | 13/15 | Good 3-tier coverage. N+1 test approach via notification subscription is correct. Missing: test for Result struct backward compat after `warning` field added. |
| **Dependency Ordering** | 15% | 15/15 | Perfect sequence: verify first (Steps 1, 3), detect (Step 2), optimize (Steps 4, 5), evaluate (Step 6), profile (Step 7). |
| **TOTAL** | **100%** | **94/100** | |

---

## Detailed Review

### 1. Completeness — 23/25

**Covered PRD Requirements:**
- ✅ AC-1: EXPLAIN ANALYZE for all 5 query patterns (Step 1)
- ✅ AC-2: Composite index confirmed (Step 1)
- ✅ AC-3: Zero N+1 queries (Step 2)
- ✅ AC-4: STI backfill completeness (Step 3)
- ✅ AC-5: All views < 500ms at 25/page (Step 7)
- ✅ AC-6: All views < 500ms at 100/page (Step 7)
- ✅ AC-7: Summary aggregates < 200ms (Step 4)
- ✅ AC-8: Warning for per_page=all > 500 (Step 5)
- ✅ AC-9: Counter cache decision documented (Step 6)
- ✅ AC-10: Performance results documented (Step 7)
- ✅ AC-11: No user-facing behavior changes

**Gap Identified:**
- The plan references "mirror Holdings grid pattern" for the per_page=all warning, but **the Holdings grid does NOT currently have this warning pattern**. `HoldingsGridDataProvider` simply returns all rows when `per_page == :all` with no warning or cap. The implementer should be aware this is a **new pattern**, not a copy of an existing one.

### 2. Architecture Alignment — 24/25

**Strengths:**
- Correctly modifies `TransactionGridDataProvider` (service object pattern)
- Correctly identifies the `Result` struct as the vehicle for warning data
- N+1 detection uses existing Bullet configuration (verified: Gemfile line 58, development.rb lines 107-112)
- STI verification rake task is idiomatic Rails
- Caching strategy correctly uses `Rails.cache.fetch` with composite keys

**Minor Concern:**
- Adding `warning` to the `Result = Struct.new(:transactions, :summary, :total_count, keyword_init: true)` is a struct signature change. Because `keyword_init: true` is used, existing callers won't break — they just won't pass `warning:`. However, the controller's `assign_from_result` method (line 150-163) must propagate `@warning = result.warning` and views must display it. The plan mentions updating the view but the controller wiring is not explicitly called out. **See Modification #2.**

### 3. Risk Awareness — 19/20

**Well-Handled Risks:**
- Composite index not used → investigate planner estimates, ANALYZE
- N+1 on `account.plaid_item` → `.includes(account: :plaid_item)` ready
- STI backfill missed rows → re-run + investigate
- Cache staleness → invalidate in `SyncTransactionsJob`
- "All" per_page OOM → warning (not hard cap, which is correct)
- Bullet false positives → whitelist config

**Observation:**
- The `transfers` action (line 42-61 in controller) calls `TransferDeduplicator.new(result.transactions).call` which materializes the entire result set into memory. If `per_page=all` is used on transfers with a large dataset, this could be the biggest memory risk. The plan doesn't specifically call out this interaction. **See Modification #3.**

### 4. Test Strategy — 13/15

**Strengths:**
- 3-tier coverage: unit (data provider), integration (controller), system (Capybara)
- N+1 test using `ActiveSupport::Notifications.subscribe("sql.active_record")` — correct approach
- Warning threshold test (501 transactions) is well-designed
- System tests focus on timeout absence, not exact timing (correct for CI)

**Gaps:**
- No explicit test that the `Result` struct still works without the `warning` field (backward compat, though `keyword_init` handles this)
- Integration test for "per_page=all returns 200" should also verify the warning ivar is set when count exceeds threshold
- The test code in Step 2 uses `create(:transaction)` factory syntax — verify this project uses factories or fixtures. Based on existing tests, the project uses **fixtures + direct creation** (`PlaidItem.create!`, etc.), not FactoryBot. Test code should be adjusted accordingly.

### 5. Dependency Ordering — 15/15

Excellent sequencing:
1. **Verify** (Steps 1, 3) — read-only, no risk
2. **Detect** (Step 2) — identify issues before fixing
3. **Optimize** (Steps 4, 5) — targeted fixes
4. **Evaluate** (Step 6) — decision gate
5. **Profile** (Step 7) — final validation with before/after

No circular dependencies. No forward references.

---

## Required Modifications

### Modification #1: Correct Holdings Grid Reference
**Step 5** references "mirror Holdings grid pattern" — this pattern does not exist. Change to: "Implement a new warning pattern for large dataset display. No existing pattern to mirror; this will be the first implementation of per_page=all warnings in the application."

### Modification #2: Explicitly Wire Warning Through Controller
**Step 5** must explicitly include:
1. Add `@warning = result.warning` to `assign_from_result` in the controller
2. Add `@warning = result.warning` to the `transfers` action (which uses custom assignment, not `assign_from_result`)
3. Add a flash-style or inline alert in the shared grid partial/view that renders `@warning` when present
4. Ensure the `summary` action also handles warning (though summary doesn't paginate, it could be relevant for filtered views)

### Modification #3: TransferDeduplicator Memory Note
**Step 5** or **Risk Assessment** should note: "The `transfers` action calls `TransferDeduplicator.new(result.transactions).call` which loads all matching transactions into memory before deduplication. When `per_page=all` is used on transfers, this is the highest memory risk scenario. The warning threshold of 500 should apply here as well. Consider whether to apply pagination *before* deduplication or add a hard cap on the transfers view."

### Modification #4: Test Code — Use Fixtures, Not Factories
All test code examples use `create(:transaction)` (FactoryBot syntax). This project uses **Minitest fixtures**. Test code should be rewritten to use fixture-based setup or `Transaction.create!` / `dup`-based patterns consistent with the existing test file at `test/services/transaction_grid_data_provider_test.rb`.

---

## Recommendations (Non-Blocking)

1. **EXPLAIN ANALYZE Documentation Format:** Consider a structured format for the task log (query pattern → full EXPLAIN output → index used? → timing). This makes future comparisons easier.

2. **Bullet Whitelist Proactively:** The `joins(account: :plaid_item).includes(:account)` pattern may trigger Bullet's "unused eager loading" warning since `.joins` already loads the association in some cases. Proactively whitelist this in Bullet config if it surfaces.

3. **Consider `strict_loading` in Development:** Rails 8 supports `strict_loading` mode which can catch N+1 issues at the model level. Not required for this PRD, but worth evaluating for the next epic.

4. **STI Verification in CI:** The `rake transactions:verify_sti_completeness` task could be added to CI as a post-deployment check (non-blocking, advisory only). This catches drift over time.

---

## Verdict

The plan is thorough, well-sequenced, and covers all PRD acceptance criteria. The quality gate nature of this PRD is properly reflected — the plan is verification-first with optimization only when warranted. The four modifications above are minor and implementable without restructuring the plan.

**PLAN-APPROVED**

---
