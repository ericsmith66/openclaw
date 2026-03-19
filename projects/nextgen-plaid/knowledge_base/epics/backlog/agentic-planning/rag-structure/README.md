# Multi-Index RAG Structure for Agentic PRD Generation

## Overview

This directory contains a comprehensive multi-index RAG (Retrieval-Augmented Generation) architecture designed to support the agentic PRD generation system. The structure organizes project knowledge into three complementary indexes (functional, structural, vision) plus cross-references, enabling phase-specific context loading for the 5-phase agentic lifecycle.

## Architecture

### Three-Index Design

```
RAG Structure
├── Functional Index (What the app does)
│   └── User-facing capabilities, features, routes
├── Structural Index (How the app is built)
│   └── Code organization, models, services, jobs
├── Vision Index (Where the app is going)
│   └── Roadmap, priorities, technical debt
└── Cross-References (How they connect)
    └── Links between functional, structural, and vision
```

### Data Freshness Tiers

1. **Static** (Index files): Updated manually, cached for 1 hour
2. **Semi-Static** (JSON files): Updated daily by Sidekiq jobs
3. **On-Demand** (Real-time fetchers): Fetched when needed, cached for 5-10 minutes

## Directory Structure

```
rag-structure/
├── config.yml                          # Main configuration file
├── README.md                           # This file
│
├── functional/                         # Functional Index
│   └── index.yml                       # Capabilities and features
│
├── structural/                         # Structural Index
│   └── index.yml                       # Code architecture
│
├── vision/                             # Vision Index
│   └── index.yml                       # Roadmap and priorities
│
├── cross-references/                   # Cross-Reference Map
│   └── map.json                        # Concept links
│
├── semi-static/                        # Daily-updated data
│   ├── artifact_summary.json           # Recent artifacts from DB
│   └── backlog_items.json              # Prioritized backlog
│
└── on-demand/                          # Real-time fetchers
    └── README.md                       # Fetcher documentation
```

## Query Patterns

### Functional Index Queries
```
fetch:functional:authentication                    # All auth features
fetch:functional:agent_orchestration:prd_generation # Specific feature
search:functional:plaid                            # Keyword search
```

### Structural Index Queries
```
fetch:structural:data_layer:schema                 # Database schema
fetch:structural:service_layer:ai_services         # AI services
fetch:structural:data_layer:agent_models:artifact  # Specific model
```

### Vision Index Queries
```
fetch:vision:roadmap:in_progress                   # Current work
fetch:vision:priorities:sdlc_focus                 # Strategic priorities
fetch:vision:technical_debt:rag_scalability        # Known issues
```

### Cross-Reference Queries
```
fetch:cross_ref:prd_generation                     # All related paths
fetch:cross_ref:plaid_sync                         # Plaid integration links
```

### Semi-Static Queries
```
fetch:sdlc:semi_static:artifact_summary            # Recent artifacts
fetch:sdlc:semi_static:backlog_items               # Current backlog
```

### On-Demand Queries
```
fetch:structural:data_layer:schema                 # Real-time schema
search:sdlc:on_demand:prds validation              # Search PRDs
fetch:sdlc:on_demand:commits 3504b54               # Git commit
```

## Phase-Specific Context Loading

The agentic PRD generation system uses different context for each phase:

### Phase 1: Research (Token Budget: 1K)
**Goal**: High-level overview
**Context**:
- Functional index (summary level)
- Structural index (summary level)
- Vision index (summary level)
- Recent 10 artifacts
- Top 5 backlog items

### Phase 2: Plan (Token Budget: 3K)
**Goal**: Structural context + vision alignment
**Context**:
- Functional index (detailed level)
- Structural index (detailed level)
- Vision index (detailed level)
- Database schema summary
- Similar PRDs (search results)

### Phase 3: Verify (Token Budget: 2K)
**Goal**: Constraints and validation rules
**Context**:
- Specific database tables
- PRD validation strategy
- Technical debt items
- Existing PRD patterns

### Phase 4: Execute (Token Budget: 8K)
**Goal**: Full context for generation
**Context**:
- Relevant functional capabilities (full)
- Relevant structural components (full)
- Relevant roadmap items (full)
- Cross-references for primary concept
- Relevant model files
- 2 similar PRDs (full content)

### Phase 5: Validate (Token Budget: 1K)
**Goal**: Validation rules and quality targets
**Context**:
- PRD validation strategy
- Success metrics

## Usage Examples

