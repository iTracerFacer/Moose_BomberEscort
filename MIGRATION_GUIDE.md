# Migration Guide - Old vs New Marker System

## Overview

The bomber escort system has been updated to use a **numbered waypoint pattern** matching the tanker system for consistency. This guide helps you understand the differences and migrate existing missions.

---

## Key Changes

### 1. Numbered Waypoints (Like Tanker System)

**OLD:**
```
BOMBER START Nellis
BOMBER TARGET Factory
BOMBER EXECUTE
```

**NEW:**
```
BOMBER1:B-52H:Nellis
TARGET1 Factory
```

### 2. Inline Parameters

**OLD:** Separate markers for each parameter
```
BOMBER START Nellis
BOMBER TYPE B-52H
BOMBER SIZE 4
BOMBER ALT 35000
BOMBER SPEED 450
BOMBER TARGET Factory
BOMBER EXECUTE
```

**NEW:** All parameters in BOMBER1
```
BOMBER1:B-52H:Nellis:4:FL350:450
TARGET1 Factory
```

### 3. Auto-Execution

**OLD:** Required BOMBER EXECUTE marker

**NEW:** Auto-executes when BOMBER1 + TARGET1 detected

### 4. Respawn Command

**OLD:** `BOMBER RESPAWN`

**NEW:** `RESPAWN1`

---

## Migration Examples

### Basic Mission

**OLD System:**
```
BOMBER START Nellis
BOMBER TARGET SAM Site
BOMBER TYPE B-1B
BOMBER EXECUTE
```

**NEW System:**
```
BOMBER1:B-1B:Nellis
TARGET1 SAM Site
```

### With Custom Altitude/Speed

**OLD System:**
```
BOMBER START Batumi
BOMBER TARGET Bridge
BOMBER TYPE B-17G
BOMBER SIZE 6
BOMBER ALT 18000
BOMBER SPEED 200
BOMBER EXECUTE
```

**NEW System:**
```
BOMBER1:B-17G:Batumi:6:FL180:200
TARGET1 Bridge
```

### With Waypoints

**OLD System:**
```
BOMBER START Nellis
BOMBER ROUTE 1    (at waypoint location)
BOMBER ROUTE 2    (at waypoint location)
BOMBER TARGET Airfield
BOMBER EXECUTE
```

**NEW System:**
```
BOMBER1:B-52H:Nellis
BOMBER2           (at waypoint location)
BOMBER3           (at waypoint location)
TARGET1 Airfield
```

### Respawn Mission

**OLD System:**
```
BOMBER RESPAWN
```

**NEW System:**
```
RESPAWN1
```

---

## Benefits of New System

### 1. Consistency
- Matches tanker marker system pattern
- Easier to remember (same pattern for both systems)
- Unified user experience across scripts

### 2. Fewer Markers
- 1-2 markers instead of 7+ markers
- Less clutter on F10 map
- Faster mission setup

### 3. Clearer Structure
- Sequential ordering (BOMBER1, BOMBER2, BOMBER3)
- All parameters visible in one marker
- Easy to modify parameters (just edit BOMBER1)

### 4. Auto-Execution
- No separate EXECUTE marker needed
- Mission spawns as soon as markers detected
- Faster workflow

### 5. Better Validation
- Immediate feedback on invalid parameters
- Shows available bomber types on error
- Coalition-specific error messages

---

## Parameter Mapping

| Old System | New System | Notes |
|------------|------------|-------|
| `BOMBER START [airbase]` | `BOMBER1:..:[airbase]:..` | Second parameter in BOMBER1 |
| `BOMBER TYPE [type]` | `BOMBER1:[type]:..` | First parameter in BOMBER1 |
| `BOMBER SIZE [n]` | `BOMBER1:..:..:[n]:..` | Third parameter in BOMBER1 |
| `BOMBER ALT [feet]` | `BOMBER1:..:..:..FL[xxx]:..` | Fourth parameter (FL format) |
| `BOMBER SPEED [kts]` | `BOMBER1:..:..:..:..:[kts]` | Fifth parameter in BOMBER1 |
| `BOMBER TARGET [name]` | `TARGET1 [name]` | Separate TARGET1 marker |
| `BOMBER ROUTE [n]` | `BOMBERn` | Sequential numbers |
| `BOMBER EXECUTE` | *(auto)* | No longer needed |
| `BOMBER RESPAWN` | `RESPAWN1` | Numbered pattern |

---

## Format Reference

### BOMBER1 Parameter Order

