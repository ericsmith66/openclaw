# Ollama Tool Use Epic - Directory Guide

This directory contains the complete specification for implementing structured
tool use in SmartProxy for reliable local AI execution with Ollama.

VERSION: 3.0 (User-approved with incremental rollout)
STATUS: BLOCKING - Production HTTP 400 errors
LAST UPDATED: 2026-01-16

---

## Quick Start

1. **PHASE 0**: Execute `PHASE-0-VALIDATION.md` checklist (~2 hours)
2. **Read**: `0000-Epic.md` - Epic overview and objectives
3. **Review**: `implementation-reference.md` - Complete OllamaClient code
4. **Implement**: Incremental rollout (Phase 1A → 1B → 2 → 3 → 4 → 5)
5. **Test**: Use test cases in PRD-06 and E2E script from PRD-07
6. **Verify**: Check `feedback-v2.md` for architectural decisions

---

## File Structure

### Core Documents

- **0000-Epic.md** - Epic narrative, objectives, architectural approach
- **implementation-reference.md** - Complete refactored OllamaClient code
- **feedback-v2.md** - Architectural review and Q&A

### Product Requirements Documents (PRDs)

Implementation order:

1. **PRD-AH-OLLAMA-TOOL-00.md** - Conversation History Normalization
   - Converts Grok/OpenAI string args -> Ollama object args
   - Fixes HTTP 400 unmarshal errors

2. **PRD-AH-OLLAMA-TOOL-01.md** - Tool Schema Acceptance and Validation
   - Validates OpenAI-compatible tools schema
   - Fails fast with clear error messages

3. **PRD-AH-OLLAMA-TOOL-02.md** - Gated Tool Forwarding with Model Selector
   - Environment flag for feature gating
   - Tool-optimized model selection
   - Retry middleware for transient errors

4. **PRD-AH-OLLAMA-TOOL-03.md** - Ollama Tool Calls Parsing to OpenAI Format
   - Converts Ollama responses to OpenAI format
   - Generates call IDs
   - Lenient error handling

5. **PRD-AH-OLLAMA-TOOL-04.md** - Streaming Restrictions and Error Handling
   - Rejects streaming + tools combination
   - Clear error messages

6. **PRD-AH-OLLAMA-TOOL-05.md** - Enhanced Logging for Tool Flows
   - Comprehensive debug logging
   - Structured JSON format
   - All key events captured

7. **PRD-AH-OLLAMA-TOOL-06.md** - Comprehensive Tests and Acceptance Criteria
   - Unit tests
   - Integration tests
   - Smoke tests
   - 90%+ coverage target

8. **PRD-AH-OLLAMA-TOOL-07.md** - Rails Client Integration and E2E Workflow Validation
   - E2E test script
   - Mixed-provider workflow validation
   - Performance verification

---

## Key Concepts

### The Problem

During SDLC E2E work, mixing providers caused errors:
- Grok/OpenAI send tool_calls[].function.arguments as JSON STRING
- Ollama expects tool_calls[].function.arguments as JSON OBJECT
- Result: HTTP 400 "cannot unmarshal string into tool_calls.function.arguments"

### The Solution

Normalize in OllamaClient before sending to Ollama:
1. Walk message history
2. Convert string arguments to Hash objects
3. Validate tools schema
4. Gate with environment flag
5. Select tool-optimized model
6. Parse responses to OpenAI format

### The Pattern

Mirror GrokClient structure:
- Method: chat_completions(payload)
- Accept full payload including tools
- Faraday retry middleware
- Return OpenStruct with status and body
- Provider-specific transformations in client

---

## Implementation Checklist

### Phase 0: Pre-Implementation Validation (~2 hours)
- [ ] Execute all items in `PHASE-0-VALIDATION.md`
- [ ] Document results in `phase-0-results.md`
- [ ] Confirm Go/No-Go decision
- [ ] Baseline performance metrics captured

**DECISION POINT**: Must complete Phase 0 before proceeding

