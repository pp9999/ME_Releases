local API = require("api")
API.SetMaxIdleTime(9)

local pouchIDs = {
    GraniteLobster = 12069,
}

local POTIONS = { 35735, 35737, 35739, 35741 } -- juju fishing
local restorePot = {3024, 3026, 3028, 3030}
local torstolID = 47715

local quartermasterGully = 22940
local AREA = {
    portSarim = { x = 3052, y = 3246, z = 0},
    wars = { x = 3294, y = 10127, z = 0 },
}

-- variables
local wobbegongsBanked = 0
local islandAmount = 0

--Ty Higgin's Safecracking
local function isAtLocation(location, distance)
    local distance = distance or 20
    return API.PInArea(location.x, distance, location.y, distance, location.z)
end

local function getChimeCount()
    return API.VB_FindPSett(6528).state
end

local mimicikingCount = 0
local unstableCount = 0
local lostCount = 0
local vengefulCount = 0
--TY SPADE
local function handleElidinisEvents()
    local lostSoul = 17720
    local unstableSoul = 17739
    local mimickingSoul = 18222
    local vengefulSoul = 17802
    local eventIDs = { lostSoul, unstableSoul, mimickingSoul, vengefulSoul }

    local found = false
    local eventObjs = API.GetAllObjArray1(eventIDs, 50, { 1 })
    if #eventObjs > 0 then
        print("Elidinis soul detected!")
        if eventObjs[1].Id == mimickingSoul then
            mimicikingCount = mimicikingCount + 1
        elseif eventObjs[1].Id == unstableSoul then
            unstableCount = unstableCount + 1 
        elseif eventObjs[1].Id == lostSoul then
            lostCount = lostCount + 1 
        elseif eventObjs[1].Id == vengefulSoul then
            vengefulCount = vengefulCount + 1 
        end
        found = true
    end

    local originTile = API.PlayerCoordfloat()
    while #eventObjs > 0 and API.Read_LoopyLoop() do
        if eventObjs[1].Id == mimickingSoul then
           -- API.DoAction_Dive_Tile(eventObjs[1].Tile_XYZ) 
            API.DoAction_TileF(eventObjs[1].Tile_XYZ)
        elseif eventObjs[1].Id == unstableSoul or eventObjs[1].Id == lostSoul then
            -- API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { eventObjs[1].Id }, 50)
            API.DoAction_NPC__Direct(0x29, API.OFF_ACT_InteractNPC_route, eventObjs[1])
        end

        API.RandomSleep2(1000, 250, 500)
        eventObjs = API.GetAllObjArray1(eventIDs, 50, { 1 })
    end

    if found then API.DoAction_TileF(originTile) end
end

local function findThing(ID, range, type)
    local objList = {ID}
    local checkRange = range
    local objectTypes = {type}
    local foundObjects = API.GetAllObjArray1(objList, checkRange, objectTypes)
    if foundObjects then
        for _, obj in ipairs(foundObjects) do
            if obj.Id == ID then
                return true
            end
        end
    end
    return false
end

local function summonFamiliar()
    if not Familiars:HasFamiliar() and Inventory:Contains(pouchIDs.GraniteLobster) and Inventory:ContainsAny(restorePot) then
        API.DoAction_Ability(("Super restore potion"), 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200,1800,1800)
        Inventory:DoAction(pouchIDs.GraniteLobster, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600,800,1200)
    end

end

