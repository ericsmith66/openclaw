# Epic 1 — PRD 1-09/1-10 Code Improvements Tracker

Tracked improvements identified from real-world execution of SmartProxy Epic 5.
Rule changes are implemented immediately; code changes are deferred to PRD 1-09/1-10.

---

## Implemented (Rule Changes — Active Now)

### R-1: Efficient Tool Usage Rules (global)
**File:** `.aider-desk/rules/efficient-tool-usage.md`
- Read before edit
- Prefer overwrite over append
- Never use Python/sed/Ruby one-liners for edits
- Never debug encoding (hexdump, cat -A)
- Limit exploration to 3-5 files before first write
- Don't re-read pre-loaded reference files
- Run tests early, fast red-green cycles (1-3 turns)
- Stop when tests pass — no verification loops
- No diagnostic bash commands (echo test, pwd)

### R-2: QA Test Writing Rules (agent-specific)
**File:** `.aider-desk/agents/ror-qa-legion/rules/qa-test-writing.md`
- Write complete test files in one shot (no append)
- Activate testing skills before writing tests
- Minimize pre-write reading (max 3 files)
- Fast red-green cycles

### R-3: Decomposition — One Test File Per Task
**File:** `app/services/legion/prompts/decomposition_prompt.md.erb`
- Never combine test-writing for multiple source files into one task

### R-4: Context Injection in Task Prompts
**File:** `app/services/legion/plan_execution_service.rb`
- `enrich_prompt_with_file_context` auto-detects backtick-quoted file paths in task prompts
- Reads and appends file contents (max 5 files, 50KB each)
- Eliminates agent turns spent reading files the prompt already references

---

## Deferred (Code Changes — Target PRD 1-09/1-10)

### C-1: Gem Runner Early Termination
**Problem:** DeepSeek Reasoner hits maxIterations (20) even when tests pass on turn 1. WR#59 consumed 285K tokens for zero productive work after green tests.
**Fix:** Add task completion detection to gem Runner — if the LLM's last response contains no tool calls and tests are green, stop the loop.
**Location:** `gems/agent_desk/lib/agent_desk/agent/runner.rb`
**Effort:** Medium
**Impact:** ~30% token savings on Rails Lead runs

### C-2: Failed Edit Auto-Recovery in PowerTools
**Problem:** `file_edit` "Search term not found" wastes 2-3 turns per failure (18 failures across PRDs 5-1 to 5-3). Agents fall back to Python scripts or hexdump diagnostics.
**Fix:** When `file_edit` fails, automatically return the first 200 chars around the best fuzzy match, or return the full file content if small (<100 lines). This gives the agent enough context to fix the search term on the next try.
**Location:** `gems/agent_desk/lib/agent_desk/tools/power_tools.rb`
**Effort:** Low-Medium
**Impact:** Eliminates ~80% of edit failure recovery cycles

### C-3: SmartProxy Prompt Caching
**Problem:** No prompt caching on SmartProxy — every turn re-sends full context at full price. WR#56 consumed 1.8M prompt tokens (24.9K/turn avg) for a single test file.
**Fix:** Eric is writing a SmartProxy PRD for Claude prompt caching support.
**Location:** SmartProxy (external project)
**Effort:** Medium (SmartProxy PRD)
**Impact:** 70-80% token cost reduction on Claude runs

### C-4: Parallel Task Execution via Solid Queue
**Problem:** All tasks execute sequentially. Tasks 1+2 (independent test tasks) could run simultaneously.
**Fix:** Dispatch all ready tasks concurrently using Solid Queue.
**Location:** `app/services/legion/plan_execution_service.rb`, new `app/jobs/`
**Effort:** High (Epic 2 scope)
**Impact:** ~40% wall-clock time reduction for plans with parallel-eligible tasks

### C-5: `bin/legion score` Command
**Problem:** No CLI command to dispatch QA agent for scoring. Currently done manually in AiderDesk.
**Fix:** `bin/legion score --team ROR --prd <path> [--workflow-run <id>]` — dispatches QA agent with scoring rubric prompt, parses score, stores result.
**Location:** `bin/legion`, new service class
**Effort:** Medium
**Impact:** Enables automated quality gates in Epic 2
