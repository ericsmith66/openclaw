# PRD 0-04: Product-Specific Connect Buttons with Dynamic Link Token Filtering

**Epic**: Epic 0 - Immediate Quick Wins (Account Management Hub) v1.0
**Priority**: 2
**Effort**: M (8-12 hours)
**Branch**: `feature/epic0-product-buttons`

---

## Log Requirements

Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- **In the log, include detailed steps for human to manually test and what the expected results**
- If asked to review, create a separate document called `epic0-prd4-addbuttons-feedback.md`

---

## Overview

Replace the single "Link Bank or Brokerage" button on `/accounts/link` with three distinct, intent-based buttons that trigger Plaid Link with pre-filtered products ('transactions', 'investments', 'liabilities'). This prevents users from seeing/connecting unsupported institutions, improves sync success for target institutions (especially Schwab for investments, Amex for liabilities), and aligns with our vision of frictionless, high-quality data ingestion for HNW financial tutoring.

**Key Decision**: Replace existing single button (not add to it) to avoid UI clutter and force clear user intent.

---

## Requirements

### Functional

- On `/accounts/link`, **replace** the existing primary CTA with three large, professional buttons in a horizontal layout (desktop):
    1. "Connect Brokerage Accounts" (investments) - for Schwab, Fidelity, Vanguard
    2. "Connect Bank Accounts" (transactions) - for JPMC, Bank of America, Wells Fargo
    3. "Connect Credit Cards & Loans" (liabilities) - for Amex, Capital One, Discover

- Add small link below buttons: "Not sure? Connect all account types" → creates link_token with all products

- Each button triggers Plaid Link with a link_token created with `products:` parameter:
    - Brokerage button → `products: ['investments']`
    - Bank button → `products: ['transactions']`
    - Credit button → `products: ['liabilities']`
    - "All" link → `products: ['investments', 'transactions', 'liabilities']`

- On successful exchange (`/plaid/exchange`), store metadata field on PlaidItem: `intended_products: string` (comma-separated, e.g., "investments" or "liabilities")

- Follow existing Plaid Link JS implementation pattern; pass product-specific link_token

- Keep per-item Retry buttons as-is (they trigger all three sync jobs regardless of intended_products)

- If user has existing PlaidItems, show them in the table above the buttons with status

- **Empty State**: If no PlaidItems exist, show:
  ```
  "Connect your financial accounts to get started.
  Choose the type of account you'd like to link:"
  [3 buttons]
  ```

### Non-Functional

- **UI**: Tailwind + DaisyUI; use same style for all three buttons (btn-primary or btn-outline) to avoid implying priority
- **Desktop Only**: This is v1.0 desktop-only; mobile UI improvements are future work
- **Performance**: link_token generation remains fast (<500ms); no extra DB calls
- **Privacy**: No new sensitive data; intended_products is metadata only (not encrypted)
- **Sandbox-first**: Test with Plaid sandbox institutions that support each product

---

## Architectural Context

- **Controller**: Follow existing implementation pattern in `PlaidController#link_token`
  - Add handling for `product_set` parameter
  - No service object extraction yet (defer until pattern emerges as needed)
  - Validate product_set against whitelist

- **Model**: Add migration for `PlaidItem#intended_products:string` (nullable)
  - Do NOT backfill existing records (leave as NULL)
  - Only set for new connections going forward

- **View**: `app/views/accounts/link.html.erb`
  - Replace existing single button with three buttons
  - Use data attributes for product_set
  - Add "Connect all" fallback link

- **JavaScript**: Use data attributes for cleaner separation:
  ```erb
  <%= button_to "Connect Brokerage Accounts", 
      "#", 
      class: "btn btn-primary plaid-link-button",
      data: { 
        product_set: "investments",
        plaid_link_target: "button"
      } %>
  ```

- **Plaid API**: Current version (2020-09-14); use `products` parameter in `/link/token/create`

- **Frontend Stack**: Check existing implementation (Stimulus vs plain JS) and follow that pattern

---

## Institution Examples (for UI guidance)

Display example institutions below each button to set expectations:

