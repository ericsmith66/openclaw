#### PRD-9-07: Edge Agent Loop & Systemd Service

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-9-07-agent-loop-service-feedback-V{{N}}.md` in the same directory.

---

### Overview

This PRD ties together all prior subsystems (wake word, STT, presence detection, API integration, TTS playback) into a single orchestrated edge agent that runs as a systemd service on the Raspberry Pi. The agent loop continuously listens for wake words, processes voice queries, enriches them with presence context, sends them to the eureka-homekit server, and plays back responses — all while maintaining a health check endpoint for monitoring.

This is the final integration PRD that delivers the end-to-end "Hey Eureka" experience.

---

### Requirements

#### Functional

- **Main Agent Loop:**
  1. On startup: initialize all subsystems (mic, wake word, mmWave, camera, Hailo, ALSA, API client).
  2. Enter idle state: wake word listener active, mmWave presence monitor active.
  3. On wake word detection:
     a. Play acknowledgment chime.
     b. Capture post-wake audio (VAD-based).
     c. Transcribe via Whisper STT.
     d. Gather current presence context (mmWave + optional camera snapshot).
     e. Send query to eureka-homekit API (text + presence).
     f. Receive response.
     g. Fetch/stream TTS audio from server.
     h. Play TTS through speaker.
     i. Return to idle state.
  4. On proactive trigger (mmWave absent → present): optionally send greeting event to API.
  5. On error at any stage: log error, play error chime, return to idle state.

- **Concurrent Operation:**
  - Wake word listener runs continuously (even during TTS playback, leveraging AEC).
  - mmWave presence monitor runs continuously in background thread.
  - Camera inference runs on-demand only (triggered by query or presence change).
  - TTS playback runs in a dedicated thread (interruptible).

- **Systemd Service:**
  - Unit file: `eureka-speaker.service`.
  - Auto-start on boot.
  - Auto-restart on crash (5-second delay).
  - Runs as dedicated user (`eureka`).
  - Environment variables loaded from `/etc/eureka-speaker/env`.
  - Logs to journalctl (`journalctl -u eureka-speaker -f`).

- **Health Check Endpoint:**
  - Lightweight HTTP server on port 8080.
  - `GET /healthz` returns JSON with subsystem statuses:
    ```json
    {
      "status": "ok",
      "uptime_seconds": 3600,
      "subsystems": {
        "wake_word": "active",
        "stt": "ready",
        "mmwave": "active",
        "camera": "ready",
        "hailo": "loaded",
        "api": "connected",
        "speaker": "ready"
      },
      "last_query": "2026-03-01T14:30:00Z",
      "queries_count": 42,
      "errors_count": 3
    }
    ```
  - `GET /metrics` (optional): Prometheus-compatible metrics.

- **Graceful Shutdown:**
  - Handle SIGTERM: stop all subsystems cleanly, close serial ports, release Hailo device, close audio streams.
  - Handle SIGINT: same as SIGTERM (for manual Ctrl+C).
  - Shutdown completes within 5 seconds.

#### Non-Functional

- Agent startup time: < 15 seconds (model loading is the bottleneck).
- Memory usage at idle: < 800 MB (all models loaded).
- Memory usage during query: < 1.2 GB peak.
- No memory leaks over 24-hour continuous operation.
- CPU usage at idle: < 10% (wake word listener + mmWave reader).
- Recovery from crash: < 10 seconds (systemd restart + model reload).
- End-to-end latency (wake to response audio start): < 5 seconds.

#### Implementation Notes

**Project Structure (final):**
```
speaker/
├── pyproject.toml
├── requirements.txt
├── README.md
├── systemd/
│   └── eureka-speaker.service
├── config/
│   ├── env.example              # Environment variables template
│   ├── config.txt.example       # /boot/firmware/config.txt reference
│   └── asound.conf.example      # ALSA configuration reference
├── src/
│   ├── __init__.py
│   ├── main.py                  # Entry point: agent loop orchestrator
│   ├── config.py                # Configuration management
│   ├── health.py                # Health check HTTP server
│   ├── wake_word.py             # Porcupine wake word detector
│   ├── audio_capture.py         # Post-wake audio recording with VAD
│   ├── stt.py                   # Whisper speech-to-text
│   ├── audio_utils.py           # ALSA helpers
│   ├── presence/
│   │   ├── __init__.py
│   │   ├── mmwave_sensor.py
│   │   ├── camera_detector.py
│   │   ├── presence_context.py
│   │   └── hailo_inference.py
│   ├── tts/
│   │   ├── __init__.py
│   │   ├── tts_client.py
│   │   ├── audio_player.py
│   │   ├── fallback_tts.py
│   │   ├── chime_player.py
│   │   └── volume_control.py
│   └── api/
│       ├── __init__.py
│       └── eureka_client.py
├── models/
│   ├── yolov8n.hef
│   └── whisper-small/           # Whisper model files
├── assets/
│   └── chimes/
│       ├── wake_ack.wav
│       ├── processing.wav
│       ├── error.wav
│       └── greeting.wav
├── tests/
│   ├── conftest.py
│   ├── test_wake_word.py
│   ├── test_audio_capture.py
│   ├── test_stt.py
│   ├── test_mmwave_sensor.py
│   ├── test_camera_detector.py
│   ├── test_presence_context.py
│   ├── test_tts_client.py
│   ├── test_audio_player.py
│   ├── test_fallback_tts.py
│   ├── test_volume_control.py
│   ├── test_eureka_client.py
│   ├── test_health.py
│   └── test_agent_loop.py
└── scripts/
    ├── validate_hardware.sh
    ├── install.sh               # Setup script (venv, deps, systemd)
    └── soak_test.sh             # 24-hour endurance test runner
