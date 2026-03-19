# Future Epics Roadmap

**Document Purpose**: High-level overview of planned epics beyond Epic 5 to guide long-term product development.

**Last Updated**: 2026-02-08

---

## Roadmap Overview

This document outlines the strategic vision for the eureka-homekit platform beyond the current Interactive Controls epic (Epic 5). Each future epic builds on prior capabilities to create a comprehensive HomeKit management and automation platform.

### Dependency Chain

```
Epic 1: Bootstrap & Prefab Integration (✅ Complete)
  ↓
Epic 2: Read-Only Monitoring UI (✅ Complete)
  ↓
Epic 3: Floorplan Navigation (🔄 In Progress)
  ↓
Epic 5: Interactive Controls (📋 Backlog - NEXT)
  ↓
Epic 6: AI Conversational Agent (📋 Backlog)
  ↓
Epic 7: Automation Rules Engine
  ↓
Epic 8: Advanced Analytics & Insights
  ↓
Epic 9: Smart Speaker POC — Assembly & Integration (📋 NEW)
  ↓
Epic 10: Multi-User & Security
  ↓
Epic 11: Mobile & Voice Integration
  ↓
Epic 12: Camera & Media Streaming
```

---

## Epic 5: AI Conversational Agent for Home Intelligence

**Status**: Planned
**Dependencies**: Epic 2 (Monitoring), Epic 3 (Floorplan - optional), Epic 6 (Controls - optional)
**Estimated Duration**: 5-8 weeks
**Strategic Value**: Very High - transforms UI into intelligent conversational interface

### Overview

Introduce an AI-powered conversational agent with a Grok-like chat interface that has deep understanding of the entire HomeKit infrastructure. Users can ask questions, execute commands, troubleshoot issues, and receive intelligent insights through natural language conversation instead of navigating complex UI.

The agent uses RAG (Retrieval-Augmented Generation) to build context from the home database (sensors, rooms, events, automation rules) and leverages Claude 3.5 Sonnet or GPT-4o to provide intelligent, context-aware responses.

### User Capabilities

- **Natural language queries**: "What's the temperature in the living room?" → instant answer
- **Complex analysis**: "Which rooms use the most energy this month?" → data-driven insights with charts
- **Voice-like commands**: "Turn off all lights except bedroom" → execute multiple actions
- **Troubleshooting**: "Why didn't my automation run last night?" → analyze logs and explain
- **Proactive suggestions**: "It's getting cold—should I adjust the thermostat?" → smart recommendations
- **Multi-turn conversations**: "Turn on living room light" → "Make it dimmer" → "Perfect, keep it like this"
- **Historical analysis**: "Show bedroom temperature trends for the past week" → generate graphs
- **Conversational automation**: "When I leave home, turn off all lights" → create rule via chat (Epic 7 integration)

### Key Features

**Conversational Interface**:
- ChatGPT/Claude-style chat UI with streaming responses
- Left sidebar: conversation history
- Main area: message bubbles (user/assistant)
- Input bar with suggested prompts
- Markdown rendering (code blocks, tables, charts)
- Action buttons inline ("Execute this command?")

**RAG Context Builder**:
- Embed home topology (homes, rooms, accessories, sensors) into LLM context
- Include recent sensor readings (last 24 hours by default)
- Include automation rules (if Epic 7 complete)
- Include event history for troubleshooting
- Smart context windowing (summarize old data, detail recent data)

**Intent Classification**:
- Query: answering questions about state
- Command: executing device controls
- Analysis: generating insights from historical data
- Troubleshooting: diagnosing issues
- Suggestion: proactive recommendations

**Action Execution**:
- Natural language → structured command → PrefabControlService
- Confirmation required for sensitive actions (unlock doors, open garage)
- Batch actions: "Turn off all living room lights" → multiple API calls
- Rollback on partial failure with explanation

**Proactive Intelligence**:
- Pattern detection: "You usually turn on bedroom lights at 9 PM—would you like an automation?"
- Anomaly alerts: "Living room temperature is unusually high (82°F vs typical 72°F)"
- Energy recommendations: "Running thermostat at 68°F instead of 72°F could save $30/month"
- Maintenance reminders: "Front door lock battery at 15%—time to replace"

