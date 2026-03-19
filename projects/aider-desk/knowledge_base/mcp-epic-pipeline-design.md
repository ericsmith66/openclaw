# Technical Design Document: MCP-Driven "Epic-to-Code" Pipeline

## 1. Overview
This document outlines the architecture for integrating Agent-Forge (AiderDesk) with an internal product management system via the Model Context Protocol (MCP). The goal is to create a seamless loop where an AI Agent can autonomously fetch Epics/PRDs stored as JSONB in a database, perform technical reviews, and execute code implementations within a local repository.

## 2. System Architecture

### 2.1 Component Diagram
```
[ AiderDesk Agent ] <--> [ MCP Client (AiderDesk) ]
                                |
                                | (MCP over Stdio/HTTP)
                                v
[ Database (Postgres) ] <--> [ Custom MCP Server ]
(Epics/PRDs in JSONB)        (Node.js / TypeScript)
```

### 2.2 Data Model (JSONB structure)
The MCP server expects a `documents` table with the following JSONB structure for Epics:
```json
{
  "id": "EPIC-001",
  "title": "OAuth2 Integration",
  "status": "active",
  "prd": {
    "requirements": [...],
    "acceptance_criteria": [...],
    "technical_constraints": [...]
  },
  "feedback_loop": [
    {"author": "agent", "content": "...", "timestamp": "..."}
  ],
  "implementation_plan": {
    "steps": [...],
    "last_updated": "..."
  }
}
```

## 3. MCP Tool Specification & Examples

The MCP server must implement the following tools. Each tool includes the Zod schema and example JSON communication.

### 3.1 `list_active_epics`
*   **Purpose:** Discovery of work items.
*   **Request Schema:**
    ```typescript
    const ListActiveEpicsSchema = z.object({
      limit: z.number().optional().default(10)
    });
    ```
*   **Example MCP Request:**
    ```json
    { "method": "tools/call", "params": { "name": "list_active_epics", "arguments": { "limit": 5 } } }
    ```
*   **Example MCP Response:**
    ```json
    {
      "content": [
        {
          "type": "text",
          "text": "[{\"id\": \"EPIC-101\", \"title\": \"User Auth Refactor\"}, {\"id\": \"EPIC-102\", \"title\": \"Payment Gateway\"}]"
        }
      ]
    }
    ```

### 3.2 `get_epic_details`
*   **Purpose:** Hydrating the Agent's context with the PRD.
*   **Request Schema:**
    ```typescript
    const GetEpicDetailsSchema = z.object({
      epic_id: z.string().describe("The unique ID of the epic (e.g. EPIC-101)")
    });
    ```
*   **Example MCP Request:**
    ```json
    { "method": "tools/call", "params": { "name": "get_epic_details", "arguments": { "epic_id": "EPIC-101" } } }
    ```
*   **Example MCP Response:**
    ```json
    {
      "content": [
        {
          "type": "text",
          "text": "{\"id\": \"EPIC-101\", \"prd\": {\"description\": \"Migrate to JWT\", \"criteria\": [\"No session stickiness\"]}}"
        }
      ]
    }
    ```

### 3.3 `submit_epic_feedback`
*   **Purpose:** Closing the loop with product owners.
*   **Request Schema:**
    ```typescript
    const SubmitFeedbackSchema = z.object({
      epic_id: z.string(),
      feedback: z.string(),
      aspect: z.enum(["architecture", "security", "clarity"])
    });
    ```
*   **Example MCP Request:**
    ```json
    {
      "method": "tools/call",
      "params": {
        "name": "submit_epic_feedback",
        "arguments": {
          "epic_id": "EPIC-101",
          "feedback": "PRD doesn't specify token rotation policy.",
          "aspect": "security"
        }
      }
    }
    ```

### 3.4 `sync_implementation_plan`
*   **Purpose:** Transparency of the Agent's intent.
*   **Request Schema:**
    ```typescript
    const SyncPlanSchema = z.object({
      epic_id: z.string(),
      plan: z.array(z.object({
        task: z.string(),
        status: z.enum(["pending", "done"])
      }))
    });
    ```
