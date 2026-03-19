### Status
- Feature branch created: `epic-1-connect-buttons` (commit `b636827`)
- Epic-0 PRDs implemented: `0010` (Retry button), `0020` (Connect button copy), `0030` (Gate advisor chat)
- DB migration ran successfully and targeted tests passed.

### What was implemented (PRD-0010 thru PRD-0030)
#### PRD-0010 — Retry button for failed sync
- Added retry tracking columns to `plaid_items`: `retry_count`, `last_retry_at`.
- Added `PlaidItem#retry_allowed?` and `PlaidItem#sync_in_progress?` (proxy via recent `SyncLog` “started”).
- Added `POST /plaid_items/:id/retry` (`PlaidItemRetriesController#create`) scoped to `current_user`.
- Retry enqueues the existing sync jobs:
    - `SyncHoldingsJob`, `SyncTransactionsJob`, `SyncLiabilitiesJob`
- Cooldown + max retries enforced.

#### PRD-0020 — Connect button label/copy
- Built a real `/accounts/link` hub page (replacing the placeholder).
- Updated primary CTA to I18n-driven copy:
    - `accounts.link.primary_cta`: “Link Bank or Brokerage”
    - subtitle: “Securely connect via Plaid”

#### PRD-0030 — Gate advisor chat until a successful link exists
- Implemented gating in the user-facing chat surface (`/agent_hub`, persona `ai_financial_advisor`).
- Added cached advisor chat state (`5 minutes`) via `@advisor_chat_state`:
    - `:active` if any `PlaidItem.successfully_linked` exists
    - `:needs_link` for fresh users
    - `:degraded` if the user had any historical `SyncLog` success but no current good items
- Added placeholder UI with CTA to `/accounts/link` when gated.
- Added “first success” toast support:
    - `PlaidController#exchange` returns `first_success: true/false`
    - `/accounts/link` and `/dashboard` Plaid Link JS sets a one-time localStorage flag and shows the toast on next load.

### Files changed (high level)
- `db/migrate/20260123120700_add_retry_tracking_to_plaid_items.rb`
- `app/models/plaid_item.rb`
- `app/controllers/plaid_item_retries_controller.rb`
- `config/routes.rb`
- `app/views/accounts/link.html.erb`
- `config/locales/en.yml`
- `app/controllers/plaid_controller.rb`
- `app/controllers/agent_hubs_controller.rb`
- `app/views/agent_hubs/show.html.erb`
- `test/controllers/plaid_item_retries_controller_test.rb`

### Tests / verification
- Migration: `bin/rails db:migrate`
- Targeted tests executed and passing:
    - `bin/rails test test/controllers/plaid_item_retries_controller_test.rb`
    - `bin/rails test test/models/plaid_item_test.rb test/controllers/plaid_item_retries_controller_test.rb test/controllers/plaid_refreshes_controller_test.rb`

### Next step you need to do locally
- Push the branch (the push attempt was cancelled in this session):
  ```bash
  git push -u origin epic-1-connect-buttons
  ```
- Open a PR from `epic-1-connect-buttons` into `main/master` titled something like:
    - `Epic-0 PRD-0010..0030: Connect button, retry sync, advisor chat gating`

If you want, tell me whether your default branch is `main` or `master` and I’ll provide the exact PR base/compare and a ready-to-paste PR description.