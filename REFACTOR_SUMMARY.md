# Marker System Refactor - Change Summary

**Date:** November 23, 2025  
**Objective:** Align bomber escort marker system with tanker marker system for consistency

---

## Changes Made

### 1. Code Refactoring (Moose_BomberEscort.lua)

#### BOMBER_MARKER Class Changes

**Removed:**
- `Commands` table with command-based strings (BOMBER START, BOMBER TARGET, etc.)
- `PendingMissions` table (coalition-indexed pending missions)
- `_ProcessMarker()` - Old command processor
- `_ExtractParams()` - Old parameter extraction
- `_ValidateMission()` - Old validation logic
- `_CollectRouteWaypoints()` - Old waypoint collection
- `_CleanupMarkers()` - Manual marker cleanup

**Added:**
- `Config` table with numbered waypoint configuration:
  - `waypointPrefix = "BOMBER"`
  - `targetPrefix = "TARGET"`
  - `respawnPrefix = "RESPAWN"`
  - `deleteMarkersAfterUse = true`
  - `minWaypoints = 1`
  - `maxWaypoints = 10`
  - `checkInterval = 2`

- `_ParseWaypointMarker()` - Parse inline parameters from BOMBER1 marker
  - Format: `BOMBER1:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]`
  - Returns table with type, airbase, size, altitude, speed
  - Supports FL altitude format (FL250 = 25,000 ft)
  - All parameters optional with sensible defaults

- `_ScanForWaypointMarkers()` - Scan for numbered waypoint markers
  - Pattern matching: `^PREFIX(%d+)` extracts sequence number
  - Scans BOMBER1-n, TARGET1-n, RESPAWN1-n patterns
  - Returns sorted array by sequence number
  - Returns marker IDs for cleanup

- `_CheckMarkers()` - New auto-execution logic
  - Scans for BOMBER, TARGET, and RESPAWN markers
  - Groups by coalition automatically
  - Auto-executes when BOMBER1 + TARGET1 detected
  - No separate EXECUTE marker needed
  - Handles RESPAWN1 markers for mission repeat

- `_ExecuteMissionFromMarkers()` - New execution handler
  - Parses BOMBER1 for mission parameters
  - Validates bomber type against BOMBER_PROFILE database
  - Validates flight size (1-6 aircraft)
  - Collects BOMBER2, BOMBER3, etc. as route waypoints
  - Auto-cleanup markers after spawn (if configured)

**Modified:**
- `_RespawnLastMission()` - Removed `respawnMarker` parameter
  - Now called directly with just coalitionSide
  - Marker cleanup handled in `_CheckMarkers()`

### 2. Documentation Updates

#### Created New Files

**MARKER_GUIDE.md** - Comprehensive marker system guide
- Complete marker format reference
- Parameter explanations
- Coalition separation details
- Multiple examples (basic, WWII, complex routes, respawn)
- Tips & best practices
- Troubleshooting section
- Benefits comparison (old vs new system)

**MIGRATION_GUIDE.md** - Transition guide from old system
- Side-by-side command comparisons
- Migration examples for all scenarios
- Parameter mapping table
- Common mistakes and corrections
- Testing procedures
- Backwards compatibility note (old system NOT supported)

#### Updated Existing Files

**README.md**
- Updated "Map Marker Commands" section
- Changed to numbered waypoint system documentation
- Added BOMBER1 parameter format table
- Updated workflow example
- Added "Advanced Example - Multiple Waypoints"
- Removed old command references

**QUICK_REFERENCE.md**
- Replaced "Marker Commands" section
- Added numbered waypoint format breakdown
- Added visual parameter diagram
- Updated examples to use BOMBER1:[params] format
- Added defaults reference
- Removed old command syntax

**SETUP_GUIDE.md**
- Updated "Creating Your First Mission" section
- Changed step-by-step to use BOMBER1 + TARGET1
- Updated inline parameter instructions
- Removed EXECUTE step (auto-execution)
- Updated "Advanced Features" for numbered waypoints

---

## Marker System Comparison

### OLD System (Command-Based)

**Required 7+ markers:**
```
BOMBER START Nellis
BOMBER TARGET Factory
BOMBER TYPE B-52H
BOMBER SIZE 4
BOMBER ALT 35000
BOMBER SPEED 450
BOMBER EXECUTE
```

**Respawn:**
```
BOMBER RESPAWN
```

**Characteristics:**
- Separate marker for each parameter
- Manual EXECUTE trigger required
- Very explicit and verbose
- Easy to forget markers
- More clutter on F10 map

### NEW System (Numbered Waypoints)

**Required 1-2 markers:**
```
BOMBER1:B-52H:Nellis:4:FL350:450
TARGET1 Factory
```

**Respawn:**
```
RESPAWN1
```

**Characteristics:**
- All parameters inline in BOMBER1
- Auto-execution (no EXECUTE needed)
- Consistent with tanker system
- Fewer markers = less clutter
- Sequential ordering for waypoints

---

## Technical Details

### Parameter Parsing

**Format:** `BOMBER1:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]`

**Parsing Logic:**
1. Split marker text by `:` delimiter
2. Extract parts[2] = Type
3. Extract parts[3] = Airbase
4. Extract parts[4] = Size (convert to number)
5. Extract parts[5] = Altitude (parse FL format)
6. Extract parts[6] = Speed (convert to number)

