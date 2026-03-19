### Epic 2: Build JSON Snapshots to Support Net Worth Dashboards

**Epic Overview**  
Implement daily/periodic FinancialSnapshotJob that exports structured JSON blobs capturing net worth, period-over-period changes, asset allocation breakdowns, and key aggregates from synced Plaid data. Adjusted for expanded v1 pages (net worth dashboard, asset allocation, sector weights, performance placeholder, holdings/transactions/liabilities summaries, curriculum/AI context). Epic 2 PRDs 2-03 through 2-05 assume SecurityEnrichment columns from Epic 1 PRD-0170 v2 are live; use fallback to `holding.sector` or `data` JSON until then. Introduce Reporting::DataProvider service to centralize query logic, starting minimal for aggregates; confine Arel usage here for composability (e.g., dynamic groups/filters in future). This promotes reusable patterns without overbuilding v1.

**User Capabilities**  
Interns download/export personal snapshots; advisors (AI) ingest snapshots as RAG context for queries; admins preview/validate snapshot generation.

**Fit into Big Picture**  
Turns raw syncs into portable, queryable financial context — essential for curriculum modules on net worth tracking, allocation drift, and historical performance without real-time computation overload. DataProvider enables evolution to grouped/shared accounts and BI exports.

**Target Snapshot JSON Structure v1**
```json
{
  "schema_version": 1,
  "as_of": "2026-01-24",
  "total_net_worth": 2500000.00,
  "delta_day": 5000.00,
  "delta_30d": 15000.00,
  "asset_allocation": {
    "equity": 0.62,
    "fixed_income": 0.18,
    "cash": 0.15,
    "alternative": 0.05
  },
  "sector_weights": {
    "technology": 0.28,
    "healthcare": 0.15,
    "financials": 0.12,
    "unknown": 0.45
  },
  "top_holdings": [
    {"ticker": "AAPL", "name": "Apple Inc.", "value": 300000.00, "pct_portfolio": 0.12},
    {"ticker": "MSFT", "name": "Microsoft Corp.", "value": 250000.00, "pct_portfolio": 0.10}
  ],
  "monthly_transaction_summary": {
    "income": 10000.00,
    "expenses": 5000.00,
    "top_categories": [{"category": "Salary", "amount": 8000.00}, {"category": "Rent", "amount": -2000.00}]
  },
  "historical_net_worth": [
    {"date": "2026-01-23", "value": 2495000.00},
    {"date": "2025-12-25", "value": 2485000.00}
  ],
  "data_quality": {
    "score": 95,
    "warnings": ["Missing price for 2 holdings", "Stale sync detected"]
  },
  "disclaimer": "Educational simulation only – not financial advice"
}
```
Reference this structure in all subsequent PRDs for JSON extensions.

**PRD Summary Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |  
|----------|-----------|-------|--------------|------------------|  
| 0 | Dashboard Wireframe Scaffold | Setup POC layout with feature flag, routes, placeholders. | None | feature/prd-2-00-dashboard-scaffold |  
| 1 | FinancialSnapshot Model & Migration | Create model for storing daily JSON snapshots. | #0 | feature/prd-2-01-snapshot-model |  
| 1b | Reporting DataProvider Service Scaffold | Minimal service for centralized aggregates, with optional Arel for composability. | #1 | feature/prd-2-01b-data-provider |  
| 2 | Daily FinancialSnapshotJob – Core Aggregates | Job to compute and store basic net worth JSON with deltas, using DataProvider. | #1b | feature/prd-2-02-snapshot-core |  
| 3 | Snapshot – Asset Allocation Breakdown | Extend JSON with asset class percentages via DataProvider. | #2 | feature/prd-2-03-snapshot-allocation |  
| 4 | Snapshot – Sector Weights | Add equity sector weight percentages to JSON via DataProvider. | #3 | feature/prd-2-04-snapshot-sectors |  
| 5 | Snapshot – Holdings & Transactions Summary | Include top holdings and monthly transaction summaries in JSON via DataProvider. | #4 | feature/prd-2-05-snapshot-summaries |  
| 6 | Snapshot – Historical Deltas & Trend Support | Add historical net worth array for trends via DataProvider. | #5 | feature/prd-2-06-snapshot-trends |  
| 7 | Snapshot Validation & Admin Preview | Admin route to list/view/validate snapshots, leveraging DataProvider for checks. | #6 | feature/prd-2-07-snapshot-validation |  
| 8 | Snapshot Export API | API for downloading snapshots and RAG context, with DataProvider exports. | #7 | feature/prd-2-08-snapshot-export |  
| 9 | Net Worth Dashboard Layout | Implement dashboard UI using snapshots via DataProvider. | #0 + #2 | feature/prd-2-09-dashboard-layout |

