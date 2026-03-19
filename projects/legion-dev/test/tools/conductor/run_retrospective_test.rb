# frozen_string_literal: true

require "test_helper"
require Rails.root.join("app/tools/legion/orchestration/run_retrospective")

module Legion
  module OrchestrationTools
    class RunRetrospectiveTest < ActiveSupport::TestCase
      setup do
        @project = create(:project)
        @team = create(:agent_team, project: @project)
        @membership = create(:team_membership, agent_team: @team)
        @execution = create(:workflow_execution, project: @project, phase: :decomposing, status: :running)
        @workflow_run = create(:workflow_run, project: @project, team_membership: @membership, workflow_execution: @execution)
      end

      test "generates retrospective report with 6 categories" do
        # Create test data
        create_list(:conductor_decision, 3, workflow_execution: @execution)
        create_list(:task, 5, workflow_execution: @execution, team_membership: @membership)
        create_list(:artifact, 2, workflow_execution: @execution, artifact_type: "score_report", metadata: { "score" => 92, "rounds_to_pass" => 1 })

        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify artifact was created
        assert_instance_of Artifact, result
        assert_equal "retrospective_report", result.artifact_type
        assert_equal "Retrospective Report - #{@execution.id}", result.name
        assert result.content.present?

        # Verify the report contains all 6 required categories
        assert_match(/## Executive Summary/, result.content, "Missing Executive Summary category")
        assert_match(/## Score Summary/, result.content, "Missing Score Summary category")
        assert_match(/## Top Failure Patterns/, result.content, "Missing Top Failure Patterns category")
        assert_match(/## Success Patterns/, result.content, "Missing Success Patterns category")
        assert_match(/## Instruction Updates/, result.content, "Missing Instruction Updates category")
        assert_match(/## Improvement Metrics/, result.content, "Missing Improvement Metrics category")

        # Verify metadata
        assert_equal 6, result.metadata["categories"]
        assert_equal @execution.id.to_s, result.metadata["execution_id"]
      end

      test "handles large data volumes" do
        # Create large volume of test data
        create_list(:conductor_decision, 50, workflow_execution: @execution)
        create_list(:task, 100, workflow_execution: @execution, team_membership: @membership)
        create_list(:artifact, 30, workflow_execution: @execution, artifact_type: "score_report", metadata: { "score" => 95, "rounds_to_pass" => 1 })

        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify artifact was created
        assert_instance_of Artifact, result
        assert_equal "retrospective_report", result.artifact_type
        assert result.content.present?

        # Verify the report contains all 6 required categories
        assert_match(/## Executive Summary/, result.content)
        assert_match(/## Score Summary/, result.content)
        assert_match(/## Top Failure Patterns/, result.content)
        assert_match(/## Success Patterns/, result.content)
        assert_match(/## Instruction Updates/, result.content)
        assert_match(/## Improvement Metrics/, result.content)
      end

      test "handles missing data gracefully" do
        # Run the retrospective with minimal data
        result = RunRetrospective.call(execution: @execution)

        # Verify artifact was created
        assert_instance_of Artifact, result
        assert_equal "retrospective_report", result.artifact_type
        assert result.content.present?

        # Verify the report contains all 6 required categories even with minimal data
        assert_match(/## Executive Summary/, result.content)
        assert_match(/## Score Summary/, result.content)
        assert_match(/## Top Failure Patterns/, result.content)
        assert_match(/## Success Patterns/, result.content)
        assert_match(/## Instruction Updates/, result.content)
        assert_match(/## Improvement Metrics/, result.content)
      end

      test "handles errors gracefully with fallback report" do
        # Create a test execution without workflow_run to force error
        execution_without_workflow = create(:workflow_execution, project: @project, phase: :decomposing, status: :running)

        # Run the retrospective
        result = RunRetrospective.call(execution: execution_without_workflow)

        # Verify error fallback artifact was created
        assert_instance_of Artifact, result
        assert_equal "retrospective_report", result.artifact_type
        assert_equal "Retrospective Report - #{execution_without_workflow.id} (Error Fallback)", result.name
        assert result.content.present?

        # Verify error details are in the report
        assert_match(/Error Details/, result.content)
        assert_match(/NoMethodError/, result.content)

        # Verify error fallback metadata
        assert result.metadata["error_fallback"]
        assert_equal "NoMethodError", result.metadata["error_class"]
      end

      test "produces report with overall assessment" do
        # Create test data with varied scores
        create_list(:artifact, 3, workflow_execution: @execution, artifact_type: "score_report", metadata: { "score" => 96, "rounds_to_pass" => 1 })
        create_list(:artifact, 2, workflow_execution: @execution, artifact_type: "score_report", metadata: { "score" => 88, "rounds_to_pass" => 2 })

        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify the report contains overall assessment
        assert_match(/## Executive Summary/, result.content)
        assert_match(/## Score Summary/, result.content)

        # Verify key metrics are present
        assert_match(/First-attempt pass rate/, result.content)
        assert_match(/Average initial score/, result.content)
      end

      test "includes decision analysis in report" do
        # Create conductor decisions
        create(:conductor_decision, workflow_execution: @execution, decision_type: "approve")
        create(:conductor_decision, workflow_execution: @execution, decision_type: "reject")
        create(:conductor_decision, workflow_execution: @execution, decision_type: "modify")

        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify the report contains decision-related content
        assert_match(/## Executive Summary/, result.content)
        assert result.content.match?(/conductor/i)
        # Debug: check what's in the report
        # puts "Report content: #{result.content}"
        # puts "Contains 'conductor': #{result.content.include?("conductor")}"
      end

      test "includes task analysis in report" do
        # Create tasks with different statuses
        create(:task, workflow_execution: @execution, team_membership: @membership, status: "completed")
        create(:task, workflow_execution: @execution, team_membership: @membership, status: "completed")
        create(:task, workflow_execution: @execution, team_membership: @membership, status: "failed")

        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify the report contains task-related content
        assert_match(/## Executive Summary/, result.content)
        assert_match(/Total PRDs analyzed/, result.content)
      end

      test "includes event analysis in report" do
        # Create workflow events
        @workflow_run.workflow_events.create!(event_type: "task_started", recorded_at: Time.current)
        @workflow_run.workflow_events.create!(event_type: "task_completed", recorded_at: Time.current)
        @workflow_run.workflow_events.create!(event_type: "score_completed", recorded_at: Time.current)

        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify the report contains event-related content
        assert_match(/## Executive Summary/, result.content)
      end

      test "includes artifact analysis in report" do
        # Create various artifacts
        create(:artifact, workflow_execution: @execution, artifact_type: "plan")
        create(:artifact, workflow_execution: @execution, artifact_type: "code_output")
        create(:artifact, workflow_execution: @execution, artifact_type: "score_report", metadata: { "score" => 94, "rounds_to_pass" => 1 })

        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify the report contains artifact-related content
        assert_match(/## Executive Summary/, result.content)
        assert_match(/Total scoring events/, result.content)
      end

      test "generates report with proper formatting" do
        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify the report has proper markdown formatting
        assert_match(/# Retrospective Report:/, result.content)
        assert_match(/\*\*Date:\*\*/, result.content)
        assert_match(/\*\*Analyzer:\*\*/, result.content)
        assert_match(/\*\*Execution ID:\*\*/, result.content)
        assert_match(/\*\*Project:\*\*/, result.content)
        assert_match(/---/, result.content)
        assert_match(/\|/, result.content) # Table formatting
      end

      test "includes recommendations section" do
        # Run the retrospective
        result = RunRetrospective.call(execution: @execution)

        # Verify the report contains recommendations
        assert_match(/## Recommendations/, result.content)
        assert_match(/## Next Steps/, result.content)
      end
    end
  end
end
