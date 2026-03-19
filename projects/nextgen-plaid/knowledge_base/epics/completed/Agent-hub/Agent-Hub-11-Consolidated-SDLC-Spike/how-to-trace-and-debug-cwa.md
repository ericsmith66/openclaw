### How-to: Trace and Debug CWA (Autonomous Implementation)

This guide provides steps to reset the environment, re-trigger implementation, and monitor CWA activity during the Epic 11 SDLC Spike.

---

### 1. Resetting the State (Database)

To test the implementation flow multiple times, you must move the artifact back to the `planning` or `in_analysis` phase.

**Command (via Rails Console or `bin/rails runner`):**
```ruby
# Find the artifact (replace 16 with your artifact ID)
a = Artifact.find(16)

# Method A: Use 'reject' to step back through the state machine
a.transition_to('reject', 'Human') # From in_development -> ready_for_development
a.transition_to('reject', 'Human') # From ready_for_development -> planning

# Method B: Hard reset to Planning
a.update!(phase: 'planning', owner_persona: 'Coordinator')
```

---

### 2. Cleaning up the Sandbox (Workspace)

CWA executes tools (like `project_search`, `file_writer`) within a sandbox directory. To ensure a "clean" run without leftover files from previous attempts, clear the sandbox area.

**Terminal Command:**
```bash
# Clear all autonomous agent workspaces
rm -rf tmp/agent_sandbox/*
```

*Note: If you want to be surgical, you can find the specific correlation ID folder in `tmp/agent_sandbox/` and delete only that one.*

---

### 3. Re-enqueuing the Implementation

You can re-trigger the CWA implementation either through the UI or directly via the Rails console.

#### A. Via the UI:
1.  **Open Agent Hub** -> **Coordinator** tab.
2.  Ensure your artifact (e.g., #16) is active in the sidebar.
3.  **To trigger manually**: Type "Start implementation" and click the generated button.
4.  **To trigger autonomously**: Type `/spike` in the chat. This launches the `AiWorkflowService` loop.

#### B. Via Rails Console:
If you want to skip the UI buttons and trigger implementation immediately:

```ruby
# 1. Setup variables
a = Artifact.find(16)
user = User.first # Or find specific user
agent_id = "coordinator-agent"

# 2. Trigger the transition to Implementation (CWA)
# This handles the state change and notifies the user in the UI
AgentHub::WorkflowBridge.execute_transition(
  artifact_id: a.id,
  command: "start_implementation",
  user: user,
  agent_id: agent_id
)

# 3. (Optional) Trigger the Autonomous Spike directly
# This starts the CWA agent actually writing code
AiWorkflowService.run(
  prompt: a.payload['content'], 
  correlation_id: "manual-spike-#{a.id}-#{Time.now.to_i}"
)
```

---

### 4. Tailing the Logs

To see what CWA is doing in real-time, you should tail two primary log locations.

#### A. The High-Level Trace (`sap.log`)
This shows RAG context generation, model requests, and high-level event routing.
```bash
tail -f agent_logs/sap.log
```
*Look for:* `RAG_PREFIX_START`, `agent_hub_message_received`, and `trigger_owner_notification`.

#### B. The Autonomous Workflow Trace (`events.ndjson`)
When using `/spike` or when CWA is running autonomously, every tool call and "thought" is logged in the workflow directory.

1.  Find the `correlation_id` of the current run (usually shown in the chat or as the folder name in `agent_logs/ai_workflow/`).
2.  Tail the events:
```bash
# Replace <ID> with the actual correlation ID folder
tail -f agent_logs/ai_workflow/<ID>/events.ndjson
```
*Look for:* `tool_start`, `tool_complete`, and `agent_thinking`.

#### C. The CWA Task Log (Markdown)
The `AiWorkflowService` generates a human-readable summary of CWA's progress.
```bash
cat agent_logs/ai_workflow/<ID>/cwa_log.md
```

---

### 5. Automated Reset & Enqueue (The "Power User" way)

If you are doing this many times, you can run this single-line command in your terminal to wipe the slate and start a fresh `/spike` for Artifact 16:

```bash
# 1. Clear sandbox
# 2. Reset DB state
# 3. Trigger /spike autonomously
bundle exec rails runner "
  FileUtils.rm_rf(Dir.glob('tmp/agent_sandbox/*'))
  a = Artifact.find(16)
  a.update!(phase: 'planning', owner_persona: 'Coordinator')
  
  # Trigger the autonomous service directly
  # (Requires an existing user for context)
  user = User.first
  AiWorkflowService.run(prompt: a.payload['content'], correlation_id: 'manual-test-#{Time.now.to_i}')
"
```

---

### 6. Troubleshooting Common Issues
- **Artifact Ownership**: If the "Start Implementation" button doesn't appear, ensure the `owner_persona` is `Coordinator`.
- **Missing Context**: If CWA seems "lost", use **Developer Mode** (eyeball icon) to inspect the RAG payload and ensure `[ACTIVE_ARTIFACT]` contains the PRD and Technical Plan.
