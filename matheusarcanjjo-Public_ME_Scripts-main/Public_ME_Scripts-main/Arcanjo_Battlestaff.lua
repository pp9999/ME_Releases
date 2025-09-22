--[[
# Script Name:   Arcanjo_Battlestaff
# Description:   <Make Battlestaves>
# Author:        <Arcanjo>
# Version:       <1.0>
# Date:          <2025.08.09>
--]]


-- This script works perfectly in front of the Fort Forinthry bank

local API = require("api")
local UTILS = require("utils")

local ID = {
    Battlestaff = 1391,
    Earth_Orb = 575,
    Water_Orb = 571,
    Fire_Orb = 569,
    Air_Orb = 573,
    Bank_Booth = 125115,
    Water_battlestaff = 1395
}

-- Put the desired orb here: Earth_Orb, Water_Orb, Fire_Orb, Air_Orb

local orbChoosed = ID.Earth_Orb

-- Logger for script
local function log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(timestamp .. " - " .. message)
end


local function loadBankPreset()
    log("Accessing the bank to load the last preset...")

    -- Opens the bank
    API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { ID.Bank_Booth }, 50)

    -- Pause for the bank interface to load
    API.RandomSleep2(2000, 200, 300)

    -- Loop to try loading the preset until the items are in the inventory
    local attempts = 0
    while attempts < 3 do
        log("Attempt " .. attempts + 1 .. ": Loading preset and checking inventory...")

        -- Loads bank preset 1
        API.DoAction_Interface(0x48, 0x1, 0, 1473, 5, 0)

        -- Pause to give the game time to update the inventory
        API.RandomSleep2(3000, 200, 300)

        local orbCount = API.InvItemcount_1(orbChoosed)
        local staffCount = API.InvItemcount_1(ID.Battlestaff)
        log("Orb count in inventory: " .. orbCount)
        log("Staff count in inventory: " .. staffCount)
        if orbCount > 0 and staffCount > 0 then 
            log("Preset items successfully loaded!")
            return true
        end

        attempts = attempts + 1
    end

    log("Failed to load preset items after several attempts. Stopping script.")
    API.Write_LoopyLoop(false) -- <- stops the loop here
    return false
end


local function craftStaves()
    log("Materials in inventory. Starting crafting...")
    -- Command lines to craft the items
    API.DoAction_Inventory1(orbChoosed, 0, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(4000, 0, 0) 
    log("Pressing Spacebar")
    API.KeyboardPress2(0x20, 3000, 20)
    log("Sleeping")
    API.RandomSleep2(18000, 0, 0) -- 18 seconds wait
end


while API.Read_LoopyLoop() do 
    if API.InvItemcount_1(orbChoosed) > 0 and API.InvItemcount_1(ID.Battlestaff) > 0 and not API.isProcessing() then
        log("STARTING")
        craftStaves()
        UTILS.countTicks(3)
    else
        loadBankPreset()
    end
    UTILS.rangeSleep(600, 0, 0)
end
