# Overwatch — DevOps & Infrastructure Management

Central repository for DevOps documentation, deployment guides, operational checklists, and per-project infrastructure artifacts for the **agent-forge** ecosystem.

## Directory Structure

```
overwatch/
├── docs/                              # All documentation
│   ├── assessments/                   # Environment & DevOps state assessments
│   │   └── devops-assessment.md       # Comprehensive DevOps assessment (all projects)
│   ├── checklists/                    # Operational checklists & action plans
│   │   └── checklist-immediate-actions.md  # 7-day priority action plan
│   ├── deployment/                    # Deployment strategies & per-app guides
│   │   ├── deployment-strategy-overview.md # Multi-app deployment strategies
│   │   ├── deployment-nextgen-plaid.md     # NextGen Plaid deployment guide
│   │   └── deployment-eureka-homekit.md    # Eureka HomeKit deployment guide
│   └── inspections/                   # Server & environment inspection reports
│       └── remote-instance-inspection.md   # 192.168.4.253 inspection (2026-02-16)
├── projects/                          # Per-project operational artifacts
│   └── nextgen-plaid/
│       └── database-sync/             # Database sync plan, prototypes, examples
│           ├── database-sync-plan.md
│           ├── database-sync-prototype.rb
│           ├── database-sync-examples.sh
│           └── test-database-connectivity.rb
└── scripts/                           # Shared DevOps automation scripts (future)
```

## Quick Reference

### Infrastructure

| Resource | Details |
|----------|---------|
| **Production Server** | M3 Ultra @ `192.168.4.253` (macOS, 256 GB RAM) |
| **Public Domain** | `api.higroundsolution.com` via Cloudflare Tunnel |
| **Network** | ATT Fiber → Ubiquiti UDM-SE → Cloudflare Tunnel |
| **PostgreSQL** | 16.11 (Homebrew) on both local and remote |

### Projects

| Project | Type | Current Documentation |
|---------|------|---------------------|
| **nextgen-plaid** | Rails 8.1.1 financial app | [📄 Current State](docs/deployments/nextgen-plaid-current-state-2026-02-25.md) |
| | | [📖 RUNBOOK v2.0](../nextgen-plaid/RUNBOOK.md) (authoritative) |
| | | [👥 Team Guide v2.0](docs/team-guides/NEXTGEN-PLAID-DEPLOYMENT-TEAM-GUIDE.md) |
| | | [⚠️ Obsolete: Docker Compose Guide](docs/deployment/deployment-nextgen-plaid.md) |
| SmartProxy | Sinatra LLM proxy | Documented in nextgen-plaid RUNBOOK |
| eureka-homekit | Rails HomeKit app | [docs/deployment/deployment-eureka-homekit.md](docs/deployment/deployment-eureka-homekit.md) |
| aider-desk | Electron/TypeScript | — |

### Remote Server Access

```bash
ssh ericsmith66@192.168.4.253
```

### Database Sync (NextGen Plaid)

The final sync script lives in the nextgen-plaid project:
```bash
cd /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid
ruby script/sync_databases.rb --dry-run    # preview
ruby script/sync_databases.rb              # sync all databases
```

See [projects/nextgen-plaid/database-sync/database-sync-plan.md](projects/nextgen-plaid/database-sync/database-sync-plan.md) for the full plan.

## Key Documents

| Document | Purpose | Location |
|----------|---------|----------|
| **NextGen Plaid Current State** | Production architecture & operations (Feb 25, 2026) | [docs/deployments/nextgen-plaid-current-state-2026-02-25.md](docs/deployments/nextgen-plaid-current-state-2026-02-25.md) |
| **SmartProxy Deployment Plan** | Deploy SmartProxy as standalone service (Mar 2, 2026) | [docs/deployment/deployment-smartproxy.md](docs/deployment/deployment-smartproxy.md) |
| SmartProxy Executive Summary | Quick deployment overview | [docs/deployment/SMARTPROXY-DEPLOYMENT-SUMMARY.md](docs/deployment/SMARTPROXY-DEPLOYMENT-SUMMARY.md) |
| DevOps Assessment | Current state of all projects | [docs/assessments/devops-assessment.md](docs/assessments/devops-assessment.md) |
| Immediate Actions | 7-day priority checklist | [docs/checklists/checklist-immediate-actions.md](docs/checklists/checklist-immediate-actions.md) |
| Deployment Overview | Multi-app deployment strategies | [docs/deployment/deployment-strategy-overview.md](docs/deployment/deployment-strategy-overview.md) |
| Remote Inspection | 192.168.4.253 server report | [docs/inspections/remote-instance-inspection.md](docs/inspections/remote-instance-inspection.md) |
| DB Sync Plan | NextGen Plaid database sync | [projects/nextgen-plaid/database-sync/database-sync-plan.md](projects/nextgen-plaid/database-sync/database-sync-plan.md) |
| **Operations Logs** | Security incident tracking | [docs/operations-log/](docs/operations-log/) |

## Contributing & Directory Conventions

See **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)** for file naming rules, where new content goes, document formatting requirements, and workflows for adding new documents or projects.

## Standards

- **IaC:** Declarative configurations preferred (Terraform planned)
- **Logging:** Structured JSON format
- **Runbooks:** `RUNBOOK.md` required per service
- **Secrets:** Never hardcoded — Vault/Doppler required
- **Backups:** Verified before any destructive operation
