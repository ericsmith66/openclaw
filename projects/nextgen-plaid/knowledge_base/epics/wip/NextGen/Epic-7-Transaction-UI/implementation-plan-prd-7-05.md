# Implementation Plan: PRD-7-05 Performance Tuning & STI Cleanup

**Date:** 2026-02-22  
**PRD:** knowledge_base/epics/wip/NextGen/Epic-7-Transaction-UI/PRD-7-05-performance.md  
**Implementer:** AiderDesk  
**Status:** Pending Architect Approval

---

## Executive Summary

This PRD is a **quality gate** — it validates that the data provider, controller refactor, and view wiring from PRDs 7.1–7.4 perform well under real data volumes (13,332 transactions in development, potentially more in production). The plan focuses on:

1. **Index verification** — confirm composite index usage in queries
2. **N+1 detection** — use Bullet gem to find and fix eager loading issues
3. **STI completeness** — verify backfill is 100% complete
4. **Performance profiling** — measure and document response times
5. **Pagination safeguards** — add warnings for large "all" requests

No new features. No user-facing behavior changes. Only performance validation and optimization.

---

## Prerequisites Validation

### ✅ Already Complete
- Composite index `idx_transactions_type_account_date` exists (migration `20260220213406`)
- Bullet gem installed (`Gemfile`) and configured (`config/environments/development.rb`)
- `rake transactions:backfill_sti_types` task exists (`lib/tasks/transactions.rake`)
- STI backfill migration exists (`db/migrate/20260121121000_backfill_transaction_sti_type.rb`)
- `TransactionGridDataProvider` service exists with `.includes(:account)` (prevents N+1)

### Current State Analysis
- **Database:** 13,332 transactions across multiple accounts (development)
- **Index Status:** Composite index created concurrently in migration
- **Data Provider:** Already uses `.joins(account: :plaid_item)` and `.includes(:account)`
- **Pagination:** Kaminari-based with "all" support (no cap currently)
- **Caching:** No aggregate query caching yet

---

## Implementation Steps

### Step 1: Composite Index Verification
**Estimated Time:** 30 minutes  
**Files:** None (verification only)

**Tasks:**
1. Start Rails console in development
2. Run `EXPLAIN ANALYZE` on each of the 5 primary query patterns:
   - Regular transactions: `type = 'RegularTransaction'`
   - Investment transactions: `type = 'InvestmentTransaction'`
   - Credit transactions: `type = 'CreditTransaction'`
   - Transfers: `personal_finance_category_label ILIKE 'TRANSFER%'`
   - Summary aggregates: various GROUP BY queries
3. Document query plans showing index usage
4. If sequential scan detected, investigate:
   - Table statistics outdated? → `ANALYZE transactions`
   - Planner estimates? → Check row counts vs reality
   - Need partial index? → Evaluate if standard composite index is insufficient

**Acceptance Criteria:**
- [ ] `EXPLAIN ANALYZE` output captured for all 5 patterns
- [ ] Composite index `idx_transactions_type_account_date` confirmed used in type-filtered queries
- [ ] If index not used, root cause identified and fix planned

**Documentation:** Output goes in task log under "Index Verification Results"

---

### Step 2: N+1 Query Detection and Fix
**Estimated Time:** 1 hour  
**Files:**
- `app/services/transaction_grid_data_provider.rb` (potential `.includes()` additions)
- `app/controllers/transactions_controller.rb` (verify no N+1 in controller)

**Tasks:**
1. Start Rails server with Bullet enabled (already configured)
2. Visit each transaction view:
   - `/transactions/regular?per_page=25`
   - `/transactions/investment?per_page=50`
   - `/transactions/credit?per_page=100`
   - `/transactions/transfers?per_page=25`
   - `/transactions/summary`
3. Check Rails log and browser console for Bullet warnings
4. For each N+1 detected:
   - Identify missing association
   - Add appropriate `.includes()` or `.preload()` to `TransactionGridDataProvider`
5. Most likely candidates:
   - `.includes(:account)` → already exists (line 48)
   - `.includes(account: :plaid_item)` → if institution name needed
   - No new associations expected unless views reference additional data

**Expected Result:**
- Zero N+1 warnings across all views
- Current `.includes(:account)` may already be sufficient

**Acceptance Criteria:**
- [ ] Zero N+1 warnings from Bullet across all 5 views
- [ ] Query count per page load documented
- [ ] If N+1 found, `.includes()` added and verified

