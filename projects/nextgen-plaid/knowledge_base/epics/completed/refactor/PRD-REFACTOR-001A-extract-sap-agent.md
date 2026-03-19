# PRD-REFACTOR-001A: Extract SapAgent Responsibilities

Part of Epic REFACTOR-001: Codebase Architectural Refactoring.

---

## Overview

Extract the multiple responsibilities currently embedded in the monolithic `SapAgent` module (927 lines) into focused, single-responsibility service classes.

This refactoring addresses the "God Object" anti-pattern by separating concerns while maintaining backward compatibility.

---

## Problem statement

The current `SapAgent` module (`app/services/sap_agent.rb`) violates the Single Responsibility Principle by handling:

1. **Command routing** (`process`, `process_command`)
2. **Code review operations** (`code_review`, `run_rubocop`, `diff_files`)
3. **Iteration management** (`iterate_prompt`, `adaptive_iterate`)
4. **Git orchestration** (`queue_handshake`, git operations)
5. **Backlog management** (`sync_backlog`, `update_backlog`, `prune_backlog`)
6. **Context pruning** (`prune_context`, `prune_by_heuristic`)
7. **Conductor orchestration** (`conductor`, `run_sub_agent`)
8. **Query processing** (`process_query`)
9. **Logging** (4 nearly identical logging methods)

This makes the module:
- Hard to test (too many dependencies)
- Hard to understand (cognitive overload)
- Hard to modify (changes affect multiple concerns)
- Hard to reuse (tightly coupled implementations)

---

## Proposed solution

### A) Extract service classes

Create five focused service classes:

1. **`SapAgent::CodeReviewService`**
   - Methods: `code_review`, `diff_files`, `prioritize_files`, `fetch_contents`, `run_rubocop`, `build_output`
   - Responsibility: Static code analysis and review
   - Location: `app/services/sap_agent/code_review_service.rb`

2. **`SapAgent::IterationService`**
   - Methods: `iterate_prompt`, `adaptive_iterate`, `generate_iteration_output`, `score_output`, `normalize_score`, `next_escalation_model`
   - Responsibility: Iterative prompt refinement and model escalation
   - Location: `app/services/sap_agent/iteration_service.rb`

3. **`SapAgent::GitOperationsService`**
   - Methods: `queue_handshake`, `git_log_for_uuid`, `git_status_clean?`, `stash_working_changes`, `pop_stash_with_retry`, `write_artifact`, `git_add`, `git_commit`, `tests_green?`, `git_push`
   - Responsibility: Git workflow and artifact queuing
   - Location: `app/services/sap_agent/git_operations_service.rb`

4. **`SapAgent::BacklogService`**
   - Methods: `sync_backlog`, `update_backlog`, `prune_backlog`
   - Responsibility: Backlog persistence and maintenance
   - Location: `app/services/sap_agent/backlog_service.rb`

5. **`SapAgent::ContextPruningService`**
   - Methods: `prune_context`, `prune_by_heuristic`, `ollama_relevance`, `age_weight`, `minify_context`
   - Responsibility: Context window management
   - Location: `app/services/sap_agent/context_pruning_service.rb`

### B) Refactor SapAgent to facade/coordinator

The main `SapAgent` module becomes a thin facade that:
- Routes commands to appropriate services
- Manages shared state (correlation_id, task_id, branch, model_used)
- Provides backward-compatible API
- Delegates to extracted services

Target: Reduce `SapAgent` to < 200 lines.

### C) Consolidate logging

Replace four nearly identical logging methods with a single parameterized method:

```ruby
def log_event(event_type, event_name, data = {})
  payload = {
    timestamp: Time.now.utc.iso8601,
    task_id: task_id,
    branch: branch,
    uuid: SecureRandom.uuid,
    correlation_id: correlation_id,
    model_used: model_used,
    event_type: event_type,
    event: event_name
  }.merge(data).compact

  logger.info(payload.to_json)
end
```

---

## Implementation plan

### Step 1: Extract CodeReviewService
- Create `app/services/sap_agent/code_review_service.rb`
- Move methods: `code_review`, `diff_files`, `prioritize_files`, `fetch_contents`, `run_rubocop`, `build_output`
- Extract shared constants (TOKEN_BUDGET, OFFENSE_LIMIT, etc.)
- Update SapAgent to delegate: `def self.code_review(...); CodeReviewService.new(...).call; end`
- Run existing tests

### Step 2: Extract IterationService
- Create `app/services/sap_agent/iteration_service.rb`
- Move iteration-related methods
- Handle shared state (model escalation, scoring)
- Update SapAgent to delegate
- Run existing tests

