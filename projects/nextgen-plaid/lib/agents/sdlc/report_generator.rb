# frozen_string_literal: true

module Agents
  module Sdlc
    class ReportGenerator
      def initialize(run_id:, run_dir_name:, started_at:, finished_at:, duration_ms:, opts:, summary_artifact_id:, summary_run_id:, output_files:, evidence:, validation:, scoring:, workflow_event_types:, error_class:, error_message:, workflow_error_class:, workflow_error:)
        @run_id = run_id
        @run_dir_name = run_dir_name
        @started_at = started_at
        @finished_at = finished_at
        @duration_ms = duration_ms
        @opts = opts
        @summary_artifact_id = summary_artifact_id
        @summary_run_id = summary_run_id
        @output_files = output_files
        @evidence = evidence
        @validation = validation
        @scoring = scoring
        @workflow_event_types = workflow_event_types
        @error_class = error_class
        @error_message = error_message
        @workflow_error_class = workflow_error_class
        @workflow_error = workflow_error
      end

      def build_summary_log
        <<~LOG
          run_id=#{@run_id}
          run_dir=#{@run_dir_name}
          generated_at=#{Time.current.iso8601}
          score=#{@scoring["score"]}
          pass=#{@scoring["pass"]}
        LOG
      end

      def build_run_summary_md
        prd_link = @evidence.dig("files", "prd_path")
        cwa_summary_link = @evidence.dig("tests", "cwa_summary_path")

        coordinator_tasks = @evidence["micro_tasks"].is_a?(Array) ? @evidence["micro_tasks"].length : 0
        artifact_line = if @evidence["artifact"].present?
          a = @evidence["artifact"]
          "- #{a['id']}: #{a['name']}#{a['artifact_type'] ? " (#{a['artifact_type']})" : ""}#{a['phase'] ? ", phase=#{a['phase']}" : ""}#{a['owner_persona'] ? ", owner=#{a['owner_persona']}" : ""}"
        else
          "- (unknown)"
        end

        <<~MD
          # SDLC CLI Run Summary

          ## Run metadata
          - run_id: #{@run_id}
          - run_dir: #{@run_dir_name}
          - started_at: #{@started_at.iso8601}
          - finished_at: #{@finished_at.iso8601}
          - duration_ms: #{@duration_ms}
          - final_phase/status: #{@evidence.dig("artifact", "phase") || "(unknown)"}
          - artifact_id: #{@summary_artifact_id}
          - ai_workflow_run_id: #{@summary_run_id}

          ## Artifacts
          #{artifact_line}

          ## CLI arguments / variations used
          - argv: #{Array(@opts[:argv]).join(' ')}
          - models: sap=#{@opts[:model_sap]} coord=#{@opts[:model_coord]} cwa=#{@opts[:model_cwa]}
          - sandbox_level: #{@opts[:sandbox_level]}
          - max_tool_calls: #{@opts[:max_tool_calls]}
          - dry_run: #{@opts[:dry_run]}

          ## Phase progression timeline
          - (see JSON logs in `knowledge_base/logs/cli_tests/#{@run_dir_name}/*.log`)

          ## Generated PRD
          #{prd_link ? "- #{prd_link}" : "- (missing)"}

          ## Coordinator plan (micro_tasks) summary
          - micro_tasks_count: #{coordinator_tasks}
          - micro_tasks_valid: #{@validation.dig("micro_tasks", "valid")}

          ## CWA execution summary
          #{cwa_summary_link ? "- cwa_summary: #{cwa_summary_link}" : "- cwa_summary: (missing)"}

          ## Scoring + suggestions
          - overall_score: #{@scoring["score"]} / 10
          - pass_threshold: 7
          - pass: #{@scoring["pass"]}
          - rubric:
          #{@scoring.fetch("rubric", {}).map { |k, v| "  - #{k}: #{v}" }.join("\n")}
          #{@scoring["notes"].present? ? "- suggestions:\n#{Array(@scoring['notes']).map { |n| "  - #{n}" }.join("\n")}" : ""}

          ## LLM usage stats
          - models_used: sap=#{@opts[:model_sap]} coord=#{@opts[:model_coord]} cwa=#{@opts[:model_cwa]}
          - workflow_event_types: #{@workflow_event_types.sort.join(', ')}
          - llm_calls_captured: #{@evidence.dig("llm_calls", "count")}
          #{@evidence.dig("llm_calls", "files").present? ? "- llm_call_logs:\n#{@evidence.dig('llm_calls', 'files').map { |f| "  - #{f}" }.join("\n")}" : ""}

          ## Errors / Escalations / Failure Evidence
          - last_phase_reached: #{@evidence.dig("artifact", "phase") || "(unknown)"}
          - last_exception: #{[ @error_class, @error_message ].compact.join(": ").presence || "(none)"}
          - workflow_error: #{[ @workflow_error_class, @workflow_error ].compact.join(": ").presence || "(none)"}
          - relevant_logs:
            - knowledge_base/logs/cli_tests/#{@run_dir_name}/cli.log
            - knowledge_base/logs/cli_tests/#{@run_dir_name}/summary.log
        MD
      end
    end
  end
end
