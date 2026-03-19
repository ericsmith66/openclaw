#### PRD-9-02: Raspberry Pi OS & Driver Setup

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-9-02-os-driver-setup-feedback-V{{N}}.md` in the same directory.

---

### Overview

This PRD covers flashing Raspberry Pi OS, configuring system interfaces, installing all hardware drivers, and validating each component individually. Upon completion, every peripheral (mic, speaker, camera, mmWave, AI HAT+) will have a confirmed working driver and pass a standalone test. This is the software foundation that all subsequent PRDs build upon.

---

### Requirements

#### Functional

- Flash Raspberry Pi OS 64-bit Lite to MicroSD card using Raspberry Pi Imager.
- Pre-configure via Imager: enable SSH, set hostname (`eureka-speaker`), set username/password, configure Wi-Fi.
- Enable required interfaces via `raspi-config`: Camera (libcamera), I2C, Serial Port (UART), SPI (if needed by AI HAT+).
- Install and configure HiFiBerry Amp4 driver (`dtoverlay=hifiberry-dacplus-std`).
- Install Hailo-8 SDK (AI HAT+ 26 TOPS) and validate with `hailortcli fw-control identify`.
- Install ALSA utilities for microphone testing (`alsa-utils`).
- Install `libcamera-apps` for camera testing.
- Install `python3-serial` for mmWave UART communication.
- Install Python 3.11+ with pip, git, and general development dependencies.
- Validate each component with individual test commands.

#### Non-Functional

- System fully updated (`apt update && apt upgrade`).
- Boot time < 30 seconds to SSH-ready.
- All drivers load on boot without manual intervention.
- System uses < 1 GB RAM at idle (Lite OS, no desktop).

#### Implementation Notes

**OS Installation:**
```bash
# On dev machine: Use Raspberry Pi Imager
# Select: Raspberry Pi OS (64-bit) Lite
# Configure: SSH enabled, hostname=eureka-speaker, user/pass, Wi-Fi
# Write to MicroSD
```

**Post-Boot Configuration:**
```bash
# SSH in
ssh pi@eureka-speaker.local

# Update system
sudo apt update && sudo apt upgrade -y

# Enable interfaces
sudo raspi-config
# → Interface Options → Camera (libcamera) → Enable
# → Interface Options → I2C → Enable
# → Interface Options → Serial Port → Login shell: No, Hardware: Yes
# → Interface Options → SPI → Enable (for Hailo if needed)

sudo reboot
```

**Driver Installation:**

*HiFiBerry Amp4:*
```bash
# Edit boot config
sudo nano /boot/firmware/config.txt
# Add under [all]:
#   dtoverlay=hifiberry-dacplus-std
# Comment out: dtparam=audio=on (disable onboard audio)

sudo reboot

# Verify
aplay -l
# Should show: card N: sndrpihifiberry [snd_rpi_hifiberry_dacplus]
```

*Hailo-8 AI HAT+:*
```bash
# Install Hailo SDK (follow official Raspberry Pi AI HAT+ guide)
sudo apt install hailo-all
# OR download .deb from https://hailo.ai/developer-zone/
# sudo dpkg -i hailo-*.deb
# sudo apt install -f

sudo reboot

# Verify
hailortcli fw-control identify
# Should show: Hailo-8, firmware version, etc.
```

*ReSpeaker Microphone (USB):*
```bash
sudo apt install alsa-utils
arecord -l
# Should show USB audio device (ReSpeaker XVF3800)
```

*Camera:*
```bash
sudo apt install libcamera-apps
libcamera-hello --timeout 2000
# Should show camera preview for 2 seconds (or output to terminal in Lite)
```

*mmWave Sensor:*
```bash
sudo apt install python3-serial python3-pip
# Test with Python:
python3 -c "
import serial
ser = serial.Serial('/dev/ttyS0', 115200, timeout=2)
data = ser.read(100)
print(f'Received {len(data)} bytes: {data.hex()}')
ser.close()
"
# Should receive data bytes (sensor outputs frames continuously)
```

*General Dependencies:*
```bash
sudo apt install python3-pip python3-venv git build-essential \
  python3-dev libffi-dev libssl-dev libasound2-dev portaudio19-dev