```
BOMBER1:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]
        │  1   │    2     │  3   │   4   │   5
```

1. **Type** - Aircraft type (B-52H, B-17G, etc.)
2. **Airbase** - Starting airbase name
3. **Size** - Flight size (1-6)
4. **Altitude** - Flight level (FL250 = 25,000 ft)
5. **Speed** - Cruise speed in knots

**All parameters are optional!** Use defaults by omitting:
```
BOMBER1                              ← All defaults
BOMBER1:B-17G                        ← Just type
BOMBER1:B-17G:Batumi                 ← Type + airbase
BOMBER1:B-17G:Batumi:4               ← Type + airbase + size
BOMBER1:B-17G:Batumi:4:FL150         ← Type + airbase + size + alt
BOMBER1:B-17G:Batumi:4:FL150:180     ← All parameters
```

---

## Common Mistakes

### ❌ Wrong Marker Names

```
BOMBER 1:B-52H:Nellis     ← Space between BOMBER and 1
BOMBAR1:B-52H:Nellis      ← Typo: BOMBAR instead of BOMBER
bomber1:B-52H:Nellis      ← Lowercase (should work but uppercase recommended)
```

✅ **Correct:**
```
BOMBER1:B-52H:Nellis
```

### ❌ Wrong Altitude Format

```
BOMBER1:B-52H:Nellis:2:25000:350     ← Raw number instead of FL format
```

✅ **Correct:**
```
BOMBER1:B-52H:Nellis:2:FL250:350     ← FL prefix
```

### ❌ Missing Colon Separators

```
BOMBER1 B-52H Nellis 2 FL250 350     ← Spaces instead of colons
```

✅ **Correct:**
```
BOMBER1:B-52H:Nellis:2:FL250:350     ← Colons separate parameters
```

### ❌ Wrong Waypoint Numbers

```
BOMBER1:B-52H:Nellis
BOMBER5                              ← Gap in sequence
TARGET1
```

✅ **Correct:**
```
BOMBER1:B-52H:Nellis
BOMBER2                              ← Sequential numbering
BOMBER3
TARGET1
```

---

## Testing the New System

### Quick Test

1. **Place markers:**
   ```
   BOMBER1
   TARGET1
   ```

2. **Wait 2-5 seconds** - Mission should auto-spawn

3. **Check for message:**
   ```
   BOMBER CONTROL: BOMBER MISSION ACTIVE
   Callsign: Thunder 3-1
   Type: B-52H x2
   ...
   ```

4. **Markers disappear** - System consumed them

### Full Parameter Test

1. **Place markers:**
   ```
   BOMBER1:B-17G:Batumi:4:FL180:200
   TARGET1 Test Target
   ```

2. **Watch for:**
   - 4x B-17G bombers spawn
   - Depart from Batumi
   - Fly at FL180 (18,000 ft)
   - Cruise at 200 knots

### Respawn Test

1. **Wait for first mission to complete/fail**

2. **Place marker:**
   ```
   RESPAWN1
   ```

3. **Watch for:**
   - Same mission spawns immediately
   - Same parameters as original

---

## Backwards Compatibility

**The old system is NOT supported anymore.** Old marker commands will not work:
- ❌ `BOMBER START`
- ❌ `BOMBER TYPE`
- ❌ `BOMBER EXECUTE`
- ❌ `BOMBER RESPAWN`

**You must use the new numbered system:**
- ✅ `BOMBER1`
- ✅ `BOMBER2`, `BOMBER3`, etc.
- ✅ `TARGET1`
- ✅ `RESPAWN1`

---

## Need Help?

**Check logs:**
- Open `C:\Users\[YourName]\Saved Games\DCS\Logs\dcs.log`
- Search for `[BOMBER]` entries
- Look for error messages

**Common issues:**
- Spelling mistakes in marker text
- Missing TARGET1 marker
- Invalid bomber type name
- Wrong coalition markers (RED vs BLUE)

**Documentation:**
- `MARKER_GUIDE.md` - Complete marker reference
- `QUICK_REFERENCE.md` - Cheat sheet
- `README.md` - Full system overview

---

## Summary

**Old System = Many markers, separate EXECUTE**

**New System = 1-2 markers, auto-execute, inline parameters**

The new numbered waypoint system is:
- ✅ Consistent with tanker system
- ✅ Faster to use
- ✅ Fewer markers needed
- ✅ Auto-executing
- ✅ Easier to modify

Start using `BOMBER1:[params]` + `TARGET1` today!
