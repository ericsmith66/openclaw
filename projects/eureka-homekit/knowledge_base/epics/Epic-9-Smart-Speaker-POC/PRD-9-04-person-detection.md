#### PRD-9-04: Person Detection & Presence Sensing

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-9-04-person-detection-feedback-V{{N}}.md` in the same directory.

---

### Overview

This PRD implements the presence sensing and person detection subsystem. The Seeed 24 GHz mmWave radar provides continuous, low-power presence detection (someone in the room? yes/no). When presence is detected (or on demand during a voice query), the Arducam Camera Module 3 Wide captures a frame and runs YOLOv8 person detection accelerated on the Hailo-8 AI HAT+ to count persons and estimate positions.

The output is a presence context payload (`{presence: bool, count: int, positions: [...]}`) that enriches voice queries sent to eureka-homekit (PRD 9-06).

---

### Requirements

#### Functional

- Continuously read Seeed 24 GHz mmWave sensor via UART for presence/absence detection.
- Parse mmWave sensor frames per datasheet protocol (MR24HPC1 or equivalent).
- Expose presence state as a boolean with last-updated timestamp.
- On demand (triggered by wake word or API request), capture a camera frame via libcamera.
- Run YOLOv8-nano person detection on captured frame, accelerated on Hailo-8.
- Return detection results: person count, bounding box positions (normalized 0-1), confidence scores.
- Serialize detection context as JSON: `{"presence": true, "count": 2, "positions": [{"x": 0.3, "y": 0.5, "confidence": 0.92}, ...], "timestamp": "..."}`.
- mmWave runs continuously in background; camera inference runs on-demand only (power/privacy optimization).
- Optional proactive mode: on mmWave presence change (absent → present), trigger greeting event.

#### Non-Functional

- mmWave detection latency: < 2 seconds from person entering room to presence=true.
- mmWave power consumption: negligible (sensor is always on, Pi reads UART).
- Camera capture + YOLO inference: < 500ms total per frame.
- Hailo-8 YOLO inference: < 100ms per frame.
- Memory usage: < 300 MB for YOLO model loaded on Hailo-8.
- Camera images never leave the device — only derived metadata (count, positions) sent to server.

#### Implementation Notes

**Project Structure (additions to `speaker/src/`):**
```
speaker/src/
├── presence/
│   ├── __init__.py
│   ├── mmwave_sensor.py      # UART reader + frame parser
│   ├── camera_detector.py    # Arducam capture + YOLO inference
│   ├── presence_context.py   # Combines mmWave + camera into context payload
│   └── hailo_inference.py    # Hailo-8 YOLO model runner
speaker/models/
├── yolov8n.hef               # Hailo-compiled YOLOv8-nano model
speaker/tests/
├── test_mmwave_sensor.py
├── test_camera_detector.py
└── test_presence_context.py
```

**Key Dependencies:**
```
pyserial>=3.5          # UART communication
opencv-python>=4.8     # Camera capture, image processing
hailo-platform>=4.17   # Hailo-8 inference runtime
numpy>=1.24
Pillow>=10.0           # Image handling
```

**mmWave Sensor Module (`mmwave_sensor.py`):**
- Open serial port (`/dev/ttyS0` or `/dev/ttyAMA0`, 115200 baud).
- Continuously read frames in a background thread.
- Parse presence status per sensor protocol (typically: header bytes → command → data → checksum).
- Expose: `is_present() -> bool`, `last_detection_time() -> datetime`, `get_raw_data() -> dict`.
- Handle serial errors (reconnect on disconnect, log errors).

**Camera Detector Module (`camera_detector.py`):**
- Capture single frame via `libcamera-still` subprocess or picamera2 Python library.
- Preprocess: resize to YOLO input size (640×640), normalize.
- Run Hailo-8 inference with YOLOv8-nano HEF model.
- Post-process: NMS, filter for person class (class 0 in COCO), extract bounding boxes.
- Return: `[{"x": float, "y": float, "w": float, "h": float, "confidence": float}, ...]`.

**Hailo Inference Module (`hailo_inference.py`):**
- Load YOLOv8-nano HEF model onto Hailo-8 device.
- Provide `infer(frame: np.ndarray) -> list[dict]` method.
- Handle Hailo device errors (device busy, model load failure).
- Fall back to OpenCV DNN or CPU YOLO if Hailo unavailable.

**Presence Context Module (`presence_context.py`):**
- Combine mmWave presence state + camera detection results.
- Produce canonical JSON payload for API transmission.
- Handle cases: mmWave says present but camera sees no one (sensor disagreement — trust mmWave for presence, camera for count).

---

### Error Scenarios & Fallbacks

- **mmWave sensor disconnected** → Log error, set presence to "unknown", attempt serial reconnect every 5 seconds. Do not crash main loop.
- **mmWave returns corrupt frames** → Validate checksum, discard invalid frames, log warning. Use last known good state.
- **Camera capture fails** → Log error, return presence context with mmWave-only data (`count: null`). Do not block voice pipeline.
- **Hailo-8 device busy / model load failure** → Fall back to CPU-based YOLO inference (slower, ~2-3 seconds). Log warning.
- **YOLO detects no persons but mmWave detects presence** → Trust mmWave for presence boolean; set count=0 with note "radar presence detected, no visual confirmation". This handles cases where person is outside camera FOV.
- **Privacy concern** → Camera images are processed in-memory and immediately discarded. No images are stored on disk or transmitted to server.

---

### Architectural Context

This PRD runs in parallel with PRD 9-03 (Wake Word & STT). Both subsystems feed into the API query (PRD 9-06):
- PRD 9-03 provides the transcribed text (what the user said).
- PRD 9-04 provides the presence context (who/how many are in the room).

The mmWave sensor runs continuously in a background thread (always monitoring). The camera + YOLO inference is on-demand only — triggered when:
1. A voice query is being assembled (enrich with "2 people in the room").
2. A proactive greeting is triggered (mmWave goes absent → present).
3. The server explicitly requests a presence update.

The Hailo-8 is shared between STT (PRD 9-03) and YOLO (this PRD). Since they run at different times (STT after wake word, YOLO on-demand), there should be no contention. If both are needed simultaneously, STT takes priority (user is speaking), and YOLO waits.

YOLOv8-nano was chosen for its small size (~6.3 MB) and fast inference. The Hailo-compiled HEF file must be generated using the Hailo Model Zoo or Dataflow Compiler.

---

### Acceptance Criteria

- [ ] mmWave sensor reads presence data via UART without errors
- [ ] Presence state changes detected within 2 seconds of person entering/leaving
- [ ] Camera captures frame via libcamera/picamera2
- [ ] YOLOv8-nano model loaded on Hailo-8 successfully
- [ ] Person detection identifies persons with > 80% accuracy in typical room lighting
- [ ] Inference time < 100ms on Hailo-8 (< 3s on CPU fallback)
- [ ] Presence context JSON payload correctly structured and serializable
- [ ] Camera images processed in-memory only — no disk storage or transmission
- [ ] mmWave background thread runs continuously without blocking main event loop
- [ ] Sensor disagreement handled gracefully (mmWave + camera fusion logic)
- [ ] All modules testable independently

---

### Test Cases

#### Unit (pytest)

- `tests/test_mmwave_sensor.py`:
  - Test frame parsing with known-good byte sequence → correct presence state
  - Test invalid checksum → frame discarded, no crash
  - Test serial timeout → returns last known state
  - Test reconnect logic on serial disconnect
- `tests/test_camera_detector.py`:
  - Test frame capture produces valid numpy array (correct shape, dtype)
  - Test YOLO inference on sample image with known person → detection returned
  - Test YOLO inference on empty room image → no detections
  - Test Hailo fallback to CPU when device unavailable
- `tests/test_presence_context.py`:
  - Test context with both mmWave + camera data → full JSON payload
  - Test context with mmWave only (camera failed) → partial payload with count=null
  - Test context serialization matches expected schema

#### Integration (pytest)

- `tests/test_presence_integration.py`:
  - Start mmWave reader + camera detector → walk into room → verify presence=true + count=1 within 3 seconds
  - Leave room → verify presence=false within 5 seconds

#### System / Smoke

- Manual: Walk in and out of room, observe console output for presence changes and person counts.

---

### Manual Verification

1. SSH into Pi. Activate venv: `source speaker/venv/bin/activate`.
2. Run mmWave test: `python -m src.presence.mmwave_sensor --test`.
3. Walk into sensor range — verify console shows `presence: true`.
4. Leave sensor range — verify console shows `presence: false`.
5. Run camera test: `python -m src.presence.camera_detector --test`.
6. Stand in front of camera — verify detection output shows count=1 with bounding box.
7. Add second person — verify count=2.
8. Run combined test: `python -m src.presence.presence_context --test`.
9. Verify JSON output includes both mmWave and camera data.

**Expected**
- mmWave detects presence within 2 seconds.
- YOLO counts persons correctly (±1 in cluttered scenes).
- Context payload is well-formed JSON.
- No images are saved to disk.

---

### Rollout / Deployment Notes

- The YOLOv8-nano HEF model must be compiled for Hailo-8 architecture. Use Hailo Model Zoo: `hailo model-zoo compile yolov8n --hw-arch hailo8`.
- Store compiled `.hef` file in `speaker/models/yolov8n.hef`.
- mmWave sensor baudrate and protocol vary by model. Document the specific model and firmware version used.
- For privacy: add a hardware camera disconnect (physical shutter or GPIO-controlled relay) as a future enhancement.
- Monitor Hailo-8 temperature under sustained inference: `hailortcli fw-control get-temp`.
