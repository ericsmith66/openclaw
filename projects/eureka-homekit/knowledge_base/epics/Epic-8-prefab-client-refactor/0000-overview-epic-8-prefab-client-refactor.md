<!--
  Epic Overview Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/<0000-overview-...>.md

  This template is based on the structure used in:
    knowledge_base/epics/wip/NextGen/Epic-4/0000-overview-epic-4.md
-->

**Epic 8: Prefab Client Refactor & Performance Optimization**

**Epic Overview**
This epic refactors the PrefabClient service to leverage new bulk accessory endpoints introduced by Prefab, significantly improving performance for sync operations and enabling efficient filtering capabilities. The new endpoints (`GET /accessories/:home` with query filters and `GET /accessories/:home/summary`) return accessory metadata from HomeKit's cached object graph with no device network calls, making them orders of magnitude faster (~30ms) than per‑room accessory fetching (2+ minutes for 400+ accessories). This optimization reduces sync time, enables real‑time filtering in the UI, and provides a foundation for dashboards and analytics.

**User Capabilities**
- Filter accessories by reachability (online/offline), room, category, manufacturer via query parameters
- View accessory summary dashboard with counts by category, room, manufacturer, and unreachable breakdown
- Experience faster sync operations (seconds instead of minutes)
- Browse all accessories across the home in a single, filterable view (optional UI)

**Fit into Big Picture**
This epic sits between Epic 1 (Prefab Integration) and Epic 5 (Interactive Controls), enhancing the performance and query capabilities of the foundational Prefab client. It enables future epics (Analytics, AI Agent) to efficiently query accessory metadata without N+1 HTTP calls. The improvements are transparent to existing features—syncs become faster, and new filtering endpoints can be used by UI components as needed.

**Reference Documents**
- `knowledge_base/epics/Epic-5-Interactive-Controls/prefab-bulk-endpoints.md` – detailed endpoint documentation
- `knowledge_base/epics/Epic-1-bootstrap/epic-1-prd-2-prefab-http-client.md` – original PrefabClient design
- `app/services/prefab_client.rb` – current implementation
- `app/services/homekit_sync.rb` – sync service that will be optimized

---

### Key Decisions Locked In

**Architecture / Boundaries**
- New methods added to existing `PrefabClient` class: `all_accessories(home, filters={})` and `accessories_summary(home)`
- `fetch_json` method extended to accept optional query parameters (backward‑compatible)
- `HomekitSync` will switch from per‑room to bulk accessory fetching, filtering locally by room
- No changes to database models or existing controller actions (backward‑compatible)
- **Explicitly out of scope**: Changing the existing `accessories(home, room)` method signature; UI changes beyond optional new endpoint

**UX / UI**
- No mandatory UI changes; existing pages continue to work unchanged
- Optional new `/accessories` index page can be added as a separate PRD
- Summary dashboard data can be surfaced in existing dashboards (e.g., unreachable count)

**Testing**
- Extend `spec/services/prefab_client_spec.rb` to cover new bulk endpoints
- Update `spec/services/homekit_sync_spec.rb` to verify bulk sync behavior
- Maintain existing test coverage; new tests must not break existing functionality

**Observability**
- Existing Rails.logger instrumentation in `PrefabClient` will include new method calls
- Latency metrics for bulk endpoints should be logged (already captured via `execute_curl`)

---

### High-Level Scope & Non-Goals

**In scope**
1. Extend `PrefabClient` with `all_accessories` and `accessories_summary` methods
2. Update `fetch_json` to support query parameters
3. Modify `HomekitSync` to use bulk endpoints, preserving existing cleanup logic
4. Add comprehensive unit and integration tests for new functionality
5. (Optional) Create `AccessoriesController#index` endpoint with filtering
6. (Optional) Add UI page for filtered accessory browsing
7. (Optional) Integrate `reachable` status into data model and create offline accessories page

