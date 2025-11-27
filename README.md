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

## Logic Flow

The system uses a finite state machine (FSM) to manage bomber behavior, with different logic paths for escort-required vs. non-escort bomber types. All bombers follow intelligent threat detection and SAM avoidance, but escort requirements fundamentally change mission flow.

Bomber escort configuration is handled on a per airframe basis or can be disabled globaly. 

### Escort Bombers:
**Ground Phase:**
- **Spawned**: Bomber spawns on ramp, cold, dark, no pilots, waits for player escort confirmation
- **Holding**: Monitors for escorts within 5km. If no escorts detected after grace period, broadcasts "need escort" messages every 60 seconds (up to 5 times before aborting)
- **Engine Starting**: Once escorts confirmed (taxi within 1km), starts cold engine sequence (several min depending on airframe)
- **Taxiing**: Moves to runway, monitors for blockages. If blocked for too long, mission is scrubbed.
- **Taking Off**: Takeoff roll with relaxed escort detection (up to 40km range during departure)

**Airborne Phase:**
- **Forming Up**: Continues broadcasting escort requests if needed
- **Climbing**: Climbs to cruise altitude with escorts. Escort detection remains relaxed during this phase
- **Cruise**: En route to target. Escort detection switches to distance-only mode (within 20km) for tactical freedom
- **Pre-Attack**: Approaches target area, prepares for bombing run - escorts released - commited to attack, will not abort for lack of escorts.
- **Attacking**: Executes bombing run on runway/bridge/building targets
- **Egressing**: Leaves target area, heads toward RTB point

**Return to Base (RTB):**
- **RTB**: Returns to designated RTB waypoint. Escort monitor remains active - escorts appreciated until landing
- **Landed**: Mission complete. Thanks escorts and cleans up resources

**Escort Impact on RTB:**
- If mission aborted due to lost escorts, bomber enters RTB state but will not land until escorts rejoin within 500m (buggy)
- During RTB, broadcasts "escort appreciated until landing" and monitors for close escorts
- If escorts detected within 500m during RTB, mission can resume if previously aborted (buggy)
- Without escorts, bomber will RTB and land independently.

### Non-Escort Bombers:
**Simplified Flow:**
- **Spawned** → **Engine Starting** (immediate cold start, no escort wait)
- **Taxiing** → **Taking Off** → **Climbing** → **Cruise** → **Pre-Attack** → **Attacking** → **Egressing** → **RTB** → **Landed**

These modern bombers operate independently but still recognize and acknowledge player escorts for formation flying compliments and enhanced protection. this again is configurable per airframe.

### Threat Detection & SAM Avoidance

**SAM Detection:**
- Continuous scanning within 100km for SAM sites and fighter threats
- Pre-mission route analysis checks 150km ahead for SAM threats
- Only considers SAMs that can engage at current altitude (altitude filtering)

**Route Planning:**
- If SAM threats detected on direct route, system finds safe corridors
- Can detour up to 150% of direct distance (300km max absolute)
- Requires minimum 15km corridor width and 20% fuel reserve
- Auto-reroutes through safe paths if available

**In-Flight Monitoring:**
- Progressive warnings at 100km, 80km, 60km, 40km, 20km from SAMs
- Status summaries every 80 seconds
- Auto-deploys countermeasures within 30km
- Dynamic threat assessment: requires 1 escort per detected fighter
- Mission abort if outnumbered (configurable tolerance, default: abort on any fighter without escort)

**SAM Route Avoidance:**
- Checks route every 10 seconds during flight
- Aborts mission if new threats make current path unsafe
- Corridor finding uses smaller 10km buffer for pre-planning vs 25km for in-flight decisions
- Fuel viability checked before accepting detour routes

### Escort Detection Logic

**Classification System:**
- **Confirmed**: Close range (<5km) with matching flight parameters (heading ±45°, altitude ±5000ft, speed ±100kts)
- **Probable**: Medium range (5-10km) or relaxed parameters during takeoff/climb
- **Passing**: Within max range (20km) but not actively escorting

**Phase-Based Detection:**
- **Takeoff/Climb**: Relaxed tolerances (up to 40km range, 180° heading) for formation assembly
- **Cruise+**: Distance-only mode for tactical freedom (20km max range)

**Escort Requirements:**
- Minimum 2 confirmed escorts required for escort-dependent bombers
- Warnings after 120 seconds unescorted, abort after 300 seconds (5 warnings × 60s)
- Formation flying compliments every 3 minutes for escorts within 250m


## Credits

- Script by F99th-TracerFacer
- Built on the MOOSE framework
- Special thanks to the DCS and MOOSE communities

## License

Copyright 2025 F99th-TracerFacer

This project is open source under the MIT License. See LICENSE for details.
