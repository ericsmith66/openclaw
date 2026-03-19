# frozen_string_literal: true

require "test_helper"

require "ostruct"

require_relative "../../smart_proxy/lib/live_search"

class LiveSearchTest < ActiveSupport::TestCase
  class FakeGrokClient
    def initialize(content:)
      @content = content
    end

    def chat_completions(_payload)
      body = {
        "choices" => [
          {
            "message" => {
              "role" => "assistant",
              "content" => @content
            }
          }
        ]
      }

      OpenStruct.new(status: 200, body: JSON.dump(body))
    end
  end

  def test_web_search_returns_strict_json_results
    results_json = {
      "results" => [
        { "title" => "Example", "url" => "https://example.com", "snippet" => "Hello" }
      ]
    }

    search = LiveSearch.new(grok_client: FakeGrokClient.new(content: JSON.dump(results_json)))
    tool_content = search.web_search("test query", num_results: 3)

    parsed = JSON.parse(tool_content)
    assert parsed["results"].is_a?(Array)
    assert_equal "Example", parsed.dig("results", 0, "title")
    assert_equal "https://example.com", parsed.dig("results", 0, "url")
    assert_equal "Hello", parsed.dig("results", 0, "snippet")
  end

  def test_web_search_raises_on_non_json
    search = LiveSearch.new(grok_client: FakeGrokClient.new(content: "not json"))

    assert_raises(LiveSearch::Error) do
      search.web_search("test query", num_results: 3)
    end
  end
end
