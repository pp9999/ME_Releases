local API = require("api")
local GUI = require("Knetter AIO Skiller.gui")
local DATA = require("Knetter AIO Skiller.data")

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

ScriptName = "Knetterbal AIO Skiller"
Author = "Knetterbal"
ScriptVersion = "1.3"
ReleaseDate = "27-08-2025"

local RES = DATA.resolve()

local selectedSkill = RES.selectedSkill
local subSkill = RES.subSkill
local selectedFish = RES.selectedFish
local selectedLog = RES.selectedLog
local selectedArrow = RES.selectedArrow
local bowMaterial1 = RES.bowMaterial1
local bowMaterial2 = RES.bowMaterial2
local subSkill2 = RES.subSkill2
local uncut = RES.uncut
local selectedSandstone = RES.selectedSandstone
local selectedGlass = RES.selectedGlass
local selectedLeather = RES.selectedLeather
local armorType = RES.armorType
local EnergyType = RES.EnergyType
local necklaceType = RES.necklaceType
local porterType = RES.porterType
local potionType = RES.potionType
local combination = RES.combination
local unfinishedPotions = RES.unfinishedPotions
local herbloreSubSkill = RES.herbloreSubSkill
local inkType = RES.inkType



-- ==== GUI ====
local function BuildGUI()
    GUI.AddBackground("main_background", 0.5, 6, ImColor.new(15, 13, 18, 255))
    GUI.AddLabel("title_label", "Knetterbal AIO Skiller", ImColor.new(255, 255, 255))
    GUI.AddLabel("version_label", "Version: " .. ScriptVersion, ImColor.new(255, 255, 255))
    GUI.AddButton("start_button", "Start/Pause Script")
end

local function isStarted()
    local btn = GUI.GetComponent("start_button")
    return btn and btn.return_click or false
end

-- ==== HELPERS ====
local function gameStateChecks()
    local gameState = API.GetGameState2()
    if gameState ~= 3 then
        API.logDebug("Not ingame with state: " .. tostring(gameState))
        return false
    end
    if not API.PlayerLoggedIn() then
        API.logDebug("Not Logged In")
        return false
    end
    return true
end


local function findItemInInventory(itemId)
    if not itemId then return nil end
    local inventory = API.ReadInvArrays33()
    for i = 1, #inventory do
        if inventory[i].itemid1 == itemId then
            return inventory[i]
        end
    end
    return nil
end


local function HasItemMin(itemId, min)
    min = min or 1
    local stack = API.InvStackSize(itemId) or 0
    local count = API.InvItemcount_1(itemId) or 0
    local amount = math.max(stack, count)
    return amount >= min
end

local function allItemsInInventory(potionTable)
    if not potionTable or #potionTable == 0 then
        return false
    end
    for i, ingredient in ipairs(potionTable) do
        local needed = ingredient.amount or 1

        if not HasItemMin(ingredient.id, needed) then
            return false
        end
    end

    return true
end

local function isInterfaceOpen()
    return API.Compare2874Status(18)
end

local function startCraft()
    API.KeyboardPress2(0x20, 100, 50)
end

local function isBusy()
    return API.CheckAnim(20) or API.isProcessing() or API.ReadPlayerMovin()
end
local function isBurningLogs()
    return API.CheckAnim(100) or API.isProcessing() or API.ReadPlayerMovin()
end


local function hasMaterials()
    local threadId   = 1734
    local bowstringId = 1777


    local fletchingCases = {
        FLETCH = function()
            return findItemInInventory(selectedLog) ~= nil
        end,
        STRING = function()
            local unfShort = bowMaterial1
            local unfLong  = bowMaterial2
            return ((unfShort and findItemInInventory(unfShort)) or
                    (unfLong  and findItemInInventory(unfLong))) 
                    and findItemInInventory(bowstringId)
        end,
        HEADLESS = function()
            return HasItemMin(52, 15) and HasItemMin(314, 15)
        end,
        ARROWS = function()
            return HasItemMin(53, 15) and HasItemMin(selectedArrow, 15)
        end,
    }


    local craftingCases = {
        CUT    = function() return findItemInInventory(uncut) ~= nil end,
        GLASS  = function() return findItemInInventory(selectedSandstone) ~= nil end,
        FLASKS = function() return findItemInInventory(selectedGlass) ~= nil end,
        ARMOR  = function()
            local armorReqs = {
                VAMBRACES = function() return findItemInInventory(selectedLeather) and findItemInInventory(threadId) end,
                BOOTS     = function() return findItemInInventory(selectedLeather) and findItemInInventory(threadId) end,
                CHAPS     = function() return HasItemMin(selectedLeather,2) and findItemInInventory(threadId) end,
                COIF      = function() return HasItemMin(selectedLeather,2) and findItemInInventory(threadId) end,
                BODY      = function() return HasItemMin(selectedLeather,3) and findItemInInventory(threadId) end,
                SHIELD    = function() return HasItemMin(selectedLeather,4) and findItemInInventory(threadId) end,
            }
            return armorReqs[armorType] and armorReqs[armorType]() or false
        end
    }


    local skillCases = {
        FLETCHING  = function() return fletchingCases[subSkill] and fletchingCases[subSkill]() or false end,
        COOKING    = function() return findItemInInventory(selectedFish) ~= nil end,
        FIREMAKING = function() return findItemInInventory(selectedLog) ~= nil end,
        CRAFTING   = function() return craftingCases[subSkill2] and craftingCases[subSkill2]() or false end,
        OTHER = function() return inkType and allItemsInInventory(inkType) end,
        HERBLORE = function()
            local herbloreCases = {
                POTIONS = function()
                    return potionType and allItemsInInventory(potionType)
                end,
                COMBINATION = function()
                    return combination and allItemsInInventory(combination)
                end,
                UNF = function()
                    return unfinishedPotions and (findItemInInventory(unfinishedPotions) and findItemInInventory(227) ~= nil)
                end
            }
            return herbloreCases[herbloreSubSkill] and herbloreCases[herbloreSubSkill]() or false
        end,

        DIVINATION = function()
            local reqs = {
                IV  = 45,
                V   = 60,
                VI  = 80,
                VII = 120
            }
            local needed = reqs[porterType]
            return needed and HasItemMin(EnergyType, needed) and findItemInInventory(necklaceType) ~= nil
        end,
    }

    return skillCases[selectedSkill] and skillCases[selectedSkill]() or false
