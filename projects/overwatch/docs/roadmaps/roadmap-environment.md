# Agent-Forge Environment Roadmap
**Created:** February 17, 2026  
**Scope:** All projects, infrastructure, and shared services  
**Approach:** Native macOS — no Docker until Phase 4  
**Production Server:** M3 Ultra at 192.168.4.253 (256GB RAM, 1.8TB disk)

---

## Current State Snapshot

### Infrastructure
| Component | Dev Machine | Production (192.168.4.253) |
|-----------|-------------|---------------------------|
| macOS | Tahoe (M3 Ultra) | Tahoe (M3 Ultra) |
| Ruby | 3.3.10 (rbenv) | 3.3.10 (rbenv) |
| PostgreSQL | 16 (Homebrew) | 16 (Homebrew, LaunchAgent) |
| Redis | 7 (Homebrew) | 7 (Homebrew, LaunchAgent) |
| Node | Yes | 20 (Homebrew) |
| Ollama | Yes | Yes (macOS app, auto-starts, port 11434) |
| Homebrew | Yes | Yes |
| Docker | Installed | Not needed yet |

### Application Portfolio

| Application | Stack | Prod Status | Port | Priority |
|-------------|-------|-------------|------|----------|
| **nextgen-plaid** | Rails 8 + Solid Queue + SmartProxy | ⚠️ Running in dev mode | 3000, 3002 | **P0 — First** |
| **eureka-homekit** | Rails 8.1 + JS/CSS bundling | ❌ Not deployed | TBD (3001) | P1 — Second |
| **SmartProxy** | Sinatra — AI gateway (Claude/Grok/Ollama) | ⚠️ Embedded in nextgen-plaid on prod | 3002 | P0.5 — Extract to standalone after nextgen-plaid stable |
| **Prefab** | Swift/macOS HomeKit HTTP bridge | ❌ Not deployed | 8080 | P1.75 — Required before eureka-homekit |
| **aider-desk** | Electron/TypeScript desktop app | N/A — desktop app | N/A | P2 — Separate workflow |
| **aider-desk-test** | Ruby test suite | N/A — CI only | N/A | P3 |
| **eureka-homekit-rebuild** | Rails (early stage) | ❌ Not started | TBD | P3 — Replaces eureka-homekit |
| **overwatch** | DevOps docs/tooling (this repo) | N/A — meta | N/A | Ongoing |
| **knowledge_base** | Markdown docs | N/A | N/A | N/A |
| **log** | Log storage | N/A | N/A | N/A |

### Local AI / Ollama
Ollama runs on the production server as a macOS app (auto-starts on login). It is **not exposed to the internet** — only accessible at `localhost:11434`. SmartProxy fronts it for the Rails app.

| Model | Size | Purpose |
|-------|------|---------|
| `llama3.1:70b` | 42.5 GB (Q4_K_M) | Primary LLM — used by nextgen-plaid via SmartProxy |
| `llama3-groq-tool-use:70b` | 40.0 GB (Q4_0) | Tool-use / function-calling model |
| `vanilj/palmyra-fin-70b-32k` | 42.5 GB (Q4_K_M) | Financial domain specialist |
| `llama3.1:8b` | 4.9 GB (Q4_K_M) | Lightweight / fast inference |
| `nomic-embed-text` | 274 MB (F16) | Embeddings for RAG |

With 256 GB RAM on the M3 Ultra, any single 70B model fits comfortably in memory. This provides a **zero-cloud-cost AI assistant** for tasks that don't require frontier model quality — useful for automated operations, code review assistance, or agent tasks where latency tolerance is higher.

### Network Path
```
Internet → ATT Fiber → Ubiquiti UDM-SE → Cloudflare Tunnel
                                              ↓
                                    192.168.4.253
                                    :80 → pf rdr → :3000 (nextgen-plaid)
                                    ├── :3000  nextgen-plaid (Rails)
                                    ├── :3001  eureka-homekit (Rails) [planned]
                                    ├── :3002  SmartProxy (Sinatra, internal only)
                                    ├── :5432  PostgreSQL 16
                                    ├── :6379  Redis 7
                                    ├── :8080  Prefab (HomeKit bridge, internal only) [planned]
                                    └── :11434 Ollama (internal only)
```

