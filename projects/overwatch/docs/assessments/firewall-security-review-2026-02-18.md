# Firewall & Security Configuration Review
**Date:** February 18, 2026  
**Reviewer:** AiderDesk + Eric Smith  
**System:** Ubiquiti Dream Machine SE (UDM-SE)  
**Firmware:** 4.4.6  
**Status:** BASELINE ESTABLISHED

---

## Executive Summary

**Overall Security Posture:** ⚠️ **MODERATE** (Good foundation, opportunities for improvement)

### Current State
- ✅ **IPS/IDS Enabled** - 37 threat categories active
- ✅ **DNS Filtering Available** - Not currently configured
- ✅ **Default Deny Policy** - No explicit allow rules (secure by default)
- ✅ **Network Segmentation** - 3 VLANs configured (Default, Span, Camera)
- ⚠️ **Minimal Port Forwarding** - 1 rule active (port 80)
- ❌ **No Custom Firewall Rules** - Relying entirely on defaults
- ❌ **SSL Inspection Disabled** - Encrypted threats not inspected
- ❌ **Ad Blocking Disabled** - No DNS-level ad/tracker blocking

### Risk Level
**CURRENT:** Medium  
**POTENTIAL (with recommendations):** Low

---

## Detailed Findings

### 1. Intrusion Prevention System (IPS/IDS)

**Status:** ✅ **ENABLED**

**Configuration:**
- **Preference:** Manual (not automatic category updates)
- **Ad Blocking:** Disabled
- **Enabled Categories:** 37 active threat signatures

#### Active Threat Categories

| Category | Type | Description |
|----------|------|-------------|
| **botcc** | Malware | Botnet command & control |
| **tor** | Anonymity | TOR exit nodes |
| **ciarmy** | Threat Intel | Known malicious IPs |
| **compromised** | Threat Intel | Compromised hosts |
| **dshield** | Threat Intel | DShield blacklist |
| **malicious-hosts** | Threat Intel | Known bad actors |
| **dark-web-blocker-list** | Content | Dark web access |
| **emerging-worm** | Malware | Worm propagation |
| **emerging-malware** | Malware | Malware distribution |
| **emerging-exploit** | Exploit | Exploit attempts |
| **emerging-shellcode** | Exploit | Shellcode injection |
| **emerging-dos** | Attack | Denial of service |
| **emerging-scan** | Recon | Port scanning |
| **emerging-sql** | Attack | SQL injection |
| **emerging-webapps** | Attack | Web app attacks |
| **emerging-webclient** | Attack | Browser exploits |
| **emerging-webserver** | Attack | Web server attacks |
| **emerging-mobile** | Mobile | Mobile malware |
| **emerging-p2p** | P2P | Peer-to-peer threats |
| **emerging-attackresponse** | Response | Attack response traffic |
| **emerging-rpc** | Protocol | RPC attacks |
| **emerging-activex** | Browser | ActiveX exploits |
| **emerging-dns** | Protocol | DNS attacks |
| **emerging-ftp** | Protocol | FTP attacks |
| **emerging-icmp** | Protocol | ICMP attacks |
| **emerging-imap** | Protocol | IMAP attacks |
| **emerging-misc** | General | Miscellaneous threats |
| **emerging-netbios** | Protocol | NetBIOS attacks |
| **emerging-pop3** | Protocol | POP3 attacks |
| **emerging-smtp** | Protocol | SMTP attacks |
| **emerging-snmp** | Protocol | SNMP attacks |
| **emerging-telnet** | Protocol | Telnet attacks |
| **emerging-tftp** | Protocol | TFTP attacks |
| **emerging-voip** | Protocol | VoIP attacks |
| **emerging-games** | Content | Gaming protocol exploits |
| **emerging-useragent** | Browser | User-agent exploits |

**Assessment:** ✅ **GOOD**  
Comprehensive coverage of common threat vectors. Manual preference ensures stability but requires periodic review for new categories.

