# frozen_string_literal: true

module Agents
  module Sdlc
    class Validator
      def initialize(evidence)
        @evidence = evidence
      end

      def call
        micro_tasks = @evidence["micro_tasks"]
        micro_tasks_errors = []

        if !micro_tasks.is_a?(Array) || micro_tasks.empty?
          micro_tasks_errors << "micro_tasks_missing"
        else
          micro_tasks.each_with_index do |t, idx|
            unless t.is_a?(Hash)
              micro_tasks_errors << "micro_tasks[#{idx}]_not_object"
              next
            end

            id = t["id"] || t[:id]
            title = t["title"] || t[:title]
            estimate = t["estimate"] || t[:estimate]

            micro_tasks_errors << "micro_tasks[#{idx}].id_missing" if id.to_s.strip.empty?
            micro_tasks_errors << "micro_tasks[#{idx}].title_missing" if title.to_s.strip.empty?
            micro_tasks_errors << "micro_tasks[#{idx}].estimate_missing" if estimate.to_s.strip.empty?
          end
        end

        handoffs = @evidence.dig("handoffs", "samples")
        handoff_errors = []
        if handoffs.is_a?(Array)
          handoffs.each_with_index do |h, idx|
            next unless h.is_a?(Hash)
            handoff_errors << "handoffs[#{idx}].type_invalid" if h["type"].to_s != "agent_handoff"
            handoff_errors << "handoffs[#{idx}].from_missing" if h["from"].to_s.strip.empty?
            handoff_errors << "handoffs[#{idx}].to_missing" if h["to"].to_s.strip.empty?
          end
        end

        {
          "micro_tasks" => { "valid" => micro_tasks_errors.empty?, "errors" => micro_tasks_errors },
          "handoffs" => { "valid" => handoff_errors.empty?, "errors" => handoff_errors }
        }
      end
    end
  end
end
