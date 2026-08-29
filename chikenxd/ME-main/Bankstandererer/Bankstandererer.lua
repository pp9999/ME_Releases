--[[
    Bankstandererer
    Generic preset-loop bankstander for inventory-item workflows.
--]]

local API = require("api")

local function addScriptDirectoryToPackagePath()
    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local scriptDir = source:match("^(.*[/\\])[^/\\]+$")
    if not scriptDir then
        return
    end

    local entries = {
        scriptDir .. "?.lua",
        scriptDir .. "?\\init.lua",
    }

    local currentPath = type(package.path) == "string" and package.path or ""
    for _, entry in ipairs(entries) do
        if not currentPath:find(entry, 1, true) then
            currentPath = entry .. ";" .. currentPath
        end
    end
    package.path = currentPath
end

addScriptDirectoryToPackagePath()

local Profiles = require("BankstanderererProfiles")
local GUI = require("BankstanderererGUI")

API.SetDrawTrackedSkills(true)

local SCRIPT_NAME = "Bankstandererer"
local BANK_PRESET_TARGETS = {
    { type = "object", name = "Bank chest" },
    { type = "object", name = "Bank booth" },
    { type = "npc", name = "Banker" },
    { type = "npc", name = "Head Guard" },
    { type = "npc", name = "Gnome Banker" },
    { type = "npc", name = "Gundai" },
    { type = "npc", name = "Emerald Benedict" },
    { type = "object", name = "Counter" },
    { type = "object", name = "Dead man's chest" },
}

local ITEM_CLICK_MODE_OPTIONS = Profiles.ITEM_CLICK_MODE_OPTIONS
local PROFILE_INTERFACE_MODE_OPTIONS = Profiles.PROFILE_INTERFACE_MODE_OPTIONS
local PROCESSING_CONFIRMATION_OPTIONS = Profiles.PROCESSING_CONFIRMATION_OPTIONS

local STATE = {
    WAITING_FOR_START = "WAITING_FOR_START",
    LOAD_PRESET = "LOAD_PRESET",
    USE_ITEM = "USE_ITEM",
    WAIT_FOR_INTERFACE = "WAIT_FOR_INTERFACE",
    CONFIRM_MAKE = "CONFIRM_MAKE",
    WAIT_FOR_PROCESSING_START = "WAIT_FOR_PROCESSING_START",
    WAIT_FOR_PROCESSING_END = "WAIT_FOR_PROCESSING_END",
    STOPPED = "STOPPED",
}

local RUNTIME = {
    started = false,
    state = STATE.WAITING_FOR_START,
    status = "Waiting to start",
    currentAction = "Idle",
    stopReason = "",
    lastError = "",
    loopsCompleted = 0,
    scriptStartTime = 0,
    deadlineAt = 0,
}

Profiles.configure({
    scriptName = SCRIPT_NAME,
    configStem = "bankstandererer",
    runtime = RUNTIME,
})

local CONFIG = Profiles.CONFIG

local function log(message)
    print(string.format("[%s] %s", SCRIPT_NAME, tostring(message)))
end

local function logError(message)
    RUNTIME.lastError = tostring(message or "")
    print(string.format("[%s][ERROR] %s", SCRIPT_NAME, tostring(message)))
end

local function setState(nextState, status)
    RUNTIME.state = nextState
    if status then
        RUNTIME.status = status
    end
end

local function setAction(action)
    RUNTIME.currentAction = tostring(action or "Idle")
end

local function formatElapsed(seconds)
    local total = math.max(0, tonumber(seconds) or 0)
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local secs = total % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function getRuntimeLabel()
    if RUNTIME.scriptStartTime <= 0 then
        return "00:00:00"
    end
    return formatElapsed(os.difftime(os.time(), RUNTIME.scriptStartTime))
end

local function delay(center, spread)
    local safeCenter = math.max(0, math.floor(tonumber(center) or 0))
    local safeSpread = math.max(0, math.floor(tonumber(spread) or 0))
    API.RandomSleep2(safeCenter, safeSpread, safeSpread)
end

