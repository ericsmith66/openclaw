**Epic 6: AI Conversational Agent for Home Intelligence**

**Epic Overview**

This epic introduces an AI-powered conversational agent with a Grok-like interface that understands the entire HomeKit infrastructure and can answer questions, provide insights, execute commands, and make intelligent recommendations through natural language. The agent will have deep awareness of home topology, sensor history, automation rules, user preferences, and system state—enabling users to interact with their smart home through conversation rather than clicking through UI.

The user-facing outcome is a chat interface (web + mobile) where users can ask questions like "Why is my bedroom warmer than usual?" or give commands like "Turn off all lights except the living room" and receive intelligent, context-aware responses with actionable insights. This transforms the platform from a control interface into an intelligent assistant.

**User Capabilities**

- Natural language queries about home state: "What's the temperature in the living room?"
- Complex questions requiring analysis: "Which rooms use the most energy?"
- Natural language control commands: "Lock all doors and turn off downstairs lights"
- Troubleshooting assistance: "Why didn't my automation run last night?"
- Proactive suggestions: "It's getting cold—should I adjust the thermostat?"
- Conversational automation creation: "When I leave home, turn off all lights"
- Historical analysis: "Show me bedroom temperature trends for the past week"
- Multi-turn conversations with context: "Turn on the bedroom light" → "Make it dimmer" → "Perfect, keep it like this"
- Voice input/output (integration with Epic 9's voice features)
- Scheduled queries: "Send me a daily summary of energy usage"

**Fit into Big Picture**

Epic 6 acts as the intelligent layer on top of Epics 1-4 (infrastructure, monitoring, floorplan, interactive controls). While users can manually control devices through UI, the AI agent provides a natural language interface that's faster, more intuitive, and proactively helpful. This sets the stage for Epic 7 (Automation Rules) by enabling conversational automation creation.

The agent bridges the gap between complex data (thousands of sensor readings, hundreds of events) and actionable insights by understanding context, user intent, and home patterns. It's the "brain" that makes the smart home truly intelligent.

**Reference Documents**

- Epic 2: Web UI Dashboard (data sources for agent)
- Epic 3: Floorplan Navigation (spatial awareness)
- Epic 4: Event Deduplication (data quality)
- Epic 6: Interactive Controls (action execution)
- Claude/GPT API Documentation
- LangChain for agent orchestration
- RAG (Retrieval-Augmented Generation) patterns

---

### Key Decisions Locked In

**Architecture / Boundaries**

- **AI Model**: Use Claude 3.5 Sonnet or GPT-4o via API (no local model hosting initially)
- **Agent Framework**: LangChain for tool orchestration and prompt management
- **Context Window**: Hybrid approach (in-memory conversation + RAG for home data)
- **New Models**:
  - `Conversation` (user_id, session_id, title, created_at, last_message_at)
  - `Message` (conversation_id, role: user/assistant/system, content, metadata, timestamp)
  - `AgentAction` (message_id, action_type, parameters, result, success)
  - `ConversationContext` (conversation_id, context_type, context_data)
- **New Services**:
  - `AiAgentService` - main orchestrator (LangChain agent)
  - `ConversationManager` - manage conversation state and history
  - `HomeContextBuilder` - build RAG context from DB (homes, rooms, sensors, events)
  - `IntentClassifier` - classify user intent (query, command, analysis, troubleshoot)
  - `ActionExecutor` - execute commands (delegates to PrefabControlService)
  - `ResponseFormatter` - format responses with markdown, charts, tables
- **New Controllers**:
  - `ConversationsController` - CRUD for conversations
  - `MessagesController` - create messages, stream responses
- **Out of Scope**:
  - Voice I/O (deferred to Epic 9)
  - Image understanding (camera feeds) (deferred to Epic 10)
  - Multi-language support (English only initially)
  - Fine-tuning custom models (use prompt engineering)

**UX / UI**

- Chat interface similar to ChatGPT/Claude (left sidebar: conversations, main: messages)
- Streaming responses (word-by-word display, not batch)
- Markdown rendering with code blocks, tables, charts
- Action buttons inline (e.g., "Turn on living room lights" → [Execute] button)
- Suggested follow-up questions/actions
- Loading state with "thinking..." indicator
- Error handling with graceful fallback ("I couldn't control that device—it may be offline")
- Mobile-responsive chat UI
- Quick actions toolbar: New conversation, Clear context, Settings

**Testing**

- Minitest unit tests for services (mock LLM responses)
- Integration tests for full conversation flows
- Test conversation context building (RAG accuracy)
- Test intent classification accuracy
- Test action execution success/failure handling
- Test conversation persistence and retrieval
- Manual testing with diverse query types (edge cases)

**Observability**

- Log all agent actions: `AgentAction` model tracks every command execution
- Track conversation metrics: avg messages per conversation, resolution rate
- Log LLM API calls: latency, token usage, cost
- Track intent classification accuracy (manual labeling + feedback loop)
- Sentry for unexpected errors (tool failures, API timeouts)
- Cost tracking: monitor OpenAI/Anthropic API spend

---

### High-Level Scope & Non-Goals

**In scope**

- Conversational interface (web-based chat)
- Natural language understanding of home state queries
- Command execution via natural language
- RAG-based context retrieval (sensor data, room info, automation rules)
- Multi-turn conversations with context retention
- Proactive suggestions based on patterns
- Action confirmation for sensitive commands (unlock doors)
- Conversation history persistence
- Markdown + rich formatting in responses
- Integration with existing Epic 6 controls (delegate to PrefabControlService)

**Non-goals / deferred**

- Voice input/output (Epic 9)
- Image understanding (Epic 10)
- Custom model fine-tuning (use prompt engineering)
- Real-time interruption during responses (pause/stop button - future enhancement)
- Multi-user conversation sharing (Epic 8)
- Automation rule creation via chat (Epic 7 will integrate)
- Multi-language support (English only MVP)

---

### PRD Summary Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 5-01 | Conversation Data Model & Storage | Database schema, conversation/message CRUD | None | `epic-6/prd-01-conversation-model` | Foundation |
| 5-02 | LLM Integration & Agent Orchestration | Claude/GPT API, LangChain setup, tool definitions | PRD 5-01 | `epic-6/prd-02-llm-integration` | Core AI capability |
| 5-03 | RAG Context Builder | Build home context from DB for RAG | PRD 5-01 | `epic-6/prd-03-rag-context` | Knowledge retrieval |
| 5-04 | Intent Classification & Routing | Classify user intent, route to appropriate tools | PRD 5-02 | `epic-6/prd-04-intent-classification` | Intelligence layer |
| 5-05 | Action Execution & Commands | Execute control commands via natural language | PRD 5-02, Epic 6 | `epic-6/prd-05-action-execution` | Command handling |
| 5-06 | Chat UI & Streaming Responses | React-based chat interface, streaming SSE | PRD 5-01, 5-02 | `epic-6/prd-06-chat-ui` | User interface |
| 5-07 | Proactive Suggestions & Insights | Pattern-based suggestions, anomaly alerts | PRD 5-03, 5-04 | `epic-6/prd-07-proactive-suggestions` | Intelligence features |
| 5-08 | Conversation Analytics & Cost Tracking | Track usage, cost, performance metrics | PRD 5-01, 5-02 | `epic-6/prd-08-analytics` | Observability |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**:
  - Use LangChain for agent orchestration (tool calling, prompt management)
  - RAG approach: embed home context into prompts, don't fine-tune models
  - Streaming responses: use Server-Sent Events (SSE) for word-by-word display
  - Stateless API: conversation state stored in DB, not in-memory
- **Components**:
  - Chat UI under `app/components/ai/` namespace
  - Use Hotwire Turbo Streams for real-time message updates
  - Use Stimulus controller for chat input/output handling
- **Data Access**:
  - Eager load conversation messages to prevent N+1 (`includes(:messages)`)
  - Cache RAG context for 5 minutes (home topology doesn't change often)
  - Paginate conversation history (load last 50 messages, lazy-load older)
- **Error Handling**:
  - Graceful degradation: if LLM API fails, show "I'm having trouble right now—try again in a moment"
  - Retry LLM API calls once with exponential backoff
  - Validate user commands before execution (confirm destructive actions)
  - Log all LLM API errors to Sentry
- **Empty States**:
  - "No conversations yet. Ask me anything about your home!"
  - "I don't have any sensor data for that room yet."
  - "I couldn't find any automation rules matching that description."
- **Accessibility**:
  - WCAG AA compliance (keyboard navigation, screen reader support)
  - Keyboard shortcuts: Enter to send, Cmd+K for new conversation
  - Focus management (auto-focus input after message sent)
  - Screen reader announcements for new messages
- **Mobile**:
  - Full-screen chat on mobile (no sidebars)
  - Bottom-anchored input (like iMessage)
  - Swipe to go back to conversation list
  - Touch-friendly message bubbles
- **Security**:
  - Rate limiting: 10 messages per minute per user
  - Content filtering: prevent prompt injection attacks
  - Sanitize LLM responses (strip potentially harmful HTML)
  - Confirm destructive actions (unlock, delete automations)
  - Log all action executions with user attribution

---

### Implementation Status Tracking

- Create `0001-IMPLEMENTATION-STATUS.md` in this directory before starting PRD work.
- Update it after each PRD completion.

---

### Success Metrics

- Agent can answer 80%+ of common home state queries correctly
- Command execution success rate >90%
- Average conversation length: 3-5 messages (indicates effectiveness)
- Response latency <2 seconds (including LLM API call)
- User satisfaction: 4+ stars (feedback mechanism)
- Cost per conversation <$0.05 (token optimization)
- 30%+ of users engage with agent weekly

---

### Estimated Timeline

- PRD 5-01 (Conversation Model): 2-3 days
- PRD 5-02 (LLM Integration): 4-5 days
- PRD 5-03 (RAG Context): 3-4 days
- PRD 5-04 (Intent Classification): 3-4 days
- PRD 5-05 (Action Execution): 3-4 days
- PRD 5-06 (Chat UI): 4-5 days
- PRD 5-07 (Proactive Suggestions): 3-4 days
- PRD 5-08 (Analytics): 2-3 days
- Testing & Polish: 3-4 days

**Total: 27-40 days** (5-8 weeks)

---

### Next Steps

1. Create `0001-IMPLEMENTATION-STATUS.md` in this directory
2. Review and approve Epic 6 scope
3. Proceed with PRD 5-01 (Conversation Data Model & Storage)

---

### Detailed PRDs

Full PRD specifications live in separate files:
- `PRD-6-01-conversation-model.md`
- `PRD-6-02-llm-integration.md`
- `PRD-6-03-rag-context.md`
- `PRD-6-04-intent-classification.md`
- `PRD-6-05-action-execution.md`
- `PRD-6-06-chat-ui.md`
- `PRD-6-07-proactive-suggestions.md`
- `PRD-6-08-analytics.md`

---

### Example Conversation Flows

**Query: Home State**
```
User: What's the temperature in the living room?
Agent: The living room is currently 72°F (22°C). The thermostat target is set to 70°F. Would you like me to adjust it?
```

**Command: Device Control**
```
User: Turn off all lights except the bedroom
Agent: I'll turn off 12 lights in your home, keeping only the bedroom lights on.
[Executing actions...]
Done! All lights are off except:
- Bedroom Ceiling Light (on, 80% brightness)
- Bedroom Lamp (on, 50% brightness)
```

**Analysis: Energy Usage**
```
User: Which rooms use the most energy?
Agent: Based on the past 30 days, here are your top energy-consuming rooms:

1. Living Room: ~45 kWh/month (thermostat, TV, lights)
2. Kitchen: ~32 kWh/month (outlets, lights)
3. Office: ~28 kWh/month (outlets, lights)

The living room uses more energy primarily due to the thermostat running frequently. Would you like recommendations to reduce usage?
```

**Troubleshooting**
```
User: Why didn't my "Good Morning" automation run today?
Agent: I checked your "Good Morning" scene—it's scheduled to trigger at 7:00 AM on weekdays. This morning it didn't run because:
- Your motion sensor in the hallway didn't detect activity (trigger condition)
- You may have left home before 7:00 AM

Would you like me to adjust the trigger conditions?
```

**Multi-turn with Context**
```
User: Turn on the living room light
Agent: The living room ceiling light is now on.

User: Make it dimmer
Agent: I've set the living room ceiling light to 30% brightness.

User: Actually, set it to 50%
Agent: Done! The living room ceiling light is now at 50% brightness.
```
