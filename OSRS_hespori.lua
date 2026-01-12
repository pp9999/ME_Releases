local API = require("api")

print("Run Lua")

ImGui_Pro = API.CreateIG_answer()
ImGui_Pro.box_name = "ImGui_Pro"
ImGui_Pro.box_start = FFPOINT.new(5, 50, 0)
ImGui_Pro.box_size = FFPOINT.new(95, 20, 0)
ImGui_Pro.string_value = ""
ImGui_Pro.tooltip_text = "Projectile"
ImGui_Pro.colour = ImColor.new(255,255,255)
API.DrawTextAtBG(ImGui_Pro)
ImGui_Anim = API.CreateIG_answer()
ImGui_Anim.box_name = "ImGui_Anim"
ImGui_Anim.box_start = FFPOINT.new(5, 80, 0)
ImGui_Anim.box_size = FFPOINT.new(95, 20, 0)
ImGui_Anim.string_value = ""
ImGui_Anim.tooltip_text = "Npc anime"
ImGui_Anim.colour = ImColor.new(255,255,255)
API.DrawTextAtBG(ImGui_Anim)
ImGui_Warn = API.CreateIG_answer()
ImGui_Warn.box_name = "ImGui_Warn"
ImGui_Warn.box_start = FFPOINT.new(5, 110, 0)
ImGui_Warn.box_size = FFPOINT.new(95, 20, 0)
ImGui_Warn.string_value = ""
ImGui_Warn.colour = ImColor.new(255,255,255)
API.DrawTextAt(ImGui_Warn)
ImGui_Select = API.CreateIG_answer()
ImGui_Select.box_name = "ImGui_Select"
ImGui_Select.box_start = FFPOINT.new(100, 50, 0)
ImGui_Select.box_size = FFPOINT.new(220, 50, 0)
ImGui_Select.colour = ImColor.new(255,255,255)

local Hespori = {
    Name = "Hespori",
    Id = 8583, 
    Minis_id = 8585,
    Ranged_pr = 1639,
    Magic_pr = 1640,
    Death_pr = 0,
    Ranged_anim = {0},--8224
    Magic_anim = {0},--8223
    Melee_anim = {0},
    Eat_block = 100,
    KeepOnPrayerTab = false,
    Obst_object1 = 0
}
local Echo_Hespori = {
    Name = "Echo Hespori",
    Id = 8583, 
    Minis_id = 8585,
    Ranged_pr = 3140,
    Magic_pr = 3141,
    Death_pr = 3143,
    Ranged_anim = {8222},
    Magic_anim = {8223},
    Melee_anim = {0},
    Eat_block = 100,
    KeepOnPrayerTab = false,
    Obst_object1 = 0
}
local Scurrius = {
    Name = "Scurrius",
    Id = 7222, 
    Minis_id = 0,
    Ranged_pr = 2642,
    Magic_pr = 2640,
    Death_pr = 0,
    Ranged_anim = {10695},
    Magic_anim = {10697},
    Melee_anim = {10693},
    Eat_block = 100,
    KeepOnPrayerTab = false,
    Obst_object1 = 0
}
local Jad = {
    Name = "Jad",
    Id = 3127, 
    Minis_id = 0,
    Ranged_pr = 0,--none
    Magic_pr = 0,--448-450
    Death_pr = 0,
    Ranged_anim = {2652},
    Magic_anim = {2656},
    Melee_anim = {0},
    Eat_block = 100,
    KeepOnPrayerTab = false,
    Obst_object1 = 0
}
local AlchHydra = {
    Name = "AlchHydra",
    Id = 8615,--8615-8621
    Minis_id = 0,
    Ranged_pr = 1663,
    Magic_pr = 1662,
    Death_pr = 0,
    Ranged_anim = {8235,8242,8249,8256},
    Magic_anim = {8236,8243,8250,8257},
    Melee_anim = {0},
    Eat_block = 100,
    KeepOnPrayerTab = false,
    Obst_object1 = 0
}
local Echo_dog = {
    Name = "Echo_dog",
    Id = 5863,
    Minis_id = 0,
    Ranged_pr = 3122,
    Magic_pr = 3119,
    Death_pr = 4493,
    Ranged_anim = {4490},
    Magic_anim = {4489},
    Melee_anim = {0},
    Eat_block = 100,
    KeepOnPrayerTab = false,
    Obst_object1 = 0
}
local Whisperer = {
    Name = "Whisperer",
    Id = 12206,
    Minis_id = 0,
    Ranged_pr = 2444,
    Magic_pr = 2445,
    Death_pr = 0,
    Ranged_anim = {0},
    Magic_anim = {0},
    Melee_anim = {0},
    Eat_block = 5000,
    KeepOnPrayerTab = true,
    Obst_object1 = 47575
}