```

**Main Agent Loop (`main.py`):**
```python
# Pseudocode structure
import asyncio

class EurekaAgent:
    async def run(self):
        await self.initialize_subsystems()
        self.start_health_server()
        self.start_mmwave_monitor()
        
        while self.running:
            try:
                # Wait for wake word (blocks until detected)
                await self.wake_word.wait_for_wake()
                
                # Process voice query
                self.chime_player.play("wake_ack")
                audio = await self.audio_capture.capture()
                text = await self.stt.transcribe(audio)
                
                if not text or len(text.strip()) < 2:
                    self.chime_player.play("error")
                    continue
                
                presence = self.presence.get_context()
                response = await self.api_client.send_query(text, presence)
                
                if response and response.get("audio_url"):
                    audio_data = await self.tts_client.fetch(response["audio_url"])
                    await self.audio_player.play(audio_data)
                elif response and response.get("response_text"):
                    audio_data = await self.tts_client.generate(response["response_text"])
                    await self.audio_player.play(audio_data)
                else:
                    self.chime_player.play("error")
                    
            except Exception as e:
                logger.error(f"Agent loop error: {e}")
                self.chime_player.play("error")
                self.health.record_error(e)

if __name__ == "__main__":
    agent = EurekaAgent()
    asyncio.run(agent.run())
```

**Systemd Unit File (`eureka-speaker.service`):**
```ini
[Unit]
Description=Eureka Smart Speaker Edge Agent
After=network-online.target sound.target
Wants=network-online.target

[Service]
Type=simple
User=eureka
Group=eureka
WorkingDirectory=/opt/eureka-speaker
EnvironmentFile=/etc/eureka-speaker/env
ExecStart=/opt/eureka-speaker/venv/bin/python -m src.main
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=eureka-speaker

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/eureka-speaker/logs /tmp

# Resource limits
MemoryMax=1500M
CPUQuota=80%

