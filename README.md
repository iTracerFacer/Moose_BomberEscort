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
  - Supports runway carpet bombing, area carpet bombing, point targets (buildings, bridges), and multi-target missions.
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

- `BOMBER1:SPAWN:B-1B:4:FL200:180` — WWII, 4-ship, 20,000ft, 180kts
- `BOMBER1:TARGET1:RUNWAY:090` — Runway attack from heading 090°
- `BOMBER1:TARGET1:CARPET:090` — Area carpet bombing from heading 090°
- `BOMBER1:TARGET1:FACTORY` — Factory attack
- `BOMBER1:TARGET1:FACTORY:CARPET` — Factory with carpet bombing
- `BOMBER1:TARGET1:FACTORY:CARPET:FL150` — Factory carpet at FL150
- `BOMBER1:TARGET1:FUELTANK:090` — Fuel tank attack from heading 090°
- `BOMBER1:TARGET1:BUNKER:CARPET:FL200` — Bunker carpet bombing at FL200
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

## Marker Tag Guide

This system uses F10 map markers to configure and control bomber missions. All markers follow a consistent naming pattern with colon-separated tags. The system is case-insensitive but marker names shown here use uppercase for clarity.

### Marker Naming Convention

All markers follow the pattern: `MISSION_ID:TAG_TYPE:PARAMETERS`

- **MISSION_ID**: A unique identifier for your mission (e.g., `BOMBER1`, `STRIKE2`, `RAID3`)
- **TAG_TYPE**: Defines the marker function (e.g., `SPAWN`, `WP`, `TARGET`, `RTB`)
- **PARAMETERS**: Vary by tag type, separated by colons

### Core Marker Types

#### 1. SPAWN Marker (Required)

Defines where and how the bomber mission spawns.

**Syntax:** `MISSION_ID:SPAWN:BOMBER_TYPE:FLIGHT_SIZE:ALTITUDE:SPEED`

**Parameters:**
- `BOMBER_TYPE`: Aircraft type (B-17G, B-24J, B-52H, B-1B, TU-95MS, TU-22M3)
- `FLIGHT_SIZE`: Number of aircraft (1-4)
- `ALTITUDE`: Flight altitude in feet or flight level
  - `25000` or `FL250` = 25,000 feet
  - `15000` or `FL150` = 15,000 feet
- `SPEED`: Cruise speed in knots (150-500)

**Examples:**
```
BOMBER1:SPAWN:B-52H:2:FL250:400
  └─ Mission "BOMBER1" spawns 2 B-52H bombers at 25,000ft cruising at 400kts

RAID5:SPAWN:B-17G:4:15000:180
  └─ Mission "RAID5" spawns 4 B-17G bombers at 15,000ft cruising at 180kts

STRIKE3:SPAWN:TU-22M3:2:FL200:450
  └─ Mission "STRIKE3" spawns 2 Tu-22M3 bombers at 20,000ft cruising at 450kts
```

**Valid Bomber Types:**
- **WWII:** `B-17G`, `B-24J`
- **Cold War:** `B-52H`, `TU-95MS`
- **Modern:** `B-1B`, `TU-22M3`

#### 2. Waypoint Markers (Optional)

Define the flight path from spawn to target. Waypoints are numbered sequentially.

**Syntax:** `MISSION_ID:WP#`

Where `#` is the waypoint number (1, 2, 3, etc.)

**Examples:**
```
BOMBER1:WP1
  └─ First waypoint for mission BOMBER1

BOMBER1:WP2
  └─ Second waypoint for mission BOMBER1

BOMBER1:WP3
  └─ Third waypoint for mission BOMBER1
```

**Usage Notes:**
- Waypoints must be numbered sequentially starting from 1
- The bomber will fly SPAWN → WP1 → WP2 → ... → TARGET
- If no waypoints are provided, bomber flies direct to target
- Use waypoints to avoid terrain, avoid SAMs, or follow realistic routes

#### 3. Target Markers (Required)

Define what and how the bomber attacks. Supports multiple targets per mission.

**Basic Syntax:** `MISSION_ID:TARGET#:TARGET_TYPE[:MODIFIER][:ALTITUDE]`

**Parameters:**
- `TARGET#`: Target number (TARGET1, TARGET2, etc.)
- `TARGET_TYPE`: What to attack (RUNWAY, FACTORY, BRIDGE, BUNKER, FUELTANK, COMMS, POWERPLANT, AMMO, BARRACKS, etc.)
- `MODIFIER`: Optional attack modifier (CARPET, heading in degrees)
- `ALTITUDE`: Optional bombing altitude override (FL150, FL200, etc.)

