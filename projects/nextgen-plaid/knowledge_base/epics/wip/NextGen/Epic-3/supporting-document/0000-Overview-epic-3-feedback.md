# Epic 3 Feedback: Net Worth Dashboard Polish & Components

**Reviewer:** Claude Sonnet 4.5
**Date:** 2026-01-26
**Epic Document:** `0000-Overview-epic-3.md`

## Overall Assessment
This is a well-structured epic with clear progression from data foundation to polished UI. The approach of leveraging pre-computed snapshots is sound for performance. Below are questions with potential solutions and improvement suggestions.

---

## Questions & Suggested Solutions

### 1. Data Structure Assumptions
**Question:** The PRDs assume specific JSON keys (`net_worth_summary`, `asset_allocation`, `sector_weights`, etc.) in `FinancialSnapshot.data`. Are these schema documented/validated?

**Potential Solution:**
- Create `knowledge_base/schemas/financial_snapshot_data_schema.md` documenting the complete JSON structure with example payloads
- Add JSON schema validation in `FinancialSnapshot` model using `jsonb_accessor` gem or similar
- Include schema validation in PRD-2-01 tests (if not already done) to ensure snapshot job produces conforming data

**Priority:** High - Blocks all Epic 3 PRDs

---

### 2. Historical Data Query Performance (PRD-3-13)
**Question:** Querying 30 days of snapshots per user could become expensive. What's the pagination/caching strategy?

**Potential Solutions:**
- Cache historical query results in Redis with 5-10 min TTL: `Rails.cache.fetch("user:#{user.id}:performance:30d", expires_in: 10.minutes)`
- Pre-compute daily aggregates into `historical_totals` array within snapshot JSON itself (already implied in line 30, but not explicit in PRD-3-13)
- Use `JSONB_AGG` or materialized view for trends if DB queries become heavy
- **Recommended:** Rely on `data['historical_totals']` array from snapshot JSON (already mentioned in line 30) rather than separate DB queries—update PRD-3-13 to clarify this

**Priority:** Medium - Affects PRD-3-13 implementation

---

### 3. Component Reusability Across Dashboard Sections
**Question:** With subdirs like `allocations/`, `sectors/`, `performance/`, etc., will components be reused or duplicated?

**Potential Solution:**
- Establish clear component hierarchy: `NetWorth::DashboardComponent` as container, with nested sub-components (`NetWorth::SummaryCardComponent`, etc.)
- Create shared base component `NetWorth::BaseComponent` with common helpers (formatting, empty states)
- Document component architecture in `knowledge_base/architecture/view_components.md` showing composition pattern
- **Alternative:** If subdirs represent separate pages (not just partials), clarify routing in PRD-3-18 (e.g., `/net_worth/allocations` vs single dashboard with sections)

**Priority:** Medium - Clarifies architecture before PRD-3-10

---

### 4. Turbo Frame Performance & UX
**Question:** Multiple Turbo interactions (allocation toggle, holdings expand, sorting) could conflict or feel janky. What's the interaction model?

**Potential Solutions:**
- Use distinct Turbo Frame IDs per interaction zone: `#allocation_chart_frame`, `#holdings_list_frame`, `#sector_table_frame`
- Implement optimistic UI updates where possible (CSS class toggles before server response)
- Add loading states via Turbo Stream templates with skeleton loaders (DaisyUI has skeleton classes)
- Consider Stimulus controllers for purely client-side interactions (chart toggle, table sorting) to avoid network round-trips

**Priority:** Medium - Affects UX quality across PRD-3-11, 3-12, 3-14

---

### 5. Empty State Consistency
**Question:** Each PRD mentions empty states, but messages vary. Will this confuse users?

**Potential Solution:**
- Standardize empty state messaging in `knowledge_base/style_guide.md`:
  - No snapshot: "Connect accounts to see your net worth"
  - Snapshot exists but specific data missing: "No [X] data available—check your connected accounts"
- Create `NetWorth::EmptyStateComponent` with icon/message/CTA props for consistency
- Define empty state hierarchy (account-level vs data-level)

**Priority:** Low - Nice-to-have for consistency

---

### 6. Mobile Responsiveness Testing
**Question:** Multiple PRDs mention "responsive" but mobile testing isn't detailed. How to ensure quality?

**Potential Solutions:**
- Add explicit mobile breakpoint specifications using Tailwind conventions: `sm:`, `md:`, `lg:` usage guidelines
- Create mobile test checklist in PRD-3-18:
  - Touch targets ≥44px
  - Horizontal scroll only where intended (tables)
  - Charts scale without overflow
  - Tooltips work on touch (consider tap-to-reveal)
- Add Capybara mobile viewport tests: `page.driver.browser.manage.window.resize_to(375, 667)`

**Priority:** Medium - Critical for user experience

