# PRD Generation: Agentic Phase Questions & Context Mapping

## Overview
This document defines the key questions each phase of the agentic PRD generation process attempts to answer, along with the specific context menu queries needed to gather relevant information.

**Agentic Lifecycle:**
1. **Research** - Gather raw data and understand the landscape
2. **Plan** - Generate a structured mini-plan for the PRD
3. **Verify** - Check the plan against constraints and patterns
4. **Execute** - Generate the final PRD artifact
5. **Validate** - Perform final structural and quality checks

---

## Phase 1: RESEARCH
**Goal:** Understand what exists, what's relevant, and what constraints apply

### Questions to Answer

#### Q1.1: What is the user requesting?
- **Question:** What feature/epic is being requested? What's the core intent?
- **Context Needed:**
  - User query (payload)
  - Similar past requests (if any)
- **Context Menu Keys:**
  - `fetch:sdlc:semi_static:artifact_summary` (check for similar PRDs)
  - `search:functional:*` (keyword search across capabilities)

#### Q1.2: Does this feature already exist (fully or partially)?
- **Question:** Is there an existing feature, PRD, or epic that covers this?
- **Context Needed:**
  - Existing functional capabilities
  - Completed and in-progress PRDs
  - Current roadmap
- **Context Menu Keys:**
  - `fetch:functional:*` (all capabilities)
  - `fetch:vision:roadmap:completed` (finished epics)
  - `fetch:vision:roadmap:in_progress` (current work)
  - `search:sdlc:on_demand:prds` (keyword search in PRD files)

#### Q1.3: What are the current strategic priorities?
- **Question:** Does this request align with current focus areas (SDLC vs Financial Planning)?
- **Context Needed:**
  - Vision and priorities
  - Current focus areas
  - Technical debt considerations
- **Context Menu Keys:**
  - `fetch:vision:vision:master_control_plan` (overall vision)
  - `fetch:vision:priorities:sdlc_focus` (current priorities)
  - `fetch:vision:priorities:quality_over_speed` (quality metrics)
  - `fetch:vision:technical_debt` (known issues)

#### Q1.4: What technical components are available?
- **Question:** What models, services, jobs, and routes exist that might be relevant?
- **Context Needed:**
  - High-level structural overview
  - Available layers and components
- **Context Menu Keys:**
  - `fetch:structural:data_layer` (summary of models/schema)
  - `fetch:structural:service_layer` (summary of services)
  - `fetch:structural:job_layer` (summary of background jobs)
  - `fetch:structural:interface_layer` (summary of controllers/routes)

#### Q1.5: What's the current backlog status?
- **Question:** What other work is in flight? What's the queue depth?
- **Context Needed:**
  - Active artifacts
  - Backlog items
  - Agent workload
- **Context Menu Keys:**
  - `fetch:sdlc:semi_static:artifact_summary` (recent artifacts)
  - `fetch:sdlc:semi_static:backlog_items` (prioritized tasks)

### Research Phase Output
```json
{
  "request_summary": "Brief description of user request",
  "existing_coverage": "none|partial|complete",
  "related_prds": ["PRD-XXX", "PRD-YYY"],
  "alignment_with_priorities": "high|medium|low",
  "available_components": {
    "models": ["User", "Artifact"],
    "services": ["SapAgent", "PlaidService"],
    "routes": ["/agent_hub", "/plaid/link_token"]
  },
  "backlog_context": {
    "in_progress_count": 2,
    "related_items": []
  }
}
```

---

## Phase 2: PLAN
**Goal:** Create a structured mini-plan for the PRD before writing prose

### Questions to Answer

#### Q2.1: What sections should this PRD include?
- **Question:** Based on the request type and complexity, what sections are required?
- **Context Needed:**
  - PRD template structure
  - Examples of similar PRDs
  - Required sections per PRD validation rules
