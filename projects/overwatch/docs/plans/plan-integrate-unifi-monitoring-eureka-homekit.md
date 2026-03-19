# Plan: Integrate UniFi Network Monitoring into Eureka-HomeKit
**Created:** February 18, 2026  
**Context:** Eureka-HomeKit already collects home automation data, perfect platform for network monitoring  
**Related:** [Firewall Monitoring Roadmap](../roadmaps/roadmap-firewall-monitoring.md)  
**Status:** PLANNING

---

## Vision

**Unified Home Intelligence Dashboard:**
Combine HomeKit device data + network infrastructure data in one Rails application for complete home observability.

**Why Eureka-HomeKit is Perfect:**
- ✅ Already collects real-time device events
- ✅ Has PostgreSQL for event storage
- ✅ Has ActionCable for real-time updates
- ✅ Has Stimulus controllers for interactive UI
- ✅ Proven architecture (Epic 5 controls, real-time sensors)
- ✅ Running on same M3 Ultra as network
- ✅ Already uses `raw_data` JSONB pattern for flexible data

---

## Architecture Overview

### Current Eureka-HomeKit Structure

```
eureka-homekit/
├── app/
│   ├── models/
│   │   ├── accessory.rb         # HomeKit devices
│   │   ├── sensor.rb            # Sensor readings
│   │   ├── homekit_event.rb     # Device events
│   │   └── control_event.rb     # Control actions
│   ├── services/
│   │   ├── homekit_sync.rb      # Syncs from Prefab
│   │   └── prefab_control_service.rb  # Device control
│   ├── controllers/
│   │   └── api/
│   │       └── homekit_events_controller.rb  # Webhook receiver
│   └── components/
│       ├── controls/            # Device controls
│       └── dashboards/          # Dashboard views
├── db/
│   ├── schema.rb               # PostgreSQL schema
│   └── migrate/
└── config/
    └── routes.rb
```

### Proposed UniFi Integration

```
eureka-homekit/
├── app/
│   ├── models/
│   │   ├── network_device.rb        # NEW: UniFi devices (APs, switches)
│   │   ├── network_client.rb        # NEW: Connected clients
│   │   ├── network_event.rb         # NEW: IPS alerts, firewall events
│   │   ├── network_health.rb        # NEW: Daily health snapshots
│   │   └── network_alert.rb         # NEW: Alerts/notifications
│   ├── services/
│   │   ├── unifi_sync_service.rb    # NEW: Syncs from UniFi API
│   │   ├── unifi_health_service.rb  # NEW: Daily health checks
│   │   └── unifi_alert_service.rb   # NEW: Alert processing
│   ├── controllers/
│   │   └── api/
│   │       └── unifi_events_controller.rb  # NEW: Optional webhook
│   ├── components/
│   │   └── network/                 # NEW: Network dashboard components
│   │       ├── device_status_component.rb
│   │       ├── client_list_component.rb
│   │       ├── ips_alerts_component.rb
│   │       └── health_dashboard_component.rb
│   └── jobs/
│       ├── unifi_sync_job.rb        # NEW: Scheduled sync (every 5 min)
│       └── unifi_health_job.rb      # NEW: Daily health check
├── lib/
│   └── unifi/
│       ├── client.rb                # NEW: UniFi API wrapper
│       └── cloud_client.rb          # NEW: UniFi Cloud API wrapper
└── config/
    └── credentials/
        └── unifi.yml.enc            # NEW: Encrypted credentials
```

---

## Database Schema

### New Tables

#### 1. `network_devices`
**Purpose:** Track UniFi infrastructure (APs, switches, gateway)

```ruby
create_table "network_devices" do |t|
  t.string "name", null: false              # "U7-Pro New"
  t.string "device_type", null: false       # "uap", "usw", "udm"
  t.string "model"                          # "U7PRO"
  t.string "mac", null: false               # "9c:05:d6:50:df:f0"
  t.string "ip"                             # "192.168.4.134"
  t.string "firmware_version"               # "8.4.6.18068"
  t.string "state"                          # "online", "offline"
  t.integer "uptime"                        # seconds
  t.datetime "last_seen_at"
  t.jsonb "raw_data", default: {}, null: false
  t.timestamps
  
  t.index ["mac"], unique: true
  t.index ["device_type"]
  t.index ["state"]
  t.index ["last_seen_at"]
end
```

