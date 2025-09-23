local API = require("api")
local startTime = os.time()
local idleTimeThreshold = math.random(120, 260)

local function antiIdleTask()
    local currentTime = os.time()
    local elapsedTime = os.difftime(currentTime, startTime)
    if elapsedTime >= idleTimeThreshold then
        API.PIdle2()
        -- Reset the timer and generate a new random idle time
        startTime = os.time()
        idleTimeThreshold = math.random(120, 260)
        print("Reset Timer & Threshold")
    end
end


local SELECTEDRUNETOMAKE = "miasma" -- spirit // bone // flesh // miasma


-- Item/Object/NPC IDs
local impureEss = 55667
local darkPortal = 127376
local spiritAltar = 127380
local boneAltar = 127381
local fleshAltar = 127382
local miasmaAltar = 127383
local bankChest = 127271
local powerburstIds = { 49069, 49067, 49065, 49063 }


local function teleportHauntHill()
    print("Teleport to Haunt on the Hill")
    API.DoAction_Interface(0xffffffff,0xdc60,7,1430,64,-1,4608)
    API.RandomSleep2(700,600,600)
    API.DoAction_Interface(0xffffffff,0xffffffff,0,720,20,-1,2912)
    API.RandomSleep2(1000,900,900)
    API.WaitUntilMovingEnds()
end

local function interactDarkPortal()
    print("Interact with Dark Portal")
    API.DoAction_Object_r(0x39, 0, { darkPortal }, 50, WPOINT.new(1163, 1819, 0), 5)
    API.RandomSleep2(1200,900,900)
end

local function surgeToAltar(runeName)
    print("Surge")
    local altarPositions = {
        spirit = WPOINT.new(1313,1969,0),
        bone = WPOINT.new(1296,1962,0),
        flesh = WPOINT.new(1315,1934,0),
        miasma = WPOINT.new(1325,1950,0)
    }
    
    local altar = altarPositions[runeName]
    if not altar then
        error("Invalid rune name")
    end

    API.DoAction_Surge_Tile(altar, 5)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(600, 600, 600)
end

local function craftRunes(runeName)
    print("Crafting Runes")
    local altarIDs = {
        spirit = spiritAltar,
        bone = boneAltar,
        flesh = fleshAltar,
        miasma = miasmaAltar
    }

    local altarID = altarIDs[runeName]
    if not altarID then
        error("Invalid rune name")
    end

    local altarPositions = {
        spirit = WPOINT.new(1313, 1969, 0),
        bone = WPOINT.new(1296, 1962, 0),
        flesh = WPOINT.new(1315, 1934, 0),
        miasma = WPOINT.new(1325, 1950, 0)
    }

    local altarPosition = altarPositions[runeName]
    if not altarPosition then
        error("Invalid rune name")
    end

    API.DoAction_Object_r(0x29, 0, { altarID }, 50, altarPosition, 5)
    API.RandomSleep2(600, 600, 600)
    API.WaitUntilMovingEnds()
end

local function bankTeleport()
    print("Teleport to bank area")
    API.DoAction_Interface(0x2e,0xd97c,1,1430,77,-1,3808)
    API.RandomSleep2(2000,1000,1000)
    API.WaitUntilMovingEnds()
end

local function loadLastPreset()
    print("Load Last Preset")
    API.DoAction_Object_r(0x33, 240, { bankChest }, 50, WPOINT.new(1150, 1804, 0), 5)
    API.RandomSleep2(1200,1200,1200)
    API.WaitUntilMovingEnds()
end

-- POWERBUST --

local function canUsePowerburst()
    local debuffs = API.DeBuffbar_GetAllIDs()
    local powerburstCoolldown = false
    for _, a in ipairs(debuffs) do
        if a.id == 48960 then
            powerburstCoolldown = true
        end
    end
    return not powerburstCoolldown
end

