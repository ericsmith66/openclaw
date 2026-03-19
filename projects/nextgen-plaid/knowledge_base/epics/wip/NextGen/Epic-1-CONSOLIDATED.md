# Epic 1: Data Model Foundation & Plaid Sync Integrity (CONSOLIDATED)

**Status**: Consolidated from epic-1-revisions.md and feedback-v1.md
**Last Updated**: 2026-01-18

---

## Epic Overview

Establish reliable, normalized, deduplicated data models and sync processes for Plaid products (investments, transactions, liabilities, enrichment) from JPMC, Schwab, Amex, Stellar — with validation, error recovery, consistent enrichment, and HNW extensions (account strategies, external income, trust lookup/associations with restricted CRUD, sharing controls, basic UI for new elements scoped by role).

## User Capabilities

- **Interns (normal users)**: View strategy/trust info; add/view/edit/delete their own other income; trigger manual syncs; see status/timestamps
- **Advisors (AI)**: Query accurate, augmented data (including trusts/other income in snapshots)
- **Admins/Parents**: Monitor logs/health; force actions; share/exclude accounts; create/edit/delete trusts (lookup table); assign trusts to accounts (restricted fields)

## Fit into Big Picture

Unbreakable foundation for trustworthy AI education — complete income/net worth with trusts enables accurate estate/tax/philanthropy simulations; restricted CRUD ensures privacy in family/intern scenarios; user-maintainable income supports personal engagement without admin bottlenecks.

---

## PRD Breakdown (Priority Order)

| Priority | PRD ID | Title | Scope | Dependencies | Branch | Notes |
|----------|--------|-------|-------|--------------|--------|-------|
| 1 | PRD-1-01 | Plaid Sync Completeness & Balance Assurance | Ensure /accounts/get called; store/update current/available balances; validate non-null | Existing sync jobs | `feature/prd-1-01-sync-balances` | Core — Claude Sonnet 4.5 |
| 2 | PRD-1-02 | Account Strategy & Trust Association Extensions | Add `asset_strategy:string` and `trust_id:integer` (nullable, belongs_to :trust) to Account; migration + validations | Account model | `feature/prd-1-02-account-extensions` | FK for lookup |
| 3 | PRD-1-03 | Trust Lookup Model & Restricted CRUD | New Trust model with EAS values (SFRT, JSIT, QSIT, SFIT, SDIT); admin/parent-only CRUD service/controller | User roles (Devise) | `feature/prd-1-03-trust-model-crud` | Pundit restrictions |
| 4 | PRD-1-04 | Other Income Model & Integration | New OtherIncome model (user_id, name:string, date:date, projected_amount:decimal, accrued_amount:decimal, suggested_tax_rate:decimal); include in FinancialSnapshotJob aggregation | User model + Epic 2 stub | `feature/prd-1-04-other-income-model` | User-owned scoping |
| 5 | PRD-1-05 | Null Field Detection & Logging (Consolidated) | Consistency job scans Holdings, Transactions, Liabilities for persistent nulls; institution-aware; output to knowledge_base/null_fields_report.md | Sync jobs | `feature/prd-1-05-null-detection` | Diagnostic; merged old PRD-1-12 |
| 6 | PRD-1-06 | Investment & Transaction Retrieval Validation | Confirm /investments/transactions/get coverage; incremental sync; fixed income handling | Holdings/Transactions jobs | `feature/prd-1-06-inv-trans-validation` | Verify institutions |
| 7 | PRD-1-07 | Dedicated Job Server Health Check | Admin endpoint (/admin/health) checks Solid Queue worker on 192.168.4.253 | Solid Queue | `feature/prd-1-07-job-health` | Server config |
| 8 | PRD-1-08 | Account Sharing & Exclusion Mechanism | New AccountSharing model; parent→child only (not bidirectional); scope queries/views | User + Account | `feature/prd-1-08-account-sharing` | Privacy-critical |
| 9 | PRD-1-09 | Basic UI for Strategy & Trust Editing (Restricted) | Inline editable strategy field (all users); trust selector dropdown (admin/parent only) in Account views | PRD-1-02, PRD-1-03, ViewComponent | `feature/prd-1-09-ui-account-edits` | DaisyUI; role checks |
| 10 | PRD-1-10 | Basic UI for Other Income CRUD (User-Maintainable) | New page/controller for list/add/edit/delete; table view; integrate link in dashboard; scoped to current_user | PRD-1-04 | `feature/prd-1-10-ui-other-income` | Simple forms |
| **11** | **PRD-1-11** | **Holdings Enrichment Fields (P0 BLOCKER)** | Add `asset_class:string` and `sector:string` to Holdings model with indexes | Holdings model | `feature/prd-1-11-holdings-enrichment-fields` | **REQUIRED FOR EPIC 2** |
| **12** | **PRD-1-12** | **Liabilities Model & Plaid Sync** | Liability model, SyncLiabilitiesJob for /liabilities/get | Account model | `feature/prd-1-12-liabilities-model-sync` | **NEW** |
| **13** | **PRD-1-13** | **Enrichment Service with Tracking** | EnrichmentService + tracking fields (enriched_at, enrichment_source) + jobs | PRD-1-11, Account Classifications | `feature/prd-1-13-enrichment-service` | **NEW** |

