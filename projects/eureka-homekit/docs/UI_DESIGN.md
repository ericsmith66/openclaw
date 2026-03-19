# HomeKit Dashboard UI Design

## Overview
A comprehensive web interface for navigating and monitoring HomeKit homes, rooms, accessories, sensors, and event logs with real-time updates and hierarchical navigation.

---

## Component Architecture

### Core Layout Components

#### 1. **AppLayout** (`layouts/application_layout.rb`)
Main application wrapper with header, three-column layout
- Header with navigation tabs
- Sticky left sidebar (240px)
- Flexible main content area
- Sticky right sidebar (320px)
- Responsive: Collapses to single column on mobile

#### 2. **Header** (`components/header_component.rb`)
Top navigation bar
- Props: `current_user`, `sync_status`
- Logo and title
- Main navigation tabs (Dashboard, Homes, Sensors, Events, Alerts)
- Action buttons (Sync, Settings, Admin)
- Live sync status indicator

#### 3. **LeftSidebar** (`components/left_sidebar_component.rb`)
Navigation tree and quick filters
- Props: `homes`, `selected_home_id`, `selected_room_id`
- Search input
- Hierarchical tree (Homes → Rooms → Accessories)
- Category filters (Motion, Temperature, Battery, etc.)
- Quick access links (Offline, Low Battery, Active)
- Recent events summary

#### 4. **RightSidebar** (`components/right_sidebar_component.rb`)
Context-sensitive details panel
- Props: `selected_item`, `item_type`
- Quick stats summary
- Selected item details
- Action buttons
- Related data preview

---

### Page Components

#### 5. **HomesIndex** (`components/homes/index_component.rb`)
Home listing page
- Props: `homes`
- Home cards with stats
- Sync status and timestamps
- Quick action buttons

#### 6. **RoomGrid** (`components/rooms/grid_component.rb`)
Room overview in grid layout
- Props: `rooms`, `view_mode` (grid|list)
- Room cards with live sensor data
- Filter and search
- Visual status indicators

#### 7. **RoomDetail** (`components/rooms/detail_component.rb`)
Detailed room view with accessories
- Props: `room`, `accessories`, `sensors`
- Grouped by type (Sensors vs Other Accessories)
- Live sensor values
- Control buttons for controllable accessories

#### 8. **SensorsDashboard** (`components/sensors/dashboard_component.rb`)
All sensors overview
- Props: `sensors`, `alerts`, `filters`
- Alert section at top
- Grouped by sensor type
- Visual indicators (progress bars, status badges)
- Filter and search capabilities

#### 9. **SensorDetail** (`components/sensors/detail_component.rb`)
Individual sensor with history
- Props: `sensor`, `events`, `time_range`
- Current value card
- Activity chart (24h/7d/30d)
- Event list with pagination
- Export functionality

#### 10. **EventLog** (`components/events/log_component.rb`)
Event viewer with live updates
- Props: `events`, `filters`, `live_mode`
- Statistics summary
- Filterable event table
- Real-time updates via ActionCable
- Pagination and infinite scroll
- Raw JSON payload viewer

---

### Shared Components

#### 11. **SensorCard** (`components/sensors/card_component.rb`)
Reusable sensor display card
- Props: `sensor`, `show_chart`, `compact`
- Icon based on type
- Current value with units
- Status badge
- Last updated timestamp
- Mini sparkline chart (optional)

#### 12. **EventRow** (`components/events/row_component.rb`)
Single event in log
- Props: `event`, `highlight_changes`
- Timestamp
- Breadcrumb (Home > Room > Accessory)
- Characteristic and value
- Status indicators (deduped, matched)
- Click to expand raw payload

#### 13. **StatusBadge** (`components/shared/status_badge_component.rb`)
Status indicator
- Props: `status`, `size`
- Variants: success, warning, danger, info
- Icons and colors
- Optional pulse animation

#### 14. **BreadcrumbTrail** (`components/shared/breadcrumb_component.rb`)
Navigation breadcrumbs
- Props: `items`
- Clickable path
- Separator icons

#### 15. **StatCard** (`components/shared/stat_card_component.rb`)
Quick stat display
- Props: `label`, `value`, `icon`, `trend`
- Large value display
- Optional trend indicator
- Icon with background color

#### 16. **ActivityChart** (`components/charts/activity_chart_component.rb`)
Time-series chart for sensor data
- Props: `sensor`, `time_range`, `chart_type`
- Uses Chart.js or similar
- Responsive
- Interactive tooltips

#### 17. **BatteryIndicator** (`components/sensors/battery_indicator_component.rb`)
Battery level visualization
- Props: `level`, `charging`, `low_threshold`
- Visual battery icon
- Color coding (red < 20%, yellow < 50%, green ≥ 50%)
- Charging indicator

#### 18. **SearchBar** (`components/shared/search_bar_component.rb`)
Search input with filters
- Props: `placeholder`, `filters`, `on_search`
- Debounced search
- Filter dropdown integration
- Clear button

---

## Data Models & Controller Actions

### Controllers

