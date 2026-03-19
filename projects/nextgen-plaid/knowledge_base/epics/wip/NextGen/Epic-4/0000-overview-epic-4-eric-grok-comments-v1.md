# Epic 4 Overview Feedback V1
**Reviewer**: Junie (Claude Sonnet 4.5)  
**Date**: 2026-01-29  
**Source**: `0000-overview-epic-4.md`

---  

## Summary Assessment
Strong foundation with clear scope and well-considered design decisions. The atomic PRD breakdown is logical and dependency-aware. Primary concerns: (1) Epic numbering conflict with existing Epic-4-future.md, (2) missing implementation status tracking, (3) some technical clarifications needed for existing patterns.

**Eric's response**: Agreed on all points—solid assessment. Numbering resolved (see below), status tracking will be added immediately, and clarifications provided inline where possible based on current repo state.

---  

## Critical Issues

### 1. Epic Numbering Conflict ⚠️
**Observation**: This document is labeled "Epic 4" but there's already an `epic-4-future.md` in `knowledge_base/epics/wip/NextGen/` that contains 10 PRDs (PRD-4-01 through PRD-4-10) for post-V1 enhancements.

**Answer** : EAS epic 4 future has been renamed so that it does not conflict with this epic.

**Objection**: Having two "Epic 4" documents creates ambiguity and will cause confusion in implementation status tracking, branch naming, and PRD references.

**Answer** : EAS epic 4 future has been renamed so that it does not conflict with this epic.

**Solutions**:
- **Option A** (Recommended): Renumber this as **Epic 5** to avoid conflict. Update all references in doc.
- **Option B**: Rename existing `epic-4-future.md` to `Epic-99-future-backlog.md` (treating it as a backlog rather than a numbered epic).
- **Option C**: Merge this with Epic 3 if it's truly part of the collaboration/AI features already in progress.

**Answer** : ERIC SMITH N/A resolved

**Eric's response**: Confirmed resolved—existing future epic file has been renamed (per your note). This document remains **Epic 4** (Reusable AI Persona Chat Interface). No merge with Epic 3 needed; this is a distinct vertical for persona-threaded chat UX on top of existing AgentHub foundations. Will update doc header and any internal references to Epic 4 explicitly.

---  

## Questions

### 2. Existing Pattern Dependencies
**Q1**: The doc references "existing sap_collaboration and Agent Hub foundations" — can you confirm these patterns are already implemented? Specifically:
- Is `SapRun` / `SapMessage` the current model for agent interactions?
- Does `AgentHubChannel` already exist with streaming support?
- Is `SmartProxyClient` + `ModelDiscoveryService` operational?

**Context**: Need to verify baseline before defining "enhancements" vs "net new" work.

**Eric's response**:
- `AgentHubChannel` exists (commit from Jan 10, 2026 fixed Markdown rendering in it), with basic streaming support present.
- `SapRun` / `SapMessage` — not explicitly visible in repo tree or recent commits under those exact names; likely internal naming for agent run/message persistence (possibly aliased or under different models like Run/Message in AI context). Assume baseline exists per your reference doc; if not fully implemented, PRD 1 will add/enhance columns only.
- `SmartProxyClient` + `ModelDiscoveryService` — assumed operational (local Ollama wrapper + model list endpoint); repo has `smart_proxy/` dir, supporting this. Enhancements will be minimal (persona_id routing).

**Q2**: What's the relationship between this Epic and the existing agent collaboration features? Is JunieDev a new persona or extending an existing agent?

**Context**: Helps determine if this is incremental enhancement or parallel system.

**Eric's response**: Incremental enhancement. JunieDev is the first concrete **persona** (AI collaborator identity with scoped context/system prompt), built on existing AgentHub/agent patterns. This epic adds threaded conversation persistence + UI selector layer, not replacing core agent execution.

**Q3**: The doc mentions `RagProvider` and `target_agent_id = persona_id`. Is the RAG system already integrated with persona-scoped context retrieval?

**Context**: PRD 4 scope depends on whether this is wiring vs building.

**Eric's response**: RAG exists (rag-structure-full.txt in repo root), but persona-scoping (via target_agent_id/persona_id) is likely partial or TBD. PRD 4 will focus on wiring persona_id into existing RagProvider calls and AgentHubChannel for context injection—assume base RAG works; add scoping as enhancement.

---  

### 3. LLM Title Generation
**Q4**: For conversation title generation via LLM (Option B chosen), which model should be used? Should this go through smart_proxy or direct to a specific lightweight model?

**Eric's response**: Route through `smart_proxy` (consistent with all LLM calls). Use lightweight/fast model: **llama3.1:8b** (or claude-haiku if available via proxy). Prompt constrained to 3-5 words summary.

