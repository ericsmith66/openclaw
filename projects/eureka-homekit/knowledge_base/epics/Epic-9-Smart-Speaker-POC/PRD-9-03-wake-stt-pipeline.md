#### PRD-9-03: Wake Word & Speech-to-Text Pipeline

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-9-03-wake-stt-pipeline-feedback-V{{N}}.md` in the same directory.

---

### Overview

This PRD implements the voice input pipeline: continuous listening for the "Hey Eureka" wake word via the ReSpeaker XVF3800 mic array, followed by post-wake audio capture and local speech-to-text transcription using Whisper accelerated on the Hailo-8 AI HAT+. The output is a transcribed text string ready to be sent to the eureka-homekit API (PRD 9-06).

This is **custom code** — the first major code artifact in the `speaker/` project directory.

---

### Requirements

#### Functional

- Continuously listen on the ReSpeaker XVF3800 for the wake word "Hey Eureka".
- Use Picovoice Porcupine (or OpenWakeWord as fallback) for wake word detection.
- On wake detection, play a short acknowledgment chime through the speaker.
- Capture post-wake audio until either:
  - Voice Activity Detection (VAD) detects 1.5 seconds of silence, OR
  - Maximum recording duration reached (10 seconds).
- Transcribe captured audio using OpenAI Whisper (small or base model).
- Accelerate Whisper inference on Hailo-8 if supported; fall back to CPU if not.
- Return transcribed text as a string with confidence score.
- Handle edge cases: no speech detected, unintelligible audio, wake word false positive.

#### Non-Functional

- Wake word detection latency: < 200ms from utterance end to detection callback.
- Wake word false positive rate: < 1 per hour in typical home environment.
- Wake word miss rate: < 10% from 3+ meters distance.
- STT transcription time: < 2 seconds for 5-second audio clip.
- Memory usage: < 500 MB for wake word + STT combined.
- Must not block the main event loop (async-compatible).

#### Implementation Notes

**Project Structure:**
```
speaker/
├── requirements.txt
├── pyproject.toml
├── src/
│   ├── __init__.py
│   ├── wake_word.py          # Porcupine wake word detector
│   ├── audio_capture.py      # Post-wake audio recording with VAD
│   ├── stt.py                # Whisper speech-to-text
│   ├── audio_utils.py        # ALSA helpers, format conversion
│   └── config.py             # Configuration (device indices, model paths, thresholds)
├── models/                   # Whisper model files
├── assets/
│   └── chimes/
│       ├── wake_ack.wav      # Acknowledgment chime
│       └── error.wav         # Error chime
├── tests/
│   ├── test_wake_word.py
│   ├── test_audio_capture.py
│   └── test_stt.py
└── scripts/
    └── validate_hardware.sh
