<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic‑4/PRD‑4‑01‑saprun‑schema‑persona‑config.md
-->

#### PRD‑8‑02: HomekitSync Bulk Fetching Optimization

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Currently `HomekitSync` fetches accessories room‑by‑room, making N+1 HTTP calls to Prefab (one per room). With the new bulk accessory endpoint available via `PrefabClient.all_accessories`, we can reduce this to a single HTTP call for the entire home, dramatically speeding up sync operations—from minutes to seconds for homes with hundreds of accessories. This PRD updates `HomekitSync` to use the bulk endpoint while preserving all existing cleanup and orphan‑detection logic.

---

### Requirements

#### Functional

- Modify `HomekitSync#perform` to fetch all accessories for a home in a single call using `PrefabClient.all_accessories(home.name)`
- Replace the inner loop that calls `PrefabClient.accessories(home.name, room.name)` with filtering of the bulk result by room name
- Maintain existing cleanup logic (deleting accessories not returned by Prefab) – adapt to work with bulk result
- Ensure backward compatibility: if bulk endpoint fails or returns empty, fall back to per‑room fetching (optional but recommended for robustness)
- Update the sync summary to reflect the same metrics (homes, rooms, accessories, scenes, deleted)

#### Non-Functional

- **Performance**: Sync time for 400+ accessories should drop from 2+ minutes to <10 seconds
- **Robustness**: Sync must still succeed if bulk endpoint fails (fallback to per‑room)
- **Data consistency**: Orphan detection must work correctly (accessories not in bulk result should be deleted)
- **Test coverage**: Update existing `HomekitSync` specs to verify bulk fetching behavior; ensure all specs pass

#### Rails / Implementation Notes

- **Service**: `app/services/homekit_sync.rb`
- **Change location**: `perform` method, inside the `homes_data.each` and `rooms_data.each` loops
- **Filtering**: `room_accessories = all_accessories.select { |acc| acc['room'] == room_data['name'] }`
- **Fallback**: If `all_accessories.empty?` (or nil), fall back to original per‑room calls (optional)
- **Cleanup**: Orphan detection currently works per‑room; need to adjust to consider all accessories across home
- **Testing**: Update `spec/services/homekit_sync_spec.rb` to mock `PrefabClient.all_accessories` and verify new flow

---

### Error Scenarios & Fallbacks

- **Bulk endpoint fails** (timeout, network error): Fall back to per‑room fetching (if implemented) or log error and proceed with empty array (resulting in deletion of all accessories – undesirable). **Recommended**: fallback to per‑room.
- **Bulk endpoint returns empty array**: Could indicate home has no accessories or endpoint malfunction. Fall back to per‑room to confirm.
- **Room name mismatch** (case sensitivity): Prefab room names are case‑sensitive; filtering must match exactly. Use exact string comparison.
- **Orphan detection across rooms**: Previously orphan detection was per‑room; now must consider all accessories in the home. Update `orphaned_accessories` query accordingly.

---

### Architectural Context

This PRD depends on PRD‑8‑01 (PrefabClient bulk endpoints). It optimizes the most expensive part of the sync pipeline without changing the external behavior: the database ends up in exactly the same state, just faster. The change is internal to `HomekitSync`; no other services or controllers are affected.

**Key boundaries**:
- No changes to `HomekitSync` public API (`self.perform` still returns same summary hash)
- No changes to database models, associations, or other services
- Orphan detection logic must be updated to work across all rooms of a home

**Non‑goals**:
- Changing how accessories are stored or associated with rooms
- Adding new cleanup strategies (beyond existing orphan deletion)
- Parallelizing sync across homes (can be separate optimization)

---

### Acceptance Criteria

- [ ] Sync completes successfully using bulk endpoint (verified with live Prefab)
- [ ] Sync time for 400+ accessories is significantly reduced (from minutes to seconds)
- [ ] All accessories are correctly associated with their rooms (no mis‑assignments)
- [ ] Orphan detection works correctly: accessories not in bulk result are deleted (with their dependent sensors and events)
- [ ] If bulk endpoint returns empty array, sync falls back to per‑room fetching (optional)
- [ ] Existing `HomekitSync` specs pass with minimal changes (mocks updated)
- [ ] Integration test with live Prefab confirms sync result matches pre‑change state
- [ ] No regressions in accessory, sensor, or scene creation

---

### Test Cases

#### Unit (Minitest)

- `spec/services/homekit_sync_spec.rb`:
  - `describe '#perform with bulk fetching'` – mocks `PrefabClient.all_accessories` and verifies filtering by room
  - `describe 'orphan detection with bulk data'` – verifies accessories not in bulk result are deleted
  - `describe 'fallback to per‑room fetching'` – when bulk endpoint fails, calls original `PrefabClient.accessories` per room
  - Existing specs updated to use bulk mocks where appropriate

#### Integration (Minitest)

- `spec/services/homekit_sync_spec.rb` (integration block):
  - Live Prefab test (skip unless `PREFAB_API_URL` set) that compares sync result using bulk vs. per‑room (should be identical)
  - Performance measurement (log sync duration) – not required for CI but useful for manual verification

#### System / Smoke (Capybara)

- Not required for this service‑only change.

---

### Manual Verification

1. Ensure Prefab is running with a home containing multiple rooms and accessories (e.g., "Waverly").
2. Run a baseline sync using current code (optional, for comparison):
   ```bash
   rails homekit:sync
   ```
   Note the time taken and counts.
3. Apply changes from PRD‑8‑01 and this PRD.
4. Run sync again:
   ```bash
   rails homekit:sync
   ```
5. Observe:
   - Sync completes much faster (seconds vs. minutes)
   - Console output shows same counts of homes, rooms, accessories, scenes
   - No errors in logs
6. Verify database consistency:
   ```ruby
   # In rails console
   Home.count
   Room.count
   Accessory.count
   Sensor.count
   Scene.count
   # Compare with previous counts (should be identical)
   ```
7. Trigger a cleanup sync (optional):
   ```bash
   rails homekit:sync CLEANUP=true
   ```
   Ensure orphan detection works (no unexpected deletions).

**Expected**
- Sync completes in seconds (not minutes)
- Database ends with same number of accessories, sensors, scenes as before
- No errors in Rails logs related to missing rooms or accessories

---

### Rollout / Deployment Notes

- No migrations or backfills required.
- Monitoring: Watch `HomekitSync` logs for performance improvements and any errors in orphan detection.
- Rollback: If issues arise, revert changes; sync will revert to slower but proven per‑room fetching.
- **Important**: Ensure PRD‑8‑01 is deployed before this PRD, as `PrefabClient.all_accessories` must be available.