**Non-goals / deferred**
- Changing the existing `accessories(home, room)` method signature or behavior
- Adding real‑time updates to the bulk endpoints (they remain cached snapshots)
- Building a full‑fledged analytics dashboard (Epic 8 in roadmap)
- Modifying any other controllers or UI components beyond optional additions

---

### PRD Summary Table

List each PRD as an “atomic” chunk that can be implemented and validated independently.

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 8‑01 | Extend PrefabClient with Bulk Accessory Endpoints | Add `all_accessories` and `accessories_summary` methods; update `fetch_json` to support query parameters | None | `epic-8/prefab-client-bulk-endpoints` | Core infrastructure change |
| 8‑02 | Optimize HomekitSync with Bulk Fetching | Replace per‑room accessory fetching with bulk call; filter locally by room | PRD‑8‑01 | `epic-8/homekit-sync-bulk` | Performance improvement |
| 8‑03 | Accessories Index Endpoint with Filtering (Optional) | Create `AccessoriesController#index` endpoint that uses bulk endpoints; add routes and basic UI | PRD‑8‑01 | `epic-8/accessories-index` | Optional UI enhancement |
| 8‑04 | Dashboard Integration of Summary Data (Optional) | Surface summary stats (unreachable count, category breakdown) in existing dashboard | PRD‑8‑01 | `epic-8/dashboard-summary` | Optional UI enhancement |
| 8‑05 | Offline Accessories Page & Reachable Status Integration | Store `reachable` flag from bulk endpoint; create offline accessories page with troubleshooting; integrate into navigation | PRD‑8‑01, PRD‑8‑02 | `epic-8/offline-accessories` | Enhances home health monitoring |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**: All changes must be backward‑compatible; existing `PrefabClient.accessories(home, room)` must continue to work unchanged.
- **Components**: New UI components (if any) should follow existing ViewComponent patterns; reuse existing layout and styling.
- **Data Access**: Use `ERB::Util.url_encode` for query parameters; handle empty filter sets gracefully.
- **Error Handling**: Preserve existing error‑handling and logging patterns in `PrefabClient`; return empty arrays/`nil` on failure.
- **Empty States**: If adding UI, provide appropriate empty states for no accessories, no filters matched, etc.
- **Accessibility**: Follow existing WCAG 2.1 AA patterns (semantic HTML, ARIA labels where needed).
- **Mobile**: Ensure any new UI works on mobile viewports (existing Tailwind responsive classes).
- **Security**: No new authentication requirements; rely on existing session‑based auth.

Replace the angle‑bracket placeholders with real content (use `{{...}}` placeholders in this template to avoid Markdown/HTML parsing issues).

---

### Implementation Status Tracking

- Create `0001-IMPLEMENTATION-STATUS.md` in the epic directory before starting PRD work.
- Update it after each PRD completion.

---

### Success Metrics

- Sync time for 400+ accessories reduced from 2+ minutes to <10 seconds
- Bulk endpoint response times consistently <50ms (measured via `PrefabClient` logging)
- Zero regressions in existing sync, control, or UI functionality
- New filtering endpoints return correct filtered subsets (verified with unit tests)

---

### Estimated Timeline (optional)

- PRD 8‑01: 1–2 days
- PRD 8‑02: 1 day
- PRD 8‑03: 1–2 days (optional)
- PRD 8‑04: 1 day (optional)

---

### Next Steps

1. Create `0001-IMPLEMENTATION-STATUS.md` in this directory
2. Proceed with PRD 8‑01 (PrefabClient extension)
3. Implement PRD 8‑02 (HomekitSync optimization)
4. Evaluate need for optional PRDs based on product priorities

---

### Detailed PRDs

Full PRD specifications live in separate files, e.g.:
- `PRD-8-01-prefab-client-bulk-endpoints.md`
- `PRD-8-02-homekit-sync-bulk-fetching.md`
- `PRD-8-03-accessories-index-filtering.md`
- `PRD-8-04-dashboard-summary-integration.md`