### PRD-2-00: Dashboard Wireframe Scaffold
**Overview**  
Create a POC dashboard scaffold with feature flag for gradual rollout, including authenticated layout, canonical routes, and placeholders for net worth pages. This provides early visibility and unblocks UI testing without full data.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Feature flag: `ENABLE_NEW_LAYOUT` (true in dev/staging, ENV-controlled in prod). Use to toggle between POC application layout and new authenticated layout.
- Layout: `layouts/authenticated.html.erb` with grid (sidebar + main content). Sidebar: `w-72` width, nav links to placeholders.
- Routes: `/net_worth/dashboard` (canonical, redirect from `/dashboard`), placeholders for `/transactions/regular`, `/investment`.
- Placeholders: Simple centered text (e.g., "Net Worth Dashboard Coming Soon" in large gray font).
- Icons: Use Heroicons v2 (add `gem 'heroicon'` if missing).
- Error: `app/components/errors/forbidden_component.rb` for 403 (alert-error div with "Forbidden: You do not have permission to access this area.").

**Non-Functional**
- Tailwind/DaisyUI: Follow `knowledge_base/UI/STYLE_GUIDE.md`.
- Privacy: Devise auth required.

**Architectural Context**
- Rails MVC: Layouts only; no models/jobs.
- Integration: Prepares for Epic 3 UI; flag allows owner → beta → all rollout.
- Reference: `knowledge_base/UI/templates/general.md`.

**Acceptance Criteria**
- Flag true shows new layout with sidebar.
- Flag false falls back to POC.
- `/net_worth/dashboard` renders placeholder.
- Non-auth: Redirects to login.
- Forbidden component renders on unauthorized access.
- Heroicons integrated (e.g., sample icon in sidebar).

**Test Cases**
- Application spec (RSpec):
```ruby
describe "Dashboard scaffold" do  
  it "renders new layout with flag on" do  
    with_env("ENABLE_NEW_LAYOUT" => "true") { get net_worth_dashboard_path }  
    expect(response.body).to include("w-72")  
  end  
end  
```  

**Workflow**
- Pull from master: `git pull origin main`
- Create branch: `git checkout -b feature/prd-2-00-dashboard-scaffold`
- Use `rails g component errors/forbidden`
- Ask questions and build a plan before execution (e.g., "Confirm flag ENV name? Sidebar links?").
- Commit only green code (tests pass).
- Default LLM: Claude Sonnet 4.5 in RubyMine.

### PRD-2-01: FinancialSnapshot Model & Migration
**Overview**  
Create FinancialSnapshot model to store daily JSON blobs per user, serving as the primary data source for Epic 3 UI components like net worth totals and allocation breakdowns. This establishes the foundation for all subsequent snapshot aggregations.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Model: `FinancialSnapshot` with associations (`belongs_to :user`), columns: `snapshot_at:datetime` (unique per user/day, use Time.zone for CST/'America/Chicago'), `data:jsonb` (for aggregates), `status:enum` (:pending, :complete, :error, :stale), `schema_version:integer` (presence true, inclusion 1..2).
- Migration: Add table with indexes on `user_id`, `snapshot_at` (composite unique), and GIN on `data`.
- Basic scopes: `latest_for_user(user)`, `for_date_range(user, start_date, end_date)`.
- Data quality: Model methods `data_quality_score` (e.g., 100 - warnings.count * 5), `warnings` (array in data).

