# PRD — Claude Prompt Caching Support

**Status**: Ready for Implementation  
**Type**: Standalone Enhancement  
**Depends on**: nothing (can be implemented before, during, or after Epic 5)  
**Affected file**: `lib/claude_client.rb`  

---

## 1. Summary

Enable Anthropic prompt caching for direct-provider Claude requests by making `ClaudeClient` pass through `cache_control` annotations from the client and surface cache usage metrics in the response. Today, `ClaudeClient#map_to_claude` silently strips `cache_control` from both the top-level request and individual content blocks, and `map_from_claude` discards the cache-related usage fields Anthropic returns.

This is a **low-risk, additive change** — requests without `cache_control` behave identically to today.

---

## 2. Background

Anthropic prompt caching reduces cost and latency by allowing the API to reuse a KV-cache of previously seen prompt prefixes. Savings appear in `usage.cache_read_input_tokens` on the response. Two modes exist:

### 2.1 Automatic Caching

A single top-level `cache_control` field on the request body. Anthropic automatically places the cache breakpoint at the last cacheable block and advances it as conversations grow.

```json
{
  "model": "claude-sonnet-4.5",
  "cache_control": { "type": "ephemeral" },
  "system": "You are a helpful assistant.",
  "messages": [
    { "role": "user", "content": "Hello" }
  ]
}
```

### 2.2 Explicit Cache Breakpoints

`cache_control` placed directly on individual content blocks (up to 4 breakpoints). Useful when different sections change at different frequencies.

```json
{
  "model": "claude-sonnet-4.5",
  "messages": [
    {
      "role": "system",
      "content": [
        { "type": "text", "text": "You are an expert." },
        { "type": "text", "text": "[LARGE REFERENCE — 10k tokens]", "cache_control": { "type": "ephemeral" } }
      ]
    },
    { "role": "user", "content": "Summarise key themes." }
  ]
}
```

### 2.3 Cache TTL Options

| TTL | Write cost | Read cost | Use case |
|-----|-----------|-----------|----------|
| 5 min (default) | 1.25× base input | 0.1× base input | Frequent requests (< 5 min apart) |
| 1 hour | 2× base input | 0.1× base input | Agentic workflows, slower conversations |

Specified via `"cache_control": { "type": "ephemeral", "ttl": "1h" }`.

### 2.4 Minimum Cacheable Tokens

| Model | Minimum tokens |
|-------|---------------|
| Claude Opus 4.6 / 4.5 | 4096 |
| Claude Sonnet 4.6 | 2048 |
| Claude Sonnet 4.5 / 4 / Opus 4.1 / 4 | 1024 |
| Claude Haiku 4.5 | 4096 |
| Claude Haiku 3.5 / 3 | 2048 |

Prompts below the threshold are processed normally without caching (no error).

---

## 3. Current Problems in `ClaudeClient`

### 3.1 System prompt flattened to string — `cache_control` lost

`map_to_claude` (line 137–229) extracts system messages with:

```ruby
system_parts << content.to_s
```

This converts structured content blocks (arrays with `cache_control`) to flat strings, discarding all annotations. The final payload uses:

```ruby
system: system_text.empty? ? nil : system_text  # plain string
```

Anthropic's Messages API accepts `system` as either a string or an array of content blocks. The current string form prevents caching.

### 3.2 Top-level `cache_control` not forwarded

The Claude payload hash (line 221–229) does not include `cache_control`. A client sending automatic caching has no effect.

### 3.3 Message content blocks lose `cache_control`

`normalize_content_for_claude` (line 95–111) converts string content to `[{ type: 'text', text: ... }]` blocks but does not preserve `cache_control` if the caller sent structured blocks with annotations. Additionally, the block filtering logic can strip blocks that carry only `cache_control` with no visible text.

### 3.4 Cache usage fields discarded in response

`map_from_claude` (line 277–282) maps only `input_tokens` and `output_tokens`. Anthropic returns:

```json
{
  "usage": {
    "input_tokens": 50,
    "output_tokens": 200,
    "cache_creation_input_tokens": 4000,
    "cache_read_input_tokens": 8000
  }
}
```

The `cache_creation_input_tokens` and `cache_read_input_tokens` fields are silently dropped — clients cannot verify caching is working.

---

## 4. Required Changes

### 4.1 System prompt: string → array-of-blocks

Refactor `map_to_claude` to preserve structured system content blocks including `cache_control`:

```ruby
# Replace the current system_parts accumulation:
messages.each do |m|
  role = hget(m, 'role').to_s
  content = hget(m, 'content')

  if role == 'system' || role == 'developer'
    if content.is_a?(Array)
      # Structured blocks — preserve cache_control and all attributes
      content.each do |block|
        if block.is_a?(Hash)
          system_parts << block
        elsif block.to_s.strip.present?
          system_parts << { 'type' => 'text', 'text' => block.to_s }
        end
      end
    elsif content.to_s.strip.present?
      system_parts << { 'type' => 'text', 'text' => content.to_s }
    end
    next
  end
  # ... rest of message handling unchanged
end
```

