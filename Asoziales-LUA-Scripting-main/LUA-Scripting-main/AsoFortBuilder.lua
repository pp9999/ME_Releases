--[[

@title AsoFortBuilder
@description Builds within Fort Forinthy
@author Asoziales <discord@Asoziales>
@date 9/1/2024
@version 1.3 ~ fixed Distance finding with new ME logic

Message on Discord for any Errors or Bugs
Credit to @higginshax for UI Template and some funcs

This version supports TownHall but i can easily add extra buildings if requested.

xp/hr is roughly 720k/hr with con outfit and an aditional 10,646.5 xp/hr in bonus xp from townhall passive

Change settings below - max idle time check
Ensure you have Magic Frames and Stone Wall Segments in inventory = to how many building you wanna make (60 frames and 6 segments per building)
Be standing somewhere inside of Fort Forinthy
Start script

--]]

local API = require("api")

--[[ settings ]]
MAX_IDLE_TIME_MINUTES = 5
startXp = API.GetSkillXP("CONSTRUCTION")

--[[ Main Script Body ]]--

startTime, afk = os.time(), os.time()
 state = nil
 firstrun = true


print("Starting AsoFortBuilder! Startxp: " .. startXp)

local function round(val, decimal) -- rounds up from 0.25 to the nearest whole number (useful for excluding diagonal objects from being 1 tile away)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.75) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function walktoTHall() -- Walks to the TownHall Building
    API.DoAction_Tile(WPOINT.new( 3303 + API.Math_RandomNumber(4), 3565 + API.Math_RandomNumber(4), 0))
    API.RandomSleep2(1050, 1000, 1000)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(1050, 1000, 1000)
end

function findobjtile() -- Iterates data from the optimal location
    Right = API.GetAllObjArray1({125061}, 50, 0);
    for _k, v in pairs(Right) do
        -- print("found")
            return v
    end
    -- print("false")
    return false
end


function clickHotspot() -- uses iterated data to determine Optimal Construction hotspots TileXY then clicks
    hotspot = findobjtile()
    if  hotspot then
        tile = WPOINT.new(hotspot.CalcX, hotspot.CalcY, 0)
        API.DoAction_Object2(0x29, 0, {125061}, 30, tile);
        API.RandomSleep2(600, 800, 1000);
        API.WaitUntilMovingEnds()
        return true
    end
    return false
end

function resethotspots() -- Paths to the Blueprint table and reselects a TownHall Blueprint then paths back to Townhall
    print("walking to BP table")
    API.DoAction_Tile(WPOINT.new( 3285 + API.Math_RandomNumber(4), 3555 + API.Math_RandomNumber(4), 0))
    print("walking to BP table")
    API.RandomSleep2(1050, 1000, 1000)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(300, 300, 1000)
    API.DoAction_Object1(0x29,0,{125059},7)
    print("Selecting TownHall BP")
    API.RandomSleep2(1800, 600, 1200)
    API.DoAction_Interface(0xffffffff,0xffffffff,1,1371,22,21,5392)
    API.RandomSleep2(1800, 600, 1200)
    API.KeyboardPress2(0x20, 60, 100)
    API.RandomSleep2(1200, 600, 1200)
    print("returning to TownHall")
    walktoTHall()
end
    
function aminexttoahotspot() -- sleeps while next to optimal hotspot
    hotspot = findobjtile()
    tile = WPOINT.new(hotspot.CalcX, hotspot.CalcY, 0)
    if round(hotspot.Distance, 0) <= 1.5 then
        --print(hotspot.Distance/512, " Tiles away") -- debug
        return true
    end
return false
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

function formatNumber(num)
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
    local skill = "CONSTRUCTION"
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
    " | " ..
    string.lower(skill):gsub("^%l", string.upper) ..
    ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(220,172,62);
    IGP.string_value = "AsoFortBuilder"
end

function drawGUI()
    DrawProgressBar(IGP)
end

local function detectOBJ(npcid, distance)
    local distance = distance or 50
    return #API.GetAllObjArrayInteract({npcid}, distance, 0) > 0
end

setupGUI()

while (API.Read_LoopyLoop()) do

    idleCheck()
    drawGUI()

    if API.PInArea(3299, 15, 3563, 15, 0) then
        if API.PInArea(3299, 15, 3563, 15, 0) and not detectOBJ(125061) then -- and no hotspots are found
            print("no Hotspots found")
            resethotspots()
        else
            if not aminexttoahotspot() then -- hotspot has moved
                print("Clicking Next Location")
                clickHotspot()
                API.WaitUntilMovingEnds()
                API.RandomSleep2(1800, 600, 1800)
            end
            API.RandomSleep2(600, 300, 600)
            goto continue
        end
        if not API.PInArea(3299, 15, 3563, 15, 0) then -- not in townhall
            print("not within Townhall Bounds, rectifying")
            walktoTHall()
        end

        if API.InvItemcountStack_String("Magic frame") <= 59 or API.InvItemcountStack_String("Stone wall segment") <= 5 and
            not findobjtile() then
            print("out of resources")
            break
        end
    end

    ::continue::
    API.DoRandomEvents()
    printProgressReport()
    API.RandomSleep2(100, 200, 200)
end
