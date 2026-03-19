# PRD-AH-008B: @mentions & Persona Routing
## Overview
Implement `@mention` support in the input bar to explicitly route messages to specific agent personas (e.g., `@SAP`, `@Conductor`).

## Requirements
- **Functional**: Regex parsing for `@PersonaName`; Update message routing based on detected persona; Visual feedback in input bar.
- **Non-Functional**: Fast parsing.
- **Rails Guidance**: Update `AgentHub::CommandParser` or create `MentionParser`.
- **Traceability**: Original Spec (Input Bar); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Typing `@SAP` in the input bar directs the message to the SAP persona regardless of the active tab.
- The assistant's response bubble reflects the mentioned persona.
- Invalid mentions (e.g., `@Unknown`) fallback to the active tab's persona.

## Test Cases
- **Integration**: On the Conductor tab, type "@SAP what is the plan?"; verify the response comes from SAP.
