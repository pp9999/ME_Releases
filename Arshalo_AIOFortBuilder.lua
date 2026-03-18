--[[

@Title:         AIO Fort Construction
@Description:   Builds all locations / Tiers in Fort Forinthry
@Author         Arshalo
@Date           15/03/26
@Version        1.4



Details

--]]

local API = require("api")
local UTILS = require("utils")
local LODE = require("lodestones")
local Bank = require("bank")


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>EDIT THE TASK TO WHERE YOU WANT TO START<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

local Task = 0 --Choose where the script starts. >>>>>    0 = Choses Blueprint | 1 = Walks to location | 2 = Builds | 3 = Return to Blueprint Table    <<<<<
local DEBUG = true   -- set to false to silence all debug logs




local startTime, afk = os.time(), os.time()
local MAX_IDLE_TIME_MINUTES = 15
local scriptPaused = true
local selectedLabel, selectedBlueprint, selectingBackDoor, selectedMaterial, selectedReturn, selectedStonePerBuild, selectedFramePerBuild, selectedFrameName




API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

local blueprints = {
    workshopt1 = 1,
    workshopt2 = 5,
    workshopt3 = 9,
    townhallt1 = 13,
    townhallt2 = 17,
    townhallt3 = 21,
    chapelt1 = 25,
    chapelt2 = 29,
    chapelt3 = 33,
    command_centert1 = 37,
    command_centert2 = 41,
    command_centert3 = 45,
    kitchent1 = 49,
    kitchent2 = 53,
    kitchent3 = 57,
    guardhouset1 = 61,
    guardhouset2 = 65,
    guardhouset3 = 69,
    groove_cabint1 = 73,
    groove_cabint2 = 77,
    groove_cabint3 = 81,
    rangers_workroomt1 = 85,
    rangers_workroomt2 = 89,
    rangers_workroomt3 = 93,
    botanists_workbencht1 = 97,
    botanists_workbencht2 = 101,
    botanists_workbencht3 = 105
}

local completedBuilds = 0

local selectedStonePerBuild = 0
local selectedFramePerBuild = 0
local selectedFrameName = "N/A"

local stoneUsed = 0
local framesUsed = 0


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ END OF INTRO @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

local function activate_dive(x, y, z)
    local tile = WPOINT.new(x, y, z)
    API.DoAction_SpecialWalk(tile)
    API.RandomSleep2(45, 60, 60)
end

local function dbg(...)
    if DEBUG then
        local msg = table.concat({...}, " ")
        print("[DEBUG] " .. msg)
    end
end

local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function formatNumber(num)
    num = num or 0

    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

----------------------------------------------------------------------
--                              GUI
----------------------------------------------------------------------
local aioSelectC = API.CreateIG_answer()

