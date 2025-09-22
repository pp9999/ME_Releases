--[[
Module: DragginsFletcher - lite
Author: Draggin
Purpose: Fletching for Fort Forinthry workbench.

Version: 1.3.8
Date: 2025-08-19
--]]

local API = require("api")
local UTILS = require("utils")

-- -----------------------------------------------------------------------------
-- Constants and IDs
-- -----------------------------------------------------------------------------
-- Item and object identifiers used by the script. Keep these grouped for easy updates.
local ID = {
    Fletching_Workbench = 125718,
    Sharp_Shell_Shard = 53093,
    Headless_Dinarrow = 53033,
    Dinarrow = 53038,
    Rune_Dart_Tip = 824,
    Feather = 314,
    Rune_Dart = 811
}
-- -----------------------------------------------------------------------------
-- State Management
-- -----------------------------------------------------------------------------
-- Processing states and related variables
local STATE = 0
-- Define states for different processing modes
local STATES = {
    NO_MATERIALS = 0,
    DINARROWS = 1,
    RUNE_DARTS = 2
}
-- Cached active processing state (assume it won't change during this run)
local ACTIVE_STATE = nil
local ACTION_COOLDOWN_MS = 300 -- brief cooldown after finishing a loop before next action

-- Startup calculation variables
local totalLoops = 0
local currentLoop = 0
local limitingItem = nil  -- ID of the material that limits totalLoops
local totalLoopsInitialized = false -- set after we calculate totalLoops once
-- -----------------------------------------------------------------------------
-- Configuration
-- -----------------------------------------------------------------------------
-- Per-loop material consumption and mode-specific settings

local MODES = {
    [STATES.DINARROWS] = {
        state = STATES.DINARROWS,
        matA = ID.Sharp_Shell_Shard,
        matB = ID.Headless_Dinarrow,
        matAName = "Sharp Shell Shards",
        matBName = "Headless Dinarrows",
        name = "Dinarrows",
        ifaceRoute = 73, -- route to select Dinarrow crafting option - find 1370,22,73 in interface debug to explore how to find the proper route
        ifaceDelay = 300,
        perLoop = 300 -- user-provided: how many of each material a Dinarrow loop consumes
    },
    [STATES.RUNE_DARTS] = {
        state = STATES.RUNE_DARTS,
        matA = ID.Rune_Dart_Tip,
        matB = ID.Feather,
        matAName = "Rune Dart Tips",
        matBName = "Feathers",
        name = "Rune Darts",
        ifaceRoute = 42, -- route to select Rune Dart crafting option - find 1370,22,42 in interface debug to explore how to find the proper route
        ifaceDelay = 300,
        perLoop = 200 -- user-provided: how many of each material a Rune Dart loop consumes
    }
}

-- Ordered list of modes (priority order). Add new modes here only.
local MODES_ORDER = {
    MODES[STATES.DINARROWS],
    MODES[STATES.RUNE_DARTS]
}

-- Interface constants
local PRIMARY_IFACE = 1371
local CONFIRM_IFACE = 1370

-- Map item IDs to the count field names used by getCounts()
local ITEM_FIELD = {
    [ID.Sharp_Shell_Shard] = "shard",
    [ID.Headless_Dinarrow] = "headless",
    [ID.Rune_Dart_Tip] = "tip",
    [ID.Feather] = "feather"
}

-- Helper to read all relevant inventory counts in one call (moved early so other helpers can use it)
-- Adds short-term caching to avoid repeated API.InvStackSize calls within a short window.
local _cachedCounts = nil
local _cachedCountsTime = 0
local function getCounts()
    local now = os.clock()
    if _cachedCounts and now - _cachedCountsTime < 0.5 then
        return _cachedCounts
    end
    local counts = {
        shard = API.InvStackSize(ID.Sharp_Shell_Shard) or 0,
        headless = API.InvStackSize(ID.Headless_Dinarrow) or 0,
        tip = API.InvStackSize(ID.Rune_Dart_Tip) or 0,
        feather = API.InvStackSize(ID.Feather) or 0
    }
    _cachedCounts = counts
    _cachedCountsTime = now
    return counts
end

-- Compare two count tables
local function countsEqual(a, b)
    return a and b and a.shard == b.shard and a.headless == b.headless and a.tip == b.tip and a.feather == b.feather
end
local function countsDifferent(a, b)
    return not countsEqual(a, b)
end

-- Safe accessor for per-loop consumption (returns 1 when not set)
local function getPerLoop(state)
    local mode = MODES[state]
    if mode and mode.perLoop then return mode.perLoop end
    return 1
end

-- Check whether there are materials for a given mode
local function hasMaterialsFor(mode)
    if not mode then return false end
    local counts = getCounts()
    local keyA = ITEM_FIELD[mode.matA]
    local keyB = ITEM_FIELD[mode.matB]
    return keyA and keyB and (counts[keyA] or 0) > 0 and (counts[keyB] or 0) > 0
end

local function findActiveMode()
    for _, mode in ipairs(MODES_ORDER) do
        if hasMaterialsFor(mode) then
            return mode
        end
    end
    return nil
end

-- -----------------------------------------------------------------------------
-- Helper Functions
-- -----------------------------------------------------------------------------
-- `getCounts` is defined above so helper functions can safely call it during setup.

-- Calculate total processing loops at startup
local function calculateTotalLoops()
    local mode = findActiveMode()
    if not mode then
        totalLoops = 0
        limitingItem = nil
        print("No materials found! Script will exit.")
        return false
    end

    STATE = mode.state
    local per = mode.perLoop
    if not per then
        print(string.format("Per-loop consumption unknown for %s; set mode.perLoop to a value.", mode.name))
        return false
    end

    local counts = getCounts()
    local keyA = ITEM_FIELD[mode.matA]
    local keyB = ITEM_FIELD[mode.matB]
    local possibleA = math.floor((counts[keyA] or 0) / per)
    local possibleB = math.floor((counts[keyB] or 0) / per)
    totalLoops = math.min(possibleA, possibleB)

    if possibleA < possibleB then
        limitingItem = mode.matA
    else
        limitingItem = mode.matB
    end

    print(string.format("Mode: %s. %s=%d %s=%d perLoop=%d -> loops=%d", mode.name, mode.matAName, counts[keyA] or 0, mode.matBName, counts[keyB] or 0, per, totalLoops))

    if totalLoops == 0 then
        print("No materials found! Script will exit.")
        return false
    end
    return true
end

-- Get current state based on inventory
local function getState()
    -- prefer the explicit modes order
    if hasMaterialsFor(MODES[STATES.DINARROWS]) then
        STATE = STATES.DINARROWS
    elseif hasMaterialsFor(MODES[STATES.RUNE_DARTS]) then
        STATE = STATES.RUNE_DARTS
    else
        STATE = STATES.NO_MATERIALS
    end
end

-- Throttle helper for interface scanning
local _lastInterfaceScan = 0
local _interfaceScanThrottleSec = 0.5

-- Check if fletching interface is present (robust: GetInterfaceStatus + Scan fallback)
local function isFletchingInterfacePresent()
    -- Primary: fast status check
    if API.GetInterfaceStatus and API.GetInterfaceStatus(PRIMARY_IFACE) then
        return true
    end
    -- Fallback: scan for interface components (safer across client states)
    if API.ScanForInterfaceTest2Get then
        local now = os.clock()
        if now - _lastInterfaceScan > _interfaceScanThrottleSec then
            _lastInterfaceScan = now
            local ok, result = pcall(API.ScanForInterfaceTest2Get, true, {{PRIMARY_IFACE, 7, -1, 0}})
            if ok and result and #result > 0 then
                return true
            end
        end
    end
    -- Also check the confirm interface as a last resort
    if API.GetInterfaceStatus and API.GetInterfaceStatus(CONFIRM_IFACE) then
        return true
    end
    return false
end

-- Perform fletching action
local function performFletchingAction()
    local mode = MODES[STATE]
    if not mode then
        return
    end

    print("Selecting " .. mode.name .. " option")
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, PRIMARY_IFACE, mode.ifaceRoute, -1, API.OFF_ACT_GeneralInterface_route)
    UTILS.rangeSleep(mode.ifaceDelay, 200, 300)
    API.DoAction_Interface(0xffffffff, 0xffffffff, 0, CONFIRM_IFACE, 30, -1, API.OFF_ACT_GeneralInterface_Choose_option)
    UTILS.rangeSleep(1000, 300, 500)
