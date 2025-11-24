# Bomber Escort Marker System Guide

Complete reference for using F10 map markers to create bomber missions.

---

## Quick Start

**Minimum Required Markers:**
1. `BOMBER1:B-52H` - Spawns 1 B-52H from nearest airbase
2. `TARGET1` - Auto-detects attack type

**That's it!** Place these two markers and the mission starts automatically.

---

## BOMBER Markers

### Basic Format
```
BOMBER1:[Type]:[Size]:[Altitude]:[Speed]
```

### Parameters

| Parameter | Position | Required | Description | Example |
|-----------|----------|----------|-------------|---------|
| Type | 2 | Yes | Aircraft type | B-52H, B-17G, B-1B |
| Size | 3 | No | Flight size (1-6) | 4 |
| Altitude | 4 | No | Cruise altitude | FL250 |
| Speed | 5 | No | Cruise speed (knots) | 350 |

### Examples

**Simplest (all defaults):**
```
BOMBER1:B-52H
```
- Spawns: 1 B-52H (modern bomber default)
- From: Nearest airbase to marker
- Altitude: 25,000 ft
- Speed: 350 knots

**WWII Formation:**
```
BOMBER1:B-17G
```
- Spawns: 4 B-17Gs (WWII bomber default)
- From: Nearest airbase to marker
- Altitude: 20,000 ft (profile default)
- Speed: 180 knots (profile default)

**Custom Parameters:**
```
BOMBER1:B-52H:2:FL350:400
```
- Spawns: 2 B-52Hs
- Altitude: 35,000 ft
- Speed: 400 knots

**Multiple Flight Sizes:**
```
BOMBER1:B-17G:6:FL200:180
```
- Spawns: 6 B-17Gs (full box formation)

### Airbase Selection

**Automatic (Recommended):**
Place BOMBER1 marker ON or NEAR (within 5km) the airbase you want them to spawn from.

**No Airbase (Air Spawn):**
Requires configuration: `BOMBER_MARKER.Config.AllowAirSpawnFallback = true`

### Available Aircraft Types

| Type | Name | Default Size | Category | Notes |
|------|------|--------------|----------|-------|
| B-17G | Flying Fortress | 4 | WWII | Heavy bomber, defensive guns |
| B-24J | Liberator | 4 | WWII | Heavy bomber, defensive guns |
| B-52H | Stratofortress | 1 | Cold War | Strategic bomber |
| B-1B | Lancer | 1 | Modern | Fast bomber, high survivability |
| Tu-95 | Bear | 1 | Cold War | Soviet strategic bomber |
| Tu-22M3 | Backfire | 1 | Modern | Supersonic bomber |

**Template Names:** Aircraft must exist in mission editor as:
- `BOMBER_B52H` (Late Activation = TRUE)
- `BOMBER_B17G` (Late Activation = TRUE)
- etc.

---

## TARGET Markers

### Basic Format
```
TARGET1:[AttackType]:[Heading]
```

### Attack Types

| Type | Description | Bombs Dropped | Passes |
|------|-------------|---------------|--------|
| *(none)* | Auto-detect based on location | All or Half | 4 or 2 |
| RUNWAY | Runway carpet bombing | All | 1 |
| BRIDGE | Bridge attack | All or Half | 4 or 2 |
| BUILDING | Point target | All or Half | 4 or 2 |

### Examples

**Auto-Detect (Recommended):**
```
TARGET1
```
- If within 3km of airbase → Runway attack (auto-heading)
- If not near airbase → Point target attack (4 passes)

**Runway Attack (Auto Heading):**
```
TARGET1:RUNWAY
```
- Detects nearest airbase
- Calculates runway heading from airbase data
- Single devastating carpet bomb run

**Runway Attack (Manual Heading):**
```
TARGET1:RUNWAY:090
```
- Attacks FROM heading 090° (flying east to west)
- Bombers approach from 40km out on heading 090°
- Drop all bombs in single pass along runway
- Egress straight through

**Runway Attack Direction Examples:**
```
TARGET1:RUNWAY:000  → Attack from north (N→S)
TARGET1:RUNWAY:090  → Attack from east (E→W)
TARGET1:RUNWAY:180  → Attack from south (S→N)
TARGET1:RUNWAY:270  → Attack from west (W→E)
```

