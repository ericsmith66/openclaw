# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"

# Live smoke tests for SmartProxy.
#
# These tests intentionally hit a *running* SmartProxy instance over HTTP.
# They are skipped by default.
#
# Run:
#   SMART_PROXY_LIVE_TEST=true bin/rails test test/smoke/smart_proxy_live_test.rb
#
class SmartProxyLiveTest < ActiveSupport::TestCase
  def setup
    super
    skip "Set SMART_PROXY_LIVE_TEST=true to enable" unless ENV["SMART_PROXY_LIVE_TEST"] == "true"

    # These tests are intentionally "live" and should not be intercepted by VCR.
    if defined?(VCR)
      @vcr_was_turned_on = VCR.turned_on?
      VCR.turn_off!
    end

    # WebMock is used across the test suite; allow real HTTP for these live tests.
    if defined?(WebMock)
      @webmock_was_allowing_net_connect = WebMock.net_connect_allowed?
      WebMock.allow_net_connect!
    end

    @port = ENV.fetch("SMART_PROXY_PORT", "3002")
    @base = URI("http://localhost:#{@port}")
    @token = ENV["PROXY_AUTH_TOKEN"].to_s
  end

  def teardown
    if defined?(WebMock) && !@webmock_was_allowing_net_connect
      WebMock.disable_net_connect!(allow_localhost: true)
    end

    if defined?(VCR) && @vcr_was_turned_on
      VCR.turn_on!
    end
    super
  end

  def test_health
    res = http_get("/health")
    assert_equal 200, res.code.to_i
    body = JSON.parse(res.body)
    assert_equal "ok", body["status"]
  end

  def test_models_endpoint_is_openai_shaped
    res = http_get("/v1/models")
    assert_equal 200, res.code.to_i
    body = JSON.parse(res.body)
    assert_equal "list", body["object"]
    assert body["data"].is_a?(Array)
  end

  def test_chat_completions_ollama_style_with_tools_returns_choices_and_usage
    res = http_post_json("/v1/chat/completions", {
      model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
      messages: [
        { role: "developer", content: "You are a helpful assistant." },
        { role: "user", content: "Say hello in one short sentence." }
      ],
      stream: false,
      temperature: 0.2,
      tools: [
        {
          type: "function",
          function: {
            name: "noop",
            description: "No-op tool",
            parameters: { type: "object", properties: {}, required: [] }
          }
        }
      ]
    })

    assert_equal 200, res.code.to_i
    body = JSON.parse(res.body)
    assert body["choices"].is_a?(Array), "expected choices array"
    assert body.dig("choices", 0, "message", "content").present?, "expected message content"
    assert body["usage"].is_a?(Hash), "expected usage hash"
    assert body.dig("usage", "prompt_tokens").is_a?(Integer)
    assert body.dig("usage", "completion_tokens").is_a?(Integer)
    assert body.dig("usage", "total_tokens").is_a?(Integer)
  end

  def test_chat_completions_grok_style_if_configured
    skip "GROK_API_KEY not set; skipping Grok live test" if ENV["GROK_API_KEY"].blank?

    grok_model = ENV.fetch("GROK_MODEL", "grok-4")

    res = http_post_json("/v1/chat/completions", {
      model: grok_model,
      messages: [
        { role: "system", content: "You are a helpful assistant." },
        { role: "user", content: "Reply with the word OK." }
      ],
      stream: false,
      temperature: 0.0,
      tools: []
    })

    assert_equal 200, res.code.to_i, "Grok returned HTTP #{res.code}: #{res.body.to_s.tr("\n", " ")[0, 500]}"

    body = JSON.parse(res.body)
    assert body["choices"].is_a?(Array), "expected choices array"
    assert body.dig("choices", 0, "message", "content").present?
    assert body["usage"].is_a?(Hash), "expected usage hash"
  end

  def test_grok_live_search_price_question_if_configured
    skip "GROK_API_KEY not set; skipping Grok live-search test" if ENV["GROK_API_KEY"].blank?
    skip "Set SMART_PROXY_ENABLE_WEB_TOOLS=true to enable Grok live-search" unless ENV.fetch("SMART_PROXY_ENABLE_WEB_TOOLS", "false") == "true"

    grok_model = ENV.fetch("GROK_LIVE_SEARCH_MODEL", "grok-4-with-live-search")

    res = http_post_json("/v1/chat/completions", {
      model: grok_model,
      messages: [
        { role: "system", content: "You are a helpful assistant." },
        { role: "user", content: "What is the price of Tesla (TSLA) today? Provide the price and the source you used." }
      ],
      stream: false,
      temperature: 0.0
    })

    assert_equal 200, res.code.to_i, "Grok live-search returned HTTP #{res.code}: #{res.body.to_s.tr("\n", " ")[0, 500]}"

    body = JSON.parse(res.body)
    msg = body.dig("choices", 0, "message") || {}

    # SmartProxy should complete any tool loop internally; the caller should receive a final answer.
    assert msg["tool_calls"].blank?, "expected SmartProxy to hide tool_calls from client"

    content = msg["content"].to_s
    assert content.present?, "expected final message content"
    assert_match(/TSLA|Tesla/i, content)

    # Option A contract: SmartProxy should attach structured tool results so callers
    # can display web-search output regardless of how the model summarizes it.
    assert body.dig("smart_proxy", "tool_results").is_a?(Hash), "expected smart_proxy.tool_results"
    assert body.dig("smart_proxy", "sources").is_a?(Array), "expected smart_proxy.sources"
    assert body.dig("smart_proxy", "sources", 0).to_s.start_with?("http"), "expected at least one source url"

    tools_used = body.dig("smart_proxy", "tools_used") || []
    tool_names = tools_used.map { |t| t["name"] || t[:name] }.compact
    assert_includes tool_names, "web_search", "expected SmartProxy to have used web_search for live-search model"
  end

  def test_grok_live_search_price_question_streaming_if_configured
    skip "GROK_API_KEY not set; skipping Grok live-search test" if ENV["GROK_API_KEY"].blank?
    skip "Set SMART_PROXY_ENABLE_WEB_TOOLS=true to enable Grok live-search" unless ENV.fetch("SMART_PROXY_ENABLE_WEB_TOOLS", "false") == "true"

    grok_model = ENV.fetch("GROK_LIVE_SEARCH_MODEL", "grok-4-with-live-search")

    res = http_post_json("/v1/chat/completions", {
      model: grok_model,
      messages: [
        { role: "system", content: "You are a helpful assistant." },
        { role: "user", content: "What is the price of Tesla (TSLA) today? Provide the price and the source you used." }
      ],
      stream: true,
      temperature: 0.0
    })

    assert_equal 200, res.code.to_i, "Grok live-search (stream) returned HTTP #{res.code}: #{res.body.to_s.tr("\n", " ")[0, 500]}"
    assert_includes res["content-type"].to_s, "text/event-stream", "expected SSE response"

    body_text = res.body.to_s
    assert_includes body_text, "data:", "expected SSE data frames"
    assert_includes body_text, "[DONE]", "expected SSE to terminate"

    full_content = +""

    body_text.split("\n").each do |line|
      next unless line.start_with?("data: ")
      next if line.strip == "data: [DONE]"

      data = JSON.parse(line.sub("data: ", ""))
      msg_delta = data.dig("choices", 0, "delta") || {}

      # Tool calls should not be leaked to the caller (SmartProxy completes the tool loop internally).
      assert msg_delta["tool_calls"].blank?, "expected SmartProxy to hide tool_calls from client"

      token = msg_delta["content"].to_s
      full_content << token if token.present?
    end

    assert full_content.present?, "expected final streamed assistant content"
    assert_match(/TSLA|Tesla/i, full_content)
  end

  private

  def http_get(path)
    uri = @base + path
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@token}" if @token.present?
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end

  def http_post_json(path, payload)
    uri = @base + path
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{@token}" if @token.present?
    req.body = JSON.dump(payload)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 180 # 3 minutes for live search
    http.request(req)
  end
end
