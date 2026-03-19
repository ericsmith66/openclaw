# PRD-REFACTOR-001B: Refactor AiWorkflowService

Part of Epic REFACTOR-001: Codebase Architectural Refactoring.

---

## Overview

Extract the multiple responsibilities currently embedded in `AiWorkflowService` (825 lines) into focused, cohesive service classes while maintaining the existing public API.

This refactoring addresses excessive coupling and improves testability by separating concerns.

---

## Problem statement

The current `AiWorkflowService` (`app/services/ai_workflow_service.rb`) handles too many responsibilities:

1. **Workflow orchestration** (`run`, `resolve_feedback`)
2. **Agent building** (`build_agent`, `persona_instructions`)
3. **Context management** (`load_existing_context`, `build_initial_context`, `normalize_context!`)
4. **Guardrail enforcement** (`enforce_turn_guardrails!`)
5. **Handoff finalization** (`finalize_hybrid_handoff!`)
6. **Artifact writing** (entire `ArtifactWriter` class nested inside, lines 632-824)
7. **RAG injection** (inline DB schema reading, file reads)
8. **Model routing** (routing policy calls)

This makes the service:
- Difficult to test (too many collaborators)
- Hard to understand (825 lines in one file)
- Brittle (changes ripple through multiple concerns)
- Difficult to parallelize development (hot conflict zone)

---

## Proposed solution

### A) Extract service classes

Create four focused classes:

1. **`AiWorkflow::AgentFactory`**
   - Methods: `build_agent`, `persona_instructions`, `build_cwa_agent`, `build_planner_agent`, `build_coordinator_agent`, `build_sap_agent`
   - Responsibility: Agent configuration and instantiation
   - Location: `app/services/ai_workflow/agent_factory.rb`

2. **`AiWorkflow::ContextManager`**
   - Methods: `load_existing_context`, `build_initial_context`, `normalize_context!`, `prepare_rag_context`
   - Responsibility: Context lifecycle management
   - Location: `app/services/ai_workflow/context_manager.rb`

3. **`AiWorkflow::GuardrailEnforcer`**
   - Methods: `enforce_turn_guardrails!`, `check_escalation_conditions`
   - Responsibility: Safety checks and error handling
   - Location: `app/services/ai_workflow/guardrail_enforcer.rb`

4. **`AiWorkflow::ArtifactWriter`** (move from nested class)
   - Entire nested `ArtifactWriter` class (lines 632-824)
   - Responsibility: Event logging, artifact persistence, broadcast
   - Location: `app/services/ai_workflow/artifact_writer.rb`

### B) Simplify AiWorkflowService

The main `AiWorkflowService` becomes an orchestrator that:
- Coordinates workflow execution
- Delegates to specialized services
- Maintains public API compatibility
- Handles high-level error recovery

Target: Reduce `AiWorkflowService` to < 300 lines.

---

## Implementation plan

### Step 1: Extract ArtifactWriter
- Create `app/services/ai_workflow/artifact_writer.rb`
- Move nested `ArtifactWriter` class (lines 632-824)
- Update requires in `AiWorkflowService`
- Change references from `AiWorkflowService::ArtifactWriter` to `AiWorkflow::ArtifactWriter`
- Run existing tests

### Step 2: Extract AgentFactory
- Create `app/services/ai_workflow/agent_factory.rb`
- Move `build_agent` and `persona_instructions` methods
- Extract inline agent construction logic from `run` and `run_once`
- Create `build_agents` method that returns all 4 agents configured
- Update `AiWorkflowService` to use factory
- Run existing tests

### Step 3: Extract ContextManager
- Create `app/services/ai_workflow/context_manager.rb`
- Move context-related methods
- Extract RAG context preparation logic
- Extract schema injection logic
- Update `AiWorkflowService` to use manager
- Run existing tests

### Step 4: Extract GuardrailEnforcer
- Create `app/services/ai_workflow/guardrail_enforcer.rb`
- Move `enforce_turn_guardrails!` method
- Extract escalation condition checking
- Update `AiWorkflowService` to use enforcer
- Run existing tests

### Step 5: Refactor run method
- Simplify `run` method using extracted services
- Reduce inline logic
- Improve readability
- Run existing tests

### Step 6: Refactor handoff finalization
- Consider extracting `finalize_hybrid_handoff!` to separate class
- Or keep in main service if < 50 lines after other extractions
- Run existing tests

### Step 7: Final cleanup
- Remove extracted code from `AiWorkflowService`
- Update YARD documentation
- Ensure all tests pass
- Measure final line count

---

## Service class designs

### AgentFactory

```ruby
module AiWorkflow
  class AgentFactory
    def initialize(model:, test_overrides: {}, common_context: "")
      @model = model
      @test_overrides = test_overrides
      @common_context = common_context
    end

    def build_agents
      {
        sap: build_sap_agent,
        coordinator: build_coordinator_agent,
        planner: build_planner_agent,
        cwa: build_cwa_agent
      }
    end

    def build_cwa_agent
      # Extract from current inline logic
    end

    private

    def persona_instructions(key)
      # Load from personas.yml
    end

    def model_for(agent_key)
      # Handle test overrides
    end
  end
end
```

### ContextManager

```ruby
module AiWorkflow
  class ContextManager
    def self.load_existing(correlation_id)
      # Load from run.json
    end

    def self.build_initial(correlation_id)
      # Build default context
    end

    def self.normalize!(result)
      # Normalize context fields
    end

    def self.prepare_rag_context(opts = {})
      # Load static docs, schema, etc.
      # Return combined RAG string
    end
  end
end
```

