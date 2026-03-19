Here is Junie's (Claude Sonnet 4.5) full markdown with inline comments prefixed **grok_eric:**.  
Every comment is actionable or clearly states agreement / decision / next step.

# Epic 3 Feedback: Net Worth Dashboard Polish & Components
**Reviewer:** Claude Sonnet 4.5  
**Date:** 2026-01-26  
**Epic Document:** `0000-Overview-epic-3.md`

## Overall Assessment
This is a well-structured epic with clear progression from data foundation to polished UI. The approach of leveraging pre-computed snapshots is sound for performance. Below are questions with potential solutions and improvement suggestions.

**grok_eric:** Agree — the snapshot-first architecture is one of the strongest parts of the plan. It keeps us scalable even when users have 50+ linked accounts.

---

## Questions & Suggested Solutions

### 1. Data Structure Assumptions
**Question:** The PRDs assume specific JSON keys (`net_worth_summary`, `asset_allocation`, `sector_weights`, etc.) in `FinancialSnapshot.data`. Are these schema documented/validated?

**Potential Solution:**
- Create `knowledge_base/schemas/financial_snapshot_data_schema.md` documenting the complete JSON structure with example payloads
- Add JSON schema validation in `FinancialSnapshot` model using `jsonb_accessor` gem or similar
- Include schema validation in PRD-2-01 tests (if not already done) to ensure snapshot job produces conforming data

**Priority:** High - Blocks all Epic 3 PRDs

**grok_eric:** High priority confirmed.  
**grok_eric:** Action: Create `knowledge_base/schemas/financial_snapshot_data_schema.md` **today** with at least v1 schema including all keys mentioned across PRDs + one full example JSON (use real-looking but fake numbers).  
**grok_eric:** We will **not** use `jsonb_accessor` (adds another dependency and magic); instead add a small PORO validator class `FinancialSnapshotDataValidator` called in `before_save` and in snapshot job tests.  
**grok_eric:** Add one test in snapshot job spec that asserts valid schema using the new validator.

### 2. Historical Data Query Performance (PRD-3-13)
**Question:** Querying 30 days of snapshots per user could become expensive. What's the pagination/caching strategy?

**Potential Solutions:** …  
**Recommended:** Rely on `data['historical_totals']` array from snapshot JSON (already mentioned in line 30) rather than separate DB queries—update PRD-3-13 to clarify this

**Priority:** Medium

**grok_eric:** Agree 100% — we should **never** query 30 separate snapshot rows for trends.  
**grok_eric:** Action: Update PRD-3-13 **before starting implementation** to state:  
"The 30-day performance chart and table MUST use only `data['historical_totals']` from the **latest** FinancialSnapshot. Do not perform additional database queries for history."  
**grok_eric:** Also add a comment in the code where we read it: `# Performance: using pre-rolled historical_totals from latest snapshot only`

### 3. Component Reusability Across Dashboard Sections
**Question:** With subdirs like `allocations/`, `sectors/`, `performance/`, etc., will components be reused or duplicated?

**Potential Solution:** …  
**Alternative:** If subdirs represent separate pages (not just partials), clarify routing in PRD-3-18 …

**Priority:** Medium

**grok_eric:** Good catch.  
**grok_eric:** Decision: We are building **one main dashboard** (`/net_worth`) with Turbo-driven sections — **not** separate routed pages for allocations/sectors/etc.  
**grok_eric:** Action: Update PRD-3-18 routing section to say: "Single route `/net_worth`. Sub-views (allocations detail, sector breakdown, full holdings) are Turbo Frame replacements or slide-over modals, not separate pages."  
**grok_eric:** Action: Create `app/views/net_worth/components/README.md` with simple hierarchy diagram (ASCII or mermaid) showing:  
`NetWorth::DashboardContainer → SummaryCards → AllocationChartSection → HoldingsTableSection → etc.`  
**grok_eric:** We will create `NetWorth::BaseCardComponent` as the shared base.

### 4. Turbo Frame Performance & UX
**Question:** Multiple Turbo interactions … could conflict or feel janky.

**Potential Solutions:** …  
**Priority:** Medium

**grok_eric:** Agree — jank is the #1 risk for perceived quality here.  
**grok_eric:** Action: Assign **unique frame IDs** as suggested:  
`#net-worth-summary-frame`, `#allocation-pie-frame`, `#holdings-table-frame`, `#sector-table-frame`, `#performance-chart-frame`  
**grok_eric:** Action: Use skeleton loaders (DaisyUI `.skeleton`) in every Turbo frame template.  
**grok_eric:** Action: For table sorting and simple toggles (expand/collapse holdings) → move to Stimulus controller (client-side) unless the sort needs server-side data we don't already have.  
**grok_eric:** We will **not** do optimistic updates on allocation toggle until after first release (risk of inconsistency with snapshot data).

### 5. Empty State Consistency
…  
**Priority:** Low

