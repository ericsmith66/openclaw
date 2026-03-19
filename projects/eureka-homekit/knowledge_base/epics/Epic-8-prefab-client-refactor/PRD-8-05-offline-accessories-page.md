<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic‑4/PRD‑4‑01‑saprun‑schema‑persona‑config.md
-->

#### PRD‑8‑05: Offline Accessories Page & Reachable Status Integration

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

The new Prefab bulk accessory endpoint provides authoritative `isReachable` status for each accessory directly from HomeKit's cached object graph. This PRD integrates that reachable status into our data model, updates offline detection logic, and creates an artfully designed offline accessories page that helps users identify, troubleshoot, and monitor unreachable devices. The page will be integrated into the navigation and dashboard, providing a seamless experience for managing home health.

---

### Requirements

#### Functional

1. **Data Model Enhancement**
   - Add `reachable` boolean column to `accessories` table (default: `true`)
   - Update `HomekitSync` to populate `reachable` from bulk endpoint's `isReachable` field
   - Add `Accessory#offline?` method that returns `!reachable` (or `reachable == false`)
   - Update `Sensor#offline?` to consider parent accessory's `reachable` status as primary indicator (before checking `Status Active`/`Status Fault`/inactivity)

2. **Offline Accessories Page**
   - Create new route `GET /accessories/offline` (or `/accessories?status=offline` if PRD‑8‑03 implemented)
   - Use `PrefabClient.all_accessories(home, reachable: false)` to fetch current unreachable accessories
   - Display offline accessories in a visually distinct, helpful layout:
     - Group by room (collapse/expand sections)
     - Show accessory name, category, manufacturer, last seen (if available)
     - Include troubleshooting tips based on category (e.g., "Check power for lightbulbs", "Verify Wi‑Fi for Sonos speakers")
     - Provide "Refresh Status" button to re‑fetch from Prefab
     - Empty state: "All accessories are online! 🎉" with celebratory illustration

3. **UI Integration**
   - Add "Offline" link to left sidebar navigation (after "Favorites", before "Settings") with badge showing count of offline accessories (cached, updated every 5 minutes)
   - Update dashboard (`/dashboard`) to show offline count prominently (could be part of PRD‑8‑04)
   - Enhance `Sensors::AlertBannerComponent` to include offline accessories (not just sensors) when count > 0
   - Ensure offline accessories are visually disabled in all control components (existing `offline?` methods will now use `reachable` flag)

4. **Caching & Performance**
   - Cache offline accessory count for 5 minutes (same as summary cache)
   - Cache list of offline accessories for 2 minutes (fresher than summary)
   - Provide manual refresh button to bypass cache

#### Non-Functional

- **Performance**: Offline page loads in <1 second (bulk endpoint ~30ms + rendering)
- **Accuracy**: Offline status reflects Prefab's `isReachable` field; if Prefab unavailable, show last known state with warning
- **Responsive**: Page works on mobile; grouping collapses to save space
- **Accessibility**: Screen readers can navigate grouped sections; ARIA labels for status badges
- **Artful Design**: Clean, non‑alarming visual treatment (soft colors, helpful icons, not error‑red everywhere)

#### Rails / Implementation Notes

- **Migration**: `rails generate migration AddReachableToAccessories reachable:boolean`
- **Model**: `app/models/accessory.rb` – add `scope :offline, -> { where(reachable: false) }`
- **Controller**: New action `AccessoriesController#offline` (or extend `#index` with `status=offline` param)
- **View**: `app/views/accessories/offline.html.erb` (or reuse index with offline filter)
- **Component**: Consider `Accessories::OfflineListComponent` for grouping and troubleshooting tips
- **Sidebar**: Update `Layouts::LeftSidebarComponent` to include offline count badge (fetch via helper that caches)
- **Alert Banner**: Update `Sensors::AlertBannerComponent` to accept `offline_accessories_count`

---

### Error Scenarios & Fallbacks

- **Prefab unavailable**: Show cached offline list with "Last updated X minutes ago" warning; allow manual refresh (will fail gracefully)
- **No offline accessories**: Display celebratory empty state with illustration
- **Home not selected**: Use default home (first home); provide home selector dropdown if multiple homes
- **Large number of offline accessories (50+)**: Paginate or virtual scroll; group by room to reduce visual clutter

---

### Architectural Context

This PRD builds on PRD‑8‑01 (PrefabClient bulk endpoints) and PRD‑8‑02 (HomekitSync bulk fetching). It enhances the data model with authoritative reachable status and provides a user‑focused interface for troubleshooting offline devices. The offline page is a special case of the accessory filtering introduced in PRD‑8‑03, but with additional grouping and troubleshooting content.

