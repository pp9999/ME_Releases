local API = require("api")

local SCRIPT_NAME = "AIO Empty Throne Room"
local SCRIPT_VERSION = "1.3.3.7"
local AUTHOR = "Bobi"
local MAX_EXP_CAP = 800000

local function getScriptPath()
    local src = debug.getinfo(1, "S").source
    if src and string.sub(src, 1, 1) == "@" then
        return string.match(string.sub(src, 2), "^(.*[/\\])") or ""
    end
    return ""
end

local TRACKER_FILE = getScriptPath() .. "empty_throne_room_tracker.json"

local Config = {
    activityMode = 0,
    prioritizeEmpowered = true,
    stopAtCap = true,
    customCapAmount = MAX_EXP_CAP,
    rechargeSilverhawks = true,
    silverhawkMinCharges = 50,
    minReactionDelayMs = 400,
    maxReactionDelayMs = 1100,
    randomMicroBreaks = true,
    actionDelayMs = 500
}

local Stats = {
    startTime = os.time(),
    startXP = 0,
    currentXP = 0,
    sessionGainedXP = 0,
    priorLifetimeXP = 0,
    totalTrackedXP = 0,
    remainingCapXP = MAX_EXP_CAP,
    xpPerHour = 0,
    startLevel = 0,
    currentLevel = 0,
    empoweredSwaps = 0,
    actionsCount = 0,
    lastXpGainTime = os.time(),
    lastSaveTime = os.time()
}

local currentStatus = "Paused"
local isRunning = true
local isPaused = true
local activeCycleTile = nil
local activeCycleIsEmpowered = false
local lastActiveBikeKey = nil
local allTrackerData = {}
local currentPlayerName = "Unknown"

local lastEmpoweredCrateKey = nil

local CRATE_DEFS = {
    Yellow = { name = "Crate of yellow crystals", color = "Yellow", normalId = 105571, empId = 105572, comp = 1, vb = 39019, tile = { x = 2822, y = 12646, z = 14 }, itemPatterns = { "Yellow crystal" } },
    Green  = { name = "Crate of green crystals", color = "Green", normalId = 105573, empId = 105574, comp = 5, vb = 39020, tile = { x = 2822, y = 12642, z = 14 }, itemPatterns = { "Green crystal" } },
    Blue   = { name = "Crate of blue crystals", color = "Blue", normalId = 105575, empId = 105576, comp = 9, vb = 39021, tile = { x = 2822, y = 12632, z = 14 }, itemPatterns = { "Blue crystal" } },
    Red    = { name = "Crate of red crystals", color = "Red", normalId = 105577, empId = 105578, comp = 13, vb = 39022, tile = { x = 2822, y = 12628, z = 14 }, itemPatterns = { "Red crystal" } }
}

local function sleep(ms, jitter)
    local total = ms + math.random(-(jitter or 50), (jitter or 50))
    API.RandomSleep2(math.max(20, total), 0, 0)
end

local function formatTime(seconds)
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
end

