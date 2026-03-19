# Epic 4 Overview Feedback V1

**Reviewer**: Junie (Claude Sonnet 4.5)
**Date**: 2026-01-29
**Source**: `0000-overview-epic-4.md`

---

## Summary Assessment

Strong foundation with clear scope and well-considered design decisions. The atomic PRD breakdown is logical and dependency-aware. Primary concerns: (1) Epic numbering conflict with existing Epic-4-future.md, (2) missing implementation status tracking, (3) some technical clarifications needed for existing patterns.

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
---

## Questions

### 2. Existing Pattern Dependencies

**Q1**: The doc references "existing sap_collaboration and Agent Hub foundations" — can you confirm these patterns are already implemented? Specifically:
- Is `SapRun` / `SapMessage` the current model for agent interactions?
- Does `AgentHubChannel` already exist with streaming support?
- Is `SmartProxyClient` + `ModelDiscoveryService` operational?

**Context**: Need to verify baseline before defining "enhancements" vs "net new" work.

---

**Q2**: What's the relationship between this Epic and the existing agent collaboration features? Is JunieDev a new persona or extending an existing agent?

**Context**: Helps determine if this is incremental enhancement or parallel system.

---

**Q3**: The doc mentions `RagProvider` and `target_agent_id = persona_id`. Is the RAG system already integrated with persona-scoped context retrieval?

**Context**: PRD 4 scope depends on whether this is wiring vs building.

---

### 3. LLM Title Generation

**Q4**: For conversation title generation via LLM (Option B chosen), which model should be used? Should this go through smart_proxy or direct to a specific lightweight model?

**Q5**: What's the fallback behavior if title generation fails (timeout, error, rate limit)?

**Suggestion**: Use a lightweight fast model (e.g., llama3.1:8b or claude-haiku) for title gen to minimize latency. Fallback to truncated first message (first 40 chars + "...") on failure.

---

### 4. Model Switching Mid-Conversation

**Q6**: The doc states model switching "does not trigger immediate context refresh or system prompt re-injection" for v1. Does this mean:
- A) The new model gets the full message history as-is when it responds?
- B) The new model may have different system prompts/context requirements but we ignore that for simplicity?

**Clarification needed**: Ensure this doesn't create confusing behavior where model B responds oddly because it's missing context model A expected.

---

## Suggestions

### 5. PRD Breakdown Order

**Current order**: 1→2→3→4→5 (data → sidebar → selector → streaming → integration)

**Alternative consideration**:
- Merge PRD 2+3 into single "Sidebar + Model Selector UI" PRD
  - **Pro**: Faster end-to-end visibility, sidebar is less useful without model selector
  - **Con**: Slightly larger PRD, harder to isolate failures

**Recommendation**: Keep as-is (5 PRDs). The current split allows testing sidebar with mock data before adding model complexity.

---

### 6. Implementation Status Tracking

**Observation**: No reference to creating/updating `0001-IMPLEMENTATION-STATUS.md` for Epic 4.

**Recommendation**: Per `.junie/guidelines.md` section 9, you should:
- Create `knowledge_base/epics/wip/NextGen/Epic-4/0001-IMPLEMENTATION-STATUS.md` before starting PRD 1
- Track completion status, blockers, and decision log
- Update after each PRD completion

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

---

### 8. Mobile Experience Detail

**Observation**: Sidebar collapsed by default on mobile with hamburger icon.

**Suggestion**: Add explicit guidance for "new chat" action on mobile when drawer is collapsed. Options:
- A) Floating action button (FAB) always visible
- B) Hamburger opens drawer showing "New Chat" as prominent first item
- C) Both (FAB + drawer access)

**Recommendation**: Option B (simpler, no FAB clutter). Document in PRD 2.

---

### 9. Stimulus Controller Naming

**Q7**: You asked about Stimulus naming conventions. Based on existing patterns in the repo, what's the current convention?

**Standard Stimulus convention**: Lowercase with hyphens, e.g., `conversation-sidebar_controller.js`

**Suggestion**: Use:
- `conversation-sidebar_controller.js` (sidebar list + new button)
- `model-selector_controller.js` (dropdown + persistence)
- `streaming-chat_controller.js` (cursor indicator, message handling)

---

### 10. Conversation Limits & Archiving

**Observation**: "Unlimited for v1" with future story for archive/delete.

**Risk**: Unlimited conversations could degrade sidebar performance with heavy users.

**Mitigation suggestion**: Add soft guidance in PRD 2:
- Sidebar initially loads most recent 50 conversations
- "Load more" link if >50 exist
- This avoids performance issues while still being "unlimited"

---

### 11. Disclaimer Placement

**Observation**: "Always-visible subtle badge (DaisyUI alert-info, small font) in header."

**Clarification needed**: Which header?
- A) Sidebar header (always visible even when collapsed)
- B) Chat pane header (only visible when in active chat)
- C) Global app header (always visible across all pages)

**Recommendation**: Option B (chat pane header). More contextual, doesn't clutter non-chat pages.

---

## Improvements

### 12. Missing: Persona Configuration

**Observation**: Epic mentions "starting with JunieDev" and "per-conversation model selection."

**Question**: Where is persona configuration defined (name, default system prompt, default model)? Is this:
- A) Hardcoded in app (e.g., `PERSONAS = {junie: {...}}`)
- B) Database model (`Persona` table)
- C) Config file (e.g., `config/personas.yml`)

**Recommendation**: Clarify in PRD 1 or add PRD 0 for "Persona Configuration Foundation." Suggest config file for flexibility without DB overhead.

---

### 13. Missing: Error Handling Strategy

**Observation**: No mention of error states (streaming fails, model unavailable, context too large).

**Suggestion**: Add to PRD 4:
- Toast notification on streaming failure with retry button
- Graceful degradation if model unavailable (show error, allow model switch)
- Context window overflow handling (truncate or warn user)

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

---

## Answers to Your Questions

### Q: "Does this PRD split feel atomic enough, or should we merge 2+3?"

**A**: Split is good as-is. PRD 2 can be tested with mock data independently of model selector complexity.

---

### Q: "Any concern with LLM title gen in v1 (latency/cost)?"

**A**: Minor concern. Mitigation:
- Use lightweight model (llama3.1:8b, claude-haiku)
- Run async (don't block message send)
- Fallback to truncation on failure (answered in Q5 above)

---

### Q: "Preferred Stimulus naming conventions?"

**A**: See suggestion in #9 above. Follow lowercase-hyphen pattern.

---

## Next Steps

1. **Resolve Epic numbering conflict** (Issue #1) — Confirm renumbering to Epic 5 or alternative
2. **Create `0001-IMPLEMENTATION-STATUS.md`** for tracking
3. **Clarify existing pattern dependencies** (Q1-Q3) before finalizing PRD scopes
4. **Update test strategy** to use Minitest consistently
5. **Document persona configuration approach** (Issue #12)
6. **Proceed with PRD 1** once above items are resolved

---

**Overall**: Strong epic design with thoughtful tradeoffs. Addressing numbering conflict and clarifying existing patterns are prerequisites for clean implementation.
