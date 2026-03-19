# Sensor Value Treatment Rules

This document defines how raw sensor values from HomeKit are processed, stored, and displayed in the Eureka dashboard.

## Overview
Sensor data is stored in the `sensor_value_definitions` table with three key fields:
- **Value**: The raw data from HomeKit (string).
- **Label**: The human-readable portion of the value (e.g., "72.5", "Motion").
- **Units**: The contextual unit or state category (e.g., "°F", "%RH", "Activity").

## Treatment Matrix

### 1. Measurement Units (Physical)
Used for continuous numerical values.

| Sensor Type | Raw Value | Label | Units | UI Display |
| :--- | :--- | :--- | :--- | :--- |
| **Temperature** | `22.5` | `72.5` | `°F` | **72.5°F** |
| **Humidity** | `45.2` | `45` | `%RH` | **45%RH** |
| **Light Level** | `150` | `150` | `lux` | **150 lux** |
| **Power** | `1250` | `1250` | `W` | **1250 W** |
| **Voltage** | `120` | `120` | `V` | **120 V** |

### 2. Percentage-Based Scales (Contextual)
Used to resolve ambiguity of the `%` symbol.

| Sensor Type | Raw Value | Label | Units | UI Display |
| :--- | :--- | :--- | :--- | :--- |
| **Brightness** | `80` | `80` | `%` | **80%** |
| **Fan Speed** | `50` | `50` | `%` | **50%** |
| **Battery** | `15` | `15` | `%` | **15%** |
| **Position** | `0` | `Closed` | `%` | **Closed** |

### 3. State Descriptors (Binary/Discrete)
Used for status-based sensors.

| Sensor Type | Raw Value | Label | Units | UI Display |
| :--- | :--- | :--- | :--- | :--- |
| **Power State** | `true` | `ON` | `Status` | **ON** |
| **Power State** | `false` | `OFF` | `Status` | **OFF** |
| **Motion** | `1` | `Motion` | `Activity` | **Motion** |
| **Motion** | `0` | `Clear` | `Activity` | **Clear** |
| **Lock State** | `1` | `Locked` | `Security` | **Locked** |
| **Contact** | `0` | `Closed` | `Contact` | **Closed** |

## Display Logic
The `Sensor#formatted_value` method follows these priority rules:
1. **Label-only**: If `label` is non-numeric (e.g., "Motion", "Locked"), display ONLY the `label`.
2. **Category Units**: If `units` is a category name (e.g., "Status", "Activity", "Security"), display ONLY the `label`.
3. **Symbolic Units**: If `units` is a symbol (e.g., "°F", "%", "W"), append it to the `label`.
4. **Fallback**: Use the hardcoded unit logic based on `characteristic_type` if no specific definition exists.
