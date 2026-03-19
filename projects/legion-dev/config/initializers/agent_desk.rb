# frozen_string_literal: true

# Verify the agent_desk gem loads correctly at boot time.
# The gem provides: ProfileManager, RulesLoader, SkillLoader, Runner, MessageBus.
#
# Agent profiles are loaded from .aider-desk/agents/ by ProfileManager.
# SmartProxy connection uses ENV vars: SMART_PROXY_URL, SMART_PROXY_HOST,
# SMART_PROXY_PORT, SMART_PROXY_TOKEN (set via .env / dotenv-rails).

Rails.application.config.after_initialize do
  Rails.logger.info "[AgentDesk] gem v#{AgentDesk::VERSION} loaded"
  Rails.logger.info "[AgentDesk] project_dir: #{Rails.root}"

  # Verify ProfileManager can discover agent profiles
  pm = AgentDesk::Agent::ProfileManager.new
  profiles = pm.load_project_profiles(Rails.root.to_s)
  Rails.logger.info "[AgentDesk] #{profiles.size} agent profile(s) discovered"

  # Log SmartProxy configuration (presence only, not the token value)
  if ENV["SMART_PROXY_URL"].present?
    Rails.logger.info "[AgentDesk] SmartProxy configured at #{ENV['SMART_PROXY_URL']}"
  else
    Rails.logger.warn "[AgentDesk] SMART_PROXY_URL not set — agent dispatch will fail"
  end
end