---

#### 2. `network_clients`
**Purpose:** Track connected devices (like HomeKit accessories but for network)

```ruby
create_table "network_clients" do |t|
  t.string "hostname"                      # "iPad", "g4-instant"
  t.string "mac", null: false              # "1a:2d:69:35:7d:d7"
  t.string "ip"                            # "192.168.4.236"
  t.boolean "is_wired", default: false
  t.string "network"                       # "Default", "Camera Network"
  t.string "essid"                         # "TOTALLY_NOT_HAUNTED"
  t.bigint "rx_bytes", default: 0
  t.bigint "tx_bytes", default: 0
  t.datetime "first_seen_at"
  t.datetime "last_seen_at"
  t.jsonb "raw_data", default: {}, null: false
  t.timestamps
  
  t.index ["mac"], unique: true
  t.index ["is_wired"]
  t.index ["network"]
  t.index ["last_seen_at"]
end
```

---

#### 3. `network_events`
**Purpose:** IPS alerts, firewall blocks, config changes (like `homekit_events`)

```ruby
create_table "network_events" do |t|
  t.string "event_type", null: false       # "ips_alert", "firewall_block", "config_change"
  t.string "severity"                      # "critical", "high", "medium", "low"
  t.string "category"                      # "botcc", "emerging-malware", etc.
  t.string "source_ip"
  t.string "destination_ip"
  t.bigint "network_client_id"             # FK to client (optional)
  t.text "message"
  t.jsonb "raw_payload", default: {}
  t.datetime "occurred_at"
  t.timestamps
  
  t.index ["event_type"]
  t.index ["severity"]
  t.index ["category"]
  t.index ["occurred_at"]
  t.index ["network_client_id"]
end
```

---

#### 4. `network_health_snapshots`
**Purpose:** Daily health summary (like daily sensor summaries)

```ruby
create_table "network_health_snapshots" do |t|
  t.date "snapshot_date", null: false
  t.integer "devices_online"
  t.integer "devices_total"
  t.integer "clients_connected"
  t.integer "ips_alerts_count"
  t.integer "firewall_blocks_count"
  t.bigint "total_bandwidth"              # bytes
  t.string "firmware_status"              # "up_to_date", "updates_available"
  t.datetime "latest_backup_at"
  t.jsonb "details", default: {}          # Full snapshot data
  t.timestamps
  
  t.index ["snapshot_date"], unique: true
end
```

---

#### 5. `network_alerts`
**Purpose:** Notifications/alerts that need attention (like HomeKit notifications)

```ruby
create_table "network_alerts" do |t|
  t.string "alert_type", null: false       # "device_offline", "firmware_update", "ips_critical"
  t.string "severity", null: false         # "critical", "warning", "info"
  t.string "title"
  t.text "message"
  t.string "entity_type"                   # "NetworkDevice", "NetworkClient"
  t.bigint "entity_id"
  t.datetime "acknowledged_at"
  t.jsonb "metadata", default: {}
  t.timestamps
  
  t.index ["alert_type"]
  t.index ["severity"]
  t.index ["acknowledged_at"]
  t.index ["entity_type", "entity_id"]
end
```

---

## Service Architecture

### 1. `UnifiSyncService`
**Purpose:** Core sync service (like `HomekitSync`)

```ruby
class UnifiSyncService
  def initialize(credentials: nil)
    @client = Unifi::Client.new(credentials)
  end

  def perform
    sync_devices
    sync_clients
    sync_recent_events
    generate_alerts
  end

  private

  def sync_devices
    devices = @client.get_devices
    devices.each do |device_data|
      device = NetworkDevice.find_or_initialize_by(mac: device_data['mac'])
      device.update!(
        name: device_data['name'],
        device_type: device_data['type'],
        model: device_data['model'],
        ip: device_data['ip'],
        firmware_version: device_data['version'],
        state: device_data['state'] == 1 ? 'online' : 'offline',
        uptime: device_data['uptime'],
        last_seen_at: Time.current,
        raw_data: device_data
      )
    end
  end

  def sync_clients
    # Similar to sync_devices
  end

  def sync_recent_events
    # Fetch IPS alerts from last sync
    # Create NetworkEvent records
  end

  def generate_alerts
    # Check for critical conditions
    # Create NetworkAlert records
  end
end
```