**Testing:**
```ruby
# test/services/transaction_grid_data_provider_test.rb
test "does not trigger N+1 queries" do
  # Create test data with associations
  account = accounts(:one)
  10.times { transactions(:one).dup.tap { |t| t.account = account }.save! }
  
  # Enable query logging
  queries = []
  subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    queries << event.payload[:sql] unless event.payload[:name] == "SCHEMA"
  end
  
  result = TransactionGridDataProvider.new(users(:one), { page: 1, per_page: 10 }).call
  result.transactions.each { |t| t.account.name } # Trigger association access
  
  ActiveSupport::Notifications.unsubscribe(subscriber)
  
  # Should be: 1 main query + 1 eager load for accounts (2 total, not 1+N)
  assert queries.size <= 3, "Expected ≤3 queries, got #{queries.size}"
end
```

---

### Step 3: STI Backfill Completeness Verification
**Estimated Time:** 30 minutes  
**Files:**
- `lib/tasks/transactions.rake` (add verification task)

**Tasks:**
1. Run verification query in Rails console:
   ```ruby
   Transaction
     .where(type: 'RegularTransaction')
     .joins(:account)
     .where(accounts: { plaid_account_type: ['investment', 'credit'] })
     .count
   ```
   **Expected:** 0 (all investment/credit account transactions should be reclassified)
2. If count > 0:
   - Re-run `rake transactions:backfill_sti_types`
   - Investigate why rows were missed (soft-deleted? orphaned accounts?)
3. Add monitoring rake task:
   ```ruby
   namespace :transactions do
     desc "Verify STI type completeness"
     task verify_sti_completeness: :environment do
       misclassified = Transaction
         .where(type: 'RegularTransaction')
         .joins(:account)
         .where(accounts: { plaid_account_type: ['investment', 'credit'] })
       
       if misclassified.any?
         puts "⚠️  Found #{misclassified.count} misclassified transactions:"
         misclassified.limit(10).each do |t|
           puts "  - Transaction #{t.id}: type=#{t.type}, account.type=#{t.account.plaid_account_type}"
         end
         puts "\nRun: rake transactions:backfill_sti_types"
       else
         puts "✅ All transactions correctly classified"
       end
     end
   end
   ```

**Acceptance Criteria:**
- [ ] Verification query returns 0 misclassified transactions
- [ ] `rake transactions:verify_sti_completeness` task exists
- [ ] Task provides actionable output

---

### Step 4: Summary Query Optimization
**Estimated Time:** 1.5 hours  
**Files:**
- `app/services/transaction_grid_data_provider.rb` (caching if needed)
- `db/migrate/YYYYMMDDHHMMSS_add_partial_indexes_to_transactions.rb` (if needed)
- `app/jobs/sync_transactions_job.rb` (cache invalidation if caching added)

**Tasks:**
1. Profile summary aggregate queries with `EXPLAIN ANALYZE`:
   - `SUM(amount) WHERE amount > 0` (total inflow)
   - `SUM(amount) WHERE amount < 0` (total outflow)
   - `GROUP BY personal_finance_category_label` (top categories)
   - `GROUP BY merchant_name` (top merchants)
   - `GROUP BY DATE_TRUNC('month', date)` (monthly totals)
2. For each query > 200ms:
   - **Option A:** Partial indexes (e.g., `WHERE amount > 0`)
   - **Option B:** Cache results with `Rails.cache.fetch` (TTL: 5 minutes)
   - **Option C:** Materialized views (deferred, too heavy for MVP)
3. If caching added:
   - Cache key must include user_id, view_type, filters
   - Invalidate in `SyncTransactionsJob` after successful sync
   - Document cache TTL and invalidation strategy

**Decision Criteria:**
- If queries < 200ms → no optimization needed
- If queries 200–500ms → add partial indexes
- If queries > 500ms → add caching + partial indexes

**Example Caching (if needed):**
```ruby
def compute_summary
  cache_key = [
    "transaction_summary",
    user.id,
    params[:view_type],
    params[:saved_account_filter_id],
    params[:date_from],
    params[:date_to]
  ].compact.join("/")
  
  Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
    rel = filtered_relation
    # ... existing aggregate queries
  end
end
```

**Acceptance Criteria:**
- [ ] All summary queries < 200ms (or < 500ms with optimization plan)
- [ ] If partial indexes added, migration created
- [ ] If caching added, cache invalidation in `SyncTransactionsJob`
- [ ] Performance results documented

---

### Step 5: Kaminari Pagination Tuning
**Estimated Time:** 45 minutes  
**Files:**
- `app/services/transaction_grid_data_provider.rb` (add warning logic)
- `app/views/transactions/_grid.html.erb` (display warning)

