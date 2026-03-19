# frozen_string_literal: true

require "test_helper"

class ArtifactTest < ActiveSupport::TestCase
  setup do
    @project = create(:project)
    @team_membership = create(:team_membership)
    @workflow_run = create(:workflow_run, project: @project, team_membership: @team_membership)
    @workflow_execution = create(:workflow_execution, project: @project)
    @created_by = create(:agent_team, project: @project)
  end

  test "factory creates valid record" do
    artifact = build(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution)
    assert artifact.valid?
  end

  test "artifact_type validation" do
    artifact = build(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: nil)
    assert_not artifact.valid?
    assert_includes artifact.errors[:artifact_type], "can't be blank"
  end

  test "content validation" do
    artifact = build(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, content: nil)
    assert_not artifact.valid?
    assert_includes artifact.errors[:content], "can't be blank"
  end

  test "workflow_run validation" do
    artifact = build(:artifact, workflow_execution: @workflow_execution, artifact_type: :plan, content: "test", workflow_run: nil)
    assert_not artifact.valid?
    assert_includes artifact.errors[:workflow_run], "must exist"
  end

  test "artifact_type enum with all 7 values" do
    %i[plan code_output score_report architect_review review_feedback retry_context retrospective_report].each do |type|
      artifact = build(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: type)
      assert artifact.valid?
      assert_respond_to artifact, "#{type}?".to_sym
      assert artifact.send("#{type}?")
    end
  end

  test "artifact_type enum helpers work correctly" do
    artifact = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report)

    assert artifact.score_report?
    refute artifact.plan?
    refute artifact.code_output?

    artifact.plan!
    assert artifact.plan?
    refute artifact.score_report?
  end

  test "version auto-increment per (workflow_execution_id, artifact_type)" do
    # Create workflow run with project
    workflow_run = build(:workflow_run, project: @project, team_membership: @team_membership)
    workflow_run.save!
    # Create first plan artifact for execution
    artifact1 = create(:artifact, project: @project, workflow_run: workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "First plan", created_by: @created_by)
    assert_equal "1.0.0", artifact1.version
    assert_equal 1, artifact1.version_number

    # Create second plan artifact for same execution
    artifact2 = create(:artifact, project: @project, workflow_run: workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Second plan", created_by: @created_by)
    assert_equal "2.0.0", artifact2.version
    assert_equal 2, artifact2.version_number

    # Create first score_report artifact for same execution (different type, resets to 1)
    artifact3 = create(:artifact, project: @project, workflow_run: workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Score report", created_by: @created_by)
    assert_equal "1.0.0", artifact3.version
    assert_equal 1, artifact3.version_number
  end

  test "version auto-increment with create_with_version!" do
    workflow_run = build(:workflow_run, project: @project, team_membership: @team_membership)
    workflow_run.save!
    artifact1 = create(:artifact, project: @project, workflow_run: workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "First", created_by: @created_by)
    assert_equal "1.0.0", artifact1.version

    artifact2 = create(:artifact, project: @project, workflow_run: workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Second", created_by: @created_by)
    assert_equal "2.0.0", artifact2.version
  end

  test "scopes: score_reports" do
    artifact1 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Score 1")
    artifact2 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Plan")
    artifact3 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Score 2")

    assert_includes Artifact.score_reports, artifact1
    assert_not_includes Artifact.score_reports, artifact2
    assert_includes Artifact.score_reports, artifact3
    assert_equal 2, Artifact.score_reports.count
  end

  test "scopes: architect_reviews" do
    artifact1 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :architect_review, content: "Review 1")
    artifact2 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Plan")
    artifact3 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :architect_review, content: "Review 2")

    assert_includes Artifact.architect_reviews, artifact1
    assert_not_includes Artifact.architect_reviews, artifact2
    assert_includes Artifact.architect_reviews, artifact3
    assert_equal 2, Artifact.architect_reviews.count
  end

  test "scopes: plans" do
    artifact1 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Plan 1")
    artifact2 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Score")
    artifact3 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Plan 2")

    assert_includes Artifact.plans, artifact1
    assert_not_includes Artifact.plans, artifact2
    assert_includes Artifact.plans, artifact3
    assert_equal 2, Artifact.plans.count
  end

  test "scopes: retrospective_reports" do
    artifact1 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retrospective_report, content: "Retrospective 1")
    artifact2 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Plan")
    artifact3 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retrospective_report, content: "Retrospective 2")

    assert_includes Artifact.retrospective_reports, artifact1
    assert_not_includes Artifact.retrospective_reports, artifact2
    assert_includes Artifact.retrospective_reports, artifact3
    assert_equal 2, Artifact.retrospective_reports.count
  end

  test "scopes: for_execution" do
    execution1 = @workflow_execution
    execution2 = create(:workflow_execution, project: @project)

    artifact1 = create(:artifact, workflow_run: @workflow_run, workflow_execution: execution1, artifact_type: :plan, content: "Execution 1 artifact")
    artifact2 = create(:artifact, workflow_run: @workflow_run, workflow_execution: execution2, artifact_type: :plan, content: "Execution 2 artifact")

    assert_includes Artifact.for_execution(execution1.id), artifact1
    assert_not_includes Artifact.for_execution(execution1.id), artifact2
    assert_equal 1, Artifact.for_execution(execution1.id).count
  end

  test "parent chain navigation: parent_artifact" do
    parent = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Parent")
    child = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child", parent_artifact: parent)

    assert_equal parent, child.parent_artifact
    assert_nil parent.parent_artifact
  end

  test "parent chain navigation: child_artifacts" do
    parent = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Parent")
    child1 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child 1", parent_artifact: parent)
    child2 = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child 2", parent_artifact: parent)

    assert_includes parent.child_artifacts, child1
    assert_includes parent.child_artifacts, child2
    assert_equal 2, parent.child_artifacts.count
  end

  test "parent chain navigation: nullifying parent" do
    parent = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Parent")
    child = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :retry_context, content: "Child", parent_artifact: parent)

    parent.destroy
    child.reload

    assert_nil child.parent_artifact
  end

  test "metadata JSONB storage and retrieval" do
    metadata = {
      "model" => "deepseek-reasoner",
      "tokens_used" => 1500,
      "duration_ms" => 4500,
      "threshold" => 90
    }

    artifact = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :score_report, content: "Score", metadata: metadata)

    assert_equal metadata, artifact.metadata
    assert_equal "deepseek-reasoner", artifact.metadata["model"]
    assert_equal 1500, artifact.metadata["tokens_used"]
  end

  test "metadata default to empty hash" do
    artifact = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Test")

    assert_equal({}, artifact.metadata)
    assert_respond_to artifact.metadata, :[]
  end

  test "associations: workflow_run" do
    artifact = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Test")

    assert_equal @workflow_run, artifact.workflow_run
    assert_includes @workflow_run.artifacts, artifact
  end

  test "associations: workflow_execution" do
    artifact = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Test")

    assert_equal @workflow_execution, artifact.workflow_execution
    assert_includes @workflow_execution.artifacts, artifact
  end

  test "associations: created_by (AgentTeam)" do
    agent_team = create(:agent_team, project: @project)
    artifact = create(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Test", created_by: agent_team)

    assert_equal agent_team, artifact.created_by
  end

  test "status field defaults to active" do
    artifact = build(:artifact, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Test")
    assert_equal "active", artifact.status
  end

  test "name field is required" do
    artifact = Artifact.new(project: @project, workflow_run: @workflow_run, workflow_execution: @workflow_execution, artifact_type: :plan, content: "Test", name: "")
    assert_not artifact.valid?
    assert_includes artifact.errors[:name], "can't be blank"
  end
end