**Non-Functional**
- JSONb optimized for quick reads (Epic 3 UI will query `data` directly).
- Privacy: RLS policy — users see only own snapshots.
- No job yet — just storage setup.

**Architectural Context**
- Rails MVC: Model only (no controller/view in this PRD).
- PostgreSQL: Use JSONb for flexible structure (reference Target Snapshot JSON Structure v1).
- Integration: Future job will populate; assume synced data in Position/Account/etc. models.
- Reference: No UI, but future admin previews follow `knowledge_base/UI/STYLE_GUIDE.md` and `knowledge_base/UI/templates/general.md`.

**Acceptance Criteria**
- Running migration creates `financial_snapshots` table with correct columns/indexes.
- `FinancialSnapshot.create(user: user, snapshot_at: Date.today.in_time_zone('America/Chicago'), data: {}, schema_version: 1)` succeeds, enforces unique per user/day.
- Scope `FinancialSnapshot.latest_for_user(user)` returns most recent snapshot.
- RLS: Non-owner user query raises error or returns empty.
- Enum status defaults to :pending.
- JSONb field accepts hash and stores correctly.
- schema_version validates inclusion.
- data_quality_score calculates based on warnings.

**Test Cases**
- Model spec (RSpec):
```ruby
describe FinancialSnapshot do  
  it "validates unique snapshot_at per user" do  
    snapshot1 = create(:financial_snapshot, user: user, snapshot_at: Date.today)  
    expect { create(:financial_snapshot, user: user, snapshot_at: Date.today) }.to raise_error(ActiveRecord::RecordNotUnique)  
  end  
  it "stores jsonb data" do  
    snapshot = create(:financial_snapshot, data: { total_net_worth: 1000000.0 }, schema_version: 1)  
    expect(snapshot.reload.data["total_net_worth"]).to eq(1000000.0)  
  end  
  it "validates schema_version" do  
    expect { create(:financial_snapshot, schema_version: 3) }.to raise_error(ActiveRecord::RecordInvalid)  
  end  
end  
```  
- Migration spec: Reversible, creates indexes.

**Workflow**
- Pull from master: `git pull origin main`
- Create branch: `git checkout -b feature/prd-2-01-snapshot-model`
- Use `rails g model FinancialSnapshot user:references snapshot_at:datetime data:jsonb status:integer schema_version:integer` then adjust.
- Ask questions and build a plan before execution (e.g., "Confirm enum values? Index details? Timezone handling?").
- Commit only green code (tests pass).
- Default LLM: Claude Sonnet 4.5 in RubyMine.

### PRD-2-01b: Reporting DataProvider Service Scaffold
**Overview**  
Implement minimal Reporting::DataProvider service to centralize aggregate queries for snapshots, promoting reusable patterns. Confine Arel usage here for composability (e.g., dynamic sums/groups); start simple for v1 single-user, with hooks for future groups/sharing/security.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Service: `Reporting::DataProvider.new(user)` with methods like `core_aggregates` (returns hash for total_net_worth, deltas), using AR scopes primarily; optional Arel for merges (e.g., base_query = Position.arel_table; query.project(Arel.sql('SUM(current_value)'))).
- Chainable: e.g., `provider.with_filters(params).build`.
- Security: Basic user scoping (e.g., user.positions); hooks for future Pundit/authorize!.
- Exports: Stub `to_json`, `to_csv` for BI (e.g., Tableau).

**Non-Functional**
- Performant: Memoize results; <2s overhead.
- Composable: Design for AI-coder extension (mix-ins like GroupFilter).
- Idempotent: Pure queries, no side effects.

**Architectural Context**
- Rails: Plain Ruby class in app/services/reporting/; integrate with jobs/controllers.
- PostgreSQL: Leverage indexes; Arel for dynamic if AR limits hit.
- Integration: Used in job for JSON; assumes synced models.
- Reference: Follow Rails service patterns; no UI.

