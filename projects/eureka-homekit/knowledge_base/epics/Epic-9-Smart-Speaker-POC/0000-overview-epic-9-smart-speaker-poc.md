**Epic 9: Eureka Smart Speaker POC — Assembly & Integration**

**Epic Overview**

This epic covers the end-to-end build-out of a Raspberry Pi 5–based smart speaker Proof of Concept (POC) named "Eureka." The POC combines far-field voice input, person presence/detection, custom TTS output (Eureka voice), and on-device AI inference into a single physical appliance that communicates with the existing `eureka-homekit` Ruby on Rails application running on an M3 Ultra server (Postgres, Ollama, nextgen-plaid/smart-proxy).

The user-facing outcome is a desk-/shelf-mountable smart speaker that:
1. Wakes on "Hey Eureka" via the ReSpeaker XVF3800 far-field mic array.
2. Transcribes speech locally (Whisper on Hailo-8 AI HAT+).
3. Detects room occupancy via Seeed 24 GHz mmWave radar + Arducam Camera Module 3 Wide (YOLO on Hailo-8).
4. Sends context-enriched queries to eureka-homekit through smart-proxy.
5. Receives and plays back responses with a custom Eureka TTS voice cloned via Ollama on the M3 Ultra server.
6. Outputs high-quality audio through a HiFiBerry Amp4 + SB Acoustics SB65WBAC25-4 full-range driver.

The project forks the Prefab repo (`ericsmith66/prefab-fork`) as the root project base and uses Aider Desktop for code modifications.

**User Capabilities**

- Hands-free voice interaction: "Hey Eureka, who's in the living room?"
- Context-aware responses enriched with presence data (person count, position).
- High-fidelity audio output with a custom Eureka voice personality.
- On-device person detection and presence sensing (mmWave + camera + AI HAT+).
- Seamless integration with all eureka-homekit features (controls, scenes, automations, AI agent).
- Always-on proactive mode: greet occupants, announce events, ambient awareness.

**Fit into Big Picture**

Epic 9 extends the eureka-homekit platform from a web/mobile interface into a physical ambient computing device. It builds on:
- **Epic 7 (AI Conversational Agent)**: The smart speaker becomes a physical voice front-end for the AI agent.
- **Epic 5 (Interactive Controls)**: Voice commands delegate to PrefabControlService for device control.
- **Epic 8 (Prefab Client Refactor)**: Bulk endpoints provide fast context for the speaker's RAG queries.
- **Epic 10 (Mobile & Voice Integration)** in the roadmap: The POC validates voice patterns that will inform the production voice integration.

The Pi runs a lightweight Python edge agent; all heavy AI processing (LLM, TTS voice cloning) is offloaded to the M3 Ultra server via smart-proxy. This validates the split-compute architecture before investing in a production enclosure.

**Reference Documents**

- `knowledge_base/epics/Epic-7-AI-Agent/0000-overview-epic-7.md` — AI Agent architecture
- `knowledge_base/epics/Epic-5-Interactive-Controls/` — Control service patterns
- `knowledge_base/epics/Epic-8-prefab-client-refactor/` — Bulk endpoint design
- `knowledge_base/epics/FUTURE-EPICS-ROADMAP.md` — Long-term roadmap context
- `.junie/guideline.md` — Agent and testing conventions
- Prefab fork: `https://github.com/ericsmith66/prefab-fork`
- Hailo SDK: `https://hailo.ai/developer-zone/software-downloads/`
- ReSpeaker XVF3800 datasheet
- Seeed 24 GHz mmWave sensor datasheet

---

### Key Decisions Locked In

**Architecture / Boundaries**