```ruby
# app/controllers/homes_controller.rb
class HomesController < ApplicationController
  def index     # List all homes
  def show      # Home detail with rooms
end

# app/controllers/rooms_controller.rb
class RoomsController < ApplicationController
  def index     # List rooms (filterable)
  def show      # Room detail with accessories
end

# app/controllers/accessories_controller.rb
class AccessoriesController < ApplicationController
  def index     # List accessories (filterable)
  def show      # Accessory detail with sensors
end

# app/controllers/sensors_controller.rb
class SensorsController < ApplicationController
  def index     # Sensors dashboard
  def show      # Sensor detail with history
  def chart     # Chart data API (JSON)
end

# app/controllers/events_controller.rb
class EventsController < ApplicationController
  def index     # Event log with filters
  def show      # Single event detail
  def live      # SSE/ActionCable for live updates
end

# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index     # Main dashboard overview
end
```

---

## Navigation Tree Structure

```
Dashboard (/)
│
├─ Homes (/homes)
│  └─ [Home Name] (/homes/:id)
│     ├─ Overview (stats, recent events)
│     ├─ Rooms (/homes/:id/rooms)
│     │  └─ [Room Name] (/rooms/:id)
│     │     ├─ Accessories List
│     │     ├─ Sensors (/rooms/:id/sensors)
│     │     └─ Events (/rooms/:id/events)
│     └─ All Sensors (/homes/:id/sensors)
│
├─ Sensors (/sensors)
│  ├─ Dashboard (grouped by type)
│  ├─ Alerts (/sensors/alerts)
│  ├─ Offline (/sensors/offline)
│  ├─ Low Battery (/sensors/low-battery)
│  ├─ By Type
│  │  ├─ Temperature (/sensors/temperature)
│  │  ├─ Motion (/sensors/motion)
│  │  ├─ Battery (/sensors/battery)
│  │  ├─ Contact (/sensors/contact)
│  │  └─ ... (other types)
│  └─ [Sensor Detail] (/sensors/:id)
│     ├─ Current Value
│     ├─ History Chart
│     └─ Events (/sensors/:id/events)
│
├─ Events (/events)
│  ├─ Live Log
│  ├─ Filters (by time, type, room, accessory)
│  ├─ Search
│  └─ Export
│
├─ Alerts (/alerts)
│  ├─ Active Alerts
│  ├─ Alert Rules
│  └─ History
│
└─ Settings (/settings)
   ├─ Sync Configuration
   ├─ Webhook Settings
   └─ Display Preferences
```

---

## Style Guide

### Color Palette

```scss
// Primary Colors
$primary: #007AFF;        // iOS Blue
$primary-dark: #0051D5;
$primary-light: #5AC8FA;

// Status Colors
$success: #34C759;        // Green
$warning: #FF9500;        // Orange
$danger: #FF3B30;         // Red
$info: #5856D6;           // Purple

// Neutrals
$background: #F2F2F7;     // Light gray background
$surface: #FFFFFF;        // Card/panel background
$border: #C6C6C8;         // Subtle borders
$text-primary: #000000;
$text-secondary: #3C3C43;
$text-tertiary: #8E8E93;

// Semantic Colors
$online: #34C759;
$offline: #8E8E93;
$active: #FF9500;
$inactive: #C6C6C8;
```

### Typography

```scss
// Font Family
$font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
              "Helvetica Neue", Arial, sans-serif;
$font-mono: "SF Mono", Monaco, "Cascadia Code", "Courier New", monospace;

// Font Sizes
$font-size-xs: 0.75rem;   // 12px - Captions
$font-size-sm: 0.875rem;  // 14px - Body small
$font-size-base: 1rem;    // 16px - Body
$font-size-lg: 1.125rem;  // 18px - Subheadings
$font-size-xl: 1.25rem;   // 20px - Headings
$font-size-2xl: 1.5rem;   // 24px - Page titles
$font-size-3xl: 2rem;     // 32px - Large values

// Font Weights
$font-weight-normal: 400;
$font-weight-medium: 500;
$font-weight-semibold: 600;
$font-weight-bold: 700;
```

### Spacing System

```scss
// 4px base unit
$space-1: 0.25rem;   // 4px
$space-2: 0.5rem;    // 8px
$space-3: 0.75rem;   // 12px
$space-4: 1rem;      // 16px
$space-5: 1.5rem;    // 24px
$space-6: 2rem;      // 32px
$space-8: 3rem;      // 48px
$space-10: 4rem;     // 64px
```

### Border Radius

```scss
$radius-sm: 4px;     // Small elements (badges, tags)
$radius-md: 8px;     // Cards, buttons
$radius-lg: 12px;    // Panels, modals
$radius-full: 9999px; // Pills, circular elements
```

### Shadows

```scss
$shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
$shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
$shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
$shadow-xl: 0 20px 25px rgba(0, 0, 0, 0.15);
```

### Component Styles

#### Cards
```scss
.card {
  background: $surface;
  border: 1px solid $border;
  border-radius: $radius-md;
  padding: $space-4;
  box-shadow: $shadow-sm;
  transition: box-shadow 0.2s ease;

  &:hover {
    box-shadow: $shadow-md;
  }
}
```

