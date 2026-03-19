<!--
  Implementation Status Template

  Copy this file into your epic directory and rename exactly:
    knowledge_base/epics/wip/<Program>/<Epic-N>/0001-IMPLEMENTATION-STATUS.md

  This template is based on:
    knowledge_base/epics/wip/NextGen/Epic-4/0001-IMPLEMENTATION-STATUS.md
-->

# Epic 8: Implementation Status

**Epic**: Prefab Client Refactor & Performance Optimization
**Status**: Not Started
**Last Updated**: 2026-02-22

---

## Overview

Track completion status, blockers, key decisions, and branch merges for Epic 8 PRDs.

Update this document after each PRD completion per `.junie/guidelines.md`.

---

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Completion Date | Notes |
|-----|-------|--------|--------|--------|-----------------|-------|
| 8‑01 | Extend PrefabClient with Bulk Accessory Endpoints | Not Started | `epic-8/prefab-client-bulk-endpoints` | No | — | — |
| 8‑02 | Optimize HomekitSync with Bulk Fetching | Not Started | `epic-8/homekit-sync-bulk` | No | — | Depends on 8‑01 |
| 8‑03 | Accessories Index Endpoint with Filtering (Optional) | Not Started | `epic-8/accessories-index` | No | — | Depends on 8‑01 |
| 8‑04 | Dashboard Integration of Summary Data (Optional) | Not Started | `epic-8/dashboard-summary` | No | — | Depends on 8‑01 |
| 8‑05 | Offline Accessories Page & Reachable Status Integration | Not Started | `epic-8/offline-accessories` | No | — | Depends on 8‑01, 8‑02 |

---

## PRD 8‑01: Extend PrefabClient with Bulk Accessory Endpoints

**Status**: Not Started
**Branch**: `epic-8/prefab-client-bulk-endpoints`
**Dependencies**: None

### Scope

- Add `PrefabClient.all_accessories(home, filters = {})` method that calls `GET /accessories/:home` with optional query filters (`reachable`, `room`, `category`, `manufacturer`)
- Add `PrefabClient.accessories_summary(home)` method that calls `GET /accessories/:home/summary`
- Update private `fetch_json` method to accept optional query parameters (backward‑compatible)
- Ensure proper URL encoding of filter values with `ERB::Util.url_encode`
- Preserve existing error‑handling and logging patterns

### Acceptance Criteria

- [ ] `PrefabClient.all_accessories('Waverly')` returns array of all accessories (verified with live Prefab)
- [ ] `PrefabClient.all_accessories('Waverly', reachable: false)` returns only unreachable accessories
- [ ] `PrefabClient.all_accessories('Waverly', room: 'Garage')` returns accessories in Garage
- [ ] `PrefabClient.accessories_summary('Waverly')` returns summary hash with total, reachable, byCategory, etc.
- [ ] Existing `PrefabClient.accessories(home, room)` continues to work unchanged
- [ ] Unit tests cover new methods and query‑parameter handling
- [ ] Integration tests verify live Prefab responses (if possible)

### Blockers

- None

### Key Decisions

- Extend `fetch_json` rather than create separate method to reuse existing timeout/retry logic
- Return empty array `[]` on failure for `all_accessories`, `nil` for `accessories_summary` (consistent with existing pattern)

### Completion Date

—

### Notes

—

---

## PRD 8‑02: Optimize HomekitSync with Bulk Fetching

**Status**: Not Started
**Branch**: `epic-8/homekit-sync-bulk`
**Dependencies**: PRD‑8‑01

### Scope

- Modify `HomekitSync#perform` to fetch all accessories for a home in a single bulk call
- Replace per‑room `PrefabClient.accessories` calls with filtering of the bulk result by room name
- Maintain existing cleanup logic (deleting orphaned accessories)
- Ensure backward compatibility: sync should still work if bulk endpoint fails (fallback to per‑room?)
- Update unit and integration tests to reflect new behavior

### Acceptance Criteria

- [ ] Sync completes successfully using bulk endpoint (verified with live Prefab)
- [ ] Sync time for 400+ accessories is significantly reduced (from minutes to seconds)
- [ ] Orphaned accessory cleanup still works correctly
- [ ] Existing `HomekitSync` specs pass with minimal changes
- [ ] No regressions in sync behavior (all accessories, sensors, scenes created correctly)