end

-- Use workbench (click then wait for interface, return true if interface opened and action performed)
local function useWorkbench()
    print("Opening workbench")
    API.DoAction_Object1(0xcd, API.OFF_ACT_GeneralObject_route0, { ID.Fletching_Workbench }, 50)
    -- wait briefly for server to respond
    UTILS.rangeSleep(400, 200, 300)

    -- Poll for interface for up to 3 seconds
    local start = os.time()
    while os.time() - start < 3 do
        if isFletchingInterfacePresent() then
            print("Workbench interface detected after click")
            return true
        end
        UTILS.rangeSleep(200, 80, 120)
    end

    print("Workbench clicked but interface did not appear yet")
    return false
end

-- Wait for inventory to stabilize (used by post-loop detection)
local function readStableInventory(timeoutSec)
    timeoutSec = timeoutSec or 6
    local startT = os.time()
    local last = getCounts()
    local stableCount = 0
    while os.time() - startT < timeoutSec do
        UTILS.rangeSleep(300, 80, 120)
        local cur = getCounts()
        if countsEqual(cur, last) then
            stableCount = stableCount + 1
            if stableCount >= 2 then
                return cur
            end
        else
            stableCount = 0
            last = cur
        end
    end
    return last
end

-- Wait for a processing cycle to start and finish. Returns true if finished, false on timeout.
local function waitForProcessingCycle(startTimeout, finishTimeout)
    startTimeout = startTimeout or 6
    finishTimeout = finishTimeout or 60

    -- wait for processing to start
    local t0 = os.time()
    while os.time() - t0 < startTimeout do
        if API.isProcessing and API.isProcessing() then
            -- processing started; now wait for it to finish
            local t1 = os.time()
            while os.time() - t1 < finishTimeout do
                if not API.isProcessing() then
                    return true
                end
                UTILS.rangeSleep(300, 80, 120)
            end
            return false -- did not finish in time
        end
        UTILS.rangeSleep(200, 80, 120)
    end

    -- Processing never started; fallback: wait for inventory to change/stabilize
    local before = readStableInventory(2)
    local after = readStableInventory(6)
    if before and after and countsDifferent(after, before) then
        return true
    end
    -- give one last chance: check stable inventory against some baseline
    return false