- **Context Menu Keys:**
  - `fetch:sdlc:static:prd_templates` (PRD format guidelines)
  - `fetch:sdlc:on_demand:prds` (load 2-3 recent PRDs as examples)
  - `search:structural:prd_strategy` (validation rules)

#### Q2.2: How many acceptance criteria are appropriate?
- **Question:** Given the feature scope, how many AC items (5-8 range)?
- **Context Needed:**
  - Feature complexity indicators
  - Similar PRD patterns
  - Validation constraints
- **Context Menu Keys:**
  - `fetch:sdlc:static:prd_templates` (AC guidelines)
  - `search:sdlc:on_demand:prds acceptance criteria` (AC patterns in existing PRDs)

#### Q2.3: What technical considerations must be addressed?
- **Question:** What models, tables, services, or integrations are involved?
- **Context Needed:**
  - Detailed schema information
  - Service dependencies
  - Integration points
- **Context Menu Keys:**
  - `fetch:structural:data_layer:schema` (full schema.rb)
  - `fetch:structural:data_layer:core_models` (relevant model files)
  - `fetch:structural:service_layer:ai_services` (if AI-related)
  - `fetch:structural:service_layer:plaid_services` (if Plaid-related)

#### Q2.4: What are the architectural constraints?
- **Question:** What patterns must be followed? What are the architectural boundaries?
- **Context Needed:**
  - Existing architectural patterns
  - Service layer organization
  - Naming conventions
- **Context Menu Keys:**
  - `fetch:sdlc:static:ai_thinking` (AI guidelines, architectural principles)
  - `fetch:structural:service_layer` (existing service patterns)
  - `fetch:structural:configuration_layer:agent_prompts` (agent system prompts)

#### Q2.5: What risks or edge cases should be considered?
- **Question:** What could go wrong? What edge cases exist?
- **Context Needed:**
  - Technical debt related to this area
  - Past issues or failures
  - Known limitations
- **Context Menu Keys:**
  - `fetch:vision:technical_debt` (known issues)
  - `search:sdlc:on_demand:commits` (recent changes in related areas)
  - `fetch:sdlc:semi_static:artifact_summary` (check for failed/rejected PRDs)

#### Q2.6: How does this fit into the broader roadmap?
- **Question:** What epic does this belong to? What comes before/after?
- **Context Needed:**
  - Roadmap context
  - Epic relationships
  - Dependencies
- **Context Menu Keys:**
  - `fetch:vision:roadmap:in_progress` (current epics)
  - `fetch:vision:roadmap:planned` (future work)
  - `search:cross_references` (find related features)

### Planning Phase Output
```json
{
  "summary": "Brief description of what this PRD will cover",
  "key_sections": [
    "Overview",
    "Acceptance Criteria",
    "Architectural Context",
    "Test Cases",
    "Workflow"
  ],
  "acceptance_criteria_count": 6,
  "technical_considerations": [
    "Requires new Artifact phase transition",
    "Integrates with existing SapAgent::Command pattern",
    "Uses RagProvider for context gathering"
  ],
  "risks": [
    "Ollama 8B may struggle with JSON planning",
    "Token usage increases with multi-phase approach"
  ],
  "epic_context": {
    "belongs_to": "agentic_refactor",
    "depends_on": ["PRD-AH-011"],
    "enables": ["PRD-AH-013"]
  },
  "estimated_complexity": "medium"
}
```

---

## Phase 3: VERIFY
**Goal:** Check the plan against constraints, patterns, and validation rules

### Questions to Answer

#### Q3.1: Does the plan meet PRD validation requirements?
- **Question:** Will this plan produce a PRD that passes validation?
- **Context Needed:**
  - PRD validation rules
  - Required sections
  - AC count constraints
- **Context Menu Keys:**
  - `fetch:structural:service_layer:ai_services:prd_strategy` (validation logic)
  - `fetch:sdlc:static:prd_templates` (required format)

#### Q3.2: Are the proposed technical components valid?
- **Question:** Do the referenced models, tables, services actually exist?
- **Context Needed:**
  - Complete schema
  - Available services
  - Existing routes
