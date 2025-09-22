local API = require("api")
print("Run Lua script GateOfEld.")

API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)

local CurrentTick = API.Get_tick()
local OBJECTS_table = API.ReadAllObjectsArray({-1},{-1},{})
local IchtlarinData = nil
local Bossdone = false
local WarsCenterTile = FFPOINT.new(3299,10131,0)
local CrossRoadCenterTile = FFPOINT.new(1010,9632,0)
local Throw_rocksdone = false
local GetMoonstonedone = false
local GetMoonstoneammount = 0
local Barrierhealth = 0
local Playerhealth = API.GetHPrecent()
local FP_global_cooldown = API.Get_tick()
local AvoidAOE_global_cooldown = API.Get_tick()
local KillAhk_global_cooldown = API.Get_tick()
local Mine_global_cooldown = API.Get_tick()
local Ahk = nil
local Transmuterocks = nil
local Minerocks = nil
local IchtlarinDataFFPOINT = nil
local Transmuterocks = nil
local SpecialButtonTimer = 0
local SpecialButtonEvent = false
local SpecialButtonEventsafe = false
local InventoryContainer = nil
local FirstPlatform = nil
local Aoe_3x3 = nil
local Aoe_7x7 = nil
local loopcheck_loot = 0
local loopcheck_wars = 0
local currentindex = 0
local WarsCenterTile = FFPOINT.new(3299,10131,0)
local CrossRoadCenterTile = FFPOINT.new(1010,9632,0)
local Findrightportal = nil
local function corruptionStacks()
    return API.VB_FindPSettinOrder(11834).state
    -- Id:11834 changed:16 To:17  10001000 00000000 00000000 00000000 : 0:0
end

CurrentArea = API.CreateIG_answer()
CurrentArea.box_name = "Area"
CurrentArea.box_start = FFPOINT.new(10,60,0)
CurrentArea.colour = ImColor.new(0,255,0)
CurrentArea.string_value = "Area:"
API.DrawTextAt(CurrentArea)

CurrentMove = API.CreateIG_answer()
CurrentMove.box_name = "CurrentMove"
CurrentMove.box_start = FFPOINT.new(10,80,0)
CurrentMove.colour = ImColor.new(0,255,0)
CurrentMove.string_value = "MOVE:"
API.DrawTextAt(CurrentMove)