**Port 80 Forwarding:** macOS `pf` (packet filter) rules in `/etc/pf.anchors/com.nextgen.plaid` redirect port 80 → 3000 on both `lo0` and `en0`. The UDM-SE firewall forwards external traffic to port 80 on 192.168.4.253, and `pf` handles the final hop to Puma on 3000.

### Known Problems
1. nextgen-plaid runs `RAILS_ENV=development` on production
2. App launched manually in a terminal — no auto-restart on crash or reboot
3. All secrets in plaintext `.env` files on both machines
4. Dev is on `feature/epic-6`, prod is on `main` — 8+ commits behind
5. No health checks, no monitoring, no alerting
6. No deployment script — manual `git pull` + restart
7. eureka-homekit not deployed at all
8. No runbooks for any service

---

## Phase 1: Stabilize nextgen-plaid (Week 1)
> **Goal:** nextgen-plaid running properly in production mode with secrets secured and automated restarts.

See **[roadmap-nextgen-plaid.md](roadmap-nextgen-plaid.md)** for the detailed breakdown.

**Deliverables:**
- [ ] `RAILS_ENV=production` with precompiled assets
- [ ] Secrets in macOS Keychain, `.env` files sanitized
- [ ] `launchd` plist for auto-start/restart
- [ ] `bin/deploy-prod` script on dev machine
- [ ] `/health` endpoint
- [ ] RUNBOOK.md in nextgen-plaid repo

---

## Phase 1.5: Extract SmartProxy to Standalone Service (Week 1-2)
> **Goal:** SmartProxy runs as its own service on prod, consumed by both nextgen-plaid and (later) eureka-homekit.

### Context
- SmartProxy is the unified AI gateway — it fronts Claude API, Grok API, and local Ollama
- On prod today it's **embedded inside** `nextgen-plaid/smart_proxy/` and launched via nextgen-plaid's Procfile
- It has already been **extracted to its own repo** at `projects/SmartProxy` (GitHub: `ericsmith66/SmartProxy`)
- Both nextgen-plaid and eureka-homekit will consume it as an external service at `localhost:3002`
- The embedded copy must be removed from nextgen-plaid once the standalone is running

### How nextgen-plaid connects to SmartProxy
- `AgentHub::SmartProxyClient` → connects via `OPENAI_API_BASE` env var (defaults to `http://localhost:11434/v1`)
- `AiFinancialAdvisor` → connects via `SMART_PROXY_PORT` env var (defaults to 3002)
- `admin/health_controller.rb` → health-checks SmartProxy via `SMART_PROXY_URL` or `localhost:{SMART_PROXY_PORT}`
- **All connections are via localhost + env vars** — no code changes needed in nextgen-plaid, just ensure the port stays 3002

### Steps
| # | Task | Notes |
|---|------|-------|
| 1.5.1 | Clone standalone SmartProxy repo to `~/Development/SmartProxy/` on prod | `git clone git@github.com:ericsmith66/SmartProxy.git` |
| 1.5.2 | `bundle install` on prod | Same Ruby 3.3.10 via rbenv |
| 1.5.3 | Store SmartProxy secrets in Keychain | `CLAUDE_API_KEY`, `GROK_API_KEY`, `PROXY_AUTH_TOKEN` (shared with nextgen-plaid) |
| 1.5.4 | Create `SmartProxy/bin/prod` launcher | Loads secrets from Keychain, starts on port 3002 |
| 1.5.5 | Create `launchd` plist | `com.agentforge.smart-proxy.plist` — auto-start, KeepAlive |
| 1.5.6 | Remove `proxy:` line from nextgen-plaid `Procfile.prod` | SmartProxy now starts independently |
| 1.5.7 | Remove embedded `smart_proxy/` directory from nextgen-plaid repo | Clean separation |
| 1.5.8 | Verify nextgen-plaid still connects to SmartProxy on :3002 | No code changes — env vars point to same port |
| 1.5.9 | Create `bin/deploy-prod` for SmartProxy | Same SSH + git pull + restart pattern |
| 1.5.10 | Add `/health` endpoint to SmartProxy | Verify Ollama + API key validity |

