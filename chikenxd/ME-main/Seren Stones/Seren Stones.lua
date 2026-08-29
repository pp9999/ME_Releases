--[[
#Script Name:   Seren Stones Prayer
# Description:  Automates cleansing corrupted Seren stones using cleansing crystals
#               and purchases crystals from the Hefin Monk when needed.
# Features:     Modern WorldHop support, Seren GUI, Prayer XP failsafe
# Version:      2.0
--]]

local API = require("api")
local SHOP = require("shop")
local SerenGUI = require("SerenStones.SerenStonesGUI")

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

local SCRIPT_NAME = "Seren Stones"
local CLEANSING_CRYSTAL_ID = 32615
local HEFIN_MONK_IDS = { 20270, 20271 }
local CORRUPTED_SEREN_STONE_ID = 94048
local SEREN_CLEANSE_ANIM = 24556
local XP_FAILSAFE_SECONDS = 300
local XP_SKILL = "PRAYER"

local runtime = {
    running = false,
    state = "Idle",
    scriptStartTime = 0,
    startXp = 0,
    crystalsPurchased = 0,
    crystalsUsed = 0,
    worldHops = 0,
    currentWorld = 0,
    nextWorldHopAt = nil,
    worldHopPending = false,
    worldHopReason = nil,
    purchaseAttempts = 0,
    tradeAttempts = 0,
    stoneClickAttempts = 0,
    stoneResponseDeadline = nil,
    tradeResponseDeadline = nil,
    purchaseResponseDeadline = nil,
    purchaseBeforeCount = 0,
    lastXp = 0,
    lastXpTime = os.time(),
}

local function logInfo(message)
    print(string.format("[%s] %s", SCRIPT_NAME, tostring(message)))
end

local function logError(message)
    print(string.format("[%s][ERROR] %s", SCRIPT_NAME, tostring(message)))
end

local function stopScript(reason)
    if reason and reason ~= "" then
        logError(reason)
    end
    runtime.running = false
    API.Write_LoopyLoop(false)
end

local function gameStateChecks()
    if API.GetGameState2 and API.GetGameState2() ~= 3 then
        return false
    end
    return API.Read_LoopyLoop() == true
end

local function updateXpTracker()
    local currentXp = API.GetSkillXP(XP_SKILL) or 0
    if currentXp > runtime.lastXp then
        runtime.lastXp = currentXp
        runtime.lastXpTime = os.time()
    end
end

local function refreshXpBaseline()
    runtime.lastXp = API.GetSkillXP(XP_SKILL) or runtime.lastXp
    runtime.lastXpTime = os.time()
end

local function checkXpFailsafe()
    if os.difftime(os.time(), runtime.lastXpTime) >= XP_FAILSAFE_SECONDS then
        stopScript("No Prayer XP gained for " .. XP_FAILSAFE_SECONDS .. " seconds")
        return true
    end
    return false
end

local function hasCrystals()
    local inventory = API.ReadInvArrays33()
    if not inventory then
        return false, 0
    end

    local count = 0
    for i = 1, #inventory do
        if inventory[i].itemid1 == CLEANSING_CRYSTAL_ID then
            count = count + (inventory[i].itemid1_size or 1)
        end
    end

    return count > 0, count
end

local function getCrystalCount()
    local _, count = hasCrystals()
    return count
end

local function getTargetCrystalCount()
    local cfg = SerenGUI.getConfig()
    return math.min(30, math.max(1, tonumber(cfg.targetCrystalCount) or 30))
end

local function isAnimating()
    return (tonumber(API.ReadPlayerAnim and API.ReadPlayerAnim()) or 0) ~= 0
end

local function getCurrentAnimation()
    return tonumber(API.ReadPlayerAnim and API.ReadPlayerAnim()) or 0
end

local function isMoving()
    if type(API.ReadPlayerMovin2) == "function" then
        return API.ReadPlayerMovin2() == true
    end
    return API.ReadPlayerMovin and API.ReadPlayerMovin() == true
end

