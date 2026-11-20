-- ED3 Hanto loop
--
-- Bank preset at the Fremennik banker -> sail to The Shadow Reef (normal mode) ->
-- clear the Crassian scouts/scuttlers around Hanto -> kill Hanto -> protect prayer
-- off -> ring of kinship teleport out -> repeat.
--
-- Story mode would be the second dialogue option (component 1188,13); this
-- script now selects normal mode (component 1188,8).
--
-- If Hanto (npc 26203) is not in the area, the run is abandoned and the script
-- banks/re-enters for another try.
--
-- Action bar requirements:
--   * Eat Food
--   * Protect from Ranged  (Crassian scouts)
--   * Protect from Magic   (Hanto)
--
-- The preset loaded from the banker must contain the ring of kinship.
-- Prayer potions/super restores are optional: if they are in the preset the
-- script sips one below 30% prayer, otherwise it fights with what it has.

local API = require("api")

local IDS = {
	BANKER = 9710,   -- Fremennik banker
	SHIP   = 5999,   -- Fremennik ship (Shadow reef)
	HANTO  = 26203,
	RING   = 15707,
	EXIT   = 6150,   -- instance "Exit" object (Climb)
}
local EXIT_ACTION = 0xb5

-- Crassian scouts and scuttlers are the enemies that keep Hanto's barrier up.
local TRASH = {
	[26147] = true, [26148] = true, [26149] = true, -- Crassian scout
	[26154] = true, [26155] = true, [26156] = true, [26157] = true, -- Crassian scuttler
}

local PRAYER_VARBIT = {
	['Protect from Ranged'] = 16746,
	['Protect from Magic']  = 16745,
	['Protect from Melee']  = 16747,
}

local FOOD_EAT_AT = 60      -- eat below this % of max life points
local FOOD_EAT_MS = 1600    -- gap between bites
local TRASH_NEAR_HANTO = 22 -- trash this close to Hanto blocks him

local RENEWAL_NAME = 'Super prayer renewal potion'
local RENEWAL_AT = 50       -- drink below this % prayer
local RENEWAL_MS = 60000    -- never try more than once a minute
local RENEWAL_BUFF = 14695  -- prayer renewal buff id

-- Optional: if the preset carries prayer/restore potions, sip one when prayer
-- gets low. The current food preset has none, so this is a no-op for it.
local PRAYER_POTIONS = {
	[2434] = true, [139] = true, [141] = true, [143] = true,       -- prayer potion
	[3024] = true, [3026] = true, [3028] = true, [3030] = true,    -- super restore
	[23399] = true, [23401] = true, [23403] = true, [23405] = true,
	[23407] = true, [23409] = true,
}

local S = {
	status = "starting",
	lastEat = 0,
	lastRenewalAt = 0,
	lastPrayerOn = {},
	lastPrayerOff = {},
	lastQpOff = 0,
	kills = 0,
	exits = 0,
	runs = 0,
	lastError = "",
	lastTargetKey = nil,
	lastTargetHp = nil,
	lastHpChangeAt = 0,
}

local UI = {
	status = "starting",
	kills = 0,
	exits = 0,
	runs = 0,
	hp = 0,
	prayer = 0,
	food = 0,
	renewal = 0,
	tilt = 0,
	inInstance = false,
	hanto = false,
	hantoHp = 0,
	protMagic = false,
	protRanged = false,
	target = "-",
	lastError = "",
	nextAt = 0,
}

local function log(msg) print('[ED3 Hanto] ' .. tostring(msg)) end
local function say(msg)
	S.status = msg
	UI.status = msg
	API.Write_ScripCuRunning0('ED3 Hanto: ' .. tostring(msg))
end
local function sleep(ms, a, b) API.RandomSleep2(ms or 500, a or 100, b or 200) end

local function player()
	local p = API.PlayerCoord()
	return math.floor(p.x), math.floor(p.y), math.floor(p.z or 0)
end

