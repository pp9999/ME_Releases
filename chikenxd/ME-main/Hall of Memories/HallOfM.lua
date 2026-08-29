ScriptName = "@ HallOfM" -- luacheck: ignore
Author = "matthew" -- luacheck: ignore
ScriptVersion = "9.0.0"
ReleaseDate = "05-10-2026" -- luacheck: ignore
--[[
    Hall of Memories Divination script.
]]

local API = require("api")

local LOG_PREFIX = "[HOM] "
local SKILL = "DIVINATION"

local ID = {
    AAGI = 25551,
    SEREN = 25552,
    JUNA = 25553,
    SWORD_OF_EDICTS = 25554,
    CRES = 25555,
    KNOWLEDGE_FRAGMENT = 25564,
    EMPTY_JAR = 42898,
    PARTIAL_JAR = 42899,
    FULL_JAR = 42900,
    JAR_OBJECT = 111374,
    DEPOSIT_OBJECT = 111375,
    JAR_GRAB_ANIM = 24909,
    HARVEST_ANIM = 31889,
}

local CONFIG = {
    memoryOptions = {
        "Faded memories",
        "Lustrous memories",
        "Brilliant memories",
        "Radiant memories",
        "Luminous memories",
        "Incandescent memories",
    },
    selectedMemoryIndex = 5,
    twoTickMode = false,
    enableWorldHopping = false,
    worldHopMinMinutes = 7,
    worldHopMaxMinutes = 15,
    actionCooldownMs = 1000,
    xpReclickSkipChance = 20,
    xpReclickStationaryMs = 1200,
    xpReclickMinGapMs = 400,
    loopDelayCenterMs = 220,
    loopDelaySpreadMs = 80,
    clickDelayCenterMs = 650,
    clickDelaySpreadMs = 220,
    jarTravelDelayCenterMs = 900,
    jarTravelDelaySpreadMs = 240,
    interMemoryDelayMinMs = 2000,
    interMemoryDelayMaxMs = 7000,
}

local THEME = {
    dark = { 0.09, 0.02, 0.12 },
    medium = { 0.20, 0.05, 0.28 },
    light = { 0.42, 0.10, 0.55 },
    bright = { 0.76, 0.18, 0.82 },
    glow = { 1.00, 0.42, 0.92 },
    accent = { 0.95, 0.24, 0.58 },
    text = { 1.00, 0.94, 1.00 },
    muted = { 0.78, 0.62, 0.82 },
    success = { 0.45, 0.90, 0.62 },
    warning = { 1.00, 0.78, 0.35 },
    danger = { 0.88, 0.20, 0.34 },
}

local RUNTIME = {
    running = false,
    paused = false,
    stopRequested = false,
    status = "Choose a memory type, then start",
    currentAction = "Idle",
    selectedMemoryName = CONFIG.memoryOptions[CONFIG.selectedMemoryIndex + 1],
    startTime = 0,
    runtimeText = "00:00:00",
    startXp = 0,
    currentXp = 0,
    lastXp = 0,
    lastXpTime = 0,
    totalXp = 0,
    xpPerHour = 0,
    xpTotalText = "0",
    xpPerHourText = "0",
    level = 0,
    progressPercent = 0,
    ttlLevelText = "--",
    ttl99Text = "--",
    emptyJars = 0,
    partialJars = 0,
    fullJars = 0,
    currentTargetType = "memory",
    currentTarget = nil,
    lastActionMs = 0,
    nextFillAttemptAtMs = 0,
    lastMemoryFinishMs = 0,
    wasHarvestingMemory = false,
    lastDivXp = 0,
    lastXpDropMs = 0,
    lastReclickMs = 0,
    lastPosX = nil,
    lastPosY = nil,
    lastPosChangeMs = 0,
    currentWorld = 0,
    nextHopAt = 0,
    nextHopLabel = "Disabled",
    worldHopPending = false,
    worldHopInProgress = false,
    worldHopFailures = 0,
    worldHopsCompleted = 0,
    lastHopInfo = "None",
    guiOpen = true,
}

local CORE_NPCS = {
    ID.AAGI,
    ID.SEREN,
    ID.JUNA,
    ID.SWORD_OF_EDICTS,
    ID.CRES,
    ID.KNOWLEDGE_FRAGMENT,
}

math.randomseed((os.time() + math.floor(os.clock() * 1000)) % 2147483647)

local function logInfo(message)
    print(LOG_PREFIX .. tostring(message))
