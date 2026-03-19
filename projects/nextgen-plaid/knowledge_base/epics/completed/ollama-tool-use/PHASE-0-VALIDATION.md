# Phase 0: Pre-Implementation Validation Checklist

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready to Execute
Duration: ~2 hours
Last Updated: 2026-01-16

---

## Purpose

Validate all assumptions and integration points before starting implementation.
This phase confirms the problem exists as described and ensures the environment
is ready for the incremental rollout.

---

## Validation Checklist

### 1. Environment Setup

- [ ] **Ollama Service Running**
  ```bash
  curl http://localhost:11434/api/tags
  # Expected: JSON response with models list
  ```

- [ ] **Tool Model Available**
  ```bash
  ollama list | grep llama3-groq-tool-use
  # Expected: llama3-groq-tool-use:70b in list
  # If not present: ollama pull llama3-groq-tool-use:70b
  ```

- [ ] **Model Loads Successfully**
  ```bash
  ollama run llama3-groq-tool-use:70b "Hello"
  # Expected: Model responds without errors
  # Ctrl+D to exit
  ```

- [ ] **SmartProxy Running**
  ```bash
  curl http://localhost:3002/health
  # Expected: 200 OK or health check response
  ```

- [ ] **Rails Application Running**
  ```bash
  curl http://localhost:3000/
  # Expected: Application responds
  ```

---

### 2. Problem Reproduction

- [ ] **Reproduce HTTP 400 Error**
  - Run mixed-provider workflow (Grok → Ollama)
  - Expected: HTTP 400 "cannot unmarshal string into tool_calls.function.arguments"
  - Document exact error message and stack trace
  - Save request/response payloads for analysis

- [ ] **Confirm Error Location**
  ```bash
  tail -f log/smart_proxy.log | grep -i "400\|unmarshal\|tool_calls"
  # Expected: See HTTP 400 errors from Ollama
  ```

- [ ] **Verify Grok Works with Tools**
  - Test Grok-only workflow with tools
  - Expected: No errors, tool calls work correctly
  - Confirms problem is Ollama-specific

---

### 3. Code Review

- [ ] **Review Current OllamaClient**
  ```bash
  cat smart_proxy/lib/ollama_client.rb
  # Expected: 66-line version with chat method
  # Confirm no recent changes that might conflict
  ```

- [ ] **Review ToolOrchestrator Integration**
  ```bash
  grep -n "respond_to?(:chat_completions)" smart_proxy/lib/tool_orchestrator.rb
  # Expected: Find check for chat_completions method
  # Confirms integration point exists
  ```

- [ ] **Review GrokClient Pattern**
  ```bash
  grep -A 20 "def chat_completions" smart_proxy/lib/grok_client.rb
  # Expected: See method signature and structure to mirror
  ```

- [ ] **Review ResponseTransformer**
  ```bash
  grep -A 30 "def ollama_to_openai" smart_proxy/lib/response_transformer.rb
  # Expected: See current transformation logic
  # Identify where to add tool_calls handling
  ```

---

### 4. Test Infrastructure

- [ ] **Run Existing Smoke Tests**
  ```bash
  cd test/smoke
  ruby smart_proxy_live_test.rb
  # Expected: All tests pass (especially test_chat_completions_ollama_style_with_tools_returns_choices_and_usage)
  ```

- [ ] **Verify SmartProxyClient Serialization**
  - Check test/smoke/smart_proxy_live_test.rb:63-82
  - Confirm tools array is sent correctly
  - Expected: Test passes, proving SmartProxyClient needs no changes

- [ ] **Run E2E Test Script**
  ```bash
  ./script/run_agent_test_sdlc_e2e.sh
  # Expected: May fail with HTTP 400 (confirms problem)
  # Document failure point and error messages
  ```

---

### 5. Performance Baseline

- [ ] **Measure Current Performance**
  ```bash
  # Run a typical request and measure timing
  time curl -X POST http://localhost:3002/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "llama3.1:70b",
      "messages": [{"role": "user", "content": "Hello"}]
    }'
  # Document: Total time, response time
  ```

- [ ] **Check Log Performance**
  ```bash
  # Verify logs are being written
  tail -20 log/smart_proxy.log
  # Expected: Recent log entries with timestamps
  # Document: Log file size, write frequency
  ```

- [ ] **Memory Usage Baseline**
  ```bash
  # Check Ollama memory usage
  ps aux | grep ollama
  # Document: Current memory usage with llama3.1:70b
  ```

---

### 6. Environment Variables

- [ ] **Check Current ENV Variables**
  ```bash
  grep OLLAMA .env
  # Expected: OLLAMA_MODEL, OLLAMA_URL, OLLAMA_TIMEOUT, OLLAMA_TAGS_URL
  # Document current values
  ```

- [ ] **Verify Logging Configuration**
  ```bash
  grep -i logger smart_proxy/app.rb | head -5
  # Expected: $logger defined and configured
  # Confirm structured JSON logging is set up
  ```

---

### 7. Hardware Verification

- [ ] **Confirm M3 Ultra Specs**
  ```bash
  system_profiler SPHardwareDataType | grep -A 5 "Memory"
  # Expected: 256GB unified memory
  ```

- [ ] **Check Available Memory**
  ```bash
  vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f Mi\n", "$1:", $2 * $size / 1048576);'
  # Expected: Sufficient free memory for 70B model (~60GB needed)
  ```

---

## Success Criteria

All checklist items must be completed and documented before proceeding to Phase 1A.

### Go Criteria:
- ✅ HTTP 400 error reproduced and documented
- ✅ Grok works with tools (confirms Ollama-specific issue)
- ✅ Tool model available and loads successfully
- ✅ Existing smoke tests pass
- ✅ Integration points confirmed (ToolOrchestrator, ResponseTransformer)
- ✅ Performance baseline documented
- ✅ Sufficient memory available

### No-Go Criteria:
- ❌ Cannot reproduce HTTP 400 error (problem may be resolved or different)
- ❌ Tool model not available or fails to load
- ❌ Existing smoke tests fail (indicates other issues)
- ❌ Integration points missing or changed
- ❌ Insufficient memory for tool model

---

## Documentation

After completing validation, document findings in:

```
knowledge_base/epics/ollama-tool-use/phase-0-results.md
```

Include:
- Validation date and time
- All checklist results (✅ or ❌)
- Error messages and stack traces
- Performance baseline metrics
- Any unexpected findings
- Go/No-Go decision with rationale

---

## Next Steps

### If Go:
Proceed to Phase 1A (Normalization Only)
- Implement normalize_tool_arguments_in_payload method
- Add to existing chat method
- Test with mixed-provider workflows

### If No-Go:
- Document blockers
- Reassess approach
- Consult with team
- Update epic based on findings

---

## Estimated Time

- Environment setup: 15 minutes
- Problem reproduction: 30 minutes
- Code review: 30 minutes
- Test infrastructure: 30 minutes
- Performance baseline: 15 minutes
- Documentation: 15 minutes

**Total: ~2 hours**

---

## Contact

If validation reveals unexpected issues or blockers, document in phase-0-results.md
and consult before proceeding to implementation.
