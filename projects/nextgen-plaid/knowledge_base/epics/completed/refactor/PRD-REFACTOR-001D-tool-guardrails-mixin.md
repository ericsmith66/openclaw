# PRD-REFACTOR-001D: DRY Up Tool Guardrails

Part of Epic REFACTOR-001: Codebase Architectural Refactoring.

---

## Overview

Eliminate duplicated `enforce_tool_guardrails!` methods across tool classes by extracting to a shared module or base class.

This is a quick-win refactoring with high impact: reduces ~30 lines of duplication per tool and establishes a pattern for future tools.

---

## Problem statement

The `enforce_tool_guardrails!` method is duplicated across multiple tool classes with **identical implementation**:

1. **SafeShellTool** (lines 121-142)
2. **GitTool** (lines 114-135)
3. **CodeAnalysisTool** (assumed similar pattern)
4. **ProjectSearchTool** (assumed similar pattern)

**Duplicated code** (~22 lines per tool):
```ruby
def enforce_tool_guardrails!(tool_context)
  turn = (tool_context.context[:turn_count] || tool_context.context["turn_count"] || 0).to_i
  tool_context.context[:tool_calls_by_turn] ||= {}
  tool_context.context[:tool_calls_by_turn][turn] ||= 0
  tool_context.context[:tool_calls_by_turn][turn] += 1

  tool_context.context[:tool_calls_total] ||= 0
  tool_context.context[:tool_calls_total] += 1

  max_total = tool_context.context[:max_tool_calls_total] || tool_context.context["max_tool_calls_total"]
  if max_total.present? && tool_context.context[:tool_calls_total] > max_total.to_i
    raise AiWorkflowService::GuardrailError, "max tool calls exceeded (#{tool_context.context[:tool_calls_total]}/#{max_total})"
  end

  if tool_context.context[:tool_calls_by_turn][turn] > MAX_CALLS_PER_TURN
    raise AiWorkflowService::GuardrailError, "max tool calls exceeded for turn #{turn}"
  end

  if tool_context.retry_count.to_i > MAX_RETRIES
    raise AiWorkflowService::GuardrailError, "max tool retries exceeded"
  end
end
```

**Constants also duplicated**:
```ruby
MAX_CALLS_PER_TURN = 30
MAX_RETRIES = 2
```

This violates the DRY principle and creates maintenance burden:
- Changes must be replicated across all tools
- Risk of inconsistency if one tool is updated but others aren't
- Increased cognitive load for developers

---

## Proposed solution

### Option A: Mixin module (RECOMMENDED)

Create `Agents::ToolGuardrailsMixin` to be included in tools:

```ruby
module Agents
  module ToolGuardrailsMixin
    MAX_CALLS_PER_TURN = 30
    MAX_RETRIES = 2

    private

    def enforce_tool_guardrails!(tool_context)
      turn = (tool_context.context[:turn_count] || tool_context.context["turn_count"] || 0).to_i
      tool_context.context[:tool_calls_by_turn] ||= {}
      tool_context.context[:tool_calls_by_turn][turn] ||= 0
      tool_context.context[:tool_calls_by_turn][turn] += 1

      tool_context.context[:tool_calls_total] ||= 0
      tool_context.context[:tool_calls_total] += 1

      max_total = tool_context.context[:max_tool_calls_total] || tool_context.context["max_tool_calls_total"]
      if max_total.present? && tool_context.context[:tool_calls_total] > max_total.to_i
        raise AiWorkflowService::GuardrailError, "max tool calls exceeded (#{tool_context.context[:tool_calls_total]}/#{max_total})"
      end

      if tool_context.context[:tool_calls_by_turn][turn] > max_calls_per_turn_limit
        raise AiWorkflowService::GuardrailError, "max tool calls exceeded for turn #{turn}"
      end

      if tool_context.retry_count.to_i > max_retries_limit
        raise AiWorkflowService::GuardrailError, "max tool retries exceeded"
      end
    end

    def max_calls_per_turn_limit
      # Allow tools to override via constant or method
      self.class.const_get(:MAX_CALLS_PER_TURN) rescue MAX_CALLS_PER_TURN
    end

    def max_retries_limit
      self.class.const_get(:MAX_RETRIES) rescue MAX_RETRIES
    end
  end
end
```

**Usage in tools**:
```ruby
class SafeShellTool < Agents::Tool
  include Agents::ToolGuardrailsMixin

  # Remove duplicated constants and method
  # MAX_CALLS_PER_TURN and enforce_tool_guardrails! now come from mixin
end
```

### Option B: Base class (ALTERNATIVE)

Create `Agents::ToolWithGuardrails` base class:

