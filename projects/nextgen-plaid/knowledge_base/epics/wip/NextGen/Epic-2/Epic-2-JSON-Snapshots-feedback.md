# Epic 2: JSON Snapshots Feedback & Review

## Executive Summary
Strong foundation with clear separation of concerns via DataProvider pattern. Main concerns: timezone handling complexity, potential performance issues with daily jobs for all users, missing error recovery strategies, and undefined fallback behavior. Solutions provided below.

---

## 1. ARCHITECTURE & DESIGN

### 1.1 DataProvider Service Pattern
**Comment**: Introducing a dedicated service layer is excellent for separation of concerns and testability.

**Question**: Why confine Arel to DataProvider when ActiveRecord already provides composable query interfaces? What specific use case requires Arel that AR scopes/relations can't handle?

**Alternative**: Consider using AR's `merge`, `or`, and scope chaining exclusively for v1. Defer Arel until you hit actual AR limitations. This reduces cognitive overhead and keeps the codebase more maintainable for junior developers.

**Objection**: PRD-2-01b mentions "Arel usage here for composability" but doesn't specify what composability problem exists.
- **Solution**: Document 2-3 concrete scenarios where Arel is necessary (e.g., "dynamic column selection based on user permissions" or "cross-table aggregations not expressible in AR"). If none exist, remove Arel mentions and use pure AR for v1.

### 1.2 Schema Versioning
**Comment**: `schema_version` field (1..2) is forward-thinking but underspecified.

**Question**: What triggers a schema version bump? How do you handle reading old versions? Is there a migration path?

**Objection**: No migration strategy defined for schema evolution.
- **Solution**: Add to PRD-2-01:
  - Document schema versioning policy (e.g., "breaking changes increment version")
  - Add `FinancialSnapshot.migrate_schema!` method that upgrades old versions
  - Create `Reporting::SchemaAdapter.read(snapshot)` that handles version-specific parsing
  - Example: v1→v2 might add `liabilities_breakdown`; adapter fills empty array for v1 snapshots

---

## 2. DATA INTEGRITY & VALIDATION

### 2.1 Timezone Handling
**Objection**: Multiple timezone references (CST, 'America/Chicago') create confusion and potential bugs.
- **Solution**:
  1. Add to app config: `config.time_zone = 'America/Chicago'`
  2. Create shared constant: `APP_TIMEZONE = 'America/Chicago'`
  3. Document policy: "All `snapshot_at` values stored in DB as UTC, displayed/queried in CST"
  4. Add validation: `before_create :normalize_snapshot_at_to_date` that strips time component
  5. Replace all `Date.today.in_time_zone('America/Chicago')` with `Date.current` (uses Rails.application.config.time_zone)

**Question**: What happens when user travels/moves timezones? Should snapshots be user-timezone aware or always CST?

### 2.2 Unique Constraint
**Objection**: "unique per user/day" (PRD-2-01:148) is ambiguous—does "day" mean 00:00 CST to 23:59 CST?
- **Solution**: Add DB constraint + index:
  ```ruby
  add_index :financial_snapshots,
    [:user_id, "DATE(snapshot_at AT TIME ZONE 'America/Chicago')"],
    unique: true,
    name: 'idx_snapshots_user_date'
  ```
  This ensures uniqueness based on CST calendar date regardless of UTC timestamp.

### 2.3 Data Quality Score
**Comment**: `data_quality_score` (PRD-2-01:133) uses `100 - warnings.count * 5` but doesn't define warning types.

**Objection**: Arbitrary scoring without documented warning catalog.
- **Solution**:
  1. Create `Reporting::DataQualityValidator` with explicit checks:
     - `missing_price_data` (positions without current_value)
     - `stale_sync` (last_sync_at > 24h)
     - `allocation_mismatch` (sum != 1.0 ± 0.01)
     - `negative_balances` (unexpected negatives in cash accounts)
  2. Each warning has weight (5-20 points)
  3. Document in PRD-2-07 admin preview which warnings are fatal vs informational

