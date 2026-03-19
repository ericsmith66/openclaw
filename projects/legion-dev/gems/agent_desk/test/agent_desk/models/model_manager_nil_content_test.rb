# frozen_string_literal: true

require "test_helper"

module AgentDesk
  module Models
    class ModelManagerNilContentTest < Minitest::Test
      # Bug fix verification: ModelManager must omit nil values from serialized
      # messages to avoid "key": null in JSON, which Anthropic's newer models
      # (opus-4-6, sonnet-4-6) reject with 400 errors.

      def test_normalize_message_omits_nil_content
        manager = ModelManager.new(
          provider: :smart_proxy,
          api_key: "test",
          model: "test-model"
        )

        # Message with nil content (typical for tool-use responses from newer Claude)
        input_msg = {
          role: "assistant",
          content: nil,
          tool_calls: [
            {
              id: "call_123",
              type: "function",
              function: { name: "test_tool", arguments: {} }
            }
          ]
        }

        normalized = manager.send(:normalize_message, input_msg)

        # Key assertion: content key should not be present in normalized output
        refute normalized.key?("content"),
               "Normalized message should not have 'content' key when input content is nil " \
               "(would serialize to 'content': null and fail with newer Claude models)"

        assert_equal "assistant", normalized["role"]
        assert normalized.key?("tool_calls")
      end

      def test_normalize_message_preserves_non_nil_content
        manager = ModelManager.new(
          provider: :smart_proxy,
          api_key: "test",
          model: "test-model"
        )

        # Message with actual content
        input_msg = {
          role: "assistant",
          content: "I'll help with that.",
          tool_calls: [
            {
              id: "call_124",
              type: "function",
              function: { name: "test_tool", arguments: {} }
            }
          ]
        }

        normalized = manager.send(:normalize_message, input_msg)

        # Content should be preserved when non-nil
        assert_equal "I'll help with that.", normalized["content"]
        assert_equal "assistant", normalized["role"]
        assert normalized.key?("tool_calls")
      end

      def test_normalize_message_omits_other_nil_fields
        manager = ModelManager.new(
          provider: :smart_proxy,
          api_key: "test",
          model: "test-model"
        )

        # Message with multiple nil fields
        input_msg = {
          role: "assistant",
          content: "Hello",
          name: nil,
          function_call: nil
        }

        normalized = manager.send(:normalize_message, input_msg)

        # Only non-nil fields should be present
        assert_equal "assistant", normalized["role"]
        assert_equal "Hello", normalized["content"]
        refute normalized.key?("name"), "Should omit nil 'name' field"
        refute normalized.key?("function_call"), "Should omit nil 'function_call' field"
      end

      def test_normalize_body_omits_nil_in_conversation
        manager = ModelManager.new(
          provider: :smart_proxy,
          api_key: "test",
          model: "test-model"
        )

        # Full request body with assistant message containing nil content
        body = {
          model: "test-model",
          messages: [
            { role: "user", content: "Use the tool" },
            {
              role: "assistant",
              content: nil,
              tool_calls: [
                {
                  id: "call_abc",
                  type: "function",
                  function: { name: "power---glob", arguments: { pattern: "*.rb" } }
                }
              ]
            },
            { role: "tool", tool_call_id: "call_abc", content: "file.rb" }
          ],
          tools: [
            {
              type: "function",
              function: {
                name: "power---glob",
                description: "Find files",
                parameters: {}
              }
            }
          ]
        }

        normalized = manager.send(:normalize_body, body)

        # Find the assistant message in normalized output
        assistant_msg = normalized[:messages].find { |m| m["role"] == "assistant" }

        refute_nil assistant_msg, "Should have assistant message"
        refute assistant_msg.key?("content"),
               "Normalized assistant message should not have 'content' key when nil"
        assert assistant_msg.key?("tool_calls")
      end
    end
  end
end