**Acceptance Criteria**
- `DataProvider.new(user).core_aggregates` returns expected hash (matches direct AR sums).
- Arel optional: Works without for v1; merge example in tests.
- Handles no data (empty hashes).
- Security: Scopes to user only.
- Export stubs return formatted data.
- Runtime <5s including mocks.

**Test Cases**
- Service spec (RSpec):
```ruby
describe Reporting::DataProvider do  
  let(:provider) { described_class.new(user) }  
  it "computes core aggregates" do  
    # Seed data  
    expect(provider.core_aggregates[:total_net_worth]).to eq(expected_sum)  
  end  
  it "uses Arel for composability" do  
    # Example merge test  
  end  
end  
```  

**Workflow**
- Pull from master: `git pull origin main`
- Create branch: `git checkout -b feature/prd-2-01b-data-provider`
- Manually create app/services/reporting/data_provider.rb.
- Ask questions and build a plan before execution (e.g., "Pros/cons of Arel vs pure AR here? Interface for chainable methods? Future group hooks? Weigh in on minimal vs full composability for v1.").
- Commit only green code (tests pass).
- Default LLM: Claude Sonnet 4.5 in RubyMine.

### PRD-2-02: Daily FinancialSnapshotJob – Core Aggregates
**Overview**  
Implement FinancialSnapshotJob to run daily, computing core net worth aggregates (total, deltas) via DataProvider and storing as JSON in FinancialSnapshot.data. This powers Epic 3 net worth hero card and changes.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Job: `FinancialSnapshotJob.perform_later(user)` — uses DataProvider to compute `total_net_worth` (sum Position.current_value + Account.balances - Liability.balances), `delta_day` (diff vs. previous snapshot, fallback to nearest if exact missing, preserve sign), `delta_30d` (diff vs. 30 days ago), `as_of` (current date in CST).
- JSON structure: Reference Target Snapshot JSON Structure v1.
- Schedule: Sidekiq cron daily at midnight (config/sidekiq.yml).
- Handle no prior snapshots: deltas = 0.
- Error handling: rescue_from StandardError → update status: :error, data: { error: e.message }, log error; optional email/in-app notify; retry: 3 attempts with exponential backoff.

**Non-Functional**
- Performant: < 5s per user (aggregate queries only); batch for multi-user.
- Idempotent: Safe rerun if snapshot exists (update if status :error).
- Logging: Error if sync stale (e.g., last_sync_at > 24h, set :stale).

**Architectural Context**
- Rails: Sidekiq job, use DataProvider for sums (e.g., provider.core_aggregates).
- PostgreSQL: JSONb for data; query latest via scopes.
- Integration: Assumes synced data; no Plaid calls here.
- Reference: No UI; follows `knowledge_base/UI/STYLE_GUIDE.md` principles for simplicity.

**Acceptance Criteria**
- Job creates snapshot with correct total_net_worth (matches model sums via DataProvider).
- Delta_day accurate vs. previous (or nearest).
- Delta_30d = 0 if no 30-day prior; correct diff otherwise.
- Cron entry in sidekiq.yml schedules daily.
- Job logs error if no recent sync, sets :stale.
- Rerun on existing date updates JSON without duplicate.
- Retry handles transient errors (e.g., DB timeout).
- Assumes Position/Account models have valid data from prior syncs — fails explicitly if sums return nil/zero unexpectedly.

**Test Cases**
- Job spec (RSpec):
```ruby
describe FinancialSnapshotJob do  
  it "computes and stores core aggregates" do  
    # Seed positions/accounts/liabilities  
    perform_enqueued_jobs { FinancialSnapshotJob.perform_now(user) }  
    snapshot = user.financial_snapshots.last  
    expect(snapshot.data["total_net_worth"]).to eq(expected_sum)  
  end  
  it "handles deltas with previous" do  
    # Create prior snapshot  
    perform_enqueued_jobs { FinancialSnapshotJob.perform_now(user) }  
    expect(snapshot.data["delta_day"]).to eq(diff_value)  
  end  
  it "retries on error" do  
    # Simulate error, check retries  
  end  
end  
```  
- Use FactoryBot for seeding, timecop for dates.

