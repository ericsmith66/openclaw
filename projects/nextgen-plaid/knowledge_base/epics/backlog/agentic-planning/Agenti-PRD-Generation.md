### Agentic PRD Generation Architecture

Based on my analysis of your current SAP Agent codebase,
here's how to structure the agentic PRD generation process with the 5-step lifecycle
(research → plan → verify → execute → validate).

---

### Current Architecture Analysis

**Current Flow (Reactive):**
1. `ArtifactCommand.execute` → optional research → `call_proxy` (single LLM call with full RAG context)
2. Post-generation validation via `PrdStrategy.validate_output!`
3. Retry loop (up to 3 attempts) if validation fails

**Problems:**
- Single-shot generation with no planning phase
- Monolithic RAG context (4000 char limit, includes everything)
- Reactive validation (fix after failure)
- High token usage on retries

---

### Proposed Agentic Architecture

#### **5-Step Lifecycle**

```ruby
module SapAgent
  class AgenticPrdCommand < Command
    def execute
      # 1. RESEARCH: Gather raw data (pluggable RAG)
      research_context = research_phase
      
      # 2. PLAN: AI generates mini-plan for the artifact
      plan = planning_phase(research_context)
      
      # 3. VERIFY: Check plan against constraints
      verified_plan = verification_phase(plan, research_context)
      
      # 4. EXECUTE: Generate final artifact based on verified plan
      artifact = execution_phase(verified_plan, research_context)
      
      # 5. VALIDATE: Final structural check
      validate_and_store(artifact)
    end
  end
end
```

---

### Smallest POC Implementation

Here's the **minimal viable POC** to test the concept with Ollama:

#### **Step 1: Create Pluggable RAG Strategies**

```ruby
# app/services/sap_agent/rag_strategy.rb
module SapAgent
  module RagStrategy
    class Base
      def gather(query, context = {})
        raise NotImplementedError
      end
    end
    
    # Lightweight schema context
    class SchemaStrategy < Base
      def gather(query, context = {})
        schema_path = Rails.root.join('db/schema.rb')
        return {} unless File.exist?(schema_path)
        
        content = File.read(schema_path)
        tables = content.scan(/create_table "([^"]+)"/).flatten
        { schema_tables: tables }
      end
    end
    
    # Existing PRDs for reference
    class PrdHistoryStrategy < Base
      def gather(query, context = {})
        prd_files = Dir.glob(Rails.root.join('knowledge_base/epics/**/*-PRD.md'))
        recent_prds = prd_files.last(3).map do |file|
          { 
            name: File.basename(file),
            excerpt: File.read(file)[0..500]
          }
        end
        { recent_prds: recent_prds }
      end
    end
    
    # Backlog priorities
    class BacklogStrategy < Base
      def gather(query, context = {})
        backlog_path = Rails.root.join('knowledge_base/backlog.json')
        return {} unless File.exist?(backlog_path)
        
        backlog = JSON.parse(File.read(backlog_path))
        { backlog_summary: backlog.first(5) }
      end
    end
  end
end
```

#### **Step 2: Create Agentic PRD Command**

