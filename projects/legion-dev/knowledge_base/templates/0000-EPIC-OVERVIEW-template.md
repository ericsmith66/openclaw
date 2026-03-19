<!--
  Epic Overview Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/<0000-overview-...>.md

  This template is based on the structure used in:
    knowledge_base/epics/wip/NextGen/Epic-4/0000-overview-epic-4.md
-->

**Epic {{N}}: {{Epic Title}}**

**Epic Overview**
{{1–2 paragraphs describing the goal, the user-facing outcome, and how it differs from existing features.}}

**User Capabilities**
- {{Capability 1}}
- {{Capability 2}}
- {{Capability 3}}

**Fit into Big Picture**
{{Explain why this epic exists and how it connects to current/next epics.}}

**Reference Documents**
- {{Link to relevant docs, PRDs, prior epics, style guide, patterns}}

---

### Key Decisions Locked In

Capture decisions that should not be re-litigated during implementation.

**Architecture / Boundaries**
- {{New models/services/components}}
- {{What is explicitly out of scope}}

**UX / UI**
- {{Layout decisions}}
- {{Mobile behavior}}

**Testing**
- {{Minitest / system tests / component tests expectations}}

**Observability**
- {{Rails.logger / Sentry / metrics decisions}}

---

### High-Level Scope & Non-Goals

**In scope**
- {{Item}}

**Non-goals / deferred**
- {{Item}}

---

### PRD Summary Table

List each PRD as an “atomic” chunk that can be implemented and validated independently.

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| {{N-01}} | {{Title}} | {{Scope}} | {{Depends on}} | {{branch name}} | {{notes}} |
| {{N-02}} | {{Title}} | {{Scope}} | {{Depends on}} | {{branch name}} | {{notes}} |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**: {{guardrails}}
- **Components**: {{where components live, patterns to follow}}
- **Data Access**: {{scoping, performance, anti-N+1}}
- **Error Handling**: {{fallback patterns}}
- **Empty States**: {{required empty states}}
- **Accessibility**: {{WCAG target, keyboard nav expectations}}
- **Mobile**: {{touch targets, drawer behavior, viewports}}
- **Security**: {{auth/scoping, channel naming, etc.}}

Replace the angle-bracket placeholders with real content (use `{{...}}` placeholders in this template to avoid Markdown/HTML parsing issues).

---

### Implementation Status Tracking

- Create `0001-IMPLEMENTATION-STATUS.md` in the epic directory before starting PRD work.
- Update it after each PRD completion.

---

### Success Metrics

- {{Metric 1}}
- {{Metric 2}}

---
 
### Estimated Timeline (optional)

- PRD {{N-01}}: {{estimate}}
- PRD {{N-02}}: {{estimate}}

---

### Next Steps

1. {{Create/confirm epic directory + overview doc}}
2. {{Create `0001-IMPLEMENTATION-STATUS.md`}}
3. Proceed with PRD {{N-01}}

---

### Detailed PRDs

Full PRD specifications live in separate files, e.g.:
- `PRD-{{N}}-01-{{slug}}.md`
- `PRD-{{N}}-02-{{slug}}.md`
