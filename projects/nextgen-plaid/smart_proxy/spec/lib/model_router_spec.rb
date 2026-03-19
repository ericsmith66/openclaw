require 'spec_helper'
require_relative '../../lib/model_router'

RSpec.describe ModelRouter do
  describe '#route' do
    it 'routes to Ollama by default' do
      router = ModelRouter.new('llama3')
      routing = router.route

      expect(routing[:provider]).to eq(:ollama)
      expect(routing[:upstream_model]).to eq('llama3')
      expect(routing[:tools_opt_in]).to be false
    end

    it 'routes to Grok when model starts with grok and API key present' do
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return('key')
      router = ModelRouter.new('grok-beta')
      routing = router.route

      expect(routing[:provider]).to eq(:grok)
      expect(routing[:use_grok]).to be true
    end

    it 'identifies live search models' do
      router = ModelRouter.new('grok-4-with-live-search')
      routing = router.route

      expect(routing[:upstream_model]).to eq('grok-4')
      expect(routing[:tools_opt_in]).to be true
    end

    it 'routes to Claude when model starts with claude and API key present' do
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return('key')
      router = ModelRouter.new('claude-3-haiku')
      routing = router.route

      expect(routing[:provider]).to eq(:claude)
      expect(routing[:use_claude]).to be true
    end
  end
end
