local API = require("api")
local APIOSRS = require("apiosrs")

--Grimy irit 209
local Vial_ = 227 --vial 227, unf irit 101
local Sec_ = 259 --irit 259, eye of new 221
local banks = { 26711 } --farm bank 26711
local sleeps = { 5000, 10000, 20000, 25000, 30000 }
local currentfail = 0
while API.Read_LoopyLoop() do
    
    local countloops = 0
    while API.ReadPlayerAnim() ~= -1 and API.Read_LoopyLoop() do
        countloops = countloops + 1
        if countloops > 50 then
            print("Stuck in animation, stopping script")
            API.Write_LoopyLoop(false)
        end
        API.RandomSleep2(200, 1000, 2000)
    end

    currentfail = currentfail + 1
    if currentfail > 8 then
        print("Too many fails, stopping script")
        API.Write_LoopyLoop(false)
    end
    if APIOSRS.RL_GetOpenTab() ~= 3 then
        APIOSRS.RL_OpenTab(3)
        API.RandomSleep2(2500, 1000, 2000)
        print("Opening tab")
    end
    if Inventory:IsOpen() and Inventory:Contains(Vial_) and (Sec_ == 0 or Inventory:Contains(Sec_)) then
            APIOSRS.RL_ClickEntity(93, {Vial_} )
            print("mixing 1")
            API.RandomSleep2(500, 1000, 2000)
            currentfail = 0
        if Sec_ > 0 then
            if APIOSRS.RL_IsWidgetSelected() then
                APIOSRS.RL_ClickEntity(93, {Sec_} )
                print("mixing 2")
                API.RandomSleep2(500, 1000, 2000)
            end           
        end
        API.KeyboardPress31(32, 40, 80)
        API.RandomSleep2(sleeps[5], 1000, 2000)
    else
        print("Opening bank")
        if not Bank:IsOpen() then
            APIOSRS.RL_ClickEntity(0, banks, 2 )
            API.RandomSleep2(2500, 1000, 2000)
        end
        if Bank:IsOpen() then
            print("Bank open")
            APIOSRS.RL_ClickBankDepositAll()
            API.RandomSleep2(100, 1000, 2000)
            if Bank:Contains(Vial_) and (Sec_ == 0 or Bank:Contains(Sec_)) then
                print("Bank contains required items")
                APIOSRS.RL_ClickEntity(95, {Vial_} )
                API.RandomSleep2(100, 1000, 2000)
                if Sec_ > 0 then
                    APIOSRS.RL_ClickEntity(95, {Sec_} )
                    API.RandomSleep2(500, 1000, 2000)
                end
                --if Inventory:Contains(Vial_) and Inventory:Contains(Sec_) then
                    print("Closing bank")
                    APIOSRS.RL_ClickCloseBank()
                --end
            else
                print("out of supplies, stopping script")
                API.Write_LoopyLoop(false)
            end
        end
    end
    API.RandomSleep2(4700, 1777,12777)
end