# PRD-AH-002A: Streaming Chat Pane Setup
## Overview
Pane for streams/badges, visibility in AI flows per Vision 2026 trust.
## Requirements
- Functional: Token/thoughts; badges.
- Non-Functional: Cap 5.
- Rails Guidance: ChatPaneComponent; broadcast.
- Logging: JSON events.
- Disclaimers: None.
## Architectural Context
Action Cable; Ollama; RAG escalations.
## Acceptance Criteria
- "…" pulses.
- Gray thoughts.
- Badges "Ollama 70B".
- Append no reload.
- Cap no overload.
- No Plaid.
- Logs id.
## Test Cases
- RSpec: broadcast changes pane.
- Integration: enqueue; assert ".typing".
## Workflow for Junie
- Pull main; branch feature/prd-ah-002a.
- Grok 4.1 for stream.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