**grok_eric:** Agree it's low but still worth doing once.  
**grok_eric:** Action: Create single `NetWorth::EmptyStateComponent` that takes:
- `context` (:no_accounts, :no_snapshot, :no_specific_data)
- `message_override` (optional)
- `cta_path` (optional)  
  **grok_eric:** Standard messages will live in the component, not duplicated in views.

### 6. Mobile Responsiveness Testing
…  
**Priority:** Medium

**grok_eric:** Important — many users check finances on phone.  
**grok_eric:** Action: Add to PRD-3-18 acceptance criteria a short mobile checklist:
- All touch targets ≥ 44×44 px
- No unintended horizontal scroll (especially tables)
- Charts use `width: 100%; height: auto;` or responsive container
- Modals/slide-overs work on small screens
- Tooltips become tap-to-show on mobile  
  **grok_eric:** Action: Add one Capybara system test with iPhone viewport resize for the main dashboard load + one interaction.

### 7. Rate Limiting Implementation (PRD-3-17)
…  
**Priority:** High

**grok_eric:** Critical — Plaid has strict rate limits.  
**grok_eric:** Decision: Use `rack-attack` + Redis (we already have Redis).  
**grok_eric:** Action: Implement exactly as shown in the example:  
`Rack::Attack.throttle("snapshot_sync/user", limit: 1, period: 60) { |req| req.user&.id if req.path.match?(%r{/net_worth/sync}) }`  
**grok_eric:** Action: On 429 return Turbo Stream that replaces sync button with:  
`<div class="alert alert-error">Refresh limit reached — try again in <span data-countdown>...</span></div>`  
**grok_eric:** Add simple JS countdown (can be Stimulus or vanilla).

### 8. Accessibility Coverage
…  
**Priority:** Medium

**grok_eric:** Agree — target **WCAG 2.1 AA**.  
**grok_eric:** Action: Add to PRD-3-18: "All new components MUST pass axe-core automated check (level AA) and manual keyboard navigation test."  
**grok_eric:** Action: Install `axe-core-capybara` and add one axe test per major system spec.  
**grok_eric:** Charts: always include `<table class="sr-only">` with same data as chart.

### 9. Testing Strategy Completeness
…  
**Priority:** Medium

**grok_eric:** Agree system tests are missing right now.  
**grok_eric:** Action: Write at least 3 system specs:
1. Load dashboard → see summary cards
2. Click "View All Holdings" → holdings frame updates
3. Click sync → see status change (mock job complete)  
   **grok_eric:** Use Cuprite driver (faster than Selenium).

### 10. Chartkick Library Limitations
…  
**Priority:** Low

**grok_eric:** Agree — Chartkick is fine for phase 1.  
**grok_eric:** Action: If we need drill-down later, we extract to dedicated Stimulus + Chart.js controller — but not now.  
**grok_eric:** Add `library: { ... }` for custom tooltip formatting where needed.

### 11. Add Error Handling Guidance
…  
**Priority:** High

**grok_eric:** Very important — missing error paths are the #1 source of angry support tickets.  
**grok_eric:** Action: Add "Error Scenarios & Fallbacks" subsection to **every** PRD in Epic 3 with at least:
- No latest snapshot → render `EmptyStateComponent(context: :no_snapshot)`
- JSON parse failure → log to Sentry + show "Data temporarily unavailable"
- Turbo/network failure → flash alert + link to refresh page

### 18. Job Completion Feedback (PRD-3-17)
…  
**Priority:** High

**grok_eric:** This is make-or-break for the sync UX.  
**grok_eric:** Decision: Use Turbo Streams + model broadcast.  
**grok_eric:** Action: In `FinancialSnapshotJob#perform`:  
after successful save → `user.broadcast_replace_to "net_worth:sync_status", target: "sync-status", partial: "net_worth/sync_status", locals: { status: :complete, snapshot: @snapshot }`  
**grok_eric:** Action: Add failure broadcast with error reason if possible.  
**grok_eric:** Show "Sync usually takes 30–90 seconds" static text while pending.

### Summary of Key Recommendations – grok_eric adjusted priorities & actions

**Must-Have Before Starting (High)**
1. Create `financial_snapshot_data_schema.md` + validator class
2. Add error handling sections to all PRDs
3. Implement rack-attack rate limit on `/net_worth/sync`
4. Implement Turbo broadcast on job completion (PRD-3-17)

**Should Address During Planning (Medium)**
5. Clarify PRD-3-13 → use only `historical_totals` from latest snapshot
6. Document component hierarchy in `components/README.md`
7. Define unique Turbo frame IDs
8. Add mobile checklist + one mobile system test
9. Set WCAG 2.1 AA + axe-core in CI
10. Define CSV headers exactly in PRD-3-16
11. Track POC deprecation with `# TODO(Epic3):` comments

**Nice-to-Have** — defer until after first working dashboard

**grok_eric final note:** Overall excellent feedback from Claude. If we knock out the four must-haves + the historical_totals clarification this week, we can start PRD-3-10 with much higher confidence. Let me know which one you want to tackle first (schema doc, rack-attack, broadcast job, or error handling write-up).