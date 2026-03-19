<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic-4/PRD-4-01-saprun-schema-persona-config.md
-->

#### PRD-{{N-XX}}: {{Title}}

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---
 
### Overview

{{1–2 paragraphs describing the problem, what will be built, and why.}}

---

### Requirements

#### Functional

- {{Requirement 1}}
- {{Requirement 2}}

#### Non-Functional

- {{Performance / reliability / security constraints}}

#### Rails / Implementation Notes (optional)

- {{Models / controllers / components / background jobs / migrations involved}}
- {{Routes / endpoints}}
- {{Feature flags (if any)}}

---

### Error Scenarios & Fallbacks

- {{Scenario}} → {{Expected behavior / fallback}}
- {{Scenario}} → {{Expected behavior / fallback}}

---

### Architectural Context

{{Explain how this PRD fits into the current architecture, key boundaries, and any explicit non-goals.}}

---

### Acceptance Criteria

- [ ] {{AC 1}}
- [ ] {{AC 2}}
- [ ] {{AC 3}}

---

### Test Cases

#### Unit (Minitest)

- {{test file path}}: {{what it covers}}

#### Integration (Minitest)

- {{test file path}}: {{what it covers}}

#### System / Smoke (Capybara)

- {{test file path}}: {{what it covers}}

---

### Manual Verification

Provide step-by-step instructions a human can follow.

1. {{Step}}
2. {{Step}}

**Expected**
- {{Expected result}}

---

### Rollout / Deployment Notes (optional)

- {{Migrations / backfills}}
- {{Monitoring / logging}}