local function isShopOpen()
    if not SHOP.isOpen() then
        return false
    end

    local shopTabState = API.VB_FindPSettinOrder and API.VB_FindPSettinOrder(5147, 0)
    if type(shopTabState) == "table" and (tonumber(shopTabState.state) or 0) > 0 then
        return true
    end

    local items = SHOP.getItems()
    return items ~= nil and #items > 0
end

local function closeShopIfOpen()
    if not isShopOpen() then
        return false
    end

    API.KeyboardPress2(27, 50, 20)
    local deadline = os.clock() + 2.5
    while API.Read_LoopyLoop() and os.clock() < deadline do
        if not isShopOpen() then
            API.RandomSleep2(240, 60, 30)
            return true
        end
        API.RandomSleep2(120, 30, 20)
    end
    return true
end

local function scheduleNextWorldHop()
    local cfg = SerenGUI.getConfig()
    if not cfg.enableWorldHop then
        runtime.nextWorldHopAt = nil
        return
    end

    local minSec = math.max(1, tonumber(cfg.hopIntervalMin) or 45) * 60
    local maxSec = math.max(minSec, tonumber(cfg.hopIntervalMax) or minSec) * 60
    runtime.nextWorldHopAt = os.time() + math.random(minSec, maxSec)
end

local function hasNearbyPlayer(rangeSquared)
    local players = API.ReadAllObjectsArray({ 2 }, {}, {})
    if not players or #players == 0 then
        return false
    end

    local playerPos = API.PlayerCoordfloat()
    if not playerPos then
        return false
    end

    local localName = API.GetLocalPlayerName and API.GetLocalPlayerName() or nil
    for i = 1, #players do
        local player = players[i]
        if player and player.Tile_XYZ then
            if localName and player.Name == localName then
                -- skip self
            else
                local dx = playerPos.x - player.Tile_XYZ.x
                local dy = playerPos.y - player.Tile_XYZ.y
                local distSq = (dx * dx) + (dy * dy)
                if distSq > 0 and distSq <= rangeSquared then
                    return true
                end
            end
        end
    end

    return false
end

local function markWorldHopPending(reason)
    if runtime.worldHopPending then
        return
    end
    runtime.worldHopPending = true
    runtime.worldHopReason = reason
    runtime.state = "World hop pending: " .. tostring(reason)
end

local function performWorldHop()
    if type(WorldHop) ~= "table" then
        stopScript("WorldHop API unavailable")
        return true
    end

    local currentBefore = WorldHop:GetCurrentWorld()
    local targetWorld = currentBefore
    for _ = 1, 6 do
        targetWorld = WorldHop:GetRandomWorld(true)
        if targetWorld and targetWorld ~= currentBefore then
            break
        end
    end

    if not targetWorld or targetWorld == currentBefore then
        logError("Could not find a valid random members world")
        runtime.worldHopPending = false
        scheduleNextWorldHop()
        return true
    end

    runtime.state = "Opening world hop"
    if not WorldHop:Open() then
        logError("WorldHop:Open() failed")
        runtime.worldHopPending = false
        scheduleNextWorldHop()
        API.RandomSleep2(1200, 220, 120)
        return true
    end

    API.RandomSleep2(900, 180, 90)

    runtime.state = "Hopping to world " .. tostring(targetWorld)
    if not WorldHop:Hop(targetWorld) then
        logError("WorldHop:Hop() failed")
        runtime.worldHopPending = false
        scheduleNextWorldHop()
        API.RandomSleep2(1200, 220, 120)
        return true
    end

    local hopStarted = os.time()
    while API.Read_LoopyLoop() and os.difftime(os.time(), hopStarted) < 15 do
        local currentAfter = WorldHop:GetCurrentWorld()
        if currentAfter == targetWorld then
            runtime.currentWorld = currentAfter
            runtime.worldHops = runtime.worldHops + 1
            runtime.worldHopPending = false
            runtime.worldHopReason = nil
            scheduleNextWorldHop()
            refreshXpBaseline()
            runtime.state = "World hopped to " .. tostring(currentAfter)
            API.RandomSleep2(1800, 260, 140)
            return true
        end
        API.RandomSleep2(240, 60, 30)
    end

    logError("World hop timed out")
    runtime.worldHopPending = false
    runtime.worldHopReason = nil
    scheduleNextWorldHop()
    return true
