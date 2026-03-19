#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to update all ROR team agents to use smart_proxy provider
# Usage: ruby scripts/fix_agent_providers.rb

require 'json'
require 'fileutils'

AIDER_DESK_PATH = File.expand_path("~/.aider-desk")
AGENTS_DIR = File.join(AIDER_DESK_PATH, "agents")

# ROR team agents that need updating
ROR_AGENTS = %w[
  ror-rails
  ror-architect
  ror-qa
  ror-debug
  aider
  aider-with-power-search
  power-tools
  master-architect
  grok41-fast-reasoning
]

def update_agent_config(agent_id)
  config_path = File.join(AGENTS_DIR, agent_id, "config.json")

  unless File.exist?(config_path)
    puts "⚠️  Skipping #{agent_id} — config not found at #{config_path}"
    return
  end

  # Read existing config
  config = JSON.parse(File.read(config_path))

  original_provider = config["provider"]
  original_model = config["model"]

  # Update provider to smart_proxy
  config["provider"] = "smart_proxy"

  # Keep original model — SmartProxy will route based on model name
  # No changes needed to model field

  # Write updated config
  File.write(config_path, JSON.pretty_generate(config))

  puts "✅ Updated #{agent_id}: #{original_provider}/#{original_model} → smart_proxy/#{original_model}"
end

puts "━━━ Updating ROR Team Agent Providers ━━━"
puts "Agents directory: #{AGENTS_DIR}"
puts

ROR_AGENTS.each do |agent_id|
  update_agent_config(agent_id)
end

puts
puts "━━━ Update Complete ━━━"
puts
puts "Next steps:"
puts "1. Re-import the ROR team:"
puts "   rails runner \"TeamImportService.call(aider_desk_path: '#{AIDER_DESK_PATH}', project_path: Project.last.path, team_name: 'ROR', dry_run: false)\""
puts
puts "2. Verify agents now use smart_proxy:"
puts "   rails runner \"AgentTeam.find_by(name: 'ROR').team_memberships.each {|tm| puts tm.config['name'] + ': ' + tm.config['provider'] + '/' + tm.config['model']}\""
puts
puts "3. Test with:"
puts "   bin/legion execute --team ROR --agent 'Rails Lead' --prompt 'Hello' --verbose"
