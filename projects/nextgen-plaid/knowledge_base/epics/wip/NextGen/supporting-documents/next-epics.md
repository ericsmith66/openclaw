## Next Epics: Revised Stories & Future Work

Based on Eric's feedback (grok-eric-feedback.md) and initial review (feedback-v1.md), this document organizes all follow-up stories into revised PRDs for Epics 1-3 and future Epic 4.

---

## Epic 1 Revisions: Critical Additions & Updates

### PRD-1-11: Holdings Enrichment Fields (P0 BLOCKER)

**Overview**
Add `asset_class` and `sector` columns to Holdings model to enable Epic 2 snapshot aggregations (allocation, sector weights). Without these fields, Epic 2 PRD-2-03 and PRD-2-04 cannot function.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Migration: Add `asset_class:string` and `sector:string` to `holdings` table.
- Indexes: `add_index :holdings, :asset_class` and `add_index :holdings, :sector` for fast grouping.
- Validations: Optional fields (nil allowed until enriched).
- Integration: Populated by enrichment service (see PRD-1-13).

**Non-Functional**
- No data loss: Existing holdings unaffected (nullable fields).
- Performance: Indexed for group/sum queries in snapshots.

**Architectural Context**
- Rails: ActiveRecord migration, update Holding model.
- PostgreSQL: String columns with indexes.
- Dependencies: Epic 2 PRD-2-03/04 require these fields.

**Acceptance Criteria**
- Migration runs cleanly, adds columns with indexes.
- Holding.create with/without asset_class/sector succeeds.
- `Holding.group(:asset_class).sum(:institution_value)` works (Epic 2).
- Existing records remain valid (nil allowed).

**Test Cases**
- Migration spec: Reversible, creates columns/indexes.
- Model spec:
  ```ruby
  describe Holding do
    it "accepts asset_class and sector" do
      holding = create(:holding, asset_class: 'equity', sector: 'technology')
      expect(holding.reload.asset_class).to eq('equity')
    end
    it "allows nil enrichment fields" do
      holding = create(:holding, asset_class: nil, sector: nil)
      expect(holding).to be_valid
    end
  end
  ```

