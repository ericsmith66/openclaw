# Plan: UniFi Monitoring API Integration into Eureka-HomeKit
**Created:** February 19, 2026  
**Status:** READY FOR IMPLEMENTATION  
**Priority:** HIGH  
**Related Docs:**
- [UniFi API Data Catalog](../reference/unifi-api-data-catalog.md)
- [UniFi API Write Capabilities](../reference/unifi-api-write-capabilities.md)
- [UniFi Ruby Clients](../reference/unifi-ruby-clients.md)
- [Firewall Monitoring Roadmap](../roadmaps/roadmap-firewall-monitoring.md)

---

## Executive Summary

**Goal:** Add UniFi network monitoring API to eureka-homekit for unified home intelligence.

**Scope:**
1. **Phase 1A:** Read-only monitoring API (devices, clients, health)
2. **Phase 1B:** Syslog server setup for UDM-SE real-time events
3. **Phase 2:** Dashboard UI integration (future)
4. **Phase 3:** Control operations (future)

**Why Eureka-HomeKit:**
- ✅ Already has PostgreSQL with event storage patterns
- ✅ Already has real-time event processing (homekit_events)
- ✅ Already has API endpoints (`/api/homekit/events`)
- ✅ Runs on same network as UDM-SE
- ✅ Production-ready Rails app with ActionCable
- ✅ Proven architecture for similar data patterns

---

## Phase 1A: Monitoring API (Week 1)

### Objectives
1. Create RESTful API for UniFi device/client/event data
2. Poll UniFi controller every 5 minutes for status updates
3. Store network state in PostgreSQL
4. Expose API endpoints for consumption by other apps

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Eureka-HomeKit Rails App                  │
├─────────────────────────────────────────────────────────────┤
│  API Endpoints                                               │
│  ├── GET /api/network/devices      # List all devices       │
│  ├── GET /api/network/clients      # List connected clients │
│  ├── GET /api/network/health       # System health          │
│  ├── GET /api/network/events       # IPS/firewall events    │
│  └── GET /api/network/alerts       # Active alerts          │
├─────────────────────────────────────────────────────────────┤
│  Background Jobs (Solid Queue)                               │
│  ├── UnifiSyncJob (every 5 min)    # Sync devices/clients   │
│  └── UnifiHealthCheckJob (daily)   # Daily health snapshot  │
├─────────────────────────────────────────────────────────────┤
│  Services                                                    │
│  ├── UnifiClient                   # API wrapper            │
│  ├── UnifiSyncService              # Data sync logic        │
│  └── UnifiAlertService             # Alert processing       │
├─────────────────────────────────────────────────────────────┤
│  Models                                                      │
│  ├── NetworkDevice                 # APs, switches, gateway │
│  ├── NetworkClient                 # Connected devices      │
│  ├── NetworkEvent                  # IPS alerts, logs       │
│  ├── NetworkHealthSnapshot         # Daily summaries        │
│  └── NetworkAlert                  # Active alerts          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
                 ┌─────────────────────┐
                 │   UDM-SE at         │
                 │   192.168.4.1       │
                 │   Local API (HTTPS) │
                 └─────────────────────┘
```

### Database Schema

#### 1. NetworkDevice Model

```ruby
# app/models/network_device.rb
class NetworkDevice < ApplicationRecord
  # Associations
  has_many :network_clients, foreign_key: 'connected_to_device_id'
  has_many :network_events
  
  # Enums
  enum :device_type, {
    access_point: 'uap',
    switch: 'usw',
    gateway: 'udm',
    pdu: 'usp'
  }
  
  enum :state, {
    online: 'online',
    offline: 'offline',
    upgrading: 'upgrading',
    provisioning: 'provisioning'
  }
  
  # Scopes
  scope :online, -> { where(state: 'online') }
  scope :offline, -> { where(state: 'offline') }
  scope :upgradable, -> { where(upgradable: true) }
  
  # Validations
  validates :name, presence: true
  validates :mac, presence: true, uniqueness: true
  validates :device_type, presence: true
  
  # Methods
  def online?
    state == 'online'
  end
  
  def uptime_humanized
    return 'N/A' unless uptime
    distance_of_time_in_words(uptime)
  end
  
  def needs_update?
    upgradable == true
  end