local function tileOf(o)
	local t = o.Tile_XYZ
	return math.floor(tonumber(t.x) or 0), math.floor(tonumber(t.y) or 0), math.floor(tonumber(t.z) or 0)
end

local function tileDistance(x1, y1, x2, y2)
	local dx, dy = x1 - x2, y1 - y2
	return math.sqrt(dx * dx + dy * dy)
end

local function inInstance()
	return API.InInstancedArea() == true
end

local function inDaemonheim()
	local x, y = player()
	return x and y and x >= 3400 and x <= 3600 and y >= 3600 and y <= 3800
end

local function scanNpcs()
	local ok, list = pcall(API.ReadAllObjectsArray, { 1 }, {}, {}, -1)
	if ok and list then return list end
	return {}
end

local function findHanto(maxDist)
	local px, py = player()
	for _, n in ipairs(scanNpcs()) do
		if tonumber(n.Id) == IDS.HANTO and (tonumber(n.Life) or 0) > 0 then
			local x, y = tileOf(n)
			local d = math.max(math.abs(x - px), math.abs(y - py))
			if d <= (maxDist or 80) then return n end
		end
	end
	return nil
end

local function findTrashNearHanto(hanto, maxDist)
	local hx, hy = tileOf(hanto)
	local px, py = player()
	local best, bestD = nil, nil
	for _, n in ipairs(scanNpcs()) do
		if TRASH[tonumber(n.Id)] and (tonumber(n.Life) or 0) > 0 then
			local x, y = tileOf(n)
			local toHanto = math.max(math.abs(x - hx), math.abs(y - hy))
			-- Only the groups south of Hanto (the entry group) and east of him
			-- hold the barrier. The scouts north-west of him are a different
			-- room: Hanto is already attackable while they are still alive.
			local relevant = (y >= hy - 2) or (x >= hx + 5)
			if relevant and toHanto <= (maxDist or TRASH_NEAR_HANTO) then
				-- pick the blocker nearest to us, so the first group is cleared
				-- before the group that stands next to Hanto
				local toPlayer = math.max(math.abs(x - px), math.abs(y - py))
				if not bestD or toPlayer < bestD then
					best, bestD = n, toPlayer
				end
			end
		end
	end
	return best, bestD
end

local function attackNpc(n)
	if not n then return false end
	local ok, res = pcall(function()
		return API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, n)
	end)
	if ok and res == true then return true end
	local id = tonumber(n.Id)
	if id then
		local ok2, res2 = pcall(function()
			return API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, { id }, 60)
		end)
		if ok2 and res2 == true then return true end
	end
	return false
end

local function isMoving()
	local ok, v = pcall(API.ReadPlayerMovin)
	return ok and v == true
end

local function inCombat()
	local ok, v = pcall(API.LocalPlayer_IsInCombat_)
	if ok then return v == true end
	local ok2, v2 = pcall(API.GetInCombBit)
	return ok2 and v2 == true
end

-- Camera tilt: API.GetTilt() (VP 5114) sits around 1400+ for a normal camera.
-- One tap of the up arrow puts a low/odd camera back to the normal tilt.
local CAMERA_MIN_TILT = 1400
local function fixCamera()
	local ok, tilt = pcall(API.GetTilt)
	tilt = ok and tonumber(tilt) or nil
	if tilt and tilt < CAMERA_MIN_TILT then
		API.KeyboardPress31(0x26, 80, 1000)
		API.RandomSleep2(400, 100, 150)
		return true
	end
	return false
end

local function walkTo(x, y, z, tol, timeout)
	tol = tol or 3
	local endAt = API.SystemTime() + (timeout or 20000)
	local lastClick = 0
	while API.Read_LoopyLoop() and API.SystemTime() < endAt do
		local px, py = player()
		if math.max(math.abs(px - x), math.abs(py - y)) <= tol then return true end
		-- one walk command at a time: only click when the previous move has
		-- stopped, and never more than once per 1.2 s
		if not isMoving() and (API.SystemTime() - lastClick) >= 1200 then
			API.DoAction_Tile(FFPOINT.new(x, y, z or 0))
			lastClick = API.SystemTime()
		end
		sleep(400, 100, 200)
	end
	local px, py = player()
	return math.max(math.abs(px - x), math.abs(py - y)) <= (tol + 3)
