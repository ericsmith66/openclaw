#### PRD-4-05: Mobile UX Polish & Accessibility

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- In the log put detailed steps for human to manually test and what the expected results.
- If asked to review please create a separate document called <epic or prd name>-feedback.md.

**Overview**
Refine mobile experience with drawer auto-close, touch target verification, responsive layout tweaks, and comprehensive WCAG 2.1 AA accessibility pass including keyboard navigation, ARIA labels, screen reader testing, and automated axe-core tests. This PRD ensures the persona chat interface is fully accessible and mobile-optimized before launch.

**Requirements**

**Functional**:

**Mobile UX Refinements**:
- **Drawer auto-close**: After selecting conversation, drawer slides closed automatically (remove `drawer-open` class via Stimulus)
- **Model selector on mobile**: Move to drawer header (above conversation list) at <768px breakpoint
  - Full-width dropdown with clear label
  - Visible even when drawer collapsed (sticky header)
- **Send button visibility**: Always visible on mobile (not hidden by soft keyboard)
  - Use `bottom: env(safe-area-inset-bottom)` for notch support
  - Sticky positioning at bottom of chat pane
- **Touch targets**: Verify all interactive elements ≥44×44px
  - Conversations in sidebar: full-width rows, min-height 44px
  - Buttons: padding adjusted for 44px min
  - Dropdown options: 44px line-height
- **Horizontal scroll prevention**: Verify no unintended overflow on narrow viewports (320px)
- **Soft keyboard handling**: Chat input remains visible when keyboard open (iOS/Android tested)
- **Tap vs hover**: Convert hover tooltips to tap-to-show on mobile (Stimulus detects touch device)

**Accessibility (WCAG 2.1 AA)**:
- **Keyboard Navigation**:
  - Tab order: Hamburger → New Conversation → Conversations list → Model selector → Chat input → Send button
  - Enter: Activates buttons, selects conversation
  - Escape: Closes drawer, dismisses toasts
  - Arrow keys: Navigate dropdown options
- **ARIA Labels**:
  - Hamburger button: `aria-label="Open conversation list"`
  - New Conversation button: `aria-label="Start new conversation with [persona_name]"`
  - Conversation items: `aria-label="[title], last message: [preview], [time_ago]"`
  - Active conversation: `aria-current="true"`
  - Model selector: `aria-label="Select AI model for this conversation"`
  - Send button: `aria-label="Send message"`
  - Streaming indicator: `aria-live="polite" aria-label="Assistant is typing"`
- **Screen Reader Support**:
  - Chat messages: Proper heading structure (`<h2>` for conversation title, `<h3>` for message roles)
  - Message role identification: `<div role="log" aria-label="Chat messages">`
  - Timestamps: `<time datetime="ISO8601">` with `aria-label` for full date
  - Empty states: Descriptive text, not just visual
- **Color Contrast**: Verify all text meets WCAG AA (4.5:1 for normal text, 3:1 for large)
  - User message: Blue on white/light (check contrast)
  - Assistant message: Dark gray on light gray (check contrast)
  - Timestamps: Gray text, ensure readable
- **Focus Indicators**: Visible outline on all interactive elements (DaisyUI default or custom)
- **Skip Links**: "Skip to chat" link for keyboard users (hidden, shown on focus)

**Testing**:
- **Automated (axe-core)**:
  - Add `axe-core-capybara` gem to test suite
  - One axe test per major system spec:
    ```ruby
    test "persona chat page is accessible" do
      visit chats_persona_path(persona_id: "junie")
      assert_no_axe_violations
    end
    ```
- **Manual (Screen Reader)**:
  - VoiceOver (macOS/iOS): Navigate chat interface, verify all elements announced correctly
  - Test: New conversation, send message, switch conversation, change model
- **Manual (Keyboard Only)**:
  - Unplug mouse, navigate entire interface with keyboard
  - Verify all actions possible (create, send, switch, change model, close drawer)
- **Manual (Mobile Devices)**:
  - Real device testing: iPhone SE (375×667), iPhone 14 (390×844), Pixel 5 (393×851)
  - Verify touch targets, drawer behavior, keyboard handling, no horizontal scroll