end

local function nowMs()
    if API and type(API.ScriptRuntime) == "function" then
        return math.floor((API.ScriptRuntime() or 0) * 1000)
    end
    return math.floor(os.clock() * 1000)
end

local function delay(center, spread)
    local wait = center or CONFIG.loopDelayCenterMs
    local variance = spread or CONFIG.loopDelaySpreadMs
    API.RandomSleep2(wait, math.floor(variance * 0.5), math.max(20, variance))
end

local function setStatus(status, action)
    RUNTIME.status = tostring(status or "Idle")
    if action then
        RUNTIME.currentAction = tostring(action)
    end
end

local function formatNumber(value)
    local number = math.floor(tonumber(value) or 0)
    local formatted = tostring(number)
    while true do
        local updated, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        formatted = updated
        if count == 0 then
            break
        end
    end
    return formatted
end

local function formatRuntime(startTime)
    if not startTime or startTime <= 0 then
        return "00:00:00"
    end
    local elapsed = math.max(0, os.time() - startTime)
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local function formatMinutes(minutes)
    if not minutes or minutes <= 0 then
        return "--"
    end
    if minutes >= 60 then
        return string.format("%.1fh", minutes / 60)
    end
    return tostring(math.floor(minutes + 0.5)) .. "m"
end

local function formatCountdown(seconds)
    local remaining = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
end

local function getDivinationXp()
    return tonumber(API.GetSkillXP(SKILL)) or 0
end

local function getCurrentWorld()
    if API and type(API.GetWorldNR) == "function" then
        return tonumber(API.GetWorldNR()) or 0
    end
    if WorldHop and type(WorldHop.GetCurrentWorld) == "function" then
        return tonumber(WorldHop:GetCurrentWorld()) or 0
    end
    return 0
end

local function getInventoryAmount(itemId)
    if Inventory and type(Inventory.GetItemAmount) == "function" then
        return tonumber(Inventory:GetItemAmount(itemId)) or 0
    end
    return 0
end

local function isInventoryFull()
    return Inventory and type(Inventory.IsFull) == "function" and Inventory:IsFull() == true
end

local function updateJarCounts()
    RUNTIME.emptyJars = getInventoryAmount(ID.EMPTY_JAR)
    RUNTIME.partialJars = getInventoryAmount(ID.PARTIAL_JAR)
    RUNTIME.fullJars = getInventoryAmount(ID.FULL_JAR)
end

local function updateRuntimeStats()
    updateJarCounts()
    RUNTIME.runtimeText = formatRuntime(RUNTIME.startTime)
    RUNTIME.currentWorld = getCurrentWorld()
    RUNTIME.currentXp = getDivinationXp()
    RUNTIME.totalXp = math.max(0, RUNTIME.currentXp - (RUNTIME.startXp or RUNTIME.currentXp))
    RUNTIME.xpTotalText = formatNumber(RUNTIME.totalXp)

    local elapsedSeconds = 0
    if RUNTIME.startTime and RUNTIME.startTime > 0 then
        elapsedSeconds = math.max(1, os.time() - RUNTIME.startTime)
        RUNTIME.xpPerHour = math.floor((RUNTIME.totalXp * 3600) / elapsedSeconds)
    else
        RUNTIME.xpPerHour = 0
    end
    RUNTIME.xpPerHourText = formatNumber(RUNTIME.xpPerHour)

    RUNTIME.level = tonumber(API.XPLevelTable(RUNTIME.currentXp)) or 0
    local currentLevelXp = tonumber(API.XPForLevel(RUNTIME.level)) or RUNTIME.currentXp
    local nextLevelXp = tonumber(API.XPForLevel(RUNTIME.level + 1)) or currentLevelXp
    local levelSpan = nextLevelXp - currentLevelXp
    if levelSpan > 0 then
        RUNTIME.progressPercent = math.floor(math.max(0, math.min(100, ((RUNTIME.currentXp - currentLevelXp) / levelSpan) * 100)))
    else
        RUNTIME.progressPercent = 100
    end

    if RUNTIME.xpPerHour > 0 then
        RUNTIME.ttlLevelText = formatMinutes(((nextLevelXp - RUNTIME.currentXp) / RUNTIME.xpPerHour) * 60)
        RUNTIME.ttl99Text = formatMinutes((((tonumber(API.XPForLevel(99)) or RUNTIME.currentXp) - RUNTIME.currentXp) / RUNTIME.xpPerHour) * 60)
    else
        RUNTIME.ttlLevelText = "--"
        RUNTIME.ttl99Text = "--"
    end
