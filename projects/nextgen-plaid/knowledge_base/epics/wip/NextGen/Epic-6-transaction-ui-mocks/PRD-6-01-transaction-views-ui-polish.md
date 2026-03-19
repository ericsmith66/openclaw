<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic-4/PRD-4-01-saprun-schema-persona-config.md
-->

#### PRD-6-01: Transaction Views UI Polish

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `UI-Mocks-feedback-feedback-V1.md` in the same directory as the source document.

---

### Overview

This PRD defines a targeted UI polish pass for the five transaction views (Cash, Investments, Credit, Transfers, Summary) built during Epic-6. The goal is to apply visual and behavioral improvements based on screenshot review and discussion, focusing on consistency, density, and usability while keeping the current data source (Plaid sync or mock data). No refactoring to new ViewComponents is included—that is deferred to the separate Epic-6 architecture pass.

The changes include global improvements to sidebar navigation, page titles, filter bar placement, account filtering, and search placeholders, as well as view‑specific enhancements such as recurring badges, column adjustments, security icons, transfer deduplication, and a new “Top 5 Recurring Expenses” card in the Summary view. A minimal recurring‑detection heuristic is also introduced.

---

### Requirements

#### Functional

**Global Changes (apply across all five views)**

- **Sidebar Navigation**
    - Flatten double‑nesting under “Transactions”; keep only direct children: Summary, Cash, Credit, Transfers, Investments.
    - Reorder tabs/links exactly: Summary, Cash, Credit, Transfers, Investments.

- **Page Titles / Breadcrumbs**
    - Eliminate duplication (e.g., no separate “Cash Transactions” h1 if breadcrumb already says “Transactions • Cash & Checking”).
    - Use clean breadcrumb only: `Home > Transactions > [Subtype]` (e.g., Cash & Checking, Investments, Credit, Transfers, Summary).
    - Keep hero/title area minimal and professional.

- **Filter Bar Placement & Account Filter**
    - Move entire filter bar **above** the summary stats cards row.
    - Make filter bar sticky on scroll (CSS `position: sticky; top: 0;` or DaisyUI utility if available).
    - Add **Account** dropdown immediately right of the Search input:
        - Default: “All Accounts”
        - Options: list of linked account names (same format/order as holdings selector)
        - On change: filter the displayed transactions to only that account (slice array or use existing `@transactions` scope for now).
        - Same dropdown appears identically on **all five** views (Summary, Cash, Credit, Transfers, Investments).

- **Search Placeholder**
    - Dynamic per view:
        - Cash / Credit / Transfers / Summary: “Search by name, merchant…”
        - Investments: “Search by name, security…”

**View‑Specific Polish**

- **Cash View**
    - Add small recurring badge (“RR” grey pill) on any detected recurring transaction.
    - No other structural changes needed (table columns look appropriate).

- **Investments View**
    - **Remove** Merchant column completely.
    - **Add** Account column right after Date (make it prominent/bold).
    - Add 20px security icon/logo left of security name (pull from enrichment if available; fallback to letter avatar via DaisyUI).
    - Make security name (and icon) clickable → stub link: `/holdings/securities/[security_id]` or `/stocks/[ticker]` (use whatever ID/ticker is in data).
    - Make **all** columns sortable: add ↑↓ icons on headers (Date, Account, Security, Quantity, Price, Amount).
        - For now: in‑memory JavaScript sort or controller array sort.
    - Optional (low priority): hover tooltip on security name showing stub “Current: $XXX | Unrealized: +$YYY (+Z%)” — use mock fields if needed.

- **Credit View**
    - Add 20px icon/logo left of merchant name (card logo if present, e.g., Chase Sapphire / Amex; fallback letter avatar).
    - Keep pending badge styling.
    - Add recurring badge (“RR”) where detected.

- **Transfers View**
    - **Remove** Merchant column.
    - Restructure row to: Date | Type (“Transfer”) | From (icon) → To (icon) | Amount (positive, right‑aligned).
    - Arrow icon: green for inbound to this account, red for outbound from this account.
    - Add badge: “External” (orange) if To account is not in family accounts; “Internal” (grey) otherwise.
    - Deduplicate transfers: show **only the source (“from”) leg** — suppress the destination leg row (simple filter on current data; add flag later if needed).

