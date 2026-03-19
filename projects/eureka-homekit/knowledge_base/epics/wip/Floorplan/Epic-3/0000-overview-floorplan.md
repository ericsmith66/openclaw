**Epic 3: Interactive Floorplan & Activity Heatmap**

**Epic Overview**
The goal of this epic is to transform static SVG blueprints into a dynamic, interactive navigation and monitoring dashboard for Eureka. It bridges the gap between static architectural data and real-time HomeKit state by overlaying live sensor data onto a visual floorplan.

Currently, the UI is list-based. This feature will provide a spatial context for the home, allowing users to see exactly where sensors are located and what the current state of each room is (temperature, humidity, motion) at a glance.

**User Capabilities**
- Navigate the home via a multi-level interactive floorplan.
- View real-time room states (temp/humidity/motion) directly on the map.
- Visualize room activity through a heatmap overlay.
- Quickly access room-specific details by clicking on mapped SVG regions.

**Fit into Big Picture**
This epic builds upon the data models and real-time infrastructure established in Epic 1 and the UI foundations from Epic 2. It introduces a visual, spatial layer to the HomeKit monitoring experience, making it more intuitive for users to understand the state of their physical environment.

**Reference Documents**
- `knowledge_base/epics/Epic-3-floorplan-navigation/Epic-3-floorplan` (Source)
- `knowledge_base/epics/Epic-3-floorplan-navigation/Epic-3-floorplan-feedback-V1.md` (Review Feedback)
- `knowledge_base/templates/PRD-template.md`
- `.junie/guideline.md`

---

### Key Decisions Locked In

**Architecture / Boundaries**
- **Asset Storage**: Extend the `Home` model to support SVG assets and mapping files.
- **Mapping Strategy**: Use a JSON mapping file to link SVG element IDs/Group names to `room_id` values.
- **Stable Identifiers**: Prefer SVG Group Names or custom data attributes over fragile auto-generated IDs (e.g., `Graphic_15`).
- **Overlay Layer**: Use an HTML/Canvas overlay for dynamic labels and sensor badges instead of modifying the SVG DOM directly, ensuring the SVG remains clean and performant.

**UX / UI**
- **Navigation**: Preserve existing dashboard navigation but add a floorplan toggle/button.
- **Interaction**: Mapped rooms are hoverable and clickable (Modular view/modal or full page).
- **Visualization**: Heatmap uses glowing pulses for active motion and semi-transparent fills for temperature/state.

**Testing**
- Minitest for unit tests of the mapping engine and integration tests for SVG delivery.
- ViewComponent tests for the Floorplan viewer.

**Observability**
- Log mapping failures or missing SVG elements to `Rails.logger`.

---

### High-Level Scope & Non-Goals

**In scope**
- Infrastructure for SVG asset storage and retrieval.
- JSON mapping engine (linking SVG to Rooms).
- Responsive SVG Viewer with pan/zoom (PRD 3-02).
- Real-time sensor data injection and heatmap overlay (PRD 3-03).

**Non-goals / deferred**
- Automated SVG mapping/discovery (Manual mapping via JSON for now).
- Multiple SVGs per level (assuming one master SVG per level for POC).
- Master Suite aggregation (focusing on individual room activity first).

---

### PRD Summary Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 3-01 | Floorplan Asset & Mapping Engine | Asset storage, JSON mapping schema, API endpoint | None | `epic-3/mapping-engine` | Foundation for spatial data |
| 3-02 | Interactive Floorplan Viewer | Pan/zoom viewer, hover/click interaction, labels overlay | 3-01 | `epic-3/viewer` | Core UI component |
| 3-03 | Real-time Heatmap & Sensor Injection | Activity scoring, glowing pulse, sensor data badges | 3-01, 3-02 | `epic-3/heatmap` | Real-time visualization |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**: Keep the mapping logic decoupled from the viewer. The viewer should consume a standardized JSON/SVG payload.
- **Components**: Use `ViewComponent` for the floorplan viewer and individual room overlays.
- **Data Access**: Ensure efficient fetching of room states for the entire floorplan to avoid N+1 queries during SVG injection.
- **Error Handling**: Fall back to the list-based view if assets are missing or mapping fails.
- **Accessibility**: Provide ARIA labels for room regions and ensure the floorplan is navigable via keyboard where possible.
- **Mobile**: Ensure pan/zoom works well with touch gestures.

---

### Implementation Status Tracking

- Create `0001-IMPLEMENTATION-STATUS.md` in the epic directory before starting PRD work.
- Update it after each PRD completion.

---

### Success Metrics

- Floorplan loads and renders within 1s of page load.
- 100% of mapped rooms correctly reflect their corresponding Database room state.
- Interactive regions have zero noticeable lag on hover/click.

---

### Next Steps

1. Create `0001-IMPLEMENTATION-STATUS.md`
2. Proceed with PRD 3-01: Floorplan Asset & Mapping Engine

---

### Detailed PRDs

- `PRD-3-01-asset-mapping-engine.md`
- `PRD-3-02-interactive-viewer.md`
- `PRD-3-03-heatmap-sensor-injection.md`
