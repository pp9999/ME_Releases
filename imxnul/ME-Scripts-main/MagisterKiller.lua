
local API = require("api")

-------------------------------------------------
-- Config
-------------------------------------------------

-- Attack the fight Soul obelisk when HP is below OBELISK_HP (constitution drain).
local ATTACK_FIGHT_OBELISK = true

-- Check/get a Magister Soul Reaper assignment. If false, skip reaper and use a Wars boss portal.
local GET_REAPER_ASSIGNMENT = true

-- Prayer sent once before the arena, toggled off before Wars teleport.
-- "magic" = Protect from Magic / Deflect Magic, "soulsplit" = Soul Split
local PRAYER_MODE = "magic"

-- Inside the Magister instance: drink/restore when prayer is at or below this percent.
local PRAYER_POT_PERCENT = 50
-- Use Ancient elven ritual shard at or below this percent (if off cooldown).
local ELVEN_SHARD_PERCENT = 60
-- Redose overload when the buff is missing or has this many seconds left.
local OVERLOAD_REFRESH_SECONDS = 20
-- Wait this many ticks after first arriving in the arena before touching the obelisk.
local ARENA_SETTLE_TICKS = 8

API.SetMaxIdleTime(10)
API.Write_LoopyLoop(true)
pcall(function() Interact:SetSleep(0, 0, 0) end)

-------------------------------------------------
-- IDs / constants
-------------------------------------------------

local BANK_CHEST_ID = 114750
local ALTAR_ID = 114748
local REAPER_PORTAL_ID = 114761
local WARS_PORTAL_IDS = { 114762, 114763, 114765 }
local PORTAL_IDS = { 114761, 114762, 114763, 114765 }
local FIRST_GATE_IDS = { 109322, 109499 }
local OBELISK_START_ID = 109157
local OBELISK_FIGHT_ID = 109158
local MAGISTER_ID = 24765
local GRIM_GEM_ID = 31846
local KEY_IDS = { 40310, 28771 }
local ELVEN_SHARD_ID = 43358
local OVERLOAD_BUFF_IDS = { 49039, 33210, 26093 }

-- Drink any dose in inventory. Flasks listed 6→1, vials 4→1.
local OVERLOAD_IDS = {
    -- Elder overload / salve
    49039, 49037, 49035, 49033, 49031, 49029,
    49052, 49050, 49048, 49046, 49044, 49042,
    -- Supreme overload / salve
    33210, 33208, 33206, 33204, 33202, 33200,
    33222, 33220, 33218, 33216, 33214, 33212,
    -- Overload vials / flasks
    15332, 15333, 15334, 15335,
    23531, 23532, 23533, 23534, 23535, 23536, 23537,
    -- Holy / searing / salve / aggro
    33246, 33244, 33242, 33240, 33238, 33236,
    33258, 33256, 33254, 33252, 33250, 33248,
    33198, 33196, 33194, 33192, 33190, 33188,
    48239, 48237, 48235, 48233, 48231, 48229,
    50877, 50875, 50873, 50871, 50869, 50867,
}

local PRAYER_POTION_IDS = {
    -- Prayer potion / flask
    2434, 139, 141, 143,
    23243, 23245, 23247, 23249, 23251, 23253,
    -- Super prayer / flask
    12146, 12145, 12144, 12143,
    23525, 23526, 23527, 23528, 23529, 23530,
    -- Extreme / spiritual / blessed
    32609, 32611, 32613, 32615,
    43464, 43466, 43468, 43470,
    49274,
    -- Prayer renewal / super prayer renewal
    21630, 21632, 21634, 21636,
    23609, 23611, 23613, 23615, 23617, 23619,
    33186, 33184, 33182, 33180, 33178, 33176,
}

local SUPER_RESTORE_IDS = {
    3024, 3026, 3028, 3030,
    23399, 23401, 23403, 23405, 23407, 23409,
}
local REAPER_TASK_VARBIT = 22901
local REAPER_INTERFACE = 1761
local MAGISTER_REAPER_CHILD = 28

local WARS_TILE = WPOINT.new(3295, 10137, 0)

local PROTECT_MAGIC_BUFF = 25959
local DEFLECT_MAGIC_BUFF = 26041
local SOUL_SPLIT_BUFF = 26033
local DARKNESS_BUFF = 30122
local EXCALIBUR_DEBUFF = 14632
local EXCALIBUR_NAME = "Augmented enhanced Excalibur"
local EXCALIBUR_HP = 65
local EAT_HP = 50
local OBELISK_HP = 70

local MAGISTER_NAME = "The Magister"
local GATE_NAME = "The First Gate"
local OBELISK_NAME = "Soul obelisk"
local REAPER_PORTAL_NAME = "Reaper portal"
local MAGISTER_PORTAL_NAME = "Portal (The Magister)"
local GRIM_GEM_NAME = "Grim gem"
local KEY_NAME = "Key to the Crossing"

-------------------------------------------------
-- State
-------------------------------------------------

local STATE = {
    INIT = "INIT",
    TELE_WARS = "TELE_WARS",
    CHECK_TASK = "CHECK_TASK",
    GET_TASK = "GET_TASK",
    BANK = "BANK",
    ALTAR = "ALTAR",
    ENTER_PORTAL = "ENTER_PORTAL",
    ENTER_GATE = "ENTER_GATE",
    START_ENCOUNTER = "START_ENCOUNTER",
    FIGHT = "FIGHT",
    LOOT = "LOOT",
}

local currentState = STATE.INIT
local stateEnteredTick = API.Get_tick()
local lastActionTick = 0
local stateActionDone = false
local magisterTaskOk = false
local clickedMagister = false
local reaperConfirmStep = 0
local afterTaskState = STATE.BANK
local kills = 0
local reaperTasksCompleted = 0
local hadReaperTask = false
local killCounted = false
local magisterAttackedThisFight = false
local startTime = os.time()
local bankAttempts = 0
local emptyPresetStops = 0
local lootOpenAttempted = false
local lootOpenMethod = 0
local deflectSentThisTrip = false
local prayerOffSent = false
local arenaSettled = false
local arenaSettleTick = 0

