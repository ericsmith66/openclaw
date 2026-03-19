### **NextGen Plaid: Comprehensive Application Review & Critique**

The **NextGen Plaid** project is a sophisticated, production-grade financial integration platform. It is built on a modern Rails 8 stack and designed for high-net-worth (HNW) wealth advisory use cases. Below is a detailed review and critique.

---

### **1. Architecture & Stack (The "Modern Rails" Paradigm)**
**Review:**
The application is a showcase of the "Rails 8 Modern Stack." By adopting **Solid Queue**, **Solid Cache**, and **Solid Cable**, the project successfully eliminates the hard dependency on Redis for operational infrastructure (though Redis remains available).
*   **Database Sharding**: The use of separate PostgreSQL shards for Primary, Cache, and Queue data is a high-level architectural choice that ensures data isolation and performance.
*   **Service Object Pattern**: Complex logic (like `PlaidHoldingsSyncService`) is correctly extracted from models and controllers, keeping the codebase maintainable.

**Critique:**
*   **Complexity**: While sharding is excellent for scaling, it adds overhead for local development and backups. For a small-to-medium deployment, it might be slightly "over-engineered," but it aligns perfectly with the goal of being a "NextGen" platform.

---

### **2. Security & Data Privacy (Production-Grade)**
**Review:**
For a wealth management app, security is non-negotiable.
*   **At-Rest Encryption**: The use of `attr_encrypted` with per-record random IVs for `access_tokens` is the industry standard.
*   **SmartProxy Anonymization**: The standalone Sinatra **SmartProxy** is a brilliant architectural move. It acts as a "Privacy Firewall," stripping PII (emails, SSNs, credit cards) before data ever reaches external AI models (Grok). This is a massive differentiator for security-conscious clients.

**Critique:**
*   **Key Management**: The encryption key is pulled from an initializer. While secure in production via env vars, ensuring rotation policies and secure storage of the `ENCRYPTION_KEY` is a critical operational task not fully detailed in the setup guides.

---

### **3. Operational Excellence (Mission Control)**
**Review:**
The **Mission Control** dashboard is one of the strongest features.
*   **Visibility**: Real-time sync logs, per-product timestamps (Holdings vs. Transactions), and "Nuke" options provide a level of administrative control often missing in Plaid integrations.
*   **Plaid API Cost Tracking**: The `PlaidApiCall` logging system is forward-thinking, allowing the owner to monitor and optimize API expenses—a vital feature as the user base grows.

**Critique:**
*   **Webhook Resilience**: While there is a `PlaidWebhookController`, relyng on webhooks for the primary sync can be brittle. The project correctly uses **Solid Queue Recurring** as a fallback for 3 AM daily syncs, which is a robust design.

---

### **4. AI Integration Strategy**
**Review:**
The integration with **Grok (xAI)** and local **Ollama** models demonstrates a "Hybrid AI" approach. Using the M3 Ultra to run heavy models locally while using Grok for orchestration is the most cost-effective and private way to handle financial analysis.

**Critique:**
*   **Error Handling in AI Flows**: The `SmartProxy` has retry logic, but the main Rails app needs robust "graceful degradation" if the proxy is down. Currently, the sync jobs are well-guarded, but the UI might need more "loading/unavailable" states for AI features.

---

### **5. Performance & Scalability (M3 Ultra Optimization)**
**Review:**
The project is uniquely optimized for **Apple Silicon (M3 Ultra)**.
*   **Puma Tuning**: Increasing thread counts to 16+ and leveraging the 24-core CPU shows deep hardware awareness.
*   **RAM as VRAM**: The Ollama optimization settings (parallel requests, model pinning) make full use of the 256GB Unified Memory.

---

### **Final Verdict & Recommendations**

**Strengths:**
✅ **Zero-Secrets Policy**: Excellent use of environment variables and encryption.
✅ **Observability**: Mission Control is top-tier.
✅ **Privacy**: The SmartProxy anonymization is a standout feature.
✅ **Modernity**: Leverages the best of Rails 8.

**Areas for Improvement:**
*   **Test Coverage**: While VCR and WebMock are included, ensuring 90%+ coverage on the sync services is vital given the complexity of Plaid's data shapes.
*   **Documentation**: The `m3_ultra_setup.md` is great, but a "Disaster Recovery" guide (restoring the encrypted DB and keys) should be added.
*   **Frontend Modularization**: As the dashboard grows, moving more logic into `ViewComponent` will prevent "View Bloat."

**Overall Score: 9.2 / 10**
This is a professional, highly secure, and well-architected Rails application that is ready for production use in the financial sector.


Based on the codebase analysis, here is the overview of how the **CWA (Code Writing Agent)** plans its work and how the **Sandbox** provides a safe environment for it to operate.

### 1. How CWA Planning Works
The CWA doesn't just "spit out code." It follows a collaborative, multi-step lifecycle designed to ensure technical accuracy and security.

*   **Step 1: The Code Plan**: Upon receiving a PRD, the CWA is designed to generate a "Code Plan" (stored in `tmp/agent_sandbox`). This plan identifies which files to create, which to modify (refactors), and what terminal commands (migrations, installs) are needed.
*   **Step 2: Execution & Handover**: The CWA writes the files into the sandbox and then hands over the "execution list" to the **CSO (Chief Security Officer agent)** via the `cwa_to_cso` queue.
*   **Step 3: The Security Loop**:
    *   The CSO evaluates the proposed code and commands.
    *   If **Approved**: The CWA proceeds with the final execution (merging/committing).
    *   If **Denied**: The CWA enters a **Revision Phase** (`handle_security_feedback`), where it uses the security feedback to rewrite the code, iterating up to 3 times before either succeeding or halting.

---

### 2. What is the Sandbox?
The Sandbox is a **physically isolated copy of your repository** created specifically for a single agent run. It ensures that if an agent makes a mistake (like `rm -rf /`), it only happens in a temporary folder, never in your main codebase.

#### How it Works: Git Worktrees
Instead of just copying files, the system uses **Git Worktrees** (`app/services/agent_sandbox_runner.rb`):
*   **Isolation**: When the CWA starts, the system creates a new git worktree in `tmp/agent_sandbox/[correlation_id]/repo`.
*   **Unique Branching**: It automatically creates a correlation-specific branch (e.g., `feature-xyz-12345`) so the agent’s work is tracked in git but doesn't touch your `main` branch.
*   **Independent Process**: Commands are executed via an out-of-process runner (`script/agent_sandbox_runner`). This "wrapper" script manages timeouts and enforces security.