And in the payload construction:

```ruby
{
  model: model,
  messages: other_messages,
  max_tokens: hget(payload, 'max_tokens') || 4096,
  system: system_parts.empty? ? nil : system_parts,  # array of blocks, not string
  cache_control: hget(payload, 'cache_control'),       # top-level passthrough (§4.2)
  temperature: hget(payload, 'temperature'),
  stream: hget(payload, 'stream') || false,
  tools: map_tools_to_claude(hget(payload, 'tools'))
}.compact
```

**Backward compatibility**: When no `cache_control` is present, system blocks are plain `{ type: 'text', text: '...' }` arrays — Anthropic accepts this identically to a flat string. No behavioral change for existing callers.

### 4.2 Top-level `cache_control` passthrough

Add `cache_control` to the Claude payload hash (shown above). The `.compact` call ensures it is omitted when not provided.

### 4.3 Preserve `cache_control` on message content blocks

Update `normalize_content_for_claude` to preserve `cache_control` and other non-text attributes on content blocks:

```ruby
def normalize_content_for_claude(content)
  return nil if content.nil?

  if content.is_a?(Array)
    filtered = content.reject do |block|
      block.nil? ||
        (block.is_a?(Hash) &&
         block['type'] == 'text' &&
         block['text'].to_s.strip.empty? &&
         !block.key?('cache_control'))  # keep blocks that carry cache_control even if text is empty
    end
    return nil if filtered.empty?
    return filtered  # preserve all Hash keys including cache_control
  end

  text = content.to_s
  return nil if text.strip.empty?

  [{ type: 'text', text: text }]
end
```

### 4.4 Surface cache usage in response

Update `map_from_claude` to include cache metrics in the OpenAI-format usage block:

```ruby
def map_from_claude(body, original_payload)
  # ... existing content/tool_calls mapping unchanged ...

  cache_read    = body.dig('usage', 'cache_read_input_tokens')
  cache_creation = body.dig('usage', 'cache_creation_input_tokens')

  usage = {
    'prompt_tokens'     => body.dig('usage', 'input_tokens'),
    'completion_tokens' => body.dig('usage', 'output_tokens'),
    'total_tokens'      => body.dig('usage', 'input_tokens').to_i + body.dig('usage', 'output_tokens').to_i
  }

  # Surface cache metrics in OpenAI-compatible prompt_tokens_details
  cache_details = {}
  cache_details['cached_tokens']         = cache_read     if cache_read
  cache_details['cache_creation_tokens'] = cache_creation  if cache_creation
  usage['prompt_tokens_details'] = cache_details unless cache_details.empty?

  {
    'id' => body['id'],
    'object' => 'chat.completion',
    'created' => Time.now.to_i,
    'model' => body['model'],
    'choices' => [
      {
        'index' => 0,
        'message' => {
          'role' => 'assistant',
          'content' => text_content.empty? ? nil : text_content,
          'tool_calls' => tool_calls.empty? ? nil : tool_calls
        }.compact,
        'finish_reason' => map_finish_reason(body['stop_reason'])
      }
    ],
    'usage' => usage
  }
end
```

### 4.5 ResponseTransformer — do not strip `prompt_tokens_details`

`ResponseTransformer` does not modify `usage` fields — no change needed. The cache metrics pass through to the client automatically.

---

## 5. What Does NOT Change

| Aspect | Why |
|--------|-----|
| **Request routing** | Cache control is a payload annotation, not a routing decision |
| **ToolOrchestrator** | Tool loop payloads are built from `current_payload.dup` — `cache_control` propagates automatically |
| **Streaming** | `cache_control` affects the upstream request only; SSE conversion is response-side |
| **Other providers** | Grok, DeepSeek, Fireworks, Ollama, OpenRouter are unaffected |
| **`app.rb`** | No changes — payload passes through untouched |

---

## 6. ENV Variables

None. Prompt caching is controlled entirely by the client's request payload — no SmartProxy configuration needed. Operators do not need to opt in or out.

---

## 7. Developer Guide

### 7.1 Automatic Caching (Recommended)

Add `cache_control` at the top level. Anthropic automatically caches the longest reusable prefix and advances the breakpoint as conversations grow. Best for multi-turn conversations.

```json
{
  "model": "claude-sonnet-4.5",
  "cache_control": { "type": "ephemeral" },
  "max_tokens": 4096,
  "messages": [
    { "role": "system", "content": "You are an expert. Reference: [LARGE CONTEXT]" },
    { "role": "user", "content": "What caused the fall?" }
  ]
}
```

For slower conversations (> 5 min between turns), use the 1-hour TTL:
```json
"cache_control": { "type": "ephemeral", "ttl": "1h" }
```

### 7.2 Explicit Breakpoints (Fine-Grained Control)

Place `cache_control` on specific content blocks. Up to 4 breakpoints allowed. Useful when system prompts are static but user context changes.