```

---

### Error Scenarios & Fallbacks

- **No SSH access after boot** → Connect HDMI monitor and keyboard. Check Wi-Fi credentials. Verify SSH was enabled in Imager.
- **HiFiBerry not detected** → Verify `dtoverlay=hifiberry-dacplus-std` in `/boot/firmware/config.txt`. Check GPIO header seating.
- **Hailo not detected** → Verify PCIe FFC cable connection. Run `lspci` to check for Hailo device. Reinstall SDK.
- **ReSpeaker not in `arecord -l`** → Try different USB port. Check `dmesg | grep -i audio` for USB device detection.
- **Camera `libcamera-hello` fails** → Check FFC cable seating. Verify camera enabled in raspi-config. Check `dmesg | grep -i camera`.
- **mmWave no data** → Verify TX/RX wiring (may be swapped). Check baudrate (115200 is common; consult datasheet). Try `/dev/ttyAMA0` instead of `/dev/ttyS0`.
- **Kernel panic or boot loop** → Re-flash MicroSD. Check for conflicting dtoverlays.

---

### Architectural Context

This PRD establishes the runtime environment for all edge agent code. The key configuration decisions here affect every subsequent PRD:
- The HiFiBerry overlay selection (`dacplus-std`) determines ALSA device naming for TTS playback (PRD 9-05).
- The Hailo SDK version determines compatible YOLO models (PRD 9-04) and Whisper acceleration (PRD 9-03).
- The UART configuration (`/dev/ttyS0` vs `/dev/ttyAMA0`) determines the serial device path for mmWave (PRD 9-04).
- Python version and venv setup determine package compatibility for all Python PRDs.

No changes to the eureka-homekit Rails app are required for this PRD.

---

### Acceptance Criteria

- [ ] Pi boots Raspberry Pi OS 64-bit Lite and is SSH-accessible at `eureka-speaker.local`
- [ ] System fully updated (`apt update && apt upgrade` completed)
- [ ] Camera enabled and `libcamera-still -o test.jpg` produces a valid JPEG
- [ ] I2C enabled (`sudo i2cdetect -y 1` runs without error)
- [ ] Serial/UART enabled and `/dev/ttyS0` or `/dev/ttyAMA0` exists
- [ ] HiFiBerry Amp4 detected: `aplay -l` shows hifiberry device
- [ ] `speaker-test -c2 -t wav` plays audio through the speaker driver
- [ ] Hailo-8 detected: `hailortcli fw-control identify` returns device info
- [ ] ReSpeaker detected: `arecord -l` shows USB audio device
- [ ] `arecord -D plughw:N,0 -d 5 -f S16_LE -r 16000 test.wav` records audio (N = ReSpeaker card number)
- [ ] `aplay test.wav` plays back recorded audio through speaker
- [ ] mmWave sensor returns data bytes via pyserial
- [ ] Python 3.11+ available with pip and venv

---

### Test Cases

#### Unit (Component Validation)

- **test_speaker_output**: `speaker-test -c2 -t wav -l 1` → audible tone from SB Acoustics driver
- **test_mic_input**: `arecord -D plughw:N,0 -d 3 -f S16_LE -r 16000 /tmp/mic_test.wav` → file > 0 bytes
- **test_mic_playback**: `aplay /tmp/mic_test.wav` → recorded audio audible
- **test_camera_capture**: `libcamera-still -o /tmp/cam_test.jpg` → valid JPEG file
- **test_mmwave_serial**: Python serial read returns > 0 bytes within 2-second timeout
- **test_hailo_identify**: `hailortcli fw-control identify` exits with code 0

#### Integration (Cross-Component)

- **test_record_and_play**: Record 5 seconds from mic, play back through speaker → audio round-trip works
- **test_camera_and_hailo**: Capture frame, run Hailo sample inference → inference completes without error

#### System / Smoke

- **test_boot_time**: Time from power-on to SSH-accessible < 30 seconds
- **test_idle_memory**: `free -m` shows used memory < 1024 MB at idle
- **test_all_devices**: Script that runs all component tests sequentially and reports pass/fail

---

### Manual Verification

1. Power on the assembled Pi (from PRD 9-01).
2. Wait 30 seconds, then SSH: `ssh pi@eureka-speaker.local`.
3. Run `aplay -l` — verify HiFiBerry appears.
4. Run `speaker-test -c2 -t wav -l 1` — listen for test tone from speaker.
5. Run `arecord -l` — verify ReSpeaker appears.
6. Run `arecord -D plughw:N,0 -d 5 -f S16_LE -r 16000 /tmp/test.wav` — speak into mic.
7. Run `aplay /tmp/test.wav` — verify your voice plays back.
8. Run `libcamera-still -o /tmp/test.jpg` — verify file created and > 0 bytes.
9. Run `hailortcli fw-control identify` — verify Hailo-8 device info.
10. Run mmWave Python test — verify data bytes received.

**Expected**
- All 6 component tests pass individually.
- Record-and-play round-trip confirms mic and speaker work together.
- System is ready for edge agent software (PRDs 9-03 through 9-07).

---

### Rollout / Deployment Notes

- Document the exact ALSA card numbers for ReSpeaker and HiFiBerry (they may vary; note them for later PRDs).
- Document the serial device path for mmWave (`/dev/ttyS0` or `/dev/ttyAMA0`).
- Save `/boot/firmware/config.txt` changes to the repo (`speaker/config/config.txt.example`).
- Create a `speaker/scripts/validate_hardware.sh` script that runs all component tests.