**Q5**: What's the fallback behavior if title generation fails (timeout, error, rate limit)?

**Suggestion**: Use a lightweight fast model (e.g., llama3.1:8b or claude-haiku) for title gen to minimize latency. Fallback to truncated first message (first 40 chars + "...") on failure.

**Eric's response**: Agreed—fallback to "Chat [date]" or truncated first user message preview (first 40-50 chars + "..."). Implement as async Solid Queue job; if fails, set default title and log error.

---  

### 4. Model Switching Mid-Conversation
**Q6**: The doc states model switching "does not trigger immediate context refresh or system prompt re-injection" for v1. Does this mean:
- A) The new model gets the full message history as-is when it responds?
- B) The new model may have different system prompts/context requirements but we ignore that for simplicity?

**Clarification needed**: Ensure this doesn't create confusing behavior where model B responds oddly because it's missing context model A expected.

**Eric's response**: **A** — new model receives full history as-is (via existing message serialization). No system prompt re-injection on switch in v1 (simplicity). Risk accepted for v1; if odd behavior observed in testing, v2 can add optional "re-generate with new prompt" button. Document in PRD 3: "Change applies to next and future responses only."

---  

## Suggestions

### 5. PRD Breakdown Order
Current order: 1→2→3→4→5 (data → sidebar → selector → streaming → integration)  
Alternative consideration:
- Merge PRD 2+3 into single "Sidebar + Model Selector UI" PRD
    - **Pro**: Faster end-to-end visibility, sidebar is less useful without model selector
    - **Con**: Slightly larger PRD, harder to isolate failures  
      **Recommendation**: Keep as-is (5 PRDs). The current split allows testing sidebar with mock data before adding model complexity.

**Eric's response**: Agree—keep split as-is. Sidebar testable early with mock SapRun data; selector adds real persistence later.

---  

### 6. Implementation Status Tracking
**Observation**: No reference to creating/updating `0001-IMPLEMENTATION-STATUS.md` for Epic 4.

**Recommendation**: Per `.junie/guidelines.md` section 9, you should:
- Create `knowledge_base/epics/wip/NextGen/Epic-4/0001-IMPLEMENTATION-STATUS.md` before starting PRD 1
- Track completion status, blockers, and decision log
- Update after each PRD completion

**Eric's response**: Agreed—will create this file immediately (before PRD 1 kickoff). Track PRD completion, branches merged, blockers, and key decisions.

---  

### 7. Testing Strategy
**Observation**: PRD 5 mentions "system tests" but earlier PRDs only mention "simple RSpec."

**Suggestion**: Clarify testing expectations per PRD:
- PRD 1: Model tests (Minitest, not RSpec per guidelines)
- PRD 2: ViewComponent tests + Stimulus controller tests
- PRD 3: Integration test for model persistence flow
- PRD 4: Channel integration test for streaming
- PRD 5: Full system test (Capybara) for end-to-end flow

**Note**: Guidelines specify **Minitest**, not RSpec. Update references.

**Eric's response**: Agreed—switch all references to **Minitest** (project standard). Update PRD language accordingly: unit/model → Minitest; ViewComponent/Stimulus → Minitest + system tests where relevant; channel → integration; end-to-end → Capybara system tests in PRD 5.

---  

### 8. Mobile Experience Detail
**Observation**: Sidebar collapsed by default on mobile with hamburger icon.

**Suggestion**: Add explicit guidance for "new chat" action on mobile when drawer is collapsed. Options:
- A) Floating action button (FAB) always visible
- B) Hamburger opens drawer showing "New Chat" as prominent first item
- C) Both (FAB + drawer access)  
  **Recommendation**: Option B (simpler, no FAB clutter). Document in PRD 2.

**Eric's response**: Agreed—**Option B**. Document in PRD 2: Hamburger drawer opens with "New Conversation" as first/top item (prominent button).

---  

### 9. Stimulus Controller Naming
**Q7**: You asked about Stimulus naming conventions. Based on existing patterns in the repo, what's the current convention?

**Standard Stimulus convention**: Lowercase with hyphens, e.g., `conversation-sidebar_controller.js`

**Suggestion**: Use:
- `conversation-sidebar_controller.js` (sidebar list + new button)
- `model-selector_controller.js` (dropdown + persistence)
- `streaming-chat_controller.js` (cursor indicator, message handling)

**Eric's response**: Agreed—adopt lowercase-hyphen convention exactly as suggested. Will specify these names in relevant PRDs.

---  

### 10. Conversation Limits & Archiving
**Observation**: "Unlimited for v1" with future story for archive/delete.

**Risk**: Unlimited conversations could degrade sidebar performance with heavy users.

