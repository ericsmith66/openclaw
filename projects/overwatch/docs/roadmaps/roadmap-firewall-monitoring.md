# Firewall & Network Security Monitoring Roadmap
**Created:** February 18, 2026  
**Context:** [Firewall Security Review](../assessments/firewall-security-review-2026-02-18.md)  
**Status:** PLANNING  
**Goal:** Automated, proactive monitoring of network security posture

---

## Vision

**Objective:** Real-time visibility into network security health with automated alerting for threats, anomalies, and configuration drift.

**Success Criteria:**
- Detect security incidents within 5 minutes
- Alert on firewall rule changes within 1 hour
- Monthly security health reports generated automatically
- Zero manual log review required for normal operations

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Collection Layer                     │
├─────────────────────────────────────────────────────────────┤
│  UniFi Local API          UniFi Cloud API      Syslog/SNMP  │
│  (Real-time data)         (Aggregated stats)   (Events)     │
└──────────────┬────────────────────┬───────────────┬─────────┘
               │                    │               │
               v                    v               v
┌──────────────────────────────────────────────────────────────┐
│                    Processing & Storage                      │
├──────────────────────────────────────────────────────────────┤
│         Time-Series DB          Event Store    Config Store  │
│         (InfluxDB/              (PostgreSQL/   (Git/         │
│          Prometheus)            File)          JSON)         │
└──────────────┬───────────────────────────────────────────────┘
               │
               v
┌──────────────────────────────────────────────────────────────┐
│                    Analysis & Alerting                       │
├──────────────────────────────────────────────────────────────┤
│    Threat Detection      Anomaly Detection    Drift Detection│
│    (IPS alerts)          (ML/Rule-based)      (Config diff)  │
└──────────────┬───────────────────────────────────────────────┘
               │
               v
┌──────────────────────────────────────────────────────────────┐
│                  Visualization & Reporting                   │
├──────────────────────────────────────────────────────────────┤
│    Grafana Dashboard     Slack/Email Alerts  Monthly Reports │
└──────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Foundation (Week 1-2)

### Objective: Basic monitoring infrastructure + daily health checks

### 1.1 Ruby Monitoring Scripts (Week 1)

**Create Core Scripts:**

#### A. `unifi-daily-health.rb`
**Purpose:** Daily health check and report generation

**Collects:**
- Firmware versions (UDM, APs, switches)
- Device status (online/offline, uptime)
- Client counts (wired/wireless)
- IPS alert summary (last 24h)
- Backup status (last successful backup)
- Port forward changes
- Network changes

**Output:**
- JSON health report
- Markdown summary
- Email/Slack notification if issues detected

**Schedule:** 8 AM daily (cron)

---

#### B. `unifi-firewall-monitor.rb`
**Purpose:** Monitor IPS/IDS alerts and firewall events

**Collects:**
- IPS alerts (blocked threats)
- Firewall rule violations
- Anomalous traffic patterns
- Denied connection attempts by source

**Output:**
- Real-time alerts (Slack/email)
- Daily digest
- Weekly threat report

**Schedule:** Every 5 minutes

---

#### C. `unifi-config-audit.rb`
**Purpose:** Track configuration changes

**Monitors:**
- Firewall rules added/removed/modified
- Port forwards changed
- Network configuration changes
- DNS filter changes
- IPS category changes

**Output:**
- Git commit of config snapshots
- Change notification (Slack/email)
- Diff report showing what changed

**Schedule:** Hourly

---

#### D. `unifi-firmware-checker.rb`
**Purpose:** Track available firmware updates (uses cloud API)

**Endpoint:** `https://api.ui.com/ea/hosts`

**Checks:**
- Current firmware version
- Available firmware version
- Release notes
- Critical security updates

**Output:**
- Alert when critical updates available
- Monthly update summary

**Schedule:** Daily at 9 AM

---

#### E. `unifi-internet-health.rb`
**Purpose:** Monitor WAN connectivity and performance (uses cloud API)

**Endpoint:** `https://api.ui.com/ea/hosts` → `reportedState.internetIssues5min`

**Tracks:**
- WAN uptime/downtime events
- Internet connectivity issues (5-min granularity)
- ISP performance metrics
- Failover events (if dual-WAN)

**Output:**
- Real-time downtime alerts
- Monthly uptime report (SLA tracking)
- ISP performance trends

**Schedule:** Every 5 minutes

---