local mainVariable = {
    {
    label = "Town Hall Tier 1",
    blueprintNumber = blueprints.townhallt1,
    stonePerBuild = 6,
    frameName = "Oak frame",
    framePerBuild = 10,
    materials = function() return Inventory:InvItemcountStack_Strings("Stone wall segment") <= 5 or Inventory:InvItemcountStack_Strings("Oak frame") <= 9
    end,
    walkToLocation = function()
        if API.PInArea(3288, 1, 3555, 1, 0) then 
            API.DoAction_Tile(WPOINT.new(3291,3555,0))
            UTILS.countTicks(1)
            UTILS.surge()
            --activate_dive(3303,3563,0)
        end
        API.DoAction_Tile(WPOINT.new(3303,3563,0))
        UTILS.SleepUntil(function() return API.PInArea(3303, 2, 3563, 2, 0) end, 10, "Arrived at Townhall")
        Task = 2
    end,
    walkToBlueprintTable = function()
        API.DoAction_Tile(WPOINT.new(3302,3559,0))
        UTILS.SleepUntil(function() return API.PInArea(3302, 2, 3559, 2, 0) end, 10, "Surge spot")
        UTILS.surge()
        API.DoAction_Tile(WPOINT.new(3288,3555,0))
        UTILS.SleepUntil(function() return API.PInArea(3288, 1, 3555, 1, 0) end, 10, "Arrived at Blueprint")
        Task = 0
    end

}, {
    label = "Town Hall Tier 2",
    blueprintNumber = blueprints.townhallt2,
    stonePerBuild = 6,
    frameName = "Maple frame",
    framePerBuild = 22,
    materials = function() return Inventory:InvItemcountStack_Strings("Stone wall segment") <= 5 or Inventory:InvItemcountStack_Strings("Maple frame") <= 21
    end,
    walkToLocation = function()
        if API.PInArea(3288, 1, 3555, 1, 0) then 
            API.DoAction_Tile(WPOINT.new(3291,3555,0))
            UTILS.countTicks(1)
            UTILS.surge()
            --activate_dive(3303,3563,0)
        end
        API.DoAction_Tile(WPOINT.new(3303,3563,0))
        UTILS.SleepUntil(function() return API.PInArea(3303, 2, 3563, 2, 0) end, 10, "Arrived at Townhall")
        Task = 2
    end,
    walkToBlueprintTable = function()
        API.DoAction_Tile(WPOINT.new(3302,3559,0))
        UTILS.SleepUntil(function() return API.PInArea(3302, 2, 3559, 2, 0) end, 10, "Surge spot")
        UTILS.surge()
        API.DoAction_Tile(WPOINT.new(3288,3555,0))
        UTILS.SleepUntil(function() return API.PInArea(3288, 1, 3555, 1, 0) end, 10, "Arrived at Blueprint")
        Task = 0
    end
}, {
    label = "Town Hall Tier 3",
    blueprintNumber = blueprints.townhallt3,
    stonePerBuild = 6,
    frameName = "Magic frame",
    framePerBuild = 60,
    materials = function() return Inventory:InvItemcountStack_Strings("Stone wall segment") <= 5 or Inventory:InvItemcountStack_Strings("Magic frame") <= 59
    end,
    walkToLocation = function()
        if API.PInArea(3288, 1, 3555, 1, 0) then 
            API.DoAction_Tile(WPOINT.new(3291,3555,0))
            UTILS.countTicks(1)
            UTILS.surge()
            --activate_dive(3303,3563,0)
        end
        API.DoAction_Tile(WPOINT.new(3303,3563,0))
        UTILS.SleepUntil(function() return API.PInArea(3303, 2, 3563, 2, 0) end, 10, "Arrived at Townhall")
        Task = 2
    end,
    walkToBlueprintTable = function()
        API.DoAction_Tile(WPOINT.new(3302,3559,0))
        UTILS.SleepUntil(function() return API.PInArea(3302, 2, 3559, 2, 0) end, 10, "Surge spot")
        UTILS.surge()
        API.DoAction_Tile(WPOINT.new(3288,3555,0))
        UTILS.SleepUntil(function() return API.PInArea(3288, 1, 3555, 1, 0) end, 10, "Arrived at Blueprint")
        Task = 0
    end
}, {
    label = "Workshop Tier 1",
    blueprintNumber = blueprints.workshopt1,
    stonePerBuild = 6,
    frameName = "Wooden frame",
    framePerBuild = 8,
    materials = function() return Inventory:InvItemcountStack_Strings("Stone wall segment") <= 5 or Inventory:InvItemcountStack_Strings("Wooden frame") <= 7
    end,
    walkToLocation = function()
        Task = 2
    end,
    walkToBlueprintTable = function()
        API.DoAction_Tile(WPOINT.new(3286,3555,0)) -- API.DoAction_Tile(WPOINT.fromLocal(22,35,0))
        UTILS.SleepUntil(function() return API.PInArea(3286, 1, 3555, 1, 0) end, 10, "Arrived at Blueprint")
        Task = 0
    end
}
}

btnStart = API.CreateIG_answer()
btnStart.box_start = FFPOINT.new(20, 149, 0)
btnStart.box_name = " START "
btnStart.box_size = FFPOINT.new(90, 50, 0)
btnStart.colour = ImColor.new(0, 255, 0)
btnStart.string_value = "START"

IG_Text = API.CreateIG_answer()
IG_Text.box_name = "TEXT"
IG_Text.box_start = FFPOINT.new(16, 79, 0)
IG_Text.colour = ImColor.new(196, 141, 59);
IG_Text.string_value = "Fort Builder AIO" --What is it example - Primal Ore AIO

IG_Back = API.CreateIG_answer()
IG_Back.box_name = "back"
IG_Back.box_start = FFPOINT.new(5, 64, 0)
IG_Back.box_size = FFPOINT.new(226, 200, 0)
IG_Back.colour = ImColor.new(15, 13, 18, 255)
IG_Back.string_value = ""

