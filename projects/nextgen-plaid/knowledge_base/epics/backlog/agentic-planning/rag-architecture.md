### RAG Architecture for Agentic Systems: Industry Patterns & Recommendations

Let me analyze your tree/branch/cluster idea against proven industry patterns and provide recommendations for your agentic PRD generation system.

---

## Current State Analysis

**Your Current RAG (Phase 1):**
- Simple query-type → document mapping (`context_map.md`)
- Flat concatenation of static docs + user snapshot
- 4K char truncation (oldest-first)
- No hierarchy, no dynamic retrieval

**Your Proposed Idea:**
- Tree structure: branch → cluster → files → leaf (individual file)
- Human-curated initially, moving to static/dynamic hybrid
- Summary at each level

---

## Industry RAG Patterns for Agentic Systems

### **Pattern 1: Hierarchical Summarization (Raptor-style)**

**How it works:**
```
Root Summary (Project Overview)
├── Branch: Backend Context
│   ├── Cluster: Database Schema
│   │   ├── schema.rb (leaf)
│   │   └── migrations/ (leaf)
│   └── Cluster: API Endpoints
│       ├── controllers/ (leaf)
│       └── routes.rb (leaf)
└── Branch: Product Context
    ├── Cluster: PRDs
    │   ├── recent PRDs (leaf)
    │   └── related PRDs (leaf)
    └── Cluster: Vision Docs
        └── MCP.md (leaf)
```

**Retrieval Strategy:**
1. Agent queries at appropriate level (branch/cluster/leaf)
2. Summaries provide "table of contents" for navigation
3. Drill down only when needed

**Used by:** Anthropic's Claude Projects, LangChain's Parent Document Retriever

**Pros:**
- ✅ Token-efficient (fetch summaries first, drill down selectively)
- ✅ Natural for agentic workflows (planning phase uses summaries, execution uses details)
- ✅ Human-readable structure

**Cons:**
- ❌ Requires maintaining summaries (can be auto-generated)
- ❌ Stale summaries if files change frequently

---

### **Pattern 2: Graph-Based Context (Microsoft AutoGen style)**

**How it works:**
```
Nodes: Files, Concepts, Entities
Edges: References, Dependencies, Semantic Similarity

Example:
PRD-0120 --references--> schema.rb
PRD-0120 --implements--> MCP.md (Vision)
schema.rb --contains--> User table
User table --used-by--> SnapshotService
```

**Retrieval Strategy:**
1. Start from query entity (e.g., "net worth feature")
2. Traverse graph to find related nodes
3. Rank by distance + relevance score

**Used by:** Microsoft AutoGen, LlamaIndex Knowledge Graph

**Pros:**
- ✅ Captures relationships between artifacts
- ✅ Dynamic traversal based on query
- ✅ Handles cross-cutting concerns well

**Cons:**
- ❌ Complex to build and maintain
- ❌ Requires graph database or complex data structure
- ❌ Overkill for small projects

---

### **Pattern 3: Contextual Retrieval with Metadata (Anthropic's approach)**

**How it works:**
```json
{
  "file": "schema.rb",
  "type": "code",
  "context": "Database schema for Rails app with User, Snapshot, Artifact tables",
  "tags": ["database", "models", "schema"],
  "last_modified": "2026-01-15",
  "related_prds": ["PRD-0120", "PRD-0030"],
  "summary": "Defines 15 tables including core user data and agent artifacts"
}
```

**Retrieval Strategy:**
1. Embed query + metadata context (not just raw content)
2. Retrieve based on semantic similarity
3. Re-rank using metadata filters (recency, type, tags)

**Used by:** Anthropic's Contextual Retrieval, Pinecone's Hybrid Search

**Pros:**
- ✅ Best retrieval accuracy (metadata + semantics)
- ✅ Works with vector DB or BM25
- ✅ Flexible filtering

**Cons:**
- ❌ Requires vector embeddings (you want to avoid this initially)
- ❌ Metadata maintenance overhead

---

### **Pattern 4: Agentic RAG with Tool-Based Retrieval (ReAct pattern)**

**How it works:**
```
Agent has "tools" for context retrieval:
- search_prds(query) → returns matching PRD excerpts
- get_schema_tables(filter) → returns table definitions
- get_recent_changes(days) → returns git history
- get_backlog_items(status) → returns filtered backlog
```

