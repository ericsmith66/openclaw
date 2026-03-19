# Epic: Integrate Raspberry Pi Smart Speaker with Eureka AI Assistant

**Epic ID:** EPI-001 (Adjust based on your existing knowledge_base/epics numbering.)

**Epic Overview:**  
This epic covers the integration of the Raspberry Pi 5-based smart speaker hardware (edge device) with the Eureka AI assistant ecosystem, leveraging the eureka-homekit Ruby on Rails app as the central backend. The Pi will handle local input/output (voice capture, person detection, TTS playback) while offloading complex AI processing to the M3 Ultra server via nextgen-plaid/smart-proxy. This enables a privacy-focused, low-latency smart home speaker that interacts with Eureka's agents (per .junie/guidelines) for tasks like home automation, queries, and contextual responses. We'll fork Prefab as the root project base, use Aider Desktop for code modifications, and align with existing templates and knowledge_base/epics/PRDs.

**Epic Goals:**
- Achieve seamless edge-to-server communication for voice interactions and detection events.
- Ensure compliance with .junie/guidelines for AI agents (e.g., context-aware, secure).
- Support custom Eureka TTS voice cloning via Ollama.
- Test end-to-end in a POC setup before scaling to production.

**Scope:**
- In: Pi software setup (Python-based), API integrations via smart-proxy, basic agent logic mods in eureka-homekit.
- Out: Full iOS/Xcode AI-agent integration (separate epic), advanced ML training on M3 Ultra, hardware enclosure finalization.

**Dependencies:**
- Hardware assembly complete (per prior guide).
- M3 Ultra server running: Postgres, Ollama (for LLM/TTS), nextgen-plaid/smart-proxy, eureka-homekit Rails app deployed.
- Prefab fork as root project: Clone and set up locally (e.g., `git clone https://github.com/ericsmith66/prefab-fork.git prefab-root`).
- Aider Desktop installed for step-by-step code mods.

**Estimated Effort:** Medium (2–4 weeks for POC, assuming 10–20 hours/week). Break into user stories below.

## User Stories

1. **US-001: Set Up Pi Software Environment**  
   **As a developer,** I want to configure the Raspberry Pi OS and install dependencies so that the edge device can run local processing scripts.  
   **Acceptance Criteria:**
    - Raspberry Pi OS 64-bit Lite installed and booted.
    - Dependencies installed: Python 3, pip, libraries (pvporcupine, openai-whisper, opencv-python, ultralytics, gtts, requests, pyserial, alsa-utils, libcamera-apps, Hailo SDK).
    - Drivers enabled for all hardware (Amp4, ReSpeaker, camera, mmWave, AI HAT+).
    - Basic tests pass (mic record, speaker playback, camera capture, mmWave read, Hailo inference).  
      **PRD Details:** Align with templates/basic-setup.md; use Aider to automate dependency installs in a setup script (e.g., `setup.py` in prefab-root).

2. **US-002: Implement Wake Word Detection on Pi**  
   **As the Eureka speaker,** I want to detect "Hey Eureka" via the ReSpeaker mic so that it triggers listening mode.  
   **Acceptance Criteria:**
    - Porcupine/Picovoice library configured with custom wake word model (train via Picovoice console if needed).
    - Script runs always-on, captures audio on wake, and passes to STT.
    - Low false positives in noisy rooms (test with background audio).  
      **PRD Details:** Per .junie/guidelines/wake-agent.md; code in Python (e.g., `wake_listener.py`); use Aider to integrate into prefab-root.

3. **US-003: Local STT and Query Transmission**  
   **As the edge device,** I want to transcribe speech locally and send queries to eureka-homekit via smart-proxy so that the server can process AI requests.  
   **Acceptance Criteria:**
    - Whisper model runs on Pi (accelerated via AI HAT+ for low latency).
    - Transcribed text sent as POST to smart-proxy (e.g., `https://your-proxy/eureka/query` with JSON payload: `{'text': 'query', 'context': {'room': 'living'}}`).
    - Handle errors (e.g., network retry).  
      **PRD Details:** Reference knowledge_base/epics/voice-processing.prd; Aider mod: Add endpoint in eureka-homekit Rails (e.g., `queries_controller.rb`).

4. **US-004: Person Presence/Detection on Pi**  
   **As the speaker,** I want to detect room occupancy via mmWave and camera so that Eureka can provide contextual responses.  
   **Acceptance Criteria:**
    - mmWave triggers always-on presence (serial read).
    - On trigger, run YOLO/MediaPipe on camera (accelerated on Hailo-8) for person count/position.
    - Send detection data to smart-proxy (e.g., POST `{'presence': true, 'details': {'count': 1}}`).
    - Privacy: Local processing only; no cloud upload.  
      **PRD Details:** New PRD in knowledge_base/epics/detection.prd; code: `detection_agent.py`; use Aider to align with .junie/guidelines/sensor-agent.

5. **US-005: Receive and Play TTS Responses**  
   **As the edge device,** I want to receive TTS audio/text from eureka-homekit/Ollama and play via Amp4 so that users hear the Eureka voice.  
   **Acceptance Criteria:**
    - Poll/WebSocket from smart-proxy for responses (e.g., `ws://your-proxy/eureka/response`).
    - Generate TTS on server (Ollama with custom voice clone) or fallback to gTTS on Pi.
    - Play audio with volume control (alsa).
    - Handle interruptions (e.g., new wake during playback).  
      **PRD Details:** Extend templates/tts-template.md; Aider mod: Add TTS endpoint in eureka-homekit (e.g., integrate Ollama API call in `responses_controller.rb`).

6. **US-006: Full Integration Loop and Testing**  
   **As a developer,** I want an end-to-end agent loop on Pi so that the speaker fully interacts with Eureka.  
   **Acceptance Criteria:**
    - Main script: Wake → STT → Detection → API send → TTS receive/play.
    - Run as systemd service (persistent, auto-start).
    - POC tests: 5 scenarios (e.g., "Hey Eureka, turn on lights" → homekit automation via Rails).
    - Logs to server for monitoring.  
      **PRD Details:** Comprehensive in knowledge_base/epics/integration.prd; use Aider to merge into prefab-root (e.g., add Ruby agents for server-side handling per .junie/guidelines).

## Implementation Plan (Step-by-Step Using Aider)
1. **Fork and Setup Prefab Root:** Clone fork, add eureka-homekit as submodule (`git submodule add https://github.com/ericsmith66/eureka-homekit`).
2. **Aider Mods:** Open prefab-root in Aider; prompt for each US (e.g., "Implement wake word detection in Python per .junie/guidelines").
3. **Server Mods:** In eureka-homekit, add API endpoints (use Aider: "Add POST /query with Ollama integration").
4. **Deploy and Test:** Run Pi script, simulate queries; monitor Rails logs on M3 Ultra.
5. **Iterate:** Based on tests, refine with Aider (e.g., "Optimize latency for STT").

**Risks/Mitigations:**
- Latency: Offload more to Hailo/AI HAT+.
- Security: All via smart-proxy (HTTPS).
- Voice Cloning: Test Ollama with samples for Eureka voice.

This epic builds on your existing setup—once complete, the Pi becomes a seamless Eureka extension. If we need sub-tasks or a full PRD template, let me know!