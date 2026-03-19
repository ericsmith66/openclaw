# Network IP Assignment Scheme
## 192.168.4.0/24 Network

Generated: 2026-03-13

---

## Recommended IP Assignment Structure

### Infrastructure (192.168.4.1-19)
**Critical network infrastructure, gateways, bridges**

| IP Range | Device Type | Current Issues | Recommendation |
|----------|-------------|----------------|----------------|
| .1 | Gateway/Router (UniFi) | ✓ Correct | Keep |
| .2-3 | Reserved for additional routers/gateways | | |
| .4 | UniFi NVR Pro | ✓ Good location | Keep |
| .9-10 | Lutron Bridges + Homebridge | Overlapping (.10 used twice) | Move homebridge to .10, Mac Mini to .195 |
| .11-12 | Alarm Panels (Resideo) | ✓ Good | Keep |
| .13 | Screen Logic (Pool) | ✓ Good | Keep |
| .14-15 | Rachio + Lutron | ✓ Good | Keep |
| .16 | Epson Printer | ✓ Good | Keep |
| .17-18 | Eight Sleep + Mill | ✓ Good | Keep |
| .19 | Lutron Bridge | ✓ Good | Keep |

### IoT Home Automation (192.168.4.20-49)
**Smart home devices, sensors, appliances**

| IP Range | Device Type | Current | Recommendation |
|----------|-------------|---------|----------------|
| .20-22 | Flo-by-Moen, UT-ATA, iSmartGate | ✓ Good | Keep |
| .23-24 | Jellyfish devices | ✓ Good | Keep |
| .25-28 | Roborock vacuums (mumu prime, nunu prime, nunu, mumu) | ✓ Good | Keep |
| .30-36 | Thermador appliances (2 fridges, oven, 2 dishwashers, wine cooler) | ✓ Good | Keep |
| .37-39 | Raspberry Pi devices (JellyfishRP, HomeAssistant, GenMonPi4) | ✓ Good | Keep |
| .40 | Pi5-3 Server | Currently here | **Move to .100** (servers section) |
| .41-43 | PowerView G3 Hubs (window shades) | ✓ Good | Keep |
| .44-46 | VOCOlinc SmartBar + unknown | ✓ Good | Keep |
| .50 | Espressif device | ✓ Good | Keep |

### Ecobee Thermostats (192.168.4.51-55)
**HVAC control**

| IP | Device | Status |
|----|--------|--------|
| .51 | Office | ✓ Keep |
| .52 | Utility Room | ✓ Keep |
| .53 | Living Room | ✓ Keep |
| .54 | Upstair Living Room | ✓ Keep |
| .55 | Master Suite | ✓ Keep |

### Smart Home Hubs & Panels (192.168.4.56-59)
| IP | Device | Status |
|----|--------|--------|
| .56 | MyQ Garage Hub | ✓ Keep |
| .57 | Span Gateway | ✓ Keep |
| .59 | Z-Hidden (Apple HomePod) | ✓ Keep |

### HomePods (192.168.4.60-68)
**Apple HomePod speakers**

| IP | Device | Status |
|----|--------|--------|
| .60 | Living Room OG | ✓ Keep |
| .61 | Studio HomePod | ✓ Keep |
| .62 | Office HomePod | ✓ Keep |
| .63 | Kitchenette | ✓ Keep |
| .64 | Kitchen | ✓ Keep |
| .65 | Shop | ✓ Keep |
| .66 | Master Bedroom | ✓ Keep |
| .67 | HomePod Turtle | ✓ Keep |
| .68 | HomePod Pool Room | ✓ Keep |

### First Alert OneLink Smoke/CO Detectors (192.168.4.70-81)
**Safety devices - should have static assignments**

| IP | Device | Current | Recommendation |
|----|--------|---------|----------------|
| .70-81 | 11 OneLink detectors + 1 iHome | Scattered | **Add DHCP reservations** |

### Servers & Infrastructure (192.168.4.100-119)
**Production servers, dev servers, critical services**

| IP | Device | Current | Recommendation |
|----|--------|---------|----------------|
| .100 | **AVAILABLE** | - | **Assign to UTM Server (MAC: 00:e0:4c:68:04:a7)** |
| .101-109 | Reserved for future servers | | |
| .110 | Homebridge (from .10) | | **Move here** |

### IoT Miscellaneous (192.168.4.120-159)
**Various smart devices, sensors, etc.**

| IP Range | Devices | Note |
|----------|---------|------|
| .120-159 | Twinkly lights, ESP devices, iHome monitors, misc | Reorganize with reservations |

### UniFi Protect Cameras (192.168.4.160-179)
**Security cameras - stable IPs recommended**

| IP | Device | Status |
|----|--------|--------|
| .154 | Back NW Alley | ✓ Keep |
| .155 | Courtyard | ✓ Keep |
| .157 | Front Doorbell | ✓ Keep |
| .164 | Side SE | ✓ Keep |
| .165 | Back SW Alley | ✓ Keep |
| .166 | Driveway | ✓ Keep |
| .168 | Zeta | ✓ Keep |
| .169 | Side SW | ✓ Keep |
| .175 | Front SE | ✓ Keep |
| .181 | Front NE | ✓ Keep |
| .183 | Side North | ✓ Keep |

Additional cameras:
- G4 Instant (.144) - **Move to .144** (conflicts)
- Z-Garage (.199) - **Move to .178**

### Computers - macOS/Windows (192.168.4.180-199)
**Desktop computers, laptops (non-mobile)**

| IP Range | Devices | Current Issues | Recommendation |
|----------|---------|----------------|----------------|
| .180-199 | Mac Studios, Mac Minis, MacBooks, PCs | Scattered throughout .130-.200 | **Consolidate here** |