--get all with that id
function GetObjectsFromTable(All_obj_table, Type, Id)
    local ALLtable = {}
    local Type2 = 9001
    if (Type == 0) then Type2 = 12 end
    if (Type == 12) then Type2 = 0 end
    if All_obj_table ~= nil then
        if #All_obj_table > 0 then
            for _, obj in pairs(All_obj_table) do
                if (obj.Type == Type or obj.Type == Type2) then 
                    if (obj.Id == Id) then 
                        ALLtable[#ALLtable+1] = obj
                    end
                end
            end
        end
    end
    if (#ALLtable > 0) then
        return ALLtable
    end
    return nil
end

--get single
function GetObjectFromTable(All_obj_table, Type, Id)
    local objects = GetObjectsFromTable(All_obj_table, Type, Id)
    if (objects ~= nil) then
        return objects[1]
    end
    return nil
end

--get single
function GetObjectFromTablenpc(All_obj_table, Type, Id)
    local objects = GetObjectsFromTable(All_obj_table, Type, Id)
    if (objects ~= nil) then
        for _, obj in pairs(objects) do
            if (obj.Life > 1) then
                return obj
            end
        end
    end
    return nil
end

--
function GetCoordsFromTable(All_obj_table, Type, Id)
    local table = {}
    local objects = GetObjectsFromTable(All_obj_table, Type, Id)
    if (objects ~= nil) then
        for _, obj in pairs(objects) do
            table[#table+1] = obj.Tile_XYZ
        end
    end
    if (#table > 0) then
        return table
    end
    return nil
end

--get all with that text
function GetObjectsFromTableString(All_obj_table, Type, Name)
    local ALLtable = {}
    local Type2 = 9001
    if (Type == 0) then Type2 = 12 end
    if (Type == 12) then Type2 = 0 end
    if All_obj_table ~= nil then
        if #All_obj_table > 0 then
            for _, obj in pairs(All_obj_table) do
                if (obj.Type == Type or obj.Type == Type2) then 
                    if (string.find(obj.Name,Name) ~= nil) then 
                        ALLtable[#ALLtable+1] = obj
                    end
                end
            end
        end
    end
    if (#ALLtable > 0) then
        return ALLtable
    end
    return nil
end

--get single
function GetObjectFromTableString(All_obj_table, Type, Name)
    local objects = GetObjectsFromTableString(All_obj_table, Type, Name)
    if (objects ~= nil) then
        return objects[1]
    end
    return nil
end

--get single
function GetObjectFromTableStringArea(All_obj_table, Type, Name, tileinfo, maxdistance, blocktype, blocktile)
    local objects = GetObjectsFromTableString(All_obj_table, Type, Name)
    if (objects ~= nil and tileinfo ~= nil) then
        for _, obj in pairs(objects) do
            if (blocktype == 0) then--ignore 
                if (API.Math_DistanceF(tileinfo,obj.Tile_XYZ) < maxdistance) then
                    return obj
                end
            end
            if (blocktype == 1) then--block this tile object
                if (API.Math_DistanceF(tileinfo,obj.Tile_XYZ) < maxdistance and blocktile.x ~= obj.Tile_XYZ.x and blocktile.y ~= obj.Tile_XYZ.y) then
                    return obj
                end
            end
            if (blocktype == 2) then--only this tile object
                if (API.Math_DistanceF(tileinfo,obj.Tile_XYZ) < maxdistance and blocktile.x == obj.Tile_XYZ.x and blocktile.y == obj.Tile_XYZ.y) then
                    return obj
                end
            end
        end
    end
    return nil
end

--get single
function GetObjectFromTableStringnpc(All_obj_table, Name)
    local objects = GetObjectsFromTableString(All_obj_table, 1, Name)
    if (objects ~= nil) then
        for _, obj in pairs(objects) do
            if (obj.Type == 1) then 
                if (obj.Life > 1) then
                    return obj
                end
            end
        end
    end
    return nil
end

function Report(text)
    print(text) 
    CurrentMove.string_value = text
end

--Ticks + Add random sleep
function SleepTickRandom(sleepticks)
    API.Sleep_tick(sleepticks)
    API.RandomSleep2(1, 120, 0)
end

--gets filled slots
function InvGAm(InventoryContainer)
    if (InventoryContainer ~= nil) then
        local count = 0
        for _, obj in pairs(InventoryContainer) do
            if (obj.item_id > 0) then
                count = count + 1
            end
        end
        return count
    end
    return -1
end

--gets filled slots by id
function InvByIdAm(InventoryContainer, id)
    if (InventoryContainer ~= nil) then
        local count = 0
        for _, obj in pairs(InventoryContainer) do
            if (obj.item_id == id) then
                count = count + 1
            end
        end
        return count
    end
    return -1
end

function TeleportToWars()
    API.DoAction_Ability("War's Retreat",1,API.OFF_ACT_GeneralInterface_route,false)
    SleepTickRandom(6)
end

function Minerocksfunc(LMinerocks)
    if (InvGAm(InventoryContainer) < 28 and LMinerocks ~= nil 
    and API.Get_tick() - Mine_global_cooldown > 3 
    and API.Get_tick() - AvoidAOE_global_cooldown > 3) then
        if (API.ReadPlayerAnim() ~= 36191) then          
            Report("Mining rocks")
            API.DoAction_Object_Direct(0x3a,API.OFF_ACT_GeneralObject_route0,LMinerocks)
            Mine_global_cooldown = API.Get_tick()              
        end
        return true          
    end
    return false
end

function Transmuterocksfunc(LTransmuterocks)
    if (LTransmuterocks ~= nil and API.Get_tick() - Mine_global_cooldown > 3 and API.Get_tick() - AvoidAOE_global_cooldown > 6) then
        if (API.ReadPlayerAnim() == 0) then
            Report("Transmuting rocks")
            API.DoAction_Object_Direct(0xc8,API.OFF_ACT_GeneralObject_route0,LTransmuterocks)
            Mine_global_cooldown = API.Get_tick()
        end
    end
end

function FightStatus()
    --in wars
    if (API.Dist_FLP(WarsCenterTile) < 30) then
        return 6
    end
    --near ichtlarin
    if (API.Dist_FLP(CrossRoadCenterTile) < 30) then
        return 5
    end
    --Ichtlarin is there == right place
    if (GetObjectFromTable(OBJECTS_table, 1, 17693) ~= nil) then
        --Gate is there 17431 dormant, 17445 active API.VB_FindPSett(10937).state == 0
        if (API.VB_FindPSett(10938).state == 0) then
            return 1 --no fight
        else
            return 2 --fight started
        end       
    end
    return 0
end

local FightStatus_status = FightStatus()
::top::
while(API.Read_LoopyLoop())
do---------------------------------------------------c--------------------------------
API.RandomSleep2(10, 100, 0)
--update objects/statuses
if (CurrentTick ~= API.Get_tick()) then
    CurrentTick = API.Get_tick()
    API.DoRandomEvents()
    --currentindex = CurrentAM.int_value + 4-->
    OBJECTS_table = API.ReadAllObjectsArray({-1},{-1},{})
    FightStatus_status = FightStatus()
    InventoryContainer = API.Container_Get_all(93)
    GetMoonstoneammount = API.Container_Findfrom(InventoryContainer,57516).item_stack
    if (GetMoonstoneammount > 40) then
        GetMoonstonedone = true
    end
    Barrierhealth = API.VB_FindPSett(10947).state / 200;
    Playerhealth = API.GetHPrecent()
    Ahk = GetObjectFromTableStringnpc(OBJECTS_table, "Feline")
    IchtlarinData = GetObjectFromTable(OBJECTS_table, 1, 17693)
    if (IchtlarinData ~= nil) then
        local IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
        IchtlarinData_copy.x = IchtlarinData_copy.x + 3
        IchtlarinData_copy.y = IchtlarinData_copy.y + 7
        if (API.VB_FindPSett(10937).state > 40000) then
            Transmuterocks = GetObjectFromTableStringArea(OBJECTS_table, 12, "Corrupt", IchtlarinData.Tile_XYZ, 20, 1,IchtlarinData_copy)
        else
            Transmuterocks = GetObjectFromTableStringArea(OBJECTS_table, 12, "Corrupt", IchtlarinData.Tile_XYZ, 20, 0,IchtlarinData_copy)
        end
        Minerocks = GetObjectFromTableStringArea(OBJECTS_table, 12, "Cleansed", IchtlarinData.Tile_XYZ, 20, 0,IchtlarinData_copy)
    end
    FirstPlatform = GetObjectFromTable(OBJECTS_table, 12, 130994)
    Aoe_3x3 = GetCoordsFromTable(OBJECTS_table, 4, 8279)
    Aoe_7x7 = GetCoordsFromTable(OBJECTS_table, 4, 8285)
    Findrightportal = GetObjectFromTableString(OBJECTS_table, 0, "Fateful")
end

--in wars
if (FightStatus_status == 6) then
    loopcheck_wars = loopcheck_wars + 1
    if (loopcheck_wars > 4) then
        API.Write_LoopyLoop(false)
        Report("Wars fail")
        goto top
    end
    API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route3,{ 114750 },50);
    Report("Withdraw last quick preset")
    SleepTickRandom(2)
    API.WaitUntilMovingEnds(20,4)
    SleepTickRandom(5)
    --presume that preset was more than 5 items of food
    --[[if (InventoryContainer ~= nil and InvGAm(InventoryContainer) < 3) then
        API.Write_LoopyLoop(false)
        Report("Couldnt withdraw preset")
        goto top
    end--]]
    SleepTickRandom(2)
    if (Findrightportal ~= nil) then
        API.DoAction_Object_Direct(0x39,API.OFF_ACT_GeneralObject_route0,Findrightportal)
        Report("Finding and Clicking portal")
        SleepTickRandom(3)
        API.WaitUntilMovingEnds(40,4)
    end
end

--near ichtlarin
if (FightStatus_status == 5) then
    loopcheck_wars = 0
    API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ 130974 },50);
    Report("Clicking  road")
    API.WaitUntilMovingEnds(10,2)
    SleepTickRandom(2)
    if (API.Compare2874Status(18)) then
        Report("Starting instance")
        API.DoAction_Interface(0x24,0xffffffff,1,1591,60,-1,API.OFF_ACT_GeneralInterface_route)
        SleepTickRandom(2)
    end
end

if (FightStatus_status == 0) then
    CurrentArea.string_value = "Area: Not in area"
end

if (FightStatus_status == 1) then
   CurrentArea.string_value = "Area: In area"
   if (InvGAm(InventoryContainer) < 5) then
        Report("error you ned more food")
        TeleportToWars()
    end
   if (IchtlarinData ~= nil) then
        local IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
        IchtlarinData_copy.x = IchtlarinData_copy.x - 2 + API.Math_RandomNumber(3)
        IchtlarinData_copy.y = IchtlarinData_copy.y - 2 + API.Math_RandomNumber(3)
        API.DoAction_TileF(FFPOINT.new(IchtlarinData_copy.x + 8,IchtlarinData_copy.y, 0))
        SleepTickRandom(3)
        API.KeyboardPress31(0x26, 100, 500)
        Report("Moving to spot")
        API.WaitUntilMovingEnds(10,2)
        if (GetObjectFromTable(OBJECTS_table, 1, 17431) ~= nil) then
            API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{ 17693 },20)
            Report("Start fight 2")
            SleepTickRandom(3)
            SpecialButtonEventsafe = false
            SpecialButtonEvent = false
            GetMoonstonedone= false
            Bossdone = true
        end
    end
end

if (FightStatus_status == 2) then
    CurrentArea.string_value = "Area: In area, fight started"

--get Moonstones
    if (GetMoonstoneammount == 0) then 
        GetMoonstonedone = false
    end
    if (not GetMoonstonedone and InvGAm(InventoryContainer) < 28) then      
        if (not API.CheckAnim(20,4)) then
            Report("Get Moonstones")
            API.DoAction_Object1(0x3e,API.OFF_ACT_GeneralObject_route0,{ 130991 },40)
            SleepTickRandom(10)
            API.WaitUntilMovingEnds(10,2)
        end
    goto top
    end

--run to safety
    if (SpecialButtonEventsafe) then
        Report("Running to safespot")
        if (API.VB_FindPSett(10937).state < 1) then
            SpecialButtonEventsafe = false
            SpecialButtonEvent = false
            Bossdone = false
            GetMoonstonedone = false
            SleepTickRandom(20)
            TeleportToWars()
            SleepTickRandom(8)
            goto top
        end
        if (IchtlarinData ~= nil) then
            local IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
            IchtlarinData_copy.x = IchtlarinData_copy.x - 2 + API.Math_RandomNumber(3)
            IchtlarinData_copy.y = IchtlarinData_copy.y - 2 + API.Math_RandomNumber(4)
            API.DoAction_TileF(FFPOINT.new(IchtlarinData_copy.x ,IchtlarinData_copy.y + 5, 0))
            SleepTickRandom(5)
            if (API.VB_FindPSett(10937).state < 1) then
                SpecialButtonEventsafe = false
                SpecialButtonEvent = false
                Bossdone = false
                GetMoonstonedone = false
                SleepTickRandom(20)
                TeleportToWars()
                SleepTickRandom(8)
                goto top
            end
            --API.DoAction_Surge_TileF(FFPOINT.new(IchtlarinData_copy.x ,IchtlarinData_copy.y + 5, 0))
            API.DoAction_BDive_Tile(WPOINT.new(IchtlarinData_copy.x ,IchtlarinData_copy.y + 5, 0))
            SleepTickRandom(1)
            API.DoAction_TileF(FFPOINT.new(IchtlarinData_copy.x ,IchtlarinData_copy.y + 5, 0))
            SleepTickRandom(6)
            local staysafe = API.SystemTime()           
            while(API.SystemTime() - staysafe < 5000) do
                local IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
                IchtlarinData_copy.x = IchtlarinData_copy.x + 3
                IchtlarinData_copy.y = IchtlarinData_copy.y + 7
                if (API.Dist_FLP(IchtlarinData_copy) < 5) then
                    Minerocks = GetObjectFromTableStringArea(OBJECTS_table, 12, "Corrupt", IchtlarinData.Tile_XYZ, 20, 2, IchtlarinData_copy)
                    if (Minerocks ~= nil) then 
                        if (Minerocksfunc(Minerocks)) then
                            SleepTickRandom(2)  
                        end  
                    end
                    Transmuterocks = GetObjectFromTableStringArea(OBJECTS_table, 12, "Cleansed", IchtlarinData.Tile_XYZ, 20, 2, IchtlarinData_copy)
                    if (Transmuterocks ~= nil) then
                        if (Transmuterocksfunc(Transmuterocks)) then
                            SleepTickRandom(2)
                        end
                    end
                end
                API.RandomSleep2(10, 100, 0)
            end
            SpecialButtonEventsafe = false
            SpecialButtonEvent = false
        end
    goto top
    end

--kill
    if (GetMoonstoneammount > 1 and Ahk ~= nil and API.Get_tick() - KillAhk_global_cooldown > 1) then
        Report("Killing akh")
        API.DoAction_NPC__Direct(0x29,API.OFF_ACT_InteractNPC_route,Ahk)
        API.RandomSleep2(10, 100, 0)
        API.DoAction_NPC__Direct(0x29,API.OFF_ACT_InteractNPC_route,Ahk)
        KillAhk_global_cooldown = API.Get_tick()
    goto top
    end

--eat foods
    if (Playerhealth < 60 and API.Get_tick() - FP_global_cooldown > 10) then 
        local AB = API.GetABs_name("Eat Food")
        if AB.id > 0 and AB.enabled and AB.hotkey ~= 0 then
            Report("Eating food 60%")
            API.KeyboardPress32(string.byte(AB.hotkey), 0)
            FP_global_cooldown = API.Get_tick()
        else
            Report("Out of food 3")
            TeleportToWars()
        end
    end

--wait for platforms
    if (SpecialButtonEvent) then
        if (IchtlarinData ~= nil) then
            if (API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ 130994 },15)) then
                Report("Jump platforms")
                SleepTickRandom(1)
            end
            local IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
            IchtlarinData_copy.x = IchtlarinData_copy.x + 4
            IchtlarinData_copy.y = IchtlarinData_copy.y + 20 + 4
            if (API.Dist_FLP(IchtlarinData_copy) < 2) then
                if (API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ 130996 },15)) then
                    SleepTickRandom(1)
                end
            end
            IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
            IchtlarinData_copy.x = IchtlarinData_copy.x - 4
            IchtlarinData_copy.y = IchtlarinData_copy.y + 20 + 7
            if (API.Dist_FLP(IchtlarinData_copy) < 2) then
                if (API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ 130998 },15)) then
                    SleepTickRandom(1)
                end
            end
            IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
            IchtlarinData_copy.x = IchtlarinData_copy.x + 4
            IchtlarinData_copy.y = IchtlarinData_copy.y + 20 + 13
            if (API.Dist_FLP(IchtlarinData_copy) < 2) then
                if (API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ 131000 },15)) then
                    SleepTickRandom(1)
                end
            end
            IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
            IchtlarinData_copy.x = IchtlarinData_copy.x - 4
            IchtlarinData_copy.y = IchtlarinData_copy.y + 20 + 17
            if (API.Dist_FLP(IchtlarinData_copy) < 2) then
                if (API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{ 17645 },50)) then     
                    Report("Pillars completed")   
                    SpecialButtonEventsafe = true
                    SpecialButtonEvent = false
                    SleepTickRandom(6)
                end                
            end
        end
    goto top
    end



