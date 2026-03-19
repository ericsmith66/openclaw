Here is the full and complete copy of Junie's Markdown feedback document, reproduced exactly as provided in your query. I've incorporated my inline comments (as **grok_eric:** notes) where they add clarification, decisions, corrections, or approvals based on current repo state (from latest scan: main branch last active Jan 24-25 2026 on PRD-2 series; no PRD-3 commits, no schemas/financial_snapshot_data_schema.md visible, no app/components/net_worth/, knowledge_base/schemas/ exists but empty of that file, epics/ dir present but no Epic 3 MDs confirmed). These comments aim to resolve open questions, confirm deferrals, and prioritize next actions without altering Junie's original structure.

# Epic 3 Feedback v2: Additional Observations After grok_eric Review

**Reviewer:** Claude Sonnet 4.5  
**Date:** 2026-01-26  
**Previous Review:** `0000-Overview-epic-3-feedback.md`  
**grok_eric Comments:** `0000-Overview-epic-3-grok_eric-comments.md`  
**Status:** Epic overview updated with all high-priority grok_eric decisions

**grok_eric:** Status confirmed—overview updates look solid. No conflicting commits since Jan 24 (PRD-2-09 dashboard UI). Repo still at Epic 2 completion; proceed to prep docs then PRD-3-10.

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

