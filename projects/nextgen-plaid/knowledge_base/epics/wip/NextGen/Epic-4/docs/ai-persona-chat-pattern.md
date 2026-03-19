# AI Persona Chat Pattern — Reference Document

**Version:** 1.0
**Date:** 2026-01-26
**Purpose:** Blueprint for reusable AI persona chat UI (Grok-style conversation tracking)
**Status:** Draft for review

---

## Overview

This document describes the target pattern for a simple, reusable AI Persona Chat interface. The pattern builds on existing Rails patterns (AgentHubChannel, SapRun/SapMessage persistence, ModelDiscoveryService) and adds Grok-style conversation tracking with a sidebar for managing multiple threaded conversations per persona.

**Key Principles:**
- **Lightweight**: Focus on core chat experience; defer file uploads and complex widgets
- **Reusable**: Easy to extend for new personas (JunieDev, FinanceAdvisor, etc.)
- **Local-first**: All processing via Ollama/smart_proxy, no cloud services
- **Real-time**: Turbo Streams for progressive token streaming

---

## 1. Baseline from Existing Patterns

### 1.1 SAP Collaboration Style (Simplicity)

The current `AgentHubChannel` (`app/channels/agent_hub_channel.rb`) demonstrates a clean, bare-bones chat pattern:

- **Single chat pane**: Message list + input form
- **Turbo Streams broadcasting**: Real-time updates to target (e.g., `agent_hub_channel_#{agent_id}`)
- **Role-based messages**: User, assistant, system
- **Progressive streaming**: Token-by-token updates via `type: "token"` messages
- **After-commit hooks**: Automatic broadcasts when messages saved
- **Persistence**: SapRun (conversation container) + SapMessage (individual messages)

**Key Files:**
- `app/channels/agent_hub_channel.rb` — WebSocket channel handling
- `app/models/sap_run.rb` — Conversation model
- `app/models/sap_message.rb` — Message model
- `app/services/agent_hub/smart_proxy_client.rb` — LLM communication

### 1.2 Agent Hub Elements (Real-time Streaming)

Current Agent Hub implementation provides:

- **ChatPaneComponent** (ViewComponent): Renders message list with Tailwind Typography (`prose` class) for markdown
- **AgentHubChannel**: Handles `speak`, `confirm_action`, `interrogate` methods
- **Ai::MarkdownRenderer**: Clean markdown-to-HTML conversion with syntax highlighting
- **Message streaming**: Progressive token accumulation with `message_finished` event for final render
- **RAG integration**: `SapAgent::RagProvider.build_prefix` injects context (FinancialSnapshot + static docs)

**Streaming Flow:**
1. User sends message → `AgentHubChannel#speak`
2. Channel creates SapMessage records (user + assistant placeholder)
3. SmartProxyClient streams response to channel
4. Channel broadcasts `type: "token"` messages progressively
5. Final `type: "message_finished"` with rendered HTML

---

## 2. Target AI Persona Chat Pattern

### 2.1 Core Enhancements

**Add to existing baseline:**

1. **Grok-style conversation tracker**:
   - Persistent conversations (already supported via SapRun)
   - Sidebar menu listing chats (new UI component needed)
   - Click to load/switch conversations
   - "New Conversation" button
   - Auto-generated titles from first message content

2. **Model selection UI**:
   - Dropdown or tabs at top of chat pane (or sidebar header)
   - Pulls available models from `ModelDiscoveryService.call` (queries smart_proxy `/v1/models`)
   - Selection persists per conversation (store in `sap_runs.model_name` or `output_json`)
   - Default: `llama3.1:70b`

3. **Persona scoping**:
   - Conversations tied to specific persona (e.g., `persona_id: "junie"`)
   - Different personas maintain separate conversation histories
   - Persona context injected via system message in RAG prefix

4. **Educational disclaimer header**:
   - Fixed header or banner: *"Educational simulation only – local processing via Ollama/smart_proxy"*
   - Non-intrusive (collapsed after first view or subtle badge)

### 2.2 Keep Lightweight

**Defer for future iterations:**
- File uploads (attachments)
- Image generation
- Complex widgets (charts, interactive elements)
- Multi-user collaboration in same conversation

**Focus on:**
- Text-based Q&A
- Markdown rendering (code blocks, lists, formatting)
- Fast, reliable streaming
- Simple, intuitive UX

