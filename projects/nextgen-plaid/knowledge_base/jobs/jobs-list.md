### What scheduled/background jobs exist in this repo

#### Scheduler
This app uses **Rails Solid Queue**.
- Worker process: `bin/rails solid_queue:start` (see `Procfile.dev`, entry `worker:`)
- Recurring schedule config: `config/recurring.yml` (has both `development:` and `production:` schedules)

---

### A) Recurring / scheduled jobs (from `config/recurring.yml`)
These are the jobs that are intended to run automatically on a schedule (defined for both **development** and **production**):

1) `clear_solid_queue_finished_jobs`
- **Type:** `command:`
- **Schedule:** `every hour at minute 12`
- **Command:** `SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)`
- **Purpose:** housekeeping—clears finished jobs to keep the Solid Queue tables from growing without bound.

2) `daily_plaid_sync_fallback`
- **Type:** `class: DailyPlaidSyncJob`
- **Schedule:** `at 2am every day`
- **Implementation:** `app/jobs/daily_plaid_sync_job.rb`
- **Purpose:** if a `PlaidItem` hasn’t received a webhook in 24h, enqueue fallback sync jobs:
    - `SyncHoldingsJob.perform_later(item.id)`
    - `SyncTransactionsJob.perform_later(item.id)`
    - `SyncLiabilitiesJob.perform_later(item.id)`

3) `daily_auto_sync`
- **Type:** `class: SyncAllItemsJob`
- **Schedule:** `at 3am every day`
- **Implementation:** `app/jobs/sync_all_items_job.rb`
- **Purpose:** enqueues holdings/transactions/liabilities syncs for **every** `PlaidItem`.

4) `rotate_agent_logs`
- **Type:** `command:`
- **Schedule:** `at 3am every day`
- **Command:** `rake logs:rotate`
- **Purpose:** rotates/archives agent logs (exact behavior is defined in the rake task).

5) `daily_sap_rag_snapshot`
- **Type:** `command:`
- **Schedule:** `at 3am every day`
- **Command:** `rake sap:rag:snapshot`
- **Purpose:** generates a daily “RAG snapshot” (SAP/agent context material) via rake task.

6) `daily_financial_snapshot`
- **Type:** `class: FinancialSnapshotJob`
- **Schedule:** `at 12am every day`
- **Implementation:** `app/jobs/financial_snapshot_job.rb`
- **Purpose:** produces a daily Financial Snapshot JSON payload.

7) `weekly_sap_rag_cleanup`
- **Type:** `command:`
- **Schedule:** `at 4am every Sunday`
- **Command:** `rake sap:rag:cleanup`
- **Purpose:** cleans up old RAG snapshot artifacts via rake task.

8) `weekly_null_field_detection`
- **Type:** `class: NullFieldDetectionJob`
- **Schedule:** `at 5am every Sunday`
- **Implementation:** `app/jobs/null_field_detection_job.rb`
- **Purpose:** scans core tables for null-field patterns by institution and writes a report (default output: `knowledge_base/schemas/null_fields_report.md`).

9) `weekly_holdings_enrichment`
- **Type:** `class: HoldingsEnrichmentJob`
- **Schedule:** `at 4am every Sunday`
- **Implementation:** `app/jobs/holdings_enrichment_job.rb`
- **Purpose:** enriches equity holdings (via `FmpEnricherService`) and upserts `SecurityEnrichment` data; also derives `asset_class` when missing.

---

### B) Other background job classes (not necessarily scheduled)
These live in `app/jobs/` and are typically enqueued by controllers/webhooks or other jobs:

- `SyncHoldingsJob` (`app/jobs/sync_holdings_job.rb`) — sync holdings for a `PlaidItem`.
- `SyncTransactionsJob` (`app/jobs/sync_transactions_job.rb`) — sync transactions for a `PlaidItem`.
- `SyncLiabilitiesJob` (`app/jobs/sync_liabilities_job.rb`) — sync liabilities for a `PlaidItem`.
- `SyncAccountsJob` (`app/jobs/sync_accounts_job.rb`) — sync accounts/balances for a `PlaidItem`.
- `ForcePlaidSyncJob` (`app/jobs/force_plaid_sync_job.rb`) — manual/forced sync orchestration.
- `TransactionEnrichJob` (`app/jobs/transaction_enrich_job.rb`) — enrich transaction metadata.
- `FinancialSnapshotJob` (`app/jobs/financial_snapshot_job.rb`) — produces Financial Snapshot JSON (Epic 2/3 direction).
- Agent/SAP pipeline jobs:
    - `SapAgentJob`, `SapProcessJob`, `SapRefreshJob`, `AgentQueueJob`, `CleanupOldRunsJob` (various agent orchestration/cleanup tasks).

(If you want, I can enumerate these with purpose by opening each file; the scheduled list above is complete per `config/recurring.yml`.)

---

### C) “When did they last run?”
There are **two practical sources**:

#### 1) Overall last job activity (any job)
`Admin::HealthController` computes overall “last job finished/claimed/succeeded” timestamps from Solid Queue:
- Implementation: `app/controllers/admin/health_controller.rb` (`check_solid_queue`)
- It uses:
    - `SolidQueue::Job.where.not(finished_at: nil).maximum(:finished_at)`
    - `SolidQueue::ClaimedExecution.maximum(:created_at)`
    - last succeeded = finished jobs excluding failed executions

If you can hit the health endpoint in your environment, it will tell you when the queue last processed *anything*.

#### 2) Per-job (or per-recurring-task) last run
Solid Queue stores this in DB tables:
- `solid_queue_jobs` (has `class_name`, `created_at`, `finished_at`)
- `solid_queue_failed_executions` (job failures)
- `solid_queue_recurring_tasks` + `solid_queue_recurring_executions` (per recurring task key + intended `run_at`)

You can run this locally or in prod against the app DB:

**Per job class, last finished:**
```bash
bin/rails runner 'puts({
  "DailyPlaidSyncJob" => SolidQueue::Job.where(class_name: "DailyPlaidSyncJob").maximum(:finished_at),
  "SyncAllItemsJob" => SolidQueue::Job.where(class_name: "SyncAllItemsJob").maximum(:finished_at),
  "NullFieldDetectionJob" => SolidQueue::Job.where(class_name: "NullFieldDetectionJob").maximum(:finished_at),
  "HoldingsEnrichmentJob" => SolidQueue::Job.where(class_name: "HoldingsEnrichmentJob").maximum(:finished_at)
}.inspect)' 
```

**If recurring tasks are loaded into the DB (production typically):**
```bash
bin/rails runner 'SolidQueue::RecurringTask.order(:key).each do |t|
  last = SolidQueue::RecurringExecution.where(task_key: t.key).order(run_at: :desc).first
  job  = last && SolidQueue::Job.find_by(id: last.job_id)
  puts [t.key, t.schedule, (t.class_name || t.command), last&.run_at, job&.finished_at].join(" | ")
end'
```

**Important note about this repo right now:** when I queried the **local** DB, there were **no rows** in `SolidQueue::RecurringTask` yet, so local “last ran” for recurring tasks is empty until recurring tasks are loaded/seeded in that environment.

---

### One question so I can give you exact “last ran” times
Which environment do you want “last ran” for?
- development
- staging
- production

If you tell me which one (and how you connect—e.g., `kamal`/SSH/`DATABASE_URL`), I can give you the exact commands to run and what output to look for.