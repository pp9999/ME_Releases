local API = require("api")
local DATA = require("Divination AIO/div_data")
local idleHandler = require("Divination AIO/idle_handler")

local Utils = {}

local containerCheckBuf = {0}
local empoweredRiftBuf = {DATA.IDS.EMPOWERED_RIFT}
local normalRiftBuf = {DATA.IDS.RIFT}
local empoweredRiftTypeBuf = {DATA.RIFT_OBJ_TYPE.EMPOWERED}
local normalRiftTypeBuf = {DATA.RIFT_OBJ_TYPE.NORMAL}
local npcTypeBuf = {1}
local wispSearchBuf = {0}

local function waitForCondition(condition, timeout)
    timeout = timeout or 10
    local startTime = os.clock()
    while (os.clock() - startTime) < timeout and API.Read_LoopyLoop() do
        idleHandler.check()
        idleHandler.collectGarbage()
        if condition() then return true end
        API.RandomSleep2(250, 250, 0)
    end
    return false
end

function Utils.clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function Utils.formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return string.format("%d", num)
end

function Utils.isWithinDistance(x1, y1, x2, y2, threshold)
    return (x2 - x1)^2 + (y2 - y1)^2 <= threshold * threshold
end

local cachedRiftObj = nil
local cachedRiftName = nil
local cachedRiftEmpowered = false
local riftCacheTime = 0

function Utils.findRift(range)
    range = range or 50
    local now = os.clock()
    if cachedRiftObj and (now - riftCacheTime) < 5 then
        return cachedRiftObj, cachedRiftName, cachedRiftEmpowered
    end
    local empowered = API.GetAllObjArray1(empoweredRiftBuf, range, empoweredRiftTypeBuf)
    if #empowered > 0 then
        cachedRiftObj = empowered[1]
        cachedRiftName = "Energy Rift"
        cachedRiftEmpowered = true
        riftCacheTime = now
        return cachedRiftObj, cachedRiftName, cachedRiftEmpowered
    end
    local normal = API.GetAllObjArray1(normalRiftBuf, range, normalRiftTypeBuf)
    if #normal > 0 then
        cachedRiftObj = normal[1]
        cachedRiftName = "Energy rift"
        cachedRiftEmpowered = false
        riftCacheTime = now
        return cachedRiftObj, cachedRiftName, cachedRiftEmpowered
    end
    cachedRiftObj = nil
    cachedRiftName = nil
    cachedRiftEmpowered = false
    riftCacheTime = now
    return nil, nil, false
end

function Utils.checkLocation(wispDef)
    local rift = Utils.findRift(50)
    if not rift then
        API.printlua("No rift found nearby", 4, false)
        return false
    end

    local riftX = rift.Tile_XYZ.x
    local riftY = rift.Tile_XYZ.y
    if not Utils.isWithinDistance(riftX, riftY, wispDef.riftCoord.x, wispDef.riftCoord.y, 2) then
        API.printlua(string.format("Rift not at expected location (found: %.0f, %.0f)", riftX, riftY), 4, false)
        return false
    end

    if rift.Distance > 49 then
        API.printlua(string.format("Too far from rift (distance: %.0f)", rift.Distance), 4, false)
        return false
    end

    return true
end

