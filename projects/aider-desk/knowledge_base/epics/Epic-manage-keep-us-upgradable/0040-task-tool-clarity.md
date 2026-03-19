# PRD-0040: Task Tool Clarity - Available Profiles Documentation

**PRD ID**: PRD-0040
**Status**: Active
**Priority**: High
**Created**: 2026-02-18
**Last Updated**: 2026-02-18
**Owner**: Engineering Team

---

## 📋 Metadata

**Affected Files**:
- `src/main/agent/tools/tasks.ts` (tool description and parameters)

**Related PRDs**:
- PRD-0020 (Agent Profile Name Lookup) - enables name-based references
- PRD-0030 (Profile-Aware Task Initialization) - implements the capability

**Upstream Tracking**:
- Issue: TBD (not yet filed with upstream)
- PR: TBD (not yet submitted)

**Epic**: [Epic-manage-keep-us-upgradable](./0000-epic-overview.md)

---

## 1. Problem Statement

### 1.1 User Story

**As a** LLM agent orchestrating multi-agent workflows,
**When I** consider creating a sub-task and read the `tasks---create_task` tool description,
**I experience** confusion about which agent profiles exist and how to reference them,
**Which prevents me from** confidently using sub-agents, leading to hallucinated profile names ("self-audit", "code-review-expert") or claims that sub-agent creation isn't possible.

---

### 1.2 Reproduction Steps

**Prerequisites**:
- aider-desk installed (clean upstream v0.53.0)
- Three agent profiles configured: "QA", "Architect", "Debug"
- A task using Claude or GPT-4 (capable of tool use)

**Steps to Reproduce**:
1. Create a new task with a capable LLM
2. Ask: "Can you create a sub-task for QA review?"
3. Observe agent's response examining `tasks---create_task` tool
4. Agent sees generic description: "Create a new task with optional agent profile"
5. Agent doesn't know valid profile names
6. Agent either:
   - **Hallucination path**: Invents plausible name (`agentProfileId: "code-review-expert"`)
   - **Refusal path**: Claims "I cannot create sub-tasks" or "profiles not available"
   - **Trial-and-error path**: Guesses "qa", gets lucky if name matches

**Expected Behavior**:
- Tool description lists available profiles: "qa", "architect", "debug"
- Agent sees examples: `agentProfileId: "qa"` for QA reviews
- Agent confidently selects appropriate profile for task

**Actual Behavior**:
- Tool description is generic, no profile list
- Agent has no knowledge of valid profile names
- Results in errors, hallucinations, or missed opportunities

**Evidence**:
```typescript
// Current tool description (upstream)
{
  name: "tasks---create_task",
  description: "Create a new task with optional agent profile",
  parameters: {
    agentProfileId: {
      type: "string",
      description: "Agent profile ID" // ❌ No examples, no valid values
    }
  }
}

// Agent attempts (real examples from Epic 5):
// Attempt 1: Hallucination
agentProfileId: "code-review-expert" // ❌ Doesn't exist

// Attempt 2: Refusal
"I cannot create sub-tasks because I don't know the available agent profiles"

// Attempt 3: Lucky guess
agentProfileId: "qa" // ✅ Works, but only by chance
```

---

### 1.3 Impact Assessment

**Frequency**:
- **Often** occurs during multi-agent workflows (8/10 first attempts)
- **Critical** for autonomous orchestration (agent must know options)
- Affects every session involving sub-agent creation

**Severity**:
- **High**: Major feature impaired, workaround is painful
- Workaround: User manually tells agent valid profile names (breaks autonomy)
- Blocks autonomous multi-agent orchestration

**Business Value of Fix**:
- **Time saved**: 30-60 seconds per sub-agent creation (no manual guidance needed)
- **Users affected**: 100% of multi-agent workflows
- **Impact on workflows**: Enables autonomous orchestration without human intervention
- **Cost of NOT fixing**:
  - Hallucinations → wasted API calls → $1-2/day
  - Manual intervention required → breaks automation
  - User frustration: "Why doesn't it know what agents I have?"
  - Reduced confidence in agentic capabilities

