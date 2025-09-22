local API = require("api")
local UTILS = require("utils")
local player = API.GetLocalPlayerName()
--API.SetDrawTrackedSkills(true)
API.Write_fake_mouse_do(false)
API.SetMaxIdleTime(10)
local PRAYER_BUFF = 25959
local Part_1_DONE = false
local Part_2_DONE = false
local Part_3_DONE = false
local Part_4_DONE = false
local Part_5_DONE = false
local CerberusIsDead = false

local function run_to_tile(x, y, z)
    math.randomseed(os.time())

    --local rand1 = math.random(-2, 2)
    --local rand2 = math.random(-2, 2)
    local tile = WPOINT.new(x, y, z)

    API.DoAction_WalkerW(tile)

    local threshold = math.random(3, 4)
    while API.Read_LoopyLoop() and API.Math_DistanceW(API.PlayerCoord(), tile) > threshold do
        API.RandomSleep2(200, 200, 200)
    end
end

local function findNPC(npcid, distance)
    local distance = distance or 10
    return #API.GetAllObjArrayInteract({ npcid }, distance, { 1 }) > 0
end

local function Tele_To_ED4()
    if Part_1_DONE == false and Part_2_DONE == false and Part_3_DONE == false and Part_4_DONE == false and Part_5_DONE == false then
        print("Teleporting to ED4")
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1519, 72, -1, API.OFF_ACT_GeneralInterface_route)              -- leave current group
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1519, 77, -1, API.OFF_ACT_GeneralInterface_route)              -- grouping interface, create group
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1431, 0, 4, API.OFF_ACT_GeneralInterface_route)          -- open social interface
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1477, 734, 15, API.OFF_ACT_GeneralInterface_route)       -- switch to grouping system section
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1524, 11, 56, API.OFF_ACT_GeneralInterface_route)        -- select zammy undercity
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1524, 21, -1, API.OFF_ACT_GeneralInterface_route)              -- click "view selected"
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1524, 115, -1, API.OFF_ACT_GeneralInterface_route)             -- click "update group"
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1188, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option) -- discard old progress
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1528, 31, -1, API.OFF_ACT_GeneralInterface_route)              -- click ready
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1527, 12, -1, API.OFF_ACT_GeneralInterface_route)              -- click all ready
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1188, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option) -- click tele all group members
        API.RandomSleep2(2500, 300, 900)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1477, 737, 1, API.OFF_ACT_GeneralInterface_route)              -- close the interface
        API.RandomSleep2(2500, 300, 900)
        Part_1_DONE = true
    end
end

local function Begin_Run()
    if Part_1_DONE == true and Part_2_DONE == false and Part_3_DONE == false and Part_4_DONE == false and Part_5_DONE == false then
        print("Dungeon run starting...")
        API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, { 124285 }, 50)                               -- use lift
        API.RandomSleep2(2700, 300, 900)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1188, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option) -- normal mode
        API.RandomSleep2(3300, 300, 900)
        API.KeyboardPress2(49, 60, 600)                                                                            -- number 1
        API.RandomSleep2(1800, 300, 600)
        API.KeyboardPress2(50, 60, 600)                                                                            -- number 2
        API.RandomSleep2(1800, 300, 600)
        API.KeyboardPress2(51, 60, 600)                                                                            -- number 3
        API.RandomSleep2(1800, 300, 600)
        run_to_tile(API.PlayerCoord().x, API.PlayerCoord().y + 16, 0)                                              -- first spot, within viewing range of first mobs
        API.RandomSleep2(600, 300, 600)
        run_to_tile(API.PlayerCoord().x, API.PlayerCoord().y + 12, 0)                                              -- center of first mobs
        API.RandomSleep2(600, 300, 600)
        if not API.Buffbar_GetIDstatus(PRAYER_BUFF, false).found then
            API.KeyboardPress2(67, 60, 600) -- Letter C keybind to protect magic
        end
        Part_2_DONE = true
    end
end