---

### 2. `UnifiHealthService`
**Purpose:** Daily health check and snapshot

```ruby
class UnifiHealthService
  def perform
    snapshot = NetworkHealthSnapshot.find_or_create_by(snapshot_date: Date.current)
    
    snapshot.update!(
      devices_online: NetworkDevice.where(state: 'online').count,
      devices_total: NetworkDevice.count,
      clients_connected: NetworkClient.where('last_seen_at > ?', 5.minutes.ago).count,
      ips_alerts_count: NetworkEvent.where(event_type: 'ips_alert').where('created_at > ?', 1.day.ago).count,
      total_bandwidth: NetworkClient.sum(:rx_bytes) + NetworkClient.sum(:tx_bytes),
      firmware_status: check_firmware_status,
      details: collect_details
    )
    
    # Send daily report
    send_health_report(snapshot)
  end
end
```

---

### 3. `UnifiAlertService`
**Purpose:** Process events and create alerts

```ruby
class UnifiAlertService
  ALERT_RULES = {
    device_offline: ->(device) { device.state == 'offline' && device.device_type != 'ugw' },
    firmware_update: ->(device) { device.firmware_update_available? },
    critical_ips_alert: ->(event) { event.severity == 'critical' && event.event_type == 'ips_alert' },
    high_bandwidth: ->(client) { client.bandwidth_24h > 10.gigabytes }
  }.freeze

  def process_events
    check_device_status
    check_ips_alerts
    check_bandwidth_anomalies
  end
end
```

---

## Jobs & Scheduling

### 1. `UnifiSyncJob`
**Schedule:** Every 5 minutes (Solid Queue)

```ruby
class UnifiSyncJob < ApplicationJob
  queue_as :default

  def perform
    UnifiSyncService.new.perform
  end
end
```

**Configuration:**
```ruby
# config/initializers/solid_queue.rb
config.recurring_tasks = [
  { class: 'UnifiSyncJob', schedule: 'every 5 minutes' }
]
```

---

### 2. `UnifiHealthJob`
**Schedule:** Daily at 8 AM

```ruby
class UnifiHealthJob < ApplicationJob
  queue_as :default

  def perform
    UnifiHealthService.new.perform
  end
end
```

---

## UI Components

### Dashboard View

```ruby
# app/views/network/dashboard.html.erb
<div class="container">
  <h1>Network Health</h1>
  
  <%= render Network::HealthDashboardComponent.new(
    snapshot: @health_snapshot
  ) %>
  
  <div class="grid grid-cols-2 gap-4">
    <%= render Network::DeviceStatusComponent.new(
      devices: @devices
    ) %>
    
    <%= render Network::ClientListComponent.new(
      clients: @clients.limit(20)
    ) %>
  </div>
  
  <%= render Network::IpsAlertsComponent.new(
    events: @recent_ips_alerts
  ) %>
</div>
```

---

### Real-Time Updates (ActionCable)

```ruby
# app/channels/network_channel.rb
class NetworkChannel < ApplicationCable::Channel
  def subscribed
    stream_from "network_updates"
  end
end
```

**Broadcast from sync:**
```ruby
# In UnifiSyncService
ActionCable.server.broadcast("network_updates", {
  type: "device_status",
  device: device.as_json
})
```

---

## API Wrapper

### Local UniFi API Client

```ruby
# lib/unifi/client.rb
module Unifi
  class Client
    def initialize(credentials = nil)
      @credentials = credentials || load_credentials
      @base_uri = "https://#{@credentials[:host]}:#{@credentials[:port]}"
      @cookies = nil
    end

    def get_devices
      authenticate! unless @cookies
      get("/proxy/network/api/s/default/stat/device")
    end

    def get_clients
      authenticate! unless @cookies
      get("/proxy/network/api/s/default/stat/sta")
    end

    def get_ips_alerts(since: 1.hour.ago)
      authenticate! unless @cookies
      events = get("/proxy/network/api/s/default/stat/event", {
        start: (since.to_i * 1000),
        end: (Time.current.to_i * 1000)
      })
      events.select { |e| e['key'] =~ /EVT_IPS/ }
    end

    private

    def authenticate!
      # Login logic (from unifi-network-inventory.rb)
    end

    def get(path, params = {})
      # HTTP GET with cookies
    end

    def load_credentials
      # From Rails credentials
      Rails.application.credentials.unifi
    end
  end
end
```

