# UniFi UDM-SE API Write Capabilities
**Generated:** February 19, 2026  
**Source:** UDM-SE at 192.168.4.1  
**Access Level:** Read/Write Local Admin API

---

## Overview

With read/write access to the UniFi local API, you can **fully manage and configure** your network infrastructure programmatically. This document catalogs all write operations available through the local admin API.

⚠️ **WARNING:** Write operations directly modify your network configuration. Always test changes in a controlled manner and maintain backups.

---

## Authentication & Session Management

### Login/Logout Operations ⭐⭐⭐

**Endpoint:** `POST /api/auth/login` (UDM-SE)

**Capabilities:**
- Create authenticated sessions
- Support for long-running sessions (remember=true)
- Session cookie management
- Explicit logout to destroy sessions

```bash
# Login
curl -k -X POST --data '{"username": "admin", "password": "$pw"}' \
  --header 'Content-Type: application/json' \
  -c cookie.txt https://192.168.4.1:443/api/auth/login

# Logout
curl -k -X POST -b cookie.txt \
  https://192.168.4.1/proxy/network/api/logout
```

---

## System Management

### System Control ⭐⭐⭐ **CRITICAL**

**Requires:** X-CSRF-Token header + Super Admin rights

| Operation | Endpoint | Method | Notes |
|-----------|----------|--------|-------|
| **Reboot UDM** | `/api/system/reboot` | POST | Restart entire gateway |
| **Power Off UDM** | `/api/system/poweroff` | POST | Shutdown gateway |
| **Backup System** | `/api/s/{site}/cmd/system` | POST | `{"cmd": "backup"}` |
| **Delete Backup** | `/api/s/{site}/cmd/backup` | POST | `{"cmd": "delete-backup", "filename": "..."}` |
| **List Backups** | `/api/s/{site}/cmd/backup` | POST | `{"cmd": "list-backups"}` |

### Site Management ⭐⭐⭐

**Endpoint:** `POST /api/s/{site}/cmd/sitemgr`

| Command | Parameters | Notes |
|---------|------------|-------|
| `add-site` | `desc` (required), `name` (shortname) | Create new site |
| `delete-site` | `name` (required) | Delete entire site |
| `update-site` | `desc` (required) | Update site metadata |
| `get-admins` | none | List site admins |

---

## Device Management

### Device Operations ⭐⭐⭐

**Endpoint:** `POST /api/s/{site}/cmd/devmgr`

| Command | Parameters | Description | Use Case |
|---------|------------|-------------|----------|
| `adopt` | `mac` (required) | Adopt new device | Add AP/switch to network |
| `restart` | `mac` (required) | Reboot device | Troubleshooting |
| `force-provision` | `mac` (required) | Push config to device | Apply pending changes |
| `upgrade` | `mac` (required) | Upgrade firmware | Security updates |
| `upgrade-external` | `mac`, `url` (both required) | Upgrade from custom URL | Beta firmware |
| `set-locate` | `mac` (required) | Blink LED | Physical identification |
| `unset-locate` | `mac` (required) | Stop blinking LED | Normal operation |
| `power-cycle` | `mac`, `port_idx` (both required) | Cycle PoE port | Restart powered device |
| `migrate` | `mac`, `inform_url` (both required) | Move device to new controller | Controller migration |
| `cancel-migrate` | `mac` (required) | Cancel migration | Abort move |
| `spectrum-scan` | `mac` (AP only, required) | Trigger RF scan | WiFi analysis |

**Device Configuration (REST)**

**Endpoint:** `PUT /api/s/{site}/rest/device/{_id}`

Update device settings like:
- Device name
- LED brightness
- PoE settings
- Port configurations (switches)
- Radio power (APs)
- Band steering

### Speed Testing ⭐⭐

**Endpoint:** `POST /api/s/{site}/cmd/devmgr`

| Command | Notes |
|---------|-------|
| `speedtest` | Trigger WAN speed test |
| `speedtest-status` | Check test status |

---

## Client Management

### Client Control ⭐⭐⭐

**Endpoint:** `POST /api/s/{site}/cmd/stamgr`

| Command | Parameters | Description | Use Case |
|---------|------------|-------------|----------|
| `block-sta` | `mac` (required) | Block client from network | Ban device |
| `unblock-sta` | `mac` (required) | Unblock client | Remove ban |
| `kick-sta` | `mac` (required) | Disconnect client | Force reconnect |
| `forget-sta` | `mac` (required) | Remove client from known list | Clean up old devices |
| `unauthorize-guest` | `mac` (required) | Revoke guest authorization | Guest management |

### Client Configuration ⭐⭐

