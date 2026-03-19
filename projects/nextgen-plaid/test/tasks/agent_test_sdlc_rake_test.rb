require "test_helper"
require "rake"

class AgentTestSdlcRakeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["agent:test_sdlc"].reenable
    @user = User.first || User.create!(email: "agent_sdlc_cli_test@example.com", password: "password")
  end

  test "writes sap.log and prd.md when workflow populates artifact payload content" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    travel_to(cst_tz.parse("2026-01-13 11:08:00.123")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      prd_path = log_dir.join("test_artifacts", "prd.md")
      micro_tasks_path = log_dir.join("test_artifacts", "micro_tasks.json")
      sap_log_path = log_dir.join("sap.log")
      planner_log_path = log_dir.join("planner.log")
      summary_path = log_dir.join("run_summary.md")
      summary_log_path = log_dir.join("summary.log")
      validation_path = Rails.root.join("knowledge_base", "test_artifacts", run_id, "validation.json")
      kb_summary_path = Rails.root.join("knowledge_base", "test_artifacts", run_id, "run_summary.md")

      # Simulate `rake agent:test_sdlc -- --input=...` argument splitting.
      ARGV.replace([ "--", "--run-id=#{run_id}", "--input=Hello", "--rag-sap=foundation", "--model-sap=llama3.1:70b" ])

      AiWorkflowService.stub :run, ->(prompt:, correlation_id:, **_rest) do
        artifact = Artifact.find_by("payload ->> 'test_correlation_id' = ?", correlation_id)
        artifact.payload["content"] = "# PRD\n\nGenerated for: #{prompt.lines.first.strip}"
        artifact.save!
        OpenStruct.new(output: nil, context: { correlation_id: correlation_id }, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert File.exist?(sap_log_path), "expected #{sap_log_path} to exist"
      assert File.exist?(planner_log_path), "expected #{planner_log_path} to exist"
      assert File.exist?(prd_path), "expected #{prd_path} to exist"
      assert File.exist?(micro_tasks_path), "expected #{micro_tasks_path} to exist"
      assert File.exist?(summary_path), "expected #{summary_path} to exist"
      assert File.exist?(summary_log_path), "expected #{summary_log_path} to exist"
      assert File.exist?(validation_path), "expected #{validation_path} to exist"
      assert File.exist?(kb_summary_path), "expected #{kb_summary_path} to exist"
      assert_includes File.read(prd_path), "run_id: #{run_id}"
      assert_includes File.read(sap_log_path), "sap_prompt_resolved"
      assert_includes File.read(sap_log_path), "sap_prd_file_written"
      assert_includes File.read(planner_log_path), "planner_overrides"

      summary = File.read(summary_path)
      assert_includes summary, "## Run metadata"
      assert_includes summary, "run_id: #{run_id}"
      assert_includes summary, "## Generated PRD"
      assert_includes summary, "test_artifacts/prd.md"
      assert_includes summary, "## Scoring + suggestions"
      assert_includes summary, "overall_score:"

      artifact = Artifact.find_by("payload ->> 'test_correlation_id' = ?", run_id)
      assert artifact, "expected artifact to exist"
      assert artifact.payload["score_attempts"].is_a?(Array), "expected artifact.payload['score_attempts'] to be an array"
      assert artifact.payload["score_attempts"].any?, "expected at least one score_attempt"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
      FileUtils.rm_rf(Rails.root.join("knowledge_base", "test_artifacts", run_id))
    end
  ensure
    travel_back
  end

  test "backfills artifact payload content from workflow output when content is missing" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    travel_to(cst_tz.parse("2026-01-13 11:08:00.123")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      prd_path = log_dir.join("test_artifacts", "prd.md")
      sap_log_path = log_dir.join("sap.log")

      ARGV.replace([ "--", "--run-id=#{run_id}", "--input=Hello", "--rag-sap=foundation", "--model-sap=llama3.1:70b" ])

      prd_output = "# PRD\n\nBackfilled content"
      AiWorkflowService.stub :run, ->(**_kwargs) do
        OpenStruct.new(output: prd_output, context: {}, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert File.exist?(sap_log_path), "expected #{sap_log_path} to exist"
      assert File.exist?(prd_path), "expected #{prd_path} to exist"
      assert_includes File.read(prd_path), "Backfilled content"
      assert_includes File.read(sap_log_path), "sap_prd_backfilled"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
    end
  ensure
    travel_back
  end

  test "raises workflow failure when workflow returns an error payload" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    travel_to(cst_tz.parse("2026-01-13 11:08:00.123")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      sap_log_path = log_dir.join("sap.log")
      summary_path = log_dir.join("run_summary.md")
      summary_log_path = log_dir.join("summary.log")

      ARGV.replace([ "--", "--run-id=#{run_id}", "--input=Hello", "--rag-sap=foundation", "--model-sap=llama3.1:70b" ])

      AiWorkflowService.stub :run, ->(**_kwargs) do
        OpenStruct.new(output: nil, context: {}, error: "Net::ReadTimeout with #<TCPSocket:(closed)>", error_class: "Faraday::TimeoutError")
      end do
        err = assert_raises(RuntimeError) { capture_io { Rake::Task["agent:test_sdlc"].invoke } }
        assert_includes err.message, "SAP workflow failed"
        assert_includes err.message, "Faraday::TimeoutError"
      end

      assert File.exist?(sap_log_path), "expected #{sap_log_path} to exist"
      assert_includes File.read(sap_log_path), "sap_workflow_failed"

      assert File.exist?(summary_path), "expected #{summary_path} to exist"
      assert File.exist?(summary_log_path), "expected #{summary_log_path} to exist"
      summary = File.read(summary_path)
      assert_includes summary, "## Errors / Escalations / Failure Evidence"
      assert_includes summary, "Faraday::TimeoutError"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
    end
  ensure
    travel_back
  end

  test "retries once with minimized rag when output is not a prd for the request" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    travel_to(cst_tz.parse("2026-01-13 11:08:00.123")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      prd_path = log_dir.join("test_artifacts", "prd.md")
      sap_log_path = log_dir.join("sap.log")

      ARGV.replace([ "--", "--run-id=#{run_id}", "--input=Generate portal at /admin", "--rag-sap=foundation", "--model-sap=llama3.1:70b" ])

      invalid = "This is a comprehensive set of templates and guidelines..."
      valid = "# PRD\n\n## 1. Overview\n- Admin portal at /admin\n\n## 17. Open Questions\n- None\n"

      call_count = 0
      AiWorkflowService.stub :run, ->(**_kwargs) do
        call_count += 1
        OpenStruct.new(output: (call_count == 1 ? invalid : valid), context: {}, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert_equal 2, call_count, "expected workflow to be invoked twice"
      assert File.exist?(prd_path), "expected #{prd_path} to exist"
      prd = File.read(prd_path)
      assert_includes prd, "# PRD"
      assert_includes prd, "/admin"

      assert File.exist?(sap_log_path), "expected #{sap_log_path} to exist"
      sap_log = File.read(sap_log_path)
      assert_includes sap_log, "sap_prd_invalid"
      assert_includes sap_log, "sap_prd_retried"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
    end
  ensure
    travel_back
  end

  test "writes coordinator.log, plan_summary.md, and handoff snapshots when starting at in_analysis" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone

    travel_to(cst_tz.parse("2026-01-13 11:09:00.456")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      coord_log_path = log_dir.join("coordinator.log")
      plan_path = log_dir.join("test_artifacts", "plan_summary.md")
      handoffs_dir = log_dir.join("test_artifacts", "handoffs")

      ARGV.replace([
        "--",
        "--run-id=#{run_id}",
        "--mode=stage",
        "--stage=in_analysis",
        "--input=Analyze PRD",
        "--rag-coord=foundation",
        "--model-coord=llama3.1:70b",
        "--model-sap=llama3.1:70b"
      ])

      micro_tasks = [
        { "id" => "T1", "title" => "Identify existing admin routes", "estimate" => "15m" },
        { "id" => "T2", "title" => "Draft portal page UX", "estimate" => "20m" }
      ]

      captured_start_agent = nil
      AiWorkflowService.stub :run, ->(prompt:, correlation_id:, **_rest) do
        captured_start_agent = _rest[:start_agent]
        # Simulate ArtifactWriter handoff evidence.
        events_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
        FileUtils.mkdir_p(events_dir)
        File.open(events_dir.join("events.ndjson"), "a") do |f|
          f.puts({ type: "agent_handoff", from: "SAP", to: "Coordinator", reason: "analysis", ts: "2026-01-13T17:09:01Z", correlation_id: correlation_id }.to_json)
        end

        OpenStruct.new(output: "ok", context: { micro_tasks: micro_tasks }, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert_equal "Coordinator", captured_start_agent, "expected coordinator-mode workflow to start at Coordinator"

      assert File.exist?(coord_log_path), "expected #{coord_log_path} to exist"
      assert_includes File.read(coord_log_path), "coord_prompt_resolved"
      assert File.exist?(plan_path), "expected #{plan_path} to exist"
      assert_includes File.read(plan_path), "**T1**"

      handoff_files = Dir.glob(handoffs_dir.join("*.json").to_s)
      assert handoff_files.any?, "expected handoff json files under #{handoffs_dir}"
      assert_includes File.read(handoff_files.first), "\"agent_handoff\""
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
      FileUtils.rm_rf(Rails.root.join("agent_logs", "ai_workflow", run_id))
    end
  ensure
    travel_back
  end

  test "extracts micro_tasks from coordinator output when context does not include them" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone

    travel_to(cst_tz.parse("2026-01-13 11:11:00.111")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      plan_path = log_dir.join("test_artifacts", "plan_summary.md")

      ARGV.replace([
        "--",
        "--run-id=#{run_id}",
        "--mode=stage",
        "--stage=in_analysis",
        "--input=Analyze PRD",
        "--rag-coord=foundation",
        "--model-coord=llama3.1:70b",
        "--model-sap=llama3.1:70b"
      ])

      output = <<~MD
        # Coordinator Analysis

        ## Micro Tasks
        ```json
        [{"id":"T1","title":"Identify admin routes","estimate":"15m"}]
        ```

        ## Notes
        - ok

        ## Ball With
        Ball with: CWA
      MD

      AiWorkflowService.stub :run, ->(**_kwargs) do
        OpenStruct.new(output: output, context: {}, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert File.exist?(plan_path), "expected #{plan_path} to exist"
      assert_includes File.read(plan_path), "**T1**"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
      FileUtils.rm_rf(Rails.root.join("agent_logs", "ai_workflow", run_id))
    end
  ensure
    travel_back
  end

  test "retries coordinator once when micro_tasks are missing and succeeds" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone

    travel_to(cst_tz.parse("2026-01-13 11:12:00.222")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      coord_log_path = log_dir.join("coordinator.log")
      plan_path = log_dir.join("test_artifacts", "plan_summary.md")

      ARGV.replace([
        "--",
        "--run-id=#{run_id}",
        "--mode=stage",
        "--stage=in_analysis",
        "--input=Analyze PRD",
        "--rag-coord=foundation",
        "--model-coord=llama3.1:70b",
        "--model-sap=llama3.1:70b"
      ])

      invalid_output = "This is a summary of guidelines..."
      valid_output = "# Coordinator Analysis\n\n## Micro Tasks\n[{\"id\":\"T1\",\"title\":\"Task\",\"estimate\":\"5m\"}]\n\n## Notes\n- ok\n\n## Ball With\nBall with: CWA\n"

      call_count = 0
      AiWorkflowService.stub :run, ->(**_kwargs) do
        call_count += 1
        OpenStruct.new(output: (call_count == 1 ? invalid_output : valid_output), context: {}, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert_equal 2, call_count, "expected coordinator workflow to be invoked twice"
      assert File.exist?(plan_path), "expected #{plan_path} to exist"
      assert_includes File.read(plan_path), "**T1**"
      assert File.exist?(coord_log_path), "expected #{coord_log_path} to exist"
      coord_log = File.read(coord_log_path)
      assert_includes coord_log, "coord_micro_tasks_missing"
      assert_includes coord_log, "coord_micro_tasks_retried"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
      FileUtils.rm_rf(Rails.root.join("agent_logs", "ai_workflow", run_id))
    end
  ensure
    travel_back
  end

  test "uses --artifact-id payload content as the PRD when starting at in_analysis" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    source = Artifact.create!(
      name: "PRD Source #{run_id}",
      artifact_type: "feature",
      phase: "backlog",
      owner_persona: "SAP",
      payload: { "content" => "# PRD\n\n## 1. Overview\n- From artifact-id\n" }
    )

    travel_to(cst_tz.parse("2026-01-13 11:10:00.789")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      coord_log_path = log_dir.join("coordinator.log")

      ARGV.replace([
        "--",
        "--run-id=#{run_id}",
        "--mode=stage",
        "--stage=in_analysis",
        "--input=Analyze PRD",
        "--artifact-id=#{source.id}",
        "--rag-coord=foundation",
        "--model-coord=llama3.1:70b",
        "--model-sap=llama3.1:70b"
      ])

      captured_prompt = nil
      micro_tasks = [
        { "id" => "T1", "title" => "Task", "estimate" => "5m" }
      ]

      AiWorkflowService.stub :run, ->(prompt:, **_rest) do
        captured_prompt = prompt
        OpenStruct.new(output: "ok", context: { micro_tasks: micro_tasks }, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert File.exist?(coord_log_path), "expected #{coord_log_path} to exist"
      assert_includes captured_prompt.to_s, "From artifact-id"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
    end
  ensure
    travel_back
    Artifact.find_by(id: source.id)&.destroy if source
  end

  test "supports --start-agent=CWA using an existing artifact" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone

    source = Artifact.create!(
      name: "Dev Source #{run_id}",
      artifact_type: "feature",
      phase: "in_development",
      owner_persona: "CWA",
      payload: {
        "content" => "# PRD\n\n## 1. Overview\n- From artifact 45 style\n",
        "micro_tasks" => [
          { "id" => "T1", "title" => "Do thing", "estimate" => "5m" }
        ]
      }
    )

    travel_to(cst_tz.parse("2026-01-13 11:13:00.333")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      summary_path = log_dir.join("run_summary.md")

      ARGV.replace([
        "--",
        "--run-id=#{run_id}",
        "--mode=stage",
        "--start-agent=CWA",
        "--artifact-id=#{source.id}",
        "--input=Execute micro tasks",
        "--sandbox-level=loose",
        "--max-tool-calls=50",
        "--model-cwa=llama3.1:70b",
        "--model-sap=llama3.1:70b",
        "--model-coord=llama3.1:70b"
      ])

      captured = {}
      AiWorkflowService.stub :run, ->(prompt:, correlation_id:, **rest) do
        captured[:prompt] = prompt
        captured[:correlation_id] = correlation_id
        captured[:start_agent] = rest[:start_agent]
        captured[:model] = rest[:model]
        OpenStruct.new(output: "ok", context: { correlation_id: correlation_id }, error: nil)
      end do
        capture_io { Rake::Task["agent:test_sdlc"].invoke }
      end

      assert_equal run_id, captured[:correlation_id]
      assert_equal "CWA", captured[:start_agent]
      assert_equal "llama3.1:70b", captured[:model]
      assert_includes captured[:prompt].to_s, "Execute micro tasks"

      assert File.exist?(summary_path), "expected #{summary_path} to exist"
      assert_includes File.read(summary_path), source.name
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
    end
  ensure
    travel_back
    Artifact.find_by(id: source.id)&.destroy if source
  end

  test "fails when output is still not a prd after retry" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    travel_to(cst_tz.parse("2026-01-13 11:08:00.123")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      sap_log_path = log_dir.join("sap.log")

      ARGV.replace([ "--", "--run-id=#{run_id}", "--input=Generate portal at /admin", "--rag-sap=foundation", "--model-sap=llama3.1:70b" ])

      invalid = "This is a comprehensive set of templates and guidelines..."

      AiWorkflowService.stub :run, ->(**_kwargs) do
        OpenStruct.new(output: invalid, context: {}, error: nil)
      end do
        err = assert_raises(RuntimeError) { capture_io { Rake::Task["agent:test_sdlc"].invoke } }
        assert_includes err.message, "SAP PRD output was not valid after retry"
      end

      assert File.exist?(sap_log_path), "expected #{sap_log_path} to exist"
      assert_includes File.read(sap_log_path), "sap_prd_still_invalid"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
    end
  ensure
    travel_back
  end

  test "raises workflow failure when retry attempt returns an error payload" do
    run_id = "test-run-#{SecureRandom.uuid}"
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    travel_to(cst_tz.parse("2026-01-13 11:08:00.123")) do
      run_dir_name = "#{Time.current.in_time_zone(cst_tz).strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"
      log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
      sap_log_path = log_dir.join("sap.log")

      ARGV.replace([ "--", "--run-id=#{run_id}", "--input=Generate portal at /admin", "--rag-sap=foundation", "--model-sap=llama3.1:70b" ])

      invalid = "This is a comprehensive set of templates and guidelines..."
      call_count = 0
      AiWorkflowService.stub :run, ->(**_kwargs) do
        call_count += 1
        if call_count == 1
          OpenStruct.new(output: invalid, context: {}, error: nil)
        else
          OpenStruct.new(output: nil, context: {}, error: "Net::ReadTimeout with #<TCPSocket:(closed)>", error_class: "Faraday::TimeoutError")
        end
      end do
        err = assert_raises(RuntimeError) { capture_io { Rake::Task["agent:test_sdlc"].invoke } }
        assert_includes err.message, "SAP workflow failed on retry"
        assert_includes err.message, "Faraday::TimeoutError"
      end

      assert File.exist?(sap_log_path), "expected #{sap_log_path} to exist"
      assert_includes File.read(sap_log_path), "sap_workflow_failed"
    ensure
      FileUtils.rm_rf(log_dir) if defined?(log_dir) && Dir.exist?(log_dir)
    end
  ensure
    travel_back
  end
end
