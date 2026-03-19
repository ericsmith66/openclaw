# Overwatch — Directory Structure & Contribution Guide

This document explains how the Overwatch repository is organized, where new content should go, and the naming and formatting conventions to follow. Treat this as the source of truth for keeping the project clean and navigable.

## Top-Level Layout

```
overwatch/
├── README.md          # Project overview, quick reference, key links
├── docs/              # All documentation (organized by type)
├── projects/          # Per-project operational artifacts
├── scripts/           # Shared DevOps automation scripts
└── docs/CONTRIBUTING.md  ← you are here
```

| Directory | Purpose | What goes here | What does NOT go here |
|-----------|---------|---------------|----------------------|
| `docs/` | Documentation organized by type | Markdown docs, guides, reports | Scripts, code, config files |
| `projects/` | Per-project DevOps artifacts | Plans, prototypes, runbooks scoped to one project | Cross-project docs (those go in `docs/`) |
| `scripts/` | Shared automation | Shell/Ruby scripts used across projects | Project-specific scripts (those go in the project's own repo) |

---

## `docs/` — Documentation by Type

Each subdirectory holds a specific category of document. Place new files in the matching category.

### `docs/assessments/`
**What:** Point-in-time evaluations of infrastructure, DevOps maturity, security posture, or environment state.

**Examples:**
- `devops-assessment.md` — full DevOps audit across all projects
- `security-audit-2026-03.md` — quarterly security review

**Naming:** `<topic>-assessment.md` or `<topic>-audit-<date>.md`

---

### `docs/checklists/`
**What:** Actionable task lists and action plans with checkboxes. Time-bound or priority-driven.

**Examples:**
- `checklist-immediate-actions.md` — 7-day priority plan
- `checklist-production-launch.md` — pre-launch verification

**Naming:** `checklist-<topic>.md`

---

### `docs/deployment/`
**What:** Deployment strategies, per-application deployment guides, Docker/Kamal configurations, and environment setup instructions.

**Examples:**
- `deployment-strategy-overview.md` — multi-app strategy comparison
- `deployment-nextgen-plaid.md` — NextGen Plaid-specific guide
- `deployment-eureka-homekit.md` — Eureka HomeKit-specific guide

**Naming:** `deployment-<project-name>.md` for per-app guides, `deployment-<topic>.md` for cross-cutting topics.

---

### `docs/inspections/`
**What:** Server, environment, or infrastructure inspection reports. These are snapshots of what was found at a specific point in time.

**Examples:**
- `remote-instance-inspection.md` — 192.168.4.253 server report
- `network-inspection-2026-04.md` — quarterly network review

**Naming:** `<target>-inspection.md` or `<target>-inspection-<date>.md`

---

### Adding a New Category

If a document doesn't fit any existing category, create a new subdirectory under `docs/`:

1. Pick a clear, plural noun: `docs/runbooks/`, `docs/postmortems/`, `docs/architecture/`
2. Add a brief description to this guide and to the root `README.md`
3. Follow the same naming conventions (lowercase, hyphen-separated)

---

## `projects/` — Per-Project Artifacts

Operational artifacts scoped to a single project live here, organized by project name and then by topic.

```
projects/
└── <project-name>/
    └── <topic>/
        ├── <topic>-plan.md
        ├── <topic>-prototype.rb
        └── ...
```

### Rules

- **One directory per project:** `projects/nextgen-plaid/`, `projects/eureka-homekit/`, etc.
- **One subdirectory per topic:** `database-sync/`, `monitoring/`, `backup/`, etc.
- **Plans stay here, final scripts go in the project's own repo.** For example, the database sync *plan* and *prototype* live in `projects/nextgen-plaid/database-sync/`, but the *production script* lives in `nextgen-plaid/script/sync_databases.rb`.

### When to use `projects/` vs `docs/`

| Content | Location | Reason |
|---------|----------|--------|
| NextGen Plaid database sync plan | `projects/nextgen-plaid/database-sync/` | Scoped to one project |
| Deployment guide for NextGen Plaid | `docs/deployment/` | Deployment docs are a cross-cutting category |
| Network architecture diagram | `docs/assessments/` or `docs/architecture/` | Infrastructure-wide |
| Eureka HomeKit runbook | `projects/eureka-homekit/runbook/` | Scoped to one project |

---

## `scripts/` — Shared Automation

Scripts that operate across multiple projects or provide shared DevOps utilities.

**Examples (future):**
- `scripts/backup-all-databases.sh` — backup all project databases
- `scripts/health-check.rb` — check health of all services
- `scripts/rotate-secrets.sh` — rotate secrets across environments

**Rules:**
- Must work independently (no project-specific dependencies)
- Include a usage comment at the top of the file
- Project-specific scripts belong in that project's repo, not here

---

## Naming Conventions

### Files
- **All lowercase**, hyphen-separated: `database-sync-plan.md`, not `DatabaseSyncPlan.md`
- **Prefix with category** when inside `docs/`: `checklist-`, `deployment-`, etc.
- **Suffix with date** for time-bound reports: `security-audit-2026-03.md`
- **Use `.md`** for documentation, `.sh` for shell scripts, `.rb` for Ruby scripts

### Directories
- **All lowercase**, hyphen-separated: `database-sync/`, not `DatabaseSync/`
- **Plural nouns** for `docs/` subdirectories: `assessments/`, `checklists/`, `inspections/`
- **Singular topic** for `projects/` subdirectories: `database-sync/`, `monitoring/`

---

## Document Format

Every Markdown document should include a header block:

```markdown
# Title
**Version:** 1.0  
**Last Updated:** February 16, 2026  
**Author:** DevOps Engineer

## Overview
Brief description of what this document covers.
```

### Required Sections (by type)

| Type | Required Sections |
|------|-------------------|
| Assessment | Overview, Findings, Recommendations, Next Review Date |
| Checklist | Priority Items (with checkboxes), Timeline, Owner |
| Deployment Guide | Prerequisites, Steps, Verification, Rollback |
| Inspection | Executive Summary, Findings, Implications, Recommendations |
| Plan | Overview, Requirements, Design, Safety, Implementation Steps |

---

## Workflow: Adding a New Document

1. **Decide the category** — does it belong in `docs/<type>/` or `projects/<project>/<topic>/`?
2. **Follow the naming convention** — lowercase, hyphen-separated, prefixed by category.
3. **Include the header block** — version, date, author.
4. **Update the root `README.md`** — add the document to the Key Documents table if it's significant.
5. **Update this guide** — if you created a new `docs/` subdirectory, document it here.

## Workflow: Adding a New Project

1. Create `projects/<project-name>/`
2. Create topic subdirectories as needed: `projects/<project-name>/<topic>/`
3. Add the project to the root `README.md` Projects table.

---

## Housekeeping

- **Archive, don't delete.** If a document is obsolete, move it to a `_archive/` subdirectory within its category rather than deleting it.
- **Review dates.** Documents with a "Next Review" date should be revisited on schedule.
- **Keep the root `README.md` current.** It's the entry point — every significant document should be linked there.
- **No secrets.** Never commit credentials, API keys, or tokens to this repository. Reference Vault/Doppler paths instead.
