# Epic 4 Review & Feedback — AI Persona Chat Interface

**Reviewer:** Junie
**Date:** 2026-01-26
**Document Reviewed:** `0000-overview-epic-4.md` + `docs/ai-persona-chat-pattern.md`
**Status:** Ready for implementation with recommendations below

---

## Overall Assessment

✅ **Epic is well-scoped and ready to proceed.** The PRD breakdown is atomic and logical, key decisions are locked in, and the reference document provides solid technical foundation. Below are detailed comments, questions, and recommended solutions.

---

## Section-by-Section Review

### 1. Epic Overview & Scope

**✅ Strengths:**
- Clear focus on lightweight, reusable pattern
- Builds on existing infrastructure (low risk)
- Explicit non-goals prevent scope creep

**💡 Suggestions:**
- Add explicit success criteria (e.g., "User can create 3+ conversations with different models and switch between them without context loss")
- Reference the task log (`knowledge_base/prds/prds-junie-log/2026-01-26__epic-4-ai-persona-chat-pattern-doc.md`) for manual testing scenarios

---

### 2. Key Decisions Locked In

**❓ Question 1: LLM Title Generation (Decision locked as "Option B")**

**Concern:**
- LLM summarization adds latency on every new conversation
- User sees "New Conversation" temporarily before async title update
- Potential failure mode if smart_proxy unavailable

**Proposed Solution:**
```ruby
# PRD 1: Implement hybrid approach
def generate_title_from_first_message
  # Strategy: Fast truncation first, async LLM upgrade
  truncated_title = sap_messages.user_role.first&.content&.truncate(40, separator: ' ', omission: '...')
  update!(title: truncated_title) if truncated_title.present?

  # Async job: Upgrade to LLM summary after initial display
  TitleGenerationJob.perform_later(id) if sap_messages.user_role.count == 1
end
```

**Benefits:**
- User sees immediate title (no "New Conversation" placeholder)
- Better UX during network/proxy issues
- LLM quality upgrade happens invisibly in background

**Action:** Revise PRD 1 to include `TitleGenerationJob` (ActiveJob) with fallback to truncation on failure.

---

**❓ Question 2: Model Switching Mid-Conversation**

**Decision states:** "Change applies to subsequent responses only (no context refresh)"

**Concern:**
- User might expect model change to affect current conversation context
- Could be confusing if switching from small model (8b) to large (70b) but quality doesn't immediately improve

**Proposed Solution:**
- **Accept current decision for v1** (simpler, less risk)
- **Add UI hint** when user switches model: Toast notification "Model changed to [name]. This will apply to your next message."
- **Log for future enhancement:** Consider PRD 6 for "reload context with new model" button

**Action:** Add toast notification to PRD 3 (Model Selector). Document limitation in user-facing help text.

---

**❓ Question 3: New Conversation Model Default**

**Decision:** "Inherit last-used model from user's previous chat"

**Question:** How to track "last-used model" across personas?
- Option A: Store `users.last_used_model` (global across all personas)
- Option B: Store `users.last_used_model_per_persona` (JSONB: `{junie: "llama3.1:8b", finance: "llama3.1:70b"}`)
- Option C: Query `sap_runs.where(user_id:, persona_id:).order(updated_at: :desc).first&.model_name`

**Recommended Solution:** **Option C** (no schema changes needed)
```ruby
# SapRun.create_conversation
def self.create_conversation(user_id:, persona_id:)
  last_model = where(user_id: user_id, persona_id: persona_id)
                 .order(updated_at: :desc)
                 .limit(1)
                 .pluck(:model_name)
                 .first || "llama3.1:70b"

  create!(
    user_id: user_id,
    persona_id: persona_id,
    model_name: last_model,
    title: "New Conversation"
  )
end
```

**Benefits:**
- Persona-specific memory (better UX)
- No new columns/cache invalidation
- Query is fast (indexed on user_id, persona_id)

