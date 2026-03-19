#### PRD-2-03: Sensors Dashboard & Detail Views

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---
 
### Overview

Create a comprehensive sensor monitoring interface with health indicators, alerts, filtering, and historical data visualization. Provide a dashboard grouped by sensor type and a detailed view for each sensor, including history charts and recent events.

---

### Requirements

#### Functional

- Sensors Dashboard (`/sensors`)
  - Alerts section at the top: Low battery (<20%), offline sensors (>1 hour), unusual readings
  - Group sensors by type: Temperature, Motion, Humidity, Battery, Contact, Active
  - Filters: Type, Status (All, Active, Offline, Low Battery), Room, Search by name
  - Sort by Name, Last Updated, Value, Status
- Sensor Detail (`/sensors/:id`)
  - Header card: icon + type, current value, last updated, status badge, metadata
  - Activity chart with time range selector (24h, 7d, 30d, custom)
  - Recent events table: timestamp, value, changed, source; pagination; export CSV; filter by date range
  - Actions: favorite, add alert rule, export, view in room context
- Sensor Type Views (`/sensors/temperature`, `/sensors/motion`, etc.)
  - Filtered views with type-specific visualizations and bulk actions

- Components
  - `SensorCardComponent` (props: `sensor`, `show_chart: false`, `compact: false`)
  - `SensorDetailComponent` (props: `sensor`, `events`, `time_range`)
  - `ActivityChartComponent` (props: `sensor`, `time_range`, `chart_type`)
  - `BatteryIndicatorComponent` (props: `level`, `charging`, `low_threshold`)
  - `AlertBannerComponent` (props: `alerts`)

#### Non-Functional

- Performance: Dashboard loads < 500ms for ~250 sensors via eager loading and pagination as needed.
- Accessibility: Charts have textual summaries and tables as fallbacks.
- Responsiveness: Cards/grid adapt across breakpoints.

#### Rails / Implementation Notes (optional)

- `SensorsController#index` supports filters (type, status, room, search) and builds an `@alerts` hash for low-battery/offline.
- `SensorsController#show` loads events in the selected time range and paginates (50/page).
- `SensorsController#chart_data` returns JSON for charts (labels, values, sensor type).

---

### Error Scenarios & Fallbacks

- No events in selected time range → Show empty-state with guidance to change range.
- Missing battery level → Show battery indicator as unknown and exclude from low-battery alert.
- Chart load failure → Show table-only historical data.

---

### Architectural Context

Builds on layout and components from 2-01. Provides core monitoring capabilities used by operations and feeds insights to Event Log viewer.

---

### Acceptance Criteria

- [ ] Dashboard shows all sensors grouped by type with counts.
- [ ] Alert section highlights critical issues.
- [ ] Sensor detail shows current value and renders a history chart.
- [ ] Events table paginates and supports CSV export.
- [ ] Filters (type, status, room, search) work together.
- [ ] Performance: Dashboard loads <500ms for 253 sensors.

---

### Test Cases

#### Unit (Minitest)

- `test/components/sensors/sensor_card_component_test.rb`: renders value, status, icon.
- `test/components/sensors/battery_indicator_component_test.rb`: thresholds and charging state.
- `test/components/charts/activity_chart_component_test.rb`: renders with time ranges.

#### Integration (Minitest)

- `test/integration/sensors_filters_sorting_test.rb`: filters and sorts combined.
- `test/integration/sensors_alerts_test.rb`: low battery and offline alerts composition.

#### System / Smoke (Capybara)

- `test/system/sensor_detail_navigation_test.rb`: navigate to sensor detail, change time ranges, export CSV.

---

### Manual Verification

1. Open /sensors; confirm alerts, grouping by type, and filter controls.
2. Filter to Motion; sort by Last Updated; verify results update.
3. Open a sensor; confirm header card info, chart renders for 24h, 7d, 30d.
4. Scroll events; verify pagination and CSV export.

**Expected**
- Alerts reflect current problematic sensors.
- Filters change the dataset without errors or reload flicker.
- Chart and table show consistent values.
