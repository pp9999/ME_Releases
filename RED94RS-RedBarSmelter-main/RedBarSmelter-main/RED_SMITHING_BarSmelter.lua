--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---   RED Bar Smelter 
--- ###########################################################
--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---  Initial Release
---    INSTRUCTIONS
---      - Have the ores in your metal bank (obviously)
---      - Must have bar selected (defaults to something random usually)
------ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
------ Options
--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--- False -> Will click the furnace to "Deposit all"
--- True  -> Will wait until the furnace interface is open and deposit all then
---     NOTE: If you're using 'Smithing Guantlets' just ignore this
local DEPOSIT_VIA_FURNACE = false

--- Logout when the script ends? (True or False)
---     Either on completion or failure. Doesn't matter
local LOGOUT_WHEN_SCRIPT_ENDS = false

----- Superheat form Options (is 1 tick faster per ore for accounts that have it)
--local SUPERHEAT_FORM = {
--    ENABLE = true,    -- Enable Superheat form? and all the stuff below this....
--    ENABLE_ANCIENT_ELVEN_SHARD = true,    -- Keep the elven shard activated?
--    ENABLE_PRAYER_RENEWAL_POTIONS = true, -- Drink Prayer Renewal Potions? (I'll probably just use the basic version's IDs)
--    ENABLE_PRAYER_POTIONS = true,         -- Drink Any Kind of Prayer Potions? (I'll add a bunch of IDs {Regular, Super, etc)
--    ENABLE_SUPER_RESTORE_POTIONS = true,  -- Drink Super restores for prayer points (Pots and Flasks)
--}



--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---   Script Information
--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---    FEATURES - v1.0
---      - Will work with or without 'Smithing Gauntlets'
---      - Will automatically stop if it fails to :
---             * deposit bars to furnace 3 times.
---             * initiate smelting process 3 times.
---             * can't click furnace 3 times.
---      - To check for if the player is smelting bars, it checks for:
---             * Player is processing
---             * VB State 2228 is greater than 0
---             * Player animation is greater than 0
---             * "Surely this will be enough.... Big sigh..."
---
---   TODO's
---      - Make the GUI not look terrible
---      - Push the bars per hour to the same GUI as XP/hr chart
---      - Will add Chat Safety Measures on request
---      - Will add "Superheat Form" support on request
---      - Will add "Scripture of Elidinis" support on request
---      - Will add XP Boosts support on request (expensive. Just use higgins Smithy script)
---      - Will add "Auras" support on request (Seems pointless)
---      - Will add "Summoning" support on request (Seems pointless)
---      - Will add "Prayer Renewal" support on request (Seems pointless)
---
---      - AutoMagically detect the best bar to smelt
---          * Either by level, or user inputted queue
---
--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--- ADVANCED SETTINGS
--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Lag Compensation
-- "Determining if the player is smelting bars is a bit buggy, so
--    this repeats a check with waits in between 'this' many times.
--    8-12 seems to be a good value even on busy, laggy worlds. 
--    Larger probably means faster smithing, but unnecessary clicks.
local LAG_COMPENSATION = 10





--- EVERYTHING BELOW THIS LINE IS THE SCRIPT 
--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local SCRIPT_NAME    = "RED Bar Smelter"
local SCRIPT_VERSION = "1.0"
local SCRIPT_SKILL   = "SMITHING"

--- REQUIRED APIs
local API = require("api")
local UTILS = require("utils") -- Dead's UTIL library (Thank you very much sir)

--- OPTIONAL APIs
--local API_SoE = require("api_ScriptureOfElidinis") -- My library
--local API_SUMMONING = require("api_summoning")     -- My library
--local API_AURAS = require("api_auras")             -- My library
--local API_XPBOOSTS = require("api_xpboosts")       -- My library

-- Random IDs. 'Some may not even be used....'
local IDs = {
    OBJs = {
        FURNACE = 113266,
    },
    ANIMs = {
        SMELTING_BARS = 32626
    }
}

-- These are the settings for the selected bar. Not currently implemented
local BAR_SELECT = {
    MTIHRIL = 2359,
    ADAMANT = 2361,
    RUNE = 2363,
    OLK = 44838,
    NECRO = 44840
}

-- List of Fail Counters for different parts of the script
local FAIL_COUNT = {
    DepositingToFurnace = 0,
    GettingTheSmithInterfaceToOpen = 0,
    GettingTheSmithInterfaceToClose = 0,
    ClickingAnyAvailableForge = 0,
    DepositingToInterface = 0
}

-- GUI Stuff (Pretty sure stolen from Dead, Thank you!) 
--#region VARIABLES
local startXP = API.GetSkillXP(SCRIPT_SKILL);
local stateXp = startXP;
local noXpGainTick = 0;

-- Draws the black background
local imguiBackground = API.CreateIG_answer();
local xstart = 50
local ystart = 50
imguiBackground.box_name = "ImguiBackground"
imguiBackground.box_start = FFPOINT.new(xstart, ystart, 0)
imguiBackground.box_size = FFPOINT.new(250, 120, 0)
imguiBackground.colour = ImColor.new(10, 13, 29)

local ImGuiTitle = API.CreateIG_answer()
ImGuiTitle.box_start = FFPOINT.new(xstart + 5, ystart + 5, 0)
ImGuiTitle.colour = ImColor.new(255, 0, 0)
ImGuiTitle.string_value = SCRIPT_NAME .. " " .. SCRIPT_VERSION
--#endregion


-- Draws the imgui objects to the screen
local function drawMetrics()
    local xpGained = API.GetSkillXP(SCRIPT_SKILL) - stateXp;
    API.DrawSquareFilled(imguiBackground)
    ImGuiTitle.string_value = SCRIPT_NAME .. SCRIPT_VERSION ..
            "\n" .. API.ScriptRuntimeString() ..
            "\n" .. "Bars Collected : *Soon*"
    API.DrawTextAt(ImGuiTitle)
    if xpGained > 0 then
        stateXp = stateXp + xpGained;
        noXpGainTick = 0;
    else
        noXpGainTick = noXpGainTick + 1;
    end
end





--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---  Script Functions
--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




--- Determines if the smithing interface is open
---      NOTE: Here because I'm dumb and can't figure out Lua function references
--- @return boolean true if the smithing interface is open
function isSmithingInterfaceOpen()
    return API.Compare2874Status(85, false)
end




--- Determines if the smithing interface is closed
---      NOTE: Here because I'm dumb and can't figure out Lua function references
--- @return boolean true if the smithing interface is closed
function isSmithingInterfaceClosed()
    return not isSmithingInterfaceOpen()
end




--- Determines if the player's inventory is empty
---      NOTE: Here because I'm dumb and can't figure out Lua function references
--- @return boolean true if the player's inventory is empty
function isInventoryEmpty()
    return Inventory:IsEmpty()
end

--- Game state checks, to ensure the script is still running
--- Stole this from Dead's library. I'm sure he won't mind.
--- Works well for this script
--- @return boolean true if the script should stop because of no xp gain
local function gameStateChecks()
    UTILS.gameStateChecks()
    if noXpGainTick > 30 then
        API.logError('Not gaining xp, exiting')
        print('Not gaining xp')
        API.Write_LoopyLoop(false)
    end
end


--- Gets the quantity of bars in the smelting queue from VB State 2228
---     NOTE: Seems to only update if the smelting interface is opened
---     NOTE: Seems to be a pretty safe way to add anti-ban for clicking the make button
--- @return number the quantity of bars in the smelting queue
local function vb_getBarSmeltingQueueQuantity()
    return API.VB_FindPSettinOrder(2228, 0).state
end




--- Gets the quantity of bars in the project selection from VB State 8336
---     NOTE: Seems to only update if the smelting interface is opened
---     NOTE: Seems to be a pretty safe way to add anti-ban for clicking the make button
--- @return number the quantity of bars in the project selection menu (0-28ish)
local function vb_getBeginProjectSelectionQuantity()
    return API.VB_FindPSettinOrder(8336, 0).state
end




--- Determines if the project quantity is showing no materials are available
---     * Same as saying "We can't make bars..."
--- @return boolean true if the project quantity is showing no materials
local function isProjectQuantityShowingNoMaterials()
    return vb_getBeginProjectSelectionQuantity() == 0
end




--- Clicks the furnace object to begin the smelting process
---    * Handles dynamic waiting for the player to stop walking
---    * Handles dynamic waiting for interface to open
---    * If failed, increments the fail counter
--- @return boolean true if the player successfully clicked the furnace
local function click_object_furnace()
    --print("Clicking furnace")
    API.DoAction_Object_string1(0x3a, API.OFF_ACT_GeneralObject_route0, { "Furnace" }, 50, true)
    API.RandomSleep2(800, 400, 600)
    API.WaitUntilMovingEnds()
    if not UTILS.SleepUntil(isSmithingInterfaceOpen, 3000, "Smithing interface open.") then
        FAIL_COUNT.GettingTheSmithInterfaceToOpen = FAIL_COUNT.GettingTheSmithInterfaceToOpen + 1
        return false
    end
    return true
end




--- Clicks the interface to begin the project
---    * Handles dynamic waiting for interface to close
---    * If failed, increments the fail counter
--- @return boolean true if the player successfully clicked the interface and it closes
local function click_iface_beginProject()
    --print("Clicking interface begin project")
    if not isSmithingInterfaceOpen() then
        print("Smithing Interface is not open. Not good....")
        FAIL_COUNT.GettingTheSmithInterfaceToClose = FAIL_COUNT.GettingTheSmithInterfaceToClose + 1
        return false
    end
    if isProjectQuantityShowingNoMaterials() then
        print("The Smithing Interface is Open, but VBs say that there isn't materials available for the selected bar.")
        print("Not good....")
        FAIL_COUNT.GettingTheSmithInterfaceToClose = FAIL_COUNT.GettingTheSmithInterfaceToClose + 1
        return false
    end
    API.DoAction_Interface(0x24,0xffffffff,1,37,163,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(800, 400, 600)
    if not UTILS.SleepUntil(isSmithingInterfaceClosed, 3000, "Smithing interface closed. Should be smithing...") then
        FAIL_COUNT.GettingTheSmithInterfaceToClose = FAIL_COUNT.GettingTheSmithInterfaceToClose + 1
        return false
    end
    return true
end




--- Deposits all bars to the furnace
---    * Handles dynamic waiting for the player to stop walking
---    * Handles dynamic waiting for the inventory to empty
---    * If failed, increments the fail counter
--- @return boolean true if the player successfully deposited all bars to the furnace
local function action_depositBarsToFurnace()
    --print("Depositing bars to furnace")
    Interact:Object("Furnace", "Deposit-all (into metal bank)", 50)
    API.RandomSleep2(800, 400, 600)
    API.WaitUntilMovingEnds()
    if not UTILS.SleepUntil(isInventoryEmpty, 3000, "Deposited bars to furnace.") then 
        FAIL_COUNT.DepositingToFurnace = FAIL_COUNT.DepositingToFurnace + 1
        return false
    end
end




--- Clicks the interface to deposit all bars in the smelting interface
---    * Handles dynamic waiting for the inventory to empty
---    * If failed, increments the fail counter
--- @return boolean true if the player successfully deposited all bars to the furnace
local function click_interface_depositAllBarsInSmeltingInterface()  
    --print("Clicking interface deposit all bars in smelting interface")
    API.DoAction_Interface(0x24,0xffffffff,1,37,167,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(800, 400, 600)
    if not UTILS.SleepUntil(isInventoryEmpty, 3000, "Deposited bars to furnace.") then
        FAIL_COUNT.DepositingToInterface = FAIL_COUNT.DepositingToInterface + 1
        return false
    end
    return true
end




--- Determins if the player is currently smelting bars via many methods
--- @return boolean true if the player is smelting bars
local function isPlayerSmeltingBars()
    for i = 1, LAG_COMPENSATION do          -- Lag Compensation is implemented here
        if API.isProcessing() then
            return true
        end
        if vb_getBarSmeltingQueueQuantity() > 0 then
            print("Player is processing did not register for some reasion. Using VB instead...")
            print("Player is smelting bars : VB State 2228: " .. vb_getBarSmeltingQueueQuantity())
            return true
        end
        if API.ReadPlayerAnim() > 0 then
            print("Player is processing did not register for some reasion. Using Player Animation instead...")
            print("Player is smelting bars : Animation: " .. API.ReadPlayerAnim())
            return true
        end
        API.RandomSleep2(100, 100, 100)
    end
end



local function click_closeSmithingInterface()
    if isSmithingInterfaceOpen() then
        API.DoAction_Interface(0x24,0xffffffff,1,37,42,-1,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(2000, 1000, 600)
    end
    return not isSmithingInterfaceOpen()
end



--- Fail safe checks to ensure the script doesn't get stuck in a loop
local function checkFailSafeCounters()
    if FAIL_COUNT.DepositingToFurnace > 3 then
        print("Failed to deposit bars to furnace too many times. Ending script.")
        API.Write_LoopyLoop(false)
    end
    if FAIL_COUNT.GettingTheSmithInterfaceToOpen > 3 then
        print("Failed to open smithing interface too many times. Ending script.")
        API.Write_LoopyLoop(false)
    end
    if FAIL_COUNT.GettingTheSmithInterfaceToClose > 3 then
        print("Failed to close smithing interface too many times. Ending script.")
        API.Write_LoopyLoop(false)
    end
    if FAIL_COUNT.ClickingAnyAvailableForge > 3 then
        print("Failed to click any available forge too many times. Ending script.")
        API.Write_LoopyLoop(false)
    end
end


--- Gets called at the begining of the script to do initial checks
--- @return boolean true if the script should continue
local function onStart()
    API.logWarn(SCRIPT_NAME .. " Started!")
    return true  
end

--- Main function of the script to repeat
local function main()
    if isPlayerSmeltingBars() then
        API.RandomSleep2(50,0,500)
    else
        if Inventory:IsFull() then 
            if isSmithingInterfaceOpen() then
                click_interface_depositAllBarsInSmeltingInterface()
                API.RandomSleep2(800, 500, 500)
            else
                if (DEPOSIT_VIA_FURNACE) then
                    action_depositBarsToFurnace()
                    API.RandomSleep2(800, 500, 500)
                else
                    click_object_furnace()
                    API.RandomSleep2(800, 500, 500)
                end
            end
        else
            if isSmithingInterfaceOpen() then
                --if not Inventory:IsFull() and not isProjectQuantityShowingNoMaterials() then
                --    print("The Smithing Interface is Open, but VBs say that there isn't materials available for the selected bar.")
                --    print("Ending the script from here...  ‧༼☯﹏☯༽")
                --    API.Write_LoopyLoop(false)
                --end
                click_iface_beginProject()
                API.RandomSleep2(800, 500, 500)
            else
                click_object_furnace()
                API.RandomSleep2(800, 500, 500)
            end
        end
    end
end

--- Gets called at the end of the script to do final checks and goodbyes
local function onFinish()
    if isSmithingInterfaceOpen() then
        print("Closing Smithing Interface before closing down the script.")
        if not click_closeSmithingInterface() then
            print("Failed to close the Smithing Interface. Disabling logout at the end of the script.")
        end
    end
    if LOGOUT_WHEN_SCRIPT_ENDS then
        API.DoAction_then_lobby()
        API.RandomSleep2(2000, 150, 150)
    end
    API.logWarn(SCRIPT_NAME .. " Done!")
    API.SetDrawTrackedSkills(false)
end

local xpEvents = 0

--- Update all the GUIs and progress tracking
---     RIP RSBot.....
local function onRepaint()
    drawMetrics()
    
    local lastEvent = API.GatherEvents_xp_check()

    if lastEvent then
        if lastEvent.skillName then
            if lastEvent.skillName == SCRIPT_SKILL then
                xpEvents = xpEvents + 1
               -- print("XP Event: " .. xpEvents)
            end
        end
    end
    
end

-- Main Loop

API.Write_LoopyLoop(onStart())
API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    onRepaint()
    API.DoRandomEvents()
    checkFailSafeCounters()
    if gameStateChecks() then
        print("Game state checks failed. Ending script.")
        break
    end
    main()
    API.RandomSleep2(800, 500, 1000)
end
onFinish()
    
