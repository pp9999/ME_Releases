local API = require("api")
local idleHandler = require("Divination AIO/idle_handler")
local DATA = require("Divination AIO/div_data")
local WISPS = require("Divination AIO/div_wisps")
local Utils = require("Divination AIO/div_utils")
local DivGUI = require("Divination AIO/div_gui")

idleHandler.init()

API.SetDrawLogs(false)
API.SetDrawTrackedSkills(false)
API.Write_fake_mouse_do(false)
API.TurnOffMrHasselhoff(false)

ClearRender()
DivGUI.reset()

local EMPTY_DATA = {}
DrawImGui(function()
    if DivGUI.open then
        DivGUI.draw(EMPTY_DATA)
    end
end)

API.printlua("Waiting for configuration...", 0, false)

while API.Read_LoopyLoop() and not DivGUI.started do
    if not DivGUI.open then
        API.printlua("GUI closed before start", 0, false)
        ClearRender()
        return
    end
    API.RandomSleep2(100, 50, 0)
end

if not API.Read_LoopyLoop() then
    ClearRender()
    return
end

local cfg = DivGUI.getConfig()

local wispDef = WISPS.TYPES[cfg.wispType]
if not wispDef then
    DivGUI.addWarning("Invalid wisp type: " .. tostring(cfg.wispType))
    DivGUI.selectWarningsTab = true
    DivGUI.started = false
    while API.Read_LoopyLoop() and not DivGUI.started and DivGUI.open do
        API.RandomSleep2(100, 50, 0)
    end
    ClearRender()
    return
end

local validationFailed = false

local currentLevel = API.XPLevelTable(API.GetSkillXP("DIVINATION"))
if currentLevel < wispDef.level then
    DivGUI.addWarning(string.format("Insufficient Divination level (have %d, need %d)", currentLevel, wispDef.level))
    validationFailed = true
end

if not Utils.checkLocation(wispDef) then
    DivGUI.addWarning("Not at correct location for " .. wispDef.name .. " wisps")
    validationFailed = true
end

if not Utils.checkEquipment(cfg.memoryDowser) then
    if cfg.memoryDowser then
        DivGUI.addWarning("Memory Dowser not equipped")
    end
    validationFailed = true
end

if validationFailed then
    DivGUI.selectWarningsTab = true
    DivGUI.started = false
    while API.Read_LoopyLoop() and not DivGUI.started and DivGUI.open do
        API.RandomSleep2(100, 50, 0)
    end
    ClearRender()
    return
end

local currentConversion = API.GetVarbitValue(DATA.VARBIT_IDS.CONVERSION_MODE)
if currentConversion ~= cfg.conversionMode then
    API.printlua("Conversion mode mismatch, attempting auto-fix...", 0, false)
    if not Utils.changeConversionMode(cfg.conversionMode) then
        DivGUI.addWarning("Failed to set conversion mode automatically")
    end
end

local manualDeposit = not cfg.memoryDowser

local state = {
    currentState = "Idle",
    currentTarget = "None",
    shouldSwitchToEnriched = false,
}

local tracking = {
    energy = {
        start = Inventory:GetItemAmount(wispDef.energyId),
        current = 0,
        gained = 0,
    },
    strands = {
        start = API.GetVarbitValue(DATA.VARBIT_IDS.MEMORY_STRANDS),
        current = 0,
        gained = 0,
    },
}
tracking.energy.current = tracking.energy.start
tracking.strands.current = tracking.strands.start

local startXP = API.GetSkillXP("DIVINATION")

API.printlua("Starting " .. wispDef.name .. " divination...", 0, false)

if #DivGUI.warnings > 0 then
    DivGUI.selectWarningsTab = true
else
    DivGUI.selectInfoTab = true
end

local formatNumber = Utils.formatNumber

local guiData = {
    title = nil,
    state = "Idle",
    currentTarget = "None",
    conversionMode = DATA.CONVERSION_MODES[cfg.conversionMode] or "Unknown",
    antiIdleText = "0:00",
    energyText = nil,
    strandsText = nil,
    metricsBarLabel = "",
    metricsBarProgress = 0,
    metricsBarMaxLevel = false,
}

local lastGUIUpdate = 0

