--[[
    Dragonkin V Farmer
    Modernized Dragonkin archaeology token farmer with a tabbed ImGui shell,
    API-randomized waits, runtime state visibility, and optional artifact redemption.
--]]

local API = require("api")

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)
math.randomseed(os.time())

local SCRIPT_NAME = "Dragonkin V Farmer"
local NO_XP_FAILSAFE_SECONDS = 300

local IDS = {
    archFocus = 7307,
    completeTome = 49976,
    banker = 9710,
    sharrigan = 27287,
    totem = 56975,
    mine = 56977,
    ring = 56973,
    gatestone = 56971,
    bankChest = 114022,
    workbench = 115421,
    chronote = 49430,
    tokenBox = 36093,
    gote = 44550,
    porterBuff = 51490,
}

local REPAIR_ITEMS = {
    { label = "Excavator portal mine", id = 56977 },
    { label = "Castle gatestone", id = 56971 },
    { label = "Engraved ring of kingship", id = 56973 },
    { label = "Exploratory totem", id = 56975 },
}

local ARTIFACT_IDS = { IDS.gatestone, IDS.ring, IDS.totem, IDS.mine }

-- Restored Artifacts for Standalone Redemption:
-- 56972 = Castle gatestone
-- 56974 = Engraved ring of kinship
-- 56976 = Exploratory totem
-- 56978 = Excavator portal mine
local RESTORED_ARTIFACT_IDS = { 56972, 56974, 56976, 56978 }
local ARTIFACT_INTERFACE_SLOTS = { 1, 5, 9, 13 }
local PORTER_IDS = { 51490, 29285, 29283, 29281, 29279, 29277, 29275 }
local SPOT_IDS = { 130307, 130309 }
local EXCAVATION_LOOP_ANIMS = {
    [33294] = true,
    [33295] = true,
    [33297] = true,
}
local START_SPOT_OPTIONS = {
    "Castle hall rubble",
    "Tunnelling equipment repository",
}
local SPOT_LABELS = {
    [130307] = "Castle hall rubble",
    [130309] = "Tunnelling equipment repository",
}
local STATE = {
    IDLE = "IDLE",
    EXCAVATING = "EXCAVATING",
    BANKING = "BANKING",
    WORLD_HOPPING = "WORLD_HOPPING",
    TRAVEL_ANACHRONIA = "TRAVEL_ANACHRONIA",
    WITHDRAWING_ARTIFACTS = "WITHDRAWING_ARTIFACTS",
    RESTORING_ARTIFACTS = "RESTORING_ARTIFACTS",
    TURNING_IN_ARTIFACTS = "TURNING_IN_ARTIFACTS",
    TRAVEL_DAEMONHEIM = "TRAVEL_DAEMONHEIM",
    REPAIRING = "REPAIRING",
    STOPPED = "STOPPED",
}

local CONFIG = {
    startSpotIndex = 1,
    redeemArtifacts = true,
    enableTimedWorldHop = false,
    worldHopMinMinutes = 18,
    worldHopMaxMinutes = 32,
    enableNearbyPlayerHop = false,
    nearbyPlayerHopRadius = 10,
    bankIncrement = 1,
    porterRechargeThreshold = 1000,
    repairSelectedIndex = 1,
    repairAmount = 1,
    repairQueue = {},
    enableRedeemTarget = false,
    redeemTargetAmount = 0,
    loopDelayCenter = 260,
    loopDelaySpread = 110,
    debugLogs = false,
}

local RUNTIME = {
    started = false,
    state = STATE.IDLE,
    status = "Waiting to start",
    stopReason = "",
    spotIndex = 1,
    iteration = 1,
    clickedSpotTile = nil,
    scriptStartTime = 0,
    collections = {
        totem = 0,
        mine = 0,
        ring = 0,
        gatestone = 0,
    },
    currentAction = "Idle",
    porterStatus = "Unknown",
    lastError = "",
    worldHops = 0,
    nextWorldHopAt = 0,
    lastWorldHopReason = "None",
    lastWorldHopTarget = 0,
    lastWorldHopLanded = 0,
    lastWorldHopDiagnostic = "",
    lastWorldHopBlockLogAt = 0,
    hopPending = false,
    hopPendingReason = "",
    hopFailCount = 0,
    lastPorterTopUpAt = 0,
    lastObservedArchXp = 0,
    lastXpGainAt = 0,
    lastActionKey = "",
    sameActionCount = 0,
    lastProgressAt = 0,
    presetResetInitialized = false,
    nextSpriteDecisionAt = 0,
    lastExcavationScanLogAt = 0,
    goteChargeFailCount = 0,
    lastGoteChargeAt = 0,
    inventoryArrayNullRecoveries = 0,
    lastInventoryArrayNullLogAt = 0,
    lastInventoryRepairAt = 0,
    repairActive = false,
    repairOnlyMode = false,
    redeemOnlyMode = false,
    totalRedeemed = 0,
    repairQueueIndex = 1,
    repairCompleted = 0,
    repairStatus = "Idle",
}

local Gui = {
    open = true,
    repairQueueMessage = "",
}

local THEME = {
    dark = { 0.07, 0.04, 0.03 },
    medium = { 0.19, 0.10, 0.06 },
    light = { 0.34, 0.18, 0.08 },
    bright = { 0.59, 0.32, 0.10 },
    glow = { 0.92, 0.60, 0.18 },
    accent = { 0.88, 0.76, 0.54 },
}

local function log(message)
    print(string.format("[%s] %s", SCRIPT_NAME, tostring(message)))
end

local function logError(message)
    RUNTIME.lastError = tostring(message or "")
    print(string.format("[%s][ERROR] %s", SCRIPT_NAME, tostring(message)))
end

local function debugLog(message)
    if CONFIG.debugLogs then
        print(string.format("[%s][DEBUG] %s", SCRIPT_NAME, tostring(message)))
    end
end

local function getCharacterName()
    if API and type(API.GetLocalPlayerName) == "function" then
        local name = API.GetLocalPlayerName()
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return "default"
end

local function resolveConfigPath()
    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*)[/\\][^/\\]+$")
    if not dir then
        return "dragonkin-v-farmer-default.config.json"
    end
    return dir .. "\\configs\\dragonkin-v-farmer-" .. getCharacterName() .. ".config.json"
end

local CONFIG_PATH = resolveConfigPath()

local function clampInteger(value, minimum, maximum, fallback)
    local number = math.floor(tonumber(value) or fallback or minimum or 0)
    if minimum and number < minimum then
        number = minimum
    end
    if maximum and number > maximum then
        number = maximum
    end
    return number
end

local function repairItemById(itemId)
    local id = tonumber(itemId)
    for _, item in ipairs(REPAIR_ITEMS) do
        if item.id == id then
            return item
        end
    end
    return nil
end