---

## 3. Key UI Elements

| Element                  | Description                                                                 | Styling/Behavior Notes                                      |
|--------------------------|-----------------------------------------------------------------------------|-------------------------------------------------------------|
| **Chat Pane**            | Scrolling message list (auto-scroll to bottom), input form (textarea + send button) | DaisyUI chat bubbles: user (right/blue), assistant (left/gray); prose class for markdown |
| **Conversation Sidebar** | List of chats (title, last message snippet, timestamp), "New Chat" button  | Collapsible drawer (mobile), fixed sidebar (desktop); highlight active chat |
| **Model Selector**       | Dropdown or tabs showing available models from smart_proxy                 | Top-right of chat pane or sidebar header; persist per conversation |
| **Message Rendering**    | Role-based display (user/assistant/system), markdown support               | Use `Ai::MarkdownRenderer`; streamed token updates          |
| **Streaming Indicator**  | Typing animation or progress during response                                | Subtle, Grok-like token-by-token reveal with cursor effect |
| **Educational Header**   | Banner or badge with disclaimer text                                        | Fixed at top or collapsible; DaisyUI alert styling          |

### 3.1 Conversation Sidebar (Detailed)

```
┌─────────────────────────┐
│ [+ New Conversation]    │
├─────────────────────────┤
│ ● Estate Planning Help  │ ← Active conversation (highlighted)
│   "Can you explain..."  │
│   2 hours ago           │
├─────────────────────────┤
│   Tax Strategy Q&A      │
│   "What are the best..." │
│   Yesterday             │
├─────────────────────────┤
│   Investment Advice     │
│   "Should I diversify..."|
│   Jan 24, 2026          │
└─────────────────────────┘
```

**Behavior:**
- Click conversation → Load chat history in main pane
- Active conversation: Bold title or colored border
- New conversation: Auto-title after first exchange
- Long titles: Truncate with ellipsis
- Timestamps: Relative (e.g., "5m ago") with tooltip for absolute time

### 3.2 Model Selector (Detailed)

**Option A: Dropdown (Simple)**
```
┌────────────────────────────────────┐
│ Model: [llama3.1:70b ▼]            │
└────────────────────────────────────┘
```

**Option B: Tabs (Visual)**
```
┌──────────────┬──────────────┬──────┐
│ llama3.1:70b │ llama3.1:8b  │ grok │
└──────────────┴──────────────┴──────┘
```

**Implementation:**
- Fetch models on page load: `AgentHub::ModelDiscoveryService.call`
- Store selection: `sap_run.update(model_name: selected_model)`
- Default to first model (prioritized as `llama3.1:70b`)

### 3.3 Chat Pane Layout

```
┌────────────────────────────────────────────┐
│ ⚠️ Educational simulation – Local Ollama   │ ← Disclaimer header
├────────────────────────────────────────────┤
│                              [Model: ▼]    │ ← Model selector
├────────────────────────────────────────────┤
│                                            │
│  [User bubble right-aligned, blue]         │
│    "What's my net worth?"                  │
│                                            │
│  [Assistant bubble left-aligned, gray]     │
│    "Based on your data..."                 │
│    [Markdown rendered with syntax highlight]│
│                                            │
│  [Streaming indicator: typing dots]        │ ← During response
│                                            │
├────────────────────────────────────────────┤
│ [Textarea: "Type your message..."]  [Send] │ ← Input form
└────────────────────────────────────────────┘
```

---

## 4. Integration Notes

### 4.1 Leverage Existing Infrastructure

**Reuse without modification:**
- **Turbo Streams**: Already configured for real-time updates
- **AgentHubChannel**: Extend `handle_chat_v2` method for conversation_id handling (already supports this)
- **smart_proxy integration**: Via `AgentHub::SmartProxyClient` for LLM calls
- **ModelDiscoveryService**: Fetch available models from smart_proxy `/v1/models` endpoint
- **Ai::MarkdownRenderer**: Clean markdown-to-HTML for messages
- **SapRun / SapMessage**: Persistence layer for conversations and messages

**Extend minimally:**
- **SapRun model**: Add `persona_id` column (if not exists) and `model_name` column for per-conversation model selection
- **Conversation title generation**: Method on SapRun to auto-generate title from first user message (consider summarization via LLM)
- **Sidebar component**: New ViewComponent (`ConversationSidebarComponent`) to render conversation list

