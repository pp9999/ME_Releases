--[[
# Script Name: Flash Powder Factory AFK'er
# Description: Travels to the factory and joins automatically. Script will continue rejoining games and AFK'ing until stopped.
# Author: matthew
# Version: 1.0.0
--]]

local API = require("api")

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

local DEBUG_MESSAGES = false

local FlashPowderAFKGUI = {}

FlashPowderAFKGUI.open = true
FlashPowderAFKGUI.startRequested = false
FlashPowderAFKGUI.stopRequested = false
FlashPowderAFKGUI.rewardModeIndex = 0

local GUI_THEME = {
    dark = { 0.05, 0.07, 0.12 },
    panel = { 0.11, 0.15, 0.24 },
    soft = { 0.18, 0.25, 0.39 },
    bright = { 0.42, 0.67, 0.94 },
    glow = { 0.70, 0.88, 1.00 },
    text = { 0.96, 0.97, 1.00 },
    good = { 0.50, 0.90, 0.68 },
    warn = { 0.96, 0.82, 0.48 },
    bad = { 0.92, 0.42, 0.42 },
}

local function guiRow(label, value, vr, vg, vb)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.TextWrapped(label)
    ImGui.TableNextColumn()
    if vr then
        ImGui.PushStyleColor(ImGuiCol.Text, vr, vg, vb, 1.0)
        ImGui.TextWrapped(value)
        ImGui.PopStyleColor(1)
    else
        ImGui.TextWrapped(value)
    end
end

local function guiSectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, GUI_THEME.glow[1], GUI_THEME.glow[2], GUI_THEME.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

function FlashPowderAFKGUI.consumeStartRequest()
    if FlashPowderAFKGUI.startRequested then
        FlashPowderAFKGUI.startRequested = false
        return true
    end
    return false
end

function FlashPowderAFKGUI.consumeStopRequest()
    if FlashPowderAFKGUI.stopRequested then
        FlashPowderAFKGUI.stopRequested = false
        return true
    end
    return false
end

function FlashPowderAFKGUI.getRewardModeIndex()
    return FlashPowderAFKGUI.rewardModeIndex or 0
end

function FlashPowderAFKGUI.draw(data)
    data = data or {}

    ImGui.SetNextWindowSize(430, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(110, 110, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, GUI_THEME.dark[1], GUI_THEME.dark[2], GUI_THEME.dark[3], 0.98)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, GUI_THEME.panel[1], GUI_THEME.panel[2], GUI_THEME.panel[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, GUI_THEME.soft[1], GUI_THEME.soft[2], GUI_THEME.soft[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Border, GUI_THEME.bright[1], GUI_THEME.bright[2], GUI_THEME.bright[3], 0.60)
    ImGui.PushStyleColor(ImGuiCol.Separator, GUI_THEME.soft[1], GUI_THEME.soft[2], GUI_THEME.soft[3], 0.60)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, GUI_THEME.panel[1], GUI_THEME.panel[2], GUI_THEME.panel[3], 0.92)
    ImGui.PushStyleColor(ImGuiCol.Text, GUI_THEME.text[1], GUI_THEME.text[2], GUI_THEME.text[3], 1.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 12)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 7, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 7)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)

    local visible = ImGui.Begin("Flash Powder Factory AFK'er###FlashPowderAFKWindow", true)
    if visible then
        guiSectionHeader("Flash Powder Factory AFK'er")
        ImGui.TextWrapped("Travels to the factory and joins automatically. Script will continue rejoining games and AFK'ing until stopped.")
        ImGui.Spacing()

        guiSectionHeader("Thaler Mode")
        local rewardLabels = { "Spotlight", "Normal" }
        ImGui.PushItemWidth(-1)
        local changedMode, newMode = ImGui.Combo("##flash_powder_afk_reward_mode", FlashPowderAFKGUI.rewardModeIndex or 0, rewardLabels, #rewardLabels)
        if changedMode then
            FlashPowderAFKGUI.rewardModeIndex = newMode
        end
        ImGui.PopItemWidth()

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.BeginTable("##flash_powder_afk_stats", 2) then
            ImGui.TableSetupColumn("Label", ImGuiTableColumnFlags.WidthStretch, 0.44)
            ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.56)
            guiRow("Reward Mode", tostring(data.rewardModeText or "Spotlight"))
            guiRow("Runtime", tostring(data.runtimeText or "00:00:00"))
            guiRow("Thaler Gained", tostring(data.thalerGainedText or "0"), GUI_THEME.good[1], GUI_THEME.good[2], GUI_THEME.good[3])
            guiRow("Thaler/Hr", tostring(data.thalerPerHourText or "0"), GUI_THEME.good[1], GUI_THEME.good[2], GUI_THEME.good[3])
            ImGui.EndTable()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button, GUI_THEME.bright[1], GUI_THEME.bright[2], GUI_THEME.bright[3], 0.92)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, GUI_THEME.glow[1], GUI_THEME.glow[2], GUI_THEME.glow[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.28, 0.78, 0.98, 1.0)
        if ImGui.Button("Start##flash_powder_afk_start", -1, 34) then
            FlashPowderAFKGUI.startRequested = true
        end
        ImGui.PopStyleColor(3)

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button, 0.56, 0.18, 0.20, 0.94)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.68, 0.24, 0.25, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.78, 0.28, 0.29, 1.0)
        if ImGui.Button("Stop##flash_powder_afk_stop", -1, 30) then
            FlashPowderAFKGUI.stopRequested = true
        end
        ImGui.PopStyleColor(3)
    end

    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(7)
    ImGui.End()

    return FlashPowderAFKGUI.open
