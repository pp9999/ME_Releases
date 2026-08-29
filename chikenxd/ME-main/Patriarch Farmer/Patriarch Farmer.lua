--[[
@Title: Patriarch Farmer
@Description: Find Living rock Patriarch, kill, area-loot all, and world hop.
@Author: Codex
@Version: 1.0.1
--]]

local API = require("api")
local Slib = require("slib")

math.randomseed(os.time())

-- ============================================================================
-- INLINED UTILS
-- ============================================================================

local function randomSleep(milliseconds)
    local randomDelay = math.random(1, 200)
    local totalDelay = milliseconds + randomDelay
    local start = os.clock()
    local target = start + (totalDelay / 1000)
    while os.clock() < target do
        API.RandomSleep2(100, 0, 0)
    end
end

local function isWorldSelectionOpen()
    if type(WorldHop) == "table" and type(WorldHop.IsOpen) == "function" then
        local ok, isOpen = pcall(function() return WorldHop:IsOpen() end)
        if ok and isOpen == true then return true end
    end
    return API.GetInterfaceOpenBySize(1587)
end

local function isUsingCurses()
    return API.VB_FindPSettinOrder(3277, 0).state & 1 == 1
end

-- ============================================================================
-- GUI STATE
-- ============================================================================

local GUI = {
    started = false,
    selectConfigTab = true,
    selectInfoTab = false,
    config = {
        enableSoulSplit = false,
        enableProtectFromMelee = false,
        randomizeWorldOrder = false,
        enableFood = false,
        foodName = "blubber jellyfish",
        foodHealThreshold = 4000,
        enablePrayerRestore = false,
        restoreName = "Super restore",
    }
}

local THEME = {
    dark = { 0.12, 0.08, 0.05 },
    medium = { 0.25, 0.16, 0.10 },
    light = { 0.70, 0.55, 0.40 },
    bright = { 0.60, 0.40, 0.25 },
    glow = { 0.85, 0.60, 0.35 },
}

-- ============================================================================
-- CONFIG
-- ============================================================================

local CFG = {
    TARGET_NPC_ID = 8834,
    TARGET_NPC_NAMES = { "Living rock patriarch" },
    NPC_SCAN_DISTANCE = 120,
    NPC_NEARBY_DISTANCE = 40,
    ATTACK_DISTANCE = 50,
    MOVE_PROXIMITY = 3,

    MOVE_TIMEOUT_SEC = 35,
    ATTACK_TIMEOUT_SEC = 8,
    KILL_TIMEOUT_SEC = 160,
    LOOT_TIMEOUT_SEC = 6,

    ATTACK_COOLDOWN_SEC = 2,

    LOOP_DELAY_MIN_MS = 120,
    LOOP_DELAY_MAX_MS = 260,
    POST_ATTACK_DELAY_MIN_MS = 700,
    POST_ATTACK_DELAY_MAX_MS = 1200,
    PRE_LOOT_DELAY_MIN_MS = 500,
    PRE_LOOT_DELAY_MAX_MS = 950,
    POST_LOOT_DELAY_MIN_MS = 700,
    POST_LOOT_DELAY_MAX_MS = 1200,
    MICRO_PAUSE_CHANCE = 0.03,
    MICRO_PAUSE_MIN_MS = 900,
    MICRO_PAUSE_MAX_MS = 2200,

}

local STATE = {
    SCAN_PATRIARCH = "SCAN_PATRIARCH",
    MOVE_TO_TARGET = "MOVE_TO_TARGET",
    ATTACK_TARGET = "ATTACK_TARGET",
    WAIT_KILL_COMPLETE = "WAIT_KILL_COMPLETE",
    LOOT_ALL = "LOOT_ALL",
    WORLD_HOP = "WORLD_HOP",
    STOPPED = "STOPPED",
}

-- ============================================================================
-- RUNTIME
-- ============================================================================

