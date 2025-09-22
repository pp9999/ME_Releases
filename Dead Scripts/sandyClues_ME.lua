--[[
# Script Name:   SandInYoPants™
# Description:  <Solves Sandy Clues during the Beach Event>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <1.2>
# Datum:        <2024.07.24>
--]]

local API = require("api")
local UTILS = require("utils")

local IDS = {
    CLUE = 43349,
    SCROLL_BOX = 43351
}

local function gotoTile(wpoint)
    if API.Dist_FLPW(wpoint) < 20 then return end
    math.randomseed(os.time())
    API.DoAction_WalkerW(WPOINT.new(wpoint.x + math.random(-5,5),wpoint.y + math.random(-5,5),wpoint.z))
end

local function isClueDialogOpen()
    local inter = { { 345, 9, -1, -1, 0 }, { 345, 11, -1, 9, 0 }, { 345, 4, -1, 11, 0 } }
    local founds = API.ScanForInterfaceTest2Get(false, inter)
    if #founds > 0 then
        return founds[1].xs > 0
    end
    return false
end

local function isNPCDialogOpen()
    local inter = { { 1184, 2, -1, -1, 0 }, { 1184, 15, -1, 2, 0 } }
    local founds = API.ScanForInterfaceTest2Get(false, inter)
    if #founds > 0 then
        return founds[1].xs > 0
    end
    return false
end

local function isScrollBoxDialogOpen()
    local inter = { { 1189, 2, -1, -1, 0 }, { 1189, 3, -1, 2, 0 } }
    local founds = API.ScanForInterfaceTest2Get(false, inter)
    if #founds > 0 then
        return founds[1].xs > 0
    end
    return false
end

local function isShopInteractDialogOpen()
    local inter = { { 1186, 2, -1, -1, 0 }, { 1186, 8, -1, 2, 0 } }
    local founds = API.ScanForInterfaceTest2Get(false, inter)
    if #founds > 0 then
        return founds[1].xs > 0
    end
    return false
end

local function takeScroll()
    gotoTile(WPOINT.new(3180,3241,0))
    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route4, { 21146 }, 70)
    if UTILS.SleepUntil(isNPCDialogOpen, 10, 'take scroll') then
        UTILS.countTicks(3)
        if not API.InvItemFound1(IDS.CLUE) then
            print('no more clues, exiting')
            API.Write_LoopyLoop(false)
        end
    end
end

local function dungHole()
    gotoTile(WPOINT.new(3170,3252,0))
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { 114121 }, 70)
    if UTILS.SleepUntil(isScrollBoxDialogOpen, 20, 'scroll') then
        UTILS.countTicks(2)
    end
end

local function sarah()
    gotoTile(WPOINT.new(3169,3220,0))
    API.DoAction_NPC(0x2c, API.OFF_ACT_InteractNPC_route, { 21153 }, 70)
    if UTILS.SleepUntil(isNPCDialogOpen, 10, 'choose option') then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1184, 15, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        UTILS.countTicks(3)
    end
end

local function lifeguard()
    gotoTile(WPOINT.new(3170,3252,0))
    API.DoAction_NPC(0x2c, API.OFF_ACT_InteractNPC_route, { 21158 }, 70)
    if UTILS.SleepUntil(isNPCDialogOpen, 10, 'choose option') then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1184, 15, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        UTILS.countTicks(2)
    end
end

local function palmer()
    gotoTile(WPOINT.new(3154,3227,0))
    API.DoAction_NPC(0x2c, API.OFF_ACT_InteractNPC_route, { 21152 }, 70)
    if UTILS.SleepUntil(isNPCDialogOpen, 10, 'choose option') then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1184, 15, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        UTILS.countTicks(2)
    end
end

local function foreman()
    gotoTile(WPOINT.new(3158,3227,0))
    API.DoAction_NPC(0x2c, API.OFF_ACT_InteractNPC_route, { 21163 }, 70)
    if UTILS.SleepUntil(isNPCDialogOpen, 10, 'choose option') then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1184, 15, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        UTILS.countTicks(2)
    end
end

local function flo()
    gotoTile(WPOINT.new(3166,3217,0))
    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { 21148 }, 70)
    if UTILS.SleepUntil(isShopInteractDialogOpen, 20, 'shopper') then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1186, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        UTILS.countTicks(3)
    end
