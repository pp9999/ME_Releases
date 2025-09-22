--[[
    Author:      Klamor
    Version:     1.1
    Release      Date: 08/20/2024
    Script:      Rogue's Den Cooking

    Release Notes:
    - Version 1.0   :   Inital release
    - Version 1.1   :   Added Fail-Safe conditions to prevent infinite loops

    DESCRIPTION:
        :   Cooks food at Rogue's Den under the tavern in Taverly.
        :   ATTENTION:
            :   This script only uses the 'Load Last Preset' action.
            :   This script only cooks when it finds a FULL inventory after banking.

    TODO:
        :   Add support for more cookable food types.

    SCRIPT SETUP:
        :   Configure any preset to a full inventory of cookable items and load it once.
        :   Run the script and choose your fishType in the drop down menu.
        :   Click START.

]]

print("Rogue's Den cooking")

local API = require("api")

GLOBALS = {
    fishToCook = nil,
    fishCooked = 0,
    currentState = "Idle"
}

RAW_FISH = {
    RAW_SHRIMPS           = { name = "Raw Shrimps",             id = 317 },
    RAW_CRAYFISH          = { name = "Raw Crayfish",            id = 13435 },
    RAW_SARDINE           = { name = "Raw Sardine",             id = 327 },
    RAW_ANCHOVIES         = { name = "Raw Anchovies",           id = 321 },
    RAW_HERRING           = { name = "Raw Herring",             id = 345 },
    RAW_MACKEREL          = { name = "Raw Mackerel",            id = 353 },
    RAW_TROUT             = { name = "Raw Trout",               id = 335 },
    RAW_COD               = { name = "Raw Cod",                 id = 341 },
    RAW_PIKE              = { name = "Raw Pike",                id = 349 },
    RAW_SALMON            = { name = "Raw Salmon",              id = 331 },
    RAW_SLIMY_EEL         = { name = "Slimy Eel",               id = 3379}, 
    RAW_TUNA              = { name = "Raw Tuna",                id = 359 },
    RAW_KARAMBWAN         = { name = "Raw Karambwan",           id = 3142 },
    RAW_RAINBOW_FISH      = { name = "Raw Rainbow Fish",        id = 10138 },
    RAW_CAVE_EEL          = { name = "Raw Cave Eel",            id = 5001 }, 
    RAW_LOBSTER           = { name = "Raw Lobster",             id = 377 },
    RAW_BASS              = { name = "Raw Bass",                id = 363 },
    RAW_SWORDFISH         = { name = "Raw Swordfish",           id = 371 },
    RAW_DESERT_SOLE       = { name = "Raw Desert Sole",         id = 40287 },  
    RAW_CATFISH           = { name = "Raw Catfish",             id = 40289 }, 
    RAW_MONKFISH          = { name = "Raw Monkfish",            id = 7944 },
    RAW_BELTFISH          = { name = "Raw Beltfish",            id = 40291 }, 
    RAW_SHARK             = { name = "Raw Shark",               id = 383 },
    RAW_SEA_TURTLE        = { name = "Raw Sea Turtle",          id = 395 },
    RAW_GREAT_WHITE_SHARK = { name = "Raw Great White Shark",   id = 34727 }, 
    RAW_CAVEFISH          = { name = "Raw Cavefish",            id = 15264 }, 
    RAW_MANTA_RAY         = { name = "Raw Manta Ray",           id = 389 },
    RAW_ROCKTAIL          = { name = "Raw Rocktail",            id = 15270 },
    RAW_TIGER_SHARK       = { name = "Raw Tiger Shark",         id = 21520 }  
}

RAW_TO_COOKED = {
    [317]     = 315,     -- Raw Shrimps -> Shrimps
    [13435]   = 13433,   -- Raw Crayfish -> Crayfish
    [327]     = 325,     -- Raw Sardine -> Sardine
    [321]     = 319,     -- Raw Anchovies -> Anchovies
    [345]     = 347,     -- Raw Herring -> Herring
    [353]     = 355,     -- Raw Mackerel -> Mackerel
    [335]     = 333,     -- Raw Trout -> Trout
    [341]     = 339,     -- Raw Cod -> Cod
    [349]     = 351,     -- Raw Pike -> Pike
    [331]     = 329,     -- Raw Salmon -> Salmon
    [3379]    = 3381,    -- Slimy Eel -> Cooked Eel
    [359]     = 361,     -- Raw Tuna -> Tuna
    [3142]    = 3144,    -- Raw Karambwan -> Cooked Karambwan
    [10138]   = 10136,   -- Raw Rainbow Fish -> Rainbow Fish
    [5001]    = 5003,    -- Raw Cave Eel -> Cooked Cave Eel
    [377]     = 379,     -- Raw Lobster -> Lobster
    [363]     = 365,     -- Raw Bass -> Bass
    [371]     = 373,     -- Raw Swordfish -> Swordfish
    [40287]   = 40293,   -- Raw Desert Sole -> Desert Sole
    [40289]   = 40295,   -- Raw Catfish -> Catfish
    [7944]    = 7946,    -- Raw Monkfish -> Monkfish
    [40291]   = 40297,   -- Raw Beltfish -> Beltfish
    [383]     = 385,     -- Raw Shark -> Shark
    [395]     = 397,     -- Raw Sea Turtle -> Sea Turtle
    [34727]   = 34729,   -- Raw Great White Shark -> Great White Shark
    [15264]   = 15266,   -- Raw Cavefish -> Cavefish
    [389]     = 391,     -- Raw Manta Ray -> Manta Ray
    [15270]   = 15272,   -- Raw Rocktail -> Rocktail
    [21520]   = 21522    -- Raw Tiger Shark -> Tiger Shark
}

