# frozen_string_literal: true

require "json"

module Agents
  class SdlcRunSummary
    REQUIRED_CLASSIFICATIONS = %w[
      provider_server_error
      provider_timeout
      provider_bad_request_request_formation
      provider_bad_request_other
      contract_failure_prd
      contract_failure_intent_summary
      contract_failure_plan_json
      contract_failure_micro_tasks
      tool_failure_shell_parse
      tool_failure_allowlist
      guardrail_abort
      db_locking_stale_object
      tests_failed
    ].freeze

    def self.classify(error_class:, error_message:, workflow_error_class:, workflow_error:)
      # Prefer workflow-level errors when present.
      klass = (workflow_error_class.presence || error_class.presence).to_s
      msg = (workflow_error.presence || error_message.presence).to_s

      # Provider/infra sometimes gets wrapped in a generic RuntimeError; detect by message too.
      return "provider_server_error" if msg.include?("RubyLLM::ServerError")
      return "provider_timeout" if msg.match?(/Faraday::TimeoutError|Net::ReadTimeout|Timeout::Error/i)

      # Provider/infra
      return "provider_server_error" if klass == "RubyLLM::ServerError"
      return "provider_timeout" if %w[Faraday::TimeoutError Net::ReadTimeout Timeout::Error].include?(klass)

      if klass == "RubyLLM::BadRequestError"
        # Default to "other" unless we have strong evidence it was our payload/request.
        return "provider_bad_request_request_formation" if msg.match?(/context|token|payload|too\s+large|max\s+tokens|request\s+too\s+large|invalid\s+schema/i)
        return "provider_bad_request_other"
      end

      # Contracts
      return "contract_failure_micro_tasks" if msg.include?("micro_tasks_missing")
      return "contract_failure_prd" if msg.match?(/prd/i) && msg.match?(/invalid|contract|schema/i)
      return "contract_failure_intent_summary" if msg.match?(/intent/i) && msg.match?(/contract|schema|invalid/i)
      return "contract_failure_plan_json" if msg.match?(/plan/i) && msg.match?(/contract|schema|invalid/i)

      # Tooling
      return "tool_failure_shell_parse" if msg.match?(/invalid_shell_command/i)
      return "tool_failure_allowlist" if msg.match?(/not_allowlisted|denylist/i)

      # Guardrails
      return "guardrail_abort" if klass == "AiWorkflowService::GuardrailError" || msg.match?(/max tool calls exceeded|sandbox_strict/i)

      # DB
      return "db_locking_stale_object" if klass == "ActiveRecord::StaleObjectError"

      # Tests
      return "tests_failed" if msg.match?(/tests_failed|test\s+fail/i)

      # Default: treat unknown as a pipeline fail; we keep taxonomy finite by mapping to the closest bucket.
      "provider_bad_request_other"
    end

    def self.stage_windows(records)
      by_stage = records.group_by { |r| r["stage"].to_s }
      by_stage.transform_values do |recs|
        times = recs.filter_map { |r| Time.iso8601(r["timestamp"]) rescue nil }
        next nil if times.empty?

        { "start" => times.min.iso8601, "end" => times.max.iso8601 }
      end.compact
    end

    def self.tool_metrics(workflow_events)
      tool_complete = workflow_events.select { |r| r["type"] == "tool_complete" }
      tool_calls_total = tool_complete.length
      tool_calls_by_tool = tool_complete.group_by { |r| r["tool"].to_s }.transform_values(&:length)

      max_bytes_by_tool = {}
      truncation_by_tool = {}
      any_truncation = false

      tool_complete.each do |evt|
        tool = evt["tool"].to_s
        raw = evt["result"]
        # Some events store a JSON string; others store an object.
        payload = if raw.is_a?(String)
          JSON.parse(raw) rescue nil
        elsif raw.is_a?(Hash)
          raw
        end

        next if payload.nil?

        stdout_bytes = payload["stdout_bytes"]
        stderr_bytes = payload["stderr_bytes"]
        stdout_truncated = payload["stdout_truncated"]
        stderr_truncated = payload["stderr_truncated"]

        # SafeShellTool/GitTool return nested result.
        if payload["result"].is_a?(Hash)
          stdout_bytes ||= payload["result"]["stdout_bytes"]
          stderr_bytes ||= payload["result"]["stderr_bytes"]
          stdout_truncated = payload["result"]["stdout_truncated"] if stdout_truncated.nil?
          stderr_truncated = payload["result"]["stderr_truncated"] if stderr_truncated.nil?
        end

        max_for_tool = max_bytes_by_tool[tool] || { "stdout" => 0, "stderr" => 0 }
        max_for_tool["stdout"] = [ max_for_tool["stdout"].to_i, stdout_bytes.to_i ].max if stdout_bytes
        max_for_tool["stderr"] = [ max_for_tool["stderr"].to_i, stderr_bytes.to_i ].max if stderr_bytes
        max_bytes_by_tool[tool] = max_for_tool

        trunc = truncation_by_tool[tool] || { "stdout" => false, "stderr" => false }
        trunc["stdout"] ||= stdout_truncated == true
        trunc["stderr"] ||= stderr_truncated == true
        truncation_by_tool[tool] = trunc
        any_truncation ||= trunc["stdout"] || trunc["stderr"]
      end

      {
        "tool_calls_total" => tool_calls_total,
        "tool_calls_by_tool" => tool_calls_by_tool,
        "max_output_bytes_by_tool" => max_bytes_by_tool,
        "truncation_by_tool" => truncation_by_tool,
        "any_truncation" => any_truncation
      }
    end
  end
end