### 2.4 Floating Point Precision
**Question**: Using `0.62` decimals for percentages—how do you handle rounding errors ensuring sum=1.0?

**Objection**: No rounding strategy defined; `sum ≈1, tolerance 0.01` (PRD-2-03:315) could fail silently.
- **Solution**:
  ```ruby
  # In DataProvider
  def normalize_percentages(raw_hash)
    total = raw_hash.values.sum
    normalized = raw_hash.transform_values { |v| v / total }
    # Adjust largest category to force exact 1.0
    diff = 1.0 - normalized.values.sum
    largest_key = normalized.max_by { |k,v| v }.first
    normalized[largest_key] += diff
    normalized
  end
  ```

---

## 3. PERFORMANCE & SCALABILITY

### 3.1 Job Scheduling
**Objection**: "Sidekiq cron daily at midnight" (PRD-2-02:250) will create thundering herd if many users.
- **Solution**:
  1. Stagger execution: `cron "#{user.id % 60} #{user.id % 24} * * *"`
  2. Or batch users: `FinancialSnapshotBatchJob` that processes users in chunks
  3. Add `bulk_perform` variant for initial backfill:
     ```ruby
     User.in_batches(of: 100) do |batch|
       batch.each { |user| FinancialSnapshotJob.perform_later(user) }
       sleep 5 # Rate limit
     end
     ```

### 3.2 Query Optimization
**Question**: PRD-2-02:255 mentions "<5s per user" but no query analysis. What's the expected data volume?

**Comment**: Need concrete performance baselines.
- **Solution**: Add to each PRD:
  - Sample data sizes (e.g., "assumes 500 positions, 1000 transactions/month")
  - Add `explain: true` to test queries during spec development
  - Document N+1 prevention (e.g., `includes(:holdings)` for positions)

### 3.3 Historical Data Query
**Objection**: PRD-2-06:457 fetches "last 30 snapshots" with pluck but doesn't use indexes efficiently.
- **Solution**:
  ```ruby
  # Add to FinancialSnapshot model
  scope :last_n_days, ->(user, days = 30) {
    where(user: user)
      .where('snapshot_at > ?', days.days.ago)
      .order(snapshot_at: :desc)
      .select(:snapshot_at, :data) # Only needed fields
  }
  ```
  Add composite index: `add_index :financial_snapshots, [:user_id, :snapshot_at]`

---

## 4. ERROR HANDLING & RESILIENCE

### 4.1 Missing Data Scenarios
**Objection**: PRDs assume data exists but don't specify behavior when it doesn't.
- **Solution for each PRD**:
  - **PRD-2-02** (Core): If `total_net_worth = 0` due to no positions, set status `:empty` (new enum value) vs `:complete`
  - **PRD-2-03** (Allocation): Empty positions → `asset_allocation: {}` with warning "No holdings data"
  - **PRD-2-04** (Sectors): No equities → `sector_weights: null` (not empty hash)
  - **PRD-2-05** (Holdings): No holdings → `top_holdings: []` with metadata `{count_available: 0}`

### 4.2 Retry Strategy
**Comment**: "retry: 3 attempts with exponential backoff" (PRD-2-02:252) is good but needs backoff definition.

**Solution**:
```ruby
class FinancialSnapshotJob < ApplicationJob
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotUnique # Don't retry duplicates

  def perform(user)
    # ... implementation
  rescue Reporting::DataProviderError => e
    # Custom handling for data issues
    snapshot.update!(status: :error, data: { error: e.message })
    raise # Still count as failure for monitoring
  end
end
```