```ruby
# app/services/sap_agent/agentic_prd_command.rb
module SapAgent
  class AgenticPrdCommand < Command
    
    def execute
      log_lifecycle('AGENTIC_START')
      validate!
      
      # Phase 1: Research
      research_context = research_phase
      log_lifecycle('RESEARCH_COMPLETED', research_context.keys.join(', '))
      
      # Phase 2: Plan
      plan = planning_phase(research_context)
      log_lifecycle('PLAN_COMPLETED', plan[:summary])
      
      # Phase 3: Verify
      verified_plan = verification_phase(plan, research_context)
      log_lifecycle('VERIFY_COMPLETED', verified_plan[:status])
      
      # Phase 4: Execute
      artifact = execution_phase(verified_plan, research_context)
      log_lifecycle('EXECUTE_COMPLETED')
      
      # Phase 5: Validate
      result = validate_and_store(artifact)
      log_lifecycle('AGENTIC_COMPLETED')
      
      result
    rescue StandardError => e
      log_lifecycle('AGENTIC_FAILURE', e.message)
      { error: e.message }
    end
    
    private
    
    def research_phase
      # Gather context using pluggable strategies
      strategies = [
        RagStrategy::SchemaStrategy.new,
        RagStrategy::PrdHistoryStrategy.new,
        RagStrategy::BacklogStrategy.new
      ]
      
      context = {}
      strategies.each do |strategy|
        context.merge!(strategy.gather(payload[:query], context))
      end
      
      # Add MCP vision
      mcp_path = Rails.root.join('knowledge_base/static_docs/MCP.md')
      context[:vision] = File.exist?(mcp_path) ? File.read(mcp_path)[0..1000] : ""
      
      context
    end
    
    def planning_phase(research_context)
      planning_prompt = <<~PROMPT
        You are a planning assistant. Based on the user request and context, create a structured plan for a PRD.
        
        USER REQUEST: #{payload[:query]}
        
        CONTEXT:
        - Available DB Tables: #{research_context[:schema_tables]&.join(', ')}
        - Recent PRDs: #{research_context[:recent_prds]&.size || 0} examples available
        - Backlog Items: #{research_context[:backlog_summary]&.size || 0} items
        
        Create a JSON plan with:
        1. "summary": Brief description of what this PRD will cover
        2. "key_sections": Array of section names to include
        3. "acceptance_criteria_count": Number of AC items (5-8)
        4. "technical_considerations": Array of technical points to address
        5. "risks": Potential issues to watch for
        
        Respond ONLY with valid JSON, no markdown formatting.
      PROMPT
      
      response = call_llm(planning_prompt, temperature: 0.3)
      
      # Parse JSON response
      plan_json = extract_json(response)
      plan_json[:raw_response] = response
      plan_json
    end
    
    def verification_phase(plan, research_context)
      # Check plan against constraints
      issues = []
      
      # Check AC count
      ac_count = plan[:acceptance_criteria_count] || plan["acceptance_criteria_count"]
      issues << "AC count should be 5-8, got #{ac_count}" unless (5..8).include?(ac_count.to_i)
      
      # Check required sections
      required_sections = ['Overview', 'Acceptance Criteria', 'Architectural Context', 'Test Cases']
      key_sections = plan[:key_sections] || plan["key_sections"] || []
      missing = required_sections - key_sections
      issues << "Missing sections: #{missing.join(', ')}" if missing.any?
      
      if issues.any?
        log_lifecycle('VERIFY_ISSUES', issues.join('; '))
        # Auto-correct the plan
        plan[:acceptance_criteria_count] = 6 if ac_count.to_i < 5 || ac_count.to_i > 8
        plan[:key_sections] = (key_sections + missing).uniq
      end
      
      {
        status: issues.any? ? 'corrected' : 'approved',
        issues: issues,
        corrected_plan: plan
      }
    end
    
    def execution_phase(verified_plan, research_context)
      plan = verified_plan[:corrected_plan]
      
      execution_prompt = <<~PROMPT
        You are a PRD writer. Generate a complete PRD following this approved plan.
        
        PLAN:
        #{plan.to_json}
        
        USER REQUEST: #{payload[:query]}
        
        CONTEXT:
        - Vision: #{research_context[:vision]}
        - DB Tables: #{research_context[:schema_tables]&.join(', ')}
        
        Generate a complete PRD in Markdown format with these sections:
        #{plan[:key_sections]&.map { |s| "#### #{s}" }&.join("\n")}
        
        Ensure:
        - Title format: ## XXXX-feature-name-PRD.md
        - Exactly #{plan[:acceptance_criteria_count]} acceptance criteria bullets
        - Technical details reference available DB tables
        - Test cases cover happy path and edge cases
      PROMPT
      
      call_llm(execution_prompt, temperature: 0.7)
    end
    
    def validate_and_store(artifact)
      # Use existing validation
      SapAgent::PrdStrategy.validate_output!(artifact)
      parsed = SapAgent::PrdStrategy.parse_output(artifact)
      SapAgent::PrdStrategy.store!(parsed)
      
      { success: true, artifact: parsed }
    end
    
    def call_llm(prompt, temperature: 0.7)
      # Use Ollama via existing routing
      model = SapAgent::Router.route(payload)
      
      # For Ollama, ensure we're using a capable model
      model = 'llama3.1:8b' if model.to_s.include?('ollama')
      
      AiFinancialAdvisor.ask(prompt, model: model, request_id: @request_id, temperature: temperature)
    end
    
    def extract_json(response)
      # Extract JSON from response (handle markdown code blocks)
      json_match = response.match(/```json\n(.*?)\n```/m) || response.match(/\{.*\}/m)
      json_str = json_match ? json_match[1] || json_match[0] : response
      
      JSON.parse(json_str, symbolize_names: true)
    rescue JSON::ParserError => e
      log_lifecycle('JSON_PARSE_ERROR', e.message)
      # Fallback plan
      {
        summary: "Generated from user request",
        key_sections: ['Overview', 'Acceptance Criteria', 'Architectural Context', 'Test Cases'],
        acceptance_criteria_count: 6,
        technical_considerations: [],
        risks: []
      }
    end
  end
end
```