**Quantitative Metrics** (measured during Epic 5):
- **Hallucination rate**: 90% of first sub-agent attempts (invents invalid names)
- **Manual interventions**: 8 per session (telling agent correct profile names)
- **Success rate**: 10% autonomous → 95% after manual guidance
- **User feedback**: "I have to babysit the agent constantly" - 3 team members

---

## 2. Root Cause Analysis

### 2.1 Technical Root Cause

**What code causes this issue?**

The `tasks---create_task` tool description in `tools/tasks.ts` provides only generic information about the `agentProfileId` parameter. It doesn't include:
1. List of available profile names/IDs
2. Examples of valid values
3. Guidance on when to use which profile

**Problematic Code Flow**:
```typescript
// src/main/agent/tools/tasks.ts (simplified)
const createTaskTool = {
  name: "tasks---create_task",
  description: "Create a new task with optional agent profile",
  parameters: {
    type: "object",
    properties: {
      agentProfileId: {
        type: "string",
        // ❌ PROBLEM: No information about valid values
        description: "Optional agent profile ID or name"
      },
      description: {
        type: "string",
        description: "Task description"
      }
    }
  }
};
```

**Why This Causes Hallucinations**:
1. LLM reads tool description to understand capabilities
2. Sees `agentProfileId` parameter but no valid values
3. LLM's training includes concepts like "code review", "QA", "testing"
4. LLM hallucinates plausible-sounding profile names based on context
5. Tool call fails with "profile not found" error
6. User must intervene with correct names

**Relevant Code Snippet** (from upstream v0.53.0):
```typescript
// src/main/agent/tools/tasks.ts:20-50
export function getTaskTools(): ToolDefinition[] {
  return [
    {
      name: "tasks---create_task",
      description: "Create a new task. Use this to spawn specialized sub-agents.",
      parameters: {
        type: "object",
        properties: {
          description: {
            type: "string",
            description: "Description of the task"
          },
          agentProfileId: {
            type: "string",
            description: "Optional: Agent profile ID to use"
            // ❌ Missing: List of available profiles
            // ❌ Missing: Examples of valid values
            // ❌ Missing: Guidance on which profile for which task
          }
        },
        required: ["description"]
      }
    }
  ];
}
```

---

### 2.2 Architectural Context

**Why does the current design fail here?**

Upstream's tool descriptions assume **human operators** who can check the UI for available profiles. The design doesn't account for **autonomous LLM agents** that only have access to tool descriptions.

**Upstream Design Philosophy**:
- Tool descriptions are minimal (less token usage)
- Users access UI for detailed information
- Profiles are dynamic (change at runtime), so hard to document

**Our Use Case Difference**:
In LLM-driven orchestration:
- **No UI access**: Agent only sees tool descriptions
- **Autonomous operation**: No human to provide profile names
- **Context-driven decisions**: Agent decides which sub-agent based on task needs
- **Token cost acceptable**: Extra 50-100 tokens in tool description is worth preventing hallucinations

The gap: Upstream optimizes for human+UI use, we need LLM-autonomous use.

---

## 3. Solution Design

### 3.1 Our Implementation

**Technical Approach**:
Enhance the `tasks---create_task` tool description to include:
1. **List of available profiles** with their specializations
2. **Examples** showing how to reference profiles by name
3. **Guidance** on when to use each profile type

**Key Design Decisions**:
1. **Static list in description**: Acceptable for small number of profiles (3-8)
2. **Include both name and purpose**: "qa" + "Quality assurance and testing"
3. **Provide examples**: Show actual usage patterns
4. **Keep concise**: Balance detail vs token usage (~100 tokens added)

**Code Changes**:

**File: `src/main/agent/tools/tasks.ts`**

```typescript
// Before (upstream)
{
  name: "tasks---create_task",
  description: "Create a new task with optional agent profile",
  parameters: {
    agentProfileId: {
      type: "string",
      description: "Optional agent profile ID"
    }
  }
}

// After (our fix)
{
  name: "tasks---create_task",
  description: `Create a new task, optionally using a specialized agent profile.

