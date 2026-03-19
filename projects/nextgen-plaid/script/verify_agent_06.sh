#!/bin/bash
echo "Running Component Tests..."
bundle exec rails test test/tools/safe_shell_tool_test.rb test/tools/git_tool_test.rb test/services/ai/cwa_task_log_service_test.rb

echo "Running Integration Smoke Test..."
# Runs a small implementation request and checks for artifacts
CORRELATION_ID="verify-$(date +%s)"
AI_TOOLS_EXECUTE=true AI_DEFAULT_MODEL=grok-4-latest rake "ai:run_request[Add a dummy text file named dummy.txt to the sandbox. IMPORTANT: You MUST call git init_sandbox first.]"

# The rake task might return quickly, but the agent might still be running if it's async (though here it seems sync)
# However, the path in the script was tmp/agent_sandbox/dummy.txt, but AgentSandboxRunner uses tmp/agent_sandbox/<cid>/repo
# Let's check for the file in a more robust way or update the script to match current architecture.

# Find any dummy.txt in the sandbox
FOUND_FILE=$(find tmp/agent_sandbox -name "dummy.txt" | head -n 1)

if [ -f "$FOUND_FILE" ]; then
  echo "Integration Success: Found $FOUND_FILE"
else
  echo "Integration Failed: dummy.txt not found in tmp/agent_sandbox"
fi