local function repairItemByIndex(index)
    return REPAIR_ITEMS[clampInteger(index, 1, #REPAIR_ITEMS, 1)]
end

local function repairItemLabels()
    local labels = {}
    for _, item in ipairs(REPAIR_ITEMS) do
        labels[#labels + 1] = item.label
    end
    return labels
end

local function normalizeRepairQueue(queue)
    local normalized = {}
    if type(queue) ~= "table" then
        return normalized
    end

    for _, entry in ipairs(queue) do
        if type(entry) == "table" then
            local item = repairItemById(entry.itemId or entry.ItemId)
            local amount = clampInteger(entry.amount or entry.Amount, 1, 100000, 1)
            if item then
                normalized[#normalized + 1] = {
                    itemId = item.id,
                    amount = amount,
                }
            end
        end
    end
    return normalized
end

local function sanitizeConfig()
    CONFIG.startSpotIndex = clampInteger(CONFIG.startSpotIndex, 1, #START_SPOT_OPTIONS, 1)
    CONFIG.worldHopMinMinutes = clampInteger(CONFIG.worldHopMinMinutes, 1, 180, 18)
    CONFIG.worldHopMaxMinutes = clampInteger(CONFIG.worldHopMaxMinutes, CONFIG.worldHopMinMinutes, 240, 32)
    CONFIG.nearbyPlayerHopRadius = clampInteger(CONFIG.nearbyPlayerHopRadius, 1, 40, 10)
    CONFIG.bankIncrement = clampInteger(CONFIG.bankIncrement, 1, 20, 1)
    CONFIG.porterRechargeThreshold = clampInteger(CONFIG.porterRechargeThreshold, 0, 2000, 1000)
    CONFIG.repairSelectedIndex = clampInteger(CONFIG.repairSelectedIndex, 1, #REPAIR_ITEMS, 1)
    CONFIG.repairAmount = clampInteger(CONFIG.repairAmount, 1, 100000, 1)
    CONFIG.repairQueue = normalizeRepairQueue(CONFIG.repairQueue)
    CONFIG.loopDelayCenter = clampInteger(CONFIG.loopDelayCenter, 50, 3000, 260)
    CONFIG.loopDelaySpread = clampInteger(CONFIG.loopDelaySpread, 0, 1200, 110)
end

local function loadConfigFromFile()
    local file = io.open(CONFIG_PATH, "r")
    if not file then
        return
    end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then
        return
    end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or type(data) ~= "table" then
        return
    end

    CONFIG.startSpotIndex = data.StartSpotIndex or CONFIG.startSpotIndex
    CONFIG.redeemArtifacts = data.RedeemArtifacts ~= false
    CONFIG.enableTimedWorldHop = data.EnableTimedWorldHop == true
    CONFIG.worldHopMinMinutes = data.WorldHopMinMinutes or CONFIG.worldHopMinMinutes
    CONFIG.worldHopMaxMinutes = data.WorldHopMaxMinutes or CONFIG.worldHopMaxMinutes
    CONFIG.enableNearbyPlayerHop = data.EnableNearbyPlayerHop == true
    CONFIG.nearbyPlayerHopRadius = data.NearbyPlayerHopRadius or CONFIG.nearbyPlayerHopRadius
    CONFIG.bankIncrement = data.BankIncrement or CONFIG.bankIncrement
    CONFIG.porterRechargeThreshold = data.PorterRechargeThreshold or CONFIG.porterRechargeThreshold
    CONFIG.enableRedeemTarget = data.EnableRedeemTarget == true
    CONFIG.redeemTargetAmount = data.RedeemTargetAmount or CONFIG.redeemTargetAmount
    CONFIG.repairSelectedIndex = data.RepairSelectedIndex or CONFIG.repairSelectedIndex
    CONFIG.repairAmount = data.RepairAmount or CONFIG.repairAmount
    CONFIG.repairQueue = data.RepairQueue or CONFIG.repairQueue
    CONFIG.loopDelayCenter = data.LoopDelayCenter or CONFIG.loopDelayCenter
    CONFIG.loopDelaySpread = data.LoopDelaySpread or CONFIG.loopDelaySpread
    CONFIG.debugLogs = data.DebugLogs == true
    sanitizeConfig()
end

local function saveConfigToFile()
    sanitizeConfig()
    local payload = {
        StartSpotIndex = CONFIG.startSpotIndex,
        RedeemArtifacts = CONFIG.redeemArtifacts,
        EnableTimedWorldHop = CONFIG.enableTimedWorldHop,
        WorldHopMinMinutes = CONFIG.worldHopMinMinutes,
        WorldHopMaxMinutes = CONFIG.worldHopMaxMinutes,
        EnableNearbyPlayerHop = CONFIG.enableNearbyPlayerHop,
        NearbyPlayerHopRadius = CONFIG.nearbyPlayerHopRadius,
        BankIncrement = CONFIG.bankIncrement,
        EnableRedeemTarget = CONFIG.enableRedeemTarget,
        RedeemTargetAmount = CONFIG.redeemTargetAmount,
        PorterRechargeThreshold = CONFIG.porterRechargeThreshold,
        RepairSelectedIndex = CONFIG.repairSelectedIndex,
        RepairAmount = CONFIG.repairAmount,
        RepairQueue = CONFIG.repairQueue,
        LoopDelayCenter = CONFIG.loopDelayCenter,
        LoopDelaySpread = CONFIG.loopDelaySpread,
        DebugLogs = CONFIG.debugLogs,
    }

    local ok, json = pcall(API.JsonEncode, payload)
    if not ok or not json then
        return false
    end

    local file = io.open(CONFIG_PATH, "w")
    if not file then
        return false
    end
    file:write(json)
    file:close()
    return true
end

function Gui.loadConfig()
    loadConfigFromFile()
end

function Gui.saveConfig()
    local saved = saveConfigToFile()
    if not saved then
        logError("Failed to save config")
    end
    return saved
end

local function setState(nextState, status)
    if RUNTIME.state ~= nextState then
        debugLog("State transition: " .. tostring(RUNTIME.state) .. " -> " .. tostring(nextState))
    end
    RUNTIME.state = nextState
    if status then
        RUNTIME.status = status
    end
end

local stopRun
local checkActionLoopFailsafe
local isGameStateReady

local function setAction(action)
    local newAction = tostring(action or "Idle")
    if RUNTIME.currentAction ~= newAction then
        debugLog("Action transition: " .. tostring(RUNTIME.currentAction) .. " -> " .. newAction)
    end
    RUNTIME.currentAction = newAction
    if type(checkActionLoopFailsafe) == "function" then
        checkActionLoopFailsafe()
    end
end

local function getArchaeologyXp()
    return tonumber(API.GetSkillXP("ARCHAEOLOGY") or 0) or 0
end

local function markProgress(reason)
    RUNTIME.lastProgressAt = os.time()
    RUNTIME.lastActionKey = ""
    RUNTIME.sameActionCount = 0
end

local function actionLoopLimit(action)
    local current = tostring(action or "")
    if current == "Destroying tomes" then
        return 6
    end
    if current == "Charge all porters" then
        return 4
    end
    if current:find("Loading Dragonkin preset", 1, true) then
        return 3
    end
    if current == "Teleporting to Daemonheim" then
        return 3
    end
    if current == "Opening War's Retreat bank" then
        return 4
    end
    return nil
end

checkActionLoopFailsafe = function()
    local action = tostring(RUNTIME.currentAction or "")
    local limit = actionLoopLimit(action)
    if not limit then
        return false
    end

    if RUNTIME.lastActionKey == action then
        RUNTIME.sameActionCount = (tonumber(RUNTIME.sameActionCount) or 0) + 1
    else
        RUNTIME.lastActionKey = action
        RUNTIME.sameActionCount = 1
    end

    if RUNTIME.sameActionCount > limit then
        stopRun("Failsafe: no progress while " .. action)
        return true
    end

    return false
end

local function checkNoXpFailsafe()
    local currentXp = getArchaeologyXp()
    if currentXp > (tonumber(RUNTIME.lastObservedArchXp) or 0) then
        RUNTIME.lastObservedArchXp = currentXp
        RUNTIME.lastXpGainAt = os.time()
        markProgress("Archaeology XP gained")
        return false
    end

    if not RUNTIME.started then
        return false
    end

    if (os.time() - (tonumber(RUNTIME.lastXpGainAt) or os.time())) >= NO_XP_FAILSAFE_SECONDS then
        stopRun("Failsafe: no Archaeology XP gained for 5 minutes")
        return true
    end

    return false
end

local function delay(center, spread, label)
    local wait = tonumber(center) or 0
    local variance = tonumber(spread) or 0
    API.RandomSleep2(wait, variance, variance)
end

local function loopDelay()
    delay(CONFIG.loopDelayCenter, CONFIG.loopDelaySpread, 0)
end

local function waitUntil(predicate, timeoutSeconds, pollMs)
    local timeout = tonumber(timeoutSeconds) or 5
    local deadline = os.time() + math.max(1, math.ceil(timeout))
    local poll = tonumber(pollMs) or 150

    while API.Read_LoopyLoop() and os.time() < deadline do
        if RUNTIME.started and type(checkNoXpFailsafe) == "function" and checkNoXpFailsafe() then
            return false
        end

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

local function isMoving()
    if type(API.ReadPlayerMovin2) == "function" then
        return API.ReadPlayerMovin2() == true
    end
    return false
end

local function isAnimating()
    return API.CheckAnim(50) == true
end

local function getCurrentAnimation()
    return tonumber(API.ReadPlayerAnim and API.ReadPlayerAnim()) or 0
end

local function isExcavationLoopAnimation()
    return EXCAVATION_LOOP_ANIMS[getCurrentAnimation()] == true
end

local function waitForStillness()
    if type(API.WaitUntilMovingandAnimEnds) == "function" then
        pcall(API.WaitUntilMovingandAnimEnds, 6, 8)
    end
    return waitUntil(function()
        return not isMoving() and not API.isProcessing() and not isAnimating()
    end, 60, 180)
end

local function waitAfterPresetReload()
    if type(API.WaitUntilMovingEnds) == "function" then
        pcall(API.WaitUntilMovingEnds, 600, 5)
    end
end

local function waitAfterExcavationClick()
    if type(API.WaitUntilMovingEnds) == "function" then
        pcall(API.WaitUntilMovingEnds, 600, 5)
    end
end

local function scheduleNextWorldHop()
    if CONFIG.enableTimedWorldHop ~= true then
        RUNTIME.nextWorldHopAt = 0
        return
    end

    local minMinutes = math.max(1, tonumber(CONFIG.worldHopMinMinutes) or 18)
    local maxMinutes = math.max(minMinutes, tonumber(CONFIG.worldHopMaxMinutes) or minMinutes)
    RUNTIME.nextWorldHopAt = os.time() + (math.random(minMinutes, maxMinutes) * 60)
end

local function nextWorldHopLabel()
    if RUNTIME.nextWorldHopAt <= 0 then
        return "Off"
    end

    local remaining = math.max(0, RUNTIME.nextWorldHopAt - os.time())
    local minutes = math.floor(remaining / 60)
    local seconds = remaining % 60
    return string.format("%02d:%02d", minutes, seconds)
end

local function getPlayerCoord()
    local coord = API.PlayerCoord and API.PlayerCoord()
    if not coord then
        return nil, nil, nil
    end
    return tonumber(coord.x), tonumber(coord.y), tonumber(coord.z)
end

local function isInventoryArrayNull()
    if not Inventory or type(Inventory.IsArrayNull) ~= "function" then
        return false
    end

    local ok, isNull = pcall(function()
        return Inventory:IsArrayNull()
    end)
    return ok and isNull == true
end

local function openInventoryTabForRepair()
    if Inventory and type(Inventory.IsOpen) == "function" then
        local ok, isOpen = pcall(function()
            return Inventory:IsOpen()
        end)
        if ok and isOpen == true then
            return true
        end
    end

    if API.DoAction_Interface then
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1432, 5, 1, API.OFF_ACT_GeneralInterface_route)
        delay(360, 120, 0)
    end
    return true
end

local function repairInventoryArray(context, timeoutSeconds, nudgeItemId)
    if not isInventoryArrayNull() then
        return true
    end

    if not isGameStateReady() then
        return false
    end

    local now = os.time()
    if now - (RUNTIME.lastInventoryArrayNullLogAt or 0) >= 3 then
        RUNTIME.lastInventoryArrayNullLogAt = now
        log("Inventory array is null during " .. tostring(context or "inventory read") .. "; opening inventory tab and waiting for client rebuild")
    end

    RUNTIME.inventoryArrayNullRecoveries = (RUNTIME.inventoryArrayNullRecoveries or 0) + 1
    RUNTIME.lastInventoryRepairAt = now
    openInventoryTabForRepair()

    if nudgeItemId and Bank and type(Bank.IsOpen) == "function" and type(Bank.Withdraw) == "function" then
        local okBankOpen, bankOpen = pcall(function()
            return Bank:IsOpen()
        end)
        if okBankOpen and bankOpen == true and isInventoryArrayNull() then
            log("Inventory array still null; withdrawing one item to force client inventory rebuild")
            pcall(function()
                Bank:Withdraw(nudgeItemId, 1)
            end)
            delay(260, 90, 0)
        end
    end

    local timeout = math.max(1, math.ceil(tonumber(timeoutSeconds) or 3))
    local deadline = os.time() + timeout
    while API.Read_LoopyLoop() and os.time() < deadline do
        if not isInventoryArrayNull() then
            log("Inventory array rebuilt after " .. tostring(context or "inventory read"))
            return true
        end
        API.RandomSleep2(160, 50, 35)
    end

    return not isInventoryArrayNull()
end

local function inventoryReady(context, timeoutSeconds)
    return repairInventoryArray(context, timeoutSeconds) == true
end

local function inventoryReadyWithBankNudge(context, timeoutSeconds, nudgeItemId)
    return repairInventoryArray(context, timeoutSeconds, nudgeItemId) == true
end

local function safeInvFreeCount(context)
    if not inventoryReady(context or "free slot count", 2.0) then
        return nil
    end
    local ok, count = pcall(function()
        return Inventory:Invfreecount()
    end)
    if not ok then
        log("Inventory free count failed during " .. tostring(context or "inventory read") .. ": " .. tostring(count))
        return nil
    end
    return tonumber(count)
end

local function safeInvItemCount(itemId, context)
    if not inventoryReady(context or ("item count " .. tostring(itemId)), 2.0) then
        return 0
    end
    local ok, count = pcall(function()
        return Inventory:InvItemcount(itemId)
    end)
    if not ok then
        log("Inventory item count failed during " .. tostring(context or "inventory read") .. ": " .. tostring(count))
        return 0
    end
    return tonumber(count) or 0
end

local function safeInventoryIsFull(context)
    if not inventoryReady(context or "full inventory check", 2.0) then
        return nil
    end
    local ok, isFull = pcall(function()
        return Inventory:IsFull()
    end)
    if not ok then
        log("Inventory full check failed during " .. tostring(context or "inventory read") .. ": " .. tostring(isFull))
        return nil
    end
    return isFull == true
end

local function isInventoryRowsArray(rows)
    return type(rows) == "table" or type(rows) == "userdata"
end

local function copyInventoryRows(rows)
    local copied = {}
    if not isInventoryRowsArray(rows) then
        return copied
    end

    for _, row in ipairs(rows) do
        copied[#copied + 1] = row
    end
    return copied
end

local function getInventoryRows()
    if not inventoryReady("raw inventory rows", 2.0) then
        return {}
    end
    if type(API.ReadInvArrays33) == "function" then
        local ok, rows = pcall(API.ReadInvArrays33)
        if ok and isInventoryRowsArray(rows) then
            return copyInventoryRows(rows)
        end
        if not ok then
            log("Raw inventory read failed: " .. tostring(rows))
        else
            log("Raw inventory read returned unsupported type: " .. type(rows) .. " value=" .. tostring(rows))
        end
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

local function isNearTile(tile, radius)
    local px, py, pz = getPlayerCoord()
    if not px or type(tile) ~= "table" then
        return false
    end

    local r = math.max(0, tonumber(radius) or 0)
    if math.abs(px - tile.x) > r or math.abs(py - tile.y) > r then
        return false
    end

    if tile.z == nil then
        return true
    end

    return tonumber(pz) == tonumber(tile.z)
end

local function safeField(obj, key)
    if obj == nil or type(key) ~= "string" then
        return nil
    end
    local t = type(obj)
    if t ~= "table" and t ~= "userdata" then
        return nil
    end
    local ok, value = pcall(function()
        return obj[key]
    end)
    if ok then
        return value
    end
    return nil
end

local function tileCoord(tile, lowerKey, upperKey)
    local value = safeField(tile, lowerKey) or safeField(tile, upperKey)
    return tonumber(value)
end

local function formatTile(tile)
    local x = tileCoord(tile, "x", "X")
    local y = tileCoord(tile, "y", "Y")
    local z = tileCoord(tile, "z", "Z") or 0
    if not x or not y then
        return "nil"
    end
    return string.format("%s,%s,%s", tostring(x), tostring(y), tostring(z))
end

local function tilesMatch(a, b)
    local ax = tileCoord(a, "x", "X")
    local ay = tileCoord(a, "y", "Y")
    local az = tileCoord(a, "z", "Z") or 0
    local bx = tileCoord(b, "x", "X")
    local by = tileCoord(b, "y", "Y")
    local bz = tileCoord(b, "z", "Z") or 0
    if not ax or not ay or not bx or not by then
        return false
    end
    return math.abs(ax - bx) < 0.01
        and math.abs(ay - by) < 0.01
        and math.abs(az - bz) < 0.01
end

local function objField(obj, key)
    return safeField(obj, key)
end

local function objTileXYZ(obj)
    local tile = objField(obj, "Tile_XYZ") or objField(obj, "tile_xyz") or objField(obj, "TileXYZ")
    if type(tile) ~= "table" and type(tile) ~= "userdata" then
        return nil
    end
    local x = objField(tile, "x") or objField(tile, "X")
    local y = objField(tile, "y") or objField(tile, "Y")
    local z = objField(tile, "z") or objField(tile, "Z")
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return {
        x = x,
        y = y,
        z = type(z) == "number" and z or 0,
    }
end

local function isObjectArray(objects)
    return type(objects) == "table" or type(objects) == "userdata"
end

local function copyObjectArray(objects)
    local copied = {}
    if not isObjectArray(objects) then
        return copied
    end

    for _, object in ipairs(objects) do
        copied[#copied + 1] = object
    end
    return copied
end

local function isAtDaemonheimDigArea()
    if #API.GetAllObjArray1({ IDS.banker }, 50, { 1 }) > 0 then
        return true
    end

    local spots = copyObjectArray(API.GetAllObjArrayInteract({ SPOT_IDS[1], SPOT_IDS[2] }, 30, { 0, 1, 12 }))
    return #spots > 0
end

local function isAtFremennikBanker()
    return #API.GetAllObjArray1({ IDS.banker }, 50, { 1 }) > 0
end

local function shouldTimedHopNow()
    return CONFIG.enableTimedWorldHop == true
        and RUNTIME.nextWorldHopAt > 0
        and os.time() >= RUNTIME.nextWorldHopAt
end

local function shouldNearbyPlayerHopNow()
    if CONFIG.enableNearbyPlayerHop ~= true or not isAtDaemonheimDigArea() then
        return false
    end

    local radius = math.max(1, tonumber(CONFIG.nearbyPlayerHopRadius) or 10)
    local players = API.GetAllObjArrayInteract({ 0 }, radius, { 2 }) or {}
    return #players > 0
end

local function lodestoneInterfaceOpen()
    local lodestoneState = API.VB_FindPSettinOrder and API.VB_FindPSettinOrder(2874, 1)
    return (#API.ScanForInterfaceTest2Get(true, { { 1092, 1, -1, -1, 0 }, { 1092, 54, -1, 1, 0 } }) > 0)
        or (lodestoneState and lodestoneState.state == 30)
        or (API.Compare2874Status and API.Compare2874Status(30))
end

local function workInterfaceOpen()
    return #API.ScanForInterfaceTest2Get(true, { { 1371, 7, -1, 0 } }) > 0
end

local function sharriganInterfaceOpen()
    return #API.ScanForInterfaceTest2Get(true, { { 656, 3, -1, 0 } }) > 0
end

local function worldHopBlockReason()
    if isMoving() then
        return "moving"
    end
    if API.isProcessing() then
        return "processing"
    end
    if isAnimating() and not isExcavationLoopAnimation() then
        return "non-excavation animation " .. tostring(getCurrentAnimation())
    end
    if Bank:IsOpen() then
        return "bank open"
    end
    if lodestoneInterfaceOpen() then
        return "lodestone interface open"
    end
    if workInterfaceOpen() then
        return "workbench interface open"
    end
    if sharriganInterfaceOpen() then
        return "Sharrigan interface open"
    end
    if RUNTIME.state == STATE.BANKING
        or RUNTIME.state == STATE.TRAVEL_ANACHRONIA
        or RUNTIME.state == STATE.WITHDRAWING_ARTIFACTS
        or RUNTIME.state == STATE.RESTORING_ARTIFACTS
        or RUNTIME.state == STATE.TURNING_IN_ARTIFACTS
        or RUNTIME.state == STATE.TRAVEL_DAEMONHEIM
    then
        return "state " .. tostring(RUNTIME.state)
    end
    return nil
end

local function isSafeToWorldHop()
    return worldHopBlockReason() == nil
end

local function queueWorldHop(reason)
    RUNTIME.hopPending = true
    RUNTIME.hopPendingReason = tostring(reason or "Scheduled")
    RUNTIME.lastWorldHopReason = RUNTIME.hopPendingReason

    local now = os.time()
    if now - (tonumber(RUNTIME.lastWorldHopBlockLogAt) or 0) >= 5 then
        RUNTIME.lastWorldHopBlockLogAt = now
        log("World hop pending: " .. RUNTIME.hopPendingReason .. " blocked by " .. tostring(worldHopBlockReason() or "unknown"))
    end
end

local function getCurrentWorldSafe()
    if WorldHop and type(WorldHop.GetCurrentWorld) == "function" then
        local ok, world = pcall(function()
            return WorldHop:GetCurrentWorld()
        end)
        if ok and tonumber(world) and tonumber(world) > 0 then
            return tonumber(world)
        end
    end

    if API and type(API.GetWorldNR) == "function" then
        local ok, world = pcall(function()
            return API.GetWorldNR()
        end)
        if ok and tonumber(world) and tonumber(world) > 0 then
            return tonumber(world)
        end
    end

    return 0
end

isGameStateReady = function()
    if type(API.PlayerLoggedIn) == "function" and API.PlayerLoggedIn() ~= true then
        return false
    end
    if type(API.GetGameState2) == "function" and tonumber(API.GetGameState2()) ~= 3 then
        return false
    end
    return true
end

local function settleAfterWorldHop(previousWorld)
    if previousWorld > 0 then
        local worldChanged = waitUntil(function()
            local worldNow = getCurrentWorldSafe()
            return worldNow > 0 and worldNow ~= previousWorld
        end, 20, 170)
        if not worldChanged then
            return false
        end
    end

    if not waitUntil(function()
        return isGameStateReady()
    end, 20, 180) then
        return false
    end

    local settled = waitUntil(function()
        return isGameStateReady()
            and not isMoving()
            and not isAnimating()
            and not API.isProcessing()
    end, 8.0, 140)

    if not settled then
        return false
    end

    delay(600, 180, 0)
    return true
end

local function performWorldHop(reason)
    setState(STATE.WORLD_HOPPING, "World hopping")
    setAction("World hopping")

    local previousWorld = getCurrentWorldSafe()
    local targetWorld = 0
    if WorldHop and type(WorldHop.GetRandomWorld) == "function" then
        local okRandom, randomWorld = pcall(function()
            return WorldHop:GetRandomWorld(true)
        end)
        if okRandom then
            targetWorld = tonumber(randomWorld) or 0
        end
    end

    if targetWorld <= 0 or targetWorld == previousWorld then
        logError("Could not resolve a target world for native API hop")
        scheduleNextWorldHop()
        return false
    end

    local ok = false
    if WorldHop and type(WorldHop.Hop) == "function" then
        local okHop, hopResult = pcall(function()
            return WorldHop:Hop(targetWorld)
        end)
        ok = okHop and hopResult == true
    end

    local landedWorld = getCurrentWorldSafe()
    landedWorld = tonumber(landedWorld) or getCurrentWorldSafe()
    RUNTIME.lastWorldHopTarget = tonumber(targetWorld) or 0
    RUNTIME.lastWorldHopLanded = landedWorld
    RUNTIME.lastWorldHopDiagnostic = string.format(
        "previous=%d target=%d landed=%d ok=%s api=native",
        previousWorld,
        RUNTIME.lastWorldHopTarget,
        landedWorld,
        tostring(ok)
    )

    if not ok then
        RUNTIME.hopFailCount = RUNTIME.hopFailCount + 1
        logError("World hop failed: " .. RUNTIME.lastWorldHopDiagnostic)
        scheduleNextWorldHop()
        return false
    end

    if not settleAfterWorldHop(previousWorld) then
        RUNTIME.hopFailCount = RUNTIME.hopFailCount + 1
        logError("World hop did not settle: " .. RUNTIME.lastWorldHopDiagnostic)
        scheduleNextWorldHop()
        return false
    end

    if not inventoryReady("post world-hop inventory rebuild", 6.0) then
        RUNTIME.hopFailCount = RUNTIME.hopFailCount + 1
        logError("World hop inventory array did not rebuild: " .. RUNTIME.lastWorldHopDiagnostic)
        scheduleNextWorldHop()
        return false
    end

    RUNTIME.worldHops = RUNTIME.worldHops + 1
    RUNTIME.hopFailCount = 0
    RUNTIME.hopPending = false
    RUNTIME.hopPendingReason = ""
    RUNTIME.lastWorldHopReason = tostring(reason or "World hop")
    RUNTIME.clickedSpotTile = nil
    scheduleNextWorldHop()
    setState(STATE.TRAVEL_DAEMONHEIM, "World hop complete")
    setAction("Reacquiring Daemonheim spot")
    log("World hop settled: " .. RUNTIME.lastWorldHopDiagnostic)
    return true
end

local function handleWorldHopRequests()
    local reason = nil

    if shouldNearbyPlayerHopNow() then
        reason = "Nearby player"
    elseif shouldTimedHopNow() then
        reason = "Timed hop"
    elseif RUNTIME.hopPending then
        reason = RUNTIME.hopPendingReason
    end

    if not reason then
        return false
    end

    if not isSafeToWorldHop() then
        queueWorldHop(reason)
        return false
    end

    return performWorldHop(reason)
end

local function guiInvItemCount(itemId)
    if not Inventory or type(Inventory.InvItemcount) ~= "function" then return 0 end
    if type(Inventory.IsArrayNull) == "function" then
        local ok, isNull = pcall(function() return Inventory:IsArrayNull() end)
        if not ok or isNull then return 0 end
    end
    local ok, count = pcall(function() return Inventory:InvItemcount(itemId) end)
    if ok then return tonumber(count) or 0 end
    return 0
end

local function getCollectionsPerHour()
    local totalCollections = (RUNTIME.collections.ring + guiInvItemCount(IDS.ring))
        + (RUNTIME.collections.gatestone + guiInvItemCount(IDS.gatestone))
        + (RUNTIME.collections.totem + guiInvItemCount(IDS.totem))
        + (RUNTIME.collections.mine + guiInvItemCount(IDS.mine))
    local runtimeSeconds = math.max(1, tonumber(API.ScriptRuntime()) or 0)
    return totalCollections / (runtimeSeconds / 3600.0)
end

local function formatElapsed(seconds)
    local total = math.max(0, tonumber(seconds) or 0)
    local h = math.floor(total / 3600)
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function runtimeLabel()
    if RUNTIME.scriptStartTime <= 0 then
        return "00:00:00"
    end
    return formatElapsed(os.difftime(os.time(), RUNTIME.scriptStartTime))
end

local function artifactFoundInterfacePresent()
    return #API.ScanForInterfaceTest2Get(true, { { 1189, 2, -1, 0 } }) > 0
end

local function getPorter()
    for _, id in ipairs(PORTER_IDS) do
        if safeInvItemCount(id, "porter scan") > 0 then
            return id
        end
    end
    return nil
end

local function getItemId(item)
    return item and tonumber(item.item_id or item.itemid1 or item.itemid or item.id or item.itemId or 0) or 0
end

local function getPorterBuffState()
    local buff = API.Buffbar_GetIDstatus(IDS.porterBuff, false)
    if not (buff and buff.found) then
        return false, 0
    end
    return true, tonumber(buff.text) or 0
end

local function useActionBarAbility(abilityName, action)
    if type(API.DoAction_Ability) ~= "function" then
        return false
    end

    local actionType = tonumber(action) or 1
    local ok, used = pcall(API.DoAction_Ability, abilityName, actionType, API.OFF_ACT_GeneralInterface_route, true)
    if ok and used == true then
        return true
    end

    ok, used = pcall(API.DoAction_Ability, abilityName, actionType, API.OFF_ACT_GeneralInterface_route, false)
    return ok and used == true
end

local function useGraceOfTheElvesAbility()
    return useActionBarAbility("Grace of the elves", 5)
end

local function updatePorterStatus()
    local buffStatus = API.Buffbar_GetIDstatus(IDS.porterBuff, false)
    if buffStatus and buffStatus.found and buffStatus.text then
        RUNTIME.porterStatus = "GOTE: " .. tostring(buffStatus.text)
    else
        local porterId = getPorter()
        if porterId then
            RUNTIME.porterStatus = "Porter ready: " .. tostring(porterId)
        else
            RUNTIME.porterStatus = "Out of porters"
        end
    end
end

local function getEquippedNecklaceContainer()
    local containers = API.Container_Get_all and API.Container_Get_all(94)
    if type(containers) ~= "table" then
        return nil
    end

    local slot2 = containers[2]
    local slot3 = containers[3]
    local slot2Id = getItemId(slot2)
    local slot3Id = getItemId(slot3)

    if slot2Id == IDS.gote then
        return slot2
    end
    if slot3Id == IDS.gote then
        return slot3
    end

    local equipped = API.ReadEquipment and API.ReadEquipment()
    if type(equipped) == "table" then
        for _, equippedItem in ipairs(equipped) do
            if getItemId(equippedItem) == IDS.gote then
                return equippedItem
            end
        end
    end

    return slot2 or slot3
end

local function getEquippedGoteDebug()
    local containers = API.Container_Get_all and API.Container_Get_all(94)
    local slot2 = type(containers) == "table" and containers[2] or nil
    local slot3 = type(containers) == "table" and containers[3] or nil
    local equipmentGote = false
    local equipped = API.ReadEquipment and API.ReadEquipment()

    if type(equipped) == "table" then
        for _, equippedItem in ipairs(equipped) do
            if getItemId(equippedItem) == IDS.gote then
                equipmentGote = true
                break
            end
        end
    end

    return "container2=" .. tostring(getItemId(slot2)) .. " container3=" .. tostring(getItemId(slot3)) .. " equipmentGote=" .. tostring(equipmentGote)
end

local confirmPorterCharge

local function chargeGOTE()
    updatePorterStatus()

    local buffStatus = API.Buffbar_GetIDstatus(IDS.porterBuff, false)
    local porterId = getPorter()
    if not porterId then
        return
    end

    local stacks = 0
    if buffStatus and buffStatus.found and buffStatus.text then
        stacks = tonumber(buffStatus.text)
    end
    if stacks ~= nil and stacks <= CONFIG.porterRechargeThreshold then
        local now = os.time()
        if now - (tonumber(RUNTIME.lastGoteChargeAt) or 0) < 4 then
            return false
        end
        RUNTIME.lastGoteChargeAt = now

        local beforeFound, beforeAmount = getPorterBuffState()
        setAction("Recharging GOTE")
        if not useGraceOfTheElvesAbility() then
            RUNTIME.goteChargeFailCount = (tonumber(RUNTIME.goteChargeFailCount) or 0) + 1
            logError("Grace of the elves ability action failed")
        elseif confirmPorterCharge(beforeFound, beforeAmount) then
            RUNTIME.goteChargeFailCount = 0
            markProgress("GOTE charged")
            delay(800, 300, 0)
            return true
        else
            RUNTIME.goteChargeFailCount = (tonumber(RUNTIME.goteChargeFailCount) or 0) + 1
            logError("Grace of the elves charge did not confirm")
        end

        if (tonumber(RUNTIME.goteChargeFailCount) or 0) >= 3 then
            stopRun("GOTE recharge failed 3 times; check Grace of the elves action bar setup")
        end
        return false
    end

    RUNTIME.goteChargeFailCount = 0
    return true
end

local function needsPorterRecharge()
    local buffStatus = API.Buffbar_GetIDstatus(IDS.porterBuff, false)
    local porterId = getPorter()

    if not porterId then
        return false
    end

    local stacks = nil
    if buffStatus and buffStatus.found and buffStatus.text then
        stacks = tonumber(buffStatus.text)
    end
    if stacks == nil then
        return true
    end
    return stacks <= CONFIG.porterRechargeThreshold
end

confirmPorterCharge = function(beforeFound, beforeAmount)
    return waitUntil(function()
        local afterFound, afterAmount = getPorterBuffState()
        if not beforeFound and afterFound then
            return true
        end
        if afterFound and afterAmount > beforeAmount then
            return true
        end
        if afterFound and not needsPorterRecharge() then
            return true
        end
        return false
    end, 3.0, 120)
end

local function topUpPortersAfterPreset()
    local now = os.time()
    if now < (RUNTIME.lastPorterTopUpAt or 0) + 3.0 then
        return
    end

    local attempts = 0
    while API.Read_LoopyLoop() and attempts < 6 and needsPorterRecharge() do
        chargeGOTE()
        attempts = attempts + 1
        delay(500, 160, 0)
    end
    RUNTIME.lastPorterTopUpAt = os.time()
    updatePorterStatus()
end

local function shouldFollowSpriteNow()
    local now = os.time()
    if now < (RUNTIME.nextSpriteDecisionAt or 0) then
        return false
    end

    local follow = math.random() <= 0.70
    if follow then
        RUNTIME.nextSpriteDecisionAt = now + math.random(2, 4)
    else
        RUNTIME.nextSpriteDecisionAt = now + math.random(4, 8)
    end

    return follow
end

local function tomeDestroyInterfaceOpen()
    if API.GetInterfaceOpenBySize and API.GetInterfaceOpenBySize(1183) == true then
        return true
    end
    if API.Compare2874Status and API.Compare2874Status(28) == true then
        return true
    end
    return #API.ScanForInterfaceTest2Get(true, {
        { 1183, 11, -1, 0 },
    }) > 0
end

local function destroyTomes()
    local tomeCountBefore = safeInvItemCount(IDS.completeTome, "complete tome destroy start")
    if tomeCountBefore <= 0 then
        return
    end

    setAction("Destroying tomes")
    if API.DoAction_Inventory1(IDS.completeTome, 0, 8, API.OFF_ACT_GeneralInterface_route2) then
        local interfaceOpen = waitUntil(tomeDestroyInterfaceOpen, 2.0, 120)
        if not interfaceOpen then
            return
        end
        
        delay(400, 150, 0)

        if tomeCountBefore > 1 then
            API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1183, 7, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        else
            API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1183, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        end
        waitUntil(function()
            return safeInvItemCount(IDS.completeTome, "complete tome destroy wait") < tomeCountBefore
                or not tomeDestroyInterfaceOpen()
        end, 2.5, 120)

        if safeInvItemCount(IDS.completeTome, "complete tome destroy retry") < tomeCountBefore then
            markProgress("Complete tome destroyed")
            return
        end

        if safeInvItemCount(IDS.completeTome, "complete tome destroy confirm open") >= tomeCountBefore and tomeDestroyInterfaceOpen() then
            API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1183, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
            waitUntil(function()
                return safeInvItemCount(IDS.completeTome, "complete tome destroy confirm wait") < tomeCountBefore
                    or not tomeDestroyInterfaceOpen()
            end, 2.5, 120)
            if safeInvItemCount(IDS.completeTome, "complete tome destroy final") < tomeCountBefore then
                markProgress("Complete tome destroyed")
            end
        end
    end
end

local function hasCompleteTome()
    return safeInvItemCount(IDS.completeTome, "complete tome check") > 0
end

local function getSpriteSpot(spots, maxDistance)
    local spriteSpot = nil
    local shortestDistance = tonumber(maxDistance) or 50
    local highlights = copyObjectArray(API.GetAllObjArray1({ IDS.archFocus }, maxDistance, { 4 }))

    for _, spot in ipairs(spots) do
        for _, highlight in ipairs(highlights) do
            local distance = API.Math_DistanceF(spot.Tile_XYZ, highlight.Tile_XYZ)
            if distance < shortestDistance then
                shortestDistance = distance
                spriteSpot = spot
            end
        end
    end
    return spriteSpot
end

local function getSpotObjectId(spot)
    if type(spot) ~= "table" and type(spot) ~= "userdata" then
        return nil
    end
    return tonumber(objField(spot, "Id") or objField(spot, "ObjectId") or objField(spot, "id"))
end

local function getSpotLabel(spotId)
    return SPOT_LABELS[tonumber(spotId) or 0]
end

local function filterSpotsById(spots, spotId)
    local filtered = {}
    local expectedId = tonumber(spotId)
    for _, spot in ipairs(spots or {}) do
        if getSpotObjectId(spot) == expectedId then
            filtered[#filtered + 1] = spot
        end
    end
    return filtered
end

local function waitForExcavationStart()
    return waitUntil(function()
        return isMoving()
            or isAnimating()
            or artifactFoundInterfacePresent()
    end, 2.2, 120)
end

local function clickExcavationSpot(spot, actionLabel, requireStartConfirm)
    if type(spot) ~= "table" and type(spot) ~= "userdata" then
        log("Excavation click skipped: invalid spot object")
        return false
    end

    local tile = objTileXYZ(spot)
    if type(tile) ~= "table" then
        log("Excavation click skipped: invalid target tile")
        return false
    end

    local spotId = getSpotObjectId(spot) or SPOT_IDS[RUNTIME.spotIndex]
    local shouldConfirmStart = requireStartConfirm == true
    local target = WPOINT.new(tile.x, tile.y, tile.z or 0)

    setAction(actionLabel)

    local sent = API.DoAction_Object2(0x2, API.OFF_ACT_GeneralObject_route0, { tonumber(spotId) or 0 }, 50, target) == true
    log("Excavation click sent: action=" .. tostring(actionLabel) .. " spotId=" .. tostring(spotId or 0) .. " tile=" .. formatTile(tile) .. " sent=" .. tostring(sent) .. " confirm=" .. tostring(shouldConfirmStart))
    if not sent then
        return false
    end

    waitAfterExcavationClick()
    RUNTIME.clickedSpotTile = tile
    if not shouldConfirmStart then
        markProgress("Excavation click sent")
        delay(600, 200, 0)
        return true
    end

    local started = waitForExcavationStart()
    log("Excavation start confirm: started=" .. tostring(started) .. " tile=" .. formatTile(tile))
    if started then
        markProgress("Excavation started")
        delay(600, 200, 0)
        return true
    end

    return false
end

local goToDaemonheim

local function loadLastPresetFromFremennikBanker()
    setState(STATE.BANKING, "Loading last preset")
    setAction("Loading last preset")

    local inventorySignatureBefore = getInventorySignature()
    local hadPorterBefore = getPorter() ~= nil
    local hadFreeSlotsBefore = safeInvFreeCount("preset load baseline")
    if hadFreeSlotsBefore == nil then
        hadFreeSlotsBefore = -1
    end

    local sent = Interact:NPC("Fremennik banker", "Load Last Preset from", 50)
    if sent ~= true then
        logError("Failed to send Load Last Preset from to Fremennik banker")
        return false
    end

    local responseStarted = waitUntil(function()
        if isMoving() or isAnimating() or API.isProcessing() then
            return true
        end
        if getInventorySignature() ~= inventorySignatureBefore then
            return true
        end
        return not hadPorterBefore and getPorter() ~= nil
    end, 5, 120)

    if not responseStarted then
        logError("Load Last Preset action had no movement, animation, processing, or inventory response")
        return false
    end

    waitForStillness()

    local presetApplied = waitUntil(function()
        if getInventorySignature() ~= inventorySignatureBefore then
            return true
        end
        local currentFree = safeInvFreeCount("preset load wait")
        if currentFree ~= nil and currentFree ~= hadFreeSlotsBefore then
            return true
        end
        if getPorter() then
            return true
        end
        return false
    end, 12, 180)

    if not presetApplied then
        logError("Preset load did not visibly change inventory")
        return false
    end

    waitAfterPresetReload()
    RUNTIME.clickedSpotTile = nil
    topUpPortersAfterPreset()
    return true
end

local function runPresetReset()
    if not goToDaemonheim() then
        return false
    end

    if not loadLastPresetFromFremennikBanker() then
        return false
    end

    RUNTIME.clickedSpotTile = nil
    return true
end

local function getExcavationSpots()
    local preferredId = SPOT_IDS[RUNTIME.spotIndex]
    local spots = copyObjectArray(API.GetAllObjArrayInteract({ preferredId }, 50, { 0, 1, 12 }))
    local now = os.time()
    if now - (tonumber(RUNTIME.lastExcavationScanLogAt) or 0) >= 5 then
        RUNTIME.lastExcavationScanLogAt = now
        log("Excavation scan: preferredId=" .. tostring(preferredId) .. " preferredCount=" .. tostring(#spots) .. " spotIndex=" .. tostring(RUNTIME.spotIndex))
    end
    if #spots > 0 then
        return spots
    end

    local fallbackSpots = copyObjectArray(API.GetAllObjArrayInteract({ SPOT_IDS[1], SPOT_IDS[2] }, 50, { 0, 1, 12 }))
    log("Excavation scan fallback: count=" .. tostring(#fallbackSpots))
    if #fallbackSpots == 0 then
        log("Excavation scan found no spots for either Dragonkin debris id")
        return {}
    end

    for index, spotId in ipairs(SPOT_IDS) do
        for _, spot in ipairs(fallbackSpots) do
            if getSpotObjectId(spot) == tonumber(spotId) then
                RUNTIME.spotIndex = index
                log("Excavation scan selected fallback id=" .. tostring(spotId) .. " tile=" .. formatTile(spot.Tile_XYZ))
                return filterSpotsById(fallbackSpots, spotId)
            end
        end
    end

    log("Excavation scan returned unfiltered fallback set")
    return fallbackSpots
end

local function excavate()
    setState(STATE.EXCAVATING, "Excavating dragonkin debris")
    setAction("Finding excavation spot")

    if isAnimating() or isMoving() then
        RUNTIME.idleSince = 0
    else
        if (tonumber(RUNTIME.idleSince) or 0) == 0 then
            RUNTIME.idleSince = os.time()
        end
    end

    if artifactFoundInterfacePresent() or (RUNTIME.idleSince > 0 and os.time() - RUNTIME.idleSince >= 2) then
        RUNTIME.clickedSpotTile = nil
    end

    local spots = getExcavationSpots()
    local spriteSpot = getSpriteSpot(spots, 50)
    local canStartExcavation = not isMoving() and not isExcavationLoopAnimation()

    if spriteSpot then
        if not RUNTIME.clickedSpotTile or not tilesMatch(RUNTIME.clickedSpotTile, spriteSpot.Tile_XYZ) then
            if not shouldFollowSpriteNow() then
                setAction("Ignoring highlighted focus")
                spriteSpot = nil
            else
                delay(5000, 2000, 0)
                    if clickExcavationSpot(spriteSpot, "Excavating highlighted focus", true) then
                        return true
                    else
                    spriteSpot = nil
                end
            end
        end

            if spriteSpot then
            return true
        end
    end

    if canStartExcavation and #spots > 0 then
        local targetSpot = nil
        if type(RUNTIME.clickedSpotTile) == "table" then
            for _, spot in ipairs(spots) do
                local spotTile = objTileXYZ(spot)
                if spotTile and tilesMatch(RUNTIME.clickedSpotTile, spotTile) then
                    targetSpot = spot
                    break
                end
            end
        end
        if not targetSpot then
            targetSpot = spots[math.random(1, #spots)]
        end
        log("Excavation fallback target chosen: spotId=" .. tostring(getSpotObjectId(targetSpot) or 0) .. " tile=" .. formatTile(objTileXYZ(targetSpot)))
            if clickExcavationSpot(targetSpot, "Excavating fallback spot", true) then
                return true
            end
    elseif not (isAnimating() or isMoving()) then
        log("Excavation idle without spots: waiting for Dragonkin debris to appear")
    end

    return true
end

goToDaemonheim = function()
    setState(STATE.TRAVEL_DAEMONHEIM, "Travelling to Daemonheim")
    setAction("Using Ring of kinship")

    if #API.GetAllObjArray1({ IDS.banker }, 50, { 1 }) > 0 then
        return true
    end

    if not useActionBarAbility("Ring of kinship", 2) then
        logError("Could not use Ring of kinship ability")
        return false
    end
    if not waitUntil(function()
        return #API.GetAllObjArray1({ IDS.banker }, 50, { 1 }) > 0
    end, 20, 250) then
        logError("Failed to reach Daemonheim")
        return false
    end

    delay(1200, 300, 0)
    return true
end

local function goToAnachronia()
    setState(STATE.TRAVEL_ANACHRONIA, "Travelling to Anachronia")
    setAction("Opening lodestone map")

    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1465, 18, -1, API.OFF_ACT_GeneralInterface_route)
    if not waitUntil(lodestoneInterfaceOpen, 8, 180) then
        logError("Failed to open lodestone interface")
        return false
    end

    delay(500, 150, 0)

    setAction("Teleporting to Anachronia")
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1092, 25, -1, API.OFF_ACT_GeneralInterface_route)
    if not waitUntil(function()
        return #API.GetAllObjArray1({ IDS.sharrigan }, 50, { 1 }) > 0
    end, 30, 250) then
        logError("Failed to arrive at Anachronia")
        return false
    end

    delay(1500, 350, 0)
    return true
end

local function getArtifacts()
    setState(STATE.WITHDRAWING_ARTIFACTS, "Withdrawing artifacts")
    setAction("Opening Anachronia bank chest")

    API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, { IDS.bankChest }, 50)
    waitForStillness()

    if not waitUntil(function() return Bank:IsOpen() end, 8, 180) then
        logError("Failed to open bank chest")
        return 0
    end

    delay(600, 200, 0)

    inventoryReadyWithBankNudge("artifact bank inventory rebuild", 3.0, ARTIFACT_IDS[1])

    local freeBeforeWithdraw = safeInvFreeCount("artifact withdraw inventory cleanup")
    if freeBeforeWithdraw ~= nil and freeBeforeWithdraw < 28 then
        Bank:DepositInventory()
        delay(300, 100, 0)
    end

    local itemsToGrab = 6
    for _, artifactId in ipairs(ARTIFACT_IDS) do
        Bank:Withdraw(artifactId, itemsToGrab)
        delay(600, 200, 0)
    end

    -- Give the server an extra second to sync the final item into your inventory array
    delay(1200, 300, 0)

    for _, artifactId in ipairs(ARTIFACT_IDS) do
        local count = safeInvItemCount(artifactId, "count withdrawn damaged artifacts")
        if count < itemsToGrab then
            debugLog("Artifact " .. tostring(artifactId) .. " clamped itemsToGrab from " .. tostring(itemsToGrab) .. " to " .. tostring(count))
            itemsToGrab = count
        end
    end

    API.KeyboardPress32(0x1B, 0)
    delay(220, 80, 0)
    return itemsToGrab
end

local function restoreArtifacts()
    setState(STATE.RESTORING_ARTIFACTS, "Restoring artifacts")

    for i, slot in ipairs(ARTIFACT_INTERFACE_SLOTS) do
        local artifactId = ARTIFACT_IDS[i]
        if safeInvItemCount(artifactId, "check damaged artifacts") > 0 then
            setAction("Opening workbench")
            API.DoAction_Object1(0x4, API.OFF_ACT_GeneralObject_route0, { IDS.workbench }, 50)
            waitForStillness()

            if not waitUntil(workInterfaceOpen, 8, 180) then
                logError("Failed to open workbench interface")
                return false
            end

            setAction("Restoring artifact")
            API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1371, 22, slot, API.OFF_ACT_GeneralInterface_route)
            delay(320, 100, 0)
            API.KeyboardPress32(0x20, 0)

            if not waitUntil(function() return API.isProcessing() end, 4, 120) then
                logError("Artifact restoration did not start")
                return false
            end

            local lastProcessing = os.clock()
            waitUntil(function()
                if API.isProcessing() or isAnimating() then
                    lastProcessing = os.clock()
                end
                -- Debounce: Only exit if neither processing nor animating has occurred for 3 seconds
                return (os.clock() - lastProcessing) > 3.0
            end, 180, 200)

            delay(300, 100, 0)
        end
    end

    return true
end

local function turnInArtifacts()
    setState(STATE.TURNING_IN_ARTIFACTS, "Turning in restored artifacts")
    setAction("Talking to Sharrigan")

    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route4, { IDS.sharrigan }, 50)
    if API.WaitUntilMovingEnds then pcall(API.WaitUntilMovingEnds, 600, 5) end

    if not waitUntil(sharriganInterfaceOpen, 8, 180) then
        logError("Failed to open Sharrigan interface")
        return false
    end

    API.DoAction_Interface(0x24, 0xffffffff, 1, 656, 31, 4, API.OFF_ACT_GeneralInterface_route)
    delay(250, 80, 0)

    local prevFreeCount = -1
    local curFreeCount = safeInvFreeCount("turn-in free count start") or -1
    while API.Read_LoopyLoop() and curFreeCount ~= prevFreeCount do
        prevFreeCount = curFreeCount
        API.DoAction_Interface(0x24, 0xffffffff, 1, 656, 25, 0, API.OFF_ACT_GeneralInterface_route)
        delay(800, 200, 0)
        curFreeCount = safeInvFreeCount("turn-in free count wait") or prevFreeCount
    end

    API.KeyboardPress32(0x1B, 0)
    delay(220, 80, 0)

    setAction("Redeeming chronotes and token boxes")
    API.DoAction_Inventory1(IDS.chronote, 0, 3, API.OFF_ACT_GeneralInterface_route)
    delay(300, 100, 0)

    while safeInvItemCount(IDS.tokenBox, "token box redeem") > 0 and API.Read_LoopyLoop() do
        API.DoAction_Inventory1(IDS.tokenBox, 0, 1, API.OFF_ACT_GeneralInterface_route)
        delay(800, 200, 0)
    end

    local freeAfterTurnIn = safeInvFreeCount("turn-in final free count")
    if freeAfterTurnIn == nil or freeAfterTurnIn < 28 then
        logError("Could not turn in all restored artifacts")
        return false
    end

    return true
end

local function shouldRedeemNow()
    return CONFIG.redeemArtifacts == true and (RUNTIME.iteration % CONFIG.bankIncrement == 0)
end

local function trackBankedArtifacts()
    RUNTIME.collections.totem = RUNTIME.collections.totem + safeInvItemCount(IDS.totem, "track banked artifacts")
    RUNTIME.collections.mine = RUNTIME.collections.mine + safeInvItemCount(IDS.mine, "track banked artifacts")
    RUNTIME.collections.ring = RUNTIME.collections.ring + safeInvItemCount(IDS.ring, "track banked artifacts")
    RUNTIME.collections.gatestone = RUNTIME.collections.gatestone + safeInvItemCount(IDS.gatestone, "track banked artifacts")
end

local function repairWorkbenchInterfaceOpen()
    return (API.GetInterfaceOpenBySize and API.GetInterfaceOpenBySize(1370) == true)
        or (API.Compare2874Status and API.Compare2874Status(1310738) == true)
end

local function openRepairBank()
    setAction("Opening bank for repairs")
    if Bank:IsOpen() then
        return true
    end
    if Interact and Interact.Object then
        pcall(function()
            Interact:Object("Bank chest", "Use")
        end)
    else
        API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, { IDS.bankChest }, 50)
    end
    if API.WaitUntilMovingEnds then
        pcall(API.WaitUntilMovingEnds, 600, 5)
    end
    return waitUntil(function()
        return Bank:IsOpen() == true
    end, 8, 180)
end

local function closeBankForRepair()
    if Bank and type(Bank.Close) == "function" then
        pcall(function()
            Bank:Close()
        end)
    else
        API.KeyboardPress32(0x1B, 0)
    end
    delay(350, 120, 0)
    return waitUntil(function()
        return Bank:IsOpen() ~= true
    end, 3, 120)
end

local function openRepairWorkbench()
    setAction("Opening repair workbench")
    if repairWorkbenchInterfaceOpen() then
        return true
    end
    if Interact and Interact.Object then
        pcall(function()
            Interact:Object("Archaeologist's workbench", "Restore")
        end)
    else
        API.DoAction_Object1(0x4, API.OFF_ACT_GeneralObject_route0, { IDS.workbench }, 50)
    end
    waitForStillness()
    return waitUntil(repairWorkbenchInterfaceOpen, 8, 180)
end

local function pressSpaceForRepair()
    setAction("Starting repair")
    if API.KeyboardPress2 then
        API.KeyboardPress2(0x20, 0, 50)
    else
        API.KeyboardPress32(0x20, 0)
    end
    delay(300, 100, 0)
    if not waitUntil(function()
        return API.isProcessing() == true
    end, 5, 120) then
        logError("Repair did not start processing")
        return false
    end
    
    local lastProcessing = os.clock()
    waitUntil(function()
        if API.isProcessing() or isAnimating() then
            lastProcessing = os.clock()
        end
        return (os.clock() - lastProcessing) > 3.0
    end, 180, 200)
    
    delay(450, 140, 0)
    return true
end

local function depositRepairOutput()
    if not openRepairBank() then
        logError("Failed to reopen bank after repair")
        return false
    end
    setAction("Depositing repaired items")
    if Bank and type(Bank.DepositInventory) == "function" then
        Bank:DepositInventory()
    else
        API.DoAction_Interface(0x24, 0xffffffff, 1, 517, 317, -1, API.OFF_ACT_GeneralInterface_route)
    end
    delay(450, 160, 0)
    markProgress("Repair output deposited")
    return true
end

local function withdrawRepairBatch(entry)
    local item = repairItemById(entry and entry.itemId)
    if not item then
        logError("Invalid repair queue item")
        return 0
    end

    local remaining = math.max(0, (tonumber(entry.amount) or 0) - (tonumber(RUNTIME.repairCompleted) or 0))
    if remaining <= 0 then
        return 0
    end

    if not openRepairBank() then
        logError("Failed to open bank for repair withdraw")
        return 0
    end

    inventoryReadyWithBankNudge("repair withdraw inventory rebuild", 3.0, item.id)
    local freeSlots = safeInvFreeCount("repair free slots") or 28
    if freeSlots < 28 then
        Bank:DepositInventory()
        delay(350, 120, 0)
        freeSlots = safeInvFreeCount("repair free slots after deposit") or 28
    end

    local batchSize = math.max(1, math.min(remaining, freeSlots, 28))
    setAction("Withdrawing " .. tostring(batchSize) .. " " .. item.label)
    if not Bank:Withdraw(item.id, batchSize) then
        logError("Failed to withdraw " .. item.label)
        return 0
    end

    delay(450, 160, 0)
    closeBankForRepair()
    return batchSize
end

local function repairBatch(entry)
    local item = repairItemById(entry and entry.itemId)
    if not item then
        logError("Invalid repair queue item")
        return false
    end

    local batchSize = withdrawRepairBatch(entry)
    if batchSize <= 0 then
        return false
    end

    if not openRepairWorkbench() then
        logError("Failed to open repair workbench")
        return false
    end
    if not pressSpaceForRepair() then
        return false
    end
    if not depositRepairOutput() then
        return false
    end

    RUNTIME.repairCompleted = (tonumber(RUNTIME.repairCompleted) or 0) + batchSize
    RUNTIME.repairStatus = string.format("%s %d/%d", item.label, RUNTIME.repairCompleted, tonumber(entry.amount) or 0)
    markProgress("Repair batch completed")
    return true
end

local function finishRepairMode(reason)
    RUNTIME.started = false
    RUNTIME.repairActive = false
    RUNTIME.repairOnlyMode = false
    RUNTIME.repairStatus = tostring(reason or "Repair queue complete")
    setState(STATE.STOPPED, RUNTIME.repairStatus)
    setAction("Repair complete")
end

local function runRepairTick()
    if RUNTIME.repairActive ~= true then
        return false
    end
    if #CONFIG.repairQueue == 0 then
        finishRepairMode("Repair queue empty")
        return true
    end

    local entry = CONFIG.repairQueue[RUNTIME.repairQueueIndex]
    if not entry then
        finishRepairMode("Repair queue complete")
        return true
    end

    if (tonumber(RUNTIME.repairCompleted) or 0) >= (tonumber(entry.amount) or 0) then
        RUNTIME.repairQueueIndex = RUNTIME.repairQueueIndex + 1
        RUNTIME.repairCompleted = 0
        return true
    end

    setState(STATE.REPAIRING, "Repairing artifacts")
    if not repairBatch(entry) then
        stopRun("Repair queue failed")
    end
    return true
end

stopRun = function(reason)
    RUNTIME.started = false
    RUNTIME.stopReason = tostring(reason or "")
    RUNTIME.clickedSpotTile = nil
    RUNTIME.repairActive = false
    RUNTIME.repairOnlyMode = false
    RUNTIME.redeemOnlyMode = false
    log("Run stopped: " .. tostring(reason or "No reason provided"))
    setState(STATE.STOPPED, reason or "Stopped")
end

local function resetForStart()
    sanitizeConfig()
    RUNTIME.started = true
    RUNTIME.repairActive = false
    RUNTIME.repairOnlyMode = false
    RUNTIME.redeemOnlyMode = false
    RUNTIME.spotIndex = CONFIG.startSpotIndex
    RUNTIME.iteration = 1
    RUNTIME.clickedSpotTile = nil
    RUNTIME.scriptStartTime = os.time()
    RUNTIME.stopReason = ""
    RUNTIME.lastError = ""
    RUNTIME.currentAction = "Preparing"
    RUNTIME.worldHops = 0
    RUNTIME.nextWorldHopAt = 0
    RUNTIME.lastWorldHopReason = "None"
    RUNTIME.lastWorldHopTarget = 0
    RUNTIME.idleSince = 0
    RUNTIME.lastWorldHopLanded = 0
    RUNTIME.lastWorldHopDiagnostic = ""
    RUNTIME.lastWorldHopBlockLogAt = 0
    RUNTIME.hopPending = false
    RUNTIME.hopPendingReason = ""
    RUNTIME.hopFailCount = 0
    RUNTIME.lastPorterTopUpAt = 0
    RUNTIME.lastObservedArchXp = getArchaeologyXp()
    RUNTIME.lastXpGainAt = os.time()
    RUNTIME.lastActionKey = ""
    RUNTIME.sameActionCount = 0
    RUNTIME.lastProgressAt = os.time()
    RUNTIME.presetResetInitialized = false
    RUNTIME.lastExcavationScanLogAt = 0
    RUNTIME.goteChargeFailCount = 0
    RUNTIME.lastGoteChargeAt = 0
    scheduleNextWorldHop()
    setState(STATE.TRAVEL_DAEMONHEIM, "Starting run")
end

local function startRepairMode()
    sanitizeConfig()
    if #CONFIG.repairQueue == 0 then
        Gui.repairQueueMessage = "Repair queue is empty"
        return false
    end

    RUNTIME.started = true
    RUNTIME.repairActive = true
    RUNTIME.repairOnlyMode = true
    RUNTIME.repairQueueIndex = 1
    RUNTIME.repairCompleted = 0
    RUNTIME.scriptStartTime = os.time()
    RUNTIME.stopReason = ""
    RUNTIME.lastError = ""
    RUNTIME.hopPending = false
    RUNTIME.repairStatus = "Starting repair queue"
    setState(STATE.REPAIRING, "Starting repair queue")
    setAction("Repair queue")
    Gui.saveConfig()
    return true
end

local function startRedeemMode()
    sanitizeConfig()
    RUNTIME.started = true
    RUNTIME.redeemOnlyMode = true
    RUNTIME.repairActive = false
    RUNTIME.repairOnlyMode = false
    RUNTIME.scriptStartTime = os.time()
    RUNTIME.stopReason = ""
    RUNTIME.lastError = ""
    RUNTIME.hopPending = false
    setState(STATE.TURNING_IN_ARTIFACTS, "Starting standalone redemption")
    setAction("Redeeming artifacts")
    Gui.saveConfig()
    return true
end

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, THEME.accent[1], THEME.accent[2], THEME.accent[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function statTable()
    local rows = {
        { "Status", tostring(RUNTIME.status) },
        { "State", tostring(RUNTIME.state) },
        { "Action", tostring(RUNTIME.currentAction) },
        { "Runtime", runtimeLabel() },
        { "Current Spot", START_SPOT_OPTIONS[RUNTIME.spotIndex] or tostring(RUNTIME.spotIndex) },
        { "Iteration", tostring(RUNTIME.iteration) },
        { "Porter", tostring(RUNTIME.porterStatus) },
        { "World Hops", tostring(RUNTIME.worldHops) },
        { "Next Hop", nextWorldHopLabel() },
        { "Last Hop", tostring(RUNTIME.lastWorldHopDiagnostic ~= "" and RUNTIME.lastWorldHopDiagnostic or "-") },
        { "Hop Reason", tostring(RUNTIME.lastWorldHopReason) },
        { "Collections/hr", string.format("%.2f", getCollectionsPerHour()) },
        { "Ring", tostring(RUNTIME.collections.ring + guiInvItemCount(IDS.ring)) },
        { "Gatestone", tostring(RUNTIME.collections.gatestone + guiInvItemCount(IDS.gatestone)) },
        { "Totem", tostring(RUNTIME.collections.totem + guiInvItemCount(IDS.totem)) },
        { "Portal mine", tostring(RUNTIME.collections.mine + guiInvItemCount(IDS.mine)) },
    }

    if ImGui.BeginTable("Runtime Stats", 2, ImGuiTableFlags.SizingStretchProp) then
        for _, row in ipairs(rows) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.TextWrapped(row[1])
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, THEME.accent[1], THEME.accent[2], THEME.accent[3], 1.0)
            ImGui.TextWrapped(row[2])
            ImGui.PopStyleColor(1)
        end
        ImGui.EndTable()
    end
end

local function drawConfigTab()
    sectionHeader("Run Setup")
    flavorText("Dragonkin debris farmer with optional artifact restoration and Sharrigan turn-ins.")
    ImGui.Spacing()

    local selectedIndex = math.max(0, CONFIG.startSpotIndex - 1)
    ImGui.PushID("dragonkin_start_spot")
    local changedSpot, newSpot = ImGui.Combo("Starting Spot", selectedIndex, START_SPOT_OPTIONS)
    ImGui.PopID()
    if changedSpot then
        CONFIG.startSpotIndex = newSpot + 1
        Gui.saveConfig()
    end

    ImGui.PushID("dragonkin_debug")
    local changedDebug, newDebug = ImGui.Checkbox("Enable Debug Logs", CONFIG.debugLogs)
    ImGui.PopID()
    if changedDebug then
        CONFIG.debugLogs = newDebug
        Gui.saveConfig()
    end

    ImGui.Spacing()
    if not RUNTIME.started then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.40, 0.55, 0.22, 0.95)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.48, 0.68, 0.26, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.35, 0.50, 0.20, 1.0)
        ImGui.PushID("dragonkin_start")
        if ImGui.Button("Start Script", -1, 30) then
            resetForStart()
            Gui.saveConfig()
        end
        ImGui.PopID()
        ImGui.PopStyleColor(3)
    else
        ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.18, 0.12, 0.95)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.70, 0.24, 0.16, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.82, 0.28, 0.18, 1.0)
        ImGui.PushID("dragonkin_stop")
        if ImGui.Button("Stop Script", -1, 30) then
            stopRun("Stopped from GUI")
        end
        ImGui.PopID()
        ImGui.PopStyleColor(3)
    end
end

local function drawRuntimeTab()
    sectionHeader("Runtime")
    ImGui.Spacing()
    statTable()

    if RUNTIME.lastError and RUNTIME.lastError ~= "" then
        ImGui.Spacing()
        sectionHeader("Last Error")
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.55, 0.35, 1.0)
        ImGui.TextWrapped(RUNTIME.lastError)
        ImGui.PopStyleColor(1)
    end
end

local function repairQueueLabel(entry, index)
    local item = repairItemById(entry and entry.itemId)
    return string.format("%d. %s x%d", index or 0, item and item.label or "Unknown", tonumber(entry and entry.amount) or 0)
end

local function addRepairQueueEntry()
    local item = repairItemByIndex(CONFIG.repairSelectedIndex)
    if not item then
        Gui.repairQueueMessage = "Select a repair item"
        return false
    end
    CONFIG.repairQueue[#CONFIG.repairQueue + 1] = {
        itemId = item.id,
        amount = clampInteger(CONFIG.repairAmount, 1, 100000, 1),
    }
    Gui.repairQueueMessage = "Added " .. item.label .. " x" .. tostring(CONFIG.repairAmount)
    Gui.saveConfig()
    return true
end

local function clearRepairQueue()
    CONFIG.repairQueue = {}
    RUNTIME.repairQueueIndex = 1
    RUNTIME.repairCompleted = 0
    Gui.repairQueueMessage = "Repair queue cleared"
    Gui.saveConfig()
end

local function drawRepairTab()
    sectionHeader("Repair Queue")
    flavorText("Runs separately from excavation. When the queue is done, the script stops instead of going back to excavating.")
    ImGui.Spacing()

    local selectedIndex = math.max(0, (tonumber(CONFIG.repairSelectedIndex) or 1) - 1)
    ImGui.PushID("dragonkin_repair_item")
    local changedItem, newItem = ImGui.Combo("Repair Item", selectedIndex, repairItemLabels())
    ImGui.PopID()
    if changedItem then
        CONFIG.repairSelectedIndex = newItem + 1
        Gui.saveConfig()
    end

    ImGui.PushID("dragonkin_repair_amount")
    local changedAmount, newAmount = ImGui.DragInt("Amount To Repair", CONFIG.repairAmount, 1, 1, 100000)
    ImGui.PopID()
    if changedAmount then
        CONFIG.repairAmount = clampInteger(newAmount, 1, 100000, 1)
        Gui.saveConfig()
    end

    if ImGui.Button("Add To Repair Queue", -1, 28) then
        addRepairQueueEntry()
    end
    if ImGui.Button("Clear Repair Queue", -1, 26) then
        clearRepairQueue()
    end

    ImGui.Spacing()
    sectionHeader("Queued Repairs")
    if #CONFIG.repairQueue == 0 then
        flavorText("No repair jobs queued.")
    else
        for i, entry in ipairs(CONFIG.repairQueue) do
            ImGui.BulletText(repairQueueLabel(entry, i))
        end
    end

    ImGui.Spacing()
    ImGui.TextWrapped("Repair status: " .. tostring(RUNTIME.repairStatus))
    if Gui.repairQueueMessage ~= "" then
        flavorText(Gui.repairQueueMessage)
    end

    ImGui.Spacing()
    if not RUNTIME.started then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.40, 0.55, 0.22, 0.95)
        if ImGui.Button("Start Repairs", -1, 30) then
            startRepairMode()
        end
        ImGui.PopStyleColor(1)
    elseif RUNTIME.repairActive then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.18, 0.12, 0.95)
        if ImGui.Button("Stop Repairs", -1, 30) then
            stopRun("Repair stopped from GUI")
        end
        ImGui.PopStyleColor(1)
    else
        flavorText("Normal Dragonkin run is active. Stop it before starting repairs.")
    end
