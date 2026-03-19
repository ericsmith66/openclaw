# Epic 2 Revisions: Critical Corrections & Additions

**Purpose**: This document contains ONLY the changes/additions needed for Epic 2 based on feedback review and Eric's responses.

---

## Global Corrections (Apply to ALL Epic 2 PRDs)

### 1. Position → Holding Terminology

**Issue**: Epic 2 references `Position` model, but actual model is `Holding`.

**Fix**: Replace ALL occurrences:
- `Position` → `Holding`
- `Position.current_value` → `Holding.institution_value`
- `user.positions` → `user.holdings`

**Rationale**: Position is deprecated (pre-Plaid naming). Holding is confirmed in schema.rb with `institution_value` field.

---

### 2. Sidekiq → Solid Queue

**Issue**: Epic 2 PRD-2-02 says "Sidekiq cron daily at midnight" and references `config/sidekiq.yml`.

**Fix**: Replace ALL occurrences:
- `Sidekiq` → `Solid Queue`
- `config/sidekiq.yml` → `config/recurring.yml`
- `perform_async` → `perform_later`
- Schedule via Solid Queue's recurring job configuration

**Rationale**: README confirms Solid Queue is the job processor. Use `config/recurring.yml` for scheduling.

**Example config/recurring.yml**:
```yaml
production:
  financial_snapshot:
    class: FinancialSnapshotJob
    queue: default
    schedule: "0 3 * * *" # 3am daily
```

---

### 3. snapshot_at:datetime → snapshot_date:date

**Issue**: PRD-2-01 uses `snapshot_at:datetime` which allows multiple snapshots per day if timestamps differ.

**Fix**:
- Change field to `snapshot_date:date` (not datetime)
- Update unique constraint to `user_id + snapshot_date`
- Update scopes to use date queries

**Rationale**: Per Eric's feedback, prefer date-based uniqueness. One snapshot per user per day.

**Updated Migration**:
```ruby
create_table :financial_snapshots do |t|
  t.references :user, null: false, foreign_key: true
  t.date :snapshot_date, null: false # CHANGED from snapshot_at:datetime
  t.jsonb :data, default: {}
  t.integer :status, default: 0 # enum: pending, complete, error
  t.timestamps
end
add_index :financial_snapshots, [:user_id, :snapshot_date], unique: true
add_index :financial_snapshots, :data, using: :gin
```

**Updated Scopes**:
```ruby
scope :latest_for_user, ->(user) { where(user: user).order(snapshot_date: :desc).first }
scope :for_date_range, ->(user, start_date, end_date) {
  where(user: user, snapshot_date: start_date..end_date).order(:snapshot_date)
}
```

---

## PRD-Specific Updates

### PRD-2-01 Update: FinancialSnapshot Model

**Changes**:
- Use `snapshot_date:date` instead of `snapshot_at:datetime`
- Update all acceptance criteria to reference `snapshot_date`
- Update test cases to use `snapshot_date: Date.today`

---

### PRD-2-02 Update: Core Aggregates + OtherIncome

**Critical Addition**: Move OtherIncome model creation HERE (from Epic 1 PRD-1-04) to resolve circular dependency.

**New Requirements**:

**Functional**
- Create OtherIncome model:
  ```ruby
  rails g model OtherIncome user:references name:string income_date:date projected_amount:decimal accrued_amount:decimal suggested_tax_rate:decimal
  ```
- Update net worth calculation to include OtherIncome:
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

**Changes to existing requirements**:
- Replace `Position.current_value` with `Holding.institution_value`
- Replace Sidekiq scheduling with Solid Queue (config/recurring.yml)
- Use `snapshot_date` not `snapshot_at`
- Add Liability.sum(:current_balance) subtraction (requires Epic 1 PRD-1-12)

---

### PRD-2-03 Update: Asset Allocation with Value + Percent

**Issue**: Epic 3 requires both percentage AND absolute dollar values for tooltips.

**Fix**: Store both in JSON structure:

**Updated JSON**:
```json
"asset_allocation": {
  "equity": { "percent": 0.62, "value": 16228311.38 },
  "fixed_income": { "percent": 0.18, "value": 4711685.21 },
  "cash": { "percent": 0.20, "value": 5234699.00 }
}
```

**Updated Job Logic**:
```ruby
total_value = user.holdings.sum(:institution_value)
allocation = user.holdings.group(:asset_class).sum(:institution_value)
data["asset_allocation"] = allocation.transform_values do |value|
  { "percent" => (value / total_value).round(4), "value" => value.round(2) }
end
```

**Additional Changes**:
- Replace `Position` with `Holding`
- Use `institution_value` not `current_value`
- Require Epic 1 PRD-1-11 (asset_class field on holdings)

---

### PRD-2-04 Update: Sector Weights with Value + Percent

**Issue**: Same as PRD-2-03 - need both percent and value.

**Fix**: Store both in JSON structure:

