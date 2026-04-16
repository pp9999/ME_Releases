--[[
    OSRS — Colossal Wyrm Agility Course (Varlamore)
    Requires: 60 Agility (basic route) | 85 Agility (advanced route)
    Start:    Stand at the Roots (first obstacle), south of Civitas illa Fortis.
              Approximate tile: 1649, 3138

    ⚠ Obstacle IDs: verified against community data as of 2024.
      If an obstacle fails to click, use the RuneLite Object Inspector
      plugin while next to it and update the ID in the obstacles table below.

    Controls:
      • Set USE_ADVANCED_ROUTE = true  to run the 85+ advanced route.
      • Set TICK_EAT_FOOD          = true  to eat food when HP < HP_THRESHOLD.
      • Set STOP_AT_LEVEL          = the agility level you want to stop at (0 = never).
]]

local API    = require("api")
local APIOSRS = require("apiosrs")

-- ─────────────────────────── USER SETTINGS ────────────────────────────────
local USE_ADVANCED_ROUTE = false   -- true = 85+ advanced route, false = basic (60+)
local TICK_EAT_FOOD      = false   -- eat food if HP drops below threshold
local HP_THRESHOLD       = 20      -- HP % to eat at (only used if TICK_EAT_FOOD = true)
local FOOD_IDS           = {379, 385, 7946}  -- Lobster, Shark, Manta ray
local STOP_AT_LEVEL      = 0       -- stop when Agility reaches this level (0 = never)
-- ───────────────────────────────────────────────────────────────────────────

--[[
    Colossal Wyrm Basic Route obstacles (60 Agility)
    Obstacle order follows the course layout west → east → north loop.
    finalX / finalY = approximate tile the player lands on after the obstacle.
--]]
local basicObstacles = {
    { id = 47782, name = "Roots",             finalX = 1649, finalY = 3141 },
    { id = 47783, name = "Low wall",          finalX = 1657, finalY = 3143 },
    { id = 47784, name = "Monkeybars",        finalX = 1664, finalY = 3145 },
    { id = 47785, name = "Gap",               finalX = 1671, finalY = 3142 },
    { id = 47786, name = "Stepping stone",    finalX = 1676, finalY = 3138 },
    { id = 47787, name = "Low wall (east)",   finalX = 1674, finalY = 3133 },
    { id = 47788, name = "Gap (finish)",      finalX = 1664, finalY = 3130 },
}

--[[
    Colossal Wyrm Advanced Route obstacles (85 Agility)
    The advanced route branches off mid-course for extra XP.
    Update IDs with the Object Inspector if needed.
--]]
local advancedObstacles = {
    { id = 47782, name = "Roots",             finalX = 1649, finalY = 3141 },
    { id = 47783, name = "Low wall",          finalX = 1657, finalY = 3143 },
    { id = 47789, name = "Advanced ledge",    finalX = 1662, finalY = 3150 },
    { id = 47790, name = "Advanced gap",      finalX = 1668, finalY = 3155 },
    { id = 47791, name = "Advanced beams",    finalX = 1675, finalY = 3150 },
    { id = 47792, name = "Advanced wall",     finalX = 1679, finalY = 3142 },
    { id = 47787, name = "Low wall (east)",   finalX = 1674, finalY = 3133 },
    { id = 47788, name = "Gap (finish)",      finalX = 1664, finalY = 3130 },
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
local function nearTile(x, y, radius)
    radius = radius or 3
    local p = API.PlayerCoord()
    return math.abs(p.x - x) <= radius and math.abs(p.y - y) <= radius
end

--- Eat food from inventory if HP is low.
local function eatIfNeeded()
    if not TICK_EAT_FOOD then return end
    local hpCurrent = API.GetHP_()
    local hpMax     = API.GetMaxHP_()
    if hpMax and hpMax > 0 and (hpCurrent / hpMax * 100) < HP_THRESHOLD then
        log("HP low — eating food.")
        APIOSRS.RL_ClickEntity(93, FOOD_IDS, 15)
        API.RandomSleep2(800, 200, 300)
    end
end

--- Try to click an obstacle object. Retries once on failure.
local function clickObstacle(obstacle)
    log("Clicking: " .. obstacle.name .. " (ID " .. obstacle.id .. ")")
    local ok = APIOSRS.RL_ClickEntity(0, { obstacle.id }, 20)
    if not ok then
        -- small sleep then retry
        API.RandomSleep2(600, 100, 200)
        ok = APIOSRS.RL_ClickEntity(0, { obstacle.id }, 20)
        if not ok then
            log("Could not find obstacle: " .. obstacle.name .. " — skipping.")
            return false
        end
    end
    return true
end

--- Cross a single obstacle and wait until the player lands near the exit tile.
local function crossObstacle(obstacle)
    if not clickObstacle(obstacle) then return false end

    -- Wait until we're near the destination OR we've timed out
    local elapsed  = 0
    local maxWait  = 10000
    local interval = 400
    API.RandomSleep2(700, 200, 300) -- let the animation begin

    while API.Read_LoopyLoop() do
        if nearTile(obstacle.finalX, obstacle.finalY, 4) then
            log("Reached: " .. obstacle.name)
            API.RandomSleep2(200, 50, 150)
            return true
        end
        -- If idle but not at destination, the click may have missed — retry
        if elapsed > 2000 and not API.CheckAnim(50) and not API.ReadPlayerMovin() then
            log("Idle but not at destination — retrying " .. obstacle.name)
            clickObstacle(obstacle)
            elapsed = 0
        end
        API.RandomSleep2(interval, 50, 100)
        elapsed = elapsed + interval
        if elapsed >= maxWait then
            log("Timed out on: " .. obstacle.name)
            return false
        end
    end
    return false
end

--- Check if we should stop due to level goal.
local function shouldStop()
    if STOP_AT_LEVEL <= 0 then return false end
    local lvl = API.XpToLvl(API.GetSkillXP("AGILITY"))
    if lvl >= STOP_AT_LEVEL then
        log("Reached target Agility level " .. lvl .. " — stopping.")
        API.Write_LoopyLoop(false)
        return true
    end
    return false
end

-- ─────────────────────────── MAIN LOOP ────────────────────────────────────

log("Starting Colossal Wyrm Agility — " ..
    (USE_ADVANCED_ROUTE and "Advanced Route (85+)" or "Basic Route (60+)"))
log("Stand at the Roots obstacle to begin. Course start: ~1649, 3138")

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do

    if shouldStop() then break end

    eatIfNeeded()

    -- Run all obstacles in order for one full lap
    local lapFailed = false
    for i, obstacle in ipairs(obstacles) do
        if not API.Read_LoopyLoop() then break end
        if shouldStop() then break end

        eatIfNeeded()

        local success = crossObstacle(obstacle)
        if not success then
            log("Failed obstacle " .. i .. " (" .. obstacle.name .. ") — will retry next iteration.")
            lapFailed = true
            break
        end

        -- Small random delay between obstacles (human-like pacing)
        API.RandomSleep2(300, 100, 500)
    end

    if not lapFailed then
        log("Lap complete! Starting next lap...")
        -- Brief pause at the end of a lap before looping
        API.RandomSleep2(400, 100, 300)
    else
        -- Give a moment before retrying after a failure
        API.RandomSleep2(1200, 400, 600)
    end

    collectgarbage("collect")
end

log("Script stopped.")