**Retrieval Strategy:**
1. Agent decides which tools to call based on task
2. Tools return focused, filtered results
3. Agent iterates until it has enough context

**Used by:** LangChain ReAct agents, OpenAI function calling

**Pros:**
- ✅ Agent controls its own context gathering
- ✅ Natural fit for multi-step workflows
- ✅ No need for pre-built hierarchy

**Cons:**
- ❌ Requires capable model (struggles with small Ollama models)
- ❌ More LLM calls (planning overhead)
- ❌ Can retrieve irrelevant context if agent makes poor decisions

---

### **Pattern 5: Staged Context Loading (Junie-inspired)**

**How it works:**
```
Stage 1 (Planning): Lightweight context
  - Project summary (500 chars)
  - Available tools/resources list
  - Query intent

Stage 2 (Verification): Constraint context
  - Schema definitions
  - Validation rules
  - Existing PRD patterns

Stage 3 (Execution): Full context
  - Detailed examples
  - Complete documentation
  - Historical artifacts
```

**Retrieval Strategy:**
1. Each agentic phase gets tailored context
2. Progressive disclosure (start small, add as needed)
3. Context is phase-specific, not query-specific

**Used by:** Cursor IDE, Junie (your inspiration)

**Pros:**
- ✅ Perfect fit for your 5-phase agentic model
- ✅ Token-efficient (only load what's needed per phase)
- ✅ Easy to implement without vector DB

**Cons:**
- ❌ Requires careful phase-to-context mapping
- ❌ May miss relevant context if phase mapping is wrong

---

## Recommended Architecture for Your System

### **Hybrid Approach: Hierarchical + Staged + Tool-Based**

I recommend combining patterns based on your constraints (Ollama, POC, static→dynamic evolution):

```ruby
# RAG Structure
module SapAgent
  module RagContext
    # Tree structure (your idea + hierarchical summarization)
    class ContextTree
      attr_reader :root
      
      def initialize
        @root = Branch.new("project_root", summary: "NextGen Plaid financial app")
      end
      
      # Navigate tree by path
      def get(path)
        # e.g., "backend/schema" → returns schema cluster
      end
      
      # Get context for specific phase
      def for_phase(phase, query_context = {})
        case phase
        when :research
          lightweight_context(query_context)
        when :plan
          structural_context(query_context)
        when :verify
          constraint_context(query_context)
        when :execute
          detailed_context(query_context)
        when :validate
          validation_context(query_context)
        end
      end
    end
    
    # Branch = high-level category
    class Branch
      attr_reader :name, :summary, :clusters
      
      def initialize(name, summary:)
        @name = name
        @summary = summary
        @clusters = []
      end
      
      def add_cluster(cluster)
        @clusters << cluster
      end
      
      # Get lightweight summary for planning
      def to_summary
        {
          name: name,
          summary: summary,
          clusters: clusters.map(&:name)
        }
      end
    end
    
    # Cluster = related files
    class Cluster
      attr_reader :name, :summary, :files, :metadata
      
      def initialize(name, summary:, metadata: {})
        @name = name
        @summary = summary
        @files = []
        @metadata = metadata # tags, last_updated, etc.
      end
      
      def add_file(file_path, summary: nil)
        @files << FileLeaf.new(file_path, summary: summary)
      end
      
      # Get cluster summary without loading files
      def to_summary
        {
          name: name,
          summary: summary,
          file_count: files.size,
          tags: metadata[:tags]
        }
      end
      
      # Load actual file contents
      def load_contents(limit: nil)
        files.first(limit || files.size).map(&:load)
      end
    end
    
    # FileLeaf = individual file
    class FileLeaf
      attr_reader :path, :summary
      
      def initialize(path, summary: nil)
        @path = path
        @summary = summary || auto_summarize
      end
      
      def load
        {
          path: path,
          summary: summary,
          content: File.read(Rails.root.join(path))
        }
      rescue => e
        { path: path, error: e.message }
      end
      
      private
      
      def auto_summarize
        # Extract first line of markdown or first comment
        content = File.read(Rails.root.join(path))
        content.lines.first(3).join.strip[0..200]
      rescue
        "File: #{File.basename(path)}"
      end
    end
  end
end
```

---

### **Context Tree Configuration (Human-Curated → Dynamic)**

#### **Phase 1: Static Human-Curated (POC)**

```yaml
# knowledge_base/rag_context_tree.yml
project_root:
  summary: "NextGen Plaid - Rails financial advisor app with AI agents"
  branches:
    - name: "product"
      summary: "Product vision, requirements, and PRDs"
      clusters:
        - name: "vision"
          summary: "High-level product strategy and goals"
          files:
            - path: "knowledge_base/static_docs/MCP.md"
              summary: "Master Control Plan - product vision"
        - name: "prds"
          summary: "Product requirement documents"
          files:
            - path: "knowledge_base/epics/**/*-PRD.md"
              summary: "Historical PRDs for reference"
              limit: 5  # Only load 5 most recent
    
    - name: "backend"
      summary: "Rails backend architecture and data models"
      clusters:
        - name: "schema"
          summary: "Database schema and models"
          files:
            - path: "db/schema.rb"
              summary: "Rails schema with User, Snapshot, Artifact tables"
        - name: "services"
          summary: "Business logic and agent services"
          files:
            - path: "app/services/sap_agent/**/*.rb"
              summary: "SAP agent implementation"
    
    - name: "backlog"
      summary: "Current work items and priorities"
      clusters:
        - name: "active"
          summary: "In-progress and planned items"
          files:
            - path: "knowledge_base/backlog.json"
              summary: "Prioritized backlog"
```

#### **Phase 2: Hybrid Static/Dynamic**

Add dynamic retrieval strategies:

```ruby
# Dynamic cluster that queries git history
class GitHistoryCluster < Cluster
  def initialize(query_keywords)
    super("git_history", summary: "Recent changes related to query")
    @query_keywords = query_keywords
  end
  
  def load_contents(limit: 5)
    # Search git log for commits matching keywords
    results = `git log --grep="#{@query_keywords}" --oneline -n #{limit}`
    results.lines.map { |line| { type: "commit", content: line } }
  end
end

# Dynamic cluster that searches PRDs by keyword
class PrdSearchCluster < Cluster
  def initialize(query)
    super("related_prds", summary: "PRDs related to query")
    @query = query
  end
  
  def load_contents(limit: 3)
    prd_files = Dir.glob(Rails.root.join('knowledge_base/epics/**/*-PRD.md'))
    
    # Simple keyword search (can upgrade to embeddings later)
    scored = prd_files.map do |file|
      content = File.read(file)
      score = @query.downcase.split.count { |word| content.downcase.include?(word) }
      { file: file, score: score, excerpt: content[0..500] }
    end
    
    scored.sort_by { |s| -s[:score] }.first(limit)
  end
end
```

---

### **Phase-Specific Context Loading**

```ruby
module SapAgent
  class AgenticPrdCommand < Command
    
    def research_phase
      # Lightweight: summaries only, no full file loads
      tree = RagContext::ContextTree.load_from_config
      
      {
        project_summary: tree.root.summary,
        available_branches: tree.root.branches.map(&:to_summary),
        schema_tables: tree.get("backend/schema").to_summary,
        recent_prds_count: tree.get("product/prds").files.size,
        backlog_summary: tree.get("backlog/active").to_summary
      }
    end
    
    def planning_phase(research_context)
      # Structural: load summaries + key constraints
      tree = RagContext::ContextTree.load_from_config
      
      context = research_context.merge(
        vision: tree.get("product/vision").load_contents.first[:content][0..1000],
        schema_tables: extract_table_names(tree.get("backend/schema").load_contents),
        prd_examples: tree.get("product/prds").load_contents(limit: 2).map { |f| f[:summary] }
      )
      
      # Call LLM with focused context
      planning_prompt = build_planning_prompt(context)
      call_llm(planning_prompt, temperature: 0.3)
    end
    
    def verification_phase(plan, research_context)
      # Constraints: validation rules, schema details, existing patterns
      tree = RagContext::ContextTree.load_from_config
      
      context = {
        plan: plan,
        schema_full: tree.get("backend/schema").load_contents.first[:content],
        prd_validation_rules: extract_validation_rules,
        existing_ac_patterns: analyze_existing_prds(tree.get("product/prds"))
      }
      
      # Programmatic verification (no LLM needed for basic checks)
      verify_plan_constraints(plan, context)
    end
    
    def execution_phase(verified_plan, research_context)
      # Detailed: full examples, complete docs
      tree = RagContext::ContextTree.load_from_config
      
      context = {
        plan: verified_plan[:corrected_plan],
        vision_full: tree.get("product/vision").load_contents.first[:content],
        prd_examples_full: tree.get("product/prds").load_contents(limit: 2),
        schema_relevant: extract_relevant_schema(verified_plan, tree),
        backlog_context: tree.get("backlog/active").load_contents
      }
      
      execution_prompt = build_execution_prompt(context)
      call_llm(execution_prompt, temperature: 0.7)
    end
  end
end
```

---

## Comparison: Your Idea vs Industry Patterns

| Aspect | Your Tree/Cluster Idea | Industry Best Practice | Recommendation |
|--------|------------------------|------------------------|----------------|
| **Structure** | Tree → Branch → Cluster → File | ✅ Matches Raptor/Hierarchical | **Keep it** - proven pattern |
| **Summaries** | At each level | ✅ Matches Anthropic's approach | **Keep it** - essential for token efficiency |
| **Static → Dynamic** | Human-curated first | ✅ Matches pragmatic rollout | **Keep it** - right for POC |
| **Context Menu** | Organized tree | ⚠️ Not common term | **Clarify**: Do you mean a config file or UI? |
| **Leaf = File** | Yes | ⚠️ Too granular for some cases | **Adjust**: Leaf can be file OR chunk |

---

## POC Implementation Plan

### **Minimal POC (1-2 days)**

```ruby
# 1. Create simple tree structure
# knowledge_base/rag_tree.json
{
  "branches": [
    {
      "name": "product",
      "summary": "Product vision and PRDs",
      "clusters": [
        {
          "name": "vision",
          "summary": "MCP and product strategy",
          "files": ["knowledge_base/static_docs/MCP.md"]
        },
        {
          "name": "prds",
          "summary": "Recent PRDs",
          "files": ["knowledge_base/epics/**/*-PRD.md"],
          "limit": 3
        }
      ]
    },
    {
      "name": "backend",
      "summary": "Rails backend",
      "clusters": [
        {
          "name": "schema",
          "summary": "Database schema",
          "files": ["db/schema.rb"]
        }
      ]
    }
  ]
}

# 2. Simple loader
class ContextTree
  def self.load
    config = JSON.parse(File.read(Rails.root.join('knowledge_base/rag_tree.json')))
    # Build tree from config
  end
  
  def for_phase(phase)
    case phase
    when :research then load_summaries_only
    when :plan then load_summaries_plus_vision
    when :execute then load_full_context
    end
  end
end

# 3. Integrate with agentic command
def research_phase
  tree = ContextTree.load
  tree.for_phase(:research)
end
```

### **Success Metrics**

- ✅ Planning phase uses <2K tokens (summaries only)
- ✅ Execution phase uses <6K tokens (full context)
- ✅ Context loading < 100ms
- ✅ Easy to add new branches/clusters via JSON

---

## Key Recommendations

### **✅ DO:**
1. **Use hierarchical tree structure** (Branch → Cluster → File) - proven pattern
2. **Generate summaries automatically** where possible (first lines, git log, etc.)
3. **Load context progressively** by phase (research=summaries, execute=full)
4. **Start with static YAML/JSON config** - easy to maintain, no DB needed
5. **Add dynamic clusters gradually** (git search, PRD search) after static works

### **❌ DON'T:**
1. **Don't build vector DB for POC** - overkill, adds complexity
2. **Don't make every file a leaf** - group related files into clusters
3. **Don't load everything upfront** - defeats the purpose of hierarchy
4. **Don't use graph structure yet** - too complex for your current needs
5. **Don't let agent choose context** (ReAct) - Ollama 8B will struggle

### **🤔 CLARIFY:**
1. **"Context menu"** - Do you mean a config file, or a UI for browsing the tree?
2. **Dynamic component** - Are you thinking embeddings, keyword search, or git-based?
3. **Cluster granularity** - How many files per cluster? (Recommend 3-10)

---

## Next Steps

1. **Validate approach**: Does this tree structure match your vision?
2. **Define initial tree**: What branches/clusters for your POC?
3. **Choose config format**: YAML, JSON, or Ruby DSL?
4. **Implement loader**: Start with static tree, test phase-specific loading
5. **Integrate with agentic command**: Replace monolithic RAG with tree-based loading

Would you like me to implement the POC tree structure based on your existing knowledge base?