### 1.2 Data Storage (Week 1)

**Option A: Simple File-Based (Start Here)**
```bash
/Users/ericsmith66/monitoring/unifi/
├── health-reports/
│   ├── 2026-02-18-health.json
│   ├── 2026-02-18-health.md
│   └── ...
├── ips-alerts/
│   ├── 2026-02-18-alerts.json
│   └── ...
├── config-snapshots/
│   ├── 2026-02-18-config.json
│   └── ...
└── logs/
    └── monitoring.log
```

**Option B: Database (Later)**
- PostgreSQL for events/alerts
- InfluxDB for time-series metrics

---

### 1.3 Notification Setup (Week 2)

#### Slack Integration
**Webhook Setup:**
```bash
# Store in macOS Keychain
security add-generic-password \
  -a "unifi-monitoring" \
  -s "SLACK_WEBHOOK_URL" \
  -w "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

**Channels:**
- `#network-alerts` - Real-time critical alerts
- `#network-health` - Daily health reports
- `#network-changes` - Configuration changes

#### Email Fallback
**SMTP Configuration:**
- Use local mail relay or SendGrid API
- Send to: ericsmith66@me.com
- Priority levels: Critical, Warning, Info

---

### 1.4 Scheduling (Week 2)

**macOS LaunchAgents:**

Create: `~/Library/LaunchAgents/com.overwatch.unifi-health.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.overwatch.unifi-health</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/ruby</string>
        <string>/Users/ericsmith66/development/agent-forge/projects/overwatch/scripts/unifi-daily-health.rb</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>8</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/ericsmith66/monitoring/unifi/logs/health-daily.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/ericsmith66/monitoring/unifi/logs/health-daily.error.log</string>
</dict>
</plist>
```

**Load:**
```bash
launchctl load ~/Library/LaunchAgents/com.overwatch.unifi-health.plist
```

---

## Phase 2: Real-Time Monitoring (Week 3-4)

### Objective: Continuous threat monitoring with automated response

### 2.1 IPS Alert Processing

**Real-Time Alert Handler:**
```ruby
# scripts/unifi-ips-monitor.rb (runs every 5 minutes)
- Fetch recent IPS alerts
- Classify by severity (critical, high, medium, low)
- Check against known false positives
- Alert on critical threats
- Log all alerts to database
```

**Alert Classification:**
| Severity | Categories | Action |
|----------|------------|--------|
| **Critical** | botcc, compromised, malicious-hosts | Immediate Slack alert + email |
| **High** | emerging-malware, emerging-exploit | Slack alert, email digest |
| **Medium** | emerging-scan, emerging-dos | Daily digest only |
| **Low** | emerging-games, tor | Weekly report only |

---

### 2.2 Anomaly Detection

**Behavioral Baselines:**

**A. Traffic Volume Baselines**
```
Establish normal ranges:
- Total bandwidth per hour (by time of day)
- Client count (wired/wireless)
- Connections per client
- DNS queries per hour
```

**Alert Triggers:**
- Traffic 200% above baseline
- Sudden spike in client connections
- Unusual DNS query volume (possible C2)
- New device with high bandwidth

**B. Network Behavior**
```
Monitor for:
- New clients on unexpected networks
- Port scanning (connections to many ports)
- Repeated failed authentication
- Devices talking to unexpected IPs
```

---

### 2.3 Configuration Drift Detection

**Track Changes:**
- Firewall rules (add/remove/modify)
- Port forwards (new forwards, enabled/disabled)
- Network configuration (VLAN changes, DHCP ranges)
- IPS categories (enabled/disabled)
- DNS filter settings

**Git-Based Tracking:**
```bash
# Store daily snapshots in git
cd /Users/ericsmith66/monitoring/unifi/config-history
git add .
git commit -m "Daily config snapshot: $(date)"

# On change detection:
git diff HEAD~1..HEAD > /tmp/config-changes.diff
# Send diff in alert
```

---

## Phase 3: Advanced Analytics (Week 5-8)

### Objective: Predictive insights and trend analysis

### 3.1 Machine Learning Anomaly Detection

**Use Case:** Detect unusual patterns without explicit rules

**Approach:**
```
1. Collect 30 days of baseline data
2. Train model on normal behavior:
   - Bandwidth patterns
   - Connection patterns
   - Device behavior
3. Flag statistical outliers (> 3 sigma)
4. Refine model based on false positives
```

