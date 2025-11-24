# MOOSE Bomber Escort System

A comprehensive player-escort AI bomber mission system for DCS World using the MOOSE framework.

## Overview

This system allows players to dynamically create bomber missions using F10 map markers, then escort those AI bombers to their targets. The bombers exhibit intelligent behavior based on escort presence, threats, and mission status.

## Features Implemented

### ✅ Phase 1 - Core Framework (COMPLETE)

1. **BOMBER_PROFILE** - Aircraft characteristics database
   - Multiple bomber types (B-17G, B-24J, B-52H, Tu-95, Tu-22M3, B-1B)
   - Historical vs Modern profiles
   - Performance parameters (speed, altitude, maneuverability)
   - Behavioral traits (escort requirements, threat tolerance)

2. **BOMBER_MARKER** - Map marker command system
   - Parse player-placed F10 markers
   - Validate mission parameters
   - Consume markers on execution
   - Multi-mission support per coalition
   - **Respawn last mission** feature

3. **BOMBER_ESCORT_MONITOR** - Player escort detection
   - Continuous scanning for nearby player aircraft
   - Track escort count and presence duration
   - Configurable escort requirements per bomber type
   - Real-time escort status reporting

4. **BOMBER_THREAT_MANAGER** - Threat detection and tracking
   - SAM site detection (30km range)
   - Fighter threat detection (50km range)
   - AAA detection (5km range)
   - Bearing and distance calculation
   - Historical threat tracking

5. **BOMBER** - Main FSM class with intelligent behaviors
   - State machine: Spawned → Enroute → Attacking → Egressing → RTB → Landed
   - Adaptive behavior based on escort presence
   - Threat-aware decision making
   - Coalition messaging system
   - Event-driven responses

### ✅ Phase 2 - Advanced Features (COMPLETE)

6. **BOMBER_MISSION_MANAGER** - Multi-mission coordination
   - Manage multiple concurrent bomber missions
   - Track active and completed missions per coalition
   - Mission registration and lifecycle management

7. **BOMBER_MISSION** - Full mission management
   - **Route planning and flying** - Start → Waypoints → Target → Egress → RTB
   - **Bombing run automation** - Automated weapon delivery at target
   - **Waypoint navigation** - Proper flight path execution
   - **Airbase integration** - Takeoff and landing at designated bases

8. **F10 Player Menu System** - Interactive bomber control
   - **Request Status** - Escort count, threats, fuel, state
   - **Recommend Abort** - Suggest mission abort
   - **Warn: SAM Threat** - Alert bomber to SAMs
   - **Warn: Bandits** - Alert bomber to fighters
   - **Request Speed Increase/Decrease** - Adjust bomber speed
   - Coalition-specific menus per active mission

9. **BOMBER_FORMATION** - Formation management
   - **Automatic formation selection** based on bomber type
   - **WWII bombers**: Box formation (tight, defensive)
   - **Modern bombers**: Line Abreast (loose, spread out)
   - **Dynamic formation types**: Box, Trail, Echelon L/R, Vic, Line Abreast
   - Tight vs loose spacing options

10. **Mission Respawn System**
    - Store last mission data per coalition
    - **BOMBER RESPAWN** marker command
    - Instant mission replay after failure/completion
    - No need to replace all markers

## Map Marker Commands (Numbered Waypoint System)

The system uses **numbered waypoint markers** similar to the tanker system for consistency and simplicity.

### Required Markers

| Marker | Format | Example |
|--------|--------|---------|
| **BOMBER1** | `BOMBER1:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]` | `BOMBER1:B-52H:Nellis:2:FL250:350` |
| **TARGET1** | `TARGET1 [description]` | `TARGET1 Enemy SAM Site` |

### Optional Markers

| Marker | Description | Example |
|--------|-------------|---------|
| **BOMBER2, BOMBER3, etc.** | Additional waypoints for routing | `BOMBER2` |
| **RESPAWN1** | Respawn last coalition mission | `RESPAWN1` |

### Parameter Details

**BOMBER1 inline parameters** (all optional):
- **Type**: Aircraft type (B-52H, B-17G, B-1B, Tu-95MS, Tu-22M3, B-24J)
- **Airbase**: Starting airbase name (e.g., Nellis, Batumi)
- **Size**: Flight size 1-6 aircraft (default: 2)
- **FLxxx**: Flight level in hundreds of feet - FL250 = 25,000 ft (default: FL250)
- **Speed**: Cruise speed in knots (default: 350)

### Workflow Example

