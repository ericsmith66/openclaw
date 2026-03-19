#!/usr/bin/env bash
# Test 3: Dispatch Multiple Agents
# Run each command one at a time, wait for it to complete before running the next

# Command 1: Architect
bin/legion execute --team ROR --agent "Architect" --prompt "What is your role in the team?" --verbose

# Command 2: QA Agent
bin/legion execute --team ROR --agent "QA Agent" --prompt "What is your primary responsibility?" --verbose

# Command 3: Debug Agent
bin/legion execute --team ROR --agent "Debug Agent" --prompt "What types of issues do you handle?" --verbose

# Verification: Check last 4 runs
rails runner "WorkflowRun.last(4).each { |r| puts r.team_membership.config['name'].to_s + ': ' + r.status.to_s + ' (' + r.team_membership.config['model'].to_s + ')' }"
