---
description: Comprehensive validation of agents, skills, and rules recognition.
---
# CONFIGURATION VALIDATION

To ensure the AiderDesk configuration is correctly loaded, please perform the following checks:

### 1. Rules Recognition
List all active rules currently in your context.
- [ ] Verify `Rails 8 Base Rules for Eureka HomeKit` is present.

### 2. Skills Recognition
Use the `skills---list_skills` tool to verify your expertise.
- [ ] Verify `rails-best-practices` is listed and correctly described.

### 3. Sub-Agent Connectivity (Roll Call)
For each agent below, use `subagents---run_task` with the message: 
*"Identify yourself and confirm if you can see the 'Rails 8 Base Rules' in your context."*

- **Architect** (ID: `architect`)
- **QA Agent** (ID: `qa`)
- **Debug Agent** (ID: `debug`)
- **Rails Lead** (ID: `rails`)

### 4. Command Availability
Confirm that you can see and execute the following custom commands:
- `/roll-call`
- `/validate-installation`
- `/implement-prd`

Summarize the state of the installation. All items must be 'PASS' for a valid configuration.
