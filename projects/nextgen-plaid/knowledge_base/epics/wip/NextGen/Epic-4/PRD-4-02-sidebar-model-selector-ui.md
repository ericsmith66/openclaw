#### PRD-4-02: Conversation Sidebar & Model Selector UI

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- In the log put detailed steps for human to manually test and what the expected results.
- If asked to review please create a separate document called <epic or prd name>-feedback.md.

**Overview**
Build the NEW user-facing conversation sidebar ViewComponent at `/chats/[persona]` (starting with `/chats/financial-advisor`) with DaisyUI drawer (mobile) and fixed sidebar (desktop), showing most recent 50 conversations with "Load more" pagination, "New Conversation" button, active highlight, and model selector dropdown in chat pane header. Includes Stimulus controllers for sidebar navigation and model persistence. This is a completely NEW interface, separate from admin `/agent_hub`. Uses PersonaConversation/PersonaMessage models. This PRD merges original PRD 2+3 for faster iteration and tighter UX coupling.

**Requirements**

**Functional**:

**Sidebar Component**:
- Display most recent 50 conversations for current persona, sorted by `updated_at DESC`
- Each conversation item shows:
  - Title (LLM-generated or truncated, max 40 chars with ellipsis)
  - Last message preview (60 chars, from `last_message_preview` method)
  - Relative timestamp ("2m ago", "1h ago", "Yesterday")
- Active conversation highlighted with DaisyUI `bg-base-300` class
- "New Conversation" button prominent at top (inside drawer on mobile)
- "Load more" button at bottom loads next 50 conversations via Turbo Frame (if >50 exist)
- Click conversation → loads chat pane via Turbo Frame (no page reload)

**Mobile Behavior** (<768px):
- Sidebar: Collapsed by default (DaisyUI drawer overlay)
- Hamburger icon (☰) fixed top-left opens drawer
- Select conversation → auto-close drawer, load chat in main pane
- Model selector dropdown moves to drawer header (above conversation list) on mobile

**Desktop Behavior** (≥768px):
- Sidebar: Fixed left column (w-64 or w-80), always visible
- Model selector in chat pane header (top-right)
- No drawer/hamburger

**Model Selector Component**:
- Dropdown in chat pane header (DaisyUI dropdown component)
- Label: "Model: [current_model_name]" with chevron-down icon
- Options fetched from `ModelDiscoveryService.available_models` (cached 1hr)
- Display format: "Llama 3.1 70B" (friendly name), value: "llama3.1:70b" (model ID)
- On select: Update `persona_conversation.model_name` via Turbo Stream, show toast "Model changed to [name]. This will apply to your next message."
- Default: Inherit last-used model for persona (from PRD 4-01 `create_conversation`)

**Empty States**:
- No conversations yet: Large "Start a New Conversation" button in sidebar center
- Sidebar empty after filter: "No conversations found—create a new one"
- Chat pane empty (no active conversation): Welcome message with persona intro (e.g., "Hi, I'm Warren Buffett. Let's talk about value investing and long-term wealth building.")

**Stimulus Controllers**:
- `conversation-sidebar_controller.js`:
  - Actions: `switchTo(event)` — loads conversation via Turbo Frame, updates active highlight
  - Targets: `conversationItem`, `activeIndicator`
- `model-selector_controller.js`:
  - Actions: `change(event)` — persists model change, broadcasts Turbo Stream, shows toast
  - Targets: `dropdown`, `toast`

**Non-Functional**:
- Sidebar render <300ms for 50 conversations
- Conversation switch <500ms (Turbo Frame load)
- Model selector dropdown opens instantly (no API delay, uses cached models)
- Touch targets ≥44×44px on mobile
- Keyboard navigation: Tab through conversations, Enter to select, Escape to close drawer

**Rails-Specific**:
- ViewComponents (NEW namespace, not related to agent_hub):
  - `app/components/persona_chats/sidebar_component.rb` + `sidebar_component.html.erb`
  - `app/components/persona_chats/model_selector_component.rb` + `model_selector_component.html.erb`
  - `app/components/persona_chats/empty_state_component.rb` (reusable for all empty states)
- Controller: `PersonaChatsController#index` (NEW controller, NOT ChatsController)
  - Route: `/chats/[persona]` maps to `PersonaChatsController#index`
  - Fetches: `@conversations = PersonaConversation.for_persona(params[:persona_id]).for_user(current_user).recent_first.limit(50)`
  - Passes to sidebar component
