--[[
    Script: Dwarf Traders Pickpocket
    Description: Dwarf Traders Pickpocket

    Author: (Barely) Jared
    Version: 1.1
    Release Date: 20/05/2025

    Release Notes:
    - Version 1.1 : Aura Fix

    Major Credit to Higgins and Daddy for CruxPickpocket and Aura management.
    Almost no work done by me
]]

local API = require("api")
local UTILS = require("utils")
local ID = {
    EXCALIBUR = 14632,
    EXCALIBUR_AUGMENTED = 36619,
    ELVEN_SHARD = 43358,
    Trader = {2114}, --replace with trader ID in pile
    SAND_SEED = 54004
    
}
local aura = { buffID = 26098, id = 30798, interfaceSlot = 76 } --five fingers

local refreshInterface = {
    InterfaceComp5.new(1477, 25, -1, 0),
    InterfaceComp5.new(1477, 765, -1, 0),
    InterfaceComp5.new(1477, 767, -1, 0),
}
local auraRefreshInterface2 = {
    InterfaceComp5.new(1929, 0, -1, 0),
    InterfaceComp5.new(1929, 3, -1, 0),
    InterfaceComp5.new(1929, 4, -1, 0),
    InterfaceComp5.new(1929, 20, -1, 0),
    InterfaceComp5.new(1929, 21, -1, 0),
    InterfaceComp5.new(1929, 24, -1, 0),
}
local CONSTANTS = {
    BUTTON_ACTIVATE = "Activate",
    BUTTON_DEACTIVATE = "Deactivate",
    AURA_MANAGEMENT = "Aura Management",
    READY = "Ready to use",
    RECHARGING = "Currently recharging"
}

local auraTitleInterface = {
    InterfaceComp5.new(1929, 0, -1, 0),
    InterfaceComp5.new(1929, 2, -1, 0),
    InterfaceComp5.new(1929, 2, 14, 0),
}

local auraStatusTextInterface = {
    InterfaceComp5.new(1929, 0, -1, 0),
    InterfaceComp5.new(1929, 3, -1, 0),
    InterfaceComp5.new(1929, 4, -1, 0),
    InterfaceComp5.new(1929, 74, -1, 0),
}

local buttonTextInterface = {
    InterfaceComp5.new(1929, 0, -1, 0),
    InterfaceComp5.new(1929, 3, -1, 0),
    InterfaceComp5.new(1929, 4, -1, 0),
    InterfaceComp5.new(1929, 6, -1, 0),
    InterfaceComp5.new(1929, 11, -1, 0),
    InterfaceComp5.new(1929, 18, -1, 0),
    InterfaceComp5.new(1929, 19, -1, 0),
}
local function doesStringInclude(input, searchValue)
    return string.find(tostring(input), searchValue) ~= nil
end

local function getInterfaceText(interface)
    local inter = API.ScanForInterfaceTest2Get(false, interface)
    return (#inter > 0) and inter[1].textids or nil
end

local function getButtonText()
    return getInterfaceText(buttonTextInterface)
end
local function openEquipmentInterface()
    API.DoAction_Interface(0xc2, 0xffffffff, 1, 1432, 5, 2, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1200, 100, 300)

end

local function isEquipmentInterfaceOpen()
    return API.VB_FindPSettinOrder(3074,1).state == 1
end
local function isAuraInterfaceOpen()
    local status = getInterfaceText(auraTitleInterface)
    print("Checking if aura interface is open: ", status)
    return status and doesStringInclude(status, CONSTANTS.AURA_MANAGEMENT)
end

local function openAuraInterface()
    if isAuraInterfaceOpen() then return end
    print("Opening aura interface")
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1464, 15, 14, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1200,600,0)
end

local function closeAuraInterface()
    print("Closing aura interface")
    API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 167, -1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1200, 100, 300)

end

local function canUseAura()
    local status = getInterfaceText(auraStatusTextInterface)
    print("Checking if aura can be used: ", status)
    return status and doesStringInclude(status, CONSTANTS.READY)
end

local function selectAura()
    if not isAuraInterfaceOpen() then openAuraInterface() end
    print("Selecting aura with ID: ", aura.id)
    API.DoAction_Interface(0xffffffff, aura.id, 1, 1929, 95, aura.interfaceSlot, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1200, 100, 300)
    local btnText = getButtonText()
    print("Button text after selecting aura: ", btnText)
    
    if doesStringInclude(btnText, CONSTANTS.BUTTON_DEACTIVATE) then
        print("Aura already active")
        return true  -- Aura is already active
    end
    
    return false  -- Aura is not active, ready to activate
end
local function isAuraEquipped()
    local equipmentOpen = isEquipmentInterfaceOpen()
    if not equipmentOpen then
        openEquipmentInterface()
        API.RandomSleep2(50, 0, 0)
    end
    local equipped = API.GetEquipSlot(11).itemid1 ~= -1
    return equipped
end
local function auraOnCooldown()
    if not isAuraInterfaceOpen() then 
        openAuraInterface()
    end
    
    -- Ensure aura is selected before checking if it's on cooldown
    if not selectAura() then
        local status = getInterfaceText(auraStatusTextInterface)
        print("Aura status: ", status)  -- Check what the status text is
        return status and doesStringInclude(status, CONSTANTS.RECHARGING)
    end

    return false -- Aura is either active or cannot be activated at the moment
end
local function activateAura()
    local btnText = getButtonText()
    if doesStringInclude(btnText, CONSTANTS.BUTTON_ACTIVATE) then
        print("Activating aura")
        API.DoAction_Interface(0x24,0xffffffff,1,1929,38,-1,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200, 100, 300)
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 16, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200, 100, 300)
        closeAuraInterface()
    else
        print("Aura cannot be activated")
    end