-------------------------------------------------
-- Helpers
-------------------------------------------------

local function log(msg)
    print("[Magister] " .. tostring(msg))
end

local function actionLog(msg)
    log(msg)
end

local function setState(newState)
    if currentState == newState then
        return
    end
    log(currentState .. " -> " .. newState)
    currentState = newState
    stateEnteredTick = API.Get_tick()
    stateActionDone = false
    lootOpenAttempted = false
    lootOpenMethod = 0
    if newState == STATE.FIGHT then
        killCounted = false
    end
    if newState == STATE.GET_TASK then
        clickedMagister = false
        reaperConfirmStep = 0
    end
    if newState == STATE.TELE_WARS then
        prayerOffSent = false
    end
end

local function beginGetTask(resumeState)
    afterTaskState = resumeState or STATE.BANK
    setState(STATE.GET_TASK)
end

local function ticksInState()
    return API.Get_tick() - stateEnteredTick
end

local function canAct(cooldown)
    return (API.Get_tick() - lastActionTick) >= (cooldown or 3)
end

local function markActed()
    lastActionTick = API.Get_tick()
end

local function isMoving()
    return API.ReadPlayerMovin2()
end

local function chatOpen()
    return API.GetInterfaceOpenBySize(1188)
end

local function continueOpen()
    return API.Check_continue_Open()
end

local function dialogOpen()
    return chatOpen() or continueOpen() or API.Check_Dialog_Open()
end

local function npcDialogText()
    local npc = API.Dialog_Read_NPC()
    local player = API.Dialog_Read_Player()
    return string.lower(tostring(npc or "") .. " " .. tostring(player or ""))
end

local function findNPC(npcId, distance)
    return #API.GetAllObjArrayInteract({ npcId }, distance or 25, { 1 }) > 0
end

local function findObject(objIds, distance)
    if type(objIds) ~= "table" then
        objIds = { objIds }
    end
    return #API.GetAllObjArrayInteract(objIds, distance or 40, { 0, 12 }) > 0
end

local function atWars()
    return API.PInAreaW(WARS_TILE, 40)
end

local function magisterNearby()
    if findNPC(MAGISTER_ID, 40) then
        return true
    end
    local named = API.GetAllObjArrayInteract_str({ MAGISTER_NAME }, 40, { 1 })
    return named ~= nil and #named > 0
end

local function atArena()
    return findObject(OBELISK_START_ID, 40)
        or findObject(OBELISK_FIGHT_ID, 40)
        or magisterNearby()
end

