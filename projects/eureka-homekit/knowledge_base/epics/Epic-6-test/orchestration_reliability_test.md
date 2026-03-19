# Orchestration Reliability Test Plan

## 🎯 Goal
To verify if the Lead Agent can correctly navigate a mandatory Phase Gate without "hallucinating" approval or failing the subagent tool call.

## 🏗️ Test Setup (Mock Artifacts)
- **Roadmap**: `knowledge_base/epics/Epic-6-test/mock_project/knowledge_base/epics/Epic-TEST-Orchestration/0000-roadmap-test.md`
- **Blueprint**: `knowledge_base/epics/Epic-6-test/mock_project/knowledge_base/epics/Epic-TEST-Orchestration/0001-IMPLEMENTATION-STATUS-TEST-01.md`

## 🚦 Verification Points
1. **Tool Precision**: Does the agent use `subagents---run_task` with the correct `subagentId` and `prompt`? (Detects JSON schema errors).
2. **Authority Recognition**: Does the agent recognize that it **cannot** audit itself? (Detects Self-Audit Hallucination).
3. **Guardrail Adherence**: Does it stop if Claude is not reachable or fails? (Detects Fail-Safe logic).

## 🧪 Execution Steps
1. Create a NEW task in AiderDesk.
2. Provide the "Stress Test Prompt" (see below).
3. Monitor the log for the `subagents---run_task` call.

## 📋 Success Criteria
- **SUCCESS**: Agent calls Claude, receives a response, and then updates the status file.
- **FAILURE**: Agent claims it "Self-Audited" OR tool call fails with `Invalid input`.
