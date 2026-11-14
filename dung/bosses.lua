-- bosses.lua - the Daemonheim boss fights.
--
-- Split out of Dung.lua, which keeps the main loop, the click/action helpers, the
-- map and route search (pathing.lua) and the puzzle rooms (puzzles.lua). Boss npcs
-- are matched by NAME (ids change between floors), so the name table, the per-boss
-- strategy, the bind-swap pre-fight hooks and the floor ladder that ends the floor
-- once the boss is down all live here.
--
-- Dung.lua installs it once, after the helpers it hands over are in scope:
--
--   local bindBosses = require("bosses")(D, API, S, H, X)
--   ...
--   bindBosses()         -- second pass, after every module is installed
--
--   D    the shared script table: all state, and every D.* entry point
--   API  the engine wrapper
--   S    dung_state, the per-floor state that outlives a rescan
--   H    helpers that stay in Dung.lua (log/say/ptile/pkey, click + action helpers)
--   X    the table the three sub-modules share their functions through
--
-- The body below is the original code, moved byte for byte. Do not reformat it: the
-- line comments describe what was observed live, not how this file is laid out.

return function(D, API, S, H, X)
	------------------------------------------------------------------
	-- helpers that stay in Dung.lua
	------------------------------------------------------------------
	local attack, chat, drainChat, engineInCombat, inCombat, log, pkey,
		ptile, say, settle =
		H.attack, H.chat, H.drainChat, H.engineInCombat, H.inCombat, H.log, H.pkey,
		H.ptile, H.say, H.settle

	------------------------------------------------------------------
	-- nothing is imported from the other two modules: this one only uses
	-- what Dung.lua hands it in H. bind() stays so Dung.lua can install all
	-- three files the same way.
	------------------------------------------------------------------
	local function bind() end

--------------------------------------------------------------------
-- bosses: matched by NAME, because npc ids change between floors
--------------------------------------------------------------------

D.BOSSES = {
	['gluttonous behemoth']          = 'gluttonous',
	['divine skinweaver']            = 'skeletalhorde',   -- the npc the Skeletal Horde fight is keyed on
	['skeletal horde']               = 'skeletalhorde',
	['runebound behemoth']           = 'generic',
	['astea frostweb']               = 'astea',     -- bind 2 first, then a spam fight
	['icy bones']                    = 'generic',
	["to'kash the bloodchiller"]     = 'generic',
	['luminescent icefiend']         = 'generic',
	['plane-freezer lakhrahnaz']     = 'planefreezer',
	['bulwark beast']                = 'generic',
	['unholy cursebearer']           = 'generic',
	["har'lakk the riftsplitter"]    = 'riftsplitter',
	["bal'lak the pummeller"]        = 'generic',
	['gravecreeper']                 = 'generic',
	['flesh-spoiler haasghenahk']    = 'generic',
	['shadow-forger ihlakhizan']     = 'shadowforger', -- hide behind a pillar when it glows
	['night-gazer khighorahk']       = 'nightgazer',   -- light the pillars, then step off the shadow
	['world-gorger shukarhazh']      = 'generic',
	['skeletal trio']                = 'generic',
	['sagittare']                    = 'generic',
	['dreadnaut']                    = 'generic',
	['stomp']                        = 'stomp',     -- lodestones, crystals and falling debris
	['lexicus runewright']           = 'generic',
	['warped gulega']                = 'generic',
	['blink']                        = 'generic',
	['rammernaut']                   = 'generic',
	['hobgoblin geomancer']          = 'generic',
}

-- Boss names are matched against this table, and the client's spelling is not
-- always the one written here: "To'Kash the Bloodchiller" comes back with either a
-- straight or a curly apostrophe depending on the cache, and a mismatch means the
-- npc is treated as an ordinary monster - the boss room then sits "waiting for the
-- boss" forever. Normalise before every lookup: lower case, curly quotes folded to
-- ', runs of whitespace collapsed.
function D.bossKey(name)
	local s = string.lower(tostring(name or ''))
	s = s:gsub('\226\128\153', "'"):gsub('\226\128\152', "'")
	s = s:gsub('%s+', ' ')
	return (s:gsub('^%s*(.-)%s*$', '%1'))
end

local function findBoss(world, px, py, maxDist)
	local best, bestName, bestD = nil, nil, math.huge
	local lim = (maxDist or 24) ^ 2
	for _, n in ipairs(D.npcScan()) do
		local name = D.bossKey(n.Name)
		if D.BOSSES[name] and (n.Life or 0) > 0 then
			local t = n.Tile_XYZ
			local d = (math.floor(t.x) - px) ^ 2 + (math.floor(t.y) - py) ^ 2
			if d <= lim and d < bestD then best, bestName, bestD = n, name, d end
		end
	end
	return best, bestName
end

-- Boss clicking, and nothing else.
--
-- The generic attack() path is wrong for a Daemonheim boss: Astea Frostweb roots
-- the player in place, so chasing, "wait because we are already in combat",
-- distance/step limits and reachability gating all describe a fight that cannot
-- happen. All that matters is that the attack click keeps landing: the boss
-- swaps its npc id mid-fight (9986 -> 9987 in the live test), so the id is read
-- fresh from the scan every pass and the click is re-sent.
--
-- The gap between clicks is deliberately uneven (0.8 s - 5 s): a fixed ~1 s
-- cadence for a whole fight is a machine signature, and the click does not need to
-- land that often anyway.
local function bossAttack(boss)
	if not boss then return false end
	local bt = boss.Tile_XYZ
	local bx, by = math.floor(bt.x), math.floor(bt.y)
	-- Inside the boss room there is nothing to compute: the click is what matters and
	-- the client walks the player into range by itself. The two StarPath searches below
	-- are a full path calculation each and they ran on every single attack pass
	-- ("MEX: walk-tile cache rescanned" between every swing) - in the room the answer is
	-- already known.
	if not D.bossNearHere then
		-- Same rule as every other npc, with the boss's own SIZE taken into account: the
		-- big ones are size 4 and stand on blocked tiles, so "can I walk onto its tile"
		-- is false even with the boss right in front of us.
		if not (D.tileReachable(bx, by, bt.z, 0) or D.tileReachable(bx, by, bt.z, 2)) then
			S.bossUnreachLog = S.bossUnreachLog or 0
			if (API.SystemTime() - S.bossUnreachLog) > 15000 then
				S.bossUnreachLog = API.SystemTime()
				log(string.format('boss %s at %d,%d is not pathable from here - not clicking it',
					tostring(boss.Name), bx, by))
			end
			API.RandomSleep2(400, 150, 250)
			return false
		end
	end
	local uid = boss.Unique_Id or 0
	if uid ~= S.bossUidSeen then
		S.bossUidSeen = uid
		log(string.format('boss %s id %d uid %d hp %d - attacking',
			tostring(boss.Name), boss.Id or 0, uid, boss.Life or 0))
	end
	API.DoAction_NPC(D.ACT_ATTACK, D.ROUTE_ATK, { boss.Id }, 50)
	-- 400 ms base + up to 900 ms + an occasional 9 s beat, and the loop's own tail sleep
	-- (~0.4-0.8 s) lands on top: 0.8 s at the fastest, ~11 s at the slowest.
	API.RandomSleep2(400, 6200, 20000)
	return true
end

-- Gluttonous behemoth heals off the carcasses, so the fight is decided by
-- position: stand on the walkable tile between the carcass and the boss. The
-- carcass has no action at all, so its name is the only handle on it.
local function bossGluttonous(boss, world, px, py)
	local t = boss.Tile_XYZ
	local bx, by = math.floor(t.x), math.floor(t.y)

	local carcass, best = nil, math.huge
	for _, o in ipairs(world.objs or {}) do
		if string.find(string.lower(o.Name or ''), D.CARCASS_NAME, 1, true) then
			local ct = o.Tile_XYZ
			local cx, cy = math.floor(ct.x), math.floor(ct.y)
			local d = (cx - bx) ^ 2 + (cy - by) ^ 2
			if d < best then best, carcass = d, { x = cx, y = cy } end
		end
	end
	if not carcass then return false end

	local sx = (bx > carcass.x and 1) or (bx < carcass.x and -1) or 0
	local sy = (by > carcass.y and 1) or (by < carcass.y and -1) or 0
	if sx == 0 and sy == 0 then return false end

	-- step from the carcass toward the boss and take the first walkable tile: the
	-- carcass is solid and usually covers two tiles, so it cannot host the spot
	local spot = nil
	for step = 1, 8 do
		local x, y = carcass.x + sx * step, carcass.y + sy * step
		if x == bx and y == by then break end
		if world.walk[pkey(x, y)] then spot = { x = x, y = y } break end
	end
	if not spot then return false end

	-- In position means standing on the spot OR right beside it on the same line -
	-- the carcass is blocked by being next to it. Requiring the exact tile made the
	-- bot click the same "move to pos" every pass whenever the spot itself was
	-- occupied or unreachable, and the fight never started.
	local dist = math.max(math.abs(px - spot.x), math.abs(py - spot.y))
	if dist <= 1 then
		D.gluTries, D.gluWalk = 0, nil
		return false                                   -- already blocking: fight
	end

	-- One walk at a time: a clicked tile takes a few seconds to walk, and stacking
	-- another click on top of it just re-sends the same move.
	local now = API.SystemTime()
	local last = D.gluWalk
	if last and last.x == spot.x and last.y == spot.y and (now - last.t) < 3000 then
		API.RandomSleep2(250, 100, 150)
		return true
	end

	D.gluTries = (D.gluTries or 0) + 1
	if D.gluTries > 4 then
		log(string.format('gluttonous: cannot stand between carcass and boss (%d,%d) from %d,%d - fighting from here',
			spot.x, spot.y, px, py))
		return false                                   -- give up positioning, attack
	end
	D.gluWalk = { x = spot.x, y = spot.y, t = now }
	say(string.format('blocking the carcass at %d,%d', spot.x, spot.y))
	log(string.format('gluttonous: walking %d,%d -> %d,%d (try %d)', px, py, spot.x, spot.y, D.gluTries))
	D.walkTile(spot.x, spot.y, t.z)
	API.RandomSleep2(600, 250, 400)
	settle()
	return true
end

-- The end ladder closes the floor. Matched by its own action and by name, never
-- by id, and by distance rather than room membership so it is still found when
-- its tile sits just outside the segmented room.
local function findLadder(here)
	local px, py = ptile()
	local inRoom, inD = nil, math.huge
	local near, nearD = nil, math.huge
	for _, o in ipairs(D.objScan()) do
		if o.Type ~= 3 then
			local act = o.Action or ''
			local nm = string.lower(o.Name or '')
			local isLadder = act == 'End dungeon'
				or (act ~= '' and string.find(nm, 'ladder', 1, true))
			if isLadder and o.Bool1 ~= 1 then
				local t = o.Tile_XYZ
				local x, y = math.floor(t.x), math.floor(t.y)
				local d = (x - px) ^ 2 + (y - py) ^ 2
				if not S.ladderBad[x .. ',' .. y] then
					if d < nearD then nearD, near = d, o end
					if here and here.set[pkey(x, y)] and d < inD then inD, inRoom = d, o end
				end
			end
		end
	end
	if inRoom and near and nearD < inD then return near end
	if inRoom then return inRoom end
	-- No 20-tile cap: the ladder is the floor's exit and may well be in another
	-- room, in which case the caller routes there before using it.
	if near then return near end
	return nil
end

-- Boss-room markers, matched by NAME only: the ids change between floors, the
-- names do not. The boss door is a type 12 decor at the boss room entrance, and
-- the behemoth's carcass sits inside its room.
D.BOSS_DOOR_NAME = 'boss door'
D.CARCASS_NAME   = 'carcass'
-- Tiles: within this of the boss npc counts as standing in its room. The room-map
-- bounds are not usable for that - a merged room blob covers half the floor, which
-- is how the boss got attacked with 11 doorways still unopened. 12, not 8: the big
-- bosses are size-4 and report the corner tile of their model, so Stomp standing 9
-- tiles away was already in the room with us.
D.BOSS_ENGAGE_DIST = 12

--------------------------------------------------------------------
-- Skeletal Horde (SkeletalHorde.java)
--------------------------------------------------------------------
-- The "Divine skinweaver" is NOT the enemy: it heals us, it is what the room is keyed on,
-- and attacking it is the one thing the generic boss path would get wrong. The java logic
-- is, in order: block a tunnel when the skinweaver speaks -> under 40% health stand next
-- to the skinweaver to be healed -> otherwise attack anything that is not the skinweaver ->
-- with nothing left to hit, talk to it (its "little danger in ..." line is the win).
-- Two things the java leaves to the player are done here as well, and they run first because
-- they are what keeps the character alive: PROTECT FROM MAGIC for the whole fight, and a bite
-- of food below 55% health.
D.HORDE_TUNNELS = { [49286] = true, [49287] = true, [49288] = true }
D.HORDE_TUNNEL_RANGE = 12
D.TUNNEL_ACTION = 'Block'
-- A BLOCKED TUNNEL IS LEFT ALONE FOR THIS LONG. The skinweaver's call-out is not one line:
-- it repeats for the whole wave, and every repeat used to be a reason to look at the tunnels
-- again - the click lands, the call is cleared, the next line re-arms it, and the player is
-- pulled off the skeletons that are actually hitting him. Five seconds is longer than a wave
-- takes to arrive, so a tunnel is blocked once and the fight gets on with it.
D.HORDE_BLOCK_GAP_MS = 5000
-- PROTECT FROM MAGIC for the whole of the fight - the skeleton waves hit with magic and the
-- prayer is what turns those hits into nothing. It is listed in D.BOSS_PRAYER (Dung.lua)
-- under both names this room is keyed on, so the walk into the arena presses it; the call in
-- the strategy below is the same press for the passes where the boss-room test missed the
-- npc. Varbit 16745 reports the state, so a press that did not take is retried instead of
-- being taken on trust.
D.HORDE_PRAYER = 'Protect from Magic'
D.HORDE_HEAL_AT = 40           -- health percent: stand beside the skinweaver (needToHeal)
D.HORDE_EAT_AT = 55            -- health percent: eat first, the walk to the weaver takes ticks
D.HORDE_HEAL_GAP_MS = 1500     -- between two walks onto the healing tile
-- The pack is matched by the Daemonheim food NAMES, exactly like Stomp's eat step: HasFood
-- only says that A food exists, so eating whatever slot happens to be first is how the
-- burnt fish gets clicked.
D.HORDE_FOOD_WORDS = { 'crab', 'eel', 'flatfish', 'snipper', 'bouldabass', 'moray', 'fish' }

-- EAT, copied from bossStomp's step 2. D.eatFood() at the front of every pass does the same
-- bite with the "Eat Food" action-bar ability; this one is the item's own option, which still
-- works when that ability is not on the bar - and the horde room is where the player bleeds
-- out while the strategy owns the pass.
local function hordeEat(hp, now)
	if not hp or hp > D.HORDE_EAT_AT then return false end
	if (now - (D.hordeEatAt or 0)) <= 1800 then return false end
	local hasFood = false
	pcall(function() hasFood = Inventory:HasFood() and true or false end)
	if not hasFood then return false end
	local okIt, items = pcall(function() return Inventory:GetItems() end)
	if not (okIt and items) then return false end
	for _, it in ipairs(items) do
		local nm = string.lower(tostring(it.name or ''))
		local food = false
		for _, w in ipairs(D.HORDE_FOOD_WORDS) do
			if string.find(nm, w, 1, true) then food = true break end
		end
		if food then
			D.hordeEatAt = now
			say('eating')
			log(string.format('skeletal horde: eating %s at %d%% health', tostring(it.name), hp))
			pcall(function() Inventory:Eat(it.id) end)
			API.RandomSleep2(600, 250, 350)
			return true
		end
	end
	return false
end

-- IS THE PLAYER IN THE SKINWEAVER'S OWN ROOM? The arena is one layout cell and the npc
-- stands inside it, so the lattice answers this exactly - while the 12-tile radius
-- D.bossStrategyStep dispatches the other bosses with also reaches the arena through a shut
-- boss door and from the corridor outside it. Running the fight from there blocks tunnels
-- through the wall, walks at the arena wall instead of into it, spends prayer points on a
-- fight that has not started and - because a dispatched boss counts as a HOT arena
-- (D.bossArenaHot) - leaves the doorway task standing down while the player waits outside a
-- door the bot will not open.
--
-- Same cell, not a distance: on every FLOOR tile this gives the same answer as the
-- distance-to-centre test D.bossPrayerStep uses (< D.BOSS_PRAYER_ROOM_R), because a room's
-- floor is 1..7 from its centre in every room. The two only part company on the near wall
-- line (offset -8, distance 8): the prayer gate refuses it, this one takes it, and that is
-- wanted here - a player standing in the arena's own doorway has the fight running.
local function hordeInArena(px, py, wx, wy)
	if not (px and py and wx and wy) then return false end
	if D.roomCellAt then
		local _, _, bi, bj = D.roomCellAt(math.floor(wx), math.floor(wy))
		local _, _, pi, pj = D.roomCellAt(px, py)
		if bi and pi then return bi == pi and bj == pj end
	end
	-- no lattice to ask: the room the player stands in is the only other answer there is
	return D.bossHere ~= nil and D.tileInHere(D.bossHere, wx, wy, 0) == true
