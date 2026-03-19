# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"

# Live smoke tests for Claude integration in SmartProxy.
#
# Run:
#   SMART_PROXY_LIVE_TEST=true CLAUDE_API_KEY=xxx bin/rails test test/smoke/claude_live_test.rb
#
class ClaudeLiveTest < ActiveSupport::TestCase
  def setup
    super
    skip "Set SMART_PROXY_LIVE_TEST=true to enable" unless ENV["SMART_PROXY_LIVE_TEST"] == "true"
    # We don't skip if CLAUDE_API_KEY is missing here, because the server might have it in its .env

    # Forcefully disable VCR and WebMock for live tests
    if defined?(VCR)
      VCR.turn_off!(ignore_cassettes: true)
    end

    if defined?(WebMock)
      WebMock.allow_net_connect!
    end

    @port = ENV.fetch("SMART_PROXY_PORT", "4567")
    @base = URI("http://localhost:#{@port}")
    @token = ENV["PROXY_AUTH_TOKEN"].to_s
    @model = ENV.fetch("CLAUDE_TEST_MODEL", "claude-3-5-sonnet-20241022")
  end

  def teardown
    if defined?(WebMock)
      WebMock.disable_net_connect!(allow_localhost: true)
    end
    if defined?(VCR)
      VCR.turn_on!
    end
    super
  end

  def test_claude_chat_completions
    res = http_post_json("/v1/chat/completions", {
      model: @model,
      messages: [
        { role: "user", content: "Say OK." }
      ],
      stream: false,
      temperature: 0.0
    })

    assert_equal 200, res.code.to_i, "Claude returned HTTP #{res.code}: #{res.body}"
    body = JSON.parse(res.body)
    assert_equal "chat.completion", body["object"]
    content = body.dig("choices", 0, "message", "content")
    assert_match(/OK/i, content)
  end

  def test_claude_live_search_orchestration
    # Using the -with-live-search suffix to trigger smart_proxy's tool_loop
    res = http_post_json("/v1/chat/completions", {
      model: "#{@model}-with-live-search",
      messages: [
        { role: "user", content: "What is the current stock price of Apple (AAPL)? Cite your source." }
      ],
      stream: false,
      temperature: 0.0
    })

    assert_equal 200, res.code.to_i, "Claude live-search returned HTTP #{res.code}: #{res.body}"
    body = JSON.parse(res.body)

    # Verify smart_proxy metadata
    puts "DEBUG BODY: #{body.inspect}" if res.code.to_i == 200
    assert body.key?("smart_proxy"), "Expected smart_proxy metadata in response"
    assert body.dig("smart_proxy", "tools_used").is_a?(Array)
    assert body.dig("smart_proxy", "tools_used").include?("web_search")

    content = body.dig("choices", 0, "message", "content")
    assert_match(/AAPL|Apple/i, content)
    assert_match(/source|http|www\./i, content)
  end

  private

  def http_post_json(path, payload)
    uri = @base + path
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{@token}" if @token.present?
    req.body = JSON.dump(payload)

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 120 # 2 minutes for live search
      http.request(req)
    rescue Errno::ECONNREFUSED => e
      flunk "Connection refused to #{uri}. Is SmartProxy actually running on port #{uri.port}?\n" \
            "Try running: curl #{uri.scheme}://#{uri.host}:#{uri.port}/health\n" \
            "Error: #{e.message}"
    rescue StandardError => e
      flunk "HTTP Request failed to #{uri}: #{e.class} - #{e.message}"
    end
  end
end
