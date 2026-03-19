### Feature branch created
- Branch: `feature/PRD-AH-012B-sap-variation`
- Commit: `fbd8a80`

### Implemented requirements from `PRD-AH-012B-sap-variation.md`
#### New CLI flags
- Added:
    - `--prompt-sap=<path/to/custom.md.erb>`
    - `--rag-sap=<tiers>` (comma-separated)
- Existing and used:
    - `--input="<query>"`
    - `--model-sap=<model>`

#### SAP prompt override (ERB)
- Implemented ERB rendering with locals:
    - `input`
    - `rag_content`
- Default prompt template exists when `--prompt-sap` is not provided.

#### Tiered RAG injection + truncation
- Implemented tier concatenation and deterministic cap at `100_000` chars.
- Tier behavior implemented for `foundation`, `structure`, `history`.

#### Logging (`sap.log`)
- Per run log now written to:
    - `knowledge_base/logs/cli_tests/<run_id>/sap.log`
- Includes:
    - resolved prompt
    - model
    - rag tiers + truncation metadata
    - response text (PRD content)
    - errors

#### Storage
- Canonical PRD content is expected in DB at `artifact.payload["content"]` (validated in the rake task).
- Rendered review copy written to:
    - `knowledge_base/test_artifacts/<run_id>/prd.md`
- Includes YAML frontmatter:
    - `run_id`, `model`, `rag_tiers`, `timestamp`

### How to run
Example:
```bash
rake agent:test_sdlc -- \
  --stage=backlog \
  --input="Generate a PRD for Build a admin page portal use the route for /admin and find the other admin pages and link them from the portal" \
  --model-sap="llama3.1:70b" \
  --rag-sap="foundation,structure" \
  --prompt-sap="knowledge_base/prompts/sap_prd.md.erb"
```
Outputs:
- `knowledge_base/logs/cli_tests/<run_id>/cli.log`
- `knowledge_base/logs/cli_tests/<run_id>/sap.log`
- `knowledge_base/test_artifacts/<run_id>/prd.md`

### Tests added/updated
- Updated: `test/services/agents/sdlc_test_options_test.rb`
- Added:
    - `test/services/agents/sdlc_sap_prompt_builder_test.rb`
    - `test/services/agents/sdlc_sap_rag_builder_test.rb`
    - `test/tasks/agent_test_sdlc_rake_test.rb`

Run:
```bash
bundle exec rails test \
  test/services/agents/sdlc_test_options_test.rb \
  test/services/agents/sdlc_sap_prompt_builder_test.rb \
  test/services/agents/sdlc_sap_rag_builder_test.rb \
  test/tasks/agent_test_sdlc_rake_test.rb
```

### Next step
If you want, I can also push the branch to origin and provide the exact PR title/body text matching `PRD-AH-012B` acceptance criteria.