### Epic: Manage & Keep Us Upgradable — Branching Strategy

**Epic ID**: `Epic-manage-keep-us-upgradable`
**Created**: 2026-02-18
**Goal**: Make it easy to (1) stay current with upstream, (2) keep our fork stable, and (3) create clean, atomic PRs back to upstream.

---

## 🚨 Non-Optional Policy

This workflow is the epic. **Following it is not optional.**

If we skip steps (“just fix it quickly on `main`”), we accumulate hidden divergence and make upstream merges harder.

**Hard rules:**

1. **Never implement upstream-worthy fixes directly on our fork `main`.**
   - Use `main` only for fork stability and fork-only divergence.
2. **All upstream PR work must happen on a short-lived PR branch** based on `upstream/main` (preferred) or a validated `sync/*` snapshot.
3. **One PR branch = one PRD / one upstream-worthy change.**
4. **Do not include `knowledge_base/**` changes in upstream PRs.**
   - `knowledge_base/**` exists for our fork’s internal process and institutional knowledge.

---

This document is intentionally procedural. If you follow it, you should be able to:
1. Create/refresh a clean “upstream-based” branch line in our fork
2. Generate one PR branch per fix/feature (PRD) with minimal, reviewable diffs
3. Avoid long-lived conflict accumulation

---

#### Reference docs in this repo

- `knowledge_base/epics/Epic-manage-keep-us-upgradable/0000-epic-overview.md`
- `knowledge_base/epics/Epic-manage-keep-us-upgradable/0006-atomic-execution-plan.md`
- `knowledge_base/epics/Epic-manage-keep-us-upgradable/0007-implementation-status.md`
- `knowledge_base/AIDER_DESK_PR_STRATEGY.md`
- `knowledge_base/AIDER_DESK_PR_Plan.md`
- `knowledge_base/MERGE_STRATEGY_COMPARISON.md`

---

### 1) Glossary / mental model

- **`upstream`**: the canonical `aider-desk` repository we want to contribute to.
- **`origin`**: our fork (where we push branches).
- **`main` (our fork)**: should remain stable, deployable, and can contain “business-critical” divergence.
- **`upstream/main`**: the base branch for upstream PRs.
- **`sync/*` branches**: “integration snapshots” created in our fork that track upstream closely and are used to validate and stage updates.
- **PR branches**: short-lived branches created off `upstream/main` (preferred) or off a `sync/*` snapshot, containing exactly one upstream-appropriate change.

---

### 2) Required git remotes (one-time setup)

From the repo root:

```bash
# Verify what you have
git remote -v

# Ensure `origin` points to *our fork*
# (If you cloned our fork, this is typically already correct.)

# Add upstream remote (canonical aider-desk repo)
git remote add upstream <UPSTREAM_GIT_URL>

# Fetch both
git fetch origin
git fetch upstream
```

Notes:
- Replace `<UPSTREAM_GIT_URL>` with the upstream repository URL (SSH or HTTPS).
- We **never push** to `upstream` directly; we push to `origin` and open PRs to upstream.

---

### 3) Standard branch names (conventions)

#### Long-lived

- `main` (on `origin`): our fork’s stable branch.

#### Integration snapshots (in our fork)

- `sync/upstream-YYYY-MM-DD`
  - Example: `sync/upstream-2026-02-17`
  - Meaning: “A snapshot branch that merges or fast-forwards to upstream/main at that date, validated locally.”

#### Upstream PR branches (in our fork)

Use atomic, intention-revealing names:

- `fix/<topic>`
- `feat/<topic>`
- `perf/<topic>`
- `test/<topic>`

Examples aligned to our current PR candidates:

- `fix/agent-profile-lookup-fallback`
- `fix/profile-aware-task-init`
- `feat/task-tooling-clarity`
- `fix/ollama-aider-prefix`
- `perf/token-count-debouncing`
- `fix/ipc-max-listeners`
- `test/jsdom-storage-mocks`

---

### 4) Creating (or refreshing) an upstream tracking branch

This creates a local branch you can always reset to match upstream:

```bash
git fetch upstream
git checkout -B upstream-main upstream/main
```

This `upstream-main` branch is local convenience only (do not PR from it).

---

### 5) Creating a `sync/upstream-YYYY-MM-DD` snapshot branch

Use this when you want a validated baseline in our fork that represents upstream at a point in time.

```bash
# Start from upstream
git fetch upstream
git checkout -B sync/upstream-YYYY-MM-DD upstream/main

# Push the snapshot branch to our fork
git push -u origin sync/upstream-YYYY-MM-DD
```