- Turbo Frames: `#conversation-sidebar-frame`, `#chat-pane-frame`, `#model-selector-frame`
- Stimulus: `app/javascript/controllers/conversation-sidebar_controller.js`, `model-selector_controller.js`
- DaisyUI classes: `drawer`, `drawer-side`, `drawer-content`, `btn`, `dropdown`, `stat`, `skeleton`

**Error Scenarios & Fallbacks**:
- **ModelDiscoveryService returns empty**: Show fallback "Models unavailable. Using default: llama3.1:70b", disable dropdown
- **Conversation load fails** (deleted conversation): Flash error "Conversation not found", redirect to first available conversation
- **Model change fails** (validation error, DB down): Revert dropdown to current model, show error toast "Failed to update model—try again"
- **Turbo Frame timeout**: Show skeleton loader, then "Loading failed—refresh page"
- **No conversations and create fails**: Show error message "Failed to create conversation—check connection"

**Architectural Context**
MVC: `PersonaChatsController` (NEW controller, separate from any agent_hub code) handles routing and data fetching for `/chats/[persona]`. Sidebar component receives array of `PersonaConversation` objects (or presenter objects with `id`, `title`, `last_message_preview`, `updated_at`). Model selector component receives current `persona_conversation` and array of available models. Stimulus handles client-side interactions (highlight, dropdown, Turbo Frame targeting). Turbo Frames enable SPA-like navigation without full page reloads. Security: Application-level scoping via `current_user.persona_conversations`. No direct ActiveRecord in components—controller passes plain Ruby objects. This is completely separate from admin Agent Hub.

**Acceptance Criteria**
- Sidebar displays most recent 50 conversations sorted by updated_at DESC
- Each conversation shows title, preview, timestamp
- Active conversation highlighted with bg-base-300
- "New Conversation" button creates new run and loads chat pane
- "Load more" button loads next 50 conversations (if >50 exist)
- Click conversation → loads chat pane via Turbo Frame, no page reload
- Mobile: Drawer collapses, hamburger opens/closes, auto-closes on selection
- Desktop: Fixed sidebar always visible
- Model selector shows current model, dropdown lists available models
- Select model → updates sap_run.model_name, shows toast notification
- Empty states display correctly (no conversations, no active chat)
- Keyboard navigation works (Tab, Enter, Escape)
- All touch targets ≥44×44px on mobile (verified with Chrome DevTools)
- ViewComponent previews work at `/rails/view_components` in development
- All Minitest component/integration tests pass

**Test Cases**

**Unit (Minitest)**:
- `test/components/chats/sidebar_component_test.rb`:
  ```ruby
  test "renders conversations with title and preview" do
    runs = [
      OpenStruct.new(id: 1, title: "Fix Bug", last_message_preview: "How do I...", updated_at: 2.hours.ago),
      OpenStruct.new(id: 2, title: "Deploy App", last_message_preview: "What's the...", updated_at: 1.day.ago)
    ]
    render_inline(Chats::SidebarComponent.new(conversations: runs, active_id: 1))

    assert_selector "div[data-conversation-id='1']", text: "Fix Bug"
    assert_selector "div[data-conversation-id='1']", text: "How do I..."
    assert_selector "div[data-conversation-id='1'].bg-base-300" # active highlight
  end

  test "renders empty state when no conversations" do
    render_inline(Chats::SidebarComponent.new(conversations: [], active_id: nil))
    assert_text "Start a New Conversation"
  end

  test "renders load more button when has_more is true" do
    render_inline(Chats::SidebarComponent.new(conversations: [], active_id: nil, has_more: true))
    assert_selector "button", text: "Load more"
  end
  ```

- `test/components/chats/model_selector_component_test.rb`:
  ```ruby
  test "renders dropdown with current model" do
    models = [{ id: "llama3.1:70b", name: "Llama 3.1 70B" }, { id: "llama3.1:8b", name: "Llama 3.1 8B" }]
    run = OpenStruct.new(id: 1, model_name: "llama3.1:70b")

    render_inline(Chats::ModelSelectorComponent.new(sap_run: run, available_models: models))

    assert_selector "select option[selected]", text: "Llama 3.1 70B"
    assert_selector "select option", text: "Llama 3.1 8B"
  end

  test "shows fallback when no models available" do
    render_inline(Chats::ModelSelectorComponent.new(sap_run: nil, available_models: []))
    assert_text "Models unavailable"
  end
  ```

