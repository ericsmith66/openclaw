# frozen_string_literal: true

require "test_helper"
require "ostruct"

begin
  require Rails.root.join("smart_proxy", "app")
rescue LoadError
  # The Rails bundle may not include SmartProxy's Sinatra dependencies.
  # These tests are optional and should not break the main Rails test suite.
  SmartProxyApp = nil
end

class SmartProxyToolGateTest < ActiveSupport::TestCase
  def setup
    super

    skip "SmartProxy Sinatra dependencies not available in Rails test bundle" if SmartProxyApp.nil?

    @original_env = ENV.to_h
    @original_tool_client = Object.const_defined?(:ToolClient) ? ToolClient : nil

    # Ensure SmartProxy has a logger during tests.
    $logger ||= Logger.new(nil)
  end

  def teardown
    # Restore ENV
    ENV.replace(@original_env)

    # Restore ToolClient constant
    Object.send(:remove_const, :ToolClient) if Object.const_defined?(:ToolClient)
    Object.const_set(:ToolClient, @original_tool_client) if @original_tool_client

    super
  end

  def test_web_search_is_blocked_when_tools_disabled
    ENV["SMART_PROXY_ENABLE_WEB_TOOLS"] = "false"

    Object.const_set(:ToolClient, Class.new do
      def initialize(**)
        raise "ToolClient should not be instantiated when tools are disabled"
      end
    end)

    app = SmartProxyApp.new
    app.instance_variable_set(:@session_id, "test-session")

    result = app.execute_tool("web_search", { query: "test" }.to_json)
    parsed = JSON.parse(result)

    assert_equal "tools_disabled", parsed["error"]
    assert_equal "web_search", parsed["tool"]
  end

  def test_web_search_executes_when_tools_enabled
    ENV["SMART_PROXY_ENABLE_WEB_TOOLS"] = "true"
    ENV["GROK_API_KEY"] = "test-key"

    Object.const_set(:ToolClient, Class.new do
      def initialize(api_key:, session_id: nil)
        @api_key = api_key
        @session_id = session_id
      end

      def web_search(query, num_results:)
        OpenStruct.new(status: 200, body: { results: [ { title: "ok", query: query, n: num_results } ] }.to_json)
      end

      def x_keyword_search(*)
        OpenStruct.new(status: 200, body: { results: [] }.to_json)
      end
    end)

    app = SmartProxyApp.new
    app.instance_variable_set(:@session_id, "test-session")

    result = app.execute_tool("web_search", { query: "hello", num_results: 2 }.to_json)
    parsed = JSON.parse(result)

    assert parsed["web_results"].is_a?(Hash)
    assert_equal "test-session", parsed["session_id"]
    assert_equal "ok", parsed.dig("web_results", "results", 0, "title")
  end
end