---

### 3. Sandbox Security Guardrails
The sandbox isn't just a folder; it's a restricted environment:
*   **`AGENT_SANDBOX_ACTIVE`**: A special environment variable is set to `1`. If an agent tries to run a tool that would create *another* sandbox, the system detects this "nesting" and blocks it to prevent recursive loops.
*   **Hard-Disabled Prompts**: Git is configured to never ask for a username/password or interactive input, preventing the agent from getting stuck or trying to bypass auth.
*   **Tool Restricted**: Tools like `GitTool` and `SafeShellTool` check `require_sandbox!`. They will refuse to run unless they detect they are operating within one of these authorized worktrees.

### Summary of the CWA + Sandbox Flow
1.  **SAP Agent** creates the PRD.
2.  **CWA** receives PRD → Initializes **Sandbox Worktree**.
3.  **CWA** generates Code Plan + Files in the Sandbox.
4.  **CSO** reviews the Sandbox.
5.  **CWA** executes/merges only after approval.

This combination of **Plan-based execution** and **Worktree-based isolation** is what makes the CWA safe to run on your dedicated Mac Studio Ultra. It can "try out" migrations and code changes without ever risking the stability of your primary development environment.


Based on the codebase analysis, here is the overview of how the **CWA (Code Writing Agent)** plans its work and how the **Sandbox** provides a safe environment for it to operate.

### 1. How CWA Planning Works
The CWA doesn't just "spit out code." It follows a collaborative, multi-step lifecycle designed to ensure technical accuracy and security.

*   **Step 1: The Code Plan**: Upon receiving a PRD, the CWA is designed to generate a "Code Plan" (stored in `tmp/agent_sandbox`). This plan identifies which files to create, which to modify (refactors), and what terminal commands (migrations, installs) are needed.
*   **Step 2: Execution & Handover**: The CWA writes the files into the sandbox and then hands over the "execution list" to the **CSO (Chief Security Officer agent)** via the `cwa_to_cso` queue.
*   **Step 3: The Security Loop**:
    *   The CSO evaluates the proposed code and commands.
    *   If **Approved**: The CWA proceeds with the final execution (merging/committing).
    *   If **Denied**: The CWA enters a **Revision Phase** (`handle_security_feedback`), where it uses the security feedback to rewrite the code, iterating up to 3 times before either succeeding or halting.

---

### 2. What is the Sandbox?
The Sandbox is a **physically isolated copy of your repository** created specifically for a single agent run. It ensures that if an agent makes a mistake (like `rm -rf /`), it only happens in a temporary folder, never in your main codebase.

#### How it Works: Git Worktrees
Instead of just copying files, the system uses **Git Worktrees** (`app/services/agent_sandbox_runner.rb`):
*   **Isolation**: When the CWA starts, the system creates a new git worktree in `tmp/agent_sandbox/[correlation_id]/repo`.
*   **Unique Branching**: It automatically creates a correlation-specific branch (e.g., `feature-xyz-12345`) so the agent’s work is tracked in git but doesn't touch your `main` branch.
*   **Independent Process**: Commands are executed via an out-of-process runner (`script/agent_sandbox_runner`). This "wrapper" script manages timeouts and enforces security.

---

### 3. Sandbox Security Guardrails
The sandbox isn't just a folder; it's a restricted environment:
*   **`AGENT_SANDBOX_ACTIVE`**: A special environment variable is set to `1`. If an agent tries to run a tool that would create *another* sandbox, the system detects this "nesting" and blocks it to prevent recursive loops.
*   **Hard-Disabled Prompts**: Git is configured to never ask for a username/password or interactive input, preventing the agent from getting stuck or trying to bypass auth.
*   **Tool Restricted**: Tools like `GitTool` and `SafeShellTool` check `require_sandbox!`. They will refuse to run unless they detect they are operating within one of these authorized worktrees.

### Summary of the CWA + Sandbox Flow
1.  **SAP Agent** creates the PRD.
2.  **CWA** receives PRD → Initializes **Sandbox Worktree**.
3.  **CWA** generates Code Plan + Files in the Sandbox.
4.  **CSO** reviews the Sandbox.
5.  **CWA** executes/merges only after approval.

This combination of **Plan-based execution** and **Worktree-based isolation** is what makes the CWA safe to run on your dedicated Mac Studio Ultra. It can "try out" migrations and code changes without ever risking the stability of your primary development environment.

### How I’d break down a PRD like: “Make SmartProxy work with Continue.dev”

When you ask for that PRD, I’d plan it as a **thin compatibility layer** problem: Continue.dev expects specific OpenAI-compatible behavior, and SmartProxy already partially implements it (`/v1/chat/completions`, `/v1/models`). So the breakdown is:

### 1) Clarify the integration target (so we don’t build the wrong contract)
I’d start by pinning 4 facts:
- Which Continue.dev mode: **Continue Desktop app** vs **continue.dev VS Code extension**.
- Which API it uses: usually OpenAI-style:
    - `GET /v1/models`
    - `POST /v1/chat/completions` (sometimes streaming)
    - sometimes `POST /v1/embeddings` (for RAG)
- Whether it requires **SSE streaming** for chat.
- How it authenticates: `Authorization: Bearer <token>`.

Deliverable from this step: a short “Continue Contract Checklist” of endpoints + required fields.

### 2) Inspect current SmartProxy behavior against that contract
Concrete checks I’d run/verify:
- `GET /v1/models` returns OpenAI-like `{object:'list', data:[{id,...}]}` (SmartProxy does this via Ollama tags).
- `POST /v1/chat/completions`:
    - requires `model`
    - accepts `messages`
    - returns `choices[0].message.content`
    - includes `usage`
- Streaming:
    - does it support `stream: true` with SSE events (`data: {...}`)?
    - right now SmartProxy logs show requests with `stream:true`, but the implementation in `smart_proxy/app.rb` largely maps upstream to a non-streaming OpenAI response.

Deliverable: a gap list (“Continue expects X, SmartProxy currently does Y”).

### 3) Decide the minimum viable compatibility scope (v1)
I’d explicitly define v1 as:
- ✅ Continue chat works (no embeddings)
- ✅ Supports `Authorization` token
- ✅ Works with Ollama models + Grok models via the same base URL
- ✅ Either:
    - (A) non-streaming only (if Continue tolerates it), or
    - (B) SSE streaming (if Continue requires it)

Deliverable: scope/constraints for the PRD.