**Tasks:**
1. Verify current pagination:
   - Default: 25/page ✅ (already set as `DEFAULT_PER_PAGE`)
   - Max selectable: 100 ✅ (user can select up to 100)
   - "All" support: ✅ (returns unpaginated relation if `per_page == "all"`)
2. Add warning for `per_page = "all"` if count > 500:
   ```ruby
   def paginate(relation)
     page = params[:page].to_i
     page = 1 if page <= 0
     per_page = params[:per_page].presence || DEFAULT_PER_PAGE
     
     if per_page.to_s == "all"
       total = filtered_relation.count
       if total > 500
         # Store warning in Result struct
         @large_dataset_warning = "Showing all #{total} transactions. Consider filtering by date or account."
       end
       relation
     else
       relation.page(page).per(per_page.to_i)
     end
   end
   ```
3. Update `Result` struct to include warning:
   ```ruby
   Result = Struct.new(:transactions, :summary, :total_count, :warning, keyword_init: true)
   ```
4. Display warning in view (mirror Holdings grid pattern)

**Acceptance Criteria:**
- [ ] Warning displayed if `per_page=all` and count > 500
- [ ] Warning includes total count
- [ ] "All" still works (no hard cap, just warning)
- [ ] Default and max per_page unchanged (25, 100)

---

### Step 6: Counter Cache Evaluation
**Estimated Time:** 30 minutes  
**Files:** None (decision only)

**Tasks:**
1. Review if `Account` needs `transactions_count` counter cache:
   - Is transaction count frequently displayed? (e.g., "Account X has Y transactions")
   - Do summary views show per-account transaction counts?
   - Is `Account.transactions.count` called in N+1 fashion?
2. Check current codebase:
   - `grep -r "transactions.count" app/`
   - `grep -r "account.transactions.size" app/`
3. Decision criteria:
   - **Add counter cache** if count is shown frequently (e.g., account list, filters)
   - **Skip** if count is only used in aggregate queries (GROUP BY already efficient)

**Expected Result:**
- Counter cache likely NOT needed (no per-account transaction counts in current views)
- Document decision in task log

**Acceptance Criteria:**
- [ ] Evaluation complete
- [ ] Decision documented with rationale
- [ ] If deferred, note potential future optimization

---

### Step 7: Page Load Time Profiling
**Estimated Time:** 1 hour  
**Files:** None (profiling only)

**Tasks:**
1. Profile all 5 views at two pagination levels:
   - 25/page (default)
   - 100/page (max)
2. Measure server response time via:
   - Rails log: `Completed 200 OK in XXXms`
   - `rack-mini-profiler` (if installed)
   - Browser DevTools Network tab (Time to First Byte)
3. Target: < 500ms server response time
4. Document results in task log:
   ```
   | View       | 25/page | 100/page | Status |
   |------------|---------|----------|--------|
   | Regular    | 245ms   | 380ms    | ✅ Pass |
   | Investment | 190ms   | 295ms    | ✅ Pass |
   | Credit     | 210ms   | 340ms    | ✅ Pass |
   | Transfers  | 260ms   | 420ms    | ✅ Pass |
   | Summary    | 480ms   | N/A      | ✅ Pass |
   ```
5. If any view > 500ms:
   - Investigate slow queries (use query logs, `EXPLAIN ANALYZE`)
   - Apply fixes from Step 2 (N+1) or Step 4 (aggregates)
   - Re-profile

**Acceptance Criteria:**
- [ ] All 5 views < 500ms at 25/page
- [ ] All 5 views < 500ms at 100/page
- [ ] Results documented in task log
- [ ] If optimizations needed, applied and re-tested

---

## Testing Strategy

### Unit Tests
**File:** `test/services/transaction_grid_data_provider_test.rb`

**New Tests:**
```ruby
test "does not trigger N+1 queries" do
  # (See Step 2 for implementation)
end

test "returns warning when per_page is all and count > 500" do
  # Create 501 transactions
  501.times { create(:transaction, user: @user) }
  
  result = TransactionGridDataProvider.new(@user, { per_page: "all" }).call
  
  assert result.warning.present?
  assert_includes result.warning, "501 transactions"
end

test "no warning when per_page is all and count <= 500" do
  # Create 100 transactions
  100.times { create(:transaction, user: @user) }
  
  result = TransactionGridDataProvider.new(@user, { per_page: "all" }).call
  
  assert_nil result.warning
end
```

**Existing Tests to Update:**
- Verify `.includes(:account)` still prevents N+1
- Verify summary mode still returns correct aggregates

### Integration Tests
**File:** `test/controllers/transactions_controller_test.rb`