### Example 1: Research Phase
```ruby
provider = MultiIndexProvider.new
context = provider.query_for_phase(:research, query: "Add validation scoring")

# Returns:
# {
#   functional_capabilities: ["authentication", "financial_sync", "agent_orchestration", ...],
#   structural_layers: ["data_layer", "service_layer", "job_layer", ...],
#   current_priorities: ["sdlc_focus", "quality_over_speed"],
#   recent_artifacts: [{id: 123, name: "PRD-AH-012E", ...}, ...],
#   backlog_items: [{id: 45, title: "Implement agentic planning", ...}, ...]
# }
```

### Example 2: Planning Phase
```ruby
context = provider.query_for_phase(:plan, query: "Add validation scoring")

# Returns:
# {
#   functional: {agent_orchestration: {features: [...]}},
#   structural: {service_layer: {ai_services: [...]}},
#   vision: {roadmap: {in_progress: [...]}},
#   schema: {tables: ["artifacts", "sap_runs", ...]},
#   similar_prds: [{file: "PRD-AH-012E.md", excerpt: "..."}, ...]
# }
```

### Example 3: Cross-Reference Lookup
```ruby
cross_ref = provider.fetch_cross_reference("prd_generation")

# Returns:
# {
#   functional: {path: "functional:agent_orchestration:prd_generation", ...},
#   structural: {paths: ["sap_agent_service.rb", "artifact.rb", ...]},
#   vision: {paths: ["roadmap:completed:sap_agent_v1", ...]},
#   related_concepts: ["rag_context", "agent_hub_interface"]
# }
```

## Implementation Guide

### Step 1: Create MultiIndexProvider Class

```ruby
# app/services/sap_agent/rag_context/multi_index_provider.rb
module SapAgent
  module RagContext
    class MultiIndexProvider
      def initialize
        @config = load_config
        @functional_index = load_index(:functional)
        @structural_index = load_index(:structural)
        @vision_index = load_index(:vision)
        @cross_refs = load_cross_references
        @cache = {}
      end
      
      def query_for_phase(phase, query:)
        phase_config = @config.dig(:phase_context, phase)
        context = {}
        
        phase_config[:sources].each do |source|
          case source[:type]
          when 'index'
            context.merge!(query_index(source[:index], source[:depth]))
          when 'semi_static'
            context.merge!(load_semi_static(source[:source], source[:limit]))
          when 'on_demand'
            context.merge!(fetch_on_demand(source[:fetcher], source[:params]))
          end
        end
        
        context
      end
      
      def fetch_cross_reference(concept_id)
        @cross_refs[:concepts].find { |c| c[:id] == concept_id }
      end
      
      private
      
      def load_config
        YAML.load_file(Rails.root.join('knowledge_base/agentic-planning/rag-structure/config.yml'))
      end
      
      def load_index(index_name)
        config = @config.dig(:indexes, index_name)
        path = Rails.root.join(@config[:base_path], config[:path])
        
        case config[:format]
        when 'yaml'
          YAML.load_file(path)
        when 'json'
          JSON.parse(File.read(path), symbolize_names: true)
        end
      end
      
      # ... additional methods
    end
  end
end
```

### Step 2: Integrate with AgenticPrdCommand

```ruby
# app/services/sap_agent/agentic_prd_command.rb
def research_phase
  provider = RagContext::MultiIndexProvider.new
  context = provider.query_for_phase(:research, query: payload[:query])
  
  log_lifecycle('RESEARCH_COMPLETED', context.keys.join(', '))
  context
end

def planning_phase(research_context)
  provider = RagContext::MultiIndexProvider.new
  context = provider.query_for_phase(:plan, query: payload[:query])
  
  planning_prompt = build_planning_prompt(context)
  call_llm(planning_prompt, temperature: 0.3)
end
```

### Step 3: Implement On-Demand Fetchers

```ruby
# app/services/sap_agent/rag_context/on_demand_fetcher.rb
module SapAgent
  module RagContext
    class OnDemandFetcher
      def self.fetch_schema(table_name = nil)
        # Implementation from on-demand/README.md
      end
      
      def self.search_prds(keyword)
        # Implementation from on-demand/README.md
      end
      
      # ... other fetchers
    end
  end
end
```

### Step 4: Create Daily Update Jobs