end

local function drawRedeemTab()
    sectionHeader("Redemption Target")
    flavorText("Stop the script automatically after a certain number of artifact sets have been redeemed.")
    ImGui.Spacing()

    ImGui.PushID("dragonkin_redeem_target_enable")
    local changedEnable, newEnable = ImGui.Checkbox("Enable Redemption Target", CONFIG.enableRedeemTarget)
    ImGui.PopID()
    if changedEnable then
        CONFIG.enableRedeemTarget = newEnable
        Gui.saveConfig()
    end

    ImGui.PushID("dragonkin_redeem_target_amount")
    local changedAmount, newAmount = ImGui.DragInt("Target Sets to Redeem", CONFIG.redeemTargetAmount, 1, 0, 999999)
    ImGui.PopID()
    if changedAmount then
        CONFIG.redeemTargetAmount = clampInteger(newAmount, 0, 999999, 0)
        Gui.saveConfig()
    end

    ImGui.Spacing()
    ImGui.TextWrapped("Total Sets Redeemed This Session: " .. tostring(RUNTIME.totalRedeemed))
    if CONFIG.enableRedeemTarget then
        ImGui.TextWrapped("Remaining Until Target: " .. tostring(math.max(0, CONFIG.redeemTargetAmount - RUNTIME.totalRedeemed)))
    end

    ImGui.Spacing()
    if not RUNTIME.started then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.40, 0.55, 0.22, 0.95)
        if ImGui.Button("Start Standalone Redeem", -1, 30) then
            startRedeemMode()
        end
        ImGui.PopStyleColor(1)
    elseif RUNTIME.redeemOnlyMode then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.18, 0.12, 0.95)
        if ImGui.Button("Stop Standalone Redeem", -1, 30) then
            stopRun("Redeem stopped from GUI")
        end
        ImGui.PopStyleColor(1)
    else
        flavorText("Normal Dragonkin run or Repair is active. Stop it before starting Standalone Redeem.")
    end