### Step 3: Extract GitOperationsService
- Create `app/services/sap_agent/git_operations_service.rb`
- Move git and queue_handshake methods
- Handle idempotency and stash management
- Update SapAgent to delegate
- Run existing tests

### Step 4: Extract BacklogService
- Create `app/services/sap_agent/backlog_service.rb`
- Move backlog methods
- Handle JSON persistence
- Update SapAgent to delegate
- Run existing tests

### Step 5: Extract ContextPruningService
- Create `app/services/sap_agent/context_pruning_service.rb`
- Move pruning methods
- Update SapAgent to delegate
- Run existing tests

### Step 6: Consolidate logging
- Replace 4 logging methods with single `log_event` method
- Update all call sites
- Run existing tests

### Step 7: Final cleanup
- Remove extracted methods from SapAgent
- Ensure all tests pass
- Update documentation

---

## Backward compatibility strategy

All existing public methods on `SapAgent` remain available with identical signatures:

```ruby
module SapAgent
  # Backward-compatible facade
  def self.code_review(**kwargs)
    CodeReviewService.new(
      task_id: task_id,
      branch: branch,
      correlation_id: correlation_id,
      model_used: model_used
    ).call(**kwargs)
  end

  def self.iterate_prompt(**kwargs)
    IterationService.new(
      task_id: task_id,
      correlation_id: correlation_id,
      model_used: model_used
    ).call(**kwargs)
  end

  # ... etc for all public methods
end
```

---

## Service class design pattern

Each service follows this pattern:

```ruby
module SapAgent
  class CodeReviewService
    attr_reader :task_id, :branch, :correlation_id, :model_used

    def initialize(task_id:, branch:, correlation_id:, model_used:)
      @task_id = task_id
      @branch = branch
      @correlation_id = correlation_id
      @model_used = model_used
    end

    def call(**kwargs)
      # Implementation
    end

    private

    def log_event(event, data = {})
      # Delegate to SapAgent logger or extract to shared concern
    end
  end
end
```

---

## Testing strategy

### Unit tests
- Test each extracted service in isolation
- Mock dependencies (file system, git commands, LLM calls)
- Focus on business logic, not integration

### Integration tests
- Existing `test/services/sap_agent_test.rb` continues to work
- Tests call public SapAgent methods (which delegate to services)
- No changes to test assertions

### Acceptance criteria for testing
- All existing tests pass without modification
- New service-specific tests added
- Code coverage maintained at 100% for all services
- No integration test changes required (backward compatibility)

---

## File structure after refactoring

```
app/services/
  sap_agent.rb (< 200 lines, facade)
  sap_agent/
    code_review_service.rb
    iteration_service.rb
    git_operations_service.rb
    backlog_service.rb
    context_pruning_service.rb
    rag_provider.rb (existing)
    artifact_command.rb (existing)
    # ... other existing files
```

---

## Acceptance criteria

- AC1: `SapAgent` module reduced to < 200 lines
- AC2: Five new service classes created with clear responsibilities
- AC3: All existing tests pass without modification
- AC4: New unit tests added for each service class
- AC5: No changes to public API signatures
- AC6: Logging consolidated to single parameterized method
- AC7: Documentation updated (YARD comments on new services)
- AC8: Code review confirms adherence to SOLID principles

---

## Risks and mitigation

### Risk: Breaking existing callers
- **Mitigation**: Facade pattern maintains all existing method signatures
- **Validation**: Run full test suite; grep codebase for all `SapAgent.` calls

### Risk: Performance regression
- **Mitigation**: Benchmark before/after on code_review and iterate_prompt
- **Validation**: Ensure < 5% performance impact

### Risk: Lost context between services
- **Mitigation**: Pass necessary state explicitly via initializers
- **Validation**: Integration tests verify end-to-end flows

---

## Success metrics

- Lines of code: `SapAgent` reduced from 927 to < 200 lines (78% reduction)
- Cyclomatic complexity: Each service < 10 (from 45+ in original)
- Test execution time: No increase > 5%
- Developer feedback: Subjective improvement in code comprehension

---

## Out of scope

- Changing external API contracts
- Modifying behavior or business logic
- Adding new features
- Performance optimization (beyond preventing regression)
- Extracting shared configuration (separate PRD)

---

## Rollout plan

1. Create feature branch `refactor/extract-sap-agent`
2. Implement Steps 1-7 incrementally with tests
3. Code review with 2+ approvers
4. Merge to main after CI passes
5. Monitor production logs for 24 hours
6. Rollback if any issues detected
