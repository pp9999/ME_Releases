--[[
 * script name: PureEss
 * purpose: Mine pure essence in east varrock
 * instructions: Start in the varrock bank
 * @author: gh0st | evolocity (discord), ported to lua by dead | dea.d (discord)
 * last edited: 08/24/2023
 */
 ]]--

print("Run Lua script gh0stEssMiner.")

local API = require("api")
local UTILS = require("utils")

-- Script settings
local debugMessages = true

-- Function to log debug messages
local function logDebugMessage(message)
    if debugMessages then
        print(message)
        API.Write_ScripCuRunning1(message)
    end
end

local function gameStateChecks()
    local gameState = API.GetGameState()
    if (gameState ~= 3) then
        print('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
    if not API.PlayerLoggedIn() then
        API.Write_LoopyLoop(false)
        return;
    end
end

-- Function to check if the door is closed
local function doorClosed()
    local drClosed = API.GetAllObjArray2({24381}, 40, 12, WPOINT.new(3253, 3398, 0))
    local drOpened = API.GetAllObjArray2({24379}, 40, 0, WPOINT.new(3253, 3399, 0))
    return (#drClosed > 0 and #drOpened == 0)
end

local function inMiningArea()
	local essenceResources = API.GetAllObjArrayInteract({ 2491 }, 50, 12);
	return #essenceResources > 0;
end

local function inBuilding()
    -- x (east) 3255 x (west) 3250
    -- y (north) 3404 y (south) 3399
    local lp = API.PlayerCoord();
    return (lp.x >= 3250 and lp.x <= 3255 and lp.y >= 3399 and lp.y <= 3404);
end

local function inVarrock()
    local lp = API.PlayerCoord();
    return (lp.x < 3300 and lp.y < 3500)
end

local function bankOpen()
    return API.BankOpen2()
end

local function inventoryFull()
    return API.InvFull_()
end

local function isMining()
    return API.CheckAnim(20)
end

local function openDoor()
    logDebugMessage("openDoor()")
    if doorClosed() then
        local doors =API.GetAllObjArray2({24381}, 40, 12, WPOINT.new(3253, 3398, 0))
        local door = doors[1]
        if API.DoAction_Object_Direct(0x31, 0, door) then
            UTILS.randomSleep(500)
            while API.ReadPlayerMovin()and API.Read_LoopyLoop() do
                logDebugMessage("Idling while player is moving.")
                UTILS.randomSleep(500)
            end
            logDebugMessage("Door has been opened.")
        end
    end
end

local function gatherEssence()
    logDebugMessage("gatherEssence()")
    local essenceResources = API.GetAllObjArrayInteract({2491}, 40, 12)

    if #essenceResources > 0 then
        local essenceResource = essenceResources[1]
        if API.DoAction_Object_Direct(0x3a, 0, essenceResource) then
            UTILS.randomSleep(700)
            while API.ReadPlayerMovin() and API.Read_LoopyLoop() do
                logDebugMessage("Idling while player is moving.")
                UTILS.randomSleep(700)
            end
        end
    end
end

local function teleportNPC()
    logDebugMessage("teleportNPC()")
    if doorClosed() then
        logDebugMessage("Door is closed. Attempting to open.")
        openDoor()
    else
        local aubury = API.GetAllObjArrayInteract({5913}, 40, 1)
        local npc = aubury[1]
        if API.DoAction_NPC__Direct(0x29, 3504, npc) then
            UTILS.randomSleep(1000)
            while API.ReadPlayerMovin() and API.Read_LoopyLoop() do
                logDebugMessage("Idling while player is moving.")
                UTILS.randomSleep(1000)
            end
            UTILS.randomSleep(1800)
        end
    end
end

local function teleportPortal()
    logDebugMessage("teleportPortal()")
    local portals = API.GetAllObjArrayInteract_str({"Portal"}, 30, 1)
    local portal = portals[1]
    if API.DoAction_NPC__Direct(0x39, 3120, portal) then
        UTILS.randomSleep(750)
        while API.ReadPlayerMovin() and API.Read_LoopyLoop() do
            logDebugMessage("Idling while player is moving.")
            UTILS.randomSleep(750)
        end
        UTILS.randomSleep(1800)
    end
end

local function openBank()
    logDebugMessage("openBank()")
    local npc_chance = 75 -- 75% chance on npc, 25% on object
    math.randomseed(os.time())
    local chance = math.random(1,100)

    local banks

    if chance > npc_chance then
        -- Bank object
        banks = API.GetAllObjArrayInteract({782}, 40, 0)
    else
        -- Bank npc
        banks = API.GetAllObjArrayInteract({2759, 553}, 40, 1)
    end

    if #banks > 0 then
        local bank = banks[1]

        if chance > npc_chance then -- Bank object
            if API.DoAction_Object_Direct(0x5, 80, bank) then
                logDebugMessage("Opening Bank (OBJECT)")
            end
        else -- Bank npc
            if API.DoAction_NPC__Direct(0x5, 3120, bank) then
                logDebugMessage("Opening Bank (NPC)")
            end
        end

        UTILS.randomSleep(500)
        while API.ReadPlayerMovin() and API.Read_LoopyLoop() do
            logDebugMessage("Idling while player is moving.")
            UTILS.randomSleep(700)
        end
    end
end

local function handleBanking()
    logDebugMessage("handleBanking()")
    if bankOpen() then
        API.DoAction_Interface(0xFFFFFFFF, 0xFFFFFFFF, 1, 517, 39, -1, 5392,0,0) -- deposit essence
        logDebugMessage("Essence deposited. Banking completed.")
    end
end

local function debugCalls()
    print("inVarrock() " .. tostring(inVarrock()))
    print("inBuilding() " .. tostring(inBuilding()))
    print("doorClosed() " .. tostring(doorClosed()))
    print("inventoryFull() " .. tostring(inventoryFull()))
    print("inMiningArea() " .. tostring(inMiningArea()))
    print("isMining() " .. tostring(isMining()))
end
-- Define other functions similarly

-- Main function
local function PureEss()
    while API.Read_LoopyLoop() do
        gameStateChecks()
        API.DoRandomEvents()
        if math.random(1000) > 960 then
            API.PIdle2()
            print("PIdle2")
        end

        if inVarrock() and inBuilding() and inventoryFull() then
            if doorClosed() then
                openDoor()
                openBank()
            else
                openBank()
            end
        end

        if inVarrock() and not inBuilding() then
            if inventoryFull() then
                if not bankOpen() then
                    openBank()
                end
                if bankOpen() then
                    handleBanking()
                end
            else
                if doorClosed() then
                    openDoor()
                else
                    teleportNPC()
                end
            end
        end

        if inMiningArea() then
            if inventoryFull() then
                teleportPortal()
            elseif not isMining() then
                gatherEssence()
            end
        end

        UTILS.randomSleep(500)
        debugCalls()
    end
end

-- Entry point of the script
PureEss()