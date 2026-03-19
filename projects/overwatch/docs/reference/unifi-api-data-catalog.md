# UniFi UDM-SE API Data Catalog
**Generated:** February 18, 2026  
**Source:** UDM-SE at 192.168.4.1  
**Firmware:** 4.4.6  
**API Version:** UniFi Network Application 8.x

---

## Overview

This document catalogs all data available from the UniFi Dream Machine SE through local and cloud APIs. Data is organized by category with use cases and monitoring value.

---

## Data Categories

### 1. System Information
### 2. UniFi Infrastructure Devices (APs, Switches, Gateway)
### 3. Connected Clients
### 4. Network Configuration
### 5. Wireless Networks (SSIDs)
### 6. Security & Threat Management
### 7. Port Forwarding & Firewall
### 8. Performance & Statistics
### 9. Cloud API Data
### 10. Events & Logs

---

## 1. System Information

**Endpoint:** `/proxy/network/api/s/default/stat/sysinfo`

### Available Data

| Field | Example | Description | Monitoring Value |
|-------|---------|-------------|------------------|
| `name` | "UDM SE" | Controller name | System identification |
| `version` | "8.4.6" | UniFi Network version | Update tracking |
| `hostname` | "UDMSE" | System hostname | Network identification |
| `timezone` | "America/Chicago" | System timezone | Time synchronization |
| `uptime` | 7581780 | Seconds since boot | Stability tracking |
| `autobackup` | true | Auto-backup enabled | Backup status |
| `build` | "atag_8.4.6_18068" | Build identifier | Version tracking |

**Use Cases:**
- Track firmware version and available updates
- Monitor system uptime for stability
- Verify backup configuration
- System health dashboard

---

## 2. UniFi Infrastructure Devices

**Endpoint:** `/proxy/network/api/s/default/stat/device`

### Device Types
- `uap` - Access Points (WiFi 6/7)
- `usw` - Switches (PoE, managed)
- `udm` - Gateway/Controller (UDM-SE)
- `ugw` - Gateway (legacy)
- `usp` - SmartPower PDU

### Core Device Data (All Types)

| Field | Example | Description | Monitoring Value |
|-------|---------|-------------|------------------|
| **Identity** | | | |
| `name` | "U7-Pro New" | Device name | ⭐⭐⭐ Display |
| `mac` | "9c:05:d6:50:df:f0" | MAC address | ⭐⭐⭐ Unique ID |
| `ip` | "192.168.4.134" | IP address | ⭐⭐⭐ Network location |
| `model` | "U7PRO" | Model code | ⭐⭐ Device type |
| `type` | "uap" | Device type | ⭐⭐⭐ Categorization |
| `serial` | "70A741A01B01" | Serial number | Reference |
| **Status** | | | |
| `state` | 1 | Device state (1=online, 0=offline) | ⭐⭐⭐ Health |
| `adopted` | true | Adoption status | Status |
| `uptime` | 2290747 | Seconds online | ⭐⭐⭐ Stability |
| `last_seen` | 1708297432 | Unix timestamp | ⭐⭐⭐ Connectivity |
| **Firmware** | | | |
| `version` | "8.4.6.18068" | Firmware version | ⭐⭐⭐ Update tracking |
| `upgradable` | true | Update available | ⭐⭐⭐ Maintenance |
| `upgrade_to_firmware` | "8.5.0" | Next firmware | Planning |
| **Performance** | | | |
| `uplink` | {...} | Uplink connection details | Network topology |
| `satisfaction` | 98 | Experience score (0-100) | ⭐⭐ Quality |
| `bytes` | 1234567890 | Total bytes transferred | Traffic analysis |
| `num_sta` | 12 | Connected clients (APs only) | ⭐⭐ Capacity |
| **Hardware** | | | |
| `board_rev` | 21 | Board revision | Hardware info |
| `has_fan` | true | Fan present | Cooling |
| `has_temperature` | true | Temp sensor present | Monitoring |
| `sys_stats` | {...} | CPU/memory/temperature | ⭐⭐⭐ Performance |

### Access Point Specific Data

| Field | Description | Monitoring Value |
|-------|-------------|------------------|
| `radio_table` | 2.4GHz/5GHz/6GHz radio config | ⭐⭐ WiFi config |
| `radio_table_stats` | Per-radio statistics | ⭐⭐ Performance |
| `vap_table` | Virtual AP config per SSID | Network setup |
| `scan_radio_table` | WiFi scanner results | Interference |
| `guest-num_sta` | Guest clients connected | ⭐⭐ Usage |
| `user-num_sta` | Regular clients connected | ⭐⭐ Usage |
| `wifi_caps` | Supported WiFi features | Capabilities |
| `atf_enabled` | Airtime fairness | QoS |