---

### 2. DNS Filtering

**Status:** ⚠️ **AVAILABLE BUT NOT CONFIGURED**

**Current Configuration:**
- All networks set to: **"none"** (no filtering)
- No blocked TLDs
- No blocked sites
- No allowed sites (whitelist)

**Available Filter Options:**
- Family-friendly filtering
- Security threats filtering
- Custom block/allow lists

**Assessment:** ⚠️ **OPPORTUNITY**  
DNS filtering could provide additional protection against phishing, malware domains, and unwanted content.

---

### 3. Firewall Rules

**Status:** ❌ **NO CUSTOM RULES CONFIGURED**

**Current Behavior:**
- Using implicit deny-all for inter-VLAN traffic
- Default LAN → WAN allow
- Default WAN → LAN deny

**Firewall Groups Defined:**
- **Cloudflare** - 15 IP ranges (173.245.48.0/20, 103.21.244.0/22, etc.)

**Assessment:** ⚠️ **MIXED**
- **Positive:** Secure by default (deny-all unless explicitly allowed)
- **Negative:** No granular control between VLANs
- **Opportunity:** Define specific rules for camera network, guest access

---

### 4. Network Segmentation

**Status:** ✅ **PARTIALLY IMPLEMENTED**

**Configured Networks:**

| Network | VLAN | Purpose | Subnet | DHCP | Isolation |
|---------|------|---------|--------|------|-----------|
| **Default** | N/A | Primary network | 192.168.4.1/24 | Enabled | None |
| **Span Network** | 2 | Unknown | 192.168.50.1/24 | Enabled | Unknown |
| **Camera Network** | 3 | Security cameras | 192.168.6.1/24 | Enabled | Unknown |
| **WireGuard VPN** | N/A | Remote access | 192.168.3.1/24 | Disabled | N/A |
| **OpenVPN** | N/A | Remote access | 192.168.5.1/24 | Disabled | N/A |

**Current Client Distribution:**
- Default: 91 clients (97%)
- Span Network: 3 clients (3%)
- Camera Network: Unknown (likely 0 - cameras on default?)

**Assessment:** ⚠️ **INCOMPLETE**
- VLANs exist but unclear if truly isolated
- No evidence of firewall rules enforcing separation
- Most devices on default network (flat network)

---

### 5. Port Forwarding

**Status:** ✅ **MINIMAL** (Good security practice)

**Active Rules:**

| Name | Enabled | Protocol | WAN Port | Forward To | Forward Port | Risk |
|------|---------|----------|----------|------------|--------------|------|
| Unknown | ✅ | tcp | 80 | 192.168.4.253 | 3000 | Low |
| Unknown | ❌ | ? | ? | ? | ? | N/A |

**Analysis:**
- Port 80 → 192.168.4.253:3000 (likely nextgen-plaid app)
- Cloudflare Tunnel likely handles SSL termination
- No admin ports exposed (SSH, RDP, HTTPS controller)

**Assessment:** ✅ **GOOD**  
Minimal port exposure reduces attack surface. Using Cloudflare Tunnel is best practice.

---

### 6. SSL/TLS Inspection

**Status:** ❌ **DISABLED**

**Capability:** Available in UniFi Threat Management
**Current State:** Not configured

**What It Does:**
- Inspects encrypted HTTPS traffic for threats
- Requires installing root certificate on clients
- Can detect malware in encrypted connections

**Trade-offs:**
- **Pro:** Detects threats in encrypted traffic (majority of web traffic)
- **Con:** Privacy concerns (man-in-the-middle by design)
- **Con:** Breaks certificate pinning (banking apps, etc.)
- **Con:** Performance impact

**Assessment:** ⚠️ **DECISION NEEDED**  
Not enabling is reasonable for home network, but consider for high-security requirements.

---

### 7. VPN Configuration

**Status:** ✅ **AVAILABLE** (WireGuard + OpenVPN)