end

local function handlePendingWorldHop()
    local cfg = SerenGUI.getConfig()
    if not cfg.enableWorldHop then
        return false
    end

    if not runtime.worldHopPending and runtime.nextWorldHopAt and os.time() >= runtime.nextWorldHopAt then
        markWorldHopPending("timer")
    end

    if not runtime.worldHopPending and cfg.hopOnNearbyPlayer then
        local rangeSquared = math.max(1, tonumber(cfg.nearbyRange) or 20)
        rangeSquared = rangeSquared * rangeSquared
        if hasNearbyPlayer(rangeSquared) then
            markWorldHopPending("nearby player")
        end
    end

    if not runtime.worldHopPending then
        return false
    end

    if isShopOpen() then
        runtime.state = "Closing shop for world hop"
        closeShopIfOpen()
        return true
    end

    if isAnimating() or isMoving() then
        runtime.state = "Waiting to world hop"
        return true
    end

    return performWorldHop()
end

local function handleCrystalPurchaseFlow()
    local cfg = SerenGUI.getConfig()
    local crystalCount = getCrystalCount()
    local targetCrystalCount = getTargetCrystalCount()

    if runtime.purchaseBeforeCount > 0 and crystalCount > runtime.purchaseBeforeCount then
        runtime.crystalsPurchased = runtime.crystalsPurchased + (crystalCount - runtime.purchaseBeforeCount)
        runtime.purchaseBeforeCount = 0
        runtime.purchaseAttempts = 0
        runtime.purchaseResponseDeadline = nil
    end

    if crystalCount >= targetCrystalCount then
        runtime.purchaseBeforeCount = 0
        runtime.purchaseAttempts = 0
        runtime.tradeAttempts = 0
        runtime.tradeResponseDeadline = nil
        runtime.purchaseResponseDeadline = nil
        return false
    end

    if cfg.purchaseCrystalsIfNeeded ~= true then
        stopScript("Out of cleansing crystals and auto-purchase is disabled")
        return true
    end

    if isShopOpen() then
        runtime.state = string.format("Buying cleansing crystals (%d/%d)", crystalCount, targetCrystalCount)
        if runtime.purchaseResponseDeadline and os.clock() < runtime.purchaseResponseDeadline then
            return true
        end

        if runtime.purchaseResponseDeadline and os.clock() >= runtime.purchaseResponseDeadline then
            runtime.purchaseAttempts = runtime.purchaseAttempts + 1
            runtime.purchaseResponseDeadline = nil
            runtime.purchaseBeforeCount = 0
            if runtime.purchaseAttempts >= 3 then
                stopScript("Could not buy cleansing crystals from shop")
                return true
            end
            API.RandomSleep2(180, 45, 25)
        end

        if not SHOP.contains(CLEANSING_CRYSTAL_ID) then
            stopScript("Cleansing crystals not found in shop")
            return true
        end

        runtime.purchaseBeforeCount = crystalCount
        local bought = SHOP.buyId(CLEANSING_CRYSTAL_ID, SHOP.BUY_OPTIONS.ONE)
        if not bought then
            runtime.purchaseAttempts = runtime.purchaseAttempts + 1
            if runtime.purchaseAttempts >= 3 then
                stopScript("Failed to send crystal purchase action")
                return true
            end
            API.RandomSleep2(180, 45, 25)
            return true
        end

        runtime.purchaseResponseDeadline = os.clock() + 1.0
        API.RandomSleep2(180, 45, 25)
        return true
    end

    runtime.state = "Opening Hefin Monk shop"
    if runtime.tradeResponseDeadline and os.clock() < runtime.tradeResponseDeadline then
        return true
    end

    if runtime.tradeResponseDeadline and os.clock() >= runtime.tradeResponseDeadline then
        runtime.tradeAttempts = runtime.tradeAttempts + 1
        runtime.tradeResponseDeadline = nil
        if runtime.tradeAttempts >= 5 then
            stopScript("Could not open Hefin Monk shop")
            return true
        end
        API.RandomSleep2(700, 140, 70)
    end

    local traded = API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, HEFIN_MONK_IDS, 50)
    if not traded then
        runtime.tradeAttempts = runtime.tradeAttempts + 1
        if runtime.tradeAttempts >= 5 then
            stopScript("Failed to interact with Hefin Monk")
            return true
        end
        API.RandomSleep2(900, 180, 90)
        return true
    end

    runtime.tradeResponseDeadline = os.clock() + 6.0
    API.RandomSleep2(1200, 220, 120)
    return true
