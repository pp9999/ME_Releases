--[[

@title AsoDiv
@description Siphons Wisps at whatever colony you start at, Prioritizes enriched if available.
@author Asoziales <discord@Asoziales>
@date 06/08/2024
@version 1.2 ~ fixed unique errors when dunking
@Credits to dead for ID Table

Message on Discord for any Errors or Bugs

Start at desired Colony with Dumping option pre selected

--]]

local API = require("api")
local UTILS = require("utils")

startTime, afk = os.time(), os.time()
MAX_IDLE_TIME_MINUTES = 15

local IDS = {
    CHRONICLE = { 18205, 51489 },
    RIFTS = {
        87306,
        93489,
    },
    ENRICHED_SPRING = {
        18152, 18175, -- flicker
        18154, 18177, -- bright
        18156, 18179, -- glowing
        18158, 18181, -- spark
        18160, 18183, -- gleam
        18162, 18185, -- vibrant
        18164, 18187, -- lust
        18166, 18189, -- brilliant
        18168, 18191, -- radiant
        18170, 18193, -- lumi
        18172, 18195, -- incan
        13615, 13617, -- eleder
    },
    SPRING = {
        18173,
        18174,
        18176,
        18178,
        18180,
        18182,
        18184,
        18186,
        18188,
        18190,
        18192,
        18194,
        13616,
    },
    WISPS = {
        18150, -- pale
        18151, -- flicker
        18153, -- bright
        18155, -- glow
        18157, -- spark
        18159, -- gleam
        18161, -- vibrant
        18163, -- lust,
        18165, -- brilliant
        18167, -- radiant
        18169, -- lumi
        18171, -- incan
        13614, --elder
    }
}

function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

function foundNPC(npcid)
    return #API.ReadAllObjectsArray({1}, npcid, {}) > 0
end

local function catchChronicle()
    if API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,IDS.CHRONICLE,50) then
        API.WaitUntilMovingEnds(10,2)
    end
end

local function gatherEnriched()
    if API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, IDS.ENRICHED_SPRING, 50) then
        UTILS.countTicks(4)
        return true else
        if not foundNPC(IDS.ENRICHED_SPRING) then return false end
    end
end

local function gather()
    catchChronicle()
    if API.InvFull_() then return end
    if API.CheckAnim(25) then return end
    if API.ReadPlayerMovin2() then return end
    if gatherEnriched() then return end
    if foundNPC(IDS.SPRING) then
        API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, IDS.SPRING, 50)
        UTILS.countTicks(4)
    elseif foundNPC(IDS.WISPS) then
        API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, IDS.WISPS, 50)
        UTILS.countTicks(4)
    end
end

function dunkmaster()
    if API.InvFull_() then
        API.DoAction_Object_string1(0xc8, API.OFF_ACT_GeneralObject_route0, { "Energy rift", "Energy Rift" }, 50,true) 
        API.WaitUntilMovingandAnimEnds(50,2)
    end
end

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    
    API.DoRandomEvents()
    gather()
    dunkmaster()
    idleCheck()
    API.RandomSleep2(200,300,200)
end

