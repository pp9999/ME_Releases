local API = require("api")
local AURAS = {}

local auraTitleInterface = {
    InterfaceComp5.new(1929, 0, -1, -1, 0),
    InterfaceComp5.new(1929, 2, -1, 0, 0),
    InterfaceComp5.new(1929, 2, 14, 2, 0),
}

local auraStatusTextInterface = {
    InterfaceComp5.new(1929, 0, -1, -1, 0),
    InterfaceComp5.new(1929, 3, -1, 0, 0),
    InterfaceComp5.new(1929, 4, -1, 3, 0),
    InterfaceComp5.new(1929, 74, -1, 4, 0),
}

local buttonTextInterface = {
    InterfaceComp5.new(1929, 0, -1, -1, 0),
    InterfaceComp5.new(1929, 3, -1, 0, 0),
    InterfaceComp5.new(1929, 4, -1, 3, 0),
    InterfaceComp5.new(1929, 6, -1, 4, 0),
    InterfaceComp5.new(1929, 11, -1, 6, 0),
    InterfaceComp5.new(1929, 18, -1, 11, 0),
    InterfaceComp5.new(1929, 19, -1, 18, 0),
}

local auraOverridePopup = {

    InterfaceComp5.new(1929, 0, -1, -1, 0),
    InterfaceComp5.new(1929, 3, -1, 0, 0),
    InterfaceComp5.new(1929, 142, -1, 3, 0),
    InterfaceComp5.new(1929, 144, -1, 142, 0),
    InterfaceComp5.new(1929, 166, -1, 144, 0),
    InterfaceComp5.new(1929, 166, 14, 166, 0),
}

local CONSTANTS = {
    BUTTON_BUY = "Buy",
    BUTTON_ACTIVATE = "Activate",
    BUTTON_DEACTIVATE = "Deactivate",
    AURA_MANAGEMENT = "Aura Management",
    READY = "Ready to use",
    RECHARGING = "Currently recharging",
    ACTIVE = "Currently active",
}

local function doesStringInclude(input, searchValue)
    return string.find(tostring(input), searchValue) ~= nil
end


local function waitUntil(x, timeout)
    local start = os.time()
    while not x() and start + timeout > os.time() do
        API.RandomSleep2(200, 200, 200)
    end
    return start + timeout > os.time()
end

local function getInterfaceText(interface, nested)
    local inter = API.ScanForInterfaceTest2Get(nested, interface)
    if (#inter > 0) then
        return inter[1].textids
    else
        return nil
    end
end

local function getButtonText()
    return getInterfaceText(buttonTextInterface, false)
end

function AURAS.isAuraInterfaceOpen()
    local inter = API.ScanForInterfaceTest2Get(false, auraTitleInterface)
    if (#inter > 0) then
        local status = inter[1].textids
        if (string.len(status) > 0) and (doesStringInclude(status, CONSTANTS.AURA_MANAGEMENT)) then
            return true
        else
            return false
        end
    else
        return false
    end
end

function AURAS.openAuraInterface()
    if AURAS.isAuraInterfaceOpen() then
        return
    end
    local auraEquipped = AURAS.isAuraEquipped()
    print('auraEquipped', auraEquipped)
    if (auraEquipped) then
        print('aura equipped, going in')
        local auraId = API.GetEquipSlot(11).itemid1
        API.DoAction_Interface(0xffffffff, auraId, 2, 1464, 15, 14, API.OFF_ACT_GeneralInterface_route)
    else
        print('no aura equipped')
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1464, 15, 14, API.OFF_ACT_GeneralInterface_route)
    end
end

function AURAS.closeAuraInterface()
    API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 167, -1, API.OFF_ACT_GeneralInterface_route)
end

local function openEquipmentInterface()
    API.DoAction_Interface(0xc2, 0xffffffff, 1, 1432, 5, 2, API.OFF_ACT_GeneralInterface_route)
end

local function isEquipmentInterfaceOpen()
    return API.VB_FindPSettinOrder(3074,1).state == 1
end

function AURAS.isAuraEquipped()
    local equipmentOpen = isEquipmentInterfaceOpen()
    if not equipmentOpen then
        openEquipmentInterface()
        API.RandomSleep2(50,0,0)
    end
    local equipped = false
    if API.GetEquipSlot(11).itemid1 == -1 then equipped = false else equipped = true end
    if not equipmentOpen then
        openEquipmentInterface()
        API.RandomSleep2(50,0,0)
    end
    return equipped
end