-- full inventory, try to use it
    if (InvGAm(InventoryContainer) > 25 -- or corruptionStacks() > 29 --]]
    or InvByIdAm(InventoryContainer, 57517) * 3125 > API.VB_FindPSett(10937).state ) then
        if (not SpecialButtonEvent and API.SystemTime() - SpecialButtonTimer > 61000) then
            Report("Call help")
            if (IchtlarinData ~= nil) then
                SpecialButtonTimer = API.SystemTime()
                SpecialButtonEvent = true
                API.DoAction_Interface(0x2e,0xffffffff,1,743,1,-1,API.OFF_ACT_GeneralInterface_route)
                local IchtlarinData_copy = FFPOINT.new(IchtlarinData.Tile_XYZ.x,IchtlarinData.Tile_XYZ.y,0)
                IchtlarinData_copy.x = IchtlarinData_copy.x - 3 + API.Math_RandomNumber(4)
                API.DoAction_TileF(FFPOINT.new(IchtlarinData_copy.x + 2,IchtlarinData_copy.y + 19, 0))
                Report("Go to wait for platforms")
                SleepTickRandom(4)
                goto top
            end
        end
    end

--avoid aoe-s
    if (Aoe_3x3 ~= nil and API.Get_tick() - AvoidAOE_global_cooldown > 4) then
        local FT = API.Math_FreeTiles(Aoe_3x3,2,10,{})
        if (#FT > 0)  then
            Report("Aoe_3x3 " .. FT[1].x .. ":" .. FT[1].y)
            API.DoAction_TileF(FT[1])
            AvoidAOE_global_cooldown = API.Get_tick()
        end
    end
    if (Aoe_7x7 ~= nil and API.Get_tick() - AvoidAOE_global_cooldown > 4) then
    local FT = API.Math_FreeTiles(Aoe_7x7,5,15,{})
    local depletedRocks = GetCoordsFromTable(OBJECTS_table, 0, 130981)
    if depletedRocks ~= nil then
        if #depletedRocks > 0 then
            local set2 = {}
            for _, value in ipairs(depletedRocks) do
                set2[value] = true
            end
            local betterFreeTiles = {}
            for _, value in ipairs(FT) do
                if not set2[value] then
                    table.insert(betterFreeTiles, value)
                end
            end
            if (#betterFreeTiles > 0) then
                Report("Aoe_7x7 " .. betterFreeTiles[1].x .. ":" .. betterFreeTiles[1].y)
                if not API.DoAction_BDive_Tile(WPOINT.new(betterFreeTiles[1].x, betterFreeTiles[1].y, 0)) then
                API.DoAction_BDive_Tile(WPOINT.new(betterFreeTiles[1].x, betterFreeTiles[1].y, 0))
                end
                AvoidAOE_global_cooldown = API.Get_tick()
            end
        end    
    else
        if (#FT > 0)  then
            Report("Aoe_7x7 " .. FT[1].x .. ":" .. FT[1].y)
            if not API.DoAction_BDive_Tile(WPOINT.new(FT[1].x, FT[1].y, 0)) then
                API.DoAction_BDive_Tile(WPOINT.new(FT[1].x, FT[1].y, 0))
            end
            AvoidAOE_global_cooldown = API.Get_tick()
        end
    end
end

--repair barrier if needed
    if (GetMoonstoneammount > 0 and Barrierhealth < 30) then 
        Report("Repair barrier")
        API.DoAction_NPC(0xae,API.OFF_ACT_InteractNPC_route,{ 18245 },30)
        SleepTickRandom(2)
        API.WaitUntilMovingEnds(20,2)
        SleepTickRandom(7)-- give it time
    end

--Mine if possible
    if (Minerocksfunc(Minerocks)) then    
        goto top
    end

--Transmute if possible
    if (Transmuterocks ~= nil) then
        Transmuterocksfunc(Transmuterocks)
    end

end
end----------------------------------------------------------------------------------
