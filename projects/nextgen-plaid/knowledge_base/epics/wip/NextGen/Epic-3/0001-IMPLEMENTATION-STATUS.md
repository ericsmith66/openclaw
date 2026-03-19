# Epic 3: Implementation Status & Readiness

**Date**: 2026-01-27
**Status**: ⬜ **PENDING PREP TASKS**
**Target Branch**: `epic-3-ui-improvements`

---

## 📋 Document Structure

### Core Documents
- ✅ `0000-Overview-epic-3.md` - Epic overview with architecture, policies, and all guidance
- ✅ `0010-PRD-3-10.md` - Net Worth Summary Card Component (document exists)
- ✅ `0020-PRD-3-11.md` - Asset Allocation View (document exists)
- ✅ `0030-PRD-3-12.md` - Sector Weights View (document exists)
- ✅ `0040-PRD-3-13.md` - Performance View (document exists)
- ✅ `0050-PRD-3-14.md` - Holdings Summary View (document exists)
- ✅ `0060-PRD-3-15.md` - Transactions Summary View (document exists)
- ✅ `0070-PRD-3-16.md` - Snapshot Export Button (document exists)
- ✅ `0080-PRD-3-17.md` - Refresh Snapshot / Sync Status Widget (document + implementation complete)
- ✅ `0090-PRD-3-18.md` - Final Dashboard Polish & Breadcrumbs (document exists)

### Supporting Documents
- ✅ `0000-Overview-epic-3-feedback.md` - Initial Claude review with 18 recommendations
- ✅ `0000-Overview-epic-3-feedback-v2.md` - Secondary review with 15 additional observations
- ✅ `0000-Overview-epic-3-grok_eric-comments.md` - Eric's inline decisions on feedback
- ✅ `0000-Overview-epic-3-grok_eric-comments-v2.md` - Eric's final decisions with priorities
- ✅ `0001-IMPLEMENTATION-STATUS.md` - This document

---

## 🚧 Prerequisites Checklist (BLOCKING)

Before starting PRD-3-10, these **must** be completed:

**Prep audit note (repo reality as of 2026-01-26):** This repo currently appears to be **Minitest-first** (`test/` present, no top-level `spec/`). Several checklist items below reference **RSpec** paths (`spec/support`, `spec/fixtures`) and will need to be adapted to the project’s actual test stack.

### Critical (Epic 3 Prep Task)
1. ⬜ **`knowledge_base/schemas/financial_snapshot_data_schema.md`**
   - Complete JSON structure with all keys (net_worth_summary, asset_allocation[], sector_weights[], holdings[], transactions_summary, historical_totals[])
   - Example payload with realistic HNW fake data ($10M+ total, diversified holdings)
   - CSV export schema: `Account,Symbol,Name,Value,Percentage` for holdings
   - Chart color palette (6-8 DaisyUI-compatible colors for asset classes/sectors)
   - Version history section (start with v1)

2. ⬜ **`app/models/financial_snapshot_data_validator.rb`** (or `app/validators/`)
   - PORO validation class with schema + integrity checks
   - Schema validation: required keys present, correct types
   - Integrity checks:
     - Asset allocation percentages sum ≈100% (tolerance 5%)
     - No negative holdings values (except shorts)
     - Net worth sanity check (>= -$10M, <=$10B for HNW users)
     - Holdings percentages sum ≈100%
   - Called in `FinancialSnapshot` before_save callback
   - Test coverage in `test/validators/financial_snapshot_data_validator_test.rb`
   - Flag suspicious data for admin review (log to `data['data_quality']['warnings']`)

3. ⬜ **`app/views/net_worth/components/README.md`**
   - ASCII or Mermaid hierarchy diagram
   - Component composition patterns
   - Shared base component usage: `NetWorth::BaseCardComponent`
   - Turbo Frame integration examples
   - Stimulus vs Turbo decision guidelines

4. ⬜ **Error Handling Template**
   - Add "Error Scenarios & Fallbacks" section template to `knowledge_base/templates/prd_template.md`
   - Standard patterns:
     - Nil snapshot → `EmptyStateComponent(context: :no_snapshot)`
     - JSON parse failure → log to Sentry + "Data temporarily unavailable"
     - Turbo failures → flash alert + refresh link
   - Apply to all Epic 3 PRDs

   **Audit finding:** `knowledge_base/templates/prd_template.md` does **not** exist in this repo (current `knowledge_base/templates/` only contains `cwa_task_log.md`). Either create `prd_template.md` at that path, or update this checklist to point at the actual PRD template location.

