Here's your updated **README.md** with **all known/current endpoints from Prefab** (the ones the CLI interacts with + the outbound webhook endpoints it sends to Rails) fully documented in a clear table.

This includes:
- Inbound endpoints (what Rails should expose to receive Prefab webhooks)
- Outbound endpoints (what Prefab exposes for manual querying/control via CLI or curl)
- Notes on how they fit into Eureka-HomeKit

Copy-paste this into `/Users/ericsmith66/development/eureka-homekit/README.md`

```markdown
# Eureka HomeKit

**AI-powered HomeKit bridge** connecting real-time HomeKit accessory events → Rails backend → local AI decisions (Ollama) → secure Plaid financial actions (via nextgen-plaid/smart-proxy).

Built for an M3 Ultra server running macOS, Postgres, Ollama, and your smart-proxy Rails app.

## Architecture

```
HomeKit Accessories
│
▼ (native callbacks + polling fallback)
Prefab (Swift bridge on macOS)
│
▼ HTTP webhook POSTs (outbound from Prefab)
Rails App (this repo) ──► Postgres
│
▼ AI Agent (Ollama) decides action
│
▼ Calls nextgen-plaid/smart-proxy ──► Plaid API
│
▼ Optional: PUT back to Prefab endpoints to control HomeKit
```

- **Prefab**: Modified fork that monitors HomeKit and pushes events via webhooks  
- **Rails**: Central logic — receives events, stores them, runs AI reasoning, triggers Plaid flows  
- **Ollama**: Local LLM for decisions  
- **nextgen-plaid/smart-proxy**: Your secure Plaid proxy (already running)

## Requirements

- macOS 14.2+ (M3 Ultra recommended)
- Xcode 15+ (to build Prefab)
- Ruby 3.2+ & Rails 7+
- PostgreSQL
- Ollama (strong model recommended)
- nextgen-plaid/smart-proxy running

## Setup

### 1. Prefab (HomeKit Bridge)

```bash
cd /Users/ericsmith66/development
git clone https://github.com/ericsmith66/prefab.git prefab-bridge
cd prefab-bridge
git checkout main
```

Build:

```bash
# In Xcode: open prefab.xcodeproj → Cmd+B
# Or CLI:
xcodebuild -scheme Prefab -configuration Release
```

Copy:

```bash
mkdir -p ~/Applications/Server
cp -R ~/Library/Developer/Xcode/DerivedData/prefab-*/Build/Products/Release/Prefab.app ~/Applications/Server/
cp ~/Library/Developer/Xcode/DerivedData/prefab-*/Build/Products/Release/prefab ~/Applications/Server/
```

Config (`~/Library/Application Support/Prefab/config.json`):

```json
{
  "webhook": {
    "url": "http://localhost:3000/api/homekit/events",
    "authToken": "sk_live_eureka_abc123xyz789",
    "enabled": true
  },
  "polling": {
    "intervalSeconds": 10.0,
    "enabled": true,
    "reportIntervalSeconds": 300.0
  },
  "deviceRegistry": {
    "mode": "whitelist",
    "devices": ["Front Door Lock", "Kitchen Motion", "Living Room Thermostat"]
  },
  "logging": {
    "enabled": false
  }
}
```

Run:

```bash
open -a ~/Applications/Server/Prefab.app
```

### 2. Eureka-HomeKit Rails App

```bash
cd /Users/ericsmith66/development/eureka-homekit
bundle install
rails db:create db:migrate
rails s
```

### Backup & Restore (DB + Active Storage)

**Backup (development DB + local Active Storage):**

```bash
cd /Users/ericsmith66/development/eureka-homekit
backup_dir="tmp/backup_YYYYMMDD_HHMM"
mkdir -p "$backup_dir"

# Postgres dump (custom format)
pg_dump -Fc -f "$backup_dir/eureka_homekit_development.dump" eureka_homekit_development

# Active Storage (local disk service)
tar -czf "$backup_dir/storage.tar.gz" storage
```

**Restore:**

```bash
cd /Users/ericsmith66/development/eureka-homekit

# Restore DB (drops/recreates objects from the dump)
pg_restore -c -d eureka_homekit_development tmp/backup_YYYYMMDD_HHMM/eureka_homekit_development.dump