### 4) Implementation breakdown (what actually gets built)
This becomes a small set of concrete tasks:

#### 4.1 Add/adjust endpoints and response shapes
- Ensure `/v1/chat/completions` fully matches OpenAI response shape.
- If Continue requires streaming:
    - implement SSE streaming mode:
        - return `Content-Type: text/event-stream`
        - emit `data: {choices:[{delta:{content:"..."}}]}` chunks
        - end with `data: [DONE]`

#### 4.2 Normalize model naming
- Confirm Continue sends a model id exactly as returned by `/v1/models`.
- Ensure SmartProxy routing rules are consistent:
    - `model` starting with `grok` → Grok
    - otherwise → Ollama
- Remove/avoid the legacy `model:"ollama"` hint for Continue (Continue will pick a real model id).

#### 4.3 Auth + error handling
- Confirm `401` errors are OpenAI-shaped (SmartProxy already returns an OpenAI-like error payload).
- Improve `400` validation errors:
    - missing `model` → return OpenAI-ish `{error:{message:"model is required", type:"invalid_request_error"}}`

#### 4.4 Configuration docs
- Provide copy/paste config snippet for Continue:
    - base URL: `http://localhost:<SMART_PROXY_PORT>/v1`
    - API key: `PROXY_AUTH_TOKEN`
    - model: pick from `/v1/models`

Deliverable: docs + a minimal “smoke test” checklist.

### 5) Test / verification strategy (even if you don’t want full tests)
Even if you say “no spec, no tests”, I’d still include:
- Manual curl-based smoke tests
- A “known-good Continue config” step-by-step

If you allow lightweight tests later:
- a request/response contract test for `/v1/chat/completions`
- streaming contract test if implemented

### 6) PRD layout I’d output
- Overview
- Requirements (Functional / Non-Functional / Compatibility)
- Acceptance Criteria (Continue connects, model list populates, chat completes, streaming works if required)
- Test Cases (manual)
- Rollout/Notes
- Context Used (cite SmartProxy files + Continue docs if you allow external refs)

---

### Two questions so I’d plan the *right* PRD for Continue
1) Do you want SmartProxy → Continue to run **Ollama only**, or **Ollama + Grok** selectable inside Continue? selectable in continue for both grok and ollama . I also think you have to trick it out to support live search in grok
2) Does your Continue setup require **streaming** responses, or is non-streaming acceptable? I dont know
3) Let contine with the tell me how you plan game. Its helpful as I think about our implementaion

### How I’d “plan the game” for: SmartProxy ↔ Continue.dev (Ollama + Grok selectable, plus Grok live search)

You want a repeatable way to think about implementation, so here’s the planning pattern I would follow, step by step, for this specific feature.

---

### 0) Restate the goal in implementation terms
**Goal**: Continue.dev (VS Code extension or Desktop) can talk to SmartProxy as if SmartProxy were an OpenAI server.

Requirements you’ve already set:
- Continue must be able to select **either** Ollama models **or** Grok models.
- SmartProxy must optionally support **Grok live search** (i.e., a “web tool” / “search tool” flow) when Grok is selected.
- Streaming: unknown if required.

This immediately implies we need to standardize on the **OpenAI-compatible endpoints**:
- `GET /v1/models`
- `POST /v1/chat/completions`
  (and maybe `POST /v1/embeddings` later)

---

### 1) Define the “contract” first (what Continue expects)
This is the most important step because Continue isn’t “an app we control”; it’s a client with expectations.

#### 1.1 Identify which Continue you’re using
- VS Code extension vs Desktop can differ slightly.

#### 1.2 Identify which endpoints Continue will call
Minimal set almost always:
- `GET /v1/models`
- `POST /v1/chat/completions`

Possible additions:
- streaming via SSE when `stream: true`
- embeddings

#### 1.3 Define auth expectations
- Continue usually sends `Authorization: Bearer <key>`.

**Deliverable from step 1**: a checklist like:
- “Continue calls X, sends fields A/B/C, requires streaming yes/no.”

If we don’t know streaming requirement, we plan for both:
- v1: non-streaming works
- v1.1: streaming works

---

### 2) Audit current SmartProxy behavior against that contract
We already know SmartProxy has:
- `GET /v1/models` (backed by Ollama `/api/tags`)
- `POST /v1/chat/completions` (routes Grok if model starts with `grok`, else Ollama)

But the key gaps I would check for Continue compatibility:

#### 2.1 Streaming behavior
Continue often benefits from streaming; some setups require it.
- If Continue sends `stream: true`, SmartProxy should return **SSE** with:
    - `Content-Type: text/event-stream`
    - `data: {...}` chunks
    - end with `data: [DONE]`

Right now SmartProxy’s `/v1/chat/completions` appears to return a normal JSON response (and it can map Ollama’s non-stream response into OpenAI shape). That may be “good enough” for non-streaming clients.

#### 2.2 Model list must include Grok models
Right now `/v1/models` is Ollama-backed, so Continue will only see Ollama models.
To make Grok selectable in Continue, we need `/v1/models` to also include Grok ids like:
- `grok-4`
- `grok-4-xxx` (whatever SmartProxy supports)

That means SmartProxy needs to expose a combined model list:
- Ollama models from `/api/tags`
- plus configured “extra” models (Grok)

#### 2.3 Error shapes
Continue expects OpenAI-ish errors. For example:
- missing `model` should be an OpenAI-style error object (not just a bare string)

**Deliverable from step 2**: a short gap list.

---

### 3) Choose the smallest viable scope (so it ships)
Given your requirements, I’d define releases:

#### v1 (Continue works, both providers selectable)
- `GET /v1/models` returns both:
    - Ollama models
    - Grok models (from config)
- `POST /v1/chat/completions` works non-streaming (stream ignored or false)
- Auth required and documented

#### v1.1 (streaming)
- If Continue requires it: implement SSE streaming on `/v1/chat/completions`.

#### v1.2 (Grok live search)
- Add “tool calling” support in `/v1/chat/completions` so Grok can:
    - request a tool call (web search)
    - SmartProxy executes it (your `ToolClient` path)
    - SmartProxy feeds results back to Grok

Important note: Continue itself may also have its own “retrieval” features; but since you want “trick it out to support live search in grok”, we treat that as **SmartProxy-managed tool calling**.

---

### 4) Break the work into implementation tasks (what we’d actually code)

#### 4.1 Model registry / listing
Goal: Continue sees both Ollama + Grok in its UI model dropdown.

