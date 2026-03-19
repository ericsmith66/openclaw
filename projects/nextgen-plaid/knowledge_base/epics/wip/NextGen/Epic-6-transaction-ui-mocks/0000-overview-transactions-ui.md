The **Transactions Exploration Epic** (let's call it **Epic-TX-UI**) focuses on building clean, separated static/mock views for transaction data exploration. This epic comes after core sync stability (holdings/transactions jobs are working, per recent commits like Epic 5 UI fixes on Feb 9, 2026, and existing `app/views/transactions/` with index/investment/regular/show). It uses static mock data to prototype UX without DB hits, allowing rapid iteration before wiring live queries.

**Epic Goal**  
Provide HNW users (22-30 demographic) with noise-free, professional views to explore transactions by logical mental model: cash (depository), investments, credit cards, transfers (especially monthly income flows), and a high-level summary. Each view is a dedicated static page (or tabbed section prototype) using Tailwind + DaisyUI + ViewComponent, with mock data mimicking real Plaid shapes. This sets the stage for a unified /transactions dashboard later, while keeping views modular and testable.

**Why separate views first?**
- Matches your stated preference: avoid co-mingling types; treat transfers specially; highlight monthly/large patterns.
- Builds on existing repo: `index.html.erb`, `investment.html.erb`, `regular.html.erb` suggest early separation (regular vs investment); we can extend/replace with dedicated static prototypes.
- Atomic and low-risk: pure frontend/mocks, no Plaid/job changes; easy to review/merge.
- Enables quick feedback loop with Aider before dynamic filtering.

**Proposed Atomic PRDs (5 total, one per view type)**  
Each PRD will be self-contained, focused on one static ERB + supporting mocks/components. Scope: hardcoded mock transactions (PORO or YAML), no controller/DB logic beyond basic render. Use ViewComponents for rows/tables/insights. Pages accessible via temporary routes (e.g., /transactions/mock-cash) during prototyping; later consolidate.

1. **PRD-TX-UI-01: Static Mock Cash Accounts View**  
   Focused on depository (checking/savings) transactions only. Table with date/description/category/amount/account; monthly accordions; basic filters (search, date presets, large threshold); mock summaries (monthly spend/in totals).

2. **PRD-TX-UI-02: Static Mock Investments Transactions View**  
   Investment-specific (buy/sell/dividend/interest/capital gain/loss from /investments/transactions/get). Columns include security/ticker/symbol, quantity, price, type; highlight trades vs income; mock portfolio context sidebar.

3. **PRD-TX-UI-03: Static Mock Credit Cards View**  
   Credit/liabilities transactions (charges, payments, pending/auth). Emphasize pending, rewards/cashback if present, monthly balance trends; red/green for charges/payments; mock utilization insights.

4. **PRD-TX-UI-04: Static Mock Transfers View**  
   Narrow to inter-account transfers (Plaid category/transfer subtype or manual filter). Direction icons (in/out), focus on monthly income patterns (e.g., investment → checking averages); timeline/chart stub for recurring inflows; exclude noise from other types.

5. **PRD-TX-UI-05: Static Mock Transactions Summary View**  
   High-level overview aggregating across types: monthly totals in/out by category, top large txns, transfer income trends, top merchants/categories pie/text list. Use cards/charts stubs (Chart.js minimal or DaisyUI progress); serves as "home" or dashboard entry.

**Prioritization & Sequencing**  
Start with #1 (Cash) as default/entry point, then #5 (Summary) for quick wins, then the specialized ones (#2-4). Each can be a separate feature branch; merge progressively.

**Shared Guidelines Across PRDs**
- Mock data: ~50-100 varied transactions per view (YAML or service class); include pending, recurring flags, Plaid-like fields (personal_finance_category, merchant_name, iso_currency_code).
- Design: Professional/minimalist (DaisyUI tabs/cards/tables, subtle colors: green in/red out); responsive/mobile-first.
- Components: Reusable TransactionRowComponent, MonthlyGroupComponent, FilterStubComponent.
- No live data/DB: All static locals in controller or dedicated mock service.
- Testing: RSpec view specs + component specs; optional Capybara for happy paths.
- Workflow: Aider pulls master → new branch per PRD → implement → green commits → push for review.

This epic keeps us iterative and aligned with "defer full UI until core sync stable" while prototyping the separated UX you want.

Ready to generate the first PRD (e.g., Cash Accounts) in full detail for Aider? Or prefer starting with the Summary view (#5) as a capstone? Any tweaks to the 5-view split?