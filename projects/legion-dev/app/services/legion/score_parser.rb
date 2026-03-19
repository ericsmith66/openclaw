# frozen_string_literal: true

module Legion
  class ScoreParser
    Result = Struct.new(:score, :message, :feedback, keyword_init: true)

    # Priority-ordered regex patterns for score extraction
    PATTERNS = {
      header_format: /##\s*Score\s*\n\s*(\d+)\/100/m,
      inline_format: /SCORE:\s*(\d+)/i,
      slash_format: /(\d+)\s*\/\s*100/
    }.freeze

    # Regex to extract content of a ## Feedback section
    FEEDBACK_PATTERN = /##\s*Feedback\s*\n(.*?)(?=\n##|\z)/m.freeze

    def self.call(text:)
      new(text: text).call
    end

    def initialize(text:)
      @text = text
    end

    def call
      # Try each pattern in priority order; first match wins
      score = extract_score
      score = 0 if score.nil?

      message = if score > 0
                  "Score extracted successfully"
      else
                  "Score parsing failed — manual review required"
      end

      feedback = extract_feedback || message

      Result.new(score: score, message: message, feedback: feedback)
    end

    private

    def extract_score
      PATTERNS.each_value do |pattern|
        match = @text.match(pattern)
        return match[1].to_i if match
      end
      nil
    end

    def extract_feedback
      match = @text.match(FEEDBACK_PATTERN)
      match ? match[1].strip : nil
    end
  end
end