ImGui_Select.stringsArr = { 
Hespori.Name,Echo_Hespori.Name, Scurrius.Name, Jad.Name, 
AlchHydra.Name, Echo_dog.Name, Whisperer.Name  
}
API.DrawComboBox(ImGui_Select)

function getcurrentselect()
    local currentnpcsindex = ImGui_Select.int_value
    if (currentnpcsindex == 0) then
        return Hespori
    end
    if (currentnpcsindex == 1) then
        return Echo_Hespori
    end
    if (currentnpcsindex == 2) then
        return Scurrius
    end
    if (currentnpcsindex == 3) then
        return Jad
    end
    if (currentnpcsindex == 4) then
         return AlchHydra
    end
    if (currentnpcsindex == 5) then
         return Echo_dog
     end
     if (currentnpcsindex == 6) then
        return Whisperer
    end
    return nil
end

local current = 0
local current_pray_1 = 0
local current_pray_2 = 0
local currentEat_block = API.SystemTime()
local Eatcooldown_block = API.SystemTime()
local Potcooldown_block = API.SystemTime()
local PrayMagiccooldown_block = API.SystemTime()
local PrayRangecooldown_block = API.SystemTime()
::labeltop::
--main loop
while(API.Read_LoopyLoop())
do-----------------------------------------------------------------------------------
    current = 0
    current_pray_1 = 0
    current_pray_2 = 0
current = getcurrentselect()
if (current == nil) then
    goto labeltop
end
local rangetable = nil
local magictable = nil
local GAOA = API.ReadAllObjectsArray({1,5},{},{})
for _, GO in ipairs(GAOA) do
    if (GO ~= nil and GO.Type == 1) then
        if (GO.Id == current.Id and GO.Anim > 0) then
            for k, v in pairs(current.Ranged_anim) do
                if (v > 0 and GO.Anim == v) then
                    ImGui_Anim.string_value = "RANGED A"
                    current_pray_1 = 40
                end
            end
            for k, v in pairs(current.Magic_anim) do
                if (v > 0 and GO.Anim == v) then
                    ImGui_Anim.string_value = "MAGIC A"
                    current_pray_1 = 37
                end
            end
            for k, v in pairs(current.Melee_anim) do
                if (v > 0 and GO.Anim == v) then
                    ImGui_Anim.string_value = "MELLE A"
                    current_pray_1 = 43
                end
            end
        end
    end

    if (GO.Type == 12) then
        if ( current.Obst_object1 ~= nil and GO.Id == current.Obst_object1) then
            --API.MarkTiles({GO.Tile_XYZ}, 2000)
        end
    end

    if (GO.Type == 5) then
        --Only first hit, they are allready sorted
        if (rangetable == nil) then
            if (GO.Id == current.Ranged_pr and GO.Distance > 0 and GO.Distance < 20) then
                rangetable = GO
            end
        end
        if (magictable == nil) then
            if (GO.Id == current.Magic_pr and GO.Distance > 0 and GO.Distance < 20) then
                magictable = GO
            end
        end
        --this is mostly seperate thing
        if (GO.Id == current.Death_pr) then
            ImGui_Pro.string_value = "Death P"
            ImGui_Warn.box_start = FFPOINT.new(GO.TileX, GO.TileY, GO.TileZ)
            API.MarkTiles({GO.Tile_XYZ}, 5000)
        end
    end
    --Jad should be protected against before launch, so anim