**Bridge/Building:**
```
TARGET1:BRIDGE
TARGET1:BUILDING
```
- Standard point target bombing
- Multiple passes to expend ordnance

### Multiple Targets

Place multiple TARGET markers for sequential attacks:
```
TARGET1:RUNWAY:270  → Attack runway first
TARGET2             → Then attack this point target
TARGET3             → Finally attack this target
```

**Bomb Distribution:**
- **1 Target:** All bombs, 4 passes (point) or 1 pass (runway)
- **Multiple Targets:** Bombs distributed, 2 passes per point target

---

## Route Waypoints (Optional)

### Format
```
BOMBER2
BOMBER3
BOMBER4
...
```

### Purpose
Control the flight path from spawn to first target.

### Examples

**Direct Flight:**
```
BOMBER1:B-52H  (Nellis AFB)
TARGET1        (Creech AFB - direct flight)
```

**Terrain Masking:**
```
BOMBER1:B-52H  (Start: Nellis)
BOMBER2        (Waypoint: Through mountain pass)
BOMBER3        (Waypoint: Along valley)
TARGET1        (Target: Creech)
```

**SAM Avoidance:**
```
BOMBER1:B-17G  (Start: England)
BOMBER2        (Avoid known SAM site #1)
BOMBER3        (Avoid known SAM site #2)
TARGET1        (Target: Germany)
```

### Notes
- All route waypoints set to cruise altitude automatically
- Waypoints numbered sequentially (BOMBER2, BOMBER3, etc.)
- Can place up to 10 route waypoints

---

## Egress Waypoints (Optional)

### Format
```
EGRESS1
EGRESS2
EGRESS3
...
```

### Purpose
Control the flight path after completing all bombing runs, before RTB.

### Examples

**Simple Egress:**
```
BOMBER1:B-52H  (Nellis AFB)
TARGET1        (Enemy airbase)
EGRESS1        (Safe waypoint away from threats)
RTB1           (Landing point)
```

**Complex Egress Route:**
```
BOMBER1:B-17G  (England)
TARGET1        (Germany)
EGRESS1        (Turn point away from target)
EGRESS2        (Avoid known SAM site)
EGRESS3        (Safe corridor)
RTB1           (Home base)
```

### Behavior
- If EGRESS markers present: Bombers follow custom egress route after last target
- If no EGRESS markers: System generates standard egress waypoint automatically
- All egress waypoints use cruise altitude

---

## RTB Marker (Optional)

### Format
```
RTB1
```

### Purpose
Define where bombers should return to base after completing mission.

### Examples

**Alternate Airbase:**
```
BOMBER1:B-52H     (Nellis - start here)
TARGET1           (Strike target)
RTB1              (Creech - land here instead)
```
- Place RTB1 on or near alternate airbase (within 5km)
- System creates landing waypoint automatically

**Bailout Point:**
```
BOMBER1:B-17G     (England)
TARGET1           (Deep in Germany)
EGRESS1           (Safe corridor)
RTB1              (Emergency field in France)
```
- Damaged bombers can land at closer field
- Reduces flight time after combat

**Rally Point (No Landing):**
```
RTB1  (Place in open airspace, >5km from any airbase)
```
- If RTB1 not near airbase, bombers fly there but don't land
- Useful for CAP handoff or formation rejoin

### Behavior
- If RTB1 within 5km of airbase: Creates landing waypoint
- If RTB1 not near airbase: Creates regular waypoint (no landing)
- If no RTB1: Returns to start airbase automatically

---

## RESPAWN Marker

### Format
```
RESPAWN1
```

### Purpose
Respawns the last bomber mission for the same coalition.

### Usage
1. Complete or fail a mission
2. Place `RESPAWN1` marker anywhere
3. Mission repeats with same parameters
4. Useful for:
   - Testing
   - Repeated attacks on same target
   - Quick mission restart after failure

---

## Complete Mission Examples

### Example 1: Simple Strike
**Objective:** Single B-52H attacks enemy airbase

```
BOMBER1:B-52H          (Place on Nellis AFB)
TARGET1:RUNWAY:270     (Place on Creech runway, attack from west)
```

**Result:**
- 1 B-52H spawns from Nellis
- Flies direct to Creech AFB
- Attacks runway from west in single carpet bomb run
- Returns to Nellis

---

### Example 2: WWII Heavy Bomber Raid
**Objective:** B-17 formation attacks industrial target

