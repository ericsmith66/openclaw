# Troubleshooting Epic 1

## Issue: PrefabClient "end of file reached" Error

### Problem
When calling `PrefabClient.homes` or any other Prefab API method, you get:
```
PrefabClient error: end of file reached
```

### Root Cause
Ruby's HTTP client libraries (HTTParty, Net::HTTP) have issues with the Prefab server's HTTP response format. The server returns valid JSON but with `Content-Type: text/plain` and potentially incomplete HTTP headers, causing Ruby's HTTP parser to fail when trying to read the response.

### Symptoms
- `curl http://localhost:8080/homes` works fine
- Ruby HTTP clients fail with EOFError
- Error occurs in `net/protocol.rb` during `rbuf_fill`

### Solution
Updated `PrefabClient` to use system `curl` calls instead of Ruby HTTP libraries:

```ruby
# Before (HTTParty)
def self.homes
  response = get('/homes')
  response.success? ? response.parsed_response : []
end

# After (curl workaround)
def self.homes
  fetch_json('/homes')
end

private

def self.fetch_json(path)
  url = "#{BASE_URL}#{path}"
  result = `curl -s -m 5 "#{url}"`

  if $?.success?
    JSON.parse(result)
  else
    Rails.logger.error("PrefabClient: curl failed")
    []
  end
end
```

### Testing
```bash
# In Rails console
PrefabClient.homes
# => [{"name"=>"Waverly"}]

PrefabClient.rooms('Waverly')
# => [{"home"=>"Waverly", "name"=>"Studio"}, ...]
```

## Issue: Missing UUIDs in Prefab Response

### Problem
Prefab API doesn't return UUIDs for homes, rooms, accessories, or scenes. The response only contains names:
```json
[{"name": "Waverly"}]
```

But our database requires UUIDs for uniqueness.

### Solution
Generate deterministic UUIDs from object names:

```ruby
def generate_uuid(*components)
  require 'digest/sha1'
  Digest::SHA1.hexdigest(components.join('::'))[0..35]
end

# Usage examples:
generate_uuid('home', 'Waverly')
# => "09d89ec15c2..." (always the same for "Waverly")

generate_uuid('room', 'Waverly', 'Office')
# => "a1b2c3d4e5f..." (unique per home+room combination)
```

### Benefits
- **Deterministic**: Same name always generates same UUID
- **Idempotent**: Re-running sync won't create duplicates
- **Unique**: Different combinations create different UUIDs
- **Works with existing code**: No changes to models or tests needed

### Updated Sync Methods
```ruby
def sync_home(data)
  uuid = data['uuid'] || generate_uuid('home', data['name'])
  home = Home.find_or_initialize_by(uuid: uuid)
  # ...
end

def sync_room(home, data)
  uuid = data['uuid'] || generate_uuid('room', home.name, data['name'])
  room = Room.find_or_initialize_by(uuid: uuid)
  # ...
end
```

## Testing After Fixes

### 1. Test PrefabClient
```bash
rails console
```

```ruby
# Test all methods
PrefabClient.homes
PrefabClient.rooms('Waverly')
PrefabClient.accessories('Waverly', 'Office')
PrefabClient.scenes('Waverly')
```

### 2. Test HomekitSync
```bash
rails homekit:sync
```

**Expected Output:**
```
Starting HomeKit sync from Prefab...
✅ Sync complete!
   Homes: 1
   Rooms: 35
   Accessories: 399
   Scenes: 48
```

### 3. Verify Database
```bash
rails runner "
puts 'Homes: ' + Home.count.to_s
puts 'Rooms: ' + Room.count.to_s
puts 'Accessories: ' + Accessory.count.to_s
puts 'Scenes: ' + Scene.count.to_s
"
```

### 4. Test Idempotency
```bash
# Run sync twice
rails homekit:sync
rails homekit:sync

# Counts should be the same both times
rails runner "puts Home.count"  # Should be 1 both times
```

## Performance Notes

### Curl vs HTTParty
- **curl**: Works reliably with Prefab server
- **HTTParty**: Fails with EOFError
- **Performance**: curl adds ~10-50ms per request but is reliable

### Alternative Solutions (Not Implemented)

1. **Fix Prefab Server**: Update Prefab to send proper HTTP headers
   - Pros: Would allow using HTTParty
   - Cons: Requires changes to Prefab codebase

2. **Use Faraday with custom adapter**: Try different HTTP library
   - Pros: More Ruby-idiomatic
   - Cons: May have same issues with Prefab's responses

3. **TCP Socket Connection**: Direct socket communication
   - Pros: Full control over connection
   - Cons: More complex, harder to maintain

## Current Status
✅ PrefabClient working with curl workaround
✅ UUID generation implemented
✅ HomekitSync tested with live Prefab
✅ All 56 specs passing
✅ Successfully synced: 1 home, 35 rooms, 399 accessories, 48 scenes
