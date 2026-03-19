# UniFi Network Infrastructure Inventory
**Generated:** 2026-02-18 17:02:52 CST
**Controller:** UDM SE
**Version:** 10.1.85

---

## Network Overview

| Metric | Count |
|--------|-------|
| **UniFi Devices** | 14 |
| **Connected Clients** | 94 |
| **Wireless Clients** | 62 |
| **Wired Clients** | 32 |
| **Networks (VLANs)** | 7 |
| **Wireless Networks (SSIDs)** | 2 |
| **Port Forwards** | 2 |
| **Firewall Rules** | 0 |

## UniFi Infrastructure Devices

| Name | Type | Model | IP Address | MAC Address | Version | Uptime | Status |
|------|------|-------|------------|-------------|---------|--------|--------|
| South East Side | uap | UKPW | 192.168.4.194 | 28:70:4e:c8:c1:33 | 8.4.6.18068 | 21d 13h 59m | ✅ Online |
| UK Ultra | uap | U7UKU | 192.168.4.193 | 9c:05:d6:76:d3:17 | 6.8.2.15592 | 5d 13h 43m | ✅ Online |
| U7-Pro New | uap | U7PRO | 192.168.4.134 | 9c:05:d6:50:df:f0 | 8.4.6.18068 | 26d 13h 58m | ✅ Online |
| U6-Pro Rack Room | uap | UAP6MP | 192.168.4.178 | ac:8b:a9:57:8a:9d | 6.8.2.15592 | 5d 13h 35m | ✅ Online |
| UK Ultra North Side | uap | U7UKU | 192.168.4.162 | 9c:05:d6:76:d6:17 | 6.8.2.15592 | 5d 13h 28m | ✅ Online |
| U6-LR-1 (Shop) | uap | UALR6v2 | 192.168.4.122 | ac:8b:a9:4a:bc:a5 | 6.7.41.15623 | 5d 13h 37m | ✅ Online |
| U6-LR-3 (Upstairs Bedroom  ) | uap | UALR6v2 | 192.168.4.139 | ac:8b:a9:4a:c9:a1 | 6.7.41.15623 | 5d 13h 47m | ✅ Online |
| U6-Pro Office | uap | UAP6MP | 192.168.4.180 | ac:8b:a9:5c:e9:90 | 6.8.2.15592 | 5d 13h 32m | ✅ Online |
| U6-Pro Master Attic | uap | UAP6MP | 192.168.4.192 | e4:38:83:1f:01:7d | 6.8.2.15592 | 5d 14h | ✅ Online |
| U6-LR-2 (BackYard) | uap | UALR6v2 | 192.168.4.161 | ac:8b:a9:4a:70:3d | 6.7.41.15623 | 5d 13h 53m | ✅ Online |
| UDM SE | udm | UDMPROSE | 104.14.41.31 | 70:a7:41:a0:1b:01 | 4.4.6.27560 | 87d 16h 15m | ✅ Online |
| Switch Pro 24 PoE | usw | US24PRO | 192.168.4.2 | f4:e2:c6:50:1c:15 | 7.2.123.16565 | 123d 14h 50m | ✅ Online |
| Switch Pro 48 | usw | US48PRO2 | 192.168.4.3 | d8:b3:70:60:36:fc | 7.2.123.16565 | 123d 14h 59m | ✅ Online |
| SmartPower PDU Pro | usw | USPPDUP | 192.168.4.196 | d8:b3:70:4a:59:95 | 7.2.123.16565 | 123d 14h 56m | ✅ Online |

## Networks (VLANs)

| Name | Purpose | VLAN ID | Network | DHCP | Domain |
|------|---------|---------|---------|------|--------|
| Internet 1 | wan | N/A | N/A | Disabled | N/A |
| Internet 2 | wan | N/A | N/A | Disabled | N/A |
| Default | corporate | N/A | 192.168.4.1/24 | Enabled | localdomain |
| My WireGuard Server  | remote-user-vpn | N/A | 192.168.3.1/24 | Disabled | N/A |
| My OpenVPN Server  | remote-user-vpn | N/A | 192.168.5.1/24 | Disabled | N/A |
| Span Network | corporate | 2 | 192.168.50.1/24 | Enabled |  |
| Camera Network | corporate | 3 | 192.168.6.1/24 | Enabled |  |

## Wireless Networks (SSIDs)

