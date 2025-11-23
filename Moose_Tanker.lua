-- ============================================================================
-- MOOSE TANKER MANAGEMENT SYSTEM
-- Comprehensive tanker lifecycle management with auto-respawn, fuel monitoring,
-- TACAN/frequency announcements, and menu controls
-- ============================================================================

-- ============================================================================
-- USER CONFIGURATION
-- ============================================================================

-- Tanker Configuration
local TANKER_CONFIG = {
  KC135 = {
    groupName = "TANKER 135",
    unitName = "TANKER 135-1",
    displayName = "TANKER KC-135",
    aircraftType = "KC-135",      -- DCS aircraft type name
    livery = nil,                 -- nil for default, or livery_id string
    callsign = "SHELL",           -- Map marker prefix for custom routes
    tacan = "50X",                -- Set to match ME or nil if none
    frequency = "252.000",         -- Set to match ME or nil if none
    respawnDelay = 180,            -- seconds before auto-respawn after destruction
    emergencyRespawnDelay = 60,    -- Emergency spawn delay
    fuelWarningPercent = 25,       -- Warn when fuel drops below this %
    fuelBingoPercent = 15,         -- RTB fuel level
    defaultAltitude = 22000,       -- Default altitude in feet (FL220)
    defaultSpeed = 330,            -- Default speed in knots
  },
  KC135_MPRS = {
    groupName = "TANKER 135 MPRS",
    unitName = "TANKER 135 MPRS-1",
    displayName = "TANKER KC-135 MPRS",
    aircraftType = "KC135MPRS",    -- DCS aircraft type name
    livery = nil,
    callsign = "ARCO",             -- Map marker prefix for custom routes
    tacan = "51X",
    frequency = "253.000",
    respawnDelay = 180,
    emergencyRespawnDelay = 60,
    fuelWarningPercent = 25,
    fuelBingoPercent = 15,
    defaultAltitude = 22000,
    defaultSpeed = 330,
  }
}

-- Custom Route Configuration
local ROUTE_CONFIG = {
  minWaypoints = 2,          -- Minimum waypoints required
  maxWaypoints = 10,         -- Maximum waypoints allowed
  deleteMarkersAfterUse = true,  -- Delete markers after route creation
  waypointPrefix = {         -- Recognized marker prefixes
    SHELL = "KC135",         -- SHELL1, SHELL2, etc. → KC-135
    ARCO = "KC135_MPRS",     -- ARCO1, ARCO2, etc. → KC-135 MPRS
  }
}

-- Monitoring Configuration
local FUEL_CHECK_INTERVAL = 60  -- Check fuel every 60 seconds
local DAMAGE_RTB_THRESHOLD = 50  -- RTB if hull damage exceeds this %

-- Default Spawn Location (for non-custom route spawns)
-- Note: Using lat/lon with SetAltitude to ensure proper altitude MSL
local DEFAULT_SPAWN_COORD = COORDINATE:NewFromLLDD(34.564, 69.212):SetAltitude(22000 * 0.3048, true)  -- Kabul area, FL220

-- ============================================================================
-- GLOBAL STATE TRACKING
-- ============================================================================

TANKER_STATE = {
  KC135 = {
    active = false,
    group = nil,
    dcsGroupName = nil,
    fuelWarned = false,
    bingoWarned = false,
    respawnScheduler = nil,
    fuelMonitor = nil,
  },
  KC135_MPRS = {
    active = false,
    group = nil,
    dcsGroupName = nil,
    fuelWarned = false,
    bingoWarned = false,
    respawnScheduler = nil,
    fuelMonitor = nil,
  }
}

local UNIQUE_NAME_COUNTER = 0

local function NextUniqueIndex()
  UNIQUE_NAME_COUNTER = UNIQUE_NAME_COUNTER + 1
  return UNIQUE_NAME_COUNTER
end

local function GenerateGroupName(base, index)
  return string.format("%s #%03d", base, index)
end

local function GenerateUnitName(base, index)
  return string.format("%s-%03d", base, index)
end

-- ============================================================================
-- MENU REFERENCES (for enable/disable)
-- ============================================================================

local MENU_TANKER_ROOT = nil

-- ============================================================================
-- MESSAGE POOLS FOR VARIETY
-- Randomized messages provide immersive variety across tanker operations.
-- Each category contains 100 variations selected randomly via GetRandomMessage()
-- ============================================================================