local function loopDelay()
    delay(CONFIG.loopDelayCenter, CONFIG.loopDelaySpread)
end

local function waitUntil(predicate, timeoutSeconds, pollMs)
    local deadline = os.clock() + (tonumber(timeoutSeconds) or 5)
    local poll = tonumber(pollMs) or 120
    while API.Read_LoopyLoop() and os.clock() < deadline do
        local ok, result = pcall(predicate)
        if ok and result then
            return true
        end
        API.DoRandomEvents()
        API.RandomSleep2(poll, math.max(20, math.floor(poll * 0.20)), math.max(20, math.floor(poll * 0.15)))
    end
    local ok, result = pcall(predicate)
    return ok and result == true
end

local function isDoItemToolInterfaceOpen()
    return API.CheckDoItemOpen()
        or API.CheckDoToolOpen()
        or API.Compare2874Status(12, false)
        or API.FindChooseOptionOpen()
end

local function isCreationInterfaceOpen()
    return API.Compare2874Status(18, false) or API.Compare2874Status(40, false)
end

local function isCustom2874StatusOpen(profile)
    return API.Compare2874Status(profile.custom2874Status or 0, false)
end

local function isCustomInterfaceSizeOpen(profile)
    return API.GetInterfaceOpenBySize(profile.customInterfaceSize or 0) == true
end

local function isTargetInterfaceOpen(profile)
    local mode = tostring(profile.interfaceMode or PROFILE_INTERFACE_MODE_OPTIONS[1])
    if mode == PROFILE_INTERFACE_MODE_OPTIONS[2] then
        return isCreationInterfaceOpen()
    elseif mode == PROFILE_INTERFACE_MODE_OPTIONS[3] then
        return isCustom2874StatusOpen(profile)
    elseif mode == PROFILE_INTERFACE_MODE_OPTIONS[4] then
        return isCustomInterfaceSizeOpen(profile)
    end
    return isDoItemToolInterfaceOpen()
end

local function isProcessingInterfaceSizeOpen(profile)
    local targetSize = tonumber(profile.processingInterfaceSize) or 0
    if targetSize <= 0 then
        return false
    end
    return API.GetInterfaceOpenBySize(targetSize) == true
end

local function isProcessing2874StatusOpen(profile)
    local targetStatus = tonumber(profile.processing2874Status) or 0
    if targetStatus <= 0 then
        return false
    end
    return API.Compare2874Status(targetStatus, false)
end

local function hasProcessingStarted(profile)
    local mode = tostring(profile.processingConfirmationMode or PROCESSING_CONFIRMATION_OPTIONS[1])
    if mode == PROCESSING_CONFIRMATION_OPTIONS[2] then
        return isProcessingInterfaceSizeOpen(profile) or API.isProcessing()
    elseif mode == PROCESSING_CONFIRMATION_OPTIONS[3] then
        return isProcessing2874StatusOpen(profile) or API.isProcessing()
    end
    return API.isProcessing()
end

local function getInventoryRows()
    if type(API.ReadInvArrays33) == "function" then
        return API.ReadInvArrays33() or {}
    end
    return {}
end