function Utils.depositMemories(wispDef)
    local memoryCount = Inventory:GetItemAmount(wispDef.memoryId)
    local enrichedCount = 0
    if wispDef.enrichedMemoryId then
        enrichedCount = Inventory:GetItemAmount(wispDef.enrichedMemoryId)
    end

    if memoryCount == 0 and enrichedCount == 0 then
        return true
    end

    API.printlua(string.format("Depositing %d normal + %d enriched memories", memoryCount, enrichedCount), 0, false)

    local _, riftName = Utils.findRift(50)
    if not riftName then
        API.printlua("No rift found to deposit memories", 4, false)
        return false
    end

    Interact:Object(riftName, "Convert memories", 50)
    API.RandomSleep2(600, 200, 200)

    local lastChangeTime = os.clock()
    local lastMemoryCount = memoryCount
    local lastEnrichedCount = enrichedCount

    waitForCondition(function()
        local currentMemory = Inventory:GetItemAmount(wispDef.memoryId)
        local currentEnriched = 0
        if wispDef.enrichedMemoryId then
            currentEnriched = Inventory:GetItemAmount(wispDef.enrichedMemoryId)
        end

        if currentMemory == 0 and currentEnriched == 0 then
            return true
        end

        if currentMemory ~= lastMemoryCount or currentEnriched ~= lastEnrichedCount then
            lastChangeTime = os.clock()
            lastMemoryCount = currentMemory
            lastEnrichedCount = currentEnriched
        end

        if (os.clock() - lastChangeTime) >= 8 then
            return true
        end

        return false
    end, 60)

    local finalMemory = Inventory:GetItemAmount(wispDef.memoryId)
    local finalEnriched = 0
    if wispDef.enrichedMemoryId then
        finalEnriched = Inventory:GetItemAmount(wispDef.enrichedMemoryId)
    end

    if finalMemory == 0 and finalEnriched == 0 then
        API.printlua("All memories deposited", 0, false)
        return true
    end

    API.printlua(string.format("Deposit incomplete: %d normal + %d enriched remaining", finalMemory, finalEnriched), 4, false)
    return false
end

local function searchNPC(id, range)
    wispSearchBuf[1] = id
    return API.GetAllObjArray1(wispSearchBuf, range or 50, npcTypeBuf)
end

function Utils.checkEnrichedAvailable(wispDef)
    if wispDef.enrichedSpringId then
        if #searchNPC(wispDef.enrichedSpringId) > 0 then
            return true
        end
    end
    if wispDef.enrichedWispId then
        if #searchNPC(wispDef.enrichedWispId) > 0 then
            return true
        end
    end
    return false
end

function Utils.findAndInteractWisp(wispDef, state, tracking)
    local targetId = nil
    local targetName = nil
    local wispNameLower = wispDef.name:lower()

    API.RandomSleep2(600, 2500, math.random(600, 1000))

    if wispDef.enrichedSpringId then
        if #searchNPC(wispDef.enrichedSpringId) > 0 then
            targetId = wispDef.enrichedSpringId
            targetName = "Enriched spring"
            Interact:NPC("Enriched " .. wispNameLower .. " spring", "Harvest", 50)
        end
    end

    if not targetId and wispDef.enrichedWispId then
        if #searchNPC(wispDef.enrichedWispId) > 0 then
            targetId = wispDef.enrichedWispId
            targetName = "Enriched wisp"
            Interact:NPC("Enriched " .. wispNameLower .. " wisp", "Harvest", 50)
        end
    end

    if not targetId then
        if #searchNPC(wispDef.springId) > 0 then
            targetId = wispDef.springId
            targetName = "Spring"
            Interact:NPC(wispDef.name .. " spring", "Harvest", 50)
        end
    end

    if not targetId then
        if #searchNPC(wispDef.wispId) > 0 then
            targetId = wispDef.wispId
            targetName = "Wisp"
            Interact:NPC(wispDef.name .. " wisp", "Harvest", 50)
        end
    end

    if not targetId then return false end

    state.currentTarget = targetName
    state.currentState = "Siphoning"

    local lastActivityTime = os.clock()
    local animStarted = waitForCondition(function()
        if API.ReadPlayerMovin2() then
            lastActivityTime = os.clock()
        end
        if API.ReadPlayerAnim() == DATA.IDS.SIPHON_ANIM then
            return true
        end
        return (os.clock() - lastActivityTime) >= 5
    end, 15)

    if not animStarted or API.ReadPlayerAnim() ~= DATA.IDS.SIPHON_ANIM then
        state.currentState = "Idle"
        return false
    end

    API.printlua("Siphoning " .. targetName, 0, false)

    local isHarvestingEnriched = (targetId == wispDef.enrichedSpringId or targetId == wispDef.enrichedWispId)
    local lastEnrichedCheck = 0

    waitForCondition(function()
        Utils.updateTracking(wispDef, tracking)

        if API.ReadPlayerAnim() ~= DATA.IDS.SIPHON_ANIM then
            return true
        end

        if not isHarvestingEnriched then
            local now = os.clock()
            if now - lastEnrichedCheck >= 2 then
                lastEnrichedCheck = now
                if Utils.checkEnrichedAvailable(wispDef) then
                    API.printlua("Enriched appeared, switching", 0, false)
                    state.shouldSwitchToEnriched = true
                    return true
                end
            end
        end

        return false
    end, 180)

    state.currentState = "Idle"
    return true
