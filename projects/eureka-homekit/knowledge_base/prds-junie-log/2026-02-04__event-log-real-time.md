# Junie Task Log — Event Log Viewer with Real-Time Updates
Date: 2026-02-04  
Mode: Brave  
Branch: main  
Owner: Junie

## 1. Goal
- Implement a real-time Event Log viewer with filtering, search, and live updates via ActionCable, as per PRD-2-04.

## 2. Context
- Part of Epic 2: Web UI Dashboard.
- References: `knowledge_base/epics/wip/UI/Epic-2/PRD-2-04-event-log-real-time.md` (Objective 2.4).

## 3. Plan
1. Fix `Sensor#value_unit` NoMethodError reported by user.
2. Implement `EventsController` with filtering and basic stats.
3. Create `Events::RowComponent`, `Events::StatisticsComponent`, and `Events::FilterComponent`.
4. Configure ActionCable `EventsChannel` and broadcasting from `Api::HomekitEventsController`.
5. Create Stimulus `events_controller.js` for real-time table updates and detail modal.
6. Add request specs and fix existing `Api::HomekitEvents` spec regressions.

## 4. Work Log (Chronological)
- 2026-02-04: Added `value_unit` to `Sensor` model to fix UI crash in Room cards.
- 2026-02-04: Fixed `undefined method 'create_sensor_from_params'` in `Api::HomekitEventsController`.
- 2026-02-04: Implemented `EventsController` and routed `/events`.
- 2026-02-04: Created Event Log UI components (Row, Statistics, Filter).
- 2026-02-04: Integrated ActionCable broadcasting for new events.
- 2026-02-04: Implemented Stimulus controller for live updates and modal detail views.
- 2026-02-04: Fixed all `Api::HomekitEvents` request specs by providing proper mock data and handling deduplication logic in tests.

## 5. Files Changed
- `app/models/sensor.rb` — Added `value_unit` method.
- `app/controllers/api/homekit_events_controller.rb` — Added broadcasting and fixed auto-discovery logic.
- `app/controllers/events_controller.rb` — New controller for event log.
- `config/routes.rb` — Added `events` resources.
- `app/components/events/row_component.rb/html.erb` — New component for table rows.
- `app/components/events/statistics_component.rb/html.erb` — New component for event stats.
- `app/components/events/filter_component.rb/html.erb` — New component for search/filter UI.
- `app/javascript/controllers/events_controller.js` — New Stimulus controller for real-time updates.
- `app/channels/events_channel.rb` — ActionCable channel for event stream.
- `app/views/events/index.html.erb` — Main event log view.
- `app/views/events/show.html.erb` — Partial view for event detail modal.
- `spec/requests/events_spec.rb` — New request specs for events.
- `spec/requests/api/homekit_events_spec.rb` — Updated to match new controller behavior.

## 6. Commands Run
- `bundle exec rspec spec/requests/events_spec.rb` — ✅ pass
- `bundle exec rspec spec/requests/api/homekit_events_spec.rb` — ✅ pass
- `bundle exec rspec spec/components` — ✅ pass

## 7. Tests
- `spec/requests/events_spec.rb` — ✅ pass
- `spec/requests/api/homekit_events_spec.rb` — ✅ pass
- `spec/components/*` — ✅ pass

## 8. Decisions & Rationale
- Decision: Use `ApplicationController.render` for broadcasting.
    - Rationale: Allows reuse of ViewComponents for real-time updates, keeping logic DRY between initial load and live stream.
- Decision: Rescue broadcasting errors.
    - Rationale: Webhook ingestion is critical; a failure in the real-time UI broadcast should not crash the event storage process.

## 9. Risks / Tradeoffs
- Risk: High frequency of events could overwhelm the DOM.
    - Mitigation: Limited live updates to 50 rows in the Stimulus controller (removes oldest row when adding new).

## 10. Follow-ups
- [ ] Implement event log export to CSV.
- [ ] Add infinite scroll for older events.

## 11. Outcome
- Event Log Viewer is fully functional with live updates, search, and filtering.

## 12. Commit(s)
Pending

## 13. Manual steps to verify and what user should see
1. Navigate to `/events`.
2. Observe the Statistics Bar showing current throughput.
3. Use the Search bar to filter by accessory name.
4. Click on any row to open the Detail Modal with the raw JSON payload.
5. (Developer) Send a POST to `/api/homekit/events` and watch the row appear at the top of the table instantly.