**Tools:**
- Python scikit-learn (isolation forest)
- Ruby integration via subprocess
- Store models in `/monitoring/models/`

---

### 3.2 Threat Intelligence Integration

**External Feeds:**
- **AbuseIPDB** - Check IPs against known bad actors
- **AlienVault OTX** - Threat intelligence platform
- **GreyNoise** - Benign scanner classification

**Integration:**
```ruby
# scripts/unifi-threat-intel.rb
- Extract unique IPs from IPS alerts
- Query threat intel APIs
- Enrich alerts with context
- Flag high-confidence threats
```

---

### 3.3 Visualization Dashboard

**Grafana Setup:**

**Panels:**
1. **Network Health**
   - Device status (online/offline)
   - Client count over time
   - Bandwidth usage (top 10 clients)

2. **Security Metrics**
   - IPS alerts per hour
   - Alert distribution by category
   - Top blocked IPs
   - Firewall denied connections

3. **ISP Performance**
   - WAN uptime percentage
   - Internet issues over time
   - Latency/packet loss (if available)

4. **Firmware Status**
   - Devices with updates available
   - Days since last update
   - Version distribution

**Access:**
```
http://grafana.local:3001
or
https://grafana.yourdomain.com (via Cloudflare Tunnel)
```

---

## Phase 4: Automated Response (Week 9-12)

### Objective: Auto-remediation for common threats

### 4.1 Automated Blocking

**IP Blacklist Management:**
```ruby
# On critical threat detection:
1. Add IP to firewall block list
2. Set expiration (24 hours default)
3. Log action
4. Alert admin
5. Auto-remove after expiration
```

**Criteria for Auto-Block:**
- Multiple failed VPN auth attempts (> 5 in 1 hour)
- Repeated IPS alerts from same IP (> 10 in 1 hour)
- Port scanning detected (> 100 ports in 5 minutes)
- Known botnet C2 IP

---

### 4.2 Auto-Remediation Rules

| Condition | Action | Notification |
|-----------|--------|--------------|
| Device offline > 10 min | Attempt reboot via API | Slack warning |
| Backup failure 2 days | Trigger manual backup | Email alert |
| Firmware critical update | Create reminder ticket | Daily reminder until updated |
| Certificate expiring < 30 days | Generate renewal notice | Email weekly countdown |

---

### 4.3 Incident Response Playbooks

**Automated Runbooks:**

**A. Suspected Compromise**
```
1. Isolate device (move to quarantine VLAN)
2. Block device MAC at switch
3. Capture traffic sample
4. Alert admin
5. Create incident ticket
```

**B. DDoS Detection**
```
1. Identify attack source IPs
2. Add to temporary block list
3. Rate limit remaining traffic
4. Alert ISP if volumetric
5. Log all actions
```

**C. Malware C2 Detection**
```
1. Block outbound to C2 IP
2. Identify infected device
3. Quarantine device
4. Alert admin
5. Create remediation ticket
```

---

## Phase 5: Reporting & Compliance (Week 13+)

### Objective: Executive visibility and audit readiness

### 5.1 Automated Reports

#### Daily Health Report
**Recipients:** Admin (Slack)
**Content:**
- System status (green/yellow/red)
- New alerts summary
- Device status changes
- Bandwidth top 5

#### Weekly Security Digest
**Recipients:** Admin (Email)
**Content:**
- Total IPS alerts (by severity)
- Top blocked threats
- Configuration changes
- Anomalies detected
- Recommendations

#### Monthly Executive Report
**Recipients:** Stakeholders (Email)
**Content:**
- Network uptime (SLA)
- Security posture score
- Threat landscape summary
- Firmware update status
- Capacity planning insights
- Budget impacts (if applicable)

---

### 5.2 Compliance Tracking

**Audit Logs:**
- All configuration changes (who, what, when)
- All firewall rule changes
- All admin access (SSH, Web UI, API)
- All blocked threats

**Retention:**
- 90 days (hot storage)
- 1 year (cold storage / S3)
- 7 years (compliance archive)

**Reports:**
- PCI-DSS compliance report (if applicable)
- NIST CSF alignment report
- CIS Controls scorecard

---

## Technology Stack

### Recommended Tools