end

local function sheldon()
    gotoTile(WPOINT.new(3170,3252,0))
    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { 21147 }, 70)
    if UTILS.SleepUntil(isShopInteractDialogOpen, 20, 'shopper') then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1186, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        UTILS.countTicks(3)
    end
end

local function wellington()
    gotoTile(WPOINT.new(3180,3241,0))
    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { 21150 }, 70)
    if UTILS.SleepUntil(isNPCDialogOpen, 10, 'choose option') then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1184, 15, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        UTILS.countTicks(3)
    end
end

local function coconuts()
    gotoTile(WPOINT.new(3169,3220,0))
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ 97332 },50)
    if UTILS.SleepUntil(isScrollBoxDialogOpen, 20, 'scroll') then
        UTILS.countTicks(3)
    end
end

local function fishTable()
    gotoTile(WPOINT.new(3180,3241,0))
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ 97277 },50)
    if UTILS.SleepUntil(isScrollBoxDialogOpen, 20, 'scroll') then
        UTILS.countTicks(3)
    end
end

local function palmTree()
    gotoTile(WPOINT.new(3180,3241,0))
    API.DoAction_Object2(0x29,API.OFF_ACT_GeneralObject_route0,{ 117512 },50,WPOINT.new(3186,3240,0))
    if UTILS.SleepUntil(isScrollBoxDialogOpen, 20, 'scroll') then
        UTILS.countTicks(3)
    end
end

local MESSAGES = {
    SARAH = "She can be trusted, she isn't shy and ",
    LIFEGUARD = "say he sits around watching beach ",
    PALMER = "palm of his hand. Others think he's just ",
    FOREMAN = "an endless stream of important ",
    FLO = "share common ground with the ",
    SHELDON = "He's got one hat, two hat, three hat, ",
    WELLINGTON = "He's named after a boot, and carrying ",
    HOLE = "Investigate a large hole that leads...  ",
    COCONUTS = "Somewhere a dwarf looks after a pile ",
    FISH_TABLE = "Something smells fishy behind a dwarf ",
    PALM_TREE = "Pick some coconuts that are oh so "
}

local function getClueText()
    local inter = { { 345, 9, -1, -1, 0 }, { 345, 11, -1, 9, 0 }, { 345, 4, -1, 11, 0 } }
    local texts = API.ScanForInterfaceTest2Get(false, inter)
    if #texts > 0 then
        return texts[1].textids
    end
    return nil
end

local function solveClue()
    local message = getClueText()
    if message ~= nil then
        if MESSAGES.FLO:find(message) then
            flo()
        elseif MESSAGES.FOREMAN:find(message) then
            foreman()
        elseif MESSAGES.LIFEGUARD:find(message) then
            lifeguard()
        elseif MESSAGES.PALMER:find(message) then
            palmer()
        elseif MESSAGES.SARAH:find(message) then
            sarah()
        elseif MESSAGES.SHELDON:find(message) then
            sheldon()
        elseif MESSAGES.WELLINGTON:find(message) then
            wellington()
        elseif MESSAGES.HOLE:find(message) then
            dungHole()
        elseif MESSAGES.COCONUTS:find(message) then
            coconuts()
        elseif MESSAGES.FISH_TABLE:find(message) then
            fishTable()
        elseif MESSAGES.PALM_TREE:find(message) then
            palmTree()
        else
            print('unknown message')
            API.Write_LoopyLoop(false)
        end
    else
        print('message is empty')
        API.Write_LoopyLoop(false)
    end
end

while API.Read_LoopyLoop() do
    if API.InvItemFound1(IDS.SCROLL_BOX) then
        print('scroll')
        API.DoAction_Inventory1(IDS.SCROLL_BOX, 0, 1, API.OFF_ACT_GeneralInterface_route)
        UTILS.countTicks(3)
    elseif API.InvItemFound1(IDS.CLUE) then
        API.DoAction_Inventory1(IDS.CLUE, 0, 1, API.OFF_ACT_GeneralInterface_route)
        UTILS.SleepUntil(isClueDialogOpen, 10, 'clue')
        UTILS.countTicks(3)
        solveClue()
    else
        takeScroll()
    end
    UTILS.rangeSleep(600, 0, 0)
end
