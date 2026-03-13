local API = require("api")
local APIOSRS = require("apiosrs")


local Raw_fish = 363 --
local banks = { 21301 } --farm bank 26711
local stoves = { 21302 } -- stove
local sleeps = { 5000, 10000, 20000 }
local currentfail = 0
while API.Read_LoopyLoop() do
    
    local countloops = 0
    while API.ReadPlayerAnim() ~= -1 and API.Read_LoopyLoop() do
        countloops = countloops + 1
        if countloops > 500 then
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
        print("Opening inventory tab")
    end
    if Inventory:IsOpen() and Inventory:Contains(Raw_fish) then
        APIOSRS.RL_ClickEntity(0, stoves, 7 )
        API.RandomSleep2(6500, 1000, 2000)
        API.KeyboardPress31(32, 40, 80)
        API.RandomSleep2(2500, 1000, 2000)
    else
        print("Opening bank")
        if not Bank:IsOpen() then
            APIOSRS.RL_ClickEntity(0, banks, 7 )
            API.RandomSleep2(6500, 1000, 2000)
        end
        if Bank:IsOpen() then
            print("Bank open")
            APIOSRS.RL_ClickBankDepositAll()
            API.RandomSleep2(300, 1000, 2000)
            if Bank:Contains(Raw_fish) then
                print("Bank contains required items")
                APIOSRS.RL_ClickEntity(95, {Raw_fish} )
                currentfail = 0
                API.RandomSleep2(300, 1000, 2000)
                print("Closing bank")
                APIOSRS.RL_ClickCloseBank()
            else
                print("out of supplies, stopping script")
                API.Write_LoopyLoop(false)
            end
        end
    end
    API.RandomSleep2(4700, 1777,12777)
end