### Switch Specific Data

| Field | Description | Monitoring Value |
|-------|-------------|------------------|
| `port_table` | Port status, PoE, link speed | ⭐⭐⭐ Connectivity |
| `ethernet_table` | Ethernet interface stats | Network |
| `downlink_table` | Connected devices per port | ⭐⭐ Topology |
| `lldp_table` | LLDP neighbor discovery | Discovery |
| `dot1x_portctrl_enabled` | 802.1X auth | Security |

### Gateway Specific Data (UDM-SE)

| Field | Description | Monitoring Value |
|-------|-------------|------------------|
| `wan_ip` | WAN IP address | ⭐⭐⭐ Internet |
| `wan_ip6` | WAN IPv6 address | Internet |
| `speedtest_status` | Last speed test results | ⭐⭐ ISP performance |
| `uplink_table` | WAN interface details | ⭐⭐⭐ Connectivity |
| `internet` | Internet connectivity status | ⭐⭐⭐ Status |

### System Stats (All Devices)

```json
"sys_stats": {
  "cpu": 18.5,           // CPU usage %
  "mem": 42.3,           // Memory usage %
  "temps": [             // Temperature sensors
    {"name": "CPU", "value": 45, "type": "cpu"},
    {"name": "PHY", "value": 52, "type": "phy"}
  ],
  "uptime": 2290747      // Seconds
}
```

**Monitoring Value:** ⭐⭐⭐ Critical for performance alerts

---

## 3. Connected Clients

**Endpoint:** `/proxy/network/api/s/default/stat/sta`

### Client Data

| Field | Example | Description | Monitoring Value |
|-------|---------|-------------|------------------|
| **Identity** | | | |
| `hostname` | "iPad" | Device hostname | ⭐⭐⭐ Display |
| `mac` | "1a:2d:69:35:7d:d7" | MAC address | ⭐⭐⭐ Unique ID |
| `ip` | "192.168.4.236" | IP address | ⭐⭐⭐ Location |
| `oui` | "Apple" | Manufacturer | Device type |
| `icon_filename` | "ipad_ios" | Icon identifier | UI |
| **Connection** | | | |
| `is_wired` | false | Wired vs wireless | ⭐⭐ Type |
| `is_guest` | false | Guest network | ⭐⭐ Classification |
| `network` | "Default" | Network name | ⭐⭐⭐ Segmentation |
| `network_id` | "636d1c6e..." | Network UUID | Reference |
| `essid` | "TOTALLY_NOT_HAUNTED" | WiFi SSID (wireless) | ⭐⭐ WiFi info |
| **Timestamps** | | | |
| `first_seen` | 1708297432 | First connection | History |
| `last_seen` | 1708307432 | Last activity | ⭐⭐⭐ Online status |
| `assoc_time` | 1708297432 | Current session start | Session tracking |
| `uptime` | 10000 | Session duration (sec) | ⭐⭐ Usage |
| **Traffic** | | | |
| `rx_bytes` | 926171234 | Received bytes (total) | ⭐⭐⭐ Bandwidth |
| `tx_bytes` | 2640123456 | Transmitted bytes (total) | ⭐⭐⭐ Bandwidth |
| `wired-rx_bytes` | 123456 | Wired RX (if applicable) | Stats |
| `wired-tx_bytes` | 654321 | Wired TX (if applicable) | Stats |
| **WiFi Stats** (wireless only) | | | |
| `rssi` | -45 | Signal strength (dBm) | ⭐⭐ Quality |
| `signal` | -45 | Signal level | ⭐⭐ Quality |
| `noise` | -90 | Noise floor | Quality |
| `channel` | 149 | WiFi channel | Info |
| `radio` | "na" | Radio band (ng=2.4, na=5, 6e=6GHz) | Info |
| `tx_rate` | 866700 | TX rate (kbps) | ⭐⭐ Speed |
| `rx_rate` | 866700 | RX rate (kbps) | ⭐⭐ Speed |
| `tx_power` | 20 | TX power (dBm) | Info |
| `satisfaction` | 95 | Experience score (0-100) | ⭐⭐⭐ Quality |
| **Device Info** | | | |
| `fingerprint_source` | 2 | How device was identified | Classification |
| `product_line` | "Apple" | Product line | Type |
| `product_model` | "iPad Pro" | Device model | Info |
| `fw_version` | "iOS 17.3" | Firmware/OS version | Info |
| **Security** | | | |
| `authorized` | true | Client authorized | ⭐⭐ Status |
| `qos_policy_applied` | true | QoS applied | QoS |
| `anomalies` | 0 | Detected anomalies | ⭐⭐⭐ Security |
| **Uplink Info** (where connected) | | | |
| `last_uplink_mac` | "9c:05:d6:50:df:f0" | AP/switch MAC | ⭐⭐ Topology |
| `last_uplink_name` | "U7-Pro New" | AP/switch name | ⭐⭐⭐ Location |
| `sw_port` | 5 | Switch port (wired) | ⭐⭐ Physical port |
| `sw_depth` | 2 | Hops from gateway | Topology |

