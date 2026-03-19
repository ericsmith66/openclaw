#### PRD-7-05: Performance Tuning & STI Cleanup

**Log Requirements**
- Junie: read `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Final optimization pass across all transaction views and the data provider. Verify composite index usage, detect and fix N+1 queries, evaluate caching for summary aggregates, confirm STI backfill completeness, and profile page load times against the 500ms target. This is a quality-gate PRD — it validates that the foundation built in PRDs 7.1–7.4 performs well at scale.

**User Story:** As a user, I want transaction pages to load quickly (< 500ms) even with thousands of transactions, so that navigating my financial data feels responsive.

---

### Requirements

#### Functional

1. **Composite index verification**:
   - Run `EXPLAIN ANALYZE` on the 5 primary query patterns (regular, investment, credit, transfers, summary)
   - Confirm `idx_transactions_type_account_date` is used in all type-filtered queries
   - If not used, investigate and fix (query planner may prefer sequential scan on small tables)
   - Document EXPLAIN output in task log

2. **N+1 query detection and fix**:
   - Enable `Bullet` gem (or manual log inspection) in development
   - Load each transaction view with 25, 50, 100 results per page
   - Fix any detected N+1 queries with appropriate `.includes()`, `.preload()`, or `.eager_load()`
   - Expected eager loads: `:account` (already), potentially `account: :plaid_item` for institution name

3. **STI backfill completeness verification**:
   - Run: `Transaction.where(type: 'RegularTransaction').joins(:account).where(accounts: { plaid_account_type: ['investment', 'credit'] }).count`
   - Expected: 0 (all investment/credit account transactions should be reclassified)
   - If > 0: re-run `rake transactions:backfill_sti_types` and investigate why rows were missed
   - Add a monitoring check (rake task or console snippet) for ongoing verification

4. **Summary query optimization**:
   - Profile summary aggregate queries (`SUM`, `GROUP BY`) with `EXPLAIN ANALYZE`
   - If any aggregate exceeds 200ms, consider:
     - Adding partial indexes (e.g., `WHERE amount > 0` for inflow queries)
     - Caching summary results with `Rails.cache` (TTL: 5 minutes)
     - Materializing monthly totals in a background job

5. **Kaminari pagination tuning**:
   - Verify `page` and `per_page` defaults are sensible (25 default, max 100 for non-"all")
   - Verify `per_page = "all"` doesn't cause memory issues with 13k+ transactions
   - Add warning/cap if "all" is selected and count > 500 (mirror Holdings grid pattern)

6. **Counter cache evaluation**:
   - Assess whether `Account` should have `transactions_count` counter cache
   - If summary views frequently show "X transactions in Account Y", add counter cache
   - If not needed, document decision and skip

7. **Page load time profiling**:
   - Profile all 5 transaction views at 25/page and 100/page
   - Target: < 500ms server response time (measured via `Rails.logger` or `rack-mini-profiler`)
   - Document results in task log with before/after if optimizations applied

#### Non-Functional

- All optimizations must not change user-facing behavior (same data, same rendering)
- Caching (if added) must be invalidated on new transaction sync
- No new dependencies (Bullet gem is development-only)
- Performance results documented for future reference

#### Rails / Implementation Notes

- **Gem**: Add `bullet` to development group in `Gemfile` if not present
- **Config**: Enable Bullet in `config/environments/development.rb`
- **Service**: Potential `.includes()` additions to `TransactionGridDataProvider`
- **Migration**: Potential partial indexes if needed (e.g., `WHERE amount > 0`)
- **Cache**: Potential `Rails.cache.fetch` wrappers in data provider summary mode
- **Rake**: Potential `rake transactions:verify_sti_completeness` task

---

### Error Scenarios & Fallbacks

| Scenario | Expected Behavior |
|----------|------------------|
| Composite index not used by query planner | Force with optimizer hint, or add more specific partial index |
| N+1 detected on `account.plaid_item.institution_name` | Add `.includes(account: :plaid_item)` to data provider |
| STI backfill missed rows (count > 0) | Re-run backfill; investigate `default_sti_type` callback interference |
| Summary cache stale after sync | Invalidate cache key in `SyncTransactionsJob` after successful sync |
| "All" per_page causes OOM on large dataset | Add cap at 1000 rows or show warning like Holdings grid |
| Bullet gem raises false positives | Whitelist specific known patterns in Bullet config |

---

### Architectural Context

This PRD is a quality gate — it validates that the data provider, controller refactor, and view wiring from PRDs 7.1–7.4 perform well under real data volumes. The development database has 13,332 transactions across multiple accounts. Production may have significantly more over time (Plaid syncs accumulate history). Performance tuning now prevents scaling issues later.

The Holdings Grid has a similar performance validation pattern — `HoldingsGridDataProvider` uses `.includes()`, composite indexes, and pagination to maintain sub-500ms response times across thousands of holdings.

---

### Acceptance Criteria

- [ ] `EXPLAIN ANALYZE` output documented for all 5 primary query patterns
- [ ] Composite index `idx_transactions_type_account_date` confirmed used in type-filtered queries
- [ ] Zero N+1 queries detected by Bullet (or manual log inspection) across all views
- [ ] STI backfill completeness: `RegularTransaction` count for investment/credit accounts == 0
- [ ] All 5 transaction views load in < 500ms server response time at 25/page
- [ ] All 5 transaction views load in < 500ms at 100/page
- [ ] Summary view aggregate queries each < 200ms
- [ ] `per_page = "all"` shows warning if count > 500 (like Holdings grid)
- [ ] Counter cache decision documented (added or explicitly deferred with rationale)
- [ ] Performance profiling results documented in task log
- [ ] No user-facing behavior changes (data and rendering identical before/after)

---

### Test Cases

#### Unit (Minitest)

- `test/services/transaction_grid_data_provider_test.rb` (additions):
  - Verify `.includes(:account)` prevents N+1 (use `assert_queries` helper if available)
  - Verify "all" per_page returns complete result set
  - Verify summary mode aggregate queries return correct results (unchanged from PRD-7.4)

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb` (additions):
  - All views respond in < 1 second (generous for test environment)
  - `per_page=all` returns 200 (not error or timeout)