[Install]
WantedBy=multi-user.target
```

**Installation Script (`install.sh`):**
```bash
#!/bin/bash
# Create user, install deps, setup systemd
sudo useradd -r -s /bin/false eureka
sudo mkdir -p /opt/eureka-speaker /etc/eureka-speaker
sudo cp -r . /opt/eureka-speaker/
sudo cp config/env.example /etc/eureka-speaker/env
# Edit /etc/eureka-speaker/env with actual values
python3 -m venv /opt/eureka-speaker/venv
/opt/eureka-speaker/venv/bin/pip install -r requirements.txt
sudo cp systemd/eureka-speaker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable eureka-speaker
sudo systemctl start eureka-speaker
```

---

### Error Scenarios & Fallbacks

- **Subsystem initialization failure** → Log which subsystem failed, start in degraded mode (skip failed subsystem). E.g., if camera fails, run without visual detection (mmWave only).
- **Main loop exception** → Catch all exceptions, log, play error chime, continue loop. Never exit the loop (systemd restart is the last resort).
- **Memory limit exceeded** → Systemd OOM kills process. RestartSec=5 brings it back. Log memory usage periodically to detect leaks.
- **Network partition (server unreachable for extended period)** → Degrade to local-only mode: wake word works, STT works, but responses are "I can't reach the server right now." Presence detection continues locally.
- **Hailo device locked** → Release and reinitialize Hailo device. If persistent, fall back to CPU inference.
- **SIGTERM received** → Graceful shutdown: close serial ports, release Hailo, stop audio, exit cleanly within 5 seconds.
- **Multiple rapid wake words** → Debounce: ignore wake words within 2 seconds of last detection or while processing a query.

---

### Architectural Context

This PRD is the capstone of Epic 9. It orchestrates all prior PRDs:

```
PRD 9-01: Hardware  ─→  Physical platform
PRD 9-02: OS/Drivers ─→ Runtime environment
PRD 9-03: Wake/STT  ─┐
PRD 9-04: Presence   ├→ PRD 9-07: Agent Loop (this PRD)
PRD 9-05: TTS        ─┤
PRD 9-06: API        ─┘
```

The agent uses Python's `asyncio` for concurrent operation:
- **Task 1**: Wake word listener (continuous, yields on detection).
- **Task 2**: mmWave presence monitor (continuous background task).
- **Task 3**: Health check HTTP server (asyncio HTTP handler).
- **Main coroutine**: Wake → STT → Presence → API → TTS → loop.

The systemd service ensures the agent survives reboots and crashes. The health endpoint enables monitoring from the M3 Ultra server (e.g., a Rails background job that polls speaker health).

---

### Acceptance Criteria

- [ ] Agent starts and initializes all subsystems within 15 seconds
- [ ] Main loop processes: wake → chime → capture → STT → presence → API → TTS → idle
- [ ] End-to-end test: "Hey Eureka, who's in the room?" → correct spoken response
- [ ] mmWave presence monitor runs continuously in background
- [ ] Wake word listener runs during TTS playback (AEC working)
- [ ] Error at any pipeline stage → error chime → return to idle (no crash)
- [ ] Systemd service auto-starts on boot
- [ ] Systemd auto-restarts on crash within 10 seconds
- [ ] Health endpoint returns correct subsystem statuses
- [ ] Graceful shutdown on SIGTERM completes within 5 seconds
- [ ] 24-hour soak test: no crashes, no memory leaks, queries processed correctly
- [ ] All Python tests pass (`pytest tests/`)
- [ ] Agent runs as dedicated `eureka` user (not root)

---

### Test Cases

#### Unit (pytest)

- `tests/test_agent_loop.py`:
  - Test initialization: all subsystems created
  - Test query pipeline with mocked subsystems (wake → STT → API → TTS)
  - Test error handling: STT failure → error chime, loop continues
  - Test error handling: API failure → fallback TTS, loop continues
  - Test debounce: rapid wake words → only first processed
  - Test graceful shutdown: SIGTERM → clean exit
- `tests/test_health.py`:
  - Test health endpoint returns 200 with all subsystem statuses
  - Test metrics tracking (query count, error count, uptime)

#### Integration (pytest)

- `tests/test_end_to_end.py`:
  - Simulate full pipeline with pre-recorded audio: wake word file → STT → mock API → TTS playback
  - Verify correct response text received
  - Verify audio played (check ALSA output device was invoked)

#### System / Smoke

- **Soak test**: Run `scripts/soak_test.sh` for 24 hours:
  - Trigger wake word every 5 minutes via pre-recorded audio.
  - Verify response received each time.
  - Monitor memory usage (should not grow monotonically).
  - Monitor CPU usage (should return to idle baseline between queries).
  - Log all latencies and error counts.

---

### Manual Verification

1. **Install and start service:**
   ```bash
   sudo bash speaker/scripts/install.sh
   # Edit /etc/eureka-speaker/env with real values
   sudo systemctl start eureka-speaker
   sudo systemctl status eureka-speaker  # Should show "active (running)"
   ```

2. **Check health:**
   ```bash
   curl http://localhost:8080/healthz
   # Should return JSON with all subsystems "active" or "ready"
   ```

3. **End-to-end voice test:**
   - Say "Hey Eureka, what's the temperature in the living room?" from 3+ meters.
   - Expect: chime → brief pause → Eureka voice responds with temperature.

4. **Interruption test:**
   - Say "Hey Eureka, tell me about all the rooms" (long response).
   - During playback, say "Hey Eureka" — expect playback to stop and new listening to begin.

5. **Error recovery test:**
   - Disconnect Wi-Fi. Say "Hey Eureka, hello."
   - Expect: chime → STT works → API fails → error message via gTTS fallback.
   - Reconnect Wi-Fi. Say "Hey Eureka, hello."
   - Expect: normal response from server.

6. **Crash recovery test:**
   ```bash
   sudo kill -9 $(pgrep -f "src.main")
   sleep 10
   sudo systemctl status eureka-speaker  # Should show "active (running)" again
   ```

7. **Boot persistence test:**
   ```bash
   sudo reboot
   # After boot, verify:
   sudo systemctl status eureka-speaker  # Active
   curl http://localhost:8080/healthz     # Responding
   ```

8. **24-hour soak test:**
   ```bash
   bash speaker/scripts/soak_test.sh
   # Monitor output for errors, check memory trend
   ```

**Expected**
- All tests pass.
- Agent recovers from all error conditions.
- 24-hour soak test shows stable memory and consistent latency.

---

### Rollout / Deployment Notes

- **First-time setup**: Run `install.sh` which creates user, venv, installs deps, and configures systemd.
- **Updates**: `git pull` in `/opt/eureka-speaker`, `pip install -r requirements.txt`, `sudo systemctl restart eureka-speaker`.
- **Log monitoring**: `journalctl -u eureka-speaker -f` for live logs.
- **Remote monitoring**: Poll `GET /healthz` from M3 Ultra server (e.g., cron job or Rails background job).
- **Metrics**: Consider adding Prometheus metrics export for Grafana dashboard (future enhancement).
- **Backup**: The Pi's MicroSD is the single point of failure. Consider periodic `dd` backups of the card.
