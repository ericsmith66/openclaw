#### PRD-2-04: Event Log Viewer with Real-Time Updates

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---
 
### Overview

Build a live event log with filtering, search, statistics, and real-time updates via ActionCable. Provide a performant, paginated table of events with expand/collapse for raw payloads and CSV export.

---

### Requirements

#### Functional

- Events Index (`/events`)
  - Statistics bar: totals, sensor/control counts, match rate, dedup rate, events per minute
  - Filter controls: time range (Last Hour, 24h, 7d, Custom), event types (Sensors/Control/System/Webhook), room, accessory, search (accessory or characteristic), live mode toggle
  - Event table: Timestamp, Room, Accessory, Characteristic, Value; status indicators (NEW, deduped), color coding by type, expandable raw JSON, pagination (50/page) or infinite scroll, auto-scroll behavior in live mode
  - Export button: download current filtered set as CSV
- Real-Time Updates
  - ActionCable subscription to `EventsChannel`
  - New events appear at the top with a NEW badge
  - Statistics update automatically and respect current filters
  - Pause/resume button for live updates; optional sound notification

- Components
  - `EventRowComponent` (props: `event`, `highlight_changes: false`)
  - `EventStatisticsComponent` (props: `events`, `time_range`)
  - `EventFilterComponent` (props: `filters`, `on_change`)

#### Non-Functional

- Handle ≥50 events/minute without UI lag; throttle broadcasts as needed.
- Accessible table semantics and keyboard navigation.
- Persist filter state via query params.

#### Rails / Implementation Notes (optional)

- `EventsChannel` streams from "events".
- Webhook controller (`Api::HomekitEventsController#create`) broadcasts normalized payload to "events" channel on create.
- `EventsController#index`:
  - Time filter (hour/24h/7d/custom) to compute `range_start`.
  - Optional filters by type, room, accessory, search (ILIKE on accessory_name/characteristic).
  - Pagination (50 per page) and stats hash (`total`, `sensor_events`, `events_per_minute`).

---

### Error Scenarios & Fallbacks

- Channel disconnect → show banner and retry/backoff.
- CSV export failure → provide inline error and retry option.
- Large payloads → lazy-render payload expansion only on user action.

---

### Architectural Context

Builds on layout from 2-01 and data model/event ingestion from Epic 1. Complements the Sensors Dashboard by providing raw chronological context.

---

### Acceptance Criteria

- [ ] Event log displays all events with proper formatting.
- [ ] Filters work correctly (time, type, room, accessory, search).
- [ ] Live updates via ActionCable are functional and respect filters.
- [ ] New events appear in real time with a NEW badge.
- [ ] Statistics update automatically.
- [ ] Pagination or infinite scroll works without regressions.

---

### Test Cases

#### Unit (Minitest)

- `test/components/events/event_row_component_test.rb`: renders columns and highlights.
- `test/components/events/event_statistics_component_test.rb`: computes stats correctly.

#### Integration (Minitest)

- `test/integration/events_filters_test.rb`: time/type/room/accessory/search combos.
- `test/integration/events_pagination_export_test.rb`: pagination and CSV export.

#### System / Smoke (Capybara)

- `test/system/events_live_updates_test.rb`: simulate ActionCable broadcasts; verify NEW badge and stats updates.

---

### Manual Verification

1. Open /events; set time range to Last Hour and enable live mode.
2. Trigger a few webhook events; verify rows prepend with NEW and stats update.
3. Apply filters (room, accessory, type); ensure only matching events display.
4. Expand raw payload for a row.
5. Export current view as CSV and open the file.

**Expected**
- Smooth prepending without layout thrash.
- Accurate counts in the statistics bar.
- CSV contains the filtered dataset.