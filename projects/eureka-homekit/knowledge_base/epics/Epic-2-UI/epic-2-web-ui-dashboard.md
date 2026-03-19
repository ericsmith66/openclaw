# Epic 2: Web UI Dashboard for HomeKit Monitoring

## Product Requirements Document

### Objectives
1. Build responsive web interface for navigating HomeKit homes, rooms, accessories, and sensors
2. Display real-time sensor data with live updates via ActionCable
3. Provide event log viewer with filtering and search capabilities
4. Enable monitoring of sensor health, battery levels, and connectivity status

### Current State
- ✅ Database models: Home, Room, Accessory, Sensor, HomekitEvent
- ✅ 399 accessories, 253 sensors, 35 rooms synced from Prefab
- ✅ Webhook receiving events (3,144/hour with 94.6% sensor matching)
- ✅ Event deduplication strategy (60% reduction in database writes)
- ⏳ No web UI - data only accessible via Rails console
- ⏳ No real-time updates - requires manual queries

### Requirements

#### 1. Application Layout & Navigation
**Three-column responsive layout**:
- **Header**: Logo, navigation tabs (Dashboard, Homes, Sensors, Events), sync button
- **Left Sidebar** (240px): Navigation tree, category filters, quick access links
- **Main Content**: Dynamic content based on current view
- **Right Sidebar** (320px): Context-sensitive details panel, quick stats

**Navigation Structure**:
```
Dashboard (/)
├─ Homes (/homes)
│  └─ [Home] (/homes/:id)
│     ├─ Rooms (/homes/:id/rooms)
│     └─ Sensors (/homes/:id/sensors)
├─ Rooms (/rooms/:id)
│  ├─ Accessories (grouped: sensors vs controllable)
│  └─ Events (/rooms/:id/events)
├─ Sensors (/sensors)
│  ├─ By Type (temperature, motion, battery, etc.)
│  └─ [Sensor Detail] (/sensors/:id)
└─ Events (/events)
   └─ Live log with filters
```

**Mobile Responsive**:
- Single column on mobile (<768px)
- Collapsible sidebars
- Bottom navigation bar
- Touch-friendly targets (44x44px minimum)

---

## PRD 2.1: Core Layout & ViewComponents Infrastructure

### Objective
Establish ViewComponent architecture with reusable shared components and application layout.

### Requirements

#### ViewComponents to Create
1. **AppLayout** (`layouts/application_layout.rb`)
   - Three-column layout with responsive breakpoints
   - Header, left sidebar, main content, right sidebar
   - Stimulus controllers for sidebar toggle

2. **HeaderComponent** (`components/header_component.rb`)
   - Props: `current_page`, `sync_status`
   - Navigation tabs with active state
   - Sync button with status indicator
   - Action buttons (Settings, Admin)

3. **LeftSidebarComponent** (`components/left_sidebar_component.rb`)
   - Props: `homes`, `selected_home_id`, `selected_room_id`
   - Hierarchical tree navigation
   - Search input
   - Category filters (Motion, Temperature, Battery, Contact)
   - Quick access links (Offline, Low Battery, Active)

4. **RightSidebarComponent** (`components/right_sidebar_component.rb`)
   - Props: `selected_item`, `item_type`
   - Quick stats summary
   - Detail panel (updates based on selection)
   - Action buttons

5. **BreadcrumbComponent** (`components/shared/breadcrumb_component.rb`)
   - Props: `items` (array of {label, url})
   - Clickable navigation path
   - Separator icons

6. **StatusBadgeComponent** (`components/shared/status_badge_component.rb`)
   - Props: `status`, `size` (sm, md, lg)
   - Variants: success, warning, danger, info
   - Optional pulse animation for live updates

7. **StatCardComponent** (`components/shared/stat_card_component.rb`)
   - Props: `label`, `value`, `icon`, `trend`
   - Large value display with icon
   - Optional trend indicator

8. **SearchBarComponent** (`components/shared/search_bar_component.rb`)
   - Props: `placeholder`, `filters`, `on_search`
   - Debounced search (300ms)
   - Filter dropdown integration

### Styling Framework
- **Tailwind CSS** for utility-first styling
- **ViewComponent** for server-side component rendering
- **Stimulus** for lightweight JavaScript interactions