- **Summary View**
    - Add new card/section below main stats: **“Top 5 Recurring Expenses”**
        - Sort by estimated yearly spend descending.
        - Simple list or small table: Name • Frequency (e.g., Monthly) • Amount • Yearly Total
        - Right‑align “See all recurring →” link that applies `recurring=true` filter to main list view.
    - Keep category breakdown as‑is.

**Recurring Detection (Minimal Implementation)**
- Quick heuristic in a helper or small service:
    - Same merchant/security + near‑identical amount + roughly monthly interval (3+ occurrences).
    - Bonus: respect Plaid’s recurring flag if present in data.
- Attach `is_recurring: true` to matching items (OpenStruct or wherever transactions are prepared).
- Render small grey “RR” badge in row (DaisyUI pill).

**General Guidelines**
- DaisyUI business theme only — professional, no playful elements.
- Icons small (20px max), table dense.
- Mobile: collapse non‑essential columns or stack into cards if needed.
- No new components yet — work within existing partials / controller @variables.
- Keep current data source (don’t force YAML unless current sync is missing edge cases).

#### Non-Functional

- **Performance**: Client‑side filtering/sorting should not cause noticeable lag (target < 100ms for 500 transactions).
- **Maintainability**: Changes should be scoped to existing ViewComponents and partials; avoid creating new components unless absolutely necessary.
- **Accessibility**: All interactive elements (dropdowns, sortable headers, clickable security names) must be keyboard‑navigable and have appropriate ARIA labels.
- **Responsive Design**: Views must remain usable on mobile (≥375px width) with appropriate column collapsing/stacking.

#### Rails / Implementation Notes (optional)

- **Models / controllers / components / background jobs / migrations involved**:
    - `TransactionsController` (already exists) – may need to pass additional data (account list, recurring detection flag).
    - `Transactions::GridComponent` – update to include Account column, sortable headers, sticky filter bar.
    - `Transactions::RowComponent` – add recurring badge, security icon, account column, transfer‑specific row layout.
    - `Transactions::FilterBarComponent` – add Account dropdown, dynamic placeholder.
    - `Transactions::SummaryCardComponent` – add “Top 5 Recurring Expenses” card.
    - Partial views (`_tabs.html.erb`) – update sidebar navigation order and flatten nesting.
    - Helper module for recurring detection (e.g., `TransactionRecurringDetector`).
- **Routes / endpoints**: No new routes needed; existing routes (`/transactions/regular`, `/transactions/investment`, etc.) remain unchanged.
- **Feature flags (if any)**: None required; changes are UI‑only and non‑breaking.

---

### Error Scenarios & Fallbacks

- **Missing account data** → Account dropdown defaults to “All Accounts” and shows empty list.
- **Recurring detection heuristic fails** → No “RR” badge shown; transaction list unaffected.
- **Security icon not available** → Fallback to letter avatar (first letter of security name).
- **Transfer deduplication incorrectly filters out legitimate rows** → Fallback to showing both legs (original behavior) with a console warning.
- **Sticky filter bar conflicts with existing CSS** → Remove sticky behavior but keep placement above summary stats.

---

### Architectural Context

This polish pass builds atop the existing Epic‑6 transaction views, which already have functional ViewComponents (`GridComponent`, `RowComponent`, `FilterBarComponent`, `SummaryCardComponent`) and mock‑data support via `MockTransactionDataProvider`. The changes are intentionally scoped to UI tweaks and do not alter the underlying data flow, STI model structure, or route architecture. This keeps the work isolated and low‑risk, while delivering immediate usability improvements.

The addition of an Account filter and recurring detection are forward‑compatible with the upcoming live‑data migration; the UI will work unchanged whether transactions come from mock YAML or the `Transaction` ActiveRecord model.

---

### Acceptance Criteria

