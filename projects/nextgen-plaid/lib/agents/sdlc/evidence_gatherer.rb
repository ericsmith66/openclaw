# frozen_string_literal: true

require "pathname"

module Agents
  module Sdlc
    class EvidenceGatherer
      def initialize(run_id:, artifact:, test_artifacts_dir:)
        @run_id = run_id
        @artifact = artifact
        @test_artifacts_dir = Pathname.new(test_artifacts_dir)
      end

      def call
        micro_tasks = @artifact&.payload&.fetch("micro_tasks", nil)
        micro_tasks ||= read_json_file(@test_artifacts_dir.join("micro_tasks.json"))

        plan_summary_path = @test_artifacts_dir.join("plan_summary.md")
        prd_path = @test_artifacts_dir.join("prd.md")
        cwa_summary_path = Rails.root.join("knowledge_base", "test_artifacts", @run_id.to_s, "cwa_summary.md")

        handoffs_dir = @test_artifacts_dir.join("handoffs")
        handoff_files = Dir.exist?(handoffs_dir) ? Dir.glob(handoffs_dir.join("*.json").to_s).sort : []
        handoffs = handoff_files.filter_map { |p| read_json_file(Pathname.new(p)) }

        # PRD-AH-012E: Collect LLM call evidence from SmartProxy
        local_llm_calls_dir = @test_artifacts_dir.join("llm_calls")
        global_llm_calls_dir = Rails.root.join("knowledge_base", "test_artifacts", "llm_calls", @run_id.to_s)

        # Best-effort wait for SmartProxy to finish writing async logs
        max_retries = 3
        llm_calls = []

        max_retries.times do |i|
          [ local_llm_calls_dir, global_llm_calls_dir ].each do |dir|
            if Dir.exist?(dir)
              calls = Dir.glob(dir.join("**", "*.json").to_s).map do |p|
                begin
                  payload = read_json_file(Pathname.new(p))
                  {
                    "agent" => File.basename(File.dirname(p)),
                    "file" => Pathname.new(p).relative_path_from(Rails.root).to_s,
                    "payload" => payload
                  }
                rescue StandardError
                  nil
                end
              end.compact
              llm_calls.concat(calls)
            end
          end

          llm_calls.uniq! { |c| c["file"] }
          break if llm_calls.any?
          sleep(1) if i < max_retries - 1
        end

        llm_calls = llm_calls.sort_by { |c| c.dig("payload", "ts").to_s }

        {
          "micro_tasks" => micro_tasks,
          "handoffs" => {
            "count" => handoffs.length,
            "files" => handoff_files.map { |p| Pathname.new(p).relative_path_from(Rails.root).to_s },
            "samples" => handoffs.first(3)
          },
          "llm_calls" => {
            "count" => llm_calls.length,
            "agents" => llm_calls.map { |c| c["agent"] }.uniq,
            "files" => llm_calls.map { |c| c["file"] }
          },
          "tests" => {
            "cwa_summary_present" => File.exist?(cwa_summary_path),
            "cwa_summary_path" => File.exist?(cwa_summary_path) ? cwa_summary_path.relative_path_from(Rails.root).to_s : nil,
            "cwa_summary_excerpt" => file_excerpt(cwa_summary_path, 25)
          }.compact,
          "files" => {
            "prd_present" => File.exist?(prd_path),
            "prd_path" => File.exist?(prd_path) ? prd_path.relative_path_from(Rails.root).to_s : nil,
            "plan_summary_present" => File.exist?(plan_summary_path),
            "plan_summary_path" => File.exist?(plan_summary_path) ? plan_summary_path.relative_path_from(Rails.root).to_s : nil
          }.compact,
          "artifact" => @artifact ? {
            "id" => @artifact.id,
            "name" => @artifact.name,
            "artifact_type" => @artifact.artifact_type,
            "phase" => @artifact.phase,
            "owner_persona" => @artifact.owner_persona
          } : nil
        }.compact
      end

      private

      def read_json_file(path)
        return nil unless path && File.exist?(path)
        JSON.parse(File.read(path, mode: "r:bom|utf-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: ""))
      rescue StandardError
        nil
      end

      def file_excerpt(path, max_lines)
        return nil unless path && File.exist?(path)
        File.read(path, mode: "r:bom|utf-8")
          .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          .lines
          .first(max_lines)
          .join
          .strip
      rescue StandardError
        nil
      end
    end
  end
end
