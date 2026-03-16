local API = require("api")
local APIOSRS = require("apiosrs")


local function Bankdeposit(stuff)
    local countloops = 0
    while countloops < 6 and API.Read_LoopyLoop() do
        countloops = countloops + 1
        APIOSRS.RL_ClickEntity(9593, {stuff} )
        API.RandomSleep2(500, 1000, 2000)
        if Bank:InventoryContains(stuff) then
            print("Deposit failed, retrying")
        else
            print("Deposit successful")
            return true
        end
    end
    return false
end


local main_stuff = 2357 -- gold/silver bar
local second_stuff = 1605 -- gem
local result_stuff = 1645 --
local mold = 11065 -- amulet 1595, ring 1592, bracelet 11065
local banks = { 10355 } --
local use_obj = { 16469 } --
local sleeps = { 5000, 10000, 20000 }
local currentfail = 0
local currentfail_bank = 0
while API.Read_LoopyLoop() do
    
    local countloops = 0
    while (API.CheckAnim(50) or API.ReadPlayerMovin()) and API.Read_LoopyLoop() do
        countloops = countloops + 1
        print("St" .. tostring(countloops))
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
    if Inventory:IsOpen() and Inventory:Contains(main_stuff) and (second_stuff == 0 or Inventory:Contains(second_stuff)) then
        print("Click furnace1")
        if (APIOSRS.RL_ClickEntity(0, use_obj, 25 )) then
            print("Click furnace2")
            API.RandomSleep2(8500, 1000, 2000)
            API.KeyboardPress31(32, 40, 80)--select item manually before using
            API.RandomSleep2(2500, 1000, 2000)
        end
    else
        print("Opening bank")
        if not Bank:IsOpen() then
            APIOSRS.RL_ClickEntity(0, banks, 25 )
            API.RandomSleep2(8500, 1000, 2000)
        end
        if Bank:IsOpen() then
            print("Bank open")
            --APIOSRS.RL_ClickBankDepositAll()
            if not APIOSRS.RL_ClickBankInvDepositAllExcept({mold}) then
                APIOSRS.RL_ClickBankInvDepositAllExcept({mold})-- try again
                currentfail_bank = currentfail_bank + 1
                if currentfail_bank > 3 then
                    print("Failed to deposit inventory, stopping script")
                    API.Write_LoopyLoop(false)
                end
            else
                currentfail_bank = 0
            end
            API.RandomSleep2(300, 1000, 2000)
            if Bank:Contains(main_stuff) and (second_stuff == 0 or Bank:Contains(second_stuff))  then
                print("Bank contains required items")
                APIOSRS.RL_ClickEntity(95, {main_stuff} )
                API.RandomSleep2(300, 1000, 2000)
                APIOSRS.RL_ClickEntity(95, {second_stuff} )
                currentfail = 0
                API.RandomSleep2(300, 1000, 2000)
                print("Closing bank")
                APIOSRS.RL_ClickCloseBank()-- furnace visible without closing, zoomout and turn camera, needs bit of work
            else
                print("out of supplies, stopping script")
                API.Write_LoopyLoop(false)
            end
        end
    end
    API.RandomSleep2(4700, 1777,12777)
end