I'll create a comprehensive UI wireframe for navigating the HomeKit data structure. Let me design this with a focus on hierarchical navigation and real-time sensor monitoring.

```
================================================================================
                        HOMEKIT DASHBOARD WIREFRAME
================================================================================

LAYOUT: Three-Column Layout with Sticky Navigation
--------------------------------------------------------------------------------

┌─────────────────────────────────────────────────────────────────────────────┐
│                         HEADER / TOP NAVIGATION                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  [🏠 HomeKit Dashboard]         [🔄 Sync] [⚙️ Settings] [👤 Admin]  │   │
│  │                                                                       │   │
│  │  📊 Dashboard  |  🏠 Homes  |  📡 Sensors  |  📋 Events  |  🔔 Alerts │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┬──────────────────────────────────┬──────────────────────┐
│   LEFT SIDEBAR   │        MAIN CONTENT AREA         │   RIGHT SIDEBAR      │
│   (Navigation)   │                                  │   (Details/Actions)  │
│      240px       │            Flexible              │       320px          │
├──────────────────┼──────────────────────────────────┼──────────────────────┤
│                  │                                  │                      │
│ 🔍 [Search...]   │  ┌────────────────────────────┐ │  ┌─────────────────┐ │
│                  │  │    BREADCRUMB TRAIL        │ │  │ QUICK STATS     │ │
│ 📂 Homes (1)     │  │  Home > Room > Accessory   │ │  │                 │ │
│  └─► Waverly     │  └────────────────────────────┘ │  │ 🏠 1 Home       │ │
│      └─► [35]    │                                  │  │ 🚪 35 Rooms     │ │
│                  │  ┌────────────────────────────┐ │  │ 💡 399 Access.  │ │
│ 📊 Categories    │  │                            │ │  │ 📡 253 Sensors  │ │
│  ├─► Motion (29) │  │    ACTIVE CONTENT VIEW     │ │  │                 │ │
│  ├─► Temp (12)   │  │                            │ │  │ 🔴 3 Alerts     │ │
│  ├─► Battery(33) │  │   (Changes based on        │ │  │ ⚠️  12 Warnings │ │
│  └─► Contact(8)  │  │    selected view)          │ │  │ ✅ 238 OK       │ │
│                  │  │                            │ │  └─────────────────┘ │
│ 🎯 Quick Access  │  │                            │ │                      │
│  ├─► Offline     │  │                            │ │  ┌─────────────────┐ │
│  ├─► Low Battery │  │                            │ │  │ SELECTED ITEM   │ │
│  └─► Active Now  │  │                            │ │  │                 │ │
│                  │  │                            │ │  │ (Details panel  │ │
│ 📋 Recent Events │  │                            │ │  │  updates based  │ │
│  └─► Last 100    │  │                            │ │  │  on selection)  │ │
│                  │  │                            │ │  │                 │ │
│                  │  └────────────────────────────┘ │  └─────────────────┘ │
└──────────────────┴──────────────────────────────────┴──────────────────────┘


================================================================================
                            VIEW 1: HOMES INDEX
================================================================================

┌────────────────────────────────────────────────────────────────────────────┐
│ 🏠 Homes                                             [+ Add Home] [🔄 Sync] │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │  🏠  WAVERLY                                          Last sync: 2m  │ │
│  │                                                                      │ │
│  │  📊  35 Rooms  │  399 Accessories  │  253 Sensors  │  3,144 Events │ │
│  │                                                                      │ │
│  │  Status: ✅ Online  │  UUID: abc123...                             │ │
│  │                                                                      │ │
│  │  [View Rooms →]  [View All Sensors]  [Recent Events]              │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘


================================================================================
                          VIEW 2: ROOM HIERARCHY
================================================================================

┌────────────────────────────────────────────────────────────────────────────┐
│ 🏠 Waverly > 🚪 Rooms                                    [View: Grid | List] │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  🔍 Filter: [All Rooms ▼]  [Has Sensors ▼]  Search: [...................] │
│                                                                            │
│ ┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐ │
│ │ 🛏️ Master Bedroom│ 👶 Jacob's Room │ 🍳 Kitchen      │ 🛋️ Living Room  │ │
│ │                 │                 │                 │                 │ │
│ │ 12 Accessories  │ 8 Accessories   │ 23 Accessories  │ 15 Accessories  │ │
│ │ 8 Sensors       │ 4 Sensors       │ 12 Sensors      │ 9 Sensors       │ │
│ │                 │                 │                 │                 │ │
│ │ 🌡️ 68°F  💧 45% │ 🚪 Open  🔋 85% │ 💡 3 On  🔌 2   │ 🎵 Playing      │ │
│ │                 │                 │                 │                 │ │
│ │ [View →]        │ [View →]        │ [View →]        │ [View →]        │ │
│ └─────────────────┴─────────────────┴─────────────────┴─────────────────┘ │
│                                                                            │
│ ┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐ │
│ │ 🚿 Master Bath  │ 🏃 Utility Room │ 🚗 Garage       │ 🌳 Courtyard    │ │
│ │ ...             │ ...             │ ...             │ ...             │ │
│ └─────────────────┴─────────────────┴─────────────────┴─────────────────┘ │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘


================================================================================
                       VIEW 3: ROOM DETAIL (Accessories)
================================================================================

┌────────────────────────────────────────────────────────────────────────────┐
│ 🏠 Waverly > 🚪 Master Bedroom                         [Edit] [⚙️ Settings] │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Room Status: ✅ Online  │  Temp: 68°F  │  Humidity: 45%  │  Motion: None │
│                                                                            │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │ 📡 SENSORS (8)                                      [Filter: All ▼]   │  │
│ ├──────────────────────────────────────────────────────────────────────┤  │
│ │                                                                      │  │
│ │  🌡️  Master Thermostat - Current Temperature        68°F   ✅ 2m   │  │
│ │  💧  Master Thermostat - Current Humidity           45%    ✅ 2m   │  │
│ │  🚶  Master Bath Sensor - Motion Detected          false   ✅ 1m   │  │
│ │  💡  Master Bath Sensor - Light Level               101    ✅ 1m   │  │
│ │  🔋  Bedside Lamp - Battery Level                   85%    ✅ 5m   │  │
│ │  ⚡  Bedside Lamp - Charging State                  Yes    ✅ 5m   │  │
│ │  🚪  Window Sensor - Contact State                  Open   ⚠️  15m  │  │
│ │  🔋  Window Sensor - Battery Level                  12%    🔴 15m  │  │
│ │                                                                      │  │
│ │  [View All Sensors →]                                               │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │ 💡 OTHER ACCESSORIES (4)                                             │  │
│ ├──────────────────────────────────────────────────────────────────────┤  │
│ │  💡  Ceiling Light                        On, 75%          [Control] │  │
│ │  🔌  Smart Outlet                         Off               [Control] │  │
│ │  🎵  Sonos Speaker                        Playing          [Control] │  │
│ │  📺  Apple TV                             Idle             [View]    │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘


================================================================================
                     VIEW 4: SENSOR DETAIL WITH HISTORY
================================================================================

┌────────────────────────────────────────────────────────────────────────────┐
│ 🏠 Waverly > 🚪 Master Bath > 📡 Motion Sensor                 [⭐ Favorite] │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ 🚶 MOTION DETECTED                                                 │   │
│  │                                                                    │   │
│  │    Current Value: false           Last Updated: 2 minutes ago     │   │
│  │    Status: ✅ Active               Supports Events: Yes            │   │
│  │                                                                    │   │
│  │  Service: Motion Sensor                                           │   │
│  │  UUID: cc48a456-c45d-584d-0dc4-10a62b729e64                      │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ 📊 ACTIVITY CHART (Last 24 Hours)          [24h|7d|30d|Custom]    │   │
│  ├────────────────────────────────────────────────────────────────────┤   │
│  │                                                                    │   │
│  │  Motion ▲                                                          │   │
│  │  Events │     ╭╮    ╭╮  ╭╮        ╭╮    ╭╮                       │   │
│  │         │   ╭╮││╮ ╭╮│╰╮╭╯│╮     ╭╮││  ╭╮││                       │   │
│  │         │ ╭╮││││││╭╯│││││ ││   ╭╮│││╰╮ │││││                      │   │
│  │      0  ╰─┴┴┴┴┴┴┴┴┴┴─┴┴┴┴┴─┴┴───┴┴┴┴┴─┴─┴┴┴┴┴─────────────────    │   │
│  │         0   4   8   12  16  20  0   4   8   12  16  20  Hours    │   │
│  │                                                                    │   │
│  │  Detected: 47 times  │  Avg Duration: 2.3 min  │  Peak: 8am-9am  │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ 📋 RECENT EVENTS                                    [Export CSV]   │   │
│  ├────────────────────────────────────────────────────────────────────┤   │
│  │  Timestamp              │ Value  │ Changed │ Source               │   │
│  ├─────────────────────────┼────────┼─────────┼──────────────────────┤   │
│  │  2026-01-26 18:52:16   │  true  │   Yes   │  Webhook             │   │
│  │  2026-01-26 18:48:03   │  false │   Yes   │  Webhook             │   │
│  │  2026-01-26 18:47:45   │  true  │   Yes   │  Webhook             │   │
│  │  2026-01-26 18:43:22   │  false │   Yes   │  Webhook             │   │
│  │  2026-01-26 18:43:01   │  true  │   Yes   │  Webhook             │   │
│  │  2026-01-26 18:38:55   │  false │   Yes   │  Webhook (Heartbeat) │   │
│  │  2026-01-26 18:23:55   │  false │   No    │  Webhook (Skipped)   │   │
│  │                                                                    │   │
│  │  [Load More] [Filter Events]                       Showing 1-7    │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘


================================================================================
                     VIEW 5: ALL SENSORS DASHBOARD
================================================================================

┌────────────────────────────────────────────────────────────────────────────┐
│ 📡 Sensors Dashboard                                   [+ Add Alert Rules]  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Filters: [Type: All ▼] [Status: All ▼] [Room: All ▼] [🔍 Search...]     │
│                                                                            │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │ 🚨 ALERTS (3)                                                        │  │
│ ├──────────────────────────────────────────────────────────────────────┤  │
│ │  🔴  Window Sensor (Master Bedroom) - Battery: 12% (Critical)       │  │
│ │  🔴  Shop Door - Battery: 8% (Critical)                             │  │
│ │  ⚠️   Garage Door - Offline for 2 hours                             │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │ 🌡️  TEMPERATURE SENSORS (12)                        Avg: 69°F       │  │
│ ├──────────────────────────────────────────────────────────────────────┤  │
│ │  Master Thermostat       68°F  ✅ 2m   ████████████░░ 68°F          │  │
│ │  Living Room             72°F  ✅ 3m   ██████████████ 72°F          │  │
│ │  Utility Room            65°F  ✅ 1m   ██████████░░░░ 65°F          │  │
│ │  Kitchen                 70°F  ✅ 5m   █████████████░ 70°F          │  │
│ │  ... (8 more)                                       [Show All →]    │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │ 🚶 MOTION SENSORS (29)                              Active: 3       │  │
│ ├──────────────────────────────────────────────────────────────────────┤  │
│ │  Kitchen Motion           🟢 Active    ✅ 30s    [View Activity]    │  │
│ │  Living Room Motion       🟢 Active    ✅ 45s    [View Activity]    │  │
│ │  Garage Motion            🟢 Active    ✅ 1m     [View Activity]    │  │
│ │  Master Bath              ⚫ Clear     ✅ 2m     [View Activity]    │  │
│ │  ... (25 more)                                      [Show All →]    │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │ 🔋 BATTERY LEVELS (33)                              Low: 4          │  │
│ ├──────────────────────────────────────────────────────────────────────┤  │
│ │  Window Sensor            12%  🔴 15m  ▓░░░░░░░░░  [Replace]       │  │
│ │  Shop Door                 8%  🔴 10m  ▓░░░░░░░░░  [Replace]       │  │
│ │  Front Door               25%  ⚠️  5m   ▓▓░░░░░░░░  [Monitor]       │  │
│ │  Bedside Lamp             85%  ✅ 3m   ▓▓▓▓▓▓▓▓░░  [OK]            │  │
│ │  ... (29 more)                                      [Show All →]    │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘


================================================================================
                        VIEW 6: EVENT LOG VIEWER
================================================================================

┌────────────────────────────────────────────────────────────────────────────┐
│ 📋 HomeKit Event Log                                [Export] [🔄 Live Mode] │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Filters:                                                                  │
│  Time: [Last Hour ▼] [Custom Range...]                                   │
│  Type: [☑ Sensors] [☑ Control] [☐ System] [☐ Webhook]                    │
│  Room: [All Rooms ▼]  Accessory: [All ▼]  [🔍 Search...]                 │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ 📊 EVENT STATISTICS (Last Hour)                                    │   │
│  │  Total: 3,144  │  Sensor: 723 (23%)  │  Control: 2,421 (77%)     │   │
│  │  Matched: 94.6%  │  Deduped: 1,887 (60%)  │  Rate: 52/min         │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ Timestamp          │Room        │Accessory      │Char      │Value  │   │
│  ├────────────────────┼────────────┼───────────────┼──────────┼───────┤   │
│  │ 18:52:16  🔴 NEW  │Master Bath │Motion Sensor  │Motion    │ true  │   │
│  │ 18:52:15          │Kitchen     │Counter Light  │Power     │ on    │   │
│  │ 18:52:14          │Living Rm   │Thermostat     │Temp      │ 72°   │   │
│  │ 18:52:13          │Garage      │Door Sensor    │Contact   │closed │   │
│  │ 18:52:11 ⏭️       │Kitchen     │Counter Light  │Power     │ on    │   │
│  │ 18:52:09          │Master Bed  │Lamp           │Bright    │ 75%   │   │
│  │ 18:52:08          │Courtyard   │Motion         │Motion    │false  │   │
│  │ 18:52:05 ⏭️       │Living Rm   │Thermostat     │Temp      │ 72°   │   │
│  │ 18:52:03          │Shop        │Door           │Battery   │ 8%    │   │
│  │ 18:52:01          │Utility     │Motion         │Motion    │false  │   │
│  │                                                                    │   │
│  │  ⏭️ = Deduped (skipped storage)                                    │   │
│  │  [Load More] [Pause Live Updates]               Showing 1-10/723  │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  [Click any event to view raw JSON payload]                               │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘


================================================================================
                     RIGHT SIDEBAR: SENSOR DETAIL PANEL
================================================================================

┌──────────────────────────┐
│ 📡 SENSOR DETAILS        │
├──────────────────────────┤
│                          │
│  🚶 Motion Detected      │
│                          │
│  Current Value:          │
│  ┌──────────────────┐    │
│  │   false          │    │
│  └──────────────────┘    │
│                          │
│  Accessory:              │
│  Master Bath Sensor      │
│                          │
│  Room:                   │
│  Master Bathroom         │
│                          │
│  Last Updated:           │
│  2 minutes ago           │
│  (2026-01-26 18:52:16)  │
│                          │
│  Status: ✅ Active       │
│                          │
│ ┌────────────────────┐   │
│ │ 📊 Quick Stats     │   │
│ ├────────────────────┤   │
│ │ Events Today: 247  │   │
│ │ Changes: 124       │   │
│ │ Deduped: 123       │   │
│ │ Avg Value: N/A     │   │
│ └────────────────────┘   │
│                          │
│ ┌────────────────────┐   │
│ │ 🔧 Actions         │   │
│ ├────────────────────┤   │
│ │ [View Full Detail] │   │
│ │ [View Events]      │   │
│ │ [Export Data]      │   │
│ │ [Add Alert Rule]   │   │
│ │ [⭐ Favorite]      │   │
│ └────────────────────┘   │
│                          │
│ ┌────────────────────┐   │
│ │ ℹ️ Metadata        │   │
│ ├────────────────────┤   │
│ │ UUID: cc48a456...  │   │
│ │ Service: Motion    │   │
│ │ Writable: No       │   │
│ │ Events: Yes        │   │
│ └────────────────────┘   │
│                          │
└──────────────────────────┘
```


Now let me create the component structure, style guide, and navigation tree:Created comprehensive UI design documentation with wireframes, component architecture, style guide, and navigation tree. The design features:

**Key Features:**
- Three-column layout (navigation, content, details)
- Hierarchical navigation (Home → Room → Accessory → Sensor)
- Real-time updates via ActionCable
- Comprehensive sensor dashboard with alerts
- Event log with deduplication indicators
- Mobile-responsive design

**Component Architecture:**
- 18 modular ViewComponents
- Controllers for each resource (Homes, Rooms, Accessories, Sensors, Events)
- Shared components (StatusBadge, BreadcrumbTrail, StatCard, etc.)

**Style Guide:**
- iOS-inspired color palette
- 4px spacing system
- System font stack
- Responsive breakpoints
- Status colors and sensor type icons

**Navigation:**
- Dashboard → Homes → Rooms → Accessories → Sensors
- Direct sensor dashboard with filtering
- Live event log
- Alert management

All documented in `/docs/UI_DESIGN.md`