# frozen_string_literal: true

return unless ENV["AGENT_DESK_INTEGRATION"]

require "test_helper"

class ModelManagerIntegrationTest < Minitest::Test
  def setup
    skip "SmartProxy not running" unless smart_proxy_alive?
    @manager = AgentDesk::Models::ModelManager.new(
      provider: :smart_proxy,
      api_key: ENV.fetch("PROXY_AUTH_TOKEN", "test")
    )
  end

  def test_real_non_streaming_call
    response = @manager.chat(
      messages: [ { role: "user", content: "Say hello in one word" } ]
    )
    assert_equal "assistant", response[:role]
    refute_nil response[:content]
    assert response[:content].length.positive?
    assert_kind_of Hash, response[:usage]
  end

  def test_real_streaming_call
    chunks = []
    response = @manager.chat(
      messages: [ { role: "user", content: "Say hello in one word" } ]
    ) { |chunk| chunks << chunk }
    assert_equal "assistant", response[:role]
    refute_empty chunks
    assert chunks.all? { |c| c[:type] == "chunk" }
  end

  private

  def smart_proxy_alive?
    require "net/http"
    Net::HTTP.get_response(URI("http://localhost:4567/health"))
    true
  rescue StandardError
    false
  end
end
