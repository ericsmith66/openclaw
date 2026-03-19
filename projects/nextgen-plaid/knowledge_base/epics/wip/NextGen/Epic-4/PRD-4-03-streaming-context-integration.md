#### PRD-4-03: Real-Time Streaming & Context Integration

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- In the log put detailed steps for human to manually test and what the expected results.
- If asked to review please create a separate document called <epic or prd name>-feedback.md.

**Overview**
Create NEW `PersonaChatChannel` (separate from admin `AgentHubChannel`) to handle user-facing persona chat streaming at `/chats/[persona]`. Reads per-conversation model_name from persona_conversation and passes to SmartProxyClient. Wire RagProvider to inject persona-scoped context from `knowledge_base/personas/financial_advisor/`. Implement Grok-style cursor streaming indicator with CSS animation, add educational disclaimer component to chat pane header, and implement comprehensive error handling for streaming failures, model unavailability, and token overflow. This is completely separate from admin Agent Hub functionality.

**Requirements**

**Functional**:

**NEW PersonaChatChannel** (app/channels/persona_chat_channel.rb):
- Create NEW channel, completely separate from AgentHubChannel (admin-only)
- Method: `handle_message` (or similar) to:
  1. Load `persona_conversation` from params (`conversation_id`)
  2. Verify user owns conversation (security check)
  3. Read `persona_conversation.model_name` (e.g., "llama3.1:70b")
  4. Pass model_name to `SmartProxyClient.generate(model: persona_conversation.model_name, ...)`
  5. Use `persona_conversation.persona_id` for RAG context routing
  6. Create PersonaMessage records for user input and assistant response
- Streaming: Use Turbo Stream broadcast mechanism (similar pattern to AgentHubChannel but separate channel)
- Channel name: `persona_chat:#{current_user.id}:#{persona_id}`
- Token tracking: Log token usage per message: `Rails.logger.info "[PersonaChat] tokens_used=#{response.usage} conversation_id=#{conversation.id} model=#{model}"`

**RagProvider Integration**:
- Wire `RagProvider.build_prefix(target_agent_id: persona_id)` into PersonaChatChannel
- For `financial-advisor` persona, RAG reads from `knowledge_base/personas/financial_advisor/`
- Add integration test: financial-advisor gets investment docs, not coding docs
- Create sample RAG doc: `knowledge_base/personas/financial_advisor/investment_principles.md` with Warren Buffett philosophy
- If RagProvider needs updates for persona namespacing, implement in this PRD

**Grok-Style Cursor Streaming Indicator**:
- Display blinking cursor ("▊") at end of assistant message during streaming
- CSS animation:
  ```css
  @keyframes cursor-blink {
    0%, 50% { opacity: 1; }
    51%, 100% { opacity: 0; }
  }
  .streaming-cursor {
    animation: cursor-blink 1s infinite;
  }
  ```
- Stimulus controller (`streaming-chat_controller.js`) adds/removes cursor:
  - On stream start: Append `<span class="streaming-cursor">▊</span>` to message div
  - On stream complete: Remove cursor span
  - On stream error: Remove cursor, show error message

**Disclaimer Component**:
- ViewComponent: `app/components/persona_chats/disclaimer_component.rb` (NEW namespace)
- Position: Fixed top of chat pane header (above model selector)
- DaisyUI `alert-info` badge with small font (text-xs)
- Text: "Educational simulation – AI responses for learning"
- Icon: Info icon (ⓘ) with tooltip on hover: "This is a simulated conversation with an AI persona. Responses are for educational purposes. Always verify important information."
- Always visible during active conversation

