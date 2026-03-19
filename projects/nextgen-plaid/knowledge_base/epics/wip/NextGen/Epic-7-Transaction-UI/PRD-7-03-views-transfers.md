#### PRD-7-03: Type-Specific View Enhancements & Transfers Deduplication

**Log Requirements**
- Junie: read `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Polish the Cash, Credit, and Investment transaction views with type-appropriate enhancements (investment-specific columns, credit pending indicators, merchant avatars) and create the `TransferDeduplicator` service that matches transfer leg pairs and shows only the canonical outbound leg. The existing `Transactions::RowComponent` already supports view-type-specific rendering (investment columns, transfer arrows, credit avatars) — this PRD wires those features to live data and builds the deduplication engine.

**User Story:** As a user, I want each transaction view to show relevant columns and details for that type (security info for investments, pending status for credit, direction arrows for transfers with deduplication), so that I can quickly understand my financial activity in context.

---

### Requirements

#### Functional

1. **Cash view polish** (`/transactions/regular`):
   - Show: Date, Name (with recurring badge if applicable), Type badge, Merchant, Account, Amount
   - Category badge from `personal_finance_category_label` (first segment before "→")
   - Merchant column populated from `merchant_name` field on Transaction model

2. **Investment view polish** (`/transactions/investment`):
   - Show: Date, Account (bold), Name, Type badge, Security (icon + link), Quantity, Price, Amount
   - Security link uses `/portfolio/securities/:security_id` path (existing `security_link` method in `RowComponent`)
   - Subtype badge for buy/sell/dividend/interest/split
   - `show_investment_columns: true` already wired in view template

3. **Credit view polish** (`/transactions/credit`):
   - Show: Date, Name (with merchant avatar + pending badge), Type badge, Merchant, Account, Amount
   - Pending transactions highlighted with warning badge (already in `RowComponent#pending?`)
   - Category label from `personal_finance_category_label`

4. **`TransferDeduplicator` service** (`app/services/transfer_deduplicator.rb`):
   - Input: array of transfer transactions (from `TransactionGridDataProvider`)
   - Matching key: date ±1 day, opposite sign, abs(amount) within 1% tolerance, different `account_id`s
   - Output: deduplicated array — outbound/negative leg kept, matched inbound/positive suppressed
   - Unmatched transactions kept with `external: true` flag for "External" badge
   - Investment account transactions excluded before processing (handled by data provider filter)

5. **Transfers view** (`/transactions/transfers`):
   - Wire `TransferDeduplicator` in controller (or data provider) after query
   - Show: Date, Type badge, Transfer Details (From → To with direction arrow + badge), Amount (absolute value)
   - `RowComponent` transfer helpers already exist: `transfer_outbound?`, `transfer_from`, `transfer_to`, `transfer_badge`
   - Update `transfer_from`/`transfer_to` to use `transaction.account.name` (live data) instead of `transaction.account_name` (mock field)

6. **Subtype badge additions to `RowComponent`**:
   - Investment subtypes: "Buy" (green), "Sell" (red), "Dividend" (blue), "Interest" (purple), "Transfer" (gray)
   - Render in a new `subtype_badge` helper method, shown next to type badge

#### Non-Functional

- All queries scoped to `current_user` (inherited from PRD-7.1)
- Transfer deduplication runs in O(n) time (single pass with hash-based matching)
- No additional database queries for deduplication (works on in-memory result set)
- Responsive columns: Merchant/Account columns hidden on mobile (`hidden lg:table-cell` already in template)

#### Rails / Implementation Notes

- **Service**: `app/services/transfer_deduplicator.rb` — new file, ~80-120 lines
- **Component**: Modify `app/components/transactions/row_component.rb` — add `subtype_badge`, update `transfer_from`/`transfer_to` for live data
- **Component template**: Modify `app/components/transactions/row_component.html.erb` — add subtype badge rendering, category label
- **Controller/Data Provider**: Call `TransferDeduplicator` on transfer query results
- **Views**: Minor updates to pass additional params if needed

---

### Error Scenarios & Fallbacks

| Scenario | Expected Behavior |
|----------|------------------|
| Transfer with no matching opposite leg | Show with "External" badge |
| Multiple same-amount transfers on same day between different accounts | Match first pair found; extras remain as unmatched externals |
| Transfer from investment account (brokerage internal) | Excluded by data provider filter (not shown in transfers view) |
| Transaction missing `account` association (orphaned) | Skip in deduplicator; show in view with "—" for account name |
| Transaction with nil amount | Skip in dedup matching; show as-is in view |
| Security ID not found for investment transaction | Show "—" for security; no link |
| `personal_finance_category_label` is nil | Skip category badge rendering |

