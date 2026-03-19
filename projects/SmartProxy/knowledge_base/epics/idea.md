### Anthropic Native vs SmartProxy (OpenAI-Compatible) in AiderDesk — Complete Difference Analysis

SmartProxy connects to AiderDesk as an **OpenAI-Compatible** provider (`src/main/models/providers/openai-compatible.ts`), while Anthropic uses a **native provider** (`src/main/models/providers/anthropic.ts`). Here are all the differences that explain why the native Anthropic config works better.

---

### Feature Comparison Table

| Feature | Anthropic Native | SmartProxy (OpenAI-Compatible) |
|---------|-----------------|-------------------------------|
| **SDK** | `@ai-sdk/anthropic` (native) | `@ai-sdk/openai-compatible` (generic) |
| **Prompt Caching** | ✅ Ephemeral cache control | ❌ None |
| **Cache Cost Tracking** | ✅ Tracks cache write/read tokens | ❌ Generic token counting only |
| **Model Info Enrichment** | ✅ `getModelInfo` from metadata DB | ❌ Not implemented |
| **Provider Options** | ❌ None needed | ✅ `reasoningEffort` mapping |
| **Provider Parameters** | ❌ Not implemented | ❌ Not implemented |
| **Provider Tools** | ❌ Not implemented | ❌ Not implemented |
| **Message Normalization** | ❌ Not implemented | ❌ Not implemented |
| **Streaming** | ✅ Native streaming with reasoning chunks | ✅ Streaming works, but reasoning chunk format may differ |
| **Model Discovery** | `api.anthropic.com/v1/models` with `x-api-key` + `anthropic-version` headers | `{baseUrl}/models` with `Bearer` token |
| **Aider Mapping** | `anthropic/{modelId}` | `openai/{modelId}` |

---

### The 3 Biggest Performance Differences

#### 1. Prompt Caching (Biggest Impact)

This is likely the **#1 reason** for the performance gap. The Anthropic provider enables **ephemeral prompt caching** (lines 166–175 of `anthropic.ts`):

```typescript
export const getAnthropicCacheControl = (): CacheControl | undefined => {
  return {
    providerOptions: {
      anthropic: {
        cacheControl: { type: 'ephemeral' },
      },
    },
    placement: 'message',
  };
};
```

This cache control is applied in `optimizeMessages()` (`agent/optimizer.ts`), which annotates messages with `providerOptions` so Anthropic can cache the system prompt and early conversation turns. On subsequent tool-call iterations within the same run, Anthropic **reuses cached tokens** instead of re-processing them.

The OpenAI-compatible strategy has **no `getCacheControl` method at all**. Every iteration re-sends and re-processes the full context from scratch. For a typical agent run with 5–15 tool-call iterations, this means:

- **Anthropic**: Pays full price on iteration 1, then ~90% cache hits on iterations 2–15
- **SmartProxy**: Pays full price on every single iteration

This affects both **speed** (cached tokens are served faster) and **cost**.

#### 2. Cost Tracking Accuracy

Anthropic's `getAnthropicUsageReport` (lines 136–163) extracts cache-specific metadata:

```typescript
const { anthropic } = (providerMetadata as AnthropicMetadata) || {};
const cacheWriteTokens = anthropic?.cacheCreationInputTokens ?? 0;
const cacheReadTokens = anthropic?.cacheReadInputTokens ?? usage?.cachedInputTokens ?? 0;
const messageCost = calculateAnthropicCost(model, sentTokens, receivedTokens, cacheWriteTokens, cacheReadTokens);
```

SmartProxy uses `getDefaultUsageReport` which only tracks basic `inputTokens` and `outputTokens`. If SmartProxy's underlying model (e.g., Claude via proxy) is actually doing caching, AiderDesk can't see or account for it.

#### 3. Model Info Enrichment

Anthropic's strategy includes `getModelInfo: getDefaultModelInfo` which looks up the model in AiderDesk's metadata database to populate:
- `inputCostPerToken` / `outputCostPerToken`
- `cacheWriteInputTokenCost` / `cacheReadInputTokenCost`
- `maxOutputTokens`
- Context window size

The OpenAI-compatible strategy **does not implement `getModelInfo`**, so models loaded from SmartProxy have **no cost data, no context window info, and no max output token defaults**. This means:
- Cost reporting shows $0 or inaccurate values
- The agent may not know the model's context limit, risking truncation
- `maxOutputTokens` falls back to whatever the profile sets (or nothing)

---

### What's NOT Different (These Work the Same)

- **Streaming**: Both support streaming via `streamText()` / `generateText()` — controlled by `isStreamingDisabled()` per model
- **Reasoning/Thinking**: The `extractReasoningMiddleware` wraps ALL models equally (line 873 of `agent.ts`) — it looks for `<think>` tags regardless of provider
- **Tool calling**: Same `ToolSet` is passed to both; the AI SDK handles tool call format translation
- **Repair tool calls**: Same `repairToolCall` logic for both
- **Context compaction**: Same `compactMessagesIfNeeded` for both
- **Max iterations**: Same iteration limits

