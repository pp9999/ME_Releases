local API = require("api")
local APIOSRS = require("apiosrs")

local safetyloopcheck = 0
while API.Read_LoopyLoop() do

    if safetyloopcheck > 35 then -- can miss few times
        API.Write_LoopyLoop(false)
    end

    if not API.CheckAnim(50) then
        if not Inventory:IsFull() then
            APIOSRS.RL_ClickEntity(1, { 8523 }, 12)
            safetyloopcheck = safetyloopcheck + 1
        else
            safetyloopcheck = 0
            if Inventory:Contains({946}) then
                if Inventory:Contains({22826,22829,22832,22835}) then
                    APIOSRS.RL_ClickEntity(93, { 946 })
                    API.RandomSleep2(200, 777, 1777)
                    if APIOSRS.RL_IsWidgetSelected() then
                        local clicked = false
                        local blu = Inventory:InvItemcount(22826)
                        if blu > 0 and not clicked then
                           if APIOSRS.RL_ClickEntity(93, { 22826 }) then
                                clicked = true
                                print("waiting blu fishes to be done")
                           end
                        end
                        local tenc = Inventory:InvItemcount(22829)
                        if tenc > 0 and not clicked then
                            if APIOSRS.RL_ClickEntity(93, { 22829 }) then
                                clicked = true
                                print("waiting tenc fishes to be done")
                            end
                        end
                        local eel = Inventory:InvItemcount(22832)
                        if eel > 0 and not clicked then
                           if APIOSRS.RL_ClickEntity(93, { 22832 }) then
                                clicked = true
                                print("waiting eel fishes to be done")
                           end
                        end
                        local siren = Inventory:InvItemcount(22835)
                        if siren > 0 and not clicked then
                            if APIOSRS.RL_ClickEntity(93, { 22835 }) then
                                clicked = true
                                print("waiting siren fishes to be done")
                            end
                        end
                        API.RandomSleep2(1000 * (blu + tenc + eel + siren), 1000, 10000)
                    end
                end
            end
        end
    end

    API.RandomSleep2(700, 1777,12777)
end