---

## Detailed PRD Specifications

### PRD-1-01: Plaid Sync Completeness & Balance Assurance

**Overview**
Ensure /accounts/get is called consistently; store/update current/available balances; validate non-null critical fields.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**
- **Functional**:
  - Sync job calls Plaid `/accounts/get`
  - Store `current_balance` and `available_balance` on Account model
  - Validate balances are present (not null) for active accounts
  - Log sync timestamp and status
- **Non-Functional**:
  - Idempotent sync (safe rerun)
  - Error handling with retry logic

**Acceptance Criteria**
- Account records have current/available balances populated
- Sync job logs success/failure with timestamps
- Validation errors logged for null balances on active accounts

**Workflow**
- Branch: `feature/prd-1-01-sync-balances`
- Default LLM: Claude Sonnet 4.5

---

### PRD-1-02: Account Strategy & Trust Association Extensions

**Overview**
Add `asset_strategy:string` and `trust_id:integer` (nullable foreign key to Trust) to Account model.

**Requirements**
- **Functional**:
  - Migration: Add `asset_strategy:string` and `trust_id:integer` to accounts table
  - Add `belongs_to :trust, optional: true` association
  - Index on trust_id for fast lookups
- **Non-Functional**:
  - Nullable fields (legacy accounts unaffected)

**Acceptance Criteria**
- Migration runs cleanly
- Account can be associated with a Trust
- Queries on trust_id are performant

**Workflow**
- Branch: `feature/prd-1-02-account-extensions`
- Command: `rails g migration AddStrategyAndTrustToAccounts asset_strategy:string trust_id:integer`

---

### PRD-1-03: Trust Lookup Model & Restricted CRUD

**Overview**
Create Trust model with EAS trust types; restrict CRUD to admin/parent roles using Pundit.

**Requirements**
- **Functional**:
  - Trust model: `name:string`, `trust_type:string`, `details:text`
  - Enum values for trust_type: `['SFRT', 'JSIT', 'QSIT', 'SFIT', 'SDIT']`
  - Controller with Pundit policy: admin/parent only
  - Index on trust_type
- **Non-Functional**:
  - Validation: name and trust_type required
  - Trust types must be from allowed list

**Acceptance Criteria**
- Trust model created with validations
- Admin/parent can create/edit/delete trusts
- Non-admin users cannot access Trust CRUD
- trust_type enum enforced

**Model Code**
```ruby
class Trust < ApplicationRecord
  TRUST_TYPES = %w[SFRT JSIT QSIT SFIT SDIT].freeze
  validates :name, presence: true
  validates :trust_type, presence: true, inclusion: { in: TRUST_TYPES }
end
```

**Workflow**
- Branch: `feature/prd-1-03-trust-model-crud`
- Command: `rails g model Trust name:string trust_type:string details:text`

---

### PRD-1-04: Other Income Model & Integration

**Overview**
Create OtherIncome model for user-maintainable income sources; integrate with Epic 2 snapshots.

**Requirements**
- **Functional**:
  - Model: `OtherIncome` belongs_to :user
  - Fields: `name:string`, `date:date`, `projected_amount:decimal`, `accrued_amount:decimal`, `suggested_tax_rate:decimal`
  - Scope: User can only access their own records
  - Include in FinancialSnapshotJob aggregation
- **Non-Functional**:
  - Validation: All fields required except accrued_amount (nullable)

