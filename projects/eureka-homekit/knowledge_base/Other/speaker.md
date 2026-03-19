# Eureka Smart Speaker POC Assembly Guide

This guide provides step-by-step instructions for assembling the hardware and setting up the software for your Raspberry Pi 5-based Eureka smart speaker Proof of Concept (POC). The speaker will feature far-field voice input, person presence/detection, TTS output with a custom Eureka voice, and integration with your `eureka-homekit` Ruby on Rails app (running on your M3 Ultra server with Postgres, Ollama, and nextgen-plaid/smart-proxy). We'll fork the Prefab repo as the root project base and use Aider Desktop for code modifications where needed.

The guide identifies key points where custom code will be required to interface with Eureka (e.g., API calls via smart-proxy, Ollama for TTS/voice cloning, and agent logic per `.junie/guidelines`). These code points align with your `knowledge_base/epics` PRDs and templates.

**Prerequisites:**
- All ordered parts (Raspberry Pi 5 16GB, ReSpeaker XVF3800 mic, HiFiBerry Amp4, Arducam Camera Module 3 Wide, Seeed 24GHz mmWave sensor, iUniker ICE Peak cooler, Anker 65W charger, Raspberry Pi AI HAT+ 26 TOPS, SB Acoustics SB65WBAC25-4 speaker driver, jumper wires, stacking header, speaker wire, thermal pads, USB-C cables, MicroSD card 64GB+).
- Access to your M3 Ultra server (Ollama running for local LLM/TTS, eureka-homekit Rails app deployed, nextgen-plaid/smart-proxy active).
- Aider Desktop installed for code edits.
- Fork the Prefab repo: Go to https://github.com/prefabapp/prefab, fork it to your GitHub (e.g., `ericsmith66/prefab-fork`), clone locally, and set it as the root project base for mods (integrate eureka-homekit logic here if needed).

**Safety Notes:** Work on a non-conductive surface. Handle components by edges to avoid static damage. Use thermal pads properly to prevent overheating.

## Section 1: Hardware Assembly

Follow these steps in order. Estimated time: 30–60 minutes.

