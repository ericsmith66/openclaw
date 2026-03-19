# Epic 3 Feedback v2: Additional Observations After grok_eric Review

**Reviewer:** Claude Sonnet 4.5
**Date:** 2026-01-26
**Previous Review:** `0000-Overview-epic-3-feedback.md`
**grok_eric Comments:** `0000-Overview-epic-3-grok_eric-comments.md`
**Status:** Epic overview updated with all high-priority grok_eric decisions

---

## Summary of Updates Applied to Epic 3 Overview

All critical decisions from grok_eric review have been incorporated into `0000-Overview-epic-3.md`:

✅ **Architecture clarified**: Single `/net_worth` route with Turbo-driven sections (not separate pages)
✅ **Component hierarchy documented**: Reference to `app/views/net_worth/components/README.md` added
✅ **Data schema requirement**: `financial_snapshot_data_schema.md` + `FinancialSnapshotDataValidator` class specified
✅ **PRD-3-13 performance fix**: Clarified to use only `historical_totals` from latest snapshot (no DB queries)
✅ **Error handling**: Added to all PRDs with specific fallback patterns
✅ **Empty states**: Standardized `NetWorth::EmptyStateComponent` with context params
✅ **Turbo Frame IDs**: Unique IDs specified for all interactive zones
✅ **Rate limiting**: rack-attack implementation detailed in PRD-3-17
✅ **Job broadcast**: Turbo Stream broadcast mechanism specified in PRD-3-17
✅ **Accessibility**: WCAG 2.1 AA target + axe-core tests + symbol+color pattern
✅ **Mobile**: Touch target specs (≥44×44px) + responsive requirements + test viewport
✅ **CSV export schema**: Headers specified with reference to schema doc
✅ **POC deprecation**: TODO comment pattern specified

---

## Additional Observations & Recommendations

### 1. Pre-Implementation Documentation Needs

**Observation:** Four documents are referenced but don't exist yet, blocking Epic 3 start.

**Required Documents (Must-Have Before PRD-3-10):**

1. **`knowledge_base/schemas/financial_snapshot_data_schema.md`**
   - Complete JSON structure with all keys
   - Example payload with realistic fake data
   - CSV export schema specifications
   - Version history for schema changes

2. **`app/views/net_worth/components/README.md`**
   - ASCII or Mermaid hierarchy diagram
   - Component composition patterns
   - Shared base component usage
   - Turbo Frame integration examples

3. **`app/models/financial_snapshot_data_validator.rb`** (or in validators/)
   - PORO validation class
   - Called in `FinancialSnapshot` before_save
   - Test coverage in snapshot job specs
   - Clear error messages for debugging

4. **PRD Error Handling Template**
   - Standard "Error Scenarios & Fallbacks" section structure
   - Can be added to `knowledge_base/templates/prd_template.md`
   - Apply to all Epic 3 PRDs before implementation

**Recommendation:** Create these four items in single prep task before starting PRD-3-10.

---

### 2. Testing Infrastructure Setup

**Observation:** New testing tools and patterns are required but not yet configured.

**Required Gem Installations:**
```ruby
# Gemfile
group :test do
  gem 'axe-core-capybara'    # WCAG 2.1 AA automated testing
  gem 'cuprite'              # Faster headless Chrome driver
  gem 'rack-attack'          # Rate limiting (also needed in production)
end
```

**Required Test Setup Tasks:**
1. Configure Cuprite driver in `spec/support/capybara.rb`
2. Add axe-core helper to `spec/support/axe_helper.rb`
3. Create fixture snapshot data in `spec/fixtures/financial_snapshots/`
4. Add mobile viewport helper: `resize_to_mobile(width: 375, height: 667)`
5. Configure rack-attack test environment settings
6. Add VCR/WebMock for Plaid API mocking (if not already present)

**Recommendation:** Complete testing infrastructure setup in PRD-3-18 or as separate pre-task.

---

### 3. Stimulus Controller Strategy

**Observation:** Multiple PRDs mention "Stimulus controllers for client-side interactions" but no guidance on when to use vs Turbo.

**Decision Needed:** Create guidelines for Stimulus vs Turbo choice:

**Use Stimulus (client-side) when:**
- Data already present in DOM (table sorting, filtering)
- Purely UI state changes (expand/collapse, toggle visibility)
- Interaction doesn't require new data from server
- Performance critical (avoid network round-trip)

**Use Turbo Frames/Streams when:**
- Need fresh data from server (full holdings list, updated sync status)
- Need to persist state server-side
- Operation requires authorization check
- Need to update multiple disconnected DOM sections