**Acceptance Criteria**
- OtherIncome model created with user association
- User can CRUD their own records
- Included in net worth calculations (Epic 2)

**Workflow**
- Branch: `feature/prd-1-04-other-income-model`
- Command: `rails g model OtherIncome user:references name:string date:date projected_amount:decimal accrued_amount:decimal suggested_tax_rate:decimal`

---

### PRD-1-05: Null Field Detection & Logging (Consolidated)

**Overview**
Scan Holdings, Transactions, and Liabilities for persistent null fields; institution-aware; output report to knowledge_base.

**Requirements**
- **Functional**:
  - Job: `NullFieldDetectionJob`
  - Scan models: Holding, Transaction, Liability
  - Group nulls by institution_id (via PlaidItem)
  - Output: `knowledge_base/null_fields_report.md`
  - Log patterns (e.g., "Schwab holdings always null for cost_basis")
- **Non-Functional**:
  - Run weekly via Solid Queue
  - < 5min execution time

**Acceptance Criteria**
- Job identifies null fields by model and institution
- Report generated in knowledge_base/
- Admin can review patterns and decide on exclusions

**Workflow**
- Branch: `feature/prd-1-05-null-detection`
- Command: `rails g job null_field_detection`

---

### PRD-1-06: Investment & Transaction Retrieval Validation

**Overview**
Confirm /investments/transactions/get coverage; ensure incremental sync; handle fixed income.

**Requirements**
- **Functional**:
  - Verify SyncHoldingsJob and SyncTransactionsJob call Plaid correctly
  - add field to the transaction table indicating that this is an investment transaction.
  - Incremental sync using cursor/start_date
  - Handle securities with missing metadata (fixed income edge cases)
- **Non-Functional**:
  - Sync frequency: daily
  - Deduplication by plaid_transaction_id

**Acceptance Criteria**
- Holdings sync covers all institutions (JPMC, Schwab, etc.)
- Transactions incrementally synced without duplicates
- Fixed income holdings do not crash sync

**Workflow**
- Branch: `feature/prd-1-06-inv-trans-validation`

---

### PRD-1-07: Dedicated Job Server Health Check

**Overview**
Admin endpoint to monitor Solid Queue worker health on 192.168.4.253.

**Requirements**
- **Functional**:
  - Endpoint: `/admin/health`
  - Check: Solid Queue process running, recent job executions
  - Response: JSON with status, last job timestamp, queue depth
- **Non-Functional**:
  - Admin-only access (Pundit policy)
  - < 1s response time

**Acceptance Criteria**
- Endpoint returns health status
- Admin can see if job server is responsive
- Alerts if no jobs processed in 1 hour

**Workflow**
- Branch: `feature/prd-1-07-job-health`

---

### PRD-1-08: Account Sharing & Exclusion Mechanism

**Overview**
Parent can share/exclude accounts to/from child users (not bidirectional).

**Requirements**
- **Functional**:
  - Model: `AccountSharing` (parent_id, child_id, account_id, excluded:boolean)
  - Scope: Parent→child only
  - Queries filter accounts based on sharing rules
- **Non-Functional**:
  - Privacy: child cannot see parent's unshared accounts

**Acceptance Criteria**
- Parent can mark accounts as shared or excluded for child
- Child only sees allowed accounts
- Snapshots respect sharing rules

**Workflow**
- Branch: `feature/prd-1-08-account-sharing`
- Command: `rails g model AccountSharing parent:references child:references account:references excluded:boolean`

---

### PRD-1-09: Basic UI for Strategy & Trust Editing (Restricted)

**Overview**
Inline editable `asset_strategy` field (all users); trust selector dropdown (admin/parent only).

**Requirements**
- **Functional**:
  - Account index/show: inline edit for asset_strategy
  - Trust dropdown: visible only to admin/parent
  - DaisyUI components
  - ViewComponent for reusability
- **Non-Functional**:
  - Role checks via Pundit
  - AJAX update (no page reload)

**Acceptance Criteria**
- All users can edit asset_strategy inline
- Admin/parent can assign trust via dropdown
- Interns cannot see trust selector

**Workflow**
- Branch: `feature/prd-1-09-ui-account-edits`

---

### PRD-1-10: Basic UI for Other Income CRUD (User-Maintainable)

**Overview**
New page/controller for user to manage their own OtherIncome records.

