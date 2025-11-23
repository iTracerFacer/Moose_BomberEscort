# Mission Setup Guide - MOOSE Bomber Escort System

## Quick Start (5 Minutes)

### Step 1: Add MOOSE to Mission
1. Open your mission in DCS Mission Editor
2. Create a trigger: **MISSION START** → **DO SCRIPT FILE** → Select `Moose.lua`
3. Create another trigger: **MISSION START** → **DO SCRIPT FILE** → Select `Moose_BomberEscort.lua`

### Step 2: Create Bomber Template Groups

For each bomber type you want to use, create a template group:

**B-17G Template:**
1. Place group: Planes → USA → WWII → B-17G
2. Name: `BOMBER_B17`
3. Set **LATE ACTIVATION** = checked
4. Set loadout (bombs)
5. Place anywhere (will be moved on spawn)
6. Can use 1 plane (will be cloned based on BOMBER SIZE marker)

**B-52H Template:**
1. Place group: Planes → USA → B-52H
2. Name: `BOMBER_B52`
3. Set **LATE ACTIVATION** = checked
4. Set loadout
5. Place anywhere

**Repeat for other bomber types you want:**
- `BOMBER_B24` for B-24 Liberator
- `BOMBER_TU95` for Tu-95 Bear
- `BOMBER_TU22` for Tu-22M Backfire
- `BOMBER_B1` for B-1B Lancer

### Step 3: (Optional) Add Test Script
Create trigger: **MISSION START** → **DO SCRIPT FILE** → `Test_BomberEscort.lua`

This adds F10 menu with helpful commands.

### Step 4: Test In-Game
1. Start mission
2. Check DCS log for "MOOSE BOMBER ESCORT SYSTEM INITIALIZING"
3. Open F10 Map
4. Place markers (see below)
5. Spawn aircraft and escort the bombers!

---

## Detailed Marker Instructions

### Creating Your First Mission

**Scenario:** B-52 strike from Nellis to destroy enemy SAM site

1. **Open F10 Map**

2. **Mark Start Waypoint with Mission Parameters**
   - Right-click on Nellis AFB (or departure point)
   - Select "Add Marker"
   - Text: `BOMBER1:B-52H:Nellis:2:FL350:450`
   - Format: `BOMBER1:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]`
     - Type: Aircraft type (B-52H, B-17G, B-1B, etc.)
     - Airbase: Starting airbase name (optional)
     - Size: Flight size 1-6 (default: 2)
     - FL[Alt]: Flight level (FL350 = 35,000 ft, default: FL250)
     - Speed: Cruise speed in knots (default: 350)
   - Click OK

3. **Mark Target**
   - Right-click on target location (enemy SAM site)
   - Text: `TARGET1`
   - Optional: Add description like `TARGET1 SAM Site Alpha`
   - Click OK

4. **Mission Auto-Executes!**
   - System detects BOMBER1 + TARGET1 markers
   - Automatically spawns mission
   - No EXECUTE marker needed

9. **Watch for message:**
   ```
   BOMBER CONTROL: BOMBER MISSION ACTIVE
   Callsign: Thunder 3-1
   Type: B-52H x2
   Target: SAM Site Alpha
   Provide escort immediately!
   ```

10. **All markers disappear** (consumed by system)

11. **Bombers spawn and depart**

12. **Intercept and escort them!**

---

## Advanced Features

### Multiple Waypoints

Add route waypoints for complex flight paths:

```
BOMBER START Nellis
BOMBER ROUTE 1    (place marker at first waypoint)
BOMBER ROUTE 2    (place marker at second waypoint)
BOMBER TARGET Enemy Airfield
BOMBER TYPE B-17G
BOMBER SIZE 6
BOMBER EXECUTE
```

Bombers will fly: Start → Route 1 → Route 2 → Target

### Multiple Missions

You can create multiple bomber missions:

**Mission 1:**
```
BOMBER START Nellis
BOMBER TARGET Northern SAM
BOMBER TYPE B-52H
BOMBER SIZE 2
BOMBER EXECUTE
```

**Mission 2:**
```
BOMBER START Groom Lake
BOMBER TARGET Eastern Airfield
BOMBER TYPE B-1B
BOMBER SIZE 4
BOMBER EXECUTE
```

Both missions will be active simultaneously!

### Default Values

If you omit certain markers, these defaults apply:

| Parameter | Default | Notes |
|-----------|---------|-------|
| TYPE | B-52H | Uses modern bomber |
| SIZE | 2 | Two aircraft |
| ALT | From profile | B-52H = 35,000 ft |
| SPEED | From profile | B-52H = 400 kts |

Minimal mission:
```
BOMBER START Nellis
BOMBER TARGET Enemy Base
BOMBER EXECUTE
```
This spawns 2x B-52H at default altitude/speed.

---

## Bomber Profiles Reference

### WWII Bombers

**B-17G Flying Fortress**
- Speed: 180 kts
- Altitude: 20,000 ft
- Escort: 2+ fighters required
- Range: 8km escort distance
- Features: Defensive guns, tight formations
- Best for: Historical scenarios

