### Test-Driven Mitigation Plan: Configuration Duplication & Sync Failures

Based on the root causes identified in `root_cause_analysis_agent_configs.md`, this plan defines specific test cases to prevent regressions and validates each fix.

---

#### Branch Strategy

**Recommendation: Continue from the current branch (`fix/agent-configs-revert` at `24f8d98d`).**

**Rationale:**
- The 2 commits ahead on `main` (`706f9a75` — project isolation, `0fc58938` — duplicate fix) are the *problematic fixes* that introduced the issues we're now mitigating with a proper test-driven approach.
- Merging `main` into this branch would pull in those broken fixes, creating conflicts and re-introducing the bugs.
- Instead, this branch will implement the *correct* versions of those fixes (with tests first), then force-push or PR to `main`, effectively replacing the broken commits.

**Steps:**
1. Stay on `fix/agent-configs-revert` (based on `24f8d98d`).
2. Implement all mitigations below with TDD.
3. When complete, open a PR to `main` that supersedes commits `706f9a75` and `0fc58938`.
4. The PR description should reference this plan and the RCA document.

---

#### Scope: All Configuration Metadata Types

The root causes (hardcoded paths, missing namespacing, destructive sanitization, broken sync) apply not just to **agents** but to all metadata types managed by AiderDesk and synced by `sync-aider-config.sh`:

| Metadata Type | Template Location (in `knowledge_base/`) | Runtime Location (in `.aider-desk/`) | Has `config.json`? | Sync'd by script? |
|---|---|---|---|---|
| **Agents** | `configs/*/agents/*/config.json` | `agents/*/config.json` | ✅ Yes | ✅ Yes |
| **Skills** | `configs/*/skills/*/skill.md` | `skills/*/skill.md` | ❌ No (frontmatter in `.md`) | ✅ Yes |
| **Commands** | `configs/*/commands/*.md` | `commands/*.md` | ❌ No (frontmatter in `.md`) | ✅ Yes |
| **Rules** | `configs/*/rules/*.md` | `rules/*.md` | ❌ No (plain `.md`) | ✅ Yes |
| **Prompts** | `configs/*/prompts/*.md` | `prompts/*.md` | ❌ No (frontmatter in `.md`) | ✅ Yes |

**Key insight:** Only agents use `config.json` with `projectDir`. Skills, commands, rules, and prompts are plain markdown files with optional YAML frontmatter — they don't suffer from Root Cause A (hardcoded paths) or C (destructive sanitization). However, they **do** share Root Cause D (sync script issues) and could be affected by future namespacing needs.

---

#### Mitigation A: Hardcoded Project Paths in Templates (Agents only)

**Root Cause**: Templates ship with hardcoded `projectDir` values (e.g., `"/home/wladimiiir/Projects/aider-desk"`), causing misidentification in other environments.

**Fix**: `sanitizeAgentProfile` should strip or ignore `projectDir` from loaded config files. The correct `projectDir` should only be set based on which directory the profile was loaded from, never from the file contents.

**Tests** (in `agent-profile-manager.test.ts`):

| # | Test Name | Description | Assertion |
|---|-----------|-------------|-----------|
| A1 | `should ignore hardcoded projectDir from config file` | Load a profile whose `config.json` contains `"projectDir": "/some/foreign/path"` from the global agents dir. | `profile.projectDir` is `undefined` (global), not `"/some/foreign/path"`. |
| A2 | `should set projectDir based on load directory, not file contents` | Load a profile from a project-specific dir (`/my-project/.aider-desk/agents/`). The `config.json` contains a *different* `projectDir`. | `profile.projectDir` equals `/my-project`, not the value from the file. |
| A3 | `template config files should not contain projectDir` | Scan all template `config.json` files in `knowledge_base/aider-desk/configs/*/agents/*/config.json`. | None of them contain a `"projectDir"` key. |

**Implementation**:
- In `loadProfileFile()` or `sanitizeAgentProfile()`, delete `loadedProfile.projectDir` before use.
- Set `projectDir` based on whether the file was loaded from a project directory or the global directory.
- Add a CI lint check or test (A3) that scans template configs for `projectDir`.

