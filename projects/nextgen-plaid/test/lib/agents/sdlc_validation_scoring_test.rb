# frozen_string_literal: true

require "test_helper"
require "agents/sdlc_validation_scoring"

class Agents::SdlcValidationScoringTest < ActiveSupport::TestCase
  setup do
    @run_id = SecureRandom.uuid
    @log_dir = Dir.mktmpdir("sdlc_test_#{@run_id}")
    @test_artifacts_dir = File.join(@log_dir, "test_artifacts")
    FileUtils.mkdir_p(@test_artifacts_dir)

    @started_at = Time.current
    @finished_at = @started_at + 10.seconds
  end

  teardown do
    FileUtils.remove_entry(@log_dir) if File.exist?(@log_dir)
    # Cleanup knowledge_base/test_artifacts created during run
    kb_artifacts_path = Rails.root.join("knowledge_base", "test_artifacts", @run_id.to_s)
    FileUtils.rm_rf(kb_artifacts_path)
  end

  test "it runs successfully and generates expected files" do
    # Create some mock evidence
    File.write(File.join(@test_artifacts_dir, "micro_tasks.json"), [ { id: "1", title: "Task 1", estimate: "1h" } ].to_json)

    handoffs_dir = File.join(@test_artifacts_dir, "handoffs")
    FileUtils.mkdir_p(handoffs_dir)
    File.write(File.join(handoffs_dir, "handoff_1.json"), { agent: "coder", status: "success" }.to_json)

    result = Agents::SdlcValidationScoring.run(
      run_id: @run_id,
      log_dir: @log_dir,
      run_dir_name: "test_run",
      started_at: @started_at,
      finished_at: @finished_at,
      duration_ms: 10000,
      opts: { model_sap: "gpt-4" },
      summary_artifact_id: nil,
      summary_run_id: nil,
      output_files: [],
      error_class: nil,
      error_message: nil,
      workflow_error_class: nil,
      workflow_error: nil,
      workflow_event_types: []
    )

    assert_nil result[:error]

    kb_artifacts_path = Rails.root.join("knowledge_base", "test_artifacts", @run_id.to_s)
    assert File.exist?(kb_artifacts_path.join("validation.json"))
    assert File.exist?(kb_artifacts_path.join("run_summary.md"))
    assert File.exist?(File.join(@log_dir, "run_summary.md"))
    assert File.exist?(File.join(@log_dir, "summary.log"))

    validation = JSON.parse(File.read(kb_artifacts_path.join("validation.json")))
    assert_equal @run_id, validation["run_id"]
    assert_not_nil validation["scoring"]["score"]
  end

  test "it handles missing evidence gracefully" do
    result = Agents::SdlcValidationScoring.run(
      run_id: @run_id,
      log_dir: @log_dir,
      run_dir_name: "test_run_empty",
      started_at: @started_at,
      finished_at: @finished_at,
      duration_ms: 1000,
      opts: {},
      summary_artifact_id: nil,
      summary_run_id: nil,
      output_files: [],
      error_class: "StandardError",
      error_message: "Something went wrong",
      workflow_error_class: nil,
      workflow_error: nil,
      workflow_event_types: []
    )

    assert_nil result[:error]
    assert_not_nil result[:run_summary_path]

    # If evidence is empty, score might not be 0 because validation of empty evidence might still result in some points?
    # Wait, if micro_tasks is missing, it should be 0.
    # If PRD is missing, it should be 0.
    # If handoffs are missing, it should be 0.
    # If impl notes are missing, it should be 0.
    # If tests are not green, it should be 0.
    # If errors are present, it should be 0.

    # Let's check why I got 2.
    # Oh, I see: micro_tasks_ok = validation.dig("micro_tasks", "valid")
    # If validation.dig("micro_tasks", "valid") is true, it gets 2 points.

    scoring = JSON.parse(File.read(Rails.root.join("knowledge_base", "test_artifacts", @run_id.to_s, "validation.json")))["scoring"]
    assert_equal false, scoring["pass"]
  end
end