**Non-Functional**:
- Drawer animation smooth (60fps, no jank)
- Touch interactions responsive (<100ms feedback)
- Screen reader announces changes without excessive verbosity
- All axe-core tests pass (0 violations)
- Keyboard-only navigation intuitive (logical tab order)

**Rails-Specific**:
- Stimulus: Update `conversation-sidebar_controller.js` with auto-close action
- CSS: Media queries for mobile breakpoints, touch target sizing
- Gem: `gem 'axe-core-capybara'` added to Gemfile (test group)
- Tests: `test/system/accessibility_test.rb` for axe-core checks
- ViewComponents: Add ARIA attributes to all components

**Error Scenarios & Fallbacks**:
- **Screen reader not detected**: UI still functional (ARIA labels ignored by visual users)
- **Touch target too small**: User can still tap (just harder), log warning in QA
- **Keyboard trap**: Escape key always closes drawer (prevent navigation lock)
- **Contrast fails**: Use DaisyUI built-in accessible color tokens (should pass by default)

**Architectural Context**
Progressive enhancement: Core functionality works without JavaScript (drawer defaults to open on no-JS, form submits via HTTP POST). ARIA attributes added via ViewComponent templates. Stimulus controllers detect touch devices (`'ontouchstart' in window`) and adjust behavior (e.g., tooltips). CSS media queries handle responsive layout. Axe-core runs in Capybara tests (headless Chrome with accessibility DevTools enabled). Manual testing on real devices via BrowserStack or local devices.

**Acceptance Criteria**
- Drawer auto-closes after selecting conversation on mobile
- Model selector appears in drawer header on mobile (<768px)
- All touch targets ≥44×44px (verified with Chrome DevTools ruler)
- No horizontal scroll on 320px viewport (iPhone SE landscape)
- Soft keyboard doesn't hide chat input on iOS/Android
- Tap tooltips work on mobile (no hover)
- Tab order logical (hamburger → new → list → selector → input → send)
- Enter activates buttons/selects conversations
- Escape closes drawer/dismisses toasts
- All ARIA labels present and descriptive
- Screen reader announces all elements correctly (VoiceOver tested)
- Color contrast ≥4.5:1 for all text (verified with Chrome DevTools)
- Focus indicators visible on all interactive elements
- Axe-core tests pass (0 violations)
- Keyboard-only navigation completes all flows
- Real device testing on iPhone SE + Pixel 5 passes
- Message role structure uses proper headings/roles

**Test Cases**

**System (Capybara + axe-core)**:
- `test/system/accessibility_test.rb`:
  ```ruby
  require 'axe/capybara'

  class AccessibilityTest < ApplicationSystemTestCase
    test "persona chat page has no accessibility violations" do
      user = users(:alice)
      run = create(:sap_run, user: user, persona_id: "junie")

      sign_in user
      visit chats_persona_path(persona_id: "junie", id: run.id)

      # Run axe-core scan
      assert_no_axe_violations
    end

    test "sidebar drawer has no violations when open" do
      user = users(:alice)
      sign_in user

      visit chats_persona_path(persona_id: "junie")

      # Open drawer (mobile simulation)
      page.driver.browser.manage.window.resize_to(375, 667)
      click_button "Open conversation list" # hamburger

      assert_no_axe_violations
    end

    test "model selector has no violations" do
      user = users(:alice)
      run = create(:sap_run, user: user, persona_id: "junie")

      sign_in user
      visit chats_persona_path(persona_id: "junie", id: run.id)

      # Click model selector
      find("select[aria-label='Select AI model']").click

      assert_no_axe_violations
    end
  end
  ```

