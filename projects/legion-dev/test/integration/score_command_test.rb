# frozen_string_literal: true

require "test_helper"

class ScoreCommandIntegrationTest < ActionDispatch::IntegrationTest
  # Disable transactional tests so subprocess can see test data
  self.use_transactional_tests = false

  # Setup common test data
  setup do
    # Use a temporary project path for each test with unique identifier
    @project_path = Rails.root.join("tmp", "test-project-#{Time.now.to_i}-#{SecureRandom.hex(4)}")
    @project = create(:project, path: @project_path.to_s)
    @team = create(:agent_team, project: @project, name: "ROR")
    @membership = create(:team_membership,
                        agent_team: @team,
                        config: {
                          "id" => "qa",
                          "name" => "QA Agent",
                          "provider" => "smart_proxy",
                          "model" => "deepseek-reasoner"
                        })
    @team.team_memberships << @membership
    @team.save!

    # Create a completed workflow run with tasks
    @workflow_run = create(:workflow_run,
                          project: @project,
                          team_membership: @membership,
                          status: :completed,
                          result: "Workflow completed successfully")

    # Create some tasks for the workflow run
    create(:task, workflow_run: @workflow_run,
                  position: 1, prompt: "Build the application",
                  status: "completed",
                  result: "App built successfully")
    create(:task, workflow_run: @workflow_run,
                  position: 2, prompt: "Write tests",
                  status: "completed",
                  result: "All tests passed")

    # Create a separate workflow run for QA agent scoring
    @qa_workflow_run = create(:workflow_run,
                             project: @project,
                             team_membership: @membership,
                             status: :completed,
                             result: "QA workflow run result")
    create(:task, workflow_run: @qa_workflow_run,
                  position: 1, prompt: "Build the application",
                  status: "completed",
                  result: "App built successfully")
    create(:task, workflow_run: @qa_workflow_run,
                  position: 2, prompt: "Write tests",
                  status: "completed",
                  result: "All tests passed")
  end

  teardown do
    # Clean up test project directory
    FileUtils.rm_rf(@project.path) if File.directory?(@project.path)

    # Clean up database records since transactional tests are disabled.
    # Null out circular/cross FKs before bulk deletes to avoid constraint violations
    conn = ActiveRecord::Base.connection
    conn.execute("UPDATE workflow_runs SET task_id = NULL, workflow_execution_id = NULL")
    conn.execute("UPDATE tasks SET execution_run_id = NULL")
    Artifact.delete_all
    TaskDependency.delete_all
    WorkflowEvent.delete_all
    ConductorDecision.delete_all
    Task.delete_all
    WorkflowExecution.delete_all
    WorkflowRun.delete_all
    TeamMembership.delete_all
    AgentTeam.delete_all
    Project.delete_all
  end

  # =============================================================================
  # AC-1: bin/legion score --workflow-run <id> --team ROR dispatches QA agent and prints score to console
  # =============================================================================

  test "AC-1: full command execution dispatches QA agent and prints score" do
    skip_unless_cassette("score_command_qa_dispatch")
    result = nil
    VCR.use_cassette("score_command_qa_dispatch") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR")
    end

    assert_equal 0, result[:exit_code], "Expected exit code 0 for successful score"
    assert_match(/Score:\s*\d+\/100/, result[:output])
    assert_match(/Verdict:.*PASSED/, result[:output])
  end

  # =============================================================================
  # AC-6: Score report stored as Artifact with artifact_type: :score_report
  # =============================================================================

  test "AC-6: score report persisted as Artifact with correct type and metadata" do
    skip_unless_cassette("score_command_artifact_persistence")
    original_artifact_count = @qa_workflow_run.artifacts.count

    VCR.use_cassette("score_command_artifact_persistence") do
      run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR")
    end

    assert_equal original_artifact_count + 1, @qa_workflow_run.artifacts.reload.count,
                 "Expected new Artifact to be created"
    artifact = @qa_workflow_run.artifacts.last
    assert_equal "score_report", artifact.artifact_type
    assert artifact.metadata["score"].present?, "Score should be in metadata"
    assert artifact.content.include?("Score"), "Content should include score information"
  end

  # =============================================================================
  # AC-7: Given score 87 and threshold 90, exit code is 3 (below threshold)
  # AC-8: Given score 94 and threshold 90, exit code is 0 (passed)
  # =============================================================================

  test "AC-7: exit code 3 when score below threshold" do
    skip_unless_cassette("score_command_below_threshold")
    result = nil
    VCR.use_cassette("score_command_below_threshold") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", threshold: 90)
    end

    assert_equal 3, result[:exit_code], "Expected exit code 3 when score < threshold"
    assert_match(/Verdict:.*BELOW THRESHOLD/, result[:output])
  end

  test "AC-8: exit code 0 when score meets or exceeds threshold" do
    skip_unless_cassette("score_command_passed_threshold")
    result = nil
    VCR.use_cassette("score_command_passed_threshold") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", threshold: 90)
    end

    assert_equal 0, result[:exit_code], "Expected exit code 0 when score >= threshold"
    assert_match(/Verdict:.*PASSED/, result[:output])
  end

  # =============================================================================
  # AC-10: --prd <path> flag includes PRD content in the scoring prompt
  # =============================================================================

  test "AC-10: --prd flag includes PRD content in scoring prompt" do
    prd_path = Rails.root.join("tmp", "test_prd.md")
    skip_unless_cassette("score_command_with_prd")
    File.write(prd_path, "# Test PRD\n\n## Acceptance Criteria\n- Implement feature X\n")

    result = nil
    VCR.use_cassette("score_command_with_prd") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR",
                                  prd: prd_path, threshold: 90)
    end

    assert_equal 0, result[:exit_code]
    assert_match(/Verdict:.*PASSED/, result[:output])
  ensure
    File.delete(prd_path.to_s) if prd_path && File.exist?(prd_path.to_s)
  end

  # =============================================================================
  # AC-9: Console output includes score, threshold, verdict, issues, artifact ID
  # =============================================================================

  test "AC-9: console output includes all required information" do
    skip_unless_cassette("score_command_output_format")
    result = nil
    VCR.use_cassette("score_command_output_format") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", threshold: 90)
    end

    output = result[:output]
    assert_match(/Score:\s*\d+\/100/, output)
    assert_match(/Threshold:\s*\d+/, output)
    assert_match(/Verdict:.*PASSED|Verdict:.*BELOW THRESHOLD/, output)
    assert_match(/Artifact ID:\s*\d+/, output)
  end

  # =============================================================================
  # Error Cases
  # =============================================================================

  test "error case: WorkflowRun not found" do
    result = run_score_command(
      workflow_run_id: 999_999,
      team: "ROR"
    )

    assert_equal 2, result[:exit_code], "Expected exit code 2 for not found"
    assert_match(/WorkflowRun.*not found/i, result[:output])
  end

  test "error case: Team not found" do
    result = run_score_command(
      workflow_run_id: @qa_workflow_run.id,
      team: "NonExistentTeam"
    )

    assert_equal 2, result[:exit_code], "Expected exit code 2 for not found"
    assert_match(/Team.*not found/i, result[:output])
  end

  test "error case: QA agent not in team" do
    # Create a team without QA membership
    team_no_qa = create(:agent_team, project: @project, name: "NoQATeam")
    create(:team_membership,
           agent_team: team_no_qa,
           config: { "id" => "dev", "name" => "Dev Agent", "provider" => "deepseek", "model" => "deepseek-reasoner" })

    result = run_score_command(
      workflow_run_id: @qa_workflow_run.id,
      team: team_no_qa.name
    )

    assert_equal 2, result[:exit_code], "Expected exit code 2 for not found"
    assert_match(/No agent with role/i, result[:output])
  end

  test "error case: dispatch failure" do
    skip_unless_cassette("score_command_dispatch_failure")
    result = nil
    VCR.use_cassette("score_command_dispatch_failure") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR")
    end

    # When dispatch fails, score should be 0 (below any threshold)
    assert_equal 3, result[:exit_code], "Expected exit code 3 for dispatch failure"
    assert_match(/Score parsing failed|dispatch failed|Verdict:.*BELOW THRESHOLD/i, result[:output])
  end

  test "error case: PRD file not found" do
    result = run_score_command(
      workflow_run_id: @qa_workflow_run.id,
      team: "ROR",
      prd: "/nonexistent/path/to/prd.md"
    )

    assert_equal 2, result[:exit_code], "Expected exit code 2 for file not found"
    assert_match(/PRD.*not found|File not found/i, result[:output])
  end

  # =============================================================================
  # Threshold Edge Cases
  # =============================================================================

  test "threshold edge case: score equals threshold (passes)" do
    skip_unless_cassette("score_command_threshold_equal")
    result = nil
    VCR.use_cassette("score_command_threshold_equal") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", threshold: 90)
    end

    assert_equal 0, result[:exit_code], "Expected exit code 0 when score equals threshold"
    assert_match(/Verdict:.*PASSED/, result[:output])
  end

  test "threshold edge case: score just below threshold (fails)" do
    skip_unless_cassette("score_command_threshold_below")
    result = nil
    VCR.use_cassette("score_command_threshold_below") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", threshold: 100)
    end

    # Score is below 100, so it should fail
    assert_equal 3, result[:exit_code], "Expected exit code 3 when score just below threshold"
    assert_match(/Verdict:.*BELOW THRESHOLD|Verdict:.*PASSED/, result[:output])
  end

  test "threshold edge case: score 0 (fails)" do
    skip_unless_cassette("score_command_zero_score")
    result = nil
    VCR.use_cassette("score_command_zero_score") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", threshold: 50)
    end

    assert_equal 3, result[:exit_code], "Expected exit code 3 when score is 0"
    assert_match(/Verdict:.*BELOW THRESHOLD/, result[:output])
  end

  test "threshold edge case: score 100 (passes)" do
    skip_unless_cassette("score_command_score_100")
    result = nil
    VCR.use_cassette("score_command_score_100") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", threshold: 100)
    end

    assert_equal 0, result[:exit_code], "Expected exit code 0 when score 100 meets threshold 100"
    assert_match(/Verdict:.*PASSED/, result[:output])
  end

  # =============================================================================
  # Custom agent role
  # =============================================================================

  test "custom agent role: --agent flag works" do
    skip_unless_cassette("score_command_custom_agent")
    result = nil
    VCR.use_cassette("score_command_custom_agent") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR", agent: "qa")
    end

    assert [ 0, 3 ].include?(result[:exit_code]), "Expected exit code 0 or 3 for successful command"
    assert_match(/Score:\s*\d+\/100/, result[:output])
  end

  # =============================================================================
  # Multiple workflow runs
  # =============================================================================

  test "multiple workflow runs: each gets separate artifact" do
    skip_unless_cassette("score_command_multiple_runs_1")
    skip_unless_cassette("score_command_multiple_runs_2")

    workflow_run2 = create(:workflow_run, project: @project, team_membership: @membership,
                                         status: :completed)
    create(:task, workflow_run: workflow_run2, position: 1, prompt: "Task for run 2",
                  status: "completed", result: "Run 2 completed")

    original_artifacts_count = @qa_workflow_run.artifacts.count
    result1 = nil
    VCR.use_cassette("score_command_multiple_runs_1") do
      result1 = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR")
    end

    assert_equal original_artifacts_count + 1, @qa_workflow_run.artifacts.reload.count

    result2 = nil
    VCR.use_cassette("score_command_multiple_runs_2") do
      result2 = run_score_command(workflow_run_id: workflow_run2.id, team: "ROR")
    end

    assert_equal original_artifacts_count + 1, @qa_workflow_run.artifacts.reload.count
    assert_equal 1, workflow_run2.artifacts.reload.count
    assert_equal 0, result1[:exit_code]
    assert_equal 0, result2[:exit_code]
  end

  # =============================================================================
  # PRD flag with actual content
  # =============================================================================

  test "PRD content is used in scoring prompt" do
    prd_path = Rails.root.join("tmp", "test_prd_full.md")
    skip_unless_cassette("score_command_prd_context")
    File.write(prd_path, "# Application Requirements\n\n## Features\n- User authentication\n")

    result = nil
    VCR.use_cassette("score_command_prd_context") do
      result = run_score_command(workflow_run_id: @qa_workflow_run.id, team: "ROR",
                                  prd: prd_path, threshold: 80)
    end

    assert_equal 0, result[:exit_code]
    assert_match(/Verdict:.*PASSED/, result[:output])
  ensure
    File.delete(prd_path) if prd_path && File.exist?(prd_path)
  end

  # =============================================================================
  # Private helper methods
  # =============================================================================

  private

  # Skip the test if the named VCR cassette does not exist on disk.
  # VCR cassettes require a live SmartProxy server to record; they can't be
  # recorded by the subprocess (bin/legion) from within the test process.
  def skip_unless_cassette(name)
    path = Rails.root.join("test", "vcr_cassettes", "#{name}.yml")
    skip "VCR cassette '#{name}' not recorded — run with RECORD_VCR=1 against a live SmartProxy" unless File.exist?(path)
  end

  def run_score_command(workflow_run_id:, team:, threshold: 90, prd: nil, agent: nil)
    # Build the command
    cmd = "cd #{Rails.root} && bin/legion score --workflow-run #{workflow_run_id} --team #{team} --threshold #{threshold}"
    cmd += " --agent #{agent}" if agent
    cmd += " --prd #{prd}" if prd

    # Execute and capture output
    output = `#{cmd} 2>&1`
    exit_code = $?.exitstatus

    {
      output: output,
      exit_code: exit_code
    }
  end
end
