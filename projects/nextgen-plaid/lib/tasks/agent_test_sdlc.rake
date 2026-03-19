require "timeout"
require "securerandom"

require Rails.root.join("lib", "agents", "sdlc_test_options")
require Rails.root.join("lib", "agents", "sdlc_cli_json_logger")
require Rails.root.join("lib", "agents", "sdlc_sap_rag_builder")
require Rails.root.join("lib", "agents", "sdlc_sap_prompt_builder")
require Rails.root.join("lib", "agents", "sdlc_cwa_prompt_builder")
require Rails.root.join("lib", "agents", "sdlc_validation_scoring")

namespace :agent do
  desc "Run autonomous SDLC test workflow (PRD-AH-012A)"
  task test_sdlc: :environment do
    retry_workflow_error = Class.new(StandardError)
    prd_only_stop = Class.new(StandardError)

    argv = ARGV.drop_while { |a| a != "--" }
    argv = argv.length > 0 ? argv.drop(1) : []

    begin
      opts = Agents::SdlcTestOptions.parse(argv)
    rescue Agents::SdlcTestOptions::HelpRequested
      # The OptionParser already printed help/examples.
      exit(0)
    rescue StandardError => e
      warn "Argument error: #{e.message}"
      exit(1)
    end

    # Preserve original argv for reporting.
    opts[:argv] = argv

    run_id = opts[:run_id]

    started_at = Time.current
    cst_tz = ActiveSupport::TimeZone["Central Time (US & Canada)"] || Time.zone
    started_at_cst = started_at.in_time_zone(cst_tz)
    run_dir_name = "#{started_at_cst.strftime('%y%m%d-%H%M%S.%L')}-#{run_id}"

    log_dir = Rails.root.join("knowledge_base", "logs", "cli_tests", run_dir_name)
    log_path = log_dir.join("cli.log")
    sap_log_path = log_dir.join("sap.log")
    coord_log_path = log_dir.join("coordinator.log")
    planner_log_path = log_dir.join("planner.log")
    cwa_log_path = log_dir.join("cwa.log")
    # Backwards-compatible report location (canonical per PRD-AH-012E is under knowledge_base/test_artifacts/<run_id>/).
    summary_path = log_dir.join("run_summary.md")

    puts "CLI test logs: #{log_dir}"

    logger = Agents::SdlcCliJsonLogger.new(path: log_path.to_s, run_id: run_id, argv: argv, debug: opts[:debug])
    sap_logger = Agents::SdlcCliJsonLogger.new(path: sap_log_path.to_s, run_id: run_id, argv: argv, debug: opts[:debug])
    coord_logger = Agents::SdlcCliJsonLogger.new(path: coord_log_path.to_s, run_id: run_id, argv: argv, debug: opts[:debug])
    planner_logger = Agents::SdlcCliJsonLogger.new(path: planner_log_path.to_s, run_id: run_id, argv: argv, debug: opts[:debug])

    read_json_lines = lambda do |path|
      return [] unless path && File.exist?(path)

      File.read(path, mode: "r:bom|utf-8")
        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        .lines
        .filter_map do |line|
          begin
            JSON.parse(line)
          rescue StandardError
            nil
          end
        end
    end

    user_email = ENV["USER_EMAIL"] || User.first&.email
    user = User.find_by(email: user_email)
    abort "No user found. Set USER_EMAIL or create a user in DB." if user.nil?

    artifact = nil
    run = nil

    logger.info(event: "cli_start", stage: "start", extra: { "parsed_args" => opts })

    rag = Agents::SdlcSapRagBuilder.build(opts[:rag_sap])
    rendered_prompt = Agents::SdlcSapPromptBuilder.build(
      input: opts[:input],
      rag_content: rag[:content],
      prompt_path: opts[:prompt_sap],
      prd_only: opts[:prd_only]
    )

    planner_rag = Agents::SdlcSapRagBuilder.build(opts[:rag_planner])

    planner_logger.info(
      event: "planner_overrides",
      stage: "planner",
      extra: {
        "model" => opts[:model_planner],
        "rag_tiers" => planner_rag[:tiers],
        "rag_truncated" => planner_rag[:truncated],
        "rag_length" => { "original" => planner_rag[:original_length], "final" => planner_rag[:final_length] },
        "prompt_path" => opts[:prompt_planner]
      }
    )

    sap_logger.info(
      event: "sap_prompt_resolved",
      stage: "sap",
      extra: {
        "model" => opts[:model_sap],
        "rag_tiers" => rag[:tiers],
        "rag_truncated" => rag[:truncated],
        "rag_length" => { "original" => rag[:original_length], "final" => rag[:final_length] },
        "prompt_path" => opts[:prompt_sap],
        "prompt" => rendered_prompt
      }
    )

    begin
      # Allow enough wall-clock time for (a) a slow long-form PRD generation and (b) a single retry.
      # This is independent of the underlying HTTP read timeout (see `AI_REQUEST_TIMEOUT`).
      workflow_timeout_s = Integer(ENV.fetch("AGENT_TEST_SDLC_TIMEOUT", "600"))
      Timeout.timeout(workflow_timeout_s) do
        ActiveRecord::Base.transaction do
          if opts[:start_agent].to_s == "CWA"
            raise "--artifact-id is required when using --start-agent=CWA" if opts[:artifact_id].blank?

            artifact = Artifact.find(opts[:artifact_id])
            artifact.payload ||= {}

            if artifact.payload["content"].to_s.strip.empty?
              raise "artifact_missing_prd_content"
            end

            # If micro_tasks are missing, generate them via Coordinator and persist to this artifact.
            unless artifact.payload["micro_tasks"].is_a?(Array) && artifact.payload["micro_tasks"].any?
              coord_rag = Agents::SdlcSapRagBuilder.build(opts[:rag_coord])
              base_coord_input = <<~TEXT
                You are coordinating the analysis phase.
                Break the PRD below into implementation micro-tasks.

                Return ONLY valid JSON in this exact shape:
                {"micro_tasks":[{"id":"T-001","title":"...","estimate":"30m","details":"..."}]}

                PRD CONTENT:
                #{artifact.payload["content"]}
              TEXT

              micro_tasks = nil
              2.times do |attempt|
                coord_input = base_coord_input
                if attempt == 1
                  coord_input += "\n\nIMPORTANT: Output must be STRICT JSON only (no markdown, no commentary)."
                end

                coord_prompt = Agents::SdlcSapPromptBuilder.build(
                  input: coord_input,
                  rag_content: coord_rag[:content],
                  prompt_path: opts[:prompt_coord]
                )

                coord_logger.info(
                  event: "coord_prompt_resolved",
                  stage: "coord",
                  artifact_id: artifact.id,
                  extra: {
                    "model" => opts[:model_coord],
                    "rag_tiers" => coord_rag[:tiers],
                    "rag_truncated" => coord_rag[:truncated],
                    "rag_length" => { "original" => coord_rag[:original_length], "final" => coord_rag[:final_length] },
                    "prompt_path" => opts[:prompt_coord],
                    "prompt" => coord_prompt,
                    "auto_generated" => true,
                    "attempt" => attempt + 1
                  }
                )

                coord_result = AiWorkflowService.run(
                  prompt: coord_prompt,
                  correlation_id: run_id,
                  model: opts[:model_coord],
                  test_mode: true,
                  test_overrides: {
                    "models" => {
                      "sap" => opts[:model_sap],
                      "coordinator" => opts[:model_coord],
                      "cwa" => opts[:model_cwa]
                    },
                    "sandbox_level" => opts[:sandbox_level],
                    "max_tool_calls" => opts[:max_tool_calls],
                    "llm_base_dir" => log_dir.join("test_artifacts", "llm_calls").to_s,
                    "cwa_log_path" => cwa_log_path.to_s,
                    "prompt_cwa" => opts[:prompt_cwa],
                    "rag_cwa" => opts[:rag_cwa]
                  },
                  start_agent: "Coordinator"
                )

                # Pull micro_tasks from context when available.
                micro_tasks = coord_result&.respond_to?(:context) ? (coord_result.context[:micro_tasks] || coord_result.context["micro_tasks"]) : nil

                # Prefer parsing strict JSON from output.
                if (!micro_tasks.is_a?(Array) || micro_tasks.empty?) && coord_result&.respond_to?(:output)
                  txt = coord_result.output.to_s
                  json_obj = txt[/\{\s*"micro_tasks"\s*:\s*\[.*?\]\s*\}/m]
                  if json_obj
                    parsed = JSON.parse(json_obj) rescue nil
                    micro_tasks = parsed["micro_tasks"] if parsed.is_a?(Hash)
                  end
                end

                break if micro_tasks.is_a?(Array) && micro_tasks.any?
                coord_logger.warn(event: "coord_micro_tasks_missing", stage: "coord", artifact_id: artifact.id, extra: { "auto_generated" => true, "attempt" => attempt + 1 })
              end

              unless micro_tasks.is_a?(Array) && micro_tasks.any?
                raise "artifact_missing_micro_tasks"
              end

              artifact.payload["micro_tasks"] = micro_tasks
              artifact.save!
              artifact.reload

              coord_logger.info(
                event: "coord_micro_tasks_persisted",
                stage: "coord",
                artifact_id: artifact.id,
                extra: { "count" => micro_tasks.length, "auto_generated" => true }
              )
            end

            # Ensure the artifact is at least in development so the CWA loopback transition is valid.
            # If the artifact is already beyond development (e.g. ready_for_qa), do not attempt to "rewind"
            # back to in_development.
            phases = Artifact::PHASES
            dev_idx = phases.index("in_development")
            cur_idx = phases.index(artifact.phase.to_s)

            if dev_idx && cur_idx && cur_idx < dev_idx
              max_hops = phases.length + 2
              hops = 0
              while (phases.index(artifact.phase.to_s) || 0) < dev_idx && hops < max_hops
                artifact.transition_to("approve", artifact.owner_persona)
                artifact.reload
                hops += 1
              end

              cur_idx = phases.index(artifact.phase.to_s)
              raise "artifact_not_in_development" if cur_idx.nil? || cur_idx < dev_idx
            end
          else
            artifact = Artifact.create!(
              name: "SDLC Test Run #{run_id}",
              artifact_type: "sdlc_test",
              phase: "backlog",
              owner_persona: "SAP",
              payload: { "test_correlation_id" => run_id }
            )

            # AC2: Backlog -> Ready for Analysis after successful parse
            artifact.transition_to("approve", "SAP")
          end

          # Apply stage fast-forward if requested.
          # NOTE: PRD default stage is `backlog`, but AC2 requires moving to `ready_for_analysis` on parse.
          # So we only fast-forward when the caller asks for a stage beyond the default.
          if opts[:stage].to_s != "backlog"
            max_hops = Artifact::PHASES.length + 2
            hops = 0
            while artifact.phase != opts[:stage]
              prior = artifact.phase
              artifact.transition_to("approve", artifact.owner_persona)
              hops += 1
              raise "Stage fast-forward stalled at phase=#{artifact.phase}" if artifact.phase == prior
              raise "Stage fast-forward exceeded max hops" if hops > max_hops
            end

            # Stage isolation contract (AH-012): inject minimal payload required to operate in analysis.
            if artifact.phase == "in_analysis" && artifact.payload["content"].to_s.strip.empty?
              prd_source_artifact_id = opts[:artifact_id]
              prd_path = opts[:prd_path].to_s
              if prd_source_artifact_id.present?
                source = Artifact.find_by(id: prd_source_artifact_id)
                content = source&.payload&.fetch("content", nil)
                if content.to_s.strip.empty?
                  raise "--artifact-id #{prd_source_artifact_id} has no payload['content'] to use as PRD"
                end
                artifact.payload["content"] = content.to_s
              elsif prd_path.present?
                prd_text = File.read(prd_path, mode: "r:bom|utf-8")
                  .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
                artifact.payload["content"] = prd_text
              else
                artifact.payload["content"] = "# PRD\n\n## 1. Overview\n- (synthetic) #{opts[:input]}\n\n## 17. Open Questions\n- None\n"
              end
              artifact.save!
            end
          end

          run = AiWorkflowRun.create!(
            user: user,
            status: "draft",
            correlation_id: run_id,
            metadata: {
              "active_artifact_id" => artifact.id,
              "linked_artifact_ids" => [ artifact.id ]
            }
          )

          logger.info(event: "db_created", stage: "db", artifact_id: artifact.id, ai_workflow_run_id: run.id)

          if opts[:dry_run]
            # PRD-AH-012A: inject synthetic payloads required for downstream phases.
            artifact.payload["content"] ||= "(dry-run) synthetic PRD for #{run_id}"
            artifact.payload["micro_tasks"] ||= [
              { "id" => "dry-task-01", "title" => "(dry-run) placeholder task", "estimate" => "5m" }
            ]
            artifact.payload["implementation_notes"] ||= "(dry-run) no-op"
            artifact.save!

            # PRD-AH-012A: advance through transitions without any LLM/tool calls.
            # If a stage was specified, we already fast-forwarded to it above.
            while artifact.phase != "complete"
              artifact.transition_to("approve", artifact.owner_persona)
            end

            logger.info(event: "dry_run_complete", stage: "dry_run", artifact_id: artifact.id, ai_workflow_run_id: run.id)
          else
            test_overrides = {
              "models" => {
                "sap" => opts[:model_sap],
                "coordinator" => opts[:model_coord],
                "planner" => opts[:model_planner],
                "cwa" => opts[:model_cwa]
              },
              "sandbox_level" => opts[:sandbox_level],
              "max_tool_calls" => opts[:max_tool_calls],
              "llm_base_dir" => log_dir.join("test_artifacts", "llm_calls").to_s,
              "cwa_log_path" => cwa_log_path.to_s,
              "prompt_planner" => opts[:prompt_planner],
              "planner_rag_content" => planner_rag[:content],
              "prompt_cwa" => opts[:prompt_cwa],
              "rag_cwa" => opts[:rag_cwa],
              "prd_only" => opts[:prd_only]
            }

            start_agent = opts[:start_agent].presence
            stage_mode = opts[:mode].to_s == "stage"
            coordinator_mode = stage_mode && start_agent.nil? && opts[:stage].to_s == "in_analysis"
            cwa_mode = stage_mode && start_agent.to_s == "CWA"

            # PRD validation: `/admin` is often requested but can be omitted by the model even when
            # the PRD is otherwise usable. Allow relaxing this requirement for consistency testing.
            require_admin_route = opts[:input].to_s.include?("/admin")
            require_admin_route = false if ENV.fetch("AI_PRD_REQUIRE_ADMIN_ROUTE", "true").to_s.downcase == "false"
            prd_valid = lambda do |text|
              t = text.to_s
              return false if t.strip.empty?
              return false unless t.lstrip.start_with?("# PRD")
              if require_admin_route
                # Accept either a generic /admin mention or the concrete routes requested.
                return false unless t.include?("/admin") || t.include?("/admin/ai_workflow_runs")
              end
              true
            end

            logger.info(event: "invoke_workflow", stage: "invoke", artifact_id: artifact.id, ai_workflow_run_id: run.id)

            result = nil
            attempts = 0
            begin
              attempts += 1
              if cwa_mode
                workflow_logger = logger

                # When starting at CWA, explicitly include the artifact's micro_tasks in the prompt.
                # The workflow context does not automatically hydrate from the Artifact payload.
                tasks = artifact.payload["micro_tasks"]
                tasks_json = tasks.is_a?(Array) ? JSON.pretty_generate(tasks) : "[]"

                # Seed the workflow context with the artifact micro-tasks so CWA can operate on them
                # (the workflow context is not automatically hydrated from the Artifact payload).
                test_overrides["micro_tasks"] = tasks if tasks.is_a?(Array) && tasks.any?

                cwa_prompt = Agents::SdlcCwaPromptBuilder.build(
                  input: opts[:input],
                  artifact_id: artifact.id,
                  prd_content: artifact.payload["content"],
                  micro_tasks_json: tasks_json,
                  prompt_path: opts[:prompt_cwa]
                )

                # Write a plan summary artifact for CWA runs too (so humans can see the tasks list).
                test_artifacts_dir = log_dir.join("test_artifacts")
                FileUtils.mkdir_p(test_artifacts_dir)
                File.write(test_artifacts_dir.join("micro_tasks.json"), tasks_json)
                if tasks.is_a?(Array) && tasks.any?
                  checklist = tasks.map do |t|
                    id = t["id"] || t[:id]
                    title = t["title"] || t[:title]
                    estimate = t["estimate"] || t[:estimate]
                    "- [ ] **#{id}**: #{title} (#{estimate})"
                  end.join("\n")
                  File.write(test_artifacts_dir.join("plan_summary.md"), "# Plan Summary\n\n#{checklist}\n")
                end

                result = AiWorkflowService.run(
                  prompt: cwa_prompt,
                  correlation_id: run_id,
                  model: opts[:model_cwa],
                  test_mode: true,
                  test_overrides: test_overrides,
                  start_agent: "CWA"
                )
              elsif coordinator_mode
                workflow_logger = coord_logger
                coord_rag = Agents::SdlcSapRagBuilder.build(opts[:rag_coord])
                coord_input = <<~TEXT
                  You are coordinating the analysis phase.
                  Break the PRD below into implementation micro-tasks.
                  Return `micro_tasks` in context (preferred) and/or include them clearly in your response.

                  PRD CONTENT:
                  #{artifact.payload["content"]}
                TEXT

                coord_prompt = Agents::SdlcSapPromptBuilder.build(
                  input: coord_input,
                  rag_content: coord_rag[:content],
                  prompt_path: opts[:prompt_coord]
                )

                coord_logger.info(
                  event: "coord_prompt_resolved",
                  stage: "coord",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: {
                    "model" => opts[:model_coord],
                    "rag_tiers" => coord_rag[:tiers],
                    "rag_truncated" => coord_rag[:truncated],
                    "rag_length" => { "original" => coord_rag[:original_length], "final" => coord_rag[:final_length] },
                    "prompt_path" => opts[:prompt_coord],
                    "prompt" => coord_prompt
                  }
                )

                result = AiWorkflowService.run(
                  prompt: coord_prompt,
                  correlation_id: run_id,
                  model: opts[:model_coord],
                  test_mode: true,
                  test_overrides: test_overrides,
                  start_agent: "Coordinator"
                )
              else
                workflow_logger = sap_logger
                result = AiWorkflowService.run(
                  prompt: rendered_prompt,
                  correlation_id: run_id,
                  model: opts[:model_sap],
                  test_mode: true,
                  test_overrides: test_overrides,
                  start_agent: "SAP",
                  max_turns: (opts[:prd_only] ? (opts[:model_sap].to_s.start_with?("llama") ? 3 : 1) : 10)
                )
              end

              # If the workflow returns an error payload (instead of raising),
              # surface that as the primary failure rather than a missing PRD.
              workflow_error = result&.respond_to?(:error) ? result.error : nil
              if workflow_error.present?
                workflow_error_class = result&.respond_to?(:error_class) ? result.error_class : nil
                retryable = [ "Faraday::TimeoutError", "Net::ReadTimeout" ].include?(workflow_error_class.to_s)

                if retryable && attempts < 2
                  workflow_logger.info(
                    event: coordinator_mode ? "coord_workflow_retry" : "sap_workflow_retry",
                    stage: coordinator_mode ? "coord" : "sap",
                    artifact_id: artifact.id,
                    ai_workflow_run_id: run.id,
                    extra: { "attempt" => attempts, "error_class" => workflow_error_class, "error" => workflow_error.to_s }
                  )
                  sleep 0.5
                  raise retry_workflow_error
                end

                workflow_logger.error(
                  event: coordinator_mode ? "coord_workflow_failed" : "sap_workflow_failed",
                  stage: coordinator_mode ? "coord" : "sap",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "error_class" => workflow_error_class, "error" => workflow_error.to_s }
                )
                who = coordinator_mode ? "Coordinator" : "SAP"
                raise "#{who} workflow failed: #{workflow_error_class || workflow_error.class}: #{workflow_error}"
              end
            rescue retry_workflow_error
              retry
            end

            logger.info(event: "workflow_complete", stage: "invoke", artifact_id: artifact.id, ai_workflow_run_id: run.id)

            artifact.reload

            if opts[:mode].to_s == "end_to_end"
              # End-to-end runs must produce micro_tasks by the time we reach (or pass) in_analysis.
              in_analysis_idx = Artifact::PHASES.index("in_analysis")
              current_idx = Artifact::PHASES.index(artifact.phase.to_s)
              current_idx ||= 0
              if in_analysis_idx && current_idx >= in_analysis_idx
                micro_tasks = artifact.payload["micro_tasks"]
                if micro_tasks.blank?
                  planner_logger.error(
                    event: "guardrail_micro_tasks_missing",
                    stage: "planner",
                    artifact_id: artifact.id,
                    ai_workflow_run_id: run.id,
                    extra: { "phase" => artifact.phase }
                  )
                  raise "micro_tasks_missing_after_end_to_end"
                end
              end

              # When tools are enabled / sandbox is loose, require implementation_notes.
              # Only enforce once we've reached the development phases where CWA/tool execution is expected
              # to have produced these notes.
              ready_for_dev_idx = Artifact::PHASES.index("ready_for_development")
              if opts[:sandbox_level].to_s == "loose" && ready_for_dev_idx && current_idx >= ready_for_dev_idx && artifact.payload["implementation_notes"].to_s.strip.empty?
                logger.error(
                  event: "guardrail_implementation_notes_missing",
                  stage: "guardrail",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "phase" => artifact.phase, "sandbox_level" => opts[:sandbox_level] }
                )
                raise "implementation_notes_missing"
              end
            end

            if coordinator_mode
              extract_micro_tasks_from_output = lambda do |text|
                t = text.to_s
                return nil if t.strip.empty?
                return nil unless t.include?("## Micro Tasks")

                # Expect a JSON array in the `## Micro Tasks` section.
                after = t.split("## Micro Tasks", 2)[1]
                return nil if after.nil?
                json_part = after
                json_part = json_part.split("## Notes", 2)[0] if json_part.include?("## Notes")
                json_part = json_part.strip

                # Allow fenced code blocks (```json ... ```), but only parse the JSON array.
                json_part = json_part.gsub(/\A```\s*json\s*/i, "").gsub(/\A```\s*/i, "")
                json_part = json_part.gsub(/```\s*\z/, "")
                json_part = json_part.strip

                # If there is extra text, extract the first JSON array.
                if (m = json_part.match(/\[[\s\S]*\]/))
                  json_part = m[0]
                end

                begin
                  parsed = JSON.parse(json_part)
                  return nil unless parsed.is_a?(Array)
                  parsed
                rescue JSON::ParserError
                  nil
                end
              end

              micro_tasks = artifact.payload["micro_tasks"]
              micro_tasks = result&.context&.dig(:micro_tasks) if micro_tasks.blank?
              micro_tasks = result&.context&.dig("micro_tasks") if micro_tasks.blank?
              micro_tasks = extract_micro_tasks_from_output.call(result&.output) if micro_tasks.blank?

              valid_micro_tasks = lambda do |tasks|
                return false unless tasks.is_a?(Array) && tasks.any?
                tasks.all? do |t|
                  next false unless t.is_a?(Hash)
                  id = t["id"] || t[:id]
                  title = t["title"] || t[:title]
                  estimate = t["estimate"] || t[:estimate]
                  id.to_s.strip.present? && title.to_s.strip.present? && estimate.to_s.strip.present?
                end
              end

              if micro_tasks.present? && !valid_micro_tasks.call(micro_tasks)
                coord_logger.info(
                  event: "coord_micro_tasks_invalid",
                  stage: "coord",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "count" => micro_tasks.is_a?(Array) ? micro_tasks.length : nil }
                )
                micro_tasks = nil
              end

              # If micro_tasks are missing or invalid, retry once with stricter instructions and minimized RAG.
              if micro_tasks.blank?
                coord_logger.info(
                  event: "coord_micro_tasks_missing",
                  stage: "coord",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id
                )

                retry_input = <<~TEXT
                  CRITICAL FORMAT LOCK:
                  - Output MUST start with '# Coordinator Analysis'.
                  - Output MUST include '## Micro Tasks' followed by a JSON array ONLY (no prose).
                  - Each task MUST include id/title/estimate.

                  USER REQUEST:
                  #{opts[:input]}

                  PRD CONTENT:
                  #{artifact.payload["content"]}
                TEXT

                retry_prompt = Agents::SdlcSapPromptBuilder.build(
                  input: retry_input,
                  rag_content: "",
                  prompt_path: opts[:prompt_coord]
                )

                retry_result = AiWorkflowService.run(
                  prompt: retry_prompt,
                  correlation_id: run_id,
                  model: opts[:model_coord],
                  test_mode: true,
                  test_overrides: test_overrides,
                  start_agent: "Coordinator"
                )

                retry_workflow_error = retry_result&.respond_to?(:error) ? retry_result.error : nil
                if retry_workflow_error.present?
                  retry_workflow_error_class = retry_result&.respond_to?(:error_class) ? retry_result.error_class : nil
                  coord_logger.error(
                    event: "coord_workflow_failed",
                    stage: "coord",
                    artifact_id: artifact.id,
                    ai_workflow_run_id: run.id,
                    extra: { "attempt" => "retry", "error_class" => retry_workflow_error_class, "error" => retry_workflow_error.to_s }
                  )
                  raise "Coordinator workflow failed on retry: #{retry_workflow_error_class || retry_workflow_error.class}: #{retry_workflow_error}"
                end

                micro_tasks = retry_result&.context&.dig(:micro_tasks)
                micro_tasks = retry_result&.context&.dig("micro_tasks") if micro_tasks.blank?
                micro_tasks = extract_micro_tasks_from_output.call(retry_result&.output) if micro_tasks.blank?

                if micro_tasks.present? && !valid_micro_tasks.call(micro_tasks)
                  micro_tasks = nil
                end

                if micro_tasks.blank?
                  coord_logger.error(
                    event: "coord_micro_tasks_still_missing",
                    stage: "coord",
                    artifact_id: artifact.id,
                    ai_workflow_run_id: run.id
                  )
                  raise "Coordinator micro_tasks were not valid after retry"
                end

                coord_logger.info(
                  event: "coord_micro_tasks_retried",
                  stage: "coord",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "count" => micro_tasks.length }
                )
              end

              if micro_tasks.present?
                artifact.payload ||= {}
                artifact.payload["micro_tasks"] = micro_tasks
                artifact.save!
                artifact.reload

                coord_logger.info(
                  event: "coord_micro_tasks_persisted",
                  stage: "coord",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "count" => micro_tasks.length }
                )
              end

              # Write plan summary for humans.
              test_artifacts_dir = log_dir.join("test_artifacts")
              FileUtils.mkdir_p(test_artifacts_dir)
              plan_path = test_artifacts_dir.join("plan_summary.md")

              tasks = artifact.payload["micro_tasks"]
              checklist = if tasks.is_a?(Array) && tasks.any?
                tasks.map do |t|
                  id = t["id"] || t[:id]
                  title = t["title"] || t[:title]
                  estimate = t["estimate"] || t[:estimate]
                  "- [ ] **#{id}**: #{title} (#{estimate})"
                end.join("\n")
              else
                "- (none)"
              end

              File.write(plan_path, "# Plan Summary\n\n#{checklist}\n")

              coord_logger.info(
                event: "coord_plan_summary_written",
                stage: "coord",
                artifact_id: artifact.id,
                ai_workflow_run_id: run.id,
                extra: { "path" => plan_path.to_s }
              )

              # Persist handoff payload snapshots from workflow events.
              workflow_events_path = Rails.root.join("agent_logs", "ai_workflow", run_id.to_s, "events.ndjson")
              if File.exist?(workflow_events_path)
                handoffs = read_json_lines.call(workflow_events_path).select { |r| r["type"] == "agent_handoff" }
                if handoffs.any?
                  handoffs_dir = test_artifacts_dir.join("handoffs")
                  FileUtils.mkdir_p(handoffs_dir)

                  handoffs.each do |h|
                    ts = h["ts"].to_s.gsub(/[^0-9TZ]/, "")
                    from = h["from"].to_s
                    to = h["to"].to_s
                    path = handoffs_dir.join("#{ts}-#{from}_to_#{to}.json")
                    File.write(path, JSON.pretty_generate(h) + "\n")
                  end

                  coord_logger.info(
                    event: "coord_handoffs_written",
                    stage: "coord",
                    artifact_id: artifact.id,
                    ai_workflow_run_id: run.id,
                    extra: { "count" => handoffs.length }
                  )
                end
              end

            else

            # In test runs we want a deterministic persisted PRD payload. Depending on agent routing,
            # the workflow output may not have been synchronized into the artifact yet.
            prd_content = artifact.payload["content"].to_s
            if prd_content.strip.empty?
              fallback = result&.output.to_s
              if fallback.strip.present?
                artifact.payload ||= {}
                artifact.payload["content"] = fallback
                artifact.save!
                artifact.reload
                prd_content = artifact.payload["content"].to_s

                sap_logger.info(
                  event: "sap_prd_backfilled",
                  stage: "sap",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "content_length" => prd_content.length }
                )
              end
            end

            # If we got content but it's not shaped like a PRD for the requested feature,
            # retry once with minimized RAG to reduce distractions.
            if prd_content.present? && !prd_valid.call(prd_content)
              sap_logger.info(
                event: "sap_prd_invalid",
                stage: "sap",
                artifact_id: artifact.id,
                ai_workflow_run_id: run.id,
                extra: { "content_length" => prd_content.length }
              )

              retry_prompt = Agents::SdlcSapPromptBuilder.build(
                input: <<~TEXT,
                  CRITICAL FORMAT LOCK:
                  - Output MUST start with '# PRD'.
                  - You MUST fill the PRD template sections 1–17 with at least 1 bullet each.
                  - Do NOT add extra headings.

                  CRITICAL ROUTES LOCK:
                  - You MUST explicitly mention BOTH routes in the PRD:
                    - /admin/ai_workflow_runs
                    - /admin/ai_workflow_runs/:id

                  USER REQUEST:
                  #{opts[:input]}
                TEXT
                rag_content: "",
                prompt_path: opts[:prompt_sap]
              )

              retry_result = AiWorkflowService.run(
                prompt: retry_prompt,
                correlation_id: run_id,
                model: opts[:model_sap],
                test_mode: true,
                test_overrides: test_overrides
              )

              retry_workflow_error = retry_result&.respond_to?(:error) ? retry_result.error : nil
              if retry_workflow_error.present?
                retry_workflow_error_class = retry_result&.respond_to?(:error_class) ? retry_result.error_class : nil
                sap_logger.error(
                  event: "sap_workflow_failed",
                  stage: "sap",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "attempt" => "retry", "error_class" => retry_workflow_error_class, "error" => retry_workflow_error.to_s }
                )
                raise "SAP workflow failed on retry: #{retry_workflow_error_class || retry_workflow_error.class}: #{retry_workflow_error}"
              end

              retry_output = retry_result&.output.to_s
              if retry_output.present?
                # Artifact uses optimistic locking; during long multi-agent runs it's possible
                # for the record to be updated between load and save. Retry a few times.
                attempts = 0
                begin
                  attempts += 1
                  artifact.reload if attempts > 1
                  artifact.payload ||= {}
                  artifact.payload["content"] = retry_output
                  artifact.save!
                  artifact.reload
                rescue ActiveRecord::StaleObjectError
                  raise if attempts >= 3
                  sleep 0.05
                  retry
                end
                prd_content = artifact.payload["content"].to_s

                sap_logger.info(
                  event: "sap_prd_retried",
                  stage: "sap",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "content_length" => prd_content.length }
                )
              end

              if prd_content.blank? || !prd_valid.call(prd_content)
                sap_logger.error(
                  event: "sap_prd_still_invalid",
                  stage: "sap",
                  artifact_id: artifact.id,
                  ai_workflow_run_id: run.id,
                  extra: { "content_length" => prd_content.to_s.length }
                )

                # One more retry with an even more targeted prompt.
                second_retry_prompt = Agents::SdlcSapPromptBuilder.build(
                  input: <<~TEXT,
                    RETURN ONLY THE PRD.

                    - Start with exactly: # PRD
                    - Include the literal strings '/admin/ai_workflow_runs' and '/admin/ai_workflow_runs/:id'
                    - Use the 17 numbered headings (1..17) from the template.
                    - At least one bullet per section.

                    USER REQUEST:
                    #{opts[:input]}
                  TEXT
                  rag_content: "",
                  prompt_path: opts[:prompt_sap]
                )

                second_retry_result = AiWorkflowService.run(
                  prompt: second_retry_prompt,
                  correlation_id: run_id,
                  model: opts[:model_sap],
                  test_mode: true,
                  test_overrides: test_overrides
                )

                second_retry_output = second_retry_result&.output.to_s
                if second_retry_output.present?
                  attempts = 0
                  begin
                    attempts += 1
                    artifact.reload if attempts > 1
                    artifact.payload ||= {}
                    artifact.payload["content"] = second_retry_output
                    artifact.save!
                    artifact.reload
                  rescue ActiveRecord::StaleObjectError
                    raise if attempts >= 3
                    sleep 0.05
                    retry
                  end
                  prd_content = artifact.payload["content"].to_s
                end

                if prd_content.blank? || !prd_valid.call(prd_content)
                  expectation = require_admin_route ? "'# PRD' and /admin(/ai_workflow_runs)" : "'# PRD'"
                  raise "SAP PRD output was not valid after retry (expected #{expectation})"
                end
              end
            end

            if prd_content.strip.empty?
              sap_logger.error(
                event: "sap_prd_missing",
                stage: "sap",
                artifact_id: artifact.id,
                ai_workflow_run_id: run.id,
                extra: { "message" => "artifact.payload['content'] was blank after workflow" }
              )
              raise "Expected artifact.payload['content'] to be present after SAP phase"
            end

            sap_logger.info(
              event: "sap_prd_persisted",
              stage: "sap",
              artifact_id: artifact.id,
              ai_workflow_run_id: run.id,
              extra: { "content_length" => prd_content.length, "response" => prd_content }
            )
            end

          # PRD-AH-012F: always write task + execution artifacts for end-to-end runs.
          # (Stage-isolated runs may not generate these reliably, so we only enforce for end-to-end.)
          if opts[:mode].to_s == "end_to_end" || coordinator_mode
            # Extract and save PRD if it was generated/backfilled.
            # In end-to-end mode, SAP usually transitions the artifact to in_analysis
            # after writing the PRD to payload['content'].
            final_prd_content = artifact.payload["content"].to_s
            if final_prd_content.strip.present?
              test_artifacts_dir = log_dir.join("test_artifacts")
              FileUtils.mkdir_p(test_artifacts_dir)
              prd_path = test_artifacts_dir.join("prd.md")

              # Track versions if it already exists.
              if File.exist?(prd_path)
                versions_dir = test_artifacts_dir.join("prd_versions")
                FileUtils.mkdir_p(versions_dir)
                ts = Time.current.strftime("%Y%m%d%H%M%S%L")
                FileUtils.mv(prd_path, versions_dir.join("prd_#{ts}.md"))
              end

              File.write(
                prd_path,
                <<~MD
                  ---
                  run_id: #{run_id}
                  model: #{opts[:model_sap]}
                  rag_tiers: #{rag[:tiers].join(",")}
                  timestamp: #{Time.current.iso8601}
                  ---

                  #{final_prd_content}
                MD
              )

              sap_logger.info(
                event: "sap_prd_file_written",
                stage: "sap",
                artifact_id: artifact.id,
                ai_workflow_run_id: run.id,
                extra: { "path" => prd_path.to_s, "mode" => opts[:mode] }
              )
            end

            tasks = artifact.payload["micro_tasks"]
            tasks_json = tasks.is_a?(Array) ? JSON.pretty_generate(tasks) : "[]"
            test_artifacts_dir = log_dir.join("test_artifacts")
            FileUtils.mkdir_p(test_artifacts_dir)
            File.write(test_artifacts_dir.join("micro_tasks.json"), tasks_json)

            if tasks.is_a?(Array) && tasks.any?
              checklist = tasks.map do |t|
                id = t["id"] || t[:id]
                title = t["title"] || t[:title]
                estimate = t["estimate"] || t[:estimate]
                "- [ ] **#{id}**: #{title} (#{estimate})"
              end.join("\n")
              File.write(test_artifacts_dir.join("plan_summary.md"), "# Plan Summary\n\n#{checklist}\n")
            end
          end

          # PRD-only mode: stop immediately after generating and persisting the PRD so
          # we can inspect the raw LLM request/response and PRD output.
          if opts[:prd_only]
            logger.info(event: "prd_only_stop", stage: "sap", artifact_id: artifact.id, ai_workflow_run_id: run.id)
            raise prd_only_stop
          end
          end
      end
    rescue prd_only_stop
      # Exit cleanly; the ensure block will still write summaries.
    rescue StandardError => e
      duration_ms = ((Time.current - started_at) * 1000).to_i
      logger.error(event: "cli_error", stage: "error", artifact_id: artifact&.id, ai_workflow_run_id: run&.id, duration_ms: duration_ms, exception: e)
      sap_logger.error(event: "sap_error", stage: "sap", artifact_id: artifact&.id, ai_workflow_run_id: run&.id, duration_ms: duration_ms, exception: e)
      raise
    ensure
      # PRD-AH-012D: rollback sandbox worktree (if created) to avoid leaving temp branches/files behind.
      begin
        keep_sandbox = ENV.fetch("AI_KEEP_SANDBOX", "false").to_s.downcase == "true"
        AgentSandboxRunner.cleanup_worktree!(correlation_id: run_id) unless keep_sandbox
      rescue StandardError
        # ignore
      end

      finished_at = Time.current
      duration_ms = ((finished_at - started_at) * 1000).to_i
      logger.info(event: "cli_end", stage: "end", artifact_id: artifact&.id, ai_workflow_run_id: run&.id, duration_ms: duration_ms)

      FileUtils.mkdir_p(log_dir)

      cli_records = read_json_lines.call(log_path)
      sap_records = read_json_lines.call(sap_log_path)
      coord_records = read_json_lines.call(coord_log_path)

      # Prefer IDs from logs (survive transaction rollbacks); fall back to in-memory objects.
      db_created = cli_records.find { |r| r["event"] == "db_created" }
      summary_artifact_id = db_created&.fetch("artifact_id", nil) || artifact&.id
      summary_run_id = db_created&.fetch("ai_workflow_run_id", nil) || run&.id

      # Gather artifact details when available.
      linked_artifact_ids = []
      begin
        if summary_run_id.present?
          run_record = AiWorkflowRun.find_by(id: summary_run_id)
          ids = run_record&.metadata&.fetch("linked_artifact_ids", nil)
          linked_artifact_ids = ids if ids.is_a?(Array)
        end
      rescue StandardError
        linked_artifact_ids = []
      end
      linked_artifact_ids = ([ summary_artifact_id ].compact + linked_artifact_ids).uniq

      artifact_rows = linked_artifact_ids.map do |aid|
        a = Artifact.find_by(id: aid)
        if a
          { "id" => a.id, "name" => a.name, "artifact_type" => a.artifact_type, "phase" => a.phase, "owner_persona" => a.owner_persona }
        else
          { "id" => aid, "name" => "(not found - possibly rolled back)", "artifact_type" => nil, "phase" => nil, "owner_persona" => nil }
        end
      end

      cli_events = cli_records.filter_map { |r| r["event"] }.uniq
      sap_events = sap_records.filter_map { |r| r["event"] }.uniq
      coord_events = coord_records.filter_map { |r| r["event"] }.uniq

      # Workflow events are recorded by ArtifactWriter when present.
      workflow_events_path = Rails.root.join("agent_logs", "ai_workflow", run_id.to_s, "events.ndjson")
      workflow_event_types = read_json_lines.call(workflow_events_path).filter_map { |r| r["type"] }.uniq

      # Persist handoff payload snapshots from workflow events for all run modes
      # (end-to-end runs won't execute the `coordinator_mode` branch where this was originally written).
      begin
        if File.exist?(workflow_events_path)
          handoffs = read_json_lines.call(workflow_events_path).select { |r| r["type"] == "agent_handoff" }
          if handoffs.any?
            test_artifacts_dir = log_dir.join("test_artifacts")
            handoffs_dir = test_artifacts_dir.join("handoffs")
            FileUtils.mkdir_p(handoffs_dir)

            handoffs.each do |h|
              ts = h["ts"].to_s.gsub(/[^0-9TZ]/, "")
              from = h["from"].to_s
              to = h["to"].to_s
              path = handoffs_dir.join("#{ts}-#{from}_to_#{to}.json")
              File.write(path, JSON.pretty_generate(h) + "\n")
            end
          end
        end
      rescue StandardError
        # best-effort only
      end

      last_error_record = (coord_records + sap_records + cli_records).reverse.find { |r| r["level"] == "error" && (r["error"].present? || r["exception"].present?) }
      error_class = last_error_record&.dig("error", "class")
      error_message = last_error_record&.dig("error", "message")

      # Also pull error payload from workflow run.json when available.
      workflow_run_json_path = Rails.root.join("agent_logs", "ai_workflow", run_id.to_s, "run.json")
      workflow_error = nil
      workflow_error_class = nil
      begin
        if File.exist?(workflow_run_json_path)
          workflow_payload = JSON.parse(File.read(workflow_run_json_path, mode: "r:bom|utf-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: ""))
          workflow_error = workflow_payload["error"]
          workflow_error_class = workflow_payload["error_class"]
        end
      rescue StandardError
        workflow_error = nil
        workflow_error_class = nil
      end

      output_files = []
      begin
        test_artifacts_dir = log_dir.join("test_artifacts")
        if Dir.exist?(test_artifacts_dir)
          output_files = Dir.glob(test_artifacts_dir.join("**", "*").to_s)
            .select { |p| File.file?(p) }
            .map { |p| Pathname.new(p).relative_path_from(Rails.root).to_s }
            .sort
        end
      rescue StandardError
        output_files = []
      end

      # PRD-AH-012E: validation/scoring + report persistence.
      Agents::SdlcValidationScoring.run(
        run_id: run_id,
        log_dir: log_dir,
        run_dir_name: run_dir_name,
        started_at: started_at,
        finished_at: finished_at,
        duration_ms: duration_ms,
        opts: opts,
        summary_artifact_id: summary_artifact_id,
        summary_run_id: summary_run_id,
        output_files: output_files,
        error_class: error_class,
        error_message: error_message,
        workflow_error_class: workflow_error_class,
        workflow_error: workflow_error,
        workflow_event_types: workflow_event_types
      )
    end
  end

  desc "Re-run validation/scoring for an existing SDLC test run (PRD-AH-012E)"
  task rescore_sdlc: :environment do
    argv = ARGV.drop_while { |a| a != "--" }
    argv = argv.length > 0 ? argv.drop(1) : []

    begin
      opts = Agents::SdlcTestOptions.parse(argv)
    rescue Agents::SdlcTestOptions::HelpRequested
      exit(0)
    rescue StandardError => e
      warn "Argument error: #{e.message}"
      exit(1)
    end

    run_id = opts[:run_id]
    pattern = Rails.root.join("knowledge_base", "logs", "cli_tests", "*-#{run_id}")
    run_dirs = Dir.glob(pattern.to_s).sort
    abort "No prior run_dir found for run_id=#{run_id} under knowledge_base/logs/cli_tests" if run_dirs.empty?

    log_dir = Pathname.new(run_dirs.last)
    run_dir_name = log_dir.basename.to_s

    log_path = log_dir.join("cli.log")
    sap_log_path = log_dir.join("sap.log")
    coord_log_path = log_dir.join("coordinator.log")

    read_json_lines = lambda do |path|
      return [] unless path && File.exist?(path)

      File.read(path, mode: "r:bom|utf-8")
        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        .lines
        .filter_map do |line|
          begin
            JSON.parse(line)
          rescue StandardError
            nil
          end
        end
    end

    cli_records = read_json_lines.call(log_path)
    sap_records = read_json_lines.call(sap_log_path)
    coord_records = read_json_lines.call(coord_log_path)

    db_created = cli_records.find { |r| r["event"] == "db_created" }
    summary_artifact_id = db_created&.fetch("artifact_id", nil) || Artifact.find_by("payload ->> 'test_correlation_id' = ?", run_id)&.id
    summary_run_id = db_created&.fetch("ai_workflow_run_id", nil) || AiWorkflowRun.find_by(correlation_id: run_id)&.id

    workflow_events_path = Rails.root.join("agent_logs", "ai_workflow", run_id.to_s, "events.ndjson")
    workflow_event_types = read_json_lines.call(workflow_events_path).filter_map { |r| r["type"] }.uniq

    last_error_record = (coord_records + sap_records + cli_records).reverse.find { |r| r["level"] == "error" && (r["error"].present? || r["exception"].present?) }
    error_class = last_error_record&.dig("error", "class")
    error_message = last_error_record&.dig("error", "message")

    workflow_run_json_path = Rails.root.join("agent_logs", "ai_workflow", run_id.to_s, "run.json")
    workflow_error = nil
    workflow_error_class = nil
    begin
      if File.exist?(workflow_run_json_path)
        workflow_payload = JSON.parse(File.read(workflow_run_json_path, mode: "r:bom|utf-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: ""))
        workflow_error = workflow_payload["error"]
        workflow_error_class = workflow_payload["error_class"]
      end
    rescue StandardError
      workflow_error = nil
      workflow_error_class = nil
    end

    output_files = []
    begin
      test_artifacts_dir = log_dir.join("test_artifacts")
      if Dir.exist?(test_artifacts_dir)
        output_files = Dir.glob(test_artifacts_dir.join("**", "*").to_s)
          .select { |p| File.file?(p) }
          .map { |p| Pathname.new(p).relative_path_from(Rails.root).to_s }
          .sort
      end
    rescue StandardError
      output_files = []
    end

    started_at = Time.current
    finished_at = Time.current
    duration_ms = 0

    opts[:argv] = argv

    Agents::SdlcValidationScoring.run(
      run_id: run_id,
      log_dir: log_dir,
      run_dir_name: run_dir_name,
      started_at: started_at,
      finished_at: finished_at,
      duration_ms: duration_ms,
      opts: opts,
      summary_artifact_id: summary_artifact_id,
      summary_run_id: summary_run_id,
      output_files: output_files,
      error_class: error_class,
      error_message: error_message,
      workflow_error_class: workflow_error_class,
      workflow_error: workflow_error,
      workflow_event_types: workflow_event_types
    )
  end
end
end