local function findPowerburst()
    local powerbursts = API.CheckInvStuff3(powerburstIds)
    local foundIdx = -1
    for i, value in ipairs(powerbursts) do
        if tostring(value) == '1' then
            foundIdx = i
            break
        end
    end
    if foundIdx ~= -1 then
        local foundId = powerburstIds[foundIdx]
        if foundId >= 49063 and foundId <= 49069 then
            return foundId
        else
            return nil
        end
    else
        return nil
    end
end

-- POWERBUST --
-- SUMMON --

local function TeleportWarRetreat() 
    if API.GetABs_name1("War's Retreat Teleport") ~= 0 and API.GetABs_name1("War's Retreat Teleport").enabled then
        API.logDebug("Info: Teleport to War's Retreat")
        API.logInfo("Teleport to War's Retreat.")
        API.DoAction_Ability_Direct(API.GetABs_name1("War's Retreat Teleport"), 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(2000,1000,2000)
        API.WaitUntilMovingEnds()
    end
end

local ID             = {
    POWERBURST = { 49069, 49067, 49065, 49063 },
    CRAFTING_ANIMATION = 23250,
    POUCHE = { 5509, 5510, 5512, 5514, 24205 },
    WAR_BANK = 114750,
    ESSENCE = {7936, 18178, 1436, 55667},
    ALTAR_OF_WAR = 114748,
}

local AREA           = {
    UM_SMITH = { x = 1149, y = 1803, z = 0 },
    HILL = { x = 1165, y = 1838, z = 0 },
    ALTARS = { x = 1315, y = 1952, z = 0 },
    WARETREAT= { x = 3294, y = 10127, z = 0 },
}

local function hasfamiliar()
    API.logDebug("Info: Check if has familliar!")
    return API.Buffbar_GetIDstatus(26095).id > 0
end

local function OpenInventoryIfNeeded()
    if not API.VB_FindPSett(3039).SumOfstate == 1 then
        API.DoAction_Interface(0xc2,0xffffffff,1,1432,5,1,API.OFF_ACT_GeneralInterface_route);
    end
end

local function renewSummoningPoints() 
    API.DoAction_Object1(0x3d,API.OFF_ACT_GeneralObject_route0,{ID.ALTAR_OF_WAR} ,50)
    API.RandomSleep2(600,0,0)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(1200,0,0)
end

local function checkForVanishesMessage()
    local chatTexts = ChatGetMessages()
    if chatTexts then
        for k, v in pairs(chatTexts) do
            if k > 2 then break end
            if string.find(v.text, "<col=EB2F2F>You have 1 minute before your familiar vanishes.") then
                API.logDebug("Info: 1 minute left!")
                API.logInfo("Familiar has 1 minute left!")
                return true
            end  
            if string.find(v.text, "<col=EB2F2F>You have 30 seconds before your familliar vanishes.") then
                API.logDebug("Info: 30 seconds left!")
                API.logInfo("Familiar has 30 seconds left!")
                return true
            end          
        end
    end
    return false
end

local fail              = 0
local selectedFamiliar = 12796

local function isAtLocation(location, distance)
    local distance = distance or 20
    return API.PInArea(location.x, distance, location.y, distance, location.z)
end

local function getFamiliarDuration()
    local value = API.VB_FindPSettinOrder(1786, 0).state
    if value == 0 then return 0 end
    return (math.floor(value / 2.1333333)) / 60
end

local function RenewFamiliar() 
    if fail > 3 then 
        API.logError("couldn't renew familiar.")
        API.Write_LoopyLoop(false)
        return
    end
    if isAtLocation(AREA.WARETREAT, 50) then 
        if API.GetSummoningPoints_() < 400 then
            API.logDebug("Info: Renew summoning points.")
            API.logInfo("Renewing summoning points.")
            renewSummoningPoints() 
        else
            API.RandomSleep2(600,100,300)
            API.logDebug("Doaction: Open bank.")
            API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, {ID.WAR_BANK}, 50)
            API.RandomSleep2(1000, 500, 1000)
            API.WaitUntilMovingEnds()
            if Inventory:FreeSpaces() < 2 then
                API.logDebug("Info: Summoning: make more room in your invt.")
                API.KeyboardPress2(0x33,0,50)
                API.RandomSleep2(1000, 500, 1000)
            else
                API.DoAction_Bank(selectedFamiliar, 1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(1000, 500, 1000)        
                API.KeyboardPress2(0x1B, 50, 150)
                API.RandomSleep2(1000, 500, 1000)
            end 
        end
        if Inventory:InvStackSize(selectedFamiliar) < 1 then
            API.logError("didn't find any pouches")
            fail = fail + 1
            return
        end    
        if API.DoAction_Inventory2({ selectedFamiliar }, 0, 1, API.OFF_ACT_GeneralInterface_route) then
            API.RandomSleep2(600,100,300)
            API.WaitUntilMovingEnds()
            OpenInventoryIfNeeded()
            API.RandomSleep2(600,100,300)
            bankTeleport()
        end    
        if API.CheckFamiliar() then 
            fail = 0
        end
    else 
        TeleportWarRetreat()
    end
end

local function familiar()
    if selectedFamiliar then
        API.logDebug("Info: Familliar check 01")
        if not hasfamiliar() or checkForVanishesMessage() then
            API.logDebug("Info: Familliar check 02")
            RenewFamiliar() 
        end
    end 
end

-- SUMMON --

-- Main loop
API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do
        API.DoRandomEvents()
    API.SetDrawTrackedSkills(true)
    API.ScriptRuntimeString()
    antiIdleTask()
    familiar()

    if selectedFamiliar then
        if checkForVanishesMessage() then
            RenewFamiliar() 
        end
    end

    if selectedFamiliar and isAtLocation(AREA.WARETREAT, 50) then
        API.logDebug("Waiting until a familiar is summond!")
    end
    
    if Inventory:IsFull() and isAtLocation(AREA.UM_SMITH, 50) then
        print("Teleporting to Hill")
        teleportHauntHill()
        API.RandomSleep2(1000, 300, 300)
    elseif not Inventory:IsFull() then
        loadLastPreset()
        API.RandomSleep2(900, 300, 120)
    end

    if Inventory:IsFull() and isAtLocation(AREA.HILL, 50) then
            print ("Go to portal")
            API.RandomSleep2(2000, 300, 300)
            interactDarkPortal()
            API.DoAction_Surge_Tile(WPOINT.new(1163,1819,0),5)
            API.RandomSleep2(600, 300, 300)
            interactDarkPortal()
            API.RandomSleep2(1400, 300, 300)
    end
        
    if Inventory:IsFull() and isAtLocation(AREA.ALTARS, 50) then
        print ("Making runes")
        surgeToAltar(SELECTEDRUNETOMAKE)
           if canUsePowerburst() and findPowerburst() then
             API.DoAction_Inventory2({ 49069, 49067, 49065, 49063 }, 0, 1, API.OFF_ACT_GeneralInterface_route)
           end
        API.RandomSleep2(600, 300, 300)
        craftRunes(SELECTEDRUNETOMAKE)
        API.RandomSleep2(1000, 300, 300)
        elseif hasfamiliar() then
            print ("Failed Runes get back to bank")
            bankTeleport()
            API.RandomSleep2(3000, 500, 500)
    end

    if Inventory:InvItemcount(impureEss) <= 1 and isAtLocation(AREA.ALTARS, 50) then
        print("Runes done, time to rebank")
        bankTeleport()
        API.RandomSleep2(3000, 500, 500)
    end

    if isAtLocation(AREA.UM_SMITH, 50) then
        loadLastPreset()
        API.RandomSleep2(900, 300, 120)
    end

    API.RandomSleep2(500, 300, 120)
end