end

local function bossSkeletalHorde(boss, world, px, py)
	local now = API.SystemTime()
	-- life points once per pass: the eat step and the healing step both ask for it
	local hp = nil
	local okHp, h = pcall(function() return API.GetHPrecent() end)
	if okHp and tonumber(h) then hp = tonumber(h) end

	local weaver = nil
	for _, n in ipairs(D.npcScan()) do
		if string.find(string.lower(n.Name or ''), 'skinweaver', 1, true) then weaver = n break end
	end
	local wt = (weaver and weaver.Tile_XYZ) or boss.Tile_XYZ
	local wx, wy = math.floor(wt.x), math.floor(wt.y)

	-- IN THE ARENA, NOT AT ITS DOOR: nothing below may run from the corridor.
	if not hordeInArena(px, py, wx, wy) then return false end

	-- 0. THE PRAYER. D.bossPrayerStep presses it on the walk in, but it answers false while
	-- the skinweaver's tile reads outside our own room box - and by then the fight is running.
	if D.ensurePrayerAbility then
		local roomKey = 'horde'
		if D.roomCellAt then
			local _, _, pi, pj = D.roomCellAt(px, py)
			if pi then roomKey = pi .. ':' .. pj end
		end
		D.ensurePrayerAbility(D.HORDE_PRAYER, roomKey)
	end

	-- 1. it only blocks a tunnel when the skinweaver has just called it out (the java boss
	-- does the same: its block step is gated on the npc having a message). 12 s window,
	-- because the call comes once per wave and the click itself takes a moment.
	-- THE WHOLE BRANCH SLEEPS FOR D.HORDE_BLOCK_GAP_MS AFTER A CLICK, scan included: a new
	-- call-out inside that window is not a new tunnel, and looking at the props again is how
	-- the same wave produced Block clicks pass after pass.
	local cooled = (now - (D.hordeBlockAt or 0)) > D.HORDE_BLOCK_GAP_MS
	local said = cooled and chat.hordeAt and (now - chat.hordeAt) < 12000
	local tunnel, best = nil, D.HORDE_TUNNEL_RANGE * D.HORDE_TUNNEL_RANGE
	if said then
		for _, o in ipairs(D.objScan()) do
			-- only a tunnel that still offers Block: once it is blocked the option goes away,
			-- and clicking it again is the "going crazy on tunnels" that filled the log
			if D.HORDE_TUNNELS[o.Id] and o.Bool1 ~= 1
				and string.find(string.lower(tostring(o.Action or '')), 'block', 1, true) then
				local ot = o.Tile_XYZ
				local d = (math.floor(ot.x) - px) ^ 2 + (math.floor(ot.y) - py) ^ 2
				if d <= best then best, tunnel = d, o end
			end
		end
	end
	if tunnel then
		D.hordeBlockAt = now
		-- the call-out is used up by the click, exactly like the java boss clearing its
		-- blocktunnel flag: without this the same message drove a Block click every pass
		chat.hordeAt = nil
		say('blocking the skeletal tunnel')
		log(string.format('skeletal horde: blocking tunnel %d at %d,%d (player %d,%d)',
			tunnel.Id, math.floor(tunnel.Tile_XYZ.x), math.floor(tunnel.Tile_XYZ.y), px, py))
		D.clickObject(D.TUNNEL_ACTION, tunnel)
		API.RandomSleep2(900, 300, 400)
		settle()
		return true
	end


	-- 2. EAT. Below D.HORDE_EAT_AT the pack is opened before anything else: the bite is one
	-- click, the trip to the skinweaver is a walk, and the next skeleton lands in between.
	if hordeEat(hp, now) then return true end

	-- 3. UNDER 40% HEALTH, STAND BESIDE THE SKINWEAVER - it heals whoever is next to it
	-- (the java's needToHeal() branch). A tile NEXT to it, never its own: the npc stands on
	-- a blocked tile and "walk onto it" is refused, which is what the walk spot search is for.
	if hp and hp <= D.HORDE_HEAL_AT and weaver then
		local beside = math.max(math.abs(px - wx), math.abs(py - wy)) <= 1
		if not beside and (now - (D.hordeHealAt or 0)) > D.HORDE_HEAL_GAP_MS then
			local sx, sy = D.walkSpotNear(world, wx, wy)
			if sx and sy and not (sx == px and sy == py) then
				D.hordeHealAt = now
				say('standing by the skinweaver to be healed')
				log(string.format('skeletal horde: %d%% health - walking to %d,%d beside the skinweaver at %d,%d',
					math.floor(hp), sx, sy, wx, wy))
				D.walkTile(sx, sy, 0)
				API.RandomSleep2(600, 250, 400)
				settle()
				return true
			end
		end
	end

	-- 4. hit whatever is in the room that is not the skinweaver
	local target, bestD = nil, math.huge
	for _, n in ipairs(D.npcScan()) do
		local nm = string.lower(n.Name or '')
		if not string.find(nm, 'skinweaver', 1, true) and (n.Life or 0) > 0
			and (n.Cmb_lv or 0) > 0 then
			local nt = n.Tile_XYZ
			local d = (math.floor(nt.x) - px) ^ 2 + (math.floor(nt.y) - py) ^ 2
			-- the waves come out of the tunnels, so the whole room is in reach, not just the
			-- ten tiles around us: a skeleton walking in from the far tunnel is still a target
			if d < bestD and d <= D.HORDE_TUNNEL_RANGE * D.HORDE_TUNNEL_RANGE then
				bestD, target = d, n
			end
		end
	end
	if target then
		D.hordeTalkAt = nil
		say(string.format('attacking %s', tostring(target.Name)))
		API.DoAction_NPC(D.ACT_ATTACK, D.ROUTE_ATK, { target.Id }, 50)
		API.RandomSleep2(400, 900, 9000)
		return true
	end

	-- 5. nothing left to fight: talk to the skinweaver - its line is what ends the fight
	if weaver and (now - (D.hordeTalkAt or 0)) > 6000 then
		D.hordeTalkAt = now
		say('talking to the divine skinweaver')
		log(string.format('skeletal horde: no skeletons left - talking to the skinweaver at %d,%d', wx, wy))
		API.DoAction_NPC(D.ACT_TALK, D.ROUTE_TALK, { weaver.Id }, 50)
		API.RandomSleep2(900, 300, 400)
		settle()
		return true
	end
	-- NOTHING TO DO: hold the pass. Everything above is gated on standing in the arena, so
	-- reaching here means the fight is ours - and the skinweaver's own option is Talk, so the
	-- room-clear branch cannot swing at it (D.roomNpcs only takes an Action of "Attack").
	return true
end

--------------------------------------------------------------------
-- Stomp (Stomp.java - ArteDungeon and MegaDungeon - plus the RS3 fight as it actually is)
--------------------------------------------------------------------
-- The javas are 2011 scripts and their OBJECT ids are not all live ones: the RS3
-- lodestones were read in the client as 49270/49271 ("Inactive lodestone", no click
-- option of their own), and the crystals are still the Daemonheim power crystals
-- 15750/15751/15752 (cache-verified: "Blue/Green/Red power crystal") - the very ids
-- both javas call BlueKey/GreenKey/RedKey. MegaDungeon's Stomp.java is the one that
-- knows the colours come in PHASES, a pair of stones each (blue 49278/49279, green
-- 49276/49277, red 49274/49275), so the whole family is accepted below: the phase only
-- decides which pair the room spawns, never what the player does about it. Both javas
-- settle the order the same way as well - key in the pack, walk to the stone and click
-- it; no key, walk to the key and take it; neither, attack:
--     if (Inventory.getCount(Key) >= Stones.length) click stone  else loot key
-- LIVE, 2026-11-05 18:37, the fight that produced the rewrite: the room held two
-- "Blue lodestone" props at 49278/49279 whose only option was "Charge", plus nine
-- "Debris" props at 49268 offering "Mine", and EVERY type-3 record in the room had an
-- empty name - so the crystals are matched by ITEM ID and the rubble by id and name.
-- LIVE, 19:33, the same tiles with no phase running: "Inactive lodestone" at 49270/49271
-- and NO option at all. The two models share their tiles, and the INACTIVE one is never
-- a target - not clicked, and not walked to.
-- The fight itself, off the wiki:
--   * at 66%, 33% and 1% life points Stomp causes an earthquake that drops rocks and
--     two small crystals, and he turns invulnerable while the lodestones are
--     unprotected - so charging them is the only way to make him damageable again
--   * a crystal is placed by clicking the stone's OWN option ("Charge"); both must be
--     filled in time or he heals a third of his life and the stage repeats
--   * the fallen rocks block the way to the crystals and to the stones, and are cleared
--     with the pickaxe - only the ones that actually shut a goal off
--   * in the last stage a big rock lands on a tile: standing there is 25% of your
--     life, so a debris shadow under us is always stepped off
-- Order per pass: stay in the arena > dodge > eat > TAKE THE CRYSTALS > charge a stone >
-- clear the rock that blocks the goal > hold or pace while the phase runs. The crystals come
-- first of all the fight's own work: they are the only ammunition a phase has and they do not
-- lie on the floor long. A stone is never walked to: its own "Charge" option is the whole
-- interaction and the client carries the player in - and a stone that answers "You can't
-- reach that" is not walked to either, because the debris is across the way in and only
-- mining clears it. NOTHING THIS FIGHT CLICKS MAY BE OUTSIDE HIS ROOM (see D.stompArena): the
-- prop sweep is a world scan, so a lodestone or a crystal in the next room answers it exactly
-- like one under our feet, and the doorway task stands down while the player is in the arena
-- (D.bossArenaHot) so a pass with nothing left to do cannot walk out to the front of the
-- room. The boss is only ever attacked when no phase is live, no stone still wants a crystal,
-- AND the debris has all despawned - swinging at him before that means standing still under
-- falling rocks.
--
-- Every id of the lodestone family, not only the pair that was read live: the id only
-- says "this is a lodestone". stompWants is what decides whether it is a target, and it
-- goes by NAME - the inactive model is the one that says so.
D.STOMP_LODESTONE_IDS = {
	[49270] = true, [49271] = true,          -- read live: the inactive pair beside Stomp
	[49274] = true, [49275] = true,          -- MegaDungeon: red phase
	[49276] = true, [49277] = true,          -- MegaDungeon: green phase
	[49278] = true, [49279] = true,          -- MegaDungeon: blue phase
}
D.STOMP_LODESTONE_NAME = 'lodestone'
D.STOMP_CRYSTAL_IDS = { 15750, 15751, 15752 }
D.STOMP_CRYSTAL_SET = { [15750] = true, [15751] = true, [15752] = true }
-- A CRYSTAL ONLY FITS THE STONE OF ITS OWN COLOUR. Live, 19:51: the pack held a Blue power
-- crystal while the room's stones were Red, and every Charge answered "You do not have the
-- required item: Green power crystal" - nothing consumed, the phase lost. So "which
-- crystal" is part of the phase, not a detail: the stone's colour picks the id.
D.STOMP_CRYSTAL_FOR = {
	[49274] = 15752, [49275] = 15752,   -- Red lodestone   <- Red power crystal
	[49276] = 15751, [49277] = 15751,   -- Green lodestone <- Green power crystal
	[49278] = 15750, [49279] = 15750,   -- Blue lodestone  <- Blue power crystal
}
D.STOMP_CRYSTAL_BY_COLOUR = { red = 15752, green = 15751, blue = 15750 }
-- The stance line lands a beat before the room catches up (stones swap model, crystals
-- fall). Deciding "nothing wants a crystal" inside that beat is what handed the pass back
-- to the attack branch 0.7 s after the line at 19:51:14, and the router then walked out.
D.STOMP_WARMUP_MS = 4000
-- The shadow the falling rock casts. Matched by id, with the name as a fallback so a
-- variant model cannot make the whole dodge invisible.
D.STOMP_DEBRIS_SET = { [49269] = true }
D.STOMP_LODESTONE_RANGE = 14
D.STOMP_CRYSTAL_RANGE = 14
-- Fallen rubble. Live: id 49268, name "Debris", option "Mine".
D.STOMP_RUBBLE_IDS = { [49268] = true }
D.STOMP_RUBBLE_FAR = 20        -- a blocking rock this far from the player can still be walked to
D.STOMP_RUBBLE_GOAL_R = 4      -- and only rocks this close to a shut-off goal are "in the way"
-- AFTER THE LAST CRYSTAL the debris is still coming down, and attacking means standing
-- still under it (the falling rock is 25% of max life). The attack is held until the
-- floor is clear; meanwhile the player paces the open side of the room, away from the
-- boss, alternating sides so it reads as someone stepping around the rocks and not as a
-- statue - but never for ever: past this window he is attacked anyway.
D.STOMP_WAIT_MS = 25000
D.STOMP_PACE_DIST = 7          -- pace SIDEWAYS, on the ring this far out from Stomp
D.STOMP_PACE_MIN = 4           -- ...and never inside this radius, whatever the search finds
D.STOMP_PACE_STEP = 4          -- a step this wide is the one the scoring likes best
D.STOMP_PACE_GAP = 3           -- ...but far enough from where we stand to be a real step
D.STOMP_PACE_EVERY_MS = 2600   -- and stand at the pace tile this long before the next one
D.STOMP_EAT_AT = 45            -- health percent, the java's needToEat()
-- A crystal phase lives about 15 s and the boss repeats its line for the whole of it.
-- The stamp that starts this window is written by the chat pump (Dung.lua).
D.STOMP_PHASE_MS = 16000
D.STOMP_SETTLE_MS = 1500       -- an empty stone scan has to hold this long before it counts
D.STOMP_INVULN_MS = 2500       -- "invulnerable" from our own swing: do not swing again yet
D.STOMP_STONES = 2             -- stones per phase, and exactly two crystals per phase
                               -- (both charged = he is damageable again; a third is never taken)
D.STOMP_LATE_MS = 12000        -- past this much of the stance, one crystal is enough
-- THE PHASE IS ABOUT FIFTEEN SECONDS. Gathering two crystals and charging two stones has to
-- fit inside it, so the gaps are the shortest that still lets the client answer: the pack
-- count after a loot click, and the crystal count after a Charge click, are both read on the
-- next pass.
D.STOMP_TAKE_GAP_MS = 300      -- between two loot clicks
-- A take click from range is a WALK IN: the crystal only reaches the pack when the player
-- gets there. That long is how long the tile stays "clicked" - the pass waits it out instead
-- of clicking the same object again, and after it the tile is written off (it was not
-- reachable after all).
D.STOMP_TAKE_WAIT_MS = 12000
-- HOW LONG THE PASS MAY BE HELD WITH NOTHING TO COLLECT before the attack branch takes over.
-- The crystals fall with the earthquake, so after the debris has cleared an empty floor is a
-- lost phase, not a waiting one - and standing still on it is free damage.
D.STOMP_IDLE_GIVEUP_MS = 3000
D.STOMP_SWING_MS = 1200      -- between two attack clicks the strategy sends itself
D.STOMP_CHARGE_GAP_MS = 600    -- between the two charges (one game tick)
D.STOMP_FOOD_WORDS = { 'crab', 'eel', 'flatfish', 'snipper', 'bouldabass', 'moray', 'fish' }
D.STOMP_LOOT_SKIP_MS = 15000   -- a crystal that did not come is left alone this long
D.STOMP_STONE_SKIP_MS = 6000   -- a stone the client cannot reach is left alone this long
-- "YOU CAN'T REACH THAT" AT A LODESTONE MEANS THE DEBRIS IS ACROSS THE WAY IN, and there is
-- no path round it - only mining clears it. While that verdict holds the stone is not
-- clicked at all, so the pass drops to the mine step instead of re-sending a refused click;
-- the verdict is dropped with the rubble that caused it (or after this long).
D.STOMP_SHUT_MS = 8000
D.STOMP_CHARGE_ACT = 'Charge'  -- the stone's only option, whatever the scan reports
D.STOMP_TAKE_ACT = 'Take'      -- a ground item's own option: one click, no loot window

local function stompLodestone(o)
	if D.STOMP_LODESTONE_IDS[o.Id] then return true end
	return string.find(string.lower(D.objName(o)), D.STOMP_LODESTONE_NAME, 1, true) ~= nil
end

-- A STONE THAT WANTS A CRYSTAL is the ACTIVE model. Live: "Blue lodestone" (49278/49279,
-- option "Charge", 2nd pair of the family) appears during a crystal phase and the very
-- same tiles hold "Inactive lodestone" (49270/49271, NO option at all) when no phase is
-- running. The inactive model is never a target: not clicked, and not walked to either -
-- walking 10 tiles to a stone that cannot take a crystal is how the fight spent a whole
-- phase standing still at 19:27.
local function stompWants(o)
	if not stompLodestone(o) then return false end
	return string.find(string.lower(D.objName(o)), 'inactive', 1, true) == nil
end

-- Stomp's debris is dodged in any of the eight directions the player can step - the
-- java uses getSurroundingTiles(loc, true), which includes the diagonals, and standing
-- still because none of the four cardinals was free is how the rock lands for free.
D.STOMP_STEPS = { {0,1}, {0,-1}, {1,0}, {-1,0}, {1,1}, {1,-1}, {-1,1}, {-1,-1} }

local function stompDebris(o)
	-- Rubble that has already landed is "Debris" with a "Mine" option (live id 49268). It
	-- is rubble, not a shadow: stepping off it wastes the pass that should clear it.
	local act = string.lower(tostring(o.Action or ''))
	if act ~= '' and (string.find(act, 'mine', 1, true) or string.find(act, 'clear', 1, true)) then
		return false
	end
	if D.STOMP_DEBRIS_SET[o.Id] then return true end
	return string.find(string.lower(D.objName(o)), 'debris', 1, true) ~= nil
end

-- How many of one crystal the pack holds. Used to CONFIRM a charge: the stone consumes
-- the crystal, so the count dropping is the only proof the click landed.
local function stompHeldCount(id)
	local ok, n = pcall(function() return Inventory:InvItemcount(id) end)
	if ok and type(n) == 'number' then return n end
	return 0
end

-- A power crystal in the room. The client hands GROUND ITEMS back with no name at all
-- (live: every type-3 record in the boss room has name ""), so the item ids are what
-- identifies them; the name is only for a model whose id drifted, or for a crystal that
-- is a prop rather than a ground item.
local function stompCrystal(o)
	if D.STOMP_CRYSTAL_SET[o.Id] then return true end
	return string.find(string.lower(D.objName(o)), 'power crystal', 1, true) ~= nil
end

-- WHICH CRYSTAL THIS STONE WANTS: by id, and by the colour in its name for a model whose
-- id drifted. nil for the "Inactive lodestone" model, which wants nothing at all.
local function stompCrystalFor(o)
	if not o then return nil end
	local id = D.STOMP_CRYSTAL_FOR[o.Id]
	if id then return id end
	local colour = string.match(string.lower(D.objName(o)), '^(%a+) lodestone')
	return colour and D.STOMP_CRYSTAL_BY_COLOUR[colour] or nil
end

-- Fallen rubble ("Debris", live id 49268, option "Mine"). By id and name, NOT by the
-- action: a rock on the far side of the room reports no option at all - the same
-- distance effect the lodestone showed - so an action-filtered scan cannot see the very
-- rocks that shut a stone in.
local function stompRubble(o)
	if D.STOMP_RUBBLE_IDS[o.Id] then return true end
	return string.find(string.lower(D.objName(o)), 'debris', 1, true) ~= nil
end

-- THE ARENA. Every target this fight clicks or walks to has to be inside the boss's own
-- room: the prop sweep is a WORLD scan, so a lodestone, a power crystal and a rock in the
-- NEXT room answer it exactly like the ones under our feet - and a pass spent walking to one
-- of those is a pass spent leaving the arena (live: the bot walked out of Stomp's room while
-- the crystal phase was running).
--
-- HIS OWN ROOM comes from the floor segmentation (world.rooms), which is exact: a radius
-- around the boss would either cut the far corners off a 14x14 arena or leak into the room
-- next door, depending on where he happens to stand. The radius is only the fallback, for a
-- pass whose floor has not segmented yet.
D.STOMP_ARENA_R = 8

local function stompArenaBox(boss, world)
	local bt = boss and boss.Tile_XYZ
	local bx, by
	if bt and bt.x == bt.x and bt.y == bt.y then bx, by = math.floor(bt.x), math.floor(bt.y) end
	if bx and world and world.rooms then
		for i = 1, #world.rooms do
			local r = world.rooms[i]
			if r.set and r.set[pkey(bx, by)] then
				D.stompArenaRoom = r
				return { x0 = r.minx - 1, y0 = r.miny - 1, x1 = r.maxx + 1, y1 = r.maxy + 1 }
			end
		end
	end
	D.stompArenaRoom = nil
	if bx then
		return { x0 = bx - D.STOMP_ARENA_R, y0 = by - D.STOMP_ARENA_R,
			x1 = bx + D.STOMP_ARENA_R, y1 = by + D.STOMP_ARENA_R }
	end
	local h = D.bossHere
	if h and h.minx and h.maxx and h.miny and h.maxy and h.maxx > h.minx and h.maxy > h.miny then
		return { x0 = h.minx - 1, y0 = h.miny - 1, x1 = h.maxx + 1, y1 = h.maxy + 1 }
	end
	return nil
end

-- Is that tile inside the arena set for this pass? No arena box at all is never a reason to
-- refuse: refusing every target on a floor that has not streamed would stand the fight down.
local function stompInArena(x, y)
	local b = D.stompArena
	if not b then return true end
	if not (x and y) then return false end
	local fx, fy = math.floor(x), math.floor(y)
	return fx >= b.x0 and fx <= b.x1 and fy >= b.y0 and fy <= b.y1
end

-- HOW MUCH RUBBLE IS STILL ON THE FLOOR, and where. Returns the count plus TWO sets: the
-- debris tiles themselves (never walked onto, never stood beside as an approach) and the
-- ring around them (never used as a pacing tile, because that is where the next rock
-- lands).
local function stompRubbleField(objs)
	local n, ring, solid = 0, {}, {}
	for _, o in ipairs(objs) do
		local t = o.Tile_XYZ
		-- rubble in ANOTHER room is not this fight's floor: counting it would hold the
		-- attack for ever and put a no-stand ring over tiles this arena does not own
		if t and stompRubble(o) and stompInArena(t.x, t.y) then
			n = n + 1
			local rx, ry = math.floor(t.x), math.floor(t.y)
			solid[pkey(rx, ry)] = true
			for i = 1, #D.STOMP_STEPS do
				ring[pkey(rx + D.STOMP_STEPS[i][1], ry + D.STOMP_STEPS[i][2])] = true
			end
			ring[pkey(rx, ry)] = true
		end
	end
	return n, ring, solid
end

-- THE FLOOR'S BOUNDING BOX, read from the ROOM the pass is standing in, never from the
-- whole walk set: that set also carries the corridor and the next rooms, and reading it
-- as "the floor" is what sent a pace click 42 tiles away (live, 19:58:41: "pacing across
-- the floor to 9778,1079 (42 tiles off him)") with the map click that goes with it. The
-- walk-set bounds are only the fallback, and they are clamped to the ground under us.
local function stompRoomBox(world, px, py)
	-- THE ARENA THE FIGHT IS IN. It is measured from the BOSS, not from the player: a pass
	-- spent in the doorway (or in the corridor beyond it) has this room's blob, not the
	-- arena's, and pacing inside the corridor is walking out of the boss room with extra
	-- steps. D.stompArena is written once per pass, before any of this runs.
	if D.stompArena then return D.stompArena end
	local h = D.bossHere
	if h and h.minx and h.maxx and h.maxy and h.maxy > h.miny and h.maxx > h.minx then
		return { x0 = h.minx, y0 = h.miny, x1 = h.maxx, y1 = h.maxy }
	end
	-- NO ROOM, NO PACE. The walk-set fallback used to be clamped to nine tiles around the
	-- player, and when the fight pass ran while the player was out in the corridor that is
	-- exactly where it paced ("pacing across the floor to 9736,1051 (32 tiles off him)",
	-- live 20:25:10). Standing still is the right answer when the arena is unknown.
	return nil
end

-- WAIT FOR THE FLOOR TO CLEAR BY PACING IT. Standing still while the rocks come down is free
-- damage: the boss keeps swinging and the next shadow lands on the tile we are standing on.
-- The pace is SIDEWAYS on purpose - perpendicular to the line to the boss - which changes his
-- angle without walking into him or out of reach. Straight back and forth along that line
-- changes only the range, and in a small arena "the other side" is two tiles away, which read
-- as twitching (live 20:42:44-20:43:30: 9737,1077 -> 9739,1077 -> 9737,1077). So: one
-- sideways step every D.STOMP_PACE_EVERY_MS, alternating sides, never onto the rubble ring
-- (that is where the next rock lands), never inside D.STOMP_PACE_MIN of him and never out of
-- the arena. True = the pass was spent waiting (do not attack).
local function stompPaceTile(world, box, px, py, bx, by, ring)
	if not (world and world.walk) then return nil end
	-- the boss->player line, quantized to a direction: its two perpendiculars are the
	-- sideways directions, and the step is scored by how close to one of them it is
	local rx, ry = px - bx, py - by
	local len = math.max(math.abs(rx), math.abs(ry))
	if len < 1 then rx, ry, len = 0, -1, 1 end
	local perpX, perpY = -ry / len, rx / len
	local side = D.stompPaceSide or 1
	-- a shorter step is the fallback when the room is too tight for a real one
	for _, minGap in ipairs({ D.STOMP_PACE_GAP, 2 }) do
		local best, bestScore = nil, -math.huge
		for dx = -6, 6 do
			for dy = -6, 6 do
				local step = math.max(math.abs(dx), math.abs(dy))
				if step >= minGap then
					local sx, sy = px + dx, py + dy
					local k = pkey(sx, sy)
					local bd = math.max(math.abs(sx - bx), math.abs(sy - by))
					if world.walk[k] and not ring[k]
						and (not box or (sx >= box.x0 and sx <= box.x1 and sy >= box.y0 and sy <= box.y1))
						and bd >= D.STOMP_PACE_MIN and bd <= D.STOMP_PACE_DIST then
						-- SIDEWAYS FIRST, ON THE RING WE ARE ALREADY ON: how much of the step
						-- is perpendicular to the boss line, minus how much of it is towards
						-- or away from him, minus how far the step drifts off that ring. The
						-- ring term is what stops the search from walking the far wall.
						local sideways = (dx * perpX + dy * perpY) / step * side
						local radial = math.abs((dx * rx + dy * ry) / (step * len))
						local drift = math.abs(bd - len)
						local score = sideways * 1.4 - radial * 0.8 - drift * 0.6
							- math.abs(step - D.STOMP_PACE_STEP) * 0.3
						if score > bestScore then bestScore, best = score, { x = sx, y = sy } end
					end
				end
			end
		end
		if best then return best end
	end
	return nil
end

local function stompWaitDebris(boss, world, px, py, now, objs)
	local n, ring = stompRubbleField(objs)
	if n == 0 then
		if D.stompDebrisWaitAt then
			log(string.format('stomp: floor is clear after %.1f s - attacking',
				(now - D.stompDebrisWaitAt) / 1000))
		end
		D.stompDebrisWaitAt, D.stompPaceAt, D.stompPaceTo, D.stompPaceSide = nil, nil, nil, nil
		return false
	end
	if not D.stompDebrisWaitAt then
		D.stompDebrisWaitAt = now
		log(string.format('stomp: %d debris still down - holding the attack until the floor clears', n))
	end
	if (now - D.stompDebrisWaitAt) > D.STOMP_WAIT_MS then
		log(string.format('stomp: debris still down after %.0f s - attacking anyway',
			(now - D.stompDebrisWaitAt) / 1000))
		D.stompDebrisWaitAt, D.stompPaceAt, D.stompPaceTo, D.stompPaceSide = nil, nil, nil, nil
		return false
	end
	-- 1) CRYSTALS AND CHARGES FIRST, 2) THEN THE PACING. A pace step is a WALK CLICK, and a
	-- walk click cancels the walk an earlier click started - so pacing while a Charge is on
	-- its way in (D.stompPending) or while a crystal is being walked to (a live
	-- D.stompTakeClicked entry) throws that action away and the phase loses the crystal or
	-- the charge. Those two get to finish first; the floor is only paced when nothing else of
	-- ours is in flight.
	if D.stompPending then
		API.RandomSleep2(200, 80, 120)
		return true
	end
	if D.stompTakeClicked then
		for _, at in pairs(D.stompTakeClicked) do
			if (now - at) < D.STOMP_TAKE_WAIT_MS then
				API.RandomSleep2(200, 80, 120)
				return true
			end
		end
	end
	-- one step per pace window; the rest of the passes just wait for the walk to land
	if (now - (D.stompPaceAt or 0)) < D.STOMP_PACE_EVERY_MS then
		API.RandomSleep2(200, 80, 120)
		return true
	end
	local bt = boss and boss.Tile_XYZ
	local bx, by = px, py
	if bt and bt.x == bt.x and bt.y == bt.y then
		bx, by = math.floor(bt.x), math.floor(bt.y)
	end
	local box = stompRoomBox(world, px, py)
	local target = stompPaceTile(world, box, px, py, bx, by, ring)
	if target then
		D.stompPaceAt, D.stompPaceTo = now, target
		D.stompPaceSide = -(D.stompPaceSide or 1)
		say('pacing the floor while the debris falls')
		log(string.format('stomp: %d debris down - pacing %s to %d,%d (%d from him, %d from us)',
			n, ((D.stompPaceSide or 1) > 0) and 'right' or 'left', target.x, target.y,
			math.max(math.abs(target.x - bx), math.abs(target.y - by)),
			math.max(math.abs(target.x - px), math.abs(target.y - py))))
		D.walkTile(target.x, target.y, 0)
		API.RandomSleep2(300, 120, 180)
		return true
	end
	if (now - (D.stompNoneAt or 0)) > 4000 then
		D.stompNoneAt = now
		log(string.format('stomp: %d debris down - nowhere clear to pace, holding', n))
	end
	API.RandomSleep2(250, 100, 150)
	return true