### 4.3 Stale Data Detection
**Objection**: "log error if sync stale" (PRD-2-02:257) doesn't define "stale" or what sync timestamp to check.
- **Solution**:
  ```ruby
  # In DataProvider or Job
  def check_sync_freshness(user)
    latest_sync = user.items.maximum(:last_successful_update)
    if latest_sync.nil? || latest_sync < 36.hours.ago
      { stale: true, last_sync_at: latest_sync }
    else
      { stale: false }
    end
  end
  ```
  Add to snapshot data: `"sync_metadata": { "last_sync_at": "2026-01-23T10:00:00Z", "is_stale": false }`

---

## 5. SECURITY & PRIVACY

### 5.1 Row Level Security (RLS)
**Comment**: PRD-2-01:137 mentions "RLS policy" but doesn't provide implementation.

**Question**: Are you using PostgreSQL RLS or application-level scoping?

**Objection**: RLS policy not defined in migration.
- **Solution (PostgreSQL RLS)**:
  ```sql
  -- In migration
  execute <<-SQL
    ALTER TABLE financial_snapshots ENABLE ROW LEVEL SECURITY;

    CREATE POLICY snapshots_user_isolation ON financial_snapshots
      USING (user_id = current_setting('app.current_user_id')::int);
  SQL
  ```
  Then set in ApplicationController: `ActiveRecord::Base.connection.execute("SET app.current_user_id = #{current_user.id}")`

- **Solution (Application-level)**:
  ```ruby
  # In FinancialSnapshot model
  belongs_to :user

  # In controller
  def scoped_snapshots
    current_user.financial_snapshots # Implicit scoping
  end
  ```
  Add test: Non-owner queries return empty, not raise error (per PRD-2-01:150).

### 5.2 Admin Authorization
**Question**: PRD-2-07:495 uses "user.admin? or email list"—which is it?

**Objection**: Dual authorization mechanisms create confusion.
- **Solution**: Pick one approach:
  - **Option A** (Role-based): Add `role:enum` to users table (`[:intern, :advisor, :admin]`)
  - **Option B** (Email whitelist): `ADMIN_EMAILS=admin@example.com,owner@example.com` in ENV
  - **Recommendation**: Use role-based for flexibility; add migration to backfill existing users

### 5.3 RAG Context Sanitization
**Comment**: PRD-2-08:545 sanitizes but doesn't list which fields to strip.

**Solution**:
```ruby
# In DataProvider
def to_rag_context
  data.except(
    'account_numbers',      # PII
    'institution_ids',      # Internal IDs
    'raw_transaction_data'  # Potentially sensitive
  ).merge(
    user_id_hash: Digest::SHA256.hexdigest(user.id.to_s + ENV['RAG_SALT']),
    exported_at: Time.current,
    disclaimer: "Anonymized data for educational AI context"
  )
end
```

---

## 6. JSON STRUCTURE & API DESIGN

### 6.1 Missing Fields
**Question**: Target schema shows `disclaimer` field (line 49) but no PRD generates it. Which PRD adds this?

**Solution**: Add to PRD-2-02 (Core):
```ruby
data[:disclaimer] = "Educational simulation only – not financial advice"
```

### 6.2 Schema Evolution
**Comment**: `historical_net_worth` array could grow unbounded in future epics.

**Alternative**: Store full history in separate `SnapshotHistory` table, keep only 30-day summary in main JSON.
```ruby
# Future optimization
class SnapshotHistory < ApplicationRecord
  belongs_to :financial_snapshot
  # date:date, value:decimal index
end
```

### 6.3 Null vs Empty Semantics
**Objection**: Inconsistent empty value handling (e.g., `[]` vs `{}` vs `null`).
- **Solution**: Document convention:
  - **Arrays**: Empty `[]` means "no items but feature works"
  - **Hashes**: Empty `{}` means "no data"
  - **Null**: `null` means "not applicable" (e.g., no equities for sector weights)

  Add to schema docs:
  ```json
  {
    "top_holdings": [],               // No holdings (valid state)
    "sector_weights": null,           // User has no equities
    "asset_allocation": {},           // No positions at all
    "monthly_transaction_summary": {  // Some data available
      "income": 0,
      "expenses": 0,
      "top_categories": []            // No transactions this month
    }
  }
  ```