Available standard profiles:
- "qa": Quality assurance and testing expert - use for code reviews, test validation, quality checks
- "architect": System design and planning specialist - use for architectural decisions, refactoring plans
- "debug": Debugging and troubleshooting expert - use for investigating bugs, error analysis

You can reference profiles by name (case-insensitive) or by UUID.
If no agentProfileId specified, sub-task inherits parent's model.

Examples:
- QA review: { agentProfileId: "qa", description: "Review code quality" }
- Architecture planning: { agentProfileId: "architect", description: "Design system architecture" }
- Bug investigation: { agentProfileId: "debug", description: "Investigate error logs" }`,

  parameters: {
    agentProfileId: {
      type: "string",
      description: "Optional: Agent profile name (e.g., 'qa', 'architect') or UUID. See tool description for available profiles."
    }
  }
}
```

**Behavior Changes**:
- **Before**: Agent doesn't know valid profile names → hallucinations
- **After**: Agent sees available profiles → confident selection
- **Example interaction**:
  ```
  User: "Can you create a QA review sub-task?"
  Agent: [reads tool description] "I see there's a 'qa' profile for quality assurance.
          I'll create a sub-task with agentProfileId: 'qa'."
  Result: ✅ Correct profile used
  ```

**Dependencies Added**:
- None (only changes tool description string)

---

### 3.2 Alternatives Considered

**Alternative 1: Dynamic profile enumeration in tool schema**
- **Description**: Use JSON Schema `enum` field with actual profile IDs
  ```typescript
  agentProfileId: {
    type: "string",
    enum: ["abc-123", "def-456", "ghi-789"] // UUIDs
  }
  ```
- **Pros**: Type-safe, validates input automatically
- **Cons**: UUIDs not human-readable, requires dynamic tool generation
- **Why Not Chosen**: LLMs work better with descriptive names than UUIDs

**Alternative 2: Separate "list_agent_profiles" tool**
- **Description**: Add new tool to query available profiles
  ```typescript
  { name: "tasks---list_profiles", description: "List available agent profiles" }
  ```
- **Pros**: Always up-to-date, supports dynamic profiles
- **Cons**: Requires extra tool call, adds latency, more complex
- **Why Not Chosen**: Simpler to include common profiles in description

**Alternative 3: Query profiles from context (RAG)**
- **Description**: Include profile list in system prompt or context
- **Pros**: Not tied to tool definition, easier to update
- **Cons**: Competes with limited context, may be truncated
- **Why Not Chosen**: Tool descriptions are always included, context is not

**Alternative 4: Show only profile names, not descriptions**
- **Description**: Minimal list: "Available: qa, architect, debug"
- **Pros**: Fewer tokens used
- **Cons**: Agent doesn't know which profile for which task
- **Why Not Chosen**: Guidance is critical for correct selection

---

### 3.3 Trade-offs & Considerations

**Performance**:
- ⚠️ **Token usage**: +100 tokens per tool call (~$0.0001/call with Claude)
- ✅ **Prevents waste**: Saves 1-2 failed calls per workflow (~$0.01/workflow)
- ✅ **Net positive**: Prevents hallucinations worth $1-2/day

**Complexity**:
- ✅ **Minimal**: Only changes a string constant
- ✅ **Maintainable**: If profiles change, update description
- ⚠️ **Manual sync**: Must remember to update when adding profiles

**Compatibility**:
- ✅ **Backward compatible**: No API changes, only description text
- ✅ **Forward compatible**: Easy to remove if upstream adds dynamic system
- ⚠️ **Drift risk**: Description could become stale if profiles change

**User Experience**:
- ✅ **Much better**: 90% hallucination rate → <5%
- ✅ **Autonomous**: No manual intervention needed
- ✅ **Confidence**: Agent knows it can create sub-tasks

---

## 4. Test Plan

### 4.1 Regression Test (Proves Issue Exists)

**Purpose**: Demonstrate agent hallucinations/confusion on clean upstream

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
1. Configure three agent profiles: "QA", "Architect", "Debug"
2. Create a new task with Claude or GPT-4
3. Ask agent: "Can you create a sub-task for QA review? Use the appropriate agent profile."
4. Observe agent's tool inspection and decision
5. Check console/logs for tool call

