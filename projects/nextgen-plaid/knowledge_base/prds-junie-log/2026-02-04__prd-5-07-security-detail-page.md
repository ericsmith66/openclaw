# Junie Task Log — PRD 5-07: Security Detail Page
Date: 2026-02-04  
Mode: Brave  
Branch: epic-5-holding-grid  
Owner: junie

## 1. Goal
- Implement `/portfolio/securities/:security_id` to show security enrichment + aggregated holdings + transactions grid with totals and pagination, with graceful empty/missing-data handling.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-07-security-detail-page.md`
- Epic overview: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0000-overview-epic-5.md`
- Dependencies called out by PRD: PRD 5-02 (data provider), PRD 5-03 (pagination), PRD 5-06 (per-account breakdown patterns).

## 3. Plan
1. Add controller + route for `/portfolio/securities/:security_id` with preloaded associations and friendly 404.
2. Build ViewComponents + views for header, enrichment sections, holdings summary, per-account breakdown, and transactions grid (pagination + totals).
3. Ensure back-link preserves holdings grid state via `return_to` param and/or referrer.
4. Add Minitest coverage (controller + components + Capybara/system smoke).
5. Run targeted tests and update Epic-5 `0001-IMPLEMENTATION-STATUS.md`.

## 4. Work Log (Chronological)
- 2026-02-04: Read PRD 5-07 and Junie log requirements; reviewed Epic-5 overview and current implementation status; prepared task log.
- 2026-02-04: Implemented `/portfolio/securities/:security_id` (route + controller + provider + component + view) and linked from the holdings grid symbol.
- 2026-02-04: Added tests for controller, provider totals/pagination, and Capybara navigation/back-link.

## 5. Files Changed
- `config/routes.rb`
- `app/controllers/portfolio/securities_controller.rb`
- `app/services/security_detail_data_provider.rb`
- `app/components/portfolio/security_detail_component.rb`
- `app/components/portfolio/security_detail_component.html.erb`
- `app/views/portfolio/securities/show.html.erb`
- `app/components/portfolio/holdings_grid_component.rb`
- `app/components/portfolio/holdings_grid_component.html.erb`
- `test/controllers/portfolio/securities_controller_test.rb`
- `test/services/security_detail_data_provider_test.rb`
- `test/smoke/portfolio_holdings_grid_capybara_test.rb`
- `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md`

## 6. Commands Run
- `git status --porcelain`
- `bin/rails test test/controllers/portfolio/securities_controller_test.rb`
- `bin/rails test test/services/security_detail_data_provider_test.rb`
- `bin/rails test test/smoke/portfolio_holdings_grid_capybara_test.rb`

## 7. Tests
- ✅ `test/controllers/portfolio/securities_controller_test.rb`
- ✅ `test/services/security_detail_data_provider_test.rb`
- ✅ `test/smoke/portfolio_holdings_grid_capybara_test.rb`

## 8. Decisions & Rationale
- Decision: Use `return_to` param (when present) and fall back to `request.referer` for the “Back to Holdings” link.
    - Rationale: Works with Turbo navigation and supports explicit URL-state preservation.

## 9. Risks / Tradeoffs
- Totals semantics depend on `transactions.type/subtype` values; may require alignment with existing transaction domain enums/strings.
- “Average cost” is phase-1 “sum only” per Epic decisions; will label as such if UI needs clarification.

## 10. Follow-ups
- [ ] Confirm transaction `type` values used in production data match PRD buckets (buy/sell/contribution/distribution/dividend).
- [ ] Consider extracting totals logic into a reusable helper/service if other pages need the same rollups.

## 11. Outcome
- Implemented PRD 5-07 (Awaiting Review).
    - Security detail page renders enrichment, holdings summary, per-account breakdown, and paginated transactions with grand totals.
    - Holdings grid symbol links to security detail with a `return_to` param so the “Back to Holdings” link restores grid URL state.

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Visit `/portfolio/holdings` and click a security row (e.g., AAPL) to navigate to `/portfolio/securities/<security_id>`.
2. Verify header shows ticker + name, price (if available), and “Enrichment Updated” badge with green/yellow/red status.
3. Verify Core/Market/Fundamentals sections render values or “N/A” placeholders if enrichment is missing.
4. Verify Holdings Summary totals match the aggregation across accounts (quantity/value/cost/unrealized G/L).
5. Verify per-account breakdown table rows match the underlying holdings (account name/mask, quantity, value, cost basis, G/L $/%).
6. Verify Transactions grid shows only transactions for that `security_id`, sorted by date desc by default.
7. Verify grand totals row shows Invested, Proceeds, Net Cash Flow, and Dividends consistent with the transaction types.
8. Change rows-per-page (25/50/100/All) and verify pagination updates accordingly.
9. Click “← Back to Holdings” and verify you return to holdings with prior filters/search/snapshot preserved when coming from the grid.
10. Visit `/portfolio/securities/does-not-exist` (or an invalid id) and verify a friendly 404 message.
