# UniFi × Eureka-HomeKit Integration Architecture
**Created:** February 19, 2026  
**Status:** Design Complete  
**Implementation Plan:** [plan-unifi-monitoring-api-eureka-integration.md](../plans/plan-unifi-monitoring-api-eureka-integration.md)

---

## System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         HOME NETWORK                                  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  UDM-SE (192.168.4.1)                                        │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │   │
│  │  │  UniFi Network │  │  IPS/IDS       │  │  Firewall      │ │   │
│  │  │  Controller    │  │  Engine        │  │  Engine        │ │   │
│  │  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘ │   │
│  │           │                   │                   │          │   │
│  │           └───────────────────┴───────────────────┘          │   │
│  │                              │                                │   │
│  │           ┌──────────────────┴──────────────────┐            │   │
│  │           │                                     │            │   │
│  │           ▼ HTTPS API (443)           ▼ Syslog (514/TCP)    │   │
│  └───────────┼─────────────────────────────────┼───────────────┘   │
│              │                                 │                    │
│              │                                 │                    │
│  ┌───────────▼─────────────────────────────────▼────────────────┐  │
│  │  Production Server (192.168.4.253) - M3 Ultra                │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  rsyslog Daemon                                         │ │  │
│  │  │  - Receives syslog from UDM-SE                          │ │  │
│  │  │  - Filters by event type                                │ │  │
│  │  │  - Writes to: /var/log/unifi/*.log                     │ │  │
│  │  └────────────────────┬────────────────────────────────────┘ │  │
│  │                       │                                       │  │
│  │                       │ Tails logs                            │  │
│  │                       ▼                                       │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  Eureka-HomeKit Rails App (Port 3001)                   │ │  │
│  │  │                                                          │ │  │
│  │  │  ┌────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  API Layer                                         │ │ │  │
│  │  │  │  ┌──────────────────────────────────────────────┐ │ │ │  │
│  │  │  │  │  GET /api/network/devices                    │ │ │ │  │
│  │  │  │  │  GET /api/network/clients                    │ │ │ │  │
│  │  │  │  │  GET /api/network/health                     │ │ │ │  │
│  │  │  │  │  GET /api/network/events                     │ │ │ │  │
│  │  │  │  └──────────────────────────────────────────────┘ │ │ │  │
│  │  │  │                     │                              │ │ │  │
│  │  │  │  ┌──────────────────▼──────────────────────────┐ │ │ │  │
│  │  │  │  │  Services                                   │ │ │ │  │
│  │  │  │  │  - UnifiClient (API wrapper)                │ │ │ │  │
│  │  │  │  │  - UnifiSyncService (polling)               │ │ │ │  │
│  │  │  │  │  - UnifiAlertService (processing)           │ │ │ │  │
│  │  │  │  └──────────────────┬──────────────────────────┘ │ │ │  │
│  │  │  │                     │                              │ │ │  │
│  │  │  │  ┌──────────────────▼──────────────────────────┐ │ │ │  │
│  │  │  │  │  Background Jobs (Solid Queue)              │ │ │ │  │
│  │  │  │  │  - UnifiSyncJob (every 5 min)               │ │ │ │  │
│  │  │  │  │  - UnifiHealthCheckJob (daily)              │ │ │ │  │
│  │  │  │  │  - UnifiSyslogMonitorJob (every 30s)        │ │ │ │  │
│  │  │  │  └──────────────────┬──────────────────────────┘ │ │ │  │
│  │  │  │                     │                              │ │ │  │
│  │  │  │  ┌──────────────────▼──────────────────────────┐ │ │ │  │
│  │  │  │  │  Models                                     │ │ │ │  │
│  │  │  │  │  - NetworkDevice                            │ │ │ │  │
│  │  │  │  │  - NetworkClient                            │ │ │ │  │
│  │  │  │  │  - NetworkEvent                             │ │ │ │  │
│  │  │  │  │  - NetworkHealthSnapshot                    │ │ │ │  │
│  │  │  │  └──────────────────┬──────────────────────────┘ │ │ │  │
│  │  │  └────────────────────┼────────────────────────────┘ │ │  │
│  │  │                       │                                │ │  │
│  │  │                       ▼                                │ │  │
│  │  │  ┌────────────────────────────────────────────────┐   │ │  │
│  │  │  │  PostgreSQL Database                           │   │ │  │
│  │  │  │  - network_devices                             │   │ │  │
│  │  │  │  - network_clients                             │   │ │  │
│  │  │  │  - network_events                              │   │ │  │
│  │  │  │  - network_health_snapshots                    │   │ │  │
│  │  │  └────────────────────────────────────────────────┘   │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Flow 1: Polling-Based Sync (Every 5 Minutes)

```
1. UnifiSyncJob triggered by Solid Queue
   ↓
2. UnifiClient authenticates to UDM-SE
   ↓
3. Fetches data via HTTPS API:
   - /proxy/network/api/s/default/stat/device  (devices)
   - /proxy/network/api/s/default/stat/sta     (clients)
   - /proxy/network/api/s/default/stat/event   (recent events)
   - /proxy/network/api/s/default/stat/health  (health status)
   ↓
4. UnifiSyncService processes responses:
   - Creates/updates NetworkDevice records
   - Creates/updates NetworkClient records
   - Creates new NetworkEvent records (no duplicates)
   - Updates NetworkHealthSnapshot for today
   ↓
5. Data stored in PostgreSQL
   ↓
6. Available via GET /api/network/* endpoints
```

### Flow 2: Syslog-Based Real-Time Events (< 1 Second)

```
1. Event occurs on UDM-SE:
   - IPS threat detected
   - Device goes offline
   - Client connects/disconnects
   ↓
2. UDM-SE sends syslog message to 192.168.4.253:514
   ↓
3. rsyslog daemon receives message:
   - Filters by program name / content
   - Routes to appropriate log file:
     * /var/log/unifi/ips.log
     * /var/log/unifi/firewall.log
     * /var/log/unifi/system.log
   ↓
4. UnifiSyslogMonitorJob runs every 30 seconds:
   - Tails log files from last read position
   - Parses structured log lines
   - Extracts: timestamp, severity, IPs, message
   ↓
5. Creates NetworkEvent records with:
   - event_type: 'ips_alert', 'firewall_block', etc.
   - severity: 'critical', 'high', 'medium', 'low'
   - occurred_at: parsed timestamp
   - raw_payload: original log line
   ↓
6. Events immediately available via API
```

### Flow 3: API Consumer Access

```
External App (e.g., monitoring dashboard)
   ↓
GET /api/network/devices
   Headers: X-API-Key: <secret>
   ↓
Api::NetworkController#devices
   ↓
Queries NetworkDevice.all
   ↓
Returns JSON:
   {
     "devices": [...],
     "meta": {
       "total": 14,
       "online": 13,
       "offline": 1
     }
   }
```

---

## Component Details

### 1. UniFi Controller (UDM-SE)

**Role:** Source of truth for network state

**Interfaces:**
- **HTTPS API (443):** Read operations, some write operations
- **Syslog (514/TCP):** Real-time event streaming

**Configuration:**
- Settings → System → Remote Logging
- Server: 192.168.4.253
- Port: 514
- Protocol: TCP

### 2. rsyslog Daemon

**Role:** Receive and filter syslog messages

**Configuration File:** `/usr/local/etc/rsyslog.conf`

**Log Files:**
- `/var/log/unifi/ips.log` - IPS/IDS alerts
- `/var/log/unifi/firewall.log` - Firewall events
- `/var/log/unifi/system.log` - Device events

**Logrotate:**
- Daily rotation
- Keep 30 days
- Compress old logs

### 3. Eureka-HomeKit Rails App

**Role:** Central data store and API provider

**Components:**

#### Models
- `NetworkDevice` - Infrastructure devices (APs, switches)
- `NetworkClient` - Connected devices
- `NetworkEvent` - IPS alerts, logs, events
- `NetworkHealthSnapshot` - Daily health summaries

#### Services
- `Unifi::Client` - API wrapper with authentication
- `UnifiSyncService` - Sync logic (devices, clients, events)
- `UnifiAlertService` - Alert processing and notifications

#### Jobs
- `UnifiSyncJob` - Scheduled every 5 minutes
- `UnifiHealthCheckJob` - Daily at 2 AM
- `UnifiSyslogMonitorJob` - Every 30 seconds

#### API Endpoints
- `GET /api/network/devices` - List all network devices
- `GET /api/network/clients` - List connected clients
- `GET /api/network/health` - System health snapshot
- `GET /api/network/events` - Recent events (filterable)

**Authentication:** X-API-Key header

### 4. PostgreSQL Database

**Tables:**

```sql
network_devices
  - id, name, device_type, model, mac, ip
  - firmware_version, state, uptime, upgradable
  - sys_stats (JSONB), raw_data (JSONB)

network_clients
  - id, hostname, mac, ip, is_wired, network
  - rx_bytes, tx_bytes, signal_strength
  - connected_to_device_id (FK)
  - first_seen_at, last_seen_at

network_events
  - id, event_type, severity, category
  - source_ip, destination_ip, message
  - network_client_id (FK), network_device_id (FK)
  - occurred_at, raw_payload (JSONB)

network_health_snapshots
  - id, snapshot_date (unique)
  - devices_online, devices_total
  - clients_connected, ips_alerts_count
  - total_bandwidth, details (JSONB)
```

---

## Data Models

### NetworkDevice

```ruby
{
  id: 1,
  name: "U7-Pro New",
  device_type: "uap",          # access_point
  model: "U7PRO",
  mac: "9c:05:d6:50:df:f0",
  ip: "192.168.4.134",
  firmware_version: "8.4.6.18068",
  state: "online",
  uptime: 2290747,              # seconds
  upgradable: false,
  sys_stats: {
    cpu: 18.5,
    mem: 42.3,
    temps: [
      { name: "CPU", value: 45 }
    ]
  },
  last_seen_at: "2026-02-19T12:34:56Z"
}
```

### NetworkClient

```ruby
{
  id: 1,
  hostname: "iPad Pro",
  mac: "1a:2d:69:35:7d:d7",
  ip: "192.168.4.236",
  is_wired: false,
  network: "Default",
  essid: "TOTALLY_NOT_HAUNTED",
  rx_bytes: 926171234,
  tx_bytes: 2640123456,
  signal_strength: -45,          # RSSI
  connected_to_device_id: 1,     # FK to U7-Pro New
  last_seen_at: "2026-02-19T12:34:56Z"
}
```

### NetworkEvent

```ruby
{
  id: 1,
  event_type: "ips_alert",
  severity: "high",
  category: "botcc",             # botnet command & control
  source_ip: "192.168.4.123",
  destination_ip: "1.2.3.4",
  message: "IPS Alert: botcc detected from 192.168.4.123",
  blocked: true,
  occurred_at: "2026-02-19T12:34:56Z",
  raw_payload: {
    source: "syslog",
    original_line: "..."
  }
}
```

---

## API Specification

### Authentication

**Method:** API Key  
**Header:** `X-API-Key: <secret_key>`

**Example:**
```bash
curl -H "X-API-Key: $EUREKA_API_KEY" \
  https://api.higroundsolution.com/api/network/devices
```

### Endpoints

#### GET /api/network/devices

**Response:**
```json
{
  "devices": [
    {
      "id": 1,
      "name": "U7-Pro New",
      "device_type": "uap",
      "model": "U7PRO",
      "mac": "9c:05:d6:50:df:f0",
      "ip": "192.168.4.134",
      "firmware_version": "8.4.6.18068",
      "state": "online",
      "uptime": 2290747,
      "upgradable": false,
      "online?": true,
      "needs_update?": false
    }
  ],
  "meta": {
    "total": 14,
    "online": 13,
    "offline": 1
  }
}
```

#### GET /api/network/clients

**Query Parameters:**
- `network` - Filter by network name
- `wired` - true/false

**Response:**
```json
{
  "clients": [
    {
      "id": 1,
      "hostname": "iPad Pro",
      "mac": "1a:2d:69:35:7d:d7",
      "ip": "192.168.4.236",
      "is_wired": false,
      "network": "Default",
      "essid": "TOTALLY_NOT_HAUNTED",
      "last_seen_at": "2026-02-19T12:34:56Z",
      "online?": true,
      "total_bandwidth": 3566294690,
      "connection_type": "WiFi (TOTALLY_NOT_HAUNTED)"
    }
  ],
  "meta": {
    "total": 94,
    "online": 86,
    "wired": 32,
    "wireless": 62
  }
}
```

#### GET /api/network/health

**Response:**
```json
{
  "health": {
    "snapshot_date": "2026-02-19",
    "devices_online": 13,
    "devices_total": 14,
    "clients_connected": 86,
    "ips_alerts_count": 2,
    "firewall_blocks_count": 0,
    "total_bandwidth": 123456789012,
    "firmware_status": "updates_available"
  },
  "devices": {
    "online": 13,
    "offline": 1,
    "upgradable": 3
  },
  "clients": {
    "connected": 86
  },
  "events": {
    "critical_today": 0,
    "total_today": 45
  }
}
```

#### GET /api/network/events

**Query Parameters:**
- `type` - Filter by event_type (ips_alert, device_offline, etc.)
- `severity` - Filter by severity (critical, high, medium, low)
- `limit` - Max results (default: 100)

**Response:**
```json
{
  "events": [
    {
      "id": 1,
      "event_type": "ips_alert",
      "severity": "high",
      "category": "botcc",
      "source_ip": "192.168.4.123",
      "destination_ip": "1.2.3.4",
      "message": "IPS Alert: botcc detected",
      "occurred_at": "2026-02-19T12:34:56Z"
    }
  ],
  "meta": {
    "total": 45,
    "page": 1
  }
}
```

---

## Deployment Architecture

### Production Server Layout

```
192.168.4.253 (M3 Ultra macOS)
├── /Users/ericsmith66/Development/
│   ├── eureka-homekit/                    # Rails app
│   │   ├── app/
│   │   │   ├── models/network_*.rb        # NEW
│   │   │   ├── services/unifi_*.rb        # NEW
│   │   │   ├── jobs/unifi_*.rb            # NEW
│   │   │   └── controllers/api/network_controller.rb  # NEW
│   │   ├── lib/unifi/                     # NEW
│   │   │   ├── client.rb
│   │   │   └── cloud_client.rb
│   │   └── db/migrate/*_create_network_*.rb  # NEW
│   └── nextgen-plaid/                     # Separate Rails app
│
├── /usr/local/etc/
│   └── rsyslog.conf                       # NEW: Syslog config
│
├── /var/log/unifi/                        # NEW: Log directory
│   ├── ips.log
│   ├── firewall.log
│   └── system.log
│
└── ~/Library/LaunchAgents/
    └── homebrew.mxcl.rsyslog.plist        # NEW: Auto-start rsyslog
```

### Services Running

```
Port 3001  - Eureka-HomeKit Rails (foreman)
Port 3000  - NextGen Plaid Rails (foreman)
Port 5432  - PostgreSQL (LaunchAgent)
Port 6379  - Redis (LaunchAgent)
Port 514   - rsyslog (LaunchAgent)        # NEW
```

---

## Security Model

### Network Segmentation

```
┌─────────────────────────────────────────┐
│  UDM-SE (192.168.4.1)                   │
│  - Management interface: HTTPS/443      │
│  - Syslog output: TCP/514               │
└─────────────────┬───────────────────────┘
                  │ Private network only
                  ▼
┌─────────────────────────────────────────┐
│  Production Server (192.168.4.253)      │
│  - API: Port 3001 (behind Cloudflare)   │
│  - rsyslog: Port 514 (local only)       │
└─────────────────────────────────────────┘
                  │ Cloudflare Tunnel
                  ▼
┌─────────────────────────────────────────┐
│  Internet                                │
│  - api.higroundsolution.com              │
│  - X-API-Key authentication required     │
└─────────────────────────────────────────┘
```

### Authentication Layers

1. **UniFi API Access:**
   - Read-only admin user
   - Username/password (encrypted in Rails credentials)
   - Session cookies (5-minute validity)

2. **Eureka API Access:**
   - API key in header (X-API-Key)
   - No public endpoints without key
   - Rate limiting (future)

3. **Syslog Security:**
   - Only accepts from 192.168.4.1
   - TCP for reliability
   - Consider TLS (port 6514) for encryption

### Secrets Management

```yaml
# config/credentials.yml.enc (encrypted)
unifi:
  username: readonly_monitoring
  password: <secure_password>
  host: https://192.168.4.1
  site: default

eureka:
  api_key: <random_256_bit_key>
```

---

## Monitoring & Observability

### Metrics to Track

**System Health:**
- API response times
- Job execution duration
- Database query performance
- Syslog message processing rate

**Network Health:**
- Devices online/offline
- Client count over time
- Bandwidth usage trends
- IPS alert frequency

### Logging Strategy

**Application Logs:**
```ruby
# JSON structured logging
Rails.logger.info({
  event: 'unifi_sync_completed',
  devices_synced: 14,
  clients_synced: 94,
  duration_ms: 1234
}.to_json)
```

**Syslog Logs:**
- Filtered by severity
- Rotated daily
- Compressed after 1 day
- Retained for 30 days

### Alerting (Future)

- Critical IPS alerts → Slack
- Device offline > 5 min → Email
- API errors → Sentry
- Disk space low → Monitoring system

---

## Future Enhancements

### Phase 2: Dashboard UI
- Real-time network status widget
- Device health indicators
- Client bandwidth graphs
- IPS alert timeline

### Phase 3: Control Operations
- Block/unblock clients via UI
- Restart devices
- Trigger speed tests
- Manage port forwards

### Phase 4: Advanced Analytics
- Bandwidth trends
- Anomaly detection
- Client behavior patterns
- Firmware update scheduling

---

## Related Documentation

- [Implementation Plan](../plans/plan-unifi-monitoring-api-eureka-integration.md)
- [UniFi API Data Catalog](../reference/unifi-api-data-catalog.md)
- [UniFi API Write Capabilities](../reference/unifi-api-write-capabilities.md)
- [UniFi Ruby Clients](../reference/unifi-ruby-clients.md)

---

**Document Status:** Design Complete  
**Last Updated:** 2026-02-19  
**Ready for Implementation:** ✅  
**Next Steps:** Begin Phase 1A migrations
