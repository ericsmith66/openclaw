# QA Agent — Test Writing Rules

## 1. Write Complete Test Files in One Shot
- **Write the entire test file in a single `power---file_write` call** with mode `overwrite` (or `create_only` for new files).
- **NEVER build test files incrementally** via multiple `append` calls. Each tool call costs a full LLM turn. Plan the complete file content, then write it all at once.
- If updating an existing test file, read it once, then write the full updated version via `overwrite`.

## 2. Activate Testing Skills First
- **Before writing any test code, activate the relevant testing skill.** Call `skills---activate_skill` with the appropriate skill name:
  - For RSpec tests: activate "Rails Minitest + VCR" (it contains patterns applicable to both frameworks)
  - For system tests: activate "Rails Capybara System Testing"
  - For service tests: activate "Rails Service Patterns"
- The skill provides tested patterns and templates that reduce iteration cycles.

## 3. Minimize Pre-Write Reading
- **Read at most 3 files before writing tests:**
  1. The source file you're testing (to understand the API)
  2. An existing spec file in the same directory (to match conventions)
  3. One helper/support file if needed (e.g., spec_helper.rb, VCR config)
- **Do NOT grep/glob the entire project** looking for patterns. The task prompt and the source file give you everything you need.

## 4. Fast Red-Green Cycles
- After writing tests, **run them immediately** — don't read more files or do syntax checks first.
- If tests fail, read the failure output carefully, fix the specific issue, re-run. Each cycle should be 1-2 turns.
- **Run only your test file first**, not the entire suite. Run the full suite as the final verification step.
