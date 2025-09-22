--[[
    Title: Portable Stringer Script
    Original Author: Mr.frank
    Current Maintainer: Mr.frank

    Description:
    This script automates bow stringing using portable fletchers in RuneScape.
    Features include bank withdrawal, inventory management, and anti-idle functions.

    Optimization and recalibration powered by AI assistance.

    Contributions and improvements are welcome!

-- DESCRIPTION
* Have unstrung bows and bowstrings in bank
* Start script near a bank or portable fletcher
* Fort forinthry Start positions
* Configure MAX_IDLE_TIME_MINUTES for anti-logout timing
* X items in Bank should be set to 14 
* required Dead utils

--Changelog:

Version: 1.0
  Date: 2025-04-01
  Changes:
    - Initial version with basic fletching functionality
    - Added bank withdrawal system for unstrung bows and bowstrings
    - Implemented anti-idle function to prevent logout

Version: 1.1
  Date: 2025-04-02
  Changes:
    - Improved withdrawal logic to prevent duplicate actions
    - Added inventory status tracking
    - Enhanced sleep timers to prevent spamming

Version: 1.2
  Date: 2025-04-03
  Changes:
    - Consolidated IDS definitions and removed duplicates
    - Rewrote main loop to remove redundant checks
    - Added proper error handling for bank operations

Version: 1.3
  Date: 2025-04-04
  Changes:
    - Added formatted inventory display showing remaining items
    - Improved withdrawal messages with clearer status
    - Optimized sleep timers between actions

Version: 1.4
  Date: 2025-04-05
  Changes:
    - Combined unstrung and bowstring withdrawals into single operation
    - Added depletion messages for item types
    - Enhanced anti-idle timing with random intervals
--]]

-- =============================================
-- SECTION 1: INITIALIZATION AND CONFIGURATION
-- =============================================

-- Load required libraries
local API = require("api")
local UTILS = require("utils")

-- Configure script settings
API.SetDrawTrackedSkills(true)  -- Show skill progress
API.Write_LoopyLoop(true)      -- Enable main loop

-- Script constants
local MAX_IDLE_TIME_MINUTES = 5    -- Max idle time before anti-logout
local MAX_ATTEMPTS = 3             -- Max attempts for actions
local processingTimeout = 30       -- Timeout for processing (seconds)

-- Portable object IDs
local Porta_ID = {
    FLETCHER = 106598,
    BANK_CHEST = 79036,
    WORKROOM_BANK_CHEST = 125734
}

-- Global variables
local afk = os.time()              -- Last active time
local unstrungTable = {}           -- Stores unstrung bow data
local bowstringTable = {}          -- Stores bowstring data

-- SECTION 2: UTILITY FUNCTIONS
-- =============================================

-- Anti-idle function to prevent logout
local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)
    
    if timeDiff > randomTime then
        print("Performing anti-idle action...")
        API.PIdle2()
        afk = os.time()
    end
end

-- Safety check to ensure script should continue
-- Update the Loppy function to return status instead of error
local function Loppy()
    if not API.Read_LoopyLoop() then
        print("Script termination requested")
        return false
    end
    return true
end

-- Update the stringing function to handle Loppy's return value
local function stringing()
    print("Attempting to string bows...")
    if not Loppy() then return false end
    
    local attempts = 0
    repeat
        if API.DoAction_Object1(0xcd, API.OFF_ACT_GeneralObject_route2, {Porta_ID.FLETCHER}, 50) then
            UTILS.randomSleep(800, 1200, 1500)
            
            if API.Compare2874Status(18) then
                print("Fletching interface opened")                
                API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1370, 30, -1, API.OFF_ACT_GeneralInterface_Choose_option)
                return true
            end
        end
        
        attempts = attempts + 1
        print(string.format("Stringing attempt %d/%d", attempts, 3))
        API.RandomSleep2(1000, 500, 1000)
    until API.isProcessing() or not Loppy() or attempts >= 3
    print("Stringing started...")
    return false
end

