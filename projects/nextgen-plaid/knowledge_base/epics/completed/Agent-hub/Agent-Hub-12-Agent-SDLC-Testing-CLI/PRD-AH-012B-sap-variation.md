# PRD-AH-012B: PRD Generation Variation and SAP Phases

Part of Epic AH-012: Agent SDLC Testing CLI.

---

## Overview

Extend the CLI to vary SAP generation in early phases and persist the generated PRD to both DB and filesystem.

---

## Logging requirements

Read: `knowledge_base/prds/prds-junie-log/junie-log-requirement.md`.

Log SAP inputs/outputs/errors to:

- `knowledge_base/logs/cli_tests/<run_id>/sap.log`

Include:

- resolved prompt (post-ERB render)
- model selection
- RAG tier list and final injected RAG content summary
- response text

---

## Functional requirements

### A) New flags

- `--input="<query>"`
- `--prompt-sap=<path/to/custom.md.erb>`
- `--model-sap=<model>`
- `--rag-sap=<tiers>` (comma-separated, e.g., `foundation,structure`)

Note: `--stage` is **artifact-phase based** only (see Epic/PRD-012A). For SAP-focused runs, use `--stage=backlog` (or another SAP-owned phase).

### B) Storage

- Canonical PRD content MUST be stored in DB: `artifact.payload["content"]`.
- Also write a rendered copy for review:
  - `knowledge_base/test_artifacts/<run_id>/prd.md`
  - include a small metadata frontmatter block (run_id, model, rag tiers, timestamp)

### C) Templating

- Prompt overrides use **ERB**.
- Expose locals:
  - `input`
  - `rag_content`

### D) RAG tiers

- Map tiers to `knowledge_base` subpaths (tier→path mapping defined in Epic/PRD-012A).
- Concatenate tiers in order.
- Cap total injected context using a deterministic proxy (100k chars); truncate with a warning log if exceeded.

### E) Retries

- Use existing SAP command retry behavior (up to 3). No additional CLI-level retries.

---

## Acceptance criteria

- AC1: Custom `--input` generates a PRD and stores it in `payload["content"]`.
- AC2: `--model-sap` switches the model used for SAP.
- AC3: `--prompt-sap` overrides the default SAP prompt.
- AC4: `--rag-sap` filters/injects tiered context.
- AC5: Writes `knowledge_base/test_artifacts/<run_id>/prd.md`.
- AC6: Logs include prompt + response + errors.
- AC7: RAG tier mapping and truncation behavior matches Epic/PRD-012A.

---

## Test cases

- Unit (RSpec): prompt override rendering and injection into SAP command
- Integration: WebMock/VCR for Ollama; run SAP stage; verify payload + filesystem output