end

-- -----------------------------------------------------------------------------
-- Core Processing printic
-- -----------------------------------------------------------------------------
-- Main fletching function
local function doFletching()
    if STATE == STATES.NO_MATERIALS then
        print("No materials remaining")
        return false
    end

    -- local helper to start an action and wait for it to finish; handles loop counter
    local function startActionAndWait()
        -- increment now so GUI shows progress upon initiation
        currentLoop = currentLoop + 1
        local loopNum = currentLoop
        print("Started loop " .. loopNum .. "/" .. (totalLoopsInitialized and tostring(totalLoops) or "??"))

        performFletchingAction()
        local finished = waitForProcessingCycle()
        if finished then
            print("Completed loop " .. loopNum .. "/" .. (totalLoopsInitialized and tostring(totalLoops) or "??"))
            return true
        else
            -- revert increment on failure
            currentLoop = currentLoop - 1
            print("Warning: processing did not complete for loop " .. loopNum .. ". Reverting loop count.")
            return false
        end
    end

    -- If interface present, perform action
    if isFletchingInterfacePresent() then
        print("Interface present, performing crafting")
        return startActionAndWait()
    end

    -- Try opening the workbench and, if interface appears, act immediately
    if useWorkbench() then
        -- small pause to ensure interface is ready
        UTILS.rangeSleep(200, 80, 120)
        if isFletchingInterfacePresent() then
            print("Interface appeared immediately after opening workbench - performing crafting")
            return startActionAndWait()
        else
            -- sometimes interface requires a tiny extra delay; wait then re-check once
            UTILS.rangeSleep(500, 150, 200)
            if isFletchingInterfacePresent() then
                print("Interface appeared after short delay - performing crafting")
                return startActionAndWait()
            end
        end
    end

    -- If we reach here, interface not available yet; caller will wait and retry
    return false