end

local function invSig()
	local ok, items = pcall(function() return Inventory:GetItems() end)
	if not ok or not items then return '' end
	local t = {}
	for _, it in ipairs(items) do
		t[#t + 1] = tostring(it.id) .. ':' .. tostring(it.amount)
	end
	return table.concat(t, ',')
end

local function invCount(namePart)
	local n = 0
	local ok, items = pcall(function() return Inventory:GetItems() end)
	if not ok or not items then return 0 end
	for _, it in ipairs(items) do
		local name = string.lower(tostring(it.name or ''))
		if name ~= '' and string.find(name, namePart, 1, true) then
			n = n + (tonumber(it.amount) or 1)
		end
	end
	return n
end

local function prayerPoints()
	local ok, v = pcall(API.GetPray_)
	if ok and tonumber(v) then return tonumber(v) end
	return 0
end

local function prayerOn(name)
	local vp = PRAYER_VARBIT[name]
	if not vp then return nil end
	local ok, v = pcall(API.VP_FindPSettBit, vp)
	if ok and tonumber(v) then return tonumber(v) > 0 end
	return false
end

-- Debug overlay data. The render callback only reads these fields; all game
-- API calls happen here on the script thread, throttled to ~1 s.
local function updateUI(force)
	local now = API.SystemTime()
	if not force and now < (UI.nextAt or 0) then return end
	UI.nextAt = now + 800

	UI.status = S.status or '-'
	UI.kills = S.kills or 0
	UI.exits = S.exits or 0
	UI.runs = S.runs or 0
	UI.lastError = S.lastError or ''

	local okHp, hp = pcall(API.GetHPrecent)
	UI.hp = okHp and tonumber(hp) or 0
	local okPr, pr = pcall(API.GetPrayPrecent)
	UI.prayer = okPr and tonumber(pr) or 0
	local okT, tilt = pcall(API.GetTilt)
	UI.tilt = okT and tonumber(tilt) or 0

	UI.inInstance = inInstance()
	if not UI.inInstance then
		UI.hanto = false
		UI.hantoHp = 0
		UI.target = '-'
	end
	UI.protMagic = prayerOn('Protect from Magic') == true
	UI.protRanged = prayerOn('Protect from Ranged') == true
	UI.food = invCount('rocktail')
	UI.renewal = invCount('super prayer renewal')
end

local function abilityEnabled(ab)
	if not ab then return false end
	if ab.enabled == true then return true end
	return tonumber(ab.enabled) == 1
end

local function prayerAbility(name)
	local ok, ab = pcall(function() return API.GetABs_name1(name) end)
	if ok and abilityEnabled(ab) then return ab end
	return nil
end

local function setPrayer(name, on)
	local state = prayerOn(name)
	if state == (on == true) then return true end
	if on and prayerPoints() <= 0 then return false end
	if on and (API.SystemTime() - (S.lastPrayerOn[name] or 0)) < 2000 then return false end
	local ab = prayerAbility(name)
	if not ab then return false end
	local ok, res = pcall(function()
		return API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
	end)
	if not (ok and res == true) then return false end
	if on then
		S.lastPrayerOn[name] = API.SystemTime()
		S.lastPrayerOff[name] = nil
	end
	API.RandomSleep2(300, 100, 100)
	return true
end

local function turnOffPrayers()
	for name in pairs(PRAYER_VARBIT) do
		if prayerOn(name) == true then
			local now = API.SystemTime()
			-- Never press the same prayer twice inside 2 s. The first call after
			-- a kill turned it off, the ringTeleport call immediately after was
			-- toggling it straight back on before the varbit had updated.
			if (now - (S.lastPrayerOff[name] or 0)) > 2000 then
				local ab = prayerAbility(name)
				if ab then
					S.lastPrayerOff[name] = now
					log('turning off ' .. name)
					pcall(function()
						return API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
					end)
					-- let the prayer varbit update before any second caller runs
					API.RandomSleep2(600, 100, 150)
				end
			end
		end
	end

	local ok, qp = pcall(API.GetQuickPray)
	if ok and (qp == true or qp == 1) then
		local now = API.SystemTime()
		if (now - (S.lastQpOff or 0)) > 2000 then
			S.lastQpOff = now
			log('turning off quick prayers')
			pcall(API.DoAction_Button_QP)
			API.RandomSleep2(600, 100, 150)
		end
	end
end

local function eatFood()
	local ok, hp = pcall(API.GetHPrecent)
	hp = ok and tonumber(hp) or nil
	if not hp or hp >= FOOD_EAT_AT then return false end
	if (API.SystemTime() - (S.lastEat or 0)) < FOOD_EAT_MS then return false end
	local ab = prayerAbility('Eat Food')
	if not ab then return false end
	local ok2, res = pcall(function()
		return API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
	end)
	if ok2 and res == true then
		S.lastEat = API.SystemTime()
		return true
	end
	return false
end

-- Optional prayer/restore potion sip. Does nothing unless the preset carries
-- one of the ids above.
local function drinkPrayer()
	local pts = prayerPoints()
	local okMax, max = pcall(API.GetPrayMax_)
	max = okMax and tonumber(max) or 750
	if max and max > 0 and pts > max * 0.30 then return false end
	local ok, items = pcall(function() return Inventory:GetItems() end)
	if not ok or not items then return false end
	for _, it in ipairs(items) do
		local id = tonumber(it.id)
		if id and PRAYER_POTIONS[id] then
			local ok2, res = pcall(function()
				return API.DoAction_Inventory1(id, 0, 1, API.OFF_ACT_GeneralInterface_route)
			end)
			if ok2 and res == true then
				sleep(1200, 200, 300)
				return true
			end
		end
	end
	return false
end

local function renewalActive()
	local ok, buff = pcall(API.Buffbar_GetIDstatus, RENEWAL_BUFF, false)
	if ok and buff and buff.found == true then return true end
	return false
end

-- Super prayer renewal potion on the action bar. The ability's enabled flag is
-- the inventory check: once the last dose is gone, GetABs_name1 still returns a
-- record but enabled is false, so it must not be pressed.
local function drinkRenewal()
	local ok, pc = pcall(API.GetPrayPrecent)
	pc = ok and tonumber(pc) or nil
	if not pc or pc >= RENEWAL_AT then return false end
	if renewalActive() then return false end
	if (API.SystemTime() - (S.lastRenewalAt or 0)) < RENEWAL_MS then return false end

	local okAb, ab = pcall(function() return API.GetABs_name1(RENEWAL_NAME) end)
	if not okAb or not ab then
		if not S.noRenewalLog then
			S.noRenewalLog = true
			log('Super prayer renewal potion is not on the action bar')
		end
		return false
	end
	if not abilityEnabled(ab) then
		if not S.noRenewalLog then
			S.noRenewalLog = true
			log('Super prayer renewal potion is out of stock (ability disabled)')
		end
		return false
	end
	if tonumber(ab.cooldown_timer or 0) > 0 then return false end

	local ok2, res = pcall(function()
		return API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
	end)
	if ok2 and res == true then
		S.noRenewalLog = nil
		S.lastRenewalAt = API.SystemTime()
		log(string.format('drinking Super prayer renewal at %d%% prayer', math.floor(pc)))
		API.RandomSleep2(600, 150, 250)
		return true
	end
	return false
end

local function choose(text)
	local ok, num = pcall(API.Dialog_Option, text)
	num = tonumber(num)
	if ok and num and num > 0 then
		API.KeyboardPress2(0x30 + num, 60, 100)
		API.RandomSleep2(450, 200, 300)
		return true
	end
	return false
end

-- Ship dialogue options:
--   continue prompt: "No."          -> option 2, component 13
--   enter prompt:    "Normal mode"  -> option 1, component 8
-- Story mode would be option 2 (component 13) if it is ever switched back.
local function clickDialogOption(component)
	return API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1188, component, -1,
		API.OFF_ACT_GeneralInterface_Choose_option)
