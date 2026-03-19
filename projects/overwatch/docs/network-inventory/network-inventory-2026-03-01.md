# UniFi Network Infrastructure Inventory
**Generated:** 2026-03-01 12:22:59 CST
**Controller:** UDM SE
**Version:** 10.1.85

---

## Network Overview

| Metric | Count |
|--------|-------|
| **UniFi Devices** | 14 |
| **Connected Clients** | 91 |
| **Wireless Clients** | 60 |
| **Wired Clients** | 31 |
| **Networks (VLANs)** | 7 |
| **Wireless Networks (SSIDs)** | 2 |
| **Port Forwards** | 3 |
| **Firewall Rules** | 0 |

## UniFi Infrastructure Devices

| Name | Type | Model | IP Address | MAC Address | Version | Uptime | Status |
|------|------|-------|------------|-------------|---------|--------|--------|
| South East Side | uap | UKPW | 192.168.4.194 | 28:70:4e:c8:c1:33 | 8.4.6.18068 | 32d 9h 19m | ✅ Online |
| UK Ultra | uap | U7UKU | 192.168.4.193 | 9c:05:d6:76:d3:17 | 6.8.2.15592 | 16d 9h 4m | ✅ Online |
| U7-Pro New | uap | U7PRO | 192.168.4.134 | 9c:05:d6:50:df:f0 | 8.4.6.18068 | 37d 9h 18m | ✅ Online |
| U6-Pro Rack Room | uap | UAP6MP | 192.168.4.178 | ac:8b:a9:57:8a:9d | 6.8.2.15592 | 16d 8h 55m | ✅ Online |
| UK Ultra North Side | uap | U7UKU | 192.168.4.162 | 9c:05:d6:76:d6:17 | 6.8.2.15592 | 16d 8h 49m | ✅ Online |
| U6-LR-1 (Shop) | uap | UALR6v2 | 192.168.4.122 | ac:8b:a9:4a:bc:a5 | 6.7.41.15623 | 16d 8h 57m | ✅ Online |
| U6-LR-3 (Upstairs Bedroom  ) | uap | UALR6v2 | 192.168.4.139 | ac:8b:a9:4a:c9:a1 | 6.7.41.15623 | 16d 9h 6m | ✅ Online |
| U6-Pro Office | uap | UAP6MP | 192.168.4.180 | ac:8b:a9:5c:e9:90 | 6.8.2.15592 | 16d 8h 52m | ✅ Online |
| U6-Pro Master Attic | uap | UAP6MP | 192.168.4.192 | e4:38:83:1f:01:7d | 6.8.2.15592 | 16d 9h 19m | ✅ Online |
| U6-LR-2 (BackYard) | uap | UALR6v2 | 192.168.4.161 | ac:8b:a9:4a:70:3d | 6.7.41.15623 | 3d 11m | ✅ Online |
| UDM SE | udm | UDMPROSE | 104.14.41.31 | 70:a7:41:a0:1b:01 | 4.4.6.27560 | 98d 11h 35m | ✅ Online |
| Switch Pro 24 PoE | usw | US24PRO | 192.168.4.2 | f4:e2:c6:50:1c:15 | 7.2.123.16565 | 134d 10h 11m | ✅ Online |
| Switch Pro 48 | usw | US48PRO2 | 192.168.4.3 | d8:b3:70:60:36:fc | 7.2.123.16565 | 134d 10h 18m | ✅ Online |
| SmartPower PDU Pro | usw | USPPDUP | 192.168.4.196 | d8:b3:70:4a:59:95 | 7.2.123.16565 | 134d 10h 16m | ✅ Online |

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
- **Wired:** 31
- **Wireless:** 60
- **Guest:** 0

### By Network
- **Default:** 88 clients
- **Span Network:** 3 clients

## Top 20 Clients by Total Bandwidth

| Hostname | IP | MAC | RX | TX | Total | Connection |
|----------|-----|-----|-----|-----|-------|------------|
| eight-pod | 192.168.4.138 | 70:b6:51:02:71:52 | 12.39 GB | 1.54 GB | 13.93 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| LivingRmHomepod | 192.168.4.60 | d4:a3:3d:75:f4:43 | 3.45 GB | 10.46 GB | 13.91 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Kitchen | 192.168.4.64 | 04:99:b9:b5:56:07 | 3.22 GB | 8.49 GB | 11.72 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| zeta | 192.168.4.168 | 70:a7:41:0f:73:d1 | 10.2 GB | 350.7 MB | 10.54 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| g4-instant | 192.168.4.144 | f4:e2:c6:77:35:6f | 10.18 GB | 350.41 MB | 10.52 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| z-garage | 192.168.4.199 | 70:a7:41:0d:76:e7 | 9.96 GB | 358.71 MB | 10.31 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| iPhone | 192.168.4.235 | fe:88:fa:f6:db:48 | 818.27 MB | 5.66 GB | 6.46 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Studio | 192.168.4.61 | d4:90:9c:da:45:eb | 225.79 MB | 4.0 GB | 4.22 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Homepodpoolroom | 192.168.4.68 | 04:99:b9:a9:69:70 | 1.68 GB | 1.85 GB | 3.52 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Office | 192.168.4.62 | d4:90:9c:e1:ab:3d | 1.64 GB | 1.74 GB | 3.39 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Shop | 192.168.4.65 | 04:99:b9:94:2f:18 | 1.85 GB | 1.44 GB | 3.29 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Samsung | 192.168.4.245 | cc:6e:a4:32:6f:3c | 1.67 GB | 1.48 GB | 3.14 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| RealityDevice | 192.168.4.233 | 12:52:b9:64:d0:ae | 174.66 MB | 2.71 GB | 2.88 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Master-Bedroom | 192.168.4.66 | d4:a3:3d:72:dc:6f | 1.13 GB | 1.06 GB | 2.19 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Watch | 192.168.4.163 | 0e:65:12:7a:53:c9 | 38.31 MB | 1.64 GB | 1.68 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| iPad | 192.168.4.236 | 1a:2d:69:35:7d:d7 | 56.22 MB | 1.49 GB | 1.54 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Kitchenette | 192.168.4.63 | 94:ea:32:8b:00:25 | 654.88 MB | 696.66 MB | 1.32 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Angelas-Air | 192.168.4.137 | 9c:58:84:5c:08:fc | 195.89 MB | 907.38 MB | 1.08 GB | WiFi (TOTALLY_NOT_HAUNTED) |
| Utility-Room | 192.168.4.52 | 44:61:32:3b:cb:5c | 609.35 MB | 381.86 MB | 991.21 MB | WiFi (TOTALLY_NOT_HAUNTED) |
| Living-Room | 192.168.4.53 | 44:61:32:67:de:6d | 585.85 MB | 378.6 MB | 964.46 MB | WiFi (TOTALLY_NOT_HAUNTED) |

## Port Forwarding Rules

| Name | Enabled | Protocol | WAN Port | Forward IP | Forward Port |
|------|---------|----------|----------|------------|--------------|
| Notify.Event | ❌ | tcp_udp | 53535 | 192.168.4.10 | 53535 |
| NextGen | ✅ | tcp_udp | 80 | 192.168.4.253 | 80 |
| cloudflare-ssl-tunnel | ✅ | tcp_udp | 443 | 192.168.4.253 | 443 |

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