#### System / Smoke (Capybara)

- `test/system/transactions_performance_test.rb`:
  - Visit each view → page loads without timeout
  - Navigate to page 2, page 3 → each loads without delay
  - Select "100" per page → renders without timeout

---

### Manual Verification

1. Open `rails console`:
   - `Transaction.where(type: 'RegularTransaction').joins(:account).where(accounts: { plaid_account_type: ['investment', 'credit'] }).count` → expected: 0
2. Start server with Bullet enabled
3. Visit each transaction view (regular, investment, credit, transfers, summary) with 25/page
4. Check Rails log for Bullet warnings — should be zero N+1 alerts
5. Check Rails log for response times — all < 500ms
6. Visit `/transactions/regular?per_page=100` → loads within 500ms
7. Visit `/transactions/summary` → all stat cards load quickly
8. Run `EXPLAIN ANALYZE` in `rails dbconsole`:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM transactions
   WHERE type = 'RegularTransaction'
   AND account_id IN (SELECT id FROM accounts WHERE id IN (SELECT account_id FROM plaid_items WHERE user_id = 1))
   ORDER BY date DESC
   LIMIT 25;
   ```
   → Confirm index scan (not sequential scan)

**Expected**
- All views load in < 500ms
- Zero N+1 warnings
- Composite index used in query plans
- STI backfill complete
- Performance results documented

---

### Dependencies

- **Blocked By:** PRD-7.4 (all views and data wiring must be complete)
- **Blocks:** None (final PRD in epic)

---

### Rollout / Deployment Notes

- Potential migration if partial indexes added (non-breaking, concurrent creation)
- Bullet gem is development-only — no production impact
- Cache additions (if any) require `Rails.cache` backend configured (already present via Solid Cache or Redis)
- Document performance baseline in task log for future comparison

---
