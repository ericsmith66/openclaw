require "spec_helper"
require_relative "../../lib/claude_client"

RSpec.describe ClaudeClient do
  describe "#map_to_claude" do
    it "supports symbol-keyed messages and hoists system to top-level" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929-with-live-search",
        messages: [
          { role: "system", content: "You are a helpful assistant." },
          { role: "user", content: "Hello" }
        ],
        stream: false
      }

      mapped = client.send(:map_to_claude, payload)
      expect(mapped[:system]).to eq("You are a helpful assistant.")
      expect(mapped[:messages]).to eq([ { role: "user", content: [ { type: "text", text: "Hello" } ] } ])
    end

    it "drops unsupported roles from messages" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929-with-live-search",
        messages: [
          { role: "tool", content: "{" },
          { role: "assistant", content: "Ok" },
          { role: "user", content: "Go" }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      roles = mapped[:messages].map { |m| m[:role] }
      expect(roles).to contain_exactly("assistant", "user")
    end

    it "wraps string content into Claude content blocks" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929-with-live-search",
        messages: [
          { role: "user", content: "Hi" },
          { role: "assistant", content: "Hello" }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      expect(mapped[:messages]).to eq([
        { role: "user", content: [ { type: "text", text: "Hi" } ] },
        { role: "assistant", content: [ { type: "text", text: "Hello" } ] }
      ])
    end
  end
end