### Technical Architecture

**AI Stack**:
- **LLM**: Claude 3.5 Sonnet (Anthropic) or GPT-4o (OpenAI)
- **Framework**: LangChain for agent orchestration and tool calling
- **RAG**: Build context from PostgreSQL queries (no vector DB initially)
- **Streaming**: Server-Sent Events (SSE) for word-by-word responses

**New Models**:
- `Conversation` (user_id, session_id, title, last_message_at)
- `Message` (conversation_id, role: user/assistant, content, metadata, timestamp)
- `AgentAction` (message_id, action_type, parameters, result, success, cost)
- `ConversationContext` (conversation_id, context_type, context_data: jsonb)

**Services**:
- `AiAgentService` - LangChain orchestrator
- `ConversationManager` - CRUD for conversations
- `HomeContextBuilder` - build RAG context from DB
- `IntentClassifier` - classify user intent
- `ActionExecutor` - execute commands (delegates to PrefabControlService)
- `ResponseFormatter` - format responses with markdown, charts

**Tools (LangChain)**:
- `get_sensor_value(sensor_id)` → current value
- `list_sensors_by_room(room_id)` → all sensors
- `get_room_info(room_id)` → room details
- `control_accessory(accessory_id, characteristic, value)` → execute command
- `query_events(filters)` → historical data
- `analyze_energy_usage(time_range)` → generate insights

### PRD Breakdown

| PRD | Title | Scope |
|-----|-------|-------|
| 5-01 | Conversation Data Model | Database schema, CRUD operations |
| 5-02 | LLM Integration & Agent Setup | Claude/GPT API, LangChain, tool definitions |
| 5-03 | RAG Context Builder | Build home context for LLM prompts |
| 5-04 | Intent Classification & Routing | Classify intent, route to appropriate tools |
| 5-05 | Action Execution via NLP | Execute commands from natural language |
| 5-06 | Chat UI & Streaming | React chat interface, SSE streaming |
| 5-07 | Proactive Suggestions | Pattern-based recommendations |
| 5-08 | Analytics & Cost Tracking | Monitor usage, cost, performance |

### Success Metrics

- Query accuracy >80% (manual evaluation)
- Command execution success rate >90%
- Average response latency <2 seconds
- Cost per conversation <$0.05
- User engagement: 30%+ use agent weekly
- Average conversation length: 3-5 messages

### Example Interactions

**Query:**
```
User: What's the temperature in the living room?
Agent: The living room is currently 72°F (22°C). The thermostat target is 70°F. Would you like me to adjust it?
```

**Command:**
```
User: Turn off all lights except bedroom
Agent: Turning off 12 lights, keeping bedroom lights on...
Done! Bedroom ceiling light (80%) and bedroom lamp (50%) remain on.
```

**Analysis:**
```
User: Which rooms use the most energy?
Agent: Based on the past 30 days:
1. Living Room: 45 kWh/month (thermostat, TV)
2. Kitchen: 32 kWh/month (outlets, lights)
3. Office: 28 kWh/month

Would you like recommendations to reduce usage?
```

---

## Epic 6: Interactive Controls (formerly Epic 5)

**Status**: Planned
**Dependencies**: Epic 5 (Interactive Controls)
**Estimated Duration**: 5-7 weeks
**Strategic Value**: High - enables "smart home" automation without scripting

### Overview

Transform the platform from manual control to intelligent automation by building a visual rule engine for creating HomeKit automations. Users define triggers (sensor events, time schedules, conditions) and actions (control accessories, execute scenes) through an intuitive UI.

### User Capabilities

- Create automation rules: "When motion detected in hallway after 10 PM, turn on lights at 20% brightness"
- Time-based schedules: "Turn off all lights at midnight"
- Multi-condition triggers: "If temperature > 75°F AND time is 2-6 PM, set thermostat to 72°F"
- Geofencing: "When arriving home, unlock front door and turn on entry lights"
- Scene triggers: "After 'Good Night' scene, wait 5 minutes then lock all doors"
- Rule templates library: Pre-built automations for common scenarios
- Rule history and debugging: See when rules triggered and what actions were taken

### Key Features