```ruby
module Agents
  class ToolWithGuardrails < Tool
    MAX_CALLS_PER_TURN = 30
    MAX_RETRIES = 2

    private

    def enforce_tool_guardrails!(tool_context)
      # ... implementation
    end
  end
end

class SafeShellTool < Agents::ToolWithGuardrails
  # Inherits enforce_tool_guardrails!
end
```

**Recommendation**: Use **Option A (Mixin)** because:
- More flexible (tools can still extend different base classes)
- Ruby composition pattern (prefer mixins over inheritance chains)
- Easier to test in isolation

---

## Implementation plan

### Step 1: Create mixin module
- Create `app/services/agents/tool_guardrails_mixin.rb`
- Extract constants and method from SafeShellTool
- Add override support for custom limits
- Write unit tests for mixin

### Step 2: Apply to SafeShellTool
- Include mixin in SafeShellTool
- Remove duplicated code (constants and method)
- Run SafeShellTool tests
- Verify no behavior changes

### Step 3: Apply to GitTool
- Include mixin in GitTool
- Remove duplicated code
- Run GitTool tests
- Verify no behavior changes

### Step 4: Apply to other tools
- Find all tools with duplicated guardrail logic (grep for `enforce_tool_guardrails!`)
- Apply mixin to CodeAnalysisTool, ProjectSearchTool, etc.
- Remove duplicated code from each
- Run all tool tests

### Step 5: Document pattern
- Add YARD documentation to mixin
- Update tool development guidelines
- Add example to CONTRIBUTING.md (if exists)

### Step 6: Final validation
- Run full test suite
- Verify all tools still enforce guardrails correctly
- Check for any tools that were missed

---

## Detailed code changes

### File: `app/services/agents/tool_guardrails_mixin.rb` (NEW)

```ruby
# frozen_string_literal: true

module Agents
  # Mixin for tools that need guardrail enforcement.
  #
  # Provides standard limits and enforcement for:
  # - Tool calls per turn
  # - Total tool calls across run
  # - Tool retry attempts
  #
  # Tools can override limits by defining constants:
  #   MAX_CALLS_PER_TURN = 50 (default: 30)
  #   MAX_RETRIES = 5 (default: 2)
  #
  # @example
  #   class MyTool < Agents::Tool
  #     include Agents::ToolGuardrailsMixin
  #
  #     def perform(tool_context, **args)
  #       enforce_tool_guardrails!(tool_context)
  #       # ... tool logic
  #     end
  #   end
  module ToolGuardrailsMixin
    DEFAULT_MAX_CALLS_PER_TURN = 30
    DEFAULT_MAX_RETRIES = 2

    private

    # Enforces guardrails on tool execution.
    #
    # Tracks and limits:
    # - Tool calls per turn (prevents infinite loops)
    # - Total tool calls (prevents runaway costs)
    # - Retry attempts (prevents retry storms)
    #
    # @param tool_context [Agents::ToolContext] the tool execution context
    # @raise [AiWorkflowService::GuardrailError] if any limit is exceeded
    def enforce_tool_guardrails!(tool_context)
      turn = (tool_context.context[:turn_count] || tool_context.context["turn_count"] || 0).to_i

      # Track calls per turn
      tool_context.context[:tool_calls_by_turn] ||= {}
      tool_context.context[:tool_calls_by_turn][turn] ||= 0
      tool_context.context[:tool_calls_by_turn][turn] += 1

      # Track total calls
      tool_context.context[:tool_calls_total] ||= 0
      tool_context.context[:tool_calls_total] += 1

      # Check total limit (if set)
      max_total = tool_context.context[:max_tool_calls_total] || tool_context.context["max_tool_calls_total"]
      if max_total.present? && tool_context.context[:tool_calls_total] > max_total.to_i
        raise AiWorkflowService::GuardrailError, "max tool calls exceeded (#{tool_context.context[:tool_calls_total]}/#{max_total})"
      end

      # Check per-turn limit
      if tool_context.context[:tool_calls_by_turn][turn] > max_calls_per_turn_limit
        raise AiWorkflowService::GuardrailError, "max tool calls exceeded for turn #{turn}"
      end

      # Check retry limit
      if tool_context.retry_count.to_i > max_retries_limit
        raise AiWorkflowService::GuardrailError, "max tool retries exceeded"
      end
    end

    # Returns the maximum calls allowed per turn.
    # Tools can override by defining MAX_CALLS_PER_TURN constant.
    def max_calls_per_turn_limit
      self.class.const_get(:MAX_CALLS_PER_TURN)
    rescue NameError
      DEFAULT_MAX_CALLS_PER_TURN
    end

    # Returns the maximum retry attempts allowed.
    # Tools can override by defining MAX_RETRIES constant.
    def max_retries_limit
      self.class.const_get(:MAX_RETRIES)
    rescue NameError
      DEFAULT_MAX_RETRIES
    end
  end
end
```