```

**Key Dependencies:**
```
pvporcupine>=3.0       # Wake word detection
pyaudio>=0.2.14        # Audio I/O
webrtcvad>=2.0.10      # Voice Activity Detection
openai-whisper>=20231117  # Speech-to-text (or faster-whisper)
numpy>=1.24
```

**Wake Word Module (`wake_word.py`):**
- Initialize Porcupine with custom "Hey Eureka" keyword (train via Picovoice Console, or use built-in "Hey Google" / "Alexa" for testing).
- Continuous audio stream from ReSpeaker (16kHz, 16-bit, mono).
- On detection: emit event/callback with timestamp and confidence.

**Audio Capture Module (`audio_capture.py`):**
- Start recording immediately after wake word detection.
- Use WebRTC VAD for silence detection (aggressiveness level 2 or 3).
- Buffer audio frames; stop when silence exceeds 1.5 seconds or 10-second max.
- Return raw audio as numpy array or WAV bytes.

**STT Module (`stt.py`):**
- Load Whisper model on startup (keep in memory for fast inference).
- Accept audio input, run transcription, return `{text: str, confidence: float, language: str}`.
- Try Hailo-8 acceleration first; fall back to CPU Whisper if Hailo path unavailable.
- Log transcription latency.

---

### Error Scenarios & Fallbacks

- **No speech after wake word** → Wait for VAD timeout (10s), log "no speech detected", return to listening.
- **Whisper returns empty/low-confidence** → Log warning, play error chime, return to listening. Do not send empty query to API.
- **Porcupine license expired** → Log error, fall back to OpenWakeWord (free/open-source).
- **ReSpeaker disconnected** → Detect via pyaudio exception, log critical error, attempt reconnect every 5 seconds.
- **Hailo STT acceleration fails** → Fall back to CPU Whisper (slower but functional). Log warning.
- **Audio buffer overflow** → Use ring buffer with max size; drop oldest frames if overflow detected.

---

### Architectural Context

This PRD creates the voice input half of the edge agent pipeline. It produces transcribed text that feeds into PRD 9-06 (API integration). It runs concurrently with PRD 9-04 (person detection) — both feed context into the API query.

The wake word detector runs in a dedicated thread/async task, continuously processing audio frames. On wake detection, it hands off to the audio capture module, which records until silence, then passes audio to STT. The entire pipeline is designed to be non-blocking so the mmWave presence monitor (PRD 9-04) can run simultaneously.

Key design decisions:
- Porcupine chosen for low false-positive rate and ARM optimization. OpenWakeWord is the free fallback.
- Whisper "small" model balances accuracy and speed on Pi 5 + Hailo-8. May downgrade to "base" if latency exceeds 2s.
- WebRTC VAD is lightweight and battle-tested for silence detection.

---

### Acceptance Criteria

- [ ] Porcupine initializes and listens on ReSpeaker mic without errors
- [ ] "Hey Eureka" (or test keyword) detected from 3+ meters with > 90% reliability
- [ ] Acknowledgment chime plays through speaker on wake detection
- [ ] Post-wake audio captured with VAD-based silence detection
- [ ] Audio capture stops after 1.5s silence or 10s max duration
- [ ] Whisper transcribes captured audio with > 85% accuracy on common home commands
- [ ] Transcription completes in < 2 seconds for 5-second audio clip
- [ ] Empty/low-confidence transcriptions handled gracefully (error chime, return to listening)
- [ ] Pipeline runs continuously without memory leaks (test for 1+ hour)
- [ ] All modules importable and testable independently

---

### Test Cases

#### Unit (pytest)

- `tests/test_wake_word.py`:
  - Test Porcupine initialization with valid access key
  - Test detection callback fires on pre-recorded wake word audio
  - Test no false trigger on silence / ambient noise sample
- `tests/test_audio_capture.py`:
  - Test VAD detects silence correctly (synthetic silent audio)
  - Test capture stops at max duration (10s timeout)
  - Test captured audio is valid WAV format / numpy array
- `tests/test_stt.py`:
  - Test Whisper loads model successfully
  - Test transcription of pre-recorded "turn on the lights" → expected text
  - Test empty audio returns empty/low-confidence result
  - Test transcription latency < 2 seconds (benchmark test)

#### Integration (pytest)

- `tests/test_wake_stt_pipeline.py`:
  - Play pre-recorded "Hey Eureka, turn on the lights" through audio → detect wake → capture → transcribe → verify text contains "turn on" and "lights"

#### System / Smoke

- Manual: Say "Hey Eureka, what's the temperature?" from 3 meters → verify chime plays and transcription printed to console.

---

### Manual Verification

1. SSH into Pi. Activate Python venv: `source speaker/venv/bin/activate`.
2. Run wake word test: `python -m src.wake_word --test`.
3. Say "Hey Eureka" from 3 meters — verify console prints "Wake word detected!" and chime plays.
4. Run full pipeline test: `python -m src.main --test-stt`.
5. Say "Hey Eureka, turn on the living room lights" — verify transcription printed.
6. Verify transcription accuracy matches spoken words.
7. Test edge case: Say "Hey Eureka" then remain silent for 10 seconds — verify timeout and return to listening.
8. Test false positive: Play music / TV audio for 5 minutes — verify no false triggers.

**Expected**
- Wake word triggers reliably at 3+ meters.
- Chime plays immediately on detection.
- Transcription is accurate for common commands.
- System returns to listening after timeout or error.

---

### Rollout / Deployment Notes

- Porcupine requires an access key (free tier available at console.picovoice.ai). Store in environment variable `PICOVOICE_ACCESS_KEY`.
- Custom "Hey Eureka" keyword may require Picovoice Console training ($). Use built-in keyword for initial testing.
- Whisper model files are large (base: ~150MB, small: ~500MB). Download once and cache in `speaker/models/`.
- Monitor Hailo-8 compatibility with Whisper — this is experimental; CPU fallback must work.