**Rule Builder UI**:
- Drag-and-drop visual editor (flow chart style)
- Trigger selection (sensor event, time, scene, geofence, manual)
- Condition builder (AND/OR logic, sensor value comparisons)
- Action builder (set characteristics, execute scenes, delays, notifications)

**Rule Types**:
1. **Event-Driven**: Sensor value changes trigger actions
2. **Time-Based**: Cron-style schedules (daily, weekly, sunrise/sunset)
3. **Conditional**: "If X and Y, then Z"
4. **Composite**: Chain multiple rules together

**Rule Management**:
- Enable/disable rules without deleting
- Rule testing mode (dry run)
- Rule execution logs with timestamps
- Rule performance metrics (execution time, success rate)

### Technical Architecture

**New Models**:
- `AutomationRule` (name, enabled, trigger_type, conditions, actions)
- `RuleTrigger` (polymorphic: TimeTrigger, SensorTrigger, SceneTrigger, GeofenceTrigger)
- `RuleCondition` (sensor_id, operator, value, logic: AND/OR)
- `RuleAction` (polymorphic: SetCharacteristic, ExecuteScene, Delay, Notify)
- `RuleExecution` (rule_id, triggered_at, completed_at, success, error)

**Background Jobs**:
- `AutomationRuleEvaluator` - checks conditions and executes actions
- `TimeBasedRuleScheduler` - Solid Queue cron jobs for scheduled rules
- `SensorEventListener` - ActionCable subscription to trigger event-driven rules

**UI Components**:
- `Rules::BuilderComponent` - visual rule editor
- `Rules::TriggerSelectorComponent` - choose trigger type
- `Rules::ConditionBuilderComponent` - build condition logic
- `Rules::ActionBuilderComponent` - define actions
- `Rules::HistoryComponent` - execution history timeline

### PRD Breakdown

| PRD | Title | Scope |
|-----|-------|-------|
| 6-01 | Rule Data Model & Engine | Core rule execution engine, models, background jobs |
| 6-02 | Time-Based Rules | Cron scheduler, sunrise/sunset, time conditions |
| 6-03 | Event-Driven Rules | Sensor triggers, scene triggers, rule chaining |
| 6-04 | Visual Rule Builder UI | Drag-and-drop editor, condition/action builders |
| 6-05 | Rule Templates Library | Pre-built automations for common scenarios |
| 6-06 | Rule Testing & Debugging | Dry run mode, execution logs, performance metrics |

### Success Metrics

- Users can create 80%+ of common automations without code
- Rule execution latency <2 seconds from trigger to action
- Rule success rate >95%
- Average user creates 5+ automation rules
- Template usage rate >60% for first automation

---

## Epic 8: Advanced Analytics & Insights

**Status**: Planned
**Dependencies**: Epic 2 (Monitoring), Epic 5 (Controls), Epic 6 (Automations)
**Estimated Duration**: 4-6 weeks
**Strategic Value**: Medium-High - adds intelligence and predictive insights

### Overview

Transform raw sensor data into actionable insights through advanced analytics, machine learning predictions, and intelligent recommendations. Users gain deeper understanding of home patterns, energy usage, and optimization opportunities.

### User Capabilities

- **Energy Analytics**: Track energy consumption by accessory, room, time of day
- **Pattern Recognition**: "Living room lights are typically on 7-10 PM weekdays"
- **Anomaly Detection**: Alerts for unusual patterns (door unlocked at 3 AM, temperature spike)
- **Predictive Insights**: "Based on weather forecast, pre-cool home at 2 PM"
- **Optimization Recommendations**: "Adjusting thermostat schedule could save 15% energy"
- **Comparative Analytics**: Compare usage across rooms, time periods, homes
- **Custom Dashboards**: Drag-and-drop widgets for personalized analytics views

### Key Features

**Analytics Dashboards**:
1. **Energy Dashboard**: kWh usage, cost estimates, trends, comparisons
2. **Activity Dashboard**: Room occupancy patterns, motion heatmaps, usage graphs
3. **Environmental Dashboard**: Temperature/humidity trends, comfort scores, air quality
4. **Security Dashboard**: Access logs, lock events, door/window states, alerts

