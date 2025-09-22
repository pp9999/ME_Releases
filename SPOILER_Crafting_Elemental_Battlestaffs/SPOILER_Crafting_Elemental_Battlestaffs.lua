print("Run Lua script Crafting Earth BattleStaves.")

local API = require("api")

-- Define the IDs for different types of orbs
local ID = {
    Battlestaff = 1391,
    Earth_Orb = 575,
    Water_Orb = 571,
    Fire_Orb = 569,
    Air_Orb = 573,
}

local NPC_ID = {
    Banker = 3418,
    -- Add more NPC IDs here as needed
}

local BankCoords = {
    { x = 3163, y = 3484 },  -- GE
}

-- Basic logger implementation
local function log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(timestamp .. " - " .. message)
end

-- Function to set the required orb ID
local function setRequiredOrb(orbType)
    if ID[orbType] ~= nil then
        requiredOrbID = ID[orbType]
        log("Required orb set to: " .. orbType)
    else
        log("Invalid orb type specified.")
    end
end

local function bank(location)
    log("Entering bank function...")
    local chestID = nil
    local bankerID = nil

    if location == 1 then
        chestID = nil
        bankerID = NPC_ID.Banker
    else
        log("Invalid bank location")
        return
    end

    local success, err = pcall(function()
        API.DoAction_Object1(0x2e, 80, { chestID }, 50)
        if bankerID then
            API.DoAction_NPC(0x5, 1488, { bankerID }, 50)  -- Needed for: Do.Action_NPC(0x5,1488,{ ID.Banker },50)
        end
        API.RandomSleep2(800, 750, 800)

        if not API.BankOpen2() then
            log("Reattempting Banking")
            bank(location)
            return
        else
            API.KeyboardPress32(0x31, 0) -- Press the 0x31 key (1)
            API.RandomSleep2(6000, 0, 0) -- Wait about 6 seconds
        end
    end)

    if not success then
        log("Error in bank function: " .. err)
        -- Add code to handle the error, e.g., retrying or ending the script
    end
end

local function scanInventoryForOrb(orbID)
    log("Scanning inventory for orb ID: " .. orbID)
    local itemCount = API.InvItemcount_1(orbID)
    log("Found " .. itemCount .. " of orb ID " .. orbID .. " in inventory.")
    return itemCount > 0
end

local function pressSpacebar()
    log("Pressing spacebar...")
    API.KeyboardPress2(0x20, 3000, 20) -- Press the space key (VK_SPACE) with a sleep time of 3 seconds and a randomness of 20%
end

API.SetDrawTrackedSkills(true)

-- Main loop
while API.Read_LoopyLoop() do
    local success, mainLoopErr = pcall(function()
        log("Entering main loop...")
        bank(1) -- Change the argument based on your bank location
        setRequiredOrb("Water_Orb") -- Change to the desired orb type
        if scanInventoryForOrb(requiredOrbID) then
            log("Orb found in inventory. Proceeding with crafting...")
            -- Add crafting logic here
        else
            log("Orb not found in inventory. Ending script.")
            API.Write_LoopyLoop(false) -- End the script if the required orb is not found
        end
        API.DoAction_Interface(0x24, 0x23f, 1, 1473, 5, 0, 3808) -- Open the interface needed to press spacebar
        pressSpacebar() -- Press spacebar after opening the interface
        API.RandomSleep2(16000, 0, 0) -- Wait for 16 seconds
    end)

    if not success then
        log("Error in main loop: " .. mainLoopErr)
        -- Add code to handle the error, e.g., retrying or ending the script
    end
end
