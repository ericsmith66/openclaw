# Epic 5 Scoring Prompt

Use this prompt with the QA Agent in AiderDesk to score the SmartProxy Epic 5 implementation.

---

## Prompt

Score the implementation of **Epic 5 — Unified Live Model Discovery** against the epic specification and each constituent PRD.

### Epic specification
Read: `knowledge_base/epics/epic-5-unified-model-discovery/epic-5-unified-model-discovery.md`

### PRDs to score individually
1. `knowledge_base/epics/epic-5-unified-model-discovery/prd-5-1-model-filter.md`
2. `knowledge_base/epics/epic-5-unified-model-discovery/prd-5-2-model-aggregator-refactor.md`
3. `knowledge_base/epics/epic-5-unified-model-discovery/prd-5-3-provider-list-models.md`
4. `knowledge_base/epics/epic-5-unified-model-discovery/prd-5-4-openrouter-provider.md`

### Scoring Process

**For each PRD (scored independently, 100 points each):**

| Category | Points | What to Check |
|----------|--------|---------------|
| Acceptance Criteria Compliance | 30 | Read each AC in the PRD. Verify it is implemented by reading the source file(s). Each unmet AC = proportional deduction. |
| Test Coverage | 30 | Run `bundle exec rspec spec/lib/<relevant>_spec.rb`. Every test case listed in the PRD's "Testing Requirements" table must exist and pass. Missing test = -3 pts. Failing test = -5 pts. |
| Code Quality | 20 | Correct patterns, error handling, no dead code, follows existing project conventions (Faraday usage, logging, ENV patterns). |
| Integration Correctness | 20 | The file wires into the rest of the system correctly. For PRD 5-1: ModelFilter is called by ModelAggregator. For PRD 5-3: each client's `list_models` returns the common format. For PRD 5-4: model_router routes OpenRouter models. |

**Verification steps (run these — do NOT just read code):**
1. `bundle exec rspec spec/lib/model_filter_spec.rb` — PRD 5-1
2. `bundle exec rspec spec/lib/model_aggregator_spec.rb` — PRD 5-2
3. `bundle exec rspec spec/lib/grok_client_spec.rb spec/lib/claude_client_spec.rb spec/lib/deepseek_client_spec.rb spec/lib/fireworks_client_spec.rb spec/lib/ollama_client_spec.rb` — PRD 5-3
4. `bundle exec rspec spec/lib/openrouter_client_spec.rb spec/lib/model_router_spec.rb` — PRD 5-4
5. `bundle exec rspec spec/lib/ --format progress` — full suite, confirm zero failures
6. `ruby -c lib/model_filter.rb lib/model_aggregator.rb lib/openrouter_client.rb lib/model_router.rb` — syntax check all new/modified files

**Epic-level integration check (after PRD scores):**
- Does `GET /v1/models` flow match the architecture diagram in the epic? (ModelAggregator → per-provider list_models → ModelFilter#apply)
- Is there a single shared filter pipeline (no per-provider filtering outside ModelFilter)?
- Do ENV fallbacks work (each provider gracefully degrades if live fetch fails)?
- Are all provider clients consistent in their `list_models` return shape?

### Output Format

```markdown
# Epic 5 — Scoring Report
**Date:** YYYY-MM-DD
**Scorer:** QA Agent

## PRD-by-PRD Scores

### PRD 5-1: ModelFilter (XX/100)
- AC Compliance: XX/30 — [details]
- Test Coverage: XX/30 — [details, test output summary]
- Code Quality: XX/20 — [details]
- Integration: XX/20 — [details]
- Deductions: [itemized with file:line references]

### PRD 5-2: ModelAggregator Refactor (XX/100)
[same format]

### PRD 5-3: Provider list_models (XX/100)
[same format]

### PRD 5-4: OpenRouter Provider (XX/100)
[same format]

## Epic-Level Assessment
- Architecture compliance: [yes/no + details]
- Shared filter pipeline: [yes/no]
- ENV fallback consistency: [yes/no]
- Provider return shape consistency: [yes/no]

## Summary
| PRD | Score | Status |
|-----|-------|--------|
| 5-1 | XX/100 | PASS/REJECT |
| 5-2 | XX/100 | PASS/REJECT |
| 5-3 | XX/100 | PASS/REJECT |
| 5-4 | XX/100 | PASS/REJECT |
| **Epic Average** | **XX/100** | **PASS/REJECT** |

## Remediation Required
[If any PRD < 90, list specific fixes needed]
```

Save the full report to: `knowledge_base/epics/epic-5-unified-model-discovery/qa-report-epic-5.md`
