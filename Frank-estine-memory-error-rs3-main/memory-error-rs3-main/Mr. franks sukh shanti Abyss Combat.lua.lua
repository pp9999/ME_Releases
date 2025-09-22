--[[ 
    Title: Mr. Frank's Combat Abyss Script
    Original Author: Mr. Frank
    Current Maintainer: Mr. Frank

    Description:
    This script integrates functionalities from 'Dead Slayer' modules, 
    --offering enhanced debugging capabilities 
    -- and kill-script mechanics.

    Optimization and recalibration powered by AI assistance.

    Contributions and improvements are welcome!


-- DESCRIPTION
* Have food in inventory and put "Eat food" ability on ability bar
* Put War's Retreat teleport on ability bar
* Configure custom loot button in RS3 settings, or set LOOT to nil to disable looting
* Start script AFTER entering the Abyss is recommended, but navigation is included.
* Drop Script Dont work.

--Changelog:

Version:
  Date: 2024-07-24
  Changes:
    - Initial version with debug messages and Abyssal NPC checks.
    - Added player movement/animation checks.
    - Added check for player movement and animation in maintainHealth function

Version:
  Date: 2024-07-24
  Changes:
    - Fixed chargePackCheck scope.

Version:
  Date: 2024-07-24
  Changes:
    - Fixed moveToTrainingSpot argument.

Version:
  Date: 2024-07-24
  Changes:
    - Added War's Retreat banking and script restart logic to walktoabyss_debug.
    - Added prayer and elven shard

Version:
  Date: 2025-04-07
  Changes:
    - Consolidated IDS definitions and removed duplicates.
    - Rewrote main loop to remove goto statements and fix scoping issues.
    - Replaced loot function with new categorized system including bury bones.

Version:
  Date: 2025-07-24
  Changes:
    - Improved prayer toggle logic with better state tracking.
    - Updated loot tables and added more item categories.
    - Enhanced Excalibur activation timing with random intervals.

Version:
  Date: 2025-07-25
  Changes:
    - Further optimized prayer state tracking and toggle logic.
    - Expanded loot categories with additional item IDs.
    - Improved loot prioritization and cooldown handling.
--]]



-- == USER CONFIGURATION SECTION ==
-- Basic Settings
local MAX_IDLE_TIME_MINUTES = 10  -- Maximum idle time before script stops
local LOOT = true -- Set to nil to disable looting
local buryBonesEnabled = false -- Set to false to disable bone burying
local DEBUG_LEVEL = 0 -- 0=Off, 1=Important, 2=All

-- NPC Settings
local NPCS = { 2265, 2264, 2263 } -- Abyssal Walker, Leech, Guardian
local MAGE_OF_ZAMORAK_ID = 2257

-- Location Settings
local SAFE_SPOT = FFPOINT.new(3048, 4805, 0)
local EDGEVILLE_SOUTH_OF_DITCH = FFPOINT.new(3101, 3520, 0)
local WILDERNESS_NORTH_OF_DITCH_CROSS = FFPOINT.new(3102, 3549, 0)
local WILDERNESS_NEAR_MAGE_AREA = FFPOINT.new(3101, 3551, 0)
local WAR_RETREAT_BANK_AREA = FFPOINT.new(3294, 10127, 0)

-- Recommended Inventory Preset
local INVENTORY_PRESET = {
    --[[Food
    {id = 391, quantity = 28},  -- Rocktail
    
    -- Potions
    {id = 2434, quantity = 4},  -- Prayer potion (4)
    {id = 15312, quantity = 2}, -- Super restore (4)
    {id = 15308, quantity = 2}, -- Super combat potion (4)
    
    -- Teleports
    {id = 42329, quantity = 1},  -- War's retreat teleport
    {id = 42327, quantity = 1},  -- Max guild teleport
    
    -- Utility
    {id = 43358, quantity = 1}, -- Elven shard
    {id = 35, quantity = 1},    -- Excalibur
    {id = 30372, quantity = 10} -- Notepaper]]
}

-- Change Equipment Preset ---Random AI GEnerated shit--++++++++++++++++++++++++++++++++++---------------------------------------
local EQUIPMENT_PRESET = {
    --[[ Weapons
    {slot = 0, id = 4151},  -- Abyssal whip
    {slot = 1, id = 1377},  -- Dragon dagger
    
    -- Armor
    {slot = 4, id = 4712},  -- Ahrim's robetop
    {slot = 5, id = 4714},  -- Ahrim's robeskirt
    {slot = 6, id = 4710},  -- Ahrim's hood
    {slot = 7, id = 7462},  -- Barrows gloves
    {slot = 9, id = 6583},  -- Amulet of fury
    {slot = 10, id = 10462}, -- Ava's accumulator
    {slot = 12, id = 6737}, -- Berserker ring
    
    -- Aura  - not working
    {slot = 11, id = 23873}, -- Saradomin aura
    {slot = 12, id = 23872}, -- Zamorak aur
    {slot = 13, id = 23874} -- Vampyrism aura]]
}

