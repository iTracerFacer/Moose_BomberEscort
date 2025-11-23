# Bomber Escort - Marker System Guide

## Quick Reference

The bomber escort system uses **numbered waypoint markers** similar to the tanker system for consistency.

### Basic Mission (Minimum Required)

```
BOMBER1:B-52H:Nellis:2:FL250:350    ← Place on departure location
TARGET1                              ← Place on bombing target
```

Mission auto-executes when both markers detected!

---

## Marker Format

### BOMBER Waypoints

**Format:** `BOMBERn:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]`

**Required:**
- `BOMBERn` - Sequential number (BOMBER1, BOMBER2, etc.)

**Optional Parameters (only on BOMBER1):**
- `Type` - Aircraft type (B-52H, B-17G, B-1B, Tu-95, etc.)
- `Airbase` - Starting airbase name
- `Size` - Flight size (1-6 aircraft)
- `FLxxx` - Flight level in hundreds of feet (FL250 = 25,000 ft)
- `Speed` - Cruise speed in knots

**Examples:**
```
BOMBER1:B-52H:Nellis:4:FL350:450    (full parameters)
BOMBER1:B-17G:Batumi:2:FL180:200    (WWII bomber, low altitude)
BOMBER1:B-1B::6:FL500:600           (skip airbase, high altitude)
BOMBER1                              (all defaults)
```

**Defaults if omitted:**
- Type: B-52H
- Airbase: None (uses marker position)
- Size: 2 aircraft
- Altitude: FL250 (25,000 ft)
- Speed: 350 knots

### TARGET Markers

**Format:** `TARGETn [description]`

**Examples:**
```
TARGET1
TARGET1 Enemy SAM Site
TARGET1 Factory Complex
```

- Place on the exact bombing location
- Optional description for F10 menu display
- Currently only TARGET1 supported (single target per mission)

### Additional Waypoints

**Format:** `BOMBERn`

**Examples:**
```
BOMBER1:B-52H:Nellis:2:FL250:350    (departure with parameters)
BOMBER2                              (route waypoint 1)
BOMBER3                              (route waypoint 2)
TARGET1                              (bombing target)
```

- BOMBER2, BOMBER3, etc. are simple waypoints (no parameters needed)
- Used to create complex flight paths
- Automatically ordered by sequence number
- Maximum 10 waypoints supported

### RESPAWN Marker

**Format:** `RESPAWN1`

**Usage:**
```
RESPAWN1    (place anywhere to repeat last mission)
```

- Repeats the last completed/failed mission for your coalition
- Uses exact same parameters as original mission
- New bombers spawn at original departure location
- Marker auto-deletes after execution

---

## Coalition Separation

The system automatically tracks missions by **coalition** (RED vs BLUE):

- **Blue markers** create Blue missions
- **Red markers** create Red missions
- Each coalition can have independent missions running simultaneously
- RESPAWN1 respawns the last mission for **your coalition only**

---

## Complete Examples

### Example 1: Simple Strike Mission

```
BOMBER1:B-52H:Nellis:2:FL300:400
TARGET1 Enemy Airfield
```

**Result:**
- 2x B-52H bombers
- Depart from Nellis AFB
- Cruise at FL300 (30,000 ft) at 400 knots
- Attack Enemy Airfield
- Return to Nellis

### Example 2: Low-Level WWII Attack

```
BOMBER1:B-17G:Batumi:4:FL150:180
TARGET1 German Factory
```

**Result:**
- 4x B-17G Flying Fortress
- Depart from Batumi
- Cruise at FL150 (15,000 ft) at 180 knots
- Attack German Factory
- Return to Batumi

### Example 3: Complex Route with Waypoints

```
BOMBER1:B-1B:Nellis:2:FL450:600
BOMBER2       (avoids enemy SAM belt)
BOMBER3       (IP - Initial Point for attack run)
TARGET1 High Value Target
```