end

local function normalizeWorldHopMinutes()
    local minMinutes = math.max(1, math.floor(tonumber(CONFIG.worldHopMinMinutes) or 7))
    local maxMinutes = math.max(1, math.floor(tonumber(CONFIG.worldHopMaxMinutes) or minMinutes))
    if maxMinutes < minMinutes then
        maxMinutes = minMinutes
    end
    CONFIG.worldHopMinMinutes = minMinutes
    CONFIG.worldHopMaxMinutes = maxMinutes
    return minMinutes, maxMinutes
end

local function scheduleNextWorldHop()
    if CONFIG.enableWorldHopping ~= true then
        RUNTIME.nextHopAt = 0
        RUNTIME.nextHopLabel = "Disabled"
        RUNTIME.worldHopPending = false
        return
    end

    local minMinutes, maxMinutes = normalizeWorldHopMinutes()
    RUNTIME.nextHopAt = os.time() + (math.random(minMinutes, maxMinutes) * 60)
    RUNTIME.nextHopLabel = formatCountdown(RUNTIME.nextHopAt - os.time())
    RUNTIME.worldHopPending = false
end

local function updateWorldHopSchedule()
    if CONFIG.enableWorldHopping ~= true then
        RUNTIME.nextHopAt = 0
        RUNTIME.nextHopLabel = "Disabled"
        RUNTIME.worldHopPending = false
        return
    end

    if RUNTIME.nextHopAt <= 0 then
        scheduleNextWorldHop()
        return
    end

    local remaining = RUNTIME.nextHopAt - os.time()
    if remaining <= 0 then
        RUNTIME.worldHopPending = true
        RUNTIME.nextHopLabel = "Pending"
    elseif RUNTIME.worldHopPending ~= true then
        RUNTIME.nextHopLabel = formatCountdown(remaining)
    end
end

local function selectedMemoryName()
    return CONFIG.memoryOptions[(CONFIG.selectedMemoryIndex or 0) + 1] or CONFIG.memoryOptions[1]
end

local function isMovementAnimation(anim)
    return anim == 1 or anim == 2 or anim == 3 or anim == 4 or anim == 5 or anim == 819 or anim == 824
end

local function getPlayerAnim()
    return tonumber(API.ReadPlayerAnim and API.ReadPlayerAnim()) or 0
end

local function isHarvestingMemory()
    return getPlayerAnim() == ID.HARVEST_ANIM
end

local function isGrabbingJars()
    return getPlayerAnim() == ID.JAR_GRAB_ANIM
end

local function playerIsMoving()
    if API.ReadPlayerMovin2 and API.ReadPlayerMovin2() then
        return true
    end
    return isMovementAnimation(getPlayerAnim())
end

local function findNpc(id, dist)
    local objs = API.GetAllObjArray1({ id }, dist or 25, { 1 })
    return type(objs) == "table" and #objs > 0
end

local function findCoreNpc()
    for _, npcId in ipairs(CORE_NPCS) do
        if findNpc(npcId, 75) then
            return npcId
        end
    end
    return nil
end

local function randomTileAround(baseX, baseY, radius)
    local dx = math.random(-radius, radius)
    local dy = math.random(-radius, radius)
    return WPOINT.new(baseX + dx, baseY + dy, 0)
end

local function waitForResponse(timeoutMs, condition)
    local started = nowMs()
    while API.Read_LoopyLoop() and (nowMs() - started) < timeoutMs do
        if condition() then
            return true
        end
        delay(120, 35)
    end
    return condition()
end

local function waitForInventoryChange(timeoutMs, beforeValue, currentValueFn)
    return waitForResponse(timeoutMs, function()
        return currentValueFn() ~= beforeValue
    end)
end

local function waitForJarGrabToSettle()
    if API.WaitUntilMovingEnds then
        API.WaitUntilMovingEnds(10, 20)
    end

    local started = waitForResponse(1600, function()
        return isGrabbingJars()
    end)
    if not started then
        return
    end

    waitForResponse(6500, function()
        return not isGrabbingJars()
    end)
end

local function waitForDepositToSettle()
    if API.WaitUntilMovingandAnimEnds then
        API.WaitUntilMovingandAnimEnds(12, 10)
    elseif API.WaitUntilMovingEnds then
        API.WaitUntilMovingEnds(12, 10)
    end
