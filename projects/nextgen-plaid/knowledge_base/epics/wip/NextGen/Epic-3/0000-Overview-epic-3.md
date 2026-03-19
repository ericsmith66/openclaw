**Epic 3: Net Worth Dashboard Polish & Components**

**Epic Overview**  
Polish and enhance the Net Worth dashboard scaffolded in Epic 2 (primarily PRD-2-09 net worth dashboard UI implementation from Jan 24, 2026 commit 31187fe, plus supporting PRDs: 2-01 snapshots, 2-06 historical trends, 2-07 admin preview, 2-08 export API). Transform basic or placeholder displays into refined, interactive ViewComponents using Tailwind + DaisyUI: hero summary card with deltas, asset allocation charts, sector breakdowns, performance trends, and later summaries/export/refresh. All components source data exclusively from `FinancialSnapshot.latest_for_user(current_user).data` JSON blobs for efficiency and consistency. End state: clean, professional, mobile-responsive dashboard delivering immediate wealth visibility and visual insights to support AI tutor curriculum for young HNW users (allocation drift, performance trends, reinvestment opportunities).

**User Capabilities**
Authenticated users view a unified `/net_worth` dashboard (single route, Turbo-driven sections) with aggregated net worth hero stats, interactive allocation/sector/performance visuals, summary cards, export options (JSON/CSV), and manual refresh (rate-limited 1/min). Interactions include hover tooltips (tap on mobile), view toggles, client-side sorting, Turbo Frame expands/updates. Admins use Mission Control for previews. Fully responsive (≥44px touch targets), WCAG 2.1 AA accessible, professional design with consistent empty states and error handling.

**Fit into Big Picture**  
Creates the core visual interface for HNW families to see aggregated wealth clearly—key "aha" moment grounding curriculum simulations (e.g., drift detection, Monte Carlo inputs). Builds directly on Epic 2's stable snapshot + export foundation; defers heavy real-time recompute.

**Note on Work Done in Epic 2**  
Epic 2 established data foundation and initial UI: FinancialSnapshot model/job (PRD-2-01), historical trends (2-06), admin preview/validation (2-07), snapshot export API (2-08), and base net worth dashboard UI (PRD-2-09, commit 31187fe Jan 24, 2026). Repo shows `app/views/net_worth/` with subdirs (allocations, dashboard, holdings, income, performance, sectors, transactions)—indicating structured views exist. No `app/components/net_worth/` yet, no PRD-3 commits/branches visible. Dashboard likely shows real snapshot data (holdings, balances, trends) but remains unpolished (missing hero deltas card, interactive charts/toolips, Turbo interactions, consistent styling, empty states, breadcrumbs).

**PRD Summary Table (Epic 3 – 9 PRDs Total)**  
| Priority | PRD Title                              | Scope                                                                 | Dependencies                  | Suggested Branch                              | Notes                                      |
|----------|----------------------------------------|-----------------------------------------------------------------------|-------------------------------|-----------------------------------------------|--------------------------------------------|
| 10       | Net Worth Summary Card Component       | Hero card: total NW + day/30d deltas ($ + %) with colors/tooltips    | PRD-2-09 layout + snapshots  | feature/prd-3-10-nw-summary-card             | Replace basic hero display first           |
| 11       | Asset Allocation View                  | Interactive pie/bar chart + tooltips (pct + value); toggle           | PRD-3-10                     | feature/prd-3-11-allocation-view             | Enhance allocations/sectors data           |
| 12       | Sector Weights View                    | Bar chart + sortable table (pct + value)                             | PRD-3-11                     | feature/prd-3-12-sector-weights              | Build on sectors view/subdir               |
| 13       | Performance View                       | Chartkick line chart for 30-day NW trend (historical query)          | PRD-3-12                     | feature/prd-3-13-performance-view            | Refine performance subdir/trends           |
| 14       | Holdings Summary View                  | Top holdings table + Turbo expand to full list                       | PRD-3-13                     | feature/prd-3-14-holdings-summary            | Enhance holdings subdir                    |
| 15       | Transactions Summary View              | Monthly income/expenses cards + link to full                         | PRD-3-14                     | feature/prd-3-15-transactions-summary        | Enhance income/transactions subdirs        |
| 16       | Snapshot Export Button                 | Dropdown (JSON/CSV) tied to PRD-2-08 export API                      | PRD-3-15                     | feature/prd-3-16-export-button               | Integrate export functionality             |
| 17       | Refresh Snapshot / Sync Status Widget  | Refresh button + badge, rate limit, Turbo feedback                   | PRD-3-16                     | feature/prd-3-17-refresh-widget              | Async sync UX                              |
| 18       | Final Dashboard Polish & Breadcrumbs   | Breadcrumbs, mobile tweaks, empty states, QA/consistency pass        | PRD-3-17                     | feature/prd-3-18-final-polish                | Overall refinement & accessibility         |

