# frozen_string_literal: true

require "json"

module Agents
  class SdlcStageContracts
    class ContractError < StandardError
      attr_reader :code, :details

      def initialize(code, message, details: {})
        super(message)
        @code = code
        @details = details
      end
    end

    INTENT_MAX_BYTES = 8_000
    PLAN_MAX_BYTES = 30_000

    def self.parse_json!(raw, code:)
      str = raw.to_s
      raise ContractError.new(code, "empty_json", details: { raw: str }) if str.strip.empty?

      JSON.parse(str)
    rescue JSON::ParserError => e
      raise ContractError.new(code, "invalid_json: #{e.message}", details: { raw: str })
    end

    # Intent Summary contract (PRD-AH-013G)
    # Required keys: business_requirement, user_interaction, change_impact
    def self.validate_intent_summary!(intent)
      raw = intent.is_a?(String) ? intent : JSON.generate(intent)
      raise ContractError.new("contract_failure_intent_summary", "intent_summary_too_large", details: { bytes: raw.bytesize }) if raw.bytesize > INTENT_MAX_BYTES

      obj = intent.is_a?(String) ? parse_json!(intent, code: "contract_failure_intent_summary") : intent
      unless obj.is_a?(Hash)
        raise ContractError.new("contract_failure_intent_summary", "intent_summary_not_object", details: { klass: obj.class.name })
      end

      required = %w[business_requirement user_interaction change_impact]
      missing = required.reject { |k| obj[k].to_s.strip.present? }
      raise ContractError.new("contract_failure_intent_summary", "intent_summary_missing_keys: #{missing.join(',')}", details: { missing: missing }) if missing.any?

      obj
    end

    # Plan JSON contract (PRD-AH-013G)
    # Required keys: tasks (array, non-empty), test_command (string, non-empty)
    def self.validate_plan_json!(plan)
      raw = plan.is_a?(String) ? plan : JSON.generate(plan)
      raise ContractError.new("contract_failure_plan_json", "plan_json_too_large", details: { bytes: raw.bytesize }) if raw.bytesize > PLAN_MAX_BYTES

      obj = plan.is_a?(String) ? parse_json!(plan, code: "contract_failure_plan_json") : plan
      unless obj.is_a?(Hash)
        raise ContractError.new("contract_failure_plan_json", "plan_json_not_object", details: { klass: obj.class.name })
      end

      tasks = obj["tasks"]
      test_cmd = obj["test_command"].to_s

      unless tasks.is_a?(Array) && tasks.any?
        raise ContractError.new("contract_failure_plan_json", "plan_json_tasks_missing", details: { tasks_class: tasks.class.name })
      end

      raise ContractError.new("contract_failure_plan_json", "plan_json_test_command_missing") if test_cmd.strip.empty?

      obj
    end
  end
end