**Workflow**
- Pull from master: `git pull origin main`
- Create branch: `git checkout -b feature/prd-2-02-snapshot-core`
- Use `rails g job financial_snapshot`
- Ask questions and build a plan (e.g., "Exact delta calc logic? Handle negative NW? Notify mechanism? Arel needed for deltas in DataProvider? Weigh in on service interface for this.").
- Commit only green code.
- Default LLM: Claude Sonnet 4.5 in RubyMine.

### PRD-2-03: Snapshot – Asset Allocation Breakdown
**Overview**  
Extend FinancialSnapshotJob JSON with asset allocation percentages by class (e.g., equities, fixed income) from Position data via DataProvider. This directly feeds Epic 3 asset allocation page pie/bar components.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Add to job/DataProvider: Group Position.current_value by asset_class (e.g., 'equity', 'fixed_income', 'cash', 'alternative').
- JSON: Reference Target Snapshot JSON Structure v1 (decimals 0–1, sum ≈1, tolerance 0.01).
- Fallback: 'other' for uncategorized; use holding.data JSON if SecurityEnrichment missing.

**Non-Functional**
- Accurate to 2 decimals; handle zero positions (empty hash).

**Architectural Context**
- Rails: Update job/DataProvider to use Position.group(:asset_class).sum(:current_value); Arel if composable needed.
- Assume asset_class populated (from sync/enrichment); fallback logic.
- Reference: No UI.

**Acceptance Criteria**
- JSON asset_allocation sums to ~1.0.
- Matches Position aggregates.
- Handles no positions (empty or all 'other': 0).
- Job runtime unchanged (<5s).
- Fallback used if enrichment columns nil.

**Test Cases**
- Job spec:
```ruby
it "includes asset allocation" do  
  # Seed positions with classes  
  perform_enqueued_jobs { FinancialSnapshotJob.perform_now(user) }  
  expect(snapshot.data["asset_allocation"]["equity"]).to eq(0.62)  
end  
```  

**Workflow**
- Pull from master: `git pull origin main`
- Create branch: `git checkout -b feature/prd-2-03-snapshot-allocation`
- Update existing job/DataProvider.
- Ask questions (e.g., "Asset class list? Round to 2 decimals? Fallback details? Arel for groups in service? Weigh in on composability.").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-2-04: Snapshot – Sector Weights
**Overview**  
Add equity sector weights to FinancialSnapshotJob JSON via DataProvider, powering Epic 3 sector weights page.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Group Position (equity only) by sector, sum value, normalize to % of equities total.
- JSON: Reference Target Snapshot JSON Structure v1.
- Fallback: 'unknown' bucket; use holding.data if enrichment missing.

**Non-Functional**
- Only equities; 0 if none.

**Architectural Context**
- Rails: DataProvider.where(asset_class: 'equity').group(:sector).sum(:current_value); Arel optional.
- Assume sector populated; fallback.

**Acceptance Criteria**
- Sector weights sum ~1.0 (equities portion).
- Matches equity aggregates.
- Empty if no equities.
- Fallback handles missing enrichment.

**Test Cases**
- Job spec:
```ruby
it "includes sector weights" do  
  # Seed equity positions with sectors  
  perform_enqueued_jobs { FinancialSnapshotJob.perform_now(user) }  
  expect(snapshot.data["sector_weights"]["technology"]).to eq(0.28)  
end  
```  

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-04-snapshot-sectors`
- Update job/DataProvider.
- Ask questions (e.g., "Sector list? Handle unknown? Arel merge in service? Weigh in on equity filter.").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-2-05: Snapshot – Holdings & Transactions Summary
**Overview**  
Extend JSON with top holdings summary and monthly transaction aggregates for Epic 3 holdings/transactions previews via DataProvider.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Top holdings: Top 10 by value [{ticker, name, value, pct_portfolio}].
- Transactions: {income, expenses, top_categories: [{cat, amount}]} (last 30 days).
- JSON: Reference Target Snapshot JSON Structure v1.
- Fallback: Use raw Position/Transaction data if enrichment missing.

**Non-Functional**
- Limit summaries to avoid large JSON (top 10/5).

**Architectural Context**
- Rails: DataProvider.order(current_value: :desc).limit(10), Transaction.last_30_days.group(:category).sum(:amount); Arel optional.
- Use scopes; fallback.

**Acceptance Criteria**
- Top holdings sorted descending, pct_portfolio correct.
- Transaction summary income/expenses match sums.
- Handles no data (empty array/hash).
- Fallback for missing names/categories.

**Test Cases**
- Job spec:
```ruby
it "includes summaries" do  
  # Seed data  
  perform_enqueued_jobs { FinancialSnapshotJob.perform_now(user) }  
  expect(snapshot.data["top_holdings"].size).to eq(10)  