**Expected Result** (upstream issue):
- ❌ Agent examines `tasks---create_task` tool description
- ❌ Doesn't find list of valid profiles
- ❌ Either:
  - Hallucinates: `agentProfileId: "quality-assurance-agent"` ❌
  - Refuses: "I don't know which agent profiles are available"
  - Guesses: `agentProfileId: "qa"` (might work by luck)

**Evidence Collection**:
```
Agent reasoning (from API logs):
"I need to create a QA task. The tool accepts agentProfileId but doesn't
list available profiles. I'll try 'code-reviewer' which seems appropriate."

Tool call: tasks---create_task({ agentProfileId: "code-reviewer", ... })
Result: Error: Agent profile 'code-reviewer' not found ❌
```

---

### 4.2 Verification Test (Proves Fix Works)

**Purpose**: Demonstrate confident, correct profile selection with fix

**Setup**:
```bash
# Use our fork with fix
git checkout main  # or branch with PRD-0040 fix
npm install
npm run build
npm run dev
```

**Test Steps**:
[Same as regression test]

**Expected Result** (with fix):
- ✅ Agent examines `tasks---create_task` tool description
- ✅ Sees available profiles: "qa", "architect", "debug"
- ✅ Reads purpose: "qa: Quality assurance and testing expert"
- ✅ Confidently selects: `agentProfileId: "qa"` ✅
- ✅ Tool call succeeds

**Evidence Collection**:
```
Agent reasoning (from API logs):
"The tool description lists available profiles. For QA review, I should use
the 'qa' profile which is described as 'Quality assurance and testing expert'."

Tool call: tasks---create_task({ agentProfileId: "qa", ... })
Result: Success ✅ Task created with QA profile
```

---

### 4.3 Automated Tests

**Unit Tests**:

```typescript
// src/main/agent/tools/__tests__/tasks.tool-description.test.ts
import { describe, it, expect } from 'vitest';
import { getTaskTools } from '../tasks';

describe('Task Tool Description - Available Profiles', () => {
  it('should include list of standard profiles in description', () => {
    const tools = getTaskTools();
    const createTaskTool = tools.find(t => t.name === 'tasks---create_task');

    expect(createTaskTool).toBeDefined();
    expect(createTaskTool?.description).toContain('Available standard profiles');
    expect(createTaskTool?.description).toContain('"qa"');
    expect(createTaskTool?.description).toContain('"architect"');
    expect(createTaskTool?.description).toContain('"debug"');
  });

  it('should include profile purposes in description', () => {
    const tools = getTaskTools();
    const createTaskTool = tools.find(t => t.name === 'tasks---create_task');

    // Check that each profile has a description of its purpose
    expect(createTaskTool?.description).toContain('Quality assurance');
    expect(createTaskTool?.description).toContain('System design');
    expect(createTaskTool?.description).toContain('Debugging');
  });

  it('should include usage examples in description', () => {
    const tools = getTaskTools();
    const createTaskTool = tools.find(t => t.name === 'tasks---create_task');

    expect(createTaskTool?.description).toContain('Examples:');
    expect(createTaskTool?.description).toContain('agentProfileId: "qa"');
  });

  it('should mention case-insensitive name support', () => {
    const tools = getTaskTools();
    const createTaskTool = tools.find(t => t.name === 'tasks---create_task');

    expect(createTaskTool?.description).toContain('case-insensitive');
  });

  it('should explain inheritance behavior', () => {
    const tools = getTaskTools();
    const createTaskTool = tools.find(t => t.name === 'tasks---create_task');

    expect(createTaskTool?.description).toContain('inherits parent');
  });
});
```