5. ⬜ **`app/components/net_worth/base_card_component.rb`**
   - Base ViewComponent with:
     - Common helpers (formatting, empty states)
     - Error handling wrapper
     - Sentry integration with Epic 3 tags
     - Defensive data access methods (`safe_get(hash, key, default)`)

6. ⬜ **`app/components/net_worth/empty_state_component.rb`**
   - Contexts: `:no_items`, `:sync_pending`, `:data_missing`
   - Optional params: `message_override`, `cta_path`
   - Standard messages per context:
     - `:no_items` → "Connect your financial accounts to get started" + link to Plaid Link
     - `:sync_pending` → "Syncing your accounts..." + spinner
     - `:data_missing` → "No [X] data available—check your connected accounts"

### High Priority (Testing Prep Task)
7. ⬜ **Install Testing Gems**
   ```ruby
   # Gemfile
   group :test do
     gem 'axe-core-capybara'  # WCAG 2.1 AA testing
     gem 'cuprite'            # Faster Chrome driver
   end

   gem 'rack-attack'  # Rate limiting (also production)
   ```

8. ⬜ **Configure Test Infrastructure**
   - `spec/support/capybara.rb` - Cuprite driver config
   - `spec/support/axe_helper.rb` - Accessibility test helper
   - `spec/fixtures/financial_snapshots/` - Sample snapshot JSON files
   - `spec/support/mobile_helper.rb` - `resize_to_mobile(width: 375, height: 667)` method
   - `config/environments/test.rb` - rack-attack test settings
   - VCR/WebMock for Plaid API mocking (if not present)

9. ⬜ **ViewComponent Preview Routes**
   ```ruby
   # config/routes.rb
   if Rails.env.development?
     mount ViewComponent::Preview::Engine, at: "/rails/view_components"
   end
   ```

---

## ✅ Prep Checklist Audit Summary (2026-01-26)

### Confirmed Present
- Epic 3 PRD documents exist (`0010`–`0090`)
- Existing ViewComponents exist under `app/components/` (e.g., `net_worth_hero_component.*`, `asset_allocation_chart_component.*`, `sector_weights_component.*`)

### Missing / Not Yet Implemented (still blocking Epic 3 Prep PR)
- `knowledge_base/schemas/financial_snapshot_data_schema.md` (missing)
- `FinancialSnapshotDataValidator` PORO + tests (missing)
- `app/views/net_worth/components/README.md` (directory/file missing)
- `NetWorth::BaseCardComponent` + `NetWorth::EmptyStateComponent` (implemented on `epic-3-ui-improvements`; still needs Prep PR alignment)
- Test gems: `axe-core-capybara`, `cuprite`, `rack-attack` (not in `Gemfile`)
- ViewComponent preview route mount in `config/routes.rb` (not present)

### Implemented (in repo)
- ✅ PRD-3-10 Net Worth Summary Card
  - Branch: `epic-3-ui-improvements`
  - Key files:
    - `app/components/net_worth/summary_card_component.rb`
    - `app/components/net_worth/summary_card_component.html.erb`
    - `app/views/net_worth/dashboard/show.html.erb` (now renders `turbo_frame_tag "net-worth-summary-frame"`)
  - Notes:
    - Backward compatible with current snapshot data keys (`total_net_worth`, `delta_day`, `delta_30d`) while also supporting `net_worth_summary` if present.
    - Still pending full Epic 3 “Prep” items (schema doc + validator + previews + axe/mobile tests).

- ✅ PRD-3-11 Asset Allocation View
  - Branch: `epic-3-ui-improvements`
  - Key files:
    - `app/components/net_worth/asset_allocation_component.rb`
    - `app/components/net_worth/asset_allocation_component.html.erb`
    - `app/javascript/controllers/chart_toggle_controller.js`
    - `app/views/net_worth/dashboard/show.html.erb` (now renders `turbo_frame_tag "allocation-pie-frame"`)
  - Notes:
    - Uses `chartkick` + `chart.js` (importmap pins) to render a donut/pie chart by default.
    - Includes a client-side (Stimulus) toggle to switch to a bar chart without page reload.
    - Includes an accessible `sr-only` table fallback.

