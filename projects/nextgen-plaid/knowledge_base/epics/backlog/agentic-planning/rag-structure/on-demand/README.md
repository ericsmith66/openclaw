# On-Demand Data Fetchers

This directory contains documentation for on-demand data fetchers that retrieve real-time information when requested by the RAG provider.

## Overview

On-demand fetchers are called dynamically during agent execution to retrieve the most current data. Unlike semi-static data (updated daily), on-demand data is fetched in real-time for each query.

## Fetcher Types

### 1. **schema.md** - Database Schema
- **Query**: `fetch:structural:data_layer:schema`
- **Source**: `db/schema.rb`
- **Returns**: Full database schema or specific table definitions
- **Use Case**: Planning phase needs to know available tables and columns

### 2. **models.md** - Model Files
- **Query**: `fetch:structural:data_layer:core_models` or specific model
- **Source**: `app/models/*.rb`
- **Returns**: Model file content with associations and methods
- **Use Case**: Execution phase needs to understand model relationships

### 3. **services.md** - Service Files
- **Query**: `fetch:structural:service_layer:ai_services` or specific service
- **Source**: `app/services/**/*.rb`
- **Returns**: Service file content with key methods
- **Use Case**: Planning phase needs to know available services

### 4. **jobs.md** - Background Job Files
- **Query**: `fetch:structural:job_layer:plaid_sync_jobs` or specific job
- **Source**: `app/jobs/*.rb`
- **Returns**: Job file content with perform method
- **Use Case**: Planning phase needs to know available background jobs

### 5. **routes.md** - Application Routes
- **Query**: `fetch:structural:interface_layer:routing`
- **Source**: `config/routes.rb`
- **Returns**: Routes definition or specific route details
- **Use Case**: Research phase needs to check if route exists

### 6. **prds.md** - PRD Files
- **Query**: `fetch:sdlc:on_demand:prds` or search by keyword
- **Source**: `knowledge_base/epics/**/*-PRD.md`
- **Returns**: PRD file content or search results
- **Use Case**: Research phase needs to find similar PRDs

### 7. **commits.md** - Git Commit History
- **Query**: `fetch:sdlc:on_demand:commits <sha>` or search by keyword
- **Source**: Git repository
- **Returns**: Commit diff or log entries
- **Use Case**: Verification phase needs to check recent changes

## Implementation Pattern

Each fetcher should follow this pattern:

```ruby
module SapAgent
  module RagContext
    class OnDemandFetcher
      def self.fetch_schema(table_name = nil)
        schema_path = Rails.root.join('db/schema.rb')
        return {error: "Schema not found"} unless File.exist?(schema_path)
        
        content = File.read(schema_path)
        
        if table_name
          # Extract specific table
          table_def = extract_table(content, table_name)
          {
            source: "db/schema.rb",
            table: table_name,
            content: table_def
          }
        else
          # Return full schema (or summary)
          {
            source: "db/schema.rb",
            tables: extract_table_names(content),
            content: content[0..5000] # Limit size
          }
        end
      end
      
      def self.fetch_model(model_name)
        model_path = Rails.root.join("app/models/#{model_name.underscore}.rb")
        return {error: "Model not found"} unless File.exist?(model_path)
        
        {
          source: model_path.to_s,
          content: File.read(model_path)
        }
      end
      
      def self.search_prds(keyword)
        prd_files = Dir.glob(Rails.root.join('knowledge_base/epics/**/*-PRD.md'))
        
        results = prd_files.map do |file|
          content = File.read(file)
          score = keyword.downcase.split.count { |word| content.downcase.include?(word) }
          next if score == 0
          
          {
            file: file,
            score: score,
            excerpt: content[0..500]
          }
        end.compact
        
        results.sort_by { |r| -r[:score] }.first(5)
      end
      
      def self.fetch_commit(sha)
        diff = `git show #{sha} 2>&1`
        return {error: "Commit not found"} unless $?.success?
        
        {
          sha: sha,
          diff: diff[0..3000] # Limit size
        }
      end
    end
  end
end
```

## Query Examples

```ruby
# Fetch full schema
OnDemandFetcher.fetch_schema
# => {source: "db/schema.rb", tables: ["users", "artifacts", ...], content: "..."}

# Fetch specific table
OnDemandFetcher.fetch_schema("artifacts")
# => {source: "db/schema.rb", table: "artifacts", content: "create_table 'artifacts' do..."}

# Fetch model
OnDemandFetcher.fetch_model("Artifact")
# => {source: "app/models/artifact.rb", content: "class Artifact < ApplicationRecord..."}

# Search PRDs
OnDemandFetcher.search_prds("validation scoring")
# => [{file: "PRD-AH-012E.md", score: 5, excerpt: "..."}, ...]

# Fetch commit
OnDemandFetcher.fetch_commit("3504b54")
# => {sha: "3504b54", diff: "diff --git a/lib/sdlc_validation.rb..."}
```

## Performance Considerations

1. **Caching**: Cache frequently accessed files (schema.rb, routes.rb) for 5 minutes
2. **Size Limits**: Truncate large files to 5KB max
3. **Timeouts**: Set 2-second timeout for git commands
4. **Rate Limiting**: Limit to 10 on-demand fetches per agent request

## Integration with Multi-Index RAG

On-demand fetchers are called by the RAG provider when:
1. Index references a file path (e.g., `structural:data_layer:schema`)
2. Agent explicitly requests real-time data
3. Phase-specific context loading requires current state

Example integration:
```ruby
def planning_phase(research_context)
  # Load structural context on-demand
  schema = OnDemandFetcher.fetch_schema
  relevant_models = OnDemandFetcher.fetch_model("Artifact")
  
  context = research_context.merge(
    schema: schema,
    models: relevant_models
  )
  
  planning_prompt = build_planning_prompt(context)
  call_llm(planning_prompt)
end
```

## Next Steps

1. Implement `OnDemandFetcher` class in `app/services/sap_agent/rag_context/`
2. Add caching layer with Redis or in-memory cache
3. Integrate with `MultiIndexProvider` for seamless fetching
4. Add metrics tracking for fetch performance
5. Create tests for each fetcher method