---

### Recommendations to Improve SmartProxy Performance

#### Quick Wins (No Code Changes)

1. **Manually set model overrides in AiderDesk UI**: For each SmartProxy model, set `maxOutputTokens`, `temperature`, and cost-per-token values manually in the model settings. This compensates for the missing `getModelInfo`.

2. **Disable streaming if you see issues**: If SmartProxy's streaming format doesn't match what AiderDesk expects, set `disableStreaming: true` on the provider. This forces `generateText()` instead of `streamText()`.

3. **Use the `reasoningEffort` setting**: The OpenAI-compatible provider DOES support this (line 125–154 of `openai-compatible.ts`). Set it to `high` for complex tasks.

#### Code Changes (If You Want Parity)

1. **Add prompt caching for SmartProxy**: If SmartProxy forwards to Anthropic, you could add a `getCacheControl` method to the OpenAI-compatible strategy that mirrors Anthropic's. Many OpenAI-compatible proxies pass through Anthropic's cache headers.

2. **Add `getModelInfo` to OpenAI-compatible strategy**: Copy the `getDefaultModelInfo` reference from the Anthropic strategy:
   ```typescript
   // In openai-compatible.ts
   import { getDefaultModelInfo } from '@/models/providers/default';
   
   export const openaiCompatibleProviderStrategy: LlmProviderStrategy = {
     ...
     getModelInfo: getDefaultModelInfo,  // ADD THIS
   };
   ```
   This would let AiderDesk look up cost/context data for models like `claude-sonnet-4-6` even when accessed through SmartProxy.

3. **Custom usage report**: If SmartProxy returns cache token info in its response (check the `smart_proxy` field in the log — I saw it includes `prompt_cache_hit_tokens` and `prompt_cache_miss_tokens`), write a custom `getUsageReport` that extracts these.

---

### TL;DR

The native Anthropic provider is better because of **prompt caching** (faster iterations, lower cost), **accurate cost tracking** (cache-aware), and **model metadata enrichment** (knows context limits and pricing). SmartProxy as OpenAI-compatible gets none of these. The fastest fix is adding `getModelInfo: getDefaultModelInfo` to the OpenAI-compatible strategy and manually configuring model overrides in the UI.

### Recommended Defaults for Grok 4.1 Fast in AiderDesk

#### Quick Settings

| Setting | Recommended Value | Rationale |
|---------|------------------|-----------|
| **Temperature** | `0.0` – `0.2` | For coding/agent tasks, you want deterministic output. Grok models default to 0.0 for code generation. Use 0.2 if you want slight creativity in architecture/planning phases. |
| **Max Output Tokens** | `16,384` | Grok 4.1 Fast supports up to 16K output tokens. Set this explicitly since AiderDesk won't auto-detect it via the OpenAI-compatible provider. |
| **Context Window** | `131,072` (128K) | Grok 4.1 Fast has a 128K context window. Good to know for compaction thresholds. |

#### Detailed Reasoning

**Temperature: `0.0`** for lead developer / QA tasks
- Grok 4.1 Fast is optimized for speed and instruction-following
- At `0.0`, tool calls are more reliable (no random parameter hallucination)
- For architect tasks where you want more creative solutions, bump to `0.2`–`0.4`
- Never go above `0.7` for coding — Grok models start producing inconsistent output

**Max Output Tokens: `16,384`**
- Grok 4.1 Fast caps at 16K output tokens per response
- This is important to set explicitly because the OpenAI-compatible provider doesn't fetch this from model metadata
- If you leave it unset, AiderDesk may default to a lower value or no limit, causing truncated responses on large code generations

#### How to Set in AiderDesk

In the provider settings for your SmartProxy / OpenAI-compatible provider:

1. Go to **Settings → Providers → [Your SmartProxy Provider]**
2. Find the Grok 4.1 Fast model in the model list
3. Click to edit/override:
    - **Temperature**: `0.0`
    - **Max Output Tokens**: `16384`
4. If cost tracking matters, also set:
    - **Input Cost Per Token**: `$0.000005` ($5.00 / 1M tokens)
    - **Output Cost Per Token**: `$0.000025` ($25.00 / 1M tokens)

#### Comparison to Your Other Models

| Model | Temperature | Max Output | Context | Speed |
|-------|------------|------------|---------|-------|
| `deepseek-reasoner` | 0.0 | 8,192 | 64K | Slow (reasoning) |
| `claude-sonnet-4-6` | 0.2 | 8,192 | 200K | Medium |
| `claude-opus-4-6` | 0.2 | 8,192 | 200K | Slow |
| **`grok-4.1-fast`** | **0.0** | **16,384** | **128K** | **Fast** |

Grok 4.1 Fast's advantage is the **2× output token limit** (16K vs 8K) combined with speed. This makes it well-suited for lead developer tasks that generate large code files in a single turn — which aligns with the "fewer turns, more depth per turn" recommendation from the earlier analysis.

