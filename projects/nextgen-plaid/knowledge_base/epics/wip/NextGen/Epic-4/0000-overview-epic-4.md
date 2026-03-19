**Epic 4: AI Persona Chat Interface for User Education with Grok-Style Conversation Tracking**

**Epic Overview**
Develop a new user-facing chat interface at `/chats/[persona]` for AI persona interactions (starting with Warren Buffett as a financial advisor) that supports persistent threaded conversations, per-conversation model selection via smart_proxy, and real-time streaming responses. This creates a dedicated educational platform for users to interact with AI personas, completely separate from the admin-only Agent Hub (`/agent_hub`) which remains for SAP/CWA/Coordinator interactions. The pattern uses separate models (`PersonaConversation` / `PersonaMessage`) and a dedicated `PersonaChatChannel` to maintain clean architectural separation from admin tooling.

**User Capabilities**
Authenticated users can create unlimited threaded conversations with AI personas, switch between conversations instantly via sidebar navigation, select and persist model choice per conversation (with last-used model inheritance for continuity), receive real-time streamed responses with Grok-style visual feedback, and view auto-generated conversation titles (LLM-summarized for quality). Mobile-first responsive design with DaisyUI drawer, professional aesthetic for 22-30 audience, educational disclaimer always visible, accessible (WCAG 2.1 AA), and keyboard navigable.

**Fit into Big Picture**
Creates the foundational pattern for all future AI persona interactions in the HNW education platform—starting with Warren Buffett (financial advisor), and enabling future personas like curriculum designers and simulation guides. Establishes consistent UX for context-aware AI education while keeping architecture simple (config-based personas, lightweight DB models). Complements Epic 3 dashboard by adding conversational access to financial insights, and enables Epic 5+ curriculum integration where personas guide learning through financial scenarios. Completely separate from Agent Hub which remains admin-only tooling.

**Reference Documents**
- Primary blueprint: This epic creates a NEW user-facing chat interface separate from admin tooling
- Core services: SmartProxyClient (model routing), ModelDiscoveryService (model discovery), Ai::MarkdownRenderer (response formatting), RagProvider (persona-scoped context injection)
- New models: PersonaConversation, PersonaMessage (separate from SapRun/SapMessage which are admin-only)
- New channel: PersonaChatChannel (separate from AgentHubChannel which is admin-only)
- UI/UX style guidance: Follow Tailwind + DaisyUI conventions (chat bubbles: user right/blue, assistant left/gray; prose for markdown; drawers for mobile). Keep professional and clean for 22-30 audience—no decorative or overly playful elements.
- Testing strategy: Minitest (per `.junie/guidelines.md`), ViewComponent tests, Stimulus controller tests, integration tests, Capybara system tests for end-to-end flows.

**Key Decisions Locked In** (from review of feedback and eric-grok-comments-v1)

**Epic Numbering**
- **Resolved**: This is Epic 4. Previous `epic-4-future.md` renamed to avoid conflict (confirmed by Eric in eric-grok-comments).

**Architectural Dependencies & Separation**
- **NEW Models**: `PersonaConversation` / `PersonaMessage` (separate from admin `SapRun` / `SapMessage`)
- **NEW Channel**: `PersonaChatChannel` (separate from admin `AgentHubChannel`)
- **Shared Services** (reusable across admin and user contexts):
  - `SmartProxyClient` + `ModelDiscoveryService` (local Ollama wrapper, model routing)
  - `RagProvider` (context injection, will support persona-scoped knowledge bases)
  - `Ai::MarkdownRenderer` (response formatting)
- **Route Separation**: `/chats/[persona]` (user-facing) vs. `/agent_hub` (admin-only)

**Conversation Title Generation**
- **Decision**: Hybrid approach (Eric + Junie feedback)
  - Show truncated title immediately (first 40-50 chars of user message + "...")
  - Upgrade to LLM 3-5 word summary async via `TitleGenerationJob`
  - Fallback to "Chat [date]" or truncated on failure
  - Use lightweight model: llama3.1:8b or claude-haiku via smart_proxy
  - Async Solid Queue job; don't block message send

