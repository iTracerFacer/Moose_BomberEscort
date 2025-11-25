# Bomber Escort Logging Migration Progress

## Summary
Systematic replacement of all logging calls in `Moose_BomberEscort.lua` with the new BOMBER_LOGGER system.

## Completed Replacements (✓)

### MARKER Category
- ✓ Waypoint marker detection (`env.info` → `BOMBER_LOGGER:Debug`)
- ✓ Auto-detected airbase (`BASE:I` → `BOMBER_LOGGER:Info`)
- ✓ Marker not on airbase (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ No friendly airbase (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ Air spawn fallback messages (`BASE:I` → `BOMBER_LOGGER:Info`)

### SPAWN Category
- ✓ Mission spawn requested (`BASE:I` → `BOMBER_LOGGER:Info`)
- ✓ Spawn parameters logging (type, start, target)

### ESCORT Category
- ✓ Escort scanning (`BASE:I` → `BOMBER_LOGGER:Trace`)
- ✓ Player aircraft detection (`BASE:I` → `BOMBER_LOGGER:Trace`)
- ✓ Escort detected messages (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ Fighter too far messages (`BASE:I` → `BOMBER_LOGGER:Trace`)
- ✓ Escort scan complete summaries (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ Phase escort detection (TAKING_OFF/CLIMBING) (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ Bomber not airborne roster updates (`BASE:I` → `BOMBER_LOGGER:Trace`)
- ✓ Escort not required messages (`BASE:I` → `BOMBER_LOGGER:Info`)
- ✓ Airborne escort detected (`BASE:I` → `BOMBER_LOGGER:Info`)
- ✓ RTB escort join messages (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ Waiting for escort (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ Formation flying detection (`BASE:I` → `BOMBER_LOGGER:Debug/Trace`)
- ✓ Formation compliments (`BASE:I` → `BOMBER_LOGGER:Debug`)
- ✓ Formation monitoring (`BASE:I` → `BOMBER_LOGGER:Trace`)

### MENU Category  
- ✓ F10 menu creation (`BASE:I` → `BOMBER_LOGGER:Info`)

### MISSION Category
- ✓ Mission registration (`BASE:I` → `BOMBER_LOGGER:Info`)

## Remaining Replacements (TODO)

### High Priority - Critical Operations

#### MISSION Category
- Mission completion (`BASE:I`)
- Mission start (`BASE:I`)

#### SPAWN Category  
- Failed to create bomber (`BASE:E` → `BOMBER_LOGGER:Error`)
- Failed to spawn bomber (`BASE:E` → `BOMBER_LOGGER:Error`)
- Spawn errors and validations
- Template not found errors (`BASE:E` → `BOMBER_LOGGER:Error`)
- Spawn success messages (`BASE:I` → `BOMBER_LOGGER:Info`)

#### ROUTE Category
- Start airbase detection (`BASE:I` → `BOMBER_LOGGER:Info`)
- Airbase not found warnings (`env.warning` → `BOMBER_LOGGER:Warn`)
- Start from marker position (`BASE:I` → `BOMBER_LOGGER:Info`)
- No valid start coordinate (`BASE:E` → `BOMBER_LOGGER:Error`)
- No valid targets (`BASE:E` → `BOMBER_LOGGER:Error`)
- Mission parameters (`BASE:I` → `BOMBER_LOGGER:Info`)
- Route waypoint additions (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Target processing (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Runway attack detection (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Airbase detection for targets (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Attack heading calculations (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Carpet bomb setup (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Point target setup (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Egress waypoint additions (`BASE:I` → `BOMBER_LOGGER:Debug`)
- RTB waypoint setup (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Route built summary (`BASE:I` → `BOMBER_LOGGER:Info`)

#### FSM Category (State Changes)
- Engine starting state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Taxiing state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Blocked state (`BASE:I` → `BOMBER_LOGGER:Warn`)
- Taking off state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Climbing state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Cruise state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Pre-attack state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Attacking state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Egressing state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Aborting state (`BASE:I` → `BOMBER_LOGGER:Warn`)
- RTB state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Landed state (`BASE:I` → `BOMBER_LOGGER:Info`)
- Destroyed state cleanup

#### FSM Monitoring
- Engine start monitoring (`BASE:I/E` → `BOMBER_LOGGER:Debug/Error`)
- Taxi transition checks (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Takeoff speed detection (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Airborne detection (`BASE:I` → `BOMBER_LOGGER:Info`)
- Cruise altitude reached (`BASE:I` → `BOMBER_LOGGER:Info`)
- Stuck/blocked detection (`BASE:E` → `BOMBER_LOGGER:Error`)
- Blockage cleared (`BASE:I` → `BOMBER_LOGGER:Info`)
- Stuck timeout criticals (`BASE:E` → `BOMBER_LOGGER:Error`)
- Startup timeout errors (`BASE:E` → `BOMBER_LOGGER:Error`)

#### COMBAT Category
- Weapons released detection (`BASE:I` → `BOMBER_LOGGER:Info`)
- Impact confirmation (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Unit destroyed (`BASE:E` → `BOMBER_LOGGER:Error`)
- Hit detection (`BASE:I` → `BOMBER_LOGGER:Info`)
- Damage classification (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Critical damage (`BASE:E` → `BOMBER_LOGGER:Error`)

#### RTB Category  
- Landing monitor start/stop (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Landing conditions detected (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Landing sustained (`BASE:I` → `BOMBER_LOGGER:Info`)
- RTB speed application (`BASE:I/E` → `BOMBER_LOGGER:Debug/Error`)
- Landing waypoint creation (`BASE:I/E` → `BOMBER_LOGGER:Debug/Error`)
- RTB route programming (`BASE:I` → `BOMBER_LOGGER:Info`)
- RTB monitor cycles (`BASE:I/E` → `BOMBER_LOGGER:Trace/Error`)
- Landing fallback triggers (`BASE:E` → `BOMBER_LOGGER:Error`)
- Landing snapshot debugging (`BASE:I/E` → `BOMBER_LOGGER:Trace/Error`)
- Despawn scheduling (`BASE:E` → `BOMBER_LOGGER:Warn`)

#### THREAT Category
- Threat detected (`BASE:I` → `BOMBER_LOGGER:Info`)
- Threat assessment (`BASE:I` → `BOMBER_LOGGER:Debug`)
- SAM warnings (`BASE:I` → `BOMBER_LOGGER:Warn`)
- SAM range warnings (progressive)
- SAM status summaries
- Fighter threat processing
- Threat cleared (`BASE:I` → `BOMBER_LOGGER:Info`)
- SAM reroute analysis (`BASE:I` → `BOMBER_LOGGER:Debug`)
- SAM corridor detection
- Threat abort decisions (`BASE:I` → `BOMBER_LOGGER:Warn`)

#### ESCORT (Additional)
- Escort roster updates (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Escort join announcements (`BASE:I` → `BOMBER_LOGGER:Info`)
- Escort leave announcements (`BASE:I` → `BOMBER_LOGGER:Info`)
- Escort roster pruning (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Escort resume logic (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Escort arrival processing (`BASE:I` → `BOMBER_LOGGER:Info`)
- Escort loss handling (`BASE:I` → `BOMBER_LOGGER:Warn`)
- Escort loss warnings (Level 1, 2, 3)
- Insufficient escort warnings

#### INIT Category
- System initialization (`BASE:I` → `BOMBER_LOGGER:Info`)
- Template validation
- Profile loading
- Configuration display

### Medium Priority

- Waypoint monitoring (`BASE:I` → `BOMBER_LOGGER:Trace`)
- Formation adjustments (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Broadcast message internals (`BASE:I` → `BOMBER_LOGGER:Trace`)
- Ground escort scanning (`BASE:I` → `BOMBER_LOGGER:Debug`)
- Holding timeout handling (`BASE:I/E` → `BOMBER_LOGGER:Warn/Error`)
- Mission scrub operations (`BASE:E` → `BOMBER_LOGGER:Error`)

### Low Priority

- IP run monitoring and announcements
- Formation type setting
- Template name conversion
- Misc debug traces

## Replacement Pattern Summary

### Error Logs
```lua
-- Old
BASE:E("error message")
BASE:E(string.format("error %s", var))

-- New
BOMBER_LOGGER:Error("CATEGORY", "error message")
BOMBER_LOGGER:Error("CATEGORY", "error %s", var)
```

### Warning Logs
```lua
-- Old
env.warning("warning message")
env.warning(string.format("warning %s", var))

-- New
BOMBER_LOGGER:Warn("CATEGORY", "warning message")
BOMBER_LOGGER:Warn("CATEGORY", "warning %s", var)
```

### Info Logs
```lua
-- Old
BASE:I("info message")
BASE:I(string.format("info %s", var))
env.info("info message")
env.info(string.format("info %s", var))

-- New
BOMBER_LOGGER:Info("CATEGORY", "info message")
BOMBER_LOGGER:Info("CATEGORY", "info %s", var)
```

### Debug Logs (detailed tracking)
```lua
-- Old
BASE:I(string.format("detailed tracking %s", var))

-- New
BOMBER_LOGGER:Debug("CATEGORY", "detailed tracking %s", var)
```

### Trace Logs (very verbose)
```lua
-- Old
BASE:I(string.format("position update %s", var))

-- New  
BOMBER_LOGGER:Trace("CATEGORY", "position update %s", var)
```

## Categories Used

- **INIT** - System initialization, setup
- **MARKER** - Marker parsing and validation
- **SPAWN** - Bomber spawning operations
- **FSM** - FSM state changes and transitions
- **ESCORT** - Escort detection and monitoring
- **THREAT** - Threat detection (SAM, fighters)
- **ROUTE** - Route planning and waypoints
- **COMBAT** - Weapons release and damage
- **RTB** - Return to base operations
- **MENU** - F10 menu operations
- **MISSION** - Mission management

## Estimated Remaining Work

- **Total logging calls**: ~200
- **Completed**: ~30 (15%)
- **Remaining**: ~170 (85%)

## Next Steps

1. Complete SPAWN category replacements (critical errors)
2. Complete FSM state change logging
3. Complete RTB and landing operations
4. Complete THREAT detection and warnings
5. Complete remaining ESCORT operations
6. Complete COMBAT logging
7. Complete ROUTE planning logs
8. Complete waypoint monitoring
9. Final validation and testing

## Notes

- String.format() calls are converted to direct format strings in BOMBER_LOGGER
- Log levels assigned based on criticality and verbosity
- Categories chosen for logical grouping of operations
- Trace level used for high-frequency position/status updates
- Debug level used for detailed tracking and diagnostics
- Info level used for major state changes and milestones
- Warn level used for unexpected situations
- Error level used for failures and critical issues
