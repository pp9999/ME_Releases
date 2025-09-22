local API = require("api")
local UTILS = require("utils")
local War = API.GetABs_name1("War's Retreat Teleport")
local InventoryItemCounter = {}
local MAX_IDLE_TIME_MINUTES = 5
API.Write_fake_mouse_do(false)
API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)
local familiar_id = 12031

local MetricsTable = {
    {"-", "-"} -- Initiates table with 2 columns
}
local startTime = os.time() 
local counter = 0
local lastUpdateTime = os.time()
local updateFrequency = 0
local count = 0
itemId = 52498
familiar_backpack = 18
local count = ( 26 + familiar_backpack )

function InventoryItemCounter.countItemsById(itemId)
    for _, item in ipairs(Inventory:GetItems()) do
        if item.id == itemId then
            count = count + item.amount
        end
    end
    return count
end
local function formatRunTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end
local function calcIncreasesPerHour()
    local runTimeInHours = (os.time() - startTime) / 3600
    if runTimeInHours > 0 then
        return counter / runTimeInHours
    else
        return 0
    end
end

local function calcAverageIncreaseTime()
    if counter > 0 then
        return (os.time() - startTime) / counter
    else
        return 0
    end
end

function Tracking() -- This is what should be called at the end of every cycle
    counter = counter + 1 
    local runTime = os.time() - startTime
    local increasesPerHour = calcIncreasesPerHour() 
    local avgIncreaseTime = calcAverageIncreaseTime() 

    MetricsTable[1] = {"Total Run Time", formatRunTime(runTime)}
    MetricsTable[2] = {"Total Keys Used", tostring(count)}  -- Add Total items made metric
end


--------going back to temple--------------
local function tp()
    API.DoAction_Inventory1(49429,0,7,API.OFF_ACT_GeneralInterface_route2)
    API.RandomSleep2(4000, 500, 500)
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ 116436 },500);
    API.RandomSleep2(4000, 500, 500)
    API.DoAction_Interface(0xac,0xffffffff,1,667,11,6,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1000, 500, 500)
    API.DoAction_Interface(0x24,0xffffffff,1,667,23,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(4000, 500, 500)
end
--------------------------------------------

local function gameStateChecks()
    local gameState = API.GetGameState2()
    if (gameState ~= 3) then
        API.logError('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
    end
end

local function WalkaToChest()
    local safeX = 1747 + math.random(0, 3)  
    local safeY = 1335 + math.random(3, 7)
    local safeX2 = 1757 + math.random(0, 3)  
    local safeY2 = 1301 + math.random(3, 7)
    API.DoAction_Tile(WPOINT.new(safeX2,safeY2,0))
    API.RandomSleep2(4000, 500, 500)
    API.DoAction_Tile(WPOINT.new(safeX,safeY,0))
    API.WaitUntilMovingEnds(20,2)
end

local function familiar()
    if UTILS.getFamiliarDuration() < 5 then
        API.DoAction_Button_FO(7)
        API.RandomSleep2(2000, 500, 500)
    end
end


local function grabKeys()
    API.DoAction_Ability_Direct(War, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(4000, 500, 500)
    familiar()
    UTILS.randomSleep(600)
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route3,{ 114750 },50);
    API.RandomSleep2(4000, 500, 500)
    API.DoAction_Button_FO(8)
    UTILS.randomSleep(600)
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route3,{ 114750 },50);
    API.RandomSleep2(4000, 500, 500)
    if API.GetSummoningPoints_() < 100 then
        API.DoAction_Object1(0x3d,API.OFF_ACT_GeneralObject_route0,{ 114748 },50);
        API.RandomSleep2(4000, 500, 500)
    end
end


local function OpenChests()
    while API.InvItemFound1(52498) do
        API.DoAction_Object1(0x31,API.OFF_ACT_GeneralObject_route0,{ 122065 },50);
        API.RandomSleep2(1500, 500, 500)
        API.DoAction_Interface(0x24,0xffffffff,1,168,27,-1,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1000, 500, 500)
        if API.CheckFamiliar() == false then
            API.DoAction_Button_FO(7)
            API.RandomSleep2(2000, 500, 500)
        end
        if API.Invfreecount_() == familiar_backpack then
            API.DoAction_Button_FO(9)
            UTILS.randomSleep(600)
        end
    end
    print ("out of keys")
end
while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    gameStateChecks()
    count = ( InventoryItemCounter.countItemsById(itemId)  + familiar_backpack  )
    OpenChests()
    UTILS.randomSleep(600)
    grabKeys()
    UTILS.randomSleep(600)
    Tracking()
    API.DrawTable(MetricsTable)
    UTILS.randomSleep(600)
    tp()
    UTILS.randomSleep(600)
    WalkaToChest()
    UTILS.randomSleep(600)
end