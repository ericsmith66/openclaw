### Refined Multi-Index RAG Architecture for Agentic Systems

Your examples show a sophisticated understanding of context organization. Let me refine the approach by analyzing what you've built and comparing it to industry patterns for **multi-index retrieval systems**.

---

## Analysis of Your Current Indexes

### **Index 1: SDLC/Financial Planning (Domain-Oriented)**
- **Structure**: Domain → Freshness → Category → Leaf
- **Strength**: Clear separation of concerns (SDLC vs Financial)
- **Freshness tiers**: Static → Semi-Static → On-Demand (brilliant!)
- **Query pattern**: `fetch:domain:freshness:category`

### **Index 2: Routes Dictionary (Function-Oriented)**
- **Structure**: Functional grouping → Endpoints
- **Strength**: Shows "what the app does" (auth, plaid, admin, agents)
- **Includes orphans**: 🛑 markers for incomplete/broken routes
- **Query pattern**: Hierarchical navigation by function

### **Your Insight**: Need multiple index types
1. **Functional**: What the app does (capabilities, features)
2. **Structural**: How the app is built (code organization, architecture)
3. **Vision/Roadmap**: Where the app is going (priorities, planned features)

---

## Industry Pattern: Multi-Index Retrieval Systems

### **Pattern: Faceted Search (Elasticsearch/Algolia style)**

Multiple indexes for the same content, each optimized for different query types:

```
Content: "User Authentication System"

Index 1 (Functional): 
  - Category: Security → Authentication → User Login
  
Index 2 (Structural):
  - Category: Backend → Controllers → Devise Integration
  
Index 3 (Temporal):
  - Category: Completed → Q4 2025 → Authentication Epic
```

**Used by**: Stripe Docs (API Reference + Guides + Recipes), Shopify Dev Docs

---

### **Pattern: Multi-Modal Knowledge Graph (Notion/Obsidian style)**

Different "views" of the same knowledge base:

```
Node: "Artifact Model"

Functional View:
  - Enables: PRD workflow, phase transitions, agent handoffs
  
Structural View:
  - Location: app/models/artifact.rb
  - Dependencies: SapRun, User, Persona
  - Database: artifacts table (schema.rb)
  
Roadmap View:
  - Status: Completed (PRD-AH-011)
  - Next: Add validation scoring (PRD-AH-012E)
```

**Used by**: Notion databases, Obsidian graph view, Roam Research

---

### **Pattern: Layered Context (Anthropic's approach)**

Different context layers for different reasoning depths:

```
Layer 1 (Surface): What exists
  - "The app has Plaid integration for financial data sync"
  
Layer 2 (Structure): How it works
  - "PlaidService calls /link/token, exchanges public_token, stores in plaid_items"
  
Layer 3 (Intent): Why it exists
  - "Enables HNW users to see consolidated net worth for financial planning"
```

**Used by**: Claude Projects, GitHub Copilot Workspace

---

## Recommended Multi-Index Architecture

### **Core Concept: 3 Complementary Indexes + Cross-References**

```ruby
# Each index is a different "lens" on the same codebase
module SapAgent
  module RagContext
    class MultiIndexProvider
      def initialize
        @functional_index = FunctionalIndex.new
        @structural_index = StructuralIndex.new
        @vision_index = VisionIndex.new
        @cross_refs = CrossReferenceMap.new
      end
      
      # Query across all indexes
      def query(query_string, phase: :research)
        results = {
          functional: @functional_index.search(query_string, depth: phase_depth(phase)),
          structural: @structural_index.search(query_string, depth: phase_depth(phase)),
          vision: @vision_index.search(query_string, depth: phase_depth(phase))
        }
        
        # Enrich with cross-references
        @cross_refs.enrich(results)
      end
      
      private
      
      def phase_depth(phase)
        case phase
        when :research then :summary  # High-level only
        when :plan then :detailed     # Include structure
        when :verify then :constraints # Rules and patterns
        when :execute then :full       # Everything
        end
      end
    end
  end
end
```

