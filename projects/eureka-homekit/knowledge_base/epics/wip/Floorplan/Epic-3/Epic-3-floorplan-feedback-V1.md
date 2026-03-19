# Review Feedback: Epic-3-floorplan (V1)

## Overview
The Epic for the Interactive Floorplan & Activity Heatmap is well-structured. The decision to break it into three PRDs (Asset/Mapping, Viewer, Heatmap) is sound. The user's inline comments (EAS) provide clear direction on manual mapping, modular room views, and sensor data injection.

---

## Questions & Suggestions

### PRD-001: Asset Storage & Mapping- EAS Agree with your recommendations
- **Suggestion (Q2 - Stable Identifiers):** To solve the issue of changing IDs from OmniGraffle, I propose using a **Secondary Mapping Layer** or **Manual Metadata tagging** within the SVG (if possible) or, more practically, mapping based on **SVG Group Names** if OmniGraffle exports them consistently. 
  - *Alternative:* If the SVG is hand-edited once, we could add a custom `data-room-id` attribute to the SVG elements. This would survive re-exports if we have a script to re-inject them based on coordinates or element types, though that's complex.
  - *Recommendation:* Stick to the JSON mapping but perhaps include a "Coordinate/Centroid" fallback if IDs change, or use the `title` attribute if OmniGraffle exports room names into it.
- **Question:** How will we handle multiple SVGs for the same level (e.g., architectural vs. electrical)? Or are we assuming one master SVG per level?

### PRD-002: Interactive Viewer- EAS Agree with your recommendations
- **Improvement:** For the "Responsive Viewer", consider using `panzoom` libraries (like `svg-pan-zoom`) to handle the heavy lifting of navigation.
- **Suggestion:** For "Dynamic Labels", instead of injecting text *into* the SVG (which can break layout/alignment), consider an **Overlay Layer** using HTML/Canvas that positions labels over the SVG coordinates. This keeps the SVG clean.

### PRD-003: Real-time Heatmap & Sensor Injection- EAS Agree with your recommendations
- **Improvement (Q5 - Sensor Data):** Since we want to inject temp/humidity, we should define a "Room Stat" component that appears on hover or as a persistent small badge within the room boundaries on the floorplan.
- **Objection (Q6 - Glowing Pulse):** While "cool", a glowing pulse for *every* room might become visually noisy. 
  - *Solution:* Limit the "pulse" to rooms with **Active Motion** only. Use solid (but semi-transparent) fills for Heat/Warm/Cold states to maintain legibility of the underlying blueprint.

---

## Objections & Potential Solutions

### Objection 1: Manual JSON Mapping Scalability - EAS Agree with your recommendations but PRD 004 
- **Concern:** Hand-editing a JSON mapping for every room and every floor will be error-prone and tedious as the system grows.
- **Solution:** In PRD-002 or a future PRD, add a "Mapping Mode" to the UI where a user can click an unmapped SVG element and select a Room from a dropdown to generate the JSON entry.

### Objection 2: SVG ID Fragility (Q2) EAS Agree with your recommendations but I would rely on names in the interim not the ids 
- **Concern:** Relying on `Graphic_15` is extremely fragile.
- **Solution:** Implement a **Visual Mapping Tool** (as mentioned above). Even if IDs change, a quick 5-minute re-mapping in the UI is better than hand-editing JSON after every export.

### Objection 3: Data Aggregation (Requirement 4) EAS Ignore the Master Suite orginazaiton for now. once we have the POC up we can revisit.
- **Concern:** Aggregating "heat" for a Suite might mask specific room activity.
- **Solution:** Allow "Drill-down". Clicking the "Master Suite" (if mapped as a group) could highlight the individual rooms within it if they are also mapped.

---

## Next Steps Improvements
- **POC:** The POC should include a script or method to "scrub" the OmniGraffle SVG to ensure it's web-optimized (removing metadata, reducing file size) before storage.
- **Schema:** The `mapping.json` should probably include `viewBox` coordinates or `transform` data if we want to support the Overlay Labels suggested above.