aioSelectC.box_name = "###Construction"                 --3x #Blanks out the text for the Gui. The box needs to be labelled
aioSelectC.box_start = FFPOINT.new(32, 94, 0)
aioSelectC.box_size = FFPOINT.new(240, 0, 0)
aioSelectC.stringsArr = {}
aioSelectC.tooltip_text = "" --Mouses over the drop down and populates whats in here

table.insert(aioSelectC.stringsArr, "Choose what you want to build") --Top of the drop down menu
for i, v in ipairs(mainVariable) do
    table.insert(aioSelectC.stringsArr, v.label)
end

API.DrawSquareFilled(IG_Back)
API.DrawTextAt(IG_Text)
API.DrawBox(btnStart)
API.DrawComboBox(aioSelectC, false)

----------------------------------------------------------------------
--                              GUI
----------------------------------------------------------------------

local function round(val, decimal) -- rounds up from 0.25 to the nearest whole number (useful for excluding diagonal objects from being 1 tile away)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.75) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

----------------------------------------------------------------------
--                         BUILDING LOGIC
----------------------------------------------------------------------
local function findobjtile()
    local Right = API.ReadAllObjectsArray({0}, {125061}, {})
    for _k, v in pairs(Right) do
        return v
    end
    return nil
end

local lastHotspotX = nil
local lastHotspotY = nil

local function clickHotspot()
    local hotspot = findobjtile()
    if not hotspot then return false end
    local x = hotspot.CalcX
    local y = hotspot.CalcY
    local tile = WPOINT.new(x, y, 0)
    API.DoAction_Object2(0x29, API.OFF_ACT_GeneralObject_route0, {125061}, 30, tile)
    -- stores the last hotspot
    lastHotspotX = x
    lastHotspotY = y
    dbg("X position: "..lastHotspotX.." | ".. "Y Position: " ..lastHotspotY)
    UTILS.SleepUntil(function() return API.PInArea(hotspot.CalcX, 2, hotspot.CalcY, 2, 0) end, 10, "Moved to new hotspot")
    return true
end

local function hotspotChanged()
    local hotspot = findobjtile()
    if not hotspot then return false end
    return hotspot.CalcX ~= lastHotspotX or hotspot.CalcY ~= lastHotspotY
end

local function aminexttoahotspot() 
    hotspot = findobjtile()
    tile = WPOINT.new(hotspot.CalcX, hotspot.CalcY, 0)
    if round(hotspot.Distance, 0) <= 1.5 then
        return true
    end
    return false
end


local blueprintSelected = false

local function selectingWhatToZugZug()
    API.DoAction_Object1(0xae,API.OFF_ACT_GeneralObject_route0,{ 125059 },50)
    API.RandomSleep2(1200, 100, 200)
    if UTILS.isCraftingInterfaceOpen() then 
        if blueprintSelected == false then
            dbg("First time - Choosing Blueprint")
            API.DoAction_Interface(0xffffffff,0xffffffff,1,1371,22,selectedBlueprint,API.OFF_ACT_GeneralInterface_route)
            blueprintSelected = true
        end
        API.RandomSleep2(1000, 100, 200)
        dbg("Confirming Selected Blueprint")
        API.DoAction_Interface(0xffffffff,0xffffffff,0,1370,30,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        API.RandomSleep2(1100, 100, 200)

        lastHotspotX = nil
        lastHotspotY = nil
        completedBuilds = completedBuilds + 1
        stoneUsed = stoneUsed + selectedStonePerBuild
        framesUsed = framesUsed + selectedFramePerBuild

        Task = 1
    end
end

local function ofToWorkThen()
    local hotspot = findobjtile()
    if hotspot then
        if hotspotChanged() then
            dbg("Mother fucking bastard keeps moving")
            if not aminexttoahotspot() then
                dbg("Lel we're a bot huhuhu")
            end
            clickHotspot()
        end
    else
        dbg("No hotspots left - The Ziggurats is complete")
        Task = 3
    end
end

----------------------------------------------------------------------
--                       BUILDING LOGIC END
----------------------------------------------------------------------

local function handleElidinisEvents()
    local lostSoul = 17720
    local unstableSoul = 17739
    local mimickingSoul = 18222
    local vengefulSoul = 17802
    local eventIDs = { lostSoul, unstableSoul, mimickingSoul, vengefulSoul }

    local found = false
    local eventObjs = API.GetAllObjArray1(eventIDs, 50, { 1 })
    if #eventObjs > 0 then
        print("Elidinis soul detected!")
        found = true
    end

    local originTile = API.PlayerCoordfloat()
    while #eventObjs > 0 and API.Read_LoopyLoop() do
        if eventObjs[1].Id == mimickingSoul then
           -- API.DoAction_Dive_Tile(eventObjs[1].Tile_XYZ) 
            API.DoAction_TileF(eventObjs[1].Tile_XYZ)
        elseif eventObjs[1].Id == unstableSoul or eventObjs[1].Id == lostSoul then
            -- API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { eventObjs[1].Id }, 50)
            API.DoAction_NPC__Direct(0x29, API.OFF_ACT_InteractNPC_route, eventObjs[1])
        end

        API.RandomSleep2(1000, 250, 500)
        eventObjs = API.GetAllObjArray1(eventIDs, 50, { 1 })
    end

    if found then API.DoAction_TileF(originTile) end