- `test/system/keyboard_navigation_test.rb`:
  ```ruby
  test "user navigates with keyboard only" do
    user = users(:alice)
    create(:sap_run, user: user, persona_id: "junie", title: "Chat 1")
    create(:sap_run, user: user, persona_id: "junie", title: "Chat 2")

    sign_in user
    visit chats_persona_path(persona_id: "junie")

    # Tab to New Conversation button
    page.driver.browser.action.send_keys(:tab).perform
    assert_equal "New Conversation", page.evaluate_script("document.activeElement.textContent.trim()")

    # Tab to first conversation
    page.driver.browser.action.send_keys(:tab).perform
    assert page.evaluate_script("document.activeElement.getAttribute('data-conversation-id')").present?

    # Enter to select
    page.driver.browser.action.send_keys(:enter).perform

    # Chat pane loads
    assert_selector "#chat-pane-frame"
  end

  test "escape key closes drawer on mobile" do
    user = users(:alice)
    sign_in user

    visit chats_persona_path(persona_id: "junie")

    # Mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)

    # Open drawer
    click_button "Open conversation list"
    assert_selector ".drawer-side", visible: true

    # Press Escape
    page.driver.browser.action.send_keys(:escape).perform

    # Drawer closed
    assert_no_selector ".drawer-side.drawer-open"
  end
  ```

- `test/system/mobile_ux_test.rb`:
  ```ruby
  test "drawer auto-closes after selecting conversation" do
    user = users(:alice)
    run1 = create(:sap_run, user: user, persona_id: "junie", title: "Chat 1")
    run2 = create(:sap_run, user: user, persona_id: "junie", title: "Chat 2")

    sign_in user
    visit chats_persona_path(persona_id: "junie", id: run1.id)

    # Mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)

    # Open drawer
    click_button "Open conversation list"
    assert_selector ".drawer-side.drawer-open"

    # Click Chat 2
    click_on "Chat 2"

    # Drawer auto-closes
    assert_no_selector ".drawer-side.drawer-open", wait: 1
    # Chat pane updated
    assert_current_path chats_persona_path(persona_id: "junie", id: run2.id)
  end

  test "all touch targets are at least 44x44 pixels" do
    user = users(:alice)
    create(:sap_run, user: user, persona_id: "junie", title: "Chat 1")

    sign_in user
    visit chats_persona_path(persona_id: "junie")

    page.driver.browser.manage.window.resize_to(375, 667)

    # Check hamburger button
    hamburger = find("button[aria-label='Open conversation list']")
    assert hamburger.native.size.width >= 44
    assert hamburger.native.size.height >= 44

    # Check conversation item
    conversation = find("div[data-conversation-id]")
    assert conversation.native.size.height >= 44

    # Check send button
    send_btn = find("button[aria-label='Send message']")
    assert send_btn.native.size.width >= 44
    assert send_btn.native.size.height >= 44
  end

  test "no horizontal scroll on narrow viewport" do
    user = users(:alice)
    sign_in user

    visit chats_persona_path(persona_id: "junie")

    # iPhone SE landscape (narrowest)
    page.driver.browser.manage.window.resize_to(320, 568)

    # Check body scroll width
    body_scroll_width = page.evaluate_script("document.body.scrollWidth")
    viewport_width = 320

    assert body_scroll_width <= viewport_width, "Horizontal scroll detected: #{body_scroll_width}px > #{viewport_width}px"
  end
  ```

**Manual**:

1. **Mobile drawer auto-close** (Chrome DevTools mobile emulation, iPhone SE):
   - Visit `/chats/junie`
   - Drawer collapsed, hamburger visible
   - Click hamburger → drawer opens
   - Click conversation → drawer auto-closes, chat pane loads
   - Verify smooth animation (no jank)

2. **Touch targets** (Chrome DevTools with ruler):
   - Enable "Show rulers" in DevTools
   - Measure hamburger button: ≥44×44px ✅
   - Measure conversation items: height ≥44px ✅
   - Measure send button: ≥44×44px ✅
   - Measure dropdown options: line-height ≥44px ✅

3. **Keyboard navigation** (unplug mouse):
   - Tab from address bar → first focus: hamburger (or skip link)
   - Tab through: New Conversation → Conversations → Model selector → Chat input → Send
   - Enter on conversation → loads chat
   - Enter on send button → sends message
   - Escape → closes drawer (mobile), dismisses toasts

