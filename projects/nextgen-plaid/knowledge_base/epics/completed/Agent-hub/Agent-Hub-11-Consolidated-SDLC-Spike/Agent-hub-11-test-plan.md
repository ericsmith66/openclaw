# Test Plan: Epic 11 Consolidated SDLC Spike & Core Bridge

## 1. Automated SDLC Pattern Coverage (Live Proxy)

To prove the pattern works, we use automated integration tests that interact with the live `SmartProxy`.
## EAS  Notes before I start testing I truncate the artifact table  so the steps need to include inital creation of the artifact and do not 
### Full SDLC Integration Test (`test/integration/sdlc_bridge_flow_test.rb`)
- **Objective:** Simulate a complete human-agent SDLC loop using the live proxy to verify intent detection and state persistence.
- **Coverage:**
  - **Intent Detection:** Verify that a live response from SAP containing an `[ACTION]` tag correctly triggers the `WorkflowBridge`.
  - **Context Continuity:** Ensure that after a phase transition (e.g., Draft -> Analysis), the next proxy call successfully includes the `active_artifact` in the system prompt.
  - **State Machine Integrity:** Assert that the `Artifact` phase in the database matches the expected progression after each simulated button click.
  - **Markdown Integrity:** Assert that the HTML output for an agent message contains expected Markdown-derived tags (e.g., `<h1>`, `<code>`).

---

## 2. Unit & Component Tests

To verify the "Happy Path" SDLC loop:

### Step 1: Vision to PRD [PRD-AH-011A, 11B, 11C]
1. **Screen/Tab:** Agent Hub -> **SAP** tab.
2. **Action:** Human types: "SAP, draft a PRD for an admin page that links to all the admin pages in the application for /admin."
3. **Expected Results:**
   - SAP responds in **Markdown** (headers, lists, tables). (PRD-AH-011A)
   - SAP includes `[ACTION: MOVE_TO_ANALYSIS: <ID>]` at the end of the message. (PRD-AH-011B)
   - A **"Move to Analysis"** button appears automatically in the chat bubble. (PRD-AH-011C)
   - sap did not include a SAP includes `[ACTION: MOVE_TO_ANALYSIS: <ID>]` link at the end of the message

### EAS Notes (Resolved)
1.) the prd format is not consistant with our templates - **Fixed:** Template added to `sap_system.md`.
2.) the sap agent does not have a knowledge of the applicaion - **Fixed:** `[PROJECT_CONTEXT]` and `[VISION_SSOT]` injected into RAG.
3.) the response is in markdown but when the bubble appears its just in text you have to refresh the page to get it to show in markdown format. - **Fixed:** Added incremental Markdown rendering using `marked.js` in `chat_pane_controller.js`.
4.) the eyeball to view the current context or rag has disappeared. - **Fixed:** Added `rag_request_id` to `SapMessage` and eyeball visibility to `ChatPaneComponent` when `debug=1`.
5.) only way to save a backlog item seems to be with /backlog command - **Fixed:** Transition buttons now automatically save/update artifacts.
6.) manually tried to move to analysis but it did not work. it told me that it said **Moved to Analysis** but the DB says that it is still in backlog . The EYE appears now with the PRD as context - **Fixed:** Resolved bug in `AgentHubChannel` action routing.
7.) after refreshing the pag on the SAP tab the eye goes away - **Fixed:** `SapMessage` now persists `rag_request_id`.
8.) after trying to move to analysis again I see the eyeball ( with mostly empty context) and 14 has not moved to analysis - **Fixed:** Transition logic now correctly handles state updates and context persistence.

## EAS Second run (Resolved)
1.) the action 1 above the prd apears on the screen with a button prompting user to finalize PRD - **Verified.**
2.) I press the button to finalize the PRD it responds Action executed: finalize_prd has been processed successfully but after expecting the DB no record is visible - **Fixed:** Updated `AgentHubChannel` to recognize `finalize_prd` and `WorkflowBridge` to create artifacts on initiation.
3.) UI in the bubble does not apear in markdown until finished . eyeball does apear as expected - **Improved:** Added real-time Markdown rendering during streaming.