local function atGate()
    return findObject(FIRST_GATE_IDS, 40)
        or (#API.GetAllObjArrayInteract_str({ GATE_NAME }, 40, { 0, 12 }) > 0)
end

local function atMagisterArea()
    return atArena() or atGate()
end

local function keyCount()
    local best = 0
    for _, id in ipairs(KEY_IDS) do
        local n = Inventory:InvItemcount(id)
        if type(n) == "number" and n > best then
            best = n
        end
    end
    return best
end

local function hasKeys()
    return keyCount() > 0
end

local function inventoryFull()
    local ok, spaces = pcall(function()
        return Inventory:FreeSpaces()
    end)
    if ok and type(spaces) == "number" then
        return spaces <= 0
    end
    local okFull, full = pcall(function()
        return Inventory:IsFull()
    end)
    return okFull and full == true
end

local function hasGrimGem()
    local ok, found = pcall(function()
        return Inventory:Contains(GRIM_GEM_ID)
    end)
    if ok then
        return found and true or false
    end
    return Inventory:InvItemFound(GRIM_GEM_ID)
        or (Inventory:InvItemcount_String(GRIM_GEM_NAME) or 0) > 0
end

local function cacheLoaded()
    local ok, loaded = pcall(API.IsCacheLoaded)
    return ok and loaded == true
end

local function reaperTaskValue()
    if not cacheLoaded() then
        return nil
    end
    if API.ReadVarbit then
        local ok, value = pcall(API.ReadVarbit, REAPER_TASK_VARBIT, false)
        if ok and type(value) == "number" and value ~= -1 then
            return value
        end
    end
    local ok, value = pcall(API.GetVarbitValue, REAPER_TASK_VARBIT)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

local function hasReaperTask()
    local value = reaperTaskValue()
    return type(value) == "number" and value ~= 0
end

local function trackReaperCompletion()
    local value = reaperTaskValue()
    if type(value) ~= "number" then
        return
    end
    local has = value ~= 0
    if hadReaperTask and not has then
        reaperTasksCompleted = reaperTasksCompleted + 1
        log("Reaper task complete #" .. tostring(reaperTasksCompleted))
    end
    hadReaperTask = has
end

local function reaperInterfaceOpen()
    return API.GetInterfaceOpenBySize(REAPER_INTERFACE)
end

local function openReaperAssignment()
    if not hasGrimGem() then
        actionLog("GET_TASK skipped: Grim gem 31846 not in inventory (no DoAction)")
        return false
    end
    local ok = API.DoAction_Inventory1(GRIM_GEM_ID, 0, 7, API.OFF_ACT_GeneralInterface_route2)
    actionLog("GET_TASK sent: DoAction_Inventory1 grim gem " .. GRIM_GEM_ID .. " action=7 route2 ok=" .. tostring(ok))
    return ok
end

local function selectMagisterReaperTask()
    local ok = API.DoAction_Interface(
        0xffffffff,
        0xffffffff,
        0,
        REAPER_INTERFACE,
        0,
        MAGISTER_REAPER_CHILD,
        API.OFF_ACT_GeneralInterface_Choose_option
    )
    actionLog("GET_TASK sent: DoAction_Interface 1761/0/" .. MAGISTER_REAPER_CHILD .. " Choose_option ok=" .. tostring(ok))
    return ok
end

local function hasMagicPrayer()
    local protect = API.Buffbar_GetIDstatus(PROTECT_MAGIC_BUFF, false)
    local deflect = API.Buffbar_GetIDstatus(DEFLECT_MAGIC_BUFF, false)
    return (protect and protect.found) or (deflect and deflect.found)
end

local function magicPrayerName()
    local deflect = API.Buffbar_GetIDstatus(DEFLECT_MAGIC_BUFF, false)
    if deflect and deflect.found then
        return "Deflect Magic"
    end
    local protect = API.Buffbar_GetIDstatus(PROTECT_MAGIC_BUFF, false)
    if protect and protect.found then
        return "Protect from Magic"
    end
    return nil
end

local function hasDarkness()
    local buff = API.Buffbar_GetIDstatus(DARKNESS_BUFF, false)
    return buff and buff.found
end

local function chatBlob()
    local parts = {}
    local function add(container)
        if not container then
            return
        end
        local ok, len = pcall(function() return #container end)
        if not ok or type(len) ~= "number" then
            return
        end
        for i = 1, len do
            local m = container[i]
            local text = nil
            if type(m) == "string" then
                text = m
            elseif type(m) == "table" then
                text = m.text or m.Text or m.message or m.Message
            else
                local sOk, s = pcall(function()
                    return m.text or m.Text or m.message
                end)
                if sOk then
                    text = s
                end
            end
            if type(text) == "string" and text ~= "" then
                parts[#parts + 1] = text
            end
        end
    end
    pcall(function() add(API.GatherEvents_chat_check()) end)
    pcall(function() add(API.ChatGetMessages()) end)
    pcall(function() add(API.ChatFind("Magister", 30)) end)
    pcall(function() add(API.ChatFind("assignment", 30)) end)
    pcall(function() add(API.ChatFind("reaper", 30)) end)
    return string.lower(table.concat(parts, "\n"))
end

local function chatIndicatesNoTask(blob)
    blob = blob or chatBlob()
    return blob:find("no assignment", 1, true)
        or blob:find("don't currently have", 1, true)
        or blob:find("do not currently have", 1, true)
        or blob:find("need a reaper assignment", 1, true)
        or blob:find("not currently on an assignment", 1, true)
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function perHour(count)
    local elapsed = os.time() - startTime
    if elapsed <= 0 then
        return 0
    end
    return (count / elapsed) * 3600
end

local function recordKill()
    if killCounted then
        return
    end
    killCounted = true
    kills = kills + 1
    log(string.format("Kill #%d  |  keys left: %d", kills, keyCount()))
end

local function pressContinue()
    actionLog("DIALOG sent: KeyboardPress2 space (continue)")
    API.KeyboardPress2(0x20, 40, 60)
    markActed()
end

local function pressDigit(digit)
    actionLog("DIALOG sent: KeyboardPress2 " .. tostring(digit))
    API.KeyboardPress2(0x30 + digit, 60, 200)
    markActed()
end

local function clickOption(text)
    if API.DoDialog_Option(text) then
        actionLog("DIALOG sent: DoDialog_Option '" .. text .. "'")
        markActed()
        return true
    end
    local idx = API.Dialog_Option(text)
    if type(idx) == "number" and idx > 0 then
        pressDigit(idx)
        return true
    end
    return false
end

-------------------------------------------------
-- Actions
-------------------------------------------------

local function loadLastPreset()
    if Interact:Object("Bank chest", "Load Last Preset from", nil, 50) then
        actionLog("BANK sent: Interact Bank chest / Load Last Preset from")
        return true
    end
    local ok = API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { BANK_CHEST_ID }, 50)
    actionLog("BANK sent: DoAction_Object1 0x33 route3 id=" .. BANK_CHEST_ID .. " ok=" .. tostring(ok))
    return ok
end

local function prayAltar()
    if Interact:Object("Altar of War", "Pray", nil, 50) then
        actionLog("ALTAR sent: Interact Altar of War / Pray")
        return true
    end
    local ok = API.DoAction_Object1(0x3d, API.OFF_ACT_GeneralObject_route0, { ALTAR_ID }, 50)
    actionLog("ALTAR sent: DoAction_Object1 0x3d route0 id=" .. ALTAR_ID .. " ok=" .. tostring(ok))
    return ok
end

local function enterPortal()
    if GET_REAPER_ASSIGNMENT then
        if Interact:Object(REAPER_PORTAL_NAME, "Enter", nil, 50) then
            actionLog("PORTAL sent: Interact Reaper portal / Enter")
            return true
        end
        if Interact:Object(MAGISTER_PORTAL_NAME, "Enter", nil, 50) then
            actionLog("PORTAL sent: Interact Portal (The Magister) / Enter")
            return true
        end
        local ok = API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, PORTAL_IDS, 50)
        actionLog("PORTAL sent: DoAction_Object1 0x39 route0 ids=" .. table.concat(PORTAL_IDS, ",") .. " ok=" .. tostring(ok))
        return ok
    end
    if Interact:Object(MAGISTER_PORTAL_NAME, "Enter", nil, 50) then
        actionLog("PORTAL sent: Interact Portal (The Magister) / Enter")
        return true
    end
    local ok = API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, WARS_PORTAL_IDS, 50)
    actionLog("PORTAL sent: DoAction_Object1 0x39 route0 Wars portal ids=" .. table.concat(WARS_PORTAL_IDS, ",") .. " ok=" .. tostring(ok))
    return ok
end

