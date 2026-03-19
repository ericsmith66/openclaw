---

# Junie Task Log — PRD-3-11 Asset Allocation View
Date: 2026-01-26  
Mode: Brave  
Branch: epic-3-ui-improvements  
Owner: Junie

## 1. Goal
- Implement PRD-3-11 by replacing the existing allocations widget with an interactive asset allocation chart (pie by default, toggle to bar), sourced from `FinancialSnapshot.latest_for_user(current_user).data`.

## 2. Context
- Epic 3 focuses on polishing the Net Worth dashboard using ViewComponents and snapshot JSON as the only data source.
- PRD reference: `knowledge_base/epics/wip/NextGen/Epic-3/0020-PRD-3-11.md`
- Existing UI used `AssetAllocationChartComponent` (progress bar list) and did not support Chartkick charts or a toggle.

## 3. Plan
1. Add Chartkick support (gem + importmap pins) with Chart.js backend.
2. Build `NetWorth::AssetAllocationComponent` with:
   - Pie chart (default) and bar chart (toggle) using Chartkick.
   - Defensive normalization for allocation data shape.
   - Accessible fallback table (`sr-only`).
3. Wire component into `app/views/net_worth/dashboard/show.html.erb` under Turbo frame `allocation-pie-frame`.
4. Add Minitest component + integration assertions.
5. Run tests and update Epic 3 status doc after green.

## 4. Work Log (Chronological)
- Implemented Chartkick setup (Gemfile + importmap pins) and loaded chart JS in `app/javascript/application.js`.
- Added `NetWorth::AssetAllocationComponent` with a Stimulus controller to toggle between pre-rendered pie and bar panels.
- Replaced dashboard allocation widget with new component under Turbo frame `allocation-pie-frame`.
- Added component and integration tests.

## 5. Files Changed
- `Gemfile` — added `chartkick` gem.
- `Gemfile.lock` — updated via `bundle install`.
- `config/importmap.rb` — pinned `chartkick`, `chart.js`, and `@kurkle/color`.
- `app/javascript/application.js` — imported `chartkick` and `chart.js`.
- `app/javascript/controllers/chart_toggle_controller.js` — added view toggle controller.
- `app/components/net_worth/asset_allocation_component.rb` — new ViewComponent.
- `app/components/net_worth/asset_allocation_component.html.erb` — new template with pie/bar charts + fallback table.
- `app/views/net_worth/dashboard/show.html.erb` — swapped old allocation widget for new component + Turbo frame.
- `test/components/net_worth/asset_allocation_component_test.rb` — added ViewComponent tests.
- `test/integration/net_worth_wireframe_test.rb` — asserts `allocation-pie-frame` exists.

## 6. Commands Run
- `bundle install` — ✅ success
- `./bin/importmap pin chartkick chart.js` — ✅ success

## 7. Tests
- `bundle exec rails test test/components/net_worth/asset_allocation_component_test.rb test/integration/net_worth_wireframe_test.rb` — ✅ pass
- `bundle exec rails test` — ✅ pass

## 8. Decisions & Rationale
- Decision: Use importmap-based Chartkick + Chart.js.
  - Rationale: Project already uses `importmap-rails` + Stimulus; this keeps the setup consistent without adding a JS bundler.
- Decision: Client-side toggle via Stimulus between two pre-rendered Chartkick charts.
  - Rationale: Meets the “toggle without full reload” requirement while avoiding extra routes/requests.

## 9. Risks / Tradeoffs
- Chart rendering relies on client-side JS; server-side tests only validate presence of Chartkick containers, not actual chart visuals.
- Allocation payload shape differs between provider fallback (hash) and persisted snapshot schema (array). Normalization is best-effort and should be aligned with the Epic 3 schema doc once finalized.
- Deploy note: if charts are stuck on "loading" in a deployed environment, verify the served importmap points at the latest `application-<digest>.js` and that production has run `RAILS_ENV=production bin/rails assets:clobber assets:precompile` followed by an app restart.

## 10. Follow-ups
- [ ] Run full test suite (`bundle exec rails test`) and fix any failures.
- [ ] Update `knowledge_base/epics/wip/NextGen/Epic-3/0001-IMPLEMENTATION-STATUS.md` to mark PRD-3-11 implemented.
- [ ] Commit PRD-3-11 changes once tests are green.

## 11. Outcome
- PRD-3-11 implemented: the Net Worth dashboard now includes an interactive Asset Allocation card using Chartkick (pie by default, toggle to bar) with an accessible fallback table.
- All tests passing locally.

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Ensure `ENABLE_NEW_LAYOUT=true`.
2. Start server: `bin/rails s`.
3. Log in and visit `/net_worth/dashboard`.
4. In the Asset Allocation card:
   - Default view shows a donut/pie chart.
   - Clicking “Bar” switches to a bar chart without a page reload.
   - With missing allocation data, you see “No allocation details available yet.”

---
