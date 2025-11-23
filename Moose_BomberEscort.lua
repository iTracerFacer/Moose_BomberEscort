--- MOOSE Bomber Escort System
-- A comprehensive player-escort AI bomber mission system
-- Players use F10 map markers to create bomber missions, then escort them to targets
-- Bombers exhibit intelligent behavior based on escort presence and threats
--
-- @module BOMBER_ESCORT
-- @author F99th-TracerFacer
-- @copyright 2025

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
    HasDefensiveGuns = true,
    FormationTight = true, -- Prefers tight formations
    EvasionCapability = "Low", -- Poor, Low, Medium, High
    EscortRequired = true,
    MinEscorts = 2,
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
    HasDefensiveGuns = true,
    FormationTight = true,
    EvasionCapability = "Low",
    EscortRequired = true,
    MinEscorts = 2,
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
    HasDefensiveGuns = false,
    FormationTight = false,
    EvasionCapability = "Low",
    EscortRequired = true,
    MinEscorts = 2,
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
    HasDefensiveGuns = true,
    FormationTight = false,
    EvasionCapability = "Low",
    EscortRequired = true,
    MinEscorts = 2,
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
    HasDefensiveGuns = false,
    FormationTight = false,
    EvasionCapability = "Medium",
    EscortRequired = true,
    MinEscorts = 2,
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
    HasDefensiveGuns = false,
    FormationTight = false,
    EvasionCapability = "High",
    EscortRequired = false, -- Can operate independently
    MinEscorts = 0,
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
  deleteMarkersAfterUse = true,     -- Auto-cleanup markers after mission spawn
  minWaypoints = 1,                 -- Minimum waypoints (BOMBER1 is required)
  maxWaypoints = 10,                -- Maximum route waypoints
  checkInterval = 2,                -- Seconds between marker scans
}

--- Create new marker parser
-- @param #BOMBER_MARKER self
-- @return #BOMBER_MARKER
function BOMBER_MARKER:New()
  local self = BASE:Inherit(self, BASE:New())
  
  self.LastMissionData = {} -- Store last mission for respawn
  self.LastMissionData[coalition.side.BLUE] = nil
  self.LastMissionData[coalition.side.RED] = nil
  
  -- Start monitoring for markers
  self:ScheduleRepeat(1, self.Config.checkInterval, nil, self._CheckMarkers, self)
  
  return self
end

--- Parse waypoint marker text for mission parameters
-- Format: BOMBER1:[Type]:[Airbase]:[Size]:FL[Alt]:[Speed]
-- Example: BOMBER1:B-52:Nellis:4:FL250:350
-- @param #BOMBER_MARKER self
-- @param #string markerText The text from the map marker
-- @param #number defaultAlt Default altitude if not specified (feet)
-- @param #number defaultSpeed Default speed if not specified (knots)
-- @return #table Parsed parameters: {type, airbase, size, altitude, speed, originalText}
function BOMBER_MARKER:_ParseWaypointMarker(markerText, defaultAlt, defaultSpeed)
  local result = {
    type = nil,
    airbase = nil,
    size = 2,
    altitude = defaultAlt or 25000,
    speed = defaultSpeed or 350,
    originalText = markerText
  }
  
  -- Split by colon delimiter
  local parts = {}
  for part in string.gmatch(markerText, "[^:]+") do
    table.insert(parts, part)
  end
  
  -- Parse each part (skip first part which is BOMBER1, BOMBER2, etc.)
  if #parts >= 2 then result.type = parts[2] end
  if #parts >= 3 then result.airbase = parts[3] end
  if #parts >= 4 then result.size = tonumber(parts[4]) or 2 end
  if #parts >= 5 then
    -- Parse FL format or raw number
    local altStr = string.upper(parts[5])
    local flNum = string.match(altStr, "FL(%d+)")
    if flNum then
      result.altitude = tonumber(flNum) * 100
    else
      result.altitude = tonumber(parts[5]) or defaultAlt
    end
  end
  if #parts >= 6 then result.speed = tonumber(parts[6]) or defaultSpeed end
  
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
            coalition = marker.coalition or coalition.side.BLUE
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
  
  -- Scan for respawn markers
  local respawnWaypoints, respawnMarkerIds = self:_ScanForWaypointMarkers(self.Config.respawnPrefix)
  
  -- Process respawn requests (RESPAWN1)
  if #respawnWaypoints > 0 then
    for _, respawnMarker in ipairs(respawnWaypoints) do
      local coalitionSide = respawnMarker.coalition
      self:_RespawnLastMission(coalitionSide)
      
      -- Cleanup respawn marker
      if self.Config.deleteMarkersAfterUse then
        trigger.action.removeMark(respawnMarker.markerId)
      end
    end
  end
  
  -- Check if we have minimum required markers for mission execution
  -- Need at least BOMBER1 and TARGET1
  if #bomberWaypoints > 0 and #targetWaypoints > 0 then
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
    
    -- Execute missions for each coalition that has complete marker set
    for coalitionSide, missionData in pairs(missionsByCoalition) do
      if #missionData.bomberWaypoints > 0 and #missionData.targetWaypoints > 0 then
        self:_ExecuteMissionFromMarkers(coalitionSide, missionData)
      end
    end
  end