### Success Criteria
- ✅ Application layout renders with all three columns

---

## PRD 2.06: Intelligent Event Deduplication & Room Activity Heatmap

### Objective
Optimize database storage by removing redundant events while enhancing room-level visibility with liveness tracking and activity heatmaps.

### 1. Event Flow Optimization (The "Liveness" Strategy)
Replace the existing 5-minute deduplication window and 15-minute heartbeat with a strict "Value Change Only" storage policy.

**Workflow**:
1. **Liveness Update**: Every incoming event updates `last_seen_at` on Sensor, Accessory, and Room.
2. **Activity Tracking**: 
   - Update `Room#last_event_at` for any event.
   - Update `Room#last_motion_at` specifically for motion detections.
3. **Change Detection**: 
   - If `new_value != current_value` -> Create `HomekitEvent` record + Broadcast UI update.
   - If `new_value == current_value` -> Update metadata only, drop event record.

### 2. Room Activity Heatmap
Visual indicator on room cards/names to show recent activity levels.
- **Logic**: Time since `Room#last_event_at`.
- **Gradient**: 
  - 0-5 mins: Bright Green (Active)
  - 5-15 mins: Pale Green
  - 15-30 mins: Faded Mint
  - > 30 mins: White (Idle)
- **Implementation**: Stimulus controller on the Room component to dynamically update class/style based on a data-attribute timestamp.

### 3. Sensor Value Discovery (Value Map)
Automatic tracking of unique values seen per sensor to build a "Known States" catalog.

**Table: `sensor_value_definitions`**
- `room_id`, `accessory_id`, `sensor_id`
- `value`: (string/json) The raw value from HomeKit.
- `label`: (string) Human-readable alias (e.g., "0" -> "Locked").
- `last_seen_at`: timestamp.
- `occurrence_count`: counter.

### 4. Schema Requirements
- **Room**: Add `last_event_at` (datetime), `last_motion_at` (datetime).
- **Sensor**: Add `last_seen_at` (datetime), `daily_event_count` (integer).
- **Accessory**: Add `last_seen_at` (datetime).
- **New Table**: `sensor_value_definitions` (as defined above).

### 5. Success Criteria
- Consecutive duplicates in `HomekitEvent` table drop to 0%.
- Room index view shows dynamic color coding based on activity.
- Sensors display "Last Seen" time independent of "Last Value Change".
- ✅ Header navigation works with active state highlighting
- ✅ Sidebars collapse on mobile
- ✅ Shared components reusable across views
- ✅ Responsive breakpoints work (640px, 768px, 1024px)

### Technical Implementation
```ruby
# app/components/header_component.rb
class HeaderComponent < ViewComponent::Base
  def initialize(current_page:, sync_status: nil)
    @current_page = current_page
    @sync_status = sync_status
  end

  def nav_items
    [
      { label: "Dashboard", path: root_path, icon: "chart-bar" },
      { label: "Homes", path: homes_path, icon: "home" },
      { label: "Sensors", path: sensors_path, icon: "signal" },
      { label: "Events", path: events_path, icon: "clipboard-list" }
    ]
  end
end
```

---

## PRD 2.2: Homes & Rooms Views

### Objective
Build hierarchical navigation views for homes and rooms with live sensor data.

### Requirements

#### Views to Create

1. **Homes Index** (`/homes`)
   - List all homes with stats (rooms, accessories, sensors, events)
   - Sync status indicator
   - Last sync timestamp
   - Quick action buttons (View Rooms, View Sensors, Recent Events)

2. **Home Show** (`/homes/:id`)
   - Breadcrumb: Home > [Home Name]
   - Summary stats (rooms, accessories, sensors)
   - Rooms grid/list view toggle
   - Recent events for this home

3. **Rooms Grid** (`/homes/:id/rooms` or `/rooms`)
   - Grid of room cards (4 columns on desktop, 2 on tablet, 1 on mobile)
   - Each card shows:
     - Room name with emoji/icon
     - Accessory count, sensor count
     - Live sensor values (temp, humidity, motion)
     - Status indicators
   - Filter by: has sensors, has motion, has temp
   - Search by room name