**Action:** Include in PRD 1 (SapRun model methods).

---

### 3. Proposed Atomic PRD Breakdown

**✅ Overall: PRD split is excellent.** Atomic, testable, and sequential.

**🔄 Recommended Adjustments:**

#### **PRD 1: Add Missing Details**

**Current scope:**
- Add columns (persona_id, model_name, title)
- Add methods (generate_title_from_first_message, last_message_preview)
- Index on [user_id, persona_id]

**Missing:**
- Migration for default values on existing SapRuns (backfill script?)
- Validation rules (e.g., persona_id presence, model_name format)
- Scopes for querying (`scope :for_persona, ->(pid) { where(persona_id: pid) }`)
- TitleGenerationJob (ActiveJob) for async LLM title upgrade

**Recommended Addition to PRD 1:**
```markdown
### Additional Requirements
- **Backfill Migration**: Update existing sap_runs with persona_id="junie" (default), model_name from ENV or "llama3.1:70b"
- **Validations**:
  - `validates :persona_id, presence: true, inclusion: { in: %w[junie finance] }` (or dynamic from config)
  - `validates :model_name, presence: true`
- **Scopes**:
  - `scope :for_persona, ->(persona_id) { where(persona_id: persona_id) }`
  - `scope :recent_first, -> { order(updated_at: :desc) }`
- **TitleGenerationJob**: Background job to call smart_proxy for 3-5 word summary
  - Prompt: "Summarize this message in 3-5 words for a chat title: [user_message]"
  - Fallback: Keep truncated title on failure
  - Timeout: 5 seconds
```

---

#### **PRD 2 & 3: Consider Merging for Faster Iteration**

**Rationale:**
- Sidebar without model selector feels incomplete
- Both are frontend-focused (ViewComponents + Stimulus)
- Testing is easier when both features available

**Recommended Merge:** **PRD 2+3 → "Sidebar & Model Selector UI"**

**New PRD 2 Scope:**
- ConversationSidebarComponent (list, new button, switch)
- Model selector dropdown (fetch from ModelDiscoveryService)
- Stimulus controllers: conversation_controller.js, model_selector_controller.js
- Layout: DaisyUI drawer (mobile), fixed sidebar (desktop)
- Persist model selection to sap_run

**Benefit:** Ship visible UX faster, easier to test interaction between sidebar and model selector

**Alternative (if keeping separate):**
- PRD 2: Mock model selector as static "llama3.1:70b" badge
- PRD 3: Replace badge with functional dropdown

**Action:** Ask user preference: Merge PRD 2+3 or keep atomic?

---

#### **PRD 4: Clarify "Context Integration Updates"**

**Current scope vague on:**
- "Ensure RagProvider injects persona-specific context" — What changes exactly?
- Does RagProvider already support target_agent_id = persona_id? (Answer: YES, per reference doc)

**Recommended Clarification:**
```markdown
### PRD 4 Scope (Refined)
- **AgentHubChannel Updates**:
  - Modify `handle_chat_v2` to read `sap_run.model_name` and pass to SmartProxyClient
  - Verify `target_agent_id` parameter maps to `persona_id` correctly
- **RagProvider Verification** (no changes expected):
  - Confirm existing `build_prefix` method already uses persona_id for context
  - Add test: Different personas get different RAG context
- **Streaming Indicator UI**:
  - Grok-like cursor blink animation ("▊") during token streaming
  - CSS: `@keyframes blink { 0%, 50% { opacity: 1; } 51%, 100% { opacity: 0; } }`
- **Disclaimer Component**:
  - DaisyUI alert-info badge: "Educational simulation – Local Ollama"
  - Position: Fixed top of chat pane, above model selector
```

**Action:** Update PRD 4 with explicit file changes and test cases.

---

#### **PRD 5: Add Acceptance Criteria**

**Current scope:** "Integration & Polish" (too vague)

