# Epic 2: Additional Questions & Clarifications

## Overview
This document contains additional questions and clarifications needed after incorporating feedback from the Grok/Eric comments. All high-priority feedback has been incorporated into the PRDs.

## Questions for Eric

### 1. User Role Migration Timing
**Question**: When should the User `role` enum migration be created?
- PRD-2-07 (Admin Preview) requires `current_user.admin?`
- Should this be done as a separate prerequisite before starting PRD-2-01?
- Or can it wait until PRD-2-07?

**Recommendation**: Create role migration as prerequisite to avoid blocking PRD-2-07.

**Migration needed**:
```ruby
class AddRoleToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :role, :integer, default: 0, null: false
    add_index :users, :role

    # Enum values: 0=intern, 1=advisor, 2=admin
  end
end
```

### 2. DataQualityValidator Service Creation
**Question**: Should `Reporting::DataQualityValidator` be created in PRD-2-01 or PRD-2-02?
- PRD-2-01 mentions it for `data_quality_score` method
- PRD-2-02 uses it for warnings/validation
- Grok/Eric comments suggest creating it but don't specify PRD

**Recommendation**: Create in PRD-2-01 as part of model setup (simpler, cleaner dependency).

**Implementation needed**:
```ruby
# app/services/reporting/data_quality_validator.rb
module Reporting
  class DataQualityValidator
    CHECKS = {
      missing_price_data: 5,      # 5 points deduction
      stale_sync: 10,              # 10 points deduction
      allocation_mismatch: 15,     # 15 points deduction
      negative_balances: 5         # 5 points deduction
    }.freeze

    def initialize(user, data)
      @user = user
      @data = data
    end

    def score
      100 - warnings.sum { |w| CHECKS[w[:type].to_sym] || 5 }
    end

    def warnings
      # Return array of {type:, message:} hashes
    end
  end
end
```

### 3. Chart Library Selection
**Question**: Which chart library for PRD-2-09 dashboard?
- **Chartkick** (simplest, gem-based, uses Chart.js under the hood)
- **Chart.js** (direct JavaScript, more control)
- **ApexCharts** (modern, beautiful, but heavier)

**Recommendation**: Chartkick for v1 (fastest implementation, good enough).

**Trade-offs**:
- Chartkick: ✅ Fast, ✅ Rails-native, ❌ Less customization
- Chart.js: ✅ Flexible, ❌ More JavaScript required
- ApexCharts: ✅ Beautiful, ❌ Overkill for v1

### 4. ENV Variables Documentation
**Question**: Should we create `.env.example` updates as part of Epic 2?

**Variables needed**:
```bash
# Epic 2 - Financial Snapshots
ENABLE_NEW_LAYOUT=true          # Feature flag for new dashboard (PRD-2-00, 2-09)
RAG_SALT=your-random-salt-here  # Salt for RAG context hashing (PRD-2-08)
APP_TIMEZONE=America/Chicago    # Moved to config, but document here
```

**Recommendation**: Add to `.env.example` as part of PRD-2-08.

### 5. Snapshot Schema Policy Document
**Question**: When should `knowledge_base/data/snapshot-schema-policy.md` be created?
- Listed in prerequisites (overview)
- Referenced in PRD-2-01 schema versioning section

**Recommendation**: Create as part of PRD-2-01 implementation.

**Content needed**:
```markdown
# Snapshot Schema Versioning Policy

## Version 1 (Current)
- Initial schema (see Target Snapshot JSON Structure v1)
- Fields: schema_version, as_of, total_net_worth, deltas, allocations, etc.

## Version Bump Rules
1. **Breaking changes trigger version bump**:
   - Required field added
   - Field renamed
   - Field type changed
   - Field removed

2. **Non-breaking changes do NOT bump version**:
   - Optional field added
   - Field deprecated but kept
   - Value format clarification

## Migration Strategy
- Use `Reporting::SnapshotAdapter.read(version, data)` to normalize old versions
- Adapter pattern allows reading any version as current schema
- Background jobs can upgrade old snapshots on-demand

## Example: v1 → v2
If we add required field `liabilities_breakdown`:
- Bump schema_version to 2
- v1 snapshots still readable via adapter (fills empty array)
- New snapshots use v2
```

### 6. Performance Benchmarking
**Question**: Should we add performance benchmarks to CI/test suite?
- PRD-2-01b mentions `spec/benchmarks/data_provider_benchmark.rb`
- PRD-2-02 mentions <5s per user baseline

**Recommendation**: Add benchmarks but don't fail CI if slow (warning only).

**RSpec config**:
```ruby
# spec/support/performance_helpers.rb
RSpec.configure do |config|
  config.before(:each, type: :benchmark) do
    # Skip benchmarks in CI unless explicitly enabled
    skip "Benchmarks disabled in CI" if ENV['CI'] && !ENV['RUN_BENCHMARKS']
  end
end
```

### 7. Sidekiq Dashboard Access
**Question**: Should admin users have access to Sidekiq web UI?
- Useful for monitoring FinancialSnapshotJob
- Not specified in any PRD