-- Training Spots
local TRAINING_DATA = {
    {
      trainingSpots = {
        FFPOINT.new(3030 + math.random(-3, 3), 4809 + math.random(-3, 3), 0),
        FFPOINT.new(3029 + math.random(-3, 3), 4809 + math.random(-3, 3), 0),
        FFPOINT.new(3032 + math.random(-3, 3), 4809 + math.random(-3, 3), 0)
      },
      resetSpot = {3019 + math.random(-3, 3), 4844 + math.random(-3, 3)},
    },
    {
      trainingSpots = {
        FFPOINT.new(3059 + math.random(-3, 3), 4812 + math.random(-3, 3), 0),
        FFPOINT.new(3059 + math.random(-3, 3), 4814 + math.random(-3, 3), 0),
        FFPOINT.new(3057 + math.random(-3, 3), 4813 + math.random(-3, 3), 0)
      },
      resetSpot = {3058 + math.random(-3, 3), 4844 + math.random(-3, 3)},
    },
}

-- Item IDs
IDS = {
    EXCALIBUR = 35,
    ELVEN_SHARD = 43358
}

local ITEMS = {}
ITEMS.COMMON = {
    995,    -- Coins
    830,    -- Rune dagger
    560,    -- Death rune
    54917,  -- Spirit weed seed
    385,    -- Raw shark
    3028,   -- Super restore (4)
    1780,   -- Flax
    42008,  -- Bloodweed seed
    4099,   -- Mithril ore
    4107    -- Adamantite ore
}

ITEMS.RUNES = {
    554,    -- Fire rune
    555,    -- Water rune
    556,    -- Air rune
    557,    -- Earth rune
    565     -- Blood rune
}

ITEMS.HERBS = {
    21626,  -- Fellstalk seed
    48243,  -- Arbuck seed
    219,    -- Grimy guam
    217,    -- Grimy marrentill
    2485,   -- Grimy tarromin
    215,    -- Grimy harralander
    3051,   -- Grimy ranarr
    37975,  -- Grimy bloodweed
    213,    -- Grimy irit
    14836,  -- Grimy kwuarm
    12174,  -- Grimy cadantine
    3049,   -- Grimy lantadyme
    207,    -- Grimy dwarf weed
    201     -- Grimy avantoe
}

ITEMS.BONES = {
    35010,  -- Dragon bones
    3123,   -- Big bones
    4834,   -- Babydragon bones
    35008,  -- Dagannoth bones
    18832,  -- Frost dragon bones
    30209,  -- Reinforced dragon bones
    6812,   -- Wyvern bones
    48075,  -- Dragonkin bones
    51858,  -- Superior dragon bones
    4832,   -- Wyrm bones
    6729,   -- Dagannoth bones
    4830,   -- Wyrm bones
    2859,   -- Bones
    536,    -- Dragon bones
    4812,   -- Wyvern bones
    530,    -- Dragon bones
    534,    -- Big bones
    528,    -- Bones
    526,    -- Bones
    532,    -- Babydragon bones
    3125    -- Big bones
}

ITEMS.ASHES = {
    34159,  -- Impious ashes
    33260,  -- Accursed ashes
    20268,  -- Infernal ashes
    20266,  -- Seared ashes
    20264   -- Fiendish ashes
}

ITEMS.ARROWS = {
    892     -- Rune arrow
}

ITEMS.CHARMS = {
    12158,  -- Gold charm
    12159,  -- Green charm
    12160,  -- Crimson charm
    12163   -- Blue charm
}

-- == 1. LIBRARIES AND GLOBAL SETTINGS ==
local API = require("api")
local LODESTONES = require("lodestones")

API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)
math.randomseed(os.time())