**FL Altitude Parsing:**
- Input: `FL250`
- Pattern: `FL(%d+)`
- Extract: `250`
- Convert: `250 * 100 = 25,000 feet`

**Defaults:**
- Type: B-52H
- Airbase: nil (uses marker position)
- Size: 2
- Altitude: 25,000 ft (FL250)
- Speed: 350 knots

### Marker Scanning

**Pattern Matching:**
```lua
local sequence = string.match(upperText, "^" .. upperPrefix .. "(%d+)")
```

**Examples:**
- `BOMBER1` → prefix="BOMBER", sequence=1
- `BOMBER2` → prefix="BOMBER", sequence=2
- `TARGET1` → prefix="TARGET", sequence=1
- `RESPAWN1` → prefix="RESPAWN", sequence=1

**Sorting:**
```lua
table.sort(waypoints, function(a, b) return a.sequence < b.sequence end)
```

### Auto-Execution Logic

**Conditions:**
1. At least one BOMBER waypoint detected (BOMBER1 required)
2. At least one TARGET waypoint detected (TARGET1 required)
3. Both markers belong to same coalition

**Workflow:**
1. Scan for BOMBER markers → group by coalition
2. Scan for TARGET markers → group by coalition
3. For each coalition with both BOMBER + TARGET:
   - Parse BOMBER1 parameters
   - Validate bomber type and flight size
   - Collect additional waypoints (BOMBER2, BOMBER3, etc.)
   - Spawn bomber mission
   - Cleanup markers if configured

### Coalition Handling

**Automatic Coalition Detection:**
- Markers have `marker.coalition` property (RED or BLUE)
- System groups markers by coalition automatically
- Each coalition can have independent missions
- RESPAWN1 respawns last mission for marker's coalition

---

## Benefits

### 1. Consistency
✅ Matches tanker marker system pattern  
✅ Same numbered waypoint approach  
✅ Unified user experience across scripts

### 2. Efficiency
✅ 1-2 markers instead of 7+  
✅ Faster mission setup (no EXECUTE needed)  
✅ Less F10 map clutter  
✅ Auto-cleanup after spawn

### 3. Usability
✅ All parameters visible in one marker  
✅ Easy to modify (just edit BOMBER1)  
✅ Sequential waypoint ordering  
✅ Clear visual format

### 4. Maintainability
✅ Less code (removed 5 functions)  
✅ Cleaner validation logic  
✅ Better error messages  
✅ Consistent with existing patterns

---

## Testing Recommendations

### Basic Test
```
BOMBER1
TARGET1
```
**Expected:** 2x B-52H spawn at FL250, attack TARGET1, RTB

### Full Parameters Test
```
BOMBER1:B-17G:Batumi:4:FL180:200
TARGET1 German Factory
```
**Expected:** 4x B-17G spawn from Batumi, FL180 @ 200kts, attack factory, RTB

### Multi-Waypoint Test
```
BOMBER1:B-52H:Nellis:2:FL300:400
BOMBER2
BOMBER3
TARGET1 High Value Target
```
**Expected:** 2x B-52H, route Nellis → B2 → B3 → Target → Nellis

### Respawn Test
1. Complete/fail a mission
2. Place: `RESPAWN1`
**Expected:** Same mission repeats with identical parameters

### Coalition Test
1. Place Blue markers: `BOMBER1`, `TARGET1`
2. Place Red markers: `BOMBER1`, `TARGET1`
**Expected:** Both coalitions spawn independent missions

---

## Backwards Compatibility

⚠️ **BREAKING CHANGE** - Old marker system NOT supported

**Old markers will be ignored:**
- `BOMBER START` ❌
- `BOMBER TYPE` ❌
- `BOMBER TARGET` ❌
- `BOMBER EXECUTE` ❌
- `BOMBER RESPAWN` ❌

**Must use new markers:**
- `BOMBER1:[params]` ✅
- `TARGET1` ✅
- `RESPAWN1` ✅

Users must update their missions to use numbered waypoint system.

---

## Files Modified

### Code Files
- ✅ `Moose_BomberEscort.lua` - Complete BOMBER_MARKER refactor

### Documentation Files
- ✅ `README.md` - Updated marker commands section
- ✅ `QUICK_REFERENCE.md` - Updated marker format
- ✅ `SETUP_GUIDE.md` - Updated mission creation steps
- ✅ `MARKER_GUIDE.md` - **NEW** - Complete marker reference
- ✅ `MIGRATION_GUIDE.md` - **NEW** - Transition guide

### Unchanged Files
- `PHASE2_COMPLETE.md` - Phase 2 completion summary (historical)
- `Test_BomberEscort.lua` - Testing utilities (still compatible)
- All other core classes (BOMBER, BOMBER_MISSION, etc.)

---

## Summary

The bomber escort marker system has been successfully refactored to match the tanker system's numbered waypoint pattern. This provides consistency across scripts while reducing marker count and improving usability. The system now auto-executes missions when markers are detected, eliminating the need for a separate EXECUTE command.

**Key Achievement:** Unified marker interface across tanker and bomber systems for better user experience and consistency.