**Specific to Epic 3:**
- Holdings expand: Turbo Frame (may need server-side pagination if >100 holdings)
- Table sorting: Stimulus if <50 rows AND already in DOM, else Turbo
- Chart toggle (pie/bar): Stimulus (same data, different presentation)
- Sync status: Turbo Stream (server-side job state)

**Recommendation:** Add Stimulus vs Turbo decision matrix to "Key Guidance" section or component README.

---

### 4. Component Preview/Documentation System

**Observation:** No mention of ViewComponent previews for component development/QA.

**Suggestion:** Use ViewComponent's built-in preview system:

```ruby
# spec/components/previews/net_worth/summary_card_component_preview.rb
class NetWorth::SummaryCardComponentPreview < ViewComponent::Preview
  def default
    render NetWorth::SummaryCardComponent.new(
      summary: {
        total: 1_234_567.89,
        day_delta_usd: 12_345,
        day_delta_pct: 1.2,
        thirty_day_delta_usd: -45_678,
        thirty_day_delta_pct: -3.8
      }
    )
  end

  def empty_state
    render NetWorth::SummaryCardComponent.new(summary: nil)
  end

  def large_numbers
    render NetWorth::SummaryCardComponent.new(
      summary: {
        total: 987_654_321.12,
        day_delta_usd: 9_876_543,
        day_delta_pct: 15.7,
        thirty_day_delta_usd: 87_654_321,
        thirty_day_delta_pct: 42.3
      }
    )
  end
end
```

Mount at `/rails/view_components` in development for visual QA.

**Benefits:**
- Visual regression testing
- Easier QA across states (normal, empty, error, edge cases)
- Living documentation for designers/stakeholders
- Faster iteration without full Rails stack

**Recommendation:** Add component preview creation to each PRD's "Test Cases" section.

---

### 5. Data Migration & Backfill Considerations

**Observation:** Epic 3 assumes `FinancialSnapshot.data` already has correct schema, but existing snapshots may not.

**Questions:**
1. Do existing production/staging snapshots have all required keys (`net_worth_summary`, `asset_allocation`, `sector_weights`, `historical_totals`)?
2. If schema changed during Epic 2, do old snapshots need backfill?
3. What happens if user's latest snapshot has old schema format?

**Potential Issues:**
- User sees broken dashboard due to missing keys
- Components fail with `NoMethodError` on expected keys
- Inconsistent data between users with old vs new snapshots

**Solutions:**
1. **Short-term (Epic 3):** Defensive coding in components—always use `data['key'] || {}` with fallbacks
2. **Medium-term:** Data migration to backfill old snapshots with new schema
3. **Long-term:** Schema versioning in snapshots (add `data_schema_version` field)

**Recommendation:**
- Add schema version check to `FinancialSnapshotDataValidator`
- If old schema detected, enqueue re-sync job automatically
- Add migration task: `rails data:backfill_snapshot_schemas`

---

### 6. Charting Library Color Consistency

**Observation:** Multiple PRDs use Chartkick for different chart types but don't specify color palette.

**Issue:** Default Chart.js colors may not match DaisyUI theme or brand colors.

**Solution:** Define chart color palette in `financial_snapshot_data_schema.md`:

```ruby
# Chart color mapping
ASSET_CLASS_COLORS = {
  'Equities' => '#3b82f6',      # blue-500
  'Fixed Income' => '#10b981',  # green-500
  'Real Estate' => '#f59e0b',   # amber-500
  'Cash' => '#6366f1',          # indigo-500
  'Alternatives' => '#8b5cf6',  # violet-500
  'Other' => '#6b7280'          # gray-500
}.freeze

SECTOR_COLORS = {
  'Technology' => '#3b82f6',
  'Healthcare' => '#10b981',
  'Financial' => '#f59e0b',
  # ... etc
}.freeze

# Pass to Chartkick:
<%= pie_chart allocation_data, colors: ASSET_CLASS_COLORS.values %>
```

**Benefits:**
- Consistent colors across all charts
- Matches DaisyUI semantic colors
- Accessible contrast ratios
- Recognizable color associations (e.g., green for income)

**Recommendation:** Add color palette to schema doc; apply in PRD-3-11 and PRD-3-12.

---

### 7. Snapshot Sync Frequency & Staleness Indicators

**Observation:** PRD-3-17 has manual refresh but no guidance on data staleness awareness.

**Questions:**
1. Should UI show "Data as of [timestamp]" on all components?
2. What if snapshot is >24 hours old—warning indicator?
3. Auto-refresh prompt if user visits dashboard and data is stale?

**Potential Enhancement (Future, not Epic 3):**
```html
<div class="alert alert-warning" data-controller="staleness">
  <svg>...</svg>
  <span>Your net worth data is 3 days old. <a href="/net_worth/sync">Refresh now</a></span>
</div>
```

Show if `snapshot.created_at < 24.hours.ago`.