#### Buttons
```scss
.btn {
  font-weight: $font-weight-medium;
  padding: $space-2 $space-4;
  border-radius: $radius-md;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;

  &-primary {
    background: $primary;
    color: white;
    &:hover { background: $primary-dark; }
  }

  &-secondary {
    background: $background;
    color: $text-primary;
    &:hover { background: darken($background, 5%); }
  }

  &-danger {
    background: $danger;
    color: white;
    &:hover { background: darken($danger, 10%); }
  }
}
```

#### Status Badges
```scss
.badge {
  display: inline-flex;
  align-items: center;
  gap: $space-1;
  padding: $space-1 $space-2;
  border-radius: $radius-sm;
  font-size: $font-size-xs;
  font-weight: $font-weight-medium;

  &-success {
    background: rgba($success, 0.1);
    color: $success;
  }

  &-warning {
    background: rgba($warning, 0.1);
    color: $warning;
  }

  &-danger {
    background: rgba($danger, 0.1);
    color: $danger;
  }

  &-info {
    background: rgba($info, 0.1);
    color: $info;
  }
}
```

#### Icons
```scss
// Use Heroicons, FontAwesome, or similar
.icon {
  width: 1.25rem;
  height: 1.25rem;

  &-sm { width: 1rem; height: 1rem; }
  &-lg { width: 1.5rem; height: 1.5rem; }
  &-xl { width: 2rem; height: 2rem; }
}
```

### Sensor Type Icons & Colors

```scss
// Icon-color pairings for sensor types
$sensor-types: (
  'temperature': (#FF9500, '🌡️'),
  'motion': (#5856D6, '🚶'),
  'humidity': (#5AC8FA, '💧'),
  'light': (#FFD60A, '💡'),
  'battery': (#34C759, '🔋'),
  'contact': (#FF9500, '🚪'),
  'occupancy': (#AF52DE, '👤'),
  'tampered': (#FF3B30, '⚠️'),
  'active': (#34C759, '✓'),
  'charging': (#34C759, '⚡')
);
```

### Responsive Breakpoints

```scss
$breakpoint-sm: 640px;   // Mobile landscape
$breakpoint-md: 768px;   // Tablet portrait
$breakpoint-lg: 1024px;  // Tablet landscape / small desktop
$breakpoint-xl: 1280px;  // Desktop
$breakpoint-2xl: 1536px; // Large desktop

// Mobile-first approach
@media (max-width: $breakpoint-md) {
  .left-sidebar, .right-sidebar {
    display: none; // Hide sidebars on mobile
  }
}
```

### Animation & Transitions

```scss
$transition-fast: 150ms ease;
$transition-base: 200ms ease;
$transition-slow: 300ms ease;

// Pulse animation for live updates
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.live-indicator {
  animation: pulse 2s infinite;
}

// Slide in for sidebars
@keyframes slideIn {
  from { transform: translateX(-100%); }
  to { transform: translateX(0); }
}
```

---

## Real-Time Updates

### ActionCable Channels

```ruby
# app/channels/events_channel.rb
class EventsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "events"
  end
end

# app/channels/sensors_channel.rb
class SensorsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "sensors"
  end
end
```

### JavaScript Integration

```javascript
// Subscribe to events
const eventsChannel = consumer.subscriptions.create("EventsChannel", {
  received(data) {
    // Update event log in real-time
    appendEventToLog(data.event);
  }
});

// Subscribe to sensor updates
const sensorsChannel = consumer.subscriptions.create("SensorsChannel", {
  received(data) {
    // Update sensor value in UI
    updateSensorValue(data.sensor_id, data.value);
  }
});
```

---

## Accessibility

- Semantic HTML5 elements
- ARIA labels for interactive elements
- Keyboard navigation support (Tab, Enter, Escape)
- Focus indicators (outline on focus)
- Color contrast ratios (WCAG AA minimum: 4.5:1)
- Screen reader friendly (proper heading hierarchy)
- Skip navigation links

---

## Performance Optimizations

1. **Lazy Loading**: Load sensor history charts only when visible
2. **Pagination**: Event logs paginated (50 per page)
3. **Debounced Search**: 300ms debounce on search inputs
4. **Cached Queries**: Cache room/accessory counts for 5 minutes
5. **Turbo Frames**: Use Turbo for partial page updates
6. **WebSockets**: ActionCable for real-time updates (not polling)
7. **Indexes**: Proper database indexes on frequently queried fields

---

## Mobile Considerations

- Single column layout on mobile
- Bottom navigation bar instead of top tabs
- Collapsible sections
- Touch-friendly tap targets (minimum 44x44px)
- Pull-to-refresh for sensor dashboard
- Swipe gestures for navigation

---

## Future Enhancements

- Dark mode support
- Customizable dashboard widgets
- Alert rule builder UI
- Scene management interface
- Automation creation UI
- Export/import configurations
- Multi-home support in UI
- User roles and permissions