**Machine Learning Features**:
- **Occupancy Prediction**: Learn typical home/away patterns
- **Optimal Scheduling**: Recommend automation schedules based on usage history
- **Anomaly Detection**: Flagging unusual sensor readings or access patterns
- **Comfort Optimization**: Learn preferred temperatures by time/occupancy

**Reporting**:
- Weekly/monthly summary emails
- PDF export for detailed reports
- CSV export for raw data analysis
- Integration with Google Sheets/Excel

### Technical Architecture

**New Services**:
- `AnalyticsEngine` - calculate metrics, trends, comparisons
- `PatternRecognizer` - detect usage patterns using time-series analysis
- `AnomalyDetector` - flag unusual events (z-score, isolation forest)
- `PredictionService` - ML models for occupancy/usage predictions
- `RecommendationEngine` - suggest optimizations based on analysis

**Data Storage**:
- `AnalyticsSnapshot` - daily/hourly aggregated metrics
- `UsagePattern` - detected patterns with confidence scores
- `Anomaly` - flagged unusual events
- `Prediction` - forecasted values with confidence intervals

**Background Jobs**:
- `DailyAnalyticsAggregator` - roll up event data into daily summaries
- `PatternDetectionJob` - run weekly to detect new patterns
- `AnomalyDetectionJob` - run hourly to flag unusual events
- `PredictionModelTrainer` - retrain ML models monthly

### PRD Breakdown

| PRD | Title | Scope |
|-----|-------|-------|
| 7-01 | Analytics Data Pipeline | Aggregation, storage, query optimization |
| 7-02 | Energy Analytics Dashboard | kWh tracking, cost estimates, trends |
| 7-03 | Activity & Occupancy Analytics | Motion patterns, room usage, heatmaps |
| 7-04 | Pattern Recognition Engine | Detect usage patterns, typical schedules |
| 7-05 | Anomaly Detection System | Flag unusual events, security alerts |
| 7-06 | Predictive Insights | ML models for forecasting, recommendations |
| 7-07 | Custom Dashboard Builder | Drag-and-drop widgets, personalization |

### Success Metrics

- Analytics dashboards load in <1 second
- Anomaly detection accuracy >90% (low false positive rate)
- Pattern recognition identifies 70%+ of recurring schedules
- Users engage with analytics 2+ times per week
- Recommendations accepted rate >30%

---

## Epic 9: Multi-User & Security

**Status**: Planned
**Dependencies**: Epic 5 (Controls), Epic 6 (Automations)
**Estimated Duration**: 4-5 weeks
**Strategic Value**: High - enables family sharing and security compliance

### Overview

Transform from single-user assumption to multi-user household platform with role-based access control, user authentication, activity audit logs, and security hardening. Enable families to safely share access with appropriate permissions.

### User Capabilities

- **User Accounts**: Email/password authentication, OAuth (Google, Apple)
- **Role-Based Access**: Admin, Operator, Viewer, Guest roles
- **Granular Permissions**: Control access by room, accessory type, or specific devices
- **Family Sharing**: Invite family members, assign roles, revoke access
- **Guest Access**: Time-limited access codes for visitors, cleaners, contractors
- **Activity Audit Log**: Who did what, when, from where (IP tracking)
- **Security Alerts**: Notifications for suspicious activity (failed logins, unauthorized access)
- **Session Management**: Active sessions view, remote logout

### Key Features

**Authentication**:
- Email/password with bcrypt
- OAuth2 (Google, Apple ID)
- Two-factor authentication (TOTP)
- Password reset via email
- Session timeout (configurable)

**Authorization**:
- Role hierarchy: Admin > Operator > Viewer > Guest
- Permission matrix:
  - **Admin**: Full control (add users, manage rules, control all accessories)
  - **Operator**: Control accessories, execute scenes, view analytics
  - **Viewer**: Read-only access to sensors, events, analytics
  - **Guest**: Limited access to specific rooms/accessories with expiration

**Access Control**:
- Room-level permissions: "Guest can control living room lights only"
- Accessory-type restrictions: "Operator cannot unlock doors"
- Time-based access: "Guest access expires in 24 hours"
- IP whitelisting: "Only allow access from home network"