end

local function drawWorldHopTab()
    sectionHeader("World Hop")
    flavorText("Timed hops and nearby-player hops use the native WorldHop API at safe checkpoints.")
    ImGui.Spacing()

    ImGui.PushID("dragonkin_timed_hop")
    local changedTimed, newTimed = ImGui.Checkbox("Enable Timed World Hop", CONFIG.enableTimedWorldHop)
    ImGui.PopID()
    if changedTimed then
        CONFIG.enableTimedWorldHop = newTimed
        if newTimed then
            scheduleNextWorldHop()
        else
            RUNTIME.nextWorldHopAt = 0
        end
        Gui.saveConfig()
    end

    if CONFIG.enableTimedWorldHop then
        ImGui.PushID("dragonkin_hop_min")
        local changedMin, newMin = ImGui.DragInt("Timed Hop Min Minutes", CONFIG.worldHopMinMinutes, 1, 1, 180)
        ImGui.PopID()
        if changedMin then
            CONFIG.worldHopMinMinutes = newMin
            sanitizeConfig()
            scheduleNextWorldHop()
            Gui.saveConfig()
        end

        ImGui.PushID("dragonkin_hop_max")
        local changedMax, newMax = ImGui.DragInt("Timed Hop Max Minutes", CONFIG.worldHopMaxMinutes, 1, 1, 240)
        ImGui.PopID()
        if changedMax then
            CONFIG.worldHopMaxMinutes = newMax
            sanitizeConfig()
            scheduleNextWorldHop()
            Gui.saveConfig()
        end
    end

    ImGui.Spacing()

    ImGui.PushID("dragonkin_nearby_hop")
    local changedNearby, newNearby = ImGui.Checkbox("Enable Nearby Player Hop", CONFIG.enableNearbyPlayerHop)
    ImGui.PopID()
    if changedNearby then
        CONFIG.enableNearbyPlayerHop = newNearby
        Gui.saveConfig()
    end

    if CONFIG.enableNearbyPlayerHop then
        ImGui.PushID("dragonkin_hop_radius")
        local changedRadius, newRadius = ImGui.DragInt("Nearby Player Hop Radius", CONFIG.nearbyPlayerHopRadius, 1, 1, 40)
        ImGui.PopID()
        if changedRadius then
            CONFIG.nearbyPlayerHopRadius = newRadius
            sanitizeConfig()
            Gui.saveConfig()
        end
    end

    ImGui.Spacing()
    ImGui.TextWrapped("Pending hop: " .. (RUNTIME.hopPending and tostring(RUNTIME.hopPendingReason) or "No"))
    ImGui.TextWrapped("Next timed hop: " .. nextWorldHopLabel())
