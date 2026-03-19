#### PRD-9-01: Hardware Assembly & Validation

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-9-01-hardware-assembly-feedback-V{{N}}.md` in the same directory.

---

### Overview

This PRD covers the physical assembly of the Eureka Smart Speaker POC. All ordered components are connected to the Raspberry Pi 5 in the correct stacking order, wired properly, and validated with a power-on smoke test. No software is involved—this is purely mechanical/electrical work that must be completed before any software setup.

The goal is a fully assembled, powered-on Pi 5 stack with all peripherals connected and ready for OS installation.

---

### Requirements

#### Functional

- Raspberry Pi 5 (16 GB) serves as the base platform with MicroSD slot accessible.
- iUniker ICE Peak cooler mounted with thermal pad contact to SoC; fan connected to PWM fan header.
- Extra-tall 2×20 stacking header installed on Pi 5 GPIO pins.
- HiFiBerry Amp4 stacked on GPIO header (I2S audio interface).
- AI HAT+ 26 TOPS (Hailo-8) stacked on top via PCIe connector with standoffs for clearance.
- SB Acoustics SB65WBAC25-4 speaker driver wired to Amp4 speaker terminals (18 AWG, polarity matched).
- Arducam Camera Module 3 Wide connected via 15-22 pin FFC cable to Pi 5 CSI port.
- Seeed 24 GHz mmWave sensor wired via jumper wires: VCC→5V, GND→GND, TX→RX (GPIO 10), RX→TX (GPIO 8).
- ReSpeaker XVF3800 plugged into USB 3.0 port.
- Power via Anker 65W charger through USB-C cable to Pi 5.

#### Non-Functional

- Assembly completed on a non-conductive surface.
- Components handled by edges to avoid ESD damage.
- All connections mechanically secure (no loose wires or headers).
- Thermal pads properly applied (no air gaps between SoC and heatsink).

#### Assembly Notes

**Step-by-step order:**

1. **Prepare Pi 5 Base**
   - Insert MicroSD card (will be flashed in PRD 9-02) into Pi 5 slot.
   - Apply thermal pads to Pi 5 SoC (CPU/GPU area) if not pre-applied on cooler.
   - Mount iUniker ICE Peak cooler: align heatsink over SoC, secure with clips/screws, plug fan connector into Pi 5 fan header.

2. **Stack the HATs**
   - Solder or attach extra-tall 2×20 stacking header to Pi 5 GPIO pins (align carefully; pin 1 indicator).
   - Stack HiFiBerry Amp4 onto GPIO header (align all 40 pins; it uses I2S for audio output).
   - Add M2.5 standoffs/screws for clearance between Amp4 and AI HAT+.
   - Stack AI HAT+ 26 TOPS on top (connects via PCIe FFC to Pi 5 PCIe connector; secure with screws from kit).

3. **Wire Speaker Driver**
   - Cut ~1–2 ft of 18 AWG speaker wire.
   - Strip ends (~0.5 inch / 12 mm).
   - Connect one end to Amp4 speaker terminals (+ to +, - to -; screw/spring clips).
   - Connect other end to SB Acoustics SB65WBAC25-4 driver terminals (match polarity).

4. **Connect Camera**
   - Use included 15-22 pin FFC cable.
   - Insert 22-pin end into Pi 5 CSI port (lift latch, insert with blue/contacts side toward HDMI ports, close latch).
   - Insert 15-pin end into Arducam Camera Module 3 Wide connector (lift latch, insert, close latch).

5. **Wire mmWave Sensor**
   - Using Chanzon female-to-male jumper wires:
     - VCC (red wire) → Pi 5 GPIO pin 2 or 4 (5V power).
     - GND (black wire) → Pi 5 GPIO pin 6 (ground).
     - Sensor TX (data out) → Pi 5 GPIO pin 10 (UART RX / GPIO 15).
     - Sensor RX (data in) → Pi 5 GPIO pin 8 (UART TX / GPIO 14).
   - Secure sensor facing room (front/side mount in enclosure).

6. **Connect Microphone**
   - Plug ReSpeaker XVF3800 into Pi 5 USB 3.0 port (blue port preferred for bandwidth).

7. **Power Connection**
   - Use 100W/10Gbps USB-C cable (short 1.5 ft) from Anker 65W charger to Pi 5 USB-C power port.
   - Do NOT power on yet if MicroSD is empty.

8. **Enclosure Mounting (3D-Printed Prototype)**
   - Mount Pi stack in enclosure with M2.5 standoffs.
   - Speaker driver front-facing (sealed or open baffle per design).
   - Mic array top-mounted for 360° pickup.
   - Camera front-facing (lens unobstructed).
   - mmWave sensor side/front-facing (unobstructed path to room).
   - Cooler vents unobstructed (allow airflow).
   - Secure all with standoffs/screws/nuts.

---

### Error Scenarios & Fallbacks

- **Stacking header misalignment** → Remove and realign; verify pin 1 orientation. Do not force.
- **Speaker polarity reversed** → Audio will be phase-inverted. Swap + and - wires at one end.
- **FFC cable not seated** → Camera will not be detected in software. Reseat with latch fully closed.
- **mmWave TX/RX swapped** → No serial data received. Swap the TX/RX jumper wires.
- **Pi does not power on** → Check USB-C cable and charger. Verify no shorts (metal touching metal). Check power LED.
- **Cooler fan not spinning** → Verify fan header connection. Fan is PWM-controlled; it may not spin at low temps.

---

### Architectural Context

This PRD is the physical foundation for all subsequent PRDs. No software or code is involved. The assembly order is critical:
1. Cooler must go on first (direct thermal contact with SoC).
2. Amp4 must be first HAT on GPIO (needs I2S pins directly).
3. AI HAT+ goes on top (uses PCIe, not GPIO for data).

The mmWave sensor uses UART on GPIO 8/10, which must not conflict with other HATs' GPIO usage. HiFiBerry Amp4 uses I2S pins (GPIO 18, 19, 20, 21) and does not conflict with UART (GPIO 14, 15).

---

### Acceptance Criteria

- [ ] All components physically mounted per assembly order
- [ ] Cooler has thermal pad contact with SoC and fan connected to fan header
- [ ] Amp4 stacked on GPIO with speaker wire connected (polarity verified)
- [ ] AI HAT+ stacked on top with PCIe FFC connected and standoffs securing it
- [ ] Camera FFC cable seated in both CSI port and camera module
- [ ] mmWave sensor wired: VCC→5V, GND→GND, TX→Pin10, RX→Pin8
- [ ] ReSpeaker plugged into USB 3.0 port
- [ ] Power cable connected (Pi powers on, LED blinks)
- [ ] No visible shorts, loose wires, or unsecured components
- [ ] Enclosure assembled with all components accessible and vents clear

---

### Test Cases

#### Unit (Manual Hardware Test)

- **Power-On Test**: Insert SD card (even blank), power on. Pi 5 power LED should illuminate (red = power, green = activity if bootable media present).
- **Fan Test**: After power-on, verify cooler fan spins (may need OS-level temp to trigger PWM; feel for airflow).
- **Visual Inspection**: All headers fully seated, no bent pins, speaker wire secure in terminals.

#### Integration (Manual)

- Integration testing deferred to PRD 9-02 (requires OS and drivers).

#### System / Smoke

- N/A for hardware-only PRD.

---

### Manual Verification

1. With all components assembled, connect Anker charger and power on.
2. Observe Pi 5 power LED (solid red = powered).
3. If MicroSD has Raspberry Pi OS (from PRD 9-02), observe green activity LED blinking.
4. Connect HDMI monitor (optional): verify boot output or rainbow screen.
5. Physically inspect:
   - No components are warm/hot to the touch within 10 seconds (indicates short).
   - Fan header wire is connected and fan spins (or is ready for PWM control).
   - Camera FFC cable is secure (gently tug — should not slide out).
   - Speaker wire is firmly in Amp4 screw terminals.
   - mmWave jumper wires are secure in GPIO pins.

**Expected**
- Pi powers on without issue.
- No components overheat unexpectedly.
- All connections are mechanically stable.
- Ready for OS installation (PRD 9-02).

---

### Rollout / Deployment Notes

- No software deployment for this PRD.
- Photograph the completed assembly for documentation.
- Label jumper wires with tape if colors are ambiguous.
- Keep spare standoffs and screws accessible for enclosure adjustments.
