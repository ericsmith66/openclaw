# PRD 5-09: Holdings Snapshots – Creation Service & Scheduled Job

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Implement a service and solidqueue job to capture current holdings as JSON snapshots, supporting manual triggers and daily scheduled runs (~1:30 AM CST).

## Requirements

### Functional
- **CreateHoldingsSnapshotService**:
  - Input: user_id, account_id (optional), name (optional), force: false
  - Fetches holdings via HoldingsGridDataProvider in :live mode
  - Serializes holdings + totals to JSON matching snapshot schema
  - Creates HoldingsSnapshot record
  - Returns created snapshot or error
- **Idempotency Check**:
  - Skip if recent snapshot (<24h) exists for same scope unless `force: true`
  - User-level: check `user_id` where `account_id` is null
  - Account-level: check `user_id` + `account_id`
- **Background Job**: CreateHoldingsSnapshotsJob
  - Accepts: user_id, account_id: nil, force: false
  - Calls service async via SolidQueue
  - Daily scheduled run at 1:30 AM CST (after US market after-hours close)
  - Processes all active users (or specific user if triggered manually)
- **Manual Trigger**:
  - Via console: `CreateHoldingsSnapshotsJob.perform_later(user_id: 1)`
  - Via future UI button (PRD 5-13)
- **Error Handling**:
  - SolidQueue default exponential backoff (3 retries)
  - On final failure: log error + enqueue admin notification job (email/Slack)
  - Transient failures (Plaid timeout, DB lock): retry
  - Permanent failures (invalid user, empty portfolio): log, don't retry

### Non-Functional
- SolidQueue for async processing
- Timestamps: created_at = Time.current
- Structured logging: log start, duration, success/failure, snapshot ID
- Monitoring: track snapshot creation rate, failures (StatsD/Prometheus)
- Gracefully handle empty portfolios (create snapshot with empty holdings array)
- Schedule  `SolidQueue`

## Architectural Context
- Service: `app/services/create_holdings_snapshot_service.rb`
- Job: `rails g job CreateHoldingsSnapshots` → `app/jobs/create_holdings_snapshots_job.rb`
- Uses HoldingsGridDataProvider in :live mode (no snapshot_id)
- Schedule in SolidQueue 

## Service Implementation

```ruby
# app/services/create_holdings_snapshot_service.rb
class CreateHoldingsSnapshotService
  def initialize(user_id:, account_id: nil, name: nil, force: false)
    @user_id = user_id
    @account_id = account_id
    @name = name
    @force = force
  end

  def call
    return skip_result unless should_create?

    snapshot_data = fetch_holdings_data
    snapshot = create_snapshot(snapshot_data)

    log_success(snapshot)
    Result.success(snapshot)
  rescue => e
    log_failure(e)
    Result.failure(e.message)
  end

  private

  def should_create?
    return true if @force

    !recent_snapshot_exists?
  end

  def recent_snapshot_exists?
    scope = HoldingsSnapshot.where(user_id: @user_id)
    scope = @account_id ? scope.where(account_id: @account_id) : scope.user_level
    scope.where('created_at > ?', 24.hours.ago).exists?
  end

  def fetch_holdings_data
    provider = HoldingsGridDataProvider.new(
      user_id: @user_id,
      account_filter_id: nil, # all accounts or specific account
      snapshot_id: :live,
      per_page: 'all'
    )

    holdings = provider.holdings
    totals = provider.totals

    {
      holdings: holdings.map(&:to_snapshot_hash),
      totals: totals
    }
  end

  def create_snapshot(data)
    HoldingsSnapshot.create!(
      user_id: @user_id,
      account_id: @account_id,
      name: @name,
      snapshot_data: data
    )
  end

  def log_success(snapshot)
    Rails.logger.info("Snapshot created: ID=#{snapshot.id}, user=#{@user_id}, account=#{@account_id}, holdings_count=#{snapshot.snapshot_data['holdings'].size}")
  end

  def log_failure(error)
    Rails.logger.error("Snapshot creation failed: user=#{@user_id}, error=#{error.message}")
  end

  def skip_result
    Result.skipped('Recent snapshot exists')
  end
end
```

