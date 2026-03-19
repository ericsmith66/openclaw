### Root Cause Analysis: Agent Configuration Duplication & Sync Failures

#### 1. Issue Summary
Users experienced duplicate agent profiles in the AiderDesk UI and persistent issues when trying to build configurations from templates. These issues persisted despite moving to a project-focused implementation and were exacerbated by attempts to use symlinks for configuration management.

#### 2. Primary Root Causes

##### A. Hardcoded Project Paths in Templates
Default agent templates (e.g., `code-checker`, `test-writer`) contained a hardcoded `"projectDir": "/home/wladimiiir/Projects/aider-desk"` in their `config.json` files.
*   **Impact**: When these templates were copied to a different environment, the application logic (specifically `AgentProfileManager`) incorrectly associated these agents with a non-existent directory.
*   **Result**: The UI would show these agents as "foreign" or fail to deduplicate them against local agents, leading to visible duplicates when the user tried to re-sync or create new agents.

##### B. Missing Namespacing in Agent IDs
Initially, agent profiles were identified solely by their `id` (e.g., `ror-rails`).
*   **Impact**: When multiple projects were loaded, each having an agent with the same ID (but different configurations), the internal `profiles` Map in `AgentProfileManager` would experience collisions or the UI would merge them incorrectly.
*   **Result**: Unpredictable behavior where one project's agent might overwrite another's in the UI, or the UI would render multiple entries for the "same" ID.

##### C. Destructive File Sanitization
The `AgentProfileManager` was designed to "sanitize" `config.json` files on load—automatically adding missing IDs, names, and defaults, and then **writing back to the file**.
*   **Impact**: This logic was incompatible with symlinks. The `fs.writeFile` call would replace the symlink with a physical file or fail depending on permissions.
*   **Result**: The "Source of Truth" strategy using symlinks was physically broken by the application itself every time it started.

#### 3. Evaluated Fixes (On `main` branch)

The following fixes were implemented in commits `706f9a75` and `0fc58938` to address these issues:

1.  **Native Project Isolation**:
    *   Moved from a global-only model to a dual-loading model where agents are loaded from both `~/.aider-desk/agents` (Global) and `[project-dir]/.aider-desk/agents` (Project).
2.  **ID Namespacing**:
    *   Updated the backend and renderer to use `projectDir` as a namespace.
    *   Logic like `current.filter((p) => !(p.id === profileId && p.projectDir === projectDir))` ensures that agents with the same ID in different projects are treated as distinct entities.
3.  **Physical Sync Strategy**:
    *   Abandoned symlinks in favor of a script-based physical sync (`scripts/sync-aider-config.sh`).
    *   The script now explicitly injects the *correct* local `projectDir` into the `config.json` using `jq` during the sync process, preventing the "hardcoded path" issue.
4.  **UI De-duplication**:
    *   Implemented explicit de-duplication in `AgentsContext.getProfiles` to ensure that if a global agent and a project agent share an ID, the project-specific one takes precedence.

#### 4. Lessons Learned & Recommendations
*   **Templates must be generic**: Never include environment-specific paths (like `projectDir`) in template files. These should be injected at deployment/sync time.
*   **Namespacing is critical**: In multi-project applications, all user-defined resources must be namespaced by the project path to prevent collisions.
*   **Avoid Auto-Write on Read**: If a configuration manager needs to sanitize files, it should ideally do so in-memory only, or have a very explicit "Save" trigger, rather than writing back on every load.