---

#### Mitigation B: Missing Namespacing in Agent IDs

**Root Cause**: The `profiles` Map uses only `profile.id` as the key. Two projects with an agent named `ror-rails` collide.

**Fix**: Use a composite key `${projectDir}::${id}` (or similar) in the internal `profiles` Map so that same-ID agents from different projects coexist.

**Tests** (in `agent-profile-manager.test.ts`):

| # | Test Name | Description | Assertion |
|---|-----------|-------------|-----------|
| B1 | `should store same-ID agents from different projects as separate entries` | Add `ror-rails` for `/project-a` and `ror-rails` for `/project-b` via `initializeForProject`. | `getAllProfiles()` returns 2 profiles, both with `id: "ror-rails"` but different `projectDir`. |
| B2 | `should not overwrite global agent when project agent has same ID` | Load global `code-checker`, then `initializeForProject` with a project that also has `code-checker`. | Both exist in `profiles` Map. `getProjectProfiles(projectDir)` returns the project one first. |
| B3 | `updateProfile should only update the correct namespaced entry` | With two `ror-rails` (project-a and project-b), update only project-a's. | Project-b's `ror-rails` is unchanged. |
| B4 | `deleteProfile should only delete the correct namespaced entry` | With two `ror-rails`, delete project-a's. | Project-b's `ror-rails` still exists. |
| B5 | `removeProject should only remove that project's agents` | Load agents for project-a and project-b, then call `removeProject(project-a)`. | Project-b agents and global agents remain. |

**Implementation**:
- Change the `profiles` Map key from `profile.id` to a composite like `${profile.projectDir || 'global'}::${profile.id}`.
- Update all Map lookups (`get`, `set`, `delete`, `has`) to use the composite key.
- Update `updateProfile` and `deleteProfile` to accept/use `projectDir` for disambiguation.

---

#### Mitigation C: Destructive File Sanitization (Auto-Write on Read)

**Root Cause**: `loadProfileFile()` compares the loaded profile to the sanitized version and writes back if different. This destroys symlinks and mutates template files.

**Fix**: Sanitize in-memory only. Never write back to the source file during load. Only write on explicit user-triggered save operations.

**Tests** (in `agent-profile-manager.test.ts`):

| # | Test Name | Description | Assertion |
|---|-----------|-------------|-----------|
| C1 | `loadProfileFile should NOT write back to disk` | Load a profile that is missing optional fields (e.g., no `name`, no `maxIterations`). | `fs.writeFile` is NOT called during load. The in-memory profile has defaults filled in. |
| C2 | `sanitizeAgentProfile should fill defaults without side effects` | Call `sanitizeAgentProfile` with a minimal profile (only `id`). | Returns a complete profile with all defaults. No I/O calls made. |
| C3 | `loading a profile should preserve the original file on disk` | Load a profile, then read the file again. | File contents are identical to the original (no fields added/removed). |

**Implementation**:
- Remove the `saveProfileToFile` call from `loadProfileFile()` (lines ~421-424 in `agent-profile-manager.ts`).
- Keep `sanitizeAgentProfile` as a pure in-memory transform.
- Only call `saveProfileToFile` from explicit mutation paths: `createProfile`, `updateProfile`.

---

#### Mitigation D: Sync Script — All Metadata Types

**Root Cause**: The `sync-aider-config.sh` script uses `jq` to inject `projectDir`, but the `find ... -exec jq` pipeline silently fails (output goes to `/dev/null`).

**Scope**: The sync script handles **all 5 metadata types** (agents, skills, commands, rules, prompts). The `jq` fix is agent-specific, but the `rsync` and directory structure must be validated for all types.

**Tests** (shell-based or integration):

