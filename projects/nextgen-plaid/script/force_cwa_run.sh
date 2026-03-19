#!/bin/bash

# Force CWA Implementation Script
# This script bypasses SAP/Coordinator/Planner layers and triggers CWA directly with the PRD content of Artifact 16.

bundle exec rails runner "
a = Artifact.find(16)
cid = \"forced-cwa-run-#{Time.now.to_i}\"

# Force state update
a.update!(phase: 'in_development', owner_persona: 'CWA')

# Setup Runner with only CWA
cwa_agent = Agents::Registry.fetch(:cwa)
instructions = \"FORCE_IMPLEMENTATION: The PRD is finalized. Build the Admin Dashboard at /admin now. PRD CONTENT: #{a.payload['content'].gsub('\"', '\"')}\"

artifacts = AiWorkflowService::ArtifactWriter.new(cid)
runner = Agents::Runner.with_agents(cwa_agent)
artifacts.attach_callbacks!(runner)

puts \"STARTING_RUN_ID:#{cid}\"

# Run the implementation
runner.run(
  instructions, 
  headers: { \"X-Request-ID\" => cid }
)
"
