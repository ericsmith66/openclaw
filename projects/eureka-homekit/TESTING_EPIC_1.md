# Testing Epic 1: Prefab Integration

This document outlines how to test all components of Epic 1.

## Quick Test (Automated)

Run all RSpec tests:
```bash
bundle exec rspec
```

**Expected Result:** 56 examples, 0 failures

## Component Testing

### 1. Database Schema (PRD 1.1)

#### Run model specs:
```bash
bundle exec rspec spec/models/
```

#### Test in Rails console:
```bash
rails console
```

```ruby
# Create test data
home = Home.create!(name: 'Test House', uuid: 'test-1', homekit_home_id: 'hk-1')
room = Room.create!(name: 'Living Room', uuid: 'test-2', home: home)
accessory = Accessory.create!(name: 'Light', uuid: 'test-3', room: room, characteristics: { power: true })
scene = Scene.create!(name: 'Movie Time', uuid: 'test-4', home: home)
scene.accessories << accessory

# Verify associations
home.rooms.count  # => 1
home.scenes.count # => 1
scene.accessories.count # => 1

# Test cascade deletion
home.destroy
Room.count # => 0 (cascaded)
```

### 2. Prefab HTTP Client (PRD 1.2)

#### Run service specs:
```bash
bundle exec rspec spec/services/prefab_client_spec.rb
```

#### Test with live Prefab (requires Prefab running on localhost:8080):
```bash
rails console
```

```ruby
# Test each endpoint
PrefabClient.homes
PrefabClient.rooms('Main House')
PrefabClient.accessories('Main House', 'Living Room')
PrefabClient.scenes('Main House')
```

**Note:** If Prefab is not running, you'll get empty arrays (graceful error handling).

### 3. HomeKit Sync Service (PRD 1.3)

#### Run sync service specs:
```bash
bundle exec rspec spec/services/homekit_sync_spec.rb
```

#### Test rake task manually:
```bash
rails homekit:sync
```

**Expected Output:**
```
Starting HomeKit sync from Prefab...
✅ Sync complete!
   Homes: X
   Rooms: X
   Accessories: X
   Scenes: X
```

#### Test with mocked data:
```bash
rails runner "
# Mock PrefabClient
class PrefabClient
  def self.homes
    [{ 'name' => 'Test Home', 'uuid' => 'home-1', 'id' => 'hk-1' }]
  end

  def self.rooms(home)
    [{ 'name' => 'Living Room', 'uuid' => 'room-1' }]
  end

  def self.accessories(home, room)
    [{ 'name' => 'Light', 'uuid' => 'acc-1', 'characteristics' => { 'power' => true } }]
  end

  def self.scenes(home)
    [{ 'name' => 'Movie Time', 'uuid' => 'scene-1', 'accessories' => ['acc-1'] }]
  end
end

# Run sync
summary = HomekitSync.perform
puts summary
# => {:homes=>1, :rooms=>1, :accessories=>1, :scenes=>1}

# Verify idempotency
summary2 = HomekitSync.perform
puts 'Idempotent!' if summary == summary2
"
```

### 4. Webhook Endpoint (PRD 1.4)

#### Run webhook specs:
```bash
bundle exec rspec spec/requests/api/homekit_events_spec.rb
```

#### Test manually with Rails server:

**Start server:**
```bash
rails server
```

**In another terminal, test with curl:**

```bash
# Test 1: Valid request (requires credentials setup)
curl -X POST http://localhost:3000/api/homekit/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk_live_eureka_abc123xyz789" \
  -d '{
    "type": "characteristic_updated",
    "accessory": "Front Door Lock",
    "characteristic": "Lock Current State",
    "value": 1,
    "timestamp": "2026-01-25T15:12:34Z"
  }'
# Expected: HTTP 200 OK

# Test 2: Missing auth header
curl -X POST http://localhost:3000/api/homekit/events \
  -H "Content-Type: application/json" \
  -d '{"type": "test"}'
# Expected: HTTP 401 {"error":"Unauthorized"}

# Test 3: Invalid token
curl -X POST http://localhost:3000/api/homekit/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid_token" \
  -d '{"type": "test"}'
# Expected: HTTP 401 {"error":"Unauthorized"}
```

**Verify events were stored:**
```bash
rails runner "puts HomekitEvent.all.to_json"
```

## Integration Testing

### Full End-to-End Test

```bash
# 1. Clear database
rails db:reset

# 2. Run migrations
rails db:migrate

# 3. Run sync (with live Prefab or mocked data)
rails homekit:sync

# 4. Verify data
rails runner "
puts 'Homes: ' + Home.count.to_s
puts 'Rooms: ' + Room.count.to_s
puts 'Accessories: ' + Accessory.count.to_s
puts 'Scenes: ' + Scene.count.to_s
"

# 5. Test webhook (with server running)
curl -X POST http://localhost:3000/api/homekit/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk_live_eureka_abc123xyz789" \
  -d '{"type":"characteristic_updated","accessory":"Test","value":1}'

# 6. Verify event was stored
rails runner "puts HomekitEvent.last.inspect"
```

## Credentials Setup (Required for Webhook)

The webhook endpoint requires a Bearer token stored in Rails credentials.

**To setup:**
```bash
EDITOR="code --wait" rails credentials:edit
```

**Add:**
```yaml
prefab_webhook_token: sk_live_eureka_abc123xyz789
```

**Verify:**
```bash
rails runner "puts Rails.application.credentials.prefab_webhook_token"
```

## Test Coverage Summary

- **Total Specs:** 56
- **Model Specs:** 7 (Home associations, validations, cascade deletion)
- **PrefabClient Specs:** 17 (All HTTP methods, error handling, URL encoding)
- **HomekitSync Specs:** 18 (Full workflow, idempotency, scene associations)
- **Webhook Specs:** 14 (Auth, error handling, CSRF bypass)

## Common Issues

### Issue: Prefab not running
**Solution:** Tests use WebMock to mock HTTP requests. Manual testing requires Prefab on localhost:8080.

### Issue: Credentials not found
**Solution:** Run `rails credentials:edit` and add `prefab_webhook_token`.

### Issue: Database errors
**Solution:** Run `rails db:migrate` and `rails db:test:prepare`.

### Issue: Port 3000 already in use
**Solution:** Kill existing server: `pkill -f 'puma.*3000'` or use different port: `rails s -p 3001`

## Success Criteria

✅ All 56 RSpec tests pass
✅ Models can be created with associations
✅ Sync task runs without errors
✅ Webhook accepts authenticated requests
✅ Database properly stores HomeKit data
✅ Idempotency works (sync can run multiple times)
✅ Scene-accessory many-to-many relationships work
✅ Error handling logs failures without crashing

## Next Steps

After testing Epic 1, you can:
1. Review and merge the feature branch to main
2. Deploy to staging/production
3. Configure Prefab to send webhooks to your Rails server
4. Set up periodic sync with `whenever` gem or cron
5. Begin Epic 2 (AI integration with Ollama)
