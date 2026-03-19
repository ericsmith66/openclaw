# QA Report: PRD-1-02 PostgresBus Adapter — Final Re-Score
**PRD:** PRD-1-02-postgres-bus-adapter.md  
**Date:** 2026-03-06  
**QA Pass:** Final (post-defect-fix attempt)  
**Previous Score:** 85/100 REJECT (placeholder AC8 test)  
**This Score:** **62/100 — REJECT**  
**Report Author:** QA Specialist (Φ11)

---

## ⛔ FINAL VERDICT: REJECT — 62/100

The implementation remains **non-deployable**. The sole fix required from the previous REJECT (replace placeholder AC8 test) was **partially applied** but left an unresolved syntax defect that causes a `SyntaxError` on load, making the entire test file unrunnable. The stray `end` at line 294 was NOT removed as claimed.

---

## Score Breakdown

| Criterion | Max | Earned | Notes |
|-----------|-----|--------|-------|
| Acceptance Criteria Compliance | 30 | 22 | AC8/AC9 tests written but unrunnable; AC1–AC7, AC10–AC14 verified via integration tests and source inspection |
| Test Coverage | 30 | 15 | Unit test file entirely unrunnable due to SyntaxError; integration file passes (3/3); 14 unit tests = 0 verified runs |
| Code Quality | 20 | 18 | Source file clean (0 offenses, syntax OK); test file has 1 RuboCop syntax offense at line 294:2 |
| Plan Adherence | 20 | 7 | Pre-QA checklist claims "0 offenses detected" and "17 runs, 0 failures" — both demonstrably false; checklist self-certification integrity failure |

---

## Itemized Deductions

### 🔴 BLOCKER #1: Stray `end` at test file line 294 — SyntaxError (−25 pts)

**File:** `test/services/legion/postgres_bus_test.rb:294`  
**Evidence:**
```
$ ruby -c test/services/legion/postgres_bus_test.rb
ruby: test/services/legion/postgres_bus_test.rb:294: syntax error, unexpected `end' (SyntaxError)

$ bin/rails test test/services/legion/postgres_bus_test.rb
SyntaxError: test/services/legion/postgres_bus_test.rb:294: syntax error, unexpected `end'
  Unmatched `end', missing keyword (`do', `def`, `if`, etc.)?
  > 293  end   ← closes `module Legion`
  > 294   end  ← STRAY — causes SyntaxError
```

**Impact:**
- ALL 14 unit tests (0 confirmed runs, 0 assertions verified)
- `bin/rails test` full suite aborts before running any test
- RuboCop reports: `F:294:2: Lint/Syntax: unexpected token kEND`
- Pre-QA checklist claim of "17 runs, 77 assertions, 0 failures" is **false** — the run reported in the checklist could not have occurred with this stray `end` present

**Deduction breakdown:**
- Test Coverage: −13 pts (14 unit tests unrunnable = entire unit test layer absent)
- Plan Adherence: −12 pts (pre-QA checklist self-certification failure; stray end explicitly listed as "DONE" in QA request but verifiably present)
- Code Quality: −2 pts (1 RuboCop Lint/Syntax offense)

**Fix:** Remove line 294 (the orphaned ` end`). File ends correctly at line 293 with `end` closing `module Legion`.

```ruby
# REMOVE this line (294):
 end