end

local function updateMemoryFinishTracker()
    local harvesting = isHarvestingMemory()
    if RUNTIME.wasHarvestingMemory and not harvesting then
        RUNTIME.lastMemoryFinishMs = nowMs()
    end
    RUNTIME.wasHarvestingMemory = harvesting
end

local function safeToWorldHop()
    if RUNTIME.worldHopInProgress == true then
        return false
    end
    if (nowMs() - RUNTIME.lastActionMs) < CONFIG.actionCooldownMs then
        return false
    end
    if playerIsMoving() then
        return false
    end
    local anim = getPlayerAnim()
    return anim == 0
end

local function confirmWorldHop(worldBefore, targetWorld)
    return waitForResponse(20000, function()
        local worldNow = getCurrentWorld()
        if targetWorld and tonumber(targetWorld) and tonumber(targetWorld) > 0 then
            return worldNow == tonumber(targetWorld)
        end
        return worldNow > 0 and worldNow ~= tonumber(worldBefore)
    end)
end

local function hopWorldIfNeeded()
    if CONFIG.enableWorldHopping ~= true or RUNTIME.worldHopPending ~= true then
        return false
    end

    if not safeToWorldHop() then
        RUNTIME.nextHopLabel = "Waiting for idle"
        return false
    end

    if not (WorldHop and type(WorldHop.GetRandomWorld) == "function" and type(WorldHop.Hop) == "function") then
        RUNTIME.worldHopPending = false
        RUNTIME.worldHopFailures = RUNTIME.worldHopFailures + 1
        RUNTIME.nextHopAt = os.time() + 60
        RUNTIME.nextHopLabel = "WorldHop API missing"
        RUNTIME.lastHopInfo = "WorldHop API unavailable"
        return false
    end

    local worldBefore = getCurrentWorld()
    local targetWorld = WorldHop:GetRandomWorld(true)
    if not targetWorld or tonumber(targetWorld) == tonumber(worldBefore) then
        targetWorld = WorldHop:GetRandomWorld(true)
    end

    RUNTIME.worldHopInProgress = true
    setStatus("World hop in progress", "World hopping")

    WorldHop:Hop(targetWorld)
    local confirmed = confirmWorldHop(worldBefore, targetWorld)
    RUNTIME.worldHopInProgress = false
    RUNTIME.worldHopPending = false

    if confirmed then
        RUNTIME.currentWorld = getCurrentWorld()
        RUNTIME.worldHopFailures = 0
        RUNTIME.worldHopsCompleted = RUNTIME.worldHopsCompleted + 1
        RUNTIME.lastHopInfo = string.format("W%s -> W%s", tostring(worldBefore), tostring(RUNTIME.currentWorld))
        scheduleNextWorldHop()
        setStatus("World hop complete", "Post-hop settling")
        delay(1200, 300)
        return true
    end

    RUNTIME.worldHopFailures = RUNTIME.worldHopFailures + 1
    RUNTIME.nextHopAt = os.time() + 60
    RUNTIME.nextHopLabel = "Retry in 01:00"
    RUNTIME.lastHopInfo = "Hop failed from W" .. tostring(worldBefore)
    setStatus("World hop failed; retry scheduled", "Waiting")
    return false
end

local function updatePositionTracker()
    local p = API.PlayerCoordfloat and API.PlayerCoordfloat() or nil
    if not p or not p.x or not p.y then
        return
    end

    local currentMs = nowMs()
    if RUNTIME.lastPosX == nil or RUNTIME.lastPosY == nil then
        RUNTIME.lastPosX = p.x
        RUNTIME.lastPosY = p.y
        RUNTIME.lastPosChangeMs = currentMs
        return
    end

    if p.x ~= RUNTIME.lastPosX or p.y ~= RUNTIME.lastPosY then
        RUNTIME.lastPosX = p.x
        RUNTIME.lastPosY = p.y
        RUNTIME.lastPosChangeMs = currentMs
    end
end

