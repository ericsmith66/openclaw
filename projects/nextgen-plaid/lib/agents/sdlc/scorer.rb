# frozen_string_literal: true

module Agents
  module Sdlc
    class Scorer
      def initialize(evidence, validation, error_class:, error_message:, workflow_error_class:, workflow_error:)
        @evidence = evidence
        @validation = validation
        @error_class = error_class
        @error_message = error_message
        @workflow_error_class = workflow_error_class
        @workflow_error = workflow_error
      end

      def call
        breakdown = {}
        score = 0

        micro_tasks_ok = @validation.dig("micro_tasks", "valid")
        breakdown["micro_tasks_valid"] = micro_tasks_ok ? 2 : 0
        score += breakdown["micro_tasks_valid"]

        prd_present = @evidence.dig("files", "prd_present")
        breakdown["prd_present"] = prd_present ? 1 : 0
        score += breakdown["prd_present"]

        handoffs_count = @evidence.dig("handoffs", "count").to_i
        breakdown["handoffs_present"] = handoffs_count > 0 ? 1 : 0
        score += breakdown["handoffs_present"]

        impl_notes_present = @evidence.dig("artifact").present? && Artifact.find_by(id: @evidence.dig("artifact", "id"))&.payload&.fetch("implementation_notes", "")
        breakdown["implementation_notes_present"] = impl_notes_present.to_s.strip.present? ? 2 : 0
        score += breakdown["implementation_notes_present"]

        tests_green = cwa_summary_indicates_green?(@evidence.dig("tests", "cwa_summary_excerpt").to_s)
        breakdown["tests_green"] = tests_green ? 3 : 0
        score += breakdown["tests_green"]

        has_errors = [ @error_class, @error_message, @workflow_error_class, @workflow_error ].any? { |v| v.to_s.strip.present? }
        breakdown["no_errors"] = has_errors ? 0 : 1
        score += breakdown["no_errors"]

        score = [ [ score, 0 ].max, 10 ].min
        pass = score >= 7

        llm_calls_ok = @evidence.dig("llm_calls", "count").to_i > 0
        breakdown["llm_calls_captured"] = llm_calls_ok ? 1 : 0

        {
          "score" => score,
          "pass" => pass,
          "rubric" => breakdown,
          "notes" => suggestions_from_breakdown(breakdown, @validation)
        }
      rescue StandardError => e
        {
          "score" => 0,
          "pass" => false,
          "rubric" => {},
          "notes" => [ "scoring_failed: #{e.class}: #{e.message}" ]
        }
      end

      private

      def suggestions_from_breakdown(breakdown, validation)
        notes = []
        notes << "micro_tasks invalid: #{validation.dig('micro_tasks', 'errors').join(', ')}" if breakdown["micro_tasks_valid"].to_i == 0
        notes << "missing prd.md artifact" if breakdown["prd_present"].to_i == 0
        notes << "no handoffs captured" if breakdown["handoffs_present"].to_i == 0
        notes << "implementation_notes missing" if breakdown["implementation_notes_present"].to_i == 0
        notes << "tests did not appear green" if breakdown["tests_green"].to_i == 0
        notes << "errors present in logs" if breakdown["no_errors"].to_i == 0
        notes << "no LLM calls captured by SmartProxy" if breakdown["llm_calls_captured"].to_i == 0
        notes
      end

      def cwa_summary_indicates_green?(txt)
        t = txt.to_s.downcase
        return true if t.include?("0 failures")
        return true if t.include?("examples, 0 failures")
        return true if t.include?("green") && !t.include?("not green")
        false
      end
    end
  end
end