- **Context Menu Keys:**
  - `fetch:structural:data_layer:schema` (verify tables exist)
  - `fetch:structural:service_layer` (verify services exist)
  - `fetch:structural:interface_layer:routing` (verify routes exist)

#### Q3.3: Does the plan follow existing architectural patterns?
- **Question:** Is the proposed structure consistent with existing code?
- **Context Needed:**
  - Service patterns
  - Command patterns
  - Job patterns
- **Context Menu Keys:**
  - `fetch:structural:service_layer:ai_services` (existing agent patterns)
  - `search:structural:command` (Command pattern examples)
  - `search:structural:strategy` (Strategy pattern examples)

#### Q3.4: Are there conflicts with in-progress work?
- **Question:** Does this overlap with or contradict current development?
- **Context Needed:**
  - In-progress PRDs
  - Active artifacts
  - Recent commits
- **Context Menu Keys:**
  - `fetch:vision:roadmap:in_progress` (current epics)
  - `fetch:sdlc:semi_static:artifact_summary` (active work)
  - `fetch:sdlc:on_demand:commits` (recent changes)

#### Q3.5: Is the scope appropriate?
- **Question:** Is this too large/small for a single PRD? Should it be split/merged?
- **Context Needed:**
  - Similar PRD sizes
  - Epic structure
  - Complexity patterns
- **Context Menu Keys:**
  - `search:sdlc:on_demand:prds` (compare to similar PRDs)
  - `fetch:vision:roadmap` (check epic structure)

### Verification Phase Output
```json
{
  "status": "approved|corrected|rejected",
  "issues": [
    "AC count was 4, corrected to 6",
    "Referenced non-existent 'ValidationService', corrected to 'SdlcValidationService'"
  ],
  "corrected_plan": {
    "summary": "...",
    "key_sections": [...],
    "acceptance_criteria_count": 6,
    "technical_considerations": [...]
  },
  "verification_checks": {
    "validation_requirements": "pass",
    "technical_components": "pass_with_corrections",
    "architectural_patterns": "pass",
    "conflict_check": "pass",
    "scope_check": "pass"
  }
}
```

---

## Phase 4: EXECUTE
**Goal:** Generate the final PRD artifact based on the verified plan

### Questions to Answer

#### Q4.1: What's the complete context for this PRD?
- **Question:** What's the full vision, technical details, and examples needed?
- **Context Needed:**
  - Complete vision documents
  - Full PRD examples
  - Detailed technical specs
- **Context Menu Keys:**
  - `fetch:vision:vision:master_control_plan` (full MCP.md)
  - `fetch:sdlc:static:product_reqs` (PRODUCT_REQUIREMENTS.md)
  - `fetch:sdlc:on_demand:prds` (load 2 full PRD examples)
  - `fetch:structural:data_layer:schema` (complete schema)

#### Q4.2: What specific models/services should be referenced?
- **Question:** What are the exact file paths, class names, and method signatures?
- **Context Needed:**
  - Full model code
  - Full service code
  - Route definitions
- **Context Menu Keys:**
  - `fetch:structural:data_layer:core_models:artifact.rb` (full file)
  - `fetch:structural:service_layer:ai_services:sap_agent.rb` (full file)
  - `fetch:structural:interface_layer:routing:routes.rb` (full file)

#### Q4.3: What test patterns should be recommended?
- **Question:** What testing approach fits this feature? What are examples?
- **Context Needed:**
  - Existing test files
  - Test patterns
  - Coverage expectations
- **Context Menu Keys:**
  - `fetch:structural:on_demand:tests` (existing test examples)
  - `search:sdlc:on_demand:tests integration` (integration test patterns)

#### Q4.4: What's the exact workflow for implementation?
- **Question:** What's the step-by-step process for a developer/agent?
- **Context Needed:**
  - Git workflow
  - Branch naming
  - Commit patterns
