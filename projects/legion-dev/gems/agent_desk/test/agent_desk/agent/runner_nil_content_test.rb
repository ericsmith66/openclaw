# frozen_string_literal: true

require "test_helper"

module AgentDesk
  module Agent
    class RunnerNilContentTest < Minitest::Test
      # Bug fix verification: Runner must handle nil content when LLM returns
      # tool_calls without text content (common in newer Claude models).
      #
      # Before fix: assistant message with content: nil serialized to
      # {"role": "assistant", "content": null, "tool_calls": [...]}, which
      # Anthropic's newer models reject with 400.
      #
      # After fix: content key is omitted when nil.

      def setup
        @model_manager = MockModelManager.new
        @runner = Runner.new(model_manager: @model_manager)
      end

      def test_tool_call_response_with_nil_content
        # Model returns tool_calls with nil content (typical for Claude opus-4-6,
        # sonnet-4-6, haiku-4-5)
        tool_call = {
          id: "call_abc123",
          type: "function",
          function: { name: "test---test_tool", arguments: {} }
        }

        @model_manager.next_response = {
          role: "assistant",
          content: nil,  # ← Newer Claude models return nil here
          tool_calls: [ tool_call ]
        }

        # Setup a mock tool
        tool = Tools::BaseTool.new(
          name: "test_tool",
          group_name: "test",
          description: "Test tool",
          input_schema: {},
          &proc { "tool result" }
        )
        tool_set = Tools::ToolSet.new
        tool_set.add(tool)

        conversation = @runner.run(
          prompt: "Use test tool",
          project_dir: Dir.pwd,
          tool_set: tool_set,
          max_iterations: 2
        )

        # Find the assistant message with tool_calls
        assistant_msg = conversation.find do |m|
          m[:role] == "assistant" && m[:tool_calls]
        end

        assert assistant_msg, "Should have assistant message with tool_calls"

        # KEY ASSERTION: content key should not be present if value was nil
        # (not content: nil, which serializes to "content": null and breaks newer Claude)
        if assistant_msg[:content].nil?
          refute assistant_msg.key?(:content),
                 "Assistant message should not have :content key when content is nil " \
                 "(would serialize to 'content': null and fail with newer Claude models)"
        end

        # Tool should have been executed
        tool_msg = conversation.find { |m| m[:role] == "tool" }
        assert tool_msg, "Tool should have been called"
        assert_equal "tool result", tool_msg[:content]
      end

      def test_tool_call_response_with_text_content
        # Model returns tool_calls WITH text content (some models do this)
        tool_call = {
          id: "call_abc124",
          type: "function",
          function: { name: "test---test_tool", arguments: {} }
        }

        @model_manager.next_response = {
          role: "assistant",
          content: "I'll use the test tool for you.",  # ← Some models include text
          tool_calls: [ tool_call ]
        }

        tool = Tools::BaseTool.new(
          name: "test_tool",
          group_name: "test",
          description: "Test tool",
          input_schema: {},
          &proc { "tool result" }
        )
        tool_set = Tools::ToolSet.new
        tool_set.add(tool)

        conversation = @runner.run(
          prompt: "Use test tool",
          project_dir: Dir.pwd,
          tool_set: tool_set,
          max_iterations: 2
        )

        assistant_msg = conversation.find do |m|
          m[:role] == "assistant" && m[:tool_calls]
        end

        assert assistant_msg, "Should have assistant message with tool_calls"

        # When content is present, it should be included
        assert_equal "I'll use the test tool for you.", assistant_msg[:content]
      end

      # Mock model manager that can return predefined responses
      class MockModelManager
        attr_accessor :next_response, :call_count

        def initialize
          @call_count = 0
          @next_response = nil
        end

        def chat(messages:, tools: nil, &block)
          @call_count += 1

          if @call_count == 1 && @next_response
            # First call: return the tool call response
            @next_response
          else
            # Subsequent calls: return final text response
            { role: "assistant", content: "Done." }
          end
        end
      end
    end
  end
end
