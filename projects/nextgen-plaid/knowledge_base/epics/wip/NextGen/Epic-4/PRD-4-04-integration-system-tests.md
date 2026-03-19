#### PRD-4-04: End-to-End Integration & System Tests

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- In the log put detailed steps for human to manually test and what the expected results.
- If asked to review please create a separate document called <epic or prd name>-feedback.md.

**Overview**
Wire together all Epic 4 components with routing, auto-title trigger on first message exchange, comprehensive Capybara system tests for all user flows (new conversation, model selection, conversation switching, streaming response, title generation), final UI polish (timestamps, ellipsis, active highlights), and observability logging for key events.

**Requirements**

**Functional**:

**Routing**:
- Primary route: `GET /chats/:persona_id` → `PersonaChatsController#index` (NEW controller, not ChatsController)
  - Shows sidebar with conversations + chat pane for active conversation
  - Params: `persona_id` (required), `id` (optional, active conversation ID)
- Default redirect: `GET /chats` → redirects to `/chats/financial-advisor` (default persona)
- New conversation: `POST /chats/:persona_id/conversations` → creates PersonaConversation, redirects to `/chats/:persona_id?id=[new_conversation_id]`
- Switch conversation: Handled via Turbo Frame (no route change, updates `#chat-pane-frame` only)
- Update model: `PATCH /chats/:persona_id/conversations/:id/model` → updates persona_conversation.model_name, broadcasts Turbo Stream

**Auto-Title Trigger**:
- After first user message + assistant response saved to persona_messages:
  - Check if `persona_conversation.title` is still truncated (contains "..." or "Chat [date]")
  - If yes: Call `persona_conversation.generate_title_from_first_message` (enqueues TitleGenerationJob)
- Implementation: Controller action or ActiveRecord callback on `PersonaMessage.create`
- Non-blocking: Job runs async, sidebar updates via Turbo Stream when title generated

**UI Polish**:
- **Timestamps**: Relative format using `time_ago_in_words` helper
  - <1m: "Just now"
  - <1h: "5m ago", "45m ago"
  - <24h: "2h ago", "12h ago"
  - <7d: "Yesterday", "2 days ago"
  - ≥7d: "Jan 15", "Dec 20"
- **Long titles**: CSS `text-overflow: ellipsis; overflow: hidden; white-space: nowrap;` on sidebar items (max-width)
- **Active conversation**: DaisyUI `bg-base-300` + subtle left border (`border-l-4 border-primary`)
- **Message bubbles**:
  - User: Right-aligned, blue background (`bg-primary text-primary-content`), rounded
  - Assistant: Left-aligned, gray background (`bg-base-200`), rounded
  - Prose class for Markdown rendering
- **Send button**: Primary button with icon, disabled during streaming
- **Empty chat pane**: Welcome message with Warren Buffett persona: "Hi, I'm Warren Buffett. Let's talk about value investing and long-term wealth building." (from Personas config)