end

-- 0 nothing, 1 range closer, 2 magic closer
local foundPR_types = 0
if (rangetable ~= nil and magictable ~= nil) then
    if (rangetable.Distance < magictable.Distance) then
        foundPR_types = 1
    else
        foundPR_types = 2
    end
end
if (rangetable ~= nil and foundPR_types == 0) then
    foundPR_types = 1
end
if (magictable ~= nil and foundPR_types == 0) then
    foundPR_types = 2
end
if (foundPR_types == 1) then
    ImGui_Pro.string_value = "Ranged P"
    current_pray_2 = 40
end
if (foundPR_types == 2) then  
    ImGui_Pro.string_value = "Magic P"
    current_pray_2 = 37
end

if (API.OSRS_GetPrayPoints() > 0 and not API.OSRS_GetQuickPrayStatus()) then
    print("Quickpray")
    API.OSRS_DoQuickPray()
    API.OSRS_SleepTick(4)
end

if (API.OSRS_GetPrayPoints() > 0) then
    local picked = false
    if (current_pray_1 > 0)  then
        if (API.SystemTime() - PrayMagiccooldown_block > 0)  then
                print("pray on 1 " .. ":" .. tostring(current_pray_1))
                API.OSRS_DoPrayProtect(current_pray_1)
                picked = true
                PrayMagiccooldown_block = API.SystemTime() + 200
        end
    end
    if (current_pray_2 > 0 and not picked)  then
        if (API.SystemTime() - PrayRangecooldown_block > 0)  then
                print("pray on 2 " .. ":" .. tostring(current_pray_2))
                API.OSRS_DoPrayProtect(current_pray_2)
                PrayRangecooldown_block = API.SystemTime() + 200
        end
    end
end

if (API.SystemTime() - Potcooldown_block > 0) then
    if (API.OSRS_GetPrayPointsPerc() < 50) then
        --contains pray pots
        if (API.Container_Check_Items( 93, {139,141,143,2434})) then
            if (API.OSRS_DoDrinkpot(3)) then
                Potcooldown_block = API.SystemTime() + 600
                print("Drink pray1")
                if (API.SystemTime() - Eatcooldown_block > 0) then
                    if (API.OSRS_GetHPointPerc() < 90) then
                        if (API.Container_Check_Items( 93, {13441,385,7946})) then
                            if (API.OSRS_DoEatFoods()) then
                                print("Eat foods1")
                                Eatcooldown_block = API.SystemTime() + 1800
                            end
                        end
                    end
                end
                if (current.KeepOnPrayerTab) then
                    API.OSRS_OpenMenu(5)
                end
            end
        end
    end
end

if (API.SystemTime() - Potcooldown_block > 0) then
    Eatcooldown_block = API.SystemTime()
    if (API.SystemTime() - currentEat_block > current.Eat_block) then
        currentEat_block = API.SystemTime()
        if (API.OSRS_GetHPointPerc() < 60) then
            --contains certain foods
            if (API.Container_Check_Items( 93, {13441,385,7946})) then
                if (API.OSRS_GetPrayPointsPerc() < 72) then
                    if (API.Container_Check_Items( 93, {139,141,143,2434})) then
                        if (API.OSRS_DoDrinkpot(3)) then
                            Potcooldown_block = API.SystemTime() + 600
                            print("Drink pray2") 
                        end 
                    end
                end
                if (API.SystemTime() - Eatcooldown_block > 0) then
                    if (API.OSRS_DoEatFoods()) then             
                        print("Eat foods2")
                        Eatcooldown_block = API.SystemTime() + 1800
                    end
                end
                if (current.KeepOnPrayerTab) then
                    API.OSRS_OpenMenu(5)
                end
            end
        end
    end
end

API.RandomSleep2(1, 10, 10)
end----------------------------------------------------------------------------------