| # | Test Name | Description | Assertion |
|---|-----------|-------------|-----------|
| D1 | `sync script should inject correct projectDir into agent configs` | Run sync for a test project, then read the resulting agent `config.json`. | `projectDir` matches the target project path. |
| D2 | `sync script should not modify source templates` | After sync, check the *source* template files for all types. | Source templates are unmodified. |
| D3 | `sync script jq pipeline should not silently fail` | Run sync and check exit code. | Exit code is 0 and target agent configs are valid JSON. |
| D4 | `sync script should copy all skills to target` | Run sync, list target `skills/` directory. | All skill directories from source exist in target with correct `skill.md` files. |
| D5 | `sync script should copy all commands to target` | Run sync, list target `commands/` directory. | All `.md` command files from source exist in target. |
| D6 | `sync script should copy all rules to target` | Run sync, list target `rules/` directory. | All `.md` rule files from source exist in target. |
| D7 | `sync script should handle missing metadata dirs gracefully` | Run sync with a config that has no `rules/` or `prompts/` directory. | Script exits 0, other types still sync correctly. |

**Implementation**:
- Fix the `jq` pipeline in `sync-aider-config.sh`: use `jq ... file > tmp && mv tmp file` pattern instead of redirecting to `/dev/null`.
- Add a `--dry-run` or `--validate` flag to the script for CI use.
- Ensure the `for dir in commands rules skills` loop also includes `prompts`.

---

#### Mitigation E: Template Lint & Structural Validation (Expanded)

**Root Cause**: No automated check prevents environment-specific data from leaking into templates, and no validation ensures templates conform to the structure AiderDesk actually expects at runtime.

**Validation Audit (2026-02-17)**: A manual review of all template configs in `knowledge_base/aider-desk/configs/` revealed the following:

| Check | Result | Details |
|---|---|---|
| Agent `config.json` valid JSON | ✅ All 14 pass | ror(4), python(4), devops(2), swift(4) |
| Agent `config.json` has `id` + `name` | ✅ All 14 pass | No missing required fields |
| Agent `config.json` has no `projectDir` | ✅ All 14 pass | Templates are clean |
| Skill structure: `<dir>/SKILL.md` | ❌ **1 FAIL** | `devops-agent-config/skills/devops-runbook-logging.md` is a **flat file**, not `<dir>/SKILL.md`. AiderDesk's `loadSkillsFromDir` expects `skills/<dirname>/SKILL.md` — this skill will be **silently ignored** at runtime. |
| Skill frontmatter: `name` + `description` | ✅ All 10 ror skills pass | devops skill can't be checked (wrong structure) |
| Command frontmatter: `description` | ❌ **1 FAIL** | `ror-agent-config/commands/implement-plan.md` has **no YAML frontmatter**. AiderDesk's `loadCommandFile` skips commands without `description` — this command will be **silently ignored**. |
| Prompts: loaded by app? | ⚠️ **N/A** | `prompts/*.md` in configs are custom delegation rules. The app's `PromptsManager` loads from `resources/prompts/` (built-in templates) and `~/.aider-desk/prompts/` (global overrides). Project-level `prompts/` in `.aider-desk/` are **not loaded by any known code path** — they may only serve as documentation or be consumed by agents reading files directly. |
| No absolute paths in any template | ✅ All pass | No `/home/`, `/Users/`, or `C:\` patterns found |

**Structural Requirements (derived from source code)**:

| Type | Expected Structure | Loader | Required Fields |
|---|---|---|---|
| **Agents** | `agents/<dirname>/config.json` | `AgentProfileManager.loadProfileFile()` | `id`, `name` (defaults applied for others) |
| **Skills** | `skills/<dirname>/SKILL.md` (uppercase, inside subdirectory) | `loadSkillsFromDir()` in `skills.ts` | YAML frontmatter: `name`, `description` |
| **Commands** | `commands/<name>.md` (flat files, supports subdirs for namespacing) | `CustomCommandManager.loadCommandFile()` | YAML frontmatter: `description` |
| **Rules** | `rules/<name>.md` | Read as plain text by agent | None (plain markdown) |
| **Prompts** | `prompts/<name>.md` | Not loaded by app — informational only | None |

**Tests** (in `template-configs.test.ts` — new file):

| # | Test Name | Description | Assertion |
|---|-----------|-------------|-----------|
| E1 | `agent template configs should not contain projectDir` | Scan all `configs/*/agents/*/config.json`. | No file contains `"projectDir"`. |
| E2 | `agent template configs should be valid JSON with id and name` | Parse all agent `config.json` files. | All parse without error and contain `id` and `name` string fields. |
| E3 | `agent order.json files should be valid JSON` | Parse all `configs/*/agents/order.json`. | All parse without error and contain only string keys with numeric values. |
| E4 | `agent order.json should reference only existing agent dirs` | For each `order.json`, check that every key matches a sibling directory name. | No orphan references. |
| E5 | `skill templates should use correct directory structure` | Scan all `configs/*/skills/` — each entry must be a **directory** containing `SKILL.md`. | No flat `.md` files directly in `skills/`. |
| E6 | `skill templates should have valid frontmatter with name and description` | Parse YAML frontmatter from each `SKILL.md`. | Each has non-empty `name` and `description`. |
| E7 | `command templates should have valid frontmatter with description` | Parse YAML frontmatter from each `configs/*/commands/*.md`. | Each has non-empty `description`. |
| E8 | `no template should contain absolute paths` | Scan all files in `configs/` for patterns like `/home/`, `/Users/`, `C:\`. | No matches found. |

**Known Defects to Fix (Phase 6)**:
1. **`devops-agent-config/skills/devops-runbook-logging.md`** → Move to `devops-agent-config/skills/devops-runbook-logging/SKILL.md` and add `name`/`description` frontmatter.
2. **`ror-agent-config/commands/implement-plan.md`** → Add YAML frontmatter with `description` field.

**Implementation**:
- Create `src/main/agent/__tests__/template-configs.test.ts` with glob-based scanning.
- Use `yaml-front-matter` (already a project dependency) for frontmatter parsing in tests.
- Run as part of the standard `vitest` suite.

---

#### Execution Order

1. **Phase 1 — Write failing tests**: Add tests A1-A3, B1-B5, C1-C3 to `agent-profile-manager.test.ts`. Add E1-E8 to `template-configs.test.ts`. Confirm they fail against current code.
2. **Phase 2 — Fix Mitigation C** (lowest risk): Remove auto-write-on-read. Tests C1-C3 should pass.
3. **Phase 3 — Fix Mitigation A**: Strip `projectDir` from loaded files, derive it from load path. Tests A1-A2 should pass.
4. **Phase 4 — Fix Mitigation B**: Implement composite Map keys. Tests B1-B5 should pass.
5. **Phase 5 — Fix Mitigation D**: Fix sync script `jq` pipeline and add `prompts` to sync loop. Tests D1-D7 should pass.
6. **Phase 6 — Fix Mitigation E**: Fix the 2 known template defects (devops skill structure, implement-plan frontmatter). Tests E1-E8 should pass.
7. **Phase 7 — PR to main**: Open PR that supersedes commits `706f9a75` and `0fc58938`.

#### Test File Locations

- **Unit tests**: `src/main/agent/__tests__/agent-profile-manager.test.ts` (extend existing)
- **Template lint**: `src/main/agent/__tests__/template-configs.test.ts` (new)
- **Sync script tests**: `scripts/__tests__/sync-aider-config.test.sh` (new, bash-based)

#### Success Criteria

- All tests in Phases 1-7 pass.
- No `projectDir` in any template `config.json`.
- No absolute paths in any template file.
- Loading profiles never triggers `fs.writeFile`.
- Two projects with identical agent IDs coexist without collision.
- Sync script produces valid JSON with correct `projectDir` for agents.
- Sync script copies all 5 metadata types (agents, skills, commands, rules, prompts).
- All skills use `<dir>/SKILL.md` structure with `name` + `description` frontmatter.
- All commands have `description` in YAML frontmatter.
- All `order.json` files reference only existing agent directories.
- Prompts directory is documented as informational-only (not loaded by app).
