# Task Log: PRD-3-01 Floorplan Asset & Mapping Engine

## Status
- **Date**: 2026-02-07
- **Status**: In Progress
- **Branch**: `epic-3/mapping-engine`

## Tasks

### 1. Data Modeling
- [x] Create `Floorplan` model.
- [x] Add `ActiveStorage` attachments for SVG and JSON mapping.
- [x] Link `Home` to `Floorplan`.

### 2. Mapping Service
- [x] Implement `FloorplanMappingService`.
- [x] Support mapping by SVG ID and Group Name.

### 3. API Development
- [x] Create `Api::FloorplansController`.
- [x] Implement `show` action returning SVG + Mapping + Room States.

## Manual Test Steps

### Test 1: Asset Attachment
1. Create a `Floorplan` for a `Home`.
2. Attach an SVG and a `mapping.json`.
3. Verify files are stored and accessible.

### Test 2: Mapping Resolution
1. Use `FloorplanMappingService` to resolve a mapping file.
2. Verify it correctly links SVG IDs/Groups to existing `Room` records.

### Test 3: API Response
1. GET `/api/floorplans/:id`.
2. Verify JSON structure contains `svg_content`, `mapping`, and `rooms`.
3. Verify `rooms` contains latest sensor data.

## Expected Results
- Successful database migration.
- `FloorplanMappingService` returns a hash of resolved room data.
- API returns 200 OK with all required fields.