**Error Handling** (per Eric feedback #13):
- **Streaming failure** (connection drop, timeout):
  - DaisyUI toast: "Streaming interrupted—[Retry] [Cancel]"
  - Retry button: Re-enqueue message via Turbo Stream
  - Cancel button: Close toast, show partial response with "(incomplete)" marker
- **Model unavailable** (Ollama down, model not found):
  - Show error message in chat: "Model [name] is currently unavailable. [Switch Model] or try again later."
  - Switch Model button: Opens model selector dropdown
  - Log error: `Rails.logger.error "[PersonaChat] model_unavailable model=#{model} run_id=#{run.id}"`
- **Token overflow** (context too large):
  - Warn user: "Message context is too large. Older messages will be summarized."
  - Backend: Truncate oldest messages or use smart_proxy metadata to detect limit
  - Fallback: If truncation fails, show error toast "Context too large—start a new conversation"

**Non-Functional**:
- Streaming latency: First token within 500ms (depends on Ollama performance)
- Cursor animation smooth (60fps, no jank)
- Error toasts auto-dismiss after 5 seconds (unless user interacts)
- Retry mechanism: Max 3 attempts with exponential backoff (1s, 2s, 4s)

**Rails-Specific**:
- Channel: `app/channels/persona_chat_channel.rb` (NEW channel, NOT modifying AgentHubChannel)
- ViewComponent: `app/components/persona_chats/disclaimer_component.rb` + ERB (NEW namespace)
- Stimulus: `app/javascript/controllers/streaming-chat_controller.js`
- Service: `app/services/smart_proxy_client.rb` (existing, reused for persona chats)
- RagProvider: `app/services/rag_provider.rb` (existing, wire persona_id to knowledge_base/personas/[persona]/
- RAG docs: Create `knowledge_base/personas/financial_advisor/investment_principles.md`
- DaisyUI: `alert`, `toast`, `badge` components

**Error Scenarios & Fallbacks**:
- **PersonaChatChannel subscription fails**: Flash error "Chat connection failed—refresh page"
- **SmartProxyClient timeout**: Show error message "Response timed out. [Retry]"
- **Invalid model_name in persona_conversation**: Fallback to default "llama3.1:70b", log warning
- **RagProvider returns empty context**: Proceed without context (degraded but functional)
- **RAG directory missing** (`knowledge_base/personas/financial_advisor/`): Log warning, proceed without RAG
- **Turbo Stream broadcast fails**: Fallback to polling (check for new messages every 2s)
- **Cursor animation doesn't load** (CSS issue): No visual indicator but streaming still works (non-critical)

**Architectural Context**
WebSocket: NEW PersonaChatChannel (separate from admin AgentHubChannel) handles bidirectional communication between frontend and Ollama via SmartProxyClient for user-facing `/chats/[persona]` interface. Frontend sends message → PersonaChatChannel receives → SmartProxyClient streams tokens → Channel broadcasts via Turbo Stream → Frontend appends tokens to DOM. RagProvider injects persona-specific context from `knowledge_base/personas/[persona]/` before sending to Ollama. Stimulus controller manages cursor animation and error UI. Security: Channel authenticated via Devise (current_user), application-level scoping ensures user can only access own persona_conversations. Performance: Streaming reduces perceived latency vs. waiting for full response. Completely separate from Agent Hub (admin-only).

**Acceptance Criteria**
- NEW PersonaChatChannel created (separate from AgentHubChannel)
- PersonaChatChannel reads `persona_conversation.model_name` and passes to SmartProxyClient
- Different models respond correctly when selected (e.g., 70b vs 8b)
- RagProvider integration test confirms financial-advisor gets investment docs from `knowledge_base/personas/financial_advisor/`
- RAG directory exists with sample doc: `investment_principles.md`
- Cursor ("▊") blinks at end of message during streaming
- Cursor disappears when streaming completes
- Disclaimer badge always visible in chat pane header at `/chats/financial-advisor`
- Disclaimer tooltip shows on hover
- Streaming failure → toast with Retry/Cancel buttons
- Retry button re-sends message, Cancel closes toast
- Model unavailable → error message with "Switch Model" button
- Token overflow → warning message about truncation
- All integration tests pass (Minitest + Capybara)
- No console errors during streaming
- PersonaChatChannel completely separate from AgentHubChannel (no admin code modified)

**Test Cases**

**Unit (Minitest)**:
- `test/components/chats/disclaimer_component_test.rb`:
  ```ruby
  test "renders disclaimer badge with text and icon" do
    render_inline(Chats::DisclaimerComponent.new)
    assert_selector ".alert-info", text: "Educational simulation"
    assert_selector "span[data-tooltip]" # hover tooltip
  end
  ```

**Integration (Minitest)**:
- `test/channels/agent_hub_channel_test.rb`:
  ```ruby
  test "handle_chat_v2 uses sap_run model_name" do
    user = users(:alice)
    run = create(:sap_run, user: user, model_name: "llama3.1:8b")

    subscribe(user_id: user.id, sap_run_id: run.id)
    perform :handle_chat_v2, { message: "Hello", sap_run_id: run.id }

    # Mock SmartProxyClient to verify model param
    assert_requested :post, /smart_proxy/, with: { body: /llama3.1:8b/ }
  end

  test "broadcasts error on model unavailable" do
    user = users(:alice)
    run = create(:sap_run, user: user, model_name: "invalid_model")

    SmartProxyClient.stub :generate, ->(*) { raise "model not found" } do
      subscribe(user_id: user.id, sap_run_id: run.id)
      perform :handle_chat_v2, { message: "Hello", sap_run_id: run.id }

      assert_broadcast_on("persona_chat:#{user.id}", action: "error", message: /unavailable/)
    end
  end
  ```

- `test/services/rag_provider_test.rb`:
  ```ruby
  test "build_prefix uses persona_id for context routing" do
    junie_context = RagProvider.build_prefix(target_agent_id: "junie")
    finance_context = RagProvider.build_prefix(target_agent_id: "finance")

    assert_includes junie_context, "coding" # or relevant keyword
    assert_includes finance_context, "financial" # or relevant keyword
    refute_equal junie_context, finance_context
  end
  ```

**System (Capybara)**:
- `test/system/streaming_chat_test.rb`:
  ```ruby
  test "user sees streaming cursor during response" do
    user = users(:alice)
    run = create(:sap_run, user: user, persona_id: "junie", model_name: "llama3.1:70b")

    sign_in user
    visit chats_path(persona_id: "junie", id: run.id)

    fill_in "Message", with: "Hello"
    click_button "Send"

    # Cursor appears during streaming
    assert_selector ".streaming-cursor", text: "▊"

    # Wait for response to complete
    assert_no_selector ".streaming-cursor" # cursor removed
    assert_selector ".assistant-message", text: /Hello/ # response rendered
  end

  test "user sees error toast on streaming failure" do
    user = users(:alice)
    run = create(:sap_run, user: user, persona_id: "junie")

    # Simulate network failure
    AgentHubChannel.stub :broadcast, ->(*) { raise "network error" } do
      sign_in user
      visit chats_path(persona_id: "junie", id: run.id)

      fill_in "Message", with: "Hello"
      click_button "Send"

      assert_selector ".toast", text: "Streaming interrupted"
      assert_button "Retry"
      assert_button "Cancel"
    end
  end
  ```

**Manual**:
1. Basic streaming:
   - Visit `/chats/financial-advisor` with active conversation
   - Send message "What are your top 3 investment principles?"
   - Verify cursor ("▊") blinks at end of response during streaming
   - Cursor disappears when response complete
   - Response rendered with Markdown formatting
   - Response should reference Warren Buffett's value investing philosophy

2. Model switching:
   - Change model to llama3.1:8b via dropdown
   - Send message "Explain compound interest"
   - Verify response uses 8b model (check Rails logs for model param)
   - Change to llama3.1:70b
   - Send same message, verify different model used (logs show model change)

3. Disclaimer:
   - Verify badge always visible at top of chat pane: "Educational simulation – AI responses for learning"
   - Hover over info icon → tooltip appears: "This is a simulated conversation with an AI persona..."

4. Error scenarios:
   - **Streaming failure**: Stop Ollama mid-response → verify toast "Streaming interrupted—[Retry] [Cancel]"
   - Click Retry → message re-sent, response completes
   - Click Cancel → toast dismissed, partial response visible with "(incomplete)"
   - **Model unavailable**: Set invalid model_name in DB → send message → error: "Model [name] is currently unavailable. [Switch Model]"
   - Click "Switch Model" → dropdown opens
   - **Token overflow**: Send very long message (>8k tokens) → warning: "Message context too large..."

5. RAG context (verify in Rails logs):
   - Send message to financial-advisor: "What's your view on diversification?" → logs should show RAG context from `knowledge_base/personas/financial_advisor/investment_principles.md`
   - Response should include persona-specific knowledge (e.g., references to Berkshire Hathaway, value investing)
   - Verify RAG NOT loading admin/coding docs

**Workflow**
Use Claude Sonnet 4.5. `git pull origin main`. `git checkout -b feature/prd-4-03-streaming-context`. Ask questions and build detailed plan first. Create NEW PersonaChatChannel (do NOT modify AgentHubChannel which is admin-only). Wire model_name param from persona_conversation. Test with browser console to verify WebSocket connection to PersonaChatChannel. Add cursor animation (CSS + Stimulus). Add disclaimer component under `persona_chats/` namespace. Implement error handling (toasts, retry logic). Create RAG directory and sample doc: `knowledge_base/personas/financial_advisor/investment_principles.md`. Wire RagProvider to persona namespacing. Test RAG context routing. Commit only green (tests pass). Open PR for review.

**Dependencies**:
- PRD 4-01 (sap_run.model_name column must exist)
- PRD 4-02 (UI for triggering streaming, model selector)

**Related PRDs**: PRD 4-04 (end-to-end integration tests)

**Logging Format** (per Eric feedback #14):
```ruby
# Successful streaming
Rails.logger.info "[PersonaChat] streaming_start run_id=#{run.id} model=#{model} persona=#{persona_id}"
Rails.logger.info "[PersonaChat] streaming_complete run_id=#{run.id} tokens=#{tokens} duration_ms=#{duration}"

# Model switch
Rails.logger.info "[PersonaChat] model_switch user=#{user.id} run=#{run.id} from=#{old} to=#{new}"

# Errors
Rails.logger.error "[PersonaChat] streaming_error run_id=#{run.id} error=#{e.class} message=#{e.message}"
```