end

-- Execute a single processing cycle (open interface if needed, perform craft, and wait)
-- Returns true if a loop completed, false otherwise
local function processCycle()
    if STATE == STATES.NO_MATERIALS then
        print("No materials remaining")
        return false
    end

    -- Attempt the fletching action; doFletching handles interface/opening and increments loop counter
    if doFletching() then
        -- short cooldown after each successful loop
        UTILS.rangeSleep(ACTION_COOLDOWN_MS, 60, 120)
        return true
    end

    return false
end

-- Helper: return a readable name for the currently configured limiting item
local function getLimitingItemName()
    if not limitingItem then return "None" end
    local mode = MODES[STATE] or MODES[ACTIVE_STATE]
    if mode then
        if limitingItem == mode.matA then return mode.matAName end
        if limitingItem == mode.matB then return mode.matBName end
    end

    -- Fallback mapping for safety
    if limitingItem == ID.Sharp_Shell_Shard then return "Sharp Shell Shards"
    elseif limitingItem == ID.Headless_Dinarrow then return "Headless Dinarrows"
    elseif limitingItem == ID.Rune_Dart_Tip then return "Rune Dart Tips"
    elseif limitingItem == ID.Feather then return "Feathers" end

    return "Unknown"
end

-- -----------------------------------------------------------------------------
-- GUI and User Feedback
-- -----------------------------------------------------------------------------
-- Simple GUI
local function drawGUI()
    local progress = totalLoops > 0 and (currentLoop / totalLoops * 100) or 0
    local mode = MODES[STATE] or MODES[ACTIVE_STATE]
    local statusText = mode and mode.name or "No Materials"

    local limitingName = getLimitingItemName()

    local per = getPerLoop(STATE)
    local metrics = {
        { "DragginsFletcher", "Simplified Version" },
        { "", "" },
        { "Mode:", statusText },
        { "Progress:", currentLoop .. "/" .. totalLoops .. " (" .. string.format("%.2f", progress) .. "%)" },
        { "Limiting Item:", limitingName .. " (uses " .. per .. ")" },
        { "", "" },
        { "Status:", currentLoop >= totalLoops and "Complete" or "Processing" }
    }

    API.DrawTable(metrics)
end

-- -----------------------------------------------------------------------------
-- Script Execution
-- -----------------------------------------------------------------------------
local utils = UTILS.new()
API.Write_fake_mouse_do(false)
print("Fake mouse disabled")

-- Startup check: ensure we have some materials to start (but defer full totalLoops calc until after first loop)
getState()
if STATE == STATES.NO_MATERIALS then
    print("No materials at startup. Script ending.")
    return
end
-- set active state at startup to avoid repeated checks
ACTIVE_STATE = STATE

-- Enable skill tracking
API.SetDrawTrackedSkills(true)

-- Calculate total loops up front using user-provided per-loop consumption
if not calculateTotalLoops() then
    -- calculateTotalLoops prints the reason (no materials etc.)
    return
end
totalLoopsInitialized = true

-- Main loop 
local function mainLoop()
    while API.Read_LoopyLoop() do
        drawGUI()

        if not utils:gameStateChecks() then break end
        utils:antiIdle()

        if totalLoopsInitialized and currentLoop >= totalLoops then
            print("All processing loops completed. Script ending.")
            break
        end

        local effectiveState = ACTIVE_STATE

        if effectiveState ~= STATES.NO_MATERIALS and not API.isProcessing() then
            local itemType = MODES[effectiveState] and MODES[effectiveState].name or (effectiveState == STATES.DINARROWS and "Dinarrows" or "Rune Darts")
            print("Processing " .. itemType)

            -- ensure global STATE used by performFletchingAction matches effectiveState
            STATE = effectiveState

            if not processCycle() then
                UTILS.rangeSleep(220, 60, 100)
            end
        else
            UTILS.rangeSleep(180, 40, 80)
        end

        UTILS.rangeSleep(120, 30, 60)
    end
end

-- Replace inline main loop with function call
mainLoop()

print("Script ended")
