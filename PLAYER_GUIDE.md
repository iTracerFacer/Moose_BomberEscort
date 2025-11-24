# Bomber Escort - Player Quick Start Guide

## 🎯 What is This?

A dynamic bomber mission system that lets you create AI bomber missions by placing markers on the F10 map. Perfect for escort missions, defending/attacking strategic targets, and creating realistic bomber operations.

---

## 🚀 Creating Your First Mission (30 Seconds)

### Minimum Required Markers:

1. **BOMBER1:B-52H** - Place on or near your airbase
2. **TARGET1** - Place on enemy target

**That's it!** The mission spawns automatically. Watch for the spawn message.

---

## 📋 F10 Menu Commands

Press **F10** to access:

### **F10 → Bomber Missions**
- **📋 Mission Status** - View all active bomber missions
  - Callsigns, aircraft types, targets
  - Current task and aircraft count
  - Updates in real-time
  
- **📖 Quick Start Guide** - This guide in condensed form
  - Marker format examples
  - Available aircraft
  - Quick reference

### **F10 → Bomber Missions → [Callsign]** (when mission is active)
- Individual bomber commands (if implemented)
- Request status, RTB, etc.

---

## ✈️ Available Aircraft

| Type | Name | Default Size | Era |
|------|------|--------------|-----|
| B-17G | Flying Fortress | 4 | WWII |
| B-24J | Liberator | 4 | WWII |
| B-52H | Stratofortress | 1 | Modern |
| B-1B | Lancer | 1 | Modern |
| Tu-95 | Bear | 1 | Cold War |
| Tu-22M3 | Backfire | 1 | Modern |

---

## 📝 Marker Format

### BOMBER1 - Spawn Point (Required)

**Format:**
```
BOMBER1:[Type]:[Size]:FL[Altitude]:[Speed]
```

**Examples:**

**Simplest (1 modern bomber):**
```
BOMBER1:B-52H
```

**WWII Formation (4 bombers):**
```
BOMBER1:B-17G
```

**Custom Parameters:**
```
BOMBER1:B-52H:2:FL350:400
```
- Type: B-52H
- Size: 2 aircraft
- Altitude: 35,000 feet
- Speed: 400 knots

**Large WWII Formation:**
```
BOMBER1:B-17G:6:FL200:180
```
- 6 B-17Gs in box formation
- 20,000 feet
- 180 knots

---

### TARGET1 - Attack Target (Required)

**Format:**
```
TARGET1:[AttackType]:[Heading]
```

**Examples:**

**Auto-Detect (Recommended):**
```
TARGET1
```
- If near runway (within 3km) → Carpet bombs runway
- If not near runway → Point target attack

**Runway Attack (Manual Heading):**
```
TARGET1:RUNWAY:270
```
- Attacks runway FROM heading 270° (flying east)
- Single devastating carpet bomb run

**Point Targets:**
```
TARGET1:BUILDING
TARGET1:BRIDGE
```
- Multiple bombing passes
- Precision attack

**Multiple Targets:**
```
TARGET1:RUNWAY:090   ← Attack first
TARGET2:BUILDING     ← Then this
TARGET3:BRIDGE       ← Finally this
```

---

### Optional Markers

#### BOMBER2, BOMBER3... - Ingress Route
Control flight path from spawn to target:
```
BOMBER1:B-52H        (Nellis AFB)
BOMBER2              (Waypoint through mountains)
BOMBER3              (Waypoint avoiding SAMs)
TARGET1              (Enemy target)
```

#### EGRESS1, EGRESS2... - Egress Route
Control flight path after bombing:
```
TARGET1              (Enemy target)
EGRESS1              (Safe turn point)
EGRESS2              (Avoid SAM site)
EGRESS3              (Safe corridor home)
RTB1                 (Landing point)
```

#### RTB1 - Return to Base Point
Define where bombers land:
```
RTB1  (on alternate airbase)
```
- Within 5km of airbase → Lands there
- Not near airbase → Flies there (no landing)
- No RTB1 → Returns to start airbase

#### RESPAWN1 - Repeat Mission
Quick respawn of last mission:
```
RESPAWN1
```
- Same aircraft, targets, parameters
- Useful for testing or repeated strikes