### File: `app/tools/safe_shell_tool.rb` (MODIFIED)

```ruby
# frozen_string_literal: true

require "open3"
require "json"
require "fileutils"
require "shellwords"

require Rails.root.join("app", "services", "agents", "tool_output_truncator")
require Rails.root.join("app", "services", "agents", "tool_guardrails_mixin")

class SafeShellTool < Agents::Tool
  include Agents::ToolGuardrailsMixin

  description "Run an allowlisted shell command inside the per-run sandbox worktree (dry-run by default)."
  param :cmd, type: "string", desc: "Shell command to run (deny-by-default allowlist)"

  # Override default limits if needed (optional)
  # MAX_CALLS_PER_TURN = 30
  # MAX_RETRIES = 2

  ALLOWLIST = [
    # ... existing allowlist
  ].freeze

  DENYLIST = [
    # ... existing denylist
  ].freeze

  def perform(tool_context, cmd:)
    # ... existing logic

    enforce_tool_guardrails!(tool_context)

    # ... rest of implementation
  end

  private

  # Remove duplicated enforce_tool_guardrails! method
  # Now provided by mixin

  def format_result(...)
    # ... existing
  end

  def record_test_status!(...)
    # ... existing
  end
end
```

---

## Testing strategy

### Unit tests for mixin
Create `test/services/agents/tool_guardrails_mixin_test.rb`:

```ruby
require "test_helper"

class ToolGuardrailsMixinTest < ActiveSupport::TestCase
  class TestTool
    include Agents::ToolGuardrailsMixin

    attr_reader :context

    def initialize
      @context = { tool_calls_by_turn: {}, tool_calls_total: 0 }
    end

    def call(tool_context)
      enforce_tool_guardrails!(tool_context)
    end
  end

  test "enforces per-turn limit" do
    tool = TestTool.new
    tool_context = mock_tool_context(turn_count: 1)

    31.times { tool.call(tool_context) }

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.call(tool_context)
    end
  end

  test "enforces total limit" do
    # ... test total call limit
  end

  test "enforces retry limit" do
    # ... test retry limit
  end

  test "allows tools to override limits" do
    # ... test custom constant overrides
  end
end
```

### Integration tests
- Existing tool tests automatically verify mixin behavior
- No test changes required (backward compatible)
- Run full test suite to verify

---

## Acceptance criteria

- AC1: `Agents::ToolGuardrailsMixin` module created with full documentation
- AC2: Mixin applied to SafeShellTool, GitTool, and all other tools with duplicated logic
- AC3: Duplicated `enforce_tool_guardrails!` methods removed from all tools
- AC4: Unit tests added for mixin (100% coverage)
- AC5: All existing tool tests pass without modification
- AC6: At least 60 lines of duplicated code eliminated (30 lines × 2 tools minimum)
- AC7: Pattern documented for future tool development

---

## Affected files

**New files**:
- `app/services/agents/tool_guardrails_mixin.rb`
- `test/services/agents/tool_guardrails_mixin_test.rb`

**Modified files** (remove duplication):
- `app/tools/safe_shell_tool.rb`
- `app/tools/git_tool.rb`
- `app/tools/code_analysis_tool.rb` (if applicable)
- `app/tools/project_search_tool.rb` (if applicable)

**Lines removed**: ~30 per tool × 4 tools = **~120 lines eliminated**

---

## Risks and mitigation

### Risk: Breaking tool behavior
- **Mitigation**: Mixin provides identical logic; comprehensive tests
- **Validation**: Run all tool tests; compare behavior before/after

### Risk: Tools need custom limits
- **Mitigation**: Support constant overrides (MAX_CALLS_PER_TURN, MAX_RETRIES)
- **Validation**: Test custom limit functionality

### Risk: Missing tools during refactoring
- **Mitigation**: Grep for `enforce_tool_guardrails!` to find all instances
- **Validation**: Code review checklist

---

## Success metrics

- Code duplication: Reduced by ~120 lines
- Maintainability: Single source of truth for guardrail logic
- Consistency: All tools enforce identical limits
- Future velocity: New tools can include mixin in 1 line vs 30 lines

---

## Out of scope

- Changing guardrail behavior or limits
- Adding new guardrail rules
- Extracting other tool patterns (separate PRDs)
- Performance optimization

---

## Rollout plan

1. Create feature branch `refactor/tool-guardrails-mixin`
2. Implement Steps 1-6 incrementally
3. Run full test suite after each step
4. Code review with 1+ approver
5. Merge to main after CI passes
6. No production monitoring needed (pure refactoring, covered by tests)
