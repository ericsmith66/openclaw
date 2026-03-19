# PRD-REFACTOR-001E: Extract SdlcValidationScoring Responsibilities

Part of Epic REFACTOR-001: Codebase Architectural Refactoring.

---

## Overview

Extract the multiple responsibilities currently embedded in `Agents::SdlcValidationScoring` (412 lines) into focused, single-responsibility service classes.

This refactoring separates concerns around evidence gathering, validation, scoring, and report generation.

---

## Problem statement

The current `Agents::SdlcValidationScoring` module (`lib/agents/sdlc_validation_scoring.rb`) violates the Single Responsibility Principle by handling:

1. **Evidence gathering** (lines 136-174: file reads, artifact queries, handoff collection)
2. **Schema validation** (lines 176-214: micro_tasks and handoffs validation)
3. **Scoring logic** (lines 216-260: rubric calculation, pass/fail determination)
4. **Report generation** (lines 310-409: Markdown formatting, human-readable reports)
5. **Persistence** (lines 28-98: JSON/Markdown file writing, artifact updates)
6. **Phase finalization** (lines 111-127: artifact state transitions)

This makes the module:
- Hard to test (too many file system dependencies)
- Hard to understand (cognitive overload from 400+ lines)
- Hard to extend (new validation rules require touching multiple concerns)
- Hard to reuse (tightly coupled to SDLC CLI context)

---

## Proposed solution

### A) Extract service classes

Create four focused service classes:

1. **`Agents::Sdlc::EvidenceGatherer`**
   - Methods: `gather_evidence`, `read_json_file`, `file_excerpt`
   - Responsibility: Collect artifacts, logs, and test results
   - Location: `lib/agents/sdlc/evidence_gatherer.rb`

2. **`Agents::Sdlc::Validator`**
   - Methods: `validate_evidence`, `validate_micro_tasks`, `validate_handoffs`
   - Responsibility: Schema validation and consistency checks
   - Location: `lib/agents/sdlc/validator.rb`

3. **`Agents::Sdlc::Scorer`**
   - Methods: `score_evidence`, `calculate_rubric`, `determine_pass_fail`, `suggestions_from_breakdown`, `cwa_summary_indicates_green?`
   - Responsibility: Rubric calculation and scoring logic
   - Location: `lib/agents/sdlc/scorer.rb`

4. **`Agents::Sdlc::ReportGenerator`**
   - Methods: `build_run_summary_md`, `build_summary_log`, `format_artifact_line`, `format_rubric`
   - Responsibility: Human-readable report formatting
   - Location: `lib/agents/sdlc/report_generator.rb`

### B) Simplify SdlcValidationScoring to orchestrator

The main `Agents::SdlcValidationScoring` module becomes an orchestrator that:
- Delegates to specialized services
- Handles file writing and persistence
- Coordinates phase finalization
- Maintains backward-compatible API

Target: Reduce `SdlcValidationScoring` to < 150 lines.

---

## Implementation plan

### Step 1: Extract EvidenceGatherer
- Create `lib/agents/sdlc/evidence_gatherer.rb`
- Move evidence gathering methods
- Make file reading configurable (inject file system adapter for testing)
- Update SdlcValidationScoring to use gatherer
- Run existing tests

### Step 2: Extract Validator
- Create `lib/agents/sdlc/validator.rb`
- Move validation methods
- Make validation rules declarative/configurable
- Update SdlcValidationScoring to use validator
- Run existing tests

### Step 3: Extract Scorer
- Create `lib/agents/sdlc/scorer.rb`
- Move scoring methods
- Extract rubric calculation logic
- Update SdlcValidationScoring to use scorer
- Run existing tests

### Step 4: Extract ReportGenerator
- Create `lib/agents/sdlc/report_generator.rb`
- Move report formatting methods
- Support multiple output formats (future: JSON, HTML)
- Update SdlcValidationScoring to use generator
- Run existing tests

### Step 5: Refactor orchestrator
- Simplify `run` method to coordinate services
- Keep only file writing and persistence logic
- Run existing tests

### Step 6: Final cleanup
- Remove extracted code
- Update YARD documentation
- Ensure all tests pass
- Measure final line count

---

## Service class designs

### EvidenceGatherer