---

## 7. TESTING & VALIDATION

### 7.1 Factory Setup
**Objection**: All PRDs reference FactoryBot but don't define factories.
- **Solution**: Create in separate setup PRD or include in PRD-2-01:
  ```ruby
  # spec/factories/financial_snapshots.rb
  FactoryBot.define do
    factory :financial_snapshot do
      association :user
      snapshot_at { Date.current.in_time_zone('America/Chicago').beginning_of_day }
      status { :complete }
      schema_version { 1 }
      data {{
        schema_version: 1,
        as_of: Date.current.to_s,
        total_net_worth: 1_000_000.00,
        # ... full valid structure
      }}

      trait :stale do
        status { :stale }
        data { attributes_for(:financial_snapshot)[:data].merge(
          data_quality: { score: 85, warnings: ["Stale sync detected"] }
        )}
      end

      trait :empty do
        status { :empty }
        data { { schema_version: 1, total_net_worth: 0 } }
      end
    end
  end
  ```

### 7.2 Test Coverage Gaps
**Question**: No integration tests across PRD boundaries. How do you test full snapshot lifecycle?

**Solution**: Add final integration spec to PRD-2-09:
```ruby
# spec/features/snapshot_lifecycle_spec.rb
describe "Full Snapshot Lifecycle", type: :feature do
  it "generates, validates, exports snapshot end-to-end" do
    # 1. Seed Plaid data
    create_list(:position, 10, user: user, asset_class: 'equity')

    # 2. Run job
    FinancialSnapshotJob.perform_now(user)

    # 3. Verify snapshot
    snapshot = user.financial_snapshots.last
    expect(snapshot.status).to eq('complete')
    expect(snapshot.data['total_net_worth']).to be > 0

    # 4. Admin views
    sign_in(admin)
    visit admin_snapshot_path(snapshot)
    expect(page).to have_content(snapshot.data['total_net_worth'])

    # 5. User downloads
    sign_in(user)
    get api_snapshot_download_path(snapshot)
    expect(JSON.parse(response.body)).to eq(snapshot.data)
  end
end
```

### 7.3 Edge Cases
**Missing Tests**:
1. Leap year snapshots (Feb 29)
2. Negative net worth (liabilities > assets)
3. Extremely large portfolios (>$1B, decimal precision)
4. Currency precision (all values 2 decimals?)
5. Concurrent job runs (race condition on unique constraint)

**Solution**: Add to relevant PRD test sections.

---

## 8. WORKFLOW & PROCESS

### 8.1 Git Branch Strategy
**Comment**: Each PRD specifies separate feature branches. Good isolation but...

**Question**: How do you handle dependencies? PRD-2-03 depends on PRD-2-02, but both are separate branches.

**Objection**: Branch per PRD creates merge conflicts if done in parallel.
- **Solution Options**:
  - **Option A** (Sequential): Complete PRD-2-02, merge to main, then branch for 2-03 from updated main
  - **Option B** (Stacked): Branch 2-03 from 2-02 branch: `git checkout -b feature/prd-2-03 feature/prd-2-02`
  - **Recommendation**: Use Option A for v1 (safer), document in Epic overview

### 8.2 Junie Log Requirement
**Comment**: Every PRD references Junie log but path may not exist.

**Question**: Does `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` exist? If not, PRDs will fail.

**Solution**: Add to Epic 2 prerequisites:
```markdown
## Prerequisites
1. Ensure junie-log-requirement.md exists and is up to date
2. Confirm all referenced UI templates exist:
   - knowledge_base/UI/STYLE_GUIDE.md
   - knowledge_base/UI/templates/general.md
   - knowledge_base/UI/templates/table.md
3. Verify Epic 1 SecurityEnrichment columns are deployed (or fallback logic ready)
```

---

## 9. MISSING SPECIFICATIONS

### 9.1 Rollback Strategy
**Objection**: No documented way to roll back if snapshot job corrupts data.

