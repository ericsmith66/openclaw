# frozen_string_literal: true

require "erb"

module Agents
  class SdlcSapPromptBuilder
    DEFAULT_TEMPLATE = <<~ERB
      <%= input %>

      ---
      [RAG]
      <%= rag_content %>
    ERB

    def self.build(input:, rag_content:, prompt_path: nil, prd_only: false)
      template_source = if prompt_path.to_s.strip.present?
        File.read(prompt_path)
      else
        DEFAULT_TEMPLATE
      end

      erb = ERB.new(template_source)
      erb.result_with_hash(input: input.to_s, rag_content: rag_content.to_s, prd_only: !!prd_only)
    end
  end
end