end

local function drawInfoTab()
    sectionHeader("Dragonkin V Farmer")
    ImGui.Spacing()

    sectionHeader("Requirements")
    ImGui.BulletText("Grace of the elves action-bar ability is required for porter recharge support.")
    ImGui.BulletText("Ring of kinship action-bar ability is required for Daemonheim travel.")
    ImGui.BulletText("Keep porters available in your bank and in your preset, leave at least one free inventory slot.")
    ImGui.BulletText("Unlock the Anachronia bank chest before using artifact redemption.")
    ImGui.BulletText("Set your last bank preset for the Dragonkin excavation inventory.")
    ImGui.Spacing()

    sectionHeader("Flow")
    ImGui.BulletText("Start Script excavates the selected Dragonkin debris spot.")
    ImGui.BulletText("Full inventories reload your last preset from the Fremennik banker.")
    ImGui.BulletText("Standalone Redeem handles restored artifact turn-ins from the Redeem tab.")
    ImGui.BulletText("Repair Queue runs selected artifact repairs from the Repair tab.")
    ImGui.Spacing()

    sectionHeader("Variant Notes")
    ImGui.BulletText("Uses API.RandomSleep2 for script delays.")
    ImGui.BulletText("World hopping uses the native WorldHop API.")
    ImGui.BulletText("No scheduled farm runs or Herb Runs integration in this version.")
