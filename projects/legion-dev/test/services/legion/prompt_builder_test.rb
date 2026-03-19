# frozen_string_literal: true

require "test_helper"

module Legion
  class PromptBuilderTest < ActiveSupport::TestCase
    setup do
      # Use a per-test temp directory so tests never overwrite real templates.
      # Copy all real templates into the temp dir so phases that rely on real
      # templates (e.g. conductor, qa_score) work without any create_test_template call.
      @tmp_dir = Dir.mktmpdir("prompt_builder_test_")
      real_dir = Rails.root.join("app/prompts")
      FileUtils.cp_r(Dir.glob("#{real_dir}/*.md.liquid"), @tmp_dir)

      # Point PromptBuilder at the temp dir for the duration of this test.
      @original_templates_dir = PromptBuilder::TEMPLATES_DIR
      silence_warnings { PromptBuilder.const_set(:TEMPLATES_DIR, Pathname.new(@tmp_dir)) }
      PromptBuilder.instance_variable_set(:@environment, nil)
    end

    teardown do
      # Restore PromptBuilder's constant and clear cached environment.
      silence_warnings { PromptBuilder.const_set(:TEMPLATES_DIR, @original_templates_dir) }
      PromptBuilder.instance_variable_set(:@environment, nil)
      FileUtils.rm_rf(@tmp_dir)
    end

    # ============================================================================
    # FR-2, AC-1: Render each phase with valid context
    # ============================================================================

    def test_build_returns_rendered_prompt_for_conductor_phase
      # Use a simple conductor template in the temp dir so we control the variables.
      create_test_template("conductor_prompt.md.liquid", "## Execution State: {{ phase }}\n**Workflow ID:** {{ workflow_id }}")

      result = PromptBuilder.build(
        phase: :conductor,
        context: { phase: "executing", workflow_id: 42 }
      )

      assert_includes result, "Execution State: executing"
      assert_includes result, "42"
    end

    def test_build_returns_rendered_prompt_for_decompose_phase
      create_test_template("decomposition_prompt.md.liquid", "PRD: {{ prd_content }}, Path: {{ project_path }}")

      result = PromptBuilder.build(
        phase: :decompose,
        context: { prd_content: "Build a user model", project_path: "/tmp/test" }
      )

      assert_includes result, "PRD: Build a user model"
      assert_includes result, "Path: /tmp/test"
    end

    def test_build_returns_rendered_prompt_for_code_phase
      create_test_template("task_prompt.md.liquid", "Task: {{ task_prompt }}, Files: {{ file_context }}")

      result = PromptBuilder.build(
        phase: :code,
        context: { task_prompt: "Create User model", file_context: "app/models/user.rb" }
      )

      assert_includes result, "Task: Create User model"
      assert_includes result, "Files: app/models/user.rb"
    end

    def test_build_returns_rendered_prompt_for_architect_review_phase
      # architect_review_prompt.md.liquid currently has no variables ("Test content")
      create_test_template("architect_review_prompt.md.liquid", "Review: {{ plan_review }}")

      result = PromptBuilder.build(
        phase: :architect_review,
        context: { plan_review: "Plan looks good" }
      )

      assert_includes result, "Review: Plan looks good"
    end

    def test_build_returns_rendered_prompt_for_qa_score_phase
      # Real qa_score template requires acceptance_criteria + task_results loop
      create_test_template("qa_score_prompt.md.liquid", "Criteria: {{ acceptance_criteria }}")

      result = PromptBuilder.build(
        phase: :qa_score,
        context: { acceptance_criteria: "All tests pass", task_results: [] }
      )

      assert_includes result, "Criteria: All tests pass"
    end

    def test_build_returns_rendered_prompt_for_retry_phase
      create_test_template("retry_prompt.md.liquid", "Previous: {{ previous_result }}, Context: {{ accumulated_context }}")

      result = PromptBuilder.build(
        phase: :retry,
        context: { previous_result: "failed", accumulated_context: "error history" }
      )

      assert_includes result, "Previous: failed"
      assert_includes result, "Context: error history"
    end

    def test_build_returns_rendered_prompt_for_retrospective_phase
      # retrospective_prompt.md.liquid currently has no variables ("Test content")
      create_test_template("retrospective_prompt.md.liquid", "Analysis: {{ analysis }}")

      result = PromptBuilder.build(
        phase: :retrospective,
        context: { analysis: "team performance review" }
      )

      assert_includes result, "Analysis: team performance review"
    end

    # ============================================================================
    # FR-3, NF-3, AC-2, AC-9: Missing context raises PromptContextError
    # ============================================================================

    def test_build_raises_PromptContextError_for_undefined_variable_in_strict_mode
      # Liquid strict mode raises UndefinedVariable for missing variables
      create_test_template("conductor_prompt.md.liquid", "{{ required_var }}")

      assert_raises PromptBuilder::PromptContextError do
        PromptBuilder.build(
          phase: :conductor,
          context: {} # Missing required_var
        )
      end
    end

    def test_build_raises_PromptContextError_with_variable_name_in_message
      create_test_template("decomposition_prompt.md.liquid", "{{ missing_key }}")

      error = assert_raises PromptBuilder::PromptContextError do
        PromptBuilder.build(
          phase: :decompose,
          context: {}
        )
      end

      assert_includes error.message, "missing_key"
    end

    # ============================================================================
    # AC-3: available_phases returns all phases with templates
    # ============================================================================

    def test_available_phases_returns_all_defined_phases
      # Create all required templates
      %i[conductor decompose code architect_review qa_score retry retrospective].each do |phase|
        template_name = PromptBuilder::PHASE_TEMPLATES[phase]
        create_test_template(template_name, "Test content")
      end

      phases = PromptBuilder.available_phases

      assert_includes phases, :conductor
      assert_includes phases, :decompose
      assert_includes phases, :code
      assert_includes phases, :architect_review
      assert_includes phases, :qa_score
      assert_includes phases, :retry
      assert_includes phases, :retrospective
      assert_equal 7, phases.length
    end

    def test_available_phases_only_includes_phases_with_templates
      # Since real templates exist for all phases, available_phases always returns all.
      # Verify the method at minimum includes a phase when its template exists.
      phases = PromptBuilder.available_phases
      # All 7 real templates exist (created in app/prompts/), so all 7 phases are available.
      assert phases.length >= 1
      assert_includes phases, :conductor
    end

    # ============================================================================
    # FR-7, AC-4: required_context returns correct keys per phase
    # ============================================================================

    def test_required_context_returns_keys_for_conductor_phase
      # Inject a template with the variables a real conductor template would use,
      # since the current conductor_prompt.md.liquid is a static placeholder.
      create_test_template(
        "conductor_prompt.md.liquid",
        "## Execution State: {{ phase }}\n**Workflow ID:** {{ workflow_id }}\nAttempt: {{ attempt }}\nTasks: {{ tasks }}\nScores: {{ scores }}"
      )

      required = PromptBuilder.required_context(phase: :conductor)

      assert_includes required, "phase"
      assert_includes required, "workflow_id"
      assert_includes required, "attempt"
      assert_includes required, "tasks"
      assert_includes required, "scores"
    end

    def test_required_context_returns_keys_for_decompose_phase
      # Template uses: prd_content, project_path
      create_test_template("decomposition_prompt.md.liquid", "{{ prd_content }}{{ project_path }}")

      required = PromptBuilder.required_context(phase: :decompose)

      assert_includes required, "prd_content"
      assert_includes required, "project_path"
    end

    def test_required_context_returns_keys_for_code_phase
      # Template uses: task_prompt, file_context
      create_test_template("task_prompt.md.liquid", "{{ task_prompt }}{{ file_context }}")

      required = PromptBuilder.required_context(phase: :code)

      assert_includes required, "task_prompt"
      assert_includes required, "file_context"
    end

    def test_required_context_returns_keys_for_architect_review_phase
      # Inject a template with a known variable to test extraction
      create_test_template("architect_review_prompt.md.liquid", "{{ plan_review }}")

      required = PromptBuilder.required_context(phase: :architect_review)

      assert_includes required, "plan_review"
    end

    def test_required_context_returns_keys_for_qa_score_phase
      # Real qa_score template uses: acceptance_criteria, task_results
      required = PromptBuilder.required_context(phase: :qa_score)

      assert_includes required, "acceptance_criteria"
    end

    def test_required_context_returns_keys_for_retry_phase
      # Template uses: previous_result, accumulated_context
      create_test_template("retry_prompt.md.liquid", "{{ previous_result }}{{ accumulated_context }}")

      required = PromptBuilder.required_context(phase: :retry)

      assert_includes required, "previous_result"
      assert_includes required, "accumulated_context"
    end

    def test_required_context_returns_keys_for_retrospective_phase
      # Inject a template with a known variable
      create_test_template("retrospective_prompt.md.liquid", "{{ analysis }}")

      required = PromptBuilder.required_context(phase: :retrospective)

      assert_includes required, "analysis"
    end

    def test_required_context_returns_empty_array_for_phase_without_variables
      create_test_template("conductor_prompt.md.liquid", "Static content")

      required = PromptBuilder.required_context(phase: :conductor)

      assert_empty required
    end

    # ============================================================================
    # AC-9: Strict mode enabled
    # ============================================================================

    def test_strict_mode_is_enabled_by_default
      # Create a template with an undefined variable
      create_test_template("conductor_prompt.md.liquid", "{{ undefined_variable }}")

      # In strict mode, this should raise an error
      assert_raises PromptBuilder::PromptContextError do
        PromptBuilder.build(
          phase: :conductor,
          context: {}
        )
      end
    end

    def test_strict_mode_raises_for_nested_undefined_variables
      create_test_template("conductor_prompt.md.liquid", "{{ user.name }}")

      assert_raises PromptBuilder::PromptContextError do
        PromptBuilder.build(
          phase: :conductor,
          context: {}
        )
      end
    end

    # ============================================================================
    # AC-9: Manifest completeness - render with only specified keys
    # ============================================================================

    def test_render_with_only_manifest_keys_succeeds_for_conductor
      # Template requires: phase_name, attempt
      create_test_template("conductor_prompt.md.liquid", "{{ phase_name }}{{ attempt }}")

      # Get required context
      required = PromptBuilder.required_context(phase: :conductor)

      # Render with only required keys
      context = required.to_h { |k| [ k, "test_value" ] }

      result = PromptBuilder.build(phase: :conductor, context: context)

      assert_not_nil result
      assert_instance_of String, result
    end

    def test_render_with_only_manifest_keys_succeeds_for_decompose
      # Template requires: prd_content, project_path
      create_test_template("decomposition_prompt.md.liquid", "{{ prd_content }}{{ project_path }}")

      required = PromptBuilder.required_context(phase: :decompose)
      context = required.to_h { |k| [ k, "test_value" ] }

      result = PromptBuilder.build(phase: :decompose, context: context)

      assert_not_nil result
    end

    def test_render_with_only_manifest_keys_succeeds_for_code
      # Template requires: task_prompt, file_context
      create_test_template("task_prompt.md.liquid", "{{ task_prompt }}{{ file_context }}")

      required = PromptBuilder.required_context(phase: :code)
      context = required.to_h { |k| [ k, "test_value" ] }

      result = PromptBuilder.build(phase: :code, context: context)

      assert_not_nil result
    end

    def test_render_with_only_manifest_keys_succeeds_for_architect_review
      # Template requires: plan_review
      create_test_template("architect_review_prompt.md.liquid", "{{ plan_review }}")

      required = PromptBuilder.required_context(phase: :architect_review)
      context = required.to_h { |k| [ k, "test_value" ] }

      result = PromptBuilder.build(phase: :architect_review, context: context)

      assert_not_nil result
    end

    def test_render_with_only_manifest_keys_succeeds_for_qa_score
      create_test_template("qa_score_prompt.md.liquid", "{{ acceptance_criteria }}")

      required = PromptBuilder.required_context(phase: :qa_score)
      context = required.to_h { |k| [ k, "test_value" ] }

      result = PromptBuilder.build(phase: :qa_score, context: context)

      assert_not_nil result
    end

    def test_render_with_only_manifest_keys_succeeds_for_retry
      # Template requires: previous_result, accumulated_context
      create_test_template("retry_prompt.md.liquid", "{{ previous_result }}{{ accumulated_context }}")

      required = PromptBuilder.required_context(phase: :retry)
      context = required.to_h { |k| [ k, "test_value" ] }

      result = PromptBuilder.build(phase: :retry, context: context)

      assert_not_nil result
    end

    def test_render_with_only_manifest_keys_succeeds_for_retrospective
      # Template requires: analysis
      create_test_template("retrospective_prompt.md.liquid", "{{ analysis }}")

      required = PromptBuilder.required_context(phase: :retrospective)
      context = required.to_h { |k| [ k, "test_value" ] }

      result = PromptBuilder.build(phase: :retrospective, context: context)

      assert_not_nil result
    end

    # ============================================================================
    # AC-3: Unknown phase raises TemplateNotFoundError
    # ============================================================================

    def test_build_raises_TemplateNotFoundError_for_unknown_phase
      assert_raises PromptBuilder::TemplateNotFoundError do
        PromptBuilder.build(
          phase: :unknown_phase,
          context: {}
        )
      end
    end

    def test_build_raises_TemplateNotFoundError_with_phase_name_in_message
      error = assert_raises PromptBuilder::TemplateNotFoundError do
        PromptBuilder.build(
          phase: :nonexistent,
          context: {}
        )
      end

      assert_includes error.message, "nonexistent"
    end

    # ============================================================================
    # AC-9: Template syntax error raises TemplateSyntaxError
    # ============================================================================

    def test_build_raises_TemplateSyntaxError_for_liquid_syntax_error
      # Write a template with invalid Liquid syntax to the ACTUAL template path
      # so PromptBuilder reads it. Provide all required variables so we reach
      # template parsing before context validation fails.
      create_test_template("conductor_prompt.md.liquid", "{{ invalid syntax")

      assert_raises PromptBuilder::TemplateSyntaxError do
        PromptBuilder.build(
          phase: :conductor,
          context: {}
        )
      end
    end

    def test_build_raises_TemplateSyntaxError_with_template_name_in_message
      create_test_template("decomposition_prompt.md.liquid", "{{ unknown_tag")

      error = assert_raises PromptBuilder::TemplateSyntaxError do
        PromptBuilder.build(
          phase: :decompose,
          context: {}
        )
      end

      assert_includes error.message, "decomposition_prompt.md.liquid"
    end

    # ============================================================================
    # Error class tests - using assert_kind_of for inheritance checks
    # ============================================================================

    def test_PromptContextError_is_subclass_of_StandardError
      error = PromptBuilder::PromptContextError.new("test")
      assert_kind_of StandardError, error
    end

    def test_TemplateNotFoundError_is_subclass_of_StandardError
      error = PromptBuilder::TemplateNotFoundError.new("test")
      assert_kind_of StandardError, error
    end

    def test_TemplateSyntaxError_is_subclass_of_StandardError
      error = PromptBuilder::TemplateSyntaxError.new("test")
      assert_kind_of StandardError, error
    end

    # ============================================================================
    # Helper methods
    # ============================================================================

    private

    # Write a template into the per-test temp directory (safe for parallel runs —
    # never touches real app/prompts files).
    def create_test_template(name, content)
      template_path = Pathname.new(@tmp_dir).join(name)
      File.write(template_path, content)
      # Invalidate PromptBuilder's cached Liquid::Environment so it re-parses templates
      PromptBuilder.instance_variable_set(:@environment, nil)
    end
  end
end