1. Place marker at Nellis AFB: `BOMBER1:B-17G:Nellis:4:FL180:200`
2. Place marker at target: `TARGET1 German Factory`
3. **Mission auto-spawns!** No EXECUTE marker needed
4. Markers automatically removed after spawn
5. Players escort the bombers to target
6. Bombers fly route, bomb target, and RTB
7. After mission ends, place marker: `RESPAWN1` to repeat instantly

### Advanced Example - Multiple Waypoints

```
BOMBER1:B-52H:Nellis:2:FL300:400    ← Departure + all parameters
BOMBER2                              ← Waypoint for routing
BOMBER3                              ← Another waypoint
TARGET1 High Value Target            ← Bombing target
```

Flight path: Nellis → BOMBER2 → BOMBER3 → TARGET1 → RTB to Nellis

## Bomber Behaviors

### Escort Awareness
- **Escorted**: Continues mission normally, flies route to target
- **Escort lost <30s**: Sends warning message, maintains course and speed
- **Escort lost 30-120s**: Slows down, sends urgent messages
- **Escort lost >120s**: Aborts mission and RTBs automatically
- **Escort returns during abort**: Resumes mission if time/fuel permits (within 5 min)

### Threat Response

**SAM Threats**:
- Detected within 30km range
- Deploys countermeasures when <20km
- Reports bearing and distance to coalition
- May abort if unescorted and inside SAM range

**Fighter Threats**:
- Detected within 50km range
- Relies on escorts for protection
- Tightens formation for mutual defense (WWII bombers)
- Aborts immediately if unescorted with close fighters

### Flight Behavior
- **Takeoff**: Departs from start airbase/position
- **Climb**: Ascends to cruise altitude over 10km
- **Route**: Follows player-defined waypoints
- **IP (Initial Point)**: 20km before target, begins attack run
- **Bombing**: Automated weapon release at target
- **Egress**: 30km past target, turns for home
- **RTB**: Returns to start airbase and lands

### Communication
Bombers broadcast messages to their coalition:
- "Enroute to target"
- "Escort contact, 2 fighters. Continuing mission"
- "Lost escort contact. Need immediate support!"
- "SAM threat! Bearing 270, 15 km!"
- "Bandits inbound, no escort! ABORTING!"
- "At target. Beginning bombing run!"
- "Bombs away! Egressing target area"
- "Escort rejoined. Resuming mission"
- "Threats clear. Continuing mission"
- "Returning to base"
- "Landed safely. Mission complete"

## Available Bomber Types

### WWII Heavy Bombers
- **B-17G Flying Fortress**: 180kts, 20k ft, tight formations, defensive guns
- **B-24 Liberator**: 175kts, 18k ft, tight formations, defensive guns

### Cold War Era
- **B-52H Stratofortress**: 400kts, 35k ft, loose formations, no guns
- **Tu-95 Bear**: 400kts, 30k ft, loose formations, tail gun
- **Tu-22M Backfire**: 450kts, 35k ft, loose formations, fast

### Modern
- **B-1B Lancer**: 500kts, 30k ft, high evasion, can operate without escort

## Installation

1. Ensure MOOSE is loaded in your mission
2. Add `Moose_BomberEscort.lua` to your mission scripts
3. Load order:
   ```lua
   -- Mission Start Trigger
   Moose.lua
   Moose_BomberEscort.lua
   ```

## Configuration

### Basic Setup
```lua
-- The system auto-initializes
-- To customize:
BOMBER_ESCORT_NO_AUTO_INIT = true -- Prevent auto-init
local system = BOMBER_ESCORT_INIT({
  -- Future options here
})
```

### Template Groups Required
You need template groups in your mission editor for each bomber type you want to use:
- Name them: `BOMBER_B17`, `BOMBER_B52`, `BOMBER_B24`, `BOMBER_TU95`, `BOMBER_TU22M3`, `BOMBER_B1B`
- Set to "Late Activation"
- Place at any location (will be moved on spawn)
- Can use 1 plane (will be cloned based on BOMBER SIZE marker)
- Configure loadout appropriately (bombs for ground targets)

## F10 Player Menu Commands

### Mission Status and Guide Menus

**Always Available**: F10 → Bomber Missions

| Command | Description |
|---------|-------------|
| 📋 Mission Status | View all active bomber missions for your coalition |
| 📖 Quick Start Guide | In-game help with marker formats and examples |

**Mission Status Shows**:
- Active mission callsigns
- Aircraft type and count (alive)
- Current target
- Mission state (Taking Off, En Route, Attacking, etc.)
- If no missions active, shows quick start instructions

**Quick Start Guide Shows**:
- Marker format examples
- Available aircraft types
- Route control (BOMBER2-n, EGRESS1-n, RTB1)
- Target types (RUNWAY, BUILDING, BRIDGE)
- Quick reference for creating missions

### Individual Bomber Commands

Once a mission is active, additional menus appear:

**Per-Mission Menu**: F10 → Bomber Missions → [Callsign]

| Command | Description |
|---------|-------------|
| Request Status | Shows bomber state, escorts, threats, fuel, target |
| Recommend Abort | Suggest bomber abort (they'll consider it) |
| Warn: SAM Threat | Alert bomber to SAM presence |
| Warn: Bandits | Alert bomber to enemy fighters |
| Request Speed Increase | Ask bomber to speed up (+20kts) |
| Request Speed Decrease | Ask bomber to slow down (-20kts) |

**Bomber Responses**:
- They acknowledge all commands
- Speed changes respect min/max limits
- Abort recommendations considered based on current threats
- Warnings trigger defensive measures

### MenuManager Integration

The system is compatible with **Moose_MenuManager.lua** for organized F10 menus:

**With MenuManager** (multi-script missions):
```
F10 → Mission Options → Bomber Missions → [Commands]
```

**Without MenuManager** (standalone):
```
F10 → Bomber Missions → [Commands]
```

Both modes work automatically - no configuration needed.

## Phase 2 Features (COMPLETE ✅)

All Phase 2 features are now implemented:

- ✅ **Mission Planning**: Full route calculation from start to target to RTB
- ✅ **Formation Management**: Historical formations (Box for WWII, Line Abreast for modern)
- ✅ **Bombing Run**: Automated IP → Target → Egress with weapon delivery
- ✅ **F10 Menu**: Player commands (status, abort, warnings, speed changes)
- ✅ **Multiple Active Missions**: Support concurrent bomber packages per coalition
- ✅ **Airbase Integration**: Proper takeoff and landing
- ✅ **Respawn System**: Retry missions with single marker command

## Future Enhancements (Phase 3 - Optional)

Potential future additions:

- [ ] **Damage Model**: Track aircraft damage, formation attrition, engine fires
- [ ] **Dynamic Routing**: Real-time route adjustment around discovered threats
- [ ] **Defensive Fire**: Gunner AI for WWII bombers
- [ ] **Countermeasures**: Automated chaff/flare deployment
- [ ] **SEAD Coordination**: Request SEAD support for SAM threats
- [ ] **Tanker Integration**: Air refueling for extended missions
- [ ] **Weather Effects**: Formation adjustments in clouds
- [ ] **Player Scoring**: Detailed leaderboards and statistics

## Technical Architecture

### Class Hierarchy
```
BOMBER_PROFILE (static database)
BOMBER_MARKER (singleton, monitors map markers)
BOMBER_MISSION (manages multiple concurrent missions)
  └── BOMBER (FSM, individual bomber group)
      ├── BOMBER_ESCORT_MONITOR (tracks player escorts)
      └── BOMBER_THREAT_MANAGER (detects threats)
```

### FSM States
```
SPAWNED → ENROUTE → ATTACKING → EGRESSING → RTB → LANDED
            ↓
         ABORTING → RTB
```

### Event Flow
1. Player places markers
2. BOMBER_MARKER validates and parses
3. BOMBER_MISSION created (TODO)
4. BOMBER spawned with FSM
5. BOMBER_ESCORT_MONITOR starts scanning
6. BOMBER_THREAT_MANAGER starts scanning
7. Bombers react to escorts/threats
8. Mission completes or aborts

## Design Decisions

### Multi-Coalition Support
- Separate marker systems per coalition
- Each coalition can have multiple active missions
- No cross-coalition interference

### Auto-Validation
- System auto-corrects reasonable mistakes
- Altitude clamped to bomber min/max
- Speed clamped to bomber capabilities
- Invalid bombers show helpful error messages

### Escort Credit
- Only players within escort range get proximity credit
- Future: Scoring system can be fully disabled
- Future: Mission completion rewards based on escort time

### Failed Missions
A "failed mission" means bombers were destroyed or aborted. Currently, players must place new markers to retry. Future: Option to respawn same mission.

### Threat Intelligence
- Bombers discover threats dynamically (no omniscience)
- Threats reported to coalition as discovered
- Historical threat tracking for mission analysis

## Troubleshooting

### Markers not working
- Ensure marker text is EXACT (case-insensitive but spelling matters)
- Check DCS log for validation errors
- Verify coalition placing markers matches coalition in game

### Bomber not spawning
- Template group must exist in mission editor
- Template must be "Late Activation"
- Check for name match: template "BOMBER_B52" for type "B-52H"

### Escort not detected
- Players must be within MaxEscortDistance (varies by bomber)
- Players must be same coalition as bomber
- Players must be in aircraft (not ground units)

## Credits

Built using the MOOSE framework by FlightControl and the MOOSE development team.

## License

MIT License - Free to use and modify