### General Performance Tweaks for Reverse Proxies Fronting LLM Providers

When setting up a reverse proxy (e.g., using tools like NGINX, Caddy, or specialized LLM proxies like LiteLLM or mcp-proxy) to front LLM APIs such as Grok (xAI), Claude (Anthropic), DeepSeek, and Ollama (for local models), the goal is to optimize for latency, cost, throughput, and reliability. Key strategies include caching, rate limiting, connection management, and request optimization. These can be implemented at the proxy level without modifying the underlying models.

A unified proxy allows routing requests based on query complexity (e.g., send simple queries to faster/cheaper models like DeepSeek, escalate complex ones to Claude or Grok). Use libraries like LiteLLM for routing and fallbacks to ensure high availability.

#### Core Optimizations Applicable to All Models
- **Caching**: Implement response caching to reuse outputs for identical or similar queries, reducing API calls and latency. Standard exact-match caching works for deterministic queries (e.g., with temperature=0). For natural language variability, use semantic caching (matching on meaning via embeddings) to achieve up to 86% cost reduction and 88% faster responses. Tune similarity thresholds (e.g., 0.8-0.95 cosine similarity) to balance accuracy and hit rates. Backends like Redis/Valkey are ideal for storage. This can save 50-90% on costs for repetitive tasks.
- **Rate Limiting and Throttling**: Enforce per-provider limits to avoid bans or overages. For example, queue requests and retry with exponential backoff.
- **Compression and Async Processing**: Enable GZIP/Deflate for responses to cut bandwidth. Use asynchronous handling (e.g., in Python with asyncio) for concurrent requests, achieving sub-200ms latency for most queries.
- **Connection Pooling**: Maintain persistent connections (keep-alive) to backends to reduce handshake overhead.
- **Fallback and Routing**: Automatically switch providers if one fails or is slow, prioritizing based on cost/performance (e.g., cheap models first).
- **Monitoring and Logging**: Track metrics like cache hit rates, latency, and token usage to fine-tune.
- **Prompt Optimization**: At the proxy, compress prompts (e.g., summarize long inputs) to minimize token costs.

#### Per-Model Tweaks
Here's a breakdown tailored to each provider, focusing on proxy-level enhancements. For local setups (e.g., Ollama or DeepSeek), proxy tweaks emphasize efficient forwarding to the backend.

| Model/Provider | Caching Strategy | Performance Tweaks | Considerations |
|---------------|------------------|--------------------|----------------|
| **Grok (xAI API)** | Exact-match for factual queries; semantic for conversational ones. Cache at proxy level since Grok doesn't have built-in prompt caching. Use Redis for storage. | Route simple queries here for speed; enable fallbacks to cheaper models. Use quantization proxies if self-hosting variants. Secure API keys via proxy vaulting. | API-based, so focus on cost optimization—cache aggressively for repeated tools/integrations. Monitor token rebates for bulk usage. |
| **Claude (Anthropic API)** | Leverage built-in prompt caching for long contexts (e.g., reuse prefixes). At proxy, add semantic caching for full responses. | Escalate complex reasoning tasks here; async batching for high-volume. Set higher context limits (up to 200k tokens) via proxy config. | Excellent for enterprise; proxy can filter PII before sending to avoid risks. Use for quality over speed in routing logic. |
| **DeepSeek (API or Local via Ollama)** | KV cache for local runs (paged for efficiency); semantic caching at proxy for API calls. Quantize to FP8/INT4 for faster inference if local. | For local: Increase context length (e.g., to 8k-32k) in Ollama config for better quality; use exponential backoff retries. Proxy can burst to cloud (e.g., Bedrock) for overload. Prioritize for reasoning tasks due to high HumanEval scores. | Cheap at scale but memory-intensive locally—proxy should monitor VRAM and route accordingly. Semantic caching shines here for variable queries. |
| **Ollama (Local Models)** | In-memory or disk-based caching for responses; integrate with proxy for semantic matching. Avoid caching personalized data. | Optimize backend: Quantization for speed; set num_ctx parameter higher (e.g., 8192) to prevent truncation. Use ngrok for secure remote access if needed. Proxy-level async to handle GPU bottlenecks. | Local, so no API costs but higher latency—cache heavily. Ideal for private setups; proxy can add security layers like auth. Balance with cloud fallbacks for scale. |

#### Implementation Tips
- **Tools/Libraries**: Use LiteLLM for unified API and caching. For semantic caching, integrate with vector DBs like Valkey. Rust-based proxies (e.g., mcp-proxy) offer low-latency forwarding.
- **Testing**: Measure baselines without tweaks, then A/B test (e.g., cache hit rate >70% is a good target).
- **Edge Cases**: For non-deterministic outputs, expire caches quickly or use cache invalidation based on model updates.

These tweaks can significantly boost performance while keeping costs down, especially in hybrid local/cloud setups. If your proxy is in Python, leverage asyncio for seamless integration.