end

local function waitForShadowReef(timeout)
	local endAt = API.SystemTime() + (timeout or 20000)
	while API.Read_LoopyLoop() and API.SystemTime() < endAt do
		if inInstance() then
			API.RandomSleep2(2500, 500, 500)
			return true
		end

		if API.GetInterfaceOpenBySize(1188) then
			local no = tonumber(API.Dialog_Option('No.'))
			if no and no > 0 then
				pcall(clickDialogOption, 13)
			else
				local normal = tonumber(API.Dialog_Option('Normal mode'))
				if normal and normal > 0 then
					pcall(clickDialogOption, 8)
				else
					pcall(clickDialogOption, 8) -- first option
				end
			end
			sleep(1200, 200, 300)
		elseif API.Check_Dialog_Open() then
			-- fallback if the interface scan misses: text + number key
			local chose = choose('No.')
			if not chose then chose = choose('Normal mode') end
			sleep(450, 100, 200)
		else
			sleep(350, 80, 150)
		end
	end
	return inInstance()
end

local function ringTeleport()
	say('teleporting out')
	turnOffPrayers()

	local hasRing = false
	local ok, items = pcall(function() return Inventory:GetItems() end)
	if ok and items then
		for _, it in ipairs(items) do
			if tonumber(it.id) == IDS.RING then hasRing = true; break end
		end
	end

	if hasRing then
		pcall(function()
			return API.DoAction_Inventory1(IDS.RING, 0, 3, API.OFF_ACT_GeneralInterface_route)
		end)
	else
		-- worn ring: second option on the action-bar ability
		local ab = prayerAbility('Ring of kinship')
		if ab then
			pcall(function()
				return API.DoAction_Ability_Direct(ab, 2, API.OFF_ACT_GeneralInterface_route)
			end)
		end
	end

	local endAt = API.SystemTime() + 15000
	while API.Read_LoopyLoop() and API.SystemTime() < endAt do
		if inDaemonheim() then return true end
		sleep(400, 100, 200)
	end
	return inDaemonheim()
