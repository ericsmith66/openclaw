# Junie Task Log — PRD-2-09 Net Worth Dashboard UI
Date: 2026-01-24  
Mode: Brave  
Branch: feature/epic-2-financial-snapshots  
Owner: Junie

## 1. Goal
- Implement the v1 Net Worth dashboard UI (`/net_worth/dashboard`) using stored `FinancialSnapshot` JSON, with safe fallback behavior and a Capybara smoke test.

## 2. Context
- PRD reference: `knowledge_base/epics/wip/NextGen/Epic-2/0090-PRD-2-09.md`
- Dependencies:
  - Snapshot storage + job already implemented (PRD-2-01..2-06)
  - Admin preview and export endpoints already implemented (PRD-2-07..2-08)
- Constraint: No real-time calculations on dashboard; read snapshot JSON directly.
- Feature flag: `ENABLE_NEW_LAYOUT` controls access.

## 3. Plan
1. Replace dashboard placeholder view with a responsive DaisyUI/Tailwind layout.
2. Update controller to load latest complete snapshot, with DataProvider fallback.
3. Create ViewComponent cards for hero, allocation, sector weights, recent activity, and performance placeholder.
4. Add Capybara smoke coverage for snapshot/no-snapshot/flag-disabled scenarios.
5. Run tests and update Epic implementation tracker.

## 4. Work Log (Chronological)
- Updated `NetWorth::DashboardController#show` to load `FinancialSnapshot.latest_for_user(current_user)`.
- Implemented fallback to `Reporting::DataProvider#build_snapshot_hash` when no snapshot exists and normalized it to the flat keys used by stored snapshots.
- Implemented feature-flag gating; when disabled, returns `404` to avoid redirect loops (authenticated root points to the dashboard).
- Replaced dashboard view with card-based layout rendering new ViewComponents.
- Added `ApplicationSystemTestCase` + Capybara rack-test smoke tests validating core UX requirements.

## 5. Files Changed
- `app/controllers/net_worth/dashboard_controller.rb` — Load snapshot + fallback; enforce feature flag.
- `app/views/net_worth/dashboard/show.html.erb` — Dashboard layout rendering ViewComponents.
- `app/components/net_worth_hero_component.rb` + `.html.erb` — Total NW + deltas card.
- `app/components/asset_allocation_chart_component.rb` + `.html.erb` — Allocation progress visualization.
- `app/components/sector_weights_component.rb` + `.html.erb` — Sector weights display (null-safe).
- `app/components/recent_activity_component.rb` + `.html.erb` — Monthly transactions summary.
- `app/components/performance_placeholder_component.rb` + `.html.erb` — Performance placeholder.
- `test/application_system_test_case.rb` — Capybara system-test harness (rack-test).
- `test/smoke/net_worth_dashboard_capybara_test.rb` — Capybara smoke coverage.
- `test/integration/net_worth_wireframe_test.rb` — Existing wireframe test continues to pass.
- `knowledge_base/epics/wip/NextGen/Epic-2/0001-IMPLEMENTATION-STATUS.md` — Mark PRD-2-09 implemented.

## 6. Commands Run
- `RAILS_ENV=test bin/rails test test/smoke/net_worth_dashboard_capybara_test.rb test/integration/net_worth_wireframe_test.rb` — ✅ pass

## 7. Tests
- `RAILS_ENV=test bin/rails test test/smoke/net_worth_dashboard_capybara_test.rb test/integration/net_worth_wireframe_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Keep dashboard reads snapshot JSON only (no live aggregation).
  - Rationale: Performance and simplicity; matches PRD requirement.
- Decision: When `ENABLE_NEW_LAYOUT` is disabled, return `404`.
  - Rationale: Avoid redirect loops because authenticated root points to the dashboard route.
- Decision: Use simple progress bars for allocation visualization (no JS chart dependency).
  - Rationale: v1 UI; chart library decision can be deferred.

## 9. Risks / Tradeoffs
- Returning `404` when disabled might not be ideal UX.
  - Mitigation: Can swap to a dedicated “feature disabled” page later without risking redirect loops.

## 10. Follow-ups
- [ ] Decide on chart library for richer allocation/performance visualizations.
- [ ] Consider adding a dedicated disabled-state view instead of `404`.

## 11. Outcome
- Net Worth dashboard renders snapshot-backed totals and breakdowns, handles missing snapshots gracefully, and is protected by the feature flag.

## 12. Commit(s)
- `Implement PRD-2-09 net worth dashboard UI` — `31187fe`

## 13. Manual steps to verify and what user should see
1. Ensure `ENABLE_NEW_LAYOUT=true` and sign in.
2. Visit `/net_worth/dashboard`.
3. If a `FinancialSnapshot` exists:
   - Expected: page shows “Total Net Worth” card, deltas, allocation, sector weights, and recent activity.
4. If no snapshot exists:
   - Expected: “Generating your first snapshot. Check back soon!” banner.
5. Set `ENABLE_NEW_LAYOUT=false` and revisit `/net_worth/dashboard`:
   - Expected: `404` response.