local TANKER_MESSAGES = {
  -- Spawn Confirmation (success)
  SPAWN_SUCCESS = {
    "%s is airborne and ready for refueling operations.",
    "%s has launched and is standing by for fuel.",
    "%s is now on station and ready to pump gas.",
    "%s has departed and is available for refueling.",
    "%s is up and ready to service aircraft.",
    "%s is airborne. Refueling services now available.",
    "%s has checked in on station.",
    "%s is overhead and ready for business.",
    "%s is now available for aerial refueling.",
    "%s has arrived on station. Ready to refuel.",
    "%s is up! Time to get your drink on.",
    "%s has joined the party. Bring your cups!",
    "%s reporting. The bar is now open.",
    "%s is flying. Get in line for your juice.",
    "%s on station. Don't be shy, we got plenty.",
    "%s airborne. Unlike Mo's last attempt at flying.",
    "%s has successfully launched. No thanks to Mo.",
    "%s is ready. Mo said he could do this but we know better.",
    "%s in position. Fuel truck of the sky is open for business!",
    "%s has arrived fashionably late but ready to pump.",
    "%s checking in. Your gas station with wings is here.",
    "%s is up there doing tanker things.",
    "%s launched without hitting anything. Good start!",
    "%s airborne and hasn't broken anything yet.",
    "%s is ready to make it rain... JP-8.",
    "%s in the pattern. Come get some dinosaur juice!",
    "%s reporting for duty. Time to feed some thirsty birds.",
    "%s has spawned successfully. Mo's jealous.",
    "%s is flying high and ready to share the wealth.",
    "%s on station. Dispensary is OPEN.",
    "%s has graced you with its presence. You're welcome.",
    "%s is here to save your ass from flameout.",
    "%s launched. The sky gas station is open 24/7.",
    "%s airborne. Better than Mo's last tanker spawn attempt.",
    "%s ready to refuel. Unlike your love life, this actually works.",
    "%s has arrived to keep you from embarrassing yourself.",
    "%s on station and totally not judging your fuel planning.",
    "%s is up. Try not to break the boom this time.",
    "%s launched successfully. Mo couldn't get his off the ground.",
    "%s airborne. Your aerial bartender has arrived!",
    "%s ready for action. The juice is loose!",
    "%s has spawned. Time to get wet... with fuel.",
    "%s on station. We promise not to tell anyone you needed us.",
    "%s reporting. Because someone forgot to fuel before takeoff.",
    "%s is here! The flying fuel truck has arrived!",
    "%s airborne and ready to fill your tanks. That's what she said.",
    "%s launched. Even Mo could refuel from this... maybe.",
    "%s on station. Your poor planning is our opportunity!",
    "%s has arrived. The aerial milk truck is ready.",
    "%s ready to pump. Get your minds out of the gutter.",
    "%s airborne because you can't manage fuel apparently.",
    "%s is up there waiting. Don't keep us hovering forever.",
    "%s has joined the fight. By 'fight' we mean 'hovering lazily.'",
    "%s on station. Premium unleaded is on tap!",
    "%s launched and looking sexy up here.",
    "%s ready to refuel. Try not to scratch the paint this time.",
    "%s has arrived. Mo said this was impossible but here we are.",
    "%s airborne. The sky's full service station is open!",
    "%s on station ready to save your bacon.",
    "%s has launched into the wild blue yonder!",
    "%s reporting for gas pumping duty.",
    "%s is up and Mo isn't. Winner: us.",
    "%s airborne. Fuel flows like wine at a wedding!",
    "%s on station. Unlike Mo, we actually showed up.",
    "%s ready to top you off. No phrasing.",
    "%s has successfully taken off. Mo's still taxiing.",
    "%s airborne and operational. The real MVP.",
    "%s on station doing the lord's work.",
    "%s has arrived to prevent your walk of shame.",
    "%s ready for refueling ops. Try to connect this time.",
    "%s launched because someone has to be the adult here.",
    "%s airborne. Probably more reliable than your ex.",
    "%s on station ready to give you the good stuff.",
    "%s has spawned. Mo's tanker is still in the hangar.",
    "%s reporting. Your airborne gas station awaits!",
    "%s is up! Time for some hot refueling action.",
    "%s airborne and Mo's not invited to this party.",
    "%s on station. We have fuel, you have need. Let's dance.",
    "%s ready to dispense freedom molecules!",
    "%s has arrived to fix your fuel management issues.",
    "%s launched. The flying gas can is ready for customers.",
    "%s airborne because apparently nobody can calculate bingo.",
    "%s on station. Come get your fix!",
    "%s ready to pump premium into your thirsty bird.",
    "%s has spawned successfully. Suck it, Mo.",
    "%s reporting. Your aerial enabler is on station.",
    "%s is up there waiting like a patient parent.",
    "%s airborne and ready to make your fuel gauge happy.",
    "%s on station. Mo said we couldn't do it. We did it.",
    "%s launched with more grace than Mo's last landing.",
    "%s ready for business. The boom is ready to boom.",
    "%s has arrived fashionably and ready to serve.",
    "%s airborne. Your fuel problems are about to be solved!",
    "%s on station doing God's work up here.",
    "%s ready to refuel. We got the good stuff.",
    "%s has spawned. Time to feed the hungry jets!",
    "%s reporting for duty with full tanks!",
    "%s launched successfully without Mo's help, thank God.",
    "%s airborne. The flying filling station is OPEN!",
  },
  
  -- Already Active Warning
  ALREADY_ACTIVE = {
    "%s is already airborne!",
    "%s is currently active.",
    "%s is already on station.",
    "%s is already flying. Check status for details.",
    "%s is already up - can't spawn another.",
    "%s is currently operating.",
    "Cannot spawn - %s already active.",
    "%s is already out there!",
    "%s already flying. One at a time, please.",
    "%s is already working the pattern.",
    "%s is already up there, genius.",
    "Dude, %s is ALREADY flying. Pay attention.",
    "%s is currently active. Are you even looking?",
    "Hey Einstein, %s is already airborne!",
    "%s is up there right now. Use your eyes.",
    "What part of '%s is active' don't you understand?",
    "%s is already flying. Did Mo program this button?",
    "Seriously? %s is already up. Check your radar.",
    "%s is currently operational. Nice try though.",
    "Negative. %s is already in the air.",
    "%s is already active. Mo would have known that.",
    "Can't spawn two, buttercup. %s is already flying.",
    "%s is already out there doing tanker things.",
    "Nice try. %s is already airborne, hotshot.",
    "%s is currently flying. One's enough.",
    "Hold your horses! %s is already active.",
    "%s is already up. We're not running a bus service here.",
    "Bruh. %s is already flying.",
    "%s is currently active. Maybe learn to read?",
    "Negative ghostrider. %s is already up.",
    "%s is already airborne. Unlike your awareness.",
    "Um, %s is ALREADY flying. Hello?",
    "%s is currently on station. Wake up.",
    "You can't spawn %s twice. Physics doesn't work that way.",
    "%s is already active. Not sure what you expected.",
    "Denied! %s is already in the pattern.",
    "%s is currently flying around. Look outside.",
    "News flash: %s is already airborne!",
    "%s is already up there. Mo makes better decisions than this.",
    "Request denied. %s is already active, chief.",
    "%s is currently operational. Check your instruments.",
    "Already got one! %s is flying right now.",
    "%s is already airborne. Reading is fundamental.",
    "Uh, no. %s is currently active.",
    "%s is already out there. Situational awareness: zero.",
    "Can't spawn %s again. Not a video game, buddy.",
    "%s is currently flying. We only get one.",
    "That's a negative. %s is already up.",
    "%s is already on station. Did you even check?",
    "Seriously? %s has been flying for 20 minutes.",
    "%s is already active. This isn't rocket science.",
    "Request rejected. %s is currently airborne.",
    "%s is already up there pumping gas. Pay attention!",
    "Nope. %s is already flying. Check the status board.",
    "%s is currently active. Even Mo knew this.",
    "Cannot comply. %s is already operational.",
    "%s is already airborne. Try the status menu next time.",
    "That's a no-go. %s is currently flying.",
    "%s is already up. Did you think we had two?",
    "Denied. %s is already on station doing its thing.",
    "%s is currently active. Surprised you didn't notice.",
    "Can't do it. %s is already flying around up there.",
    "%s is already operational. One tanker at a time, pal.",
    "Negative. %s has been active for a while now.",
    "%s is already up there. Spawn button isn't a toy.",
    "Request denied. %s is currently on station.",
    "%s is already flying. Not cloning aircraft today.",
    "Can't spawn another. %s is already airborne.",
    "%s is currently active. Stop button mashing.",
    "That's not happening. %s is already up.",
    "%s is already operational. One's all you get.",
    "No can do. %s is already in the pattern.",
    "%s is currently flying. Check before clicking, maybe?",
    "Request rejected. %s is already on duty.",
    "%s is already airborne. Unlike your attention span.",
    "Nope! %s is currently active and doing fine.",
    "%s is already up there. Stop spamming the spawn button.",
    "Cannot spawn duplicate. %s is already flying.",
    "%s is currently operational. Mo's spawn would work better.",
    "Denied! %s is already on station, genius.",
    "%s is already flying. Check your tanker status!",
    "That's a negative. %s is currently active.",
    "%s is already airborne. One tanker per customer.",
    "Can't do that. %s is already up and working.",
    "%s is currently on station. Read the room.",
    "Request denied. %s is already operational, chief.",
    "%s is already active. Try paying attention.",
    "No dice. %s is already flying the pattern.",
    "%s is currently airborne. Spawn limit: 1.",
    "Negative. %s is already up there doing tanker stuff.",
    "%s is already active. Maybe check the status screen?",
    "Can't spawn %s again. We're not made of tankers here.",
    "%s is currently flying. One at a time, hotshot.",
    "Request rejected. %s is already on station.",
    "%s is already operational. Even Mo knows you only get one.",
    "That's not possible. %s is currently airborne.",
    "%s is already up there. Better situational awareness needed.",
    "Denied. %s is currently active and wondering why you asked.",
    "%s is already flying. The spawn button isn't for spam.",
    "Cannot comply. %s is already operational, Einstein.",
  },
  
  -- Spawn Failure
  SPAWN_FAILURE = {
    "Failed to spawn %s!",
    "Unable to launch %s. Try again.",
    "%s spawn aborted!",
    "Cannot spawn %s at this time.",
    "%s failed to launch!",
    "Error spawning %s. Contact support.",
    "%s launch unsuccessful.",
    "Unable to activate %s. Retry required.",
    "%s spawn failed. Check logs.",
    "Launch failure for %s!",
    "%s spawn went sideways. Oops.",
    "Well that didn't work. %s failed to spawn.",
    "%s couldn't get off the ground. Awkward.",
    "Houston, we have a problem. %s didn't spawn.",
    "%s spawn failed harder than Mo's last landing.",
    "Oof. %s spawn went to hell.",
    "%s launch aborted. This is embarrassing.",
    "Yeah, %s didn't spawn. Our bad.",
    "Spawn failed for %s. Not our finest moment.",
    "%s couldn't launch. Try again, genius.",
    "That's a big negative on %s spawn.",
    "%s failed to spawn. Did Mo write this code?",
    "Error: %s spawn went boom. The bad kind.",
    "%s launch unsuccessful. Better luck next time.",
    "Spawn failed. %s is still in the hangar.",
    "%s didn't want to fly today apparently.",
    "Well crap. %s spawn totally failed.",
    "%s launch aborted. Something broke.",
    "That didn't work. %s spawn failed miserably.",
    "%s couldn't spawn. Technical difficulties.",
    "Negative spawn for %s. Try again maybe?",
    "%s spawn went tits up. Sorry.",
    "Launch failure! %s is grounded.",
    "%s spawn crashed and burned. Not literally.",
    "Unable to spawn %s. Computer says no.",
    "%s launch failed. Mo could have done better.",
    "Spawn error for %s. This is awkward.",
    "%s didn't spawn. The universe said no.",
    "Failed to launch %s. Not our day.",
    "%s spawn aborted. Probably for the best.",
    "Yeah... %s spawn didn't happen.",
    "%s failed to spawn. Check your setup.",
    "Spawn unsuccessful for %s. Womp womp.",
    "%s launch went south. Way south.",
    "That's a no-go. %s failed to spawn.",
    "%s spawn error. Better call tech support.",
    "Launch failure! %s stayed on the ground.",
    "%s couldn't spawn. Even we're confused.",
    "Spawn failed for %s. Mo's laughing right now.",
    "%s launch aborted. Something went wrong.",
    "Unable to activate %s. Try turning it off and on again.",
    "%s spawn went nowhere fast.",
    "Failed spawn alert: %s is still parked.",
    "%s launch unsuccessful. This is fine. Everything's fine.",
    "Spawn error for %s. Not ideal.",
    "%s couldn't get airborne. Rough.",
    "Launch aborted. %s is taking a day off.",
    "%s spawn failed spectacularly.",
    "Cannot spawn %s. System said 'nah.'",
    "%s launch went sideways. Try again.",
    "Spawn failure! %s is grounded indefinitely.",
    "%s didn't spawn. Murphy's Law in effect.",
    "Failed to launch %s. Mo's spawn worked better.",
    "%s spawn unsuccessful. Check the logs.",
    "Error spawning %s. This shouldn't happen.",
    "%s launch aborted. Technical difficulties ahead.",
    "Spawn failed. %s is staying home today.",
    "%s couldn't spawn. Better luck next time, champ.",
    "Launch failure for %s. Not sure why.",
    "%s spawn went wrong. Very wrong.",
    "Unable to spawn %s. Try again later.",
    "%s launch failed. Mo would be disappointed.",
    "Spawn error: %s didn't make it.",
    "%s failed to spawn. Computer threw a tantrum.",
    "Launch aborted for %s. Sorry about that.",
    "%s spawn unsuccessful. Try again maybe?",
    "Cannot activate %s. Spawn failed.",
    "%s launch went nowhere. Like Mo's career.",
    "Spawn failure! %s is MIA.",
    "%s couldn't spawn. System error.",
    "Failed to launch %s. This is awkward.",
    "%s spawn aborted. Not today, apparently.",
    "Launch error for %s. Check your setup.",
    "%s didn't spawn. Computer says no way.",
    "Spawn unsuccessful. %s is grounded.",
    "%s launch failed. Mo's code was better.",
    "Cannot spawn %s. Technical issues.",
    "%s failed to activate. Try again.",
    "Launch aborted. %s spawn went south.",
    "%s spawn error. This isn't good.",
    "Failed to spawn %s. Maybe next time.",
    "%s launch unsuccessful. Something broke.",
    "Spawn failure for %s. Not our best work.",
    "%s couldn't get off the ground. Awkward moment.",
    "Launch error! %s is still parked.",
    "%s spawn went wrong. Very, very wrong.",
    "Unable to spawn %s. System malfunction.",
    "%s launch failed harder than expected.",
    "Spawn aborted. %s is taking a sick day.",
  },
  
  -- Custom Route Accepted
  ROUTE_ACCEPTED = {
    "%s accepting custom route with %d waypoints.%s",
    "%s has your route. %d waypoints loaded.%s",
    "%s acknowledges custom flight plan. %d waypoints.%s",
    "%s route confirmed. %d waypoints programmed.%s",
    "%s copy your route. %d waypoints accepted.%s",
    "%s roger. %d waypoint route loaded.%s",
    "%s has the route. %d points confirmed.%s",
    "%s flight plan accepted. %d waypoints.%s",
    "%s confirms route. %d waypoints in the box.%s",
    "%s routing confirmed with %d waypoints.%s",
    "%s has your custom route. %d waypoints loaded.%s",
    "%s accepts your flight plan. %d points confirmed.%s",
    "%s copies custom route with %d waypoints.%s",
    "%s acknowledges %d waypoint route.%s",
    "%s route programmed. %d waypoints locked in.%s",
    "%s flight plan confirmed with %d points.%s",
    "%s roger your route. %d waypoints loaded.%s",
    "%s accepts %d waypoint custom plan.%s",
    "%s has your %d waypoint route locked in.%s",
    "%s confirms %d waypoint flight plan.%s",
    "%s copy that. %d waypoint route programmed.%s",
    "%s routing accepted. %d points confirmed.%s",
    "%s has the route. %d waypoints ready.%s",
    "%s acknowledges %d point route.%s",
    "%s flight plan loaded with %d waypoints.%s",
    "%s custom route confirmed. %d points.%s",
    "%s accepts your %d waypoint plan.%s",
    "%s roger. %d waypoints programmed.%s",
    "%s has your %d waypoint custom route.%s",
    "%s routing confirmed with %d points.%s",
    "%s copies %d waypoint route. Unlike Mo's attempt.%s",
    "%s accepts your custom %d waypoint plan.%s",
    "%s has loaded %d waypoint route.%s",
    "%s confirms %d waypoint routing.%s",
    "%s flight plan locked in. %d waypoints.%s",
    "%s roger your %d waypoint route.%s",
    "%s accepts custom route with %d points.%s",
    "%s has programmed %d waypoint plan.%s",
    "%s acknowledges %d waypoint custom route.%s",
    "%s routing confirmed. %d waypoints ready.%s",
    "%s copies %d waypoint flight plan.%s",
    "%s accepts your %d point custom route.%s",
    "%s has %d waypoint route confirmed.%s",
    "%s roger custom plan with %d waypoints.%s",
    "%s routing accepted. %d points programmed.%s",
    "%s flight plan confirmed. %d waypoints loaded.%s",
    "%s has your custom %d waypoint routing.%s",
    "%s accepts %d waypoint plan.%s",
    "%s confirms custom route. %d waypoints.%s",
    "%s roger that. %d waypoint route accepted.%s",
    "%s has %d waypoint custom plan loaded.%s",
    "%s acknowledges %d point custom route.%s",
    "%s routing programmed. %d waypoints confirmed.%s",
    "%s flight plan accepted with %d points.%s",
    "%s copies your %d waypoint custom route.%s",
    "%s has %d waypoint route ready.%s",
    "%s accepts custom plan. %d waypoints.%s",
    "%s confirms %d point flight plan.%s",
    "%s roger custom %d waypoint route.%s",
    "%s routing locked in. %d waypoints.%s",
    "%s has %d waypoint plan confirmed.%s",
    "%s flight plan loaded. %d waypoints accepted.%s",
    "%s acknowledges custom %d waypoint route.%s",
    "%s accepts %d waypoint routing.%s",
    "%s copies custom %d waypoint plan.%s",
    "%s has %d waypoint route programmed.%s",
    "%s confirms your %d waypoint custom route.%s",
    "%s roger. %d waypoint custom plan loaded.%s",
    "%s routing accepted with %d points.%s",
    "%s flight plan programmed. %d waypoints.%s",
    "%s has custom route with %d waypoints.%s",
    "%s accepts %d waypoint custom plan.%s",
    "%s acknowledges %d waypoint routing.%s",
    "%s copies %d waypoint custom route.%s",
    "%s has %d waypoint flight plan confirmed.%s",
    "%s roger custom route. %d waypoints.%s",
    "%s routing confirmed with %d waypoints.%s",
    "%s flight plan accepted. %d points loaded.%s",
    "%s has your %d waypoint custom plan.%s",
    "%s accepts custom %d waypoint route.%s",
    "%s confirms %d waypoint custom plan.%s",
    "%s acknowledges %d waypoint flight plan.%s",
    "%s copies %d waypoint route confirmed.%s",
    "%s has custom %d waypoint routing ready.%s",
    "%s roger. %d waypoints accepted and locked.%s",
    "%s routing programmed with %d waypoints.%s",
    "%s flight plan confirmed with %d points.%s",
    "%s has %d waypoint custom route loaded.%s",
    "%s accepts your custom %d waypoint routing.%s",
    "%s confirms %d waypoint plan confirmed.%s",
    "%s acknowledges custom route with %d points.%s",
    "%s copies %d waypoint custom flight plan.%s",
    "%s has %d waypoint route locked and loaded.%s",
    "%s roger that. %d waypoint custom route ready.%s",
    "%s routing accepted. %d waypoints programmed.%s",
    "%s flight plan loaded with %d waypoints.%s",
  },
  
  -- Emergency Spawn
  EMERGENCY_SPAWN = {
    "EMERGENCY: %s launching immediately!",
    "PRIORITY LAUNCH: %s is scrambling now!",
    "EMERGENCY TANKER: %s departing expedited!",
    "URGENT: %s is launching on priority status!",
    "EMERGENCY RESPONSE: %s airborne ASAP!",
    "PRIORITY: %s scrambling for emergency fuel!",
    "EMERGENCY: %s launching hot!",
    "URGENT LAUNCH: %s is wheels up now!",
    "EMERGENCY TANKER: %s responding immediately!",
    "PRIORITY STATUS: %s emergency launch in progress!",
    "EMERGENCY! %s wheels up NOW!",
    "SCRAMBLE SCRAMBLE: %s launching immediately!",
    "PRIORITY LAUNCH: %s getting airborne right now!",
    "EMERGENCY TANKER: %s departing hot and fast!",
    "URGENT: %s scrambling for emergency refuel!",
    "PRIORITY: %s launching on expedited status!",
    "EMERGENCY RESPONSE: %s airborne immediately!",
    "URGENT LAUNCH: %s departing NOW!",
    "EMERGENCY: %s getting up there ASAP!",
    "PRIORITY STATUS: %s scrambling right now!",
    "EMERGENCY TANKER: %s wheels up immediately!",
    "URGENT: %s launching on priority!",
    "SCRAMBLE: %s departing expedited!",
    "EMERGENCY: %s getting airborne fast!",
    "PRIORITY LAUNCH: %s launching NOW!",
    "URGENT TANKER: %s scrambling immediately!",
    "EMERGENCY: %s departing hot!",
    "PRIORITY: %s wheels up ASAP!",
    "URGENT LAUNCH: %s airborne right now!",
    "EMERGENCY TANKER: %s launching immediately!",
    "SCRAMBLE SCRAMBLE: %s getting up there now!",
    "PRIORITY: %s launching on emergency status!",
    "URGENT: %s departing immediately!",
    "EMERGENCY: %s scrambling for urgent refuel!",
    "PRIORITY LAUNCH: %s wheels up hot!",
    "URGENT TANKER: %s airborne ASAP!",
    "EMERGENCY: %s launching right now!",
    "PRIORITY: %s scrambling expedited!",
    "URGENT LAUNCH: %s departing NOW NOW NOW!",
    "EMERGENCY TANKER: %s getting airborne fast!",
    "PRIORITY STATUS: %s launching immediately!",
    "URGENT: %s wheels up on priority!",
    "EMERGENCY: %s scrambling now!",
    "PRIORITY LAUNCH: %s departing fast!",
    "URGENT TANKER: %s launching ASAP!",
    "EMERGENCY: %s airborne immediately!",
    "PRIORITY: %s scrambling hot!",
    "URGENT LAUNCH: %s wheels up right now!",
    "EMERGENCY TANKER: %s departing expedited!",
    "PRIORITY: %s launching on urgent status!",
    "URGENT: %s getting airborne now!",
    "EMERGENCY SCRAMBLE: %s departing immediately!",
    "PRIORITY TANKER: %s wheels up fast!",
    "URGENT: %s launching right now!",
    "EMERGENCY: %s airborne ASAP!",
    "PRIORITY LAUNCH: %s scrambling now!",
    "URGENT TANKER: %s departing hot!",
    "EMERGENCY: %s wheels up immediately!",
    "PRIORITY: %s getting airborne fast!",
    "URGENT LAUNCH: %s scrambling ASAP!",
    "EMERGENCY TANKER: %s launching on priority!",
    "PRIORITY: %s departing right now!",
    "URGENT: %s airborne expedited!",
    "EMERGENCY: %s scrambling immediately!",
    "PRIORITY LAUNCH: %s wheels up NOW!",
    "URGENT TANKER: %s launching fast!",
    "EMERGENCY: %s departing ASAP!",
    "PRIORITY: %s airborne right now!",
    "URGENT LAUNCH: %s scrambling hot!",
    "EMERGENCY TANKER: %s wheels up expedited!",
    "PRIORITY: %s launching immediately!",
    "URGENT: %s getting airborne ASAP!",
    "EMERGENCY: %s scrambling fast!",
    "PRIORITY LAUNCH: %s departing NOW!",
    "URGENT TANKER: %s wheels up right now!",
    "EMERGENCY: %s airborne hot!",
    "PRIORITY: %s scrambling ASAP!",
    "URGENT LAUNCH: %s launching immediately!",
    "EMERGENCY TANKER: %s departing fast!",
    "PRIORITY: %s wheels up expedited!",
    "URGENT: %s airborne NOW!",
    "EMERGENCY: %s launching hot and fast!",
    "PRIORITY LAUNCH: %s scrambling expedited!",
    "URGENT TANKER: %s departing immediately!",
    "EMERGENCY: %s wheels up ASAP!",
    "PRIORITY: %s getting airborne now!",
    "URGENT LAUNCH: %s airborne fast!",
    "EMERGENCY TANKER: %s scrambling NOW!",
    "PRIORITY: %s launching expedited!",
    "URGENT: %s departing hot!",
    "EMERGENCY: %s airborne immediately unlike Mo!",
    "PRIORITY LAUNCH: %s wheels up faster than Mo!",
    "URGENT TANKER: %s scrambling (Mo couldn't do this)!",
    "EMERGENCY: %s launching while Mo watches!",
    "PRIORITY: %s departing - Mo take notes!",
    "URGENT LAUNCH: %s airborne (unlike Mo's attempts)!",
    "EMERGENCY TANKER: %s scrambling successfully!",
    "PRIORITY: %s wheels up for real!",
    "URGENT: %s launching like professionals do!",
  },
  
  -- Low Fuel Warning
  LOW_FUEL = {
    "%s reports fuel at %d%%. Recommend expedite refueling.",
    "%s low on fuel - %d%% remaining. RTB soon.",
    "%s fuel state: %d%%. Time is limited.",
    "%s down to %d%% fuel. Get your gas quick.",
    "%s running low - %d%% remaining.",
    "%s fuel advisory: %d%% left. Don't delay.",
    "%s reports %d%% fuel state. Limited time remaining.",
    "%s low fuel warning at %d%%. RTB imminent.",
    "%s fuel: %d%%. Better hurry up.",
    "%s getting thirsty at %d%% fuel remaining.",
    "%s fuel down to %d%%. Time's ticking.",
    "%s running on fumes at %d%%. Get moving.",
    "%s reports %d%% fuel. Clock is running.",
    "%s fuel state critical at %d%%.",
    "%s getting low at %d%%. Don't dawdle.",
    "%s fuel: %d%%. Window is closing.",
    "%s reports %d%% remaining. Hurry it up.",
    "%s fuel advisory: %d%%. Time's short.",
    "%s down to %d%%. Better move fast.",
    "%s fuel at %d%%. RTB soon or refuel now.",
    "%s running thin at %d%%. Expedite.",
    "%s reports %d%% fuel. Not much time left.",
    "%s fuel state %d%%. Don't mess around.",
    "%s getting low - %d%% and dropping.",
    "%s fuel: %d%%. Better get some quick.",
    "%s reports %d%%. Running out of time.",
    "%s fuel down to %d%%. Tick tock.",
    "%s low on gas at %d%%. Move it.",
    "%s reports %d%% fuel state. Limited window.",
    "%s fuel: %d%%. Don't be slow about it.",
    "%s getting thirsty - %d%% remaining.",
    "%s reports %d%%. Better hurry your ass up.",
    "%s fuel at %d%%. Time ain't on your side.",
    "%s running low - %d%%. Get in here.",
    "%s fuel state: %d%%. Mo could refuel faster.",
    "%s reports %d%%. Don't be a hero, get fuel.",
    "%s fuel down to %d%%. Unlike Mo we're warning you.",
    "%s getting low at %d%%. Stop screwing around.",
    "%s reports %d%% fuel. This isn't a drill.",
    "%s fuel: %d%%. Better not screw this up.",
    "%s running thin - %d%% remaining.",
    "%s reports %d%%. Time to get your ass over here.",
    "%s fuel state %d%%. Seriously, hurry up.",
    "%s getting thirsty at %d%%. Don't be stupid.",
    "%s fuel: %d%%. We're leaving soon.",
    "%s reports %d%%. Better expedite refueling.",
    "%s fuel down to %d%%. Window closing fast.",
    "%s low on juice - %d%% remaining.",
    "%s reports %d%% fuel. Get moving or RTB.",
    "%s fuel state: %d%%. Don't drag ass.",
    "%s getting low at %d%%. Time's running out.",
    "%s reports %d%%. Stop dicking around.",
    "%s fuel: %d%%. Get in the basket.",
    "%s running thin at %d%%. Move faster.",
    "%s reports %d%% remaining. Chop chop.",
    "%s fuel down to %d%%. Unlike Mo's planning.",
    "%s getting thirsty - %d%%. Don't be slow.",
    "%s reports %d%% fuel state. Hurry.",
    "%s fuel: %d%%. Better not flame out.",
    "%s low on gas at %d%%. Get over here.",
    "%s reports %d%%. Time to move it.",
    "%s fuel state %d%%. We don't have all day.",
    "%s getting low - %d%% and dropping fast.",
    "%s reports %d%%. Stop being a pussy.",
    "%s fuel: %d%%. Refuel or die trying.",
    "%s running thin - %d%%. Better hurry.",
    "%s reports %d%% fuel. Move your ass.",
    "%s fuel down to %d%%. Not kidding here.",
    "%s getting thirsty at %d%%. Expedite.",
    "%s reports %d%%. Don't be like Mo.",
    "%s fuel state: %d%%. Get fuel or get bent.",
    "%s low at %d%%. Time's wasting.",
    "%s reports %d%% remaining. Hurry up.",
    "%s fuel: %d%%. Stop fucking around.",
    "%s running low - %d%%. Get here now.",
    "%s reports %d%%. We're not waiting forever.",
    "%s fuel down to %d%%. Better get moving.",
    "%s getting low at %d%%. Tick tock motherfucker.",
    "%s reports %d%% fuel state. Move it.",
    "%s fuel: %d%%. Don't be a jackass.",
    "%s running thin at %d%%. Expedite refuel.",
    "%s reports %d%%. Time's running short.",
    "%s fuel state %d%%. Get in the pattern.",
    "%s getting thirsty - %d%%. Don't delay.",
    "%s reports %d%%. Unlike Mo we're still here.",
    "%s fuel: %d%%. Better not screw this up.",
    "%s low on gas - %d%% remaining.",
    "%s reports %d%% fuel. Window closing.",
    "%s fuel down to %d%%. Get your shit together.",
    "%s getting low at %d%%. Seriously move.",
    "%s reports %d%%. Don't make us leave.",
    "%s fuel state: %d%%. Better expedite.",
    "%s running thin - %d%%. Time's up soon.",
    "%s reports %d%% remaining. Get here.",
    "%s fuel: %d%%. Stop dragging ass.",
    "%s getting thirsty at %d%%. Hurry.",
    "%s reports %d%%. Mo would have flamed out by now.",
  },
  
  -- Bingo Fuel (RTB)
  BINGO_FUEL = {
    "%s is BINGO fuel. Returning to base immediately!",
    "%s has reached BINGO. RTB in progress!",
    "%s calling BINGO fuel. Departing the pattern now!",
    "%s is at BINGO state. Returning to base!",
    "%s BINGO fuel - heading home now!",
    "%s has hit BINGO. No more refueling available!",
    "%s fuel critical - RTB initiated!",
    "%s at BINGO state. Breaking off now!",
    "%s calling BINGO. Pattern is clear!",
    "%s BINGO fuel declared. Returning to base!",
    "%s is BINGO. Getting the hell out!",
    "%s calling BINGO fuel. We're done here!",
    "%s has reached BINGO state. Leaving NOW!",
    "%s BINGO declared. RTB in progress!",
    "%s at BINGO fuel. Heading home!",
    "%s calling BINGO. Pattern clear!",
    "%s has hit BINGO. See ya!",
    "%s BINGO fuel state. Departing!",
    "%s is at BINGO. RTB immediately!",
    "%s calling BINGO. We're out!",
    "%s has reached BINGO. Breaking off!",
    "%s BINGO fuel declared. Leaving!",
    "%s at BINGO state. Going home!",
    "%s calling BINGO. Adios!",
    "%s has hit BINGO fuel. Departing now!",
    "%s BINGO declared. RTB active!",
    "%s is at BINGO. Bye bye!",
    "%s calling BINGO fuel. Out of here!",
    "%s has reached BINGO state. Later!",
    "%s BINGO fuel. Heading back!",
    "%s at BINGO. Returning immediately!",
    "%s calling BINGO. Pattern's yours!",
    "%s has hit BINGO. Going home!",
    "%s BINGO declared. Leaving the AO!",
    "%s is at BINGO fuel. RTB now!",
    "%s calling BINGO. Peace out!",
    "%s has reached BINGO. Departing!",
    "%s BINGO fuel state. We're done!",
    "%s at BINGO. Heading to base!",
    "%s calling BINGO. Catch you later!",
    "%s has hit BINGO fuel. RTB!",
    "%s BINGO declared. Getting out!",
    "%s is at BINGO state. Later gator!",
    "%s calling BINGO. We out!",
    "%s has reached BINGO. Returning!",
    "%s BINGO fuel. Leaving now!",
    "%s at BINGO. Going home finally!",
    "%s calling BINGO. Done pumping gas!",
    "%s has hit BINGO. RTB initiated!",
    "%s BINGO declared. Out of here!",
    "%s is at BINGO fuel. Bye!",
    "%s calling BINGO. Pattern clear!",
    "%s has reached BINGO state. Departing!",
    "%s BINGO fuel. Heading back!",
    "%s at BINGO. RTB in progress!",
    "%s calling BINGO. See ya later!",
    "%s has hit BINGO fuel. Leaving!",
    "%s BINGO declared. Going home!",
    "%s is at BINGO. Out!",
    "%s calling BINGO fuel. We're outta here!",
    "%s has reached BINGO. RTB now!",
    "%s BINGO fuel state. Later!",
    "%s at BINGO. Returning to base!",
    "%s calling BINGO. Adios amigos!",
    "%s has hit BINGO. Departing!",
    "%s BINGO declared. Heading home!",
    "%s is at BINGO fuel. Peace!",
    "%s calling BINGO. We done!",
    "%s has reached BINGO state. Leaving!",
    "%s BINGO fuel. RTB active!",
    "%s at BINGO. Going back!",
    "%s calling BINGO. That's it folks!",
    "%s has hit BINGO fuel. Out of here!",
    "%s BINGO declared. Returning!",
    "%s is at BINGO. Later suckers!",
    "%s calling BINGO fuel. Bye!",
    "%s has reached BINGO. Heading home!",
    "%s BINGO fuel state. Departing!",
    "%s at BINGO. RTB initiated!",
    "%s calling BINGO. We're gone!",
    "%s has hit BINGO. Leaving now!",
    "%s BINGO declared. Getting out of dodge!",
    "%s is at BINGO fuel. Later!",
    "%s calling BINGO. Don't wait up!",
    "%s has reached BINGO state. Out!",
    "%s BINGO fuel. Going home!",
    "%s at BINGO. Returning immediately!",
    "%s calling BINGO. Unlike Mo we planned this!",
    "%s has hit BINGO fuel. Peace out!",
    "%s BINGO declared. Heading back!",
    "%s is at BINGO. Bye felicia!",
    "%s calling BINGO fuel. That's a wrap!",
    "%s has reached BINGO. We're out!",
    "%s BINGO fuel state. Later gator!",
    "%s at BINGO. RTB right now!",
    "%s calling BINGO. Smell ya later!",
    "%s has hit BINGO. Departing!",
    "%s BINGO declared. Mo would've flamed out!",
    "%s is at BINGO fuel. Catch you on the flip side!",
  },
  
  -- Tanker Destroyed
  DESTROYED = {
    "%s has been destroyed!",
    "%s is down! Aircraft lost!",
    "%s has been shot down!",
    "%s destroyed in combat!",
    "%s is gone - aircraft destroyed!",
    "%s has been lost!",
    "We've lost %s!",
    "%s destroyed! No survivors!",
    "%s is down and out!",
    "%s has been eliminated!",
    "%s has been blown to hell!",
    "%s is toast! Aircraft destroyed!",
    "%s went down in flames!",
    "%s has been obliterated!",
    "%s is scrap metal now!",
    "%s got smoked!",
    "RIP %s. Aircraft destroyed!",
    "%s has been vaporized!",
    "%s is no more!",
    "%s went down hard!",
    "%s has been wasted!",
    "%s is KIA! Aircraft lost!",
    "%s got shot the fuck down!",
    "%s has been annihilated!",
    "%s is sleeping with the fishes!",
    "%s went boom!",
    "%s has been terminated!",
    "%s is dead! No survivors!",
    "%s got fucked up!",
    "%s has ceased to exist!",
    "%s went down like Mo's career!",
    "%s is destroyed! Total loss!",
    "%s got hammered!",
    "%s has been neutralized!",
    "%s is history!",
    "%s went down in a ball of fire!",
    "%s has been taken out!",
    "%s is gone forever!",
    "%s got massacred!",
    "%s has been deleted!",
    "%s is pushing up daisies!",
    "%s went down screaming!",
    "%s has been liquidated!",
    "%s is scattered across the landscape!",
    "%s got wrecked!",
    "%s has been erased!",
    "%s is no longer operational!",
    "%s went down like a brick!",
    "%s has been dispatched!",
    "%s is gone to the great hangar in the sky!",
    "%s got absolutely demolished!",
    "%s has been removed from existence!",
    "%s is dead as fuck!",
    "%s went down faster than Mo!",
    "%s has been exterminated!",
    "%s is now a smoking crater!",
    "%s got absolutely destroyed!",
    "%s has been converted to debris!",
    "%s is no longer with us!",
    "%s went down in a spectacular fashion!",
    "%s has been sent to hell!",
    "%s is totally fucked!",
    "%s got blown out of the sky!",
    "%s has been utterly destroyed!",
    "%s is burning on the ground!",
    "%s went down like a sack of shit!",
    "%s has been wiped out!",
    "%s is permanently grounded!",
    "%s got turned into confetti!",
    "%s has been removed from service!",
    "%s is now spare parts!",
    "%s went down hard and fast!",
    "%s has been completely destroyed!",
    "%s is toast and then some!",
    "%s got absolutely annihilated!",
    "%s has been blown to smithereens!",
    "%s is no longer flying!",
    "%s went down like the Hindenburg!",
    "%s has been totally wrecked!",
    "%s is deader than dead!",
    "%s got straight up murdered!",
    "%s has been completely obliterated!",
    "%s is scattered across three counties!",
    "%s went down in flames like Mo's reputation!",
    "%s has been catastrophically destroyed!",
    "%s is now a fireball!",
    "%s got absolutely smoked!",
    "%s has been reduced to atoms!",
    "%s is gone gone gone!",
    "%s went down and ain't coming back!",
    "%s has been utterly annihilated!",
    "%s is now a lawn dart!",
    "%s got completely fucked!",
    "%s has been sent to the shadow realm!",
    "%s is now in aircraft heaven!",
    "%s went down faster than your hopes and dreams!",
    "%s has been totally destroyed!",
    "%s is no longer a thing!",
  },
  
  -- Hostile Fire
  TAKING_FIRE = {
    "%s is taking fire!",
    "%s under attack!",
    "%s receiving hostile fire!",
    "%s taking hits!",
    "%s is being engaged!",
    "%s under hostile fire!",
    "Hostile fire on %s!",
    "%s taking enemy fire!",
    "%s is under attack!",
    "%s being fired upon!",
    "%s is getting shot at!",
    "%s under hostile fire!",
    "%s taking incoming!",
    "%s is being lit up!",
    "%s receiving enemy fire!",
    "%s getting hammered!",
    "%s under attack right now!",
    "%s taking fire from hostiles!",
    "%s is being engaged by enemy!",
    "%s getting shot to shit!",
    "%s under hostile attack!",
    "%s taking heavy fire!",
    "%s is being targeted!",
    "%s receiving hostile rounds!",
    "%s getting fucked up!",
    "%s under enemy fire!",
    "%s taking hits from hostiles!",
    "%s is being shot at!",
    "%s receiving incoming fire!",
    "%s getting attacked!",
    "%s under hostile engagement!",
    "%s taking enemy rounds!",
    "%s is being hit!",
    "%s receiving fire!",
    "%s getting lit up!",
    "%s under attack from enemy!",
    "%s taking hostile fire!",
    "%s is being engaged!",
    "%s receiving enemy rounds!",
    "%s getting shot!",
    "%s under fire right now!",
    "%s taking incoming rounds!",
    "%s is being attacked!",
    "%s receiving hostile fire!",
    "%s getting hammered by hostiles!",
    "%s under enemy attack!",
    "%s taking fire from below!",
    "%s is being targeted by enemy!",
    "%s receiving heavy fire!",
    "%s getting shot at hard!",
    "%s under hostile fire!",
    "%s taking enemy fire now!",
    "%s is being engaged by hostiles!",
    "%s receiving incoming!",
    "%s getting attacked by enemy!",
    "%s under fire from hostiles!",
    "%s taking hits!",
    "%s is being shot up!",
    "%s receiving hostile rounds!",
    "%s getting fucked up by enemy!",
    "%s under hostile engagement!",
    "%s taking fire!",
    "%s is being hammered!",
    "%s receiving enemy fire!",
    "%s getting shot at!",
    "%s under enemy fire!",
    "%s taking hostile rounds!",
    "%s is being lit up!",
    "%s receiving fire from hostiles!",
    "%s getting attacked hard!",
    "%s under hostile attack!",
    "%s taking incoming fire!",
    "%s is being engaged!",
    "%s receiving hostile fire!",
    "%s getting shot to hell!",
    "%s under fire!",
    "%s taking enemy rounds!",
    "%s is being targeted!",
    "%s receiving fire!",
    "%s getting hammered!",
    "%s under attack by hostiles!",
    "%s taking fire from enemy!",
    "%s is being shot at!",
    "%s receiving incoming rounds!",
    "%s getting attacked!",
    "%s under hostile fire right now!",
    "%s taking hits from enemy!",
    "%s is being engaged by hostiles!",
    "%s receiving hostile fire!",
    "%s getting lit up by enemy!",
    "%s under fire from below!",
    "%s taking enemy fire!",
    "%s is being attacked by hostiles!",
    "%s receiving fire from enemy!",
    "%s getting shot at hard!",
    "%s under enemy attack!",
    "%s taking hostile fire unlike Mo who'd be dead!",
    "%s is being hammered by hostiles!",
    "%s receiving enemy rounds!",
  },
  
  -- Invalid Waypoint Count (too few)
  TOO_FEW_WAYPOINTS = {
    "Custom route requires at least %d waypoints!\nPlace markers: %s1, %s2, etc.",
    "Not enough waypoints! Need at least %d.\nUse markers: %s1, %s2, etc.",
    "Insufficient waypoints - need %d minimum.\nCreate markers: %s1, %s2, etc.",
    "Route rejected: need %d waypoints minimum.\nPlace %s1, %s2, etc.",
    "At least %d waypoints required!\nDrop markers: %s1, %s2, etc.",
    "Need more waypoints - minimum is %d.\nUse: %s1, %s2, etc.",
    "Route incomplete. Need %d waypoints.\nCreate: %s1, %s2, etc.",
    "Waypoint count too low - need %d.\nPlace: %s1, %s2, etc.",
    "Minimum %d waypoints required!\nMark: %s1, %s2, etc.",
    "Can't route with less than %d points.\nAdd markers: %s1, %s2, etc.",
  },
  
  -- Too Many Waypoints
  TOO_MANY_WAYPOINTS = {
    "Too many waypoints! Maximum is %d",
    "Waypoint limit exceeded. Max: %d",
    "Can't route with more than %d waypoints!",
    "Route rejected - too many points. Max: %d",
    "Waypoint overflow! Maximum is %d",
    "Too complex - max %d waypoints allowed!",
    "Exceeded waypoint limit of %d!",
    "Route too long! Maximum: %d waypoints",
    "Cannot accept more than %d waypoints!",
    "Waypoint maximum is %d. Route rejected.",
  },
  
  -- No RTB Airbase Found
  NO_RTB_AIRBASE = {
    "No friendly airbase found for RTB!",
    "Cannot locate RTB destination!",
    "No suitable airbase available for recovery!",
    "Unable to find friendly base for RTB!",
    "No recovery airfield located!",
    "RTB destination unavailable!",
    "Cannot identify friendly airbase for return!",
    "No airbase in range for RTB!",
    "Recovery base not found!",
    "Unable to locate RTB airfield!",
  },
  -- EMERGENCY SPAWN MESSAGES (100 total)
  EMERGENCY_SPAWN = {
    "EMERGENCY: %s launching immediately!",
    "PRIORITY LAUNCH: %s is scrambling now!",
    "EMERGENCY TANKER: %s departing expedited!",
    "URGENT: %s is launching on priority status!",
    "EMERGENCY RESPONSE: %s airborne ASAP!",
    "PRIORITY: %s scrambling for emergency fuel!",
    "EMERGENCY: %s launching hot!",
    "URGENT LAUNCH: %s is wheels up now!",
    "EMERGENCY TANKER: %s responding immediately!",
    "PRIORITY STATUS: %s emergency launch in progress!",
    "EMERGENCY! %s wheels up NOW!",
    "SCRAMBLE SCRAMBLE: %s launching immediately!",
    "PRIORITY LAUNCH: %s getting airborne right now!",
    "EMERGENCY TANKER: %s departing hot and fast!",
    "URGENT: %s scrambling for emergency refuel!",
    "PRIORITY: %s launching on expedited status!",
    "EMERGENCY RESPONSE: %s airborne immediately!",
    "URGENT LAUNCH: %s departing NOW!",
    "EMERGENCY: %s getting up there ASAP!",
    "PRIORITY STATUS: %s scrambling right now!",
    "EMERGENCY TANKER: %s wheels up immediately!",
    "URGENT: %s launching on priority!",
    "SCRAMBLE: %s departing expedited!",
    "EMERGENCY: %s getting airborne fast!",
    "PRIORITY LAUNCH: %s launching NOW!",
    "URGENT TANKER: %s scrambling immediately!",
    "EMERGENCY: %s departing hot!",
    "PRIORITY: %s wheels up ASAP!",
    "URGENT LAUNCH: %s airborne right now!",
    "EMERGENCY TANKER: %s launching immediately!",
    "SCRAMBLE SCRAMBLE: %s getting up there now!",
    "PRIORITY: %s launching on emergency status!",
    "URGENT: %s departing immediately!",
    "EMERGENCY: %s scrambling for urgent refuel!",
    "PRIORITY LAUNCH: %s wheels up hot!",
    "URGENT TANKER: %s airborne ASAP!",
    "EMERGENCY: %s launching right now!",
    "PRIORITY: %s scrambling expedited!",
    "URGENT LAUNCH: %s departing NOW NOW NOW!",
    "EMERGENCY TANKER: %s getting airborne fast!",
    "PRIORITY STATUS: %s launching immediately!",
    "URGENT: %s wheels up on priority!",
    "EMERGENCY: %s scrambling now!",
    "PRIORITY LAUNCH: %s departing fast!",
    "URGENT TANKER: %s launching ASAP!",
    "EMERGENCY: %s airborne immediately!",
    "PRIORITY: %s scrambling hot!",
    "URGENT LAUNCH: %s wheels up right now!",
    "EMERGENCY TANKER: %s departing expedited!",
    "PRIORITY: %s launching on urgent status!",
    "URGENT: %s getting airborne now!",
    "EMERGENCY SCRAMBLE: %s departing immediately!",
    "PRIORITY TANKER: %s wheels up fast!",
    "URGENT: %s launching right now!",
    "EMERGENCY: %s airborne ASAP!",
    "PRIORITY LAUNCH: %s scrambling now!",
    "URGENT TANKER: %s departing hot!",
    "EMERGENCY: %s wheels up immediately!",
    "PRIORITY: %s getting airborne fast!",
    "URGENT LAUNCH: %s scrambling ASAP!",
    "EMERGENCY TANKER: %s launching on priority!",
    "PRIORITY: %s departing right now!",
    "URGENT: %s airborne expedited!",
    "EMERGENCY: %s scrambling immediately!",
    "PRIORITY LAUNCH: %s wheels up NOW!",
    "URGENT TANKER: %s launching fast!",
    "EMERGENCY: %s departing ASAP!",
    "PRIORITY: %s airborne right now!",
    "URGENT LAUNCH: %s scrambling hot!",
    "EMERGENCY TANKER: %s wheels up expedited!",
    "PRIORITY: %s launching immediately!",
    "URGENT: %s getting airborne ASAP!",
    "EMERGENCY: %s scrambling fast!",
    "PRIORITY LAUNCH: %s departing NOW!",
    "URGENT TANKER: %s wheels up right now!",
    "EMERGENCY: %s airborne hot!",
    "PRIORITY: %s scrambling ASAP!",
    "URGENT LAUNCH: %s launching immediately!",
    "EMERGENCY TANKER: %s departing fast!",
    "PRIORITY: %s wheels up expedited!",
    "URGENT: %s airborne NOW!",
    "EMERGENCY: %s launching hot and fast!",
    "PRIORITY LAUNCH: %s scrambling expedited!",
    "URGENT TANKER: %s departing immediately!",
    "EMERGENCY: %s wheels up ASAP!",
    "PRIORITY: %s getting airborne now!",
    "URGENT LAUNCH: %s airborne fast!",
    "EMERGENCY TANKER: %s scrambling NOW!",
    "PRIORITY: %s launching expedited!",
    "URGENT: %s departing hot!",
    "EMERGENCY: %s airborne immediately unlike Mo!",
    "PRIORITY LAUNCH: %s wheels up faster than Mo!",
    "URGENT TANKER: %s scrambling (Mo couldn't do this)!",
    "EMERGENCY: %s launching while Mo watches!",
    "PRIORITY: %s departing - Mo take notes!",
    "URGENT LAUNCH: %s airborne (unlike Mo's attempts)!",
    "EMERGENCY TANKER: %s scrambling successfully!",
    "PRIORITY: %s wheels up for real!",
    "URGENT: %s launching like professionals do!",
  },
}