**Recommended Additions:**
```markdown
### PRD 5: End-to-End Integration (Refined Scope)

**Backend:**
- [ ] Routing: `GET /chats/:persona_id` → loads ConversationSidebarComponent + ChatPaneComponent
- [ ] Default persona: Redirect `/chats` → `/chats/junie`
- [ ] Auto-title trigger: After first user message + assistant response, call TitleGenerationJob

**Frontend:**
- [ ] New conversation flow: Click button → Create run → Load empty chat
- [ ] Switch conversation flow: Click sidebar item → Load history via Turbo Frame
- [ ] Model change flow: Select dropdown → Update run.model_name → Toast notification

**System Tests (manual scenarios from task log):**
- [ ] Test 1: New Conversation Creation
- [ ] Test 2: Model Selection and Persistence
- [ ] Test 3: Conversation Switching
- [ ] Test 4: Streaming Response with Markdown
- [ ] Test 9: Conversation Title Auto-Generation

**Polish:**
- [ ] Timestamps: Relative display (2m ago, 1h ago) with `time_ago_in_words` helper
- [ ] Long titles: CSS `text-overflow: ellipsis` on sidebar items
- [ ] Active conversation: DaisyUI `bg-base-300` highlight
```

**Action:** Replace vague "polish" language with concrete checklist.

---

### 4. Questions for Junie (Original Document)

**Answering the questions posed in Epic overview:**

#### Q1: "Does this PRD split feel atomic enough, or should we merge 2+3?"

**Answer:** **Recommend merging PRD 2+3** for reasons stated above (faster visible progress, easier integration testing). If you prefer strict atomicity, keep separate but add explicit handoff points.

---

#### Q2: "Any concern with LLM title gen in v1 (latency/cost)?"

