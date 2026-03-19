# Prefab Bulk Accessory Endpoints

**Server:** `http://localhost:8080`  
**Added:** 2026-02-15  

These endpoints return accessory metadata from HomeKit's cached object graph with **no device network calls**, making them orders of magnitude faster than fetching individual accessory details.

**Performance comparison:**
| Approach | Time | Notes |
|----------|------|-------|
| Individual detail requests (411 accessories) | **2+ minutes** | Each triggers `readValue` on every characteristic |
| Bulk endpoint (411 accessories) | **~30ms** | Reads cached properties only |

---

## Table of Contents

1. [Bulk Accessory List](#1-bulk-accessory-list)
2. [Accessory Summary](#2-accessory-summary)
3. [Ruby Examples](#3-ruby-examples)

---

## 1. Bulk Accessory List

### `GET /accessories/:home`

Returns all accessories across all rooms with metadata. No characteristic values — just identity, location, and status.

```bash
curl -s "http://localhost:8080/accessories/Waverly"
```

**Response:**
```json
[
  {
    "home": "Waverly",
    "room": "Office",
    "name": "Chandelier",
    "category": "Other",
    "isReachable": true,
    "isBridged": true,
    "manufacturer": "Lutron Electronics Co., Inc",
    "model": "Lutron Lighting Control",
    "firmwareVersion": "26.0"
  },
  ...
]
```

### Query Filters

All filters are optional and combinable via `&`:

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `reachable` | `true\|false` | Filter by reachability | `?reachable=false` |
| `room` | string | Filter by room name | `?room=Garage` |
| `category` | string | Filter by accessory category | `?category=Thermostat` |
| `manufacturer` | string | Filter by manufacturer | `?manufacturer=Sonos` |

**Notes:**
- `category` and `manufacturer` matching is **case-insensitive**
- `room` matching is **case-sensitive** (matches HomeKit room names exactly)
- URL-encode spaces and special characters: `?room=Living%20Room`

---

### Filter Examples (curl)

#### All unreachable accessories

```bash
curl -s "http://localhost:8080/accessories/Waverly?reachable=false"
```

#### All accessories in a specific room

```bash
curl -s "http://localhost:8080/accessories/Waverly?room=Garage"
curl -s "http://localhost:8080/accessories/Waverly?room=Living%20Room"
curl -s "http://localhost:8080/accessories/Waverly?room=Z-Power"
```

#### All thermostats

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Thermostat"
```

#### All door locks

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Door%20Lock"
```

#### All sensors

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Sensor"
```

#### All lightbulbs

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Lightbulb"
```

#### All speakers

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Speaker"
```

#### All bridges

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Bridge"
```

#### All Sonos devices

```bash
curl -s "http://localhost:8080/accessories/Waverly?manufacturer=Sonos"
```

#### All Lutron devices

```bash
curl -s "http://localhost:8080/accessories/Waverly?manufacturer=Lutron%20Electronics%20Co.%2C%20Inc"
```

#### All Pentair pool equipment

```bash
curl -s "http://localhost:8080/accessories/Waverly?manufacturer=Pentair"
```

---

### Combined Filters (curl)

#### Unreachable locks — security concern

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Door%20Lock&reachable=false"
```

#### Unreachable Sonos speakers

```bash
curl -s "http://localhost:8080/accessories/Waverly?manufacturer=Sonos&reachable=false"
```

#### All reachable sensors

```bash
curl -s "http://localhost:8080/accessories/Waverly?category=Sensor&reachable=true"
```

#### Everything offline in a specific room

```bash
curl -s "http://localhost:8080/accessories/Waverly?room=Shop&reachable=false"
```

#### Lutron devices in the Office

```bash
curl -s "http://localhost:8080/accessories/Waverly?room=Office&manufacturer=Lutron%20Electronics%20Co.%2C%20Inc"
```

---

### Pretty-print helpers (curl + python)

#### Table format

```bash
curl -s "http://localhost:8080/accessories/Waverly?reachable=false" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Found {len(data)} accessories\n')
for i, d in enumerate(data, 1):
    reach = '✅' if d.get('isReachable') else '❌'
    print(f'{i:<4} {reach} {d[\"name\"]:<45} {d[\"room\"]:<25} {(d.get(\"model\") or \"N/A\"):<30} {d.get(\"manufacturer\") or \"N/A\"}')
"
```

#### Count by room

```bash
curl -s "http://localhost:8080/accessories/Waverly" | python3 -c "
import sys, json
from collections import Counter
data = json.load(sys.stdin)
counts = Counter(d['room'] for d in data)
for room, count in counts.most_common():
    print(f'{count:>4}  {room}')
"
```

---

## 2. Accessory Summary

### `GET /accessories/:home/summary`

Returns counts and rollups in a single call — designed for dashboards.

```bash
curl -s "http://localhost:8080/accessories/Waverly/summary" | python3 -m json.tool
```

**Response:**
```json
{
  "total": 411,
  "reachable": 390,
  "unreachable": 21,
  "byCategory": {
    "Other": 296,
    "Lightbulb": 14,
    "Bridge": 22,
    "Sensor": 14,
    "Thermostat": 5,
    "Door Lock": 7,
    "Outlet": 5,
    "Speaker": 3,
    "Security System": 1,
    "Uncategorized": 12
  },
  "byRoom": {
    "Z-Power": 87,
    "Courtyard": 35,
    "Prepper closet": 31,
    "Z-Hidden": 26,
    "Living Room": 21,
    ...
  },
  "byManufacturer": {
    "Lutron Electronics Co., Inc": 150,
    "Pentair": 20,
    "Ubiquiti Inc.": 15,
    ...
  },
  "unreachableByManufacturer": {
    "Ledworks": 11,
    "Sonos": 3,
    "Level Home Inc.": 2,
    "VOCOlinc": 2,
    ...
  },
  "unreachableByRoom": {
    "Z-Holiday Lights": 11,
    "Front Porch": 3,
    "Shop": 2,
    ...
  }
}
```

### Dashboard one-liner

```bash
curl -s "http://localhost:8080/accessories/Waverly/summary" | python3 -c "
import sys, json
s = json.load(sys.stdin)
print(f\"Total: {s['total']} | Reachable: {s['reachable']} | Unreachable: {s['unreachable']}\")
print(f\"\nBy Category:\")
for k, v in sorted(s['byCategory'].items(), key=lambda x: -x[1]):
    print(f'  {v:>4}  {k}')
print(f\"\nUnreachable by Manufacturer:\")
for k, v in sorted(s.get('unreachableByManufacturer', {}).items(), key=lambda x: -x[1]):
    print(f'  {v:>4}  {k}')
"
```

---

## 3. Ruby Examples

### Setup

```ruby
require 'net/http'
require 'json'
require 'uri'

module Prefab
  BASE_URL = 'http://localhost:8080'
  HOME = 'Waverly'

  class Client
    def self.get(path, params: {})
      uri = URI("#{BASE_URL}/#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?
      response = Net::HTTP.get_response(uri)
      JSON.parse(response.body)
    end
  end
end
```

### Bulk List — All Accessories

```ruby
all = Prefab::Client.get("accessories/Waverly")
puts "Total: #{all.length}"
```

### Filter by Reachability

```ruby
# Unreachable devices
dead = Prefab::Client.get("accessories/Waverly", params: { reachable: false })
puts "Unreachable: #{dead.length}"
dead.each do |d|
  puts "  ❌ #{d['name'].ljust(45)} #{d['room'].ljust(25)} #{d['manufacturer']}"
end
```

### Filter by Room

```ruby
garage = Prefab::Client.get("accessories/Waverly", params: { room: 'Garage' })
puts "Garage: #{garage.length} accessories"
garage.each do |d|
  status = d['isReachable'] ? '✅' : '❌'
  puts "  #{status} #{d['name'].ljust(40)} #{d['category'].ljust(20)} #{d['manufacturer']}"
end
```

### Filter by Category

```ruby
# All thermostats
thermostats = Prefab::Client.get("accessories/Waverly", params: { category: 'Thermostat' })
puts "Thermostats: #{thermostats.length}"
thermostats.each { |t| puts "  #{t['name']} in #{t['room']} — reachable: #{t['isReachable']}" }

# All door locks
locks = Prefab::Client.get("accessories/Waverly", params: { category: 'Door Lock' })
puts "\nDoor Locks: #{locks.length}"
locks.each { |l| puts "  #{l['name']} in #{l['room']} — reachable: #{l['isReachable']}" }

# All sensors
sensors = Prefab::Client.get("accessories/Waverly", params: { category: 'Sensor' })
puts "\nSensors: #{sensors.length}"
sensors.each { |s| puts "  #{s['name']} in #{s['room']} — reachable: #{s['isReachable']}" }
```

### Filter by Manufacturer

```ruby
sonos = Prefab::Client.get("accessories/Waverly", params: { manufacturer: 'Sonos' })
puts "Sonos devices: #{sonos.length}"
sonos.each { |s| puts "  #{s['name']} in #{s['room']} — reachable: #{s['isReachable']}" }
```

### Combined Filters

```ruby
# Unreachable locks
dead_locks = Prefab::Client.get("accessories/Waverly", params: {
  category: 'Door Lock',
  reachable: false
})
puts "⚠️  Unreachable locks: #{dead_locks.length}"
dead_locks.each { |l| puts "  #{l['name']} in #{l['room']}" }

# Everything offline in Shop
shop_dead = Prefab::Client.get("accessories/Waverly", params: {
  room: 'Shop',
  reachable: false
})
puts "Shop offline: #{shop_dead.length}"
```

### Summary Dashboard

```ruby
summary = Prefab::Client.get("accessories/Waverly/summary")

puts "=== HomeKit Dashboard ==="
puts "Total: #{summary['total']} | Online: #{summary['reachable']} | Offline: #{summary['unreachable']}"

puts "\nBy Category:"
summary['byCategory'].sort_by { |_, v| -v }.each do |cat, count|
  puts "  #{count.to_s.rjust(4)}  #{cat}"
end

puts "\nBy Room (top 10):"
summary['byRoom'].sort_by { |_, v| -v }.first(10).each do |room, count|
  puts "  #{count.to_s.rjust(4)}  #{room}"
end

puts "\nUnreachable by Manufacturer:"
summary['unreachableByManufacturer'].sort_by { |_, v| -v }.each do |mfr, count|
  puts "  #{count.to_s.rjust(4)}  #{mfr}"
end

puts "\nUnreachable by Room:"
summary['unreachableByRoom'].sort_by { |_, v| -v }.each do |room, count|
  puts "  #{count.to_s.rjust(4)}  #{room}"
end
```

### Health Check Script

```ruby
# Quick health check — run periodically
summary = Prefab::Client.get("accessories/Waverly/summary")
pct = (summary['reachable'].to_f / summary['total'] * 100).round(1)

puts "HomeKit Health: #{pct}% online (#{summary['reachable']}/#{summary['total']})"

if summary['unreachable'] > 0
  dead = Prefab::Client.get("accessories/Waverly", params: { reachable: false })
  dead.group_by { |d| d['room'] }.each do |room, devices|
    puts "  #{room}: #{devices.map { |d| d['name'] }.join(', ')}"
  end
end
```

---

## Endpoint Summary

| Method | Endpoint | Description | Speed |
|--------|----------|-------------|-------|
| `GET` | `/accessories/:home` | All accessories with metadata | ~30ms |
| `GET` | `/accessories/:home?reachable=false` | Unreachable only | ~30ms |
| `GET` | `/accessories/:home?room=X` | Filter by room | ~30ms |
| `GET` | `/accessories/:home?category=X` | Filter by category | ~30ms |
| `GET` | `/accessories/:home?manufacturer=X` | Filter by manufacturer | ~30ms |
| `GET` | `/accessories/:home?room=X&reachable=false` | Combined filters | ~30ms |
| `GET` | `/accessories/:home/summary` | Counts and rollups | ~30ms |

### Known Categories

`Other`, `Lightbulb`, `Bridge`, `Sensor`, `Thermostat`, `Door Lock`, `Outlet`, `Speaker`, `Security System`

### Known Manufacturers (Waverly)

`Lutron Electronics Co., Inc`, `Pentair`, `Ubiquiti Inc.`, `ecobee Inc.`, `Sonos`, `Level Home Inc.`, `Ledworks`, `VOCOlinc`, `Meross`, `FirstAlert`, `SDI Technologies`, `Chamberlain Group`, `homebridge.io`
