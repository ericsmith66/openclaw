require "test_helper"

class AgentHub::SmartProxyClientTest < ActiveSupport::TestCase
  class CapturingBroadcastServer
    attr_reader :broadcasts

    def initialize
      @broadcasts = []
    end

    def broadcast(target, payload)
      @broadcasts << [ target, payload ]
    end
  end

  setup do
    @client = AgentHub::SmartProxyClient.new(model: "test-model", stream: false)
    @messages = [ { role: "user", content: "hello" } ]
    @base_url = "http://localhost:11434/v1"
    @client.instance_variable_set(:@base_url, @base_url)
    @client.instance_variable_set(:@api_key, "ollama")
  end

  test "chat non-stream returns parsed JSON response" do
    VCR.turned_off do
      stub_request(:post, "#{@base_url}/chat/completions")
        .with(
          body: { model: "test-model", messages: @messages, stream: false }.to_json,
          headers: { "Authorization" => "Bearer ollama", "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: { choices: [ { message: { content: "hi" } } ] }.to_json)

      result = @client.chat(@messages)
      assert_equal "hi", result.dig("choices", 0, "message", "content")
    end
  end

  test "chat stream broadcasts tokens" do
    VCR.turned_off do
      @client = AgentHub::SmartProxyClient.new(model: "test-model", stream: true)
      @client.instance_variable_set(:@base_url, @base_url)
      @client.instance_variable_set(:@api_key, "ollama")

      stream_content = [
        "data: " + { choices: [ { delta: { content: "He" } } ] }.to_json,
        "data: " + { choices: [ { delta: { content: "llo" } } ] }.to_json,
        "data: [DONE]"
      ].join("\n\n")

      stub_request(:post, "#{@base_url}/chat/completions")
        .to_return(status: 200, body: stream_content)

      server = CapturingBroadcastServer.new

      ActionCable.stub :server, server do
        result = @client.chat(@messages, stream_to: "123")
        assert_equal "Hello", result.dig("choices", 0, "message", "content")
      end

      token_payloads = server.broadcasts
        .select { |(target, payload)| target == "agent_hub_channel_123" && payload[:type] == "token" }
        .map { |(_target, payload)| payload }

      assert_equal [
        { type: "token", token: "He", message_id: nil },
        { type: "token", token: "llo", message_id: nil }
      ], token_payloads
    end
  end

  test "chat stream with no assistant content returns structured error" do
    VCR.turned_off do
      @client = AgentHub::SmartProxyClient.new(model: "test-model", stream: true)
      @client.instance_variable_set(:@base_url, @base_url)
      @client.instance_variable_set(:@api_key, "ollama")

      stream_content = [
        "data: " + { choices: [ { delta: { tool_calls: [ { id: "call_1", type: "function", function: { name: "web_search", arguments: "{\"q\":\"foo\"}" } } ] } } ] }.to_json,
        "data: [DONE]"
      ].join("\n\n")

      stub_request(:post, "#{@base_url}/chat/completions")
        .to_return(status: 200, body: stream_content)

      server = CapturingBroadcastServer.new
      ActionCable.stub :server, server do
        result = @client.chat(@messages, stream_to: "123")
        assert_equal true, result.key?("error")
        assert_match(/No assistant content received/, result["error"])
      end

      keepalive_payloads = server.broadcasts
        .select { |(target, payload)| target == "agent_hub_channel_123" && payload[:type] == "keepalive" }
        .map { |(_target, payload)| payload }

      assert_operator keepalive_payloads.length, :>=, 1
    end
  end

  test "handles timeout" do
    VCR.turned_off do
      stub_request(:post, "#{@base_url}/chat/completions").to_raise(Faraday::TimeoutError)

      result = @client.chat(@messages)
      assert_match(/Timeout/, result["error"])
    end
  end

  test "chat stream handles 500 error from proxy gracefully" do
    VCR.turned_off do
      @client = AgentHub::SmartProxyClient.new(model: "test-model", stream: true)
      @client.instance_variable_set(:@base_url, @base_url)
      @client.instance_variable_set(:@api_key, "ollama")

      error_body = { error: "Net::ReadTimeout with #<TCPSocket:(closed)>" }.to_json
      stub_request(:post, "#{@base_url}/chat/completions")
        .to_return(status: 500, body: error_body)

      result = @client.chat(@messages, stream_to: "123")
      assert_equal "Net::ReadTimeout with #<TCPSocket:(closed)>", result["error"]
    end
  end
end
