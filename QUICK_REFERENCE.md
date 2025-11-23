# Quick Reference - Bomber Escort System

## 🚀 Quick Start

1. **Mission Editor**: Create template groups `BOMBER_B17G`, `BOMBER_B52`, etc. (Late Activation)
2. **Triggers**: Load Moose.lua, then Moose_BomberEscort.lua
3. **In-Game**: Place F10 map markers
4. **Escort**: Fly close to bombers and protect them!

---

## 📝 Map Markers (F10 Map)

### Required (Numbered Waypoint System)
```
BOMBER1:B-52H:Nellis:2:FL250:350    ← All mission parameters
TARGET1                              ← Target location
```
**Auto-executes! No EXECUTE marker needed.**

### Format Breakdown
```
BOMBER1:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]
        │      │         │      │       └─ Cruise speed (knots)
        │      │         │      └─────── Altitude (FL250 = 25,000 ft)
        │      │         └────────────── Flight size (1-6)
        │      └──────────────────────── Start airbase (optional)
        └─────────────────────────────── Aircraft type
```

### Simple Examples
```
BOMBER1:B-52H:Nellis                (minimal - uses defaults)
BOMBER1:B-17G:Batumi:4:FL180:200   (WWII mission)
BOMBER1:B-1B:Nellis:2:FL500:600    (supersonic strike)
```

### Advanced - Multiple Waypoints
```
BOMBER1:B-52H:Nellis:2:FL250:350   (departure + params)
BOMBER2                             (waypoint 1)
BOMBER3                             (waypoint 2)
TARGET1                             (bombing target)
```

### Respawn Last Mission
```
RESPAWN1                            (repeats previous mission)
```

### Defaults if Parameters Omitted
- Type: B-52H
- Airbase: Uses marker position
- Size: 2 aircraft
- Altitude: FL250 (25,000 ft)
- Speed: 350 knots

---

## 🎮 F10 Commands (In-Flight)

**F10 → Bomber Missions → [Callsign]**

- **Request Status** - Check bomber state
- **Recommend Abort** - Suggest RTB
- **Warn: SAM Threat** - Alert to SAMs
- **Warn: Bandits** - Alert to fighters  
- **Request Speed +/-** - Adjust speed

---

## ✈️ Bomber Types

| Type | Speed | Alt | Escorts | Formation |
|------|-------|-----|---------|-----------|
| B-17G | 180kts | 20k | 2+ | Box (tight) |
| B-24 | 175kts | 18k | 2+ | Box (tight) |
| B-52H | 400kts | 35k | 2+ | Line Abreast |
| Tu-95 | 400kts | 30k | 2+ | Line Abreast |
| Tu-22M3 | 450kts | 35k | 2+ | Line Abreast |
| B-1B | 500kts | 30k | 0+ | Line Abreast |

---

## 🛡️ Escort Guidelines

### Stay Close
- B-17/B-24: Within **8km** (4.3nm)
- B-52/Tu-95: Within **15km** (8.1nm)
- B-1B: Within **20km** (10.8nm)

### Bomber Reactions
- **<30s no escort**: Warning
- **30-120s no escort**: Slowing, urgent
- **>120s no escort**: **ABORT!**
- **Escort returns**: Resume mission

### Priority Threats
1. **Fighters** - Intercept immediately
2. **SAMs** - Suppress or avoid
3. **AAA** - Keep bombers high

---

## 📡 Bomber Messages

### Normal Operations
- "Enroute to target"
- "At target. Beginning bombing run!"
- "Bombs away! Egressing target area"
- "Landed safely. Mission complete"

### Escort Status
- "Escort contact, 2 fighters"
- "Lost escort contact. Need support!"
- "Escort rejoined. Resuming mission"

### Threats
- "SAM threat! Bearing 270, 15 km!"
- "Bandits inbound, no escort! ABORTING!"

---

## 🎯 Mission Flow

```
1. Place markers
2. BOMBER EXECUTE
3. Bombers spawn & depart
4. Escort to target
5. Bombing run
6. Escort home
7. Bombers land
8. BOMBER RESPAWN (optional)
```

---

## 🔧 Template Groups Needed

Must be in mission editor with "Late Activation":

```
BOMBER_B17G     → B-17G
BOMBER_B24      → B-24
BOMBER_B52      → B-52H
BOMBER_TU95     → Tu-95
BOMBER_TU22M3   → Tu-22M3
BOMBER_B1B      → B-1B
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| No spawn | Check template group exists |
| No messages | Check coalition (RED/BLUE) |
| Escort not detected | Stay closer, check distance |
| Markers not working | Check spelling exactly |
| No bombing | Target must have coordinates |
| No RTB | Need valid start airbase |

---

## 💡 Pro Tips

- **Start simple**: B-52H with no route waypoints
- **Test escort detection**: Fly close, watch for message
- **Use respawn**: Fast iteration for testing
- **Check DCS log**: `Saved Games/DCS/Logs/dcs.log`
- **Historical missions**: B-17G x12 for epic raids!
- **Modern strikes**: B-1B needs minimal escort

---

## 📊 Quick Stats

- **8 Classes**: All features integrated
- **75+ Functions**: Complete AI system
- **9 Marker Commands**: Full control
- **6 F10 Commands**: Player interaction
- **6 Bomber Types**: Historical to modern
- **6 Formations**: Automatic selection
- **15+ Messages**: Rich communication

---

## ⚡ Power User Commands

### Multiple Missions
```
# Mission 1 (BLUE)
BOMBER START Nellis
BOMBER TARGET North
BOMBER TYPE B-52H
BOMBER SIZE 2
BOMBER EXECUTE

# Mission 2 (BLUE)  
BOMBER START Groom Lake
BOMBER TARGET South
BOMBER TYPE B-1B
BOMBER SIZE 4
BOMBER EXECUTE
```

### Complex Routes
```
BOMBER START Batumi
BOMBER ROUTE 1          (mark waypoint 1)
BOMBER ROUTE 2          (mark waypoint 2)
BOMBER ROUTE 3          (mark waypoint 3)
BOMBER TARGET Kobuleti
BOMBER TYPE Tu-95
BOMBER ALT 30000
BOMBER EXECUTE
```

### Historical Raid
```
BOMBER START England (hypothetical)
BOMBER TARGET Berlin
BOMBER TYPE B-17G
BOMBER SIZE 12
BOMBER ALT 22000
BOMBER SPEED 180
BOMBER EXECUTE
```

---

## 🎖️ Achievement Ideas

- ⭐ **First Escort**: Complete first mission
- ⭐⭐ **Ace Protector**: 5 missions without loss
- ⭐⭐⭐ **Guardian Angel**: Stay within escort range entire mission
- 💀 **Last Stand**: Protect bombers after all other escorts lost
- 🎯 **Precision**: All bombs on target
- 🔥 **Hot Zone**: Complete mission with 3+ SAM threats
- 📡 **Nowhere Man**: Mission without radio (no F10 commands)

---

## 📞 Resources

- **README.md**: Full technical documentation
- **SETUP_GUIDE.md**: Step-by-step mission setup
- **PHASE2_COMPLETE.md**: Feature summary
- **Test_BomberEscort.lua**: Testing utilities

---

**Version**: 1.0 Phase 2  
**Status**: ✅ Production Ready  
**Have Fun!** 🚀