---

## Index 1: Functional Index (What the App Does)

**Purpose**: Organize by capabilities and user-facing features

```yaml
# knowledge_base/indexes/functional_index.yml
functional_index:
  summary: "Application capabilities organized by user-facing features"
  
  capabilities:
    - name: "authentication"
      summary: "User login, signup, session management"
      features:
        - name: "user_login"
          routes: ["/users/sign_in", "/users/sign_out"]
          models: ["User"]
          services: ["Devise"]
          status: "production"
          prd: null
        
        - name: "oauth_flow"
          routes: ["/plaid_oauth/initiate", "/plaid_oauth/callback"]
          models: []
          services: []
          status: "incomplete"  # 🛑 orphan
          prd: null
    
    - name: "financial_sync"
      summary: "Plaid integration for account/transaction sync"
      features:
        - name: "plaid_link"
          routes: ["/plaid/link_token", "/plaid/exchange"]
          models: ["PlaidItem", "Account"]
          services: ["PlaidService"]
          status: "production"
          prd: "PRD-PLAID-001"
        
        - name: "holdings_sync"
          routes: ["/mission_control/sync_holdings_now"]
          models: ["Holding"]
          jobs: ["SyncHoldingsJob"]
          status: "production"
          prd: "PRD-PLAID-002"
    
    - name: "agent_orchestration"
      summary: "AI agent workflows for PRD generation and development"
      features:
        - name: "prd_generation"
          routes: ["/agent_hub", "/admin/sap_collaborate"]
          models: ["Artifact", "SapRun"]
          services: ["SapAgent", "AiFinancialAdvisor"]
          status: "production"
          prd: "PRD-AH-011"
        
        - name: "agent_monitoring"
          routes: ["/agents/monitor"]
          models: ["SapRun", "SapMessage"]
          services: ["SapAgent::Router"]
          status: "in_development"
          prd: "PRD-AH-012E"
    
    - name: "admin_tools"
      summary: "Owner-only controls for system management"
      features:
        - name: "mission_control"
          routes: ["/mission_control", "/mission_control/nuke"]
          models: ["PlaidItem", "Account", "Holding"]
          services: ["PlaidService", "MissionControlService"]
          status: "production"
          prd: null
        
        - name: "rag_inspector"
          routes: ["/admin/rag_inspector"]
          models: []
          services: ["RagProvider"]
          status: "production"
          prd: "PRD-AH-011D"

# Query examples:
# - "fetch:functional:financial_sync" → Returns all sync features
# - "fetch:functional:agent_orchestration:prd_generation" → Specific feature details
# - "search:functional:plaid" → All features mentioning Plaid
```

---

## Index 2: Structural Index (How the App is Built)

**Purpose**: Organize by code architecture and technical layers