---

### Cloud API Client

```ruby
# lib/unifi/cloud_client.rb
module Unifi
  class CloudClient
    def initialize(api_key = nil)
      @api_key = api_key || Rails.application.credentials.unifi[:cloud_api_key]
      @base_uri = "https://api.ui.com"
    end

    def get_hosts
      get("/ea/hosts")
    end

    def get_firmware_updates
      hosts = get_hosts
      hosts.select { |h| h.dig('reportedState', 'deviceState') == 'updateAvailable' }
    end

    def get_internet_issues(since: 24.hours.ago)
      hosts = get_hosts
      hosts.flat_map { |h| h.dig('reportedState', 'internetIssues5min', 'periods') || [] }
    end

    private

    def get(path)
      # HTTP GET with X-API-KEY header
    end
  end
end
```

---

## Credentials Management

### Encrypted Credentials

```bash
# Store credentials securely
EDITOR="code --wait" rails credentials:edit
```

```yaml
# config/credentials.yml.enc
unifi:
  host: "192.168.4.1"
  port: 443
  username: <%= ENV['UNIFI_ADMIN_USER'] %>  # Read-only user recommended
  password: <%= ENV['UNIFI_ADMIN_PASS'] %>
  cloud_api_key: "hY04GiUsCZGpNAtedBMp6ZzaFZ0Pm_1T"
```

**Access in code:**
```ruby
Rails.application.credentials.unifi[:cloud_api_key]
```

---

## Migration Plan

### Phase 1: Foundation (Week 1)

**Tasks:**
1. Create migrations for 5 new tables
2. Create models with associations and validations
3. Build `Unifi::Client` wrapper (port from Ruby scripts)
4. Create `UnifiSyncService`
5. Add Solid Queue jobs

**Deliverable:** Sync working, data flowing into database

---

### Phase 2: Basic UI (Week 2)

**Tasks:**
1. Create `/network` route and controller
2. Build ViewComponents for device status, client list
3. Create health dashboard view
4. Add navigation link to sidebar

**Deliverable:** Basic dashboard showing devices and clients

---

### Phase 3: Real-Time Updates (Week 3)

**Tasks:**
1. Create `NetworkChannel` for ActionCable
2. Broadcast updates from sync service
3. Add Stimulus controllers for auto-refresh
4. Show live device status changes

**Deliverable:** Real-time network status updates

---

### Phase 4: Alerts & Notifications (Week 4)

**Tasks:**
1. Build `UnifiAlertService` with alert rules
2. Create alert UI components
3. Add notification system (Slack/email)
4. Implement alert acknowledgment

**Deliverable:** Automated alerting for critical events

---

### Phase 5: Analytics & Reporting (Week 5)

**Tasks:**
1. Build `UnifiHealthService` for daily snapshots
2. Create health trend charts (using existing Chart.js)
3. Add IPS alert analytics
4. Generate weekly/monthly reports

**Deliverable:** Historical trends and reports

---

## Integration Benefits

### Reuse Existing Infrastructure

| Feature | Current Use | Network Use |
|---------|-------------|-------------|
| **PostgreSQL** | HomeKit events | Network events, snapshots |
| **Solid Queue** | Background jobs | UniFi sync jobs |
| **ActionCable** | Real-time sensor updates | Real-time device status |
| **ViewComponents** | Device controls | Network dashboards |
| **Stimulus** | Interactive controls | Network charts, filters |
| **Tailwind CSS** | HomeKit UI | Network UI (consistent styling) |
| **JSONB `raw_data`** | Accessory data | Device/client data |

---

### Unified Experience

**Single Dashboard:**
- HomeKit devices + Network devices side-by-side
- Correlate device issues (e.g., "Camera offline" → check network)
- Unified search across all entities
- Single authentication/authorization

**Example Correlation:**
```
Network Alert: "g4-instant offline"
  → Check NetworkClient (last_seen: 10 minutes ago)
  → Check Accessory with same name
  → Alert: "Camera may have network issue"
```

---

## Testing Strategy

### Model Tests