**Key Guidance for All PRDs in Epic 3**
- **Architecture**: Single route `/net_worth` with Turbo-driven sections—NOT separate pages for allocations/sectors/etc. Sub-views use Turbo Frame replacements or slide-over modals.
- **Components**: Use nested ViewComponents under `app/components/net_worth/`. Create `NetWorth::BaseCardComponent` as shared base. See `app/views/net_worth/components/README.md` for hierarchy diagram. **No ActiveRecord associations in component rendering**—receive only plain Ruby hashes/arrays from snapshot JSON.
- **POC Deprecation**: Mark any PRD-2-09 disposable code with `# TODO(Epic3): Replace with NetWorth::XComponent` before refactoring.
- **Data Schema**: Reference `knowledge_base/schemas/financial_snapshot_data_schema.md` for complete JSON structure with chart color palette. Validate using `FinancialSnapshotDataValidator` PORO class (includes schema + integrity checks). Add `data_schema_version: 1` to all new snapshots.
- **Data Access**: Always `FinancialSnapshot.latest_for_user(current_user).data` (structured keys: net_worth_summary, asset_allocation[], sector_weights[], historical_totals[], etc.). **Never query multiple snapshots for history**—use pre-computed `historical_totals` array. Defensive coding: `data['key'] || {}` fallbacks everywhere.
- **Error Handling**: Every PRD includes "Error Scenarios & Fallbacks" section: nil snapshot → `EmptyStateComponent(context: :no_snapshot)`; JSON parse failure → log to Sentry + "Data temporarily unavailable"; Turbo failures → flash alert + refresh link.
- **Empty States**: Use single `NetWorth::EmptyStateComponent` with params: `context` (:no_items, :sync_pending, :data_missing), `message_override` (optional), `cta_path` (optional). Hierarchy: no Plaid accounts → link to Plaid Link; accounts linked but no snapshot → "Sync now"; snapshot exists but missing data → generic message.
- **Turbo Frames**: Unique IDs per zone: `#net-worth-summary-frame`, `#allocation-pie-frame`, `#holdings-table-frame`, `#sector-table-frame`, `#performance-chart-frame`. Use DaisyUI `.skeleton` loaders.
- **Stimulus vs Turbo**: Use Stimulus for data already in DOM (chart toggle, local sort <50 rows, expand/collapse); use Turbo for server data needed (holdings expand >100 rows, sync status updates). Prefer Turbo for Epic 3 data-dependent actions.
- **ViewComponent Previews**: Create preview for each component at `spec/components/previews/net_worth/` with variants (default, empty_state, edge_cases). Mount at `/rails/view_components` in development.
- **Style**: Follow `knowledge_base/style_guide.md` and `templates/` strictly (young adult aesthetic: clean, elegant, no playful elements). Tailwind CSS + DaisyUI. Use DaisyUI color tokens for chart palette.
- **Accessibility**: Target WCAG 2.1 AA. Add `axe-core-capybara` tests. Charts include `<table class="sr-only">` fallback. Use symbols (↑/↓) with colors for deltas. Verify with Chrome DevTools colorblind simulator.
- **Mobile**: Touch targets ≥44×44px. Responsive charts/tables. Tooltips tap-to-show on mobile. Test with Capybara mobile viewport (375×667). No unintended horizontal scroll.
- **Performance**: No new live aggregations—leverage pre-computed JSON snapshots. Add inline comments: `# Performance: using pre-rolled historical_totals from latest snapshot only`. Use `bullet` gem in development to catch N+1s.
- **Security**: Application-level scoping via `current_user.financial_snapshots`. Verify Turbo Stream channels user-scoped: `net_worth:sync:#{current_user.id}`. Add channel authentication tests.
- **Observability**: Tag Sentry errors with `epic:3, prd:"3-XX", component:"ComponentName"`. Log all JSON parse failures, Turbo broadcast failures, rate limit hits.
- **i18n**: US/USD-only for Epic 3. Hard-code `$` and `MM/DD/YYYY`. Defer multi-currency to future epic.
- **Scope**: Transactions/holdings detail views deferred to Epic 4. PRD-3-15 link = "#" with tooltip "Coming soon" or remove link.

