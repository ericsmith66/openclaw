#### PRD-WF-01: Generalize Base Rules & Fix Commit Policy

**Log Requirements**
- Create/update a task log under `knowledge_base/prds-junie-log/` on completion.
- Include detailed manual verification steps and expected results.

---

### Overview

The `rails-base-rules.md` file in `ror-agent-config/rules/` is titled "Rails 8 Base Rules for Eureka HomeKit" and contains domain-specific references (e.g., `characteristic_uuid`, `LockControlComponent`, HomeKit webhooks). It also states "NEVER commit without explicit user confirmation," which directly contradicts the agreed workflow commit policy. The `delegation-rules.md` prompt and agent system prompts also carry inconsistent commit language.

This PRD generalizes the base rules to be project-agnostic and aligns the commit policy across all config files to: "Commit plans always; commit code when tests pass (green)."

---

### Requirements

#### Functional

1. **Generalize `rails-base-rules.md`**
   - Remove all HomeKit-specific references: `Eureka HomeKit`, `characteristic_uuid`, `LockControlComponent`, HomeKit webhooks, and any other domain-specific terms.
   - Keep all generic Rails 8 conventions: idiomatic Ruby, Minitest, service objects, ViewComponents, DaisyUI/Tailwind, Turbo/Hotwire.
   - Update the title from "Rails 8 Base Rules for Eureka HomeKit" to "Rails 8 Base Rules".

2. **Fix commit policy in `rails-base-rules.md`**
   - Replace "NEVER run destructive git commands or commit without explicit user confirmation" with:
     - "Commit plans always."
     - "Commit code when tests pass (green)."
     - "NEVER run destructive git commands (drop, reset, truncate) without explicit user confirmation."

3. **Fix commit policy in `delegation-rules.md`**
   - Locate the commit-related instructions.
   - Add explicit green gate: "Commit code only when all tests pass."
   - Ensure plan commits are unconditional.

4. **Fix commit policy in `ror-rails` agent system prompt**
   - Update the COMMIT LOGIC section in `ror-rails/config.json` to reflect the agreed policy.

#### Non-Functional

- No behavioral changes to agent execution — only config text changes.
- All changes target `ror-agent-config/` source files, not `.aider-desk/` runtime files.

---

### Error Scenarios & Fallbacks

- **HomeKit reference missed**: Grep for `homekit`, `eureka`, `characteristic_uuid`, `LockControlComponent` across all config files after changes. Any hit is a failure.
- **Commit policy inconsistency**: Grep for `NEVER commit`, `explicit user confirmation`, `without.*confirmation` across all config files. Any hit contradicting the new policy is a failure.

---

### Architectural Context

This PRD is the foundation for all other PRDs in the epic. The base rules file and delegation rules are loaded by every agent at runtime. If they contain domain-specific references or contradictory policies, all downstream commands will inherit those problems. This must be completed before creating new command files (WF-02) or updating agent prompts (WF-04).

---

### Acceptance Criteria

- [ ] `rails-base-rules.md` title is "Rails 8 Base Rules" (no HomeKit reference).
- [ ] Zero occurrences of `Eureka`, `HomeKit`, `characteristic_uuid`, `LockControlComponent` in `rails-base-rules.md`.
- [ ] `rails-base-rules.md` commit policy says "Commit plans always; commit code when tests pass (green)."
- [ ] `rails-base-rules.md` still prohibits destructive git commands without confirmation.
- [ ] `delegation-rules.md` includes green gate for code commits.
- [ ] `delegation-rules.md` allows unconditional plan commits.
- [ ] `ror-rails/config.json` system prompt commit logic matches the agreed policy.
- [ ] Grep across all `ror-agent-config/` files returns zero contradictory commit policy statements.
- [ ] All generic Rails 8 conventions (Minitest, service objects, ViewComponents, etc.) are preserved in `rails-base-rules.md`.

---

### Test Cases

#### Validation (grep-based — no application tests)

- `grep -ri "homekit\|eureka\|characteristic_uuid\|LockControlComponent" ror-agent-config/`: expect zero results.
- `grep -ri "NEVER commit\|without explicit user confirmation" ror-agent-config/`: expect zero results (except the destructive-commands clause).
- `grep -ri "commit.*plan" ror-agent-config/rules/rails-base-rules.md`: expect "Commit plans always."
- `grep -ri "commit.*code.*green\|commit.*code.*tests pass" ror-agent-config/rules/rails-base-rules.md`: expect match.

---

### Manual Verification

1. Open `ror-agent-config/rules/rails-base-rules.md`.
2. Confirm title is "Rails 8 Base Rules".
3. Search for "HomeKit" — expect zero results.
4. Search for "commit" — confirm policy matches "commit plans always; commit code when green."
5. Open `ror-agent-config/prompts/delegation-rules.md`.
6. Search for "commit" — confirm green gate is present for code, unconditional for plans.
7. Open `ror-agent-config/agents/ror-rails/config.json`.
8. Read system prompt — confirm commit logic matches policy.

**Expected**
- All three files reflect the agreed commit policy with no HomeKit references.
