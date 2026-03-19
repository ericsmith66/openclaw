---

# Junie Task Log — PRD-3-12 Sector Weights View
Date: 2026-01-26  
Mode: Brave  
Branch: epic-3-ui-improvements  
Owner: ericsmith66

## 1. Goal
- Implement PRD-3-12 Sector Weights View (bar chart + sortable table + fallbacks) and keep tests green.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-3/0030-PRD-3-12.md`
- Net Worth dashboard currently renders a minimal `SectorWeightsComponent` and `/net_worth/sectors` was a "Coming Soon" placeholder.

## 3. Plan
1. Add `NetWorth::SectorWeightsComponent` rendering Chartkick bar chart + DaisyUI table.
2. Add client-side sorting via Stimulus for small tables; server-side sorting via Turbo params for larger lists.
3. Wire the component through `Turbo Frame` `sector-table-frame` and load it from `/net_worth/sectors` to show a skeleton while loading.
4. Add ViewComponent preview + Minitest coverage.

## 4. Work Log (Chronological)
- Implemented `NetWorth::SectorWeightsComponent` with normalization, chart+table rendering, and fallbacks.
- Updated `NetWorth::SectorsController#show` and `app/views/net_worth/sectors/show.html.erb` to render inside `turbo_frame_tag "sector-table-frame"`.
- Updated the dashboard to lazy-load the sector frame with a skeleton.
- Added `sector_table_sort_controller.js` for client-side sorting.
- Added component test and ViewComponent preview.

## 5. Files Changed
- `app/views/net_worth/dashboard/show.html.erb` — lazy-load sectors via Turbo Frame w/ skeleton loader
- `app/controllers/net_worth/sectors_controller.rb` — populate `@snapshot_data` for sector view
- `app/views/net_worth/sectors/show.html.erb` — replace Coming Soon with sector weights component
- `app/components/net_worth/sector_weights_component.rb` — component logic
- `app/components/net_worth/sector_weights_component.html.erb` — bar chart + sortable table UI
- `app/javascript/controllers/sector_table_sort_controller.js` — client-side sorting for small tables
- `test/components/net_worth/sector_weights_component_test.rb` — render assertions
- `test/components/previews/net_worth/sector_weights_component_preview.rb` — previews
- `app/javascript/application.js` — Chartkick redraw hook for Turbo Frame lazy-load
- `knowledge_base/prds-junie-log/2026-01-26__prd-3-12-sector-weights.md` — this log

## 6. Commands Run
- `bin/rails test test/components/net_worth/sector_weights_component_test.rb`
- `bin/rails test test/integration/net_worth_wireframe_test.rb`

## 7. Tests
- ✅ `test/components/net_worth/sector_weights_component_test.rb` (2 runs, 0 failures)
- ✅ `test/integration/net_worth_wireframe_test.rb` (3 runs, 0 failures)

## 8. Decisions & Rationale
- Decision: Use Turbo Frame `src` to `/net_worth/sectors` to enable skeleton loading.
    - Rationale: Meets PRD requirement for skeleton loading without additional JS.

## 9. Risks / Tradeoffs
- Chartkick tooltip customization is approximated via labels including formatted $ values.

## 10. Follow-ups
- [ ] Update `knowledge_base/epics/wip/NextGen/Epic-3/0001-IMPLEMENTATION-STATUS.md` after tests pass.

## 11. Outcome
- Implemented PRD-3-12 Sector Weights View (Turbo Frame lazy-load + Chartkick bar chart + sortable table) with component/integration test coverage.

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Load `/net_worth/dashboard`.
2. Confirm the Sector Weights card shows a skeleton briefly, then renders a bar chart and a table.
3. With <10 sectors, click table headers to sort without full page reload.
4. With >=10 sectors, header clicks should re-request the Turbo Frame with `sort`/`dir` params.

---
