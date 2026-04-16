--[[
    Controls:
      • Set USE_ADVANCED_ROUTE = true  to run the 62+ advanced route.
]]

local API    = require("api")
local APIOSRS = require("apiosrs")

-- ─────────────────────────── USER SETTINGS ────────────────────────────────
local USE_ADVANCED_ROUTE = true   -- true = 62+ advanced route, false = basic (50+)
-- ───────────────────────────────────────────────────────────────────────────

--[[
    Colossal Wyrm Basic Route obstacles (50 Agility)
    Obstacle order follows the course layout west → east → north loop.
    finalX / finalY = approximate tile the player lands on after the obstacle.
--]]
local basicObstacles = {
    { id = 55178, name = "Ladder_1",          finalX = 1652, finalY = 2931, plane = 0 },
    { id = 55180, name = "Rope_1",          finalX = 1655, finalY = 2925, plane = 1 },
    { id = 55184, name = "Rope_2",        finalX = 1646, finalY = 2910, plane = 1 },
    { id = 55186, name = "Rope_3",         finalX = 1631, finalY = 2910, plane = 1 },
    { id = 55190, name = "Ladder_2",    finalX = 1626, finalY = 2932, plane = 1 },
    { id = 55179, name = "Slide_down",   finalX = 1626, finalY = 2933, plane = 2 }
}

--[[
    Colossal Wyrm Advanced Route obstacles (62 Agility)
    The advanced route branches off mid-course for extra XP.
    Update IDs with the Object Inspector if needed.
--]]
local advancedObstacles = {
    { id = 55178, name = "Ladder_1",          finalX = 1652, finalY = 2931, plane = 0 },
    { id = 55180, name = "Rope_1",          finalX = 1655, finalY = 2925, plane = 1 },
    { id = 55191, name = "UPLadder_1",        finalX = 1648, finalY = 2909, plane = 1 },
    { id = 55192, name = "UPPER_obst",         finalX = 1646, finalY = 2907, plane = 2 },
    { id = 55194, name = "UPPER_rope_1",    finalX = 1633, finalY = 2908, plane = 2 },
    { id = 55179, name = "Slide_down",   finalX = 1626, finalY = 2933, plane = 2 }
}

-- Pick active route
local obstacles = USE_ADVANCED_ROUTE and advancedObstacles or basicObstacles

-- ─────────────────────────── HELPERS ──────────────────────────────────────

local function log(msg)
    print("[WyrmAgility] " .. msg)
end

--- Wait for the player to stop animating and moving.
--- Returns false if we time out (stuck detection).
local function waitForIdle(timeoutMs)
    timeoutMs = timeoutMs or 12000
    local elapsed = 0
    local interval = 300
    -- first, give it a moment to START the action
    API.RandomSleep2(600, 200, 400)
    while API.Read_LoopyLoop() do
        if not API.CheckAnim(50) and not API.ReadPlayerMovin() then
            return true
        end
        API.RandomSleep2(interval, 50, 100)
        elapsed = elapsed + interval
        if elapsed >= timeoutMs then
            log("Timeout waiting for idle — possible stuck!")
            return false
        end
    end
    return false
end

--- Check whether the player is near a given world tile (within `radius` tiles).
local function nearTile(x, y, radius, plane)
    radius = radius or 3
    local p = API.PlayerCoord()
    --print("Player at: " .. tostring(p.x) .. ", " .. tostring(p.y) .. ", plane " .. tostring(p.z))
    --print("Checking near: " .. tostring(x) .. ", " .. tostring(y) .. ", plane " .. tostring(plane) .. " with radius " .. tostring(radius))
    return math.abs(p.x - x) <= radius and math.abs(p.y - y) <= radius and p.z == plane
end

--- Cross a single obstacle and wait until the player lands near the exit tile.
local function crossObstacle(obstacle)
    -- If idle but not at destination, the click may have missed — retry
    if (not API.CheckAnim(50) and not API.ReadPlayerMovin()) then
        APIOSRS.RL_ClickEntity(0, { obstacle.id }, 20)
        return true
    end
    return false
end

-- ─────────────────────────── MAIN LOOP ────────────────────────────────────

log("Starting Colossal Wyrm Agility — " ..
    (USE_ADVANCED_ROUTE and "Advanced Route (62+)" or "Basic Route (50+)"))

API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do

    waitForIdle(20000)  -- wait for any previous obstacle action to complete

    -- Run all obstacles in order for one full lap
    for i, obstacle in ipairs(obstacles) do
        if not API.Read_LoopyLoop() then break end
        --check before
        if nearTile(obstacle.finalX,obstacle.finalY, 10, obstacle.plane) then
            log("Trying obstacle " .. i .. " (" .. obstacle.name .. ")")
            crossObstacle(obstacle)
            API.RandomSleep2(2000, 100, 500)
            break
        end
    end

    collectgarbage("collect")
end

log("Script stopped.")