end
local afk, startTime = os.time(), os.time()
local skill = "THIEVING"
local startXp = API.GetSkillXP(skill)
local MAX_IDLE_TIME_MINUTES = 10
local lastFailedReset = 0  -- Track when the last failed reset occurred
local RESET_COOLDOWN = 3 * 60 * 60  -- 3 hours in seconds

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end
local function resetAura()
    print("aura on cooldown, resetting")
    API.RandomSleep2(1200,0,0)
    openAuraInterface()
    API.RandomSleep2(1200,0,0)
    API.DoAction_Interface(0xffffffff,0x784e,1,1929,95,23,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1200,0,0)
    API.DoAction_Interface(0xffffffff,0xa6a5,1,1929,22,-1,API.OFF_ACT_GeneralInterface_route) --requires a general reset aura scroll
    API.RandomSleep2(1800,0,0)
    refreshStatus = API.ScanForInterfaceTest2Get(false, refreshInterface)
    auraRefreshes = API.ScanForInterfaceTest2Get(false, auraRefreshInterface2)
    if #refreshStatus > 0 and auraRefreshes[1].itemid1_size > 0 then
        API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,8,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        return true  -- Reset was successful
    else
        lastFailedReset = os.time()  -- Record the failed reset time
        print("Aura reset failed, will try again in 3 hours (Out of reset scrolls)")
        return false  -- Reset failed
    end
    API.RandomSleep2(1800,0,0)
end
local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function formatNumber(num)
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

local function isAtWar()
    return API.PInArea(AREA.WAR[1], 50, AREA.WAR[2], 50, 0)
end

local function isAtKnight()
    return API.PInArea(AREA.KNIGHT[1], 50, AREA.KNIGHT[2], 50, 0)
end

local function hasFam()
    return API.Buffbar_GetIDstatus(26095).id > 0
end

local function prayAtAltar()
    API.DoAction_Object1(0x3d, 0, { 114748 }, 50)
    API.RandomSleep2(1200, 500, 500)
end

local function teleportToWar()
    API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(400, 500, 500)
end

local function teleportToKnight()
    local ss = API.GetABs_name1("Mystical sand seed")
    if ss.enabled then
        API.DoAction_Ability_Direct(ss, 1, API.OFF_ACT_GeneralInterface_route)
    end
    -- API.DoAction_Inventory1(ID.SAND_SEED, 0, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(800, 500, 500)
end
local function maintainaura()
    if API.Buffbar_GetIDstatus(aura.buffId, false).id <= 0 then
        if not isAuraEquipped() then
            -- Check if we're still in cooldown from a failed reset
            local timeSinceLastFailed = os.time() - lastFailedReset
            if timeSinceLastFailed < RESET_COOLDOWN then
                print("Still in cooldown from last failed reset. Time remaining: " .. 
                    math.floor((RESET_COOLDOWN - timeSinceLastFailed) / 60) .. " minutes")
                return
            end
            
            if auraOnCooldown() then 
                if not resetAura() then
                    return  -- Exit if reset failed
                end
            end
            selectAura()  -- Ensure the aura is selected before activation
            activateAura() -- Activate the aura if not already active
        end
    end
end
local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(6, 82, 221);
    IGP.string_value = "Dwarf Traders"
end

local function drawGUI()
    DrawProgressBar(IGP)
end

local function healthCheck()
    local prayer = API.GetPrayPrecent()
    local excalCD = API.DeBuffbar_GetIDstatus(ID.EXCALIBUR, false)
    local excalFound = API.InvItemcount_1(ID.EXCALIBUR_AUGMENTED)
    local elvenCD = API.DeBuffbar_GetIDstatus(ID.ELVEN_SHARD, false)
    local health = API.GetHPrecent()
    local crystalMask = API.Buffbar_GetIDstatus(25938)
    local lightForm = API.Buffbar_GetIDstatus(26048)
    local fiveFingers = API.Buffbar_GetIDstatus(26098)
    local adren = API.GetAddreline_()
    local elvenFound = API.InvItemcount_1(ID.ELVEN_SHARD)
    
    if not excalCD.found and excalFound > 0 then
        API.DoAction_Inventory1(ID.EXCALIBUR_AUGMENTED, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if not elvenCD.found and elvenFound > 0 then
        API.DoAction_Inventory1(ID.ELVEN_SHARD, 43358, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if not crystalMask.found then
        API.DoAction_Ability("Crystal Mask", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if prayer > 50 and not lightForm.found then
        API.DoAction_Ability("Light Form", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if not fiveFingers.found then
        maintainaura()
        API.RandomSleep2(800, 500, 500)
    end
    if health < 80 and adren >= 100 then
        API.DoAction_Interface(0xffffffff,0xffffffff,1,1430,11,-1,API.OFF_ACT_GeneralInterface_route)
    end
    if health < 30 then
        API.DoAction_Interface(0x2e,0x28ec,1,1670,136,-1,API.OFF_ACT_GeneralInterface_route)
    end
end

setupGUI()

while API.Read_LoopyLoop() do
    idleCheck()
    drawGUI()
    API.DoRandomEvents()
    UTILS.DO_ElidinisSouls()
    if API.ReadPlayerMovin2() then
        API.RandomSleep2(200, 200, 200)
        goto continue
    end

    if API.ReadPlayerAnim() == 424 then
        API.RandomSleep2(5100, 500, 500)
    end

    healthCheck()
    
    if API.CheckAnim(80) or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route2, ID.Trader, 50) then
        API.RandomSleep2(600, 100, 100)
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(50, 100, 100)
end