**Updated JSON**:
```json
"sector_weights": {
  "technology": { "percent": 0.28, "value": 7321314.19 },
  "healthcare": { "percent": 0.15, "value": 3925431.72 }
}
```

**Updated Job Logic**:
```ruby
equity_total = user.holdings.where(asset_class: 'equity').sum(:institution_value)
sector_sums = user.holdings.where(asset_class: 'equity').group(:sector).sum(:institution_value)
data["sector_weights"] = sector_sums.transform_values do |value|
  { "percent" => (value / equity_total).round(4), "value" => value.round(2) }
end
```

**Additional Changes**:
- Replace `Position` with `Holding`
- Require Epic 1 PRD-1-11 (sector field on holdings)

---

### PRD-2-05 Update: Holdings & Transactions Summary

**Changes**:
- Replace `Position` with `Holding`
- Use `institution_value` not `current_value`
- Update to: `Holding.order(institution_value: :desc).limit(10)`

---

### PRD-2-06 Update: Remove Historical Trends from JSON

**Issue**: Storing 30-day history in each snapshot creates duplication.

**Fix per Eric's feedback**: Remove `historical_net_worth` array from JSON. Let Epic 3 query on-demand.

**Updated Requirements**:

**Remove from JSON**:
- Delete `historical_net_worth` array from job logic

**Keep delta calculations**:
```ruby
# Delta calculations still work via scopes
prior_1d = user.financial_snapshots.where('snapshot_date = ?', 1.day.ago.to_date).first
data["delta_day"] = prior_1d ? (total_net_worth - prior_1d.data["total_net_worth"]) : 0

prior_30d = user.financial_snapshots.where('snapshot_date = ?', 30.days.ago.to_date).first
data["delta_30d"] = prior_30d ? (total_net_worth - prior_30d.data["total_net_worth"]) : 0
```

**Epic 3 Integration**:
- Epic 3 performance view will query `user.financial_snapshots.where('snapshot_date >= ?', 30.days.ago).order(:snapshot_date)` directly
- No duplication, same functionality

---

## New PRDs (Add to Epic 2)

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

## Updated Epic 2 PRD Priority Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 1 | FinancialSnapshot Model & Migration | Create model with **snapshot_date:date** (not datetime) | Existing models | feature/prd-2-01-snapshot-model | **UPDATED** |
| 2 | Daily FinancialSnapshotJob – Core Aggregates + OtherIncome | Job with Holding.institution_value + OtherIncome + Liabilities; **Solid Queue** scheduling | Epic 1 PRD-1-11, PRD-1-12; Epic 2 PRD-2-01 | feature/prd-2-02-snapshot-core | **UPDATED** |
| 3 | Snapshot – Asset Allocation Breakdown | Extend JSON with percent + value per class | PRD-2-02, Epic 1 PRD-1-11 | feature/prd-2-03-snapshot-allocation | **UPDATED** |
| 4 | Snapshot – Sector Weights | Add equity sector percent + value to JSON | PRD-2-03, Epic 1 PRD-1-11 | feature/prd-2-04-snapshot-sectors | **UPDATED** |
| 5 | Snapshot – Holdings & Transactions Summary | Include top holdings and transaction summaries | PRD-2-04 | feature/prd-2-05-snapshot-summaries | **UPDATED** |
| 6 | Snapshot – Historical Deltas (NO ARRAY IN JSON) | Delta calcs only; Epic 3 queries history on-demand | PRD-2-05 | feature/prd-2-06-snapshot-trends | **UPDATED** |
| 7 | Snapshot Validation & Admin Preview | Admin route to list/view/validate snapshots | PRD-2-06 | feature/prd-2-07-snapshot-validation | Unchanged |
| **8** | **Liability Breakdown in Snapshots (NEW)** | Add liability breakdown by type | Epic 1 PRD-1-12 | feature/prd-2-08-liability-breakdown | **NEW** |
| **9** | **Snapshot Export API (NEW)** | Export endpoint for JSON/CSV download | PRD-2-07 | feature/prd-2-09-snapshot-export | **NEW** |

---

## Summary of Changes

**Global Corrections**:
- Position → Holding (all PRDs)
- Sidekiq → Solid Queue (all PRDs)
- snapshot_at:datetime → snapshot_date:date (PRD-2-01)

**PRD Updates**:
- PRD-2-01: Use snapshot_date:date
- PRD-2-02: Add OtherIncome model + include in aggregates
- PRD-2-03: Store both percent + value for allocation
- PRD-2-04: Store both percent + value for sectors
- PRD-2-05: Update Holding references
- PRD-2-06: Remove historical_net_worth array from JSON

**New PRDs**:
- PRD-2-08: Liability Breakdown in Snapshots
- PRD-2-09: Snapshot Export API

**Key Decisions**:
- One snapshot per user per day (date-based uniqueness)
- Historical trends: query on-demand, not stored in JSON
- OtherIncome moved to Epic 2 (from Epic 1)
- Both percentage and absolute values in allocation/sector JSON
- All currency is USD for V1