---

## 💡 Mission Examples

### Example 1: Simple Modern Strike
```
BOMBER1:B-52H          (On Nellis AFB)
TARGET1                (Enemy airbase - auto-detects runway)
```
**Result:** 1 B-52H flies direct, carpet bombs runway, returns

---

### Example 2: WWII Heavy Bomber Raid
```
BOMBER1:B-17G:6:FL200:180     (On friendly airbase)
BOMBER2                        (Safe waypoint)
BOMBER3                        (Rally point)
TARGET1:BUILDING               (Factory)
EGRESS1                        (Safe turn)
EGRESS2                        (Safe corridor)
RTB1                           (Emergency field)
```
**Result:** 6 B-17s in formation, waypoint route, bomb factory, egress to emergency field

---

### Example 3: Multi-Target Strike
```
BOMBER1:B-1B:2:FL300:500      (On airbase)
TARGET1:RUNWAY:000             (Enemy runway from north)
TARGET2:BUILDING               (Nearby ammo depot)
TARGET3:BRIDGE                 (Supply bridge)
RTB1                           (Alternate base)
```
**Result:** 2 B-1Bs hit 3 targets sequentially, land at alternate base

---

## 🎯 Attack Direction Guide

### Runway Attacks

**Format:** `TARGET1:RUNWAY:[Heading]`

The heading is where bombers approach FROM (not the direction they fly):

```
TARGET1:RUNWAY:000  → Approach from NORTH (fly south)
TARGET1:RUNWAY:090  → Approach from EAST (fly west)
TARGET1:RUNWAY:180  → Approach from SOUTH (fly north)
TARGET1:RUNWAY:270  → Approach from WEST (fly east)
```

**Tip:** Choose heading based on:
- Minimal turn from ingress route
- Egress safety (away from threats)
- Wind direction (into wind is better)

---

## ⚠️ Important Notes

### Airbase Placement
- BOMBER1 must be ON or WITHIN 5km of an airbase
- System auto-detects closest friendly airbase
- Move marker if you get "not on airbase" error

### Templates Required
Each bomber type needs a template group in mission editor:
- Group name: `BOMBER_B52H`, `BOMBER_B17G`, etc.
- **Late Activation = TRUE**
- Loadout: Bombs (any type)

### Runway Detection
- System auto-detects if TARGET1 is within 3km of airbase runway
- Use explicit `TARGET1:RUNWAY` if auto-detect fails
- Add heading `TARGET1:RUNWAY:270` for specific approach

### Mission Cleanup
- Markers automatically deleted after mission starts
- Configure in script if you want to keep them

---

## 🆘 Troubleshooting

### "NO ACTIVE MISSIONS" in Status
**Solution:** Place BOMBER1 and TARGET1 markers, mission spawns automatically

### "BOMBER1 marker not on airbase"
**Solution:** Move BOMBER1 marker closer to airbase (within 5km)

### "BOMBER TEMPLATE MISSING"
**Solution:** 
1. Open mission editor
2. Place bomber group (e.g., B-52H)
3. Name it: `BOMBER_B52H`
4. Set Late Activation = TRUE
5. Set bomb loadout
6. Save mission

### Bombers Not Attacking Runway
**Solution:** 
- Check distance to airbase (must be < 3km)
- Use explicit: `TARGET1:RUNWAY:270`
- Check logs for detection messages

---

## 📚 More Information

For complete documentation including:
- All marker parameters
- Advanced routing
- Configuration options
- Technical details

**See:** `MARKER_GUIDE.md`

---

## 🎮 Quick Reference Card

### Minimum Mission
```
BOMBER1:B-52H
TARGET1
```

### Full Mission
```
BOMBER1:B-17G:6:FL200:180
BOMBER2
BOMBER3
TARGET1:RUNWAY:270
TARGET2:BUILDING
EGRESS1
EGRESS2
RTB1
```

### F10 Menus
- F10 → Bomber Missions → Mission Status
- F10 → Bomber Missions → Quick Start Guide

### Quick Respawn
```
RESPAWN1
```

---

**Good hunting! ✈️💣**
