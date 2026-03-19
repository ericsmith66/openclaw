# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'agent_desk'
  spec.version       = '0.1.0'
  spec.authors       = [ 'AiderDesk' ]
  spec.summary       = 'Ruby port of AiderDesk agent/skill/rule/tool-calling framework'
  spec.description   = 'A Ruby framework replicating the agent profile, tool calling, skill activation, ' \
                        'rule loading, hook system, and prompt templating architecture from AiderDesk.'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir['lib/**/*.rb', 'templates/**/*', 'config/**/*', 'LICENSE', 'README.md']
  spec.require_paths = [ 'lib' ]

  spec.add_dependency 'handlebars', '~> 0.8' # Handlebars template rendering
  spec.add_dependency 'json_schemer', '~> 2.3' # JSON Schema validation for tool inputs
  spec.add_dependency 'listen', '~> 3.9'      # File watching for rules/skills/prompts
  spec.add_dependency 'ruby-openai', '~> 7.4'  # OpenAI-compatible LLM API client
  spec.add_dependency 'anthropic', '~> 0.3'    # Anthropic Claude API client
  spec.add_dependency 'yaml', '~> 0.3'
end
