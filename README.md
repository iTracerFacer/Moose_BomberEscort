# MOOSE Bomber Escort System

A comprehensive, dynamic AI bomber mission system for DCS World using the MOOSE framework. This script allows players to create, launch, and escort AI bomber missions with advanced threat detection, SAM avoidance, and intelligent bomber/escort interaction—all controlled via F10 map markers and menus.

## Features

- **Player-Driven Bomber Missions:**
  - Create bomber missions by placing F10 map markers (no scripting required).
  - Supports multiple bomber types (WWII, Cold War, Modern, Soviet).
  - Customizable flight size, altitude, speed, and route.

- **Escort System:**
  - Bombers require player escort to proceed (configurable per bomber type).
  - Real-time escort detection (distance, heading, altitude, speed, and formation).
  - Dynamic in-game feedback and voice lines for escort actions.
  - Compliments for tight formation flying.

- **Threat Detection & Avoidance:**
  - Real-time detection of SAMs and enemy fighters.
  - Pre-mission route analysis for SAM threats; auto-reroutes through safe corridors if possible.
  - In-flight dynamic threat monitoring and mission abort if threats become critical.
  - Configurable threat tolerance and abort logic.

- **Mission Types & Targeting:**
  - Supports runway carpet bombing, point targets (buildings, bridges), and multi-target missions.
  - Auto-detects runways and attack headings.
  - Customizable ingress, egress, and RTB waypoints.

- **F10 Menu Integration:**
  - Launch, respawn, and monitor missions via F10 menu.
  - Player guide and mission status available in-game.

- **Logging & Debugging:**
  - Multi-level logging system (TRACE, DEBUG, INFO, WARN, ERROR).
  - Extensive debug output for mission makers.

## Supported Bomber Types

- **WWII:** B-17G, B-24J
- **Cold War:** B-52H, Tu-95MS
- **Modern:** B-1B, Tu-22M3

## Quick Start

1. **Add Bomber Templates:**
   - In the DCS Mission Editor, add late-activated groups for each bomber type you want to use.
   - Name them as follows:
     - `BOMBER_B17G`, `BOMBER_B24J`, `BOMBER_B52H`, `BOMBER_B1B`, `BOMBER_TU95`, `BOMBER_TU22`

2. **Place F10 Map Markers:**
   - **Spawn:** `BOMBER1:SPAWN:B-52H:2:FL250:400` (type, size, altitude, speed)
   - **Waypoints:** `BOMBER1:WP1`, `BOMBER1:WP2`, ...
   - **Targets:** `BOMBER1:TARGET1:RUNWAY:270` (type, heading)
   - **RTB:** `BOMBER1:RTB`

3. **Launch Mission:**
   - Use the F10 menu: `Bomber Missions > Launch Bomber Mission`

4. **Escort the Bomber:**
   - Stay within the required range and parameters to be recognized as an escort.
   - Respond to in-game feedback and warnings.

5. **Monitor & Control:**
   - Use F10 menu for mission status, respawn, and player guide.

## Advanced Marker Syntax

- `BOMBER1:SPAWN:B-17G:4:FL200:180` — WWII, 4-ship, 20,000ft, 180kts
- `BOMBER1:TARGET1:RUNWAY:090` — Runway attack from heading 090°
- `BOMBER1:TARGET1:BRIDGE` — Bridge attack
- `BOMBER1:RTB` — Custom RTB point
- `RESPAWN1` — Respawn last mission

See the in-game "Quick Start Guide" or `MARKER_GUIDE.md` for full details.

## Configuration

Edit the `BOMBER_ESCORT_CONFIG` table in the script to adjust:
- Logging level
- Escort requirements and detection thresholds
- Threat detection and SAM avoidance behavior
- Message durations and marker cleanup

## Requirements

- [MOOSE Framework](https://github.com/FlightControl-Master/MOOSE)
- DCS World (any map)
- Script must be loaded in the mission (via ME or Scripting Hooks)

## Installation

1. Place `Moose_BomberEscort.lua` and the MOOSE framework in your mission folder.
2. Load both scripts in your mission (MOOSE first, then Bomber Escort).
3. Add required bomber templates as late-activated groups.
4. Use F10 markers and menu as described above.

## Credits

- Script by F99th-TracerFacer
- Built on the MOOSE framework
- Special thanks to the DCS and MOOSE communities

## License

Copyright 2025 F99th-TracerFacer

This project is open source under the MIT License. See LICENSE for details.