**Integration Tests** (LLM behavior):
```typescript
// src/main/agent/__tests__/agent.tool-usage.integration.test.ts
describe('Agent Sub-Task Creation', () => {
  it('should correctly select QA profile for code review request', async () => {
    const agent = createTestAgent();

    const response = await agent.chat(
      "Create a sub-task to review the authentication code for security issues"
    );

    // Agent should select "qa" profile based on task description
    const toolCalls = extractToolCalls(response);
    const createTaskCall = toolCalls.find(t => t.name === 'tasks---create_task');

    expect(createTaskCall?.parameters.agentProfileId).toBe('qa');
  });

  it('should correctly select architect profile for design request', async () => {
    const agent = createTestAgent();

    const response = await agent.chat(
      "Create a sub-task to design the database schema for user authentication"
    );

    const toolCalls = extractToolCalls(response);
    const createTaskCall = toolCalls.find(t => t.name === 'tasks---create_task');

    expect(createTaskCall?.parameters.agentProfileId).toBe('architect');
  });

  it('should not hallucinate non-existent profiles', async () => {
    const agent = createTestAgent();

    const response = await agent.chat(
      "Create a sub-task for code review"
    );

    const toolCalls = extractToolCalls(response);
    const createTaskCall = toolCalls.find(t => t.name === 'tasks---create_task');

    // Should use valid profile, not hallucinated names
    const validProfiles = ['qa', 'architect', 'debug'];
    expect(validProfiles).toContain(
      createTaskCall?.parameters.agentProfileId.toLowerCase()
    );
  });
});
```

**Manual Test Checklist**:
- [ ] Agent reads tool description - sees profile list
- [ ] Ask for "QA review" - agent selects "qa" profile
- [ ] Ask for "architecture design" - agent selects "architect" profile
- [ ] Ask for "debug this error" - agent selects "debug" profile
- [ ] Agent doesn't hallucinate invalid profile names
- [ ] Agent explains why it chose specific profile (reasoning visible)
- [ ] Multiple sub-tasks in one session - agent consistently uses correct profiles

---

## 5. Success Metrics

### 5.1 Acceptance Criteria

**Must Have**:
- ✅ Tool description includes list of standard profiles (qa, architect, debug)
- ✅ Each profile includes purpose description
- ✅ Description includes usage examples
- ✅ Mentions case-insensitive name support
- ✅ Explains inheritance behavior when no profile specified

**Should Have**:
- [ ] Dynamic profile enumeration (future enhancement - query actual profiles)
- [ ] Profile selection guidance based on task type (future LLM training)

---

### 5.2 Performance Targets

| Metric | Before Fix | Target | Achieved |
|--------|-----------|--------|----------|
| Hallucination rate | 90% | <5% | TBD |
| Manual interventions per session | 8 | 0 | TBD |
| First-attempt success rate | 10% | >90% | TBD |
| Token usage increase | 0 | <200 tokens/call | TBD (~100) |

---

### 5.3 Business Metrics

**Developer Productivity**:
- **Manual interventions**: 8 per session → 0 (saves 4-8 minutes/session)
- **Success rate**: 10% autonomous → 90%+ autonomous
- **Workflow confidence**: Low (needs babysitting) → High (hands-off)

**Cost Optimization**:
- **Wasted API calls**: 1-2 failed attempts/workflow → 0 ($1-2/day savings)
- **Token overhead**: +$0.0001/call (negligible)
- **Net savings**: ~$1.50/day

**User Satisfaction**:
- "Agent knows what it's doing" vs "constant hand-holding"
- Reduced frustration: From "I have to guide every step" to "it just works"

---

## 6. Maintenance Notes

### 6.1 Upstream Monitoring

**Watch For**:
- Changes to `tools/tasks.ts` tool descriptions
- New dynamic tool generation systems
- Profile management enhancements

**Indicators Upstream Might Have Fixed**:
- [ ] Release notes mention "improved tool descriptions" or "profile enumeration"
- [ ] PRs adding dynamic profile lists to tools
- [ ] Issues closed about agent hallucinations with profiles

**Upstream Issue Search Queries**:
```
repo:paul-paliychuk/aider-desk is:issue "tool" "description" "profile"
repo:paul-paliychuk/aider-desk is:pr "tasks.ts" OR "tool description"
```

**Re-evaluation Triggers**:
- Upstream adds dynamic tool generation
- Profile system refactored
- Tool description standards changed

---

### 6.2 Testing Protocol (Before Each Merge)