local rt = {
    state = STATE.SCAN_PATRIARCH,
    stateStartedAt = os.time(),
    startedAt = os.time(),

    currentWorld = API.GetWorldNR() or 0,
    worldHops = 0,
    emptyWorlds = 0,
    kills = 0,
    lootAttempts = 0,

    targetX = nil,
    targetY = nil,
    targetZ = nil,
    targetId = nil,

    lastAttackAt = 0,
    attackXpBaseline = 0,

}

local worldTracker = {
    index = 0,
    cycleNumber = 1,
}

local P2P_WORLDS = {
    1, 2, 4, 5, 6, 9, 10, 12, 14, 15, 16, 21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32,
    35, 36, 37, 39, 40, 42, 44, 45, 46, 48, 49, 50, 51, 52, 53, 54, 56, 58, 59, 60, 62, 63,
    64, 65, 67, 68, 69, 70, 71, 72, 73, 74, 76, 77, 78, 79, 82, 83, 84, 85, 86, 87, 88, 89,
    91, 92, 96, 97, 98, 99, 100, 103, 104, 105, 106, 114, 116, 117, 119, 123, 124, 134,
    138, 139, 140, 252
}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function now()
    return os.time()
end

local function log(msg)
    print("[PATRIARCH] " .. tostring(msg))
end


local function maybeMicroPause()
    if math.random() <= CFG.MICRO_PAUSE_CHANCE then
        randomSleep((CFG.MICRO_PAUSE_MIN_MS + CFG.MICRO_PAUSE_MAX_MS) / 2)
    end
end

local function updateStatus()
    API.Write_ScripCuRunning0(string.format(
        "Patriarch Farmer | %s | K:%d H:%d E:%d | World %d/%d (Cycle #%d) | W:%d",
        rt.state, rt.kills, rt.worldHops, rt.emptyWorlds, worldTracker.index, #P2P_WORLDS, worldTracker.cycleNumber, rt.currentWorld
    ))
end


local function setState(newState)
    if rt.state ~= newState then
        rt.state = newState
        rt.stateStartedAt = now()
        log("State -> " .. newState)
        updateStatus()
    else
        rt.state = newState
    end
end

local function stateElapsed()
    return now() - rt.stateStartedAt
end

local function clearTarget()
    rt.targetX = nil
    rt.targetY = nil
    rt.targetZ = nil
    rt.targetId = nil
end

local function getSkillXpSafe(skill)
    local ok, xp = pcall(API.GetSkillXP, skill)
    if ok and type(xp) == "number" then
        return xp
    end
    return 0
end

local function getCombatXpTotal()
    return getSkillXpSafe("ATTACK")
        + getSkillXpSafe("STRENGTH")
        + getSkillXpSafe("DEFENCE")
        + getSkillXpSafe("RANGED")
        + getSkillXpSafe("MAGIC")
        + getSkillXpSafe("NECROMANCY")
        + getSkillXpSafe("CONSTITUTION")
end

