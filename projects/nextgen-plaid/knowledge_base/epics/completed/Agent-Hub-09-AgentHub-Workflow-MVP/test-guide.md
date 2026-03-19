# Test Guide: Agent Hub Workflow & CWA Autonomous Spike (Epics 9 & 10)

This guide provides comprehensive test cases for verifying the Agent Hub Workflow MVP (Epic 9) and the CWA Autonomous Implementation Spike (Epic 10). It covers system health, artifact management, slash commands, workflow UI, and autonomous execution.

## 1. Prerequisites
- Authenticated as a user with **Admin** roles.
- `SMART_PROXY_URL` configured (default: `http://localhost:3002`).
- `CLOUDFLARE_CHECK_ENDPOINTS` set to a comma-separated list of URLs (e.g., `https://api.higroundsolutions.com`).
- ActionCable server running and accessible.

---

## 2. Test Suite A: System Health Dashboard (PRD-AH-009A)

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| A.1 | Access Health Dashboard | Admin | Navigate to `/admin/health` | Page loads with cards for Proxy, Worker, ActionCable, and Cloudflare. |
| A.2 | Proxy Status Check | System | View "Proxy Health" card | Shows "OK" if Proxy responds to `/health`. Shows "FAIL" and error message otherwise. |
| A.3 | Version Consistency | System | View "Worker & Version Consistency" card | Displays Web Version and Worker Version. Versions should match for production environments. |
| A.4 | ActionCable Readiness | System | View "ActionCable Status" card | Shows "OK" if Action Cable server is mounted. |
| A.5 | Cloudflare Monitoring | System | View "Cloudflare Endpoints" card | Lists status for each URL in `CLOUDFLARE_CHECK_ENDPOINTS`. Checks should use HTTPS (port 443). Ensure env is a URL list, not just "true". |

---

## 3. Test Suite B: Artifact Store & State Machine (PRD-AH-009B)

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| B.1 | Artifact Creation | System | Create via Console: `Artifact.create!(name: "Test", artifact_type: "feature")` | `phase` defaults to `backlog`. `owner_persona` is assigned (SAP) automatically. |
| B.2 | Initial Transition | Human | Open Agent Hub chat; type `/approve` on a `backlog` artifact; click "Approve Now" in bubble | Phase moves to `ready_for_analysis`. `owner_persona` becomes `SAP`. |
| B.3 | Ownership Handoff | Human | Type `/approve` in Agent Hub chat on `ready_for_analysis` artifact; click "Approve Now" | Phase moves to `in_analysis`. `owner_persona` becomes `Coordinator`. |
| B.4 | Audit Trail Integrity | System | Inspect `artifact.payload['audit_trail']` | Contains an entry for every transition with `from_phase`, `to_phase`, `action`, `actor_persona`, and `timestamp`. |
| B.5 | Optimistic Locking | Human | Attempt to update the same artifact simultaneously in two windows | The second update should fail with an `ActiveRecord::StaleObjectError`. |

---

## 4. Test Suite C: Linking & Context (PRD-AH-009C)

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| C.1 | Link Card Visibility | Human | Navigate to Agent Hub with an active artifact linked to the run | A link card appears in the header showing: Artifact Name, Current Phase, and "View in Workflow UI" link. |
| C.2 | Dynamic Phase Update | System | Update artifact phase in background | The link card's badge updates to reflect the new phase (via Page Refresh or ActionCable). |
| C.3 | Context Retrieval | Human | Click "Inspect Context" (or use `inspect_context` API) | Returns JSON containing current RAG prefix, including persona-specific instructions. |

---

## 5. Test Suite D: Status Movers & Slash Commands (PRD-AH-009D)

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| D.1 | Approval Loop (Happy Path) | Human | Type `/approve` in Chat Input | A `ConfirmationBubbleComponent` appears with "Approve Now" button. |
| D.2 | Confirmation Execution | Human | Click "Approve Now" in the bubble | Bubble shows "Processing...", then "Confirmed". System message: "Artifact '...' moved to phase: ... Assigned to: ..." |
| D.3 | Rejection/Rework | Human | Type `/reject` in Chat Input | Confirmation bubble appears with "Reject/Rework". Clicking it moves the artifact back one phase and reassigns owner. |
| D.4 | Auto-Artifact Spike | Human | Type `/approve` when NO artifact is linked | System creates a new `Artifact` and `AiWorkflowRun` automatically from the conversation context. |
| D.5 | SAP Backlog Retrieval | Human | In SAP tab, type "show me the backlog" | SAP lists backlog items with their IDs and names (from RAG context). |
| D.6 | SAP Artifact Selection | Human | In SAP tab, type "lets work on backlog item <ID>" | SAP responds with a confirmation and triggers an "Approve Now" bubble for that specific ID. |

