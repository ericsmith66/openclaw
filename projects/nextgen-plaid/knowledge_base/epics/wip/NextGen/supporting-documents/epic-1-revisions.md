# Epic 1 Revisions: Critical Additions & Corrections

**Purpose**: This document contains ONLY the changes/additions needed for Epic 1 based on feedback review and Eric's responses.

---

## Critical New PRDs (Must Add to Epic 1)

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

## Updates to Existing PRDs

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

### PRD-1-04 & PRD-1-05 & PRD-1-12 Consolidation

**Action**
- Remove duplicate PRD-1-12 (null detection) from Epic 1.
- Consolidate null detection logic into PRD-1-05 only.
- Update PRD-1-05 to:
  - Output document to `knowledge_base/null_fields_report.md`
  - Make institution-aware by logging null patterns keyed on `PlaidItem.institution_id`
  - Scan Holdings, Transactions, and Liabilities models

---

### PRD-1-04 Update: Remove OtherIncome (Moved to Epic 2)

**Action**
- Remove OtherIncome model creation from Epic 1 PRD-1-04.
- OtherIncome has been moved to Epic 2 PRD-2-02 (Core Aggregates) as part of net worth calculation.
- Keep PRD-1-04 stub as placeholder or remove entirely.

---

## Account Classifications Reference Data

Per Eric's feedback, use these mappings for enrichment (PRD-1-13):

```yaml
# config/account_classifications.yml
classifications:
  - asset_strategy: "Asia ex-Japan Equity"
    asset_class: "Equity"
    asset_strategy_detail: "Core"
  - asset_strategy: "Cash & Short Term"
    asset_class: "Fixed Income & Cash"
    asset_strategy_detail: "Short Term"
  - asset_strategy: "Cash & Short Term"
    asset_class: "Fixed Income & Cash"
    asset_strategy_detail: "Cash"
  - asset_strategy: "Concentrated & Other Equity"
    asset_class: "Equity"
    asset_strategy_detail: "Unclassified"
  - asset_strategy: "EAFE Equity"
    asset_class: "Equity"
    asset_strategy_detail: "Core"
  - asset_strategy: "Emerging Mkt Equity"
    asset_class: "Equity"
    asset_strategy_detail: "Core"
  - asset_strategy: "Fixed Income"
    asset_class: "Fixed Income & Cash"
    asset_strategy_detail: "Investment Grade"
  - asset_strategy: "High Yield Fixed Income"
    asset_class: "Fixed Income & Cash"
    asset_strategy_detail: "High Yield"
  - asset_strategy: "Japan Equity"
    asset_class: "Equity"
    asset_strategy_detail: "Core"
  - asset_strategy: "Public Market Alternatives"
    asset_class: "Alternatives"
    asset_strategy_detail: "Liquid Alternatives"
  - asset_strategy: "Real Assets"
    asset_class: "Alternatives"
    asset_strategy_detail: "Real Estate"
  - asset_strategy: "U.S. Large Cap Equity"
    asset_class: "Equity"
    asset_strategy_detail: "Core"
  - asset_strategy: "U.S. Small/Mid Cap Equity"
    asset_class: "Equity"
    asset_strategy_detail: "Core"
```

---

## Updated Epic 1 PRD Priority Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 1 | Plaid Sync Completeness & Balance Assurance | Ensure /accounts/get called; store/update balances; validate non-null | Existing sync jobs | feature/prd-1-sync-balances | Core |
| 2 | Account Strategy & Trust Association Extensions | Add `strategy:string` and `trust_id:integer` to Account | Account model | feature/prd-1-account-extensions | Update FK |
| 3 | Trust Lookup Model & Restricted CRUD | Trust model with EAS values (SFRT, JSIT, QSIT, SFIT, SDIT); admin/parent CRUD | User roles (Devise) | feature/prd-1-trust-model-crud | Pundit |
| 4 | ~~Other Income Model~~ (MOVED TO EPIC 2) | Moved to Epic 2 PRD-2-02 | N/A | N/A | Circular dependency resolved |
| 5 | Null Field Detection & Logging (CONSOLIDATED) | Scan Holdings, Transactions, Liabilities for nulls; institution-aware; output to knowledge_base/null_fields_report.md | Sync jobs | feature/prd-1-null-detection | Consolidates old PRD-1-12 |
| 6 | Investment & Transaction Retrieval Validation | Confirm /investments/transactions/get coverage | Holdings/Transactions jobs | feature/prd-1-inv-trans-validation | Verify |
| 7 | Dedicated Job Server Health Check | Admin endpoint checks Solid Queue worker | Solid Queue | feature/prd-1-job-health | Config |
| 8 | Account Sharing & Exclusion Mechanism | AccountSharing model; parent→child only | User + Account | feature/prd-1-account-sharing | Not bidirectional |
| 9 | Basic UI for Strategy & Trust Editing | Inline editable strategy; trust selector (admin/parent) | PRD-1-02, PRD-1-03 | feature/prd-1-ui-account-edits | DaisyUI |
| 10 | Basic UI for Other Income CRUD | (DEFER TO EPIC 2) | N/A | N/A | Moved |
| **11** | **Holdings Enrichment Fields (P0 BLOCKER)** | Add asset_class:string, sector:string to Holdings | Holdings model | feature/prd-1-11-holdings-enrichment-fields | **REQUIRED FOR EPIC 2** |
| **12** | **Liabilities Model & Plaid Sync (NEW)** | Liability model, SyncLiabilitiesJob | Account model | feature/prd-1-12-liabilities-model-sync | **NEW** |
| **13** | **Enrichment Service (NEW)** | EnrichmentService + tracking fields + jobs | PRD-1-11, Account Classifications | feature/prd-1-13-enrichment-service | **NEW** |

---

## Summary of Changes

**Added**:
- PRD-1-11: Holdings Enrichment Fields (P0 BLOCKER)
- PRD-1-12: Liabilities Model & Plaid Sync
- PRD-1-13: Enrichment Service with Tracking

**Updated**:
- PRD-1-03: Trust model now uses EAS values (SFRT, JSIT, QSIT, SFIT, SDIT)
- PRD-1-05: Consolidated null detection (merged PRD-1-12), institution-aware, outputs to knowledge_base/

**Removed**:
- PRD-1-04: OtherIncome moved to Epic 2 PRD-2-02

**Key Decisions**:
- All currency is USD for V1
- Account sharing is parent→child only (not bidirectional)
- Trust values from EAS confirmed
- Use Account Classifications mapping from config/account_classifications.yml