### Client Categorization

**By Network:**
- Default: 91 clients (your main network)
- Span Network: 3 clients
- Camera Network: 0 clients (cameras on default!)
- Guest: 0 clients

**By Type:**
- Wired: 32 clients
- Wireless: 62 clients

**By Manufacturer (OUI):**
- Apple: iPhones, iPads, MacBooks
- UniFi: Cameras, APs
- Lutron: Smart home controllers
- Etc.

---

## 4. Network Configuration

**Endpoint:** `/proxy/network/api/s/default/rest/networkconf`

### Network Data

| Field | Example | Description | Monitoring Value |
|-------|---------|-------------|------------------|
| `name` | "Default" | Network name | ⭐⭐⭐ Display |
| `purpose` | "corporate" | Network type | Classification |
| `vlan` | 2 | VLAN ID (if applicable) | ⭐⭐⭐ Segmentation |
| `ip_subnet` | "192.168.4.1/24" | Subnet CIDR | ⭐⭐⭐ IP range |
| `dhcpd_enabled` | true | DHCP server enabled | Config |
| `dhcpd_start` | "192.168.4.10" | DHCP range start | IP pool |
| `dhcpd_stop` | "192.168.4.250" | DHCP range end | IP pool |
| `domain_name` | "localdomain" | DNS domain | Config |
| `dhcpd_dns` | ["192.168.4.1"] | DNS servers | Config |
| `networkgroup` | "LAN" | Network group | Organization |
| `igmp_snooping` | true | IGMP snooping enabled | Multicast |
| `isolation` | false | Client isolation | ⭐⭐ Security |

**Your Networks:**
1. **Default** - 192.168.4.1/24 (primary)
2. **Span Network** - VLAN 2, 192.168.50.1/24
3. **Camera Network** - VLAN 3, 192.168.6.1/24
4. **WireGuard VPN** - 192.168.3.1/24
5. **OpenVPN** - 192.168.5.1/24
6. **Internet 1** (WAN)
7. **Internet 2** (WAN)

---

## 5. Wireless Networks (SSIDs)

**Endpoint:** `/proxy/network/api/s/default/rest/wlanconf`

### WLAN Data

| Field | Example | Description | Monitoring Value |
|-------|---------|-------------|------------------|
| `name` | "TOTALLY_NOT_HAUNTED" | SSID name | ⭐⭐⭐ Display |
| `enabled` | true | SSID enabled | ⭐⭐ Status |
| `security` | "wpapsk" | Security type (WPA2/WPA3) | Security |
| `wpa_enc` | "ccmp" | Encryption (AES) | Security |
| `wpa_mode` | "wpa2" | WPA mode | Security |
| `hide_ssid` | false | Hidden network | Config |
| `is_guest` | false | Guest network | ⭐⭐ Classification |
| `networkconf_id` | "636d1c6e..." | Associated network | Link |
| `usergroup_id` | "..." | User group | Access control |
| `schedule` | [] | Time-based schedule | Automation |
| `radius_das_enabled` | false | RADIUS dynamic auth | Enterprise |
| `no2ghz_oui` | false | 2.4GHz band steering | Performance |

**Your SSIDs:**
1. **TOTALLY_NOT_HAUNTED** - Primary WiFi
2. **HAUNTED** - Secondary WiFi

---

## 6. Security & Threat Management

**Endpoint:** `/proxy/network/api/s/default/get/setting` (filter: key="ips")

### IPS/IDS Configuration