**Endpoint:** `PUT /api/s/{site}/rest/user/{_id}`

Update client properties:
- Friendly name (`name`)
- Fixed IP assignment
- Bandwidth limits (user group assignment)
- Notes/descriptions
- Device type/icon override

```bash
# Example: Rename client
curl -k -X PUT -b cookie.txt \
  --data '{"name":"iPad Pro"}' \
  https://192.168.4.1/proxy/network/api/s/default/upd/user/5aca464bb79fc60200460394
```

---

## Network Configuration

### Networks (VLANs) ⭐⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/networkconf` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/networkconf/{_id}` (update)  
**Endpoint:** `DELETE /api/s/{site}/rest/networkconf/{_id}` (delete)

**Capabilities:**
- Create new VLANs
- Configure DHCP server settings
  - DHCP range (start/stop)
  - DNS servers
  - Domain name
  - Static DHCP leases
- Network isolation settings
- IGMP snooping
- Multicast DNS
- IPv6 configuration
- Guest network policies

**Example Network Creation:**
```json
{
  "name": "IoT Network",
  "purpose": "corporate",
  "vlan": 10,
  "ip_subnet": "192.168.10.1/24",
  "dhcpd_enabled": true,
  "dhcpd_start": "192.168.10.10",
  "dhcpd_stop": "192.168.10.250",
  "dhcpd_dns": ["1.1.1.1", "8.8.8.8"],
  "domain_name": "iot.local",
  "networkgroup": "LAN",
  "igmp_snooping": true,
  "isolation": true
}
```

---

## Wireless Configuration

### WiFi Networks (SSIDs) ⭐⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/wlanconf` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/wlanconf/{_id}` (update)  
**Endpoint:** `GET /api/s/{site}/rest/wlanconf/{_id}` (details)

**Capabilities:**
- Create/delete SSIDs
- Security settings (WPA2/WPA3)
- Password changes
- Enable/disable SSIDs
- Hide/show SSID broadcast
- Guest network configuration
- MAC filtering
- Band steering (2.4/5/6 GHz)
- Rate limiting per SSID
- VLAN assignment
- Scheduled WiFi (time-based on/off)
- Captive portal settings
- Radius authentication (Enterprise WiFi)

**Example SSID Creation:**
```json
{
  "name": "Guest WiFi",
  "enabled": true,
  "security": "wpapsk",
  "wpa_mode": "wpa2",
  "wpa_enc": "ccmp",
  "x_passphrase": "YourPasswordHere",
  "is_guest": true,
  "hide_ssid": false,
  "networkconf_id": "636d1c6e...",
  "usergroup_id": "guest-usergroup-id",
  "schedule": []
}
```

---

## Firewall & Security

### Firewall Rules ⭐⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/firewallrule` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/firewallrule/{_id}` (update)  
**Endpoint:** `DELETE /api/s/{site}/rest/firewallrule/{_id}` (delete)

**Capabilities:**
- Create custom firewall rules
- Define source/destination IPs or networks
- Protocol filtering (TCP/UDP/ICMP/all)
- Port-based filtering
- Inter-VLAN routing rules
- WAN→LAN rules
- LAN→WAN rules
- Action: Accept, Drop, Reject
- Rule prioritization (rule_index)
- Logging per rule

**Rule Components:**
```json
{
  "name": "Block IoT to LAN",
  "enabled": true,
  "action": "drop",
  "protocol": "all",
  "src_networkconf_type": "LAN",
  "src_networkconf_id": "iot-network-id",
  "dst_networkconf_type": "LAN",
  "dst_networkconf_id": "default-network-id",
  "logging": true,
  "rule_index": 2000
}
```

### Firewall Groups ⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/firewallgroup` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/firewallgroup/{_id}` (update)

**Capabilities:**
- Create IP address groups
- Port groups
- IPv6 groups
- Reusable in firewall rules

**Example IP Group:**
```json
{
  "name": "Cloudflare IPs",
  "group_type": "address-group",
  "group_members": [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "104.16.0.0/13"
  ]
}
```

### Port Forwarding ⭐⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/portforward` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/portforward/{_id}` (update/enable/disable)  
**Endpoint:** `DELETE /api/s/{site}/rest/portforward/{_id}` (delete)

**Capabilities:**
- Create port forwards
- Enable/disable existing forwards
- Protocol selection (TCP/UDP/both)
- Port ranges
- Logging

**Example:**
```json
{
  "name": "Web Server",
  "enabled": true,
  "src": "any",
  "dst_port": "443",
  "fwd": "192.168.4.10",
  "fwd_port": "8443",
  "proto": "tcp",
  "log": true
}
```

