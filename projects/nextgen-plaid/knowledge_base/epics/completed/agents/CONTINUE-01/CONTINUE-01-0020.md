### PRD 0020: Combined Model Registry for Continue (Ollama + Grok in `/v1/models`)

**Overview**: Continue must be able to select **both** Ollama and Grok models. Today SmartProxy’s `GET /v1/models` is backed by Ollama tags only. Extend it to also list configured Grok model ids.

**Requirements**:
1) **Model Listing**
   - `/v1/models` returns:
     - all Ollama models (existing behavior)
     - plus Grok model ids from an env var (e.g., `SMART_PROXY_GROK_MODELS=grok-4`).
2) **Stable IDs**
   - Grok model ids must exactly match what SmartProxy accepts in `/v1/chat/completions` (e.g., `grok-4`).
3) **Metadata**
   - Mark Grok entries as `owned_by: "xai"` (or similar) for clarity.
4) **Failure Modes**
   - Decide one behavior and document it:
     - either list Grok models even if `GROK_API_KEY` is missing (fail clearly when selected),
     - or hide Grok models when Grok is not configured.

**Architectural Context**: Continue selects models by reading `GET /v1/models`. If Grok models are not listed, Grok cannot be selected inside the editor. SmartProxy owns model listing and must provide a stable set.

**Acceptance Criteria**:
- Continue model picker includes:
  - at least one Ollama model (e.g., `llama3.1:8b`)
  - at least one Grok model (e.g., `grok-4`).
- Selecting `grok-4` routes to Grok when API key is present.

**Test Cases**:
- Manual: `curl -H "Authorization: Bearer $PROXY_AUTH_TOKEN" http://localhost:<port>/v1/models` shows Grok + Ollama.
- Manual: Continue model picker shows both.

**Workflow**: Implement SmartProxy model list augmentation; validate in Continue.

**Context Used**:
- `smart_proxy/app.rb` (`GET /v1/models` behavior)