#### **Step 3: Update Router to Support Agentic Mode**

```ruby
# In app/services/sap_agent.rb or wherever you route commands
def self.process_agentic_prd(query, payload = {})
  command_payload = payload.merge(query: query, strategy: 'prd')
  command = SapAgent::AgenticPrdCommand.new(command_payload)
  command.execute
end
```

---

### Testing the POC

#### **1. Create a Test Script**

```ruby
# script/test_agentic_prd.rb
require_relative '../config/environment'

payload = {
  query: "Create a PRD for a net worth tracking feature that shows users their total assets minus liabilities over time",
  user_id: 1,
  persona_id: "sap-agent",
  request_id: SecureRandom.uuid
}

result = SapAgent::AgenticPrdCommand.new(payload).execute

puts "=" * 80
puts "RESULT:"
puts "=" * 80
puts result.inspect
puts "\n"
puts "Check agent_logs/sap.log for detailed lifecycle events"
```

#### **2. Run with Ollama**

```bash
# Ensure Ollama is running with a capable model
ollama pull llama3.1:8b

# Run the test
rails runner script/test_agentic_prd.rb
```

---

### Expected Benefits

**Quality Improvements:**
- **Planning reduces hallucinations**: Model commits to structure before writing
- **Proactive verification**: Catches issues before generation (not after)
- **Focused context**: Each phase gets only relevant RAG data
- **Better AC quality**: Planning phase explicitly thinks about criteria count

**Observability:**
- All 5 phases logged to `agent_logs/sap.log`
- Plan JSON captured for debugging
- Verification issues tracked

**Extensibility:**
- New RAG strategies easy to add
- Each phase can be independently improved
- Planning prompts can be tuned per artifact type

---

### Trade-offs

**Pros:**
- ✅ Higher quality PRDs (planning reduces errors)
- ✅ Better token efficiency (focused context per phase)
- ✅ Self-correction via verification phase
- ✅ Clear audit trail

**Cons:**
- ❌ 2-3 extra LLM calls (planning + verification)
- ❌ Increased latency (~10-15 seconds total vs ~5 seconds)
- ❌ More complex codebase
- ❌ Ollama 8B models may struggle with JSON planning

---

### Recommended Next Steps

1. **POC Validation** (1-2 days):
    - Implement the 3 files above
    - Run 10 test PRD generations
    - Compare quality vs current approach
    - Measure latency and token usage

2. **Iterate on Planning Prompt** (1 day):
    - Tune planning prompt for Ollama
    - Add few-shot examples if JSON parsing fails
    - Consider using structured output format

3. **Expand RAG Strategies** (2-3 days):
    - Add `GitHistoryStrategy` (search for related PRDs by keyword)
    - Add `LiveSchemaStrategy` (parse schema.rb for column details)
    - Create strategy registry for dynamic selection

4. **Production Readiness** (3-5 days):
    - Add error recovery for each phase
    - Implement phase result caching
    - Add metrics/monitoring
    - A/B test against current approach

---

### Minimal POC Checklist

To get started **today** with the smallest possible test:

- [ ] Create `app/services/sap_agent/rag_strategy.rb` with 3 basic strategies
- [ ] Create `app/services/sap_agent/agentic_prd_command.rb` with 5-phase lifecycle
- [ ] Create `script/test_agentic_prd.rb` test script
- [ ] Run with Ollama and compare output quality
- [ ] Check `agent_logs/sap.log` for phase transitions
- [ ] Measure: Does planning improve AC quality? Does verification catch issues?

**Success Criteria for POC:**
- Planning phase produces valid JSON 80%+ of time
- Verification catches at least 1 issue per 5 generations
- Final PRD passes validation on first try 70%+ (vs current ~40-50%)
- Total time < 20 seconds with Ollama

This POC gives you a working agentic system you can test immediately while keeping the current reactive system as fallback.