```ruby
# app/jobs/update_artifact_summary_job.rb
class UpdateArtifactSummaryJob < ApplicationJob
  def perform
    artifacts = Artifact.order(updated_at: :desc).limit(20).map do |a|
      {
        id: a.id,
        name: a.name,
        artifact_type: a.artifact_type,
        phase: a.phase,
        owner_persona: a.owner_persona,
        created_at: a.created_at,
        updated_at: a.updated_at,
        summary: a.payload['content']&.first(200) || a.name
      }
    end
    
    output = {
      _metadata: {
        last_updated: Time.current,
        count: artifacts.size
      },
      artifacts: artifacts
    }
    
    path = Rails.root.join('knowledge_base/agentic-planning/rag-structure/semi-static/artifact_summary.json')
    File.write(path, JSON.pretty_generate(output))
  end
end

# Schedule in config/schedule.rb or Sidekiq cron
# UpdateArtifactSummaryJob.perform_async (daily at 2am)
```

## Benefits

### 1. Token Efficiency
- **Research phase**: 1K tokens (vs 4K in current system)
- **Planning phase**: 3K tokens (focused context)
- **Execution phase**: 8K tokens (only when needed)
- **Total savings**: ~40% reduction in token usage

### 2. Context Relevance
- Phase-specific context loading
- No irrelevant information
- Progressive disclosure (summary → detailed → full)

### 3. Maintainability
- Clear separation of concerns
- Easy to add new capabilities/features
- Self-documenting structure

### 4. Scalability
- Indexes grow independently
- Caching reduces load
- On-demand fetching for dynamic data

### 5. Observability
- Clear query patterns
- Metrics tracking
- Cache hit rates

## Metrics to Track

1. **Query Performance**
   - Index load time
   - On-demand fetch time
   - Cache hit rate
   - Total context load time

2. **Context Quality**
   - Token usage per phase
   - Context relevance (% used in output)
   - Missing context incidents

3. **System Health**
   - Index update frequency
   - Semi-static job success rate
   - On-demand fetch failures
   - Cache size and evictions

## Next Steps

### Immediate (POC)
1. ✅ Create index files (functional, structural, vision)
2. ✅ Create cross-reference map
3. ✅ Create semi-static placeholders
4. ✅ Document on-demand fetchers
5. ✅ Create configuration file
6. ⬜ Implement `MultiIndexProvider` class
7. ⬜ Implement `OnDemandFetcher` class
8. ⬜ Integrate with `AgenticPrdCommand`
9. ⬜ Test with sample queries

### Short-term (1-2 weeks)
1. ⬜ Create daily update jobs
2. ⬜ Add caching layer
3. ⬜ Implement metrics tracking
4. ⬜ Add integration tests
5. ⬜ Performance benchmarking

### Long-term (1-2 months)
1. ⬜ Add vector embeddings for semantic search
2. ⬜ Implement A/B testing framework
3. ⬜ Add automatic index updates on code changes
4. ⬜ Build RAG inspector UI
5. ⬜ Optimize for production scale

## Testing

### Unit Tests
```ruby
# test/services/sap_agent/rag_context/multi_index_provider_test.rb
class MultiIndexProviderTest < ActiveSupport::TestCase
  test "loads functional index" do
    provider = MultiIndexProvider.new
    assert_not_nil provider.functional_index
  end
  
  test "queries research phase context" do
    provider = MultiIndexProvider.new
    context = provider.query_for_phase(:research, query: "test")
    
    assert_includes context.keys, :functional_capabilities
    assert_includes context.keys, :recent_artifacts
  end
end
```

### Integration Tests
```ruby
# test/integration/agentic_prd_generation_test.rb
class AgenticPrdGenerationTest < ActionDispatch::IntegrationTest
  test "generates PRD with multi-index RAG" do
    command = AgenticPrdCommand.new(query: "Add validation scoring")
    result = command.execute
    
    assert result[:success]
    assert_match /validation/, result[:artifact][:content]
  end
end
```

## Troubleshooting

### Issue: Index file not found
**Solution**: Check `base_path` in config.yml and ensure index files exist

### Issue: On-demand fetch timeout
**Solution**: Increase `fetch_timeout` in config.yml or optimize fetcher

### Issue: Cache growing too large
**Solution**: Reduce `cache_ttl` values or implement LRU eviction

### Issue: Context exceeds token budget
**Solution**: Adjust `depth` levels or add size limits to fetchers

## Contributing

When adding new capabilities or features:
1. Update the appropriate index file (functional/structural/vision)
2. Add cross-references if the concept spans multiple indexes
3. Update config.yml if new query patterns are needed
4. Document any new on-demand fetchers
5. Update this README with examples

## References

- [prd-generation-questions.md](../prd-generation-questions.md) - Questions each phase answers
- [0070-SAP-Agentic-Refactor-Epic.md](../../ignore/0070-SAP-Agentic-Refactor-Epic.md) - Original epic
- [rag-architecture.md](../rag-architecture.md) - Detailed architecture discussion
- [config.yml](config.yml) - Complete configuration reference