end

----------------------------------------------------------------------
--                           MAIN BODY
----------------------------------------------------------------------

local function Metrics()
    local elapsedMinutes = (os.time() - startTime) / 60
    local buildsPH = 0

    if elapsedMinutes > 0 then
        buildsPH = math.floor((completedBuilds * 60) / elapsedMinutes)
    end

    local metrics = {
        {"Script", "Arshalo's AIO Fort Builder"},
        {"Runtime:", formatElapsedTime(startTime)},
        {"Builds:", formatNumber(completedBuilds)},
        {"Builds/H:", formatNumber(buildsPH)},        
        {"Frame Type:", selectedFrameName or "N/A"},
        {"Frames Used:", formatNumber(framesUsed)},
        {"Stone Used:", formatNumber(stoneUsed)},
    }

    API.DrawTable(metrics)
end

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ LOOPY LOOPY @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

API.Write_LoopyLoop(true)
while (API.Read_LoopyLoop()) do

----------------------------------------------------------------------
--                              GUI
----------------------------------------------------------------------
    local elapsedMinutes = (os.time() - startTime)
    if scriptPaused == false then
        if btnStart.return_click then
            btnStart.return_click = false
            btnStart.box_name = " START "
            scriptPaused = true
        end
    end
    if scriptPaused == true then
        if btnStart.return_click then
            btnStart.return_click = false
            btnStart.box_name = " PAUSE "
            IG_Back.remove = true
            btnStart.remove = true
            IG_Text.remove = true
            aioSelectC.remove = true
            MAX_IDLE_TIME_MINUTES = 15
            scriptPaused = false
            print("Script started!")
            API.logDebug("Info: Script started!")
            if firstRun then
                startTime = os.time()
            end
            if (aioSelectC.return_click) then
                aioSelectC.return_click = false
                for i, v in ipairs(mainVariable) do
                    if (aioSelectC.string_value == v.label) then
                        selectedLabel = v.label --Assigning the Variable label to "selectedLabel"
                        selectedBlueprint = v.blueprintNumber
                        selectingBackDoor = v.walkToLocation
                        selectedMaterial = v.materials
                        selectedReturn = v.walkToBlueprintTable
                        selectedStonePerBuild = v.stonePerBuild
                        selectedFramePerBuild = v.framePerBuild
                        selectedFrameName = v.frameName
                    end
                end
            end
            if mainVariable == nil then
                API.Write_LoopyLoop(false)
                print("Promps the user to select an option") --Change to what this is
                API.logError("Promps the user to select an option")
            end
        end
        goto continue
    end

----------------------------------------------------------------------
--                              GUI
----------------------------------------------------------------------

    if Task == 0 then
        dbg("Task - 0 - Selecting Blueprint")
        if selectedMaterial and selectedMaterial() then
            dbg("Materials too low - Be less poor and buy more from GE")
            API.Write_LoopyLoop(false)
            return
        end    
        selectingWhatToZugZug()
    elseif Task == 1 then
        dbg("Task - 1 - Sliding to location hisss!")
        selectingBackDoor()
    elseif Task == 2 then
        --dbg("Task - 2 - Building... Construction complete, Building")
        ofToWorkThen()
    elseif Task == 3 then
        dbg("Task - 3 - Returning to build more Ziggurats ")
        selectedReturn()
    end

::continue::
    idleCheck()
    Metrics()
    API.DoRandomEvents()
    API.DoRandomEvent(23855)
    API.RandomSleep2(200, 200, 200)
end