---@return table of strings
function getAllFishNames()
    local names = {"None"}
    for _, fish in pairs(RAW_FISH) do
        table.insert(names, fish.name)
    end
    return names
end

---@param amount number
---@return string
function comma_value(amount)
    local formatted = tostring(amount) -- Convert the number to a string
    while true do
        -- Replace a sequence of digits followed by three digits with the same sequence, a comma, and the three digits
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        -- If no more replacements were made (k == 0), break the loop
        if (k == 0) then
            break
        end
    end
    return formatted
end

---@param number
---@return string
function fmt(value)
    if value > 999 then
        return comma_value(value)
    end
    return tostring(value)
end

---@param item number
---@return number
function itemsPerHour(item)
    if item == 0 then
        return 0
    end
    local elapsedTime = API.ScriptRuntime() / 3600 
    return math.floor(item / elapsedTime)
end

---@param itemID number
---@param itemNum number
---@return number
function EstimatedProfit(itemID, itemNum) 
    local profitPerItem = API.GetExchangePrice(itemID)
    return itemNum * profitPerItem
end

---@param itemID number
---@param itemNum number
---@return number
function EstimatedProfitPerHour(itemID, itemNum)
    local elapsedTime = API.ScriptRuntime() / 3600
    return math.floor(EstimatedProfit(itemID, itemNum) / elapsedTime)    
end

function metrics()
    local METRICS = {
        {"Current State: ", GLOBALS.currentState},
        {"Fish Type: ", GLOBALS.fishToCook.name},
        {"GE Value: ", fmt(API.GetExchangePrice(GLOBALS.fishToCook.id))},
        {"# of fish: ", fmt(GLOBALS.fishCooked)},
        {"# of fish/hr: ", fmt(itemsPerHour(GLOBALS.fishCooked))},
        {"Est. profit: ", fmt(EstimatedProfit(GLOBALS.fishToCook.id, GLOBALS.fishCooked))},
        {"Est. profit/hr: ", fmt(EstimatedProfitPerHour(GLOBALS.fishToCook.id, GLOBALS.fishCooked))}
    }
    API.DrawTable(METRICS)
end

function updateCurrentState(state)
    GLOBALS.currentState = state
    API.logDebug("Current State: "..GLOBALS.currentState)
    metrics()
end

function drawGUI()

    imguiBackground = API.CreateIG_answer()
    imguiBackground.box_name = "imguiBackground"
    imguiBackground.box_start = FFPOINT.new(50, 30, 0)
    imguiBackground.box_size = FFPOINT.new(330, 115, 0)
    imguiBackground.colour = ImColor.new(99, 99, 99, 225)

    local gui_center_x = imguiBackground.box_start.x + (imguiBackground.box_size.x / 2)

    local dropdown_width = 300
    local dropdown_height = 20
    local dropdown_x = gui_center_x - (dropdown_width / 2) + 10
    local dropdown_y = 40 

    local fishTypes = getAllFishNames()

    fishTypeCombo = API.CreateIG_answer()
    fishTypeCombo.box_name = "Fish Type"
    fishTypeCombo.box_start = FFPOINT.new(dropdown_x, dropdown_y, 0)
    fishTypeCombo.stringsArr = fishTypes
    fishTypeCombo.string_value = fishTypes[1]
    fishTypeCombo.tooltip_text = "Choose the fish type to cook."

    local button_y = dropdown_y + dropdown_height + 15  
    local button_width = 80
    local button_height = 30
    local button_spacing = 20
    local total_button_width = button_width * 2 + button_spacing
    local buttons_start_x = gui_center_x - (total_button_width / 2) - 25

    startButton = API.CreateIG_answer()
    startButton.box_name = "START"
    startButton.box_start = FFPOINT.new(buttons_start_x, button_y, 0)
    startButton.box_size = FFPOINT.new(button_width, button_height, 0)
    startButton.tooltip_text = "Start the script."

    quitButton = API.CreateIG_answer()
    quitButton.box_name = "QUIT"
    quitButton.box_start = FFPOINT.new(buttons_start_x + button_width + button_spacing, button_y, 0)
    quitButton.box_size = FFPOINT.new(button_width, button_height, 0)
    quitButton.tooltip_text = "Close the script."

    API.DrawSquareFilled(imguiBackground)
    API.DrawComboBox(fishTypeCombo)
    API.DrawBox(startButton)
    API.DrawBox(quitButton)