**Audit & Security**:
- Full audit log of all control actions with user attribution
- Failed login tracking and lockout after 5 attempts
- Suspicious activity alerts (new device, unusual location)
- GDPR compliance (data export, account deletion)

### Technical Architecture

**New Models**:
- `User` (devise-based: email, encrypted_password, role, created_at)
- `UserPermission` (user_id, resource_type, resource_id, permission_level)
- `AccessCode` (code, user_id, expires_at, usage_count, max_uses)
- `AuditLog` (user_id, action, resource_type, resource_id, ip_address, user_agent, timestamp)
- `Session` (user_id, token, ip_address, user_agent, last_activity, expires_at)

**Authentication**:
- Devise gem for user management
- OmniAuth for OAuth2 providers
- Rotp gem for TOTP 2FA
- Rack::Attack for rate limiting

**Authorization**:
- Pundit gem for policy-based authorization
- `AccessoryPolicy`, `ScenePolicy`, `RoomPolicy` classes
- Middleware to check permissions on all control endpoints

### PRD Breakdown

| PRD | Title | Scope |
|-----|-------|-------|
| 8-01 | User Authentication System | Devise setup, OAuth, 2FA, session management |
| 8-02 | Role-Based Access Control | Roles, permissions, policy classes |
| 8-03 | Family Sharing & Invitations | Invite users, assign roles, manage access |
| 8-04 | Guest Access Codes | Time-limited codes, usage tracking |
| 8-05 | Audit Log & Security Monitoring | Full activity tracking, suspicious activity alerts |
| 8-06 | GDPR Compliance | Data export, account deletion, privacy policy |

### Success Metrics

- Authentication setup time <5 minutes
- Zero unauthorized access incidents
- Audit log covers 100% of control actions
- Family sharing adoption rate >40% of households
- Guest access used for 20%+ of homes

---

## Epic 9: Smart Speaker POC — Assembly & Integration

**Status**: Planned (NEW)
**Dependencies**: Epic 7 (AI Agent), Epic 8 (Prefab Client Refactor)
**Estimated Duration**: 2.5–4.5 weeks
**Strategic Value**: Very High — extends platform into physical ambient computing

### Overview

Build a Raspberry Pi 5–based smart speaker POC named "Eureka" with far-field voice input (ReSpeaker XVF3800), on-device AI inference (Hailo-8 AI HAT+), person presence/detection (mmWave + camera + YOLO), custom TTS voice (Ollama on M3 Ultra), and high-fidelity audio output (HiFiBerry Amp4 + SB Acoustics driver). The Pi runs a lightweight Python edge agent that communicates with eureka-homekit via smart-proxy, offloading heavy AI processing to the server.

### User Capabilities

- Hands-free voice interaction: "Hey Eureka, who's in the living room?"
- Context-aware responses enriched with presence data (person count, position)
- High-fidelity audio output with a custom Eureka voice personality
- On-device person detection and presence sensing
- Seamless integration with all eureka-homekit features (controls, scenes, AI agent)
- Always-on proactive mode: greet occupants, announce events

### PRD Breakdown

| PRD | Title | Scope |
|-----|-------|-------|
| 9-01 | Hardware Assembly & Validation | Physical build, wiring, component tests |
| 9-02 | Raspberry Pi OS & Driver Setup | OS flash, drivers, interface enablement |
| 9-03 | Wake Word & STT Pipeline | Porcupine wake word + Whisper STT on Hailo-8 |
| 9-04 | Person Detection & Presence Sensing | mmWave UART + YOLO on camera via Hailo-8 |
| 9-05 | TTS Playback & Custom Eureka Voice | Ollama TTS on server, audio streaming, Amp4 playback |
| 9-06 | Eureka-Homekit API Integration | Rails API endpoints, smart-proxy, context payloads |
| 9-07 | Edge Agent Loop & Systemd Service | Main loop orchestration, systemd, health check |

### Success Metrics

- Wake word detection from 3+ meters with > 90% reliability
- End-to-end wake-to-response latency < 5 seconds
- 24-hour soak test without crash
- STT accuracy > 85% on home commands

---

## Epic 10: Mobile & Voice Integration