end  
```  

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-05-snapshot-summaries`
- Update job/DataProvider.
- Ask questions (e.g., "Top N? Categories? Fallback? Arel for limits in service? Weigh in on transaction scopes.").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-2-06: Snapshot – Historical Deltas & Trend Support
**Overview**  
Add historical net worth array to JSON for Epic 3 performance placeholder trends via DataProvider.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- On job run, fetch last 30 snapshots, add "historical_net_worth": [{date: "YYYY-MM-DD", value: decimal}, ...] (sorted asc).
- Use for delta calcs if not already.
- Note: Accept no historical data for first 30 days. Backfill deferred to future epic.

**Non-Functional**
- Limit to 30 days to keep JSON small.

**Architectural Context**
- Rails: DataProvider.user.financial_snapshots.last_30_days.pluck(:snapshot_at, "data->>'total_net_worth'"); Arel optional.
- Store in data JSON; reference Target Snapshot JSON Structure v1.

**Acceptance Criteria**
- Historical array has up to 30 entries, sorted asc.
- Values match prior snapshots.
- Empty if no history.

**Test Cases**
- Job spec:
```ruby
it "includes historical trends" do  
  # Create priors  
  perform_enqueued_jobs { FinancialSnapshotJob.perform_now(user) }  
  expect(snapshot.data["historical_net_worth"].size).to eq(3) # e.g.  
end  
```  

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-06-snapshot-trends`
- Update job/DataProvider.
- Ask questions (e.g., "30 days limit? Include deltas here? Arel for plucks in service? Weigh in on history query.").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-2-07: Snapshot Validation & Admin Preview
**Overview**  
Add admin-only route to list/view snapshots and basic validation (e.g., sums check) for debugging before Epic 3, leveraging DataProvider.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Controller: Admin::SnapshotsController (index: list recent 50, show: pretty JSON).
- Validation: On job save, use DataProvider to check allocation sum ≈1 (tolerance 0.01), nw > -10M, set status; display score/warnings in preview.
- Route: `/admin/snapshots`, `/admin/snapshots/:id`.
- Auth: `before_action :require_admin!` (e.g., user.admin? or email list).

**Non-Functional**
- Pretty print: JSON.pretty_generate in prose block.
- Table: Use `table table-zebra` for index.

**Architectural Context**
- Rails: Admin namespace, simple controller; DataProvider for validation logic.
- Privacy: Admin only.
- Reference: Use `knowledge_base/UI/templates/table.md` for index table, `knowledge_base/UI/STYLE_GUIDE.md` for business theme.

**Acceptance Criteria**
- /admin/snapshots shows table with user, date, status badge, nw preview, quality score.
- /admin/snapshots/:id shows pretty JSON.
- Non-admin: 403 with forbidden component.
- Validation sets status correctly (e.g., sum off = :warning).
- Index paginates if >50.

**Test Cases**
- Controller spec:
```ruby
describe Admin::SnapshotsController do  
  it "indexes recent snapshots" do  
    get admin_snapshots_path  
    expect(response.body).to include("Snapshots")  
  end  
  it "shows pretty JSON" do  
    get admin_snapshot_path(snapshot)  
    expect(response.body).to include(JSON.pretty_generate(expected))  
  end  
