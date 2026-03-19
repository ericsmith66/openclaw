#### PRD-2-02: Homes & Rooms Views

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---
 
### Overview

Build hierarchical navigation views for homes and rooms with live sensor data. Provide index and detail pages for homes and rooms, including grids, filters, and breadcrumbs.

---

### Requirements

#### Functional

- Homes Index (`/homes`)
  - List all homes with stats (rooms, accessories, sensors, events)
  - Sync status indicator and last sync timestamp
  - Quick action buttons (View Rooms, View Sensors, Recent Events)
- Home Show (`/homes/:id`)
  - Breadcrumb: Home > [Home Name]
  - Summary stats (rooms, accessories, sensors)
  - Rooms grid/list view toggle
  - Recent events for this home
- Rooms Grid (`/homes/:id/rooms` or `/rooms`)
  - Grid of room cards (4 columns desktop, 2 tablet, 1 mobile)
  - Each card: name + emoji/icon, accessory count, sensor count, live sensor values (temp, humidity, motion), status indicators
  - Filters: has sensors, has motion, has temp
  - Search by room name
- Room Detail (`/rooms/:id`)
  - Breadcrumb: Home > Room > [Room Name]
  - Status bar (temp, humidity, motion, connectivity)
  - Sections:
    - Sensors: current values, last updated, status
    - Other Accessories: controllable devices (future control buttons)
  - Filter sensors by type
  - Clicking a sensor opens detail panel

- Components
  - `HomeCardComponent` (props: `home`) — stats, sync status, actions
  - `RoomCardComponent` (props: `room`, `compact: false`) — live data, indicators, navigation
  - `RoomDetailComponent` (props: `room`, `accessories`, `sensors`) — grouped sections, filters

#### Non-Functional

- Responsive on mobile/tablet/desktop.
- Avoid N+1 queries using `includes`.
- Accessible breadcrumbs and card content.

#### Rails / Implementation Notes (optional)

- Controllers:
  - `HomesController#index` loads homes with rooms/accessories/sensors.
  - `HomesController#show` loads a single home with rooms and recent events.
  - `RoomsController#index` supports filters and search; eager-loads relations.
  - `RoomsController#show` loads sensors and separates other accessories.

---

### Error Scenarios & Fallbacks

- Home with no rooms → Show empty-state message and link to sensors/events.
- Room with no sensors → Show empty Sensors section and emphasize Other Accessories.
- Missing live values → Show placeholders and mark status as unknown.

---

### Architectural Context

Uses the shared layout and components from PRD 2-01. Outputs feed into sensors and events features in later PRDs.

---

### Acceptance Criteria

- [ ] Homes index shows all homes with accurate stats.
- [ ] Rooms grid displays with live sensor values.
- [ ] Room detail separates sensors from controllable accessories.
- [ ] Navigation breadcrumbs work correctly.
- [ ] Filters and search functional.
- [ ] Responsive on mobile/tablet/desktop.

---

### Test Cases

#### Unit (Minitest)

- `test/components/homes/home_card_component_test.rb`: stats and sync indicators.
- `test/components/rooms/room_card_component_test.rb`: displays counts and live values.
- `test/components/rooms/room_detail_component_test.rb`: grouping and filtering.

#### Integration (Minitest)

- `test/integration/homes_flow_test.rb`: index and show pages render with expected data.
- `test/integration/rooms_filters_search_test.rb`: filters (has sensors/motion/temp) and search work.

#### System / Smoke (Capybara)

- `test/system/rooms_grid_responsive_test.rb`: grid column counts at different breakpoints; card navigation.

---

### Manual Verification

1. Navigate to /homes; verify stats, sync status, and quick actions.
2. Open a home; verify breadcrumbs, summary stats, rooms toggle, recent events.
3. Open rooms grid; apply filters and search; confirm layout changes by screen size.
4. Open a room; verify status bar, sections, and sensor filter.

**Expected**
- Accurate counts and recent events.
- Filters and search update results without errors.
- Breadcrumbs lead back to parent views.