**Status**: Planned
**Dependencies**: Epic 5 (Controls), Epic 8 (Multi-User)
**Estimated Duration**: 6-8 weeks
**Strategic Value**: High - expands platform accessibility and convenience

### Overview

Extend platform beyond web browser to native mobile apps (iOS/Android) and voice assistant integrations (Siri Shortcuts, Alexa, Google Assistant). Enable users to control home from anywhere via mobile or voice commands.

### User Capabilities

**Mobile Apps**:
- Native iOS and Android apps with full feature parity to web
- Push notifications for alerts, rule triggers, security events
- Widgets for quick access to favorite controls
- Offline mode (cache sensor data, queue control commands)
- Geofencing triggers ("When leaving home, turn off lights")
- Camera integration with live feeds (Epic 10 dependency)

**Voice Assistants**:
- **Siri Shortcuts**: "Hey Siri, trigger Good Night scene"
- **Alexa Skills**: "Alexa, ask Eureka to lock the front door"
- **Google Assistant Actions**: "Hey Google, what's the living room temperature?"
- Natural language processing: "Turn on bedroom lights" → execute action
- Voice-triggered automations: "When I say 'Movie Time', dim lights and close blinds"

### Key Features

**Mobile App**:
- React Native or Flutter for cross-platform development
- Feature parity with web UI (sensors, controls, scenes, rules, analytics)
- Push notifications via Firebase Cloud Messaging (FCM) / Apple Push Notification Service (APNS)
- Biometric authentication (Face ID, Touch ID, fingerprint)
- Home/Away geofencing automation triggers
- Quick action widgets on home screen
- Offline mode with background sync

**Voice Integration**:
- Siri Shortcuts app with predefined actions
- Alexa Skill certification and distribution
- Google Assistant Action certification
- Natural language intent parsing (match phrases to actions)
- Voice feedback: "Front door locked successfully"
- Multi-step voice commands: "Alexa, ask Eureka to turn off all lights except bedroom"

**Notifications**:
- Push notifications for:
  - Security alerts (door unlocked, motion detected)
  - Automation rule triggers
  - Anomaly detections
  - Low battery warnings
  - System status (Prefab offline, sync errors)
- Notification preferences per event type
- Do Not Disturb scheduling

### Technical Architecture

**Mobile App Stack**:
- **Framework**: React Native or Flutter
- **State Management**: Redux (React Native) or Riverpod (Flutter)
- **API Client**: GraphQL or REST API (existing Rails endpoints)
- **Push Notifications**: Firebase Cloud Messaging
- **Offline Storage**: SQLite or Realm
- **Geofencing**: react-native-geolocation or geolocator (Flutter)

**Voice Assistant Integration**:
- **Siri Shortcuts**: iOS Intents extension
- **Alexa Skill**: AWS Lambda + Alexa Skills Kit
- **Google Assistant**: Dialogflow + Cloud Functions
- **NLP Engine**: Intent matching service (webhook to Rails API)

**API Enhancements**:
- GraphQL API for efficient mobile data fetching
- WebSocket subscriptions for real-time updates
- API rate limiting per user
- API versioning for backward compatibility

### PRD Breakdown

| PRD | Title | Scope |
|-----|-------|-------|
| 9-01 | Mobile App Foundation | React Native/Flutter setup, authentication, navigation |
| 9-02 | Mobile Controls UI | Replicate web controls in mobile app |
| 9-03 | Push Notifications | FCM/APNS integration, notification preferences |
| 9-04 | Geofencing Automations | Home/Away detection, location-based triggers |
| 9-05 | Offline Mode & Sync | SQLite caching, background sync, queue management |
| 9-06 | Siri Shortcuts Integration | iOS Intents, shortcut library |
| 9-07 | Alexa Skill Development | Lambda functions, skill certification |
| 9-08 | Google Assistant Actions | Dialogflow intents, Cloud Functions |
| 9-09 | Home Screen Widgets | iOS/Android widgets for quick access |

### Success Metrics

- Mobile app installs reach 70%+ of web users
- Mobile session length >3 minutes (comparable to web)
- Push notification opt-in rate >60%
- Voice command success rate >90%
- Geofencing triggers work within 100m accuracy

---

## Epic 11: Camera & Media Streaming