**grok_eric:** All ✅ items approved. Add one more: ✅ **No ActiveRecord in components** — enforce plain hash/array usage from snapshot JSON only (mitigates N+1 risk noted in #12).

---

## Additional Observations & Recommendations

### 1. Pre-Implementation Documentation Needs

**Observation:** Four documents are referenced but don't exist yet, blocking Epic 3 start.  
**Required Documents (Must-Have Before PRD-3-10):**
1. **`knowledge_base/schemas/financial_snapshot_data_schema.md`** - Complete JSON structure with all keys - Example payload with realistic fake data - CSV export schema specifications - Version history for schema changes
2. **`app/views/net_worth/components/README.md`** - ASCII or Mermaid hierarchy diagram - Component composition patterns - Shared base component usage - Turbo Frame integration examples
3. **`app/models/financial_snapshot_data_validator.rb`** (or in validators/) - PORO validation class - Called in `FinancialSnapshot` before_save - Test coverage in snapshot job specs - Clear error messages for debugging
4. **PRD Error Handling Template** - Standard "Error Scenarios & Fallbacks" section structure - Can be added to `knowledge_base/templates/prd_template.md` - Apply to all Epic 3 PRDs before implementation

**Recommendation:** Create these four items in single prep task before starting PRD-3-10.

**grok_eric:** Highest priority—repo scan confirms knowledge_base/schemas/ dir exists but file missing. Create #1 first (schema doc) with example JSON covering: net_worth_summary, asset_allocation[], sector_weights[], holdings[], transactions_summary, historical_totals[]. Use realistic HNW fake data ($10M+ total, diversified). Then validator (#3) as PORO with schema + integrity checks (e.g., pct sums ≈100%, no negative values). Bundle into "Epic 3 Prep PR" branch. Defer #2 until after PRD-3-10 if needed—start with inline component comments.

### 2. Testing Infrastructure Setup

**Observation:** New testing tools and patterns are required but not yet configured.  
**Required Gem Installations:**
```ruby
# Gemfile
group :test do
  gem 'axe-core-capybara' # WCAG 2.1 AA automated testing
  gem 'cuprite'           # Faster headless Chrome driver
  gem 'rack-attack'       # Rate limiting (also needed in production)
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

**grok_eric:** Approve gems + setup. Do as separate "Epic 3 Test Prep" task before PRD-3-10. Include fixture JSON files matching schema doc. rack-attack needed for PRD-3-17 anyway.

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

**grok_eric:** Approved matrix—add to overview Key Guidance. For Epic 3: prefer Turbo for data-dependent actions (expand, sync); Stimulus for pure UI (chart toggle, local sort on small tables). No Stimulus install yet? Add to Gemfile if missing (`stimulus-rails`).

### 4. Component Preview/Documentation System

**Observation:** No mention of ViewComponent previews for component development/QA.  
**Suggestion:** Use ViewComponent's built-in preview system:
```ruby
# spec/components/previews/net_worth/summary_card_component_preview.rb
class NetWorth::SummaryCardComponentPreview < ViewComponent::Preview
  def default
    render NetWorth::SummaryCardComponent.new(
      summary: { total: 1_234_567.89, day_delta_usd: 12_345, day_delta_pct: 1.2, thirty_day_delta_usd: -45_678, thirty_day_delta_pct: -3.8 }
    )
  end
  # ... other variants
end
```
Mount at `/rails/view_components` in development for visual QA.

**Benefits:** Visual regression testing, easier QA, living docs.  
**Recommendation:** Add component preview creation to each PRD's "Test Cases" section.

**grok_eric:** Strong yes—add to every PRD Test Cases. Enable in routes: `draw do get '/rails/view_components', to: 'rails/view_components#index' if Rails.env.development?`. Great for QA before PR merges.

### 5. Data Migration & Backfill Considerations

**Observation:** Epic 3 assumes `FinancialSnapshot.data` already has correct schema, but existing snapshots may not.  
**Questions:**
1. Do existing production/staging snapshots have all required keys?
2. If schema changed during Epic 2, do old snapshots need backfill?
3. What happens if user's latest snapshot has old schema format?

**Potential Issues:** Broken dashboard, NoMethodError, inconsistency.  
**Solutions:**
1. **Short-term (Epic 3):** Defensive coding (`data['key'] || {}` fallbacks)
2. **Medium-term:** Migration/backfill
3. **Long-term:** Schema versioning (`data_schema_version` field)

**Recommendation:** Add schema version check to validator; enqueue re-sync on old version; add `rails data:backfill_snapshot_schemas` task.

**grok_eric:** Repo has no evidence of schema versioning yet. Short-term defensive + version field addition mandatory. Defer full backfill rake task to post-Epic 3 unless old snapshots break dashboard testing. Add `data_schema_version: 1` to new snapshots in job.

### 6. Charting Library Color Consistency

**Observation:** Multiple PRDs use Chartkick but no color palette.  
**Issue:** Defaults may mismatch DaisyUI/brand.  
**Solution:** Define in schema doc:
```ruby
ASSET_CLASS_COLORS = { 'Equities' => '#3b82f6', ... }.freeze
# Usage: pie_chart ..., colors: ASSET_CLASS_COLORS.values
```

**Recommendation:** Add palette to schema doc; apply in PRD-3-11/3-12.

**grok_eric:** Approved—use DaisyUI color tokens where possible (e.g., `var(--fallback-bc, oklch(var(--bc)/1))`). Define 6-8 colors matching neutral/professional theme for young adults.

### 7. Snapshot Sync Frequency & Staleness Indicators

**Observation:** PRD-3-17 manual refresh only; no staleness UI.  
**Questions:** Timestamp display? >24h warning? Auto-prompt?  
**Recommendation for Epic 3:** Add "Last updated [time_ago]" to summary card (PRD-3-10). Defer warnings.

**grok_eric:** Yes—add timestamp to PRD-3-10 hero card ("As of [relative time]"). No warnings in Epic 3; keep simple.

### 8. Transactions Detail Route Clarity

**Observation:** PRD-3-15 link to `/net_worth/transactions` unclear if in scope.  
**Recommendation:** Defer detail view to Epic 4; change link to placeholder or remove.

**grok_eric:** Defer—Epic 3 stays summary-focused. Update PRD-3-15: link = "#" with tooltip "Full transactions view coming soon" or remove link.

### 9. Holdings Detail Route Clarity

**Observation:** Similar to #8.  
**Recommendation:** Defer; focus on summary.

**grok_eric:** Agreed—defer. Remove future-link mention in PRD-3-14.

### 10. Empty State CTAs and Account Linking

**Observation:** Empty states reference sync but linking flow unclear.  
**Empty State Hierarchy:**
1. No Plaid accounts → CTA to Plaid Link
2. Accounts linked but no snapshot → "Sync now"
3. Snapshot exists but missing data → generic

**Recommendation:** Define in `EmptyStateComponent` with contexts.

**grok_eric:** Approved hierarchy. Plaid Link flow from Epic 1/2 (Connect button). Use context symbols in component: `:no_items`, `:sync_pending`, `:data_missing`. Add to PRD-3-10 empty state.

### 11. Security: Financial Data Exposure in Turbo Streams

**Observation:** Turbo broadcasts risk exposure.  
**Required Verification:** User-scoped channels + authenticated connection.

**Recommendation:** Add to PRD-3-17 acceptance criteria; test scoping.

**grok_eric:** Critical—verify `identified_by :current_user` in connection.rb. Broadcast to `net_worth:sync:#{current_user.id}`. Add test: assert no cross-user leak.

### 12. Performance: N+1 Queries in Component Rendering

**Observation:** Low risk (JSON only) but guard against future associations.

**Recommendation:** Ban AR in components; use bullet gem dev.

**grok_eric:** Enforce in Key Guidance: "Components receive only plain Ruby objects from snapshot.data—no ActiveRecord calls."

### 13. Internationalization Considerations

**Observation:** No i18n; assume US/USD.

**Recommendation:** Document US/USD-only; defer multi-currency.

**grok_eric:** Confirmed—US/HNW focus. Hard-code $ and MM/DD/YYYY. Defer i18n.

### 14. Error Tracking & Observability

**Observation:** Sentry/logging guidance missing.

**Recommendation:** Add to PRD-3-18; define tags.

**grok_eric:** Use Rails.logger + Sentry if configured. Add tags: epic:3, prd:"3-10", component:"SummaryCard".

### 15. Snapshot Data Integrity & Validation

**Observation:** Schema pass ≠ sensible data.

**Recommendation:** Add integrity checks (pct sum, no negatives); flag for admin.

**grok_eric:** Yes—extend validator with business rules. Enqueue re-sync on major flags; show user warning banner if flagged.

---

## Prioritized Action Items for grok_eric

### Critical (Before Starting PRD-3-10):
1. ✅ Review and approve Epic 3 overview updates
2. ⬜ Create `knowledge_base/schemas/financial_snapshot_data_schema.md`
3. ⬜ Create `FinancialSnapshotDataValidator` PORO class
4. ⬜ Create `app/views/net_worth/components/README.md` with hierarchy diagram
5. ⬜ Add error handling template to PRD template or create separate doc
6. ⬜ Clarify scope: transactions/holdings detail views in Epic 3 or deferred? → **Deferred to Epic 4**

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

**grok_eric:** Priorities good. Critical #2-5 → single prep branch/PR. High #7-8 → parallel test setup task.

---

## Conclusion

Epic 3 overview is now **production-ready** with all high-priority grok_eric decisions incorporated. The remaining action items above are mostly infrastructure setup and documentation—all clearly scoped and achievable before PRD-3-10 implementation starts.

**Biggest Remaining Risks:**
1. **Data schema not documented yet** (blocks all PRDs) → Highest priority
2. **Empty state flow unclear** (no accounts vs no snapshot) → Needs quick decision
3. **Testing infrastructure not set up** (will slow down PRD velocity) → Do in parallel with PRD-3-10

**Recommended Next Step:** Create schema doc + validator + component README in single "Epic 3 Prep" task (estimate: 2-4 hours), then proceed confidently to PRD-3-10.

**grok_eric:** Agreed—start prep task now. Once schema doc exists, hand off PRD-3-10 to Junie. Questions for you: Any local changes to schema since Jan 24 commits? Ready to create the schema MD?