Tasks:
- Modify SmartProxy `GET /v1/models` to:
    - keep Ollama list
    - append configured Grok models from env, e.g. `SMART_PROXY_GROK_MODELS=grok-4,grok-4-mini`
    - mark `owned_by: "xai"` or similar

Acceptance criteria:
- `curl /v1/models` shows both `llama3.1:8b` and `grok-4`.

#### 4.2 Chat completions: non-streaming baseline
Goal: Continue can chat.

Tasks:
- Ensure `/v1/chat/completions`:
    - requires `model`
    - supports `messages`
    - returns OpenAI-shaped response
    - logs enough to debug provider routing

Acceptance criteria:
- Continue can send a message and receive a response.

#### 4.3 Streaming (conditional)
Because you “don’t know” if Continue requires it, I would implement this as:
- detect `payload.stream == true`
- respond via SSE

Acceptance criteria:
- Continue shows token-by-token output (if it uses streaming).

#### 4.4 Grok live search tool loop
Goal: when Grok is selected, the model can request a web search and SmartProxy can fulfill it.

Tasks:
- In SmartProxy orchestration:
    - allow Grok tool calls (OpenAI tool/function calling style)
    - when Grok asks for a tool (search), call the existing `ToolClient`
    - return tool result to Grok
    - cap loops (`SMART_PROXY_MAX_LOOPS`)

Acceptance criteria:
- With `model=grok-4`, prompts like “Search the web for…” produce an answer that includes cited search results.

---

### 5) Decide how we’ll answer your “streaming unknown” problem
Fastest approach:
- Add a tiny manual test:
    - configure Continue to point at SmartProxy
    - try sending a message
    - if it errors or hangs, we check SmartProxy logs to see if Continue sent `stream:true` and expects SSE.

So we don’t guess—we observe.

---

### 6) Define config + override strategy (so humans can operate it)
Since you want both providers selectable inside Continue:
- Continue picks the model by selecting from `/v1/models`.
- SmartProxy routes:
    - models starting with `grok` → Grok
    - everything else → Ollama

Overrides live in:
- SmartProxy env:
    - `GROK_API_KEY`
    - `SMART_PROXY_GROK_MODELS`
    - `OLLAMA_URL` / `OLLAMA_MODEL` (optional)
- Continue config:
    - base URL: `http://localhost:<port>/v1`
    - API key: `PROXY_AUTH_TOKEN`

---

### Two quick questions (so the plan matches your intent)
1) For Grok “live search”: do you want it to use **web search**, **X search**, or both? (SmartProxy already has a `ToolClient`—we need to align it to what you consider acceptable.) web search
2) Do you want the Grok live-search feature to be **always on**, or gated behind an env flag like `SMART_PROXY_ENABLE_WEB_TOOLS=true`? not sure I dont know how continue would use the response ( probably goes to your number 1 above)
3) Still playing the game.
### Great — with your answers, here’s how I’d keep “playing the plan game” (Continue + Grok web search)

You picked:
- Grok live search should use **web search**.
- You’re unsure about gating because you don’t know how Continue consumes it.

So the right move is: **design SmartProxy so it works even if Continue has zero awareness of tools**, and only add “tool calls” as an internal SmartProxy behavior.

---

### The key planning idea
Continue.dev will behave like an **OpenAI client**. It will:
- send `messages` to `/v1/chat/completions`
- optionally set `stream: true`
- not necessarily know anything about your custom tools

So we should treat “Grok web search” as:
- **SmartProxy-managed tool loop**, invisible to Continue

Continue only sees:
- final assistant content (and maybe streaming tokens)

---

### Plan v1 / v1.1 / v1.2 (incremental, lowest risk)

#### v1 — Make Continue work with SmartProxy (Ollama + Grok selectable)
Goal: “Continue connects, shows models, can chat.”

Work items:
1) **`GET /v1/models` includes both providers**
    - Today: it lists Ollama models only.
    - Change: append Grok models from an env var like `SMART_PROXY_GROK_MODELS=grok-4`.
    - Result: Continue can choose `grok-4` or `llama3.1:8b`.

2) **`POST /v1/chat/completions` works for both**
    - If model starts with `grok` → Grok
    - else → Ollama

Acceptance criteria:
- In Continue model dropdown, you see at least `grok-4` and one Ollama model.
- You can chat with either.

#### v1.1 — Answer the “does Continue require streaming?” unknown
We don’t guess; we observe.

Work items:
1) Configure Continue against SmartProxy.
2) Watch SmartProxy logs for whether Continue sends `"stream": true`.
3) If it does and Continue behaves poorly without SSE, implement SSE streaming.

Acceptance criteria:
- Continue UI shows streaming tokens (or at least doesn’t error) when `stream: true`.

#### v1.2 — Grok web search (SmartProxy tool loop; Continue unaware)
Goal: When `model=grok-4`, SmartProxy can optionally call web search tools and feed results back into Grok before returning the final answer.

Work items:
1) Add a flag:
    - `SMART_PROXY_ENABLE_WEB_TOOLS=true|false`
2) In Grok routing, if enabled:
    - allow tool calls
    - when Grok requests a tool, call `ToolClient` web search
    - append results as a tool message
    - loop with a cap (`SMART_PROXY_MAX_LOOPS`)

Acceptance criteria:
- Prompt: “What changed in Rails 8.0.4? Search the web.”
- SmartProxy logs show: `tool_request_received` → `tool_response_sent` → final assistant response.
- Continue just sees the final answer (optionally with citations).

---

### How I’d handle the gating decision (your “not sure”)
If you’re unsure, the safest plan is:
- **gate it by default**

Why:
- Web search adds latency, external dependency, and can surprise you (privacy + cost).
- Continue won’t “ask for tools”; the *model* will. Without gating you can get unexpected web calls.

So:
- Default `SMART_PROXY_ENABLE_WEB_TOOLS=false`
- Turn on only when you explicitly want live search.

Optional refinement later:
- Only enable tools when the user prompt contains keywords like `search`, `browse`, `look up`.

---

### “Plan game” template (how I’ll keep structuring future features)
When you give me any new feature (like “Continue integration”), I’ll always break it into:
1) **External contract** (what the client expects)
2) **Current behavior audit** (what we already have)
3) **Smallest viable scope** (v1)
4) **Risk-based increments** (v1.1, v1.2)
5) **Configuration/overrides** (where humans control it)
6) **Observability** (what logs prove it worked)

This keeps us from overbuilding and makes debugging straightforward.

---