local function enterGate()
    if Interact:Object(GATE_NAME, "Enter", nil, 40) then
        actionLog("GATE sent: Interact The First Gate / Enter")
        return true
    end
    local ok = API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, FIRST_GATE_IDS, 40)
    actionLog("GATE sent: DoAction_Object1 0x39 route0 ids=" .. table.concat(FIRST_GATE_IDS, ",") .. " ok=" .. tostring(ok))
    return ok
end

local function touchObelisk()
    if Interact:Object(OBELISK_NAME, "Touch", nil, 40) then
        actionLog("OBELISK sent: Interact Soul obelisk / Touch")
        return true
    end
    local ok = API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBELISK_START_ID }, 40)
    actionLog("OBELISK sent: DoAction_Object1 0x29 route0 id=" .. OBELISK_START_ID .. " ok=" .. tostring(ok))
    return ok
end

local function attackObelisk()
    if Interact:Object(OBELISK_NAME, "Attack", nil, 40) then
        actionLog("FIGHT sent: Interact Soul obelisk / Attack")
        return true
    end
    local ok = API.DoAction_Object1(0x2a, API.OFF_ACT_GeneralObject_route0, { OBELISK_FIGHT_ID }, 40)
    actionLog("FIGHT sent: DoAction_Object1 0x2a route0 id=" .. OBELISK_FIGHT_ID .. " ok=" .. tostring(ok))
    return ok
end

local function attackMagister()
    if Interact:NPC(MAGISTER_NAME, "Attack", nil, 40) then
        actionLog("FIGHT sent: Interact NPC The Magister / Attack")
        return true
    end
    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, { MAGISTER_ID }, 40) then
        actionLog("FIGHT sent: DoAction_NPC 0x2a AttackNPC id=" .. MAGISTER_ID)
        return true
    end
    local ok = API.DoAction_NPC_str(0x2a, API.OFF_ACT_AttackNPC_route, { MAGISTER_NAME }, 40)
    actionLog("FIGHT sent: DoAction_NPC_str 0x2a AttackNPC '" .. MAGISTER_NAME .. "' ok=" .. tostring(ok))
    return ok
end

local function interactingWithMagister()
    local interacting = API.ReadLpInteracting()
    if not interacting then
        return false
    end
    return interacting.Id == MAGISTER_ID or interacting.Name == MAGISTER_NAME
end

local function prayerMode()
    local mode = string.lower(tostring(PRAYER_MODE or "magic"))
    if mode == "soulsplit" or mode == "soul split" or mode == "ss" then
        return "soulsplit"
    end
    return "magic"
end

local function sendConfiguredPrayer(why)
    if prayerMode() == "soulsplit" then
        actionLog("PRAYER sent: Soul Split (" .. why .. ")")
        API.DoAction_Ability_check("Soul Split", 1, API.OFF_ACT_GeneralInterface_route, true, true, true)
        markActed()
        return
    end
    if API.DoAction_Ability_check("Deflect Magic", 1, API.OFF_ACT_GeneralInterface_route, true, true, true) then
        actionLog("PRAYER sent: Deflect Magic (" .. why .. ")")
        markActed()
        return
    end
    actionLog("PRAYER sent: Protect from Magic (" .. why .. ")")
    API.DoAction_Ability("Protect from Magic", 1, API.OFF_ACT_GeneralInterface_route, false)
    markActed()
end

local function hasConfiguredPrayer()
    if prayerMode() == "soulsplit" then
        local ss = API.Buffbar_GetIDstatus(SOUL_SPLIT_BUFF, false)
        return ss and ss.found
    end
    return hasMagicPrayer()
end

local function enablePrayerBeforeArena()
    if hasConfiguredPrayer() then
        deflectSentThisTrip = true
        return false
    end
    if deflectSentThisTrip then
        return false
    end
    deflectSentThisTrip = true
    sendConfiguredPrayer("once before arena")
    return true
end

local function ensurePrayerUp()
    if hasConfiguredPrayer() then
        return false
    end
    if not canAct(4) then
        return false
    end
    sendConfiguredPrayer("upkeep")
    return true
end

local function disablePrayer()
    sendConfiguredPrayer("toggle off before tele")
    return false
end

local function teleWars()
    local ok = API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route, true)
    actionLog("TELE sent: DoAction_Ability War's Retreat Teleport ok=" .. tostring(ok))
    return ok
end

local function leaveToWars()
    magisterTaskOk = false
    setState(STATE.TELE_WARS)
end

local function ensureDarkness()
    if hasDarkness() or dialogOpen() then
        return false
    end
    if not canAct(4) then
        return false
    end
    actionLog("DARKNESS sent: DoAction_Ability_check Darkness")
    API.DoAction_Ability_check("Darkness", 1, API.OFF_ACT_GeneralInterface_route, true, true, true)
    markActed()
    return true
end

local function useExcalibur()
    if dialogOpen() then
        return false
    end
    local hp = API.GetHPrecent()
    if not hp or hp <= 0 or hp >= EXCALIBUR_HP then
        return false
    end
    local cd = API.DeBuffbar_GetIDstatus(EXCALIBUR_DEBUFF, false)
    if cd and cd.found then
        return false
    end
    if not canAct(3) then
        return false
    end
    local ab = API.GetABs_name1(EXCALIBUR_NAME)
    if not ab or ab.id == 0 or not ab.enabled then
        return false
    end
    actionLog(string.format("EXCALIBUR sent: DoAction_Ability_Direct %s (HP: %.0f%%)", EXCALIBUR_NAME, hp))
    API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
    markActed()
    return true
end

local function eatFood()
    if dialogOpen() then
        return false
    end
    local hp = API.GetHPrecent()
    if not hp or hp <= 0 or hp >= EAT_HP then
        return false
    end
    if not canAct(2) then
        return false
    end
    local ab = API.GetABs_name1("Eat Food")
    if ab and ab.id ~= 0 and ab.enabled then
        actionLog(string.format("EAT sent: DoAction_Ability_Direct Eat Food (HP: %.0f%%)", hp))
        API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
        markActed()
        return true
    end
    return false