```yaml
# knowledge_base/indexes/structural_index.yml
structural_index:
  summary: "Application architecture organized by technical layers"
  
  layers:
    - name: "data_layer"
      summary: "Database schema, models, migrations"
      components:
        - name: "core_models"
          files:
            - path: "app/models/user.rb"
              summary: "User authentication and profile"
              tables: ["users"]
              associations: ["has_many :plaid_items", "has_many :snapshots"]
            
            - path: "app/models/artifact.rb"
              summary: "Agent workflow artifacts (PRDs, plans)"
              tables: ["artifacts"]
              associations: ["belongs_to :user", "has_many :sap_runs"]
              state_machine: true
              phases: ["backlog", "in_analysis", "in_development", "completed"]
        
        - name: "plaid_models"
          files:
            - path: "app/models/plaid_item.rb"
              summary: "Plaid connection tokens"
              tables: ["plaid_items"]
              encrypted_fields: ["access_token"]
            
            - path: "app/models/account.rb"
              summary: "Financial accounts from Plaid"
              tables: ["accounts"]
              associations: ["belongs_to :plaid_item", "has_many :holdings"]
        
        - name: "schema"
          files:
            - path: "db/schema.rb"
              summary: "Complete database schema"
              tables: ["users", "plaid_items", "accounts", "holdings", "transactions", 
                       "artifacts", "sap_runs", "sap_messages", "snapshots"]
    
    - name: "service_layer"
      summary: "Business logic and external integrations"
      components:
        - name: "ai_services"
          files:
            - path: "app/services/ai_financial_advisor.rb"
              summary: "LLM proxy (Grok/Ollama routing)"
              dependencies: ["SmartProxy", "SapAgent::Router"]
            
            - path: "app/services/sap_agent.rb"
              summary: "Main SAP agent orchestration"
              dependencies: ["RagProvider", "Command pattern"]
            
            - path: "app/services/sap_agent/rag_provider.rb"
              summary: "Context gathering for LLM calls"
              dependencies: ["Snapshot", "context_map.md"]
        
        - name: "plaid_services"
          files:
            - path: "app/services/plaid_service.rb"
              summary: "Plaid API integration"
              endpoints: ["/link/token/create", "/item/public_token/exchange"]
    
    - name: "job_layer"
      summary: "Background jobs and scheduled tasks"
      components:
        - name: "sync_jobs"
          files:
            - path: "app/jobs/sync_holdings_job.rb"
              summary: "Fetch holdings from Plaid"
              schedule: "daily"
            
            - path: "app/jobs/financial_snapshot_job.rb"
              summary: "Generate daily user financial snapshot"
              schedule: "daily"
              outputs: ["storage/snapshots/*.json"]
        
        - name: "agent_jobs"
          files:
            - path: "app/jobs/sap_agent_job.rb"
              summary: "Async SAP agent execution"
              queue: "default"
    
    - name: "interface_layer"
      summary: "Controllers, views, routes"
      components:
        - name: "api_controllers"
          files:
            - path: "app/controllers/plaid_controller.rb"
              summary: "Plaid Link integration endpoints"
              routes: ["/plaid/link_token", "/plaid/exchange"]
            
            - path: "app/controllers/agent_hubs_controller.rb"
              summary: "Agent Hub real-time interface"
              routes: ["/agent_hub", "/agent_hub/messages/:agent_id"]
        
        - name: "admin_controllers"
          files:
            - path: "app/controllers/mission_control_controller.rb"
              summary: "Owner admin panel"
              routes: ["/mission_control/*"]
            
            - path: "app/controllers/admin/sap_collaborate_controller.rb"
              summary: "SAP agent collaboration interface"
              routes: ["/admin/sap_collaborate"]
    
    - name: "configuration_layer"
      summary: "Config files, routes, environment"
      components:
        - name: "routing"
          files:
            - path: "config/routes.rb"
              summary: "Application routes"
              namespaces: ["admin", "agents"]
        
        - name: "agent_prompts"
          files:
            - path: "config/agent_prompts/sap_system.md"
              summary: "SAP agent system prompt"

# Query examples:
# - "fetch:structural:data_layer:core_models" → User, Artifact models
# - "fetch:structural:service_layer:ai_services" → All AI-related services
# - "search:structural:plaid" → All Plaid-related components across layers
```

---

## Index 3: Vision/Roadmap Index (Where the App is Going)

**Purpose**: Organize by strategic priorities and development timeline