**New Tests:**
```ruby
test "all views respond in < 1 second" do
  # Generous threshold for test environment (CI may be slower)
  %w[regular investment credit transfers summary].each do |view|
    start_time = Time.current
    get "/transactions/#{view}"
    duration = Time.current - start_time
    
    assert_response :success
    assert duration < 1.0, "#{view} took #{duration}s (> 1s)"
  end
end

test "per_page=all returns all transactions without error" do
  # Create 100 transactions (avoid CI timeout)
  100.times { create(:transaction, user: @user) }
  
  get "/transactions/regular", params: { per_page: "all" }
  
  assert_response :success
  assert assigns(:transactions).size == 100
end
```

### System / Smoke Tests
**File:** `test/system/transactions_performance_test.rb` (new)

```ruby
require "application_system_test_case"

class TransactionsPerformanceTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
    # Create representative data (avoid timeout)
    25.times { create(:transaction, user: @user, type: "RegularTransaction") }
    25.times { create(:transaction, user: @user, type: "InvestmentTransaction") }
  end

  test "all transaction views load without timeout" do
    %w[regular investment credit transfers summary].each do |view|
      visit "/transactions/#{view}"
      assert_selector "h1", text: /Transactions|Summary/i, wait: 5
    end
  end

  test "pagination works without delay" do
    visit "/transactions/regular"
    
    # Page 2
    click_on "2"
    assert_selector "h1", wait: 2
    
    # Per page selector
    select "50", from: "per_page"
    assert_selector "h1", wait: 2
  end

  test "per_page=100 renders without timeout" do
    visit "/transactions/regular?per_page=100"
    assert_selector "table", wait: 5
  end
end
```

---

## Risk Assessment

### Low Risk
- **Composite index verification** — read-only, no code changes
- **Counter cache evaluation** — decision only, no changes
- **Profiling** — observation only

### Medium Risk
- **N+1 fixes** — adding `.includes()` rarely breaks, but verify no over-fetching
- **STI verification** — backfill task is idempotent, safe to re-run
- **Pagination warning** — display-only, no behavioral change

### High Risk
- **Summary query caching** — cache invalidation is hard; prefer deferring if not needed
- **Partial indexes** — rarely problematic, but test planner behavior on small datasets

### Mitigation
1. All changes isolated to performance, no feature changes
2. Existing test suite catches regressions
3. Manual smoke testing before PR
4. Cache invalidation strategy documented and tested

---

## Dependencies

### Blocked By
- **PRD-7.4** — must be complete (all views wired, summary mode implemented)

### Blocks
- None (final PRD in epic)

---

## Performance Targets (Acceptance Criteria)

- [ ] All type-filtered queries use composite index `idx_transactions_type_account_date`
- [ ] Zero N+1 queries across all 5 views
- [ ] STI backfill 100% complete (0 misclassified transactions)
- [ ] All summary aggregate queries < 200ms
- [ ] All 5 views load in < 500ms at 25/page
- [ ] All 5 views load in < 500ms at 100/page
- [ ] Warning displayed if `per_page=all` and count > 500
- [ ] Counter cache decision documented
- [ ] Performance results documented in task log
- [ ] No user-facing behavior changes

---

## Rollout Notes

1. **Migrations:** If partial indexes added, use `algorithm: :concurrently` (non-blocking)
2. **Caching:** If added, verify cache backend (Solid Cache or Redis) is configured
3. **Monitoring:** Document baseline performance in task log for future comparison
4. **Rollback:** All changes are additive (indexes, tests). Safe to revert if needed.

---

## Estimated Total Time

- **Step 1:** Index verification — 30 min
- **Step 2:** N+1 detection — 1 hour
- **Step 3:** STI verification — 30 min
- **Step 4:** Summary optimization — 1.5 hours
- **Step 5:** Pagination tuning — 45 min
- **Step 6:** Counter cache evaluation — 30 min
- **Step 7:** Profiling — 1 hour
- **Testing:** 1.5 hours
- **Documentation:** 30 min

**Total:** ~7.5 hours

---

## Success Criteria

1. ✅ All acceptance criteria from PRD-7-05 met
2. ✅ No regressions in existing tests
3. ✅ Performance results documented
4. ✅ No user-facing behavior changes
5. ✅ Architect approval received
6. ✅ QA score ≥ 90

---

## Next Steps

1. Submit this plan to **Architect Agent** for review and approval
2. Upon `PLAN-APPROVED`, begin Step 1 (index verification)
3. Document all findings in Junie task log
4. Submit completed work to **QA Agent** for scoring