*   **Example MCP Request:**
    ```json
    {
      "method": "tools/call",
      "params": {
        "name": "sync_implementation_plan",
        "arguments": {
          "epic_id": "EPIC-101",
          "plan": [{"task": "Define JWT secrets", "status": "pending"}]
        }
      }
    }
    ```

## 4. End-to-End Execution Scenario

1.  **Selection:** Agent calls `list_active_epics` -> User picks "User Auth Refactor".
2.  **Context:** Agent calls `get_epic_details` -> Learns that PRD requires "JWT Migration".
3.  **Review:** Agent reads `src/auth.ts`. Notices existing middleware uses Redis sessions.
4.  **Interaction:** Agent calls `submit_epic_feedback` -> "Warning: Switching to JWT will bypass the existing Redis rate limiter. Recommend updating rate limiter too."
5.  **Planning:** Agent generates a 5-step implementation plan. Calls `sync_implementation_plan` to push it to the DB.
6.  **Coding:** Agent uses **`aider` tool** to rewrite `auth.ts` and update the rate limiter middleware.
7.  **Completion:** Agent updates the implementation plan status in the DB via MCP.

## 5. Interaction Lifecycle (Logic Flow)

### Phase 1: Context Retrieval
1.  **User:** "Show me active epics from the DB."
2.  **Agent:** Calls `list_active_epics`.
3.  **Agent:** Displays a list. User selects `EPIC-001`.
4.  **Agent:** Calls `get_epic_details("EPIC-001")`. The PRD is now in the Agent's context.

### Phase 2: Technical Review
1.  **Agent:** Analyzes the local codebase vs. the PRD requirements.
2.  **Agent:** Identifies that the PRD misses a specific edge case (e.g., token expiration).
3.  **Agent:** Calls `submit_epic_feedback` to document this in the source-of-truth system.

### Phase 3: Planning & Execution (The "Bridge")
1.  **Agent:** Generates an internal AiderDesk Implementation Plan (Todos).
2.  **Agent:** Calls `sync_implementation_plan` so stakeholders can see the progress in the main app.
3.  **Agent:** Uses AiderDesk's **built-in `aider` tools** to begin writing code in the local repo that satisfies the PRD.

## 5. Implementation Details (MCP Server)

### Technology Stack:
*   **Runtime:** Node.js (TypeScript)
*   **MCP SDK:** `@modelcontextprotocol/sdk`
*   **DB Client:** `pg` (node-postgres)
*   **Validation:** `zod`

### Example Endpoint Implementation (Internal Logic):
```typescript
server.tool(
  "submit_epic_feedback",
  { epic_id: z.string(), feedback: z.string() },
  async ({ epic_id, feedback }) => {
    const query = `
      UPDATE epics
      SET content = jsonb_set(content, '{feedback_loop}',
                    content->'feedback_loop' || $2::jsonb)
      WHERE id = $1`;
    await db.query(query, [epic_id, JSON.stringify({ agent: "AiderDesk", feedback, date: new Date() })]);
    return { content: [{ type: "text", text: "Feedback synced to database." }] };
  }
);
```

## 6. Testing Strategy

### 6.1 Unit Testing (MCP Logic)
*   Use `vitest` to mock the Database connection.
*   Verify that tool handlers return valid MCP `CallToolResult` objects.
*   Test Zod schema validation by passing malformed JSON to the tools.

### 6.2 Integration Testing (The Loop)
*   **Mock MCP Client:** Create a script that acts as an MCP client (using the SDK) to call the server via STDIO and verify DB state changes.
*   **AiderDesk "Dry Run":**
    1. Start the MCP server locally.
    2. Configure AiderDesk to point to the server.
    3. Run a prompt: *"Identify the current active epic and tell me its title."*
    4. Success is defined by the Agent correctly parsing the MCP response.

### 6.3 Security & Safety
*   **Read-Only Scopes:** Ensure the DB user for MCP has restricted access (e.g., cannot drop tables).
*   **User Approval:** In AiderDesk, set `submit_epic_feedback` and `sync_implementation_plan` to `Approval: Ask`. This creates a human-in-the-loop requirement before the DB is modified.

## 7. Future Scalability: "The Big Picture"
By moving the implementation plans into the DB via MCP, multiple Agents (or human developers) can subscribe to the same JSONB field. AiderDesk becomes the **Execution Engine** for a larger, multi-agent product lifecycle.