**Recommendation**: Add to PRD-2-07 (Admin Preview) or as separate mini-PRD.

**Implementation**:
```ruby
# config/routes.rb
require 'sidekiq/web'

authenticate :user, ->(user) { user.admin? } do
  mount Sidekiq::Web => '/admin/sidekiq'
end
```

### 8. Snapshot Regeneration
**Question**: Should admins be able to manually trigger snapshot regeneration?
- Useful for debugging/testing
- Not specified in PRDs

**Recommendation**: Add simple button in PRD-2-07 admin interface.

**Controller action**:
```ruby
# Admin::SnapshotsController
def regenerate
  @snapshot = FinancialSnapshot.find(params[:id])
  authorize_admin!

  FinancialSnapshotJob.perform_later(@snapshot.user, force: true)
  redirect_to admin_snapshot_path(@snapshot), notice: "Regeneration queued"
end
```

### 9. Mobile Responsive Design
**Question**: Is mobile responsiveness required for v1 dashboard (PRD-2-09)?
- Not explicitly required in PRDs
- 22-30 audience likely uses mobile

**Recommendation**: Include basic responsive grid (DaisyUI handles most of it), but don't optimize heavily for mobile in v1.

### 10. Error Notification Strategy
**Question**: How should snapshot job errors be surfaced to users?
- PRD-2-02 mentions logging only
- Should users see "Snapshot generation failed" message?

**Recommendation**: For v1, admin-only visibility (in admin preview). User just sees stale data or placeholder.

## Clarifications Needed

### A. Position/Account/Liability Model Assumptions
**Assumption**: These models exist with these attributes:
- `Position`: `user_id`, `current_value`, `asset_class`, `sector`, `ticker`, `name`
- `Account`: `user_id`, `current_balance`
- `Liability`: `user_id`, `current_balance`
- `Transaction`: `user_id`, `amount`, `category`, `date`
- `Item`: `user_id`, `last_successful_update`

**Question**: Are these correct? Any missing fields?

### B. SecurityEnrichment Fallback
**Assumption**: Fallback logic for missing SecurityEnrichment data:
1. Try `position.asset_class` (from SecurityEnrichment if Epic 1 complete)
2. Fall back to `holding.asset_class` (raw Plaid data)
3. Fall back to `holding.data['type']` (JSON field)
4. Default to 'other'

**Question**: Is this fallback hierarchy correct?

### C. Transaction Category Mapping
**Question**: Are Plaid transaction categories already normalized, or do we need mapping?
- E.g., "Food and Drink" → "Groceries"
- Or use Plaid categories as-is?

**Recommendation**: Use Plaid categories as-is for v1.

### D. Beta User Rollout
**Question**: How will beta users be selected for `ENABLE_NEW_LAYOUT`?
- Global ENV flag (all or none)
- Or per-user feature flag (e.g., via Flipper gem)?

**Current assumption**: Global ENV flag for v1 (simpler).

## Implementation Notes

### Migration Order
Recommended migration sequence before starting PRD-2-01:
1. User role migration (if not exists)
2. APP_TIMEZONE constant in `config/initializers/constants.rb`
3. Update `config/application.rb` with `config.time_zone = 'America/Chicago'`
4. Create `knowledge_base/data/snapshot-schema-policy.md`

### Testing Strategy
Each PRD should include:
- ✅ Model specs (if applicable)
- ✅ Service specs
- ✅ Job specs
- ✅ Controller specs (if applicable)
- ✅ Feature specs (PRD-2-09 only)
- ✅ Component specs (PRD-2-09 only)
- ❓ Benchmark specs (optional, PRD-2-01b, PRD-2-02)
- ❓ Integration specs (lifecycle test in PRD-2-09)

### Code Review Checkpoints
After each PRD commit, human should verify:
1. All tests green
2. No N+1 queries (check with bullet gem if available)
3. Proper indexing (EXPLAIN in console)
4. Error handling comprehensive
5. Memoization working (benchmark if needed)

## Next Steps
1. **Eric to confirm**:
   - User role migration timing (before PRD-2-01?)
   - DataQualityValidator creation (PRD-2-01 or PRD-2-02?)
   - Chart library preference (Chartkick?)
   - Mobile responsive requirement for v1

2. **Junie to proceed**:
   - Start with PRD-2-01 after Eric confirms prerequisites
   - Log plan/questions per PRD requirements
   - Commit only green code
   - Request review after each PRD

3. **Prerequisites to create**:
   - [ ] User role migration
   - [ ] APP_TIMEZONE constant
   - [ ] `snapshot-schema-policy.md` document
   - [ ] `.env.example` updates
   - [ ] DataQualityValidator service (PRD-2-01 or PRD-2-02)

## Summary
All major feedback from Grok/Eric comments has been incorporated into PRDs. The questions above are minor clarifications that won't block implementation—sensible defaults have been recommended for each. Junie can proceed with PRD-2-01 and ask these questions in Junie log as needed.
