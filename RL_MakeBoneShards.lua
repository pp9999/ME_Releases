local API = require("api")
local APIOSRS = require("apiosrs")


local NPCs = {13346}--unote npc
local unitems_noted = {28900}--unblessed NOTED bones
local unitems_not_noted = {28899}--unblessed bones
local blessed = {29354}--blessed
local chisel = {1755}
local Alter = {52799}
local currentfail = 0
while API.Read_LoopyLoop() do

    if not API.CheckAnim(50) and not API.ReadPlayerMovin() then
        if Inventory:Contains(unitems_not_noted) then
            local object = APIOSRS.ReadAllObjectsArrayFirst({0},Alter)
            if object ~= nil then
                print("Walking to altar1 " .. tostring(object.Distance))
                if (object.Distance > 7) then
                    print("Walking to altar2 ")
                    APIOSRS.RL_ClickTile(object.Tile_XYZ.x,object.Tile_XYZ.y + 3,true)
                    API.RandomSleep2(5200, 1000, 2000)
                end
            end
            APIOSRS.RL_ClickEntity(0, Alter, 20)
            API.RandomSleep2(1200, 1000, 2000)
        end
        if Inventory:Contains(blessed) then
            APIOSRS.RL_ClickEntity(93, blessed)
            API.RandomSleep2(1200, 1000, 2000)
        end
        if Inventory:Contains(unitems_noted) and not Inventory:Contains(unitems_not_noted) and not Inventory:Contains(blessed) then
            if APIOSRS.RL_GetOpenTab() == 3 then
                APIOSRS.RL_ClickEntity(93, unitems_noted)
                API.RandomSleep2(500, 1000, 2000)
                if APIOSRS.RL_IsWidgetSelected() then
                    APIOSRS.RL_ClickEntity(1, NPCs,30,false,0,0,"Use")
                    API.RandomSleep2(2500, 1000, 2000)
                    while API.ReadPlayerMovin() do
                        API.RandomSleep2(500, 1000, 2000)
                    end
                    API.KeyboardPress31(51, 40, 80)
                end
            end
        end
    end

    
    API.RandomSleep2(700, 1777,12777)
end