| SSID | Security | Network | Enabled | Hidden | Guest |
|------|----------|---------|---------|--------|-------|
| TOTALLY_NOT_HAUNTED | wpapsk | 636d1c6e25021519530da547 | Yes | No | No |
| HAUNTED | wpapsk | 636d1c6e25021519530da547 | Yes | No | No |

## Connected Clients Summary

### By Connection Type
- **Wired:** 32
- **Wireless:** 62
- **Guest:** 0

### By Network
- **Default:** 91 clients
- **Span Network:** 3 clients

## Top 20 Clients by Total Bandwidth

| Hostname | IP | MAC | RX | TX | Total | Connection |
|----------|-----|-----|-----|-----|-------|------------|
| g4-instant | 192.168.4.144 | f4:e2:c6:77:35:6f | 85.53 GB | 2.82 GB | 88.36 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| zeta | 192.168.4.168 | 70:a7:41:0f:73:d1 | 82.2 GB | 2.87 GB | 85.07 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| z-garage | 192.168.4.199 | 70:a7:41:0d:76:e7 | 78.5 GB | 2.72 GB | 81.22 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| iPad | 192.168.4.236 | 1a:2d:69:35:7d:d7 | 926.17 MB | 2.64 GB | 3.54 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| eight-pod | 192.168.4.138 | 70:b6:51:02:71:52 | 3.14 GB | 396.3 MB | 3.52 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| iPhone | 192.168.4.232 | 7e:8c:52:6b:51:7f | 131.35 MB | 2.83 GB | 2.96 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| LivingRmHomepod | 192.168.4.60 | d4:a3:3d:75:f4:43 | 1011.41 MB | 1.28 GB | 2.26 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Studio | 192.168.4.61 | d4:90:9c:da:45:eb | 59.61 MB | 1.63 GB | 1.69 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Office | 192.168.4.62 | d4:90:9c:e1:ab:3d | 843.49 MB | 834.09 MB | 1.64 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Master-Bedroom | 192.168.4.66 | d4:a3:3d:72:dc:6f | 595.59 MB | 844.49 MB | 1.41 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Z-Hidden | 192.168.4.59 | a4:cf:99:ab:8d:de | 678.28 MB | 590.13 MB | 1.24 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Samsung | 192.168.4.245 | cc:6e:a4:32:6f:3c | 440.18 MB | 393.12 MB | 833.3 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| Angelas-Air | 192.168.4.137 | 9c:58:84:5c:08:fc | 100.2 MB | 464.71 MB | 564.91 MB | WiFi (HAUNTED) |
| Watch | 192.168.4.191 | ee:62:05:48:68:f3 | 14.88 MB | 524.87 MB | 539.75 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| Kitchen | 192.168.4.64 | 04:99:b9:b5:56:07 | 64.92 MB | 422.7 MB | 487.62 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| Mine2 | 192.168.4.190 | cc:81:7d:88:f8:87 | 40.05 MB | 409.0 MB | 449.05 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| Utility-Room | 192.168.4.52 | 44:61:32:3b:cb:5c | 160.26 MB | 95.09 MB | 255.35 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| Living-Room | 192.168.4.53 | 44:61:32:67:de:6d | 154.81 MB | 94.01 MB | 248.82 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| Master-Suite | 192.168.4.55 | 44:61:32:c7:9d:45 | 147.27 MB | 97.75 MB | 245.02 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| ecobee-ares | 192.168.4.51 | 44:61:32:51:1f:83 | 127.03 MB | 81.19 MB | 208.22 MB | WiFi (TOTALLY_NOT_HAUNTED) |

## Port Forwarding Rules

| Name | Enabled | Protocol | WAN Port | Forward IP | Forward Port |
|------|---------|----------|----------|------------|--------------|
| Notify.Event | ❌ | tcp_udp | 53535 | 192.168.4.10 | 53535 |
| NextGen | ✅ | tcp_udp | 80 | 192.168.4.253 | 80 |

## Firewall Rules Summary

*No firewall rules configured*

---

## Notes

- This inventory was generated automatically via UniFi read-only API
- Sensitive data (passwords, keys) are not included in this report
- For detailed client information, see the JSON export

## Related Documentation

- [DevOps Assessment](../assessments/devops-assessment.md)
- [UniFi Security Audit](../assessments/security-audit-unifi-2026-02-18.md)
- [Network Deployment Strategy](../deployment/deployment-strategy-overview.md)

**Document Status:** Auto-generated  
**Next Update:** Monthly or after major network changes