### Prerequisites
- [ ] Ollama running at localhost:11434
- [ ] Tool model pulled: `ollama pull llama3-groq-tool-use:70b`
- [ ] Model verified: `ollama run llama3-groq-tool-use:70b "Hello"`
- [ ] ENV vars set: OLLAMA_TOOLS_ENABLED=true, OLLAMA_TOOL_MODEL=llama3-groq-tool-use:70b

### Phase 1A: Critical Fix - Normalization Only (Week 1, Days 1-2)
- [ ] Add normalize_tool_arguments_in_payload method
- [ ] Integrate into existing chat method
- [ ] Add basic logging for normalization events
- [ ] Test with mixed-provider histories
- [ ] Deploy to production with feature flag
- [ ] Run script/run_agent_test_sdlc_e2e.sh
- [ ] Validate HTTP 400 errors resolved

**DECISION POINT**: If normalization fixes HTTP 400, validate in production before Phase 1B

### Phase 1B: Full Refactor - chat_completions Method (Week 1, Days 3-4)
- [ ] Add validate_tools_schema! method (with enhanced error messages)
- [ ] Add validate_and_gate_tools method
- [ ] Add select_model method
- [ ] Add Faraday retry middleware
- [ ] Add chat_completions method (coexists with chat - NO DEPRECATION)
- [ ] Add enhanced logging helpers
- [ ] Add performance monitoring instrumentation

### Phase 2: Response Parsing + Restrictions (Week 1, Day 5)
- [ ] Add parse_tool_calls_if_present method
- [ ] Add parse_tool_call method
- [ ] Update ResponseTransformer.ollama_to_openai
- [ ] Add streaming + tools check

### Phase 3: App.rb Integration (Week 2, Day 1)
- [ ] Add ArgumentError catch for streaming + tools
- [ ] Add early validation for tools schema
- [ ] Update dump_llm_call_artifact! with tools_count, tool_calls_count

### Phase 4: Comprehensive Testing (Week 2, Days 2-3)
- [ ] Create spec/ollama_client_spec.rb with all unit tests
- [ ] Update spec/response_transformer_spec.rb
- [ ] Update spec/app_spec.rb
- [ ] Update test/smoke/smart_proxy_live_test.rb
- [ ] Edge case testing (empty strings, null values, large payloads)
- [ ] Target: 95%+ code coverage

### Phase 5: E2E Validation + Documentation (Week 2, Days 4-5)
- [ ] Run script/run_agent_test_sdlc_e2e.sh (full validation)
- [ ] Update README with tool usage examples
- [ ] Add inline documentation
- [ ] Performance profiling and validation
- [ ] Update .env.example
- [ ] Verify success metrics

---

## Environment Variables

Add to .env.example:

```bash
# Enable/disable tool forwarding to Ollama (default: true)
OLLAMA_TOOLS_ENABLED=true

# Model to use when tools are present (optional)
OLLAMA_TOOL_MODEL=llama3-groq-tool-use:70b
```

Existing variables:
```bash
OLLAMA_MODEL=llama3.1:70b
OLLAMA_URL=http://localhost:11434/api/chat
OLLAMA_TIMEOUT=120
OLLAMA_TAGS_URL=http://localhost:11434/api/tags
```

---

## Testing Strategy

### Unit Tests
```bash
cd smart_proxy
bundle exec rspec spec/ollama_client_spec.rb
```

### Integration Tests
```bash
cd smart_proxy
bundle exec rspec spec/response_transformer_spec.rb
bundle exec rspec spec/app_spec.rb
```

### Smoke Tests (requires Ollama)
```bash
cd test/smoke
ruby smart_proxy_live_test.rb
```

### E2E Test (mixed providers)
```bash
./script/run_agent_test_sdlc_ollama_tools_e2e.sh
```

### Coverage Report
```bash
cd smart_proxy
COVERAGE=true bundle exec rspec
open coverage/index.html
```

---

## Architecture Overview

### Data Flow