end
```

**Migration:**
```ruby
# db/migrate/20260219_create_network_devices.rb
class CreateNetworkDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :network_devices do |t|
      t.string :name, null: false
      t.string :device_type, null: false
      t.string :model
      t.string :mac, null: false
      t.string :ip
      t.string :firmware_version
      t.string :state, default: 'offline'
      t.integer :uptime
      t.boolean :upgradable, default: false
      t.string :upgrade_to_version
      t.datetime :last_seen_at
      t.jsonb :raw_data, default: {}, null: false
      t.jsonb :sys_stats, default: {}  # CPU, memory, temps
      t.timestamps
      
      t.index :mac, unique: true
      t.index :device_type
      t.index :state
      t.index :last_seen_at
    end
  end
end
```

#### 2. NetworkClient Model

```ruby
# app/models/network_client.rb
class NetworkClient < ApplicationRecord
  belongs_to :network_device, foreign_key: 'connected_to_device_id', optional: true
  has_many :network_events
  
  enum :network_type, {
    wired: 'wired',
    wireless: 'wireless'
  }
  
  scope :online, -> { where('last_seen_at > ?', 5.minutes.ago) }
  scope :wired, -> { where(is_wired: true) }
  scope :wireless, -> { where(is_wired: false) }
  scope :by_network, ->(network_name) { where(network: network_name) }
  
  validates :mac, presence: true, uniqueness: true
  
  def online?
    last_seen_at && last_seen_at > 5.minutes.ago
  end
  
  def total_bandwidth
    rx_bytes + tx_bytes
  end
  
  def connection_type
    is_wired ? 'Wired' : "WiFi (#{essid})"
  end
end
```

**Migration:**
```ruby
# db/migrate/20260219_create_network_clients.rb
class CreateNetworkClients < ActiveRecord::Migration[8.1]
  def change
    create_table :network_clients do |t|
      t.string :hostname
      t.string :mac, null: false
      t.string :ip
      t.string :oui  # Manufacturer
      t.boolean :is_wired, default: false
      t.boolean :is_guest, default: false
      t.string :network
      t.string :network_id
      t.string :essid
      t.bigint :rx_bytes, default: 0
      t.bigint :tx_bytes, default: 0
      t.integer :signal_strength  # RSSI for wireless
      t.bigint :connected_to_device_id  # FK to network_devices
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.jsonb :raw_data, default: {}, null: false
      t.timestamps
      
      t.index :mac, unique: true
      t.index :is_wired
      t.index :network
      t.index :last_seen_at
      t.index :connected_to_device_id
    end
    
    add_foreign_key :network_clients, :network_devices, column: :connected_to_device_id
  end
end
```

#### 3. NetworkEvent Model

```ruby
# app/models/network_event.rb
class NetworkEvent < ApplicationRecord
  belongs_to :network_client, optional: true
  belongs_to :network_device, optional: true
  
  enum :event_type, {
    ips_alert: 'ips_alert',
    firewall_block: 'firewall_block',
    device_offline: 'device_offline',
    device_online: 'device_online',
    config_change: 'config_change',
    firmware_update: 'firmware_update',
    client_connected: 'client_connected',
    client_disconnected: 'client_disconnected'
  }
  
  enum :severity, {
    critical: 'critical',
    high: 'high',
    medium: 'medium',
    low: 'low',
    info: 'info'
  }
  
  scope :critical, -> { where(severity: 'critical') }
  scope :recent, -> { order(occurred_at: :desc).limit(100) }
  scope :today, -> { where('occurred_at > ?', Date.current.beginning_of_day) }
  scope :by_type, ->(type) { where(event_type: type) }
  
  validates :event_type, presence: true
  validates :occurred_at, presence: true
