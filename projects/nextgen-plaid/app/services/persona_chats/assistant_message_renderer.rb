module PersonaChats
  class AssistantMessageRenderer
    class << self
      def call(content:, sources:, model:, provider_model: "")
        body_html = Ai::MarkdownRenderer.render(content.to_s)

        sources = Array(sources).map(&:to_s).reject(&:blank?).uniq
        meta_html = build_meta_html(model: model.to_s, provider_model: provider_model.to_s, sources: sources)

        # Wrap so the client can safely insert this into the chat bubble.
        "<div class=\"prose max-w-none\">#{body_html}</div>#{meta_html}"
      end

      private

      def build_meta_html(model:, provider_model:, sources:)
        meta_parts = []
        if model.present?
          meta = ERB::Util.html_escape(model)
          meta << " (#{ERB::Util.html_escape(provider_model)})" if provider_model.present? && provider_model != model
          meta_parts << "<div class=\"text-xs opacity-70 mt-2\">Model: <code>#{meta}</code></div>"
        end

        if sources.any?
          items = sources.first(8).map do |url|
            u = ERB::Util.html_escape(url)
            "<li><a class=\"link link-primary\" href=\"#{u}\" target=\"_blank\" rel=\"noopener noreferrer\">#{u}</a></li>"
          end.join
          sources_html = <<~HTML
            <details class="mt-2">
              <summary class="cursor-pointer text-xs opacity-70">Sources</summary>
              <ul class="text-xs opacity-80 list-disc ml-4 mt-1">#{items}</ul>
            </details>
          HTML
          meta_parts << sources_html
        end

        meta_parts.join
      end
    end
  end
end