end

local function loadPreset()
	say('loading preset')

	-- If the bank happens to be open, ESC it first: the banker's "Load Last
	-- Preset from" option is a right-click action, not a bank interface action.
	local okOpen, bankOpen = pcall(API.GetInterfaceOpenBySize, 517)
	if okOpen and bankOpen then
		API.KeyboardPress2(0x1B, 60, 100)
		sleep(500, 100, 200)
	end

	walkTo(3449, 3719, 0, 2, 20000)

	local before = invSig()
	local sent = false
	local ok, res = pcall(function()
		return API.DoAction_NPC(0x33, API.OFF_ACT_InteractNPC_route4, { IDS.BANKER }, 50)
	end)
	if ok and res == true then sent = true end
	if not sent then
		pcall(function()
			return API.DoAction_NPC_str(0x33, API.OFF_ACT_InteractNPC_route4, { 'Fremennik banker' }, 50)
		end)
	end

	-- One load is enough. If the inventory already matched the preset the
	-- signature will not change, so do not click the banker again.
	local endAt = API.SystemTime() + 3000
	while API.Read_LoopyLoop() and API.SystemTime() < endAt do
		if invSig() ~= before then break end
		sleep(300, 80, 150)
	end
	sleep(500, 150, 250)
	return true
end

local function sailToShadowReef()
	if inInstance() then return true end
	fixCamera()

	say('walking to the ship')
	walkTo(3510, 3691, 0, 3, 25000)

	for _ = 1, 4 do
		if not API.Read_LoopyLoop() then return false end
		say('sailing')
		pcall(function()
			return API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { IDS.SHIP }, 50)
		end)
		sleep(1200, 250, 350)
		if waitForShadowReef(15000) then return true end
		if not API.Read_LoopyLoop() then return false end
		walkTo(3512, 3692, 0, 2, 10000)
	end
	return inInstance()