end
```

**Migration:**
```ruby
# db/migrate/20260219_create_network_events.rb
class CreateNetworkEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :network_events do |t|
      t.string :event_type, null: false
      t.string :severity, default: 'info'
      t.string :category
      t.string :source_ip
      t.string :destination_ip
      t.integer :source_port
      t.integer :dest_port
      t.bigint :network_client_id
      t.bigint :network_device_id
      t.text :message
      t.boolean :blocked, default: false
      t.jsonb :raw_payload, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
      
      t.index :event_type
      t.index :severity
      t.index :category
      t.index :occurred_at
      t.index :network_client_id
      t.index :network_device_id
      t.index [:event_type, :occurred_at]
    end
    
    add_foreign_key :network_events, :network_clients
    add_foreign_key :network_events, :network_devices
  end
end
```

#### 4. NetworkHealthSnapshot Model

```ruby
# app/models/network_health_snapshot.rb
class NetworkHealthSnapshot < ApplicationRecord
  validates :snapshot_date, presence: true, uniqueness: true
  
  scope :recent, -> { order(snapshot_date: :desc).limit(30) }
  
  def health_score
    return 0 if devices_total.zero?
    (devices_online.to_f / devices_total * 100).round
  end
  
  def critical_alerts?
    ips_alerts_count > 0 || firewall_blocks_count > 10
  end
end
```

**Migration:**
```ruby
# db/migrate/20260219_create_network_health_snapshots.rb
class CreateNetworkHealthSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :network_health_snapshots do |t|
      t.date :snapshot_date, null: false
      t.integer :devices_online, default: 0
      t.integer :devices_total, default: 0
      t.integer :clients_connected, default: 0
      t.integer :ips_alerts_count, default: 0
      t.integer :firewall_blocks_count, default: 0
      t.bigint :total_bandwidth, default: 0
      t.string :firmware_status
      t.datetime :latest_backup_at
      t.jsonb :details, default: {}
      t.timestamps
      
      t.index :snapshot_date, unique: true
    end
  end