```ruby
module Agents
  module Sdlc
    class EvidenceGatherer
      attr_reader :run_id, :artifact, :test_artifacts_dir

      def initialize(run_id:, artifact:, test_artifacts_dir:)
        @run_id = run_id
        @artifact = artifact
        @test_artifacts_dir = test_artifacts_dir
      end

      def call
        {
          "micro_tasks" => gather_micro_tasks,
          "handoffs" => gather_handoffs,
          "tests" => gather_test_evidence,
          "files" => gather_file_evidence,
          "artifact" => gather_artifact_metadata
        }.compact
      end

      private

      def gather_micro_tasks
        artifact&.payload&.fetch("micro_tasks", nil) ||
          read_json_file(test_artifacts_dir.join("micro_tasks.json"))
      end

      def gather_handoffs
        handoff_files = Dir.glob(test_artifacts_dir.join("handoffs/*.json"))
        handoffs = handoff_files.filter_map { |p| read_json_file(p) }

        {
          "count" => handoffs.length,
          "files" => handoff_files.map { |p| relative_path(p) },
          "samples" => handoffs.first(3)
        }
      end

      # ... other gather methods
    end
  end
end
```

### Validator

```ruby
module Agents
  module Sdlc
    class Validator
      MICRO_TASK_SCHEMA = {
        required_fields: %w[id title estimate],
        field_types: { "id" => String, "title" => String, "estimate" => String }
      }.freeze

      def initialize(evidence)
        @evidence = evidence
      end

      def call
        {
          "micro_tasks" => validate_micro_tasks,
          "handoffs" => validate_handoffs
        }
      end

      private

      def validate_micro_tasks
        micro_tasks = @evidence["micro_tasks"]
        errors = []

        return { "valid" => false, "errors" => ["micro_tasks_missing"] } unless micro_tasks.is_a?(Array) && micro_tasks.any?

        micro_tasks.each_with_index do |task, idx|
          errors.concat(validate_micro_task(task, idx))
        end

        { "valid" => errors.empty?, "errors" => errors }
      end

      def validate_micro_task(task, idx)
        errors = []
        return [errors << "micro_tasks[#{idx}]_not_object"] unless task.is_a?(Hash)

        MICRO_TASK_SCHEMA[:required_fields].each do |field|
          value = task[field] || task[field.to_sym]
          errors << "micro_tasks[#{idx}].#{field}_missing" if value.to_s.strip.empty?
        end

        errors
      end

      def validate_handoffs
        # Similar pattern for handoffs
      end
    end
  end
end
```

### Scorer

```ruby
module Agents
  module Sdlc
    class Scorer
      RUBRIC = {
        micro_tasks_valid: { weight: 2, description: "Micro-tasks present and valid" },
        prd_present: { weight: 1, description: "PRD artifact exists" },
        handoffs_present: { weight: 1, description: "Agent handoffs captured" },
        implementation_notes_present: { weight: 2, description: "Implementation notes exist" },
        tests_green: { weight: 3, description: "Tests passed" },
        no_errors: { weight: 1, description: "No errors in logs" }
      }.freeze

      PASSING_SCORE = 7
      MAX_SCORE = RUBRIC.values.sum { |v| v[:weight] }

      def initialize(evidence:, validation:, error_context: {})
        @evidence = evidence
        @validation = validation
        @error_context = error_context
      end

      def call
        breakdown = calculate_rubric
        score = breakdown.values.sum
        score = [[score, 0].max, MAX_SCORE].min

        {
          "score" => score,
          "pass" => score >= PASSING_SCORE,
          "rubric" => breakdown,
          "notes" => generate_suggestions(breakdown)
        }
      end

      private

      def calculate_rubric
        {
          "micro_tasks_valid" => score_micro_tasks_valid,
          "prd_present" => score_prd_present,
          "handoffs_present" => score_handoffs_present,
          "implementation_notes_present" => score_implementation_notes,
          "tests_green" => score_tests_green,
          "no_errors" => score_no_errors
        }
      end

      def score_micro_tasks_valid
        @validation.dig("micro_tasks", "valid") ? 2 : 0
      end

      # ... other scoring methods
    end
  end
end
```

### ReportGenerator

```ruby
module Agents
  module Sdlc
    class ReportGenerator
      def initialize(run_metadata:, evidence:, validation:, scoring:)
        @run_metadata = run_metadata
        @evidence = evidence
        @validation = validation
        @scoring = scoring
      end

      def generate_markdown
        <<~MD
          # SDLC CLI Run Summary

          ## Run metadata
          #{format_run_metadata}

          ## Artifacts
          #{format_artifact_section}

          ## Scoring + suggestions
          #{format_scoring_section}

          ## Errors / Escalations
          #{format_errors_section}
        MD
      end

      def generate_log
        <<~LOG
          run_id=#{@run_metadata[:run_id]}
          score=#{@scoring["score"]}
          pass=#{@scoring["pass"]}
        LOG
      end

      private

      def format_run_metadata
        # Format metadata section
      end

      # ... other formatting methods
    end
  end
end
```

---

## Orchestrator refactoring