local function toTileInt(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        return nil
    end
    if n >= 0 then
        return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
end

local function getNpcTile(npc)
    if not npc then
        return nil, nil, nil
    end
    if npc.Tile_XYZ and npc.Tile_XYZ.x and npc.Tile_XYZ.y then
        local tx = toTileInt(npc.Tile_XYZ.x)
        local ty = toTileInt(npc.Tile_XYZ.y)
        local tz = toTileInt(npc.Tile_XYZ.z or 0)
        return tx, ty, tz
    end
    if npc.TileX and npc.TileY then
        local tx = toTileInt((npc.TileX or 0) / 512)
        local ty = toTileInt((npc.TileY or 0) / 512)
        local tz = toTileInt((npc.TileZ or 0) / 512)
        return tx, ty, tz
    end
    return nil, nil, nil
end

local function getNearestNpc(list)
    if not list or #list == 0 then
        return nil
    end
    if #list == 1 then
        return list[1]
    end

    local player = API.PlayerCoordfloat()
    if not player then
        return list[1]
    end

    local nearest = list[1]
    local nearestDist = 999999
    for i = 1, #list do
        local npc = list[i]
        if npc and npc.Tile_XYZ then
            local d = API.Math_DistanceF(player, npc.Tile_XYZ)
            if d and d < nearestDist then
                nearestDist = d
                nearest = npc
            end
        end
    end
    return nearest
end

local function findPatriarch(scanDistance)
    local dist = scanDistance or CFG.NPC_SCAN_DISTANCE
    local npcsByName = API.GetAllObjArrayInteract_str(CFG.TARGET_NPC_NAMES, dist, { 1 })
    if npcsByName and #npcsByName > 0 then
        return getNearestNpc(npcsByName)
    end

    local npcsById = API.GetAllObjArrayInteract({ CFG.TARGET_NPC_ID }, dist, { 1 })
    if npcsById and #npcsById > 0 then
        return getNearestNpc(npcsById)
    end

    return nil
end

local function lockTarget(npc)
    local tx, ty, tz = getNpcTile(npc)
    if not (tx and ty and tz ~= nil) then
        return false
    end

    local p = API.PlayerCoord()
    if p and type(p.z) == "number" and tz ~= p.z then
        log(string.format("Adjusting target floor %d -> %d", tz, p.z))
        tz = p.z
    end

    rt.targetX = tx
    rt.targetY = ty
    rt.targetZ = tz
    rt.targetId = npc and npc.Id or CFG.TARGET_NPC_ID
    log(string.format("Target found @ (%d, %d, %d)", tx, ty, tz))
    return true
end

local function isPlayerNearTarget(range)
    if not (rt.targetX and rt.targetY and rt.targetZ ~= nil) then
        return false
    end
    local p = API.PlayerCoord()
    if not p then
        return false
    end
    return math.abs(p.x - rt.targetX) <= range
        and math.abs(p.y - rt.targetY) <= range
        and p.z == rt.targetZ
end

local function attackPatriarch()
    local okByName = Interact:NPC(CFG.TARGET_NPC_NAMES[1], "Attack", nil, CFG.ATTACK_DISTANCE)
    if okByName then
        return true
    end

    local okById = API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, { CFG.TARGET_NPC_ID }, CFG.ATTACK_DISTANCE)
    return okById == true
end

local function isKillComplete()
    local xpNow = getCombatXpTotal()
    if xpNow > rt.attackXpBaseline then
        return true, "xp"
    end

    local nearbyNpc = findPatriarch(CFG.NPC_NEARBY_DISTANCE)
    if not nearbyNpc then
        return true, "despawn"
    end

    return false, nil
end


-- ============================================================================
-- BUFF MANAGEMENT
-- ============================================================================

local function getBuff(buffId)
    local buff = API.Buffbar_GetIDstatus(buffId, false)
    return { found = buff.found, remaining = (buff.found and API.Bbar_ConvToSeconds(buff)) or 0 }
end

local function managePrayers()
    local prayer = API.GetPray_()

    -- Don't activate prayers if prayer is depleted
    if prayer == 0 then
        return
    end

    -- Check if Soul Split is already active via buff bar
    if GUI.config.enableSoulSplit then
        local soulSplitBuff = getBuff(26033)
        if not soulSplitBuff.found then
            API.DoAction_Ability("Soul Split", 1, API.OFF_ACT_GeneralInterface_route, false)
            randomSleep(300)
        end
    elseif GUI.config.enableProtectFromMelee then
        local protectBuff = getBuff(26012)
        local deflectBuff = getBuff(26040)
        if not protectBuff.found and not deflectBuff.found then
            -- Use Deflect Melee (curses) if available, otherwise Protect from Melee (prayer)
            if isUsingCurses() then
                API.DoAction_Ability("Deflect Melee", 1, API.OFF_ACT_GeneralInterface_route, false)
            else
                API.DoAction_Ability("Protect from Melee", 1, API.OFF_ACT_GeneralInterface_route, false)
            end
            randomSleep(300)
        end
    end
end

