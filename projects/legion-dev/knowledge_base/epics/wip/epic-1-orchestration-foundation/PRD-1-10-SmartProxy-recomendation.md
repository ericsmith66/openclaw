Now I have everything I need. Full picture from both sides. Here are the recommendations:

---

## AgentDesk Gem — Recommended Modifications

Framed entirely around what SmartProxy sends back and what the gem currently does with it.

---

### 🔴 #1 — `ResponseNormalizer` drops cache tokens SmartProxy already sends
**Impact: High | Effort: Trivial**

SmartProxy's `dump_llm_call_artifact!` already captures the full `usage` hash from every provider. DeepSeek returns `prompt_cache_hit_tokens` / `prompt_cache_miss_tokens`, Grok returns `cached_prompt_tokens`, and Claude (once we add the cache headers) will return `cache_creation_input_tokens` / `cache_read_input_tokens`. All of these come through SmartProxy normalized in the `usage` field of the response body.

The gem **silently drops them**. `ResponseNormalizer.normalize_usage` only picks out `prompt_tokens`, `completion_tokens`, `total_tokens`. Everything else is discarded.

`TokenBudgetTracker` has `cache_read_tokens` and `cache_write_tokens` parameters wired in. `CostCalculator` has `cache_read_cost_per_token` and `cache_write_cost_per_token` rates. The plumbing exists end-to-end — the normalizer is the single missing link.

**Fix:** Extend `normalize_usage` to forward cache token fields using the field names SmartProxy passes through:

```ruby
def self.normalize_usage(usage)
  return { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 } unless usage
  {
    prompt_tokens:       usage["prompt_tokens"]              || 0,
    completion_tokens:   usage["completion_tokens"]          || 0,
    total_tokens:        usage["total_tokens"]               || 0,
    cache_read_tokens:   usage["prompt_cache_hit_tokens"]    ||
                         usage["cached_prompt_tokens"]       ||
                         usage["cache_read_input_tokens"]    || 0,
    cache_write_tokens:  usage["prompt_cache_miss_tokens"]   ||
                         usage["cache_creation_input_tokens"] || 0
  }
end
```

One method, ~8 lines. Immediately unlocks real cost tracking for DeepSeek and Grok (free, automatic caching), and for Claude once SmartProxy adds cache headers.

---

### 🔴 #2 — Wrong default port for `:smart_proxy`
**Impact: High | Effort: Trivial**

`ModelManager#default_base_url` returns `http://localhost:4567` for `:smart_proxy`. SmartProxy runs on port **3001** in production (confirmed from the server memory). Every legion agent connecting to SmartProxy on the same machine will silently fail or hit the wrong service unless the caller explicitly passes `base_url:`.

```ruby
# current
when :smart_proxy then "http://localhost:4567"

# fix — match SmartProxy's actual port, or make it ENV-driven
when :smart_proxy then ENV.fetch("SMART_PROXY_URL", "http://localhost:3001")
```

Also worth adding a `:legion` provider preset that points to the production server:

```ruby
when :legion then ENV.fetch("SMART_PROXY_URL", "http://192.168.4.253:3001")
```

---

### 🔴 #3 — No retry middleware in `ModelManager` — SmartProxy returns 429s and 500s
**Impact: High | Effort: Low**

We saw three 500s in the logs (19:06, 19:18, 19:29) all caused by upstream provider timeouts. SmartProxy passes these back as HTTP 500. A single transient 500 or 429 from SmartProxy will crash the entire runner loop mid-run — potentially 50+ iterations in. SmartProxy's own Faraday clients (Grok, Claude, DeepSeek, Fireworks) all have retry middleware configured. AgentDesk has none.

Add Faraday retry to `ModelManager#faraday_connection`:

```ruby
def faraday_connection
  @faraday_connection ||= Faraday.new(url: @base_url, request: { timeout: @timeout }) do |conn|
    conn.request :retry, {
      max: 3,
      interval: 1.0,
      backoff_factor: 2,
      retry_statuses: [429, 500, 502, 503, 504],
      retry_block: ->(env, _, retries, exc) {
        warn "[AgentDesk] Retrying (#{retries} left) after #{exc&.message || env.status}"
      }
    }
    conn.adapter Faraday.default_adapter
  end
end
```