local function Bank_At_Wars_Retreat()
    if Part_1_DONE == true and Part_2_DONE == true and Part_3_DONE == true and Part_4_DONE == true and Part_5_DONE == true and CerberusIsDead == true then
        print("Banking for supplies")
        API.DoAction_Interface(0x2e, 0xffffffff, 1, 1670, 188, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(7000, 1000, 2000)
        if API.Buffbar_GetIDstatus(PRAYER_BUFF).found then
            API.KeyboardPress2(67, 60, 600) -- Letter C keybind to protect magic
        end
        API.RandomSleep2(1200, 500, 900)
        API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { 114750 }, 50) -- bank load last preset
        API.RandomSleep2(5000, 900, 1200)
        if not API.InvFull_() then
            print("Ran out of supplies -- ENDING SCRIPT")
            API.Write_LoopyLoop(false)
        end
        API.DoAction_Object1(0x3d, API.OFF_ACT_GeneralObject_route0, { 114748 }, 50) -- altar recharge prayer
        API.RandomSleep2(5000, 900, 1200)
        print("Setting back booleans to false")
        Part_1_DONE = false
        Part_2_DONE = false
        Part_3_DONE = false
        Part_4_DONE = false
        Part_5_DONE = false
        CerberusIsDead = false
        print(Part_1_DONE, " p1 ", Part_2_DONE, " p2 ", Part_3_DONE, " p3 ", Part_4_DONE, " p4 ", Part_5_DONE, " p5 ",
            CerberusIsDead, " cerberus ")
        API.RandomSleep2(900, 600, 600)
    end
end

local function Check_Player_HP()
    --print("Checking player HP")
    if API.GetHPrecent() <= 45 then
        API.KeyboardPress2(70, 60, 100) -- F key
        API.RandomSleep2(500, 100, 300)
    end
end

local function Move_Away_From_Cerberus()
    local cerberusNPC = API.GetAllObjArray1({ 29302 }, 50, { 1 })

    if #cerberusNPC > 0 then
        local cerberus = cerberusNPC[1]

        if cerberus.Tile_XYZ then
            local newTileX = cerberus.Tile_XYZ.x
            local newTileY = cerberus.Tile_XYZ.y - 3
            local newTileZ = cerberus.Tile_XYZ.z

            if not API.PInArea(newTileX, 1, newTileY, 1, newTileZ) then
                print("Moving back from cerberus")
                API.DoAction_WalkerW(WPOINT.new(newTileX, newTileY, newTileZ))
                API.RandomSleep2(1200, 300, 600)
            end
        end
    end
end

local function Fight_Cerberus()
    if Part_1_DONE == true and Part_2_DONE == true and Part_3_DONE == true and Part_4_DONE == true and Part_5_DONE == false then
        print("Fighting Cerberus Juvenile")
        API.WaitUntilMovingandAnimandCombatEnds(3, 7)
        API.DoAction_NPC_str(0x2a, API.OFF_ACT_AttackNPC_route, { "Cerberus Juvenile" }, 50)
        API.WaitUntilMovingandAnimandCombatEnds(3, 7)
        print("Moving back from cerberus")
        Move_Away_From_Cerberus()
        API.RandomSleep2(2000, 600, 900)
        if not API.LocalPlayer_IsInCombat_() and not findNPC(29302, 50) then
            CerberusIsDead = true
            Part_5_DONE = true
        end
    end
end

local function Walk_To_Safe_Spot()
    if Part_1_DONE == true and Part_2_DONE == true and Part_3_DONE == true and Part_4_DONE == false and Part_5_DONE == false then
        print("Walking to safe spot")
        run_to_tile(API.PlayerCoord().x + 30, API.PlayerCoord().y, 0)    -- next to barrel by cerberus
        API.RandomSleep2(2000, 300, 600)
        run_to_tile(API.PlayerCoord().x, API.PlayerCoord().y + 12, 0)    -- close to door safespot
        API.RandomSleep2(2000, 300, 600)
        run_to_tile(API.PlayerCoord().x - 1, API.PlayerCoord().y + 1, 0) -- door safespot tile
        API.RandomSleep2(2000, 300, 600)
    end
    Part_4_DONE = true
end

local function Kill_First_Mobs()
    print("Killing first wizards and witch mender")
    Part_3_DONE = true
end

while API.Read_LoopyLoop() do
    Check_Player_HP()
    if not API.LocalPlayer_IsInCombat_() then
        Tele_To_ED4()
    end
    if not API.LocalPlayer_IsInCombat_() then
        Begin_Run()
    end
    if not API.LocalPlayer_IsInCombat_() then
        Kill_First_Mobs()
    end
    if not API.LocalPlayer_IsInCombat_() then
        Walk_To_Safe_Spot()
    end
    if not API.LocalPlayer_IsInCombat_() then
        Fight_Cerberus()
        if CerberusIsDead then
            Bank_At_Wars_Retreat()
            goto continue
        end
    end
    ::continue::
end