end

function clearGUI()
    imguiBackground.remove = true
    fishTypeCombo.remove = true
    startButton.remove = true
    quitButton.remove = true
end

---@return boolean
function isCraftingInterfaceOpen()
  return API.VB_FindPSett(2874, 1, 0).state == 1310738
end

---@return boolean
function waitForCraftingInterface()
    local failTimer = API.SystemTime()
    while not isCraftingInterfaceOpen() do
        if not API.Read_LoopyLoop() then return false end
        API.RandomSleep2(600,0,250)
        if API.SystemTime() - failTimer > 30000 then
            API.logWarn("Failed to open Crafting Interface!")
            API.Write_LoopyLoop(false)
            return false
        end
    end
    return true
end

---@return boolean
function clickStart()
    waitForCraftingInterface()
    return API.DoAction_Interface(0xffffffff,0xffffffff,0,1370,30,-1,API.OFF_ACT_GeneralInterface_Choose_option)  
end

---@return boolean
function doCrafting()
    waitForCraftingInterface()
    if clickStart() then
        local craftingTimer = API.SystemTime()
        while not API.isProcessing() do
            if not API.Read_LoopyLoop() then return false end
            API.RandomSleep2(600,0,500)
            if API.SystemTime() - craftingTimer > 10000 then
                API.logWarn("Crafting process took too long to start!")
                API.Write_LoopyLoop(false)
                return false
            end
        end
        while API.isProcessing() do
            if not API.Read_LoopyLoop() then return false end
            API.RandomSleep2(600,0,500)
        end
        return true
    end
end

function loadLastPreset()
    local banktimer = API.SystemTime()
    Interact:NPC("Emerald Benedict", "Load Last Preset from", 20)
    API.RandomSleep2(600, 0, 250)
    while API.Invfreecount_() > 0 do
        if not API.Read_LoopyLoop() then return false end
        if (API.SystemTime() - banktimer) > 30000 then
            API.logDebug("Out of supplies!")
            API.Write_LoopyLoop(false)
            return
        end
        API.RandomSleep2(50, 0, 50)
    end
end

function cookAtFire()
    if Interact:Object("Fire", "Cook at", 10) then
        doCrafting()
    else
        API.logDebug("Out of supplies!")
        API.Write_LoopyLoop(false)
        return
    end
end

function updateMetrics()

    local cookedID = RAW_TO_COOKED[GLOBALS.fishToCook.id]
    local cookedFishCount = Inventory:GetItemAmount(cookedID)

    GLOBALS.fishCooked = GLOBALS.fishCooked + cookedFishCount

    metrics()
end

function startCookingRoutine()

    while GLOBALS.currentState == "Idle" do

        if fishTypeCombo.return_click then
            fishTypeCombo.return_click = false
            local selectedFishType = fishTypeCombo.string_value
            for key, value in pairs(RAW_FISH) do
                if value.name == selectedFishType then
                    GLOBALS.fishToCook = value
                    break
                end
            end
            if GLOBALS.fishToCook ~= nil then
                API.logDebug("Selected Fish Type: "..GLOBALS.fishToCook.name)
            else
                API.logWarn("Something went wrong! Selected fish type still NIL!")
                API.Write_LoopyLoop(false)
                return
            end
        end

        if startButton.return_click then
            startButton.return_click = false
            if GLOBALS.fishToCook == nil then
                API.logWarn("Fish Type not selected!")
            else
                clearGUI()
                updateCurrentState("Starting...")
            end

        end

        if quitButton.return_click then
            API.logWarn("Stopping script!")
            API.Write_LoopyLoop(false)
            return
        end

        if not API.Read_LoopyLoop() then return end
        API.RandomSleep2(250,0,250)

    end

    while GLOBALS.currentState ~= "Idle" do
        if GLOBALS.fishToCook == nil then
            API.logWarn("Something went wrong! Selected fish type still NIL!")
            API.Write_LoopyLoop(false)
            return
        end
        if not API.Read_LoopyLoop() then return end
        if Inventory:Contains(GLOBALS.fishToCook.id) then
            updateCurrentState("Cooking...")
            cookAtFire()
            updateCurrentState("Updating Metrics...")
            updateMetrics()
        else
            updateCurrentState("Banking...")
            loadLastPreset()
        end
    end

end

API.Write_LoopyLoop(true)
API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(5)
drawGUI()

while API.Read_LoopyLoop()
do-----------------------------------------------------------------------------------
    startCookingRoutine()
end----------------------------------------------------------------------------------