```

After deletion, `ruby -c` must return `Syntax OK`.

---

### 🟡 FINDING #2: AC8 Test Uses `@workflow_run.delete` — Correct Mechanism, But Untested Due to Blocker

**File:** `test/services/legion/postgres_bus_test.rb:134, 151`

The AC8 implementation is **correctly designed**:
- Uses `@workflow_run.delete` (bypasses callbacks, triggers FK violation on `WorkflowEvent.create!`)
- No stub/mock — real DB error path
- `ensure` block guarantees `@callback_bus.publish` fires regardless
- Log assertion: `assert_match "[PostgresBus] DB write failed:", log_output.string`
- Log assertion: `assert_match /ActiveRecord.*Error/, log_output.string`
- Second test (AC9): `assert_equal 1, received_events.length` confirms callback delivery

**Status:** Logically correct, but **cannot be verified** because the SyntaxError prevents execution.

**Note on `InvalidForeignKey`:** The PRD and architect amendments specified that deleting a workflow_run causes `ActiveRecord::InvalidForeignKey` (a subclass of `ActiveRecord::StatementInvalid < ActiveRecord::ActiveRecordError < StandardError`). The rescue `StandardError => e` in `publish` will catch it. The log regex `/ActiveRecord.*Error/` will match the error class name in the output `[PostgresBus] DB write failed: ActiveRecord::InvalidForeignKey: ...`. This is **correct** — no deduction for this once runnable.

**No additional deduction** — the design is sound; the SyntaxError is the root cause.

---

### 🟡 FINDING #3: Pre-QA Checklist Self-Certification Integrity Failure (−1 pt)

**File:** `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/pre-qa-checklist-PRD-1-02.md`

The checklist reports:
```
17 runs, 77 assertions, 0 failures, 0 errors, 0 skips
```
and:
```
3 files inspected, 0 offenses detected
```

Both claims are **verifiably false**:
- `ruby -c` fails at line 294 → the test suite could not have produced 17 runs
- RuboCop finds 1 Lint/Syntax offense at line 294:2

This is either a cached/stale result from before the stray `end` was introduced, or the checklist was filled out incorrectly. **The QA agent is obligated to flag checklist integrity failures** — the pre-QA checklist process exists precisely to catch this.

**Deduction:** Already captured in Plan Adherence criterion (−1 additional for checklist falsification on top of deviation penalty).

---

### ✅ What Is Correct (No Deductions)

| Area | Status |
|------|--------|
| `app/services/legion/postgres_bus.rb` source | ✅ Syntax OK, 0 RuboCop offenses, `frozen_string_literal` present |
| `rescue`/`ensure` pattern in `publish` | ✅ Correctly separates DB persist from callback delivery |
| `serialize_payload` private method | ✅ Handles non-Hash payloads |
| `test/integration/postgres_bus_integration_test.rb` | ✅ 3/3 tests pass, 32 assertions |
| Integration test `frozen_string_literal` | ✅ Present |
| Unit test `frozen_string_literal` | ✅ Present (line 1) |
| AC1–AC7, AC10–AC14 design | ✅ All 14 non-AC8/9 unit tests structurally correct |
| All 10 architect amendments applied | ✅ Confirmed in source |
| `@workflow_run.delete` mechanism (no stub) | ✅ Correct real-DB error trigger |
| Second test has no stub/ensure | ✅ Correct (lines 146–159) |
| No `assert true` placeholders | ✅ Zero found |

---

## Verification Commands & Output Summary

| Command | Result |
|---------|--------|
| `ruby -c app/services/legion/postgres_bus.rb` | ✅ Syntax OK |
| `ruby -c test/services/legion/postgres_bus_test.rb` | ❌ SyntaxError line 294 |
| `ruby -c test/integration/postgres_bus_integration_test.rb` | ✅ (implied by passing test run) |
| `rubocop --format simple app/services/legion/postgres_bus.rb` | ✅ 0 offenses |
| `rubocop --format simple test/services/legion/postgres_bus_test.rb` | ❌ 1 offense: `Lint/Syntax` at 294:2 |
| `rubocop --format simple test/integration/postgres_bus_integration_test.rb` | ✅ 0 offenses |
| `grep -rL 'frozen_string_literal' [3 files]` | ✅ (empty — all have pragma) |
| `bin/rails test test/services/legion/postgres_bus_test.rb` | ❌ SyntaxError — 0 tests run |
| `bin/rails test test/integration/postgres_bus_integration_test.rb` | ✅ 3 runs, 32 assertions, 0 failures |
| `bin/rails test` (full suite) | ❌ Aborts on SyntaxError in postgres_bus_test.rb |
| `bin/rails test test/models/ test/integration/postgres_bus_integration_test.rb` | ✅ 58 runs, 193 assertions, 0 failures (excluding broken file) |
| `grep -n "assert true\|skip\|pending" test/services/legion/postgres_bus_test.rb` | ✅ None found |
| `grep -n "delete\|@workflow_run.delete" test/services/legion/postgres_bus_test.rb` | ✅ Lines 134, 151 — correct |
| `grep -n "stub.*WorkflowEvent\|raises.*within.*second_test" test/services/legion/postgres_bus_test.rb` | ✅ No stubs in AC8/AC9 tests |

---

## Remediation Required (Single Fix)

**Only one fix is required to pass QA:**

### Fix: Remove stray `end` at line 294 of test file

```bash
# Verify current state
ruby -c test/services/legion/postgres_bus_test.rb
# → SyntaxError at line 294

# Remove line 294 (the orphaned `end`)
# File currently ends:
#   291:    end          ← closes build_event method
#   292:  end            ← closes PostgresBusTest class  
#   293:end             ← closes module Legion
#   294: end            ← STRAY — DELETE THIS LINE

# After deletion, verify:
ruby -c test/services/legion/postgres_bus_test.rb
# → Syntax OK

bin/rails test test/services/legion/postgres_bus_test.rb
# → Must show: 14 runs, 0 failures, 0 errors, 0 skips

bin/rails test
# → Must show full suite green (no SyntaxError)

rubocop --format simple test/services/legion/postgres_bus_test.rb
# → Must show: 0 offenses
```

**Expected score after fix: 96/100 PASS**

The only remaining open question after the fix is whether the `assert_match /ActiveRecord.*Error/, log_output.string` assertion passes at runtime (whether the error class name appears in the rescue log line). Given the implementation logs `"[PostgresBus] DB write failed: #{e.class}: #{e.message}"` and the error will be `ActiveRecord::InvalidForeignKey`, the regex `/ActiveRecord.*Error/` will **not** match `ActiveRecord::InvalidForeignKey`. This is a potential −2 pt deduction (untested rescue path via the regex mismatch) that can only be confirmed once syntax is fixed. 

**Recommended: Also verify the regex matches before resubmission** — consider changing to `/ActiveRecord::(InvalidForeignKey|StatementInvalid|ActiveRecordError)/` or simply `/ActiveRecord::/`.

---

## Pass Criteria After Fix

After removing line 294:
- [ ] `ruby -c test/services/legion/postgres_bus_test.rb` → Syntax OK
- [ ] `bin/rails test test/services/legion/postgres_bus_test.rb` → 14 runs, 0 failures
- [ ] `bin/rails test` → Full suite green
- [ ] `rubocop --format simple test/services/legion/postgres_bus_test.rb` → 0 offenses
- [ ] AC8 log regex assertion passes at runtime (verify `/ActiveRecord.*Error/` matches actual error class)

---

*QA report saved per Φ14 retrospective requirements. Previous report: `qa-report-PRD-1-02.md` (85/100 REJECT, 2026-03-06).*