- **Brokerage**: "e.g., Schwab, Fidelity, Vanguard"
- **Banking**: "e.g., JPMC, Bank of America, Wells Fargo"
- **Credit**: "e.g., Amex, Capital One, Discover"

Note: Apple Card is NOT covered by Plaid

---

## Duplicate Institution Handling

**Current Behavior**: Plaid's institution filtering is flaky and may show same institution across multiple product types.

**V1 Approach**: Allow duplicate PlaidItems for same institution with different products
- User can connect Schwab via "Brokerage" button → gets investments
- User can connect Schwab via "Banking" button → gets transactions (if available)
- This creates separate PlaidItems

**Future Enhancement** (separate story): Detect existing institution and prompt:
"You've already connected [Institution]. Add [Product B]?" → update existing item per account

---

## Product Combination Support

**Plaid Behavior**: One PlaidItem can support multiple products simultaneously (e.g., JPMC returns investments + transactions + liabilities if user grants all permissions)

**Retry Behavior**: Retry buttons sync ALL available products regardless of intended_products (maximizes data freshness, simpler implementation)

---

## Migration Strategy

**Existing PlaidItems**: Leave `intended_products` as NULL
- Do NOT backfill based on available_products
- Plaid will automatically enable other products if they become available

**New Connections**: Set `intended_products` based on button clicked

```ruby
# Migration
class AddIntendedProductsToPlaidItems < ActiveRecord::Migration[7.1]
  def change
    add_column :plaid_items, :intended_products, :string
    # No backfill - leave existing records as NULL
  end
end
```

---

## Error Handling

**Error States**:
- Link token creation fails → Show toast "Unable to connect. Try again."
- User cancels Plaid Link → No action, return to page
- Institution doesn't support product → Plaid handles (filters out institution)
- Network error → Show retry button

**Plaid Error Codes** (for future enhancement):
- ITEM_LOGIN_REQUIRED → "Please update your login credentials"
- MFA_REQUIRED → "Check your phone for 2FA code, then try again"
- ITEM_LOCKED → "Account locked. Please contact your bank."

---

## Analytics Events

Track the following events (implementation details TBD based on analytics tool):

- `connect_button_clicked` (product_set, user_id)
- `plaid_link_opened` (product_set, institution_search_term)
- `plaid_link_success` (product_set, institution_name, intended_products)
- `plaid_link_cancelled` (product_set, step)

---

## Acceptance Criteria

- [ ] Visiting `/accounts/link` shows three clear buttons (no single generic button)
- [ ] "Connect all" fallback link present below buttons
- [ ] Clicking "Connect Brokerage Accounts" opens Plaid Link showing only institutions supporting 'investments'
- [ ] After successful link + exchange, PlaidItem has `intended_products: "investments"`
- [ ] Same behavior for other buttons with their respective products
- [ ] Existing retry buttons and table remain functional
- [ ] No regression on chat gating (still requires at least one good PlaidItem)
- [ ] Empty state shows when no PlaidItems exist
- [ ] In Rails console: `PlaidItem.last.intended_products` returns expected value post-link
- [ ] Sandbox test: Link known institutions via each button; confirm products filter applies

---

## Test Cases

### Manual Test Steps

