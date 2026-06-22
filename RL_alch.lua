local API = require("api")
local APIOSRS = require("apiosrs")


local itemtoalch = {2504,1150,1128,1114,3055,1360,1202,3055,1378,1348,1404,1374,1334,1402,1094,1320
,3055,3203,1164,1124,1214,1186,1306,1080,1433,9432,71,2500}
local nats = 561
local currentfail = 0
while API.Read_LoopyLoop() do
    if Inventory:Contains(itemtoalch) and Inventory:Contains({nats}) and not API.CheckAnim(50)and not API.ReadPlayerMovin() then
        if APIOSRS.RL_GetOpenTab() ~= 6 then
            APIOSRS.RL_OpenTab(6)
            print("wrong tab, opening spellbook")
            API.RandomSleep2(2500, 100, 200)
        end
        if APIOSRS.RL_GetOpenTab() == 6 then
            if not APIOSRS.RL_IsWidgetSelected() then
                APIOSRS.RL_ClickSpellbook("High Level Alchemy",0)
                print("high alch")
                API.RandomSleep2(1500, 1000, 2000)
            else
                APIOSRS.RL_OpenTab(3)
                print("spell already selected")
                API.RandomSleep2(2500, 1000, 2000)
            end
        end
        if APIOSRS.RL_GetOpenTab() == 3 then
            if APIOSRS.RL_IsWidgetSelected() then
                APIOSRS.RL_ClickEntity(93, itemtoalch )
                print("clicking item")
                API.RandomSleep2(1500, 1000, 2000)
            end
        end
    end
    API.RandomSleep2(300, 3077,22777)
end