end

local function handleSerenStone()
    if isAnimating() then
        if runtime.stoneResponseDeadline then
            runtime.crystalsUsed = runtime.crystalsUsed + 1
            runtime.stoneResponseDeadline = nil
            runtime.stoneClickAttempts = 0
        end
        runtime.state = "Cleansing Seren stone"
        return true
    end

    if runtime.stoneResponseDeadline and os.clock() < runtime.stoneResponseDeadline then
        runtime.state = "Waiting for cleanse response"
        return true
    end

    if runtime.stoneResponseDeadline and os.clock() >= runtime.stoneResponseDeadline then
        runtime.stoneResponseDeadline = nil
        runtime.stoneClickAttempts = runtime.stoneClickAttempts + 1
        if runtime.stoneClickAttempts >= 5 then
            stopScript("Failed to start cleansing the Seren stone")
            return true
        end
        API.RandomSleep2(900, 180, 90)
    end

    if isMoving() then
        runtime.state = "Settling before stone click"
        return true
    end

    runtime.state = "Clicking corrupted Seren stone"
    local clicked = API.DoAction_Object1(0x3d, API.OFF_ACT_GeneralObject_route0, { CORRUPTED_SEREN_STONE_ID }, 50)
    if not clicked then
        runtime.stoneClickAttempts = runtime.stoneClickAttempts + 1
        if runtime.stoneClickAttempts >= 5 then
            stopScript("Could not interact with Corrupted Seren Stone")
            return true
        end
        API.RandomSleep2(800, 160, 80)
        return true
    end

    runtime.stoneResponseDeadline = os.clock() + 3.5
    API.RandomSleep2(1000, 220, 120)
    return true
end

local function shouldHandleCrystalPurchase()
    local crystalCount = getCrystalCount()
    if crystalCount <= 0 then
        if getCurrentAnimation() == SEREN_CLEANSE_ANIM then
            runtime.state = "Waiting for cleanse animation to finish before refill"
            return false
        end
        return true
    end

    if isShopOpen() and crystalCount < getTargetCrystalCount() then
        return true
    end

    return false
end

local function formatRuntime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function formatNumberWithCommas(value)
    local formatted = tostring(math.floor(tonumber(value) or 0))
    local sign, digits = formatted:match("^([%-]?)(%d+)$")
    if not digits then
        return formatted
    end

    local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
    local cleaned = reversed:reverse():gsub("^,", "")
    return (sign or "") .. cleaned
end

local function captureStartXp()
    local xp = API.GetSkillXP(XP_SKILL)
    if type(xp) == "number" and xp > 0 then
        return xp
    end

    local deadline = os.clock() + 2.0
    while API.Read_LoopyLoop() and os.clock() < deadline do
        API.RandomSleep2(120, 30, 20)
        xp = API.GetSkillXP(XP_SKILL)
        if type(xp) == "number" and xp > 0 then
            return xp
        end
    end

    return tonumber(xp) or 0
end

local function getXpTotal()
    local currentXp = API.GetSkillXP(XP_SKILL) or runtime.startXp or 0
    local total = currentXp - (runtime.startXp or 0)
    if total < 0 then
        total = 0
    end
    return total
end

