# Junie Task Log — PRD 5-11 Snapshot Selector UI
Date: 2026-02-05  
Mode: Brave  
Branch: `epic-5-holding-grid`  
Owner: eric

## 1. Goal
- Add a snapshot selector UI to the Epic 5 holdings grid so users can switch between live holdings and a historical snapshot via a bookmarkable `snapshot_id` param.

## 2. Context
- Epic 5 Holdings Grid work-in-progress.
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-11-snapshot-selector-ui.md`
- Snapshot model/service work completed in PRDs 5-08/5-09 and provider snapshot-mode in PRD 5-02.

## 3. Plan
1. Add a reusable snapshot selector component (live + recent snapshots) with a historical-view indicator.
2. Wire selector into `/portfolio/holdings` header and ensure URL state persists.
3. Add validation for invalid `snapshot_id` and a basic snapshots index page for navigation.
4. Add component + controller tests.

## 4. Work Log (Chronological)
- Implemented `SnapshotSelectorComponent` with `Latest (live)` option + up to 50 recent user-level snapshots.
- Added historical view indicator and “Switch to live” action when `snapshot_id` is present.
- Wired selector into `Portfolio::HoldingsGridComponent` header and wrapped holdings grid in a Turbo frame so switching snapshots updates the grid.
- Parameterized `SavedAccountFilterSelectorComponent` so it can link to either Net Worth holdings or Portfolio holdings (was hardcoded to Net Worth).
- Added `Portfolio::HoldingsSnapshotsController#index` + route + view to back “View all snapshots…” navigation.
- Added `Portfolio::HoldingsController` `snapshot_id` validation to redirect invalid snapshot IDs back to live with a flash.
- Added/updated Minitest coverage for the selector component and controller behavior.

## 5. Files Changed
- `app/components/snapshot_selector_component.rb` — New component backing logic (snapshot list, selection state, param handling).
- `app/components/snapshot_selector_component.html.erb` — New dropdown UI + historical indicator.
- `app/components/portfolio/holdings_grid_component.rb` — Added `user:` and turbo-frame id constant; renders snapshot selector.
- `app/components/portfolio/holdings_grid_component.html.erb` — Renders snapshot selector + turbo-frame targeting for header controls.
- `app/views/portfolio/holdings/index.html.erb` — Wrap holdings grid in a Turbo frame.
- `app/controllers/portfolio/holdings_controller.rb` — Validate `snapshot_id` and redirect invalid IDs back to live.
- `app/controllers/portfolio/holdings_snapshots_controller.rb` — New controller for snapshots index.
- `app/views/portfolio/holdings_snapshots/index.html.erb` — New snapshots list page.
- `app/components/saved_account_filter_selector_component.rb` — Add `holdings_path_helper` to support multiple contexts.
- `app/components/saved_account_filter_selector_component.html.erb` — Use component `holdings_path` instead of hardcoded route.
- `config/routes.rb` — Add `portfolio_holdings_snapshots` route.
- `test/components/snapshot_selector_component_test.rb` — New component test coverage.
- `test/controllers/portfolio/holdings_controller_test.rb` — Assert provider receives valid `snapshot_id` and invalid IDs redirect.

## 6. Commands Run
- `bin/rails test test/components/snapshot_selector_component_test.rb test/controllers/portfolio/holdings_controller_test.rb` — pass

## 7. Tests
- `bin/rails test test/components/snapshot_selector_component_test.rb test/controllers/portfolio/holdings_controller_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Wrap the holdings grid in a Turbo frame and target the frame from selector/search/filter controls.
    - Rationale: Switching snapshots should feel instantaneous and not require full-page reload; aligns with existing Turbo usage in Epic 5.
- Decision: Redirect invalid `snapshot_id` back to live with a flash alert.
    - Rationale: Keeps user on the holdings grid while preventing silent “empty snapshot” behavior.

## 9. Risks / Tradeoffs
- Snapshot list is capped at 50 in the selector.
  - Mitigation/follow-up: PRD 5-13 snapshot management UI can provide full browsing/filtering.

## 10. Follow-ups
- [ ] Implement PRD 5-13 (full snapshot management UI) and replace/augment the basic snapshots index.
- [ ] Consider a system test (Capybara) for selecting a snapshot in-browser once fixtures/data setup is finalized.

## 11. Outcome
- `/portfolio/holdings` now supports selecting `Latest (live)` vs a historical snapshot via `snapshot_id`.
- When viewing a snapshot, a clear historical-view indicator is shown with a one-click “Switch to live”.
- Invalid `snapshot_id` values are handled safely (redirect back to live holdings).

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Navigate to `/portfolio/holdings`.
2. Use the Snapshot dropdown to select a snapshot (requires snapshots to exist for the current user).
3. Confirm the URL includes `snapshot_id=<id>` and a historical indicator is shown.
4. Click “Switch to live” and confirm the URL no longer includes `snapshot_id` and the indicator disappears.
5. Manually visit `/portfolio/holdings?snapshot_id=<invalid>` and confirm you are redirected back to live with an alert.
