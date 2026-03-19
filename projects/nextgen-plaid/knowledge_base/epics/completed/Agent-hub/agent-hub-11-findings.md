I have saved the bypass script to `script/force_cwa_run.sh` and reverted the temporary changes to `AiWorkflowService.rb`.

Based on the "stalling" behavior we observed (SAP/Coordinator acting like chatbots instead of routers) and the poor quality of the initial PRD/Plan, here are my recommendations for modifying the workflow:

### 1. Enforce "Action-First" Routing
The current routing agents (SAP and Coordinator) have too much "conversational" freedom.
*   **Recommendation**: Modify the `Agents::Runner` call in `AiWorkflowService` to support a `tool_choice: 'required'` parameter for the first turn. This forces the router to pick a tool (Handoff) before it is allowed to "chat."
*   **Benefit**: Eliminates the "SAP review" stall where the agent gives text feedback but fails to move the ball.

### 2. Persona-Aware RAG Tuning
CWA is currently getting a "flat" dump of context.
*   **Recommendation**: Update `SapAgent::RagProvider` to specifically tag sections for CWA. For example, explicitly labeling the `[TECHNICAL_PLAN]` and `[PRD]` with "REQUIRED: MUST FOLLOW" instructions. We should also include a "Project Map" that shows only the file paths relevant to the feature (e.g., `app/views/admin/*`) rather than the whole repo.
*   **Benefit**: Reduces hallucinations where CWA tries to implement things in the wrong directory.

### 3. Automated "Backtrack" Loops
When an agent like SAP says "REVISE_PRD," it currently just stops.
*   **Recommendation**: Implement a "Refinement Loop." If an agent flags a PRD as poor, it should automatically trigger a `RefinementAgent` whose *only* job is to rewrite the PRD based on the feedback, then re-submit it to the router.
*   **Benefit**: Moves the SDLC forward autonomously without needing you to manually "Force" it as often.

### 4. Transition Button Hard-Coding
The UI buttons (`Move to Analysis`, etc.) currently rely on the agent's response containing a specific tag.
*   **Recommendation**: Move the transition logic into the `AiWorkflowRun` state machine. Instead of the UI asking the agent what to do, the engine should determine the next state and simply present the agent with a "Next Step" instruction (e.g., "You are now in Implementation phase. Begin coding.").
*   **Benefit**: Decouples the UI state from the agent's (sometimes unreliable) text output.

### 5. Standardized "Task Logs" (CWA Log)
The `cwa_log.md` was mostly empty because the planning phase was skipped or failed.
*   **Recommendation**: Ensure every agent (including Planner) is required to write to a "Shared Memory" artifact before handing off. CWA should not be allowed to start until a JSON-schema validated "Plan" exists.
*   **Benefit**: Provides a clear audit trail and ensures CWA isn't "guessing" the requirements.

**Next Steps**: Which of these should we prioritize implementing first? I recommend starting with **#1 (Action-First Routing)** to stop the stalling issue.

1.) when we are approving we should be phase change so the button should tell me the phase change ( move to ready for analysis)
2.) I should be able to ask for a backlog item by name or number and it should make the Item current or add a button confirmation like work on Item x .
3.) I should be able to save an artifact with save this artifact or something like that.  4.) the UI needs maximize the usability of the screen size
5.) Mobile only sort of works
6.) I should be able to close the sidebar on the right  	
7.) gear menu and pulldown do not agree on what model to use and they are not sticky  we should remove the one in the chatbox but the selected model should be visible in the title bar  next to the gear
8.) the flash message should be a field on the top title bar not its own banner ( takes up too much room)
9.) in agent hub when a message has been submitted but not yet returned the send button should  change to stop and stop should stop the current message and the bubble should display stoped by the user
10.) the page does not yield a plan.
12 .) the page size is not optimal  for a left right top format ( the scroll center should be bigger ) it should take all of the height minus what it takes to render the chat box on the bottom . If I have a large Plan or a PRD in the sidebar it will push down the chat box beyond the fold of the screen .