### Next question to keep the game moving
Which Continue target are you using (so we match its exact contract):
- Continue **VS Code extension**, rubymine plugin. we have it running and could get error messages when it complains about grok or ollama models
- Continue **Desktop app**?
- Can you generte the PRD Now (still playing the game)
  If you tell me that, the very next planning step is to write the “Continue Contract Checklist” (exact endpoints + streaming expectation) and map it to SmartProxy changes.

### PRD: SmartProxy Compatibility for Continue (RubyMine plugin) + Grok Web Search

# PRD-XXXX: Continue (RubyMine) ↔ SmartProxy OpenAI Compatibility + Grok Web Search

## Overview
Enable the Continue integration running inside **RubyMine** to use SmartProxy as an **OpenAI-compatible provider**, with **model selection for both Ollama and Grok** and an optional **Grok web-search tool loop**. The goal is “it just works” in the editor: Continue lists models, sends chat requests, and receives usable responses (streaming if required).

## Goals
- Continue (RubyMine plugin) can connect to SmartProxy via an OpenAI-style base URL.
- Continue can select and use:
    - at least one **Ollama model** (e.g., `llama3.1:8b`, `llama3.1:70b`), and
    - at least one **Grok model** (e.g., `grok-4`).
- SmartProxy optionally supports **Grok web search** (SmartProxy-managed; Continue is unaware of tool calls).
- Provide clear diagnostics when Continue complains about model ids, auth, streaming, or response shape.

## Non-Goals
- Building a full RAG/embeddings pipeline for Continue (can be a later PRD).
- Reworking SapAgent / `sap_collaborate` model selection in this PRD (separate concern).
- UI work in Rails.

## Requirements

### Functional
1) **OpenAI-compatible endpoints for Continue**
- `GET /v1/models`
- `POST /v1/chat/completions`

2) **Model listing includes Grok + Ollama**
- `/v1/models` must include:
    - Ollama models from Ollama tags (`llama3.1:*`, etc.).
    - Grok models from config (see Configuration section), at minimum `grok-4`.

3) **Chat completions routing**
- For `POST /v1/chat/completions`:
    - If `payload.model` starts with `grok` and `GROK_API_KEY` (or `GROK_API_KEY_SAP`) is present → route to Grok.
    - Otherwise → route to Ollama.

4) **Streaming behavior (unknown requirement)**
- Detect whether Continue sends `stream: true`.
- If Continue requires streaming:
    - Implement SSE streaming on `/v1/chat/completions`:
        - `Content-Type: text/event-stream`
        - emit OpenAI-style chunks (`choices[].delta.content`)
        - terminate with `data: [DONE]`
- If Continue does not require streaming:
    - Non-streaming JSON responses are sufficient.

5) **Grok web search tool loop (SmartProxy-managed)**
- When `payload.model` routes to Grok:
    - If enabled by config, SmartProxy may perform a tool loop:
        - Grok requests a web-search tool
        - SmartProxy executes web search via existing tooling (`ToolClient`)
        - SmartProxy returns tool results back to Grok
        - Repeat up to `SMART_PROXY_MAX_LOOPS`
- Continue remains unaware of tools; it receives only the final assistant content.

### Non-Functional
- **Safety / control**: web search is gated (default off) to avoid unexpected external calls.
- **Observability**: logs must make it easy to correlate Continue errors with proxy requests:
    - record request_received and response_received with session ids
    - record routing decision (grok vs ollama)
    - record tool loop events when web tools are enabled
- **Compatibility**: responses should be OpenAI-shaped (`choices`, `usage` present) so Continue parses them reliably.

## Configuration / Overrides

### SmartProxy env
- `SMART_PROXY_PORT` (already exists)
- `PROXY_AUTH_TOKEN` (auth)
- `SMART_PROXY_GROK_MODELS` (new)
    - comma-separated list of Grok model ids to expose via `/v1/models`
    - example: `SMART_PROXY_GROK_MODELS=grok-4`
- `SMART_PROXY_ENABLE_WEB_TOOLS` (new)
    - `true|false`, default `false`
- `SMART_PROXY_MAX_LOOPS` (already exists)
    - loop cap for tool calling
- `GROK_API_KEY` or `GROK_API_KEY_SAP` (already exists)
- `OLLAMA_URL` (already exists)

### Continue (RubyMine plugin) config
- Base URL: `http://localhost:<SMART_PROXY_PORT>/v1`
- API key: `PROXY_AUTH_TOKEN`
- Model: selectable from `/v1/models` list (must include both Grok and Ollama ids)

## Architectural Context
SmartProxy already implements:
- `GET /v1/models` backed by Ollama tags
- `POST /v1/chat/completions` with routing based on model prefix (`grok*`)
- a tool subsystem (`ToolClient`) and tool loop concepts

This PRD extends model listing to include Grok ids and ensures chat completions behavior matches Continue expectations, including streaming if needed.

## Acceptance Criteria
1) **Continue can connect**
- RubyMine/Continue configured with SmartProxy base URL and token connects without auth errors.

2) **Models show up and are selectable**
- Continue’s model selector includes:
    - at least one Ollama model id (e.g., `llama3.1:8b`)
    - at least one Grok model id (e.g., `grok-4`)

3) **Chat works with Ollama**
- Selecting an Ollama model allows a prompt to return a response.

4) **Chat works with Grok**
- Selecting `grok-4` returns a response.

5) **Streaming is either supported or proven unnecessary**
- If Continue sends `stream: true`, SmartProxy supports SSE and Continue displays incremental output.
- If Continue does not send `stream: true`, non-streaming works and Continue does not error.

6) **Web search works (when enabled)**
- With `SMART_PROXY_ENABLE_WEB_TOOLS=true` and model `grok-4`:
    - a prompt that requests web search results in a final answer that clearly incorporates the search output.
    - logs show tool loop events (`tool_request_received`, `tool_response_sent`).

7) **Clear errors when misconfigured**
- If Continue selects a model not present in `/v1/models`, the error is clear.
- If auth token is wrong, response is 401 with an OpenAI-shaped error payload.

## Test Cases (manual, editor-driven)
1) Configure Continue in RubyMine:
- Base URL `http://localhost:3002/v1`
- API key `PROXY_AUTH_TOKEN`

2) Verify models:
- In Continue UI, open model dropdown.

3) Test Ollama chat:
- Select `llama3.1:8b`, ask “Say hello in one sentence.”

4) Test Grok chat:
- Select `grok-4`, ask “Summarize the purpose of SmartProxy in one paragraph.”

