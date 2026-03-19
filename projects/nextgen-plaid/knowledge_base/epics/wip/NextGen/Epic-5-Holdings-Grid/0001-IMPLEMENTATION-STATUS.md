# Epic 5: Implementation Status

**Epic**: Epic 5 — Holdings Grid  
**Status**: In Progress  
**Last Updated**: 2026-02-09

---

## Overview

Track completion status, blockers, key decisions, and branch merges for Epic 5 PRDs.

Update this document after each PRD completion per `.junie/guidelines.md`.

---

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Completion Date | Notes |
|-----|-------|--------|--------|--------|-----------------|-------|
| 5-01 | Saved Account Filters | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Includes CRUD UI + holdings selector integration + DataProvider criteria filtering |
| 5-02 | Data Provider Service | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Added `HoldingsGridDataProvider` with live + snapshot modes, grouping, totals caching, and invalidation |
| 5-03 | Core Table + Pagination | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Added `/portfolio/holdings` route/controller/view + pagination/per-page selector + large-All warning |
| 5-04 | Filters + Tabs Integration | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Added saved account filter + asset-class tabs (mapped to multi-asset filters), URL-state preservation, and page reset |
| 5-05 | Search/Sort + Enrichment | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Added global search (incl. sector), full sortable headers (incl. computed price/GL%/%portfolio), and enrichment freshness badge |
| 5-06 | Multi-Account Expansion | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Added expandable multi-account parent rows with per-account child breakdown and aggregated G/L% tooltip |
| 5-07 | Security Detail Page | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Added `/portfolio/securities/:security_id` with enrichment + holdings aggregation + transactions grid w/ totals + pagination |
| 5-08 | Holdings Snapshots Model | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-04 | Added `HoldingsSnapshot` model/table to support PRD 5-02 snapshot mode |
| 5-09 | Snapshot Creation Service | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-05 | Added snapshot creation service + SolidQueue job + recurring schedule + tests |
| 5-10 | Snapshot Comparison Service | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-05 | Added `HoldingsSnapshotComparator` service for snapshot-vs-snapshot and snapshot-vs-live comparisons + tests |
| 5-11 | Snapshot Selector UI | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-05 | Added snapshot selector dropdown + historical indicator + invalid snapshot redirect + basic snapshots index page |
| 5-12 | Comparison Mode UI | Implemented (Awaiting Review) | `epic-5-holding-grid` | No | 2026-02-06 | Added `compare_to` URL-state, compare dropdown, diff columns, and row/cell highlighting |
| 5-13 | Snapshot Management UI | Not Started | - | - | - | |
| 5-14 | Holdings Export CSV | Not Started | - | - | - | |
| 5-15 | Mobile Responsive | Not Started | - | - | - | |

---

## PRD 5-01: Saved Account Filters

**Status**: Implemented (Awaiting Review)  
**Branch**: `epic-5-holding-grid`  
**Dependencies**: None

### Scope

- Add `SavedAccountFilter` model and persistence with per-user scoping.
- Provide CRUD UI to create/edit/delete saved filters.
- Provide a reusable selector component and integrate it into Net Worth → Holdings.

### Acceptance Criteria

- [x] Users can create, edit, delete saved filters scoped to their user.
- [x] Users can select “All Accounts” or a saved filter on Holdings, and holdings data is scoped accordingly.
- [x] Selection persists across expand/collapse, sort, retry (Turbo-frame interactions).
- [x] Basic tests exist for model validations, controller scoping, and selector rendering.

### Blockers

- None.

### Key Decisions

- Use flexible `criteria` JSONB with minimal validation (must include at least one supported key).
- Apply criteria filtering in `Reporting::DataProvider` to ensure totals/percentages are consistent with the filtered holdings set.

### Completion Date

2026-02-04

### Notes

- Implemented `Reporting::DataProvider#with_account_filter(criteria)` supporting `account_ids`, `institution_ids`, `ownership_types`, `asset_strategy`, `trust_code`, `holder_category`.
- Added `SavedAccountFilterSelectorComponent` and integrated into `NetWorth::HoldingsSummaryComponent`.
- Added `knowledge_base/data-dictionary.md` documenting criteria schema.
- No commit performed yet (awaiting review).

---

## Change Log

| Date | Change | Notes |
|------|--------|-------|
| 2026-02-04 | PRD 5-01 implemented on branch `epic-5-holding-grid` | Awaiting review/commit instruction |
| 2026-02-04 | PRD 5-02 implemented on branch `epic-5-holding-grid` | Added `HoldingsGridDataProvider`, caching + invalidation, and snapshot support |
| 2026-02-04 | PRD 5-08 implemented on branch `epic-5-holding-grid` | Added `holdings_snapshots` table + `HoldingsSnapshot` model |
| 2026-02-04 | PRD 5-03 implemented on branch `epic-5-holding-grid` | Implemented `/portfolio/holdings` grid with pagination, per-page selector, and large-All warning toast |
| 2026-02-04 | PRD 5-04 implemented on branch `epic-5-holding-grid` | Added asset-class tabs + multi-asset filtering; verified composition with saved account filters and page reset |
| 2026-02-04 | PRD 5-05 implemented on branch `epic-5-holding-grid` | Added search, sortable columns, enrichment freshness UI, and supporting provider/index changes |
| 2026-02-04 | PRD 5-06 implemented on branch `epic-5-holding-grid` | Added expandable grouped holdings rows with per-account sub-table and aggregated tooltip messaging |
| 2026-02-04 | PRD 5-07 implemented on branch `epic-5-holding-grid` | Implemented security detail page + navigation link from holdings grid; added provider and tests |
| 2026-02-05 | PRD 5-09 implemented on branch `epic-5-holding-grid` | Added `CreateHoldingsSnapshotService`, `CreateHoldingsSnapshotsJob`, minimal `AdminNotificationJob`, recurring schedule entry, and tests |
| 2026-02-05 | PRD 5-10 implemented on branch `epic-5-holding-grid` | Added `HoldingsSnapshotComparator` service (snapshot-vs-snapshot and snapshot-vs-live) and Minitest coverage |
| 2026-02-06 | PRD 5-12 implemented on branch `epic-5-holding-grid` | Added comparison-mode UI (`compare_to`), merged start/end rows, diff columns, and visual highlighting; ensured filters apply to both sides |
| 2026-02-09 | Holdings grid enrichment indicator compacted | Replaced `Enrichment Updated` text with a colored dot + tooltip showing timestamp; reduced column width |