| Field | Description | Monitoring Value |
|-------|-------------|------------------|
| `enabled_categories` | Array of 37 threat categories | ⭐⭐⭐ Protection scope |
| `ips_mode` | "auto" or "manual" | Auto-update mode |
| `ad_blocking_enabled` | false | DNS ad blocking | Privacy |
| `dns_filters` | DNS filter config per network | ⭐⭐ Content filtering |
| `honeypot_enabled` | false | Honeypot feature | Advanced detection |
| `endpoint_scanning` | false | Device scanning | Security |
| `memory_optimized` | true | Performance mode | Performance |

### Threat Categories (37 Active)

**Malware & Exploits:**
- `botcc` - Botnet command & control
- `emerging-malware` - Malware distribution
- `emerging-worm` - Worm propagation
- `emerging-exploit` - Exploit attempts
- `emerging-shellcode` - Shellcode injection
- `emerging-mobile` - Mobile malware

**Attack Types:**
- `emerging-dos` - Denial of service
- `emerging-scan` - Port scanning
- `emerging-attackresponse` - Attack responses
- `emerging-sql` - SQL injection
- `emerging-webapps` - Web app attacks
- `emerging-webclient` - Browser exploits
- `emerging-webserver` - Web server attacks

**Threat Intelligence:**
- `ciarmy` - Known malicious IPs
- `compromised` - Compromised hosts
- `dshield` - DShield blacklist
- `malicious-hosts` - Known bad actors
- `tor` - TOR exit nodes
- `dark-web-blocker-list` - Dark web

**Protocol Attacks:**
- `emerging-ftp`, `emerging-imap`, `emerging-pop3`
- `emerging-smtp`, `emerging-snmp`, `emerging-telnet`
- `emerging-tftp`, `emerging-voip`, `emerging-dns`
- `emerging-rpc`, `emerging-netbios`, `emerging-icmp`

### IPS Events (Real-Time)

**Endpoint:** `/proxy/network/api/s/default/stat/event` (filter: key contains "EVT_IPS")

**Event Data:**
```json
{
  "key": "EVT_IPS_ALERT",
  "timestamp": 1708297432000,
  "datetime": "2026-02-18T12:00:00Z",
  "msg": "IPS Alert: botcc detected",
  "category": "botcc",
  "severity": "critical",
  "src_ip": "192.168.4.123",
  "dst_ip": "1.2.3.4",
  "src_port": 54321,
  "dst_port": 443,
  "proto": "tcp",
  "signature": "BOTNET:GENERIC Command and Control Traffic",
  "inner_alert_gid": 1,
  "inner_alert_signature_id": 123456,
  "blocked": true
}
```

**Monitoring Value:** ⭐⭐⭐ Critical security events

---

## 7. Port Forwarding & Firewall

### Port Forwarding

**Endpoint:** `/proxy/network/api/s/default/rest/portforward`

| Field | Example | Description | Monitoring Value |
|-------|---------|-------------|------------------|
| `name` | "NextGen Plaid" | Rule name | ⭐⭐⭐ Display |
| `enabled` | true | Rule active | ⭐⭐⭐ Status |
| `src` | "any" | Source (usually "any") | Config |
| `dst_port` | "80" | WAN port | ⭐⭐⭐ External |
| `fwd` | "192.168.4.253" | Forward to IP | ⭐⭐⭐ Internal |
| `fwd_port` | "3000" | Forward to port | ⭐⭐⭐ Internal |
| `proto` | "tcp" | Protocol | Config |
| `log` | false | Log connections | Auditing |

### Firewall Rules

**Endpoint:** `/proxy/network/api/s/default/rest/firewallrule`

| Field | Description | Monitoring Value |
|-------|-------------|------------------|
| `name` | Rule name | ⭐⭐⭐ Display |
| `enabled` | Rule active | ⭐⭐⭐ Status |
| `action` | "accept", "drop", "reject" | ⭐⭐⭐ Action |
| `protocol` | "tcp", "udp", "icmp", "all" | Filter |
| `src_address` | Source IP/CIDR | ⭐⭐ Source |
| `dst_address` | Destination IP/CIDR | ⭐⭐ Destination |
| `src_networkconf_type` | "LAN", "WAN", etc. | Source zone |
| `dst_networkconf_type` | "LAN", "WAN", etc. | Destination zone |
| `logging` | Log matches | ⭐⭐ Auditing |
| `rule_index` | Priority order | Precedence |

### Firewall Groups

**Endpoint:** `/proxy/network/api/s/default/rest/firewallgroup`