---

### 7. Rate Limiting Implementation (PRD-3-17)
**Question:** "1/min" rate limit—where enforced? Redis or DB? User-specific or global?

**Potential Solutions:**
- **Recommended:** Use `rack-attack` gem with Redis backend:
  ```ruby
  Rack::Attack.throttle("snapshot_sync/user", limit: 1, period: 60) do |req|
    req.env['warden'].user&.id if req.path == '/net_worth/sync'
  end
  ```
- **Alternative:** Timestamp in user table: `last_snapshot_refresh_at`, checked in controller
- Return 429 with Turbo Stream error message
- Display countdown timer in UI: "Next refresh available in #{time_remaining}"

**Priority:** High - Protects API limits (PRD-3-17)

---

### 8. Accessibility Coverage
**Question:** PRDs mention ARIA labels but not comprehensive WCAG compliance. What's the target level?

**Potential Solutions:**
- Set explicit goal: WCAG 2.1 AA compliance
- Add accessibility testing tools:
  - `axe-core` gem for automated checks
  - Manual keyboard nav testing checklist (tab order, focus states)
- Specific enhancements:
  - Chart fallbacks: data tables hidden with `.sr-only`
  - Color contrast verification (DaisyUI themes may need overrides)
  - Live regions for Turbo updates: `aria-live="polite"`
- Document in PRD-3-18 acceptance criteria

**Priority:** Medium - Important for compliance

---

### 9. Testing Strategy Completeness
**Question:** Unit/integration tests mentioned, but what about system tests for Turbo interactions?

**Potential Solution:**
- Add system test layer using Capybara + Cuprite/Selenium:
  ```ruby
  # spec/system/net_worth/dashboard_spec.rb
  scenario "expanding holdings list" do
    visit net_worth_path
    click_button "View All Holdings"
    expect(page).to have_css("#holdings_full_list")
  end
  ```
- Create test fixture snapshots with known data for predictable assertions
- Mock Plaid API calls in test environment
- Add VCR/WebMock cassettes for API interactions

**Priority:** Medium - Ensures quality

---

### 10. Chartkick Library Limitations
**Question:** Chartkick is convenient but limited for advanced interactions (drill-down, custom tooltips). Is it sufficient?

**Potential Solutions:**
- **Short term:** Use Chartkick's `library` option to pass custom Chart.js/Highcharts config:
  ```ruby
  <%= line_chart data, library: { tooltips: { callbacks: {...} } } %>
  ```
- **Medium term:** If limitations hit, create custom Stimulus controllers wrapping Chart.js directly
- **Consideration:** Chartkick requires JS; ensure graceful degradation if user has JS disabled
- Document charting strategy in `knowledge_base/architecture/frontend.md`

**Priority:** Low - Can evaluate during implementation

---

## Suggested Improvements

### 11. Add Error Handling Guidance
**Issue:** Currently missing from PRDs—what happens if `FinancialSnapshot.latest_for_user` returns `nil`? How to handle corrupt JSON in `data` field? Network errors during Turbo interactions?

**Solution:** Add "Error Scenarios" section to each PRD with fallback behavior:
- Nil snapshot → render global empty state
- Invalid JSON → log error, show "Data unavailable" message
- Turbo failures → fallback to full page reload with flash message

**Priority:** High - Critical for robustness

---

### 12. Performance Budgets
**Issue:** Line 50 mentions "<500ms render" for summary card, but no overall dashboard budget specified.

**Solution:**
- Define performance budgets for entire dashboard: <2s LCP, <100ms TBT
- Add `rack-mini-profiler` or `skylight` instrumentation
- Create performance regression tests using `benchmark-ips`
- Document in PRD-3-18 acceptance criteria

**Priority:** Low - Nice-to-have for optimization

---

### 13. Deprecation of POC Code
**Issue:** Line 29 says "refactor/replace POC code freely" but no tracking mechanism mentioned.

**Solution:**
- Add `# TODO(Epic3): Replace with NetWorth::XComponent` comments in PRD-2-09 code
- Create tracking issue for POC deprecation
- Ensure no production dependencies on disposable code before starting Epic 3
- Document what specifically is considered "POC code"

**Priority:** Medium - Prevents confusion

---

### 14. Component Documentation
**Issue:** No documentation strategy for ViewComponents mentioned.

**Solution:**
- Inline YARD docs for each component:
  ```ruby
  # Renders the net worth summary card with deltas
  # @param summary [Hash] Keys: :total, :day_delta_usd, :thirty_day_delta_pct
  # @example
  #   <%= render NetWorth::SummaryCardComponent.new(summary: {...}) %>
  ```
- Storybook-style component showcase (ViewComponent has preview support)
- Add to style guide or create `knowledge_base/components/README.md`