```json
{
  "model": "claude-sonnet-4.5",
  "max_tokens": 4096,
  "messages": [
    {
      "role": "system",
      "content": [
        { "type": "text", "text": "You are a historian." },
        {
          "type": "text",
          "text": "[LARGE REFERENCE DOCUMENT — 10,000+ tokens]",
          "cache_control": { "type": "ephemeral" }
        }
      ]
    },
    { "role": "user", "content": "Summarise the key themes." }
  ]
}
```

### 7.3 Combining Both Modes

Use explicit breakpoints on stable content (system prompt, tools) and automatic caching on the growing conversation:

```json
{
  "model": "claude-sonnet-4.5",
  "cache_control": { "type": "ephemeral" },
  "max_tokens": 4096,
  "messages": [
    {
      "role": "system",
      "content": [
        {
          "type": "text",
          "text": "You are a helpful assistant.",
          "cache_control": { "type": "ephemeral" }
        }
      ]
    },
    { "role": "user", "content": "First question..." },
    { "role": "assistant", "content": "First answer..." },
    { "role": "user", "content": "Follow-up question" }
  ]
}
```

### 7.4 Verifying Cache Hits

Check `usage.prompt_tokens_details` in the response:

```json
{
  "usage": {
    "prompt_tokens": 50,
    "completion_tokens": 200,
    "total_tokens": 250,
    "prompt_tokens_details": {
      "cached_tokens": 8000,
      "cache_creation_tokens": 0
    }
  }
}
```

- `cached_tokens > 0` → cache hit (90% cost savings on those tokens)
- `cache_creation_tokens > 0` → new cache entry written (25% surcharge on those tokens)
- Both zero or absent → prompt too short or cache expired

### 7.5 Cost Implications

| Scenario | Cost vs. no caching |
|----------|-------------------|
| First request (cache write, 5m TTL) | +25% on cached input tokens |
| First request (cache write, 1h TTL) | +100% on cached input tokens |
| Subsequent requests (cache hit) | −90% on cached input tokens |
| Break-even (5m TTL) | 2nd request |
| Break-even (1h TTL) | 3rd request |

Prompt caching is cost-effective for any conversation that has ≥ 2 turns with a shared prefix above the minimum token threshold.

### 7.6 Minimum Token Thresholds

Prompts below the model's minimum cacheable token count are processed normally (no error, no caching). See §2.4 for per-model thresholds. Most practical use cases (system prompt + context document) easily exceed these minimums.

---

## 8. Testing Requirements

### `spec/lib/claude_client_spec.rb` (update)

| Test | Description |
|------|-------------|
| T1 | `map_to_claude` with top-level `cache_control` includes it in the Claude payload |
| T2 | `map_to_claude` without `cache_control` does not include it (backward compat) |
| T3 | System message as array-of-blocks with `cache_control` preserved in Claude payload `system` field |
| T4 | System message as plain string still works (converted to array-of-blocks, no `cache_control`) |
| T5 | Mixed system messages: some with `cache_control`, some without — all blocks preserved in order |
| T6 | User message content blocks with `cache_control` preserved through `normalize_content_for_claude` |
| T7 | `map_from_claude` with `cache_read_input_tokens` surfaces as `usage.prompt_tokens_details.cached_tokens` |
| T8 | `map_from_claude` with `cache_creation_input_tokens` surfaces as `usage.prompt_tokens_details.cache_creation_tokens` |
| T9 | `map_from_claude` without cache fields omits `prompt_tokens_details` entirely (backward compat) |
| T10 | Round-trip: request with `cache_control` → VCR cassette → response includes `prompt_tokens_details` |
| T11 | `cache_control` with `ttl: "1h"` passes through without modification |
| T12 | Content block with `cache_control` but empty text is preserved (not filtered out) |

---

## 9. Acceptance Criteria

- [ ] Request with top-level `cache_control: { type: "ephemeral" }` forwards it to Anthropic API
- [ ] Request with `cache_control` on system content blocks preserves them in the Claude `system` array
- [ ] Request with `cache_control` on user/assistant content blocks preserves them in `messages`
- [ ] Request without any `cache_control` behaves identically to today (no behavioral change)
- [ ] System prompt sent as plain string still works (backward compatible)
- [ ] Response `usage` includes `prompt_tokens_details.cached_tokens` when Anthropic returns `cache_read_input_tokens`
- [ ] Response `usage` includes `prompt_tokens_details.cache_creation_tokens` when Anthropic returns `cache_creation_input_tokens`
- [ ] Response `usage` omits `prompt_tokens_details` when no cache fields present (backward compat)
- [ ] `cache_control` with `ttl: "1h"` passes through without modification
- [ ] ToolOrchestrator tool-loop requests preserve `cache_control` from the original payload
- [ ] No new ENV variables or configuration required
- [ ] All existing `ClaudeClient` tests continue to pass
- [ ] All 12 new tests pass

---

## 10. Estimation

| Dimension | Value |
|-----------|-------|
| **Files touched** | 1 production (`lib/claude_client.rb`) + 1 test |
| **Lines changed** | ~35 production, ~60 test |
| **Risk** | Low — additive, backward compatible |
| **Breaking changes** | None |
| **New dependencies** | None |
| **Estimated effort** | 2–4 hours |
