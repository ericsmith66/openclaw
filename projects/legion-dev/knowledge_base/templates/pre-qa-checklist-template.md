# Pre-QA Checklist: PRD-{ID}-{SLUG}

**Date:** YYYY-MM-DD  
**PRD:** PRD-{epic-id}-{seq}-{slug}  
**Submitted by:** Lead Developer  
**Epic:** {Epic Name}

> **Purpose:** Catch common failure patterns BEFORE QA submission to improve first-attempt pass rates.
> 
> **Instructions:** Complete EVERY item before submitting to QA Agent (Φ11). Mark items with `[x]` when complete. If any item is `[ ]`, DO NOT submit — fix first.

---

## 1. Code Quality & Linting ✅

### RuboCop Clean (MANDATORY)
- [ ] **Zero RuboCop offenses** on ALL modified files (source + tests)
  - Command run: `rubocop -A app/ lib/ test/ gems/ --only-recognized-file-types`
  - **Result:**
    ```
    [Paste rubocop summary output here]
    ```
  - **Files checked:** [list files or "all modified files"]
  - **Offenses:** 0 (REQUIRED)

**⚠️ Deduction if failed:** -5 to -8 points

---

## 2. Test Coverage & Completeness 🧪

### All Planned Tests Implemented (MANDATORY)
- [ ] **Every test from implementation plan is written** (no skips, no stubs, no placeholders)
  - **Implementation Plan Reference:** [link to section]
  - **Tests implemented:** [count] / [planned count]
  - **Missing tests:** None OR [list with reason + alternative]
  - **Skipped tests:** None OR [list with blocker documentation]

**⚠️ Deduction if failed:** -8 to -15 points

### Test Suite Passes (MANDATORY)
- [ ] **Full test suite runs successfully**
  - Command run: `rails test` OR `rake test` OR `bundle exec minitest`
  - **Result:**
    ```
    [Paste test summary: X runs, Y assertions, 0 failures, 0 errors, 0 skips]
    ```
  - **PRD-specific tests:** All passing
  - **Failures:** 0 (REQUIRED)
  - **Errors:** 0 (REQUIRED)
  - **Skips on PRD tests:** 0 (REQUIRED)

**⚠️ Deduction if failed:** -10 to -20 points

### Edge Case Coverage (MANDATORY)
- [ ] **Every `rescue` block and error class has a test**
  - Verification: `grep -rn 'rescue\|raise' [modified files]`
  - **Error paths identified:** [count]
  - **Error paths tested:** [count] (must equal above)
  - **List of tested error scenarios:**
    - [ ] [Error class/path 1]: Test name: `test_...`
    - [ ] [Error class/path 2]: Test name: `test_...`

**⚠️ Deduction if failed:** -2 to -5 points

---

## 3. Ruby Standards 💎

### frozen_string_literal Pragma (MANDATORY)
- [ ] **Every `.rb` file starts with `# frozen_string_literal: true`** (line 1)
  - Verification command: `grep -rL 'frozen_string_literal' lib/ app/ test/ gems/ --include='*.rb'`
  - **Result:**
    ```
    [Paste grep output — should be EMPTY]
    ```
  - **Missing pragmas:** 0 (REQUIRED)
  - **Files checked:** Source files, test files, Rakefiles, migrations, support files

**⚠️ Deduction if failed:** -1 to -3 points

---

## 4. Rails-Specific (if applicable) 🚂

### Migration Integrity (MANDATORY for Rails PRDs)
- [ ] **Migrations work from scratch** (idempotent and correct)
  - Command sequence run: `rails db:drop db:create db:migrate db:seed`
  - **Result:**
    ```
    [Paste migration output — must show success]
    ```
  - **Migrations created:** [list new migration files]
  - **No edited migrations:** Confirmed (never edit committed migrations)

**⚠️ Deduction if failed:** -5 to -8 points

### Model Association Tests (MANDATORY if models modified)
- [ ] **New associations have corresponding tests**
  - **New associations added:**
    - [ ] `[Model].[association_name]` → Test: `test_...`
    - [ ] `[Model].[association_name]` → Test: `test_...`
  - **Association test coverage:** 100%

**⚠️ Deduction if failed:** -3 to -5 points

---

## 5. Architecture & Design 🏗️

### No Dead Code (MANDATORY)
- [ ] **Every defined error class, rescue block, or code path is exercised**
  - **Error classes defined:** [list]
  - **Error classes raised somewhere:** [confirm each]
  - **Rescue blocks:** [count]
  - **Rescue blocks tested:** [count] (must equal above)
  - **Unused code removed:** Yes (no TODO placeholders, no commented-out blocks)

**⚠️ Deduction if failed:** -2 to -5 points

### Mock/Stub Compatibility (MANDATORY if mocks created)
- [ ] **Mocks/stubs return same structure as real implementations**
  - **Mocks created:** [list mock classes]
  - **Contract verification:**
    - [ ] `[MockClass]` returns: [shape] (matches `[RealClass]` ✓)
  - **Integration smoke test:** [describe or link to test]

**⚠️ Deduction if failed:** -3 to -5 points

---

## 6. Documentation & Manual Testing 📋

### Manual Test Steps Work (RECOMMENDED)
- [ ] **Ran through manual verification steps from PRD**
  - **PRD section reference:** [link to manual testing steps]
  - **Steps executed:** [X] / [total]
  - **Results:**
    - Step 1: ✅ [expected result achieved]
    - Step 2: ✅ [expected result achieved]
  - **Evidence:** [screenshots, logs, or output]

### Acceptance Criteria Verified (MANDATORY)
- [ ] **Every AC in every PRD has been explicitly checked**
  - **Acceptance Criteria checklist:**
    - [ ] AC1: [description] → ✅ Verified
    - [ ] AC2: [description] → ✅ Verified
    - [ ] AC3: [description] → ✅ Verified
  - **Unmet AC:** None OR [list with blocker explanation]

---

## Summary & Submission Decision

### Checklist Score
- **Mandatory items completed:** [X] / [total mandatory]
- **Recommended items completed:** [X] / [total recommended]
- **Blockers:** None OR [list]

### Ready for QA?
- [ ] **YES** — All mandatory items complete, ready to submit to QA Agent (Φ11)
- [ ] **NO** — Blockers remain, must fix before submission

### Submission Statement
> I, [Lead Developer Name/Agent], confirm that I have completed this Pre-QA Checklist and all mandatory items pass. The implementation is ready for formal QA validation (Φ11).

**Submitted:** YYYY-MM-DD HH:MM  
**QA Agent notified:** [Yes/No]

---

## Notes & Deviations

[Document any items that couldn't be completed, with justification and mitigation]

---

## Appendix: Scoring Impact Reference

| Checklist Item | Point Deduction if Failed | Frequency in Past Epics |
|----------------|---------------------------|-------------------------|
| RuboCop offenses | -5 to -8 pts | 80% |
| Missing/skipped tests | -8 to -15 pts | 60% |
| frozen_string_literal | -1 to -3 pts | 47% |
| Migration errors | -5 to -8 pts | 60% (Rails PRDs) |
| Dead code / unexercised paths | -2 to -5 pts | 33% |

**Goal:** First-attempt pass rate (score ≥90) should increase from ~33% to ~80%+ with consistent checklist use.
