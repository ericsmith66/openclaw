# Epic 1: Initial Rails Server Setup with Prefab Integration

## Product Requirements Document

### Objectives
1. Set up Rails API endpoints to receive Prefab webhook callbacks
2. Query Prefab's REST API to get the current HomeKit instance shape/structure
3. Store HomeKit device/accessory data for AI decision-making

### Current State
- ✅ Prefab listener running on port 4567 (`ruby prefab-listener/agent.rb &`)
- ✅ Prefab configured to send webhooks to `http://localhost:3000/api/homekit/events`
- ✅ Prefab HTTP API available at `http://localhost:8080`
- ⏳ Rails server needs webhook endpoint + Prefab integration

### Requirements

#### 1. Rails Webhook Receiver
**Endpoint**: `POST /api/homekit/events`
- Accept JSON payloads from Prefab
- Validate `Authorization: Bearer <token>` header
- Parse events: `characteristic_updated`, `homes_updated`
- Store in `HomeKitEvent` model (accessory, characteristic, value, timestamp)

**Example Payload**:
```json
{
  "type": "characteristic_updated",
  "accessory": "Front Door",
  "characteristic": "Lock Current State",
  "value": 1,
  "timestamp": "2026-01-25T15:12:34Z"
}
```

#### 2. Prefab REST API Client
**Purpose**: Query Prefab to understand HomeKit structure

Create service to fetch from `http://localhost:8080`:
- `GET /homes` - List all homes
- `GET /rooms/:home` - Rooms per home
- `GET /accessories/:home/:room` - Accessories per room with characteristics

Store in models:
- `Home` (name, uuid)
- `Room` (name, uuid, home_id)
- `Accessory` (name, uuid, room_id, characteristics JSON)

#### 3. Initial Data Sync
**Rake task**: `rails homekit:sync`
- Query Prefab API (`http://localhost:8080`)
- Populate database with current HomeKit structure
- Run on server startup or manually

#### 4. Database Schema
```ruby
# homes
- id: bigint (primary key)
- name: string
- uuid: string
- homekit_home_id: string
- created_at: datetime
- updated_at: datetime

# rooms
- id: bigint (primary key)
- name: string
- uuid: string
- home_id: bigint (foreign key)
- created_at: datetime
- updated_at: datetime

# accessories
- id: bigint (primary key)
- name: string
- uuid: string
- room_id: bigint (foreign key)
- characteristics: jsonb
- created_at: datetime
- updated_at: datetime

# homekit_events
- id: bigint (primary key)
- event_type: string
- accessory_name: string
- characteristic: string
- value: jsonb
- raw_payload: jsonb
- timestamp: datetime
- created_at: datetime
- updated_at: datetime
```

#### 5. Authentication & Security
- Validate `Authorization: Bearer sk_live_eureka_abc123xyz789` header on webhook endpoint
- Store auth token in Rails credentials
- Skip CSRF for API endpoints

### Technical Implementation

#### Controllers
- `Api::HomekitEventsController#create` - Webhook receiver

#### Services
- `PrefabClient` - HTTP client for Prefab REST API
- `HomekitSync` - Orchestrates data sync from Prefab

#### Models
- `Home`
- `Room`
- `Accessory`
- `HomekitEvent`

### Success Criteria
- ✅ Rails receives and logs Prefab webhooks at `/api/homekit/events`
- ✅ Database contains current HomeKit structure from Prefab API
- ✅ Events stored with accessory context for AI processing
- ✅ `rails homekit:sync` successfully populates database
- ✅ Auth token validation working on webhook endpoint

### Next Steps After This Epic
1. Generate Rails models & migrations
2. Create API controller with auth
3. Build Prefab HTTP client service
4. Write sync rake task
5. Test with live Prefab callbacks
6. Add Sidekiq for async event processing
7. Integrate Ollama for AI decision-making
8. Connect to nextgen-plaid/smart-proxy

### Testing
- Unit tests for PrefabClient
- Integration tests for webhook endpoint
- Test sync task with mock Prefab responses

### Dependencies
- Prefab running on localhost:8080
- PostgreSQL database
- HTTParty or Faraday gem for HTTP requests

---

**Epic Created**: 2026-01-25
**Status**: Planning
**Owner**: @ericsmith66