end
```

### UniFi Client Service

```ruby
# lib/unifi/client.rb
module Unifi
  class Client
    include HTTParty
    base_uri ENV.fetch('UNIFI_HOST', 'https://192.168.4.1')
    headers 'Accept' => 'application/json'
    default_options.update(verify: false)  # Self-signed cert
    
    class AuthenticationError < StandardError; end
    class APIError < StandardError; end
    
    def initialize
      @site = ENV.fetch('UNIFI_SITE', 'default')
      @cookies = login
      raise AuthenticationError, 'Failed to authenticate' unless @cookies
    end
    
    # Authentication
    def login
      response = self.class.post('/api/auth/login',
        body: {
          username: ENV.fetch('UNIFI_USERNAME'),
          password: ENV.fetch('UNIFI_PASSWORD'),
          remember: true
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
      response.headers['set-cookie'] if response.success?
    end
    
    # Read Operations
    def system_info
      get('/proxy/network/api/s/default/stat/sysinfo')
    end
    
    def devices
      get('/proxy/network/api/s/default/stat/device')
    end
    
    def clients
      get('/proxy/network/api/s/default/stat/sta')
    end
    
    def site_health
      get('/proxy/network/api/s/default/stat/health')
    end
    
    def events(limit: 100)
      get('/proxy/network/api/s/default/stat/event', query: { _limit: limit })
    end
    
    def ips_alerts
      events = get('/proxy/network/api/s/default/stat/event')
      events.select { |e| e['key'] == 'EVT_IPS_ALERT' }
    end
    
    private
    
    def get(path, query: {})
      response = self.class.get(path,
        cookies: @cookies,
        query: query
      )
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("UniFi API Error: #{e.message}")
      raise APIError, e.message
    end
    
    def parse_response(response)
      return [] unless response.success?
      
      data = JSON.parse(response.body)
      if data['meta'] && data['meta']['rc'] == 'ok'
        data['data'] || []
      else
        raise APIError, "API returned error: #{data['meta']['msg']}"
      end
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON response: #{e.message}"
    end
  end
end
```

### Sync Service

```ruby
# app/services/unifi_sync_service.rb
class UnifiSyncService
  def initialize
    @client = Unifi::Client.new
  end
  
  def sync_all
    sync_devices
    sync_clients
    sync_events
    sync_health
  rescue Unifi::Client::AuthenticationError => e
    Rails.logger.error("UniFi authentication failed: #{e.message}")
    raise
  rescue Unifi::Client::APIError => e
    Rails.logger.error("UniFi API error: #{e.message}")
    # Don't raise - allow next sync attempt
  end
  
  def sync_devices
    devices_data = @client.devices
    
    devices_data.each do |device_data|
      device = NetworkDevice.find_or_initialize_by(mac: device_data['mac'])
      device.update!(
        name: device_data['name'],
        device_type: device_data['type'],
        model: device_data['model'],
        ip: device_data['ip'],
        firmware_version: device_data['version'],
        state: device_data['state'] == 1 ? 'online' : 'offline',
        uptime: device_data['uptime'],
        upgradable: device_data['upgradable'] || false,
        upgrade_to_version: device_data['upgrade_to_firmware'],
        last_seen_at: Time.at(device_data['last_seen']),
        sys_stats: device_data['sys_stats'] || {},
        raw_data: device_data
      )
    end
    
    Rails.logger.info("Synced #{devices_data.count} devices")
  end
  
  def sync_clients
    clients_data = @client.clients
    
    clients_data.each do |client_data|
      client = NetworkClient.find_or_initialize_by(mac: client_data['mac'])
      
      # Find connected device
      connected_device = nil
      if client_data['last_uplink_mac']
        connected_device = NetworkDevice.find_by(mac: client_data['last_uplink_mac'])
      end
      
      client.update!(
        hostname: client_data['hostname'],
        ip: client_data['ip'],
        oui: client_data['oui'],
        is_wired: client_data['is_wired'] || false,
        is_guest: client_data['is_guest'] || false,
        network: client_data['network'],
        network_id: client_data['network_id'],
        essid: client_data['essid'],
        rx_bytes: client_data['rx_bytes'] || 0,
        tx_bytes: client_data['tx_bytes'] || 0,
        signal_strength: client_data['rssi'],
        connected_to_device_id: connected_device&.id,
        first_seen_at: client.first_seen_at || Time.at(client_data['first_seen']),
        last_seen_at: Time.at(client_data['last_seen']),
        raw_data: client_data
      )
    end
    
    Rails.logger.info("Synced #{clients_data.count} clients")
  end
  
  def sync_events
    # Only get recent events (last 5 minutes)
    events_data = @client.events(limit: 500)
    cutoff_time = 5.minutes.ago
    
    events_data.select { |e| Time.at(e['time'] / 1000) > cutoff_time }.each do |event_data|
      next if NetworkEvent.exists?(
        event_type: map_event_type(event_data['key']),
        occurred_at: Time.at(event_data['time'] / 1000)
      )
      
      NetworkEvent.create!(
        event_type: map_event_type(event_data['key']),
        severity: map_severity(event_data),
        category: event_data['category'],
        source_ip: event_data['src_ip'],
        destination_ip: event_data['dst_ip'],
        source_port: event_data['src_port'],
        dest_port: event_data['dst_port'],
        message: event_data['msg'],
        blocked: event_data['blocked'] || false,
        occurred_at: Time.at(event_data['time'] / 1000),
        raw_payload: event_data
      )
    end
  end
  
  def sync_health
    health_data = @client.site_health
    
    snapshot = NetworkHealthSnapshot.find_or_create_by(
      snapshot_date: Date.current
    )
    
    snapshot.update!(
      devices_online: NetworkDevice.online.count,
      devices_total: NetworkDevice.count,
      clients_connected: NetworkClient.online.count,
      ips_alerts_count: NetworkEvent.where(event_type: 'ips_alert').today.count,
      firewall_blocks_count: NetworkEvent.where(event_type: 'firewall_block').today.count,
      total_bandwidth: NetworkClient.sum(:rx_bytes) + NetworkClient.sum(:tx_bytes),
      details: health_data
    )
  end
  
  private
  
  def map_event_type(key)
    case key
    when 'EVT_IPS_ALERT'
      'ips_alert'
    when 'EVT_AP_DISCONNECTED', 'EVT_SW_DISCONNECTED'
      'device_offline'
    when 'EVT_AP_CONNECTED', 'EVT_SW_CONNECTED'
      'device_online'
    when 'EVT_LU_Connected'
      'client_connected'
    when 'EVT_LU_Disconnected'
      'client_disconnected'
    else
      'info'
    end
  end
  
  def map_severity(event_data)
    return 'critical' if event_data['key'] == 'EVT_IPS_ALERT' && event_data['blocked']
    return 'high' if event_data['key'] == 'EVT_IPS_ALERT'
    return 'medium' if event_data['key']&.include?('DISCONNECTED')
    'info'
  end
end
```

### Background Jobs

```ruby
# app/jobs/unifi_sync_job.rb
class UnifiSyncJob < ApplicationJob
  queue_as :default
  
  def perform
    UnifiSyncService.new.sync_all
  rescue StandardError => e
    Rails.logger.error("UniFi sync failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Optionally send alert
  end
end
```

**Schedule in config/recurring.yml (Solid Queue):**
```yaml
# config/recurring.yml
production:
  unifi_sync:
    class: UnifiSyncJob
    schedule: every 5 minutes
    
  unifi_health_check:
    class: UnifiHealthCheckJob
    schedule: every day at 2am
```

### API Controllers

```ruby
# app/controllers/api/network_controller.rb
module Api
  class NetworkController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_api_key
    
    def devices
      devices = NetworkDevice.all.order(:name)
      render json: {
        devices: devices.as_json(
          only: [:id, :name, :device_type, :model, :mac, :ip, 
                 :firmware_version, :state, :uptime, :upgradable],
          methods: [:online?, :needs_update?]
        ),
        meta: {
          total: devices.count,
          online: devices.online.count,
          offline: devices.offline.count
        }
      }
    end
    
    def clients
      clients = NetworkClient.all.order(last_seen_at: :desc)
      
      render json: {
        clients: clients.as_json(
          only: [:id, :hostname, :mac, :ip, :is_wired, :network, 
                 :essid, :last_seen_at],
          methods: [:online?, :total_bandwidth, :connection_type]
        ),
        meta: {
          total: clients.count,
          online: clients.online.count,
          wired: clients.wired.count,
          wireless: clients.wireless.count
        }
      }
    end
    
    def health
      snapshot = NetworkHealthSnapshot.order(snapshot_date: :desc).first
      
      render json: {
        health: snapshot,
        devices: {
          online: NetworkDevice.online.count,
          offline: NetworkDevice.offline.count,
          upgradable: NetworkDevice.upgradable.count
        },
        clients: {
          connected: NetworkClient.online.count
        },
        events: {
          critical_today: NetworkEvent.critical.today.count,
          total_today: NetworkEvent.today.count
        }
      }
    end
    
    def events
      events = NetworkEvent.recent
      
      if params[:type]
        events = events.by_type(params[:type])
      end
      
      if params[:severity]
        events = events.where(severity: params[:severity])
      end
      
      render json: {
        events: events.as_json(
          only: [:id, :event_type, :severity, :category, :source_ip, 
                 :destination_ip, :message, :occurred_at]
        ),
        meta: {
          total: events.count,
          page: params[:page] || 1
        }
      }
    end
    
    private
    
    def authenticate_api_key
      api_key = request.headers['X-API-Key']
      unless api_key == ENV['EUREKA_API_KEY']
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end
  end
end
```

**Routes:**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    # Existing HomeKit endpoints
    post "homekit/events", to: "homekit_events#create"
    resources :floorplans, only: [:show]
    
    # NEW: Network monitoring endpoints
    get "network/devices", to: "network#devices"
    get "network/clients", to: "network#clients"
    get "network/health", to: "network#health"
    get "network/events", to: "network#events"
  end
end
```

### Environment Variables

```bash
# Add to .env
UNIFI_HOST=https://192.168.4.1
UNIFI_SITE=default
UNIFI_USERNAME=readonly_monitoring
UNIFI_PASSWORD=secure_password_here
EUREKA_API_KEY=generate_random_key_here
```

---

## Phase 1B: Syslog Setup for Real-Time Events (Week 1)

### Why Syslog?

**Polling Limitations:**
- 5-minute delay for events
- Higher API load
- Can miss rapid events

**Syslog Benefits:**
- Real-time event delivery (< 1 second)
- No polling overhead
- Standard protocol (514/UDP or 514/TCP)
- UDM-SE native support

### Architecture

```
┌─────────────────┐
│    UDM-SE       │
│  192.168.4.1    │
│                 │
│  Generates logs │
└────────┬────────┘
         │ UDP/TCP 514
         ▼
┌─────────────────┐
│  Syslog Server  │
│  (rsyslog)      │
│  192.168.4.253  │
│                 │
│  Filters logs   │
└────────┬────────┘
         │ Writes to
         ▼
┌─────────────────┐
│  /var/log/      │
│  unifi/         │
│  ├─ ips.log     │
│  ├─ firewall.log│
│  └─ system.log  │
└────────┬────────┘
         │ Tails logs
         ▼
┌─────────────────────────────────┐
│  Eureka-HomeKit Background Job  │
│  (UnifiSyslogMonitorJob)        │
│                                 │
│  Parses & stores to DB          │
└─────────────────────────────────┘
```

### Step 1: Configure rsyslog on Production Server

**Install rsyslog (if not present):**
```bash
# On macOS (production server at 192.168.4.253)
brew install rsyslog
```

**Create rsyslog configuration:**
```bash
# /usr/local/etc/rsyslog.conf
# Accept logs on UDP 514
module(load="imudp")
input(type="imudp" port="514")

# Accept logs on TCP 514 (more reliable)
module(load="imtcp")
input(type="imtcp" port="514")

# Template for UniFi logs
template(name="UnifiLogFormat" type="string"
  string="%timestamp% %hostname% %msg%\n")

# Filter IPS alerts
if $programname == 'EVT_IPS_ALERT' then {
  action(type="omfile" file="/var/log/unifi/ips.log" template="UnifiLogFormat")
  stop
}

# Filter firewall events
if $programname contains 'firewall' then {
  action(type="omfile" file="/var/log/unifi/firewall.log" template="UnifiLogFormat")
  stop
}

# All other UniFi logs
if $fromhost-ip == '192.168.4.1' then {
  action(type="omfile" file="/var/log/unifi/system.log" template="UnifiLogFormat")
  stop
}
```

**Create log directory:**
```bash
sudo mkdir -p /var/log/unifi
sudo chown $(whoami):staff /var/log/unifi
```

**Start rsyslog:**
```bash
# On macOS, create LaunchAgent
cat << 'EOF' > ~/Library/LaunchAgents/homebrew.mxcl.rsyslog.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>homebrew.mxcl.rsyslog</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/sbin/rsyslogd</string>
    <string>-n</string>
    <string>-f</string>
    <string>/usr/local/etc/rsyslog.conf</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/homebrew.mxcl.rsyslog.plist
```

**Test rsyslog:**
```bash
# From another machine
logger -n 192.168.4.253 -P 514 -t test "Test syslog message"

# Check if received
tail -f /var/log/unifi/system.log
```

### Step 2: Configure UDM-SE to Send Syslogs

**Via UniFi Controller UI:**
1. Navigate to **Settings** → **System** → **Remote Logging**
2. Enable **Remote Logging**
3. Enter syslog server: `192.168.4.253`
4. Port: `514`
5. Protocol: **TCP** (more reliable than UDP)
6. Save

**Via API (programmatic):**
```ruby
# lib/unifi/client.rb - Add method
def enable_remote_logging(server_ip, port: 514)
  put('/proxy/network/api/s/default/rest/setting/mgmt',
    {
      remote_syslog_enabled: true,
      remote_syslog_server: server_ip,
      remote_syslog_port: port,
      remote_syslog_protocol: 'tcp'
    }
  )
end
```

### Step 3: Log Monitoring Job

```ruby
# app/jobs/unifi_syslog_monitor_job.rb
class UnifiSyslogMonitorJob < ApplicationJob
  queue_as :default
  
  LOG_FILES = {
    ips: '/var/log/unifi/ips.log',
    firewall: '/var/log/unifi/firewall.log',
    system: '/var/log/unifi/system.log'
  }
  
  def perform
    LOG_FILES.each do |type, file_path|
      next unless File.exist?(file_path)
      process_log_file(type, file_path)
    end
  end
  
  private
  
  def process_log_file(type, file_path)
    # Track last read position
    position_key = "syslog_position_#{type}"
    last_position = Rails.cache.read(position_key) || 0
    
    File.open(file_path, 'r') do |file|
      file.seek(last_position)
      
      file.each_line do |line|
        process_log_line(type, line)
      end
      
      Rails.cache.write(position_key, file.pos)
    end
  rescue StandardError => e
    Rails.logger.error("Error processing #{type} log: #{e.message}")
  end
  
  def process_log_line(type, line)
    case type
    when :ips
      parse_ips_alert(line)
    when :firewall
      parse_firewall_event(line)
    when :system
      parse_system_event(line)
    end
  end
  
  def parse_ips_alert(line)
    # Example line:
    # 2026-02-19T12:34:56 UDMSE EVT_IPS_ALERT: botcc detected from 192.168.4.123
    
    return unless line.include?('EVT_IPS_ALERT')
    
    # Parse timestamp, category, source IP
    if line =~ /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}).*?(\w+) detected from ([\d.]+)/
      timestamp = Time.parse($1)
      category = $2
      source_ip = $3
      
      NetworkEvent.create!(
        event_type: 'ips_alert',
        severity: 'high',
        category: category,
        source_ip: source_ip,
        message: line.strip,
        occurred_at: timestamp,
        raw_payload: { source: 'syslog', original_line: line }
      )
    end
  rescue StandardError => e
    Rails.logger.error("Failed to parse IPS alert: #{e.message}")
  end
  
  def parse_firewall_event(line)
    # Similar parsing for firewall events
  end
  
  def parse_system_event(line)
    # Parse device online/offline events
  end
end
```

**Schedule:**
```yaml
# config/recurring.yml
production:
  unifi_syslog_monitor:
    class: UnifiSyslogMonitorJob
    schedule: every 30 seconds  # Near real-time
```

### Step 4: Logrotate Configuration

```bash
# /etc/logrotate.d/unifi
/var/log/unifi/*.log {
  daily
  rotate 30
  compress
  delaycompress
  missingok
  notifempty
  create 0644 $(whoami) staff
}
```

---

## Testing Plan

### API Testing

```bash
# 1. Test sync job manually
rails console
> UnifiSyncService.new.sync_all

# 2. Verify database
> NetworkDevice.count
> NetworkClient.online.count
> NetworkEvent.today.count

# 3. Test API endpoints
curl -H "X-API-Key: $EUREKA_API_KEY" \
  http://localhost:3001/api/network/devices | jq

curl -H "X-API-Key: $EUREKA_API_KEY" \
  http://localhost:3001/api/network/clients | jq

curl -H "X-API-Key: $EUREKA_API_KEY" \
  http://localhost:3001/api/network/health | jq
```

### Syslog Testing

```bash
# 1. Test rsyslog reception
logger -n 192.168.4.253 -P 514 -t EVT_IPS_ALERT "Test IPS alert"
tail -f /var/log/unifi/ips.log

# 2. Generate real event on UDM-SE
# Block a test client temporarily, check if event appears

# 3. Run monitor job
rails runner "UnifiSyslogMonitorJob.perform_now"

# 4. Verify event stored
rails console
> NetworkEvent.where(event_type: 'ips_alert').last
```

---

## Deployment Checklist

### Prerequisites
- [ ] Eureka-homekit running on 192.168.4.253
- [ ] PostgreSQL accessible
- [ ] Solid Queue configured for background jobs
- [ ] Read-only UniFi admin user created

### Phase 1A (API)
- [ ] Run migrations
- [ ] Add environment variables
- [ ] Deploy code changes
- [ ] Test API authentication
- [ ] Manually trigger sync job
- [ ] Verify data in database
- [ ] Enable recurring jobs
- [ ] Test API endpoints

### Phase 1B (Syslog)
- [ ] Install rsyslog on production server
- [ ] Configure rsyslog.conf
- [ ] Create log directories
- [ ] Start rsyslog service
- [ ] Configure UDM-SE remote logging
- [ ] Test log reception
- [ ] Deploy monitor job
- [ ] Configure logrotate
- [ ] Test end-to-end flow

---

## Security Considerations

1. **API Authentication:**
   - Use strong API key for Eureka API
   - Store in Rails credentials (not .env)
   - Rotate keys periodically

2. **UniFi Credentials:**
   - Use read-only admin account
   - Never commit credentials to git
   - Use Rails encrypted credentials

3. **Syslog Security:**
   - Consider TLS for syslog (port 6514)
   - Firewall rules: only UDM-SE → production server
   - Log rotation to prevent disk fill

4. **Network Security:**
   - API only accessible on local network
   - Consider VPN for remote access
   - Rate limiting on API endpoints

---

## Future Enhancements (Phase 2+)

### Phase 2: Dashboard UI
- [ ] Add network monitoring dashboard to eureka-homekit UI
- [ ] Real-time device status widgets
- [ ] IPS alert notifications
- [ ] Client bandwidth graphs
- [ ] ActionCable for real-time updates

### Phase 3: Control Operations
- [ ] Add write endpoints (block client, restart device)
- [ ] Manual firmware update triggers
- [ ] Port forward management
- [ ] Firewall rule creation

### Phase 4: Alerting
- [ ] Email/SMS alerts for critical events
- [ ] Slack/Discord webhooks
- [ ] Custom alert rules engine
- [ ] Alert acknowledgment workflow

---

## Success Metrics

**Phase 1A:**
- ✅ API endpoints return valid data
- ✅ Devices sync every 5 minutes
- ✅ Events stored in database
- ✅ Zero authentication errors
- ✅ < 1 second API response time

**Phase 1B:**
- ✅ Syslog server receives logs from UDM-SE
- ✅ Events appear in database within 1 minute
- ✅ Zero log parsing errors
- ✅ Logrotate working correctly

---

## Related Documentation
- [UniFi API Data Catalog](../reference/unifi-api-data-catalog.md)
- [UniFi Ruby Clients Guide](../reference/unifi-ruby-clients.md)
- [Eureka-HomeKit Deployment](../deployment/deployment-eureka-homekit.md)
- [Overwatch DevOps Assessment](../assessments/devops-assessment.md)

---

**Status:** Ready for Implementation  
**Estimated Effort:** 2-3 days for Phase 1A, 1 day for Phase 1B  
**Next Steps:** Begin with Phase 1A migrations and UniFi client setup