**Example: Cloudflare IP Group**
```json
{
  "name": "Cloudflare",
  "group_type": "address-group",
  "group_members": [
    "173.245.48.0/20",
    "103.21.244.0/22",
    ...15 ranges
  ]
}
```

---

## 8. Performance & Statistics

### Device Statistics

**Per-Device Metrics:**
- `bytes` - Total bytes transferred (lifetime)
- `bytes-d` - Bytes today
- `bytes-r` - Bytes last rollover period
- `rx_bytes` / `tx_bytes` - Directional traffic
- `num_sta` - Connected clients (APs)
- `satisfaction` - Experience score (0-100)
- `uptime` - Seconds online

### Client Statistics

**Per-Client Metrics:**
- `rx_bytes` / `tx_bytes` - Total bandwidth
- `wired-rx_bytes` / `wired-tx_bytes` - Wired bandwidth
- `tx_rate` / `rx_rate` - Current link speeds
- `rssi` / `signal` - WiFi signal quality
- `satisfaction` - Experience score
- `uptime` - Current session duration
- `tx_retries` - Failed transmissions
- `wifi_tx_attempts` - Total attempts
- `wifi_tx_dropped` - Dropped packets

### Speed Test Results

**Endpoint:** Gateway device → `speedtest_status`

```json
{
  "status_download": 950.5,  // Mbps
  "status_upload": 45.2,     // Mbps
  "status_ping": 12,         // ms
  "latency": 12,
  "xput_download": 950.5,
  "xput_upload": 45.2,
  "rundate": 1708297432000,
  "server": {
    "name": "Dallas, TX",
    "cc": "US"
  }
}
```

**Monitoring Value:** ⭐⭐⭐ ISP performance tracking

---

## 9. Cloud API Data

**Base URL:** `https://api.ui.com`  
**Authentication:** `X-API-KEY: hY04GiUsCZGpNAtedBMp6ZzaFZ0Pm_1T`

### GET /ea/hosts

**Controller/Host Information:**

```json
{
  "id": "...",
  "type": "console",
  "ipAddress": "104.14.41.31",
  "owner": true,
  "lastConnectionStateChange": "2026-02-17T21:20:15Z",
  "latestBackupTime": "2026-02-18T04:34:04Z",
  "reportedState": {
    "hostname": "UDMSE",
    "deviceState": "updateAvailable",
    "firmwareUpdate": {
      "latestAvailableVersion": "5.0.12+64e93f2"
    },
    "hardware": {
      "name": "UniFi Dream Machine SE",
      "firmwareVersion": "4.4.6",
      "mac": "70A741A01B01",
      "serialno": "70a741a01b01"
    },
    "internetIssues5min": {
      "periods": [...]  // Internet outage events
    },
    "autoUpdate": {
      "schedule": {
        "frequency": "weekly",
        "day": 0,
        "hour": 0
      }
    }
  }
}
```

**Monitoring Value:**
- ⭐⭐⭐ Firmware updates available
- ⭐⭐⭐ Internet connectivity issues (5-min intervals)
- ⭐⭐⭐ Last backup timestamp
- ⭐⭐ Device state (online/offline/updating)
- ⭐⭐ Auto-update schedule

---

## 10. Events & Logs

**Endpoint:** `/proxy/network/api/s/default/stat/event`

### Event Types

| Event Key | Description | Monitoring Value |
|-----------|-------------|------------------|
| **Device Events** | | |
| `EVT_AP_CONNECTED` | AP came online | ⭐⭐⭐ Device status |
| `EVT_AP_DISCONNECTED` | AP went offline | ⭐⭐⭐ Device status |
| `EVT_AP_UPGRADED` | AP firmware upgraded | ⭐⭐ Maintenance |
| `EVT_AP_RESTARTED` | AP rebooted | ⭐⭐ Stability |
| `EVT_SW_CONNECTED` | Switch came online | ⭐⭐⭐ Device status |
| `EVT_SW_DISCONNECTED` | Switch went offline | ⭐⭐⭐ Device status |
| `EVT_GW_CONNECTED` | Gateway came online | ⭐⭐⭐ Critical |
| `EVT_GW_WAN_TRANSITION` | WAN failover event | ⭐⭐⭐ Internet |
| **Client Events** | | |
| `EVT_LU_Connected` | Client connected | ⭐⭐ User activity |
| `EVT_LU_Disconnected` | Client disconnected | ⭐⭐ User activity |
| `EVT_LU_ROAMED` | Client roamed to another AP | ⭐⭐ Mobility |
| `EVT_LU_ROAMING_FAILED` | Roaming failed | ⭐⭐ Performance |
| **Security Events** | | |
| `EVT_IPS_ALERT` | IPS threat detected | ⭐⭐⭐ Security |
| `EVT_AD_BLOCKED` | Ad blocked (if enabled) | Privacy |
| `EVT_DNS_FILTERED` | DNS filter blocked domain | ⭐⭐ Security |
| **Admin Events** | | |
| `EVT_AD_LOGIN` | Admin login | ⭐⭐⭐ Audit |
| `EVT_AD_LOGOUT` | Admin logout | Audit |
| `EVT_ADMIN_CONFIG_CHANGE` | Configuration changed | ⭐⭐⭐ Audit |
| **System Events** | | |
| `EVT_FW_UPDATE_AVAILABLE` | Firmware update ready | ⭐⭐⭐ Maintenance |
| `EVT_BACKUP_COMPLETED` | Backup finished | ⭐⭐ Backup status |
| `EVT_BACKUP_FAILED` | Backup failed | ⭐⭐⭐ Backup status |