end

function Utils.changeConversionMode(targetMode)
    local modeName = DATA.CONVERSION_MODES[targetMode] or "Unknown"
    API.printlua("Changing conversion mode to: " .. modeName, 0, false)

    local _, riftName = Utils.findRift(50)
    if not riftName then
        API.printlua("No rift found to change conversion settings", 4, false)
        return false
    end

    Interact:Object(riftName, "Configure", 50)

    local interfaceOpened = waitForCondition(function()
        local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.RIFT_CONFIGURE)
        if result and result[1] and result[1].textids then
            local text = result[1].textids
            return text == "Memory Conversion:" or text == "Memory Conversion"
        end
        return false
    end, 5)

    if not interfaceOpened then
        API.printlua("Failed to open conversion mode interface", 4, false)
        return false
    end

    local iface = DATA.INTERFACES.CONVERSION_MODE[targetMode]
    if not iface then
        API.printlua("Unknown conversion mode: " .. tostring(targetMode), 4, false)
        return false
    end

    API.DoAction_Interface(0x24, 0xffffffff, 1, 131, iface[2], iface[3], API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(300, 150, 150)

    local modeUpdated = waitForCondition(function()
        return API.GetVarbitValue(DATA.VARBIT_IDS.CONVERSION_MODE) == targetMode
    end, 5)

    if not modeUpdated then
        API.printlua("Failed to update conversion mode", 4, false)
        return false
    end

    API.printlua("Conversion mode changed to: " .. modeName, 0, false)
    return true
end

function Utils.checkEquipment(memoryDowser)
    if not memoryDowser then return true end

    containerCheckBuf[1] = DATA.IDS.MEMORY_DOWSER
    if not API.Container_Check_Items(DATA.EQUIPMENT_CONTAINER, containerCheckBuf) then
        API.printlua("Memory Dowser not equipped", 4, false)
        return false
    end

    API.printlua("Memory Dowser equipped", 0, false)

    if API.GetVarbitValue(DATA.VARBIT_IDS.RUN_ENABLED) == 1 then
        API.printlua("Disabling run for Memory Dowser", 0, false)
        local iface = DATA.INTERFACES.RUN_TOGGLE
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, iface[1], iface[2], iface[3], API.OFF_ACT_GeneralInterface_route)
        waitForCondition(function()
            return API.GetVarbitValue(DATA.VARBIT_IDS.RUN_ENABLED) == 0
        end, 3)
    end

    return true
end

function Utils.updateTracking(wispDef, tracking)
    local newEnergy = Inventory:GetItemAmount(wispDef.energyId)
    if newEnergy ~= tracking.energy.current then
        tracking.energy.current = newEnergy
        tracking.energy.gained = tracking.energy.current - tracking.energy.start
    end

    local newStrands = API.GetVarbitValue(DATA.VARBIT_IDS.MEMORY_STRANDS)
    if newStrands ~= tracking.strands.current then
        tracking.strands.current = newStrands
        tracking.strands.gained = tracking.strands.current - tracking.strands.start
    end
end

return Utils
