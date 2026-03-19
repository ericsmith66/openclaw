# Epic Review Feedback - v1 (Updated with RAG Context)
**Date:** January 18, 2026 (Updated)
**Reviewer:** Claude (AI Assistant)
**Context:** Reviewed with RAG structure (functional, structural, vision indexes)

## Executive Summary

This review covers three epics in the nextgen-plaid project: Epic 1 (Data Consistency), Epic 2 (JSON Snapshots), and Epic 3 (Net Worth UI). Epic 3 now contains a concrete PRD sequence (PRD-3-01..PRD-3-05), which meaningfully closes the "UI missing" gap — but there are still important cross-epic alignment issues (job processor choice, enrichment fields, currency handling, and snapshot schema decisions) and some UI stories implied by Epic 2 data that aren't yet represented in Epic 3.

### Key Findings from RAG Structure Review
1. **Model Naming Conflict**: Epic 2 references `Position.current_value` but RAG structural index shows model is `Holding` with `institution_value` field
2. **Job Scheduler Confirmed**: RAG vision index confirms Solid Queue (not Sidekiq), Epic 2 PRD-2-02 needs correction
3. **UI Templates Now Exist**: ✅ `knowledge_base/UI/STYLE_GUIDE.md` and `templates/` created and match epic references
4. **Enrichment Fields Missing**: RAG structural index shows Holding model lacks `asset_class` and `sector` fields needed by Epic 2
5. **Currency Support Exists**: RAG functional index notes Plaid supports multi-currency accounts, but no normalization service defined

---

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