```yaml
# knowledge_base/indexes/vision_index.yml
vision_index:
  summary: "Product vision, roadmap, and strategic priorities"
  
  vision:
    - name: "master_control_plan"
      file: "knowledge_base/static_docs/MCP.md"
      summary: "Overall product vision: HNW financial planning with AI agents"
      themes:
        - "Shirtsleeves to shirtsleeves prevention"
        - "CFP-like curriculum for wealth preservation"
        - "AI-assisted SDLC for rapid feature development"
  
  roadmap:
    - phase: "completed"
      summary: "Production features"
      epics:
        - name: "plaid_integration"
          prds: ["PRD-PLAID-001", "PRD-PLAID-002"]
          features: ["Plaid Link", "Holdings sync", "Transaction sync"]
          completion_date: "2025-Q4"
        
        - name: "sap_agent_v1"
          prds: ["PRD-AH-011", "PRD-0120-RAG"]
          features: ["PRD generation", "Basic RAG", "Artifact workflow"]
          completion_date: "2026-Q1"
    
    - phase: "in_progress"
      summary: "Current development focus"
      epics:
        - name: "agentic_refactor"
          prd: "0070-SAP-Agentic-Refactor-Epic.md"
          features: ["Planning phase", "Pluggable RAG", "Proactive verification"]
          target_date: "2026-Q1"
          priority: "high"
          blockers: []
        
        - name: "sdlc_validation"
          prds: ["PRD-AH-012E"]
          features: ["Validation scoring", "Quality metrics", "Agent monitoring"]
          target_date: "2026-Q1"
          priority: "high"
          blockers: []
    
    - phase: "planned"
      summary: "Backlog and future work"
      epics:
        - name: "financial_planning_curriculum"
          prds: []
          features: ["Estate tax simulations", "Monte Carlo projections", "Trust planning"]
          target_date: "2026-Q2"
          priority: "medium"
          dependencies: ["Agent Hub maturity"]
        
        - name: "oauth_completion"
          prds: []
          features: ["Complete OAuth flow", "Fix orphan routes"]
          target_date: "TBD"
          priority: "low"
          blockers: ["🛑 No controller specified"]
  
  priorities:
    - name: "sdlc_focus"
      summary: "Agent Hub maturity before financial sims"
      rationale: "Need stable agent workflows before complex financial features"
      current_focus:
        - "Agentic PRD generation"
        - "Multi-index RAG"
        - "Validation scoring"
    
    - name: "quality_over_speed"
      summary: "High-quality PRDs reduce downstream bugs"
      metrics:
        - "PRD validation pass rate: 70% → 90%"
        - "First-time execution success: 40% → 70%"
  
  technical_debt:
    - name: "orphan_routes"
      items:
        - "/plaid_oauth/initiate (no controller)"
        - "/plaid_oauth/callback (no controller)"
      priority: "low"
      impact: "OAuth flow incomplete"
    
    - name: "rag_scalability"
      items:
        - "4K char truncation too aggressive"
        - "No vector DB for semantic search"
      priority: "medium"
      impact: "Context quality degrades with project growth"

# Query examples:
# - "fetch:vision:roadmap:in_progress" → Current epics
# - "fetch:vision:priorities:sdlc_focus" → Why we're focusing on agents
# - "search:vision:validation" → All roadmap items related to validation
```

---

## Cross-Reference Map (Linking Indexes)

**Purpose**: Connect related concepts across indexes

