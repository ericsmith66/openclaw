# PRD 0-02: Clear Plaid Connect Button (Accounts Link Page)

**Epic**: Epic 0 - Immediate Quick Wins (Account Management Hub) v1.0
**Priority**: 2
**Effort**: XS (1-2 hours)
**Branch**: `feature/epic0-connect-label`

---

## Log Requirements

Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- **in the log put detailed steps for human to manually test and what the expected results**
- If asked to review please create a separate document called epic0-prd2-connect-label-feedback.md

---

## Overview

Update the primary Plaid Link button on `/accounts/link` to clear, descriptive text ("Link Bank or Brokerage") with optional subtitle for better user understanding.

---

## Requirements

### Functional
- Change button text to I18n.t('accounts.link_button') with default "Link Bank or Brokerage"
- Add subtitle/help text: "Securely connect Schwab, JPMC, Amex, Stellar…"
- Trigger standard Plaid Link flow on click

### Non-functional
- DaisyUI primary button styling + optional icon (bank/building)
- Accessible label/ARIA ("Connect new brokerage account")

---

## Icon Specification

- Use Heroicons `building-library` (bank icon, matches DaisyUI ecosystem)
- Placement: Left of text, 20px size, primary color
- Add aria-hidden="true" to icon since button text is descriptive

---

## I18n Configuration

Ensure config/locales/en.yml contains:

```yaml
en:
  accounts:
    link_button: "Link Bank or Brokerage"
    link_subtitle: "Securely connect Schwab, JPMC, Amex, Stellar…"
```

---

## Feature Flag Integration

In view or controller:

```ruby
# Only show new button text if feature enabled
if ENV['EPIC0_CONNECT_LABEL_ENABLED'] == 'true'
  t('accounts.link_button')
else
  # Original button text
end
```

---

## Acceptance Criteria

- [ ] Button text/subtitle match spec on `/accounts/link`
- [ ] Click initiates Plaid Link (no functional change)
- [ ] Renders cleanly on mobile/desktop
- [ ] No regressions in existing Link callback
- [ ] If Plaid Link fails to load → show toast "Connection failed. Please try again or contact support@nextgen-plaid.com"
- [ ] I18n key exists in locales file

---

## Test Cases

### View Tests
- `accounts/link` renders correct button text/subtitle
- Icon renders with correct attributes
- I18n fallback works if translation missing

### Manual Tests
- Visit `/accounts/link` → text matches spec
- Click button → Plaid Link opens normally

### Mobile Test Cases
- iPhone SE (small screen): buttons don't overlap, text readable
- Android Chrome: touch targets ≥44px, no tap delay
- Landscape orientation: layout doesn't break
- Slow 3G: loading states appear immediately, no blank screens

---

## Workflow

1. Pull master → `git checkout -b feature/epic0-connect-label`
2. Update I18n file
3. Update view with new button text/icon
4. Test locally (mobile + desktop)
5. Simple commit → push/PR

---

## Dependencies

- Plaid Link integration (existing)
- DaisyUI styling framework
- Heroicons library

---

## Nice-to-Have Enhancement

Add a "Supported Institutions" modal/tooltip that opens when user hovers or clicks an info icon next to the button. This reduces friction if user is unsure if their bank is supported.

**Implementation** (optional for v2):
- Add info icon next to button
- Modal lists: Schwab, JPMC, Amex, Fidelity, Vanguard, etc.
- Link to Plaid's full institution list

---

## Security Considerations

- No security changes (visual only)
- Ensure CSRF token present on form if applicable

---

## Accessibility Notes

- Button text is descriptive enough for screen readers
- Icon has aria-hidden="true" to avoid redundancy
- Color contrast meets WCAG AA standards
- Focus indicator visible on keyboard navigation