**Before** (412 lines):
```ruby
module Agents
  class SdlcValidationScoring
    def self.run(run_id:, ...)
      # 50 lines of evidence gathering
      evidence = gather_evidence(...)

      # 40 lines of validation
      validation = validate_evidence(evidence)

      # 50 lines of scoring
      scoring = score_evidence(evidence, validation, ...)

      # 100 lines of report generation
      report_md = build_run_summary_md(...)

      # 30 lines of file writing
      File.write(...)
    end
  end
end
```

**After** (< 150 lines):
```ruby
module Agents
  class SdlcValidationScoring
    def self.run(run_id:, log_dir:, started_at:, finished_at:, duration_ms:, opts:, **context)
      artifact = safe_find_artifact(context[:summary_artifact_id])

      # Gather evidence
      evidence = Sdlc::EvidenceGatherer.new(
        run_id: run_id,
        artifact: artifact,
        test_artifacts_dir: Pathname.new(log_dir).join("test_artifacts")
      ).call

      # Validate
      validation = Sdlc::Validator.new(evidence).call

      # Score
      scoring = Sdlc::Scorer.new(
        evidence: evidence,
        validation: validation,
        error_context: {
          error_class: context[:error_class],
          error_message: context[:error_message],
          workflow_error_class: context[:workflow_error_class],
          workflow_error: context[:workflow_error]
        }
      ).call

      # Generate reports
      generator = Sdlc::ReportGenerator.new(
        run_metadata: build_run_metadata(run_id, started_at, finished_at, duration_ms, opts),
        evidence: evidence,
        validation: validation,
        scoring: scoring
      )

      # Write files
      write_artifacts(log_dir, run_id, generator, scoring)

      # Update artifact
      append_score_attempt!(artifact, scoring)
      finalize_phase!(artifact, scoring)

      # Return paths
      build_result_paths(log_dir, run_id)
    rescue StandardError => e
      { error: { "class" => e.class.to_s, "message" => e.message } }
    end

    private

    def self.write_artifacts(log_dir, run_id, generator, scoring)
      kb_artifacts_dir = Rails.root.join("knowledge_base", "test_artifacts", run_id.to_s)
      FileUtils.mkdir_p(kb_artifacts_dir)

      File.write(kb_artifacts_dir.join("run_summary.md"), generator.generate_markdown)
      File.write(Pathname.new(log_dir).join("summary.log"), generator.generate_log)
    end

    # ... minimal helper methods
  end
end
```

---

## Testing strategy

### Unit tests (new)
- Test each service in isolation
- Mock file system dependencies
- Fast tests (< 0.1s each)

**New test files**:
- `test/lib/agents/sdlc/evidence_gatherer_test.rb`
- `test/lib/agents/sdlc/validator_test.rb`
- `test/lib/agents/sdlc/scorer_test.rb`
- `test/lib/agents/sdlc/report_generator_test.rb`

### Integration tests (existing)
- Existing tests in `test/tasks/agent_test_sdlc_rake_test.rb` continue to work
- No changes to test assertions

---

## File structure after refactoring

```
lib/agents/
  sdlc_validation_scoring.rb (< 150 lines, orchestrator)
  sdlc/
    evidence_gatherer.rb
    validator.rb
    scorer.rb
    report_generator.rb
```

---

## Acceptance criteria

- AC1: `SdlcValidationScoring` reduced to < 150 lines
- AC2: Four new service classes created in `sdlc/` namespace
- AC3: All existing tests pass without modification
- AC4: New unit tests added for each service (100% coverage)
- AC5: No changes to public API or file output formats
- AC6: YARD documentation added to all services
- AC7: Rubric scoring logic fully testable without file system
- AC8: Code review confirms improved separation of concerns

---

## Risks and mitigation

### Risk: Breaking SDLC CLI
- **Mitigation**: Maintain exact output format; comprehensive integration tests
- **Validation**: Run full CLI test suite; compare outputs before/after

### Risk: File system dependencies
- **Mitigation**: Inject file system adapters for testing
- **Validation**: Unit tests use in-memory file system

### Risk: Scoring logic changes
- **Mitigation**: Extract scoring logic unchanged; add tests to lock behavior
- **Validation**: Regression tests on scoring rubric

---

## Success metrics

- Lines of code: Reduced from 412 to < 150 lines (64% reduction)
- Test speed: Unit tests run in < 1s (vs 5s+ for integration)
- Maintainability: Each service < 100 lines
- Extensibility: New scoring rules added in < 10 lines

---

## Out of scope

- Changing scoring rubric or validation rules
- Adding new validation checks
- Modifying output formats
- Performance optimization (beyond preventing regression)

---

## Rollout plan

1. Create feature branch `refactor/extract-sdlc-validation`
2. Implement Steps 1-6 incrementally with tests
3. Code review with 1+ approver
4. Run full SDLC CLI test suite
5. Merge to main after CI passes
6. No production monitoring needed (CLI tool, covered by tests)
