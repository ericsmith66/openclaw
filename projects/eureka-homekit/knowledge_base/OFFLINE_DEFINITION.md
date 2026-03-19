# Offline Status Definition

In Eureka Homekit, an **offline sensor or accessory** is defined as one that is currently not responding to HomeKit, as reported by the device itself or the HomeKit bridge.

## Primary Indicators (Prioritized)

A sensor's offline status is determined by checking the following indicators on its parent accessory, in order of priority:

1.  **Status Active**: If a characteristic of type `Status Active` exists for the accessory:
    *   `0` = **Offline**
    *   `1` = **Online**
    
2.  **Status Fault**: If `Status Active` is missing, but a `Status Fault` characteristic exists:
    *   Non-zero (and present) = **Offline** (Faulted)
    *   `0` = **Online**

## Fallback Logic (Inactivity)

The user explicitly stated: *"The fact that a sensor has not fired an event is not an indication that it's offline."*

To balance this with the need to identify truly dead devices that might not even be able to report their status, the system uses a very conservative **24-hour inactivity window** as a fallback *only if no explicit status characteristics are present*.

*   **Offline Fallback**: No `Status Active` or `Status Fault` AND `last_updated_at` is older than 24 hours.

## Implementation Details

*   **Model Method**: `Sensor#offline?` encapsulates this logic.
*   **Database Scope**: `Sensor.offline_by_status` allows for efficient querying of sensors explicitly reported as offline.
*   **UI Integration**: 
    *   **Sensors Dashboard**: Uses the `offline_by_status` scope for the "Offline" filter and alert banner.
    *   **Room Detail**: Aggregates the status of all sensors in a room to determine room-level connectivity.
    *   **Visual Badges**: The `StatusBadgeComponent` uses `sensor.offline?` to toggle between Online/Offline states.
