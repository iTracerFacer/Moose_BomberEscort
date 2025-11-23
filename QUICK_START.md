# Quick Start - New Marker System

## 60 Second Mission Setup

### 1. In Mission Editor
✅ Load `Moose.lua`  
✅ Load `Moose_BomberEscort.lua`  
✅ Create late-activated bomber templates (optional)

### 2. In Game - Open F10 Map

### 3. Place TWO Markers

**Marker 1:** Right-click on Nellis AFB
```
BOMBER1:B-52H:Nellis:2:FL250:350
```

**Marker 2:** Right-click on target location
```
TARGET1
```

### 4. Done!

⚡ **Mission auto-spawns in 2-5 seconds**  
📍 **Markers disappear automatically**  
✈️ **Bombers depart and fly to target**

---

## What Just Happened?

**BOMBER1** created a mission with:
- **Type:** B-52H Stratofortress
- **Start:** Nellis AFB
- **Size:** 2 aircraft
- **Altitude:** FL250 (25,000 feet)
- **Speed:** 350 knots

**TARGET1** marked the bombing location

**System automatically:**
- ✅ Validated parameters
- ✅ Spawned 2x B-52H at Nellis
- ✅ Planned route: Nellis → Climb → Target → Egress → RTB
- ✅ Activated escort detection
- ✅ Activated threat monitoring
- ✅ Created F10 player menus
- ✅ Removed markers from map

---

## Even Simpler

Want to skip typing parameters? Use defaults:

```
BOMBER1
TARGET1
```

Gets you:
- 2x B-52H bombers
- Spawn at BOMBER1 location
- FL250 @ 350 knots
- Attack TARGET1
- RTB to nearest base

---

## More Complex?

Add waypoints for specific routing:

```
BOMBER1:B-52H:Nellis:2:FL250:350    ← Start + parameters
BOMBER2                              ← Waypoint 1
BOMBER3                              ← Waypoint 2
TARGET1                              ← Target
```

Route: Nellis → B2 → B3 → Target → Nellis

---

## Different Bomber Types

### WWII Formation Strike
```
BOMBER1:B-17G:Batumi:6:FL180:200
TARGET1 German Factory
```
**Result:** 6x B-17 Flying Fortress, low altitude

### Modern High-Speed Strike
```
BOMBER1:B-1B:Nellis:2:FL500:600
TARGET1 High Value Target
```
**Result:** 2x B-1B Lancer, supersonic penetration

### Russian Bear Formation
```
BOMBER1:Tu-95MS:Mineralnye Vody:4:FL300:450
TARGET1 NATO Airbase
```
**Result:** 4x Tu-95 Bear, cruise missile carriers

---

## Repeat a Mission

After mission completes (or fails), instantly repeat it:

```
RESPAWN1
```

Same bombers, same route, same everything!

---

## Tips

### 💡 Parameter Order
```
BOMBER1:[Type]:[Base]:[Size]:FL[Alt]:[Speed]
```

### 💡 Skip Parameters
```
BOMBER1:B-52H:Nellis                (just type and base)
BOMBER1:B-17G::4                    (type and size, skip base)
```

### 💡 Flight Levels
- FL250 = 25,000 feet
- FL180 = 18,000 feet
- FL500 = 50,000 feet

### 💡 Available Types
- Modern: B-52H, B-1B, Tu-95MS, Tu-22M3
- WWII: B-17G, B-24J

### 💡 Flight Size
- Min: 1 aircraft
- Max: 6 aircraft
- Default: 2 aircraft

---

## Troubleshooting

**Mission doesn't spawn?**
- Check spelling: `BOMBER1` not "BOMBER 1"
- Need both BOMBER1 and TARGET1
- Wait 2-5 seconds for auto-detection

**Wrong parameters?**
- Check colons: `BOMBER1:B-52H:Nellis` not spaces
- Check FL format: `FL250` not "250"
- Check type spelling: `B-52H` not "B52"

**Still stuck?**
- Check `dcs.log` for errors
- Look for `[BOMBER]` entries
- See error messages for guidance

---

## That's It!

The new system is:
- ✅ **Fast** - 2 markers instead of 7+
- ✅ **Simple** - All params in one marker
- ✅ **Automatic** - No EXECUTE needed
- ✅ **Consistent** - Matches tanker system

Place `BOMBER1` and `TARGET1`, then fly your escort mission!

---

## Need More Info?

📖 **MARKER_GUIDE.md** - Complete marker reference  
📖 **MIGRATION_GUIDE.md** - Converting from old system  
📖 **README.md** - Full system documentation  
📖 **QUICK_REFERENCE.md** - One-page cheat sheet

Happy escorting! ✈️
