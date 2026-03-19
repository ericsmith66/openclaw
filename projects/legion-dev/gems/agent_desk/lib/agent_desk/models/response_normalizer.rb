# frozen_string_literal: true

require "json"

module AgentDesk
  module Models
    # Normalizes OpenAI-compatible API responses into a consistent hash.
    #
    # Handles missing fields gracefully: nil tool_calls become nil,
    # missing usage defaults to zero tokens, malformed tool arguments
    # fall back to an empty hash.
    module ResponseNormalizer
      # Normalizes a full (non-streaming) OpenAI chat completion response.
      #
      # @param openai_response [Hash] raw parsed JSON response
      # @return [Hash] normalized hash with :role, :content, :tool_calls, :usage keys
      def self.normalize(openai_response)
        choice = openai_response.dig("choices", 0) || {}
        message = choice["message"] || {}
        result = {
          role: message["role"],
          content: message["content"],
          tool_calls: normalize_tool_calls(message["tool_calls"]),
          usage: normalize_usage(openai_response["usage"])
        }
        # Preserve reasoning_content for models that require it (e.g., deepseek-reasoner).
        # DeepSeek's API requires this field in assistant messages during tool call loops.
        result[:reasoning_content] = message["reasoning_content"] if message.key?("reasoning_content")
        result
      end

      # Normalizes tool_calls from OpenAI format, parsing JSON argument strings.
      #
      # @param tool_calls [Array<Hash>, nil] raw tool_calls array
      # @return [Array<Hash>, nil] normalized tool_calls or nil
      def self.normalize_tool_calls(tool_calls)
        return nil if tool_calls.nil? || tool_calls.empty?
        tool_calls.map do |tc|
          {
            id: tc["id"],
            type: tc["type"] || "function",  # OpenAI spec requires type field
            function: {
              name: tc.dig("function", "name"),
              arguments: parse_arguments(tc.dig("function", "arguments"))
            }
          }
        end
      end

      # Parses a JSON string into a Hash, falling back to empty hash on error.
      #
      # @param arguments_string [String, nil] JSON-encoded arguments
      # @return [Hash] parsed arguments or empty hash
      def self.parse_arguments(arguments_input)
        return {} if arguments_input.nil?
        # Some providers (e.g. xAI/Grok) return arguments as a Hash directly,
        # while OpenAI returns a JSON string.
        return arguments_input if arguments_input.is_a?(Hash)
        return {} if arguments_input.empty?

        JSON.parse(arguments_input)
      rescue JSON::ParserError
        {}
      end

      # Normalizes usage data, defaulting missing fields to zero.
      #
      # @param usage [Hash, nil] raw usage data
      # @return [Hash] usage with :prompt_tokens, :completion_tokens, :total_tokens
      def self.normalize_usage(usage)
        return { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 } unless usage
        {
          prompt_tokens: usage["prompt_tokens"] || 0,
          completion_tokens: usage["completion_tokens"] || 0,
          total_tokens: usage["total_tokens"] || 0
        }
      end
    end
  end
end
