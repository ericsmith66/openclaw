#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================================
# Set Agent Model — Update a single agent's model for a project's ROR team
#
# Usage:
#   rails runner scripts/set_agent_model.rb <project_path> <agent> <model>
#
# Examples:
#   rails runner scripts/set_agent_model.rb /Users/ericsmith66/development/legion/projects/SmartProxy "Rails Lead" grok-code-fast-1
#   rails runner scripts/set_agent_model.rb /Users/ericsmith66/development/legion/projects/SmartProxy "QA Agent" claude-sonnet-4-6
#
# Options:
#   rails runner scripts/set_agent_model.rb --list-agents <project_path>
#   rails runner scripts/set_agent_model.rb --list-models
#   rails runner scripts/set_agent_model.rb --show <project_path>
# ============================================================================

require "net/http"
require "json"

SMART_PROXY_URL = ENV.fetch("SMART_PROXY_URL", "http://192.168.4.253:3001")
SMART_PROXY_TOKEN = ENV.fetch("SMART_PROXY_TOKEN", nil)

def fetch_available_models
  uri = URI("#{SMART_PROXY_URL}/v1/models")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{SMART_PROXY_TOKEN}" if SMART_PROXY_TOKEN

  response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 10) do |http|
    http.request(req)
  end

  if response.code == "200"
    data = JSON.parse(response.body)
    (data["data"] || []).map { |m| m["id"] }.compact.sort
  else
    []
  end
rescue StandardError => e
  warn "WARNING: Could not fetch models from SmartProxy: #{e.message}"
  []
end

def find_project(path)
  project = Project.find_by(path: path)
  unless project
    puts "ERROR: No project found with path: #{path}"
    puts ""
    puts "Available projects:"
    Project.all.each { |p| puts "  #{p.name}: #{p.path}" }
    exit 1
  end
  project
end

def find_team(project)
  team = AgentTeam.find_by(name: "ROR", project: project)
  unless team
    puts "ERROR: No ROR team found for project '#{project.name}'"
    exit 1
  end
  team
end

def find_agent(team, agent_identifier)
  # Match by name (case-insensitive) or by config id
  membership = team.team_memberships.detect do |tm|
    tm.config["name"].downcase == agent_identifier.downcase ||
      tm.config["id"].downcase == agent_identifier.downcase
  end

  unless membership
    puts "ERROR: Agent '#{agent_identifier}' not found in ROR team"
    puts ""
    puts "Available agents:"
    team.team_memberships.order(:position).each do |tm|
      puts "  #{tm.config['name']} (id: #{tm.config['id']}): #{tm.config['model']}"
    end
    exit 1
  end

  membership
end

def validate_model(model_id, available_models)
  return true if available_models.empty? # Can't validate, allow it

  unless available_models.include?(model_id)
    puts "ERROR: Model '#{model_id}' not found on SmartProxy"
    puts ""
    puts "Available models (#{available_models.size}):"
    available_models.each { |m| puts "  #{m}" }
    exit 1
  end

  true
end

def show_team(project_path)
  project = find_project(project_path)
  team = find_team(project)

  puts "Project: #{project.name} (#{project.path})"
  puts "Team: ROR (#{team.team_memberships.count} agents)"
  puts ""
  team.team_memberships.order(:position).each do |tm|
    puts "  #{tm.config['name']}"
    puts "    ID:       #{tm.config['id']}"
    puts "    Provider: #{tm.config['provider']}"
    puts "    Model:    #{tm.config['model']}"
    puts ""
  end
end

def list_models
  puts "Fetching models from SmartProxy (#{SMART_PROXY_URL})..."
  models = fetch_available_models

  if models.empty?
    puts "No models found (SmartProxy may be down or token missing)"
    exit 1
  end

  puts "Available models (#{models.size}):"
  puts ""
  models.each { |m| puts "  #{m}" }
end

def list_agents(project_path)
  project = find_project(project_path)
  team = find_team(project)

  puts "ROR agents for #{project.name}:"
  team.team_memberships.order(:position).each do |tm|
    puts "  #{tm.config['name']} (#{tm.config['id']}): #{tm.config['model']}"
  end
end

def update_model(project_path, agent_identifier, new_model)
  project = find_project(project_path)
  team = find_team(project)
  membership = find_agent(team, agent_identifier)

  # Validate model exists on SmartProxy
  puts "Validating model '#{new_model}' on SmartProxy..."
  available_models = fetch_available_models
  validate_model(new_model, available_models)

  old_model = membership.config["model"]

  if old_model == new_model
    puts "No change: #{membership.config['name']} already uses #{new_model}"
    exit 0
  end

  membership.config["model"] = new_model
  membership.save!

  puts "Updated #{membership.config['name']}:"
  puts "  #{old_model} -> #{new_model}"
  puts ""
  puts "Current team lineup:"
  team.team_memberships.reload.order(:position).each do |tm|
    marker = tm.config["name"] == membership.config["name"] ? " <-- changed" : ""
    puts "  #{tm.config['name']}: #{tm.config['model']}#{marker}"
  end
end

# ============================================================================
# Main
# ============================================================================

case ARGV[0]
when "--list-models"
  list_models
when "--list-agents"
  if ARGV[1].nil?
    puts "Usage: rails runner scripts/set_agent_model.rb --list-agents <project_path>"
    exit 1
  end
  list_agents(ARGV[1])
when "--show"
  if ARGV[1].nil?
    puts "Usage: rails runner scripts/set_agent_model.rb --show <project_path>"
    exit 1
  end
  show_team(ARGV[1])
when "--help", "-h", nil
  puts <<~HELP
    Set Agent Model — Update a single agent's model for a project's ROR team

    Usage:
      rails runner scripts/set_agent_model.rb <project_path> <agent> <model>

    Commands:
      <project_path> <agent> <model>   Update agent's model
      --show <project_path>            Show current team lineup
      --list-agents <project_path>     List available agents
      --list-models                    List available models from SmartProxy
      --help                           Show this help

    Examples:
      rails runner scripts/set_agent_model.rb /path/to/project "Rails Lead" grok-code-fast-1
      rails runner scripts/set_agent_model.rb /path/to/project ror-rails grok-code-fast-1
      rails runner scripts/set_agent_model.rb --show /path/to/project
      rails runner scripts/set_agent_model.rb --list-models

    Agent names (case-insensitive, name or id):
      "Rails Lead"  / ror-rails
      "Architect"   / ror-architect
      "QA Agent"    / ror-qa
      "Debug Agent" / ror-debug
  HELP
when /^--/
  puts "Unknown option: #{ARGV[0]}"
  puts "Run with --help for usage"
  exit 1
else
  if ARGV.size < 3
    puts "ERROR: Missing arguments"
    puts "Usage: rails runner scripts/set_agent_model.rb <project_path> <agent> <model>"
    puts "Run with --help for full usage"
    exit 1
  end
  update_model(ARGV[0], ARGV[1], ARGV[2])
end
