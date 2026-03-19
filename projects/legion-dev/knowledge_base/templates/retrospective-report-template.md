# Retrospective Report: Epic {START-ID} to {END-ID}

**Date:** YYYY-MM-DD  
**Analyzer:** QA Agent  
**Epics Analyzed:** [List epic IDs and names]  
**Period:** [Start date] to [End date]  
**Trigger:** [Every 3-5 epics / Epic with 2+ QA failures / Quarterly review]

---

## Executive Summary

**Purpose:** Systematic analysis of failure patterns and quality trends to enable continuous improvement through actionable instruction updates and Pre-QA Checklist refinements.

**Key Findings:**
- First-attempt pass rate: **X%** (baseline: 33%)
- Average QA score: **X/100** (target: ≥90)
- Most impactful pattern: [Pattern name] (-X pts avg, Y% frequency)
- Improvement trend: [Improving / Stable / Declining]

---

## Score Summary

| Metric | Value | Trend | Target |
|--------|-------|-------|--------|
| **Epics analyzed** | N | — | — |
| **Total PRDs** | N | — | — |
| **QA scoring events** | N | — | — |
| **First-attempt passes** | N (X%) | ↑/↓/→ | ≥80% |
| **QA loops (avg)** | X.X | ↑/↓/→ | ≤1.5 |
| **Average initial score** | X/100 | ↑/↓/→ | ≥90 |
| **Average final score** | X/100 | ↑/↓/→ | ≥95 |

### Score Distribution

| Score Range | Count | % of Total |
|-------------|-------|-----------|
| 95-100 (Excellent) | N | X% |
| 90-94 (Pass) | N | X% |
| 85-89 (Marginal) | N | X% |
| 80-84 (Fail) | N | X% |
| <80 (Critical Fail) | N | X% |

---

## Top 5 Recurring Failure Patterns

### Pattern 1: [Pattern Name]
- **Frequency:** X% (appeared in N/M PRDs)
- **Avg Point Deduction:** -X to -Y pts
- **Fix Difficulty:** [Trivial / Medium / Hard]
- **Evidence:** PRD-X, PRD-Y, PRD-Z
- **Impact Description:**
  [Describe what breaks, why it matters, user/system impact]
- **Root Cause:**
  [Why this keeps happening — process gap, unclear instruction, tooling issue]
- **Prevention Strategy:**
  ```markdown
  ✅ CHECKLIST ITEM (add to Part 9):
  - [ ] [Specific verification step with command/tool]
    - Command: `[exact command]`
    - Expected result: [clear pass/fail criteria]
    - Deduction if failed: -X to -Y points
  
  📝 INSTRUCTION UPDATE (Lead Developer):
  **MANDATORY**: [Clear, actionable requirement with no ambiguity]
  
  📝 INSTRUCTION UPDATE (Architect — if planning gap):
  [Template addition or planning requirement]
  ```

### Pattern 2: [Pattern Name]
[Same structure as Pattern 1]

### Pattern 3: [Pattern Name]
[Same structure as Pattern 1]

### Pattern 4: [Pattern Name]
[Same structure as Pattern 1]

### Pattern 5: [Pattern Name]
[Same structure as Pattern 1]

---

## Secondary Patterns (Less Frequent but Notable)

| Pattern | Frequency | Avg Deduction | Fix Difficulty | Notes |
|---------|-----------|--------------|----------------|-------|
| [Pattern 6] | X% | -Y pts | [Level] | [Brief note] |
| [Pattern 7] | X% | -Y pts | [Level] | [Brief note] |
| [Pattern 8] | X% | -Y pts | [Level] | [Brief note] |

---

## Success Patterns (Celebrate & Reinforce) 🎉

### What Worked Well Across Multiple PRDs

1. **[Success pattern name]**
   - **Frequency:** Consistently applied in X/Y PRDs
   - **Impact:** [Positive outcome — score boost, time saved, zero defects]
   - **Example:** PRD-X, PRD-Y
   - **Recommendation:** [Codify as standard practice / Add to onboarding docs]

2. **[Success pattern name]**
   [Same structure]

3. **[Success pattern name]**
   [Same structure]

### High-Quality Implementations (Score ≥95 on first attempt)

| PRD | Domain | Score | What Made It Excellent |
|-----|--------|-------|----------------------|
| PRD-X | [Domain] | 99/100 | [Key quality factors] |
| PRD-Y | [Domain] | 97/100 | [Key quality factors] |

---

## Instruction Updates (Actionable Changes)

### Lead Developer Instructions

**File:** `knowledge_base/instructions/RULES.md` (Φ10) OR `knowledge_base/ai-instructions/agent-guidelines.md`

#### NEW MANDATORY Requirements
```markdown
1. **[Requirement name]:**
   - [Clear, specific instruction]
   - Verification: [Command or check]
   - Rationale: [Why this matters — link to pattern]

2. **[Requirement name]:**
   [Same structure]
```

#### UPDATED Requirements (Clarifications)
```markdown
1. **[Existing requirement] — CLARIFIED:**
   - Old: [Vague statement]
   - New: [Specific, measurable statement]
   - Why: [Pattern that revealed ambiguity]
```

---

### Architect Instructions

**File:** `knowledge_base/instructions/RULES.md` (Φ8, Φ9)

#### NEW Planning Requirements
```markdown
1. **[Planning template addition]:**
   - Add section to implementation plan: "[Section name]"
   - Must include: [Specific items]
   - Rationale: [Pattern that revealed planning gap]
```