### Detailed PRDs (Priorities 10–13)

#### PRD-3-10: Net Worth Summary Card Component

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- In the log put detailed steps for human to manually test and what the expected results.
- If asked to review please create a separate document called <epic or prd name>-feedback.md.

**Overview**  
Implement a prominent hero summary card for total net worth with daily and 30-day deltas ($ and %) including color coding and explanatory tooltips. Replaces any basic NW display in the PRD-2-09 dashboard layout, giving users instant wealth snapshot and change awareness.

**Requirements**
- **Functional**: Display formatted total net worth; day delta ($ and %); 30-day delta ($ and %). Positive = green with ↑, negative = red with ↓. Hover tooltips (tap on mobile) explain: "Day change vs. most recent prior snapshot" and "30-day change from earliest in window". **Add "Last updated [time_ago]" timestamp** showing `snapshot.created_at` in relative format ("3 hours ago"). Empty state: use `EmptyStateComponent(context: :no_snapshot)`.
- **Non-Functional**: Render <500ms; fully responsive (stack vertically on mobile, ≥44px touch targets); ARIA labels for deltas and tooltips; no client-side computation.
- **Rails-Specific**: Create ViewComponent `app/components/net_worth/summary_card_component.rb` inheriting from `NetWorth::BaseCardComponent` with matching ERB template in Turbo Frame `#net-worth-summary-frame`. Integrate into main dashboard view `app/views/net_worth/index.html.erb`. Leverage `number_to_currency`, `number_to_percentage`, `time_ago_in_words`; DaisyUI stat/card classes with skeleton loader.
- **Error Scenarios**: Nil snapshot → `EmptyStateComponent(:no_snapshot)`; corrupt JSON → log Sentry + "Data temporarily unavailable"; Turbo failure → flash alert + refresh link.

**Architectural Context**  
MVC: `NetWorth::DashboardController` (or equivalent) fetches `snapshot = FinancialSnapshot.latest_for_user(current_user)` and passes `data = snapshot&.data || {}` → component receives `summary: data['net_worth_summary'] || {total: , day_delta_usd: , day_delta_pct: , thirty_day_delta_usd: , thirty_day_delta_pct: }`. PostgreSQL RLS enforces isolation; Devise required. Pure presentation—no Ollama here.

**Acceptance Criteria**
- Total net worth shows correctly formatted (e.g., $12,345,678.90).
- Deltas display with proper sign, color, and formatting (e.g., +$45,200 / +3.8%).
- Tooltips appear on hover with accurate explanations.
- No snapshot → shows empty state message.
- Card responsive: full-width desktop, stacked mobile.
- ARIA labels ensure screen reader compatibility.
- No unescaped JSON or sensitive leaks in HTML.

**Test Cases**
- Unit (RSpec): `describe NetWorth::SummaryCardComponent` – mock summary hash, assert rendered HTML matches expected (formatted values, classes for colors).
- Integration: Controller test stubs snapshot; visit /net_worth (or /net_worth/dashboard); expect card selector with correct content.
- Manual: Log in → verify deltas align with known snapshot differences.

**Workflow**  
Use Claude Sonnet 4.5 (default). `git pull origin main`. `git checkout -b feature/prd-3-10-nw-summary-card`. Ask questions and build detailed plan first. Commit only green (tests pass). Open PR for review.

#### PRD-3-11: Asset Allocation View

**Log Requirements**  
(same as above)

**Overview**  
Add interactive asset allocation visualization (default pie chart, toggle to bar) with hover tooltips showing percentage and dollar value. Pulls from snapshot's `asset_allocation` array; enhances existing allocations subdir/view from PRD-2-09.

**Requirements**
- **Functional**: Pie chart via Chartkick; Turbo toggle to horizontal bar. Tooltips: "Equities: 62% ($8.1M)". Optional future click → filter holdings.
- **Non-Functional**: Responsive sizing; graceful zero/missing data handling.
- **Rails-Specific**: `app/components/net_worth/asset_allocation_component.rb` + ERB. Use `chartkick` gem. DaisyUI card wrapper.

**Architectural Context**  
Controller passes `allocation_data = data['asset_allocation'] || []` (array of {class: String, pct: Float, value: Float}). Component renders Chartkick pie/bar config. MVC separation; RLS secure.