- **Edge Device**: Raspberry Pi 5 (16 GB) running Raspberry Pi OS 64-bit Lite.
- **AI Acceleration**: Hailo-8 (AI HAT+ 26 TOPS) via PCIe for on-device YOLO inference and Whisper STT.
- **Audio Output**: HiFiBerry Amp4 (I2S) driving SB Acoustics SB65WBAC25-4 (4Ω full-range).
- **Microphone**: ReSpeaker XVF3800 USB far-field mic array with AEC/beamforming.
- **Camera**: Arducam Camera Module 3 Wide (CSI, 120° FOV).
- **Presence Sensor**: Seeed 24 GHz mmWave (UART, MR24HPC1 or similar).
- **Cooling**: iUniker ICE Peak active cooler (PWM fan on Pi 5 fan header).
- **Power**: Anker 65W USB-C charger (sufficient for Pi 5 + Amp4 + peripherals).
- **Edge Language**: Python 3.11+ (lightweight edge agent; heavy processing on server).
- **Server Communication**: HTTPS/WSS via nextgen-plaid/smart-proxy to eureka-homekit Rails API.
- **TTS Engine**: Ollama on M3 Ultra for voice cloning / custom Eureka voice generation.
- **Project Base**: Fork of Prefab repo (`ericsmith66/prefab-fork`); edge code in `speaker/` subdirectory.
- **New Models (Rails side)**: None initially; reuse existing `Conversation`/`Message` from Epic 7.
- **New Endpoints (Rails side)**:
  - `POST /api/v1/speaker/wake` — register wake event with context.
  - `POST /api/v1/speaker/query` — send transcribed text + presence context.
  - `GET /api/v1/speaker/response` (SSE) or `WS /cable/speaker` — stream TTS audio/text back.
- **Out of Scope**:
  - Production enclosure (3D-print prototype only).
  - iOS/HomeKit bridging (future guide).
  - Multi-room speaker mesh.
  - Firmware-level optimizations.

**UX / UI**

- No web UI changes required for POC.
- LED feedback on Pi 5 GPIO (optional): listening (blue), processing (yellow), speaking (green), error (red).
- Audio feedback: chime on wake word detection, voice response via speaker driver.

**Testing**

- Hardware validation: component-level tests (mic record/play, camera capture, mmWave serial read, speaker tone, AI HAT identify).
- Edge agent: Python `pytest` unit tests for each pipeline stage (wake → STT → API → TTS).
- Integration: End-to-end test script ("Hey Eureka, what's the temperature?") with expected response validation.
- Rails side: Minitest for any new API endpoints (`test/controllers/api/v1/speaker_controller_test.rb`).

**Observability**

- Edge agent logs to `journalctl` (systemd service) and optionally to a log file.
- Rails-side logging for speaker API calls via existing `Rails.logger`.
- Latency tracking: wake-to-response round-trip target < 3 seconds.
- Health check endpoint on Pi (`GET /healthz`) reporting sensor/mic/camera/HAT status.

---

### High-Level Scope & Non-Goals

**In scope**

1. Complete hardware assembly guide (Pi 5 + HATs + peripherals + enclosure).
2. Raspberry Pi OS installation, driver setup, and component validation.
3. Wake word detection (Picovoice/Porcupine "Hey Eureka").
4. On-device STT (Whisper accelerated on Hailo-8).
5. Person detection (mmWave presence trigger + YOLO on camera via Hailo-8).
6. API integration with eureka-homekit via smart-proxy (query + context).
7. TTS playback with custom Eureka voice (audio from server, played via Amp4).
8. Edge agent main loop as a systemd service.
9. End-to-end POC validation.

**Non-goals / deferred**

- Production-quality enclosure or industrial design.
- Multi-room audio synchronization.
- iOS/HomeKit bridge or Siri integration.
- Speaker-to-speaker communication.
- OTA firmware updates.
- Voice enrollment / speaker identification (who is speaking).
- Offline fallback (server required for LLM/TTS).

---

