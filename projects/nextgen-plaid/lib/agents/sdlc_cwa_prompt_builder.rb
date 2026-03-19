# frozen_string_literal: true

require "erb"

module Agents
  class SdlcCwaPromptBuilder
    DEFAULT_PROMPT_PATH = Rails.root.join("knowledge_base", "prompts", "cwa_execution.md.erb").to_s

    def self.build(input:, artifact_id:, prd_content:, micro_tasks_json:, prompt_path: nil)
      path = prompt_path.to_s.strip
      path = DEFAULT_PROMPT_PATH if path.empty?

      template = File.read(path)
      erb = ERB.new(template)

      erb.result_with_hash(
        input: input.to_s,
        artifact_id: artifact_id,
        prd_content: prd_content.to_s,
        micro_tasks_json: micro_tasks_json.to_s
      )
    end
  end
end