### GuardrailEnforcer

```ruby
module AiWorkflow
  class GuardrailEnforcer
    def self.enforce_turn_limit!(result, max_turns:, artifacts:)
      turns = (result.context[:turns_count] || 0).to_i
      return if turns < max_turns

      result.context[:workflow_state] = "escalated_to_human"
      artifacts.record_event(type: "max_turns_exceeded", turns_count: turns, max_turns: max_turns)
      raise AiWorkflowService::EscalateToHumanError, "max turns exceeded"
    end
  end
end
```

---

## Backward compatibility strategy

All existing public methods on `AiWorkflowService` remain available with identical signatures:

```ruby
class AiWorkflowService
  def self.run(prompt:, correlation_id: SecureRandom.uuid, **opts)
    # Orchestrate using extracted services
    factory = AiWorkflow::AgentFactory.new(model: opts[:model], test_overrides: opts[:test_overrides] || {})
    context = AiWorkflow::ContextManager.load_existing(correlation_id) || AiWorkflow::ContextManager.build_initial(correlation_id)
    artifacts = AiWorkflow::ArtifactWriter.new(correlation_id)

    agents = factory.build_agents
    runner = Agents::Runner.with_agents(*agents.values)

    # ... rest of orchestration
  end
end
```

---

## File structure after refactoring

```
app/services/
  ai_workflow_service.rb (< 300 lines, orchestrator)
  ai_workflow/
    agent_factory.rb
    context_manager.rb
    guardrail_enforcer.rb
    artifact_writer.rb
```

---

## Testing strategy

### Unit tests
- Test each extracted service in isolation
- Mock file system, database, and external dependencies
- Focus on single responsibility per service

### Integration tests
- Existing `test/services/ai_workflow_service_test.rb` continues to work unchanged
- Tests call public `AiWorkflowService.run` method
- No changes to test assertions (backward compatibility)

### New test files
- `test/services/ai_workflow/agent_factory_test.rb`
- `test/services/ai_workflow/context_manager_test.rb`
- `test/services/ai_workflow/guardrail_enforcer_test.rb`
- `test/services/ai_workflow/artifact_writer_test.rb`

---

## Acceptance criteria

- AC1: `AiWorkflowService` reduced to < 300 lines
- AC2: Four new service classes created in `ai_workflow/` namespace
- AC3: All existing tests pass without modification
- AC4: New unit tests added for each extracted service
- AC5: No changes to public API signatures
- AC6: `ArtifactWriter` moved from nested class to separate file
- AC7: YARD documentation updated for all services
- AC8: Code review confirms improved testability and separation of concerns

---

## RAG context extraction detail

Extract inline RAG logic to `ContextManager.prepare_rag_context`:

**Before** (inline in `run` method):
```ruby
# Lines 216-244: inline RAG loading
common_context = "\n\n--- VISION ---\n#{File.read(...)}"
common_context += "\n\n--- PROJECT STRUCTURE ---\n#{`find ...`}"
# ... more inline logic
```

**After** (delegated):
```ruby
common_context = AiWorkflow::ContextManager.prepare_rag_context(
  rag_level: opts[:rag_level],
  include_schema: true,
  test_overrides: opts[:test_overrides]
)
```

---

## Agent construction extraction detail

Extract repetitive agent building to `AgentFactory.build_agents`:

**Before** (lines 262-330):
```ruby
cwa_agent = Agents::Registry.fetch(:cwa, model: model, instructions: cwa_instructions)
planner_agent = build_agent(name: "Planner", instructions: ..., model: ..., handoff_agents: [...], tools: [...])
coordinator_agent = build_agent(name: "Coordinator", instructions: ..., model: ..., handoff_agents: [...])
cwa_agent.register_handoffs(coordinator_agent)
sap_agent = build_agent(name: "SAP", instructions: ..., model: ..., handoff_agents: [...])
```

**After**:
```ruby
agents = AiWorkflow::AgentFactory.new(
  model: model,
  test_overrides: test_overrides,
  common_context: common_context
).build_agents

agents[:cwa].register_handoffs(agents[:coordinator])
```

---

## Risks and mitigation

### Risk: Breaking existing workflows
- **Mitigation**: Maintain exact public API; comprehensive test suite
- **Validation**: Run full integration tests; monitor staging environment

### Risk: Lost context between services
- **Mitigation**: Pass explicit parameters; avoid hidden coupling
- **Validation**: Review dependency graphs; ensure services are stateless

### Risk: Performance regression from additional layers
- **Mitigation**: Benchmark critical paths; minimize object allocations
- **Validation**: Profiling before/after; ensure < 5% overhead

---

## Success metrics

- Lines of code: Reduced from 825 to < 300 lines (64% reduction)
- Cyclomatic complexity: Main service < 15 (from 35+)
- Test isolation: Each service testable in < 1 second
- Developer feedback: Improved code comprehension scores

---

## Out of scope

- Changing workflow behavior or logic
- Modifying external API contracts
- Adding new features
- Performance optimization (beyond preventing regression)
- Extracting `finalize_hybrid_handoff!` (deferred to future PRD if still > 300 lines)

---

## Rollout plan

1. Create feature branch `refactor/extract-ai-workflow`
2. Implement Steps 1-7 incrementally with tests
3. Code review with 2+ approvers
4. Run CI/CD pipeline
5. Deploy to staging for 24-hour observation
6. Merge to main after validation
7. Monitor production for 48 hours
8. Rollback if any issues detected