- ✅ PRD-3-12 Sector Weights View
  - Branch: `epic-3-ui-improvements`
  - Key files:
    - `app/components/net_worth/sector_weights_component.rb`
    - `app/components/net_worth/sector_weights_component.html.erb`
    - `app/controllers/net_worth/sectors_controller.rb`
    - `app/views/net_worth/sectors/show.html.erb`
    - `app/views/net_worth/dashboard/show.html.erb` (lazy-loads `turbo_frame_tag "sector-table-frame"` with skeleton)
    - `app/javascript/controllers/sector_table_sort_controller.js`
    - `test/components/net_worth/sector_weights_component_test.rb`
    - `test/integration/net_worth_wireframe_test.rb`
    - `test/components/previews/net_worth/sector_weights_component_preview.rb`
    - `app/javascript/application.js` (Chartkick redraw hook for Turbo Frames)
  - Notes:
    - Renders a Chartkick horizontal bar chart and a DaisyUI table sourced from `data['sector_weights']`.
    - Sorting:
      - Client-side sorting (Stimulus) when <10 rows.
      - Server-side sorting via Turbo Frame reload with `sort`/`dir` params when >=10 rows.
    - Chart rendering:
      - Adds a global Chartkick redraw hook on `turbo:frame-load` to avoid charts getting stuck on "Loading..." when inserted via lazy-loaded Turbo Frames.
    - Defensive fallbacks:
      - Empty state when no sector data present.
      - Corrupt-data fallback with conditional Sentry logging (or `Rails.logger`).

- ✅ PRD-3-13 Performance View
  - Branch: `epic-3-13`
  - Key files:
    - `app/components/net_worth/performance_component.rb`
    - `app/components/net_worth/performance_component.html.erb`
    - `app/views/net_worth/dashboard/show.html.erb` (now renders `turbo_frame_tag "performance-chart-frame"`)
    - `app/controllers/net_worth/performance_controller.rb`
    - `app/views/net_worth/performance/show.html.erb` (replaced coming soon)
    - `app/controllers/net_worth/dashboard_controller.rb` (normalizes provider fallback to include `historical_totals`)
    - `test/components/net_worth/performance_component_test.rb`
    - `test/components/previews/net_worth/performance_component_preview.rb`
    - `test/smoke/net_worth_dashboard_capybara_test.rb` (updated expectation for lazy-loaded sector frame)
    - `test/integration/net_worth_performance_page_test.rb`
  - Notes:
    - Uses only the latest snapshot payload; no additional DB queries.
    - Renders a Chartkick `line_chart` plus a `<table class="sr-only">` fallback for accessibility.
    - Handles missing data (EmptyState), insufficient history (<2 points), and corrupt data (Sentry/log + friendly message).

- ✅ PRD-3-14 Holdings Summary View
  - Branch: `epic-3-ui-improvements`
  - Key files:
    - `app/components/net_worth/holdings_summary_component.rb`
    - `app/components/net_worth/holdings_summary_component.html.erb`
    - `app/controllers/net_worth/holdings_controller.rb`
    - `app/views/net_worth/holdings/show.html.erb`
    - `app/views/net_worth/dashboard/show.html.erb` (renders `turbo_frame_tag "holdings-summary-frame"`)
    - `app/services/reporting/data_provider.rb` (`top_holdings` + `holdings`)
    - `app/javascript/controllers/holdings_table_sort_controller.js`
    - `app/javascript/controllers/turbo_frame_skeleton_controller.js`
    - `test/components/net_worth/holdings_summary_component_test.rb`
    - `test/integration/net_worth_holdings_frame_test.rb`
  - Notes:
    - Initial render uses `snapshot.data['top_holdings']` (top 10) with client-side sorting via Stimulus.
    - “Expand” loads the full holdings list into the same Turbo Frame with a skeleton loader while in-flight.
    - Expanded list uses server-side sorting via `sort`/`dir` params.
    - Errors during expand are rescued and rendered inline with a Retry action.