end

local function moveToHantoRange(hanto, want)
	local px, py, pz = player()
	local hx, hy = tileOf(hanto)
	local dx, dy = px - hx, py - hy
	local d = math.sqrt(dx * dx + dy * dy)
	if d < 0.1 then dx, dy, d = 0, 1, 1 end
	-- unit vector from Hanto to the player, then rotate it by an offset.
	-- (no math.atan: its two-argument form is not available in every Lua build)
	local ux, uy = dx / d, dy / d

	for _, off in ipairs({ 0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 3.14 }) do
		if not API.Read_LoopyLoop() then return false end
		local c, s = math.cos(off), math.sin(off)
		local rx = ux * c - uy * s
		local ry = ux * s + uy * c
		local tx = math.floor(hx + rx * want + 0.5)
		local ty = math.floor(hy + ry * want + 0.5)
		API.DoAction_Tile(FFPOINT.new(tx, ty, pz))
		sleep(900, 150, 200)
		local nx, ny = player()
		if nx ~= px or ny ~= py then return true end
	end
	return false
end

-- Use the "Exit" object next to the instance entrance. This leaves the
-- dungeon and puts the player back on the Fremennik ship without banking.
local function exitInstance()
	say('Hanto not here - taking Exit')
	turnOffPrayers()
	local ok, res = pcall(function()
		return API.DoAction_Object1(EXIT_ACTION, API.OFF_ACT_GeneralObject_route0, { IDS.EXIT }, 50)
	end)
	if not (ok and res == true) then
		pcall(function()
			return API.DoAction_Object_string1(EXIT_ACTION, API.OFF_ACT_GeneralObject_route0, { 'Exit' }, 50, true)
		end)
	end

	local endAt = API.SystemTime() + 15000
	while API.Read_LoopyLoop() and API.SystemTime() < endAt do
		if not inInstance() then
			sleep(600, 150, 250)
			-- camera resets when leaving an instance; put it back to normal
			fixCamera()
			S.exits = (S.exits or 0) + 1
			updateUI(true)
			return true
		end
		sleep(400, 100, 200)
	end
	if not inInstance() then
		fixCamera()
		S.exits = (S.exits or 0) + 1
		updateUI(true)
		return true
	end
	return false
end