1. **Rails Request**
   - SmartProxyClient serializes full payload (no changes needed)
   - Sends to SmartProxy /v1/chat/completions

2. **SmartProxy Endpoint** (app.rb)
   - Early validation (optional)
   - Routes to ToolOrchestrator

3. **ToolOrchestrator**
   - Checks client.respond_to?(:chat_completions)
   - Calls client.chat_completions(payload)

4. **OllamaClient** (NEW)
   - STEP 1: Normalize tool arguments (string -> Hash)
   - STEP 2: Validate and gate tools
   - STEP 3: Select model (tool-optimized if tools present)
   - STEP 4: Check streaming + tools (reject if both)
   - STEP 5: Force stream: false
   - STEP 6: Make request with retry
   - STEP 7: Parse tool_calls if present
   - Return OpenStruct(status, body)

5. **ResponseTransformer**
   - Convert Ollama format to OpenAI format
   - Include tool_calls in message
   - Set finish_reason to 'tool_calls' when appropriate

6. **Rails Response**
   - Receive OpenAI-compatible format
   - Process tool_calls in ToolOrchestrator loop

### Integration Points

- **ToolOrchestrator**: No changes (already checks respond_to?(:chat_completions))
- **ResponseTransformer**: Update ollama_to_openai to include tool_calls
- **SmartProxyClient**: No changes (already works, proven by smoke test)
- **App.rb**: Add validation and error handling

---

## Success Metrics

- Zero HTTP 400 errors from Ollama in mixed-provider workflows
- 90%+ test coverage on new code
- E2E script completes successfully
- Tool-optimized model used when configured
- No performance regression (<2s added per loop)
- All log events present and queryable

---

## References

### Internal
- smart_proxy/lib/grok_client.rb - Pattern reference
- smart_proxy/lib/tool_orchestrator.rb - Integration point
- smart_proxy/lib/response_transformer.rb - Response handling
- test/smoke/smart_proxy_live_test.rb:63-82 - Evidence tools work

### External
- https://github.com/ollama/ollama/blob/main/docs/api.md - Ollama API docs
- knowledge_base/prds/prds-junie-log/junie-log-requirement.md - Log format

---

## Status

REVIEW STATUS: Ready for Implementation (User-Approved)
CONFIDENCE LEVEL: High
PRIORITY: BLOCKING - Production HTTP 400 errors
RECOMMENDED ACTION: Execute Phase 0 validation, then begin Phase 1A (normalization)

---

## User Decisions Summary

### Approved Changes:
- ✅ Incremental rollout strategy (Phase 1A normalization first, then full refactor)
- ✅ Opt-out feature flag (OLLAMA_TOOLS_ENABLED=true by default)
- ✅ NO deprecation of chat method (permanent coexistence with chat_completions)
- ✅ Enhanced error messages with remediation hints
- ✅ Performance monitoring instrumentation
- ✅ Enhanced success metrics (95%+ coverage, <50ms normalization overhead)
- ✅ Phase 0 validation checklist before implementation

### Deferred Features (Future Enhancements):
- ⏸️ Model availability check with caching
- ⏸️ Semantic tool call validation (OLLAMA_VALIDATE_TOOL_REFS)
- ⏸️ Strict vs. lenient parsing modes (OLLAMA_STRICT_TOOL_PARSING)
- ⏸️ Middleware pattern for transformations

### Environment Context:
- Hardware: M3 Ultra with 256GB unified memory
- Current Issue: Production HTTP 400 errors blocking PRD generation
- Test Environment: Using script/run_agent_test_sdlc_e2e.sh
- Logging: /logs/smart_proxy.log (structured JSON, no anonymization needed for local Ollama)

---

## Questions?

All architectural questions answered in `feedback-v2.md`

For implementation questions, refer to:
- `PHASE-0-VALIDATION.md` - Pre-implementation validation checklist
- `implementation-reference.md` - Complete code with v3.0 enhancements
- Individual PRDs - Detailed requirements and test cases
- `0000-Epic.md` - Overall context and objectives