local function getInventorySignature()
    local parts = {}
    for _, row in ipairs(getInventoryRows()) do
        local itemId = tonumber(row.itemid1) or 0
        local amount = tonumber(row.itemid1_size) or 0
        if itemId > 0 and amount > 0 then
            parts[#parts + 1] = tostring(itemId) .. ":" .. tostring(amount)
        end
    end
    return table.concat(parts, "|")
end

local function inventoryHasChanged(previousSignature)
    local current = getInventorySignature()
    if current ~= "" and previousSignature == "" then
        return true
    end
    return current ~= previousSignature
end

local function inventoryHasItem(targetId)
    targetId = tonumber(targetId) or 0
    if targetId <= 0 then
        return false
    end

    for _, row in ipairs(getInventoryRows()) do
        if tonumber(row.itemid1) == targetId then
            return true
        end
    end
    return false
end

local function hasProfileItem(profile)
    return inventoryHasItem(profile.itemId)
end

local function hasUseOnItem(profile)
    return inventoryHasItem(profile.useOnItemId)
end

local function profileInputsAvailable(profile)
    if tostring(profile.itemClickMode or ITEM_CLICK_MODE_OPTIONS[1]) == ITEM_CLICK_MODE_OPTIONS[2] then
        return hasProfileItem(profile) and hasUseOnItem(profile)
    end
    return hasProfileItem(profile)
end

local function loadPresetByInteract()
    for _, target in ipairs(BANK_PRESET_TARGETS) do
        local sent = false
        if target.type == "npc" then
            sent = Interact:NPC(target.name, "Load Last Preset from", nil, 50) == true
        else
            sent = Interact:Object(target.name, "Load Last Preset from", nil, 50) == true
        end
        if sent then
            return true
        end
    end
    return false
end

local function stopScript(reason)
    RUNTIME.started = false
    RUNTIME.stopReason = tostring(reason or "")
    setState(STATE.STOPPED, reason or "Stopped")
    setAction("Stopped")
    if reason and reason ~= "" then
        log("Stopping: " .. tostring(reason))
    end
end

local function shouldLoadPresetAtStart(profile)
    return not profileInputsAvailable(profile)
end

local function startScript()
    Profiles.commitDraftProfile(true)
    local profile = Profiles.getSelectedProfile()
    if not profile or (tonumber(profile.itemId) or 0) <= 0 or tostring(profile.itemName or "") == "" then
        stopScript("invalid_profile")
        return
    end
    if tostring(profile.itemClickMode or ITEM_CLICK_MODE_OPTIONS[1]) == ITEM_CLICK_MODE_OPTIONS[2] then
        if (tonumber(profile.useOnItemId) or 0) <= 0 or tostring(profile.useOnItemName or "") == "" then
            stopScript("invalid_use_on_item")
            return
        end
    end
    RUNTIME.started = true
    RUNTIME.loopsCompleted = 0
    RUNTIME.scriptStartTime = os.time()
    RUNTIME.stopReason = ""
    RUNTIME.lastError = ""
    RUNTIME.deadlineAt = 0
    if shouldLoadPresetAtStart(profile) then
        setState(STATE.LOAD_PRESET, "Loading preset")
    else
        setState(STATE.USE_ITEM, "Using inventory item")
    end
    setAction("Preparing run")
end

local function loadPreset(profile)
    setAction("Loading last preset")
    local beforeSignature = getInventorySignature()
    local sent = loadPresetByInteract()
    if sent ~= true then
        logError("Failed to load preset")
        stopScript("preset_load_failed")
        return false
    end

    if not waitUntil(function()
        return inventoryHasChanged(beforeSignature) or profileInputsAvailable(profile)
    end, 5, 140) then
        logError("Preset loaded but item not found in inventory")
        stopScript("preset_item_missing")
        return false
    end
    return true
end

local function clickPrimaryItem(profile)
    setAction(string.format("Selecting item: %s (%d)", tostring(profile.itemName), tonumber(profile.itemId) or 0))
    local inventoryAction = 1
    if tostring(profile.itemClickMode or ITEM_CLICK_MODE_OPTIONS[1]) == ITEM_CLICK_MODE_OPTIONS[2] then
        inventoryAction = 0
    end
    local ok = API.DoAction_Inventory1(profile.itemId, 0, inventoryAction, API.OFF_ACT_GeneralInterface_route)
    if ok ~= true then
        logError("Failed to click profile item")
        stopScript("item_click_failed")
        return false
    end
    return true
end

local function clickUseOnItem(profile)
    setAction(string.format("Using on item: %s (%d)", tostring(profile.useOnItemName), tonumber(profile.useOnItemId) or 0))
    local ok = API.DoAction_Inventory1(profile.useOnItemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
    if ok ~= true then
        logError("Failed to click use-on item")
        stopScript("use_on_item_click_failed")
        return false
    end
    return true
end

local function confirmMake(profile)
    if profile.useSpaceToConfirm ~= false then
        setAction("Confirming interface with space")
        API.KeyboardPress32(0x20, 0)
    else
        setAction("Interface open; waiting for processing start")
    end
    delay(120, 40)
end

local function shouldReloadPreset(profile)
    if profile.reloadPresetEveryCycle ~= false then
        return true
    end
    return not profileInputsAvailable(profile)
end

local function runStateMachine()
    local profile = Profiles.getSelectedProfile()
    if not profile then
        stopScript("no_profile_selected")
        return
    end

    if RUNTIME.state == STATE.LOAD_PRESET then
        if loadPreset(profile) then
            setState(STATE.USE_ITEM, "Using inventory item")
        end
        return
    end

    if RUNTIME.state == STATE.USE_ITEM then
        if clickPrimaryItem(profile) then
            if tostring(profile.itemClickMode or ITEM_CLICK_MODE_OPTIONS[1]) == ITEM_CLICK_MODE_OPTIONS[2] then
                if not clickUseOnItem(profile) then
                    return
                end
            end
            RUNTIME.deadlineAt = os.clock() + (profile.processingStartTimeoutSeconds or 4)
            setState(STATE.WAIT_FOR_INTERFACE, "Waiting for interface")
            log("Waiting for prompt detection: " .. tostring(profile.interfaceMode))
        end
        return
    end

    if RUNTIME.state == STATE.WAIT_FOR_INTERFACE then
        if hasProcessingStarted(profile) then
            log("Processing started without interface")
            RUNTIME.deadlineAt = os.clock() + math.max(profile.processingEndTimeoutSeconds or 45, 90)
            setState(STATE.WAIT_FOR_PROCESSING_END, "Waiting for processing end")
            return
        end
        if isTargetInterfaceOpen(profile) then
            setState(STATE.CONFIRM_MAKE, "Confirming make interface")
            return
        end
        if os.clock() >= RUNTIME.deadlineAt then
            logError("Interface never opened")
            stopScript("interface_never_opened")
        end
        return
    end

    if RUNTIME.state == STATE.CONFIRM_MAKE then
        confirmMake(profile)
        RUNTIME.deadlineAt = os.clock() + (profile.processingStartTimeoutSeconds or 4)
        setState(STATE.WAIT_FOR_PROCESSING_START, "Waiting for processing start")
        return
    end

    if RUNTIME.state == STATE.WAIT_FOR_PROCESSING_START then
        if hasProcessingStarted(profile) then
            log("Processing started")
            RUNTIME.deadlineAt = os.clock() + math.max(profile.processingEndTimeoutSeconds or 45, 90)
            setState(STATE.WAIT_FOR_PROCESSING_END, "Waiting for processing end")
            return
        end
        if os.clock() >= RUNTIME.deadlineAt then
            logError("Processing never started")
            stopScript("processing_never_started")
        end
        return
    end

    if RUNTIME.state == STATE.WAIT_FOR_PROCESSING_END then
        if not hasProcessingStarted(profile) then
            RUNTIME.loopsCompleted = RUNTIME.loopsCompleted + 1
            if shouldReloadPreset(profile) then
                setState(STATE.LOAD_PRESET, "Loading last preset")
            else
                setState(STATE.USE_ITEM, "Reusing inventory inputs")
            end
            setAction("Cycle complete")
            return
        end
        if os.clock() >= RUNTIME.deadlineAt then
            logError("Processing never finished")
            stopScript("processing_never_finished")
        end
        return
    end
end

Profiles.loadConfig()
GUI.register({
    model = Profiles,
    runtime = RUNTIME,
    startScript = startScript,
    stopScript = stopScript,
    getRuntimeLabel = getRuntimeLabel,
    shouldLoadPresetAtStart = shouldLoadPresetAtStart,
})

while API.Read_LoopyLoop() do
    if RUNTIME.started then
        runStateMachine()
    else
        setState(STATE.WAITING_FOR_START, RUNTIME.stopReason ~= "" and RUNTIME.stopReason or "Waiting to start")
        setAction("Idle")
        API.DoRandomEvents()
    end
    loopDelay()
end
