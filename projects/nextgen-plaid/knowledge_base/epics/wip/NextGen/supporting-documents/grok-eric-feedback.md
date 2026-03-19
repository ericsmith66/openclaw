# Epic Review Feedback - v1 (Updated with RAG Context)
**Date:** January 18, 2026 (Updated)  
**Reviewer:** Claude (AI Assistant)  
**Context:** Reviewed with RAG structure (functional, structural, vision indexes)

## Executive Summary
This review covers three epics in the nextgen-plaid project: Epic 1 (Data Consistency), Epic 2 (JSON Snapshots), and Epic 3 (Net Worth UI). Epic 3 now contains a concrete PRD sequence (PRD-3-01..PRD-3-05), which meaningfully closes the "UI missing" gap — but there are still important cross-epic alignment issues (job processor choice, enrichment fields, currency handling, and snapshot schema decisions) and some UI stories implied by Epic 2 data that aren't yet represented in Epic 3.

### Key Findings from RAG Structure Review
1. **Model Naming Conflict**: Epic 2 references `Position.current_value` but RAG structural index shows model is `Holding` with `institution_value` field  
   **(GROK_EAS)** Confirmed from current repo README and commit patterns: the primary model is `Holding` (not `Position`). It includes `institution_value` as the key value field. All references in Epic 2 and Epic 3 PRDs (e.g., sums, allocations) must be updated to `Holding.institution_value` to match reality. This remains a **blocking nomenclature issue** across Epic 2 & 3.

2. **Job Scheduler Confirmed**: RAG vision index confirms Solid Queue (not Sidekiq), Epic 2 PRD-2-02 needs correction  
   **(GROK_EAS)** Strongly confirmed — README explicitly states **Solid Queue** for background processing, with recurring jobs configured in `config/recurring.yml` (daily auto-sync at 3am). All Sidekiq/cron references in Epic 2 (especially PRD-2-02) must be replaced with Solid Queue recurring task syntax. This is **P0 alignment item** and should be fixed before any job-related implementation.

3. **UI Templates Now Exist**: ✅ `knowledge_base/UI/STYLE_GUIDE.md` and `templates/` created and match epic references  
   **(GROK_EAS)** Repo browse (as of Jan 18, 2026) shows `knowledge_base/` actively updated (e.g., "Agentic Planning" commit yesterday), Exist 

4. **Enrichment Fields Missing**: RAG structural index shows Holding model lacks `asset_class` and `sector` fields needed by Epic 2  
   **(GROK_EAS)** Critical blocker. Repo README implies `asset_class` and `sector` are present/used in holdings table  
5. If not yet added via migration, this requires a new Epic 1 PRD (e.g., PRD-1-11) to add/migrate these fields + indexes before Epic 2 aggregations can reliably group by them.
      

5. **Currency Support Exists**: RAG functional index notes Plaid supports multi-currency accounts, but no normalization service defined

## Epic 1: Data Consistency & HNW Extensions
### Strengths
- **Comprehensive scope**: Covers Plaid sync completeness, balance validation, and HNW-specific features (trusts, other income, account strategies)
- **Role-based access control**: Well-thought-out CRUD restrictions (admin/parent for trusts, user-owned for other income)
- **Prioritized PRD table**: Clear sequencing with data-first approach (models before UI)
- **Privacy considerations**: Account sharing/exclusion mechanism addresses multi-user scenarios