```
BOMBER1:B-17G:6:FL200:180  (Place on friendly airbase)
BOMBER2                     (Waypoint: Safe route)
BOMBER3                     (Waypoint: Rally point)
TARGET1:BUILDING            (Enemy factory)
```

**Result:**
- 6 B-17Gs spawn in formation
- Fly waypoint route at 20,000 ft
- Attack factory with multiple passes
- Return to base

---

### Example 3: Multi-Target Strike
**Objective:** Attack multiple targets in sequence

```
BOMBER1:B-1B:2:FL300:500   (Place on airbase)
TARGET1:RUNWAY:000         (Enemy airbase runway)
TARGET2:BUILDING           (Nearby ammo depot)
TARGET3:BRIDGE             (Supply bridge)
```

**Result:**
- 2 B-1Bs spawn
- Attack runway from north (carpet bomb)
- Attack ammo depot (2 passes)
- Attack bridge (2 passes)
- Return to base

---

### Example 4: Complex Egress Route
**Objective:** B-1B strike with custom egress to alternate base

```
BOMBER1:B-1B:2:FL300:500   (Nellis AFB)
BOMBER2                     (Ingress waypoint)
TARGET1:RUNWAY:090          (Enemy airbase)
EGRESS1                     (Safe turn point)
EGRESS2                     (Avoid SAM site)
RTB1                        (Creech AFB - alternate landing)
```

**Result:**
- 2 B-1Bs spawn from Nellis
- Fly ingress route to target
- Attack runway from east
- Follow custom egress route (EGRESS1→2)
- Land at Creech instead of returning to Nellis

---

### Example 5: WWII Deep Strike
**Objective:** B-17 raid with emergency landing field

```
BOMBER1:B-17G:6:FL200:180  (England)
BOMBER2                     (Channel crossing)
BOMBER3                     (Enemy coast)
TARGET1:BUILDING            (Factory in Germany)
EGRESS1                     (Immediate turn)
EGRESS2                     (Safe corridor)
EGRESS3                     (Friendly territory)
RTB1                        (Emergency field in France)
```

**Result:**
- 6 B-17Gs spawn from England
- Deep penetration into Germany
- Attack factory
- Emergency egress through safe corridor
- Land at closer French airfield

---

### Example 6: Low-Level Attack
**Objective:** B-1B terrain-following strike

```
BOMBER1:B-1B:FL100:600     (Low altitude, high speed)
BOMBER2                     (Valley entrance)
BOMBER3                     (Through mountains)
TARGET1:BRIDGE              (Enemy bridge)
```

**Result:**
- 1 B-1B spawns
- Flies low-level route (1,000 ft)
- High speed (600 knots)
- Attacks bridge
- Returns

---

## Mission Flow with Egress Control

### Complete Flight Path Control

The marker system now gives you complete control over the entire bomber flight path:

1. **BOMBER1** → Spawn parameters and start location
2. **BOMBER2-n** → Ingress route to target area
3. **TARGET1-n** → Attack targets in sequence
4. **EGRESS1-n** → Egress route from target area
5. **RTB1** → Final destination (landing or rally point)

**Example Mission Flow:**
```
BOMBER1:B-52H → Spawn from Nellis
    ↓
BOMBER2 → Ingress waypoint #1
    ↓
BOMBER3 → Ingress waypoint #2 (near target area)
    ↓
TARGET1:RUNWAY:270 → Attack enemy runway
    ↓
TARGET2:BUILDING → Attack ammo depot
    ↓
EGRESS1 → Safe turn point away from target
    ↓
EGRESS2 → Avoid known SAM threat
    ↓
EGRESS3 → Safe corridor back to friendly territory
    ↓
RTB1 → Land at Creech AFB (alternate base)
```

### Fallback Behavior

**If no EGRESS markers:**
- System generates standard egress waypoint automatically
- For point targets: 30km north of target
- For runway targets: 25km continuing along attack heading

**If no RTB marker:**
- Bombers return to starting airbase (from BOMBER1)
- Creates landing waypoint automatically

This allows you to use egress control only when needed, while maintaining backward compatibility with existing missions.

---

## Configuration Options

### Enable Air Spawn Fallback
```lua
BOMBER_MARKER.Config.AllowAirSpawnFallback = true
```
Allows bombers to spawn in air if marker not near airbase.

