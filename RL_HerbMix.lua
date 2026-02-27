local API = require("api")
local APIOSRS = require("apiosrs")


local Vial_ = 99
local Sec_ = 99
local currentfail = 0
while API.Read_LoopyLoop() do
    if Inventory:Contains(Vial_) and Inventory:Contains(Sec_) then
        if APIOSRS.RL_GetOpenTab() == 3 then
                APIOSRS.RL_ClickEntity(93, {Vial_} )
                print("mixing 1")
                API.RandomSleep2(1500, 1000, 2000)
                currentfail = 0
            end
            if APIOSRS.RL_IsWidgetSelected() then
                APIOSRS.RL_ClickEntity(93, {Sec_} )
                print("mixing 2")
                API.RandomSleep2(1500, 1000, 2000)
        end
    else
        print("banking")



    end
    API.RandomSleep2(1700, 1777,12777)
end