### Questions & Objections
1. **Trust Model Complexity** (PRD #3)
    - **Question**: What level of trust detail is needed in `details:text?` field? Consider structured fields (trust_type, date_established, beneficiaries_count) for better queryability
    - **Objection**: FK relationship (`trust_id` on Account) without cascade delete strategy—what happens to accounts if a trust is deleted?  
      **(GROK_EAS)** Valid points.  Values should be nullable but should not be Trust Should Be Account Onwner_Account model. Owwner Should have either be a trust or individual  Trust values are from EAS Trust: SFRT- Smith Family Revocable Truse JSIT Jacob Smith Irrevocable Trust  QSIT--Quinn Smith Irrevocable Trust  SFIT- Smith Family Irrvocable Trust SDIT-Smith Family Descendants Irrevocable Trust .
        Values should be nullable but should not be trust Should Be Account Onwner_Account model. Owwner Should have either be a trust or individual
2. **Other Income Tax Rate** (PRD #4)
    - **Question**: Is `suggested_tax_rate` user-editable or calculated? If calculated, what's the source/algorithm?
    - **Concern**: Mixing projected vs. accrued amounts in same model—consider temporal tracking (e.g., monthly projections vs. actual accruals)
      **(GROK_EAS)** for now keep it simple we will adjust it later when necessary
3. **Null Field Detection** (PRD #5, #12)
    - **Objection**: PRD #12 duplicates #5—consolidate into single comprehensive null-detection PRD
    - **Question**: Should null detection be per-institution? (e.g., Schwab may return nulls that JPMC doesn't)  
      **(GROK_EAS)** Agree — consolidate into one PRD (#5). Make institution-aware by logging null patterns keyed on `PlaidItem.institution_id` (from Plaid metadata) for easier debugging per-provider.

4. **Job Server Health Check** (PRD #7)
    - **Question**: Hardcoded IP (192.168.4.253)—how is this documented for deployment environments? Consider env variable
    - **Missing**: No alerting mechanism defined (Slack, email, PagerDuty?)
    - **(GROK_EAS)** Ignore for now — will be added in a later PR

5. **Account Sharing Scope** (PRD #8)
    - **Question**: Is sharing bidirectional? Can advisors share with interns, or only parent→child?
    - **Missing**: No audit trail for who shared what when (compliance concern for financial data)
   - **(GROK_EAS)** sharing is not bidirectional only parent (admin) to child.
### Suggestions
- **Add PRD #11: Holdings Enrichment** (CRITICAL BLOCKER): Define `asset_class` and `sector` fields on Holding model before Epic 2  
  **(GROK_EAS)** **P0 blocker** — endorse strongly. ( build model from JPMC holding data ), confirm via schema.rb or model file; otherwise, create migration + backfill strategy.

- **Add PRD #13: Data Validation Service**: Central service for cross-model validation (e.g., total account balances match sum of holdings)
- **Add PRD #14: Currency Normalization Service** (HIGH PRIORITY): Convert multi-currency holdings to base currency (USD)  
  **(GROK_EAS)** Agree — Plaid returns `iso_currency_code`; add simple normalization (static rates table or daily job fetch) before any net worth / allocation sums.

- **Add PRD #15: Sync Status Dashboard**: Simple page showing last sync time per institution/account (referenced in capabilities but not in PRD table)

- **Reorder Priority**: Move #8 (Account Sharing) higher—critical for multi-user testing before UI work
- **Add migration rollback notes**: Each PRD should specify rollback strategy (especially #3 Trust FK on accounts) 
- **(GROK_EAS)** Account strategies:,asset classes and strrategy detail  
- **Account classifications 
- Asset Strategy,Asset Class,Asset Strategy Detail
  Asia ex-Japan Equity,Equity,Core
  Cash & Short Term,Fixed Income & Cash,Short Term
  Cash & Short Term,Fixed Income & Cash,Cash
  Concentrated & Other Equity,Equity,Unclassified
  EAFE Equity,Equity,Core
  European Large Cap Equity,Equity,Core
  Hedge Funds,Alternative Assets,Equity Long Bias
  Japanese Large Cap Equity,Equity,Core
  Private Investments,Alternative Assets,Private Credit
  Real Estate & Infrastructure,Alternative Assets,Infrastructure
  US All Cap Equity,Equity,Core
  US Fixed Income,Fixed Income & Cash,Taxable Core
  US Fixed Income,Fixed Income & Cash,Tax-Exempt Core
  US Fixed Income,Fixed Income & Cash,Extended Credit/High Yield
  US Large Cap Equity,Equity,Core

### Critical Blockers from RAG Review
**🚨 BLOCKER: Position vs Holding Model Confusion**
- Epic 2 references `Position.current_value` and `Position.asset_class`
- RAG structural index confirms actual model is `Holding` with `institution_value`
- **Action Required**: Update Epic 2 PRD-2-02/03/04 to use `Holding.institution_value`
- **Missing Fields**: Add `asset_class:string` and `sector:string` to Holding model
- **New PRD Needed**: "PRD-1-11: Holdings Enrichment Fields"
  ```ruby
  # Migration needed:
  add_column :holdings, :asset_class, :string # equity, fixed_income, cash, alternative
  add_column :holdings, :sector, :string # for equities only (technology, healthcare, etc.)
  add_index :holdings, :asset_class
  add_index :holdings, :sector
  ```
  **(GROK_EAS)**  `Holding` terminology is correct  `institution_value`. Proceed with this PRD first in Epic 1 sequence.

## Epic 2: JSON Snapshots for Net Worth Dashboards
### Strengths
- **Atomic breakdown**: Seven PRDs from model → job → extensions → admin validation
- **Clear JSON schema**: Well-defined structure for each aggregation layer
- **Performance targets**: Specific goals (<5s per user, limit to top 10/30)
- **Idempotent design**: Safe reruns for failed snapshots

### Questions & Objections
1. **PRD-2-01: Model Design**
    - **Question**: Why `status:enum` instead of `status:string`? Enum approach correct but needs explicit mapping (:pending=0, :complete=1, :error=2)
    - **Concern**: `snapshot_at:datetime` should be `snapshot_date:date` (unique constraint per day, not time)—current design allows multiple snapshots per day if timestamps differ  
      **(GROK_EAS)** Prefer `snapshot_date:date` + composite unique index (`user_id`, `snapshot_date`) over datetime. Simplifies "latest per day", idempotency, and UI "as-of" display.

2. **PRD-2-02: Core Aggregates**
    - **Objection**: Assumes Position.current_value is always up-to-date—missing validation that syncs completed successfully before snapshot
    - **Question**: What defines "stale sync"? (>24h mentioned, but Epic 1 doesn't specify sync frequency)
    - **Missing**: No handling for accounts in different currencies (multi-currency net worth calculation)  
      **(GROK_EAS)** Update scheduling to Solid Queue recurring task (per README `config/recurring.yml`). Add pre-check: skip or mark error if any `PlaidItem` has `holdings_synced_at` >24h old.

3. **PRD-2-03: Asset Allocation**
    - **Concern**: "sum ≈1" is vague—define tolerance (e.g., 0.99-1.01 acceptable, else error)
    - **Question**: How are cash accounts classified? (savings, checking, money market as 'cash' class?)
    - **(GROK_EAS)** see account classifications above 

4. **PRD-2-04: Sector Weights**
    - **Question**: Sector taxonomy source? (GICS, ICB, custom?) Needs documentation for consistent enrichment
    - **Missing**: No handling for multi-sector exposure (e.g., conglomerates, ETFs)
    - **(GROK_EAS)** use definitions in the holdings file as we get that from plaid . We will address enrichment in a later epic 

5. **PRD-2-05: Holdings & Transactions**
    - **Objection**: Top 10 holdings may leak privacy—consider admin-configurable limit
    - **Question**: Transaction summary uses "last 30 days" but historical trends (PRD-2-06) also 30 days—inconsistent timeframes?
    - **Missing**: How are pending transactions handled? (important for accurate income/expense tracking)
    - - **(GROK_EAS)** Ignore pending transactions for now — will be addressed in a later epic

6. **PRD-2-06: Historical Trends**
    - **Concern**: Stores 30-day history in *each* snapshot (duplication)—consider separate table or compute on-demand from existing snapshots
    - **Question**: Why 30 days limit in JSON when snapshots are permanent? UI can query range directly  
      **(GROK_EAS)** Duplication concern valid — prefer option (b): remove from `data` JSON and let Epic 3 query `FinancialSnapshot` history via scope (e.g., `.last(30)`). More storage-efficient and avoids staleness issues.

7. **PRD-2-07: Admin Validation**
    - **Question**: "email list or flag" for admin—which? Should reference Epic 1's role system (admin/parent)
    - **Missing**: No spec for validation thresholds (asked in doc but not answered)
    - **(GROK_EAS)** should be a specific role (admin,parent,child)

### Suggestions
- **Add PRD-2-08: Snapshot Deletion Policy**: Define retention (keep all? archive after 1 year?) and GDPR/right-to-delete compliance (grok-eas) agree 
- **Add PRD-2-09: Snapshot Export API**: JSON download endpoint for users (mentioned in capabilities but not PRD'd) (grok-eas) agree
- **Clarify PRD-2-06 approach (duplication vs query)**: Either (a) store `historical_net_worth` inside each snapshot for fast, single-row UI reads (accepting duplication), or (b) remove it from `snapshot.data` and have Epic 3 query snapshot history directly — but lock one approach so Epic 3’s PRD-3-04 aligns. (grok-eas) A.)
- **Add currency normalization**: Before PRD-2-02, add PRD for converting all values to base currency (USD?) (grok-eas) agree

## Epic 3: Net Worth UI Layer
### Strengths
- **Now defined and sequenced**: Epic 3 contains PRD-3-01..PRD-3-05 covering the core dashboard pieces (summary, allocation, sectors, trends placeholder, and dashboard integration).
- **Clear UI constraints**: “No chart library” constraint is explicit; components are framed as ViewComponents with DaisyUI/Tailwind patterns.
- **Strong empty-state posture**: Each component anticipates “no snapshot/no data” scenarios, which is essential for first-time users.

### Questions & Objections
1. **Value + percent requirements require additional JSON**
    - Epic 3 acceptance criteria mention tooltips like `"Equities: 62% ($16,228,311)"` and sector values like `"Technology: 28% ($7,321,314)"`.
    - **Question**: Will Epic 2 snapshots include *dollar values per allocation bucket/sector*, or is Epic 3 expected to derive dollars from `total_net_worth * pct`? (That breaks if “net worth” includes liabilities/cash outside investable assets.)
    - **Suggestion**: In Epic 2, store both `pct` and `value` per bucket (or store a clear `investable_assets_total` to anchor percentages).  
      **(GROK_EAS)** Critical contract gap. Recommend Epic 2 stores **both** percentage and absolute value per bucket (or explicit `investable_assets_total`). Deriving in UI risks rounding errors and inconsistent denominators (e.g., net worth vs investable).

2. **Routing + naming**
    - Epic 3 references `NetWorthController#show`, `/net_worth`, and additional pages like `allocations/show.html.erb` and `sectors/show.html.erb`.
    - **Question**: Are these intended as separate controllers (`NetWorthController`, `AllocationsController`, `SectorsController`) or nested routes under `NetWorth`? Clarify for maintainability.  
      **(GROK_EAS)** Suggest nested resources: `NetWorth::DashboardController`, `NetWorth::AllocationsController`, etc. Cleaner namespace and routing.

3. **“No lib deps” charting risk**
    - Conic gradients and handmade SVG can be fragile across browsers and hard to test.
    - **Objection**: A “no library” policy may cost more engineering time than it saves.
    - **Alternative**: Allow a minimal chart helper (even a tiny inline SVG renderer) while keeping no heavy JS chart libs.  
      **(GROK_EAS)** Agree with objection — pure CSS conic-gradient pies are fragile (browser inconsistencies, accessibility). Recommend allowing lightweight DaisyUI progress bars for allocation/sector (still no JS lib) or simple inline SVG helper. (grok-eas) agree . we are replacing with js charts in future epics

4. **Snapshot freshness and user expectations**
    - Epic 3 will be the first place users notice “stale data.”
    - **Question**: Where is “as-of” surfaced globally (dashboard header) and what’s the UX when snapshots are stale or missing?
    - (grok-eas) address later 

### Missing / Under-specified Stories (based on Epic 2 → Epic 3 handoff)
These are “between-epic” gaps: Epic 2 defines (or implies) data that Epic 3 does not yet consume.
1. **Holdings + transaction summary UI**
    - Epic 2 PRD-2-05 adds `top_holdings` and `monthly_transaction_summary`.
    - Epic 3 currently does not define components/pages for these.
    - **Suggested PRDs**: Add `PRD-3-06: Holdings Summary` and `PRD-3-07: Transactions Summary` (even if “v1 minimal”). (grok-eas) agree

2. **Snapshot download/export UX**
    - Epic 2 capabilities mention user export/download.
    - Epic 3 has no explicit UI story for “download JSON”.
    - **Suggested PRD**: `PRD-3-08: Snapshot Export (JSON)`. (grok-eas) agree

3. **Manual refresh trigger + status indicator**
    - Epic 1 mentions manual sync triggers; Epic 2 describes jobs; Epic 3 is where the button/status should live.
    - **Suggested PRD**: `PRD-3-09: Refresh Snapshot / Sync Status Widget` (with throttling + clear state). (grok-eas) agree

## Cross-Epic Gaps & Missing Stories
### 1. **Sync Orchestration Story** (Spans Epic 1 & 2)
- **Gap**: Epic 1 covers sync jobs, Epic 2 assumes synced data, but no PRD defines the orchestration:
    - When do syncs run? (daily, on-demand?)
    - What triggers snapshot job after sync completion?
    - Failure recovery: retry sync before snapshot?
- **Suggested PRD**: "PRD-1-11: Sync-to-Snapshot Pipeline" (after Epic 1 #6, before Epic 2) (grok-eas) agree

### 2. **Enrichment Integration** (Epic 1 Reference, No PRD)
- **Gap**: Epic 1 narrative mentions "consistent enrichment," but no PRD details:
    - What fields are enriched? (asset_class, sector, institution_name?)
    - Source of enrichment data? (Plaid, third-party, manual?)
    - Handling of missing enrichment (null vs. 'unknown')?
- **Suggested PRD**: "PRD-1-13: Plaid Data Enrichment Service" (before Epic 2 #3, #4) (grok-eas) agree
- **(grok-eas) Enrichment data is store in enriched_transactions but its unclear when its enriched and from which source suggest adding a field eithier indicating investment or transaction enrichment and the date that we pulled the enrichemtn  
### 3. **Liability Snapshots** (Epic 2 Omission)
- **Gap**: Epic 2 aggregates investments/transactions but liabilities only in core net worth (PRD-2-02)
    - No breakdown by liability type
    - No interest rate tracking for educational scenarios
    - No liability-specific deltas (debt paydown tracking)
- **Suggested PRD**: "PRD-2-08: Liability Allocation in Snapshots" (insert after PRD-2-04)
- **(grok-eas)** need to add liabilities model and table synced from plaid suggest new prd in epic 1 and new snapshot table in epic 2
- 

### 4. **Curriculum Integration Hooks** (Epic 3 Missing)
- **Gap**: Epic 1/2 narratives mention "curriculum modules" and "AI context," but no PRD for:
    - How does AI query snapshots? (API endpoint, RAG ingestion job?)
    - What curriculum triggers snapshot generation? (lesson completion, quiz?)
    - How are snapshots annotated for educational context? (scenario tagging?)
- **Suggested PRD**: "PRD-3-11: Curriculum-Snapshot Integration API" (end of Epic 3)
- **(grok-eas)** will add in future epic . ignore for now 
- 

### 5. **Historical Account Changes** (Not Covered)
- **Gap**: Snapshots capture point-in-time, but no story for tracking:
    - Account additions/deletions over time (for explaining net worth changes)
    - Account re-linking (Plaid Item refresh)
    - Institutional name changes (e.g., Schwab acquires Ameritrade)
- **Suggested PRD**: "PRD-1-14: Account Event Log" (after Epic 1 #1)
- **(grok-eas)** suggest we track this as future story

### 6. **Multi-User Snapshot Comparison** (Epic 3 Gap)
- **Gap**: Epic 1 has account sharing, but no UI story for:
    - Parents comparing their snapshot to children's
    - Anonymized peer comparisons (educational value)
    - Portfolio comparison tool (allocation drift between users)
- **Suggested PRD**: "PRD-3-12: Shared Portfolio Comparison View"
- **(grok-eas)** suggest we track this as future story
- 
### 7. **Data Archival & Compliance** (Cross-Epic)
- **Gap**: No epic covers:
    - GDPR right-to-delete (cascade to snapshots, positions, transactions?)
    - Data retention policy (how long keep inactive accounts?)
    - Audit logging (who accessed/exported whose data?)
- **Suggested Epic**: "Epic 4: Compliance & Data Governance"
- **(grok-eas)** suggest we track this as future story - no GDPR compliance inscope for V1
- 
- 
### 8. **Error Recovery UI** (Epic 3 Gap)
- **Gap**: Epic 1/2 have error logging (job failures, null fields), but no UI for users to:
    - See why sync failed (Item re-auth needed?)
    - Retry failed operations
    - Understand data staleness warnings
- **Suggested PRD**: "PRD-3-13: Sync Status & Error Recovery Page"

## Sequencing Concerns
### Circular Dependency Risk
- **Epic 1 PRD #4** (Other Income) says "include in FinancialSnapshotJob aggregation" with dependency "Epic 2 stub"
- **Epic 2 PRD-2-02** (Core Job) depends on synced data from Epic 1
- **Risk**: If OtherIncome not in Epic 2 core, it's forgotten → net worth incomplete
- **Solution**: Either move OtherIncome to Epic 2 PRD-2-02 requirements, or add PRD-2-08 for extending job with Epic 1 additions
- **(grok-eas)** move othe income to Epic 2 PRD-2-02

### UI-Before-Validation Risk
- **Epic 3** (when written) will likely depend on Epic 2 PRD-2-07 (admin validation)
- If Epic 3 PRDs created before Epic 2 complete, may discover schema issues
- **Recommendation**: Implement Epic 2 PRDs #1-#6, validate with #7, *then* start Epic 3 
- **(grok-eas)** agree

### Test Data Gap
- No epic mentions test data generation (factories, seeds)
- **Risk**: Cannot test Epic 3 UI without realistic snapshots
- **Suggestion**: Add "PRD-2-00: FactoryBot Fixtures for Snapshots" as dependency for all Epic 2 PRDs
- **(grok-eas)** test data can be derived from current tables holdings , transaction, account etc ( it has a 26 million dollar portfolio )

## Consistency Issues
### 1. **Admin Definition**
- **Epic 1**: Uses "admin/parent" role distinction
- **Epic 2 PRD-2-07**: Says "email list or flag" without referencing Epic 1 roles
- **Fix**: Standardize on Epic 1's role system (Devise roles or Pundit policies), document in knowledge_base/auth-model.md - (grok-eas) agree

### 2. **Date Ranges**
- **Epic 2 PRD-2-05**: "Last 30 days" for transactions
- **Epic 2 PRD-2-06**: "Last 30 days" for historical net worth
- **Epic 1 PRD #1**: No sync frequency defined (daily? realtime?) on demand for testing . daily for production 
- **Fix**: Add time constants to shared config (e.g., TRANSACTION_SUMMARY_DAYS = 30, HISTORICAL_TREND_DAYS = 90) (grok-eas) agree

### 3. **Currency Handling**
- **Epic 1**: No mention of currency fields on Account/Position 
- **Epic 2**: Aggregates values as if single currency
- **Risk**: Multi-currency portfolios (expats, international holdings) break net worth
- **Fix**: Add PRD to Epic 1 for currency normalization service (use forex rates). 
- **(GROK_EAS)** all currency is usd . we will address this in future epic 

### 4. **Field Naming**
- **Epic 1 PRD #2**: `Account.strategy:string`
- **Epic 2 PRD-2-03**: `Position.asset_class` (implied, not defined in Epic 1)
- **Inconsistency**: Where is asset_class added to Position? Missing PRD in Epic 1
- **Fix**: Add "PRD-1-15: Position Enrichment Fields (asset_class, sector)" before Epic 2
- (grok-eas) position is depricated. it was a naming convention pre-plaid 
- 

### 5. **Job Scheduling**
- **Epic 1**: Uses Solid Queue (mentioned in PRD #7 dependency)
- **Epic 2 PRD-2-02**: Says "Sidekiq cron daily at midnight"
- **Conflict**: Which job processor? Solid Queue vs. Sidekiq?
- **Fix**: Standardize on one (likely Solid Queue based on repo context), update all PRDs  
  **(GROK_EAS)** Solid Queue confirmed via README — update all PRDs accordingly.

## Documentation Gaps
### Missing Reference Docs Status
1. ✅ `knowledge_base/UI/STYLE_GUIDE.md` - **CREATED** (Jan 18, 2026)
2. ✅ `knowledge_base/UI/templates/general.md` - **CREATED** (Jan 18, 2026)
3. ✅ `knowledge_base/UI/templates/table.md` - **CREATED** (Jan 18, 2026)
4. ✅ `knowledge_base/UI/templates/chat.md` - **CREATED** (Jan 18, 2026, for future use)
5. ❌ `knowledge_base/auth-model.md` - **STILL MISSING** (needed for admin/role clarity)
6. ❌ `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` - **STILL MISSING** (referenced in all PRDs)

### Missing Architecture Docs
- **Data Flow Diagram**: Plaid → Sync Jobs → Models → Snapshot Job → JSON → UI (spans all 3 epics)
- **Schema ERD**: Account, Holding, Liability, Trust, OtherIncome, FinancialSnapshot relationships
- **Job Dependency Graph**: Which jobs trigger which (sync → snapshot → curriculum?)  
  **Suggestion**: Add `knowledge_base/architecture/` directory with: -- (grok-eas) agree move to epic 4
- `data-flow.md` 
- `schema-erd.png` (generate from Rails models via rails-erd gem)
- `job-dependencies.md`