**Test Case 1: Brokerage Button Filters Correctly**
1. Navigate to `/accounts/link` in sandbox
2. Click "Connect Brokerage Accounts"
3. In Plaid Link search, type "Amex"
4. **Expected**: Amex does NOT appear (doesn't support investments)
5. Search "Schwab"
6. **Expected**: Schwab appears, connect successfully
7. Verify in Rails console: `PlaidItem.last.intended_products == "investments"`

**Test Case 2: Credit Button Shows Credit Cards**
1. Click "Connect Credit Cards & Loans"
2. Search "Amex"
3. **Expected**: Amex appears prominently
4. Search "Schwab"
5. **Expected**: Schwab does NOT appear (no credit products)
6. Connect Amex successfully
7. Verify: `PlaidItem.last.intended_products == "liabilities"`

**Test Case 3: Banking Button**
1. Click "Connect Bank Accounts"
2. Search "JPMC" or "Chase"
3. **Expected**: JPMC appears, connect successfully
4. Verify: `PlaidItem.last.intended_products == "transactions"`

**Test Case 4: Connect All Link**
1. Click "Not sure? Connect all account types" link
2. **Expected**: Plaid Link shows all institutions (no filtering)
3. Connect any institution
4. Verify: `PlaidItem.last.intended_products == "investments,transactions,liabilities"` (or similar)

**Test Case 5: Duplicate Institution (Current Behavior)**
1. Connect Schwab via "Connect Brokerage Accounts"
2. Click "Connect Bank Accounts"
3. Search "Schwab"
4. **Expected**: Schwab appears again (Plaid's flaky filtering)
5. Connect Schwab again
6. **Expected**: Two separate PlaidItems created (duplicate allowed in v1)

**Test Case 6: Empty State**
1. Ensure user has no PlaidItems (or use fresh test account)
2. Visit `/accounts/link`
3. **Expected**: See empty state message with three buttons
4. No table/list of existing items shown

**Test Case 7: Retry Button Still Works**
1. Create a failed PlaidItem (any product)
2. Visit `/accounts/link`
3. Click retry button on failed item
4. **Expected**: Retry triggers sync for ALL available products (not just intended_products)

### Unit Tests (Optional - nominal value per EAS)

```ruby
# spec/models/plaid_item_spec.rb
RSpec.describe PlaidItem do
  describe '#intended_products' do
    it 'stores comma-separated product list' do
      item = create(:plaid_item, intended_products: 'investments,transactions')
      expect(item.intended_products).to eq('investments,transactions')
    end

    it 'allows nil for legacy items' do
      item = create(:plaid_item, intended_products: nil)
      expect(item.intended_products).to be_nil
    end
  end
end
```

---

## Dependencies

### Pre-Implementation Audit

Before starting, verify:
- [ ] Current Plaid API version (should be 2020-09-14 or later)
- [ ] PlaidItem schema: check for existing columns (run: `rails db:schema:dump | grep plaid_items`)
- [ ] Confirm `available_products` column exists (if not, may need additional migration)
- [ ] Review existing Plaid error handling patterns
- [ ] Check frontend framework: Stimulus controllers or plain JavaScript?
- [ ] Verify existing PlaidItemSyncJob is idempotent

### Required

- Existing sync status tracking in PlaidItem
- PlaidItemSyncJob exists and is idempotent
- `/accounts/link` route and view
- Plaid API credentials configured
- plaid-ruby gem >= 14.0.0

---

## Security Considerations

**V1 Scope** (defer advanced security to future stories):
- Link token creation scoped to current_user
- Product_set parameter validated against whitelist
- CSRF protection on POST endpoint (Rails default)
- No sensitive data in client-side JavaScript

**Future Enhancements** (not in v1):
- Rate limiting on link_token creation (10/hour per user)
- Audit logging for link_token creation
- Input validation with strong params

---

## Out of Scope (Future Work)

The following are explicitly NOT included in v1:

- **Mobile responsive design** (desktop only for v1)
- **Feature flag** (this is 1.0 requirement, must work)
- **Rollback plan** (not in production yet, will nuke and restart if needed)
- **Service object extraction** (defer until pattern emerges)
- **Advanced rate limiting** (not yet needed)
- **Comprehensive error handling** (basic only, refine as needed)
- **Integration tests** (manual testing sufficient for v1)
- **Duplicate institution prevention** (separate future story)
- **Backfilling existing PlaidItems** (leave as NULL)

---

## Workflow

1. Pull master: `git pull origin main`
2. Create branch: `git checkout -b feature/epic0-product-buttons`
3. Run pre-implementation audit (check dependencies above)
4. Ask questions in log if anything unclear
5. Implement with green commits
6. Test thoroughly using manual test cases above
7. Push/PR when all acceptance criteria met

---

## Notes

- This PRD incorporates feedback from `epic0-prd4-addbuttons-feedback.md`
- Effort increased from S (4-6 hours) to M (8-12 hours) based on realistic breakdown
- Focus on getting v1 working; iterate based on real user behavior
- Plaid's institution filtering is flaky; we'll learn more during implementation
- Desktop-only for v1; mobile improvements are separate epic