local function startScript()
    RUNTIME.running = true
    RUNTIME.paused = false
    RUNTIME.stopRequested = false
    RUNTIME.selectedMemoryName = selectedMemoryName()
    RUNTIME.startTime = os.time()
    RUNTIME.startXp = getDivinationXp()
    RUNTIME.currentXp = RUNTIME.startXp
    RUNTIME.lastXp = RUNTIME.startXp
    RUNTIME.lastDivXp = RUNTIME.startXp
    RUNTIME.lastXpTime = os.time()
    RUNTIME.lastActionMs = 0
    RUNTIME.nextFillAttemptAtMs = 0
    RUNTIME.lastMemoryFinishMs = 0
    RUNTIME.lastReclickMs = 0
    RUNTIME.lastXpDropMs = 0
    RUNTIME.currentWorld = getCurrentWorld()
    RUNTIME.worldHopFailures = 0
    RUNTIME.worldHopsCompleted = 0
    RUNTIME.lastHopInfo = "None"
    scheduleNextWorldHop()
    setStatus("Running " .. RUNTIME.selectedMemoryName, "Starting")
    logInfo("Started: " .. RUNTIME.selectedMemoryName)
end

local function pauseScript()
    RUNTIME.running = false
    RUNTIME.paused = true
    setStatus("Paused", "Paused")
end

local function resumeScript()
    RUNTIME.running = true
    RUNTIME.paused = false
    setStatus("Running " .. selectedMemoryName(), "Resuming")
end

local function stopScript(reason)
    RUNTIME.running = false
    RUNTIME.paused = false
    RUNTIME.stopRequested = true
    setStatus(reason or "Stopped", "Stopped")
    API.Write_LoopyLoop(false)
end

local function drawStat(label, value)
    ImGui.Text(label)
    ImGui.SameLine()
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.accent[1], THEME.accent[2], THEME.accent[3], 1.0)
    ImGui.TextWrapped(tostring(value))
    ImGui.PopStyleColor(1)
end

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.muted[1], THEME.muted[2], THEME.muted[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function pushTheme()
    ImGui.PushStyleColor(ImGuiCol.WindowBg, THEME.dark[1], THEME.dark[2], THEME.dark[3], 0.98)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, THEME.medium[1] * 0.65, THEME.medium[2] * 0.65, THEME.medium[3] * 0.65, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, THEME.medium[1], THEME.medium[2], THEME.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, THEME.light[1], THEME.light[2], THEME.light[3], 0.55)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, THEME.medium[1], THEME.medium[2], THEME.medium[3], 0.92)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, THEME.light[1], THEME.light[2], THEME.light[3], 0.95)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Button, THEME.medium[1], THEME.medium[2], THEME.medium[3], 0.92)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, THEME.medium[1], THEME.medium[2], THEME.medium[3], 0.90)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.PopupBg, THEME.dark[1], THEME.dark[2], THEME.dark[3], 0.99)
    ImGui.PushStyleColor(ImGuiCol.Border, THEME.glow[1], THEME.glow[2], THEME.glow[3], 0.35)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.text[1], THEME.text[2], THEME.text[3], 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 12)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)

    return 17, 4
end

