# Epic 1: Atomic PRD Index

## Overview
Epic 1 broken into 4 atomic PRDs for focused implementation.

## PRDs

### PRD 1.1: Database Schema for HomeKit Data
**File**: `epic-1-prd-1-database-schema.md`
**Status**: Ready
**Dependencies**: None
**Summary**: Create Home, Room, Accessory, Scene, SceneAccessory, and HomekitEvent models with migrations. Scenes have many-to-many relationship with Accessories.

---

### PRD 1.2: Prefab HTTP Client Service
**File**: `epic-1-prd-2-prefab-http-client.md`
**Status**: Ready
**Dependencies**: None
**Summary**: Build `PrefabClient` service to query Prefab REST API for homes, rooms, accessories, and scenes.

---

### PRD 1.3: HomeKit Sync Service & Rake Task
**File**: `epic-1-prd-3-homekit-sync-service.md`
**Status**: Ready
**Dependencies**: PRD 1.1, PRD 1.2
**Summary**: Create `HomekitSync` service and `rails homekit:sync` task to populate database from Prefab, including scenes with many-to-many accessory relationships.

---

### PRD 1.4: Webhook Endpoint for Prefab Events
**File**: `epic-1-prd-4-webhook-endpoint.md`
**Status**: Ready
**Dependencies**: PRD 1.1
**Summary**: Build `POST /api/homekit/events` endpoint with auth to receive real-time events from Prefab.

---

## Implementation Order

### Parallel Track 1
1. PRD 1.1 (Database Schema)
2. PRD 1.4 (Webhook Endpoint)

### Parallel Track 2
1. PRD 1.2 (HTTP Client)
2. PRD 1.3 (Sync Service) - *requires PRD 1.1 & 1.2*

## Total Scope
- 6 models (Home, Room, Accessory, Scene, SceneAccessory, HomekitEvent)
- 6 migrations
- 2 service classes (PrefabClient, HomekitSync)
- 1 controller (Api::HomekitEventsController)
- 1 rake task (homekit:sync)
- Auth setup via Rails credentials

## Key Design Decisions
- **Scenes → Accessories**: Many-to-many via `scene_accessories` join table
- **Scene Scope**: Scenes belong to Home (not Room), can include accessories from any room
- **Sync Strategy**: Clear and rebuild scene associations on each sync to handle changes

---
**Epic Created**: 2026-01-25
**Last Updated**: 2026-01-25