local function formatNumber(num)
    local formatted = tostring(math.floor(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function getSkillName()
    return Config.activityMode == 0 and "AGILITY" or "DIVINATION"
end

local function getSkillId()
    return Config.activityMode == 0 and 32 or 50
end

local function loadTrackerFile()
    allTrackerData = {}
    local file = io.open(TRACKER_FILE, "r") or io.open("empty_throne_room_tracker.json", "r")
    if file then
        local content = file:read("*a")
        file:close()
        if content and #content > 0 then
            local status, decoded = pcall(function() return API.JsonDecode(content) end)
            if status and type(decoded) == "table" then allTrackerData = decoded end
        end
    end

    currentPlayerName = API.GetLocalPlayerName()
    if not currentPlayerName or currentPlayerName == "" or currentPlayerName == "none" then
        currentPlayerName = API.ReadLPNameP() or "Default"
    end

    if not allTrackerData[currentPlayerName] then
        allTrackerData[currentPlayerName] = { totalXpGained = 0, agilityXp = 0, divinationXp = 0, lastUpdated = os.date("%Y-%m-%d %H:%M:%S") }
    end

    local rec = allTrackerData[currentPlayerName]
    if rec.settings then
        for k, v in pairs(rec.settings) do
            if Config[k] ~= nil then Config[k] = v end
        end
    end

    if Config.activityMode == 0 then
        Stats.priorLifetimeXP = rec.agilityXp or rec.totalXpGained or 0
    else
        Stats.priorLifetimeXP = rec.divinationXp or 0
    end

    Stats.totalTrackedXP = Stats.priorLifetimeXP
    Stats.remainingCapXP = math.max(0, Config.customCapAmount - Stats.totalTrackedXP)
end

local function saveTrackerFile()
    local name = API.GetLocalPlayerName()
    if name and name ~= "" and name ~= "none" then currentPlayerName = name end
    if currentPlayerName == "Unknown" or currentPlayerName == "" then return end

    if not allTrackerData[currentPlayerName] then allTrackerData[currentPlayerName] = {} end
    local totalGained = Stats.priorLifetimeXP + Stats.sessionGainedXP
    local rec = allTrackerData[currentPlayerName]

    if Config.activityMode == 0 then
        rec.agilityXp = totalGained
        rec.totalXpGained = totalGained
    else
        rec.divinationXp = totalGained
    end

    rec.remainingCap = math.max(0, Config.customCapAmount - totalGained)
    rec.lastUpdated = os.date("%Y-%m-%d %H:%M:%S")
    rec.settings = {
        prioritizeEmpowered = Config.prioritizeEmpowered,
        stopAtCap = Config.stopAtCap,
        customCapAmount = Config.customCapAmount,
        rechargeSilverhawks = Config.rechargeSilverhawks,
        silverhawkMinCharges = Config.silverhawkMinCharges,
        minReactionDelayMs = Config.minReactionDelayMs,
        maxReactionDelayMs = Config.maxReactionDelayMs
    }

    local encoded = API.JsonEncode(allTrackerData)
    if encoded and #encoded > 0 then
        local file = io.open(TRACKER_FILE, "w") or io.open("empty_throne_room_tracker.json", "w")
        if file then
            file:write(encoded)
            file:close()
        end
    end
end

local function checkSilverhawkRecharge()
    if not Config.rechargeSilverhawks then return false end
    local boots = API.Container_Get_s(94, 30924)
    if boots and boots.item_id == 30924 and boots.Extra_ints and (boots.Extra_ints[2] or 0) < Config.silverhawkMinCharges then
        if Inventory:Contains(30915) then
            API.DoAction_Inventory1(30915, 0, 1, API.OFF_ACT_GeneralInterface_route)
            sleep(600, 100)
            return true
        elseif Inventory:Contains(34823) then
            API.DoAction_Inventory1(34823, 0, 1, API.OFF_ACT_GeneralInterface_route)
            sleep(600, 100)
            return true
        end
    end
    return false
end

local function checkDestroyScroll()
    if Inventory:Contains(39018) or Inventory:Contains("Senntisten scroll") then
        currentStatus = "Destroying Senntisten scroll"
        sleep(math.random(250, 450), 30)
        local slotIndex = 0
        local items = Inventory:GetItems()
        if items then
            for idx, it in ipairs(items) do
                if it and (it.id == 39018 or (it.name and string.find(it.name, "Senntisten scroll"))) then
                    slotIndex = it.slot or (idx - 1)
                    break
                end
            end
        end

        API.DoAction_Interface(0x24, 0x986a, 8, 1473, 5, slotIndex, API.OFF_ACT_GeneralInterface_route2)
        API.RandomSleep2(600, 900, 1300)
        API.KeyboardPress31(89, 0, 0)
        API.RandomSleep2(400, 700, 1000)
        return true
    end
    return false
end

local function scanAutoCycles()
    local objects = API.ReadAllObjectsArray({12, 0}, {}, {})
    local allCycles, empoweredCycle = {}, nil

    if objects then
        for _, obj in ipairs(objects) do
            if obj and obj.Name then
                local name = tostring(obj.Name)
                local id = obj.Id or 0
                local isCycle = (id == 105568 or id == 105565 or id == 105566 or id == 105567 or id == 105569) or string.find(name, "Auto%-cycle") or string.find(name, "Cycle")

                if isCycle then
                    local isEmp = string.find(name, "Empowered") or string.find(tostring(obj.Action or ""), "Empowered")
                    local cycleInfo = {
                        rawObj = obj,
                        id = id,
                        name = name,
                        tile = { x = obj.TileX, y = obj.TileY, z = obj.TileZ },
                        distance = obj.Distance or 0,
                        isEmpowered = isEmp,
                        key = string.format("%d_%d_%d", obj.TileX, obj.TileY, obj.TileZ)
                    }
                    table.insert(allCycles, cycleInfo)
                    if isEmp then empoweredCycle = cycleInfo end
                end
            end
        end
    end

    if not empoweredCycle then
        local empInteract = API.GetAllObjArrayInteract_str({"Manual Auto-cycle (Empowered)"}, 30, {12, 0})
        if empInteract and #empInteract > 0 then
            local eObj = empInteract[1]
            empoweredCycle = {
                rawObj = eObj,
                id = eObj.Id or 0,
                name = eObj.Name or "Manual Auto-cycle (Empowered)",
                tile = { x = eObj.TileX, y = eObj.TileY, z = eObj.TileZ },
                distance = eObj.Distance or 0,
                isEmpowered = true,
                key = string.format("%d_%d_%d", eObj.TileX, eObj.TileY, eObj.TileZ)
            }
            table.insert(allCycles, empoweredCycle)
        end
    end

    return allCycles, empoweredCycle
end

local function isPlayerPedaling()
    local anim, isMoving = API.ReadPlayerAnim(), API.ReadPlayerMovin()
    if anim > 0 and not isMoving then return true end
    if (os.time() - Stats.lastXpGainTime) <= 4 and not isMoving then return true end
    return false
end

local function dismountCurrentCycle()
    local pCoord = API.PlayerCoord()
    local offsets = { {1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, -1}, {1, -1}, {-1, 1} }
    local chosen = offsets[math.random(1, #offsets)]
    local stepTile = WPOINT.new(pCoord.x + chosen[1], pCoord.y + chosen[2], pCoord.z)

    sleep(math.random(60, 160), 20)
    if not API.DoAction_Tile(stepTile) then
        pcall(function() API.DoAction_WalkerW(stepTile) end)
    end
    API.RandomSleep2(1200, 2000, 3500)
end

local function pedalCycle(cycle)
    if not cycle or not cycle.rawObj then return false end

    if isPlayerPedaling() or (lastActiveBikeKey and lastActiveBikeKey ~= cycle.key) then
        dismountCurrentCycle()
    end

    currentStatus = cycle.isEmpowered and "Switching (Empowered)" or "Moving to Cycle"
    sleep(math.random(120, 280), 30)

    local xpBefore = API.GetSkillXP("AGILITY")
    if not API.DoAction_Object_Direct(0xb5, API.OFF_ACT_GeneralObject_route0, cycle.rawObj) then
        pcall(function() Interact:Object(cycle.name, "Pedal", WPOINT.new(cycle.tile.x, cycle.tile.y, cycle.tile.z), 30) end)
    end

    Stats.actionsCount = Stats.actionsCount + 1
    if cycle.isEmpowered then Stats.empoweredSwaps = Stats.empoweredSwaps + 1 end
    activeCycleTile = cycle.tile
    activeCycleIsEmpowered = cycle.isEmpowered
    lastActiveBikeKey = cycle.key

    local startTime = os.time()
    while API.Read_LoopyLoop() and (os.time() - startTime) < 8 do
        sleep(200, 30)
        local currentXp = API.GetSkillXP("AGILITY")
        if currentXp > xpBefore then
            Stats.lastXpGainTime = os.time()
            break
        end
        if API.ReadPlayerAnim() > 0 and not API.ReadPlayerMovin() and (os.time() - startTime) >= 4 then
            break
        end
    end

    API.RandomSleep2(1200, 2000, 3500)
    return true
end

local function scanDivinationNodes()
    local objects = API.ReadAllObjectsArray({0, 12}, {}, {})
    local binObj = nil
    local crates = {}
    local empoweredCrate = nil

    if objects then
        for _, obj in ipairs(objects) do
            if obj and obj.Name then
                local name = tostring(obj.Name)
                local id = obj.Id or 0
                local objType = obj.Type or 0

                if string.find(name, "storage bin") or string.find(name, "Storage bin") or string.find(name, "Crystal storage") then
                    binObj = obj
                end

                for colorKey, cDef in pairs(CRATE_DEFS) do
                    if string.find(name, cDef.color) or id == cDef.normalId or id == cDef.empId then
                        local isEmp = (objType == 0) or (id == cDef.empId) or string.find(name, "Empowered")
                        local crateData = {
                            rawObj = obj,
                            id = id,
                            name = name,
                            color = cDef.color,
                            def = cDef,
                            tile = { x = obj.TileX, y = obj.TileY, z = obj.TileZ },
                            distance = obj.Distance or 0,
                            isEmpowered = isEmp,
                            key = cDef.color
                        }
                        table.insert(crates, crateData)
                        if isEmp then empoweredCrate = crateData end
                    end
                end
            end
        end
    end

    return binObj, crates, empoweredCrate
end

local function getInventoryCrystalCount()
    local count = 0
    local items = Inventory:GetItems()
    if items then
        for _, item in ipairs(items) do
            if item and (item.id == 39017 or item.name == "Senntisten crystal") then
                count = count + (item.amount or 1)
            end
        end
    end
    return count
end

local function getAllTransmutedCrystalsInInventory()
    local found = {}
    local items = Inventory:GetItems()
    if items then
        for _, item in ipairs(items) do
            if item and item.name and item.name ~= "Senntisten crystal" and item.id ~= 39017 then
                for colorKey, cDef in pairs(CRATE_DEFS) do
                    if string.find(item.name, cDef.color) or (item.id and item.id == cDef.vb) then
                        if not found[cDef.color] then
                            found[cDef.color] = { def = cDef, count = 0 }
                        end
                        found[cDef.color].count = found[cDef.color].count + (item.amount or 1)
                    end
                end
            end
        end
    end
    local list = {}
    for _, data in pairs(found) do
        if data.count > 0 then
            table.insert(list, data.def)
        end
    end
    return list
end

local function updateStats()
    local skillName = getSkillName()
    local skillId = getSkillId()
    local currentXp = API.GetSkillXP(skillName)
    local currentLvl = API.GetSkillsTableSkill(skillId)

    if Stats.startXP == 0 and currentXp > 0 then
        Stats.startXP = currentXp
        Stats.startLevel = currentLvl
    end

    if currentXp > Stats.currentXP then
        if Stats.currentXP > 0 then Stats.lastXpGainTime = os.time() end
        Stats.currentXP = currentXp
        Stats.currentLevel = currentLvl
        Stats.sessionGainedXP = Stats.currentXP - Stats.startXP
        Stats.totalTrackedXP = Stats.priorLifetimeXP + Stats.sessionGainedXP
        Stats.remainingCapXP = math.max(0, Config.customCapAmount - Stats.totalTrackedXP)

        if (os.time() - Stats.lastSaveTime) >= 15 then
            saveTrackerFile()
            Stats.lastSaveTime = os.time()
        end
    end

    local elapsed = os.difftime(os.time(), Stats.startTime)
    Stats.xpPerHour = (elapsed > 0 and Stats.sessionGainedXP > 0) and math.floor((Stats.sessionGainedXP / elapsed) * 3600) or 0
end

local function checkAreaWalking(targetX, targetY, areaName)
    local p = API.PlayerCoord()
    if math.sqrt((p.x - targetX)^2 + (p.y - targetY)^2) > 20 then
        currentStatus = "Walking to " .. areaName
        API.DoAction_WalkerW(WPOINT.new(targetX, targetY, p.z))
        API.RandomSleep2(1200, 1800, 2500)
        API.WaitUntilMovingEnds()
        return true
    end
    return false
end

local function stepAgility()
    if checkAreaWalking(2854, 12637, "Agility area") then return end

    if checkSilverhawkRecharge() then
        sleep(600, 100)
        return
    end

    local allCycles, empoweredCycle = scanAutoCycles()

    if #allCycles == 0 then
        currentStatus = "Searching for Cycles..."
        sleep(1000, 100)
        return
    end

    if Config.prioritizeEmpowered and empoweredCycle then
        local empoweredKey = empoweredCycle.key
        if lastActiveBikeKey == empoweredKey and isPlayerPedaling() then
            currentStatus = "Cycling (Empowered 10x)"
            sleep(Config.actionDelayMs, 80)
            return
        else
            if isPlayerPedaling() then
                local reactionDelay = math.random(Config.minReactionDelayMs, Config.maxReactionDelayMs)
                if Config.randomMicroBreaks and math.random(1, 20) == 1 then
                    reactionDelay = reactionDelay + math.random(600, 1400)
                end
                sleep(reactionDelay, 30)
            end
            pedalCycle(empoweredCycle)
            sleep(Config.actionDelayMs, 80)
            return
        end
    end

    if not isPlayerPedaling() then
        local targetCycle = empoweredCycle or allCycles[1]
        if not empoweredCycle then
            local minDist = 9999
            for _, c in ipairs(allCycles) do
                if c.distance < minDist then
                    minDist = c.distance
                    targetCycle = c
                end
            end
        end
        if targetCycle then pedalCycle(targetCycle) end
    else
        currentStatus = activeCycleIsEmpowered and "Cycling (Empowered 10x)" or "Cycling (Normal)"
    end

    sleep(Config.actionDelayMs, 100)
end

local currentCraftingColor = nil

local function stepDivination()
    if checkDestroyScroll() then return end
    if checkAreaWalking(2823, 12637, "Divination area") then return end

    local binObj, crates, empoweredCrate = scanDivinationNodes()

    if empoweredCrate then
        if lastEmpoweredCrateKey and lastEmpoweredCrateKey ~= empoweredCrate.color then
            Stats.empoweredSwaps = Stats.empoweredSwaps + 1
        end
        lastEmpoweredCrateKey = empoweredCrate.color
    end

    local rawCount = getInventoryCrystalCount()
    local coloredList = getAllTransmutedCrystalsInInventory()
    local isFull = Inventory:IsFull()

    if API.isProcessing() then
        if empoweredCrate and currentCraftingColor and empoweredCrate.color ~= currentCraftingColor and rawCount > 0 then
            currentStatus = "Switching to " .. empoweredCrate.color .. " mid-craft"
            API.DoAction_Interface(0x24, 0xffffffff, 1, 1251, 32, -1, API.OFF_ACT_GeneralInterface_route)
            sleep(math.random(400, 700), 50)
            return
        end
        currentStatus = "Transmuting " .. (currentCraftingColor or "Crystals") .. "..."
        sleep(250, 40)
        return
    end

    if #coloredList > 0 and rawCount == 0 then
        local targetDef = coloredList[math.random(1, #coloredList)]
        currentStatus = "Depositing " .. targetDef.color .. " crystals"

        local targetCrate = nil
        for _, c in ipairs(crates) do
            if c.color == targetDef.color then
                if not targetCrate or c.isEmpowered then
                    targetCrate = c
                end
            end
        end

        if targetCrate and targetCrate.rawObj then
            sleep(math.random(100, 250), 30)
            if not API.DoAction_Object_Direct(0xb5, API.OFF_ACT_GeneralObject_route0, targetCrate.rawObj) then
                pcall(function() Interact:Object(targetCrate.name, "Deposit", WPOINT.new(targetCrate.tile.x, targetCrate.tile.y, targetCrate.tile.z), 30) end)
            end
            Stats.actionsCount = Stats.actionsCount + 1

            local depositTimeout = 0
            while API.Read_LoopyLoop() and depositTimeout < 30 do
                sleep(250, 30)
                local currentList = getAllTransmutedCrystalsInInventory()
                local stillHasColor = false
                for _, def in ipairs(currentList) do
                    if def.color == targetDef.color then stillHasColor = true; break end
                end
                if not stillHasColor then break end
                depositTimeout = depositTimeout + 1
            end
            API.RandomSleep2(600, 1000, 1500)
            return
        end
    end

    if not isFull and rawCount == 0 and #coloredList == 0 then
        currentStatus = "Withdrawing Raw Crystals"
        if binObj then
            sleep(math.random(100, 250), 30)
            if not API.DoAction_Object_Direct(0xb5, API.OFF_ACT_GeneralObject_route0, binObj) then
                pcall(function() Interact:Object(binObj.Name or "Crystal storage bin", "Withdraw", WPOINT.new(binObj.TileX, binObj.TileY, binObj.TileZ), 30) end)
            end
            Stats.actionsCount = Stats.actionsCount + 1

            local withdrawTimeout = 0
            while API.Read_LoopyLoop() and withdrawTimeout < 30 do
                sleep(250, 30)
                if getInventoryCrystalCount() > 0 or Inventory:IsFull() then break end
                withdrawTimeout = withdrawTimeout + 1
            end
            API.RandomSleep2(600, 1000, 1500)
            return
        else
            currentStatus = "Locating Storage Bin..."
            sleep(1000, 100)
            return
        end
    end

    if rawCount > 0 then
        local targetCDef = empoweredCrate and empoweredCrate.def or CRATE_DEFS.Green
        currentStatus = "Transmuting " .. targetCDef.color

        if not API.GetInterfaceOpenBySize(1371) then
            sleep(math.random(100, 250), 30)
            API.DoAction_Inventory3("Senntisten crystal", 0, 1, API.OFF_ACT_GeneralInterface_route)

            local openTimeout = 0
            while API.Read_LoopyLoop() and openTimeout < 15 do
                sleep(200, 30)
                if API.GetInterfaceOpenBySize(1371) then break end
                openTimeout = openTimeout + 1
            end
        end

        if API.GetInterfaceOpenBySize(1371) then
            local vbData = API.VB_FindPSett(1170)
            local curVb = vbData and vbData.state or 0

            if curVb ~= targetCDef.vb then
                API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1371, 22, targetCDef.comp, API.OFF_ACT_GeneralInterface_route)
                local changeTimeout = 0
                while API.Read_LoopyLoop() and changeTimeout < 15 do
                    sleep(100, 20)
                    local checkVb = API.VB_FindPSett(1170)
                    if checkVb and checkVb.state == targetCDef.vb then break end
                    changeTimeout = changeTimeout + 1
                end
                API.RandomSleep2(350, 600, 900)
            else
                API.RandomSleep2(250, 450, 700)
            end

            currentCraftingColor = targetCDef.color
            API.KeyboardPress31(32, 0, 0)
            API.RandomSleep2(1000, 1500, 2500)
            return
        end
    end

    sleep(Config.actionDelayMs, 100)
end

local selectedSkill = nil

local function setupImGui()
    DrawImGui(function()
        if not isRunning then return end

        ImGui.SetNextWindowSize(390, 480, ImGuiCond.FirstUseEver)
        local visible = ImGui.Begin(SCRIPT_NAME .. "##AIO_ETR_UI")
        if visible then
            ImGui.TextColored(0.4, 0.8, 1.0, 1.0, SCRIPT_NAME .. " v" .. SCRIPT_VERSION .. " | " .. AUTHOR)
            ImGui.Separator()

            if selectedSkill == nil then
                ImGui.Text("Choose training activity to begin:")
                ImGui.Spacing()

                if ImGui.Button("Train Agility (Auto-cycles)", 340, 40) then
                    Config.activityMode = 0
                    selectedSkill = 0
                    Stats.startTime = os.time()
                    Stats.startXP = 0
                    Stats.sessionGainedXP = 0
                    loadTrackerFile()
                    updateStats()
                end

                ImGui.Spacing()
                if ImGui.Button("Train Divination (Crystals)", 340, 40) then
                    Config.activityMode = 1
                    selectedSkill = 1
                    Stats.startTime = os.time()
                    Stats.startXP = 0
                    Stats.sessionGainedXP = 0
                    loadTrackerFile()
                    updateStats()
                end
            else
                local skillName = Config.activityMode == 0 and "Agility" or "Divination"
                ImGui.Text("Activity: " .. skillName)
                ImGui.SameLine()
                if ImGui.Button("Switch Skill", 100, 20) then
                    isPaused = true
                    selectedSkill = nil
                    currentCraftingColor = nil
                    currentStatus = "Paused"
                end

                local r, g, b = 0.7, 0.7, 0.7
                if string.find(currentStatus, "Empowered") or string.find(currentStatus, "10x") then r, g, b = 0.2, 1.0, 0.4
                elseif string.find(currentStatus, "Normal") or string.find(currentStatus, "Transmuting") then r, g, b = 1.0, 0.85, 0.2
                elseif string.find(currentStatus, "Switching") or string.find(currentStatus, "Moving") or string.find(currentStatus, "Withdrawing") or string.find(currentStatus, "Depositing") or string.find(currentStatus, "Walking") then r, g, b = 0.2, 0.8, 1.0
                elseif string.find(currentStatus, "Cap Reached") then r, g, b = 0.9, 0.4, 1.0
                elseif currentStatus == "Paused" then r, g, b = 1.0, 0.3, 0.3 end

                ImGui.Text("Status: ")
                ImGui.SameLine()
                ImGui.TextColored(r, g, b, 1.0, currentStatus)
                ImGui.Separator()

                if Config.activityMode == 0 then
                    if ImGui.CollapsingHeader("800k Cap Progress", ImGuiTreeNodeFlags.DefaultOpen) then
                        ImGui.Text("Lifetime Agility XP: " .. formatNumber(Stats.totalTrackedXP) .. " / " .. formatNumber(Config.customCapAmount))
                        ImGui.Text("Remaining to Cap: " .. formatNumber(Stats.remainingCapXP) .. " XP")

                        local capFraction = math.min(1.0, Stats.totalTrackedXP / math.max(1, Config.customCapAmount))
                        ImGui.ProgressBar(capFraction, 0, 0, string.format("%.2f%% of 800k Cap", capFraction * 100))
                    end
                end

                if ImGui.CollapsingHeader("Session Statistics", ImGuiTreeNodeFlags.DefaultOpen) then
                    local elapsedSec = os.difftime(os.time(), Stats.startTime)
                    ImGui.Text("Session Runtime: " .. formatTime(elapsedSec))
                    ImGui.Text("Current Level: " .. Stats.currentLevel .. " (+" .. (Stats.currentLevel - Stats.startLevel) .. ")")
                    ImGui.Text("Session XP Gained: " .. formatNumber(Stats.sessionGainedXP))
                    ImGui.Text("XP / Hour: " .. formatNumber(Stats.xpPerHour))
                    ImGui.Text("Empowered Swaps: " .. Stats.empoweredSwaps)
                end

                if ImGui.CollapsingHeader("Settings", ImGuiTreeNodeFlags.None) then
                    local changed, val
                    changed, val = ImGui.Checkbox("Prioritize Empowered (10x XP)", Config.prioritizeEmpowered)
                    if changed then Config.prioritizeEmpowered = val; saveTrackerFile() end

                    if Config.activityMode == 0 then
                        changed, val = ImGui.Checkbox("Auto-stop at 800k Cap", Config.stopAtCap)
                        if changed then Config.stopAtCap = val; saveTrackerFile() end

                        changed, val = ImGui.Checkbox("Recharge Silverhawk Boots", Config.rechargeSilverhawks)
                        if changed then Config.rechargeSilverhawks = val; saveTrackerFile() end
                    end

                    ImGui.Separator()
                    changed, val = ImGui.SliderInt("Min Reaction (ms)", Config.minReactionDelayMs, 100, 1500)
                    if changed then Config.minReactionDelayMs = val; saveTrackerFile() end

                    changed, val = ImGui.SliderInt("Max Reaction (ms)", Config.maxReactionDelayMs, 200, 3000)
                    if changed then Config.maxReactionDelayMs = math.max(Config.minReactionDelayMs, val); saveTrackerFile() end

                    if Config.activityMode == 0 then
                        ImGui.Separator()
                        if ImGui.Button("Reset Agility 800k Progress", 220, 24) then
                            Stats.priorLifetimeXP = 0
                            Stats.totalTrackedXP = Stats.sessionGainedXP
                            Stats.remainingCapXP = math.max(0, Config.customCapAmount - Stats.totalTrackedXP)
                            saveTrackerFile()
                        end
                    end
                end

                ImGui.Separator()

                if isPaused then
                    if ImGui.Button("Start", 100, 26) then
                        isPaused = false
                        currentStatus = "Running"
                        Stats.startTime = os.time()
                        updateStats()
                    end
                else
                    if ImGui.Button("Pause", 100, 26) then
                        isPaused = true
                        currentStatus = "Paused"
                    end
                end

                ImGui.SameLine()
                if ImGui.Button("Reset Session", 110, 26) then
                    Stats.startTime = os.time()
                    Stats.startXP = API.GetSkillXP(getSkillName())
                    Stats.startLevel = API.GetSkillsTableSkill(getSkillId())
                    Stats.sessionGainedXP = 0
                    Stats.xpPerHour = 0
                    Stats.empoweredSwaps = 0
                    Stats.actionsCount = 0
                    currentCraftingColor = nil
                end

                ImGui.SameLine()
                if ImGui.Button("Stop Script", 100, 26) then
                    API.Write_LoopyLoop(false)
                end
            end
        end

        ImGui.End()
    end)
end

API.SetMaxIdleTime(5)
API.SetDrawTrackedSkills(true)
loadTrackerFile()
updateStats()
setupImGui()

local function mainLoopStep()
    if selectedSkill == nil or isPaused then
        currentStatus = "Paused"
        sleep(200, 20)
        return
    end

    if Config.activityMode == 0 and Config.stopAtCap and Stats.totalTrackedXP >= Config.customCapAmount then
        currentStatus = "800k Cap Reached"
        API.Play_sound(100, "C:\\Windows\\Media\\chimes.wav")
        saveTrackerFile()
        API.Write_LoopyLoop(false)
        return
    end

    if not API.PlayerLoggedIn() then
        sleep(1000, 200)
        return
    end

    if Config.activityMode == 0 then
        stepAgility()
    else
        stepDivination()
    end
end

while API.Read_LoopyLoop() do
    API.SetMaxIdleTime(5)
    API.DoRandomEvents()
    updateStats()
    mainLoopStep()
    collectgarbage("collect")
end

saveTrackerFile()
ClearRender()
API.ClearMarkTiles()

API.DrawTable({
    { SCRIPT_NAME .. " - " .. AUTHOR },
    { " " },
    { "Mode: " .. (Config.activityMode == 0 and "Agility" or "Divination") },
    { "Runtime: " .. formatTime(os.difftime(os.time(), Stats.startTime)) },
    { "Session XP: " .. formatNumber(Stats.sessionGainedXP) },
    { "Lifetime XP: " .. formatNumber(Stats.totalTrackedXP) .. " / " .. formatNumber(Config.customCapAmount) },
    { "XP / Hour: " .. formatNumber(Stats.xpPerHour) },
    { "Empowered Swaps: " .. Stats.empoweredSwaps }
})