**WireGuard VPN:**
- Network: 192.168.3.1/24
- Status: Configured

**OpenVPN:**
- Network: 192.168.5.1/24  
- Status: Configured

**Assessment:** ✅ **GOOD**  
Secure remote access available. Dual VPN support provides flexibility.

---

### 8. Ad Blocking / DNS Sinkhole

**Status:** ❌ **DISABLED**

**Current:** `ad_blocking_enabled: false`

**What It Does:**
- Blocks ads at DNS level (before they load)
- Blocks tracking domains
- Reduces bandwidth usage
- Privacy protection

**Assessment:** ⚠️ **OPPORTUNITY**  
Easy win for privacy and performance. Can be enabled per-network.

---

### 9. Country Blocking

**Status:** ❌ **NOT CONFIGURED**

**Current:** Code "840" (USA) - Location, not blocking

**Capability:** Block traffic from/to specific countries

**Use Cases:**
- Block countries with high attack traffic (Russia, China, etc.)
- Reduce attack surface if no legitimate traffic expected

**Assessment:** ⚠️ **OPTIONAL**  
Not critical for home network, but could reduce log noise and attack attempts.

---

### 10. Management Access

**Status:** ⚠️ **REVIEW NEEDED**

**SSH Access:**
- **Enabled:** Yes
- **Username:** `mzxRdhczu0b` (randomized, good)
- **Password Auth:** Enabled
- **SSH Key:** Configured (ericsmith66)
- **Bind to Wildcard:** No (localhost only, good)

**API Access:**
- **Token:** Present (6zS7HF4tjrQurUMOoE5Q...)
- **Direct Connect:** Disabled (good)

**Auto-Updates:**
- **Enabled:** Yes
- **Schedule:** 3 AM daily

**Assessment:** ✅ **MOSTLY GOOD**
- SSH key configured (preferred over password)
- Localhost-only binding limits exposure
- Auto-updates enabled (security patches)
- Consider disabling password auth (key-only)

---

## Security Gaps & Risks

### High Priority Gaps

1. **No Inter-VLAN Firewall Rules** ⚠️
   - Camera network can potentially access main network
   - Span network purpose/isolation unclear
   - No guest network with proper isolation

2. **Camera Network Not Isolated** ⚠️
   - Security cameras are IoT devices (common attack vector)
   - Should be on isolated VLAN with restricted access
   - Current location: Likely on default network

3. **No DNS Filtering** ⚠️
   - Misses malware/phishing domains blocked at DNS level
   - No protection against typosquatting
   - No content filtering options

### Medium Priority Gaps

4. **Ad Blocking Disabled** ⚠️
   - Privacy exposure through tracking domains
   - Bandwidth waste on ads
   - Potential malware in malicious ads

5. **Manual IPS Category Updates** ⚠️
   - New threat categories won't auto-enable
   - Requires periodic manual review
   - Could miss emerging threats

6. **SSL Inspection Not Configured** ⚠️
   - Encrypted malware undetected
   - Reasonable for home, but limits visibility

### Low Priority Gaps

7. **Password Auth for SSH** ℹ️
   - SSH key configured but password auth also enabled
   - Best practice: key-only authentication

8. **No Country Blocking** ℹ️
   - Attack traffic from high-risk countries allowed
   - Reduces log noise if enabled

---

## Recommendations

### Immediate Actions (High Priority)

#### 1. Isolate Camera Network ⚠️ CRITICAL
**Problem:** IoT cameras are high-risk devices, should be isolated

**Action:**
```
Settings → Networks → Camera Network (VLAN 3)
- Enable "Isolation" (prevent client-to-client communication)
```