```yaml
# knowledge_base/indexes/cross_references.yml
cross_references:
  
  # Example: PRD Generation feature
  - id: "prd_generation"
    functional:
      path: "functional:agent_orchestration:prd_generation"
      summary: "User-facing PRD generation capability"
    structural:
      paths:
        - "structural:service_layer:ai_services:sap_agent.rb"
        - "structural:data_layer:core_models:artifact.rb"
        - "structural:interface_layer:admin_controllers:sap_collaborate"
      summary: "Implementation across service, data, and interface layers"
    vision:
      paths:
        - "vision:roadmap:completed:sap_agent_v1"
        - "vision:roadmap:in_progress:agentic_refactor"
      summary: "V1 completed, V2 (agentic) in progress"
  
  # Example: Plaid Integration
  - id: "plaid_sync"
    functional:
      path: "functional:financial_sync"
      summary: "All Plaid sync features"
    structural:
      paths:
        - "structural:data_layer:plaid_models"
        - "structural:service_layer:plaid_services"
        - "structural:job_layer:sync_jobs"
      summary: "Models, services, and background jobs"
    vision:
      paths:
        - "vision:roadmap:completed:plaid_integration"
      summary: "Production-ready, no active work"
  
  # Example: Validation Scoring
  - id: "validation_scoring"
    functional:
      path: "functional:agent_orchestration:agent_monitoring"
      summary: "Quality metrics for agent outputs"
    structural:
      paths:
        - "structural:service_layer:ai_services:sdlc_validation_service.rb"
        - "structural:job_layer:agent_jobs:sdlc_validation_job.rb"
      summary: "Service + background job"
    vision:
      paths:
        - "vision:roadmap:in_progress:sdlc_validation"
        - "vision:priorities:quality_over_speed"
      summary: "High priority, aligns with quality focus"
```

---

## Query Patterns for Agentic Phases

### **Research Phase: High-Level Overview**

```ruby
def research_phase
  provider = MultiIndexProvider.new
  
  # Get summaries from all indexes
  {
    functional_capabilities: provider.functional_index.list_capabilities,
    structural_layers: provider.structural_index.list_layers,
    current_priorities: provider.vision_index.get_priorities,
    in_progress_epics: provider.vision_index.get_roadmap(phase: :in_progress)
  }
end

# Returns:
# {
#   functional_capabilities: ["authentication", "financial_sync", "agent_orchestration", ...],
#   structural_layers: ["data_layer", "service_layer", "job_layer", ...],
#   current_priorities: ["sdlc_focus", "quality_over_speed"],
#   in_progress_epics: ["agentic_refactor", "sdlc_validation"]
# }
```

### **Planning Phase: Structural + Vision Context**

```ruby
def planning_phase(research_context)
  provider = MultiIndexProvider.new
  query = payload[:query]  # e.g., "Add validation scoring to PRD generation"
  
  # Search across indexes
  functional_matches = provider.functional_index.search(query)
  structural_matches = provider.structural_index.search(query)
  vision_matches = provider.vision_index.search(query)
  
  # Get cross-references
  cross_refs = provider.cross_refs.find_related([
    functional_matches.first[:id],
    vision_matches.first[:id]
  ])
  
  context = {
    related_features: functional_matches,
    existing_code: structural_matches,
    roadmap_context: vision_matches,
    dependencies: cross_refs
  }
  
  # Build planning prompt with focused context
  planning_prompt = build_planning_prompt(context)
  call_llm(planning_prompt)
end
```

### **Verification Phase: Constraints from All Indexes**

```ruby
def verification_phase(plan, research_context)
  provider = MultiIndexProvider.new
  
  # Check against existing patterns (structural)
  existing_patterns = provider.structural_index.get_patterns(
    layer: "service_layer",
    component: "ai_services"
  )
  
  # Check against roadmap priorities (vision)
  priorities = provider.vision_index.get_priorities
  
  # Check against functional requirements
  related_features = provider.functional_index.search(plan[:summary])
  
  issues = []
  
  # Verify plan aligns with priorities
  if plan[:epic] && !priorities[:sdlc_focus][:current_focus].include?(plan[:epic])
    issues << "Plan doesn't align with current SDLC focus"
  end
  
  # Verify plan follows existing patterns
  if plan[:new_service] && !follows_pattern?(plan[:new_service], existing_patterns)
    issues << "Service structure doesn't match existing patterns"
  end
  
  {
    status: issues.any? ? 'needs_review' : 'approved',
    issues: issues,
    corrected_plan: auto_correct(plan, existing_patterns, priorities)
  }
end
```

### **Execution Phase: Full Context from Relevant Index Paths**

