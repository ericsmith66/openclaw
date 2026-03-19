# frozen_string_literal: true

module Legion
  # Custom Liquid filters for prompt engineering
  #
  # Register these filters with Liquid::Template.register_filter(LiquidFilters)
  module LiquidFilters
    # Truncates a string to an approximate token count
    #
    # @param input [String] The string to truncate
    # @param max_tokens [Integer] Maximum number of tokens (words) to keep
    # @return [String] Truncated string with ellipsis if truncated
    def self.truncate_tokens(input, max_tokens)
      return if input.nil?
      return "" if max_tokens.nil?
      return input if max_tokens <= 0

      words = input.split(/\s+/)
      return input if words.length <= max_tokens

      truncated_words = words.first(max_tokens)
      "#{truncated_words.join(' ')}..."
    end

    # Indents each line in a multiline string
    #
    # @param input [String] The multiline string to indent
    # @param spaces [Integer] Number of spaces to indent (default: 4)
    # @return [String] Indented string
    def self.indent(input, spaces = 4)
      return if input.nil?

      return "" if input.empty?

      indent_string = " " * spaces
      input.lines.map { |line| line == "\n" ? line : "#{indent_string}#{line}" }.join
    end

    # Provides a default value for nil or empty strings
    #
    # @param input [Object] The value to check
    # @param default_value [Object] The value to return if input is nil or empty
    # @return [Object] The input value or the default
    def self.default(input, default_value = "")
      input.nil? || input == "" ? default_value : input
    end

    # Instance methods for Liquid filter registration
    def truncate_tokens(input, max_tokens)
      Legion::LiquidFilters.truncate_tokens(input, max_tokens)
    end

    def indent(input, spaces = 4)
      Legion::LiquidFilters.indent(input, spaces)
    end

    def default(input, default_value = "")
      Legion::LiquidFilters.default(input, default_value)
    end
  end
end