local function takeFishingPot()
    if API.Buffbar_GetIDstatus(35739).conv_text > 1 then
        return
    end

    for _, pot in ipairs(POTIONS) do
        if API.InvItemcount_1(pot) > 0 then
            print("Drinking potion!")
            API.DoAction_Inventory1(pot, 0, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(800,1800,2400)
            break
        end
    end
end

local function applyBoosts()
    local torstol = API.Buffbar_GetIDstatus(torstolID, false)
    if not torstol.found and API.InvStackSize(torstolID) >= 10 then
        API.DoAction_Inventory1(torstolID, 0, 2, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 500, 500)
    elseif torstol.found and torstol.conv_text > 0 and torstol.conv_text < 3 and API.InvStackSize(torstolID) >= 1 then
        API.DoAction_Inventory1(torstolID, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 500, 500)
    end
    takeFishingPot()
end

local ArcJournalTeleporInterface = {
    InterfaceComp5.new( 720,2,-1,0 ),
    InterfaceComp5.new( 720,16,-1,0 ),
    InterfaceComp5.new( 720,4,-1,0 ),
    InterfaceComp5.new( 720,0,-1,0 )
}

local function isArcJournalTeleporInterfacePresent()
    local result = API.ScanForInterfaceTest2Get(true, ArcJournalTeleporInterface)
    if #result > 0 then
        return true
    else return false end
end

local function checkArcInterface()
    if API.Compare2874Status(18, false) then
        return true
    else
        return false
    end
end

local Suppliesinterface = {
    InterfaceComp5.new( 1776,29,-1,0),
    InterfaceComp5.new( 1776,22,-1,0 ),
    InterfaceComp5.new( 1776,23,-1,0),
    InterfaceComp5.new( 1776,76,-1,0),
    InterfaceComp5.new( 1776,28,-1,0),
}

local function checkSupplies()
    local valueInterface = API.ScanForInterfaceTest2Get(false, Suppliesinterface)
    local suppliesNumber = tonumber(string.match(valueInterface[1].textids, "%d+"))
    return suppliesNumber
end

local Rowboat = 104020
local function findBoat()
    if findThing(Rowboat, 100, 0) then
        print("found the boat")
        return true
    else
        return false
    end
end

local function getObjFFPoint(Objects,  type)
    local objList = Objects
    local checkRange = 100
    local objectTypes = {type}
    local foundObjects = API.GetAllObjArray1(objList, checkRange, objectTypes)
    if foundObjects then
        for _, obj in ipairs(foundObjects) do
                return obj.Tile_XYZ
        end
    end
end

local function travelToNewIsland()
    if checkArcInterface() then
        if checkSupplies() >= 5 then
            -- API.DoAction_Interface(0xffffffff,0xffffffff,1,1776,40,-1,API.OFF_ACT_GeneralInterface_route) -- big island
            API.DoAction_Interface(0xffffffff,0xffffffff,1,1776,42,-1,API.OFF_ACT_GeneralInterface_route) -- small island
            API.RandomSleep2(6000,400,1200) 
            islandAmount = islandAmount + 1
        else
            print("Ran out of supplies. Stopping script.")
            API.Write_LoopyLoop(false)
        end
    elseif findBoat() then
        local boatLocation = getObjFFPoint({Rowboat}, 0)
        if API.Dist_FLP(boatLocation) > 25 then
            print("Walk towards boat")
            API.DoAction_WalkerF1(boatLocation,100)
            API.RandomSleep2(1200,1200,1200) 
            API.WaitUntilMovingEnds(20,4)
        else
            API.DoAction_Object1(0x39,API.GeneralObject_route_useon,{ Rowboat },50) 
            print("Wait until moving ends towards rowboat")
            API.RandomSleep2(1200,1200,1200) 
            API.WaitUntilMovingEnds(20,4)
        end
    elseif not isAtLocation(AREA.portSarim, 10) then
        print("not in port sarim")
        if Inventory:Contains(37729) then -- Arc Journal
            if isArcJournalTeleporInterfacePresent() then
                API.KeyboardPress2(0x31, 60, 100)
                API.RandomSleep2(5000,1000,1200) 
            else
                API.DoAction_Inventory1(37729,0,3,API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(600,400,1200) 
            end
        end
    else
            API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{ quartermasterGully },50)
            API.RandomSleep2(600,400,1200) 
            API.WaitUntilMovingEnds(10,2)
    end
end

local supplies = 104643
local treasureChest = 104021
local treasureChest2 = 104022
local treasureChest3 = 104023
local function isThereAChest()
    if findThing(supplies, 100, 0) then
        return true
   elseif findThing(treasureChest, 100, 0) then
        return true
   elseif findThing(treasureChest2, 100, 0) then
        return true
   elseif findThing(treasureChest3, 100, 0) then
        return true
   else
        return false  
   end
end

local chestAmount = 0
local function islandStuff()
    local chestLocation = getObjFFPoint({supplies, treasureChest, treasureChest2, treasureChest3}, 0)
    if API.Dist_FLP(chestLocation) > 25 then
        print("Walk near chest")
        API.DoAction_WalkerF1(chestLocation,100)
        API.RandomSleep2(1200,1200,1200) 
        API.WaitUntilMovingEnds(20,4)
    else
        API.DoAction_Object1(0x2d,API.OFF_ACT_GeneralObject_route0,{ supplies, treasureChest, treasureChest2, treasureChest3 },50)
        API.WaitUntilMovingEnds(20,4)
        chestAmount = chestAmount + 1 
    end
end

local WobbegongSpot = 23136
local function findFishingSpot()
    if findThing(WobbegongSpot, 100, 1) then
        return true
    else
        return false
    end
end

local function doFishing()
    local fishLocation = getObjFFPoint({WobbegongSpot}, 1)
    if API.Dist_FLP(fishLocation) > 25 then
        print("Walk towards boat")
        API.DoAction_WalkerF1(fishLocation,100)
        API.RandomSleep2(1200,1200,1200) 
        API.WaitUntilMovingEnds(20,4)
    elseif not API.CheckAnim(20) then
        if API.DoAction_NPC(0x3c,API.OFF_ACT_InteractNPC_route,{ WobbegongSpot },50) then
            print("Clicked fishing spot")
            API.RandomSleep2(1200,1200,1200) 
            API.WaitUntilMovingandAnimEnds(10,3)
        end
    end
end

local function depositFish()
    if findBoat() then
        local boatLocation = getObjFFPoint({Rowboat}, 0)
        if API.Dist_FLP(boatLocation) > 25 then
            print("Walk towards boat")
            API.DoAction_WalkerF1(boatLocation,100)
            API.RandomSleep2(1200,1200,1200) 
            API.WaitUntilMovingEnds(20,4)
        else
            print("Load last prest on the rowboat")
            local currentWobbegongAmount = Inventory:GetItemAmount(37768)
            wobbegongsBanked = wobbegongsBanked + currentWobbegongAmount
            API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route3,{ Rowboat },50) -- load last preset
            API.RandomSleep2(1200,1200,1200) 
            API.WaitUntilMovingEnds(20,4)
        end
    end
end

local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

API.SetDrawTrackedSkills(true)
while (API.Read_LoopyLoop()) do
    local metrics = {
        {"Wobbegongs banked:", formatNumber(wobbegongsBanked)},
        {"Islands visited:", formatNumber(islandAmount)},
        {"Chests found:", formatNumber(chestAmount)},
        {"Mimickng souls:", formatNumber(mimicikingCount)},
        {"Unstable Souls:",formatNumber(unstableCount)},
        {"Lost Souls:",formatNumber(lostCount)},
        {"Vengeful souls:",formatNumber(vengefulCount)},
        }
    API.DrawTable(metrics)
    API.DoRandomEvents()
    handleElidinisEvents()
    applyBoosts()
    summonFamiliar()
    if Inventory:IsFull() then
        depositFish()
    elseif isThereAChest() then
        print("There is a chest!")
        islandStuff()
    elseif findFishingSpot() then
        doFishing()
    else 
        travelToNewIsland()
    end
    API.RandomSleep2(600,400,400) 
end