**Integration (Minitest)**:
- `test/integration/persona_chat_navigation_test.rb`:
  ```ruby
  test "sidebar shows conversations and switches on click" do
    user = users(:alice)
    create(:sap_run, user: user, persona_id: "junie", title: "Chat 1")
    create(:sap_run, user: user, persona_id: "junie", title: "Chat 2")

    sign_in user
    get chats_path(persona_id: "junie")

    assert_select "div[data-conversation-id]", count: 2
    assert_select "div", text: "Chat 1"
  end

  test "model selector persists change" do
    user = users(:alice)
    run = create(:sap_run, user: user, persona_id: "junie", model_name: "llama3.1:70b")

    sign_in user
    patch update_model_chats_path(id: run.id, model_name: "llama3.1:8b")

    assert_equal "llama3.1:8b", run.reload.model_name
    assert_select "div.toast", text: "Model changed"
  end
  ```

**System (Capybara)**:
- `test/system/persona_chat_test.rb`:
  ```ruby
  test "user switches conversations in sidebar" do
    user = users(:alice)
    run1 = create(:sap_run, user: user, persona_id: "junie", title: "Chat 1")
    run2 = create(:sap_run, user: user, persona_id: "junie", title: "Chat 2")

    sign_in user
    visit chats_path(persona_id: "junie")

    # Click Chat 2
    click_on "Chat 2"

    # Chat pane updates via Turbo Frame
    assert_selector "#chat-pane-frame[data-conversation-id='#{run2.id}']"
    assert_selector "div[data-conversation-id='#{run2.id}'].bg-base-300" # highlight
  end

  test "user changes model and sees toast" do
    user = users(:alice)
    run = create(:sap_run, user: user, persona_id: "junie", model_name: "llama3.1:70b")

    sign_in user
    visit chats_path(persona_id: "junie", id: run.id)

    select "Llama 3.1 8B", from: "Model selector"

    assert_text "Model changed to Llama 3.1 8B"
    assert_equal "llama3.1:8b", run.reload.model_name
  end
  ```

**Manual**:
1. Desktop view:
   - Visit `/chats/financial-advisor` → verify fixed sidebar on left, chat pane on right
   - Sidebar shows most recent 50 conversations (create test data if <50)
   - Click conversation → chat pane updates, no page reload
   - Active conversation highlighted with darker background
   - Model selector in chat header shows current model
   - Change model → toast appears "Model changed to [name]"
   - Verify dropdown lists all available models from ModelDiscoveryService

2. Mobile view (Chrome DevTools, iPhone SE 375×667):
   - Visit `/chats/financial-advisor` → sidebar collapsed, hamburger icon visible
   - Click hamburger → drawer slides in from left
   - "New Conversation" button prominent at top
   - Model selector appears in drawer header (above conversations)
   - Click conversation → drawer auto-closes, chat pane loads
   - Verify all touch targets ≥44×44px (use DevTools ruler)

3. Empty states:
   - Delete all conversations → "Start a New Conversation" button in sidebar center
   - Click "New Conversation" → creates conversation, loads empty chat pane with welcome: "Hi, I'm Warren Buffett. Let's talk about value investing..."
   - No active conversation → chat pane shows Warren Buffett persona intro

4. Pagination:
   - Create >50 conversations → "Load more" button appears at bottom
   - Click "Load more" → next 50 conversations load via Turbo Frame
   - Verify no page reload

5. Error scenarios:
   - Stop ModelDiscoveryService → model dropdown shows "Models unavailable"
   - Delete active conversation → error flash, redirect to first conversation
   - Model change fails (DB down) → dropdown reverts, error toast

**Workflow**
Use Claude Sonnet 4.5. `git pull origin main`. `git checkout -b feature/prd-4-02-sidebar-model-selector`. Ask questions and build detailed plan first. Create NEW controller `PersonaChatsController` (NOT modifying any agent_hub code). Create ViewComponents under `app/components/persona_chats/` namespace with previews first (test in browser at `/rails/view_components`). Add Stimulus controllers with console.log for debugging. Wire up Turbo Frames incrementally. Test at route `/chats/financial-advisor`. Commit only green (tests pass). Open PR for review.

**Dependencies**: PRD 4-01 (schema must exist: persona_id, model_name, title columns)

**Related PRDs**: PRD 4-03 (will integrate streaming), PRD 4-04 (end-to-end tests)

**Mobile Specifications** (per Junie feedback #3):
- Drawer behavior: DaisyUI `drawer-mobile` class
- Hamburger: Fixed `top-4 left-4` with `z-50`
- Auto-close: Stimulus action removes `drawer-open` class on conversation select
- Model selector on mobile: Positioned in `drawer-side` header, above conversation list (full-width dropdown)
- Send button: Use Enter key on desktop, visible button + Enter on mobile (Stimulus detects mobile via window.innerWidth)
