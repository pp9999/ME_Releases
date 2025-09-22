local API = require('api')

local startTime, lastXpTime, afk = os.time(), os.time(), os.time()
local MAX_IDLE_TIME_MINUTES = 5

local IDS = {
    DRAINED_PAULINE_POLARIS = 13621,
    LUNAR_LUMBER = 20702,
    LUNAR_FENCEPOST = 20703,
    LOG_PILE = 40444,
    BROKEN_FENCE = 40431,
    PRODUCE_PILE = 40438,
    LIVID_PLANT = 20704,
    LIVID_PLANT_BUNCH = 20705,
    TRADE_WAGON = 40443,
    NATURE_RUNE = 561,
    ASTRAL_RUNE = 9075,
    ELEMENTAL_BATTLESTAFF = 41885,
    MUD_BATTLESTAFF = 6562,
} 

local function checkRunes()
    if API.InvStackSize(IDS.NATURE_RUNE) < 100 or API.InvStackSize(IDS.ASTRAL_RUNE) < 100 or not API.Read_LoopyLoop() or not API.PlayerLoggedIn() or API.GetAllObjArray1({IDS.LOG_PILE}, 30, {12})[1] == nil then
        return false
    else
        return true
    end
end

local function dive(destinationTile)
    local abilityAB = API.GetABs_name1("Dive")
    if abilityAB.id == 0 or not abilityAB.enabled then return end
    math.randomseed(os.time())
    if abilityAB ~= nil and abilityAB.cooldown_timer == 0 then
        local random = math.random(-1,1)
        local randomizedDest = WPOINT.new(destinationTile.x + random, destinationTile.y + random, destinationTile.z)
        API.DoAction_Dive_Tile(randomizedDest)
        API.RandomSleep2(600, 600, 600)
    end
end

local function fertiliseEmptyPatches()
    if not checkRunes() then return end
    while API.Read_LoopyLoop() and API.GetAllObjArrayInteract_str({"Empty patch"}, 30, {0})[1] ~= nil do
        print("Fertilizing patch")
        API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ 40446 },50)
        API.RandomSleep2(1000, 600, 600)
    end
    API.RandomSleep2(600, 600, 600)
end

local function moveNearPlants()
    if not checkRunes() then return end
    if not API.PInArea21(2098, 2109, 3942, 3950) then
        math.randomseed(os.time())
        local random = math.random(-2, 2)
        API.DoAction_Tile(WPOINT.new(2103 + random,3946 + random,0))
        while API.Read_LoopyLoop() and not API.PInArea21(2098, 2109, 3942, 3950) do
            API.RandomSleep2(600, 100, 200)
        end
    end
end

local function curePlants()
    if not checkRunes() then return end
    local diseasedLivids = API.GetAllObjArrayInteract_str({"Diseased livid"}, 30, {0})
    if #diseasedLivids > 0 then
        moveNearPlants()
        for i = 1, #diseasedLivids, 1 do
            print("Cuting plant #" .. i)
            while API.Read_LoopyLoop() and API.GetAllObjArray1({diseasedLivids[i].Id}, 30, {0})[1] ~= nil do
                API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ diseasedLivids[i].Id },50)
                API.RandomSleep2(800, 600, 600)
                if diseasedLivids[i].Id == 40452 then
                    API.DoAction_Interface(0xffffffff,0xffffffff,1,1081,0,-1,API.OFF_ACT_GeneralInterface_route)
                elseif diseasedLivids[i].Id == 40453 then
                    API.DoAction_Interface(0xffffffff,0xffffffff,1,1081,3,-1,API.OFF_ACT_GeneralInterface_route)
                elseif diseasedLivids[i].Id == 40454 then
                    API.DoAction_Interface(0xffffffff,0xffffffff,1,1081,6,-1,API.OFF_ACT_GeneralInterface_route)
                elseif diseasedLivids[i].Id == 40455 then
                    API.DoAction_Interface(0xffffffff,0xffffffff,1,1081,9,-1,API.OFF_ACT_GeneralInterface_route)
                end
                API.RandomSleep2(600, 600, 600)
            end
        end
    end
end

local function convertLogs()
    if not checkRunes() then return end
    if not API.InventoryInterfaceCheckvarbit() then
        print("Open inventory")
        API.RandomSleep2(100, 100, 100)
        API.DoAction_Interface(0xc2,0xffffffff,1,1431,0,9,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 0, 1200)
    end 
    API.RandomSleep2(100, 50, 100)
    API.DoAction_Inventory1(20702,0,1,API.OFF_ACT_GeneralInterface_route)
    print("Converting logpile to fence")
    API.RandomSleep2(200, 100, 100)
end