- ✅ PRD-3-15 Transactions Summary View
  - Branch: `feature/prd-3-15-transactions-summary`
  - Key files:
    - `app/components/net_worth/transactions_summary_component.rb`
    - `app/components/net_worth/transactions_summary_component.html.erb`
    - `app/views/net_worth/dashboard/show.html.erb` (renders `turbo_frame_tag "transactions-summary-frame"`)
    - `app/jobs/financial_snapshot_job.rb` (writes `data['transactions_summary']` in snapshot payload)
    - `app/controllers/net_worth/dashboard_controller.rb` (normalizes provider fallback to include `transactions_summary`)
    - `test/components/net_worth/transactions_summary_component_test.rb`
    - `test/components/previews/net_worth/transactions_summary_component_preview.rb`
    - `test/smoke/net_worth_dashboard_capybara_test.rb` (asserts cards render)
    - `test/integration/net_worth_wireframe_test.rb` (asserts frame is present)
  - Notes:
    - Implements 3 DaisyUI stat cards (Income/Expenses/Net) with currency formatting and ↑/↓ indicators.
    - Net is computed as `income - expenses` (source-of-truth derived, even if snapshot includes `net`).
    - Defensive fallbacks:
      - Missing data → EmptyState message "No recent transactions—sync accounts"
      - Corrupt data → Sentry (if present) + "Data temporarily unavailable"
    - Backward compatible with existing snapshots that only provide `monthly_transaction_summary`.

### Mismatches / Decisions Needed
- **Test stack mismatch:** checklist references RSpec (`spec/`) but repo appears Minitest-based (`test/`). Decide whether Epic 3 will introduce RSpec, or translate checklist items to Minitest equivalents.
- **Template path mismatch:** `knowledge_base/templates/prd_template.md` is referenced but absent.

### Nice to Have (Can defer to specific PRDs)
- ⬜ Empty state hierarchy documentation
- ⬜ Turbo Stream channel authentication verification
- ⬜ Sentry tag conventions document
- ⬜ Schema backfill rake task (if needed)

---

## 🎯 Implementation Order

### Prep Phase (Before PRD-3-10)
**Epic 3 Prep PR** (`feature/epic-3-prep`)
- Schema doc with examples + color palette
- Validator PORO with tests
- BaseCardComponent + EmptyStateComponent
- Component README with hierarchy
- Error handling template
- Test gem installations + configs
- ViewComponent preview routes

**Estimated**: 3-4 hours

### Phase 1: Core Components (PRD-3-10 to PRD-3-13)
Priority 10-13 build foundational display components using pre-computed snapshot data.

1. **PRD-3-10**: Net Worth Summary Card (2-3 hours)
2. **PRD-3-11**: Asset Allocation View (2-3 hours)
3. **PRD-3-12**: Sector Weights View (2-3 hours)
4. **PRD-3-13**: Performance View (2-3 hours)

**Total**: ~8-12 hours

### Phase 2: Summary Views (PRD-3-14 to PRD-3-15)
5. **PRD-3-14**: Holdings Summary (3-4 hours)
6. **PRD-3-15**: Transactions Summary (2-3 hours)

**Total**: ~5-7 hours

### Phase 3: Actions & Polish (PRD-3-16 to PRD-3-18)
7. **PRD-3-16**: Export Button (2-3 hours)
8. **PRD-3-17**: Refresh/Sync Widget (3-4 hours) ✅ implemented (2026-01-27)
9. **PRD-3-18**: Final Polish & QA (4-5 hours)

**Total**: ~9-12 hours

**Grand Total**: ~25-35 hours focused implementation (similar to Epic 2)

---

## 🔍 Key Design Decisions Confirmed

### Architecture
- **Single Route**: `/net_worth` with Turbo-driven sections (NOT separate pages)
- **ViewComponents**: All UI in `app/components/net_worth/`, inherit from `BaseCardComponent`
- **Data Source**: `FinancialSnapshot.latest_for_user(current_user).data` JSON only
- **No AR in Components**: Receive only plain Ruby hashes/arrays from snapshot JSON

### Data & Performance
- **Historical Data**: Use pre-computed `historical_totals` array from latest snapshot (never query multiple rows)
- **Defensive Coding**: `data['key'] || {}` fallbacks everywhere
- **Schema Versioning**: Add `data_schema_version: 1` to all new snapshots
- **Memoization**: Throughout controller/service layer
- **Performance**: <2s LCP, <500ms per component render

### Interactivity
- **Stimulus vs Turbo**:
  - Stimulus: Data in DOM (chart toggle, local sort <50 rows, expand/collapse)
  - Turbo: Server data needed (holdings expand >100 rows, sync status)