**Quick Enable/Disable:**
```bash
# Just update the enabled flag
curl -k -X PUT -b cookie.txt \
  --data '{"enabled": false}' \
  https://192.168.4.1/proxy/network/api/s/default/rest/portforward/{rule_id}
```

### IPS/IDS Configuration ⭐⭐⭐

**Endpoint:** `PUT /api/s/{site}/rest/setting/ips/{_id}`

**Capabilities:**
- Enable/disable IPS
- Configure threat categories (37 categories)
- Auto-update mode (auto/manual)
- Signature updates
- Honeypot configuration
- Ad blocking (DNS-based)
- DNS filtering per network
- Endpoint scanning

---

## Traffic & QoS Management

### User Groups (Bandwidth Limits) ⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/usergroup` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/usergroup/{_id}` (update)

**Capabilities:**
- Create bandwidth profiles
- Download/upload limits per client
- QoS priority levels
- Apply to specific clients or networks

### Traffic Rules ⭐⭐

**Endpoint:** `POST /v2/api/site/{site}/trafficrules` (create)  
**Endpoint:** `PUT /v2/api/site/{site}/trafficrules/{id}` (update)  
**Endpoint:** `DELETE /v2/api/site/{site}/trafficrules/{id}` (delete)

**Capabilities:**
- DPI-based traffic shaping
- Application-specific rules
- Content filtering

---

## Switch Configuration

### Port Profiles ⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/portconf` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/portconf/{_id}` (update)

**Capabilities:**
- Create port profiles
- VLAN assignments
- PoE settings (on/off, power limits)
- Port isolation
- Storm control
- Link negotiation
- Port forwarding

---

## RADIUS & Authentication

### RADIUS Profiles ⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/radiusprofile` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/radiusprofile/{_id}` (update)

**Capabilities:**
- Configure RADIUS servers
- 802.1X authentication
- Dynamic VLAN assignment
- Enterprise WiFi

### RADIUS Accounts ⭐⭐

**Endpoint:** `POST /api/s/{site}/rest/account` (create)  
**Endpoint:** `PUT /api/s/{site}/rest/account/{_id}` (update)

**Capabilities:**
- Manage RADIUS user accounts
- Hotspot vouchers
- Guest portal accounts

---

## Guest Portal & Hotspot ⭐⭐

### Hotspot Configuration

**Endpoint:** `PUT /guest/s/{site}/hotspotconfig`

**Capabilities:**
- Enable/disable hotspot
- Captive portal design
- Authentication methods:
  - None (open)
  - Voucher codes
  - Payment gateway
  - Social media login
  - Email/SMS verification
- Terms of service
- Redirect URL
- Session timeout

### Hotspot Packages

**Endpoint:** `POST /guest/s/{site}/hotspotpackages` (create)

**Capabilities:**
- Create time-based access packages
- Bandwidth-limited packages
- Voucher generation

---

## Dynamic DNS ⭐⭐

**Endpoint:** `PUT /api/s/{site}/rest/dynamicdns`

**Capabilities:**
- Configure DDNS providers
- Update DDNS hostnames
- Enable/disable DDNS

---

## Advanced Operations

### DPI Statistics Management ⭐

**Endpoint:** `POST /api/s/{site}/cmd/stat`

| Command | Notes |
|---------|-------|
| `clear-dpi` | Reset all DPI counters |

### Event Management ⭐

**Endpoint:** `POST /api/s/{site}/cmd/evtmgt`

| Command | Notes |
|---------|-------|
| `archive-all-alarms` | Archive all active alarms |

---

## API Patterns & Best Practices

### REST Operations

| Method | Purpose | Returns |
|--------|---------|---------|
| `GET` | Read configuration | 200 + data |
| `POST` | Create new object | 200 + new object |
| `PUT` | Update existing object | 200 + updated object |
| `DELETE` | Delete object | 200 + confirmation |

### Command Pattern

Commands use `POST /api/s/{site}/cmd/{manager}` with JSON body:

```json
{
  "cmd": "command-name",
  "param1": "value1",
  "param2": "value2"
}
```

### Response Format

**Success:**
```json
{
  "data": [...],
  "meta": {"rc": "ok"}
}
```

**Error:**
```json
{
  "data": [],
  "meta": {
    "rc": "error",
    "msg": "api.err.LoginRequired"
  }
}
```

### Important Headers

| Header | Purpose | When Required |
|--------|---------|---------------|
| `Content-Type: application/json` | All requests | Always |
| `Cookie` | Session authentication | After login |
| `X-CSRF-Token` | CSRF protection | System commands (reboot, poweroff) |
| `X-API-KEY` | API key auth (alternative) | If using API key instead of session |

