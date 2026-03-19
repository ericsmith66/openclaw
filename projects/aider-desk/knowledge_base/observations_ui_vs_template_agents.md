### Observations: UI-Created Agents vs Template Agents

**Date**: 2026-02-17
**Context**: Agents created through the AiderDesk UI work correctly. Template agents from `knowledge_base/aider-desk/configs/` exhibit issues. This document compares the two to identify the structural differences.

---

#### 1. Field Inventory Comparison

| Field | UI-Created Agent | Template Agent | Impact |
|---|---|---|---|
| `id` | ✅ Present | ✅ Present | — |
| `name` | ✅ Present | ✅ Present | — |
| `provider` | ✅ `"anthropic"` | ⚠️ `"ollama"` | Different but valid |
| `model` | ✅ Full model string | ⚠️ `"qwen3-coder-next:latest"` | Different but valid |
| `maxIterations` | ✅ `250` | ⚠️ `20` | Templates use very low value |
| `minTimeBetweenToolCalls` | ✅ `0` | ❌ **Missing** | Defaults to `0` via sanitizer — OK |
| **`toolApprovals`** | ✅ **Full map (25 entries)** | ❌ **Missing entirely** | **CRITICAL** — see §2 |
| **`toolSettings`** | ✅ **Bash allow/deny patterns** | ❌ **Missing entirely** | **CRITICAL** — see §2 |
| **`includeContextFiles`** | ✅ `false` | ❌ **Missing** | Defaults via spread — see §3 |
| **`includeRepoMap`** | ✅ `true` or `false` | ❌ **Missing** | Defaults via spread — see §3 |
| **`usePowerTools`** | ✅ Explicit `true`/`false` | ❌ **Missing** | Defaults to `true` — see §3 |
| **`useAiderTools`** | ✅ Explicit `true`/`false` | ⚠️ Only in `ror-rails` (`true`) | Defaults to `false` — **agents can't use Aider** |
| **`useTodoTools`** | ✅ `true` | ❌ **Missing** | Defaults to `true` — OK |
| **`useSubagents`** | ✅ Explicit `true`/`false` | ❌ **Missing** | Defaults to `true` — OK |
| **`useTaskTools`** | ✅ `false` | ❌ **Missing** | Defaults to `false` — OK |
| **`useMemoryTools`** | ✅ `true` | ❌ **Missing** | Defaults to `true` — OK |
| **`useSkillsTools`** | ✅ `true` | ❌ **Missing** | Defaults to `true` — OK |
| `customInstructions` | ✅ `""` | ❌ **Missing** | Defaults to `""` — OK |
| `enabledServers` | ✅ `[]` | ❌ **Missing** | Defaults to `[]` — OK |
| `subagent` | ✅ Full object (7 fields) | ✅ Present (5-6 fields) | Merged with defaults — OK |
| `subagent.description` | ✅ Present | ❌ **Missing** | Defaults to `""` — agent has no description in UI |
| `subagent.contextMemory` | ✅ `"off"` | ✅ `"full-context"` | Different but intentional |

---

#### 2. CRITICAL: Missing `toolApprovals` and `toolSettings`

**This is the most significant difference.**

UI-created agents have a complete `toolApprovals` map with 25 entries specifying exactly which tools require approval (`"ask"`), are auto-approved (`"always"`), or are blocked (`"never"`).

Template agents have **no `toolApprovals` at all**. The sanitizer does:
```typescript
toolApprovals: {
  ...loadedProfile.toolApprovals,  // spreads undefined → empty object
},
```

**Result**: Template agents load with an **empty `toolApprovals` object `{}`**. This means:
- The app has **no explicit approval rules** for any tool
- Behavior depends on how the app handles a missing key in `toolApprovals` — it may default to `"ask"` for everything (causing the "hang" issue) or `"never"` (blocking all tools)
- Either way, the agent cannot function as intended

**Fix needed**: Templates must include a full `toolApprovals` map, or the sanitizer must merge with `DEFAULT_AGENT_PROFILE.toolApprovals` instead of spreading an empty object.

Similarly, `toolSettings` (bash allow/deny patterns) is missing, so template agents have no bash safety guardrails.