function AURAS.canUseAura()

    local statusText = getInterfaceText(auraStatusTextInterface, false)
    local inter = API.ScanForInterfaceTest2Get(false, auraStatusTextInterface)
    if (#inter > 0) then
        local status = inter[1].textids
        if (string.len(status) > 0) and doesStringInclude(status, CONSTANTS.READY) then
            return true
        else
            return false
        end
    else
        return false
    end
end

local function selectAura(auraIds, force)
    if (not AURAS.isAuraEquipped()) and force then
        print('already have an aura, no force')
        return
    end

    for index, value in ipairs(auraIds) do
        API.DoAction_Interface(0xffffffff, auraIds[index][1], 1, 1929, 95, auraIds[index][2],
            API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200, 100, 300)
        local btnText = getButtonText()
        if doesStringInclude(btnText, CONSTANTS.BUTTON_DEACTIVATE) then
            print('aura already active')
            break
        end
        if (AURAS.canUseAura()) then
            if doesStringInclude(btnText, CONSTANTS.BUTTON_ACTIVATE) then
                API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 16, -1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(1200, 100, 300)
                if AURAS.isAuraEquipped() and force then
                    print('force use')
                    API.DoAction_Interface(0x24,0xffffffff,1,1929,162,-1,API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(800, 100, 300)
                    AURAS.closeAuraInterface()
                end
                break
            else
                print('have aura but cant use')
            end
        else
            print('dont have aura')
        end
    end
end

local function activateAura(auraIds, force)
    if AURAS.isAuraEquipped() and not force then print('already have aura and no force') return end
    local auraInterfaceOpened = AURAS.isAuraInterfaceOpen()
    if not auraInterfaceOpened then
        AURAS.openAuraInterface()
    end
    if not waitUntil(AURAS.isAuraInterfaceOpen, 10) then
        print('Aura interface wasnt open after 10 seconds, exiting')
        return
    end
    selectAura(auraIds, force)

    if not auraInterfaceOpened then
        AURAS.closeAuraInterface()
    end
end

AURAS.ODDBALL = {
    ids = { { 20957, 0 } },
    activate = function(force) activateAura(0, force) end
}
AURAS.FESTIVE = {
    ids = { { 26120, 88 } },
    activate = function(force) activateAura(0, force) end
}
AURAS.POISON_PURGE = {
    ids = { { 23862, 67 }, { 22917, 48 }, { 22268, 10 }, { 20958, 1 } },
    activate = function(self, force) activateAura(self.ids, force) end
}
AURAS.FRIEND_IN_NEED = {
    ids = { { 20963, 2 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.KNOCK_OUT = {
    ids = { { 22933, 53 }, { 20961, 3 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.SHARP_SHOOTER = {
    ids = { { 23866, 69 }, { 22921, 50 }, { 22272, 12 }, { 20967, 4 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.RUNIC_ACCURACY = {
    ids = { { 23864, 68 }, { 22919, 49 }, { 22270, 11 }, { 20962, 5 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.SUREFOOTED = {
    ids = { { 22278, 15 }, { 20964, 6 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.REVERENCE = {
    ids = { { 23870, 71 }, { 22925, 52 }, { 22276, 14 }, { 20965, 7 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.CALL_OF_THE_SEA = {
    ids = { { 30794, 74 }, { 23868, 70 }, { 22923, 51 }, { 22274, 13 }, { 20966, 8 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.LUMBERJACK = {
    ids = { { 30796, 75 }, { 23860, 66 }, { 22915, 47 }, { 22282, 17 }, { 22280, 16 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.QUARRYMASTER = {
    ids = { { 30800, 77 }, { 23858, 65 }, { 22913, 46 }, { 22286, 19 }, { 22284, 18 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.FIVE_FINGER_DISCOUNT = {
    ids = { { 30798, 76 }, { 23856, 64 }, { 22911, 45 }, { 22290, 21 }, { 22288, 20 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.RESOURCEFUL = {
    ids = { { 22292, 22 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.EQUILIBRIUM = {
    ids = { { 22294, 23 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.INSPIRATION = {
    ids = { { 22296, 24 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.PENANCE = {
    ids = { { 22300, 26 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.WISDOM = {
    ids = { { 35832, 27 }, { 35830, 27 }, { 22302, 27 } }, -- MISSING????
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.AEGIS = {
    ids = { { 22889, 28 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.REGENERATION = {
    ids = { { 22893, 29 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.DARK_MAGIC = {
    ids = { { 22891, 30 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.BERSERKER = {
    ids = { { 22897, 31 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.ANCESTOR_SPIRITS = {
    ids = { { 22895, 32 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.TRACKER = {
    ids = { { 30802, 78 }, { 23872, 72 }, { 22931, 38 }, { 22929, 37 }, { 22927, 36 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.SALVATION = {
    ids = { { 23876, 54 }, { 22903, 41 }, { 22901, 40 }, { 22899, 39 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.CORRUPTION = {
    ids = { { 23874, 55 }, { 22909, 44 }, { 22907, 43 }, { 22905, 42 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.HARMONY = {
    ids = { { 23854, 59 }, { 23852, 58 }, { 23850, 57 }, { 23848, 56 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.INVIGORATE = {
    ids = { { 23846, 63 }, { 23844, 62 }, { 23842, 61 }, { 23840, 60 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.GREENFINGERS = {
    ids = { { 30804, 79 }, { 23878, 73 }, { 22887, 35 }, { 22885, 34 }, { 22883, 33 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.ENRICHMENT = {
    ids = { { 30792, 84 }, { 30790, 83 }, { 30788, 82 }, { 30786, 81 }, { 30784, 80 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.BRAWLER = {
    ids = { { 35792, 92 }, { 35790, 91 }, { 35788, 90 }, { 35786, 89 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.RECKLESS = {
    ids = { { 35794, 93 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.MANIACAL = {
    ids = { { 35796, 94 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.DEDICATED_SLAYER = {
    ids = { { 35806, 99 }, { 35804, 98 }, { 35802, 97 }, { 35800, 96 }, { 35798, 95 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.FOCUSED_SIPHONING = {
    ids = { { 35816, 104 }, { 35814, 103 }, { 35812, 102 }, { 35810, 101 }, { 35808, 100 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.FLAMEPROOF = {
    ids = { { 35826, 108 }, { 35824, 107 }, { 35820, 106 }, { 35818, 105 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

AURAS.JACK_OF_TRADES = {
    ids = { { 35828, 110 }, { 30808, 86 }, { 30806, 85 }, { 20959, 9 } },
    activate = function(self, force) activateAura(self.ids, force) end
}

return AURAS
