# Epic 4 Overview Feedback V2

**Reviewer**: Claude (via Eric Smith)
**Date**: 2026-01-30
**Source**: User clarification request for Epic 4 scope

---

## Clarification: Separation of Admin Agent Hub vs. User Chat Interface

### Issue
The current Epic 4 PRDs reference modifying `AgentHubChannel` and building on "Agent Hub foundations," but the user has clarified:

**What we DO NOT want:**
- Modify the `agent_hub` UI or code
- Build the user-facing chat interface within the agent_hub context

**What we DO want:**
- Build a **new user-accessible chat interface** on a new route: `/chats/[persona]`
- First persona: `financial-advisor` (Warren Buffett persona)
- `agent_hub` remains **admin-only** for interacting with SAP, CWA, Coordinator agents

### Questions for Clarification

**Q1: Channel Architecture**
The current PRD 4-03 modifies `AgentHubChannel` to handle persona chats. Should we instead:
- A) Create a new `PersonaChatChannel` separate from `AgentHubChannel`? EAS:YES
- B) Keep `AgentHubChannel` but add clear separation between admin vs. user contexts? 
- C) Build the new chat interface using the same underlying streaming infrastructure but with a completely different controller/channel? 

**Recommendation**: Option A - Create `PersonaChatChannel` for clean separation. Admin channel stays isolated for SAP/CWA/Coordinator work.

---

**Q2: Data Model Separation**
Current PRDs extend `SapRun` / `SapMessage` for persona chats. Should we:
- A) Continue using `SapRun` / `SapMessage` with `persona_id` field to distinguish admin vs. user chats?
- B) Create separate models like `PersonaConversation` / `PersonaMessage`?
- C) Add a `conversation_type` enum to `SapRun` (e.g., "admin_agent", "user_persona")? 
- EAS: This is not related to SAPRUN at all so I think it B)

**Recommendation**: Option A or C - Keep using `SapRun` / `SapMessage` but add clear type distinction. Avoids duplicate streaming/model infrastructure.

---

**Q3: Persona Configuration**
Current PRD 4-01 defines `personas.yml` with:
```yaml
personas:
  - id: junie
    name: JunieDev
    ...
  - id: finance
    name: Finance Advisor
    ...
```

Should the first persona be:
- A) `id: financial-advisor`, `name: "Warren Buffett - Financial Advisor"`
- B) `id: warren-buffett`, `name: "Warren Buffett"`
- C) Keep generic `id: finance` for flexibility? EAS A:

**Also**: Should `JunieDev` persona be removed from user-facing personas (since it's more of a dev/admin tool)? EAS Yes 

**Recommendation**: Agree
- Use `id: financial-advisor` for consistency with route structure
- Keep `name: "Warren Buffett"` or `"Warren Buffett - Financial Advisor"` as display name
- Remove or flag `junie` as `admin_only: true` in personas.yml

---

**Q4: Routing Structure**
Current PRD 4-04 defines:
- `/chats` → redirects to `/chats/junie`
- `/chats/:persona_id`

Should this be updated to:
- `/chats` → redirects to `/chats/financial-advisor`
- `/chats/financial-advisor` as the default/only persona for V1?

**Recommendation**: Yes - update default redirect and PRD examples to use `financial-advisor` as primary persona. EAS Agree 

---

**Q5: Agent Hub References**
Throughout the PRDs, there are references to "Agent Hub foundations" and using `AgentHubChannel`. Should these be updated to:
- Remove references to Agent Hub as a user-facing feature? YES
- Clarify that Agent Hub is admin-only (`/agent_hub` route, not accessible to regular users)? YES
- Emphasize that `/chats/[persona]` is a **new, separate interface** for users? YES

**Recommendation**: Yes - update all PRDs to clarify the separation. Agent Hub = admin tool, Persona Chat = user tool.

---

**Q6: System Prompt and Persona Behavior**
For the Warren Buffett financial advisor persona:
- What should the system prompt emphasize? (e.g., "You are Warren Buffett, providing educational financial advice...") EAS YES
- Should responses reference Warren Buffett's investment philosophy, books, quotes? EAS YES
- Educational disclaimer wording - should it specifically mention this is a simulation of Warren Buffett, not actual advice? EAS NO

**Recommendation**: Define system prompt in PRD 4-01 with:
- Clear Warren Buffett persona framing YES
- Educational simulation disclaimer YES
- Focus on teaching principles (value investing, long-term thinking, etc.) YES

---

**Q7: RAG Context**
Current PRD 4-03 mentions RAG context injection for different personas (e.g., JunieDev gets coding docs, Finance gets financial docs).

For Warren Buffett persona:
- What documents should be in the RAG context? (e.g., Berkshire Hathaway annual letters, investment principles?)
- Should we create a new RAG namespace/directory for financial advisor persona? YES

**Recommendation**: Create `knowledge_base/personas/financial_advisor/` with relevant financial education docs for RAG injection. YES

---

## Proposed Changes to Epic 4

### High-Level Updates Needed:

1. **Epic Overview** (`0000-overview-epic-4.md`):
   - Update "Epic Overview" section to clarify this is a NEW user-facing chat interface, separate from Agent Hub
   - Change default persona from `junie` to `financial-advisor`
   - Remove references to "building on Agent Hub foundations" or clarify Agent Hub is admin-only
   - Update route structure: `/chats/[persona]` where first persona is `financial-advisor`

2. **PRD 4-01** (Schema):
   - Update `personas.yml` example to use `financial-advisor` as primary persona
   - Add `conversation_type` enum or clarify `persona_id` distinguishes admin vs. user chats
   - Define Warren Buffett system prompt
   - Update default model inheritance examples to use `financial-advisor` instead of `junie`

3. **PRD 4-02** (Sidebar UI):
   - Update route references from `/chats/junie` to `/chats/financial-advisor`
   - Update component examples to use financial advisor persona
   - Clarify this is a new UI, not modifying agent_hub views

4. **PRD 4-03** (Streaming):
   - Create `PersonaChatChannel` instead of modifying `AgentHubChannel`
   - OR: Clearly document that `AgentHubChannel` handles both admin and user contexts with separation logic
   - Update RAG context references to include financial advisor docs

5. **PRD 4-04** (Integration):
   - Update routing examples to use `financial-advisor`
   - Update test cases to use Warren Buffett persona
   - Clarify this is testing the NEW `/chats/[persona]` interface, not agent_hub

6. **PRD 4-05** (Mobile):
   - Update examples to use financial advisor persona

---

## Next Steps

**Awaiting Eric's Answers to Q1-Q7 Above**

Once clarified, I will:
1. Update Epic 4 overview document
2. Update all 5 PRDs with correct persona, routes, and architectural separation
3. Ensure all references to Agent Hub are clarified as admin-only
4. Update example code, test cases, and manual test scenarios to use `financial-advisor` persona

---

**Overall Assessment**: The core Epic 4 architecture is sound, but needs updates to reflect the separation between:
- **Agent Hub** (admin-only, `/agent_hub`, SAP/CWA/Coordinator interactions)
- **Persona Chat** (user-facing, `/chats/[persona]`, starting with Warren Buffett financial advisor)

The main changes are scoping, naming, and clarification—not fundamental architectural rework.