- **Turbo Frame IDs**: `#net-worth-summary-frame`, `#allocation-pie-frame`, `#holdings-summary-frame`, `#sector-table-frame`, `#performance-chart-frame`
- **Turbo Frame IDs**: `#transactions-summary-frame` (PRD-3-15)
- **Skeleton Loaders**: DaisyUI `.skeleton` class in all Turbo frames

### Accessibility & Mobile
- **Target**: WCAG 2.1 AA compliance
- **Testing**: `axe-core-capybara` automated checks + manual keyboard nav
- **Touch Targets**: ≥44×44px minimum
- **Tooltips**: Hover on desktop, tap on mobile
- **Charts**: Include `<table class="sr-only">` fallback
- **Deltas**: Use symbols (↑/↓) + colors for accessibility

### Security & Observability
- **Scoping**: `current_user.financial_snapshots` application-level
- **Turbo Channels**: User-scoped `net_worth:sync:#{current_user.id}`
- **Sentry Tags**: `epic:3, prd:"3-XX", component:"ComponentName"`
- **Logging**: JSON parse failures, Turbo broadcast failures, rate limit hits

### Scope Decisions
- **Defer to Epic 4**: Transactions detail page, holdings detail page
- **PRD-3-15**: No link or `#` placeholder with "Coming soon" tooltip
- **PRD-3-14**: No holding detail links
- **i18n**: US/USD-only for Epic 3

---

## 🧪 Testing Strategy

### Test Coverage Requirements
Each PRD must include:
- ✅ Unit tests (ViewComponent specs)
- ✅ Integration tests (controller/request specs)
- ✅ ViewComponent preview (default + empty_state + edge_cases)
- ✅ Accessibility test (axe-core check)
- ✅ Mobile viewport test (one per major component)
- ✅ Error scenario tests

### Edge Cases to Test
- Nil/missing snapshot data
- Corrupt JSON in snapshot.data
- Very large portfolios (>$1B)
- Negative net worth
- Empty holdings/transactions
- Percentages not summing to 100%
- Turbo Stream failures
- Rate limit hits (PRD-3-17)
- Concurrent snapshot updates

### System Tests
Add Capybara system tests for key user flows:
1. Load dashboard → see all summary cards
2. Click "View All Holdings" → holdings frame updates
3. Toggle chart type → chart changes without reload
4. Click sync → status badge updates
5. Mobile: all interactions work with touch

---

## ❓ Outstanding Decisions

### Resolved ✅
1. ✅ Single `/net_worth` route (not separate pages) - **CONFIRMED**
2. ✅ Transactions/holdings detail views - **DEFERRED TO EPIC 4**
3. ✅ Stimulus vs Turbo guidelines - **DOCUMENTED IN KEY GUIDANCE**
4. ✅ Empty state hierarchy - **DEFINED WITH 3 CONTEXTS**
5. ✅ Chart color palette - **TO BE IN SCHEMA DOC**
6. ✅ Rate limiting implementation - **rack-attack WITH REDIS**
7. ✅ Job broadcast mechanism - **TURBO STREAM TO USER CHANNEL**
8. ✅ i18n scope - **US/USD ONLY FOR EPIC 3**

### Awaiting Eric Confirmation
- ⬜ Approval to start Epic 3 Prep task
- ⬜ Plaid Link flow location (for empty state CTAs)
- ⬜ Existing schema in production snapshots (need backfill?)
- ⬜ Sentry already configured? (or use Rails.logger only)

---

## 📦 Git Workflow

### Branch Strategy
```bash
# Prep task
git checkout -b feature/epic-3-prep
# ... commit prep work
git push origin feature/epic-3-prep
# Open PR, get approval, merge to main

# Main epic branch
git checkout main
git pull origin main
git checkout -b feature/epic-3-dashboard-polish

# Per-PRD commits
git commit -m "feat(PRD-3-10): Add net worth summary card component"
git commit -m "feat(PRD-3-11): Add asset allocation chart view"
# ... sequential commits

# Push for incremental review
git push origin feature/epic-3-dashboard-polish

# Final squash merge when epic complete
git checkout main
git merge --squash feature/epic-3-dashboard-polish
git commit -m "feat(Epic-3): Complete net worth dashboard polish & components"
```