end



local function startWorking()
    if isInterfaceOpen() then
        return startCraft()
    end
    local necroplasm = {55599, 55600, 55601}
    local actions = {
        COOKING    = function() if not isBusy() then Interact:Object("Range", "Cook-at") end end,
        FLETCHING  = function() if not isBusy() then Interact:Object("Fletching workbench", "Use") end end,
        FIREMAKING = function() if not isBurningLogs() then Interact:Object("Bonfire", "Add logs to") end end,
        HERBLORE  = function()
            if isBusy() then return end
            local subActions = {
                POTIONS = function() Interact:Object("Botanist's workbench", "Mix Potions") end,
                UNF = function() API.DoAction_Inventory1(227, 0, 1, API.OFF_ACT_GeneralInterface_route) end,
                COMBINATION = function() API.DoAction_Inventory1(32843, 0, 1, API.OFF_ACT_GeneralInterface_route) end,
            }
            return subActions[herbloreSubSkill] and subActions[herbloreSubSkill]()
        end,
        OTHER = function() if not isBusy() then API.DoAction_Inventory1(necroplasm, 0, 1, API.OFF_ACT_GeneralInterface_route) end end,
        DIVINATION = function() if not isBusy() then API.DoAction_Inventory1(EnergyType, 0, 1, API.OFF_ACT_GeneralInterface_route) end end,
        CRAFTING   = function()
            if isBusy() then return end
            local subActions = {
                GLASS  = function() Interact:Object("Robust glass machine", "Fill"); API.WaitUntilMovingEnds() end,
                FLASKS = function() API.DoAction_Inventory1(selectedGlass, 0, 1, API.OFF_ACT_GeneralInterface_route) end,
                CUT    = function() API.DoAction_Inventory1(uncut, 0, 1, API.OFF_ACT_GeneralInterface_route) end,
                ARMOR  = function() API.DoAction_Inventory1(selectedLeather, 0, 1, API.OFF_ACT_GeneralInterface_route) end,
            }
            return subActions[subSkill2] and subActions[subSkill2]()
        end,
    }

    return actions[selectedSkill] and actions[selectedSkill]()
end



local function loadLastPreset()
    local function loadChest()
        Interact:Object("Bank chest", "Load Last Preset from")
    end

    local function loadBanker()
        Interact:NPC("Banker", "Load Last Preset from")
    end

    local actions = {
        FLETCHING  = loadChest,
        COOKING    = loadChest,
        FIREMAKING = loadBanker,
        DIVINATION = loadChest,
        HERBLORE = loadChest,
        OTHER = loadChest,
        CRAFTING   = function()
            if isBusy() then return end
            local subs = { GLASS = loadChest, FLASKS = loadChest, CUT = loadChest, ARMOR = loadChest }
            return subs[subSkill2] and subs[subSkill2]()
        end,
    }

    if actions[selectedSkill] then
        API.logDebug("Loading last preset")
        actions[selectedSkill]()
    end
end

-- ==== START ====
BuildGUI()

API.logDebug(("Knetterbal AIO Skiller started with skill: %s  and sub-skill: %s and sub-skill2: %s"):format(tostring(
    selectedSkill), tostring(subSkill), tostring(subSkill2)))
API.logDebug(("Selected Fish: %s  Selected Log: %s  Selected Bow: %s  Selected Arrow: %s"):format(
    tostring(selectedFish), tostring(selectedLog), tostring(selectedBow), tostring(selectedArrow)))
API.logDebug(("BowMaterial1: %s  BowMaterial2: %s"):format(tostring(bowMaterial1), tostring(bowMaterial2)))

API.logDebug(("Selected Sandstone: %s  Selected Glass: %s"):format(tostring(selectedSandstone), tostring(selectedGlass)))

local fails = 0

while API.Read_LoopyLoop() do
    GUI.Draw()
    API.DoRandomEvents()

    if not gameStateChecks() then
        goto continue
    end

    if isStarted() then

        if not hasMaterials() then
            -- API.logDebug("Materials not found, trying to load last preset.")
            loadLastPreset()

            -- API.RandomSleep2(500, 700, 800)
            fails = fails + 1
            if fails > 5 then
                -- API.logDebug("Failed to find materials 3 times, stopping script.")
                API.Write_LoopyLoop(false)
            end
        else
            -- API.logDebug("Materials found, continuing.")
            fails = 0
            startWorking()
            API.RandomSleep2(500, 700, 800)
        end

    end

    ::continue::
    API.RandomSleep2(500, 700, 800)
end
