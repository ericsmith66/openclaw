# Review of PRD-2-06-event-viewer-sidebar.md — Feedback V1

## Overview
This PRD addresses a critical usability gap in the Event Viewer's sidebar, which currently displays redundant and low-signal information. The proposed improvements aim to transform it into a high-value "at-a-glance" activity panel.

## Questions & Clarifications
1. **Deduplication Logic**: Requirement 65 mentions grouping rapid identical updates (e.g., last 5 humidity reads). Should this grouping happen in the database query (backend) or via Stimulus/JavaScript (frontend)? Grouping in the backend might be more efficient for initial load, but frontend grouping would be needed for live updates.
2. **"View All" Link**: Requirement 82 mentions a "View All" link. Since the sidebar is *on* the `/events` page (which is the "All" view), where should this link point? Or should it simply scroll/focus the main table?
3. **Detail Modal Consistency**: Requirement 68 states clicking an item opens the same detail modal as table rows. Do we have a standard `EventDetailComponent` or modal infrastructure already defined in PRD 2-04 or 2-01?
4. **Live Mode Toggle**: Requirement 81 mentions the live toggle adding new events. Should the sidebar *always* be live, or only when the global "Live Mode" is enabled?

## Suggestions & Improvements
1. **Empty State Tip**: Requirement 69 suggests a "tip" for the empty state. A good tip would be "Ensure your HomeKit bridge is connected and active."
2. **Visual Hierarchy**: Use bolding for the *value* or *change* (e.g., **49%**) and lighter weight for the context (e.g., in Kitchenette) to improve scannability.
3. **Accessibility**: Ensure that the color-coded severity/delta (Requirement 64) is also reflected in text or ARIA labels for color-blind users (e.g., "Humidity increased by 2%").
4. **Integration with 0001-IMPLEMENTATION-STATUS.md**: This PRD (2-06) is not currently listed in the Epic Overview's PRD summary table or the Implementation Status document. It should be added as `2-06` to maintain a single source of truth.

## Objections & Solutions
1. **Objection**: The PRD mentions `app/components/layouts/recent_events_item_component.html.erb` as the likely location, but `knowledge_base/epics/wip/UI/Epic-2/0000-overview-epic-2-web-ui-dashboard.md` suggests a `RightSidebarComponent`.
   - **Solution**: Clarify if `RecentEventsItemComponent` will be a sub-component used *within* `RightSidebarComponent`. I recommend keeping them separate for better reusability.
2. **Objection**: The "Quick Wins" section suggests using `formatted_value(event)` from `Events::RowComponent`. If this logic is shared, it should be moved to a Helper or a Concern to avoid duplication and maintain DRY principles.
   - **Solution**: Create `EventFormattingHelper` or move the logic to the `Event` model if appropriate.

## Conclusion
The PRD is well-reasoned and addresses a clear pain point. With the addition of deduplication and better visual cues, it will significantly improve the dashboard's utility.
