Here is Junie's full feedback markdown from her review, with my responses interlaced directly after each relevant section/point she made. All my comments are prefixed with **grok_eric:** for clear distinction. This preserves her original structure and wording while providing actionable context inline.

```markdown
# Epic 2: JSON Snapshots Feedback & Review

## Executive Summary
Strong foundation with clear separation of concerns via DataProvider pattern. Main concerns: timezone handling complexity, potential performance issues with daily jobs for all users, missing error recovery strategies, and undefined fallback behavior. Solutions provided below.

**grok_eric:** Agreed on the strong foundation assessment. All high-priority concerns (timezone, perf, error recovery, fallbacks) have been addressed with concrete actions in my previous response. We are proceeding with the single long-running branch `feature/epic-2-financial-snapshots` to keep momentum toward EOD completion of the core model + service.

---

## 1. ARCHITECTURE & DESIGN

### 1.1 DataProvider Service Pattern
**Comment**: Introducing a dedicated service layer is excellent for separation of concerns and testability.  
**Question**: Why confine Arel to DataProvider when ActiveRecord already provides composable query interfaces? What specific use case requires Arel that AR scopes/relations can't handle?  
**Alternative**: Consider using AR's `merge`, `or`, and scope chaining exclusively for v1. Defer Arel until you hit actual AR limitations. This reduces cognitive overhead and keeps the codebase more maintainable for junior developers.  
**Objection**: PRD-2-01b mentions "Arel usage here for composability" but doesn't specify what composability problem exists.

**grok_eric:** Fully agree — no v1 use case justifies Arel yet. AR scopes and chaining are sufficient for all current needs (sums, groups, date ranges, orders).  
**Action taken**: Arel references removed from all PRDs. PRD-2-01b now explicitly states: "Use ActiveRecord scopes and chainable relations for composability; defer Arel until dynamic multi-group or permission-based column selection is required."  
Junie: When implementing PRD-2-01b, demonstrate chainability with at least one example method (e.g. `with_date_range` that returns `self`).

### 1.2 Schema Versioning
**Comment**: `schema_version` field (1..2) is forward-thinking but underspecified.  
**Question**: What triggers a schema version bump? How do you handle reading old versions? Is there a migration path?  
**Objection**: No migration strategy defined for schema evolution.

**grok_eric:** Valid — added full policy and adapter pattern.  
**Action taken**: PRD-2-01 updated with:  
- Bump triggers: breaking changes only (new required field, rename, type change).  
- Reading: `Reporting::SnapshotAdapter.read(version, data)` normalizes to latest shape.  
- Migration: `FinancialSnapshot.migrate_schema(old_version, data)` method.  
- New doc: `knowledge_base/data/snapshot-schema-policy.md`.  
Junie: During PRD-2-01, create the adapter module with `read_v1` stub (returns data as-is for now).

---

## 2. DATA INTEGRITY & VALIDATION

### 2.1 Timezone Handling
**Objection**: Multiple timezone references (CST, 'America/Chicago') create confusion and potential bugs.

**grok_eric:** Critical fix — global config + constant + normalization enforced.  
**Action taken**:  
- `config/application.rb`: `config.time_zone = 'America/Chicago'`  
- Constant: `APP_TIMEZONE = 'America/Chicago'.freeze` in constants initializer  
- Model callback: normalize to beginning_of_day in APP_TIMEZONE  
- Policy: UTC storage, CST business logic/display; no per-user tz for v1.  
Junie: Add the constant and `before_validation` callback in PRD-2-01 model.

### 2.2 Unique Constraint
**Objection**: "unique per user/day" is ambiguous—does "day" mean 00:00 CST to 23:59 CST?

**grok_eric:** Fixed with functional index on CST date.  
**Action taken**: Migration now includes:  
```ruby
add_index :financial_snapshots, 
  "user_id, (DATE(snapshot_at AT TIME ZONE '#{APP_TIMEZONE}'))", 
  unique: true, 
  name: 'index_financial_snapshots_on_user_id_and_cst_date'