**Requirements**
- **Functional**:
  - Route: `/other_incomes`
  - Actions: index, new, create, edit, update, destroy
  - Scope: `current_user.other_incomes`
  - Table view with add/edit/delete buttons
  - Link from dashboard
- **Non-Functional**:
  - Simple forms (no admin restriction)
  - DaisyUI styling

**Acceptance Criteria**
- User can see list of their income sources
- User can add/edit/delete records
- No access to other users' records

**Workflow**
- Branch: `feature/prd-1-10-ui-other-income`
- Command: `rails g controller OtherIncomes index new create edit update destroy`

---

### PRD-1-11: Holdings Enrichment Fields (P0 BLOCKER)

**Overview**
Add `asset_class:string` and `sector:string` to Holdings model to enable Epic 2 snapshot aggregations.

**Requirements**
- **Functional**:
  - Migration: Add `asset_class:string` and `sector:string` to holdings table
  - Indexes: `add_index :holdings, :asset_class` and `add_index :holdings, :sector`
  - Validations: Optional fields (nil allowed until enriched)
  - Integration: Populated by EnrichmentService (PRD-1-13)
- **Non-Functional**:
  - No data loss: existing holdings unaffected
  - Performance: indexed for group/sum queries

**Acceptance Criteria**
- Migration runs cleanly with columns and indexes
- `Holding.create` with/without asset_class/sector succeeds
- `Holding.group(:asset_class).sum(:institution_value)` works
- Existing records remain valid (nil allowed)

**Test Cases**
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
- Branch: `feature/prd-1-11-holdings-enrichment-fields`
- Command: `rails g migration AddEnrichmentFieldsToHoldings asset_class:string sector:string`
- Default LLM: Claude Sonnet 4.5

---

### PRD-1-12: Liabilities Model & Plaid Sync

**Overview**
Create Liabilities model and sync job to fetch from Plaid `/liabilities/get`, enabling complete net worth calculations (assets - liabilities).

**Requirements**
- **Functional**:
  - Model: `Liability` belongs_to :account, belongs_to :user
  - Fields: `liability_type:string`, `current_balance:decimal`, `last_payment_date:date`, `next_payment_due_date:date`, `minimum_payment_amount:decimal`, `apr:decimal`, `is_overdue:boolean`
  - Migration: Create table with indexes on user_id, account_id, liability_type
  - Job: `SyncLiabilitiesJob` (calls Plaid `/liabilities/get`, upserts Liability records)
  - Schedule: Daily at 3:05am via Solid Queue config/recurring.yml
- **Non-Functional**:
  - Idempotent: safe rerun (upsert by account + liability_id)
  - Error handling: log Plaid errors, set account.last_sync_status = :error

**Acceptance Criteria**
- Migration creates liabilities table with correct fields/indexes
- SyncLiabilitiesJob fetches and stores liability data from Plaid
- `Liability.total_for_user(user)` returns sum of balances
- Job handles no liabilities gracefully (empty array)
- Recurring config schedules job daily

**Test Cases**
```ruby
describe Liability do
  it "calculates total balance" do
    create(:liability, user: user, current_balance: 5000)
    create(:liability, user: user, current_balance: 3000)
    expect(Liability.total_for_user(user)).to eq(8000)
  end
end

describe SyncLiabilitiesJob do
  it "syncs liabilities from Plaid" do
    VCR.use_cassette('plaid_liabilities') do
      perform_enqueued_jobs { SyncLiabilitiesJob.perform_now(user) }
      expect(user.liabilities.count).to be > 0
    end
  end
end
```

**Workflow**
- Branch: `feature/prd-1-12-liabilities-model-sync`
- Commands:
  - `rails g model Liability user:references account:references liability_type:string current_balance:decimal last_payment_date:date next_payment_due_date:date minimum_payment_amount:decimal apr:decimal is_overdue:boolean`
  - `rails g job sync_liabilities`
- Default LLM: Claude Sonnet 4.5

---

### PRD-1-13: Enrichment Service with Tracking

**Overview**
Build EnrichmentService to populate holdings.asset_class, holdings.sector, and accounts.asset_strategy using Account Classifications mapping. Add tracking fields for audit.

