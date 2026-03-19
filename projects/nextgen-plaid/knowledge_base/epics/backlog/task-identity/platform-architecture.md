# Cross-App Platform Architecture: Task Manager, Identity & Notifications

**Created:** February 20, 2026
**Status:** Backlog / Architecture Planning
**Scope:** All agent-forge ecosystem apps

---

## Table of Contents

1. [Ecosystem Inventory](#1-ecosystem-inventory)
2. [Architecture Decision: Shared Gem + Shared Database](#2-architecture-decision-shared-gem--shared-database)
3. [Network Topology — Apps Stay Separate](#3-network-topology--apps-stay-separate)
4. [Identity: One Table, Two Types](#4-identity-one-table-two-types)
5. [Task Manager](#5-task-manager)
6. [Notification Service (Twilio)](#6-notification-service-twilio)
7. [The Shared Gem (platform-core)](#7-the-shared-gem-platform-core)
8. [Migration Plan](#8-migration-plan)
9. [Microservices Decomposition (Future Reference)](#9-microservices-decomposition-future-reference)

---

## 1. Ecosystem Inventory

| App | Stack | Auth Today | DB | Port |
|-----|-------|-----------|-----|------|
| **nextgen-plaid** | Rails 8.0, PostgreSQL | Devise (email/password, roles: owner/admin/parent/kid, family_id) | nextgen_plaid_db | 3000 |
| **eureka-homekit** | Rails 8.1, PostgreSQL | None (session-based UserPreference) | eureka_homekit_db | 3001 |
| **agent-forge** | Rails 8.1, PostgreSQL | Devise (minimal — email/password only) | agent_forge_db | 3003 |
| **SmartProxy** | Sinatra, Puma | Bearer token (env var) | None | 3002 |
| **overwatch** | Docs/scripts only | N/A | N/A | N/A |

### Infrastructure
- **Server:** M3 Ultra @ 192.168.4.253 (macOS, 256 GB RAM, 1.8TB disk)
- **Network:** ATT Fiber → Ubiquiti UDM-SE → Cloudflare Tunnel
- **Public Domain:** `api.higroundsolution.com`
- **PostgreSQL:** 16.11 (Homebrew) on same server
- **Users:** ~8 humans (Smith family), ~8-16+ AI agents
- **Developer:** Single developer

---

## 2. Architecture Decision: Shared Gem + Shared Database

### Why NOT Microservices

For 8 humans and ~16 agents on a single server with a single developer, microservices add operational overhead with no benefit. The chosen approach:

> **One shared `platform_db` PostgreSQL database** that all apps connect to as a secondary database, alongside their own app-specific DB. Shared logic packaged as a Ruby gem.

| Shared Gem (chosen) | Separate API Service |
|---|---|
| Direct DB access — no HTTP overhead | HTTP calls between apps |
| Shared migrations run from any app | Separate deployment/monitoring |
| ActiveRecord callbacks work naturally | Webhook plumbing for events |
| One codebase change, all apps get it | Must version & deploy independently |
| Trivial for 1 developer | Operational overhead for 1 developer |
| Perfect for 8 users on 1 server | Over-engineered for this scale |

### Future Escape Hatch

If apps ever need to run on different servers or be maintained by different teams, the shared DB can be promoted to a proper API service:

```
Phase 1 (now):     Shared gem + shared DB     ← Simple, right-sized
Phase 2 (maybe):   Extract platform-api app   ← Only if you outgrow Phase 1
```

---

## 3. Network Topology — Apps Stay Separate

Each app remains a fully independent process. The shared gem is just a library loaded in-process, not a service.

### Cloudflare Tunnel Routing (Single Public IP)

```
        Internet
           │
    ┌──────▼──────┐
    │  Cloudflare  │  ← Middleware/router (already configured)
    │  Tunnel      │
    └──────┬──────┘
           │  ATT Fiber → UDM-SE → 192.168.4.253
           │
    ┌──────▼──────────────────────────────────┐
    │  M3 Ultra (256GB RAM)                   │
    │                                         │
    │  :3000  nextgen-plaid      (own DB)     │
    │  :3001  eureka-homekit     (own DB)     │
    │  :3002  SmartProxy         (no DB)      │
    │  :3003  agent-forge        (own DB)     │
    │                                         │
    │  PostgreSQL 16.11                       │
    │    ├─ nextgen_plaid_db                  │
    │    ├─ eureka_homekit_db                 │
    │    ├─ agent_forge_db                    │
    │    └─ platform_db  ← NEW (shared)       │
    └─────────────────────────────────────────┘
```

Subdomain routing:

```
plaid.api.higroundsolution.com    →  localhost:3000  (nextgen-plaid)
homekit.api.higroundsolution.com  →  localhost:3001  (eureka-homekit)
forge.api.higroundsolution.com    →  localhost:3003  (agent-forge)
proxy.api.higroundsolution.com    →  localhost:3002  (SmartProxy)
```

### What stays separate (independent apps):
- Each app is its own Rails process on its own port
- Each app has its own database for its own domain data
- Each app deploys independently
- Each app has its own routes, controllers, views
- Cloudflare routes the right traffic to the right app

### What's shared (via the gem + shared DB):
- **Identity** — "who is Eric" is the same answer in all apps
- **Tasks** — create a task in nextgen-plaid, see it in agent-forge
- **Notifications** — any app can SMS Eric via the same Twilio logic

---

## 4. Identity: One Table, Two Types

### Shared Database Connection (each app's database.yml)

```yaml
production:
  primary:
    <<: *default
    database: nextgen_plaid_production  # app's own DB

  platform:
    <<: *default
    database: platform_production       # shared platform DB
    migrations_paths: db/platform_migrate
```

```ruby
# Shared base class for platform models
class PlatformRecord < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: { writing: :platform, reading: :platform }
end
```

### Identity Model

```ruby
class Identity < PlatformRecord
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id
  has_many :created_tasks,  class_name: "Task", foreign_key: :creator_id
  has_many :notification_preferences

  # Fields:
  #   id (bigint PK)
  #   type          — "human" or "agent"
  #   handle        — unique slug: "eric", "madison", "sap-agent", "cwa"
  #   display_name  — "Eric Smith", "Madison Lauderbauck", "SAP Agent"
  #   email         — nullable (agents don't have email)
  #   phone         — nullable (for Twilio, humans only)
  #   role          — "owner", "admin", "parent", "kid", "agent"
  #   home_app      — "nextgen-plaid", "eureka-homekit", etc. (where agent lives)
  #   avatar_url    — optional
  #   active        — boolean
  #   metadata      — jsonb (app-specific extras)
  #   created_at, updated_at
end
```

### Seed Data (~24 rows)

```ruby
# db/platform_seeds.rb — run once, idempotent

# === 8 Humans ===
Identity.find_or_create_by!(handle: "eric") do |i|
  i.type = "human"
  i.display_name = "Eric Smith"
  i.email = "ericsmith66@me.com"
  i.phone = "+1555XXXXXXX"
  i.role = "owner"
end
# ... 7 more family members ...

# === Agents (seeded from each app's config) ===
Identity.find_or_create_by!(handle: "madison") do |i|
  i.type = "agent"
  i.display_name = "Madison Lauderbauck"
  i.role = "agent"
  i.home_app = "nextgen-plaid"
  i.metadata = { persona_id: "financial-advisor", model: "llama3.1:70b" }
end

Identity.find_or_create_by!(handle: "sap-agent") do |i|
  i.type = "agent"
  i.display_name = "SAP Agent"
  i.role = "agent"
  i.home_app = "nextgen-plaid"
end

Identity.find_or_create_by!(handle: "cwa") do |i|
  i.type = "agent"
  i.display_name = "CWA Agent"
  i.role = "agent"
  i.home_app = "nextgen-plaid"
end
# ... more agents as you add them ...
```

### Linking Identities to App-Specific Users

Devise stays per-app for session management. Each app maps its local user to the shared identity via `identity_id` FK:

```ruby
# nextgen-plaid
class User < ApplicationRecord
  belongs_to :platform_identity, class_name: "Identity",
             foreign_key: :identity_id, optional: true
end

# eureka-homekit
class UserPreference < ApplicationRecord
  belongs_to :platform_identity, class_name: "Identity",
             foreign_key: :identity_id, optional: true
end

# agent-forge
class User < ApplicationRecord
  belongs_to :platform_identity, class_name: "Identity",
             foreign_key: :identity_id, optional: true
end
```

---

## 5. Task Manager

### Data Model

```ruby
class Task < PlatformRecord
  belongs_to :creator,  class_name: "Identity"
  belongs_to :assignee, class_name: "Identity", optional: true
  belongs_to :parent,   class_name: "Task", optional: true
  has_many   :subtasks, class_name: "Task", foreign_key: :parent_id
  has_many   :comments, dependent: :destroy
  has_many   :task_links, dependent: :destroy
  has_many   :task_labels
  has_many   :labels, through: :task_labels

  enum :status, {
    backlog: 0, todo: 1, in_progress: 2,
    blocked: 3, in_review: 4, done: 5, cancelled: 6
  }
  enum :priority, { low: 0, medium: 1, high: 2, critical: 3 }

  # Fields:
  #   title, description (text),
  #   source_app      — which app created it
  #   creator_id      — Identity FK (human or agent)
  #   assignee_id     — Identity FK (human or agent)
  #   creator_type    — "human" / "agent" (denormalized for quick queries)
  #   status, priority, due_date, completed_at,
  #   metadata (jsonb), created_at, updated_at
end

class TaskLink < PlatformRecord
  belongs_to :task
  # Cross-app resource references (NO foreign keys — just identifiers)
  # Fields:
  #   app_slug       — "nextgen-plaid"
  #   resource_type  — "PlaidItem", "Scene", "Project"
  #   resource_id    — "42"
  #   resource_url   — "/mission_control" (deep link within that app)
  #   label          — "Chase checking account"
end

class Comment < PlatformRecord
  belongs_to :task
  belongs_to :author, class_name: "Identity"
  # Fields: body (text), author_type ("human"/"agent"), created_at
end

class Label < PlatformRecord
  # Fields: name, color, scope (nil=global, or app_slug)
end
```

### Usage Examples

```ruby
# SAP agent creates a task for a human
task = Task.create!(
  title: "Plaid re-link required: Chase",
  description: "ITEM_LOGIN_REQUIRED error on PlaidItem #7",
  source_app: "nextgen-plaid",
  creator: Identity.find_by!(handle: "sap-agent"),
  assignee: Identity.find_by!(handle: "eric"),
  creator_type: "agent",
  priority: :high,
  status: :todo
)
task.task_links.create!(
  app_slug: "nextgen-plaid",
  resource_type: "PlaidItem",
  resource_id: "7",
  resource_url: "/mission_control",
  label: "Chase checking PlaidItem"
)

# Human creates a task for an agent in eureka-homekit
Task.create!(
  title: "Investigate why bedroom Hue lights are unresponsive",
  source_app: "eureka-homekit",
  creator: Identity.find_by!(handle: "eric"),
  assignee: Identity.find_by!(handle: "homekit-monitor"),
  creator_type: "human",
  priority: :medium,
  status: :todo
)

# Cross-app dashboard — see ALL tasks from any app
my_tasks = Task.where(assignee: current_identity)
              .or(Task.where(creator: current_identity))
              .order(priority: :desc, created_at: :desc)
```

---

## 6. Notification Service (Twilio)

### Data Model

```ruby
class NotificationChannel < PlatformRecord
  belongs_to :identity
  # Fields: channel_type (sms/voice/whatsapp), address, verified, primary
end

class NotificationPreference < PlatformRecord
  belongs_to :identity
  # Fields:
  #   event_type    — "task.assigned", "task.overdue", "plaid.sync_failed"
  #   app_slug      — nil (global) or "nextgen-plaid" (app-specific)
  #   channel_type  — "sms", "voice"
  #   enabled       — boolean
  #   quiet_start   — time (e.g. 22:00)
  #   quiet_end     — time (e.g. 07:00)
end

class NotificationLog < PlatformRecord
  belongs_to :identity
  # Fields:
  #   event_type, app_slug, channel_type, recipient_address,
  #   body, status (queued/sent/delivered/failed),
  #   twilio_sid, error_message, idempotency_key,
  #   sent_at, delivered_at, created_at
end
```

### Notifier Service

```ruby
# gems/platform-core/lib/platform/notifier.rb
module Platform
  class Notifier
    def self.send_sms(identity:, event_type:, app_slug:, message:, idempotency_key: nil)
      pref = NotificationPreference.find_by(
        identity: identity, event_type: event_type, channel_type: "sms"
      )
      return unless pref&.enabled?
      return if in_quiet_hours?(pref)
      return if already_sent?(idempotency_key)

      channel = identity.notification_channels.find_by(channel_type: "sms", primary: true)
      return unless channel

      twilio_message = TwilioClient.messages.create(
        from: ENV["TWILIO_FROM_NUMBER"],
        to: channel.address,
        body: message
      )

      NotificationLog.create!(
        identity: identity, event_type: event_type, app_slug: app_slug,
        channel_type: "sms", recipient_address: channel.address,
        body: message, status: "sent", twilio_sid: twilio_message.sid,
        idempotency_key: idempotency_key, sent_at: Time.current
      )
    end
  end
end
```

### Usage From Any App

```ruby
# nextgen-plaid — Plaid sync failure
Platform::Notifier.send_sms(
  identity: Identity.find_by!(handle: "eric"),
  event_type: "plaid.sync_failed",
  app_slug: "nextgen-plaid",
  message: "⚠️ Chase checking Plaid sync failed. Re-link needed.",
  idempotency_key: "plaid-item-7-sync-fail-#{Date.current}"
)

# eureka-homekit — security event
Platform::Notifier.send_sms(
  identity: Identity.find_by!(handle: "eric"),
  event_type: "homekit.security_alert",
  app_slug: "eureka-homekit",
  message: "🚪 Front door opened at #{Time.current.strftime('%I:%M %p')}"
)

# Task auto-notification on assignment
after_commit :notify_assignee, on: [:create, :update]
def notify_assignee
  return unless assignee && saved_change_to_assignee_id?
  return unless assignee.type == "human"

  Platform::Notifier.send_sms(
    identity: assignee,
    event_type: "task.assigned",
    app_slug: source_app,
    message: "📋 New task: #{title} (#{priority})",
    idempotency_key: "task-#{id}-assigned-#{assignee_id}"
  )
end
```

### Built-in Protections

| Protection | Implementation |
|-----------|---------------|
| Rate limiting | Max 10 SMS/hour per identity (configurable) |
| Deduplication | `idempotency_key` prevents duplicate sends within 24h |
| Quiet hours | Per-user preference; `urgent` priority bypasses |
| Retry with backoff | Failed deliveries retry 3x with exponential backoff |
| Cost tracking | Log Twilio cost per message for monitoring |

---

## 7. The Shared Gem (platform-core)

### Directory Structure

```
agent-forge/
  gems/
    platform-core/
      lib/
        platform.rb
        platform/
          platform_record.rb        # Base class (connects_to :platform)
          identity.rb               # Identity model
          task.rb                   # Task model
          task_link.rb
          comment.rb
          label.rb
          notifier.rb               # Twilio sender
          notification_channel.rb
          notification_preference.rb
          notification_log.rb
      db/
        migrate/                    # Platform DB migrations
          001_create_identities.rb
          002_create_tasks.rb
          003_create_notifications.rb
      config/
        seeds/
          identities.rb             # Seed the 8 humans + agents
      platform-core.gemspec
  projects/
    nextgen-plaid/      # gem "platform-core", path: "../../gems/platform-core"
    eureka-homekit/     # gem "platform-core", path: "../../gems/platform-core"
    agent-forge/        # gem "platform-core", path: "../../gems/platform-core"
    SmartProxy/         # (optional — only if it needs task/notify access)
```

### Installation in Each App

```ruby
# Gemfile
gem "platform-core", path: "../../gems/platform-core"
```

---

## 8. Migration Plan

### Step 1: Create the gem + platform_db (Day 1-2)
- Create gem structure, PlatformRecord base class, migrations
- Create `platform_production` database
- Run migrations to create identities, tasks, notifications tables
- Seed 8 humans + known agents

### Step 2: Wire up nextgen-plaid (Day 3-4)
- Add `gem "platform-core"` to Gemfile
- Add `platform:` connection to `database.yml`
- Migration: add `identity_id` to `users` table
- One-time script: match users by email → identity, backfill `identity_id`
- Wrap existing SAP agent / persona code to use Identity for task creation

### Step 3: Wire up agent-forge + eureka-homekit (Day 5-6)
- Same pattern — add gem, add DB connection, add `identity_id` to local user/preference tables
- eureka-homekit: add optional login (Devise) or just map sessions → identities

### Step 4: Build Task UI + Notification preferences (Day 7-10)
- Add task list/create views to each app (or shared ViewComponent in the gem)
- Configure Twilio credentials
- Set up notification preferences for each family member
- Wire up key events to notifications

---

## 9. Microservices Decomposition (Future Reference)

If the ecosystem ever outgrows the shared-gem approach, here is the recommended decomposition into 6 bounded contexts. **This is NOT recommended now** — it's preserved for future reference.

### Proposed Services

| # | Service | Responsibility | Extract When |
|---|---------|---------------|-------------|
| 1 | **Identity & Core** (residual monolith) | User auth, settings, web shell, admin | Never — stays as monolith shell |
| 2 | **Plaid Integration** | All Plaid API comms, OAuth, webhooks, sync | Adding more data providers (Yodlee, MX) |
| 3 | **Portfolio & Holdings** | Holdings, snapshots, enrichment, asset classification | Portfolio queries bottleneck OLTP |
| 4 | **Transactions & Enrichment** | Transaction storage, categorization, merchants | Transaction volume exceeds single-DB capacity |
| 5 | **AI Agent Platform** | Agent Hub, SAP, AI Workflow, Persona Chats | AI workload needs independent scaling |
| 6 | **Reporting & Snapshots** | Financial snapshots, net worth, dashboards | Analytical queries need OLAP separation |

### Recommended Extraction Order

```
Phase 0: Modular Monolith (Packwerk)           ← Enforce boundaries first
Phase 1: Extract AI Agent Platform (Service 5)  ← Biggest service count, least coupling
Phase 2: Extract Plaid Integration (Service 2)  ← Independent scaling, webhook isolation
Phase 3: Extract Reporting/Snapshots (Svc 6)    ← Read-heavy, can use read replica
Phase 4: Split Portfolio & Transactions          ← Only if scale demands
```

### Communication Patterns (When Decomposed)

| Pattern | Use Case | Technology |
|---------|----------|------------|
| Synchronous REST | UI → Service queries | JSON API over HTTP/2 |
| Synchronous gRPC | Service → Service high-perf | Protocol Buffers |
| Async Events | Data pipeline (syncs → enrichment) | Solid Queue → Kafka |
| WebSocket | Real-time chat | ActionCable |

### Key Events (When Decomposed)

```
plaid.accounts.synced       → Portfolio, Transactions, Reporting
plaid.holdings.synced       → Portfolio
plaid.transactions.synced   → Transactions
portfolio.snapshot.created  → Reporting
transaction.enriched        → Reporting
agent.workflow.completed    → Core (notifications)
```

---

## Appendix: nextgen-plaid Current State

- **Models:** 42 (User, PlaidItem, Account, Holding, Transaction, etc.)
- **Services:** 82 (Plaid sync, Agent Hub, SAP Agent, AI Workflow, Reporting, etc.)
- **Controllers:** 45 (net_worth/, portfolio/, transactions/, admin/, agents/)
- **Jobs:** 20 (sync, enrichment, snapshots, agent processing)
- **Tables:** 36
- **Auth:** Devise with roles (owner/admin/parent/kid), family_id scoping
- **Owner check:** `email == ENV["OWNER_EMAIL"] || "ericsmith66@me.com"`