**Recommendation for Epic 3:**
- Add "Last updated [time_ago]" timestamp to summary card (PRD-3-10)
- No staleness warnings yet (defer to future epic)
- Document timestamp display location in PRD-3-10

---

### 8. Transactions Detail Route Clarity

**Observation:** PRD-3-15 mentions "link to nested route (e.g., /net_worth/transactions)" but routing not specified.

**Question:** Is transactions detail view part of Epic 3 or deferred?

**If Epic 3 scope:**
- Add PRD-3-19 for transactions detail view
- Update dependency chain (PRD-3-15 → PRD-3-19 → PRD-3-18)
- Define Turbo Frame vs separate page
- Specify filtering/sorting/pagination requirements

**If deferred:**
- Change PRD-3-15 link to `#` with tooltip "Coming soon"
- Or remove link entirely, just show summary cards
- Document deferral decision in PRD-3-15

**Recommendation:** Clarify scope—likely defer to Epic 4 given Epic 3 already has 9 PRDs. Update PRD-3-15 to remove link or mark as placeholder.

---

### 9. Holdings Detail Route Clarity

**Observation:** Similar to #8, PRD-3-14 mentions "Link to detailed holding view if future" but unclear.

**Recommendation:** Same as #8—clarify scope and defer to future epic. Focus Epic 3 on summary views only.

---

### 10. Empty State CTAs and Account Linking

**Observation:** Empty state messages reference "sync accounts" but linking flow not in Epic 3 scope.

**Questions:**
1. Where does "Sync accounts to view your net worth" CTA link to?
2. Is Plaid Link integration in Epic 2 or separate?
3. If no accounts linked → different empty state than "no snapshot"?

**Empty State Hierarchy:**
1. **No Plaid accounts linked**: "Connect your financial accounts to get started" → CTA to Plaid Link
2. **Accounts linked but no snapshot**: "Syncing your accounts..." (show spinner if job running, else "Sync now" button)
3. **Snapshot exists but specific data missing**: "No [holdings/transactions/etc] data available—check your connected accounts"

**Recommendation:** Define empty state hierarchy in `EmptyStateComponent` with distinct contexts:
- `:no_plaid_accounts` → link to account connection flow
- `:no_snapshot` → sync button
- `:no_specific_data` → generic message + support link

Add to schema doc or component README.

---

### 11. Security: Financial Data Exposure in Turbo Streams

**Observation:** Turbo broadcasts over websockets could expose sensitive financial data.

**Security Considerations:**
1. Are Turbo Stream channels user-scoped properly?
2. Could user A intercept user B's sync status broadcast?
3. Is channel subscription authenticated?

**Required Verification:**
```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      if verified_user = env['warden'].user
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end

# User-scoped broadcast
user.broadcast_replace_to("net_worth:sync_status:#{user.id}", ...)
```

**Recommendation:**
- Add security review to PRD-3-17 acceptance criteria
- Verify channel authentication in integration tests
- Document broadcast scoping pattern in architectural context

---

### 12. Performance: N+1 Queries in Component Rendering

**Observation:** Components receive nested data (holdings array, allocations array) that might trigger N+1s if not careful.

**Potential Issue:**
```ruby
# Component iterating over holdings
<% holdings.each do |holding| %>
  <%= holding.account.name %>  # N+1 if account not eager loaded
<% end %>
```

**Epic 3 Mitigation:**
Since all data comes from snapshot JSON (not ActiveRecord relations), N+1 risk is low. BUT if components ever call associations (e.g., `snapshot.user.profile`), issue could arise.

**Recommendation:**
- Add "No ActiveRecord associations in component rendering" to Key Guidance
- Use `bullet` gem in development to catch N+1s
- All component data should be plain Ruby hashes/arrays from snapshot JSON

---

### 13. Internationalization Considerations

**Observation:** No mention of i18n, but currency/date formatting may need localization.

**Questions:**
1. Target audience: US-only or international?
2. Multi-currency portfolio support needed?
3. Date format: MM/DD/YYYY (US) vs DD/MM/YYYY (EU) vs ISO?

**If US-only (likely for HNW young adults initially):**
- Hard-code `number_to_currency(value, unit: '$')`
- Use `l(date, format: :long)` with US locale
- Can defer i18n to future epic

**If international:**
- Add `user.currency_preference` field
- Use `number_to_currency(value, unit: user.currency_symbol)`
- Store all amounts in USD equivalent + original currency
- Major schema impact—should be in Epic 2

**Recommendation:** Document assumption of US-only / USD-only in Epic 3 overview. Defer multi-currency to future epic.

---

### 14. Error Tracking & Observability

**Observation:** Error handling mentions "log to Sentry" but no instrumentation guidance.

