# PRD 0-03: Gate Chat Until Accounts Linked (Global)

**Epic**: Epic 0 - Immediate Quick Wins (Account Management Hub) v1.0
**Priority**: 3
**Effort**: S (3-5 hours)
**Branch**: `feature/epic0-gate-chat`

---

## Log Requirements

Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- **in the log put detailed steps for human to manually test and what the expected results**
- If asked to review please create a separate document called epic0-prd3-gate-chat-feedback.md

---

## Overview

Globally hide advisor chat interface until at least one successful PlaidItem exists—no change to location, just enforcement to avoid empty-state confusion.

---

## Requirements

### Functional
- In layout/application or chat component: if current_user.plaid_items.successfully_linked.empty? → render placeholder ("Link an account first to chat with your advisor") + link to `/accounts/link`
- Else → show full chat
- After first successful link → show celebratory toast: "🎉 Great! Your advisor chat is now active. Ask anything!"

### Non-functional
- No flicker on navigation; use before_action or view conditional
- Placeholder professional, with clear CTA

---

## PlaidItem Model Requirements

Add scope to PlaidItem model if not already present:

```ruby
# app/models/plaid_item.rb
scope :successfully_linked, -> {
  where(status: 'active')
    .where('last_synced_at > ?', 7.days.ago)
    .joins(:accounts).distinct
}
```

### Acceptance Criteria for Scope
- PlaidItem.successfully_linked returns only active items synced in last 7 days with accounts
- Unit test: verify scope excludes failed, degraded, and stale items

---

## Degraded State Handling

- If ALL linked accounts fail/expire after initial success, replace chat with: "Your accounts need attention. [Fix Accounts] to continue chatting."
- Re-check status on each page load (cache for 5 min to reduce queries)

---

## Implementation Location

### Option A: Global Layout (application.html.erb)
```ruby
# ApplicationHelper
def show_chat?
  return false unless user_signed_in?
  Rails.cache.fetch("user_#{current_user.id}_has_linked_accounts", expires_in: 5.minutes) do
    current_user.plaid_items.successfully_linked.exists?
  end
end

# app/views/layouts/application.html.erb
<%= render 'shared/chat' if show_chat? %>
<%= render 'shared/chat_placeholder' unless show_chat? %>
```

### Option B: Turbo Frames
- Conditionally load turbo_frame based on helper
- Use HTTP 204 (No Content) response if not authorized

### Option C: ViewComponent
```ruby
# app/components/chat_component.rb
class ChatComponent < ViewComponent::Base
  def render?
    return false unless helpers.user_signed_in?
    helpers.current_user.plaid_items.successfully_linked.exists?
  end
end
```

Choose approach based on existing chat implementation.

---

## Placeholder Design

```
┌─────────────────────────────────────┐
│  🔒 Financial Advisor Chat          │
│                                     │
│  Connect your accounts to get       │
│  personalized advice on:            │
│                                     │
│  ✓ Portfolio allocation             │
│  ✓ Tax optimization strategies      │
│  ✓ Net worth growth planning        │
│                                     │
│  [Connect Your First Account →]    │
└─────────────────────────────────────┘
```

---

## Feature Flag Integration

```ruby
def show_chat?
  return true unless ENV['EPIC0_GATE_CHAT_ENABLED'] == 'true'
  # ... gating logic
end
```

---

## Acceptance Criteria

- [ ] Fresh user → no chat visible, placeholder shows with link to `/accounts/link`
- [ ] After successful link → chat appears on refresh
- [ ] Placeholder renders correctly on all pages (if chat global)
- [ ] No errors when chat hidden
- [ ] If all accounts fail post-success → degraded placeholder shows
- [ ] Post-link toast fires on first success
- [ ] Cache works: doesn't query DB on every page load
- [ ] `successfully_linked` scope exists and works correctly

---

## Test Cases

### Controller/View Tests
- Assigns show_chat false if no successful PlaidItem
- Placeholder rendered when show_chat? is false
- Chat rendered when show_chat? is true

### Integration Tests
- Visit chat route with no accounts → shows placeholder
- After mock link → chat becomes visible
- Cache expiry works after 5 minutes

### Feature Tests
- Fresh user journey: signup → sees placeholder → links account → sees chat
- Degraded state: user with failed accounts sees "Fix Accounts" message

### Mobile Test Cases
- iPhone SE (small screen): placeholder doesn't overflow, text readable
- Android Chrome: touch targets ≥44px, CTA button works
- Landscape orientation: layout doesn't break
- Slow 3G: placeholder appears immediately, no blank screen

---

## Workflow

1. Pull master → `git checkout -b feature/epic0-gate-chat`
2. Add `successfully_linked` scope to PlaidItem (if missing)
3. Add `show_chat?` helper
4. Create placeholder partial/component
5. Update layout/chat component to use conditional
6. Add celebration toast logic
7. Plan if needed → green commits → push/PR

---

## Dependencies

- PlaidItem model with status and last_synced_at
- User authentication (Devise)
- Chat component location identified
- Toast notification system

---

## Security Considerations

- Ensure chat visibility check uses current_user (no cross-user leaks)
- Cache key includes user_id to prevent cache collision
- No sensitive data in placeholder

---

## Performance Requirements

- Cache `has_successful_plaid_items?` for 5 min per user
- Use `.exists?` instead of `.any?` for efficiency
- Ensure query uses index on (user_id, status, last_synced_at)

---

## UX Considerations

### Celebration Toast Timing
- Show immediately after first successful Plaid Link callback
- Don't show on subsequent links (track with flag: `first_link_completed_at`)

### Placeholder Copy Variations
- **No accounts**: "Link an account first to chat with your advisor"
- **All failed**: "Your accounts need attention. Fix Accounts to continue chatting."
- **Linking in progress**: "Syncing your accounts... Chat will be available shortly."

---

## Edge Cases

1. **User links account but sync takes 60+ seconds**: Show intermediate state
2. **User has account but it's stale (>7 days)**: Treat as no accounts
3. **User deletes all accounts**: Chat disappears, placeholder returns
4. **Multiple tabs open**: Use Turbo Streams or page refresh to sync state
