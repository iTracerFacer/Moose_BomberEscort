--- Test/Demo Script for MOOSE Bomber Escort System
-- This script demonstrates how to set up and test the bomber escort system
-- Load this AFTER Moose.lua and Moose_BomberEscort.lua

---
-- TEST CONFIGURATION
---

-- List all available bomber types on startup
BASE:I("=== AVAILABLE BOMBER TYPES ===")
local bomberTypes = BOMBER_PROFILE:ListTypes()
for _, bType in ipairs(bomberTypes) do
  local profile = BOMBER_PROFILE:Get(bType)
  BASE:I(string.format("%s - %s (%dkts @ %dft)", 
    bType, 
    profile.DisplayName, 
    profile.CruiseSpeed, 
    profile.CruiseAlt))
end

---
-- MANUAL BOMBER SPAWN TEST
-- Uncomment this section to manually spawn a bomber for testing
---

--[[
-- Delayed spawn for testing (10 seconds after mission start)
SCHEDULER:New(nil, function()
  
  BASE:I("=== MANUAL BOMBER SPAWN TEST ===")
  
  -- Create test mission data
  local testMission = {
    Coalition = coalition.side.BLUE,
    BomberType = "B-52H",
    FlightSize = 2,
    StartAirbase = "Nellis AFB",
    TargetName = "Test Target",
    CruiseAlt = 25000,
    CruiseSpeed = 400,
  }
  
  -- Spawn bomber
  -- NOTE: You need a template group named "BOMBER_B52" in mission editor
  local bomber = BOMBER:New("BOMBER_B52", testMission)
  
  if bomber then
    local success = bomber:Spawn()
    
    if success then
      BASE:I("Test bomber spawned successfully: " .. bomber.Callsign)
      BASE:I("Get close to the bomber in an aircraft to test escort detection!")
    else
      BASE:E("Failed to spawn test bomber")
    end
  else
    BASE:E("Failed to create bomber object - check bomber type")
  end
  
end, {}, 10)
--]]

---
-- DEBUG: Monitor bomber marker system
---
SCHEDULER:New(nil, function()
  if _BOMBER_MARKER_SYSTEM then
    -- Show pending missions
    for coalitionSide, pending in pairs(_BOMBER_MARKER_SYSTEM.PendingMissions) do
      local count = 0
      for _ in pairs(pending) do count = count + 1 end
      
      if count > 0 then
        BASE:I(string.format("Coalition %d has %d pending marker commands", coalitionSide, count))
      end
    end
  end
end, {}, 30, 30)

---
-- DEMONSTRATION: Show how to integrate with mission
---

-- Example: Create F10 menu for testing
local testMenu = MENU_MISSION:New("Bomber Escort Tests")

-- Menu: Show bomber types
MENU_MISSION_COMMAND:New("List Bomber Types", testMenu, function()
  local msg = "AVAILABLE BOMBER TYPES:\n\n"
  local types = BOMBER_PROFILE:ListTypes()
  for _, bType in ipairs(types) do
    local profile = BOMBER_PROFILE:Get(bType)
    msg = msg .. string.format("%s\n  %s\n  Cruise: %d kts @ %,d ft\n  Escort: %d fighters\n\n",
      bType,
      profile.DisplayName,
      profile.CruiseSpeed,
      profile.CruiseAlt,
      profile.MinEscorts)
  end
  trigger.action.outText(msg, 30)
end)

-- Menu: Show marker help
MENU_MISSION_COMMAND:New("Show Marker Commands", testMenu, function()
  local msg = [[
BOMBER MARKER COMMANDS:

1. BOMBER START [airbase]
   Example: "BOMBER START Nellis"
   Place at departure airbase

2. BOMBER TARGET [name]
   Example: "BOMBER TARGET Enemy HQ"
   Place at target location

3. BOMBER TYPE [aircraft]
   Example: "BOMBER TYPE B-17G"
   Place anywhere

4. BOMBER SIZE [1-12]
   Example: "BOMBER SIZE 4"
   Number of aircraft

5. BOMBER ALT [feet]
   Example: "BOMBER ALT 20000"
   Optional cruise altitude

6. BOMBER SPEED [knots]
   Example: "BOMBER SPEED 350"
   Optional cruise speed

7. BOMBER EXECUTE
   Create mission from markers
   Place anywhere

All markers consumed on EXECUTE.
Multiple missions can be created.
]]
  trigger.action.outText(msg, 45)
end)

-- Menu: Show system status
MENU_MISSION_COMMAND:New("System Status", testMenu, function()
  local msg = "BOMBER ESCORT SYSTEM STATUS:\n\n"
  
  if _BOMBER_MARKER_SYSTEM then
    msg = msg .. "Marker System: ACTIVE\n\n"
    
    for coalitionSide = 0, 2 do
      local pending = _BOMBER_MARKER_SYSTEM.PendingMissions[coalitionSide]
      if pending then
        local count = 0
        for _ in pairs(pending) do count = count + 1 end
        
        if count > 0 then
          msg = msg .. string.format("Coalition %d: %d pending commands\n", coalitionSide, count)
        end
      end
    end
  else
    msg = msg .. "Marker System: NOT FOUND\n"
  end
  
  msg = msg .. "\nBomber Types Available: " .. #BOMBER_PROFILE:ListTypes()
  
  trigger.action.outText(msg, 15)
end)

---
-- HELPER: Quick spawn function for mission designers
---

--- Quickly spawn a bomber with minimal setup
-- @param #string bomberType Type of bomber (e.g., "B-52H")
-- @param #string templateName Mission editor template group name
-- @param #number flightSize Number of aircraft (1-12)
-- @param #number coalitionSide Coalition (coalition.side.BLUE or RED)
-- @return #BOMBER The bomber object
function QUICK_BOMBER_SPAWN(bomberType, templateName, flightSize, coalitionSide)
  local missionData = {
    Coalition = coalitionSide or coalition.side.BLUE,
    BomberType = bomberType or "B-52H",
    FlightSize = flightSize or 2,
    StartAirbase = "Unknown",
    TargetName = "Unknown",
  }
  
  local bomber = BOMBER:New(templateName, missionData)
  if bomber then
    bomber:Spawn()
  end
  
  return bomber
end

BASE:I("==============================================")
BASE:I("BOMBER ESCORT TEST SCRIPT LOADED")
BASE:I("Use F10 Menu → Bomber Escort Tests for info")
BASE:I("Use F10 Map Markers to create missions")
BASE:I("==============================================")