### 4.2 Data Model Adjustments

**SapRun additions:**
```ruby
# Migration needed:
add_column :sap_runs, :persona_id, :string, default: "junie"
add_column :sap_runs, :model_name, :string, default: "llama3.1:70b"
add_column :sap_runs, :title, :string, default: "New Conversation"
add_index :sap_runs, [:user_id, :persona_id]
```

**SapRun methods:**
```ruby
def generate_title_from_first_message
  # Summarize first user message into 3-5 word title
  # Use LLM call or simple truncation
end

def last_message_preview
  sap_messages.last&.content&.truncate(50)
end
```

### 4.3 Smart Proxy Model Discovery

**Current implementation** (`app/services/agent_hub/model_discovery_service.rb`):
- Queries `#{OPENAI_API_BASE}/v1/models` (smart_proxy endpoint)
- Caches results for 1 hour
- Prioritizes `llama3.1:70b` to front of list
- Falls back to env vars (`AI_DEFAULT_MODEL`, `AI_DEV_MODEL`) if unreachable

**Usage in UI:**
```ruby
# Controller or component
@available_models = AgentHub::ModelDiscoveryService.call
```

**Expected response format** (smart_proxy `/v1/models`):
```json
{
  "data": [
    {"id": "llama3.1:70b"},
    {"id": "llama3.1:8b"},
    {"id": "grok-beta"}
  ]
}
```

### 4.4 Persona Context Injection

**Current RAG pattern** (`SapAgent::RagProvider.build_prefix`):
```ruby
rag_context = SapAgent::RagProvider.build_prefix(
  "default",           # RAG tier
  current_user.id,     # User ID for personalized data
  target_agent_id,     # Persona ID (e.g., "junie")
  sap_run.id           # Conversation ID
)

messages << {
  role: "system",
  content: "You are #{target_agent_id.upcase}. #{rag_context}"
}
```

**Persona-specific prompts** (future enhancement):
- Store persona definitions in `config/personas.yml` or database
- Include persona-specific instructions in system message (e.g., "You are JunieDev, a helpful coding assistant for Ruby on Rails")

### 4.5 Privacy & Local Processing

**Hard requirements:**
- **No cloud APIs**: All LLM calls via smart_proxy → Ollama (local inference)
- **No external data sharing**: FinancialSnapshot, user data stays on-premises
- **Educational disclaimer**: Visible in UI to set expectations

**Smart proxy configuration** (already configured):
- Base URL: `http://localhost:11434/v1` (Ollama-compatible endpoint)
- Authentication: Local only (no API keys required for Ollama)

---

## 5. Future Extension Points

**When ready to scale beyond lightweight chat:**

1. **File attachments**:
   - Add ActiveStorage integration
   - Display uploaded files as message attachments
   - Support image/PDF preview

2. **Advanced widgets**:
   - Inline charts (e.g., net worth trend)
   - Interactive calculators (GRAT, estate tax)
   - Embedded forms (e.g., goal setting)

3. **Multi-persona generators**:
   - Rails generator: `rails g persona finance_advisor`
   - Auto-scaffold controller, channel methods, UI components

4. **Collaboration features**:
   - Share conversation read-only link
   - Export conversation as PDF/Markdown

5. **Search and filters**:
   - Full-text search across all conversations
   - Filter by date, persona, model

---

## 6. Implementation Checklist (High-Level)

**Backend:**
- [ ] Migrate SapRun: Add `persona_id`, `model_name`, `title` columns
- [ ] Implement `SapRun#generate_title_from_first_message`
- [ ] Extend `AgentHubChannel#handle_chat_v2` to use conversation-specific model
- [ ] Ensure `ModelDiscoveryService` caching works reliably

**Frontend:**
- [ ] Create `ConversationSidebarComponent` (ViewComponent)
- [ ] Add model selector UI (dropdown or tabs)
- [ ] Update chat pane layout with disclaimer header
- [ ] Implement sidebar toggle for mobile (DaisyUI drawer)
- [ ] Add "New Conversation" button and handler

**Stimulus Controllers:**
- [ ] `conversation_controller.js` — Handle sidebar interactions (switch, create new)
- [ ] `model_selector_controller.js` — Handle model dropdown/tabs
- [ ] `chat_pane_controller.js` — Already exists; verify streaming token handling