1. **Prepare the Raspberry Pi 5 Base:**
    - Insert the MicroSD card (prepped with Raspberry Pi OS in Section 2) into the Pi 5 slot.
    - Apply thermal pads to the Pi 5 SoC (CPU/GPU area) if not pre-applied on the iUniker cooler.
    - Mount the iUniker ICE Peak cooler: Align the heatsink over the SoC, secure with clips/screws (fan connector plugs into Pi 5's fan header for PWM control).

2. **Stack the HATs:**
    - Solder or attach the extra-tall 2x20 stacking header to the Pi 5's GPIO pins (if not pre-soldered; align carefully).
    - Stack the HiFiBerry Amp4 onto the GPIO header (align pins; it uses I2S for audio).
    - Use M2.5 standoffs/screws to add clearance, then stack the AI HAT+ 26 TOPS on top (it connects via PCIe; secure with screws from the kit).

3. **Connect the Speaker Driver:**
    - Cut ~1–2 ft of 18AWG speaker wire.
    - Strip ends (~0.5 inch), connect one end to the Amp4's speaker terminals (+/- screw/spring clips).
    - Connect the other end to the SB Acoustics SB65WBAC25-4 driver terminals (match polarity: + to +, - to -).

4. **Connect the Camera:**
    - Use the included 15cm 15-22 pin FFC cable: Insert the 22-pin end into the Pi 5's CSI port (blue side toward HDMI ports).
    - Insert the 15-pin end into the Arducam Camera Module 3 Wide (secure in acrylic case if desired).

5. **Connect the mmWave Sensor:**
    - Use jumper wires (female-male from Chanzon kit):
        - VCC (red) → Pi 5 GPIO pin 2 or 4 (5V).
        - GND (black) → Pi 5 GPIO pin 6 (GND).
        - TX (sensor output) → Pi 5 GPIO pin 10 (RX, UART).
        - RX (sensor input) → Pi 5 GPIO pin 8 (TX, UART).
    - Mount the sensor facing the room (e.g., in your 3D-printed case).

6. **Connect the Microphone:**
    - Plug the ReSpeaker XVF3800 into one of the Pi 5's USB ports (USB 3.0 preferred).

7. **Power Connections:**
    - Use a 100W/10Gbps USB-C cable (short 1.5ft pack) from Anker charger to Pi 5 USB-C port.

8. **Enclosure Mounting (Custom 3D-Printed Case):**
    - Mount the Pi stack, speaker driver (front-facing), mic array (top for 360° pickup), camera (front), mmWave (side/front), and cooler (with vents).
    - Secure with M2.5 standoffs/screws/nuts.
    - Test fit: Power on briefly (no OS needed yet) to check for shorts/lights (Pi 5 LED should blink).

**Hardware Test:** Once assembled, insert SD card and power on. If the Pi boots (monitor via HDMI if needed), proceed to software.

## Section 2: Software Setup

Estimated time: 1–2 hours. Use a monitor/keyboard/mouse initially, or enable SSH/headless mode.

1. **Install Raspberry Pi OS:**
    - Download Raspberry Pi OS 64-bit Lite (or Desktop) from raspberrypi.com/software.
    - Use Raspberry Pi Imager to flash to MicroSD (enable SSH, set username/password, Wi-Fi if needed).
    - Insert SD, power on Pi 5. SSH in (e.g., `ssh pi@raspberrypi.local`, default pass: raspberry).

2. **Update System and Enable Interfaces:**
    - Run:
      ```
      sudo apt update && sudo apt upgrade -y
      sudo raspi-config
      ```
    - In raspi-config: Interface Options → Enable Camera (libcamera), I2C (for Amp4 if needed), Serial Port (for mmWave UART).
    - Reboot: `sudo reboot`.

3. **Install Drivers and Libraries:**
    - **HiFiBerry Amp4:** Edit `/boot/config.txt` (use nano): Add `dtoverlay=hifiberry-dacplus-std`. Reboot.
    - **AI HAT+ 26 TOPS (Hailo-8):** Install Hailo SDK: Follow https://hailo.ai/developer-zone/software-downloads/ (download Raspbian package, install with dpkg). Test: `hailortcli fw-control identify`.
    - **ReSpeaker Mic:** USB auto-detects. Install `arecord` if needed: `sudo apt install alsa-utils`.
    - **Camera:** `sudo apt install libcamera-apps`. Test: `libcamera-hello`.
    - **mmWave Sensor:** Install pyserial: `sudo apt install python3-serial`.
    - **General Dependencies:** `sudo apt install python3-pip git` (for code repos).

4. **Basic Component Tests:**
    - **Mic:** `arecord -d 5 test.wav` (record 5s), then `aplay test.wav`.
    - **Speaker/Amp4:** `speaker-test -c2 -t wav` (plays test tone).
    - **Camera:** `libcamera-still -o test.jpg` (captures photo).
    - **mmWave:** Python script: `import serial; ser = serial.Serial('/dev/ttyS0', 115200); print(ser.readline())` (adjust baudrate per datasheet).
    - **AI HAT+:** Run a sample Hailo inference (e.g., object detection demo from SDK).

5. **Clone Repos and Set Up Project Structure:**
    - Fork Prefab: Already done (your `ericsmith66/prefab-fork`).
    - Clone locally on Pi (or your dev machine, then push): `git clone https://github.com/ericsmith66/prefab-fork.git prefab-root`.
    - Clone eureka-homekit: `git clone https://github.com/ericsmith66/eureka-homekit.git`.
    - Use Aider Desktop: Open prefab-root, add eureka-homekit as submodule or merge relevant files (epics/PRDs from knowledge_base, templates, .junie/guidelines for agents).

## Section 3: Integration with Eureka

This section integrates the speaker with your eureka-homekit Rails app (via nextgen-plaid/smart-proxy for secure API calls) and Ollama on M3 Ultra for AI processing/TTS. Use Python on the Pi for edge logic (lightweight; offload heavy tasks to server). Use Aider for code mods in your prefab-fork root.

**Key Code Points to Write/Modify (Using Aider Desktop):**
These align with your epics/PRDs (e.g., smart home automation, AI agent guidelines in .junie).

1. **Wake Word Detection (Custom Code Needed):**
    - Install Picovoice/Porcupine: `pip install pvporcupine`.
    - Code: Python script to listen on ReSpeaker mic for "Hey Eureka" (use Porcupine demo as base). On detection, trigger STT.
    - Interface Point: Send wake event to eureka-homekit API (POST via smart-proxy: `https://your-proxy/eureka/wake` with context).

2. **Speech-to-Text (STT) (Custom Code Needed):**
    - Install Whisper (local via AI HAT+ for acceleration): `pip install openai-whisper` (use Torch for Hailo offload).
    - Code: Capture audio post-wake, transcribe locally, send text to eureka-homekit API (e.g., `requests.post('https://your-proxy/eureka/query', json={'text': transcribed_text}')`).
    - Per .junie/guidelines: Add agent context (e.g., room occupancy from detection).

3. **Person Detection/Presence (Custom Code Needed):**
    - mmWave: Python serial read for presence trigger (proactive mode).
    - Camera + AI HAT+: Use OpenCV/YOLOv8 (accelerated on Hailo): `pip install opencv-python ultralytics`.
    - Code: On mmWave trigger, run YOLO for person count/position; send to eureka-homekit (e.g., `{'presence': True, 'count': 2}` via API).
    - Interface Point: Update epics/PRD for context-aware responses (e.g., greet user).

4. **Text-to-Speech (TTS) Playback (Custom Code Needed):**
    - Receive response from eureka-homekit/Ollama (custom voice cloned via Ollama on M3 Ultra).
    - Code: Use gTTS or ElevenLabs wrapper: `pip install gtts`. Play via Amp4: `aplay response.wav`.
    - Interface Point: Poll or WebSocket from smart-proxy for TTS audio/text (e.g., `ws://your-proxy/eureka/response`).

5. **Overall Agent Loop (Custom Code Needed):**
    - Main Python script: Infinite loop for wake → STT → API call → TTS.
    - Use Aider to mod prefab-fork: Integrate as an edge agent per .junie/guidelines (e.g., add Ruby snippets for Rails-side handling if needed, but Pi is Python-focused).
    - Test: Simulate with your knowledge_base/epics (e.g., home automation PRD).

**Deployment Notes:** Run the main script as a systemd service on Pi (`sudo systemctl`). Monitor with your M3 Ultra (e.g., Rails logs). Use Aider for iterative mods based on tests.

If issues arise (e.g., GPIO conflicts), debug with `raspi-gpio get`. For Xcode AI-agent extension (iOS/HomeKit bridging), we'll cover in a follow-up guide—focus here on Pi POC first.

Once set up, test end-to-end: "Hey Eureka, who's in the room?" → Detection → API → Ollama response → TTS. Let me know for tweaks or next steps!