**Required Sentry/Logging Setup:**
```ruby
# app/components/net_worth/base_card_component.rb
class NetWorth::BaseCardComponent < ViewComponent::Base
  def initialize(data:)
    @data = data
  rescue JSON::ParserError => e
    Sentry.capture_exception(e, extra: { component: self.class.name, data: data })
    @data = {}
    @error_state = :corrupt_json
  end
end
```

**Observability Checklist:**
1. All JSON parse failures tagged with `component: class_name`
2. Snapshot fetch failures logged with user context
3. Turbo Stream broadcast failures tracked
4. Rate limit hits monitored (threshold alerts if >10% of requests)
5. Chart rendering errors captured (Chartkick JS errors)

**Recommendation:**
- Add error tracking setup to PRD-3-18 QA section
- Define Sentry tags convention: `epic:3, component:net_worth, prd:3-10`
- Set up error rate alerts in staging before production deploy

---

### 15. Snapshot Data Integrity & Validation

**Observation:** What if Plaid returns bad data that passes schema validation but is nonsensical?

**Examples of Bad Data:**
- Net worth = $0.00 (user has $5M, suddenly shows $0 due to Plaid outage)
- Holdings percentages sum to 1500% (calculation error)
- Negative asset values (debt miscategorized)
- Day delta = $999,999,999 (obviously wrong)

**Validation Beyond Schema:**
```ruby
# app/models/financial_snapshot_data_validator.rb
class FinancialSnapshotDataValidator
  def validate(data)
    errors = []

    # Schema validation...

    # Integrity checks
    if data['net_worth_summary']['total'] <= 0 && previous_snapshot.total > 0
      errors << "Net worth dropped to zero unexpectedly"
    end

    if data['asset_allocation'].sum { |a| a['pct'] } > 105 # allow 5% rounding
      errors << "Allocation percentages exceed 100%"
    end

    if data['holdings'].any? { |h| h['value'] < 0 }
      errors << "Negative holding values detected"
    end

    # Flag for review but don't block save
    flag_for_admin_review if errors.any?

    errors
  end
end
```

**Recommendation:**
- Add integrity checks to validator (beyond schema)
- Log warnings for suspicious data
- Add admin alert in Mission Control for flagged snapshots
- Display warning banner to user: "Some data looks unusual—verify with your bank"

---

## Prioritized Action Items for grok_eric

### Critical (Before Starting PRD-3-10):
1. ✅ Review and approve Epic 3 overview updates
2. ⬜ Create `knowledge_base/schemas/financial_snapshot_data_schema.md`
3. ⬜ Create `FinancialSnapshotDataValidator` PORO class
4. ⬜ Create `app/views/net_worth/components/README.md` with hierarchy diagram
5. ⬜ Add error handling template to PRD template or create separate doc
6. ⬜ Clarify scope: transactions/holdings detail views in Epic 3 or deferred?

### High Priority (During PRD-3-10 to PRD-3-15):
7. ⬜ Install testing gems: axe-core-capybara, cuprite, rack-attack
8. ⬜ Configure test infrastructure (Cuprite driver, axe helper, fixtures)
9. ⬜ Define chart color palette (add to schema doc)
10. ⬜ Verify Turbo Stream channel authentication/scoping
11. ⬜ Add empty state hierarchy (no accounts vs no snapshot vs no data)
12. ⬜ Add Stimulus vs Turbo decision matrix to Key Guidance

### Medium Priority (PRD-3-16 to PRD-3-18):
13. ⬜ Set up ViewComponent preview system for visual QA
14. ⬜ Configure Sentry tags and error tracking conventions
15. ⬜ Add snapshot integrity checks to validator
16. ⬜ Document i18n assumptions (US/USD only for now)
17. ⬜ Review schema backfill needs for existing snapshots

### Low Priority (Post-Epic 3):
18. ⬜ Consider staleness indicators (defer to Epic 4?)
19. ⬜ Evaluate data migration strategy for schema versions
20. ⬜ Performance monitoring setup (rack-mini-profiler, etc.)

---

## Conclusion

Epic 3 overview is now **production-ready** with all high-priority grok_eric decisions incorporated. The remaining action items above are mostly infrastructure setup and documentation—all clearly scoped and achievable before PRD-3-10 implementation starts.

**Biggest Remaining Risks:**
1. **Data schema not documented yet** (blocks all PRDs) → Highest priority
2. **Empty state flow unclear** (no accounts vs no snapshot) → Needs quick decision
3. **Testing infrastructure not set up** (will slow down PRD velocity) → Do in parallel with PRD-3-10

**Recommended Next Step:**
Create schema doc + validator + component README in single "Epic 3 Prep" task (estimate: 2-4 hours), then proceed confidently to PRD-3-10.