-- Define UTILS if not provided by environment
local UTILS = {
    concatenateTables = function(...)
        local result = {}
        for _, tbl in ipairs({...}) do
            for _, v in ipairs(tbl) do
                table.insert(result, v)
            end
        end
        return result
    end,
    randomSleep = function(ms)
        API.RandomSleep2(ms, ms // 5, ms // 5)
    end
}

local buryBonesEnabled = true
local bonesId = ITEMS.BONES -- Now properly defined as a table
local itemIdsToLoot = UTILS.concatenateTables(
    ITEMS.COMMON,
    ITEMS.RUNES,
    ITEMS.CHARMS
)
local lastLootTime = os.time()
local nextLootDelay = math.random(120, 180)

-- == 4. UTILITY FUNCTIONS ==
local function ShouldStopScript()
    if not API.Read_LoopyLoop(false) then
        if DEBUG_LEVEL > 0 then print("Stop request detected.") end
        return true
    end
    return false
end

local function chargePackCheck()
    local chatTexts = API.GatherEvents_chat_check()
    for _, v in ipairs(chatTexts) do
        if string.find(v.text, "Your charge pack has run out of power") then
            if DEBUG_LEVEL > 0 then print("Charge pack is empty!") end
            API.DoAction_Ability("Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
            API.Write_LoopyLoop(false)
            return
        end
    end
end


local inventoryItems = {}
local function updateInventoryItems()

-- Print item table for debugging
if DEBUG_LEVEL > 0 then
    print("\nItem List:")
    print("Type\t\tID")
    print("--------------------------------")
    for category, items in pairs(ITEMS) do
        for _, id in ipairs(items) do
            print(category.."\t\t"..id)
        end
    end
end
    local inventory = Inventory:GetItems()
    for i = 1, #inventory do
        local item = inventory[i]
        local exists = false
        for j = 1, #inventoryItems do
            if inventoryItems[j] == item then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(inventoryItems, item)
        end
    end
    return true
end

updateInventoryItems()

-- Print item table for debugging
if DEBUG_LEVEL > 0 then
    print("\nItem List:")
    print("Type\t\tID")
    print("--------------------------------")
    for category, items in pairs(ITEMS) do
        for _, id in ipairs(items) do
            print(category.."\t\t"..id)
        end
    end
end

local lastExcaliburUse = os.time() -- Track the last time Excalibur was used
local EXCALIBUR_INTERVAL = 305 -- Base interval in seconds (5 minutes 5 seconds)
local player = API.GetLocalPlayerName()
local lastExcaliburDebugTime = 0 -- Track last debug message time



local function openBank()
    if not API.BankOpen2() then
        
        if DEBUG_LEVEL > 1 then print("[DEBUG] Opening bank") end

        local attempts = 0

        repeat
            API.DoAction_Object_string1(0x2e, API.OFF_ACT_GeneralObject_route1, {"Bank chest"}, 20, true)
            API.RandomSleep2(1500, 1000, 2000)
            attempts = attempts + 1
        until API.BankOpen2() or attempts > 5

        if API.BankOpen2() then
            API.DoAction_Interface(0x24, 0xffffffff, 1, 517, 119, 9, API.OFF_ACT_GeneralInterface_route)
            if DEBUG_LEVEL > 1 then print("[DEBUG] Bank opened successfully") end
            -- Wait for preset to load before updating inventory
            API.RandomSleep2(2000, 500, 1000)
            updateInventoryItems()
        else
            if DEBUG_LEVEL > 0 then print("[ERROR] Failed to open bank after " .. attempts .. " attempts") end
            return false
        end

-- Print item table for debugging
if DEBUG_LEVEL > 0 then
    print("\nItem List:")
    print("Type\t\tID")
    print("--------------------------------")
    for category, items in pairs(ITEMS) do
        for _, id in ipairs(items) do
            print(category.."\t\t"..id)
        end
    end
end
    end
  

end



local function maintainHealth()
    
local lastPrayerCheckTime = nil
local lastPrayer = nil
local prayerActive = false
local prayerCooldown = os.time()
local prayerUnchangedStart = os.time()
local lastExcaliburDebugTime = os.time()


    if API.IsInCombat_(player) and abysss then
       
        API.RandomSleep2(100, 50, 100) -- Add small delay to prevent rapid polling
        local hp = API.GetHPrecent()
        local prayer = API.GetPrayPrecent()
        local prayerCooldown = false -- Simplified cooldown check
        local prayerUnchangedStart = os.time()
        if hp < 80 and not prayerActive and not prayerCooldown then
            -- Check if the current prayer is the same as the last one
            if lastPrayer == prayer then
            end
        end
        local excalCD = API.DeBuffbar_GetIDstatus(IDS.EXCALIBUR, false)
        local excalFound = API.InvItemcount_1(IDS.EXCALIBUR)
        local elvenCD = API.DeBuffbar_GetIDstatus(IDS.ELVEN_SHARD, false)
        local elvenFound = API.InvItemcount_1(IDS.ELVEN_SHARD)
        local eatFoodAB = API.GetABs_name1("Eat Food")

        -- Auto-activate Excalibur every ~5 minutes 5 seconds (+0 to 20 seconds random)
        local currentTime = os.time()
        local timeSinceLastExcal = os.difftime(currentTime, lastExcaliburUse)
        local randomInterval = EXCALIBUR_INTERVAL + math.random(0, 20)
        
        -- Only check interval once per cycle
        if timeSinceLastExcal >= randomInterval then
            if not excalCD.found and excalFound > 0 then
                if DEBUG_LEVEL > 0 then print("Auto-activating Excalibur (elapsed: " .. timeSinceLastExcal .. " seconds)") end
                API.DoAction_Inventory1(IDS.EXCALIBUR, 0, 1, API.OFF_ACT_GeneralInterface_route)
                lastExcaliburUse = currentTime
                lastExcaliburDebugTime = currentTime
                API.RandomSleep2(800, 200, 300)
            elseif excalCD.found and DEBUG_LEVEL > 1 and os.difftime(currentTime, lastExcaliburDebugTime) >= randomInterval then
                if os.difftime(currentTime, lastExcaliburDebugTime) >= randomInterval then
                    print("[DEBUG] Excalibur not used (interval): On cooldown.")
                    lastExcaliburDebugTime = currentTime
                end
            elseif excalFound <= 0 and DEBUG_LEVEL > 1 and os.difftime(currentTime, lastExcaliburDebugTime) >= randomInterval then
                if os.difftime(currentTime, lastExcaliburDebugTime) >= randomInterval then
                    print("[DEBUG] Excalibur not used (interval): Not found in inventory.")
                    lastExcaliburDebugTime = currentTime
                end
            end
        end
        
        -- Existing health management
        if hp < 50 then
                if eatFoodAB.id ~= 0 and eatFoodAB.enabled then
                    if DEBUG_LEVEL > 0 then print("Eating") end
                    API.DoAction_Ability_Direct(eatFoodAB, 1, API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(1000, 200, 400) -- Increased sleep time
                elseif hp < 20 then
                    if DEBUG_LEVEL > 0 then print("Health critical, unable to heal, running away") end
                    API.DoAction_Ability("Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(1500, 300, 500) -- Added longer delay for critical actions
                end
            
        end

        -- Prayer tracking with time-based checks (5-10 second intervals)
        local currentTime = os.time()
        
        -- Initialize tracking variables if first run
        if lastPrayerCheckTime == nil then
            lastPrayerCheckTime = currentTime
            lastPrayer = prayer
            prayerActive = (prayer < lastPrayer)  -- Prayer is active if points are decreasing
            prayerUnchangedStart = currentTime
        end
        
        -- Check prayer state every 5-10 seconds
        if os.difftime(currentTime, lastPrayerCheckTime) >= 5 then
            -- Update prayer state if points changed significantly
            if math.abs(prayer - lastPrayer) > 1 then
                if DEBUG_LEVEL > 1 then print("Prayer state changed: "..(prayerActive and "active" or "inactive").." to "..(prayer < lastPrayer and "active" or "inactive")) end
                prayerActive = (prayer < lastPrayer)
                lastPrayer = prayer
                prayerUnchangedStart = currentTime
            
            -- Activate prayer if inactive for 10+ seconds
            elseif not prayerActive and os.difftime(currentTime, prayerUnchangedStart) >= 10 then
                if DEBUG_LEVEL > 1 then print("Activating prayer after 10+ seconds of inactivity") end
                API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1430, 16, -1, API.OFF_ACT_GeneralInterface_route)
                prayerActive = true
                prayerUnchangedStart = currentTime
            end
            
            lastPrayerCheckTime = currentTime
        end

        

        -- Prayer management
        if prayer < 50 and not elvenCD.found and elvenFound > 0 then
            if DEBUG_LEVEL > 0 then print("Using Elven Shard") end
            API.DoAction_Inventory1(IDS.ELVEN_SHARD, 43358, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(600, 150, 250)
        elseif prayer < 25 and elvenCD.found then
            API.DoAction_Interface(0x2e, 0xbd0, 1, 1672, 79, -1, API.OFF_ACT_GeneralInterface_route)
            API.DoAction_Ability("pray", 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(600, 150, 250)
        end
    end
end -- End of maintainHealth function


local function waitForStillness(timeout_secs)
    if ShouldStopScript() then return end
    if DEBUG_LEVEL > 1 then print("[DEBUG] Checking for stillness") end

    local start_time = os.time()
    local max_wait_seconds = timeout_secs or 15
    local lastCombatCheck = os.time()

    while (API.CheckAnim(2) or API.ReadPlayerMovin2()) and API.Read_LoopyLoop() and (os.time() - start_time < max_wait_seconds) do
        
        -- Check combat status more frequently (every 2 seconds)
        if os.difftime(os.time(), lastCombatCheck) >= 2 then
            lastCombatCheck = os.time()
            if API.IsInCombat_(player) then
                maintainHealth()
                chargePackCheck()
            end
        end
        
        if ShouldStopScript() then return end
        API.RandomSleep2(500, 100, 200)
    end
end

local function sleep_random(min, max)
    local duration = math.random(min, max)
    API.RandomSleep2(duration, duration // 5, duration // 5)
end

local function wp(x, y, z)
    return WPOINT.new(x, y, z)
end

local function press_key(vk_code)
    API.KeyboardPress32(vk_code, 50, 100)
end

-- == 5. LOOT FUNCTIONS ==
local function randomLootAll()
    local currentTime = os.time()
    local timeSinceLastLoot = os.difftime(currentTime, lastLootTime)
    if timeSinceLastLoot >= nextLootDelay then
        API.DoAction_Interface(0x24,0xffffffff,1,1622,30,-1,API.OFF_ACT_GeneralInterface_route)
        lastLootTime = currentTime
        nextLootDelay = math.random(20, 60) -- Changed to 20-60 seconds for more frequent looting
        if DEBUG_LEVEL > 1 then print("Loot All button pressed randomly after " .. timeSinceLastLoot .. " seconds") end
        UTILS.randomSleep(600)
    end
end

local function buryBones()
    local bonesCount = 0
    for _, boneId in ipairs(bonesId) do
        bonesCount = bonesCount + API.InvItemcount_1(boneId)
    end
    if bonesCount > 0 and buryBonesEnabled then
        for i = 1, bonesCount, 1 do
            API.DoAction_Interface(0x2e, 0x20e, 1, 1430, 233, -1, API.OFF_ACT_GeneralInterface_route)
            UTILS.countTicks(1)
            if not API.Read_LoopyLoop() or not API.PlayerLoggedIn() then
                break
            end
        end
    end
end



local itemsToLoot = UTILS.concatenateTables(
    ITEMS.COMMON,
    ITEMS.RUNES,
    ITEMS.CHARMS
)
local itemsToKeep = UTILS.concatenateTables(itemsToLoot, inventoryItems)
---@param ids table|number
---@param random number
---@param m_action number
---@param offset number
---@return boolean

local function doesTableContain(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function dropJunk()
    -- Create combined table of items to keep from bank preset and loot items
    local itemsToKeep = {}
    
    -- Add items from bank preset (if any)
    if INVENTORY_PRESET then
        for _, item in ipairs(INVENTORY_PRESET) do
            itemsToKeep[item.id] = true
        end
    end
    
    -- Add items from loot table
    for _, id in ipairs(itemsToLoot) do
        itemsToKeep[id] = true
    end
    
    -- Get current inventory items
    local inventory = Inventory:GetItems()
    
    -- Drop items not in our keep list
    for _, item in ipairs(inventory) do
        if not itemsToKeep[item.id] then
            if DEBUG_LEVEL > 0 then print("Dropping item ID: "..item.id) end
            local success = Inventory:Drop(item.id)
            if not success and DEBUG_LEVEL > 0 then
                print("Failed to drop item ID: "..item.id)
            end
            API.RandomSleep2(300, 100, 200)
        end
    end
end



local lastLootAttempt = os.time() * 1000
local LOOT_COOLDOWN = 1500 -- 1.5 seconds minimum between loot attempts
local attempts = 0 -- Counter for failed attemp
local function loot()
    if not LOOT or ShouldStopScript() then return end
    
    local currentTime = os.time() * 1000
    if currentTime - lastLootAttempt < LOOT_COOLDOWN then
        API.RandomSleep2(LOOT_COOLDOWN - (currentTime - lastLootAttempt), 500, 800)
    end
    
    if not API.InvFull_()    then
        API.DoAction_Interface(0x24,0xffffffff,1,1622,30,-1,API.OFF_ACT_GeneralInterface_route)
        local maxAttempts = math.random(1, 3)
        local attempts = 0
                if attempts >= maxAttempts then
                    if DEBUG_LEVEL > 1 then print("Loot: Completed "..attempts.." attempts") end 
                    return
                end

                lastLootAttempt = os.time() * 1000
                API.LootWindowOpen_2()
                attempts = attempts + 1
                
                API.DoAction_Loot_k(itemIdsToLoot, 10, 1, "", 0)
                API.RandomSleep2(1000, 1000, 2000)

        
    else
       -- dropJunk()
        --randomLootAll()
        if buryBonesEnabled then buryBones() end
    end
end

-- == 6. CORE FUNCTIONS ==
local function moveToTrainingSpot(trainingSpot)
    if DEBUG_LEVEL > 0 then print("Running to training spot.") end
    API.DoAction_TileF(trainingSpot)
    waitForStillness()
    API.RandomSleep2(1000, 250, 500)
    API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, NPCS, 2)
end

local lastAttackTime = 0
local ATTACK_COOLDOWN = 1500 -- 1.5 seconds minimum between attacks

local function attackNearestNPC()
    if ShouldStopScript() then return false end
    
    local currentTime = os.time() * 1000 -- Convert to milliseconds
    if currentTime - lastAttackTime < ATTACK_COOLDOWN then
        API.RandomSleep2(ATTACK_COOLDOWN - (currentTime - lastAttackTime), 100, 200)
    end
    
    if DEBUG_LEVEL > 0 then print("Attempting to attack nearest Abyssal NPC...") end
    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, NPCS, 15) then
        if DEBUG_LEVEL > 0 then print("Attack initiated.") end
        lastAttackTime = os.time() * 1000
        API.RandomSleep2(800, 200, 300) -- Increased sleep time
        return true
    else
        if DEBUG_LEVEL > 0 then print("No suitable NPC found in range to attack.") end
        API.RandomSleep2(500, 100, 200)
        return false
    end
end

local function playerNearTile(targetTile, dist)
    if ShouldStopScript() then return false end
    if not targetTile then return false end

    local players = API.GetAllObjArray1({ 1 }, 50, { 2 })
    if not players then return false end

    local localPlayerName = API.GetLocalPlayerName()
    if not localPlayerName then
        print("Warning: Could not get local player name.")
        return false
    end

    for _, p in ipairs(players) do
        if p and p.Name and p.Name ~= localPlayerName then
            local distance = 999
            if p.Tile_XYZ then
                local success, calculated_dist = pcall(API.Math_DistanceF, p.Tile_XYZ, targetTile)
                if success and type(calculated_dist) == "number" then
                    distance = calculated_dist
                end
            end
            if distance < dist then
                if DEBUG_LEVEL > 0 then print(string.format("%s is too close to the training spot! (Dist: %.1f)", p.Name, distance)) end
                return true
            end
        end
    end
    return false
end

local function checkAbyssLocation()
    if #API.GetAllObjArray1(NPCS, 50, { 1 }) <= 0 then
        if DEBUG_LEVEL > 0 then print("No Abyssal NPCs detected, not in the Abyss!") end
        abysss = false
    else
        --print("Abyssal NPCs detected, in the Abyss!")
        abysss = true
    end
    return abysss
end

local function chooseTrainingData()
    if ShouldStopScript() then return nil end
    if DEBUG_LEVEL > 1 then print("Choosing training data...") end
    for i, v in ipairs(TRAINING_DATA) do
        if v and v.trainingSpots and v.trainingSpots[1] then
            if not playerNearTile(v.trainingSpots[1], 10) then
                if DEBUG_LEVEL > 1 then print(string.format("Training spot #%d appears clear.", i)) end
                return v
            else
                if DEBUG_LEVEL > 1 then print(string.format("Training spot #%d is occupied.", i)) end
            end
        end
    end
    if DEBUG_LEVEL > 0 then print("No suitable training spot found.") end
    return nil
end



-- == 7. NAVIGATION FUNCTIONS ==
local function walktoabyss_debug()
    if DEBUG_LEVEL > 0 then print("[NAV] Starting navigation attempt...") end

    local initial_abyss_check = checkAbyssLocation()
    if initial_abyss_check then
        if DEBUG_LEVEL > 0 then print("[NAV] Already in Abyss. No navigation needed.") end
        return true
    end

    local navigation_attempts = 0
    local max_attempts = 20
    local war_retreat_teleport_used = false

    local isEdgevilleStart = LODESTONES.EDGEVILLE:IsAtLocation()
    local isWildyStart = LODESTONES.WILDERNESS:IsAtLocation()
    local playerPos = API.PlayerCoordfloat()

    if playerPos and API.Math_DistanceF(playerPos, WAR_RETREAT_BANK_AREA) < 10 then
        if DEBUG_LEVEL > 1 then print("[NAV] Player is near War's Retreat bank.") end
        if openBank() then
            if DEBUG_LEVEL > 1 then print("[NAV] Bank opened. Waiting 2 seconds.") end
            API.RandomSleep2(2000, 500, 1000)
            if DEBUG_LEVEL > 0 then print("[NAV] Teleporting to Edgeville Lodestone.") end
            LODESTONES.EDGEVILLE:Teleport()
            API.RandomSleep2(3000, 1000, 1500)
            waitForStillness()
            if ShouldStopScript() then return false end
            war_retreat_teleport_used = true
        else
            if DEBUG_LEVEL > 0 then print("[NAV] Failed to open bank, continuing.") end
        end
    end

    if not isEdgevilleStart and not isWildyStart and not initial_abyss_check and not war_retreat_teleport_used then
        if DEBUG_LEVEL > 0 then print("[NAV] Not in Edgeville, Wilderness, or Abyss. Teleporting to Edgeville.") end
        LODESTONES.EDGEVILLE:Teleport()
        API.RandomSleep2(3000, 1000, 1500)
        waitForStillness()
        if ShouldStopScript() then return false end
    end

    while not abysss and API.Read_LoopyLoop() and navigation_attempts < max_attempts do
        navigation_attempts = navigation_attempts + 1
        if DEBUG_LEVEL > 1 then print(string.format("[NAV] Iteration: %d", navigation_attempts)) end

        if ShouldStopScript() then
            print("[walktoabyss_debug] Script stop requested during navigation.")
            break
        end

        local currentPos = API.PlayerCoordfloat()
        local isEdgeville = LODESTONES.EDGEVILLE:IsAtLocation()
        local isWildy = LODESTONES.WILDERNESS:IsAtLocation()
        abysss = checkAbyssLocation()

        if currentPos and type(currentPos.X) == "number" and type(currentPos.Y) == "number" and type(currentPos.Z) == "number" then
            print(string.format("[walktoabyss_debug] Current Coords: X=%.1f, Y=%.1f, Z=%d", currentPos.X, currentPos.Y, currentPos.Z))
        elseif currentPos then
            print("[walktoabyss_debug] Warning: Got coordinates object, but fields are invalid/nil.")
        else
            print("[walktoabyss_debug] Warning: Could not get player coordinates! API returned nil.")
        end

        print("[walktoabyss_debug] Is in Edgeville? " .. tostring(isEdgeville))
        print("[walktoabyss_debug] Is in Wilderness? " .. tostring(isWildy))
        print("[walktoabyss_debug] Is in Abyss? " .. tostring(abysss))

        if abysss then
            print("[walktoabyss_debug] Successfully detected in the Abyss.")
            break
        elseif isEdgeville then
            print("[walktoabyss_debug] Action: In Edgeville. Attempting to jump Wilderness wall.")
            local wall_options = { 65081, 65083 }
            local wall_id = wall_options[math.random(1, #wall_options)]
            print("[walktoabyss_debug] Trying to interact with Wall Object ID: " .. wall_id)
            API.DoAction_Object1(0xb5, API.OFF_ACT_GeneralObject_route0, { wall_id }, 50)
            API.RandomSleep2(3000, 1000, 1500)
            waitForStillness()
        elseif isWildy then
            print("[walktoabyss_debug] Action: In Wilderness. Attempting to reach Mage.")
            local mageAreaTile = FFPOINT.new(3105, 3556, 0)
            local distToMageArea = nil
            if currentPos and mageAreaTile then
                local success, calculated_dist = pcall(API.Math_DistanceF, currentPos, mageAreaTile)
                if success and type(calculated_dist) == "number" then
                    distToMageArea = calculated_dist
                end
            end

            if type(distToMageArea) == "number" then
                print(string.format("[walktoabyss_debug] Distance to Mage target area: %.1f", distToMageArea))
                if distToMageArea > 6 then
                    local targetX = 3104 + math.random(-2, 2)
                    local targetY = 3557 + math.random(-2, 2)
                    local walkTargetTile = FFPOINT.new(targetX, targetY, 0)
                    print(string.format("[walktoabyss_debug] Walking towards Mage area (Target: %d, %d)", targetX, targetY))
                    if API.DoAction_TileF(walkTargetTile) then
                        print("[walktoabyss_debug] Walk action initiated.")
                        API.RandomSleep2(1000, 500, 1000)
                        waitForStillness()
                    else
                        print("[walktoabyss_debug] Error: DoAction_TileF FAILED. Tile out of range or blocked?")
                        API.RandomSleep2(3000, 1000, 1500)
                    end
                else
                    print("[walktoabyss_debug] Close to Mage area. Attempting interaction.")
                    local mageNPCID = { 2257 }
                    if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, mageNPCID, 10) then
                        print("[walktoabyss_debug] Interact action initiated with Mage.")
                        API.RandomSleep2(3000, 500, 1000)
                        abysss = checkAbyssLocation()
                        if abysss then print("[walktoabyss_debug] Now in abyss after Mage interaction!") end
                    else
                        print("[walktoabyss_debug] Error: Failed interaction with Mage.")
                        API.RandomSleep2(2000, 500, 1000)
                    end
                end
            else
                print("[walktoabyss_debug] Error: Could not calculate distance to Mage area (invalid coordinates?). Skipping Wildy movement/interaction this iteration.")
                API.RandomSleep2(2000, 500, 1000)
            end
        else
            print("[walktoabyss_debug] Lost? Not in Edgeville, Wilderness, or Abyss. Teleporting to Edgeville.")
            LODESTONES.EDGEVILLE:Teleport()
            API.RandomSleep2(3000, 1000, 1500)
            waitForStillness()
        end

        print(string.format("[walktoabyss_debug] --- End of Iteration: %d --- Short pause.", navigation_attempts))
        API.RandomSleep2(1500, 500, 1000)
        abysss = checkAbyssLocation()
    end

    abysss = checkAbyssLocation()
    if abysss then
        print("[walktoabyss_debug] Finished: Successfully confirmed in Abyss.")
        return true
    elseif not API.Read_LoopyLoop() then
        print("[walktoabyss_debug] Finished: Script was stopped externally.")
        return false
    elseif navigation_attempts >= max_attempts then
        print("[walktoabyss_debug] Finished: Reached max navigation attempts (" .. max_attempts .. "). Failed.")
        return false
    else
        print("[walktoabyss_debug] Finished: Loop exited unexpectedly (maybe failed teleport/action?). Failed.")
        return false
    end
end

-- == 8. GLOBAL VARIABLES ==
local abysss = false -- Track Abyss location



-- == 9. MAIN SCRIPT LOGIC ==
print("Starting main script loop...")
local TDATA = nil
local current_training_spot = nil
while API.Read_LoopyLoop() do
    -- Consolidated game state and stop checks
    if API.GetGameState2() ~= 3 or not API.PlayerLoggedIn() or ShouldStopScript() then
        if API.GetGameState2() ~= 3 or not API.PlayerLoggedIn() then
            print("Bad game state or not logged in. Waiting...")
            API.RandomSleep2(5000, 1000, 2000)
        end
        break
    end

    chargePackCheck()
    maintainHealth()

    -- Location handling
    abysss = checkAbyssLocation()
    if not abysss then
        print("Not in abyss, navigating...")
        if not walktoabyss_debug() then
            print("Navigation failed. Stopping.")
            API.Write_LoopyLoop(false)
            break
        end
        TDATA = nil
        current_training_spot = nil
        API.RandomSleep2(1000, 250, 500)
        -- Skip to next iteration using continue
        goto continue
    end

    -- Training spot selection (once per location)
    if not TDATA then
        TDATA = chooseTrainingData()
        if not TDATA then
            print("No training spots available. Stopping.")
            API.DoAction_TileF(SAFE_SPOT)
            waitForStillness()
            API.Write_LoopyLoop(false)
            break
        end
        current_training_spot = TDATA.trainingSpots[math.random(1, #TDATA.trainingSpots)]
    end

    -- Movement to spot
    local distance_to_spot = API.Dist_FLP(current_training_spot) or 999
    if distance_to_spot > 8 then
        print("Moving to training spot (Distance: "..string.format("%.1f", distance_to_spot)..")")
        moveToTrainingSpot(current_training_spot)
        API.RandomSleep2(600, 200, 400)
        -- Skip to next iteration using continue
        goto continue
    end

    -- Combat actions
    if not API.CheckAnim(100) and not API.LocalPlayer_IsInCombat_() then
        if not attackNearestNPC() then
            print("No NPCs found, resetting position")
            local resetTile = FFPOINT.new(TDATA.resetSpot[1] + math.random(-5, 5), TDATA.resetSpot[2] + math.random(0, 5), 0)
            API.DoAction_TileF(resetTile)
            waitForStillness()
            moveToTrainingSpot(current_training_spot)
        end
    else
        loot()
    end

    API.RandomSleep2(600, 200, 400)
    
    ::continue::
end

print("Script execution finished or stopped.")