### Blockers

- PRD‑8‑01 must be merged

### Key Decisions

- Use bulk endpoint as primary source; if it fails, fall back to per‑room fetching for robustness
- Filter bulk result locally by room name (case‑sensitive match)

### Completion Date

—

### Notes

—

---

## PRD 8‑03: Accessories Index Endpoint with Filtering (Optional)

**Status**: Not Started
**Branch**: `epic-8/accessories-index`
**Dependencies**: PRD‑8‑01

### Scope

- Add `GET /accessories` route (or `/accessories/index`) that accepts query parameters
- Create `AccessoriesController#index` action that uses `PrefabClient.all_accessories` with filters
- Render basic HTML view (or JSON API) showing filtered accessories
- Include filter UI (dropdowns for room, category, manufacturer, reachable toggle)
- Follow existing layout and styling patterns

### Acceptance Criteria

- [ ] `GET /accessories?home=Waverly&reachable=false` returns HTML page with unreachable accessories
- [ ] Filter UI presents available rooms, categories, manufacturers (could be hard‑coded initially)
- [ ] Page works on mobile viewports
- [ ] Empty state shown when no accessories match filters
- [ ] JSON API version available (`Accept: application/json`)

### Blockers

- PRD‑8‑01 must be merged

### Key Decisions

- Home selection: default to first home, allow param `?home=...`
- Filter values can be populated from summary endpoint or hard‑coded list

### Completion Date

—

### Notes

Optional PRD; implement only if product prioritizes accessory‑browsing UI.

---

## PRD 8‑04: Dashboard Integration of Summary Data (Optional)

**Status**: Not Started
**Branch**: `epic-8/dashboard-summary`
**Dependencies**: PRD‑8‑01

### Scope

- Add summary stats to existing dashboard (`DashboardsController#show`)
- Use `PrefabClient.accessories_summary` to display total, reachable, unreachable counts
- Show top categories, rooms with most accessories
- Highlight unreachable accessories by manufacturer/room

### Acceptance Criteria

- [ ] Dashboard shows total accessory count and reachable/unreachable breakdown
- [ ] Unreachable accessories list with room and manufacturer (optional)
- [ ] Stats update on dashboard refresh (no real‑time auto‑update)
- [ ] UI follows existing styling (cards, badges, etc.)

### Blockers

- PRD‑8‑01 must be merged

### Key Decisions

- Cache summary data for 5 minutes to avoid hitting Prefab on every dashboard load
- Display as additional cards in existing dashboard layout

### Completion Date

—

### Notes

Optional PRD; implement if dashboard enrichment is a priority.

---

## PRD 8‑05: Offline Accessories Page & Reachable Status Integration

**Status**: Not Started
**Branch**: `epic-8/offline-accessories`
**Dependencies**: PRD‑8‑01, PRD‑8‑02

### Scope

- Add `reachable` boolean column to `accessories` table
- Update `HomekitSync` to populate `reachable` from bulk endpoint's `isReachable` field
- Add `Accessory#offline?` method and scope
- Update `Sensor#offline?` to consider parent accessory's reachable status
- Create `GET /accessories/offline` page with grouping by room and troubleshooting tips
- Integrate offline count into left sidebar navigation with badge
- Update dashboard and alert banner to include offline accessories

### Acceptance Criteria

- [ ] Migration adds `reachable` column
- [ ] Sync updates `reachable` flag correctly
- [ ] `Accessory.offline` scope works
- [ ] Offline page shows unreachable accessories grouped by room
- [ ] Sidebar includes "Offline" link with badge count
- [ ] Empty state appears when all accessories reachable
- [ ] Control components respect `accessory.offline?`

### Blockers

- PRD‑8‑01 and PRD‑8‑02 must be merged

### Key Decisions

- Offline status derived from Prefab's `isReachable` field (authoritative)
- Troubleshooting tips are static per category
- Cache offline count for 5 minutes

### Completion Date

—

### Notes

Enhances home health monitoring with artful UI integration.

---

## Change Log

| Date | Change | Notes |
|------|--------|-------|
| 2026-02-22 | Created implementation status document | Initial setup for Epic 8 |