- **Context Menu Keys:**
  - `fetch:sdlc:static:ai_thinking` (workflow guidelines)
  - `fetch:sdlc:on_demand:repo_meta` (git conventions)

#### Q4.5: How should this be documented?
- **Question:** What format, what level of detail, what examples?
- **Context Needed:**
  - PRD template
  - Writing style from examples
  - Required sections
- **Context Menu Keys:**
  - `fetch:sdlc:static:prd_templates` (format guidelines)
  - `fetch:sdlc:on_demand:prds` (style examples)

### Execution Phase Output
```markdown
## 0071-agentic-prd-generation-PRD.md

#### Overview
[Full prose description based on plan and context]

#### Acceptance Criteria
- [Criterion 1 based on plan]
- [Criterion 2 based on plan]
- [Criterion 3 based on plan]
- [Criterion 4 based on plan]
- [Criterion 5 based on plan]
- [Criterion 6 based on plan]

#### Architectural Context
[Detailed technical description referencing actual models, services, routes]

#### Test Cases
[Specific test scenarios based on AC and technical considerations]

#### Workflow
[Step-by-step implementation guide]
```

---

## Phase 5: VALIDATE
**Goal:** Perform final structural and quality checks

### Questions to Answer

#### Q5.1: Does the PRD pass structural validation?
- **Question:** Are all required sections present? Is AC count correct?
- **Context Needed:**
  - Validation rules
  - Generated PRD content
- **Context Menu Keys:**
  - `fetch:structural:service_layer:ai_services:prd_strategy` (validation logic)
  - (No external context needed - validates against generated content)

#### Q5.2: Are all technical references valid?
- **Question:** Do all mentioned files, classes, tables actually exist?
- **Context Needed:**
  - Schema verification
  - File existence checks
- **Context Menu Keys:**
  - `fetch:structural:data_layer:schema` (verify table names)
  - `fetch:structural:service_layer` (verify service names)
  - `fetch:structural:interface_layer:routing` (verify route names)

#### Q5.3: Is the PRD internally consistent?
- **Question:** Do sections align? Do AC match test cases?
- **Context Needed:**
  - Generated PRD content only
- **Context Menu Keys:**
  - (No external context - internal consistency check)

#### Q5.4: Does it follow the approved plan?
- **Question:** Did execution drift from the verified plan?
- **Context Needed:**
  - Verified plan from Phase 3
  - Generated PRD
- **Context Menu Keys:**
  - (No external context - compare plan to output)

#### Q5.5: Where should this PRD be stored?
- **Question:** What's the correct file path and naming?
- **Context Needed:**
  - Storage conventions
  - Epic structure
- **Context Menu Keys:**
  - `fetch:sdlc:on_demand:repo_meta` (directory structure)
  - `fetch:vision:roadmap` (epic organization)

### Validation Phase Output
```json
{
  "validation_result": "pass|fail",
  "checks": {
    "structural": "pass",
    "technical_references": "pass",
    "internal_consistency": "pass",
    "plan_adherence": "pass",
    "storage_path": "knowledge_base/epics/agentic-refactor/0071-agentic-prd-generation-PRD.md"
  },
  "errors": [],
  "warnings": [
    "AC count is 6, which is on the lower end of the 5-8 range"
  ],
  "stored_at": "knowledge_base/epics/agentic-refactor/0071-agentic-prd-generation-PRD.md"
}
```

---

## Context Menu Query Summary by Phase

### Research Phase (Lightweight - Summaries Only)
```
fetch:sdlc:semi_static:artifact_summary
fetch:functional:*
fetch:vision:roadmap:completed
fetch:vision:roadmap:in_progress
fetch:vision:vision:master_control_plan
fetch:vision:priorities:sdlc_focus
fetch:structural:data_layer (summary)
fetch:structural:service_layer (summary)
search:functional:* (keyword)
search:sdlc:on_demand:prds (keyword)
```