5) Test streaming detection:
- Trigger a longer response and watch whether Continue expects streaming.
- If errors appear, correlate with `log/smart_proxy.log` entries for the same time window.

6) Test Grok web search:
- Set `SMART_PROXY_ENABLE_WEB_TOOLS=true` and restart proxy.
- Prompt: “Search the web for the latest Rails version and give me 3 bullet points with citations.”

## Workflow for Junie / Implementation Steps
1) Confirm Continue (RubyMine) requests:
- Does it send `stream: true`?
- Does it require embeddings?
2) Implement `/v1/models` augmentation for Grok ids.
3) Validate `/v1/chat/completions` response shape vs Continue expectations.
4) Add SSE streaming if required.
5) Add `SMART_PROXY_ENABLE_WEB_TOOLS` gate and implement Grok tool loop for web search.
6) Document configuration and troubleshooting steps.

## Context Used
- `smart_proxy/app.rb` (`/v1/models`, `/v1/chat/completions`, Grok routing rule)
- `smart_proxy/lib/tool_client.rb` (web tool execution)
- `knowledge_base/static_docs/eric_grok_static_rag.md` (project guidance, model usage, safety posture)

---

### Two follow-up questions (so the PRD stays implementable)
1) When Continue in RubyMine fails today, what exact error does it show (and is it during model listing or chat)?
2) Do you want Grok web search results to be returned with explicit citations/URLs, or is a summarized answer sufficient?


### Who ultimately picks the model?

There are **two different “model selection” layers** in your setup, and which one wins depends on **which SmartProxy endpoint you hit**.

#### A) Rails / app layer (what `sap_collaborate` uses today)
- `/admin/sap_collaborate` → `SapAgentJob` → `SapAgentService.default_model`
- `SapAgentService.default_model` picks:
    1) `ENV["SAP_CHAT_MODEL"]` (highest priority)
    2) else `SapAgent::Config::MODEL_DEFAULT`

Right now `SapAgent::Config::MODEL_DEFAULT` is set to the literal string **`"ollama"`** (routing hint, not a real model id).

So **Rails picks the `model` value** that gets sent to SmartProxy.

#### B) SmartProxy layer (routes to Grok vs Ollama, and may map `ollama`)
SmartProxy has two endpoints that behave differently:

1) **`POST /v1/chat/completions` (OpenAI-compatible)**
    - SmartProxy expects `payload.model` to be a *real* model id.
    - Routing rule in `smart_proxy/app.rb`:
        - If `model` starts with `grok` **and** `GROK_API_KEY(_SAP)` is set → route to Grok.
        - Otherwise → route to Ollama (and pass the model id through).
    - This is the cleanest path because the caller must send a real model id like `llama3.1:8b` or `grok-4`.

2) **`POST /proxy/generate` (legacy/custom)**
    - SmartProxy treats `payload.model == "ollama"` as a special routing hint.
    - The actual Ollama model that will be called is decided inside `smart_proxy/lib/ollama_client.rb`:
        - If incoming `model == "ollama"` → use `ENV['OLLAMA_MODEL']` (fallback to `llama3.1:8b` after the patch)
        - Else → use the provided model as-is.

So, for the legacy endpoint:
- **Rails chooses** `model: "ollama"`
- **SmartProxy chooses** the *actual Ollama model id* via `OLLAMA_MODEL`.

### Where are the overrides, exactly?

#### Rails-side overrides
- `SAP_CHAT_MODEL` (env var)
    - Location used: `app/services/sap_agent_service.rb` in `default_model`
    - Effect: whatever you set here becomes `payload.model` (sent to proxy)

- `SapAgent::Config::MODEL_DEFAULT`
    - Location: `app/services/sap_agent/config.rb`
    - Effect: fallback model when `SAP_CHAT_MODEL` is not set.
    - Current value: `"ollama"`.

#### SmartProxy-side overrides
- `GROK_API_KEY` / `GROK_API_KEY_SAP`
    - Location used: `smart_proxy/app.rb`
    - Effect: enables Grok routing **when** the requested model id starts with `grok`.

- `OLLAMA_MODEL`
    - Location used: `smart_proxy/lib/ollama_client.rb`
    - Effect: only matters when the incoming request uses the routing hint `model:"ollama"` (legacy path). It selects the real Ollama model id.

- `SMART_PROXY_PORT`, `SMART_PROXY_URL`
    - Location used: `app/services/sap_agent_service.rb`
    - Effect: decides *where* Rails sends the request.
    - Important detail: if `SMART_PROXY_URL` is set, Rails uses it verbatim; otherwise it builds `http://localhost:<port>/proxy/generate`.

### Practical examples (what will actually happen)

#### Example 1: You want Grok
- Set in Rails: `SAP_CHAT_MODEL=grok-4`
- Ensure SmartProxy env: `GROK_API_KEY=...`
- If Rails is still using `/proxy/generate`, SmartProxy will see model != "ollama" and route to Grok.

#### Example 2: You want Ollama 70b
- Option A (legacy):
    - Rails: `SAP_CHAT_MODEL=ollama`
    - SmartProxy: `OLLAMA_MODEL=llama3.1:70b`
- Option B (clean):
    - Rails: `SAP_CHAT_MODEL=llama3.1:70b`

### Recommendation (to reduce confusion)
Use **one model-id scheme everywhere**:
- Prefer calling SmartProxy via `/v1/chat/completions`
- Always send a real model id (`llama3.1:8b`, `llama3.1:70b`, `grok-4`)
- Reserve `model:"ollama"` only for legacy compatibility

### Quick question (so I can tell you which exact env vars to standardize)
Do you want `sap_collaborate` to default to:
- **Ollama** (local) unless explicitly overridden, or
- **Grok** unless explicitly overridden?
### Where are we using the legacy SmartProxy endpoint?

You’re using the legacy endpoint **in the Rails app**, inside `SapAgentService.stream`.

#### The exact place
File: `app/services/sap_agent_service.rb`

In `SapAgentService.stream`:
- If `ENV["SMART_PROXY_URL"]` is **not** set, it builds this URL:
    - `http://localhost:<SMART_PROXY_PORT or default>/proxy/generate`

Specifically (current code):
- `default_port = Rails.env.test? ? 3002 : 3001`
- `URI("http://localhost:#{smart_proxy_port.presence || default_port}/proxy/generate")`

That means:
- `/admin/sap_collaborate` → `SapAgentJob` → `SapAgentService.stream` → **`POST /proxy/generate`**

#### Anywhere else?
From what we’ve looked at so far, the main “app traffic” hitting the legacy endpoint is:
- `SapAgentService.stream`