end

DrawImGui(function()
    ImGui.SetNextWindowSize(585, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(120, 120, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg,         THEME.dark[1],            THEME.dark[2],            THEME.dark[3],            0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg,          THEME.medium[1] * 0.7,    THEME.medium[2] * 0.7,    THEME.medium[3] * 0.7,    1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive,    THEME.medium[1],          THEME.medium[2],          THEME.medium[3],          1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator,        THEME.light[1],           THEME.light[2],           THEME.light[3],           0.5)
    ImGui.PushStyleColor(ImGuiCol.Tab,              THEME.medium[1] * 0.8,    THEME.medium[2] * 0.8,    THEME.medium[3] * 0.8,    1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered,       THEME.light[1],           THEME.light[2],           THEME.light[3],           1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive,        THEME.bright[1] * 0.8,    THEME.bright[2] * 0.8,    THEME.bright[3] * 0.8,    1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg,          THEME.medium[1] * 0.5,    THEME.medium[2] * 0.5,    THEME.medium[3] * 0.5,    0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered,   THEME.light[1] * 0.8,     THEME.light[2] * 0.8,     THEME.light[3] * 0.8,     1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive,    THEME.bright[1] * 0.55,   THEME.bright[2] * 0.55,   THEME.bright[3] * 0.55,   1.0)
    ImGui.PushStyleColor(ImGuiCol.Button,           THEME.medium[1],          THEME.medium[2],          THEME.medium[3],          0.85)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered,    THEME.light[1],           THEME.light[2],           THEME.light[3],           1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,     THEME.bright[1],          THEME.bright[2],          THEME.bright[3],          1.0)
    ImGui.PushStyleColor(ImGuiCol.Header,           THEME.medium[1],          THEME.medium[2],          THEME.medium[3],          0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered,    THEME.light[1],           THEME.light[2],           THEME.light[3],           1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive,     THEME.bright[1],          THEME.bright[2],          THEME.bright[3],          1.0)
    ImGui.PushStyleColor(ImGuiCol.Text,             1.0,  0.96, 0.88, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Border,           THEME.glow[1],            THEME.glow[2],            THEME.glow[3],            0.25)
    ImGui.PushStyleColor(ImGuiCol.CheckMark,        THEME.glow[1],            THEME.glow[2],            THEME.glow[3],            1.0)
    ImGui.PushStyleColor(ImGuiCol.PopupBg,          THEME.dark[1],            THEME.dark[2],            THEME.dark[3],            0.98)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing,    7,  5)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding,  4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)

    local visible = ImGui.Begin("Dragonkin V Farmer###DragonkinVFarmerGUI", true)
    if visible then
        if ImGui.BeginTabBar("##dragonkin_tabs", 0) then
            if ImGui.BeginTabItem("Config##dragonkin_tab_config", nil, 0) then
                drawConfigTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Runtime##dragonkin_tab_runtime", nil, 0) then
                drawRuntimeTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Redeem##dragonkin_tab_redeem", nil, 0) then
                drawRedeemTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Repair##dragonkin_tab_repair", nil, 0) then
                drawRepairTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("World Hop##dragonkin_tab_wh", nil, 0) then
                drawWorldHopTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Info##dragonkin_tab_info", nil, 0) then
                drawInfoTab()
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end
    end

    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(20)
    ImGui.End()