**Specific assignments:**
- .190: Mine2 ✓ Keep
- .195: Mac Mini (currently .136)
- .196: MacMini (currently .10)
- .197: OneLink detector (move to .81)
- .198: InternetBK-Pi5 - **Move to .105** (servers)

### Static Appliances (192.168.4.200-209)
**TVs, printers, Sonos, fixed appliances**

| IP | Device | Status |
|----|--------|--------|
| .200 | EricsMacStudio2 | ✓ Keep |
| .201-202 | Samsung Frame TVs | ✓ Keep |
| .203 | Tesla Model X | ✓ Keep |
| .204-207 | Sonos Zone Players (4 units) | ✓ Keep |
| .208 | Twinkly-eafef9 | ✓ Keep |
| .209 | Frame TV | ✓ Keep |

### Mobile Devices - DHCP Pool (192.168.4.210-229)
**iPhones, iPads, Apple Watches - Dynamic**

| IP Range | Device Type | Note |
|----------|-------------|------|
| .210-229 | Reserved for mobile DHCP pool | Let these remain dynamic |

### Mobile Devices - Static (192.168.4.230-249)
**Mobile devices that need static IPs**

| IP Range | Devices | Current |
|----------|---------|---------|
| .230-236 | iPhones (Erics, Jello's, Jacob's, etc.) | ✓ Keep if needed |
| .237-242 | Misc devices, Reality Device | ✓ Keep |
| .243-249 | Watches, PCs, devices | Review |

### Special Purpose / Future (192.168.4.250-254)
| IP | Device | Status |
|----|--------|--------|
| .250 | Jacob's iPhone | ✓ Keep |
| .251-252 | Twinkly lights | ✓ Keep |
| .253 | **NextGen Plaid Server** | ✓ CRITICAL - Keep |
| .254 | Reserved | |

---

## Critical Actions Required

### 1. **Immediate - Fix Conflicts**
- **192.168.4.10** used by both:
  - Mac Mini (Apple)
  - Homebridge (Raspberry Pi)
  - **Action:** Move Mac Mini to .196, keep Homebridge at .10

- **192.168.4.141** - Currently showing as Twinkly but also MacBook-Air
  - **Action:** Assign **192.168.4.100** to UTM/MacBook-Air via DHCP reservation

### 2. **High Priority - Add DHCP Reservations**

**Servers:**
```
192.168.4.100 - MacBook-Air (UTM) - MAC: 00:e0:4c:68:04:a7
192.168.4.105 - InternetBK-Pi5 - MAC: 2c:cf:67:3d:3d:eb
192.168.4.253 - NextGen Plaid - MAC: 1c:1d:d3:df:9c:74 (verify exists)
```

**Infrastructure:**
```
192.168.4.4   - UniFi NVR Pro - MAC: d8:b3:70:48:9e:73
192.168.4.9   - Lutron Bridge - MAC: 64:cf:d9:e6:18:51
192.168.4.10  - Homebridge - MAC: d8:3a:dd:26:66:89
192.168.4.11  - Alarm Panel - MAC: 48:a2:e6:f8:18:48
192.168.4.15  - Lutron 05900c8d - MAC: f8:2e:0c:42:fc:49
192.168.4.19  - Lutron 05900cce - MAC: f8:2e:0c:43:4a:e5
```

**Cameras (All 14 cameras should have reservations):**
```
192.168.4.154 - Back NW Alley - MAC: 70:a7:41:0b:9f:f3
192.168.4.155 - Courtyard - MAC: f4:e2:c6:7c:47:79
192.168.4.157 - Front Doorbell - MAC: 70:a7:41:0d:1a:69
... (continue for all cameras)
```

### 3. **Medium Priority - Reorganize**

**Move these devices:**
- Mac Mini (.136) → .196
- Pi5-3 (.40) → .100 or .105
- InternetBK-Pi5 (.198) → .105
- Z-Garage camera (.199) → .178

### 4. **Low Priority - Documentation**
- Label all OneLink detectors by room
- Document which Twinkly is which
- Identify unnamed devices

---

## Implementation Steps

1. **Create DHCP reservation for UTM Server:**
   - MAC: `00:e0:4c:68:04:a7`
   - IP: `192.168.4.100`
   - Name: UTM-Server or MacBook-Air-UTM

2. **Export current DHCP pool range from UniFi**
   - Verify current range (likely .2-.254)
   - Adjust to exclude static ranges

3. **Add reservations in batches:**
   - Start with critical infrastructure (.1-.19)
   - Then servers (.100-.119)
   - Then cameras (.160-.179)
   - Then everything else

4. **Test each change:**
   - Verify device reconnects with new IP
   - Update any hardcoded IPs in configs
   - Monitor for conflicts

---

## DHCP Pool Recommendations

**Current pool (assumed):** 192.168.4.2 - 192.168.4.254

**Recommended pool:**
- **Primary Dynamic:** 192.168.4.210 - 192.168.4.229 (20 IPs for mobile devices)
- **Secondary Dynamic:** 192.168.4.82 - 192.168.4.99 (18 IPs for guests/temporary)

All other IPs should have DHCP reservations or be excluded from DHCP.

---

## Summary Statistics

- **Total Devices:** ~180
- **Currently using DHCP reservations:** 0
- **Should have reservations:** ~150
- **Mobile devices (dynamic OK):** ~30
- **Critical conflicts found:** 2
- **Reorganization candidates:** ~8

---

## Next Steps

1. Review this document
2. Approve IP assignment changes
3. Create DHCP reservation for 192.168.4.100 (UTM Server)
4. Incrementally add reservations (start with infrastructure & cameras)
5. Update documentation as changes are made