### Event Structure

```json
{
  "key": "EVT_IPS_ALERT",
  "timestamp": 1708297432000,
  "datetime": "2026-02-18T12:00:00Z",
  "msg": "IPS Alert: botcc detected from 192.168.4.123",
  "user": "admin",
  "client_mac": "AA:BB:CC:DD:EE:FF",
  "ap_name": "U7-Pro New",
  "subsystem": "ips",
  "site_id": "636d1c5e25021519530da530"
}
```

---

## Data Freshness & Update Frequency

| Data Type | Update Frequency | Latency |
|-----------|------------------|---------|
| Device status (state) | Real-time | < 10 sec |
| Client status | Real-time | < 10 sec |
| Device stats (bytes, uptime) | Every 5 min | 5 min |
| Client stats (bandwidth) | Every 5 min | 5 min |
| IPS alerts | Real-time | < 1 sec |
| Events | Real-time | < 1 sec |
| Cloud API (firmware updates) | Every 24 hours | 24 hours |
| Cloud API (internet issues) | Every 5 minutes | 5 min |
| Speed test results | On-demand | Manual |

---

## API Rate Limits

**Local API:**
- No documented hard limits
- Recommended: 1 request per second for health
- Burst: 10 requests per second for specific queries

**Cloud API:**
- Free tier: 100 requests/hour
- Recommended: 1 request per 5 minutes

---

## Top Monitoring Use Cases

### Critical (Real-Time)

1. **Device Offline Alerts** - `state` != 1
2. **IPS Critical Alerts** - `EVT_IPS_ALERT` with `severity: critical`
3. **Internet Connectivity** - `internetIssues5min` from cloud API
4. **Gateway Status** - UDM-SE `state`

### Important (5-Minute Polling)

5. **Client Bandwidth Anomalies** - Sudden spike in `rx_bytes`/`tx_bytes`
6. **Device Performance** - `sys_stats.cpu` > 80%, `sys_stats.temps` > 75°C
7. **WiFi Quality** - Client `satisfaction` < 50
8. **Firmware Updates** - `upgradable: true` or cloud API `deviceState: updateAvailable`

### Daily Summary

9. **Health Snapshot** - All device/client counts, total bandwidth
10. **Security Summary** - IPS alert count by category
11. **Backup Status** - `latestBackupTime` < 24 hours
12. **Top Bandwidth Users** - Sort clients by total bytes

---

## Sample Monitoring Queries

### All Offline Devices
```ruby
NetworkDevice.where(state: 'offline')
```

### Clients Active in Last Hour
```ruby
NetworkClient.where('last_seen_at > ?', 1.hour.ago)
```

### Critical IPS Alerts Today
```ruby
NetworkEvent
  .where(event_type: 'ips_alert')
  .where(severity: 'critical')
  .where('occurred_at > ?', Date.current.beginning_of_day)
```

### Top 10 Bandwidth Users
```ruby
NetworkClient.order('(rx_bytes + tx_bytes) DESC').limit(10)
```

---

## Related Documentation

- [Network Inventory](../network-inventory/network-inventory-2026-02-18.md)
- [Firewall Security Review](../assessments/firewall-security-review-2026-02-18.md)
- [Integration Plan](../plans/plan-integrate-unifi-monitoring-eureka-homekit.md)

---

**Document Status:** Reference  
**Last Updated:** 2026-02-18  
**Maintainer:** AiderDesk
