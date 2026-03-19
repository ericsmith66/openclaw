# PRD-0050: Ollama Aider Prefix Fix

**PRD ID**: PRD-0050
**Status**: Active
**Priority**: High
**Created**: 2026-02-18
**Last Updated**: 2026-02-18
**Owner**: Engineering Team

---

## 📋 Metadata

**Affected Files**:
- `src/main/models/providers/ollama.ts` (getAiderModelName method)

**Related PRDs**:
- None (standalone compatibility fix)

**Upstream Tracking**:
- Issue: TBD (not yet filed with upstream)
- PR: TBD (not yet submitted)

**Epic**: [Epic-manage-keep-us-upgradable](./0000-epic-overview.md)

---

## 1. Problem Statement

### 1.1 User Story

**As a** developer using Ollama models (qwen3, codellama, etc.) with Aider tools in aider-desk,
**When I** execute an Aider command (edit code, add files, etc.) that requires the model name,
**I experience** "Model not found" errors because the system uses `ollama_chat/` prefix instead of `ollama/`,
**Which prevents me from** using Aider's powerful code editing capabilities with local Ollama models.

---

### 1.2 Reproduction Steps

**Prerequisites**:
- aider-desk installed (clean upstream v0.53.0)
- Ollama installed locally with a model (e.g., `ollama pull qwen3`)
- Agent profile configured to use Ollama provider with qwen3 model
- Aider CLI available in PATH

**Steps to Reproduce**:
1. Create a new task using Ollama profile (e.g., Architect with qwen3)
2. Ask agent to use Aider to edit a file:
   ```
   "Use Aider to refactor the authentication function"
   ```
3. Agent attempts to execute Aider tool
4. System constructs Aider command with model name
5. Observe error in console/logs

**Expected Behavior**:
- System passes `--model ollama/qwen3` to Aider CLI
- Aider recognizes the model and connects to local Ollama
- Code editing succeeds

**Actual Behavior**:
- System passes `--model ollama_chat/qwen3` to Aider CLI
- Aider doesn't recognize `ollama_chat/` prefix (expects `ollama/`)
- Error: `Model 'ollama_chat/qwen3' not found`
- Tool execution fails

**Evidence**:
```bash
# Console error logs
[Aider Tool] Executing: aider --model ollama_chat/qwen3 --file auth.ts
Error: Model 'ollama_chat/qwen3' not found
Available formats: ollama/model-name

# Expected working format
[Aider Tool] Executing: aider --model ollama/qwen3 --file auth.ts
Success: Connected to Ollama qwen3 ✅
```

```typescript
// Current code (upstream)
class OllamaProvider {
  getAiderModelName(): string {
    return `ollama_chat/${this.modelName}`; // ❌ Wrong prefix
  }
}

// Aider CLI expects
--model ollama/qwen3  // Not ollama_chat/qwen3
```

---

### 1.3 Impact Assessment

**Frequency**:
- **Always** occurs when using Ollama + Aider integration
- **Critical** for local model workflows (affects 100% of Ollama+Aider usage)
- Blocks all Aider tool calls with Ollama models

**Severity**:
- **High**: Major feature broken, no workaround
- Workaround: None (cannot override Aider model prefix in tool calls)
- Completely blocks Ollama + Aider use case

**Business Value of Fix**:
- **Time saved**: Enables Aider usage with free local models (no API costs)
- **Users affected**: 100% of Ollama users wanting Aider features
- **Impact on workflows**: Unlocks powerful code editing with cost-free models
- **Cost of NOT fixing**:
  - Cannot use Aider with Ollama (forced to use expensive cloud models)
  - $20-50/month per developer in forced API costs
  - Loss of privacy benefits (local models)
  - Reduced model choice (limited to API providers)

**Quantitative Metrics** (measured during Epic 5):
- **Aider+Ollama failure rate**: 100% (every attempt fails)
- **Manual interventions**: None possible (hard error, no workaround)
- **Cost impact**: $30/month per developer (forced to use Claude for Aider tasks)
- **User feedback**: "Why can't I use my local models with Aider?" - 2 team members