**Status**: Planned
**Dependencies**: Epic 9 (Mobile Apps)
**Estimated Duration**: 6-8 weeks
**Strategic Value**: Medium - completes feature parity with native HomeKit

### Overview

Add support for HomeKit camera feeds, doorbell integration, and media streaming (Apple TV, HomePod). Users can view live camera feeds, review recorded clips, receive doorbell notifications, and control media playback.

### User Capabilities

**Camera Integration**:
- Live camera feed viewing in web and mobile apps
- Doorbell notifications with snapshot preview
- Motion detection events from cameras
- Recorded clip playback (if camera supports)
- Multi-camera grid view
- Camera controls (pan, tilt, zoom if supported)
- Privacy zones (mask areas from view)

**Media Streaming**:
- Browse and play content on Apple TV
- Control HomePod playback (play, pause, volume, skip)
- Multi-room audio synchronization
- Now Playing widget with album art
- Voice-controlled media (via Epic 9 voice integration)

**Security Features**:
- Face recognition (if camera supports)
- Person detection alerts
- Package detection (doorbell cameras)
- Activity zones (only alert for motion in specific areas)
- Clip sharing (generate shareable links)

### Key Features

**Camera Streaming**:
- WebRTC for low-latency live streaming
- HLS fallback for compatibility
- Adaptive bitrate streaming (adjust to network conditions)
- Snapshot capture from live feed
- PiP (Picture-in-Picture) mode on mobile

**Doorbell Integration**:
- Real-time doorbell press notifications
- Quick reply with pre-recorded messages (if supported)
- Two-way audio (talk to visitor via app)
- Package delivery detection

**Recording & Playback**:
- Access HomeKit Secure Video recordings (if enabled)
- Clip timeline with motion events
- Download clips for archival
- Clip retention policy (30 days default)

**Privacy & Security**:
- End-to-end encryption for camera streams
- Camera access audit log (who viewed when)
- Privacy mode (disable camera remotely)
- Face blur for unknown persons

### Technical Architecture

**Streaming Infrastructure**:
- **WebRTC**: Direct peer-to-peer streaming for low latency
- **HLS**: HTTP Live Streaming for fallback
- **TURN Server**: NAT traversal for cameras behind firewalls
- **Media Server**: Janus or Kurento for stream processing

**Storage**:
- `CameraFeed` model (camera_id, stream_url, status, privacy_mode)
- `CameraClip` model (camera_id, start_time, end_time, file_url, thumbnail_url, event_type)
- `DoorbellEvent` model (camera_id, visitor_snapshot, timestamp, acknowledged)

**Background Jobs**:
- `CameraStreamHealthCheck` - monitor stream availability
- `ClipRetentionJob` - delete old clips per retention policy
- `FaceDetectionJob` - process clips for face recognition (optional)

### PRD Breakdown

| PRD | Title | Scope |
|-----|-------|-------|
| 10-01 | Camera Stream Integration | WebRTC/HLS streaming, live feed viewing |
| 10-02 | Doorbell Notifications | Push notifications, snapshot preview, two-way audio |
| 10-03 | Clip Recording & Playback | Access HSV recordings, timeline, download |
| 10-04 | Multi-Camera Grid View | Dashboard with multiple live feeds |
| 10-05 | Face Recognition | Person detection, face tagging, alerts |
| 10-06 | Privacy & Security | End-to-end encryption, privacy zones, audit log |
| 10-07 | Media Playback Controls | Apple TV, HomePod control, Now Playing widget |

### Success Metrics

- Camera stream latency <2 seconds
- Stream uptime >99%
- Doorbell notification delivery <5 seconds
- Face recognition accuracy >85%
- Media control success rate >95%

---

## Epic 12: Energy Management & Sustainability

**Status**: Exploratory
**Dependencies**: Epic 7 (Analytics)
**Estimated Duration**: 4-5 weeks
**Strategic Value**: Medium - aligns with sustainability trends

### Overview (Brief)

Advanced energy tracking with solar integration, utility bill analysis, carbon footprint calculation, and optimization recommendations. Users can track energy production/consumption, compare against utility bills, and receive actionable insights to reduce energy usage and carbon emissions.

