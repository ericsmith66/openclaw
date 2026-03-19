# frozen_string_literal: true

require "json"

module AiWorkflow
  class ContextManager
    def self.load_existing(correlation_id)
      run_path = Rails.root.join("agent_logs", "ai_workflow", correlation_id.to_s, "run.json")
      return nil unless File.exist?(run_path)

      payload = JSON.parse(File.read(run_path))
      ctx = payload["context"]
      return nil unless ctx.is_a?(Hash)

      # Defensive: persisted runs may contain malformed conversation entries (e.g. missing `role`),
      # which can crash `Agents::Runner.restore_conversation_history` on subsequent retries.
      if ctx["conversation_history"].is_a?(Array)
        ctx["conversation_history"] = ctx["conversation_history"]
          .select do |entry|
            next false unless entry.is_a?(Hash)

            role = entry["role"]
            role = entry[:role] if role.nil? && entry.key?(:role)
            role.to_s.strip.present?
          end
          .map do |entry|
            # `ai-agents` expects symbol-keyed message hashes (e.g. `msg[:role]`).
            # Persisted JSON uses string keys, so normalize to symbols.
            normalized = entry.respond_to?(:symbolize_keys) ? entry.symbolize_keys : entry
            role = normalized[:role] || normalized["role"]
            normalized[:role] = role.to_s if role.present?
            normalized
          end
      end

      ctx.symbolize_keys
    rescue StandardError
      nil
    end

    def self.build_initial(correlation_id)
      {
        correlation_id: correlation_id,
        workflow_state: "in_progress",
        ball_with: "SAP",
        turns_count: 0,
        feedback_history: [],
        artifacts: [],
        micro_tasks: [],
        state: {}
      }
    end

    def self.normalize!(result)
      current_agent = result.context[:current_agent] || result.context["current_agent"]
      result.context[:ball_with] = current_agent

      turn_count = result.context[:turn_count] || result.context["turn_count"]
      result.context[:turns_count] = turn_count
      result
    end

    def self.prepare_rag_context
      common_context = "\n\n--- VISION ---\n#{File.read(Rails.root.join('knowledge_base/static_docs/MCP.md'))}"
      common_context += "\n\n--- PROJECT STRUCTURE ---\n#{`find . -maxdepth 2 -not -path '*/.*'`.strip}"
      common_context
    end
  end
end