```ruby
# spec/models/network_device_spec.rb
RSpec.describe NetworkDevice, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:mac) }
    it { should validate_uniqueness_of(:mac) }
  end

  describe 'scopes' do
    it 'returns only online devices' do
      online = create(:network_device, state: 'online')
      offline = create(:network_device, state: 'offline')
      expect(NetworkDevice.online).to include(online)
      expect(NetworkDevice.online).not_to include(offline)
    end
  end
end
```

### Service Tests

```ruby
# spec/services/unifi_sync_service_spec.rb
RSpec.describe UnifiSyncService do
  describe '#perform' do
    it 'syncs devices from UniFi API' do
      stub_unifi_api_devices
      expect { described_class.new.perform }.to change(NetworkDevice, :count).by(14)
    end
  end
end
```

---

## Performance Considerations

### Database Indexes

All critical indexes included in schema (MAC addresses, timestamps, foreign keys)

### Caching Strategy

```ruby
# Cache device list for 1 minute
@devices = Rails.cache.fetch("network_devices", expires_in: 1.minute) do
  NetworkDevice.online.order(:name)
end
```

### Query Optimization

```ruby
# Avoid N+1 queries
@clients = NetworkClient
  .includes(:network_events)
  .where('last_seen_at > ?', 1.hour.ago)
  .limit(100)
```

---

## Monitoring & Observability

### Health Checks

```ruby
# Add to existing health check endpoint
def network_health
  {
    unifi_sync: UnifiSyncJob.last_run_at > 10.minutes.ago,
    devices_online: NetworkDevice.online.count,
    last_sync: UnifiSyncJob.last_run_at
  }
end
```

### Metrics to Track

- Sync job duration
- API call latency
- Database query performance
- Alert generation rate
- Dashboard load time

---

## Security Considerations

1. **Read-Only API Access**: Use dedicated read-only UniFi user
2. **Encrypted Credentials**: Store in Rails credentials, not ENV
3. **Rate Limiting**: Limit API calls to avoid overwhelming controller
4. **Access Control**: Reuse existing authentication system
5. **Audit Log**: Track who viewed network data

---

## Cost Analysis

### Development Time

| Phase | Effort | Duration |
|-------|--------|----------|
| Phase 1: Foundation | 20-24 hours | Week 1 |
| Phase 2: Basic UI | 12-16 hours | Week 2 |
| Phase 3: Real-Time | 8-12 hours | Week 3 |
| Phase 4: Alerts | 12-16 hours | Week 4 |
| Phase 5: Analytics | 16-20 hours | Week 5 |
| **Total** | **68-88 hours** | **5 weeks** |

### Infrastructure Cost

- **$0** - Runs on existing Rails app and database
- **$0** - Uses existing Solid Queue
- **$0** - Uses existing ActionCable
- **Storage:** +~500 MB for 90 days of network data

---

## Advantages Over Standalone Monitoring

| Aspect | Standalone (Original Plan) | Integrated (This Plan) |
|--------|---------------------------|------------------------|
| **Setup Complexity** | High (new stack: InfluxDB, Grafana, Loki) | Low (reuse existing Rails) |
| **Data Correlation** | Manual (separate systems) | Automatic (same database) |
| **UI Consistency** | Different UIs | Unified UI |
| **Authentication** | Separate auth | Single sign-on |
| **Deployment** | Multiple services | One Rails app |
| **Maintenance** | Multiple systems | One codebase |
| **Learning Curve** | Learn new tools | Use existing skills |

---

## Next Steps

1. **Review & Approve** - Confirm this approach vs. standalone
2. **Create Epic** - `knowledge_base/epics/Epic-8-Network-Monitoring/`
3. **Break Down PRDs** - 5 PRDs (one per phase)
4. **Start Phase 1** - Create migrations and models
5. **Iterate** - Build incrementally, test each phase

---

## Related Documentation

- [Firewall Security Review](../assessments/firewall-security-review-2026-02-18.md)
- [Firewall Monitoring Roadmap](../roadmaps/roadmap-firewall-monitoring.md)
- [Network Inventory](../network-inventory/network-inventory-2026-02-18.md)
- [Eureka-HomeKit Epic 5 Architecture](../../../eureka-homekit/knowledge_base/epics/Epic-5-Interactive-Controls/)

---

**Document Status:** Ready for Review  
**Next Step:** Approval to begin Phase 1  
**Owner:** Eric Smith + AiderDesk
