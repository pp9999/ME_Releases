--[[
    https://runescape.wiki/w/Construction_training#Training_at_Fort_Forinthry

    Start at fort forinthry with a full inventory of the material to process and have it set as preset 1
]]

-- includes
local API = require("api")
local UTILS = require("utils")
-- includes

-- variables
local MAX_IDLE_TIME_MINUTES = 5
local startTime, afk = os.time(), os.time()
local SKILL = "CONSTRUCTION"
local TITLE = "FortForinthryProcessing"
local startXp = API.GetSkillXP(SKILL)
local out, fails = 0, 0
local MATERIALS = {
    Limestone_brick = {"Stone wall segment", "Stonecutter", 4},
    Logs = {"Plank", "Sawmill", 1},
    Oak_logs = {"Oak plank", "Sawmill", 1},
    Willow_logs = {"Willow plank", "Sawmill", 1},
    Teak_logs = {"Teak plank", "Sawmill", 1},
    Maple_logs = {"Maple plank", "Sawmill", 1},
    Acadia_logs = {"Acadia plank", "Sawmill", 1},
    Mahogany_logs = {"Mahogany plank", "Sawmill", 1},
    Yew_logs = {"Yew plank", "Sawmill", 1},
    Magic_logs = {"Magic plank", "Sawmill", 1},
    Plank = {"Refined planks", "Sawmill", 4},
    Oak_plank = {"Refined Oak planks", "Sawmill", 4},
    Willow_plank = {"Refined Willow planks", "Sawmill", 4},
    Teak_plank = {"Refined Teak planks", "Sawmill", 4},
    Maple_plank = {"Refined Maple planks", "Sawmill", 4},
    Acadia_plank = {"Refined Acadia planks", "Sawmill", 4},
    Mahogany_plank = {"Refined Mahogany planks", "Sawmill", 4},
    Yew_plank = {"Refined Yew planks", "Sawmill", 4},
    Magic_plank = {"Refined Magic planks", "Sawmill", 4},
    Elder_plank = {"Refined Elder planks", "Sawmill", 4},
    Refined_planks = {"Wooden frame", "Woodworking bench", 3},
    Refined_Oak_planks = {"Oak frame", "Woodworking bench", 3},
    Refined_Willow_planks = {"Willow frame", "Woodworking bench", 3},
    Refined_Teak_planks = {"Teak frame", "Woodworking bench", 3},
    Refined_Maple_planks = {"Maple frame", "Woodworking bench", 3},
    Refined_Acadia_planks = {"Acadia frame", "Woodworking bench", 3},
    Refined_Mahogany_planks = {"Mahogany frame", "Woodworking bench", 3},
    Refined_Yew_planks = {"Yew frame", "Woodworking bench", 3},
    Refined_Magic_planks = {"Magic frame", "Woodworking bench", 3},
    Refined_Elder_planks = {"Elder frame", "Woodworking bench", 3}
}
-- variables

-- setup
local material = API.ReadInvArrays33()[1].textitem
local product = MATERIALS[material:gsub(" ", "_")][1]
local machine = MATERIALS[material:gsub(" ", "_")][2]
local min_materials = MATERIALS[material:gsub(" ", "_")][3]
-- setup

-- functions
local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

-- Format a number with commas as thousands separator
local function formatNumberWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

local function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

-- Format script elapsed time to [hh:mm:ss]
local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function calcProgressPercentage(skill, currentExp)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    if currentLevel == 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1)
    local currentLevelExp = XPForLevel(currentLevel)
    local progressPercentage = (currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100
    return math.floor(progressPercentage)
end

local function printProgressReport(final)
    local skill = SKILL
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp)
    local xpPH = round((diffXp * 60) / elapsedMinutes)
    local outPH = round((out * 60) / elapsedMinutes)
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    local progress = time ..
    " | " ..
    string.lower(skill):gsub("^%l", string.upper) ..
    ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
    .. " | " .. product .. "/H: " .. formatNumber(outPH) .. " | " .. product .. ": " .. out
    IGP.string_value = progress
    if final then print(progress) end
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(116, 2, 179);
    IGP.string_value = TITLE
end

local function drawGUI()
    DrawProgressBar(IGP)
end

setupGUI()
-- functions

-- checks
local function isBusy()
    return API.isProcessing() or API.ReadPlayerMovin()
end

local function hasMaterials()
    return API.InvItemcount_String(material) - API.InvItemcount_String(MATERIALS[material:gsub(" ", "_")][1]) >= min_materials
end

local function isBankOpen()
    return API.BankOpen2()
end

local function isInterfaceOpen()
    return API.VB_FindPSett(2874).state == 1310738
end
-- checks

-- actions
local function openBank()
    API.DoAction_Object_string1(0x2e, API.OFF_ACT_GeneralObject_route1, {"Bank chest"}, 20, true)
end

local function takePreset()
    out = out + API.InvItemcount_String(product)
    API.KeyboardPress2(0x31, 0, 50) -- presses 1 (first preset)
end

local function startCraft()
    API.KeyboardPress2(0x20, 0, 50) -- presses spacebar
end

local function openInterface()
    local offset; if machine == "Woodworking bench" then offset = 0xae else offset = 0x29 end
    API.DoAction_Object_string1(offset, API.OFF_ACT_GeneralObject_route0, {machine}, 20, true)
end
-- actions

-- mainloop
while API.Read_LoopyLoop() do
    idleCheck()
    printProgressReport(false)
    drawGUI()

    if not isBusy() then
        if isInterfaceOpen() then
            startCraft()
        else
            if isBankOpen() then
                takePreset()
                UTILS.randomSleep(500)
                if not hasMaterials() then
                    fails = fails + 1
                end
            else
                if hasMaterials() then
                    fails = 0
                    openInterface()
                else
                    openBank()
                end
            end
        end
    end

    if fails > 2 then
        printProgressReport(true)
        API.Write_LoopyLoop(false)
    end
    
    UTILS.randomSleep(500)
end
-- mainloop