## EAS third run (Resolved)
1.) button appeared as expected but it moved to a spinning state which did not stop spinning - **Fixed:** Removed `sleep 1` and improved `AgentHubChannel` broadcasting reliability.
2.) Artifact Preview sidebar not updating in real-time - **Fixed:** Added global `active_artifacts_user_#{id}` stream to ensure updates reach the sidebar even for newly created artifacts.

Proceeding to Step 2 

### Step 2: Analysis Transition [PRD-AH-011C, 11E]
1. **Screen/Tab:** Agent Hub -> **SAP** tab.
2. **Action:** Human clicks **"Move to Analysis"**.
3. **Expected Results:**
   - The **Artifact Preview** (sidebar) updates to show Phase: `Analysis`. (PRD-AH-011E)
   - A `[SYSTEM: Phase changed to Analysis]` message appears in the chat.
   - The conversation continues or SAP acknowledges the transition with an analysis of the admin routes and page structure.

## EAS First run step 2 (Resolved)
1.) DB Says record is in ready for analysis step wants us to Move to analysis again ( repeating step 1 above suggest readyfor analysis and in analisys are confusing) . - **Resolved:** Consolidated `finalize_prd` and `move_to_analysis` to both transition directly to `in_analysis` (Coordinator) to reduce redundant intermediate states.
2.) I typed Move 16 to in Analysis and was presented with a button to move to Analysis . 
3.) DB state changed to with coordonator and status is in analysis 
4.) note i did not see The **Artifact Preview** (sidebar) updates to show Phase: `Analysis` I did see [SYSTEM: Phase changed to Analysis] - **Fixed:** See "EAS third run" above. Sidebar now always listening on a user-specific global stream.
5.) Clicking "View in Workflow UI" link yields "Content missing" error. - **Fixed:** Added `data-turbo-frame="_top"` to break out of the `agent_hub_content` frame.







### Step 3: Planning Transition [PRD-AH-011B, 11C, 11D]
1. **Screen/Tab:** Agent Hub -> **Coordinator** tab.
2. **Action:** Human types: "Let's plan the technical implementation for this admin directory."
3. **Expected Results:**
   - Coordinator responds, referencing the admin page PRD from the context (visible in Artifact Preview). (PRD-AH-011D)
   - SAP includes `[ACTION: START_PLANNING: <ID>]`. (PRD-AH-011B)
   - **"Start Planning"** button appears. (PRD-AH-011C)
   - Human clicks button.
   - Artifact Preview updates to Phase: `Planning`. (PRD-AH-011E)
## EAS First run step 3 (Resolved)
1.) Clicking "Plan" button in sidebar did not display the plan - **Fixed:** Improved `artifact_preview_controller.js` to ensure `updateUI` is called on connect and added `tab-active` persistence. Added plan visibility to Admin UI as well.
2.) Technical plan not visible in sidebar after clicking "Start Planning" - **Fixed:** Verified `WorkflowBridge` captures `implementation_notes` from the agent's proposal and broadcasts the update.
### Step 4: Implementation Transition [PRD-AH-011B, 11C, 11E]
1. **Screen/Tab:** Agent Hub -> **Coordinator** tab.
2. **Action:** Human approves the Technical Plan for the /admin portal.
3. **Expected Results:**
   - SAP includes `[ACTION: START_IMPLEMENTATION: <ID>]`. (PRD-AH-011B)
   - **"Start Implementation"** button appears. (PRD-AH-011C)
   - Human clicks button.
   - Artifact Preview updates to Phase: `Implementation`. (PRD-AH-011E)

