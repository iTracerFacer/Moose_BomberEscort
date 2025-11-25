--- MOOSE Bomber Escort System
-- A comprehensive player-escort AI bomber mission system
-- Players use F10 map markers to create bomber missions, then escort them to targets
-- Bombers exhibit intelligent behavior based on escort presence and threats
--
-- @module BOMBER_ESCORT
-- @author F99th-TracerFacer
-- @copyright 2025

-- Global spawn counter to ensure unique MOOSE spawn indices
if not _BOMBER_GLOBAL_SPAWN_COUNTER then
  _BOMBER_GLOBAL_SPAWN_COUNTER = 0
end

-- Global SPAWN objects per template (reused to prevent conflicts)
if not _BOMBER_SPAWN_OBJECTS then
  _BOMBER_SPAWN_OBJECTS = {}
end

--Naming Convention:
--
--B-17G -> Template name: BOMBER_B17G
--B-52H -> Template name: BOMBER_B52H
--B-1B -> Template name: BOMBER_B1B
--Tu-95MS -> Template name: BOMBER_TU95
--Tu-22M3 -> Template name: BOMBER_TU22
--B-24J -> Template name: BOMBER_B24J

---
-- CONFIGURATION
-- Customize these settings to adjust system behavior
---
BOMBER_ESCORT_CONFIG = {
  -- Message Settings
  MessageDuration = 30,                -- Seconds messages display (default: 15)
  ShowDetailedLogs = true,             -- Show detailed state change messages to players (default: true)
  
  -- Marker System
  AllowAirSpawnFallback = false,       -- Allow bombers to spawn in air if not on airbase (default: false)
  DeleteMarkersAfterUse = true,        -- Auto-remove markers after mission starts (default: true)
  MarkerCheckInterval = 2,             -- Seconds between marker scans (default: 2)
  
  -- Escort Requirements
  RequireEscort = true,                -- Bombers require player escort to proceed with mission (default: true, set false to allow solo bomber missions)
  EscortTimeBeforeAbort = 120,         -- Seconds without escort before abort (default: 120)
  EscortWarningTime = 30,              -- Seconds before warning about missing escort (default: 30)
  
  -- Escort Classification Thresholds
  EscortCloseRange = 5000,             -- Meters - Definite escort range (default: 1km)
  EscortMediumRange = 10000,            -- Meters - Probable escort range (default: 5km)
  EscortMaxRange = 20000,              -- Meters - Maximum detection range (default: 20km)
  EscortFormationRange = 250,          -- Meters - Tight formation range for compliments (default: 250m)
  EscortHeadingTolerance = 45,         -- Degrees - Max heading difference for confirmed escort (default: 45°)
  EscortAltitudeTolerance = 5000,      -- Feet - Max altitude difference for confirmed escort (default: 5000ft)
  EscortVelocityTolerance = 100,       -- Knots - Max speed difference for confirmed escort (default: 100kts)
  EscortHistoryDuration = 30,          -- Seconds - Track escort position/heading history (default: 30s)
  EscortFormationComplimentInterval = 180, -- Seconds between formation flying compliments (default: 180s = 3 minutes)
  
  -- Threat Detection
  SAMThreatDistance = 50000,           -- Meters - SAM detection range (default: 50km - extended for strategic awareness)
  FighterThreatDistance = 75000,       -- Meters - Fighter detection range (default: 75km - extended for escort positioning time)
  ThreatCheckInterval = 10,            -- Seconds between threat scans (default: 10)
  
  -- SAM Warning System
  SAMProgressiveWarnings = {50000, 40000, 30000, 20000}, -- Meters - Range thresholds for progressive warnings
  SAMStatusSummaryInterval = 80,       -- Seconds between SAM status summary messages (default: 80s = 1:20)
  SAMAutoCountermeasureRange = 30000,  -- Meters - Auto-deploy countermeasures inside this range (default: 30km)
  
  -- SAM Avoidance and Dynamic Routing
  EnableSAMAvoidance = true,           -- Enable dynamic SAM avoidance routing (default: true)
  SAMAvoidanceBuffer = 15000,          -- Meters - Stay this far outside SAM max range (default: 15km buffer)
  SAMCorridorMinWidth = 10000,         -- Meters - Minimum safe corridor width between SAMs (default: 10km)
  SAMAvoidOnlyIfCanEngage = true,      -- Only avoid SAMs that can engage at current altitude (default: true)
  SAMMaxDetourPercent = 50,            -- Max detour as % of direct distance (100km direct = max 150km detour)
  SAMMaxDetourAbsolute = 100000,       -- Meters - Absolute max detour distance regardless of percent (default: 100km)
  SAMRerouteCheckInterval = 15,        -- Seconds between route threat checks during flight (default: 15s)
  SAMFuelReservePercent = 20,          -- Percent fuel reserve required for detours (default: 20%)
  
  -- Dynamic Threat Assessment
  EnableThreatAssessment = true,       -- Enable dynamic threat-to-escort ratio checking (default: true)
  RequireEscortParity = true,          -- Require at least 1 escort per detected fighter (default: true)
  ThreatToleranceWithoutEscort = 0,    -- Max fighters tolerated with no escort (0 = abort on any fighter) (default: 0)
  ThreatToleranceWithEscort = 999,     -- Max fighters tolerated when escort parity is met (999 = no limit) (default: 999)
  ThreatAbortGracePeriod = 120,        -- Seconds to allow outnumbered situation before aborting (gives escorts time to reposition) (default: 120)
  ThreatWarningInterval = 30,          -- Seconds between threat warning messages during grace period (default: 30)
  
  -- Runway Attack Settings
  RunwayDetectionRadius = 500,        -- Meters - Auto-detect runway if target within this distance of airbase (default: 3km)
  RunwayApproachDistance = 40000,      -- Meters - IP distance for runway attacks (default: 40km)
  
  -- Default Mission Parameters (used when not specified in markers)
  DefaultAltitude = 25000,             -- Feet (default: 25000)
  DefaultSpeed = 450,                  -- Knots (default: 350)

  -- RTB/Landing Recovery Fallbacks
  RTBLandingStuckDistance = 8000,      -- Meters - consider the landing leg "stuck" if farther than this from runway on final WP
  RTBLandingStuckTime = 90,            -- Seconds - time allowed to loiter on the landing leg before forcing a land task
  RTBLandingSnapshotInterval = 15,     -- Seconds - minimum interval between repeated landing debug snapshots (set lower for more spam)
  RTBLandingDespawnDelaySeconds = 60, -- Optional - auto-despawn bomber this many seconds after a landing fallback if it still hasn't landed 
}

---
-- BOMBER_MARKER - Map marker parser for mission creation
-- Uses numbered waypoint system matching tanker script pattern
-- @type BOMBER_MARKER
BOMBER_MARKER = {
  ClassName = "BOMBER_MARKER"
}

--- Marker configuration
BOMBER_MARKER.Config = {
  waypointPrefix = "BOMBER",        -- Waypoint marker prefix (BOMBER1, BOMBER2, etc.)
  targetPrefix = "TARGET",          -- Target marker prefix (TARGET1)
  respawnPrefix = "RESPAWN",        -- Respawn marker prefix (RESPAWN1)
  egressPrefix = "EGRESS",          -- Egress waypoint prefix (EGRESS1, EGRESS2, etc.)
  rtbPrefix = "RTB",                -- RTB marker prefix (RTB1)
  deleteMarkersAfterUse = BOMBER_ESCORT_CONFIG.DeleteMarkersAfterUse,
  minWaypoints = 1,                 -- Minimum waypoints (BOMBER1 is required)
  maxWaypoints = 10,                -- Maximum route waypoints
  checkInterval = BOMBER_ESCORT_CONFIG.MarkerCheckInterval,
  AllowAirSpawnFallback = BOMBER_ESCORT_CONFIG.AllowAirSpawnFallback,
}

---
-- BOMBER_PROFILE - Aircraft type definitions with characteristics
-- @type BOMBER_PROFILE
BOMBER_PROFILE = {
  ClassName = "BOMBER_PROFILE"
}

--- Bomber aircraft profiles database
-- Each profile defines behavioral and performance characteristics
BOMBER_PROFILE.DB = {
  
  -- WWII Heavy Bombers
  ["B-17G"] = {
    Type = "B-17G",
    DisplayName = "B-17G Flying Fortress",
    Category = "WWII",
    CruiseSpeed = 180, -- knots
    MaxSpeed = 220,
    MinSpeed = 140,
    CruiseAlt = 20000, -- feet
    MaxAlt = 28000,
    MinAlt = 5000,
    DefaultFlightSize = 4, -- Default number of aircraft if not specified
    HasDefensiveGuns = true,
    FormationTight = true, -- Prefers tight formations
    EvasionCapability = "Low", -- Poor, Low, Medium, High
    EscortRequired = BOMBER_ESCORT_CONFIG.RequireEscort,  -- Use global config by default
    MinEscorts = 1,  -- Minimum escort fighters required
    MaxEscortDistance = 8000, -- meters
    ThreatTolerance = "Medium", -- Low, Medium, High (how long they'll stay under threat)
  },
  
  ["B-24J"] = {
    Type = "B-24",
    DisplayName = "B-24 Liberator",
    Category = "WWII",
    CruiseSpeed = 175,
    MaxSpeed = 210,
    MinSpeed = 135,
    CruiseAlt = 18000,
    MaxAlt = 26000,
    MinAlt = 5000,
    DefaultFlightSize = 4,
    HasDefensiveGuns = true,
    FormationTight = true,
    EvasionCapability = "Low",
    EscortRequired = BOMBER_ESCORT_CONFIG.RequireEscort,
    MinEscorts = 1,  -- Minimum escort fighters required
    MaxEscortDistance = 8000,
    ThreatTolerance = "Medium",
  },
  
  -- Cold War Era
  ["B-52H"] = {
    Type = "B-52H",
    DisplayName = "B-52H Stratofortress",
    Category = "Cold War",
    CruiseSpeed = 400,
    MaxSpeed = 500,
    MinSpeed = 280,
    CruiseAlt = 35000,
    MaxAlt = 45000,
    MinAlt = 10000,
    DefaultFlightSize = 1, -- Usually operate solo or pairs
    HasDefensiveGuns = false,
    FormationTight = false,
    EvasionCapability = "Low",
    EscortRequired = BOMBER_ESCORT_CONFIG.RequireEscort,
    MinEscorts = 2,  -- Minimum escort fighters required
    MaxEscortDistance = 15000,
    ThreatTolerance = "Low", -- Will abort quickly
  },
  
  ["Tu-95"] = {
    Type = "Tu-95MS",
    DisplayName = "Tu-95 Bear",
    Category = "Cold War",
    CruiseSpeed = 400,
    MaxSpeed = 450,
    MinSpeed = 270,
    CruiseAlt = 30000,
    MaxAlt = 40000,
    MinAlt = 8000,
    DefaultFlightSize = 1,
    HasDefensiveGuns = true,
    FormationTight = false,
    EvasionCapability = "Low",
    EscortRequired = BOMBER_ESCORT_CONFIG.RequireEscort,
    MinEscorts = 1,  -- Minimum escort fighters required
    MaxEscortDistance = 15000,
    ThreatTolerance = "Medium",
  },
  
  ["Tu-22M3"] = {
    Type = "Tu-22M3",
    DisplayName = "Tu-22M Backfire",
    Category = "Modern",
    CruiseSpeed = 450,
    MaxSpeed = 600,
    MinSpeed = 300,
    CruiseAlt = 35000,
    MaxAlt = 45000,
    MinAlt = 1000,
    DefaultFlightSize = 1,
    HasDefensiveGuns = false,
    FormationTight = false,
    EvasionCapability = "Medium",
    EscortRequired = BOMBER_ESCORT_CONFIG.RequireEscort,
    MinEscorts = 1,  -- Minimum escort fighters required
    MaxEscortDistance = 20000,
    ThreatTolerance = "Low",
  },
  
  -- Modern
  ["B-1B"] = {
    Type = "B-1B",
    DisplayName = "B-1B Lancer",
    Category = "Modern",
    CruiseSpeed = 500,
    MaxSpeed = 700,
    MinSpeed = 320,
    CruiseAlt = 30000,
    MaxAlt = 50000,
    MinAlt = 500,
    DefaultFlightSize = 1,
    HasDefensiveGuns = false,
    FormationTight = false,
    EvasionCapability = "High",
    EscortRequired = false, -- Can operate independently
    MinEscorts = 0,  -- Minimum escort fighters required
    MaxEscortDistance = 20000,
    ThreatTolerance = "High",
  },
}



--- Get bomber profile by type name
-- @param #string bomberType The bomber type identifier
-- @return #table The bomber profile or nil if not found
function BOMBER_PROFILE:Get(bomberType)
  if not bomberType then
    return nil
  end
  
  -- Try exact match first
  if BOMBER_PROFILE.DB[bomberType] then
    return BOMBER_PROFILE.DB[bomberType]
  end
  
  -- Try partial match (case insensitive)
  local searchType = string.upper(bomberType)
  for profileType, profile in pairs(BOMBER_PROFILE.DB) do
    if string.find(string.upper(profileType), searchType) then
      return profile
    end
  end
  
  return nil
end

--- List all available bomber types
-- @return #table Array of bomber type names
function BOMBER_PROFILE:ListTypes()
  local types = {}
  for bomberType, _ in pairs(BOMBER_PROFILE.DB) do
    table.insert(types, bomberType)
  end
  table.sort(types)
  return types
end

--- Create new marker parser
-- @param #BOMBER_MARKER self
-- @return #BOMBER_MARKER
function BOMBER_MARKER:New()
  local self = BASE:Inherit(self, BASE:New())
  
  self.LastMissionData = {} -- Store last mission for respawn
  self.LastMissionData[coalition.side.BLUE] = nil
  self.LastMissionData[coalition.side.RED] = nil
  
  -- No automatic marker scanning - players use F10 menu to submit missions
  -- This prevents spam while building routes
  
  return self
end

--- Parse waypoint marker text for mission parameters
-- Format: BOMBER1:[Type]:[Size]:FL[Alt]:[Speed]
-- Example: BOMBER1:B-52H:4:FL250:350
-- @param #BOMBER_MARKER self
-- @param #string markerText The text from the map marker
-- @param #number defaultAlt Default altitude if not specified (feet)
-- @param #number defaultSpeed Default speed if not specified (knots)
-- @return #table Parsed parameters: {type, size, altitude, speed, originalText}
function BOMBER_MARKER:_ParseWaypointMarker(markerText, defaultAlt, defaultSpeed)
  local result = {
    type = nil,
    size = nil, -- Will use profile default if not specified
    altitude = defaultAlt or BOMBER_ESCORT_CONFIG.DefaultAltitude,
    speed = defaultSpeed or BOMBER_ESCORT_CONFIG.DefaultSpeed,
    originalText = markerText
  }
  
  -- Split by colon delimiter
  local parts = {}
  for part in string.gmatch(markerText, "[^:]+") do
    table.insert(parts, (string.gsub(part, "^%s*(.-)%s*$", "%1"))) -- Trim whitespace
  end
  
  -- Parse each part (skip first part which is BOMBER1, BOMBER2, etc.)
  if #parts >= 2 and parts[2] ~= "" then result.type = parts[2] end
  if #parts >= 3 and parts[3] ~= "" then 
    result.size = tonumber(parts[3])
  end
  if #parts >= 4 then
    -- Parse FL format or raw number
    local altStr = string.upper(parts[4])
    local flNum = string.match(altStr, "FL(%d+)")
    if flNum then
      result.altitude = tonumber(flNum) * 100
    else
      result.altitude = tonumber(parts[4]) or defaultAlt
    end
  end
  if #parts >= 5 then result.speed = tonumber(parts[5]) or defaultSpeed end
  
  return result
end

--- Parse target marker text for attack parameters
-- Format: TARGET1:TYPE:HEADING
-- Examples: 
--   TARGET1 - Standard attack
--   TARGET1:RUNWAY - Runway carpet bombing (auto direction)
--   TARGET1:RUNWAY:090 - Runway from heading 090
--   TARGET1:BRIDGE - Bridge attack
-- @param #BOMBER_MARKER self
-- @param #string markerText The text from the map marker
-- @return #table Parsed parameters: {attackType, heading}
function BOMBER_MARKER:_ParseTargetMarker(markerText)
  local result = {
    attackType = "AUTO", -- AUTO, RUNWAY, BRIDGE, BUILDING
    heading = nil, -- Optional specific attack heading
    originalText = markerText
  }
  
  -- Split by colon delimiter
  local parts = {}
  for part in string.gmatch(markerText, "[^:]+") do
    table.insert(parts, (string.gsub(part, "^%s*(.-)%s*$", "%1"))) -- Trim whitespace
  end
  
  -- Parse parts (skip first part which is TARGET1, TARGET2, etc.)
  if #parts >= 2 and parts[2] ~= "" then 
    result.attackType = string.upper(parts[2])
  end
  if #parts >= 3 and parts[3] ~= "" then
    result.heading = tonumber(parts[3])
  end
  
  return result
end

--- Scan map for waypoint markers matching bomber pattern
-- @param #BOMBER_MARKER self
-- @param #string prefix The marker prefix to search for (e.g., "BOMBER", "TARGET")
-- @return #table Array of waypoint data sorted by sequence number
-- @return #table Array of marker IDs for cleanup
function BOMBER_MARKER:_ScanForWaypointMarkers(prefix)
  local waypoints = {}
  local markerIds = {}
  
  -- Iterate through all possible marker IDs (DCS markers are numbered)
  for i = 1, 1000 do
    local markerData = world.getMarkPanels()
    if markerData and markerData[i] then
      local marker = markerData[i]
      local markerText = marker.text
      
      if markerText then
        -- Check if marker matches pattern: PREFIX + number
        local upperText = string.upper(markerText)
        local upperPrefix = string.upper(prefix)
        local sequence = string.match(upperText, "^" .. upperPrefix .. "(%d+)")
        
        if sequence then
          local seqNum = tonumber(sequence)
          local pos = marker.pos
          
          table.insert(waypoints, {
            sequence = seqNum,
            coordinate = COORDINATE:NewFromVec3(pos),
            markerId = marker.idx,
            markerText = markerText,
            coalition = marker.coalition or coalition.side.BLUE,
            -- Parse target-specific parameters if this is a target marker
            targetParams = prefix == self.Config.targetPrefix and self:_ParseTargetMarker(markerText) or nil
          })
          
          table.insert(markerIds, marker.idx)
          
          env.info(string.format("[BOMBER] Found waypoint marker: %s at seq %d (ID: %d)", 
            markerText, seqNum, marker.idx))
        end
      end
    end
  end
  
  -- Sort by sequence number
  table.sort(waypoints, function(a, b) return a.sequence < b.sequence end)
  
  return waypoints, markerIds
end

--- Check for new map markers and auto-execute missions
-- @param #BOMBER_MARKER self
function BOMBER_MARKER:_CheckMarkers()
  -- Scan for bomber waypoint markers
  local bomberWaypoints, bomberMarkerIds = self:_ScanForWaypointMarkers(self.Config.waypointPrefix)
  
  -- Scan for target markers
  local targetWaypoints, targetMarkerIds = self:_ScanForWaypointMarkers(self.Config.targetPrefix)
  
  -- Scan for egress waypoint markers
  local egressWaypoints, egressMarkerIds = self:_ScanForWaypointMarkers(self.Config.egressPrefix)
  
  -- Scan for RTB markers
  local rtbWaypoints, rtbMarkerIds = self:_ScanForWaypointMarkers(self.Config.rtbPrefix)
  
  -- Provide feedback about what was found
  local feedbackMsg = "[MAP] BOMBER MISSION MARKERS DETECTED:\n\n"
  local hasBombers = #bomberWaypoints > 0
  local hasTargets = #targetWaypoints > 0
  
  if hasBombers then
    feedbackMsg = feedbackMsg .. string.format("[OK] BOMBER waypoints: %d found\n", #bomberWaypoints)
    for _, wp in ipairs(bomberWaypoints) do
      feedbackMsg = feedbackMsg .. string.format("  - %s (seq %d)\n", wp.markerText, wp.sequence)
    end
  else
    feedbackMsg = feedbackMsg .. "[X] BOMBER waypoints: NONE found\n"
    feedbackMsg = feedbackMsg .. "  -> Place BOMBER1:[Type]:[Size]:FL[Alt]:[Speed]\n"
  end
  
  feedbackMsg = feedbackMsg .. "\n"
  
  if hasTargets then
    feedbackMsg = feedbackMsg .. string.format("[OK] TARGET markers: %d found\n", #targetWaypoints)
    for _, wp in ipairs(targetWaypoints) do
      feedbackMsg = feedbackMsg .. string.format("  - %s (seq %d)\n", wp.markerText, wp.sequence)
    end
  else
    feedbackMsg = feedbackMsg .. "[X] TARGET markers: NONE found\n"
    feedbackMsg = feedbackMsg .. "  -> Place TARGET1:[AttackType]:[Heading]\n"
  end
  
  if #egressWaypoints > 0 then
    feedbackMsg = feedbackMsg .. string.format("\n[OK] EGRESS waypoints: %d found (optional)\n", #egressWaypoints)
  end
  
  if #rtbWaypoints > 0 then
    feedbackMsg = feedbackMsg .. string.format("[OK] RTB markers: %d found (optional)\n", #rtbWaypoints)
  end
  
  -- Check if we have minimum required markers for mission execution
  if not hasBombers or not hasTargets then
    feedbackMsg = feedbackMsg .. "\n[!] INCOMPLETE MISSION\n"
    feedbackMsg = feedbackMsg .. "Both BOMBER1 and TARGET1 are required.\n"
    feedbackMsg = feedbackMsg .. "Add missing markers and retry F10 -> Launch Mission."
    
    -- Send feedback to all coalitions with markers
    local coalitionsWithMarkers = {}
    for _, wp in ipairs(bomberWaypoints) do
      coalitionsWithMarkers[wp.coalition] = true
    end
    for _, wp in ipairs(targetWaypoints) do
      coalitionsWithMarkers[wp.coalition] = true
    end
    
    for coalitionSide, _ in pairs(coalitionsWithMarkers) do
      MESSAGE:New(feedbackMsg, 20):ToCoalition(coalitionSide)
    end
    
    -- If no markers at all, send to blue by default
    if not hasBombers and not hasTargets then
      MESSAGE:New("[X] NO BOMBER MISSION MARKERS FOUND\n\nPlace BOMBER1 and TARGET1 markers on the F10 map, then use F10 -> Bomber Missions -> Launch Mission.", 15):ToBlue()
    end
    
    return false
  end
  
  feedbackMsg = feedbackMsg .. "\n[OK] MISSION COMPLETE - Validating and spawning...\n"
  
  -- Group by coalition
  local missionsByCoalition = {}
  
  for _, bomberWp in ipairs(bomberWaypoints) do
    local coalitionSide = bomberWp.coalition
    
    if not missionsByCoalition[coalitionSide] then
      missionsByCoalition[coalitionSide] = {
        bomberWaypoints = {},
        targetWaypoints = {},
        allMarkerIds = {}
      }
    end
    
    table.insert(missionsByCoalition[coalitionSide].bomberWaypoints, bomberWp)
    table.insert(missionsByCoalition[coalitionSide].allMarkerIds, bomberWp.markerId)
  end
  
  for _, targetWp in ipairs(targetWaypoints) do
    local coalitionSide = targetWp.coalition
    
    if missionsByCoalition[coalitionSide] then
      table.insert(missionsByCoalition[coalitionSide].targetWaypoints, targetWp)
      table.insert(missionsByCoalition[coalitionSide].allMarkerIds, targetWp.markerId)
    end
  end
  
  for _, egressWp in ipairs(egressWaypoints) do
    local coalitionSide = egressWp.coalition
    
    if missionsByCoalition[coalitionSide] then
      if not missionsByCoalition[coalitionSide].egressWaypoints then
        missionsByCoalition[coalitionSide].egressWaypoints = {}
      end
      table.insert(missionsByCoalition[coalitionSide].egressWaypoints, egressWp)
      table.insert(missionsByCoalition[coalitionSide].allMarkerIds, egressWp.markerId)
    end
  end
  
  for _, rtbWp in ipairs(rtbWaypoints) do
    local coalitionSide = rtbWp.coalition
    
    if missionsByCoalition[coalitionSide] then
      if not missionsByCoalition[coalitionSide].rtbWaypoints then
        missionsByCoalition[coalitionSide].rtbWaypoints = {}
      end
      table.insert(missionsByCoalition[coalitionSide].rtbWaypoints, rtbWp)
      table.insert(missionsByCoalition[coalitionSide].allMarkerIds, rtbWp.markerId)
    end
  end
  
  -- Send initial feedback before detailed validation
  for coalitionSide, _ in pairs(missionsByCoalition) do
    MESSAGE:New(feedbackMsg, 15):ToCoalition(coalitionSide)
  end
  
  -- Execute missions for each coalition that has complete marker set
  for coalitionSide, missionData in pairs(missionsByCoalition) do
    if #missionData.bomberWaypoints > 0 and #missionData.targetWaypoints > 0 then
      self:_ExecuteMissionFromMarkers(coalitionSide, missionData)
    end
  end
  
  return true
end

--- Execute a bomber mission from detected markers
-- @param #BOMBER_MARKER self
-- @param #number coalitionSide The coalition side
-- @param #table missionData Table containing bomberWaypoints, targetWaypoints, egressWaypoints, rtbWaypoints, allMarkerIds
function BOMBER_MARKER:_ExecuteMissionFromMarkers(coalitionSide, missionData)
  local bomberWaypoints = missionData.bomberWaypoints
  local targetWaypoints = missionData.targetWaypoints
  local egressWaypoints = missionData.egressWaypoints or {}
  local rtbWaypoints = missionData.rtbWaypoints or {}
  
  -- Parse BOMBER1 marker for mission parameters
  local firstWp = bomberWaypoints[1]
  local params = self:_ParseWaypointMarker(firstWp.markerText)
  
  -- Validate bomber type
  local bomberType = params.type or "B-52H"
  if not BOMBER_PROFILE:Get(bomberType) then
    self:_SendMessage(coalitionSide, string.format(
      "[X] INVALID BOMBER TYPE: %s\n\nAvailable types: %s", 
      bomberType, 
      table.concat(BOMBER_PROFILE:ListTypes(), ", ")
    ))
    return
  end
  
  -- Check if template exists in mission
  if _BOMBER_AVAILABLE_TEMPLATES and not _BOMBER_AVAILABLE_TEMPLATES[bomberType] then
    local templateName = string.gsub(bomberType, "[-]", "")
    templateName = string.gsub(templateName, "MS$", "")
    templateName = "BOMBER_" .. string.upper(templateName)
    
    self:_SendMessage(coalitionSide, string.format(
      "[X] BOMBER TEMPLATE MISSING\n\n" ..
      "Bomber Type: %s\n" ..
      "Required Template: %s\n\n" ..
      "MISSION MAKER: Add this to mission editor:\n" ..
      "1. Place %s aircraft group\n" ..
      "2. Name group: %s\n" ..
      "3. Set Late Activation = TRUE\n" ..
      "4. Set loadout (bombs)\n" ..
      "5. Restart mission after adding",
      bomberType, templateName, bomberType, templateName
    ))
    return
  end
  
  -- Get profile for defaults
  local profile = BOMBER_PROFILE:Get(bomberType)
  
  -- Validate flight size (use profile default if not specified)
  local flightSize = params.size or profile.DefaultFlightSize or 1
  if flightSize < 1 or flightSize > 6 then
    self:_SendMessage(coalitionSide, "INVALID FLIGHT SIZE: Must be 1-6 aircraft")
    return
  end
  
  -- Auto-detect airbase from marker position
  local startAirbase = nil
  
  -- Find nearest airbase to BOMBER1 marker
  local nearestAirbase = firstWp.coordinate:GetClosestAirbase(Airbase.Category.AIRDROME, coalitionSide)
  if nearestAirbase then
    local distance = firstWp.coordinate:Get2DDistance(nearestAirbase:GetCoordinate())
    -- Only use airbase if marker is within 5km of it
    if distance < 5000 then
      startAirbase = nearestAirbase:GetName()
      BASE:I(string.format("Auto-detected airbase: %s (%.0f m from marker)", startAirbase, distance))
    else
      BASE:I(string.format("Marker not on airbase (%.0f m from nearest: %s)", distance, nearestAirbase:GetName()))
      if self.Config.AllowAirSpawnFallback then
        BASE:I("Air spawn fallback enabled - proceeding with air spawn")
        self:_SendMessage(coalitionSide, string.format(
          "[!] BOMBER1 not on airbase - using air spawn\n\n" ..
          "Nearest: %s (%.1f km away)\n" ..
          "Bombers will spawn in the air at marker position",
          nearestAirbase:GetName(), 
          distance / 1000
        ))
      else
        self:_SendMessage(coalitionSide, string.format(
          "[X] BOMBER1 marker not on airbase!\n\n" ..
          "Nearest airbase: %s (%.1f km away)\n\n" ..
          "Move marker onto the airbase to spawn bombers.",
          nearestAirbase:GetName(), 
          distance / 1000
        ))
        return
      end
    end
  else
    BASE:I("No friendly airbase found near marker")
    if self.Config.AllowAirSpawnFallback then
      BASE:I("Air spawn fallback enabled - proceeding with air spawn")
      self:_SendMessage(coalitionSide, "[!] No airbase nearby - using air spawn")
    else
      self:_SendMessage(coalitionSide, 
        "[X] No friendly airbase found!\n\n" ..
        "BOMBER1 must be placed on or near an airbase."
      )
      return
    end
  end
  
  -- Build mission data structure with multiple targets
  local targets = {}
  for i, targetWp in ipairs(targetWaypoints) do
    -- Check if target is near an airbase for location info
    local nearAirbase = nil
    local targetAirbase = targetWp.coordinate:GetClosestAirbase(Airbase.Category.AIRDROME)
    if targetAirbase then
      local distance = targetWp.coordinate:Get2DDistance(targetAirbase:GetCoordinate())
      if distance < 5000 then -- Within 5km
        nearAirbase = targetAirbase:GetName()
      end
    end
    
    table.insert(targets, {
      name = targetWp.markerText,
      coordinate = targetWp.coordinate,
      sequence = targetWp.sequence,
      attackType = targetWp.targetParams and targetWp.targetParams.attackType or "AUTO",
      attackHeading = targetWp.targetParams and targetWp.targetParams.heading or nil,
      airbaseName = nearAirbase
    })
  end
  
  local missionDataStruct = {
    Coalition = coalitionSide,
    StartAirbase = startAirbase,
    StartPos = firstWp.coordinate,
    Targets = targets,
    BomberType = bomberType,
    FlightSize = flightSize,
    CruiseAlt = params.altitude,
    CruiseSpeed = params.speed,
    RouteWaypoints = {},
    EgressWaypoints = {},
    RTBWaypoint = nil,
  }
  
  -- Collect additional route waypoints (BOMBER2, BOMBER3, etc.)
  for i = 2, #bomberWaypoints do
    table.insert(missionDataStruct.RouteWaypoints, {
      coordinate = bomberWaypoints[i].coordinate,
      sequence = bomberWaypoints[i].sequence
    })
  end
  
  -- Collect egress waypoints (EGRESS1, EGRESS2, etc.)
  for i, egressWp in ipairs(egressWaypoints) do
    table.insert(missionDataStruct.EgressWaypoints, {
      coordinate = egressWp.coordinate,
      sequence = egressWp.sequence
    })
  end
  
  -- Get RTB waypoint if provided (only use first one if multiple)
  if #rtbWaypoints > 0 then
    missionDataStruct.RTBWaypoint = {
      coordinate = rtbWaypoints[1].coordinate,
      sequence = rtbWaypoints[1].sequence
    }
  end
  
  -- Spawn the bomber mission
  local success, mission = self:_SpawnBomberMission(missionDataStruct)
  
  if success then
    local targetCount = #missionDataStruct.Targets
    
    -- Build target description with attack types and locations
    local targetDescriptions = {}
    for i, target in ipairs(missionDataStruct.Targets) do
      local attackTypeDesc = ""
      local locationDesc = ""
      
      -- Determine attack type description
      if target.attackType == "RUNWAY" then
        attackTypeDesc = "RUNWAY"
      elseif target.attackType == "BRIDGE" then
        attackTypeDesc = "BRIDGE"
      elseif target.attackType == "BUILDING" then
        attackTypeDesc = "BUILDING"
      else
        attackTypeDesc = "TARGET"
      end
      
      -- Add location if known
      if target.airbaseName then
        locationDesc = " @ " .. target.airbaseName
      end
      
      -- Add heading for runway attacks
      if target.attackType == "RUNWAY" and target.attackHeading then
        locationDesc = locationDesc .. string.format(" (HDG %.0f°)", target.attackHeading)
      end
      
      table.insert(targetDescriptions, attackTypeDesc .. locationDesc)
    end
    
    -- Build the complete message with proper formatting
    local missionMsg = "[AC] BOMBER MISSION ACTIVE\n\n"
    missionMsg = missionMsg .. "Callsign: " .. (mission.Callsign or "Unknown") .. "\n"
    missionMsg = missionMsg .. "Aircraft: " .. missionDataStruct.BomberType .. " x" .. missionDataStruct.FlightSize .. "\n"
    
    if targetCount == 1 then
      missionMsg = missionMsg .. "Target: " .. targetDescriptions[1] .. "\n"
    else
      missionMsg = missionMsg .. "Targets: " .. targetCount .. "\n"
      for _, desc in ipairs(targetDescriptions) do
        missionMsg = missionMsg .. "  - " .. desc .. "\n"
      end
    end
    
    missionMsg = missionMsg .. "\n[!] PROVIDE ESCORT IMMEDIATELY!"
    
    self:_SendMessage(coalitionSide, missionMsg)
    
    -- Cleanup markers if configured
    if self.Config.deleteMarkersAfterUse then
      for _, markerId in ipairs(missionData.allMarkerIds) do
        trigger.action.removeMark(markerId)
      end
    end
  else
    self:_SendMessage(coalitionSide, "MISSION SPAWN FAILED: " .. tostring(mission))
  end
end

--- Respawn the last completed/failed mission
-- @param #BOMBER_MARKER self
-- @param #number coalitionSide The coalition side
function BOMBER_MARKER:_RespawnLastMission(coalitionSide)
  local lastMission = self.LastMissionData[coalitionSide]
  
  if not lastMission then
    self:_SendMessage(coalitionSide, "No previous mission to respawn!")
    return
  end
  
  -- Respawn the mission
  local success, mission = self:_SpawnBomberMission(lastMission)
  
  if success then
    self:_SendMessage(coalitionSide, string.format(
      "MISSION RESPAWNED\nCallsign: %s\nType: %s x%d\nTarget: %s",
      mission.Callsign or "Unknown",
      lastMission.BomberType,
      lastMission.FlightSize,
      lastMission.TargetName or "Coordinates"
    ))
  else
    self:_SendMessage(coalitionSide, "RESPAWN FAILED: " .. tostring(mission))
  end
end


--- Spawn bomber mission from validated data
-- @param #BOMBER_MARKER self
-- @param #table missionData The mission parameters
-- @return #boolean success
-- @return #BOMBER_MISSION mission The bomber mission object or error string
function BOMBER_MARKER:_SpawnBomberMission(missionData)
  BASE:I("*** BOMBER MISSION SPAWN REQUESTED ***")
  BASE:I(string.format("Type: %s x%d", missionData.BomberType, missionData.FlightSize))
  BASE:I(string.format("Start: %s", missionData.StartAirbase or "Coordinates"))
  BASE:I(string.format("Target: %s", missionData.TargetName or "Coordinates"))
  
  -- Create mission manager if it doesn't exist
  if not _BOMBER_MISSION_MANAGER then
    _BOMBER_MISSION_MANAGER = BOMBER_MISSION_MANAGER:New()
  end
  
  -- Create and register mission
  local mission = BOMBER_MISSION:New(missionData)
  if mission then
    local success = mission:Start()
    if success then
      _BOMBER_MISSION_MANAGER:RegisterMission(mission)
      
      -- Store last mission data for respawn
      _BOMBER_MARKER_SYSTEM.LastMissionData = _BOMBER_MARKER_SYSTEM.LastMissionData or {}
      _BOMBER_MARKER_SYSTEM.LastMissionData[missionData.Coalition] = missionData
      
      return true, mission
    else
      return false, "Failed to start mission"
    end
  else
    return false, "Failed to create mission"
  end
end

--- Send message to coalition
-- @param #BOMBER_MARKER self
-- @param #number coalitionSide The coalition side
-- @param #string message The message text
function BOMBER_MARKER:_SendMessage(coalitionSide, message)
  trigger.action.outTextForCoalition(coalitionSide, "BOMBER CONTROL: " .. message, BOMBER_ESCORT_CONFIG.MessageDuration)
end

---
-- BOMBER_ESCORT_MONITOR - Tracks player escorts around bombers
-- @type BOMBER_ESCORT_MONITOR
BOMBER_ESCORT_MONITOR = {
  ClassName = "BOMBER_ESCORT_MONITOR"
}

--- Create new escort monitor
-- @param #BOMBER_ESCORT_MONITOR self
-- @param #BOMBER bomber The bomber instance to monitor
-- @return #BOMBER_ESCORT_MONITOR
function BOMBER_ESCORT_MONITOR:New(bomber)
  local self = BASE:Inherit(self, BASE:New())
  
  self.Bomber = bomber
  self.EscortUnits = {} -- Table of escort unit names and last seen time
  self.EscortCount = 0
  self.PreviousEscortCount = 0  -- Track previous count to detect changes
  self.LastEscortTime = timer.getTime()
  self.UnescortedDuration = 0
  self.EverHadEscort = false  -- Track if we've ever detected escorts (prevents abort timer during initial join-up)
  
  -- Configuration from bomber profile
  local profile = bomber.Profile
  self.MaxEscortDistance = profile.MaxEscortDistance or 10000
  self.MinEscorts = profile.MinEscorts or 2
  self.CheckInterval = 5 -- seconds
  
  return self
end

--- Start monitoring for escorts
-- @param #BOMBER_ESCORT_MONITOR self
function BOMBER_ESCORT_MONITOR:Start()
  -- Reset escort timing when starting monitor to avoid false "unescorted" duration
  self.LastEscortTime = timer.getTime()
  self.UnescortedDuration = 0
  
  self.SchedulerID = SCHEDULER:New(nil, self._ScanForEscorts, {self}, 2, self.CheckInterval)
  return self
end

--- Stop monitoring
-- @param #BOMBER_ESCORT_MONITOR self
function BOMBER_ESCORT_MONITOR:Stop()
  if self.SchedulerID then
    self.SchedulerID:Stop()
  end
  return self
end

--- Scan for player escorts nearby
-- @param #BOMBER_ESCORT_MONITOR self
function BOMBER_ESCORT_MONITOR:_ScanForEscorts()
  if not self.Bomber or not self.Bomber:IsAlive() then
    self:Stop()
    return
  end
  
  local bomberGroup = self.Bomber.Group
  if not bomberGroup then return end
  
  local bomberCoord = bomberGroup:GetCoordinate()
  if not bomberCoord then return end
  
  local currentTime = timer.getTime()
  local escortsFound = {}
  
  -- Scan for player aircraft within range
  local scanSet = SET_UNIT:New()
    :FilterCoalitions(self.Bomber.Coalition)
    :FilterCategories("plane")
    :FilterOnce()
  
  BASE:I(string.format("%s: Scanning for escorts within %.1f km...", self.Bomber.Callsign, self.MaxEscortDistance/1000))
  local scannedCount = 0
  local playerCount = 0
  local fighterCount = 0
  local confirmedCount = 0
  local probableCount = 0
  local passingCount = 0
  
  scanSet:ForEachUnit(function(unit)
    scannedCount = scannedCount + 1
    local unitType = unit:GetTypeName()
    
    -- Check if player controlled
    if unit:IsPlayer() and unit:IsAlive() then
      playerCount = playerCount + 1
      
      -- Check if it's a fighter (not bomber, attacker, or helicopter)
      local isFighter = self:_IsFighterType(unitType)
      BASE:I(string.format("%s: Found player aircraft '%s' (Type: %s, IsFighter: %s)", 
        self.Bomber.Callsign, unit:GetName(), unitType, tostring(isFighter)))
      
      if isFighter then
        fighterCount = fighterCount + 1
        local unitCoord = unit:GetCoordinate()
        if unitCoord then
          local distance = bomberCoord:Get2DDistance(unitCoord)
          
          if distance <= self.MaxEscortDistance then
            -- Classify the escort based on tactical relationship
            local classification, details = self:_ClassifyEscort(unit, distance)
            
            if classification == "confirmed" then
              confirmedCount = confirmedCount + 1
            elseif classification == "probable" then
              probableCount = probableCount + 1
            elseif classification == "passing" then
              passingCount = passingCount + 1
            end
            
            local unitName = unit:GetName()
            escortsFound[unitName] = {
              Unit = unit,
              Distance = distance,
              Time = currentTime,
              Classification = classification,
              Details = details
            }
            
            BASE:I(string.format("%s: ESCORT DETECTED - %s at %.1f km [%s] (Hdg: %.0f°, Alt: %.0fft, Spd: %.0fkts | Diff - Hdg: %.0f°, Alt: %.0fft, Spd: %.0fkts)", 
              self.Bomber.Callsign, unitName, distance/1000, string.upper(classification),
              details.heading or 0, details.altitude or 0, details.speed or 0,
              details.headingDiff or 0, details.altDiff or 0, details.speedDiff or 0))
          else
            BASE:I(string.format("%s: Fighter %s too far (%.1f km > %.1f km)", 
              self.Bomber.Callsign, unit:GetName(), distance/1000, self.MaxEscortDistance/1000))
          end
        end
      end
    end
  end)
  
  BASE:I(string.format("%s: Escort scan complete - Total: %d, Players: %d, Fighters: %d | Confirmed: %d, Probable: %d, Passing: %d", 
    self.Bomber.Callsign, scannedCount, playerCount, fighterCount, confirmedCount, probableCount, passingCount))
  
  -- Update escort tracking (only count CONFIRMED escorts for mission requirements)
  self.EscortUnits = escortsFound
  self.EscortCount = self:_CountConfirmedEscorts(escortsFound)
  
  -- During TAKING_OFF/CLIMBING phases, also count PROBABLE escorts for abort timer reset (escorts catching up)
  local probableCount = 0
  if self.Bomber:Is(BOMBER.States.TAKING_OFF) or self.Bomber:Is(BOMBER.States.CLIMBING) then
    for unitName, data in pairs(escortsFound) do
      if data.Classification == "probable" then
        probableCount = probableCount + 1
      end
    end
    if probableCount > 0 then
      local phase = self.Bomber:Is(BOMBER.States.TAKING_OFF) and "TAKING_OFF" or "CLIMBING"
      BASE:I(string.format("%s: %s phase - %d confirmed + %d probable escorts (probable resets abort timer)", 
        self.Bomber.Callsign, phase, self.EscortCount, probableCount))
    end
  end
  
  -- Only track escort roster changes if bomber is airborne (prevents spam during taxi)
  local bomberAirborne = false
  if self.Bomber.Group then
    local altitude = self.Bomber.Group:GetAltitude()
    local velocity = self.Bomber.Group:GetVelocityKNOTS()
    bomberAirborne = (altitude > 100 and velocity > 100)  -- Clearly airborne and flying
  end
  
  if bomberAirborne then
    -- Build current escorts table for roster tracking with classification
    local currentEscorts = {}
    for unitName, data in pairs(escortsFound) do
      local callsign = data.Unit:GetCallsign() or unitName
      currentEscorts[callsign] = {
        unit = data.Unit,
        classification = data.Classification,
        details = data.Details
      }
    end
    
    -- Update bomber's dynamic escort roster (with join/leave announcements)
    self.Bomber:_UpdateEscortRoster(currentEscorts)
  else
    BASE:I(string.format("%s: Bomber not yet airborne - skipping escort roster updates", self.Bomber.Callsign))
  end
  
  -- Check for tight formation flying and send compliments
  if bomberAirborne then
    self:_CheckFormationFlying(escortsFound, currentTime)
  end
  
  -- Check if escort is required for this bomber
  local escortRequired = self.Bomber.Profile.EscortRequired
  
  if not escortRequired then
    BASE:I(string.format("%s: Escort not required for this bomber type - operating independently (escorts still recognized and appreciated)", self.Bomber.Callsign))
    return  -- Skip escort requirement/abort checks - but escorts are still tracked and acknowledged above
  end
  
  -- Update escort status (only if escort is required)
  -- During TAKING_OFF/CLIMBING, count both CONFIRMED + PROBABLE escorts to prevent premature abort while escort catches up
  local effectiveEscortCount = self.EscortCount
  if (self.Bomber:Is(BOMBER.States.TAKING_OFF) or self.Bomber:Is(BOMBER.States.CLIMBING)) and probableCount > 0 then
    effectiveEscortCount = self.EscortCount + probableCount
  end
  
  if effectiveEscortCount >= self.MinEscorts and effectiveEscortCount > 0 then
    self.LastEscortTime = currentTime
    self.UnescortedDuration = 0
    
    -- Only set EverHadEscort flag if bomber is airborne (prevents ground detections from starting timer)
    if bomberAirborne and not self.EverHadEscort then
      self.EverHadEscort = true  -- Mark that we've had escorts while airborne
      BASE:I(string.format("%s: Airborne escort detected - abort timer now active", self.Bomber.Callsign))
    end
    
    if not self.Bomber.HasEscort then
      -- Special case: If bomber is RTB/ABORTING, require close proximity (500m) to resume
      local isReturning = self.Bomber:Is(BOMBER.States.RTB) or self.Bomber:Is(BOMBER.States.ABORTING)
      
      if isReturning then
        -- Check if any escort is within 500m
        local hasCloseEscort = false
        local closestDistance = 999999
        local closestCallsign = nil
        
        for unitName, data in pairs(escortsFound) do
          if data.Distance < closestDistance then
            closestDistance = data.Distance
            closestCallsign = data.Unit:GetCallsign() or unitName
          end
          if data.Distance <= 500 then
            hasCloseEscort = true
          end
        end
        
        if hasCloseEscort then
          BASE:I(string.format("%s: RTB escort join - %s within %.0fm (required <500m)", 
            self.Bomber.Callsign, closestCallsign, closestDistance))
          self.Bomber:OnEscortArrived(self.EscortCount)
        else
          BASE:I(string.format("%s: RTB - Escort detected but too far for resume (closest: %s at %.0fm, need <500m)", 
            self.Bomber.Callsign, closestCallsign or "none", closestDistance))
          
          -- Send message to players (throttled to once per 60 seconds to prevent spam)
          if not self.Bomber.LastProximityWarningTime or (currentTime - self.Bomber.LastProximityWarningTime) >= 60 then
            self.Bomber:_BroadcastMessage(string.format("%s: [!] Escort detected at %.1f km - Close to within 500m to resume mission!", 
              self.Bomber.Callsign, closestDistance / 1000))
            self.Bomber.LastProximityWarningTime = currentTime
          end
        end
      else
        -- Normal operations - any escort in range is good
        self.Bomber:OnEscortArrived(self.EscortCount)
      end
    end
    self.PreviousEscortCount = self.EscortCount
  else
    -- Only start abort timer if we've had escorts before (prevents abort during initial join-up)
    if self.EverHadEscort then
      self.UnescortedDuration = currentTime - self.LastEscortTime
      
      -- Determine if escorts were lost or just never had enough
      local hadSufficientEscorts = (self.PreviousEscortCount >= self.MinEscorts)
      
      -- Always call with updated duration to allow progressive warnings/abort
      if self.UnescortedDuration > 0 then
        self.Bomber:OnEscortLost(self.UnescortedDuration, self.EscortCount, hadSufficientEscorts)
      end
    else
      -- Haven't had escorts yet - waiting for initial join-up, no warnings
      BASE:I(string.format("%s: Waiting for escort to join (no timer yet)", self.Bomber.Callsign))
    end
    
    self.PreviousEscortCount = self.EscortCount
  end
end

--- Count valid escorts
-- @param #BOMBER_ESCORT_MONITOR self
-- @param #table escorts Table of escort data
-- @return #number Count of valid escorts
function BOMBER_ESCORT_MONITOR:_CountEscorts(escorts)
  local count = 0
  for _, _ in pairs(escorts) do
    count = count + 1
  end
  return count
end

--- Count only confirmed escorts (for mission requirements)
-- @param #BOMBER_ESCORT_MONITOR self
-- @param #table escorts Table of escort data with classification
-- @return #number Count of confirmed escorts
function BOMBER_ESCORT_MONITOR:_CountConfirmedEscorts(escorts)
  local count = 0
  for _, data in pairs(escorts) do
    if data.Classification == "confirmed" then
      count = count + 1
    end
  end
  return count
end

--- Check if aircraft type is a fighter (not bomber, attacker, or helicopter)
-- @param #BOMBER_ESCORT_MONITOR self
-- @param #string typeName Aircraft type name
-- @return #boolean True if fighter type
function BOMBER_ESCORT_MONITOR:_IsFighterType(typeName)
  if not typeName then return false end
  
  -- Exclude bomber types
  local bomberTypes = {
    ["B-1B"] = true,
    ["B-52H"] = true,
    ["Tu-95MS"] = true,
    ["Tu-160"] = true,
    ["Tu-22M3"] = true,
  }
  
  -- Exclude attacker/ground attack types (A-10, Su-25, etc)
  local attackerTypes = {
    ["A-10A"] = true,
    ["A-10C"] = true,
    ["A-10C_2"] = true,
    ["Su-25"] = true,
    ["Su-25T"] = true,
    ["Su-25TM"] = true,
  }
  
  -- Exclude helicopters (category check should handle this but be explicit)
  local heloTypes = {
    ["AH-64D"] = true,
    ["Ka-50"] = true,
    ["Mi-24P"] = true,
    ["Mi-8MT"] = true,
    ["UH-1H"] = true,
  }
  
  if bomberTypes[typeName] or attackerTypes[typeName] or heloTypes[typeName] then
    return false
  end
  
  -- Everything else in the plane category is considered a fighter
  return true
end

--- Classify escort based on tactical relationship to bomber
-- Returns: "confirmed", "probable", "passing", or "unrelated"
-- @param #BOMBER_ESCORT_MONITOR self
-- @param Wrapper.Unit#UNIT escortUnit The escort unit to classify
-- @param #number distance Distance to bomber in meters
-- @return #string Classification type
-- @return #table Details {heading, altitude, speed, headingDiff, altDiff, speedDiff}
function BOMBER_ESCORT_MONITOR:_ClassifyEscort(escortUnit, distance)
  local bomberGroup = self.Bomber.Group
  if not bomberGroup or not escortUnit then
    return "unrelated", {}
  end
  
  -- Get bomber parameters
  local bomberCoord = bomberGroup:GetCoordinate()
  local bomberVelocity = bomberGroup:GetVelocityKNOTS()
  local bomberAltitude = bomberGroup:GetAltitude() * 3.28084  -- Convert m to ft
  local bomberHeading = bomberGroup:GetHeading()
  
  -- Get escort parameters
  local escortCoord = escortUnit:GetCoordinate()
  local escortVelocity = escortUnit:GetVelocityKNOTS()
  local escortAltitude = escortUnit:GetAltitude() * 3.28084  -- Convert m to ft
  local escortHeading = escortUnit:GetHeading()
  
  if not bomberCoord or not escortCoord then
    return "unrelated", {}
  end
  
  -- Calculate differences
  local headingDiff = math.abs(bomberHeading - escortHeading)
  if headingDiff > 180 then
    headingDiff = 360 - headingDiff  -- Normalize to 0-180 range
  end
  
  local altDiff = math.abs(bomberAltitude - escortAltitude)
  local speedDiff = math.abs(bomberVelocity - escortVelocity)
  
  -- Build details table
  local details = {
    heading = escortHeading,
    altitude = escortAltitude,
    speed = escortVelocity,
    headingDiff = headingDiff,
    altDiff = altDiff,
    speedDiff = speedDiff,
    distance = distance
  }
  
  -- Classification logic with config thresholds
  -- During TAKING_OFF/CLIMBING phases, use strict matching for join-up verification
  -- After that, simplify to distance-only (escorts need freedom to maneuver during mission)
  local rangeMultiplier = 1.0
  local headingMultiplier = 1.0
  local altMultiplier = 1.0
  local speedMultiplier = 1.0
  local distanceOnlyMode = false  -- Flag for simplified distance-only classification
  
  -- Calculate flight size scaling factor (more bombers = more spacing needed)
  local flightSize = self.Bomber.FlightSize or 1
  local flightSizeScale = 1.0 + (flightSize - 1) * 0.5  -- +50% per additional bomber
  
  if self.Bomber:Is(BOMBER.States.TAKING_OFF) then
    -- During takeoff - very lenient for initial departure coordination
    rangeMultiplier = 4.0 * flightSizeScale      -- 4x base (40km single, 60km for 2, 80km for 3, 100km for 4)
    headingMultiplier = 4.0                       -- 4x heading tolerance (180° - any direction during departure)
    altMultiplier = 3.0 * flightSizeScale         -- 3x base altitude tolerance (scales with flight size)
    speedMultiplier = 3.0 * flightSizeScale       -- 3x base speed tolerance (scales with flight size)
    BASE:I(string.format("%s: TAKING_OFF phase (flight:%d, scale:%.1fx) - very relaxed escort detection (range:%.1fx=%.0fkm, hdg:%.1fx, alt:%.1fx, spd:%.1fx)", 
      self.Bomber.Callsign, flightSize, flightSizeScale, rangeMultiplier, rangeMultiplier * 10, headingMultiplier, altMultiplier, speedMultiplier))
  elseif self.Bomber:Is(BOMBER.States.CLIMBING) then
    -- During climb - relaxed for formation assembly
    rangeMultiplier = 3.5 * flightSizeScale      -- 3.5x base (35km single, 52.5km for 2, 70km for 3, 87.5km for 4)
    headingMultiplier = 3.0                       -- 3x heading tolerance (135° - escorts can approach from behind)
    altMultiplier = 2.5 * flightSizeScale         -- 2.5x base altitude tolerance (scales with flight size)
    speedMultiplier = 2.5 * flightSizeScale       -- 2.5x base speed tolerance (scales with flight size)
    BASE:I(string.format("%s: CLIMBING phase (flight:%d, scale:%.1fx) - relaxed escort detection (range:%.1fx=%.0fkm, hdg:%.1fx, alt:%.1fx, spd:%.1fx)", 
      self.Bomber.Callsign, flightSize, flightSizeScale, rangeMultiplier, rangeMultiplier * 10, headingMultiplier, altMultiplier, speedMultiplier))
  else
    -- CRUISE and beyond - distance-only mode (escorts need tactical freedom)
    distanceOnlyMode = true
    rangeMultiplier = 2.0  -- 20km max range
    BASE:I(string.format("%s: CRUISE+ phase - distance-only escort detection (range: %.0fkm, no heading/alt/speed checks)", 
      self.Bomber.Callsign, rangeMultiplier * 10))
  end
  
  local closeRange = BOMBER_ESCORT_CONFIG.EscortCloseRange * rangeMultiplier
  local mediumRange = BOMBER_ESCORT_CONFIG.EscortMediumRange * rangeMultiplier
  local maxRange = BOMBER_ESCORT_CONFIG.EscortMaxRange * rangeMultiplier
  local headingTol = BOMBER_ESCORT_CONFIG.EscortHeadingTolerance * headingMultiplier
  local altTol = BOMBER_ESCORT_CONFIG.EscortAltitudeTolerance * altMultiplier
  local speedTol = BOMBER_ESCORT_CONFIG.EscortVelocityTolerance * speedMultiplier
  
  -- Special case: Both on ground (altitude < 100ft) and close proximity
  -- Ground escorts don't need heading/speed matching since they're taxiing
  local bomberOnGround = bomberAltitude < 100
  local escortOnGround = escortAltitude < 100
  
  -- If escort is on ground but bomber is airborne, escort cannot provide protection
  if escortOnGround and escortVelocity < 10 and not bomberOnGround then
    return "unrelated", details
  end
  
  if bomberOnGround and escortOnGround and distance <= closeRange then
    return "confirmed", details
  end
  
  -- DISTANCE-ONLY MODE (CRUISE and beyond): Escorts need tactical freedom
  -- Simply check if within range - no heading/altitude/speed checks
  if distanceOnlyMode then
    if distance <= closeRange then
      return "confirmed", details
    elseif distance <= mediumRange then
      return "probable", details
    elseif distance <= maxRange then
      return "passing", details
    else
      return "unrelated", details
    end
  end
  
  -- STRICT MODE (TAKING_OFF/CLIMBING): Verify escorts are actually joining up
  -- CONFIRMED: Close range with similar flight parameters (airborne)
  if distance <= closeRange and 
     headingDiff <= headingTol and 
     altDiff <= altTol and 
     speedDiff <= speedTol then
    return "confirmed", details
  end
  
  -- PROBABLE: Medium range with mostly similar parameters (2 of 3 match)
  if distance <= mediumRange then
    local matches = 0
    if headingDiff <= headingTol then matches = matches + 1 end
    if altDiff <= altTol then matches = matches + 1 end
    if speedDiff <= speedTol then matches = matches + 1 end
    
    if matches >= 2 then
      return "probable", details
    end
  end
  
  -- PASSING: Within range but clearly not escorting
  -- (opposite heading, significantly different speed/altitude)
  if distance <= maxRange then
    if headingDiff > 135 or speedDiff > speedTol * 2 or altDiff > altTol * 2 then
      return "passing", details
    end
    -- If within range but doesn't fit other categories, it's probable
    return "probable", details
  end
  
  -- UNRELATED: Too far away
  return "unrelated", details
end

--- Check for tight formation flying and send compliments
-- @param #BOMBER_ESCORT_MONITOR self
-- @param #table escortsFound Table of detected escorts with distance/details
-- @param #number currentTime Current mission time
function BOMBER_ESCORT_MONITOR:_CheckFormationFlying(escortsFound, currentTime)
  local formationRange = BOMBER_ESCORT_CONFIG.EscortFormationRange
  local complimentInterval = BOMBER_ESCORT_CONFIG.EscortFormationComplimentInterval
  
  -- Initialize tracking table if needed
  if not self.FormationFlyingTracker then
    self.FormationFlyingTracker = {}
  end
  
  -- Check each escort for tight formation flying
  for unitName, data in pairs(escortsFound) do
    local distance = data.Distance
    local details = data.Details
    
    -- Check if escort is in tight formation (within 250m and matching flight parameters)
    if distance <= formationRange then
      -- Require tight tolerances for formation flying compliment
      local headingMatch = details.headingDiff <= 15  -- Within 15 degrees
      local altMatch = details.altDiff <= 500         -- Within 500 feet
      local speedMatch = details.speedDiff <= 30      -- Within 30 knots
      
      if headingMatch and altMatch and speedMatch then
        -- Initialize tracker for this escort if needed
        if not self.FormationFlyingTracker[unitName] then
          self.FormationFlyingTracker[unitName] = {
            startTime = currentTime,
            lastComplimentTime = 0,
            inFormation = true
          }
          BASE:I(string.format("%s: %s entered tight formation (%.0fm)", 
            self.Bomber.Callsign, data.Unit:GetCallsign() or unitName, distance))
        end
        
        local tracker = self.FormationFlyingTracker[unitName]
        local formationDuration = currentTime - tracker.startTime
        local timeSinceLastCompliment = currentTime - tracker.lastComplimentTime
        
        -- Send compliment if they've been in formation for at least 3 minutes
        -- and we haven't complimented them in the last 3 minutes
        if formationDuration >= complimentInterval and timeSinceLastCompliment >= complimentInterval then
          local messages = BOMBER.FormationCompliments
          local message = messages[math.random(#messages)]
          local callsign = data.Unit:GetCallsign() or unitName
          
          self.Bomber:_BroadcastMessage(string.format("%s: %s (%s)", 
            self.Bomber.Callsign, message, callsign))
          
          tracker.lastComplimentTime = currentTime
          
          BASE:I(string.format("%s: Formation compliment sent to %s (%.0fm, %.0f min in formation)", 
            self.Bomber.Callsign, callsign, distance, formationDuration/60))
        end
      else
        -- Not matching parameters well enough, reset tracker
        if self.FormationFlyingTracker[unitName] then
          BASE:I(string.format("%s: %s no longer in tight formation (hdg:%s alt:%s spd:%s)", 
            self.Bomber.Callsign, data.Unit:GetCallsign() or unitName,
            tostring(headingMatch), tostring(altMatch), tostring(speedMatch)))
          self.FormationFlyingTracker[unitName] = nil
        end
      end
    else
      -- Too far for formation flying, clear tracker
      if self.FormationFlyingTracker[unitName] then
        BASE:I(string.format("%s: %s moved out of formation range (%.0fm > %dm)", 
          self.Bomber.Callsign, data.Unit:GetCallsign() or unitName, distance, formationRange))
        self.FormationFlyingTracker[unitName] = nil
      end
    end
  end
  
  -- Clean up trackers for escorts no longer detected
  for unitName, tracker in pairs(self.FormationFlyingTracker) do
    if not escortsFound[unitName] then
      BASE:I(string.format("%s: %s no longer detected, removing formation tracker", 
        self.Bomber.Callsign, unitName))
      self.FormationFlyingTracker[unitName] = nil
    end
  end
end

--- Get current escort status
-- @param #BOMBER_ESCORT_MONITOR self
-- @return #table Status {count, unescortedTime, escorts}
function BOMBER_ESCORT_MONITOR:GetStatus()
  return {
    Count = self.EscortCount,
    UnescortedDuration = self.UnescortedDuration,
    Escorts = self.EscortUnits,
    HasMinimumEscort = self.EscortCount >= self.MinEscorts
  }
end

---
-- BOMBER_THREAT_MANAGER - Detects and manages threats to bomber
-- @type BOMBER_THREAT_MANAGER
BOMBER_THREAT_MANAGER = {
  ClassName = "BOMBER_THREAT_MANAGER"
}

--- Threat types
BOMBER_THREAT_MANAGER.ThreatType = {
  SAM = "SAM",
  FIGHTER = "FIGHTER",
  AAA = "AAA",
  UNKNOWN = "UNKNOWN"
}

--- SAM threat database with engagement parameters
-- Ranges in meters, altitudes in feet
BOMBER_THREAT_MANAGER.SAMDatabase = {
  -- Short Range (SR) - Low to Medium altitude threats
  ["SA-2"] = {name = "SA-2 Guideline", maxRange = 45000, minAlt = 1000, maxAlt = 82000, threat = "MEDIUM"},
  ["SA-3"] = {name = "SA-3 Goa", maxRange = 25000, minAlt = 100, maxAlt = 45000, threat = "MEDIUM"},
  ["SA-6"] = {name = "SA-6 Gainful", maxRange = 24000, minAlt = 100, maxAlt = 45000, threat = "HIGH"},
  ["SA-8"] = {name = "SA-8 Gecko", maxRange = 15000, minAlt = 25, maxAlt = 16000, threat = "MEDIUM"},
  ["SA-9"] = {name = "SA-9 Gaskin", maxRange = 5500, minAlt = 25, maxAlt = 11000, threat = "LOW"},
  ["SA-11"] = {name = "SA-11 Gadfly", maxRange = 32000, minAlt = 100, maxAlt = 72000, threat = "HIGH"},
  ["SA-13"] = {name = "SA-13 Gopher", maxRange = 5000, minAlt = 25, maxAlt = 11000, threat = "LOW"},
  ["SA-15"] = {name = "SA-15 Gauntlet", maxRange = 12000, minAlt = 25, maxAlt = 20000, threat = "MEDIUM"},
  ["SA-19"] = {name = "SA-19 Grison", maxRange = 8000, minAlt = 25, maxAlt = 11000, threat = "MEDIUM"},
  
  -- Long Range (LR) - High altitude capable
  ["SA-10"] = {name = "SA-10 Grumble", maxRange = 75000, minAlt = 100, maxAlt = 100000, threat = "CRITICAL"},
  ["SA-20"] = {name = "SA-20 Gargoyle", maxRange = 120000, minAlt = 100, maxAlt = 100000, threat = "CRITICAL"},
  ["SA-17"] = {name = "SA-17 Grizzly", maxRange = 50000, minAlt = 100, maxAlt = 75000, threat = "HIGH"},
  
  -- Russian designations (DCS often uses these names)
  ["S-75"] = {name = "S-75 Dvina (SA-2)", maxRange = 45000, minAlt = 1000, maxAlt = 82000, threat = "MEDIUM"},
  ["S-125"] = {name = "S-125 Neva (SA-3)", maxRange = 25000, minAlt = 100, maxAlt = 45000, threat = "MEDIUM"},
  ["2K12"] = {name = "2K12 Kub (SA-6)", maxRange = 24000, minAlt = 100, maxAlt = 45000, threat = "HIGH"},
  ["9K33"] = {name = "9K33 Osa (SA-8)", maxRange = 15000, minAlt = 25, maxAlt = 16000, threat = "MEDIUM"},
  ["9K31"] = {name = "9K31 Strela-1 (SA-9)", maxRange = 5500, minAlt = 25, maxAlt = 11000, threat = "LOW"},
  ["9K37"] = {name = "9K37 Buk (SA-11)", maxRange = 32000, minAlt = 100, maxAlt = 72000, threat = "HIGH"},
  ["9K35"] = {name = "9K35 Strela-10 (SA-13)", maxRange = 5000, minAlt = 25, maxAlt = 11000, threat = "LOW"},
  ["9K330"] = {name = "9K330 Tor (SA-15)", maxRange = 12000, minAlt = 25, maxAlt = 20000, threat = "MEDIUM"},
  ["2K22"] = {name = "2K22 Tunguska (SA-19)", maxRange = 8000, minAlt = 25, maxAlt = 11000, threat = "MEDIUM"},
  ["S-300PS"] = {name = "S-300PS (SA-10)", maxRange = 75000, minAlt = 100, maxAlt = 100000, threat = "CRITICAL"},
  ["S-300PMU"] = {name = "S-300PMU (SA-10)", maxRange = 90000, minAlt = 100, maxAlt = 100000, threat = "CRITICAL"},
  ["S-400"] = {name = "S-400 Triumf (SA-21)", maxRange = 150000, minAlt = 100, maxAlt = 100000, threat = "CRITICAL"},
  ["9K317"] = {name = "9K317 Buk-M2 (SA-17)", maxRange = 50000, minAlt = 100, maxAlt = 75000, threat = "HIGH"},
  
  -- Western SAMs
  ["Hawk"] = {name = "MIM-23 Hawk", maxRange = 40000, minAlt = 200, maxAlt = 60000, threat = "MEDIUM"},
  ["Patriot"] = {name = "MIM-104 Patriot", maxRange = 80000, minAlt = 200, maxAlt = 80000, threat = "CRITICAL"},
  ["Roland"] = {name = "Roland", maxRange = 8000, minAlt = 20, maxAlt = 18000, threat = "MEDIUM"},
  ["Rapier"] = {name = "Rapier", maxRange = 8000, minAlt = 50, maxAlt = 10000, threat = "MEDIUM"},
  
  -- Generic fallback
  ["UNKNOWN"] = {name = "Unknown SAM", maxRange = 30000, minAlt = 100, maxAlt = 50000, threat = "MEDIUM"}
}

--- Create new threat manager
-- @param #BOMBER_THREAT_MANAGER self
-- @param #BOMBER bomber The bomber instance
-- @return #BOMBER_THREAT_MANAGER
function BOMBER_THREAT_MANAGER:New(bomber)
  local self = BASE:Inherit(self, BASE:New())
  
  self.Bomber = bomber
  self.ActiveThreats = {}
  self.ThreatHistory = {}
  self.CheckInterval = 10 -- seconds
  self.SAMThreatRange = 30000 -- meters (roughly SA-2/SA-6 range)
  self.FighterThreatRange = 50000 -- meters
  self.AAAThreatRange = 5000 -- meters
  
  return self
end

--- Start threat monitoring
-- @param #BOMBER_THREAT_MANAGER self
function BOMBER_THREAT_MANAGER:Start()
  self.SchedulerID = SCHEDULER:New(nil, self._ScanThreats, {self}, 3, self.CheckInterval)
  return self
end

--- Stop threat monitoring
-- @param #BOMBER_THREAT_MANAGER self
function BOMBER_THREAT_MANAGER:Stop()
  if self.SchedulerID then
    self.SchedulerID:Stop()
  end
  return self
end

--- Scan for threats around bomber
-- @param #BOMBER_THREAT_MANAGER self
function BOMBER_THREAT_MANAGER:_ScanThreats()
  if not self.Bomber or not self.Bomber:IsAlive() then
    self:Stop()
    return
  end
  
  local bomberGroup = self.Bomber.Group
  if not bomberGroup then return end
  
  local bomberCoord = bomberGroup:GetCoordinate()
  if not bomberCoord then return end
  
  local currentTime = timer.getTime()
  local threatsFound = {}
  
  -- Get enemy coalition
  local enemyCoalition = self.Bomber.Coalition == coalition.side.BLUE and coalition.side.RED or coalition.side.BLUE
  
  -- Scan for SAM threats
  local samScan = SET_GROUP:New()
    :FilterCoalitions(enemyCoalition)
    :FilterCategories("ground")
    :FilterOnce()
  
  samScan:ForEachGroup(function(group)
    if group:IsAlive() then
      -- Check if group has SAM attributes
      local unit = group:GetUnit(1)
      if unit and (unit:HasAttribute("SAM") or unit:HasAttribute("Air Defence")) then
        local groupCoord = group:GetCoordinate()
        if groupCoord then
          local distance = bomberCoord:Get2DDistance(groupCoord)
          
          if distance <= self.SAMThreatRange then
            local threatId = group:GetName()
            local typeName = unit:GetTypeName()
            
            -- Identify SAM type and get threat data
            local samData = self:_IdentifySAM(typeName)
            local bomberAltFeet = self.Bomber.Group:GetAltitude() * 3.28084 -- meters to feet
            
            -- Assess if this SAM can actually engage at current altitude and range
            local canEngage = self:_CanSAMEngage(samData, distance, bomberAltFeet)
            local effectiveThreat = self:_CalculateEffectiveThreat(samData, distance, bomberAltFeet)
            
            threatsFound[threatId] = {
              Type = BOMBER_THREAT_MANAGER.ThreatType.SAM,
              Group = group,
              Distance = distance,
              Bearing = self:_GetBearing(bomberCoord, groupCoord),
              Time = currentTime,
              SAMType = samData.name,
              SAMData = samData,
              CanEngage = canEngage,
              ThreatLevel = effectiveThreat,
              BomberAlt = bomberAltFeet
            }
          end
        end
      end
    end
  end)
  
  -- Scan for fighter threats
  local fighterScan = SET_GROUP:New()
    :FilterCoalitions(enemyCoalition)
    :FilterCategories("plane")
    :FilterOnce()
  
  fighterScan:ForEachGroup(function(group)
    if group:IsAlive() and group:InAir() then
      -- Check if this is actually a fighter/attacker, not a bomber
      local groupType = group:GetTypeName()
      local isBomber = groupType and (string.find(string.upper(groupType), "B-52") or 
                                       string.find(string.upper(groupType), "B-1") or
                                       string.find(string.upper(groupType), "TU-95") or
                                       string.find(string.upper(groupType), "TU-22") or
                                       string.find(string.upper(groupType), "TU-160") or
                                       string.find(string.upper(groupType), "B-17") or
                                       string.find(string.upper(groupType), "B-24"))
      
      if not isBomber then
        local groupCoord = group:GetCoordinate()
        if groupCoord then
          local distance = bomberCoord:Get2DDistance(groupCoord)
          
          if distance <= self.FighterThreatRange then
            local threatId = group:GetName()
            threatsFound[threatId] = {
              Type = BOMBER_THREAT_MANAGER.ThreatType.FIGHTER,
              Group = group,
              Distance = distance,
              Bearing = self:_GetBearing(bomberCoord, groupCoord),
              Time = currentTime
            }
          end
        end
      end
    end
  end)
  
  -- Update threat tracking
  self:_UpdateThreats(threatsFound)
end

--- Update threat tracking and notify bomber
-- @param #BOMBER_THREAT_MANAGER self
-- @param #table newThreats Newly detected threats
function BOMBER_THREAT_MANAGER:_UpdateThreats(newThreats)
  -- Check for new threats
  for threatId, threatData in pairs(newThreats) do
    if not self.ActiveThreats[threatId] then
      -- New threat detected
      self.ActiveThreats[threatId] = threatData
      self.Bomber:OnThreatDetected(threatData)
      
      -- Add to history
      table.insert(self.ThreatHistory, {
        ThreatId = threatId,
        Type = threatData.Type,
        TimeDetected = threatData.Time
      })
    else
      -- Update existing threat
      self.ActiveThreats[threatId] = threatData
    end
  end
  
  -- Check for cleared threats
  for threatId, threatData in pairs(self.ActiveThreats) do
    if not newThreats[threatId] then
      -- Threat no longer detected
      self.Bomber:OnThreatCleared(threatData)
      self.ActiveThreats[threatId] = nil
    end
  end
end

--- Identify SAM type from unit type name
-- @param #BOMBER_THREAT_MANAGER self
-- @param #string typeName Unit type name from DCS
-- @return #table SAM data from database
function BOMBER_THREAT_MANAGER:_IdentifySAM(typeName)
  if not typeName then
    return BOMBER_THREAT_MANAGER.SAMDatabase["UNKNOWN"]
  end
  
  local typeUpper = string.upper(typeName)
  
  -- Match against known SAM systems
  for samKey, samData in pairs(BOMBER_THREAT_MANAGER.SAMDatabase) do
    if samKey ~= "UNKNOWN" then
      local keyUpper = string.upper(samKey)
      -- Check for SAM designation in unit name
      if string.find(typeUpper, keyUpper) or string.find(typeUpper, string.gsub(keyUpper, "-", "")) then
        return samData
      end
    end
  end
  
  -- Check for specific DCS unit names
  if string.find(typeUpper, "S%-300") or string.find(typeUpper, "S300") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["SA-10"]
  elseif string.find(typeUpper, "S%-400") or string.find(typeUpper, "S400") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["SA-20"]
  elseif string.find(typeUpper, "BUK") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["SA-11"]
  elseif string.find(typeUpper, "KUB") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["SA-6"]
  elseif string.find(typeUpper, "TOR") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["SA-15"]
  elseif string.find(typeUpper, "OSA") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["SA-8"]
  elseif string.find(typeUpper, "TUNGUSKA") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["SA-19"]
  elseif string.find(typeUpper, "HAWK") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["Hawk"]
  elseif string.find(typeUpper, "PATRIOT") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["Patriot"]
  elseif string.find(typeUpper, "ROLAND") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["Roland"]
  elseif string.find(typeUpper, "RAPIER") then
    return BOMBER_THREAT_MANAGER.SAMDatabase["Rapier"]
  end
  
  return BOMBER_THREAT_MANAGER.SAMDatabase["UNKNOWN"]
end

--- Check if SAM can engage bomber at current range and altitude
-- @param #BOMBER_THREAT_MANAGER self
-- @param #table samData SAM data from database
-- @param #number distance Distance to SAM in meters
-- @param #number altitude Bomber altitude in feet
-- @return #boolean True if SAM can engage
function BOMBER_THREAT_MANAGER:_CanSAMEngage(samData, distance, altitude)
  if not samData then return false end
  
  -- Check range
  if distance > samData.maxRange then
    return false
  end
  
  -- Check altitude envelope
  if altitude < samData.minAlt or altitude > samData.maxAlt then
    return false
  end
  
  return true
end

--- Calculate effective threat level considering range and altitude
-- @param #BOMBER_THREAT_MANAGER self
-- @param #table samData SAM data from database
-- @param #number distance Distance to SAM in meters
-- @param #number altitude Bomber altitude in feet
-- @return #string Threat level: "CRITICAL", "HIGH", "MEDIUM", "LOW", "NONE"
function BOMBER_THREAT_MANAGER:_CalculateEffectiveThreat(samData, distance, altitude)
  if not samData then return "NONE" end
  
  -- Not within engagement envelope
  if not self:_CanSAMEngage(samData, distance, altitude) then
    -- Close to envelope edges might still be concerning
    if distance <= samData.maxRange * 1.1 then
      return "LOW" -- Just outside range
    end
    return "NONE"
  end
  
  -- Within envelope - assess based on range percentage and base threat
  local rangePercent = distance / samData.maxRange
  local baseThreat = samData.threat
  
  -- Optimal engagement range for SAMs is typically 30-70% of max range
  if rangePercent < 0.3 then
    -- Very close - highest threat
    if baseThreat == "CRITICAL" then return "CRITICAL" end
    if baseThreat == "HIGH" then return "CRITICAL" end
    return "HIGH"
  elseif rangePercent < 0.7 then
    -- Optimal range - use base threat
    return baseThreat
  else
    -- Near max range - reduced threat
    if baseThreat == "CRITICAL" then return "HIGH" end
    if baseThreat == "HIGH" then return "MEDIUM" end
    return "LOW"
  end
end

--- Get bearing from bomber to threat
-- @param #BOMBER_THREAT_MANAGER self
-- @param #COORDINATE fromCoord Bomber position
-- @param #COORDINATE toCoord Threat position
-- @return #number Bearing in degrees
function BOMBER_THREAT_MANAGER:_GetBearing(fromCoord, toCoord)
  local heading = fromCoord:HeadingTo(toCoord)
  return heading
end

--- Get active threats by type
-- @param #BOMBER_THREAT_MANAGER self
-- @param #string threatType Optional filter by type
-- @return #table Active threats
function BOMBER_THREAT_MANAGER:GetActiveThreats(threatType)
  if not threatType then
    return self.ActiveThreats
  end
  
  local filtered = {}
  for threatId, threatData in pairs(self.ActiveThreats) do
    if threatData.Type == threatType then
      filtered[threatId] = threatData
    end
  end
  return filtered
end

--- Check if under immediate threat
-- @param #BOMBER_THREAT_MANAGER self
-- @return #boolean True if critical threats nearby
function BOMBER_THREAT_MANAGER:IsUnderThreat()
  -- Check for close SAM threats
  for _, threat in pairs(self.ActiveThreats) do
    if threat.Type == BOMBER_THREAT_MANAGER.ThreatType.SAM and threat.Distance < 25000 then
      return true
    end
    if threat.Type == BOMBER_THREAT_MANAGER.ThreatType.FIGHTER and threat.Distance < 15000 then
      return true
    end
  end
  return false
end

---
-- BOMBER_SAM_AVOIDANCE_ROUTER - Dynamic SAM threat avoidance and corridor detection
-- @type BOMBER_SAM_AVOIDANCE_ROUTER
BOMBER_SAM_AVOIDANCE_ROUTER = {
  ClassName = "BOMBER_SAM_AVOIDANCE_ROUTER"
}

--- Create new SAM avoidance router
-- @param #BOMBER_SAM_AVOIDANCE_ROUTER self
-- @param #BOMBER bomber The bomber instance
-- @return #BOMBER_SAM_AVOIDANCE_ROUTER
function BOMBER_SAM_AVOIDANCE_ROUTER:New(bomber)
  local self = BASE:Inherit(self, BASE:New())
  
  self.Bomber = bomber
  self.LastRouteCheck = 0
  self.ActiveDetours = {}
  self.RouteHistory = {}
  
  return self
end

--- Analyze route for SAM threats and find safe corridors
-- @param #BOMBER_SAM_AVOIDANCE_ROUTER self
-- @param #COORDINATE fromCoord Starting position
-- @param #COORDINATE toCoord Destination
-- @param #table samThreats Active SAM threats from threat manager
-- @return #table Route analysis: {isSafe, threats, corridors, recommendation}
function BOMBER_SAM_AVOIDANCE_ROUTER:AnalyzeRoute(fromCoord, toCoord, samThreats)
  if not BOMBER_ESCORT_CONFIG.EnableSAMAvoidance then
    return {isSafe = true, threats = {}, corridors = {}, recommendation = "SAM avoidance disabled"}
  end
  
  local directDistance = fromCoord:Get2DDistance(toCoord)
  local directHeading = fromCoord:HeadingTo(toCoord)
  local bomberAlt = self.Bomber.Group:GetAltitude() * 3.28084 -- meters to feet
  
  -- Build threat zones from active SAMs
  local threatZones = {}
  local threatsOnRoute = {}
  
  for threatId, threat in pairs(samThreats) do
    if threat.Type == BOMBER_THREAT_MANAGER.ThreatType.SAM then
      -- Only consider SAMs that can engage at current altitude if configured
      local shouldProcess = true
      if BOMBER_ESCORT_CONFIG.SAMAvoidOnlyIfCanEngage and not threat.CanEngage then
        -- Skip this SAM, it's harmless at our altitude
        shouldProcess = false
      end
      
      if shouldProcess then
        local samCoord = threat.Group:GetCoordinate()
        if samCoord then
          local samData = threat.SAMData or BOMBER_THREAT_MANAGER.SAMDatabase["UNKNOWN"]
          local threatRadius = samData.maxRange + BOMBER_ESCORT_CONFIG.SAMAvoidanceBuffer
          
          -- Check if this SAM threatens the direct route
          local distanceToRoute = self:_PointToLineDistance(samCoord, fromCoord, toCoord)
          
          if distanceToRoute < threatRadius then
            table.insert(threatsOnRoute, {
              id = threatId,
              coord = samCoord,
              radius = threatRadius,
              samType = threat.SAMType,
              threatLevel = threat.ThreatLevel,
              distanceToRoute = distanceToRoute,
              threat = threat
            })
          end
          
          table.insert(threatZones, {
            id = threatId,
            coord = samCoord,
            radius = threatRadius,
            samType = threat.SAMType
          })
        end
      end
    end
  end
  
  -- If no threats on direct route, we're clear
  if #threatsOnRoute == 0 then
    return {
      isSafe = true,
      threats = {},
      corridors = {},
      recommendation = "Direct route clear",
      directDistance = directDistance
    }
  end
  
  -- Try to find corridors through the SAM field
  local corridors = self:_FindCorridors(fromCoord, toCoord, threatZones)
  
  -- Evaluate best route option
  local recommendation = self:_EvaluateRouteOptions(fromCoord, toCoord, directDistance, threatsOnRoute, corridors)
  
  return {
    isSafe = (recommendation.action ~= "ABORT"),
    threats = threatsOnRoute,
    corridors = corridors,
    recommendation = recommendation,
    directDistance = directDistance
  }
end

--- Find safe corridors between SAM threat zones
-- @param #BOMBER_SAM_AVOIDANCE_ROUTER self
-- @param #COORDINATE fromCoord Start
-- @param #COORDINATE toCoord End
-- @param #table threatZones Array of SAM threat zones
-- @return #table Array of corridor options with waypoints
function BOMBER_SAM_AVOIDANCE_ROUTER:_FindCorridors(fromCoord, toCoord, threatZones)
  local corridors = {}
  
  if #threatZones == 0 then
    return corridors
  end
  
  -- Try different approach angles to find gaps
  local directHeading = fromCoord:HeadingTo(toCoord)
  local testAngles = {-45, -30, -15, 15, 30, 45, -60, 60, -90, 90} -- Degrees offset from direct
  
  for _, angleOffset in ipairs(testAngles) do
    local testHeading = (directHeading + angleOffset) % 360
    local corridor = self:_TestCorridorPath(fromCoord, toCoord, testHeading, threatZones)
    
    if corridor.isValid then
      table.insert(corridors, corridor)
    end
  end
  
  -- Sort corridors by total distance (prefer shorter detours)
  table.sort(corridors, function(a, b) return a.totalDistance < b.totalDistance end)
  
  return corridors
end

--- Test a specific corridor path through SAM field
-- @param #BOMBER_SAM_AVOIDANCE_ROUTER self
-- @param #COORDINATE fromCoord Start
-- @param #COORDINATE toCoord End  
-- @param #number heading Test heading in degrees
-- @param #table threatZones SAM threat zones
-- @return #table Corridor data {isValid, waypoints, totalDistance}
function BOMBER_SAM_AVOIDANCE_ROUTER:_TestCorridorPath(fromCoord, toCoord, heading, threatZones)
  local directDistance = fromCoord:Get2DDistance(toCoord)
  local maxDetourDist = math.min(
    directDistance * (BOMBER_ESCORT_CONFIG.SAMMaxDetourPercent / 100),
    BOMBER_ESCORT_CONFIG.SAMMaxDetourAbsolute
  )
  
  -- Project waypoint along test heading
  local testDistance = directDistance * 0.7 -- Go 70% of the way on this heading
  local waypointCoord = fromCoord:Translate(testDistance, heading)
  
  -- Check if waypoint avoids all threat zones
  local safe = true
  for _, zone in ipairs(threatZones) do
    local distToZone = waypointCoord:Get2DDistance(zone.coord)
    if distToZone < zone.radius then
      safe = false
      break
    end
  end
  
  if not safe then
    return {isValid = false}
  end
  
  -- Check if path from waypoint to target is clear
  for _, zone in ipairs(threatZones) do
    local distToRoute = self:_PointToLineDistance(zone.coord, waypointCoord, toCoord)
    if distToRoute < zone.radius then
      safe = false
      break
    end
  end
  
  if not safe then
    return {isValid = false}
  end
  
  -- Calculate total distance
  local leg1 = fromCoord:Get2DDistance(waypointCoord)
  local leg2 = waypointCoord:Get2DDistance(toCoord)
  local totalDistance = leg1 + leg2
  
  -- Check if detour is within acceptable limits
  if (totalDistance - directDistance) > maxDetourDist then
    return {isValid = false, reason = "Detour too long"}
  end
  
  return {
    isValid = true,
    waypoints = {waypointCoord},
    totalDistance = totalDistance,
    detourDistance = totalDistance - directDistance,
    heading = heading
  }
end

--- Calculate distance from point to line segment
-- @param #BOMBER_SAM_AVOIDANCE_ROUTER self
-- @param #COORDINATE point Point coordinate
-- @param #COORDINATE lineStart Line start
-- @param #COORDINATE lineEnd Line end
-- @return #number Distance in meters
function BOMBER_SAM_AVOIDANCE_ROUTER:_PointToLineDistance(point, lineStart, lineEnd)
  local px, py = point.x, point.z
  local x1, y1 = lineStart.x, lineStart.z
  local x2, y2 = lineEnd.x, lineEnd.z
  
  local dx = x2 - x1
  local dy = y2 - y1
  
  if dx == 0 and dy == 0 then
    -- Line is actually a point
    return point:Get2DDistance(lineStart)
  end
  
  -- Calculate the t parameter (projection of point onto line)
  local t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)
  
  -- Clamp t to [0, 1] to stay on line segment
  t = math.max(0, math.min(1, t))
  
  -- Find closest point on line
  local closestX = x1 + t * dx
  local closestY = y1 + t * dy
  
  -- Calculate distance
  local dist = math.sqrt((px - closestX)^2 + (py - closestY)^2)
  
  return dist
end

--- Evaluate route options and recommend action
-- @param #BOMBER_SAM_AVOIDANCE_ROUTER self
-- @param #COORDINATE fromCoord Start
-- @param #COORDINATE toCoord End
-- @param #number directDistance Direct distance in meters
-- @param #table threatsOnRoute SAMs threatening direct route
-- @param #table corridors Available safe corridors
-- @return #table Recommendation {action, route, message, distance}
function BOMBER_SAM_AVOIDANCE_ROUTER:_EvaluateRouteOptions(fromCoord, toCoord, directDistance, threatsOnRoute, corridors)
  
  -- Check if we have viable corridors
  if #corridors > 0 then
    local bestCorridor = corridors[1] -- Already sorted by distance
    
    -- Check fuel viability
    local fuelCheck = self:_CheckFuelViability(bestCorridor.totalDistance)
    
    if fuelCheck.viable then
      return {
        action = "REROUTE",
        route = bestCorridor,
        message = string.format("Rerouting through corridor (detour +%d km) to avoid %d SAM site%s",
          math.floor(bestCorridor.detourDistance / 1000),
          #threatsOnRoute,
          #threatsOnRoute > 1 and "s" or ""),
        distance = bestCorridor.totalDistance,
        detour = bestCorridor.detourDistance,
        fuelRemaining = fuelCheck.percentRemaining
      }
    else
      return {
        action = "ABORT",
        route = nil,
        message = string.format("Insufficient fuel for SAM avoidance (need %d%%, have %d%%) - RTB",
          BOMBER_ESCORT_CONFIG.SAMFuelReservePercent,
          math.floor(fuelCheck.percentRemaining)),
        distance = 0,
        reason = "FUEL"
      }
    end
  end
  
  -- No safe corridors found
  local maxDetour = BOMBER_ESCORT_CONFIG.SAMMaxDetourAbsolute
  
  -- Describe the SAM wall
  local samTypes = {}
  for _, threat in ipairs(threatsOnRoute) do
    table.insert(samTypes, threat.samType)
  end
  
  return {
    action = "ABORT",
    route = nil,
    message = string.format("No safe corridor found through SAM field (%s) - RTB",
      table.concat(samTypes, ", ")),
    distance = 0,
    reason = "SAM_WALL"
  }
end

--- Check if bomber has enough fuel for detour
-- @param #BOMBER_SAM_AVOIDANCE_ROUTER self
-- @param #number plannedDistance Planned route distance in meters
-- @return #table {viable, percentRemaining, reason}
function BOMBER_SAM_AVOIDANCE_ROUTER:_CheckFuelViability(plannedDistance)
  if not self.Bomber.Group or not self.Bomber.Group:IsAlive() then
    return {viable = false, percentRemaining = 0, reason = "Group not alive"}
  end
  
  local unit = self.Bomber.Group:GetUnit(1)
  if not unit then
    return {viable = false, percentRemaining = 0, reason = "No unit"}
  end
  
  local fuelRemaining = unit:GetFuel() -- Returns 0.0 to 1.0
  local percentRemaining = fuelRemaining * 100
  
  -- Need reserve plus percentage for detour
  local requiredPercent = BOMBER_ESCORT_CONFIG.SAMFuelReservePercent
  
  if percentRemaining >= requiredPercent then
    return {
      viable = true,
      percentRemaining = percentRemaining,
      reason = "Sufficient fuel"
    }
  else
    return {
      viable = false,
      percentRemaining = percentRemaining,
      reason = string.format("Only %.0f%% fuel remaining, need %.0f%%", percentRemaining, requiredPercent)
    }
  end
end

---
-- BOMBER_MISSION_MANAGER - Manages multiple concurrent bomber missions
-- @type BOMBER_MISSION_MANAGER
BOMBER_MISSION_MANAGER = {
  ClassName = "BOMBER_MISSION_MANAGER"
}

--- Create new mission manager
-- @param #BOMBER_MISSION_MANAGER self
-- @return #BOMBER_MISSION_MANAGER
function BOMBER_MISSION_MANAGER:New()
  local self = BASE:Inherit(self, BASE:New())
  
  self.ActiveMissions = {}
  self.MissionCounter = 0
  self.CompletedMissions = {}
  self.Menus = {}
  
  -- Create F10 menus for each coalition
  self:_InitializeMenus()
  
  return self
end

--- Initialize F10 menus
-- @param #BOMBER_MISSION_MANAGER self
function BOMBER_MISSION_MANAGER:_InitializeMenus()
  -- Check if MenuManager exists for integration
  local useMenuManager = (MenuManager ~= nil)
  
  -- Create menus for both coalitions
  for _, coalitionSide in ipairs({coalition.side.BLUE, coalition.side.RED}) do
    local coalitionName = (coalitionSide == coalition.side.BLUE) and "BLUE" or "RED"
    
    -- Create parent menu
    local parentMenu
    if useMenuManager then
      parentMenu = MenuManager.CreateCoalitionMenu(coalitionSide, "Bomber Missions")
    else
      parentMenu = MENU_COALITION:New(coalitionSide, "Bomber Missions")
    end
    
    -- Store menu reference
    self.Menus[coalitionSide] = {
      Parent = parentMenu,
      StatusCommand = nil,
      GuideCommand = nil,
      LaunchCommand = nil,
      RespawnCommand = nil
    }
    
    -- Add "Launch Bomber Mission" command (validates and spawns from markers)
    self.Menus[coalitionSide].LaunchCommand = MENU_COALITION_COMMAND:New(
      coalitionSide,
      "Launch Bomber Mission",
      parentMenu,
      function()
        if _BOMBER_MARKER_SYSTEM then
          _BOMBER_MARKER_SYSTEM:_CheckMarkers()
        else
          MESSAGE:New("Bomber system not initialized", 10):ToCoalition(coalitionSide)
        end
      end
    )
    
    -- Add "Respawn Last Mission" command
    self.Menus[coalitionSide].RespawnCommand = MENU_COALITION_COMMAND:New(
      coalitionSide,
      "Respawn Last Mission",
      parentMenu,
      function()
        if _BOMBER_MARKER_SYSTEM then
          _BOMBER_MARKER_SYSTEM:_RespawnLastMission(coalitionSide)
        else
          MESSAGE:New("Bomber system not initialized", 10):ToCoalition(coalitionSide)
        end
      end
    )
    
    -- Add "Mission Status" command
    self.Menus[coalitionSide].StatusCommand = MENU_COALITION_COMMAND:New(
      coalitionSide,
      "Mission Status",
      parentMenu,
      function()
        self:_ShowMissionStatus(coalitionSide)
      end
    )
    
    -- Add "Player Guide" command
    self.Menus[coalitionSide].GuideCommand = MENU_COALITION_COMMAND:New(
      coalitionSide,
      "Quick Start Guide",
      parentMenu,
      function()
        self:_ShowPlayerGuide(coalitionSide)
      end
    )
    
    BASE:I(string.format("Bomber F10 menus created for %s coalition", coalitionName))
  end
end

--- Show mission status for coalition
-- @param #BOMBER_MISSION_MANAGER self
-- @param #number coalitionSide Coalition side
function BOMBER_MISSION_MANAGER:_ShowMissionStatus(coalitionSide)
  local missions = self:GetActiveMissions(coalitionSide)
  
  if #missions == 0 then
    -- No active missions
    local message = "═══════════════════════════════\n" ..
                   "📋 BOMBER MISSION STATUS\n" ..
                   "═══════════════════════════════\n\n" ..
                   "[X] NO ACTIVE MISSIONS\n\n" ..
                   "To create a bomber mission:\n" ..
                   "1. Place BOMBER1:[Type] marker on airbase\n" ..
                   "2. Place TARGET1 marker on target\n" ..
                   "3. Mission spawns automatically!\n\n" ..
                   "📖 Use 'Quick Start Guide' for details\n" ..
                   "═══════════════════════════════"
    
    MESSAGE:New(message, BOMBER_ESCORT_CONFIG.MessageDuration):ToCoalition(coalitionSide)
  else
    -- Build status for each active mission
    local statusLines = {
      "═══════════════════════════════",
      "📋 BOMBER MISSION STATUS",
      "═══════════════════════════════",
      ""
    }
    
    for i, mission in ipairs(missions) do
      -- Get bomber group status
      local bomberStatus = "UNKNOWN"
      local bomberCount = "?"
      local currentTask = "Unknown"
      
      if mission.Bomber and mission.Bomber.Group then
        local group = mission.Bomber.Group
        if group:IsAlive() then
          bomberCount = tostring(group:CountAliveUnits())
          bomberStatus = "ACTIVE"
          
          -- Use FSM state for current task display
          local state = mission.Bomber:GetState()
          if state == "Spawned" then
            currentTask = "Spawned"
          elseif state == "Holding" then
            currentTask = "Waiting for Escort"
          elseif state == "EngineStarting" then
            currentTask = "Starting Engines"
          elseif state == "Taxiing" then
            currentTask = "Taxiing"
          elseif state == "Blocked" then
            currentTask = "Blocked on Taxiway"
          elseif state == "TakingOff" then
            currentTask = "Taking Off"
          elseif state == "Climbing" then
            currentTask = "Climbing to Cruise"
          elseif state == "Cruise" then
            currentTask = "En Route to Target"
          elseif state == "PreAttack" then
            currentTask = "Approaching Target"
          elseif state == "Attacking" then
            currentTask = "Attacking Target"
          elseif state == "Egressing" then
            currentTask = "Egressing"
          elseif state == "Aborting" then
            currentTask = "Aborting Mission"
          elseif state == "RTB" then
            currentTask = "Returning to Base"
          elseif state == "Landed" then
            currentTask = "Landed"
          elseif state == "Destroyed" then
            currentTask = "Destroyed"
          else
            currentTask = "Unknown State"
          end
        else
          bomberStatus = "LOST"
          bomberCount = "0"
          currentTask = "Destroyed"
        end
      end
      
      -- Build target info
      local targetInfo = ""
      if mission.Targets and #mission.Targets > 0 then
        if #mission.Targets == 1 then
          local target = mission.Targets[1]
          if target.airbaseName then
            targetInfo = target.airbaseName
          else
            targetInfo = "Coordinates"
          end
        else
          targetInfo = string.format("%d Targets", #mission.Targets)
        end
      else
        targetInfo = "Unknown"
      end
      
      -- Add mission info
      table.insert(statusLines, string.format("[AC] MISSION %d: %s", i, mission.Callsign or "Unknown"))
      table.insert(statusLines, string.format("   Aircraft: %s x%s", mission.BomberType or "Unknown", bomberCount))
      table.insert(statusLines, string.format("   Target: %s", targetInfo))
      table.insert(statusLines, string.format("   Status: %s", currentTask))
      
      if i < #missions then
        table.insert(statusLines, "")
      end
    end
    
    table.insert(statusLines, "")
    table.insert(statusLines, "═══════════════════════════════")
    
    local message = table.concat(statusLines, "\n")
    MESSAGE:New(message, BOMBER_ESCORT_CONFIG.MessageDuration):ToCoalition(coalitionSide)
  end
end

--- Show player guide for coalition
-- @param #BOMBER_MISSION_MANAGER self
-- @param #number coalitionSide Coalition side
function BOMBER_MISSION_MANAGER:_ShowPlayerGuide(coalitionSide)
  local guide = {
    "═══════════════════════════════",
    "📖 BOMBER MISSION QUICK START",
    "═══════════════════════════════",
    "",
    "🎯 CREATING A MISSION:",
    "",
    "1️⃣ BOMBER1:[Type]",
    "   Place on or near your airbase",
    "   Example: BOMBER1:B-52H",
    "",
    "2️⃣ TARGET1",
    "   Place on enemy target",
    "   Auto-detects runways within 3km",
    "",
    "3️⃣ Done! Mission spawns automatically",
    "",
    "───────────────────────────────",
    "📝 ADVANCED OPTIONS:",
    "",
    "BOMBER1:B-17G:4:FL200:180",
    "        └─┬─┘ └┬┘ └─┬─┘ └┬┘",
    "          │    │    │    └─ Speed (knots)",
    "          │    │    └────── Altitude (feet)",
    "          │    └─────────── Flight size (1-6)",
    "          └──────────────── Aircraft type",
    "",
    "───────────────────────────────",
    "🛣️ ROUTE CONTROL:",
    "",
    "BOMBER2, BOMBER3... = Ingress route",
    "EGRESS1, EGRESS2... = Egress route",
    "RTB1 = Return to base point",
    "",
    "───────────────────────────────",
    "🎯 TARGET TYPES:",
    "",
    "TARGET1:RUNWAY:270",
    "  -> Carpet bomb runway from heading 270°",
    "",
    "TARGET1:BUILDING / BRIDGE",
    "  -> Point target attack",
    "",
    "TARGET2, TARGET3...",
    "  -> Multiple targets in sequence",
    "",
    "───────────────────────────────",
    "[AC] AVAILABLE AIRCRAFT:",
    "",
    "WWII: B-17G, B-24J (4 aircraft default)",
    "Modern: B-52H, B-1B (1 aircraft default)",
    "Soviet: Tu-95, Tu-22M3",
    "",
    "───────────────────────────────",
    "🔄 QUICK RESPAWN:",
    "",
    "RESPAWN1 = Repeat last mission",
    "",
    "═══════════════════════════════",
    "For complete guide, see:",
    "MARKER_GUIDE.md",
    "═══════════════════════════════"
  }
  
  local message = table.concat(guide, "\n")
  MESSAGE:New(message, 30):ToCoalition(coalitionSide)
end

--- Register a new mission
-- @param #BOMBER_MISSION_MANAGER self
-- @param #BOMBER_MISSION mission The mission to register
function BOMBER_MISSION_MANAGER:RegisterMission(mission)
  self.MissionCounter = self.MissionCounter + 1
  mission.MissionID = self.MissionCounter
  self.ActiveMissions[mission.MissionID] = mission
  
  BASE:I(string.format("Mission %d registered: %s", mission.MissionID, mission.Callsign))
end

--- Unregister a completed mission
-- @param #BOMBER_MISSION_MANAGER self
-- @param #BOMBER_MISSION mission The mission to unregister
function BOMBER_MISSION_MANAGER:UnregisterMission(mission)
  if self.ActiveMissions[mission.MissionID] then
    self.ActiveMissions[mission.MissionID] = nil
    table.insert(self.CompletedMissions, {
      MissionID = mission.MissionID,
      Callsign = mission.Callsign,
      Success = mission.MissionSuccess,
      EndTime = timer.getTime()
    })
    BASE:I(string.format("Mission %d completed: %s", mission.MissionID, mission.Callsign))
  end
end

--- Get active missions for coalition
-- @param #BOMBER_MISSION_MANAGER self
-- @param #number coalitionSide Coalition side
-- @return #table Array of active missions
function BOMBER_MISSION_MANAGER:GetActiveMissions(coalitionSide)
  local missions = {}
  for _, mission in pairs(self.ActiveMissions) do
    if not coalitionSide or mission.Coalition == coalitionSide then
      table.insert(missions, mission)
    end
  end
  return missions
end

---
-- BOMBER_MISSION - Individual bomber mission with route and objectives
-- @type BOMBER_MISSION
BOMBER_MISSION = {
  ClassName = "BOMBER_MISSION"
}

--- Create new bomber mission
-- @param #BOMBER_MISSION self
-- @param #table missionData Mission parameters from marker system
-- @return #BOMBER_MISSION
function BOMBER_MISSION:New(missionData)
  local self = BASE:Inherit(self, BASE:New())
  
  self.MissionData = missionData
  self.Coalition = missionData.Coalition
  self.BomberType = missionData.BomberType or "B-52H"
  self.FlightSize = missionData.FlightSize or 2
  self.Callsign = self:_GenerateCallsign()
  
  -- Mission locations
  self.StartAirbase = missionData.StartAirbase
  self.StartPos = missionData.StartPos
  self.Targets = missionData.Targets or {}
  self.RouteWaypoints = missionData.RouteWaypoints or {}
  self.EgressWaypoints = missionData.EgressWaypoints or {}
  self.RTBWaypoint = missionData.RTBWaypoint or nil
  
  -- Mission parameters
  self.CruiseAlt = missionData.CruiseAlt
  self.CruiseSpeed = missionData.CruiseSpeed
  
  -- Status
  self.MissionActive = false
  self.MissionSuccess = false
  self.CurrentState = "SPAWNED"
  self.Bomber = nil
  
  -- Player menu
  self.PlayerMenu = nil
  
  return self
end

--- Start the mission
-- @param #BOMBER_MISSION self
-- @return #boolean Success
function BOMBER_MISSION:Start()
  BASE:I(string.format("Starting mission: %s", self.Callsign))
  
  -- Create template name from bomber type
  local templateName = self:_GetTemplateName()
  
  -- Create full mission data for bomber
  local bomberMissionData = {
    Coalition = self.Coalition,
    BomberType = self.BomberType,
    FlightSize = self.FlightSize,
    StartAirbase = self.StartAirbase,
    StartPos = self.StartPos,
    Targets = self.Targets,
    TargetZone = self:_CreateTargetZone(),
    CruiseAlt = self.CruiseAlt,
    CruiseSpeed = self.CruiseSpeed,
    RouteWaypoints = self.RouteWaypoints,
    EgressWaypoints = self.EgressWaypoints,
    RTBWaypoint = self.RTBWaypoint,
    Mission = self, -- Reference back to mission
  }
  
  -- Create bomber
  self.Bomber = BOMBER:New(templateName, bomberMissionData)
  if not self.Bomber then
    BASE:E("Failed to create bomber")
    return false
  end
  
  -- Build route
  self:_BuildRoute()
  
  -- Spawn bomber
  local success = self.Bomber:Spawn()
  if not success then
    BASE:E(string.format("Failed to spawn bomber: %s (template: %s)", self.BomberType, templateName))
    -- Error message already sent to players by BOMBER:Spawn()
    return false
  end
  
  self.MissionActive = true
  self.Callsign = self.Bomber.Callsign -- Use bomber's callsign
  
  -- Create player F10 menu
  self:_CreatePlayerMenu()
  
  return true
end

--- Build flight route from start to target
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_BuildRoute()
  local profile = BOMBER_PROFILE:Get(self.BomberType)
  
  -- Get start coordinate
  local startCoord
  if self.StartAirbase then
    local airbase = AIRBASE:FindByName(self.StartAirbase)
    if airbase then
      startCoord = airbase:GetCoordinate()
      BASE:I(string.format("Start from airbase: %s at %s", self.StartAirbase, startCoord:ToStringLLDMS()))
    else
      env.warning(string.format("[BOMBER] Airbase '%s' not found", self.StartAirbase))
    end
  end
  
  if not startCoord and self.StartPos then
    startCoord = COORDINATE:NewFromVec3(self.StartPos)
    BASE:I(string.format("Start from marker position: %s", startCoord:ToStringLLDMS()))
  end
  
  if not startCoord then
    BASE:E("No valid start coordinate")
    return
  end
  
  -- Validate we have targets
  if not self.Targets or #self.Targets == 0 then
    BASE:E("No valid targets")
    return
  end
  
  BASE:I(string.format("Mission has %d target(s)", #self.Targets))
  
  -- Build waypoint list
  local waypoints = {}
  
  -- Waypoint 1: Start (takeoff)
  local cruiseAlt = self.CruiseAlt or profile.CruiseAlt
  local cruiseSpeed = self.CruiseSpeed or profile.CruiseSpeed
  local cruiseAltMeters = cruiseAlt * 0.3048 -- Convert feet to meters
  local cruiseSpeedMPS = cruiseSpeed * 0.514444 -- Convert knots to m/s
  
  BASE:I(string.format("Mission parameters: Altitude=%.0f ft (%.0f m), Speed=%d kts (%.1f m/s)", 
    cruiseAlt, cruiseAltMeters, cruiseSpeed, cruiseSpeedMPS))
  
  table.insert(waypoints, startCoord:WaypointAirTakeOffParking())
  
  -- Waypoint 2+: Route waypoints (BOMBER2, BOMBER3, etc.)
  -- Aircraft will climb naturally toward cruise altitude
  -- No intermediate climb waypoints - go directly to route waypoints
  for _, waypointData in ipairs(self.RouteWaypoints) do
    -- RouteWaypoints contains {coordinate=COORDINATE, sequence=number}
    local wpCoord = waypointData.coordinate:SetAltitude(cruiseAltMeters)
    table.insert(waypoints, wpCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
    BASE:I(string.format("Added route waypoint %d at altitude %.0f m", waypointData.sequence, cruiseAltMeters))
  end
  
  -- Process each target (TARGET1, TARGET2, TARGET3...)
  for targetIndex, targetData in ipairs(self.Targets) do
    local targetCoord = targetData.coordinate
    local targetName = targetData.name or string.format("Target %d", targetIndex)
    local attackType = targetData.attackType or "AUTO"
    local attackHeading = targetData.attackHeading
    
    BASE:I(string.format("Processing target %d/%d: %s at %s (Type: %s, Heading: %s)", 
      targetIndex, #self.Targets, targetName, targetCoord:ToStringLLDMS(), 
      attackType, attackHeading and string.format("%.0f°", attackHeading) or "AUTO"))
    
    -- Determine if this is a runway/carpet bombing target
    local isRunwayTarget = false
    local runwayHeading = attackHeading -- Use specified heading if provided
    
    if attackType == "RUNWAY" then
      -- Explicitly marked as runway attack
      isRunwayTarget = true
      BASE:I(string.format("Target %d: RUNWAY attack (marked explicitly)", targetIndex))
      
      -- If no heading specified, try to detect from airbase
      if not runwayHeading then
        local targetAirbase = targetCoord:GetClosestAirbase(Airbase.Category.AIRDROME)
        if targetAirbase then
          local airbaseCoord = targetAirbase:GetCoordinate()
          local distanceToAirbase = targetCoord:Get2DDistance(airbaseCoord)
          BASE:I(string.format("Nearest airbase: %s (%.0f m away)", targetAirbase:GetName(), distanceToAirbase))
          
          -- Try to get runway heading
          local runways = targetAirbase:GetRunways()
          if runways and #runways > 0 then
            runwayHeading = runways[1].course or 0
            BASE:I(string.format("Using airbase runway heading: %.0f°", runwayHeading))
          else
            -- Calculate heading from airbase to marker
            runwayHeading = airbaseCoord:HeadingTo(targetCoord)
            BASE:I(string.format("Calculated heading from airbase: %.0f°", runwayHeading))
          end
        else
          -- No airbase found, use default north heading
          runwayHeading = 0
          BASE:I("No airbase found, using heading 0° (north)")
        end
      else
        BASE:I(string.format("Using specified attack heading: %.0f°", runwayHeading))
      end
      
    elseif attackType == "AUTO" then
      -- Auto-detect based on proximity to airbase
      local targetAirbase = targetCoord:GetClosestAirbase(Airbase.Category.AIRDROME)
      
      if targetAirbase then
        local airbaseCoord = targetAirbase:GetCoordinate()
        local distanceToAirbase = targetCoord:Get2DDistance(airbaseCoord)
        BASE:I(string.format("Nearest airbase: %s (%.0f m away)", targetAirbase:GetName(), distanceToAirbase))
        
        -- If target is within configured radius of an airbase, treat as runway attack
        if distanceToAirbase < BOMBER_ESCORT_CONFIG.RunwayDetectionRadius then
          isRunwayTarget = true
          
          -- Try to get runway heading for attack direction
          local runways = targetAirbase:GetRunways()
          if runways and #runways > 0 then
            runwayHeading = runways[1].course or 0
            BASE:I(string.format("AUTO-DETECTED RUNWAY: %s Runway %.0f°", 
              targetAirbase:GetName(), runwayHeading))
          else
            -- Calculate heading from airbase to target
            runwayHeading = airbaseCoord:HeadingTo(targetCoord)
            BASE:I(string.format("AUTO-DETECTED RUNWAY: %s (calculated heading %.0f°)", 
              targetAirbase:GetName(), runwayHeading))
          end
        else
          BASE:I(string.format("Target too far from airbase (%.0f m) - using point target bombing", distanceToAirbase))
        end
      else
        BASE:I("No airbase found near target - using point target bombing")
      end
    else
      -- Other attack types (BRIDGE, BUILDING, etc.) use point target bombing
      BASE:I(string.format("Target %d: %s attack - using point target bombing", targetIndex, attackType))
    end
    
    -- Configure bombing run based on target type
    local ipDistance, ipHeading, attackQty, attackType, expend
    
    if isRunwayTarget then
      -- RUNWAY CARPET BOMBING - Single devastating pass
      -- Position IP out along runway axis for long, straight approach
      ipDistance = BOMBER_ESCORT_CONFIG.RunwayApproachDistance
      
      -- Determine best approach direction based on current position
      -- Get last position (either last route waypoint or climb point)
      local lastPos = #self.RouteWaypoints > 0 
        and self.RouteWaypoints[#self.RouteWaypoints].coordinate 
        or startCoord
      
      -- Calculate which runway direction is closer to current heading
      local headingToTarget = lastPos:HeadingTo(targetCoord)
      local diff1 = math.abs(headingToTarget - runwayHeading)
      local diff2 = math.abs(headingToTarget - (runwayHeading + 180))
      
      -- Normalize differences to 0-180 range
      if diff1 > 180 then diff1 = 360 - diff1 end
      if diff2 > 180 then diff2 = 360 - diff2 end
      
      -- Choose runway direction closest to current heading
      local approachHeading
      if diff1 < diff2 then
        -- Approach from opposite of runway heading
        approachHeading = (runwayHeading + 180) % 360
        BASE:I(string.format("Runway attack: Approach from %.0f° (runway heading %.0f°)", approachHeading, runwayHeading))
      else
        -- Approach from same as runway heading (reciprocal attack)
        approachHeading = runwayHeading
        BASE:I(string.format("Runway attack: Approach from %.0f° (reciprocal to runway %.0f°)", approachHeading, (runwayHeading + 180) % 360))
      end
      
      ipHeading = approachHeading
      attackQty = 1 -- Single pass only
      attackType = "Carpet" -- Carpet bombing mode
      expend = "All" -- Drop everything in one pass
      
      BASE:I(string.format("Target %d: RUNWAY CARPET BOMB - 1 pass, heading %.0f°, expend ALL", 
        targetIndex, approachHeading))
    else
      -- POINT TARGET (building, bridge, etc.)
      ipDistance = 20000 -- 20km initial point
      ipHeading = 180 -- Default approach from north
      attackQty = #self.Targets == 1 and 4 or 2 -- Fewer passes per target if multiple targets
      attackType = "Bombing" -- Standard bombing
      expend = #self.Targets == 1 and "All" or "Half"
      BASE:I(string.format("Target %d: POINT TARGET - %d passes with standard bombing", 
        targetIndex, attackQty))
    end
    
    -- Waypoint: IP - Initial Point before this target
    local ipCoord = targetCoord:Translate(ipDistance, ipHeading):SetAltitude(cruiseAltMeters)
    table.insert(waypoints, ipCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
    
    -- For runway carpet bombing, create simple waypoints with bombing task at center
    if isRunwayTarget then
      local attackHeading = (ipHeading + 180) % 360
      
      -- Start of bombing run - 8km before runway (gives time to arm and drop)
      local startBombCoord = targetCoord:Translate(8000, ipHeading):SetAltitude(cruiseAltMeters)
      table.insert(waypoints, startBombCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
      
      -- Runway center waypoint - CARPET BOMBING TASK HERE
      local centerWP = targetCoord:SetAltitude(cruiseAltMeters):WaypointAirTurningPoint(nil, cruiseSpeedMPS)
      local targetVec3 = targetCoord:GetVec3()
      
      -- Use proper CarpetBombing task for runway attacks
      centerWP.task = {
        id = "ComboTask",
        params = {
          tasks = {
            {
              enabled = true,
              auto = false,
              id = "CarpetBombing",
              params = {
                attackType = "Carpet",
                x = targetVec3.x,
                y = targetVec3.z,
                point = {x = targetVec3.x, y = targetVec3.z},
                groupAttack = true,
                carpetLength = 3000, -- 3km carpet along attack axis
                expend = "All",
                attackQtyLimit = false, -- No limit on attack quantity
                attackQty = 10, -- Up to 10 passes
                directionEnabled = true,
                direction = math.rad(attackHeading), -- DCS uses radians
                altitudeEnabled = true,
                altitude = cruiseAltMeters,
                weaponType = 1073741822 -- Auto-select bombs (ENUMS.WeaponFlag.AutoDCS)
              }
            }
          }
        }
      }
      table.insert(waypoints, centerWP)
      
      -- End of bombing run - 8km past runway
      local endBombCoord = targetCoord:Translate(8000, attackHeading):SetAltitude(cruiseAltMeters)
      table.insert(waypoints, endBombCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
      
      BASE:I(string.format("Runway attack: IP->Start(-8km)->Center(CARPET BOMB)->End(+8km) heading %.0f°", attackHeading))
      
    else
      -- POINT TARGET: Standard bombing with multiple passes
      local bombingCoord = targetCoord:SetAltitude(cruiseAltMeters)
      local targetWP = bombingCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS)
      local targetVec3 = targetCoord:GetVec3()
      
      targetWP.task = {
        id = "ComboTask",
        params = {
          tasks = {
            {
              enabled = true,
              auto = false,
              id = "Bombing",
              params = {
                point = {x = targetVec3.x, y = targetVec3.z},
                attackQtyLimit = true,  -- Limit to specific number of passes
                attackQty = 1,           -- Single pass attack - drop and go
                directionEnabled = true, -- Enable attack direction for reliable release
                direction = math.rad(ipHeading), -- Attack from IP heading (radians)
                altitudeEnabled = true,
                altitude = cruiseAltMeters,
                weaponType = 2032, -- General purpose bombs
                expend = expend,
                groupAttack = true
              }
            }
          }
        }
      }
      table.insert(waypoints, targetWP)
    end
    
    -- Add egress waypoints after last target
    local isLastTarget = (targetIndex == #self.Targets)
    
    if isLastTarget then
      -- Check if custom egress waypoints are provided
      if self.EgressWaypoints and #self.EgressWaypoints > 0 then
        BASE:I(string.format("Adding %d custom egress waypoints", #self.EgressWaypoints))
        for i, egressData in ipairs(self.EgressWaypoints) do
          local egressCoord = egressData.coordinate:SetAltitude(cruiseAltMeters)
          table.insert(waypoints, egressCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
          BASE:I(string.format("Added custom egress waypoint %d at %s", i, egressCoord:ToStringLLDMS()))
        end
      else
        -- Standard egress waypoint after last target
        if not isRunwayTarget then
          local egressCoord = targetCoord:Translate(30000, 0):SetAltitude(cruiseAltMeters)
          table.insert(waypoints, egressCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
        else
          local finalEgressCoord = targetCoord:Translate(25000, (ipHeading + 180) % 360):SetAltitude(cruiseAltMeters)
          table.insert(waypoints, finalEgressCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
        end
        BASE:I("Added standard egress waypoint")
      end
    else
      -- Not the last target, add transition egress between targets
      if not isRunwayTarget then
        local egressCoord = targetCoord:Translate(30000, 0):SetAltitude(cruiseAltMeters)
        table.insert(waypoints, egressCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
      else
        local finalEgressCoord = targetCoord:Translate(25000, (ipHeading + 180) % 360):SetAltitude(cruiseAltMeters)
        table.insert(waypoints, finalEgressCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
      end
    end
  end
  
  -- Final waypoint: RTB (Return to start airbase or custom RTB point)
  if self.RTBWaypoint then
    -- Use custom RTB waypoint
    BASE:I(string.format("Using custom RTB waypoint at %s", self.RTBWaypoint.coordinate:ToStringLLDMS()))
    local rtbCoord = self.RTBWaypoint.coordinate
    
    -- Check if RTB is near an airbase for landing
    local rtbAirbase = rtbCoord:GetClosestAirbase(Airbase.Category.AIRDROME)
    if rtbAirbase then
      local airbaseCoord = rtbAirbase:GetCoordinate()
      local distance = rtbCoord:Get2DDistance(airbaseCoord)
      if distance < 5000 then -- Within 5km, assume landing
        BASE:I(string.format("RTB at airbase %s - creating landing waypoint", rtbAirbase:GetName()))
        table.insert(waypoints, airbaseCoord:WaypointAirLanding(cruiseSpeed * 0.514444 * 0.7, rtbAirbase))
      else
        -- Just a regular waypoint, not landing
        BASE:I("RTB waypoint not near airbase - regular waypoint")
        table.insert(waypoints, rtbCoord:SetAltitude(cruiseAltMeters):WaypointAirTurningPoint(nil, cruiseSpeedMPS))
      end
    else
      BASE:I("RTB waypoint not near airbase - regular waypoint")
      table.insert(waypoints, rtbCoord:SetAltitude(cruiseAltMeters):WaypointAirTurningPoint(nil, cruiseSpeedMPS))
    end
  elseif self.StartAirbase then
    -- Return to start airbase
    local airbase = AIRBASE:FindByName(self.StartAirbase)
    if airbase then
      local rtbCoord = airbase:GetCoordinate()
      BASE:I(string.format("RTB to start airbase: %s", self.StartAirbase))
      table.insert(waypoints, rtbCoord:WaypointAirLanding(cruiseSpeed * 0.514444 * 0.7, airbase))
    end
  end
  
  -- Store route
  self.Bomber.Route = waypoints
  
  BASE:I(string.format("Route built: %d waypoints", #waypoints))
end

--- Create target zone
-- @param #BOMBER_MISSION self
-- @return #ZONE Target zone for first target
function BOMBER_MISSION:_CreateTargetZone()
  if self.Targets and #self.Targets > 0 then
    local firstTarget = self.Targets[1]
    local coord = firstTarget.coordinate
    return ZONE_RADIUS:New(firstTarget.name or "Target", coord:GetVec2(), 2000) -- 2km radius
  end
  return nil
end

--- Get template name for bomber type
-- @param #BOMBER_MISSION self
-- @return #string Template name
function BOMBER_MISSION:_GetTemplateName()
  -- Convert bomber type to template name by removing hyphens and MS suffix
  -- Examples:
  --   B-52H    -> BOMBER_B52H
  --   B-17G    -> BOMBER_B17G
  --   B-1B     -> BOMBER_B1B
  --   Tu-95MS  -> BOMBER_TU95
  --   Tu-22M3  -> BOMBER_TU22M3
  --   B-24J    -> BOMBER_B24J
  
  local typeName = self.BomberType
  
  -- Remove hyphens
  typeName = string.gsub(typeName, "[-]", "")
  
  -- Remove MS suffix only (for Tu-95MS)
  typeName = string.gsub(typeName, "MS$", "")
  
  -- Return template name
  local templateName = "BOMBER_" .. string.upper(typeName)
  
  BASE:I(string.format("Converting bomber type '%s' to template '%s'", self.BomberType, templateName))
  
  return templateName
end

--- Generate callsign
-- @param #BOMBER_MISSION self
-- @return #string Callsign
function BOMBER_MISSION:_GenerateCallsign()
  local callsigns = {"Overlord", "Fortress", "Hammer", "Thunder", "Steel", "Anvil", "Titan", "Sledge"}
  local idx = math.random(1, #callsigns)
  local flight = math.random(1, 9)
  return string.format("%s %d-1", callsigns[idx], flight)
end

--- Create player F10 menu
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_CreatePlayerMenu()
  -- Create coalition-specific menu
  local coalitionName = self.Coalition == coalition.side.BLUE and "BLUE" or "RED"
  
  -- Main menu path
  if not _BOMBER_PLAYER_MENUS then
    _BOMBER_PLAYER_MENUS = {}
  end
  
  if not _BOMBER_PLAYER_MENUS[self.Coalition] then
    _BOMBER_PLAYER_MENUS[self.Coalition] = MENU_COALITION:New(self.Coalition, "Bomber Missions")
  end
  
  -- Mission submenu
  self.PlayerMenu = MENU_COALITION:New(self.Coalition, self.Callsign, _BOMBER_PLAYER_MENUS[self.Coalition])
  
  -- Status command
  MENU_COALITION_COMMAND:New(
    self.Coalition,
    "Request Status",
    self.PlayerMenu,
    function() self:_PlayerRequestStatus() end
  )
  
  -- Abort recommendation
  MENU_COALITION_COMMAND:New(
    self.Coalition,
    "Recommend Abort",
    self.PlayerMenu,
    function() self:_PlayerRecommendAbort() end
  )
  
  -- SAM warning
  MENU_COALITION_COMMAND:New(
    self.Coalition,
    "Warn: SAM Threat",
    self.PlayerMenu,
    function() self:_PlayerWarnSAM() end
  )
  
  -- Bandit warning
  MENU_COALITION_COMMAND:New(
    self.Coalition,
    "Warn: Bandits",
    self.PlayerMenu,
    function() self:_PlayerWarnBandits() end
  )
  
  -- Speed change request
  MENU_COALITION_COMMAND:New(
    self.Coalition,
    "Request Speed Increase",
    self.PlayerMenu,
    function() self:_PlayerRequestSpeedUp() end
  )
  
  MENU_COALITION_COMMAND:New(
    self.Coalition,
    "Request Speed Decrease",
    self.PlayerMenu,
    function() self:_PlayerRequestSlowDown() end
  )
end

--- Player requests status
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_PlayerRequestStatus()
  if not self.Bomber or not self.Bomber:IsAlive() then
    trigger.action.outTextForCoalition(self.Coalition, 
      string.format("%s: (No response - mission not active)", self.Callsign), 10)
    return
  end
  
  local escortStatus = self.Bomber.EscortMonitor:GetStatus()
  local threatCount = 0
  for _ in pairs(self.Bomber.ThreatManager.ActiveThreats) do
    threatCount = threatCount + 1
  end
  
  local state = self.Bomber:GetState()
  local fuel = self.Bomber.Group:GetFuelMin() * 100 -- percentage
  
  local statusMsg = string.format([[
%s STATUS REPORT:
State: %s
Escorts: %d (Min: %d)
Threats: %d active
Fuel: %d%%
Target: %s]],
    self.Callsign,
    state,
    escortStatus.Count,
    self.Bomber.Profile.MinEscorts,
    threatCount,
    math.floor(fuel),
    self.TargetName or "Coordinates"
  )
  
  trigger.action.outTextForCoalition(self.Coalition, statusMsg, 15)
end

--- Player recommends abort
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_PlayerRecommendAbort()
  if self.Bomber and self.Bomber:IsAlive() then
    -- Bomber considers abort based on current situation
    if self.Bomber.IsUnderThreat or not self.Bomber.HasEscort then
      self.Bomber:_BroadcastMessage(string.format("%s: Copy abort recommendation. RTB!", self.Callsign))
      self.Bomber:Abort()
    else
      self.Bomber:_BroadcastMessage(string.format("%s: Negative, continuing mission.", self.Callsign))
    end
  end
end

--- Player warns of SAM threat
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_PlayerWarnSAM()
  if self.Bomber and self.Bomber:IsAlive() then
    self.Bomber:_BroadcastMessage(string.format("%s: Copy SAM warning. Deploying countermeasures.", self.Callsign))
    -- TODO: Deploy flares/chaff
  end
end

--- Player warns of bandits
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_PlayerWarnBandits()
  if self.Bomber and self.Bomber:IsAlive() then
    self.Bomber:_BroadcastMessage(string.format("%s: Copy bandit warning. Tightening formation.", self.Callsign))
    -- TODO: Formation adjustment
  end
end

--- Player requests speed increase
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_PlayerRequestSpeedUp()
  if self.Bomber and self.Bomber:IsAlive() then
    local profile = self.Bomber.Profile
    local currentSpeed = self.Bomber.Group:GetVelocityKNOTS()
    
    if currentSpeed < profile.MaxSpeed - 10 then
      self.Bomber:_BroadcastMessage(string.format("%s: Increasing speed.", self.Callsign))
      local newSpeed = math.min(currentSpeed + 20, profile.MaxSpeed)
      self.Bomber.Group:SetSpeed(newSpeed * 0.514444) -- Convert to m/s
    else
      self.Bomber:_BroadcastMessage(string.format("%s: Negative, already at max speed.", self.Callsign))
    end
  end
end

--- Player requests speed decrease
-- @param #BOMBER_MISSION self
function BOMBER_MISSION:_PlayerRequestSlowDown()
  if self.Bomber and self.Bomber:IsAlive() then
    local profile = self.Bomber.Profile
    local currentSpeed = self.Bomber.Group:GetVelocityKNOTS()
    
    if currentSpeed > profile.MinSpeed + 10 then
      self.Bomber:_BroadcastMessage(string.format("%s: Reducing speed.", self.Callsign))
      local newSpeed = math.max(currentSpeed - 20, profile.MinSpeed)
      self.Bomber.Group:SetSpeed(newSpeed * 0.514444)
    else
      self.Bomber:_BroadcastMessage(string.format("%s: Negative, already at minimum speed.", self.Callsign))
    end
  end
end

--- Mission complete
-- @param #BOMBER_MISSION self
-- @param #boolean success Mission success
function BOMBER_MISSION:Complete(success)
  self.MissionActive = false
  self.MissionSuccess = success
  
  if success then
    trigger.action.outTextForCoalition(self.Coalition,
      string.format("%s: Mission complete! RTB.", self.Callsign), 15)
  else
    trigger.action.outTextForCoalition(self.Coalition,
      string.format("%s: Mission failed.", self.Callsign), 15)
  end
  
  -- Remove menu
  if self.PlayerMenu then
    self.PlayerMenu:Remove()
  end
  
  -- Unregister from manager
  if _BOMBER_MISSION_MANAGER then
    _BOMBER_MISSION_MANAGER:UnregisterMission(self)
  end
end

---
-- BOMBER_FORMATION - Formation management system
-- @type BOMBER_FORMATION
BOMBER_FORMATION = {
  ClassName = "BOMBER_FORMATION"
}

--- Formation types
BOMBER_FORMATION.Type = {
  BOX = "Box", -- WWII bomber box
  TRAIL = "Trail", -- Single file
  ECHELON_RIGHT = "Echelon Right",
  ECHELON_LEFT = "Echelon Left",
  VIC = "Vic", -- V formation
  LINE_ABREAST = "Line Abreast",
}

--- Create formation manager
-- @param #BOMBER_FORMATION self
-- @param #BOMBER bomber The bomber instance
-- @return #BOMBER_FORMATION
function BOMBER_FORMATION:New(bomber)
  local self = BASE:Inherit(self, BASE:New())
  
  self.Bomber = bomber
  self.FormationType = self:_DetermineFormation()
  self.FormationTight = bomber.Profile.FormationTight or false
  self.Spacing = self.FormationTight and 50 or 200 -- meters
  
  return self
end

--- Determine formation type based on bomber profile
-- @param #BOMBER_FORMATION self
-- @return #string Formation type
function BOMBER_FORMATION:_DetermineFormation()
  local profile = self.Bomber.Profile
  
  if profile.Category == "WWII" then
    return BOMBER_FORMATION.Type.BOX
  elseif profile.FormationTight then
    return BOMBER_FORMATION.Type.VIC
  else
    return BOMBER_FORMATION.Type.LINE_ABREAST
  end
end

--- Apply formation to group
-- @param #BOMBER_FORMATION self
function BOMBER_FORMATION:Apply()
  if not self.Bomber or not self.Bomber.Group then
    return
  end
  
  local group = self.Bomber.Group
  local units = group:GetUnits()
  
  if #units <= 1 then
    return -- No formation needed for single aircraft
  end
  
  -- Get DCS formation constant
  local dcsFormation = self:_GetDCSFormation()
  
  if dcsFormation then
    group:SetOption(AI.Option.Air.id.FORMATION, dcsFormation)
    BASE:I(string.format("%s: Formation set to %s", self.Bomber.Callsign, self.FormationType))
  end
end

--- Get DCS formation constant
-- @param #BOMBER_FORMATION self
-- @return #number DCS formation ID
function BOMBER_FORMATION:_GetDCSFormation()
  if self.FormationType == BOMBER_FORMATION.Type.BOX then
    -- Use bomber element formation for WWII
    return self.FormationTight and ENUMS.Formation.FixedWing.BomberElement.Close or ENUMS.Formation.FixedWing.BomberElement.Open
  elseif self.FormationType == BOMBER_FORMATION.Type.TRAIL then
    return self.FormationTight and ENUMS.Formation.FixedWing.Trail.Close or ENUMS.Formation.FixedWing.Trail.Open
  elseif self.FormationType == BOMBER_FORMATION.Type.ECHELON_RIGHT then
    return self.FormationTight and ENUMS.Formation.FixedWing.EchelonRight.Close or ENUMS.Formation.FixedWing.EchelonRight.Open
  elseif self.FormationType == BOMBER_FORMATION.Type.ECHELON_LEFT then
    return self.FormationTight and ENUMS.Formation.FixedWing.EchelonLeft.Close or ENUMS.Formation.FixedWing.EchelonLeft.Open
  elseif self.FormationType == BOMBER_FORMATION.Type.VIC then
    return ENUMS.Formation.FixedWing.FighterVic.Close
  elseif self.FormationType == BOMBER_FORMATION.Type.LINE_ABREAST then
    return self.FormationTight and ENUMS.Formation.FixedWing.LineAbreast.Close or ENUMS.Formation.FixedWing.LineAbreast.Open
  end
  
  return nil
end

---
-- BOMBER - Main bomber FSM class with intelligent behaviors
-- @type BOMBER
BOMBER = {
  ClassName = "BOMBER",
  Version = "1.0.0"
}

--- Bomber states
BOMBER.States = {
  SPAWNED = "Spawned",
  HOLDING = "Holding",           -- Waiting for escort on ground
  ENGINE_STARTING = "EngineStarting",  -- Cold start, engines spooling up
  TAXIING = "Taxiing",           -- Moving to runway
  BLOCKED = "Blocked",           -- Stuck on taxiway due to obstruction
  TAKING_OFF = "TakingOff",      -- Takeoff roll and initial climb
  CLIMBING = "Climbing",         -- Climbing to cruise altitude
  CRUISE = "Cruise",             -- At cruise altitude, en route to target
  PRE_ATTACK = "PreAttack",      -- Approaching target, preparing for attack
  ATTACKING = "Attacking",       -- Bombing run in progress
  EGRESSING = "Egressing",       -- Leaving target area
  ABORTING = "Aborting",         -- Mission abort in progress
  RTB = "RTB",                   -- Returning to base
  LANDED = "Landed",
  DESTROYED = "Destroyed"
}

--- Escort loss messages - 3 escalating levels with 15 variations each
BOMBER.EscortLossMessages = {
  -- Level 1: Casual check-in (just noticed escort missing)
  Level1 = {
    "Hey, you still with me up here?",
    "Escort, say position.",
    "Where'd my escort go?",
    "Anyone got eyes on my escort?",
    "Escort flight, check in.",
    "Lost visual on my escort. Anyone got them?",
    "Escort, this is %s, requesting position.",
    "Could use a wingman visual right about now.",
    "Escort's gone quiet. Anyone have comms?",
    "Did my escort peel off? Say status.",
    "No visual on escort. Requesting check-in.",
    "Escort flight, say your position please.",
    "Lost my escort somewhere back there.",
    "Anybody see where my fighters went?",
    "Escort, you still up?"
  },
  
  -- Level 2: Getting concerned (been a while, need help)
  Level2 = {
    "This mission requires escorts - I'm gonna need some help up here!",
    "I need fighter support ASAP, getting exposed out here.",
    "Where are my escorts? Requesting immediate support!",
    "No escort coverage - I need fighters NOW!",
    "Getting lonely up here. Need escort support!",
    "Request immediate fighter assistance - lost my escort!",
    "I need some friends up here - requesting fighter support!",
    "This is a bad time to be alone. Need escorts NOW!",
    "Unescorted bomber - requesting fighter support immediately!",
    "No fighter coverage - need help up here!",
    "Lost my escort and I need them back NOW!",
    "Requesting urgent fighter support - unescorted!",
    "I'm exposed out here - need escort ASAP!",
    "Where's my cover? Need fighters immediately!",
    "Getting nervous without escorts - need support NOW!"
  },
  
  -- Level 3: Critical/Panic (about to abort)
  Level3 = {
    "NO ESCORT FOR %d SECONDS! REQUESTING IMMEDIATE ABORT CLEARANCE!",
    "UNESCORTED TOO LONG - ABORTING MISSION NOW!",
    "MISSION ABORT - NO FIGHTER SUPPORT FOR %d SECONDS!",
    "THIS IS SUICIDE WITHOUT ESCORTS - ABORTING!",
    "NO PROTECTION FOR %d SECONDS - TURNING AROUND!",
    "ABORT ABORT ABORT - NO ESCORT COVERAGE!",
    "CANNOT CONTINUE UNESCORTED - ABORTING MISSION!",
    "TOO EXPOSED - MISSION ABORT IN PROGRESS!",
    "NO FIGHTERS FOR %d SECONDS - GETTING OUT OF HERE!",
    "ABORT - UNESCORTED FOR TOO LONG!",
    "MISSION SCRUBBED - NO FIGHTER SUPPORT!",
    "TURNING BACK - NO ESCORT FOR %d SECONDS!",
    "ABORT ABORT - UNSAFE TO CONTINUE UNESCORTED!",
    "MISSION ABORT - FLYING ALONE IS A DEATH SENTENCE!",
    "NO ESCORTS - ABORTING BEFORE IT'S TOO LATE!"
  }
}

--- Formation flying compliment messages (when escort flies tight formation)
BOMBER.FormationCompliments = {
  -- Professional/Military Lingo
  "Nice flying, you're looking good out there.",
  "Solid formation flying, escort. Five by five.",
  "Good position, escort. Right where I need you.",
  "Textbook formation flying. Well done.",
  "You're dialed in, escort. Appreciate the precision.",
  "That's some professional flying right there.",
  "Copy that formation. You're looking sharp.",
  "Excellent positioning, escort. Couldn't ask for better.",
  "You're locked in tight, good work.",
  "Perfect escort position. Outstanding flying.",
  "Rock steady on the wing. Impressive.",
  "You've got the touch, escort. Beautiful flying.",
  "That's how it's done. Smooth as silk.",
  "Textbook positioning. Someone trained you well.",
  "You make this look easy, escort.",
  "Holding formation like a pro. Nice work.",
  "Steady as she goes. Good flying, escort.",
  "Right in the sweet spot. Well positioned.",
  "You're welded to my wing. Great job.",
  "Perfect spacing. That's professional flying.",
  
  -- Encouraging/Friendly
  "Hey, you're pretty good at this!",
  "Now THAT'S what I call an escort!",
  "You been practicing? That's smooth flying!",
  "I feel safer already with you on my wing.",
  "Stick around, you're doing great!",
  "Now I know why they sent you - solid flying!",
  "You make my job easier, nice work!",
  "I'd fly with you any day. Good stuff!",
  "Keep it up, you're nailing this formation thing.",
  "This is what good escort flying looks like!",
  "You're a natural at this, escort.",
  "Finally, someone who knows how to fly formation!",
  "You've done this before, haven't you?",
  "Glad to have you on my wing today.",
  "You're making me look good out here!",
  
  -- Light Humor
  "Don't scratch the paint! ...Just kidding, nice flying.",
  "Easy there, you're making me nervous! Actually, you're doing great.",
  "You trying to count my rivets? Ha! Good formation work.",
  "I can almost shake your hand from here. Nice and tight!",
  "Careful, any closer and I'll charge you rent!",
  "You're so close I can see what you had for breakfast!",
  "Wow, personal space much? Just kidding - good position.",
  "I was gonna wave but you might take it as a signal!",
  "You park this well at the BX too?",
  "Formation this tight should be illegal. Great job!",
  "My copilot thinks you're too close. I think you're perfect.",
  "Don't sneeze or we're both going down! Kidding - nice work.",
  "You're closer than my shadow. Impressive!",
  "If we were any closer we'd be carpooling!",
  "My crew chief is gonna ask about the wingtip wear. Worth it!",
  
  -- Humorous/Cocky
  "Show off! But seriously, nice formation flying.",
  "Trying to make the rest of the flight jealous?",
  "Easy Maverick, save some skill for the bandits!",
  "You auditioning for the Blues? Because that's tight!",
  "Someone's been watching too much Top Gun. Keep it up!",
  "Careful, the other escorts might get jealous!",
  "You planning on moving in permanently?",
  "My wingman's taking notes. You're making them look bad!",
  "That's either really good flying or really bad judgment!",
  "You must be fun at airshows!",
  "Okay hotshot, I'm impressed.",
  "Are you TRYING to make this look easy?",
  "Look at you, flying like you own the sky!",
  "Someone's showing off their academy training!",
  
  -- Mo-Related Jokes
  "Now THAT'S precision! Mo could learn a thing or two from you.",
  "Wish Mo could fly formation like this instead of... whatever he does.",
  "You're way better at this than Mo. And we've needed these bombers because he can't hit anything!",
  "If Mo flew this tight we wouldn't need bombers at all. But here we are.",
  "Nice flying! Unlike Mo, you actually know where your aircraft ends!",
  "Good thing you're escorting and not Mo. He'd probably escort the wrong bomber.",
  "This is why we like you and not Mo on escort duty!",
  "See, THIS is formation flying. Mo thinks formation means 'generally the same direction.'",
  "Mo couldn't hold this position if his flight computer did it for him!",
  "Perfect formation! Mo would've hit me by now.",
  "You make this look easy. Mo makes it look like a near-death experience.",
  "That's some skill! We brought the bombers because Mo can't hit anything in his F-4.",
  "If Mo flew like you, we could've taken Cessnas to the target!",
  "Beautiful flying! Mo would be 5 miles out wondering where I went.",
  "You're so good at this. Mo would've run out of fuel trying to find me.",
  "This is textbook! Mo's textbook had half the pages missing.",
  "Great job! We only need these bombers because Mo's aim is... questionable.",
  "Now that's how it's done! Mo would've winged me and called it 'close air support.'",
  "You've got the touch! Mo's got... well, Mo's got problems.",
  "Solid work, escort! Unlike Mo, you know which end of the jet goes forward!",
    
  -- More Professional Variations  
  "Maintain that position, you're doing excellent.",
  "Good stick work, escort. Keep it up.",
  "That's the kind of flying I like to see.",
  "You're tracking perfectly. Well done.",
  "Smooth flying, escort. I'm impressed.",
  "That's some confident flying right there.",
  "You've got good situational awareness. Nice job.",
  "Steady and reliable. That's what I need.",
  "Professional work, escort. Appreciate it.",
  "You're a credit to your squadron.",
  
  -- Additional Humor
  "We should get 'Just Married' signs for our aircraft!",
  "At this distance I can critique your panel layout!",
  "You're in my bubble! ...And I'm okay with that.",
  "Hope you like my paint scheme, you're seeing a lot of it!",
  "This close and you haven't complained about my flying? Keeper!",
  "My navigator wants your autograph after this!",
  "Formation so tight we're practically holding hands!",
  "You fly this close to your wife? Impressive commitment!",
  "Any tighter and we'd need a marriage certificate!",
  "The ground crew's gonna think we kissed up here!"
}

--- Create new bomber mission
-- @param #BOMBER self
-- @param #string templateName The spawn template group name
-- @param #table missionData Mission parameters from marker system
-- @return #BOMBER
function BOMBER:New(templateName, missionData)
  local self = BASE:Inherit(self, FSM:New())
  
  self.TemplateName = templateName
  self.MissionData = missionData or {}
  
  -- Get bomber profile
  self.Profile = BOMBER_PROFILE:Get(missionData.BomberType or "B-52H")
  if not self.Profile then
    BASE:E("ERROR: Unknown bomber type " .. tostring(missionData.BomberType))
    return nil
  end
  
  -- Mission properties
  self.Coalition = missionData.Coalition or coalition.side.BLUE
  self.Callsign = self:_GenerateCallsign()
  self.FlightSize = missionData.FlightSize or 2
  self.StartAirbase = missionData.StartAirbase
  self.TargetZone = missionData.TargetZone
  self.CruiseAlt = missionData.CruiseAlt or self.Profile.CruiseAlt
  self.CruiseSpeed = missionData.CruiseSpeed or self.Profile.CruiseSpeed
  
  -- Store target information for bombing task execution
  self.Targets = missionData.Targets or {}
  self.CurrentTargetIndex = 1
  
  -- Status tracking
  self.HasEscort = false
  self.IsUnderThreat = false
  self.AbortRequested = false
  self.AllowEscortResume = true
  self.ResumeLockReason = nil
  self.MissionStartTime = nil
  self.MissionCompleted = false
  self.EscortRejoinCount = 0  -- Track how many times escorts have rejoined after leaving
  self.MaxRejoins = 3  -- Maximum number of rejoins before aborting mission
  
  -- Threat abort timer tracking
  self.ThreatAbortTimer = nil  -- When threat abort countdown started
  self.LastThreatWarning = 0   -- Last time we warned about threat situation
  self.LastThreatReason = nil  -- Last recorded threat reason (to detect changes)
  
  -- Engine start tracking
  self.EngineStartTime = nil  -- When engines were started
  
  -- Holding timeout tracking
  self.HoldingStartTime = nil  -- When we entered HOLDING state
  self.MaxHoldingTime = 900  -- 15 minutes in seconds
  
  -- Blockage tracking
  self.PreBlockedState = nil  -- Track which state we were in before getting blocked
  
  -- Escort roster tracking with memory management
  self.EscortRoster = {}  -- Table of escort callsigns: {callsign = {unit, joinTime, lastSeen, classification, details, positionHistory}}
  self.LastKnownEscorts = {}  -- List of callsigns we've confirmed as escorts (preserved when they leave)
  self.MaxRosterSize = 20  -- Prevent memory bloat - prune oldest entries beyond this
  self.LastHoldingAnnounce = 0  -- Track last holding announcement time
  self.WaitingForEscortDeparture = false  -- Flag: detected ground escort, waiting for them to follow
  self.LastCrewCalloutTime = {}  -- Track last time crew made specific callouts to prevent spam
  
  -- Attack tracking flags for event-driven messages
  self.WeaponsReleased = false
  self.ImpactAnnounced = false
  
  -- Damage tracking
  self.DamageTracker = nil  -- Initialized on first hit
  self.CriticalDamageCalled = false
  
  -- FSM States
  self:SetStartState(BOMBER.States.SPAWNED)
  
  -- State transitions
  self:AddTransition(BOMBER.States.SPAWNED, "WaitForEscort", BOMBER.States.HOLDING)
  self:AddTransition(BOMBER.States.SPAWNED, "StartEngines", BOMBER.States.ENGINE_STARTING)  -- Direct if escort not required
  self:AddTransition(BOMBER.States.SPAWNED, "BeginClimb", BOMBER.States.CLIMBING)  -- Hot start/airborne spawn escape hatch
  self:AddTransition(BOMBER.States.HOLDING, "StartEngines", BOMBER.States.ENGINE_STARTING)  -- From holding when escort ready
  self:AddTransition(BOMBER.States.ENGINE_STARTING, "BeginTaxi", BOMBER.States.TAXIING)
  self:AddTransition(BOMBER.States.ENGINE_STARTING, "BeginClimb", BOMBER.States.CLIMBING)  -- Hot start/airborne spawn escape hatch
  self:AddTransition(BOMBER.States.TAXIING, "Blocked", BOMBER.States.BLOCKED)  -- Transition when stuck
  self:AddTransition(BOMBER.States.BLOCKED, "ClearBlockage", BOMBER.States.TAXIING)  -- Resume when clear (let normal progression handle takeoff)
  self:AddTransition(BOMBER.States.TAXIING, "Takeoff", BOMBER.States.TAKING_OFF)
  self:AddTransition(BOMBER.States.TAKING_OFF, "Blocked", BOMBER.States.BLOCKED)  -- Can get stuck during takeoff roll too
  self:AddTransition(BOMBER.States.TAKING_OFF, "BeginClimb", BOMBER.States.CLIMBING)
  self:AddTransition(BOMBER.States.CLIMBING, "ReachCruise", BOMBER.States.CRUISE)
  self:AddTransition(BOMBER.States.CRUISE, "ApproachTarget", BOMBER.States.PRE_ATTACK)
  self:AddTransition(BOMBER.States.PRE_ATTACK, "BeginAttack", BOMBER.States.ATTACKING)
  self:AddTransition(BOMBER.States.ATTACKING, "BombsAway", BOMBER.States.EGRESSING)
  self:AddTransition({BOMBER.States.HOLDING, BOMBER.States.ENGINE_STARTING, BOMBER.States.TAXIING, BOMBER.States.BLOCKED, BOMBER.States.TAKING_OFF, BOMBER.States.CLIMBING, BOMBER.States.CRUISE, BOMBER.States.PRE_ATTACK, BOMBER.States.ATTACKING}, "Abort", BOMBER.States.ABORTING)
  self:AddTransition({BOMBER.States.EGRESSING, BOMBER.States.ABORTING}, "ReturnToBase", BOMBER.States.RTB)
  self:AddTransition(BOMBER.States.RTB, "Land", BOMBER.States.LANDED)
  self:AddTransition("*", "Destroy", BOMBER.States.DESTROYED)
  
  -- Initialize subsystems
  self.EscortMonitor = nil
  self.ThreatManager = nil
  
  return self
end

--- Spawn the bomber group
-- @param #BOMBER self
-- @return #boolean Success
function BOMBER:Spawn()
  -- Verify template exists before attempting spawn
  local templateGroup = GROUP:FindByName(self.TemplateName)
  if not templateGroup then
    BASE:E(string.format("ERROR: Template group '%s' not found in mission", self.TemplateName))
    
    -- Send message to coalition
    trigger.action.outTextForCoalition(
      self.Coalition,
      string.format(
        "❌ BOMBER SPAWN FAILED\n\n" ..
        "Template Missing: %s\n" ..
        "Bomber Type: %s\n\n" ..
        "MISSION MAKER: This mission is missing the required bomber template.\n" ..
        "Add group '%s' in mission editor and set Late Activation = TRUE.",
        self.TemplateName,
        self.MissionData.BomberType or "Unknown",
        self.TemplateName
      ),
      30
    )
    return false
  end
  
  -- Increment global spawn counter for unique spawn index
  _BOMBER_GLOBAL_SPAWN_COUNTER = _BOMBER_GLOBAL_SPAWN_COUNTER + 1
  local spawnIndex = _BOMBER_GLOBAL_SPAWN_COUNTER
  
  -- Get or create SPAWN object for this template (reuse same object to prevent MOOSE conflicts)
  if not _BOMBER_SPAWN_OBJECTS[self.TemplateName] then
    _BOMBER_SPAWN_OBJECTS[self.TemplateName] = SPAWN:New(self.TemplateName)
      :InitCoalition(self.Coalition)
      :InitDelayOff()
      :InitLimit(100, 0)
    BASE:I(string.format("Created new SPAWN object for template: %s", self.TemplateName))
  end
  
  local spawner = _BOMBER_SPAWN_OBJECTS[self.TemplateName]
  
  -- Update grouping for this specific spawn
  spawner:InitGrouping(self.FlightSize)
  
  BASE:I(string.format("Spawning %s (#%d) from template %s", self.Callsign, spawnIndex, self.TemplateName))
  
  -- Spawn at the requested airbase if specified
  local spawnedGroup = nil
  if self.StartAirbase then
    local airbase = AIRBASE:FindByName(self.StartAirbase)
    if airbase then
      BASE:I(string.format("Spawning %s at airbase: %s", self.Callsign, self.StartAirbase))
      local success, result = pcall(function()
        -- Spawn normally - reusing same SPAWN object prevents cleanup conflicts
        return spawner:SpawnAtAirbase(airbase, SPAWN.Takeoff.Cold)
      end)
      
      if success then
        spawnedGroup = result
      else
        BASE:E(string.format("ERROR: Failed to spawn at airbase %s: %s", self.StartAirbase, tostring(result)))
      end
    else
      BASE:E(string.format("ERROR: Airbase '%s' not found for spawn", self.StartAirbase))
    end
  end
  
  -- Fallback to normal spawn if airbase spawn failed
  if not spawnedGroup then
    BASE:I(string.format("Using template location spawn for %s (#%d)", self.Callsign, spawnIndex))
    local success, result = pcall(function()
      return spawner:Spawn()
    end)
    
    if not success then
      BASE:E(string.format("ERROR: Exception during spawn: %s", tostring(result)))
      trigger.action.outTextForCoalition(
        self.Coalition,
        string.format(
          "[X] BOMBER SPAWN ERROR\n\n" ..
          "Template: %s\n" ..
          "Error: %s\n\n" ..
          "Check DCS log for details.",
          self.TemplateName,
          tostring(result)
        ),
        30
      )
      return false
    end
    spawnedGroup = result
  end
  
  self.Group = spawnedGroup
  
  if not self.Group then
    BASE:E("ERROR: Failed to spawn bomber group (returned nil)")
    trigger.action.outTextForCoalition(
      self.Coalition,
      string.format(
        "❌ BOMBER SPAWN FAILED\n\n" ..
        "Template: %s\n" ..
        "Spawn returned nil - check template is properly configured.\n\n" ..
        "MISSION MAKER: Verify Late Activation is enabled.",
        self.TemplateName
      ),
      30
    )
    return false
  end
  
  -- Rename the group to use callsign for F10 map display
  local dcsGroup = self.Group:GetDCSObject()
  if dcsGroup then
    local newName = string.format("%s #%03d", self.Callsign, spawnIndex)
    pcall(function()
      dcsGroup:rename(newName)
      BASE:I(string.format("Renamed group to: %s", newName))
    end)
  end
  
  -- CRITICAL: Stop any default route from template
  -- The template might have a route set in mission editor, clear it immediately
  BASE:I(string.format("%s: Clearing template route to prevent auto-taxi", self.Callsign))
  self.Group:RouteStop()  -- Stop any existing route/taxi orders
  
  self.MissionStartTime = timer.getTime()
  
  -- Initialize monitoring systems (but don't start escort monitor yet if holding)
  self.EscortMonitor = BOMBER_ESCORT_MONITOR:New(self)  -- Create but don't start
  self.ThreatManager = BOMBER_THREAT_MANAGER:New(self):Start()
  
  -- Initialize SAM avoidance router
  if BOMBER_ESCORT_CONFIG.EnableSAMAvoidance then
    self.SAMRouter = BOMBER_SAM_AVOIDANCE_ROUTER:New(self)
    BASE:I(string.format("%s: SAM avoidance router initialized", self.Callsign))
  end
  
  -- Start SAM status summary scheduler (runs every 80 seconds)
  local summaryInterval = BOMBER_ESCORT_CONFIG.SAMStatusSummaryInterval or 80
  self.SAMStatusScheduler = SCHEDULER:New(nil, 
    function()
      if self and self:IsAlive() then
        self:_UpdateSAMStatusSummary()
      end
    end, {}, 15, summaryInterval) -- First run after 15 seconds, then every 80 seconds
  
  BASE:I(string.format("%s: SAM status summary scheduled every %d seconds", self.Callsign, summaryInterval))
  
  -- Initialize formation manager
  self.FormationManager = BOMBER_FORMATION:New(self)
  self.FormationManager:Apply()
  
  -- Set up event handlers
  self:_SetupEventHandlers()
  
  -- Set ROE and ROT - WEAPONS FREE to allow bombing tasks to execute
  self.Group:OptionROEWeaponFree()
  self.Group:OptionROTPassiveDefense()
  
  -- Set alarm state to allow weapon employment
  self.Group:OptionAlarmStateGreen()
  
  -- Allow RTB on out of ammo (let them go home when winchester)
  self.Group:OptionRTBAmmo(true)
  
  BASE:I(string.format("%s: ROE=WEAPONS FREE, Alarm=GREEN, RTB on winchester=ON", self.Callsign))
  
  -- If route exists, prepare it (but don't start yet if holding for escort)
  if self.Route and #self.Route > 0 then
    -- Don't start route yet - check for escort first
    BASE:I(string.format("%s: Route prepared, checking escort requirements", self.Callsign))
  else
    env.warning(string.format("[BOMBER] %s: No route defined for bomber", self.Callsign))
  end
  
  BASE:I(string.format("Bomber %s spawned: %s x%d", self.Callsign, self.Profile.DisplayName, self.FlightSize))
  
  -- Check if escort is required
  if self.Profile.EscortRequired then
    BASE:I(string.format("%s: Escort required - checking for ground escorts", self.Callsign))
    self:__WaitForEscort(2)  -- Transition to HOLDING state after 2 seconds
  else
    BASE:I(string.format("%s: Escort not required - beginning mission immediately", self.Callsign))
    self:_StartRoute()
    -- Transition directly to ENGINE_STARTING since route is commanded
    self:__StartEngines(2)
  end
  
  return true
end

--- Start flying the route
-- @param #BOMBER self
function BOMBER:_StartRoute()
  if not self.Route or #self.Route == 0 then
    return
  end
  
  BASE:I(string.format("%s: Starting route with %d waypoints", self.Callsign, #self.Route))
  
  -- Save original route for resume capability after abort
  if not self.OriginalRoute then
    self.OriginalRoute = self.Route
    BASE:I(string.format("%s: Original route saved for resume capability", self.Callsign))
  end
  
  -- Mark engine start time for detailed state tracking
  self.EngineStartTime = timer.getTime()
  
  -- Activate the group AI to start engines
  self.Group:Activate()
  BASE:I(string.format("%s: Group activated (engines starting)", self.Callsign))
  
  -- Route the group (DCS AI will handle cold start -> taxi -> takeoff)
  self.Group:Route(self.Route)
  BASE:I(string.format("%s: Route commanded - cold start sequence will take ~6 minutes", self.Callsign))
  
  -- Set up waypoint monitoring
  self:_MonitorWaypoints()
  
  -- Start monitoring bomber state for FSM transitions (ENGINE_STARTING -> TAXIING -> TAKING_OFF -> CLIMBING -> CRUISE)
  self:_MonitorEngineStart()
end

--- Monitor bomber state and trigger FSM transitions based on actual aircraft state
-- Monitors: Engine start -> Taxi -> Takeoff -> Climb -> Cruise
-- Also detects stuck conditions (blockage by other aircraft)
-- @param #BOMBER self
function BOMBER:_MonitorEngineStart()
  -- Prevent duplicate monitors (function can be called multiple times in escort scenarios)
  if self.EngineStartMonitor then
    BASE:I(string.format("%s: Engine start monitor already running, skipping duplicate start", self.Callsign))
    return
  end
  
  local startTime = timer.getTime()
  local movementDetectedTime = nil
  local lastMovementTime = nil
  local stuckWarningIssued = false
  
  -- Track position for movement detection
  local lastPosition = nil
  local totalDistanceMoved = 0
  
  -- Track which state we've already transitioned to (prevent duplicate transitions)
  local hasTransitionedToEngineStarting = false
  local hasTransitionedToTaxiing = false
  local hasTransitionedToTakeoff = false
  local hasTransitionedToClimbing = false
  
  -- Track last status message time (outside scheduler so it persists across iterations)
  local lastStatusTime = startTime
  
  self.EngineStartMonitor = SCHEDULER:New(nil, function()
    if not self.Group or not self:IsAlive() then
      BASE:I(string.format("%s: Engine start monitor stopping (not alive)", self.Callsign))
      if self.EngineStartMonitor then
        self.EngineStartMonitor:Stop()
        self.EngineStartMonitor = nil
      end
      return
    end
    
    local currentTime = timer.getTime()
    local velocity = self.Group:GetVelocityKNOTS()
    local altitude = self.Group:GetAltitude()
    local elapsedTime = currentTime - startTime
    
    -- Stop monitoring if we've reached cruise altitude
    local cruiseAlt = self.CruiseAlt or (self.Profile and self.Profile.CruiseAlt) or 20000
    local cruiseAltMeters = cruiseAlt * 0.3048
    if altitude >= (cruiseAltMeters * 0.9) and self:Is(BOMBER.States.CRUISE) then
      BASE:I(string.format("%s: Reached cruise - stopping ground/climb monitor", self.Callsign))
      if self.EngineStartMonitor then
        self.EngineStartMonitor:Stop()
        self.EngineStartMonitor = nil
      end
      return
    end
    
    -- Track movement for stuck detection (use both velocity and position)
    local currentPosition = self.Group:GetCoordinate()
    local hasMoved = false
    
    if currentPosition and lastPosition then
      local distanceMoved = currentPosition:Get2DDistance(lastPosition)
      if distanceMoved > 5 then  -- Moved more than 5 meters
        totalDistanceMoved = totalDistanceMoved + distanceMoved
        hasMoved = true
      end
    end
    
    if velocity > 1 or hasMoved then
      lastMovementTime = currentTime
      if not movementDetectedTime then
        movementDetectedTime = currentTime
        BASE:I(string.format("%s: Initial movement detected (%.1f kts, %.0fm moved, after %.0f seconds)", 
          self.Callsign, velocity, totalDistanceMoved, elapsedTime))
      end
    end
    
    lastPosition = currentPosition
    
    -- Send status updates every 90 seconds during long startup with variety
    if self:Is(BOMBER.States.ENGINE_STARTING) and currentTime - lastStatusTime >= 90 then
      lastStatusTime = currentTime  -- Update BEFORE sending to prevent double-send
      local elapsedMins = math.floor(elapsedTime / 60)
      local waypointCount = self.Route and #self.Route or 0
      
      -- Varied startup messages (rotate for entertainment value)
      local startupMessages = {
        string.format("%s: Calculating climb profile for %d waypoints (%d min elapsed)...", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Still running pre-flight checks on %d waypoints. These old birds take their sweet time! (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Crunching numbers for %d waypoint route. Coffee's getting cold up here... (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Planning route through %d waypoints. Wish Mo was this thorough with his targeting! (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Computing optimal climb for %d waypoints. These engines are older than my copilot! (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Processing flight plan - %d waypoints to calculate. Hope the autopilot remembers them all! (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: %d waypoints to map out. At least we know WHERE we're going, unlike Mo's usual ops... (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Working through %d waypoint calculations. Cold start on these birds ain't quick! (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Flight computer chewing on %d waypoints. This thing's slower than Mo finding a target! (%d min)", self.Callsign, waypointCount, elapsedMins),
        string.format("%s: Validating %d waypoint route profile. These bomber missions take prep - not like Mo's 'point and pray' approach! (%d min)", self.Callsign, waypointCount, elapsedMins),
      }
      
      -- Select message based on elapsed time (cycles through list)
      local messageIndex = (elapsedMins % #startupMessages) + 1
      self:_BroadcastMessage(startupMessages[messageIndex])
      
      BASE:I(string.format("%s: Engine start in progress - %.0f seconds, velocity: %.1f kts", 
        self.Callsign, elapsedTime, velocity))
    end
    
    -- === FSM STATE TRANSITIONS BASED ON PHYSICAL STATE ===
    
    -- SPAWNED -> CLIMBING (catch-all for edge cases where bomber is airborne but stuck in SPAWNED)
    -- This should rarely trigger with proper escort logic, but protects against FSM bugs
    if self:Is(BOMBER.States.SPAWNED) and not hasTransitionedToClimbing then
      if altitude >= 500 and velocity > 100 then  -- Clearly airborne and flying
        BASE:E(string.format("%s: WARNING - Airborne but stuck in SPAWNED state (%.0f ft, %.0f kts) -> CLIMBING (FSM bug workaround)", 
          self.Callsign, altitude * 3.28084, velocity))
        self:_BroadcastMessage(string.format("%s: Airborne at %.0f ft - continuing climb to cruise altitude.", 
          self.Callsign, altitude * 3.28084))
        self:__BeginClimb(0.5)
        hasTransitionedToClimbing = true
        -- Skip other ground-phase transitions since we're already airborne
        hasTransitionedToEngineStarting = true
        hasTransitionedToTaxiing = true
        hasTransitionedToTakeoff = true
      end
    end
    
    -- ENGINE_STARTING -> CLIMBING (catch airborne spawns stuck in engine start)
    -- If bomber is clearly flying but stuck in ENGINE_STARTING, jump directly to CLIMBING
    if self:Is(BOMBER.States.ENGINE_STARTING) and not hasTransitionedToClimbing then
      if altitude >= 500 and velocity > 100 then  -- Clearly airborne and flying
        BASE:E(string.format("%s: WARNING - Airborne but stuck in ENGINE_STARTING state (%.0f ft, %.0f kts) -> CLIMBING (hot start)", 
          self.Callsign, altitude * 3.28084, velocity))
        self:_BroadcastMessage(string.format("%s: Airborne at %.0f ft - proceeding to cruise altitude.", 
          self.Callsign, altitude * 3.28084))
        self:__BeginClimb(0.5)
        hasTransitionedToClimbing = true
        -- Skip other ground-phase transitions since we're already airborne
        hasTransitionedToTaxiing = true
        hasTransitionedToTakeoff = true
      end
    end
    
    -- HOLDING -> ENGINE_STARTING (when route commanded and engines starting)
    if self:Is(BOMBER.States.HOLDING) and self.EngineStartTime and not hasTransitionedToEngineStarting then
      self:__StartEngines(0.5)
      BASE:I(string.format("%s: Transitioning HOLDING -> ENGINE_STARTING", self.Callsign))
      hasTransitionedToEngineStarting = true
    end
    
    -- ENGINE_STARTING -> TAXIING (sustained movement on ground)
    if self:Is(BOMBER.States.ENGINE_STARTING) and not hasTransitionedToTaxiing then
      if movementDetectedTime then
        local timeSinceMovement = currentTime - movementDetectedTime
        BASE:I(string.format("%s: Checking taxi transition: time=%.1fs, vel=%.1fkt, dist=%.0fm, alt=%.0fm", 
          self.Callsign, timeSinceMovement, velocity, totalDistanceMoved, altitude))
      end
      -- Trigger taxi if: sustained movement (5sec) AND (velocity OR distance moved) AND on ground
      if movementDetectedTime and (currentTime - movementDetectedTime) >= 5 and altitude < 50 then
        if velocity > 3 or totalDistanceMoved > 30 then  -- Either speed OR moved 30+ meters
          BASE:I(string.format("%s: Sustained movement confirmed (%.1f kts, %.0fm moved) -> TAXIING", 
            self.Callsign, velocity, totalDistanceMoved))
          self:__BeginTaxi(0.5)
          hasTransitionedToTaxiing = true
        end
      end
    end
    
    -- TAXIING -> TAKING_OFF (fast on ground - takeoff roll)
    if self:Is(BOMBER.States.TAXIING) and not hasTransitionedToTakeoff then
      if velocity >= 50 and altitude < 100 then
        BASE:I(string.format("%s: Takeoff speed reached (%.1f kts) -> TAKING_OFF", self.Callsign, velocity))
        self:__Takeoff(0.5)
        hasTransitionedToTakeoff = true
      end
    end
    
    -- TAKING_OFF -> CLIMBING (airborne and climbing)
    if self:Is(BOMBER.States.TAKING_OFF) and not hasTransitionedToClimbing then
      if altitude >= 500 then  -- 500ft AGL = definitely airborne
        BASE:I(string.format("%s: Airborne (%.0f ft) -> CLIMBING", self.Callsign, altitude * 3.28084))
        self:__BeginClimb(0.5)
        hasTransitionedToClimbing = true
      end
    end
    
    -- Start escort monitoring once we're above 500ft (if required and not already started)
    -- Early monitoring during takeoff/climb allows tracking escorts from departure
    -- More lenient thresholds during CLIMBING allow formation assembly
    -- For multi-ship flights, wait until all aircraft are airborne to avoid false alarms during staggered takeoff
    if self.Profile.EscortRequired and altitude >= 152 then  -- 500ft in meters (start much earlier)
      if self.EscortMonitor and not self.EscortMonitor.SchedulerID then
        -- Check if all units in the flight are airborne (for multi-ship flights)
        local allAirborne = true
        local units = self.Group:GetUnits()
        if units and #units > 1 then
          for _, unit in ipairs(units) do
            if unit and unit:IsAlive() then
              local unitAlt = unit:GetAltitude()
              if unitAlt < 152 then  -- Any unit still below 500ft
                allAirborne = false
                break
              end
            end
          end
        end
        
        if allAirborne then
          BASE:I(string.format("%s: All aircraft airborne (%.0f ft) - starting escort monitoring", self.Callsign, altitude * 3.28084))
          self.EscortMonitor:Start()
        end
      end
    end
    
    -- CLIMBING -> CRUISE (reached cruise altitude)
    if self:Is(BOMBER.States.CLIMBING) then
      if altitude >= (cruiseAltMeters * 0.9) then  -- Within 10% of cruise altitude
        BASE:I(string.format("%s: Reached cruise altitude (%.0f ft) -> CRUISE", self.Callsign, altitude * 3.28084))
        self:__ReachCruise(0.5)
      end
    end
    
    -- === STUCK DETECTION (works during TAXIING/TAKING_OFF states) ===
    if (self:Is(BOMBER.States.TAXIING) or self:Is(BOMBER.States.TAKING_OFF)) then
      if movementDetectedTime and lastMovementTime then
        local stuckDuration = currentTime - lastMovementTime
        
        if velocity < 1 and stuckDuration >= 60 then
          -- Transition to BLOCKED state after 1 minute of being stuck
          if not self:Is(BOMBER.States.BLOCKED) then
            BASE:E(string.format("%s: WARNING - Bomber stuck/blocked (stationary for %.0f seconds) -> BLOCKED", 
              self.Callsign, stuckDuration))
            self:__Blocked(0.5)
            stuckWarningIssued = true
          end
        end
      end
    end
    
    -- === BLOCKAGE CLEARANCE DETECTION (works when in BLOCKED state) ===
    if self:Is(BOMBER.States.BLOCKED) then
      if movementDetectedTime and lastMovementTime then
        local stuckDuration = currentTime - lastMovementTime
        
        -- Check if blockage cleared (movement resumed)
        if velocity > 1 then
          BASE:I(string.format("%s: Blockage cleared - resuming (velocity: %.1f kts)", self.Callsign, velocity))
          self:_BroadcastMessage(string.format("%s: [OK] Taxiway cleared - resuming departure", 
            self.Callsign))
          
          -- Reset transition flags so we can progress through states again
          -- Based on where we were before blockage
          if self.PreBlockedState == BOMBER.States.TAKING_OFF then
            -- We were taking off - allow TAKING_OFF -> CLIMBING transition
            hasTransitionedToTakeoff = true
            hasTransitionedToClimbing = false
          else
            -- We were taxiing - allow TAXIING -> TAKING_OFF transition
            hasTransitionedToTakeoff = false
          end
          
          -- Clear blockage - will transition back to TAXIING via FSM rule
          self:__ClearBlockage(0.5)
          stuckWarningIssued = false
          
          -- Reset stuck tracking since we're moving again
          lastMovementTime = currentTime
        else
          -- Still blocked - check if we should scrub mission after 3 minutes total
          if stuckDuration >= 180 then
            BASE:E(string.format("%s: CRITICAL - Bomber stuck for 3 minutes - scrubbing mission", 
              self.Callsign))
            self:_BroadcastMessage(string.format("%s: [X] Aircraft blocked for 3 minutes - mission scrubbed", 
              self.Callsign))
            
            if self.EngineStartMonitor then
              self.EngineStartMonitor:Stop()
              self.EngineStartMonitor = nil
            end
            
            -- Scrub mission and cleanup
            self:_ScrubMission("Blocked on taxiway")
            return
          end
        end
      end
    end
    
    -- Safety timeout: 15 minutes (900 seconds) for complete startup + taxi + takeoff
    -- Don't apply timeout if:
    --   1. Already in flight phases (CLIMBING, CRUISE, PRE_ATTACK, ATTACKING, EGRESSING, ABORTING, RTB)
    --   2. Actually airborne and flying (handles air spawns or state transition issues)
    local isActuallyAirborne = false
    if self.Group and self.Group:IsAlive() then
      local altitude = self.Group:GetAltitude()
      local velocity = self.Group:GetVelocityKNOTS()
      isActuallyAirborne = (altitude > 500 and velocity > 100)  -- Clearly airborne and flying (>500ft, >100kts)
      if isActuallyAirborne then
        BASE:I(string.format("%s: Actually airborne (alt=%.0fft, vel=%.0fkts) - ignoring startup timeout", 
          self.Callsign, altitude / 0.3048, velocity))
      end
    end
    
    if elapsedTime > 900 and not isActuallyAirborne 
       and not self:Is(BOMBER.States.CLIMBING) and not self:Is(BOMBER.States.CRUISE) 
       and not self:Is(BOMBER.States.PRE_ATTACK) and not self:Is(BOMBER.States.ATTACKING) 
       and not self:Is(BOMBER.States.EGRESSING) and not self:Is(BOMBER.States.ABORTING) 
       and not self:Is(BOMBER.States.RTB) then
      BASE:E(string.format("%s: ERROR - Startup/departure timeout after 15 minutes (alt=%.0fft, vel=%.0fkts, state=%s)", 
        self.Callsign, altitude / 0.3048, velocity, self.CurrentState))
      self:_BroadcastMessage(string.format("%s: [X] Aircraft departure failure after 15 minutes - mission scrubbed", 
        self.Callsign))
      
      if self.EngineStartMonitor then
        self.EngineStartMonitor:Stop()
        self.EngineStartMonitor = nil
      end
      
      self:_ScrubMission("Startup/departure timeout")
      return
    end
    
  end, {}, 2, 5)  -- Check every 5 seconds
end

--- Monitor landing progress after RTB
-- @param #BOMBER self
function BOMBER:_MonitorLanding()
  local landingDetectedTime = nil
  local lastVelocity = nil
  local lastAltitude = nil
  
  BASE:I(string.format("%s: Starting landing monitor", self.Callsign))
  self:_LogLandingSnapshot("Landing monitor start", { force = true, includeController = false })
  
  self.LandingMonitor = SCHEDULER:New(nil, function()
    if not self.Group or not self:IsAlive() then
      BASE:I(string.format("%s: Landing monitor stopping (not alive)", self.Callsign))
      self:_CancelLandingFailureDespawn("group not alive")
      if self.LandingMonitor then
        self.LandingMonitor:Stop()
        self.LandingMonitor = nil
      end
      return
    end
    
    -- Only monitor in RTB state
    if not self:Is(BOMBER.States.RTB) then
      BASE:I(string.format("%s: Landing monitor stopping (not in RTB state)", self.Callsign))
      self:_CancelLandingFailureDespawn("state change")
      if self.LandingMonitor then
        self.LandingMonitor:Stop()
        self.LandingMonitor = nil
      end
      return
    end
    
    local currentTime = timer.getTime()
    local velocity = self.Group:GetVelocityKNOTS()
    local altitude = self.Group:GetAltitude()
    
    -- Check landing conditions: altitude < 50ft (15m) and velocity < 5 kts
    local isOnGround = altitude < 15 and velocity < 5
    
    if isOnGround then
      if not landingDetectedTime then
        -- First detection of landing conditions
        landingDetectedTime = currentTime
        lastVelocity = velocity
        lastAltitude = altitude
        BASE:I(string.format("%s: Landing conditions detected (alt: %.1fm, vel: %.1fkts) - waiting for sustained condition", 
          self.Callsign, altitude, velocity))
        self:_LogLandingSnapshot("Landing detect", { force = true, includeController = false })
      else
        -- Check if conditions have been sustained for 10 seconds
        local sustainedTime = currentTime - landingDetectedTime
        
        if sustainedTime >= 10 then
          -- Landed successfully!
          BASE:I(string.format("%s: Sustained landing confirmed (%.1f seconds)", 
            self.Callsign, sustainedTime))
          self:_CancelLandingFailureDespawn("landing detected")
          self:_LogLandingSnapshot("Landing confirmed", { force = true, includeController = false })
          
          if self.LandingMonitor then
            self.LandingMonitor:Stop()
            self.LandingMonitor = nil
          end
          
          -- Transition to LANDED state
          self:__Landed(0.5)
          return
        else
          -- Still waiting for sustained condition
          BASE:I(string.format("%s: Landing sustained for %.1f seconds (alt: %.1fm, vel: %.1fkts)", 
            self.Callsign, sustainedTime, altitude, velocity))
        end
      end
    else
      -- Not on ground - reset detection
      if landingDetectedTime then
        BASE:I(string.format("%s: Landing conditions lost (alt: %.1fm, vel: %.1fkts) - resetting detection", 
          self.Callsign, altitude, velocity))
        self:_LogLandingSnapshot("Landing detect reset", { includeController = false })
        landingDetectedTime = nil
      end
    end
    
  end, {}, 2, 5)  -- Check every 5 seconds
end

--- Apply explicit speed commands for RTB legs
-- @param #BOMBER self
-- @param #number index
function BOMBER:_ApplyRTBWaypointSpeed(index)
  if not self.Group then
    BASE:E(string.format("%s: Cannot apply RTB speed - group handle missing", self.Callsign))
    return
  end

  if not self.RTBRoute or #self.RTBRoute == 0 then
    BASE:E(string.format("%s: Cannot apply RTB speed - RTB route not defined", self.Callsign))
    return
  end

  index = index or 1
  if index < 1 or index > #self.RTBRoute then
    BASE:I(string.format("%s: RTB speed request for invalid waypoint index %d (route has %d)", self.Callsign, index, #self.RTBRoute))
    return
  end

  local waypoint = self.RTBRoute[index]
  if not waypoint then return end

  local targetSpeedMPS = waypoint.speed
  if not targetSpeedMPS or targetSpeedMPS <= 0 then
    local fallbackKnots = self.CruiseSpeed or (self.Profile and self.Profile.CruiseSpeed)
    if fallbackKnots then
      targetSpeedMPS = fallbackKnots * 0.514444
    end
  end

  if not targetSpeedMPS or targetSpeedMPS <= 0 then
    BASE:E(string.format("%s: Unable to determine RTB speed for waypoint %d", self.Callsign, index))
    return
  end

  if self.CurrentRTBSpeedIndex == index and self.CurrentRTBSpeedMPS and math.abs(self.CurrentRTBSpeedMPS - targetSpeedMPS) < 0.5 then
    return
  end

  local ok, err = pcall(function()
    self.Group:SetSpeed(targetSpeedMPS)
  end)

  if ok then
    self.CurrentRTBSpeedMPS = targetSpeedMPS
    self.CurrentRTBSpeedIndex = index
    BASE:I(string.format("%s: Applied RTB speed %.0f kts for waypoint %d/%d", self.Callsign, targetSpeedMPS / 0.514444, index, #self.RTBRoute))
  else
    BASE:E(string.format("%s: Failed to set RTB speed for waypoint %d - %s", self.Callsign, index, tostring(err)))
  end
end

--- Build a mission-editor style landing waypoint for the RTB route.
-- Ensures the last leg is a true DCS "Land" waypoint with an airdrome id so the AI flies a native recovery instead of relying on speed overrides.
-- @param #BOMBER self
-- @param #AIRBASE airbase
-- @param #COORDINATE landingCoord
-- @param #number landingSpeedMPS
-- @param #table landingTasks
-- @param #number fieldAltitude
function BOMBER:_BuildLandingWaypoint(airbase, landingCoord, landingSpeedMPS, landingTasks, fieldAltitude)
  local coord = landingCoord or (airbase and airbase:GetCoordinate())
  if not coord then
    BASE:E(string.format("%s: Unable to build landing waypoint - coordinate missing", self.Callsign))
    return nil
  end

  local wp = coord:WaypointAirLanding(landingSpeedMPS, airbase, landingTasks)
  wp.type = "Land"
  wp.action = "Landing"
  wp.alt_type = "BARO"
  wp.alt = fieldAltitude and (fieldAltitude + 15) or wp.alt or 0
  wp.airdromeId = (airbase and airbase:GetID()) or wp.airdromeId
  wp.properties = wp.properties or {}
  wp.properties.LANDING_POINT = true
  wp.properties.LANDING = true

  local airbaseName = airbase and airbase:GetName() or "unknown airbase"
  BASE:I(string.format("%s: Created explicit landing waypoint for %s (airdromeId %s)", self.Callsign, airbaseName, tostring(wp.airdromeId)))

  return wp
end

--- Safely resolve the active DCS controller for the bomber group.
-- @param #BOMBER self
-- @return DCS Controller or nil, error message when nil
function BOMBER:_GetActiveController()
  local group = self.Group
  if not group then
    return nil, "group reference missing"
  end

  if group.GetController then
    local ok, controllerOrErr = pcall(function()
      return group:GetController()
    end)

    if ok and controllerOrErr then
      return controllerOrErr
    elseif not ok then
      return nil, string.format("GetController threw '%s'", tostring(controllerOrErr))
    end
  end

  if not group.GetDCSObject then
    return nil, "GetDCSObject unavailable"
  end

  local dcsGroup = group:GetDCSObject()
  if not dcsGroup then
    return nil, "DCS group unavailable"
  end

  if not dcsGroup.getController then
    return nil, "DCS getController missing"
  end

  local okDCS, controllerOrErr = pcall(function()
    return dcsGroup:getController()
  end)

  if okDCS and controllerOrErr then
    return controllerOrErr
  elseif okDCS then
    return nil, "controller unavailable"
  end

  return nil, string.format("getController threw '%s'", tostring(controllerOrErr))
end

--- Call either Moose or native DCS controller methods safely.
-- @param controller Controller instance
-- @param primary string Method name to try first
-- @param secondary string Optional fallback method name
-- @param ... any Extra parameters forwarded to the method
-- @return boolean, any True when call succeeded and method return value (or nil and error string)
local function callController(controller, primary, secondary, ...)
  if not controller then
    return false, nil, "controller missing"
  end

  local function invoke(methodName, ...)
    local fn = methodName and controller[methodName]
    if type(fn) ~= "function" then
      return false, nil, string.format("method %s unavailable", tostring(methodName))
    end

    local ok, result = pcall(fn, controller, ...)
    if ok then
      return true, result
    end
    return false, nil, string.format("%s threw '%s'", methodName, tostring(result))
  end

  local ok, result, err = invoke(primary, ...)
  if ok then
    return true, result
  end

  if secondary then
    local okAlt, resultAlt, errAlt = invoke(secondary, ...)
    if okAlt then
      return true, resultAlt
    end
    return false, nil, errAlt
  end

  return false, nil, err
end

--- Read the current mission task from whichever controller implementation we have.
-- @param #BOMBER self
-- @param controller Controller instance
-- @return table, string Mission task or error text
function BOMBER:_GetControllerMissionTask(controller)
  local ok, task, err = callController(controller, "GetTask", "getTask")
  if ok then
    return task
  end
  return nil, err or "controller task unavailable"
end

--- Push a task regardless of controller implementation casing.
-- @param #BOMBER self
-- @param controller Controller instance
-- @param task table DCS task to push
-- @return boolean, string Success flag and optional error message
function BOMBER:_PushControllerTask(controller, task)
  if not task then
    return false, "task missing"
  end

  local ok, _, err = callController(controller, "PushTask", "pushTask", task)
  if ok then
    return true
  end
  return false, err or "controller pushTask unavailable"
end

--- Force a direct landing task if the AI gets stuck orbiting the landing waypoint.
-- @param #BOMBER self
-- @param #string reason Optional logging context
function BOMBER:_ForceLandingTask(reason)
  if self.RTBLandingFallbackIssued then
    return
  end

  local group = self.Group
  if not group or not group:IsAlive() then
    BASE:E(string.format("%s: Cannot force landing task - group not alive", self.Callsign))
    return
  end

  local controller, controllerErr = self:_GetActiveController()
  if not controller then
    BASE:E(string.format("%s: Cannot force landing task - %s", self.Callsign, controllerErr or "controller unavailable"))
    return
  end

  local landingTask = self.RTBLandingTask
  if not landingTask then
    local airbase = self.RTBAirbase
    if not airbase or not airbase:GetCoordinate() then
      BASE:E(string.format("%s: Cannot build fallback landing task - airbase reference missing", self.Callsign))
      return
    end
    landingTask = group:TaskLandAtVec2(airbase:GetCoordinate():GetVec2())
    self.RTBLandingTask = landingTask
  end

  self:_LogLandingSnapshot("ForceLandingTask (pre)", { force = true })

  local ok, err = pcall(function()
    local pushed, pushErr = self:_PushControllerTask(controller, landingTask)
    if not pushed then
      error(pushErr or "controller rejected push task")
    end
  end)

  if ok then
    self.RTBLandingFallbackIssued = true
    BASE:I(string.format("%s: Forced immediate landing task (%s)", self.Callsign, reason or "fallback trigger"))
    self:_LogLandingSnapshot("ForceLandingTask (success)", { force = true })
  else
    BASE:E(string.format("%s: Failed to push landing fallback task - %s", self.Callsign, tostring(err)))
    self:_LogLandingSnapshot("ForceLandingTask (error)", { force = true })
  end
end

--- Track progress on the final landing waypoint and trigger fallbacks if needed.
-- @param #BOMBER self
-- @param #number distanceMeters Current distance to the active landing waypoint
function BOMBER:_TrackLandingProgress(distanceMeters)
  if not self.RTBRoute or #self.RTBRoute == 0 then
    self.RTBLandingStuckSeconds = 0
    return
  end

  local finalIndex = #self.RTBRoute
  local currentIndex = self.RTBWaypointIndex or 1
  if currentIndex ~= finalIndex then
    self.RTBLandingStuckSeconds = 0
    return
  end

  local stuckDistance = BOMBER_ESCORT_CONFIG.RTBLandingStuckDistance or 8000
  if distanceMeters < stuckDistance then
    self.RTBLandingStuckSeconds = 0
    return
  end

  local interval = self.RTBMonitorInterval or 5
  self.RTBLandingStuckSeconds = (self.RTBLandingStuckSeconds or 0) + interval

  local requiredTime = BOMBER_ESCORT_CONFIG.RTBLandingStuckTime or 90
  if self.RTBLandingStuckSeconds >= requiredTime and not self.RTBLandingFallbackIssued then
    local reason = string.format("stuck %.1f km from runway for %.0fs", distanceMeters / 1000, self.RTBLandingStuckSeconds)
    BASE:E(string.format("%s: Landing fallback triggered - %s", self.Callsign, reason))
    self:_LogLandingSnapshot("Landing fallback trigger", { force = true })
    self:_ForceLandingTask(reason)
    self:_ScheduleLandingFailureDespawn("landing fallback")
    self.RTBLandingStuckLogged = self.RTBLandingStuckSeconds
    return
  end

  local snapshotInterval = BOMBER_ESCORT_CONFIG.RTBLandingSnapshotInterval or 0
  if snapshotInterval > 0 then
    local lastLogged = self.RTBLandingStuckLogged or 0
    if self.RTBLandingStuckSeconds - lastLogged >= snapshotInterval then
      self.RTBLandingStuckLogged = self.RTBLandingStuckSeconds
      self:_LogLandingSnapshot("Landing stuck", { force = true })
    end
  end
end

--- Compute distance from current aircraft position to a given RTB waypoint index.
-- @param #BOMBER self
-- @param #number index
-- @return #number|nil Distance in meters or nil when unavailable
function BOMBER:_GetDistanceToRTBWaypoint(index)
  if not index or index < 1 then return nil end
  if not self.RTBRoute or #self.RTBRoute == 0 then return nil end
  if index > #self.RTBRoute then index = #self.RTBRoute end
  if not self.Group or not self.Group:IsAlive() then return nil end
  local coord = self.Group:GetCoordinate()
  if not coord then return nil end
  local wp = self.RTBRoute[index]
  if not wp or not wp.x or not wp.y then return nil end
  local wpCoord = COORDINATE:New(wp.x, wp.alt or 0, wp.y)
  return coord:Get2DDistance(wpCoord)
end

--- Emit a detailed landing/RTB snapshot for troubleshooting.
-- @param #BOMBER self
-- @param #string context Label for the snapshot
-- @param #table options { force = bool, includeController = bool }
function BOMBER:_LogLandingSnapshot(context, options)
  options = options or {}
  local throttle = BOMBER_ESCORT_CONFIG.RTBLandingSnapshotInterval or 0
  local now = timer.getTime()
  if not options.force and throttle > 0 then
    if self._LastLandingSnapshotTime and (now - self._LastLandingSnapshotTime) < throttle then
      return
    end
    self._LastLandingSnapshotTime = now
  else
    self._LastLandingSnapshotTime = now
  end

  local routeCount = self.RTBRoute and #self.RTBRoute or 0
  local currentIndex = self.RTBWaypointIndex or 1
  local infoParts = {}
  table.insert(infoParts, string.format("state=%s", self:GetState() or "n/a"))
  table.insert(infoParts, string.format("wp=%d/%d", currentIndex, routeCount))
  table.insert(infoParts, string.format("stuck=%.0fs", self.RTBLandingStuckSeconds or 0))
  table.insert(infoParts, string.format("fallback=%s", self.RTBLandingFallbackIssued and "yes" or "no"))
  if self.LandingFailureDespawnTimer then
    table.insert(infoParts, "despawn=scheduled")
  end

  local activeDist = self:_GetDistanceToRTBWaypoint(currentIndex)
  if activeDist then
    table.insert(infoParts, string.format("wp-dist=%.1fkm", activeDist / 1000))
  end
  if routeCount > 0 then
    local finalDist = self:_GetDistanceToRTBWaypoint(routeCount)
    if finalDist then
      table.insert(infoParts, string.format("final-dist=%.1fkm", finalDist / 1000))
    end
  end

  if self.Group and self.Group:IsAlive() then
    local speed = self.Group:GetVelocityKNOTS() or 0
    local altitude = self.Group:GetAltitude() or 0
    table.insert(infoParts, string.format("spd=%.0fkts", speed))
    table.insert(infoParts, string.format("alt=%.0fft", UTILS and UTILS.MetersToFeet and UTILS.MetersToFeet(altitude) or altitude * 3.28084))
  end

  if self.RTBAirbase then
    table.insert(infoParts, string.format("rtb=%s", self.RTBAirbase:GetName()))
  end

  BASE:I(string.format("%s: LANDING SNAPSHOT [%s] %s", self.Callsign, context, table.concat(infoParts, " | ")))

  if options.includeController == false then
    return
  end

  local controller, controllerErr = self:_GetActiveController()
  if not controller then
    BASE:E(string.format("%s: LANDING SNAPSHOT [%s] controller unavailable (%s)", self.Callsign, context, controllerErr or "unknown"))
    return
  end

  local missionTask, taskErr = self:_GetControllerMissionTask(controller)
  if not missionTask then
    BASE:E(string.format("%s: LANDING SNAPSHOT [%s] controller task unreadable (%s)", self.Callsign, context, taskErr or "unknown"))
    return
  end

  local routePoints = missionTask.params and missionTask.params.route and missionTask.params.route.points
  local routePointCount = routePoints and #routePoints or 0
  BASE:I(string.format("%s: LANDING SNAPSHOT [%s] controller task %s with %d point(s)", self.Callsign, context, tostring(missionTask.id), routePointCount))

  if routePoints and routePointCount > 0 then
    local lastPoint = routePoints[routePointCount]
    if lastPoint and lastPoint.x and lastPoint.y then
      local coordDesc = COORDINATE:New(lastPoint.x, lastPoint.alt or 0, lastPoint.y):ToStringLLDMS()
      local altFeet = lastPoint.alt and ((UTILS and UTILS.MetersToFeet and UTILS.MetersToFeet(lastPoint.alt)) or (lastPoint.alt * 3.28084)) or 0
      local speedKnots = lastPoint.speed and (lastPoint.speed / 0.514444) or 0
      BASE:I(string.format("%s: LANDING SNAPSHOT [%s] final controller WP -> %s | alt %.0fft | spd %.0fkts | action %s", self.Callsign, context, coordDesc, altFeet, speedKnots, lastPoint.action or lastPoint.type or "UNKNOWN"))
    end
  end
end

--- Schedule a fail-safe despawn if landing never completes.
-- @param #BOMBER self
-- @param #string reason Context for scheduling
function BOMBER:_ScheduleLandingFailureDespawn(reason)
  local delay = BOMBER_ESCORT_CONFIG.RTBLandingDespawnDelaySeconds
  if not delay or delay <= 0 then
    return
  end
  if self.LandingFailureDespawnTimer then
    return
  end

  BASE:E(string.format("%s: Landing failure despawn scheduled in %ds (%s)", self.Callsign, delay, reason or "no reason"))
  self.LandingFailureDespawnTimer = SCHEDULER:New(nil, function()
    self.LandingFailureDespawnTimer = nil
    if not self:IsAlive() then
      return
    end
    if self:Is(BOMBER.States.LANDED) then
      BASE:I(string.format("%s: Landing failure despawn canceled (already landed)", self.Callsign))
      return
    end
    self:_LogLandingSnapshot("Landing failure despawn", { force = true })
    self:_BroadcastMessage(string.format("%s: Could not complete landing in time - despawning to prevent mission stall.", self.Callsign))
    self:_ScrubMission("Landing failure despawn")
  end, {}, delay)
end

--- Cancel any pending landing failure despawn timers.
-- @param #BOMBER self
-- @param #string reason Optional log context
function BOMBER:_CancelLandingFailureDespawn(reason)
  if self.LandingFailureDespawnTimer then
    self.LandingFailureDespawnTimer:Stop()
    self.LandingFailureDespawnTimer = nil
    BASE:I(string.format("%s: Landing failure despawn canceled (%s)", self.Callsign, reason or "cleared"))
  end
end

--- Monitor RTB waypoint progress for debugging
-- @param #BOMBER self
function BOMBER:_StartRTBMonitor()
  if self.RTBMonitor then
    BASE:I(string.format("%s: Restarting RTB monitor", self.Callsign))
    self.RTBMonitor:Stop()
    self.RTBMonitor = nil
  end

  self.RTBWaypointIndex = 1
  self.CurrentRTBSpeedIndex = nil
  self.CurrentRTBSpeedMPS = nil
  local monitorInterval = 5
  self.RTBMonitorInterval = monitorInterval
  self.RTBLandingStuckSeconds = 0

  if self.RTBRoute and #self.RTBRoute > 0 then
    self:_ApplyRTBWaypointSpeed(self.RTBWaypointIndex)
  end

  local function feet(valueMeters)
    if not valueMeters then return 0 end
    if UTILS and UTILS.MetersToFeet then
      return UTILS.MetersToFeet(valueMeters)
    end
    return valueMeters * 3.28084
  end

  BASE:I(string.format("%s: RTB progress monitor started", self.Callsign))

  self.RTBMonitor = SCHEDULER:New(nil, function()
    if not self.Group or not self:IsAlive() then
      BASE:I(string.format("%s: RTB monitor stopping (group not alive)", self.Callsign))
      if self.RTBMonitor then
        self.RTBMonitor:Stop()
        self.RTBMonitor = nil
      end
      return
    end

    if not self.RTBRoute or #self.RTBRoute == 0 then
      BASE:I(string.format("%s: RTB monitor stopping (no RTB route)", self.Callsign))
      if self.RTBMonitor then
        self.RTBMonitor:Stop()
        self.RTBMonitor = nil
      end
      return
    end

    if not (self:Is(BOMBER.States.ABORTING) or self:Is(BOMBER.States.RTB)) then
      BASE:I(string.format("%s: RTB monitor stopping (state %s)", self.Callsign, self:GetState()))
      if self.RTBMonitor then
        self.RTBMonitor:Stop()
        self.RTBMonitor = nil
      end
      return
    end

    local coord = self.Group:GetCoordinate()
    if not coord then
      BASE:E(string.format("%s: RTB monitor cannot read aircraft position", self.Callsign))
      return
    end

    local currentSpeed = self.Group:GetVelocityKNOTS() or 0
    local currentAltMeters = self.Group:GetAltitude() or 0
    BASE:I(string.format("%s: RTB monitor tick - state %s | speed %.0f kts | alt %.0fft", self.Callsign, self:GetState(), currentSpeed, feet(currentAltMeters)))

    local index = self.RTBWaypointIndex or 1
    if index > #self.RTBRoute then
      BASE:I(string.format("%s: RTB monitor reached end of route (%d points)", self.Callsign, #self.RTBRoute))
      if self.RTBMonitor then
        self.RTBMonitor:Stop()
        self.RTBMonitor = nil
      end
      return
    end

    local nextWP = self.RTBRoute[index]
    if nextWP and nextWP.x and nextWP.y then
      local wpCoord = COORDINATE:New(nextWP.x, nextWP.alt or 0, nextWP.y)
      local distanceMeters = coord:Get2DDistance(wpCoord)
      self:_TrackLandingProgress(distanceMeters)
      BASE:I(string.format("%s: RTB monitor - WP %d/%d distance %.1f km (target alt %.0fft, target spd %.0f kts)",
        self.Callsign,
        index,
        #self.RTBRoute,
        distanceMeters / 1000,
        feet(nextWP.alt or 0),
        (nextWP.speed or 0) / 0.514444))

      if distanceMeters < 4000 then
        self.RTBWaypointIndex = index + 1
        BASE:I(string.format("%s: RTB monitor advancing to waypoint %d", self.Callsign, self.RTBWaypointIndex))
        if self.RTBWaypointIndex <= #self.RTBRoute then
          self:_ApplyRTBWaypointSpeed(self.RTBWaypointIndex)
        end
      end
    else
      BASE:E(string.format("%s: RTB waypoint %d missing coordinate data", self.Callsign, index))
      self.RTBWaypointIndex = index + 1
    end

  end, {}, 1, monitorInterval)
end

--- Monitor waypoint progress
-- @param #BOMBER self
function BOMBER:_MonitorWaypoints()
  -- Track current waypoint index
  self.CurrentWaypointIndex = 1
  
  -- Find which waypoint has the bombing task (to know when to transition to ATTACKING)
  self.BombingWaypointIndex = nil
  if self.Route then
    for i, wp in ipairs(self.Route) do
      if wp.task and wp.task.params and wp.task.params.tasks then
        for _, task in ipairs(wp.task.params.tasks) do
          if task.id == "Bombing" or task.id == "CarpetBombing" then
            self.BombingWaypointIndex = i
            BASE:I(string.format("%s: Detected bombing task at waypoint %d/%d", self.Callsign, i, #self.Route))
            break
          end
        end
      end
      if self.BombingWaypointIndex then break end
    end
  end
  
  -- Schedule waypoint checks
  self.WaypointMonitor = SCHEDULER:New(nil, function()
    -- Early exit if group or unit no longer exists
    if not self.Group or not self.Group:IsAlive() then
      BASE:I(string.format("%s: Group no longer alive - stopping waypoint monitor", self.Callsign))
      if self.WaypointMonitor then
        self.WaypointMonitor:Stop()
        self.WaypointMonitor = nil
      end
      return
    end
    
    BASE:I(string.format("%s: Waypoint monitor cycle - checking position and state", self.Callsign))
    
    if not self:IsAlive() then
      BASE:I(string.format("%s: Not alive, skipping monitor", self.Callsign))
      return
    end
    
    if not self.Route then
      BASE:I(string.format("%s: No route defined, skipping monitor", self.Callsign))
      return
    end
    
    local totalWP = #self.Route
    if totalWP == 0 then 
      BASE:I(string.format("%s: Route has 0 waypoints, skipping monitor", self.Callsign))
      return 
    end
    
    BASE:I(string.format("%s: Current state: %s, Current WP Index: %d/%d", 
      self.Callsign, self:GetState(), self.CurrentWaypointIndex, totalWP))
    
    -- Get current position
    local currentPos = self.Group:GetCoordinate()
    if not currentPos then 
      BASE:E(string.format("%s: Failed to get current coordinate!", self.Callsign))
      return 
    end
    
    BASE:I(string.format("%s: Current position: %s", self.Callsign, currentPos:ToStringLLDMS()))
    
    -- Check distance to next waypoint
    if self.CurrentWaypointIndex <= totalWP then
      local nextWP = self.Route[self.CurrentWaypointIndex]
      if nextWP and nextWP.x and nextWP.y then
        local wpCoord = COORDINATE:New(nextWP.x, nextWP.alt or 0, nextWP.y)
        local distance = currentPos:Get2DDistance(wpCoord)
        
        -- If within 5km of waypoint, consider it reached (larger radius for IP runs)
        if distance < 5000 then
          BASE:I(string.format("%s: Reached waypoint %d/%d (distance: %.1f km)", self.Callsign, self.CurrentWaypointIndex, totalWP, distance/1000))
          self.CurrentWaypointIndex = self.CurrentWaypointIndex + 1
        end
      end
    end
    
    -- Check distance to bombing waypoint for state transitions (CRUISE -> PRE_ATTACK -> ATTACKING)
    if self.BombingWaypointIndex then
      local bombWP = self.Route[self.BombingWaypointIndex]
      if bombWP and bombWP.x and bombWP.y then
        local bombCoord = COORDINATE:New(bombWP.x, bombWP.alt or 0, bombWP.y)
        local distToBomb = currentPos:Get2DDistance(bombCoord)
        
        -- Only log distance during relevant states
        local currentState = self:GetState()
        if currentState == "PreAttack" or currentState == "Attacking" then
          BASE:I(string.format("%s: Distance to bombing waypoint: %.1f km (State: %s)", 
            self.Callsign, distToBomb/1000, currentState))
        end
        
        -- CRUISE -> PRE_ATTACK when within 50km of target
        if self:Is(BOMBER.States.CRUISE) and distToBomb < 50000 then
          BASE:I(string.format("%s: Approaching target (%.1f km) -> PRE_ATTACK", self.Callsign, distToBomb/1000))
          self:__ApproachTarget(0.5)
        end
        
        -- PRE_ATTACK -> ATTACKING when within 15km of target
        if self:Is(BOMBER.States.PRE_ATTACK) and distToBomb < 15000 then
          BASE:I(string.format("%s: At attack range (%.1f km) -> ATTACKING", self.Callsign, distToBomb/1000))
          self:__BeginAttack(0.5)
        end
      else
        BASE:E(string.format("%s: Bombing waypoint %d has no coordinates!", self.Callsign, self.BombingWaypointIndex))
      end
    else
      BASE:I(string.format("%s: No bombing waypoint detected in route", self.Callsign))
    end
    
    -- Only egress after weapons are actually released AND sufficient time has passed for bomb drop to complete
    -- Require at least 15 seconds after first weapon release to allow full ordnance employment
    if self.WeaponsReleased and self.WeaponsReleaseStartTime and 
       (timer.getTime() - self.WeaponsReleaseStartTime) >= 15 and
       self.BombingWaypointIndex and 
       self.CurrentWaypointIndex >= self.BombingWaypointIndex + 2 and 
       self:Is(BOMBER.States.ATTACKING) then
      BASE:I(string.format("%s: Weapons released %.0fs ago and past bombing area (current: %d, bombing was: %d) - transitioning to EGRESSING", 
        self.Callsign, timer.getTime() - self.WeaponsReleaseStartTime, self.CurrentWaypointIndex, self.BombingWaypointIndex))
      self:__BombsAway(0)
    end
    
    -- RTB when all waypoints complete
    if self.CurrentWaypointIndex > totalWP and self:Is(BOMBER.States.EGRESSING) then
      self:__ReturnToBase(0)
    end
    
  end, {}, 5, 5)  -- Check every 5 seconds instead of 10 for more responsive state changes
end

--- Check if bomber is alive
-- @param #BOMBER self
-- @return #boolean True if alive
function BOMBER:IsAlive()
  return self.Group and self.Group:IsAlive()
end

--- Generate callsign for bomber
-- @param #BOMBER self
-- @return #string Callsign
function BOMBER:_GenerateCallsign()
  local callsigns = {"Overlord", "Fortress", "Hammer", "Thunder", "Steel", "Anvil", "Titan"}
  local idx = math.random(1, #callsigns)
  local flight = math.random(1, 9)
  return string.format("%s %d-1", callsigns[idx], flight)
end

--- Set up event handlers for bomber
-- @param #BOMBER self
function BOMBER:_SetupEventHandlers()
  -- Handle dead event
  self:HandleEvent(EVENTS.Dead, function(self, EventData)
    if EventData.IniGroup and EventData.IniGroup:GetName() == self.Group:GetName() then
      self:Destroy()
    end
  end)
  
  -- Handle land event
  self:HandleEvent(EVENTS.Land, function(self, EventData)
    if EventData.IniGroup and EventData.IniGroup:GetName() == self.Group:GetName() then
      if self:Is(BOMBER.States.RTB) or self:Is(BOMBER.States.EGRESSING) then
        self:__Land(2)
      end
    end
  end)
  
  -- Track IP runs for status announcements
  self.IPRunCount = 0
  self.LastIPRunTime = 0
  
  -- Handle weapon release (Shot event = weapon fired/dropped)
  self:HandleEvent(EVENTS.Shot, function(self, EventData)
    if EventData.IniGroup and EventData.IniGroup:GetName() == self.Group:GetName() then
      -- Only announce first weapon release during attack
      if self:Is(BOMBER.States.ATTACKING) and not self.WeaponsReleased then
        self.WeaponsReleased = true
        self.WeaponsReleaseStartTime = timer.getTime() -- Track when bombs started dropping
        
        -- Use crew awareness callout
        self:_CrewAwarenessCallout("weapons_release")
        
        BASE:I(string.format("%s: SHOT event detected - weapons release started", self.Callsign))
      end
    end
  end)
  
  -- Handle weapon impact (for BDA - Battle Damage Assessment)
  self:HandleEvent(EVENTS.Hit, function(self, EventData)
    -- Check if weapon was fired by our bomber group (our bombs hitting target)
    if EventData.IniGroup and EventData.IniGroup:GetName() == self.Group:GetName() then
      if self:Is(BOMBER.States.ATTACKING) or self:Is(BOMBER.States.EGRESSING) then
        -- Announce impact only once per attack run
        if not self.ImpactAnnounced then
          self.ImpactAnnounced = true
          
          local impactMessages = {
            "%s: Good impacts observed! Target hit!",
            "%s: Direct hit confirmed! Excellent bombing!",
            "%s: Bombs on target! Solid hits!",
            "%s: Target struck! Impact confirmed!"
          }
          local msg = impactMessages[math.random(#impactMessages)]
          
          -- Announce impact after short delay
          SCHEDULER:New(nil, function()
            if self:IsAlive() then
              self:_BroadcastMessage(string.format(msg, self.Callsign))
              BASE:I(string.format("%s: HIT event detected - impact confirmed", self.Callsign))
            end
          end, {}, 2)
        end
      end
    end
    
    -- Check if OUR bomber was hit by enemy fire
    if EventData.TgtGroup and EventData.TgtGroup:GetName() == self.Group:GetName() then
      self:_HandleDamage(EventData)
    end
  end)
  
  -- Handle bomber destruction
  self:HandleEvent(EVENTS.Kill, function(self, EventData)
    if EventData.TgtGroup and EventData.TgtGroup:GetName() == self.Group:GetName() then
      -- Our bomber unit was killed
      local unitName = EventData.TgtUnit and EventData.TgtUnit:GetName() or "Unknown"
      BASE:E(string.format("%s: Unit %s destroyed!", self.Callsign, unitName))
      
      -- Check if entire group is dead
      if not self.Group or not self.Group:IsAlive() or self.Group:GetSize() == 0 then
        self:_HandleCriticalDamage("destroyed")
      end
    end
  end)
end

--- Handle bomber taking damage
-- @param #BOMBER self
-- @param #table EventData Hit event data
function BOMBER:_HandleDamage(EventData)
  -- Initialize damage tracking
  if not self.DamageTracker then
    self.DamageTracker = {
      totalHits = 0,
      lastHitTime = 0,
      lastCalloutTime = 0,
      weaponTypes = {}
    }
  end
  
  local currentTime = timer.getTime()
  self.DamageTracker.totalHits = self.DamageTracker.totalHits + 1
  self.DamageTracker.lastHitTime = currentTime
  
  -- Throttle callouts to max once per 15 seconds
  if currentTime - self.DamageTracker.lastCalloutTime < 15 then
    return
  end
  self.DamageTracker.lastCalloutTime = currentTime
  
  -- Identify weapon type
  local weaponType = "unknown"
  local weaponName = "Unknown"
  
  if EventData.Weapon then
    local weapon = EventData.Weapon
    weaponName = weapon:getTypeName() or "Unknown"
    BASE:I(string.format("%s: Hit by weapon: %s", self.Callsign, weaponName))
    
    -- Detect weapon category
    if weaponName:match("[Ff]lak") or weaponName:match("ZU") or weaponName:match("ZSU") or 
       weaponName:match("Shilka") or weaponName:match("%d+mm") or weaponName:match("M61") or
       weaponName:match("Vulcan") or weaponName:match("Gepard") or weaponName:match("2A38") then
      weaponType = "flak"
    elseif weaponName:match("SA%-") or weaponName:match("S%-") or weaponName:match("Patriot") or
           weaponName:match("HAWK") or weaponName:match("Roland") or weaponName:match("Rapier") or
           weaponName:match("BUK") or weaponName:match("TOR") or weaponName:match("Osa") then
      weaponType = "sam"
    elseif weaponName:match("AIM") or weaponName:match("R%-") or weaponName:match("Sidewinder") or
           weaponName:match("Sparrow") or weaponName:match("AMRAAM") or weaponName:match("Aphid") or
           weaponName:match("Archer") or weaponName:match("Alamo") then
      weaponType = "aam"
    elseif EventData.IniUnit and EventData.IniUnit:IsAir() then
      weaponType = "fighter_gun"
    else
      weaponType = "unknown"
    end
  end
  
  BASE:I(string.format("%s: Damage type classified as: %s (total hits: %d)", 
    self.Callsign, weaponType, self.DamageTracker.totalHits))
  
  -- Get escort status for contextual messages
  local escortCount = self.EscortMonitor and self.EscortMonitor.EscortCount or 0
  local hasEscort = escortCount > 0
  
  -- Generate damage callouts based on weapon type
  local damageMessages = self:_GetDamageMessages(weaponType, hasEscort)
  local message = damageMessages[math.random(#damageMessages)]
  
  self:_BroadcastMessage(string.format("%s: %s", self.Callsign, message))
  
  -- Check for critical damage (multiple hits)
  if self.DamageTracker.totalHits >= 5 then
    SCHEDULER:New(nil, function()
      if self:IsAlive() then
        self:_HandleCriticalDamage(weaponType)
      end
    end, {}, 3)
  end
end

--- Get context-appropriate damage messages
-- @param #BOMBER self
-- @param #string weaponType Type of weapon ("flak", "sam", "aam", "fighter_gun", "unknown")
-- @param #boolean hasEscort Whether bomber has escort support
-- @return #table Array of possible messages
function BOMBER:_GetDamageMessages(weaponType, hasEscort)
  local messages = {}
  
  if weaponType == "flak" then
    if hasEscort then
      messages = {
        "Taking flak! Escorts, suppress that AAA!",
        "Flak burst! We're hit! Escorts, find that gun!",
        "Taking heavy flak! Need that AAA silenced!",
        "[COPILOT] We're taking flak! [PILOT] Escorts, where's that coming from?",
        "Flak hit! [FLIGHT ENGINEER] Checking damage! [PILOT] Stay on target!"
      }
    else
      messages = {
        "Taking flak! No escort coverage!",
        "Flak burst and no escorts! We're sitting ducks!",
        "Heavy flak! Where are our fighters?!",
        "[COPILOT] Taking flak! [PILOT] No escort! Get us out of here!",
        "Flak damage! We need fighters NOW!"
      }
    end
    
  elseif weaponType == "sam" then
    if hasEscort then
      messages = {
        "SAM hit! We're damaged! Escorts, find that launcher!",
        "Missile impact! [FLIGHT ENGINEER] Systems failing! [PILOT] Escorts, nail that SAM!",
        "SAM strike! Need immediate SEAD support!",
        "Surface-to-air hit! Escorts, suppress that site!",
        "[COPILOT] SAM hit us! [PILOT] Escorts, take out that launcher!"
      }
    else
      messages = {
        "SAM hit! No fighter support! We're in trouble!",
        "Missile strike and no escorts! We're exposed!",
        "SAM damage! Where are the fighters?!",
        "[COPILOT] SAM HIT! [PILOT] No escort! Emergency RTB!",
        "Surface-to-air missile! No SEAD support! Aborting!"
      }
    end
    
  elseif weaponType == "aam" then
    if hasEscort then
      messages = {
        "Air-to-air hit! Bandits on us! Escorts, engage!",
        "Missile from fighter! [COPILOT] We're hit! [PILOT] Escorts, get them off us!",
        "Enemy missile impact! Escorts, where are they?!",
        "Fighter missile strike! Need immediate assistance!",
        "[FLIGHT ENGINEER] Air-to-air hit! [PILOT] Escorts, engage those bandits!"
      }
    else
      messages = {
        "FIGHTER MISSILE! NO ESCORT! WE'RE DEAD!",
        "Air-to-air hit! No escorts! MAYDAY!",
        "Enemy missile and no support! We're done for!",
        "[COPILOT] MISSILE HIT! [PILOT] NO FIGHTERS! MAYDAY MAYDAY!",
        "Fighter attack! No escort! Emergency emergency!"
      }
    end
    
  elseif weaponType == "fighter_gun" then
    if hasEscort then
      messages = {
        "Taking cannon fire! Bandits on our six! Escorts, break them off!",
        "Fighter attack! Gun hits! Escorts, engage!",
        "[COPILOT] Fighters shooting us! [PILOT] Escorts, get them!",
        "Under fighter attack! Escorts, we need help NOW!",
        "Cannon hits! Where are our escorts?!"
      }
    else
      messages = {
        "FIGHTERS ATTACKING! NO ESCORT! WE'RE EXPOSED!",
        "Taking cannon fire with no support! MAYDAY!",
        "Fighter attack! No escorts! We're defenseless!",
        "[COPILOT] FIGHTERS! [PILOT] NO ESCORT! BREAK BREAK!",
        "Gun attack! No fighters to help! Critical situation!"
      }
    end
    
  else
    -- Generic damage
    if hasEscort then
      messages = {
        "We're hit! Taking damage!",
        "[COPILOT] We're hit! [FLIGHT ENGINEER] Checking systems!",
        "Taking fire! Escorts, cover us!",
        "Damage sustained! Need support!",
        "We're under attack! Escorts, help!"
      }
    else
      messages = {
        "WE'RE HIT! No escort!",
        "Taking damage with no support!",
        "[COPILOT] WE'RE HIT! [PILOT] No escort! RTB NOW!",
        "Under fire! No fighters! Emergency!",
        "Damage! No escort coverage! Aborting!"
      }
    end
  end
  
  return messages
end

--- Handle critical damage / going down
-- @param #BOMBER self
-- @param #string cause Cause of critical damage
function BOMBER:_HandleCriticalDamage(cause)
  if self.CriticalDamageCalled then
    return  -- Only call once
  end
  self.CriticalDamageCalled = true
  
  BASE:E(string.format("%s: CRITICAL DAMAGE - %s", self.Callsign, cause))
  
  local criticalMessages = {
    "MAYDAY MAYDAY MAYDAY! We're going down!",
    "[COPILOT] WE'RE LOSING IT! [PILOT] MAYDAY! Aircraft breaking apart!",
    "CRITICAL DAMAGE! We can't stay airborne! Going down!",
    "Engines failing! We're going down! MAYDAY MAYDAY!",
    "[FLIGHT ENGINEER] FIRE IN THE FUSELAGE! [PILOT] BAIL OUT BAIL OUT!",
    "We're done for! Aircraft is falling! MAYDAY!",
    "Can't maintain altitude! We're going down! MAYDAY MAYDAY!",
    "[COPILOT] LOSING CONTROL! [PILOT] Crew prepare to bail out!",
    "CATASTROPHIC DAMAGE! We're not gonna make it! MAYDAY!",
    "Aircraft breaking up! Going down! Good luck everyone!"
  }
  
  local message = criticalMessages[math.random(#criticalMessages)]
  self:_BroadcastMessage(string.format("%s: %s", self.Callsign, message))
  
  -- If still somehow alive after 10 seconds, force abort
  SCHEDULER:New(nil, function()
    if self:IsAlive() and not self:Is(BOMBER.States.RTB) and not self:Is(BOMBER.States.ABORTING) then
      BASE:I(string.format("%s: Critical damage - forcing abort", self.Callsign))
      self:Abort()
    end
  end, {}, 10)
end

--- Add fighter to escort roster with memory management
-- @param #BOMBER self
-- @param #string callsign Fighter callsign
-- @param Wrapper.Unit#UNIT unit Fighter unit
function BOMBER:_AddToEscortRoster(callsign, unit)
  local currentTime = timer.getTime()
  
  if not self.EscortRoster[callsign] then
    -- New escort joining
    self.EscortRoster[callsign] = {
      unit = unit,
      joinTime = currentTime,
      lastSeen = currentTime,
      rejoins = 0
    }
    -- Store in LastKnownEscorts for message personalization
    if not self.LastKnownEscorts then
      self.LastKnownEscorts = {}
    end
    table.insert(self.LastKnownEscorts, callsign)
    BASE:I(string.format("%s: Added %s to escort roster", self.Callsign, callsign))
  else
    -- Existing escort seen again
    self.EscortRoster[callsign].lastSeen = currentTime
  end
  
  -- Prune old entries to prevent memory bloat
  self:_PruneEscortRoster()
end

--- Update escort roster based on current scan with join/leave announcements and classification
-- @param #BOMBER self
-- @param #table currentEscorts Table of {callsign = {unit, classification, details}}
function BOMBER:_UpdateEscortRoster(currentEscorts)
  local currentTime = timer.getTime()
  local joined = {}
  local joinedConfirmed = {}
  local joinedProbable = {}
  local left = {}
  local statusChanged = {}  -- Track escorts whose classification changed
  
  -- Check for new escorts (joins)
  for callsign, escortData in pairs(currentEscorts) do
    local unit = escortData.unit
    local classification = escortData.classification
    local details = escortData.details
    
    if not self.EscortRoster[callsign] then
      -- New escort
      if classification == "confirmed" then
        table.insert(joinedConfirmed, callsign)
      elseif classification == "probable" then
        table.insert(joinedProbable, callsign)
      end
      
      self.EscortRoster[callsign] = {
        unit = unit,
        joinTime = currentTime,
        lastSeen = currentTime,
        rejoins = 0,
        classification = classification,
        details = details,
        positionHistory = {{time = currentTime, coord = unit:GetCoordinate(), heading = details.heading or 0}}
      }
    else
      -- Known escort, update info
      local timeSinceLastSeen = currentTime - self.EscortRoster[callsign].lastSeen
      local previousClassification = self.EscortRoster[callsign].classification
      
      if timeSinceLastSeen > 120 then  -- Was gone for > 2 minutes
        if classification == "confirmed" then
          table.insert(joinedConfirmed, callsign)
        elseif classification == "probable" then
          table.insert(joinedProbable, callsign)
        end
        self.EscortRoster[callsign].rejoins = self.EscortRoster[callsign].rejoins + 1
      elseif previousClassification ~= classification then
        -- Track classification changes (e.g., probable -> confirmed)
        table.insert(statusChanged, {callsign = callsign, from = previousClassification, to = classification})
      end
      
      self.EscortRoster[callsign].lastSeen = currentTime
      self.EscortRoster[callsign].classification = classification
      self.EscortRoster[callsign].details = details
      
      -- Update position history (keep last 10 positions for tracking)
      if not self.EscortRoster[callsign].positionHistory then
        self.EscortRoster[callsign].positionHistory = {}
      end
      local coord = unit:GetCoordinate()
      if coord then
        table.insert(self.EscortRoster[callsign].positionHistory, {
          time = currentTime, 
          coord = coord, 
          heading = details.heading or 0
        })
        -- Keep only recent history
        if #self.EscortRoster[callsign].positionHistory > 10 then
          table.remove(self.EscortRoster[callsign].positionHistory, 1)
        end
      end
    end
  end
  
  -- Check for escorts that left (not in current scan)
  for callsign, data in pairs(self.EscortRoster) do
    local timeSinceLastSeen = currentTime - data.lastSeen
    if timeSinceLastSeen > 120 and timeSinceLastSeen < 150 then  -- Just left (2-2.5 min window to announce once)
      table.insert(left, callsign)
    end
  end
  
  -- Announce confirmed escort joins
  if #joinedConfirmed > 0 then
    local joinList = table.concat(joinedConfirmed, ", ")
    self:_CrewCallout("escort_join", string.format("%s: [AC] Escort confirmed in formation: %s", self.Callsign, joinList), 60)
    BASE:I(string.format("%s: Confirmed escorts joined: %s", self.Callsign, joinList))
  end
  
  -- Announce probable escort joins (less urgent)
  if #joinedProbable > 0 then
    local joinList = table.concat(joinedProbable, ", ")
    self:_CrewCallout("escort_probable", string.format("%s: Aircraft detected in vicinity: %s", self.Callsign, joinList), 60)
    BASE:I(string.format("%s: Probable escorts joined: %s", self.Callsign, joinList))
  end
  
  -- Announce significant status changes (probable -> confirmed)
  for _, change in ipairs(statusChanged) do
    if change.from == "probable" and change.to == "confirmed" then
      self:_CrewCallout("escort_confirmed", 
        string.format("%s: %s confirmed as escort - matched course and altitude", self.Callsign, change.callsign), 60)
    -- Removed "drifting out of formation" announcement - too noisy during maneuvers/turns
    -- elseif change.from == "confirmed" and change.to == "probable" then
    --   self:_CrewCallout("escort_drifting", 
    --     string.format("%s: ⚠️ %s drifting out of formation", self.Callsign, change.callsign), 60)
    end
  end
  
  -- Announce departures
  if #left > 0 then
    local leftList = table.concat(left, ", ")
    self:_CrewCallout("escort_left", string.format("%s: [!] Lost escort: %s departed", self.Callsign, leftList), 60)
    BASE:I(string.format("%s: Escorts left: %s", self.Callsign, leftList))
  end
  
  -- Prune roster
  self:_PruneEscortRoster()
end

--- Crew callout with rate limiting to prevent spam
-- @param #BOMBER self
-- @param #string calloutType Unique identifier for this type of callout
-- @param #string message The message to broadcast
-- @param #number cooldown Minimum seconds between same callout type (default: 30)
function BOMBER:_CrewCallout(calloutType, message, cooldown)
  cooldown = cooldown or 30
  local currentTime = timer.getTime()
  
  if not self.LastCrewCalloutTime then
    self.LastCrewCalloutTime = {}
  end
  
  local lastTime = self.LastCrewCalloutTime[calloutType] or 0
  if currentTime - lastTime >= cooldown then
    self:_BroadcastMessage(message)
    self.LastCrewCalloutTime[calloutType] = currentTime
  end
end

--- Get escort status report for crew situational awareness
-- @param #BOMBER self
-- @return #string Status report message
function BOMBER:_GetEscortStatusReport()
  local confirmed = {}
  local probable = {}
  local positions = {
    front = {},
    left = {},
    right = {},
    rear = {},
    high = {},
    low = {}
  }
  
  if not self.Group or not self.Group:IsAlive() then
    return "Unable to determine escort positions"
  end
  
  local bomberCoord = self.Group:GetCoordinate()
  local bomberHeading = self.Group:GetHeading()
  
  -- Analyze escort positions relative to bomber
  for callsign, data in pairs(self.EscortRoster) do
    if data.classification == "confirmed" and data.unit and data.unit:IsAlive() then
      table.insert(confirmed, callsign)
      
      -- Determine relative position
      local escortCoord = data.unit:GetCoordinate()
      if escortCoord then
        local bearing = bomberCoord:HeadingTo(escortCoord)
        local relativeBearing = bearing - bomberHeading
        if relativeBearing < 0 then relativeBearing = relativeBearing + 360 end
        
        local altDiff = data.details.altitude - (self.Group:GetAltitude() * 3.28084)
        
        -- Cardinal positions
        if relativeBearing >= 315 or relativeBearing < 45 then
          table.insert(positions.front, callsign)
        elseif relativeBearing >= 45 and relativeBearing < 135 then
          table.insert(positions.right, callsign)
        elseif relativeBearing >= 135 and relativeBearing < 225 then
          table.insert(positions.rear, callsign)
        else
          table.insert(positions.left, callsign)
        end
        
        -- Altitude
        if altDiff > 1000 then
          table.insert(positions.high, callsign)
        elseif altDiff < -1000 then
          table.insert(positions.low, callsign)
        end
      end
    elseif data.classification == "probable" then
      table.insert(probable, callsign)
    end
  end
  
  -- Build report
  local report = {}
  
  if #confirmed > 0 then
    table.insert(report, string.format("Confirmed escorts: %d", #confirmed))
    
    -- Position summary
    local posSummary = {}
    if #positions.front > 0 then table.insert(posSummary, string.format("%d forward", #positions.front)) end
    if #positions.left > 0 then table.insert(posSummary, string.format("%d port", #positions.left)) end
    if #positions.right > 0 then table.insert(posSummary, string.format("%d starboard", #positions.right)) end
    if #positions.rear > 0 then table.insert(posSummary, string.format("%d aft", #positions.rear)) end
    
    if #posSummary > 0 then
      table.insert(report, "Positions: " .. table.concat(posSummary, ", "))
    end
    
    if #positions.high > 0 then
      table.insert(report, string.format("%d high cover", #positions.high))
    end
    if #positions.low > 0 then
      table.insert(report, string.format("%d low", #positions.low))
    end
  else
    table.insert(report, "No confirmed escorts in formation")
  end
  
  if #probable > 0 then
    table.insert(report, string.format("%d probable nearby", #probable))
  end
  
  return table.concat(report, " | ")
end

--- Generate contextual crew awareness callout based on situation
-- @param #BOMBER self
-- @param #string situation Type of situation: "threat_sam", "threat_fighter", "escort_status", "target_approach"
function BOMBER:_CrewAwarenessCallout(situation)
  local currentTime = timer.getTime()
  
  if situation == "threat_sam" then
    -- Crew reacts to SAM threat with knowledge of escort status
    local escortCount = self.EscortMonitor and self.EscortMonitor.EscortCount or 0
    if escortCount >= 2 then
      self:_CrewCallout("threat_sam", 
        string.format("%s: [PILOT] SAM radar! [COPILOT] Escorts are with us, continuing mission. [EWO] Chaff ready.", self.Callsign), 45)
    elseif escortCount == 1 then
      self:_CrewCallout("threat_sam", 
        string.format("%s: [PILOT] SAM radar! [COPILOT] One escort only... [EWO] Deploying countermeasures!", self.Callsign), 45)
    else
      self:_CrewCallout("threat_sam", 
        string.format("%s: [PILOT] SAM RADAR! [COPILOT] We're alone out here! [NAV] Recommend abort!", self.Callsign), 45)
    end
    
  elseif situation == "threat_fighter" then
    -- Crew reacts to fighter threat
    local escortCount = self.EscortMonitor and self.EscortMonitor.EscortCount or 0
    local hasGuns = self.Profile and self.Profile.HasDefensiveGuns or false
    
    if escortCount >= 2 then
      if hasGuns then
        self:_CrewCallout("threat_fighter", 
          string.format("%s: [COPILOT] Bandits! [PILOT] Escorts, engage! [TAIL GUNNER] I see 'em, in position!", self.Callsign), 45)
      else
        self:_CrewCallout("threat_fighter", 
          string.format("%s: [COPILOT] Bandits! [PILOT] Escorts, engage! [EWO] Countermeasures ready!", self.Callsign), 45)
      end
    elseif escortCount == 1 then
      if hasGuns then
        self:_CrewCallout("threat_fighter", 
          string.format("%s: [COPILOT] BANDITS! [PILOT] Single escort... [WAIST GUNNER] Multiple hostiles, we're outnumbered!", self.Callsign), 45)
      else
        self:_CrewCallout("threat_fighter", 
          string.format("%s: [COPILOT] BANDITS! [PILOT] Single escort... [EWO] We're vulnerable, recommend evasive action!", self.Callsign), 45)
      end
    else
      if hasGuns then
        self:_CrewCallout("threat_fighter", 
          string.format("%s: [TAIL GUNNER] FIGHTERS CLOSING! [PILOT] NO ESCORT! [COPILOT] We need to get out of here!", self.Callsign), 45)
      else
        self:_CrewCallout("threat_fighter", 
          string.format("%s: [EWO] FIGHTERS CLOSING! [PILOT] NO ESCORT! [COPILOT] We need to get out of here NOW!", self.Callsign), 45)
      end
    end
    
  elseif situation == "escort_status" then
    -- Periodic escort status update
    local statusReport = self:_GetEscortStatusReport()
    self:_CrewCallout("escort_status", 
      string.format("%s: [NAV] %s", self.Callsign, statusReport), 120)
    
  elseif situation == "target_approach" then
    -- Crew coordination approaching target
    local escortCount = self.EscortMonitor and self.EscortMonitor.EscortCount or 0
    if escortCount >= self.Profile.MinEscorts then
      self:_CrewCallout("target_approach", 
        string.format("%s: [NAV] IP in 2 minutes. [PILOT] Copy. Escorts, stay tight. [BOMBARDIER] Beginning bomb run.", self.Callsign), 90)
    else
      self:_CrewCallout("target_approach", 
        string.format("%s: [NAV] IP in 2 minutes. [COPILOT] Still waiting on full escort... [PILOT] Holding for now.", self.Callsign), 90)
    end
    
  elseif situation == "weapons_release" then
    -- Bomb release
    self:_CrewCallout("weapons_release", 
      string.format("%s: [BOMBARDIER] BOMBS AWAY! [PILOT] Pulling off target. [NAV] New heading 0-9-0.", self.Callsign), 999)
      
  elseif situation == "damage_taken" then
    -- Aircraft damaged
    local escortCount = self.EscortMonitor and self.EscortMonitor.EscortCount or 0
    if escortCount > 0 then
      self:_CrewCallout("damage", 
        string.format("%s: [COPILOT] We're hit! [FLIGHT ENGINEER] Checking systems! [PILOT] Escorts, cover our six!", self.Callsign), 60)
    else
      self:_CrewCallout("damage", 
        string.format("%s: [COPILOT] WE'RE HIT! [PILOT] No escort! Get us out of here NOW!", self.Callsign), 60)
    end
  end
end

--- Prune escort roster to prevent memory bloat
-- @param #BOMBER self
function BOMBER:_PruneEscortRoster()
  local currentTime = timer.getTime()
  local toRemove = {}
  
  -- Mark entries for removal if not seen in 10 minutes
  for callsign, data in pairs(self.EscortRoster) do
    local timeSinceLastSeen = currentTime - data.lastSeen
    if timeSinceLastSeen > 600 then  -- 10 minutes
      table.insert(toRemove, callsign)
    end
  end
  
  -- Remove stale entries
  for _, callsign in ipairs(toRemove) do
    BASE:I(string.format("%s: Pruning stale escort from roster: %s (not seen for 10+ min)", self.Callsign, callsign))
    self.EscortRoster[callsign] = nil
  end
  
  -- If roster is still too large, remove oldest entries
  local rosterSize = 0
  for _ in pairs(self.EscortRoster) do
    rosterSize = rosterSize + 1
  end
  
  if rosterSize > self.MaxRosterSize then
    -- Build sorted array by lastSeen time
    local sortedRoster = {}
    for callsign, data in pairs(self.EscortRoster) do
      table.insert(sortedRoster, {callsign = callsign, lastSeen = data.lastSeen})
    end
    table.sort(sortedRoster, function(a, b) return a.lastSeen < b.lastSeen end)
    
    -- Remove oldest entries beyond max size
    local toRemoveCount = rosterSize - self.MaxRosterSize
    for i = 1, toRemoveCount do
      local callsign = sortedRoster[i].callsign
      BASE:I(string.format("%s: Pruning escort from roster (size limit): %s", self.Callsign, callsign))
      self.EscortRoster[callsign] = nil
    end
  end
end

--- Prevent further mission resumes after abort is committed
-- @param #BOMBER self
-- @param #string reason Optional context for logging/broadcasts
function BOMBER:_DisableEscortResume(reason)
  if not self.AllowEscortResume then
    return
  end

  self.AllowEscortResume = false
  self.ResumeLockReason = reason or "mission abort locked"
  BASE:I(string.format("%s: Escort resume disabled (%s)", self.Callsign, self.ResumeLockReason))
end

--- Escort arrived event
-- @param #BOMBER self
-- @param #number escortCount Number of escorts
function BOMBER:OnEscortArrived(escortCount)
  self.HasEscort = true
  
  -- Reset escort loss warning flags
  self.EscortLossWarnings = {
    initialWarning = false,
    speedReduction = false,
  }
  
  -- Reset insufficient escort warning flag
  self.InsufficientEscortWarning = false
  
  -- Restore normal speed if it was reduced
  if self.Group and self.Group:IsAlive() then
    self.Group:SetSpeed(self.Profile.CruiseSpeed * 0.514444)
  end
  
  BASE:I(string.format("%s: Escort arrived - %d fighters detected", self.Callsign, escortCount))
  
  local message = string.format("%s: [OK] Escort contact established. %d fighter%s on station. Proceeding with mission.", 
    self.Callsign, escortCount, escortCount > 1 and "s" or "")
  self:_BroadcastMessage(message)

  if not self.AllowEscortResume then
    BASE:I(string.format("%s: Escort arrival detected but resume is locked (%s)", self.Callsign, self.ResumeLockReason or "no reason provided"))
    self:_BroadcastMessage(string.format("%s: Escort contact acknowledged but mission abort is locked. Continuing RTB.", self.Callsign))
    return
  end
  
  -- If was aborting/RTB and escort returns, can resume mission if conditions allow
  if self:Is(BOMBER.States.ABORTING) or self:Is(BOMBER.States.RTB) then
    -- Increment rejoin counter
    self.EscortRejoinCount = self.EscortRejoinCount + 1
    BASE:I(string.format("%s: Escort rejoining (rejoin #%d/%d)", self.Callsign, self.EscortRejoinCount, self.MaxRejoins))
    
    -- Check if too many rejoins - indicates unstable/dangerous situation
    if self.EscortRejoinCount > self.MaxRejoins then
      BASE:I(string.format("%s: DECISION - ABORT (too many escort rejoins: %d)", self.Callsign, self.EscortRejoinCount))
      self:_BroadcastMessage(string.format("%s: [X] Escort rejoined for the %d%s time! Area too dangerous or situation FUBAR. Aborting mission permanently!", 
        self.Callsign, self.EscortRejoinCount, 
        self.EscortRejoinCount == 1 and "st" or (self.EscortRejoinCount == 2 and "nd" or (self.EscortRejoinCount == 3 and "rd" or "th"))))
      
      -- Continue abort, don't resume
      if not self:Is(BOMBER.States.RTB) then
        self:__ReturnToBase(0)
      end
      return
    end
    
    local unescortedTime = self.EscortMonitor and self.EscortMonitor.UnescortedDuration or 0
    BASE:I(string.format("%s: Was aborting/RTB, unescorted for %.0f seconds", self.Callsign, unescortedTime))
    
    -- Check fuel level - need at least 30% to resume mission
    local fuelLevel = 100  -- Default assume full
    if self.Group and self.Group:IsAlive() then
      local unit = self.Group:GetUnit(1)
      if unit then
        local fuel = unit:GetFuel()
        fuelLevel = fuel * 100
        BASE:I(string.format("%s: Current fuel level: %.1f%%", self.Callsign, fuelLevel))
      end
    end
    
    -- Check distance to target
    local distanceToTarget = 999
    if self.BombingWaypoint and self.Group and self.Group:IsAlive() then
      local currentPos = self.Group:GetCoordinate()
      distanceToTarget = currentPos:Get2DDistance(self.BombingWaypoint) / 1000  -- km
      BASE:I(string.format("%s: Distance to target: %.1f km", self.Callsign, distanceToTarget))
    end
    
    -- Resume mission if conditions are favorable
    if fuelLevel >= 30 and unescortedTime < 300 then
      local rejoinsRemaining = self.MaxRejoins - self.EscortRejoinCount
      BASE:I(string.format("%s: DECISION - Resuming mission (fuel=%.1f%%, escort returned, %.1f km to target, %d rejoins remaining)", 
        self.Callsign, fuelLevel, distanceToTarget, rejoinsRemaining))
      
      if rejoinsRemaining > 0 then
        self:_BroadcastMessage(string.format("%s: [OK] Escort rejoined with %.0f%% fuel remaining! Resuming mission to target. WARNING: %d rejoin%s left before permanent abort!", 
          self.Callsign, fuelLevel, rejoinsRemaining, rejoinsRemaining == 1 and "" or "s"))
      else
        self:_BroadcastMessage(string.format("%s: [OK] Escort rejoined with %.0f%% fuel remaining! Resuming mission. FINAL WARNING: This is your LAST chance - one more loss and we're going home for good!", 
          self.Callsign, fuelLevel))
      end
      
      -- Stop waypoint monitoring temporarily
      if self.WaypointMonitor then
        self.WaypointMonitor:Stop()
      end
      
      -- Resume original route to target
      if self.OriginalRoute then
        BASE:I(string.format("%s: Restoring original route with %d waypoints", self.Callsign, #self.OriginalRoute))
        self.Group:Route(self.OriginalRoute, 1)
        
        -- Restart waypoint monitoring
        self:_MonitorWaypoints()
      else
        BASE:E(string.format("%s: ERROR - No original route saved, cannot resume", self.Callsign))
      end
      
      self:Takeoff() -- Transition back to ENROUTE
    else
      -- Can't resume - insufficient fuel or too long
      local reason = fuelLevel < 30 and "insufficient fuel" or "too long without escort"
      BASE:I(string.format("%s: DECISION - Continuing RTB (%s, fuel=%.1f%%)", self.Callsign, reason, fuelLevel))
      self:_BroadcastMessage(string.format("%s: Escort rejoined but %s (%.0f%% fuel). Continuing RTB.", 
        self.Callsign, reason, fuelLevel))
    end
  end
end

--- Escort lost event
-- @param #BOMBER self
-- @param #number unescortedTime Seconds without escort
-- @param #number currentEscortCount Current number of escorts present
-- @param #boolean hadSufficientEscorts Whether we previously had enough escorts
function BOMBER:OnEscortLost(unescortedTime, currentEscortCount, hadSufficientEscorts)
  self.HasEscort = false
  
  -- Don't process escort loss if still on the ground waiting to depart
  if self:Is(BOMBER.States.HOLDING) or self:Is(BOMBER.States.SPAWNED) then
    BASE:I(string.format("%s: Ignoring escort loss - still on ground in %s state", self.Callsign, self.CurrentState))
    return
  end
  
  -- Don't enforce escort requirements during attack run - mission committed at this point
  if self:Is(BOMBER.States.ATTACKING) or self:Is(BOMBER.States.EGRESSING) then
    BASE:I(string.format("%s: Escort lost during %s - continuing mission (attack committed)", self.Callsign, self.CurrentState))
    return
  end
  
  local minRequired = self.Profile.MinEscorts or 1
  
  -- Different handling for insufficient vs lost escorts
  if not hadSufficientEscorts and currentEscortCount > 0 then
    -- Have some escorts but not enough
    BASE:I(string.format("%s: Insufficient escorts - have %d, need %d (%.0fs)", 
      self.Callsign, currentEscortCount, minRequired, unescortedTime))
    
    -- Calculate distance to target for appropriate response
    local distanceToTarget = 999
    if self.BombingWaypoint and self.Group and self.Group:IsAlive() then
      local currentPos = self.Group:GetCoordinate()
      distanceToTarget = currentPos:Get2DDistance(self.BombingWaypoint) / 1000
    end
    
    -- Different behavior based on phase
    if self:Is(BOMBER.States.HOLDING) or self:Is(BOMBER.States.SPAWNED) then
      -- On ground - just wait patiently
      if not self.InsufficientEscortWarning then
        self:_BroadcastMessage(string.format("%s: Have %d escort%s but need %d minimum. Requesting additional fighters, standing by...", 
          self.Callsign, currentEscortCount, currentEscortCount > 1 and "s" or "", minRequired))
        self.InsufficientEscortWarning = true
      end
      return  -- Don't process as "lost" - just waiting for more
      
    else
      -- Airborne - insufficient escorts is a threat, apply distance-based thresholds
      local abortThreshold = 300  -- 5 minutes far from target
      if distanceToTarget < 30 then
        abortThreshold = 120  -- 2 minutes near target
      elseif distanceToTarget < 50 then
        abortThreshold = 180  -- 3 minutes approaching
      elseif distanceToTarget < 100 then
        abortThreshold = 240  -- 4 minutes moderate distance
      end
      
      BASE:I(string.format("%s: Airborne with insufficient escorts - abort threshold %.0fs (%.1f km to target)", 
        self.Callsign, abortThreshold, distanceToTarget))
      
      -- Send initial warning
      if not self.InsufficientEscortWarning then
        self:_BroadcastMessage(string.format("%s: [!] Have only %d escort%s, need %d minimum! Requesting additional fighters immediately!", 
          self.Callsign, currentEscortCount, currentEscortCount > 1 and "s" or "", minRequired))
        self.InsufficientEscortWarning = true
      end
      
      -- If insufficient for too long, abort
      if unescortedTime >= abortThreshold then
        if not self:Is(BOMBER.States.ABORTING) and not self:Is(BOMBER.States.RTB) then
          BASE:I(string.format("%s: DECISION - ABORT MISSION (insufficient escorts for %.0fs, %.1f km to target)", 
            self.Callsign, unescortedTime, distanceToTarget))
          self:_BroadcastMessage(string.format("%s: [X] INSUFFICIENT ESCORT FOR %d SECONDS! MISSION ABORTED - RETURNING TO BASE!", 
            self.Callsign, math.floor(unescortedTime)))
          self:Abort()
        end
      end
      return
    end
    
  elseif currentEscortCount >= minRequired then
    -- Have enough now, clear the insufficient flag
    self.InsufficientEscortWarning = false
  end
  
  -- Don't send warnings/abort if already aborting or RTB (but keep monitor running for rejoin detection)
  if self:Is(BOMBER.States.ABORTING) or self:Is(BOMBER.States.RTB) then
    return
  end
  
  -- Don't enforce escort requirements during attack run - mission committed at this point
  if self:Is(BOMBER.States.ATTACKING) or self:Is(BOMBER.States.EGRESSING) then
    BASE:I(string.format("%s: Escort lost during %s - continuing mission (attack committed)", self.Callsign, self.CurrentState))
    return
  end
  
  BASE:I(string.format("%s: Lost escort - unescorted for %.0f seconds (had sufficient: %s)", 
    self.Callsign, unescortedTime, tostring(hadSufficientEscorts)))
  
  -- Calculate distance to target to determine urgency
  local distanceToTarget = 0
  local abortThreshold = 120  -- Default 2 minutes
  local warningThreshold = 30  -- Default 30 seconds
  local speedReductionThreshold = 60  -- Default 1 minute
  
  -- Track which warnings we've already sent to prevent spam
  if not self.EscortLossWarnings then
    self.EscortLossWarnings = {
      initialWarning = false,
      speedReduction = false,
    }
  end
  
  if self.BombingWaypoint and self.Group and self.Group:IsAlive() then
    local currentPos = self.Group:GetCoordinate()
    local targetPos = self.BombingWaypoint
    distanceToTarget = currentPos:Get2DDistance(targetPos) / 1000  -- Convert to km
    
    -- Scale thresholds based on distance to target
    -- Far from target (>100km): More lenient, escorts have time to catch up
    -- Near target (<30km): More urgent, abort quickly if no protection
    if distanceToTarget > 100 then
      warningThreshold = 60      -- 1 minute
      speedReductionThreshold = 180  -- 3 minutes
      abortThreshold = 300       -- 5 minutes
    elseif distanceToTarget > 50 then
      warningThreshold = 45      -- 45 seconds
      speedReductionThreshold = 120  -- 2 minutes
      abortThreshold = 240       -- 4 minutes
    elseif distanceToTarget > 30 then
      warningThreshold = 30      -- 30 seconds
      speedReductionThreshold = 90   -- 90 seconds
      abortThreshold = 180       -- 3 minutes
    else
      -- Close to target, need immediate protection
      warningThreshold = 20      -- 20 seconds
      speedReductionThreshold = 60   -- 1 minute
      abortThreshold = 120       -- 2 minutes
    end
    
    BASE:I(string.format("%s: Distance to target: %.1f km - Thresholds: warn=%ds, reduce=%ds, abort=%ds", 
      self.Callsign, distanceToTarget, warningThreshold, speedReductionThreshold, abortThreshold))
  end
  
  -- Progressive warnings based on thresholds (only send each message once)
  if unescortedTime < warningThreshold then
    -- LEVEL 1: Just lost escort, casual check-in (only once)
    if not self.EscortLossWarnings.initialWarning then
      local messages = BOMBER.EscortLossMessages.Level1
      local message = messages[math.random(#messages)]
      
      -- Add escort name if we had confirmed escorts
      if self.LastKnownEscorts and #self.LastKnownEscorts > 0 then
        local escortName = self.LastKnownEscorts[math.random(#self.LastKnownEscorts)]
        message = message .. " (" .. escortName .. "?)"
      end
      
      BASE:I(string.format("%s: LEVEL 1 - Casual escort check (recently lost escort)", self.Callsign))
      self:_BroadcastMessage(string.format("%s: %s", self.Callsign, message))
      self.EscortLossWarnings.initialWarning = true
    end
  elseif unescortedTime < speedReductionThreshold then
    -- LEVEL 2: Getting concerned - reduce speed and request help (only once)
    if not self.EscortLossWarnings.speedReduction then
      local messages = BOMBER.EscortLossMessages.Level2
      local message = messages[math.random(#messages)]
      
      -- Add escort name reference if we had confirmed escorts
      if self.LastKnownEscorts and #self.LastKnownEscorts > 0 then
        if #self.LastKnownEscorts == 1 then
          message = message .. " Lost " .. self.LastKnownEscorts[1] .. "!"
        else
          message = message .. " Lost " .. self.LastKnownEscorts[1] .. " and " .. self.LastKnownEscorts[2] .. "!"
        end
      end
      
      BASE:I(string.format("%s: LEVEL 2 - Concerned, requesting help (%.0fs unescorted, %.1f km to target)", 
        self.Callsign, unescortedTime, distanceToTarget))
      self:_BroadcastMessage(string.format("%s: %s", self.Callsign, message))
      
      -- Reduce speed (only if airborne)
      if self.Group and self.Group:IsAlive() then
        local reducedSpeed = self.Profile.CruiseSpeed * 0.7
        self.Group:SetSpeed(reducedSpeed * 0.514444) -- Convert knots to m/s
        BASE:I(string.format("%s: Speed reduced to %.0f knots", self.Callsign, reducedSpeed))
      else
        BASE:I(string.format("%s: Cannot reduce speed - not yet airborne", self.Callsign))
      end
      self.EscortLossWarnings.speedReduction = true
    end
  elseif unescortedTime >= abortThreshold then
    -- LEVEL 3: Critical - abort mission (state check prevents multiple aborts)
    if not self:Is(BOMBER.States.ABORTING) and not self:Is(BOMBER.States.RTB) then
      local messages = BOMBER.EscortLossMessages.Level3
      local message = messages[math.random(#messages)]
      -- Replace %d with unescorted time if present
      message = string.format(message, math.floor(unescortedTime))
      
      -- Add escort name list if we had confirmed escorts
      if self.LastKnownEscorts and #self.LastKnownEscorts > 0 then
        if #self.LastKnownEscorts == 1 then
          message = message .. " (Lost " .. self.LastKnownEscorts[1] .. ")"
        elseif #self.LastKnownEscorts == 2 then
          message = message .. " (Lost " .. self.LastKnownEscorts[1] .. " and " .. self.LastKnownEscorts[2] .. ")"
        else
          message = message .. " (Lost " .. table.concat(self.LastKnownEscorts, ", ", 1, 3) .. ")"
        end
      end
      
      BASE:I(string.format("%s: LEVEL 3 - CRITICAL ABORT (%.0fs unescorted exceeds %.0fs threshold, %.1f km to target)", 
        self.Callsign, unescortedTime, abortThreshold, distanceToTarget))
      self:_BroadcastMessage(string.format("%s: %s", self.Callsign, message))
      self:Abort()
    end
  end
end

--- Threat detected event
-- @param #BOMBER self
-- @param #table threatData Threat information
function BOMBER:OnThreatDetected(threatData)
  self.IsUnderThreat = true
  
  local bearing = math.floor(threatData.Bearing)
  local distance = math.floor(threatData.Distance / 1000) -- km
  local distanceNm = math.floor(threatData.Distance / 1852) -- nautical miles
  
  BASE:I(string.format("%s: THREAT DETECTED - %s at bearing %d°, distance %d km (%.1f NM)", 
    self.Callsign, threatData.Type, bearing, distance, distanceNm))
  
  self:_BroadcastMessage(string.format("%s: [!] %s THREAT DETECTED! Bearing %03d°, %d nm!", 
    self.Callsign, threatData.Type, bearing, distanceNm))
  
  -- React based on threat type and escort status with crew awareness
  if threatData.Type == BOMBER_THREAT_MANAGER.ThreatType.FIGHTER then
    -- Use contextual crew callout
    self:_CrewAwarenessCallout("threat_fighter")
    
    -- Get current escort count
    local escortCount = self.EscortMonitor and self.EscortMonitor.EscortCount or 0
    
    -- Count active fighter threats
    local fighterThreats = self.ThreatManager:GetActiveThreats(BOMBER_THREAT_MANAGER.ThreatType.FIGHTER)
    local fighterCount = 0
    for _ in pairs(fighterThreats) do
      fighterCount = fighterCount + 1
    end
    
    BASE:I(string.format("%s: Threat assessment - Fighters=%d, Escorts=%d, EscortRequired=%s, ThreatAssessment=%s", 
      self.Callsign, fighterCount, escortCount, 
      tostring(self.Profile.EscortRequired), tostring(BOMBER_ESCORT_CONFIG.EnableThreatAssessment)))
    
    -- Determine if we should abort based on threat-to-escort ratio
    local shouldAbort = false
    local abortReason = ""
    
    if BOMBER_ESCORT_CONFIG.EnableThreatAssessment then
      -- Dynamic threat assessment enabled
      if escortCount == 0 then
        -- No escorts - check tolerance without escort
        if fighterCount > BOMBER_ESCORT_CONFIG.ThreatToleranceWithoutEscort then
          shouldAbort = true
          abortReason = string.format("%d fighter%s detected with no escort (tolerance: %d)", 
            fighterCount, fighterCount > 1 and "s" or "", BOMBER_ESCORT_CONFIG.ThreatToleranceWithoutEscort)
        end
      else
        -- Have escorts - check if we meet parity requirements
        if BOMBER_ESCORT_CONFIG.RequireEscortParity then
          if fighterCount > escortCount then
            -- Outnumbered - abort
            shouldAbort = true
            abortReason = string.format("outnumbered %d vs %d (need escort parity)", fighterCount, escortCount)
          end
        else
          -- Parity not required - check absolute tolerance
          if fighterCount > BOMBER_ESCORT_CONFIG.ThreatToleranceWithEscort then
            shouldAbort = true
            abortReason = string.format("%d fighters exceeds tolerance (%d) even with %d escort%s", 
              fighterCount, BOMBER_ESCORT_CONFIG.ThreatToleranceWithEscort, 
              escortCount, escortCount > 1 and "s" or "")
          end
        end
      end
    else
      -- Legacy behavior - abort only if escort required and not present
      if self.Profile.EscortRequired and not self.HasEscort then
        shouldAbort = true
        abortReason = "no escort protection (legacy mode)"
      end
    end
    
    -- Apply abort decision with grace period timer
    local currentTime = timer.getTime()
    
    if shouldAbort and self.Profile.EscortRequired then
      -- Threat situation exists - manage abort timer
      if not self.ThreatAbortTimer then
        -- Start abort countdown
        self.ThreatAbortTimer = currentTime
        self.LastThreatReason = abortReason
        BASE:I(string.format("%s: THREAT ABORT COUNTDOWN STARTED: %s (grace period: %d seconds)", 
          self.Callsign, abortReason, BOMBER_ESCORT_CONFIG.ThreatAbortGracePeriod))
        self:_BroadcastMessage(string.format("%s: [!] THREAT ASSESSMENT: %s! Aborting in %d seconds unless escorts arrive!", 
          self.Callsign, abortReason:upper(), BOMBER_ESCORT_CONFIG.ThreatAbortGracePeriod))
        self.LastThreatWarning = currentTime
      else
        -- Timer already running - check if we should warn or abort
        local elapsedTime = currentTime - self.ThreatAbortTimer
        local remainingTime = BOMBER_ESCORT_CONFIG.ThreatAbortGracePeriod - elapsedTime
        
        -- Check if threat reason changed (e.g., more fighters appeared)
        if abortReason ~= self.LastThreatReason then
          BASE:I(string.format("%s: THREAT SITUATION CHANGED: %s (%.0fs remaining)", 
            self.Callsign, abortReason, remainingTime))
          self:_BroadcastMessage(string.format("%s: [!] THREAT ESCALATION: %s! %.0f seconds to abort!", 
            self.Callsign, abortReason:upper(), remainingTime))
          self.LastThreatReason = abortReason
          self.LastThreatWarning = currentTime
        end
        
        -- Periodic warnings during grace period
        if (currentTime - self.LastThreatWarning) >= BOMBER_ESCORT_CONFIG.ThreatWarningInterval then
          BASE:I(string.format("%s: THREAT ABORT WARNING: %s (%.0f seconds remaining)", 
            self.Callsign, abortReason, remainingTime))
          self:_BroadcastMessage(string.format("%s: [!] STILL OUTNUMBERED: %s! %.0f seconds until abort!", 
            self.Callsign, abortReason:upper(), remainingTime))
          self.LastThreatWarning = currentTime
        end
        
        -- Check if grace period expired
        if elapsedTime >= BOMBER_ESCORT_CONFIG.ThreatAbortGracePeriod then
          BASE:I(string.format("%s: DECISION - ABORT (grace period expired): %s", self.Callsign, abortReason))
          self:_BroadcastMessage(string.format("%s: [X] GRACE PERIOD EXPIRED: %s - ABORTING MISSION!", 
            self.Callsign, abortReason:upper()))
          self:__Abort(0)
        end
      end
    elseif not self.Profile.EscortRequired then
      -- Escort not required - clear any timer and continue
      if self.ThreatAbortTimer then
        self.ThreatAbortTimer = nil
        self.LastThreatReason = nil
      end
      BASE:I(string.format("%s: DECISION - Continue (escort not required for this bomber type)", self.Callsign))
      self:_BroadcastMessage(string.format("%s: [!] %d FIGHTER%s DETECTED! We'll handle this ourselves - continuing mission!", 
        self.Callsign, fighterCount, fighterCount > 1 and "S" or ""))
    else
      -- Threat situation resolved - cancel timer if it was running
      if self.ThreatAbortTimer then
        local elapsedTime = currentTime - self.ThreatAbortTimer
        BASE:I(string.format("%s: THREAT SITUATION RESOLVED after %.0f seconds - canceling abort timer", 
          self.Callsign, elapsedTime))
        self:_BroadcastMessage(string.format("%s: [OK] THREAT NEUTRALIZED! %d escort%s now on station - continuing mission!", 
          self.Callsign, escortCount, escortCount > 1 and "s" or ""))
        self.ThreatAbortTimer = nil
        self.LastThreatReason = nil
      end
      
      BASE:I(string.format("%s: DECISION - Continue (threat level acceptable: %d fighters vs %d escorts)", 
        self.Callsign, fighterCount, escortCount))
      if escortCount > 0 then
        self:_BroadcastMessage(string.format("%s: [!] %d fighter%s detected - %d escort%s on station. Continuing mission!", 
          self.Callsign, fighterCount, fighterCount > 1 and "s" or "", 
          escortCount, escortCount > 1 and "s" or ""))
      end
    end
  elseif threatData.Type == BOMBER_THREAT_MANAGER.ThreatType.SAM then
    -- Use contextual crew callout
    self:_CrewAwarenessCallout("threat_sam")
    
    -- Progressive range-based warnings
    self:_ProcessSAMRangeWarning(threatData)
    
    -- Check if we need to reroute around this SAM
    if BOMBER_ESCORT_CONFIG.EnableSAMAvoidance and self.SAMRouter then
      self:_CheckSAMReroute()
    end
    
    -- Auto-deploy countermeasures when close
    if threatData.Distance < (BOMBER_ESCORT_CONFIG.SAMAutoCountermeasureRange or 30000) then
      if not self.SAMCountermeasuresActive then
        self.SAMCountermeasuresActive = true
        BASE:I(string.format("%s: Auto-deploying countermeasures (SAM within %d km)", 
          self.Callsign, math.floor(threatData.Distance / 1000)))
      end
    end
  end
end

--- Process progressive SAM range warnings
-- @param #BOMBER self
-- @param #table threatData SAM threat information
function BOMBER:_ProcessSAMRangeWarning(threatData)
  local distance = threatData.Distance
  local distanceNm = math.floor(distance / 1852)
  local bearing = math.floor(threatData.Bearing)
  local threatId = threatData.Group:GetName()
  local samType = threatData.SAMType or "Unknown SAM"
  local threatLevel = threatData.ThreatLevel or "MEDIUM"
  local canEngage = threatData.CanEngage
  local bomberAlt = threatData.BomberAlt or 0
  
  -- Initialize SAM warning tracking
  if not self.SAMWarningRanges then
    self.SAMWarningRanges = {}
  end
  
  if not self.SAMWarningRanges[threatId] then
    self.SAMWarningRanges[threatId] = {}
  end
  
  -- Check each warning threshold (50km, 40km, 30km, 20km)
  local thresholds = BOMBER_ESCORT_CONFIG.SAMProgressiveWarnings or {50000, 40000, 30000, 20000}
  
  for _, threshold in ipairs(thresholds) do
    if distance <= threshold and not self.SAMWarningRanges[threatId][threshold] then
      -- New threshold crossed - issue warning
      self.SAMWarningRanges[threatId][threshold] = true
      
      local severity = ""
      local message = ""
      local engageStatus = canEngage and "CAN ENGAGE" or "outside envelope"
      
      if threshold >= 50000 then
        severity = "DETECTED"
        message = string.format("%s: [SAM] %s - %s bearing %03d°, %d nm", 
          self.Callsign, samType, severity, bearing, distanceNm)
      elseif threshold >= 40000 then
        severity = threatLevel
        if canEngage then
          message = string.format("%s: [SAM] %s (%s threat) bearing %03d°, %d nm - %s at %.0fft!", 
            self.Callsign, samType, severity, bearing, distanceNm, engageStatus, bomberAlt)
        else
          message = string.format("%s: [SAM] %s bearing %03d°, %d nm - %s", 
            self.Callsign, samType, bearing, distanceNm, engageStatus)
        end
      elseif threshold >= 30000 then
        if canEngage then
          message = string.format("%s: [SAM] %s (%s) bearing %03d°, %d nm - DANGER ZONE! Deploying countermeasures!", 
            self.Callsign, samType, threatLevel, bearing, distanceNm)
        else
          message = string.format("%s: [SAM] %s bearing %03d°, %d nm - close but %s at %.0fft", 
            self.Callsign, samType, bearing, distanceNm, engageStatus, bomberAlt)
        end
      else -- 20km or less
        if canEngage then
          message = string.format("%s: [!] %s (%s THREAT!) bearing %03d°, %d nm - TRACKING!", 
            self.Callsign, samType, threatLevel, bearing, distanceNm)
        else
          message = string.format("%s: %s bearing %03d°, %d nm - %s at %.0fft", 
            self.Callsign, samType, bearing, distanceNm, engageStatus, bomberAlt)
        end
      end
      
      self:_BroadcastMessage(message)
      BASE:I(string.format("%s: SAM progressive warning - %s (%s/%s) at %d m, can engage: %s", 
        self.Callsign, samType, threatLevel, engageStatus, math.floor(distance), tostring(canEngage)))
      
      -- Only warn once per threshold
      break
    end
  end
end

--- Update SAM status summary (called periodically)
-- @param #BOMBER self
function BOMBER:_UpdateSAMStatusSummary()
  if not self.ThreatManager then return end
  
  local samThreats = self.ThreatManager:GetActiveThreats(BOMBER_THREAT_MANAGER.ThreatType.SAM)
  local threatCount = 0
  for _ in pairs(samThreats) do
    threatCount = threatCount + 1
  end
  
  if threatCount == 0 then
    -- Clear countermeasures flag when no threats
    self.SAMCountermeasuresActive = false
    return
  end
  
  -- Find closest and most dangerous threats
  local closest = nil
  local closestDist = math.huge
  local mostDangerous = nil
  local highestThreat = 0
  
  -- Threat level to numeric value for comparison
  local threatValues = {CRITICAL = 4, HIGH = 3, MEDIUM = 2, LOW = 1, NONE = 0}
  
  for _, threat in pairs(samThreats) do
    if threat.Distance < closestDist then
      closestDist = threat.Distance
      closest = threat
    end
    
    -- Track most dangerous based on threat level and engagement capability
    local threatValue = threatValues[threat.ThreatLevel] or 0
    if threat.CanEngage then
      threatValue = threatValue + 1 -- Boost priority if can actually engage
    end
    
    if threatValue > highestThreat then
      highestThreat = threatValue
      mostDangerous = threat
    end
  end
  
  -- Build status message prioritizing actual threats
  local primaryThreat = mostDangerous or closest
  
  if threatCount == 1 and primaryThreat then
    local distanceNm = math.floor(primaryThreat.Distance / 1852)
    local bearing = math.floor(primaryThreat.Bearing)
    local samType = primaryThreat.SAMType or "Unknown SAM"
    local threatLevel = primaryThreat.ThreatLevel or "MEDIUM"
    local canEngage = primaryThreat.CanEngage
    local bomberAlt = primaryThreat.BomberAlt or 0
    
    if canEngage then
      self:_BroadcastMessage(string.format("%s: [SAM STATUS] %s (%s) - %03d° @ %d nm - CAN ENGAGE at %.0fft", 
        self.Callsign, samType, threatLevel, bearing, distanceNm, bomberAlt))
    else
      self:_BroadcastMessage(string.format("%s: [SAM STATUS] %s - %03d° @ %d nm (safe at %.0fft)", 
        self.Callsign, samType, bearing, distanceNm, bomberAlt))
    end
  elseif threatCount > 1 and primaryThreat then
    local closestNm = math.floor(closestDist / 1852)
    local closestBearing = math.floor(closest.Bearing)
    local primaryType = primaryThreat.SAMType or "Unknown"
    local canEngage = primaryThreat.CanEngage
    
    -- Count how many can actually engage
    local engageCount = 0
    for _, threat in pairs(samThreats) do
      if threat.CanEngage then
        engageCount = engageCount + 1
      end
    end
    
    if engageCount > 0 then
      self:_BroadcastMessage(string.format("%s: [SAM STATUS] %d sites (%d CAN ENGAGE) - Priority: %s @ %03d°", 
        self.Callsign, threatCount, engageCount, primaryType, closestBearing))
    else
      self:_BroadcastMessage(string.format("%s: [SAM STATUS] %d sites detected - closest: %03d° @ %d nm (all outside envelope)", 
        self.Callsign, threatCount, closestBearing, closestNm))
    end
  end
end

--- Check if SAM reroute is needed and execute if necessary
-- @param #BOMBER self
function BOMBER:_CheckSAMReroute()
  if not self.SAMRouter or not self.ThreatManager then
    return
  end
  
  -- Don't reroute if already RTB or aborting
  if self:Is(BOMBER.States.RTB) or self:Is(BOMBER.States.ABORTING) then
    return
  end
  
  -- Throttle checks to avoid excessive recalculation
  local currentTime = timer.getTime()
  local checkInterval = BOMBER_ESCORT_CONFIG.SAMRerouteCheckInterval or 15
  if (currentTime - (self.SAMRouter.LastRouteCheck or 0)) < checkInterval then
    return
  end
  self.SAMRouter.LastRouteCheck = currentTime
  
  -- Get current position and next target
  if not self.Group or not self.Group:IsAlive() then
    return
  end
  
  local currentCoord = self.Group:GetCoordinate()
  if not currentCoord then
    return
  end
  
  -- Determine target coordinate based on current state
  local targetCoord = nil
  
  if self:Is(BOMBER.States.FLYING) then
    -- En route to target - check path to target
    if self.TargetCoord then
      targetCoord = self.TargetCoord
    end
  elseif self:Is(BOMBER.States.ATTACKING) then
    -- Already attacking, let it complete
    return
  end
  
  if not targetCoord then
    -- No target to route to
    return
  end
  
  -- Get active SAM threats
  local samThreats = self.ThreatManager:GetActiveThreats(BOMBER_THREAT_MANAGER.ThreatType.SAM)
  
  if not samThreats or not next(samThreats) then
    -- No SAM threats, clear route
    return
  end
  
  -- Analyze route for SAM threats
  local analysis = self.SAMRouter:AnalyzeRoute(currentCoord, targetCoord, samThreats)
  
  BASE:I(string.format("%s: Route analysis - Safe: %s, Threats on route: %d, Corridors found: %d", 
    self.Callsign, tostring(analysis.isSafe), #analysis.threats, #analysis.corridors))
  
  if analysis.isSafe and #analysis.threats == 0 then
    -- Current route is safe
    return
  end
  
  -- Route is threatened - evaluate recommendation
  local rec = analysis.recommendation
  
  if rec.action == "REROUTE" then
    -- Apply the new route
    BASE:I(string.format("%s: Applying SAM avoidance reroute - %s", self.Callsign, rec.message))
    self:_BroadcastMessage(string.format("%s: [REROUTE] %s", self.Callsign, rec.message))
    
    -- Apply the detour route
    self:_ApplySAMDetourRoute(rec.route, targetCoord)
    
  elseif rec.action == "ABORT" then
    -- Must abort mission
    BASE:I(string.format("%s: SAM avoidance abort required - %s", self.Callsign, rec.message))
    self:_BroadcastMessage(string.format("%s: [ABORT] %s", self.Callsign, rec.message))
    
    -- Abort the mission
    self:__Abort(2)
  end
end

--- Apply SAM detour route to current flight plan
-- @param #BOMBER self
-- @param #table corridor Corridor data with waypoints
-- @param #COORDINATE finalTarget Final target coordinate
function BOMBER:_ApplySAMDetourRoute(corridor, finalTarget)
  if not corridor or not corridor.waypoints or #corridor.waypoints == 0 then
    BASE:E(string.format("%s: Invalid corridor data for reroute", self.Callsign))
    return
  end
  
  if not self.Group or not self.Group:IsAlive() then
    return
  end
  
  -- Build new route with detour waypoints
  local cruiseAlt = self.Profile.CruiseAlt
  local cruiseSpeed = self.Profile.CruiseSpeed
  local cruiseAltMeters = cruiseAlt * 0.3048
  local cruiseSpeedMPS = cruiseSpeed * 0.514444
  
  local waypoints = {}
  
  -- Add current position as waypoint 1
  local currentCoord = self.Group:GetCoordinate()
  table.insert(waypoints, currentCoord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
  
  -- Add corridor waypoints
  for _, wpCoord in ipairs(corridor.waypoints) do
    local coord = wpCoord:SetAltitude(cruiseAltMeters)
    table.insert(waypoints, coord:WaypointAirTurningPoint(nil, cruiseSpeedMPS))
  end
  
  -- Add final target
  local targetWP = finalTarget:SetAltitude(cruiseAltMeters):WaypointAirTurningPoint(nil, cruiseSpeedMPS)
  table.insert(waypoints, targetWP)
  
  -- Apply the new route
  self.Group:Route(waypoints)
  
  BASE:I(string.format("%s: Applied detour route with %d waypoints", self.Callsign, #waypoints))
  
  -- Track that we've rerouted
  table.insert(self.SAMRouter.RouteHistory, {
    time = timer.getTime(),
    reason = "SAM avoidance",
    detour = corridor.detourDistance,
    waypoints = #waypoints
  })
end

--- Threat cleared event
-- @param #BOMBER self
-- @param #table threatData Threat information
function BOMBER:OnThreatCleared(threatData)
  -- Clear SAM warning ranges for this specific threat
  if threatData.Type == BOMBER_THREAT_MANAGER.ThreatType.SAM then
    local threatId = threatData.Group:GetName()
    if self.SAMWarningRanges and self.SAMWarningRanges[threatId] then
      self.SAMWarningRanges[threatId] = nil
    end
  end
  
  BASE:I(string.format("%s: Threat cleared - %s", self.Callsign, threatData.Type))
  
  -- Check if any threats remain
  local remainingThreats = self.ThreatManager:GetActiveThreats()
  local count = 0
  for _ in pairs(remainingThreats) do count = count + 1 end
  
  BASE:I(string.format("%s: Remaining threats: %d", self.Callsign, count))
  
  if count == 0 then
    self.IsUnderThreat = false
    BASE:I(string.format("%s: DECISION - All threats cleared, resuming normal operations", self.Callsign))
    self:_BroadcastMessage(string.format("%s: [OK] All threats clear. Continuing mission.", self.Callsign))
  else
    self:_BroadcastMessage(string.format("%s: One threat cleared. %d threat%s still active.", 
      self.Callsign, count, count > 1 and "s" or ""))
  end
end

--- Broadcast message to coalition
-- @param #BOMBER self
-- @param #string message The message text
function BOMBER:_BroadcastMessage(message)
  BASE:I(string.format("%s: _BroadcastMessage called with: %s (Coalition: %d)", 
    self.Callsign, message, self.Coalition or -1))
  
  -- Use MOOSE MESSAGE for better visibility
  MESSAGE:New(message, 15):ToCoalition(self.Coalition)
  
  BASE:I(string.format("%s: Message sent to coalition %d", self.Callsign, self.Coalition or -1))
end

--- Handle holding timeout - abort mission and cleanup
-- @param #BOMBER self
function BOMBER:_HandleHoldingTimeout()
  local waitTime = math.floor((timer.getTime() - self.HoldingStartTime) / 60)
  
  BASE:I(string.format("%s: Holding timeout - waited %d minutes for escort", self.Callsign, waitTime))
  
  -- Send dejected message
  self:_BroadcastMessage(string.format("%s: We've been waiting on the ramp for %d minutes... No escort showed up. Mission scrubbed. Standing down.", 
    self.Callsign, waitTime))
  
  -- Stop the holding check scheduler
  if self.HoldingCheck then
    self.HoldingCheck:Stop()
    self.HoldingCheck = nil
  end
  
  -- Cleanup escort roster
  self.EscortRoster = {}
  self.WaitingForEscortDeparture = nil
  
  -- Mark mission as completed (failed)
  self.MissionCompleted = true
  self.AbortRequested = true
  
  -- Despawn the bomber group
  if self.Group and self.Group:IsAlive() then
    BASE:I(string.format("%s: Despawning bomber group due to holding timeout", self.Callsign))
    self.Group:Destroy()
  end
  
  -- Transition to DESTROYED state for proper cleanup
  self:__Destroyed(0)
end

--- FSM State: Holding (waiting for escort on ground)
-- @param #BOMBER self
function BOMBER:onenterHolding()
  BASE:I(string.format("%s: STATE CHANGE - HOLDING (waiting for escort)", self.Callsign))
  
  -- Track when we started holding
  self.HoldingStartTime = timer.getTime()
  self.LastHoldingAnnounce = self.HoldingStartTime
  
  local maxWaitMins = math.floor(self.MaxHoldingTime / 60)
  local airbaseName = self.StartAirbase or "departure point"
  self:_BroadcastMessage(string.format("%s: [AC] On ramp at %s, engines running. Waiting for fighter escort within 1km (%d min max).", 
    self.Callsign, airbaseName, maxWaitMins))
  
  -- Start checking for ground escorts every 10 seconds
  self.HoldingCheck = SCHEDULER:New(nil, function()
    if not self:IsAlive() or not self:Is(BOMBER.States.HOLDING) then
      return
    end
    
    local currentTime = timer.getTime()
    
    -- Check for holding timeout (15 minutes)
    if self.HoldingStartTime and (currentTime - self.HoldingStartTime) > self.MaxHoldingTime then
      BASE:I(string.format("%s: Holding timeout reached (%.0f seconds) - aborting mission", 
        self.Callsign, currentTime - self.HoldingStartTime))
      self:_HandleHoldingTimeout()
      return
    end
    
    local escortsFound = self:_ScanForGroundEscorts()
    
    if escortsFound and #escortsFound > 0 then
      if not self.WaitingForEscortDeparture then
        -- First detection - add escorts to roster and announce
        local escortNames = {}
        for _, escort in ipairs(escortsFound) do
          table.insert(escortNames, escort.callsign)
          self:_AddToEscortRoster(escort.callsign, escort.unit)
        end
        
        local escortList = table.concat(escortNames, ", ")
        BASE:I(string.format("%s: Ground escorts detected: %s - waiting for them to taxi/take off", self.Callsign, escortList))
        self:_BroadcastMessage(string.format("%s: [OK] Escort detected: %s. Waiting for escort to begin taxi...", 
          self.Callsign, escortList))
        
        self.WaitingForEscortDeparture = true
      else
        -- Check if any escorts are moving (taxiing or airborne)
        local anyEscortMoving = false
        for _, escort in ipairs(escortsFound) do
          local velocity = escort.unit:GetVelocityKNOTS()
          if velocity > 10 then  -- Moving/taxiing
            anyEscortMoving = true
            break
          end
        end
        
        if anyEscortMoving then
          -- Escort is following! Begin engine start sequence
          BASE:I(string.format("%s: Escort is taxiing - beginning engine start", self.Callsign))
          
          -- Stop holding check
          if self.HoldingCheck then
            self.HoldingCheck:Stop()
            self.HoldingCheck = nil
          end
          
          -- Start engines (broadcasts "Starting Engines" message)
          self:_StartRoute()
          
          -- Monitor for actual movement before transitioning FSM
          -- Bomber needs ~6 minutes to complete cold & dark startup
          self:_MonitorEngineStart()
        end
      end
    else
      -- No escorts found - announce periodically (every 2 minutes)
      if currentTime - self.LastHoldingAnnounce >= 120 then
        local waitedTime = currentTime - self.HoldingStartTime
        local remainingTime = self.MaxHoldingTime - waitedTime
        local waitedMins = math.floor(waitedTime / 60)
        local remainingMins = math.ceil(remainingTime / 60)
        
        BASE:I(string.format("%s: Still holding for escort at %s (waited %d min, %d min remaining)", 
          self.Callsign, airbaseName, waitedMins, remainingMins))
        self:_BroadcastMessage(string.format("%s: Still waiting for fighter escort at %s. Waited %d min - %d min remaining before mission scrub.", 
          self.Callsign, airbaseName, waitedMins, remainingMins))
        self.LastHoldingAnnounce = currentTime
      end
      self.WaitingForEscortDeparture = false  -- Reset flag if escorts left
    end
    
  end, {}, 5, 10)  -- Check after 5 seconds, then every 10 seconds
end

--- Scan for fighter escorts on the ground within 1km with engines running
-- @param #BOMBER self
-- @return #table Array of escort data {unit, callsign, distance}
function BOMBER:_ScanForGroundEscorts()
  if not self.Group then return {} end
  
  local bomberCoord = self.Group:GetCoordinate()
  if not bomberCoord then return {} end
  
  local escorts = {}
  local GROUND_ESCORT_RANGE = 1000  -- meters
  
  -- Scan for coalition fighters
  local scanSet = SET_UNIT:New()
    :FilterCoalitions(self.Coalition)
    :FilterCategories("plane")
    :FilterOnce()
  
  BASE:I(string.format("%s: Scanning for ground escorts within %.0f meters...", self.Callsign, GROUND_ESCORT_RANGE))
  
  scanSet:ForEachUnit(function(unit)
    if unit:IsPlayer() and unit:IsAlive() then
      local unitType = unit:GetTypeName()
      
      -- Check if it's a fighter (use existing escort monitor logic)
      local isFighter = self:_IsFighterType(unitType)
      
      if isFighter then
        local unitCoord = unit:GetCoordinate()
        if unitCoord then
          local distance = bomberCoord:Get2DDistance(unitCoord)
          local altitude = unit:GetAltitude()
          local velocity = unit:GetVelocityKNOTS()
          
          -- Must be: within 1km, on ground (alt < 50m), engines running (velocity > 0 or just alive)
          local onGround = altitude < 50
          local enginesRunning = velocity >= 0  -- If alive and on ground, engines are running
          
          if distance <= GROUND_ESCORT_RANGE and onGround then
            local callsign = unit:GetCallsign() or unit:GetName()
            table.insert(escorts, {
              unit = unit,
              callsign = callsign,
              distance = distance
            })
            BASE:I(string.format("%s: Found ground escort: %s (%s) at %.0fm, alt=%.0fm, vel=%.0fkts", 
              self.Callsign, callsign, unitType, distance, altitude, velocity))
          else
            BASE:I(string.format("%s: Fighter %s not eligible - dist=%.0fm (max 1000m), alt=%.0fm (max 50m), onGround=%s", 
              self.Callsign, unit:GetCallsign() or unit:GetName(), distance, altitude, tostring(onGround)))
          end
        end
      end
    end
  end)
  
  BASE:I(string.format("%s: Ground escort scan complete - found %d eligible fighters", self.Callsign, #escorts))
  return escorts
end

--- Check if aircraft type is a fighter (not bomber, attacker, or helicopter)
-- @param #BOMBER self
-- @param #string typeName Aircraft type name
-- @return #boolean True if fighter type
function BOMBER:_IsFighterType(typeName)
  if not typeName then return false end
  
  -- Exclude bomber types
  local bomberTypes = {
    ["B-1B"] = true,
    ["B-52H"] = true,
    ["Tu-95MS"] = true,
    ["Tu-160"] = true,
    ["Tu-22M3"] = true,
    ["B-17G"] = true,
    ["B-24"] = true,
  }
  
  -- Exclude attacker/ground attack types
  local attackerTypes = {
    ["A-10A"] = true,
    ["A-10C"] = true,
    ["A-10C_2"] = true,
    ["Su-25"] = true,
    ["Su-25T"] = true,
    ["Su-25TM"] = true,
  }
  
  if bomberTypes[typeName] or attackerTypes[typeName] then
    return false
  end
  
  return true
end

--- FSM State: Enroute
-- @param #BOMBER self
function BOMBER:onenterEnroute()
  BASE:I(string.format("%s: STATE CHANGE - ENROUTE (flying to target)", self.Callsign))
  
  -- Start escort monitoring now that we're actually flying
  if self.EscortMonitor and not self.EscortMonitor.SchedulerID then
    BASE:I(string.format("%s: Starting escort monitoring", self.Callsign))
    self.EscortMonitor:Start()
  end
  
  -- Build spawn location string
  local spawnLocation = "unknown location"
  if self.StartAirbase then
    spawnLocation = self.StartAirbase
  elseif self.Group then
    local currentPos = self.Group:GetCoordinate()
    if currentPos then
      spawnLocation = currentPos:ToStringLLDMS()
    end
  end
  
  -- Wait to announce until aircraft are actually airborne
  SCHEDULER:New(nil, function()
    if self:IsAlive() then
      -- Check if actually in the air
      local velocity = self.Group:GetVelocityKNOTS()
      local altitude = self.Group:GetAltitude()
      
      -- Determine message based on escort requirement
      local escortMsg = self.Profile.EscortRequired and " - provide escort." or " - proceeding independently."
      
      -- If moving and above ground, they're airborne
      if velocity > 50 and altitude > 100 then
        self:_BroadcastMessage(string.format("%s: Flight of %d %s airborne from %s. Enroute to target%s", 
          self.Callsign, self.FlightSize, self.Profile.DisplayName, spawnLocation, escortMsg))
      else
        -- Still on ground, check again in 30 seconds
        SCHEDULER:New(nil, function()
          -- Check if in any active flight state (not SPAWNED, HOLDING, or terminal states)
          local inFlight = self:IsAlive() and (
            self:Is(BOMBER.States.ENGINE_STARTING) or
            self:Is(BOMBER.States.TAXIING) or
            self:Is(BOMBER.States.TAKING_OFF) or
            self:Is(BOMBER.States.CLIMBING) or
            self:Is(BOMBER.States.CRUISE) or
            self:Is(BOMBER.States.PRE_ATTACK) or
            self:Is(BOMBER.States.ATTACKING)
          )
          
          if inFlight then
            local vel = self.Group:GetVelocityKNOTS()
            -- Only send message if actually moving (taxiing or airborne)
            if vel > 5 then
              self:_BroadcastMessage(string.format("%s: Flight of %d %s departing %s. Enroute to target%s", 
                self.Callsign, self.FlightSize, self.Profile.DisplayName, spawnLocation, escortMsg))
            end
          end
        end, {}, 30)
      end
    end
  end, {}, 15) -- Wait 15 seconds after entering ENROUTE state before checking
end

--- FSM State: Engine Starting
-- @param #BOMBER self
function BOMBER:onenterEngineStarting()
  BASE:I(string.format("%s: STATE CHANGE - ENGINE_STARTING (cold start in progress)", self.Callsign))
  local targetName = self.TargetName or "target"
  self:_BroadcastMessage(string.format("%s: Starting engines. Mission brief: %s, routing via climb-optimized waypoints.", 
    self.Callsign, targetName))
  
  -- Mark engine start time for monitoring
  self.EngineStartTime = timer.getTime()
end

--- FSM State: Taxiing
-- @param #BOMBER self
function BOMBER:onenterTaxiing()
  BASE:I(string.format("%s: STATE CHANGE - TAXIING (moving to runway)", self.Callsign))
  local cruiseAlt = self.CruiseAlt or (self.Profile and self.Profile.CruiseAlt) or 20000
  self:_BroadcastMessage(string.format("%s: Taxiing to runway. Route planned for safe altitude management to %d ft.", 
    self.Callsign, cruiseAlt))
end

--- FSM State: Blocked
-- @param #BOMBER self
function BOMBER:onenterBlocked(From)
  -- Store which state we came from for reference
  self.PreBlockedState = From or "Unknown"
  
  BASE:I(string.format("%s: STATE CHANGE - BLOCKED (obstructed on taxiway, was in %s)", self.Callsign, self.PreBlockedState))
  self:_BroadcastMessage(string.format("%s: [!] Aircraft blocked on taxiway - waiting for clearance...", self.Callsign))
  
  -- Track when we entered BLOCKED state for periodic updates
  self.BlockedStartTime = timer.getTime()
  self.LastBlockedUpdate = self.BlockedStartTime
  
  -- Start periodic blocked status updates (every 60 seconds)
  self.BlockedStatusScheduler = SCHEDULER:New(nil, function()
    if not self:Is(BOMBER.States.BLOCKED) then
      -- No longer blocked, stop scheduler
      if self.BlockedStatusScheduler then
        self.BlockedStatusScheduler:Stop()
        self.BlockedStatusScheduler = nil
      end
      return
    end
    
    local currentTime = timer.getTime()
    local blockedDuration = currentTime - self.BlockedStartTime
    local blockedMins = math.floor(blockedDuration / 60)
    local remainingTime = 300 - blockedDuration  -- 5 minutes total before scrub
    local remainingSecs = math.max(0, math.floor(remainingTime))
    
    self:_BroadcastMessage(string.format("%s: Still blocked on taxiway (%d min elapsed, %d sec until mission scrub)", 
      self.Callsign, blockedMins, remainingSecs))
    BASE:I(string.format("%s: BLOCKED status update - %.0f seconds elapsed", self.Callsign, blockedDuration))
    
  end, {}, 60, 60)  -- First update after 60s, then every 60s
end

--- FSM State: Leaving Blocked (cleanup)
-- @param #BOMBER self
function BOMBER:onleaveBlocked()
  -- Stop the blocked status scheduler when leaving BLOCKED state
  if self.BlockedStatusScheduler then
    BASE:I(string.format("%s: Stopping blocked status updates (leaving BLOCKED state)", self.Callsign))
    self.BlockedStatusScheduler:Stop()
    self.BlockedStatusScheduler = nil
  end
  self.BlockedStartTime = nil
  self.LastBlockedUpdate = nil
end

--- FSM State: Taking Off
-- @param #BOMBER self
function BOMBER:onenterTakingOff()
  BASE:I(string.format("%s: STATE CHANGE - TAKING_OFF (takeoff roll)", self.Callsign))
  local cruiseAlt = self.CruiseAlt or (self.Profile and self.Profile.CruiseAlt) or 20000
  self:_BroadcastMessage(string.format("%s: Rolling. Route optimized for climb profile - we'll turn direct to target once at %d ft. Stay close!", 
    self.Callsign, cruiseAlt))
end

--- FSM State: Climbing
-- @param #BOMBER self
function BOMBER:onenterClimbing()
  local cruiseAlt = self.CruiseAlt or (self.Profile and self.Profile.CruiseAlt) or 20000
  BASE:I(string.format("%s: STATE CHANGE - CLIMBING (climbing to %d ft)", self.Callsign, cruiseAlt))
  self:_BroadcastMessage(string.format("%s: Climbing to %d ft via staged waypoints. Direct target routing once at altitude.", 
    self.Callsign, cruiseAlt))
end

--- FSM State: Cruise
-- @param #BOMBER self
function BOMBER:onenterCruise()
  local cruiseAlt = self.CruiseAlt or (self.Profile and self.Profile.CruiseAlt) or 20000
  BASE:I(string.format("%s: STATE CHANGE - CRUISE (at %d ft, en route to target)", self.Callsign, cruiseAlt))
  self:_BroadcastMessage(string.format("%s: At cruise altitude, en route to target", self.Callsign))
end

--- FSM State: Pre-Attack
-- @param #BOMBER self
function BOMBER:onenterPreAttack()
  BASE:I(string.format("%s: STATE CHANGE - PRE_ATTACK (approaching target)", self.Callsign))
  self:_BroadcastMessage(string.format("%s: Approaching target - preparing for attack", self.Callsign))
  
  -- Release escorts - bomber is committed to attack, no longer needs escort protection
  if self.EscortMonitor then
    BASE:I(string.format("%s: Releasing escorts - committed to attack run, making 1st pass, dropping on 2nd...here we go!", self.Callsign))
    self.EscortMonitor:Stop()
    self.EscortMonitor = nil
    
    -- Thank escorts for their service
    SCHEDULER:New(nil, function()
      if self:IsAlive() then
        self:_BroadcastMessage(string.format("%s: Escorts released - thanks for the cover! We've got it from here.", self.Callsign))
      end
    end, {}, 2) -- Announce 2 seconds after PRE_ATTACK message
  end
end

--- FSM State: Attacking (at target)
-- @param #BOMBER self
function BOMBER:onenterAttacking()
  BASE:I(string.format("%s: STATE CHANGE - ATTACKING (beginning bombing run)", self.Callsign))
  
  -- Reset attack tracking flags for this run
  self.WeaponsReleased = false
  self.WeaponsReleaseStartTime = nil
  self.ImpactAnnounced = false
  self.IPRunCount = 0
  self.LastIPRunTime = timer.getTime()
  
  -- Announce attack initiation
  local attackMessages = {
    "%s: [MAP] IP reached! Commencing attack run - preparing weapons!",
    "%s: [MAP] On target approach! Bombardier, you have control!",
    "%s: [MAP] Target acquired! Beginning bombing run!",
    "%s: [MAP] We're at the IP! Starting attack sequence!",
    "%s: [MAP] Target in sight! Attack run initiated!",
    "%s: [MAP] Attack position! Beginning weapon employment!"
  }
  local attackMsg = attackMessages[math.random(#attackMessages)]
  self:_BroadcastMessage(string.format(attackMsg, self.Callsign))
  
  -- Start monitoring IP runs to inform players during setup passes
  if self.IPRunMonitor then
    self.IPRunMonitor:Stop()
  end
  
  self.IPRunMonitor = SCHEDULER:New(nil, function()
    if not self:IsAlive() or not self:Is(BOMBER.States.ATTACKING) then
      return
    end
    
    -- If still in ATTACKING state but no weapons released yet, we're doing IP runs
    if not self.WeaponsReleased then
      local currentTime = timer.getTime()
      local timeSinceLastAnnounce = currentTime - self.LastIPRunTime
      
      -- Announce IP run status every 45 seconds
      if timeSinceLastAnnounce >= 45 then
        self.IPRunCount = self.IPRunCount + 1
        self.LastIPRunTime = currentTime
        
        local ipMessages = {
            "%s: First pass complete - setting up attack geometry for weapon release, we're still in it..",
            "%s: Initial pass complete - calculating bombing solution for second pass.",
            "%s: Repositioning for attack run - weapon release on next pass.",
            "%s: Attack geometry being refined - release pass inbound.",
            "%s: First pass complete - adjusting approach parameters for weapons employment.",
            "%s: Bombardier refining solution - second pass will be hot.",
            "%s: Repositioning for optimal release parameters - standby.",
            "%s: Attack run setup in progress - weapon release next pass.",
            "%s: Calculating final bombing solution - release pass momentarily.",
            "%s: First pass complete - aligning for precision weapon employment.",
            "%s: Adjusting attack geometry - second pass will be weapons hot.",
            "%s: Bombardier calculating release parameters - coming around.",
            "%s: Initial approach complete - setting up for weapon release.",
            "%s: Refining attack solution - hot pass inbound.",
            "%s: First pass complete - optimizing release geometry for next pass.",
            "%s: Repositioning for weapons employment - release on next pass.",
            "%s: Attack parameters being calculated - standby for weapon release on next pass.",
            "%s: Setup pass complete - bombardier has the solution for next pass.",
            "%s: Coming around for release pass - attack geometry confirmed.",
            "%s: Calculating wind and speed corrections - weapon release next pass.",
            "%s: First pass complete - aligning for accurate weapon employment.",
            "%s: Bombardier refining parameters - hot pass momentarily.",
            "%s: Attack solution being finalized - release pass inbound.",
            "%s: Repositioning for optimal bombing geometry - standby.",
            "%s: Setup pass complete - second pass will be weapons release.",
            "%s: Adjusting for wind and target motion - release pass coming up.",
            "%s: Initial geometry established - fine-tuning for weapon employment.",
            "%s: Bombardier calculating final solution - hot pass inbound.",
            "%s: First pass complete - setting up precision release parameters.",
            "%s: Coming around for weapons employment - attack geometry set.",
            "%s: Refining bombing solution - release on second pass.",
            "%s: Setup complete - repositioning for weapon release.",
            "%s: Attack parameters confirmed - hot pass momentarily.",
            "%s: First pass complete - calculating optimal release point.",
            "%s: Bombardier has preliminary solution - refining for next pass.",
            "%s: Repositioning for weapon employment - standby for release.",
            "%s: Attack geometry being optimized - second pass will be hot.",
            "%s: Setup pass complete - aligning for precision bombing.",
            "%s: Calculating release parameters - weapon employment next pass.",
            "%s: First pass complete - coming around for weapons hot.",
            "%s: Bombardier refining attack solution - release pass inbound.",
            "%s: Initial approach complete - setting up for accurate employment.",
            "%s: Adjusting bombing geometry - hot pass momentarily.",
            "%s: Setup complete - weapon release on next pass.",
            "%s: Coming around for precision attack - release parameters set.",
            "%s: First pass complete - bombardier finalizing solution.",
            "%s: Repositioning for optimal weapon employment - standby.",
            "%s: Attack geometry confirmed - hot pass inbound.",
            "%s: Calculating final release parameters - second pass ready.",
            "%s: Too much drift — this isn't a Battlestar Viper moment. This next pass will be the magic moment!",
            "%s: Bombardier has the target solution - weapon release next pass.",
            "%s: Enabling attack computers... this next pass will be the one!",
            "%s: Setup pass complete - weapons employment next approach.",
            "%s: Setup pass done - coming around for weapon release. Even Mo could navigate this one.",
            "%s: First pass complete - calculating release parameters for next pass. Unlike Mo, we'll actually hit something.",
            "%s: Repositioning for attack run - second pass will be hot. Mo would've gotten lost by now.",
            "%s: Attack geometry being refined - weapon release on next pass. Mo's still trying to find the target on his map.",
            "%s: Initial pass complete - setting up for weapons employment. If Mo can't hit it in his F-4, at least we can.",
            "%s: Bombardier calculating solution - hot pass inbound. Mo's probably still looking at the wrong waypoint.",
            "%s: Coming around for release pass - next pass drops ordnance. Mo's navigation skills not required here.",
            "%s: Setup complete - weapon release next pass. Even with Mo's aim, you can't miss from a bomber.",
            "%s: First pass complete - refining attack geometry for second pass. Mo would've bombed the wrong coordinates.",
            "%s: Repositioning for precision attack - release on next pass. Mo's F-4 is probably out of gas by now anyway.",
            "%s: Setup pass complete - calculating for weapon release next pass. Taking our time, unlike Mo Jenkins.",
            "%s: First pass done - coming around for hot pass. No need to Jenkins our way straight into trouble.",
            "%s: Attack geometry being refined - weapon release on next approach. We're not pulling a Mo Jenkins here.",
            "%s: Repositioning for second pass - this time with weapons hot. Mo Jenkins would've charged in guns blazing already.",
            "%s: Initial pass complete - bombardier finalizing solution for next pass. Patience, Mo Jenkins would've gotten us all killed by now.",
            "%s: Coming around for release pass - second pass will be the money shot. Unlike Mo Jenkins, we actually plan our attacks.",
            "%s: Setup complete - weapon employment next pass. At least we're not Mo Jenkins-ing headlong into SAMs.",
            "%s: First pass complete - refining parameters for weapons release. Mo Jenkins would've blown past the IP already.",
            "%s: Bombardier calculating final solution - hot pass inbound. Methodical approach beats Mo Jenkins-style chaos every time.",
            "%s: Repositioning for precision attack - release on next pass. Mo Jenkins probably already triggered every defense in the area."
        }
        
        local msg = ipMessages[math.random(#ipMessages)]
        self:_BroadcastMessage(string.format(msg, self.Callsign))
        BASE:I(string.format("%s: IP setup pass %d - awaiting proper attack geometry", self.Callsign, self.IPRunCount))
        
        -- Sanity check: if we've been in ATTACKING state for 10+ minutes without releasing, something is wrong
        if self.IPRunCount >= 120 then -- 120 * 5 seconds = 600 seconds = 10 minutes
          BASE:E(string.format("%s: CRITICAL - Stuck in ATTACKING state for 10+ minutes without weapon release!", self.Callsign))
          self:_BroadcastMessage(string.format("%s: [EMERGENCY] Attack run timeout - aborting to egress!", self.Callsign))
          -- Force transition to egressing to prevent infinite loop
          self:__WeaponsReleased(0.1)
        end
      end
    end
  end, {}, 5, 5) -- Check every 5 seconds
  
  -- ROE is already WEAPONS FREE from spawn - bombing tasks in waypoints should execute automatically
  -- DO NOT override with SetTask as it loses the route geometry and attack heading
  BASE:I(string.format("%s: At target waypoint - letting embedded bombing task execute", self.Callsign))
  
  -- Get current target info for logging
  if self.Targets and #self.Targets > 0 and self.CurrentTargetIndex <= #self.Targets then
    local targetData = self.Targets[self.CurrentTargetIndex]
    local targetCoord = targetData.coordinate
    local isRunwayTarget = targetData.targetParams and targetData.targetParams.attackType == "RUNWAY"
    
    BASE:I(string.format("%s: Target type: %s at %s", 
      self.Callsign, 
      isRunwayTarget and "RUNWAY CARPET BOMB" or "POINT TARGET",
      targetCoord:ToStringLLDMS()))
      
    if isRunwayTarget then
      local attackHeading = targetData.targetParams.heading or 0
      BASE:I(string.format("%s: Runway attack heading: %.0f°", self.Callsign, attackHeading))
    end
  else
    BASE:E(string.format("%s: No target data available!", self.Callsign))
  end
  
  -- Announce task setup (this is confirmed, the weapon release will be event-driven)
  SCHEDULER:New(nil, function()
    if self:IsAlive() and self:Is(BOMBER.States.ATTACKING) and not self.WeaponsReleased then
      local prepMessages = {
        "%s: Bomb doors opening - attack computers active!",
        "%s: Weapons armed - bombardier has the target!",
        "%s: Target locked - holding formation for release!",
        "%s: Attack computers engaged - steady on target!",
        "%s: Weapons system active - preparing for release!"
      }
      local prepMsg = prepMessages[math.random(#prepMessages)]
      self:_BroadcastMessage(string.format(prepMsg, self.Callsign))
    end
  end, {}, 3) -- Announce 3 seconds after reaching target
end

--- FSM State: Egressing (bombs away)
-- @param #BOMBER self
function BOMBER:onenterEgressing()
  BASE:I(string.format("%s: STATE CHANGE - EGRESSING (leaving target area)", self.Callsign))
  
  -- Stop IP run monitoring
  if self.IPRunMonitor then
    self.IPRunMonitor:Stop()
    self.IPRunMonitor = nil
  end
  
  -- Delay egress announcement to let weapon release complete
  SCHEDULER:New(nil, function()
    if not self:IsAlive() then return end
    
    -- Only announce egress if weapons were actually released
    if self.WeaponsReleased then
      local egressMessages = {
        "%s: Winchester - egressing target area!",
        "%s: Ordnance expended - breaking off target!",
        "%s: Bombs away - moving to egress!",
        "%s: Target run complete - weapons released!"
      }
      local msg = egressMessages[math.random(#egressMessages)]
      self:_BroadcastMessage(string.format(msg, self.Callsign))
    else
      -- Weapons weren't released - continuing with ordnance
      BASE:I(string.format("%s: Egressing with ordnance still available", self.Callsign))
      self:_BroadcastMessage(string.format("%s: Egressing target area - ordnance available for opportunistic targets", self.Callsign))
    end
    
    -- Keep ROE at WEAPONS FREE in case there are multiple targets or defensive needs
    BASE:I(string.format("%s: Continuing with ROE=WEAPONS FREE", self.Callsign))
    
    -- Notify mission of completion (after announcement)
    if self.MissionData and self.MissionData.Mission then
      BASE:I(string.format("%s: Notifying mission manager of SUCCESS", self.Callsign))
      self.MissionData.Mission:Complete(true)
    end
  end, {}, 2) -- Wait 2 seconds after entering egress state before announcing
end

--- FSM State: Aborting
-- @param #BOMBER self
function BOMBER:onenterAborting()
  BASE:I(string.format("%s: STATE CHANGE - ABORTING (mission abort in progress)", self.Callsign))
  self:_BroadcastMessage(string.format("%s: [X] ABORTING MISSION! Returning to base immediately!", self.Callsign))
  self:_DisableEscortResume("mission abort in progress")
  
  -- Escort monitor stays active for situational awareness only (no mission resume)
  -- Stop waypoint monitoring - no longer tracking the bombing route
  if self.WaypointMonitor then
    self.WaypointMonitor:Stop()
    self.WaypointMonitor = nil
  end
  
  -- Clear mission route tracking since we're aborting
  self.Route = nil
  self.BombingWaypointIndex = nil
  self.CurrentWaypointIndex = 0
  
  -- Cancel current route and head home
  BASE:I(string.format("%s: Issuing RTB command", self.Callsign))
  
  -- Route back to original spawn airbase (or nearest if spawn airbase unknown)
  local rtbAirbase = nil
  if self.StartAirbase then
    rtbAirbase = AIRBASE:FindByName(self.StartAirbase)
    if rtbAirbase then
      BASE:I(string.format("%s: RTB to spawn airbase: %s (coalition %d)", 
        self.Callsign, self.StartAirbase, rtbAirbase:GetCoalition()))
    else
      BASE:E(string.format("%s: Spawn airbase '%s' not found, finding nearest", self.Callsign, self.StartAirbase))
    end
  else
    BASE:I(string.format("%s: No spawn airbase stored, finding nearest", self.Callsign))
  end
  
  -- Fallback to nearest airbase if spawn airbase not available
  if not rtbAirbase then
    local currentPos = self.Group:GetCoordinate()
    rtbAirbase = currentPos:GetClosestAirbase(nil, Airbase.Category.AIRDROME)
    if rtbAirbase then
      BASE:I(string.format("%s: RTB to nearest airbase: %s (coalition %d, distance %.1f km)", 
        self.Callsign, rtbAirbase:GetName(), rtbAirbase:GetCoalition(), currentPos:Get2DDistance(rtbAirbase:GetCoordinate()) / 1000))
    else
      BASE:E(string.format("%s: ERROR - No airbase found for RTB!", self.Callsign))
    end
  end
  
  if rtbAirbase then
    BASE:I(string.format("%s: Commanding land at %s", self.Callsign, rtbAirbase:GetName()))

    local group = self.Group
    if not group or not group:IsAlive() then
      BASE:E(string.format("%s: ERROR - Bomber group not available for RTB command", self.Callsign))
    else
        group:RouteStop()
        group:ClearTasks()
        BASE:I(string.format("%s: Cleared active tasks prior to RTB routing", self.Callsign))
      local rtbCoord = rtbAirbase:GetCoordinate()
      local currentCoord = group:GetCoordinate()
      local currentSpeed = group:GetVelocityKNOTS() or 0
      local fallbackSpeed = self.CruiseSpeed or (self.Profile and self.Profile.CruiseSpeed) or BOMBER_ESCORT_CONFIG.DefaultSpeed or 300
      local desiredSpeed = currentSpeed > 10 and currentSpeed or fallbackSpeed
      local approachSpeed = math.max(desiredSpeed * 0.7, 150)
      local cruiseSpeedMPS = desiredSpeed * 0.514444
      local landingSpeedMPS = approachSpeed * 0.514444
      local fieldAltitude = rtbCoord:GetLandHeight() or 0

      BASE:I(string.format("%s: RTB routing speed %.0f kts (landing %.0f kts)", self.Callsign, desiredSpeed, approachSpeed))

      local route = {}
      local approachLegs = 0

      local function dumpControllerRouteSnapshot(controller)
        if not controller then
          BASE:E(string.format("%s: Unable to dump controller mission - controller missing", self.Callsign))
          return
        end

        local missionTask, taskErr = self:_GetControllerMissionTask(controller)
        if not missionTask then
          BASE:E(string.format("%s: Unable to read controller mission task - %s", self.Callsign, taskErr or "unknown error"))
          return
        end

        local routePoints = missionTask.params and missionTask.params.route and missionTask.params.route.points
        if not routePoints or #routePoints == 0 then
          BASE:E(string.format("%s: Controller mission has no route points (task id: %s)", self.Callsign, tostring(missionTask.id)))
          return
        end

        BASE:I(string.format("%s: Controller mission snapshot - %d point(s), task id %s", self.Callsign, #routePoints, tostring(missionTask.id)))
        for idx, point in ipairs(routePoints) do
          local coordDesc = "(missing coordinates)"
          if point.x and point.y then
            local wpCoord = COORDINATE:New(point.x, point.alt or 0, point.y)
            coordDesc = wpCoord:ToStringLLDMS()
          end
          local altitudeFeet = point.alt and ((UTILS and UTILS.MetersToFeet and UTILS.MetersToFeet(point.alt)) or (point.alt * 3.28084)) or 0
          local speedKnots = point.speed and (point.speed / 0.514444) or 0
          local action = point.action or point.type or "UNKNOWN"
          BASE:I(string.format("%s: CTRL WP %d -> %s | alt %.0fft | spd %.0fkts | action %s", self.Callsign, idx, coordDesc, altitudeFeet, speedKnots, action))
        end
      end

      local function setWaypointSpeed(waypoint, targetSpeedMPS)
        if not waypoint or not targetSpeedMPS then return end
        waypoint.speed = targetSpeedMPS
        waypoint.speed_locked = true
        waypoint.speedEdited = true
        if waypoint.task and waypoint.task.params then
          waypoint.task.params.speed = targetSpeedMPS
          waypoint.task.params.speed_locked = true
          waypoint.task.params.speedEdited = true
        end
      end

      if currentCoord then
        local distanceToBase = currentCoord:Get2DDistance(rtbCoord)

        local function normalizeDegrees(value)
          value = value % 360
          if value < 0 then value = value + 360 end
          return value
        end

        local function diffDegrees(a, b)
          local diff = math.abs(a - b) % 360
          if diff > 180 then diff = 360 - diff end
          return diff
        end

        local headingToBase = 0
        if currentCoord and rtbCoord then
          headingToBase = currentCoord:HeadingTo(rtbCoord)
        end

        local landingHeading = headingToBase
        local approachSource = "inbound vector"
        local runways = rtbAirbase.GetRunways and rtbAirbase:GetRunways() or nil
        if runways and #runways > 0 then
          local bestDiff = 361
          for _, runway in ipairs(runways) do
            if runway.course then
              local course = runway.course
              if math.abs(course) <= (math.pi * 2 + 0.001) then
                course = math.deg(course)
              end
              local primary = normalizeDegrees(course)
              local secondary = normalizeDegrees(course + 180)
              for _, candidate in ipairs({primary, secondary}) do
                local diff = diffDegrees(candidate, headingToBase)
                if diff < bestDiff then
                  bestDiff = diff
                  landingHeading = candidate
                  approachSource = runway.name and string.format("runway %s", runway.name) or "runway data"
                end
              end
            end
          end
        end

        local approachHeading = normalizeDegrees(landingHeading + 180)
        local currentAltitude = currentCoord.y or fieldAltitude + 1000

        local function metersFromNM(nm)
          if UTILS and UTILS.NMToMeters then
            return UTILS.NMToMeters(nm)
          end
          return nm * 1852
        end

        local function buildApproachLeg(offsetMeters, targetAltMeters, speedMPS, label)
          local legCoord = rtbCoord:Translate(offsetMeters, approachHeading)
          legCoord:SetAltitude(targetAltMeters, false)  -- Use BARO/MSL for smooth altitude transitions
          local waypoint = legCoord:WaypointAirTurningPoint(nil, speedMPS)
          setWaypointSpeed(waypoint, speedMPS)
          table.insert(route, waypoint)
          approachLegs = approachLegs + 1
          BASE:I(string.format("%s: Added %s approach fix %.1f km out (alt %.0fft MSL)",
            self.Callsign,
            label,
            offsetMeters / 1000,
            UTILS.MetersToFeet and UTILS.MetersToFeet(targetAltMeters) or (targetAltMeters * 3.28084)))
        end

        local distanceKm = distanceToBase and (distanceToBase / 1000) or 0
        BASE:I(string.format("%s: RTB geometry - distance %.1f km, inbound heading %.0f°, landing heading %.0f° via %s", 
          self.Callsign, distanceKm, headingToBase, landingHeading, approachSource))

        local anchorSpeed = math.max(cruiseSpeedMPS, landingSpeedMPS)
        local anchorWP = currentCoord:WaypointAirTurningPoint(nil, anchorSpeed)
        setWaypointSpeed(anchorWP, anchorSpeed)
        table.insert(route, anchorWP)
        BASE:I(string.format("%s: Added anchor waypoint at current position", self.Callsign))

        if distanceToBase and distanceToBase > metersFromNM(10) then
          local farLeg = math.min(math.max(distanceToBase - metersFromNM(6), metersFromNM(20)), metersFromNM(60))
          farLeg = math.min(farLeg, distanceToBase - metersFromNM(8))
          if farLeg > metersFromNM(8) then
            local farAltitude = math.max(fieldAltitude + UTILS.FeetToMeters(12000), math.min(currentAltitude, fieldAltitude + UTILS.FeetToMeters(28000)))
            buildApproachLeg(farLeg, farAltitude, cruiseSpeedMPS, "initial")
          end
        end

        if distanceToBase and distanceToBase > metersFromNM(6) then
          local nearLeg = math.min(math.max(distanceToBase - metersFromNM(2.5), metersFromNM(8)), metersFromNM(20))
          nearLeg = math.min(nearLeg, distanceToBase - metersFromNM(2))
          if nearLeg > metersFromNM(3) then
            local nearAltitude = fieldAltitude + UTILS.FeetToMeters(3000)
            buildApproachLeg(nearLeg, nearAltitude, math.min(cruiseSpeedMPS, landingSpeedMPS * 1.3), "final")
          end
        end

        if distanceToBase and distanceToBase > metersFromNM(4.5) then
          local shortLeg = math.min(math.max(distanceToBase - metersFromNM(1.5), metersFromNM(3)), metersFromNM(5))
          shortLeg = math.min(shortLeg, distanceToBase - metersFromNM(1))
          if shortLeg > metersFromNM(2.5) then
            local shortAltitude = fieldAltitude + UTILS.FeetToMeters(1500)
            local shortSpeed = math.max(landingSpeedMPS * 0.85, landingSpeedMPS - 15, 80 * 0.514444)
            buildApproachLeg(shortLeg, shortAltitude, shortSpeed, "short-final")
          end
        end

        if approachLegs == 0 then
          BASE:I(string.format("%s: No space for extended approach, proceeding direct from anchor", self.Callsign))
        end
      else
        BASE:E(string.format("%s: WARN - Unable to capture current coordinate for RTB route", self.Callsign))
      end

      local landingTasks = { group:TaskLandAtVec2(rtbCoord:GetVec2()) }
      local landingWP = self:_BuildLandingWaypoint(rtbAirbase, rtbCoord, landingSpeedMPS, landingTasks, fieldAltitude)
      if landingWP then
        setWaypointSpeed(landingWP, landingSpeedMPS)
        table.insert(route, landingWP)
      else
        BASE:E(string.format("%s: Failed to append landing waypoint to RTB route", self.Callsign))
      end

      self.RTBRoute = route
      self.Route = route
      self.RTBAirbase = rtbAirbase
      self.RTBLandingTask = landingTasks and landingTasks[1] or nil
      self.RTBLandingFallbackIssued = false
      self.RTBLandingStuckSeconds = 0

      if #route > 0 then
        group:Route(route, 1)
        BASE:I(string.format("%s: RTB route programmed with %d waypoint(s) (%d approach + landing)", self.Callsign, #route, approachLegs))
        for idx, wp in ipairs(route) do
          if wp.x and wp.y then
            local wpCoord = COORDINATE:New(wp.x, wp.alt or 0, wp.y)
            local wpAltFeet = UTILS and UTILS.MetersToFeet and UTILS.MetersToFeet(wp.alt or 0) or ((wp.alt or 0) * 3.28084)
            BASE:I(string.format("%s: RTB WP %d at %s (alt %.0fft, speed %.0f kts)",
              self.Callsign,
              idx,
              wpCoord:ToStringLLDMS(),
              wpAltFeet,
              (wp.speed or cruiseSpeedMPS) / 0.514444))
          end
        end
        local snapshotRetryDelay = 2
        local maxSnapshotAttempts = 3

        local function attemptControllerSnapshot(attempt)
          if not group then
            BASE:E(string.format("%s: Cannot dump controller route snapshot - group reference lost", self.Callsign))
            return
          end

          local controller, controllerErr = self:_GetActiveController()

          if controller then
            dumpControllerRouteSnapshot(controller)
            return
          end

          local errMsg = controllerErr or "controller unavailable"
          if attempt >= maxSnapshotAttempts then
            BASE:E(string.format("%s: Skipping controller route snapshot after %d failed attempt(s) (%s)", self.Callsign, attempt, errMsg))
            return
          end

          BASE:E(string.format("%s: Controller snapshot attempt %d failed (%s) - retrying in %d seconds", self.Callsign, attempt, errMsg, snapshotRetryDelay))
          SCHEDULER:New(nil, function()
            attemptControllerSnapshot(attempt + 1)
          end, {}, snapshotRetryDelay)
        end

        attemptControllerSnapshot(1)
        self:_StartRTBMonitor()
      else
        BASE:E(string.format("%s: ERROR - No RTB route points generated", self.Callsign))
      end
    end
  else
    BASE:E(string.format("%s: CRITICAL - Cannot RTB without airbase!", self.Callsign))
  end
  
  -- Transition to RTB state
  BASE:I(string.format("%s: Triggering ReturnToBase state transition in 2 seconds", self.Callsign))
  self:__ReturnToBase(2)
  
  -- Mark mission as failed, but don't complete it yet - wait until landed
  self.MissionFailed = true
end

--- FSM State: RTB
-- @param #BOMBER self
function BOMBER:onenterRTB()
  BASE:I(string.format("%s: STATE CHANGE - RTB (returning to base)", self.Callsign))
  self:_BroadcastMessage(string.format("%s: RTB - escort appreciated until landing.", self.Callsign))
  
  -- Start landing detection monitor
  self:_MonitorLanding()
  
  -- Keep escort monitor running so escorts can provide cover (resume only if not locked)
end

--- FSM State: Landed
-- @param #BOMBER self
function BOMBER:onenterLanded()
  BASE:I(string.format("%s: STATE CHANGE - LANDED (mission terminated)", self.Callsign))
  self:_CancelLandingFailureDespawn("landed state")
  
  -- Check if mission was aborted or successful
  local successMessage = ""
  if self.MissionFailed then
    successMessage = "[X] Landed safely after mission abort."
  else
    successMessage = "[OK] Landed safely. Mission complete - thanks for the escort!"
  end
  
  self:_BroadcastMessage(string.format("%s: %s", self.Callsign, successMessage))
  
  -- Stop monitors immediately when landed
  if self.LandingMonitor then
    BASE:I(string.format("%s: Stopping landing monitor", self.Callsign))
    self.LandingMonitor:Stop()
    self.LandingMonitor = nil
  end

  if self.RTBMonitor then
    BASE:I(string.format("%s: Stopping RTB monitor", self.Callsign))
    self.RTBMonitor:Stop()
    self.RTBMonitor = nil
  end
  
  if self.EscortMonitor then
    BASE:I(string.format("%s: Stopping escort monitor", self.Callsign))
    self.EscortMonitor:Stop()
    self.EscortMonitor = nil
  end
  
  if self.WaypointMonitor then
    self.WaypointMonitor:Stop()
    self.WaypointMonitor = nil
  end
  
  -- Now complete the mission after landing
  if self.MissionData and self.MissionData.Mission then
    local missionSuccess = not self.MissionFailed
    BASE:I(string.format("%s: Notifying mission manager - %s", self.Callsign, missionSuccess and "SUCCESS" or "FAILURE"))
    self.MissionData.Mission:Complete(missionSuccess)
  end
  
  -- Clean up after delay
  SCHEDULER:New(nil, function()
    self:Destroy()
  end, {}, 60)
end

--- Scrub mission due to failure (stuck, timeout, etc) and cleanup all resources
-- @param #BOMBER self
-- @param #string reason Reason for scrubbing
function BOMBER:_ScrubMission(reason)
  BASE:E(string.format("%s: Mission scrubbed - %s", self.Callsign, reason))
  self:_CancelLandingFailureDespawn("scrub mission")
  
  -- Stop all monitors
  if self.HoldingCheck then
    self.HoldingCheck:Stop()
    self.HoldingCheck = nil
  end
  
  if self.EngineStartMonitor then
    self.EngineStartMonitor:Stop()
    self.EngineStartMonitor = nil
  end
  
  if self.LandingMonitor then
    self.LandingMonitor:Stop()
    self.LandingMonitor = nil
  end

  if self.RTBMonitor then
    self.RTBMonitor:Stop()
    self.RTBMonitor = nil
  end
  
  if self.WaypointMonitor then
    self.WaypointMonitor:Stop()
    self.WaypointMonitor = nil
  end
  
  if self.EscortMonitor then
    self.EscortMonitor:Stop()
    self.EscortMonitor = nil
  end
  
  if self.ThreatManager then
    self.ThreatManager:Stop()
    self.ThreatManager = nil
  end
  
  -- Clear escort roster
  if self.EscortRoster then
    self.EscortRoster = {}
  end
  
  -- Broadcast final message
  self:_BroadcastMessage(string.format("%s: [X] MISSION SCRUBBED - %s", self.Callsign, reason))
  
  -- Clean up airbase if we're scrubbing due to blockage
  if reason and string.find(reason:lower(), "block") and self.StartAirbase then
    BASE:I(string.format("%s: Running airbase cleanup at %s to remove obstructions", self.Callsign, self.StartAirbase))
    
    -- Create temporary cleanup for this airbase
    local cleanup = CLEANUP_AIRBASE:New(self.StartAirbase)
    
    -- Force immediate cleanup pass
    if cleanup and cleanup.__ and cleanup.__.CleanUpSchedule then
      cleanup.__.CleanUpSchedule(cleanup.__)
    end
    
    self:_BroadcastMessage(string.format("%s: Airbase cleanup complete - obstructions removed", self.Callsign))
  end
  
  -- Despawn the bomber group
  if self.Group and self.Group:IsAlive() then
    BASE:I(string.format("%s: Despawning bomber group", self.Callsign))
    self.Group:Destroy()
  end
  
  -- Transition to DESTROYED state
  if not self:Is(BOMBER.States.DESTROYED) then
    self:__Destroy(0)
  end
  
  -- Notify mission manager to clean up mission record
  if _BOMBER_MISSION_MANAGER then
    _BOMBER_MISSION_MANAGER:UnregisterMission(self)
  end
end

--- Clean up bomber mission
-- @param #BOMBER self
function BOMBER:Destroy()
  -- Stop holding check if active
  self:_CancelLandingFailureDespawn("destroy")
  if self.HoldingCheck then
    self.HoldingCheck:Stop()
    self.HoldingCheck = nil
  end
  
  if self.EngineStartMonitor then
    self.EngineStartMonitor:Stop()
    self.EngineStartMonitor = nil
  end
  
  if self.LandingMonitor then
    self.LandingMonitor:Stop()
    self.LandingMonitor = nil
  end
  
  if self.RTBMonitor then
    self.RTBMonitor:Stop()
    self.RTBMonitor = nil
  end

  if self.WaypointMonitor then
    self.WaypointMonitor:Stop()
    self.WaypointMonitor = nil
  end
  
  if self.EscortMonitor then
    self.EscortMonitor:Stop()
    self.EscortMonitor = nil
  end
  
  if self.ThreatManager then
    self.ThreatManager:Stop()
    self.ThreatManager = nil
  end
  
  -- Clear escort roster to free memory
  if self.EscortRoster then
    self.EscortRoster = {}
  end
  
  self:_BroadcastMessage(string.format("%s: Mission terminated.", self.Callsign))
  
  -- Trigger FSM destroy state
  if not self:Is(BOMBER.States.DESTROYED) then
    self:__Destroy(0)
  end
end

---
-- Initialize the bomber escort system
-- @param #table options Configuration options
function BOMBER_ESCORT_INIT(options)
  options = options or {}
  
  BASE:I("==============================================")
  BASE:I("MOOSE BOMBER ESCORT SYSTEM INITIALIZING")
  BASE:I("==============================================")
  
  -- Create global marker parser
  _BOMBER_MARKER_SYSTEM = BOMBER_MARKER:New()
  
  -- Create global mission manager (creates F10 menus)
  if not _BOMBER_MISSION_MANAGER then
    _BOMBER_MISSION_MANAGER = BOMBER_MISSION_MANAGER:New()
    BASE:I("Bomber Mission Manager: ACTIVE")
    BASE:I("F10 Menus Created:")
    BASE:I("  - Launch Bomber Mission (submit markers)")
    BASE:I("  - Respawn Last Mission")
    BASE:I("  - Mission Status (shows active bombers)")
    BASE:I("  - Quick Start Guide (player help)")
  end
  
  BASE:I("Bomber Marker System: ACTIVE (On-Demand)")
  BASE:I("Available Bomber Types:")
  local types = BOMBER_PROFILE:ListTypes()
  for _, bomberType in ipairs(types) do
    BASE:I("  - " .. bomberType)
  end
  BASE:I("==============================================")
  BASE:I("HOW TO USE:")
  BASE:I("1. Place F10 map markers to plan your route")
  BASE:I("2. Use F10 -> Bomber Missions -> Launch Mission")
  BASE:I("3. System validates markers and spawns bomber")
  BASE:I("==============================================")
  BASE:I("Required Markers:")
  BASE:I("  BOMBER1:[Type]:[Size]:FL[Alt]:[Speed]")
  BASE:I("  TARGET1:[AttackType]:[Heading]")
  BASE:I("")
  BASE:I("Optional Markers:")
  BASE:I("  BOMBER2-n (route waypoints)")
  BASE:I("  TARGET2-n (additional targets)")
  BASE:I("  EGRESS1-n (egress waypoints)")
  BASE:I("  RTB1 (return to base point)")
  BASE:I("")
  BASE:I("Quick Examples:")
  BASE:I("  BOMBER1:B-52H")
  BASE:I("  TARGET1")
  BASE:I("")
  BASE:I("  BOMBER1:B-17G:6:FL200:180")
  BASE:I("  TARGET1:RUNWAY:270")
  BASE:I("==============================================")
  BASE:I("F10 Menu Workflow:")
  BASE:I("  1. Place markers at your own pace")
  BASE:I("  2. F10 -> Bomber Missions -> Launch Mission")
  BASE:I("  3. System validates and reports any issues")
  BASE:I("  4. Fix markers if needed, retry Launch")
  BASE:I("  5. Mission spawns when all checks pass")
  BASE:I("")
  BASE:I("After mission complete/failed:")
  BASE:I("  F10 -> Bomber Missions -> Respawn Last Mission")
  BASE:I("==============================================")
  BASE:I("Formations: Automatic based on bomber type")
  BASE:I("  WWII: Box formation (tight)")
  BASE:I("  Modern: Line Abreast (loose)")
  BASE:I("==============================================")
  BASE:I("Template Groups Required:")
  for _, bomberType in ipairs(types) do
    local profile = BOMBER_PROFILE:Get(bomberType)
    local templateName = string.gsub(bomberType, "[-]", "")
    templateName = string.gsub(templateName, "MS", "")
    BASE:I(string.format("  BOMBER_%s for %s", string.upper(templateName), bomberType))
  end
  BASE:I("  (Set Late Activation in mission editor)")
  BASE:I("==============================================")
  BASE:I("Features:")
  BASE:I("  [OK] On-demand marker submission (no auto-spam)")
  BASE:I("  [OK] Numbered waypoint system (BOMBER1, TARGET1)")
  BASE:I("  [OK] Auto-detect spawn airbase from marker")
  BASE:I("  [OK] Multiple targets in sequence")
  BASE:I("  [OK] Runway carpet bombing (auto or manual heading)")
  BASE:I("  [OK] Custom egress routes (EGRESS1-n, RTB1)")
  BASE:I("  [OK] F10 mission control and validation")
  BASE:I("  [OK] Formation management")
  BASE:I("  [OK] Mission respawn system")
  BASE:I("==============================================")
  BASE:I("For complete documentation, see MARKER_GUIDE.md")
  BASE:I("==============================================")

  
  return _BOMBER_MARKER_SYSTEM
end

-- Auto-initialize if running directly
if not BOMBER_ESCORT_NO_AUTO_INIT then
  BOMBER_ESCORT_INIT()
end
