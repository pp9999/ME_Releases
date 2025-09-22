local API = require("api")
local UTILS = require("utils")
local player = API.GetLocalPlayerName()

local firstRun = false
local afk = os.time()

local FOOD = {
    ROCKTAIL = 15272
}

local POTIONS = {
    OVERLOAD_3 = 15333,
    OVERLOAD_2 = 15334,
    OVERLOAD_1 = 15335,
    SUPER_RESTORE_4 = 3024,
    SUPER_RESTORE_3 = 3026,
    SUPER_RESTORE_2 = 3028,
    SUPER_RESTORE_1 = 3030
}

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random(180, 280)
    if timeDiff > randomTime then
        API.DoRandomEvents()
        API.PIdle2()
        afk = os.time()
    end
end

local function checkHP()
    -------------------------------------
    local HP = API.GetHPrecent()
    local PRAYER = API.GetPrayPrecent()
    -------------------------------------
    if not API.Buffbar_GetIDstatus(26093).found then
        API.DoAction_Interface(0x2e, 0x3be5, 1, 1670, 97, -1, API.OFF_ACT_GeneralInterface_route) -- drink overload
    end
    if HP < 60 then
        API.DoAction_Interface(0x2e, 0x3ba8, 1, 1670, 71, -1, API.OFF_ACT_GeneralInterface_route) -- Eat rocktail
        UTILS.countTicks(1)
    end
    if PRAYER < 70 then
        API.DoAction_Interface(0x2e, 0xbd0, 1, 1670, 84, -1, API.OFF_ACT_GeneralInterface_route) -- Drink super retore dose
        UTILS.countTicks(1)
    else
        UTILS.countTicks(1)
    end
end

local function reSupplyNeeded()
    if not API.InvItemFound1(FOOD.ROCKTAIL) then
        print("OUT OF FOOD")
        return true
    end
    if not API.InvItemFound1(POTIONS.OVERLOAD_3) and not API.InvItemFound1(POTIONS.OVERLOAD_2) and not API.InvItemFound1(POTIONS.OVERLOAD_1) then
        print("OUT OF OVERLOAD")
        return true
    end
    if not API.InvItemFound1(POTIONS.SUPER_RESTORE_4) and not API.InvItemFound1(POTIONS.SUPER_RESTORE_3) and not API.InvItemFound1(POTIONS.SUPER_RESTORE_2) and not API.InvItemFound1(POTIONS.SUPER_RESTORE_1) then
        print("OUT OF SUPER RESTORES")
        return true
    end
    if API.InvFull_() then
        print("FULL OF LOOT")
        return true
    end
    return false
end

local function goToSpot()
    if firstRun == false then
        API.DoAction_Interface(0x2e, 0xffffffff, 1, 1671, 183, -1, API.OFF_ACT_GeneralInterface_route) -- wars teleport
        UTILS.countTicks(10)
        API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, { 121370 }, 50)                   -- enter arch glacor portaL
        UTILS.countTicks(16)
        API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, { 121338 }, 50)                   -- aqueduct portal
        UTILS.countTicks(6)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1591, 60, -1, API.OFF_ACT_GeneralInterface_route)  -- enter instance
        UTILS.countTicks(3)
        local POS = API.PlayerCoord()                                                                  -- get player coords
        API.DoAction_Tile(WPOINT.new(POS.x + math.random(12, 15), POS.y + math.random(3, 5), POS.z))   -- move to randomized spot
        UTILS.countTicks(5)
    end
    firstRun = true
end

local function checkInventory()
    if not API.InvItemFound1(FOOD.ROCKTAIL) then
        print("OUT OF FOOD - STOPPING")
        API.Write_LoopyLoop(false)
    end
    if not API.InvItemFound1(POTIONS.OVERLOAD_3) and not API.InvItemFound1(POTIONS.OVERLOAD_2) and not API.InvItemFound1(POTIONS.OVERLOAD_1) then
        print("OUT OF OVERLOAD - STOPPING")
        API.Write_LoopyLoop(false)
        return true
    end
    if not API.InvItemFound1(POTIONS.SUPER_RESTORE_4) and not API.InvItemFound1(POTIONS.SUPER_RESTORE_3) and not API.InvItemFound1(POTIONS.SUPER_RESTORE_2) and not API.InvItemFound1(POTIONS.SUPER_RESTORE_1) then
        print("OUT OF SUPER RESTORES - STOPPING")
        API.Write_LoopyLoop(false)
        return true
    end
end

local function reSupply()
    if reSupplyNeeded() == true then
        API.DoAction_Interface(0x2e, 0xffffffff, 1, 1671, 183, -1, API.OFF_ACT_GeneralInterface_route) -- wars teleport
        UTILS.countTicks(10)
        API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { 114750 }, 50)                   -- load last preset from bank chest at wars retreat
        UTILS.countTicks(7)

        checkInventory()

        firstRun = false
        goToSpot()
    end
end

local function lootDrops()
    if not API.InvFull_() then
        local lootWindowOpen = API.LootWindowOpen_2()
        UTILS.countTicks(1)
        if not lootWindowOpen then
            API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1678, 8, -1, API.OFF_ACT_GeneralInterface_route) -- Open loot interface
            UTILS.countTicks(1)
            API.DoAction_LootAll_Button()
        else
            API.DoAction_LootAll_Button()
        end
    end
    UTILS.countTicks(1)
end

local function isAlive()
    local objList = { 28241 }
    local checkRange = 25
    local objectTypes = { 1 }
    local foundObjects = API.GetAllObjArray1(objList, checkRange, objectTypes)

    if foundObjects then
        for _, obj in ipairs(foundObjects) do
            if obj.Id == 28241 then
                return true
            end
        end
    end
    return false
end



------MAIN LOOP------



--TRACK SKILLS XP--
API.GetTrackedSkills()

while API.Read_LoopyLoop(true) do
    API.SetDrawTrackedSkills(true)

    ----MAIN LOGIC----

    goToSpot()

    reSupply()

    checkHP()

    if not isAlive() then
        lootDrops()
    end

    idleCheck()
end
