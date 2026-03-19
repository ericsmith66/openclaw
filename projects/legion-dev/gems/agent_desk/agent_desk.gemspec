# frozen_string_literal: true

require_relative "lib/agent_desk"

Gem::Specification.new do |spec|
  spec.name = "agent_desk"
  spec.version = AgentDesk::VERSION
  spec.authors = [ "Legion Team" ]
  spec.email = [ "team@legion.example.com" ]

  spec.summary = "Ruby agent framework for AI assistants"
  spec.description = "A framework for building AI-powered agents with tools, hooks, and conversation management"
  spec.homepage = "https://github.com/ericsmith66/legion"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir["lib/**/*", "templates/**/*", "bin/*", "README.md", "LICENSE.txt"]
  spec.executables = [ "agent_desk_cli" ]
  spec.require_paths = [ "lib" ]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "simplecov", "~> 0.22"

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "liquid", "~> 5.0"
end
