# Epic 4: Future Enhancements (Post-V1)

**Purpose**: This document contains stories marked as 🔮 future work by Eric, deferred until after Epic 1-3 completion.

---

## Epic 4 Overview

**Epic Title**: Advanced Features & Non-V1 Enhancements

**User Capabilities**: Curriculum integration, historical account change tracking, multi-user comparison, compliance/GDPR, architecture docs, multi-currency.

**Fit into Big Picture**: Post-V1 polish — enables deeper educational context, audit trails, collaboration features, and international expansion.

---

## PRD-4-01: Curriculum Integration (🔮 Future)

**Overview**
Link financial snapshots to curriculum modules (e.g., "Net Worth Module 1") for contextualized learning with live data.

**Scope**
- Add curriculum_module_id to snapshots (optional FK).
- Build curriculum module model/UI to display associated snapshots.
- API endpoints for AI to query snapshots by curriculum context.

**Dependencies**
- Curriculum models (future epic).
- Epic 2 FinancialSnapshot model.

**User Capabilities**
- Advisors (AI) query: "Show me student's net worth snapshot for Module 3."
- Interns see curriculum context in snapshot view: "This snapshot supports: Estate Planning 101."
- Curriculum modules display live financial data from associated snapshots.

**Suggested Branch**: `feature/prd-4-01-curriculum-integration`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-02: Historical Account Changes Tracking (🔮 Future)

**Overview**
Track changes to account.name, account.strategy, account.trust_id over time for audit trail and "what changed" views.

**Scope**
- Use PaperTrail gem or custom AccountChangeLog model.
- Admin view to list historical changes: "Account XYZ changed strategy from 'Core Equity' to 'Fixed Income' on 2026-02-15."
- Timeline UI showing account lifecycle (created, updated, closed).

**Dependencies**
- Account model (Epic 1).

**User Capabilities**
- Admins view audit log: "Who changed what, when?"
- Interns see account history: "This account was renamed from 'Savings' to 'Emergency Fund' on Jan 1."
- AI queries: "What accounts changed in last 30 days?"

**Suggested Branch**: `feature/prd-4-02-account-change-tracking`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-03: Multi-User Snapshot Comparison (🔮 Future)

**Overview**
Allow admins to compare snapshots across users (anonymized) for cohort analysis.

**Scope**
- Admin-only comparison page with side-by-side charts.
- Privacy: Anonymize user names ("User A", "User B").
- Metrics: Compare net worth, allocation, sector weights across users.
- Cohort analysis: "All users with >$1M net worth have 60%+ equity allocation."

**Dependencies**
- Epic 2 snapshots, Epic 3 charts.

**User Capabilities**
- Admins compare: "How does User A's allocation compare to User B?"
- Curriculum designers: "What's the average net worth of students in Module 5?"
- AI queries: "Show me allocation distribution across all users."

**Suggested Branch**: `feature/prd-4-03-multi-user-comparison`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-04: Compliance & GDPR (🔮 Future)

**Overview**
Add data export/delete features for GDPR, audit logs for data access.

**Scope**
- User-initiated full data export (all snapshots, holdings, transactions).
- Data deletion flow with confirmation: "Delete all my data."
- Access log model: Track who accessed whose data when.
- GDPR compliance: Right to access, right to be forgotten, data portability.

**Dependencies**
- All models (Epic 1-3).

**User Capabilities**
- Interns: "Export all my data as JSON."
- Interns: "Delete my account and all associated data."
- Admins: "View access log: who accessed User X's data?"
- Compliance: Respond to GDPR requests with audit trail.

**Suggested Branch**: `feature/prd-4-04-compliance-gdpr`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-05: Architecture Documentation (🔮 Future)

**Overview**
Generate architecture diagrams (ERD, data flow) from codebase using gems like rails-erd.

**Scope**
- Install rails-erd, configure for PNG/PDF output.
- Add to knowledge_base/architecture/:
  - `schema-erd.png` (entity relationship diagram)
  - `data-flow.md` (Plaid → Sync → Models → Snapshot → UI)
  - `job-dependencies.md` (which jobs trigger which)
- Automated: Regenerate on schema changes via git hook.

**Dependencies**
- Stable schema (post-Epic 1-3).

**User Capabilities**
- Developers: "See current schema ERD."
- AI: "Understand data flow from Plaid to UI."
- Onboarding: New developers get visual overview.

**Suggested Branch**: `feature/prd-4-05-architecture-docs`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-06: Multi-Currency Support (🔮 Future)

**Overview**
Support non-USD accounts with currency conversion and multi-currency net worth display.

**Scope**
- Add currency:string to accounts/holdings (e.g., "USD", "EUR", "GBP").
- Integrate exchange rate API (e.g., Open Exchange Rates, ECB).
- Snapshot JSON includes currency breakdown:
  ```json
  "net_worth_by_currency": {
    "USD": 20000000.00,
    "EUR": 3000000.00,
    "GBP": 1500000.00
  },
  "net_worth_usd_equivalent": 26174695.59
  ```
- UI: Toggle between "USD Equivalent" and "Multi-Currency View."

**Dependencies**
- Epic 2 snapshots.

**User Capabilities**
- Interns with international holdings: "See my net worth in EUR + USD."
- AI queries: "What's my GBP exposure?"
- Admins: "Set base currency for conversions."