## Job Implementation

```ruby
# app/jobs/create_holdings_snapshots_job.rb
class CreateHoldingsSnapshotsJob < ApplicationJob
  queue_as :default

  # Solid Queue uses ActiveJob retry semantics.
  # `executions` increments each time the job runs (including retries).
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(user_id:, account_id: nil, force: false)
    service = CreateHoldingsSnapshotService.new(
      user_id: user_id,
      account_id: account_id,
      force: force
    )

    result = service.call

    if result.failure?
      notify_admin_on_final_failure(user_id, result.error) if executions >= 3
      raise StandardError, result.error # trigger retry
    end
  end

  private

  def notify_admin_on_final_failure(user_id, error)
    AdminNotificationJob.perform_later(
      subject: "Snapshot creation failed for user #{user_id}",
      message: error
    )
  end
end
```

## Scheduled Job Configuration

Use Solid Queue recurring tasks via `config/recurring.yml`.

```yaml
# config/recurring.yml
production:
  daily_holdings_snapshots:
    command: "User.active.find_each { |u| CreateHoldingsSnapshotsJob.perform_later(user_id: u.id) }"
    schedule: at 1:30am every day
```

## Acceptance Criteria
- Service creates snapshot matching current holdings
- Snapshot JSON structure matches schema
- Idempotency: skips if recent (<24h) snapshot exists
- Force flag bypasses idempotency check
- Job enqueues and processes async via Solid Queue
- Daily schedule runs at 1:30 AM CST
- Retries on transient failures (3x exponential backoff)
- Admin notification sent on final failure
- Handles empty portfolios gracefully (creates snapshot with empty holdings)
- Logs structured data (duration, success/failure, snapshot ID)

## Test Cases
- **Service**:
  - Mock data provider → assert JSON structure correct
  - Assert snapshot record created with correct attributes
  - Idempotency: recent snapshot exists → skip unless force
  - Empty portfolio → creates valid snapshot
  - Data provider error → returns failure result
- **Job**:
  - Enqueue job → verify performs
  - Mock service failure → verify retry triggered
  - Final retry → verify admin notification sent
- **VCR/WebMock**: mock any external API calls
- **Edge**:
  - Plaid API timeout → retry
  - Invalid user_id → log error, don't retry
  - Very large portfolio (500+ holdings) → ensure JSON under 1MB
  - Account deleted during snapshot → handle gracefully

## Manual Testing Steps
1. Rails console: trigger manual snapshot
   ```ruby
  CreateHoldingsSnapshotsJob.perform_later(user_id: 1, force: true)
  ```
2. Verify job enqueued (examples):
   - Visit `/admin/health` → confirm Solid Queue is healthy
   - Rails console: `SolidQueue::Job.where(class_name: "CreateHoldingsSnapshotsJob").order(created_at: :desc).limit(5)`
3. Wait for job to process → check logs for "Snapshot created"
4. Query HoldingsSnapshot → verify new record exists
5. Verify snapshot_data structure matches schema
6. Trigger again without force → verify skipped (recent exists)
7. Trigger with force → verify new snapshot created
8. Test scheduled job: set schedule to "every 1 minute" temporarily → verify runs
9. Simulate failure (e.g., disconnect DB) → verify retry attempts
10. Verify admin notification sent after final failure (check email/Slack)
11. Verify job shows as failed/finished in Solid Queue tables after retries exhausted
12. Test with empty portfolio user → verify snapshot created with empty holdings

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-09-snapshot-creation-service`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-02 (Data provider service for fetching holdings)
- PRD 5-08 (HoldingsSnapshot model)

## Blocked By
- PRD 5-08 must be complete

## Blocks
- PRD 5-11 (Snapshot selector lists created snapshots)
- PRD 5-13 (Snapshot management UI triggers manual creation)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-08: Holdings Snapshots Model](./PRD-5-08-holdings-snapshots-model.md)
- [Feedback V2 - Snapshot Creation](./Epic-5-Holding-Grid-feedback-V2.md#prd-9-snapshot-creation)