4. **Screen reader** (VoiceOver on macOS):
   - Enable VoiceOver (Cmd+F5)
   - Navigate to `/chats/junie`
   - Verify announcements:
     - "Open conversation list, button"
     - "Start new conversation with JunieDev, button"
     - "Fix Bug, last message: How do I debug, 2 hours ago, button, current"
     - "Select AI model for this conversation, popup button"
     - "Send message, button"
   - Send message → verify "Assistant is typing" announced
   - Response appears → verify message content announced

5. **Color contrast** (Chrome DevTools, "Show contrast ratio"):
   - User message: Blue text on white → check ratio (should be ≥4.5:1)
   - Assistant message: Dark gray on light gray → check ratio
   - Timestamps: Gray text → check ratio
   - All should pass WCAG AA

6. **Focus indicators**:
   - Tab through interface
   - Verify visible outline on every focused element (DaisyUI default blue ring or custom)
   - No invisible focus (common accessibility bug)

7. **Real device testing**:
   - **iPhone SE** (375×667):
     - Drawer behavior: hamburger, open, auto-close
     - Soft keyboard: Chat input stays visible, send button accessible
     - Touch targets: All tappable without precision
     - No horizontal scroll
   - **Pixel 5** (393×851):
     - Same tests as iPhone
     - Verify Android soft keyboard handling

8. **Horizontal scroll check**:
   - Chrome DevTools → 320px width (iPhone SE landscape)
   - Scroll horizontally → should not be possible
   - Check all pages: sidebar, chat pane, empty states

9. **Tap tooltips** (real touch device):
   - Hover tooltips on desktop convert to tap-to-show on mobile
   - Tap info icon on disclaimer → tooltip appears
   - Tap outside → tooltip dismisses

**Workflow**
Use Claude Sonnet 4.5. `git pull origin main`. `git checkout -b feature/prd-4-05-mobile-accessibility`. Ask questions and build detailed plan first. Install `axe-core-capybara` gem. Add ARIA labels to all ViewComponents. Update Stimulus for drawer auto-close. Test keyboard navigation manually (unplug mouse). Test screen reader (VoiceOver). Run axe-core tests. Fix violations. Test on real devices (BrowserStack or local). Verify touch targets with DevTools. Commit only green (tests pass, 0 axe violations). Open PR for review.

**Dependencies**:
- PRD 4-04 (integration complete, all flows working)

**Related PRDs**: All previous PRDs (4-01 through 4-04) must be complete for this polish pass.

**Success Metrics** (from Epic overview):
- ✅ Mobile drawer responsive on iPhone SE (smallest target)
- ✅ All WCAG 2.1 AA criteria met (axe-core passes)
- ✅ Keyboard navigation completes all flows
- ✅ Screen reader testing passes (VoiceOver)
- ✅ Real device testing on iOS + Android passes

**Axe-core Setup**:
```ruby
# Gemfile (test group)
gem 'axe-core-capybara'

# test/test_helper.rb
require 'axe/capybara'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Axe::Capybara::Matchers
  # ...
end
```

**ARIA Label Examples**:
```erb
<!-- Hamburger button -->
<button data-action="click->conversation-sidebar#toggle"
        aria-label="Open conversation list"
        class="btn btn-ghost">
  ☰
</button>

<!-- Conversation item -->
<div data-conversation-id="<%= run.id %>"
     role="button"
     tabindex="0"
     aria-label="<%= run.title %>, last message: <%= run.last_message_preview %>, <%= time_ago_in_words(run.updated_at) %> ago"
     aria-current="<%= 'true' if active %>"
     data-action="click->conversation-sidebar#switchTo">
  <!-- ... -->
</div>

<!-- Model selector -->
<select aria-label="Select AI model for this conversation"
        data-controller="model-selector"
        data-action="change->model-selector#update">
  <!-- options -->
</select>

<!-- Streaming indicator -->
<div role="status"
     aria-live="polite"
     aria-label="Assistant is typing"
     class="streaming-cursor">
  ▊
</div>

<!-- Chat messages container -->
<div role="log"
     aria-label="Chat messages"
     id="messages">
  <!-- messages -->
</div>
```