end)

local function runRedeemCycle()
    local redeemedThisCycle = 0
    if not goToAnachronia() then
        return false
    end

    local keepRunning = true
    while keepRunning and API.Read_LoopyLoop() do
        local artifactCount = getArtifacts()
        if artifactCount == 0 then
            break
        elseif artifactCount < 6 then
            keepRunning = false
        end
        redeemedThisCycle = redeemedThisCycle + artifactCount
        RUNTIME.totalRedeemed = RUNTIME.totalRedeemed + artifactCount

        if not restoreArtifacts() or not turnInArtifacts() then
            return false
        end
    end

    if not goToDaemonheim() then
        return false
    end
    return true
end

local function runRedeemOnlyTick()
    if RUNTIME.redeemOnlyMode ~= true then
        return false
    end

    if CONFIG.enableRedeemTarget and RUNTIME.totalRedeemed >= CONFIG.redeemTargetAmount then
        stopRun("Redemption target reached: " .. tostring(CONFIG.redeemTargetAmount) .. " sets redeemed")
        return true
    end

    setAction("Opening bank for redemption")
    if not Bank:IsOpen() then
        if Interact and Interact.Object then
            pcall(function() Interact:Object("Bank chest", "Use") end)
        else
            API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, { IDS.bankChest }, 50)
        end
        if API.WaitUntilMovingEnds then pcall(API.WaitUntilMovingEnds, 600, 5) end
        waitUntil(function() return Bank:IsOpen() == true end, 8, 180)
    end

    if not Bank:IsOpen() then
        logError("Failed to open bank chest")
        stopRun("Redemption failed: Bank did not open")
        return true
    end

    delay(600, 200, 0)
    inventoryReadyWithBankNudge("redeem bank inventory rebuild", 3.0, RESTORED_ARTIFACT_IDS[1])

    local freeSlots = safeInvFreeCount("redeem withdraw inventory cleanup")
    if freeSlots ~= nil and freeSlots < 28 then
        Bank:DepositInventory()
        delay(300, 100, 0)
    end

    local itemsToGrab = 6
    for _, artifactId in ipairs(RESTORED_ARTIFACT_IDS) do
        Bank:Withdraw(artifactId, itemsToGrab)
        delay(600, 200, 0)
    end

    -- Give the server an extra second to sync the final item into your inventory array
    delay(1200, 300, 0)

    for _, artifactId in ipairs(RESTORED_ARTIFACT_IDS) do
        local count = safeInvItemCount(artifactId, "count withdrawn restored artifacts")
        if count < itemsToGrab then
            debugLog("Artifact " .. tostring(artifactId) .. " clamped itemsToGrab from " .. tostring(itemsToGrab) .. " to " .. tostring(count))
            itemsToGrab = count
        end
    end

    if Bank and type(Bank.Close) == "function" then
        pcall(function() Bank:Close() end)
    else
        API.KeyboardPress32(0x1B, 0)
    end
    delay(350, 120, 0)
    waitUntil(function() return not Bank:IsOpen() end, 3, 120)

    if itemsToGrab == 0 then
        stopRun("Out of artifacts to redeem")
        return true
    end

    setAction("Talking to Sharrigan")
    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route4, { IDS.sharrigan }, 50)
    
    if API.WaitUntilMovingEnds then pcall(API.WaitUntilMovingEnds, 600, 5) end
    
    local sharriganOpen = waitUntil(function()
        return sharriganInterfaceOpen()
    end, 8, 180)

    if not sharriganOpen then
        logError("Failed to open Sharrigan interface")
        stopRun("Redemption failed: Interface did not open")
        return true
    end

    API.DoAction_Interface(0x24, 0xffffffff, 1, 656, 31, 4, API.OFF_ACT_GeneralInterface_route)
    delay(400, 150, 0)

    for i = 1, itemsToGrab do
        API.DoAction_Interface(0x24, 0xffffffff, 1, 656, 25, 0, API.OFF_ACT_GeneralInterface_route)
        delay(800, 200, 0)
    end

    API.KeyboardPress32(0x1B, 0)
    delay(300, 100, 0)

    setAction("Redeeming token boxes")
    while safeInvItemCount(IDS.tokenBox, "token box redeem") > 0 and API.Read_LoopyLoop() do
        API.DoAction_Inventory1(IDS.tokenBox, 0, 1, API.OFF_ACT_GeneralInterface_route)
        delay(800, 200, 0)
    end

    RUNTIME.totalRedeemed = RUNTIME.totalRedeemed + itemsToGrab
    markProgress("Standalone redemption cycle complete")
    return true
