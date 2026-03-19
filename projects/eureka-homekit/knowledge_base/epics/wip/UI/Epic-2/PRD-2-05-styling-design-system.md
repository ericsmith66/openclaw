#### PRD-2-05: Styling & Design System

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---
 
### Overview

Implement a consistent design system with iOS-inspired aesthetics and responsive components. Configure Tailwind, define tokens for colors/spacing/typography, and provide reusable styles for cards, buttons, and badges.

---

### Requirements

#### Functional

- Design Tokens
  - Color palette (primary, status, neutrals) aligned with iOS-inspired values.
  - Typography system (font stack, sizes, weights).
  - Spacing scale using a 4px base unit.
  - Border radius scale (small, medium, large, full).
  - Shadow scale (sm, md, lg, xl).
- Icon & Color Mapping for Sensor Types
  - Temperature, Motion, Humidity, Light, Battery, Contact, Occupancy, Tampered, Active, Charging.
- Component Styles
  - Card: white surface, border, rounded, hover shadow.
  - Button: primary/secondary/danger variants.
  - Status Badge: success/warning/danger classes.
- Responsive Breakpoints
  - Mobile (<640px), Tablet (≥640px and <1024px), Desktop (≥1024px).
  - CSS to hide/collapse sidebars on smaller screens.

#### Non-Functional

- Accessibility: WCAG AA color contrast and visible focus states.
- Consistency: All components should use tokens rather than hard-coded values.
- Extensibility: Leave room for dark mode as a future enhancement.

#### Rails / Implementation Notes (optional)

- Tailwind config updates under `tailwind.config.js` with content paths for views, components, helpers, and JS.
- Utility classes applied in ViewComponents.

---

### Error Scenarios & Fallbacks

- Missing token usage → lint or review guideline to flag hard-coded colors.
- Dark mode not implemented → ensure tokens are neutral and future-ready.

---

### Architectural Context

Provides a unified look and feel across all PRDs in Epic 2. Reduces design drift and improves implementation speed and accessibility.

---

### Acceptance Criteria

- [ ] Consistent color palette applied throughout.
- [ ] Typography system implemented.
- [ ] All components use design system tokens.
- [ ] Responsive design works on mobile/tablet/desktop.
- [ ] Accessibility: WCAG AA contrast ratios (≥4.5:1) for text.

---

### Test Cases

#### Unit (Minitest)

- `test/components/shared/status_badge_component_test.rb`: color classes by status.
- `test/components/shared/button_styles_test.rb`: variant classes applied.

#### System / Smoke (Capybara)

- `test/system/responsive_layout_smoke_test.rb`: sidebars hide on mobile, layout holds on tablet/desktop.

---

### Manual Verification

1. Open multiple views (Dashboard, Homes, Sensors, Events) and confirm consistent typography and colors.
2. Inspect buttons and badges; verify variants and hover/focus states.
3. Resize the browser to mobile and tablet widths; confirm responsive behavior.

**Expected**
- Visual consistency across components and pages.
- Readable contrast and visible focus indicators.
- No stray hard-coded colors overriding tokens.
