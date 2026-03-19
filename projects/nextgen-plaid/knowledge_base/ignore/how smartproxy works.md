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