**Answer:** **Concerns mitigated by hybrid approach:**
- Show truncated title immediately (no perceived latency)
- LLM upgrade happens async (user doesn't wait)
- Fallback to truncation on failure (resilient)
- Cost: Minimal (one summarization call per new chat, ~10 tokens)

**Recommendation:** Proceed with hybrid approach (see Question 1 solution above).

---

#### Q3: "Preferred Stimulus naming conventions?"

**Answer:** Follow existing codebase conventions:
- `conversation_controller.js` (matches `chat_pane_controller.js` style)
- Use kebab-case for HTML attributes: `data-controller="conversation"`
- Use camelCase for actions: `data-action="click->conversation#switchTo"`

**Example:**
```html
<!-- ConversationSidebarComponent -->
<div data-controller="conversation">
  <div data-conversation-id-value="<%= run.id %>"
       data-action="click->conversation#switchTo"
       class="cursor-pointer">
    <%= run.title %>
  </div>
</div>
```

**Action:** Document in PRD 2 (or merged PRD 2+3).

---

## Additional Concerns & Recommendations

### 🔴 Concern 1: Missing Error Handling Specs

**Issue:** None of the PRDs explicitly mention error scenarios:
- What if ModelDiscoveryService returns empty array?
- What if conversation load fails (deleted run)?
- What if TitleGenerationJob times out?

**Solution:** Add "Error Handling" section to each PRD:

**Example for PRD 3 (Model Selector):**
```markdown
### Error Handling
- **No models available**: Show fallback message "Models unavailable. Using default: llama3.1:70b"
- **Model change fails**: Revert dropdown to current model, show error toast
- **Smart proxy unreachable**: Use cached models (ModelDiscoveryService 1hr cache)
```

**Action:** Template all PRDs with "Error Handling" section.

---

### 🟡 Concern 2: Performance (Sidebar with 100+ Conversations)

**Issue:** No mention of pagination or virtualization for long conversation lists

**Current Risk:** If user creates 100+ conversations, sidebar could be slow/unwieldy

**Recommended Solutions:**

**Option A: Pagination (Simple)**
```ruby
# ConversationSidebarComponent
@conversations = SapRun.for_persona(persona_id)
                       .for_user(current_user)
                       .recent_first
                       .limit(20) # Show most recent 20
```
- Add "Load More" button at bottom of sidebar
- Infinite scroll alternative (Stimulus + Turbo Frames)

**Option B: Virtual Scrolling (Complex)**
- Use library like `stimulus-use` for virtual scrolling
- Defer to post-v1 unless performance becomes issue

**Recommendation:** Start with **Option A (limit 20)** in PRD 2. Add TODO for pagination if needed.

**Action:** Add to PRD 2 scope: "Display 20 most recent conversations, defer pagination to future story."

---

### 🟡 Concern 3: Mobile UX Not Fully Specified

**Issue:** "DaisyUI drawer with hamburger" mentioned but behavior unclear:
- Does drawer auto-close after selecting conversation?
- How does user access model selector on mobile (small header space)?
- What about send button vs. soft keyboard on mobile?

**Recommended Additions to PRD 2:**

```markdown
### Mobile Behavior (< 768px)
- Sidebar: Collapsed by default (drawer overlay)
- Hamburger icon: Fixed top-left (☰) opens drawer
- Select conversation: Auto-close drawer, load chat in main pane
- Model selector: Move to drawer header (above conversation list) on mobile
- Send button: Use Enter key on desktop, button + Enter on mobile (Stimulus detect)
```

**Action:** Add "Mobile Specifications" subsection to PRD 2.

---

### 🟢 Strength: Excellent Use of Existing Infrastructure

**No objections here.** The plan correctly leverages:
- AgentHubChannel (no rewrite needed)
- SapRun/SapMessage (minimal extensions)
- ModelDiscoveryService (already fetches models)
- Turbo Streams (real-time streaming)

This de-risks the epic significantly. ✅

---

## Recommended PRD Breakdown (Revised)

Based on feedback above, here's the revised atomic breakdown:

### **PRD 1: SapRun & SapMessage Schema + Methods**
**Scope:**
- Migrations: Add persona_id, model_name, title columns + index
- Backfill existing runs with defaults
- Model validations & scopes
- Methods: `generate_title_from_first_message` (hybrid), `last_message_preview`
- TitleGenerationJob (ActiveJob with fallback)
- RSpec: Model tests + job tests

**Dependencies:** None
**Estimated Complexity:** Low
**Can ship independently:** Yes (backend-only)

---

### **PRD 2: Sidebar & Model Selector UI** (Merged from original PRD 2+3)
**Scope:**
- ConversationSidebarComponent (ViewComponent)
- Model selector dropdown (fetch from ModelDiscoveryService)
- DaisyUI drawer (mobile) + fixed sidebar (desktop)
- Stimulus controllers: conversation_controller.js, model_selector_controller.js
- Limit 20 conversations, most recent first
- Mobile specifications (drawer auto-close, selector placement)
- Error handling (empty models, load failures)

**Dependencies:** PRD 1 (schema must exist)
**Estimated Complexity:** Medium
**Can ship independently:** Yes (with mocked backend if PRD 1 not done)

---

### **PRD 3: Real-Time Streaming & Context Integration** (Renamed from PRD 4)
**Scope:**
- AgentHubChannel: Read sap_run.model_name, pass to SmartProxyClient
- Verify RagProvider persona_id context injection (test only, no code changes expected)
- Grok cursor streaming indicator (CSS animation)
- Disclaimer component (DaisyUI alert badge)
- Error handling: Streaming failures, model unavailable

**Dependencies:** PRD 1 (model_name column), PRD 2 (UI to test streaming)
**Estimated Complexity:** Low-Medium
**Can ship independently:** No (needs PRD 1+2 for visible effect)

---

### **PRD 4: End-to-End Integration & System Tests** (Renamed from PRD 5)
**Scope:**
- Routing: `/chats/:persona_id` with default redirect
- Auto-title trigger after first exchange
- System tests for all 10 manual scenarios (from task log)
- Final polish: timestamps, ellipsis, highlights
- Acceptance criteria checklist

**Dependencies:** PRD 1+2+3 (all features must exist)
**Estimated Complexity:** Medium
**Can ship independently:** No (integration layer)

---

### **Summary: 4 PRDs Instead of 5**
- Original PRD 2+3 merged (Sidebar + Model Selector are tightly coupled UX)
- Original PRD 4 renamed to PRD 3 (clearer focus on streaming)
- Original PRD 5 renamed to PRD 4 (integration/testing layer)

**Benefit:** Faster time-to-visible-feature, clearer dependencies, less coordination overhead.

---

## Open Questions Requiring Decisions

### Q1: Merge PRD 2+3 or keep atomic?
**Junie Recommendation:** Merge (see rationale above)
**Decision needed from:** You/Eric

---

### Q2: Conversation deletion UI in v1?
**Current:** Not in scope (unlimited conversations)
**Question:** Should we add basic delete button in v1 for UX safety valve?
**Recommendation:** Add simple delete to PRD 2 (trash icon → confirm modal → soft delete with deleted_at)
**Effort:** Low (one migration column, one Stimulus action)

---

### Q3: Title generation: Sync or async?
**Current Decision:** Async (TitleGenerationJob)
**Alternative:** Sync call with timeout (simpler, but blocks response)
**Recommendation:** Stick with async (better UX, no blocking)

---

### Q4: Persona config storage?
**Current:** Hardcoded persona_id strings ("junie", "finance")
**Future:** Need config/personas.yml or Persona model?
**Recommendation for v1:** Hardcode with validation (`inclusion: { in: %w[junie finance] }`)
**Follow-up Epic:** PRD for Persona generator + config management

---

## Summary & Next Steps

### ✅ Ready to Proceed
- Epic is well-defined and atomic
- Reference document provides solid technical foundation
- Risk is low (builds on existing infrastructure)

### 🔄 Recommended Changes Before Starting
1. **Update PRD breakdown**: Merge PRD 2+3, renumber subsequent PRDs
2. **Add to PRD 1**: TitleGenerationJob, hybrid title approach, backfill migration
3. **Add to PRD 2**: Mobile specs, pagination limit, error handling
4. **Add to PRD 3**: Explicit file changes, RagProvider verification tests
5. **Add to PRD 4**: Concrete acceptance criteria checklist

### 📋 Immediate Action Items
1. Create PRD 1 first (data foundation)
2. Implement & test PRD 1 independently
3. Create PRD 2 (merged Sidebar + Model Selector)
4. Ship PRD 2 for user feedback on UX
5. Complete PRD 3 + 4 for full integration

### 🎯 Success Metrics (Add to Epic Overview)
- User can create 5+ conversations with different models
- Conversation switching takes < 500ms
- Title generation completes within 3 seconds (async)
- Zero data loss on model switch
- Mobile drawer responsive on iPhone SE (smallest target)

---

## Final Recommendation

**🚀 Proceed with Epic 4 implementation using revised 4-PRD structure.** The plan is sound, dependencies are clear, and scope is appropriate for v1. Address the concerns/questions above before finalizing individual PRDs.

**Estimated Timeline:**
- PRD 1: 1-2 days (migrations, model methods, job)
- PRD 2: 3-4 days (UI components, Stimulus, styling)
- PRD 3: 2-3 days (streaming integration, tests)
- PRD 4: 2-3 days (system tests, polish)
- **Total: ~8-12 days** (assuming full-time Junie + CWA)

**Risk Level:** Low (leverages existing patterns, minimal new infrastructure)

**Go/No-Go:** ✅ **GO** with recommended adjustments above.

---

**End of Feedback Document**

*Prepared by: Junie*
*Ready for: PRD 1 creation upon approval*
