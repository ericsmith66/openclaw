**Epic 2: Web UI Dashboard for HomeKit Monitoring**

**Epic Overview**
The goal of this epic is to build a responsive web interface for navigating HomeKit homes, rooms, accessories, and sensors. It will provide a user-friendly way to monitor real-time sensor data, view historical events, and track the health of various devices synced from the Prefab system.

Currently, the data is only accessible via the Rails console or manual database queries. This epic will bridge that gap by providing a rich, real-time UI that allows users to see what's happening in their HomeKit environment at a glance.

**User Capabilities**
- Navigate through homes and rooms to see hierarchical device organization.
- Monitor live sensor data (temperature, motion, humidity, etc.) with real-time updates.
- View a comprehensive event log with filtering and search capabilities.
- Check sensor health, battery levels, and connectivity status.
- Analyze historical sensor data through activity charts.

**Fit into Big Picture**
This epic follows Epic 1, which established the Rails server, database models, and Prefab integration. While Epic 1 focused on data ingestion and storage, Epic 2 focuses on data visualization and user interaction, making the system truly usable for end-users.

**Reference Documents**
- `knowledge_base/epics/Epic-2-UI/epic-2-web-ui-dashboard.md` (Source)
- `knowledge_base/templates/PRD-template.md`
- `.junie/guideline.md`

---

### Key Decisions Locked In

**Architecture / Boundaries**
- Use **ViewComponent** for all UI components to ensure reusability and testability.
- Use **Stimulus** for client-side interactions and **Turbo** for partial page updates.
- Use **ActionCable** for real-time event broadcasting.
- **Out of Scope**: Controlling accessories (write operations) is deferred to future epics.

**UX / UI**
- Three-column responsive layout (Header, Left Sidebar, Main Content, Right Sidebar).
- iOS-inspired aesthetics for a familiar feel.
- Mobile-first approach with collapsible sidebars.

**Testing**
- Minitest for unit, integration, and system tests.
- High focus on ViewComponent unit tests.

**Observability**
- Use standard Rails logging for now.

---

### High-Level Scope & Non-Goals

**In scope**
- Core Layout & ViewComponents Infrastructure
- Homes & Rooms Views
- Sensors Dashboard & Detail Views
- Event Log Viewer with Real-Time Updates
- Styling & Design System

**Non-goals / deferred**
- Dark Mode (future enhancement)
- Scene Management
- Automation Builder
- Native Mobile Apps

---

### PRD Summary Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 2-01 | Core Layout & ViewComponents Infrastructure | Layout, Header, Sidebars, Shared Components | None | `epic-2/layout` | Foundation for all views |
| 2-02 | Homes & Rooms Views | Homes index/show, Rooms grid/detail | 2-01 | `epic-2/homes-rooms` | |
| 2-03 | Sensors Dashboard & Detail Views | Sensors index, detail views, Charts, Battery indicators | 2-01, 2-02 | `epic-2/sensors` | |
| 2-04 | Event Log Viewer with Real-Time Updates | Event log, ActionCable integration, Real-time stats | 2-01 | `epic-2/event-log` | |
| 2-05 | Styling & Design System | Tailwind config, consistent styling, iOS aesthetics | 2-01 | `epic-2/styling` | |
| 2-06 | Event Viewer Sidebar Improvement | Rich event summaries, deduplication, live updates | 2-01, 2-04 | `feature/prd-sidebar-recent-events-improvement` | |
| 2-07 | Intelligent Event Deduplication & Room Activity Heatmap | Liveness tracking, heatmaps, state discovery | 2-01, 2-04 | `feature/prd-liveness-and-heatmap` | |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**: Follow the ViewComponent pattern strictly. Avoid fat views.
- **Components**: Components live in `app/components/`. Shared components in `app/components/shared/`.
- **Data Access**: Use `includes()` to avoid N+1 queries. Cache expensive counts.
- **Error Handling**: Provide empty-state UI instead of crashing. Tolerate missing JSON keys.
- **Empty States**: Required for all list views and detail panels when no data is present.
- **Accessibility**: Aim for WCAG AA. Use semantic HTML and ARIA labels.
- **Mobile**: Single column < 768px. Touch targets at least 44x44px.

---

### Implementation Status Tracking

- Create `0001-IMPLEMENTATION-STATUS.md` in the epic directory before starting PRD work.
- Update it after each PRD completion.

---

### Success Metrics

- Dashboard loads in < 500ms for 250+ sensors.
- Real-time updates delivered with < 1s latency.
- Test coverage > 80% for components.

---

### Estimated Timeline

- PRD 2-01: 3-4 days
- PRD 2-02: 2-3 days
- PRD 2-03: 4-5 days
- PRD 2-04: 3-4 days
- PRD 2-05: 2-3 days
- Total: 16-22 days

---

### Next Steps

1. Create `0001-IMPLEMENTATION-STATUS.md`
2. Proceed with PRD 2-01: Core Layout & ViewComponents Infrastructure

---

### Detailed PRDs

- `PRD-2-01-core-layout-components.md`
- `PRD-2-02-homes-rooms-views.md`
- `PRD-2-03-sensors-dashboard-detail.md`
- `PRD-2-04-event-log-real-time.md`
- `PRD-2-05-styling-design-system.md`
- `PRD-2-06-event-viewer-sidebar.md`
- `PRD-2-07-liveness-and-heatmap.md`