**B-24 Liberator**
- Speed: 175 kts
- Altitude: 18,000 ft
- Similar to B-17G

### Cold War Bombers

**B-52H Stratofortress**
- Speed: 400 kts
- Altitude: 35,000 ft
- Escort: 2+ fighters required
- Range: 15km escort distance
- Features: Fast, high-altitude
- Threat: Low tolerance (aborts quickly)

**Tu-95 Bear**
- Speed: 400 kts
- Altitude: 30,000 ft
- Features: Tail gun, medium threat tolerance

**Tu-22M Backfire**
- Speed: 450 kts
- Altitude: 35,000 ft
- Features: Fast, medium evasion

### Modern Bombers

**B-1B Lancer**
- Speed: 500 kts
- Altitude: 30,000 ft
- Escort: Optional (can operate alone)
- Range: 20km escort distance
- Features: High evasion, threat tolerant
- Best for: High-risk missions

---

## In-Game Escort Guide

### Finding Your Bomber

After EXECUTE, bombers will:
1. Spawn at START location
2. Send message: "Callsign: Thunder 3-1"
3. Depart and climb to cruise altitude
4. Set course for target

**Intercept Methods:**
- Start in air near departure base
- Launch from same base
- Use AWACS/GCI to find them

### Maintaining Escort

**Distance Requirements:**
- Stay within bomber's escort range (varies by type)
- B-17: 8km (4.3 nm)
- B-52: 15km (8.1 nm)
- B-1B: 20km (10.8 nm)

**Escort Count:**
- Most bombers need 2+ escorts minimum
- B-1B can operate alone

**Listen for Messages:**
```
"Thunder 3-1: Lost escort contact. Need immediate support!"
  → Get closer immediately!

"Thunder 3-1: No escort for 90 seconds. Reducing speed."
  → Hurry! They're about to abort!

"Thunder 3-1: No escort. Mission aborted, RTB!"
  → Too late. Mission failed.

"Thunder 3-1: Escort rejoined. Resuming mission."
  → Success! They'll continue to target.
```

### Threat Response

**SAM Threats:**
```
"Thunder 3-1: SAM threat! Bearing 270, 15 km!"
```
- Escort should engage or suppress SAM
- Bomber will deploy countermeasures
- Stay close for morale

**Fighter Threats:**
```
"Thunder 3-1: FIGHTER threat! Bearing 045, 25 km!"
```
- Intercept bandits immediately
- Bomber relies on you completely
- If no escort, bomber WILL abort

### Mission Success

Bomber completes when:
1. Reaches target area
2. Delivers ordnance
3. Egresses successfully
4. Returns to base

You'll see messages at each stage.

---

## Troubleshooting

### "MISSION INVALID: No START marker placed"
- You must place a START marker
- Check spelling: `BOMBER START`

### "MISSION INVALID: Unknown bomber type: XYZ"
- Check available types with F10 menu
- Exact names: B-17G, B-52H, Tu-95, etc.

### Bombers spawn but don't move
- (Feature not yet implemented - Phase 2)
- They should taxi/takeoff/climb

### Escort not detected
- Check distance: Use F10 map measure tool
- Ensure you're same coalition
- Must be in aircraft (not ground unit)

### Markers not disappearing
- Check DCS log for errors
- Verify exact command spelling
- Ensure EXECUTE marker placed

### No messages appearing
- Check coalition (RED vs BLUE)
- Messages sent to bomber's coalition only

---

## Mission Design Tips

### Balanced Missions

**Easy Mission:**
```
BOMBER TYPE B-1B
BOMBER SIZE 4
```
Modern bombers with high survivability.

**Medium Mission:**
```
BOMBER TYPE B-52H
BOMBER SIZE 2
```
Requires constant escort.

**Hard Mission:**
```
BOMBER TYPE B-17G
BOMBER SIZE 6
BOMBER ALT 18000
```
Slow, low altitude, vulnerable to everything.

### Historical Scenarios

**1944 Europe - Daylight Raid**
```
BOMBER TYPE B-17G
BOMBER SIZE 12
BOMBER ALT 22000
BOMBER SPEED 180
```
Large formation, needs substantial escort (4-8 fighters).

**1991 Gulf War - Strategic Strike**
```
BOMBER TYPE B-52H
BOMBER SIZE 3
BOMBER ALT 30000
```
Modern bombers, fast, high-altitude.

### PvP Considerations

- Attackers: Spawn bombers for their coalition
- Defenders: Must intercept and destroy bombers
- Escorts earn points for bomber survival
- Interceptors earn points for bomber kills

---

## Phase 2 Features (Coming Soon)

These features are planned but not yet implemented:

- ✈️ Actual route flying (waypoint navigation)
- 💣 Bombing runs with weapon release
- 📊 Scoring system for escort effectiveness
- 🎯 Dynamic route adjustment around threats
- 🔧 Damage model (engines fires, wounded aircraft)
- 📻 F10 menu for player commands
- 🎨 Formation types (Box, Trail, Echelon)
- 🏆 Leaderboards and statistics

---

## Support & Development

Check the README.md for technical details.

Report issues or suggest features through your preferred channel.

**Happy Escorting!** 🛩️
