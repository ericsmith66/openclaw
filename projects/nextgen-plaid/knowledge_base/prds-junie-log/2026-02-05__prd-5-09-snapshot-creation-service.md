# Junie Task Log — PRD 5-09 Snapshot Creation Service
Date: 2026-02-05  
Mode: Brave  
Branch: Pending  
Owner: ericsmith66  

## 1. Goal
- Implement the holdings snapshot creation service + SolidQueue job + daily schedule (1:30 AM CST) with tests and safe failure/notification behavior.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-09-snapshot-creation-service.md`
- Depends on PRD 5-08 (HoldingsSnapshot model) and PRD 5-02 (HoldingsGridDataProvider).
- Repo notes:
  - `User.active` is referenced by the PRD schedule example, but no `User.active` scope exists in current app code.
  - PRD references `AdminNotificationJob`, but it does not exist in current app code.

## 3. Plan
1. Implement `CreateHoldingsSnapshotService` that fetches live holdings, serializes to snapshot schema, enforces 24h idempotency unless `force`, logs structured events, and returns a small Result object.
2. Implement `CreateHoldingsSnapshotsJob` using ActiveJob retry semantics (3 attempts exponential backoff), with final-failure admin notification (or safe fallback) and “permanent failure” handling (invalid user, etc.).
3. Add SolidQueue recurring schedule entry at `1:30am` daily.
4. Add Minitest coverage for service + job.
5. Run the smallest relevant tests and record results.
6. Update epic implementation status and finalize this log.

## 4. Work Log (Chronological)
- 2026-02-05: Read PRD 5-09 and existing `HoldingsGridDataProvider` + `HoldingsSnapshot` + `config/recurring.yml`.
- 2026-02-05: Created this task log before first code change (per Junie log requirements).

## 5. Files Changed
- `app/services/create_holdings_snapshot_service.rb`
- `app/jobs/create_holdings_snapshots_job.rb`
- `app/jobs/admin_notification_job.rb`
- `app/models/holdings_snapshot.rb` (added PRD-required scopes)
- `config/recurring.yml` (added `daily_holdings_snapshots` schedule)
- `test/services/create_holdings_snapshot_service_test.rb`
- `test/jobs/create_holdings_snapshots_job_test.rb`
- `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md`

## 6. Commands Run
- `bundle exec rails test test/jobs/create_holdings_snapshots_job_test.rb test/services/create_holdings_snapshot_service_test.rb`

## 7. Tests
- ✅ `test/services/create_holdings_snapshot_service_test.rb`
- ✅ `test/jobs/create_holdings_snapshots_job_test.rb`

## 8. Decisions & Rationale
- Decision: Select “active users” for the recurring command as users with at least one `plaid_item` (e.g., `User.joins(:plaid_items).distinct`).
  - Rationale: `User.active` scope does not exist; `plaid_items` is the best available proxy for users who can have holdings.
- Decision: If no `AdminNotificationJob` exists, implement a minimal `AdminNotificationJob` (or a notification shim) that logs and optionally emails later.
  - Rationale: PRD requires admin notification on final failure; we need a safe behavior that doesn’t silently drop alerts.

## 9. Risks / Tradeoffs
- Risk: Serializing holdings requires mapping `Holding` AR fields into the snapshot JSON schema; schema drift could break snapshot parsing.
- Mitigation: Add unit tests that validate snapshot JSON keys and that `HoldingsGridDataProvider` can read back the snapshot.

## 10. Follow-ups
- [ ] Confirm desired admin notification channel (email vs Slack) and implement integration if needed.
- [ ] Confirm “active users” definition (all users, users with plaid items, or users with investment accounts).

## 11. Outcome
- Implemented PRD 5-09 snapshot creation service + job + recurring schedule entry.
- Added unit tests for idempotency/force/empty portfolio + retry/notification behavior.
- Updated Epic-5 implementation status doc.
- No commits created (awaiting review).

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. In Rails console: run `CreateHoldingsSnapshotsJob.perform_later(user_id: <valid_user_id>, force: true)`.
2. Confirm a new `HoldingsSnapshot` exists for that user (latest `created_at`).
3. Confirm `snapshot_data` contains:
   - `holdings` as an array (possibly empty)
   - `totals` with `portfolio_value`, `total_gl_dollars`, `total_gl_pct`
4. Trigger again with `force: false` within 24h and confirm it is skipped (no new snapshot created).
5. Trigger again with `force: true` and confirm a new snapshot is created.
6. (Optional) Temporarily adjust recurring schedule to `every 1 minute` in `config/recurring.yml` and confirm jobs enqueue.
7. Simulate a transient failure (e.g., stub provider to raise) and confirm retries happen; on final failure confirm an admin notification is emitted/logged.
