local API = require("api")
local UTILS = require("utils")
API.Write_fake_mouse_do(false)
local Wartp = API.GetABs_name1("War's Retreat Teleport")


local spaces = {
    { id = 66115, pos = WPOINT.new(3557, 3298, 0) , npc = 2030 , stairs = 6707, chest = 66016},
    { id = 66116, pos = WPOINT.new(3554, 3282, 0) , npc = 2029 , stairs = 6706, chest = 66019},
    { id = 66115, pos = WPOINT.new(3564, 3277, 0) , npc = 2028 , stairs = 6705, chest = 66018},
    { id = 66116, pos = WPOINT.new(3567, 3288, 0) , npc = 2025 , stairs = 6702, chest = 66017},
    { id = 66116, pos = WPOINT.new(3575, 3298, 0) , npc = 2026 , stairs = 6703, chest = 63177},
    { id = 66115, pos = WPOINT.new(3576, 3281, 0) , npc = 2027 , stairs = 6704, chest = 66020}
}
local portals    = {132113, 132112}
local finalChest = 6774
local lootChest  = 10284
local ropeID     = {6711,6708}


local deferredSpace = nil
local function war()
    API.DoAction_Ability_Direct(Wartp, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(5000, 500, 500)
    API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route3,{ 114750 },50);
    API.WaitUntilMovingEnds(20, 10)
    API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ 114763 },50);
    API.WaitUntilMovingEnds(20, 10)
    API.RandomSleep2(2000, 500, 500)
end

local function waitForCombatEnd()
    while API.LocalPlayer_IsInCombat_() do
        API.Sleep_tick(3)
    end
end

local function interactWithSpace(i)
    local space = spaces[i]
    API.DoAction_Object2(0x29, API.OFF_ACT_GeneralObject_route0, { space.id }, 50, space.pos)
    UTILS.countTicks(2)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(2000, 500, 500)
    print("looking for chest")
        API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { space.chest }, 15)
        API.WaitUntilMovingEnds(5, 5)
    
    if UTILS.isChooseOptionInterfaceOpen() then
        deferredSpace = i
        print("boss chamber")
            API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { space.stairs }, 15)
            API.WaitUntilMovingEnds(5, 5)
   else
            print("fighting mob")
            API.DoAction_NPC(0x2a,API.OFF_ACT_AttackNPC_route,{ space.npc },15)
            API.RandomSleep2(2000, 500, 500)
            waitForCombatEnd()
            API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { space.stairs }, 15)
            API.WaitUntilMovingEnds(5, 5)
    end
end

local function processDeferredSpace()
    local i = deferredSpace
    local space = spaces[i]

    API.DoAction_Object2(0x29, API.OFF_ACT_GeneralObject_route0, { space.id }, 50, space.pos)
    UTILS.countTicks(2)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(2000, 500, 500)
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { space.chest }, 15)
    API.WaitUntilMovingEnds(5, 5)
    API.RandomSleep2(1000, 500, 500)
    API.DoAction_Interface(0xFFFFFFFF, 0xFFFFFFFF, 0, 1186, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
    API.RandomSleep2(1000, 500, 500)  
    API.DoAction_Interface(0xFFFFFFFF, 0xFFFFFFFF, 0, 1188, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
    API.RandomSleep2(3000, 500, 500)

    for _, pid in ipairs(portals) do
        API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { pid }, 15)
        API.WaitUntilMovingEnds(10, 5)
    end

    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { 6774 }, 10)
    API.WaitUntilMovingEnds(5, 5)

    API.DoAction_NPC(0x2a,API.OFF_ACT_AttackNPC_route,{ space.npc },15)
    API.RandomSleep2(2000, 500, 500)
    waitForCombatEnd()
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { 6775 }, 15)
    API.WaitUntilMovingEnds(5, 5)
    API.DoAction_Interface(0x24, 0xFFFFFFFF, 1, 168, 18, -1, API.OFF_ACT_GeneralInterface_route)
    API.Sleep_tick(3)

    for _, pid in ipairs(portals) do
        API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { pid }, 10)
        API.WaitUntilMovingEnds(5, 5)
        API.RandomSleep2(2000, 500, 500)
    end

    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { 6708 }, 15)
    API.WaitUntilMovingEnds(5, 5)
    API.RandomSleep2(2000, 500, 500)
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { space.stairs }, 15)
    API.WaitUntilMovingEnds(5, 5)
    API.RandomSleep2(2000, 500, 500)
end


-- Main loop
while (API.Read_LoopyLoop()) do
    API.DoRandomEvents()
    for i = 1, #spaces do
        interactWithSpace(i)
    end

    if deferredSpace then
        processDeferredSpace()
        deferredSpace = nil
        API.printlua("Sequence complete", 1, true)
    end
    if API.Invfreecount_() < 5 then
        war()
    end
end