2. **Other Income Tax Rate** (PRD #4)
   - **Question**: Is `suggested_tax_rate` user-editable or calculated? If calculated, what's the source/algorithm?
   - **Concern**: Mixing projected vs. accrued amounts in same model—consider temporal tracking (e.g., monthly projections vs. actual accruals)

3. **Null Field Detection** (PRD #5, #12)
   - **Objection**: PRD #12 duplicates #5—consolidate into single comprehensive null-detection PRD
   - **Question**: Should null detection be per-institution? (e.g., Schwab may return nulls that JPMC doesn't)

4. **Job Server Health Check** (PRD #7)
   - **Question**: Hardcoded IP (192.168.4.253)—how is this documented for deployment environments? Consider env variable
   - **Missing**: No alerting mechanism defined (Slack, email, PagerDuty?)

5. **Account Sharing Scope** (PRD #8)
   - **Question**: Is sharing bidirectional? Can advisors share with interns, or only parent→child?
   - **Missing**: No audit trail for who shared what when (compliance concern for financial data)

### Suggestions

- **Add PRD #11: Holdings Enrichment** (CRITICAL BLOCKER): Define `asset_class` and `sector` fields on Holding model before Epic 2
- **Add PRD #13: Data Validation Service**: Central service for cross-model validation (e.g., total account balances match sum of holdings)
- **Add PRD #14: Currency Normalization Service** (HIGH PRIORITY): Convert multi-currency holdings to base currency (USD)
- **Add PRD #15: Sync Status Dashboard**: Simple page showing last sync time per institution/account (referenced in capabilities but not in PRD table)
- **Reorder Priority**: Move #8 (Account Sharing) higher—critical for multi-user testing before UI work
- **Add migration rollback notes**: Each PRD should specify rollback strategy (especially #3 Trust FK on accounts)

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

---

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

2. **PRD-2-02: Core Aggregates**
   - **Objection**: Assumes Position.current_value is always up-to-date—missing validation that syncs completed successfully before snapshot
   - **Question**: What defines "stale sync"? (>24h mentioned, but Epic 1 doesn't specify sync frequency)
   - **Missing**: No handling for accounts in different currencies (multi-currency net worth calculation)

3. **PRD-2-03: Asset Allocation**
   - **Concern**: "sum ≈1" is vague—define tolerance (e.g., 0.99-1.01 acceptable, else error)
   - **Question**: How are cash accounts classified? (savings, checking, money market as 'cash' class?)

4. **PRD-2-04: Sector Weights**
   - **Question**: Sector taxonomy source? (GICS, ICB, custom?) Needs documentation for consistent enrichment
   - **Missing**: No handling for multi-sector exposure (e.g., conglomerates, ETFs)

5. **PRD-2-05: Holdings & Transactions**
   - **Objection**: Top 10 holdings may leak privacy—consider admin-configurable limit
   - **Question**: Transaction summary uses "last 30 days" but historical trends (PRD-2-06) also 30 days—inconsistent timeframes?
   - **Missing**: How are pending transactions handled? (important for accurate income/expense tracking)

6. **PRD-2-06: Historical Trends**
   - **Concern**: Stores 30-day history in *each* snapshot (duplication)—consider separate table or compute on-demand from existing snapshots
   - **Question**: Why 30 days limit in JSON when snapshots are permanent? UI can query range directly

7. **PRD-2-07: Admin Validation**
   - **Question**: "email list or flag" for admin—which? Should reference Epic 1's role system (admin/parent)
   - **Missing**: No spec for validation thresholds (asked in doc but not answered)

### Suggestions

- **Add PRD-2-08: Snapshot Deletion Policy**: Define retention (keep all? archive after 1 year?) and GDPR/right-to-delete compliance
- **Add PRD-2-09: Snapshot Export API**: JSON download endpoint for users (mentioned in capabilities but not PRD'd)
- **Clarify PRD-2-06 approach (duplication vs query)**: Either (a) store `historical_net_worth` inside each snapshot for fast, single-row UI reads (accepting duplication), or (b) remove it from `snapshot.data` and have Epic 3 query snapshot history directly — but lock one approach so Epic 3’s PRD-3-04 aligns.
- **Add currency normalization**: Before PRD-2-02, add PRD for converting all values to base currency (USD?)

---

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

2. **Routing + naming**
   - Epic 3 references `NetWorthController#show`, `/net_worth`, and additional pages like `allocations/show.html.erb` and `sectors/show.html.erb`.
   - **Question**: Are these intended as separate controllers (`NetWorthController`, `AllocationsController`, `SectorsController`) or nested routes under `NetWorth`? Clarify for maintainability.

3. **“No lib deps” charting risk**
   - Conic gradients and handmade SVG can be fragile across browsers and hard to test.
   - **Objection**: A “no library” policy may cost more engineering time than it saves.
   - **Alternative**: Allow a minimal chart helper (even a tiny inline SVG renderer) while keeping no heavy JS chart libs.

4. **Snapshot freshness and user expectations**
   - Epic 3 will be the first place users notice “stale data.”
   - **Question**: Where is “as-of” surfaced globally (dashboard header) and what’s the UX when snapshots are stale or missing?

### Missing / Under-specified Stories (based on Epic 2 → Epic 3 handoff)
These are “between-epic” gaps: Epic 2 defines (or implies) data that Epic 3 does not yet consume.

1. **Holdings + transaction summary UI**
   - Epic 2 PRD-2-05 adds `top_holdings` and `monthly_transaction_summary`.
   - Epic 3 currently does not define components/pages for these.
   - **Suggested PRDs**: Add `PRD-3-06: Holdings Summary` and `PRD-3-07: Transactions Summary` (even if “v1 minimal”).

2. **Snapshot download/export UX**
   - Epic 2 capabilities mention user export/download.
   - Epic 3 has no explicit UI story for “download JSON”.
   - **Suggested PRD**: `PRD-3-08: Snapshot Export (JSON)`.

3. **Manual refresh trigger + status indicator**
   - Epic 1 mentions manual sync triggers; Epic 2 describes jobs; Epic 3 is where the button/status should live.
   - **Suggested PRD**: `PRD-3-09: Refresh Snapshot / Sync Status Widget` (with throttling + clear state).

---

## Cross-Epic Gaps & Missing Stories

### 1. **Sync Orchestration Story** (Spans Epic 1 & 2)
- **Gap**: Epic 1 covers sync jobs, Epic 2 assumes synced data, but no PRD defines the orchestration:
  - When do syncs run? (daily, on-demand?)
  - What triggers snapshot job after sync completion?
  - Failure recovery: retry sync before snapshot?
- **Suggested PRD**: "PRD-1-11: Sync-to-Snapshot Pipeline" (after Epic 1 #6, before Epic 2)

### 2. **Enrichment Integration** (Epic 1 Reference, No PRD)
- **Gap**: Epic 1 narrative mentions "consistent enrichment," but no PRD details:
  - What fields are enriched? (asset_class, sector, institution_name?)
  - Source of enrichment data? (Plaid, third-party, manual?)
  - Handling of missing enrichment (null vs. 'unknown')?
- **Suggested PRD**: "PRD-1-13: Plaid Data Enrichment Service" (before Epic 2 #3, #4)

### 3. **Liability Snapshots** (Epic 2 Omission)
- **Gap**: Epic 2 aggregates investments/transactions but liabilities only in core net worth (PRD-2-02)
  - No breakdown by liability type
  - No interest rate tracking for educational scenarios
  - No liability-specific deltas (debt paydown tracking)
- **Suggested PRD**: "PRD-2-08: Liability Allocation in Snapshots" (insert after PRD-2-04)

### 4. **Curriculum Integration Hooks** (Epic 3 Missing)
- **Gap**: Epic 1/2 narratives mention "curriculum modules" and "AI context," but no PRD for:
  - How does AI query snapshots? (API endpoint, RAG ingestion job?)
  - What curriculum triggers snapshot generation? (lesson completion, quiz?)
  - How are snapshots annotated for educational context? (scenario tagging?)
- **Suggested PRD**: "PRD-3-11: Curriculum-Snapshot Integration API" (end of Epic 3)

### 5. **Historical Account Changes** (Not Covered)
- **Gap**: Snapshots capture point-in-time, but no story for tracking:
  - Account additions/deletions over time (for explaining net worth changes)
  - Account re-linking (Plaid Item refresh)
  - Institutional name changes (e.g., Schwab acquires Ameritrade)
- **Suggested PRD**: "PRD-1-14: Account Event Log" (after Epic 1 #1)

### 6. **Multi-User Snapshot Comparison** (Epic 3 Gap)
- **Gap**: Epic 1 has account sharing, but no UI story for:
  - Parents comparing their snapshot to children's
  - Anonymized peer comparisons (educational value)
  - Portfolio comparison tool (allocation drift between users)
- **Suggested PRD**: "PRD-3-12: Shared Portfolio Comparison View"

### 7. **Data Archival & Compliance** (Cross-Epic)
- **Gap**: No epic covers:
  - GDPR right-to-delete (cascade to snapshots, positions, transactions?)
  - Data retention policy (how long keep inactive accounts?)
  - Audit logging (who accessed/exported whose data?)
- **Suggested Epic**: "Epic 4: Compliance & Data Governance"

### 8. **Error Recovery UI** (Epic 3 Gap)
- **Gap**: Epic 1/2 have error logging (job failures, null fields), but no UI for users to:
  - See why sync failed (Item re-auth needed?)
  - Retry failed operations
  - Understand data staleness warnings
- **Suggested PRD**: "PRD-3-13: Sync Status & Error Recovery Page"

---

## Sequencing Concerns

### Circular Dependency Risk
- **Epic 1 PRD #4** (Other Income) says "include in FinancialSnapshotJob aggregation" with dependency "Epic 2 stub"
- **Epic 2 PRD-2-02** (Core Job) depends on synced data from Epic 1
- **Risk**: If OtherIncome not in Epic 2 core, it's forgotten → net worth incomplete
- **Solution**: Either move OtherIncome to Epic 2 PRD-2-02 requirements, or add PRD-2-08 for extending job with Epic 1 additions

### UI-Before-Validation Risk
- **Epic 3** (when written) will likely depend on Epic 2 PRD-2-07 (admin validation)
- If Epic 3 PRDs created before Epic 2 complete, may discover schema issues
- **Recommendation**: Implement Epic 2 PRDs #1-#6, validate with #7, *then* start Epic 3

### Test Data Gap
- No epic mentions test data generation (factories, seeds)
- **Risk**: Cannot test Epic 3 UI without realistic snapshots
- **Suggestion**: Add "PRD-2-00: FactoryBot Fixtures for Snapshots" as dependency for all Epic 2 PRDs

---

## Consistency Issues

### 1. **Admin Definition**
- **Epic 1**: Uses "admin/parent" role distinction
- **Epic 2 PRD-2-07**: Says "email list or flag" without referencing Epic 1 roles
- **Fix**: Standardize on Epic 1's role system (Devise roles or Pundit policies), document in knowledge_base/auth-model.md

### 2. **Date Ranges**
- **Epic 2 PRD-2-05**: "Last 30 days" for transactions
- **Epic 2 PRD-2-06**: "Last 30 days" for historical net worth
- **Epic 1 PRD #1**: No sync frequency defined (daily? realtime?)
- **Fix**: Add time constants to shared config (e.g., TRANSACTION_SUMMARY_DAYS = 30, HISTORICAL_TREND_DAYS = 90)

### 3. **Currency Handling**
- **Epic 1**: No mention of currency fields on Account/Position
- **Epic 2**: Aggregates values as if single currency
- **Risk**: Multi-currency portfolios (expats, international holdings) break net worth
- **Fix**: Add PRD to Epic 1 for currency normalization service (use forex rates)

### 4. **Field Naming**
- **Epic 1 PRD #2**: `Account.strategy:string`
- **Epic 2 PRD-2-03**: `Position.asset_class` (implied, not defined in Epic 1)
- **Inconsistency**: Where is asset_class added to Position? Missing PRD in Epic 1
- **Fix**: Add "PRD-1-15: Position Enrichment Fields (asset_class, sector)" before Epic 2

### 5. **Job Scheduling**
- **Epic 1**: Uses Solid Queue (mentioned in PRD #7 dependency)
- **Epic 2 PRD-2-02**: Says "Sidekiq cron daily at midnight"
- **Conflict**: Which job processor? Solid Queue vs. Sidekiq?
- **Fix**: Standardize on one (likely Solid Queue based on repo context), update all PRDs

---

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
- **Schema ERD**: Account, Position, Liability, Trust, OtherIncome, FinancialSnapshot relationships
- **Job Dependency Graph**: Which jobs trigger which (sync → snapshot → curriculum?)

**Suggestion**: Add `knowledge_base/architecture/` directory with:
- `data-flow.md`
- `schema-erd.png` (generate from Rails models via rails-erd gem)
- `job-dependencies.md`

---

## Risk Assessment

### High Risk
1. **Job processor mismatch**: Epic 1 references Solid Queue; Epic 2 schedules via Sidekiq cron. This impacts implementation and ops.
2. **Currency assumption**: Aggregations assume single-currency values; will silently misstate net worth for multi-currency users.
3. **Schema decisions can ripple**: `snapshot_at:datetime` vs “per-day uniqueness” (date) affects idempotency, UI “as-of” display, and delta logic.

### Medium Risk
1. **Trust FK Cascade**: Account deletion could orphan or incorrectly delete trusts
2. **No Test Data Strategy**: Cannot efficiently test without realistic fixtures
3. **UI charting without a library**: Increased fragility/cross-browser quirks; higher test burden for visual correctness

### Low Risk
1. **Duplicate Null Detection PRDs** (#5, #12): Wastes effort but not breaking
2. **Historical Data Duplication** (PRD-2-06): Inefficient but functionally sound
3. **Admin Auth Inconsistency**: Can be fixed with policy class, no schema impact

---

## Recommendations by Priority

### P0 (Blocking)
1. **Resolve job processor + scheduling**: Confirm Solid Queue vs Sidekiq (and cron mechanism), then update Epic 1/Epic 2 wording to match.
2. **Lock snapshot identity rules**: Decide whether snapshots are per-`date` (recommended) or per-`datetime`, and update Epic 2 + Epic 3 acceptance criteria accordingly.
3. **Close the Epic 2 → Epic 3 contract**: Ensure snapshots include the fields Epic 3 tooltips/AC require (pct + value, and clear denominator definitions).

### P1 (High Value)
4. **Create Missing Docs**: UI style guide, templates, auth model, architecture diagrams
5. **Add Enrichment PRD**: Define asset_class/sector population (Epic 1) before Epic 2 depends on it
6. **Consolidate Null Detection**: Merge Epic 1 PRD #5 and #12 into single comprehensive story

### P2 (Quality)
7. **Add Test Data PRD**: FactoryBot/seeds strategy before Epic 2 implementation
8. **Standardize Admin Roles**: Document Devise/Pundit approach, unify references
9. **Add Sync Orchestration PRD**: Define sync-to-snapshot pipeline (Epic 1/2 boundary)

### P3 (Future-Proofing)
10. **Add Compliance Epic**: GDPR, audit logs, data retention (can defer to later)
11. **Add Account Event Log**: Track historical changes (nice-to-have for education)
12. **Add Comparison Views**: Multi-user portfolio comparison (Epic 3 enhancement)

---

## Summary

**Epic 1** is well-structured with clear HNW extensions, but has minor inconsistencies (duplicate PRDs, missing enrichment story) and needs better cascade delete strategy for trusts.

**Epic 2** has excellent atomic breakdown and JSON schemas, but makes assumptions about Epic 1 completion (asset_class field, sync frequency) and has unclear currency/admin handling. Historical data duplication is inefficient.

**Epic 3** is now in good shape for a v1 UI slice (PRD-3-01..PRD-3-05). The remaining work is less about "writing Epic 3" and more about making the Epic 2 snapshot schema precisely satisfy Epic 3's UI expectations, plus adding a small set of UI PRDs for holdings/transactions export and refresh/status.

**Cross-Epic Gaps** include sync orchestration, enrichment definition, liability detail, currency normalization, test data strategy, and compliance/audit (potentially Epic 4).

**Next Steps**:
1. Resolve cross-epic mismatches (job processor, admin auth, snapshot identity/date semantics).
2. Add missing PRDs to Epic 1 (enrichment fields population, currency normalization, optional event log).
3. Extend Epic 2 where needed to meet UI contracts (allocation/sector values, liabilities breakdown, export API, retention/deletion policy).
4. Extend Epic 3 with the missing UI stories implied by Epic 2 (holdings/transactions summary pages, snapshot export, refresh/status).
5. Create/commit the referenced UI and architecture docs (style guide/templates, ERD, data flow, job graph).

This will transform three disjointed epics into a coherent, implementable roadmap for HNW financial education platform.

---

## Eric's Responses to Feedback (GROK_EAS annotations)

### Epic 1 Clarifications
✅ **Trust Model**: Values should be nullable. Owner should be either trust or individual. Trust values from EAS: SFRT, JSIT, QSIT, SFIT, SDIT.
✅ **Other Income**: Keep simple for now, adjust later when necessary
✅ **Null Detection**: Consolidate PRD #5/#12, make institution-aware by logging null patterns keyed on `PlaidItem.institution_id`
✅ **Account Sharing**: Not bidirectional, only parent (admin) to child
✅ **Holdings Enrichment**: P0 blocker - build model from JPMC holding data, confirm via schema.rb
✅ **Currency Normalization**: Plaid returns `iso_currency_code` - ALL CURRENCY IS USD for V1, address multi-currency in future epic
✅ **Account Classifications**: Provided comprehensive list of Asset Strategy, Asset Class, and Asset Strategy Detail mappings

### Epic 2 Clarifications
✅ **snapshot_at**: Prefer `snapshot_date:date` + composite unique index over datetime
✅ **Job Scheduler**: Solid Queue confirmed via README - update all PRDs, use `config/recurring.yml`
✅ **Position vs Holding**: Holding terminology is correct, use `institution_value`. Position is deprecated (pre-Plaid naming)
✅ **Historical Trends**: Prefer option (b) - remove from `data` JSON, let Epic 3 query FinancialSnapshot history via scope
✅ **Asset Allocation**: Use definitions from holdings file as provided by Plaid
✅ **Sector Weights**: Use definitions in holdings file from Plaid, address enrichment in later epic
✅ **Admin Roles**: Should be specific role (admin, parent, child)
✅ **OtherIncome**: Move to Epic 2 PRD-2-02 (resolve circular dependency)
✅ **Test Data**: Can be derived from current tables (holdings, transaction, account) - has 26 million dollar portfolio
✅ **Sync Frequency**: On-demand for testing, daily for production

### Epic 3 Clarifications
✅ **Value + Percent**: Store both percentage and absolute value per bucket in Epic 2 JSON
✅ **Routing**: Suggest nested resources: `NetWorth::DashboardController`, `NetWorth::AllocationsController`
✅ **Chart Library**: Agree with using lightweight DaisyUI progress bars, will replace with JS charts in future epics
✅ **Missing PRDs**: Agree to add PRD-3-06 (Holdings Summary), PRD-3-07 (Transactions Summary), PRD-3-08 (Export), PRD-3-09 (Refresh Widget)

### Cross-Epic Decisions
✅ **Sync Orchestration**: Agree - need PRD-1-11
✅ **Enrichment**: Agree - need PRD-1-13. Note: enriched_transactions unclear when/from which source enriched. Suggest adding field indicating investment or transaction enrichment + date pulled
✅ **Liabilities**: Need to add liabilities model/table synced from Plaid (new PRD in Epic 1) and new snapshot aggregation in Epic 2
🔮 **Curriculum Integration**: Will add in future epic, ignore for V1
🔮 **Historical Account Changes**: Track as future story
🔮 **Multi-User Comparison**: Track as future story
🔮 **Compliance/GDPR**: Track as future story - no GDPR compliance in scope for V1
🔮 **Architecture Docs**: Move to Epic 4

### Actions Required
See `next-epics.md` for organized follow-up stories and updated PRD sequencing

---

## Final Review: Remaining Concerns

After reviewing Eric's comprehensive responses, I have **no additional concerns or objections**. All critical issues have been addressed:

✅ **P0 Blockers Resolved**:
- Holdings enrichment fields confirmed as P0
- Position→Holding naming resolved
- Job scheduler confirmed (Solid Queue)
- snapshot_date:date confirmed

✅ **Architecture Decisions Locked**:
- USD-only for V1 (multi-currency deferred)
- Trust values from EAS confirmed
- Liabilities model scope defined
- OtherIncome moved to Epic 2
- Historical trends: query on-demand (not stored in JSON)

✅ **Epic 3 Approach Confirmed**:
- Nested routing (NetWorth::*)
- Value + percent in JSON
- Chartkick for placeholder charts
- Missing PRDs identified (3-06 through 3-09)

**Recommendation**: The project is ready to proceed with implementation. `next-epics.md` contains the complete revised roadmap organized by epic with proper sequencing.
