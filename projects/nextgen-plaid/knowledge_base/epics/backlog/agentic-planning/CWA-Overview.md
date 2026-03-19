Based on the codebase analysis, here is the overview of how the **CWA (Code Writing Agent)** plans its work and how the **Sandbox** provides a safe environment for it to operate.

### 1. How CWA Planning Works
The CWA doesn't just "spit out code." It follows a collaborative, multi-step lifecycle designed to ensure technical accuracy and security.

*   **Step 1: The Code Plan**: Upon receiving a PRD, the CWA is designed to generate a "Code Plan" (stored in `tmp/agent_sandbox`). This plan identifies which files to create, which to modify (refactors), and what terminal commands (migrations, installs) are needed.
*   **Step 2: Execution & Handover**: The CWA writes the files into the sandbox and then hands over the "execution list" to the **CSO (Chief Security Officer agent)** via the `cwa_to_cso` queue.
*   **Step 3: The Security Loop**:
    *   The CSO evaluates the proposed code and commands.
    *   If **Approved**: The CWA proceeds with the final execution (merging/committing).
    *   If **Denied**: The CWA enters a **Revision Phase** (`handle_security_feedback`), where it uses the security feedback to rewrite the code, iterating up to 3 times before either succeeding or halting.

---

### 2. What is the Sandbox?
The Sandbox is a **physically isolated copy of your repository** created specifically for a single agent run. It ensures that if an agent makes a mistake (like `rm -rf /`), it only happens in a temporary folder, never in your main codebase.

#### How it Works: Git Worktrees
Instead of just copying files, the system uses **Git Worktrees** (`app/services/agent_sandbox_runner.rb`):
*   **Isolation**: When the CWA starts, the system creates a new git worktree in `tmp/agent_sandbox/[correlation_id]/repo`.
*   **Unique Branching**: It automatically creates a correlation-specific branch (e.g., `feature-xyz-12345`) so the agent’s work is tracked in git but doesn't touch your `main` branch.
*   **Independent Process**: Commands are executed via an out-of-process runner (`script/agent_sandbox_runner`). This "wrapper" script manages timeouts and enforces security.

---

### 3. Sandbox Security Guardrails
The sandbox isn't just a folder; it's a restricted environment:
*   **`AGENT_SANDBOX_ACTIVE`**: A special environment variable is set to `1`. If an agent tries to run a tool that would create *another* sandbox, the system detects this "nesting" and blocks it to prevent recursive loops.
*   **Hard-Disabled Prompts**: Git is configured to never ask for a username/password or interactive input, preventing the agent from getting stuck or trying to bypass auth.
*   **Tool Restricted**: Tools like `GitTool` and `SafeShellTool` check `require_sandbox!`. They will refuse to run unless they detect they are operating within one of these authorized worktrees.

### Summary of the CWA + Sandbox Flow
1.  **SAP Agent** creates the PRD.
2.  **CWA** receives PRD → Initializes **Sandbox Worktree**.
3.  **CWA** generates Code Plan + Files in the Sandbox.
4.  **CSO** reviews the Sandbox.
5.  **CWA** executes/merges only after approval.

This combination of **Plan-based execution** and **Worktree-based isolation** is what makes the CWA safe to run on your dedicated Mac Studio Ultra. It can "try out" migrations and code changes without ever risking the stability of your primary development environment.