-- Returns "killed" when Hanto dies, "exit" when the nearby Exit was used to
-- reset the instance, or "failed" if neither worked.
local function clearToHanto()
	S.runs = (S.runs or 0) + 1
	fixCamera()
	local entryX, entryY, entryZ = player()

	-- The map streams in. Wait for NPCs to appear, then give Hanto a short
	-- grace period after the scouts are loaded before concluding he is absent.
	local hanto = findHanto(80)
	local npcSeenAt = nil
	if not hanto then
		say('looking for Hanto')
		local endAt = API.SystemTime() + 8000
		while API.Read_LoopyLoop() and API.SystemTime() < endAt and not hanto do
			if not npcSeenAt and #scanNpcs() > 0 then
				npcSeenAt = API.SystemTime()
			end
			hanto = findHanto(80)
			if npcSeenAt and not hanto and (API.SystemTime() - npcSeenAt) > 2500 then
				break
			end
			sleep(500, 100, 200)
		end
	end

	-- Map still empty: step forward once and look again.
	if not hanto and not npcSeenAt then
		say('checking the Hanto area')
		walkTo(entryX, entryY - 6, entryZ, 3, 8000)
		local endAt = API.SystemTime() + 5000
		while API.Read_LoopyLoop() and API.SystemTime() < endAt and not hanto do
			sleep(500, 100, 200)
			hanto = findHanto(80)
		end
	end

	UI.hanto = hanto ~= nil
	UI.hantoHp = hanto and (tonumber(hanto.Life) or 0) or 0
	updateUI(true)

	if not hanto then
		if exitInstance() then return 'exit' end
		return 'failed'
	end

	local foughtHanto = false
	local lastX, lastY = player()
	local lastMoveAt = API.SystemTime()
	while API.Read_LoopyLoop() do
		drinkRenewal()
		drinkPrayer()
		eatFood()
		updateUI()

		hanto = findHanto(80)
		if not hanto then
			UI.hanto = false
			UI.hantoHp = 0
			if foughtHanto then
				say('Hanto killed')
				updateUI(true)
				return 'killed'
			end
			if exitInstance() then return 'exit' end
			return 'failed'
		end
		UI.hantoHp = tonumber(hanto.Life) or 0

		local px, py = player()
		if px ~= lastX or py ~= lastY then
			lastX, lastY, lastMoveAt = px, py, API.SystemTime()
		end
		local hx, hy = tileOf(hanto)
		local hd = tileDistance(px, py, hx, hy)

		local blocker, blockerD = findTrashNearHanto(hanto, TRASH_NEAR_HANTO)
		local moving = isMoving()
		local fighting = inCombat()

		-- Track the current target's life so "in combat" does not become a
		-- permanent wait if Revolution/auto-retaliate stops attacking.
		local target = blocker or hanto
		local targetKey = tonumber(target.Unique_Id) or tonumber(target.Id)
		local targetHp = tonumber(target.Life) or 0
		if targetKey ~= S.lastTargetKey or targetHp ~= S.lastTargetHp then
			S.lastTargetKey, S.lastTargetHp = targetKey, targetHp
			S.lastHpChangeAt = API.SystemTime()
		end

		if moving then
			-- do not stack another walk/attack on top of the current movement
			if blocker then
				setPrayer('Protect from Ranged', true)
			else
				setPrayer('Protect from Magic', true)
			end
			UI.target = 'moving'
			say('moving')
			sleep(450, 100, 150)
		elseif fighting then
			-- already in combat: let auto-retaliate / Revolution finish the job
			local movedAway = false
			if blocker then
				setPrayer('Protect from Ranged', true)
				UI.target = 'in combat - Crassians'
				say('in combat - Crassians')
			else
				setPrayer('Protect from Magic', true)
				foughtHanto = true
				UI.target = 'in combat - Hanto'
				say('in combat - Hanto')
				if hd <= 4.5 then
					movedAway = moveToHantoRange(hanto, 8)
				end
			end
			-- if the target's life has not moved for 4 s, give combat a nudge
			if not movedAway and (API.SystemTime() - (S.lastHpChangeAt or 0)) > 4000 then
				attackNpc(target)
				S.lastHpChangeAt = API.SystemTime()
			end
			sleep(600, 100, 200)
		elseif blocker then
			UI.target = 'clearing Crassians'
			say('clearing Crassians near Hanto (' .. tostring(blockerD) .. ')')
			setPrayer('Protect from Ranged', true)
			local bx, by = tileOf(blocker)
			if not attackNpc(blocker) then
				API.DoAction_Tile(FFPOINT.new(bx, by, entryZ))
			elseif blockerD and blockerD > 10 and (API.SystemTime() - lastMoveAt) > 2500 then
				-- the click is not moving us (target behind a barrier): walk at it
				API.DoAction_Tile(FFPOINT.new(bx, by, entryZ))
				lastMoveAt = API.SystemTime()
			end
			sleep(900, 200, 300)
		else
			UI.target = 'fighting Hanto'
			say('fighting Hanto')
			setPrayer('Protect from Magic', true)
			foughtHanto = true

			-- Keep more than 4 tiles away: Hanto's black-magic blast is 5x5.
			if hd <= 4.5 then
				-- too close: step out first, do not trade hits inside the blast
				moveToHantoRange(hanto, 8)
				sleep(500, 100, 200)
			elseif hd > 15 then
				-- out of comfortable range: close to ~7 tiles, then click
				if not moveToHantoRange(hanto, 7) then
					attackNpc(hanto)
					sleep(800, 200, 300)
				end
			else
				attackNpc(hanto)
				sleep(800, 200, 300)
			end
		end
	end
	return 'failed'