**Result:**
- 2x B-1B Lancer
- Depart Nellis
- Fly to BOMBER2 (avoidance waypoint)
- Proceed to BOMBER3 (IP)
- Attack from BOMBER3 → TARGET1
- Return to Nellis

### Example 4: Minimal Mission (All Defaults)

```
BOMBER1
TARGET1
```

**Result:**
- 2x B-52H (default type)
- Spawn at BOMBER1 marker location
- Cruise at FL250 at 350 knots (defaults)
- Attack TARGET1
- Return to nearest friendly airbase

### Example 5: Respawn Last Mission

After a mission completes (or fails):

```
RESPAWN1
```

**Result:**
- Exact copy of previous mission spawns
- Same aircraft type, size, route, target
- Useful for repeated strikes or training scenarios

---

## Marker Behavior

### Auto-Execution
- No separate EXECUTE marker needed
- Mission spawns automatically when BOMBER1 + TARGET1 detected
- Markers are scanned every 2 seconds

### Auto-Cleanup
- All mission markers automatically deleted after spawn
- Prevents clutter on F10 map
- Can be disabled by setting `deleteMarkersAfterUse = false` in code

### Validation
- Invalid bomber types show error message with available types
- Invalid flight sizes rejected (must be 1-6)
- Missing required markers (BOMBER1 or TARGET1) = no spawn

---

## Differences from Old System

**Old Command System:**
```
BOMBER START Nellis
BOMBER TARGET Factory
BOMBER TYPE B-52H
BOMBER SIZE 2
BOMBER ALT 35000
BOMBER SPEED 450
BOMBER EXECUTE
```

**New Numbered System:**
```
BOMBER1:B-52H:Nellis:2:FL350:450
TARGET1 Factory
```

**Benefits:**
- **Consistent** with tanker marker system
- **Fewer markers** needed (1-2 vs 7+)
- **Auto-execution** (no EXECUTE marker)
- **Inline parameters** (easier to read and modify)
- **Sequential ordering** (BOMBER1, BOMBER2, BOMBER3)

---

## Tips & Best Practices

1. **Start with BOMBER1** - Always use BOMBER1 for the departure point with parameters

2. **Keep it simple** - For basic missions, just use `BOMBER1:Type:Airbase` and TARGET1

3. **Test with defaults** - Place `BOMBER1` and `TARGET1` to quickly test without typing parameters

4. **Use waypoints sparingly** - Only add BOMBER2, BOMBER3 if you need complex routing

5. **Coalition markers** - Make sure markers are placed by correct coalition in multiplayer

6. **Check log file** - Watch `dcs.log` for detailed spawn information and errors

7. **RESPAWN for training** - Use RESPAWN1 to quickly repeat missions for practice

---

## Troubleshooting

**Mission doesn't spawn:**
- Check spelling: `BOMBER1` (not "BOMBAR1" or "BOMBER 1")
- Verify TARGET1 is present
- Check DCS log for error messages
- Ensure coalition is correct (RED/BLUE)

**Wrong aircraft type:**
- Check spelling matches exactly: `B-52H` not "B52" or "B-52"
- See available types: B-52H, B-1B, B-17G, B-24J, Tu-95MS, Tu-22M3

**Bombers spawn at wrong location:**
- BOMBER1 marker position = departure location if no airbase specified
- Use `BOMBER1:Type:AirbaseName` to override spawn location

**Parameters not working:**
- Ensure colon separators: `BOMBER1:B-52H:Nellis:2:FL250:350`
- Check order: Type:Airbase:Size:Altitude:Speed
- Use FL prefix for altitude: `FL350` not "35000"

---

## Summary

**Minimum Mission:**
```
BOMBER1:B-52H:Nellis
TARGET1
```

**Full Parameters:**
```
BOMBER1:B-1B:Nellis:4:FL500:600
BOMBER2
TARGET1 High Value Target
```

**Repeat Mission:**
```
RESPAWN1
```

The new numbered waypoint system provides consistency with the tanker script while reducing marker clutter and simplifying mission creation!