**Solution**: Add to PRD-2-02:
```ruby
# In FinancialSnapshot model
def self.rollback_to_date(user, date)
  # Soft delete newer snapshots
  where(user: user)
    .where('snapshot_at > ?', date)
    .update_all(status: :rolled_back, updated_at: Time.current)
end
```

### 9.2 Monitoring & Alerting
**Question**: How do you know if job fails for many users?

**Solution**: Add observability PRD or include in PRD-2-02:
```ruby
# After job
if snapshot.status == :error
  Metrics.increment('snapshot.errors', tags: ["user:#{user.id}"])
  SlackNotifier.ping("Snapshot failed for user #{user.id}: #{error}")
end

# Daily summary
DailySnapshotSummaryJob # Reports % success, avg runtime, common errors
```

### 9.3 Backfill Strategy
**Comment**: PRD-2-06:451 defers backfill but doesn't define future epic.

**Solution**: Add "Epic 2.5: Historical Backfill" outline:
```markdown
### Epic 2.5: Historical Snapshot Backfill (Future)
- Fetch historical Plaid data (if available)
- Reconstruct snapshots using point-in-time holdings
- Validate against known balances
- Batch processing to avoid API rate limits
```

---

## 10. RECOMMENDATIONS

### High Priority (Must Address Before Implementation)
1. **Timezone normalization strategy** (Section 2.1) — prevents subtle bugs
2. **Error handling for missing data** (Section 4.1) — defines behavior
3. **Admin authorization mechanism** (Section 5.2) — security critical
4. **Percentage normalization** (Section 2.4) — prevents validation failures
5. **Job staggering** (Section 3.1) — avoids production issues

### Medium Priority (Address During Implementation)
6. Schema version migration (Section 1.2)
7. Data quality warning catalog (Section 2.3)
8. Query optimization baselines (Section 3.2)
9. RAG sanitization field list (Section 5.3)
10. Git branch workflow clarification (Section 8.1)

### Low Priority (Nice to Have)
11. Arel removal in favor of AR (Section 1.1)
12. Historical data table split (Section 6.2)
13. Full lifecycle integration test (Section 7.2)
14. Monitoring/alerting (Section 9.2)
15. Backfill epic outline (Section 9.3)

---

## 11. QUESTIONS REQUIRING ANSWERS

1. **Performance**: What's the expected user count at launch? 10? 100? 1000?
2. **Concurrency**: Can users manually trigger snapshots or only automated daily?
3. **Versioning**: When does schema_version increment? Who decides?
4. **Timezone**: Should app support multiple timezones or always CST?
5. **Data Retention**: How long to keep snapshots? Archive policy?
6. **Epic 1 Status**: Are SecurityEnrichment columns actually live or is fallback required for v1?
7. **BI Integration**: Is Tableau export (PRD-2-08) a real requirement or placeholder?
8. **Curriculum Integration**: How will AI/curriculum consume RAG context? REST API? File export?
9. **Feature Flag**: Is `ENABLE_NEW_LAYOUT` per-user or global? How to enable for beta users?
10. **Go-Live**: Target date for Epic 2 completion?

---

## 12. FINAL VERDICT

**Overall Assessment**: **B+ / 85%** — Solid foundation with clear structure, but needs refinement in error handling, performance planning, and edge case definitions.

**Strengths**:
- Clean separation of concerns (DataProvider)
- Comprehensive PRD breakdown
- Good test scaffolding
- Forward-thinking schema versioning

**Weaknesses**:
- Underspecified error handling
- Missing performance baselines
- Timezone complexity not addressed
- No monitoring/observability plan

**Recommendation**: Address High Priority items (1-5) before starting PRD-2-02. Medium Priority items can be tackled during implementation. Low Priority items are optional for v1.

**Estimated Risk**: **Medium** — Most risks have clear solutions provided above. Main unknowns are Epic 1 dependency status and production user volume.