---

## 6. Test Suite E: Workflow UI Hooks (PRD-AH-009E)

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| E.1 | Workflow List | Admin | Navigate to `/admin/ai_workflow` | Displays all artifacts ordered by most recent update. |
| E.2 | Artifact Details | Admin | Select an artifact from the list | Displays detailed view with Tabs: Artifact Data, Ownership, Context, and Logs. |
| E.3 | Log Inspection | Admin | Click "Logs" tab in Artifact Detail | Displays the full audit trail of state transitions. |
| E.4 | Cross-Link | Admin | Click "View in Workflow UI" from Agent Hub | Correct artifact is highlighted/selected in the Workflow UI. |

---

## 7. Test Suite F: CWA Autonomous Spike (Epic 10)

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| F.1 | Trigger Autonomous Spike | Human | Type `/spike` in Agent Hub (with active PRD) | System broadcasts: "🚀 Launching autonomous spike...". Background job starts `AiWorkflowService`. **Artifact transitions through analysis phases automatically.** |
| F.2 | Orchestration: Planning | System | Automated turn in `AiWorkflowService` | Coordinator hands off to Planner; Planner uses `TaskBreakdownTool` to generate micro-tasks. **The plan is automatically broadcasted to the Agent Hub chat, and the artifact moves to `ready_for_development_feedback`.** |
| F.3 | Orchestration: Implementation | System | Automated turn in `AiWorkflowService` | Planner/Coordinator hands off to CWA; CWA initializes sandbox worktree. |
| F.4 | RAG Injection Verification | System | Inspect `agent_logs/ai_workflow/<id>/events.ndjson` | Verify `eric_grok_static_rag.md` is included in the CWA system prompt. |
| F.5 | Sandbox Execution | System | CWA agent tool calls | CWA uses `GitTool`, `SafeShellTool` (rails test), and `VcTool` to implement and verify code. |
| F.6 | Success Loopback | System | Autonomous run finishes successfully | Artifact moves to `ready_for_qa`. `implementation_notes` (diff + test results) attached to payload. |
| F.7 | Failure Loopback | System | Autonomous run fails (e.g., tests fail) | Artifact moves back to `in_analysis`. System broadcasts failure notification. |
| F.8 | Manual Plan Verification | Human | Type `/inspect` | Detailed view of the technical plan (micro-tasks) appears in chat. |

---

## 8. Test Suite G: Port Forwarding (80 -> 3000)

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| G.1 | Local Port 80 Access | Human | Run `curl -I http://127.0.0.1` | Returns HTTP 200 (or redirect) from the Rails app on port 3000. |
| G.2 | Network Port 80 Access | Human | From another machine (192.168.4.200), run `curl -I http://192.168.4.253` | Returns HTTP 200. Confirms `en0` redirection works. |
| G.3 | PF Rule Verification | Human | Run `sudo pfctl -a com.nextgen.plaid -s nat` | Shows `rdr pass` rules for both `lo0` and `en0`. |
| G.4 | Persistence Check | Human | Reboot the machine | Port 80 remains forwarded automatically (via LaunchDaemon). |

---

### 10. Test Suite H: Human Language Backlog Retrieval

| Case ID | Scenario | Actor | Inputs/Actions | Expected Results |
|:--- |:--- |:--- |:--- |:--- |
| H.1 | List Backlog (Natural Language) | Human | In Agent Hub (SAP persona), type: "show me the backlog" | SAP responds with a list of artifacts in the `backlog` phase, including their IDs and Names. |
| H.2 | Select Backlog Item (Natural Language) | Human | In Agent Hub (SAP persona), type: "lets work on backlog item <ID>" | SAP confirms and triggers a "Approve Now" confirmation bubble for that specific artifact. |
| H.3 | Cross-Persona Backlog Check | Human | Switch to Coordinator persona; type: "show me the backlog" | Coordinator should see their assigned artifacts, NOT the general backlog. |
| H.4 | Coordinator Artifact Selection | Human | In Agent Hub (Coordinator persona), type: "lets work on item <ID>" | Coordinator confirms and triggers an "Approve Now" confirmation bubble for their assigned artifact. |

