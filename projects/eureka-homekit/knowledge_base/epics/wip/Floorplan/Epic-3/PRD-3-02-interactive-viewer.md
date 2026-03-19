#### PRD-3-02: Interactive Floorplan Viewer

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-3-02-interactive-viewer-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

This PRD covers the frontend implementation of the SVG floorplan as an interactive navigation tool. It enables users to view their home layout, zoom/pan for details, and interact with specific rooms to see more information.

---

### Requirements

#### Functional

- **Responsive Viewer**: A frontend component that renders the SVG and allows for intuitive zooming and panning.
- **Interactive Regions**:
  - Mapped rooms should highlight (change opacity or stroke) when hovered.
  - Clicking a mapped room should trigger an action (e.g., navigate to room detail page or open a modal).
  - Unmapped regions should remain static and non-interactive.
- **Dynamic Labels Overlay**: Instead of editing the SVG DOM to add text, use an HTML overlay layer to position room names and status badges over the SVG coordinates.
- **Level Switcher**: A UI control to toggle between different floorplan levels (e.g., "1st Floor", "2nd Floor").

#### Non-Functional

- **Performance**: Zooming and panning must be smooth (> 60fps).
- **Accessibility**: Interactive rooms must be focusable via keyboard and have appropriate ARIA labels.
- **Mobile Support**: Implement touch gestures for pan/zoom.

#### Rails / Implementation Notes (optional)

- **Components**: `FloorplanViewerComponent` (ViewComponent).
- **JavaScript**: Stimulus controller to handle pan/zoom (using a library like `svg-pan-zoom`) and interaction events.
- **CSS**: Tailwind classes for the layout and SVG highlighting.

---

### Error Scenarios & Fallbacks

- **SVG Loading Error** → Display a "Floorplan Unavailable" message and provide a link to the standard list view.
- **Missing room for a mapped region** → Region remains unhighlightable.

---

### Architectural Context

This PRD depends on the API provided by PRD 3-01. It focuses purely on the presentation and interaction layer in the browser.

---

### Acceptance Criteria

- [ ] Floorplan renders correctly within the Dashboard.
- [ ] Users can zoom and pan the SVG using mouse or touch.
- [ ] Hovering over a mapped room shows a visual highlight.
- [ ] Clicking a room opens the room details (modal or navigation).
- [ ] Room labels are visible and correctly aligned with their corresponding SVG regions.

---

### Test Cases

#### Unit (Minitest)

- `test/components/floorplan_viewer_component_test.rb`: Test that the component renders with correct data attributes for the Stimulus controller.

#### System / Smoke (Capybara)

- `test/system/floorplan_interaction_test.rb`: Test that hovering/clicking a room element in the SVG triggers the expected UI updates.

---

### Manual Verification

1. Open the Dashboard.
2. Click the "Floorplan" button.
3. Verify that the SVG loads.
4. Test zooming with the mouse wheel and panning by dragging.
5. Hover over a room (e.g., "Kitchen") and ensure it highlights.
6. Click the room and verify it opens the room details.

**Expected**
- Smooth rendering and interaction.
- Labels are readable and correctly placed.

---

### Rollout / Deployment Notes (optional)

- Initial release might use full-page navigation for room clicks, with modals as a future enhancement.
- Labels will be implemented as an overlay to ensure SVG performance.
