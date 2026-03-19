#### PRD-9-06: Eureka-Homekit API Integration via Smart-Proxy

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-9-06-api-integration-feedback-V{{N}}.md` in the same directory.

---

### Overview

This PRD defines the API contract between the Eureka Smart Speaker (Pi edge agent) and the eureka-homekit Rails application. Communication is routed through nextgen-plaid/smart-proxy for HTTPS termination and security. The Rails app receives context-enriched queries (transcribed text + presence data), processes them via the AI agent (Epic 7), and returns responses that the speaker converts to audio.

This PRD involves both **Rails server-side code** (new API endpoints, controller, routing) and **Python edge-side code** (HTTP client for API calls).

---

### Requirements

#### Functional

**Rails API Endpoints (Server-Side):**

1. `POST /api/v1/speaker/wake`
   - Registers a wake event from the speaker.
   - Payload: `{"device_id": "uuid", "timestamp": "iso8601", "presence": {...}}`.
   - Response: `200 OK {"status": "acknowledged"}`.
   - Purpose: Logging, proactive context loading, conversation initialization.

2. `POST /api/v1/speaker/query`
   - Primary endpoint: sends transcribed text with presence context.
   - Payload:
     ```json
     {
       "device_id": "uuid",
       "text": "who's in the living room?",
       "presence": {
         "present": true,
         "count": 2,
         "positions": [{"x": 0.3, "y": 0.5, "confidence": 0.92}],
         "source": "mmwave+camera"
       },
       "conversation_id": "uuid-or-null",
       "timestamp": "iso8601"
     }
     ```
   - Response (streaming SSE or JSON):
     ```json
     {
       "response_text": "There are 2 people in the living room.",
       "audio_url": "/api/v1/speaker/tts/abc123.wav",
       "conversation_id": "uuid",
       "actions_taken": [],
       "follow_up_suggestions": ["Would you like me to turn on the lights?"]
     }
     ```
   - Delegates to AI agent service (Epic 7) with speaker-specific context.

3. `POST /api/v1/speaker/tts`
   - Generates TTS audio for given text using Ollama on M3 Ultra.
   - Payload: `{"text": "response text", "voice": "eureka", "format": "wav"}`.
   - Response: Streamed audio bytes (chunked transfer) or download URL.

4. `GET /api/v1/speaker/tts/:id`
   - Download a previously generated TTS audio file by ID.
   - Response: Audio file (WAV/MP3) with appropriate Content-Type.

5. `GET /api/v1/speaker/health`
   - Health check for the speaker API subsystem.
   - Response: `200 OK {"status": "ok", "ollama": "connected", "timestamp": "..."}`.

**Authentication:**
- Bearer token authentication: `Authorization: Bearer <SPEAKER_API_TOKEN>`.
- Token configured as environment variable on both Pi and Rails server.
- Rate limiting: 30 requests/minute per device_id.

**Smart-Proxy Configuration:**
- Route `/api/v1/speaker/*` through smart-proxy to eureka-homekit Rails app.
- HTTPS termination at smart-proxy level.
- WebSocket upgrade support for future streaming (optional in POC).

**Python Edge Client (Pi-Side):**
- `EurekaApiClient` class in `speaker/src/api/eureka_client.py`.
- Methods: `send_wake()`, `send_query(text, presence)`, `fetch_tts(text)`, `health_check()`.
- Handles: retries (3 attempts, exponential backoff), timeouts (5s connect, 30s read), error responses.
- Stores conversation_id for multi-turn context.

#### Non-Functional

- API response latency (query → response text): < 2 seconds (excluding TTS generation).
- TTS generation latency: < 3 seconds for sentences up to 200 characters.
- API availability: must handle server downtime gracefully (retry + local fallback).
- All traffic encrypted via HTTPS (smart-proxy).
- No PII transmitted beyond transcribed voice text and anonymized presence counts.

#### Rails / Implementation Notes

**New Files (Rails Side):**
```
app/controllers/api/v1/speaker_controller.rb
config/routes.rb (add API routes)
test/controllers/api/v1/speaker_controller_test.rb
```

**Controller:**
```ruby
# app/controllers/api/v1/speaker_controller.rb
module Api
  module V1
    class SpeakerController < ApplicationController
      before_action :authenticate_speaker!
      
      def wake
        # Log wake event, initialize conversation context
      end
      
      def query
        # Validate params, delegate to AI agent, return response
      end
      
      def tts
        # Generate TTS via Ollama, stream audio
      end
      
      def tts_download
        # Serve previously generated TTS file
      end
      
      def health
        # Check subsystem health
      end
      
      private
      
      def authenticate_speaker!
        # Verify Bearer token
      end
    end
  end
end
```

**Routes:**
```ruby
namespace :api do
  namespace :v1 do
    resource :speaker, only: [], controller: 'speaker' do
      post :wake
      post :query
      post :tts
      get 'tts/:id', action: :tts_download, as: :tts_download
      get :health
    end
  end
end
```

**Integration with Epic 7 (AI Agent):**
- The `query` action delegates to the existing `AiAgentService` (or equivalent) from Epic 7.
- Speaker queries are tagged with `source: "speaker"` for analytics.
- Presence context is injected into the AI agent's RAG context alongside home topology data.

---

### Error Scenarios & Fallbacks

- **Smart-proxy unreachable from Pi** → Retry 3 times with exponential backoff (1s, 2s, 4s). If all fail, play error chime, speak fallback message via gTTS: "I'm having trouble connecting to the server."
- **Bearer token invalid/expired** → Server returns 401. Pi logs error, does not retry (token must be refreshed manually).
- **Query timeout (> 5s)** → Pi cancels request, plays "I'm taking longer than expected, please try again."
- **Ollama TTS unavailable** → Server returns 503 for TTS endpoint. Pi falls back to gTTS.
- **Malformed presence payload** → Server validates and returns 422 with error details. Pi logs and retries without presence data.
- **Rate limit exceeded** → Server returns 429. Pi backs off for 60 seconds.
- **Conversation context lost** → If conversation_id is invalid, server starts new conversation. Pi stores new conversation_id.

---

### Architectural Context

This PRD is the bridge between edge (Pi) and server (M3 Ultra). It connects:
- PRD 9-03 (STT output: transcribed text) → API query payload.
- PRD 9-04 (Presence output: context JSON) → API query payload.
- API response → PRD 9-05 (TTS playback: audio URL or streamed audio).

```
Pi Edge                          smart-proxy                    M3 Ultra Server
────────                         ───────────                    ────────────────
[STT text] ─┐
             ├→ POST /query ──→ HTTPS proxy ──→ SpeakerController#query
[Presence]  ─┘                                        │
                                                      ├→ AiAgentService (Epic 7)
                                                      ├→ HomeContextBuilder (RAG)
                                                      ├→ Ollama (LLM response)
                                                      │
                                               Response JSON ◄──┘
                                                      │
[TTS fetch] ◄── POST /tts ◄── HTTPS proxy ◄── Ollama TTS audio
     │
[Audio play] → HiFiBerry Amp4 → Speaker
```

The Rails controller is intentionally thin — it validates, authenticates, and delegates to existing services. No new models are needed (reuse Conversation/Message from Epic 7). The speaker is treated as another client of the AI agent, like the web chat UI.

Smart-proxy routing must be configured to forward the `/api/v1/speaker` namespace. If smart-proxy uses nginx-style config, add a location block for the prefix.

---

### Acceptance Criteria

- [ ] `POST /api/v1/speaker/wake` returns 200 and logs wake event
- [ ] `POST /api/v1/speaker/query` accepts text + presence, returns AI response
- [ ] `POST /api/v1/speaker/tts` generates audio and returns it (streamed or URL)
- [ ] `GET /api/v1/speaker/tts/:id` serves generated audio file
- [ ] `GET /api/v1/speaker/health` returns subsystem status
- [ ] Bearer token authentication enforced on all endpoints
- [ ] Invalid/missing token returns 401 Unauthorized
- [ ] Rate limiting enforced (429 on excess)
- [ ] Python `EurekaApiClient` successfully calls all endpoints
- [ ] Retry logic works: 3 attempts with exponential backoff
- [ ] End-to-end: Pi sends query → server responds → Pi receives response text + audio
- [ ] Smart-proxy routes correctly (HTTPS, no CORS issues)
- [ ] Minitest coverage for all controller actions

---

### Test Cases

#### Unit (Minitest — Rails)

- `test/controllers/api/v1/speaker_controller_test.rb`:
  - `test_wake_with_valid_token` → 200 OK
  - `test_wake_without_token` → 401 Unauthorized
  - `test_query_with_text_and_presence` → 200 with response_text
  - `test_query_with_empty_text` → 422 Unprocessable Entity
  - `test_query_without_presence` → 200 (presence optional)
  - `test_tts_generates_audio` → 200 with audio content-type
  - `test_tts_with_invalid_voice` → 422
  - `test_health_check` → 200 with status "ok"
  - `test_rate_limiting` → 429 after exceeding limit

#### Unit (pytest — Python edge)

- `tests/test_eureka_client.py`:
  - Test `send_wake()` with mock server → 200 response parsed
  - Test `send_query()` with mock server → response text extracted
  - Test `fetch_tts()` with mock server → audio bytes received
  - Test retry on 500 error → retries 3 times then returns None
  - Test timeout handling → returns None after timeout
  - Test `health_check()` → returns status dict

#### Integration (Minitest — Rails)

- `test/integration/speaker_api_test.rb`:
  - Full query flow: wake → query → tts → verify conversation created
  - Multi-turn: query → query with same conversation_id → context preserved

#### System / Smoke

- Manual: curl from Pi to server through smart-proxy — verify all endpoints respond.

---

### Manual Verification

1. **Server-side:** Start Rails server. Run `curl` tests:
   ```bash
   # Health check
   curl -H "Authorization: Bearer $TOKEN" https://your-proxy/api/v1/speaker/health
   
   # Wake
   curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"device_id":"test-pi","timestamp":"2026-03-01T12:00:00Z"}' \
     https://your-proxy/api/v1/speaker/wake
   
   # Query
   curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"device_id":"test-pi","text":"what is the temperature?","presence":{"present":true,"count":1}}' \
     https://your-proxy/api/v1/speaker/query
   ```
2. **Pi-side:** Run Python client test: `python -m src.api.eureka_client --test`.
3. Verify response text received and logged.
4. Verify TTS audio downloaded/streamed successfully.

**Expected**
- All endpoints return expected status codes and payloads.
- Smart-proxy passes requests correctly.
- Python client handles all response types.

---

### Rollout / Deployment Notes

- **Environment Variables (Pi):**
  - `EUREKA_API_URL=https://your-proxy/api/v1/speaker`
  - `EUREKA_API_TOKEN=<bearer-token>`
  - `EUREKA_DEVICE_ID=<pi-serial-or-uuid>`
- **Environment Variables (Rails server):**
  - `SPEAKER_API_TOKEN=<same-bearer-token>`
  - `OLLAMA_TTS_URL=http://localhost:11434` (Ollama local endpoint)
- **Smart-proxy config:** Add routing rule for `/api/v1/speaker/*` → eureka-homekit Rails app.
- **Migrations:** None needed if reusing Epic 7 Conversation/Message models. If Epic 7 is not yet implemented, this PRD creates minimal models or uses a simpler request/response pattern.
- **CORS:** Not needed (Pi makes server-to-server calls, not browser requests).