4. **Room Detail** (`/rooms/:id`)
   - Breadcrumb: Home > Room > [Room Name]
   - Room status bar (temp, humidity, motion, connectivity)
   - Two sections:
     - **Sensors** (8-12 per room): Current values, last updated, status
     - **Other Accessories**: Controllable devices (future: control buttons)
   - Filter sensors by type
   - Click sensor to open detail panel

#### Components

5. **HomeCardComponent** (`components/homes/card_component.rb`)
   - Props: `home`
   - Display stats, sync status
   - Action buttons

6. **RoomCardComponent** (`components/rooms/card_component.rb`)
   - Props: `room`, `compact: false`
   - Live sensor data display
   - Status indicators
   - Click to navigate to room detail

7. **RoomDetailComponent** (`components/rooms/detail_component.rb`)
   - Props: `room`, `accessories`, `sensors`
   - Grouped sections (sensors vs others)
   - Filter controls

### Success Criteria
- ✅ Homes index shows all homes with accurate stats
- ✅ Rooms grid displays with live sensor values
- ✅ Room detail separates sensors from controllable accessories
- ✅ Navigation breadcrumbs work correctly
- ✅ Filters and search functional
- ✅ Responsive on mobile/tablet/desktop

### Controllers
```ruby
# app/controllers/homes_controller.rb
class HomesController < ApplicationController
  def index
    @homes = Home.includes(:rooms, :accessories, :sensors).all
  end

  def show
    @home = Home.includes(rooms: [:accessories, :sensors]).find(params[:id])
    @recent_events = HomekitEvent.where(
      accessory_name: @home.accessories.pluck(:name)
    ).order(timestamp: :desc).limit(50)
  end
end

# app/controllers/rooms_controller.rb
class RoomsController < ApplicationController
  def index
    @rooms = Room.includes(:home, :accessories, :sensors).all
    @rooms = @rooms.joins(:sensors).distinct if params[:has_sensors]
    @rooms = @rooms.where("name ILIKE ?", "%#{params[:search]}%") if params[:search]
  end

  def show
    @room = Room.includes(:home, accessories: :sensors).find(params[:id])
    @sensors = @room.sensors.includes(:accessory)
    @other_accessories = @room.accessories.left_joins(:sensors)
                              .where(sensors: { id: nil })
  end
end
```

---

## PRD 2.3: Sensors Dashboard & Detail Views

### Objective
Create comprehensive sensor monitoring interface with health indicators, alerts, and historical data.

### Requirements

#### Views to Create

1. **Sensors Dashboard** (`/sensors`)
   - **Alerts Section** at top (critical issues)
     - Low battery (<20%)
     - Offline sensors (>1 hour)
     - Unusual readings
   - **Grouped by Type**:
     - 🌡️ Temperature (12 sensors) - Average, min, max, sparklines
     - 🚶 Motion (29 sensors) - Active count, recent activity
     - 💧 Humidity (7 sensors) - Average with range
     - 🔋 Battery (33 sensors) - Low battery count, visual bars
     - 🚪 Contact (8 sensors) - Open/closed states
     - ✓ Status Active (51 sensors) - Active count
   - **Filter Controls**:
     - Type dropdown (All, Temperature, Motion, etc.)
     - Status dropdown (All, Active, Offline, Low Battery)
     - Room dropdown (All, specific room)
     - Search by name
   - **Sort Options**: Name, Last Updated, Value, Status

2. **Sensor Detail** (`/sensors/:id`)
   - **Header Card**:
     - Icon and characteristic type
     - Current value (large, prominent)
     - Last updated (relative time)
     - Status badge (Active, Offline, Low Battery)
     - Metadata (UUID, service type, writable, supports events)
   - **Activity Chart** (Chart.js or similar):
     - Time range selector (24h, 7d, 30d, custom)
     - Line/bar chart showing value over time
     - Statistics (min, max, average, changes count)
   - **Recent Events Table**:
     - Timestamp, value, changed (yes/no), source
     - Pagination (50 per page)
     - Export to CSV button
     - Filter by date range
   - **Actions**:
     - Favorite sensor (for quick access)
     - Add alert rule
     - Export data
     - View in room context

3. **Sensor Type Views** (`/sensors/temperature`, `/sensors/motion`, etc.)
   - Filtered view of sensors dashboard
   - Type-specific visualizations
   - Bulk actions (export all, set alert rules)