**Key Features**:
- Solar panel monitoring (production, consumption, grid import/export)
- Utility bill integration (import bills via CSV or API)
- Carbon footprint calculation (kWh to CO2 equivalent)
- Cost analysis ($ per kWh, peak vs off-peak rates)
- Optimization recommendations (shift usage to off-peak, adjust thermostat)
- Energy challenges and gamification (reduce usage by 10% this month)

---

## Epic 13: Third-Party Integrations

**Status**: Exploratory
**Dependencies**: Epic 8 (Multi-User), Epic 9 (Mobile)
**Estimated Duration**: 5-6 weeks
**Strategic Value**: Medium - expands ecosystem compatibility

### Overview (Brief)

Connect with popular smart home platforms and services: IFTTT, Home Assistant, SmartThings, Philips Hue, Nest, Ecobee, Ring. Enable cross-platform automations and unified control.

**Key Features**:
- OAuth2 API for third-party access
- Webhook integrations (IFTTT, Zapier)
- Home Assistant MQTT bridge
- SmartThings integration
- Platform-specific adapters (Hue, Nest, Ring APIs)
- Integration marketplace (browse and install integrations)

---

## Prioritization Framework

### Epic Priority Matrix

| Epic | User Value | Technical Complexity | Dependencies | Priority |
|------|-----------|---------------------|--------------|----------|
| Epic 5: AI Agent | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Epic 2, 3 | **P0** (Next) |
| Epic 6: Interactive Controls | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Epic 5 (optional) | **P0** (Can parallel) |
| Epic 7: Automation | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Epic 6 | **P0** |
| Epic 9: Smart Speaker POC | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Epic 7, 8 | **P1** (Hardware + edge) |
| Epic 10: Multi-User | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Epic 6 | **P1** (Parallel with 7) |
| Epic 8: Analytics | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Epic 2, 6, 7 | **P1** |
| Epic 11: Mobile & Voice | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Epic 6, 10 | **P1** |
| Epic 12: Camera & Media | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Epic 11 | **P2** |
| Epic 13: Energy Mgmt | ⭐⭐⭐ | ⭐⭐⭐ | Epic 8 | **P2** |
| Epic 14: Integrations | ⭐⭐⭐ | ⭐⭐⭐⭐ | Epic 10, 11 | **P2** |

### Recommended Order

1. **Epic 5: AI Conversational Agent** - High value, transforms UX, can work with read-only data initially
2. **Epic 6: Interactive Controls** - Enable write operations for both UI and AI agent
3. **Epic 7: Automation Rules Engine** - Highest automation value, integrates with AI agent
4. **Epic 9: Multi-User & Security** - Can develop in parallel with Epic 7, essential for household sharing
5. **Epic 8: Advanced Analytics** - Builds on data collected from Epics 2, 5, 6, 7
6. **Epic 10: Mobile & Voice** - High value but high complexity, needs stable foundation
7. **Epic 11: Camera & Media** - Lower priority, high complexity, requires mobile apps
8. **Epic 12: Energy Management** - Nice-to-have, depends on analytics infrastructure
9. **Epic 13: Third-Party Integrations** - Extends ecosystem after core features mature

---

## Long-Term Vision (2-3 Years)

**Year 1 (Epics 1-7)**: Complete core platform with AI
- AI conversational interface
- Full read/write HomeKit control
- Visual automation builder
- Multi-user security

**Year 2 (Epics 8-10)**: Expand analytics and accessibility
- Advanced ML-powered insights
- Native mobile apps with push notifications
- Voice assistant integrations
- Predictive automations

**Year 3 (Epics 11-13)**: Complete ecosystem
- Camera and media streaming
- Energy management and sustainability
- Third-party platform integrations
- Enterprise/commercial features (optional)

---

## Notes

- Each epic will have detailed PRDs created before implementation (like Epic 5)
- Timelines are estimates and may adjust based on complexity and resources
- User feedback should inform prioritization adjustments
- Consider releasing MVPs (Minimum Viable Products) for each epic before full feature sets
- Security and privacy should be considered in all epics (not just Epic 8)

---

**Document Owner**: @ericsmith66
**Review Cadence**: Quarterly
**Next Review**: 2026-05-08