**Mitigation suggestion**: Add soft guidance in PRD 2:
- Sidebar initially loads most recent 50 conversations
- "Load more" link if >50 exist
- This avoids performance issues while still being "unlimited"

**Eric's response**: Good mitigation—add to PRD 2: paginate sidebar to most recent 50 (ordered by updated_at DESC), with "Load more" Stimulus action to fetch older via AJAX/JSON.

---  

### 11. Disclaimer Placement
**Observation**: "Always-visible subtle badge (DaisyUI alert-info, small font) in header."

**Clarification needed**: Which header?
- A) Sidebar header (always visible even when collapsed)
- B) Chat pane header (only visible when in active chat)
- C) Global app header (always visible across all pages)  
  **Recommendation**: Option B (chat pane header). More contextual, doesn't clutter non-chat pages.

**Eric's response**: Agreed—**Option B** (chat pane header, always visible during active conversation). Implement as reusable ViewComponent in PRD 4.

---  

## Improvements

### 12. Missing: Persona Configuration
**Observation**: Epic mentions "starting with JunieDev" and "per-conversation model selection."

**Question**: Where is persona configuration defined (name, default system prompt, default model)? Is this:
- A) Hardcoded in app (e.g., `PERSONAS = {junie: {...}}`)
- B) Database model (`Persona` table)
- C) Config file (e.g., `config/personas.yml`)

**Recommendation**: Clarify in PRD 1 or add PRD 0 for "Persona Configuration Foundation." Suggest config file for flexibility without DB overhead.

**Eric's response**: **C** — config/personas.yml (YAML array of personas with keys: id/slug, name, default_model, system_prompt_ref). Load via constant or initializer. Add brief section in PRD 1 (or small PRD 0 if needed) to define JunieDev entry. Keeps it lightweight/no migration.

---  

### 13. Missing: Error Handling Strategy
**Observation**: No mention of error states (streaming fails, model unavailable, context too large).

**Suggestion**: Add to PRD 4:
- Toast notification on streaming failure with retry button
- Graceful degradation if model unavailable (show error, allow model switch)
- Context window overflow handling (truncate or warn user)

**Eric's response**: Agreed—add these to PRD 4: DaisyUI toast for failures (retry via Stimulus), fallback message if model down, warn/truncate on token overflow (use smart_proxy metadata if available).

---  

### 14. Missing: Analytics/Observability
**Observation**: No mention of logging or metrics for:
- Model usage per conversation
- Title generation success/failure rates
- Streaming latency/errors

**Suggestion**: Add lightweight logging in PRD 5:
- Log model switches, streaming errors, title gen outcomes
- Use existing Rails.logger (or Sentry if present per guidelines)
- Enables future debugging and usage analysis

**Eric's response**: Agreed—add to PRD 5 (and sprinkle in earlier PRDs): Rails.logger.info for key events (model switch, title gen success/fail, streaming start/end/error with duration). No Sentry yet—keep Rails.logger.

---  

## Answers to Your Questions

### Q: "Does this PRD split feel atomic enough, or should we merge 2+3?"
**A**: Split is good as-is. PRD 2 can be tested with mock data independently of model selector complexity.

**Eric's response**: Agreed—split stays.

### Q: "Any concern with LLM title gen in v1 (latency/cost)?"
**A**: Minor concern. Mitigation:
- Use lightweight model (llama3.1:8b, claude-haiku)
- Run async (don't block message send)
- Fallback to truncation on failure (answered in Q5 above)

**Eric's response**: Agreed—implement async + fallback.

### Q: "Preferred Stimulus naming conventions?"
**A**: See suggestion in #9 above. Follow lowercase-hyphen pattern.

**Eric's response**: Adopted as suggested.

---  

## Next Steps
1. **Resolve Epic numbering conflict** (Issue #1) — Confirmed resolved via rename.
2. **Create `0001-IMPLEMENTATION-STATUS.md`** for tracking — Will create now.
3. **Clarify existing pattern dependencies** (Q1-Q3) — Addressed inline (partial visibility; assume baseline + enhancements).
4. **Update test strategy** to use Minitest consistently — Done in responses.
5. **Document persona configuration approach** (Issue #12) — Config YAML, add to PRD 1.
6. **Proceed with PRD 1** once above items are resolved — Ready when you confirm.

**Overall**: Strong epic design with thoughtful tradeoffs. Addressing numbering conflict and clarifying existing patterns are prerequisites for clean implementation.

**Eric's final note**: All clarifications provided; ready to finalize Epic 4 doc and generate PRD 1 (SapRun & SapMessage Enhancements). Let me know if any remaining gaps or adjustments before proceeding.