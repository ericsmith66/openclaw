# PRD-0020: Agent Profile Name Lookup Enhancement

**PRD ID**: PRD-0020
**Status**: Active
**Priority**: High
**Created**: 2026-02-18
**Last Updated**: 2026-02-18
**Owner**: Engineering Team

---

## 📋 Metadata

**Affected Files**:
- `src/main/agent/agent-profile-manager.ts` (lines ~100-130)

**Related PRDs**:
- PRD-0030 (Profile-Aware Task Initialization) - depends on this lookup feature
- PRD-0040 (Task Tool Clarity) - enables natural language agent references

**Upstream Tracking**:
- Issue: TBD (not yet filed with upstream)
- PR: TBD (not yet submitted)

**Epic**: [Epic-manage-keep-us-upgradable](./0000-epic-overview.md)

---

## 1. Problem Statement

### 1.1 User Story

**As a** developer orchestrating multi-agent workflows,
**When I** reference a sub-agent by its human-readable name (e.g., "qa", "architect") in tool calls or prompts,
**I experience** "Agent profile not found" errors because the system only supports UUID lookups,
**Which prevents me from** using natural language for agent orchestration and requires memorizing/copying UUIDs.

---

### 1.2 Reproduction Steps

**Prerequisites**:
- aider-desk installed (clean upstream v0.53.0)
- At least 2 agent profiles configured (e.g., "QA" and "Architect")
- Note their UUIDs from settings

**Steps to Reproduce**:
1. Open aider-desk and create a new task
2. In the chat, ask the agent: "Create a QA review task using the qa agent"
3. Observe the agent attempts to use `tasks---create_task` tool with `agentProfileId: "qa"`
4. System responds with error:
   ```
   Error: Agent profile 'qa' not found
   Available profiles: [list of UUIDs]
   ```
5. Alternative: Try manually calling `tasks---create_task` with `agentProfileId: "qa"` via tool testing
6. Same error occurs

**Expected Behavior**:
- Agent should be able to reference profiles by name
- `agentProfileId: "qa"` should resolve to the QA profile UUID
- Natural language workflow: "use the architect" should work

**Actual Behavior**:
- System only accepts UUIDs: `agentProfileId: "abc-123-def-456"`
- Human-readable names fail with "not found" error
- Requires copying UUIDs from settings (poor UX)

**Evidence**:
```typescript
// Current code only does UUID lookup
getProfile(id: string): AgentProfile | undefined {
  return this.profiles.find(p => p.id === id); // Only matches UUID
}

// Calling with name fails
getProfile("qa") // Returns undefined
getProfile("abc-123-def") // Works if UUID matches
```

---

### 1.3 Impact Assessment

**Frequency**:
- **Always** occurs when using name-based references
- **Often** needed during multi-agent orchestration (5-10 times per day)
- Particularly problematic when agents create sub-agents (no access to UUID)

**Severity**:
- **High**: Major feature impaired, workaround is painful
- Workaround: Manually look up UUID in settings, copy-paste into prompt
- Blocks natural language orchestration capabilities