end

-- ---------------------------------------------------------------------------
-- main loop
-- ---------------------------------------------------------------------------
ClearRender()
DrawImGui(function()
	ImGui.SetNextWindowPos(20, 120, ImGuiCond.FirstUseEver)
	ImGui.SetNextWindowSize(380, 0, ImGuiCond.FirstUseEver)

	if ImGui.Begin("ED3 Hanto##ed3_hanto_debug") then
		ImGui.TextColored(0.40, 0.80, 1.00, 1.00, "ED3 Hanto")
		ImGui.Separator()

		ImGui.Text("Status:")
		ImGui.SameLine()
		ImGui.TextColored(1.00, 0.85, 0.20, 1.00, tostring(UI.status))

		ImGui.Text(string.format("Kills: %d    Exits: %d    Runs: %d",
			UI.kills or 0, UI.exits or 0, UI.runs or 0))
		ImGui.Text(string.format("HP: %d%%    Prayer: %d%%",
			math.floor(UI.hp or 0), math.floor(UI.prayer or 0)))
		ImGui.Text(string.format("Food: %d    Renewals: %d",
			UI.food or 0, UI.renewal or 0))
		ImGui.Text(string.format("Camera tilt: %d", math.floor(UI.tilt or 0)))
		ImGui.Text(string.format("Location: %s    Hanto: %s",
			UI.inInstance and "Instance" or "Overworld",
			UI.hanto and "present" or "absent"))
		if UI.hanto then
			ImGui.Text(string.format("Hanto HP: %d", UI.hantoHp or 0))
		end

		if UI.protMagic then
			ImGui.TextColored(0.45, 0.75, 1.00, 1.00, "Protect from Magic: ON")
		end
		if UI.protRanged then
			ImGui.TextColored(0.45, 1.00, 0.45, 1.00, "Protect from Ranged: ON")
		end
		if UI.target and UI.target ~= "" then
			ImGui.Text("Action: " .. UI.target)
		end
		if UI.lastError and UI.lastError ~= "" then
			ImGui.TextColored(1.00, 0.40, 0.40, 1.00, "Last error: " .. UI.lastError)
		end
	end
	ImGui.End()
end)

log('loaded - banking, sailing, killing Hanto, repeating')
say('starting')
updateUI(true)

-- Keeps entering/leaving until Hanto is actually killed. A missing Hanto uses
-- the nearby Exit and re-enters the ship without loading the bank preset.
local function runUntilKilled()
	while API.Read_LoopyLoop() do
		if not inInstance() then
			if not sailToShadowReef() then return false end
		end
		local result = clearToHanto()
		turnOffPrayers()
		if result == 'killed' then
			S.kills = S.kills + 1
			updateUI(true)
			return true
		end
		if result ~= 'exit' then
			return false
		end
		-- clearToHanto used the Exit; we are back at the ship. Go straight
		-- back in, without banking.
		sleep(500, 100, 200)
	end
	return false
end

while API.Read_LoopyLoop() do
	updateUI()
	local ok, err = pcall(function()
		if inInstance() then
			-- Already inside the dungeon (script start/restart): continue this
			-- run instead of teleporting out and re-banking.
			runUntilKilled()
			if API.Read_LoopyLoop() then ringTeleport() end
		else
			if not inDaemonheim() then
				ringTeleport()
			end
			if inDaemonheim() then
				loadPreset()
				runUntilKilled()
				if API.Read_LoopyLoop() then ringTeleport() end
			end
		end
	end)
	if not ok then
		S.lastError = tostring(err)
		log('error: ' .. tostring(err))
		updateUI(true)
		sleep(2000, 300, 300)
	end
	sleep(800, 150, 250)
end

turnOffPrayers()
ClearRender()
log('stopped')
