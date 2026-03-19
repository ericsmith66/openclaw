**Epic-7: Real Transaction Views Implementation (Leveraging Holdings Patterns)**

**Overview**  
Build production-ready transaction views (Summary, Cash, Credit, Transfers, Investments) using real Plaid-synced data from the Transaction model. Reuse patterns from the portfolio/holdings implementation (e.g., HoldingsGridComponent style, table components, filter selectors, sync timestamps) to accelerate development and ensure UI consistency. No mocks—YAML/provider layer skipped since live sync is functional. Focus on enhancing existing TransactionsController + views with type-specific refinements, account filtering, recurring detection, transfers deduplication, and aggregated summary.

**Vision Tie-in**  
Enables HNW families to see full cash flow patterns (spending vampires, internal transfers, recurring liabilities) alongside holdings/net worth—core to the AI tutor curriculum for wealth preservation.

**Scope**
- Atomic PRDs cover: architectural alignment plan, filter enhancements (global account selector), type-specific UI polish (icons, columns, deduplication), recurring logic & summary section, live data optimizations (STI fix, pagination, sorting).
- Excludes: advanced AI analysis (defer to post-stability), CSV export, full search backend.

**Dependencies**
- Existing: Transaction model (STI), SyncTransactionsJob, PlaidItem/Account associations, Holdings UI patterns (table/grid components, selectors).
- Prior: Epic-5 (Holdings grid & views), Plaid sync stability.

**Timeline**  
1-2 weeks (assuming polish pass from previous feedback merged).

**Backlog**

| Priority | PRD | Feature | Status | Dependencies |
|----------|-----|---------|--------|--------------|
| 1 | PRD-7.1 | Architectural Alignment & Plan | Todo | None |
| 2 | PRD-7.2 | Global Account Filter & Filter Bar Refinements | Todo | #1 |
| 3 | PRD-7.3 | Type-Specific View Polish (Cash, Credit, Investments) | Todo | #2 |
| 4 | PRD-7.4 | Transfers View & Deduplication Logic | Todo | #2 |
| 5 | PRD-7.5 | Summary View Enhancements & Recurring Section | Todo | #3, #4 |
| 6 | PRD-7.6 | Live Data Optimizations (STI Fix, Pagination, Sorting) | Todo | #5 |

**PRD-7.1: Architectural Alignment & Implementation Plan for Transaction Views**

**log requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results - If asked to review please create a separate document called <epic or prd name>-feedback.md

**Overview**  
Create a comprehensive plan aligning transaction views with existing holdings/portfolio patterns (e.g., HoldingsGridComponent → TransactionGridComponent style, account selectors, sync-aware UI). Define migration from current partial/table setup to reusable ViewComponents where beneficial, while preserving live Plaid data flow.

**Requirements**
- Functional: Document routes (/transactions/summary, regular, credit, transfers, investment); controller data loading (Transaction scopes by type/account); component reuse strategy (extend transaction_table_component.rb where possible); recurring detection service; transfers deduplication (prefer source leg).
- Non-functional: Use existing auth/RLS; no new models/migrations unless minor (e.g., recurring_flag column optional); mobile-first DaisyUI; Turbo for filter updates.
- Rails Guidance: Leverage TransactionsController (add account_id param handling); scope queries (e.g., Transaction.where(type: 'RegularTransaction').where(account_id: params[:account_id])); reuse saved_account_filter_selector_component.rb pattern for dropdown.

**Architectural Context**  
Rails MVC: TransactionsController actions load filtered scopes → views use existing transaction_table_component + new/updated components (e.g., TransactionRowComponent for icons/badges/arrows). PostgreSQL RLS ensures user isolation; attr_encrypted on Plaid tokens. plaid-ruby handles /transactions/get. Reference schema: Transaction STI (RegularTransaction, InvestmentTransaction, CreditTransaction), Account linkage. No Ollama/RAG here—focus stability. Pattern match: Holdings table → transaction table; account selector reuse; sync timestamps from holdings.

**Acceptance Criteria**
- Plan covers all Epic-7 PRDs with sequence, file touchpoints, and reuse map.
- Routes/actions aligned with holdings (e.g., account filter param consistent).
- STI categorization rule defined (post-sync: if account.investment? → force InvestmentTransaction).
- Recurring detection outlined (simple scan or Plaid flag + heuristic).
- Risks noted: query performance (add indexes on date/type/account_id), deduplication accuracy.
- Plan concise (<1000 words), actionable.

**Test Cases**
- RSpec: Controller scopes return expected records with account filter.
- Manual: Load each /transactions/[subtype]; apply account filter → only matching records; verify no mock data references.

**Workflow**  
Junie: Pull master, branch `feature/prd-7.1-transaction-arch-plan`. Use Claude Sonnet 4.5. Draft plan.md in knowledge_base/prds/; ask clarifying questions (e.g., exact recurring threshold, family account definition for external badge). Commit green. Human: Review for completeness/consistency with holdings.

Next steps: Once PRD-7.1 approved, proceed to PRD-7.2 (filters) or confirm repo state on specific files (e.g., transaction_table_component usage)? Questions on holdings patterns to mirror?