end  
```  

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-07-snapshot-validation`
- Use `rails g controller admin/snapshots index show`
- Ask questions (e.g., "Admin check method? Validation rules? Arel in DataProvider validation? Weigh in on quality display.").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-2-08: Snapshot Export API
**Overview**  
Implement API endpoints for exporting snapshots as JSON, including sanitized RAG context for AI ingestion, using DataProvider exports. This enables intern downloads and AI curriculum queries.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Routes: `/api/snapshots/:id/download` (full JSON, user-owned only), `/api/snapshots/:id/rag_context` (sanitized, compact JSON: user_id_hash SHA256, strip sensitive fields like account numbers, add warnings).
- JSON: Reference Target Snapshot JSON Structure v1; use DataProvider.to_json for formatting; send_data for download (filename: "financial-snapshot-#{snapshot.snapshot_at}.json").
- BI stub: Add DataProvider.to_tableau_json (e.g., flattened hash for easy import).

**Non-Functional**
- Auth: User for download, admin/AI for RAG.
- Performant: Quick response (<1s).

**Architectural Context**
- Rails: API namespace controller, use existing model/DataProvider.
- Integration: For RAG (Ollama context); Arel optional in provider exports if needed.
- Privacy: Sanitize for portability.

**Acceptance Criteria**
- /api/snapshots/:id/download returns full JSON if owned.
- /api/snapshots/:id/rag_context returns sanitized (e.g., no full IDs).
- Non-owner: 403.
- Filename correct.
- BI stub formats correctly (e.g., flat keys for Tableau).

**Test Cases**
- API spec:
```ruby
describe "Snapshot Export API" do  
  it "downloads full JSON" do  
    get api_snapshot_download_path(snapshot)  
    expect(response.body).to eq(JSON.pretty_generate(snapshot.data))  
  end  
end  
```  

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-08-snapshot-export`
- Use `rails g controller api/snapshots download rag_context`
- Ask questions (e.g., "Sanitization fields? API auth? Arel in exports? Weigh in on BI formats.").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-2-09: Net Worth Dashboard Layout
**Overview**  
Implement the net worth dashboard UI using snapshot data, integrating placeholders from PRD-2-00 with real aggregates via DataProvider. This delivers the v1 user-facing pages.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions. In the log, put detailed steps for human to manually test and what the expected results.

**Requirements**  
**Functional**
- Controller: NetWorth::DashboardController (index: fetch latest snapshot via DataProvider, render hero card with total/deltas, pie for allocation, etc.).
- Components: ViewComponent for cards/charts (e.g., NetWorthHeroComponent).
- Routes: Build on PRD-2-00.
- Data: Query FinancialSnapshot.latest_for_user(current_user).data or DataProvider.build_snapshot_hash.

**Non-Functional**
- UI: Tailwind/DaisyUI, professional for 22-30 audience.
- Performant: No real-time calcs; JSON direct.

**Architectural Context**
- Rails MVC: Controller + ViewComponents; DataProvider for data.
- Integration: Uses snapshot JSON; reference Target Snapshot JSON Structure v1.
- Reference: `knowledge_base/UI/templates/general.md`.

**Acceptance Criteria**
- Dashboard renders total_net_worth, deltas from snapshot/DataProvider.
- Allocation pie matches JSON.
- Feature flag gates access.
- Handles no snapshot (placeholder).
- Capybara: Basic smoke test.

**Test Cases**
- Feature spec (Capybara):
```ruby
describe "Net Worth Dashboard" do  
  it "displays aggregates" do  
    visit net_worth_dashboard_path  
    expect(page).to have_content("Total Net Worth: $2,500,000")  
  end  
end  
```  

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-09-dashboard-layout`
- Use `rails g controller net_worth/dashboard`
- Ask questions (e.g., "Chart lib? Component breakdown? Arel in DataProvider for UI? Weigh in on query reuse.").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

Next steps: Commit UI guide/templates to knowledge_base/UI/. Then implement Epic 2 PRDs sequentially. Questions: Confirm validation thresholds (e.g., sum tolerance 0.01)? Add download JSON button? Go-live target date? Expected initial user count?