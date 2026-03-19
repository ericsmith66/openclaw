# Junie Task Log — PRD-3-17: Refresh Snapshot / Sync Status Widget
Date: 2026-01-27  
Mode: Brave  
Branch: feature/prd-3-17-refresh-widget  
Owner: junie

## 1. Goal
- Add a refresh button + sync-status badge for the Net Worth dashboard that triggers `FinancialSnapshotJob`, provides Turbo Stream feedback (pending/complete/error), and prevents abuse via a 1/min per-user rate limit.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-3/0080-PRD-3-17.md`
- Existing dashboard header had export dropdown (PRD-3-16); PRD-3-17 adds refresh + status.
- Must be user-scoped (no cross-user stream/broadcast leakage).

## 3. Plan
1. Add `/net_worth/sync` endpoint to enqueue `FinancialSnapshotJob` and immediately show pending status.
2. Add widget UI (Turbo Frame + stream subscription) in dashboard header and sync status partial.
3. Add `rack-attack` throttling (1/min per user) and Turbo Stream 429 response with countdown.
4. Broadcast completion/error from `FinancialSnapshotJob` back to the user-scoped stream.
5. Add tests for widget states, sync endpoint, throttling, and user scoping.

## 4. Work Log (Chronological)
- Implemented `POST /net_worth/sync` route + controller to enqueue job and Turbo-stream pending state.
- Added `NetWorth::SyncStatusWidgetComponent` (Turbo Frame + `turbo_stream_from` user-scoped stream) and `net_worth/_sync_status` partial for pending/complete/error/rate-limited UI.
- Added `countdown` Stimulus controller for the “try again in N seconds” countdown.
- Added `rack-attack` middleware + initializer throttle `snapshot_sync/user` (1/min per user) and a Turbo Stream throttled responder that replaces the widget content with rate-limited state + countdown.
- Updated `FinancialSnapshotJob` to broadcast success and failure states to `net_worth:sync_status:<user_id>`.
- Added ViewComponent and Integration tests; fixed helper availability in ViewComponent template.

## 5. Files Changed
- `Gemfile` — add `rack-attack`.
- `config/application.rb` — add `Rack::Attack` middleware.
- `config/initializers/rack_attack.rb` — add `snapshot_sync/user` throttle + Turbo Stream 429 responder + in-memory cache store for test/dev.
- `config/routes.rb` — add `post "sync", to: "syncs#create"`.
- `app/controllers/net_worth/syncs_controller.rb` — enqueue `FinancialSnapshotJob` and render pending Turbo Stream.
- `app/jobs/financial_snapshot_job.rb` — broadcast complete/error to user-scoped Turbo stream.
- `app/views/net_worth/dashboard/show.html.erb` — add refresh/status widget to header.
- `app/views/net_worth/_sync_status.html.erb` — UI for sync status states.
- `app/components/net_worth/sync_status_widget_component.rb` — widget component.
- `app/components/net_worth/sync_status_widget_component.html.erb` — Turbo Frame + stream subscription.
- `app/javascript/controllers/countdown_controller.js` — countdown timer for rate-limit message.
- `test/components/net_worth/sync_status_widget_component_test.rb` — widget rendering + stream scoping assertion.
- `test/integration/net_worth_sync_test.rb` — sync endpoint + rate limit behavior.
- `config/environments/development.rb` — default ActiveJob adapter to `:async` unless Solid Queue is explicitly enabled.

## 6. Commands Run
- `bundle install` — ✅ installed `rack-attack`.
- `bin/rails test test/components/net_worth/sync_status_widget_component_test.rb test/integration/net_worth_sync_test.rb` — ✅ pass.

## 7. Tests
- `bin/rails test test/components/net_worth/sync_status_widget_component_test.rb test/integration/net_worth_sync_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Use `rack-attack` for throttling `/net_worth/sync`.
  - Rationale: Central, framework-standard request throttling and matches PRD requirement.
- Decision: Use user-scoped Turbo stream name `net_worth:sync_status:<user_id>`.
  - Rationale: Prevent cross-user status leaks; easy to test by verifying signed stream name.
- Decision: Render a Turbo Stream response from rack-attack on 429.
  - Rationale: Keeps feedback inline in the widget rather than a full-page error.

## 9. Risks / Tradeoffs
- Using an in-memory rack-attack cache is not multi-process safe.
  - Mitigation: In production, configure a shared cache store (e.g., Redis) if the app runs multiple processes/servers.

- In development, `:solid_queue` requires a worker (`bin/rails solid_queue:start`) or the Puma plugin.
  - Mitigation: default development to `:async` unless opted-in.

## 10. Follow-ups
- [ ] Confirm production cache strategy for rack-attack (Redis vs Solid Cache) if deploying multi-instance.
- [ ] Consider disabling the refresh button during rate-limit window (currently shows rate-limited badge + countdown).

## 11. Outcome
- Net Worth dashboard now includes a Refresh button and sync-status badge.
- Clicking Refresh shows immediate “Syncing…” feedback and enqueues `FinancialSnapshotJob`.
- On job completion/failure, the badge updates via user-scoped Turbo Stream broadcast.
- Rate limit (1/min per user) returns a Turbo Stream 429 response with countdown.

## 12. Commit(s)
- Add net worth snapshot sync status widget — `3acc56e`

## 13. Manual steps to verify and what user should see
1. Sign in and visit `/net_worth/dashboard`.
2. Click `Refresh`.
3. Widget changes to `Syncing…` and button disables.
4. After job completes, widget changes to `Up to date` with updated “Last sync … ago”.
5. Click `Refresh` again immediately; widget shows `Rate limited` and an alert: “Refresh limit reached — try again in Ns”.
