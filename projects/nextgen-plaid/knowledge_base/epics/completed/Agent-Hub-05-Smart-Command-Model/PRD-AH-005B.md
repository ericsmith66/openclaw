# PRD-AH-005B: SmartProxy Integration
## Overview
Ollama/Proxy chat integration per Vision 2026.
## Requirements
- Functional: Stream response; thoughts.
- Non-Functional: Timeout 30s.
- Rails Guidance: SmartProxyClient; Faraday.
- Logging: JSON tokens.
- Disclaimers: None.
## Architectural Context
Local AI; Cable.
## Acceptance Criteria
- Post to /v1/chat.
- Handle stream tokens.
- Broadcast to pane.
- Timeout safe.
- Logs id.
- No cloud leak.
- Mobile stable.
## Test Cases
- RSpec: stub_request match response.
- Integration: submit; assert tokens stream.
## Workflow for Junie
- Pull main; branch feature/prd-ah-005b.
- Grok 4.1 for stream.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