### Commit Requirements
- ✅ All tests green before commit
- ✅ No N+1 queries (use `bullet` gem)
- ✅ Accessibility tests passing (axe-core)
- ✅ Mobile viewport test passing
- ✅ ViewComponent preview created
- ✅ Sentry error tags added
- ✅ Error scenarios handled

---

## ✅ Epic 3 Success Criteria

Epic 3 is complete when:
1. ✅ All 9 PRDs (3-10 through 3-18) implemented and tested
2. ✅ Dashboard displays all summary components with real snapshot data
3. ✅ All components responsive (desktop + mobile ≥375px)
4. ✅ WCAG 2.1 AA compliance verified (axe-core passing)
5. ✅ Turbo interactions work smoothly (no jank)
6. ✅ Empty states consistent and contextual
7. ✅ Error handling comprehensive (nil data, corrupt JSON, network failures)
8. ✅ Export button downloads JSON/CSV successfully
9. ✅ Sync widget shows real-time status with rate limiting
10. ✅ All tests green (unit, integration, system, accessibility)
11. ✅ Performance <2s LCP on dashboard load
12. ✅ ViewComponent previews created for all components
13. ✅ No console errors on interactions
14. ✅ Breadcrumbs navigate correctly
15. ✅ Full QA checklist passed (PRD-3-18)

---

## 📊 All Feedback Incorporated

### From 0000-Overview-epic-3-feedback.md
1. ✅ Data schema doc requirement
2. ✅ Historical data from snapshot JSON (not DB queries)
3. ✅ Component hierarchy documented
4. ✅ Turbo Frame IDs specified
5. ✅ Empty state consistency
6. ✅ Mobile testing requirements
7. ✅ Rate limiting (rack-attack)
8. ✅ WCAG 2.1 AA target + axe-core
9. ✅ System test requirements
10. ✅ Chartkick configuration guidance
11. ✅ Error handling in all PRDs
12. ✅ Performance budgets
13. ✅ POC deprecation tracking
14. ✅ Component documentation
15. ✅ Breadcrumb strategy
16. ✅ CSV export schema
17. ✅ Color accessibility (symbols + colors)
18. ✅ Job completion feedback (Turbo broadcast)

### From 0000-Overview-epic-3-grok_eric-comments-v2.md
1. ✅ No ActiveRecord in components enforced
2. ✅ Schema version field (`data_schema_version`)
3. ✅ Defensive coding patterns
4. ✅ Stimulus vs Turbo matrix
5. ✅ ViewComponent preview system
6. ✅ Chart color palette requirement
7. ✅ Timestamp display on summary card
8. ✅ Transactions/holdings detail deferred
9. ✅ Empty state hierarchy (3 contexts)
10. ✅ Turbo Stream channel security
11. ✅ Bullet gem for N+1 detection
12. ✅ i18n assumptions (US/USD only)
13. ✅ Sentry tag conventions
14. ✅ Integrity checks in validator
15. ✅ Scope clarifications confirmed

---

## 🎉 Summary

**Status**: All feedback incorporated, prep tasks defined, Epic 3 ready to start after prep phase.
**Blocking Issues**: 6 prep tasks (schema, validator, base components, test setup)
**Estimated Prep Time**: 3-4 hours
**Estimated Epic Time**: 25-35 hours focused implementation
**Timeline**: 1-2 weeks with incremental commits and reviews

**Next Actions**:
1. **Eric**: Approve prep task scope + answer outstanding questions
2. **Junie**: Complete Epic 3 Prep PR (6 tasks)
3. **Eric**: Review and merge prep PR
4. **Junie**: Begin PRD-3-10 on main epic branch

---

**Last Updated**: 2026-01-27 14:45 local

### Implementation Notes (in-repo)
- ✅ PRD-3-16 (Snapshot Export Button) implemented on `feature/prd-3-16-export-button`
  - Dashboard dropdown component added (`NetWorth::ExportSnapshotDropdownComponent`)
  - `GET /api/snapshots/:id/download.(json|csv)` supports `networth-snapshot-YYYY-MM-DD.*` filenames
  - Fix: export dropdown enables for the most recent persisted snapshot even when its status is `stale` (see `FinancialSnapshot.latest_for_user`).
  - UX: JSON export now has two options: summary JSON (default, omits large `holdings_export`) and full JSON (includes `holdings_export` via `include_holdings_export=true`).
**Next Review**: After prep PR completion
