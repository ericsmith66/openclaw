---
name: Legion Logging
description: Implementation of logging standards for agents.
---

## When to use
- Implementing new agent actions or service objects
- Troubleshooting long-running tasks
- Ensuring auditability of agent decisions

## Required conventions
- Follow `knowledge_base/ai-instructions/task-log-requirement.md`.
- Use `Rails.logger` with appropriate levels (`info`, `warn`, `error`).
- Log the start, critical decision points, and completion of agent workflows.

## Examples
```ruby
def perform_task
  Rails.logger.info "[Agent] Starting task: #{@task_id}"
  # ... logic ...
  Rails.logger.info "[Agent] Completed task: #{@task_id} in #{duration}s"
rescue StandardError => e
  Rails.logger.error "[Agent] Failed task: #{@task_id} - #{e.message}"
  raise
end
```

## Do / Don’t
**Do**:
- Include relevant IDs (task_id, session_id) in logs
- Use structured logs if the system supports them

**Don’t**:
- Log sensitive data (passwords, API keys)
- Use `puts` for logging in production/test environments
