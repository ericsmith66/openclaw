# PRD 2-05: PromptBuilder Service (Liquid)

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-14: Liquid templates in `app/prompts/`
- D-26: Prompt templates use **Liquid** (not ERB) for sandboxing, strict variable validation, and safe user-editability in future epics
- D-33: Retrospective has 6 named categories with markdown heading structure. `retrospective_prompt.md.liquid` added to PromptBuilder (7th template).
- D-37: Static manifest for `required_context`. Convention comment `{# REQUIRED: var1, var2 #}` in templates for future parsing. Manifest completeness test.
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

Epic 1 constructs prompts inline — `DecompositionService` builds its prompt as a string, and `PlanExecutionService` enriches task prompts with file context directly. There's no centralized prompt management, no templating engine, and no way to edit prompts without changing Ruby code.

PRD 2-05 introduces PromptBuilder — a service that renders phase-specific prompts from Liquid templates (D-26). Liquid provides sandboxed execution (templates can't run arbitrary Ruby), strict variable validation (raises on undefined variables), and filters for common transforms (`truncate`, `default`). Templates live in `app/prompts/` as `.md.liquid` files. The Conductor prompt (`conductor_prompt.md.liquid`) is the most important template — it IS the workflow engine.

---

### Requirements

#### Functional

- FR-1: Add `gem 'liquid'` to Gemfile
- FR-2: Create `PromptBuilder` service: `Legion::PromptBuilder.build(phase:, context:) → String`
- FR-3: `PromptBuilder` renders Liquid templates in strict mode (`Liquid::Template.error_mode = :strict`) — raises `Liquid::UndefinedVariable` on missing variables
- FR-4: Context is passed as a flat Hash (Liquid requirement — no arbitrary Ruby objects in template scope)
- FR-5: Create template directory `app/prompts/` with `.md.liquid` files (7 templates). Each template includes a convention comment at the top `{# REQUIRED: var1, var2 #}` for future parsing (D-37):
  - `conductor_prompt.md.liquid` — the workflow engine logic (see epic overview)
  - `decomposition_prompt.md.liquid` — refactored from DecompositionService
  - `task_prompt.md.liquid` — task execution prompt with file context
  - `architect_review_prompt.md.liquid` — plan review prompt
  - `qa_score_prompt.md.liquid` — QA scoring prompt
  - `retry_prompt.md.liquid` — retry prompt with accumulated context
  - `retrospective_prompt.md.liquid` — retrospective analysis prompt (D-33)
- FR-6: `PromptBuilder.available_phases` → returns list of phases with templates
- FR-7: `PromptBuilder.required_context(phase:)` → returns list of required context keys for a given phase (static manifest per phase). Add a manifest completeness test requirement: render each template with only manifest-specified keys → verify no `Liquid::UndefinedVariable` (D-37).
- FR-8: Refactor `DecompositionService` to use `PromptBuilder.build(phase: :decompose, context: { prd_content: ..., project_path: ... })` instead of inline prompt construction
- FR-9: Custom Liquid filters for prompt engineering: `truncate_tokens` (approximate token-based truncation), `indent` (indent multiline strings)
- FR-10: Template inheritance not required (each template is self-contained)

#### Non-Functional

- NF-1: Template rendering must complete in < 50ms (no I/O during render — all context pre-loaded)
- NF-2: Templates are version-controlled in `app/prompts/` — changes tracked in Git
- NF-3: Liquid strict mode must be the default — never silently swallow missing variables

#### Rails / Implementation Notes

- **Gem**: `liquid` added to Gemfile
- **Service**: `app/services/legion/prompt_builder.rb`
- **Templates**: `app/prompts/*.md.liquid` (6 templates)
- **Filters**: `app/services/legion/liquid_filters.rb` — custom Liquid filters
- **Refactor**: `app/services/legion/decomposition_service.rb` — use PromptBuilder

---

### Error Scenarios & Fallbacks

- **Template not found for phase** → `PromptBuilder` raises `Legion::TemplateNotFoundError` ("No template for phase :unknown")
- **Missing required context variable** → Liquid strict mode raises `Liquid::UndefinedVariable` with variable name. PromptBuilder wraps this in `Legion::PromptContextError` ("Missing context variable 'prd_content' for phase :decompose")
- **Template syntax error** → Liquid raises `Liquid::SyntaxError` at render time. PromptBuilder wraps in `Legion::TemplateSyntaxError` with template path and line number.
- **Context value is nil** → Liquid renders empty string for `{{ nil_value }}`. Use `{{ value | default: "not available" }}` filter in templates to handle optional values explicitly.

---

### Architectural Context

PromptBuilder is the centralized prompt management layer that all services use. Before this PRD, each service builds its own prompt string. After this PRD, services call `PromptBuilder.build(phase:, context:)` and receive a rendered prompt.

The choice of Liquid over ERB (D-26) is deliberate:
- Prompts are data, not code — Liquid's sandboxing prevents accidental code execution
- Strict mode provides the context validation the Architect requested (S-7)
- In Epic 4+, prompts may become user-editable — Liquid is safe for untrusted input
- Liquid filters (`truncate`, `default`) are natural for prompt engineering

The Conductor prompt template is the workflow engine — workflow changes are template edits, not code changes. This template is the single most important file in Epic 2.

**Non-goal:** This PRD does not implement the Conductor — it creates the template and the rendering infrastructure. PRD 2-06 implements the ConductorService that renders and dispatches the Conductor prompt.

---

### Acceptance Criteria

- [ ] AC-1: `PromptBuilder.build(phase: :decompose, context: { prd_content: "...", project_path: "..." })` returns a rendered prompt string containing the PRD content
- [ ] AC-2: Given a template with `{{ undefined_var }}`, `PromptBuilder.build` raises `Legion::PromptContextError` with the variable name
- [ ] AC-3: `PromptBuilder.available_phases` returns `[:conductor, :decompose, :code, :architect_review, :qa_score, :retry, :retrospective]`
- [ ] AC-4: `PromptBuilder.required_context(phase: :decompose)` returns the context keys used in the decomposition template
- [ ] AC-5: `DecompositionService` uses `PromptBuilder.build(phase: :decompose, ...)` instead of inline prompt construction (refactored)
- [ ] AC-6: `conductor_prompt.md.liquid` exists and renders correctly with execution state context (phase, attempt, scores, tasks)
- [ ] AC-7: All 7 template files exist in `app/prompts/` with `.md.liquid` extension
- [ ] AC-8: Custom filter `truncate_tokens` truncates text to approximate token count
- [ ] AC-9: Liquid strict mode is enabled by default (verified by test)
- [ ] AC-10: `liquid` gem is in Gemfile and `bundle install` succeeds

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/prompt_builder_test.rb`: Render each phase template with valid context. Missing context raises PromptContextError. Unknown phase raises TemplateNotFoundError. Template syntax error raises TemplateSyntaxError. `available_phases` returns all phases. `required_context` returns correct keys per phase.
- `test/services/legion/liquid_filters_test.rb`: `truncate_tokens` filter (truncate at approximate token boundary), `indent` filter, `default` filter for nil values.

#### Integration (Minitest)

- `test/integration/prompt_builder_integration_test.rb`: Render decomposition prompt → verify it contains PRD content. Render conductor prompt with full execution state → verify all state values present. Verify DecompositionService refactored (uses PromptBuilder, not inline).

---

### Manual Verification

1. Open Rails console: `bin/rails console`
2. Run: `Legion::PromptBuilder.build(phase: :decompose, context: { prd_content: "Build a user model", project_path: "/tmp/test" })`
3. Verify: returned string contains "Build a user model"
4. Run: `Legion::PromptBuilder.build(phase: :decompose, context: {})` — verify error raised with missing variable name
5. Run: `Legion::PromptBuilder.available_phases` — verify all 6 phases listed
6. Run `bin/legion decompose` on a PRD — verify it still works (uses PromptBuilder now)

**Expected:** Templates render correctly, errors are descriptive, DecompositionService works via PromptBuilder.

---

### Dependencies

- **Blocked By:** 2-01 (base infrastructure)
- **Blocks:** 2-06 (Conductor needs PromptBuilder for conductor_prompt), 2-07 (QualityGate needs scoring prompt templates)

---

### Rollout / Deployment Notes

- **Gem addition**: `liquid` gem. Run `bundle install`.
- **Template files**: 6 new files in `app/prompts/`. Version-controlled.
- **Refactor**: DecompositionService changes — test existing decompose command still works.

---

