#### PRD-2-01: Core Layout & ViewComponents Infrastructure

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---
 
### Overview

Establish the foundational ViewComponent architecture for the Web UI Dashboard. This includes the application layout, header, sidebars, and several shared components that will be used across all other views in Epic 2.

---

### Requirements

#### Functional

- **AppLayout**: A three-column responsive layout with a header, left sidebar, main content area, and right sidebar.
- **HeaderComponent**: Displays the application logo, navigation tabs (Dashboard, Homes, Sensors, Events), and a sync status indicator.
- **LeftSidebarComponent**: Provides hierarchical navigation through homes and rooms, category filters, and quick access links.
- **RightSidebarComponent**: A context-sensitive panel that shows details based on the current selection in the main content area.
- **BreadcrumbComponent**: A clickable navigation path (e.g., Home > Room > Accessory).
- **StatusBadgeComponent**: A versatile badge for showing status (success, warning, danger, info) with optional pulse animation.
- **StatCardComponent**: Displays a label, large value, icon, and optional trend indicator.
- **SearchBarComponent**: A debounced search bar with filter integration.

#### Non-Functional

- **Responsiveness**: Sidebars should collapse on mobile devices (< 768px). Use standard breakpoints (640px, 768px, 1024px).
- **Performance**: Components should be lightweight and avoid unnecessary re-renders.
- **Accessibility**: Use semantic HTML5 elements and ARIA labels where appropriate.

#### Rails / Implementation Notes (optional)

- **Components**: `app/components/layouts/application_layout.rb`, `app/components/header_component.rb`, etc.
- **Styling**: Tailwind CSS and DaisyUI.
- **Interactions**: Stimulus for sidebar toggles and search debouncing.

---

### Error Scenarios & Fallbacks

- **Missing Data** → Show empty-state UI for sidebars and stat cards.
- **Sync Failure** → Update `StatusBadge` in header to 'danger' and show last successful sync timestamp.

---

### Architectural Context

This PRD establishes the "shell" of the application. All subsequent PRDs (2-02 to 2-04) will render their content within the `Main Content` area of this layout and utilize the shared components defined here.

---

### Acceptance Criteria

- [ ] Application layout renders correctly on desktop, tablet, and mobile.
- [ ] Sidebars can be toggled on/off on mobile.
- [ ] Header navigation highlights the active page.
- [ ] StatCard and StatusBadge components render with various props.
- [ ] SearchBar debounces input correctly (300ms).

---

### Test Cases

#### Unit (Minitest)

- `test/components/layouts/application_layout_test.rb`: Verifies three columns and responsive classes.
- `test/components/header_component_test.rb`: Checks navigation items and active state.
- `test/components/shared/stat_card_component_test.rb`: Verifies rendering of values and icons.

#### System / Smoke (Capybara)

- `test/system/layout_navigation_test.rb`: Verifies clicking navigation tabs updates the active state and main content area.

---

### Manual Verification

1. Open the application in a browser.
2. Verify the three-column layout is visible.
3. Resize the browser to mobile width and verify sidebars collapse.
4. Toggle the sidebar using the header button.
5. Click through the navigation tabs.

**Expected**
- Layout is consistent across views.
- Mobile responsiveness works as expected.
- No console errors.

---
