# Epic: Framework Hardening & Permissive CWA (Agent-09)

## Epic Goal
Incorporate findings from AGENT-06 integration testing to harden the multi-agent framework. This includes introducing a tiered guardrail system to allow more liberal tool usage in trusted contexts (like CWA in a sandbox), implementing a dedicated `FileWriteTool` to replace risky shell redirections, and refactoring the RAG system into a centralized context factory for better consistency across agents.

## Scope
- **Tiered Guardrails**: Define and implement Low, Medium, and High safety tiers for agents and tools.
- **Permissive CWA Mode**: Substantially reduce restrictions on CWA when operating in High-tier (sandboxed) mode.
- **Dedicated Tooling**: Replace `sh -c "echo ... > file"` with a robust `FileWriteTool`.
- **RAG Refactor**: Centralize RAG logic into a `Ai::ContextFactory` to eliminate duplicate/stale logic between SAP and CWA.
- **Environment Consistency**: Ensure all safety flags and environment variables propagate correctly to out-of-process runners.

## Tiered Guardrail Proposal

### 1. Low Tier (Strict/Read-Only)
- **Use Case**: Default for new/untrusted agents, or production-adjacent read operations.
- **Max Calls/Turn**: 5
- **Execution**: `AI_TOOLS_EXECUTE=false` (Dry-run enforced).
- **Tool Allowlist**: Read-only tools only (`VcTool` status/log, `ProjectSearchTool`, `CodeAnalysisTool`).
- **Shell**: Blocked.

### 2. Medium Tier (Standard/Hybrid)
- **Use Case**: Standard development workflows with human-in-the-loop.
- **Max Calls/Turn**: 10
- **Execution**: `AI_TOOLS_EXECUTE=true` allowed with audit logging.
- **Tool Allowlist**: Standard set (`GitTool`, `SafeShellTool` with basic allowlist, `CodeAnalysisTool`).
- **Shell**: Restricted (no redirections, no pipe).
- **Commits**: Must be green (tests pass).

### 3. High Tier (Liberal/Sandboxed)
- **Use Case**: CWA in a dedicated sandbox for complex implementation tasks.
- **Max Calls/Turn**: 30
- **Execution**: `AI_TOOLS_EXECUTE=true` by default in sandbox.
- **Tool Allowlist**: Full developer suite including `FileWriteTool`.
- **Shell**: Liberal (allows `sh -c`, `grep`, `find`, `sed`).
- **Commits**: "Soft" check (allows `AI_COMMIT_SKIP_TESTS=true` if explicitly flagged by Coordinator).
- **Headroom**: Increased timeouts for complex tool chains.

## RAG Refactor Plan
- Move RAG logic out of `SapAgent::RagProvider` and `AiWorkflowService`.
- Create `Ai::ContextFactory` that takes a `query_type` and `agent_persona` and returns a structured context.
- Support "Static-First" RAG for SAP and "Hybrid" RAG (Static + Codebase) for CWA.

## Atomic PRDs Table
| Priority | Feature | Status | Description |
|----------|---------|--------|-------------|
| 1 | PRD-0060 | Draft | Tiered Guardrails & Permissive CWA Mode |
| 2 | PRD-0061 | Draft | Dedicated FileWriteTool |
| 3 | PRD-0062 | Draft | RAG Service Refactor (Context Factory) |

## Risks / Mitigations
- **Over-Permissioning**: Mitigation: High-tier is *only* active inside the `AgentSandboxRunner` with `AGENT_SANDBOX_ACTIVE=1`.
- **Context Bloat**: Mitigation: `ContextFactory` must implement intelligent truncation and token estimation.
- **Refactor Regression**: Mitigation: Parallel run `RagProvider` and `ContextFactory` during transition with parity tests.