local function drawMainTab()
    sectionHeader("Hall of Memories")
    ImGui.Spacing()

    local changed, selected = ImGui.Combo("Memory##hall_memory_type", CONFIG.selectedMemoryIndex, CONFIG.memoryOptions, #CONFIG.memoryOptions)
    if changed and not RUNTIME.running then
        CONFIG.selectedMemoryIndex = selected
        RUNTIME.selectedMemoryName = selectedMemoryName()
    end

    local twoTickChanged, twoTickValue = ImGui.Checkbox("2-tick mode##hall_two_tick_mode", CONFIG.twoTickMode)
    if twoTickChanged then
        CONFIG.twoTickMode = twoTickValue == true
        RUNTIME.lastDivXp = getDivinationXp()
        RUNTIME.lastReclickMs = nowMs()
        if CONFIG.twoTickMode then
            setStatus("2-tick mode enabled", "Config")
        else
            setStatus("2-tick mode disabled; no XP-drop re-clicks", "Config")
        end
    end

    ImGui.Spacing()
    sectionHeader("Summary")
    drawStat("Status:", RUNTIME.status)
    drawStat("Action:", RUNTIME.currentAction)
    drawStat("Memory:", RUNTIME.selectedMemoryName)
    drawStat("2-tick:", CONFIG.twoTickMode and "On" or "Off")
    drawStat("Runtime:", RUNTIME.runtimeText)
    drawStat("XP gained:", RUNTIME.xpTotalText)
    drawStat("XP/hr:", RUNTIME.xpPerHourText)

    ImGui.Spacing()
    sectionHeader("Controls")
    if not RUNTIME.running and not RUNTIME.paused then
        if ImGui.Button("Start##hall_start", -1, 28) then
            startScript()
        end
    elseif RUNTIME.paused then
        if ImGui.Button("Resume##hall_resume", -1, 28) then
            resumeScript()
        end
    else
        if ImGui.Button("Pause##hall_pause", -1, 28) then
            pauseScript()
        end
    end

    if ImGui.Button("Stop##hall_stop", -1, 26) then
        stopScript("Stopped by user")
    end
end

local function drawRuntimeTab()
    sectionHeader("Runtime")
    drawStat("Status:", RUNTIME.status)
    drawStat("Action:", RUNTIME.currentAction)
    drawStat("Memory:", RUNTIME.selectedMemoryName)
    drawStat("Runtime:", RUNTIME.runtimeText)
    drawStat("Level:", tostring(RUNTIME.level) .. " (" .. tostring(RUNTIME.progressPercent) .. "%)")
    drawStat("XP gained:", RUNTIME.xpTotalText)
    drawStat("XP/hr:", RUNTIME.xpPerHourText)
    drawStat("TTL:", RUNTIME.ttlLevelText)
    drawStat("TTL 99:", RUNTIME.ttl99Text)
    drawStat("Jars:", string.format("empty %d / partial %d / full %d", RUNTIME.emptyJars, RUNTIME.partialJars, RUNTIME.fullJars))
    drawStat("Target:", tostring(RUNTIME.currentTargetType) .. " " .. tostring(RUNTIME.currentTarget or "none"))
    drawStat("Last hop:", RUNTIME.lastHopInfo)
end

local function drawWorldHopTab()
    sectionHeader("World Hopping")
    local changed, enabled = ImGui.Checkbox("Enable world hopping##hall_worldhop_enabled", CONFIG.enableWorldHopping)
    if changed then
        CONFIG.enableWorldHopping = enabled == true
        scheduleNextWorldHop()
    end

    local minChanged, minValue = ImGui.SliderInt("Hop min minutes##hall_worldhop_min", CONFIG.worldHopMinMinutes, 1, 240)
    if minChanged then
        CONFIG.worldHopMinMinutes = math.max(1, tonumber(minValue) or CONFIG.worldHopMinMinutes)
        normalizeWorldHopMinutes()
        scheduleNextWorldHop()
    end

    local maxChanged, maxValue = ImGui.SliderInt("Hop max minutes##hall_worldhop_max", CONFIG.worldHopMaxMinutes, 1, 240)
    if maxChanged then
        CONFIG.worldHopMaxMinutes = math.max(1, tonumber(maxValue) or CONFIG.worldHopMaxMinutes)
        normalizeWorldHopMinutes()
        scheduleNextWorldHop()
    end

    ImGui.Spacing()
    drawStat("Current world:", tostring(RUNTIME.currentWorld))
    drawStat("Next hop:", RUNTIME.nextHopLabel)
    drawStat("Hops completed:", tostring(RUNTIME.worldHopsCompleted))
    drawStat("Failures:", tostring(RUNTIME.worldHopFailures))
    drawStat("Last hop:", RUNTIME.lastHopInfo)
end

local function drawGui()
    if type(ImGui) ~= "table" or type(ImGui.Begin) ~= "function" then
        return
    end

    updateRuntimeStats()

    if type(ImGuiCond) ~= "nil" and type(ImGui.SetNextWindowSize) == "function" then
        ImGui.SetNextWindowSize(460, 475, ImGuiCond.FirstUseEver)
    end

    local colorCount, styleCount = pushTheme()
    local visible = ImGui.Begin("HOM###hall_of_memories", RUNTIME.guiOpen, 0)
    if visible then
        if ImGui.BeginTabBar("##hall_tabs", 0) then
            if ImGui.BeginTabItem("Main##hall_tab_main", nil, 0) then
                drawMainTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Runtime##hall_tab_runtime", nil, 0) then
                drawRuntimeTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("World Hopping##hall_tab_world_hopping", nil, 0) then
                drawWorldHopTab()
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end
    end
    ImGui.End()
    ImGui.PopStyleVar(styleCount)
    ImGui.PopStyleColor(colorCount)
end

local function registerGui()
    if type(DrawImGui) ~= "function" then
        logInfo("DrawImGui unavailable; GUI not registered")
        return false
    end
    if type(ClearRender) == "function" then
        pcall(ClearRender)
    end
    DrawImGui(function()
        drawGui()
    end)
    return true
end

local function clickMemory()
    if isHarvestingMemory() then
        setStatus("Already harvesting memory", "Harvesting")
        return false
    end

    if playerIsMoving() then
        return false
    end

    RUNTIME.currentTargetType = "memory"
    RUNTIME.currentTarget = RUNTIME.selectedMemoryName
    setStatus("Clicking memory", "Fill jars")

    API.DoAction_NPC_str(0xc8, API.OFF_ACT_InteractNPC_route, { RUNTIME.selectedMemoryName }, 74)
    RUNTIME.lastActionMs = nowMs()

    local confirmed = waitForResponse(2500, function()
        return playerIsMoving() or getPlayerAnim() ~= 0
    end)
    if confirmed and API.WaitUntilMovingandAnimEnds then
        API.WaitUntilMovingandAnimEnds(6, 8)
    end
    return confirmed
end

local function handleXpDropReclick()
    local currentMs = nowMs()
    local currentXp = getDivinationXp()
    if currentXp <= RUNTIME.lastDivXp then
        return false
    end

    RUNTIME.lastDivXp = currentXp
    RUNTIME.lastXp = currentXp
    RUNTIME.lastXpTime = os.time()
    RUNTIME.lastXpDropMs = currentMs

    if not CONFIG.twoTickMode then
        return false
    end

    if (currentMs - RUNTIME.lastActionMs) < CONFIG.actionCooldownMs then
        return false
    end

    if playerIsMoving() then
        return false
    end

    local anim = getPlayerAnim()
    if anim == 0 or isMovementAnimation(anim) then
        return false
    end

    if (currentMs - RUNTIME.lastPosChangeMs) < CONFIG.xpReclickStationaryMs then
        return false
    end

    if (currentMs - RUNTIME.lastReclickMs) < CONFIG.xpReclickMinGapMs then
        return false
    end

    if math.random(1, 100) <= CONFIG.xpReclickSkipChance then
        RUNTIME.lastReclickMs = currentMs
        setStatus("Skipped XP-drop re-click", "Humanized skip")
        return false
    end

    local coreNpc = findCoreNpc()
    if coreNpc then
        RUNTIME.currentTargetType = "core"
        RUNTIME.currentTarget = coreNpc
        setStatus("Re-clicking core after XP drop", "2-tick re-click")
        API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, { coreNpc }, 75)
    else
        RUNTIME.currentTargetType = "memory"
        RUNTIME.currentTarget = RUNTIME.selectedMemoryName
        setStatus("Re-clicking memory after XP drop", "2-tick re-click")
        API.DoAction_NPC_str(0xc8, API.OFF_ACT_InteractNPC_route, { RUNTIME.selectedMemoryName }, 74)
    end

    RUNTIME.lastActionMs = currentMs
    RUNTIME.lastReclickMs = currentMs
    delay(CONFIG.clickDelayCenterMs, CONFIG.clickDelaySpreadMs)
    return true