end

-- A crystal that did not come stays out of the running for a while: see the count check
-- inside stompTakeCrystal.
local function stompLootSkipped(x, y, now)
	local t = D.stompLootSkip and D.stompLootSkip[pkey(x, y)]
	return t ~= nil and (now - t) < D.STOMP_LOOT_SKIP_MS
end

-- ONE WALK OVER THE ROOM'S FLOOR, WITH THE RUBBLE TAKEN OUT.
--
-- The pass walk set is built from the tile records, and a "Debris" prop standing on a tile
-- does not change the record underneath it - so the plain walk set calls a crystal ringed
-- by fallen rock "walkable" while the only way in is through the rock. The client answers
-- that click with "You can't reach that" and nothing else (a dungeon floor item opens no
-- loot window), which is a whole pass lost inside a fifteen-second phase. The same walk,
-- refusing every rubble tile, gives that answer before anything is clicked.
--
-- Cached per pass: the props - and so the rubble - are read once per pass, and the player
-- tile does not move inside one.
local stompDir4 = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }

local function stompBfs(objs, world, solid, px, py)
	if not (world and world.walk) then return nil end
	local c = D.stompBfsCache
	if c and c.objs == objs and c.x == px and c.y == py then return c.dist end
	local dist, q, head = {}, {}, 1
	local function free(k) return world.walk[k] and not (solid and solid[k]) end
	if free(pkey(px, py)) then
		dist[pkey(px, py)] = 0
		q[1] = { px, py }
	else
		-- standing on a prop or a pad: the walk starts from the floor around it
		for i = 1, #stompDir4 do
			local nx, ny = px + stompDir4[i][1], py + stompDir4[i][2]
			local k = pkey(nx, ny)
			if free(k) then
				dist[k] = 1
				q[#q + 1] = { nx, ny }
			end
		end
	end
	-- no floor to walk from at all: refuse to judge rather than call everything blocked
	if #q == 0 then return nil end
	while head <= #q do
		local cur = q[head]
		local d0 = dist[pkey(cur[1], cur[2])]
		head = head + 1
		for i = 1, #stompDir4 do
			local nx, ny = cur[1] + stompDir4[i][1], cur[2] + stompDir4[i][2]
			local k = pkey(nx, ny)
			if dist[k] == nil and free(k) then
				dist[k] = d0 + 1
				q[#q + 1] = { nx, ny }
			end
		end
	end
	D.stompBfsCache = { objs = objs, x = px, y = py, dist = dist }
	return dist
end

-- CAN THIS BE PICKED UP WITHOUT CROSSING THE RUBBLE? The eight tiles around it count: a
-- crystal sits on a tile the client calls blocked, so "stand on it" is never the answer.
--
-- With NO rubble in the room there is nothing to cross, so the answer is yes and the walk
-- set is never consulted: a floor blob that has not fully streamed would otherwise read as
-- "everything is walled off" and the crystals would sit on the floor untouched. No floor to
-- walk at all (nil) is never a reason to refuse a click either - and neither is standing
-- OUTSIDE the arena: a pass spent in the doorway carries the corridor's blob, and every
-- crystal would then read as cut off and the fight would stand still.
local function stompOpen(objs, world, solid, x, y, px, py, rubbleN)
	if (rubbleN or 0) == 0 then return true end
	if not stompInArena(px, py) then return true end
	local dist = stompBfs(objs, world, solid, px, py)
	if not dist then return true end
	for dx = -1, 1 do
		for dy = -1, 1 do
			if dist[pkey(x + dx, y + dy)] then return true end
		end
	end
	return false
end

-- A STONE THE CLIENT REFUSED IS NOT CLICKED AGAIN WHILE THE RUBBLE STANDS. "You can't reach
-- that" at a lodestone means the debris is across the way in, and there is no walking round
-- it - the rock has to be mined. Shutting the stone off for a few seconds is what lets the
-- pass fall through to the mine step instead of sending the same refused click again.
local function stompShutOff(k, now, rubbleN)
	local s = D.stompShut
	if not s or s.k ~= k then return false end
	if (now - s.at) >= D.STOMP_SHUT_MS or (rubbleN or 0) == 0 then
		D.stompShut = nil
		return false
	end
	return true
end

-- "YOU CAN'T REACH THAT" AT A STONE. The debris is across the way in, there is no path round
-- it, and only mining clears it - so the stone is shut off for a few seconds and the pass
-- falls through to the mine step. Three refusals with the rocks cleared in between mean
-- debris is NOT what is in the way, and the stone is left for D.STOMP_STONE_SKIP_MS so the
-- OTHER stone of the pair gets its crystal.
local function stompShutStone(lk, nx, ny, now)
	D.stompPending = nil
	D.stompShut = { k = lk, at = now }
	D.stompShutHits = D.stompShutHits or {}
	local hits = (D.stompShutHits[lk] or 0) + 1
	D.stompShutHits[lk] = hits
	if hits >= 3 then
		D.stompStoneSkip = D.stompStoneSkip or {}
		D.stompStoneSkip[lk] = now
		D.stompShut, D.stompShutHits[lk] = nil, nil
		log(string.format('stomp: the lodestone at %d,%d still cannot be reached after the rocks went - leaving it for %d s',
			nx, ny, math.floor(D.STOMP_STONE_SKIP_MS / 1000)))
	else
		log(string.format('stomp: "You can\'t reach that" at the lodestone %d,%d - debris is across the way in, mining it',
			nx, ny))
	end
end

-- GROUND ITEM, ONE DIRECT CLICK, NO INTERFACE. A dungeon floor item goes straight into the
-- pack and the loot window never opens for it, so the sweep D.takeFloorItem runs after its
-- own Take click has nothing to collect - it is a 1.4 s sleep and a second sweep in a phase
-- that only lasts about fifteen seconds.
local function stompTakeDirect(o)
	if not o then return false end
	local x, y = D.objTile(o)
	local ok, sent = pcall(API.DoAction_G_Items_Direct, D.ACT_TAKE, D.ROUTE_PICKUP, o)
	if ok and sent == true then
		log(string.format('Take %s at %s', tostring(D.objGet(o, 'Id')),
			(x and y) and string.format('%d,%d', math.floor(x), math.floor(y)) or '?'))
	end
	return ok and sent == true
end

-- TAKE THE OTHER CRYSTAL OF THE PAIR IN THE SAME PASS. A crystal phase only ever drops them
-- in twos and a phase needs two, so between the two takes there is a whole world sweep (the
-- pass's prop/tile scan) doing nothing. One tick apart is enough for the pack count to
-- answer, and the second is usually on the tile next to the first. Same one-click rule as
-- the first: the tile is remembered, so a slow pickup is waited out, never re-clicked.
local function stompTakeSecond(crystal, objs, world, solid, rubbleN, px, py, now)
	local best, bestD = nil, math.huge
	for _, o in ipairs(objs) do
		local t = o.Tile_XYZ
		if t and o ~= crystal and o.Id == crystal.Id and stompInArena(t.x, t.y) then
			local cx, cy = math.floor(t.x), math.floor(t.y)
			local k = pkey(cx, cy)
			local d = (cx - px) ^ 2 + (cy - py) ^ 2
			if d < bestD and not (D.stompTakeClicked and D.stompTakeClicked[k])
				and not stompLootSkipped(cx, cy, now)
				and stompOpen(objs, world, solid, cx, cy, px, py, rubbleN) then
				bestD, best = d, o
			end
		end
	end
	if not best then return false end
	local x, y = D.objTile(best)
	if not (x and y) then return false end
	local bk = pkey(math.floor(x), math.floor(y))
	D.stompTakeClicked = D.stompTakeClicked or {}
	D.stompTakeClicked[bk] = now
	local before = stompHeldCount(best.Id)
	if not stompTakeDirect(best) then
		-- never dispatched (the engine refused it): the tile is free to try again
		D.stompTakeClicked[bk] = nil
		return false
	end
	API.RandomSleep2(600, 120, 200)
	return stompHeldCount(best.Id) > before
end

-- 4. CRYSTALS BEFORE WALKING. A crystal on the floor IS the fight's ammunition and it is
-- what the next phase is charged with, so collecting it outranks everything that is not a
-- live lodestone.
--
-- ONE OBJECT IS ONE PICKUP. A take click from range is a WALK IN - the crystal comes off the
-- floor when the player gets there, which can be several seconds away - so a second click
-- inside that window only restarts the walk, and a pass that keeps re-clicking every crystal
-- it can see is what "clicking around like an insane person" was: the old code read the
-- missing pack count as "it did not come", walked a tile closer AND clicked the crystal
-- again, every pass.
--
-- THE CLICK IS THE OBJECT, NEVER A TILE: D.stompTakeDirect hands the engine the scanned
-- ground-item record (DoAction_G_Items_Direct with the pickup route), which is the same call
-- the key and food branches use. Nothing here walks to a crystal - the client does that
-- itself once the object is clicked. The crystal's TILE is only the memo of "this one has
-- been clicked" (a ground item is identified by where it lies), so the pass can wait it out
-- instead of clicking it a second time.
-- True = the pass was spent on the crystal (clicked, or waiting for a click to land).
local function stompTakeCrystal(crystal, bestD, heldTotal, world, px, py, now, objs, solid, rubbleN)
	if not crystal or heldTotal >= D.STOMP_STONES then return false end
	local ct = crystal.Tile_XYZ
	if not ct then return false end
	local cx, cy = math.floor(ct.x), math.floor(ct.y)
	local ck = pkey(cx, cy)
	-- BFS FIRST: a crystal behind the rubble cannot be taken at all. The click would only
	-- earn "You can't reach that" (no loot window opens for a floor item, so there is not
	-- even an interface to answer), so the rocks ringing it are the target - and that is the
	-- mine step, not this one.
	if not stompOpen(objs, world, solid, cx, cy, px, py, rubbleN) then
		if (now - (D.stompLootShutAt or 0)) > 6000 then
			D.stompLootShutAt = now
			log(string.format('stomp: debris is between us and the crystal at %d,%d - mining the way in', cx, cy))
		end
		return false
	end
	-- ALREADY CLICKED. The click owns this object until it lands or the window runs out;
	-- nothing here clicks it a second time.
	local clickedAt = D.stompTakeClicked and D.stompTakeClicked[ck]
	if clickedAt then
		if (now - clickedAt) < D.STOMP_TAKE_WAIT_MS then
			API.RandomSleep2(200, 80, 120)
			return true
		end
		D.stompTakeClicked[ck] = nil
		D.stompLootSkip = D.stompLootSkip or {}
		D.stompLootSkip[ck] = now
		log(string.format('stomp: crystal %d at %d,%d did not come in %.1f s - leaving that crystal for %d s',
			crystal.Id, cx, cy, (now - clickedAt) / 1000, math.floor(D.STOMP_LOOT_SKIP_MS / 1000)))
		return false
	end
	if (now - (D.stompTakeAt or 0)) <= D.STOMP_TAKE_GAP_MS then return false end
	D.stompTakeAt = now
	D.stompTakeClicked = D.stompTakeClicked or {}
	D.stompTakeClicked[ck] = now
	say('picking up the crystal')
	log(string.format('stomp: taking crystal %d at %d,%d (type %s) - one click',
		crystal.Id, cx, cy, tostring(crystal.Type)))
	local before = stompHeldCount(crystal.Id)
	local sent
	if (tonumber(crystal.Type) or 0) == 3 then
		-- DIRECT TAKE, AND NOTHING ELSE. The ground item's own pickup is one click and the
		-- client walks the player in by itself; the loot-window route is a click, a 1.4 s
		-- sleep and a sweep of an interface that never appears for a dungeon floor item.
		sent = stompTakeDirect(crystal)
	else
		-- a crystal that is a prop rather than a ground item: click its own option
		sent = D.clickObject(tostring(crystal.Action or D.STOMP_TAKE_ACT), crystal)
	end
	if not sent then
		-- never dispatched (the engine refused it): the tile is free to try again
		D.stompTakeClicked[ck] = nil
		return false
	end
	API.RandomSleep2(600, 120, 200)
	if stompHeldCount(crystal.Id) > before then
		D.stompTakeClicked[ck] = nil
		-- ONE TICK SPENT, SO SPEND IT ON THE TWIN. They fall in pairs and a phase needs two:
		-- taking the second here saves a whole pass (a full world sweep) between them.
		if (tonumber(crystal.Type) or 0) == 3 and stompHeldCount(crystal.Id) < D.STOMP_STONES then
			stompTakeSecond(crystal, objs, world, solid, rubbleN, px, py, now)
		end
	end
	-- either it is in the pack or the click is walking us in: both are the pass spent
	return true
end

-- HOLD THE PASS, BUT NEVER FOR EVER. Every "wait a moment" in this fight goes through
-- here: a phase that cannot be progressed (stones answering no option, the right crystal
-- never dropping, a stone that cannot be walked to) must hand the pass back instead of
-- stalling the fight - which is what "no walking, no attacking, no eating" looked like.
local function stompHold(now, inactive)
	if not D.stompHoldAt then D.stompHoldAt = now end
	if (now - D.stompHoldAt) > (D.STOMP_PHASE_MS + 8000) then
		local held = (now - D.stompHoldAt) / 1000
		D.stompHoldAt, D.stompPhaseOn = nil, false
		log(string.format('stomp: nothing chargeable for %.0f s (%d stone(s) wanting) - back to the attack',
			held, inactive or 0))
		return false
	end
	API.RandomSleep2(200, 80, 120)
	return true
end

-- SWING AT HIM OURSELVES. The room-clear branch only attacks an npc whose Life reads above 1
-- and that offers "Attack", and Stomp reports Life 0 for stretches while he stands over the
-- lodestones - so a pass handed back to that branch could end with nothing happening at all,
-- which is the "it just stands there after the debris cleared" report. One click per
-- D.STOMP_SWING_MS, and the "currently invulnerable" stamp still holds the next one back.
local function stompSwing(boss, stamp, now, why)
	if boss == nil or boss.Id == nil then return false end
	if (now - (D.stompSwingAt or 0)) <= D.STOMP_SWING_MS then return false end
	if (stamp ~= 0) and ((now - stamp) < D.STOMP_INVULN_MS) then return false end
	D.stompSwingAt = now
	say('attacking Stomp')
	-- the swing repeats every D.STOMP_SWING_MS; the line is worth one every few seconds, not
	-- one per click
	if (now - (D.stompSwingLogAt or 0)) > 10000 then
		D.stompSwingLogAt = now
		log(string.format('stomp: %s - swinging at him', why))
	end
	pcall(API.DoAction_NPC, D.ACT_ATTACK, D.ROUTE_ATK, { boss.Id }, 50)
	API.RandomSleep2(600, 300, 500)
	return true
end

local function bossStomp(boss, world, px, py)
	local objs = D.objScan()
	local now = API.SystemTime()
	-- THE ARENA, fixed once per pass: every lodestone, crystal, rock and walk target below
	-- is checked against it, so nothing this fight clicks can be in another room.
	D.stompArena = stompArenaBox(boss, world)

	-- 1. the rock is aimed at the tile we are standing on: being somewhere else IS the
	-- dodge, so step to the first neighbour without a shadow of its own
	for _, o in ipairs(objs) do
		local t = o.Tile_XYZ
		if t and stompDebris(o) and math.floor(t.x) == px and math.floor(t.y) == py then
			local shadow = {}
			for _, o2 in ipairs(objs) do
				local t2 = o2.Tile_XYZ
				if t2 and stompDebris(o2) then
					shadow[pkey(math.floor(t2.x), math.floor(t2.y))] = true
				end
			end
			for i = 1, #D.STOMP_STEPS do
				local nx, ny = px + D.STOMP_STEPS[i][1], py + D.STOMP_STEPS[i][2]
				if not shadow[pkey(nx, ny)] and world and world.walk and world.walk[pkey(nx, ny)] then
					say('dodging the falling debris')
					log(string.format('stomp: debris on %d,%d - stepping to %d,%d', px, py, nx, ny))
					D.walkTile(nx, ny, 0)
					API.RandomSleep2(250, 100, 150)
					settle()
					return true
				end
			end
			break
		end
	end

	-- 2. eat before the next rock lands
	local hp = nil
	local okHp, h = pcall(function() return API.GetHPrecent() end)
	if okHp and type(h) == 'number' then hp = h end
	if hp and hp <= D.STOMP_EAT_AT and (now - (D.stompEatAt or 0)) > 1800 then
		local hasFood = false
		pcall(function() hasFood = Inventory:HasFood() and true or false end)
		-- HasFood says A food exists; it does not say which, so the pack is matched by
		-- the Daemonheim food names rather than eating whatever slot happens to be first.
		local okIt, items = pcall(function() return Inventory:GetItems() end)
		if hasFood and okIt and items then
			for _, it in ipairs(items) do
				local nm = string.lower(tostring(it.name or ''))
				local food = false
				for _, w in ipairs(D.STOMP_FOOD_WORDS) do
					if string.find(nm, w, 1, true) then food = true break end
				end
				if food then
					D.stompEatAt = now
					say('eating')
					log(string.format('stomp: eating %s at %d%% health', tostring(it.name), hp))
					pcall(function() Inventory:Eat(it.id) end)
					API.RandomSleep2(600, 250, 350)
					return true
				end
			end
		end
	end

	-- 2b. STAY IN THE ARENA. A pass that ends up outside it (the doorway, the corridor beyond
	-- it, a click that overshot) is a pass the fight loses: everything this strategy clicks
	-- stands inside the arena. Walk back in while the floor around the boss still takes a
	-- click; once it does not, HAND THE PASS BACK - the doorway task is what opens the way in,
	-- and it only stands down while the player is already inside the boss's room.
	if D.stompArena and not stompInArena(px, py) then
		if (now - (D.stompBackAt or 0)) > 1500 and (D.stompBackTries or 0) < 3 then
			local bt = boss and boss.Tile_XYZ
			local bx, by = px, py
			if bt and bt.x == bt.x and bt.y == bt.y then
				bx, by = math.floor(bt.x), math.floor(bt.y)
			end
			local best, bestD2 = nil, math.huge
			for dx = -4, 4 do
				for dy = -4, 4 do
					local sx, sy = bx + dx, by + dy
					if math.max(math.abs(dx), math.abs(dy)) >= 2 and world and world.walk
						and world.walk[pkey(sx, sy)] then
						local d = (sx - px) ^ 2 + (sy - py) ^ 2
						if d < bestD2 then bestD2, best = d, { x = sx, y = sy } end
					end
				end
			end
			if best then
				D.stompBackAt = now
				D.stompBackTries = (D.stompBackTries or 0) + 1
				say('walking back into the arena')
				log(string.format('stomp: standing outside the arena at %d,%d - walking back to %d,%d',
					px, py, best.x, best.y))
				if D.walkTile(best.x, best.y, 0) then
					API.RandomSleep2(400, 150, 250)
					return true
				end
			end
		end
		if (now - (D.stompOutAt or 0)) > 4000 then
			D.stompOutAt = now
			log('stomp: outside the arena and the way in is not clickable - letting the doors take the pass')
		end
		return false
	end
	D.stompBackTries, D.stompOutAt = nil, nil

	-- 3. WHAT THE ROOM HOLDS, read before anything is clicked: the crystals (in the pack
	-- and on the floor), whether a phase is running at all, and only then the stones that
	-- want a crystal. The order matters - "a phase is running" decides whether this
	-- strategy owns the pass, and only the crystals can answer it.
	local crystalHeld, heldTotal = nil, 0
	for _, id in ipairs(D.STOMP_CRYSTAL_IDS) do
		local have = stompHeldCount(id)
		heldTotal = heldTotal + have
		if have > 0 and not crystalHeld then crystalHeld = id end
	end
	-- A CHARGE CONFIRMED A PASS LATER. A Charge click sent from across the room only starts
	-- the walk in: the client uses the stone on arrival, which can be several passes after
	-- the click - and the crystal leaving the pack is the only proof it happened. Counting
	-- charges inside their own click pass alone made that charge invisible: the stone still
	-- read as wanting a crystal, and the second crystal was spent on a stone already lit.
	if D.stompPending then
		local p = D.stompPending
		local have = stompHeldCount(p.id)
		if have < (p.n or 0) then
			D.stompPlacedSet = D.stompPlacedSet or {}
			D.stompPlacedSet[p.k] = true
			D.stompCharged = (D.stompCharged or 0) + 1
			D.stompHoldAt, D.stompShut = nil, nil
			if D.stompShutHits then D.stompShutHits[p.k] = nil end
			D.stompPending = nil
			log(string.format('stomp: the lodestone at %s is charged (%d/%d) - the crystal left the pack on the way in',
				tostring(p.k), D.stompCharged, D.STOMP_STONES))
		elseif (now - p.at) > 8000 then
			D.stompPending = nil
		else
			-- watch the count drop from wherever it is now: a crystal taken while the walk
			-- in is still going would otherwise hide the charge behind a bigger number
			p.n = have
		end
	end
	-- WHERE THE RUBBLE STANDS RIGHT NOW, read before the crystals: the walks below never
	-- step onto it (the tile is in the room's walk set - a prop does not block the tile
	-- record - so without this the "step beside the stone" lands ON the rock that is
	-- blocking it), and the crystal BFS treats every rock as a wall.
	local rubbleN, _, rubbleSolid = stompRubbleField(objs)
	-- THREE LISTS, because they answer three different questions:
	--   crystal     - the nearest crystal in the arena, whatever is in front of it. THIS is
	--                 the phase signal: crystals only ever fall during one, so dropping a
	--                 rubble-blocked one out of the list is how the strategy decided "no
	--                 phase" and handed the pass to the doors and the route.
	--   takeCrystal - the nearest one the rubble does not shut off: the only one to click.
	--   cryBlocked  - the nearest one it does shut off: not clicked (the click would only
	--                 answer "You can't reach that"), but kept as a mine goal so the rocks
	--                 ringing it are what gets cleared next.
	local crystal, bestD, crystalsOnFloor = nil, math.huge, 0
	local takeCrystal, takeD = nil, math.huge
	local cryBlocked, blockD = nil, math.huge
	for _, o in ipairs(objs) do
		local t = o.Tile_XYZ
		if t and stompCrystal(o) and stompInArena(t.x, t.y) then
			crystalsOnFloor = crystalsOnFloor + 1
			local cx, cy = math.floor(t.x), math.floor(t.y)
			local d = (cx - px) ^ 2 + (cy - py) ^ 2
			if d < bestD then bestD, crystal = d, o end
			if not stompLootSkipped(cx, cy, now) then
				if stompOpen(objs, world, rubbleSolid, cx, cy, px, py, rubbleN) then
					if d < takeD then takeD, takeCrystal = d, o end
				elseif d < blockD then
					blockD, cryBlocked = d, o
				end
			end
		end
	end
	-- only the STANCE line opens a phase: what was placed for the last one is forgotten
	-- there, and nowhere else
	local stamp = tonumber(chat.stompPhaseAt) or 0
	local startStamp = tonumber(chat.stompPhaseStart) or 0
	if D.stompPhaseStamp ~= startStamp then
		D.stompPhaseStamp, D.stompPlacedSet = startStamp, {}
		-- how many stones WE charged this phase: the only proof that the phase is truly
		-- over rather than a scan that caught the lodestones mid swap
		D.stompCharged = 0
		-- a fresh set of stones: the refusals of the last phase say nothing about these
		D.stompShut, D.stompShutHits, D.stompPending, D.stompTakeClicked = nil, nil, nil, nil
		D.stompIdleAt = nil
	end

	-- 3a. THE STONES THAT STILL WANT A CRYSTAL, nearest first, at any distance.
	--
	-- THE STONE'S OWN OPTION IS THE CLICK. Live, "Blue lodestone" (49278/49279) offers
	-- "Charge" when the player is beside it, and clicking that option is the whole action -
	-- it consumes a crystal from the pack. There is no item-on-object step: selecting the
	-- crystal and using it on the stone (GeneralObject_route_useon) is exactly what
	-- produced four dead "via \"\"" attempts at 19:01 and again at 19:06, with nothing
	-- consumed and the phase running out.
	--
	-- A stone already dealt with THIS phase is skipped, and so is one that has burned its
	-- two attempts. Nothing here asks for an action string: from ten tiles away the client
	-- reports the lodestone with NO action at all, so an action-based scan silently loses
	-- the stone exactly when the player is far from it - which is most of the room.
	--
	-- A stone that is still chargeable after the click is not retried for ever: two
	-- attempts and it is left, so the OTHER stone of the pair gets its crystal - live, the
	-- same one was charged three passes in a row and the second one never got a look in.
	D.stompChargeTries = D.stompChargeTries or {}
	local nearest, nearD = nil, math.huge
	local inactive = 0
	for _, o in ipairs(objs) do
		local t = o.Tile_XYZ
		if t and stompWants(o) and stompInArena(t.x, t.y) then
			local lx, ly = math.floor(t.x), math.floor(t.y)
			local k = pkey(lx, ly)
			local done = D.stompPlacedSet and D.stompPlacedSet[k]
			if not done then
				inactive = inactive + 1
				local skipAt = D.stompStoneSkip and D.stompStoneSkip[k]
				local skipped = skipAt ~= nil and (now - skipAt) < D.STOMP_STONE_SKIP_MS
				if not skipped and (D.stompChargeTries[k] or 0) < 2 then
					local d = (lx - px) ^ 2 + (ly - py) ^ 2
					if d < nearD then nearD, nearest = d, o end
				end
			end
		end
	end
	if inactive == 0 then
		-- none left for this phase: the next earthquake brings fresh lodestones
		D.stompChargeTries = {}
	end

	-- A PHASE IS RUNNING while a STONE WANTS A CRYSTAL, a crystal is on the floor (they
	-- only ever drop during one), or the boss announced one in chat within the window.
	-- "A stone wants a crystal" is the one signal that cannot be missed: it is read
	-- straight from the room, so a phase whose chat line was dropped - or whose line
	-- arrived while the stones were still the inactive model - is still ours. Without it a
	-- phase with an ACTIVE lodestone in the room was handed to the attack branch.
	--
	-- A CRYSTAL IN THE PACK IS NOT A PHASE. It used to count, and a single leftover
	-- crystal then kept this strategy "in a phase" for the rest of the fight: the bot
	-- walked to lodestones that wanted nothing, clicked Charge out of phase, and never
	-- handed the pass back to the attack branch. Two crystals are all a phase needs
	-- (D.STOMP_STONES), so a leftover is simply carried and ignored in between.
	local phase = (inactive > 0) or (crystal ~= nil)
		or ((startStamp ~= 0) and (now - startStamp) < D.STOMP_PHASE_MS)
	-- WHICH CRYSTAL THE ROOM IS ASKING FOR, and the nearest one of that colour on the
	-- floor. A crystal of another colour is not ammunition: it cannot charge these stones.
	local needId = nearest and stompCrystalFor(nearest) or nil
	local crystalMatch, matchD = nil, math.huge
	if needId then
		for _, o in ipairs(objs) do
			local t = o.Tile_XYZ
			if t and o.Id == needId and stompInArena(t.x, t.y) then
				local cx, cy = math.floor(t.x), math.floor(t.y)
				local d = (cx - px) ^ 2 + (cy - py) ^ 2
				-- a crystal the rubble cut off is not ammunition either: the take click would
				-- only answer "You can't reach that", so it is skipped here and the rocks that
				-- ring it become the mine goal instead
				if d < matchD and not stompLootSkipped(cx, cy, now)
					and stompOpen(objs, world, rubbleSolid, cx, cy, px, py, rubbleN) then
					matchD, crystalMatch = d, o
				end
			end
		end
	end
	-- NO STONE LEFT TO FILL IS THE PHASE BEING OVER - whatever is still on the floor or in
	-- the pack. Live, 19:27: both stones answered "" once we finally stood beside them, but
	-- two crystals were in the pack, so "done" never became true and the strategy held the
	-- pass for the rest of the fight - no walking, no attacking, no eating.
	--
	-- A SCAN THAT SEES NO STONE IS NOT PROOF, THOUGH. The lodestones are removed and
	-- re-created when the phase flips, so one pass can see none of them at all: standing
	-- down on that pass is how the fight was abandoned 0.8 s after the walk to a stone had
	-- started (live, 20:06:56 "crystal phase - 2 stone(s) left to fill" -> 20:06:57 the
	-- router was picking a doorway). Two ways to be sure: we charged both stones ourselves
	-- this phase, or the empty answer has held still for D.STOMP_SETTLE_MS.
	if inactive > 0 then
		D.stompNoStoneAt = nil
	elseif not D.stompNoStoneAt then
		D.stompNoStoneAt = now
	end
	local settled = (now - (D.stompNoStoneAt or now)) > D.STOMP_SETTLE_MS
	-- AND THE PHASE WINDOW HAS TO BE CLOSED. A stance line keeps the phase ours until
	-- D.STOMP_PHASE_MS has passed: within that window an empty stone scan is a room that
	-- has not caught up (or one pass that caught the models mid swap), never a phase that
	-- is over. Without this the walk to a stone was abandoned 0.8 s after it started
	-- (live, 20:06:56 -> 20:06:57) and the fight was lost to the router.
	--
	-- THE WINDOW IS THE STANCE LINE ONLY. "Stomp is currently invulnerable!" is stamped too
	-- (it is the same field), but that line is produced by OUR OWN SWINGS bouncing off him -
	-- and while auto-retaliate is answering his attacks it never stops. Reading it as "a
	-- phase is running" held the pass for ever: the bot never attacked him at all.
	local windowOpen = (startStamp ~= 0) and (now - startStamp) < D.STOMP_PHASE_MS
	local phaseDone = (inactive == 0) and (((D.stompCharged or 0) >= D.STOMP_STONES)
		or (settled and not windowOpen))
	-- THE LINE ARRIVES BEFORE THE ROOM DOES. A stance line that landed a moment ago with
	-- nothing yet asking for a crystal is a phase setting itself up, not a phase that is
	-- over: hold the pass instead of swinging at an invulnerable boss - and instead of
	-- letting the router walk out of the room, which is what 19:51:14 turned into.
	local warmup = (startStamp ~= 0) and (now - startStamp) < D.STOMP_WARMUP_MS
	if warmup and inactive == 0 and crystal == nil then
		D.stompPhaseOn = false
		say('waiting for the lodestones')
		return stompHold(now, inactive)
	end
	if not phase or phaseDone then
		-- nothing of ours in the room, or the phase is over
		D.stompPhaseOn, D.stompHoldAt = false, nil
		-- 1. CRYSTALS FIRST - UNLESS THIS PHASE IS ALREADY DONE. Whatever else is going on
		-- the ammunition on the floor is worth the pass, and the debris wait below used to
		-- take it every time, so crystals were left lying where they fell. The exception is
		-- a phase we just completed: both stones charged means the boss is VULNERABLE right
		-- now, and two crystals is all a phase ever needs, so looting would spend the
		-- damage window on a shopping trip.
		if (D.stompCharged or 0) < D.STOMP_STONES
			and stompTakeCrystal(takeCrystal, takeD, heldTotal, world, px, py, now, objs, rubbleSolid, rubbleN) then
			return true
		end
		-- 2. THEN THE WALKING. THE FIGHT IS NOT OVER WHEN THE STONES ARE. The debris keeps
		-- coming down after the last crystal, and attacking means standing still under it
		-- (the falling rock is 25% of max life). Pace the open floor until it has all
		-- despawned, then hand the pass back to the attack branch. Asked whatever the phase
		-- bookkeeping says: debris on the floor is debris on the floor.
		if stompWaitDebris(boss, world, px, py, now, objs) then
			return true
		end
		if not D.stompDeclineAt or (now - D.stompDeclineAt) > 6000 then
			D.stompDeclineAt = now
			-- WHAT THE SCAN ACTUALLY SAW, because "0 stone(s) wanting" cannot be told from
			-- "no lodestone in the list at all" from the counts alone, and the two need
			-- different fixes
			local seen = {}
			for _, o in ipairs(objs) do
				if stompLodestone(o) then
					local t = o.Tile_XYZ
					seen[#seen + 1] = string.format('%s(%d)@%d,%d%s', tostring(D.objName(o)), o.Id,
						math.floor((t and t.x) or -1), math.floor((t and t.y) or -1),
						stompWants(o) and '*' or '')
				end
			end
			log(string.format('stomp: standing down - %d stone(s) wanting, %d crystal(s) on the floor, %d charged, phase window %s, stones: %s',
				inactive, crystalsOnFloor, D.stompCharged or 0, phase and 'open' or 'closed',
				#seen > 0 and table.concat(seen, ' ') or 'none seen'))
		end
		-- HE IS ONLY VULNERABLE AFTER BOTH STONES ARE CHARGED - that is what "The portal
		-- weakens, harming Stomp!" means. A swing at any other time answers "Stomp is
		-- currently invulnerable!", and repeating it for the length of a stance is exactly
		-- what read as "keeps attacking stomp" (live 20:11:21: no stone lit, six crystals on
		-- the floor, and an attack click every couple of seconds). So: while the stance
		-- window is open and this phase was not completed, hold the pass - the debris pacing
		-- above is what keeps the player moving - and once the window has closed, hand it
		-- back to the attack so a phase that never lights up cannot stall the fight.
		if windowOpen and (D.stompCharged or 0) < D.STOMP_STONES then
			say('waiting for the lodestones')
			return stompHold(now, inactive)
		end
		-- HE SAID "INVULNERABLE" A MOMENT AGO: hold this pass, do not swing again. That line
		-- only ever comes from our own swing bouncing off him, so one probing swing is the
		-- whole cost of the answer - but it must NOT be read as a phase (see windowOpen):
		-- refreshed by auto-retaliate it never stops, and holding on it meant he was never
		-- attacked at all.
		if (stamp ~= 0) and ((now - stamp) < D.STOMP_INVULN_MS) then
			API.RandomSleep2(300, 150, 250)
			return true
		end
		-- and the click itself, because the room-clear branch cannot be relied on for him
		if stompSwing(boss, stamp, now, 'phase over, nothing left to click') then return true end
		return false
	end
	-- the strategy is acting again: a later stand-down is worth a fresh line, not silence
	D.stompDeclineAt = nil

	-- 3b. THE CRYSTALS FIRST - BEFORE THE CHARGE, THE ROCKS AND THE PACING. A crystal on the
	-- floor is the phase's ammunition: it is the only thing that can charge a stone, and it
	-- does not lie there long. So the pickup outranks everything else this fight does. One
	-- direct Take click each (the client walks the player in), the twin taken in the same
	-- pass, and a crystal of the wrong colour is still taken when the stones have not asked
	-- for a colour yet - it is ammunition for the next phase either way.
	if needId then
		if stompTakeCrystal(crystalMatch, matchD, stompHeldCount(needId), world, px, py, now, objs, rubbleSolid, rubbleN) then
			return true
		end
		if not crystalMatch then
			-- nothing of the right colour down: hold rather than fill the pack with the
			-- wrong one, so the floor crystals that DO fall this phase get taken
			if stompHeldCount(needId) < D.STOMP_STONES and (now - (D.stompNoMatchAt or 0)) > 6000 then
				D.stompNoMatchAt = now
				log(string.format('stomp: waiting for crystal %d - %d crystal(s) on the floor, none of them it',
					needId, crystalsOnFloor))
			end
		end
	elseif stompTakeCrystal(takeCrystal, takeD, heldTotal, world, px, py, now, objs, rubbleSolid, rubbleN) then
		return true
	end

	-- 3c. THEN THE STONE - CLICK ITS OWN OPTION, the client walks the player in.
	--
	-- A stone that is still chargeable after the click is not retried for ever: two
	-- attempts and it is left, so the OTHER stone of the pair gets its crystal - live, the
	-- same one was charged three passes in a row and the second one never got a look in.
	--
	-- ONE LINE PER PHASE: what the scan can see, how many crystals, and what the pack holds.
	if not D.stompPhaseOn or (stamp ~= 0 and D.stompPhaseLogged ~= stamp) then
		D.stompPhaseOn, D.stompPhaseLogged = true, stamp
		log(string.format('stomp: crystal phase - %d stone(s) left to fill, %d crystal(s) on the floor, holding %d/%d of crystal %s',
			inactive, crystalsOnFloor, needId and stompHeldCount(needId) or 0, D.STOMP_STONES,
			tostring(needId)))
	end
	-- THE STONE NEEDS THE CRYSTAL OF ITS OWN COLOUR, AND BOTH CRYSTALS FIRST.
	-- Clicking Charge holding a different colour answers "You do not have the required item"
	-- and consumes nothing, so the colour decides whether there is anything to place - and
	-- the whole phase needs TWO, so both are collected before the first stone is touched.
	-- Walking to a stone, charging, walking back out for the second crystal and walking in
	-- again is three crossings of a room that is falling apart; two crystals in the pack is
	-- two clicks.
	--
	-- The only exceptions are the end of the window (with one crystal in hand and the stance
	-- almost over, half a phase beats none) and a phase already started - once the first
	-- stone is charged there is one crystal left and one stone to fill, so the second charge
	-- goes in with what the first one left behind.
	local heldNeed = needId and stompHeldCount(needId) or 0
	local late = (startStamp ~= 0) and ((now - startStamp) > D.STOMP_LATE_MS)
	local armed = heldNeed >= D.STOMP_STONES
		or (heldNeed >= 1 and (((D.stompCharged or 0) > 0) or late))
	-- A STONE THE CLIENT ALREADY REFUSED IS NOT CLICKED AGAIN while the rubble stands: the
	-- way in is mined, not walked, so the click branch is skipped and the pass falls
	-- through to the mine step below.
	local shutKey = nearest and pkey(math.floor(nearest.Tile_XYZ.x), math.floor(nearest.Tile_XYZ.y))
	if nearest and needId and armed and (now - (D.stompChargeAt or 0)) > D.STOMP_CHARGE_GAP_MS
		and not (shutKey and stompShutOff(shutKey, now, rubbleN)) then
		local nt = nearest.Tile_XYZ
		local nx, ny = math.floor(nt.x), math.floor(nt.y)
		local lk = pkey(nx, ny)
		local dist = math.max(math.abs(nx - px), math.abs(ny - py))
		local adj = dist <= 1
		-- A CHARGE IS ALREADY ON ITS WAY. The click that sent it also started the walk in, so
		-- a second click would only restart that walk (and cost the tile's click budget).
		-- D.stompPending is what turns "the crystal left the pack" into the confirmation, so
		-- waiting here is cheap - and the refusal, when there is one, is read here too: it
		-- usually lands while the walk in is still going, and flipping straight to the mine
		-- step beats waiting the whole pending window out.
		if D.stompPending and D.stompPending.k == lk then
			drainChat()
			if (tonumber(chat.noReach) or 0) > (D.stompPending.noReach or 0) then
				stompShutStone(lk, nx, ny, now)
				return true
			end
			API.RandomSleep2(200, 80, 120)
			return true
		end
		-- CLICK IT, NEVER WALK TO IT. The stone's own option is the whole interaction and
		-- the client walks the player in by itself, so a tile click first only competes with
		-- the walk the Charge click already started. The old rule ("the Charge option is only
		-- resolved when adjacent") came from a scan that reports no Action text at range; the
		-- OPTION CODE does not depend on that (0x39, the object's only option), so a distant
		-- click is a legal click - and if the way in is blocked, the client says so in chat
		-- ("You can't reach that"), which is the signal to mine the debris, not to walk.
		--
		-- Beside it we still wait for the tile to hold still first: a click sent while a
		-- walk is carrying the player is retargeted or dropped.
		if adj and not D.canClickNow(2000) then
			API.RandomSleep2(200, 100, 150)
			return true
		end
		-- read the stone as it stands NOW, not the record the pass opened with
		local live = D.liveObjectAt(nearest.Id, nx, ny)
		if live == nil then
			-- THE STONE IS GONE FROM THAT TILE. Between the scan that chose it and this
			-- click the phase ended and the model swapped back to "Inactive lodestone"
			-- (a different id), so the record in hand is stale - and clicking a record
			-- the server no longer knows dispatches an object action that answers
			-- NOTHING AT ALL: no chat line, no consumption. Live, 19:59:11: a "Charge"
			-- click with a Red crystal in the pack against a Red lodestone produced no
			-- game message whatsoever. Re-read the room instead of clicking this.
			if (now - (D.stompGoneAt or 0)) > 4000 then
				D.stompGoneAt = now
				log(string.format('stomp: the lodestone at %d,%d is not there any more - re-reading', nx, ny))
			end
			D.stompChargeAt = now
			return true
		end
		local rec = (live ~= false) and live or nearest
		local act = tostring(D.objGet(rec, 'Action') or '')
		local low = string.lower(act)
		-- "Examine"/"Cancel" are menu entries, not actions on the stone. An EMPTY
		-- action at range is not "no option": the client only resolves option text when
		-- the player is close, and the click is sent by option CODE (0x39 = the object's
		-- only option), so "Charge" is what we ask for either way.
		local chargeable = act == '' or (low ~= 'examine' and low ~= 'cancel')
		if not chargeable then
			-- next to it and it offers nothing: this stone is done for this phase. When
			-- D.liveObjectAt could not read the stone at all (nil, not false) the answer
			-- is not trusted on the first look - a scan glitch must not write a stone off
			-- for the rest of the phase.
			local sure = (live ~= nil)
			D.stompChargeTries[lk] = (D.stompChargeTries[lk] or 0) + 1
			if sure or D.stompChargeTries[lk] >= 2 then
				D.stompPlacedSet = D.stompPlacedSet or {}
				D.stompPlacedSet[lk] = true
				log(string.format('stomp: lodestone at %d,%d offers "%s" - nothing to put there', nx, ny, act))
			end
			return true
		end
		D.stompChargeAt = now
		-- AN ATTEMPT IS A CLICK FROM BESIDE THE STONE. A click sent across the room only
		-- starts the walk in, so counting it would burn both attempts before the player
		-- ever arrived - and both attempts spent means the stone is written off.
		if adj then D.stompChargeTries[lk] = (D.stompChargeTries[lk] or 0) + 1 end
		local before = stompHeldCount(needId)
		local noReach0 = tonumber(chat.noReach) or 0
		-- the option is asked for BY NAME and the stone has only one, so an unresolved
		-- scan ("") still clicks "Charge" instead of falling back to a default action
		local clickAct = (act ~= '') and act or D.STOMP_CHARGE_ACT
		say('placing the crystal on the lodestone')
		log(string.format('stomp: crystal %d onto the lodestone at %d,%d via "%s" from %d tiles (%s)', needId,
			nx, ny, clickAct, dist,
			adj and string.format('try %d/2', D.stompChargeTries[lk] or 0) or 'walking in'))
		if not D.clickObject(clickAct, rec) then
			-- the click was refused before dispatch (rate limit on that tile): do not
			-- burn one of the two attempts on it
			D.stompChargeTries[lk] = math.max(0, (D.stompChargeTries[lk] or 1) - 1)
			log(string.format('stomp: the "%s" click at %d,%d was refused before dispatch', clickAct, nx, ny))
		else
			-- the charge is confirmed by the crystal leaving the pack, and from across the
			-- room that happens when the walk in arrives - see the pending check at step 3
			D.stompPending = { k = lk, id = needId, n = before, at = now,
				noReach = tonumber(chat.noReach) or 0 }
		end
		API.RandomSleep2(600, 120, 200)
		-- NO settle() HERE. A click from range is a WALK IN, and settle() waits for the
		-- character to stop - several seconds of a fifteen-second phase spent watching it
		-- walk. D.stompPending carries the confirmation to whichever pass the crystal
		-- actually leaves the pack on, so nothing is lost by not waiting.
		-- "You can't reach that" only arrives in chat, and the pump is how this chunk reads
		-- it: without the drain here the refusal would only be seen on the NEXT pass, after
		-- the same click had already been sent again.
		drainChat()
		-- CHARGED ONLY IF THE CRYSTAL LEFT THE PACK. Counting dispatched clicks instead
		-- is what let the phase look "done" after four clicks that never landed, and
		-- the pass then went to the attack branch while the lodestones were still dark.
		if stompHeldCount(needId) < before then
			D.stompPlacedSet = D.stompPlacedSet or {}
			D.stompPlacedSet[lk] = true
			D.stompCharged = (D.stompCharged or 0) + 1
			D.stompHoldAt = nil
			D.stompShut, D.stompPending = nil, nil
			if D.stompShutHits then D.stompShutHits[lk] = nil end
			log(string.format('stomp: crystal consumed - the lodestone at %d,%d is charged (%d/%d)',
				nx, ny, D.stompCharged, D.STOMP_STONES))
		elseif (tonumber(chat.noReach) or 0) > noReach0 then
			-- the click did not fail as a click, so it does not cost one of the two charge
			-- attempts; the stone is shut and the mine step takes the pass
			D.stompChargeTries[lk] = math.max(0, (D.stompChargeTries[lk] or 1) - 1)
			stompShutStone(lk, nx, ny, now)
		else
			log(string.format('stomp: the "%s" click from %d tiles left the crystal in the pack',
				clickAct, dist))
		end
		return true
	end

	-- 5. CLEAR THE ROCKS THAT SHUT THE GOAL OFF - and only those.
	--
	-- THE ROOM'S OWN WALK SET CANNOT ANSWER THIS. It is built from the type-99 tile
	-- records, and a "Debris" prop standing on a tile does not change the tile record
	-- underneath it - so D.walkSpotNear reports a spot right beside a lodestone that is
	-- ringed by rocks, the fight "knows" the stone is reachable, and nothing is ever
	-- mined. The client's own path test is the only thing that knows an OBJECT blocks a
	-- tile: "can I stand within two tiles of the goal", cached for a second because it is
	-- a real path find.
	--
	-- While it says no, the rock nearest the goal within a few tiles is cleared, one per
	-- pass - a second rock is never clicked while the first is still there, and the
	-- answer is re-asked every pass, so the wall around a stone is taken down rock by rock
	-- until the path opens. Rocks elsewhere in the room are never touched.
	--
	-- A STONE THE CLIENT REFUSED ("You can't reach that") counts as shut off whatever this
	-- path test says: the debris is across the way in, there is no path round it, and only
	-- mining clears it - so that stone is the goal ahead of anything else in the room. A
	-- crystal the rubble cut off is a goal for the same reason.
	local shutStone = nil
	if D.stompShut and stompShutOff(D.stompShut.k, now, rubbleN) then
		for _, o in ipairs(objs) do
			local t = o.Tile_XYZ
			if t and stompWants(o) and stompInArena(t.x, t.y)
				and pkey(math.floor(t.x), math.floor(t.y)) == D.stompShut.k then
				shutStone = o
				break
			end
		end
	end
	local goal = shutStone or (needId and stompHeldCount(needId) > 0 and nearest) or crystalMatch
		or takeCrystal or crystal or cryBlocked or nearest
	if goal and (now - (D.stompMineAt or 0)) > 900 then
		local gt = goal.Tile_XYZ
		local gx, gy = math.floor(gt.x), math.floor(gt.y)
		local gz = math.floor(tonumber(gt.z) or 0)
		local gk = pkey(gx, gy)
		local reach
		local memo = D.stompReachMemo
		if stompShutOff(gk, now, rubbleN) then
			reach = false
		elseif memo and memo.k == gk and (now - memo.at) < 1200 then
			reach = memo.ok
		else
			-- TOLERANCE 1, not 2: an object is used from an ADJACENT tile, so "within two
			-- tiles" says yes while the only tiles one step from the stone are covered in
			-- rock - and the Charge click then fails with "You can't reach that".
			reach = D.tileReachable(gx, gy, gz, 1)
			D.stompReachMemo = { k = gk, at = now, ok = reach }
		end
		if not reach then
			local rubble, rockD = nil, math.huge
			-- every rock that sits around the shut-off goal, so the console shows the
			-- COMBINED blockage (three rocks in a line is one wall, not one rock) and not
			-- just whichever one is being cleared this pass
			local blockers = {}
			local farD = D.STOMP_RUBBLE_FAR * D.STOMP_RUBBLE_FAR
			local goalD = D.STOMP_RUBBLE_GOAL_R * D.STOMP_RUBBLE_GOAL_R
			D.stompRockSkip = D.stompRockSkip or {}
			for _, o in ipairs(objs) do
				local t = o.Tile_XYZ
				-- BY ID AND NAME, not by the action text: a rock on the far side of the
				-- room reports no action at all, exactly like the lodestone, so an
				-- action-filtered scan cannot see the very rocks that block the way in.
				if t and stompRubble(o) and stompInArena(t.x, t.y) then
					local rx, ry = math.floor(t.x), math.floor(t.y)
					local k = pkey(rx, ry)
					if not D.stompRockSkip[k] then
						local d = (rx - px) ^ 2 + (ry - py) ^ 2
						local gd = (rx - gx) ^ 2 + (ry - gy) ^ 2
						if d <= farD and gd <= goalD then
							blockers[#blockers + 1] = string.format('%d,%d', rx, ry)
							if gd < rockD then rockD, rubble = gd, o end
						end
					end
				end
			end
			if rubble then
				local rt = rubble.Tile_XYZ
				local rx, ry = math.floor(rt.x), math.floor(rt.y)
				local adjR = math.max(math.abs(rx - px), math.abs(ry - py)) <= 1
				-- NOT BESIDE IT YET: walk to it, like the crystal walk above. The rock is in
				-- the room, so a tile click on it is a legal walk target even though the tile
				-- itself is occupied.
				if not adjR and (now - (D.stompWalkAt or 0)) > 1500 then
					D.stompWalkAt = now
					say('walking to the rock in the way')
					log(string.format('stomp: the rock shutting %d,%d off stands at %d,%d - walking to it',
						gx, gy, rx, ry))
					D.walkTile(rx, ry, 0)
					API.RandomSleep2(400, 150, 250)
					return true
				end
				-- BESIDE IT: stand still first, then read the rock as it is NOW and click
				-- the option it offers. A click fired mid-walk is retargeted or dropped.
				if not D.canClickNow(1500) then
					API.RandomSleep2(200, 100, 150)
					return true
				end
				local liveR = D.liveObjectAt(rubble.Id, rx, ry)
				local recR = (liveR and liveR ~= false) and liveR or rubble
				local actR = tostring(D.objGet(recR, 'Action') or '')
				if actR == '' then
					-- no option on it: not a rock we can clear (or already gone)
					local kR = pkey(rx, ry)
					D.stompRockSkip[kR] = true
					log(string.format('stomp: rock at %d,%d offers nothing - leaving it', rx, ry))
					return true
				end
				D.stompMineAt = now
				say('clearing the rock in the way')
				local shown = #blockers
				local list = table.concat(blockers, ' ', 1, math.min(shown, 6))
				if shown > 6 then list = list .. ' ...' end
				log(string.format('stomp: goal %d,%d is shut off - %d rock(s) around it (%s) - clearing %d,%d via "%s"',
					gx, gy, shown, list, rx, ry, actR))
				D.clickObject(actR, recR)
				API.RandomSleep2(700, 250, 350)
				settle()
				return true
			end
			-- no rock near the goal: something else shut it off (the boss body, a prop).
			-- Mining is not the answer, so this pass falls through to the walk/attack.
		end
	end

	-- 6. NOTHING TO CLICK YET. The boss is invulnerable until both stones are charged, so
	-- handing the pass to the attack branch too early spends it on a hit that cannot land
	-- (and fills the chat with "Stomp is currently invulnerable!"). Debris on the floor is
	-- paced, not stood under: the wait is the same wait.
	if stompWaitDebris(boss, world, px, py, now, objs) then
		return true
	end
	-- NOTHING LEFT TO COLLECT - ACT. The crystals of a phase fall WITH the earthquake, so once
	-- the debris has cleared an empty floor means they are gone, not coming; holding the pass
	-- then is the "it just stands there after the debris cleared" report. The short grace
	-- window keeps the late single-crystal charge possible (a stone only needs one once
	-- D.STOMP_LATE_MS has passed); after it the strategy swings at him itself.
	if crystalMatch == nil and cryBlocked == nil then
		if not D.stompIdleAt then D.stompIdleAt = now end
		if (now - D.stompIdleAt) > D.STOMP_IDLE_GIVEUP_MS then
			D.stompIdleAt = nil
			if (stamp ~= 0) and ((now - stamp) < D.STOMP_INVULN_MS) then
				API.RandomSleep2(300, 150, 250)
				return true
			end
			local why = string.format('floor clear, nothing left to collect (%d stone(s) wanting, holding %d/%d)',
				inactive, heldNeed, D.STOMP_STONES)
			if stompSwing(boss, stamp, now, why) then return true end
			return false
		end
	else
		D.stompIdleAt = nil
	end
	if nearest and needId and heldNeed == 1 then
		say('collecting the second crystal')
	else
		say(nearest and 'waiting for the crystal' or 'waiting for the lodestones')
	end
	return stompHold(now, inactive)
end

D.bossLogic = { gluttonous = bossGluttonous, skeletalhorde = bossSkeletalHorde,
	stomp = bossStomp }

--------------------------------------------------------------------
-- Har'Lakk the Riftsplitter: get OFF the tile the portal was cast on.
--------------------------------------------------------------------
-- The boss drops a portal through the tile the player is standing on and says so in
-- chat ("...miasma...", "...flame portal...", "...cut you..."), then that tile and the
-- ring around it burn for about ten seconds. The fight itself is an ordinary spam attack;
-- the only mechanic is not standing in the portal. MegaDungeon's Riftsplitter.java does
-- exactly this: remember the player's tile when the message lands, keep it for 10 s, and
-- walk away instead of attacking while you are inside it. It walks to a RANDOM room tile;
-- here the nearest walkable tile outside every live portal is used instead, so the player
-- stays in range of the boss.
D.RIFT_LIFE_MS = 10000      -- how long a portal burns (java: Portal_Life = 10 s)
D.RIFT_RADIUS  = 1          -- covers the cast tile and the 8 around it
D.RIFT_STEP_MAX = 4         -- how far the step-off is allowed to reach

-- Live portals from the chat pump, with expired ones dropped. chat.riftPortals holds the
-- tile that was under the player at the moment the boss announced it.
local function riftPortals()
	local list = chat.riftPortals
	if not list or #list == 0 then return nil end
	local now = API.SystemTime()
	local keep = {}
	for i = 1, #list do
		local p = list[i]
		if p and p.at and (now - p.at) < D.RIFT_LIFE_MS then keep[#keep + 1] = p end
	end
	chat.riftPortals = (#keep > 0) and keep or nil
	return chat.riftPortals
end

local function riftInPortal(list, x, y)
	if not list then return nil end
	for i = 1, #list do
		local p = list[i]
		if math.abs(x - p.x) <= D.RIFT_RADIUS and math.abs(y - p.y) <= D.RIFT_RADIUS then
			return p
		end
	end
	return nil
end

-- Everything that is dangerous to stand on: the tile the boss announced (chat) PLUS any
-- portal actually standing on the floor within reach. The chat pump only sees chatbox
-- lines, so if an announcement is missed the object is the second, independent answer.
local function riftHazards(px, py)
	local live = riftPortals()
	local list = {}
	if live then
		for i = 1, #live do list[#list + 1] = live[i] end
	end
	local scan = D.objScan and D.objScan() or nil
	if scan then
		local now = API.SystemTime()
		for _, o in ipairs(scan) do
			local ok, nm, t = pcall(function() return o.Name, o.Tile_XYZ end)
			if ok and nm and t then
				local n = string.lower(tostring(nm))
				if string.find(n, 'portal', 1, true) or string.find(n, 'miasma', 1, true) then
					local x, y = math.floor(t.x), math.floor(t.y)
					if math.max(math.abs(x - px), math.abs(y - py)) <= 8 then
						list[#list + 1] = { x = x, y = y, at = now }
					end
				end
			end
		end
	end
	if #list == 0 then return nil end
	return list
end

local function bossRiftsplitter(boss, world, px, py)
	local list = riftHazards(px, py)
	if not list then return false end
	local p = riftInPortal(list, px, py)
	if not p then return false end          -- clear of every portal: the caller attacks
	-- The nearest walkable tile that is outside all of them. Reading the walk set is what
	-- keeps this out of walls; a portal in a corner still leaves the ring's outside.
	local nx, ny, best = nil, nil, math.huge
	if world and world.walk then
		for dx = -D.RIFT_STEP_MAX, D.RIFT_STEP_MAX do
			for dy = -D.RIFT_STEP_MAX, D.RIFT_STEP_MAX do
				local x, y = px + dx, py + dy
				if (dx ~= 0 or dy ~= 0) and world.walk[pkey(x, y)]
					and not riftInPortal(list, x, y) then
					local v = dx * dx + dy * dy
					if v < best then best, nx, ny = v, x, y end
				end
			end
		end
	end
	if not nx then
		-- boxed in by portals: attacking from inside beats standing still doing nothing
		return false
	end
	D.riftSteps = (D.riftSteps or 0) + 1
	if D.riftSteps <= 3 or D.riftSteps % 15 == 0 then
		log(string.format('riftsplitter: portal under us at %d,%d - stepping off it to %d,%d (%d)',
			p.x, p.y, nx, ny, D.riftSteps))
	end
	say('stepping out of the portal')
	D.walkTile(nx, ny, 0)
	API.RandomSleep2(400, 150, 250)
	return true
end
D.bossRiftsplitter = bossRiftsplitter
D.bossLogic.riftsplitter = bossRiftsplitter

--------------------------------------------------------------------
-- Plane-freezer Lakhrahnaz: switch to the bound magic weapon first
--------------------------------------------------------------------
-- The boss is heavily ranged, so the account keeps a magic loadout in a smuggler
-- bind and swaps to it before the fight:
--   1. home teleport        interface 1465/34, takes ~20 s
--   2. open the binds       smuggler, InteractNPC_route3 (third option)
--   3. pick the bind        interface 116/9 (1st), /13 (2nd), /17 (3rd)
-- Bind 2 is the magic one on this account, hence D.PF_BIND = 13.
-- A home teleport cannot be cast in combat, so if we are already fighting (or the
-- boss room was entered by a double click) the swap is skipped and the fight runs
-- with whatever is equipped - trying to teleport out mid-fight just wastes passes.
D.PF_TELEPORT = { 0xffffffff, 0xffffffff, 1, 1465, 34, -1 }
D.PF_BIND_IFACE = 116
D.PF_BIND = { 9, 13, 17 }        -- 1st / 2nd / 3rd bind
D.PF_BIND_WANT = 2               -- the magic bind is the second one
D.PF_TELEPORT_MS = 15000         -- "start teleport home" animation
D.PF_BINDS_WAIT_MS = 5000        -- smuggler dialog needs to load
D.SMUGGLER_RANGE = 6             -- must be right next to it; further only earns "can't reach that"

-- The swap itself, shared by every boss that wants a different bind before the
-- fight. `st` is that boss's own state table so two bosses on one run cannot share a
-- half-finished step.
function D.bossBindSwap(boss, st, tag, world, px, py)
	st = st or {}
	if st.done then return false end
	-- LocalPlayer_IsInCombat_ is the engine's own answer and is enough: while it is
	-- true the teleport will not cast. Waiting for a combat TARGET as well was wrong -
	-- the target varclient can still read 0 while the boss is already swinging.
	if engineInCombat() then
		st.done = true
		log(tag .. ': already in combat - no home teleport, fighting with what we have')
		return false
	end
	if not st.step then
		st.step = 1
		log(string.format('%s: swapping to bind %d before the fight', tag, D.PF_BIND_WANT))
	end

	if st.step == 1 then
		say('teleporting home to swap weapons')
		local t = D.PF_TELEPORT
		API.DoAction_Interface(t[1], t[2], t[3], t[4], t[5], t[6], API.OFF_ACT_GeneralInterface_route)
		log(tag .. ': home teleport started - waiting for it to land')
		API.RandomSleep2(D.PF_TELEPORT_MS, 1200, 2000)
		if engineInCombat() then
			st.done = true
			log(tag .. ': got a combat target during the teleport - aborting the swap')
			return false
		end
		st.step = 2
		return true

	elseif st.step == 2 then
		say('opening the smuggler binds')
		API.DoAction_NPC(D.ACT_TALK, API.OFF_ACT_InteractNPC_route3, { D.SMUGGLER }, D.SMUGGLER_RANGE)
		log(string.format('%s: smuggler %d bind interface (third option)', tag, D.SMUGGLER))
		API.RandomSleep2(D.PF_BINDS_WAIT_MS, 800, 1200)
		st.step = 3
		return true

	elseif st.step == 3 then
		local comp = D.PF_BIND[D.PF_BIND_WANT]
		say('selecting the magic bind')
		API.DoAction_Interface(0x2e, 0xffffffff, 1, D.PF_BIND_IFACE, comp, -1,
			API.OFF_ACT_GeneralInterface_route)
		log(string.format('%s: picked bind %d (interface %d/%d)',
			tag, D.PF_BIND_WANT, D.PF_BIND_IFACE, comp))
		API.RandomSleep2(1500, 400, 700)
		st.step = nil
		st.done = true
		log(tag .. ': weapon swapped - heading back to the boss')
		return true
	end
	return false
end

function D.bossPlaneFreezer(boss, world, px, py)
	return D.bossBindSwap(boss, D.pfState, 'plane-freezer', world, px, py)
end
D.bossLogic.planefreezer = D.bossPlaneFreezer

-- Astea Frostweb is a spam fight - no positioning, no mechanic - but the account
-- binds a magic weapon second, and the same three steps put it on: home teleport,
-- smuggler, bind 2. After that the ordinary attack loop is all it needs.
function D.bossAstea(boss, world, px, py)
	return D.bossBindSwap(boss, D.afState, 'astea frostweb', world, px, py)
end
D.bossLogic.astea = D.bossAstea

-- The pre-fight swap hooks, keyed by boss name. The boss block calls one while it
-- reports "still working", so the fight cannot start with the wrong weapon.
D.BOSS_BIND_SWAP = {
	['plane-freezer lakhrahnaz'] = D.bossPlaneFreezer,
	['astea frostweb'] = D.bossAstea,
}

D.pfState = {}
D.afState = {}

--------------------------------------------------------------------
-- Night-gazer Khighorahk: keep the room lit, and step off the shadow
--------------------------------------------------------------------
-- MegaDungeon's NightGazer.java, mechanics only. Live in the client: four "Pillar of
-- light" props (id 49265, type 12 DECOR) stand at the corners of the arena, and an unlit
-- one offers exactly one option, "Light"; a lit one offers nothing. So the ACTION is the
-- state - unlit is "the record still answers to Light" - and no Bool1 guess is needed.
--
-- The java's order is the fight:
--   * boss playing the DANGEROUS animation -> move, do not swing
--   * more than two pillars unlit          -> light the nearest one (java: getCount() > 2)
--   * otherwise                            -> attack it, which is the ordinary room-clear branch
D.NG_PILLAR_ID    = 49265
D.NG_PILLAR_SET   = { [D.NG_PILLAR_ID] = true }
D.NG_PILLAR_NAME  = 'pillar of light'
D.NG_PILLAR_ACT   = 'Light'
D.NG_PILLAR_RANGE = 22          -- the arena is 14x14; the pillars stand on its corners
D.NG_LIGHT_ABOVE  = 2           -- java: MyObjects.getCount(UNLIGHT_COLLUM) > 2
-- ONE animation, checked in the client: 13428 is the dangerous one. The java lists four
-- (13426-13429), but those are the boss's whole attack cycle - dodging the other three
-- walks the player out of range for no reason.
D.NG_SPECIAL_ANIMS = { [13428] = true }
D.NG_STEP_RANGE   = 3           -- how far the step off the shadow is allowed to reach
D.NG_STEP_MS      = 400
D.NG_DODGE_MS     = 900         -- one step per walk, not one per pass, while the anim plays

-- The unlit pillars, nearest first. D.objScan is this pass's snapshot, so this costs one
-- walk over a list that already exists.
local function ngPillars(px, py)
	local out = {}
	for _, o in ipairs(D.objScan() or {}) do
		local id = tonumber(D.objGet(o, 'Id'))
		local name = string.lower(D.objName(o) or '')
		if D.NG_PILLAR_SET[id] or string.find(name, D.NG_PILLAR_NAME, 1, true) then
			local x, y = D.objTile(o)
			if x then
				x, y = math.floor(x), math.floor(y)
				local d = math.max(math.abs(x - px), math.abs(y - py))
				local act = D.objGet(o, 'Action')
				act = type(act) == 'string' and string.lower(act) or ''
				-- lit: not interactable any more, so no action text at all
				if d <= D.NG_PILLAR_RANGE and D.interactable(o)
					and string.find(act, 'light', 1, true) then
					out[#out + 1] = { o = o, x = x, y = y, d = d }
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

-- Step off the tile we are standing on. The room grid comes from D.localWorld, so a wall is
-- never a target; of the walkable tiles in range, the one furthest from the boss wins, with
-- a small preference for a short step so the player stays in range of it.
local function ngStepOff(world, px, py, bx, by)
	if not (world and world.walk) then return nil end
	local nx, ny, best = nil, nil, -math.huge
	for dx = -D.NG_STEP_RANGE, D.NG_STEP_RANGE do
		for dy = -D.NG_STEP_RANGE, D.NG_STEP_RANGE do
			local x, y = px + dx, py + dy
			if (dx ~= 0 or dy ~= 0) and world.walk[pkey(x, y)] then
				local score = 0
				if bx and by then score = math.abs(x - bx) + math.abs(y - by) end
				score = score - 0.25 * (math.abs(dx) + math.abs(dy))
				if score > best then best, nx, ny = score, x, y end
			end
		end
	end
	return nx, ny
end

local function bossNightGazer(boss, world, px, py)
	local bx, by = D.objTile(boss)
	if bx then bx, by = math.floor(bx), math.floor(by) end

	-- 1. THE DANGEROUS ANIMATION (13428, checked in the client) is the tell that something
	-- is coming down on the tile the player stands on; the answer is to not be on it.
	local anim = tonumber(D.objGet(boss, 'Anim')) or 0
	if anim ~= 0 then
		-- each distinct animation once per floor: the boss cycles through its whole attack
		-- set in a fight, and a line per change would bury the log
		D.ngAnimsSeen = D.ngAnimsSeen or {}
		if not D.ngAnimsSeen[anim] then
			D.ngAnimsSeen[anim] = true
			log(string.format('night-gazer: boss animation %d%s', anim,
				D.NG_SPECIAL_ANIMS[anim] and ' - DANGEROUS, stepping off' or ''))
		end
	end
	if D.NG_SPECIAL_ANIMS[anim] then
		local nx, ny = nil, nil
		local now = API.SystemTime()
		-- the animation plays for longer than a pass: one step per walk, not one per pass
		if (now - (D.ngDodgeAt or 0)) >= D.NG_DODGE_MS then
			nx, ny = ngStepOff(world, px, py, bx, by)
			if nx then D.ngDodgeAt = now end
		end
		if nx then
			D.ngDodges = (D.ngDodges or 0) + 1
			if D.ngDodges <= 3 or D.ngDodges % 20 == 0 then
				log(string.format('night-gazer: animation %d - stepping off %d,%d to %d,%d (%d)',
					anim, px, py, nx, ny, D.ngDodges))
			end
			say('stepping out of the shadow')
			D.walkTile(nx, ny, 0)
			API.RandomSleep2(D.NG_STEP_MS, 150, 250)
			return true
		end
	end

	-- 2. THE ROOM GOES DARK. One or two pillars out is not worth leaving the boss for - the
	-- java only relights once more than two are out.
	local unlit = ngPillars(px, py)
	if #unlit > D.NG_LIGHT_ABOVE then
		local p = unlit[1]
		D.ngLights = (D.ngLights or 0) + 1
		if D.ngLights <= 3 or D.ngLights % 10 == 0 then
			log(string.format('night-gazer: %d pillars unlit - lighting the one at %d,%d (%d)',
				#unlit, p.x, p.y, D.ngLights))
		end
		say('lighting the pillars')
		D.clickObject(D.NG_PILLAR_ACT, p.o)
		API.RandomSleep2(600, 200, 300)
		return true
	end

	-- 3. Lit enough: nothing to do here, and the room-clear branch swings at it.
	return false
end
D.bossLogic.nightgazer = bossNightGazer

--------------------------------------------------------------------
-- Shadow-Forger Ihlakhizan: stand behind a pillar while it glows
--------------------------------------------------------------------
-- MegaDungeon's Shadow.java, mechanics only. Live in the client:
--   * the boss is "Shadow-Forger Ihlakhizan" (id 10143 at level 91), size 4, hanging over
--     the pit in the middle of its arena;
--   * four TYPE-0 objects, id 51110, name "Pillar", stand on the pit's corners (live:
--     10741,693 / 10741,698 / 10746,693 / 10746,698 around a boss at 10744,696). They have
--     NO action at all - hiding is a WALK to a tile beside one, never an object click;
--   * the java's special animation is 13030. That id comes from the same generation as the
--     night-gazer's 13426-13429, which the live client still answers, so it is the first
--     candidate; the log below prints every animation the fight plays, which is what will
--     confirm or correct it without another code change.
--
-- The java has the SHAPE right: attack unless the boss is playing the special, and spend the
-- special behind a pillar. It gets the position and the return wrong: getNearstTile() can
-- pick the BOSS side of the pillar (no cover at all), and nothing ever walks back out - which
-- is exactly how the wiki says the shadow claw finds you. Here the hide tile is the FAR side
-- of the pillar from the boss, and leaving is its own step.
--
-- Off the wiki: Protect from Magic does NOT stop the orange beam (unclassified damage), so
-- PROTECT FROM MELEE is the prayer for a melee-range fight. The green acid is a separate,
-- dodgeable attack and is not handled here.
D.SF_PRAYER       = 'Protect from Melee'
D.SF_PILLAR_IDS   = { [51110] = true }
D.SF_PILLAR_NAME  = 'pillar'        -- live object name, compared exactly
D.SF_PILLAR_RANGE = 18              -- the arena is 14x14; the corners are well inside this
D.SF_SPECIAL_ANIM = 13030           -- Shadow.java: SpeicalAttack
D.SF_GLOW_MS      = 2500            -- how long a chat "glow" line starts a hide
D.SF_HOLD_MIN_MS  = 1000            -- stay behind cover at least this long, charging or not
D.SF_HIDE_MS      = 6000            -- hard cap: past the burst the shadow claw is the risk
D.SF_STEP_MS      = 400
D.SF_WALK_RANGE   = 10              -- a hide tile farther than this cannot be reached in time
D.SF_STEP_SEARCH  = 6               -- no pillar in reach: how far the step-away may look
-- THE ARENA TEST. The dispatcher sees the boss from ~12 tiles, which includes the corridor
-- OUTSIDE the boss door (live: player 10734,694, boss 10744,696). Hiding must not start out
-- there: the hide walk would click a tile through a shut door the door task is about to open.
-- The pillar square is 6x6 and the rim a fight is fought from is 4-5 from its centre; 7
-- keeps the doorway (8 from the boss on the live layout) out and the rim in.
D.SF_ARENA_R      = 7

-- Every Pillar in reach of the boss and the player, nearest player first.
local function sfPillars(px, py, bx, by)
	local out = {}
	for _, o in ipairs(D.objScan() or {}) do
		local id = tonumber(D.objGet(o, 'Id'))
		local nm = string.lower(D.objName(o) or '')
		if D.SF_PILLAR_IDS[id] or nm == D.SF_PILLAR_NAME then
			local x, y = D.objTile(o)
			if x then
				x, y = math.floor(x), math.floor(y)
				local d = math.max(math.abs(x - px), math.abs(y - py))
				local db = math.max(math.abs(x - bx), math.abs(y - by))
				if d <= D.SF_PILLAR_RANGE and db <= D.SF_PILLAR_RANGE then
					out[#out + 1] = { o = o, x = x, y = y, d = d, db = db }
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

-- HUG THE PILLAR. A candidate is one of the eight tiles directly beside it, walkable, and on
-- the continuation of the boss->pillar ray (dot > 0), i.e. the pillar stands between it and
-- the boss. Of those, the one farthest along the ray wins (the outward diagonal on a corner
-- pillar); the tie-break is the shorter walk. Distance 2 was a full tile of exposed floor
-- between the player and the pillar - the flash caught the edge of it.
local function sfHideSpot(world, pillars, bx, by, px, py)
	if not (world and world.walk) then return nil end
	local best, bestScore = nil, -math.huge
	for _, p in ipairs(pillars) do
		local vx, vy = p.x - bx, p.y - by
		if vx ~= 0 or vy ~= 0 then
			for dx = -1, 1 do
				for dy = -1, 1 do
					local x, y = p.x + dx, p.y + dy
					if (dx ~= 0 or dy ~= 0) and world.walk[pkey(x, y)] then
						local dot = dx * vx + dy * vy
						if dot > 0 then
							local dPlayer = math.max(math.abs(x - px), math.abs(y - py))
							if dPlayer <= D.SF_WALK_RANGE then
								local score = dot * 10 - dPlayer
								if score > bestScore then
									bestScore, best = score, { x = x, y = y, px = p.x, py = p.y }
								end
							end
						end
					end
				end
			end
		end
	end
	return best
end

-- NO PILLAR IN REACH. The java stands still here; stepping off the tile is the only part of
-- "hide" that is left, so take the farthest walkable tile within a short step and hold the
-- pass instead of swinging through the flash.
local function sfStepOff(world, bx, by, px, py)
	if not (world and world.walk) then return nil end
	local nx, ny, best = nil, nil, -math.huge
	for dx = -D.SF_STEP_SEARCH, D.SF_STEP_SEARCH do
		for dy = -D.SF_STEP_SEARCH, D.SF_STEP_SEARCH do
			local x, y = px + dx, py + dy
			if (dx ~= 0 or dy ~= 0) and world.walk[pkey(x, y)] then
				local score = math.abs(x - bx) + math.abs(y - by)
					- 0.25 * (math.abs(dx) + math.abs(dy))
				if score > best then best, nx, ny = score, x, y end
			end
		end
	end
	return nx, ny
end

local function bossShadowForger(boss, world, px, py)
	local bt = boss.Tile_XYZ
	local bx, by = math.floor(bt.x), math.floor(bt.y)

	-- 0. IN THE ARENA, NOT AT ITS DOOR (see D.SF_ARENA_R). Out here the fight has not
	-- started: the doorway task still owns the pass.
	if math.max(math.abs(px - bx), math.abs(py - by)) > D.SF_ARENA_R then return false end

	-- 1. THE PRAYER. D.bossPrayerStep presses it on the walk in; this is the same retry for
	-- the passes where that gate missed the room.
	if D.ensurePrayerAbility then
		local roomKey = 'shadow'
		if D.roomCellAt then
			local _, _, pi, pj = D.roomCellAt(px, py)
			if pi then roomKey = pi .. ':' .. pj end
		end
		D.ensurePrayerAbility(D.SF_PRAYER, roomKey)
	end

	local now = API.SystemTime()
	local anim = tonumber(D.objGet(boss, 'Anim')) or 0
	-- one line per distinct animation per floor: the fight cycles through its attacks and a
	-- line per change would bury the log
	D.sfAnims = D.sfAnims or {}
	if anim ~= 0 and not D.sfAnims[anim] then
		D.sfAnims[anim] = true
		log(string.format('shadow-forger: boss animation %d%s', anim,
			anim == D.SF_SPECIAL_ANIM and ' - CHARGING, hide behind a pillar' or ''))
	end

	local charging = (anim == D.SF_SPECIAL_ANIM)
	local said = chat.shadowGlowAt and (now - chat.shadowGlowAt) < D.SF_GLOW_MS
	local glow = charging or said

	-- 2. ALREADY HIDING. THE CHAT LINE STARTS THE HIDE; THE HOLD FOLLOWS THE ANIMATION.
	-- Using the chat window for both kept the player behind the pillar after the burst had
	-- already landed: the line is stamped at the start and its window outlives the charge.
	-- One second of minimum cover rides out a single missed animation frame; the cap rides
	-- out a stuck one.
	if D.sfHide then
		local held = now - D.sfHide.at
		if (charging or held < D.SF_HOLD_MIN_MS) and held < D.SF_HIDE_MS then
			if (px ~= D.sfHide.x or py ~= D.sfHide.y)
				and (now - (D.sfHide.walkAt or 0)) >= 900 then
				-- a knockback or a cancelled walk leaves the player in the open; re-send
				-- the hide tile (D.walkTile's own retry cap stops a hopeless click)
				D.sfHide.walkAt = now
				D.walkTile(D.sfHide.x, D.sfHide.y, 0)
			end
			return true
		end
		local why = (held >= D.SF_HIDE_MS) and 'the hide cap' or 'the special ended'
		log(string.format('shadow-forger: leaving cover at %d,%d (%s, %d ms)',
			D.sfHide.x, D.sfHide.y, why, held))
		D.sfHide = nil
		-- no re-hide until this special is over: a cap exit with 13030 still playing would
		-- otherwise walk straight back into the same pillar for a second full window
		D.sfArmed = false
		return false
	end

	-- 3. RE-ARM once the special AND its chat window are over; the next one is worth hiding
	-- from again. Re-arming on the animation alone let a chat line that outlived the burst
	-- start a second hide right after the first one left cover.
	if D.sfArmed == false and not glow then D.sfArmed = true end
	if not glow or D.sfArmed == false then return false end

	-- 4. GO BEHIND A PILLAR. The far side, not the nearest tile.
	local pillars = sfPillars(px, py, bx, by)
	local spot = sfHideSpot(world, pillars, bx, by, px, py)
	if not spot then
		local nx, ny = sfStepOff(world, bx, by, px, py)
		D.sfNoCover = (D.sfNoCover or 0) + 1
		local told = D.sfNoCover <= 3 or D.sfNoCover % 20 == 0
		if nx then
			if told then
				log(string.format('shadow-forger: animation %d but no pillar cover from %d,%d (%d pillars) - stepping off to %d,%d',
					anim, px, py, #pillars, nx, ny))
			end
			D.sfHide = { x = nx, y = ny, at = now, walkAt = now }
			say('stepping away from the flash')
			D.walkTile(nx, ny, 0)
			API.RandomSleep2(D.SF_STEP_MS, 150, 250)
			return true
		end
		if told then
			log(string.format('shadow-forger: animation %d but no pillar cover and nowhere to step from %d,%d - holding the pass',
				anim, px, py))
		end
		API.RandomSleep2(D.SF_STEP_MS, 150, 250)
		return true
	end
	D.sfHide = { x = spot.x, y = spot.y, at = now, walkAt = now, px = spot.px, py = spot.py }
	D.sfHides = (D.sfHides or 0) + 1
	if D.sfHides <= 3 or D.sfHides % 10 == 0 then
		log(string.format('shadow-forger: animation %d - hiding behind the pillar at %d,%d (stand %d,%d, %d)',
			anim, spot.px, spot.py, spot.x, spot.y, D.sfHides))
	end
	say('hiding behind the pillar')
	D.walkTile(spot.x, spot.y, 0)
	API.RandomSleep2(D.SF_STEP_MS, 150, 250)
	return true
end
D.bossLogic.shadowforger = bossShadowForger

--------------------------------------------------------------------
-- the boss pass the main loop asks for before the room-clear branch
--------------------------------------------------------------------
-- A Daemonheim boss is not "a monster in the room". The main loop asks this first: find the
-- boss standing in our own room and let its strategy take the pass. True = the strategy
-- acted (a pillar lit, a step off the shadow) and the ordinary attack must not fire on the
-- same tick; false = nothing to do, and the room-clear branch swings at it as usual.
--
-- Only D.BOSS_INFIGHT strategies are dispatched. The pre-fight weapon swap (astea,
-- plane-freezer) is not one of them: it belongs to the moment before the first swing, and
-- calling it from here would start a home teleport in the middle of a fight.
-- Stomp IS one: the crystal phases ARE the fight, and the strategy answers false when
-- there is nothing left to fix, so the ordinary attack branch still owns those passes.
-- The Skeletal Horde IS one for the opposite reason: the room is keyed on the Divine
-- skinweaver, which must never be attacked, and only the strategy knows to block its
-- tunnels and to attack the skeletons it points at instead.
-- Shadow-Forger IS one: the flash is the fight - a pass spent swinging through it is a
-- stat drain, and only the strategy knows which side of a pillar is cover.
-- A boss is bigger than a tile, and its reported tile can sit a couple of tiles outside
-- the box the PLAYER's room is measured in; the room blob can also be missing entirely
-- while a fight is on. Either one dropped the whole strategy: live, Stomp stood in his own
-- room with the crystal phase running and every pass went to the attack branch ("Stomp is
-- currently invulnerable!") because the room test said no. The room test is asked with
-- slack now, and plain distance to the player is the fallback - a Daemonheim boss fight is
-- a room-sized event and no other room puts a boss within 12 tiles of the player.
D.BOSS_NEAR = 12
D.BOSS_ROOM_SLACK = 3
D.BOSS_INFIGHT = { nightgazer = true, stomp = true, skeletalhorde = true,
	shadowforger = true }

-- IS THE PLAYER STANDING IN A LIVE BOSS'S OWN ROOM? Dung.lua's door task asks this before it
-- clicks anything: a doorway click WALKS THE PLAYER THROUGH the doorway, and the way out of
-- the boss room is the last thing a fight needs (live: the door task fired mid-phase and the
-- bot walked out to the front of the room and left Stomp standing in it). Only the player's
-- own room counts - a boss seen through the closed door of the NEXT room must not stop the
-- passage being opened, or the arena could never be entered at all.
D.BOSS_HOT_MS = 4000
function D.bossArenaHot(px, py)
	local bl = D.bossLive
	if not bl then return false end
	if (API.SystemTime() - (tonumber(D.bossLiveAt) or 0)) >= D.BOSS_HOT_MS then return false end
	-- THE BOSS'S OWN ROOM, when the Stomp pass has already worked it out: exact, and it
	-- cannot mistake the corridor outside a shut door for the arena the way a radius can
	local r = D.stompArenaRoom
	if r and r.set then return r.set[pkey(px, py)] == true end
	local bx, by = D.objTile(bl)
	if not bx then return false end
	-- the shadow-forger's arena is the pillar square plus its rim: the fight is fought
	-- from up to D.SF_ARENA_R away, and the door task must stay down for all of it
	local logic = D.bossLiveLogic and D.BOSSES[D.bossLiveLogic]
	local near = (logic == 'shadowforger') and D.SF_ARENA_R or 5
	return math.max(math.abs(math.floor(bx) - px), math.abs(math.floor(by) - py)) <= near
end

function D.bossStrategyStep(world, here, px, py)
	local boss, key, bestD = nil, nil, math.huge
	for _, n in ipairs(D.npcScan() or {}) do
		local k = D.bossKey(n.Name)
		local logic = D.BOSSES[k]
		-- NOTHING IS ASKED OF HIS LIFE POINTS. Live, 20:24:42: a Charge click landed, and
		-- from that pass on the boss answered Life = 0 while he stood over the lodestones -
		-- the "> 1" test dropped him from the list, the 3 s memory ran out, and the fight
		-- was unattended for the next twelve seconds. A dead boss leaves the npc list and the
		-- end ladder ends the floor, so the name and the room are proof enough.
		if logic and D.BOSS_INFIGHT[logic] then
			local bx, by = D.objTile(n)
			local d = math.huge
			if bx then
				d = math.max(math.abs(math.floor(bx) - px), math.abs(math.floor(by) - py))
			end
			if bx and (d <= D.BOSS_NEAR or D.tileInHere(here, bx, by, D.BOSS_ROOM_SLACK)) then
				-- THE HORDE IS DISPATCHED BY ROOM, NOT BY RADIUS. Its arena is one layout
				-- cell and the Divine skinweaver stands inside it, so the 12-tile radius also
				-- reaches it through a shut boss door and from the corridor outside - and a
				-- dispatched boss is a hot arena (D.bossArenaHot), which stands the doorway
				-- task down and leaves the bot waiting at a door it will not open.
				local seen = true
				if logic == 'skeletalhorde' then
					seen = hordeInArena(px, py, math.floor(bx), math.floor(by))
				end
				if seen and d < bestD then boss, key, bestD = n, k, d end
			end
		end
	end
	if not boss then
		-- ONE MISSED SCAN IS NOT THE FIGHT ENDING. The npc sweep is cached for 700 ms and
		-- the client hands back a list with a multi-tile boss missing from it every so often
		-- (the same transient that loses the lodestones for a pass). Standing down there is
		-- how the pass fell through to the food branch and the player walked out of the
		-- arena mid-phase (live 20:16:02 -> 20:16:04: "walking to the lodestone", then
		-- "taking food at 9731,1049 from 9735,1054" two rooms away). Keep the last TILE for
		-- a moment - plain numbers, never the engine record, which the next scan frees - and
		-- hand the strategy a stand-in. A boss that is really dead stops answering Life > 1
		-- long before this three second window is up.
		local last = D.bossLastLive
		local nowMs = API.SystemTime()
		if last and last.x and (nowMs - (last.at or 0)) < 3000 then
			boss = { Tile_XYZ = { x = last.x, y = last.y, z = 0 }, Name = last.name }
			key, bestD = last.key, last.d or 0
		else
			D.bossLive = nil
			return false
		end
	else
		local bx, by = D.objTile(boss)
		D.bossLastLive = {
			key = key, d = bestD, at = API.SystemTime(),
			x = bx and math.floor(bx) or nil, y = by and math.floor(by) or nil,
			name = tostring(D.objName(boss)),
		}
	end
	local fn = D.bossLogic[D.BOSSES[key]]
	if not fn then return false end
	-- the arena is STOMP's own bookkeeping: leaving it set while another boss fights would
	-- have D.bossArenaHot answer for the wrong room
	if key ~= 'stomp' then D.stompArena, D.stompArenaRoom = nil, nil end
	-- the combat-room box this pass built: the strategies aim walks inside it, so a pace
	-- click cannot end up in the corridor two rooms away
	D.bossHere = here
	-- the window reads these two: which boss is in sight, and which strategy owns it
	D.bossLive, D.bossLiveLogic = boss, key
	D.bossLiveAt = API.SystemTime()
	-- ONE line the first time a strategy actually runs for a boss, per script run. The
	-- boss pass being skipped altogether is invisible otherwise: live, a Stomp fight ran
	-- to a full invulnerable cycle with no "stomp:" line anywhere and no way to tell
	-- "never dispatched" from "dispatched and unimpressed". This says which.
	if D.bossDispatchLogged ~= key then
		D.bossDispatchLogged = key
		log(string.format('boss: %s (%s) in sight at %d tiles - strategy running',
			tostring(D.objName(boss)), tostring(key), math.floor(bestD)))
	end
	return fn(boss, world, px, py) and true or false
end

	------------------------------------------------------------------
	-- exports: what Dung.lua may call
	------------------------------------------------------------------
	X.findBoss, X.bossAttack, X.bossGluttonous, X.findLadder = findBoss, bossAttack, bossGluttonous, findLadder
	X.bossSkeletalHorde, X.stompLodestone, X.stompWants, X.stompDebris = bossSkeletalHorde, stompLodestone, stompWants, stompDebris
	X.bossStomp = bossStomp

	return bind
end