### SmartProxy Secrets
| Secret | Notes |
|--------|-------|
| `CLAUDE_API_KEY` | Same key as `CLAUDE_CODE_API_KEY` in nextgen-plaid |
| `GROK_API_KEY` | Same key |
| `PROXY_AUTH_TOKEN` | Auth token for Rails apps calling SmartProxy |

### Dependency Order
```
SmartProxy must start BEFORE nextgen-plaid and eureka-homekit.
launchd does not guarantee order, so bin/prod scripts should
wait-for-port 3002 before starting Rails.
```

---

## Phase 1.75: Deploy Prefab — HomeKit Bridge (Week 2)
> **Goal:** Prefab.app running on prod, providing HomeKit HTTP API on port 8080 for eureka-homekit.

### What Is Prefab?
Prefab is a **forked Swift/macOS application** that exposes HomeKit data over HTTP. It acts as the bridge between Apple's HomeKit framework (which only runs on Apple platforms) and eureka-homekit (Rails). eureka-homekit's `PrefabClient` talks to Prefab at `localhost:8080` to read homes/rooms/accessories/scenes and send control commands.

- **Repo:** `ericsmith66/prefab` (GitHub) — fork with enhanced logging and config
- **Dev location:** `/Users/ericsmith66/development/prefab`
- **Stack:** Swift 5.9+, Hummingbird HTTP server, macOS 14+
- **Port:** 8080 (default)
- **HomeKit requirement:** Must run on a Mac with HomeKit entitlements and access to the same home network as the physical HomeKit devices

### Prefab → eureka-homekit Connection
```
eureka-homekit (Rails :3001)
  └── PrefabClient (app/services/prefab_client.rb)
        └── HTTP via curl → Prefab.app (localhost:8080)
              └── Apple HomeKit Framework
                    └── Physical HomeKit devices on LAN
```

`PrefabClient` connects via `PREFAB_API_URL` env var (defaults to `http://localhost:8080`).

### Models Available via Prefab
| Endpoint | Purpose |
|----------|---------|
| `GET /homes` | List all HomeKit homes |
| `GET /rooms/:home` | List rooms in a home |
| `GET /accessories/:home/:room` | List accessories in a room |
| `GET /accessories/:home/:room/:accessory` | Accessory detail |
| `PUT /accessories/:home/:room/:accessory` | Set characteristic value |
| `GET /scenes/:home` | List scenes |
| `POST /scenes/:home/:uuid/execute` | Trigger a scene |

### Steps
| # | Task | Notes |
|---|------|-------|
| 1.75.1 | Clone prefab repo to `~/Development/prefab/` on prod | `git clone git@github.com:ericsmith66/prefab.git` |
| 1.75.2 | Build with Xcode/Swift | `xcodebuild` or `swift build` — Swift 6.2.3 already on prod |
| 1.75.3 | Configure HomeKit entitlements | Requires Apple Developer signing; may need to build via Xcode GUI first |
| 1.75.4 | Test HomeKit access | Run Prefab.app, verify it discovers homes/devices on the LAN |
| 1.75.5 | Create `launchd` plist | `com.agentforge.prefab.plist` — auto-start, KeepAlive |
| 1.75.6 | Store any Prefab secrets in Keychain | `prefab_webhook_token` (used by eureka-homekit for webhook auth) |
| 1.75.7 | Verify from prod | `curl http://localhost:8080/homes` returns HomeKit data |

### Prefab-Specific Considerations
- **HomeKit entitlements:** Prefab needs code signing with HomeKit capability — this likely means building via Xcode on the prod Mac (or copying a signed .app from dev)
- **First-launch HomeKit permission:** macOS will prompt to allow HomeKit access on first run — must be done interactively
- **Network:** Prod Mac must be on the same LAN as HomeKit hub (should be fine — same Ubiquiti network)
- **Not internet-exposed:** Prefab only listens on localhost:8080

