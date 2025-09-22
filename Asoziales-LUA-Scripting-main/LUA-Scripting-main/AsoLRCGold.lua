--[[

@title AsoLRCGold
@description mines gold in the LRC and deposits 
@author Asoziales <discord@Asoziales>
@date 03/08/24
@version 1.2 ~ Changed looting Logic

Message on Discord for any Errors or Bugs

Start tile next to the Pulley with orebox, have the "Loot Logger" window open somewhere on the screen

--]]

local API = require("api")
local UTILS = require("utils")
local LODE = require("lodestones")

startTime, afk = os.time(), os.time()
MAX_IDLE_TIME_MINUTES = 5
local gold = 0
local version = "1.0"

LOCATIONS = {rock = {x = 3667, y = 5078, radius = 5, z = 0},
             bank = {x = 3655, y = 5113, radius = 8, z = 0}
            }

IDS = {goldDeposit = {113010},
       pulleyLift = {45079},
      }

function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

function gICheck()
    return #API.ReadAllObjectsArray({3}, {444}, {}) > 1
end

local function mine()
    if not API.CheckAnim(20) then
        API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,IDS.goldDeposit,50)
    else
        if API.VB_FindPSett(8308).state > 240 then
            API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,IDS.goldDeposit,50)
            API.RandomSleep2(600, 300, 300)
        end
    end
end

local function fillOreBox()
    if UTILS.getAmountInOrebox() << 100 then
    API.DoAction_Inventory1(44797,0,1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(300,400,200)
    end
end

local function depositOreBox()
    API.DoAction_Inventory1(44797,0,0,API.OFF_ACT_Bladed_interface_route)
    UTILS.countTicks(1)
    API.DoAction_Object1(0x24,API.OFF_ACT_GeneralObject_route00,IDS.pulleyLift,50)
    UTILS.countTicks(1)
    API.WaitUntilMovingEnds()
end

local function loot()
    if API.Invfreecount_() >= 1 then
        if not API.LootWindowOpen_2() and gICheck() then
            API.DoAction_Interface(0xffffffff,0xffffffff,1,1678,8,-1,API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(400,200,300)
        else
         API.DoAction_Loot_w({444}, 10, API.PlayerCoordfloatRaw(), 10)
         UTILS.randomSleep(600)
        API.WaitUntilMovingEnds()
        end
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

function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end


API.Write_LoopyLoop(true)
while (API.Read_LoopyLoop()) do
    ::start::
    local elapsedMinutes = (os.time() - startTime)
    local metrics = {{"Script", "AsoLRCGold - (v" .. version .. ") by Asoziales"}, {"Runtime:", formatElapsedTime(startTime)}, {"Gold deposited:", formatNumber(gold)}
    }
    API.DrawTable(metrics)
    API.SetDrawLogs(true)
    API.SetDrawTrackedSkills(true)

    if API.PInArea(LOCATIONS.rock.x, LOCATIONS.rock.radius, LOCATIONS.rock.y, LOCATIONS.rock.radius, LOCATIONS.rock.z) then
        mine()
        if API.InvFull_() and UTILS.getAmountInOrebox(444) << 99 then
            API.logInfo('Filling Ore Box')
            fillOreBox()
            API.RandomSleep2(500, 200, 100)
        end 
        if API.InvFull_() and UTILS.getAmountInOrebox(444) == 100 then
            API.logWarn('Ore Box full Deposting')
            API.DoAction_WalkerW(WPOINT.new(LOCATIONS.bank.x + math.random(-2, 3),LOCATIONS.bank.y + math.random(-2, 3),LOCATIONS.bank.z))
            API.WaitUntilMovingEnds(20,2)
            goto start
        end
        if API.InvFull_() == false then loot() end

    end

    if API.PInArea(LOCATIONS.bank.x, LOCATIONS.bank.radius, LOCATIONS.bank.y, LOCATIONS.bank.radius, LOCATIONS.bank.z) then
        if API.InvFull_() then
            API.logInfo('Depositing Loose Ore')
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,IDS.pulleyLift,50)
            API.WaitUntilMovingEnds(20,3)
            API.DoAction_Interface(0xffffffff,0x1bc,4,11,19,2,API.OFF_ACT_GeneralInterface_route)
            UTILS.countTicks(1)
            API.DoAction_Interface(0x24,0xffffffff,1,11,23,-1,API.OFF_ACT_GeneralInterface_route)
            UTILS.countTicks(1)
            gold = gold + 27
        end

        if UTILS.getAmountInOrebox(444) == 100 then
            API.logInfo('Depositing Ore Box')
            gold = gold + 100
            depositOreBox()

        end
        
        if not API.InvFull_() and UTILS.getAmountInOrebox(444) == 0 then
            API.logInfo('Walking back to Gold Deposit')
            API.DoAction_WalkerW(WPOINT.new(LOCATIONS.rock.x + math.random(-2, 3),LOCATIONS.rock.y + math.random(-2, 3),LOCATIONS.rock.z))
            API.WaitUntilMovingEnds(20,2)
        end
    end

    idleCheck()
    API.DoRandomEvents()
    API.RandomSleep2(300, 200, 300)
end
