-- Title: FMK_Optimal Fort Builder
-- Author: FourthMK
-- Description: Optimal Construction Hotspot Builder for Fort Forinthry. Follows and clicks the optimal construction hotspot
-- Version: 3.8
-- Category: Construction

local API = require("api")
API.SetDrawLogs(true)
API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)

-- Config
local HOTSPOT_IDS = {125061, 125065}  -- Optimal Construction Hotspot IDs

local SEARCH_DISTANCE = 60            -- how far to look for hotspots
local last_hotspot_key = nil          


local function playerToObjDistance(obj)
    local p = API.PlayerCoordfloat()
    local dist = API.Math_DistanceF(p, obj.Tile_XYZ)
    return dist
end

-- Get all hotspot objects for the candidate IDs
local function getAllHotspots()
    local found = API.GetAllObjArray1(HOTSPOT_IDS, SEARCH_DISTANCE, {0})
    if #found == 0 then
        API.logDebug("No hotspots detected within " .. SEARCH_DISTANCE .. " tiles")
    end
    return found
end

-- Choose the closest hotspot by distance
local function getClosestHotspot()
    local hotspots = getAllHotspots()
    local closest, minDist = nil, math.huge
    for _, obj in ipairs(hotspots) do
        local dist = playerToObjDistance(obj)
        if dist < minDist then
            minDist = dist
            closest = obj
        end
    end
    return closest, minDist
end

-- Route-and-interact to the exact tile of the hotspot
local function routeAndInteractHotspot(obj, label)
    label = label or "hotspot"
    local tile = WPOINT.new(obj.CalcX, obj.CalcY, 0)

    API.DoAction_Object2(0x29, API.OFF_ACT_GeneralObject_route0, { obj.Id }, 50, tile)

    API.RandomSleep2(150, 100, 200)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(150, 100, 200)
end

-- Decide if we're ready to click (not moving and not animating)
local function readyToAct()
    local moving = API.ReadPlayerMovin2()
    local anim = API.CheckAnim(40)
    return (not moving) and (not anim)
end

-- Main loop
API.ClearLog()
local last_xp = API.GetSkillXP("CONSTRUCTION") or 0
API.logInfo("Optimal Construction Hotspot Builder started")

while API.Read_LoopyLoop() do
    local hotspot, dist = getClosestHotspot()

    local hotspot_key = hotspot and string.format("%d_%d_%d", hotspot.Id, hotspot.CalcX or -1, hotspot.CalcY or -1) or nil

    if hotspot and dist > 0 and hotspot_key ~= last_hotspot_key then
        API.logInfo(string.format("Switching to new hotspot at %.2f tiles", dist))
        local tries = 0
        local success = false
        while tries < 3 and not success do
            routeAndInteractHotspot(hotspot, "closest-hotspot")
            API.RandomSleep2(3000, 2000, 4000) -- Wait for XP gain
            local xp = API.GetSkillXP("CONSTRUCTION") or last_xp
            if xp > last_xp then
                success = true
                last_xp = xp
            else
                tries = tries + 1
                if tries < 3 then
                    API.logInfo("No XP gain, retrying (" .. tries .. "/3)")
                end
            end
        end
        if not success then
            API.logInfo("No XP gain after 3 tries, stopping script")
            break
        end
        last_hotspot_key = hotspot_key
    elseif not readyToAct() then
        -- Currently moving or building; wait a bit
        API.RandomSleep2(150, 100, 200)
    else
        -- Ready but no new optimal hotspot or too close; idle a bit
        API.logDebug("Idling - no new actions required")
        API.RandomSleep2(300, 200, 400)
    end

    API.DoRandomEvents()
    API.RandomSleep2(30, 20, 40)
end

API.logInfo("Building complete. Script stopped")