#### UPDATED Plan Review Rubric
```markdown
1. **[Rubric category] — UPDATED:**
   - Old weight: X%
   - New weight: Y%
   - New criteria: [What to check]
```

---

### Pre-QA Checklist Updates

**File:** `knowledge_base/templates/pre-qa-checklist-template.md`

#### NEW Checklist Items
```markdown
### [Category]
- [ ] **[Item name]** (MANDATORY/RECOMMENDED)
  - Command: `[exact command]`
  - Expected result: [clear criteria]
  - **Deduction if failed:** -X to -Y points
  - **Rationale:** Pattern [N] — prevents [specific failure]
```

#### REMOVED Checklist Items (False Positives)
```markdown
- **[Item name]**: Removed after 10+ PRDs with zero triggers
```

---

## Improvement Metrics (Trend Analysis)

### Pattern Frequency Over Time

| Pattern | Epic N-5 | Epic N-4 | Epic N-3 | Epic N-2 | Epic N-1 | Trend |
|---------|---------|---------|---------|---------|---------|-------|
| RuboCop offenses | 80% | 75% | 60% | 45% | 30% | ✅ Improving |
| Missing tests | 60% | 60% | 55% | 50% | 40% | ✅ Improving |
| frozen_string_literal | 47% | 40% | 35% | 20% | 10% | ✅ Improving |
| [Pattern N] | X% | X% | X% | X% | X% | ⚠️ Stable / ❌ Worsening |

### First-Attempt Pass Rate Over Time

```
Epic N-5:  20% (1/5 PRDs passed first attempt)
Epic N-4:  33% (2/6 PRDs passed first attempt)
Epic N-3:  40% (2/5 PRDs passed first attempt)
Epic N-2:  50% (3/6 PRDs passed first attempt) ← Pre-QA Checklist introduced
Epic N-1:  67% (4/6 PRDs passed first attempt) ← Checklist refinements applied
```

**Target:** ≥80% by Epic N+3

---

## Recommendations (Prioritized)

### High Priority (Implement Immediately)

1. **[Recommendation]**
   - **Problem:** [What's broken/inefficient]
   - **Solution:** [Specific action with owner]
   - **Expected Impact:** [Metric improvement]
   - **Effort:** [Hours/days]
   - **Owner:** [Lead Developer / Architect / QA Agent]

2. **[Recommendation]**
   [Same structure]

### Medium Priority (Next Sprint)

3. **[Recommendation]**
   [Same structure]

### Low Priority (Backlog)

4. **[Recommendation]**
   [Same structure]

---

## Root Cause Analysis (Deep Dive)

### Why Are We Still Seeing [Pattern X]?

**Hypothesis 1:** [Possible root cause]
- **Evidence:** [Data supporting this]
- **Test:** [How to validate]
- **Mitigation:** [If true, what to do]

**Hypothesis 2:** [Possible root cause]
[Same structure]

**Conclusion:** [Most likely root cause based on evidence]

---

## Continuous Improvement Loop Verification

### Did Previous Retrospective Actions Work?

| Action from Last Retro | Status | Impact | Evidence |
|------------------------|--------|--------|----------|
| [Action 1] | ✅ Implemented / ⏳ In Progress / ❌ Not Done | [Measured change] | [Data] |
| [Action 2] | [Status] | [Measured change] | [Data] |

**Lessons Learned:**
- [What worked well in implementation]
- [What didn't work / needs adjustment]

---

## Memory Storage Decisions (Φ14 Rule 7)

### Items to Store in Memory (Passed Eligibility Filter)

✅ **STORE:**
1. **[Pattern/decision name]**
   - Type: [code-pattern / architectural-decision / user-preference]
   - Content: [Concise, actionable statement]
   - Reusable: Yes — applies across multiple epics/projects
   - Stable: Yes — unlikely to change in next 6 months
   - Actionable: Yes — directly changes future implementation behavior

### Items NOT Stored (Failed Eligibility Filter)

❌ **DO NOT STORE:**
- Task progress/status (transient)
- One-off bug details (not reusable)
- Implementation specifics (derivable from code)
- File lists from this analysis (task-specific)
- Logs/stack traces (noise)

---

## Next Steps

### Immediate Actions (This Week)
- [ ] Update RULES.md with new mandatory requirements
- [ ] Update pre-qa-checklist-template.md with new items
- [ ] Notify Lead Developer of instruction changes
- [ ] Store eligible patterns in memory
- [ ] Schedule next retrospective (after Epic X)

### Follow-Up (Next Month)
- [ ] Re-measure first-attempt pass rate after changes
- [ ] Validate that new checklist items are catching issues
- [ ] Remove false-positive checklist items (if any)
- [ ] Conduct follow-up retrospective to verify improvements

---

## Appendix: Raw Data

### Complete QA Score Registry

| PRD | Domain | Initial Score | Final Score | Rounds to Pass | Key Deductions |
|-----|--------|--------------|-------------|----------------|----------------|
| PRD-X | [Domain] | X/100 | Y/100 | N | [Issues] |
| [Continue for all PRDs analyzed] |

### Complete Pattern Registry

| Pattern ID | Description | Frequency | Avg Deduction | Fix Difficulty | First Seen | Last Seen |
|-----------|-------------|-----------|--------------|----------------|-----------|-----------|
| P001 | RuboCop offenses | 80% | -6 pts | Trivial | Epic 4C | Epic N-1 |
| [Continue for all patterns] |

---

**Report prepared by:** QA Agent  
**Reviewed by:** [Optional: Architect Agent]  
**Approved by:** Eric  
**Next retrospective scheduled:** [Date / After Epic X]