# Restore Active Storage files
tar -xzf tmp/backup_YYYYMMDD_HHMM/storage.tar.gz -C .
```

Notes:
- This assumes the `local` Active Storage service (`storage/`), per `config/storage.yml`.
- Stop the Rails server before restoring to avoid file/DB contention.

Frontend: Tailwind + DaisyUI + esbuild

## All Endpoints

### A. Outbound from Prefab → Rails (Webhooks sent by Prefab)

These are the endpoints **your Rails app must expose** to receive real-time events.

| Method | Path                              | Triggered by Prefab when…                          | Payload Example                                                                 | Auth Header                  |
|--------|-----------------------------------|----------------------------------------------------|---------------------------------------------------------------------------------|------------------------------|
| POST   | `/api/homekit/events`             | Any HomeKit characteristic value changes           | `{ "type": "characteristic_updated", "accessory": "Front Door", "characteristic": "Lock Current State", "value": 1, "timestamp": "2026-01-25T15:12:34Z" }` | `Authorization: Bearer <token>` (from config) |
| POST   | `/api/homekit/homes_updated`      | Home list changes (added/removed home) – rare      | `{ "type": "homes_updated", "home_count": 2, "timestamp": "2026-01-25T15:12:34Z" }` | Same as above                |

### B. Inbound to Prefab (Queryable / Controllable via CLI or curl)

These run on Prefab's HTTP server (**localhost:8080** or server IP:8080).  
Mainly used by the `prefab` CLI or for manual/debug control.

| Method | Path                                      | Purpose                                            | Example CLI Command                  | Response Type |
|--------|-------------------------------------------|----------------------------------------------------|--------------------------------------|---------------|
| GET    | `/homes`                                  | List all HomeKit homes                             | `prefab homes`                       | JSON array    |
| GET    | `/homes/:home`                            | Details for a specific home                        | `prefab home LivingRoom`             | JSON object   |
| GET    | `/rooms/:home`                            | List rooms in a home                               | `prefab rooms LivingRoom`            | JSON array    |
| GET    | `/rooms/:home/:room`                      | Details for a specific room                        | —                                    | JSON object   |
| GET    | `/accessories/:home/:room`                | List accessories in a room                         | `prefab accessories LivingRoom Kitchen` | JSON array |
| GET    | `/accessories/:home/:room/:accessory`     | Details for a specific accessory (state, chars)    | —                                    | JSON object   |
| PUT    | `/accessories/:home/:room/:accessory`     | Update accessory state (e.g. turn light on/off)    | — (manual curl)                      | 200 OK        |
| GET    | `/scenes/:home`                           | List scenes in a home                              | `prefab scenes LivingRoom`           | JSON array    |
| POST   | `/scenes/:home/:scene/execute`            | Trigger/execute a scene                            | —                                    | 200 OK        |
| GET    | `/groups/:home`                           | List accessory groups                              | —                                    | JSON array    |
| PUT    | `/groups/:home/:group`                    | Update group settings                              | —                                    | 200 OK        |

**Notes on Prefab endpoints**:
- All are JSON
- `:home`, `:room`, `:accessory` can be names (URL-encoded) or UUIDs
- Use `curl http://localhost:8080/homes` for quick testing
- Prefab must be running for these to respond
- No built-in auth on Prefab side — protect with firewall/reverse proxy if exposed

## Frontend Styling

Tailwind CSS + DaisyUI for rapid, beautiful UI.

Example:

```erb
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title text-primary">Latest Event</h2>
    <p>Front Door unlocked</p>
    <div class="card-actions justify-end">
      <button class="btn btn-secondary">Details</button>
    </div>
  </div>
</div>
```

## Development Tools

- IDE: **RubyMine**
- AI coding: **Aider Desktop** (Ollama)
- LLM: Ollama on M3 Ultra
- Plaid: nextgen-plaid/smart-proxy

## Security

- Validate webhook `Authorization` header
- Use HTTPS locally (mkcert)
- Keep tokens out of git

## Roadmap

- Webhook receiver + HomeKitEvent model
- Ollama decision prompts
- Sidekiq for async jobs
- Dashboard with live events + AI suggestions

Happy building!  
Questions? → Issues or @ericsmith66
```

This now includes **every endpoint** we know about from Prefab (both directions), with examples and context for your project.

Want to add:
- A sample webhook controller code block?
- launchd setup for Prefab?
- First Ollama prompt example?

Just let me know what to tackle next.