Requires adding `faraday-retry` to the gemspec (it's a separate gem from Faraday 2.x). SmartProxy already has this dependency so it's already in the lockfile ecosystem.

---

### 🟡 #4 — `PromptsManager` and `SkillLoader` are hardcoded to `.aider-desk` paths
**Impact: Medium | Effort: Low**

Three places reference `.aider-desk` as a hardcoded directory name:
- `SkillLoader` defaults to `~/.aider-desk/skills` and `{project}/.aider-desk/skills`
- `PromptsManager` defaults to `~/.aider-desk/prompts` and `{project}/.aider-desk/prompts`
- `RulesLoader` (same pattern)

With the move to legion, skills, prompts, and rules should live under `.legion/` or be configurable via a single constant. SmartProxy's own knowledge base is already under `knowledge_base/` — the convention should unify.

**Fix:** Extract the config dir name to a single constant:

```ruby
module AgentDesk
  CONFIG_DIR = ENV.fetch("AGENT_DESK_CONFIG_DIR", ".aider-desk")
end
```

Then all three loaders reference `AgentDesk::CONFIG_DIR` instead of the hardcoded string. One ENV var to migrate the whole ecosystem to `.legion/`.

---

### 🟡 #5 — `smart_proxy` header sends wrong `X-LLM-Base-Dir`
**Impact: Medium | Effort: Low**

`ModelManager#build_headers` hardcodes `"X-LLM-Base-Dir" => Dir.pwd` for the `:smart_proxy` provider. SmartProxy reads this header to determine where to dump the LLM call artifacts. `Dir.pwd` at gem initialization time is whatever directory the process started in — for a Rails app embedding the gem that's the Rails root, which may not be the project the agent is actually working on.

The correct value is the `project_dir` passed to `runner.run(project_dir: ...)`. But `ModelManager` doesn't know about `project_dir` — that's a `Runner` concern.

**Fix:** Make `X-LLM-Base-Dir` configurable at `ModelManager` construction time, and have `Runner` pass it through:

```ruby
# ModelManager
def initialize(provider:, api_key: nil, base_url: nil, model: "gpt-4o-mini",
               timeout: 120, llm_base_dir: nil)
  @llm_base_dir = llm_base_dir || Dir.pwd
  ...
end

# In build_headers:
headers["X-LLM-Base-Dir"] = @llm_base_dir if provider == :smart_proxy
```

Then when `Runner` creates or receives a `ModelManager`, the `project_dir` from `run()` can be forwarded. SmartProxy will then dump artifacts in the right place, and the correlation between agent runs and their artifact directories will be correct.

---

### 🟡 #6 — `Profile` carries dead Aider tool weight
**Impact: Medium | Effort: Low**

`Profile` has `use_aider_tools: true` as a default and the entire `AIDER_TOOL_*` constant group and tool approvals exist for AiderDesk-specific context file management. In the legion model, the runner uses power tools directly — there's no Aider subprocess. These defaults mean every agent starts with `aider` tools registered in its approval map even though there's no `AiderToolSet` factory that works without the AiderDesk app.

**Fix:** Set `use_aider_tools: false` in `default_attributes` and strip `AIDER_TOOL_*` entries from `default_tool_approvals`. Keep the constants and tool implementations in place (another host app might use them) but don't advertise them as defaults in the profiles.

---

### 🟢 #7 — `MemoryStore` keyword retrieval doesn't scale
**Impact: Medium | Effort: Medium**

SmartProxy can reach Ollama's local embedding models. The gem ships with keyword-only retrieval (`query.split.count { include? }`) which means semantic queries like "authentication patterns" won't match a memory saying "OAuth2 token refresh logic". For a coding agent building up institutional knowledge over many sessions, this is a real limitation.

**Fix — two-phase approach:**
1. Short-term (no new deps): add TF-IDF scoring over the keyword match — weight rare terms more heavily than common ones. This is pure Ruby, no new gems.
2. Medium-term: add an optional `embedding_fn` parameter to `MemoryStore`. When provided, memories are stored with an embedding vector and retrieved by cosine similarity. The embedding function can be injected from outside — e.g., a call to `http://localhost:11434/api/embeddings` on Ollama. The gem stays dependency-free; the caller provides the function.

```ruby
MemoryStore.new(
  storage_path: "/path/to/memories.json",
  embedding_fn: ->(text) { ollama_embed(text) }  # injected from host app
)
```

---

### 🟢 #8 — Streaming is buffered, not real-time
**Impact: Low-Medium | Effort: High**

`ModelManager#stream_request` reads the full response into `StringIO` before parsing SSE. The `SSEParser` is well-implemented and correctly handles all edge cases — the problem is upstream: Faraday's default adapter buffers the response before your code sees any bytes.

For the agent loop this is mostly fine (you need the full tool call response before you can execute anything), but it makes the UI feel unresponsive on long assistant messages. Real streaming would require switching to `Faraday::StreamingAdapter` or `Net::HTTP` with `response_block`.

Given the runner already skips streaming when tools are present (which is most of the time in agent mode), the practical impact is low. **Defer this until the legion UI explicitly needs live token streaming.**

---

### Summary

| # | Change | Where | Impact | Effort |
|---|---|---|---|---|
| 1 | Forward cache tokens from SmartProxy usage | `ResponseNormalizer` | 🔴 High | Trivial |
| 2 | Fix `:smart_proxy` default port + add `:legion` preset | `ModelManager` | 🔴 High | Trivial |
| 3 | Add Faraday retry for 429/500 | `ModelManager` | 🔴 High | Low |
| 4 | Extract `.aider-desk` to configurable constant | `SkillLoader`, `PromptsManager`, `RulesLoader` | 🟡 Medium | Low |
| 5 | Make `X-LLM-Base-Dir` use actual `project_dir` | `ModelManager`, `Runner` | 🟡 Medium | Low |
| 6 | Default `use_aider_tools: false` | `Profile` | 🟡 Medium | Low |
| 7 | Improve `MemoryStore` retrieval (TF-IDF then embeddings) | `MemoryStore` | 🟢 Medium | Medium |
| 8 | Real SSE streaming | `ModelManager` | 🟢 Low-Med | High |

Items 1–3 are a single PR — maybe 30 minutes of work — and directly fix real bugs we've already observed in the logs. Items 4–6 are cleanup that should happen before legion goes into production. Items 7–8 are improvements for later.