end

local SCRIPT_NAME = "Flash Powder Factory AFK'er"
local ROGUES_DEN_START = { x = 3041, y = 4968, radius = 30 }
local ROGUES_DEN_SURFACE = { x = 2878, y = 3442, radius = 5 }
local LODESTONE_SETTLE_BUFFER_MS = 1200
local FACTORY_STRONG_OBJECT_RADIUS = 20
local FACTORY_FALLBACK_OBJECT_RADIUS = 25
local FACTORY_STRONG_OBJECT_MINIMUM = 2
local FACTORY_FALLBACK_OBJECT_MINIMUM = 3
local FACTORY_STRONG_OBJECT_IDS = {
    64637, -- Mixer machine
    64638, -- Reagent machine (A)
    64639, -- Reagent machine (A)
    64640, -- Reagent machine (B)
    64641, -- Reagent machine (B)
    64650, -- Catalyst machine
    64652, -- Catalyst machine
    64654, -- Charge machine
    64655, -- Charge machine
    64656, -- Charge machine
}
local FACTORY_ENTRY_OBJECT_IDS = {
    64575,
    64637,
    64638,
    64639,
    64640,
    64641,
    64650,
    64652,
    64654,
    64655,
    64656,
    64667,
    64674,
    64676,
    64688,
    64689,
    64690,
    64691,
    64692,
    64694,
}
local REWARD_MODE = {
    SPOTLIGHT = "SPOTLIGHT",
    NORMAL = "NORMAL",
}

local STATE = {
    WAIT_START = "WAIT_START",
    TRAVEL_TO_ROGUES_DEN = "TRAVEL_TO_ROGUES_DEN",
    PREPARE_FACTORY_ENTRY = "PREPARE_FACTORY_ENTRY",
    JOINING_ARENA = "JOINING_ARENA",
    TRANSITIONING = "TRANSITIONING",
    IDLING_IN_ARENA = "IDLING_IN_ARENA",
    REJOINING = "REJOINING",
    STOPPED = "STOPPED",
}

local TRAVEL_STEP = {
    SURFACE_INTERFACE = "SURFACE_INTERFACE",
    SURFACE_TELEPORT = "SURFACE_TELEPORT",
    OPEN_TRAPDOOR = "OPEN_TRAPDOOR",
    WAIT_FOR_DEN = "WAIT_FOR_DEN",
}

