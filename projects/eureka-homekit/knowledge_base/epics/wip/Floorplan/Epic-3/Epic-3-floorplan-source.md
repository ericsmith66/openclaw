This is a significant feature that bridges the gap between static architectural data and real-time HomeKit state. To keep this atomic and manageable, I have structured this as an **Epic** divided into three logical **Product Requirement Documents (PRDs)**.

---

# **Epic: Interactive Floorplan & Activity Heatmap**
**Goal:** Transform static SVG blueprints into a dynamic, interactive navigation and monitoring dashboard for Eureka.

### **High-Level Architecture**
- **Data Source:** SVGs for visuals, `waverly.json` (or similar) for metadata, and `Room` models for system state.
- **Mapping:** A dedicated JSON "Map File" will link SVG `id` attributes (e.g., `Graphic_15`) to Database `room_id` values.
- **Fallback:** If assets are missing, the UI reverts to the current list-based view.
- **Navigation:** EAS : assume we preserve the existing Dashboard navigation. but add a floorplan button next to events
---

## **PRD-001: Floorplan Asset & Mapping Engine**
**Focus:** The infrastructure required to store, retrieve, and map SVG elements to Database rooms.

### **Requirements**
1. **Asset Storage:** Extend the `Home` model to support `floorplan_assets` (SVG files for each level and a master `mapping.json`).
2. **The Mapping Schema:** Define a standard format for the mapping file.
   - *Example:* `{"Graphic_15": {"room_id": 45, "level": 1}, "Group_55": {"room_id": 12, "level": 1}}`
3. **API Endpoint:** Create an endpoint that returns the SVG content along with the current sensor state for all mapped rooms.

### **Questions for PRD-001**
- **Q1:** Should the mapping file be manually created by the user via a UI, or is it acceptable to continue hand-editing a JSON file in the `knowledge_base` for now? EAS Hand editing for now
- **Q2:** How should we handle SVG IDs that change if the file is re-exported from OmniGraffle? (Should we use a more stable identifier?) EAS - what would you propose ?

---

## **PRD-002: Interactive Floorplan Viewer**
**Focus:** The frontend implementation of the SVG as a navigation tool.

### **Requirements**
1. **Responsive Viewer:** A component that renders the SVG and allows zooming/panning.
2. **Interactive Regions:**
   - Mapped rooms must be "hoverable" (highlight) and "clickable" (Redirect to `room_path(room)`).
   - Unmapped regions (e.g., "Rectangle", "Elevator") should be greyed out or semi-transparent.
3. **Dynamic Labels:** Inject labels into the SVG based on the Database room names rather than just relying on the static text in the SVG.
4. **Multi-Level Support:** A level-switcher (e.g., "1st Floor", "2nd Floor") to swap the active SVG.

### **Questions for PRD-002**
- **Q3:** For clickable rooms, should they open in a modal or perform a full page navigation? EAS Modular
- **Q4:** Do we want a "Legend" to explain why some rooms are greyed out? EAs if room permits

---

## **PRD-003: Real-time Activity Heatmap**
**Focus:** Visualizing sensor activity (motion/occupancy) as a heatmap overlay on the floorplan.

### **Requirements**
1. **Activity Scoring:** Define what "Heat" means.
   - *Active:* Motion detected in the last 5 minutes (Bright Red/Orange).
   - *Warm:* Occupancy detected but no recent motion (Yellow).
   - *Cold:* No activity for >15 minutes (Blue or Neutral).
2. **SVG CSS Injection:** Use CSS classes or inline styles to change the `fill` color of SVG elements based on real-time activity scores.
3. **Live Updates:** Use ActionCable (or the existing polling mechanism) to update the room "heat" without a page refresh.
4. **Aggregation:** If a group (like "Master Suite") contains multiple rooms, the "heat" should represent the highest activity level within that group.

### **Questions for PRD-003**
- **Q5:** Should "Heat" be based solely on Motion/Occupancy, or should we factor in things like "Lights On" or "High Temperature"? EAS for now , we also want to inject sensor data into each room ( temp humidity etc )
- **Q6:** What is the preferred visual style for the heatmap? (Solid color fill, a glowing pulse effect, or a literal radial gradient?). EAS glowing Pulse sounds cool

---

### **Next Steps**
1. **Validation:** Review the questions above.
2. **POC:** I can begin by creating a sample `mapping.json` for the 1st Floor based on our recent mapping work.
3. **UI Integration:** Decide where this "Map View" lives in the existing Rails app (e.g., a new tab on the Dashboard).