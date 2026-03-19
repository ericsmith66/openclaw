# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "sdlc/evidence_gatherer"
require_relative "sdlc/validator"
require_relative "sdlc/scorer"
require_relative "sdlc/report_generator"

module Agents
  # PRD-AH-012E: post-run validation + scoring + persistence.
  #
  # This is intentionally tolerant: it should never raise during CLI teardown.
  class SdlcValidationScoring
    class << self
      def run(
        run_id:,
        log_dir:,
        run_dir_name:,
        started_at:,
        finished_at:,
        duration_ms:,
        opts:,
        summary_artifact_id:,
        summary_run_id:,
        output_files:,
        error_class:,
        error_message:,
        workflow_error_class:,
        workflow_error:,
        workflow_event_types:
      )
        artifact = safe_find_artifact(summary_artifact_id)

        test_artifacts_dir = Pathname.new(log_dir).join("test_artifacts")
        kb_artifacts_dir = Rails.root.join("knowledge_base", "test_artifacts", run_id.to_s)
        FileUtils.mkdir_p(kb_artifacts_dir)

        evidence = Sdlc::EvidenceGatherer.new(
          run_id: run_id,
          artifact: artifact,
          test_artifacts_dir: test_artifacts_dir
        ).call

        validation = Sdlc::Validator.new(evidence).call
        scoring = Sdlc::Scorer.new(
          evidence,
          validation,
          error_class: error_class,
          error_message: error_message,
          workflow_error_class: workflow_error_class,
          workflow_error: workflow_error
        ).call

        attempt = {
          "timestamp" => Time.current.iso8601,
          "score" => scoring.fetch("score"),
          "pass" => scoring.fetch("pass"),
          "rubric" => scoring.fetch("rubric"),
          "model" => scoring["model"],
          "notes" => scoring["notes"]
        }.compact

        append_score_attempt!(artifact, attempt)

        finalize_phase!(artifact, scoring)

        validation_payload = {
          "run_id" => run_id,
          "generated_at" => Time.current.iso8601,
          "validation" => validation,
          "scoring" => scoring,
          "evidence" => evidence.slice("micro_tasks", "handoffs", "tests")
        }

        # Machine-readable artifact
        File.write(kb_artifacts_dir.join("validation.json"), JSON.pretty_generate(validation_payload) + "\n")

        reporter = Sdlc::ReportGenerator.new(
          run_id: run_id,
          run_dir_name: run_dir_name,
          started_at: started_at,
          finished_at: finished_at,
          duration_ms: duration_ms,
          opts: opts,
          summary_artifact_id: summary_artifact_id,
          summary_run_id: summary_run_id,
          output_files: output_files,
          evidence: evidence,
          validation: validation,
          scoring: scoring,
          workflow_event_types: workflow_event_types,
          error_class: error_class,
          error_message: error_message,
          workflow_error_class: workflow_error_class,
          workflow_error: workflow_error
        )

        # Human-readable report (canonical location per PRD-AH-012E)
        report_md = reporter.build_run_summary_md

        File.write(kb_artifacts_dir.join("run_summary.md"), report_md)

        # Backwards-compatible location used by existing tests and historical runs
        File.write(Pathname.new(log_dir).join("run_summary.md"), report_md)

        # Summary log (simple, greppable)
        summary_log_path = Pathname.new(log_dir).join("summary.log")
        File.write(summary_log_path, reporter.build_summary_log)

        {
          validation_path: kb_artifacts_dir.join("validation.json"),
          run_summary_path: kb_artifacts_dir.join("run_summary.md"),
          summary_log_path: summary_log_path
        }
      rescue StandardError => e
        # Never fail the CLI teardown. Best-effort only.
        {
          error: {
            "class" => e.class.to_s,
            "message" => e.message
          }
        }
      end

      private

      def finalize_phase!(artifact, scoring)
        return if artifact.nil?
        return unless scoring["pass"]
        return if artifact.phase.to_s == "complete"

        max_hops = Artifact::PHASES.length + 2
        hops = 0
        while artifact.phase.to_s != "complete" && hops < max_hops
          prior = artifact.phase
          artifact.transition_to("approve", artifact.owner_persona)
          artifact.reload
          break if artifact.phase == prior
          hops += 1
        end
      rescue StandardError
        # ignore
      end

      def safe_find_artifact(id)
        return nil if id.blank?
        Artifact.find_by(id: id)
      rescue StandardError
        nil
      end

      def append_score_attempt!(artifact, attempt)
        return if artifact.nil?
        artifact.payload ||= {}
        artifact.payload["score_attempts"] ||= []
        artifact.payload["score_attempts"] << attempt
        artifact.save!
      rescue StandardError
        # ignore
      end
    end
  end
end