local function buildGUIData()
    guiData.state = state.currentState
    guiData.currentTarget = state.currentTarget

    local antiIdle = idleHandler.getTimeUntilNextIdle()
    local mins = math.floor(antiIdle / 60)
    local secs = math.floor(antiIdle % 60)
    guiData.antiIdleText = string.format("%d:%02d", mins, secs)

    local elapsed = API.ScriptRuntime()

    if tracking.energy.gained > 0 then
        local energyPerHour = elapsed > 0 and math.floor((tracking.energy.gained / elapsed) * 3600) or 0
        guiData.energyText = string.format("%s (%s/hr)", formatNumber(tracking.energy.gained), formatNumber(energyPerHour))
    end

    if tracking.strands.gained > 0 then
        local strandsPerHour = elapsed > 0 and math.floor((tracking.strands.gained / elapsed) * 3600) or 0
        guiData.strandsText = string.format("%s (%s/hr)", formatNumber(tracking.strands.gained), formatNumber(strandsPerHour))
    end

    local currentXP = API.GetSkillXP("DIVINATION")
    local level = API.XPLevelTable(currentXP)
    local xpGained = currentXP - startXP
    local xpPerHour = elapsed > 0 and (xpGained / elapsed) * 3600 or 0

    if level >= 120 then
        guiData.metricsBarMaxLevel = true
        guiData.metricsBarProgress = 1.0
        guiData.metricsBarLabel = string.format("Divination %d  |  %s/hr", level, formatNumber(xpPerHour))
    else
        guiData.metricsBarMaxLevel = false
        local nextLevelXP = API.XPForLevel(level + 1)
        local currentLevelXP = API.XPForLevel(level)
        local levelRange = nextLevelXP - currentLevelXP
        local progress = levelRange > 0 and ((currentXP - currentLevelXP) / levelRange) or 0
        local xpRemaining = nextLevelXP - currentXP
        local ttl = xpPerHour > 0 and (xpRemaining / xpPerHour) * 3600 or 0

        guiData.metricsBarProgress = progress

        local ttlText
        if ttl <= 0 then
            ttlText = "--"
        else
            local hours = math.floor(ttl / 3600)
            local ttlMins = math.floor((ttl % 3600) / 60)
            if hours > 0 then
                ttlText = string.format("%dh %02dm", hours, ttlMins)
            else
                local ttlSecs = math.floor(ttl % 60)
                ttlText = string.format("%dm %02ds", ttlMins, ttlSecs)
            end
        end

        guiData.metricsBarLabel = string.format("Divination %d (%.0f%%)  |  %s  |  %s/hr",
            level, progress * 100, ttlText, formatNumber(xpPerHour))
    end

    guiData.title = string.format("%s | %s###Diviner", guiData.state, API.ScriptRuntimeString())
end

ClearRender()
DrawImGui(function()
    if DivGUI.open then
        local now = os.clock()
        if now - lastGUIUpdate >= 0.5 then
            buildGUIData()
            lastGUIUpdate = now
        end
        DivGUI.draw(guiData)
    end
end)

local success, err = pcall(function()
    while API.Read_LoopyLoop() do
        if not idleHandler.check() then break end
        idleHandler.collectGarbage()

        if not Utils.checkLocation(wispDef) then
            API.printlua("Moved too far from rift - terminating", 4, false)
            break
        end

        Utils.updateTracking(wispDef, tracking)

        local shouldInteract = false

        if state.shouldSwitchToEnriched then
            state.shouldSwitchToEnriched = false
            shouldInteract = true
        elseif API.ReadPlayerAnim() ~= DATA.IDS.SIPHON_ANIM then
            shouldInteract = true
        end

        if shouldInteract then
            if manualDeposit and Inventory:IsFull() then
                local memCount = Inventory:GetItemAmount(wispDef.memoryId)
                local enrichedCount = wispDef.enrichedMemoryId and Inventory:GetItemAmount(wispDef.enrichedMemoryId) or 0
                if memCount > 0 or enrichedCount > 0 then
                    state.currentState = "Depositing"
                    Utils.depositMemories(wispDef)
                end
            end
            Utils.findAndInteractWisp(wispDef, state, tracking)
        end

        API.RandomSleep2(100, 150, 100)
    end
end)

if not success then
    API.printlua("Error in main loop: " .. tostring(err), 4, false)
end

ClearRender()
API.printlua("Script terminated.", 0, false)