#### Target Type: RUNWAY

Attacks runways with automatic heading detection or manual specification.

**Syntax Options:**
```
MISSION_ID:TARGET1:RUNWAY
  └─ Auto-detects runway and optimal attack heading

MISSION_ID:TARGET1:RUNWAY:270
  └─ Attacks runway from heading 270° (west to east)

MISSION_ID:TARGET1:RUNWAY:090:FL180
  └─ Attacks runway from heading 090° at 18,000ft
```

**Examples:**
```
BOMBER1:TARGET1:RUNWAY
BOMBER2:TARGET1:RUNWAY:180
RAID3:TARGET1:RUNWAY:360:FL200
```

#### Target Type: CARPET (Area Bombing)

Performs carpet bombing over an area from a specified heading.

**Syntax:** `MISSION_ID:TARGET#:CARPET:HEADING[:ALTITUDE]`

**Examples:**
```
BOMBER1:TARGET1:CARPET:090
  └─ Carpet bombs area from heading 090° (east)

BOMBER1:TARGET1:CARPET:270:FL250
  └─ Carpet bombs area from heading 270° at 25,000ft
```

#### Target Type: Point Targets

Attacks specific structures like factories, bridges, bunkers, etc.

**Syntax:** `MISSION_ID:TARGET#:STRUCTURE_TYPE[:MODIFIER][:ALTITUDE]`

**Structure Types:**
- `FACTORY` - Industrial facilities
- `BRIDGE` - Bridges
- `BUNKER` - Hardened bunkers
- `FUELTANK` - Fuel storage
- `COMMS` - Communications facilities
- `POWERPLANT` - Power generation
- `AMMO` - Ammunition depots
- `BARRACKS` - Military barracks

**Examples:**
```
BOMBER1:TARGET1:FACTORY
  └─ Precision attack on factory

BOMBER1:TARGET1:BRIDGE:180
  └─ Attacks bridge from heading 180°

BOMBER1:TARGET1:BUNKER:CARPET
  └─ Carpet bombs bunker area

BOMBER1:TARGET1:FUELTANK:090:FL200
  └─ Attacks fuel tanks from heading 090° at 20,000ft

BOMBER1:TARGET1:FACTORY:CARPET:FL150
  └─ Carpet bombs factory area at 15,000ft
```

#### Multiple Targets

You can assign multiple targets to a single mission by incrementing the target number.

**Examples:**
```
BOMBER1:TARGET1:RUNWAY:270
BOMBER1:TARGET2:FACTORY
BOMBER1:TARGET3:FUELTANK
  └─ Mission BOMBER1 will attack all three targets in sequence
```

#### 4. RTB Marker (Optional)

Defines a custom return-to-base waypoint. If not specified, bombers return to spawn point.

**Syntax:** `MISSION_ID:RTB`

**Examples:**
```
BOMBER1:RTB
  └─ Custom RTB point for mission BOMBER1

STRIKE5:RTB
  └─ Custom RTB point for mission STRIKE5
```

#### 5. RESET Marker (Mission Control)

Immediately aborts and resets an active mission, cleaning up all resources.

**Syntax:** `MISSION_ID:RESET`

**Examples:**
```
BOMBER1:RESET
  └─ Aborts and resets mission BOMBER1

STRIKE5:RESET
  └─ Aborts and resets mission STRIKE5
```

**Usage:**
- Place a RESET marker to abort a running mission
- Cleans up the bomber group and all associated resources
- Mission ID becomes available for reuse
- Useful for canceling missions that are stuck or no longer needed

#### 6. RESPAWN Marker (Special)

Respawns the last completed mission at a new spawn location.

**Syntax:** `RESPAWN#`

**Examples:**
```
RESPAWN1
  └─ Respawns last mission with a new spawn location

RESPAWN2
  └─ Can use any number, system recognizes any RESPAWN marker
```

**Usage:**
1. Complete a bomber mission
2. Place a RESPAWN marker where you want the mission to start again
3. Launch via F10 menu
4. All original waypoints, targets, and parameters are preserved

### Complete Mission Examples

#### Example 1: Simple WWII Runway Attack
```
MISSION1:SPAWN:B-17G:4:15000:180
MISSION1:TARGET1:RUNWAY:270
MISSION1:RTB
```
Four B-17s spawn, fly direct to target runway, attack from west, return to RTB point.

#### Example 2: Modern Multi-Waypoint Strike
```
STRIKE2:SPAWN:B-1B:2:FL250:450
STRIKE2:WP1
STRIKE2:WP2
STRIKE2:WP3
STRIKE2:TARGET1:FACTORY:CARPET
STRIKE2:RTB
```
Two B-1Bs spawn, follow three waypoints avoiding threats, carpet bomb factory, return to base.