**Rationale**: V1 is USD-only per Eric's feedback. This epic defers multi-currency to post-V1.

**Suggested Branch**: `feature/prd-4-06-multi-currency`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-07: Advanced Performance Analytics (🔮 Future)

**Overview**
Replace PRD-3-04 placeholder with full interactive charting (time-weighted returns, Sharpe ratio, benchmark comparison).

**Scope**
- Install charting library (Chart.js via chartkick, or D3.js for advanced).
- Metrics:
  - Time-weighted return (TWR)
  - Money-weighted return (MWR)
  - Sharpe ratio
  - Max drawdown
  - Benchmark comparison (S&P 500, custom)
- Date range picker: "Show performance for last 1Y, 3Y, 5Y."
- Export charts as PNG/PDF.

**Dependencies**
- Epic 2 historical snapshots.
- Epic 3 performance placeholder.

**User Capabilities**
- Interns: "See my portfolio's Sharpe ratio."
- AI: "How did my portfolio perform vs S&P 500?"
- Curriculum: Teach risk-adjusted returns with live data.

**Suggested Branch**: `feature/prd-4-07-advanced-performance`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-08: Detailed Transaction Views (🔮 Future)

**Overview**
Expand PRD-3-07 transaction summary into full paginated transaction list with search/filter.

**Scope**
- Full transaction list page: `/net_worth/transactions/all`
- Table columns: Date, Description, Amount, Category, Account
- Search: By description, category
- Filter: By date range, account, category, amount range
- Pagination: 50 per page
- Export: CSV download

**Dependencies**
- Epic 1 Transaction model.
- Epic 3 PRD-3-07 summary.

**User Capabilities**
- Interns: "Search for all 'Starbucks' transactions."
- Interns: "Filter transactions by category: 'Dining'."
- Admins: "Export user's transactions as CSV."

**Suggested Branch**: `feature/prd-4-08-transaction-list`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-09: Detailed Holdings Views (🔮 Future)

**Overview**
Expand PRD-3-06 holdings summary into full holdings list with search/filter/sort.

**Scope**
- Full holdings list page: `/net_worth/holdings/all`
- Table columns: Ticker, Name, Quantity, Cost Basis, Current Value, Gain/Loss, % Portfolio
- Search: By ticker, name
- Filter: By account, asset_class, sector
- Sort: By any column
- Export: CSV download

**Dependencies**
- Epic 1 Holding model.
- Epic 3 PRD-3-06 summary.

**User Capabilities**
- Interns: "Search for all Apple holdings."
- Interns: "Filter holdings by sector: Technology."
- Admins: "Export user's holdings as CSV."

**Suggested Branch**: `feature/prd-4-09-holdings-list`

**LLM**: Claude Sonnet 4.5

---

## PRD-4-10: Liabilities Dashboard (🔮 Future)

**Overview**
Build dedicated liabilities dashboard showing debt paydown tracking, interest rates, payment schedules.

**Scope**
- Liabilities page: `/net_worth/liabilities`
- Metrics:
  - Total debt
  - Debt by type (mortgage, credit card, student loan)
  - Average APR
  - Next payment due
  - Payoff projections
- Chart: Debt paydown over time
- Table: List of all liabilities with details

**Dependencies**
- Epic 1 PRD-1-12 Liability model.
- Epic 2 PRD-2-08 liability breakdown.

**User Capabilities**
- Interns: "See my debt payoff timeline."
- AI: "What's my highest interest debt?"
- Curriculum: Teach debt management with live data.

**Suggested Branch**: `feature/prd-4-10-liabilities-dashboard`

**LLM**: Claude Sonnet 4.5

---

## Summary of Epic 4 PRDs

**Priority Sequence** (after Epic 1-3 complete):

**P1 (High Value)**:
- PRD-4-05: Architecture Documentation (foundational for future work)
- PRD-4-07: Advanced Performance Analytics (completes Epic 3 placeholder)
- PRD-4-08: Detailed Transaction Views (expands Epic 3 summary)
- PRD-4-09: Detailed Holdings Views (expands Epic 3 summary)
- PRD-4-10: Liabilities Dashboard (completes liability tracking)

**P2 (Medium Value)**:
- PRD-4-01: Curriculum Integration (enables educational features)
- PRD-4-02: Historical Account Changes (audit/compliance)
- PRD-4-03: Multi-User Comparison (cohort analysis)

**P3 (Low Priority / Compliance)**:
- PRD-4-04: Compliance & GDPR (required for EU users, not V1)
- PRD-4-06: Multi-Currency Support (international expansion)

---

## Epic 4 Narrative

**Epic Title**: Post-V1 Enhancements & Advanced Features

**Epic Overview**: Expand V1 foundation with advanced analytics, full CRUD views, compliance features, and international support. Transform basic dashboard into comprehensive financial education platform with deep insights, audit trails, and multi-user collaboration.

**User Capabilities**:
- Interns: Advanced charts, detailed transaction/holdings lists, debt tracking, multi-currency support
- Admins: Compliance features, user comparison, audit logs
- AI Advisors: Curriculum integration, performance analytics, cohort queries

**Fit into Big Picture**: Completes the vision of a world-class HNW financial education platform with institutional-grade features, compliance readiness, and global reach.

---

**Next Steps**: Complete Epic 1-3 implementation first. Epic 4 stories can be prioritized based on user feedback and business needs post-V1 launch.
