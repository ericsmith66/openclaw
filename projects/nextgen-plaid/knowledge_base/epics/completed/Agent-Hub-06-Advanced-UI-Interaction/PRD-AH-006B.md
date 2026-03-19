# PRD-AH-006B: Gear Icon & Model Overrides
## Overview
Add a global model selection menu to the persona tabs, allowing users to override the default AI model for the current session.

## Requirements
- **Functional**: A Gear icon dropdown in the Persona Tabs bar; List available models (Grok, Ollama, etc.); Update backend routing on selection.
- **Non-Functional**: Persist selection in session or AiWorkflowRun.
- **Rails Guidance**: Stimulus controller for dropdown interaction; POST to `AgentHubsController#update_model`.
- **Traceability**: Original Spec (Persona Tabs); Remaining Capabilities Doc (UI Gaps).

## Acceptance Criteria
- Gear icon visible in the top-right of the tabs bar.
- Clicking the Gear shows a DaisyUI dropdown with model options.
- Selecting a model updates the `model` used for subsequent messages in that session.
- UI reflects the selected model (e.g., checkmark next to active model).

## Test Cases
- **Integration**: Select "Grok" from the Gear menu; send a message; verify the model badge on the response bubble shows "Grok".
