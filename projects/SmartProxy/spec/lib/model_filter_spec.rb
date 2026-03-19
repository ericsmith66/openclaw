require 'spec_helper'
require_relative '../../lib/model_filter'

RSpec.describe ModelFilter do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Build a filter with an isolated env hash so tests never touch real ENV.
  def build_filter(env: {})
    ModelFilter.new(env: env)
  end

  # Shorthand model fixtures
  def model(id, extra = {})
    { id: id }.merge(extra)
  end

  # ---------------------------------------------------------------------------
  # T1–T3: text output guard (`modalities` field)
  # ---------------------------------------------------------------------------

  describe 'text output guard' do
    subject(:filter) { build_filter }

    # T1: no `modalities` key at all → passes through (we cannot rule out text)
    it 'T1: passes a model when the modalities field is absent' do
      m = model('gpt-4o')
      expect(filter.call([m])).to include(m)
    end

    # T2: modalities contains 'text' → passes through
    it 'T2: passes a model when modalities contains "text"' do
      m = model('gpt-4-vision', modalities: %w[text image])
      expect(filter.call([m])).to include(m)
    end

    # T3: modalities present but contains only 'image' (no 'text') → filtered out
    it 'T3: removes a model when modalities contains only "image"' do
      m = model('dall-e-3', modalities: %w[image])
      expect(filter.call([m])).not_to include(m)
    end
  end

  # ---------------------------------------------------------------------------
  # T4–T6: tools guard
  # ---------------------------------------------------------------------------

  describe 'tools guard' do
    # T4: tools guard is off by default — model without 'tools' in
    #     supported_parameters still passes
    it 'T4: does not filter out models for lacking tools support by default' do
      m = model('llama3', supported_parameters: %w[temperature])
      filter = build_filter
      expect(filter.call([m])).to include(m)
    end

    # T5: when MODELS_REQUIRE_TOOLS=true, a model without tools support is removed
    it 'T5: removes models lacking tools support when MODELS_REQUIRE_TOOLS is true' do
      m = model('llama3', supported_parameters: %w[temperature])
      filter = build_filter(env: { 'MODELS_REQUIRE_TOOLS' => 'true' })
      expect(filter.call([m])).not_to include(m)
    end

    # T6: when MODELS_REQUIRE_TOOLS=true, a model with 'tools' in
    #     supported_parameters passes
    it 'T6: passes models that include "tools" in supported_parameters when MODELS_REQUIRE_TOOLS is true' do
      m = model('claude-3-opus', supported_parameters: %w[temperature tools])
      filter = build_filter(env: { 'MODELS_REQUIRE_TOOLS' => 'true' })
      expect(filter.call([m])).to include(m)
    end
  end

  # ---------------------------------------------------------------------------
  # T7–T8: global blacklist regex
  # ---------------------------------------------------------------------------

  describe 'global blacklist' do
    # T7: partial ID match removes the model
    it 'T7: removes a model whose ID partially matches a blacklist pattern' do
      m = model('openai/gpt-4-vision-preview')
      filter = build_filter(env: { 'MODELS_BLACKLIST' => 'vision-preview' })
      expect(filter.call([m])).not_to include(m)
    end

    # T8: pattern matching is case-insensitive
    it 'T8: blacklist matching is case-insensitive' do
      m = model('SomeProvider/GPT-4-TURBO')
      filter = build_filter(env: { 'MODELS_BLACKLIST' => 'gpt-4-turbo' })
      expect(filter.call([m])).not_to include(m)
    end
  end

  # ---------------------------------------------------------------------------
  # T9: include override rescues a blacklisted model
  # ---------------------------------------------------------------------------

  describe 'include override' do
    it 'T9: rescues a blacklisted model when its ID matches MODELS_INCLUDE' do
      m = model('openai/gpt-4-vision-preview')
      filter = build_filter(env: {
        'MODELS_BLACKLIST' => 'vision-preview',
        'MODELS_INCLUDE'   => 'gpt-4-vision-preview'
      })
      expect(filter.call([m])).to include(m)
    end
  end

  # ---------------------------------------------------------------------------
  # T10: per-provider blacklist merges with global blacklist
  # ---------------------------------------------------------------------------

  describe 'per-provider blacklist' do
    it 'T10: OPENROUTER_MODELS_BLACKLIST adds to the global MODELS_BLACKLIST' do
      blocked_by_global   = model('anthropic/claude-instant-1')
      blocked_by_provider = model('openrouter/some-experimental-model')
      safe_model          = model('claude-3-opus')

      filter = build_filter(env: {
        'MODELS_BLACKLIST'            => 'claude-instant',
        'OPENROUTER_MODELS_BLACKLIST' => 'some-experimental'
      })

      result = filter.call([blocked_by_global, blocked_by_provider, safe_model])

      expect(result).not_to include(blocked_by_global)
      expect(result).not_to include(blocked_by_provider)
      expect(result).to include(safe_model)
    end
  end

  # ---------------------------------------------------------------------------
  # T11–T13: WITH_LIVE_SEARCH_MODELS creates -with-live-search variants
  # ---------------------------------------------------------------------------

  describe 'live-search variant generation' do
    let(:matching_model)     { model('claude-3-opus') }
    let(:non_matching_model) { model('gpt-4o') }
    let(:filter) do
      build_filter(env: { 'WITH_LIVE_SEARCH_MODELS' => '^claude-' })
    end

    # T11: a model whose ID matches the regex gets a companion variant appended
    it 'T11: appends a -with-live-search variant for each matching model' do
      result = filter.call([matching_model, non_matching_model])
      variant_ids = result.map { |m| m[:id] }
      expect(variant_ids).to include('claude-3-opus-with-live-search')
    end

    # T12: the generated variant carries smart_proxy features live-search + tools
    it 'T12: live-search variant includes smart_proxy features live-search and tools' do
      result = filter.call([matching_model])
      variant = result.find { |m| m[:id] == 'claude-3-opus-with-live-search' }

      expect(variant).not_to be_nil
      expect(variant[:smart_proxy]).to be_a(Hash)
      expect(variant[:smart_proxy][:features]).to include('live-search', 'tools')
    end

    # T13: non-matching models get no live-search variant
    it 'T13: does not produce a live-search variant for non-matching models' do
      result = filter.call([non_matching_model])
      variant_ids = result.map { |m| m[:id] }
      expect(variant_ids).not_to include('gpt-4o-with-live-search')
    end
  end

  # ---------------------------------------------------------------------------
  # T14: empty input
  # ---------------------------------------------------------------------------

  it 'T14: returns an empty list without error when given an empty input list' do
    filter = build_filter
    expect { filter.call([]) }.not_to raise_error
    expect(filter.call([])).to eq([])
  end

  # ---------------------------------------------------------------------------
  # T15: parse_patterns with nil / empty string
  # ---------------------------------------------------------------------------

  describe '.parse_patterns' do
    it 'T15: returns an empty array for nil input' do
      expect(ModelFilter.parse_patterns(nil)).to eq([])
    end

    it 'T15: returns an empty array for an empty string input' do
      expect(ModelFilter.parse_patterns('')).to eq([])
    end
  end
end
