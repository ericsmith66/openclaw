require "spec_helper"
require_relative "../../lib/claude_client"

RSpec.describe ClaudeClient do
  # -----------------------------------------------------------------------
  # Helpers – ENV isolation without external gems
  # -----------------------------------------------------------------------

  def with_env(key, value)
    old_value   = ENV[key]
    old_existed = ENV.key?(key)
    value.nil? ? ENV.delete(key) : ENV[key] = value
    yield
  ensure
    old_existed ? ENV[key] = old_value : ENV.delete(key)
  end

  # -----------------------------------------------------------------------
  # Shared fixtures
  # -----------------------------------------------------------------------

  let(:api_key)      { "test-anthropic-key" }
  let(:client)       { described_class.new(api_key: api_key) }
  let(:models_url)   { "https://api.anthropic.com/v1/models" }

  # Minimal but realistic Anthropic /v1/models response body
  let(:api_model_payload) do
    {
      "object" => "list",
      "data"   => [
        {
          "id"         => "claude-opus-4-5-20250929",
          "object"     => "model",
          "created_at" => "2025-09-29T00:00:00Z"
        },
        {
          "id"         => "claude-sonnet-4-5-20250929",
          "object"     => "model",
          "created_at" => "2025-09-29T00:00:00Z"
        }
      ]
    }
  end

  # Keys every normalised model hash must carry (T5 contract)
  REQUIRED_CLAUDE_MODEL_KEYS = %i[id object owned_by created smart_proxy].freeze

  # -----------------------------------------------------------------------
  # T1 – returns normalised hash array on success (200)
  # -----------------------------------------------------------------------

  describe "#list_models (T1: 200 success)" do
    before do
      stub_request(:get, models_url)
        .with(headers: { "x-api-key" => api_key })
        .to_return(
          status:  200,
          body:    api_model_payload.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns an Array" do
      expect(client.list_models).to be_an(Array)
    end

    it "returns one entry per model in the API response" do
      expect(client.list_models.size).to eq(2)
    end

    it "maps id from the upstream payload" do
      ids = client.list_models.map { |m| m[:id] }
      expect(ids).to contain_exactly("claude-opus-4-5-20250929", "claude-sonnet-4-5-20250929")
    end

    it "forces object to \"model\"" do
      expect(client.list_models.map { |m| m[:object] }).to all(eq("model"))
    end

    it "sets owned_by to \"anthropic\"" do
      expect(client.list_models.map { |m| m[:owned_by] }).to all(eq("anthropic"))
    end

    it "carries a created integer timestamp" do
      client.list_models.each { |m| expect(m[:created]).to be_an(Integer) }
    end

    it "sets smart_proxy provider to \"anthropic\"" do
      expect(client.list_models.map { |m| m.dig(:smart_proxy, :provider) }).to all(eq("anthropic"))
    end

    it "hits the correct endpoint" do
      client.list_models
      expect(WebMock).to have_requested(:get, models_url)
    end
  end

  # -----------------------------------------------------------------------
  # T2 – returns [] (or ENV fallback) on Faraday::Error
  # -----------------------------------------------------------------------

  describe "#list_models (T2: Faraday::Error)" do
    context "when Faraday::ConnectionFailed is raised" do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "returns an Array" do
        with_env("ANTHROPIC_MODELS", nil) { expect(client.list_models).to be_an(Array) }
      end

      it "returns [] when ANTHROPIC_MODELS is not set" do
        with_env("ANTHROPIC_MODELS", nil) { expect(client.list_models).to eq([]) }
      end

      it "does not propagate the exception" do
        with_env("ANTHROPIC_MODELS", nil) { expect { client.list_models }.not_to raise_error }
      end
    end

    context "when Faraday::TimeoutError is raised" do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::TimeoutError.new("execution expired"))
      end

      it "returns [] when ANTHROPIC_MODELS is not set" do
        with_env("ANTHROPIC_MODELS", nil) { expect(client.list_models).to eq([]) }
      end

      it "does not propagate the exception" do
        with_env("ANTHROPIC_MODELS", nil) { expect { client.list_models }.not_to raise_error }
      end
    end
  end

  # -----------------------------------------------------------------------
  # T3 – returns [] (or ENV fallback) on non-200 response
  # -----------------------------------------------------------------------

  describe "#list_models (T3: non-200 response)" do
    [401, 403, 429, 500, 503].each do |status_code|
      context "when the server returns HTTP #{status_code}" do
        before do
          stub_request(:get, models_url)
            .to_return(
              status:  status_code,
              body:    { error: "upstream error" }.to_json,
              headers: { "Content-Type" => "application/json" }
            )
        end

        it "returns [] for #{status_code} when ANTHROPIC_MODELS is not set" do
          with_env("ANTHROPIC_MODELS", nil) { expect(client.list_models).to eq([]) }
        end

        it "does not raise for #{status_code}" do
          with_env("ANTHROPIC_MODELS", nil) { expect { client.list_models }.not_to raise_error }
        end
      end
    end

    context "when the response body contains a data array but status is 401" do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  401,
            body:    api_model_payload.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "ignores body data on non-200 and returns [] without a fallback env var" do
        with_env("ANTHROPIC_MODELS", nil) { expect(client.list_models).to eq([]) }
      end
    end
  end

  # -----------------------------------------------------------------------
  # T4 – falls back to ANTHROPIC_MODELS CSV env var when live returns empty
  # -----------------------------------------------------------------------

  describe "#list_models (T4: ANTHROPIC_MODELS env var fallback)" do
    let(:env_models_csv) { "claude-opus-4-5-20250929,claude-sonnet-4-5-20250929, claude-haiku-4-5 " }

    shared_examples "returns env fallback models" do
      it "returns an Array" do
        with_env("ANTHROPIC_MODELS", env_models_csv) { expect(client.list_models).to be_an(Array) }
      end

      it "returns one entry per non-empty CSV token" do
        with_env("ANTHROPIC_MODELS", env_models_csv) { expect(client.list_models.size).to eq(3) }
      end

      it "uses the CSV values as model ids" do
        with_env("ANTHROPIC_MODELS", env_models_csv) do
          expect(client.list_models.map { |m| m[:id] })
            .to contain_exactly(
              "claude-opus-4-5-20250929",
              "claude-sonnet-4-5-20250929",
              "claude-haiku-4-5"
            )
        end
      end

      it "strips surrounding whitespace from each CSV token" do
        with_env("ANTHROPIC_MODELS", " claude-opus-4-5-20250929 , claude-haiku-4-5 ") do
          expect(client.list_models.map { |m| m[:id] })
            .to contain_exactly("claude-opus-4-5-20250929", "claude-haiku-4-5")
        end
      end

      it "sets owned_by to \"anthropic\" for every fallback entry" do
        with_env("ANTHROPIC_MODELS", env_models_csv) do
          expect(client.list_models.map { |m| m[:owned_by] }).to all(eq("anthropic"))
        end
      end

      it "sets smart_proxy provider to \"anthropic\" for every fallback entry" do
        with_env("ANTHROPIC_MODELS", env_models_csv) do
          expect(client.list_models.map { |m| m.dig(:smart_proxy, :provider) }).to all(eq("anthropic"))
        end
      end
    end

    context "when the API raises a Faraday::Error" do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      include_examples "returns env fallback models"
    end

    context "when the API returns 200 with an empty data array" do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  200,
            body:    { "object" => "list", "data" => [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      include_examples "returns env fallback models"
    end

    context "when the API returns a non-200 response" do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  503,
            body:    { error: "service unavailable" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      include_examples "returns env fallback models"
    end

    context "when ANTHROPIC_MODELS is an empty string" do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "returns [] (empty CSV treated as no fallback)" do
        with_env("ANTHROPIC_MODELS", "") { expect(client.list_models).to eq([]) }
      end
    end
  end

  # -----------------------------------------------------------------------
  # T5 – every returned hash contains the five required normalised keys
  # -----------------------------------------------------------------------

  describe "#list_models (T5: normalised key contract)" do
    context "when the API returns live models" do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  200,
            body:    api_model_payload.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "every hash contains all five required keys" do
        client.list_models.each do |model|
          expect(model.keys).to include(*REQUIRED_CLAUDE_MODEL_KEYS),
            "expected model #{model.inspect} to include #{REQUIRED_CLAUDE_MODEL_KEYS}"
        end
      end

      it "id is a non-nil String" do
        client.list_models.each { |m| expect(m[:id]).to be_a(String) }
      end

      it "object is the String \"model\"" do
        client.list_models.each { |m| expect(m[:object]).to eq("model") }
      end

      it "owned_by is a non-nil String" do
        client.list_models.each { |m| expect(m[:owned_by]).to be_a(String) }
      end

      it "created is an Integer" do
        client.list_models.each { |m| expect(m[:created]).to be_an(Integer) }
      end

      it "smart_proxy is a Hash with a :provider String" do
        client.list_models.each do |m|
          expect(m[:smart_proxy]).to be_a(Hash)
          expect(m[:smart_proxy][:provider]).to be_a(String)
        end
      end
    end

    context "when models come from the ANTHROPIC_MODELS env var fallback" do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "every fallback hash contains all five required keys" do
        with_env("ANTHROPIC_MODELS", "claude-opus-4-5-20250929,claude-sonnet-4-5-20250929") do
          client.list_models.each do |model|
            expect(model.keys).to include(*REQUIRED_CLAUDE_MODEL_KEYS),
              "expected fallback model #{model.inspect} to include #{REQUIRED_CLAUDE_MODEL_KEYS}"
          end
        end
      end

      it "fallback created is an Integer" do
        with_env("ANTHROPIC_MODELS", "claude-opus-4-5-20250929") do
          client.list_models.each { |m| expect(m[:created]).to be_an(Integer) }
        end
      end

      it "fallback object is \"model\"" do
        with_env("ANTHROPIC_MODELS", "claude-opus-4-5-20250929") do
          client.list_models.each { |m| expect(m[:object]).to eq("model") }
        end
      end
    end
  end

  # -----------------------------------------------------------------------
  # T6 – list_models never returns IDs ending in "-with-live-search"
  # -----------------------------------------------------------------------

  describe "#list_models (T6: no -with-live-search IDs)" do
    context "when the API returns a mix of standard and live-search model IDs" do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  200,
            body:    {
              "object" => "list",
              "data"   => [
                { "id" => "claude-sonnet-4-5-20250929",                   "created_at" => "2025-09-29T00:00:00Z" },
                { "id" => "claude-sonnet-4-5-20250929-with-live-search",  "created_at" => "2025-09-29T00:00:00Z" },
                { "id" => "claude-opus-4-5-20250929",                     "created_at" => "2025-09-29T00:00:00Z" },
                { "id" => "claude-opus-4-5-20250929-with-live-search",    "created_at" => "2025-09-29T00:00:00Z" },
                { "id" => "claude-haiku-4-5-20250929",                    "created_at" => "2025-09-29T00:00:00Z" }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "does not include any model ID ending in \"-with-live-search\"" do
        ids = client.list_models.map { |m| m[:id] }
        expect(ids.none? { |id| id.end_with?("-with-live-search") }).to be(true),
          "expected no -with-live-search IDs but got: #{ids.grep(/-with-live-search$/)}"
      end

      it "still returns the standard model variants" do
        ids = client.list_models.map { |m| m[:id] }
        expect(ids).to include(
          "claude-sonnet-4-5-20250929",
          "claude-opus-4-5-20250929",
          "claude-haiku-4-5-20250929"
        )
      end
    end

    context "when every API model has a -with-live-search suffix" do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  200,
            body:    {
              "object" => "list",
              "data"   => [
                { "id" => "claude-sonnet-4-5-20250929-with-live-search", "created_at" => "2025-09-29T00:00:00Z" }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns an empty array when the only available IDs are -with-live-search variants" do
        expect(client.list_models).to eq([])
      end
    end

    context "when the ANTHROPIC_MODELS env fallback contains -with-live-search IDs" do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "does not include any -with-live-search ID from the fallback list" do
        with_env(
          "ANTHROPIC_MODELS",
          "claude-sonnet-4-5-20250929,claude-sonnet-4-5-20250929-with-live-search,claude-opus-4-5-20250929"
        ) do
          ids = client.list_models.map { |m| m[:id] }
          expect(ids.none? { |id| id.end_with?("-with-live-search") }).to be(true),
            "expected no -with-live-search IDs but got: #{ids.grep(/-with-live-search$/)}"
        end
      end
    end
  end

  # -----------------------------------------------------------------------
  # Pre-existing #map_to_claude coverage
  # -----------------------------------------------------------------------

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
      expect(mapped[:system]).to eq([{ 'type' => 'text', 'text' => 'You are a helpful assistant.' }])
      expect(mapped[:messages]).to eq([ { role: "user", content: [ { type: "text", text: "Hello" } ] } ])
    end

    it "converts tool role messages to tool_result content blocks in a user message" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "user", content: "Search for news" },
          { role: "assistant", content: nil, tool_calls: [
            { id: "call_123", type: "function", function: { name: "web_search", arguments: '{"query":"latest news"}' } }
          ] },
          { role: "tool", tool_call_id: "call_123", content: '{"results":[{"title":"News"}]}' }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      expect(mapped[:messages].length).to eq(3)

      expect(mapped[:messages][0][:role]).to eq("user")

      assistant_msg = mapped[:messages][1]
      expect(assistant_msg[:role]).to eq("assistant")
      expect(assistant_msg[:content]).to include(
        hash_including(type: "tool_use", id: "call_123", name: "web_search", input: { "query" => "latest news" })
      )

      tool_result_msg = mapped[:messages][2]
      expect(tool_result_msg[:role]).to eq("user")
      expect(tool_result_msg[:content]).to eq([
        { type: "tool_result", tool_use_id: "call_123", content: '{"results":[{"title":"News"}]}' }
      ])
    end

    it "merges consecutive tool messages into a single user message" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "user", content: "Search for both" },
          { role: "assistant", content: nil, tool_calls: [
            { id: "call_1", type: "function", function: { name: "web_search", arguments: '{"query":"a"}' } },
            { id: "call_2", type: "function", function: { name: "x_keyword_search", arguments: '{"query":"b"}' } }
          ] },
          { role: "tool", tool_call_id: "call_1", content: "result_a" },
          { role: "tool", tool_call_id: "call_2", content: "result_b" }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      expect(mapped[:messages].length).to eq(3)

      tool_result_msg = mapped[:messages][2]
      expect(tool_result_msg[:role]).to eq("user")
      expect(tool_result_msg[:content].length).to eq(2)
      expect(tool_result_msg[:content][0]).to eq(
        { type: "tool_result", tool_use_id: "call_1", content: "result_a" }
      )
      expect(tool_result_msg[:content][1]).to eq(
        { type: "tool_result", tool_use_id: "call_2", content: "result_b" }
      )
    end

    it "converts assistant tool_calls to tool_use content blocks" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "user", content: "Hello" },
          { role: "assistant", content: "Let me search", tool_calls: [
            { id: "call_abc", type: "function", function: { name: "web_search", arguments: '{"query":"test"}' } }
          ] }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      assistant_msg = mapped[:messages][1]
      expect(assistant_msg[:role]).to eq("assistant")
      expect(assistant_msg[:content]).to eq([
        { type: "text", text: "Let me search" },
        { type: "tool_use", id: "call_abc", name: "web_search", input: { "query" => "test" } }
      ])
    end

    it "handles assistant tool_calls with no text content" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "user", content: "Search" },
          { role: "assistant", content: nil, tool_calls: [
            { id: "call_1", type: "function", function: { name: "web_search", arguments: '{"query":"x"}' } }
          ] }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      assistant_msg = mapped[:messages][1]
      expect(assistant_msg[:content]).to eq([
        { type: "tool_use", id: "call_1", name: "web_search", input: { "query" => "x" } }
      ])
    end

    it "handles tool_calls with hash arguments (not JSON string)" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "user", content: "Go" },
          { role: "assistant", tool_calls: [
            { id: "call_1", type: "function", function: { name: "web_search", arguments: { "query" => "test" } } }
          ] }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      assistant_msg = mapped[:messages][1]
      tool_use = assistant_msg[:content].find { |b| b[:type] == "tool_use" }
      expect(tool_use[:input]).to eq({ "query" => "test" })
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

    it "skips messages with nil or empty content to avoid Anthropic 400 errors" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "user", content: "Hello" },
          { role: "assistant", content: nil },
          { role: "assistant", content: "" },
          { role: "assistant", content: "   " },
          { role: "user", content: "Follow up" }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      expect(mapped[:messages]).to eq([
        { role: "user", content: [ { type: "text", text: "Hello" } ] },
        { role: "user", content: [ { type: "text", text: "Follow up" } ] }
      ])
    end

    it "skips messages with empty content arrays" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "user", content: [] },
          { role: "user", content: "Real message" }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      expect(mapped[:messages]).to eq([
        { role: "user", content: [ { type: "text", text: "Real message" } ] }
      ])
    end

    it "handles a full tool loop conversation correctly" do
      client = described_class.new(api_key: "test")

      payload = {
        model: "claude-sonnet-4-5-20250929",
        messages: [
          { role: "system", content: "Live-search is enabled." },
          { role: "user", content: "What is the latest Bitcoin price?" },
          { "role" => "assistant", "content" => nil, "tool_calls" => [
            { "id" => "toolu_01", "type" => "function", "function" => {
              "name" => "web_search", "arguments" => '{"query":"bitcoin price today"}'
            } }
          ] },
          { "role" => "tool", "tool_call_id" => "toolu_01", "content" => '{"results":[{"title":"BTC $100k"}]}' }
        ]
      }

      mapped = client.send(:map_to_claude, payload)

      expect(mapped[:system]).to eq([{ 'type' => 'text', 'text' => 'Live-search is enabled.' }])
      expect(mapped[:messages].length).to eq(3)

      expect(mapped[:messages][0][:role]).to eq("user")
      expect(mapped[:messages][0][:content]).to eq([ { type: "text", text: "What is the latest Bitcoin price?" } ])

      expect(mapped[:messages][1][:role]).to eq("assistant")
      expect(mapped[:messages][1][:content].length).to eq(1)
      expect(mapped[:messages][1][:content][0][:type]).to eq("tool_use")
      expect(mapped[:messages][1][:content][0][:id]).to eq("toolu_01")
      expect(mapped[:messages][1][:content][0][:name]).to eq("web_search")

      expect(mapped[:messages][2][:role]).to eq("user")
      expect(mapped[:messages][2][:content].length).to eq(1)
      expect(mapped[:messages][2][:content][0][:type]).to eq("tool_result")
      expect(mapped[:messages][2][:content][0][:tool_use_id]).to eq("toolu_01")
    end

    it "handles string-keyed messages from tool_orchestrator" do
      client = described_class.new(api_key: "test")

      payload = {
        "model" => "claude-sonnet-4-5-20250929",
        "messages" => [
          { "role" => "user", "content" => "Hello" },
          { "role" => "assistant", "content" => nil, "tool_calls" => [
            { "id" => "tc_1", "type" => "function", "function" => { "name" => "search", "arguments" => "{}" } }
          ] },
          { "role" => "tool", "tool_call_id" => "tc_1", "content" => "found it" }
        ]
      }

      mapped = client.send(:map_to_claude, payload)
      expect(mapped[:messages].length).to eq(3)
      expect(mapped[:messages][2][:role]).to eq("user")
      expect(mapped[:messages][2][:content][0][:type]).to eq("tool_result")
    end
  end

  describe "prompt caching support" do
    describe "#map_to_claude" do
      it "T1: uses client-provided cache_control over auto-injection" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          cache_control: { "type" => "ephemeral", "ttl" => "1h" },
          messages: [
            { role: "user", content: "Hello" }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        expect(mapped[:cache_control]).to eq({ "type" => "ephemeral", "ttl" => "1h" })
      end

      it "T2: auto-injects cache_control when not provided by client (default behavior)" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          messages: [
            { role: "user", content: "Hello" }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        expect(mapped[:cache_control]).to eq({ 'type' => 'ephemeral' })
      end

      it "T2b: omits cache_control when CLAUDE_PROMPT_CACHING=false" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          messages: [
            { role: "user", content: "Hello" }
          ]
        }

        original = ENV['CLAUDE_PROMPT_CACHING']
        begin
          ENV['CLAUDE_PROMPT_CACHING'] = 'false'
          mapped = client.send(:map_to_claude, payload)
          expect(mapped).not_to have_key(:cache_control)
        ensure
          ENV['CLAUDE_PROMPT_CACHING'] = original
        end
      end

      it "T3: preserves cache_control on system content blocks" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          messages: [
            {
              role: "system",
              content: [
                { "type" => "text", "text" => "You are an expert." },
                { "type" => "text", "text" => "[LARGE REFERENCE]", "cache_control" => { "type" => "ephemeral" } }
              ]
            },
            { role: "user", content: "Summarise." }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        expect(mapped[:system].length).to eq(2)
        expect(mapped[:system][0]).to eq({ "type" => "text", "text" => "You are an expert." })
        expect(mapped[:system][1]).to eq({ "type" => "text", "text" => "[LARGE REFERENCE]", "cache_control" => { "type" => "ephemeral" } })
      end

      it "T4: plain string system message still works (converted to blocks)" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          messages: [
            { role: "system", content: "Be helpful." },
            { role: "user", content: "Hi" }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        expect(mapped[:system]).to eq([{ 'type' => 'text', 'text' => 'Be helpful.' }])
      end

      it "T5: mixed system messages with and without cache_control preserved in order" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          messages: [
            { role: "system", content: "First instruction." },
            {
              role: "system",
              content: [
                { "type" => "text", "text" => "Context doc.", "cache_control" => { "type" => "ephemeral" } }
              ]
            },
            { role: "user", content: "Go" }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        expect(mapped[:system].length).to eq(2)
        expect(mapped[:system][0]).to eq({ 'type' => 'text', 'text' => 'First instruction.' })
        expect(mapped[:system][1]).to eq({ "type" => "text", "text" => "Context doc.", "cache_control" => { "type" => "ephemeral" } })
      end

      it "T6: preserves cache_control on user message content blocks" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          messages: [
            {
              role: "user",
              content: [
                { "type" => "text", "text" => "Based on this document:" },
                { "type" => "text", "text" => "[LARGE DOC]", "cache_control" => { "type" => "ephemeral" } },
                { "type" => "text", "text" => "List all action items." }
              ]
            }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        user_content = mapped[:messages][0][:content]
        expect(user_content.length).to eq(3)
        expect(user_content[1]).to eq({ "type" => "text", "text" => "[LARGE DOC]", "cache_control" => { "type" => "ephemeral" } })
      end

      it "T11: cache_control with ttl 1h passes through without modification" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          cache_control: { "type" => "ephemeral", "ttl" => "1h" },
          messages: [
            { role: "user", content: "Hello" }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        expect(mapped[:cache_control]).to eq({ "type" => "ephemeral", "ttl" => "1h" })
      end

      it "T12: content block with cache_control but empty text is preserved" do
        client = described_class.new(api_key: "test")

        payload = {
          model: "claude-sonnet-4.5",
          messages: [
            {
              role: "user",
              content: [
                { "type" => "text", "text" => "", "cache_control" => { "type" => "ephemeral" } },
                { "type" => "text", "text" => "Actual question" }
              ]
            }
          ]
        }

        mapped = client.send(:map_to_claude, payload)
        user_content = mapped[:messages][0][:content]
        expect(user_content.length).to eq(2)
        expect(user_content[0]).to eq({ "type" => "text", "text" => "", "cache_control" => { "type" => "ephemeral" } })
      end
    end

    describe "#map_from_claude" do
      it "T7: surfaces cache_read_input_tokens as prompt_tokens_details.cached_tokens" do
        client = described_class.new(api_key: "test")

        body = {
          'id' => 'msg_123',
          'model' => 'claude-sonnet-4.5',
          'content' => [{ 'type' => 'text', 'text' => 'Hello' }],
          'stop_reason' => 'end_turn',
          'usage' => {
            'input_tokens' => 50,
            'output_tokens' => 100,
            'cache_read_input_tokens' => 8000
          }
        }

        result = client.send(:map_from_claude, body, {})
        expect(result['usage']['prompt_tokens_details']).to eq({
          'cached_tokens' => 8000
        })
      end

      it "T8: surfaces cache_creation_input_tokens as prompt_tokens_details.cache_creation_tokens" do
        client = described_class.new(api_key: "test")

        body = {
          'id' => 'msg_123',
          'model' => 'claude-sonnet-4.5',
          'content' => [{ 'type' => 'text', 'text' => 'Hello' }],
          'stop_reason' => 'end_turn',
          'usage' => {
            'input_tokens' => 50,
            'output_tokens' => 100,
            'cache_creation_input_tokens' => 4000
          }
        }

        result = client.send(:map_from_claude, body, {})
        expect(result['usage']['prompt_tokens_details']).to eq({
          'cache_creation_tokens' => 4000
        })
      end

      it "T9: omits prompt_tokens_details when no cache fields present (backward compat)" do
        client = described_class.new(api_key: "test")

        body = {
          'id' => 'msg_123',
          'model' => 'claude-sonnet-4.5',
          'content' => [{ 'type' => 'text', 'text' => 'Hello' }],
          'stop_reason' => 'end_turn',
          'usage' => {
            'input_tokens' => 50,
            'output_tokens' => 100
          }
        }

        result = client.send(:map_from_claude, body, {})
        expect(result['usage']).not_to have_key('prompt_tokens_details')
      end

      it "T10: includes both cached_tokens and cache_creation_tokens when both present" do
        client = described_class.new(api_key: "test")

        body = {
          'id' => 'msg_123',
          'model' => 'claude-sonnet-4.5',
          'content' => [{ 'type' => 'text', 'text' => 'Hello' }],
          'stop_reason' => 'end_turn',
          'usage' => {
            'input_tokens' => 50,
            'output_tokens' => 100,
            'cache_read_input_tokens' => 8000,
            'cache_creation_input_tokens' => 2000
          }
        }

        result = client.send(:map_from_claude, body, {})
        expect(result['usage']['prompt_tokens_details']).to eq({
          'cached_tokens' => 8000,
          'cache_creation_tokens' => 2000
        })
        expect(result['usage']['prompt_tokens']).to eq(50)
        expect(result['usage']['total_tokens']).to eq(150)
      end
    end
  end
end