local function getFenceLogs()
    if not checkRunes() then return end
    if API.InvStackSize(IDS.LUNAR_FENCEPOST) >= 1 then
        return 
    elseif API.InvStackSize(IDS.LUNAR_LUMBER) >= 1 then
        convertLogs()
    else
        if API.GetAllObjArray1({IDS.LOG_PILE}, 30, {12})[1].Distance >= 8 then
            dive(WPOINT.new(2113,3949,0))
        end
        API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route1,{ IDS.LOG_PILE },50)
        while API.Read_LoopyLoop() and API.InvStackSize(IDS.LUNAR_LUMBER) < 2 do
            API.RandomSleep2(600, 600, 600)
            if not API.InventoryInterfaceCheckvarbit() then
                print("Open inventory")
                API.RandomSleep2(100, 100, 100)
                API.DoAction_Interface(0xc2,0xffffffff,1,1431,0,9,API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(600, 0, 1200)
            end 
        end
        print("Took 5 log piles")
        convertLogs()
    end
end

local function fixFences()
    if not checkRunes() then return end
    local brokenFences = API.GetAllObjArrayInteract_str({"Broken fence"}, 30, {0})
    if #brokenFences > 0 then
        for i = 1, #brokenFences do
            getFenceLogs()
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ IDS.BROKEN_FENCE },50)
            local counter = 0
            local bFences = API.GetAllObjArrayInteract_str({"Broken fence"}, 30, {0})
            while API.Read_LoopyLoop() and (#bFences == #API.GetAllObjArrayInteract_str({"Broken fence"}, 30, {0})) do
                API.RandomSleep2(600, 100, 200)
                if (counter >= 10) then
                    break
                end
                counter = counter + 1
            end
            API.RandomSleep2(100, 100, 100)
            print("Fence fixed")
        end
    end
end

local function produce()
    if not checkRunes() then return end
    local produce = API.GetAllObjArrayInteract_str({"Produce pile (full)"}, 30, {0})
    if #produce > 0 and API.InvStackSize(IDS.LIVID_PLANT) < 10 then
        API.RandomSleep2(100, 100, 100)
        API.DoAction_Object1(0x2d,API.OFF_ACT_GeneralObject_route0,{ IDS.PRODUCE_PILE },50)
        while API.Read_LoopyLoop() and API.InvStackSize(IDS.LIVID_PLANT) < 10 do
            API.RandomSleep2(600, 600, 600)
            if not API.InventoryInterfaceCheckvarbit() then
                print("Open inventory")
                API.RandomSleep2(100, 100, 100)
                API.DoAction_Interface(0xc2,0xffffffff,1,1431,0,9,API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(600, 0, 1200)
            end 
        end
        API.RandomSleep2(100, 100, 100)
    end  

    if API.InvStackSize(IDS.LIVID_PLANT) > 0 then
        if not API.InventoryInterfaceCheckvarbit() then
            print("Open inventory")
            API.RandomSleep2(100, 100, 100)
            API.DoAction_Interface(0xc2,0xffffffff,1,1431,0,9,API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(600, 0, 1200)
        end 
        API.DoAction_Inventory1(20704,0,1,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(200, 100, 100)
        API.DoAction_Inventory1(20704,0,1,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 600, 600)
        API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ IDS.TRADE_WAGON },50)
        while API.Read_LoopyLoop() and API.InvStackSize(IDS.LIVID_PLANT_BUNCH) > 0 do
            API.RandomSleep2(600, 600, 600)
        end
        print("Livid bunch traded")
    end
end

local function encouragePauline()
    if not checkRunes() then return end
    local pauline = API.GetAllObjArrayInteract_str({"Drained Pauline Polaris"}, 30, {1})
    if #pauline > 0 then
        API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route3,{ IDS.DRAINED_PAULINE_POLARIS },50)
        local counter = 0
        while API.Read_LoopyLoop() and not API.Compare2874Status(12, false) do
            API.RandomSleep2(600, 600, 600)
            if not API.Compare2874Status(12, false) then
                API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route3,{ IDS.DRAINED_PAULINE_POLARIS },50)
            end
            if (counter >= 5) then
                return
            end
            counter = counter + 1
        end
        API.RandomSleep2(100, 100, 100)
        if tonumber(API.Dialog_Option("Come on, you're doing so well.")) then
            API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,8,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        elseif tonumber(API.Dialog_Option("Keep going! We can do this.")) then
            API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,13,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        elseif tonumber(API.Dialog_Option("Look at all the produce being made.")) then
            API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,18,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        elseif tonumber(API.Dialog_Option("Lokar will really appreciate this.")) then
            API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,13,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        elseif tonumber(API.Dialog_Option("You're doing a fantastic job.")) then
            API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,18,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        elseif tonumber(API.Dialog_Option("Extraordinary!")) then
            API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,23,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        end
        API.RandomSleep2(800, 600, 600)
        print("Pauline encouraged")
    end
end

local function idleCheck()
    if not checkRunes() then return end
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end



while API.Read_LoopyLoop() and API.PlayerLoggedIn() do

    if not checkRunes() then
        API.Write_LoopyLoop(false)
        break
    end
    
    fertiliseEmptyPatches()
    curePlants()
    encouragePauline()
    fixFences()
    produce()

    idleCheck()
    API.DoRandomEvents()
    API.RandomSleep2(100, 100, 100)

end