#### Components

4. **SensorCardComponent** (`components/sensors/card_component.rb`)
   - Props: `sensor`, `show_chart: false`, `compact: false`
   - Icon based on characteristic type
   - Current value with units
   - Status badge
   - Last updated timestamp
   - Optional mini sparkline

5. **SensorDetailComponent** (`components/sensors/detail_component.rb`)
   - Props: `sensor`, `events`, `time_range`
   - Full sensor information
   - Chart integration
   - Event list

6. **ActivityChartComponent** (`components/charts/activity_chart_component.rb`)
   - Props: `sensor`, `time_range`, `chart_type`
   - Chart.js integration
   - Responsive
   - Interactive tooltips

7. **BatteryIndicatorComponent** (`components/sensors/battery_indicator_component.rb`)
   - Props: `level`, `charging`, `low_threshold`
   - Visual battery icon
   - Color coding (red <20%, yellow <50%, green ≥50%)
   - Charging animation

8. **AlertBannerComponent** (`components/sensors/alert_banner_component.rb`)
   - Props: `alerts` (array)
   - Critical/warning sections
   - Dismiss functionality
   - Click to view detail

### Success Criteria
- ✅ Dashboard shows all sensors grouped by type
- ✅ Alert section highlights critical issues
- ✅ Sensor detail displays current value and history chart
- ✅ Charts render correctly with time range selector
- ✅ Event log paginated and exportable
- ✅ Filters and search work across all views
- ✅ Battery indicators show correct status
- ✅ Performance: Dashboard loads <500ms for 253 sensors

### Controllers
```ruby
# app/controllers/sensors_controller.rb
class SensorsController < ApplicationController
  def index
    @sensors = Sensor.includes(:accessory, room: :home)

    # Filters
    @sensors = @sensors.where(characteristic_type: params[:type]) if params[:type]
    @sensors = @sensors.where('last_updated_at < ?', 1.hour.ago) if params[:status] == 'offline'
    @sensors = @sensors.battery_level.where('current_value < ?', 20) if params[:status] == 'low_battery'
    @sensors = @sensors.joins(:room).where(rooms: { id: params[:room_id] }) if params[:room_id]
    @sensors = @sensors.where('sensors.characteristic_type ILIKE ?', "%#{params[:search]}%") if params[:search]

    # Alerts
    @alerts = {
      low_battery: Sensor.battery_level.where('current_value < ?', 20),
      offline: Sensor.where('last_updated_at < ?', 1.hour.ago)
    }
  end

  def show
    @sensor = Sensor.includes(accessory: { room: :home }).find(params[:id])
    @time_range = params[:time_range] || '24h'

    range_start = case @time_range
    when '24h' then 24.hours.ago
    when '7d' then 7.days.ago
    when '30d' then 30.days.ago
    else params[:start_date]&.to_datetime || 24.hours.ago
    end

    @events = @sensor.events.where('timestamp >= ?', range_start)
                    .order(timestamp: :desc)
                    .page(params[:page]).per(50)
  end

  def chart_data
    sensor = Sensor.find(params[:id])
    time_range = params[:time_range] || '24h'

    # Return JSON data for Chart.js
    render json: {
      labels: events.pluck(:timestamp),
      values: events.pluck(:value),
      sensor: sensor.characteristic_type
    }
  end
end
```

---

## PRD 2.4: Event Log Viewer with Real-Time Updates

### Objective
Build live event log with filtering, search, and real-time updates via ActionCable.

### Requirements

#### Views to Create

1. **Events Index** (`/events`)
   - **Statistics Bar** at top:
     - Total events (time period)
     - Sensor events count/percentage
     - Control events count/percentage
     - Match rate (events matched to sensors)
     - Deduplication rate
     - Events per minute
   - **Filter Controls**:
     - Time range (Last Hour, Last 24h, Last 7d, Custom Range)
     - Event type checkboxes (Sensors, Control, System, Webhook)
     - Room dropdown
     - Accessory dropdown
     - Search input (accessory name or characteristic)
     - Live mode toggle
   - **Event Table**:
     - Columns: Timestamp, Room, Accessory, Characteristic, Value
     - Status indicators (NEW, deduped icon)
     - Color coding by event type
     - Click row to expand raw JSON payload
     - Pagination (50 per page) or infinite scroll
     - Auto-scroll to top on new events (live mode)
   - **Export Button**: Download filtered events as CSV