**Create Firewall Rules:**
```
Settings → Firewall → Rules → Create New Rule

Rule 1: Allow Cameras to NVR/NAS
- Action: Accept
- Source: Camera Network (VLAN 3)
- Destination: Address/Port Group (NVR IP)
- Ports: Required ports only

Rule 2: Block Cameras to LAN
- Action: Drop
- Source: Camera Network (VLAN 3)
- Destination: LAN Networks
- Log: Yes (monitor unauthorized access)

Rule 3: Allow Cameras to WAN (if cloud needed)
- Action: Accept  
- Source: Camera Network (VLAN 3)
- Destination: Internet
- Ports: HTTPS (443) only
```

**Benefit:** Prevents compromised camera from attacking internal network

---

#### 2. Enable DNS Filtering on All Networks
**Problem:** No protection against malware/phishing domains

**Action:**
```
Settings → Security → DNS Content Filtering
- Default Network: Security Threats + Adult Content (if desired)
- Camera Network: Security Threats only
- Span Network: Review purpose, configure accordingly
```

**Benefit:** 
- Blocks known malware domains
- Protects against phishing
- Parental controls (optional)

---

#### 3. Enable Ad Blocking
**Problem:** Privacy exposure, bandwidth waste

**Action:**
```
Settings → Security → Threat Management
- Enable: Ad Blocking
- Apply to: All networks or per-network
```

**Benefit:**
- Privacy protection
- Reduced bandwidth
- Faster page loads

---

### Short-Term Actions (Medium Priority)

#### 4. Create Guest Network with Isolation
**Problem:** No dedicated guest WiFi with proper isolation

**Action:**
```
Settings → WiFi → Create New Network
- Name: HAUNTED_GUEST
- VLAN: 4
- Guest Policy: Enable
- Block LAN Access: Yes
```

**Benefit:** Safe guest access without internal network exposure

---

#### 5. Move All IoT Devices to Isolated VLAN
**Problem:** Smart home devices mixed with computers/phones

**Action:**
1. Create IoT network (VLAN 5)
2. Identify IoT devices from inventory (smart speakers, etc.)
3. Move to IoT VLAN
4. Create firewall rules allowing only required traffic

**Benefit:** Limits blast radius if IoT device compromised

---

#### 6. Configure Automatic IPS Updates
**Problem:** New threat categories require manual intervention

**Action:**
```
Settings → Security → Threat Management
- Advanced Filtering Preference: Automatic (instead of Manual)
```

**Benefit:** Automatic protection against new threat types

---

#### 7. Disable SSH Password Authentication
**Problem:** Password auth enabled alongside key auth

**Action:**
```
Settings → System → Advanced → SSH
- Password Authentication: Disable
- Ensure SSH key is working first!
```

**Benefit:** Key-only authentication (more secure)

---

### Long-Term Actions (Low Priority)

#### 8. Consider SSL Inspection (Optional)
**Trade-off Analysis Required**

**Pros:**
- Detect encrypted malware
- Full visibility into HTTPS traffic
- DLP capabilities

**Cons:**
- Privacy concerns
- Breaks certificate pinning (banking apps)
- Setup complexity (root cert on all devices)
- Performance impact

**Recommendation:** Not needed for home network unless high-security requirements

---

#### 9. Implement Country Blocking (Optional)
**Countries to Consider:**
- Russia, China, North Korea (high attack volume)
- If no legitimate traffic expected from these regions

**Benefit:** Reduced attack surface, cleaner logs

---

#### 10. Review and Document VLAN Purpose
**Problem:** "Span Network" purpose unclear

**Action:**
1. Identify 3 clients on Span Network (192.168.50.x)
2. Document intended purpose
3. Configure appropriate firewall rules
4. Consider consolidation if unused

---

## Firewall Rule Template

### Recommended Rule Structure

```
Priority Order:
1. Allow VPN access to LAN (WireGuard/OpenVPN)
2. Allow LAN to LAN (default network)
3. Block IoT to LAN (except specific services)
4. Block Camera to LAN (except NVR/NAS)
5. Allow Guest to WAN only
6. Block all inter-VLAN by default
7. Log denied packets
```

