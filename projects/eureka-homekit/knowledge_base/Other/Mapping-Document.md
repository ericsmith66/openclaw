I have mapped the metadata from the 1st and 2nd Floor SVG blueprints to the database room names and cross-referenced them with `waverly.json` to extract dimensions and square footage.

### **First Floor Mapping**

| SVG Name | DB Room Name | Dimensions (JSON) | Sq Ft (JSON) | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Living Room** | Living Room | 15'-0" × 20'-0" | 300 | Exact Match |
| **Master Bedroom** | Master Bedroom | 15'-0" × 18'-0" | 270 | Exact Match |
| **Master Bath** | Master Bath | 10'-0" × 12'-0" | 120 | Exact Match |
| **Master Closet** | Master Closet | 8'-0" × 10'-0" | 80 | Exact Match |
| **Foyer** | Foyer | 10'-0" × 10'-0" | 100 | Exact Match |
| **Coffee Bar** | (N/A) | 5'-0" × 8'-0" | 40 | Listed in JSON, but not a distinct DB room |
| **Dining Room** | Dining Room | 12'-0" × 16'-6" | 200 | JSON: "Dining Room / Library" |
| **Kitchen** | Kitchen | 14'-0" × 18'-0" | 250 | JSON: "Main Kitchen" |
| **Scullary** | Scullary | 8'-0" × 10'-0" | 80 | JSON: "Scullery" |
| **Utility Room** | Utility Room | 7'-0" × 10'-0" | 70 | JSON: "Laundry" |
| **Shop** | Shop | 10'-0" × 15'-0" | 150 | JSON: "Workroom" |
| **Front Powder** | Front Powder | 5'-0" × 8'-0" | 40 | JSON: "Powder Bath #1" |
| **Back Powder** | Back Powder | 5'-0" × 8'-0" | 40 | JSON: "Powder Bath #2" |
| **Garage** | Garage | 20'-0" × 30'-0" | 600 | JSON: "Garage #1" |
| **Front Pourch** | Front Porch | 10'-0" × 15'-0" | 150 | Exact Match (Spelling: Porch) |
| **North Porch** | North Porch | 8'-0" × 12'-6" | 100 | JSON: "Side Porch" |
| **Courtyard** | Courtyard | 10'-0" × 12'-0" | 120 | JSON: "Sitting Area" |
| **Mechanical Room**| (N/A) | 5'-0" × 8'-0" | 40 | JSON (2nd Floor): "Mech" |

---

### **Second Floor Mapping**

| SVG Name | DB Room Name | Dimensions (JSON) | Sq Ft (JSON) | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Studio** | Studio | 12'-0" × 16'-6" | 200 | JSON: "Aerial Studio" |
| **Office** | Office | 10'-0" × 12'-0" | 120 | JSON: "Home Office" |
| **Guest Room** | Guest Room | 12'-0" × 15'-0" | 180 | JSON: "Bedroom #1" |
| **Quinn's Room** | Quinn’s Room | 11'-0" × 14'-6" | 160 | JSON: "Bedroom #2" |
| **Jacob's Room** | Jacob’s Room | 10'-0" × 15'-0" | 150 | JSON: "Bedroom #3" |
| **Apt Bath** | Apt Bath | 6'-0" × 8'-0" | 50 | JSON: "3/4 Bath" |
| **Guest Bath** | (N/A) | 6'-0" × 10'-0" | 60 | JSON: "Full Bath" |
| **Kitchenette** | Kitchenette | 8'-0" × 10'-0" | 80 | Exact Match |
| **Apartment** (Group)| (N/A) | 20'-0" × 20'-0" | 400 | JSON: "Garage Apt" |
| **Prepper Closet** | Prepper closet | (N/A) | (N/A) | In DB & SVG, not in JSON |
| **Landing** | Landing | (N/A) | (N/A) | In DB & SVG, not in JSON |
| **Back Hall** | Back Hall | (N/A) | (N/A) | In DB & SVG, not in JSON |

### **Summary of Measurements**
*   **Total Living Square Footage:** 4,300 sq ft (JSON)
*   **1st Floor Living:** 2,800 sq ft (JSON)
*   **2nd Floor Living:** 1,500 sq ft (JSON)

Many of the system/logical zones (e.g., `Z-Hidden`, `Z-Power`) and structural areas (e.g., `Front Stairs`, `Elevator`) are present in the SVG and DB but do not have specific square footage listed in the `waverly.json` summary.