Verification (recommended for a snapshot you intend to build on):

```bash
npm ci
npm run lint:check
npm run typecheck
npm run test
```

If these checks fail on pure upstream, record that in the epic notes before continuing.

#### 5.1) Copy the epic process docs onto the snapshot branch (recommended)

If you intend to do PRD work starting from a `sync/*` snapshot branch, **copy the epic documents onto that snapshot branch** so the instructions travel with the baseline.

This is an internal-only commit that stays in our fork (it is **not** intended to be upstreamed).

On the snapshot branch:

```bash
# Bring the epic docs from our fork main onto the snapshot branch
git checkout origin/main -- knowledge_base/epics/Epic-manage-keep-us-upgradable

git add knowledge_base/epics/Epic-manage-keep-us-upgradable
git commit -m "docs(epic): sync upgradability process docs onto snapshot"
```

Alternative (if you prefer to keep the snapshot branch pristine):
- Use two worktrees: one checked out at `origin/main` for reading `knowledge_base/**`, and one checked out at your `sync/*` / PR branch for coding.

---

### 6) How to create clean upstream PR branches (the core workflow)

#### Rule 1: PR branches should be based on `upstream/main` unless there’s a reason not to

Preferred:

```bash
git fetch upstream
git checkout -b fix/<topic> upstream/main
```

Alternative (if you want to base on a validated snapshot):

```bash
git checkout -b fix/<topic> origin/sync/upstream-YYYY-MM-DD
```

**Reminder:** do not branch off our fork `main` for upstream PRs.

#### Rule 2: One PR branch = one PRD / one upstream-worthy change

This aligns with `knowledge_base/AIDER_DESK_PR_STRATEGY.md` (atomic PRs).

#### Rule 3: Prefer PRD-driven reimplementation over “dragging fork history”

You have two ways to build the PR branch:

1) **Reimplement from PRD** (preferred for long-term upgradability)
   - Use the PRD’s reproduction steps + acceptance criteria
   - Implement the minimal fix
   - Add/update tests if appropriate

2) **Cherry-pick from our fork** (allowed when it is clean and obviously correct)
   - Useful for small, self-contained changes
   - Still ensure the resulting PR diff is small and reviewable

Cherry-pick example:

```bash
# Identify the commit(s) on our fork branch containing the change
git log origin/main --oneline

# On your PR branch based on upstream/main:
git cherry-pick <commit_sha>
```

Guardrails for cherry-picking:
- Avoid cherry-picking merge commits.
- If cherry-picking pulls unrelated formatting/dependency churn, stop and reimplement instead.

---

### 7) Keeping PRs clean (practical checks)

Before pushing:

```bash
# Inspect exactly what upstream will see
git diff --stat upstream/main...HEAD
git diff upstream/main...HEAD

# Confirm you didn’t accidentally include lockfile churn
git status
```

If `package-lock.json` changes but your PR does not require dependency changes, fix it before pushing.

---

### 8) Pushing PR branches and opening upstream PRs

```bash
git push -u origin fix/<topic>
```

Then open a PR:
- **Base repo**: upstream `aider-desk`
- **Base branch**: `main`
- **Head repo**: our fork
- **Compare branch**: `fix/<topic>` (or `feat/*`, etc.)

PR description should include:
- Problem statement + reproduction (from PRD)
- Summary of change
- Test evidence (commands run + results)

---

### 9) Recommended sequence for this epic

Use `knowledge_base/AIDER_DESK_PR_STRATEGY.md` as the canonical grouping. Recommended order:

1. **Testing infrastructure**: `test/jsdom-storage-mocks`
2. **Agent orchestration fixes**: `fix/agent-orchestration-*` (split if needed)
3. **Ollama Aider integration**: `fix/ollama-aider-prefix`
4. **Platform performance/stability**: `perf/token-count-debouncing`, `fix/ipc-max-listeners`

Rationale:
- Better tests reduce risk for subsequent PRs.
- Orchestration fixes are higher impact and likely to be accepted.
- Performance/stability improvements are easier to review after functional correctness is solid.

---

### 10) What happens to our fork `main`?

We keep `origin/main` stable and deployable.

When upstream releases move forward:
1. Create a new `sync/upstream-YYYY-MM-DD` snapshot and validate it
2. Re-evaluate each PRD against upstream (per `0000-epic-overview.md`)
3. Reapply only what is still needed (prefer PRD-driven reimplementation)
4. Decide what remains fork-only vs what becomes upstream PRs