### Port Update
| Port | Service |
|------|---------|
| 8080 | Prefab (HomeKit HTTP bridge) — internal only |

---

## Phase 2: Deploy eureka-homekit (Week 2-3)
> **Goal:** eureka-homekit running on prod alongside nextgen-plaid.

### Prerequisites
- [ ] Phase 1.5 complete — SmartProxy running standalone on :3002
- [ ] Phase 1.75 complete — Prefab running on prod at :8080
- [ ] Determine: deploy `eureka-homekit` or `eureka-homekit-rebuild`? (rebuild may supersede)
- [ ] Verify HomeKit mDNS/Bonjour works on prod network (requires same LAN as HomeKit devices)

### Steps
| # | Task | Notes |
|---|------|-------|
| 2.1 | Clone repo to `~/Development/eureka-homekit/` on prod | Same pattern as nextgen-plaid |
| 2.2 | Install Node deps (`yarn install`) | JS/CSS bundling requires Node + Yarn |
| 2.3 | Create production databases | `eureka_homekit_production`, `_cache`, `_queue` |
| 2.4 | Store secrets in Keychain | `EUREKA_HOMEKIT_DATABASE_PASSWORD`, `RAILS_MASTER_KEY` |
| 2.5 | Create `Procfile.prod` | `web` (port 3001), `worker` (Solid Queue), `js` build (one-time, not watch) |
| 2.6 | Create `bin/prod` launcher | Same pattern as nextgen-plaid |
| 2.7 | Create `launchd` plist | `com.agentforge.eureka-homekit.plist` |
| 2.8 | Configure Cloudflare Tunnel | `homekit.api.higroundsolution.com → :3001` |
| 2.9 | Add `/health` endpoint | |
| 2.10 | Create `bin/deploy-prod` | |
| 2.11 | Create RUNBOOK.md | |
| 2.12 | Test HomeKit device discovery | Critical — mDNS may need network config |

### eureka-homekit Secrets Inventory
| Secret | Source |
|--------|--------|
| `RAILS_MASTER_KEY` | `config/master.key` |
| `EUREKA_HOMEKIT_DATABASE_PASSWORD` | New — create during setup |
| `prefab_webhook_token` | Rails credentials — Prefab uses this to authenticate webhook callbacks |
| `PREFAB_API_URL` | Non-secret config — defaults to `http://localhost:8080` |

### Port Allocation
| Service | Port |
|---------|------|
| eureka-homekit (Rails) | 3001 |
| nextgen-plaid (Rails) | 3000 |
| SmartProxy (Sinatra) | 3002 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| Ollama | 11434 |

---

## Phase 3: Secrets & Security Hardening (Week 3-4)
> **Goal:** No plaintext secrets anywhere. Documented access controls.

### Steps
| # | Task | Notes |
|---|------|-------|
| 3.1 | Audit all secrets across all repos | Create master inventory |
| 3.2 | Rotate all API keys | Plaid, Claude, Grok, Finnhub, FMP, Proxy token |
| 3.3 | Clean git history of `.env` files (if ever committed) | `git filter-repo` or BFG |
| 3.4 | Standardize: `.env` = dev/sandbox only | No production values in `.env` files |
| 3.5 | Document Keychain usage in RUNBOOK | How to add/update/read secrets |
| 3.6 | Evaluate Doppler for multi-machine scaling | Decision point: stay Keychain or migrate |
| 3.7 | SSH key audit on prod server | Document who has access |
| 3.8 | Enable GitHub branch protection on `main` | Require PR reviews before merge |

