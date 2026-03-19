<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic‑4/PRD‑4‑01‑saprun‑schema‑persona‑config.md
-->

#### PRD‑8‑04: Dashboard Integration of Summary Data (Optional)

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

The new `PrefabClient.accessories_summary` endpoint provides rich, pre‑aggregated counts and breakdowns of accessories by category, room, manufacturer, and reachability. This optional PRD surfaces that data on the existing dashboard (`/dashboard`), giving users an at‑a‑glance view of home health, device distribution, and potential issues (unreachable devices). The summary data is cached to avoid hitting Prefab on every page load.

---

### Requirements

#### Functional

- Enhance `DashboardsController#show` to fetch and cache summary data:
  - Use `PrefabClient.accessories_summary` for the default (or selected) home
  - Cache result for 5 minutes with key `"accessories_summary/#{home_name}"`
  - Pass summary hash to view
- Add dashboard UI components that display:
  - **Total accessory count** (large number)
  - **Reachable / Unreachable breakdown** (pie chart or two large numbers with color coding)
  - **Top categories** (bar chart or list of top 5 categories with counts)
  - **Top rooms** (list of top 5 rooms by accessory count)
  - **Unreachable by manufacturer** (list of manufacturers with unreachable counts, if any)
  - **Unreachable by room** (list of rooms with unreachable counts, if any)
- Ensure UI follows existing dashboard styling (cards, grids, badges)
- Provide "Refresh" button to bypass cache and fetch fresh summary

#### Non-Functional

- **Performance**: Dashboard load time should not increase significantly (cache ensures ~1ms hit after first load)
- **Responsive**: New components fit within existing dashboard grid on all viewports
- **Accessibility**: Charts (if any) have ARIA labels; color coding meets contrast requirements
- **Graceful degradation**: If summary endpoint fails, show placeholder "Data unavailable" and keep rest of dashboard functional

#### Rails / Implementation Notes

- **Controller**: `app/controllers/dashboards_controller.rb` (add `@summary` instance variable)
- **View**: `app/views/dashboards/show.html.erb` (add new sections)
- **Caching**: Use `Rails.cache.fetch` with `expires_in: 5.minutes`
- **Components**: Consider creating `Dashboards::SummaryComponent` or separate sub‑components for each metric
- **Charts**: Use lightweight chart library (Chart.js, ApexCharts) if desired, or keep simple HTML/CSS bars
- **Home selection**: If multiple homes, allow home selector dropdown (could reuse existing home picker)

---

### Error Scenarios & Fallbacks

- **Prefab unavailable / timeout**: Cache may be stale; show "Last updated X minutes ago" with warning icon. Allow manual refresh.
- **Empty summary** (no accessories): Show "No accessories found. Run a sync?" with link to sync page.
- **Cache failure** (Redis down): Fall back to uncached fetch; if that fails, show placeholder.
- **Large home (1000+ accessories)**: Summary endpoint still fast; UI should handle large numbers (format with commas).

---

### Architectural Context

This PRD depends on PRD‑8‑01 (PrefabClient bulk endpoints). It enhances the existing dashboard without changing any underlying data models or services. The summary data is read‑only and cached, placing minimal load on Prefab.

**Key boundaries**:
- No changes to database or existing dashboard data (events, sensors, etc.)
- Caching is optional but recommended for performance
- UI additions must not break existing dashboard layout or functionality

**Non‑goals**:
- Real‑time updates (dashboard refreshes on page load)
- Historical trend graphs (Epic 8 – Analytics)
- Interactive filtering (covered in PRD‑8‑03)
- Exporting summary data

---

### Acceptance Criteria

- [ ] Dashboard (`/dashboard`) displays total accessory count, reachable/unreachable breakdown
- [ ] Top categories and rooms are shown (limit to 5 each)
- [ ] Unreachable breakdown by manufacturer and room appears only when unreachable > 0
- [ ] Summary data is cached for 5 minutes (verify by checking logs – only one Prefab call per 5 minutes)
- [ ] "Refresh" button fetches fresh data and updates UI
- [ ] If summary fetch fails, dashboard still loads (other sections unaffected) with error message
- [ ] UI works on mobile (grid rearranges appropriately)
- [ ] All existing dashboard functionality (events, favorites, etc.) remains intact

---

### Test Cases

#### Unit (Minitest)

- `spec/controllers/dashboards_controller_spec.rb`:
  - `describe '#show'` – assigns `@summary` from cache, handles missing summary, caching behavior
- `spec/helpers/dashboards_helper_spec.rb` (if helpers added):
  - Formatting methods for summary data

#### Integration (Minitest)

- `spec/requests/dashboards_spec.rb`:
  - GET `/dashboard` returns success and includes summary data in HTML
  - Caching headers or fragment caching (optional)

#### System / Smoke (Capybara)

- `spec/system/dashboard_spec.rb` (extend existing):
  - Visit dashboard, verify summary sections present
  - Click refresh button, verify data updates
  - Simulate Prefab failure, verify graceful error display

---

### Manual Verification

1. Ensure Prefab running with home "Waverly".
2. Navigate to `/dashboard`.
3. Verify new summary sections appear (likely near top of page).
4. Check that numbers match Prefab reality (compare with `rails console` call to `PrefabClient.accessories_summary`).
5. Wait 5 minutes, refresh page – verify no new Prefab call (check Rails logs).
6. Click "Refresh" button (if implemented) – verify new Prefab call and updated timestamp.
7. Test mobile view.
8. Simulate Prefab offline: stop Prefab, reload dashboard – verify error placeholder and rest of dashboard works.

**Expected**
- Dashboard loads with new summary cards
- Numbers are accurate
- Caching works (no excessive Prefab calls)
- Mobile layout acceptable
- Error handling graceful

---

### Rollout / Deployment Notes

- No migrations or backfills required.
- Monitoring: Watch for cache misses and Prefab timeouts in logs.
- Rollback: Remove controller caching and UI components; dashboard reverts to previous state.
- **Dependency**: Requires PRD‑8‑01 to be deployed first.