**Sidebar**
- Default on mobile: Collapsed (DaisyUI drawer with hamburger icon)
- Ordering: Most-recent-first (update timestamp on new message/activity)
- Pagination: Load most recent 50 conversations initially, "Load more" link for older (performance mitigation per Junie feedback)
- Max conversations: Unlimited for v1 (future epic adds archive/delete UI)
- Mobile: Hamburger opens drawer with "New Conversation" as prominent first item (Option B, Eric confirmed)

**Model Selector**
- Placement: Chat pane header (always visible/prominent during active chat), Option B confirmed by Eric
- Model switching mid-conversation: Allow switching (updates model_name on SapRun); for v1, do **not** trigger immediate context refresh or system prompt re-injection (simpler; change applies to subsequent responses only)
  - **Clarification** (Eric response to Q6): New model receives full history as-is via existing message serialization. Risk accepted for v1; v2 can add "re-generate with new prompt" button if needed.
  - **UI feedback**: Toast notification "Model changed to [name]. This will apply to your next message." (PRD 3)
- New conversation model default: Inherit last-used model from user's previous chat **per persona** (query `sap_runs.where(user_id:, persona_id:).order(updated_at: :desc).first&.model_name`, fallback to llama3.1:70b if none set; no new columns needed per Junie recommendation Option C)

