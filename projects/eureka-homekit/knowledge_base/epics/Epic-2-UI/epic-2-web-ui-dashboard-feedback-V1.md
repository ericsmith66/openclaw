# Review: Epic 2 - Web UI Dashboard for HomeKit Monitoring (V1)

## Overview
This document provides a review of `epic-2-web-ui-dashboard.md`, as per the guidelines in `.junie/guideline.md`. The Epic is well-structured and comprehensive, covering layout, specific views (Homes, Rooms, Sensors, Events), a design system, and technical implementation details.

---

## ❓ Questions
1.  **Minitest vs RSpec**: The guidelines specify **Minitest**, but the project uses **RSpec**. Should I proceed with Minitest for new components?
2.  **Chart.js Dependency**: Is this already added to `package.json`?
3.  **Real-Time Statistics**: Should these be updated via ActionCable for every event, or polled?
4.  **DaisyUI vs Custom**: The guidelines mention **DaisyUI**, but the Epic/UI.md mentions custom iOS-inspired aesthetics. Which should be primary?
5.  **18 Modular Components**: `ui.md` mentions 18 modular ViewComponents. Does this list include the 8 already defined in PRD 2.1, or are there 10 more to define?

---

## 💡 Suggestions & Improvements
1.  **Empty States**: As per guideline #4, ensure all components (especially `RoomDetailComponent` and `SensorDetailComponent`) handle missing data or empty arrays gracefully by providing a clear empty-state UI.
2.  **Breadcrumb Service/Helper**: Instead of passing raw props to `BreadcrumbComponent` in every view, consider a small helper or service to generate breadcrumbs based on the current controller/action to ensure consistency.
3.  **Turbo Frames for Modals**: For "Sensor Detail Detail Panel" (PRD 2.2 #4), using Turbo Frames to load the detail view into a side panel or modal without a full page reload would enhance the "app-like" feel.
4.  **Accessibility (ARIA Labels)**: Ensure `StatCardComponent` and other dashboard widgets have clear `aria-labels` for screen readers, as suggested in guideline #4.
5.  **Deduplication Visuals**: In the Event Log (PRD 2.4), explicitly show the "deduplication rate" in the stats bar and use the `⏭️` icon for deduped events as shown in the `ui.md` wireframe.
6.  **Sidebar Metadata**: Ensure the `RightSidebarComponent` includes the full metadata suite (UUID, Service, Writable, Events) as detailed in the `ui.md` details panel wireframe.

---

## 🛑 Objections & Potential Solutions
1.  **Objection: Performance of `includes()` on Sensors Index**:
    - **Issue**: PRD 2.3 #344 calls `Sensor.includes(:accessory, room: :home)`. With 253+ sensors, this is efficient, but if the number of accessories or homes grows significantly, the initial load might still be heavy.
    - **Solution**: Consider adding a specialized scope or a cached summary for the dashboard stats to avoid loading all full sensor objects just to show counts and averages.
2.  **Objection: ActionCable Broadcast in Webhook Controller**:
    - **Issue**: PRD 2.4 #470 proposes broadcasting directly from the controller. This might block the webhook response if the ActionCable server is busy.
    - **Solution**: Move the broadcast to an `after_create_commit` hook in the `HomekitEvent` model or a background job (using Solid Queue as per the tech stack) to ensure the webhook response remains fast.
3.  **Objection: Hardcoded iOS Colors in SCSS**:
    - **Issue**: PRD 2.5 #597 defines colors in SCSS, but later defines them in `tailwind.config.js`.
    - **Solution**: Consolidate design tokens in `tailwind.config.js` and use Tailwind's `@apply` or functional colors in CSS to avoid duplication and ensure the design system is the "single source of truth".
4.  **Objection: Mismatched Accessory/Sensor Search**:
    - **Issue**: PRD 2.4 #567 searches `accessory_name` or `characteristic`.
    - **Solution**: Since `HomekitEvent` now has `accessory_id` and `sensor_id` (from recent fixes), the search should ideally leverage these associations or specific indexed columns for better performance.

---

## 📋 Implementation Status Check
The Epic should be accompanied by `0001-IMPLEMENTATION-STATUS.md` in the `knowledge_base/epics/Epic-2-UI/` directory. I will verify if it exists and create it if necessary, following guideline #9.

**STATUS: DONE — awaiting review (no commit yet)**
