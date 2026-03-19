# PRD-{XXXX}: {Feature Name}

**PRD ID**: PRD-{XXXX}
**Status**: Draft | Active | Under Review | Superseded | Merged Upstream
**Priority**: Critical | High | Medium | Low
**Created**: YYYY-MM-DD
**Last Updated**: YYYY-MM-DD
**Owner**: {Team/Person}

---

## 📋 Metadata

**Affected Files**:
- `path/to/file1.ts`
- `path/to/file2.ts`

**Related PRDs**:
- PRD-XXXX (dependency/related)

**Upstream Tracking**:
- Issue: [paul-paliychuk/aider-desk#XXX](https://github.com/paul-paliychuk/aider-desk/issues/XXX)
- PR: [paul-paliychuk/aider-desk#XXX](https://github.com/paul-paliychuk/aider-desk/pull/XXX)

**Epic**: [Epic-manage-keep-us-upgradable](../epics/Epic-manage-keep-us-upgradable/0000-epic-overview.md)

---

## 1. Problem Statement

### 1.1 User Story

**As a** [role/persona],
**When I** [perform action/scenario],
**I experience** [specific problem/pain point],
**Which prevents me from** [desired goal/outcome].

**Example**:
> As a developer using multi-agent orchestration,
> When I add 10+ files to the context rapidly,
> I experience a 5-10 second UI freeze with 100% CPU usage,
> Which prevents me from efficiently working with large codebases.

---

### 1.2 Reproduction Steps

**Prerequisites**:
- System state requirements
- Configuration settings
- Specific models/agents used

**Steps to Reproduce**:
1. Start with clean upstream aider-desk
2. Configure [specific settings]
3. Execute [specific action]
4. Observe [specific symptom]

**Expected Behavior**:
[What should happen in ideal scenario]

**Actual Behavior**:
[What actually happens - the problem]

**Evidence**:
- Screenshots: [if applicable]
- Logs: [relevant error messages/console output]
- Performance metrics: [CPU/memory/network data]

---

### 1.3 Impact Assessment

**Frequency**:
- How often does this occur? (Always | Often | Sometimes | Rarely)
- Under what conditions? (Specific workflows/configurations)

**Severity**:
- **Critical**: Blocks core functionality, no workaround
- **High**: Major feature impaired, workaround is painful
- **Medium**: Feature degraded, reasonable workaround exists
- **Low**: Minor inconvenience, easy workaround available

**Business Value of Fix**:
- Time saved per occurrence: [X minutes/hours]
- Users affected: [number or percentage]
- Impact on workflows: [describe key workflow improvements]
- Cost of NOT fixing: [productivity loss, user frustration, etc.]

**Quantitative Metrics** (if measured):
- Performance degradation: [percentage or absolute numbers]
- Error rate: [frequency of failures]
- User satisfaction: [survey data, feedback quotes]

---

## 2. Root Cause Analysis

### 2.1 Technical Root Cause

**What code/architecture causes this issue?**

[Detailed explanation of the underlying technical problem]

**Example**:
> Every file addition triggers `updateEstimatedTokens()` synchronously. With 10 files, this means 10 sequential calls to `agent.estimateTokens()`, each taking ~500ms, blocking the event loop for 5+ seconds total.

**Relevant Code Snippet** (from upstream):
```typescript
// Current problematic implementation
addFile(file) {
  this.files.push(file);
  this.updateEstimatedTokens(); // ❌ Synchronous, called for EVERY file
}
```

---

### 2.2 Architectural Context

**Why does the current design fail here?**

[Explain architectural constraints or design decisions that contribute to the problem]

**Upstream Design Philosophy**:
[If known, explain what upstream was optimizing for]

**Our Use Case Difference**:
[How our usage patterns differ from upstream's assumptions]

---

## 3. Solution Design

### 3.1 Our Implementation

**Technical Approach**:
[High-level description of the solution]

**Key Design Decisions**:
- Decision 1: [Why we chose X over Y]
- Decision 2: [Reasoning behind approach Z]

**Code Changes**:

**File: `path/to/file.ts`**
```typescript
// Before (upstream)
addFile(file) {
  this.files.push(file);
  this.updateEstimatedTokens(); // Called immediately
}

// After (our fix)
import debounce from 'lodash/debounce';

private debouncedEstimateTokens = debounce(async (profile) => {
  const tokens = await this.agent.estimateTokens(this, profile);
  this.updateTokensInfo({ estimated: tokens });
}, 500); // ✅ Batches calls with 500ms delay

addFile(file) {
  this.files.push(file);
  void this.debouncedEstimateTokens(this.agentProfile); // Debounced
}
```

**Dependencies Added**:
- lodash/debounce: For throttling expensive operations

---

### 3.2 Alternatives Considered

**Alternative 1: [Name]**
- **Description**: [Brief explanation]
- **Pros**: [Advantages]
- **Cons**: [Disadvantages]
- **Why Not Chosen**: [Reasoning]

**Alternative 2: [Name]**
- **Description**: [Brief explanation]
- **Pros**: [Advantages]
- **Cons**: [Disadvantages]
- **Why Not Chosen**: [Reasoning]

---

### 3.3 Trade-offs & Considerations

**Performance**:
- [Impact on CPU/memory/network]

**Complexity**:
- [Added code complexity, maintenance burden]

**Compatibility**:
- [Potential conflicts with future upstream changes]

**User Experience**:
- [Changes to behavior users might notice]

---

## 4. Test Plan

### 4.1 Regression Test (Proves Issue Exists)

**Purpose**: Demonstrate the problem on clean upstream

**Setup**:
```bash
# Clone clean upstream
git clone https://github.com/paul-paliychuk/aider-desk.git test-upstream
cd test-upstream
git checkout v0.XX.X  # Specific version

# Install and build
npm install
npm run build
npm run dev
```

**Test Steps**:
1. [Step-by-step instructions to reproduce issue]
2. [Include specific actions, timing, expected observations]

**Expected Result**:
[The problem should occur - describe symptoms]

**Evidence Collection**:
- Monitor CPU: `Activity Monitor` or `top -pid [electron-pid]`
- Console logs: Check for [specific error messages]
- User experience: UI should [freeze/lag/error]

---

### 4.2 Verification Test (Proves Fix Works)

**Purpose**: Demonstrate the fix resolves the issue

**Setup**:
```bash
# Use our fork with fix
git checkout [our-branch-with-fix]
npm install
npm run build
npm run dev
```

**Test Steps**:
[Same steps as regression test]

**Expected Result**:
[The problem should NOT occur - describe improved behavior]

**Evidence Collection**:
- Monitor CPU: Should remain <30%
- Console logs: No errors
- User experience: Smooth, responsive UI

---

### 4.3 Automated Tests

**Unit Tests**:
```typescript
// tests/task.debouncing.test.ts
describe('Token Count Debouncing', () => {
  it('should batch rapid file additions into single token count', async () => {
    const task = new Task(/* ... */);
    const estimateSpy = vi.spyOn(task.agent, 'estimateTokens');

    // Add 10 files rapidly
    for (let i = 0; i < 10; i++) {
      task.addFile(`file${i}.ts`);
    }

    // Wait for debounce
    await vi.advanceTimersByTimeAsync(600);

    // Should only call estimateTokens ONCE, not 10 times
    expect(estimateSpy).toHaveBeenCalledTimes(1);
  });
});
```

**Integration Tests**:
- [Describe end-to-end test scenarios]
- [List test file names/locations]

**Manual Test Checklist**:
- [ ] Add 10+ files to context - CPU stays <30%
- [ ] Add files one-by-one - token count updates correctly
- [ ] Switch between tasks - debounce doesn't leak between tasks
- [ ] Error during token estimation - fails gracefully

---

## 5. Success Metrics

### 5.1 Acceptance Criteria

**Must Have**:
- ✅ [Specific, measurable criterion 1]
- ✅ [Specific, measurable criterion 2]

**Example**:
- ✅ CPU usage <30% when adding 10+ files rapidly
- ✅ Token count updates within 1 second after last file addition
- ✅ No race conditions or stale token counts

**Should Have**:
- [ ] [Nice-to-have improvement 1]

---

### 5.2 Performance Targets

| Metric | Before Fix | Target | Achieved |
|--------|-----------|--------|----------|
| CPU during bulk add | 100% for 5-10s | <30% sustained | TBD |
| UI freeze duration | 5-10 seconds | <500ms perceived lag | TBD |
| Token count accuracy | 100% | 100% | TBD |

---

### 5.3 Business Metrics

**Developer Productivity**:
- Time saved per large codebase operation: [X seconds]
- Reduced frustration: [qualitative feedback]

**System Health**:
- Reduced event loop blocking
- Better multi-tasking capability

---

## 6. Maintenance Notes

### 6.1 Upstream Monitoring

**Watch For**:
- Changes to `task.ts` token estimation logic
- New performance optimization initiatives
- Related issues: [link to upstream issue tracker queries]

**Indicators Upstream Might Have Fixed**:
- [ ] Release notes mention "token counting performance"
- [ ] PRs modifying `updateEstimatedTokens()` method
- [ ] Issues closed related to UI freezes during file operations

**Re-evaluation Triggers**:
- Major version releases (0.X.0)
- Significant task.ts refactoring
- Community reports of improved performance

---

### 6.2 Testing Protocol (Before Each Merge)

**Quick Test** (5 min):
```bash
# On upstream branch
1. Open project with 50+ files
2. Select 10 files, add to context
3. Monitor CPU in Activity Monitor
4. Record: Freezes? CPU spike? Duration?
```

**Decision Matrix**:
| Test Result | Action |
|-------------|--------|
| UI freezes, CPU >80% | ✅ Reimplement our fix |
| UI smooth, CPU <30% | ❌ Upstream fixed it, use theirs |
| Mixed results | 🔬 Deeper investigation needed |

---

## 7. Decision Log

| Date | Upstream Version | Decision | Rationale | Tested By |
|------|-----------------|----------|-----------|-----------|
| 2026-02-18 | v0.53.0 | Initial implementation | Upstream has no solution, critical blocker | @username |
| 2026-XX-XX | v0.54.0 | Re-evaluated, kept fix | Upstream still lacks debouncing | @username |

---

## 8. References

### 8.1 Implementation References

**Our Implementation**:
- Commit: [abc123def - Add token count debouncing](https://github.com/our-fork/commit/abc123)
- PR: [#123 - Performance: Debounce token counting](https://github.com/our-fork/pull/123)
- Branch: `perf/token-count-debouncing`

**Original Investigation**:
- Epic 5 notes: [link to notes]
- Performance profiling data: [link to metrics/screenshots]

---

### 8.2 Upstream References

**Related Upstream Issues**:
- [Issue #456: UI freezes when adding many files](https://github.com/paul-paliychuk/aider-desk/issues/456)

**Related Upstream PRs**:
- [PR #789: Optimize token counting](https://github.com/paul-paliychuk/aider-desk/pull/789)

**Upstream Code Locations**:
- `src/main/task/task.ts:140-160` - Token estimation logic
- `src/main/agent/agent.ts:200-220` - estimateTokens method

---

### 8.3 Additional Context

**Team Discussion**:
- [Link to Slack thread or meeting notes]

**User Feedback**:
- Quote: "Adding my full codebase used to freeze the app for 10 seconds, now it's instant"

**Performance Data**:
- [Link to CPU profiling screenshots]
- [Link to before/after comparison videos]

---

## 9. Appendix

### 9.1 Glossary

**Token Estimation**: Process of calculating approximate LLM token count for context
**Debouncing**: Technique to delay function execution until calls stop arriving
**Event Loop Blocking**: When synchronous operations prevent UI responsiveness

### 9.2 Related Documentation

- [Merge Strategy Comparison](../MERGE_STRATEGY_COMPARISON.md)
- [Epic Overview](../epics/Epic-manage-keep-us-upgradable/0000-epic-overview.md)
- [Upstream Architecture Docs](https://github.com/paul-paliychuk/aider-desk/docs)

---

**Template Version**: 1.0
**Last Template Update**: 2026-02-18
