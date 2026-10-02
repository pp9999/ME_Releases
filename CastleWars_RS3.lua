--[[
================================================================================
  CastleWars_RS3.lua                                            RS3 / MemoryError
================================================================================
  Castle Wars helper for the MemoryError (ME) RS3 API.

  Core rule (as requested):
      BEFORE every action we do an AREA CHECK, then act only if the player is
      inside that area AND the target is closer than 15 tiles.

      order:  inArea()  ->  nearest target within <15  ->  DoAction_Object1

  API flavour: RS3 / MemoryError  ->  require("api") only.
      API.PInArea(x, xrange, y, yrange, zfloor)
      API.DoAction_Object1(action, route, { ids }, maxdist)
      API.OFF_ACT_GeneralObject_route0

  DOACTIONS / IDS below were taken from the existing repo scripts
  ("Castle Wars AFK.lua", "Amr1x1/castleWars.lua"). If your client logs
  different opcodes, set DEBUG_SCAN = true, run the script and read the ME
  console: it prints every nearby object/NPC as
        [DBG] type=.. id=.. name=.. dist=.. action=..
  then update TASKS with the ids/opcodes you see.

  Author: (your name)  --  this is a personal script, kept additive so the
  existing Castle Wars scripts are untouched.
================================================================================
--]]

local API = require("api")

-- ────────────────────────────────────────────────────────────────────────────
--  CONFIG
-- ────────────────────────────────────────────────────────────────────────────

-- Print every object/NPC within DEBUG_RANGE once per loop. Use this to collect
-- the doactions from the ME console, then set to false for normal play.
local DEBUG_SCAN  = false
local DEBUG_RANGE = 20

-- Never act on anything further away than this (requested: < 15).
local DEFAULT_MAX_DIST = 15

-- Known Castle Wars ids (from repo scripts).
local IDS = {
    GUTHIX_PORTAL      = 83642,
    BANK_CHEST         = 83634,
    EXIT_PORTAL_SARA   = 83510,
    EXIT_PORTAL_ZAMMY  = 83620,
    WAITING_ROOM       = 74979,
    ZAMMY_DOOR         = 83570,
    SARA_DOOR          = 83496,
    ZAMMY_LADDER       = 83622,
    SARA_LADDER        = 83511,
}

-- Commonly used opcodes seen in the repo Castle Wars scripts.
local OP = {
    DOOR_PORTAL = 0x39,
    LADDER      = 0x34,
}

-- Areas. PInArea(x_center, x_range, y_center, y_range, zfloor).
--   `z`     -> what we hand to PInArea for that area.
--   `floor` -> explicit plane gate checked with API.GetFloorLv_2() before acting.
--   NOTE: adjust these to the tiles your client actually reports.
local AREA = {
    LOBBY        = { x = 2441, xr = 10, y = 3090, yr = 10, z = 0, floor = 0 }, -- queue lobby
    SARA_WAITING = { x = 2480, xr = 15, y = 9482, yr = 20, z = 0, floor = 0 }, -- sara waiting room
    ZAMMY_WAITING= { x = 2421, xr = 15, y = 9522, yr = 20, z = 0, floor = 0 }, -- zammy waiting room
    SARA_RESPAWN = { x = 2423, xr = 20, y = 3070, yr = 12, z = 1, floor = 1 }, -- sara respawn (upstairs)
    ZAMMY_RESPAWN= { x = 2370, xr = 12, y = 3135, yr = 12, z = 1, floor = 1 }, -- zammy respawn (upstairs)
}

-- TASKS: each entry = one gated action.
--   name    : status text
--   area    : key into AREA (required -- this is the area check)
--   floor   : required plane(s) via API.GetFloorLv_2() -- number or {n,...}
--             (nil = inherit AREA[...].floor; false = skip floor check)
--   ids     : target object ids
--   action  : doaction opcode
--   types   : entity types to scan (0 = object, 12 = decor)
--   maxdist : distance gate (must be < this; keep <= 15)
local TASKS = {
    {
        name    = "Entering Guthix portal",
        area    = "LOBBY",
        floor   = 0,
        ids     = { IDS.GUTHIX_PORTAL },
        action  = OP.DOOR_PORTAL,
        types   = { 0, 12 },
        maxdist = 15,
    },
    {
        name    = "Climbing Sara ladder",
        area    = "SARA_RESPAWN",
        floor   = 1,
        ids     = { IDS.SARA_LADDER },
        action  = OP.LADDER,
        types   = { 0, 12 },
        maxdist = 15,
    },
    {
        name    = "Climbing Zammy ladder",
        area    = "ZAMMY_RESPAWN",
        floor   = 1,
        ids     = { IDS.ZAMMY_LADDER },
        action  = OP.LADDER,
        types   = { 0, 12 },
        maxdist = 15,
    },
    {
        name    = "Opening Sara door",
        area    = "SARA_RESPAWN",
        floor   = 1,
        ids     = { IDS.SARA_DOOR },
        action  = OP.DOOR_PORTAL,
        types   = { 0, 12 },
        maxdist = 15,
    },
    {
        name    = "Opening Zammy door",
        area    = "ZAMMY_RESPAWN",
        floor   = 1,
        ids     = { IDS.ZAMMY_DOOR },
        action  = OP.LADDER,
        types   = { 0, 12 },
        maxdist = 15,
    },
}