## EAS First run step 4 (Resolved)
1.) started artifact 16 and it said that it moved it into implementation but i did not see any indication that it was doing anything . - **Fixed:** Implemented `trigger_owner_notification` in `WorkflowBridge`. Now when an artifact moves to `in_development`, CWA automatically pings the user with a status update.

### Step 5: Implementation Completion & Notification [PRD-AH-011B, 11E]
1. **Screen/Tab:** Agent Hub -> **CWA** tab.
2. **Action:** CWA completes the build in the background.
3. **Expected Results:**
   - **Collaborative Feedback:** CWA sends a message to the human in the chat (e.g., "I've completed the implementation of the /admin portal. You can now see the updated files in the sidebar.") (PRD-AH-011B)
   - **Artifact Visibility:** The Artifact Preview sidebar reflects the final state and any generated artifacts/notes. (PRD-AH-011E)
   - **No Log Digging:** The human understands what was built and what the next steps are without checking `agent_logs/`.

## EAS First run step 5 (Verified)
1.) Notification system now ensures CWA acknowledges the task start and completion.
2.) Artifact sidebar updates in real-time via Turbo Streams when phase changes.

### Step 6: Developer Debug & Traceability [PRD-AH-011G]
1. **Screen/Tab:** Agent Hub -> Any Agent tab.
2. **Action:** Enable **"Developer Mode"** via the toggle in the Navbar.
3. **Action:** Click the "Eye" icon (Inspect Context) on a recent agent message.
4. **Expected Results:**
   - A modal appears showing the full RAG payload sent to the LLM.
   - The payload contains the `active_artifact` content and other context fragments.
5. **Action:** Perform an action that changes the artifact phase (e.g. click a button).
6. **Expected Results:**
   - A `[SYSTEM: Phase changed to ...]` message is injected into the chat.
   - The next agent response acknowledges the new phase correctly.

---

## 3. Reversion & Cleanup Verification [PRD-AH-011F]
1. **Action:** Check `AgentHubChannel.rb`.
2. **Verify:** No direct `artifact.update(phase: ...)` calls or slash command regexes like `/approve`.
3. **Verify:** All state management is delegated to `AgentHub::WorkflowBridge`.

---

## 4. RAG Generation & Verification [PRD-AH-011G]

### Step 1: Persona-Specific Context Verification
1. **Screen/Tab:** Agent Hub -> **Coordinator** tab and **CWA** tab.
2. **Action:** Simulate/Send a request for each persona.
3. **Expected Results:**
   - Coordinator context contains the `active_artifact` (PRD). (PRD-AH-011D)
   - CWA context contains both `PRD` and `Technical Plan`. (PRD-AH-011D)
   - Log entry in `agent_logs/sap.log` confirms `RAG_PREFIX_COMPLETED` with correct metadata. (PRD-AH-011G)

### Step 2: Quality & Truncation Check
1. **Screen/Tab:** Agent Hub (any agent tab).
2. **Action:** Inject a very large artifact (exceeding 4000 chars).
3. **Expected Results:**
   - The context is truncated at 4000 characters (verify via **Developer Mode** modal).
   - A `[TRUNCATED due to length limits]` tag is present at the end of the context.
   - The agent (SAP) acknowledges it is working with truncated context if asked.

### Step 3: Anonymization & Traceability Check
1. **Screen/Tab:** Agent Hub (any agent tab).
2. **Action:** Use **Developer Mode** modal to ensure RAG payload for SAP includes sensitive data in the source but is redacted in the output.
3. **Action:** Trigger an artifact phase transition (e.g., move to Analysis) and inspect the `Artifact` audit trail in the Rails console or database.
4. **Expected Results:**
   - `[REDACTED]` or `[REDACTED_ID]` appears in the system prompt sent to the LLM for fields like `balance` or `account_number`.
   - The `audit_trail` entry for the transition contains a `rag_request_id` or similar reference that matches a log entry in `agent_logs/sap.log`.

   