local runtime = {
    running = false,
    stopReason = "",
    currentState = STATE.WAIT_START,
    scriptStartTime = 0,
    transitionStartedAt = 0,
    transitionTimeoutSeconds = 25,
    nextKeepaliveAt = 0,
    wasInsideArena = false,
    rewardMode = REWARD_MODE.SPOTLIGHT,
    thalerGained = 0,
    thalerPerHour = 0,
    travelStep = nil,
    travelStepStartedAt = 0,
    actionFailureCount = 0,
    maxActionFailures = 6,
    idleMissingArenaSince = 0,
    lastArenaMissLogAt = 0,
    debugEnabled = false,
}

local stopScript

local function logInfo(message)
    print(string.format("[%s] %s", SCRIPT_NAME, tostring(message)))
end

local function debugLog(message)
    if runtime.debugEnabled ~= true then
        return
    end
    logInfo(message)
end

local function sleep(wait, sleep1, sleep2)
    API.RandomSleep2(wait, sleep1 or 0, sleep2 or sleep1 or 0)
end

local function now()
    return os.time()
end

local function nowClock()
    return os.clock()
end

local function formatRuntime(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local secs = total % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function getRewardMode()
    local index = FlashPowderAFKGUI.getRewardModeIndex and FlashPowderAFKGUI.getRewardModeIndex() or 0
    if tonumber(index) == 1 then
        return REWARD_MODE.NORMAL
    end
    return REWARD_MODE.SPOTLIGHT
end

local function getRewardModeText()
    return runtime.rewardMode == REWARD_MODE.NORMAL and "Normal" or "Spotlight"
end

local function waitUntil(predicate, timeoutSeconds, pollMs)
    local deadline = nowClock() + (tonumber(timeoutSeconds) or 1)
    while API.Read_LoopyLoop() and nowClock() < deadline do
        local ok, result = pcall(predicate)
        if ok and result then
            return true
        end
        local poll = tonumber(pollMs) or 180
        API.RandomSleep2(poll, math.max(20, math.floor(poll * 0.2)), math.max(20, math.floor(poll * 0.15)))
    end
    local ok, result = pcall(predicate)
    return ok and result == true
end

local function isPlayerSettled()
    local anim = tonumber(API.ReadPlayerAnim and API.ReadPlayerAnim()) or 0
    local moving = type(API.ReadPlayerMovin2) == "function" and API.ReadPlayerMovin2() == true or false
    local processing = type(API.isProcessing) == "function" and API.isProcessing() == true or false
    return (not moving) and anim == 0 and (not processing)
end

local function waitForSettled(timeoutSec)
    if type(API.WaitUntilMovingEnds) == "function" then
        API.WaitUntilMovingEnds(600, 5)
    end
    return waitUntil(isPlayerSettled, timeoutSec or 8, 180)
end

local function getPlayerCoord()
    local coord = API.PlayerCoord and API.PlayerCoord()
    if not coord then
        return nil, nil, nil
    end
    return tonumber(coord.x), tonumber(coord.y), tonumber(coord.z)
end

local function isNearTile(tile, radius)
    local px, py, pz = getPlayerCoord()
    if not px or type(tile) ~= "table" then
        return false
    end

    local r = math.max(0, tonumber(radius) or 0)
    if math.abs(px - tile.x) > r or math.abs(py - tile.y) > r then
        return false
    end

    if tile.z ~= nil and tonumber(pz) ~= tonumber(tile.z) then
        return false
    end

    return true
end

local function isNearRoguesDenStart()
    return isNearTile(ROGUES_DEN_START, ROGUES_DEN_START.radius)
end

local function isNearRoguesDenSurface()
    return isNearTile(ROGUES_DEN_SURFACE, ROGUES_DEN_SURFACE.radius)
end

local function getNearbyObjectCount(ids, radius)
    local function countObjectsWithinRadius(objects, maxDistance)
        if type(objects) ~= "table" and type(objects) ~= "userdata" then
            return 0
        end

        local count = 0
        for _, obj in ipairs(objects) do
            local distance = tonumber(obj and obj.Distance)
            if distance == nil or distance <= maxDistance then
                count = count + 1
            end
        end
        return count
    end

    local bestCount = 0

    if type(API.GetAllObjArrayInteract) == "function" then
        local interactObjects = API.GetAllObjArrayInteract(ids, radius, { 0, 12 }) or {}
        bestCount = math.max(bestCount, countObjectsWithinRadius(interactObjects, radius))
    end

    if type(API.GetAllObjArray1) == "function" then
        local rawObjects = API.GetAllObjArray1(ids, radius, { 0, 12 }) or {}
        bestCount = math.max(bestCount, countObjectsWithinRadius(rawObjects, radius))
    end

    if type(API.ReadAllObjectsArray) == "function" then
        local allObjects = API.ReadAllObjectsArray({ 0, 12 }, ids, {}) or {}
        bestCount = math.max(bestCount, countObjectsWithinRadius(allObjects, radius))
    end

    return bestCount
end

local function formatPlayerCoord()
    local x, y, z = getPlayerCoord()
    if not x then
        return "unknown"
    end
    return string.format("%d,%d,%d", x, y, z or 0)
end

local function getFactoryObjectCounts()
    local strongCount = getNearbyObjectCount(FACTORY_STRONG_OBJECT_IDS, FACTORY_STRONG_OBJECT_RADIUS)
    local fallbackCount = getNearbyObjectCount(FACTORY_ENTRY_OBJECT_IDS, FACTORY_FALLBACK_OBJECT_RADIUS)
    return strongCount, fallbackCount
end

local function hasNearbyFactoryObjects()
    local strongCount, fallbackCount = getFactoryObjectCounts()
    if strongCount >= FACTORY_STRONG_OBJECT_MINIMUM then
        return true
    end

    if strongCount >= 1 and fallbackCount >= FACTORY_FALLBACK_OBJECT_MINIMUM then
        return true
    end

    return fallbackCount >= 5
end

local function isInsideFactorySession()
    return hasNearbyFactoryObjects()
end

local function logArenaDetectionMiss(context)
    local nowAt = nowClock()
    if (nowAt - (tonumber(runtime.lastArenaMissLogAt) or 0)) < 2.5 then
        return
    end
    runtime.lastArenaMissLogAt = nowAt

    local strongCount, fallbackCount = getFactoryObjectCounts()
    debugLog(string.format(
        "Arena detection miss%s: strong=%d fallback=%d pos=%s",
        context and (" (" .. tostring(context) .. ")") or "",
        strongCount,
        fallbackCount,
        formatPlayerCoord()
    ))
end

local function isRoundEndInterfaceOpen()
    if type(API.GetInterfaceOpenBySize) ~= "function" then
        return false
    end
    return API.GetInterfaceOpenBySize(1186) == true
end

local function confirmInsideFactorySession(timeoutSeconds)
    if isInsideFactorySession() then
        return true
    end

    local timeout = math.max(0, tonumber(timeoutSeconds) or 0)
    if timeout <= 0 then
        return false
    end

    return waitUntil(function()
        return isInsideFactorySession()
    end, timeout, 140)
end

local function markInsideArenaConfirmed()
    local shouldLogArrival = runtime.wasInsideArena ~= true
    runtime.wasInsideArena = true
    runtime.idleMissingArenaSince = 0
    if shouldLogArrival then
        debugLog("Arena arrival confirmed")
    end
end

local function setState(nextState)
    runtime.currentState = nextState
end

local function markActionSuccess()
    runtime.actionFailureCount = 0
end

local function recordActionFailure(reason)
    runtime.actionFailureCount = (tonumber(runtime.actionFailureCount) or 0) + 1
    if runtime.actionFailureCount >= (tonumber(runtime.maxActionFailures) or 6) then
        stopScript("Repeated failed actions: " .. tostring(reason or "Unknown"))
        return true
    end
    return false
end

local function resolveStartArea()
    if confirmInsideFactorySession(1.8) then
        logInfo("Already inside factory arena")
        debugLog("Already inside factory arena, switching to AFK idle")
        return STATE.IDLING_IN_ARENA
    end

    if isNearRoguesDenStart() then
        logInfo("Ready at Rogues Den start")
        return STATE.PREPARE_FACTORY_ENTRY
    end

    logInfo("Travelling to Rogues Den")
    return STATE.TRAVEL_TO_ROGUES_DEN
end

local function inventoryHasItems()
    if Inventory and type(Inventory.IsEmpty) == "function" then
        return Inventory:IsEmpty() ~= true
    end
    if type(API.ReadInvArrays33) == "function" then
        local rows = API.ReadInvArrays33() or {}
        for _, row in ipairs(rows) do
            if (tonumber(row.itemid1) or 0) > 0 then
                return true
            end
        end
    end
    return false
end

local function isBankOpen()
    return Bank and Bank.IsOpen and Bank:IsOpen()
end

local function closeBankInterface()
    if isBankOpen() then
        debugLog("Closing bank interface (attempt 1)")
        API.DoAction_Interface(0x24, 0xffffffff, 1, 517, 317, -1, API.OFF_ACT_GeneralInterface_route)
        waitUntil(function()
            return not isBankOpen()
        end, 1.5, 140)
    end
    if isBankOpen() then
        debugLog("Closing bank interface (attempt 2)")
        API.DoAction_Interface(0x24, 0xffffffff, 1, 517, 317, -1, API.OFF_ACT_GeneralInterface_route)
        waitUntil(function()
            return not isBankOpen()
        end, 1.5, 140)
    end
    return not isBankOpen()
end

local function prepareFactoryEntry()
    if not isNearRoguesDenStart() then
        debugLog("Prepare factory entry: not at Rogues Den start yet")
        return false
    end

    if inventoryHasItems() and not isBankOpen() then
        debugLog("Prepare factory entry: opening Emerald Benedict bank")
        local opened = Interact:NPC("Emerald Benedict", "Bank", nil, 30) == true
        if type(API.WaitUntilMovingEnds) == "function" then
            API.WaitUntilMovingEnds(600, 5)
        end
        if not opened or not waitUntil(function()
            return isBankOpen()
        end, 8, 180) then
            recordActionFailure("Failed to open Emerald Benedict bank")
            return false
        end
        markActionSuccess()
    end

    if isBankOpen() and inventoryHasItems() then
        debugLog("Prepare factory entry: depositing inventory")
        if Bank:DepositInventory() ~= true then
            if recordActionFailure("Failed to deposit inventory") then
                return false
            end
            sleep(620, 180, 180)
            return false
        end
        sleep(620, 180, 180)
        markActionSuccess()
    end

    if isBankOpen() then
        debugLog("Prepare factory entry: closing bank")
        if not closeBankInterface() then
            if recordActionFailure("Failed to close bank") then
                return false
            end
            return false
        end
        markActionSuccess()
    end

    debugLog("Prepare factory entry complete, proceeding to Brian quick start")
    setState(STATE.JOINING_ARENA)
    return true
end

local function travelToRoguesDen()
    if isNearRoguesDenStart() then
        debugLog("Travel complete: inside Rogues Den")
        runtime.travelStep = nil
        runtime.travelStepStartedAt = 0
        setState(STATE.PREPARE_FACTORY_ENTRY)
        return true
    end

    if not runtime.travelStep then
        runtime.travelStep = isNearRoguesDenSurface() and TRAVEL_STEP.OPEN_TRAPDOOR or TRAVEL_STEP.SURFACE_INTERFACE
        runtime.travelStepStartedAt = nowClock()
    end

    if runtime.travelStep == TRAVEL_STEP.SURFACE_INTERFACE then
        debugLog("Travel step: opening lodestone interface")
        local sent = API.DoAction_Interface(0xffffffff,0xffffffff,1,1465,33,-1,API.OFF_ACT_GeneralInterface_route)
        if sent ~= false and waitUntil(function()
            if API.GetInterfaceOpenBySize and API.GetInterfaceOpenBySize(1092) == true then
                return true
            end
            return false
        end, 5, 220) then
            markActionSuccess()
            runtime.travelStep = TRAVEL_STEP.SURFACE_TELEPORT
            runtime.travelStepStartedAt = nowClock()
            return false
        end

        recordActionFailure("Failed to open travel interface")
        sleep(900, 180, 220)
        return false
    end

    if runtime.travelStep == TRAVEL_STEP.SURFACE_TELEPORT then
        debugLog("Travel step: teleporting to Rogues Den surface")
        API.DoAction_Interface(0xffffffff,0xffffffff,1,1092,20,-1,API.OFF_ACT_GeneralInterface_route)
        if waitUntil(function()
            local surfaceStatusMatched = type(API.Compare2874Status) == "function" and API.Compare2874Status(30) == true
            if surfaceStatusMatched and not isNearRoguesDenSurface() then
                debugLog("Travel step: lodestone status matched, waiting for actual surface coords")
            end
            return isNearRoguesDenSurface()
        end, 20, 300) then
            if waitForSettled(8) then
                debugLog("Travel step: lodestone settled, waiting extra buffer before trapdoor")
                sleep(LODESTONE_SETTLE_BUFFER_MS, 220, 260)
                markActionSuccess()
                runtime.travelStep = TRAVEL_STEP.OPEN_TRAPDOOR
                runtime.travelStepStartedAt = nowClock()
                return false
            end
        end

        recordActionFailure("Failed to travel to Rogues Den surface")
        runtime.travelStep = TRAVEL_STEP.SURFACE_INTERFACE
        runtime.travelStepStartedAt = nowClock()
        return false
    end

    if runtime.travelStep == TRAVEL_STEP.OPEN_TRAPDOOR then
        if not isNearRoguesDenSurface() then
            debugLog("Travel step: trapdoor gated until Rogues Den surface arrival")
            if (nowClock() - runtime.travelStepStartedAt) > 12 then
                recordActionFailure("Trapdoor step timed out before surface arrival")
                runtime.travelStep = TRAVEL_STEP.SURFACE_INTERFACE
                runtime.travelStepStartedAt = nowClock()
            else
                sleep(350, 100, 120)
            end
            return false
        end

        debugLog("Travel step: opening trapdoor to Rogues Den")
        local opened = Interact:Object("Trapdoor", "Open") == true
        if not opened then
            recordActionFailure("Failed to open trapdoor")
            sleep(900, 180, 220)
            return false
        end

        if type(API.WaitUntilMovingEnds) == "function" then
            API.WaitUntilMovingEnds(600, 5)
        end

        markActionSuccess()
        runtime.travelStep = TRAVEL_STEP.WAIT_FOR_DEN
        runtime.travelStepStartedAt = nowClock()
        return false
    end

    if runtime.travelStep == TRAVEL_STEP.WAIT_FOR_DEN then
        debugLog("Travel step: waiting to settle inside Rogues Den")
        if isNearRoguesDenStart() then
            markActionSuccess()
            runtime.travelStep = nil
            runtime.travelStepStartedAt = 0
            setState(STATE.PREPARE_FACTORY_ENTRY)
            return true
        end

        if (nowClock() - runtime.travelStepStartedAt) > 20 then
            recordActionFailure("Timed out waiting for Rogues Den arrival")
            runtime.travelStep = TRAVEL_STEP.OPEN_TRAPDOOR
            runtime.travelStepStartedAt = nowClock()
        end

        sleep(300, 80, 100)
        return false
    end

    runtime.travelStep = TRAVEL_STEP.SURFACE_INTERFACE
    runtime.travelStepStartedAt = nowClock()
    return false
end

local function isQuickStartDialogueOpen()
    return API.GetInterfaceOpenBySize and API.GetInterfaceOpenBySize(1184) == true
end

local function pressSpaceToAdvanceDialogue()
    if type(API.KeyboardPress2) ~= "function" then
        return false
    end
    sleep(150, 50, 50)
    API.KeyboardPress2(0x20, 0, 50)
    return true
end

local function continueQuestDialogue(maxContinues)
    local budget = math.max(1, tonumber(maxContinues) or 4)
    local advanced = false
    for _ = 1, budget do
        if isQuickStartDialogueOpen() and pressSpaceToAdvanceDialogue() then
            advanced = true
        elseif type(API.DoContinue_Dialog) == "function" then
            local ok, sent = pcall(API.DoContinue_Dialog)
            if ok and sent ~= false then
                advanced = true
            end
        end

        if hasNearbyFactoryObjects() or not isNearRoguesDenStart() then
            return true
        end
        sleep(420, 120, 120)
    end

    return advanced
end

local function tryQuickStartFactory()
    if not isNearRoguesDenStart() then
        return false
    end

    local sent = Interact:NPC("Brian O'Richard", "Quick start", nil, 50) == true
    if not sent then
        return false
    end

    if not waitUntil(function()
        return isQuickStartDialogueOpen() or hasNearbyFactoryObjects() or not isNearRoguesDenStart()
    end, 5, 240) then
        return false
    end

    if isQuickStartDialogueOpen() then
        continueQuestDialogue(6)
    end

    local entered = waitUntil(function()
        if hasNearbyFactoryObjects() then
            return true
        end
        if continueQuestDialogue(1) then
            return hasNearbyFactoryObjects() or not isNearRoguesDenStart()
        end
        return false
    end, 10, 420)

    if not entered then
        entered = hasNearbyFactoryObjects() or not isNearRoguesDenStart()
    end

    return entered
end

local function updateThalerTracking()
    local elapsedSeconds = math.max(0, now() - runtime.scriptStartTime)
    local rateSeconds = runtime.rewardMode == REWARD_MODE.NORMAL and 300 or 60
    runtime.thalerGained = math.floor(elapsedSeconds / rateSeconds)
    runtime.thalerPerHour = math.floor(3600 / rateSeconds)
end

local function scheduleNextKeepalive()
    runtime.nextKeepaliveAt = now() + math.random(300, 600)
end

local function refreshAntiIdle(force)
    if force or runtime.nextKeepaliveAt <= 0 or now() >= runtime.nextKeepaliveAt then
        API.SetMaxIdleTime(math.random(5, 10))
        scheduleNextKeepalive()
    end
end

stopScript = function(reason)
    runtime.running = false
    runtime.stopReason = tostring(reason or "")
    if runtime.stopReason ~= "" then
        logInfo(runtime.stopReason)
    end
    setState(STATE.STOPPED)
    API.Write_LoopyLoop(false)
end

local function beginTransition(timeoutSeconds)
    runtime.transitionStartedAt = nowClock()
    runtime.transitionTimeoutSeconds = tonumber(timeoutSeconds) or 25
    setState(STATE.TRANSITIONING)
end

local function handleTransition()
    if (nowClock() - runtime.transitionStartedAt) >= runtime.transitionTimeoutSeconds then
        logInfo("Transition timed out, retrying entry")
        setState(STATE.REJOINING)
        return
    end

    if confirmInsideFactorySession(1.2) then
        markInsideArenaConfirmed()
        debugLog("Transition complete: inside factory arena, AFK idling")
        setState(STATE.IDLING_IN_ARENA)
        return
    end

    logArenaDetectionMiss("transition")

    local gameState = tonumber(API.GetGameState2 and API.GetGameState2()) or -1
    if gameState ~= 3 then
        return
    end
end

local function handleJoining()
    if confirmInsideFactorySession(1.2) then
        markInsideArenaConfirmed()
        debugLog("Joining arena: detected inside factory, switching to AFK idle")
        setState(STATE.IDLING_IN_ARENA)
        return
    end

    logArenaDetectionMiss("joining")

    local gameState = tonumber(API.GetGameState2 and API.GetGameState2()) or -1
    if gameState ~= 3 then
        debugLog("Joining arena: waiting for in-game state to return")
        sleep(600, 150, 180)
        return
    end

    if not isNearRoguesDenStart() then
        debugLog("Joining arena: not at Rogues Den start, re-resolving location")
        setState(resolveStartArea())
        sleep(300, 80, 100)
        return
    end

    if tryQuickStartFactory() then
        markActionSuccess()
        debugLog("Joining arena: Brian quick start sent, waiting for transition")
        beginTransition(25)
        return
    end

    recordActionFailure("Failed to quick start factory")
    sleep(900, 180, 220)
end

local function handleIdle()
    refreshAntiIdle(false)
    updateThalerTracking()

    if confirmInsideFactorySession(1.2) then
        markInsideArenaConfirmed()
        sleep(600, 120, 160)
        return
    end

    logArenaDetectionMiss("idle")

    local gameState = tonumber(API.GetGameState2 and API.GetGameState2()) or -1
    if gameState ~= 3 then
        debugLog("AFK idle: game state not ready, keeping arena latch during transition")
        sleep(600, 120, 160)
        return
    end

    if runtime.wasInsideArena and isRoundEndInterfaceOpen() then
        logInfo("Round ended, rejoining arena")
        runtime.idleMissingArenaSince = 0
        setState(STATE.REJOINING)
        return
    end

    if runtime.wasInsideArena then
        if runtime.idleMissingArenaSince <= 0 then
            runtime.idleMissingArenaSince = nowClock()
            debugLog("AFK idle: arena detection dropped, waiting for confirmation before rejoin")
            sleep(600, 120, 160)
            return
        end

        if (nowClock() - runtime.idleMissingArenaSince) < 12 then
            debugLog("AFK idle: arena still not confirmed, holding position")
            sleep(600, 120, 160)
            return
        end

        debugLog("AFK idle: arena missing long enough, rejoining arena")
        runtime.idleMissingArenaSince = 0
        setState(STATE.REJOINING)
        return
    end

    sleep(600, 120, 160)
end

local function buildGuiData()
    if not runtime.running then
        return {
            rewardModeText = (FlashPowderAFKGUI.getRewardModeIndex and FlashPowderAFKGUI.getRewardModeIndex() == 1) and "Normal" or "Spotlight",
            runtimeText = "00:00:00",
            thalerGainedText = "0",
            thalerPerHourText = "0",
        }
    end

    runtime.rewardMode = getRewardMode()
    updateThalerTracking()
    return {
        rewardModeText = getRewardModeText(),
        runtimeText = formatRuntime(now() - runtime.scriptStartTime),
        thalerGainedText = tostring(runtime.thalerGained),
        thalerPerHourText = tostring(runtime.thalerPerHour),
    }
end

local function resetRuntimeForStart()
    runtime.running = true
    runtime.stopReason = ""
    runtime.scriptStartTime = now()
    runtime.transitionStartedAt = 0
    runtime.currentState = resolveStartArea()
    runtime.wasInsideArena = isInsideFactorySession()
    runtime.rewardMode = getRewardMode()
    runtime.debugEnabled = DEBUG_MESSAGES == true
    runtime.thalerGained = 0
    runtime.thalerPerHour = 0
    runtime.travelStep = nil
    runtime.travelStepStartedAt = 0
    runtime.idleMissingArenaSince = 0
    runtime.lastArenaMissLogAt = 0
    refreshAntiIdle(true)
end

local function onStartRequested()
    resetRuntimeForStart()
end

local function onStopRequested()
    stopScript("Stopped by user")
end

local function drawGUI()
    FlashPowderAFKGUI.draw(buildGuiData())
    if FlashPowderAFKGUI.consumeStartRequest() and not runtime.running then
        onStartRequested()
    end
    if FlashPowderAFKGUI.consumeStopRequest() and runtime.currentState ~= STATE.STOPPED then
        onStopRequested()
    end
end

local function registerGui()
    if type(DrawImGui) ~= "function" then
        logInfo("DrawImGui unavailable")
        return
    end
    if type(ClearRender) == "function" then
        pcall(ClearRender)
    end
    DrawImGui(function()
        drawGUI()
    end)
end

local function mainLoop()
    API.Write_LoopyLoop(true)
    while API.Read_LoopyLoop() do
        if not runtime.running then
            sleep(120, 30, 20)
        elseif runtime.currentState == STATE.TRAVEL_TO_ROGUES_DEN then
            travelToRoguesDen()
        elseif runtime.currentState == STATE.PREPARE_FACTORY_ENTRY then
            prepareFactoryEntry()
        elseif runtime.currentState == STATE.JOINING_ARENA then
            handleJoining()
        elseif runtime.currentState == STATE.TRANSITIONING then
            handleTransition()
            sleep(240, 60, 80)
        elseif runtime.currentState == STATE.IDLING_IN_ARENA then
            handleIdle()
        elseif runtime.currentState == STATE.REJOINING then
            handleJoining()
        elseif runtime.currentState == STATE.STOPPED then
            break
        else
            setState(STATE.JOINING_ARENA)
        end
    end
end

logInfo("Ready - press Start to travel to the arena and begin AFKing")
registerGui()
mainLoop()
