local API = require("api")
local APIOSRS = require("apiosrs")


local itemtoalch = {2504,1150}
local nats = 561
local currentfail = 0
while API.Read_LoopyLoop() do
    if Inventory:Contains(itemtoalch) and Inventory:Contains({nats}) then
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
    API.RandomSleep2(1700, 1777,12777)
end