**Business Value of Fix**:
- **Time saved**: 30-60 seconds per agent reference (looking up UUID)
- **Users affected**: 100% of users doing multi-agent workflows
- **Impact on workflows**: Enables LLM agents to orchestrate naturally without UUID knowledge
- **Cost of NOT fixing**:
  - Poor user experience (UUIDs are developer-hostile)
  - LLM hallucinations (agents invent plausible-sounding UUIDs that don't exist)
  - Manual intervention required (breaks automation)
  - Reduces adoption of multi-agent features

**Quantitative Metrics** (measured during Epic 5):
- **Error rate**: 40% of sub-agent creation attempts failed due to name/UUID mismatch
- **Manual interventions**: 8 times per session (looking up correct UUID)
- **User feedback**: "Why can't I just say 'use the QA agent'?" - multiple team members

---

## 2. Root Cause Analysis

### 2.1 Technical Root Cause

**What code causes this issue?**

The `AgentProfileManager.getProfile()` method only performs UUID-based lookups. It compares the input `id` parameter directly against the `profile.id` property (which is a UUID).

**Problematic Code Flow**:
```typescript
// src/main/agent/agent-profile-manager.ts
class AgentProfileManager {
  private profiles: AgentProfile[] = [];

  getProfile(id: string): AgentProfile | undefined {
    // ❌ PROBLEM: Only checks UUID field
    return this.profiles.find(p => p.id === id);
  }
}

// When called with name
manager.getProfile("qa") // Returns undefined (no profile.id === "qa")

// When called with UUID
manager.getProfile("abc-123") // Works (matches profile.id)
```

**Why This Causes Failures**:
1. LLM agents naturally reference sub-agents by role name ("qa", "architect")
2. Agent profiles have both `id` (UUID) and `name` (human-readable) properties
3. Lookup only checks `id`, ignoring `name`
4. Result: Name-based references always fail

**Relevant Code Snippet** (from upstream v0.53.0):
```typescript
// src/main/agent/agent-profile-manager.ts:100-110
public getProfile(profileId: string): AgentProfile | undefined {
  const profiles = this.getAllProfiles();
  return profiles.find(profile => profile.id === profileId);
}

// Example profile structure
interface AgentProfile {
  id: string;        // "abc-123-def-456" (UUID)
  name: string;      // "QA" or "Architect" (human-readable)
  description: string;
  model: string;
  // ... other properties
}
```

---

### 2.2 Architectural Context

**Why does the current design fail here?**

Upstream designed agent profiles with UUIDs as primary identifiers to ensure uniqueness and avoid naming conflicts. This is technically sound but assumes:
1. Users will reference agents by UUID (via UI dropdowns)
2. API consumers know the UUID mapping ahead of time

**Upstream Design Philosophy**:
- UUIDs prevent naming conflicts (two profiles can't have same UUID)
- UUIDs are immutable (renaming doesn't break references)
- UUIDs are globally unique (no collision risk)

**Our Use Case Difference**:
In LLM-driven multi-agent orchestration:
- **Agents don't know UUIDs**: LLMs read tool descriptions like "use agentProfileId: qa"
- **Names are semantic**: "qa" conveys meaning, "abc-123" doesn't
- **Dynamic workflows**: Agent decides which sub-agent to use based on context
- **No UI access**: Programmatic tool calls can't use dropdowns

This mismatch creates a gap: LLMs naturally generate `agentProfileId: "qa"`, but system requires `agentProfileId: "abc-123-def-456"`.

---

## 3. Solution Design

### 3.1 Our Implementation

**Technical Approach**:
Implement **fallback lookup by name** (case-insensitive) when UUID lookup fails. This maintains backward compatibility (UUIDs still work) while enabling name-based references.

**Key Design Decisions**:
1. **UUID-first priority**: Try UUID match first to avoid breaking existing code
2. **Case-insensitive name match**: "qa", "QA", "Qa" all resolve to same profile
3. **First-match semantics**: If multiple profiles have same name, return first found
4. **No breaking changes**: All existing UUID-based calls continue working

**Code Changes**:

**File: `src/main/agent/agent-profile-manager.ts`**

```typescript
// Before (upstream)
public getProfile(profileId: string): AgentProfile | undefined {
  const profiles = this.getAllProfiles();
  return profiles.find(profile => profile.id === profileId);
}

// After (our fix)
public getProfile(profileIdOrName: string): AgentProfile | undefined {
  const profiles = this.getAllProfiles();

  // ✅ Try UUID match first (backward compatibility)
  let profile = profiles.find(p => p.id === profileIdOrName);

  // ✅ Fallback to case-insensitive name match
  if (!profile) {
    const searchName = profileIdOrName.toLowerCase();
    profile = profiles.find(p =>
      p.name.toLowerCase() === searchName
    );
  }

  return profile;
}
```

**Behavior Changes**:
- **Before**: `getProfile("qa")` → undefined
- **After**: `getProfile("qa")` → QA profile (if exists)
- **Before**: `getProfile("abc-123")` → profile (UUID match)
- **After**: `getProfile("abc-123")` → profile (UUID match, same behavior)

**Dependencies Added**:
- None (uses existing JavaScript/TypeScript features)

---

### 3.2 Alternatives Considered

**Alternative 1: Separate `getProfileByName()` method**
- **Description**: Add new method `getProfileByName(name: string)` instead of modifying existing
- **Pros**: Explicit API, no confusion about lookup semantics
- **Cons**: All call sites must be updated to use new method, more code churn
- **Why Not Chosen**: Fallback approach is more elegant, requires fewer changes

**Alternative 2: Require namespace prefix (e.g., "name:qa" vs "uuid:abc-123")**
- **Description**: Use prefixes to distinguish name vs UUID lookups
- **Pros**: Explicit, no ambiguity
- **Cons**: Complicates API, harder for LLMs to use correctly
- **Why Not Chosen**: Fallback is simpler and more intuitive

**Alternative 3: Change all UUIDs to human-readable slugs (e.g., "qa-agent")**
- **Description**: Replace UUIDs with URL-style slugs as primary identifiers
- **Pros**: Permanently solves the problem, no dual lookup needed
- **Cons**: Breaking change, requires data migration, upstream unlikely to accept
- **Why Not Chosen**: Too invasive, hard to maintain across merges

**Alternative 4: Maintain separate name→UUID index**
- **Description**: Build a hash map `{ "qa": "abc-123", "architect": "def-456" }`
- **Pros**: O(1) lookup performance
- **Cons**: Must maintain index consistency, more complex
- **Why Not Chosen**: Over-engineered for small profile lists (typically <10)

---

### 3.3 Trade-offs & Considerations

**Performance**:
- ✅ **Minimal impact**: Two linear searches at most (UUID then name)
- ✅ **Small dataset**: Typical installations have 3-8 profiles
- ⚠️ **Worst case**: O(2N) for miss, but N is small (<10)

**Complexity**:
- ✅ **Low**: ~10 lines of code added
- ✅ **Maintainable**: Standard fallback pattern
- ✅ **Testable**: Easy to write unit tests

**Compatibility**:
- ✅ **Backward compatible**: All UUID-based calls work unchanged
- ⚠️ **Name collision risk**: If two profiles have same name (rare)
  - Mitigation: First-match behavior is deterministic
  - Future: Could add warning log for duplicate names
- ✅ **Forward compatible**: If upstream adds similar feature, easy to remove ours

**User Experience**:
- ✅ **Much better**: Natural language agent references work
- ✅ **Intuitive**: Matches user mental model ("use the QA agent")
- ⚠️ **Case sensitivity**: "QA" vs "qa" vs "Qa" all work (good), but could surprise users who expect exact match

---

## 4. Test Plan

### 4.1 Regression Test (Proves Issue Exists)

**Purpose**: Demonstrate name-based lookup failure on clean upstream

**Setup**:
```bash
# Clone clean upstream
git clone https://github.com/paul-paliychuk/aider-desk.git test-upstream
cd test-upstream
git checkout v0.53.0

# Install and build
npm install
npm run build
npm run dev
```

**Test Steps**:
1. Open aider-desk application
2. Go to Settings → Agent Profiles
3. Create two profiles:
   - Name: "QA", Model: Claude Sonnet 4
   - Name: "Architect", Model: GPT-4
4. Note their UUIDs (e.g., "abc-123" and "def-456")
5. Create a new task
6. In Node.js console, test profile lookup:
   ```javascript
   const manager = require('./agent-profile-manager');
   manager.getProfile("qa");        // Returns: undefined ❌
   manager.getProfile("architect"); // Returns: undefined ❌
   manager.getProfile("abc-123");   // Returns: QA profile ✅
   ```

**Expected Result** (upstream issue):
- ❌ Name-based lookups return `undefined`
- ✅ UUID-based lookups work
- ❌ LLM agents cannot reference by name

**Evidence Collection**:
- Console output showing undefined results
- Error logs from failed sub-agent creation

---

### 4.2 Verification Test (Proves Fix Works)

**Purpose**: Demonstrate name-based lookup success with fix

**Setup**:
```bash
# Use our fork with fix
git checkout main  # or branch with PRD-0020 fix
npm install
npm run build
npm run dev
```

**Test Steps**:
[Same setup as regression test]

In Node.js console:
```javascript
const manager = require('./agent-profile-manager');

// Test name lookup (various cases)
manager.getProfile("qa");        // Returns: QA profile ✅
manager.getProfile("QA");        // Returns: QA profile ✅
manager.getProfile("Qa");        // Returns: QA profile ✅
manager.getProfile("architect"); // Returns: Architect profile ✅

// Test UUID still works (backward compatibility)
manager.getProfile("abc-123");   // Returns: QA profile ✅

// Test non-existent
manager.getProfile("nonexistent"); // Returns: undefined ✅
```

**Expected Result** (with fix):
- ✅ Name-based lookups work (case-insensitive)
- ✅ UUID-based lookups still work (backward compatible)
- ✅ Invalid names return undefined (graceful failure)

**Evidence Collection**:
- Console output showing successful lookups
- Successful sub-agent creation logs

---

### 4.3 Automated Tests

**Unit Tests**:

```typescript
// src/main/agent/__tests__/agent-profile-manager.name-lookup.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { AgentProfileManager } from '../agent-profile-manager';

describe('Agent Profile Name Lookup', () => {
  let manager: AgentProfileManager;

  beforeEach(() => {
    manager = new AgentProfileManager();

    // Add test profiles
    manager.addProfile({
      id: 'abc-123-def',
      name: 'QA',
      description: 'Quality assurance',
      model: 'claude-sonnet-4',
      provider: 'anthropic',
    });

    manager.addProfile({
      id: 'xyz-789-ghi',
      name: 'Architect',
      description: 'System design',
      model: 'gpt-4',
      provider: 'openai',
    });
  });

  it('should find profile by exact name (lowercase)', () => {
    const profile = manager.getProfile('qa');
    expect(profile).toBeDefined();
    expect(profile?.name).toBe('QA');
    expect(profile?.id).toBe('abc-123-def');
  });

  it('should find profile by exact name (uppercase)', () => {
    const profile = manager.getProfile('QA');
    expect(profile).toBeDefined();
    expect(profile?.name).toBe('QA');
  });

  it('should find profile by mixed case name', () => {
    const profile = manager.getProfile('Qa');
    expect(profile).toBeDefined();
    expect(profile?.name).toBe('QA');
  });

  it('should find profile by UUID (backward compatibility)', () => {
    const profile = manager.getProfile('abc-123-def');
    expect(profile).toBeDefined();
    expect(profile?.name).toBe('QA');
  });

  it('should prioritize UUID over name if both match', () => {
    // Edge case: profile name happens to match another profile's UUID
    manager.addProfile({
      id: 'match-test',
      name: 'abc-123-def', // Name matches first profile's UUID
      model: 'claude',
      provider: 'anthropic',
    });

    const profile = manager.getProfile('abc-123-def');
    // Should return the profile with matching UUID, not matching name
    expect(profile?.id).toBe('abc-123-def');
    expect(profile?.name).toBe('QA');
  });

  it('should return undefined for non-existent profile', () => {
    const profile = manager.getProfile('nonexistent');
    expect(profile).toBeUndefined();
  });

  it('should return first match if multiple profiles have same name', () => {
    // Add duplicate name (edge case)
    manager.addProfile({
      id: 'duplicate-id',
      name: 'QA', // Same name as first profile
      model: 'gpt-4',
      provider: 'openai',
    });

    const profile = manager.getProfile('qa');
    expect(profile).toBeDefined();
    // Should return first matching profile
    expect(profile?.id).toBe('abc-123-def');
  });
});
```

**Integration Tests**:
- Test file: `src/main/project/__tests__/project.agent-lookup.test.ts`
- Scenario: Create sub-task with `agentProfileId: "qa"`, verify correct profile used
- Scenario: LLM generates `create_task` call with name, verify successful execution

**Manual Test Checklist**:
- [ ] Look up "qa" profile by name - succeeds
- [ ] Look up "QA" profile by name (uppercase) - succeeds
- [ ] Look up "Architect" profile - succeeds
- [ ] Look up by UUID - still works (backward compatibility)
- [ ] Look up non-existent name - returns undefined gracefully
- [ ] Create sub-task using name reference - succeeds
- [ ] LLM-driven orchestration with name references - works end-to-end

---

## 5. Success Metrics

### 5.1 Acceptance Criteria

**Must Have**:
- ✅ Name-based profile lookup works (case-insensitive)
- ✅ UUID-based profile lookup still works (backward compatibility)
- ✅ Returns undefined for invalid names (graceful failure)
- ✅ No performance regression (<5ms lookup time)
- ✅ Sub-agent creation with name references succeeds

**Should Have**:
- [ ] Warning log if multiple profiles have same name (future enhancement)
- [ ] Metrics/telemetry for name vs UUID usage (future enhancement)

---

### 5.2 Performance Targets

| Metric | Before Fix | Target | Achieved |
|--------|-----------|--------|----------|
| Name lookup success rate | 0% | 100% | TBD |
| UUID lookup success rate | 100% | 100% (maintained) | TBD |
| Lookup time (avg) | <1ms | <2ms | TBD |
| Sub-agent creation failures | 40% | <5% | TBD |

---

### 5.3 Business Metrics

**Developer Productivity**:
- **Time saved**: 30-60 seconds per agent reference (no UUID lookup needed)
- **Manual interventions eliminated**: 8 per session → 0
- **Error rate**: 40% orchestration failures → <5%

**User Experience**:
- Natural language agent references: "use the QA agent" ✅
- No more UUID copy-pasting from settings
- LLM agents can orchestrate without human intervention

**Adoption**:
- Multi-agent workflows become practical
- Lower barrier to entry for new users
- Better alignment with LLM capabilities

---

## 6. Maintenance Notes

### 6.1 Upstream Monitoring

**Watch For**:
- Changes to `agent-profile-manager.ts` profile lookup logic
- New profile management features (aliases, tags, etc.)
- Related issues about profile references

**Indicators Upstream Might Have Fixed**:
- [ ] Release notes mention "profile name lookup" or "agent aliases"
- [ ] PRs modifying `getProfile()` method
- [ ] Issues closed about "profile not found" with names

**Upstream Issue Search Queries**:
```
repo:paul-paliychuk/aider-desk is:issue "agent profile" "not found" "name"
repo:paul-paliychuk/aider-desk is:pr "getProfile" OR "profile lookup"
```

**Re-evaluation Triggers**:
- Upstream refactors profile management
- New profile identifier scheme introduced
- Community requests for similar feature

---

### 6.2 Testing Protocol (Before Each Merge)

**Quick Test** (3 min):
```bash
# On clean upstream branch
git checkout upstream/main
npm install && npm run build

# In Node console or test:
const manager = new AgentProfileManager();
// Add test profile with name "QA"
manager.getProfile("qa"); // Record result: works or undefined?
```

**Decision Matrix**:
| Test Result | Action | Rationale |
|-------------|--------|-----------|
| Name lookup works | ❌ **Use upstream's code** | Upstream fixed it |
| Name lookup fails | ✅ **Reimplement our fix** | Still needed |
| Different approach (e.g., aliases) | 🔬 **Evaluate both** | Compare features |

---

## 7. Decision Log

| Date | Upstream Version | Decision | Rationale | Tested By |
|------|-----------------|----------|-----------|-----------|
| 2026-02-18 | v0.53.0 | Initial implementation | Upstream only supports UUID, critical for Epic 5 orchestration | Engineering Team |
| 2026-02-18 | v0.54.0 (sync branch) | Re-evaluated, kept fix | Tested upstream - name lookup still returns undefined | @engineer |

---

## 8. References

### 8.1 Implementation References

**Our Implementation**:
- Commit: `1766e59d` (included with agent config changes)
- Branch: `main`
- Files changed: `src/main/agent/agent-profile-manager.ts`
- Lines: ~115-125 (fallback name lookup logic)

**Original Investigation**:
- Epic 5 notes: Orchestration failures during HomeKit integration
- Issue discovered: 2026-02-15 when architect agent couldn't spawn QA sub-agent
- Team discussion: "Why do I need to use UUIDs? Can't I just say 'qa'?"

---

### 8.2 Upstream References

**Related Upstream Issues**:
- None found (issue not yet reported to upstream)

**Related Upstream PRs**:
- None found

**Upstream Code Locations** (v0.53.0):
- `src/main/agent/agent-profile-manager.ts:100-110` - `getProfile()` method
- `src/main/agent/agent.ts` - Profile usage
- `src/main/project/project.ts` - Task creation with profiles

---

### 8.3 Additional Context

**User Feedback**:
> "I shouldn't need to memorize UUIDs. 'Use the QA agent' is natural, 'use profile abc-123-def-456' is not." - @teammate1

> "Every time I want to create a QA sub-task, I have to go to settings, find the QA profile, copy the UUID, paste it in the prompt. This is ridiculous." - @teammate2

**Related Patterns** (industry research):
- Kubernetes: Supports both name and UUID for pod references
- Docker: Container names are primary, IDs are fallback
- Git: Branch names are primary, commit SHAs are fallback
- **Best practice**: Human-readable names for primary use, UUIDs for precise reference

---

## 9. Appendix

### 9.1 Glossary

**Agent Profile**: Configuration defining an AI agent's model, provider, system prompt, and capabilities

**UUID (Universally Unique Identifier)**: 128-bit identifier (e.g., "abc-123-def-456") guaranteed to be unique

**Profile Name**: Human-readable label for a profile (e.g., "QA", "Architect")

**Fallback Lookup**: Pattern where primary lookup method fails, secondary method attempts

**Case-insensitive**: Comparison ignores uppercase/lowercase differences ("qa" === "QA")

### 9.2 Technical Deep Dive

**Why Case-Insensitive Matching?**
- Users type naturally: "qa", "QA", "Qa"
- LLM output varies: "qa" vs "QA" based on context
- No semantic difference: "QA" and "qa" mean same thing
- Implementation: `toLowerCase()` before comparison

**Name Collision Handling**:
Current approach: First-match (deterministic but not ideal)

Future enhancement options:
1. Warn on duplicate names during profile creation
2. Return array of matches, let caller decide
3. Require unique names (enforce at creation time)

### 9.3 Related Documentation

- [Merge Strategy Comparison](../../MERGE_STRATEGY_COMPARISON.md) - Section 2: Agent Profile Name Lookup
- [Epic Overview](./0000-epic-overview.md)
- [PRD-0030](./0030-profile-aware-task-initialization.md) - Depends on this feature

---

**PRD Version**: 1.0
**Last Updated**: 2026-02-18
**Next Review**: Before next upstream merge (v0.55.0+)