### Secrets Inventory (All Apps)
| Secret | App | Current Location |
|--------|-----|-----------------|
| `PLAID_CLIENT_ID` | nextgen-plaid | `.env` (plaintext) |
| `PLAID_SECRET` | nextgen-plaid | `.env` (plaintext) |
| `ENCRYPTION_KEY` | nextgen-plaid | `.env` (plaintext) |
| `CLAUDE_CODE_API_KEY` | nextgen-plaid / SmartProxy | `.env` (plaintext) |
| `GROK_API_KEY` | nextgen-plaid / SmartProxy | `.env` (plaintext) |
| `PROXY_AUTH_TOKEN` | nextgen-plaid / SmartProxy | `.env` (plaintext) |
| `FINNHUB_API_KEY` | nextgen-plaid | `.env` (plaintext) |
| `FMP_API_KEY` | nextgen-plaid | `.env` (plaintext) |
| `PROD_USER_PASSWORD` | nextgen-plaid | `.env.production` (plaintext) |
| `NEXTGEN_PLAID_DATABASE_PASSWORD` | nextgen-plaid | `.env.production` (plaintext) |
| `RAILS_MASTER_KEY` (nextgen) | nextgen-plaid | `config/master.key` |
| `RAILS_MASTER_KEY` (homekit) | eureka-homekit | `config/master.key` |
| `EUREKA_HOMEKIT_DATABASE_PASSWORD` | eureka-homekit | TBD |

---

## Phase 4: Observability (Week 4-6)
> **Goal:** Know when something breaks before users tell you.

### Steps
| # | Task | Notes |
|---|------|-------|
| 4.1 | Structured JSON logging in all Rails apps | `config.log_formatter` in production.rb |
| 4.2 | Centralized log directory | `~/logs/{app-name}/` with rotation |
| 4.3 | Install Uptime Kuma (lightweight) | Single binary, monitors `/health` endpoints |
| 4.4 | Basic alerting | Email or Pushover on health check failures |
| 4.5 | PostgreSQL monitoring | Connection count, slow queries, disk usage |
| 4.6 | Evaluate Grafana + Loki | Decision point: when warranted by scale |

---

## Phase 5: CI/CD Pipeline (Week 6-8)
> **Goal:** Push to `main` → automatic deploy to production.

### Steps
| # | Task | Notes |
|---|------|-------|
| 5.1 | Standardize GitHub Actions CI across all projects | Shared workflow templates |
| 5.2 | Add deployment step to CI | On merge to `main`: SSH → git pull → restart |
| 5.3 | GitHub Actions self-hosted runner on prod (optional) | Avoids SSH-from-cloud security concern |
| 5.4 | Pre-deploy checks | Run tests, security scan, then deploy |
| 5.5 | Rollback mechanism | `bin/rollback-prod` script (git checkout previous tag) |
| 5.6 | Git tagging for releases | `v1.0.0`, `v1.0.1` etc. |

---

## Phase 6: Docker & Containerization (Week 8+)
> **Goal:** Containerize for reproducibility and easier scaling. Only after native deployment is stable.

### When to Trigger This Phase
- Need to run same app on multiple machines
- Dependency conflicts between apps on same host
- Want reproducible environments across dev/staging/prod
- Team grows and onboarding needs to be faster

### Steps
| # | Task | Notes |
|---|------|-------|
| 6.1 | Dockerize nextgen-plaid (Dockerfile already exists) | Test with existing Docker setup |
| 6.2 | Dockerize eureka-homekit | HomeKit mDNS needs host networking |
| 6.3 | Configure Kamal for deployment | `config/deploy.yml` already scaffolded |
| 6.4 | Set up container registry (ghcr.io) | Free with GitHub |
| 6.5 | Migrate launchd → Docker Compose or Kamal | One service manager instead of many plists |

---

## Phase 7: Local AI Operations Assistant (Week 8+)
> **Goal:** Use the on-box Ollama instance as a private DevOps/code assistant — slower but zero cloud cost and no data exposure.

### Available Models (already pulled)
| Model | Params | Best For |
|-------|--------|----------|
| `llama3.1:70b` | 70B | General reasoning, code review, operational Q&A |
| `llama3-groq-tool-use:70b` | 70B | Automated tool-calling / agent workflows |
| `vanilj/palmyra-fin-70b-32k` | 70B | Financial domain analysis (fits nextgen-plaid) |
| `llama3.1:8b` | 8B | Fast lightweight tasks, log summarization |
| `nomic-embed-text` | 137M | RAG embeddings for knowledge base search |