2. **Live Updates**:
   - ActionCable subscription to `EventsChannel`
   - New events appear at top with "NEW" badge
   - Auto-update statistics bar
   - Respect current filters
   - Pause button to stop live updates
   - Sound notification option (user preference)

#### Components

3. **EventRowComponent** (`components/events/row_component.rb`)
   - Props: `event`, `highlight_changes: false`
   - Formatted timestamp
   - Breadcrumb (Home > Room > Accessory)
   - Characteristic and value display
   - Status indicators (matched, deduped)
   - Expandable raw payload

4. **EventStatisticsComponent** (`components/events/statistics_component.rb`)
   - Props: `events`, `time_range`
   - Calculate and display stats
   - Visual indicators (charts, percentages)

5. **EventFilterComponent** (`components/events/filter_component.rb`)
   - Props: `filters`, `on_change`
   - All filter controls
   - Clear filters button

### Real-Time Implementation

#### ActionCable Channels
```ruby
# app/channels/events_channel.rb
class EventsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "events"
  end

  def unsubscribed
    stop_all_streams
  end
end

# Broadcast from webhook controller
# app/controllers/api/homekit_events_controller.rb
def create
  # ... existing code ...

  # Broadcast to subscribers
  ActionCable.server.broadcast("events", {
    event: {
      id: @event.id,
      timestamp: @event.timestamp,
      accessory_name: @event.accessory_name,
      characteristic: @event.characteristic,
      value: @event.value,
      event_type: @event.event_type
    }
  })
end
```

#### Stimulus Controller
```javascript
// app/javascript/controllers/events_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["table", "stats", "liveToggle"]

  connect() {
    this.subscription = consumer.subscriptions.create("EventsChannel", {
      received: (data) => {
        if (this.liveMode) {
          this.prependEvent(data.event)
          this.updateStats()
          this.playSound()
        }
      }
    })
  }

  disconnect() {
    this.subscription.unsubscribe()
  }

  toggleLive() {
    this.liveMode = !this.liveMode
    this.liveToggleTarget.classList.toggle("active")
  }

  prependEvent(event) {
    // Add event row to top of table with "NEW" badge
    const row = this.createEventRow(event)
    this.tableTarget.prepend(row)
  }
}
```

### Success Criteria
- ✅ Event log displays all events with proper formatting
- ✅ Filters work correctly (time, type, room, accessory)
- ✅ Live updates via ActionCable working
- ✅ New events appear in real-time with "NEW" badge
- ✅ Statistics update automatically
- ✅ Expandable raw JSON payload
- ✅ Export to CSV functional
- ✅ Performance: Handle 50+ events/minute without lag
- ✅ Pagination or infinite scroll working

### Controllers
```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  def index
    @events = HomekitEvent.includes(accessory: { room: :home })
                          .order(timestamp: :desc)

    # Time filter
    @time_range = params[:time_range] || 'hour'
    range_start = case @time_range
    when 'hour' then 1.hour.ago
    when '24h' then 24.hours.ago
    when '7d' then 7.days.ago
    else params[:start_date]&.to_datetime || 1.hour.ago
    end
    @events = @events.where('timestamp >= ?', range_start)

    # Type filter
    if params[:types].present?
      sensor_types = ['characteristic_updated']
      if params[:types].include?('sensors')
        @events = @events.where(event_type: sensor_types)
      end
    end

    # Room/Accessory filter
    @events = @events.joins(accessory: :room).where(rooms: { id: params[:room_id] }) if params[:room_id]
    @events = @events.where(accessory_name: params[:accessory]) if params[:accessory]

    # Search
    @events = @events.where('accessory_name ILIKE ? OR characteristic ILIKE ?',
                           "%#{params[:search]}%", "%#{params[:search]}%") if params[:search]

    @events = @events.page(params[:page]).per(50)

    # Statistics
    @stats = {
      total: @events.count,
      sensor_events: @events.where(event_type: 'characteristic_updated').count,
      events_per_minute: @events.count / ((Time.current - range_start) / 60.0)
    }
  end

  def show
    @event = HomekitEvent.find(params[:id])
  end
end
```