**Styling:**
- [ ] DaisyUI chat bubbles (user/assistant)
- [ ] Sidebar highlight for active conversation
- [ ] Responsive layout (mobile drawer, desktop fixed sidebar)
- [ ] Typography prose class for markdown rendering

**Testing:**
- [ ] System test: Create conversation, send message, switch conversations
- [ ] System test: Model selection persists across conversations
- [ ] Integration test: ModelDiscoveryService fallback behavior
- [ ] Unit test: SapRun#generate_title_from_first_message

---

## 7. Open Questions

1. **Conversation title generation strategy**:
   - Option A: Simple truncation of first message (fast, no LLM call)
   - Option B: Summarization via LLM (better quality, slower)
   - **Recommendation**: Start with Option A, upgrade to B if needed

2. **Sidebar default state on mobile**:
   - Collapsed by default (more space for chat)?
   - Expanded by default (better discoverability)?
   - **Recommendation**: Collapsed, with visible hamburger icon

3. **Max conversations per persona**:
   - Unlimited (until user manually deletes)?
   - Auto-archive after N days or M conversations?
   - **Recommendation**: Start unlimited, add archive later

4. **Model selector placement**:
   - Chat pane header (always visible)?
   - Sidebar header (contextual to conversation)?
   - **Recommendation**: Chat pane header for prominence

5. **Typing indicator style**:
   - Ellipsis animation ("...")?
   - Cursor blink ("▊")?
   - **Recommendation**: Cursor blink (more Grok-like)

---

## 8. ASCII UI Mockup (Desktop)

```
┌──────────────────┬────────────────────────────────────────────────────┐
│                  │ ⚠️ Educational Simulation – Local Ollama           │
│  Conversations   ├────────────────────────────────────────────────────┤
│                  │ Model: [llama3.1:70b ▼]                   [≡ Menu] │
│ [+ New Chat]     ├────────────────────────────────────────────────────┤
├──────────────────┤                                                    │
│ ● Estate Plan... │                              [User message right]  │
│   "Can you..."   │   "What's my net worth?"                           │
│   2h ago         │                                                    │
├──────────────────┤  [Assistant message left]                         │
│   Tax Strategy   │  "Based on your data, your current net worth..."   │
│   "What are..."  │  • Liquid assets: $2.5M                            │
│   Yesterday      │  • Real estate: $1.8M                              │
├──────────────────┤  • Total: $4.3M                                    │
│   Investment...  │                                                    │
│   "Should I..."  │  [Streaming: "Let me explain the breakdown▊"]     │
│   Jan 24         │                                                    │
│                  │                                                    │
│                  │                                                    │
└──────────────────┴────────────────────────────────────────────────────┤
                   │ [Type your message here...]            [Send]      │
                   └────────────────────────────────────────────────────┘
```

---

## 9. Next Steps

1. **Review this document**: Share with team for feedback on approach
2. **Refine based on input**: Adjust UI mockups, data model, implementation strategy
3. **Break into PRDs**: Create specific PRDs for:
   - PRD 1: Data model migrations and SapRun enhancements
   - PRD 2: ConversationSidebarComponent and UI layout
   - PRD 3: Model selector and persistence
   - PRD 4: Persona routing and context injection
4. **Implement incrementally**: Ship each PRD as standalone feature
5. **Manual testing**: Use test plan from task log to verify each PRD

---

## 10. References

**Codebase:**
- `app/channels/agent_hub_channel.rb:173-210` — `handle_chat_v2` method (conversation handling)
- `app/services/agent_hub/model_discovery_service.rb` — Model discovery from smart_proxy
- `app/models/sap_run.rb` — Conversation persistence model
- `app/services/agent_hub/smart_proxy_client.rb` — LLM communication
- `app/services/sap_agent/rag_provider.rb` — Context injection

**Documentation:**
- `knowledge_base/prds/prds-junie-log/junie-log-requirement.md` — Logging standards
- `knowledge_base/epics/wip/NextGen/Epic-4/0000-overview-epic-4.md` — Epic 4 overview

**External:**
- DaisyUI drawer component: https://daisyui.com/components/drawer/
- Turbo Streams reference: https://turbo.hotwired.dev/handbook/streams

---

**End of Document**