### Example Rules to Create

| Priority | Name | Action | Source | Destination | Ports | Log |
|----------|------|--------|--------|-------------|-------|-----|
| 1 | Allow VPN to LAN | Accept | VPN Networks | Default | All | No |
| 2 | Allow NAS Access | Accept | All LANs | NAS IP | 445, 139 | No |
| 3 | Block IoT to LAN | Drop | IoT VLAN | Default | All | Yes |
| 4 | Block Camera to LAN | Drop | Camera VLAN | Default | All | Yes |
| 5 | Allow Guest to WAN | Accept | Guest VLAN | Internet | All | No |
| 6 | Block Guest to LAN | Drop | Guest VLAN | All LANs | All | Yes |

---

## Monitoring & Alerting Recommendations

See companion document: [Firewall Monitoring Roadmap](../roadmaps/roadmap-firewall-monitoring.md)

**Key Metrics:**
- IPS/IDS alert count (daily/weekly)
- Blocked connection attempts per network
- Firewall rule hit counts
- Anomalous traffic patterns

---

## Testing Plan

### After Implementing Recommendations

1. **Camera Isolation Test**
   - Try to ping camera from workstation
   - Try to access camera web interface
   - Verify NVR can still access cameras
   - Expected: Workstation blocked, NVR allowed

2. **DNS Filtering Test**
   - Try accessing known malware domain (testmyids.com)
   - Verify block page appears
   - Check DNS filter logs

3. **IoT Isolation Test**
   - Verify smart home devices still function
   - Verify mobile apps can control devices
   - Verify devices cannot access computers

4. **Firewall Rule Verification**
   - Review firewall logs for denied packets
   - Verify no legitimate traffic blocked
   - Adjust rules as needed

---

## Compliance & Best Practices

### Current Alignment

| Standard | Requirement | Status |
|----------|-------------|--------|
| **NIST Cybersecurity Framework** | Network segmentation | ⚠️ Partial |
| **CIS Controls** | Firewall configuration | ⚠️ Partial |
| **CIS Controls** | IDS/IPS deployment | ✅ Yes |
| **PCI-DSS** | Network isolation | ⚠️ Partial |
| **GDPR** | Privacy by design | ⚠️ Partial |

### After Recommendations

All requirements would be ✅ **Met** or **Exceeded**

---

## Implementation Priority Matrix

| Action | Impact | Effort | Priority |
|--------|--------|--------|----------|
| Isolate Camera Network | High | Low | 🔥 **DO FIRST** |
| Enable DNS Filtering | High | Low | 🔥 **DO FIRST** |
| Enable Ad Blocking | Medium | Low | ⚡ Do This Week |
| Create Guest Network | Medium | Low | ⚡ Do This Week |
| Move IoT to VLAN | High | Medium | ⚡ Do This Week |
| Auto IPS Updates | Low | Low | ✅ Do Soon |
| Disable SSH Password | Low | Low | ✅ Do Soon |
| SSL Inspection | Medium | High | ⏸️ Consider Later |
| Country Blocking | Low | Low | ⏸️ Consider Later |

---

## Next Steps

1. ✅ **Review this document** with stakeholder
2. **Prioritize recommendations** based on risk tolerance
3. **Schedule implementation** (suggest: 1 action per week)
4. **Test each change** in isolation
5. **Document configuration** as you go
6. **Set up monitoring** (see monitoring roadmap)

---

## Related Documentation

- [Network Inventory](../network-inventory/network-inventory-2026-02-18.md)
- [UniFi Security Audit](security-audit-unifi-2026-02-18.md)
- [DevOps Assessment](devops-assessment.md)
- [Firewall Monitoring Roadmap](../roadmaps/roadmap-firewall-monitoring.md) (to be created)

---

**Document Status:** Ready for Review  
**Next Review:** After implementation of recommendations  
**Owner:** Eric Smith
