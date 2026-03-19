# Junie Task Log — PRD-3-13 Performance View
Date: 2026-01-27  
Mode: Brave  
Branch: epic-3-13  
Owner: ericsmith66

## 1. Goal
- Render a 30-day Net Worth performance line chart using `historical_totals` from the latest snapshot only, with accessible fallback and safe error handling.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-3/0040-PRD-3-13.md`
- Constraint: no additional DB queries beyond the latest snapshot fetch in the dashboard.

## 3. Plan
1. Implement `NetWorth::PerformanceComponent` (Chartkick line chart + sr-only table).
2. Wire it into the Net Worth dashboard inside Turbo frame `performance-chart-frame`.
3. Add component tests and run targeted test suite.
4. Update Epic 3 implementation status doc once tests are green.

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- 2026-01-27: Started PRD-3-13 implementation on branch `epic-3-13`.
- 2026-01-27: Added `NetWorth::PerformanceComponent` (Chartkick line chart + sr-only table fallback) and wired it into dashboard Turbo frame `performance-chart-frame`.
- 2026-01-27: Updated provider normalization so fallback/provider data exposes `historical_totals` without adding DB queries.
- 2026-01-27: Added component tests and updated existing dashboard smoke test expectation for lazy-loaded Turbo frame content.
- 2026-01-27: Ran targeted test commands; all green.

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `app/components/net_worth/performance_component.rb` — New ViewComponent for 30-day net worth performance.
- `app/components/net_worth/performance_component.html.erb` — Chartkick `line_chart` + accessible sr-only table + empty/insufficient/corrupt states.
- `app/controllers/net_worth/dashboard_controller.rb` — Normalize fallback/provider payload to include `historical_totals`.
- `app/views/net_worth/dashboard/show.html.erb` — Render performance card within Turbo frame `performance-chart-frame`.
- `test/components/net_worth/performance_component_test.rb` — ViewComponent unit tests for missing/insufficient/normal data.
- `test/smoke/net_worth_dashboard_capybara_test.rb` — Adjust assertion to account for lazy-loaded Turbo frame `src:` behavior.
- `test/components/previews/net_worth/performance_component_preview.rb` — ViewComponent previews (default/sparse/insufficient/empty).
- `app/controllers/net_worth/performance_controller.rb` — Render Performance page using latest snapshot data.
- `app/views/net_worth/performance/show.html.erb` — Replace “coming soon” with `NetWorth::PerformanceComponent`.
- `test/integration/net_worth_performance_page_test.rb` — Integration test for `/net_worth/performance` route.
- `knowledge_base/epics/wip/NextGen/Epic-3/0001-IMPLEMENTATION-STATUS.md` — Mark PRD-3-13 implemented and document key files/tests.
- `knowledge_base/prds-junie-log/2026-01-27__prd-3-13-performance-view.md` — This task log.

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.  
Use placeholders for any sensitive arguments.

- `bin/rails test test/components/net_worth/performance_component_test.rb` — pass
- `bin/rails test test/smoke/net_worth_dashboard_capybara_test.rb` — pass
- `bin/rails test test/integration/net_worth_wireframe_test.rb` — pass
- `bin/rails test test/integration/net_worth_performance_page_test.rb` — pass

## 7. Tests
Record tests that were run and results.

- `bin/rails test test/components/net_worth/performance_component_test.rb` — ✅ pass
- `bin/rails test test/smoke/net_worth_dashboard_capybara_test.rb` — ✅ pass
- `bin/rails test test/integration/net_worth_wireframe_test.rb` — ✅ pass
- `bin/rails test test/integration/net_worth_performance_page_test.rb` — ✅ pass

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Decision: Render the performance card directly on the dashboard (not via `turbo_frame_tag ... src:`).
    - Rationale: avoids extra requests/queries and aligns with PRD requirement of “no additional DB queries beyond latest snapshot fetch”.

- Decision: Accept `historical_net_worth` as a legacy alias when `historical_totals` is absent.
    - Rationale: preserves compatibility with existing snapshot/fallback payloads while keeping the primary source `historical_totals`.

## 9. Risks / Tradeoffs
- Tooltip delta formatting relies on Chartkick/Chart.js passing through tooltip callback functions and raw point metadata; should be sanity-checked in a browser.

## 10. Follow-ups
Use checkboxes.

- [ ] Confirm tooltip delta formatting in-browser (Chart.js callback behavior)
- [ ] Ensure latest snapshot JSON includes `historical_totals` in prod data pipeline

## 11. Outcome
- Net Worth dashboard now includes a Performance card rendering a 30-day line chart using `historical_totals` from the latest snapshot payload, with accessibility fallback and safe empty/corrupt handling.

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- Pending

## 13. Manual steps to verify and what user should see
1. Visit `/net_worth/dashboard`.
2. See a “Performance” card with a 30-day line chart.
3. Hover/tap points to see tooltip with date, value, and day-over-day delta.
4. With <2 data points, see “Insufficient history…” message.
5. With missing `historical_totals`, see the empty state message (“No data available yet.”).