--- Get a random message from a category
--- @param category string Message category key
--- @param ... any Format arguments for string.format
--- @return string Formatted message
local function GetRandomMessage(category, ...)
  local pool = TANKER_MESSAGES[category]
  if not pool or #pool == 0 then
    return "Message unavailable"
  end
  
  local template = pool[math.random(1, #pool)]
  
  if select("#", ...) > 0 then
    return string.format(template, ...)
  else
    return template
  end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Update menu state based on tanker availability
local function UpdateTankerMenus()
  -- Standard spawn menus removed; nothing to manage for now.
end

--- Announce tanker information to coalition
local function AnnounceTankerInfo(config, spawned)
  local msg = GetRandomMessage("SPAWN_SUCCESS", config.displayName) .. "\n"
  
  if config.tacan then
    msg = msg .. string.format("TACAN: %s\n", config.tacan)
  end
  
  if config.frequency then
    msg = msg .. string.format("Radio: %s MHz", config.frequency)
  end
  
  MESSAGE:New(msg, 20):ToBlue()
  env.info(string.format("[TANKER] %s spawned successfully", config.displayName))
end

--- Monitor tanker fuel levels
local function MonitorTankerFuel(stateKey, config)
  return function()
    local state = TANKER_STATE[stateKey]
    
    if not state.active or not state.group then
      return
    end
    
    -- Check if group still exists
    if not state.group:IsAlive() then
      return
    end
    
    local fuelPercent = state.group:GetFuel() * 100
    
    -- Bingo fuel check
    if fuelPercent <= config.fuelBingoPercent and not state.bingoWarned then
      MESSAGE:New(GetRandomMessage("BINGO_FUEL", config.displayName), 15, "WARNING"):ToBlue()
      state.bingoWarned = true
      env.info(string.format("[TANKER] %s bingo fuel: %.1f%%", config.displayName, fuelPercent))
      
    -- Low fuel warning
    elseif fuelPercent <= config.fuelWarningPercent and not state.fuelWarned then
      MESSAGE:New(GetRandomMessage("LOW_FUEL", config.displayName, math.floor(fuelPercent)), 15):ToBlue()
      state.fuelWarned = true
      env.info(string.format("[TANKER] %s low fuel warning: %.1f%%", config.displayName, fuelPercent))
    end
  end
end

--- Start (or restart) the fuel monitor scheduler for a tanker
local function StartFuelMonitor(stateKey, config)
  local state = TANKER_STATE[stateKey]
  if not state then
    return
  end

  if state.fuelMonitor then
    state.fuelMonitor:Stop()
    state.fuelMonitor = nil
  end

  state.fuelMonitor = SCHEDULER:New(
    nil,
    MonitorTankerFuel(stateKey, config),
    {},
    FUEL_CHECK_INTERVAL,
    FUEL_CHECK_INTERVAL
  )
end

--- Clean up tanker state
local function CleanupTankerState(stateKey)
  local state = TANKER_STATE[stateKey]
  
  state.active = false
  state.group = nil
  state.fuelWarned = false
  state.bingoWarned = false
  state.dcsGroupName = nil
  
  if state.fuelMonitor then
    state.fuelMonitor:Stop()
    state.fuelMonitor = nil
  end
  
  if state.respawnScheduler then
    state.respawnScheduler:Stop()
    state.respawnScheduler = nil
  end
end

-- ============================================================================
-- CUSTOM ROUTE FUNCTIONS
-- ============================================================================

--- Parse waypoint marker text for altitude and speed overrides
--- Supports formats: SHELL1, SHELL1:FL220, SHELL1:FL220:SP330, SHELL1::SP300, SHELL1:RTB
--- @param markerText string The text from the map marker
--- @param defaultAlt number Default altitude in feet
--- @param defaultSpeed number Default speed in knots
--- @return table Parsed waypoint data {altitude, speed, rtb, isValid}
local function ParseWaypointMarker(markerText, defaultAlt, defaultSpeed)
  local result = {
    altitude = defaultAlt,
    speed = defaultSpeed,
    rtb = false,
    isValid = true,
    originalText = markerText
  }
  
  -- Split by colon
  local parts = {}
  for part in string.gmatch(markerText, "[^:]+") do
    table.insert(parts, part)
  end
  
  -- Check for RTB command
  for _, part in ipairs(parts) do
    if string.upper(part) == "RTB" then
      result.rtb = true
      return result
    end
  end
  
  -- Parse FL (Flight Level)
  for _, part in ipairs(parts) do
    local fl = string.match(part, "FL(%d+)")
    if fl then
      result.altitude = tonumber(fl) * 100  -- Convert FL to feet
    end
  end
  
  -- Parse SP (Speed)
  for _, part in ipairs(parts) do
    local sp = string.match(part, "SP(%d+)")
    if sp then
      result.speed = tonumber(sp)
    end
  end
  
  return result
end

--- Scan map for waypoint markers matching callsign pattern
--- @param callsign string The callsign prefix to search for (e.g., "SHELL", "ARCO")
--- @return table Array of waypoint data sorted by sequence number
local function ScanForWaypointMarkers(callsign)
  local waypoints = {}
  local markerIds = {}
  
  -- Iterate through all possible marker IDs (DCS markers are numbered)
  -- We'll scan up to 1000 markers (should be more than enough)
  for i = 1, 1000 do
    local markerData = world.getMarkPanels()
    if markerData and markerData[i] then
      local marker = markerData[i]
      local markerText = marker.text
      
      if markerText then
        -- Check if marker matches pattern: CALLSIGN + number
        local upperText = string.upper(markerText)
        local upperCallsign = string.upper(callsign)
        local sequence = string.match(upperText, "^" .. upperCallsign .. "(%d+)")
        
        if sequence then
          local seqNum = tonumber(sequence)
          local pos = marker.pos
          
          table.insert(waypoints, {
            sequence = seqNum,
            coordinate = COORDINATE:NewFromVec3(pos),
            markerId = marker.idx,
            markerText = markerText
          })
          
          table.insert(markerIds, marker.idx)
          
          env.info(string.format("[TANKER] Found waypoint marker: %s at seq %d (ID: %d)", 
            markerText, seqNum, marker.idx))
        end
      end
    end
  end
  
  -- Sort by sequence number
  table.sort(waypoints, function(a, b) return a.sequence < b.sequence end)
  
  return waypoints, markerIds
end

-- ============================================================================

--- Spawn a tanker directly from config (no Mission Editor template required)
--- @param config table Tanker configuration
--- @param coord COORDINATE Where to spawn
--- @param heading number Initial heading in degrees
--- @return GROUP|nil The spawned tanker group wrapper
--- @return string|nil The actual DCS group name used for the spawn
local function SpawnTankerFromConfig(config, coord, heading)
  -- Generate unique identifiers to prevent registration conflicts
  local uniqueIndex = NextUniqueIndex()
  local uniqueGroupName = GenerateGroupName(config.groupName, uniqueIndex)
  local uniqueUnitName = GenerateUnitName(config.unitName, uniqueIndex)

  -- Ensure we have valid altitude (coord.y is altitude in meters MSL)
  local spawnAlt = coord.y
  env.info(string.format("[TANKER] Spawn altitude: %.1f meters (FL%03d)", spawnAlt, spawnAlt * 3.28084 / 100))

  -- Create group definition for coalition.addGroup
  local groupData = {
    visible = false,
    taskSelected = true,
    route = {
      points = {
        {
          alt = spawnAlt,
          type = "Turning Point",
          action = "Turning Point",
          alt_type = "BARO",
          speed = config.defaultSpeed * 0.514444,
          task = {
            id = "ComboTask",
            params = {
              tasks = {
                {
                  id = "Tanker",
                  params = {}
                }
              }
            }
          },
          x = coord.x,
          y = coord.z,
        }
      }
    },
    hidden = false,
    units = {
      {
        alt = spawnAlt,
        alt_type = "BARO",
        livery_id = config.livery,
        skill = "High",
        speed = config.defaultSpeed * 0.514444,
        type = config.aircraftType,
        psi = -heading,
        unitName = uniqueUnitName,
        x = coord.x,
        y = coord.z,
        heading = math.rad(heading),
        onboard_num = "010",
      },
    },
    y = coord.z,
    x = coord.x,
    name = uniqueGroupName,
    task = "Refueling",
  }

  local spawnedId = coalition.addGroup(country.id.USA, Group.Category.AIRPLANE, groupData)

  if not spawnedId then
    env.error(string.format("[TANKER] Failed to spawn %s", config.groupName))
    return nil
  end

  env.info(string.format("[TANKER] Spawned %s as %s", config.groupName, uniqueGroupName))

  local mooseGroup = GROUP:FindByName(uniqueGroupName)
  if not mooseGroup and Group and Group.getByName then
    local dcsGroup = Group.getByName(uniqueGroupName)
    if dcsGroup then
      mooseGroup = GROUP:Find(dcsGroup)
    end
  end

  if not mooseGroup then
    env.warning(string.format("[TANKER] Spawned %s but could not resolve group wrapper", uniqueGroupName))
    return nil
  end

  return mooseGroup, uniqueGroupName
end

--- Ensure default spawns immediately enter a holding pattern so they do not RTB
--- @param group GROUP The spawned tanker group
--- @param coord COORDINATE Center point for the orbit
--- @param config table Tanker configuration for speed/altitude
local function ApplyDefaultOrbitRoute(group, coord, config)
  if not group or not coord or not config then
    return
  end

  local orbitCenter = coord:SetAltitude(config.defaultAltitude * 0.3048, true)
  local orbitWP = orbitCenter:WaypointAirTurningPoint(
    COORDINATE.WaypointAltType.BARO,
    config.defaultSpeed * 0.514444,
    config.defaultAltitude * 0.3048,
    {},
    "DEFAULT-ORBIT"
  )

  orbitWP.task = {
    id = "ComboTask",
    params = {
      tasks = {
        {
          id = "Tanker",
          params = {}
        },
        {
          id = "Orbit",
          params = {
            pattern = "Circle",
            speed = config.defaultSpeed * 0.514444,
            altitude = config.defaultAltitude * 0.3048,
            point = {
              x = orbitCenter.x,
              y = orbitCenter.z
            }
          }
        }
      }
    }
  }

  group:Route({ orbitWP })
  env.info(string.format("[TANKER] Applied default orbit for %s", config.displayName))
end

--- Create custom route tanker spawn
--- @param callsign string Callsign prefix used for markers
--- @param config table Tanker configuration
--- @param stateKey string State key for tracking
--- @param isEmergency boolean Whether this is an emergency spawn
--- @return boolean Success status
local function SpawnCustomRouteTanker(callsign, config, stateKey, isEmergency)
  local state = TANKER_STATE[stateKey]
  
  -- Check if already active
  if state.active then
    MESSAGE:New(GetRandomMessage("ALREADY_ACTIVE", config.displayName), 10):ToBlue()
    return false
  end
  
  -- Scan for waypoint markers
  local waypoints, markerIds = ScanForWaypointMarkers(callsign)
  
  -- Validate waypoint count
  if #waypoints < ROUTE_CONFIG.minWaypoints then
    MESSAGE:New(GetRandomMessage("TOO_FEW_WAYPOINTS", 
      ROUTE_CONFIG.minWaypoints, callsign, callsign), 15, "ERROR"):ToBlue()
    return false
  end
  
  if #waypoints > ROUTE_CONFIG.maxWaypoints then
    MESSAGE:New(GetRandomMessage("TOO_MANY_WAYPOINTS", 
      ROUTE_CONFIG.maxWaypoints), 15, "ERROR"):ToBlue()
    return false
  end
  
  -- Build route description and validate waypoints
  local routeDesc = ""
  local routePoints = {}
  local hasRTB = false
  
  for i, wp in ipairs(waypoints) do
    local parsed = ParseWaypointMarker(wp.markerText, config.defaultAltitude, config.defaultSpeed)
    
    if parsed.rtb then
      hasRTB = true
      -- Find nearest friendly airbase from last waypoint position
      local lastPos = #routePoints > 0 and routePoints[#routePoints].coord or wp.coordinate
      local nearestAirbase = lastPos:GetClosestAirbase(Airbase.Category.AIRDROME, coalition.side.BLUE)
      
      if nearestAirbase then
        local airbaseName = nearestAirbase:GetName()
        local airbaseCoord = nearestAirbase:GetCoordinate()
        routeDesc = routeDesc .. string.format("\n  WP%d: RTB to %s", i, airbaseName)
        
        table.insert(routePoints, {
          coord = airbaseCoord,
          altitude = 0,  -- Will land
          speed = parsed.speed,
          rtb = true,
          airbase = nearestAirbase,
          airbaseName = airbaseName
        })
        
        env.info(string.format("[TANKER] RTB destination: %s", airbaseName))
      else
        routeDesc = routeDesc .. string.format("\n  WP%d: RTB (no airbase found)", i)
        env.warning("[TANKER] No friendly airbase found for RTB")
      end
      break  -- RTB is terminal command
    else
      routeDesc = routeDesc .. string.format("\n  WP%d: FL%03d @ %d kts", 
        i, math.floor(parsed.altitude / 100), parsed.speed)
      
      table.insert(routePoints, {
        coord = wp.coordinate,
        altitude = parsed.altitude,
        speed = parsed.speed,
        rtb = false
      })
    end
  end
  
  -- Confirm route to player
  local emergencyText = isEmergency and " [EMERGENCY]" or ""
  local routeMsg = GetRandomMessage("ROUTE_ACCEPTED", config.displayName, #routePoints, routeDesc)
  if isEmergency then
    routeMsg = GetRandomMessage("EMERGENCY_SPAWN", config.displayName) .. "\n" .. routeMsg
  end
  MESSAGE:New(routeMsg, 20):ToBlue()
  
  env.info(string.format("[TANKER] Spawning %s with custom route: %d waypoints", 
    config.displayName, #routePoints))
  
  -- Debug: log route point data
  for i, rp in ipairs(routePoints) do
    env.info(string.format("[TANKER] RoutePoint %d: coord=%s, alt=%.0f, spd=%.0f, rtb=%s",
      i, tostring(rp.coord), rp.altitude, rp.speed, tostring(rp.rtb)))
  end
  
  -- Delete markers if configured
  if ROUTE_CONFIG.deleteMarkersAfterUse then
    for _, markerId in ipairs(markerIds) do
      trigger.action.removeMark(markerId)
    end
    env.info(string.format("[TANKER] Deleted %d waypoint markers", #markerIds))
  end
  
  -- Spawn tanker with custom route
  -- Calculate initial heading
  local headingCoord
  if routePoints[2] and routePoints[2].coord then
    headingCoord = routePoints[2].coord
  else
    headingCoord = routePoints[1].coord
  end
  
  local initialHeading = routePoints[1].coord:HeadingTo(headingCoord)
  
  -- Set the spawn coordinate with correct altitude (convert feet to meters)
  local spawnCoord = routePoints[1].coord:SetAltitude(routePoints[1].altitude * 0.3048)
  
  local spawnedGroup, spawnedName = SpawnTankerFromConfig(
    config,
    spawnCoord,
    initialHeading
  )
  
  if not spawnedGroup then
    MESSAGE:New(GetRandomMessage("SPAWN_FAILURE", config.displayName), 10, "ERROR"):ToBlue()
    return false
  end
  
  -- Route the group through all waypoints
  local taskRoute = {}
  for i, rp in ipairs(routePoints) do
    local wp
    
    -- RTB waypoint - land at airbase
    if rp.rtb and rp.airbase then
      wp = rp.coord:WaypointAirLanding(
        rp.speed * 0.514444,
        rp.airbase:GetDCSObject(),
        {},
        "RTB"
      )
    else
      -- Normal waypoint
      wp = rp.coord:WaypointAirFlyOverPoint(
        COORDINATE.WaypointAltType.BARO,
        rp.speed * 0.514444,  -- Convert knots to m/s
        rp.altitude * 0.3048,  -- Convert feet to meters
        {},
        "WP" .. i
      )
      
      -- Add tanker task to all waypoints
      wp.task = {
        id = "ComboTask",
        params = {
          tasks = {
            {
              id = "Tanker",
              params = {}
            }
          }
        }
      }
    end
    
    table.insert(taskRoute, wp)
  end
  
  -- If last waypoint is not RTB, loop back to first waypoint to create continuous patrol
  if not hasRTB and #routePoints > 1 then
    local firstPoint = routePoints[1]
    local loopWP = firstPoint.coord:WaypointAirFlyOverPoint(
      COORDINATE.WaypointAltType.BARO,
      firstPoint.speed * 0.514444,
      firstPoint.altitude * 0.3048,
      {},
      "LOOP-WP1"
    )
    
    -- Add tanker task to loop waypoint
    loopWP.task = {
      id = "ComboTask",
      params = {
        tasks = {
          {
            id = "Tanker",
            params = {}
          }
        }
      }
    }
    
    table.insert(taskRoute, loopWP)
    env.info(string.format("[TANKER] Added loop waypoint back to WP1 for continuous patrol"))
  elseif not hasRTB and #routePoints == 1 then
    -- Single waypoint - add circular orbit pattern
    local singlePoint = routePoints[1]
    local orbitWP = singlePoint.coord:WaypointAirTurningPoint(
      COORDINATE.WaypointAltType.BARO,
      singlePoint.speed * 0.514444,
      singlePoint.altitude * 0.3048,
      {},
      "ORBIT"
    )
    orbitWP.task = {
      id = "ComboTask",
      params = {
        tasks = {
          {
            id = "Tanker",
            params = {}
          },
          {
            id = "Orbit",
            params = {
              pattern = "Circle",
              speed = singlePoint.speed * 0.514444,
              altitude = singlePoint.altitude * 0.3048
            }
          }
        }
      }
    }
    table.insert(taskRoute, orbitWP)
    env.info(string.format("[TANKER] Single waypoint - added circular orbit pattern"))
  end
  
  -- Apply route to group
  spawnedGroup:Route(taskRoute)
  
  -- Update state
  local state = TANKER_STATE[stateKey]
  state.active = true
  state.group = spawnedGroup
  state.fuelWarned = false
  state.bingoWarned = false
  state.dcsGroupName = spawnedName or (spawnedGroup.GetName and spawnedGroup:GetName()) or config.groupName
  
  -- Announce spawn with details
  AnnounceTankerInfo(config, true)
  
  -- Start fuel monitoring
  StartFuelMonitor(stateKey, config)
  
  -- Update menus
  UpdateTankerMenus()
  
  return true
end

-- ============================================================================
-- EVENT HANDLER
-- ============================================================================

BlueTankerEventHandler = EVENTHANDLER:New()

function BlueTankerEventHandler:OnEventBirth(EventData)
  local groupName = EventData.IniDCSGroupName
  
  if groupName and string.find(groupName, "TANKER 135") then
    env.info(string.format("[TANKER] Birth event: %s", groupName))
    
    -- Determine which tanker spawned
    local stateKey, config
    if string.find(groupName, "MPRS") then
      stateKey = "KC135_MPRS"
      config = TANKER_CONFIG.KC135_MPRS
    else
      stateKey = "KC135"
      config = TANKER_CONFIG.KC135
    end
    
    -- Update state
    local state = TANKER_STATE[stateKey]
    state.active = true
    state.group = GROUP:FindByName(groupName)
    state.dcsGroupName = groupName
    state.fuelWarned = false
    state.bingoWarned = false
    
    -- Announce spawn with details
    AnnounceTankerInfo(config, true)
    
    -- Start fuel monitoring
    StartFuelMonitor(stateKey, config)
    
    -- Update menus
    UpdateTankerMenus()
  end
end

function BlueTankerEventHandler:OnEventDead(EventData)
  local groupName = EventData.IniDCSGroupName
  
  if groupName and string.find(groupName, "TANKER 135") then
    env.info(string.format("[TANKER] Dead event: %s", groupName))
    
    -- Determine which tanker died
    local stateKey, config
    if string.find(groupName, "MPRS") then
      stateKey = "KC135_MPRS"
      config = TANKER_CONFIG.KC135_MPRS
    else
      stateKey = "KC135"
      config = TANKER_CONFIG.KC135
    end
    
    MESSAGE:New(GetRandomMessage("DESTROYED", config.displayName), 
      15, "ALERT"):ToBlue()
    
    -- Clean up state
    CleanupTankerState(stateKey)
    
    -- Update menus
    UpdateTankerMenus()
  end
end

function BlueTankerEventHandler:OnEventCrash(EventData)
  -- Treat crash same as dead
  self:OnEventDead(EventData)
end

function BlueTankerEventHandler:OnEventEngineShutdown(EventData)
  local groupName = EventData.IniDCSGroupName
  
  if groupName and string.find(groupName, "TANKER 135") then
    env.info(string.format("[TANKER] Engine shutdown event: %s", groupName))
    
    -- Determine which tanker
    local stateKey, config
    if string.find(groupName, "MPRS") then
      stateKey = "KC135_MPRS"
      config = TANKER_CONFIG.KC135_MPRS
    else
      stateKey = "KC135"
      config = TANKER_CONFIG.KC135
    end
    
    MESSAGE:New(string.format("%s has returned to base", config.displayName), 
      10):ToBlue()
    
    -- Clean up state
    CleanupTankerState(stateKey)
    
    -- Update menus
    UpdateTankerMenus()
  end
end

function BlueTankerEventHandler:OnEventHit(EventData)
  local groupName = EventData.IniDCSGroupName
  
  if groupName and string.find(groupName, "TANKER 135") then
    local config = string.find(groupName, "MPRS") and TANKER_CONFIG.KC135_MPRS or TANKER_CONFIG.KC135
    
    MESSAGE:New(GetRandomMessage("TAKING_FIRE", config.displayName), 
      15, "WARNING"):ToBlue()
    
    env.info(string.format("[TANKER] %s hit by hostile fire", config.displayName))
  end
end

-- ============================================================================
-- SPAWN OBJECTS AND FUNCTIONS
-- ============================================================================

-- Function to spawn KC-135 with custom route
function SpawnCustomTanker()
  SpawnCustomRouteTanker(
    TANKER_CONFIG.KC135.callsign,
    TANKER_CONFIG.KC135,
    "KC135",
    false
  )
end

-- Function to spawn KC-135 MPRS with custom route
function SpawnCustomTankerMPRS()
  SpawnCustomRouteTanker(
    TANKER_CONFIG.KC135_MPRS.callsign,
    TANKER_CONFIG.KC135_MPRS,
    "KC135_MPRS",
    false
  )
end

-- Function to spawn emergency KC-135 with custom route
function SpawnEmergencyTanker()
  -- Use emergency respawn delay
  local originalDelay = TANKER_CONFIG.KC135.respawnDelay
  TANKER_CONFIG.KC135.respawnDelay = TANKER_CONFIG.KC135.emergencyRespawnDelay
  
  local success = SpawnCustomRouteTanker(
    TANKER_CONFIG.KC135.callsign,
    TANKER_CONFIG.KC135,
    "KC135",
    true
  )
  
  -- Restore original delay
  TANKER_CONFIG.KC135.respawnDelay = originalDelay
  
  return success
end

-- Function to spawn emergency KC-135 MPRS with custom route
function SpawnEmergencyTankerMPRS()
  local originalDelay = TANKER_CONFIG.KC135_MPRS.respawnDelay
  TANKER_CONFIG.KC135_MPRS.respawnDelay = TANKER_CONFIG.KC135_MPRS.emergencyRespawnDelay
  
  local success = SpawnCustomRouteTanker(
    TANKER_CONFIG.KC135_MPRS.callsign,
    TANKER_CONFIG.KC135_MPRS,
    "KC135_MPRS",
    true
  )
  
  TANKER_CONFIG.KC135_MPRS.respawnDelay = originalDelay
  
  return success
end

-- Function to display tanker status
function ShowTankerStatus()
  local msg = "=== TANKER STATUS ===\n\n"
  
  -- KC-135 Status
  local kc135State = TANKER_STATE.KC135
  if kc135State.active and kc135State.group and kc135State.group:IsAlive() then
    local fuel = kc135State.group:GetFuel() * 100
    local coord = kc135State.group:GetCoordinate()
    local alt = coord:GetLandHeight() + coord.y
    msg = msg .. string.format("%s: ACTIVE\n", TANKER_CONFIG.KC135.displayName)
    msg = msg .. string.format("  Fuel: %.0f%%\n", fuel)
    msg = msg .. string.format("  Altitude: FL%03d\n", math.floor(alt * 3.28084 / 100))
    if TANKER_CONFIG.KC135.tacan then
      msg = msg .. string.format("  TACAN: %s\n", TANKER_CONFIG.KC135.tacan)
    end
    if TANKER_CONFIG.KC135.frequency then
      msg = msg .. string.format("  Radio: %s MHz\n", TANKER_CONFIG.KC135.frequency)
    end
  else
    msg = msg .. string.format("%s: NOT ACTIVE\n", TANKER_CONFIG.KC135.displayName)
  end
  
  msg = msg .. "\n"
  
  -- KC-135 MPRS Status
  local mprsState = TANKER_STATE.KC135_MPRS
  if mprsState.active and mprsState.group and mprsState.group:IsAlive() then
    local fuel = mprsState.group:GetFuel() * 100
    local coord = mprsState.group:GetCoordinate()
    local alt = coord:GetLandHeight() + coord.y
    msg = msg .. string.format("%s: ACTIVE\n", TANKER_CONFIG.KC135_MPRS.displayName)
    msg = msg .. string.format("  Fuel: %.0f%%\n", fuel)
    msg = msg .. string.format("  Altitude: FL%03d\n", math.floor(alt * 3.28084 / 100))
    if TANKER_CONFIG.KC135_MPRS.tacan then
      msg = msg .. string.format("  TACAN: %s\n", TANKER_CONFIG.KC135_MPRS.tacan)
    end
    if TANKER_CONFIG.KC135_MPRS.frequency then
      msg = msg .. string.format("  Radio: %s MHz\n", TANKER_CONFIG.KC135_MPRS.frequency)
    end
  else
    msg = msg .. string.format("%s: NOT ACTIVE\n", TANKER_CONFIG.KC135_MPRS.displayName)
  end
  
  MESSAGE:New(msg, 25):ToBlue()
end

-- Function to show custom route help
function ShowCustomRouteHelp()
  local msg = "╔════════════════════════════════════════════╗\n"
  msg = msg .. "║     TANKER MANAGEMENT SYSTEM - GUIDE      ║\n"
  msg = msg .. "╚════════════════════════════════════════════╝\n\n"
  
  msg = msg .. "━━━ QUICK START ━━━\n\n"
  msg = msg .. "1. SIMPLE SPAWN:\n"
  msg = msg .. "   • F10 → Tanker Management → Launch KC-135\n"
  msg = msg .. "   • Tanker spawns at default location (FL220)\n"
  msg = msg .. "   • Automatically orbits and provides refueling\n\n"
  
  msg = msg .. "2. CUSTOM ROUTE SPAWN:\n"
  msg = msg .. "   • Place numbered F10 map markers\n"
  msg = msg .. "   • Launch from Custom Route menu\n"
  msg = msg .. "   • Tanker follows your waypoints\n\n"
  
  msg = msg .. "━━━ AVAILABLE TANKERS ━━━\n\n"
  msg = msg .. string.format("• %s (SHELL)\n", TANKER_CONFIG.KC135.displayName)
  msg = msg .. string.format("  TACAN: %s | Radio: %s MHz\n", 
    TANKER_CONFIG.KC135.tacan or "N/A", TANKER_CONFIG.KC135.frequency or "N/A")
  msg = msg .. string.format("  Marker Prefix: %s\n\n", TANKER_CONFIG.KC135.callsign)
  
  msg = msg .. string.format("• %s (ARCO)\n", TANKER_CONFIG.KC135_MPRS.displayName)
  msg = msg .. string.format("  TACAN: %s | Radio: %s MHz\n", 
    TANKER_CONFIG.KC135_MPRS.tacan or "N/A", TANKER_CONFIG.KC135_MPRS.frequency or "N/A")
  msg = msg .. string.format("  Marker Prefix: %s\n\n", TANKER_CONFIG.KC135_MPRS.callsign)
  
  msg = msg .. "━━━ CUSTOM ROUTE MARKERS ━━━\n\n"
  msg = msg .. "BASIC USAGE:\n"
  msg = msg .. "  Place markers in sequence: SHELL1, SHELL2, SHELL3\n"
  msg = msg .. "  Minimum 2 waypoints required\n"
  msg = msg .. "  Defaults: FL220 @ 330 knots\n\n"
  
  msg = msg .. "ADVANCED SYNTAX:\n"
  msg = msg .. "  SHELL1:FL180         → Altitude override\n"
  msg = msg .. "  SHELL2::SP300        → Speed override\n"
  msg = msg .. "  SHELL3:FL200:SP280   → Both overrides\n"
  msg = msg .. "  SHELL4:RTB           → Return to nearest base\n\n"
  
  msg = msg .. "EXAMPLES:\n"
  msg = msg .. "  Simple 3-point orbit:\n"
  msg = msg .. "    ARCO1, ARCO2, ARCO3\n\n"
  msg = msg .. "  High altitude route with RTB:\n"
  msg = msg .. "    SHELL1:FL280, SHELL2:FL280, SHELL3:RTB\n\n"
  msg = msg .. "  Low-level tanker track:\n"
  msg = msg .. "    ARCO1:FL120:SP250, ARCO2:FL120:SP250\n\n"
  
  msg = msg .. "━━━ REROUTING ACTIVE TANKERS ━━━\n\n"
  msg = msg .. "Change an active tanker's route mid-mission:\n"
  msg = msg .. "  1. Place new waypoint markers\n"
  msg = msg .. "  2. F10 → Custom Route → Reroute Active Tanker\n"
  msg = msg .. "  3. Tanker immediately follows new route\n\n"
  
  msg = msg .. "Use cases:\n"
  msg = msg .. "  • Reposition for different theater\n"
  msg = msg .. "  • Avoid threat areas\n"
  msg = msg .. "  • Send tanker home (use :RTB)\n\n"
  
  msg = msg .. "━━━ NOTES ━━━\n\n"
  msg = msg .. "• Markers are auto-deleted after use\n"
  msg = msg .. "• Tankers auto-respawn after 3 minutes if lost\n"
  msg = msg .. "• Use Emergency Tanker for 1-minute respawn\n"
  msg = msg .. "• RTB finds nearest friendly airbase & lands\n"
  msg = msg .. "• Check Tanker Status for current position/fuel\n"
  
  MESSAGE:New(msg, 45):ToBlue()
end

-- Function to reroute an active tanker with new waypoints
function RerouteTanker()
  if not TANKER_STATE.KC135.active or not TANKER_STATE.KC135.group then
    MESSAGE:New("KC-135 is not active! Spawn it first.", 10):ToBlue()
    return
  end
  
  -- Scan for waypoint markers
  local waypoints, markerIds = ScanForWaypointMarkers(TANKER_CONFIG.KC135.callsign)
  
  if #waypoints < ROUTE_CONFIG.minWaypoints then
    MESSAGE:New(string.format("Reroute requires at least %d waypoints!\nPlace markers: %s1, %s2, etc.", 
      ROUTE_CONFIG.minWaypoints, TANKER_CONFIG.KC135.callsign, TANKER_CONFIG.KC135.callsign), 15, "ERROR"):ToBlue()
    return
  end
  
  -- Build new route
  local routePoints = {}
  local routeDesc = ""
  local hasRTB = false
  
  for i, wp in ipairs(waypoints) do
    local parsed = ParseWaypointMarker(wp.markerText, TANKER_CONFIG.KC135.defaultAltitude, TANKER_CONFIG.KC135.defaultSpeed)
    
    if parsed.rtb then
      hasRTB = true
      local lastPos = #routePoints > 0 and routePoints[#routePoints].coord or TANKER_STATE.KC135.group:GetCoordinate()
      local nearestAirbase = lastPos:GetClosestAirbase(Airbase.Category.AIRDROME, coalition.side.BLUE)
      
      if nearestAirbase then
        local airbaseName = nearestAirbase:GetName()
        local airbaseCoord = nearestAirbase:GetCoordinate()
        routeDesc = routeDesc .. string.format("\n  WP%d: RTB to %s", i, airbaseName)
        
        table.insert(routePoints, {
          coord = airbaseCoord,
          altitude = 0,
          speed = parsed.speed,
          rtb = true,
          airbase = nearestAirbase,
          airbaseName = airbaseName
        })
      end
      break
    else
      routeDesc = routeDesc .. string.format("\n  WP%d: FL%03d @ %d kts", 
        i, math.floor(parsed.altitude / 100), parsed.speed)
      table.insert(routePoints, {
        coord = wp.coordinate,
        altitude = parsed.altitude,
        speed = parsed.speed,
        rtb = false
      })
    end
  end
  
  -- Build task route
  local taskRoute = {}
  for i, rp in ipairs(routePoints) do
    local wp
    
    if rp.rtb and rp.airbase then
      wp = rp.coord:WaypointAirLanding(
        rp.speed * 0.514444,
        rp.airbase:GetDCSObject(),
        {},
        "RTB"
      )
    else
      wp = rp.coord:WaypointAirFlyOverPoint(
        COORDINATE.WaypointAltType.BARO,
        rp.speed * 0.514444,
        rp.altitude * 0.3048,
        {},
        "WP" .. i
      )
      
      if not rp.rtb then
        wp.task = {
          id = "ComboTask",
          params = {
            tasks = {
              {id = "Tanker", params = {}}
            }
          }
        }
      end
    end
    
    table.insert(taskRoute, wp)
  end
  
  -- Apply new route
  TANKER_STATE.KC135.group:Route(taskRoute)
  
  MESSAGE:New(string.format("%s accepting new route with %d waypoints:%s", 
    TANKER_CONFIG.KC135.displayName, #routePoints, routeDesc), 20):ToBlue()
  
  -- Delete markers
  if ROUTE_CONFIG.deleteMarkersAfterUse then
    for _, markerId in ipairs(markerIds) do
      trigger.action.removeMark(markerId)
    end
  end
  
  env.info(string.format("[TANKER] Rerouted %s with %d waypoints", TANKER_CONFIG.KC135.displayName, #routePoints))
end

-- Function to reroute KC-135 MPRS
function RerouteTankerMPRS()
  if not TANKER_STATE.KC135_MPRS.active or not TANKER_STATE.KC135_MPRS.group then
    MESSAGE:New("KC-135 MPRS is not active! Spawn it first.", 10):ToBlue()
    return
  end
  
  local waypoints, markerIds = ScanForWaypointMarkers(TANKER_CONFIG.KC135_MPRS.callsign)
  
  if #waypoints < ROUTE_CONFIG.minWaypoints then
    MESSAGE:New(string.format("Reroute requires at least %d waypoints!\nPlace markers: %s1, %s2, etc.", 
      ROUTE_CONFIG.minWaypoints, TANKER_CONFIG.KC135_MPRS.callsign, TANKER_CONFIG.KC135_MPRS.callsign), 15, "ERROR"):ToBlue()
    return
  end
  
  local routePoints = {}
  local routeDesc = ""
  local hasRTB = false
  
  for i, wp in ipairs(waypoints) do
    local parsed = ParseWaypointMarker(wp.markerText, TANKER_CONFIG.KC135_MPRS.defaultAltitude, TANKER_CONFIG.KC135_MPRS.defaultSpeed)
    
    if parsed.rtb then
      hasRTB = true
      local lastPos = #routePoints > 0 and routePoints[#routePoints].coord or TANKER_STATE.KC135_MPRS.group:GetCoordinate()
      local nearestAirbase = lastPos:GetClosestAirbase(Airbase.Category.AIRDROME, coalition.side.BLUE)
      
      if nearestAirbase then
        local airbaseName = nearestAirbase:GetName()
        local airbaseCoord = nearestAirbase:GetCoordinate()
        routeDesc = routeDesc .. string.format("\n  WP%d: RTB to %s", i, airbaseName)
        
        table.insert(routePoints, {
          coord = airbaseCoord,
          altitude = 0,
          speed = parsed.speed,
          rtb = true,
          airbase = nearestAirbase,
          airbaseName = airbaseName
        })
      end
      break
    else
      routeDesc = routeDesc .. string.format("\n  WP%d: FL%03d @ %d kts", 
        i, math.floor(parsed.altitude / 100), parsed.speed)
      table.insert(routePoints, {
        coord = wp.coordinate,
        altitude = parsed.altitude,
        speed = parsed.speed,
        rtb = false
      })
    end
  end
  
  local taskRoute = {}
  for i, rp in ipairs(routePoints) do
    local wp
    
    if rp.rtb and rp.airbase then
      wp = rp.coord:WaypointAirLanding(
        rp.speed * 0.514444,
        rp.airbase:GetDCSObject(),
        {},
        "RTB"
      )
    else
      wp = rp.coord:WaypointAirFlyOverPoint(
        COORDINATE.WaypointAltType.BARO,
        rp.speed * 0.514444,
        rp.altitude * 0.3048,
        {},
        "WP" .. i
      )
      
      if not rp.rtb then
        wp.task = {
          id = "ComboTask",
          params = {
            tasks = {
              {id = "Tanker", params = {}}
            }
          }
        }
      end
    end
    
    table.insert(taskRoute, wp)
  end
  
  TANKER_STATE.KC135_MPRS.group:Route(taskRoute)
  
  MESSAGE:New(string.format("%s accepting new route with %d waypoints:%s", 
    TANKER_CONFIG.KC135_MPRS.displayName, #routePoints, routeDesc), 20):ToBlue()
  
  if ROUTE_CONFIG.deleteMarkersAfterUse then
    for _, markerId in ipairs(markerIds) do
      trigger.action.removeMark(markerId)
    end
  end
  
  env.info(string.format("[TANKER] Rerouted %s with %d waypoints", TANKER_CONFIG.KC135_MPRS.displayName, #routePoints))
end

-- ============================================================================
-- MISSION MENU SETUP
-- ============================================================================

-- Create mission menu for tanker requests
-- Integrates with MenuManager to place under "Mission Options"
-- This keeps CTLD at F2 and AFAC at F3 as intended
if MenuManager and MenuManager.CreateCoalitionMenu then
  -- Use MenuManager to create menu under "Mission Options"
  MENU_TANKER_ROOT = MenuManager.CreateCoalitionMenu(coalition.side.BLUE, "Tanker Operations")
  env.info("[TANKER] Using MenuManager - menu created under Mission Options")
else
  -- Fallback: create root menu if MenuManager not available
  MENU_TANKER_ROOT = MENU_COALITION:New(coalition.side.BLUE, "Tanker Operations")
  env.warning("[TANKER] MenuManager not found - creating root menu (load MenuManager first!)")
end

-- Custom route submenu
local MENU_CUSTOM_ROUTE = MENU_COALITION:New(
  coalition.side.BLUE,
  "Custom Route",
  MENU_TANKER_ROOT
)

MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  "How to Use Custom Routes",
  MENU_CUSTOM_ROUTE,
  ShowCustomRouteHelp
)

MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  string.format("Launch %s (%s markers)", TANKER_CONFIG.KC135.displayName, TANKER_CONFIG.KC135.callsign),
  MENU_CUSTOM_ROUTE,
  SpawnCustomTanker
)

MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  string.format("Launch %s (%s markers)", TANKER_CONFIG.KC135_MPRS.displayName, TANKER_CONFIG.KC135_MPRS.callsign),
  MENU_CUSTOM_ROUTE,
  SpawnCustomTankerMPRS
)

-- Reroute submenu for changing active tanker routes
local MENU_REROUTE = MENU_COALITION:New(
  coalition.side.BLUE,
  "Reroute Active Tanker",
  MENU_CUSTOM_ROUTE
)

MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  string.format("Reroute %s (%s markers)", TANKER_CONFIG.KC135.displayName, TANKER_CONFIG.KC135.callsign),
  MENU_REROUTE,
  RerouteTanker
)

MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  string.format("Reroute %s (%s markers)", TANKER_CONFIG.KC135_MPRS.displayName, TANKER_CONFIG.KC135_MPRS.callsign),
  MENU_REROUTE,
  RerouteTankerMPRS
)

-- Emergency spawns submenu
local MENU_EMERGENCY = MENU_COALITION:New(
  coalition.side.BLUE,
  "Emergency Tanker",
  MENU_TANKER_ROOT
)

MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  string.format("Emergency %s (%s markers)", TANKER_CONFIG.KC135.displayName, TANKER_CONFIG.KC135.callsign),
  MENU_EMERGENCY,
  SpawnEmergencyTanker
)

MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  string.format("Emergency %s (%s markers)", TANKER_CONFIG.KC135_MPRS.displayName, TANKER_CONFIG.KC135_MPRS.callsign),
  MENU_EMERGENCY,
  SpawnEmergencyTankerMPRS
)

-- Status and info
MENU_COALITION_COMMAND:New(
  coalition.side.BLUE,
  "Tanker Status Report",
  MENU_TANKER_ROOT,
  ShowTankerStatus
)

-- ============================================================================
-- EVENT HANDLER REGISTRATION
-- ============================================================================

BlueTankerEventHandler:HandleEvent(EVENTS.Birth)
BlueTankerEventHandler:HandleEvent(EVENTS.Dead)
BlueTankerEventHandler:HandleEvent(EVENTS.Crash)
BlueTankerEventHandler:HandleEvent(EVENTS.EngineShutdown)
BlueTankerEventHandler:HandleEvent(EVENTS.Hit)

env.info("[TANKER] Tanker Management System initialized")
MESSAGE:New("Tanker Management System online - Use F10 menu to request tankers", 15):ToBlue()