### Potential Uses
| Use Case | Model | Integration Point |
|----------|-------|-------------------|
| Deploy pre-flight code review | `llama3.1:70b` | `bin/deploy-prod` calls Ollama before deploying |
| Log anomaly detection | `llama3.1:8b` | Cron job summarizes `~/logs/` and flags issues |
| Runbook Q&A assistant | `llama3.1:70b` + `nomic-embed-text` | RAG over RUNBOOK.md files |
| Financial data sanity checks | `palmyra-fin-70b` | Post-sync validation in Solid Queue jobs |
| Automated incident summaries | `llama3.1:70b` | Triggered by health check failures |

### Architecture
```
SmartProxy (:3002) ← already fronts Ollama
     ↓
Ollama (:11434) ← already running, auto-starts
     ↓
Models loaded on demand (256 GB RAM — any 70B fits)
```

No new infrastructure needed. SmartProxy already proxies to Ollama. The question is just building the automation scripts that call it.

---

## Phase 8: Advanced Operations (Ongoing)
> **Goal:** Mature operations practices.

| # | Task | Phase |
|---|------|-------|
| 8.1 | Database backup automation + verified restores | After Phase 2 |
| 8.2 | Disaster recovery plan + tested runbook | After Phase 3 |
| 8.3 | Performance monitoring (request timing, DB queries) | After Phase 4 |
| 8.4 | Load testing | When user base grows |
| 8.5 | Staging environment (optional) | When risk of prod breakage increases |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-17 | Native macOS first, Docker later | Fastest path; both machines are identical M3 Ultras; apps already run natively |
| 2026-02-17 | macOS Keychain for secrets (Phase 1) | Zero setup, encrypted at rest, already on both machines; Doppler evaluated for later |
| 2026-02-17 | nextgen-plaid is P0, eureka-homekit P1 | nextgen-plaid already running (poorly) on prod; eureka-homekit not deployed yet |
| 2026-02-17 | Foreman + launchd for process management | Foreman already in use; launchd is the native macOS supervisor |
| 2026-02-17 | Port 80 → 3000 via pf, not Cloudflare Tunnel | UDM-SE forwards port 80 to prod; macOS pf anchor `com.nextgen.plaid` redirects to Puma on 3000 |
| 2026-02-17 | Ollama as local AI ops assistant (Phase 7) | 256GB RAM handles 70B models; zero cloud cost; SmartProxy already fronts it |
| 2026-02-17 | SmartProxy extraction to standalone (Phase 1.5) | Already extracted to own repo; both nextgen-plaid and eureka-homekit will consume it; must run independently before eureka-homekit can deploy |
| 2026-02-17 | Prefab (HomeKit bridge) required before eureka-homekit (Phase 1.75) | Swift fork at ericsmith66/prefab; eureka-homekit's PrefabClient connects to localhost:8080; needs HomeKit entitlements and device LAN access |
| TBD | Doppler vs stay on Keychain | Evaluate at Phase 3 based on team size and multi-machine needs |
| TBD | Docker migration timing | Evaluate at Phase 6 based on operational needs |

---

## Port Registry

| Port | Service | Exposed to Internet | Notes |
|------|---------|-------------------|-------|
| 80 | pf redirect → 3000 | Yes — UDM-SE forwards here | `/etc/pf.anchors/com.nextgen.plaid` |
| 3000 | nextgen-plaid (Rails) | Yes (via port 80 redirect) | Puma |
| 3001 | eureka-homekit (Rails) | Planned (via Cloudflare Tunnel) | Not deployed yet |
| 3002 | SmartProxy (Sinatra) | No — internal only | Shared AI gateway for all apps; fronts Claude/Grok/Ollama |
| 5432 | PostgreSQL 16 | No — localhost only | Homebrew LaunchAgent |
| 6379 | Redis 7 | No — localhost only | Homebrew LaunchAgent |
| 8080 | Prefab (HomeKit bridge) | No — localhost only | Swift/macOS app; eureka-homekit dependency |
| 11434 | Ollama | No — localhost only | macOS app, auto-starts |

---

**Next Action:** Execute [roadmap-nextgen-plaid.md](roadmap-nextgen-plaid.md) Phase 1