---

### Architectural Context

The `Transactions::RowComponent` was designed in Epic-6 with view-type awareness — it already supports investment columns (`show_investment_columns`), transfer direction arrows (`transfers_view?`), credit merchant avatars (`credit_view?`), and pending/recurring badges. This PRD completes the wiring to live data where mock data previously provided `account_name`, `security_name`, `target_account_name` as flat strings. With live data, these come from associations (`transaction.account.name`, joined security enrichments).

The `TransferDeduplicator` is a pure-Ruby service that processes an array of transactions and returns a deduplicated array. It does not touch the database — it operates on the result set returned by `TransactionGridDataProvider`.

---

### Acceptance Criteria

- [ ] Cash view shows category label from `personal_finance_category_label` (primary segment)
- [ ] Cash view shows `merchant_name` in Merchant column from Transaction model field
- [ ] Investment view shows Security column with icon and clickable link to `/portfolio/securities/:security_id`
- [ ] Investment view shows Quantity and Price columns from Transaction model fields
- [ ] Investment view shows subtype badge (Buy/Sell/Dividend/Interest/Split) with appropriate colors
- [ ] Credit view shows pending badge on pending transactions
- [ ] Credit view shows merchant avatar (letter initial) next to transaction name
- [ ] `TransferDeduplicator` service exists and passes all 7 edge case tests
- [ ] Transfers view shows deduplicated results (matched inbound legs suppressed)
- [ ] Transfers view shows direction arrows (outbound red →, inbound green ←)
- [ ] Transfers view shows "External" badge for unmatched transfer legs
- [ ] Transfers view shows "Internal" badge for matched internal transfer legs
- [ ] Transfer amounts displayed as absolute values
- [ ] No investment-account transfers appear in transfers view

---

### Test Cases

#### Unit (Minitest)

- `test/services/transfer_deduplicator_test.rb`:
  1. Internal exact match: $1000 out + $1000 in, same day → only outbound returned
  2. Near-amount match: $1000.00 out + $999.87 in → matched, inbound suppressed
  3. Date offset: out Feb 17, in Feb 18 → matched
  4. External: $500 out, no matching inbound → returned with `external: true`
  5. Investment account excluded: brokerage "transfer" → not in input set
  6. Self-transfer (same account): treated as outbound if negative
  7. Multi-leg (wire fee split): amounts don't match → both kept as unmatched

- `test/components/transactions/row_component_test.rb` (additions):
  - Renders subtype badge for investment transactions
  - Renders category label for cash transactions
  - Renders pending badge for credit transactions
  - Renders transfer direction arrow and badge

#### Integration (Minitest)

- `test/controllers/transactions_controller_test.rb` (additions):
  - `GET /transactions/transfers` returns deduplicated results
  - `GET /transactions/investment` includes investment-specific columns in response

#### System / Smoke (Capybara)

- `test/system/transactions_views_test.rb`:
  - Visit `/transactions/investment` → security links are clickable
  - Visit `/transactions/transfers` → direction arrows visible
  - Visit `/transactions/credit` → pending badges visible on pending transactions

---

### Manual Verification

1. Visit `/transactions/regular` → verify merchant names display from live data, category labels visible
2. Visit `/transactions/investment` → verify security names with icons, subtype badges (Buy/Sell/Dividend), quantity/price columns
3. Click a security link → navigates to `/portfolio/securities/:id`
4. Visit `/transactions/credit` → verify pending badges on pending transactions, merchant avatars
5. Visit `/transactions/transfers` → verify deduplicated list (count should be less than raw transfer count)
6. Verify direction arrows (red → for outbound, green ← for inbound)
7. Verify "External"/"Internal" badges on transfer rows
8. In `rails console`: compare `TransferDeduplicator.new(transfers).call.size` vs raw transfer count

**Expected**
- Each view type shows relevant columns with live data
- Investment securities are clickable links
- Transfers are deduplicated — fewer rows than raw count
- External transfers badged correctly
- No visual regressions from Epic-6 mock views

---

### Dependencies

- **Blocked By:** PRD-7.2 (filter bar must be wired to data provider)
- **Blocks:** PRD-7.4 (summary view uses aggregated data from all views)

---

### Rollout / Deployment Notes

- No migrations
- `TransferDeduplicator` is a new service file — no impact on existing code
- Component changes are additive (new badges/labels) — low regression risk

---