**Key boundaries**:
- Offline status is derived from Prefab's `isReachable` field, not inferred from sensor inactivity (though `Sensor#offline?` retains fallback logic for sensors without parent accessory reachable data)
- The page is read‑only; no control actions (turning devices on/off) are offered because devices are unreachable
- Troubleshooting tips are static content based on category; no automated diagnostics

**Non‑goals**:
- Automated remediation (power‑cycling via smart plug, etc.)
- Historical tracking of offline periods (can be added in analytics epic)
- Notifications for newly offline devices (future feature)
- Integration with manufacturer‑specific diagnostics (e.g., Sonos Wi‑Fi test)

---

### Acceptance Criteria

- [ ] Migration adds `reachable:boolean` column to `accessories` table (default true, not null)
- [ ] `HomekitSync` updates `accessory.reachable` from bulk endpoint's `isReachable` field
- [ ] `Accessory.offline` scope returns accessories where `reachable == false`
- [ ] `Accessory#offline?` method returns `!reachable`
- [ ] `Sensor#offline?` checks parent accessory's `reachable` first, then falls back to existing logic
- [ ] `GET /accessories/offline` returns page listing unreachable accessories grouped by room
- [ ] Each accessory entry shows name, category, manufacturer, and relevant troubleshooting tip
- [ ] Empty state shows celebratory message when all accessories are reachable
- [ ] Left sidebar includes "Offline" link with badge showing count (updated every 5 minutes)
- [ ] Dashboard shows offline count (if PRD‑8‑04 implemented, integrate there; otherwise add small badge)
- [ ] `Sensors::AlertBannerComponent` shows offline accessory count when > 0
- [ ] All existing control components respect `accessory.offline?` (already do via `offline?` method)
- [ ] Manual refresh button fetches fresh data from Prefab and updates UI

---

### Test Cases

#### Unit (Minitest)

- `spec/models/accessory_spec.rb`:
  - `describe '#offline?'` – returns true when `reachable` false, false when true
  - `describe '.offline'` – scope returns correct records
- `spec/models/sensor_spec.rb`:
  - `describe '#offline?'` – prioritizes accessory.reachable, falls back to status active/fault/inactivity
- `spec/services/homekit_sync_spec.rb`:
  - `describe 'sync updates reachable flag'` – verifies `reachable` is set from bulk data
- `spec/controllers/accessories_controller_spec.rb`:
  - `describe 'GET #offline'` – success, empty list, prefab failure, caching

#### Integration (Minitest)

- `spec/requests/accessories_spec.rb`:
  - End‑to‑end request/response for `/accessories/offline`
  - Sidebar includes offline count badge
- `spec/system/offline_accessories_spec.rb` (optional):
  - Visit offline page, see grouped accessories
  - Click refresh button, see updated list
  - Mobile viewport test

#### System / Smoke (Capybara)

- `spec/system/offline_accessories_spec.rb`:
  - Navigate to offline page via sidebar link
  - Verify grouping, troubleshooting tips
  - Test empty state (mock all accessories reachable)

---

### Manual Verification

1. Ensure Prefab running with home containing some unreachable accessories.
2. Run migration: `rails db:migrate`
3. Run sync: `rails homekit:sync` – verify `reachable` column populated.
4. Navigate to `/accessories/offline`.
5. Verify:
   - Page shows offline accessories grouped by room
   - Each entry has name, category, manufacturer, troubleshooting tip
   - Sidebar has "Offline" link with badge count > 0
   - Dashboard (if PRD‑8‑04 implemented) shows offline count
6. Click "Refresh Status" – page updates (may be same list).
7. Mark an accessory as reachable in Prefab (if possible), refresh page – accessory disappears.
8. Test empty state: temporarily set all accessories reachable (or mock), visit page – see celebratory empty state.
9. Mobile responsiveness: resize browser.
10. Verify control components show disabled state for offline accessories (visit room detail page).

**Expected**
- Offline page loads quickly with helpful grouping
- Sidebar badge updates (may be cached)
- Empty state is encouraging, not alarming
- All existing functionality remains intact

---

### Rollout / Deployment Notes

- **Migration required**: Add `reachable` column; backfill existing accessories with `true` (assume reachable until next sync).
- **Cache invalidation**: After sync, clear offline count cache to reflect new reachable status.
- **Monitoring**: Watch for sync errors updating `reachable` flag.
- **Rollback**: Remove migration (revert column), revert sidebar link, revert controller action; offline detection falls back to sensor‑based logic.
- **Dependencies**: Requires PRD‑8‑01 and PRD‑8‑02 to be deployed first.