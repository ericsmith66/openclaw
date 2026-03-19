# PRD 5.1 — `ModelFilter`: Shared Regex Filter Pipeline

**Status**: Ready for Implementation  
**Epic**: 5 — Unified Live Model Discovery  
**Depends on**: nothing  
**Required by**: PRD-5.2, PRD-5.3, PRD-5.4  

---

## 1. Summary

Create `lib/model_filter.rb` — a single, stateless class that applies a consistent filter pipeline to any array of OpenAI-format model hashes. All providers will pass their live-fetched lists through this class before returning to `ModelAggregator`.

---

## 2. Filter Pipeline (in order)

| Step | Name | Description | ENV Control |
|------|------|-------------|-------------|
| 1 | **Text output guard** | Discard models where `modalities` (if present) does not include `"text"` | Always on |
| 2 | **Tools guard** | Discard models where `supported_parameters` (if present) does not include `"tools"` | `MODELS_REQUIRE_TOOLS=true` (default: false) |
| 3 | **Blacklist** | Discard models whose `id` matches any pattern in the blacklist | `MODELS_BLACKLIST` (global) and/or `<PROVIDER>_MODELS_BLACKLIST` (per-provider) |
| 4 | **Include override** | Force-include models whose `id` matches any include pattern, even if blacklisted | `MODELS_INCLUDE` (global) and/or `<PROVIDER>_MODELS_INCLUDE` (per-provider) |
| 5 | **Synthetic decoration** | Append `-with-live-search` variants for models whose `id` matches `WITH_LIVE_SEARCH_MODELS` | `WITH_LIVE_SEARCH_MODELS` regex (default: `^claude-`) |

Steps 3 and 4 support **both** a global ENV and a per-provider ENV. Per-provider overrides **add to** (not replace) global patterns. This allows `MODELS_BLACKLIST=image-gen` globally while `OPENROUTER_MODELS_BLACKLIST=openai/` further restricts OpenRouter specifically.

---

## 3. Class Interface

```ruby
# lib/model_filter.rb

class ModelFilter
  # provider: symbol e.g. :openrouter, :grok, :claude — used to resolve
  #           per-provider ENV overrides
  def initialize(provider:, env: ENV)

  # models: Array<Hash> — OpenAI-format model hashes with at minimum { id: }
  # Returns filtered (and decorated) Array<Hash>
  def apply(models)
end
```

### 3.1 ENV Variable Resolution

```ruby
def blacklist_patterns(provider)
  global   = parse_patterns(env['MODELS_BLACKLIST'])
  specific = parse_patterns(env["#{provider.upcase}_MODELS_BLACKLIST"])
  global + specific
end

def include_patterns(provider)
  global   = parse_patterns(env['MODELS_INCLUDE'])
  specific = parse_patterns(env["#{provider.upcase}_MODELS_INCLUDE"])
  global + specific
end

# parse_patterns: split on comma, strip whitespace, compile each as Regexp
def parse_patterns(str)
  return [] if str.to_s.empty?
  str.split(',').map(&:strip).reject(&:empty?).map { |p| Regexp.new(p, Regexp::IGNORECASE) }
end
```

### 3.2 Filter Logic Pseudocode

```ruby
def apply(models)
  blacklist = blacklist_patterns(@provider)
  includes  = include_patterns(@provider)
  tools_req = require_tools?
  ls_regex  = live_search_regex

  result = models.select do |m|
    id = m[:id] || m['id']

    # Step 1: text output
    next false unless text_capable?(m)

    # Step 2: tools guard (only if MODELS_REQUIRE_TOOLS=true)
    next false if tools_req && !tools_capable?(m)

    # Step 3+4: blacklist unless rescued by include
    if blacklist.any? { |re| re.match?(id) }
      next includes.any? { |re| re.match?(id) }
    end

    true
  end

  # Step 5: synthetic decoration
  result + live_search_variants(result, ls_regex)
end
```

### 3.3 Synthetic Decoration

```ruby
def live_search_variants(models, regex)
  return [] unless regex
  models.select { |m| regex.match?(m[:id] || m['id']) }.map do |m|
    m.merge(
      id: "#{m[:id] || m['id']}-with-live-search",
      smart_proxy: (m[:smart_proxy] || {}).merge(features: %w[live-search tools])
    )
  end
end
```

`WITH_LIVE_SEARCH_MODELS` defaults to `^claude-`. Set to empty string to disable.

---

## 4. ENV Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODELS_BLACKLIST` | _(empty)_ | Comma-separated regex patterns — global blacklist across all providers |
| `MODELS_INCLUDE` | _(empty)_ | Comma-separated regex patterns — force-include even if blacklisted |
| `MODELS_REQUIRE_TOOLS` | `false` | If `true`, discard models without `tools` in `supported_parameters` |
| `WITH_LIVE_SEARCH_MODELS` | `^claude-` | Regex for models that should get a `-with-live-search` synthetic variant |
| `<PROVIDER>_MODELS_BLACKLIST` | _(empty)_ | Per-provider blacklist (additive to global). E.g. `OPENROUTER_MODELS_BLACKLIST` |
| `<PROVIDER>_MODELS_INCLUDE` | _(empty)_ | Per-provider include override (additive to global) |

---

## 5. Testing Requirements

### `spec/lib/model_filter_spec.rb` (new file)

| Test | Description |
|------|-------------|
| T1 | Models with no modalities field pass text guard |
| T2 | Models with `modalities: ['text']` pass text guard |
| T3 | Models with `modalities: ['image']` only are rejected by text guard |
| T4 | Tools guard off by default — models without `supported_parameters` pass |
| T5 | Tools guard on (`MODELS_REQUIRE_TOOLS=true`) — models without `tools` are rejected |
| T6 | Tools guard on — models with `tools` in `supported_parameters` pass |
| T7 | Blacklist regex matches by partial ID |
| T8 | Blacklist regex is case-insensitive |
| T9 | Include override rescues a blacklisted model |
| T10 | Per-provider blacklist adds to global blacklist |
| T11 | `WITH_LIVE_SEARCH_MODELS=^claude-` creates `-with-live-search` variants for claude models |
| T12 | `-with-live-search` variants include `features: ['live-search', 'tools']` in `smart_proxy` |
| T13 | Non-matching models do not get `-with-live-search` variants |
| T14 | Empty model list returns empty list without error |
| T15 | `parse_patterns` with empty/nil string returns `[]` |

---

## 6. Acceptance Criteria

- [ ] `ModelFilter.new(provider: :openrouter).apply(models)` correctly filters a list of 500 OpenRouter models
- [ ] Blacklist `MODELS_BLACKLIST=^openai/` removes all `openai/*` models
- [ ] Include `MODELS_INCLUDE=openai/gpt-4o` rescues `openai/gpt-4o` despite the blacklist above
- [ ] `WITH_LIVE_SEARCH_MODELS=^claude-` results in one extra `*-with-live-search` entry per Claude model
- [ ] No filtering code remains in `ModelAggregator` or any provider client
- [ ] All 15 unit tests pass