end

local function prayerPercent()
    local p = tonumber(API.GetPrayPrecent()) or 0
    if p > 0 and p <= 1 then
        p = p * 100
    end
    return p
end

local function buffRemaining(buffId)
    local b = API.Buffbar_GetIDstatus(buffId, false)
    if not b or not b.found then
        return 0
    end
    local remain = 0
    pcall(function()
        remain = tonumber(API.Bbar_ConvToSeconds(b)) or 0
    end)
    if remain > 0 then
        return remain
    end
    return 999
end

local function overloadActive()
    local best = 0
    for _, id in ipairs(OVERLOAD_BUFF_IDS) do
        local remain = buffRemaining(id)
        if remain > best then
            best = remain
        end
    end
    return best > OVERLOAD_REFRESH_SECONDS
end

local function drinkInventoryIds(ids, label)
    local found = nil
    for i = 1, #ids do
        local n = Inventory:InvItemcount(ids[i])
        if type(n) == "number" and n > 0 then
            found = ids[i]
            break
        end
    end
    if not found then
        return false
    end
    if API.DoAction_Inventory2 and API.DoAction_Inventory2(ids, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        actionLog("BUFF sent: drink " .. label .. " id=" .. tostring(found))
        markActed()
        return true
    end
    actionLog("BUFF sent: DoAction_Inventory1 " .. found .. " (" .. label .. ")")
    API.DoAction_Inventory1(found, 0, 1, API.OFF_ACT_GeneralInterface_route)
    markActed()
    return true
end

local function drinkByNames(names, label)
    for i = 1, #names do
        local name = names[i]
        local count = Inventory:InvItemcount_String(name)
        if type(count) == "number" and count > 0 then
            actionLog("BUFF sent: DoAction_Inventory3 '" .. name .. "' (" .. label .. ")")
            if API.DoAction_Inventory3(name, 0, 1, API.OFF_ACT_GeneralInterface_route) then
                markActed()
                return true
            end
        end
    end
    return false
end

local function drinkOverload()
    if drinkInventoryIds(OVERLOAD_IDS, "overload") then
        return true
    end
    return drinkByNames({
        "Elder overload salve",
        "Elder overload",
        "Supreme overload salve",
        "Supreme overload",
        "Holy aggroverload",
        "Holy overload",
        "Searing overload",
        "Overload salve",
        "Aggroverload",
        "Overload",
    }, "overload")
end

local function useElvenShard()
    local cd = API.DeBuffbar_GetIDstatus(ELVEN_SHARD_ID, false)
    if cd and cd.found then
        return false
    end
    local n = Inventory:InvItemcount(ELVEN_SHARD_ID)
    if type(n) ~= "number" or n <= 0 then
        return false
    end
    actionLog("BUFF sent: Ancient elven ritual shard")
    API.DoAction_Inventory1(ELVEN_SHARD_ID, 0, 1, API.OFF_ACT_GeneralInterface_route)
    markActed()
    return true
end

local function drinkPrayerOrRestore()
    if drinkInventoryIds(PRAYER_POTION_IDS, "prayer potion") then
        return true
    end
    if drinkInventoryIds(SUPER_RESTORE_IDS, "super restore") then
        return true
    end
    return drinkByNames({
        "Blessed flask",
        "Super prayer renewal",
        "Spiritual prayer",
        "Extreme prayer",
        "Super prayer flask",
        "Super prayer",
        "Prayer flask",
        "Prayer potion",
        "Super restore flask",
        "Super restore",
    }, "prayer/restore")
end

local function manageInstanceBuffs()
    if not atMagisterArea() then
        return false
    end
    if dialogOpen() or reaperInterfaceOpen() then
        return false
    end
    if not canAct(3) then
        return false
    end
    if not overloadActive() then
        if drinkOverload() then
            return true
        end
    end
    local pray = prayerPercent()
    if pray <= ELVEN_SHARD_PERCENT then
        if useElvenShard() then
            return true
        end
    end
    if pray <= PRAYER_POT_PERCENT then
        if drinkPrayerOrRestore() then
            return true
        end
    end
    return false
end

local function groundItems(distance)
    distance = distance or 40
    local results = {}
    local seenMem = {}
    local function add(list, requireType3)
        if not list then
            return
        end
        local okLen, n = pcall(function()
            return #list
        end)
        if not okLen or type(n) ~= "number" then
            return
        end
        for i = 1, n do
            local obj = list[i]
            if obj then
                local id = tonumber(obj.Id) or 0
                local typ = tonumber(obj.Type)
                if requireType3 and typ and typ ~= 3 then
                    id = 0
                end
                local key = tostring(obj.Mem or obj.Unique_Id or id) .. ":" .. tostring(id)
                if id > 0 and not seenMem[key] then
                    seenMem[key] = true
                    results[#results + 1] = obj
                end
            end
        end
    end
    pcall(function()
        add(API.GetAllObjArray1({ -1 }, distance, { 3 }), false)
    end)
    pcall(function()
        add(API.ReadAllObjectsArray({ 3 }, { -1 }, {}), false)
    end)
    pcall(function()
        add(API.ReadAllObjectsArray({ 3 }, {}, {}), false)
    end)
    pcall(function()
        add(API.ReadAllObjectsArray({ -1 }, {}, {}), true)
    end)
    table.sort(results, function(a, b)
        return (tonumber(a.Distance) or 0) < (tonumber(b.Distance) or 0)
    end)
    return results
end

local function groundLootIds(items)
    local ids = { 995 }
    local seen = { [995] = true }
    for i = 1, #items do
        local id = tonumber(items[i].Id)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function clickGroundItemToOpenLoot()
    local items = groundItems(40)
    local ids = groundLootIds(items)
    local tile = API.PlayerCoordfloat()
    local first = items[1]
    local firstId = first and first.Id or ids[1]
    lootOpenMethod = lootOpenMethod + 1
    local method = ((lootOpenMethod - 1) % 5) + 1
    actionLog("LOOT: " .. tostring(#items) .. " ground items, try=" .. tostring(method)
        .. " id=" .. tostring(firstId)
        .. (first and first.Name and (" " .. tostring(first.Name)) or ""))

    if method == 1 and #items > 0 then
        if API.DoAction_G_Items1(0x2d, ids, 30) then
            actionLog("LOOT sent: G_Items1 0x2d (open window)")
            markActed()
            return true
        end
    end
    if method == 2 then
        if API.KeyboardPress then
            API.KeyboardPress("\\", 0, 50)
            actionLog("LOOT sent: KeyboardPress \\ (area loot)")
            markActed()
            return true
        end
        if API.KeyboardPress2 then
            API.KeyboardPress2(0xDC, 40, 60)
            actionLog("LOOT sent: KeyboardPress2 VK_OEM_5 (area loot)")
            markActed()
            return true
        end
    end
    if method == 3 and #items > 0 then
        if API.DoAction_G_Items1(0x45, ids, 30) then
            actionLog("LOOT sent: G_Items1 0x45 (open window)")
            markActed()
            return true
        end
    end
    if method == 4 then
        if API.DoAction_Loot_w and API.DoAction_Loot_w(ids, 30, tile, 30) then
            actionLog("LOOT sent: DoAction_Loot_w (open window)")
            markActed()
            return true
        end
        if API.DoAction_Loot_k then
            API.DoAction_Loot_k(ids, 30, 28, 92, 0)
            actionLog("LOOT sent: DoAction_Loot_k (open window)")
            markActed()
            return true
        end
    end
    if method == 5 then
        if first and API.DoAction_G_Items_Direct then
            local route = API.OFF_ACT_GeneralObject_route0
            if API.DoAction_G_Items_Direct(0x2d, route, first) then
                actionLog("LOOT sent: G_Items_Direct 0x2d id=" .. tostring(firstId))
                markActed()
                return true
            end
        end
        if API.DoAction_Loot_o then
            local ok = API.DoAction_Loot_o(ids, 30, tile, 30, {
                allowCoins = true,
                coinMinAmount = 1,
                useLootAll = false,
                useKeybindToOpen = true,
            })
            if ok then
                actionLog("LOOT sent: DoAction_Loot_o (open window)")
                markActed()
                return true
            end
        end
    end
    actionLog("LOOT failed: open method " .. tostring(method) .. " did not land")
    markActed()
    return false
end

local function handleDialog()
    if not dialogOpen() then
        return false
    end
    if not canAct(2) then
        return true
    end
    if chatOpen() then
        pressDigit(1)
        return true
    end
    if continueOpen() then
        pressContinue()
        return true
    end
    if clickOption("Yes") then
        return true
    end
    pressDigit(1)
    return true
end

-------------------------------------------------
-- States
-------------------------------------------------

local function doInit()
    if API.IsInDeathOffice() then
        log("In Death's office — stopping so you can reclaim")
        API.Write_LoopyLoop(false)
        return
    end
    if atWars() then
        if GET_REAPER_ASSIGNMENT then
            setState(STATE.CHECK_TASK)
        else
            setState(STATE.BANK)
        end
    elseif atArena() then
        if magisterNearby() or findObject(OBELISK_FIGHT_ID, 40) then
            setState(STATE.FIGHT)
        else
            setState(STATE.START_ENCOUNTER)
        end
    elseif atGate() then
        setState(STATE.ENTER_GATE)
    else
        log("Unknown location — teleporting to War's Retreat")
        leaveToWars()
    end
end

local function doTeleWars()
    if atWars() then
        bankAttempts = 0
        emptyPresetStops = 0
        magisterTaskOk = false
        deflectSentThisTrip = false
        arenaSettled = false
        arenaSettleTick = 0
        if GET_REAPER_ASSIGNMENT then
            setState(STATE.CHECK_TASK)
        else
            setState(STATE.BANK)
        end
        return
    end
    if isMoving() then
        return
    end
    if not prayerOffSent then
        disablePrayer()
        prayerOffSent = true
        return
    end
    if canAct(8) then
        log("War's Retreat Teleport")
        teleWars()
        markActed()
    end
end

local function doCheckTask()
    if not GET_REAPER_ASSIGNMENT then
        setState(STATE.BANK)
        return
    end
    if not atWars() then
        setState(STATE.TELE_WARS)
        return
    end
    if handleDialog() then
        return
    end
    if not cacheLoaded() then
        if ticksInState() == 0 or ticksInState() % 20 == 0 then
            log("Waiting for IsCacheLoaded() before reading reaper varbit " .. REAPER_TASK_VARBIT)
        end
        return
    end
    if hasReaperTask() then
        log("Reaper task found (varbit " .. REAPER_TASK_VARBIT .. "=" .. tostring(reaperTaskValue()) .. ")")
        magisterTaskOk = true
        setState(STATE.BANK)
        return
    end
    log("No reaper assignment (varbit " .. REAPER_TASK_VARBIT .. "=0) — requesting Magister")
    beginGetTask(STATE.BANK)
end

local function doGetTask()
    if not GET_REAPER_ASSIGNMENT then
        if atWars() then
            setState(STATE.BANK)
        else
            setState(STATE.START_ENCOUNTER)
        end
        return
    end
    if not cacheLoaded() then
        return
    end

    local listOpen = reaperInterfaceOpen()

    local function handleReaperConfirm()
        if not dialogOpen() then
            return true
        end
        if not canAct(2) then
            return true
        end
        if reaperConfirmStep <= 1 then
            pressContinue()
            reaperConfirmStep = 2
            return true
        end
        pressDigit(1)
        reaperConfirmStep = 3
        return true
    end

    if hasReaperTask() and reaperConfirmStep >= 3 and not dialogOpen() then
        log("Magister reaper task accepted (varbit " .. REAPER_TASK_VARBIT .. "=" .. tostring(reaperTaskValue()) .. ") — resume " .. afterTaskState)
        magisterTaskOk = true
        setState(afterTaskState)
        return
    end

    if listOpen then
        if canAct(3) then
            if selectMagisterReaperTask() then
                clickedMagister = true
                reaperConfirmStep = 1
            end
            markActed()
        end
        return
    end

    if clickedMagister and reaperConfirmStep < 3 then
        handleReaperConfirm()
        return
    end

    if hasReaperTask() then
        if dialogOpen() then
            if reaperConfirmStep < 3 then
                handleReaperConfirm()
            elseif canAct(2) then
                pressContinue()
            end
            return
        end
        log("Magister reaper task accepted (varbit " .. REAPER_TASK_VARBIT .. "=" .. tostring(reaperTaskValue()) .. ") — resume " .. afterTaskState)
        magisterTaskOk = true
        setState(afterTaskState)
        return
    end

    if not hasGrimGem() then
        log("No Grim gem in inventory — cannot request a reaper task here")
        if atWars() then
            setState(STATE.BANK)
        else
            leaveToWars()
        end
        return
    end

    if ticksInState() > 50 and not clickedMagister then
        log("Still no Magister assignment (varbit " .. REAPER_TASK_VARBIT .. "=0) — retrying Grim gem")
        reaperConfirmStep = 0
        stateEnteredTick = API.Get_tick()
    end
    if isMoving() then
        return
    end
    if canAct(8) then
        openReaperAssignment()
        markActed()
    end
end

local function doBank()
    if not atWars() then
        setState(STATE.TELE_WARS)
        return
    end
    if dialogOpen() then
        handleDialog()
        return
    end
    if ticksInState() < 3 then
        return
    end
    if stateActionDone then
        if ticksInState() >= 8 then
            if not hasKeys() then
                emptyPresetStops = emptyPresetStops + 1
                if emptyPresetStops >= 2 then
                    log("No Key to the Crossing after loading preset — add keys to your last preset")
                    API.Write_LoopyLoop(false)
                    return
                end
                log("Preset loaded with 0 keys — retrying bank")
                stateActionDone = false
                stateEnteredTick = API.Get_tick()
                return
            end
            emptyPresetStops = 0
            setState(STATE.ALTAR)
        end
        return
    end
    if isMoving() then
        return
    end
    if not canAct(4) then
        return
    end
    log("Loading last preset")
    loadLastPreset()
    stateActionDone = true
    bankAttempts = bankAttempts + 1
    markActed()
end

local function doAltar()
    if not atWars() then
        setState(STATE.TELE_WARS)
        return
    end
    if isMoving() then
        return
    end
    if stateActionDone then
        if ticksInState() >= 6 then
            setState(STATE.ENTER_PORTAL)
        end
        return
    end
    if ticksInState() < 2 then
        return
    end
    log("Praying at Altar of War")
    prayAltar()
    stateActionDone = true
    markActed()
end

local function doEnterPortal()
    if atMagisterArea() then
        if atArena() then
            setState(STATE.START_ENCOUNTER)
        else
            setState(STATE.ENTER_GATE)
        end
        return
    end
    if GET_REAPER_ASSIGNMENT then
        local blob = chatBlob()
        if chatIndicatesNoTask(blob) then
            log("Reaper portal requires an assignment")
            magisterTaskOk = false
            beginGetTask(STATE.BANK)
            return
        end
    end
    if not atWars() then
        if ticksInState() > 25 then
            if atMagisterArea() then
                setState(STATE.ENTER_GATE)
            else
                log("Portal did not land at Magister — returning to Wars")
                leaveToWars()
            end
        end
        return
    end
    if isMoving() then
        return
    end
    if not hasKeys() then
        log("No keys before portal — banking again")
        setState(STATE.BANK)
        return
    end
    if canAct(5) then
        if GET_REAPER_ASSIGNMENT then
            log("Entering Reaper / Magister portal")
        else
            log("Entering Wars boss portal (The Magister)")
        end
        if not enterPortal() then
            if GET_REAPER_ASSIGNMENT then
                log("Portal not found — use the Reaper portal, or attune a Wars portal to The Magister")
            else
                log("Wars portal not found — attune a boss portal to The Magister")
            end
        end
        markActed()
    end
end

local function doEnterGate()
    if handleDialog() then
        return
    end
    if manageInstanceBuffs() then
        return
    end
    if atArena() then
        setState(STATE.START_ENCOUNTER)
        return
    end
    if not atGate() and ticksInState() > 15 then
        if atWars() then
            setState(STATE.ENTER_PORTAL)
        else
            setState(STATE.START_ENCOUNTER)
        end
        return
    end
    if isMoving() then
        return
    end
    if enablePrayerBeforeArena() then
        return
    end
    if canAct(5) then
        log("Entering The First Gate")
        enterGate()
        markActed()
    end
end

local function doStartEncounter()
    if reaperInterfaceOpen() then
        beginGetTask(STATE.START_ENCOUNTER)
        return
    end
    if handleDialog() then
        return
    end
    if manageInstanceBuffs() then
        return
    end

    local inFight = magisterNearby() or API.LocalPlayer_IsInCombat_()

    if GET_REAPER_ASSIGNMENT then
        if not cacheLoaded() then
            if ticksInState() == 0 or ticksInState() % 20 == 0 then
                log("Waiting for IsCacheLoaded() before reaper check at obelisk")
            end
            return
        end
        if not hasReaperTask() and not inFight then
            log("No Magister reaper assignment (varbit " .. REAPER_TASK_VARBIT .. "=0) — getting a new task before the fight")
            beginGetTask(STATE.START_ENCOUNTER)
            return
        end
    end

    if inFight or findObject(OBELISK_FIGHT_ID, 40) then
        setState(STATE.FIGHT)
        return
    end
    if inventoryFull() then
        log("Inventory full — teleporting to Wars to bank")
        leaveToWars()
        return
    end
    if not hasKeys() then
        log("Out of keys — teleporting to Wars")
        leaveToWars()
        return
    end
    if not atArena() then
        if atGate() then
            setState(STATE.ENTER_GATE)
            return
        end
        if ticksInState() > 12 then
            setState(STATE.ENTER_GATE)
        end
        return
    end
    if isMoving() then
        return
    end
    if not arenaSettled then
        if arenaSettleTick == 0 then
            arenaSettleTick = API.Get_tick()
            log("Waiting for the arena to load before touching the Soul obelisk")
        end
        if (API.Get_tick() - arenaSettleTick) < ARENA_SETTLE_TICKS then
            return
        end
        arenaSettled = true
    end
    if enablePrayerBeforeArena() then
        return
    end
    if canAct(5) then
        log("Touching Soul obelisk (consumes a key)")
        touchObelisk()
        magisterAttackedThisFight = false
        markActed()
    end
end

local function doFight()
    if handleDialog() then
        return
    end

    if ensurePrayerUp() then
        return
    end

    if not magisterAttackedThisFight and magisterNearby() then
        if canAct(2) then
            log("Attacking The Magister (once this fight)")
            attackMagister()
            magisterAttackedThisFight = true
            markActed()
        end
        return
    end

    if eatFood() or useExcalibur() then
        return
    end
    if manageInstanceBuffs() then
        return
    end

    local inCombat = API.LocalPlayer_IsInCombat_()
    local bossUp = magisterNearby()

    if not bossUp and not inCombat then
        if ticksInState() < 8 then
            return
        end
        recordKill()
        setState(STATE.LOOT)
        return
    end

    if ATTACK_FIGHT_OBELISK and findObject(OBELISK_FIGHT_ID, 40) then
        local hp = API.GetHPrecent() or 100
        if hp < OBELISK_HP and canAct(4) then
            log("Attacking Soul obelisk (constitution drain)")
            attackObelisk()
            markActed()
            return
        end
    end
end

local function proceedAfterLoot()
    if inventoryFull() then
        log("Inventory full — teleporting to Wars to bank")
        leaveToWars()
        return
    end
    if GET_REAPER_ASSIGNMENT and cacheLoaded() and not hasReaperTask() then
        log("Reaper assignment is 0 — getting a new Magister task before the next kill")
        beginGetTask(atWars() and STATE.BANK or STATE.START_ENCOUNTER)
        return
    end
    if hasKeys() then
        setState(STATE.START_ENCOUNTER)
    else
        log("Out of keys — teleporting to Wars")
        leaveToWars()
    end
end

local function doLoot()
    if isMoving() then
        return
    end

    if API.LootWindowOpen_2() then
        if not stateActionDone then
            if canAct(2) then
                actionLog("LOOT sent: DoAction_LootAll_Button")
                API.DoAction_LootAll_Button()
                markActed()
                stateActionDone = true
                stateEnteredTick = API.Get_tick()
            end
            return
        end
        if ticksInState() < 3 then
            return
        end
        proceedAfterLoot()
        return
    end

    if ticksInState() < 24 then
        if canAct(3) then
            clickGroundItemToOpenLoot()
            lootOpenAttempted = true
        end
        return
    end

    if manageInstanceBuffs() then
        return
    end

    proceedAfterLoot()
end

local handlers = {
    [STATE.INIT] = doInit,
    [STATE.TELE_WARS] = doTeleWars,
    [STATE.CHECK_TASK] = doCheckTask,
    [STATE.GET_TASK] = doGetTask,
    [STATE.BANK] = doBank,
    [STATE.ALTAR] = doAltar,
    [STATE.ENTER_PORTAL] = doEnterPortal,
    [STATE.ENTER_GATE] = doEnterGate,
    [STATE.START_ENCOUNTER] = doStartEncounter,
    [STATE.FIGHT] = doFight,
    [STATE.LOOT] = doLoot,
}

-------------------------------------------------
-- GUI
-------------------------------------------------

if DrawImGui then
    DrawImGui(function()
        ImGui.Begin("Magister Killer")
        ImGui.Text("Keys: " .. tostring(keyCount()))
        ImGui.Text("Runtime: " .. formatTime(os.time() - startTime))
        ImGui.Text(string.format("Kills: %d  (%.0f/hr)", kills, perHour(kills)))
        ImGui.Text("Reaper tasks: " .. tostring(reaperTasksCompleted))
        ImGui.End()
    end)
end

-------------------------------------------------
-- Main
-------------------------------------------------

log("Started — auto farm ON  |  attack fight obelisk=" .. tostring(ATTACK_FIGHT_OBELISK)
    .. "  get reaper=" .. tostring(GET_REAPER_ASSIGNMENT)
    .. "  prayer=" .. prayerMode())
if GET_REAPER_ASSIGNMENT then
    log("Use the Wars Reaper portal, or attune a boss portal to The Magister")
else
    log("Reaper check off — attune a Wars boss portal to The Magister")
end

while API.Read_LoopyLoop() do
    if API.GetGameState2() ~= 3 then
        log("Not in game — stopping")
        API.Write_LoopyLoop(false)
        break
    end
    if API.IsInDeathOffice() then
        log("Died — stopping so you can reclaim")
        API.Write_LoopyLoop(false)
        break
    end

    trackReaperCompletion()
    pcall(API.DoRandomEvents, 300, 200, false)
    if not ensureDarkness() then
        local handler = handlers[currentState]
        if handler then
            handler()
        else
            log("Unknown state: " .. tostring(currentState))
            setState(STATE.INIT)
        end
    end
    API.RandomSleep2(200, 100, 100)
end

log("Stopped")