local function manageBuffs()
    local hp = API.GetHP_()
    local prayer = API.GetPray_()

    -- Activate prayers if configured
    managePrayers()

    -- Heal when HP drops below threshold
    if GUI.config.enableFood and hp < GUI.config.foodHealThreshold then
        if Inventory:Eat(GUI.config.foodName) then
            randomSleep(200)
            return
        end
    end

    -- Restore prayer if low
    if GUI.config.enablePrayerRestore and prayer > 0 and prayer < 100 then
        local itemId = API.GetItemSlotId(GUI.config.restoreName)
        if itemId and itemId ~= -1 then
            API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
            randomSleep(200)
            return
        end
    end
end

-- ============================================================================
-- WORLD HOPPING
-- ============================================================================

local INTERFACE_SETTINGS_SIZE = 1433
local INTERFACE_WORLDHOP_BUTTON = 1433
local INTERFACE_WORLDHOP_BUTTON_CHILD = 66
local INTERFACE_WORLDHOP_LIST = 1587

local function waitForCondition(timeoutSec, condFn)
    local started = now()
    while API.Read_LoopyLoop() and (now() - started) < timeoutSec do
        if condFn() then
            return true
        end
        randomSleep(220)
    end
    return condFn()
end

local function pickNextWorld()
    local currentWorld = API.GetWorldNR() or 0

    if GUI.config.randomizeWorldOrder then
        -- Random: pick any world except current
        local choices = {}
        for i = 1, #P2P_WORLDS do
            if P2P_WORLDS[i] ~= currentWorld then
                choices[#choices + 1] = P2P_WORLDS[i]
            end
        end
        if #choices == 0 then return nil end
        return choices[math.random(#choices)]
    end

    -- Sequential
    worldTracker.index = worldTracker.index + 1
    if worldTracker.index > #P2P_WORLDS then
        worldTracker.index = 1
        worldTracker.cycleNumber = worldTracker.cycleNumber + 1
        log("World cycle #" .. worldTracker.cycleNumber .. " complete, restarting")
    end

    -- Skip current world
    if P2P_WORLDS[worldTracker.index] == currentWorld then
        worldTracker.index = worldTracker.index + 1
        if worldTracker.index > #P2P_WORLDS then
            worldTracker.index = 1
            worldTracker.cycleNumber = worldTracker.cycleNumber + 1
        end
    end

    return P2P_WORLDS[worldTracker.index]
end

local function openWorldSelection()
    if isWorldSelectionOpen() then
        return true
    end

    -- Try WorldHop global if available
    if type(WorldHop) == "table" and type(WorldHop.Open) == "function" then
        local ok, opened = pcall(function() return WorldHop:Open() end)
        if ok and opened == true and waitForCondition(5, isWorldSelectionOpen) then
            return true
        end
    end

    -- Click settings button, retry once
    for attempt = 1, 2 do
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 568, 5, 7, API.OFF_ACT_GeneralInterface_route)
        if waitForCondition(4, function()
            return API.GetInterfaceOpenBySize(INTERFACE_SETTINGS_SIZE)
        end) then
            break
        end
        if attempt == 2 then return false end
        randomSleep(600)
    end

    -- Click world hop button, retry up to 3 times
    for _ = 1, 3 do
        randomSleep(2500)
        API.DoAction_Interface(
            0x24, 0xffffffff, 1,
            INTERFACE_WORLDHOP_BUTTON, INTERFACE_WORLDHOP_BUTTON_CHILD, -1,
            API.OFF_ACT_GeneralInterface_route
        )
        if waitForCondition(6, isWorldSelectionOpen) then
            return true
        end
    end
    return false
end

local function performWorldHop()
    local oldWorld = API.GetWorldNR() or rt.currentWorld
    local targetWorld = pickNextWorld()
    if not targetWorld or oldWorld == targetWorld then
        return false
    end

    randomSleep(1300)

    if not openWorldSelection() then
        log("Could not open world selection")
        return false
    end

    API.DoAction_Interface(
        0xffffffff, 0xffffffff, 1,
        INTERFACE_WORLDHOP_LIST, 10, targetWorld,
        API.OFF_ACT_GeneralInterface_route
    )

    local hopOk = waitForCondition(12, function()
        return API.GetWorldNR() == targetWorld or API.GetGameState2() ~= 3
    end)

    -- Always wait for game to fully load before checking result
    waitForCondition(15, function()
        return API.GetGameState2() == 3
    end)

    randomSleep(2400)

    local newWorld = API.GetWorldNR() or oldWorld
    rt.currentWorld = newWorld

    if newWorld ~= oldWorld then
        rt.worldHops = rt.worldHops + 1
        log(string.format("Hop %d -> %d", oldWorld, newWorld))
        return true
    end

    log("World hop failed (still on " .. oldWorld .. ")")
    return false
end

local function stopScript(reason)
    setState(STATE.STOPPED)
    log("Stopping: " .. tostring(reason))
    API.Write_ScripCuRunning0("Patriarch Farmer stopped: " .. tostring(reason))
    API.Write_LoopyLoop(false)
end

-- ============================================================================
-- GUI FUNCTIONS
-- ============================================================================

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function drawConfigTab()
    sectionHeader("Prayer Settings")
    flavorText("Configure which prayers to use during combat.")
    ImGui.Spacing()

    local soulChanged, newSoul = ImGui.Checkbox("Soul Split##soulSplitCheck", GUI.config.enableSoulSplit)
    if soulChanged and newSoul then
        GUI.config.enableSoulSplit = true
        GUI.config.enableProtectFromMelee = false
    elseif soulChanged and not newSoul then
        GUI.config.enableSoulSplit = false
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Enables Soul Split prayer during combat for automatic healing.")
    end

    ImGui.Spacing()

    local meleeChanged, newMelee = ImGui.Checkbox("Protect from Melee##meleeCheck", GUI.config.enableProtectFromMelee)
    if meleeChanged and newMelee then
        GUI.config.enableProtectFromMelee = true
        GUI.config.enableSoulSplit = false
    elseif meleeChanged and not newMelee then
        GUI.config.enableProtectFromMelee = false
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Enables Protect from Melee prayer to reduce incoming damage.")
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    sectionHeader("World Hop Settings")
    ImGui.Spacing()

    local randChanged, randVal = ImGui.Checkbox("Randomize world order##randWorlds", GUI.config.randomizeWorldOrder)
    if randChanged then GUI.config.randomizeWorldOrder = randVal end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Hop to worlds in random order instead of sequential.")
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    sectionHeader("Consumable Management")
    flavorText("Configure food and prayer restore items.")
    ImGui.Spacing()

    local foodChanged, foodVal = ImGui.Checkbox("Enable Food##enableFood", GUI.config.enableFood)
    if foodChanged then GUI.config.enableFood = foodVal end

    if GUI.config.enableFood then
        ImGui.Text("Food Name:")
        local foodNameChanged, foodNameVal = ImGui.InputText("##foodName", GUI.config.foodName, 32)
        if foodNameChanged then GUI.config.foodName = foodNameVal end

        ImGui.Text("Heal Threshold (HP):")
        local thresholdChanged, thresholdVal = ImGui.SliderInt("##foodThreshold", GUI.config.foodHealThreshold, 500, 12000)
        if thresholdChanged then GUI.config.foodHealThreshold = thresholdVal end
    end

    ImGui.Spacing()

    local restoreChanged, restoreVal = ImGui.Checkbox("Enable Prayer Restore##enableRestore", GUI.config.enablePrayerRestore)
    if restoreChanged then GUI.config.enablePrayerRestore = restoreVal end

    if GUI.config.enablePrayerRestore then
        ImGui.Text("Restore Potion Name:")
        local restoreNameChanged, restoreNameVal = ImGui.InputText("##restoreName", GUI.config.restoreName, 32)
        if restoreNameChanged then GUI.config.restoreName = restoreNameVal end
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, THEME.bright[1], THEME.bright[2], THEME.bright[3], 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, THEME.glow[1], THEME.glow[2], THEME.glow[3], 0.8)
    if ImGui.Button("Start Script##start", 120, 32) then
        GUI.started = true
    end
    ImGui.PopStyleColor(3)

    ImGui.SameLine()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.45, 0.25, 0.15, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.55, 0.32, 0.20, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.65, 0.40, 0.25, 1.0)
    if ImGui.Button("Stop Script##stop", 120, 32) then
        GUI.started = false
    end
    ImGui.PopStyleColor(3)