### Planning Phase (Detailed - Summaries + Key Details)
```
fetch:sdlc:static:prd_templates
fetch:sdlc:on_demand:prds (2-3 examples)
fetch:structural:data_layer:schema (full)
fetch:structural:data_layer:core_models (summaries)
fetch:structural:service_layer:ai_services (summaries)
fetch:sdlc:static:ai_thinking
fetch:vision:technical_debt
fetch:vision:roadmap:in_progress
search:structural:prd_strategy
search:cross_references
```

### Verification Phase (Constraints - Rules + Patterns)
```
fetch:structural:service_layer:ai_services:prd_strategy (full)
fetch:structural:data_layer:schema (full)
fetch:structural:service_layer (patterns)
fetch:vision:roadmap:in_progress
fetch:sdlc:semi_static:artifact_summary
search:structural:command
search:structural:strategy
search:sdlc:on_demand:prds (comparison)
```

### Execution Phase (Full - Everything Needed)
```
fetch:vision:vision:master_control_plan (full)
fetch:sdlc:static:product_reqs (full)
fetch:sdlc:static:prd_templates (full)
fetch:sdlc:on_demand:prds (2 full examples)
fetch:structural:data_layer:schema (full)
fetch:structural:data_layer:core_models:artifact.rb (full)
fetch:structural:service_layer:ai_services:sap_agent.rb (full)
fetch:structural:interface_layer:routing:routes.rb (full)
fetch:structural:on_demand:tests (examples)
fetch:sdlc:static:ai_thinking (full)
```

### Validation Phase (Minimal - Verification Only)
```
fetch:structural:service_layer:ai_services:prd_strategy (validation rules)
fetch:structural:data_layer:schema (verify references)
fetch:sdlc:on_demand:repo_meta (storage conventions)
```

---

## Token Budget Estimates

| Phase | Context Size | Estimated Tokens | Notes |
|-------|-------------|------------------|-------|
| Research | Summaries only | 500-1000 | High-level overview |
| Plan | Summaries + details | 2000-3000 | Focused context |
| Verify | Rules + patterns | 1500-2500 | Constraint checking |
| Execute | Full context | 6000-8000 | Complete information |
| Validate | Minimal | 500-1000 | Verification only |
| **Total** | **Progressive** | **10,500-15,500** | Across all phases |

**Comparison to Current Approach:**
- Current (single-shot): ~4000 tokens (truncated), 3 retries = ~12,000 tokens
- Agentic (5-phase): ~10,500-15,500 tokens, but higher quality, fewer retries

---

## Implementation Notes

### Context Menu Query Syntax
```ruby
# Fetch specific path
context = provider.fetch("sdlc:static:prd_templates")

# Search with keyword
results = provider.search("functional:*", query: "plaid")

# Get summary vs full
summary = provider.fetch("structural:data_layer", depth: :summary)
full = provider.fetch("structural:data_layer:schema", depth: :full)

# Cross-reference lookup
related = provider.cross_reference("prd_generation")
```

### Phase-Specific Context Loading
```ruby
def research_phase
  queries = [
    "fetch:sdlc:semi_static:artifact_summary",
    "fetch:vision:priorities:sdlc_focus",
    "fetch:structural:data_layer:summary"
  ]
  
  context = queries.map { |q| provider.query(q, depth: :summary) }
  context.reduce({}, :merge)
end
```

### Caching Strategy
- **Static context**: Cache indefinitely (prd_templates, ai_thinking)
- **Semi-static context**: Cache for 24 hours (artifact_summary, backlog_items)
- **On-demand context**: No caching (schema, commits, models)

---

## Future Enhancements

1. **Dynamic Query Selection**: Let the agent choose which context to fetch based on the request
2. **Semantic Search**: Add vector embeddings for better keyword matching
3. **Context Ranking**: Score and rank context by relevance
4. **Incremental Loading**: Start with summaries, drill down only if needed
5. **Context Pruning**: Remove irrelevant sections before sending to LLM
6. **Multi-Modal Context**: Include diagrams, screenshots, or code diffs
