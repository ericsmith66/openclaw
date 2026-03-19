# frozen_string_literal: true

module Ai
  class MarkdownRenderer
    def self.render(text)
      return "" if text.blank?

      # Using commonmarker 2.x API
      # Enable tables and other common extensions
      # Ensure UTF-8 encoding as required by Commonmarker 2.x
      utf8_text = text.to_s.force_encoding("UTF-8")
      html = Commonmarker.to_html(utf8_text, options: {
        render: { hardbreaks: true, unsafe: false }
      })

      # Sanitize the output for safety
      SanitizedHtml.fragment(html)
    end

    private

    # Helper to handle sanitization and html_safe marking
    class SanitizedHtml
      def self.fragment(html)
        Sanitize.fragment(html, Sanitize::Config::RELAXED).html_safe
      end
    end
  end
end