**Requirements**
- **Functional**:
  - Service: `EnrichmentService.enrich_holding(holding)` — maps holding.security_name or account name to asset_class/sector using lookup table or heuristics
  - Service: `EnrichmentService.enrich_account(account)` — maps account.type/subtype to asset_strategy using Account Classifications (see below)
  - Tracking: Add `enriched_at:datetime` and `enrichment_source:string` to holdings and accounts tables
  - Jobs: `EnrichHoldingsJob` and `EnrichAccountsJob` (run after sync, before snapshot)
  - Schedule: Daily at 3:10am via Solid Queue config/recurring.yml
- **Non-Functional**:
  - Fast: < 1s per 100 holdings (in-memory lookup)
  - Fallback: 'other'/'unknown' for unmapped items

**Architectural Context**
- Rails: Service object (app/services/enrichment_service.rb), Solid Queue jobs
- Data: Store Account Classifications as YAML or seed data (config/account_classifications.yml)
- Dependencies: Holding (PRD-1-11), Account (PRD-1-02)

**Acceptance Criteria**
- EnrichmentService maps known securities to correct asset_class/sector
- EnrichmentService maps account types to asset_strategy
- Tracking fields populated with timestamp and source ("plaid_type", "manual", "heuristic")
- Jobs run successfully on schedule
- Unmapped items fall back to 'other'

**Test Cases**
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
- Branch: `feature/prd-1-13-enrichment-service`
- Commands:
  - `mkdir -p app/services && touch app/services/enrichment_service.rb`
  - `rails g migration AddEnrichmentTrackingToHoldings enriched_at:datetime enrichment_source:string`
  - `rails g migration AddEnrichmentTrackingToAccounts enriched_at:datetime enrichment_source:string`
  - `rails g job enrich_holdings`
  - `rails g job enrich_accounts`
- Default LLM: Claude Sonnet 4.5

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

## Key Architectural Decisions

1. **Currency**: All amounts in USD for V1
2. **Account Sharing**: Parent→child only (not bidirectional)
3. **Trust Types**: Use EAS values (SFRT, JSIT, QSIT, SFIT, SDIT)
4. **Enrichment Source**: config/account_classifications.yml
5. **Authorization**: Pundit for role-based access control
6. **Job Scheduler**: Solid Queue with config/recurring.yml
7. **Testing**: VCR for Plaid API mocks

---

## Implementation Order (Recommended)

**Phase 1: Core Data Models (P0)**
1. PRD-1-01: Sync balances (foundation)
2. PRD-1-11: Holdings enrichment fields (blocker for Epic 2)
3. PRD-1-12: Liabilities model & sync (net worth calculation)
4. PRD-1-02: Account extensions (strategy/trust FK)
5. PRD-1-03: Trust model & CRUD

**Phase 2: Enrichment & Validation (P1)**
6. PRD-1-13: Enrichment service
7. PRD-1-06: Investment/transaction validation
8. PRD-1-05: Null field detection

**Phase 3: User Features & Admin Tools (P2)**
9. PRD-1-04: OtherIncome model
10. PRD-1-08: Account sharing
11. PRD-1-07: Job health check

**Phase 4: UI (P3)**
12. PRD-1-09: Strategy/trust editing UI
13. PRD-1-10: OtherIncome CRUD UI

---

## Dependencies on Other Epics

- **Epic 2 (Snapshots)**: Depends on PRD-1-11 (holdings enrichment fields), PRD-1-12 (liabilities), PRD-1-04 (other income)
- **Epic 3 (Net Worth UI)**: Depends on Epic 2 completion + PRD-1-09/PRD-1-10 (UI components)

---

## Success Metrics

- **Data Quality**: < 1% null critical fields (balances, holdings)
- **Sync Reliability**: 99% success rate for Plaid API calls
- **Performance**: Sync jobs complete in < 5 minutes for 100+ accounts
- **Coverage**: All institutions (JPMC, Schwab, Amex, Stellar) syncing holdings, transactions, liabilities
- **User Satisfaction**: Admin/parent can manage trusts; interns can maintain their own income sources

---

## Notes

- **Removed**: OtherIncome was initially in Epic 1 but circular dependency with Epic 2 snapshots resolved by keeping it in Epic 1 with Epic 2 integration hook
- **Consolidated**: PRD-1-05 now includes null detection for Holdings, Transactions, and Liabilities (previously split across PRD-1-12)
- **New PRDs**: PRD-1-11, PRD-1-12, PRD-1-13 added based on feedback-v1.md review

---

**Next Steps**: Lock this epic and draft full atomic PRD for PRD-1-01 (sync balances)?