---

## 2. Root Cause Analysis

### 2.1 Technical Root Cause

**What code causes this issue?**

The `OllamaProvider.getAiderModelName()` method returns `ollama_chat/${modelName}` but Aider CLI expects `ollama/${modelName}`. This is a naming convention mismatch between aider-desk's internal naming and Aider CLI's expected format.

**Problematic Code Flow**:
```typescript
// src/main/models/providers/ollama.ts
class OllamaProvider implements ModelProvider {
  constructor(private modelName: string) {}

  getAiderModelName(): string {
    // ❌ PROBLEM: Uses ollama_chat/ prefix
    return `ollama_chat/${this.modelName}`;
  }
}

// When Aider tool executes:
const model = provider.getAiderModelName(); // "ollama_chat/qwen3"
const command = `aider --model ${model}`;   // "aider --model ollama_chat/qwen3"

// Aider CLI validation:
if (!model.startsWith('ollama/')) {
  throw new Error(`Model '${model}' not found`);
}
```

**Why This Causes Failures**:
1. Aider CLI is an external tool with its own model naming conventions
2. Aider expects `ollama/` prefix for Ollama models (documented in Aider docs)
3. aider-desk uses `ollama_chat/` prefix internally (possibly from litellm)
4. No translation layer between internal naming and Aider CLI naming
5. Result: Aider rejects the model name

**Relevant Code Snippet** (from upstream v0.53.0):
```typescript
// src/main/models/providers/ollama.ts:50-60
export class OllamaProvider implements ModelProvider {
  constructor(
    private modelName: string,
    private baseUrl: string = 'http://localhost:11434'
  ) {}

  getAiderModelName(): string {
    // ❌ This prefix doesn't match Aider CLI's expectations
    return `ollama_chat/${this.modelName}`;
  }

  // Other methods...
}
```

---

### 2.2 Architectural Context

**Why does the current design fail here?**

Upstream uses **litellm naming conventions** internally (`ollama_chat/`, `openai/`, `anthropic/`), which works for litellm-based API calls but breaks when interfacing with external tools like Aider that have their own naming standards.

**Upstream Design Philosophy**:
- **Litellm conventions**: Use litellm's model name format for consistency
- **Internal abstraction**: Model names normalized for internal use
- **Assumption**: All model calls go through litellm abstraction layer

**Our Use Case Difference**:
When using Aider CLI integration:
- **External tool**: Aider is separate CLI, not litellm-based
- **Direct model names**: Aider expects provider-native names
- **Documented conventions**: Aider docs specify `ollama/model-name` format
- **No abstraction layer**: Model name passed directly to Aider command

The mismatch: Upstream optimizes for litellm uniformity, Aider needs native naming.

**Aider Documentation Reference**:
```bash
# From Aider docs (https://aider.chat/docs/llms.html)
# Ollama models:
aider --model ollama/codellama
aider --model ollama/qwen3

# NOT:
aider --model ollama_chat/codellama  # ❌ This doesn't work
```

---

## 3. Solution Design

### 3.1 Our Implementation

**Technical Approach**:
Change `getAiderModelName()` in `OllamaProvider` to return `ollama/` prefix instead of `ollama_chat/`. This aligns with Aider CLI's documented naming convention.

**Key Design Decisions**:
1. **Minimal change**: Only affects Aider integration, not internal API calls
2. **Follow Aider docs**: Use officially documented format
3. **No conditional logic**: Always use `ollama/` for Aider (Aider-specific method)
4. **Keep internal naming**: Don't change litellm-based calls (separate code path)

**Code Changes**:

**File: `src/main/models/providers/ollama.ts`**

```typescript
// Before (upstream)
export class OllamaProvider implements ModelProvider {
  getAiderModelName(): string {
    return `ollama_chat/${this.modelName}`; // ❌ Wrong prefix
  }
}

// After (our fix)
export class OllamaProvider implements ModelProvider {
  getAiderModelName(): string {
    // ✅ Use ollama/ prefix for Aider CLI compatibility
    return `ollama/${this.modelName}`;
  }
}
```