end

local function drawInfoTab()
    local statusText = GUI.started and "Running" or "Stopped"
    local statusColor = GUI.started and THEME.glow or THEME.light
    ImGui.PushStyleColor(ImGuiCol.Text, statusColor[1], statusColor[2], statusColor[3], 1.0)
    ImGui.TextWrapped("Status: " .. statusText)
    ImGui.PopStyleColor(1)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    sectionHeader("Current Settings")
    flavorText("View your active configuration.")
    ImGui.Spacing()

    if ImGui.BeginTable("##currsets", 2) then
        ImGui.TableSetupColumn("Setting", ImGuiTableColumnFlags.WidthStretch, 0.5)
        ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.5)

        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.TextWrapped("Soul Split")
        ImGui.TableNextColumn()
        ImGui.TextWrapped(GUI.config.enableSoulSplit and "Enabled" or "Disabled")

        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.TextWrapped("Protect from Melee")
        ImGui.TableNextColumn()
        ImGui.TextWrapped(GUI.config.enableProtectFromMelee and "Enabled" or "Disabled")

        ImGui.EndTable()
    end
end

local function drawGUI()
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, THEME.dark[1], THEME.dark[2], THEME.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, THEME.medium[1] * 0.6, THEME.medium[2] * 0.6, THEME.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, THEME.medium[1], THEME.medium[2], THEME.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, THEME.light[1], THEME.light[2], THEME.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, THEME.medium[1], THEME.medium[2], THEME.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, THEME.medium[1] * 0.5, THEME.medium[2] * 0.5, THEME.medium[3] * 0.5, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, THEME.light[1] * 0.7, THEME.light[2] * 0.7, THEME.light[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, THEME.bright[1] * 0.5, THEME.bright[2] * 0.5, THEME.bright[3] * 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, THEME.medium[1], THEME.medium[2], THEME.medium[3], 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Button, THEME.medium[1], THEME.medium[2], THEME.medium[3], 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local visible = ImGui.Begin("Patriarch Farmer###PatriarchGUI", true)

    if visible then
        local ok, err = pcall(function()
            if ImGui.BeginTabBar("##maintabs", 0) then
                local configFlags = GUI.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
                GUI.selectConfigTab = false

                if ImGui.BeginTabItem("Config###config", nil, configFlags) then
                    ImGui.Spacing()
                    drawConfigTab()
                    ImGui.EndTabItem()
                end

                if ImGui.BeginTabItem("Info###info", nil, GUI.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0) then
                    GUI.selectInfoTab = false
                    ImGui.Spacing()
                    drawInfoTab()
                    ImGui.EndTabItem()
                end

                ImGui.EndTabBar()
            end
        end)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(20)
    ImGui.End()
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

if type(DrawImGui) == "function" then
    DrawImGui(function()
        drawGUI()
    end)
end

API.Write_LoopyLoop(true)
log("Starting Patriarch Farmer")
updateStatus()

while API.Read_LoopyLoop() do
    if not GUI.started then
        randomSleep(150)
    else
    if rt.state == STATE.SCAN_PATRIARCH then
        log("Scanning for Patriarch...")
        local npc = findPatriarch(CFG.NPC_SCAN_DISTANCE)
        if npc and lockTarget(npc) then
            log("Patriarch found! Traveling to target...")
            setState(STATE.MOVE_TO_TARGET)
        else
            log("Patriarch not found, hopping...")
            rt.emptyWorlds = rt.emptyWorlds + 1
            clearTarget()
            setState(STATE.WORLD_HOP)
        end

    elseif rt.state == STATE.MOVE_TO_TARGET then
        if stateElapsed() > CFG.MOVE_TIMEOUT_SEC then
            log("Move timeout, hopping worlds")
            clearTarget()
            setState(STATE.WORLD_HOP)
        elseif not (rt.targetX and rt.targetY and rt.targetZ ~= nil) then
            setState(STATE.SCAN_PATRIARCH)
        elseif isPlayerNearTarget(CFG.MOVE_PROXIMITY) then
            log("Reached Patriarch! Attacking...")
            setState(STATE.ATTACK_TARGET)
        else
            local moved = Slib:MoveTo(rt.targetX, rt.targetY, rt.targetZ)
            if moved then
                setState(STATE.ATTACK_TARGET)
            else
                log("Move failed, hopping worlds")
                clearTarget()
                setState(STATE.WORLD_HOP)
            end
        end

    elseif rt.state == STATE.ATTACK_TARGET then
        if stateElapsed() > CFG.ATTACK_TIMEOUT_SEC then
            log("Attack timeout, rescan")
            setState(STATE.SCAN_PATRIARCH)
        elseif (now() - rt.lastAttackAt) < CFG.ATTACK_COOLDOWN_SEC then
            manageBuffs()
            randomSleep(275)
        else
            local attackSent = attackPatriarch()
            rt.lastAttackAt = now()
            if attackSent then
                rt.attackXpBaseline = getCombatXpTotal()
                randomSleep((CFG.POST_ATTACK_DELAY_MIN_MS + CFG.POST_ATTACK_DELAY_MAX_MS) / 2)
                setState(STATE.WAIT_KILL_COMPLETE)
            else
                setState(STATE.SCAN_PATRIARCH)
            end
        end

    elseif rt.state == STATE.WAIT_KILL_COMPLETE then
        if stateElapsed() > CFG.KILL_TIMEOUT_SEC then
            log("Kill timeout, proceeding to loot/hop")
            setState(STATE.LOOT_ALL)
        else
            local done, reason = isKillComplete()
            if done then
                rt.kills = rt.kills + 1
                log("Kill complete (" .. tostring(reason) .. ")")
                setState(STATE.LOOT_ALL)
            else
                manageBuffs()
                randomSleep(335)
            end
        end

    elseif rt.state == STATE.LOOT_ALL then
        if stateElapsed() > CFG.LOOT_TIMEOUT_SEC then
            log("Loot timeout, hopping")
            setState(STATE.WORLD_HOP)
        else
            rt.lootAttempts = rt.lootAttempts + 1
            randomSleep((CFG.PRE_LOOT_DELAY_MIN_MS + CFG.PRE_LOOT_DELAY_MAX_MS) / 2)
            local opened = Slib:AreaLootOpen()
            if opened then
                randomSleep((CFG.POST_LOOT_DELAY_MIN_MS + CFG.POST_LOOT_DELAY_MAX_MS) / 2)
                Slib:AreaLootTakeItems("all")
                randomSleep((CFG.POST_LOOT_DELAY_MIN_MS + CFG.POST_LOOT_DELAY_MAX_MS) / 2)
                log("Loot taken")
                setState(STATE.WORLD_HOP)
            else
                log("Area loot window not open, retrying...")
                randomSleep(500)
            end
        end

    elseif rt.state == STATE.WORLD_HOP then
        -- Wait until out of combat before hopping
        if API.LocalPlayer_IsInCombat_() then
            manageBuffs()
            randomSleep(335)
        else
            local okHop = performWorldHop()
            if not okHop then
                -- Wait before retrying on next loop tick
                randomSleep(1300)
            else
                clearTarget()
                setState(STATE.SCAN_PATRIARCH)
            end
        end

    elseif rt.state == STATE.STOPPED then
        break

    else
        stopScript("Unknown state: " .. tostring(rt.state))
        break
    end

    maybeMicroPause()
    randomSleep((CFG.LOOP_DELAY_MIN_MS + CFG.LOOP_DELAY_MAX_MS) / 2)
    end
end

local runtime = now() - rt.startedAt
log(string.format("Script ended | Runtime:%ds Kills:%d Hops:%d EmptyWorlds:%d Loot:%d",
    runtime, rt.kills, rt.worldHops, rt.emptyWorlds, rt.lootAttempts))
