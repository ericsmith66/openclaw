### PRD 0050: “Known-Good Continue Config” + Troubleshooting Guide

**Overview**: Provide a short, copy/pasteable guide so a developer can configure Continue (RubyMine) to use SmartProxy and quickly diagnose common issues (auth, missing models, streaming, Grok key).

**Requirements**:
1) **Configuration Snippet**
   - Base URL format: `http://localhost:<port>/v1`
   - Token: `PROXY_AUTH_TOKEN`
   - Model selection via `GET /v1/models`
2) **Troubleshooting Playbook**
   - “Model not found” → check `/v1/models`
   - 401 Unauthorized → check token
   - 400 “model is required” → explain missing/blank model scenarios
   - Grok selected but fails → check `GROK_API_KEY`
   - streaming errors → check whether Continue sends `stream: true`
3) **Log Correlation**
   - How to grep `log/smart_proxy.log` by time and `session_id`.

**Acceptance Criteria**:
- A new developer can configure Continue and successfully chat with Ollama and Grok in <10 minutes.

**Test Cases**:
- Manual: follow the doc from scratch.

**Workflow**: Update knowledge base docs; validate by onboarding test.

**Context Used**:
- `knowledge_base/epics/CONTINUE-01/CONTINUE-01-Epic.md` (epic scope and dependencies)
- `log/smart_proxy.log` (correlation)