**Observability Logging** (per Eric feedback #14):
- Log key events with Rails.logger.info:
  ```ruby
  # New conversation
  Rails.logger.info "[PersonaChat] new_conversation user=#{user.id} persona=#{persona_id} run_id=#{run.id}"

  # Model switch
  Rails.logger.info "[PersonaChat] model_switch user=#{user.id} run=#{run.id} from=#{old_model} to=#{new_model}"

  # Title generation
  Rails.logger.info "[PersonaChat] title_gen_success run=#{run.id} title='#{new_title}'"
  Rails.logger.warn "[PersonaChat] title_gen_failed run=#{run.id} error=#{e.message}"

  # Streaming
  Rails.logger.info "[PersonaChat] streaming_start run=#{run.id} model=#{model} persona=#{persona_id}"
  Rails.logger.info "[PersonaChat] streaming_complete run=#{run.id} tokens=#{tokens} duration_ms=#{duration}"
  Rails.logger.error "[PersonaChat] streaming_error run=#{run.id} error=#{e.class} message=#{e.message}"
  ```

**Non-Functional**:
- End-to-end flow <3s from "Send" to first token streamed
- Title generation completes within 3 seconds (async, non-blocking)
- All system tests pass (Capybara, headless Chrome)
- No console errors in browser DevTools during any flow
- No N+1 queries (verified with `bullet` gem in test environment)

**Rails-Specific**:
- Routes: `config/routes.rb`
  ```ruby
  namespace :chats do
    get '', to: redirect('/chats/financial-advisor')
    get ':persona_id', to: 'persona_chats#index', as: :persona
    post ':persona_id/conversations', to: 'persona_chats#create'
    patch ':persona_id/conversations/:id/model', to: 'persona_chats#update_model'
  end
  ```
- Controller: `app/controllers/persona_chats_controller.rb` (NEW controller, separate from any agent_hub code)
- System tests: `test/system/persona_chat_test.rb` (Capybara with headless Chrome)
- Fixtures: `test/fixtures/persona_conversations.yml`, `test/fixtures/persona_messages.yml`

**Error Scenarios & Fallbacks**:
- **Invalid persona_id in URL**: 404 error or redirect to `/chats/financial-advisor` with flash: "Persona not found"
- **Conversation ID not found**: Flash error "Conversation not found", load first available conversation
- **User tries to access another user's conversation**: 403 Forbidden (application-level scoping enforced)
- **Title generation fails**: Keep truncated title, log error, continue (non-critical)
- **Streaming fails**: Show error toast, allow retry (covered in PRD 4-03)

**Architectural Context**
MVC: NEW `PersonaChatsController` (separate from any agent_hub code) orchestrates all pieces for `/chats/[persona]`—fetches conversations via `PersonaConversation.for_persona(persona_id).for_user(current_user)`, passes to sidebar component, loads active conversation + messages, handles new conversation creation and model updates. Turbo Frames handle partial updates (sidebar, chat pane, model selector). Turbo Streams handle real-time updates (new messages, title changes, error toasts) via NEW PersonaChatChannel. Stimulus controllers add client-side interactivity. Security: Devise authentication required, application-level scoping filters via `current_user`. Observability: Rails.logger for key events, no Sentry yet (defer to future). This is completely separate from admin Agent Hub.

**Acceptance Criteria**
- `GET /chats` redirects to `/chats/financial-advisor`
- `GET /chats/financial-advisor` shows sidebar + chat pane with Warren Buffett welcome
- Click "New Conversation" → creates PersonaConversation, loads empty chat pane
- Send message → streams response via PersonaChatChannel, auto-triggers title generation after first exchange
- Title updates in sidebar within 3 seconds (async)
- Click conversation in sidebar → chat pane updates via Turbo Frame, no page reload
- Change model → toast notification, persona_conversation.model_name updated, logs event
- All manual test scenarios pass
- All Capybara system tests pass
- Timestamps display correctly (relative format)
- Long titles truncated with ellipsis
- Active conversation highlighted
- Message bubbles styled correctly (user right/blue, assistant left/gray)
- Empty chat pane shows Warren Buffett welcome message
- No console errors in browser DevTools
- No N+1 queries (bullet gem clean)
- PersonaChatsController completely separate from agent_hub code

**Test Cases**

**System (Capybara)**:
- `test/system/persona_chat_test.rb`:
  ```ruby
  class PersonaChatTest < ApplicationSystemTestCase
    test "user creates new conversation and sends message" do
      user = users(:alice)
      sign_in user

      visit chats_path

      # Redirected to /chats/junie
      assert_current_path chats_persona_path(persona_id: "junie")

      # Click "New Conversation"
      click_button "New Conversation"

      # Empty chat pane with welcome message
      assert_text "Hi, I'm JunieDev"

      # Send message
      fill_in "Message", with: "Hello, Junie!"
      click_button "Send"

      # Streaming cursor appears
      assert_selector ".streaming-cursor", text: "▊"

      # Response appears (wait for streaming to complete)
      assert_text "Hello! How can I help you today?", wait: 5

      # Cursor disappears
      assert_no_selector ".streaming-cursor"

      # Title updates in sidebar (async, within 3s)
      assert_text "Hello Junie", wait: 3 # LLM-generated title
    end

    test "user switches between conversations" do
      user = users(:alice)
      run1 = create(:sap_run, user: user, persona_id: "junie", title: "Fix Bug")
      run2 = create(:sap_run, user: user, persona_id: "junie", title: "Deploy App")
      create(:sap_message, sap_run: run1, role: "user", content: "Help me debug")
      create(:sap_message, sap_run: run2, role: "user", content: "How do I deploy?")

      sign_in user
      visit chats_persona_path(persona_id: "junie", id: run1.id)

      # Chat pane shows run1 messages
      assert_text "Help me debug"

      # Click run2 in sidebar
      click_on "Deploy App"

      # Chat pane updates via Turbo Frame
      assert_text "How do I deploy?"
      assert_no_text "Help me debug"

      # Active highlight moves to run2
      assert_selector "div[data-conversation-id='#{run2.id}'].bg-base-300"
    end

    test "user changes model and sees notification" do
      user = users(:alice)
      run = create(:sap_run, user: user, persona_id: "junie", model_name: "llama3.1:70b")

      sign_in user
      visit chats_persona_path(persona_id: "junie", id: run.id)

      # Current model shown in dropdown
      assert_selector "select option[selected]", text: "Llama 3.1 70B"

      # Change model
      select "Llama 3.1 8B", from: "Model selector"

      # Toast notification appears
      assert_text "Model changed to Llama 3.1 8B", wait: 2

      # sap_run updated
      assert_equal "llama3.1:8b", run.reload.model_name
    end

    test "title generation updates sidebar async" do
      user = users(:alice)
      run = create(:sap_run, user: user, persona_id: "junie", title: "Chat Jan 29")

      sign_in user
      visit chats_persona_path(persona_id: "junie", id: run.id)

      # Initial truncated title in sidebar
      assert_text "Chat Jan 29"

      # Send first message
      fill_in "Message", with: "How do I fix a Ruby bug?"
      click_button "Send"

      # Wait for response (triggers title generation)
      assert_text /bug/, wait: 5

      # Title updates in sidebar (LLM-generated, within 3s)
      assert_text "Fix Ruby Bug", wait: 3
      assert_no_text "Chat Jan 29"
    end

    test "timestamps display in relative format" do
      user = users(:alice)
      run1 = create(:sap_run, user: user, persona_id: "junie", title: "Recent", updated_at: 5.minutes.ago)
      run2 = create(:sap_run, user: user, persona_id: "junie", title: "Yesterday", updated_at: 1.day.ago)

      sign_in user
      visit chats_persona_path(persona_id: "junie")

      # Sidebar shows relative timestamps
      within "div[data-conversation-id='#{run1.id}']" do
        assert_text "5m ago"
      end

      within "div[data-conversation-id='#{run2.id}']" do
        assert_text "1 day ago"
      end
    end

    test "empty state shows when no conversations" do
      user = users(:alice)
      sign_in user

      visit chats_persona_path(persona_id: "junie")

      # Empty sidebar
      assert_text "Start a New Conversation"
      assert_button "New Conversation"

      # Empty chat pane
      assert_text "Hi, I'm JunieDev"
      assert_text "Your coding tutor"
    end

    test "invalid persona redirects with error" do
      user = users(:alice)
      sign_in user

      visit chats_persona_path(persona_id: "invalid")

      # Redirected to default persona
      assert_current_path chats_persona_path(persona_id: "junie")
      assert_text "Persona not found"
    end
  end
  ```

**Integration (Minitest)**:
- `test/integration/chats_routing_test.rb`:
  ```ruby
  test "default route redirects to junie" do
    user = users(:alice)
    sign_in user

    get chats_path
    assert_redirected_to chats_persona_path(persona_id: "junie")
  end

  test "new conversation creates run" do
    user = users(:alice)
    sign_in user

    assert_difference 'SapRun.count', 1 do
      post chats_persona_conversations_path(persona_id: "junie")
    end

    run = SapRun.last
    assert_equal "junie", run.persona_id
    assert_equal user.id, run.user_id
  end
  ```

**Manual**:
1. **End-to-end new conversation flow**:
   - Visit `/chats` (not logged in) → redirected to login
   - Log in → redirected to `/chats/financial-advisor`
   - Sidebar empty → "Start a New Conversation" button
   - Click "New Conversation" → PersonaConversation created, empty chat pane with "Hi, I'm Warren Buffett. Let's talk about value investing..."
   - Send message "What are your top 3 investment principles?"
   - Watch streaming cursor blink during response via PersonaChatChannel
   - Response completes, cursor disappears
   - Response should mention value investing, long-term thinking, quality businesses
   - Sidebar updates with LLM-generated title (within 3s): "Investment Principles"

2. **Conversation switching**:
   - Create 3 conversations with different messages
   - Click conversation 2 in sidebar → chat pane updates instantly (no reload)
   - Active highlight moves to conversation 2 (darker background + left border)
   - Click conversation 3 → chat pane updates
   - Verify no page reloads (check Network tab in DevTools)

3. **Model switching**:
   - Active conversation with 70b model
   - Change to 8b via dropdown
   - Toast appears: "Model changed to Llama 3.1 8B. This will apply to your next message."
   - Send message, verify logs show 8b model used
   - Rails logs: `[PersonaChat] model_switch user=1 run=5 from=llama3.1:70b to=llama3.1:8b`

4. **Title generation**:
   - New conversation with auto-generated title "Chat Jan 29"
   - Send first message + receive response
   - Sidebar title updates within 3s: "Your Question Here" (LLM-generated)
   - Rails logs: `[PersonaChat] title_gen_success run=5 title='Your Question Here'`

5. **UI polish**:
   - Timestamps: Verify relative format ("2m ago", "1h ago", "Yesterday")
   - Long titles: Verify ellipsis on titles >40 chars
   - Message bubbles: User right/blue, assistant left/gray, Markdown rendered
   - Empty states: No conversations → large "New Conversation" button
   - Disclaimer: Always visible in chat header

6. **Error handling**:
   - Invalid persona URL `/chats/invalid` → redirected to `/chats/financial-advisor`, flash error
   - Access another user's conversation (manually set ID in URL) → 403 Forbidden
   - Title generation timeout → sidebar keeps truncated title, no crash

7. **Performance**:
   - Open Rails console, run `Bullet.enable = true`
   - Visit `/chats/financial-advisor` → verify no N+1 queries in console
   - Load 50 conversations → verify no slowdown (<300ms render)

**Workflow**
Use Claude Sonnet 4.5. `git pull origin main`. `git checkout -b feature/prd-4-04-integration-tests`. Ask questions and build detailed plan first. Create NEW PersonaChatsController (NOT modifying any agent_hub code). Add routes for `/chats/[persona]` with default redirect to `financial-advisor`. Wire up Turbo Frames for conversation switching. Implement auto-title trigger (callback or controller action). Add observability logging. Write Capybara system tests incrementally (one flow at a time) using Warren Buffett persona. Polish UI (timestamps, ellipsis, highlights). Run `bullet` gem to catch N+1s. Commit only green (tests pass). Open PR for review.

**Dependencies**:
- PRD 4-01 (schema + TitleGenerationJob)
- PRD 4-02 (sidebar + model selector UI)
- PRD 4-03 (streaming + error handling)

**Related PRDs**: PRD 4-05 (mobile polish + accessibility)

**Success Metrics** (from Epic overview):
- ✅ User can create 5+ conversations with different models
- ✅ Conversation switching takes < 500ms
- ✅ Title generation completes within 3 seconds (async, non-blocking)
- ✅ Zero data loss on model switch
- ✅ All manual test scenarios pass