**Acceptance Criteria**
- Charts display correct segments/proportions from JSON.
- Toggle switches chart type without full reload (Turbo).
- Hover tooltips show both % and $ value.
- No data → "No allocation details available yet."
- Fully responsive across breakpoints.
- Chart accessible (alt text or fallback table).

**Test Cases**
- Unit: Component spec mocks allocation array → assert Chartkick config and HTML output.
- Integration: Visit dashboard page → assert chart element and toggle interaction works.

**Workflow**  
Claude Sonnet 4.5. Pull main, branch `feature/prd-3-11-allocation-view`. Plan first, small green commits.

#### PRD-3-12: Sector Weights View

**Log Requirements**  
(same)

**Overview**  
Implement sector exposure view with bar chart and sortable table displaying % and $ values per sector. Sources `sector_weights` JSON; builds on sectors subdir from Epic 2.

**Requirements**
- **Functional**: Chartkick bar for top sectors; DaisyUI table below with sortable columns (sector name, %, value). Hover tooltips on bars.
- **Non-Functional**: Turbo for sorting; responsive (table collapses on mobile).
- **Rails-Specific**: `app/components/net_worth/sector_weights_component.rb`. Chartkick + DaisyUI table.

**Architectural Context**  
Data: `sector_data = data['sector_weights'] || []` (array {sector: String, pct: Float, value: Float}). Component handles presentation; secure via RLS.

**Acceptance Criteria**
- Bar chart and table accurately reflect JSON data.
- Table sorting updates view dynamically.
- Tooltips show on bar hover.
- Mobile: table stacks or scrolls cleanly.
- Empty state message shown.
- Accessible: proper table headers/labels.

**Test Cases**
- Unit: Spec mocks data → verify render and sort logic.
- Integration: Assert chart/table presence and sorting behavior on page.

**Workflow**  
Claude Sonnet 4.5. Branch `feature/prd-3-12-sector-weights`.

#### PRD-3-13: Performance View

**Log Requirements**
(same)

**Overview**
Render 30-day net worth performance as interactive Chartkick line chart using pre-computed historical data from latest snapshot JSON. Refines performance subdir and PRD-2-06 trends data.

**Requirements**
- **Functional**: Line chart plotting daily total NW from `data['historical_totals']` array; tooltips with date, value, day-over-day delta.
- **Non-Functional**: No additional DB queries; responsive scaling; ≥44px touch targets.
- **Rails-Specific**: `app/components/net_worth/performance_component.rb` in Turbo Frame `#performance-chart-frame`. **MUST use only** `data['historical_totals']` from latest FinancialSnapshot—do NOT query multiple snapshot rows. Add comment: `# Performance: using pre-rolled historical_totals from latest snapshot only`. Include `<table class="sr-only">` fallback for accessibility.
- **Error Scenarios**: Fewer than 2 data points → "Insufficient history for trend"; nil data → `EmptyStateComponent(:no_specific_data)`; corrupt JSON → log + "Data temporarily unavailable".

**Architectural Context**
Controller passes `historical_data = data['historical_totals'] || []` (array of {date: String, total: Float, delta: Float}) to component. Chartkick handles rendering. No DB queries beyond latest snapshot fetch. RLS filters to user.

**Acceptance Criteria**
- Line accurately plots historical totals over 30 days.
- Tooltips display date, NW value, and delta.
- Fewer than 2 points → "Insufficient history for trend."
- Responsive and zoom-friendly if Chartkick supports.
- Accessible fallback or labels.

**Test Cases**
- Unit: Mock query result array → assert Chartkick config.
- Integration: Visit page → confirm chart renders with expected data points.

**Workflow**  
Claude Sonnet 4.5. Branch `feature/prd-3-13-performance-view`.


### PRD-3-14: Holdings Summary View

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- In the log put detailed steps for human to manually test and what the expected results.
- If asked to review please create a separate document called <epic or prd name>-feedback.md.

**Overview**  
Implement a holdings summary component showing top 10 holdings in a table with Turbo-powered expand to full sorted/paginated list, sourced from snapshot's `holdings` array. Enhances the existing holdings subdir/view from PRD-2-09, providing quick portfolio concentration insights for HNW users.

