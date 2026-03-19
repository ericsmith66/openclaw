# PRD-1.5-02 — Team Configurations

**PRD ID:** PRD-1.5-02
**Epic:** Epic 1.5 — LLM Benchmark
**Status:** Draft
**Created:** 2026-03-07
**Depends On:** PRD-1.5-01
**Blocks:** PRD-1.5-03, PRD-1.5-04

---

## User Story

As a benchmark operator, I want pre-configured team profiles for three LLM tiers (Ollama-cheap, budget-cloud, frontier) so that I can run the same Epic 4C spec against each tier and compare results objectively.

---

## Acceptance Criteria

1. Three team config sets exist under `legion-test/.aider-desk/`:
   - `teams/team-c-ollama/` — all-local config
   - `teams/team-b-budget/` — budget cloud escalation config
   - `teams/team-a-frontier/` — frontier config (reference/fallback)
2. Each team config set contains 4 agent configs (rails-lead, architect, qa, debug) with identical structure to Legion's `.aider-desk/agents/`
3. All agent configs share identical `toolApprovals`, `toolSettings`, `subagent` prompts, `customInstructions`, and `use*` flags — copied from Legion's production configs
4. ONLY `provider` and `model` fields differ between teams
5. Architect agent config is identical across all teams: `"provider": "deepseek", "model": "deepseek-chat"`
6. QA model verified: `ollama run qwen3:32b "ping"` responds successfully (already installed)
7. SmartProxy routing verified: DeepSeek-Chat responds through SmartProxy endpoint
8. Ollama routing verified: `qwen3-coder-next`, `qwen3:32b` all respond through SmartProxy (or direct Ollama endpoint)
9. A `teams.md` file documents all three team configs with model assignments and rationale

---

## Team Configurations

### Team C — All-Ollama ($0.00)

| Role | Agent ID | Provider | Model | Already Installed |
|------|----------|----------|-------|-------------------|
| Coder | ror-rails-legion | ollama | qwen3-coder-next | ✅ Yes (51GB) |
| Architect | ror-architect-legion | deepseek | deepseek-chat | ✅ Remote |
| QA | ror-qa-legion | ollama | qwen3:32b | ✅ Yes (20GB) |
| Debug | ror-debug-legion | ollama | qwen3:32b | ✅ Yes (20GB) |

### Team B — Budget Cloud Escalation

| Role | Agent ID | Provider | Model | Notes |
|------|----------|----------|-------|-------|
| Coder | ror-rails-legion | deepseek | deepseek-chat | Cheapest competent cloud coder |
| Architect | ror-architect-legion | deepseek | deepseek-chat | Same as Team C |
| QA | ror-qa-legion | anthropic | claude-sonnet-4-6 | Thorough verification (if Qwen3:32b QA too shallow) |
| Debug | ror-debug-legion | deepseek | deepseek-chat | Cheap but effective |

### Team A — Frontier (Reference)

| Role | Agent ID | Provider | Model | Notes |
|------|----------|----------|-------|-------|
| Coder | ror-rails-legion | anthropic | claude-sonnet-4-6 | Proven on Legion Epic 1 |
| Architect | ror-architect-legion | deepseek | deepseek-chat | Same across all teams |
| QA | ror-qa-legion | anthropic | claude-sonnet-4-6 | Current Legion QA |
| Debug | ror-debug-legion | anthropic | claude-sonnet-4-6 | Current Legion Debug |

---

## Non-Functional Requirements

- Agent `customInstructions` must be copied verbatim from Legion — especially the DeepSeek "ZERO THINKING OUT LOUD" directive for reasoning models
- Qwen3-Coder-Next custom instructions may need a similar conciseness directive (test during smoke run)
- SmartProxy must be configured to route `ollama/*` model requests to local Ollama endpoint
- All configs must set `"projectDir"` to `/Users/ericsmith66/development/legion-test`

---

## Error Scenarios

| Scenario | Expected Behavior |
|----------|------------------|
| QA and Debug share same model (`qwen3:32b`) | Acceptable trade-off — both are already installed. Monitor for any confusion if both agents run concurrently. |
| SmartProxy can't route to Ollama | Verify SmartProxy config includes Ollama backend. Check `http://localhost:11434/api/tags`. |
| DeepSeek API rate-limited during decomposition | SmartProxy should handle retries. If persistent, switch Architect to Grok-latest. |
| Qwen3-Coder-Next too slow (< 10 tok/s) | Expected ~20-50 tok/s on M3 Ultra. If < 10, consider `qwen2.5-coder:32b` as substitute. |

---

## Setup Steps

1. Verify QA model: `ollama run qwen3:32b "Write a Ruby hello world"` → produces Ruby code (already installed)
2. (No pull needed — qwen3:32b already present)
3. Verify SmartProxy: `curl -H "Authorization: Bearer $SMART_PROXY_TOKEN" http://192.168.4.253:3001/v1/chat/completions -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"ping"}]}'` → response
4. Copy Legion's `.aider-desk/agents/` to `legion-test/.aider-desk/agents/`
5. Copy Legion's `.aider-desk/skills/` to `legion-test/.aider-desk/skills/`
6. Copy Legion's `.aider-desk/rules/` to `legion-test/.aider-desk/rules/`
7. For Team C: modify 4 agent `config.json` files with Ollama provider/model overrides
8. Store Team B and Team A configs as separate directories for quick swapping
9. Run `rake teams:import[~/.aider-desk]` in `legion-test`
10. Smoke test: `bin/legion execute --team ROR --agent rails-lead --prompt "Create a Ruby method that adds two numbers"` → verify Qwen3-Coder-Next responds

---

## Manual Testing Steps

1. `ollama list` → shows `qwen3:32b` in list
2. Compare `legion-test/.aider-desk/agents/ror-rails-legion/config.json` with Legion's → only `provider` and `model` differ
3. `bin/legion execute --team ROR --agent architect --prompt "ping"` → DeepSeek responds
4. `bin/legion execute --team ROR --agent rails-lead --prompt "ping"` → Qwen3-Coder responds
5. `bin/legion execute --team ROR --agent qa --prompt "ping"` → Qwen3:32b responds
6. `bin/legion execute --team ROR --agent debug --prompt "ping"` → Qwen3:32b responds