---

## PRD 2.5: Styling & Design System

### Objective
Implement consistent design system with iOS-inspired aesthetics and responsive components.

### Requirements

#### Design System

1. **Color Palette**
   ```scss
   // Primary
   $primary: #007AFF;        // iOS Blue
   $primary-dark: #0051D5;
   $primary-light: #5AC8FA;

   // Status
   $success: #34C759;        // Green
   $warning: #FF9500;        // Orange
   $danger: #FF3B30;         // Red
   $info: #5856D6;           // Purple

   // Neutrals
   $background: #F2F2F7;     // Light gray
   $surface: #FFFFFF;        // Card background
   $border: #C6C6C8;
   $text-primary: #000000;
   $text-secondary: #3C3C43;
   $text-tertiary: #8E8E93;
   ```

2. **Typography**
   - Font: System font stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto`)
   - Sizes: 12px (xs), 14px (sm), 16px (base), 18px (lg), 20px (xl), 24px (2xl), 32px (3xl)
   - Weights: 400 (normal), 500 (medium), 600 (semibold), 700 (bold)

3. **Spacing System** (4px base unit)
   - 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px

4. **Border Radius**
   - Small: 4px (badges, tags)
   - Medium: 8px (cards, buttons)
   - Large: 12px (panels, modals)
   - Full: 9999px (pills, circular)

5. **Shadows**
   - Small: `0 1px 2px rgba(0, 0, 0, 0.05)`
   - Medium: `0 4px 6px rgba(0, 0, 0, 0.07)`
   - Large: `0 10px 15px rgba(0, 0, 0, 0.1)`
   - XL: `0 20px 25px rgba(0, 0, 0, 0.15)`

6. **Sensor Type Icons & Colors**
   - Temperature: 🌡️ #FF9500
   - Motion: 🚶 #5856D6
   - Humidity: 💧 #5AC8FA
   - Light: 💡 #FFD60A
   - Battery: 🔋 #34C759
   - Contact: 🚪 #FF9500
   - Occupancy: 👤 #AF52DE
   - Tampered: ⚠️ #FF3B30
   - Active: ✓ #34C759
   - Charging: ⚡ #34C759

#### Tailwind Configuration
```javascript
// tailwind.config.js
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/components/**/*.{rb,erb}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        primary: '#007AFF',
        success: '#34C759',
        warning: '#FF9500',
        danger: '#FF3B30',
        info: '#5856D6'
      },
      spacing: {
        '1': '4px',
        '2': '8px',
        '3': '12px',
        '4': '16px',
        '5': '24px',
        '6': '32px',
        '8': '48px',
        '10': '64px'
      }
    }
  }
}
```

#### Component Styles

7. **Card Component**
   ```css
   .card {
     @apply bg-white border border-gray-200 rounded-lg p-4 shadow-sm;
     @apply hover:shadow-md transition-shadow duration-200;
   }
   ```

8. **Button Styles**
   ```css
   .btn {
     @apply font-medium px-4 py-2 rounded-lg border-none cursor-pointer;
     @apply transition-all duration-200;
   }
   .btn-primary {
     @apply bg-blue-500 text-white hover:bg-blue-600;
   }
   .btn-secondary {
     @apply bg-gray-100 text-gray-900 hover:bg-gray-200;
   }
   .btn-danger {
     @apply bg-red-500 text-white hover:bg-red-600;
   }
   ```

9. **Status Badge**
   ```css
   .badge {
     @apply inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium;
   }
   .badge-success {
     @apply bg-green-100 text-green-700;
   }
   .badge-warning {
     @apply bg-orange-100 text-orange-700;
   }
   .badge-danger {
     @apply bg-red-100 text-red-700;
   }
   ```

10. **Responsive Breakpoints**
    - Mobile: <640px
    - Tablet: 640px - 1024px
    - Desktop: >1024px

    ```css
    @media (max-width: 768px) {
      .left-sidebar, .right-sidebar {
        display: none;
      }
    }
    ```

### Success Criteria
- ✅ Consistent color palette applied throughout
- ✅ Typography system implemented
- ✅ All components use design system tokens
- ✅ Responsive design works on mobile/tablet/desktop
- ✅ Accessibility: WCAG AA contrast ratios (4.5:1 minimum)
- ✅ Dark mode support (future enhancement)

---

## Technical Stack

### Frontend
- **Framework**: Ruby on Rails 8.1.2 with Hotwire (Turbo + Stimulus)
- **Styling**: Tailwind CSS 3.x
- **Components**: ViewComponent
- **Charts**: Chart.js or similar
- **Icons**: Heroicons or FontAwesome
- **Real-time**: ActionCable (WebSockets)

### Backend
- **Framework**: Rails 8.1.2
- **Database**: PostgreSQL 16
- **Caching**: Rails.cache (memory or Redis)
- **Background Jobs**: Solid Queue (Rails 8 default)

### Performance Optimizations
1. **Database**:
   - Proper indexes on frequently queried fields
   - Eager loading with `includes()` to prevent N+1 queries
   - Cached counts for stats (5 minute TTL)

2. **Frontend**:
   - Lazy load charts (only when visible)
   - Pagination for event logs (50 per page)
   - Debounced search (300ms)
   - Turbo Frames for partial updates

3. **Real-time**:
   - ActionCable for WebSocket connections
   - Broadcast only to subscribed channels
   - Throttle broadcasts (max 10/second per channel)

### Accessibility
- Semantic HTML5 elements
- ARIA labels for interactive elements
- Keyboard navigation (Tab, Enter, Escape)
- Focus indicators (visible outline)
- Screen reader friendly (proper heading hierarchy)
- Skip navigation links

### Browser Support
- Modern browsers: Chrome, Firefox, Safari, Edge (last 2 versions)
- No IE11 support

---

## Success Criteria for Epic 2

- ✅ All 5 PRDs implemented and functional
- ✅ Responsive UI works on mobile/tablet/desktop
- ✅ Real-time updates via ActionCable working
- ✅ All sensor types displayed with correct icons/colors
- ✅ Event log shows live updates with <1 second latency
- ✅ Dashboard loads in <500ms for 253 sensors
- ✅ Filters, search, and pagination working correctly
- ✅ Design system consistently applied
- ✅ Accessibility standards met (WCAG AA)
- ✅ No N+1 query issues
- ✅ Test coverage >80% for components

---

## Testing Strategy

### Unit Tests
- ViewComponent tests for all components
- Controller tests for all actions
- Model tests for queries and scopes

### Integration Tests
- Full page load tests
- Filter/search functionality
- Navigation between views
- ActionCable subscription/broadcast

### System Tests
- End-to-end user flows
- Real-time update scenarios
- Mobile responsive behavior
- Accessibility (axe-core)

---

## Future Enhancements (Post-Epic 2)

1. **Dark Mode** - Theme switcher with system preference detection
2. **Customizable Dashboards** - Drag-and-drop widgets
3. **Alert Rules** - User-defined thresholds and notifications
4. **Scene Management** - View and trigger HomeKit scenes
5. **Automation Builder** - Visual interface for creating automations
6. **Export/Import** - Backup and restore configurations
7. **Multi-Home Support** - Switch between multiple HomeKit homes
8. **User Roles** - Admin, viewer, operator permissions
9. **Mobile App** - Native iOS/Android apps (React Native or similar)
10. **Voice Commands** - Integration with Siri/Alexa/Google

---

## Dependencies

- Epic 1 (Rails Server + Prefab Integration) must be complete
- Database models: Home, Room, Accessory, Sensor, HomekitEvent
- Webhook endpoint receiving events
- Prefab sync working

---

## Timeline Estimate

- **PRD 2.1** (Layout & Components): 3-4 days
- **PRD 2.2** (Homes & Rooms): 2-3 days
- **PRD 2.3** (Sensors Dashboard): 4-5 days
- **PRD 2.4** (Event Log): 3-4 days
- **PRD 2.5** (Styling): 2-3 days
- **Testing & Polish**: 2-3 days

**Total: 16-22 days** (3-4 weeks)

---

**Epic Created**: 2026-01-26
**Status**: Planning
**Owner**: @ericsmith66
**Dependencies**: Epic 1 Complete
