# Junie Guidelines — `euraka-homekit`

These guidelines are **project-specific operating rules** for Junie/AI assistants working in this repository.

They are written to be:
- **Actionable** (clear do/don’t)
- **Safe** (avoid destructive commands)
- **Consistent** (match repo conventions)

---

## 1) Repo overview (what this is)

- Ruby on Rails application.
- UI work frequently uses:
  - Hotwire/Turbo (`turbo_frame_tag`)
  - ViewComponent (components under `app/components/...`)
  - DaisyUI/Tailwind classes for styling.
- Tests use **Minitest** (`test/`), including `ViewComponent::TestCase` and Capybara system tests.
- Product docs live in `knowledge_base/` (Epics, PRDs, templates, task logs).

---

## 2) Critical communication rule (prevents the “continue loop”)

Junie sessions may show a **timeout/keep-alive prompt** asking the human to “continue.”

### Interpretation rule
- A bare message like `continue` (or similar) should be treated as **keep-alive only**.
- **Do not** re-run tests, re-check status, or repeat progress updates just because of `continue`.
- **If you have no task remaining** Post a **single explicit completion message**: STATUS: DONE — awaiting review (no commit yet) Then quit the task.

### When work is complete
When implementation is done and tests are green:
1. Post a **single explicit completion message**:
  - `STATUS: DONE — awaiting review (no commit yet)`
2. Then quit the task


---

## 3) Safety rails (do not break the dev environment)

### Database safety (high priority)
Development DB was previously dropped accidentally during testing.

Rules:
- **Never** run destructive DB commands without explicit user confirmation:
  - `db:drop`, `db:reset`, `db:truncate`, `db:migrate:reset`, etc.
- If you must run DB commands for tests, **always** scope to test:
  - Prefer `RAILS_ENV=test bin/rails ...` when applicable.
- If unsure which environment a command affects, **ask first**.

### Git safety
- Do **not** commit unless the human explicitly asks.
- Avoid generating unrelated diffs (e.g., newline-only changes) — keep PRD diffs focused.

---

## 4) Implementation conventions

### Components
- Prefer ViewComponents for dashboard/widgets.
- Mirror existing patterns in `app/components/net_worth/`.
- Use defensive access for snapshot JSON:
  - tolerate missing keys and empty arrays/hashes
  - provide an empty-state UI instead of crashing
  - log/report corrupt payloads (Sentry if present; fallback to `Rails.logger`).

### Styling
- Use DaisyUI/Tailwind utility classes.
- Mobile-first responsive layout.

### Accessibility
- Provide meaningful headings/labels.
- Use `aria-label` where helpful for stat cards/controls.
- Provide non-visual fallback where appropriate (e.g., tables for charts).

---

## 5) Testing expectations

### Default test stack
- Use **Minitest** (do not introduce RSpec unless explicitly requested).

### What to add
- For new ViewComponents:
  - Add a component unit test under `test/components/...`.
- For wiring changes:
  - Update/add an integration test under `test/integration/...`.
  - Update/add smoke/system tests under `test/smoke/...` if appropriate.

### How to run
- Prefer smallest relevant set first, then broaden.
- Typical commands:
  - `bin/rails test test/components/...`
  - `bin/rails test test/integration/...` 
  - `bin/rails test test/smoke/...`
  - `bin/rails test` (full suite)

--- 

## 6) Documentation requirements (PRD workflow)

### Use the Knowledge Base templates (start here)

When creating new Epic/PRD docs, start from the templates under `knowledge_base/templates/` (based on `knowledge_base/epics/wip/NextGen/Epic-4`).

- Epic overview: copy `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md` into your epic directory and rename to `0000-overview-...md`.
- Implementation status tracker: copy `knowledge_base/templates/0001-IMPLEMENTATION-STATUS-template.md` and rename to `0001-IMPLEMENTATION-STATUS.md`.
- PRD: copy `knowledge_base/templates/PRD-template.md` and rename to `PRD-<epic>-<nn>-<slug>.md`.

Keep epic docs together under:
- `knowledge_base/epics/wip/<Program>/<Epic-N>/`

Minimum expected set in an epic directory:
- `0000-overview-...md`
- `0001-IMPLEMENTATION-STATUS.md`
- `PRD-<epic>-<nn>-<slug>.md` (one per PRD)

When implementing a PRD that requires a Junie log:
- Create/update a task log under `knowledge_base/prds-junie-log/`.
- Record:
  - files changed
  - commands run
  - tests run + results
  - manual verification steps

When tests are green:
- Update `knowledge_base/epics/wip/.../0001-IMPLEMENTATION-STATUS.md` as required.

---

## 7) Output/interaction style

- Be concise and explicit.
- When blocked or ambiguous, ask a direct question with options.
- After finishing work, stop and wait for review instructions.

## 8) Epic & PRD workflow
- When I ask you to review a Epic or PRD responde with a file in the same directory as the file I asked you to review
- Title the review document as <source-document>-feedback-V<1..N>.md
- When reviewing, provide quesitons, suggestions, improvements and objections. I you provided objections or provide potential solutions

## 9) Implementing Epic's and PRD's
- consider the epic overview in the same directory
- read the ####-IMPLEMENTATION-STATUS.md or create it if it does not exist
- implement the epic or prd
- at the end of the epic update  ####-IMPLEMENTATION-STATUS.md as necessary
