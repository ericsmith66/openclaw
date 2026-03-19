# PRD 0-01: Retry Button on Failed Sync (Accounts Link Page)

**Epic**: Epic 0 - Immediate Quick Wins (Account Management Hub) v1.0
**Priority**: 1
**Effort**: S (4-6 hours)
**Branch**: `feature/epic0-retry-button`

---

## Log Requirements

Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- **in the log put detailed steps for human to manually test and what the expected results**
- If asked to review please create a separate document called epic0-prd1-retry-button-feedback.md

---

## Overview

Add visible "Retry" buttons next to failed sync indicators on `/accounts/link` to re-enqueue the Plaid sync job for specific items. Keeps recovery intuitive and contained in the account management hub.

---

## Requirements

### Functional
- Render DaisyUI "Retry" button (secondary/danger style) only for PlaidItems that match the display logic below.
- Click → POST to `/plaid_items/:id/retry` (new route) → enqueues `PlaidItemSyncJob.perform_later(plaid_item.id)`.
- Show inline spinner + toast ("Retrying sync…") during job.
- If `plaid_item.sync_in_progress?` → show "Sync already in progress" toast, no enqueue.

### Non-functional
- No page reload — use Turbo.visit('/accounts/link') or simple polling (ENV['SYNC_POLL_INTERVAL'] || 15 seconds) for v1 status refresh.
- Accessibility: ARIA label "Retry sync for [institution name]".

---

## Safety Measures

- Track retry attempts: PlaidItem.retry_count increments on each retry (add column if missing)
- After 3 retries in 1 hour, disable button and show "Contact Support"
- Log retry events to Rails.logger (or retry_events table if added)
- If Plaid returns ITEM_LOCKED, permanently disable retry until user re-authenticates

---

## Retry Button Display Logic

Show button if PlaidItem matches ANY:
- status IN ('failed', 'error', 'degraded')
- plaid_error_code IN ('ITEM_LOGIN_REQUIRED', 'PENDING_EXPIRATION')
- last_synced_at > 24 hours AND status != 'active'

---

## UX Copy States

- Click: "Reconnecting to [Institution]... This may take 30-60 seconds"
- Success: "✓ [Institution] synced! Latest data will appear in 5 minutes"
- Failure: "Unable to sync [Institution]. [Specific reason + Next step]"
- If ITEM_LOGIN_REQUIRED: "Please update your login credentials" + button to re-auth
- If MFA_REQUIRED: "Check your phone for 2FA code, then try again"

---

## PlaidItem Methods Required

If not already present, add to PlaidItem model:

```ruby
def sync_in_progress?
  # Option A: Status-based
  status == 'syncing' || status == 'pending'

  # Option B: Job-based (check if job running)
  # Requires Solid Queue or ActiveJob inspection
  # SolidQueue::Job.where(class_name: 'PlaidItemSyncJob', arguments: plaid_item_id).pending.exists?
end
```

Choose approach based on how sync status is currently tracked.

---

## Database Changes (if needed)

If PlaidItem does not have `retry_count` and `last_retry_at` columns, add migration:

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_retry_tracking_to_plaid_items.rb
class AddRetryTrackingToPlaidItems < ActiveRecord::Migration[7.1]
  def change
    add_column :plaid_items, :retry_count, :integer, default: 0, null: false
    add_column :plaid_items, :last_retry_at, :datetime
    add_index :plaid_items, [:user_id, :retry_count]
  end
end
```

**Alternative**: Count from `retry_events` table (slower but no schema change)
Implementer should verify schema and choose approach in dependency audit.

---

## Feature Flag Integration

In PlaidItemsController#retry:

```ruby
def retry
  unless ENV['EPIC0_RETRY_ENABLED'] == 'true'
    render json: { error: 'Feature disabled' }, status: 503
    return
  end
  # ... rest of retry logic
end
```

---

## Acceptance Criteria

- [ ] Button visible only on matching PlaidItems on `/accounts/link`
- [ ] Click enqueues exactly one job (verifiable in queue console)
- [ ] Status updates on refresh/polling: error → pending → success/fail
- [ ] Toast shows outcome ("Sync retried successfully" or error)
- [ ] No duplicate jobs on rapid clicks
- [ ] Mobile: button sized/touchable, no overflow
- [ ] Retry count increments; disables after 3
- [ ] Logs entry for each retry

---

## Test Cases

### Unit Tests
- `RetryService#call(plaid_item)` → enqueues job once

### Integration Tests
- `AccountsController` spec → POST `/plaid_items/:id/retry` → job enqueued

### Feature Tests
- Mock failed PlaidItem → visit `/accounts/link` → click retry → status updates (VCR mock Plaid if needed)

### Mobile Test Cases
- iPhone SE (small screen): buttons don't overlap, text readable
- Android Chrome: touch targets ≥44px, no tap delay
- Landscape orientation: layout doesn't break
- Slow 3G: loading states appear immediately, no blank screens

---

## Workflow

1. Pull master → `git checkout -b feature/epic0-retry-button`
2. Create dependency audit if needed
3. Plan/ask questions in log
4. Implement with green commits
5. Test thoroughly (including mobile)
6. Push/PR

---

## Dependencies

- Existing sync status tracking in PlaidItem
- PlaidItemSyncJob exists and is idempotent
- `/accounts/link` route and view

---

## Security Considerations

- Retry action must be scoped to current_user (prevent retry of other users' items)
- Rate limiting on server-side to prevent abuse
- No sensitive Plaid data in client-side JS or logs
- CSRF protection on POST endpoint
- Audit logging for retry attempts

---

## Performance Notes

- Polling interval configurable via ENV (default 15s)
- Ensure no N+1 queries when loading PlaidItems
- Cache retry_count checks where possible