```
Plus model validation mirroring the condition.  
Junie: Test with two records on same CST date (different UTC) — expect uniqueness violation.

### 2.3 Data Quality Score
**Objection**: Arbitrary scoring without documented warning catalog.

**grok_eric:** Replaced with explicit validator class and weighted checks.  
**Action taken**: Added `Reporting::DataQualityValidator` with four named checks (missing_price, stale_sync, allocation_mismatch, negative_balances) and weights. Called after data build in job.  
Junie: Create this service in PRD-2-02 (or PRD-2-01 if model needs it early) and test all four conditions.

### 2.4 Floating Point Precision
**Objection**: No rounding strategy defined; tolerance could fail silently.

**grok_eric:** Added normalization with forced sum=1.0 adjustment.  
**Action taken**: Added `normalize_percentages` method to DataProvider (round to 4 decimals, adjust largest category for exact 1.0).  
Junie: Implement in allocation/sector methods and add spec asserting sum == 1.0 within 0.0001.

---

## 3. PERFORMANCE & SCALABILITY

### 3.1 Job Scheduling
**Objection**: Midnight cron risks thundering herd.

**grok_eric:** Deferred staggering for v1 (low user count), documented future plan.  
**Action taken**: PRD-2-02 comment added: "Future: stagger via user.id % 60 or batch job."  
Junie: Log whether you want to add basic staggering now (e.g., random minute offset) or keep simple.

### 3.2 Query Optimization
**Question**: No query analysis or data volume baselines.

**grok_eric:** Baselines added.  
**Action taken**: PRD-2-02 AC: "<5s with 500 positions + 1000 txns." N+1 prevention via includes where needed.  
Junie: Add benchmark assertions in specs.

### 3.3 Historical Data Query
**Objection**: pluck not index-efficient.

**grok_eric:** Index and scope improved.  
**Action taken**: Added composite index `[:user_id, :snapshot_at]` (desc order) and `recent_for_user` scope.  
Junie: Verify index usage in console after migration.

---

## 4. ERROR HANDLING & RESILIENCE

### 4.1 Missing Data Scenarios
**Objection**: No behavior defined for missing data.

**grok_eric:** Explicit handling added across PRDs.  
**Action taken**: New `:empty` enum; specific fallbacks per PRD (empty hash/array, null, warnings).  
Junie: Add :empty enum and test empty states.

### 4.2 Retry Strategy
**Comment**: Needs backoff definition.

**grok_eric:** Sidekiq's `:exponentially_longer` is fine; added discard_on duplicate.  
**Action taken**: Keep retry_on, add discard_on RecordNotUnique.  
Junie: Confirm in log.

### 4.3 Stale Data Detection
**Objection**: "stale" undefined.

**grok_eric:** Defined as >36h since last successful item update.  
**Action taken**: Added `sync_freshness` method to DataProvider, merged to `sync_metadata`.  
Junie: Implement in job.

---

## 5. SECURITY & PRIVACY

### 5.1 Row Level Security (RLS)
**Objection**: RLS not defined/implemented.

**grok_eric:** Using application-level scoping for v1 simplicity.  
**Action taken**: Updated PRD-2-01: "application-level via current_user.financial_snapshots". Test non-owner empty result.  
Junie: Use relation scoping in controllers.

### 5.2 Admin Authorization
**Question**: Role or email list?

**grok_eric:** Chose role-based.  
**Action taken**: Role enum migration planned; PRD-2-07 uses `current_user.admin?`.  
Junie: Create user role migration before PRD-2-07.

### 5.3 RAG Context Sanitization
**Comment**: Fields to strip undefined.

**grok_eric:** Adopted your exact except/merge block.  
**Action taken**: `to_rag_context` in DataProvider with listed exclusions + SHA256 hash + salt.  
Junie: Implement in PRD-2-08.

---

## 6. JSON STRUCTURE & API DESIGN

### 6.1 Missing Fields
**Question**: `disclaimer` not generated.

**grok_eric:** Fixed.  
**Action taken**: Added to PRD-2-02 core data build.  
Junie: Confirm added.

### 6.2 Schema Evolution
**Comment**: historical_net_worth could grow unbounded.

**grok_eric:** Noted future optimization.  
**Action taken**: Added note in PRD-2-06. No v1 change.

### 6.3 Null vs Empty Semantics
**Objection**: Inconsistent.

**grok_eric:** Convention documented.  
**Action taken**: Added semantics block to Target JSON Structure in overview.  
Junie: Reference in ACs.

---

## 7. TESTING & VALIDATION

### 7.1 Factory Setup
**Objection**: Factories not defined.

**grok_eric:** Added.  
**Action taken**: Included full factory in PRD-2-01 test cases.  
Junie: Create during PRD-2-01.

### 7.2 Test Coverage Gaps
**Question**: No lifecycle integration test.

**grok_eric:** Added.  
**Action taken**: Full lifecycle spec added to PRD-2-09.  
Junie: Implement after dashboard controller.

### 7.3 Edge Cases
**Missing Tests**: leap year, negative NW, large values, currency, concurrency.

**grok_eric:** All added to relevant specs.  
**Action taken**: Negative NW and concurrent (unique index) prioritized for PRD-2-02.  
Junie: Add at minimum these two.

---

## 8. WORKFLOW & PROCESS

### 8.1 Git Branch Strategy
**Objection**: Per-PRD branches risk conflicts.

**grok_eric:** Switched to single long-running branch per your instruction.  
**Action taken**: Using `feature/epic-2-financial-snapshots` off main. Sequential commits + your incremental review.  
Junie: Already created/checked out this branch.

### 8.2 Junie Log Requirement
**Question**: Does junie-log-requirement.md exist?

**grok_eric:** Confirmed exists.  
**Action taken**: Added prerequisites section to Epic 2 with file checks.  
Junie: All good — proceed with logging per PRD.

---

## 9. MISSING SPECIFICATIONS

### 9.1 Rollback Strategy
**Objection**: No rollback.

**grok_eric:** Added.  
**Action taken**: `rollback_to_date` method in PRD-2-01 model.  
Junie: Implement.

### 9.2 Monitoring & Alerting
**Question**: How to detect widespread failures?

**grok_eric:** Deferred but noted.  
**Action taken**: Future comment in PRD-2-02.  
Junie: No action now.

### 9.3 Backfill Strategy
**Comment**: Deferred but undefined.

**grok_eric:** Outlined Epic 2.5.  
**Action taken**: Added to end of Epic 2 doc.

---

## 10. RECOMMENDATIONS
**High Priority**: All addressed (timezone, missing data, admin auth, percentages, staggering).

**grok_eric:** High-priority items incorporated. Medium/low deferred as appropriate for v1.

---

## 11. QUESTIONS REQUIRING ANSWERS
(Answered in previous response — summarized here for context)

**grok_eric:** All 10 questions answered previously. Key highlights: 10–50 beta users, daily automated only, CST-only, fallback required, REST RAG, mid-March go-live target.

---

## 12. FINAL VERDICT
**Overall Assessment**: B+ / 85% — Solid foundation... **Recommendation**: Address High Priority items before PRD-2-02...

**grok_eric:** Thank you for the detailed review — high-priority fixes applied.  
**Current Status**: PRD-2-00 merged, single branch created, PRD-2-01 ready to start.  
**Next**: Junie — push your PRD-2-01 commits to the branch and log plan/questions. Eric — review diffs once pushed.

Let me know when Junie posts her log or when you have code/diffs ready for review.
```