| Component | Tool | Reason |
|-----------|------|--------|
| **Scripting** | Ruby | Already in use, good libraries |
| **Time-Series DB** | InfluxDB | Native time-series, easy Grafana integration |
| **Event Storage** | PostgreSQL | Reliable, queryable, ACID compliant |
| **Visualization** | Grafana | Industry standard, beautiful dashboards |
| **Alerting** | Grafana Alertmanager | Built-in, flexible rules |
| **Log Aggregation** | Loki | Lightweight, integrates with Grafana |
| **Threat Intel** | AbuseIPDB API | Free tier, good coverage |
| **ML/Analytics** | Python (scikit-learn) | Best ML ecosystem |
| **Scheduling** | macOS LaunchAgents | Native, reliable |
| **Version Control** | Git | Config drift tracking |

### Infrastructure Requirements

**Development Machine (M3 Ultra):**
- Ruby 3.3+ ✅ (already have)
- PostgreSQL (brew install postgresql@16)
- InfluxDB (brew install influxdb)
- Grafana (brew install grafana)
- Loki (brew install loki)

**Storage:**
- ~10 GB for 90 days of data
- ~50 GB for 1 year archive

**Network:**
- Minimal impact (API calls every 5 min)
- ~1 MB/day data collection

---

## Implementation Timeline

| Week | Phase | Deliverable |
|------|-------|-------------|
| **1** | Foundation | Core Ruby scripts created |
| **2** | Foundation | Scheduling + notifications working |
| **3** | Real-Time | IPS monitoring + alerts live |
| **4** | Real-Time | Anomaly detection operational |
| **5** | Analytics | 30-day baseline collected |
| **6** | Analytics | ML model trained + deployed |
| **7** | Analytics | Grafana dashboard live |
| **8** | Analytics | Threat intel integration |
| **9** | Response | Auto-blocking implemented |
| **10** | Response | Remediation playbooks tested |
| **11** | Response | Incident response automation |
| **12** | Reporting | All reports automated |
| **13+** | Maintenance | Tune, optimize, expand |

---

## Success Metrics

### Operational Metrics
- **MTTD** (Mean Time To Detect): < 5 minutes for critical threats
- **MTTR** (Mean Time To Respond): < 1 hour for high-severity incidents
- **False Positive Rate**: < 5% of alerts
- **Uptime**: 99.9% monitoring availability

### Security Metrics
- **Threats Detected**: Baseline + trending
- **Threats Blocked**: 100% of detections
- **Configuration Changes**: 100% tracked
- **Audit Compliance**: 100% of requirements met

### Business Metrics
- **Manual Effort Reduction**: 90% (vs. manual log review)
- **Incident Detection Improvement**: 300% faster than manual
- **Admin Time Saved**: 10 hours/month

---

## Risk Mitigation

### Monitoring Failures

**Risk:** Monitoring system goes down, blind to threats

**Mitigation:**
- Health check for monitoring scripts (monitor the monitor)
- Slack alert if no health report received
- Fallback to email
- Redundant scheduling (cron + LaunchAgent)

### False Positives

**Risk:** Too many alerts, alert fatigue

**Mitigation:**
- Severity-based thresholds
- Known false positive whitelist
- ML-based refinement over time
- Weekly tuning reviews

### Performance Impact

**Risk:** Monitoring consumes too many resources

**Mitigation:**
- Rate limiting on API calls
- Efficient queries (fetch only what's needed)
- Background processing (don't block)
- Resource monitoring for scripts

---

## Cost Analysis

### Time Investment
- **Initial Setup:** 40-60 hours (spread over 12 weeks)
- **Ongoing Maintenance:** 2-4 hours/month
- **Break-Even:** After 3 months (vs. manual monitoring)

### Financial Cost
- **Software:** $0 (all open source)
- **Infrastructure:** $0 (runs on existing M3 Ultra)
- **APIs:** $0-50/month (depending on usage)

**Total:** Essentially free (labor only)

---

## Next Steps

1. **Review & Prioritize** - Which phases to implement?
2. **Quick Win:** Create `unifi-daily-health.rb` first (1 day effort)
3. **Schedule Demo** - Show daily health report in Slack
4. **Iterate** - Add features based on value

---

## Related Documentation

- [Firewall Security Review](../assessments/firewall-security-review-2026-02-18.md)
- [Network Inventory](../network-inventory/network-inventory-2026-02-18.md)
- [DevOps Assessment](../assessments/devops-assessment.md)
- [Roadmap: Environment](roadmap-environment.md)

---

**Document Status:** Ready for Implementation  
**Next Review:** After Phase 1 completion  
**Owner:** Eric Smith