### PRD Summary Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 9-01 | Hardware Assembly & Validation | Physical assembly, wiring, component-level tests | None (parts ordered) | `epic-9/prd-01-hardware-assembly` | Hands-on; no code |
| 9-02 | Raspberry Pi OS & Driver Setup | OS flash, driver install, interface enable, component tests | PRD 9-01 | `epic-9/prd-02-os-driver-setup` | Pi configuration |
| 9-03 | Wake Word & Speech-to-Text Pipeline | Porcupine wake word + Whisper STT on Hailo-8 | PRD 9-02 | `epic-9/prd-03-wake-stt-pipeline` | Custom Python code |
| 9-04 | Person Detection & Presence Sensing | mmWave UART + YOLO on camera via Hailo-8 | PRD 9-02 | `epic-9/prd-04-person-detection` | Custom Python code |
| 9-05 | TTS Playback & Custom Eureka Voice | Ollama TTS on server, audio streaming, Amp4 playback | PRD 9-02 | `epic-9/prd-05-tts-playback` | Server + edge code |
| 9-06 | Eureka-Homekit API Integration via Smart-Proxy | Rails API endpoints, smart-proxy routing, context payload | PRD 9-03, 9-04 | `epic-9/prd-06-api-integration` | Rails + Python code |
| 9-07 | Edge Agent Loop & Systemd Service | Main loop orchestration, systemd unit, health check | PRD 9-03, 9-04, 9-05, 9-06 | `epic-9/prd-07-agent-loop-service` | Ties everything together |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**: The Pi is a thin edge client; offload LLM inference and TTS voice cloning to M3 Ultra via smart-proxy. Only wake word detection, STT, and person detection run on-device (Hailo-8 accelerated).
- **Components**: Edge code lives in `speaker/` subdirectory of the prefab-fork repo. Python packages managed via `requirements.txt` or `pyproject.toml`.
- **Data Access**: All eureka-homekit data access goes through smart-proxy HTTPS endpoints; no direct DB connections from Pi.
- **Error Handling**: Edge agent must handle network failures gracefully (retry with backoff, audio error chime, log to journalctl). Never crash the main loop.
- **Empty States**: If server is unreachable, play a "I'm having trouble connecting" audio cue and retry.
- **Accessibility**: Audio-first interface; ensure clear voice prompts and chimes for state transitions.
- **Mobile**: N/A for this epic (physical device).
- **Security**: All API traffic over HTTPS via smart-proxy. API keys stored in environment variables on Pi (never in code). mmWave/camera data stays on-device (only derived metadata sent to server).

---

### Implementation Status Tracking

- Create `0001-IMPLEMENTATION-STATUS.md` in this directory before starting PRD work.
- Update it after each PRD completion.

---

### Success Metrics

- Hardware assembles without modifications (all parts compatible as specced).
- All component-level tests pass (mic, speaker, camera, mmWave, AI HAT+).
- Wake word detection triggers reliably from 3+ meters.
- STT transcription accuracy > 85% for common home commands.
- Person detection accuracy > 80% (mmWave presence + YOLO count).
- End-to-end wake-to-response latency < 3 seconds.
- Edge agent runs continuously for 24+ hours without crash (systemd auto-restart on failure).
- Custom Eureka voice is clearly intelligible and distinct.

---

### Estimated Timeline

- PRD 9-01 (Hardware Assembly): 1 day (30–60 min hands-on)
- PRD 9-02 (OS & Drivers): 1 day (1–2 hours)
- PRD 9-03 (Wake Word & STT): 2–3 days
- PRD 9-04 (Person Detection): 2–3 days
- PRD 9-05 (TTS Playback): 2–3 days
- PRD 9-06 (API Integration): 2–3 days
- PRD 9-07 (Agent Loop & Service): 1–2 days
- End-to-End Testing & Polish: 2–3 days

**Total: 13–22 days** (2.5–4.5 weeks)

---

### Next Steps

1. ✅ Create `0000-overview-epic-9-smart-speaker-poc.md` (this document)
2. Create `0001-IMPLEMENTATION-STATUS.md`
3. Proceed with PRD 9-01 (Hardware Assembly & Validation)

---

### Detailed PRDs

Full PRD specifications live in separate files:
- `PRD-9-01-hardware-assembly.md`
- `PRD-9-02-os-driver-setup.md`
- `PRD-9-03-wake-stt-pipeline.md`
- `PRD-9-04-person-detection.md`
- `PRD-9-05-tts-playback.md`
- `PRD-9-06-api-integration.md`
- `PRD-9-07-agent-loop-service.md`

---

### Bill of Materials (BOM)

