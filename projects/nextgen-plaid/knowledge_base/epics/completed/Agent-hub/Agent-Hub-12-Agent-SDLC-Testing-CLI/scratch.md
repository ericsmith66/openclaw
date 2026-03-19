### Changes
- Added new CLI flag `--artifact-id=<id>` (preferred) to link `agent:test_sdlc -- --stage=in_analysis` Coordinator runs to an existing PRD stored in the `artifacts` table (`artifact.payload['content']`).
- Updated stage-isolation PRD injection to prefer `--artifact-id`, with `--prd-path` retained as a fallback when you only have a file on disk.
- Updated `PRD-AH-012C-EOPRD.md` to show the correct run/test command format (including `--artifact-id`) and clarified fallback usage.

### Files touched
- `lib/agents/sdlc_test_options.rb` (new flag + validation)
- `lib/tasks/agent_test_sdlc.rake` (load PRD content from source Artifact)
- `test/services/agents/sdlc_test_options_test.rb` (coverage for `--artifact-id`)
- `test/tasks/agent_test_sdlc_rake_test.rb` (coverage for `--artifact-id` injection)
- `knowledge_base/epics/Agent-hub/Agent-Hub-12-Agent-SDLC-Testing-CLI/PRD-AH-012C-EOPRD.md` (docs update)

### Verification
- `bin/rails test test/services/agents/sdlc_test_options_test.rb test/tasks/agent_test_sdlc_rake_test.rb`