**Requirements**
- **Functional**: Compact table: symbol/ticker, name, value ($), % of portfolio (top 10 default). Expand button loads full list via Turbo Frame (sortable by value/%/name). Tooltips on rows: full security details if available. **No detail link** (deferred to Epic 4).
- **Non-Functional**: Responsive table (DaisyUI); lazy full load; handle large lists gracefully.
- **Rails-Specific**: ViewComponent `app/components/net_worth/holdings_summary_component.rb` + ERB. Use Turbo Frame for expand. DaisyUI table classes; sort via Stimulus if <50 rows, else Turbo with params.

**Architectural Context**  
Controller passes `holdings = data['holdings'] || []` (array of {symbol: String, name: String, value: Float, percentage: Float, ...}). Component slices top 10, handles expand logic. MVC: presentation layer; RLS secures snapshot access.

**Acceptance Criteria**
- Top 10 table renders correctly sorted by value descending.
- Expand button loads full list without page reload (Turbo).
- Full list sortable (click headers).
- Percentages formatted (e.g., 12.4%).
- Empty holdings → "No holdings data yet—sync investments."
- Responsive: mobile stacks or horizontal scroll.
- Tooltips show on hover for key fields.

**Test Cases**
- Unit (RSpec): Mock holdings array; test component renders top 10 + expand placeholder.
- Integration: Visit dashboard; assert table presence, expand triggers frame update.
- Manual: Verify sort persists on expand; check percentages sum ≈100%.

**Workflow**  
Use Claude Sonnet 4.5. `git pull origin main`. `git checkout -b feature/prd-3-14-holdings-summary`. Ask questions/build plan first. Small green commits only. Open PR.

### PRD-3-15: Transactions Summary View

**Log Requirements**  
(same as above)

**Overview**  
Create transactions summary cards displaying current-month income, expenses, and net flow, with link to full transactions list. Pulls from snapshot's transaction aggregates or derived data; enhances income/transactions subdirs from PRD-2-09.

**Requirements**
- **Functional**: Three DaisyUI stat cards: Income (+green), Expenses (-red), Net (color by sign). Values formatted as currency. **Defer detail link to Epic 4**—display cards only or use `#` placeholder with tooltip "Coming soon".
- **Non-Functional**: Responsive grid layout; fast static render from JSON.
- **Rails-Specific**: `app/components/net_worth/transactions_summary_component.rb`. Assume `data['transactions_summary']` {month: {income: Float, expenses: Float, net: Float}} or compute minimally if needed.

**Architectural Context**  
Controller provides summary hash from snapshot JSON. Component focuses on presentation. Turbo optional for future refresh tie-in.

**Acceptance Criteria**
- Cards show accurate monthly totals from latest snapshot.
- Colors applied correctly (positive green, negative red).
- Net card reflects income - expenses.
- **No detail link** (deferred to Epic 4) or placeholder link with tooltip.
- No data → "No recent transactions—sync accounts."
- Responsive: 3-column desktop, stacked mobile.
- ARIA labels for stats.

**Test Cases**
- Unit: Component spec with mock summary → assert card HTML/classes/values.
- Integration: Dashboard visit → confirm cards and link href.

**Workflow**  
Claude Sonnet 4.5. Branch `feature/prd-3-15-transactions-summary`.

### PRD-3-16: Snapshot Export Button

**Log Requirements**  
(same)

**Overview**  
Add a dropdown export button on the dashboard for downloading latest snapshot as JSON or CSV, leveraging PRD-2-08 export API endpoint.

**Requirements**
- **Functional**: DaisyUI dropdown: "Export Snapshot" → options "JSON" and "CSV". Triggers download via existing API route (e.g., GET /net_worth/export?format=json). Filename: "networth-snapshot-YYYY-MM-DD". JSON exports full `snapshot.data`; CSV uses schema: `Account,Symbol,Name,Value,Percentage` for holdings (see `financial_snapshot_data_schema.md` for complete CSV spec).
- **Non-Functional**: Secure (user-scoped only); fast generation; ≥44px touch target.
- **Rails-Specific**: Use link_to or button_to with Turbo false for download. Controller action from PRD-2-08 handles send_data. Consider ZIP archive if exporting multiple CSVs (holdings, transactions, accounts).
- **Error Scenarios**: Empty snapshot → disabled button with tooltip "No data to export"; export failure → flash error "Export failed, please try again".

**Architectural Context**  
Button in layout or header partial. RLS ensures only own snapshot exported. No new endpoint needed.

**Acceptance Criteria**
- Dropdown appears and opens correctly.
- JSON option downloads valid JSON matching latest snapshot.data.
- CSV option downloads tabular file (e.g., flattened holdings/accounts).
- Filename includes date.
- Empty snapshot → graceful message or disabled button.
- Download initiates without page reload if possible.