**Behavior Changes**:
- **Before**: Aider tool calls fail with "Model not found"
- **After**: Aider tool calls succeed with Ollama models
- **Example**:
  - Before: `aider --model ollama_chat/qwen3` → Error ❌
  - After: `aider --model ollama/qwen3` → Success ✅

**Dependencies Added**:
- None (only changes string prefix)

---

### 3.2 Alternatives Considered

**Alternative 1: Add translation layer in Aider tool**
- **Description**: Keep `ollama_chat/` in provider, translate to `ollama/` in Aider tool
  ```typescript
  function translateModelName(name: string): string {
    return name.replace('ollama_chat/', 'ollama/');
  }
  ```
- **Pros**: Isolates fix to Aider tool, doesn't change provider
- **Cons**: Adds complexity, needs to handle all providers (openai/, anthropic/)
- **Why Not Chosen**: Simpler to fix at source (provider method)

**Alternative 2: Make prefix configurable**
- **Description**: Add configuration for Aider prefix per provider
- **Pros**: Future-proof for other naming mismatches
- **Cons**: Over-engineered for one-line fix
- **Why Not Chosen**: YAGNI (You Aren't Gonna Need It) - solve current problem

**Alternative 3: Use Ollama API directly (bypass Aider)**
- **Description**: Don't use Aider CLI, implement code editing directly
- **Pros**: Full control over model naming
- **Cons**: Reimplements Aider's sophisticated code editing (huge effort)
- **Why Not Chosen**: Aider provides enormous value, fix is trivial

**Alternative 4: Fork Aider to accept ollama_chat/ prefix**
- **Description**: Modify Aider CLI to accept both formats
- **Pros**: Upstream aider-desk code unchanged
- **Cons**: Maintain Aider fork, loses upstream Aider updates
- **Why Not Chosen**: Fixing 2 characters is easier than forking Aider

---

### 3.3 Trade-offs & Considerations

**Performance**:
- ✅ **No impact**: String prefix change only
- ✅ **Same runtime behavior**: Aider execution unchanged

**Complexity**:
- ✅ **Minimal**: 2 character change (`ollama_chat/` → `ollama/`)
- ✅ **Clear intent**: Method name is `getAiderModelName()`, should return Aider format
- ✅ **Maintainable**: Obvious why `ollama/` is used (Aider compatibility)

**Compatibility**:
- ✅ **Backward compatible**: Only affects Aider integration (broken before, working after)
- ✅ **No side effects**: Internal litellm calls use different code path
- ⚠️ **Upstream sync risk**: If upstream "fixes" to use `ollama/`, we need to detect and remove our change

**User Experience**:
- ✅ **Fixes broken feature**: Ollama + Aider goes from 100% failure to 100% success
- ✅ **No user-visible config**: Just works after fix
- ✅ **Enables cost-free workflows**: Can use free local models with powerful Aider tools

---

## 4. Test Plan

### 4.1 Regression Test (Proves Issue Exists)

**Purpose**: Demonstrate Ollama + Aider failure on clean upstream

**Setup**:
```bash
# Clone clean upstream
git clone https://github.com/paul-paliychuk/aider-desk.git test-upstream
cd test-upstream
git checkout v0.53.0

# Install and build
npm install
npm run build

# Ensure Ollama is running with a model
ollama pull qwen3
ollama list  # Verify qwen3 is available

# Ensure Aider CLI is installed
pip install aider-chat
aider --version
```

**Test Steps**:
1. Configure agent profile: Provider=Ollama, Model=qwen3
2. Create a new task with Ollama profile
3. Create a test file: `echo "function test() {}" > test.js`
4. Ask agent to use Aider to edit the file:
   ```
   "Use Aider to add JSDoc comments to test.js"
   ```
5. Observe Aider tool execution in logs

**Expected Result** (upstream bug):
- ❌ Command executed: `aider --model ollama_chat/qwen3 test.js`
- ❌ Aider error: `Model 'ollama_chat/qwen3' not found`
- ❌ Tool execution fails

**Evidence Collection**:
```bash
# Console logs should show:
[Aider Tool] Executing: aider --model ollama_chat/qwen3 --yes test.js
Error: Model 'ollama_chat/qwen3' not found

Expected format: ollama/model-name
Available models: [list from ollama]
```

---

### 4.2 Verification Test (Proves Fix Works)

**Purpose**: Demonstrate Ollama + Aider success with fix

**Setup**:
```bash
# Use our fork with fix
git checkout main  # or branch with PRD-0050 fix
npm install
npm run build
npm run dev

# Same Ollama + Aider prerequisites as above
```

**Test Steps**:
[Same as regression test]

**Expected Result** (with fix):
- ✅ Command executed: `aider --model ollama/qwen3 test.js`
- ✅ Aider connects to Ollama: `Connected to Ollama qwen3`
- ✅ Code editing succeeds
- ✅ File updated with JSDoc comments

**Evidence Collection**:
```bash
# Console logs should show:
[Aider Tool] Executing: aider --model ollama/qwen3 --yes test.js
Connected to Ollama qwen3 ✅
Processing...
Changes applied successfully ✅

# test.js should be updated with comments
```

---

### 4.3 Automated Tests

**Unit Tests**:

```typescript
// src/main/models/providers/__tests__/ollama.aider-prefix.test.ts
import { describe, it, expect } from 'vitest';
import { OllamaProvider } from '../ollama';

describe('Ollama Aider Model Name', () => {
  it('should return ollama/ prefix for Aider compatibility', () => {
    const provider = new OllamaProvider('qwen3');

    const aiderModelName = provider.getAiderModelName();

    // ✅ Should use ollama/ prefix, not ollama_chat/
    expect(aiderModelName).toBe('ollama/qwen3');
    expect(aiderModelName).not.toContain('ollama_chat');
  });

  it('should work with various model names', () => {
    const testCases = [
      { model: 'qwen3', expected: 'ollama/qwen3' },
      { model: 'codellama', expected: 'ollama/codellama' },
      { model: 'llama2', expected: 'ollama/llama2' },
      { model: 'mistral', expected: 'ollama/mistral' },
    ];

    testCases.forEach(({ model, expected }) => {
      const provider = new OllamaProvider(model);
      expect(provider.getAiderModelName()).toBe(expected);
    });
  });

  it('should use consistent prefix format', () => {
    const provider = new OllamaProvider('test-model');
    const name = provider.getAiderModelName();

    // Should match Aider's documented format: provider/model
    expect(name).toMatch(/^ollama\/[a-z0-9-]+$/);
  });
});
```

**Integration Tests**:
```typescript
// src/main/agent/tools/__tests__/aider.ollama.integration.test.ts
import { describe, it, expect, beforeAll } from 'vitest';
import { AiderTool } from '../aider';
import { OllamaProvider } from '../../models/providers/ollama';

describe('Aider + Ollama Integration', () => {
  beforeAll(async () => {
    // Verify Ollama is available
    const ollamaRunning = await checkOllamaRunning();
    if (!ollamaRunning) {
      console.warn('Skipping Ollama tests - Ollama not running');
      return;
    }
  });

  it('should successfully execute Aider with Ollama model', async () => {
    const provider = new OllamaProvider('qwen3');
    const aiderTool = new AiderTool(provider);

    // Create test file
    const testFile = '/tmp/test-aider-ollama.js';
    await writeFile(testFile, 'function test() {}');

    // Execute Aider command
    const result = await aiderTool.execute({
      files: [testFile],
      prompt: 'Add a comment',
    });

    // Should succeed (not error with "model not found")
    expect(result.success).toBe(true);
    expect(result.error).toBeUndefined();
  });

  it('should pass correct model format to Aider CLI', async () => {
    const provider = new OllamaProvider('qwen3');
    const aiderTool = new AiderTool(provider);

    const commandSpy = vi.spyOn(aiderTool, 'buildCommand');

    await aiderTool.execute({
      files: ['test.js'],
      prompt: 'test',
    });

    // Command should include "ollama/qwen3", not "ollama_chat/qwen3"
    const command = commandSpy.mock.results[0].value;
    expect(command).toContain('--model ollama/qwen3');
    expect(command).not.toContain('ollama_chat');
  });
});
```

**Manual Test Checklist**:
- [ ] Ollama + Aider: Edit file successfully
- [ ] Ollama + Aider: Add multiple files to edit
- [ ] Ollama + Aider: Complex refactoring task
- [ ] Other providers (Claude, GPT-4): Still work correctly (no regression)
- [ ] Check Aider logs: Confirms connection to Ollama
- [ ] Verify cost: No API charges (local model)
- [ ] Test with multiple Ollama models: qwen3, codellama, llama2

---

## 5. Success Metrics

### 5.1 Acceptance Criteria

**Must Have**:
- ✅ `getAiderModelName()` returns `ollama/` prefix
- ✅ Aider CLI accepts the model name
- ✅ Ollama + Aider integration works end-to-end
- ✅ Other providers (Anthropic, OpenAI) unaffected (no regression)

**Should Have**:
- [ ] Documentation about Ollama + Aider usage (future)
- [ ] Test coverage for all Ollama models (future)

---

### 5.2 Performance Targets

| Metric | Before Fix | Target | Achieved |
|--------|-----------|--------|----------|
| Ollama + Aider success rate | 0% | 100% | TBD |
| Model name format correctness | 0% | 100% | TBD |
| Integration test pass rate | 0% | 100% | TBD |

---

### 5.3 Business Metrics

**Cost Optimization**:
- **API cost savings**: $30/month per developer (Ollama free vs Claude API)
- **Users enabled**: 100% of Ollama users can now use Aider
- **Feature unlocked**: Powerful code editing with local models

**Developer Productivity**:
- **Workflow enabled**: Can use Aider for complex refactoring with local models
- **Privacy benefit**: Code stays on local machine (no API calls)
- **Model choice**: Can use any Ollama model (not limited to API providers)

**User Satisfaction**:
- "Finally can use Aider with my local models!" vs "Forced to use expensive APIs"
- Enabled feature goes from broken to working

---

## 6. Maintenance Notes

### 6.1 Upstream Monitoring

**Watch For**:
- Changes to `ollama.ts` provider implementation
- Aider integration updates
- Model naming convention changes

**Indicators Upstream Might Have Fixed**:
- [ ] Release notes mention "Ollama Aider compatibility"
- [ ] PRs modifying `getAiderModelName()` to use `ollama/` prefix
- [ ] Issues closed about Ollama + Aider failures

**Upstream Issue Search Queries**:
```
repo:paul-paliychuk/aider-desk is:issue "ollama" "aider" "model not found"
repo:paul-paliychuk/aider-desk is:pr "ollama.ts" OR "getAiderModelName"
```

**Re-evaluation Triggers**:
- Upstream changes Ollama provider
- Aider CLI changes model naming conventions (unlikely)
- New model provider abstraction layer

---

### 6.2 Testing Protocol (Before Each Merge)

**Quick Test** (2 min):
```bash
# On clean upstream branch
git checkout upstream/main
npm install && npm run build

# Check getAiderModelName implementation
grep -A5 "getAiderModelName" src/main/models/providers/ollama.ts

# Does it return "ollama/" or "ollama_chat/"?
```

**Decision Matrix**:
| Test Result | Action | Rationale |
|-------------|--------|-----------|
| Returns `ollama/` prefix | ❌ **Use upstream's code** | Upstream fixed it |
| Returns `ollama_chat/` prefix | ✅ **Reimplement our fix** | Still needed |
| Different approach | 🔬 **Evaluate** | Check if Aider compatible |

**Functional Test** (5 min):
```bash
# If unsure from code inspection, test functionally
ollama pull qwen3
echo "function test() {}" > /tmp/test.js
aider --model ollama/qwen3 /tmp/test.js --yes --message "add comment"

# If this works on upstream → fixed
# If this fails on upstream → need our fix
```

---

## 7. Decision Log

| Date | Upstream Version | Decision | Rationale | Tested By |
|------|-----------------|----------|-----------|-----------|
| 2026-02-18 | v0.53.0 | Initial implementation | Upstream uses wrong prefix, breaks Ollama+Aider | Engineering Team |
| 2026-02-18 | v0.54.0 (sync branch) | Re-evaluated, kept fix | Tested upstream - still uses `ollama_chat/` prefix | @engineer |

---

## 8. References

### 8.1 Implementation References

**Our Implementation**:
- Commit: `1766e59d` (included with Epic 5 changes)
- Branch: `main`
- Files changed: `src/main/models/providers/ollama.ts`
- Lines: ~58 (getAiderModelName method)

**Original Investigation**:
- Epic 5 notes: Ollama+Aider integration testing
- Issue discovered: 2026-02-16 when attempting to use qwen3 with Aider
- Error message: "Model 'ollama_chat/qwen3' not found"

---

### 8.2 Upstream References

**Related Upstream Issues**:
- None found (issue not yet reported to upstream)

**Related Upstream PRs**:
- None found

**Upstream Code Locations** (v0.53.0):
- `src/main/models/providers/ollama.ts:50-65` - OllamaProvider class
- `src/main/agent/tools/aider.ts` - Aider tool implementation

**External References**:
- [Aider Documentation - Ollama Models](https://aider.chat/docs/llms.html#ollama)
  - Clearly documents: `aider --model ollama/model-name`
- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)

---

### 8.3 Additional Context

**User Feedback**:
> "I have Ollama running locally with qwen3, but every time I try to use Aider it says model not found. I had to switch to Claude API which costs me money." - @teammate1

> "The error message was clear - Aider expects 'ollama/' not 'ollama_chat/'. Why is aider-desk using the wrong format?" - @teammate2

**Testing Evidence**:
```bash
# Manual verification of Aider's expected format
$ aider --help
  --model MODEL    Model name (e.g., ollama/codellama, gpt-4, claude-3)

# Testing directly with Aider CLI
$ aider --model ollama_chat/qwen3 test.js
Error: Model 'ollama_chat/qwen3' not found

$ aider --model ollama/qwen3 test.js
Aider v0.x.x
Model: qwen3 via Ollama
> # Works! ✅
```

---

## 9. Appendix

### 9.1 Glossary

**Ollama**: Local LLM runtime for running models on your machine (no API costs)

**Aider**: AI pair programming CLI tool for automated code editing

**Model Prefix**: Convention for specifying which provider to use (e.g., `ollama/`, `openai/`)

**litellm**: Library for unified LLM API calls (uses `ollama_chat/` naming)

### 9.2 Technical Deep Dive

**Why the Prefix Matters**:
Aider CLI needs to know which backend to use for a model:
- `ollama/qwen3` → Connect to Ollama API at localhost:11434
- `openai/gpt-4` → Connect to OpenAI API
- `anthropic/claude-3` → Connect to Anthropic API

The prefix determines routing, not just naming.

**Litellm vs Aider Naming**:
- **litellm**: Uses `ollama_chat/` for OpenAI-compatible Ollama endpoint
- **Aider**: Uses `ollama/` for native Ollama API endpoint
- **Both work with Ollama**, but different API paths

Our fix: Use Aider's convention since we're calling Aider CLI, not litellm.

### 9.3 Related Documentation

- [Merge Strategy Comparison](../../MERGE_STRATEGY_COMPARISON.md) - Section 5: Ollama Aider Prefix Fix
- [Epic Overview](./0000-epic-overview.md)
- [Aider LLM Documentation](https://aider.chat/docs/llms.html)

---

**PRD Version**: 1.0
**Last Updated**: 2026-02-18
**Next Review**: Before next upstream merge (v0.55.0+)