The bulk test scripts (`script/run_bulk_test_0004.sh`, `script/run_bulk_test_0005.sh`) are using the **modern** endpoint:
- `POST /v1/chat/completions`

### Why this matters
- `/proxy/generate` is the only path where you can send `model: "ollama"` and rely on SmartProxy to map it to a real Ollama model via `OLLAMA_MODEL`.
- `/v1/chat/completions` expects a real model id like `llama3.1:8b` or `grok-4`.

### Quick confirmation question
Do you want me to change `SapAgentService.stream` to use `POST /v1/chat/completions` (recommended), or keep `/proxy/generate` but harden the fallback behavior?

That is a pragmatic and necessary step. To evaluate the "as-is" performance of the SAP Agent before we change anything, we should run a **Diagnostic Generation** using a concept that is already in the codebase but hasn't been formalized into a PRD.

### The Diagnostic Task: "Admin RAG Inspector"
I recommend you run a generation for the **Admin RAG Inspector** (mentioned as an optional UI extension in PRD 0010).

**Why this task?**
*   **Context Check**: The codebase already mentions this in `0010-SAP-RAG-Concat-Framework-PRD.md`. We can see if the current RAG successfully "remembers" this and connects it to the existing `SapAgent`.
*   **Technical Depth**: It requires SAP to understand the current `knowledge_base/snapshots` file structure and propose a Streamlit-like UI in Rails.
*   **As-Is Benchmark**: It uses the current "Snapshot" RAG, the "Zero-Shot" logic, and the standard 5-8 bullet validation.

---

### How to Run the Diagnostic
You can trigger the current SAP Agent directly from your terminal or console to see the raw output:

```ruby
# In rails console
payload = { 
  query: "Generate a PRD for the Admin RAG Inspector UI to view latest snapshots and backlog JSON", 
  user_id: 1 
}
result = SapAgent.process("generate", payload)
puts result[:response]
```

