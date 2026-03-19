require 'spec_helper'
require_relative '../../lib/model_router'
require_relative '../../lib/mlx_client'

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

    it 'routes to DeepSeek when model starts with deepseek and API key present' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DEEPSEEK_API_KEY').and_return('ds-key')
      router = ModelRouter.new('deepseek-chat')
      routing = router.route

      expect(routing[:provider]).to eq(:deepseek)
      expect(routing[:use_deepseek]).to be true
    end

    it 'falls through to Ollama when deepseek model requested but DEEPSEEK_API_KEY is absent' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DEEPSEEK_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('FIREWORKS_API_KEY').and_return(nil)
      router = ModelRouter.new('deepseek-chat')
      routing = router.route

      expect(routing[:provider]).to eq(:ollama)
      expect(routing[:use_deepseek]).to be false
    end

    it 'routes to Fireworks when model starts with accounts/fireworks/ and API key present' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FIREWORKS_API_KEY').and_return('fw-key')
      router = ModelRouter.new('accounts/fireworks/models/llama4-maverick-instruct-basic')
      routing = router.route

      expect(routing[:provider]).to eq(:fireworks)
      expect(routing[:use_fireworks]).to be true
    end

    it 'falls through to Ollama when Fireworks model requested but FIREWORKS_API_KEY is absent' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FIREWORKS_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('DEEPSEEK_API_KEY').and_return(nil)
      router = ModelRouter.new('accounts/fireworks/models/llama4-maverick-instruct-basic')
      routing = router.route

      expect(routing[:provider]).to eq(:ollama)
      expect(routing[:use_fireworks]).to be false
    end

    it 'routes mlx/ prefixed models to :mlx provider and MlxClient per FR-2' do
      router = ModelRouter.new('mlx/qwen2.5-coder-7b')
      routing = router.route

      expect(routing[:provider]).to eq(:mlx)
      expect(routing[:client]).to be_a(MlxClient)
      expect(routing[:upstream_model]).to eq('qwen2.5-coder-7b')
      expect(routing[:use_mlx]).to be true
    end

    it 'routes mlx/ prefixed models to :mlx even when other API keys present per FR-2' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return('key')
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('key')
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return('key')
      allow(ENV).to receive(:[]).with('DEEPSEEK_API_KEY').and_return('key')
      allow(ENV).to receive(:[]).with('FIREWORKS_API_KEY').and_return('key')
      allow(ENV).to receive(:[]).with('OPENROUTER_API_KEY').and_return('key')
      router = ModelRouter.new('mlx/qwen2.5-coder-7b')
      routing = router.route

      expect(routing[:provider]).to eq(:mlx)
      expect(routing[:use_mlx]).to be true
    end

    it 'non-mlx models route unchanged with use_mlx: false per FR-2' do
      router = ModelRouter.new('llama3')
      routing = router.route

      expect(routing[:provider]).to eq(:ollama)
      expect(routing[:use_mlx]).to be false
    end
  end

  describe '#use_mlx?' do
    it 'returns true for mlx/ prefixed models per FR-2' do
      router = ModelRouter.new('mlx/qwen2.5-coder-7b')
      expect(router.use_mlx?).to be true
    end

    it 'returns false for non-mlx prefixed models per FR-2' do
      router = ModelRouter.new('llama3')
      expect(router.use_mlx?).to be false
    end
  end
end
