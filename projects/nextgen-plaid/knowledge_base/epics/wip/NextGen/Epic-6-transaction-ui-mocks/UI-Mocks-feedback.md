**Transaction Views UI Polish Pass**  
(Quick front-end / data tweaks for existing transaction views)  
**Date:** February 16, 2026  
**Assignee:** Junie (or equivalent dev)  
**Estimated effort:** 3–5 days  
**Branch suggestion:** `git checkout -b polish/transaction-views-2026-02`  
**Goal:** Apply targeted visual and behavioral improvements to the five transaction views based on screenshot review and discussion. Focus on consistency, density, and usability while keeping current data source (Plaid sync or whatever is rendering now). Do **not** refactor to new ViewComponents yet—that comes in the separate Epic-6 architecture pass.

**Global Changes (apply across all five views)**

- **Sidebar Navigation**
    - Flatten: Remove double-nesting under "Transactions".
    - Direct children only: Summary, Cash, Credit, Transfers, Investments.
    - Reorder tabs/links exactly:
        1. Summary
        2. Cash
        3. Credit
        4. Transfers
        5. Investments

- **Page Titles / Breadcrumbs**
    - Eliminate duplication (e.g., no separate "Cash Transactions" h1 if breadcrumb already says "Transactions • Cash & Checking").
    - Use clean breadcrumb only: `Home > Transactions > [Subtype]` (e.g., Cash & Checking, Investments, Credit, Transfers, Summary).
    - Keep hero/title area minimal and professional.

- **Filter Bar Placement & Account Filter**
    - Move entire filter bar **above** the summary stats cards row.
    - Make filter bar sticky on scroll (CSS `position: sticky; top: 0;` or DaisyUI utility if available).
    - Add **Account** dropdown immediately right of the Search input:
        - Default: "All Accounts"
        - Options: list of linked account names (same format/order as holdings selector)
        - On change: filter the displayed transactions to only that account (slice array or use existing `@transactions` scope for now).
        - Same dropdown appears identically on **all five** views (Summary, Cash, Credit, Transfers, Investments).

- **Search Placeholder**
    - Dynamic per view:
        - Cash / Credit / Transfers / Summary: "Search by name, merchant..."
        - Investments: "Search by name, security..."

**View-Specific Polish**

- **Cash View**
    - Add small recurring badge ("RR" grey pill) on any detected recurring transaction.
    - No other structural changes needed (table columns look appropriate).

- **Investments View**
    - **Remove** Merchant column completely.
    - **Add** Account column right after Date (make it prominent/bold).
    - Add 20px security icon/logo left of security name (pull from enrichment if available; fallback to letter avatar via DaisyUI).
    - Make security name (and icon) clickable → stub link: `/holdings/securities/[security_id]` or `/stocks/[ticker]` (use whatever ID/ticker is in data).
    - Make **all** columns sortable: add ↑↓ icons on headers (Date, Account, Security, Quantity, Price, Amount).
        - For now: in-memory JavaScript sort or controller array sort.
    - Optional (low priority): hover tooltip on security name showing stub "Current: $XXX | Unrealized: +$YYY (+Z%)" — use mock fields if needed.

- **Credit View**
    - Add 20px icon/logo left of merchant name (card logo if present, e.g., Chase Sapphire / Amex; fallback letter avatar).
    - Keep pending badge styling.
    - Add recurring badge ("RR") where detected.

- **Transfers View**
    - **Remove** Merchant column.
    - Restructure row to: Date | Type ("Transfer") | From (icon) → To (icon) | Amount (positive, right-aligned).
    - Arrow icon: green for inbound to this account, red for outbound from this account.
    - Add badge: "External" (orange) if To account is not in family accounts; "Internal" (grey) otherwise.
    - Deduplicate transfers: show **only the source ("from") leg** — suppress the destination leg row (simple filter on current data; add flag later if needed).

- **Summary View**
    - Add new card/section below main stats: **"Top 5 Recurring Expenses"**
        - Sort by estimated yearly spend descending.
        - Simple list or small table: Name • Frequency (e.g., Monthly) • Amount • Yearly Total
        - Right-align "See all recurring →" link that applies `recurring=true` filter to main list view.
    - Keep category breakdown as-is.

**Recurring Detection (Minimal Implementation)**
- Quick heuristic in a helper or small service:
    - Same merchant/security + near-identical amount + roughly monthly interval (3+ occurrences).
    - Bonus: respect Plaid's recurring flag if present in data.
- Attach `is_recurring: true` to matching items (OpenStruct or wherever transactions are prepared).
- Render small grey "RR" badge in row (DaisyUI pill).

**General Guidelines**
- DaisyUI business theme only — professional, no playful elements.
- Icons small (20px max), table dense.
- Mobile: collapse non-essential columns or stack into cards if needed.
- No new components yet — work within existing partials / controller @variables.
- Keep current data source (don't force YAML unless current sync is missing edge cases).

**Workflow**
1. Pull latest main.
2. Create branch: `git checkout -b polish/transaction-views-2026-02`
3. Implement in small commits (e.g., one commit per view + global changes).
4. Manually test each route:
    - Apply account filter → only that account's items show.
    - Click security link in investments → goes to stub URL.
    - Transfers show one row per movement, with direction arrow and external/internal badge.
    - Summary shows Top 5 Recurring card.
5. Push + share screenshots of all five views after changes.

**Questions for Junie before starting**
- Is the current data coming from real Plaid sync or local mocks? (affects how we filter/slice)
- Do we have account icons/logos already available in the data model?
- Preferred way to implement client-side sort vs server-side for now?
- Exact family account definition for "external" badge (all linked Plaid accounts = family)?

Once this pass is merged and looks good, we'll follow with the full Epic-6 refactor (ViewComponents, MockTransactionDataProvider, monthly grouping, STI fix in sync, etc.).

Let me know if you want any section expanded, removed, or re-prioritized.