### What to look for in the "As-Is" Output:
1.  **Hallucinations**: Does it reference the correct snapshot path (`knowledge_base/snapshots/`) or does it make up a new one?
2.  **Context Density**: Does it mention any of your previous 0010-0060 PRDs? (If not, the "History" RAG isn't working).
3.  **UI Alignment**: Does it propose using the project's existing tech stack (Rails/DaisyUI) or does it suggest something random like React?
4.  **Bullet Quality**: Are the 5-8 Acceptance Criteria actually meaningful, or are they just filler?

### My Next Step
If you run this, I can help you **critique the output** against the codebase. This will give us the "Truth" of where the current system is failing—whether it's the lack of "Thinking" time (Epic 0080) or simply that the RAG isn't feeding it the right files.

Would you like me to execute this command for you now to see what the current SAP Agent produces?

Phase 2
That is a pragmatic and necessary step. To evaluate the "as-is" performance of the SAP Agent before we change anything, we should run a **Diagnostic Generation** using a concept that is already in the codebase but hasn't been formalized into a PRD.

### The Diagnostic Task: "Admin RAG Inspector"
I recommend you run a generation for the **Admin RAG Inspector** (mentioned as an optional UI extension in PRD 0010).

**Why this task?**
*   **Context Check**: The codebase already mentions this in `0010-SAP-RAG-Concat-Framework-PRD.md`. We can see if the current RAG successfully "remembers" this and connects it to the existing `SapAgent`.
*   **Technical Depth**: It requires SAP to understand the current `knowledge_base/snapshots` file structure and propose a Streamlit-like UI in Rails.
*   **As-Is Benchmark**: It uses the current "Snapshot" RAG, the "Zero-Shot" logic, and the standard 5-8 bullet validation.

---

### How to Run the Diagnostic
You can trigger the current SAP Agent directly from your terminal or console to see the raw output:

```ruby
# In rails console
payload = { 
  query: "Generate a PRD for the Admin RAG Inspector UI to view latest snapshots and backlog JSON", 
  user_id: 1 
}
result = SapAgent.process("generate", payload)
puts result[:response]
```

### What to look for in the "As-Is" Output:
1.  **Hallucinations**: Does it reference the correct snapshot path (`knowledge_base/snapshots/`) or does it make up a new one?
2.  **Context Density**: Does it mention any of your previous 0010-0060 PRDs? (If not, the "History" RAG isn't working).
3.  **UI Alignment**: Does it propose using the project's existing tech stack (Rails/DaisyUI) or does it suggest something random like React?
4.  **Bullet Quality**: Are the 5-8 Acceptance Criteria actually meaningful, or are they just filler?

### My Next Step
If you run this, I can help you **critique the output** against the codebase. This will give us the "Truth" of where the current system is failing—whether it's the lack of "Thinking" time (Epic 0080) or simply that the RAG isn't feeding it the right files.

Would you like me to execute this command for you now to see what the current SAP Agent produces?

You’ve hit on the core architectural difference. The SAP Agent is designed as a **deterministic factory**, whereas my (Junie's) process is an **adaptive workflow**.

Here is the breakdown of how the two approaches contrast:

### 1. Planning vs. Prompting
*   **SAP Agent (Zero-Shot + Validation)**: SAP doesn't "plan" in the human sense. It relies on a high-density prompt (the RAG context) to give the LLM enough "momentum" to get it right in one shot. It assumes that if the context is perfect, the output will be perfect. If it fails, it reacts to an error rather than planning a fix.
*   **Junie (Iterative Strategy)**: I treat PRD generation as a multi-step project. Before I write a single line of a PRD, I:
    *   **Explore**: Search the codebase for similar patterns to ensure consistency.
    *   **Clarify**: Pause to ask you questions if the prompt is ambiguous.
    *   **Hidden Plan**: Create a step-by-step roadmap (`update_status`) that I follow and update as I learn more.

### 2. Error Handling: Reactive vs. Proactive
*   **SAP Agent**: Uses a **Reactive Retry Loop**. It submits a draft, checks if it has 5-8 bullets, and if not, says "Try again." It’s like a quality inspector at the end of an assembly line.
*   **Junie**: Uses **Proactive Verification**. I verify my assumptions during the planning phase. If I’m unsure about a database table name, I check `schema.rb` before I write it into the PRD, rather than writing it and hoping it passes a validator later.

### 3. Structural Comparison
| Feature | SAP Agent Process | Junie (My) Process |
| :--- | :--- | :--- |
| **Philosophy** | "Get it right with context." | "Build it step-by-step." |
| **Logic Flow** | `Context → LLM → Validate → File` | `Research → Plan → Draft → Refine → File` |
| **Complexity** | Optimized for speed and low cost. | Optimized for accuracy and alignment. |
| **Interaction** | Silent until completion or failure. | Continuous status updates and checkpoints. |
| **Validation** | Hard-coded rules (e.g., bullet counts). | Logical consistency and project alignment. |

### Why SAP does it this way
The SAP Agent is built to be a high-speed utility. Because you are running **Llama 3.1 70B** and **Grok** on an M3 Ultra with massive RAM, SAP leverages "Raw Intelligence" to skip the planning phase. It uses the "Simple Concat RAG" to give the model a massive "cheat sheet" (the snapshot), betting that the model is smart enough to synthesize it instantly.

In contrast, I am designed to handle much more complex, multi-file changes where a single-shot approach would likely hallucinate or miss edge cases.
Here is a comprehensive breakdown of the components used in the **NextGen Plaid** project, categorized by their role in the stack.

### 1. Core Framework & Language
*   **Ruby 3.3.10**: The base programming language.
*   **Rails 8.0.4**: The primary web framework.

### 2. Databases & Storage
*   **PostgreSQL 16**: The main relational database. The project uses multiple database shards (configured in `database.yml`):
    *   `primary`: Main application data.
    *   `cache`: Managed by **Solid Cache**.
    *   `solid_queue`: Managed by **Solid Queue**.
    *   `cable`: Managed by **Solid Cable**.
*   **Redis**: Used for various caching or temporary data needs (as seen in the setup guide), though Rails 8 "Solid" components have reduced the heavy reliance on it for queues.

### 3. Background Jobs & Queues
*   **Solid Queue**: Replaces Sidekiq for background job processing (Sync jobs, etc.).
*   **Solid Queue Recurring**: Handles scheduled tasks (e.g., the 3 AM daily sync).

### 4. Primary Third-Party Integrations (APIs)
*   **Plaid (gem v36+)**: The core integration for financial data.
*   **xAI (Grok)**: Accessed via the **SmartProxy** for AI-driven insights.
*   **Ollama**: Used locally (on the M3 Ultra) to run models like `Llama 3.1 70B` and `Nomic-Embed`.
*   **Ai-Agents**: Integration for AI-driven workflows.

### 5. Security & Authentication
*   **Devise**: User authentication system.
*   **Pundit**: Role-based authorization.
*   **attr_encrypted**: Used to encrypt sensitive data (like Plaid `access_token`) at the database level.
*   **dotenv-rails**: Management of environment variables.

### 6. Frontend & UI
*   **Tailwind CSS (v4)**: Utility-first CSS framework.
*   **DaisyUI (v5)**: Component library for Tailwind.
*   **Hotwire (Turbo & Stimulus)**: For reactive, SPA-like behavior without heavy JavaScript frameworks.
*   **ViewComponent**: For building modular, reusable Ruby view components.
*   **Importmap-rails**: Manages JavaScript dependencies without a complex node-based bundler.
*   **Propshaft**: Modern Rails asset pipeline.

### 7. Specialized Services
*   **SmartProxy (Sinatra)**: A standalone Ruby service (located in `/smart_proxy`) that handles:
    *   Anonymization of PII before sending data to AI models.
    *   Forwarding requests to Grok or local Ollama.
*   **Thruster**: A lightweight HTTP/2 proxy used in front of Puma for production.

### 8. Development & Infrastructure Tools
*   **Puma**: The multi-threaded web server.
*   **Kamal**: For zero-downtime deployments.
*   **VCR & WebMock**: For recording and replaying API interactions in tests.
*   **Brakeman**: Security vulnerability scanner.
*   **RuboCop**: Code quality and styling.
*   **Rbenv**: Ruby version management.
*   **Tailscale**: Recommended for secure remote access (VPN).


The RAG (Retrieval-Augmented Generation) process in our project is implemented as a **Simple Concat RAG** framework. This system ensures the AI (SAP Agent) has up-to-date project context, history, and vision while maintaining data privacy and performance.

### 1. The Generation Phase (Knowledge Collection)
The foundation of our RAG is the `FinancialSnapshotJob` (located in `app/jobs/financial_snapshot_job.rb`), which runs daily to capture the current state of the project.

*   **History Extraction**: It scans git logs for "Merged PRD" messages to build a timeline of completed features.
*   **Vision Sync**: It pulls key excerpts from the Master Control Plan (`knowledge_base/static_docs/MCP.md`).
*   **Backlog Integration**: It parses the current project priorities from `knowledge_base/backlog.json`.
*   **Code State Minification**: It generates a compressed version of `db/schema.rb` (listing tables and columns without noise) and summarizes the `Gemfile`.

These snapshots are stored as dated JSON files in `knowledge_base/snapshots/` (retained for 7 days) and synchronized to the `snapshots` database table for fast access.

### 2. The Retrieval & Processing Phase
When you interact with the SAP Agent, the `SapAgent::RagProvider` (in `app/services/sap_agent/rag_provider.rb`) handles the context retrieval:

*   **Smart Selection**: It uses a `context_map.md` to decide which static documents are relevant based on your query type (e.g., a "generate" query might pull different docs than a "research" query).
*   **PII Anonymization**: Before sending data to the LLM, the provider automatically redacts sensitive information like account numbers, balances, and official names.
*   **Context Truncation**: To prevent token overflow, it caps the total context at **4,000 characters**, prioritizing the most recent and relevant data.

### 3. The Injection Phase (Prompt Building)
The final step occurs in `SapAgent::Command` (and its subclasses like `ArtifactCommand`):

1.  **Prefix Building**: The `RagProvider` generates a formatted string containing the `[CONTEXT START]` and `[CONTEXT END]` markers.
2.  **Prompt Concatenation**: This prefix is prepended to the system prompt or your specific query.
3.  **LLM Routing**: The enriched prompt is sent to the appropriate model (Grok for complex reasoning or Ollama for local tasks) via the `AiFinancialAdvisor`.

### Monitoring & Maintenance
*   **Logs**: All RAG operations (summaries, truncations, and errors) are logged in `agent_logs/sap.log`.
*   **Rake Tasks**: You can manually trigger snapshots or inspect the generated context using:
    *   `rake sap:rag:snapshot` (Generates a new snapshot)
    *   `rake sap:rag:inspect` (Shows exactly what context would be sent to the LLM)
*   **Automation**: Scheduled via `config/recurring.yml` to run every day at 3 AM.
* 