```ruby
def execution_phase(verified_plan, research_context)
  provider = MultiIndexProvider.new
  plan = verified_plan[:corrected_plan]
  
  # Load full content for relevant paths
  context = {}
  
  # If plan involves a specific feature, load its full context
  if plan[:feature_id]
    cross_ref = provider.cross_refs.get(plan[:feature_id])
    
    # Load functional details
    context[:functional] = provider.functional_index.load_full(cross_ref[:functional][:path])
    
    # Load structural code
    context[:structural] = cross_ref[:structural][:paths].map do |path|
      provider.structural_index.load_full(path)
    end
    
    # Load vision context
    context[:vision] = cross_ref[:vision][:paths].map do |path|
      provider.vision_index.load_full(path)
    end
  end
  
  # Build execution prompt with complete context
  execution_prompt = build_execution_prompt(plan, context)
  call_llm(execution_prompt)
end
```

---

## POC Implementation Plan

### **Phase 1: Build Static Indexes (1-2 days)**

```bash
# 1. Create index files
knowledge_base/indexes/
├── functional_index.yml
├── structural_index.yml
├── vision_index.yml
└── cross_references.yml

# 2. Populate with current state (manual curation)
# - Functional: Extract from routes.rb + feature list
# - Structural: Extract from app/ directory structure
# - Vision: Extract from MCP.md + epic files

# 3. Create simple loader
app/services/sap_agent/rag_context/
├── multi_index_provider.rb
├── functional_index.rb
├── structural_index.rb
├── vision_index.rb
└── cross_reference_map.rb
```

### **Phase 2: Integrate with Agentic Command (1 day)**

```ruby
# Update AgenticPrdCommand to use multi-index
def research_phase
  @provider = MultiIndexProvider.new
  @provider.query(payload[:query], phase: :research)
end

def planning_phase(research_context)
  context = @provider.query(payload[:query], phase: :plan)
  # ... use context in planning prompt
end
```

### **Phase 3: Add Dynamic Components (2-3 days)**

```ruby
# Add semi-static updates (daily jobs)
class UpdateArtifactSummaryJob < ApplicationJob
  def perform
    summary = Artifact.recent.map { |a| a.to_summary }
    File.write(
      Rails.root.join('knowledge_base/indexes/semi_static/artifact_summary.json'),
      summary.to_json
    )
  end
end

# Add on-demand fetchers
class OnDemandFetcher
  def fetch_schema
    File.read(Rails.root.join('db/schema.rb'))
  end
  
  def fetch_commit(sha)
    `git show #{sha}`
  end
end
```

---

## Key Recommendations

### **✅ Your Approach is Excellent:**
1. **Multi-index design** matches industry best practices (Stripe, Notion, Anthropic)
2. **Freshness tiers** (static/semi-static/on-demand) are brilliant
3. **Cross-references** enable rich context without duplication
4. **Dot-notation queries** are clean and intuitive

### **🔧 Refinements:**
1. **Separate indexes into files** (not one giant tree) for maintainability
2. **Add cross-reference map** to link related concepts across indexes
3. **Phase-specific depth** (summary → detailed → full) for token efficiency
4. **Auto-generate where possible** (structural index from code, vision from PRDs)

### **📊 Success Metrics:**
- Research phase: <1K tokens (summaries only)
- Planning phase: <3K tokens (summaries + key details)
- Execution phase: <8K tokens (full context for relevant paths)
- Index query time: <50ms per index
- Cross-reference resolution: <20ms

---

## Next Steps

1. **Validate index structure**: Do these 3 indexes cover your needs?
2. **Prioritize index population**: Which index to build first? (Recommend: Functional → Structural → Vision)
3. **Choose format**: YAML, JSON, or database? (Recommend: YAML for POC, DB for production)
4. **Define auto-generation**: What can be extracted automatically vs manually curated?
5. **Test query patterns**: Mock a few queries to validate the approach

Would you like me to generate the initial YAML files for these indexes based on your current codebase?