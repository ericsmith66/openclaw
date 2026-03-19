# Epic 2: Implementation Status

**Epic**: Web UI Dashboard for HomeKit Monitoring
**Status**: Not Started
**Last Updated**: 2026-02-04

---

## Overview

Track completion status, blockers, key decisions, and branch merges for Epic 2 PRDs.

Update this document after each PRD completion per `.junie/guidelines.md`.

---

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Completion Date | Notes |
|-----|-------|--------|--------|--------|-----------------|-------|
| 2-01 | Core Layout & ViewComponents Infrastructure | Not Started | `epic-2/layout` | No | - | |
| 2-02 | Homes & Rooms Views | Not Started | `epic-2/homes-rooms` | No | - | |
| 2-03 | Sensors Dashboard & Detail Views | Not Started | `epic-2/sensors` | No | - | |
| 2-04 | Event Log Viewer with Real-Time Updates | Not Started | `epic-2/event-log` | No | - | |
| 2-05 | Styling & Design System | Not Started | `epic-2/styling` | No | - | |
| 2-06 | Event Viewer Sidebar Improvement | Completed | `feature/prd-sidebar-recent-events-improvement` | No | 2026-02-05 | |
| 2-07 | Intelligent Event Deduplication & Room Activity Heatmap | Not Started | `feature/prd-liveness-and-heatmap` | No | - | |
| - | Left Sidebar Room Sorting | Completed | - | No | 2026-02-06 | Alphabetical sorting (case-insensitive) |

---

## PRD 2-01: Core Layout & ViewComponents Infrastructure

**Status**: Not Started
**Branch**: `epic-2/layout`
**Dependencies**: None

### Scope

- Create `AppLayout` component (three-column responsive).
- Create `HeaderComponent` with navigation.
- Create `LeftSidebarComponent` and `RightSidebarComponent`.
- Create shared components: `Breadcrumb`, `StatusBadge`, `StatCard`, `SearchBar`.

### Acceptance Criteria

- [ ] Application layout renders with all three columns.
- [ ] Header navigation works with active state highlighting.
- [ ] Sidebars collapse on mobile.
- [ ] Shared components reusable across views.

### Blockers

- None

### Key Decisions

- Use ViewComponent for all layout elements.

### Completion Date

-

### Notes

-

---

## PRD 2-02: Homes & Rooms Views

**Status**: Not Started
**Branch**: `epic-2/homes-rooms`
**Dependencies**: 2-01

### Scope

- Homes index and show views.
- Rooms grid and detail views.
- `HomeCardComponent`, `RoomCardComponent`, `RoomDetailComponent`.

### Acceptance Criteria

- [ ] Homes index shows all homes with accurate stats.
- [ ] Rooms grid displays with live sensor values.
- [ ] Room detail separates sensors from controllable accessories.

### Blockers

- None

### Key Decisions

-

### Completion Date

-

### Notes

-

---

## PRD 2-03: Sensors Dashboard & Detail Views

**Status**: Not Started
**Branch**: `epic-2/sensors`
**Dependencies**: 2-01, 2-02

### Scope

- Sensors dashboard with alerts and grouping by type.
- Sensor detail view with historical activity chart.
- `SensorCardComponent`, `SensorDetailComponent`, `ActivityChartComponent`.
- `BatteryIndicatorComponent`, `AlertBannerComponent`.

### Acceptance Criteria

- [ ] Dashboard shows all sensors grouped by type.
- [ ] Alert section highlights critical issues.
- [ ] Sensor detail displays current value and history chart.

### Blockers

- None

### Key Decisions

-

### Completion Date

-

### Notes

-

---

## PRD 2-04: Event Log Viewer with Real-Time Updates

**Status**: Not Started
**Branch**: `epic-2/event-log`
**Dependencies**: 2-01

### Scope

- Live event log index with filters and statistics bar.
- ActionCable integration for real-time updates.
- `EventRowComponent`, `EventStatisticsComponent`, `EventFilterComponent`.

### Acceptance Criteria

- [ ] Event log displays all events with proper formatting.
- [ ] Live updates via ActionCable working.
- [ ] Statistics update automatically.

### Blockers

- None

### Key Decisions

-

### Completion Date

-

### Notes

-

---

## PRD 2-05: Styling & Design System

**Status**: Not Started
**Branch**: `epic-2/styling`
**Dependencies**: 2-01

### Scope

- Tailwind CSS configuration.
- iOS-inspired design system implementation.
- Consistent typography, spacing, and component styling.

### Acceptance Criteria

- [ ] Consistent color palette applied throughout.
- [ ] Typography system implemented.
- [ ] All components use design system tokens.

### Blockers

- None

### Key Decisions

-

### Completion Date

-

### Notes

-

---

## PRD 2-06: Event Viewer Sidebar Improvement

**Status**: Completed
**Branch**: `feature/prd-sidebar-recent-events-improvement`
**Dependencies**: 2-01, 2-04

### Scope

- Create `RightSidebarComponent` and `RecentEventsItemComponent`.
- Implement `EventFormattingHelper`.
- Implement `EventDetailModalComponent`.
- Add `recent_events_grouped` scope to `Event` model.
- Implement live updates with client-side merging.

### Acceptance Criteria

- [ ] Sidebar shows scannable summaries with icons and bold values.
- [ ] Rapid identical events are grouped (backend + frontend).
- [ ] Sidebar respects global Live Mode.
- [ ] Clicking item opens detail modal.
- [ ] "Show in table" triggers smooth scroll.
- [ ] Empty state with helpful tip.

### Blockers

- None

### Key Decisions

- Hybrid deduplication (Backend for load, Frontend for live).
- Shared helper for formatting.

### Completion Date

-

### Notes

-

---

---

## PRD 2-07: Intelligent Event Deduplication & Room Activity Heatmap

**Status**: Not Started
**Branch**: `feature/prd-liveness-and-heatmap`
**Dependencies**: 2-01, 2-04

### Scope

- Implement `last_seen_at` on Sensor, Accessory, and Room.
- Update `Api::HomekitEventsController` to use "Value Change Only" storage.
- Implement Room Activity Heatmap logic (Green -> White decay).
- Create `SensorValueDefinitions` table for auto-discovery of sensor states.

### Acceptance Criteria

- [ ] `HomekitEvent` table contains zero consecutive duplicates.
- [ ] Room UI displays dynamic color coding based on activity age.
- [ ] Sensors display "Last Seen" time independent of value changes.

### Blockers

- None

### Key Decisions

- Use `touch` for high-frequency liveness updates.
- Auto-discovery of sensor values instead of manual configuration.

### Completion Date

-

### Notes

-

---

## Change Log

| Date | Change | Notes |
|------|--------|-------|
| 2026-02-04 | Initial setup | Created from Epic 2 overview and PRDs. |