end

local function tick()
    if CONFIG.enableRedeemTarget and RUNTIME.totalRedeemed >= CONFIG.redeemTargetAmount then
        stopRun("Redemption target reached: " .. tostring(CONFIG.redeemTargetAmount) .. " sets redeemed")
        return
    end

    if API.GetGameState2() ~= 3 or not API.PlayerLoggedIn() then
        stopRun("Bad game state")
        return
    end

    if RUNTIME.repairOnlyMode == true then
        API.DoRandomEvents()
        runRepairTick()
        return
    end

    if RUNTIME.redeemOnlyMode == true then
        API.DoRandomEvents()
        runRedeemOnlyTick()
        return
    end

    if hasCompleteTome() then
        API.DoRandomEvents()
        destroyTomes()
        return
    end

    API.DoRandomEvents()
    if checkNoXpFailsafe() then
        return
    end
    if handleWorldHopRequests() then
        return
    end
    if RUNTIME.hopPending then
        setAction("Waiting for world hop checkpoint")
        return
    end
    chargeGOTE()

    if #API.GetAllObjArray1({ IDS.banker }, 50, { 1 }) == 0 and RUNTIME.iteration == 1 and not isAnimating() and not isMoving() then
        if not goToDaemonheim() then
            stopRun("Failed to reach Daemonheim on start")
            return
        end
    end

    if not CONFIG.redeemArtifacts and not RUNTIME.presetResetInitialized and RUNTIME.iteration == 1 and not isAnimating() and not isMoving() then
        if not runPresetReset() then
            stopRun("Preset load failed")
            return
        end
        RUNTIME.presetResetInitialized = true
        return
    end

    local inventoryFull = safeInventoryIsFull("main loop full check")
    if inventoryFull == nil then
        setAction("Waiting for inventory array rebuild")
        return
    end

    if inventoryFull then
        if shouldRedeemNow() then
            if not runRedeemCycle() then
                stopRun("Redemption cycle failed")
                return
            end
                    if not runPresetReset() then
                        stopRun("Preset reset failed after redemption")
                        return
                    end
        else
            trackBankedArtifacts()
            if not runPresetReset() then
                stopRun("Preset reset failed")
                return
            end
        end

                RUNTIME.spotIndex = (RUNTIME.spotIndex % #SPOT_IDS) + 1
                RUNTIME.clickedSpotTile = nil
        RUNTIME.iteration = RUNTIME.iteration + 1
        return
    end

    if not excavate() then
        stopRun("Excavation failed")
        return
    end
end

Gui.loadConfig()
sanitizeConfig()

while API.Read_LoopyLoop() do
    if RUNTIME.started then
        tick()
    else
        setState(STATE.IDLE, RUNTIME.stopReason ~= "" and RUNTIME.stopReason or "Waiting to start")
        setAction("Idle")
        API.DoRandomEvents()
    end

    collectgarbage("collect")
    loopDelay()
end