local function getXpPerHour()
    if runtime.scriptStartTime <= 0 then
        return 0
    end

    local elapsedSeconds = os.difftime(os.time(), runtime.scriptStartTime)
    if elapsedSeconds <= 0 then
        return 0
    end

    return math.floor((getXpTotal() * 3600) / elapsedSeconds)
end

local function getNextHopText()
    local cfg = SerenGUI.getConfig()
    if not cfg.enableWorldHop or not runtime.nextWorldHopAt then
        return "Disabled"
    end
    local remaining = runtime.nextWorldHopAt - os.time()
    if remaining < 0 then
        remaining = 0
    end
    return formatRuntime(remaining)
end

local function getXpFailsafeText()
    local remaining = XP_FAILSAFE_SECONDS - os.difftime(os.time(), runtime.lastXpTime)
    if remaining < 0 then
        remaining = 0
    end
    return remaining .. "s"
end

local function resetRuntime()
    runtime.running = true
    runtime.state = "Starting"
    runtime.scriptStartTime = os.time()
    runtime.startXp = captureStartXp()
    runtime.crystalsPurchased = 0
    runtime.crystalsUsed = 0
    runtime.worldHops = 0
    runtime.currentWorld = type(WorldHop) == "table" and WorldHop:GetCurrentWorld() or (API.GetWorldNR and API.GetWorldNR()) or 0
    runtime.worldHopPending = false
    runtime.worldHopReason = nil
    runtime.purchaseAttempts = 0
    runtime.tradeAttempts = 0
    runtime.stoneClickAttempts = 0
    runtime.stoneResponseDeadline = nil
    runtime.tradeResponseDeadline = nil
    runtime.purchaseResponseDeadline = nil
    runtime.purchaseBeforeCount = 0
    refreshXpBaseline()
    scheduleNextWorldHop()
end

local function drawGui()
    SerenGUI.draw({
        running = runtime.running,
        state = runtime.state,
        xpTotalText = formatNumberWithCommas(getXpTotal()),
        xpPerHourText = formatNumberWithCommas(getXpPerHour()),
        crystalsPurchased = runtime.crystalsPurchased,
        crystalsUsed = runtime.crystalsUsed,
        worldHops = runtime.worldHops,
        currentWorld = runtime.currentWorld,
        nextHopText = getNextHopText(),
        xpFailsafeText = getXpFailsafeText(),
        runtimeText = runtime.scriptStartTime > 0 and formatRuntime(os.difftime(os.time(), runtime.scriptStartTime)) or "00:00:00",
    })
end

local function registerGui()
    if type(DrawImGui) ~= "function" then
        logError("DrawImGui is unavailable")
        return
    end
    if type(ClearRender) == "function" then
        pcall(ClearRender)
    end
    DrawImGui(function()
        drawGui()
    end)
end

registerGui()
API.SetMaxIdleTime(5)
API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    if SerenGUI.consumeStopRequest() then
        stopScript("Stopped by user")
        break
    end

    if not runtime.running then
        if SerenGUI.consumeStartRequest() then
            resetRuntime()
            logInfo("Starting Seren Stones v2.0")
        else
            API.RandomSleep2(160, 40, 20)
        end
    else
        if not gameStateChecks() then
            stopScript("Game state check failed")
            break
        end

        updateXpTracker()
        if checkXpFailsafe() then
            break
        end

        runtime.currentWorld = type(WorldHop) == "table" and WorldHop:GetCurrentWorld() or runtime.currentWorld

        if handlePendingWorldHop() then
            API.RandomSleep2(180, 50, 25)
        else
            if shouldHandleCrystalPurchase() then
                handleCrystalPurchaseFlow()
            else
                handleSerenStone()
            end
            API.RandomSleep2(220, 60, 30)
        end
    end
end

if runtime.scriptStartTime > 0 then
    logInfo("Runtime: " .. formatRuntime(os.difftime(os.time(), runtime.scriptStartTime)))
    logInfo("Crystals Purchased: " .. tostring(runtime.crystalsPurchased))
    logInfo("Crystals Used: " .. tostring(runtime.crystalsUsed))
    logInfo("World Hops: " .. tostring(runtime.worldHops))
end