-- ────────────────────────────────────────────────────────────────────────────
--  HELPERS
-- ────────────────────────────────────────────────────────────────────────────

local function status(msg)
    API.Write_ScripCuRunning0(msg)
end

local function inArea(area)
    return API.PInArea(area.x, area.xr, area.y, area.yr, area.z or 0)
end

--- Floor gate using API.GetFloorLv_2().
--- `want` may be:
---   nil            -> no requirement (passes)
---   false          -> explicit "skip floor check" (passes)
---   number         -> must equal that plane
---   table {a,b,..} -> must match any listed plane
local function checkFloor(want)
    if want == nil or want == false then
        return true
    end
    local floor = API.GetFloorLv_2()
    if type(want) == "table" then
        for _, f in ipairs(want) do
            if floor == f then return true end
        end
        return false
    end
    return floor == want
end

--- Nearest matching object within maxdist, or nil. AllObject has a .Distance field.
local function nearestObject(ids, maxdist, types)
    local objs = API.GetAllObjArray1(ids, maxdist, types)
    if objs and objs[1] then
        return objs[1]
    end
    return nil
end

--- Core gated action:
---   1) player inside area?           (area check)
---   2) player on the required floor? (floor check via API.GetFloorLv_2)
---   3) object exists AND dist < max? (distance check, "closer than <15")
---   4) only then dispatch the DoAction.
---@return boolean acted
local function actIfInAreaAndNear(task)
    local area = AREA[task.area]
    if not area then
        return false
    end

    -- 1. AREA CHECK
    if not inArea(area) then
        return false
    end

    -- 2. FLOOR CHECK (explicit; task.floor overrides AREA[...].floor)
    local wantFloor = task.floor
    if wantFloor == nil then
        wantFloor = area.floor
    end
    if not checkFloor(wantFloor) then
        return false
    end

    -- 3. DISTANCE CHECK (must be strictly closer than maxdist)
    local maxd = task.maxdist or DEFAULT_MAX_DIST
    local obj  = nearestObject(task.ids, maxd, task.types or { 0, 12 })
    if not obj or not (obj.Distance and obj.Distance < maxd) then
        return false
    end

    -- 4. DOACTION
    status(string.format("%s (z=%d dist %d)", task.name, API.GetFloorLv_2(), math.floor(obj.Distance)))
    API.DoAction_Object1(task.action, API.OFF_ACT_GeneralObject_route0, task.ids, maxd)
    return true
end

--- Debug: dump nearby objects/NPCs so you can read the doactions from console.
local function dumpNearby(maxdist)
    print(string.format("[DBG] player floor=%d", API.GetFloorLv_2()))
    local objs = API.ReadAllObjectsArray({ 0, 1, 12 }, {}, {})
    for _, o in ipairs(objs) do
        if o.Distance and o.Distance <= maxdist then
            print(string.format(
                "[DBG] type=%d id=%d name=%s floor=%s dist=%d action=%s",
                o.Type, o.Id, tostring(o.Name), tostring(o.Floor),
                math.floor(o.Distance), tostring(o.Action or "")))
        end
    end
end

--- Accept the team/enter dialogue if the waiting-room prompt is up.
local function handleDialog()
    if API.Dialog_Option("Yes, please!") then
        API.Select_Option("Yes, please!")
        API.RandomSleep2(800, 600, 600)
    end
end

-- ────────────────────────────────────────────────────────────────────────────
--  SETUP (outside the loop, per ME conventions)
-- ────────────────────────────────────────────────────────────────────────────

API.SetMaxIdleTime(5)          -- auto anti-idle while AFK in the game
API.Write_ScripCuRunning0("Castle Wars: starting")

-- ────────────────────────────────────────────────────────────────────────────
--  MAIN LOOP
-- ────────────────────────────────────────────────────────────────────────────

API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do

    if not API.PlayerLoggedIn() then
        status("Not logged in - stopping")
        API.Write_LoopyLoop(false)
        break
    end

    if DEBUG_SCAN then
        dumpNearby(DEBUG_RANGE)
    end

    handleDialog()

    -- Walk the task list: first task whose area + distance gates pass, acts.
    local acted = false
    for _, task in ipairs(TASKS) do
        if actIfInAreaAndNear(task) then
            acted = true
            API.RandomSleep2(1200, 600, 1500)   -- let the action register
            API.WaitUntilMovingEnds()
            break
        end
    end

    if not acted then
        status("Castle Wars: idle (no area/action)")
        API.RandomSleep2(1200, 800, 2000)
    end

end

status("Castle Wars: stopped")