#### Example 3: Multi-Target Bombing Run
```
RAID3:SPAWN:B-52H:2:FL300:400
RAID3:WP1
RAID3:TARGET1:RUNWAY:180
RAID3:TARGET2:FUELTANK
RAID3:TARGET3:AMMO:CARPET:FL200
RAID3:RTB
```
Two B-52s spawn, follow waypoint, attack runway, then fuel depot, then carpet bomb ammo dump at lower altitude, return to base.

#### Example 4: Soviet Heavy Bomber Mission
```
BEAR1:SPAWN:TU-95MS:2:FL280:380
BEAR1:WP1
BEAR1:WP2
BEAR1:TARGET1:POWERPLANT
BEAR1:TARGET2:COMMS
BEAR1:RTB
```
Two Tu-95 Bears spawn, navigate via waypoints, strike power plant and communications, return to base.

#### Example 5: Low-Level WWII Attack
```
LOWLEVEL:SPAWN:B-24J:4:8000:200
LOWLEVEL:WP1
LOWLEVEL:WP2
LOWLEVEL:TARGET1:BRIDGE:090
LOWLEVEL:RTB
```
Four B-24s spawn at low altitude (8,000ft), follow terrain-masking waypoints, attack bridge, return to base.

### Altitude Specification

You can specify altitude in two formats:

**Flight Level (FL):**
- `FL250` = 25,000 feet
- `FL180` = 18,000 feet
- `FL050` = 5,000 feet

**Direct Feet:**
- `25000` = 25,000 feet
- `18000` = 18,000 feet
- `5000` = 5,000 feet

Both formats are interchangeable. Flight levels are standard aviation notation.

### Speed Guidelines

Recommended speeds by bomber type:

| Bomber Type | Min Speed | Max Speed | Typical Cruise |
|-------------|-----------|-----------|----------------|
| B-17G       | 150 kts   | 220 kts   | 180 kts       |
| B-24J       | 160 kts   | 240 kts   | 200 kts       |
| B-52H       | 300 kts   | 500 kts   | 400 kts       |
| B-1B        | 350 kts   | 500 kts   | 450 kts       |
| TU-95MS     | 300 kts   | 450 kts   | 380 kts       |
| TU-22M3     | 350 kts   | 500 kts   | 450 kts       |

### Best Practices

1. **Waypoint Spacing**: Space waypoints 20-50km apart for smooth flight paths
2. **Target Altitude**: Use altitude overrides on targets for terrain clearance or specific bombing profiles
3. **SAM Avoidance**: Plot waypoints to avoid known SAM threats; system will also auto-avoid when possible
4. **Runway Attacks**: Let system auto-detect heading or specify for precise attack axis
5. **Carpet Bombing**: Requires heading parameter; choose heading that maximizes coverage over target area
6. **Mission Naming**: Use descriptive mission IDs (STRIKE1, RAID2, ESCORT3) for clarity with multiple concurrent missions
7. **RTB Placement**: Place RTB markers at safe locations away from threats
8. **Escort Coordination**: For escort-required bombers (B-17G, B-24J), plan spawn locations where you can easily rendezvous

### Common Mistakes to Avoid

- ❌ Missing mission ID: `SPAWN:B-52H:2:FL250:400` (should be `BOMBER1:SPAWN:B-52H:2:FL250:400`)
- ❌ Wrong parameter order: `BOMBER1:SPAWN:2:B-52H:FL250:400` (bomber type must come before flight size)
- ❌ Non-sequential waypoints: `BOMBER1:WP1`, `BOMBER1:WP3` (missing WP2)
- ❌ Invalid bomber type: `BOMBER1:SPAWN:F-16:2:FL250:400` (F-16 is not a bomber)
- ❌ Missing target number: `BOMBER1:TARGET:RUNWAY` (should be `BOMBER1:TARGET1:RUNWAY`)
- ❌ Carpet without heading: `BOMBER1:TARGET1:CARPET` (should be `BOMBER1:TARGET1:CARPET:090`)

### Marker Management

- **Cleanup**: Markers are automatically cleaned up after mission launch (configurable)
- **Reuse**: You can reuse mission IDs after a mission completes
- **Updates**: To change a mission, delete all markers and recreate them before launch
- **Visibility**: Markers are visible to all coalition members

## Credits

- Script by F99th-TracerFacer
- Built on the MOOSE framework
- Special thanks to the DCS and MOOSE communities

## License

Copyright 2025 F99th-TracerFacer

This project is open source under the MIT License. See LICENSE for details.
