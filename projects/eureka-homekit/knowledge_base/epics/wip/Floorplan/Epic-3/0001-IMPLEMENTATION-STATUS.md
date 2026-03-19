# Epic 3: Implementation Status

**Epic**: Interactive Floorplan & Activity Heatmap
**Status**: Completed
**Last Updated**: 2026-02-08

---

## Overview

Track completion status, blockers, key decisions, and branch merges for Epic 3 PRDs.

Update this document after each PRD completion per `.junie/guidelines.md`.

---

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Completion Date | Notes |
|-----|-------|--------|--------|--------|-----------------|-------|
| 3-01 | Floorplan Asset & Mapping Engine | Completed | `main` | Yes | 2026-02-08 | Restored and verified |
| 3-02 | Interactive Floorplan Viewer | Completed | `main` | Yes | 2026-02-08 | Restored and verified |
| 3-03 | Real-time Heatmap & Sensor Injection | Completed | `main` | Yes | 2026-02-08 | Restored and verified |

---

## PRD 3-01: Floorplan Asset & Mapping Engine
**Status**: Completed
**Branch**: `main`
**Dependencies**: None

### Scope

- Extend `Home` model to support `floorplan_assets` (SVGs and `mapping.json`).
- Define the JSON mapping schema (supporting IDs, Group names, and fallback coordinates).
- API endpoint for SVG content + real-time room states.

### Acceptance Criteria

- [x] `Home` model has attached floorplan assets.
- [x] Mapping schema supports linking SVG elements to `room_id`.
- [x] API returns valid SVG content and current sensor states for mapped rooms.

### Blockers

- None

### Key Decisions

- Hand-editing JSON for mapping in the initial phase.

### Completion Date

-

### Notes

-

---

## PRD 3-02: Interactive Floorplan Viewer

**Status**: Completed
**Branch**: `main`
**Dependencies**: 3-01

### Scope

- ViewComponent for rendering SVG with pan/zoom.
- Hover effects for mapped rooms.
- Click action to navigate or open room details modal.
- HTML overlay layer for dynamic room labels.

### Acceptance Criteria

- [x] SVG renders correctly with pan/zoom functionality.
- [x] Mapped rooms highlight on hover.
- [x] Clicking a room triggers a navigation or modal.
- [x] Room labels are correctly positioned over SVG regions via overlay.

### Blockers

- None

### Key Decisions

- Use `svg-pan-zoom` library for navigation.
- Use HTML/CSS overlay for labels to keep SVG clean and simplify positioning.

### Completion Date

- 2026-02-07

### Notes

- Integrated into Dashboard with a view toggle.

---

## PRD 3-03: Real-time Heatmap & Sensor Injection

**Status**: Completed
**Branch**: `main`
**Dependencies**: 3-01, 3-02

### Scope

- Activity scoring logic (Motion/Occupancy -> Heat).
- Visual heatmap overlay (CSS classes for fill colors).
- Glowing pulse effect for active motion.
- Real-time updates via ActionCable.
- Room Stat badges (temp/humidity) on floorplan.

### Acceptance Criteria

- [x] Rooms change color based on sensor activity.
- [x] Glowing pulse appears in rooms with active motion.
- [x] Sensor data (temp/humidity) is visible on the floorplan.
- [x] Updates reflect in real-time without page reload.

### Blockers

- None

### Key Decisions

- Limit glowing pulse to active motion to avoid visual noise.
- Use `FloorplanChannel` specifically for map-related real-time updates.

### Completion Date

- 2026-02-07

---

## Change Log

| Date | Change | Notes |
|------|--------|-------|
| 2026-02-07 | PRD 3-01 Completed | Asset storage and mapping engine implemented |
| 2026-02-07 | PRD 3-02 Completed | Interactive SVG UI implemented |
| 2026-02-07 | PRD 3-03 Completed | Real-time heatmap and sensor injection implemented |