---

#### 3. CRITICAL: Missing Boolean Feature Flags

The sanitizer uses the **spread operator** (`...profileWithoutProjectDir`) to carry forward any fields from the loaded profile. For missing boolean fields, this means `undefined` is spread, and **no explicit default is applied**.

The sanitizer does NOT explicitly default these fields:
- `includeContextFiles` — remains `undefined`
- `includeRepoMap` — remains `undefined`
- `usePowerTools` — remains `undefined`
- `useAiderTools` — remains `undefined` (except `ror-rails` which sets it to `true`)
- `useTodoTools` — remains `undefined`
- `useSubagents` — remains `undefined`
- `useTaskTools` — remains `undefined`
- `useMemoryTools` — remains `undefined`
- `useSkillsTools` — remains `undefined`

**Result**: These fields are `undefined` at runtime. Whether the app treats `undefined` as `true` or `false` depends on each consumer's truthiness check:
- `if (profile.useAiderTools)` → `undefined` is falsy → **Aider tools disabled**
- `if (profile.useAiderTools !== false)` → `undefined` is not `false` → **Aider tools enabled**

This is **unpredictable** and varies by call site. The UI-created agents avoid this entirely by always writing explicit `true`/`false` values.

---

#### 4. Minor Differences

| Issue | Severity | Notes |
|---|---|---|
| `subagent.description` missing in templates | Low | Agent shows blank description in UI |
| `maxIterations: 20` in templates vs `250` in UI | Medium | Templates may terminate prematurely on complex tasks |
| `provider: "ollama"` in templates | Info | Templates target local models; UI agents target Anthropic |

---

#### 5. Root Cause Summary

The templates were authored as **minimal configs** — only the fields the author considered important. The UI, by contrast, writes **complete configs** with every field explicitly set. The sanitizer (`sanitizeAgentProfile`) was designed to fill in some defaults but **does not cover all fields**:

| Field Category | Sanitizer Handles? | Template Impact |
|---|---|---|
| `id`, `name`, `provider`, `model` | ✅ Yes | OK |
| `maxIterations`, `minTimeBetweenToolCalls` | ✅ Yes (via `??`) | OK |
| `enabledServers`, `customInstructions` | ✅ Yes (via `??`) | OK |
| `subagent` | ✅ Yes (merged with defaults) | OK |
| **`toolApprovals`** | ❌ **No** — spreads as-is | **BROKEN** |
| **`toolSettings`** | ❌ **No** — spreads as-is | **BROKEN** |
| **Boolean flags** (`useAiderTools`, etc.) | ❌ **No** — not defaulted | **UNPREDICTABLE** |

---

#### 6. Recommended Fixes

##### Fix A: Update the Sanitizer (code change)
Modify `sanitizeAgentProfile()` to merge `toolApprovals` and `toolSettings` with defaults, and explicitly default all boolean flags:

```typescript
toolApprovals: {
  ...DEFAULT_AGENT_PROFILE.toolApprovals,   // defaults first
  ...loadedProfile.toolApprovals,            // template overrides
},
toolSettings: {
  ...DEFAULT_AGENT_PROFILE.toolSettings,
  ...loadedProfile.toolSettings,
},
includeContextFiles: loadedProfile.includeContextFiles ?? DEFAULT_AGENT_PROFILE.includeContextFiles,
includeRepoMap: loadedProfile.includeRepoMap ?? DEFAULT_AGENT_PROFILE.includeRepoMap,
usePowerTools: loadedProfile.usePowerTools ?? DEFAULT_AGENT_PROFILE.usePowerTools,
useAiderTools: loadedProfile.useAiderTools ?? DEFAULT_AGENT_PROFILE.useAiderTools,
// ... etc for all boolean flags
```

##### Fix B: Update the Templates (data change)
Add the full set of fields to every template `config.json` so they match the UI-created format. This is more verbose but eliminates any dependency on sanitizer behavior.

##### Recommendation
**Do both.** Fix A makes the system robust against minimal configs. Fix B makes the templates explicit and self-documenting. Fix A is the higher priority because it protects against any future minimal config.
