#### PRD-3-01: Floorplan Asset & Mapping Engine

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-3-01-asset-mapping-engine-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

This PRD focuses on the infrastructure required to store, retrieve, and map SVG elements to Database rooms. It establishes the "source of truth" for spatial data within Eureka, allowing the system to understand which part of an SVG file corresponds to which physical room in the database.

---

### Requirements

#### Functional

- **Asset Storage**: Extend the `Home` model (or create a related `Floorplan` model) to support multiple levels, each with an attached SVG file.
- **Mapping Schema**: Define a standard JSON format for the mapping file.
  - Must support linking by SVG `id` (e.g., `Graphic_15`).
  - Must support linking by SVG Group names (e.g., `Living Room Group`).
  - Should include metadata like `level` and `room_id`.
- **API Endpoint**: Create a Rails endpoint that returns:
  - The SVG content (as a string or URL).
  - The mapping metadata.
  - The current state (temp, humidity, motion, occupancy) for all mapped rooms.
- **Fallback Mechanism**: If an SVG or mapping entry is missing for a room, the system should gracefully exclude it from visual rendering without crashing.

#### Non-Functional

- **Performance**: Fetching the floorplan and room states should be optimized to avoid N+1 queries.
- **Reliability**: Handle cases where SVG IDs might change (e.g., provide a way to map based on Group names which are more stable in OmniGraffle).

#### Rails / Implementation Notes (optional)

- **Models**: `Home`, `Room`, (Optional) `FloorplanAsset`.
- **Controllers**: `Api::FloorplansController`.
- **Migrations**: Add `floorplan_assets` support to `Home` or create a new table.

---

### Error Scenarios & Fallbacks

- **Missing SVG ID in Mapping** → Log a warning and ignore the element in the viewer.
- **Room ID not found in DB** → Log a warning and treat the SVG region as "unmapped".
- **Empty SVG file** → Return an error or a placeholder message in the UI.

---

### Architectural Context

This PRD provides the data foundation for the subsequent viewer (PRD 3-02) and heatmap (PRD 3-03). It resides in the backend and focuses on data modeling and API delivery.

---

### Acceptance Criteria

- [ ] `Home` model can successfully store and retrieve SVG files for different levels.
- [ ] A `mapping.json` can be uploaded/associated and parsed correctly.
- [ ] API endpoint returns a JSON payload containing the SVG and the associated room states.
- [ ] System handles missing mapping entries without crashing.

---

### Test Cases

#### Unit (Minitest)

- `test/models/home_test.rb`: Test floorplan asset attachment and retrieval.
- `test/services/floorplan_mapping_service_test.rb`: Test parsing of the mapping JSON and resolving room IDs.

#### Integration (Minitest)

- `test/requests/api/floorplans_controller_test.rb`: Test the API endpoint for correct JSON structure and room state injection.

---

### Manual Verification

1. Upload an SVG and a `mapping.json` to a Home record via the Rails console or a temporary form.
2. Query the API endpoint for that Home.
3. Verify that the response includes the SVG content and a list of mapped rooms with their current sensor values.

**Expected**
- API returns 200 OK.
- Response contains the SVG string.
- Response contains an array of rooms with `room_id` and latest `sensor_states`.

---

### Rollout / Deployment Notes (optional)

- Initial mapping will be hand-edited in JSON files.
- POC will use the provided `BluePrints.svg` and `waverly.json` metadata.