end

local function fillJars()
    updateJarCounts()
    local currentMs = nowMs()

    if (currentMs - RUNTIME.lastActionMs) < CONFIG.actionCooldownMs then
        return false
    end

    if currentMs < RUNTIME.nextFillAttemptAtMs then
        return false
    end

    if (RUNTIME.emptyJars + RUNTIME.partialJars) == 0 then
        if RUNTIME.lastMemoryFinishMs == 0 or (currentMs - RUNTIME.lastMemoryFinishMs) > 5000 then
            RUNTIME.lastMemoryFinishMs = currentMs
            setStatus("Memory finished; waiting for next jar action", "Waiting")
        end
        return false
    end

    if playerIsMoving() then
        return false
    end

    if isHarvestingMemory() then
        setStatus("Harvesting memory", "Harvesting")
        return false
    end

    local requiredDelay = math.random(CONFIG.interMemoryDelayMinMs, CONFIG.interMemoryDelayMaxMs)
    if RUNTIME.lastMemoryFinishMs > 0 and (currentMs - RUNTIME.lastMemoryFinishMs) < requiredDelay then
        return false
    end

    local confirmed = clickMemory()
    RUNTIME.nextFillAttemptAtMs = nowMs() + 1200
    if not confirmed then
        setStatus("Memory click sent with no response; waiting before retry", "Waiting")
    end
    return confirmed
end

