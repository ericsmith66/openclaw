# frozen_string_literal: true

module AgentDesk
  module Test
    # A test double for AgentDesk::Models::ModelManager.
    #
    # Returns pre-configured responses without making real HTTP calls.
    # Response shape mirrors the real ModelManager output:
    # { role:, content:, tool_calls:, usage: }
    #
    # @example Text response
    #   mock = MockModelManager.new
    #   mock.chat(messages: []) # => { role: "assistant", content: "Mock response", ... }
    #
    # @example Custom responses
    #   mock = MockModelManager.new(responses: [
    #     { role: "assistant", content: nil,
    #       tool_calls: [{ id: "1", function: { name: "search", arguments: {} } }],
    #       usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } }
    #   ])
    class MockModelManager
      # @return [Array<Hash>] all recorded #chat invocations
      attr_reader :calls

      # @param responses [Array<Hash>] pre-configured responses to return in order.
      #   Each response must be a normalized hash with :role, :content, :tool_calls, :usage keys.
      #   When the queue is exhausted, #default_text_response is returned.
      def initialize(responses: [])
        @responses = responses.dup
        @calls = []
      end

      # Simulates a chat completion call.
      #
      # Records the call arguments in #calls and returns the next pre-configured response.
      # When a block is given and the response has content, yields streaming chunks.
      #
      # @param messages [Array<Hash>] conversation messages
      # @param tools [Array<Hash>, nil] tool definitions
      # @param temperature [Float, nil] sampling temperature
      # @param max_tokens [Integer, nil] maximum tokens
      # @yield [chunk] called for each simulated streaming chunk when block is given
      # @yieldparam chunk [Hash] with :type ("chunk") and :content keys
      # @return [Hash] normalized response with :role, :content, :tool_calls, :usage keys
      def chat(messages:, tools: nil, temperature: nil, max_tokens: nil, &block)
        @calls << { messages:, tools:, temperature:, max_tokens: }
        response = @responses.shift || default_text_response

        # Simulate streaming if block given and response has textual content
        if block && response[:content]
          response[:content].chars.each_slice(10) do |chunk|
            block.call({ type: "chunk", content: chunk.join })
          end
        end

        response
      end

      private

      # @return [Hash] default normalized text response
      def default_text_response
        {
          role: "assistant",
          content: "Mock response",
          tool_calls: nil,
          usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }
        }
      end
    end
  end
end
