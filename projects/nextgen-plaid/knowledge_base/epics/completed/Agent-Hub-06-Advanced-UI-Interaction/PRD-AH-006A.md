# PRD-AH-006A: Color-coded Persona Tabs
## Overview
Implement visual differentiation for persona tabs via color-coding, aligning with the Grok-inspired UI requirements for quick identification.

## Requirements
- **Functional**: Each persona tab must have a specific border/background color when active (SAP: #3B82F6, Conductor: #10B981, CWA: #F59E0B, AiFinancialAdvisor: #8B5CF6, Debug: #EF4444).
- **Non-Functional**: Minimalist DaisyUI styling; no performance impact on context switching.
- **Rails Guidance**: Update `PersonaTabsComponent` to accept color mapping.
- **Traceability**: Original Spec (Persona Tabs); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- SAP tab shows Blue (#3B82F6) when active.
- Conductor tab shows Emerald (#10B981) when active.
- CWA tab shows Amber (#F59E0B) when active.
- AiFinancialAdvisor tab shows Violet (#8B5CF6) when active.
- Debug tab shows Red (#EF4444) when active.
- Colors are applied via Tailwind classes where possible (e.g., `border-blue-500`).

## Test Cases
- **RSpec**: Verify `PersonaTabsComponent` renders the correct CSS classes for each persona.
- **Integration**: Click through each tab and verify the active class changes color.