- [ ] Sidebar navigation flattened, reordered as specified, and functional across all five views.
- [ ] Page titles/breadcrumbs cleaned up (no duplication) and follow `Home > Transactions > [Subtype]` pattern.
- [ ] Filter bar moved above summary stats, sticky on scroll, and includes an Account dropdown with “All Accounts” default.
- [ ] Search placeholder dynamically changes per view (Cash/Credit/Transfers/Summary vs Investments).
- [ ] Cash view shows “RR” badge on recurring transactions.
- [ ] Investments view: Merchant column removed, Account column added after Date, security icon+name clickable stub, all columns sortable.
- [ ] Credit view shows merchant icon and recurring badge where appropriate.
- [ ] Transfers view: Merchant column removed, row restructured with direction arrow and external/internal badge, deduplicated to show only source leg.
- [ ] Summary view includes “Top 5 Recurring Expenses” card with “See all recurring” link.
- [ ] Recurring detection heuristic implemented and “RR” badge appears on qualifying transactions across all views.
- [ ] All changes respect DaisyUI business theme, are mobile‑friendly, and do not introduce regressions in existing functionality.

---

### Test Cases

#### Unit (Minitest)

- `test/components/transactions/grid_component_test.rb`: Verify Account column appears in investments view, sticky filter bar class present.
- `test/components/transactions/row_component_test.rb`: Verify recurring badge rendered when `transaction.is_recurring = true`, security icon rendered for investment transactions, transfer row renders arrow icon and external/internal badge.
- `test/components/transactions/filter_bar_component_test.rb`: Verify Account dropdown options populated, placeholder text changes based on view.
- `test/helpers/transaction_recurring_detector_test.rb`: Verify heuristic correctly identifies recurring transactions.

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb`: Ensure all five actions still return 200, @transactions includes account list for filter.
- `test/system/transactions_test.rb`: Smoke test each view loads with updated UI elements.

#### System / Smoke (Capybara)

- `test/system/transactions_ui_polish_test.rb`: Walk through each view, verify sidebar order, filter bar placement, account filter works, recurring badges appear, investment columns sort, transfer deduplication, summary recurring card present.

---

### Manual Verification

Provide step‑by‑step instructions a human can follow.

1. Start the Rails server: `bin/rails server`
2. Navigate to `http://localhost:3000/transactions/regular`
3. **Global checks**:
    - Confirm sidebar shows direct links: Summary, Cash, Credit, Transfers, Investments (no nested “Transactions” parent).
    - Click each link; verify breadcrumb reads `Home > Transactions > [Subtype]` and title area is minimal.
    - On any view, scroll down; filter bar should stay sticky at top.
    - See Account dropdown right of Search input; select an account; transactions should filter to that account (or show none if mock data lacks matches).
    - Check placeholder text: Cash view says “Search by name, merchant…”; Investments view says “Search by name, security…”.
4. **Cash view**:
    - Identify a recurring transaction (same merchant, similar amount, monthly). Should have grey “RR” pill badge.
5. **Investments view**:
    - Merchant column absent. Account column appears after Date.
    - Security name has a 20px icon to its left.
    - Click security name; browser should navigate to stub URL (e.g., `/holdings/securities/...`).
    - Click each column header (Date, Account, Security, Quantity, Price, Amount); sort direction indicator toggles and rows reorder.
6. **Credit view**:
    - Merchant names have card/logo icon left of them.
    - Recurring transactions show “RR” badge.
7. **Transfers view**:
    - Merchant column absent.
    - Each row shows “Transfer” type, From → To with arrow icon (green for inbound, red for outbound).
    - External/internal badge appears correctly.
    - Only one row per transfer pair (source leg only).
8. **Summary view**:
    - “Top 5 Recurring Expenses” card appears below main stats.
    - List shows Name, Frequency, Amount, Yearly Total sorted by yearly spend.
    - “See all recurring →” link applies `recurring=true` filter to main list view.

**Expected**
- All five views render without JavaScript errors.
- UI matches DaisyUI business theme, dense tables, professional appearance.
- All new features (badges, icons, sorting, filtering) work as described.
- No regression in existing pagination, search, or type filtering.

---

### Rollout / Deployment Notes (optional)

- **Migrations / backfills**: None required (UI‑only changes).
- **Monitoring / logging**: Log recurring detection counts for debugging; add a log line when Account filter is used.

