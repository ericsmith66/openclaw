# Prefab HomeKit API Reference — Validated REST Calls

**Server:** `http://localhost:8080`  
**Home:** Waverly  
**Validated:** 2026-02-15  

---

## Table of Contents

1. [Homes](#1-homes)
2. [Rooms](#2-rooms)
3. [Accessories](#3-accessories)
4. [Accessory Control (Write)](#4-accessory-control-write)
5. [Scenes](#5-scenes)
6. [Groups](#6-groups)
7. [Validated Write Examples by Type](#7-validated-write-examples-by-type)
8. [Device Discovery Workflow](#8-device-discovery-workflow)

---

## 1. Homes

### List all homes

```bash
curl -s http://localhost:8080/homes
```

**Response:**
```json
[{"name": "Waverly"}]
```

### Get a specific home

```bash
curl -s http://localhost:8080/homes/Waverly
```

**Response:**
```json
{"name": "Waverly"}
```

---

## 2. Rooms

### List all rooms in a home

```bash
curl -s http://localhost:8080/rooms/Waverly
```

**Response:**
```json
[
  {"name": "Studio", "home": "Waverly"},
  {"name": "Kitchen", "home": "Waverly"},
  {"name": "Office", "home": "Waverly"},
  ...
]
```

### Get a specific room

```bash
curl -s http://localhost:8080/rooms/Waverly/Office
```

**Note:** Room names with spaces must be URL-encoded:
```bash
curl -s "http://localhost:8080/rooms/Waverly/Living%20Room"
curl -s "http://localhost:8080/rooms/Waverly/Master%20Bedroom"
```

For special characters (smart quotes, etc.):
```bash
# Jacob's Room (uses Unicode right single quote U+2019)
curl -s "http://localhost:8080/rooms/Waverly/Jacob%E2%80%99s%20Room"
```

---

## 3. Accessories

### List accessories in a room

```bash
curl -s http://localhost:8080/accessories/Waverly/Office
```

**Response:**
```json
[
  {"room": "Office", "category": "Other", "home": "Waverly", "name": "Chandelier"},
  {"room": "Office", "category": "Other", "home": "Waverly", "name": "Office Shade"},
  {"room": "Office", "category": "Other", "home": "Waverly", "name": "Downlights"},
  ...
]
```

### Get detailed accessory info (services, characteristics, values)

```bash
curl -s "http://localhost:8080/accessories/Waverly/Office/Chandelier"
```

**Response includes:**
- `name`, `home`, `room`, `category`
- `isReachable`, `isBridged`, `supportsIdentify`
- `manufacturer`, `model`, `firmwareVersion`
- `services[]` — each with `uniqueIdentifier`, `typeName`, `characteristics[]`
- Each characteristic has: `uniqueIdentifier`, `typeName`, `value`, `properties[]`, `metadata` (format, min, max, step, units)

**Key properties to check:**
- `HMCharacteristicPropertyWritable` — can be written to
- `HMCharacteristicPropertyReadable` — can be read
- `HMCharacteristicPropertySupportsEventNotification` — supports push notifications

---

## 4. Accessory Control (Write)

### Update an accessory characteristic

```
PUT /accessories/:home/:room/:accessory
Content-Type: application/json
```

**Request body:**
```json
{
  "serviceId": "<service-uniqueIdentifier>",
  "characteristicId": "<characteristic-uniqueIdentifier>",
  "value": "<string-value>"
}
```

**Important notes:**
- All values are passed as **strings** regardless of the underlying format
- The server converts the string to the appropriate type based on the characteristic's `metadata.format`
- Returns empty string `""` on success
- Returns HTTP error on failure (400, 404, 500)

### Supported value formats

| Format | String Value Examples | Notes |
|--------|----------------------|-------|
| `bool` | `"true"`, `"false"`, `"1"`, `"0"`, `"on"`, `"off"` | Case-insensitive |
| `uint8` | `"0"`, `"100"`, `"255"` | 0–255 |
| `uint16` | `"0"`, `"65535"` | |
| `uint32` | `"0"`, `"4294967295"` | |
| `uint64` | `"0"` | |
| `int` | `"-100"`, `"0"`, `"100"` | Signed integer |
| `float` | `"22.5"`, `"18.9"` | Decimal values |
| `string` | `"any text"` | Pass-through |

---

## 5. Scenes

### List all scenes in a home

```bash
curl -s http://localhost:8080/scenes/Waverly
```

**Response:**
```json
[
  {
    "name": "Bed Time",
    "isBuiltIn": false,
    "uniqueIdentifier": "B97C345A-FA82-5F43-B2D1-3F4C8EC93B74",
    "home": "Waverly"
  },
  ...
]
```

### Get scene details (includes actions)

```bash
curl -s "http://localhost:8080/scenes/Waverly/B97C345A-FA82-5F43-B2D1-3F4C8EC93B74"
```

**Note:** Scene endpoint uses UUID, not name.

**Response:**
```json
{
  "home": "Waverly",
  "uniqueIdentifier": "B97C345A-FA82-5F43-B2D1-3F4C8EC93B74",
  "name": "Bed Time",
  "isBuiltIn": false,
  "actions": [
    {
      "accessoryName": "Downlights",
      "serviceName": "Downlights",
      "characteristicType": "00000025-0000-1000-8000-0026BB765291",
      "targetValue": "0"
    }
  ]
}
```

### Execute a scene

```bash
curl -s -X POST "http://localhost:8080/scenes/Waverly/B97C345A-FA82-5F43-B2D1-3F4C8EC93B74/execute"
```

**Response:**
```json
{"success": true, "scene": "Bed Time"}
```

### Execute a scene — Shades Office Open ✅ (validated 2026-02-15)

```bash
curl -s -X POST "http://localhost:8080/scenes/Waverly/DE620F4E-D2EA-5621-8A6E-3213B86EF852/execute"
```

**Response:**
```json
{"success": true, "scene": "Shades Office Open"}
```

**Related shade scenes:**

| Scene | UUID | Action |
|-------|------|--------|
| Shades Office Open | `DE620F4E-D2EA-5621-8A6E-3213B86EF852` | Open office shades |
| Shades Office Close | `B7CB5BB5-6F3F-59B9-A3B2-2E28CEFEC3C2` | Close office shades |
| Shades Living Room Open | `C66AA03B-75FB-58B4-A111-BA5C8EEA39F6` | Open living room shades |
| Shades Living Room Closed | `3F0B3D6D-6759-592E-81C5-8598C584F25C` | Close living room shades |
| Shades Dining Open | `A6AB06EC-C5CB-5047-BF87-87B19BAC9B02` | Open dining shades |
| Shades Dining Closed | `E34C74CA-B7AD-5106-B985-A580304FF0A2` | Close dining shades |
| Shades Master Bed Room Open | `E0CC2D5C-7729-5805-B7CD-9E0E792665F6` | Open master bedroom shades |
| Shades Master Bed Room Closed | `8C05C29C-A2B5-5C37-8986-CBE55B47CAD4` | Close master bedroom shades |
| Shades Up First Floor | `52D8E7C1-A2A4-563A-AD2F-3F8A148FD922` | Open all first floor shades |
| Shades Pool Time | `A0071FBA-723C-55DC-A4F0-F91F7B604DFC` | Pool time shade positions |
| shades 0 | `B78A62C2-1E7B-506B-890A-47A36F72B6AD` | All shades fully closed |
| shades 30 | `E3958C09-C750-57C9-9DE2-02F4B6480914` | All shades to 30% |
| shades 50 | `8ECD0115-16BC-50E5-BBBD-7EFE2345D57B` | All shades to 50% |
| shades 100 | `A0FEDF5E-A8B8-522E-8DCA-F6B8EE914730` | All shades fully open |

---

## 6. Groups

### List all groups in a home

```bash
curl -s http://localhost:8080/groups/Waverly
```

### Get group details

```bash
curl -s "http://localhost:8080/groups/Waverly/97D307A1-1BB6-5DC1-B0B8-277D5E10CAA1"
```

### Update all accessories in a group

```bash
curl -s -X PUT "http://localhost:8080/groups/Waverly/97D307A1-1BB6-5DC1-B0B8-277D5E10CAA1" \
  -H "Content-Type: application/json" \
  -d '{"characteristicType": "00000025-0000-1000-8000-0026BB765291", "value": "true"}'
```

---

## 7. Validated Write Examples by Type

All examples below were tested and confirmed working on 2026-02-15.

### Light On/Off (bool) ✅

```bash
# Turn OFF the Office Chandelier
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Office/Chandelier" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "FF6E60A3-B101-56DB-B296-A10AB04DF729",
    "characteristicId": "1594A5F1-5345-54D3-9025-F6288F1D3B4C",
    "value": "false"
  }'

# Turn ON the Office Chandelier
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Office/Chandelier" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "FF6E60A3-B101-56DB-B296-A10AB04DF729",
    "characteristicId": "1594A5F1-5345-54D3-9025-F6288F1D3B4C",
    "value": "true"
  }'
```

### Light Brightness (int, 0–100%) ✅

```bash
# Set Office Chandelier brightness to 20%
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Office/Chandelier" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "FF6E60A3-B101-56DB-B296-A10AB04DF729",
    "characteristicId": "52D57137-7A54-5AE8-9B67-4067765DF991",
    "value": "20"
  }'
```

**Other dimmable lights in Office (same pattern):**

| Accessory | Service ID | On Char ID | Brightness Char ID |
|-----------|-----------|------------|-------------------|
| Desk Pucks | 0C57E8A2-430D-5167-9D97-6A96D0D548B5 | 89ED45A1-9567-5AE7-8658-2DA1CF6342DA | 44102C7D-BA23-5277-84C5-7B37BF96E0A2 |
| Cabinets | 3C92B897-980C-5103-A04D-9118C4AD5F91 | B91E7F78-69C6-51DD-B5F4-7D80E6B5D555 | BF3B8839-E038-5FCF-B2DD-1D002F7990B1 |
| Sitting Pucks | 12D55294-345D-556F-AC62-1ACB09A83299 | FCB331B0-5E7D-5D15-84F5-BD3D95DFE368 | 15D0ABCF-79CF-5AB6-90BB-CD43E4B7EEB6 |
| Downlights | 6BE2E0B2-87E8-522D-B885-C84D38AB3BC1 | F9864B3F-6F48-5C2F-B08C-8F75500A7420 | 10D827A7-FAF1-5D9E-8B32-E2F7B59075A7 |

### Window Shade Position (uint8, 0–100%) ✅

```bash
# Open Office Shade to 100%
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Office/Office%20Shade" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "B1A9F90A-D540-55C7-A712-2498DA95D74E",
    "characteristicId": "52B4B9BF-6A3B-5440-B176-28EC6ADC3AFC",
    "value": "100"
  }'

# Close Office Shade to 0%
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Office/Office%20Shade" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "B1A9F90A-D540-55C7-A712-2498DA95D74E",
    "characteristicId": "52B4B9BF-6A3B-5440-B176-28EC6ADC3AFC",
    "value": "0"
  }'

# Set Office Shade to 50%
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Office/Office%20Shade" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "B1A9F90A-D540-55C7-A712-2498DA95D74E",
    "characteristicId": "52B4B9BF-6A3B-5440-B176-28EC6ADC3AFC",
    "value": "50"
  }'
```

**Read shade position:**
```bash
curl -s "http://localhost:8080/accessories/Waverly/Office/Office%20Shade" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for svc in data.get('services', []):
    if svc['typeName'] == 'Window Covering':
        for c in svc['characteristics']:
            if c['typeName'] in ('Current Position', 'Target Position', 'Position State'):
                print(f\"{c['typeName']}: {c['value']}\")
"
```

### Switch On/Off — Spa Pump (bool) ✅

```bash
# Turn ON Spa Pump
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Courtyard/Spa%20Pump" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "C58CBB27-E9C4-5705-8AF9-EC663D755107",
    "characteristicId": "245A8939-59CA-5ABA-8C3A-F10C700D2BDC",
    "value": "true"
  }'

# Turn OFF Spa Pump
curl -s -X PUT "http://localhost:8080/accessories/Waverly/Courtyard/Spa%20Pump" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "C58CBB27-E9C4-5705-8AF9-EC663D755107",
    "characteristicId": "245A8939-59CA-5ABA-8C3A-F10C700D2BDC",
    "value": "false"
  }'
```

---

## 8. Device Discovery Workflow

To control any accessory, you need its `serviceId` and `characteristicId`. Here's the workflow:

### Step 1: Find the room

```bash
curl -s http://localhost:8080/rooms/Waverly | python3 -m json.tool
```

### Step 2: List accessories in the room

```bash
curl -s http://localhost:8080/accessories/Waverly/Office | python3 -m json.tool
```

### Step 3: Get detailed accessory info

```bash
curl -s "http://localhost:8080/accessories/Waverly/Office/Chandelier" | python3 -m json.tool
```

### Step 4: Find the writable characteristic

Look for characteristics with `HMCharacteristicPropertyWritable` in the `properties` array. Note the:
- **Service `uniqueIdentifier`** → use as `serviceId`
- **Characteristic `uniqueIdentifier`** → use as `characteristicId`
- **`metadata.format`** → determines value format (bool, int, uint8, float, etc.)
- **`metadata.minimumValue` / `metadata.maximumValue`** → valid range

### Step 5: Write the value

```bash
curl -s -X PUT "http://localhost:8080/accessories/Waverly/<room>/<accessory>" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceId": "<service-uniqueIdentifier>",
    "characteristicId": "<characteristic-uniqueIdentifier>",
    "value": "<string-value>"
  }'
```

### Helper: List all writable characteristics for an accessory

```bash
curl -s "http://localhost:8080/accessories/Waverly/Office/Chandelier" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Accessory: {data['name']} | Reachable: {data.get('isReachable')}\")
for svc in data.get('services', []):
    for c in svc['characteristics']:
        if 'HMCharacteristicPropertyWritable' in c.get('properties', []):
            fmt = c.get('metadata', {}).get('format', '?')
            mn = c.get('metadata', {}).get('minimumValue', '')
            mx = c.get('metadata', {}).get('maximumValue', '')
            rng = f' [{mn}-{mx}]' if mn or mx else ''
            print(f\"  {c['typeName']:30s} val={c.get('value',''):10s} fmt={fmt}{rng}\")
            print(f\"    serviceId: {svc['uniqueIdentifier']}\")
            print(f\"    characteristicId: {c['uniqueIdentifier']}\")
"
```

---

## API Endpoint Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/homes` | List all homes |
| `GET` | `/homes/:home` | Get specific home |
| `GET` | `/rooms/:home` | List rooms in a home |
| `GET` | `/rooms/:home/:room` | Get specific room |
| `GET` | `/accessories/:home/:room` | List accessories in a room |
| `GET` | `/accessories/:home/:room/:accessory` | Get accessory details + characteristics |
| `PUT` | `/accessories/:home/:room/:accessory` | Update accessory characteristic |
| `GET` | `/scenes/:home` | List scenes |
| `GET` | `/scenes/:home/:scene` | Get scene details (by UUID) |
| `POST` | `/scenes/:home/:scene/execute` | Execute a scene (by UUID) |
| `GET` | `/groups/:home` | List groups |
| `GET` | `/groups/:home/:group` | Get group details (by UUID) |
| `PUT` | `/groups/:home/:group` | Update group characteristics |

---

## Common HAP Characteristic Types (UUID Reference)

| Characteristic | UUID | Typical Format |
|---------------|------|---------------|
| On | `00000025-0000-1000-8000-0026BB765291` | bool |
| Brightness | `00000008-0000-1000-8000-0026BB765291` | int (0–100) |
| Current Position | `0000006D-0000-1000-8000-0026BB765291` | uint8 (0–100) |
| Target Position | `0000007C-0000-1000-8000-0026BB765291` | uint8 (0–100) |
| Position State | `00000072-0000-1000-8000-0026BB765291` | uint8 (0=down, 1=up, 2=stopped) |
| Current Temperature | `00000011-0000-1000-8000-0026BB765291` | float (°C) |
| Target Temperature | `00000035-0000-1000-8000-0026BB765291` | float (°C) |
| Target Heating Cooling State | `00000033-0000-1000-8000-0026BB765291` | uint8 (0=Off, 1=Heat, 2=Cool, 3=Auto) |
| Lock Current State | `0000001D-0000-1000-8000-0026BB765291` | uint8 (0=Unsecured, 1=Secured) |
| Lock Target State | `0000001E-0000-1000-8000-0026BB765291` | uint8 (0=Unsecured, 1=Secured) |
| Hue | `00000013-0000-1000-8000-0026BB765291` | float (0–360°) |
| Saturation | `0000002F-0000-1000-8000-0026BB765291` | float (0–100%) |
| Color Temperature | `000000CE-0000-1000-8000-0026BB765291` | uint32 |


---

## 9. Ruby Examples

### Setup — Shared Client Helper

```ruby
require 'net/http'
require 'json'
require 'uri'

module Prefab
  BASE_URL = 'http://localhost:8080'
  HOME = 'Waverly'

  class Client
    def self.get(path)
      uri = URI("#{BASE_URL}/#{path}")
      response = Net::HTTP.get_response(uri)
      JSON.parse(response.body)
    end

    def self.put(path, body)
      uri = URI("#{BASE_URL}/#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.path)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json
      http.request(request)
    end

    def self.post(path)
      uri = URI("#{BASE_URL}/#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.path)
      http.request(request)
    end

    def self.update_accessory(room:, accessory:, service_id:, characteristic_id:, value:)
      path = "accessories/#{HOME}/#{URI.encode_www_form_component(room)}/#{URI.encode_www_form_component(accessory)}"
      put(path, {
        serviceId: service_id,
        characteristicId: characteristic_id,
        value: value.to_s
      })
    end
  end
end
```

---

### Homes

```ruby
# List all homes
homes = Prefab::Client.get("homes")
puts homes
# => [{"name"=>"Waverly"}]

# Get specific home
home = Prefab::Client.get("homes/Waverly")
puts home
# => {"name"=>"Waverly"}
```

### Rooms

```ruby
# List all rooms
rooms = Prefab::Client.get("rooms/Waverly")
rooms.each { |r| puts r['name'] }

# Get specific room
room = Prefab::Client.get("rooms/Waverly/Office")
```

### Accessories

```ruby
# List accessories in a room
accessories = Prefab::Client.get("accessories/Waverly/Office")
accessories.each { |a| puts "#{a['name']} (#{a['category']})" }

# Get detailed accessory info
accessory = Prefab::Client.get("accessories/Waverly/Office/Chandelier")
puts "#{accessory['name']} | Reachable: #{accessory['isReachable']} | Model: #{accessory['model']}"

# List writable characteristics
accessory['services'].each do |svc|
  svc['characteristics'].each do |c|
    next unless c['properties'].include?('HMCharacteristicPropertyWritable')
    meta = c['metadata'] || {}
    range = [meta['minimumValue'], meta['maximumValue']].compact.join('-')
    puts "  #{c['typeName']}: val=#{c['value']} fmt=#{meta['format']} [#{range}]"
    puts "    serviceId: #{svc['uniqueIdentifier']}"
    puts "    characteristicId: #{c['uniqueIdentifier']}"
  end
end
```

---

### Light On/Off (bool) ✅

```ruby
# Turn ON the Office Chandelier
Prefab::Client.update_accessory(
  room: 'Office',
  accessory: 'Chandelier',
  service_id: 'FF6E60A3-B101-56DB-B296-A10AB04DF729',
  characteristic_id: '1594A5F1-5345-54D3-9025-F6288F1D3B4C',
  value: 'true'
)

# Turn OFF the Office Chandelier
Prefab::Client.update_accessory(
  room: 'Office',
  accessory: 'Chandelier',
  service_id: 'FF6E60A3-B101-56DB-B296-A10AB04DF729',
  characteristic_id: '1594A5F1-5345-54D3-9025-F6288F1D3B4C',
  value: 'false'
)
```

### Light Brightness (int, 0–100%) ✅

```ruby
# Set Office Chandelier brightness to 20%
Prefab::Client.update_accessory(
  room: 'Office',
  accessory: 'Chandelier',
  service_id: 'FF6E60A3-B101-56DB-B296-A10AB04DF729',
  characteristic_id: '52D57137-7A54-5AE8-9B67-4067765DF991',
  value: 20
)
```

### Window Shade Position (uint8, 0–100%) ✅

```ruby
# Open Office Shade to 100%
Prefab::Client.update_accessory(
  room: 'Office',
  accessory: 'Office Shade',
  service_id: 'B1A9F90A-D540-55C7-A712-2498DA95D74E',
  characteristic_id: '52B4B9BF-6A3B-5440-B176-28EC6ADC3AFC',
  value: 100
)

# Close Office Shade
Prefab::Client.update_accessory(
  room: 'Office',
  accessory: 'Office Shade',
  service_id: 'B1A9F90A-D540-55C7-A712-2498DA95D74E',
  characteristic_id: '52B4B9BF-6A3B-5440-B176-28EC6ADC3AFC',
  value: 0
)

# Read shade position
shade = Prefab::Client.get("accessories/Waverly/Office/Office%20Shade")
shade['services'].each do |svc|
  next unless svc['typeName'] == 'Window Covering'
  svc['characteristics'].each do |c|
    next unless ['Current Position', 'Target Position', 'Position State'].include?(c['typeName'])
    puts "#{c['typeName']}: #{c['value']}"
  end
end
```

### Switch — Spa Pump (bool) ✅

```ruby
# Turn ON Spa Pump
Prefab::Client.update_accessory(
  room: 'Courtyard',
  accessory: 'Spa Pump',
  service_id: 'C58CBB27-E9C4-5705-8AF9-EC663D755107',
  characteristic_id: '245A8939-59CA-5ABA-8C3A-F10C700D2BDC',
  value: 'true'
)

# Turn OFF Spa Pump
Prefab::Client.update_accessory(
  room: 'Courtyard',
  accessory: 'Spa Pump',
  service_id: 'C58CBB27-E9C4-5705-8AF9-EC663D755107',
  characteristic_id: '245A8939-59CA-5ABA-8C3A-F10C700D2BDC',
  value: 'false'
)
```

---

### Scenes

```ruby
# List all scenes
scenes = Prefab::Client.get("scenes/Waverly")
scenes.each { |s| puts "#{s['name']} (built-in: #{s['isBuiltIn']}) — #{s['uniqueIdentifier']}" }

# Get scene details
scene = Prefab::Client.get("scenes/Waverly/B97C345A-FA82-5F43-B2D1-3F4C8EC93B74")
puts "Scene: #{scene['name']}"
scene['actions'].each do |a|
  puts "  #{a['accessoryName']} / #{a['serviceName']} → #{a['targetValue']}"
end

# Execute a scene
response = Prefab::Client.post("scenes/Waverly/B97C345A-FA82-5F43-B2D1-3F4C8EC93B74/execute")
result = JSON.parse(response.body)
puts "Executed: #{result['scene']} — success: #{result['success']}"
```

---

### Groups

```ruby
# List all groups
groups = Prefab::Client.get("groups/Waverly")
groups.each { |g| puts "#{g['name']} (#{g['serviceCount']} services)" }

# Get group details
group = Prefab::Client.get("groups/Waverly/97D307A1-1BB6-5DC1-B0B8-277D5E10CAA1")
puts "Group: #{group['name']}"
group['services'].each do |s|
  puts "  #{s['accessoryName']} / #{s['serviceName']}"
end

# Update all accessories in a group (e.g., turn all On)
uri = URI("#{Prefab::BASE_URL}/groups/Waverly/97D307A1-1BB6-5DC1-B0B8-277D5E10CAA1")
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Put.new(uri.path)
request['Content-Type'] = 'application/json'
request.body = {
  characteristicType: '00000025-0000-1000-8000-0026BB765291',
  value: 'true'
}.to_json
response = http.request(request)
result = JSON.parse(response.body)
puts "Updated: #{result['updated']}, Failed: #{result['failed']}"
```

---

### Device Discovery Workflow (Ruby)

```ruby
# Full workflow: discover and control any accessory

# Step 1: Find rooms
rooms = Prefab::Client.get("rooms/Waverly")
puts "Rooms: #{rooms.map { |r| r['name'] }.join(', ')}"

# Step 2: Pick a room, list accessories
accessories = Prefab::Client.get("accessories/Waverly/Office")
puts "\nOffice accessories:"
accessories.each { |a| puts "  #{a['name']} (#{a['category']})" }

# Step 3: Get detailed info for an accessory
detail = Prefab::Client.get("accessories/Waverly/Office/Chandelier")

# Step 4: Find writable characteristics
puts "\nWritable controls for #{detail['name']}:"
detail['services'].each do |svc|
  svc['characteristics'].each do |c|
    next unless c['properties'].include?('HMCharacteristicPropertyWritable')
    meta = c['metadata'] || {}
    puts "  #{c['typeName']}"
    puts "    Current value: #{c['value']}"
    puts "    Format: #{meta['format']}, Range: #{meta['minimumValue']}–#{meta['maximumValue']} #{meta['units']}"
    puts "    serviceId: #{svc['uniqueIdentifier']}"
    puts "    characteristicId: #{c['uniqueIdentifier']}"
  end
end

# Step 5: Write a value
Prefab::Client.update_accessory(
  room: 'Office',
  accessory: 'Chandelier',
  service_id: 'FF6E60A3-B101-56DB-B296-A10AB04DF729',
  characteristic_id: '52D57137-7A54-5AE8-9B67-4067765DF991',
  value: 50
)
puts "\nChandelier brightness set to 50%"
```

### Monitor Accessory State (Ruby)

```ruby
# Poll an accessory for state changes
loop do
  shade = Prefab::Client.get("accessories/Waverly/Office/Office%20Shade")
  shade['services'].each do |svc|
    next unless svc['typeName'] == 'Window Covering'
    values = svc['characteristics']
      .select { |c| ['Current Position', 'Target Position', 'Position State'].include?(c['typeName']) }
      .map { |c| "#{c['typeName']}: #{c['value']}" }
    puts "#{Time.now.strftime('%H:%M:%S')} | #{values.join(' | ')}"
  end
  sleep 2
end
```