**Test Cases**
- Integration: Click options → assert download response headers/content-type.
- Manual: Verify file contents match Rails console snapshot.

**Workflow**  
Claude Sonnet 4.5. Branch `feature/prd-3-16-export-button`.

### PRD-3-17: Refresh Snapshot / Sync Status Widget

**Log Requirements**  
(same)

**Overview**  
Implement a refresh button with sync status badge (e.g., "Up to date", "Syncing...", last sync time) and rate limiting, using Turbo for async feedback. Triggers FinancialSnapshotJob.

**Requirements**
- **Functional**: Button enqueues `FinancialSnapshotJob` if not rate-limited (1/min via rack-attack). Badge updates via Turbo Stream broadcast: spinner during sync ("Syncing... usually takes 30-90 seconds"), success ("Up to date" + timestamp), or error. Show last sync timestamp. On 429 rate limit → alert "Refresh limit reached — try again in [countdown]".
- **Non-Functional**: Prevent API abuse; visible feedback; ≥44px touch target; responsive header placement.
- **Rails-Specific**: Use `rack-attack` gem with Redis: `Rack::Attack.throttle("snapshot_sync/user", limit: 1, period: 60) { |req| req.user&.id if req.path.match?(%r{/net_worth/sync}) }`. Job broadcasts via `user.broadcast_replace_to "net_worth:sync_status", target: "sync-status", partial: "net_worth/sync_status"` on completion. Add countdown timer (Stimulus or vanilla JS).
- **Error Scenarios**: Job failure → error badge + broadcast failure reason; websocket disconnect → fallback to page refresh prompt; network error → flash alert + retry link.

**Architectural Context**
Widget component in Turbo Frame `#sync-status-frame`; controller action `/net_worth/sync` enqueues job and responds with Turbo Stream. `FinancialSnapshotJob#perform` broadcasts on complete/failure. Rate limit enforced at rack-attack layer.

**Acceptance Criteria**
- Button visible and clickable.
- Click → shows "Syncing...", disables temporarily.
- On complete → badge "Up to date" + timestamp.
- Rate limit hit → toast/alert "Try again in X min".
- Error → error badge/message.
- Responsive placement (e.g., header).

**Test Cases**
- Integration: Mock job enqueue → assert Turbo stream updates badge.
- Unit: Widget renders states correctly.

**Workflow**  
Claude Sonnet 4.5. Branch `feature/prd-3-17-refresh-widget`.

### PRD-3-18: Final Dashboard Polish & Breadcrumbs

**Log Requirements**  
(same)

**Overview**  
Apply final UI consistency: add breadcrumbs, mobile optimizations, empty states across components, and full QA pass for the Net Worth dashboard.

**Requirements**
- **Functional**: Breadcrumbs: "Home > Net Worth" on main dashboard; "Home > Net Worth > [Subsection]" only for drill-down views (transactions list, holding detail). Empty states use `NetWorth::EmptyStateComponent` consistently across all components. Mobile: stack sections, adjust fonts/padding, charts responsive (`width: 100%; height: auto;`), no unintended horizontal scroll, tooltips tap-to-show.
- **Non-Functional**: No console errors; load <2s (LCP); WCAG 2.1 AA compliance; all touch targets ≥44×44px; keyboard navigation tested.
- **Rails-Specific**: DaisyUI breadcrumb component; Tailwind responsive media queries. Add `axe-core-capybara` to test suite; one axe test per major system spec. Add Capybara mobile viewport test (375×667) for dashboard load + one interaction.
- **QA Checklist**: Cross-device/browser check; axe-core automated AA check; manual keyboard nav; consistent typography/colors per style_guide; all Turbo interactions work; all error scenarios handled; all empty states consistent.
- **Error Scenarios**: Document all error paths tested and passing.

**Architectural Context**  
Layout/application updates; component refinements. QA: manual + Capybara if added.

**Acceptance Criteria**
- Breadcrumbs navigate correctly.
- All components show consistent empty states.
- Mobile view stacks logically, no overflow.
- Consistent typography/colors per style_guide.
- No JS/console errors on interactions.
- Accessibility: ARIA on interactive elements.
- Full dashboard QA checklist passed.

**Test Cases**
- Integration: Capybara mobile emulation → assert layout.
- Manual: Cross-device/browser check.

**Workflow**  
Claude Sonnet 4.5. Branch `feature/prd-3-18-final-polish`.