| # | Component | Role | Interface | Notes |
|---|-----------|------|-----------|-------|
| 1 | Raspberry Pi 5 16 GB | Main SBC | — | Base platform |
| 2 | Raspberry Pi AI HAT+ 26 TOPS (Hailo-8) | On-device AI inference | PCIe | STT + YOLO acceleration |
| 3 | HiFiBerry Amp4 | Audio amplifier | I2S via GPIO | Powers speaker driver directly |
| 4 | SB Acoustics SB65WBAC25-4 | Full-range speaker driver | Speaker wire to Amp4 | 4Ω, 25W, 2.5" |
| 5 | ReSpeaker XVF3800 | Far-field mic array | USB 3.0 | AEC, beamforming, 360° pickup |
| 6 | Arducam Camera Module 3 Wide | Vision / person detection | CSI (15-22 pin FFC) | 120° FOV |
| 7 | Seeed 24 GHz mmWave Sensor | Presence detection | UART (GPIO 8/10) | MR24HPC1 or equivalent |
| 8 | iUniker ICE Peak Cooler | Active cooling | Fan header (PWM) | Heatsink + fan |
| 9 | Anker 65W USB-C Charger | Power supply | USB-C | Sufficient for full stack |
| 10 | MicroSD Card (64 GB+) | Boot / OS storage | MicroSD slot | Raspberry Pi OS 64-bit Lite |
| 11 | Extra-tall 2×20 stacking header | HAT stacking | GPIO | Solder or press-fit |
| 12 | M2.5 standoffs, screws, nuts | Mechanical mounting | — | For HAT clearance & enclosure |
| 13 | 18 AWG speaker wire (1–2 ft) | Amp4 → driver | Screw/spring terminals | Match polarity |
| 14 | Chanzon jumper wires (F-M) | mmWave wiring | GPIO pins | VCC, GND, TX, RX |
| 15 | 100W USB-C cable (1.5 ft) | Power delivery | USB-C | Short, high-quality |
| 16 | Thermal pads | Heat transfer | Adhesive | Between SoC and heatsink |
| 17 | 3D-printed enclosure (custom) | Housing | — | Prototype; STL TBD |

---

### Architecture Diagram (Conceptual)

```
┌─────────────────────────────────────────────────────────────────┐
│                     Eureka Smart Speaker (Pi 5)                 │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────────┐  │
│  │ ReSpeaker │  │ Arducam  │  │  mmWave   │  │  AI HAT+     │  │
│  │ XVF3800  │  │ Cam 3W   │  │  24 GHz   │  │  Hailo-8     │  │
│  │ (USB)    │  │ (CSI)    │  │  (UART)   │  │  (PCIe)      │  │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘  └──────┬───────┘  │
│       │              │              │                │           │
│  ┌────▼──────────────▼──────────────▼────────────────▼───────┐  │
│  │              Python Edge Agent (speaker/)                  │  │
│  │  ┌─────────┐ ┌─────┐ ┌──────────┐ ┌─────┐ ┌───────────┐ │  │
│  │  │ Wake    │→│ STT │→│ Presence │→│ API │→│ TTS       │ │  │
│  │  │ Word    │ │     │ │ Context  │ │ Call│ │ Playback  │ │  │
│  │  │Porcupine│ │Whispr│ │YOLO+Radar│ │     │ │           │ │  │
│  │  └─────────┘ └─────┘ └──────────┘ └──┬──┘ └─────┬─────┘ │  │
│  └───────────────────────────────────────┼──────────┼────────┘  │
│                                          │          │           │
│  ┌───────────────┐                       │    ┌─────▼───────┐  │
│  │ HiFiBerry     │◄──────────────────────┼────│ ALSA/aplay  │  │
│  │ Amp4 (I2S)    │                       │    └─────────────┘  │
│  └───────┬───────┘                       │                     │
│          │                               │                     │
│  ┌───────▼───────┐                       │                     │
│  │ SB Acoustics  │                       │                     │
│  │ SB65WBAC25-4  │                       │                     │
│  └───────────────┘                       │                     │
└──────────────────────────────────────────┼─────────────────────┘
                                           │ HTTPS / WSS
                                           │ (smart-proxy)
┌──────────────────────────────────────────▼─────────────────────┐
│                   M3 Ultra Server                               │
│                                                                 │
│  ┌─────────────────┐  ┌────────────┐  ┌──────────────────────┐ │
│  │ eureka-homekit   │  │  Ollama    │  │ nextgen-plaid/       │ │
│  │ Rails App        │  │  (LLM +   │  │ smart-proxy          │ │
│  │ (Postgres)       │  │   TTS)    │  │ (HTTPS termination)  │ │
│  └─────────────────┘  └────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```