**Streaming & UI**
- Streaming indicator: Grok-like cursor blink ("▊") with CSS animation
- Disclaimer: Always-visible subtle badge (DaisyUI alert-info, small font) in **chat pane header** (Option B, Eric confirmed, contextual, doesn't clutter non-chat pages)

**Persona Configuration** (Eric response to issue #12)
- **Option C**: config/personas.yml (YAML array with keys: id/slug, name, default_model, system_prompt_ref, rag_namespace)
- Load via constant or initializer (lightweight, no migration)
- First persona: `financial-advisor` (Warren Buffett)
- System prompt emphasizes: value investing principles, educational simulation, long-term thinking
- RAG context: `knowledge_base/personas/financial_advisor/` (Berkshire letters, investment principles)

**Testing** (Eric + Junie feedback #7)
- **Minitest** (not RSpec per guidelines)
- PRD 1: Model tests (Minitest)
- PRD 2: ViewComponent tests + Stimulus controller tests (Minitest)
- PRD 3: Integration test for model persistence flow (Minitest)
- PRD 4: Channel integration test for streaming (Minitest)
- PRD 5: Full system test (Capybara) for end-to-end flow

**Error Handling** (Eric response to issue #13)
- PRD 4: DaisyUI toast for streaming failures with retry button
- Fallback message if model down, allow model switch
- Warn/truncate on token overflow (use smart_proxy metadata if available)

**Analytics/Observability** (Eric response to issue #14)
- PRD 5: Rails.logger.info for key events (model switch, title gen success/fail, streaming start/end/error with duration)
- No Sentry yet—keep Rails.logger

**Stimulus Naming Conventions** (Eric + Junie feedback #9)
- Lowercase-hyphen pattern:
  - `conversation-sidebar_controller.js` (sidebar list + new button)
  - `model-selector_controller.js` (dropdown + persistence)
  - `streaming-chat_controller.js` (cursor indicator, message handling)

**High-Level Scope & Non-Goals**
- **In scope**: NEW user-facing chat interface at `/chats/[persona]`, sidebar conversation tracker, model selector + persistence, persona scoping (persona_id on conversations), new models (PersonaConversation/PersonaMessage), new channel (PersonaChatChannel), real-time streaming with context injection, educational disclaimer, config/personas.yml for persona definitions, hybrid title generation with async LLM upgrade, error handling (toasts, retry, fallbacks), pagination (50 conversations initially), Warren Buffett financial advisor persona with investment philosophy focus.
- **Non-goals / deferred**: Modifying Agent Hub UI/code (stays admin-only), file attachments, image gen, charts/widgets, multi-user collab, search/filter across chats, Rails generator for new personas, CRT theme styling, auto-archiving, conversation deletion UI (defer to future epic).

**PRD Summary Table (Epic 4 – 5 PRDs Total)**

| Priority | PRD Title                                    | Scope                                                                 | Dependencies                  | Suggested Branch                              | Notes                                      |
|----------|----------------------------------------------|-----------------------------------------------------------------------|-------------------------------|-----------------------------------------------|--------------------------------------------|
| 4-01     | PersonaConversation Schema + Persona Config  | New models (PersonaConversation/PersonaMessage), validations, scopes, hybrid title gen, TitleGenerationJob, personas.yml with financial-advisor | None                         | feature/prd-4-01-persona-conversation-schema | Data foundation + Warren Buffett persona  |
| 4-02     | Conversation Sidebar & Model Selector UI     | Sidebar component, drawer, model dropdown, Stimulus, pagination at /chats/[persona] | PRD 4-01                     | feature/prd-4-02-sidebar-model-selector      | NEW user-facing UI (not agent_hub)        |
| 4-03     | Real-Time Streaming & Context Integration    | NEW PersonaChatChannel, RagProvider persona context, cursor animation, disclaimer | PRD 4-01, PRD 4-02           | feature/prd-4-03-streaming-context           | Separate from admin AgentHubChannel       |
| 4-04     | End-to-End Integration & System Tests        | Routing /chats/financial-advisor, auto-title trigger, system tests, polish | PRD 4-01, 4-02, 4-03         | feature/prd-4-04-integration-tests           | Final integration layer                   |
| 4-05     | Mobile UX Polish & Accessibility             | Mobile drawer auto-close, touch targets, WCAG 2.1 AA, axe-core tests | PRD 4-04                     | feature/prd-4-05-mobile-accessibility        | Mobile refinement & a11y pass             |

**Key Guidance for All PRDs in Epic 4**

- **Architecture**: NEW user-facing interface at `/chats/:persona_id` with default redirect to `/chats/financial-advisor`. Completely separate from admin `/agent_hub`. Uses NEW models (PersonaConversation/PersonaMessage) and NEW channel (PersonaChatChannel). Use Turbo Frames for conversation switching, model selection, streaming updates—NOT separate pages per conversation.
- **Components**: Use ViewComponents under `app/components/persona_chats/` (NEW namespace, not related to agent_hub). Follow Tailwind + DaisyUI patterns from Epic 3. **No ActiveRecord associations in component rendering**—receive plain Ruby hashes/arrays from controller.
- **Data Access**: Controller fetches `@conversations = PersonaConversation.for_persona(persona_id).for_user(current_user).recent_first.limit(50)` and `@active_conversation = @conversations.find(params[:id])`. Pass to components as plain objects. Defensive coding: `conversation.title || "Untitled"` fallbacks.
- **Error Handling**: Every PRD includes "Error Scenarios & Fallbacks" section. Use DaisyUI toasts for failures, flash alerts for critical errors, graceful degradation (show cached data or empty state).
- **Empty States**: Use consistent pattern: "No conversations yet—start a new chat!" with prominent CTA button. Sidebar empty: large "New Conversation" button. Chat pane empty: welcome message with persona intro.
- **Turbo Frames**: Unique IDs per zone: `#conversation-sidebar-frame`, `#chat-pane-frame`, `#model-selector-frame`, `#streaming-message-frame`. Use DaisyUI `.skeleton` loaders during updates.
- **Stimulus vs Turbo**: Use Stimulus for DOM-only interactions (sidebar highlight, dropdown toggle, cursor blink animation); use Turbo for server data (load conversation history, persist model change, stream responses).
- **Style**: Follow `knowledge_base/style_guide.md` strictly. Young adult aesthetic: clean, elegant, professional. DaisyUI color tokens. Chat bubbles: user (right/blue), assistant (left/gray). Prose class for Markdown. No playful elements.
- **Accessibility**: Target WCAG 2.1 AA. Add `axe-core-capybara` tests in PRD 5. Keyboard navigation: Tab through conversations, Enter to select, Escape to close drawer. ARIA labels on buttons/dropdowns. Screen reader friendly.
- **Mobile**: Touch targets ≥44×44px. Drawer auto-closes after selecting conversation. Model selector moves to drawer header on mobile (above conversation list). Test with Capybara mobile viewport (375×667). No horizontal scroll.
- **Performance**: Paginate sidebar (limit 50 initially). Use Turbo for lazy load ("Load more" button). No N+1 queries—use includes/preload where needed. Verify with `bullet` gem in development.
- **Security**: Application-level scoping via `current_user.persona_conversations`. Verify Turbo Stream channels user-scoped: `persona_chat:#{current_user.id}:#{persona_id}`. Add channel authentication tests in PRD 3. PersonaChatChannel completely separate from AgentHubChannel (admin-only).
- **Observability**: Rails.logger for key events: `Rails.logger.info "[PersonaChat] model_switch user=#{user.id} run=#{run.id} from=#{old_model} to=#{new_model}"`. Tag errors with `epic:4, prd:"4-XX"`.
- **i18n**: US-only for Epic 4. Hard-code strings in English. Defer i18n to future epic.
- **Testing**: Minitest for all tests. ViewComponent previews at `test/components/previews/chats/`. Integration tests at `test/integration/persona_chat/`. System tests at `test/system/persona_chat_test.rb`. Capybara for end-to-end flows.

**Implementation Status Tracking**
- Per `.junie/guidelines.md` section 9, create `0001-IMPLEMENTATION-STATUS.md` before starting PRD 4-01.
- Track: PRD completion status, blockers, key decisions, branch merges.
- Update after each PRD completion.

**Success Metrics**
- User can create 5+ conversations with different models
- Conversation switching takes < 500ms
- Title generation completes within 3 seconds (async, non-blocking)
- Zero data loss on model switch
- Mobile drawer responsive on iPhone SE (smallest target)
- All manual test scenarios from task log pass

**Estimated Timeline**
- PRD 4-01: 1-2 days (migrations, model methods, job, personas.yml)
- PRD 4-02: 3-4 days (UI components, Stimulus, styling, pagination)
- PRD 4-03: 2-3 days (streaming integration, tests, error handling)
- PRD 4-04: 2-3 days (system tests, routing, auto-title, polish)
- PRD 4-05: 1-2 days (mobile tweaks, axe-core tests, final QA)
- **Total: ~9-14 days** (assuming focused implementation)

**Risk Level**: Low (leverages existing patterns, minimal new infrastructure)

**Next Steps**
1. ✅ Resolve epic numbering conflict (confirmed resolved by Eric)
2. ✅ Clarify existing pattern dependencies (addressed in eric-grok-comments)
3. ✅ Update test strategy to Minitest (confirmed)
4. ✅ Document persona configuration approach (config/personas.yml)
5. Create `0001-IMPLEMENTATION-STATUS.md` before PRD 4-01 kickoff
6. Proceed with PRD 4-01 (SapRun Schema + Persona Config)

---

### Detailed PRDs (Priorities 4-01 through 4-05)

Full PRD specifications follow in separate files:
- `PRD-4-01-persona-conversation-schema-config.md` (NEW models, financial-advisor persona)
- `PRD-4-02-sidebar-model-selector-ui.md` (NEW user-facing UI at /chats/[persona])
- `PRD-4-03-streaming-context-integration.md` (NEW PersonaChatChannel, separate from admin)
- `PRD-4-04-integration-system-tests.md` (Routes, Warren Buffett persona tests)
- `PRD-4-05-mobile-accessibility-polish.md`

See individual PRD files for detailed requirements, acceptance criteria, test cases, and workflows.

**Important**: This epic creates a NEW user-facing feature at `/chats/[persona]`. It does NOT modify `/agent_hub` which remains admin-only for SAP/CWA/Coordinator interactions.
