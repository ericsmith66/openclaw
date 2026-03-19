<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic-4/PRD-4-01-saprun-schema-persona-config.md
-->

#### PRD-8-01: PrefabClient Bulk Accessory Endpoints

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Prefab has introduced bulk accessory endpoints (`GET /accessories/:home` with filters and `GET /accessories/:home/summary`) that return metadata from HomeKit's cached object graph with **no device network calls**, making them orders of magnitude faster (~30ms) than per‑room accessory fetching (2+ minutes for 400+ accessories). This PRD extends the existing `PrefabClient` service to expose these endpoints, enabling efficient filtering and summary queries for sync operations, dashboards, and future UI features.

---

### Requirements

#### Functional

- Add `PrefabClient.all_accessories(home, filters = {})` method that calls `GET /accessories/:home` with optional query filters:
  - `reachable` (`true`/`false`)
  - `room` (string, case‑sensitive)
  - `category` (string, case‑insensitive)
  - `manufacturer` (string, case‑insensitive)
- Add `PrefabClient.accessories_summary(home)` method that calls `GET /accessories/:home/summary`
- Update private `fetch_json` method to accept optional query parameters (backward‑compatible)
- Ensure proper URL encoding of filter values using `ERB::Util.url_encode`
- Preserve existing error‑handling and logging patterns (return empty array `[]` on failure for `all_accessories`, `nil` for `accessories_summary`)

#### Non-Functional

- **Performance**: Bulk endpoint calls should complete within 50ms (measured via existing `PrefabClient` latency logging)
- **Backward compatibility**: Existing `PrefabClient.accessories(home, room)` must continue to work unchanged
- **Robustness**: Network timeouts, retries, and error handling must follow existing `PrefabClient` patterns
- **Test coverage**: New methods must have unit tests; integration tests should verify live Prefab responses when possible

#### Rails / Implementation Notes

- **Service**: `app/services/prefab_client.rb` (extend existing)
- **Private method update**: `fetch_json(path, params = {})` – add optional second parameter for query params
- **URL construction**: `url = "#{BASE_URL}#{path}"`; append `?#{URI.encode_www_form(params)}` if `params` present
- **Error handling**: Rescue `StandardError` and log via `Rails.logger.error`; return appropriate empty value
- **Testing**: Extend `spec/services/prefab_client_spec.rb` with new method tests and query‑parameter handling

---

### Error Scenarios & Fallbacks

- **Prefab unavailable / timeout**: Return empty array `[]` for `all_accessories`, `nil` for `accessories_summary` (consistent with existing `accessories` method)
- **Invalid home name**: Prefab returns empty array `[]`; our method should propagate that (no exception)
- **Malformed filter values**: URL‑encode special characters; if encoding fails, log error and proceed without filter
- **Network error during retry**: After `READ_TIMEOUT` and `READ_RETRY_TIMEOUT`, return empty result and log warning

---

### Architectural Context

This PRD builds directly on Epic 1's PrefabClient infrastructure. The new methods are additive and backward‑compatible, ensuring no disruption to existing sync, control, or UI functionality. The bulk endpoints will be used by `HomekitSync` (PRD‑8‑02) to dramatically reduce sync time, and can later be used by dashboards, analytics, or an accessory‑browsing UI.

**Key boundaries**: 
- No changes to database models, controllers, or UI in this PRD.
- The `fetch_json` modification must not break any existing calls (all current calls pass only one argument).
- Filter parameter validation is left to Prefab; we pass through whatever is provided.

**Non‑goals**:
- Adding caching layer (can be separate PRD)
- Changing existing `accessories(home, room)` signature
- Building UI components (covered in optional PRDs 8‑03, 8‑04)

---

### Acceptance Criteria

- [ ] `PrefabClient.all_accessories('Waverly')` returns an array of all accessories (verified with live Prefab)
- [ ] `PrefabClient.all_accessories('Waverly', reachable: false)` returns only unreachable accessories
- [ ] `PrefabClient.all_accessories('Waverly', room: 'Garage')` returns accessories in Garage
- [ ] `PrefabClient.all_accessories('Waverly', category: 'Lightbulb')` returns only lightbulbs
- [ ] `PrefabClient.all_accessories('Waverly', manufacturer: 'Sonos')` returns only Sonos devices
- [ ] Combined filters work: `PrefabClient.all_accessories('Waverly', room: 'Shop', reachable: false)`
- [ ] `PrefabClient.accessories_summary('Waverly')` returns a hash with keys `total`, `reachable`, `unreachable`, `byCategory`, `byRoom`, `byManufacturer`, `unreachableByManufacturer`, `unreachableByRoom`
- [ ] Existing `PrefabClient.accessories('Waverly', 'Office')` continues to return accessories for that room
- [ ] All existing `PrefabClient` specs pass without modification
- [ ] New unit tests cover `all_accessories` and `accessories_summary` with various filter combinations
- [ ] Integration tests verify live Prefab responses (if possible; may be mocked for CI)

---

### Test Cases

#### Unit (Minitest)

- `spec/services/prefab_client_spec.rb`:
  - `describe '.all_accessories'` – success with no filters, each filter type, combined filters, empty result, error handling
  - `describe '.accessories_summary'` – success, empty result, error handling
  - `describe '#fetch_json with query params'` – URL construction, encoding, backward compatibility (single‑arg call)

#### Integration (Minitest)

- `spec/services/prefab_client_spec.rb` (integration block):
  - Live Prefab test (skip unless `PREFAB_API_URL` set) that verifies bulk endpoint responses match expected structure
  - Fallback behavior when Prefab unavailable (mock timeout)

#### System / Smoke (Capybara)

- Not required for this service‑only change.

---

### Manual Verification

Provide step‑by‑step instructions a human can follow.

1. Ensure Prefab is running on `localhost:8080` with at least one home (e.g., "Waverly").
2. Open Rails console: `rails console`
3. Test new methods:
   ```ruby
   # All accessories
   all = PrefabClient.all_accessories('Waverly')
   puts "Total: #{all.length}"
   
   # Unreachable only
   unreachable = PrefabClient.all_accessories('Waverly', reachable: false)
   puts "Unreachable: #{unreachable.length}"
   
   # Filter by room
   garage = PrefabClient.all_accessories('Waverly', room: 'Garage')
   puts "Garage: #{garage.length}"
   
   # Filter by category
   thermostats = PrefabClient.all_accessories('Waverly', category: 'Thermostat')
   puts "Thermostats: #{thermostats.length}"
   
   # Combined filters
   dead_locks = PrefabClient.all_accessories('Waverly', category: 'Door Lock', reachable: false)
   puts "Unreachable locks: #{dead_locks.length}"
   
   # Summary
   summary = PrefabClient.accessories_summary('Waverly')
   puts "Summary total: #{summary['total']}, reachable: #{summary['reachable']}, unreachable: #{summary['unreachable']}"
   ```
4. Verify existing method still works:
   ```ruby
   office = PrefabClient.accessories('Waverly', 'Office')
   puts "Office accessories: #{office.length}"
   ```

**Expected**
- Each call returns appropriate data (no exceptions)
- Filtered results match what you see via direct `curl` to Prefab
- Summary contains expected keys and counts
- Existing `accessories` method returns same as before

---

### Rollout / Deployment Notes

- No migrations or backfills required.
- Monitoring: Existing `PrefabClient` logging includes latency; watch for errors in production logs.
- Rollback: If issues arise, revert the changes; all existing functionality remains intact.