### 9. Slash Command Syntax Reference

| Command | Syntax | Description |
|:--- |:--- |:--- |
| **Approve** | `/approve` | Triggers a confirmation bubble to move the active artifact to the next phase. |
| **Reject** | `/reject` | Triggers a confirmation bubble to move the active artifact back one phase (Rework). |
| **Backlog** | `/backlog <Description>` | Creates a new backlog item with the provided description. |
| **Move to Backlog** | `/backlog` | (Without arguments) Triggers a confirmation bubble to move the active artifact to the `backlog` phase. |
| **Spike** | `/spike` | Launches an autonomous CWA spike for the active artifact/PRD. |
| **Plan** | `/plan` | Launches an autonomous planning session for the active artifact. |
| **Inspect** | `/inspect` | Displays the current active artifact's details, PRD content, and autonomous Technical Plan (micro-tasks) in a human-friendly format. |
| **Save** | `/save <content>` | Manually updates the active artifact's PRD content with the provided text. |

---

### 10. SDLC Workflow Reference: Phases & Actions

| Phase | Description | Owner | Available Commands | User Action Required |
|:--- |:--- |:--- |:--- |:--- |
| **Backlog** | Initial entry point for ideas. | SAP | `/approve`, `/backlog <text>`, `/inspect` | Discuss feature; type `/approve` to move to Analysis. |
| **Ready for Analysis** | Waiting for SAP to perform deep dive. | SAP | `/approve`, `/reject`, `/inspect`, `/save` | Confirm PRD/Tech specs; type `/approve` to hand off to Coordinator. |
| **In Analysis** | Coordinator is planning/questioning. | Coordinator | `/plan`, `/approve`, `/reject`, `/inspect`, `/save` | Ask questions or type `/plan` for autonomous breakdown. Use `/inspect` to view the plan. |
| **Ready for Dev Feedback** | SAP reviews the technical plan. | SAP | `/approve`, `/reject`, `/inspect`, `/save` | Verify micro-tasks/risks; type `/approve` to move to Development. |
| **Ready for Development** | Feature is in CWA's queue. | CWA | `/spike`, `/approve`, `/reject`, `/inspect` | Type `/spike` to start autonomous coding. |
| **In Development** | CWA is actively implementing code. | CWA | `/approve`, `/reject`, `/inspect` | Monitor progress in logs; type `/approve` once tests pass. |
| **Ready for QA** | Coordinator performs final checks. | Coordinator | `/approve`, `/reject`, `/inspect` | Verify implementation; type `/approve` to mark as Complete. |
| **Complete** | Feature is shipped/finished. | Human | `/inspect` | None. |

### How to Save Your Work:
The system uses **Automated Persistence** during workflow transitions:
1.  **State Save:** Every time you click "Approve Now" or "Reject/Rework", the system automatically saves the artifact's state, owner, and audit trail to the database.
2.  **Manual Update:** To manually update the content of an active artifact (e.g., to refine a PRD), use:
    *   Syntax: `/save <The new PRD markdown content>`
3.  **Manual Draft:** To manually save a new idea without starting a workflow, use:
    *   Syntax: `/backlog <Your feature description>`
4.  **Conversation Persistence:** All chats are automatically saved to the linked `SapRun`. You can "save" your place simply by stopping; the system will pick up where you left off when you reload the session.

---

## 11. Verification Checklist (Post-Run)
- [ ] Artifact `lock_version` incremented?
- [ ] Audit trail captures the correct `actor_persona`?
- [ ] `owner_persona` matches the mapping in `artifact.rb`?
- [ ] ActionCable broadcasts received in real-time?
- [ ] Admin permissions enforced on `/admin/*` routes?
- [ ] **(Epic 10)** `/spike` trigger successfully launched background `AiWorkflowService`?
- [ ] **(Epic 10)** `implementation_notes` contains actual `git diff` and `test results` on success?
- [ ] **(Epic 10)** RAG context included `eric_grok_static_rag.md` architectural patterns?