**Workflow**
- Pull master: `git pull origin main`
- Branch: `git checkout -b feature/prd-1-11-holdings-enrichment-fields`
- Use `rails g migration AddEnrichmentFieldsToHoldings asset_class:string sector:string`
- Ask questions (e.g., "Sector list? Fallback for unknown?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-1-12: Liabilities Model & Plaid Sync (NEW)

**Overview**
Create Liabilities model and sync job to fetch from Plaid `/liabilities/get`, enabling complete net worth calculations (assets - liabilities) in Epic 2 snapshots. Covers credit cards, mortgages, student loans.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Model: `Liability` (belongs_to :account, belongs_to :user; fields: `liability_type:string`, `current_balance:decimal`, `last_payment_date:date`, `next_payment_due_date:date`, `minimum_payment_amount:decimal`, `apr:decimal`, `is_overdue:boolean`).
- Migration: Create table with indexes on user_id, account_id, liability_type.
- Job: `SyncLiabilitiesJob` (calls Plaid `/liabilities/get`, upserts Liability records).
- Schedule: Via Solid Queue config/recurring.yml (daily at 3:05am, after accounts).
- Orchestration: Triggered by main sync job (Epic 1 PRD-1-06).

**Non-Functional**
- Idempotent: Safe rerun (upsert by account + liability_id).
- Error handling: Log Plaid errors, set account.last_sync_status = :error.

**Architectural Context**
- Rails: ActiveRecord model, Solid Queue job.
- Plaid: `/liabilities/get` endpoint.
- Dependencies: Account model (Epic 1 PRD-1-02).

**Acceptance Criteria**
- Migration creates liabilities table with correct fields/indexes.
- SyncLiabilitiesJob fetches and stores liability data from Plaid.
- Liability.total_for_user(user) returns sum of balances.
- Job handles no liabilities gracefully (empty array).
- Recurring config schedules job daily.

**Test Cases**
- Model spec:
  ```ruby
  describe Liability do
    it "calculates total balance" do
      create(:liability, user: user, current_balance: 5000)
      create(:liability, user: user, current_balance: 3000)
      expect(Liability.total_for_user(user)).to eq(8000)
    end
  end
  ```
- Job spec (VCR for Plaid):
  ```ruby
  describe SyncLiabilitiesJob do
    it "syncs liabilities from Plaid" do
      perform_enqueued_jobs { SyncLiabilitiesJob.perform_now(user) }
      expect(user.liabilities.count).to be > 0
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-1-12-liabilities-model-sync`
- Use `rails g model Liability user:references account:references liability_type:string current_balance:decimal ...`
- Use `rails g job sync_liabilities`
- Ask questions (e.g., "Plaid response structure? Upsert key?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-1-13: Enrichment Service with Tracking Fields (NEW)

**Overview**
Build EnrichmentService to populate holdings.asset_class, holdings.sector, and accounts.asset_strategy using Account Classifications mapping (from Eric's feedback). Add tracking fields (enriched_at:datetime, enrichment_source:string) to audit enrichment status.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Service: `EnrichmentService.enrich_holding(holding)` — maps holding.security_name or account name to asset_class/sector using lookup table or heuristics.
- Service: `EnrichmentService.enrich_account(account)` — maps account.type/subtype to asset_strategy using provided classifications (Eric's feedback).
- Tracking: Add `enriched_at:datetime` and `enrichment_source:string` to holdings and accounts tables.
- Job: `EnrichHoldingsJob` and `EnrichAccountsJob` (run after sync, before snapshot).
- Schedule: Via Solid Queue config/recurring.yml (daily at 3:10am).

**Non-Functional**
- Fast: < 1s per 100 holdings (in-memory lookup).
- Fallback: 'other'/'unknown' for unmapped items.

**Architectural Context**
- Rails: Service object (app/services/enrichment_service.rb), Solid Queue jobs.
- Data: Store Account Classifications as YAML or seed data (config/account_classifications.yml).
- Dependencies: Holding (PRD-1-11), Account (PRD-1-02).

**Acceptance Criteria**
- EnrichmentService maps known securities to correct asset_class/sector.
- EnrichmentService maps account types to asset_strategy.
- Tracking fields populated with timestamp and source ("plaid_type", "manual", "heuristic").
- Jobs run successfully on schedule.
- Unmapped items fall back to 'other'.

**Test Cases**
- Service spec:
  ```ruby
  describe EnrichmentService do
    it "enriches holding with asset_class" do
      holding = create(:holding, security_name: "AAPL")
      EnrichmentService.enrich_holding(holding)
      expect(holding.reload.asset_class).to eq('equity')
      expect(holding.sector).to eq('technology')
    end
    it "enriches account with asset_strategy" do
      account = create(:account, type: 'brokerage', subtype: 'taxable')
      EnrichmentService.enrich_account(account)
      expect(account.reload.asset_strategy).to match(/Taxable/)
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-1-13-enrichment-service`
- Create service: `mkdir -p app/services && touch app/services/enrichment_service.rb`
- Use `rails g migration AddEnrichmentTrackingToHoldings enriched_at:datetime enrichment_source:string`
- Use `rails g migration AddEnrichmentTrackingToAccounts enriched_at:datetime enrichment_source:string`
- Use `rails g job enrich_holdings` and `rails g job enrich_accounts`
- Ask questions (e.g., "Classification YAML structure? Heuristic rules?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-1-03 Update: Trust Model with EAS Values

**Changes**
- Update Trust model validations to use enum or validates_inclusion_of with Eric's values: `['SFRT', 'JSIT', 'QSIT', 'SFIT', 'SDIT']`.
- Migration adjustment:
  ```ruby
  create_table :trusts do |t|
    t.string :name, null: false
    t.string :trust_type, null: false # enum: SFRT, JSIT, QSIT, SFIT, SDIT
    t.text :details
    t.timestamps
  end
  add_index :trusts, :trust_type
  ```
- Add validations:
  ```ruby
  class Trust < ApplicationRecord
    TRUST_TYPES = %w[SFRT JSIT QSIT SFIT SDIT].freeze
    validates :trust_type, inclusion: { in: TRUST_TYPES }
  end
  ```

---

### PRD-1-04 & PRD-1-05 Consolidation

**Action**
- Remove duplicate PRD-1-12 (null detection) from Epic 1.
- Consolidate null detection logic into PRD-1-05 only.
- Update PRD-1-05 to output document to `knowledge_base/null_fields_report.md` (as noted in Eric's feedback).

---

### PRD-1-04 Move: OtherIncome to Epic 2

**Action**
- Remove OtherIncome model creation from Epic 1 PRD-1-04.
- Move to Epic 2 PRD-2-02 (Core Aggregates) as part of net worth calculation.
- Epic 1 PRD-1-04 becomes placeholder or removed.

---

## Epic 2 Revisions: Critical Corrections & Additions

### Global Updates Across All Epic 2 PRDs

**Position → Holding**
- Replace all references to `Position` with `Holding`.
- Replace `Position.current_value` with `Holding.institution_value`.
- Update all code snippets and examples.

**Sidekiq → Solid Queue**
- Replace all references to Sidekiq with Solid Queue.
- Update scheduling references: `config/recurring.yml` (not `config/sidekiq.yml`).
- Use `perform_later` (not `perform_async`).

**snapshot_at → snapshot_date**
- Change `snapshot_at:datetime` to `snapshot_date:date` in PRD-2-01.
- Update unique constraint: `user_id + snapshot_date` (not timestamp).
- Update scopes: `latest_for_user`, `for_date_range` to use date queries.

---

### PRD-2-01 Update: FinancialSnapshot Model with Date Field

**Changes**
- Migration:
  ```ruby
  create_table :financial_snapshots do |t|
    t.references :user, null: false, foreign_key: true
    t.date :snapshot_date, null: false
    t.jsonb :data, default: {}
    t.integer :status, default: 0 # enum: pending, complete, error
    t.timestamps
  end
  add_index :financial_snapshots, [:user_id, :snapshot_date], unique: true
  add_index :financial_snapshots, :data, using: :gin
  ```
- Scopes:
  ```ruby
  scope :latest_for_user, ->(user) { where(user: user).order(snapshot_date: :desc).first }
  scope :for_date_range, ->(user, start_date, end_date) {
    where(user: user, snapshot_date: start_date..end_date).order(:snapshot_date)
  }
  ```

---

### PRD-2-02 Update: Add OtherIncome to Core Aggregates

**Changes**
- Create OtherIncome model in this PRD (moved from Epic 1):
  ```ruby
  rails g model OtherIncome user:references name:string income_date:date projected_amount:decimal accrued_amount:decimal suggested_tax_rate:decimal
  ```
- Update FinancialSnapshotJob to include OtherIncome in net worth calculation:
  ```ruby
  total_net_worth = user.holdings.sum(:institution_value) +
                     user.accounts.sum(:available_balance) -
                     user.liabilities.sum(:current_balance) +
                     user.other_incomes.where('income_date <= ?', Date.today).sum(:accrued_amount)
  ```
- JSON structure:
  ```json
  {
    "total_net_worth": 26174695.59,
    "holdings_value": 25000000.00,
    "account_balances": 500000.00,
    "liabilities": -200000.00,
    "other_income": 874695.59,
    "delta_day": 124500.00,
    "delta_30d": -50000.00,
    "as_of": "2026-01-17"
  }
  ```

---

### PRD-2-03 Update: Asset Allocation with Value + Percent

**Changes**
- Update JSON structure to include both percentage and absolute value:
  ```json
  "asset_allocation": {
    "equity": { "percent": 0.62, "value": 16228311.38 },
    "fixed_income": { "percent": 0.18, "value": 4711685.21 },
    "cash": { "percent": 0.20, "value": 5234699.00 }
  }
  ```
- Update job logic:
  ```ruby
  total_value = user.holdings.sum(:institution_value)
  allocation = user.holdings.group(:asset_class).sum(:institution_value)
  data["asset_allocation"] = allocation.transform_values do |value|
    { "percent" => (value / total_value).round(4), "value" => value.round(2) }
  end
  ```

---

### PRD-2-04 Update: Sector Weights with Value + Percent

**Changes**
- Update JSON structure to include both percentage and absolute value:
  ```json
  "sector_weights": {
    "technology": { "percent": 0.28, "value": 7321314.19 },
    "healthcare": { "percent": 0.15, "value": 3925431.72 }
  }
  ```
- Update job logic:
  ```ruby
  equity_total = user.holdings.where(asset_class: 'equity').sum(:institution_value)
  sector_sums = user.holdings.where(asset_class: 'equity').group(:sector).sum(:institution_value)
  data["sector_weights"] = sector_sums.transform_values do |value|
    { "percent" => (value / equity_total).round(4), "value" => value.round(2) }
  end
  ```

---

### PRD-2-06 Update: Remove Historical Trends from JSON

**Changes**
- Remove `historical_net_worth` array from JSON (per Eric's feedback: query on-demand).
- Keep delta calculations using `last_30_days` scope:
  ```ruby
  prior_30d = user.financial_snapshots.where('snapshot_date = ?', 30.days.ago.to_date).first
  data["delta_30d"] = prior_30d ? (total_net_worth - prior_30d.data["total_net_worth"]) : 0
  ```
- Add note in PRD: Historical trends will be fetched on-demand in Epic 3 performance view.

---

### PRD-2-08: Liability Breakdown in Snapshots (NEW)

**Overview**
Extend FinancialSnapshotJob JSON to include liability breakdown by type (credit_card, mortgage, student_loan) for Epic 3 liabilities summary view.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Add to job: Group Liability.current_balance by liability_type.
- JSON:
  ```json
  "liabilities": {
    "total": 200000.00,
    "breakdown": {
      "mortgage": { "value": 150000.00 },
      "credit_card": { "value": 30000.00 },
      "student_loan": { "value": 20000.00 }
    }
  }
  ```
- Fallback: Empty breakdown if no liabilities.

**Non-Functional**
- Fast: < 1s addition to job runtime.

**Architectural Context**
- Rails: Update FinancialSnapshotJob.
- Dependencies: Liability model (Epic 1 PRD-1-12).

**Acceptance Criteria**
- JSON liability breakdown sums match total.
- Handles no liabilities (empty breakdown).
- Job runtime unchanged.

**Test Cases**
- Job spec:
  ```ruby
  it "includes liability breakdown" do
    create(:liability, user: user, liability_type: 'mortgage', current_balance: 150000)
    perform_enqueued_jobs { FinancialSnapshotJob.perform_now(user) }
    expect(snapshot.data["liabilities"]["breakdown"]["mortgage"]["value"]).to eq(150000.00)
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-08-liability-breakdown`
- Update job.
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-2-09: Snapshot Export API (NEW)

**Overview**
Add admin/user endpoint to export FinancialSnapshot JSON as downloadable file (JSON or CSV) for offline analysis/RAG ingestion.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Endpoint: `GET /snapshots/:id/export?format=json|csv` (user-owned or admin).
- JSON format: Return snapshot.data as `application/json` with filename `snapshot_YYYY-MM-DD.json`.
- CSV format: Flatten top-level keys + allocation/sector summaries as rows.
- Auth: User can export own snapshots; admin can export any.

**Non-Functional**
- Fast: < 500ms for typical snapshot.
- Content-Disposition header for download.

**Architectural Context**
- Rails: SnapshotsController#export action.
- Authorization: Pundit policy (user-owned or admin).

**Acceptance Criteria**
- User exports own snapshot as JSON/CSV.
- Admin exports any snapshot.
- Non-owner returns 403.
- CSV format includes key metrics (total_net_worth, deltas, allocation summary).

**Test Cases**
- Controller spec:
  ```ruby
  describe SnapshotsController do
    it "exports JSON for user" do
      get export_snapshot_path(snapshot, format: :json)
      expect(response.content_type).to eq('application/json')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end
    it "denies non-owner" do
      get export_snapshot_path(other_user_snapshot, format: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-2-09-snapshot-export`
- Use `rails g controller snapshots export`
- Ask questions (e.g., "CSV row structure? Include nested data?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

## Epic 3 Revisions: Additional UI & Integration PRDs

### Global Updates Across All Epic 3 PRDs

**Routing Update**
- Use nested namespace: `NetWorth::*` controllers/views.
- Routes:
  ```ruby
  namespace :net_worth do
    resource :dashboard, only: :show
    resources :allocations, only: :show
    resources :sectors, only: :show
    resources :performance, only: :show
    resources :holdings, only: :index
    resources :transactions, only: :index
    resources :liabilities, only: :index
  end
  ```

**Chart Library Decision**
- Per Eric's feedback: Use chartkick + groupdate gems for performance placeholder.
- Install: `bundle add chartkick groupdate`
- Add to layout: `<%= javascript_include_tag "chartkick", "Chart.bundle" %>`

---

### PRD-3-01 Update: Display Both Value + Percent in Net Worth Summary

**Changes**
- Update component to show both absolute and percentage deltas:
  ```erb
  <div class="badge badge-success">
    +$124,500 (0.48%)
  </div>
  ```
- JSON access:
  ```ruby
  delta_day = snapshot.data["delta_day"]
  delta_day_pct = (delta_day / snapshot.data["total_net_worth"]) * 100
  ```

---

### PRD-3-02 Update: Asset Allocation with Value + Percent Tooltips

**Changes**
- Update component to display both percent and value from nested JSON:
  ```erb
  <% allocation.each do |asset_class, data| %>
    <div class="progress-bar" style="width: <%= data['percent'] * 100 %>%;"
         title="<%= asset_class.titleize %>: <%= data['percent'] * 100 %>% ($<%= number_with_delimiter(data['value']) %>)">
    </div>
  <% end %>
  ```

---

### PRD-3-03 Update: Sector Weights with Value + Percent Tooltips

**Changes**
- Update component similarly to PRD-3-02:
  ```erb
  <% weights.each do |sector, data| %>
    <tr>
      <td><%= sector.titleize %></td>
      <td><%= number_to_percentage(data['percent'] * 100, precision: 2) %></td>
      <td>$<%= number_with_delimiter(data['value']) %></td>
    </tr>
  <% end %>
  ```

---

### PRD-3-04 Update: Use Chartkick for Performance Placeholder

**Changes**
- Update component to use chartkick:
  ```erb
  <%= line_chart @historical_data, library: {
    title: { text: 'Net Worth Trend (Last 30 Days)' },
    colors: ['#1f77b4']
  } %>
  ```
- Controller:
  ```ruby
  def show
    @historical_data = current_user.financial_snapshots
                                   .where('snapshot_date >= ?', 30.days.ago)
                                   .order(:snapshot_date)
                                   .pluck(:snapshot_date, Arel.sql("data->>'total_net_worth'"))
                                   .map { |date, value| [date, value.to_f] }
                                   .to_h
  end
  ```

---

### PRD-3-06: Holdings Summary View (NEW)

**Overview**
Build holdings list page showing top holdings table from snapshot JSON with expand/collapse for full list.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Controller: `NetWorth::HoldingsController#index`.
- View: Table with columns: Ticker, Name, Value, % Portfolio (from snapshot.data["top_holdings"]).
- Expand: "View All Holdings" button loads full Holdings.where(user: current_user).order(institution_value: :desc) via Turbo Frame.
- Empty state: "No holdings data" if nil.

**Non-Functional**
- Responsive: Table scrolls horizontally on mobile.
- Performant: Use snapshot JSON for top 10, query on expand only.

**Architectural Context**
- Rails: Controller + ViewComponent (HoldingsSummaryComponent).
- UI: `knowledge_base/UI/templates/table.md` for structure.

**Acceptance Criteria**
- Renders top 10 holdings from snapshot JSON.
- Expand button loads full list via Turbo Frame.
- % Portfolio sums to correct total.
- Handles no holdings (empty state).

**Test Cases**
- Controller spec:
  ```ruby
  describe NetWorth::HoldingsController do
    it "renders holdings summary" do
      get net_worth_holdings_path
      expect(response.body).to include("AAPL")
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-06-holdings-summary`
- Use `rails g controller net_worth/holdings index`
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-3-07: Transactions Summary View (NEW)

**Overview**
Build transactions summary page showing monthly income/expenses from snapshot JSON with link to full transaction list.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Controller: `NetWorth::TransactionsController#index`.
- View: Card with summary stats (income, expenses, top categories from snapshot.data["monthly_transaction_summary"]).
- Link: "View All Transactions" → full paginated Transaction list (Epic 4).
- Empty state: "No transaction data" if nil.

**Non-Functional**
- Responsive: Cards stack on mobile.

**Architectural Context**
- Rails: Controller + ViewComponent (TransactionsSummaryComponent).
- UI: `knowledge_base/UI/templates/general.md` for card layout.

**Acceptance Criteria**
- Renders income, expenses, top 5 categories from snapshot JSON.
- Link navigates correctly.
- Handles no transactions (empty state).

**Test Cases**
- Controller spec:
  ```ruby
  describe NetWorth::TransactionsController do
    it "renders transaction summary" do
      get net_worth_transactions_path
      expect(response.body).to include("Income")
      expect(response.body).to include("Expenses")
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-07-transactions-summary`
- Use `rails g controller net_worth/transactions index`
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-3-08: Snapshot Export Button (NEW)

**Overview**
Add "Export Snapshot" button to net worth dashboard linking to snapshot export endpoint (Epic 2 PRD-2-09).

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Button: In net_worth/show.html.erb, render button with dropdown for format (JSON/CSV).
- Link: `link_to "Export JSON", export_snapshot_path(@latest_snapshot, format: :json), class: "btn btn-ghost btn-sm"`.
- Placement: Top-right of dashboard (near refresh widget).

**Non-Functional**
- Download triggers immediately (no page navigation).

**Architectural Context**
- Rails: Simple link helper in view.
- Dependencies: Epic 2 PRD-2-09 (export endpoint).

**Acceptance Criteria**
- Button renders on dashboard.
- Click triggers download (JSON or CSV).
- Non-owner sees no button (or disabled).

**Test Cases**
- View spec:
  ```ruby
  it "renders export button" do
    render
    expect(rendered).to have_link("Export JSON")
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-08-export-button`
- Update net_worth/show.html.erb.
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-3-09: Refresh Snapshot / Sync Status Widget (NEW)

**Overview**
Add widget to dashboard showing last sync time and "Refresh" button to trigger new snapshot generation.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Widget: Component showing `@latest_snapshot.snapshot_date` + "Last synced X hours ago" + status badge.
- Refresh button: `button_to "Refresh", refresh_snapshot_path, method: :post, class: "btn btn-primary btn-sm"`.
- Endpoint: `POST /snapshots/refresh` → enqueues FinancialSnapshotJob.perform_later(current_user).
- Feedback: Turbo Stream replaces widget with "Refreshing..." spinner, then updated snapshot on completion.

**Non-Functional**
- Non-blocking: Button stays clickable (rate limit: max 1 refresh per 5 minutes).

**Architectural Context**
- Rails: SnapshotsController#refresh action.
- Turbo: Use Turbo Streams for async update.
- UI: `knowledge_base/UI/STYLE_GUIDE.md` for badge/button styles.

**Acceptance Criteria**
- Widget shows last sync time + status.
- Refresh button triggers job.
- Rate limiting prevents spam (flash message if <5min since last refresh).
- Turbo Stream updates widget on completion.

**Test Cases**
- Controller spec:
  ```ruby
  describe SnapshotsController do
    it "enqueues snapshot job on refresh" do
      expect {
        post refresh_snapshot_path
      }.to have_enqueued_job(FinancialSnapshotJob).with(current_user)
    end
    it "rate limits refresh" do
      post refresh_snapshot_path
      post refresh_snapshot_path
      expect(flash[:alert]).to include("Please wait")
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-09-refresh-widget`
- Use `rails g controller snapshots refresh`
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

## Epic 4: Future Enhancements (Deferred Stories)

### Epic 4 Overview

**Epic Title**: Advanced Features & Non-V1 Enhancements
**User Capabilities**: Curriculum integration, historical account change tracking, multi-user comparison, compliance/GDPR, architecture docs, multi-currency.
**Fit into Big Picture**: Post-V1 polish — enables deeper educational context, audit trails, collaboration features, and international expansion.

---

### PRD-4-01: Curriculum Integration (🔮 Future)

**Overview**
Link financial snapshots to curriculum modules (e.g., "Net Worth Module 1") for contextualized learning with live data.

**Scope**
- Add curriculum_module_id to snapshots (optional FK).
- Build curriculum module model/UI to display associated snapshots.

**Dependencies**
- Curriculum models (future epic).

---

### PRD-4-02: Historical Account Changes Tracking (🔮 Future)

**Overview**
Track changes to account.name, account.strategy, account.trust_id over time for audit trail and "what changed" views.

**Scope**
- Use PaperTrail gem or custom AccountChangeLog model.
- Admin view to list historical changes.

**Dependencies**
- Account model (Epic 1).

---

### PRD-4-03: Multi-User Snapshot Comparison (🔮 Future)

**Overview**
Allow admins to compare snapshots across users (anonymized) for cohort analysis.

**Scope**
- Admin-only comparison page with side-by-side charts.
- Privacy: Anonymize user names.

**Dependencies**
- Epic 2 snapshots, Epic 3 charts.

---

### PRD-4-04: Compliance & GDPR (🔮 Future)

**Overview**
Add data export/delete features for GDPR, audit logs for data access.

**Scope**
- User-initiated full data export (all snapshots, holdings, transactions).
- Data deletion flow with confirmation.
- Access log model.

**Dependencies**
- All models (Epic 1-3).

---

### PRD-4-05: Architecture Documentation (🔮 Future)

**Overview**
Generate architecture diagrams (ERD, data flow) from codebase using gems like rails-erd.

**Scope**
- Install rails-erd, configure for PNG/PDF output.
- Add to knowledge_base/architecture/.

**Dependencies**
- Stable schema (post-Epic 1-3).

---

### PRD-4-06: Multi-Currency Support (🔮 Future)

**Overview**
Support non-USD accounts with currency conversion and multi-currency net worth display.

**Scope**
- Add currency:string to accounts/holdings.
- Integrate exchange rate API (e.g., Open Exchange Rates).
- Snapshot JSON includes currency breakdown.

**Dependencies**
- Epic 2 snapshots.

---

## Summary of Priorities

**P0 (Blocking)**: Epic 1 PRD-1-11 (Holdings Enrichment Fields) — without this, Epic 2 cannot aggregate allocations/sectors.

**P1 (Critical)**:
- Epic 1 PRD-1-12 (Liabilities), PRD-1-13 (Enrichment Service)
- Epic 2 global updates (Position→Holding, Sidekiq→Solid Queue, snapshot_at→snapshot_date)
- Epic 2 PRD-2-02 update (OtherIncome)

**P2 (High)**:
- Epic 2 PRD-2-03/04 updates (value + percent)
- Epic 2 PRD-2-06 update (remove historical from JSON)
- Epic 2 PRD-2-08/09 (Liabilities breakdown, Export API)
- Epic 3 global updates (routing, chartkick)
- Epic 3 PRD-3-01 through PRD-3-05 updates

**P3 (Medium)**:
- Epic 3 PRD-3-06 through PRD-3-09 (new UI views)

**P4 (Low/Future)**:
- Epic 4 PRDs (curriculum, historical changes, comparison, compliance, docs, multi-currency)

---

**Next Steps**: Implement Epic 1 PRD-1-11 first (blocker), then sequence remaining P1/P2 PRDs. Questions?
