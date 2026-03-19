The **Recent Events** panel (right sidebar in `/events`) currently shows redundant and low-signal information. Each item displays generic titles like "Characteristic Updated" without specific context, making it difficult to scan for actual activity at a glance.

### Proposed Solution
Replace the generic sidebar with a high-signal "at-a-glance" panel that summarizes what changed (e.g., "Kitchenette humidity → 49%"), uses visual cues (icons, bolding), groups rapid identical events, and supports live updates synchronized with the dashboard's Live Mode.

### Requirements

#### 1. Architecture & Components
- **RightSidebarComponent**: Container for the recent events list, live mode sync, and empty states.
- **RecentEventsItemComponent**: Individual scannable event summaries.
- **EventDetailModalComponent**: Standardized modal for viewing full event details (shared with main table).
- **EventFormattingHelper**: DRY helper for units, deltas, and icons.

#### 2. Visual Design & Scannability
- **Hierarchy**: Bold the *value* or *change* (e.g., **49%**); use lighter text for context (e.g., "humidity in Kitchenette").
- **Icons**: Use specific icons based on characteristic (thermometer, droplet, bulb, etc.).
- **Deltas**: Show deltas (↑ ↓) with visible text (e.g., "↑ 2%") for accessibility.
- **Color**: Use DaisyUI semantic colors (success, info, warning) for status/deltas.

#### 3. Data & Deduplication (Hybrid Approach)
- **Backend**: Implement `recent_events_grouped` scope in the `Event` model to collapse identical rapid updates (e.g., within 30s) for initial load. Show a count badge (e.g., "×5").
- **Frontend**: Stimulus controller handles client-side merging for live updates to avoid redundant round-trips.

#### 4. Interaction & Live Mode
- **Live Sync**: Sidebar respects the global "Live Mode" toggle. New events are appended/merged only when Live Mode is ON.
- **Detail View**: Clicking an item opens the `EventDetailModalComponent`.
- **Navigation**: Replace "View All" with a **"Show in table"** link that smooth scrolls to the main events table.
- **Empty State**: Display: "No recent events. Ensure your Prefab/HomeKit bridge is running and connected. Check the bridge status in Settings."

### Acceptance Criteria
- [ ] Sidebar displays specific characteristic + value/change summaries.
- [ ] Visual hierarchy uses bolding for values and distinct icons for event types.
- [ ] Rapid identical updates are grouped into a single entry with a count.
- [ ] Clicking an item opens the standardized detail modal.
- [ ] Sidebar live updates are synchronized with the global Live Mode toggle.
- [ ] "Show in table" triggers a smooth scroll to the main history.
- [ ] Accessibility: Visible text/labels for all color-coded or icon-only information.

### Test Cases
- **Unit**: `EventFormattingHelper` returns correct strings/icons for varied characteristics.
- **Component**: `RecentEventsItemComponent` renders bold values and ARIA labels.
- **System**: Live toggle on -> new event appears in sidebar. Click -> modal opens.
- **System**: Multiple rapid humidity updates group into one sidebar item with count.