---

## Safety Guidelines

### Critical Operations ⚠️

**Test First:**
1. **Port Forwards** - Incorrect config can expose internal services
2. **Firewall Rules** - Can lock yourself out
3. **Network Changes** - Can disconnect all clients
4. **Device Upgrades** - Can cause downtime
5. **System Reboot** - Interrupts all network traffic

### Best Practices

✅ **DO:**
- Always `GET` before `PUT` to see current config
- Maintain backups before major changes
- Test firewall rules with `logging: true` first
- Use descriptive names for all objects
- Document custom configurations
- Use staging/test VLANs when possible

❌ **DON'T:**
- Delete objects without understanding dependencies
- Modify firewall rules without backup access
- Upgrade firmware during business hours
- Change WAN settings without console access
- Create "allow all" firewall rules from WAN

### Recovery Options

If you lock yourself out:
1. **Local Console Access** - UDM-SE has physical console port
2. **Factory Reset** - Hold reset button for 10+ seconds
3. **Cloud Restore** - Restore from cloud backup
4. **UniFi Hosting** - Access via ui.com if configured

---

## Automation Examples

### Bulk Operations

**Block Multiple Clients:**
```ruby
clients_to_block = ['aa:bb:cc:dd:ee:ff', '11:22:33:44:55:66']
clients_to_block.each do |mac|
  unifi.cmd('stamgr', 'block-sta', {mac: mac})
end
```

**Restart All APs:**
```ruby
devices = unifi.get_devices
aps = devices.select { |d| d['type'] == 'uap' }
aps.each do |ap|
  unifi.cmd('devmgr', 'restart', {mac: ap['mac']})
  sleep 30  # Stagger restarts
end
```

### Scheduled Tasks

**Nightly Backup:**
```bash
#!/bin/bash
# Trigger backup at 2 AM daily
curl -k -X POST -b cookie.txt \
  --data '{"cmd":"backup"}' \
  https://192.168.4.1/proxy/network/api/s/default/cmd/system
```

**Guest WiFi Schedule:**
```json
{
  "schedule": [
    {
      "name": "Business Hours",
      "day_of_week": [1,2,3,4,5],
      "start_hour": 8,
      "start_minute": 0,
      "duration_minutes": 600
    }
  ]
}
```

---

## Comparison: Read-Only vs Read-Write

| Capability | Read-Only | Read-Write |
|------------|-----------|------------|
| View devices/clients | ✅ | ✅ |
| View configuration | ✅ | ✅ |
| Security monitoring | ✅ | ✅ |
| Events/logs | ✅ | ✅ |
| Create VLANs | ❌ | ✅ |
| Modify firewall | ❌ | ✅ |
| Block clients | ❌ | ✅ |
| Update firmware | ❌ | ✅ |
| Reboot devices | ❌ | ✅ |
| Port forwarding | ❌ | ✅ |
| WiFi config | ❌ | ✅ |
| System backup | ❌ | ✅ |
| Adopt new devices | ❌ | ✅ |

---

## Use Cases for Write Access

### Network Automation ⭐⭐⭐
- Auto-adopt new devices
- Batch configuration changes
- Firmware update orchestration
- Network topology changes

### Security Operations ⭐⭐⭐
- Automated threat response (block malicious clients)
- Emergency firewall rule deployment
- Guest network automation
- Quarantine infected devices

### Operations & Maintenance ⭐⭐⭐
- Scheduled backups
- Device health automation (restart on anomalies)
- PoE cycling for stuck devices
- Configuration drift detection/correction

### Client Management ⭐⭐
- Guest WiFi voucher generation
- Bandwidth enforcement
- Parental controls (scheduled access)
- Device naming/organization

### Integration & Orchestration ⭐⭐⭐
- Infrastructure as Code (Terraform)
- CI/CD for network changes
- ChatOps (Slack bot for network control)
- HomeKit/Home Assistant integration
- Voice control ("Alexa, restart the living room AP")

---

## Related Documentation

- [Read-Only Data Catalog](./unifi-api-data-catalog.md)
- [Network Inventory](../network-inventory/network-inventory-2026-02-18.md)
- [Firewall Monitoring Plan](../plans/plan-integrate-unifi-monitoring-eureka-homekit.md)
- [Security Audit Report](../assessments/security-audit-unifi-2026-02-18.md)

---

**Document Status:** Reference  
**Last Updated:** 2026-02-19  
**Maintainer:** AiderDesk  
**API Version:** UniFi Network Application 8.x / UDM-SE Firmware 4.4.6