end

--- Execute a bomber mission from detected markers
-- @param #BOMBER_MARKER self
-- @param #number coalitionSide The coalition side
-- @param #table missionData Table containing bomberWaypoints, targetWaypoints, allMarkerIds
function BOMBER_MARKER:_ExecuteMissionFromMarkers(coalitionSide, missionData)
  local bomberWaypoints = missionData.bomberWaypoints
  local targetWaypoints = missionData.targetWaypoints
  
  -- Parse BOMBER1 marker for mission parameters
  local firstWp = bomberWaypoints[1]
  local params = self:_ParseWaypointMarker(firstWp.markerText)
  
  -- Validate bomber type
  local bomberType = params.type or "B-52H"
  if not BOMBER_PROFILE:Get(bomberType) then
    self:_SendMessage(coalitionSide, string.format(
      "INVALID BOMBER TYPE: %s\nAvailable types: %s", 
      bomberType, 
      table.concat(BOMBER_PROFILE:ListTypes(), ", ")
    ))
    return
  end
  
  -- Get profile for defaults
  local profile = BOMBER_PROFILE:Get(bomberType)
  
  -- Validate flight size
  local flightSize = params.size or 2
  if flightSize < 1 or flightSize > 6 then
    self:_SendMessage(coalitionSide, "INVALID FLIGHT SIZE: Must be 1-6 aircraft")
    return
  end
  
  -- Build mission data structure
  local missionDataStruct = {
    Coalition = coalitionSide,
    StartAirbase = params.airbase,
    StartPos = firstWp.coordinate,
    TargetName = targetWaypoints[1].markerText,
    TargetPos = targetWaypoints[1].coordinate,
    BomberType = bomberType,
    FlightSize = flightSize,
    CruiseAlt = params.altitude,
    CruiseSpeed = params.speed,
    RouteWaypoints = {},
  }
  
  -- Collect additional route waypoints (BOMBER2, BOMBER3, etc.)
  for i = 2, #bomberWaypoints do
    table.insert(missionDataStruct.RouteWaypoints, {
      coordinate = bomberWaypoints[i].coordinate,
      sequence = bomberWaypoints[i].sequence
    })
  end
  
  -- Spawn the bomber mission
  local success, mission = self:_SpawnBomberMission(missionDataStruct)
  
  if success then
    self:_SendMessage(coalitionSide, string.format(
      "BOMBER MISSION ACTIVE\nCallsign: %s\nType: %s x%d\nTarget: %s\nProvide escort immediately!",
      mission.Callsign or "Unknown",
      missionDataStruct.BomberType,
      missionDataStruct.FlightSize,
      missionDataStruct.TargetName or "Coordinates"
    ))
    
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
  trigger.action.outTextForCoalition(coalitionSide, "BOMBER CONTROL: " .. message, 15)
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
  self.LastEscortTime = timer.getTime()
  self.UnescortedDuration = 0
  
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
  
  scanSet:ForEachUnit(function(unit)
    -- Check if player controlled
    if unit:IsPlayer() and unit:IsAlive() then
      local unitCoord = unit:GetCoordinate()
      if unitCoord then
        local distance = bomberCoord:Get2DDistance(unitCoord)
        
        if distance <= self.MaxEscortDistance then
          local unitName = unit:GetName()
          escortsFound[unitName] = {
            Unit = unit,
            Distance = distance,
            Time = currentTime
          }
        end
      end
    end
  end)
  
  -- Update escort tracking
  self.EscortUnits = escortsFound
  self.EscortCount = self:_CountEscorts(escortsFound)
  
  -- Update escort status
  if self.EscortCount >= self.MinEscorts then
    self.LastEscortTime = currentTime
    self.UnescortedDuration = 0
    
    if not self.Bomber.HasEscort then
      self.Bomber:OnEscortArrived(self.EscortCount)
    end
  else
    self.UnescortedDuration = currentTime - self.LastEscortTime
    
    if self.Bomber.HasEscort then
      self.Bomber:OnEscortLost(self.UnescortedDuration)
    end
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
            threatsFound[threatId] = {
              Type = BOMBER_THREAT_MANAGER.ThreatType.SAM,
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
  
  -- Scan for fighter threats
  local fighterScan = SET_GROUP:New()
    :FilterCoalitions(enemyCoalition)
    :FilterCategories("plane")
    :FilterOnce()
  
  fighterScan:ForEachGroup(function(group)
    if group:IsAlive() and group:InAir() then
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
  
  return self
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
  self.TargetName = missionData.TargetName
  self.TargetPos = missionData.TargetPos
  self.RouteWaypoints = missionData.RouteWaypoints or {}
  
  -- Mission parameters
  self.CruiseAlt = missionData.CruiseAlt
  self.CruiseSpeed = missionData.CruiseSpeed
  
  -- Status
  self.MissionActive = false
  self.MissionSuccess = false
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
    TargetName = self.TargetName,
    TargetPos = self.TargetPos,
    TargetZone = self:_CreateTargetZone(),
    CruiseAlt = self.CruiseAlt,
    CruiseSpeed = self.CruiseSpeed,
    RouteWaypoints = self.RouteWaypoints,
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
    BASE:E("Failed to spawn bomber")
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
    end
  end
  
  if not startCoord and self.StartPos then
    startCoord = COORDINATE:New(self.StartPos.x, self.StartPos.alt or 0, self.StartPos.y)
  end
  
  if not startCoord then
    BASE:E("No valid start coordinate")
    return
  end
  
  -- Get target coordinate
  local targetCoord
  if self.TargetPos then
    targetCoord = COORDINATE:New(self.TargetPos.x, self.TargetPos.alt or 0, self.TargetPos.y)
  end
  
  if not targetCoord then
    BASE:E("No valid target coordinate")
    return
  end
  
  -- Build waypoint list
  local waypoints = {}
  
  -- Waypoint 1: Start (takeoff)
  local cruiseAlt = self.CruiseAlt or profile.CruiseAlt
  local cruiseSpeed = self.CruiseSpeed or profile.CruiseSpeed
  
  table.insert(waypoints, startCoord:WaypointAirTakeOffParking())
  
  -- Waypoint 2: Climb to cruise altitude
  local climbCoord = startCoord:Translate(10000, 0) -- 10km ahead
  climbCoord:SetAltitude(cruiseAlt * 0.3048) -- Convert feet to meters
  table.insert(waypoints, climbCoord:WaypointAirTurningPoint(nil, cruiseSpeed * 0.514444)) -- Convert knots to m/s
  
  -- Waypoint 3+: Route waypoints
  for _, waypointPos in ipairs(self.RouteWaypoints) do
    local wpCoord = COORDINATE:New(waypointPos.x, cruiseAlt * 0.3048, waypointPos.y)
    table.insert(waypoints, wpCoord:WaypointAirTurningPoint(nil, cruiseSpeed * 0.514444))
  end
  
  -- Waypoint N-1: Target (IP - Initial Point)
  local ipCoord = targetCoord:Translate(20000, 180) -- 20km before target
  ipCoord:SetAltitude(cruiseAlt * 0.3048)
  table.insert(waypoints, ipCoord:WaypointAirTurningPoint(nil, cruiseSpeed * 0.514444))
  
  -- Waypoint N: Target (bombing run)
  targetCoord:SetAltitude(cruiseAlt * 0.3048)
  local targetWP = targetCoord:WaypointAirTurningPoint(nil, cruiseSpeed * 0.514444)
  -- Add bombing task
  targetWP.task = {
    id = "ComboTask",
    params = {
      tasks = {
        {
          id = "Bombing",
          params = {
            point = {x = targetCoord.x, y = targetCoord.z},
            weaponType = 2032, -- Bombs
            expend = "All",
            attackQty = 1,
          }
        }
      }
    }
  }
  table.insert(waypoints, targetWP)
  
  -- Waypoint N+1: Egress
  local egressCoord = targetCoord:Translate(30000, 0) -- 30km past target
  egressCoord:SetAltitude(cruiseAlt * 0.3048)
  table.insert(waypoints, egressCoord:WaypointAirTurningPoint(nil, cruiseSpeed * 0.514444))
  
  -- Waypoint N+2: RTB (Return to start airbase)
  if self.StartAirbase then
    local airbase = AIRBASE:FindByName(self.StartAirbase)
    if airbase then
      local rtbCoord = airbase:GetCoordinate()
      table.insert(waypoints, rtbCoord:WaypointAirLanding(cruiseSpeed * 0.514444 * 0.7, airbase))
    end
  end
  
  -- Store route
  self.Bomber.Route = waypoints
  
  BASE:I(string.format("Route built: %d waypoints", #waypoints))
end

--- Create target zone
-- @param #BOMBER_MISSION self
-- @return #ZONE Target zone
function BOMBER_MISSION:_CreateTargetZone()
  if self.TargetPos then
    local coord = COORDINATE:New(self.TargetPos.x, self.TargetPos.alt or 0, self.TargetPos.y)
    return ZONE_RADIUS:New(self.TargetName or "Target", coord:GetVec2(), 2000) -- 2km radius
  end
  return nil
end

--- Get template name for bomber type
-- @param #BOMBER_MISSION self
-- @return #string Template name
function BOMBER_MISSION:_GetTemplateName()
  -- Convert bomber type to template name
  -- B-52H -> BOMBER_B52
  -- B-17G -> BOMBER_B17
  local typeName = string.gsub(self.BomberType, "[-]", "")
  typeName = string.gsub(typeName, "MS", "") -- Tu-95MS -> Tu-95
  return "BOMBER_" .. string.upper(typeName)
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
  ENROUTE = "Enroute",
  ATTACKING = "Attacking",
  EGRESSING = "Egressing",
  ABORTING = "Aborting",
  RTB = "RTB",
  LANDED = "Landed",
  DESTROYED = "Destroyed"
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
  
  -- Status tracking
  self.HasEscort = false
  self.IsUnderThreat = false
  self.AbortRequested = false
  self.MissionStartTime = nil
  self.MissionCompleted = false
  
  -- FSM States
  self:SetStartState(BOMBER.States.SPAWNED)
  self:AddTransition("*", "Takeoff", BOMBER.States.ENROUTE)
  self:AddTransition(BOMBER.States.ENROUTE, "ReachTarget", BOMBER.States.ATTACKING)
  self:AddTransition(BOMBER.States.ATTACKING, "BombsAway", BOMBER.States.EGRESSING)
  self:AddTransition({BOMBER.States.ENROUTE, BOMBER.States.ATTACKING}, "Abort", BOMBER.States.ABORTING)
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
  -- Create SPAWN object
  self.Spawner = SPAWN:New(self.TemplateName)
    :InitLimit(1, 0)
    :InitCoalition(self.Coalition)
    :InitGrouping(self.FlightSize)
  
  -- Spawn the group
  self.Group = self.Spawner:Spawn()
  
  if not self.Group then
    BASE:E("ERROR: Failed to spawn bomber group")
    return false
  end
  
  self.MissionStartTime = timer.getTime()
  
  -- Initialize monitoring systems
  self.EscortMonitor = BOMBER_ESCORT_MONITOR:New(self):Start()
  self.ThreatManager = BOMBER_THREAT_MANAGER:New(self):Start()
  
  -- Initialize formation manager
  self.FormationManager = BOMBER_FORMATION:New(self)
  self.FormationManager:Apply()
  
  -- Set up event handlers
  self:_SetupEventHandlers()
  
  -- Set ROE and ROT
  self.Group:OptionROEHoldFire()
  self.Group:OptionROTPassiveDefense()
  
  -- If route exists, fly it
  if self.Route and #self.Route > 0 then
    self:_StartRoute()
  else
    BASE:W("No route defined for bomber")
  end
  
  BASE:I(string.format("Bomber %s spawned: %s x%d", self.Callsign, self.Profile.DisplayName, self.FlightSize))
  
  -- Transition to ENROUTE state
  self:__Takeoff(5)
  
  return true
end

--- Start flying the route
-- @param #BOMBER self
function BOMBER:_StartRoute()
  if not self.Route or #self.Route == 0 then
    return
  end
  
  BASE:I(string.format("%s: Starting route with %d waypoints", self.Callsign, #self.Route))
  
  -- Route the group
  self.Group:Route(self.Route)
  
  -- Set up waypoint monitoring
  self:_MonitorWaypoints()
end

--- Monitor waypoint progress
-- @param #BOMBER self
function BOMBER:_MonitorWaypoints()
  -- Schedule waypoint checks
  self.WaypointMonitor = SCHEDULER:New(nil, function()
    if not self:IsAlive() then
      return
    end
    
    local currentWP = self.Group:GetTaskRoute() or 0
    local totalWP = #self.Route
    
    -- Check if at target waypoint (N-1 from end, which is the bombing run)
    if currentWP >= totalWP - 2 and not self:Is(BOMBER.States.ATTACKING) then
      self:__ReachTarget(0)
    end
    
    -- Check if past target (egress)
    if currentWP >= totalWP - 1 and self:Is(BOMBER.States.ATTACKING) then
      self:__BombsAway(0)
    end
    
    -- Check if at final waypoint
    if currentWP >= totalWP and self:Is(BOMBER.States.EGRESSING) then
      self:__ReturnToBase(0)
    end
    
  end, {}, 10, 10)
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
end

--- Escort arrived event
-- @param #BOMBER self
-- @param #number escortCount Number of escorts
function BOMBER:OnEscortArrived(escortCount)
  self.HasEscort = true
  
  local message = string.format("%s: Escort contact, %d fighters. Continuing mission.", 
    self.Callsign, escortCount)
  self:_BroadcastMessage(message)
  
  -- If was aborting and escort returns, can resume
  if self:Is(BOMBER.States.ABORTING) then
    local unescortedTime = self.EscortMonitor.UnescortedDuration
    if unescortedTime < 300 then -- Resume if < 5 minutes
      self:_BroadcastMessage(string.format("%s: Escort rejoined. Resuming mission.", self.Callsign))
      self:Takeoff() -- Transition back to ENROUTE
    end
  end
end

--- Escort lost event
-- @param #BOMBER self
-- @param #number unescortedTime Seconds without escort
function BOMBER:OnEscortLost(unescortedTime)
  self.HasEscort = false
  
  if unescortedTime < 30 then
    -- Just lost escort, send warning
    self:_BroadcastMessage(string.format("%s: Lost escort contact. Need immediate support!", self.Callsign))
  elseif unescortedTime < 120 then
    -- Been a while, getting nervous
    self:_BroadcastMessage(string.format("%s: No escort for %d seconds. Reducing speed.", 
      self.Callsign, math.floor(unescortedTime)))
    -- TODO: Reduce speed
  else
    -- Too long, abort mission
    if not self:Is(BOMBER.States.ABORTING) and not self:Is(BOMBER.States.RTB) then
      self:_BroadcastMessage(string.format("%s: No escort. Mission aborted, RTB!", self.Callsign))
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
  
  self:_BroadcastMessage(string.format("%s: %s threat! Bearing %d, %d km!", 
    self.Callsign, threatData.Type, bearing, distance))
  
  -- React based on threat type and escort status
  if threatData.Type == BOMBER_THREAT_MANAGER.ThreatType.FIGHTER then
    if not self.HasEscort then
      -- No escort, abort immediately
      self:_BroadcastMessage(string.format("%s: Bandits inbound, no escort! ABORTING!", self.Callsign))
      self:Abort()
    end
  elseif threatData.Type == BOMBER_THREAT_MANAGER.ThreatType.SAM then
    if threatData.Distance < 20000 then -- Inside SAM range
      -- TODO: Deploy countermeasures, evasive action
      self:_BroadcastMessage(string.format("%s: SAM threat close! Deploying countermeasures!", self.Callsign))
    end
  end
end

--- Threat cleared event
-- @param #BOMBER self
-- @param #table threatData Threat information
function BOMBER:OnThreatCleared(threatData)
  -- Check if any threats remain
  local remainingThreats = self.ThreatManager:GetActiveThreats()
  local count = 0
  for _ in pairs(remainingThreats) do count = count + 1 end
  
  if count == 0 then
    self.IsUnderThreat = false
    self:_BroadcastMessage(string.format("%s: Threats clear. Continuing mission.", self.Callsign))
  end
end

--- Broadcast message to coalition
-- @param #BOMBER self
-- @param #string message The message text
function BOMBER:_BroadcastMessage(message)
  trigger.action.outTextForCoalition(self.Coalition, message, 10)
end

--- FSM State: Enroute
-- @param #BOMBER self
function BOMBER:onenterEnroute()
  self:_BroadcastMessage(string.format("%s: Enroute to target.", self.Callsign))
end

--- FSM State: Attacking (at target)
-- @param #BOMBER self
function BOMBER:onenterAttacking()
  self:_BroadcastMessage(string.format("%s: At target. Beginning bombing run!", self.Callsign))
  
  -- Set ROE to weapons free for bombing
  self.Group:OptionROEWeaponFree()
end

--- FSM State: Egressing (bombs away)
-- @param #BOMBER self
function BOMBER:onenterEgressing()
  self:_BroadcastMessage(string.format("%s: Bombs away! Egressing target area.", self.Callsign))
  
  -- Back to hold fire
  self.Group:OptionROEHoldFire()
  
  -- Notify mission of completion
  if self.MissionData and self.MissionData.Mission then
    self.MissionData.Mission:Complete(true)
  end
end

--- FSM State: Aborting
-- @param #BOMBER self
function BOMBER:onenterAborting()
  self:_BroadcastMessage(string.format("%s: ABORTING MISSION!", self.Callsign))
  
  -- Cancel current route and head home
  if self.StartAirbase then
    local airbase = AIRBASE:FindByName(self.StartAirbase)
    if airbase then
      self.Group:RouteRTB(airbase)
    end
  end
  
  -- Notify mission of failure
  if self.MissionData and self.MissionData.Mission then
    self.MissionData.Mission:Complete(false)
  end
end

--- FSM State: RTB
-- @param #BOMBER self
function BOMBER:onenterRTB()
  self:_BroadcastMessage(string.format("%s: Returning to base.", self.Callsign))
end

--- FSM State: Landed
-- @param #BOMBER self
function BOMBER:onenterLanded()
  self:_BroadcastMessage(string.format("%s: Landed safely. Mission complete.", self.Callsign))
  
  -- Clean up after delay
  SCHEDULER:New(nil, function()
    self:Destroy()
  end, {}, 60)
end

--- Clean up bomber mission
-- @param #BOMBER self
function BOMBER:Destroy()
  if self.EscortMonitor then
    self.EscortMonitor:Stop()
  end
  if self.ThreatManager then
    self.ThreatManager:Stop()
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
  
  BASE:I("Bomber Marker System: ACTIVE")
  BASE:I("Available Bomber Types:")
  local types = BOMBER_PROFILE:ListTypes()
  for _, bomberType in ipairs(types) do
    BASE:I("  - " .. bomberType)
  end
  BASE:I("==============================================")
  BASE:I("Place map markers to create bomber missions:")
  BASE:I("  BOMBER START [airbase]")
  BASE:I("  BOMBER TARGET [name]")
  BASE:I("  BOMBER TYPE [aircraft]")
  BASE:I("  BOMBER SIZE [1-12]")
  BASE:I("  BOMBER ALT [feet]")
  BASE:I("  BOMBER SPEED [knots]")
  BASE:I("  BOMBER ROUTE [waypoint]  (optional, multiple)")
  BASE:I("  BOMBER EXECUTE          (spawns mission)")
  BASE:I("")
  BASE:I("After mission complete/failed:")
  BASE:I("  BOMBER RESPAWN          (repeats last mission)")
  BASE:I("==============================================")
  BASE:I("In-Flight Commands (F10 Menu):")
  BASE:I("  - Request Status")
  BASE:I("  - Recommend Abort")
  BASE:I("  - Warn: SAM Threat / Bandits")
  BASE:I("  - Request Speed Changes")
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
  BASE:I("Phase 2 Features: COMPLETE")
  BASE:I("  ✓ Route flying with waypoints")
  BASE:I("  ✓ Automated bombing runs")
  BASE:I("  ✓ F10 player menus")
  BASE:I("  ✓ Formation management")
  BASE:I("  ✓ Mission respawn system")
  BASE:I("==============================================")

  
  return _BOMBER_MARKER_SYSTEM
end

-- Auto-initialize if running directly
if not BOMBER_ESCORT_NO_AUTO_INIT then
  BOMBER_ESCORT_INIT()
end