-- Update the openBank function's Loppy call
local function openBank()
    print("Attempting to open bank...")
    if not API.BankOpen2() then
        local attempts = 0
        repeat
            if not API.DoAction_NPC(0x5, API.OFF_ACT_InteractNPC_route, {3418}, 50) then  
                API.DoAction_Object_string1(0x2e, API.OFF_ACT_GeneralObject_route1, {"Bank chest"}, 20, true) 
            end
            UTILS.randomSleep(1800)
            attempts = attempts + 1
            if not Loppy() then return false end
            print(string.format("Bank open attempt %d/%d", attempts, 5))
        until API.BankOpen2() or attempts > 5
        return API.BankOpen2()
    end
    return true
end

-- Fetches unstrung items and bowstrings from bank
local function fetchUnstrungItems()
    print("Fetching items from bank...")
    unstrungTable = {}
    bowstringTable = {}
    
    -- Only proceed if bank is open
    if not API.BankOpen2() then
        print("Bank not open, cannot fetch items")
        return false
    end
    
    local bankItems = API.FetchBankArray()
    if not bankItems or #bankItems == 0 then 
        print("Warning: No items found in bank!")
        return false 
    end
    
    -- Process bank items
    local unstrungLookup = {}
    local bowstringLookup = {}
    
    for _, item in ipairs(bankItems) do
        if item.textitem then
            local cleanName = string.gsub(item.textitem, "<col=%x%x%x%x%x%x>", "")
            local size = item.itemid1_size or 0
            
            if string.find(cleanName, "unstrung") and size > 0 then
                unstrungLookup[cleanName] = unstrungLookup[cleanName] or {name = cleanName, id = item.itemid1, size = 0}
                unstrungLookup[cleanName].size = unstrungLookup[cleanName].size + size
            elseif string.find(cleanName, "Bowstring") and size > 0 then
                bowstringLookup[cleanName] = bowstringLookup[cleanName] or {name = cleanName, id = item.itemid1, size = 0}
                bowstringLookup[cleanName].size = bowstringLookup[cleanName].size + size
            end
        end
    end
    
    -- Convert lookup tables to arrays
    for _, item in pairs(unstrungLookup) do table.insert(unstrungTable, item) end
    for _, item in pairs(bowstringLookup) do table.insert(bowstringTable, item) end
    
    -- Sort by quantity for efficient withdrawal
    table.sort(unstrungTable, function(a, b) return a.size < b.size end)
    table.sort(bowstringTable, function(a, b) return a.size < b.size end)
    
    print(string.format("Found %d unstrung items and %d bowstrings", #unstrungTable, #bowstringTable))
    return true
end

-- Withdraws fletching materials from bank
local initialXWithdrawalDone = false  -- Track only X withdrawal

local function withdrawFletchingItems()
    print("Withdrawing fletching items...")
    Loppy()
    
    -- Only proceed if bank is open
    if not API.BankOpen2() then
        print("Bank not open, cannot withdraw items")
        return false
    end
    
    -- Deposit inventory if full
    if API.Invfreecount_() < 28 then
        print("Inventory full, depositing items...")
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 517, 39, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 1200, 1500)
    end
    
    -- Refresh item list if empty
    if #unstrungTable == 0 or #bowstringTable == 0 then 
        print("Item tables empty, refreshing from bank...")
        if not fetchUnstrungItems() then
            return false
        end
    end
    
    -- Print inventory status
    print("\nUnstrung Items Inventory:")
    print("---------------------------------")
    print("| Item Name           | Remaining |")
    print("---------------------------------")
    for i, item in ipairs(unstrungTable) do
        if i == 1 then
            print(string.format("| *%-18s | %-9d | <-- Next", item.name, item.size))
        else
            print(string.format("| %-18s | %-9d |", item.name, item.size))
        end
    end
    print("---------------------------------")
    
    if #bowstringTable > 0 then
        print(string.format("\nBowstrings remaining: %d", bowstringTable[1].size))
    end
    
    -- Withdraw items X (only once)
    if not initialXWithdrawalDone then
        API.DoAction_Interface(0x2e, 0xffffffff, 1, 517, 106, -1, API.OFF_ACT_GeneralInterface_route)
        initialXWithdrawalDone = true
        API.RandomSleep2(1500, 1500, 1000)
    end
    
    -- Modified withdrawal logic to handle <14 items
    local unstrungItem = unstrungTable[1]
    local bowstringItem = bowstringTable[1]
    
    if unstrungItem and unstrungItem.size > 0 and bowstringItem and bowstringItem.size > 0 then
        local withdrawAmount = math.min(14, unstrungItem.size, bowstringItem.size)
        print(string.format("\nWithdrawing %d %s and %d %s", 
            withdrawAmount, unstrungItem.name, 
            withdrawAmount, bowstringItem.name))
        
        -- Withdraw unstrung item
        API.DoAction_Bank(unstrungItem.id, 1, API.OFF_ACT_GeneralInterface_route)
        unstrungItem.size = unstrungItem.size - withdrawAmount
        if unstrungItem.size <= 0 then 
            table.remove(unstrungTable, 1)
            print("This type of unstrung item is now depleted")
        end
        API.RandomSleep2(1000, 500, 1000)
        
        -- Withdraw bowstring
        API.DoAction_Bank(bowstringItem.id, 1, API.OFF_ACT_GeneralInterface_route)
        bowstringItem.size = bowstringItem.size - withdrawAmount
        if bowstringItem.size <= 0 then 
            table.remove(bowstringTable, 1)
            print("This type of bowstring is now depleted")
        end
        
        API.RandomSleep2(1000, 500, 1000)
    end
    
    -- Close bank
    API.DoAction_Interface(0x24, 0xffffffff, 1, 517, 318, -1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(500, 500, 1000)
    return true
end

-- SECTION 4: FLETCHING FUNCTIONS
-- =============================================

-- Checks if required items are in inventory
local function hasRequiredItems()
    print("Checking inventory for required items...")
    local hasUnstrung = false
    local hasBowstring = false
    
    local invItems = API.ReadInvArrays33() or {}
    for _, item in ipairs(invItems) do
        if item and item.textitem then
            local cleanName = string.gsub(item.textitem, "<col=%x%x%x%x%x%x>", "")
            if string.find(cleanName, "unstrung") then
                hasUnstrung = true
            elseif string.find(cleanName, "Bowstring") then
                hasBowstring = true
            end
            if hasUnstrung and hasBowstring then break end
        end
    end
    
    print(string.format("Inventory check: Unstrung=%s, Bowstring=%s", tostring(hasUnstrung), tostring(hasBowstring)))
    return hasUnstrung and hasBowstring
end

-- Strings bows using portable fletcher
local function stringing()
    print("Attempting to string bows...")
    Loppy()
    local attempts = 0
    
    repeat
        if API.DoAction_Object1(0xcd, API.OFF_ACT_GeneralObject_route2, {Porta_ID.FLETCHER}, 50) then
            UTILS.randomSleep(800, 1200, 1500)  -- Added sleep after fletcher interaction
            
            if API.Compare2874Status(18) then
                print("Fletching interface opened")                
                API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1370, 30, -1, API.OFF_ACT_GeneralInterface_Choose_option)
             
                return true
            end
        end
        
        attempts = attempts + 1
        print(string.format("Stringing attempt %d/%d", attempts, 3))
        API.RandomSleep2(1000, 500, 1000)
    until API.isProcessing() or not API.Read_LoopyLoop() or attempts >= 3
    print("Stringing started...")
    return false
end

-- SECTION 5: MAIN LOOP
-- =============================================

print("=== Portable Fletcher Script Started ===")
API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    idleCheck()
    
    -- Check and replenish inventory
    if not hasRequiredItems() then
        print("Missing materials, visiting bank...")
        if not openBank() or not withdrawFletchingItems() then
            print("Error: Failed to get required items")
            API.Write_LoopyLoop(false)
            break
        end
    end
    
    -- Perform fletching
    if not stringing() then
        print("Error: Failed to start stringing")
        API.Write_LoopyLoop(false)
        break
    end
    
    -- Wait for completion
    print("Waiting for fletching to complete...")
    local start = os.time()
    while API.isProcessing() or API.CheckAnim(50) do
        if os.time() - start > processingTimeout then
            print("Warning: Processing timeout reached")
            API.Write_LoopyLoop(false)
            break
        end
        API.RandomSleep2(1000, 500, 1000)
    end
    
    API.RandomSleep2(500, 500, 1000)
end

print("=== Script Finished ===")