**Priority:** Low - Improves maintainability

---

### 15. Breadcrumb Strategy (PRD-3-18)
**Issue:** "Home > Net Worth > [Subsection]" needs clarification.

**Solution:**
- Clarify: Is "[Subsection]" only for drill-down views (transactions list, holdings detail, etc.)?
- Main dashboard shows: "Home > Net Worth" (no subsection)
- Use `breadcrumbs_on_rails` gem or built-in helper
- Document breadcrumb structure in routing docs
- Specify breadcrumb behavior for each nested route

**Priority:** Low - Can be defined in PRD-3-18

---

### 16. CSV Export Format (PRD-3-16)
**Issue:** "Flattened holdings/accounts" is vague.

**Solution:**
- Define exact CSV schema with headers: `Account, Symbol, Name, Value, Percentage`
- Handle nested data (multiple accounts with holdings)
- Provide sample CSV in PRD-3-16 or separate schema doc:
  ```csv
  Account,Symbol,Name,Value,Percentage
  Brokerage-1234,AAPL,Apple Inc.,125000.00,12.5
  Brokerage-1234,GOOGL,Alphabet Inc.,87500.00,8.75
  ```
- Consider ZIP archive if exporting multiple CSVs (holdings, transactions, accounts)

**Priority:** Medium - Needed for PRD-3-16

---

### 17. Color Accessibility
**Issue:** Red/green for deltas may be problematic for colorblind users.

**Solution:**
- Add symbols: ↑/↓ alongside colors
- Use DaisyUI semantic colors (`success`, `error`) which have sufficient contrast
- Test with colorblind simulators (Chrome DevTools has this)
- Add to PRD-3-10 requirements
- Document color usage in style guide

**Priority:** Medium - Accessibility concern

---

### 18. Job Completion Feedback (PRD-3-17)
**Issue:** How does UI know when `FinancialSnapshotJob` finishes?

**Solution:**
- Use `turbo-rails` Broadcast: `Turbo::StreamsChannel.broadcast_replace_to(user, target: "sync_status", ...)`
- Job calls `broadcast_replace_later` on completion
- Consider websocket fallback for connection issues
- Show approximate sync duration: "Usually takes 30-60 seconds"
- Handle job failures with retry mechanism
- Add to PRD-3-17 architectural context

**Priority:** High - Core to PRD-3-17 functionality

---

## Summary of Key Recommendations

### Must-Have Before Starting (Priority: High)
1. **Document snapshot JSON schema** before starting PRD-3-10 (#1)
2. **Define error handling strategy** for nil/corrupt data (#11)
3. **Specify rate limiting implementation** (rack-attack recommended) (#7)
4. **Document job completion feedback mechanism** for PRD-3-17 (#18)

### Should Address During Planning (Priority: Medium)
5. **Clarify PRD-3-13 to use pre-computed `historical_totals`** from snapshot (#2)
6. **Create component architecture doc** showing hierarchy and reuse patterns (#3)
7. **Define Turbo Frame interaction model** (#4)
8. **Add mobile test checklist** to PRD-3-18 (#6)
9. **Set WCAG 2.1 AA compliance target** with tooling (#8)
10. **Add system tests** for Turbo interactions (#9)
11. **Define CSV export schema** explicitly (#16)
12. **Track POC code deprecation** (#13)
13. **Add accessibility enhancements** (symbols with colors, ARIA live regions) (#17)

### Nice-to-Have (Priority: Low)
14. **Standardize empty states** with shared component (#5)
15. **Evaluate Chartkick limitations** during implementation (#10)
16. **Add performance budgets** (#12)
17. **Create component documentation** strategy (#14)
18. **Clarify breadcrumb structure** (#15)

---

## Architecture Strengths

The epic demonstrates several strong architectural decisions:
- **Pre-computed snapshots:** Avoids expensive real-time aggregations
- **ViewComponents:** Promotes reusability and testability
- **Turbo Streams:** Modern, performant interactivity without heavy JS
- **DaisyUI + Tailwind:** Consistent design system
- **RLS security:** Database-level isolation
- **Clear dependency chain:** Logical PRD progression (10→11→12...)

---

## Conclusion

This epic is well-conceived and ready for implementation with clarifications on the high-priority items above. The dependency chain is logical and allows for iterative progress. The emphasis on ViewComponents and pre-computed data is architecturally sound for maintainability and performance.

**Recommended Next Steps:**
1. Create `knowledge_base/schemas/financial_snapshot_data_schema.md`
2. Update PRD-3-13 to clarify data source (snapshot JSON vs DB query)
3. Add error handling sections to all PRDs
4. Define rate limiting and job feedback mechanisms in PRD-3-17
5. Create mobile testing checklist for PRD-3-18
6. Proceed with PRD-3-10 implementation