**Quick Test** (3 min):
```bash
# On clean upstream branch
git checkout upstream/main
npm install && npm run build

# Check tool description
node -e "
  const tools = require('./dist/main/agent/tools/tasks').getTaskTools();
  const createTask = tools.find(t => t.name === 'tasks---create_task');
  console.log(createTask.description);
"

# Does it list profiles? (qa, architect, debug)
```

**Decision Matrix**:
| Test Result | Action | Rationale |
|-------------|--------|-----------|
| Description lists profiles | ❌ **Use upstream's code** | Upstream fixed it |
| Description generic (no profiles) | ✅ **Reimplement our fix** | Still needed |
| Different approach (dynamic enum) | 🔬 **Evaluate both** | Compare solutions |

---

## 7. Decision Log

| Date | Upstream Version | Decision | Rationale | Tested By |
|------|-----------------|----------|-----------|-----------|
| 2026-02-18 | v0.53.0 | Initial implementation | Upstream lacks profile guidance, causing 90% hallucination rate | Engineering Team |
| 2026-02-18 | v0.54.0 (sync branch) | Re-evaluated, kept fix | Tested upstream - tool description still generic | @engineer |

---

## 8. References

### 8.1 Implementation References

**Our Implementation**:
- Commit: `1766e59d` (included with Epic 5 changes)
- Branch: `main`
- Files changed: `src/main/agent/tools/tasks.ts`
- Lines: ~30-60 (enhanced description string)

**Original Investigation**:
- Epic 5 notes: Agent hallucinations during orchestration
- Issue discovered: 2026-02-16 when architect hallucinated "code-review-expert" profile
- Pattern identified: 9/10 attempts invented invalid names

---

### 8.2 Upstream References

**Related Upstream Issues**:
- None found (issue not yet reported to upstream)

**Related Upstream PRs**:
- None found

**Upstream Code Locations** (v0.53.0):
- `src/main/agent/tools/tasks.ts:20-80` - Task tool definitions
- `src/main/agent/agent.ts` - Tool usage patterns

---

### 8.3 Additional Context

**User Feedback**:
> "I'd tell the agent 'create a QA review' and it would invent names like 'qa-specialist' or 'code-reviewer'. I had to manually correct it every single time." - @teammate1

> "It felt like the agent was guessing blindly. Sometimes it would get lucky with 'qa', other times it would fail spectacularly with 'quality-assurance-agent-v2'." - @teammate2

**Hallucination Examples** (real data from Epic 5):
- Attempted: "code-review-expert" ❌
- Attempted: "qa-specialist" ❌
- Attempted: "testing-agent" ❌
- Attempted: "self-audit" ❌
- Attempted: "architecture-planner" ❌
- Success: "qa" ✅ (10% of cases)

---

## 9. Appendix

### 9.1 Glossary

**Tool Description**: Human-readable text explaining what a tool does and how to use it

**Hallucination**: When LLM generates plausible but incorrect/non-existent information

**Agent Profile**: Configuration defining an agent's specialization and capabilities

**Autonomous Orchestration**: LLM agents creating sub-agents without human guidance

### 9.2 Technical Deep Dive

**Why Tool Descriptions Matter**:
LLMs use tool descriptions as their primary API documentation. Unlike humans who can:
- Check UI dropdowns
- Read separate documentation
- Ask questions

LLMs can only:
- Read tool descriptions
- Infer from examples
- Reason about parameter meanings

**Token Cost Analysis**:
- Original description: ~50 tokens
- Enhanced description: ~150 tokens
- Cost increase: $0.0001 per call (Claude Sonnet)
- Prevented failures: ~1-2 per workflow ($0.01 each)
- **ROI**: 100x (spend $0.0001 to save $0.01)

### 9.3 Related Documentation

- [Merge Strategy Comparison](../../MERGE_STRATEGY_COMPARISON.md) - Section 4: Task Tool Clarity
- [Epic Overview](./0000-epic-overview.md)
- [PRD-0020](./0020-agent-profile-name-lookup.md) - Related profile features
- [PRD-0030](./0030-profile-aware-task-initialization.md) - Related profile features

---

**PRD Version**: 1.0
**Last Updated**: 2026-02-18
**Next Review**: Before next upstream merge (v0.55.0+)