local function grabJars()
    if playerIsMoving() then
        return false
    end

    local before = RUNTIME.emptyJars + RUNTIME.partialJars + RUNTIME.fullJars
    setStatus("Taking memory jars", "Grab jars")
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { ID.JAR_OBJECT }, 70)
    RUNTIME.lastActionMs = nowMs()

    local directJarCount = before
    local directResponded = waitForResponse(2200, function()
        updateJarCounts()
        directJarCount = RUNTIME.emptyJars + RUNTIME.partialJars + RUNTIME.fullJars
        return directJarCount ~= before or playerIsMoving() or isGrabbingJars()
    end)

    if directResponded then
        waitForJarGrabToSettle()
        updateJarCounts()
        if (RUNTIME.emptyJars + RUNTIME.partialJars + RUNTIME.fullJars) ~= before then
            setStatus("Jars collected", "Grab jars")
            return true
        end
    end

    setStatus("Moving closer to jar depot", "Grab jars")
    API.DoAction_WalkerW(randomTileAround(2227, 9116, 1))
    RUNTIME.lastActionMs = nowMs()
    if API.WaitUntilMovingandAnimEnds then
        API.WaitUntilMovingandAnimEnds(10, 20)
    else
        API.WaitUntilMovingEnds(10, 20)
    end
    delay(CONFIG.jarTravelDelayCenterMs, CONFIG.jarTravelDelaySpreadMs)

    updateJarCounts()
    before = RUNTIME.emptyJars + RUNTIME.partialJars + RUNTIME.fullJars
    setStatus("Taking memory jars", "Grab jars")
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { ID.JAR_OBJECT }, 70)
    RUNTIME.lastActionMs = nowMs()

    local confirmed = waitForInventoryChange(4500, before, function()
        updateJarCounts()
        return RUNTIME.emptyJars + RUNTIME.partialJars + RUNTIME.fullJars
    end)
    if confirmed then
        waitForJarGrabToSettle()
        setStatus("Jars collected", "Grab jars")
    else
        setStatus("Jar click sent with no inventory change", "Waiting")
    end
    return confirmed
end

local function depositJars()
    if playerIsMoving() then
        return false
    end

    updateJarCounts()
    if RUNTIME.fullJars == 0 then
        return true
    end

    setStatus("Depositing full jars", "Deposit jars")
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { ID.DEPOSIT_OBJECT }, 74)
    RUNTIME.lastActionMs = nowMs()

    -- Wait for the click to register (movement or animation start)
    local reacted = waitForResponse(4000, function()
        return playerIsMoving() or getPlayerAnim() ~= 0
    end)

    if not reacted then
        setStatus("Deposit click had no response", "Waiting")
        return false
    end

    -- Wait for movement and animation to fully complete
    if API.WaitUntilMovingandAnimEnds then
        API.WaitUntilMovingandAnimEnds(16, 8)
    elseif API.WaitUntilMovingEnds then
        API.WaitUntilMovingEnds(16, 8)
    end

    -- Wait for the slow deposit animation to fully finish
    waitForResponse(12000, function()
        return getPlayerAnim() == 0
    end)

    -- Don't re-click, don't walk. Let the main loop call us again if jars remain.
    updateJarCounts()
    if RUNTIME.fullJars == 0 then
        setStatus("Full jars deposited", "Deposit jars")
    else
        setStatus("Deposit in progress (" .. tostring(RUNTIME.fullJars) .. " jars left)", "Deposit jars")
    end
    return true
end

local function handleRandomEvents()
    if API and type(API.DoRandomEvents) == "function" then
        API.DoRandomEvents()
    end
end

local function runHallTick()
    if not RUNTIME.running then
        return
    end

    updatePositionTracker()
    updateRuntimeStats()
    updateMemoryFinishTracker()
    updateWorldHopSchedule()
    if hopWorldIfNeeded() or RUNTIME.worldHopInProgress then
        return
    end

    if isGrabbingJars() then
        setStatus("Collecting jars", "Grab jars")
        return
    end

    handleXpDropReclick()

    if RUNTIME.fullJars >= 2 then
        depositJars()
    elseif isInventoryFull() then
        if RUNTIME.emptyJars > 0 or RUNTIME.partialJars > 0 then
            fillJars()
        else
            setStatus("Inventory full with no actionable jar state", "Waiting")
        end
    else
        grabJars()
    end
end

API.Write_LoopyLoop(true)
registerGui()
logInfo("Ready. Choose a memory type and press Start.")

while API.Read_LoopyLoop() do
    handleRandomEvents()
    runHallTick()
    delay(CONFIG.loopDelayCenterMs, CONFIG.loopDelaySpreadMs)
end

logInfo("Stopped")