### Disable Auto-Cleanup
```lua
BOMBER_MARKER.Config.deleteMarkersAfterUse = false
```
Keeps markers on map after mission starts.

### Change Check Interval
```lua
BOMBER_MARKER.Config.checkInterval = 5
```
Changes how often system scans for new markers (seconds).

---

## Mission Maker Tips

### Runway Attacks - Best Practices

**Place marker on runway:**
```
TARGET1:RUNWAY:270
```
- System detects runway automatically
- Use heading to control attack direction
- Choose heading that:
  - Minimizes turn from route
  - Maximizes egress safety
  - Avoids overflying defenses

**Attack Direction Selection:**
1. Check wind (bombers perform better into wind)
2. Check threats (egress away from SAMs)
3. Check terrain (approach over clear terrain)
4. Consider sun angle (IRL consideration)

### Multiple Targets

**Sequential vs Distributed:**
- **1 target:** All bombs, maximize destruction
- **2-3 targets:** Half bombs each, spread damage
- **4+ targets:** Consider multiple missions

**Target Ordering:**
- Most dangerous first (SAM sites)
- Time-critical targets second
- Opportunity targets last

### Route Planning

**When to use waypoints:**
- ✓ SAM threat areas
- ✓ Mountainous terrain
- ✓ Coordinated timing with other flights
- ✓ Realistic approach corridors
- ✗ Simple direct flights (unnecessary)

**Waypoint Spacing:**
- Long legs: 50-100km between waypoints
- Terrain following: 10-20km between waypoints
- Combat area: Dense waypoints for precision

---

## Troubleshooting

### "BOMBER TEMPLATE MISSING"
**Problem:** Template doesn't exist in mission editor
**Solution:** 
1. Open mission editor
2. Place bomber group (e.g., B-52H)
3. Name it exactly: `BOMBER_B52H`
4. Set Late Activation = TRUE
5. Set loadout (bombs)
6. Save and restart mission

### "BOMBER1 marker not on airbase"
**Problem:** Marker too far from airbase
**Solution:**
- Move BOMBER1 marker closer to airbase (within 5km)
- Or enable air spawn: `BOMBER_MARKER.Config.AllowAirSpawnFallback = true`

### "INVALID BOMBER TYPE"
**Problem:** Bomber type not recognized
**Solution:** Use exact type names:
- ✓ B-52H, B-17G, B-1B, Tu-95, Tu-22M3, B-24J
- ✗ B-52, B17, B1B (incorrect format)

### Bombers not attacking runway properly
**Problem:** DCS AI override or incorrect heading
**Solution:**
- Use explicit heading: `TARGET1:RUNWAY:270`
- Check logs for detected heading
- Verify runway direction in mission editor
- Ensure marker actually on runway (within 3km of airbase)

### Multiple passes on runway (not carpet bombing)
**Problem:** System not detecting as runway
**Solution:**
- Check distance to airbase (must be < 3km)
- Use explicit: `TARGET1:RUNWAY`
- Check logs: "TARGET IS RUNWAY" should appear
- If not detected, manually specify heading

---

## Advanced: F10 Menu Integration

Once mission is active, players get F10 menus:

**F10 → Bomber Missions → [Callsign]:**
- Request Status
- Request RTB
- Request Abort

Use these for dynamic mission control during flight.

---

## Summary: Quick Reference

| Marker | Required | Purpose | Example |
|--------|----------|---------|---------|
| BOMBER1 | Yes | Spawn point & params | BOMBER1:B-52H:2:FL300:400 |
| BOMBER2-n | No | Ingress waypoints | BOMBER2 |
| TARGET1 | Yes | First target | TARGET1:RUNWAY:270 |
| TARGET2-n | No | Additional targets | TARGET2:BUILDING |
| EGRESS1-n | No | Egress waypoints | EGRESS1 |
| RTB1 | No | Return to base point | RTB1 |
| RESPAWN1 | No | Repeat mission | RESPAWN1 |

**Minimum viable mission:**
```
BOMBER1:B-52H
TARGET1
```

**Full-featured mission:**
```
BOMBER1:B-17G:6:FL200:180
BOMBER2
BOMBER3
TARGET1:RUNWAY:090
TARGET2:BUILDING
TARGET3:BRIDGE
EGRESS1
EGRESS2
RTB1
```

