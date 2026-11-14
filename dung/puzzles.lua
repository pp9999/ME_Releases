-- puzzles.lua - the Daemonheim puzzle rooms.
--
-- Split out of Dung.lua, which keeps the main loop, the click/action helpers, the
-- map and route search and the boss strategies (bosses.lua). Every
-- room puzzle the script can solve lives here, one section per puzzle, plus the
-- shared "this room's puzzle is done" bookkeeping the solvers agree on.
--
-- Dung.lua installs it once, after the helpers it hands over are in scope:
--
--   local bindPuzzles = require("puzzles")(D, API, S, H, X)
--   ...
--   bindPuzzles()        -- second pass, after every module is installed
--
--   D    the shared script table: all state, and every D.* entry point
--   API  the engine wrapper
--   S    dung_state, the per-floor state that outlives a rescan
--   H    helpers that stay in Dung.lua (log/say/ptile/pkey, click + action helpers)
--   X    the table the three sub-modules share their functions through
--
-- The pathing helpers used here are forward-declared and filled in by bind(): the
-- two files call each other, so nothing can be bound while the other is loading.
--
-- The body below is the original code, moved byte for byte. Do not reformat it: the
-- line comments describe what was observed live, not how this file is laid out.

return function(D, API, S, H, X)
	------------------------------------------------------------------
	-- helpers that stay in Dung.lua
	------------------------------------------------------------------
	local attack, chat, clearReach, code, countKeys, dkey,
		doorKeyFromName, drainChat, engineInCombat, entityReachable, foodInRoom, hasKeyFor,
		heldKeys, inCombat, isMoving, keysInRoom, liveEnemies, log,
		pairKey, pkey, ptile, readKeyVar, rkey, say,
		settle, waitStill, warn =
		H.attack, H.chat, H.clearReach, H.code, H.countKeys, H.dkey,
		H.doorKeyFromName, H.drainChat, H.engineInCombat, H.entityReachable, H.foodInRoom, H.hasKeyFor,
		H.heldKeys, H.inCombat, H.isMoving, H.keysInRoom, H.liveEnemies, H.log,
		H.pairKey, H.pkey, H.ptile, H.readKeyVar, H.rkey, H.say,
		H.settle, H.waitStill, H.warn

	------------------------------------------------------------------
	-- pathing.lua functions used here - bound by bind(), see the header
	------------------------------------------------------------------
	local crossedDoorway, doorClickable, doorInRoom, doorLeadsToWork, doorNoKey, doorSide, doorwayOpen,
		enterLeaf, markDoorway, openDoor, roomNearRooms
	local function bind()
		crossedDoorway = X.crossedDoorway
		doorClickable = X.doorClickable
		doorInRoom = X.doorInRoom
		doorLeadsToWork = X.doorLeadsToWork
		doorNoKey = X.doorNoKey
		doorSide = X.doorSide
		doorwayOpen = X.doorwayOpen
		enterLeaf = X.enterLeaf
		markDoorway = X.markDoorway
		openDoor = X.openDoor
		roomNearRooms = X.roomNearRooms
	end

--------------------------------------------------------------------
-- puzzles: Pondskaters (ported from ShadowDungeon's Pondskaters.java)
--------------------------------------------------------------------

-- Pondskaters dart across the room and are caught one at a time. The java script
-- picks the one whose animation is CATCHABLE_ANIM and clicks "Catch" on it; that
-- is exactly the rule used here - a resting skater cannot be caught, so clicking
-- it only wastes a click.
D.CATCHABLE_ANIM = 14405
D.CATCH_CODE = 0x29   -- default NPC option, the same opcode "Talk-to" uses

-- Pondskaters standing in OUR room, nearest first. They are NOT in liveEnemies:
-- their option is "Catch", not "Attack", so they never look like combat.
--
-- Matched by the ids the java Constants carry - 12089, 12091, 12092, 12093 - with
-- the name as a fallback. Those ids were verified live and are stable; the name is
-- only there so a variant model cannot make the whole puzzle invisible.
--
-- They float on the pond, so their tiles are never part of the room's walk set -
-- membership is judged on the room's bounds instead. The player must also be in
-- that room: a skater visible from the doorway of the next room is not catchable,
-- and chasing it made the bot leave a room it was working in.
D.POND_ROOM_SLACK = 3   -- the pond can sit a little outside the walkable bbox
D.POND_CATCH_RANGE = 12 -- tiles; skaters drift around, the shore sits a few back

D.PONDSKATER_IDS = { 12089, 12091, 12092, 12093 }
D.PONDSKATER_SET = {}
for i = 1, #D.PONDSKATER_IDS do D.PONDSKATER_SET[D.PONDSKATER_IDS[i]] = true end

local function isPondskater(n)
	return D.PONDSKATER_SET[n.Id] == true
		or string.find(string.lower(n.Name or ''), 'pondskater', 1, true) ~= nil
end

local function pondskaters(here, px, py)
	local out = {}
	if not here then return out end
	local player = FFPOINT.new(px, py, 0)
	for _, n in ipairs(D.npcScan()) do
		if isPondskater(n) then
			local t = n.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			local inside = x >= here.minx - D.POND_ROOM_SLACK and x <= here.maxx + D.POND_ROOM_SLACK
				and y >= here.miny - D.POND_ROOM_SLACK and y <= here.maxy + D.POND_ROOM_SLACK
			if inside then
				local d = API.Math_Distance(player, FFPOINT.new(x, y, 0))
				if d and d <= D.POND_CATCH_RANGE then
					out[#out + 1] = { npc = n, d = d }
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	local npcs = {}
	for i = 1, #out do npcs[i] = out[i].npc end
	return npcs
end

-- One step of the puzzle: catch the catchable skater. Returns true when a click
-- was dispatched, so the caller knows the floor logic must wait for it.
--
-- No reachability gate here: pondskaters float on water, so their own tile is never
-- walkable and a reachability test would always fail. The client walks to the
-- nearest shore tile on its own when the skater is clicked.
--
-- Only the skater playing CATCHABLE_ANIM can be caught - this is the java rule
-- (getKeyNpc) and it is the one that works. When none is surfacing the original
-- simply waits, so this waits too and logs the animations it does see.
-- A pondskater that was caught hands over the room's key, and the skaters stay on
-- the pond afterwards - one of them often gets stuck and never animates again. So
-- the puzzle is finished when a NEW key lands in the ring (its varclient), not when the
-- pond is empty, and waiting for another surfacing has a limit.
D.POND_QUIET_LIMIT = 20    -- polls with nothing surfacing before moving on
D.POND_CENTRE_RANGE = 16   -- tiles from the room's middle point

local function pondReset()
	S.pondState = {}
end

-- Mark a room's puzzle finished, whatever the evidence was (chat message or the
-- skaters actually clearing). Solved rooms stop being walked back into.
local function puzzleMarkSolved(r, why)
	local key = rkey(r)
	local st = S.pondState[key] or { caught = 0, solved = false }
	S.pondState[key] = st
	if st.solved then return end
	st.solved = true
	if why then
		say('puzzle solved')
		log(string.format('puzzle in room %s solved (%s)', key, tostring(why)))
	end
end

-- S.pondState is keyed by ROOM and shared by every puzzle solver, so each solver may
-- only read state it owns. A lever room's table has no `caught`/`quiet` fields, and
-- reading them as numbers crashed this function with "attempt to compare number with
-- nil" the moment the lever solver had claimed the room.
local function puzzleOwn(key, kind)
	local st = S.pondState[key]
	if not st then return nil end
	if st.kind and st.kind ~= kind then return nil end
	return st
end

-- The same, but creating the table and filling in the solver's numeric defaults.
-- Returns nil when another puzzle owns the room.
local function puzzleClaim(key, kind, defaults)
	local st = S.pondState[key]
	if st and st.kind and st.kind ~= kind then return nil end
	st = st or {}
	st.kind = kind
	for k, v in pairs(defaults or {}) do
		if st[k] == nil then st[k] = v end
	end
	S.pondState[key] = st
	return st
end

local function solvePondskaters(here, px, py)
	local key = rkey(here)
	local st = puzzleOwn(key, 'pondskaters')
	if st and st.solved then return false end

	-- The puzzle only exists inside the pond room, so the player has to be in it.
	-- Judged from the room's middle point: standing in the doorway of the next
	-- room put skaters "in range" of a straight line and the bot walked off to
	-- chase them instead of finishing the room it was in.
	local dCentre = API.Math_Distance(
		FFPOINT.new(px, py, 0), FFPOINT.new(here.cx or here.minx, here.cy or here.miny, 0))
	if dCentre and dCentre > D.POND_CENTRE_RANGE then
		return false
	end

	local list = pondskaters(here, px, py)
	if #list == 0 then
		-- nothing here and never was: not a pond room, stay quiet
		if not st then return false end
		-- An empty skater list is NOT proof of success: the pondskaters stay on
		-- the pond after the puzzle is done, so the room can hold them forever.
		-- Only chat ("you have solved the puzzle") or having caught some counts.
		if not st.solved then
			if (st.caught or 0) > 0 then
				st.solved = true
				say('pondskater puzzle solved')
				log(string.format('pondskater puzzle complete after %d catch(es)', st.caught))
			elseif not st.quieted then
				st.quieted = true
				log('pondskaters gone before any catch - leaving the state to chat')
			end
		end
		return false
	end

	st = puzzleClaim(key, 'pondskaters', { caught = 0, solved = false, quiet = 0 })
	if not st then return false end
	-- The moment a catch turns into a key in the ring, the puzzle is done. This is
	-- only checked in a room that HAS skaters: with the check before the skater
	-- list it fired for every room the bot walked through, because any key picked
	-- up elsewhere raised the count above the base recorded on entry (the log was
	-- full of "puzzle in room X solved (a key was recovered (1 -> 2))").
	local heldNow = heldKeys()
	local keyCount = countKeys(heldNow)
	if st.keyBase == nil then
		st.keyBase = keyCount
	elseif keyCount > st.keyBase then
		puzzleMarkSolved(here, string.format('a key was recovered (%d -> %d)', st.keyBase, keyCount))
		return false
	end
	-- the count dropping means a catch landed
	if st.last and #list < st.last then
		st.caught = (st.caught or 0) + (st.last - #list)
		st.quiet = 0
	end
	st.last = #list

	-- Only the skater playing CATCHABLE_ANIM can be caught - this is the java
	-- rule (getKeyNpc) and it is the one that works: clicking a resting skater
	-- does nothing at all. While none is surfacing the bot WAITS here rather than
	-- handing the loop back, or the door logic walks off and the puzzle is
	-- abandoned. A skater can also get stuck and never animate again, so the wait
	-- is bounded - after POND_QUIET_LIMIT quiet polls the room is finished.
	local target = nil
	for _, n in ipairs(list) do
		if (n.Anim or 0) == D.CATCHABLE_ANIM then target = n break end
	end
	if not target then
		local anims = {}
		for _, n in ipairs(list) do anims[#anims + 1] = tostring(n.Anim) end
		st.quiet = (st.quiet or 0) + 1
		if st.quiet >= D.POND_QUIET_LIMIT then
			puzzleMarkSolved(here, string.format(
				'no skater surfaced in %d polls (anims %s)', st.quiet, table.concat(anims, ',')))
			return false
		end
		say(string.format('waiting for a pondskater to surface (%s)', table.concat(anims, ',')))
		log(string.format('waiting to catch: %d skater(s), anims %s, want %d (%d/%d)',
			#list, table.concat(anims, ','), D.CATCHABLE_ANIM, st.quiet, D.POND_QUIET_LIMIT))
		API.RandomSleep2(400, 200, 300)
		return true
	end

	st.quiet = 0
	say(string.format('catching a pondskater (%d left)', #list))
	log(string.format('catching pondskater id %d uid %s anim %d at %d,%d',
		target.Id, tostring(target.Unique_Id), target.Anim,
		math.floor(target.Tile_XYZ.x), math.floor(target.Tile_XYZ.y)))
	API.DoAction_NPC(D.CATCH_CODE, D.ROUTE_TALK, { target.Id }, 50)
	API.RandomSleep2(900, 300, 500)
	return true
end

-- A room whose puzzle is finished must not keep looking like unexplored work.
local function puzzleDone(r)
	local st = S.pondState[rkey(r)]
	return st ~= nil and st.solved == true
end

--------------------------------------------------------------------
-- puzzles: the barrel puzzle (Barrel puzzle - Strength + Construction)
--------------------------------------------------------------------
-- Pushing IS the puzzle, and a push always moves a barrel ONE tile directly away
-- from the player: the player then stands on the tile the barrel left. That vacated
-- tile is what opens the way, which is why the barrels across the room's throat have
-- to be shoved sideways before anything behind them can be reached.
--
--   stage 1  barrels pushed aside until the broken barrel bits on the floor can be
--            reached and picked up (pushing needs Strength)
--   stage 2  the broken barrel in the middle of the room is repaired with those bits
--            (Construction); it becomes the barrel that gets filled
--   stage 3  that fixed barrel is pushed beside a live "expelling pipe", which fills
--            it ("dry pipes" do nothing, and the pipes change position, so it is
--            aimed again every pass), and then the FULL barrel is pushed onto the
--            room's pressure pad. That is what unlocks the room: live, the barrel sat
--            full beside the pipe for ever and only the pad finished it - and the
--            moment it did, every pushable barrel npc turned into a plain "Barrel"
--            OBJECT. A barrel room with no pushable barrels left is a solved room.
D.BARREL_KIND      = 'barrels'
D.BARREL_SLACK     = 3    -- barrels stand on the room's edge, so judge by bounds
D.BARREL_PUSH_MAX  = 80   -- pushes in one room before the door sweep gets it back
D.BARREL_REPEAT    = 3    -- identical pushes in a row before that push is written off
D.BARREL_STUCK_MS  = 25000
D.BARREL_REPAIRS   = 8    -- Fix clicks before the broken barrel is left alone
D.BARREL_REPAIR_AFTER = 12 -- pushes after which Fix is tried even with no bits seen
D.BARREL_FILL_WAIT = 25   -- polls beside the pipe with the room still shut
D.BARREL_PIPE_WAITS = 15  -- polls waiting for an expelling pipe to appear
D.BARREL_PUSH_WAIT = 3000 -- a push: animation, the slide, the step into the freed tile
D.BARREL_ANIM_WAIT = 2500 -- wait for the push animation to APPEAR (it starts a tick later)
D.BARREL_STEP_WAIT = 2500 -- walking into the pushing side before the click
D.BARREL_REVERSE_MS = 12000 -- a push is never undone straight away
D.BARREL_SETTLE_MS = 6000  -- how long the scan may take to report the barrel's new tile
D.BARREL_BITS_BAD_MS = 30000 -- a bits pickup the client refused is not retried for this long
D.BARREL_STALLS    = 6    -- passes with no legal push in line with the pipe before the room is given back
D.BARREL_PAD_WAIT  = 20   -- polls with the filled barrel on the pressure pad before giving up
-- Live ids, as a fallback for a name or an option that has not loaded: 11072 is the
-- pushable barrel npc, 11075 the broken one ("Barrel" with the only option "Fix").
D.BARREL_IDS       = { [11072] = true }
D.BARREL_FIX_IDS   = { [11075] = true }
-- The repaired barrel is its own npc, and this id is how the fill stage is still
-- recognised after the room is re-segmented into a different key (a merged room
-- claims a key the repair was never recorded under, which silently skipped the fill).
D.BARREL_FIXED_IDS = { [11073] = true }
-- 17422 is "Broken barrel bits" (17423 is the noted form). It has to be matched by ID:
-- a ground item comes back from the scan with an EMPTY name, so the room's bits were
-- never recognised and the bot pushed barrels for ever instead of picking them up.
D.BARREL_BITS_IDS  = { 17422, 17423 }
D.BARREL_BITS_SET  = { [17422] = true, [17423] = true }

-- The broken barrel's own option. It is sometimes called just "Barrel", in which
-- case the repair option is the only thing that tells it apart from the pushable
-- ones - and the bits are the item, so "barrel bits" must never match as a barrel.
local function repairAction(a)
	a = a or ''
	if a == 'Repair' or a == 'Fix' or a == 'Repair-barrel' or a == 'Fix-barrel'
		or a == 'Rebuild' or a == 'Build' then
		return a
	end
	return nil
end

-- Is this thing a BARREL at all? The Repair option alone is nowhere near enough: the
-- collapsing room's "Collapsing strut" also offers Repair, and the barrel solver claimed
-- it as the broken barrel - "barrel puzzle in room 15702:1061: 0 barrel(s), broken
-- barrel 49611 at 15706,1062 Repair" - which wasted the room on nonsense pushes AND
-- blocked the rock room, because a room claimed by one puzzle cannot be claimed by
-- another. Barrels are matched by name and by the barrel id sets, nothing else.
local function looksBarrel(nm, id)
	if string.find(nm, 'barrel', 1, true) then return true end
	return (D.BARREL_FIX_IDS[id] or D.BARREL_FIXED_IDS[id] or D.BARREL_IDS[id]) and true or false
end

-- Everything the puzzle works with, from one snapshot and only inside the room we
-- stand in: the pushable barrels (npcs), the broken barrel bits on the floor, the
-- broken barrel itself, the live expelling pipe, and every pipe tile (live or dry -
-- the bank a barrel must never be pushed onto).
function D.barrelPieces(here)
	local out = { barrels = {}, bits = nil, broken = nil, pipe = nil, pipes = {} }
	if not here then return out end
	local function inside(x, y)
		return x >= here.minx - D.BARREL_SLACK and x <= here.maxx + D.BARREL_SLACK
			and y >= here.miny - D.BARREL_SLACK and y <= here.maxy + D.BARREL_SLACK
	end
	for _, n in ipairs(D.npcScan()) do
		-- Tile, option and id are read through the protected accessors: a barrel that is
		-- removed between the scan and this pass (the whole room turns into scenery when
		-- the puzzle is finished) leaves dead userdata, and `n.Action` then throws inside
		-- the engine instead of returning something.
		local tx, ty = D.objTile(n)
		local x, y = math.floor(tx or 0), math.floor(ty or 0)
		local nm = string.lower(D.objName(n))
		local nid = D.objGet(n, 'Id')
		local act = D.objGet(n, 'Action')
		if type(act) ~= 'string' then act = '' end
		if tx and ty and inside(x, y) then
			-- The broken barrel is an NPC too, and it is called plain "Barrel": only
			-- its option ("Fix") and its id tell it apart from the ones that are
			-- pushed. Missing that made the bot click Push on the one barrel that
			-- cannot be pushed. The id is only a fallback for a missing option: after
			-- the repair the same barrel becomes pushable, and then it must be pushed.
			local fix = looksBarrel(nm, nid) and repairAction(act) or nil
			if not fix and D.BARREL_FIX_IDS[nid] and act ~= 'Push' then
				fix = (act ~= '') and act or 'Fix'
			end
			if fix and not out.broken then
				out.broken = { npc = n, obj = n, id = nid, x = x, y = y, action = fix, npcFix = true }
			elseif not fix and string.find(nm, 'broken', 1, true) and not out.broken then
				out.broken = { npc = n, obj = n, id = nid, x = x, y = y, action = act, npcFix = true }
			elseif not fix and (string.find(nm, 'barrel', 1, true) or D.BARREL_IDS[nid]) then
				out.barrels[#out.barrels + 1] = {
					npc = n, id = nid, x = x, y = y,
					broken = string.find(nm, 'broken', 1, true) ~= nil,
					fixed = D.BARREL_FIXED_IDS[nid] or nil,
				}
			end
		end
	end
	for _, o in ipairs(D.objScan()) do
		local tx, ty = D.objTile(o)
		local x, y = math.floor(tx or 0), math.floor(ty or 0)
		local nm = string.lower(D.objName(o))
		local oid = D.objGet(o, 'Id')
		local otype = D.objGet(o, 'Type')
		local oact = D.objGet(o, 'Action')
		if type(oact) ~= 'string' then oact = '' end
		if tx and ty and inside(x, y) then
			if otype == 3 then
				if not out.bits and (D.BARREL_BITS_SET[oid]
					or string.find(nm, 'barrel bits', 1, true)) then
					out.bits = { obj = o, id = oid, x = x, y = y }
				end
			else
				local repair = looksBarrel(nm, oid) and repairAction(oact) or nil
				if string.find(nm, 'pipe', 1, true) then
					-- every pipe, live or dry: those tiles are the pipe bank, so a barrel
					-- must never be pushed onto one of them
					out.pipes[pkey(x, y)] = true
				end
				if not out.pad and (D.LEADER_PAD_SET[oid]
					or string.find(nm, 'pressure pad', 1, true)) then
					-- the room's answer: the FILLED barrel goes on this tile
					out.pad = { obj = o, id = oid, x = x, y = y }
				end
				if not out.broken and (repair or string.find(nm, 'broken barrel', 1, true)) then
					out.broken = { obj = o, id = oid, x = x, y = y, action = repair or oact }
				elseif not out.pipe and string.find(nm, 'expelling pipe', 1, true) then
					out.pipe = { obj = o, id = oid, x = x, y = y }
				end
			end
		end
	end
	return out
end

-- Which barrel is the FIXED one - the repaired barrel being filled? It is recorded
-- the moment the repair is dispatched, because afterwards it is just another barrel
-- npc and the ones blocking the throat look exactly the same. With no record (a
-- floor change remembered only half the room) the middle of the room is used, which
-- is where the broken barrel stands.
function D.barrelFixed(here, barrels, st)
	-- The repaired barrel says what it is: trust that over any remembered tile.
	for _, b in ipairs(barrels) do
		if b.fixed and not b.broken then return b end
	end
	local fx = (st and st.fixedX) or (here and here.cx)
	local fy = (st and st.fixedY) or (here and here.cy)
	if not fx or not fy then return nil end
	local best, bestD = nil, math.huge
	for _, b in ipairs(barrels) do
		if not b.broken then
			local d = math.abs(b.x - fx) + math.abs(b.y - fy)
			if d < bestD and d <= 3 then bestD, best = d, b end
		end
	end
	return best
end

-- WHERE the repaired barrel has to stand to be filled: DIRECTLY beside the live
-- pipe - same row or same column, one tile apart. Diagonally against the pipe is not
-- "beside": the pipe never fills that, and the old Chebyshev test counted it as in
-- place, so the solver polled its fill counter dry and wrote the room off.
-- The four tiles a pipe can face are filtered to real floor, and the side the barrel
-- is already on comes first: a push can never cross the pipe itself. The second
-- entry is the other side, kept as the retry for a pipe that only fills the tile it
-- actually faces.
function D.barrelFillSpots(world, pipe, bx, by, pipes)
	local out = {}
	if not (world and world.walk and pipe) then return out end
	for i = 1, 4 do
		local d = D.DIR4[i]
		local x, y = pipe.x + d[1], pipe.y + d[2]
		local k = pkey(x, y)
		-- floor only, and never a pipe tile: the barrel has to stand BESIDE the pipe
		-- bank, not on it
		if world.walk[k] and not (pipes and pipes[k]) and k ~= pkey(pipe.x, pipe.y) then
			local score = math.abs((x or 0) - bx) + math.abs((y or 0) - by)
			local behind = (d[1] == 1 and bx < pipe.x) or (d[1] == -1 and bx > pipe.x)
				or (d[2] == 1 and by < pipe.y) or (d[2] == -1 and by > pipe.y)
			if behind then score = score + 1000 end
			out[#out + 1] = { x = x, y = y, score = score }
		end
	end
	table.sort(out, function(a, b) return a.score < b.score end)
	return out
end

-- The pushing side has to be walkable WITHOUT crossing the barrel line. The shared
-- search (D.walkBfs) now treats barrel npcs as obstacles, so its distance map is the
-- answer - no second, differently-behaved search here.
--
-- One push, planned and made. `candidates` are the barrels we may push (all of them
-- in stage 1, only the fixed one in stage 3) and `all` supplies the occupancy, so two
-- barrels never plan into each other. `goal` is what the push is FOR:
--   { x =, y = } - close the barrel's distance to that tile (aiming at a pipe/bits)
--   nil          - clear the throat: shove a barrel away from where we stand
-- `noLand` is a set of tile keys a barrel may never be pushed ONTO (the pipe bank:
-- a barrel standing on a pipe is not beside it, and can never be pushed off again).
-- Returns true when the pass was spent (walking into place, or clicking).
function D.barrelPush(world, all, candidates, px, py, goal, st, noLand)
	local occupied = {}
	for _, b in ipairs(all) do occupied[pkey(b.x, b.y)] = true end
	local bfs = D.walkBfs(world)
	local best, bestScore = nil, nil
	for _, b in ipairs(candidates) do
		-- A barrel cannot be standing on the tile we are standing on: that record is
		-- the scan from before the last push, and planning against it is what pushed
		-- the same barrel straight back where it came from.
		if not b.broken and not (b.x == px and b.y == py) then
			for i = 1, 4 do
				local d = D.DIR4[i]
				local sx, sy = b.x - d[1], b.y - d[2]   -- where the push is made from
				local tx, ty = b.x + d[1], b.y + d[2]   -- where the barrel lands
				local tk, sk = pkey(tx, ty), pkey(sx, sy)
				-- both tiles must be free floor: the barrel takes the far one, we take
				-- the one it leaves, and we must be able to walk to ours
				if world.walk[tk] and not occupied[tk] and not (noLand and noLand[tk])
					and world.walk[sk] and not occupied[sk]
					and bfs and bfs.dist[sk] then
					local score
					if goal then
						local before, after
						if goal.barrel then
							-- stage 3: the BARREL has to reach the pipe, so a push that
							-- does not shorten its distance is no push at all
							before = math.abs(b.x - goal.x) + math.abs(b.y - goal.y)
							after = math.abs(tx - goal.x) + math.abs(ty - goal.y)
						else
							-- stage 1: what moves is US - the push ends with the player
							-- standing on the tile the barrel leaves - so the push worth
							-- making is the one that leaves us nearer the target. This
							-- is what makes the pushes deliberate instead of "nearest
							-- barrel, any direction".
							before = math.abs(px - goal.x) + math.abs(py - goal.y)
							after = math.abs(b.x - goal.x) + math.abs(b.y - goal.y)
						end
						score = (after < before) and (100 + (before - after)) or nil
					else
						-- Away from us is what opens the throat: the barrel leaves the
						-- tile the way through needs. A sideways shove scores the same
						-- as a straight one - what must never win is dragging a barrel
						-- back over the ground we just cleared - and the nearest barrel
						-- is the cheap one, so pushing it beats walking past it.
						local toward = (b.x - px) * d[1] + (b.y - py) * d[2] < 0
						score = (toward and -1000 or 100)
							- 2 * (math.abs(b.x - px) + math.abs(b.y - py))
					end
					local pk = pkey(b.x, b.y) .. '>' .. tk
					local now = API.SystemTime()
					local badUntil = D.barrelBad and D.barrelBad[pk]
					-- Never undo the push just made. The barrel's reported tile lags the
					-- push by a moment, and a pass that read that lag shoved the barrel
					-- straight back ("skips barrels, gets stuck" in the live log).
					local reversing = st and st.lastTo == pkey(b.x, b.y) and st.lastFrom == tk
						and (now - (st.pushAt or 0)) < D.BARREL_REVERSE_MS
					if score and not reversing and not (badUntil and badUntil > now) then
						-- already on the pushing side: no walk, so this is the cheap one
						if px == sx and py == sy then score = score + 10 end
						if not bestScore or score > bestScore then
							bestScore = score
							best = { b = b, sx = sx, sy = sy, tx = tx, ty = ty, key = pk }
						end
					end
				end
			end
		end
	end
	-- Every legal push would drag a barrel back over the ground we just cleared: that
	-- is worse than standing still, so the pass is given back (a room that answers
	-- nothing hands it to the sweep).
	if not best then return false end
	if not goal and bestScore < 0 then return false end
	if px ~= best.sx or py ~= best.sy then
		say('stepping round a barrel to push it')
		log(string.format('barrel %d at %d,%d: walking to %d,%d first, then pushing it to %d,%d%s',
			best.b.id, best.b.x, best.b.y, best.sx, best.sy, best.tx, best.ty,
			goal and string.format(' towards %d,%d %s', goal.x, goal.y,
				goal.barrel and '(the barrel)' or '(us)') or ''))
		if not D.walkTile(best.sx, best.sy) then
			-- The client will not click that tile (its own cap) or no path reaches it:
			-- give this push up instead of standing still for the rest of the floor.
			D.barrelBad = D.barrelBad or {}
			D.barrelBad[best.key] = API.SystemTime() + D.BARREL_STUCK_MS
			log(string.format('cannot walk to %d,%d to push barrel %d - written off for %ds',
				best.sx, best.sy, best.b.id, math.floor(D.BARREL_STUCK_MS / 1000)))
			return false
		end
		-- arrive before deciding anything else: planning the push while the walk is
		-- still running re-picks the same barrel from the old tile
		D.waitMove(px, py, D.BARREL_STEP_WAIT)
		return true
	end
	-- The same push decided again only means something once the last one has had
	-- time to play out. Re-planning after 600 ms read a push that was still animating
	-- as one that had failed, and blacklisted barrels that were moving perfectly well
	-- - which is exactly what "it skips some barrels" looked like.
	if st then
		local now = API.SystemTime()
		if st.lastPush ~= best.key then
			st.same = 0
			st.lastPush, st.lastPushAt = best.key, now
		elseif (now - (st.lastPushAt or 0)) > D.BARREL_PUSH_WAIT then
			st.same = (st.same or 0) + 1
			st.lastPushAt = now
		end
		if (st.same or 0) >= D.BARREL_REPEAT then
			D.barrelBad = D.barrelBad or {}
			D.barrelBad[best.key] = API.SystemTime() + D.BARREL_STUCK_MS
			st.same = 0
			log(string.format('barrel %d at %d,%d will not move that way (%s) - written off for %ds',
				best.b.id, best.b.x, best.b.y, best.key, math.floor(D.BARREL_STUCK_MS / 1000)))
			return false
		end
		st.pushes = (st.pushes or 0) + 1
	end
	say(string.format('pushing a barrel (%d/%d)', (st and st.pushes) or 0, D.BARREL_PUSH_MAX))
	log(string.format('pushing barrel %d from %d,%d to %d,%d (standing on %d,%d)%s',
		best.b.id, best.b.x, best.b.y, best.tx, best.ty, best.sx, best.sy,
		goal and string.format(' towards %d,%d %s', goal.x, goal.y,
			goal.barrel and '(the barrel)' or '(us)') or ''))
	if st then
		-- One push per cycle: nothing is planned again until this one has played out.
		st.pushUntil = API.SystemTime() + D.BARREL_PUSH_WAIT + D.BARREL_ANIM_WAIT
		st.pushAt = API.SystemTime()
		-- and the way back is barred for a while: the barrel's reported tile lags the
		-- push by a moment, and a pass that read that lag pushed it straight back
		st.lastFrom, st.lastTo = pkey(best.b.x, best.b.y), pkey(best.tx, best.ty)
		-- what the next passes wait for: this barrel off this tile
		st.expect = { id = best.b.id, from = st.lastFrom, to = st.lastTo }
		-- the pushing side, for the log and for the "never stand on a barrel" check
		st.lastStand = pkey(best.sx, best.sy)
	end
	local act = D.CODE['Push'] or D.ACT_DEFAULT
	-- Direct click: every barrel shares one id, so the id-based call would push
	-- whichever of them the engine likes, not the one we are standing beside.
	if not API.DoAction_NPC__Direct(act, D.ROUTE_TALK, best.b.npc) then
		API.DoAction_NPC(act, D.ROUTE_TALK, { best.b.id }, 50)
	end
	-- Let the push FINISH before the next decision: the player animates, the barrel
	-- slides a tile and the player steps onto the tile it left. A push takes a couple
	-- of seconds, so this waits for the animation to appear and end, then for the
	-- step, and only then hands the pass back.
	API.RandomSleep2(600, 250, 400)
	D.waitAnimStart(D.BARREL_ANIM_WAIT)
	D.waitMove(px, py, D.BARREL_PUSH_WAIT)
	-- the barrel is on a new tile now: the cached npc list still shows the old one, and
	-- every cached search still has its tile blocked
	D.npcCache = nil
	D.bfsCache = {}
	return true
end

-- Do we already hold the broken barrel bits? Answering from the inventory is what lets
-- the repair happen the moment the bits are in the bag, instead of waiting for a push
-- count or for a bit that is no longer on the floor.
function D.holdsBits()
	for i = 1, #D.BARREL_BITS_IDS do
		local ok, has = pcall(function() return Inventory:Contains(D.BARREL_BITS_IDS[i]) end)
		if ok and has then return true end
	end
	return false
end

-- The barrel room is finished the moment its broken barrel is gone. That npc is the
-- only thing in the room that is ever "broken", and it disappears as soon as the
-- repair lands (live: 11075 vanished right after "You successfully fix the barrel") -
-- what is left behind is the row of plain barrels the puzzle is built of. Those must
-- never be pushed: that is the furniture of a solved room.
--
-- The verdict is remembered by TILE, not by room key, because one physical room takes
-- several keys over a few seconds while the segmentation settles (live: 10721:4881,
-- 10688:4864 and 10709:4864 all named this one room), and a key-based record is lost
-- exactly when the bot walks away - which is how it came back and worked a room it had
-- already finished.
D.barrelDone = {}

function D.barrelDoneHere(here)
	if not here then return nil end
	for _, p in ipairs(D.barrelDone or {}) do
		if p.x >= here.minx - D.BARREL_SLACK and p.x <= here.maxx + D.BARREL_SLACK
			and p.y >= here.miny - D.BARREL_SLACK and p.y <= here.maxy + D.BARREL_SLACK then
			return p
		end
	end
	return nil
end

function D.barrelFinished(here, x, y, why)
	if not here or D.barrelDoneHere(here) then return end
	D.barrelDone = D.barrelDone or {}
	D.barrelDone[#D.barrelDone + 1] = { x = x, y = y }
	log(string.format('barrel puzzle in room %s is finished (%s) - not working it again on this floor',
		rkey(here), tostring(why)))
end

-- How far the puzzle still is: the nearest barrel piece to where we stand. A merged
-- room (segmentation blob) keeps the finished barrel room's barrels inside the bounds of
-- the NEXT room, and the solver then planned pushes 25 tiles behind it ("barrel 11072 at
-- 10725,4891 ... from 10722,4866"). Past this range the puzzle is simply not ours any
-- more.
D.BARREL_WORK_DIST = 12
D.BARREL_NPC_NAMES = { ['barrel'] = true, ['broken barrel'] = true }

function D.barrelNearest(pieces, px, py)
	local best = math.huge
	local function near(x, y)
		local d = math.max(math.abs(x - px), math.abs(y - py))
		if d < best then best = d end
	end
	for _, b in ipairs(pieces.barrels or {}) do near(b.x, b.y) end
	if pieces.broken then near(pieces.broken.x, pieces.broken.y) end
	if pieces.bits then near(pieces.bits.x, pieces.bits.y) end
	return best
end

-- Is there any barrel work left in this room? Two things and only two: the broken
-- barrel to repair, and the barrel this solver repaired a moment ago that still has to
-- be filled. Both the solver and D.barrelRoomBusy ask THIS question, so a room can
-- never be claimed as "busy" without the solver actually working it. That mismatch is
-- what parked the bot on the floor route inside a room with two unopened chests: the
-- barrel solver had declared the room finished (the broken barrel is gone once it is
-- repaired) while the busy test still claimed it and blocked the chest solver, so
-- nothing worked the room and the route took every pass.
function D.barrelWorkLeft(here)
	if not here then return false end
	local pieces = D.barrelPieces(here)
	if pieces.broken then return true end
	local st = S.pondState[rkey(here)]
	return (st and st.kind == D.BARREL_KIND and st.fixedX) and true or false
end

-- Is this room the barrel puzzle, and still unfinished? While it is, the room belongs
-- to that puzzle. Live, two other solvers stole its passes: the chest solver walked
-- off to the room's bonus chest ("locked chest 49682 ... walking to") and the icy-pad
-- solver mistook the pressure pad for an ice square ("icy pads: 1 pad(s) at
-- 10725,4886"), both while the barrel bits were lying reachable.
function D.barrelRoomBusy(here)
	if not here then return false end
	if D.barrelDoneHere(here) then return false end
	-- Nothing to repair and nothing of ours to fill: the room is not ours to keep.
	-- Without this the busy flag outlived the work and starved the chest solver.
	if not D.barrelWorkLeft(here) then return false end
	local st = S.pondState[rkey(here)]
	if st and st.kind == D.BARREL_KIND and st.solved then return false end
	local ids, fixIds = D.BARREL_IDS, D.BARREL_FIX_IDS
	local px, py = ptile()
	for _, n in ipairs(D.npcScan()) do
		local nm = string.lower(D.objName(n))
		if (ids and ids[n.Id]) or (fixIds and fixIds[n.Id]) or D.BARREL_NPC_NAMES[nm] then
			local t = n.Tile_XYZ
			if t then
				local x, y = math.floor(t.x), math.floor(t.y)
				-- in this room AND close enough to be our work: a merged room keeps the
				-- barrels of the room behind us in bounds, and they must not hold this
				-- room hostage
				if x >= here.minx - D.BARREL_SLACK and x <= here.maxx + D.BARREL_SLACK
					and y >= here.miny - D.BARREL_SLACK and y <= here.maxy + D.BARREL_SLACK
					and math.max(math.abs(x - px), math.abs(y - py)) <= D.BARREL_WORK_DIST then
					return true
				end
			end
		end
	end
	return false
end

-- One pass of the barrel puzzle. Returns true whenever the pass was spent here, so
-- the caller does not hand the room to the door sweep in between pushes.
function D.solveBarrels(world, here, px, py)
	if not (here and world) then return false end
	local pieces = D.barrelPieces(here)
	-- No barrel and no broken barrel in this room: not this puzzle, stay quiet.
	if #pieces.barrels == 0 and not pieces.broken then
		-- ...and GIVE THE ROOM BACK. Every object offering "Repair" used to be read as
		-- the broken barrel, so the live collapsing room's strut made this solver claim
		-- that room - and a room already claimed cannot be claimed by the rock room's
		-- own solver, which is why it never recognised the room. The claim survives a
		-- script reload (dung_state is required, so it is the same table), so it has to
		-- be dropped here as well, not just fixed going forward.
		local key0 = rkey(here)
		local st0 = puzzleOwn(key0, D.BARREL_KIND)
		-- A room this solver worked, that now has no pushable barrel at all, is the
		-- FINISHED one: pushing the filled barrel onto the pad turns every barrel npc
		-- into scenery (live: "all npc barrels disappeared and were replaced with
		-- Barrel objects"). There is nothing left to push, so the room is written off
		-- for the rest of the floor instead of being looked at again.
		if st0 and st0.fixedX and st0.filled then
			D.barrelFinished(here, st0.fixedX, st0.fixedY, 'the barrels became scenery')
			return false
		end
		if st0 and not st0.solved and (st0.pushes or 0) == 0 and not st0.fixedX then
			S.pondState[key0] = nil
			log('barrel puzzle: nothing barrel-shaped in this room - releasing the claim')
		end
		return false
	end
	-- The puzzle is behind us. A merged room keeps the finished barrel room's barrels
	-- in bounds, and planning pushes 25 tiles back is how the bot walked away from where
	-- it had already got to.
	local nearest = D.barrelNearest(pieces, px, py)
	if nearest > D.BARREL_WORK_DIST then
		local key0 = rkey(here)
		D.barrelAwayLog = D.barrelAwayLog or {}
		if not D.barrelAwayLog[key0] then
			D.barrelAwayLog[key0] = true
			log(string.format(
				'barrel puzzle in room %s: nearest barrel is %d tiles away - leaving it alone',
				key0, nearest))
		end
		return false
	end
	local key = rkey(here)
	-- Already finished here (this solver did the repair, the fill gave up, or the room
	-- was found with no broken barrel at all).
	if D.barrelDoneHere(here) then return false end
	local st = puzzleOwn(key, D.BARREL_KIND)
	if st and st.solved then
		-- A "solved" mark this solver did not make is not trusted here. The chat rule
		-- that sets it matches the monolith's "the doors in the room are now
		-- unlocked", the chat ring REPLAYS old lines whenever the script is restarted,
		-- and the mark lands on whichever room the player is standing in - which is how
		-- this very barrel room was written off as finished before a single barrel had
		-- been pushed (live: room 10721:4881 marked solved at load time).
		if st.kind ~= D.BARREL_KIND then
			st.solved = nil
			-- the room was written off as finished from that mark too, so it has to be
			-- put back into play or routing keeps skipping it
			S.done[key] = nil
		else
			return false
		end
	end
	st = puzzleClaim(key, D.BARREL_KIND, { pushes = 0, same = 0 })
	if not st then return false end
	-- The room's only work items are the broken barrel (repair it) and the barrel this
	-- solver repaired a moment ago (fill it). With no broken barrel and no repair of our
	-- own, there is nothing left to do here: the Fix barrel disappearing IS the
	-- completion signal, and every barrel still standing is the room's furniture.
	-- Only concluded from inside the room - a corner entry can leave the broken barrel
	-- outside the npc scan, and that must not write the room off.
	if not pieces.broken and not st.fixedX then
		if px >= here.minx - D.BARREL_SLACK and px <= here.maxx + D.BARREL_SLACK
			and py >= here.miny - D.BARREL_SLACK and py <= here.maxy + D.BARREL_SLACK then
			D.barrelFinished(here, here.cx or px, here.cy or py,
				'no broken barrel left to repair')
		end
		return false
	end
	if not st.detected then
		st.detected = true
		log(string.format('barrel puzzle in room %s: %d barrel(s)%s%s', key, #pieces.barrels,
			pieces.broken and string.format(', broken barrel %d at %d,%d "%s"',
				pieces.broken.id, pieces.broken.x, pieces.broken.y, tostring(pieces.broken.action)) or '',
			pieces.pipe and string.format(', expelling pipe %d at %d,%d',
				pieces.pipe.id, pieces.pipe.x, pieces.pipe.y) or ''))
	end
	-- A push has not played out yet. Planning inside that window reads the barrel's
	-- OLD tile - either repeating the push or, worse, reversing it - so the pass is
	-- spent waiting instead.
	if st.pushUntil and API.SystemTime() < st.pushUntil then
		API.RandomSleep2(250, 100, 150)
		return true
	end
	-- The push was made; the scan has to catch up with it. Until the barrel is
	-- reported on its new tile, planning again would repeat or reverse the push from a
	-- stale position - so the pass waits for the report. If it never comes the push
	-- really did nothing, and that one is written off instead of retried for ever.
	if st.expect and st.expect.id then
		local still = false
		for _, b in ipairs(pieces.barrels) do
			if b.id == st.expect.id and pkey(b.x, b.y) == st.expect.from then still = true break end
		end
		if not still then
			st.expect = nil
		elseif (API.SystemTime() - (st.pushAt or 0)) < D.BARREL_SETTLE_MS then
			API.RandomSleep2(300, 100, 150)
			return true
		else
			D.barrelBad = D.barrelBad or {}
			D.barrelBad[st.expect.from .. '>' .. st.expect.to] = API.SystemTime() + D.BARREL_STUCK_MS
			log(string.format(
				'barrel %d did not move from %s after the push (%s) - written off for %ds',
				st.expect.id, st.expect.from, st.expect.to,
				math.floor(D.BARREL_STUCK_MS / 1000)))
			st.expect = nil
		end
	end
	if (st.pushes or 0) >= D.BARREL_PUSH_MAX then
		if not st.gaveUp then
			st.gaveUp = true
			warn(string.format(
				'barrel puzzle in room %s: %d pushes and the room is still shut - leaving it to the door sweep',
				key, st.pushes))
		end
		return false
	end

	-- (a) the bits are the repair's material: take them the moment they can be
	-- reached. While they cannot be, the barrels in the way are the job - and
	-- "reached" means walked to WITHOUT crossing the barrel line (the shared search
	-- treats barrel npcs as obstacles).
	local bfs = D.walkBfs(world)
	if pieces.bits then
		st.sawBits = true
		local bk = pkey(pieces.bits.x, pieces.bits.y)
		local now = API.SystemTime()
		-- THE CLIENT IS THE AUTHORITY ON "CAN THESE BE PICKED UP". A refused pickup
		-- answers "You can't reach that." and the solver used to click the same bits
		-- again on the very next pass, because the tile search said there was a way
		-- (live: five identical "taking barrel bits 17422 at 8620,455 from 8611,456"
		-- with the room's wall in between, until the script was stopped). A refusal is
		-- proof the search is wrong about that tile: the bits are written off for a
		-- while and the pass falls through to a push, which is what opens the way.
		if st.bitsAt and (chat.noReach or 0) > (st.bitsNoReach or 0) then
			D.barrelBitsBad = D.barrelBitsBad or {}
			D.barrelBitsBad[bk] = now + D.BARREL_BITS_BAD_MS
			st.bitsAt = nil
			log(string.format(
				'the client refused the barrel bits at %d,%d - not clicking them again for %ds, pushing instead',
				pieces.bits.x, pieces.bits.y, math.floor(D.BARREL_BITS_BAD_MS / 1000)))
		end
		local bitsBad = D.barrelBitsBad and (D.barrelBitsBad[bk] or 0) > now
		if not bitsBad and D.walkReach(bfs, pieces.bits.x, pieces.bits.y, 1) then
			say('taking the broken barrel bits')
			log(string.format('barrel bits %d at %d,%d in room %s - taking them',
				pieces.bits.id, pieces.bits.x, pieces.bits.y, key))
			st.tookBits = true
			-- remembered before the click: the answer to a refused pickup arrives a few
			-- seconds later, and the next pass has to know it was this take that asked
			st.bitsAt, st.bitsNoReach = now, chat.noReach or 0
			D.takeFloorItem(pieces.bits.obj, { pieces.bits.id }, 'barrel bits')
			return true
		end
		if D.barrelPush(world, pieces.barrels, pieces.barrels, px, py,
			{ x = pieces.bits.x, y = pieces.bits.y }, st) then
			return true
		end
	elseif st.bitsAt then
		-- the bits are off the floor, so the take worked: nothing left to attribute a
		-- refusal to, and an old stamp would only be noise for a later pickup
		st.bitsAt = nil
	end

	-- (b) repair the broken barrel - but only once the bits are ours. They are not
	-- lying on the floor at all until the barrels are pushed aside (live: an empty
	-- ground scan in a room full of barrels), so "no bits visible" is NOT evidence of
	-- holding them and must not send the bot clicking Fix without the material.
	-- Once the throat has been worked, a few tries are spent anyway: after a restart
	-- the bits are already in the inventory and the state that says so is gone.
	local bitsMine = st.tookBits or st.sawBits or D.holdsBits()
		or (st.pushes or 0) >= D.BARREL_REPAIR_AFTER
	if pieces.broken and not pieces.bits and bitsMine then
		st.repairs = (st.repairs or 0) + 1
		if st.repairs <= D.BARREL_REPAIRS and D.interactable(pieces.broken.obj) then
			local act = pieces.broken.action or 'Repair'
			say('repairing the broken barrel')
			log(string.format('repairing the broken barrel %d at %d,%d with "%s" (room %s, try %d/%d)',
				pieces.broken.id, pieces.broken.x, pieces.broken.y, act, key,
				st.repairs, D.BARREL_REPAIRS))
			-- remembered before the click: after the repair this tile holds the barrel
			-- that has to be filled, and nothing else marks it out
			st.fixedX, st.fixedY = pieces.broken.x, pieces.broken.y
			if pieces.broken.npcFix then
				-- the broken barrel is an npc: the direct call is the only one that can
				-- pick the right one out of a room full of identical "Barrel" npcs
				if not API.DoAction_NPC__Direct(code(act), D.ROUTE_TALK, pieces.broken.obj) then
					API.DoAction_NPC(code(act), D.ROUTE_TALK, { pieces.broken.id }, 50)
				end
			else
				D.clickObject(act, pieces.broken.obj)
			end
			-- Construction has an animation of its own: wait for the barrel to be
			-- fixed instead of re-deciding on the next tick, then drop the caches so
			-- the fixed barrel is seen where it is now.
			API.RandomSleep2(700, 250, 400)
			D.waitAnimStart(D.BARREL_ANIM_WAIT)
			D.npcCache, D.objCache = nil, nil
			D.bfsCache = {}
			return true
		elseif st.repairs == D.BARREL_REPAIRS + 1 then
			warn(string.format('barrel puzzle in room %s: the broken barrel would not repair in %d tries',
				key, D.BARREL_REPAIRS))
		end
	end

	-- (c) the fixed barrel: fill it at the live pipe, then push the FULL barrel onto
	-- the room's pressure pad. Live: standing beside the expelling pipe only fills the
	-- barrel - the room opened when the filled barrel was pushed onto the pad, and at
	-- that moment every pushable barrel npc turned into a plain "Barrel" object.
	-- Waiting beside the pipe for ever is what left this puzzle unfinished.
	if st.fixedX and not pieces.broken then
		local fixed = D.barrelFixed(here, pieces.barrels, st)
		if not fixed then
			-- our filled barrel is no longer a pushable npc: the barrels of a finished
			-- room are scenery. Only concluded from a barrel THIS solver filled.
			if st.filled then
				D.barrelFinished(here, st.fixedX, st.fixedY,
					'the filled barrel turned into scenery')
			end
			return false
		end
		if not pieces.pipe and not st.filled then
			-- the pipes stream in with the room: wait for one instead of shoving the
			-- fixed barrel around at random. Bounded - a pipe that never shows up must
			-- not keep the room for ever. A barrel that is already FULL does not need
			-- the pipe any more, only the pad.
			st.pipeWaits = (st.pipeWaits or 0) + 1
			if st.pipeWaits > D.BARREL_PIPE_WAITS then
				if st.pipeWaits == D.BARREL_PIPE_WAITS + 1 then
					warn(string.format(
						'barrel puzzle in room %s: no expelling pipe after %d polls - giving the room back',
						key, D.BARREL_PIPE_WAITS))
				end
				return false
			end
			say('waiting for the expelling pipe')
			API.RandomSleep2(600, 250, 350)
			return true
		end
		st.pipeWaits = 0

		-- (c1) LINE UP and fill. "Beside the pipe" means the barrel is on one of the
		-- pipe's own row/column neighbours, both tiles in line - a barrel left
		-- diagonally against the pipe is pushed into line first, never waited on.
		if not st.filled then
			local spots = D.barrelFillSpots(world, pieces.pipe, fixed.x, fixed.y, pieces.pipes)
			local pipeKey = pkey(pieces.pipe.x, pieces.pipe.y)
			if st.fillPipe ~= pipeKey then
				-- a pipe that moved (they do) is a fresh start
				st.fillPipe, st.fills, st.fillLogAt = pipeKey, 0, nil
			end
			local spot = spots[1]
			if spot and fixed.x == spot.x and fixed.y == spot.y then
				st.fills = (st.fills or 0) + 1
				say(string.format('barrel lined up with the pipe - filling (%d/%d)',
					st.fills, D.BARREL_FILL_WAIT))
				local now = API.SystemTime()
				if not st.fillLogAt or (now - st.fillLogAt) > 5000 then
					st.fillLogAt = now
					log(string.format(
						'barrel %d at %d,%d is lined up with the expelling pipe at %d,%d - letting it fill (%d/%d)',
						fixed.id, fixed.x, fixed.y, pieces.pipe.x, pieces.pipe.y,
						st.fills, D.BARREL_FILL_WAIT))
				end
				if st.fills > D.BARREL_FILL_WAIT then
					-- Full. The pipe never finishes the room on its own: the pad does.
					st.filled = true
					st.fills, st.fillLogAt = 0, nil
					log(string.format(
						'barrel %d has filled at pipe %d,%d - taking it to the pressure pad%s',
						fixed.id, pieces.pipe.x, pieces.pipe.y,
						pieces.pad and string.format(' at %d,%d', pieces.pad.x, pieces.pad.y) or ''))
				else
					API.RandomSleep2(700, 250, 350)
					return true
				end
			end
			if not st.filled then
				-- Not in line yet: push it onto the aligned tile (the pipe itself is no
				-- target - a barrel standing on the pipe is not beside it, so the pipe
				-- bank is barred as a landing tile)
				if not spot then spot = { x = pieces.pipe.x, y = pieces.pipe.y } end
				if D.barrelPush(world, pieces.barrels, { fixed }, px, py,
					{ x = spot.x, y = spot.y, barrel = true }, st, pieces.pipes) then
					st.stalls = 0
					return true
				end
				-- No legal push puts the barrel in line from where it stands. Bounded: a
				-- room this solver cannot finish must be handed back instead of being
				-- claimed every pass, which starves the chest solver in the same room.
				st.stalls = (st.stalls or 0) + 1
				if st.stalls >= D.BARREL_STALLS then
					D.barrelFinished(here, st.fixedX, st.fixedY,
						string.format('no push moved the barrel in line with pipe %d in %d tries',
							pieces.pipe.id, st.stalls))
					return false
				end
				API.RandomSleep2(500, 200, 300)
				return true
			end
		end

		-- (c2) the full barrel goes ON the pressure pad - that is the unlock
		local pad = pieces.pad
		if not pad then
			st.padWaits = (st.padWaits or 0) + 1
			if st.padWaits == 1 then
				log(string.format(
					'barrel %d is full but this room shows no pressure pad - waiting for one', fixed.id))
			end
			if st.padWaits >= D.BARREL_STALLS then
				D.barrelFinished(here, st.fixedX, st.fixedY,
					string.format('barrel %d is full and the room has no pressure pad', fixed.id))
				return false
			end
			API.RandomSleep2(600, 250, 350)
			return true
		end
		st.padWaits = 0
		if fixed.x == pad.x and fixed.y == pad.y then
			st.padPolls = (st.padPolls or 0) + 1
			say(string.format('full barrel on the pressure pad - waiting for the room (%d/%d)',
				st.padPolls, D.BARREL_PAD_WAIT))
			local now = API.SystemTime()
			if not st.padLogAt or (now - st.padLogAt) > 5000 then
				st.padLogAt = now
				log(string.format(
					'filled barrel %d is ON the pressure pad at %d,%d - waiting for the room to open (%d/%d)',
					fixed.id, pad.x, pad.y, st.padPolls, D.BARREL_PAD_WAIT))
			end
			if st.padPolls > D.BARREL_PAD_WAIT then
				D.barrelFinished(here, st.fixedX, st.fixedY,
					string.format('full barrel %d stood on pad %d,%d for %d polls',
						fixed.id, pad.x, pad.y, st.padPolls))
				return false
			end
			API.RandomSleep2(700, 250, 350)
			return true
		end
		if D.barrelPush(world, pieces.barrels, { fixed }, px, py,
			{ x = pad.x, y = pad.y, barrel = true }, st, pieces.pipes) then
			st.stalls = 0
			return true
		end
		st.stalls = (st.stalls or 0) + 1
		if st.stalls >= D.BARREL_STALLS then
			D.barrelFinished(here, st.fixedX, st.fixedY,
				string.format('no push moved the full barrel onto pad %d,%d in %d tries',
					pad.x, pad.y, st.stalls))
			return false
		end
		API.RandomSleep2(500, 200, 300)
		return true
	end

	-- (d) stage 1: get PAST the barrels. The target is where the work is - the bits if
	-- they have been seen, otherwise the broken barrel that has to be repaired (it is
	-- the one thing in the room that is always there and always behind the barrels).
	-- Pushing is then a means to an end: every pass picks the push that ends with the
	-- player nearer that target, so it works one gap instead of shoving neighbours at
	-- random. Only when no push improves anything does it fall back to opening the
	-- throat away from the player.
	local goal = { x = pieces.bits and pieces.bits.x or pieces.broken and pieces.broken.x
			or here.cx or px,
		y = pieces.bits and pieces.bits.y or pieces.broken and pieces.broken.y
			or here.cy or py }
	if D.barrelPush(world, pieces.barrels, pieces.barrels, px, py, goal, st) then
		return true
	end
	-- Nothing shortens the way to the target. Open the throat away from the player
	-- instead - and say so, because a push with no visible purpose is exactly what
	-- looks like "pushing random barrels" from the outside.
	local now = API.SystemTime()
	if not st.throatLogAt or (now - st.throatLogAt) > 6000 then
		st.throatLogAt = now
		log(string.format('no push moves us towards %d,%d - clearing the throat instead',
			goal.x, goal.y))
	end
	return D.barrelPush(world, pieces.barrels, pieces.barrels, px, py, nil, st)
end

--------------------------------------------------------------------
-- puzzles: the monolith (Monolith.java)
--------------------------------------------------------------------
-- A monolith room is LOCKED: none of its doorways open until the pillar is
-- charged to 100%, which is why clicking them does nothing at all and why the
-- bot kept declaring the floor cleared with door 49462 still shut. The java
-- answer is the only one that works - activate the monolith, then distract the
-- mysterious shades that spawn and drain it; when the charge completes the
-- shades die and the room's doors unlock.
D.MONO_TRY_LIMIT = 12     -- Activate clicks before the pillar is written off
D.MONO_QUIET_MS  = 20000  -- charging pillar, no shade for this long = charged

-- 'start' | 'progress'. The option text is authoritative (Activate = not started,
-- Count-charges = charging); the ids are the fallback for a variant whose first
-- option is not loaded. Nothing here says "finished" - the charged pillar looks
-- exactly like the charging one.
function D.monolithState(n)
	local a = n.Action or ''
	if a == 'Activate' then return 'start' end
	if a == 'Count-charges' then return 'progress' end
	if (n.Anim or 0) == D.MONOLITH_ANIM then return 'progress' end
	if D.MONOLITH_SET[n.Id] then return 'start' end
	if D.MONOLITH_ACTIVE_SET[n.Id] then return 'progress' end
	return 'start'
end

-- The pillar is an npc and the world scan no longer reads npcs, so the room it
-- belongs to is resolved on demand: its own tile is a blocked square that is not
-- in a room's walk set, so the search is by bounds, and the answer is kept for the
-- room key (room indices are rebuilt on every rescan).
D.monoPillarCache = {}
function D.monoPillar(here)
	if not here then return nil end
	local key = rkey(here)
	local hit = D.monoPillarCache[key]
	if hit then return hit end
	for _, n in ipairs(D.npcScan()) do
		if D.isMonolith(n) then
			local t = n.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			if x >= here.minx - 3 and x <= here.maxx + 3
				and y >= here.miny - 3 and y <= here.maxy + 3 then
				D.monoPillarCache[key] = n
				here.monolith, here.monoX, here.monoY = n, x, y
				return n
			end
		end
	end
	return nil
end

-- Shades (or anything else with an attack option) standing in the pillar's room.
-- liveEnemies() only sees npcs whose tile is in the room's walk set, and a shade
-- walking around the pillar's blocked square can fall outside it.
function D.monolithShade(here)
	if not here then return nil end
	local best, bestD = nil, math.huge
	local mx, my = here.monoX or here.cx or here.minx, here.monoY or here.cy or here.miny
	for _, n in ipairs(D.npcScan()) do
		if not D.isMonolith(n) and (n.Action or '') == 'Attack' and (n.Life or 0) > 0 then
			local t = n.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			if x >= here.minx - 3 and x <= here.maxx + 3
				and y >= here.miny - 3 and y <= here.maxy + 3 then
				local d = (x - mx) ^ 2 + (y - my) ^ 2
				if d < bestD then bestD, best = d, n end
			end
		end
	end
	return best
end

-- One step of the puzzle: activate the pillar, then kill whatever appears.
-- Returns true while the room still owns us - its doors are dead until the
-- monolith is charged, so there is nothing else to do in here.
-- A D field, not a local function: the 200-local budget is shared by everything
-- in this file, and D.* entries cost nothing.
function D.solveMonolith(world, here, px, py)
	local mono = here and here.monolith or nil
	if not mono and here then mono = D.monoPillar(here) end
	if not mono then return false end
	local key = rkey(here)
	local st = D.monoState[key]
	if st and st.solved then return false end
	if puzzleDone(here) then
		-- chat already announced that the room is unlocked
		D.monoState[key] = { solved = true }
		D.monoClearRoom = key
		return false
	end
	st = st or { tries = 0, shades = 0 }
	D.monoState[key] = st
	local mx, my = here.monoX or px, here.monoY or py
	local state = D.monolithState(mono)

	-- kill everything that appears (the mysterious shades)
	local shade = D.monolithShade(here)
	if shade then
		st.shades = st.shades + 1
		st.quiet = API.SystemTime()
		say('killing a shade at the monolith')
		attack(shade)
		return true
	end

	-- nothing to kill: make sure the pillar is running
	if state == 'start' then
		if st.tries >= D.MONO_TRY_LIMIT then
			if not st.gaveUp then
				st.gaveUp = true
				say('the monolith will not activate')
				log(string.format('monolith %d at %d,%d ignored %d Activate clicks - leaving it',
					mono.Id, mx, my, st.tries))
			end
			return false
		end
		local d = math.max(math.abs(px - mx), math.abs(py - my))
		if d > 1 then
			-- Never walk to the pillar's own tile: it is blocked collision, so the
			-- plan fails every single time and the bot stood still for 12 tries
			-- ("monolith 10975 at 6904,5080 is 6 tiles away - walking in range" x12)
			-- without ever clicking Activate.
			local sx, sy = D.walkSpotNear(world, mx, my)
			if sx then
				say('walking to the monolith')
				log(string.format('monolith %d at %d,%d is %d tiles away - walking to %d,%d',
					mono.Id, mx, my, d, sx, sy))
				D.walkTile(sx, sy, 0)
				return true
			end
		end
		st.tries = st.tries + 1
		say('activating the monolith')
		log(string.format('monolith %d at %d,%d - clicking Activate (try %d)',
			mono.Id, mx, my, st.tries))
		API.DoAction_NPC(D.ACT_TALK, D.ROUTE_TALK, { mono.Id }, 50)
		API.RandomSleep2(1200, 400, 600)
		settle()
		return true
	end

	-- Charging. The pillar's own id is the primary "charged" answer (see above);
	-- this is the confirmation: the doorways that were SHUT when the room was
	-- entered are the ones the puzzle unlocks, so one of them opening means done.
	if not st.shut then
		st.shut = {}
		for _, d in ipairs(world.doors or {}) do
			if doorInRoom(here, d) and not doorwayOpen(world, d) then
				st.shut[dkey(d)] = true
			end
		end
		if next(st.shut) == nil then st.shut = false end
	end
	if st.shut then
		for _, d in ipairs(world.doors or {}) do
			if st.shut[dkey(d)] and doorInRoom(here, d) and doorwayOpen(world, d) then
				st.solved = true
				D.monoClearRoom = key
				say('monolith charged - the doors opened')
				log(string.format(
					'monolith in room %s charged after %d shade(s) - doorway %d at %d,%d unlocked',
					key, st.shades, d.id, d.x, d.y))
				return false
			end
		end
	end
	-- Charged. The pillar looks identical when it finishes, so this is read from the
	-- room: a doorway that was shut when we walked in is now open -> done. Backup:
	-- every shade dies the moment the charge hits 100%, so a shade-free stretch on
	-- a charging pillar means it is finished too.
	st.quiet = st.quiet or API.SystemTime()
	local now = API.SystemTime()
	if now - st.quiet > D.MONO_QUIET_MS then
		st.solved = true
		D.monoClearRoom = key
		say('monolith charged')
		log(string.format(
			'monolith in room %s charged after %d shade(s) - no shade for %ds',
			key, st.shades, math.floor(D.MONO_QUIET_MS / 1000)))
		return false
	end
	say('waiting for the shades')
	API.RandomSleep2(800, 300, 500)
	return true
end

--------------------------------------------------------------------
-- puzzle: lodestone power
--------------------------------------------------------------------
-- Live layout (frozen floor, player 7265,2185):
--   "Lodestone"     49571 [Unlock]    at 7272,2180 - the centre; charging it unlocks
--                                    every doorway of the room
--   "Gap"           49568 [Jump-over] on a checkerboard, x 7269..7275, y 2182..2188;
--                                    the stones between them are the walkable tiles
--   "Power crystal" 17376 (ground)    at 7272,2189 - the south entry, in front of the
--                                    field; it opens the loot window like a key does
-- A move is a click on a GAP: the character jumps two tiles over it (clicking the
-- stone beyond the gap does nothing - verified live). The last jump lands on 7272,2181,
-- the platform beside the lodestone. The guardian sphere shadows the player and a
-- capture just drops us back at the entry, so the crossing is done as four jumps in a
-- row and a capture simply starts it again - no waiting, no detours.
D.LODESTONE_IDS = { 49571, 49572 }
D.LODESTONE_SET = {}
for i = 1, #D.LODESTONE_IDS do D.LODESTONE_SET[D.LODESTONE_IDS[i]] = true end
D.LODE_GAP     = 49568
D.LODE_CRYSTAL = 17376
D.LODE_RANGE   = 13

-- Everything this puzzle owns, anchored on the lodestone (segmentation drops the
-- platforms, so the room model cannot be used to recognise it).
function D.lodeRoom(px, py)
	local all = D.objScan()
	local lode = nil
	for _, o in ipairs(all) do
		if D.LODESTONE_SET[o.Id] then
			local t = o.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			local d = (x - px) ^ 2 + (y - py) ^ 2
			if d <= D.LODE_RANGE * D.LODE_RANGE and (not lode or d < lode.d) then
				lode = { obj = o, id = o.Id, x = x, y = y, z = math.floor(t.z or 0),
					d = d, action = o.Action }
			end
		end
	end
	if not lode then return nil end
	local r = { lode = lode, gaps = {}, gapAt = {}, crystal = nil }
	for _, o in ipairs(all) do
		local t = o.Tile_XYZ
		local x, y = math.floor(t.x), math.floor(t.y)
		if math.abs(x - lode.x) <= D.LODE_RANGE and math.abs(y - lode.y) <= D.LODE_RANGE then
			if o.Id == D.LODE_GAP then
				local e = { obj = o, x = x, y = y, z = math.floor(t.z or 0) }
				r.gaps[#r.gaps + 1] = e
				r.gapAt[pkey(x, y)] = e
				r.minx = math.min(r.minx or x, x)
				r.maxx = math.max(r.maxx or x, x)
				r.miny = math.min(r.miny or y, y)
				r.maxy = math.max(r.maxy or y, y)
			elseif o.Type == 3 and o.Id == D.LODE_CRYSTAL then
				local d = (x - px) ^ 2 + (y - py) ^ 2
				if not r.crystal or d < r.crystal.d then
					r.crystal = { obj = o, x = x, y = y, z = math.floor(t.z or 0), d = d }
				end
			end
		end
	end
	return r
end

-- The stones of the crossing, in order, derived from the pit's bounds: the route hugs the
-- outside edges - one jump up the left edge, three east along the row two up from the
-- bottom, then two up the right edge onto the stone that faces the lodestone's platform.
function D.lodeLattice(r)
	local minx, maxx, maxy = r.minx, r.maxx, r.maxy
	return {
		{ x = minx,     y = maxy },
		{ x = minx,     y = maxy - 2 },
		{ x = minx + 2, y = maxy - 2 },
		{ x = minx + 4, y = maxy - 2 },
		{ x = maxx,     y = maxy - 2 },
		{ x = maxx,     y = maxy - 4 },
		{ x = maxx,     y = maxy - 6 },
	}
end
-- The crossing, exactly as it was clicked by hand in game: step onto the left-most stone
-- of the bottom row, then six Gap clicks - one north, THREE east along the row two up from
-- the bottom, then two north up the right-hand column - which parks you on the stone beside
-- the lodestone's platform. The guardian sphere sits in front of the middle lanes, so the
-- crossing hugs the outside edges and never goes up the middle.
--
-- The landings are a fixed lattice of the 7x7 pit, so they are derived from its bounds
-- rather than hardcoded tiles.
function D.lodeSteps(r, px, py, walk)
	local minx, maxx, miny, maxy = r.minx, r.maxx, r.miny, r.maxy
	if not (minx and maxx and miny and maxy) then return nil end
	local endY, entryY = miny - 1, maxy + 1

	-- A step is only ever emitted for a real tile: never one of the pit's gap tiles, and
	-- never a floor tile outside the puzzle that the client cannot reach (that used to be
	-- clicked through the room's closed door). Tiles inside the puzzle's box are trusted;
	-- anything further out has to be in the live walk set.
	local function standable(x, y)
		if r.gapAt[pkey(x, y)] then return false end
		if x >= minx - 1 and x <= maxx + 1 and y >= miny - 1 and y <= maxy + 1 then return true end
		if walk then return walk[pkey(x, y)] and true or false end
		return false
	end

	-- the stones of the crossing, in order; the gap to click is the midpoint of each pair
	local landings = D.lodeLattice(r)

	-- where we stand in that list
	local idx = nil
	for k = 1, #landings do
		if px == landings[k].x and py == landings[k].y then idx = k break end
	end

	local steps = {}
	local cx, cy = px, py

	if not idx then
		-- On the lodestone's platform already: walk across to the lodestone.
		if cy <= endY then
			while cx ~= r.lode.x do
				cx = cx + ((r.lode.x > cx) and 1 or -1)
				if not standable(cx, cy) then return nil end
				steps[#steps + 1] = { x = cx, y = cy }
			end
			if #steps == 0 then return nil end
			return steps
		end
		-- Anywhere else: get onto the first stone of the crossing. This is the only
		-- walking before the jumps, and the caller collapses it into a single click.
		while cy > entryY do
			cy = cy - 1
			if not standable(cx, cy) then return nil end
			steps[#steps + 1] = { x = cx, y = cy }
		end
		while cx ~= minx do
			cx = cx + ((minx > cx) and 1 or -1)
			if not standable(cx, cy) then return nil end
			steps[#steps + 1] = { x = cx, y = cy }
		end
		while cy > maxy do
			cy = cy - 1
			if not standable(cx, cy) then return nil end
			steps[#steps + 1] = { x = cx, y = cy }
		end
		if cy ~= maxy or cx ~= minx then return nil end
		return steps
	end

	if idx < #landings then
		for k = idx, #landings - 1 do
			local a, b = landings[k], landings[k + 1]
			local gx, gy = math.floor((a.x + b.x) / 2), math.floor((a.y + b.y) / 2)
			if not r.gapAt[pkey(gx, gy)] then return nil end
			if not standable(b.x, b.y) then return nil end
			steps[#steps + 1] = { x = b.x, y = b.y, via = { x = gx, y = gy } }
		end
		return steps
	end

	-- last stone of the crossing: onto the platform and across to the lodestone
	while cy ~= endY do
		cy = cy + ((endY > cy) and 1 or -1)
		if not standable(cx, cy) then return nil end
		steps[#steps + 1] = { x = cx, y = cy }
	end
	while cx ~= r.lode.x do
		cx = cx + ((r.lode.x > cx) and 1 or -1)
		if not standable(cx, cy) then return nil end
		steps[#steps + 1] = { x = cx, y = cy }
	end
	if #steps == 0 then return nil end
	return steps
end

-- The gap objects are re-created by the puzzle, so a record kept from an earlier scan
-- can be dead by the time it is clicked ("no such object in the live scan"). Resolve
-- the "Jump-over" object that is on that tile NOW.
function D.lodeGapAt(x, y)
	for _, o in ipairs(D.objsFresh()) do
		if o.Type ~= 3 and (o.Action or '') == 'Jump-over' then
			local t = o.Tile_XYZ
			if math.floor(t.x) == x and math.floor(t.y) == y then return o end
		end
	end
	return nil
end

-- Shortest move list to `tol` of a target, where a blocked gap tile is crossed by a
-- jump to the tile two steps on. Returns nil when the target cannot be reached.
function D.lodePath(px, py, goalX, goalY, gapAt, tol, walk, jumpsOnly)
	tol = tol or 1
	if math.abs(px - goalX) <= tol and math.abs(py - goalY) <= tol then return {} end
	walk = walk or S.floorTiles
	if not walk[pkey(px, py)] then return nil end
	local prev, seen = {}, { [pkey(px, py)] = true }
	local q, head, goal = { { px, py } }, 1, nil
	while head <= #q and not goal do
		local cur = q[head]
		head = head + 1
		for i = 1, 4 do
			local dx, dy = D.DIR4[i][1], D.DIR4[i][2]
			local tx, ty, via
			local ka = pkey(cur[1] + dx, cur[2] + dy)
			if not jumpsOnly and walk[ka] then
				tx, ty = cur[1] + dx, cur[2] + dy
			elseif gapAt and gapAt[ka] then
				local bx, by = cur[1] + 2 * dx, cur[2] + 2 * dy
				if walk[pkey(bx, by)] then tx, ty, via = bx, by, { x = cur[1] + dx, y = cur[2] + dy } end
			end
			local k = tx and pkey(tx, ty)
			if k and not seen[k] then
				seen[k] = true
				prev[k] = { from = cur, x = tx, y = ty, via = via }
				if math.abs(tx - goalX) <= tol and math.abs(ty - goalY) <= tol then
					goal = k
					break
				end
				q[#q + 1] = { tx, ty }
			end
		end
	end
	if not goal then return nil end
	local steps, node = {}, goal
	while prev[node] do
		local e = prev[node]
		table.insert(steps, 1, { x = e.x, y = e.y, via = e.via })
		node = pkey(e.from[1], e.from[2])
	end
	return steps
end

-- The room's doorways answered "locked until the lock in the centre is released" and
-- were written off for the floor by then; the charge makes them work again.
function D.lodeClearNear(x, y)
	if not S.badDoor or not x or not y then return end
	local n = 0
	for k in pairs(S.badDoor) do
		local ax, ay = k:match('^(%-?%d+):(%-?%d+)$')
		if ax and math.abs(tonumber(ax) - x) <= 14 and math.abs(tonumber(ay) - y) <= 14 then
			S.badDoor[k] = nil
			if S.attempts then S.attempts[k] = nil end
			n = n + 1
		end
	end
	if n > 0 then
		log(string.format('lodestone: cleared %d blacklisted doorway attempt(s) around %d,%d', n, x, y))
	end
end

-- One step of the lodestone room. Returns true while the room still owns us: until the
-- lodestone is charged none of its doorways answer ("This door is locked. It won't open
-- until the lock in the centre of the room is released").
function D.solveLodestone(world, px, py, here)
	local r = D.lodeRoom(px, py)
	if not r or not r.gaps[1] then
		-- The lodestone is REMOVED from the middle once it is charged, so "the one we
		-- just clicked is no longer there" is the finished signal. Record it, put the
		-- room's doorways back in play (they were written off while locked) and let the
		-- normal routing take over.
		if D.lodeLast and not D.lodeDone then
			D.lodeDone = {}
			D.lodeDone[D.lodeLast] = true
			say('lodestone charged - heading back')
			log(string.format('lodestone at %s is gone from the middle - the room is unlocked',
				tostring(D.lodeLast)))
			local lx, ly = tostring(D.lodeLast):match('^(%-?%d+),(%-?%d+)$')
			D.lodeClearNear(tonumber(lx), tonumber(ly))
			D.lodeActive = nil
		end
		return false
	end
	local lode = r.lode
	local key = lode.x .. ',' .. lode.y
	local held = Inventory:Contains(D.LODE_CRYSTAL)

	-- Charged? The lodestone flips its own Bool1 to 1 on the successful "Unlock" click and
	-- stays in the middle afterwards, so Bool1 is the definitive signal. The crystal is
	-- consumed by that same click, which is the immediate fallback for the frames before
	-- Bool1 reads back.
	local flag = tonumber(lode.obj.Bool1 or 0) or 0
	local charged = flag == 1
		or (D.lodeClickAt and not held and (API.SystemTime() - D.lodeClickAt) < 20000)
	if charged and not (D.lodeDone and D.lodeDone[key]) then
		D.lodeDone = D.lodeDone or {}
		D.lodeDone[key] = true
		D.lodeHops = nil
		D.lodeClearNear(lode.x, lode.y)
		say('lodestone charged - heading back')
		log(string.format('lodestone %d at %d,%d charged (%s) - room unlocked',
			lode.id, lode.x, lode.y, flag == 1 and 'Bool1=1' or 'the crystal was used'))
	end
	if D.lodeDone and D.lodeDone[key] then
		-- Standing next to the lodestone or on the pit: keep control until we are back on
		-- the room's floor. The platform belongs to no room, so handing this to the router
		-- leaves it clicking doors it cannot path to. Past the pit on the entry row means
		-- we are out, so drop control.
		local inBox = px >= r.minx - 1 and px <= r.maxx + 1 and py >= r.miny - 2 and py <= r.maxy
		if not inBox then return false end

		-- Back down the same lattice the crossing uses, in reverse: the way home is then one
		-- clean line instead of a BFS that zig-zags sideways.
		local landings = D.lodeLattice(r)
		if #landings < 2 then return false end
		local idx = nil
		for k = 1, #landings do
			if px == landings[k].x and py == landings[k].y then idx = k break end
		end
		if not idx then
			-- not on a stone of the crossing: step onto the one that faces the platform
			local top = landings[#landings]
			if px == top.x and py == top.y then
				idx = #landings
			else
				say('stepping onto the stones to head back')
				log(string.format('lodestone %d: stepping to %d,%d to start the way back',
					lode.id, top.x, top.y))
				D.walkTile(top.x, top.y, 0)
				API.RandomSleep2(900, 300, 500)
				settle()
				D.dirty = true
				return true
			end
		end
		if idx <= 1 then
			-- on the entry stone: step off the pit and hand back to routing
			say('back off the stones')
			log(string.format('lodestone %d: stepping off the pit at %d,%d', lode.id, r.minx, r.maxy + 1))
			D.walkTile(r.minx, r.maxy + 1, 0)
			API.RandomSleep2(900, 300, 500)
			settle()
			D.dirty = true
			return true
		end
		local from, to = landings[idx], landings[idx - 1]
		local gx, gy = math.floor((from.x + to.x) / 2), math.floor((from.y + to.y) / 2)
		local live = D.lodeGapAt(gx, gy)
		if not live then
			D.dirty = true
			return true
		end
		say('heading back over the stones')
		log(string.format('lodestone %d: back over gap %d,%d -> %d,%d (player %d,%d)',
			lode.id, gx, gy, to.x, to.y, px, py))
		if not D.clickObject('Jump-over', live) then
			API.RandomSleep2(1000, 200, 300)     -- gate refused: wait it out
		end
		API.RandomSleep2(900, 300, 500)
		settle()
		D.dirty = true
		return true
	end
	-- Only work the room from the platform row the power crystal sits on (and the field
	-- itself). Standing on the far side of its doorway there is nothing to jump yet - the
	-- doorway has to be opened and walked through first, which is the router's job. This
	-- used to engage from anywhere in the room and clicked a floor tile on the far side
	-- of the closed door.
	local engaged = px >= r.minx - 1 and px <= r.maxx + 1
		and py >= r.miny - 1 and py <= r.maxy + 2
	if not engaged then return false end
	D.lodeActive = D.lodeActive or {}
	if not D.lodeActive[key] then
		D.lodeActive[key] = true
		log(string.format('lodestone %d at %d,%d: solving this room from %d,%d (%d gap(s) seen)',
			lode.id, lode.x, lode.y, px, py, #r.gaps))
	end
	-- Progress watch only: a failed jump, a capture that drops us back at the entry or a
	-- click the client ignored all just mean the crossing starts again from wherever we
	-- stand. This counts that, it never gives up - the room's doors stay locked until
	-- the lodestone is charged, so leaving it unsolved is worse than trying again.
	local now = API.SystemTime()
	if not D.lodeTry or (px ~= D.lodeTry.x or py ~= D.lodeTry.y) then
		D.lodeTry = { x = px, y = py, t = now }
	elseif now - D.lodeTry.t > 12000 then
		D.lodeTries = (D.lodeTries or 0) + 1
		D.lodeTry = { x = px, y = py, t = now }
		log(string.format('lodestone %d: still at %d,%d after 12s - attempt %d, crossing again',
			lode.id, px, py, D.lodeTries))
	end

	-- Dumped back out of the field (a stumble on a jump): the crossing starts again from
	-- the entry row, so just say so and let the next pass re-plan from there.
	local onStones = px >= r.minx and px <= r.maxx and py >= r.miny and py <= r.maxy
	if D.lodeWasOn and not onStones then
		log(string.format('lodestone %d: back off the stones at %d,%d - crossing again from the entry',
			lode.id, px, py))
	end
	D.lodeWasOn = onStones

	-- Standing in the middle with the crystal: charge it.
	if held and math.max(math.abs(px - lode.x), math.abs(py - lode.y)) <= 1 then
		if D.canClickNow(2500) and (not D.lodeClickAt or (API.SystemTime() - D.lodeClickAt) > 2500) then
			D.lodeClickAt = API.SystemTime()
			D.lodeLast = key
			say('charging the lodestone')
			log(string.format('lodestone %d at %d,%d: clicking "%s" with the power crystal (player %d,%d)',
				lode.id, lode.x, lode.y, tostring(lode.action), px, py))
			-- the record kept from the scan can be dead by now (the puzzle re-creates its
			-- objects), so the click goes to the object that is on that tile right now
			local live = D.liveObjectAt(lode.id, lode.x, lode.y)
			if live and live ~= false then
				D.clickObject(lode.action or 'Unlock', live)
			else
				D.clickObject(lode.action or 'Unlock', lode.obj)
			end
			API.RandomSleep2(1200, 400, 600)
			settle()
			D.dirty = true
		end
		return true
	end

	-- Next to the crystal that is still on the floor: take it.
	if not held and r.crystal
		and math.max(math.abs(px - r.crystal.x), math.abs(py - r.crystal.y)) <= 1 then
		if D.canClickNow(2500) then
			D.lodeCrystal = D.lodeCrystal or { t = 0, n = 0 }
			if (API.SystemTime() - D.lodeCrystal.t) > 3000 then
				D.lodeCrystal.t = API.SystemTime()
				D.lodeCrystal.n = D.lodeCrystal.n + 1
				say('taking the power crystal')
				log(string.format('lodestone %d: taking the power crystal at %d,%d (try %d)',
					lode.id, r.crystal.x, r.crystal.y, D.lodeCrystal.n))
				D.takeFloorItem(r.crystal.obj, { D.LODE_CRYSTAL }, 'power crystal')
			end
		end
		return true
	end

	-- Otherwise go for the crystal, then cross by jumps.
	local gx, gy = lode.x, lode.y
	if not held and r.crystal then gx, gy = r.crystal.x, r.crystal.y end
	local path
	if held then
		-- crossing: gap clicks only (plus one step if we are off the stones)
		path = D.lodeSteps(r, px, py, world.walk)
		if path and #path > 0 and not D.lodePlanLog then
			D.lodePlanLog = true
			local desc = {}
			for _, s in ipairs(path) do
				desc[#desc + 1] = (s.via and 'jump->' or 'walk->') .. s.x .. ',' .. s.y
			end
			log(string.format('lodestone %d: crossing is %d step(s): %s',
				lode.id, #path, table.concat(desc, ' ')))
		end
	else
		-- the crystal is still on the floor: walk to it (this is the only walking in the
		-- room, and it is what puts us on the stones)
		path = D.lodePath(px, py, gx, gy, r.gapAt, 0, world.walk)
	end
	if not path or #path == 0 then
		log(string.format('lodestone %d: nothing to do from %d,%d (crystal %s, %d gap(s))',
			lode.id, px, py, held and 'held' or 'on the floor', #r.gaps))
		return false
	end
	local st = path[1]
	if st.via then
		-- ONE click per jump, then wait for it to land before anything else. The burst of
		-- repeats this used to do (a click every ~950 ms until the character moved) is
		-- what looked like a spamming bot; one deliberate click per pass is enough,
		-- because the next pass retries the same step if the client ignored it.
		say('jumping the gaps')
		log(string.format('lodestone %d: jump gap at %d,%d -> land %d,%d (player %d,%d, %d step(s) left)',
			lode.id, st.via.x, st.via.y, st.x, st.y, px, py, #path))
		local g = D.lodeGapAt(st.via.x, st.via.y)
		if not g then
			log(string.format('lodestone %d: no "Jump-over" object on %d,%d - rescanning',
				lode.id, st.via.x, st.via.y))
			D.dirty = true
			return true
		end
		-- Jumps are swallowed often, so retry the SAME step a few times inside this pass
		-- instead of spending a whole world scan between attempts: without this the room
		-- needed dozens of passes to make one hop.
		for attempt = 1, 3 do
			if D.clickObject('Jump-over', g) then
				API.RandomSleep2(900, 300, 400)   -- the jump animation plus the landing
				settle()
				local ax, ay = ptile()
				if ax ~= px or ay ~= py then break end
				log(string.format('lodestone %d: the jump at %d,%d did not take (try %d/3)',
					lode.id, st.via.x, st.via.y, attempt))
			else
				-- the click gate refused it (too soon after the last one on this tile)
				API.RandomSleep2(1000, 200, 400)
			end
			-- the puzzle re-creates its gap objects, so re-resolve before clicking again
			g = D.lodeGapAt(st.via.x, st.via.y) or g
		end
		D.dirty = true
		return true
	end
	-- The only non-jump move in this room: the step(s) that put us on a stone. They are
	-- collapsed into ONE tile click, never a walk across the room.
	local last = st
	for i = 2, #path do
		if path[i].via then break end
		last = path[i]
	end
	say('stepping onto the stones')
	log(string.format('lodestone %d: step %d,%d -> %d,%d to reach the stones (player %d,%d)',
		lode.id, px, py, last.x, last.y, px, py))
	D.walkTile(last.x, last.y, 0)
	API.RandomSleep2(900, 300, 500)
	settle()
	D.dirty = true
	return true
end

--------------------------------------------------------------------
-- puzzles: follow the leader (FallowTheLeader.java)
--------------------------------------------------------------------
-- A "Statue" npc runs this room: it performs an emote, and the player must stand
-- on the pad nearest it and answer with the same emote from the 5-entry menu that
-- opens there. The broken statues stand by the dead pads and must never be taken
-- for the leader.
D.LEADER_IDS = { 12114, 10966, 10967, 10968 }
D.LEADER_SET = {}
for i = 1, #D.LEADER_IDS do D.LEADER_SET[D.LEADER_IDS[i]] = true end
D.LEADER_PADS = { 52206, 54282 }
D.LEADER_PAD_SET = {}
for i = 1, #D.LEADER_PADS do D.LEADER_PAD_SET[D.LEADER_PADS[i]] = true end
-- The emote menu is fixed: five entries, first one is key 1. The statue's
-- animation id is the only signal (FallowTheLeader: WAVE 863, NOD 855,
-- SHAKE 856, LAUGH 861, CRY 860).
D.LEADER_EMOTES = { [863] = 1, [855] = 2, [856] = 3, [861] = 4, [860] = 5 }
D.LEADER_LABELS = { [863] = 'Wave', [855] = 'Nod', [856] = 'Shake', [861] = 'Laugh', [860] = 'Cry' }
D.LEADER_NEEDED = 4          -- four copied emotes and the room is done
D.LEADER_POLLS = 6           -- statue reads per pass while standing on the pad
D.LEADER_POLL_MS = 180
D.LEADER_SLACK = 3
D.LEADER_NEAR = 12           -- the statue must be this close: a statue across the room
                             -- (or across the fused floor) is not ours to work yet
D.LEADER_WALK_TRIES = 3      -- walk passes onto one pad before it is written off
D.LEADER_IDLE_MS = 10000     -- on the pad this long with nothing to copy = done

function D.isLeader(n)
	-- read behind a pcall: these records come from the shared npc scan and an npc that died
	-- since throws from the userdata metamethod, which would kill the run - and this is now
	-- asked on every pass for every npc in the scan.
	local ok, id, nm = pcall(function() return n.Id, n.Name end)
	if not ok then return false end
	if D.LEADER_SET[id] then return true end
	local low = string.lower(nm or '')
	if string.find(low, 'broken', 1, true) then return false end
	return string.find(low, 'statue', 1, true) ~= nil
end

-- Statues standing in this room (id, tile, current animation id).
function D.roomStatues(here)
	local out = {}
	for _, n in ipairs(D.npcScan()) do
		if D.isLeader(n) then
			local ok, t = pcall(function() return n.Tile_XYZ end)
			if ok and t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= here.minx - D.LEADER_SLACK and x <= here.maxx + D.LEADER_SLACK
					and y >= here.miny - D.LEADER_SLACK and y <= here.maxy + D.LEADER_SLACK then
					out[#out + 1] = { id = n.Id, x = x, y = y, anim = n.Anim or -1 }
				end
			end
		end
	end
	return out
end

-- Pressure pads of this room, nearest to sx,sy first. Uses the shared cached object scan:
-- this is now asked on EVERY pass as the "is this my puzzle at all" gate, and a fresh
-- DLL sweep per pass was what the caches exist to avoid.
function D.roomPads(here, sx, sy)
	local out = {}
	for _, o in ipairs(D.objScan()) do
		if string.find(string.lower(o.Name or ''), 'pressure pad', 1, true) or D.LEADER_PAD_SET[o.Id] then
			local ok, t = pcall(function() return o.Tile_XYZ end)
			if ok and t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= here.minx - D.LEADER_SLACK and x <= here.maxx + D.LEADER_SLACK
					and y >= here.miny - D.LEADER_SLACK and y <= here.maxy + D.LEADER_SLACK then
					out[#out + 1] = { x = x, y = y, d = (x - sx) ^ 2 + (y - sy) ^ 2 }
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

-- One step: stand on the pad of the statue that is emoting, read its animation
-- while there, and answer with the matching menu key. Four answers (or
-- D.LEADER_IDLE_MS on the pad with nothing to copy) and the room is done.
function D.solveFollowLeader(world, here, px, py)
	if not here then return false end
	local k = rkey(here)
	local st = D.leaderState[k]
	if st and st.solved then return false end
	-- IS THIS MY PUZZLE AT ALL? Asked BEFORE anything else, and answered by the PRESSURE PAD,
	-- not by the statue: this solver shares the word "Statue" with the sliding-statue room,
	-- so a statue alone proves nothing. This gate is also why the status line stopped
	-- flashing "follow-the-leader": the solver used to `say()` a reason on every pass in every
	-- room without a statue ("follow-the-leader: no statue left"), and the branch right after
	-- it overwrote the Doing line at once - so the line flickered that text all over the floor
	-- while the bot was doing something else entirely.
	local earlyPads = D.roomPads(here, px, py)
	if #earlyPads == 0 then return false end
	if puzzleDone(here) then
		D.leaderState[k] = { solved = true }
		return false
	end

	local statues = D.roomStatues(here)
	st = st or {}
	D.leaderState[k] = st
	st.answered = st.answered or 0
	st.lastAnim = st.lastAnim or -1
	st.seen = st.seen or {}
	if #statues == 0 then
		if st.answered > 0 then
			st.solved = true
			D.dirty = true   -- layout changed: rebuild the walk set
			say('follow-the-leader: statue gone')
			log('follow the leader: leader statue is gone - room done')
		end
		return false
	end

	-- the statue that is emoting is the leader, its pad is the one to stand on
	local lx, ly = statues[1].x, statues[1].y
	for i = 1, #statues do
		if D.LEADER_EMOTES[statues[i].anim] then
			lx, ly = statues[i].x, statues[i].y
			break
		end
	end
	-- Rooms fuse through open doors, so "inside this room" can mean a statue twenty
	-- tiles away behind two walls. Working it from here only produces clicks that
	-- cannot land; wait until the walk actually brings us next to it.
	local far = (lx - px) ^ 2 + (ly - py) ^ 2
	if far > D.LEADER_NEAR * D.LEADER_NEAR then
		if st.farLogged ~= k .. lx .. ',' .. ly then
			st.farLogged = k .. lx .. ',' .. ly
			log(string.format('follow the leader: statue at %d,%d is %.0f tiles away (we are at %d,%d) - not working it from here',
				lx, ly, math.sqrt(far), px, py))
		end
		return false
	end

	-- nearest pad that has not already been written off - nearest to the STATUE, which is
	-- which pad the leader stands on. `earlyPads` was only the cheap "is this my puzzle"
	-- answer and is sorted from the player, so the distances are re-measured here.
	st.badPads = st.badPads or {}
	local pads, pad = {}, nil
	for i = 1, #earlyPads do
		local p = earlyPads[i]
		p.d = (p.x - lx) ^ 2 + (p.y - ly) ^ 2
		pads[#pads + 1] = p
	end
	table.sort(pads, function(a, b) return a.d < b.d end)
	for i = 1, #pads do
		if not st.badPads[pkey(pads[i].x, pads[i].y)] then
			pad = pads[i]
			break
		end
	end
	if not pad then
		st.solved = true
		D.dirty = true   -- layout changed: rebuild the walk set
		say('follow-the-leader: no pad works')
		log(string.format('follow the leader in room %s: every pad next to the statue failed - leaving it', k))
		return false
	end

	if px ~= pad.x or py ~= pad.y then
		local pk = pkey(pad.x, pad.y)
		st.padTries = st.padTries or {}
		st.padTries[pk] = (st.padTries[pk] or 0) + 1
		if st.padTries[pk] > D.LEADER_WALK_TRIES then
			st.badPads[pk] = true
			st.padTries[pk] = nil
			log(string.format('follow the leader: cannot get onto pad %d,%d after %d walks - next pad',
				pad.x, pad.y, D.LEADER_WALK_TRIES))
			return true
		end
		st.padAt = nil
		if st.padKey ~= pk then
			st.padKey = pk
			say('walking to the leader pad')
			log(string.format('follow the leader: pad %d,%d for the statue at %d,%d (try %d)',
				pad.x, pad.y, lx, ly, st.padTries[pk]))
		end
		D.walkTile(pad.x, pad.y, 0)
		API.RandomSleep2(700, 250, 400)
		settle()
		return true
	end

	-- on the pad: watch the statue and copy whatever it plays
	local ids = {}
	for i = 1, #statues do ids[i] = statues[i].id end
	st.padAt = st.padAt or API.SystemTime()
	for _ = 1, D.LEADER_POLLS do
		for _, n in ipairs(API.ReadAllObjectsArray({ 1 }, ids, {}, D.NO_REACH) or {}) do
			local a = n.Anim or -1
			if a == -1 then
				-- back to idle: the same emote may be played again and counts again
				if st.lastAnim ~= -1 then st.gap = true end
			elseif D.LEADER_EMOTES[a] then
				local t = API.SystemTime()
				local dup = (a == st.lastAnim) and not st.gap
					and st.pressedAt and (t - st.pressedAt < 4000)
				if not dup then
					st.lastAnim, st.gap, st.pressedAt, st.padAt = a, false, t, t
					st.answered = st.answered + 1
					say('copying ' .. D.LEADER_LABELS[a])
					log(string.format('follow the leader: statue %d plays %s (anim %d) -> key %d [%d/%d]',
						n.Id, D.LEADER_LABELS[a], a, D.LEADER_EMOTES[a], st.answered, D.LEADER_NEEDED))
					API.KeyboardPress2(0x30 + D.LEADER_EMOTES[a], 60, 30)
					API.RandomSleep2(600, 200, 300)
				end
			elseif not st.seen[a] then
				st.seen[a] = true
				log(string.format('follow the leader: statue %d anim %d is not an emote', n.Id, a))
			end
			if st.answered >= D.LEADER_NEEDED then break end
		end
		if st.answered >= D.LEADER_NEEDED then break end
		API.RandomSleep2(D.LEADER_POLL_MS, 40, 60)
	end

	if st.answered >= D.LEADER_NEEDED then
		st.solved = true
		D.dirty = true   -- layout changed: rebuild the walk set
		say('follow-the-leader done')
		log(string.format('follow the leader in room %s: %d emotes copied - room done', k, st.answered))
		return false
	end
	if API.SystemTime() - st.padAt > D.LEADER_IDLE_MS then
		st.solved = true
		D.dirty = true   -- layout changed: rebuild the walk set
		say('follow-the-leader done')
		log(string.format('follow the leader in room %s: %ds on the pad with nothing to copy - room done',
			k, math.floor(D.LEADER_IDLE_MS / 1000)))
		return false
	end
	say('watching the statue')
	return true
end

--------------------------------------------------------------------
-- puzzles: suspicious grooves (GrooveSpike.java ids, real rule from the wiki)
--------------------------------------------------------------------
-- Three rows of grooves separate the entrance from the room. Only ONE groove per
-- row is safe: checking it turns the object into plain "Grooves" (no option, just
-- walkable), and that tile is the crossing. The other three stay trapped - checking
-- one sets its trap off from a distance ("There's definitely a trap here"), which
-- is harmless but not the way through.
--
-- Deliberately NO id table: the java list (GrooveSpike.java) is stub code and does
-- not match every floor, and a puzzle that is not recognised is worse than one that
-- is a bit generic. Grooves are found by NAME and their state is read from the
-- object itself, so any variant works.
D.GROOVE_SLACK = 3
D.GROOVE_MAX_TRIES = 40
D.GROOVE_ROWS = 3             -- three rows, one safe groove each: all three found = done
D.GROOVE_CHECK_WAIT = 2200    -- a check takes a moment to answer; never click on top of it
D.GROOVE_RETRY = 2            -- a groove that ignored the click may be clicked again
D.GROOVE_RELOOKS = 3          -- a room that answered nothing gets this many clean re-looks
D.GROOVE_RELOOK_MS = 20000    -- ... no more often than this
D.GROOVE_SILENT_MAX = 6       -- investigations in a row with no answer at all: give the room up

-- Three kinds of groove object, straight from the live room:
--   67120 "Suspicious grooves" (Step-onto)  -> still trapped, can be CHECKED
--   67097 "Suspicious grooves" ()           -> trapped, not clickable right now
--   67099 "Grooves"             ()          -> disabled, this is the crossing tile
-- So "has no option" does NOT mean safe - the NAME does: only a groove that is no
-- longer "suspicious" may be walked on.
function D.grooveKind(o)
	local nm = string.lower(o.Name or '')
	if not string.find(nm, 'groove', 1, true) then return nil end
	if string.find(nm, 'suspicious', 1, true) then
		if (o.Bool1 or 0) ~= 1 and (o.Action or '') ~= '' then return 'check' end
		return 'trap'
	end
	return 'open'
end

-- Live state of one groove tile: the check answer renames the object, so this is
-- how a check result is read back.
function D.grooveAt(x, y)
	for _, o in ipairs(API.ReadAllObjectsArray(D.OBJ_TYPES, {}, {}, D.NO_REACH) or {}) do
		local t = o.Tile_XYZ
		if math.floor(t.x) == x and math.floor(t.y) == y then
			local kind = D.grooveKind(o)
			if kind then return { id = o.Id, name = o.Name, kind = kind } end
		end
	end
	return nil
end

-- Grooves come in rows of four; only one groove per row is safe. Rows are the
-- set of grooves sharing one coordinate - whichever axis repeats more is the row
-- axis. Returned nearest row first.
function D.grooveRows(list)
	local yc, xc, ny, nx = {}, {}, 0, 0
	for _, g in ipairs(list) do
		yc[g.y] = (yc[g.y] or 0) + 1
		xc[g.x] = (xc[g.x] or 0) + 1
	end
	for _, c in pairs(yc) do if c > ny then ny = c end end
	for _, c in pairs(xc) do if c > nx then nx = c end end
	local byY = ny >= nx
	local rows, order = {}, {}
	for _, g in ipairs(list) do
		local k = byY and ('y' .. g.y) or ('x' .. g.x)
		if not rows[k] then
			rows[k] = { key = k, list = {}, d = math.huge }
			order[#order + 1] = k
		end
		local r = rows[k]
		r.list[#r.list + 1] = g
		if g.d < r.d then r.d = g.d end
	end
	table.sort(order, function(a, b) return rows[a].d < rows[b].d end)
	local out = {}
	for i = 1, #order do out[i] = rows[order[i]] end
	return out
end

-- One step. Returns true whenever the room is a groove room, so the loop keeps
-- working it until every row's safe groove is known.
-- The room is done the moment all three safe grooves are DISCOVERED - the tiles
-- are free to walk afterwards, so there is no reason to ever click one of them.
function D.solveGrooves(world, here, px, py)
	if not here then return false end
	local key = rkey(here)
	local st = puzzleOwn(key, 'grooves')
	if st and st.solved then return false end
	if puzzleDone(here) then
		S.pondState[key] = { solved = true }
		return false
	end

	-- every groove of this room, nearest first
	local list = {}
	local function collect(box)
		for _, o in ipairs(API.ReadAllObjectsArray(D.OBJ_TYPES, {}, {}, D.NO_REACH) or {}) do
			if string.find(string.lower(o.Name or ''), 'groove', 1, true) then
				local t = o.Tile_XYZ
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= box.minx and x <= box.maxx and y >= box.miny and y <= box.maxy then
					list[#list + 1] = {
						id = o.Id, x = x, y = y, name = o.Name,
						kind = D.grooveKind(o),
						act = (o.Action or ''),
						d = (x - px) ^ 2 + (y - py) ^ 2,
					}
				end
			end
		end
	end
	collect({ minx = here.minx - D.GROOVE_SLACK, maxx = here.maxx + D.GROOVE_SLACK,
		miny = here.miny - D.GROOVE_SLACK, maxy = here.maxy + D.GROOVE_SLACK })
	if #list == 0 then
		-- THE ROOM BLOB IS NOT THE PUZZLE. Room keys are minx:miny of a segmentation that
		-- splits and merges whenever a doorway opens, so the box can miss the grooves that
		-- are standing right beside the player - and the solver then returned "not my
		-- puzzle" without a word while the prop gate kept standing the walker down for the
		-- same grooves. That is a room nobody can act in: the solver refuses it and the
		-- walker refuses to leave it. Fall back to what is within reach of the player, and
		-- say so, because silently deciding this is what hid the bug.
		local near = D.PUZZLE_NEAR or 6
		collect({ minx = px - near, maxx = px + near, miny = py - near, maxy = py + near })
		if #list > 0 then
			D.grooveBoxLog = D.grooveBoxLog or {}
			if not D.grooveBoxLog[key] then
				D.grooveBoxLog[key] = true
				log(string.format(
					'grooves in room %s: none inside the room box - using the %d groove(s) within %d tiles of the player at %d,%d',
					key, #list, near, px, py))
			end
		end
	end
	if #list == 0 then return false end
	table.sort(list, function(a, b) return a.d < b.d end)

	st = puzzleClaim(key, 'grooves', { checked = {}, tries = 0 })
	if not st then return false end
	st.checked = st.checked or {}
	st.tries = st.tries or 0
	-- WHAT THE GAME ANSWERED, per tile. The object keeps its "Suspicious grooves" name
	-- after an investigation on this floor, so the chat is the only record of which tile
	-- is safe and which is trapped - and a trapped tile must never be stepped on again.
	-- Keyed by tile so it survives the list being rebuilt every pass.
	st.safe = st.safe or {}
	st.trap = st.trap or {}
	-- AN ANSWER THAT ARRIVES LATE BELONGS TO THE TILE WE LAST INVESTIGATED, not to the one
	-- we are about to click. The game answers a second or two after the click and the chat
	-- pump runs once per pass, so a slow answer can land between two investigations; reading
	-- it after the next click would file a trap as safe (or the other way round) and send
	-- the player onto the wrong tile. `pending` is that last tile, with the sequence numbers
	-- the answer has to beat.
	if st.pending then
		drainChat()
		local p = st.pending
		local got = nil
		if (chat.grooveSafe or 0) > (p.s or 0) then
			st.safe[pkey(p.x, p.y)] = true
			got = 'safe'
		elseif (chat.grooveTrap or 0) > (p.t or 0) then
			st.trap[pkey(p.x, p.y)] = true
			got = 'trap'
		end
		if got then
			st.pending = nil
			-- A LATE ANSWER IS STILL AN ANSWER. Without this the silence counter kept
			-- climbing on investigations that were actually answered a second later, and
			-- after six of them the solver declared "the game is not answering" and latched
			-- the room - leaving an unsolved groove puzzle the walker then stood down for
			-- on every pass ("it cannot formulate a plan").
			st.silent = 0
			log(string.format('grooves: %d,%d answered %s (late, from the previous check)',
				p.x, p.y, string.upper(got)))
		end
	end
	S.pondState[key] = st
	if st.tries >= D.GROOVE_MAX_TRIES then
		st.solved = true
		D.dirty = true   -- layout changed: rebuild the walk set
		say('grooves: giving up')
		log(string.format('grooves in room %s: %d tries, moving on', key, st.tries))
		return false
	end

	-- A row is done as soon as one of its grooves is KNOWN safe - either because the
	-- object stopped being suspicious (the old signal, which this game build does not
	-- produce) or because the chat said so for that tile.
	local function answeredSafe(g) return st.safe[pkey(g.x, g.y)] == true end
	local function answeredTrap(g) return st.trap[pkey(g.x, g.y)] == true end
	local rows, missing, foundN = D.grooveRows(list), nil, 0
	for i = 1, #rows do
		local open = false
		for _, g in ipairs(rows[i].list) do
			if g.kind == 'open' or answeredSafe(g) then open = true break end
		end
		if open then
			foundN = foundN + 1
		elseif not missing then
			missing = rows[i]
		end
	end
	if foundN >= D.GROOVE_ROWS then
		st.solved = true
		D.dirty = true   -- layout changed: rebuild the walk set
		say('grooves: done')
		-- Name the tiles: the crossing is one safe groove per row, and printing them is
		-- what makes the next log readable ("it walked into a groove row and the traps
		-- fired" can be checked against the answer the bot recorded).
		local fixes = {}
		for i = 1, #rows do
			for _, g in ipairs(rows[i].list) do
				if g.kind == 'open' or answeredSafe(g) then
					fixes[#fixes + 1] = string.format('%d,%d', g.x, g.y)
					break
				end
			end
		end
		log(string.format('grooves in room %s: %d of %d safe grooves found (%s) - room is open, walking freely',
			key, foundN, D.GROOVE_ROWS, table.concat(fixes, ' ')))
		return false
	end

	-- check a suspicious groove of the nearest row that still has none found
	-- SIX INVESTIGATIONS IN A ROW WITH NO ANSWER means the game is not answering this room
	-- at all (the chat line is what carries the answer, and on this build the object never
	-- renames itself). Walking every groove twice and then starting over produced 90+
	-- silent clicks per room before this - which is what "it fails to detect the puzzle"
	-- looks like from outside.
	if (st.silent or 0) >= D.GROOVE_SILENT_MAX then
		st.solved = true
		D.dirty = true   -- layout changed: rebuild the walk set
		say('grooves: the game is not answering')
		log(string.format(
			'grooves in room %s: %d investigations in a row got no answer - leaving the room rather than clicking every groove for ever',
			key, st.silent))
		return false
	end
	local cand
	while missing and not cand do
		for _, g in ipairs(missing.list) do
			if g.kind == 'check' and not answeredSafe(g) and not answeredTrap(g)
				and (st.checked[pkey(g.x, g.y)] or 0) < D.GROOVE_RETRY then
				cand = g
				break
			end
		end
		if not cand then
			local nextRow
			for i = 1, #rows do
				local r = rows[i]
				if r.key ~= missing.key then
					local hasOpen, hasCheck = false, false
					for _, g in ipairs(r.list) do
						if g.kind == 'open' or answeredSafe(g) then hasOpen = true end
						if g.kind == 'check' and not answeredSafe(g) and not answeredTrap(g)
							and (st.checked[pkey(g.x, g.y)] or 0) < D.GROOVE_RETRY then
							hasCheck = true
						end
					end
					if not hasOpen and hasCheck then nextRow = r break end
				end
			end
			missing = nextRow
		end
	end
	if not cand then
		-- NOTHING LEFT TO CHECK. Only call the room solved when the puzzle is really
		-- answered - one known-safe tile per row. Marking it solved with nothing learned is
		-- what made the room unrecoverable for the rest of the floor: the solver latches per
		-- room and never looks again, which from outside is exactly "fails to detect the
		-- suspicious grooves puzzle" in a room it had already investigated.
		local safeRows = 0
		for i = 1, #rows do
			for _, g in ipairs(rows[i].list) do
				if g.kind == 'open' or answeredSafe(g) then safeRows = safeRows + 1 break end
			end
		end
		if safeRows >= D.GROOVE_ROWS then
			st.solved = true
			D.dirty = true   -- layout changed: rebuild the walk set
			say('grooves: done')
			log(string.format('grooves in room %s: %d of %d safe grooves found - room is open, walking freely',
				key, safeRows, D.GROOVE_ROWS))
			return false
		end
		local now = API.SystemTime()
		st.passes = (st.passes or 0) + 1
		if st.passes <= D.GROOVE_RELOOKS and (now - (st.retryAt or 0)) > D.GROOVE_RELOOK_MS then
			-- ONE CLEAN RE-LOOK. A chat answer can be missed (the line is drained by the
			-- main loop, or the click was refused and nothing was said), and with every tile
			-- already at its retry count the room would go quiet for the rest of the floor.
			st.retryAt = now
			st.checked = {}
			log(string.format(
				'grooves in room %s: nothing left to check and only %d of %d rows known - re-checking the room (pass %d/%d)',
				key, safeRows, D.GROOVE_ROWS, st.passes, D.GROOVE_RELOOKS))
			return false
		end
		st.solved = true
		D.dirty = true   -- layout changed: rebuild the walk set
		say('grooves: giving up')
		log(string.format('grooves in room %s: %d groove(s), %d of %d rows known and no answer left - leaving it',
			key, #list, safeRows, D.GROOVE_ROWS))
		return false
	end

	st.tries = st.tries + 1
	st.checked[pkey(cand.x, cand.y)] = (st.checked[pkey(cand.x, cand.y)] or 0) + 1
	say('checking a groove')
	log(string.format('grooves: checking %d "%s" at %d,%d (try %d)',
		cand.id, tostring(cand.name), cand.x, cand.y, st.tries))
	settle()
	-- Ask for the action the object actually offers. Live, the suspicious groove only
	-- offered "Step-onto / Investigate / Examine", so every pass logged a failed
	-- "action 'Check' was unavailable" before falling back to Investigate.
	local nm = (cand.name and cand.name ~= '' and cand.name) or 'Grooves'
	local beforeSafe, beforeTrap = chat.grooveSafe or 0, chat.grooveTrap or 0
	-- Remember which tile the next answer belongs to, in case it lands after the wait.
	st.pending = { x = cand.x, y = cand.y, s = beforeSafe, t = beforeTrap }
	-- The scanned action word is the FIRST option ("Step-onto"), so it cannot be used
	-- directly. Only an object that literally offers "Check" is clicked with Check; every
	-- other variant gets Investigate first, which is the option the game actually shows
	-- (live: "action 'Check' was unavailable for nearby IDs 67120; available actions:
	-- Step-onto, Investigate, Examine" - one failed action on every single attempt).
	if (cand.act or '') == 'Check' then
		if not Interact:Object(nm, 'Check', FFPOINT.new(cand.x, cand.y, 0), 20) then
			Interact:Object(nm, 'Investigate', FFPOINT.new(cand.x, cand.y, 0), 20)
		end
	elseif not Interact:Object(nm, 'Investigate', FFPOINT.new(cand.x, cand.y, 0), 20) then
		Interact:Object(nm, 'Check', FFPOINT.new(cand.x, cand.y, 0), 20)
	end
	-- the answer is a chat line plus a rename, so give it time and read both back
	API.RandomSleep2(D.GROOVE_CHECK_WAIT, 900, 1400)
	settle()
	-- PUMP THE CHAT HERE. drainChat runs once per main-loop pass, and this solver is
	-- *inside* that pass, so without this the answer we just waited 2.2s for is still
	-- sitting in the client's buffer and every read below answers "nothing".
	drainChat()
	local answered = nil
	if (chat.grooveSafe or 0) > beforeSafe then
		answered = 'safe'
		st.safe[pkey(cand.x, cand.y)] = true
		st.pending = nil
		st.silent = 0
		log(string.format('grooves: %d,%d answered SAFE (chat) - that tile is this row\'s crossing',
			cand.x, cand.y))
	elseif (chat.grooveTrap or 0) > beforeTrap then
		answered = 'trap'
		st.trap[pkey(cand.x, cand.y)] = true
		st.pending = nil
		st.silent = 0
		log(string.format('grooves: %d,%d answered TRAPPED (chat) - never stepping on it',
			cand.x, cand.y))
	end
	if not answered then
		st.silent = (st.silent or 0) + 1
	end
	local after = D.grooveAt(cand.x, cand.y)
	if after then
		log(string.format('grooves: %d,%d answered "%s" (%s)%s', cand.x, cand.y,
			tostring(after.name), tostring(after.kind),
			answered and (' - chat: ' .. answered) or ''))
	elseif not answered then
		-- No chat answer and no object left to read: the click went nowhere. Say so,
		-- because "the puzzle is not detected" and "the click was refused" look the
		-- same from outside - and the refused-action line comes from the DLL, not here.
		log(string.format('grooves: %d,%d gave no answer at all (no chat line, no object) - the click was refused or still in flight',
			cand.x, cand.y))
	end
	API.RandomSleep2(900, 400, 700)
	return true
end

--------------------------------------------------------------------
-- puzzles: three weapon statues (ThreeWeapionStatus.java)
--------------------------------------------------------------------
-- Three statues, one per combat style, each missing its weapon. The matching
-- stone weapon is carved out of a Stone block (mined from the room's Crumbling
-- wall) and handed over with the statue's own "Arm" option - which is why the
-- statue must be armed where it stands and cannot be solved from across the floor.
--
-- THE "Arm" OPTION IS THE ROOM'S STATE: a statue that still offers it is unarmed,
-- and an armed one offers nothing (live: unarmed melee statue 11038 says "Arm" while
-- 11047/11050 in the same room say nothing). So the room is finished exactly when no
-- statue in it offers "Arm" any more - and one that does cancels a "solved" mark.
--
-- Carving: the block's first inventory option is "Carve", which opens the
-- three-way menu (interface 1188) where the choice is 1 sword, 2 bow, 3 staff.
D.STATUE_KIND = {}
for _, id in ipairs({ 11036, 11037, 11038 }) do D.STATUE_KIND[id] = 'melee' end
for _, id in ipairs({ 11039, 11040, 11041, 12095 }) do D.STATUE_KIND[id] = 'range' end
for _, id in ipairs({ 11042, 11043, 11044 }) do D.STATUE_KIND[id] = 'mage' end
D.STATUE_WEAPON = { melee = 17416, range = 17418, mage = 17420 }  -- sword / bow / staff
-- "Carve" (option 1) opens the three-way menu; the menu itself is 1 sword,
-- 2 bow, 3 staff. The stone block's other inventory options ("Carve sword" etc.)
-- are shortcuts that need the right index, so the menu route is the one used.
D.STATUE_MENU      = 1188
D.STATUE_MENU_KEY  = { melee = 1, range = 2, mage = 3 }
D.STATUE_STONE  = 17415           -- "Stone block"
D.STATUE_CHISEL = 17444
D.STATUE_WALLS  = { 49649, 49648, 49647, 53991 }
D.STATUE_WALL_SET = {}
for _, id in ipairs(D.STATUE_WALLS) do D.STATUE_WALL_SET[id] = true end
D.STATUE_SLACK  = 3
D.STATUE_TRIES  = 4
D.STATUE_MINE_TRIES = 8    -- Mine clicks that may give nothing before the wall is left
D.STATUE_MINE_ANIM_MS = 4000  -- the pickaxe swing, waited for and waited out
D.STATUE_WALL_WAIT = 6     -- passes to wait for a mined wall to respawn before leaving

-- One step. Returns true while this room still owns us.
function D.solveStatues(world, here, px, py)
	if not here then return false end
	local key = rkey(here)
	local st = S.pondState[key]
	-- S.pondState is shared by every puzzle, keyed by room. Only the solver that owns
	-- the room may touch it: without this the statue solver found "state exists and no
	-- statue" in a lever room and declared "every statue is armed - room done", which
	-- stopped the lever solver after one pull.
	if st and st.kind and st.kind ~= 'statues' then return false end

	-- "Arm" ON A STATUE IS THE PROOF IT IS STILL UNARMED - the option is the answer, not
	-- the id and not a remembered flag. An armed statue loses it (live: the unarmed melee
	-- statue 11038 says "Arm" while the armed statues standing in the same room say
	-- nothing), so this scan decides the room either way:
	--   one statue still says "Arm"  ->  the room is NOT done, even if it was marked done
	--                                    earlier, and that mark is cleared
	--   no statue says "Arm"         ->  every statue is armed, the room is finished
	-- the chosen record is clicked later, so its scan is pinned
	local target, kind, armCount = nil, nil, 0
	for _, n in ipairs(D.keepScan(API.ReadAllObjectsArray({ 1 }, {}, {}, D.NO_REACH)) or {}) do
		if D.objGet(n, 'Action') == 'Arm' then
			local t = n.Tile_XYZ
			if t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= here.minx - D.STATUE_SLACK and x <= here.maxx + D.STATUE_SLACK
					and y >= here.miny - D.STATUE_SLACK and y <= here.maxy + D.STATUE_SLACK then
					armCount = armCount + 1
					local k = D.STATUE_KIND[tonumber(n.Id)]
					if k and not target then target, kind = n, k end
				end
			end
		end
	end
	if armCount > 0 then
		st = st or {}
		st.kind = st.kind or 'statues'
		S.pondState[key] = st
		if st.solved then
			st.solved = nil
			D.dirty = true
			log(string.format('statues in room %s: a statue still offers "Arm" - the room is not done after all',
				key))
		end
	end
	if st and st.solved then return false end
	if armCount == 0 then
		-- no statue in this room offers "Arm" any more: the puzzle is finished - but only
		-- a room this solver was actually working on can be declared done
		if st and st.kind == 'statues' then
			st.solved = true
			D.dirty = true
			log(string.format('statues in room %s: every statue is armed - room done', key))
		end
		return false
	end
	if not target then
		-- a statue is unarmed but its id is not one this script knows, so there is no
		-- telling which weapon it wants: say so instead of calling the room finished
		if not st.unknownSaid then
			st.unknownSaid = true
			log(string.format('statues in room %s: %d statue(s) offer "Arm" but none has a known id - cannot pick a weapon',
				key, armCount))
		end
		return false
	end

	st = st or {}
	st.kind = st.kind or 'statues'
	st.tries = st.tries or {}
	st.tries[kind] = st.tries[kind] or 0
	S.pondState[key] = st

	local weapon = D.STATUE_WEAPON[kind]
	if Inventory:Contains(weapon) then
		if st.tries[kind] >= D.STATUE_TRIES then
			log(string.format('statues: the %s statue at %d,%d did not take the weapon after %d tries - leaving it',
				kind, math.floor(target.Tile_XYZ.x), math.floor(target.Tile_XYZ.y), st.tries[kind]))
			return false
		end
		-- NO WALKING TO THE STATUE. This is not a melee-range game: DoAction_NPC with a
		-- 50-tile search sends the click and the client walks the player over itself, so a
		-- pre-walk only spends a pass to arrive at the same click.
		st.tries[kind] = st.tries[kind] + 1
		settle()
		say('arming the ' .. kind .. ' statue')
		log(string.format('statues: arming statue %d (%s) with weapon %d (try %d)',
			target.Id, kind, weapon, st.tries[kind]))
		-- "Arm" is the statue's first option
		API.DoAction_NPC(D.ACT_TALK, D.ROUTE_TALK, { target.Id }, 50)
		API.RandomSleep2(1300, 500, 800)
		settle()
		return true
	end

	if Inventory:Contains(D.STATUE_STONE) then
		st.carves = st.carves or 0
		if st.carves >= D.STATUE_TRIES then
			log(string.format('statues: stone block will not turn into a %s weapon (%d tries, chisel missing?)',
				kind, st.carves))
			return false
		end
		st.carves = (st.carves or 0) + 1
		settle()
		say('carving a ' .. kind .. ' weapon')
		log(string.format('statues: carving the stone block (option 1 "Carve"), then choosing %s (key %d, try %d)',
			kind, D.STATUE_MENU_KEY[kind], st.carves))
		-- Inventory class resolves the block by id, so no slot maths is needed.
		Inventory:DoAction(D.STATUE_STONE, 1, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(900, 350, 650)
		settle()
		if API.GetInterfaceOpenBySize(D.STATUE_MENU) then
			API.KeyboardPress2(0x30 + D.STATUE_MENU_KEY[kind], 60, 30)
			API.RandomSleep2(1200, 400, 800)
		else
			log(string.format('statues: carve menu %d did not open', D.STATUE_MENU))
		end
		settle()
		if not Inventory:Contains(weapon) then
			log(string.format('statues: still %d stone block(s) and %d %s weapon(s) after the carve',
				Inventory:InvItemcount(D.STATUE_STONE), Inventory:InvItemcount(weapon), kind))
		end
		return true
	end

	-- no weapon and no block: mine this room's crumbling wall for one. Live: the wall is
	-- DECOR 49649 "Crumbling wall", action "Mine", and it stands across the room (9 tiles
	-- away when the statues were 2) - so the click needs a walk first, a standstill to be
	-- accepted at all, and an animation to prove it landed.
	local wall, wallD
	for _, o in ipairs(D.keepScan(API.ReadAllObjectsArray(D.OBJ_TYPES, D.STATUE_WALLS, {}, D.NO_REACH)) or {}) do
		local wid = tonumber(o.Id)
		local t = o.Tile_XYZ
		-- REFUSE A RECORD THAT IS NOT A WALL. A scan called with a missing type list once
		-- handed back id 1 with a junk name ("Space??X??race" in the doaction log) and the
		-- solver mined that for seven tries; the id test costs nothing and stops it.
		if wid and D.STATUE_WALL_SET[wid] and t then
			local x, y = math.floor(t.x), math.floor(t.y)
			if x >= here.minx - D.STATUE_SLACK and x <= here.maxx + D.STATUE_SLACK
				and y >= here.miny - D.STATUE_SLACK and y <= here.maxy + D.STATUE_SLACK then
				local d = math.max(math.abs(x - px), math.abs(y - py))
				if not wallD or d < wallD then
					wall = { id = wid, x = x, y = y, z = math.floor(t.z or 0), name = o.Name,
						action = o.Action, obj = o, d = d }
					wallD = d
				end
			end
		end
	end
	if not wall then
		-- a mined wall respawns, so "not there right now" is not "this room is finished"
		st.noWallTries = (st.noWallTries or 0) + 1
		if st.noWallTries <= D.STATUE_WALL_WAIT then
			if st.noWallTries == 1 then
				say('statues: waiting for the crumbling wall')
				log(string.format('statues in room %s: no crumbling wall in the room right now - waiting for it to respawn',
					key))
			end
			API.RandomSleep2(1500, 500, 900)
			return true
		end
		if not st.noWall then
			st.noWall = true
			say('statues: nothing to mine here')
			log(string.format('statues in room %s: no stone block, no %s weapon and no crumbling wall after %d checks - leaving it',
				key, kind, st.noWallTries))
		end
		return false
	end
	-- OUT OF REACH IS NOT A THING HERE: the wall is clicked from wherever we stand and the
	-- client walks the player over by itself, exactly like the statues. Nothing is walked
	-- to by hand in this room.
	-- MOVEMENT/ANIMATION CHECK: a click sent out of a walk is eaten by the walk, and one
	-- sent over a running animation is dropped
	if isMoving() or (D.walkLive and D.walkLive()) or D.playerBusy() then
		API.RandomSleep2(200, 80, 120)
		return true
	end
	if (st.mines or 0) >= D.STATUE_MINE_TRIES then
		log(string.format('statues: crumbling wall %d at %d,%d gave nothing after %d clicks - leaving it',
			wall.id, wall.x, wall.y, st.mines))
		return false
	end
	settle()
	-- the record must actually offer the option we are about to send
	if wall.action and wall.action ~= 'Mine' and wall.action ~= '' then
		log(string.format('statues: wall %d at %d,%d offers "%s", not "Mine" - waiting for it to respawn',
			wall.id, wall.x, wall.y, tostring(wall.action)))
		API.RandomSleep2(1500, 500, 900)
		return true
	end
	say('mining the crumbling wall')
	if not D.clickObject('Mine', wall.obj) then
		-- D.clickObject refused (its own click cap, or the tile does not allow it): do not
		-- spend a mine on a click that was never sent
		log(string.format('statues: the Mine click on %d at %d,%d was not sent - retrying next pass',
			wall.id, wall.x, wall.y))
		return true
	end
	st.mines = (st.mines or 0) + 1
	log(string.format('statues: mining %d "%s" at %d,%d for a stone block (try %d/%d)',
		wall.id, tostring(wall.name), wall.x, wall.y, st.mines, D.STATUE_MINE_TRIES))
	-- ANIMATION CHECK: mining plays a pickaxe swing; if none starts the click did nothing
	if not D.waitAnimStart(D.STATUE_MINE_ANIM_MS) then
		log(string.format('statues: no mining animation after clicking %d at %d,%d - the click did not land',
			wall.id, wall.x, wall.y))
	end
	D.waitAnim(D.STATUE_MINE_ANIM_MS)
	settle()
	return true
end

--------------------------------------------------------------------
-- puzzles: sliding statues (SilidingStatues.java)
--------------------------------------------------------------------
-- Eight "Statue" npcs in four pairs: a fixed one and a sliding one. The sliding
-- statue is pushed one tile at a time until the four of them stand in the SAME
-- arrangement as the fixed four - the whole pattern translated, never mirrored -
-- and then the room is done. The wiki's warning is the whole puzzle: "duplicate
-- the position of the movable statues to the stationary statues, instead of
-- mirroring them".
--
-- Pushing is the only verb needed. A push always moves the statue ONE tile
-- straight away from the player, and the player then stands on the tile the
-- statue left (verified live: statue 10965 at 7084,261 pushed from 7084,262 went
-- to 7084,260 and the player ended up on 7084,261 - exactly the barrel npc's
-- behaviour, which is why this reads like barrelPush). That covers all four
-- directions by standing on the far side, so the right-click "Pull" is never
-- needed and is not used.
--
-- The pair is the ID, not the distance. The ids come in runs of four, one per
-- statue of the room, and the same index inside the fixed run and inside the
-- sliding run is the same pair:
--
--   10942 10943 10944 10945 | 10946 10947 10948 10949 | 10950 10951 10952 10953
--   10954 10955 10956 10957 | 10958 10959 10960 10961 | 10962 10963 10964 10965
--
-- i.e. three model runs of four facings each; the k-th fixed statue of a run is
-- partnered with the k-th sliding one (live: 10950/10962, 10951/10963,
-- 10952/10964, 10953/10965). That is also what "duplicate the position" means -
-- pair k and pair j keep the same relative offset. Proximity is only the
-- fallback, for a room that mixes two of the three model runs.
--
-- Where a statue belongs: 7 tiles from its fixed partner, in the direction the
-- fixed row faces (the java's getSolution() is exactly this, with the offset it
-- reads from the statue's orientation via getOffset()/ver()). The direction is
-- taken from the room here instead of from an orientation reading: the four
-- candidates are scored by which one puts floor under the most goal tiles, with
-- the fixed-row-to-sliding-row direction breaking ties, so no degree convention
-- has to be trusted. Live check (room 7073-7086 x 257-270: fixed statues at
-- y 265-267, sliding ones at y 259-262, south wall at y 256) - "7 to the south"
-- is the only candidate whose four goals are all inside this room, and they land
-- at y 258-260, the south half the sliding statues already stand in. Those four
-- tiles are 7078,258 / 7075,260 / 7081,258 / 7083,259, and pushing the four
-- statues onto them finished the room: "You hear a click as the last statue is
-- moved into place. All the doors in the room are now unlocked." (which is the
-- "now unlocked" line D.CHAT_SOLVED already listens for, so the room is marked
-- solved by the chat rule as well as by the check below).
--
-- A statue does not move if the tile it is pushed onto is held by a monster or a
-- player, and the wall answers "You can't push that there."; either way the
-- animation plays and the statue stays. A push that decides the same thing twice
-- is therefore counted, and a pair that will not move is written off instead of
-- being clicked for ever.
D.SLIDE_FIXED = { 10942, 10953 }   -- 10942..10953: three model runs, four statues each
D.SLIDE_FREE = { 10954, 10965 }    -- 10954..10965: the same runs, the sliding half
D.SLIDE_GAP = 7                    -- the two rows of statues stand this far apart
D.SLIDE_SLACK = 3                  -- a statue stands on its own (unwalkable) tile
D.SLIDE_PUSH_WAIT = 5000           -- one push: animation, the slide and our step
D.SLIDE_SETTLE_MS = 1500           -- a repeat decision inside this is latency, not failure
D.SLIDE_TRIES = 3                  -- pushes that changed nothing before a pair is given up
D.SLIDE_PAIRS = 4                  -- only a full room may be declared finished
-- id -> index of the statue inside its run (1..4). Table fields, not locals: this
-- file's chunk belongs to Dung.lua's local budget.
D.SLIDE_FIXED_IDX, D.SLIDE_FREE_IDX = {}, {}
for id = D.SLIDE_FIXED[1], D.SLIDE_FIXED[2] do
	D.SLIDE_FIXED_IDX[id] = (id - D.SLIDE_FIXED[1]) % 4 + 1
end
for id = D.SLIDE_FREE[1], D.SLIDE_FREE[2] do
	D.SLIDE_FREE_IDX[id] = (id - D.SLIDE_FREE[1]) % 4 + 1
end

-- The statues of this room, split into fixed and sliding. Judged against the
-- room's bounds, not its walk set: a statue stands on a tile the player cannot
-- walk onto. The sliding ones are also the ones whose first option is "Push".
function D.slideStatues(here)
	local fixed, free = {}, {}
	for _, n in ipairs(D.npcScan()) do
		local fi, mi = D.SLIDE_FIXED_IDX[n.Id], D.SLIDE_FREE_IDX[n.Id]
		if fi or mi then
			local t = n.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			if x >= here.minx - D.SLIDE_SLACK and x <= here.maxx + D.SLIDE_SLACK
				and y >= here.miny - D.SLIDE_SLACK and y <= here.maxy + D.SLIDE_SLACK then
				local r = { npc = n, id = n.Id, x = x, y = y, idx = fi or mi }
				if fi then fixed[#fixed + 1] = r else free[#free + 1] = r end
			end
		end
	end
	return fixed, free
end

-- fixed statue -> its sliding partner, by run index; nearest wins when a room has
-- two statues sharing one index (two model runs in the same room), and nearest of
-- the leftovers when no index matches at all.
function D.slidePairs(fixed, free)
	local byIdx, used, out = {}, {}, {}
	for i = 1, #free do
		local k = free[i].idx
		byIdx[k] = byIdx[k] or {}
		byIdx[k][#byIdx[k] + 1] = free[i]
	end
	for i = 1, #fixed do
		local f = fixed[i]
		local pick, best
		local list = byIdx[f.idx] or {}
		for j = 1, #list do
			local c = list[j]
			if not used[c] then
				local d = (c.x - f.x) ^ 2 + (c.y - f.y) ^ 2
				if not best or d < best then best, pick = d, c end
			end
		end
		if not pick then
			for j = 1, #free do
				local c = free[j]
				if not used[c] then
					local d = (c.x - f.x) ^ 2 + (c.y - f.y) ^ 2
					if not best or d < best then best, pick = d, c end
				end
			end
		end
		if pick then
			used[pick] = true
			out[#out + 1] = { f = f, m = pick }
		end
	end
	return out
end

-- The offset from a fixed statue to where its sliding partner belongs, shared by
-- all four pairs (the statues of one room face the same way, so the pattern is one
-- translation). Scored rather than read: a candidate only counts if the goal tile
-- is floor inside THIS room, and the row the sliding statues already stand in
-- breaks a tie. nil when no candidate reaches the floor at all.
function D.slideOffset(world, here, fixed, free)
	if not world or not world.walk then return nil end
	if #fixed == 0 or #free == 0 or not here.set then return nil end
	local fx, fy, mx, my = 0, 0, 0, 0
	for i = 1, #fixed do fx, fy = fx + fixed[i].x, fy + fixed[i].y end
	for i = 1, #free do mx, my = mx + free[i].x, my + free[i].y end
	fx, fy = fx / #fixed, fy / #fixed
	mx, my = mx / #free, my / #free
	local best, bestScore
	for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		local floors = 0
		for i = 1, #fixed do
			local k = pkey(fixed[i].x + d[1] * D.SLIDE_GAP, fixed[i].y + d[2] * D.SLIDE_GAP)
			if here.set[k] and world.walk[k] then floors = floors + 1 end
		end
		local score = floors * 100 + (mx - fx) * d[1] + (my - fy) * d[2]
		if not bestScore or score > bestScore then bestScore, best = score, d end
	end
	if not best or bestScore < 100 then return nil end
	return best
end

-- The four fixed/sliding pairs of this room with their goal tiles, or nil when the
-- room does not hold the sliding-statue puzzle at all. `off` is nil when no direction
-- lands the goals on floor; `left` counts the pairs still off their goal.
-- ONE source of truth: the solver plans from this, and the walker asks
-- D.slidingMatched, so the two can never disagree about whether the room is done.
function D.slidePlan(world, here)
	if not here then return nil end
	local fixed, free = D.slideStatues(here)
	-- BOTH halves have to be in the room: that is what keeps this puzzle out of every
	-- other room, including follow-the-leader, whose npcs are also called "Statue"
	-- (ids 10966-10968) - and out of the base camp, whose exit statues (52004/52005)
	-- are decor and belong to neither family.
	if #fixed == 0 or #free == 0 then return nil end
	local off = D.slideOffset(world, here, fixed, free)
	local plan = { fixed = fixed, free = free, off = off, pairs = {}, left = 0 }
	if not off then return plan end
	plan.pairs = D.slidePairs(fixed, free)
	for i = 1, #plan.pairs do
		local p = plan.pairs[i]
		p.gx, p.gy = p.f.x + off[1] * D.SLIDE_GAP, p.f.y + off[2] * D.SLIDE_GAP
		if p.m.x ~= p.gx or p.m.y ~= p.gy then plan.left = plan.left + 1 end
	end
	return plan
end

-- Is the pattern matched? nil = not this puzzle, false = still work to do, true = done.
-- Deliberately CONTENT-ONLY: it asks the statues, not the saved room state, so a room
-- whose statues were already pushed into place - by hand, by an earlier run, or before
-- two rooms merged through the open doors and changed the room key - still reads as
-- solved instead of as pending work for the rest of the floor.
-- IT DOES NOT ASK WHERE TO PUSH. D.slideOffset answers "which way do the goals lie",
-- and once the statues ARE on their goals that question has no floor left under it (the
-- goal tiles are the tiles the statues are standing on), so it answered nil and a
-- FINISHED room fell through to the name-only prop test in D.puzzlePropsHere and was
-- reported as "an unsolved puzzle in this room (statue [statue])" for the rest of the
-- floor. Live: room 7073:257, all four sliding statues 7 tiles from their fixed partners
-- (10951/7075,267->10963/7075,260, 10950/7078,265->10962/7078,258, 10952/7081,265->
-- 10964/7081,258, 10953/7083,266->10965/7083,259), walker standing down in the room.
-- The match is read off the pairs instead: every sliding statue exactly D.SLIDE_GAP
-- tiles from its fixed partner, all four by the same offset - which is precisely the
-- state the game calls solved.
function D.slidingMatched(world, here)
	if not here then return nil end
	local fixed, free = D.slideStatues(here)
	if #fixed == 0 or #free == 0 then return nil end
	if #fixed < D.SLIDE_PAIRS or #free < D.SLIDE_PAIRS then return false end
	local pairs = D.slidePairs(fixed, free)
	if #pairs < D.SLIDE_PAIRS then return false end
	local dx, dy
	for i = 1, #pairs do
		local p = pairs[i]
		local ox, oy = p.m.x - p.f.x, p.m.y - p.f.y
		if math.abs(ox) + math.abs(oy) ~= D.SLIDE_GAP then return false end
		if not dx then dx, dy = ox, oy
		elseif ox ~= dx or oy ~= dy then return false end
	end
	return true
end

-- Remember a matched room as solved. The walker judges a room before any solver has
-- had a pass in it, so the marking has to be possible from there too.
function D.slidingMarkSolved(here)
	if not here or not S.pondState then return end
	local k = rkey(here)
	local st = S.pondState[k]
	if st and st.solved then return end
	S.pondState[k] = { solved = true, kind = 'slidingstatues' }
end

-- One pass. Returns true while the room still owns the bot.
function D.solveSlidingStatues(world, here, px, py)
	if not here then return false end
	local key = rkey(here)
	local own = puzzleOwn(key, 'slidingstatues')
	if own and own.solved then return false end
	local plan = D.slidePlan(world, here)
	if not plan then return false end
	if puzzleDone(here) then
		local done = puzzleClaim(key, 'slidingstatues', {})
		if done then done.solved = true end
		return false
	end
	local off = plan.off
	if not off then
		if not own then
			say('sliding statues: no goal tile is floor')
			log(string.format('sliding statues in room %s: %d fixed and %d sliding statue(s), but no offset lands on floor - leaving the room',
				key, #plan.fixed, #plan.free))
		end
		return false
	end
	local st = puzzleClaim(key, 'slidingstatues', { tries = {}, bad = {} })
	if not st then return false end
	if not st.offLogged then
		st.offLogged = true
		log(string.format('sliding statues in room %s: %d fixed and %d sliding statue(s), every goal %d tiles at offset %d,%d',
			key, #plan.fixed, #plan.free, D.SLIDE_GAP, off[1], off[2]))
	end

	local fixed, free = plan.fixed, plan.free
	local pairsList, need = plan.pairs, {}
	for i = 1, #pairsList do
		local p = pairsList[i]
		if p.m.x ~= p.gx or p.m.y ~= p.gy then need[#need + 1] = p end
	end
	if #need == 0 then
		-- A room is only finished when all four pairs are really there: a statue
		-- that was not in the scan yet must never make the room look solved.
		if #pairsList >= D.SLIDE_PAIRS and not st.solved then
			st.solved = true
			say('the statues match')
			log(string.format('sliding statues in room %s: all %d pair(s) in place - room done', key, #pairsList))
			puzzleMarkSolved(here, 'sliding statues matched')
		end
		return false
	end

	local occupied = {}
	for i = 1, #fixed do occupied[pkey(fixed[i].x, fixed[i].y)] = true end
	for i = 1, #free do occupied[pkey(free[i].x, free[i].y)] = true end
	local bfs = D.walkBfs(world)

	-- One axis at a time: a statue is pushed straight away from the player, so a
	-- diagonal step does not exist. The longer axis goes first so a pair that needs
	-- both cannot zig-zag. Returns where to stand, where the statue lands, or why
	-- there is no such push (plus whether another statue is the reason).
	local function plan(m, gx, gy)
		local dx, dy = gx - m.x, gy - m.y
		local steps = {}
		if math.abs(dx) >= math.abs(dy) then
			if dx ~= 0 then steps[#steps + 1] = { dx > 0 and 1 or -1, 0 } end
			if dy ~= 0 then steps[#steps + 1] = { 0, dy > 0 and 1 or -1 } end
		else
			if dy ~= 0 then steps[#steps + 1] = { 0, dy > 0 and 1 or -1 } end
			if dx ~= 0 then steps[#steps + 1] = { dx > 0 and 1 or -1, 0 } end
		end
		local why, held = nil, false
		for i = 1, #steps do
			local d = steps[i]
			local cx, cy = m.x + d[1], m.y + d[2]   -- where the statue lands
			local ax, ay = m.x - d[1], m.y - d[2]   -- where we stand to push it
			local kc, ka = pkey(cx, cy), pkey(ax, ay)
			if occupied[kc] then
				held = true
				why = string.format('another statue holds %d,%d', cx, cy)
			elseif not world.walk[kc] then
				why = string.format('%d,%d is not floor', cx, cy)
			elseif not world.walk[ka] then
				why = string.format('there is no room to stand on %d,%d', ax, ay)
			elseif not (bfs and bfs.dist[ka]) then
				why = string.format('%d,%d cannot be walked to', ax, ay)
			else
				return ax, ay, cx, cy
			end
		end
		return nil, why, held
	end

	-- The first pair that can legally be moved takes the pass. A pair whose landing
	-- tile is held by ANOTHER statue is skipped, never written off: that statue has
	-- to move first, and writing the pair off would leave the room unsolvable.
	local pick, sx, sy, tx, ty, why, held
	for i = 1, #need do
		local p = need[i]
		if not st.bad[p.m.id] then
			local ax, ay, cx, cy, ry, rh = plan(p.m, p.gx, p.gy)
			if ax then
				pick, sx, sy, tx, ty = p, ax, ay, cx, cy
				break
			end
			why, held = ry, rh
			if not rh then st.bad[p.m.id] = true end
		end
	end
	if not pick then
		if why and not held and not st.gaveUp then
			st.gaveUp = true
			say('sliding statues: nothing can be moved')
			log(string.format('sliding statues in room %s: no pair can be pushed (%s) - leaving the room',
				key, tostring(why)))
		end
		return false
	end
	local m, gx, gy = pick.m, pick.gx, pick.gy

	if px ~= sx or py ~= sy then
		say('stepping round the statue')
		log(string.format('sliding statues: walking to %d,%d to push statue %d from %d,%d to %d,%d (it belongs on %d,%d)',
			sx, sy, m.id, m.x, m.y, tx, ty, gx, gy))
		if not D.walkTile(sx, sy, 0) then
			st.bad[m.id] = true
			log(string.format('sliding statues: cannot walk to %d,%d - statue %d written off', sx, sy, m.id))
			return false
		end
		D.waitMove(px, py, D.SLIDE_PUSH_WAIT)
		return true
	end

	-- The same push decided again with the statue still on the same tile means the
	-- animation played and the statue did not move (pushing onto a monster, a player
	-- or the wall answers "You can't push that there" and leaves it where it is).
	local now = API.SystemTime()
	local sig = pkey(m.x, m.y) .. '>' .. pkey(tx, ty)
	if st.lastSig ~= sig then
		-- a statue that moved starts from a clean count
		st.tries[m.id] = nil
	elseif (now - (st.lastAt or 0)) > D.SLIDE_SETTLE_MS then
		st.tries[m.id] = (st.tries[m.id] or 0) + 1
		log(string.format('sliding statues: statue %d is still on %d,%d after the push (try %d/%d)',
			m.id, m.x, m.y, st.tries[m.id], D.SLIDE_TRIES))
		if st.tries[m.id] >= D.SLIDE_TRIES then
			st.bad[m.id] = true
			log(string.format('sliding statues: statue %d will not move off %d,%d - pair written off',
				m.id, m.x, m.y))
			return false
		end
	end
	st.lastSig, st.lastAt = sig, now
	st.pushes = (st.pushes or 0) + 1

	settle()
	say(string.format('pushing a statue (%d,%d to %d,%d)', m.x, m.y, tx, ty))
	log(string.format('sliding statues: pushing statue %d from %d,%d to %d,%d, standing on %d,%d (push %d)',
		m.id, m.x, m.y, tx, ty, sx, sy, st.pushes))
	local act = D.CODE['Push'] or D.ACT_DEFAULT
	-- Direct click: the statue we push has to be THIS one, and the id form would let
	-- the engine pick whichever statue of that id it likes best.
	if not API.DoAction_NPC__Direct(act, D.ROUTE_TALK, m.npc) then
		API.DoAction_NPC(act, D.ROUTE_TALK, { m.id }, 50)
	end
	-- Let the push FINISH before deciding anything else: the player animates, the
	-- statue slides a tile and we step onto the tile it left. Deciding earlier read a
	-- working push as a failed one and clicked it a second time.
	API.RandomSleep2(900, 300, 500)
	D.waitAnimStart(D.SLIDE_PUSH_WAIT)
	D.waitMove(px, py, D.SLIDE_PUSH_WAIT)
	API.RandomSleep2(400, 150, 250)
	-- the statue is on a new tile now: the cached npc list still shows the old one
	D.npcCache = nil
	D.bfsCache = {}
	return true
end

--------------------------------------------------------------------
-- puzzles: sleeping guards (Sleepingguards.java)
--------------------------------------------------------------------
-- Four "Brute" guards sleep around the room, one key each. A failed steal wakes
-- the room; killing an awake guard drops its key instead - so the room is a
-- thieving job with a combat fallback, and the fight branch above already owns
-- every guard whose option has become "Attack".
--
-- The only thing the room produces is the plain "Guard room key" (item 17363),
-- which is NOT one of the colour/shape keys on the key ring: it is an ordinary
-- inventory item, and D.keyCvar has no entry for it. That is why D.guardHoldsKey
-- exists and why hasKeyFor() in Dung.lua asks it before refusing a locked door -
-- without that the room's own door could never be opened at all.
--
-- A pickpocket is the guard's FIRST option, so it is dispatched exactly like the
-- statue's Push (D.ACT_DEFAULT on the NPC route). The option text is checked
-- first so an awake guard is never clicked with it.
D.GUARD_KEY = 17363
-- The room's own clutter (Sleepingguards.TRASH). It is only used as room identity,
-- and it is read through the CACHED object scan so a room without it costs nothing.
D.GUARD_TRASH = { 49315, 49316, 49317, 49318 }
D.GUARD_TRASH_SET = {}
for i = 1, #D.GUARD_TRASH do D.GUARD_TRASH_SET[D.GUARD_TRASH[i]] = true end
D.GUARD_SLACK = 3
D.GUARD_REACH = 2      -- a pickpocket only exists at arm's length
D.GUARD_TRIES = 4      -- steals from one guard before it is left alone

-- Guards standing in this room. `sleeping` is judged on the option the client
-- offers, never on the name or the id.
function D.guardBrutes(here)
	local out = {}
	if not here then return out end
	for _, n in ipairs(D.npcScan()) do
		if string.find(string.lower(n.Name or ''), 'brute', 1, true) then
			local ok, t = pcall(function() return n.Tile_XYZ end)
			if ok and t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= here.minx - D.GUARD_SLACK and x <= here.maxx + D.GUARD_SLACK
					and y >= here.miny - D.GUARD_SLACK and y <= here.maxy + D.GUARD_SLACK then
					local a = string.lower(n.Action or '')
					out[#out + 1] = {
						npc = n, id = n.Id, x = x, y = y,
						sleeping = string.find(a, 'pickpocket', 1, true) ~= nil
							or string.find(a, 'steal', 1, true) ~= nil,
					}
				end
			end
		end
	end
	return out
end

-- The guard key lying in this room, if any. Matched by ID (a ground item comes
-- back from the scan with an EMPTY name) and read from the shared object sweep:
-- a fresh {3},{17363} sweep here would be one extra engine scan on every pass in
-- every room, which is exactly what D.objScan exists to prevent.
function D.guardKeyOnFloor(here)
	if not here then return nil end
	for _, o in ipairs(D.objScan()) do
		if o.Id == D.GUARD_KEY then
			local ok, t = pcall(function() return o.Tile_XYZ end)
			if ok and t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= here.minx - D.GUARD_SLACK and x <= here.maxx + D.GUARD_SLACK
					and y >= here.miny - D.GUARD_SLACK and y <= here.maxy + D.GUARD_SLACK then
					return o
				end
			end
		end
	end
	return nil
end

-- Is the room's clutter standing here? Read through D.objScan (the shared object
-- sweep) so it is judged from the same props every other solver sees.
function D.guardClutter(here)
	if not here then return false end
	for _, o in ipairs(D.objScan()) do
		if D.GUARD_TRASH_SET[o.Id] then
			local ok, t = pcall(function() return o.Tile_XYZ end)
			if ok and t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= here.minx - D.GUARD_SLACK and x <= here.maxx + D.GUARD_SLACK
					and y >= here.miny - D.GUARD_SLACK and y <= here.maxy + D.GUARD_SLACK then
					return true
				end
			end
		end
	end
	return false
end

-- Is the room key in the bag? Inventory:Contains is a live engine read, so it is
-- asked behind a pcall like every other one in this file.
function D.guardHoldsKey()
	local ok, has = pcall(function() return Inventory:Contains(D.GUARD_KEY) end)
	return ok and has == true
end

-- One pass. Returns true while this room still owns the bot.
function D.solveSleepingGuards(world, here, px, py)
	if not here then return false end
	local key = rkey(here)
	local own = puzzleOwn(key, 'guards')
	if own and own.solved then return false end

	local brutes = D.guardBrutes(here)
	local floorKey = D.guardKeyOnFloor(here)
	local held = D.guardHoldsKey()
	-- EVIDENCE FIRST. A guard key carried out of an earlier room must never make an
	-- unrelated room look like this puzzle: only a guard, a key on the floor, the
	-- room's clutter or a room this solver has already worked may claim it.
	if #brutes == 0 and not floorKey and not (own and own.seen)
		and not D.guardClutter(here) then
		return false
	end
	-- No guard, no key on the floor and no key in the bag: this is a guards room
	-- whose work is done.
	if #brutes == 0 and not floorKey and not held then
		if own and own.seen and not own.solved then
			own.solved = true
			say('the guards room is finished')
			log(string.format('sleeping guards in room %s: no brute and no key left - room done', key))
			puzzleMarkSolved(here, 'sleeping guards cleared')
		end
		return false
	end
	local st = puzzleClaim(key, 'guards', { tries = {} })
	if not st then return false end
	st.seen = true

	-- A key on the floor is free: take it before anything that can wake the room.
	if floorKey then
		local ok, t = pcall(function() return floorKey.Tile_XYZ end)
		local kx = ok and t and math.floor(t.x) or nil
		local ky = ok and t and math.floor(t.y) or nil
		if kx then
			say('taking the guard room key')
			log(string.format('sleeping guards in room %s: taking the key on the floor at %d,%d', key, kx, ky))
			D.takeFloorItem(floorKey, { D.GUARD_KEY }, 'guard room key')
			return true
		end
	end
	-- Holding a key already: the doorway logic unlocks with it (hasKeyFor), so
	-- this room has nothing more for us until that key is spent.
	if held then return false end

	-- Steal from the nearest guard that is still asleep.
	local pick
	for i = 1, #brutes do
		local b = brutes[i]
		local kk = b.x .. ',' .. b.y
		if b.sleeping and (st.tries[kk] or 0) < D.GUARD_TRIES then
			local d = (b.x - px) ^ 2 + (b.y - py) ^ 2
			if not pick or d < pick.d then pick = { b = b, d = d, k = kk } end
		end
	end
	if not pick then
		if not st.gaveUp then
			st.gaveUp = true
			say('sleeping guards: no guard left to steal from')
			log(string.format('sleeping guards in room %s: %d brute(s), none asleep and none giving a key - leaving them to the fight branch',
				key, #brutes))
		end
		return false
	end
	local b = pick.b
	if math.max(math.abs(b.x - px), math.abs(b.y - py)) > D.GUARD_REACH then
		local tx, ty = D.walkSpotNear(world, b.x, b.y)
		if tx then
			say('walking to a sleeping guard')
			log(string.format('sleeping guards: walking to %d,%d for the brute at %d,%d', tx, ty, b.x, b.y))
			D.walkTile(tx, ty, 0)
			API.RandomSleep2(700, 250, 400)
			settle()
			return true
		end
	end
	st.tries[pick.k] = (st.tries[pick.k] or 0) + 1
	settle()
	say('pickpocketing a sleeping guard')
	log(string.format('sleeping guards in room %s: stealing from the brute at %d,%d (try %d/%d)',
		key, b.x, b.y, st.tries[pick.k], D.GUARD_TRIES))
	-- "Pickpocket" is the guard's first option while it sleeps.
	if not API.DoAction_NPC__Direct(D.ACT_DEFAULT, D.ROUTE_TALK, b.npc) then
		API.DoAction_NPC(D.ACT_DEFAULT, D.ROUTE_TALK, { b.id }, 50)
	end
	API.RandomSleep2(1100, 400, 700)
	D.waitAnimStart(2500)
	settle()
	-- a wake-up turns them all into fresh fight targets: drop the cached npc list
	D.npcCache = nil
	return true
end

--------------------------------------------------------------------
-- puzzles: crystal power / light beams (CrystalPower.java)
--------------------------------------------------------------------
-- A "Large crystal" sits in the middle of a ring of four "Pressure pad"s, with
-- coloured crystals (red/yellow/green/blue) and "Inactive lodestone"s around it.
-- Two jobs, in the java's own order:
--   1. every inactive lodestone is powered up ("Power-up"),
--   2. the beams of the remaining colours are blocked/let through by standing on
--      the pressure pad nearest that colour until its index matches ms + 2.
-- The index is the java's: the tile distance from that colour's crystal to the
-- nearest reachable pressure pad. `ms` is the index most colours share; a colour
-- whose index differs is the beam that is currently in the way.
D.CRYSTAL_BIG = { 34866, 35070, 49510, 49507, 49508, 49511, 49509, 49512, 54276, 54275 }
-- The large crystal is a STATE PAIR on its own tile: 49507 dark, 49510 glowing.
-- Neither variant is interactable (Bool1 reports no option), so it is only ever
-- used as the room anchor and as a progress lamp - it is never clicked.
D.CRYSTAL_BIG_GLOW = { 49510 }
D.CRYSTAL_OFF = { 49491, 34852, 34863, 49471, 49472, 49473, 49490, 49481, 49489,
	49480, 49500, 49482, 54263, 54269, 54266 }
D.CRYSTAL_PADS = { 35232, 52206, 54282 }
D.CRYSTAL_COLOURS = {
	red    = { 49479, 49478, 49477, 34848, 54265 },
	yellow = { 49497, 49496, 49495, 34862, 54271 },
	green  = { 49488, 49487, 49486, 34856, 54268 },
	blue   = { 34319, 49470, 49469, 49468, 54262 },
}
D.CRYSTAL_BIG_SET, D.CRYSTAL_OFF_SET, D.CRYSTAL_PAD_SET, D.CRYSTAL_COLOR_OF = {}, {}, {}, {}
D.CRYSTAL_GLOW_SET = {}
for i = 1, #D.CRYSTAL_BIG_GLOW do D.CRYSTAL_GLOW_SET[D.CRYSTAL_BIG_GLOW[i]] = true end
-- Only the classification sets are kept: the room is found by scanning types 0/12
-- and matching these ids in Lua (passing the whole id list to
-- ReadAllObjectsArray returned nothing, which is why the room went unrecognised).
local function cid(list, kind)
	for i = 1, #list do
		if kind == 'big' then D.CRYSTAL_BIG_SET[list[i]] = true
		elseif kind == 'off' then D.CRYSTAL_OFF_SET[list[i]] = true
		elseif kind == 'pad' then D.CRYSTAL_PAD_SET[list[i]] = true
		else D.CRYSTAL_COLOR_OF[list[i]] = kind end
	end
end
cid(D.CRYSTAL_BIG, 'big')
cid(D.CRYSTAL_OFF, 'off')
cid(D.CRYSTAL_PADS, 'pad')
for name, list in pairs(D.CRYSTAL_COLOURS) do cid(list, name) end

D.CRYSTAL_SLACK = 3
D.CRYSTAL_RANGE = 12   -- tiles from the large crystal: the whole room around it
-- Only these are ever path-tested. A REACH_LOCAL scan runs a client path find per
-- object, so scanning ALL objects of types 0/12 with it cost ~hundreds of path
-- finds on every loop pass; the pads and lodestones are 18 ids.
D.CRYSTAL_REACH_IDS = {}
for i = 1, #D.CRYSTAL_OFF do D.CRYSTAL_REACH_IDS[#D.CRYSTAL_REACH_IDS + 1] = D.CRYSTAL_OFF[i] end
for i = 1, #D.CRYSTAL_PADS do D.CRYSTAL_REACH_IDS[#D.CRYSTAL_REACH_IDS + 1] = D.CRYSTAL_PADS[i] end
-- "no crystal near here" memo, so a floor without this room does not pay for the
-- scan on every single pass
D.CRYSTAL_MISS_TTL = 3000
D.crystalMiss = nil

-- Everything belonging to the crystal puzzle, found by DISTANCE from the large
-- crystal - the java does the same ("nearest BIG_CRYSTAL"), and it is the only
-- reliable anchor: segmentation drops blocked tiles, so the crystal's own tile is
-- usually not inside the room's tile set and a bbox test missed the room entirely.
-- Returns nil when this is not a crystal room.
function D.crystalRoom(px, py)
	-- Scan by TYPE and filter in Lua. Passing the ~45 crystal ids to
	-- ReadAllObjectsArray returned nothing in this room even though every object is
	-- present (live dump: 49507 at 12855,680 and both inactive lodestones), so the
	-- id list is not trusted here.
	local all = D.keepScan(API.ReadAllObjectsArray(D.OBJ_TYPES, {}, {}, D.NO_REACH)) or {}
	local big, bd = nil, math.huge
	for _, o in ipairs(all) do
		if D.CRYSTAL_BIG_SET[o.Id] then
			local t = o.Tile_XYZ
			local d = (math.floor(t.x) - px) ^ 2 + (math.floor(t.y) - py) ^ 2
			if d < bd then
				bd = d
				big = { obj = o, id = o.Id, x = math.floor(t.x), y = math.floor(t.y),
					z = math.floor(t.z or 0), name = o.Name,
					glow = D.CRYSTAL_GLOW_SET[o.Id] == true }
			end
		end
	end
	if not big or bd > D.CRYSTAL_RANGE * D.CRYSTAL_RANGE then return nil end

	-- One batched local pass ("the client can path to within one tile of it") so the
	-- solver never targets an object behind a wall. Restricted to the pads and
	-- lodestone ids: startpathreach = 1 path-finds once per object, and asking it
	-- about every type 0/12 object on the floor cost hundreds of path finds a pass.
	local reach = {}
	for _, o in ipairs(API.ReadAllObjectsArray(D.OBJ_TYPES, D.CRYSTAL_REACH_IDS, {}, D.REACH_LOCAL) or {}) do
		local t = o.Tile_XYZ
		reach[pkey(math.floor(t.x), math.floor(t.y))] = o.Id
	end

	local r = { big = big, off = {}, pads = {}, colours = {} }
	for _, o in ipairs(all) do
		local t = o.Tile_XYZ
		local x, y = math.floor(t.x), math.floor(t.y)
		local d = (x - big.x) ^ 2 + (y - big.y) ^ 2
		if d <= D.CRYSTAL_RANGE * D.CRYSTAL_RANGE then
			local e = { obj = o, id = o.Id, x = x, y = y, z = math.floor(t.z or 0), name = o.Name,
				reach = reach[pkey(x, y)] == o.Id }
			if D.CRYSTAL_BIG_SET[o.Id] then
				-- the anchor itself and its dark/glow twin: never a click target
				r.big2 = r.big2 or e
			elseif D.CRYSTAL_OFF_SET[o.Id] then
				r.off[#r.off + 1] = e
			elseif D.CRYSTAL_PAD_SET[o.Id] then
				r.pads[#r.pads + 1] = e
			else
				local c = D.CRYSTAL_COLOR_OF[o.Id]
				if c then r.colours[#r.colours + 1] = { e = e, colour = c } end
			end
		end
	end
	return r
end

-- The java's light index: distance from a colour's crystal to the nearest pad it
-- can reach; -1 when there is no pad at all.
function D.crystalIndex(r, colour)
	local c = nil
	for i = 1, #r.colours do
		if r.colours[i].colour == colour and not c then c = r.colours[i].e end
	end
	if not c then return nil end
	local best
	for i = 1, #r.pads do
		local p = r.pads[i]
		if p.reach then
			local d = math.floor(math.sqrt((p.x - c.x) ^ 2 + (p.y - c.y) ^ 2) + 0.5)
			if not best or d < best.d then best = { pad = p, d = d } end
		end
	end
	if not best then return nil end
	return best.d, best.pad
end

-- One step. Returns true while this room still owns us.
-- Keyed by the CRYSTAL's tile, not by the room: the segmented room box does not
-- contain the crystal (it stands on a blocked centre tile), and relying on `here`
-- meant the puzzle was never recognised at all.
function D.solveCrystalPower(world, here, px, py)
	-- Repeated "no crystal in range" answers are not free: the detection scan walks
	-- every object of types 0/12. Remember the last miss for a moment so a floor
	-- without this room costs one scan per few seconds, not one per loop pass.
	if D.crystalMiss and (API.SystemTime() - D.crystalMiss.t) < D.CRYSTAL_MISS_TTL
		and math.abs(px - D.crystalMiss.x) <= 4 and math.abs(py - D.crystalMiss.y) <= 4 then
		return false
	end
	local r = D.crystalRoom(px, py)
	if not r then
		D.crystalMiss = { x = px, y = py, t = API.SystemTime() }
		return false
	end
	D.crystalMiss = nil
	local key = 'crystal:' .. r.big.x .. ',' .. r.big.y
	local st = S.pondState[key]
	if st and st.solved then return false end
	if here and puzzleDone(here) then
		S.pondState[key] = { solved = true, kind = 'crystal' }
		return false
	end

	st = st or {}
	st.kind = st.kind or 'crystal'
	S.pondState[key] = st
	if not st.seenLog then
		st.seenLog = true
		local at = {}
		for i = 1, #r.off do at[#at + 1] = 'lodestone ' .. r.off[i].x .. ',' .. r.off[i].y end
		for i = 1, #r.pads do at[#at + 1] = 'pad ' .. r.pads[i].x .. ',' .. r.pads[i].y end
		for i = 1, #r.colours do
			at[#at + 1] = r.colours[i].colour .. ' ' .. r.colours[i].e.x .. ',' .. r.colours[i].e.y
		end
		log(string.format('crystal room %s: large crystal %d at %d,%d (%s) | %d lodestone(s), %d pad(s), %d colour(s): %s',
			key, r.big.id, r.big.x, r.big.y, r.big.glow and 'glowing' or 'dark',
			#r.off, #r.pads, #r.colours, table.concat(at, ' ')))
	end

	-- 1. power up every inactive lodestone we can actually walk up to
	for i = 1, #r.off do
		local e = r.off[i]
		if e.reach and D.interactable(e.obj) then
			st.powers = (st.powers or 0) + 1
			if st.powers > 12 then
				log(string.format('crystal power in room %s: %d power-up clicks without effect - leaving it',
					key, st.powers - 1))
				return false
			end
			settle()
			say('powering up the lodestone')
			log(string.format('crystal power: %d "%s" at %d,%d - Power-up (try %d)',
				e.id, tostring(e.name), e.x, e.y, st.powers))
			D.clickObject('Power-up', e.obj)
			API.RandomSleep2(1300, 500, 900)
			settle()
			return true
		end
	end

	-- 2. no coloured crystal left = the beams are done
	if #r.colours == 0 then
		st.solved = true
		D.dirty = true
		say('crystal power done')
		log(string.format('crystal power in room %s: no coloured crystal left - room done', key))
		return false
	end
	if #r.pads == 0 then return false end

	-- index per colour, and the index most colours share
	local idx, order = {}, { 'red', 'yellow', 'green', 'blue' }
	local count, ms, msCount = {}, nil, 0
	for i = 1, #order do
		local d = D.crystalIndex(r, order[i])
		if d then
			idx[order[i]] = d
			count[d] = (count[d] or 0) + 1
			if count[d] > msCount then ms, msCount = d, count[d] end
		end
	end
	if not ms then return false end
	-- java currentmsNumber(ms + 2): 5 -> 0, 6 -> 1, so the index wraps at 5
	local target = (ms + 2) % 5

	-- the colour to work: first one whose index disagrees with ms
	local work, pad
	for i = 1, #order do
		local c = order[i]
		if idx[c] and idx[c] ~= ms then
			local _, p = D.crystalIndex(r, c)
			work, pad = c, p
			break
		end
	end
	if not work then
		-- every colour already sits on the same index: nothing to block
		log(string.format('crystal power in room %s: all colours at index %d - waiting', key, ms))
		API.RandomSleep2(1200, 400, 700)
		return true
	end

	st.work, st.pad = work, pad
	if px ~= pad.x or py ~= pad.y then
		say('blocking the ' .. work .. ' beam')
		log(string.format('crystal power: %s at index %s, ms %d - standing on pad %d,%d (target index %d)',
			work, tostring(idx[work]), ms, pad.x, pad.y, target))
		D.walkTile(pad.x, pad.y, 0)
		API.RandomSleep2(1000, 400, 700)
		settle()
		return true
	end
	if idx[work] == target then
		-- beam line up: step off (java: the tile one west of the pad) and let it pass
		say('letting the ' .. work .. ' beam through')
		log(string.format('crystal power: %s reached index %d - stepping off pad %d,%d',
			work, target, pad.x, pad.y))
		D.walkTile(pad.x - 1, pad.y, 0)
		API.RandomSleep2(900, 350, 600)
		settle()
		return true
	end
	say('holding the ' .. work .. ' beam')
	API.RandomSleep2(800, 300, 500)
	return true
end

--------------------------------------------------------------------
-- puzzles: coloured ferrets on pressure plates (ColoredFurret.java)
--------------------------------------------------------------------
-- Five colours, four plate tiles each and one ferret each. The ferret has to end
-- up standing on one of its own plates, and the only way to move it is to stand
-- behind it (the side away from the plate) and click "Scare" - it then hops one
-- tile toward the plate. Standing on the plate itself does nothing.
D.FERRET_PLATES = {
	{ 54372, 54374, 54376, 54378 },   -- blue
	{ 54364, 54366, 54368, 54370 },   -- red
	{ 54388, 54390, 54392, 54394 },   -- yellow
	{ 54380, 54382, 54384, 54386 },   -- green
	{ 54396, 54398, 54400, 54402 },   -- orange
}
D.FERRET_IDS = { 12167, 12165, 12171, 12169, 12173 }
D.FERRET_SCARE = 0x29   -- the npc's non-attack option, same opcode as Catch/Talk
D.FERRET_PLATE_SET = {}
for _, list in ipairs(D.FERRET_PLATES) do
	for _, id in ipairs(list) do D.FERRET_PLATE_SET[id] = true end
end

-- Stand on one exact tile. A plain tile click is allowed to stop one tile short (it accepts
-- distance^2 <= 2), which is fine for doors and useless for puzzles: the scare
-- tile has to be the tile, or the ferret is pushed the wrong way.
local function standOn(x, y)
	local px, py = ptile()
	if px == x and py == y then return true end
	for _ = 1, 4 do
		D.walkTile(x, y, 0)
		API.RandomSleep2(600, 200, 350)
		settle()
		px, py = ptile()
		if px == x and py == y then return true end
	end
	return false
end

-- One ferret per pass: find the one that is not on its plate, work out the tile
-- to scare it from, walk there, and click. Returns true when it did something so
-- the main loop does not also try to route away.
local function solveFerrets(world, here, px, py)
	if not here then return false end
	local ferrets = {}
	-- the ferret records are used after the scan loop: pin the scan that owns them
	for _, n in ipairs(D.keepScan(API.ReadAllObjectsArray({ 1 }, D.FERRET_IDS, {}, D.NO_REACH)) or {}) do
		ferrets[n.Id] = n
	end
	local haveFerret = false
	for _ in pairs(ferrets) do haveFerret = true break end
	if not haveFerret then return false end

	local plates = {}
	for _, o in ipairs(API.ReadAllObjectsArray(D.OBJ_TYPES, {}, {}, D.NO_REACH) or {}) do
		if D.FERRET_PLATE_SET[o.Id] then
			local t = o.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			plates[o.Id] = { x = x, y = y }
		end
	end

	local present, off = 0, 0
	for ci = 1, #D.FERRET_PLATES do
		local ferret = ferrets[D.FERRET_IDS[ci]]
		if ferret then
			present = present + 1
			local ft = ferret.Tile_XYZ
			local fx, fy = math.floor(ft.x), math.floor(ft.y)
			-- nearest plate of this colour: the one it is heading for
			local pad, padD = nil, math.huge
			local onPad = false
			for _, id in ipairs(D.FERRET_PLATES[ci]) do
				local p = plates[id]
				if p then
					local d = (p.x - fx) ^ 2 + (p.y - fy) ^ 2
					if d == 0 then onPad = true end
					if d < padD then padD, pad = d, p end
				end
			end
			if not onPad then off = off + 1 end
			if not onPad and pad then
				local sx = (pad.x > fx and 1) or (pad.x < fx and -1) or 0
				local sy = (pad.y > fy and 1) or (pad.y < fy and -1) or 0
				-- Stand on the far side of the ferret from its plate: directly behind
				-- first, then the three neighbours on that same side, so a blocked
				-- tile never stops the puzzle.
				local cands = {
					{ fx - sx, fy - sy },
					{ fx - sx, fy },
					{ fx, fy - sy },
					{ fx + sy, fy - sx },
					{ fx - sy, fy + sx },
				}
				local spot = nil
				for _, c in ipairs(cands) do
					if (c[1] ~= fx or c[2] ~= fy) and world.walk[pkey(c[1], c[2])] then
						spot = c
						break
					end
				end
				if not spot then
					log(string.format('ferret %s at %d,%d: no tile behind it to scare from',
						tostring(ferret.Name), fx, fy))
					return false
				end
				if px == spot[1] and py == spot[2] then
					say('scaring the ferret')
					log(string.format('scare ferret %s id %d at %d,%d from %d,%d toward pad %d,%d',
						tostring(ferret.Name), ferret.Id, fx, fy, spot[1], spot[2], pad.x, pad.y))
					API.DoAction_NPC(D.FERRET_SCARE, D.ROUTE_TALK, { ferret.Id }, 50)
					API.RandomSleep2(900, 300, 500)
					return true
				end
				say('walking behind the ferret')
				log(string.format('ferret %s at %d,%d, pad %d,%d - standing on %d,%d to scare it',
					tostring(ferret.Name), fx, fy, pad.x, pad.y, spot[1], spot[2]))
				if (px - spot[1]) ^ 2 + (py - spot[2]) ^ 2 > 4 then
					D.walkTile(spot[1], spot[2])
				end
				if not standOn(spot[1], spot[2]) then
					log(string.format('could not stand on %d,%d to scare the ferret', spot[1], spot[2]))
				end
				return true
			end
		end
	end
	-- Every ferret that exists is standing on one of its own plates: that IS the
	-- solved state of this puzzle (the plates never change, the ferrets do).
	if present > 0 and off == 0 then
		puzzleMarkSolved(here, string.format('all %d ferret(s) on their plates', present))
	end
	return false
end

--------------------------------------------------------------------
-- flip tiles / rune tiles puzzle
--------------------------------------------------------------------
-- A grid of Green and Yellow floor tiles. Clicking one toggles its colour, and the
-- puzzle is done when the whole board is one colour. Verified on the live client:
-- "Imbue" on a green tile turned it yellow, "Imbue" on a yellow tile turned it
-- green - so one option is enough and Force is not needed.
-- (Reference: ShadowDungeon FlipTiles.java, which turns a tile towards the colour
-- most common around it - the same thing as flipping every tile that is not the
-- board's majority colour.)
D.FLIP_GREEN = { 49638, 49639, 49640, 54065 }
D.FLIP_YELLOW = { 49641, 49642, 49643, 54066 }
D.FLIP_IDS, D.FLIP_GREEN_SET = {}, {}
for _, id in ipairs(D.FLIP_GREEN) do
	D.FLIP_IDS[#D.FLIP_IDS + 1] = id
	D.FLIP_GREEN_SET[id] = true
end
for _, id in ipairs(D.FLIP_YELLOW) do D.FLIP_IDS[#D.FLIP_IDS + 1] = id end
-- Live board size and the finished state: a solved board is 25 "Yellow tile" props in a
-- 5x5 box, every one of them still offering "Imbue" - the colour is the only signal.
D.FLIP_ACT = 0x39          -- option 1 on an object; "Imbue" is the tile's first option
D.FLIP_MIN_BOARD = 3
D.FLIP_BOARD     = 5

-- Every flip tile on the board, split by colour, plus a tile-keyed lookup. Room
-- membership is the filter, but a tile stands ON a floor tile and the room set only
-- holds walkable ones, so anything close to the player counts as well.
local function flipBoard(here, px, py, world)
	local green, yellow, at = {}, {}, {}
	local skip = D.enteredDoorSkip and D.enteredDoorSkip() or nil
	-- the board records carry the tile's object out of this loop: pin the scan (D.keepScan)
	for _, o in ipairs(D.keepScan(API.ReadAllObjectsArray({ 0 }, D.FLIP_IDS, {}, D.NO_REACH)) or {}) do
		local t = o.Tile_XYZ
		local x, y = math.floor(t.x), math.floor(t.y)
		-- "Near us" is not the same as "in our room": a doorway between us and the tile
		-- means it is the next room's board. D.propInMyRoom is the shared rule every
		-- puzzle uses (see Dung.lua), so this board cannot reach through a wall.
		local near = px and math.abs(x - px) <= 6 and math.abs(y - py) <= 6
			and D.propInMyRoom(world, px, py, x, y, skip)
		if near or (here and here.set[pkey(x, y)]) then
			local rec = { x = x, y = y, obj = o, green = D.FLIP_GREEN_SET[o.Id] and true or false }
			at[pkey(x, y)] = rec
			if rec.green then green[#green + 1] = rec else yellow[#yellow + 1] = rec end
		end
	end
	return green, yellow, at
end

-- Lights Out on the tile grid. "Imbue" flips the clicked tile AND its four
-- orthogonal neighbours (runescape.wiki/w/Green_tile: "flips the imbued tile and
-- any other tiles immediately north/east/south/west"); the room is done when the
-- whole grid is one colour. So the presses are computed, not guessed: mark every
-- tile that differs from the target colour, then chase - the 32 press patterns of
-- one row are enumerated and each is propagated up the board until one clears it.
-- A 5x5 cross-kernel board is always solvable, so a solution exists.
-- Lights Out on the tile grid. "Imbue" flips the clicked tile AND its four
-- orthogonal neighbours (runescape.wiki/w/Green_tile: "flips the imbued tile and
-- any other tiles immediately north/east/south/west"); the room is done when the
-- whole grid is one colour. So the presses are computed, not guessed: mark every
-- tile that differs from the target colour, then chase - the 32 press patterns of
-- one row are enumerated and each is propagated up the board.
--
-- The 5x5 cross matrix has rank 23 of 25, so two of every four board states cannot
-- be cleared by Imbue alone. That is what the tile's second option is for: "Force"
-- flips ONLY the clicked tile (at the cost of some damage). So the chase returns the
-- pattern with the fewest tiles left over, and those leftovers get Forced.
local function flipSolve(w, h, wrong)
	local best, bestLeft = nil, math.huge
	for mask = 0, (2 ^ w) - 1 do
		local st, press = {}, {}
		for i = 1, w * h do st[i] = wrong[i] end
		local function hit(r, c)
			local idx = (r - 1) * w + c
			press[idx] = not press[idx]
			for _, n in ipairs({ { r, c }, { r - 1, c }, { r + 1, c }, { r, c - 1 }, { r, c + 1 } }) do
				if n[1] >= 1 and n[1] <= h and n[2] >= 1 and n[2] <= w then
					st[(n[1] - 1) * w + n[2]] = 1 - st[(n[1] - 1) * w + n[2]]
				end
			end
		end
		for c = 1, w do
			if math.floor(mask / (2 ^ (c - 1))) % 2 == 1 then hit(1, c) end
		end
		-- A tile still wrong in row r can only be fixed from row r+1 from here on.
		for r = 1, h - 1 do
			for c = 1, w do
				if st[(r - 1) * w + c] == 1 then hit(r + 1, c) end
			end
		end
		local left = {}
		for i = 1, w * h do
			if st[i] == 1 then left[#left + 1] = i end
		end
		if #left < bestLeft then
			local imbue = {}
			for i = 1, w * h do
				if press[i] then imbue[#imbue + 1] = i end
			end
			bestLeft, best = #left, { imbue = imbue, force = left }
			if bestLeft == 0 then break end
		end
	end
	return best, bestLeft
end

---------------------------------------------------------------------
-- Levers / "5 switches" (Leavers.java)
---------------------------------------------------------------------
-- Five levers on the room's walls and one action: Pull. A pulled lever becomes a
-- different object with no Pull option at all, so "nothing in this room still
-- offers Pull" is the solved test and the ids are only a fallback (Leavers.java:
-- 49381/49382 unpulled, 49384/49385 pulled - cache ids move between floors).
D.LEVER_ON = { 49381, 49382 }
D.LEVER_ON_SET = {}
for _, id in ipairs(D.LEVER_ON) do D.LEVER_ON_SET[id] = true end
-- A lever is this room's puzzle only when it stands in the room, against its wall, or
-- inside its box plus the wall slack - NOT "any lever within 18 tiles". A lever from the
-- next room used to keep this puzzle alive from afar: every pass logged "1 up but none
-- can be worked from here", the room never fell through to its doors, and the lever could
-- not be walked to either. Room segmentation can split one puzzle room in two (live: the
-- five switches of one room fell into 12993:3137 and 12993:3153), so the box keeps the
-- wall slack instead of testing the room's own set alone.
D.LEVER_SLACK = 3       -- levers sit on the wall, just outside the room's tile box
D.LEVER_TRIES = 8       -- pulls on one lever before it is written off
-- Longer than D.WORLD_TTL (8 s) on purpose: the object cache has to refresh before a
-- pulled switch stops reading "Pull", so re-picking one earlier only earns a refusal.
D.LEVER_RECLICK_MS = 9000
-- The click has to reach the client (one tick) and then either start a walk or start
-- the pull animation. Anything longer than that is dead time between levers.
D.LEVER_TICK_WAIT = 700
D.LEVER_STALL_MAX = 4    -- rescans with no lever progress before the room is dropped
D.LEVER_MOVES = 4        -- walks towards a lever that is not beside us before routing gives up

-- Does this object still offer to be pulled? Everything needed is already in the
-- AllObject the world scan returned: a pulled switch is Bool1 = 1 (disabled) while
-- its Action may still read "Pull", which is exactly what D.interactable tests.
-- No extra scan is made for this.
function D.leverUnpulled(o)
	if not D.interactable(o) then return false end
	-- The toxin maze's own switch (live id 49353, option Pull) is NOT one of the five
	-- levers: pulling it toggles the maze, and before the maze has ever been planned
	-- nothing has marked the room as a maze yet. Live, the lever solver walked at it and
	-- crashed on D.gotoTile ("1 up but none can be worked from here", every pass).
	local okId, id = pcall(function() return o.Id end)
	if okId and id == 49353 then return false end
	local act = string.lower(tostring(o.Action or ''))
	return string.find(act, 'pull', 1, true) ~= nil or D.LEVER_ON_SET[o.Id] == true
end

-- One step. Returns true while this room still owns us.
function D.solveSwitches(world, here, px, py)
	if not here then return false end
	-- the maze room has a Switch prop that is not a lever: leave it alone. The maze owns
	-- that switch (it is what starts the puzzle) and must be the only one pulling it -
	-- a second Pull toggles the maze back off.
	if D.mazeRoomKey == rkey(here) or (D.mazeLeverOn and D.mazeLeverOn[rkey(here)])
		or (D.mazeRoomIsMaze and D.mazeRoomIsMaze[rkey(here)]) then return false end
	local key = rkey(here)
	local st = S.pondState[key]
	if st and st.solved then return false end
	-- shared state: never take a room another puzzle owns
	if st and st.kind and st.kind ~= 'levers' then return false end

	-- Everything below comes out of the AllObject array the pass already scanned:
	-- Action says Pull, Bool1 says whether it is still up (a pulled switch is
	-- disabled, the client only marks it), and the room's walk set says whether we
	-- can stand next to it. No extra scans, no path tests.
	local function beside(o, x, y)
		local k = pkey(x, y)
		if here.set[k] then return true end
		return here.set[pkey(x - 1, y)] or here.set[pkey(x + 1, y)]
			or here.set[pkey(x, y - 1)] or here.set[pkey(x, y + 1)]
	end

	local list = {}
	for _, o in ipairs(world.objs or {}) do
		if D.leverUnpulled(o) then
			local t = o.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			local d = (x - px) ^ 2 + (y - py) ^ 2
			-- In this room or on its wall, never a lever from the room next door: a
			-- puzzle that is not in the room is dropped here, so an unreachable lever
			-- elsewhere cannot keep this room "busy" pass after pass. Levers we cannot
			-- walk to are dropped below as well.
			if beside(o, x, y) or D.tileInHere(here, x, y, D.LEVER_SLACK) then
				list[#list + 1] = { obj = o, x = x, y = y, z = math.floor(t.z or 0), d = d }
			end
		end
	end
	if #list == 0 then
		if st and st.kind == 'levers' then
			st.solved = true
			D.dirty = true
			log(string.format('levers in room %s: every lever is pulled - room done', key))
		end
		return false
	end
	table.sort(list, function(a, b) return a.d < b.d end)

	st = st or { kind = 'levers' }
	st.kind = 'levers'
	st.tries, st.clickedAt = st.tries or {}, st.clickedAt or {}
	S.pondState[key] = st

	local pick, waiting, behindWall = nil, nil, nil
	for _, c in ipairs(list) do
		local kk = pkey(c.x, c.y)
		st.tries[kk] = st.tries[kk] or 0
		local last = st.clickedAt[kk]
		if last and (API.SystemTime() - last) < D.LEVER_RECLICK_MS then
			waiting = waiting or c
		elseif st.tries[kk] < D.LEVER_TRIES then
			if beside(c.obj, c.x, c.y) then
				pick = c
				break
			end
			behindWall = behindWall or c
			st.unreach = st.unreach or {}
			if not st.unreach[kk] then
				st.unreach[kk] = true
				log(string.format(
					'levers: %d at %d,%d is not walkable from room %s - not clicking it, routing instead',
					c.obj.Id, c.x, c.y, key))
			end
		end
	end

	if not pick then
		if waiting then
			-- every lever still up was just clicked: the cache needs one refresh before
			-- the Bool1 marks show up (D.WORLD_TTL = 8 s). One rescan is cheaper than
			-- idling into the TTL.
			st.stall = (st.stall or 0) + 1
			if st.stall > D.LEVER_STALL_MAX then
				log(string.format('levers in room %s: %d lever(s) here did not register - moving on',
					key, #list))
				return false
			end
			D.dirty = true
			API.RandomSleep2(200, 60, 120)
			return true
		end
		-- THE ROOM STILL HAS LEVERS UP, SO IT STILL OWNS THE PASS. Falling through to the
		-- ordinary routing is what let the key branch take the middle of a lever solve
		-- ("midlle of solving switches puzzle started picking up keys"): one pass with no
		-- lever beside us - the room blob was split, so `beside` said no - and the chain
		-- went on to loot keys. Walk to the nearest lever instead and stay on the puzzle.
		local c = list[1]
		st.moves = (st.moves or 0) + 1
		if st.moves <= D.LEVER_MOVES then
			local kk = pkey(c.x, c.y)
			st.moveLog = st.moveLog or {}
			if not st.moveLog[kk] then
				st.moveLog[kk] = true
				log(string.format('levers: %d at %d,%d is not beside us - walking to it, the puzzle comes first',
					c.obj.Id, c.x, c.y))
			end
			say(string.format('walking to a lever (%d up)', #list))
			-- D.gotoTile lived in the routing module that is gone; calling it blind threw
			-- "attempt to call a nil value (field 'gotoTile')" on every pass a lever was not
			-- beside us and the room was skipped with nothing done ("stands there like an
			-- idiot"). No router means a lever we cannot walk to is not workable here: let
			-- the room go instead of holding the pass for ever.
			if D.gotoTile and D.gotoTile(world, { x = c.x, y = c.y, z = c.z, id = c.obj.Id, kind = 'lever' }) then
				API.RandomSleep2(700, 250, 400)
				D.dirty = true
				return true
			end
			log(string.format('levers: %d at %d,%d is out of reach and this build has no router - dropping the room',
				c.obj.Id, c.x, c.y))
			st.solved = true
			D.dirty = true
			return false
		end
		-- nothing clickable from here and the walks did not help: let routing get us closer
		log(string.format('levers in room %s: %d up but none can be worked from here - letting the route take over',
			key, #list))
		return false
	end
	st.stall = 0
	st.moves = 0

	-- Never retarget while the last click is still walking us somewhere or the player
	-- is animating: a second click would cancel the walk and the pull that goes with it.
	if isMoving() or D.playerBusy() then
		API.RandomSleep2(120, 40, 80)
		return true
	end

	local kk = pkey(pick.x, pick.y)
	local leftNow = 0
	for _, c in ipairs(list) do
		if not st.clickedAt[pkey(c.x, c.y)] then leftNow = leftNow + 1 end
	end
	st.clickedAt[kk] = API.SystemTime()
	st.tries[kk] = st.tries[kk] + 1
	say(string.format('pulling a lever (%d left)', math.max(leftNow, 1)))
	log(string.format('levers: pulling %d at %d,%d (%d left in room %s, try %d)',
		pick.obj.Id, pick.x, pick.y, math.max(leftNow, 1), key, st.tries[kk]))
	local x0, y0 = px, py
	D.clickObject('Pull', pick.obj)
	-- Wait only for the click to land: the player starts walking or the pull animation
	-- starts. Fixed multi-second waits plus a world rescan per lever is what made five
	-- switches take half a minute.
	local t0 = API.SystemTime()
	while (API.SystemTime() - t0) < D.LEVER_TICK_WAIT do
		if D.playerBusy() or isMoving() then break end
		local nx, ny = ptile()
		if nx ~= x0 or ny ~= y0 then break end
		API.RandomSleep2(100, 30, 60)
	end
	return true
end

--------------------------------------------------------------------
-- puzzles: the magical construct (Magicalconstruct.java)
--------------------------------------------------------------------
-- One npc does the whole room: the Damaged construct offers "Repair" and wants a
-- limb that is taken as stone from a rock pile, carved into a part with the
-- carve menu (interface 1188 picks which part), then imbued. A Magic construct that
-- wakes up is simply fought by the enemy branch.
-- The npc changes id and name at every stage (damaged -> dormant -> awake), so it
-- is matched by name and by the option it shows, never by one id.
D.CONSTRUCT = {
  damaged = 11002,
  rocks = { 49543, 49544, 49545 },
  stone = 17364,
  parts = {
    { unf = 17365, fin = 17368 },   -- arm
    { unf = 17366, fin = 17370 },   -- leg
    { unf = 17367, fin = 17372 },   -- head
  },
  names = { 'arm', 'leg', 'head' },  -- also the carve dialog order
  tries = 8,
}
-- The construct and its rock pile stand against the room's wall, so the room rect is
-- used with this slack; and never further than one room away from the player.
D.CONSTRUCT_SLACK = 2
-- Standing this close to the construct IS being in its room, whatever the room blob is
-- keyed as: a Damaged construct 3 tiles away was thrown away by the rect test, so the
-- puzzle was never detected. The doorway test (with the doorway we entered by excused) is
-- what keeps this from firing on the next room's construct, so the radius can cover a whole
-- room: at 6 the walker detected a construct it then could not reach, because the bot stood
-- 7 tiles off while the walker's own test reaches D.PUZZLE_NEAR.
D.CONSTRUCT_NEAR = 12
-- Which limb is missing, from the construct's examine text in the chat ring.
function D.constructLimb()
  for i = #chat.lines, math.max(1, #chat.lines - 8), -1 do
    local line = chat.lines[i] or ''
    for idx = 1, #D.CONSTRUCT.names do
      local word = D.CONSTRUCT.names[idx]
      if string.find(line, '%f[%w]' .. word .. '%f[%W]') then return idx end
    end
  end
  return nil
end

function D.solveConstruct(world, here, px, py)
  if not here then return false end
  local key = rkey(here)
  local st = puzzleOwn(key, 'construct')
  if st and st.solved then return false end

  local damaged, dormant, awake
  for _, n in ipairs(D.npcScan()) do
    -- THE CONSTRUCT ROOM IS THE ONLY PLACE THIS PUZZLE CAN BE DONE. The npc scan is
    -- floor-wide (npcs stream in up to ~40 tiles), so without this filter the solver
    -- found a Damaged construct in another room and started taking stones and carving
    -- for it while standing on the far side of the map.
    -- BEING IN FRONT OF IT COUNTS AS BEING IN ITS ROOM - but only with NO DOORWAY BETWEEN.
    -- The rectangle test alone missed the live case (a Damaged construct 3 tiles away at
    -- 15740,1051 from 15737,1052 was rejected because the player's blob keyed a different
    -- sub-room), and a plain radius then went the other way and started the puzzle from
    -- outside the room. The line test is what separates the two: a doorway standing
    -- between us and the construct means it is somebody else's room.
    local nt = n.Tile_XYZ
    if nt then
      local nx, ny = math.floor(nt.x), math.floor(nt.y)
      local close = math.max(math.abs(nx - px), math.abs(ny - py)) <= D.CONSTRUCT_NEAR
        and not D.doorBetween(world, px, py, nx, ny, D.enteredDoorSkip())
      if close or D.tileInHere(here, nt.x, nt.y, D.CONSTRUCT_SLACK) then
        local nm = D.bossKey(n.Name)
        if nm == 'damaged construct' or n.Id == D.CONSTRUCT.damaged then damaged = n
        elseif nm == 'dormant construct' then dormant = n
        elseif nm == 'magic construct' then awake = n end
      end
    end
  end

  if not damaged and not dormant and not awake then
    -- none of the three stages is in the room: the construct is dealt with
    if st then
      if Inventory:Contains(D.CONSTRUCT.stone) then Inventory:Drop(D.CONSTRUCT.stone) end
      puzzleMarkSolved(here, 'construct done')
    end
    return false
  end
  -- an awake construct is a fight, not a repair job
  if awake and not damaged and not dormant then return false end

  st = puzzleClaim(key, 'construct', { tries = 0 })
  if not st or st.tries >= D.CONSTRUCT.tries then return false end

  settle()
  if not damaged then
    -- repaired: charge it and the awake construct is the enemy branch's problem
    st.tries = st.tries + 1
    say('charging the construct')
    Interact:NPC(dormant.Name, 'Charge', dormant.Tile_XYZ, 10)
    API.RandomSleep2(2000, 600, 900)
    settle()
    D.dirty = true
    return true
  end

  for i = 1, #D.CONSTRUCT.parts do
    local p = D.CONSTRUCT.parts[i]
    if Inventory:Contains(p.fin) then
      local sx, sy = math.floor(damaged.Tile_XYZ.x), math.floor(damaged.Tile_XYZ.y)
      if (sx - px) ^ 2 + (sy - py) ^ 2 > 36 then
        local tx, ty = D.walkSpotNear(world, sx, sy)
        if tx then
          D.walkTile(tx, ty, 0)
          API.RandomSleep2(1400, 500, 900)
          settle()
          return true
        end
      end
      st.tries = st.tries + 1
      say('repairing the construct')
      -- Direct: an id-based DoAction_NPC re-resolves the id in the engine and can pick
      -- another instance of the same npc on the far side of the floor. This is the
      -- construct we filtered to be in front of us.
      API.DoAction_NPC__Direct(D.ACT_TALK, D.ROUTE_TALK, damaged)
      API.RandomSleep2(2500, 600, 900)
      settle()
      return true
    end
    if Inventory:Contains(p.unf) then
      st.tries = st.tries + 1
      say('imbuing the ' .. D.CONSTRUCT.names[i])
      Inventory:DoAction(p.unf, 1, API.OFF_ACT_GeneralInterface_route)
      API.RandomSleep2(2200, 600, 900)
      settle()
      return true
    end
  end

  if Inventory:Contains(D.CONSTRUCT.stone) then
    if not st.part then
      st.part = D.constructLimb()
      if not st.part and not st.examined then
        st.examined = true
        say('examining the construct')
        Interact:NPC(damaged.Name, 'Examine', damaged.Tile_XYZ, 8)
        API.RandomSleep2(1400, 500, 800)
        return true
      end
      st.part = st.part or 1
      log(string.format('construct: carving the %s (option %d)', D.CONSTRUCT.names[st.part], st.part))
    end
    st.tries = st.tries + 1
    say('carving the ' .. D.CONSTRUCT.names[st.part])
    Inventory:DoAction(D.CONSTRUCT.stone, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(900, 350, 650)
    settle()
    API.KeyboardPress2(0x30 + st.part, 60, 30)
    API.RandomSleep2(1200, 400, 800)
    settle()
    return true
  end

  for _, o in ipairs(world.objs or {}) do
    local t = o.Tile_XYZ
    -- A rock pile in THIS room only: mining one across the floor gave the bot a stone
    -- it could not use anywhere, because the carve menu only works at the construct.
    if t and D.tileInHere(here, t.x, t.y, D.CONSTRUCT_SLACK)
      and (o.Id == D.CONSTRUCT.rocks[1] or o.Id == D.CONSTRUCT.rocks[2]
        or o.Id == D.CONSTRUCT.rocks[3]) then
      st.tries = st.tries + 1
      say('taking a stone')
      D.clickObject('Take', o)
      API.RandomSleep2(1500, 400, 700)
      return true
    end
  end

  -- nothing to carve and no stone on the floor: stop wasting passes on this room
  st.tries = D.CONSTRUCT.tries
  log('construct: no stone and no rock pile in the room - leaving it')
  return false
end

--------------------------------------------------------------------
-- puzzles: the unhappy ghost (UnhappyGhost.java)
--------------------------------------------------------------------
-- A ghost in a wrecked room: the wall is damaged, the pot is broken, the coffin is
-- locked and the jewellery box wants the antique ring that is lying on the floor. Fix
-- the room, unlock the coffin, and once it stands open, bless the remains - that is
-- what finishes it. The java order per pass is Box > Coffin > Wall > Pot > opened
-- coffin, and the box only counts once the ring is in the pack (before that the job is
-- picking the ring up).
--
-- Matched by NAME first: the java's ids are 2011 models and the live ones differ, so
-- they are only a fallback. The click uses the object's OWN option text, whichever
-- variant is in front of us ("Bless-remain", "Fill", "Unlock", "Repair").
D.GHOST_RING     = 19879          -- "Antique ring" (cache-verified, still the same item)
D.GHOST_COFFIN_IDS = { [54593] = true, [54571] = true, [40181] = true }
D.GHOST_OPEN_IDS   = { [54572] = true, [55451] = true }
D.GHOST_WALL_IDS   = { [54580] = true, [54602] = true, [55457] = true }
D.GHOST_BOX_IDS    = { [54598] = true, [54576] = true, [55453] = true }
D.GHOST_POT_IDS    = { [54599] = true, [54577] = true, [55455] = true }
D.GHOST_RANGE = 14    -- tiles; the room is small, this is "in here"
D.GHOST_SLACK = 3     -- the props stand against the walls, outside the walk bounds
D.GHOST_UNLOCK_ALT = 2 -- coffin "Unlock" attempts with the plain opcode before the door one
D.GHOST_BOX_TRIES = 6  -- passes the unfilled box may hold the blessing back
D.ghostTries = {}

-- What is this object, if it is one of the ghost room's? The opened coffin is tested
-- BEFORE the plain coffin: it is the one that can be blessed, and its name contains
-- "coffin" too.
function D.ghostKind(o)
	local nm = string.lower(D.objName(o))
	local act = string.lower(tostring(o.Action or ''))
	if D.GHOST_BOX_IDS[o.Id] or string.find(nm, 'jewel', 1, true) then return 'box' end
	if D.GHOST_OPEN_IDS[o.Id]
		or (string.find(nm, 'coffin', 1, true)
			and (string.find(nm, 'open', 1, true) or string.find(act, 'bless', 1, true))) then
		return 'open'
	end
	if D.GHOST_COFFIN_IDS[o.Id] or string.find(nm, 'coffin', 1, true) then return 'coffin' end
	if D.GHOST_WALL_IDS[o.Id] or string.find(nm, 'damaged wall', 1, true) then return 'wall' end
	if D.GHOST_POT_IDS[o.Id]
		or (string.find(nm, 'pot', 1, true) and string.find(act, 'repair', 1, true)) then
		return 'pot'
	end
	return nil
end

-- Nearest prop of one kind that is inside this room AND offers an option: a solved
-- prop ("opened coffin", a filled box) keeps its name but loses its option, and
-- clicking it again would only earn "There is no interaction on object!".
function D.ghostFind(here, px, py, kind)
	local best, bestD = nil, D.GHOST_RANGE * D.GHOST_RANGE
	for _, o in ipairs(D.objScan()) do
		if o.Type ~= 3 and D.ghostKind(o) == kind and (o.Action or '') ~= '' then
			local t = o.Tile_XYZ
			if t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if x >= here.minx - D.GHOST_SLACK and x <= here.maxx + D.GHOST_SLACK
					and y >= here.miny - D.GHOST_SLACK and y <= here.maxy + D.GHOST_SLACK then
					local d = (x - px) ^ 2 + (y - py) ^ 2
					if d <= bestD then bestD, best = d, o end
				end
			end
		end
	end
	return best
end

function D.ghostAct(o, what)
	local act = tostring(o.Action or '')
	local t = o.Type ~= 3 and o.Tile_XYZ or nil
	if act == '' or not t then return false end
	local x, y = math.floor(t.x), math.floor(t.y)
	local key = x .. ',' .. y .. '/' .. act
	local tries = D.ghostTries[key] or 0
	-- Every prop here offers exactly ONE option, so the first-option slot is the
	-- opcode. The doorway "Unlock" opcode (0xc3) is only proven for doors: if a
	-- coffin "Unlock" does nothing twice, the next attempts send that one as well so
	-- an unverified coffin variant cannot stall the room for the whole floor.
	local op = D.ACT_DEFAULT
	if act == 'Unlock' and tries >= D.GHOST_UNLOCK_ALT then
		op = D.CODE['Unlock'] or D.ACT_DEFAULT
	end
	say(string.format('%s the %s', act, tostring(what or 'ghost room prop')))
	log(string.format('unhappy ghost: %s "%s" %d at %d,%d (op 0x%x, try %d)',
		act, D.objName(o), o.Id, x, y, op, tries + 1))
	if not D.clickGate(o.Id, x, y, act) then
		-- the gate refused it (tile cap, or a key turn in flight at that doorway):
		-- nothing left the client, so this must not count as the room being worked
		log(string.format('unhappy ghost: the %s click was refused before it was sent', act))
		API.RandomSleep2(400, 150, 250)
		return false
	end
	D.ghostTries[key] = tries + 1
	-- the world just changed: whatever is cached about objects is now pre-click
	D.objCache = nil
	-- through the click guard: a disabled record (Bool1 = 1) must not earn a DoAction
	if not D.clickObject(op, o) then return false end
	API.RandomSleep2(1100, 300, 500)
	settle()
	return true
end

-- Has the jewellery box already been filled? The filled box keeps its name, so the
-- only honest signals are "the option is gone" and "a Fill has already been sent
-- there this floor" (D.ghostTries is written by every click ghostAct dispatches).
function D.ghostBoxDone(o)
	local act = tostring(o.Action or '')
	if act == '' then return true end
	local t = o.Tile_XYZ
	if not t then return false end
	return (D.ghostTries[math.floor(t.x) .. ',' .. math.floor(t.y) .. '/' .. act] or 0) > 0
end

function D.solveGhost(world, here, px, py)
	if not here then return false end
	local ringHeld = false
	local okR, has = pcall(function() return Inventory:Contains(D.GHOST_RING) end)
	if okR then ringHeld = has and true or false end
	-- Looted from anywhere the scan can see it, not just from this room: the java's
	-- loot(Ring) is a plain GroundItems.getNearest with no room test, and the ring can
	-- lie in the next room of the floor.
	local ring = nil
	for _, o in ipairs(D.objScan()) do
		if o.Type == 3 and o.Id == D.GHOST_RING then ring = o break end
	end

	-- 1. the jewellery box, first: fill it once the ring is ours, take the ring while
	-- it is not (that is the java's order, and the ring is the only thing the box wants)
	local box = D.ghostFind(here, px, py, 'box')
	local boxDone = (box == nil) or D.ghostBoxDone(box)
	if boxDone then D.ghostBoxWhy, D.ghostBoxStalls = nil, nil end
	if box and ringHeld then
		if D.ghostAct(box, 'jewellery box') then return true end
	elseif box and ring then
		say('taking the antique ring')
		log(string.format('unhappy ghost: taking the antique ring at %d,%d',
			math.floor(ring.Tile_XYZ.x), math.floor(ring.Tile_XYZ.y)))
		D.takeFloorItem(ring, { D.GHOST_RING }, 'antique ring')
		return true
	end
	-- 2. the room itself: unlock the coffin, repair the damaged wall, repair the broken
	-- pot. Java order, and each one only while that prop is still standing.
	for _, kind in ipairs({ 'coffin', 'wall', 'pot' }) do
		local o = D.ghostFind(here, px, py, kind)
		if o and D.ghostAct(o, kind) then return true end
	end
	-- 3. Blessing the remains is the LAST action of this room: it is the one that
	-- frees the ghost, and it takes the coffin's options away, so nothing can be done
	-- in here afterwards. It waits until the box has been filled and the room has
	-- nothing left to unlock or repair. The box branch used to fall straight through
	-- to this when the ring was not lying in this room, which blessed the remains with
	-- the box still unfilled.
	if not boxDone then
		if not string.find(string.lower(tostring(box.Action or '')), 'fill', 1, true) then
			-- it does not offer Fill, so it is not waiting for the ring and cannot be
			-- what holds the blessing back
			boxDone = true
		else
			D.ghostBoxStalls = (D.ghostBoxStalls or 0) + 1
			if D.ghostBoxStalls > D.GHOST_BOX_TRIES then
				-- the ring is nowhere to be had (already used, or never spawned): the
				-- room still has to finish, so bless and say why
				log(string.format('unhappy ghost: the box has wanted the ring for %d passes '
					.. 'and there is no antique ring anywhere - blessing the remains anyway',
					D.GHOST_BOX_TRIES))
				boxDone = true
			else
				if not D.ghostBoxWhy then
					D.ghostBoxWhy = true
					log('unhappy ghost: the jewellery box is still unfilled - not blessing the remains yet')
				end
				return false
			end
		end
	end
	local open = D.ghostFind(here, px, py, 'open')
	if open then return D.ghostAct(open, 'opened coffin') end
	return false
end

--------------------------------------------------------------------
-- puzzles: the collapsing room (Collapsingroom.java)
--------------------------------------------------------------------
-- The room is a hub with up to FOUR doorways. The unit of work is the DOORWAY:
--
--   a doorway HAS a strut when one stands within D.COLLAPSE_DOOR_R of it, and it is
--   CLEARED the moment that strut is a Support strut. While its strut is still a
--   Collapsing strut the doorway is waiting, and the work on it, by distance from the
--   player, is exactly:
--
--     Destroy Rocky 49620  ->  Destroy Rocky 49619  ->  Destroy Rocky 49615-49618
--                          ->  Repair 1 Collapsing strut   (it becomes a Support strut)
--
--   then that doorway is cleared and the next one is taken. Only the debris lying against
--   that doorway's strut is mined - "only 1 rock was needed to access 1 strut" - so rubble
--   anywhere else in the room is left standing, and the room is finished when no doorway
--   is waiting, not when the floor is swept clean.
D.COLLAPSE_ROCK_IDS = { [49622] = true, [49621] = true, [49620] = true, [49619] = true,
	[49618] = true, [49617] = true, [49616] = true, [49615] = true }
D.COLLAPSE_FIX_IDS = { [49610] = true, [49611] = true, [54061] = true }
D.COLLAPSE_DOOR_R = 8      -- a strut this close to a doorway is that doorway's strut
D.COLLAPSE_TRIES = 32      -- clicks in one room before it is left to the router
D.COLLAPSE_PROP_TRIES = 3  -- clicks at one prop before it is passed over
D.COLLAPSE_STRUT_TRIES = 6 -- clicks at one strut: a repair is refused while walking, so it
                           -- needs a longer leash than the debris before it is skipped
D.COLLAPSE_NOT_READY = 3   -- Repair clicks the engine ignored before that strut is left alone
D.COLLAPSE_STRUT_DONE_R = 2 -- a Support strut this close to a Collapsing strut means that
                            -- struct is already UP (distance, not the tile: the marker is a
                            -- separate object and does not always sit on the same tile)
D.COLLAPSE_ROCK_DONE_R = 2  -- debris within 3 tiles of a repaired struct is DONE: it is not
                            -- dug, whatever the doorway's path still looks like
D.COLLAPSE_ANIM_MS = 4000  -- our own click opens this long no-spam window while it animates

-- What is this object, if it belongs to the collapsing room? 'fix' is the repair job,
-- 'rock' the debris. Repair is also the option on a damaged wall (ghost room), a broken
-- barrel and the magical construct, so those names are excluded explicitly - each of
-- them has its own solver and its own room claim.
function D.collapseKind(o)
	-- Bool1 = 1 means the object is DONE, not a target: a destroyed 49620/49619 keeps its
	-- "Destroy" option as a marker, and a repaired strut keeps "Repair" while being a
	-- Support strut. Neither may ever be clicked again.
	if (o.Bool1 or 0) == 1 then return nil end
	if D.COLLAPSE_FIX_IDS[o.Id] then return 'fix' end
	local act = tostring(o.Action or '')
	if act == 'Destroy' or D.COLLAPSE_ROCK_IDS[o.Id] then return 'rock' end
	if act ~= 'Repair' then return nil end
	local nm = string.lower(D.objName(o))
	if string.find(nm, 'barrel', 1, true) or string.find(nm, 'wall', 1, true)
		or string.find(nm, 'pot', 1, true) or string.find(nm, 'construct', 1, true) then
		return nil
	end
	-- the path's own strut: "Collapsing strut" while it still needs Repair
	if string.find(nm, 'strut', 1, true) then return 'fix' end
	if string.find(nm, 'collaps', 1, true) or string.find(nm, 'rubble', 1, true)
		or string.find(nm, 'debris', 1, true) or string.find(nm, 'column', 1, true)
		or string.find(nm, 'support', 1, true) or string.find(nm, 'ceiling', 1, true) then
		return 'fix'
	end
	return nil
end

-- A strut is THE STATE OF ITS PATH: "Collapsing strut" still offers Repair, and a
-- repaired one is a "Support strut" with no option left at all. That is what decides
-- whether a path is finished - not "no props left in the room", because rocks lying
-- elsewhere say nothing about a path that already has its strut up.
function D.collapseStrut(o)
	local nm = string.lower(D.objName(o))
	if not string.find(nm, 'strut', 1, true) then return nil end
	return D.interactable(o) and 'todo' or 'done'
end

-- THE COLLAPSING ROOM, as it is actually built and as it is actually solved:
--
--   a doorway HAS a collapsing strut when one stands within D.COLLAPSE_DOOR_R of it, and
--   it is CLEARED the moment that strut is a Support strut. A doorway whose strut is still
--   a Collapsing strut is work, and the work on it is, by distance from the player:
--
--     Destroy Rocky 49620  ->  Destroy Rocky 49619  ->  Destroy Rocky 49615-49618
--                          ->  Repair 1 Collapsing strut  (it becomes a Support strut)
--
--   ...and then that doorway is cleared and the next one is taken. Only the debris lying
--   against that doorway's strut is mined - "only 1 rock was needed to access 1 strut" -
--   so rubble elsewhere in the room is left standing.
D.COLLAPSE_RANK = { [49620] = 0, [49619] = 1,
	[49618] = 2, [49617] = 2, [49616] = 2, [49615] = 2 }

function D.solveCollapse(world, here, px, py)
	if not here then return false end
	local key = rkey(here)
	local st = puzzleOwn(key, 'collapse')
	-- THE PLAYER'S OWN ANIMATION IS THE ACTION. Mining a pile and repairing a strut both
	-- put the client into a multi-second swing, and a click sent during it is dropped -
	-- three clicks at one pile in the time a single mine takes, which is exactly the
	-- spam. CheckAnim is the engine's answer for the local player; only a click this
	-- solver just sent opens the window, so an unrelated animation in the room (an ore
	-- rock, a monster hitting us) cannot freeze the room.
	if st and st.clickAt and (API.SystemTime() - st.clickAt) < D.COLLAPSE_ANIM_MS
		and API.CheckAnim(30) then
		API.RandomSleep2(300, 100, 150)
		return true
	end
	-- Everything the room holds, from one scan: the doorways, the struts (Collapsing while
	-- they still offer Repair, Support once done) and the debris.
	local struts, rocks, doors = {}, {}, {}
	for _, d in ipairs(world.doors or {}) do
		if doorInRoom(here, d) then doors[#doors + 1] = d end
	end
	local sawStrut = false
	local upPos = {}        -- where the Support struts stand
	for _, o in ipairs(D.objScan()) do
		local t = o.Tile_XYZ
		if t then
			local x, y = math.floor(t.x), math.floor(t.y)
			local state = D.collapseStrut(o)
			if state then
				sawStrut = true
				if state == 'done' then upPos[#upPos + 1] = { x = x, y = y } end
				struts[#struts + 1] = { obj = o, x = x, y = y, z = t.z, state = state }
			end
		end
	end
	st = puzzleClaim(key, 'collapse', { tries = 0 })
	if not st then return false end          -- another puzzle owns this room
	st.clicks = st.clicks or {}
	st.cleared = st.cleared or {}
	st.notReady = st.notReady or {}
	st.upPos = st.upPos or {}
	for _, u in ipairs(upPos) do st.upPos[#st.upPos + 1] = u end
	-- DEBRIS WITHIN 3 TILES OF A REPAIRED STRUCT IS DONE. It is not blocking anything that
	-- matters any more, and digging it is the "wasting time on 49615-49618" loop.
	local function nearUpStruct(r)
		for _, u in ipairs(st.upPos) do
			if math.max(math.abs(u.x - r.x), math.abs(u.y - r.y)) <= D.COLLAPSE_ROCK_DONE_R then
				return true
			end
		end
		return false
	end
	for _, o in ipairs(D.objScan()) do
		local t = o.Tile_XYZ
		if t and not D.collapseStrut(o) and D.interactable(o) and D.collapseKind(o) == 'rock' then
			local x, y = math.floor(t.x), math.floor(t.y)
			if not nearUpStruct({ x = x, y = y }) then
				rocks[#rocks + 1] = { obj = o, x = x, y = y, z = t.z }
			end
		end
	end
	-- A STRUCT IS UP WHEN A SUPPORT STRUT STANDS WITHIN D.COLLAPSE_STRUT_DONE_R OF IT, and
	-- that is a DISTANCE test: the marker is its own object and does not have to share the
	-- decor's tile. The struts we repaired ourselves are remembered as positions too, so a
	-- struct is never repaired a second time even after the marker streams out of the scan.
	local function strutUp(sr)
		for _, u in ipairs(st.upPos) do
			if math.max(math.abs(u.x - sr.x), math.abs(u.y - sr.y)) <= D.COLLAPSE_STRUT_DONE_R then
				return true
			end
		end
		return false
	end
	if sawStrut then st.sawStrut = true end
	if st.tries >= D.COLLAPSE_TRIES then return false end

	-- WHICH DOORWAYS ARE STILL WAITING. A doorway is CLEARED only when the whole job on it
	-- is done: its strut repaired into a Support strut AND no debris left lying on its path.
	-- Repairing the strut alone is not enough - the rubble still blocks the way out, and
	-- stopping there is exactly "you haven't cleared the doorway".
	local work = {}
	for _, d in ipairs(doors) do
		local k = dkey(d)
		if not st.cleared[k] then
			local mine, done = {}, false
			for _, sr in ipairs(struts) do
				if math.max(math.abs(sr.x - d.x), math.abs(sr.y - d.y)) <= D.COLLAPSE_DOOR_R then
					if sr.state == 'done' or strutUp(sr) then
						-- a Support strut within D.COLLAPSE_STRUT_DONE_R: this struct is up,
						-- whatever its leftover decor still offers
						done = true
					else
						mine[#mine + 1] = sr
					end
				end
			end
			-- the debris ON THIS DOORWAY'S PATH: within D.COLLAPSE_DOOR_R of its door
			local onPath = {}
			for _, r in ipairs(rocks) do
				if math.max(math.abs(r.x - d.x), math.abs(r.y - d.y)) <= D.COLLAPSE_DOOR_R then
					onPath[#onPath + 1] = r
				end
			end
			-- only a doorway that carries a strut of some kind belongs to this puzzle
			if done or #mine > 0 then
				if done and #onPath == 0 then
					st.cleared[k] = true
					say(string.format('doorway %d cleared', d.id))
					log(string.format(
						'collapsing room: doorway %d at %d,%d is cleared - support strut up and the path swept',
						d.id, d.x, d.y))
				else
					work[#work + 1] = {
						door = d, key = k, struts = mine, rocks = onPath, done = done,
						dist = math.max(math.abs(d.x - px), math.abs(d.y - py)),
					}
				end
			end
		end
	end
	table.sort(work, function(a, b)
		if a.dist ~= b.dist then return a.dist < b.dist end
		return a.key < b.key
	end)

	-- DONE WHEN NO DOORWAY IS WAITING. Rubble that lies on no doorway's path is not this
	-- puzzle's business.
	if #work == 0 then
		if st.sawStrut then
			puzzleMarkSolved(here, 'every doorway is cleared')
		end
		return false
	end

	-- One click per pass, on the closest doorway that is still waiting: its debris in the
	-- order 49620 -> 49619 -> 49615-49618, and then its strut. The debris is NOT optional -
	-- it keeps being destroyed after the repair until the path is clean.
	local pick, pickFrom
	for _, w in ipairs(work) do
		local best
		for _, r in ipairs(w.rocks) do
			local rk = pkey(r.x, r.y)
			if (st.clicks[rk] or 0) < D.COLLAPSE_PROP_TRIES then
				local rank = D.COLLAPSE_RANK[r.obj.Id] or 3
				local d = math.max(math.abs(r.x - px), math.abs(r.y - py))
				if not best or rank < best.rank or (rank == best.rank and d < best.d) then
					best = { p = r, rank = rank, d = d }
				end
			end
		end
		if best then pick, pickFrom = best.p, w break end
		local near
		for _, sr in ipairs(w.struts) do
			local sk = pkey(sr.x, sr.y)
			if (st.clicks[sk] or 0) < D.COLLAPSE_STRUT_TRIES
				and (st.notReady[sk] or 0) < D.COLLAPSE_NOT_READY then
				local d = math.max(math.abs(sr.x - px), math.abs(sr.y - py))
				if not near or d < near.d then near = { p = sr, d = d } end
			end
		end
		if near then pick, pickFrom = near.p, w break end
		if st.whyLog ~= w.key then
			st.whyLog = w.key
			log(string.format(
				'collapsing room: doorway %d at %d,%d still has %d debris / %d strut(s) but nothing on it can be clicked any more',
				w.door.id, w.door.x, w.door.y, #w.rocks, #w.struts))
		end
	end
	if not pick then return false end

	local pk = pkey(pick.x, pick.y)
	local act = tostring(pick.obj.Action or 'Destroy')
	say(string.format('%s the %s', act, D.objName(pick.obj)))
	log(string.format('collapsing room: %s "%s" %d at %d,%d (try %d/%d)',
		act, D.objName(pick.obj), pick.obj.Id, pick.x, pick.y,
		(st.tries or 0) + 1, D.COLLAPSE_TRIES))
	if D.clickObject(act, pick.obj) then
		st.tries = st.tries + 1
		st.clickAt = API.SystemTime()
		API.RandomSleep2(1200, 400, 600)
		settle()
		-- DID IT START? Standing next to the prop, an accepted action puts the player into the
		-- swing straight away. With no swing the engine ignored the click - a strut clicked
		-- before its debris is off the path - and that must not spend the prop's clicks.
		local arm = math.max(math.abs(pick.x - px), math.abs(pick.y - py)) <= 1
		if arm and not API.CheckAnim(60) then
			st.notReady[pk] = (st.notReady[pk] or 0) + 1
			log(string.format(
				'collapsing room: %s on %s %d at %d,%d did not start - not ready yet (%d/%d)',
				act, D.objName(pick.obj), pick.obj.Id, pick.x, pick.y,
				st.notReady[pk], D.COLLAPSE_NOT_READY))
			return true
		end
		st.notReady = {}
		st.clicks[pk] = (st.clicks[pk] or 0) + 1
		if act == 'Repair' then
			st.sawStrut = true
			-- where we repaired is remembered as a POSITION: the struct there is up
			st.upPos[#st.upPos + 1] = { x = pick.x, y = pick.y }
		end
		return true
	end
	API.RandomSleep2(400, 150, 250)
	return false
end

--------------------------------------------------------------------
-- puzzles: the damaged bridge (DamagedBridge.java)
--------------------------------------------------------------------
-- Two ways to get across, and the room carries one or both:
--
--   damaged bridge (54187-54189) - Repair it, but Repair only exists once we hold a
--        CARVED stone: mine a rock (54183/54184, "Mine") -> Stone 19660 ->
--        inventory option 1 "Carve" -> Carved stone 19661 -> Repair.
--   agile bridge (54010-54012)  - Repair it with 5 Wood 19651, which comes from
--        raiding the wood box (54023, "Raid"); with no wood box in reach the bridge
--        is simply jumped ("Jump"), which is also how the room is crossed.
--
-- The java picks the agile bridge whenever one is in the room and only falls back to the
-- stone route otherwise; that is kept, because the wood route needs no mining at all.
D.BRIDGE_ROCK_IDS   = { [54183] = true, [54184] = true }
D.BRIDGE_FIX_IDS    = { [54187] = true, [54188] = true, [54189] = true }
D.BRIDGE_AGILE_IDS  = { [54010] = true, [54011] = true, [54012] = true }
D.BRIDGE_WOODBOX_IDS = { [54023] = true }
D.BRIDGE_STONE      = 19660     -- "Stone", carved into
D.BRIDGE_CARVED     = 19661     -- "Carved stone"
D.BRIDGE_WOOD       = 19651     -- "Wooden plank" (the cache's name for it)
D.BRIDGE_WOOD_NEED  = 5         -- the repair of the bridge costs 5 planks
D.BRIDGE_NEAR       = 12        -- a bridge this close, with no doorway between, is ours
D.BRIDGE_TRIES      = 6         -- clicks at one prop before it is passed over

-- HOW MANY PLANKS DO WE HOLD? Inventory:GetItemAmount is the documented getter; it is asked
-- first, then the older InvItemcount, and finally a sweep of the inventory for anything
-- named "...plank" - a floor that hands out a different plank id would otherwise read as
-- zero and the bot would raid crates it has already emptied.
function D.bridgePlanks()
	local want = D.BRIDGE_WOOD_NEED
	local n = 0
	local ok, v = pcall(function() return Inventory:GetItemAmount(D.BRIDGE_WOOD) end)
	if ok and tonumber(v) then n = tonumber(v) end
	if n < want then
		local ok2, v2 = pcall(function() return Inventory:InvItemcount(D.BRIDGE_WOOD) end)
		if ok2 and tonumber(v2) and tonumber(v2) > n then n = tonumber(v2) end
	end
	if n < want then
		local ok3, items = pcall(function() return Inventory:GetItems() end)
		if ok3 and items then
			local sum = 0
			for _, it in ipairs(items) do
				local ok4, nm, amt = pcall(function() return it.name, it.amount end)
				if ok4 and nm and string.find(string.lower(tostring(nm)), 'plank', 1, true) then
					sum = sum + (tonumber(amt) or 1)
				end
			end
			if sum > n then n = sum end
		end
	end
	return n
end

-- Is this prop ours to work on? The room blob is unreliable (it merges across walls and
-- splits one room in two), so it cannot be the only test - live, the bridge at 14776,1223
-- and its crate at 14774,1229 sat outside the blob the bot reported (14753:1217) and the
-- solver decided the room held no bridge at all.
-- The doorway line test is not enough on its own either: the doorway we walk IN by sits one
-- tile off the line from us to the bridge (14768,1224 against a line at y=1223), so a
-- bridge ten tiles away in OUR OWN room read as the next room's business. What decides it
-- is the physical walk search: a tile we can walk to without crossing a doorway is in the
-- room we are standing in.
local function bridgeOurs(world, here, x, y, px, py)
	if here and here.set and here.set[pkey(x, y)] then return true end
	if math.max(math.abs(x - px), math.abs(y - py)) > D.BRIDGE_NEAR then return false end
	local phys = D.walkBfs(world)
	if phys then return D.walkReach(phys, x, y, 2) end
	return not D.doorBetween(world, px, py, x, y, D.enteredDoorSkip and D.enteredDoorSkip() or nil)
end

local function bridgePick(world, here, ids, px, py)
	local best
	for _, o in ipairs(D.objScan()) do
		local ok, id2, t = pcall(function() return o.Id, o.Tile_XYZ end)
		if ok and id2 and ids[id2] and t then
			local x, y = math.floor(t.x), math.floor(t.y)
			if bridgeOurs(world, here, x, y, px, py) then
				local d = math.max(math.abs(x - px), math.abs(y - py))
				if not best or d < best.d then
					best = { obj = o, id = id2, x = x, y = y, z = math.floor(t.z or 0), d = d,
						name = D.objName(o), act = tostring(o.Action or '') }
				end
			end
		end
	end
	return best
end

-- One step. Returns true while this room still owns us.
-- THE STATE IS THIS SOLVER'S OWN. S.pondState is keyed by the room blob and shared, and a
-- room the collapsing puzzle claimed earlier ("the collapse puzzle is not finished", live)
-- made puzzleClaim return nil here - so a bridge standing in that same blob could never be
-- worked, which is the "doesn't know it is a puzzle". Counters live in D.bridgeTry and the
-- room is only reported solved through puzzleMarkSolved once the bridge is really gone.
D.bridgeTry, D.bridgeWorked, D.bridgeDone = {}, {}, {}
function D.solveBridge(world, here, px, py)
	if not here then return false end
	local key = rkey(here)
	if D.bridgeDone[key] then return false end
	local agile = bridgePick(world, here, D.BRIDGE_AGILE_IDS, px, py)
	local damaged = bridgePick(world, here, D.BRIDGE_FIX_IDS, px, py)
	if not agile and not damaged then
		-- no bridge left in a room this solver was working: that room is finished. Only then
		-- is the shared solved flag set, and only when no OTHER puzzle owns the room.
		if D.bridgeWorked[key] then
			D.bridgeDone[key] = true
			D.bridgeWorked[key] = nil
			D.dirty = true
			local shared = S.pondState[key]
			if not shared or not shared.kind or shared.kind == 'bridge' then
				puzzleMarkSolved(here, 'the bridge is repaired')
			else
				log(string.format('damaged bridge: room %s has no bridge left (%s owns it) - nothing more to do',
					key, tostring(shared.kind)))
			end
		end
		return false
	end
	D.bridgeTry[key] = D.bridgeTry[key] or { n = 0, k = {} }
	local st = D.bridgeTry[key]
	if st.n >= D.BRIDGE_TRIES * 4 then return false end

	local function attempt(k)
		st.k[k] = (st.k[k] or 0) + 1
		return st.k[k]
	end
	-- The ACTION CHANGES with the inventory: an "Unfinished bridge" offers Jump until it can
	-- be repaired, then Repair (live: id 54011 "Unfinished bridge" at 14776,1223 shows Jump
	-- with no wood in hand). So every click re-reads the live record and uses ITS option; the
	-- wanted verb is only the fallback for a record that has none.
	local function liveAct(t, want)
		local o = D.liveObjectAt(t.id, t.x, t.y)
		if o and o ~= false then
			local a = tostring(o.Action or '')
			if a ~= '' then return a, o end
		end
		return want, t.obj
	end
	-- REPAIR ON THE BRIDGE IS ITS SECOND OPTION (offset 1). The record's own Action field
	-- only carries the DEFAULT option ("Jump"), so asking for Repair through the default
	-- packet jumps instead of repairing - the click has to go out on the route1 packet,
	-- exactly like the flip tile's "Force". The damaged bridge (54187-54189) has Repair as
	-- its only option, so it stays on route0.
	local function click(t, want)
		if not t then return false end
		local action, obj, route = want, t.obj, D.ROUTE_OBJ
		if want == 'Repair' and D.BRIDGE_AGILE_IDS[t.id] then
			route = API.OFF_ACT_GeneralObject_route1
		else
			action, obj = liveAct(t, want)
		end
		local k = action .. pkey(t.x, t.y)
		if (st.k[k] or 0) >= D.BRIDGE_TRIES then return false end
		attempt(k)
		st.n = st.n + 1
		say(string.format('%s the %s', action, t.name ~= '' and t.name or 'bridge'))
		log(string.format('damaged bridge: %s "%s" %d at %d,%d (try %d)%s',
			action, tostring(t.name), t.id, t.x, t.y, st.k[k],
			route ~= D.ROUTE_OBJ and ' - option 2 (route1)' or ''))
		settle()
		local ok = D.clickObject(action, obj, route)
		if ok then D.bridgeWorked[key] = true end
		API.RandomSleep2(1300, 400, 700)
		settle()
		return ok
	end

	-- THE BRIDGE FIRST, like the java: no mining needed while planks are about.
	if agile then
		local wood = D.bridgePlanks()
		local repaired = (st.k['Repair' .. pkey(agile.x, agile.y)] or 0)
		if wood >= D.BRIDGE_WOOD_NEED and repaired < D.BRIDGE_TRIES then
			return click(agile, 'Repair')
		end
		-- PLANKS COME FROM THE CRATE. Raid it while one is in the room; the click carries its
		-- own reach and the client walks over, so no walk of our own is needed.
		local box = bridgePick(world, here, D.BRIDGE_WOODBOX_IDS, px, py)
		if box and repaired < D.BRIDGE_TRIES then
			local act = tostring(select(1, liveAct(box, 'Raid')))
			if act ~= '' then
				if click(box, 'Raid') then return true end
			end
			log(string.format('damaged bridge: wood crate %d at %d,%d offers no Raid any more', box.id, box.x, box.y))
		end
		-- nothing left to repair it with: jump it and cross. THE OBJECT GOES when the jump
		-- lands - the room is finished, not broken, so this is recorded as the bridge being
		-- worked and the next pass sees no bridge and closes the room.
		log(string.format('damaged bridge: %d plank(s) held, %d needed - jumping across instead',
			wood, D.BRIDGE_WOOD_NEED))
		return click(agile, 'Jump')
	end

	-- DAMAGED BRIDGE: carved stone -> Repair, stone -> Carve, nothing -> Mine a rock.
	local hasCarved, hasStone = false, false
	local okC, c = pcall(function() return Inventory:Contains(D.BRIDGE_CARVED) end)
	hasCarved = okC and c == true
	local okS, s2 = pcall(function() return Inventory:Contains(D.BRIDGE_STONE) end)
	hasStone = okS and s2 == true
	if hasCarved then
		local did = click(damaged, 'Repair')
		-- the java throws the plain stone away once the carved one is in hand: the
		-- inventory only has room for one of them
		if hasStone then
			pcall(function() Inventory:Drop(D.BRIDGE_STONE) end)
		end
		return did
	end
	if hasStone then
		local k = 'carve' .. pkey(damaged.x, damaged.y)
		if (st.k[k] or 0) >= D.BRIDGE_TRIES then return false end
		attempt(k)
		st.n = st.n + 1
		say('carving the stone')
		log(string.format('damaged bridge: carving stone %d (option 1 "Carve") for the bridge at %d,%d (try %d)',
			D.BRIDGE_STONE, damaged.x, damaged.y, st.k[k]))
		settle()
		-- Inventory resolves the item by id, so no slot maths is needed.
		pcall(function() Inventory:DoAction(D.BRIDGE_STONE, 1, API.OFF_ACT_GeneralInterface_route) end)
		D.bridgeWorked[key] = true
		API.RandomSleep2(1100, 400, 700)
		settle()
		return true
	end
	local rock = bridgePick(world, here, D.BRIDGE_ROCK_IDS, px, py)
	if not rock then
		log(string.format('damaged bridge: %d,%d needs a carved stone, there is no stone and no rock in the room',
			damaged.x, damaged.y))
		return false
	end
	return click(rock, 'Mine')
end

--------------------------------------------------------------------
-- puzzles: the grapple bridge / winch bridge (WhinchBridge.java)
--------------------------------------------------------------------
-- One room, two ways to get a rope across the chasm, and the script has to know both
-- because the java only knows one of them:
--
--   winch variant  - a "Winch" (54647 / 39917, option "Operate") stands in the room and
--        the bridge itself (39914 / 39915 / 39930, name "Bridge", NO option at all)
--        blocks the way. Operate the winch and that bridge becomes crossable.
--   grapple variant (LIVE, room 12448..12463 x 1808..1823) - there is NO WINCH in the
--        room at all, and the game SPAWNS the way across the moment the climbing hook
--        is thrown: the chasm (54238 / 54239 / 54240, "Grapple") gains a
--        "Tightrope" 54242 ("Walk-the") on the same tiles. WhinchBridge.java gives up
--        on exactly this room - `if (!MyObjects.There(Whinch))` opens the back door and
--        sets LeaveDungeon - and it gives up again one line later when a rope bridge is
--        already there. That is the whole reason this solver exists: the room the java
--        abandons is the room we are standing in.
--
-- The chain is four clicks and one combination, and every click is the prop's OWN
-- default option - the item in the pack is used automatically, with nothing put on the
-- cursor first (verified click by click in the client):
--
--   Meatcorn stash       54255 "Plunder"   -> Meatcorn            19665
--   Spinning wheel       49935 "Spin"      -> Meatcorn rope       19667
--   Climbing hook heads  54251 "Retrieve"  -> Broken hook head    19663
--   Anvil                54259 "Smith"     -> Climbing hook head  19664
--   rope + head, Inventory:UseItemOnItem   -> Climbing hook       19668
--   Chasm                54238 "Grapple"   -> THE TIGHTROPE SPAWNS
--   Tightrope            54242 "Walk-the"  -> the other half of the room
--
-- SOLVED TEST: a Tightrope standing in this room. The rope being across IS the puzzle
-- being solved - the far half, and the doorway in it, can only be reached by walking it.
-- CROSSING IS NOT THIS SOLVER'S JOB any more. The rope is a pair of walkable tiles in
-- D.walkBfs (see D.walkPairs), and D.openLocalDoors crosses it whenever the doorway it
-- wants to open is on the other side - which also means the bot can cross BACK when a
-- route needs the near half again, something a "cross once" flag could never do.
D.GRAP_MEATCORN = 19665   -- "Meatcorn"
D.GRAP_ROPE     = 19667   -- "Meatcorn rope"
D.GRAP_BROKEN   = 19663   -- "Broken climbing hook head"
D.GRAP_HEAD     = 19664   -- "Climbing hook head" (the anvil's product)
D.GRAP_HOOK     = 19668   -- "Climbing hook" (rope + head), what the chasm wants

D.GRAP_STASH_IDS     = { [54255] = true, [54253] = true, [54568] = true, [54646] = true }
D.GRAP_WHEEL_IDS     = { [49935] = true, [49934] = true, [49936] = true,
                         [53749] = true, [55566] = true }
D.GRAP_HOOKBOX_IDS   = { [54251] = true, [54249] = true, [54645] = true, [54567] = true }
D.GRAP_ANVIL_IDS     = { [54259] = true, [54257] = true, [54258] = true, [54260] = true }
-- The edge we throw the hook over. 39912 / 39929 are the older models that carry the
-- Grapple option themselves; the 5423x chasms are what the live room has.
D.GRAP_CHASM_IDS     = { [54237] = true, [54238] = true, [54239] = true, [54240] = true,
                         [39912] = true, [39929] = true }
-- The UN-ROPED bridge of the winch variant: no option at all, so it is a trigger (and a
-- reason to operate the winch) and never a click target.
D.GRAP_BRIDGE_IDS    = { [39914] = true, [39915] = true, [39930] = true }
D.GRAP_WINCH_IDS     = { [54647] = true, [39917] = true }
-- The spawned way across, and it CHANGES ID UNDER US: live, the grapple spawned
-- 54242 "Walk-the", and the same tile answered 54246 "Cross-the" once it had been walked
-- (the rope becomes permanent). So both families are the same prop, and the solver clicks
-- whatever option the LIVE record offers instead of a fixed verb - 54241-54244 are
-- "Walk-the", 54245-54248 and 37267 are "Cross-the".
D.GRAP_TIGHTROPE_IDS = { [54241] = true, [54242] = true, [54243] = true, [54244] = true,
                         [54245] = true, [54246] = true, [54247] = true, [54248] = true,
                         [37267] = true }

D.GRAP_NEAR   = 14   -- tiles: the room is 16x16, so a prop of ours is never further than
                     -- this from us without being the next room's business
D.GRAP_SLACK  = 2    -- the room blob is built from WALKABLE tiles, and every prop here
                     -- stands on a blocked one - the chasm especially, which the blob often
                     -- reports from the far side of itself. A room is 16 tiles from its
                     -- neighbour, so two tiles of slack can never reach into the next room.
D.GRAP_TRIES  = 6    -- clicks at one prop before it is passed over for this pass

-- EVERY PROP OF THIS PUZZLE THAT BELONGS TO THIS ROOM, nearest of each family, in ONE
-- sweep: the chain of solvers runs on every pass of every room, so asking the engine for
-- the same list eight times is eight times the cost for the same answer.
--
-- The room blob alone is not trusted (it merges across walls and splits one room in two -
-- the damaged bridge solver learned that live), so a prop is ours only when it is both
-- inside the room box and within reach of where we stand.
local function grapScan(here, px, py)
	local found = {}
	if not here then return found end
	for _, o in ipairs(D.objScan()) do
		local id = tonumber(D.objGet(o, 'Id'))
		if id then
			local fam
			if D.GRAP_TIGHTROPE_IDS[id] then fam = 'tight'
			elseif D.GRAP_CHASM_IDS[id] then fam = 'chasm'
			elseif D.GRAP_BRIDGE_IDS[id] then fam = 'bridge'
			elseif D.GRAP_WINCH_IDS[id] then fam = 'winch'
			elseif D.GRAP_STASH_IDS[id] then fam = 'stash'
			elseif D.GRAP_HOOKBOX_IDS[id] then fam = 'hookbox'
			elseif D.GRAP_WHEEL_IDS[id] then fam = 'wheel'
			elseif D.GRAP_ANVIL_IDS[id] then fam = 'anvil'
			end
			if fam then
				local tx, ty = D.objTile(o)
				if tx and ty then
					local x, y = math.floor(tx), math.floor(ty)
					local d = math.max(math.abs(x - px), math.abs(y - py))
					local cur = found[fam]
					if d <= D.GRAP_NEAR and D.tileInHere(here, x, y, D.GRAP_SLACK)
						and (not cur or d < cur.d) then
						found[fam] = { obj = o, id = id, x = x, y = y, d = d,
							name = D.objName(o),
							act = tostring(D.objGet(o, 'Action') or '') }
					end
				end
			end
		end
	end
	return found
end

-- How many of this item do we hold? InvItemcount is asked first and Contains is the
-- fallback, because a held item whose count reads 0 is the difference between "go and
-- make the rope" and "throw the hook we are already holding".
local function grapHeld(id)
	local ok, n = pcall(function() return Inventory:InvItemcount(id) end)
	n = (ok and tonumber(n)) or 0
	if n == 0 then
		local ok2, b = pcall(function() return Inventory:Contains(id) end)
		if ok2 and b == true then n = 1 end
	end
	return n
end

D.grapTry = {}
function D.solveGrappleBridge(world, here, px, py)
	if not (here and world) then return false end
	local key = rkey(here)
	local st = D.grapTry[key]
	if not st then st = {}; D.grapTry[key] = st end
	-- ONE ACTION PER PASS. Every prop here changes the room or the pack, so the next
	-- step has to be re-read from the world rather than guessed from the plan that
	-- produced this one.
	local found = grapScan(here, px, py)
	local tight, chasm = found.tight, found.chasm
	local bridge, winch = found.bridge, found.winch
	local stash, hookbox = found.stash, found.hookbox
	-- Only the props that exist in no other room identify the room; the anvil and the
	-- spinning wheel are targets once it is identified, never triggers.
	local ours = st.worked or chasm or bridge or winch or stash or hookbox

	-- 0. THE ROPE IS ACROSS: this IS the solved state. The walker crosses it (see
	-- D.walkPairs / D.openLocalDoors), so there is nothing left for the solver to click.
	if tight then
		-- A tightrope only solves a room this solver has worked in (or one that still
		-- carries the props that make it this puzzle). Anything else is somebody else's
		-- rope and must not be reported as this puzzle being finished.
		if not ours then return false end
		if not st.tightSaid then
			st.tightSaid = true
			puzzleMarkSolved(here, 'the tightrope is across - the walker crosses it')
			log(string.format('grapple bridge: room %s has its tightrope (%d "%s" at %d,%d) - room solved, crossings belong to the walker',
				key, tight.id, tostring(tight.name), tight.x, tight.y))
		end
		return false
	end

	-- 1. IS THIS ROOM EVEN OURS? Only the props that exist in no other room count.
	if not ours then return false end

	-- Clicking a prop: its own option, its own record, and a budget per prop tile so a
	-- prop that refuses cannot be hammered every 700 ms.
	local function click(t, want, what)
		if not t then return false end
		local act = t.act ~= '' and t.act or want
		local k = act .. pkey(t.x, t.y)
		local n = (st[k] or 0) + 1
		st[k] = n
		if n > D.GRAP_TRIES then
			if not st['skip' .. k] then
				st['skip' .. k] = true
				log(string.format('grapple bridge: %s %d at %d,%d still answering after %d clicks - passing it over',
					tostring(t.name), t.id, t.x, t.y, D.GRAP_TRIES))
			end
			return false
		end
		say(what)
		log(string.format('grapple bridge: %s %s "%s" %d at %d,%d (try %d)%s',
			what, act, tostring(t.name), t.id, t.x, t.y, n,
			t.d > 2 and ' - the client has to walk first' or ''))
		settle()
		local ok = D.clickObject(act, t.obj, D.ROUTE_OBJ)
		if ok then st.worked = true end
		API.RandomSleep2(1200, 400, 800)
		settle()
		return ok
	end

	-- 2. THE WINCH VARIANT NEEDS NOTHING FROM THE PACK. Operate it while the un-roped
	-- bridge still blocks; once that bridge is no longer there the winch has done its
	-- job and there is nothing left for this solver to click.
	if winch then
		if bridge then
			st.operated = true
			return click(winch, 'Operate', 'operating the winch')
		end
		if st.operated then
			puzzleMarkSolved(here, 'the winch has taken the rope across')
			log(string.format('grapple bridge: room %s - the winch is turned and no blocking bridge is left',
				key))
			return false
		end
	end

	-- 3. THE HOOK, THROWN OVER THE CHASM. This is the step that spawns the tightrope.
	if chasm and grapHeld(D.GRAP_HOOK) > 0 then
		return click(chasm, 'Grapple', 'throwing the climbing hook across the chasm')
	end

	-- 4. ROPE + HOOK HEAD -> CLIMBING HOOK. The one step that is not a click: the two
	-- halves are combined in the pack, which is exactly what "You tie the rope to the
	-- climbing hook head." reports. It is not gated on the chasm being in sight: holding
	-- both halves can only happen in this room, and the hook has to exist before the
	-- throw either way.
	if grapHeld(D.GRAP_ROPE) > 0 and grapHeld(D.GRAP_HEAD) > 0 then
		say('tying the rope to the climbing hook head')
		log(string.format('grapple bridge: using %d on %d in the pack (rope onto hook head)',
			D.GRAP_ROPE, D.GRAP_HEAD))
		settle()
		local ok = pcall(function() return Inventory:UseItemOnItem(D.GRAP_ROPE, D.GRAP_HEAD) end)
		if ok then st.worked = true end
		API.RandomSleep2(1000, 300, 600)
		settle()
		return ok == true
	end

	-- 5. NO ROPE YET: meatcorn -> spin, or plunder the stash for one.
	if grapHeld(D.GRAP_ROPE) == 0 then
		if grapHeld(D.GRAP_MEATCORN) > 0 then
			if found.wheel then return click(found.wheel, 'Spin', 'spinning the meatcorn into rope') end
			log(string.format('grapple bridge: %d meatcorn in the pack and no spinning wheel in room %s',
				D.GRAP_MEATCORN, key))
			return false
		end
		if stash then return click(stash, 'Plunder', 'plundering the meatcorn stash') end
		log(string.format('grapple bridge: room %s needs a rope and has neither meatcorn nor a stash', key))
		return false
	end

	-- 6. ROPE IN HAND, NO HOOK HEAD: retrieve one, or repair the broken one we hold.
	if grapHeld(D.GRAP_HEAD) == 0 then
		if grapHeld(D.GRAP_BROKEN) > 0 then
			if found.anvil then return click(found.anvil, 'Smith', 'repairing the climbing hook head') end
			log(string.format('grapple bridge: broken hook head in the pack and no anvil in room %s', key))
			return false
		end
		if hookbox then return click(hookbox, 'Retrieve', 'retrieving a climbing hook head') end
		log(string.format('grapple bridge: room %s needs a climbing hook head and has no crate left', key))
	end
	return false
end

-- The walls of this puzzle are half walls: a wall can share the tile the player
-- stands on, and which way a tile may be LEFT is decided by that tile's own wall
-- cut bits. A plain tile grid cannot see that and always finds a straight line
-- through it. The type 99 map tiles ReadAllObjectsArray hands back carry exactly
-- the missing data:
--   Cmb_lv     wall cuts, low nibble N=1 E=2 S=4 W=8, corner infill NW=16 NE=32
--              SE=64 SW=128 (a filled corner forbids the diagonal move)
--   Bool1      1 = the whole tile is blocked (an object stands on it)
--   Unique_Id  the directions the tile may be walked OUT of (cuts already removed)
-- The tile's z is meaningless here: the record is a combination of every blocker on
-- that tile, not a real object, so the grid is keyed by x,y only.
-- Pedestals are blocked tiles that can be mined away, barriers are the tiles that
-- carry the room's separators ('Go-through'). This planner only PLANS: the route
-- is drawn as green dots with the crossings in red, and nothing is clicked.
D.MAZE_PEDESTALS = { [49371] = true, [49372] = true, [49373] = true, [49374] = true }
-- 49353 is NOT here: that id is the room's "Switch" (option Pull) that starts the maze.
-- Once it is pulled its option can go blank, and the `act == ''` half of the barrier test
-- below then read the switch as a Go-through crossing - the route planned over it and sent
-- Go-through to a prop that only ever answers to Pull. Live ids: 49341 and 49344 are the
-- real barriers ("Barrier", option Go-through); pedestals in the same room came as 49360,
-- 49362 and 49363, which is why they are matched by NAME + option and not by id here.
D.MAZE_BARRIERS  = { [49341] = true, [49344] = true }
D.MAZE_CHESTS    = { [49345] = true, [49346] = true, [49347] = true, [54407] = true }
D.MAZE_BARRIER_COST = 10   -- crossing a barrier: one click
D.MAZE_PEDESTAL_COST = 30  -- mining a pedestal out of the way
D.MAZE_MARK_MS = 30000     -- how long the drawn route stays on the floor
D.MAZE_TILE_TTL = 30000    -- collision re-read interval, ms (only on a plan rebuild)
D.MAZE_MINE_TRIES = 3      -- clicks at one crossing before giving up on the room
D.MAZE_MINE_SWINGS = 8     -- mine clicks at one pedestal: one swing is not a hole, and
                           -- the step is only done once the pedestal is really gone
D.MAZE_STALLS = 6          -- re-clicks at a crossing that never started a walk
D.MAZE_CHEST_REACH = 3     -- the locked chest opens from this many tiles away
D.MAZE_CENTRE_R = 2        -- how close to the room's CENTRE the locked chest must stand to
                           -- make this room a toxin maze: the maze is the only room that
                           -- puts a chest in the middle of its floor
D.MAZE_REACH = 20          -- how far from the player a maze prop may be to be a candidate
D.MAZE_LINK = 6            -- how close a prop must be to one already in the maze to join it:
                           -- the group is what defines the room's footprint, so a prop from
                           -- the next room (or a lone chest across the corridor) stays out
D.MAZE_ROOM_MARGIN = 3     -- only props this close to the room box SEED the maze: standing in
                           -- the room next door must not plan (or draw) someone else's maze
D.MAZE_WALK_MS = 1200      -- how long a click may take to get the player MOVING.
                           -- It is only consulted while standing still: once the walk
                           -- starts the wait continues until it ends. This was 6000 and
                           -- every obstacle cost a 6 s stall before the retry that works.

-- Lua 5.1 has no bitwise operators, and `0` is truthy in this runtime, so the wall
-- cut test has to be an arithmetic bit test - `not (cuts & bit)` would be wrong even
-- where `&` parses.
local function mzHas(v, bit)
  return math.floor((v or 0) / bit) % 2 == 1
end

-- union of two cut masks without arithmetic carries (adding 2 and 2 would make 4)
local function mzOr(a, b)
  if a == 0 then return b end
  if b == 0 then return a end
  local out, bit = 0, 1
  while bit <= 255 do
    if mzHas(a, bit) or mzHas(b, bit) then out = out + bit end
    bit = bit * 2
  end
  return out
end

local MZ_N, MZ_E, MZ_S, MZ_W = 1, 2, 4, 8
-- { dx, dy, cut bit of the tile we leave, cut bit of the tile we enter }
local MZ_DIRS = {
  { 0, 1, MZ_N, MZ_S },
  { 1, 0, MZ_E, MZ_W },
  { 0, -1, MZ_S, MZ_N },
  { -1, 0, MZ_W, MZ_E },
}

-- A type 99 record is not an object: it is the combined blocker of one tile,
-- assembled from the wall/decor records on it, so its z means nothing. Everything
-- is merged into one grid by x,y; where two records claim the same tile the
-- stricter reading wins (blocked if either says blocked, cuts OR'd together).
local function mazeTiles()
  local cells = {}
  local n = 0
  for _, o in ipairs(API.ReadAllObjectsArray({ 99 }, {}, {}, D.NO_REACH) or {}) do
    local t = o.Tile_XYZ
    if t then
      local k = pkey(t.x, t.y)
      local cuts = o.Cmb_lv or 0
      local blocked = (o.Bool1 == 1)
      local c = cells[k]
      if c then
        c.blocked = c.blocked or blocked
        c.cuts = mzOr(c.cuts, cuts)
      else
        cells[k] = { cuts = cuts, blocked = blocked }
        n = n + 1
      end
    end
  end
  return cells, n
end

-- One action per pass, driven by the plan's own order. The click walks the player,
-- so there is no tile walking, and the plan is never thrown away for a step: a replan
-- costs a world scan plus a 6k tile read, and that is where the seconds went.
--
-- "Did it work?" is answered by POSITION, not by looking the object up again. The
-- object scan is cached per query, so right after a click it happily reports the
-- barrier still standing - verifying with it made every step look failed and the bot
-- re-click and walk into walls. Where the player is cannot lie: the tile you cannot
-- reach is the tile you are not standing on.
-- Re-stamp the maze route dots. The caller owns the tile lists (they are built with
-- the plan), so this only decides WHEN: at most once per D.MAZE_MARK_REFRESH, so the
-- marks stay on the floor for as long as the plan is being worked and then expire
-- D.MAZE_MARK_MS after the last stamp.
D.MAZE_MARK_REFRESH = 10000
function D.mazeMarkRefresh(marks)
  if not marks then return end
  local now = API.SystemTime()
  if D.mazeMarksAt and (now - D.mazeMarksAt) < D.MAZE_MARK_REFRESH then return end
  D.mazeMarksAt = now
  local function stamp(list, colour, thickness)
    if list and #list > 0 then
      API.MarkTiles(list, D.MAZE_MARK_MS, colour, thickness, true, true,
        FFPOINT.new(0, 0, 0), FFPOINT.new(0, 0, 0))
    end
  end
  stamp(marks.walk, 0x00FF00, 4)
  stamp(marks.cross, 0xFF0000, 4)
  stamp(marks.goal and { marks.goal } or nil, 0xFFFF00, 5)
end

-- Is the pedestal on this tile still standing? Mining is a swing, not an instant hole:
-- live, the Mine click landed, the step was declared done and the tile was marked open,
-- and the plan then tried to walk and click PAST a pedestal that was still loaded (three
-- ground clicks into a blocked tile, then "You can't reach that" twice, then the room was
-- written off). Every step after a mine checks this before it is allowed to move on.
function D.mazePedestalUp(x, y)
  if not x or not y then return false end
  for _, o in ipairs(D.objsFresh()) do
    local ok, t, act = pcall(function()
      return o.Tile_XYZ, tostring(o.Action or '')
    end)
    if ok and t and math.floor(t.x) == x and math.floor(t.y) == y
      and string.find(string.lower(act), 'mine', 1, true) then
      return true
    end
  end
  return false
end

-- Is the maze chest on this tile still there to open? The chest disables itself (Bool1 = 1)
-- once it has been looted, which is also how the room's completion is read. A chest that has
-- left the scan is open too. This is what turns "I clicked it" into "it opened".
function D.mazeChestUp(x, y)
  if not x or not y then return false end
  for _, o in ipairs(D.objsFresh()) do
    local ok, t, oid, b1, act = pcall(function()
      return o.Tile_XYZ, o.Id, o.Bool1, tostring(o.Action or '')
    end)
    if ok and t and math.floor(t.x) == x and math.floor(t.y) == y and D.MAZE_CHESTS[oid] then
      if (tonumber(b1) or 0) == 1 then return false end
      return string.find(string.lower(act), 'open', 1, true) ~= nil
    end
  end
  return false
end

local function mazeExecute(plan, here)
  if not plan or not plan.steps or #plan.steps == 0 then return false end
  D.mazeStepIdx = D.mazeStepIdx or 1
  D.mazeTries = D.mazeTries or {}
  D.mazeClickAt = D.mazeClickAt or {}
  -- Keep the drawn route alive while it is being worked: a mark now lives for
  -- D.MAZE_MARK_MS (30 s), so a maze that takes longer than that would lose its dots
  -- halfway through. Re-stamped at most once every 10 s, and never for a plan that
  -- is finished - the dots then expire on their own 30 s after the last stamp.
  D.mazeMarkRefresh(D.mazeMarks)

  -- The barrier we clicked last. "Moved at all" is NOT enough: a refused click still
  -- walks the player one tile towards the barrier and then stops at the wall, which
  -- looked exactly like success and made the bot skip barriers and wander. The tests
  -- are now: the ROUTE'S next tile reached (or the barrier tile itself) = through,
  -- "You dispel the magical barrier" = through, "unable to move through the barrier" /
  -- "you can't reach that" = refused - all judged only once the walking has stopped.
  local wait = D.mazeWait
  if wait then
    local px, py = ptile()
    local d = math.max(math.abs(px - wait.x), math.abs(py - wait.y))
    -- `isMoving` (ReadPlayerMovin2) is only true inside a movement tick and flaps between
    -- two steps of one walk; D.walkLive reads the tile and does not. Judging a crossing in
    -- that gap is what turns one walk into "the barrier did not start a walk" re-clicks.
    if isMoving() or (D.walkLive and D.walkLive()) then
      return true                            -- still walking, nothing else to do
    end
    local refused = chat.noReach ~= wait.nr or chat.barrierRefused ~= (wait.br or 0)
    local dispelled = chat.barrierDispelled ~= (wait.bd or 0)
    -- THROUGH means the player reached the tile the ROUTE needs after this barrier, or is
    -- standing on the barrier tile itself - not "close enough to it". A refused click walks
    -- the player right up to the barrier and stops, so "beside it" was true either way: the
    -- solver marked barriers it had never dispelled as crossed, skipped them, and then
    -- wandered the maze off-route (live: "at the barrier 8034,1269 ... (now 8033,1269)"
    -- 511 ms after the client answered "You find yourself unable to move through the
    -- barrier"). The chat answers are the authority: dispel = through, "unable to move" =
    -- refused, and only a barrier with no route tile after it (the last one) still uses the
    -- old proximity test.
    local ahead = wait.after
    -- STANDING ON THE BARRIER TILE IS NOT "THROUGH". Live, that clause declared 8033,1271
    -- crossed while the player was still stuck on it ("now 8033,1271"), and every crossing
    -- after it answered "You can't reach that" until the room was written off - the toxin
    -- then killed the character. Reaching the route tile AFTER the barrier, or the client
    -- saying "You dispel the magical barrier", is the proof; nothing else is.
    local through = ahead and (px == ahead.x and py == ahead.y) or false
    if not ahead then
      through = d <= 1                       -- the last crossing has no route tile after it
    end
    through = through or dispelled
    if (px == wait.x and py == wait.y) and not dispelled then
      D.mazeOnBarrier = (D.mazeOnBarrier or 0) + 1
      if D.mazeOnBarrier <= 2 then
        log(string.format('maze: standing on the barrier at %d,%d without dispelling it - clicking it again', wait.x, wait.y))
      end
    else
      D.mazeOnBarrier = 0
    end
    -- the go-through needs a moment to apply before any of that can be judged
    if through and (API.SystemTime() - wait.at) > 300 then
      D.mazeWait = nil                       -- standing past it: it is open
      D.mazeStartTries = 0                   -- a crossing landed: the maze IS running
      log(string.format('maze: through the barrier %d,%d after %dms (now %d,%d%s)',
        wait.x, wait.y, API.SystemTime() - wait.at, px, py, dispelled and ', dispelled' or ''))
      return true
    end
    if refused or (API.SystemTime() - wait.at) > wait.limit then
      D.mazeWait = nil
      D.mazeStepIdx = wait.idx
      D.mazeCleared = D.mazeCleared or {}
      D.mazeCleared[pkey(wait.x, wait.y)] = nil
      local wmk = 'barrier' .. pkey(wait.x, wait.y)
      -- creeping closer is progress, not a failure: a refused object click still walks
      -- the player as far as the walls allow, so retry without burning a try
      if d < wait.d0 then
        log(string.format('maze: barrier at %d,%d refused, but %d tile(s) closer (%d -> %d) - retrying',
          wait.x, wait.y, wait.d0 - d, wait.d0, d))
      elseif not refused then
        -- the click did not even start a walk: either the client is a moment behind the
        -- barrier we just opened, or we are too far from it to be taken at all. Too far
        -- means walk (once) into click range - not "this barrier will not open".
        D.mazeStepUps = D.mazeStepUps or {}
        if d > 2 and (D.mazeStepUps[wmk] or 0) < 3 then
          D.mazeStepUp = pkey(wait.x, wait.y)
          log(string.format('maze: %d,%d is %d tile(s) off and the click was ignored - stepping into range',
            wait.x, wait.y, d))
          return true
        end
        -- the click did not even start a walk: the client is a moment behind the
        -- barrier we just opened. Click again - a stall is not a failure.
        D.mazeStalls = D.mazeStalls or {}
        D.mazeStalls[wmk] = (D.mazeStalls[wmk] or 0) + 1
        log(string.format('maze: barrier at %d,%d did not start a walk - re-clicking (%d)',
          wait.x, wait.y, D.mazeStalls[wmk]))
        if D.mazeStalls[wmk] > D.MAZE_STALLS then
          say('maze: this barrier will not open, leaving the room')
          return false
        end
      else
        -- "You find yourself unable to move through the barrier" is NOT this barrier
        -- refusing - it is the client saying the MAZE IS NOT RUNNING. The switch pull is
        -- fire-and-forget (DoAction always hands the click to the engine), so it can have
        -- been dropped and the once-per-room flag then blocks the one thing that would fix
        -- it. Clear the flag and pull again, without spending this crossing's tries - but
        -- cap it, so a maze that will not start cannot ping-pong switch/barrier forever.
        if chat.barrierRefused ~= (wait.br or 0) then
          D.mazeStartTries = (D.mazeStartTries or 0) + 1
          if D.mazeStartTries <= 6 then
            -- false, not nil: "the maze is off, pull the switch" is a request the switch
            -- block in D.solveMaze acts on (nil or true means "leave it alone")
            D.mazeLeverOn[rkey(here)] = false
            D.dirty = true
            log(string.format('maze: the barrier at %d,%d answered "unable to move" - the maze is not running, pulling the switch again (%d)',
              wait.x, wait.y, D.mazeStartTries))
            say('maze: maze not running - pulling the switch again')
            return true
          end
        end
        -- The client refused the crossing. Not adjacent, or only DIAGONAL to it: that is
        -- not the barrier refusing, it will not take a door from a corner or from across
        -- the room. Step to a tile that shares a side with it (one ground click, at most
        -- three times per crossing) and click again - no try burned.
        local adj = math.max(math.abs(math.floor(px) - wait.x), math.abs(math.floor(py) - wait.y))
        D.mazeStepUps = D.mazeStepUps or {}
        if (adj > 1 or not D.orthoBeside(px, py, wait.x, wait.y))
          and (D.mazeStepUps[wmk] or 0) < 3 then
          D.mazeStepUp = pkey(wait.x, wait.y)
          log(string.format('maze: %d,%d was refused from %d tile(s) off%s - stepping beside it and clicking again',
            wait.x, wait.y, adj, D.orthoBeside(px, py, wait.x, wait.y) and '' or ' on the diagonal'))
          return true
        end
        D.mazeTries[wmk] = (D.mazeTries[wmk] or 1) + 1
        log(string.format('maze: barrier at %d,%d refused by the client - retry %d',
          wait.x, wait.y, D.mazeTries[wmk]))
        if D.mazeTries[wmk] > D.MAZE_MINE_TRIES then
          say('maze: this barrier cannot be reached, leaving the room')
          return false
        end
      end
      return true
    end
    return true                              -- give the walk a moment
  end

  local px2, py2 = ptile()
  local step = plan.steps[D.mazeStepIdx]
  if not step then return false end

  -- The chest is the last step. The client silently drops an 'Open' from too far away
  -- (the chest occupies its own tile, so there is no tile to path onto), which is how
  -- the room was once marked done with the chest still locked. Inside
  -- D.MAZE_CHEST_REACH it is clicked directly; further out the tile before it in the
  -- plan is walked first.
  if step.kind == 'chest' then
    local mk = 'chest' .. pkey(step.x, step.y)
    local d = math.max(math.abs(px2 - step.x), math.abs(py2 - step.y))
    local cw = D.mazeChestWait
    -- THE OPEN IS NOT A GUARANTEE. Live: "maze: opening the locked chest 49347 ... standing 2
    -- tile(s) off" -> DoAction_Object: Locked chest -> no loot, no chat, and the solver had
    -- ALREADY marked the room done and moved on, so the chest was never touched again. The
    -- click is dropped when it comes too soon after the previous action or from further than
    -- a tile, so it is verified now: wait, look at the chest, and click again from beside it.
    if cw and cw.x == step.x and cw.y == step.y then
      local since = API.SystemTime() - cw.at
      local still = D.mazeChestUp(step.x, step.y)
      if not still then
        D.mazeChestWait = nil
        log(string.format('maze: chest %d at %d,%d has opened', step.id, step.x, step.y))
        say('maze: chest opened')
        D.mazeRoomDone = rkey(here)
        D.mazeStepIdx = #plan.steps + 1
        return false
      end
      if since < 1200 then
        say('maze: waiting for the chest to open')
        return true
      end
      if d > 1 then
        local near = plan.path and plan.path[#plan.path - 1]
        if near and (D.tileReachable(near.x, near.y, step.z or 0, 1)
          or D.tileReachable(near.x, near.y, step.z or 0, 2)) then
          say(string.format('maze: the chest did not open from %d tile(s) - going beside it', d))
          log(string.format('maze: chest %d at %d,%d ignored the Open from %d tile(s) - walking to %d,%d first',
            step.id, step.x, step.y, d, near.x, near.y))
          D.mazeChestWait = nil
          D.walkTile(near.x, near.y, step.z or 0)
          D.waitMove(px2, py2, 4000)
          return true
        end
      end
      D.mazeChestWait = nil               -- click again below
    end
    -- the client refuses an 'Open' from further than a couple of tiles; anything
    -- under D.MAZE_CHEST_REACH is fine, so only a longer reach walks up first
    if d >= D.MAZE_CHEST_REACH then
      local tries = (D.mazeTries[mk] or 0) + 1
      D.mazeTries[mk] = tries
      if tries > D.MAZE_MINE_TRIES then
        log(string.format('maze: could not get beside the chest %d at %d,%d - leaving the room',
          step.id, step.x, step.y))
        return false
      end
      local near = plan.path and plan.path[#plan.path - 1]
      if not near then return false end
      say(string.format('maze: stepping up to the chest (%d tile(s) off)', d))
      log(string.format('maze: chest %d at %d,%d is %d tile(s) off - walking to %d,%d first',
        step.id, step.x, step.y, d, near.x, near.y))
      D.walkTile(near.x, near.y, step.z or 0)
      D.waitMove(px2, py2, 8000)
      return true
    end
    D.mazeTries[mk] = (D.mazeTries[mk] or 0) + 1
    if D.mazeTries[mk] > 6 then
      log(string.format('maze: chest %d at %d,%d did not open after %d clicks - NOT marking the room done',
        step.id, step.x, step.y, D.mazeTries[mk] - 1))
      say('maze: the chest will not open - leaving it for later')
      D.mazeChestWait = nil
      return false
    end
    say(string.format('maze: opening the chest at %d,%d', step.x, step.y))
    log(string.format('maze: opening the locked chest %d at %d,%d, standing %d tile(s) off (click %d)',
      step.id, step.x, step.y, d, D.mazeTries[mk]))
    D.clickObject('Open', D.objAt(step.id, step.x, step.y))
    D.mazeChestWait = { at = API.SystemTime(), x = step.x, y = step.y }
    -- Completion is read back from the chest itself (Bool1, and the chest disappearing from
    -- the scan): the room is NOT declared done on the strength of the click any more.
    log(string.format('maze: clicked chest id %d name "%s" at %d,%d - checking it really opened',
      step.id, chest and chest.name or '?', step.x, step.y))
    say('maze: chest clicked, checking it opened')
    return true
  end

  -- Standing two tiles off a crossing is not a refusal, it is "You can't reach that": the
  -- client cannot path to a tile that is itself blocked, so it drops the Go-through and
  -- the solver counted that as the barrier refusing us (live: 3 tries on 8034,1269 while
  -- the player stood at 8033,1271 - one route tile short - and then "giving up on the
  -- room"). Walk the route tile just before the crossing first, exactly like the chest.
  -- MOVEMENT IS THE OBJECT CLICK. The crossing is clicked from wherever the player stands
  -- and the client walks the character into range itself - no ground clicks to line up. Only
  -- when the client has actually REFUSED the click ("You can't reach that") because we are
  -- diagonal to it does the solver step round to a tile that shares a side with it, which is
  -- what D.orthoBeside / D.mazeStepUp are for. The old pre-emptive walk ran a
  -- DoAction_Tile:Ground before every single crossing, which is the "why are you walking"
  -- the maze kept showing.
  local tk = pkey(step.x, step.y)
  if D.mazeStepUp == tk then
    D.mazeStepUp = nil
    D.mazeStepUps = D.mazeStepUps or {}
    D.mazeStepUps['barrier' .. tk] = (D.mazeStepUps['barrier' .. tk] or 0) + 1
    local target, bestD = nil, nil
    local cands = {}
    if plan.path then
      for i = 2, #plan.path do
        if plan.path[i].x == step.x and plan.path[i].y == step.y then
          local p = plan.path[i - 1]
          if D.orthoBeside(p.x, p.y, step.x, step.y) then cands[#cands + 1] = p end
          break
        end
      end
    end
    for _, n in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      cands[#cands + 1] = { x = step.x + n[1], y = step.y + n[2] }
    end
    for _, c in ipairs(cands) do
      if not (c.x == math.floor(px2) and c.y == math.floor(py2))
        and (D.tileReachable(c.x, c.y, step.z or 0, 1)
          or D.tileReachable(c.x, c.y, step.z or 0, 2)) then
        local dd = (c.x - px2) ^ 2 + (c.y - py2) ^ 2
        if not bestD or dd < bestD then target, bestD = c, dd end
      end
    end
    if target then
      say(string.format('maze: stepping beside the %s at %d,%d', step.kind, step.x, step.y))
      log(string.format('maze: the client will not take %d,%d from a diagonal tile - stepping to %d,%d',
        step.x, step.y, target.x, target.y))
      D.walkTile(target.x, target.y, step.z or 0)
      D.waitMove(px2, py2, 4000)
      return true
    end
    local back = D.mazeStepIdx - 1
    local bstep = back >= 1 and plan.steps[back] or nil
    if bstep and bstep.kind == 'mine' then
      say(string.format('maze: no open tile beside %d,%d - mining the pedestal again', step.x, step.y))
      log(string.format('maze: no reachable tile shares a side with %d,%d - going back to %s %d at %d,%d',
        step.x, step.y, bstep.kind, bstep.id, bstep.x, bstep.y))
      D.mazeTries['mine' .. pkey(bstep.x, bstep.y)] = nil
      D.mazeStepIdx = back
      return true
    end
    log(string.format('maze: no reachable tile shares a side with %d,%d - clicking it from here anyway',
      step.x, step.y))
  end

  local mk = tostring(step.kind) .. tk
  local tries = (D.mazeTries[mk] or 0) + 1
  D.mazeTries[mk] = tries
  -- mining gets its own budget: a pedestal can legitimately take several swings, and one
  -- swing that lands is not the same as a barrier that refuses the click
  local cap = (step.kind == 'mine') and (D.MAZE_MINE_SWINGS or 8) or D.MAZE_MINE_TRIES
  if tries > cap then
    say('maze: this crossing will not open, leaving the room')
    log(string.format('maze: %s %d at %d,%d refused %d times - giving up on the room',
      step.kind, step.id, step.x, step.y, cap))
    return false
  end
  local action = (step.kind == 'barrier') and 'Go-through' or 'Mine'
  say(string.format('maze: %s %d at %d,%d (step %d/%d)', action, step.id, step.x, step.y,
    D.mazeStepIdx, #plan.steps))
  log(string.format('maze %s %d/%d: %s %d at %d,%d', action, tries, cap,
    step.kind, step.id, step.x, step.y))
  D.mazeClickAt[tk] = API.SystemTime()
  D.clickObject(action, D.objAt(step.id, step.x, step.y))
  D.mazeCleared = D.mazeCleared or {}
  if step.kind == 'mine' then
    -- the only place the animation matters: the swing has to land or the ore is never
    -- dug and the tile stays a wall. Mining is done from beside the pedestal, so there
    -- is no walk to follow - the swing finishing IS the step finishing.
    D.waitAnimStart(2000)
    D.waitAnim(6000)
    if D.mazePedestalUp(step.x, step.y) then
      -- still loaded: that was a swing, not a hole. The tile stays SHUT in the plan and
      -- the step is not advanced, so the next pass mines it again from beside it.
      D.mazeCleared[tk] = nil
      say(string.format('maze: pedestal at %d,%d is still up - mining it again', step.x, step.y))
      log(string.format('maze: pedestal %d at %d,%d still standing after the swing (%d/%d) - not moving on yet',
        step.id, step.x, step.y, tries, cap))
      return true
    end
    D.mazeCleared[tk] = true
    D.mazeStepIdx = D.mazeStepIdx + 1
    log(string.format('maze: pedestal %d at %d,%d is mined away - the tile is open now',
      step.id, step.x, step.y))
    return true
  end
  D.mazeCleared[tk] = true
  D.mazeStepIdx = D.mazeStepIdx + 1
  -- a barrier: wait for the walk it started, then judge it by where we ended up
  -- `after` is the tile the ROUTE needs once this barrier is behind us: reaching it is
  -- what "through" means, and reaching it is also what makes the rest of the plan valid.
  -- It must be a PLAIN route tile: back-to-back crossings are normal in a dense maze (a
  -- pedestal standing right behind a barrier, two pedestals side by side - both live in
  -- the 8791,1054 room), and a tile that is itself still a crossing cannot be stood on
  -- until it is cleared, so it could never become "through" and the barrier was re-clicked
  -- until D.MAZE_STALLS wrote the room off.
  local after = nil
  for i = 1, #(plan.path or {}) do
    local t = plan.path[i]
    if t.x == step.x and t.y == step.y then
      for j = i + 1, #plan.path do
        if not plan.path[j].kind then after = plan.path[j] break end
      end
      break
    end
  end
  D.mazeWait = { idx = D.mazeStepIdx - 1, x = step.x, y = step.y, after = after,
    d0 = math.max(math.abs(px2 - step.x), math.abs(py2 - step.y)),
    nr = chat.noReach, br = chat.barrierRefused, bd = chat.barrierDispelled,
    limit = D.MAZE_WALK_MS, at = API.SystemTime() }
  return true
end

-- Cached: the scan walks the whole map data plus every entity, and this runs from
-- the main loop. The grid only changes when the room does.
local function mazeRoom(here)
  local ck = rkey(here)
  local now = API.SystemTime()
  if not (D.mazeScan and D.mazeScan.key == ck and (now - D.mazeScan.at) < D.MAZE_TILE_TTL) then
    local cells, n = mazeTiles()
    D.mazeScan = { key = ck, at = now, cells = cells, n = n }
  end
  return D.mazeScan
end

-- Standing beside a door/barrier means sharing a SIDE with it, not a corner. Live, the
-- barrier at 8034,1269 clicked from the diagonal tile answered "You can't reach that"
-- twice; the same barrier clicked from the tile below it went straight through.
function D.orthoBeside(px, py, x, y)
  return (math.abs(math.floor(px) - x) + math.abs(math.floor(py) - y)) == 1
end

-- A FINISHED TOXIN ROOM IS JUST A ROOM. There is deliberately NO teleport here any more:
-- pulling the gatestone out of a room that was solved (sometimes many floors ago) is what
-- made "the router walked into the maze room" look like the script panicking, and it also
-- teleported the player out of the dungeon mid-run. The way out of a maze is the door the
-- switch unlocked, which the ordinary door task already uses like any other.
function D.mazeRoomFinished(rk, why)
  if D.mazeRoomDone ~= rk then
    log(string.format('maze: room %s is finished (%s) - nothing to do here', tostring(rk), tostring(why)))
    say('maze: this room is already done')
  end
  D.mazeChestWait = nil
  D.mazeRoomDone = rk
  return false
end

-- THE TOXIN MAZE'S OWN IDENTITY: a locked chest on the CENTRE of the room. Nothing else
-- on a Daemonheim floor puts a chest in the middle of its floor, and the maze's chest
-- stands there exactly until the puzzle is beaten - so one prop answers both "is this a
-- maze" and "is it done", from any corner of the room and however badly the room blob was
-- cut (the maze's one-tile corridors are choke points, so the blob is a stub).
-- The centre is the LATTICE centre (D.roomCellAt: half a cell from the room's wall), not
-- the blob's box centre.
-- Returns { id, name, x, y, z, d, disabled } or nil; `disabled` is Bool1 = 1, the client's
-- own "this chest has already been looted".
function D.mazeCentreChest(world, here)
  local cx, cy = here and here.cx, here and here.cy
  if not (cx and cy) then return nil end
  local best = nil
  for _, o in ipairs((world and world.objs) or {}) do
    local oid = D.objGet(o, 'Id')
    if D.MAZE_CHESTS[oid] then
      local tx, ty = D.objTile(o)
      if tx then
        local x, y = math.floor(tx), math.floor(ty)
        local d = math.max(math.abs(x - cx), math.abs(y - cy))
        if d <= (D.MAZE_CENTRE_R or 2) and (not best or d < best.d) then
          local okZ, tz = pcall(function() return o.Tile_XYZ.z end)
          best = { id = oid, name = D.objName(o), x = x, y = y, d = d,
            z = okZ and math.floor(tonumber(tz) or 0) or 0,
            disabled = (tonumber(D.objGet(o, 'Bool1')) or 0) == 1 }
        end
      end
    end
  end
  return best
end

--------------------------------------------------------------------
-- FREMENNIK CAMP - three crates, one skill action each
--------------------------------------------------------------------
--   "Crate of bars"      Smith-battleaxes   49529 / 49530
--   "Crate of raw fish"  Cook-fish          49523 / 49524
--   "Crate of logs"      Fletch-bows        49535 / 49536
-- The ids are MegaDungeon's (Fremennikcamp.java); the LIVE world uses the higher member of
-- each pair - seen in the client at 49530 / 49536 / 49524 - so both are matched.
--
-- The room is done when no crate still offers its action. Confirmed live: after the
-- action lands ALL THREE KEEP THEIR IDS (49530 / 49536 / 49524) and get Bool1 = 1 - the
-- crate stays as scenery, the client just stops offering the option. So the test is
-- "Bool1 == 0 AND the crate's own action is on it", which is true only while the crate is
-- still usable and false for every other state the game might put it in.
D.CAMP_CRATES = {
	[49529] = 'Smith-battleaxes', [49530] = 'Smith-battleaxes',
	[49523] = 'Cook-fish',        [49524] = 'Cook-fish',
	[49535] = 'Fletch-bows',      [49536] = 'Fletch-bows',
}
-- THE ROOM'S OWN MARKER: a Fremennik scout stands in the camp (live npc 11001, "Talk to",
-- next to the crates). It is what says "this is the camp room" when the crates are spent
-- or not streamed - it is NOT used for routing: the scout never goes away, so a camp room
-- would stay a "live puzzle" for ever and the router would keep walking back to it.
D.CAMP_SCOUT = 'fremennik scout'
-- The action is a skill animation: a click sent while one is running is dropped.
D.CAMP_ANIM_MS = 2600
-- Clicks per crate tile before it is written off. The puzzle is one click per crate, so a
-- crate that survives three is scenery that happens to carry the option.
D.CAMP_TRIES = 3
D.CAMP_RECLICK_MS = 1200

-- Is a Fremennik scout standing in this room? Used for the log line only (see above).
function D.campScoutNear(here)
	for _, n in ipairs(D.npcScan() or {}) do
		local nm = string.lower(tostring(D.objGet(n, 'Name') or ''))
		if string.find(nm, D.CAMP_SCOUT, 1, true) then
			local x, y = D.objTile(n)
			if x and D.tileInHere(here, x, y, 1) then
				return { x = math.floor(x), y = math.floor(y) }
			end
		end
	end
	return nil
end

function D.solveCamp(world, here, px, py)
	if not here or not world then return false end
	local key = rkey(here)
	-- ITS OWN STATE, NOT S.pondState. puzzleClaim() refuses a room another kind already
	-- owns, and D.solveCollapse claims every room it is called in before it decides whether
	-- it has anything to do - collapse runs earlier in the chain, so the camp solver could
	-- never claim a room and returned false on every pass ("it does not detect the room").
	-- The camp is keyed on three ids nothing else uses, so it needs no arbitration at all.
	D.campState = D.campState or {}
	local st = D.campState[key]
	if not st then
		st = { tries = {}, clickedAt = {}, skip = {} }
		D.campState[key] = st
	end
	if st.solved then return false end
	-- the swing the last click started is still running: yield, do not click again
	if st.clickAt and (API.SystemTime() - st.clickAt) < D.CAMP_ANIM_MS and D.playerBusy() then
		API.RandomSleep2(300, 100, 150)
		return true
	end
	local scout = D.campScoutNear(here)
	if scout and not st.said then
		st.said = true
		log(string.format('camp %s: Fremennik scout at %d,%d - this is the camp room',
			tostring(key), scout.x, scout.y))
	end
	-- ONE SWEEP of this pass's props: every crate in THIS room that still offers its own
	-- action. Judged on the room box with a tile of slack, because a crate stands on the
	-- room's edge rather than on its floor.
	local list = {}
	for _, o in ipairs(world.objs or {}) do
		local id = tonumber(D.objGet(o, 'Id'))
		local want = id and D.CAMP_CRATES[id] or nil
		-- a used crate keeps its id and turns Bool1 to 1, so both halves are required
		if want and (tonumber(D.objGet(o, 'Bool1')) or 0) == 0
			and D.objGet(o, 'Action') == want then
			local x, y = D.objTile(o)
			if x and D.tileInHere(here, x, y, 1) then
				local fx, fy = math.floor(x), math.floor(y)
				if not st.skip[pkey(fx, fy)] then
					list[#list + 1] = { obj = o, x = fx, y = fy, id = id, action = want,
						d = math.max(math.abs(fx - px), math.abs(fy - py)) }
				end
			end
		end
	end
	if #list == 0 then
		-- say WHAT is left, because "nothing to click" and "the crates are all spent" are
		-- different facts and this is the line that proves which one it was
		local used = 0
		for _, o in ipairs(world.objs or {}) do
			local id = tonumber(D.objGet(o, 'Id'))
			if id and D.CAMP_CRATES[id] and (tonumber(D.objGet(o, 'Bool1')) or 0) == 1 then
				used = used + 1
			end
		end
		st.solved = true
		D.dirty = true
		log(string.format('camp %s: every crate is used (%d crate(s) left with Bool1 = 1) - room done',
			tostring(key), used))
		return false
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	local c = list[1]
	local kk = pkey(c.x, c.y)
	-- do not hammer a crate inside the click window; the wait is the animation, not a guess
	local last = st.clickedAt[kk]
	if last and (API.SystemTime() - last) < D.CAMP_RECLICK_MS then
		API.RandomSleep2(200, 80, 120)
		return true
	end
	st.tries[kk] = (st.tries[kk] or 0) + 1
	if st.tries[kk] > D.CAMP_TRIES then
		st.skip[kk] = true
		log(string.format('camp %s: crate %d at %d,%d still offers "%s" after %d clicks - writing it off',
			tostring(key), c.id, c.x, c.y, c.action, D.CAMP_TRIES))
		return true
	end
	-- do not use a crate mid-walk (isMoving flaps between steps, D.walkLive does not)
	-- and not over a running skill animation: either click is dropped
	if isMoving() or (D.walkLive and D.walkLive()) or D.playerBusy() then
		API.RandomSleep2(200, 80, 120)
		return true
	end
	if not D.clickObject(c.action, c.obj) then return false end
	st.clickAt = API.SystemTime()
	st.clickedAt[kk] = st.clickAt
	log(string.format('camp %s: "%s" on %s (id %d) at %d,%d',
		tostring(key), c.action, tostring(D.objName(c.obj)), c.id, c.x, c.y))
	API.RandomSleep2(D.CAMP_ANIM_MS, 300, 500)
	return true
end

--------------------------------------------------------------------
-- COLOURED RECESS - push each Block onto its recess
--------------------------------------------------------------------
-- Four "Block" npcs and four coloured recesses. The blocks are pushed one tile at a
-- time (the live option is "Push"; MegaDungeon's ColouredRecess.java still says "Pull"
-- from 2011 - the geometry is the same either way: a pull moves the block toward the
-- player, a push moves it away, so the pushing side is the tile OPPOSITE the recess).
--
-- Recess ids, four models per colour (MegaDungeon's BLUE/GREEN/YELLOW/VIOLET_TILES):
--   54504 54546 54623 56060  blue     (live: 54623 "Blue recess")
--   54506 54548 54625 56062  green    (live: 54625 "Green recess")
--   54508 54550 54627 56064  yellow   (live: 54627 "Yellow recess")
--   54510 54552 54629 56066  violet   (live: 54629 "Violet recess")
-- The block npc is 13034 "Block" and every one of the four shares that id, so the record
-- itself (not the id) is what gets clicked - the same rule the barrel pushes already
-- learned.
--
-- The pushing itself is D.barrelPush with a barrel goal: "the BLOCK has to reach that
-- tile", which is exactly the mode built for the barrels' pipe stage. Nothing here walks
-- tiles or guesses geometry - one push per pass, then wait for the scan to report it.
D.RECESS_IDS = {
	[54504] = 'blue',  [54546] = 'blue',  [54623] = 'blue',  [56060] = 'blue',
	[54506] = 'green', [54548] = 'green', [54625] = 'green', [56062] = 'green',
	[54508] = 'yellow',[54550] = 'yellow',[54627] = 'yellow',[56064] = 'yellow',
	[54510] = 'violet',[54552] = 'violet',[54629] = 'violet',[56066] = 'violet',
}
D.RECESS_BLOCK = 13034          -- the plain "Block" npc (action "Push")
-- A BLOCK THAT HAS TAKEN ITS LIQUID IS RENAMED AND RE-IDed - live: 13034 "Block" became
-- 13035 "Blue block" when the blue vial went on it. The NAME carries the colour, so that is
-- what is read: the coloured block on a recess IS the room's state, no bookkeeping needed.
D.RECESS_PUSH_MAX = 160         -- pushes in one room before the door sweep gets it back
D.RECESS_SETTLE_MS = 3000       -- how long a push is given to show up in the scan
D.RECESS_SAID = 20              -- seconds between two "nothing to push" lines
D.recessState = {}

-- THE COLOURED LIQUID (phase 2), as reported live: "Mix liquid" on the shelves opens the
-- make-X chatbox a few seconds later, and taking "All" from it puts all four coloured
-- bottles in the pack. Bottle ids are the old script's (BLUE_COLOR .. VIOLET_COLOR).
D.RECESS_BOTTLES = { [19869] = 'blue', [19871] = 'green', [19873] = 'yellow', [19875] = 'violet' }
D.RECESS_MIX_WAIT = 3200        -- click -> menu is up
D.RECESS_MIX_TRIES = 3
D.RECESS_MIX_OPTION = 'All.'    -- the make-X chatbox option, full stop included
D.RECESS_ANIM_START_MS = 2500   -- click -> the mix animation has to show up inside this
D.RECESS_MIX_ANIM_MS = 8000     -- the mix animation itself, waited out before the menu

-- USING A BOTTLE ON A BLOCK (phase 2b). Taken from the client's own doaction log during a
-- manual use of the blue bottle (19869), not from guesswork:
--   DoAction_Interface(0x24,0x4d9d,0,1473,5,9,API.OFF_ACT_Bladed_interface_route)  -- item Use
--   Matching action: API.OFF_ACT_InteractNPC_useitem
--   API.DoAction_NPC(0x24,API.OFF_ACT_InteractNPC_useitem,{ ids },50)              -- the target
-- The item half is Inventory:Use(id); the target half is the BLOCK npc standing on the
-- coloured recess, clicked by RECORD because all four blocks share id 13034.
D.RECESS_USE_ACT = 0x24
D.RECESS_USE_ROUTE = API.OFF_ACT_InteractNPC_useitem
D.RECESS_USE_TRIES = 3          -- uses per colour before the colour is written off
-- blue -> green -> yellow -> violet: the reference treats violet as the finishing one
D.RECESS_USE_ORDER = { 'blue', 'green', 'yellow', 'violet' }

-- TAKE "ALL" FROM THE MIX MENU. The make-X chatbox offers it as the literal option
-- "All."; API.Dialog_Option answers with its char, which KeyboardPress takes as-is.
function D.recessPickAll(st)
	local okD, key = pcall(API.Dialog_Option, D.RECESS_MIX_OPTION)
	if not (okD and key and key ~= 0) then return false end
	API.KeyboardPress(key, 60, 200)
	if not st.allSaid then
		st.allSaid = true
		log(string.format('recess: mix menu - "%s" pressed 0x%02X', D.RECESS_MIX_OPTION, key))
	end
	return true
end

-- MIX THE LIQUID: click the shelves' own option, then take "All" from the menu that comes
-- up a few seconds later. One click per pass, and the wait is spent trying the menu
-- instead of sleeping through it.
function D.recessMix(world, here, key, st)
	local shelf = nil
	for _, o in ipairs(world.objs or {}) do
		local act = D.objGet(o, 'Action')
		if type(act) == 'string' and string.find(string.lower(act), 'mix', 1, true) then
			local x, y = D.objTile(o)
			if x and D.tileInHere(here, x, y, 1) then shelf = o break end
		end
	end
	if not shelf then return false end
	local act = D.objGet(shelf, 'Action')
	local now = API.SystemTime()
	if st.mixAt then
		if D.recessPickAll(st) then return true end
		if (now - st.mixAt) < D.RECESS_MIX_WAIT then
			API.RandomSleep2(300, 100, 150)
			return true
		end
		-- the menu never answered this try
		st.mixAt = nil
		st.mixTries = (st.mixTries or 0) + 1
		if st.mixTries > D.RECESS_MIX_TRIES then
			if not st.mixSaid then
				st.mixSaid = true
				log(string.format('recess %s: "Mix liquid" opened no menu I could take after %d tries - not clicking it again',
					tostring(key), st.mixTries - 1))
			end
			return false
		end
	end
	-- do not use the shelves mid-walk (isMoving flaps between steps, D.walkLive does not)
	-- and not over a running animation: either click is lost
	if isMoving() or (D.walkLive and D.walkLive()) or D.playerBusy() then
		API.RandomSleep2(200, 80, 120)
		return true
	end
	if not D.clickObject(act, shelf) then return false end
	log(string.format('recess %s: "%s" on the shelves (try %d)',
		tostring(key), tostring(act), (st.mixTries or 0) + 1))
	-- ANIMATION CHECK: the click only did something if the mix animation starts. Wait for
	-- it instead of sleeping blind, let it finish, then start the menu window from a free
	-- player - the menu is up a few seconds after the mixing, not after the click.
	if not D.waitAnimStart(D.RECESS_ANIM_START_MS) and not st.animSaid then
		st.animSaid = true
		log(string.format('recess %s: no animation after clicking the shelves - the click may not have landed',
			tostring(key)))
	end
	D.waitAnim(D.RECESS_MIX_ANIM_MS)
	st.mixAt = API.SystemTime()
	return true
end

-- WHAT BOTTLES THIS PACK HOLDS, by colour. One GetItems sweep: the four bottle ids are
-- unique, so the colour is just the id's name and nothing else has to be read.
function D.recessHeld()
	local held, n = {}, 0
	local okI, items = pcall(function() return Inventory:GetItems() end)
	if okI and items then
		for _, it in ipairs(items) do
			local ok2, id2 = pcall(function() return it.id end)
			id2 = ok2 and tonumber(id2) or nil
			local colour = id2 and D.RECESS_BOTTLES[id2] or nil
			if colour then
				held[colour] = id2
				n = n + 1
			end
		end
	end
	return held, n
end

-- WHICH COLOUR HAS THIS BLOCK TAKEN? The name says it - a plain block is "Block", a charged
-- one is "Blue block" / "Green block" / … (live). nil means it is still plain.
function D.recessBlockColour(npc)
	local nm = string.lower(tostring(D.objGet(npc, 'Name') or ''))
	if nm == '' or nm == 'block' then return nil end
	for _, c in ipairs(D.RECESS_USE_ORDER) do
		if string.find(nm, c, 1, true) then return c end
	end
	return nil
end

-- HOW MANY RECESSES ARE DONE: a recess is finished when the block standing on it carries
-- that recess's colour. Returns done, total.
function D.recessColoured(recesses, blocks)
	local done = 0
	for _, r in ipairs(recesses) do
		for _, b in ipairs(blocks) do
			if b.x == r.x and b.y == r.y then
				if b.colour == r.colour then done = done + 1 end
				break
			end
		end
	end
	return done, #recesses
end

-- SELECT THE ITEM, THEN USE IT ON THE NPC. Both halves are the captured ones (see the
-- constants above): Inventory:Use(id) puts the item on the cursor exactly the way a manual
-- "Use" click does, and the target is clicked by record with the useitem route.
function D.useItemOn(itemId, npc)
	if not itemId or not npc then return false end
	if not pcall(function() return Inventory:Use(itemId) end) then return false end
	API.RandomSleep2(250, 100, 150)
	local okC, sent = pcall(API.DoAction_NPC__Direct, D.RECESS_USE_ACT, D.RECESS_USE_ROUTE, npc)
	return (okC and sent) and true or false
end

-- ONE BOTTLE ON ITS RECESS, one per pass. Order blue -> green -> yellow -> violet. The
-- target is the Block npc standing on that colour's recess tile - the pairing the push phase
-- already made - and the colour is finished the moment that block is renamed to it.
function D.recessUseBottle(world, here, key, st, recesses, blocks)
	st.served = st.served or {}
	st.skip = st.skip or {}
	st.tries = st.tries or {}

	-- READ THE ROOM FIRST: a recess whose block already carries its colour is done, whether
	-- this script charged it or the room arrived half-solved (live: blue was already on).
	for _, r in ipairs(recesses) do
		if not st.served[r.colour] then
			for _, b in ipairs(blocks) do
				if b.x == r.x and b.y == r.y and b.colour == r.colour then
					st.served[r.colour] = true
					st.servedSaid = st.servedSaid or {}
					if not st.servedSaid[r.colour] then
						st.servedSaid[r.colour] = true
						log(string.format('recess %s: the %s recess is coloured', tostring(key), r.colour))
					end
					break
				end
			end
		end
	end

	-- PICK THE NEXT COLOUR: a bottle we hold, a recess of that colour in this room, and a
	-- colour that has not been written off
	local held = D.recessHeld()
	local colour, recess = nil, nil
	for _, c in ipairs(D.RECESS_USE_ORDER) do
		if held[c] and not st.served[c] and not st.skip[c] then
			if (st.tries[c] or 0) >= D.RECESS_USE_TRIES then
				st.skip[c] = true
				log(string.format('recess %s: %s still not coloured after %d bottle(s) - writing the colour off',
					tostring(key), c, st.tries[c]))
			else
				for _, r in ipairs(recesses) do
					if r.colour == c then colour, recess = c, r break end
				end
			end
			if colour then break end
		end
	end
	if not colour then return false end

	-- THE BLOCK ON THAT RECESS is what takes the bottle
	local blk = nil
	for _, b in ipairs(blocks) do
		if b.x == recess.x and b.y == recess.y then blk = b break end
	end
	if not blk then
		if not st.blockSaid then
			st.blockSaid = true
			log(string.format('recess %s: no block on the %s recess at %d,%d yet - nothing to use the bottle on',
				tostring(key), colour, recess.x, recess.y))
		end
		return false
	end
	if blk.colour then return false end    -- charged already; the scan is a pass behind

	if isMoving() or (D.walkLive and D.walkLive()) or D.playerBusy() then
		API.RandomSleep2(200, 80, 120)
		return true
	end
	local bottleId = held[colour]
	if not D.useItemOn(bottleId, blk.npc) then return false end
	st.tries[colour] = (st.tries[colour] or 0) + 1
	log(string.format('recess %s: %s bottle %d on the block at %d,%d (over the %s recess, try %d)',
		tostring(key), colour, bottleId, blk.x, blk.y, colour, st.tries[colour]))
	API.RandomSleep2(1500, 300, 500)
	return true
end

function D.solveRecess(world, here, px, py)
	if not here or not world then return false end
	local key = rkey(here)
	-- the recesses of THIS room
	local recesses = {}
	for _, o in ipairs(world.objs or {}) do
		local id = tonumber(D.objGet(o, 'Id'))
		local colour = id and D.RECESS_IDS[id] or nil
		if colour then
			local x, y = D.objTile(o)
			if x and D.tileInHere(here, x, y, 1) then
				recesses[#recesses + 1] = { id = id, colour = colour,
					x = math.floor(x), y = math.floor(y) }
			end
		end
	end
	if #recesses == 0 then return false end     -- not a coloured-recess room
	-- the blocks of THIS room, and which tiles they occupy. A charged block is still a block
	-- (its name just carries the colour now), so it has to be scanned too - otherwise a
	-- coloured block vanishes from the room and its recess looks empty again.
	local blocks, occupied = {}, {}
	for _, n in ipairs(D.npcScan() or {}) do
		local nm = string.lower(tostring(D.objGet(n, 'Name') or ''))
		if string.find(nm, 'block', 1, true)
			or tonumber(D.objGet(n, 'Id')) == D.RECESS_BLOCK then
			local x, y = D.objTile(n)
			if x and D.tileInHere(here, x, y, 1) then
				local fx, fy = math.floor(x), math.floor(y)
				blocks[#blocks + 1] = { npc = n, id = tonumber(D.objGet(n, 'Id')) or D.RECESS_BLOCK,
					colour = D.recessBlockColour(n), x = fx, y = fy }
				occupied[pkey(fx, fy)] = true
			end
		end
	end
	local st = D.recessState[key]
	if not st then st = { pushes = 0 } D.recessState[key] = st end

	-- A PUSH IS MADE ONE PASS AND JUDGED THE NEXT. Planning again while the client still
	-- reports the block on its old tile is what makes a solver push the same block back
	-- and forth, so the settle wait comes first (same shape as the barrel solver's).
	if st.expect and st.expect.from then
		local still = false
		for _, b in ipairs(blocks) do
			if pkey(b.x, b.y) == st.expect.from then still = true break end
		end
		if still and (API.SystemTime() - (st.pushAt or 0)) < D.RECESS_SETTLE_MS then
			API.RandomSleep2(300, 100, 150)
			return true
		end
		st.expect = nil
	end

	local empty = {}
	for _, r in ipairs(recesses) do
		if not occupied[pkey(r.x, r.y)] then empty[#empty + 1] = r end
	end
	if #blocks == 0 or #empty == 0 then
		-- PHASE 2. A RECESS IS FINISHED WHEN ITS BLOCK IS COLOURED - the block takes the
		-- colour's name, so the room reports its own progress. Every recess coloured is the
		-- whole puzzle done.
		local doneN, totalN = D.recessColoured(recesses, blocks)
		if totalN > 0 and doneN >= totalN then
			if not st.done then
				st.done = true
				st.solved = true
				D.dirty = true
				log(string.format('recess %s: all %d recesses coloured - room done',
					tostring(key), totalN))
			end
			return false
		end
		if doneN > 0 and not st.doneSaid then
			st.doneSaid = true
			log(string.format('recess %s: %d/%d recesses coloured', tostring(key), doneN, totalN))
		end
		local held, n = D.recessHeld()
		if n > 0 then
			if not st.heldSaid then
				st.heldSaid = true
				local names = {}
				for _, c in ipairs(D.RECESS_USE_ORDER) do
					if held[c] then names[#names + 1] = c end
				end
				log(string.format('recess %s: holding %d bottle(s): %s',
					tostring(key), n, table.concat(names, ', ')))
			end
			return D.recessUseBottle(world, here, key, st, recesses, blocks)
		end
		return D.recessMix(world, here, key, st)
	end

	-- the block that belongs to a recess is the nearest one to it (MegaDungeon pairs them
	-- the same way: the block nearest the colour tile). A COLOURED block is never pushed -
	-- it is already where it belongs, and shoving it would undo a finished colour.
	local plain = {}
	for _, b in ipairs(blocks) do
		if not b.colour then plain[#plain + 1] = b end
	end
	if #plain == 0 then
		if not st.plainSaid then
			st.plainSaid = true
			log(string.format('recess %s: no plain block left to push - leaving the room', tostring(key)))
		end
		return false
	end
	local pick, pickD = nil, nil
	for _, r in ipairs(empty) do
		for _, b in ipairs(plain) do
			local d = math.abs(b.x - r.x) + math.abs(b.y - r.y)
			if not pickD or d < pickD then pick, pickD = { b = b, r = r }, d end
		end
	end
	if not pick then return false end
	if (st.pushes or 0) >= D.RECESS_PUSH_MAX then
		if not st.gaveUp then
			st.gaveUp = true
			log(string.format('recess %s: %d pushes and the room is still not done - leaving it to the door sweep',
				tostring(key), st.pushes))
		end
		return false
	end
	-- one push toward the recess; barrelPush walks to the pushing side itself and logs
	if D.barrelPush(world, blocks, { pick.b }, px, py,
		{ x = pick.r.x, y = pick.r.y, barrel = true }, st) then
		st.pushAt = API.SystemTime()
		return true
	end
	return false
end

function D.solveMaze(world, here, px, py)
  if not here or not world then return false end  -- The home teleport is only the quick way OUT of the toxin room once the chest is open -
  -- it is NOT the end of the run. It used to Write_LoopyLoop(false) here, which stopped the
  -- script on a completed puzzle room while the floor still had rooms (and the boss) to do.
  if D.mazeTeleportAt then
    if (API.SystemTime() - D.mazeTeleportAt) < D.PF_TELEPORT_MS then
      say('maze: puzzle complete - waiting for the teleport out')
      return true
    end
    log('maze: teleport out of the maze landed - carrying on with the floor')
    say('maze: out of the maze - carrying on')
    D.mazeTeleportAt = nil
    D.mazePlan, D.mazeWait, D.mazeChestWait = nil, nil, nil
    D.mazeCleared, D.mazeTries, D.mazeClickAt = {}, {}, {}
    D.mazeStalls, D.mazeStepUp, D.mazeStepUps = {}, nil, {}
    D.mazeStepIdx = 1
    D.dirty = true
    return true                 -- one pass held while the new room loads
  end
  local bx0, bx1 = here.minx, here.maxx
  local by0, by1 = here.miny, here.maxy
  if bx1 - bx0 < 3 or by1 - by0 < 3 then return false end

  -- THE SWITCH IS A TOGGLE AND THE ROOM CAN ARRIVE RUNNING. Live: the maze was already
  -- activated and the switch disabled (Bool1 = 1, no option), and the old "pull it once per
  -- room before any barrier" turned the puzzle OFF - after that every barrier answers
  -- "You find yourself unable to move through the barrier" and nothing in the room works.
  -- So the pull is DEMAND DRIVEN: a barrier saying exactly "unable to move through the
  -- barrier" is the only proof the maze is off, and mazeExecute sets D.mazeLeverOn[rk] =
  -- false when it hears it (see the refusal branch). A disabled switch, on the other hand,
  -- is the proof the maze is ON, and it is never clicked.
  D.mazeLeverOn = D.mazeLeverOn or {}
  local rk = rkey(here)

  -- IS THIS ROOM A TOXIN MAZE? A locked chest on the room's CENTRE is the whole answer -
  -- it is the only room on the floor that puts one there, and it stands there exactly until
  -- the maze is beaten. This replaces "is there a cluster of barriers near us", which
  -- needed the props found and grouped before the room could even be named: a room whose
  -- blob was cut to a stub planned nothing, and a room whose route was already cleared had
  -- no barriers left and was dropped as "not a maze" with its chest still locked.
  local centreChest = D.mazeCentreChest(world, here)
  if not centreChest then
    -- NO CHEST ON THE CENTRE: the maze is beaten, whether we did it this run or three floors
    -- ago. Record it and do nothing - the route reads D.mazeRoomDone, so it will not send us
    -- back here, and the door the switch unlocked is the way out.
    return D.mazeRoomFinished(rk, 'no chest on the centre')
  end
  if centreChest.disabled then
    -- the client has disabled the chest: looted, by us or by an earlier run. Same answer -
    -- no teleport, no re-solve, just do not come back.
    return D.mazeRoomFinished(rk, 'the centre chest is disabled (Bool1 = 1)')
  end

  -- this room IS a maze: the lever solver must never read the switch as one of its own
  -- levers (pulling it there toggles the maze instead of solving a 5-lever room)
  D.mazeRoomIsMaze = D.mazeRoomIsMaze or {}
  D.mazeRoomIsMaze[rk] = true

  do
    local lever, loid, lx, ly, lz, lPull = nil, nil, nil, nil, nil, false
    for _, o in ipairs(D.objScan()) do
      -- the cached records can outlive their entities: read every field behind pcall
      local ok, t, act, oid = pcall(function()
        return o.Tile_XYZ, tostring(o.Action or ''), o.Id
      end)
      if ok and t then
        local ox, oy = math.floor(t.x), math.floor(t.y)
        if ox >= bx0 - 2 and ox <= bx1 + 2 and oy >= by0 - 2 and oy <= by1 + 2 then
          local pull = string.find(string.lower(act), 'pull', 1, true) ~= nil
          -- the switch itself, whatever state it is in: a disabled one has no option at all
          if pull or oid == 49353 then
            lever, loid, lx, ly, lz, lPull = o, oid, ox, oy, math.floor(t.z or 0), pull
            break
          end
        end
      end
    end
    if lever and not lPull and D.mazeLeverOn[rk] == nil then
      -- disabled switch, nothing offers Pull: the maze is already running - do not touch it
      D.mazeLeverOn[rk] = true
      log(string.format('maze: switch %s at %d,%d is disabled - the maze is already running',
        tostring(loid), lx, ly))
    end
    if lever and D.mazeLeverOn[rk] == false then
      say('maze: pulling the switch to start the puzzle')
      log(string.format('maze: switch %s at %d,%d - the maze answered "unable to move", pulling it to start it',
        tostring(loid), lx, ly))
      -- The object click hands the engine the scanned record itself. A toggled switch
      -- is exactly where that can be refused - live, the same switch was clicked from a
      -- record the client had already flagged as "no action" while it accepted a Pull and
      -- started the puzzle - so a refused click is retried once from a freshly read scan.
      local clicked = D.clickObject('Pull', lever)
      if not clicked then
        log(string.format('maze: switch %s click refused - re-reading the scan and trying again', tostring(loid)))
        clicked = D.clickObject('Pull', D.objAt(loid, lx, ly))
      end
      if clicked then
        D.mazeLeverOn[rk] = true
        D.mazeLeverFail = nil
        D.mazeStartTries = 0
        -- the next pass plans against the maze that is now running, not the shut one
        D.mazeWait = nil
        D.mazeStepIdx = 1
        D.mazePlan = nil
        API.RandomSleep2(1200, 400, 700)
        D.dirty = true
        return true
      end
      -- It will not take the click from here. Hold the room: the barriers are pointless
      -- until the switch is down, and running them anyway is what produced
      -- "barrier, switch, barrier, barrier" and a death in the toxin.
      D.mazeLeverFail = (D.mazeLeverFail or 0) + 1
      if D.mazeLeverFail < 16 then
        say('maze: getting in range of the switch')
        D.dirty = true
        API.RandomSleep2(600, 200, 400)
        return true
      end
      -- still nothing after both click routes: leave the room rather than die in it
      log('maze: switch would not take a Pull after 16 tries - leaving the room instead of running the barriers')
      say('maze: cannot press the switch - leaving')
      D.mazeRoomDone = rkey(here)
      D.mazeLeverFail = nil
      return false
    end
  end
  -- what the room holds: the two kinds of obstacle and the chest in the middle.
  --
  -- THE BOX IS THE MAZE'S OWN FOOTPRINT, NOT A RADIUS AROUND THE PLAYER. Room segmentation
  -- stops at the first choke point and every one-tile maze corridor IS one, so `here` can
  -- be a stub of a corridor while the chest sits in another blob: live, room 8789:1050 came
  -- out 9x5 with "chest none", the plan read BLOCKED, nothing was clicked and the bot stood
  -- there. The fix is the props themselves - the barriers, pedestals and the locked chest,
  -- taken as ONE connected group and added to the room box - so the map covers the maze
  -- room and nothing else. A radius around the player would drag the corridor and the next
  -- room into the plan (a second maze room on the floor would even be merged into it).
  local barriers, pads, chest = {}, {}, nil
  local nBar, nPad = 0, 0
  local reach = D.MAZE_REACH or 20   -- coarse gate: how far a prop may be to even be a candidate
  local link = D.MAZE_LINK or 6      -- a prop joins the maze when it is this close to one already in it
  local seedMargin = D.MAZE_ROOM_MARGIN or 3   -- how far outside the room box a prop may sit
                                               -- and still count as this room's own
  local cand = {}
  for _, o in ipairs(world.objs or {}) do
    -- EVERYTHING IS READ IN ONE PROTECTED CALL. A prop removed between the scan and this
    -- loop leaves a dead userdata behind, and then even `o.Action` throws inside the
    -- engine's __index ("[C]: in metamethod 'index'") - that is what killed a run here.
    -- An object that is spawning or being removed also reports a NaN/inf tile, and
    -- math.floor of that has no integer representation, so pkey threw too.
    local okObj, tx, ty, tz, act, oid, onm, ob1 = pcall(function()
      local t = o.Tile_XYZ
      if not t then return nil end
      return t.x, t.y, t.z, o.Action, o.Id, o.Name, o.Bool1
    end)
    tx, ty = tonumber(tx), tonumber(ty)
    if okObj and tx and ty and tx == tx and ty == ty
      and math.abs(tx) < 1e15 and math.abs(ty) < 1e15 then
      local x, y = math.floor(tx), math.floor(ty)
      local z = math.floor(tonumber(tz) or 0)
      if math.max(math.abs(x - px), math.abs(y - py)) <= reach then
        if type(act) ~= 'string' then act = '' end
        if type(onm) ~= 'string' then onm = '' end
        -- 'Go-through' is the closed barrier. Once it is opened the action text
        -- changes (or goes away) and it must stop counting as a crossing, or the
        -- route would keep trying to click a barrier that is already open.
        local kind = nil
        if act == 'Go-through'
          or (D.MAZE_BARRIERS[oid] and act == '') then
          kind = 'barrier'
        elseif D.MAZE_PEDESTALS[oid] or (onm == 'Pedestal' and act == 'Mine') then
          kind = 'pad'
        elseif D.MAZE_CHESTS[oid] or onm == 'Locked chest' then
          kind = 'chest'
        end
        if kind then
          cand[#cand + 1] = { kind = kind, x = x, y = y, z = z, id = oid, name = onm,
            bool1 = ob1 or 0, d = (x - px) ^ 2 + (y - py) ^ 2,
            -- is it the ROOM's own prop? Only these seed the maze, so standing in the room
            -- next door can never plan (or draw) a maze that is not ours.
            inRoom = x >= bx0 - seedMargin and x <= bx1 + seedMargin
              and y >= by0 - seedMargin and y <= by1 + seedMargin }
        end
      end
    end
  end
  -- The maze is the group that starts at the props TOUCHING OUR ROOM and grows through the
  -- props that touch those (a maze's barriers sit 1-3 tiles apart). Nothing seeds it from
  -- outside the room: live, standing in the room next door seeded the cluster with a prop
  -- across the wall, the box became blob + that room and the map covered both rooms -
  -- "why does it calculate the maze map outside the maze room".
  table.sort(cand, function(a, b) return a.d < b.d end)
  local taken = {}
  for _, c in ipairs(cand) do
    if c.inRoom then
      c.used = true
      taken[#taken + 1] = c
    end
  end
  local grew = true
  while grew and #taken > 0 do
    grew = false
    for _, c in ipairs(cand) do
      if not c.used then
        for _, t in ipairs(taken) do
          if math.max(math.abs(c.x - t.x), math.abs(c.y - t.y)) <= link then
            c.used = true
            taken[#taken + 1] = c
            grew = true
            break
          end
        end
      end
    end
  end
  -- THE MAZE'S OWN BOX, taken from the props so the map is the maze room and not a 20-tile
  -- radius (the room blob is cut at the maze's one-tile corridors, so the blob alone was a
  -- 9x5 stub with "chest none" and a BLOCKED plan). The blob is unioned back in afterwards:
  -- you stand in the entrance/switch end of the SAME room - live, pressing the switch
  -- unlocked "the door next to you" from 3 tiles outside the barrier box - so being outside
  -- the props' box is not "a maze that is not yours".
  local mx0, mx1, my0, my1 = nil, nil, nil, nil
  for _, c in ipairs(taken) do
    if not mx0 or c.x < mx0 then mx0 = c.x end
    if not mx1 or c.x > mx1 then mx1 = c.x end
    if not my0 or c.y < my0 then my0 = c.y end
    if not my1 or c.y > my1 then my1 = c.y end
  end
  if not mx0 then
    -- The props are all out of sight (you may be standing at the far end of the room):
    -- the room's own floor is the box then. The centre chest already proved this room is
    -- a maze, so this is never "not a maze", only "nothing in the way yet".
    mx0, mx1, my0, my1 = bx0, bx1, by0, by1
  end
  for _, c in ipairs(taken) do
    local k = pkey(c.x, c.y)
    if c.kind == 'barrier' then
      if not barriers[k] then nBar = nBar + 1 end
      barriers[k] = { id = c.id, x = c.x, y = c.y, z = c.z }
    elseif c.kind == 'pad' then
      if not pads[k] then nPad = nPad + 1 end
      pads[k] = { id = c.id, x = c.x, y = c.y, z = c.z }
    elseif not chest or c.d < chest.d then
      chest = { id = c.id, name = c.name, x = c.x, y = c.y, z = c.z, d = c.d,
        bool1 = c.bool1 }
    end
  end
  -- THE CHEST ON THE CENTRE IS THE MAZE'S PROOF NOW, not the barriers. A room whose route
  -- is already cleared has no "Go-through" left in it, and the old "no barriers, no maze"
  -- guard dropped it as not-a-maze with its chest still locked. The centre chest never
  -- fails that way: if it is there, the room is a maze and the job is to open it.
  if not chest then
    chest = { id = centreChest.id, name = centreChest.name, x = centreChest.x,
      y = centreChest.y, z = centreChest.z, d = 0, bool1 = 0 }
    log(string.format('maze: using the centre chest %d at %d,%d - no maze prop group reached it',
      chest.id, chest.x, chest.y))
  end

  -- this room IS a maze, and that was recorded the moment the centre chest named it (the
  -- lever solver must never read the switch as one of its own levers: pulling it there
  -- toggles the maze instead of solving a 5-lever room)

  -- the box everything below plans in: the maze's own footprint, plus the room blob the
  -- player walked in from
  bx0, by0, bx1, by1 = math.min(bx0, mx0), math.min(by0, my0),
    math.max(bx1, mx1), math.max(by1, my1)

  local sx, sy = math.floor(px), math.floor(py)
  if sx < bx0 then sx = bx0 elseif sx > bx1 then sx = bx1 end
  if sy < by0 then sy = by0 elseif sy > by1 then sy = by1 end

  -- The sig is the room and the chest, nothing else: obstacle counts change as
  -- barriers open (and the world scan is 8 s stale anyway), which used to force a
  -- full replan - collision read, Dijkstra, 20 log lines - after every crossing. The
  -- plan is tile based and cleared tiles are remembered, so one plan serves the room.
  -- It is also checked BEFORE the collision read, so running the plan costs no scan.
  local sig = string.format('%s|%s', rkey(here),
    chest and (chest.x .. ',' .. chest.y) or '-')
  if D.mazePlan and D.mazePlan.sig == sig then
    return mazeExecute(D.mazePlan, here)
  end
  local scan = mazeRoom(here)
  local cells = scan.cells
  -- The click times and cleared tiles are NOT reset here: this branch runs right after
  -- every click, and wiping them is what made the just-clicked barrier look shut
  -- again and the route read as blocked. Only a change of room clears them.
  if D.mazeRoomKey ~= rkey(here) then
    D.mazeRoomKey = rkey(here)
    D.mazeClickAt, D.mazeCleared, D.mazeTries = {}, {}, {}
    D.mazeStalls, D.mazeWait, D.mazeStepUp = {}, nil, nil
    D.mazeChestWait = nil
    D.mazeStartTries = 0
  end
  -- a rebuilt plan starts at its own step 1: it was calculated against the current
  -- grid, so its first crossing is the next thing to clear
  D.mazeStepIdx = 1

  -- Passability: a tile the walk data does not cover is unknown and treated as a
  -- wall. Barriers and pedestals are standable because they are removed first -
  -- they only cost extra, so the route crosses as few of them as it can.
  local now = API.SystemTime()
  local function tile(x, y)
    local k = pkey(x, y)
    local c = cells[k]
    local bar = barriers[k]
    local pad = pads[k]
    local blocked = (not c) or (c.blocked == true)
    if bar or pad then blocked = false end
    -- a crossing already cleared this floor stays open even if the map record was
    -- not refreshed yet; the tile is walked over on the way back out
    -- Live comparison, before and after a cleared room: mining a pedestal flips the
    -- tile's Bool1 to 0, but opening a barrier changes the map record NOTHING - its
    -- cut stays in the type 99 data forever. So a cleared barrier has to be remembered
    -- for the rest of the room; a time-limited grace expired and made the route treat
    -- a barrier we had already opened as a wall again.
    local cleared = D.mazeCleared and D.mazeCleared[k]
    if cleared then blocked = false end
    return {
      -- the cut on a barrier tile IS the barrier, so it goes away with the click
      cuts = (c and not bar and not cleared) and c.cuts or 0,
      blocked = blocked,
      cost = 1 + (bar and D.MAZE_BARRIER_COST or 0) + (pad and D.MAZE_PEDESTAL_COST or 0),
      bar = bar, pad = pad,
    }
  end

  -- Dijkstra over the room box. Small grid (a maze room is 10-ish tiles across),
  -- so the frontier is scanned linearly instead of carrying a heap around.
  local dist, prev, done = {}, {}, {}
  local startK = pkey(sx, sy)
  dist[startK] = 0
  local goalK = chest and pkey(chest.x, chest.y) or nil
  local found = false
  for _ = 1, (bx1 - bx0 + 1) * (by1 - by0 + 1) + 1 do
    local bestK, bestD = nil, math.huge
    for k, d in pairs(dist) do
      if not done[k] and d < bestD then bestK, bestD = k, d end
    end
    if not bestK then break end
    done[bestK] = true
    if bestK == goalK then found = true break end
    local cx, cy = bestK:match('(%-?%d+):(%-?%d+)')
    cx, cy = tonumber(cx), tonumber(cy)
    local a = tile(cx, cy)
    for i = 1, 4 do
      local dx, dy, cutA, cutB = MZ_DIRS[i][1], MZ_DIRS[i][2], MZ_DIRS[i][3], MZ_DIRS[i][4]
      local nx, ny = cx + dx, cy + dy
      if nx >= bx0 and nx <= bx1 and ny >= by0 and ny <= by1 then
        local b = tile(nx, ny)
        local nk = pkey(nx, ny)
        -- a wall cut on either side of the edge stops the move
        if not a.blocked and not mzHas(a.cuts, cutA) and not mzHas(b.cuts, cutB)
          and not (b.blocked and nk ~= goalK) and not done[nk] then
          local nd = bestD + b.cost
          if nd < (dist[nk] or math.huge) then
            dist[nk] = nd
            prev[nk] = bestK
          end
        end
      end
    end
  end

  local path = {}
  if found then
    local k = goalK
    while k do
      local x, y = k:match('(%-?%d+):(%-?%d+)')
      table.insert(path, 1, { x = tonumber(x), y = tonumber(y), key = k })
      k = prev[k]
    end
  end

  local steps = {}
  for _, t in ipairs(path) do
    local bar, pad = barriers[t.key], pads[t.key]
    t.kind = bar and 'barrier' or (pad and 'mine' or nil)
    t.id = bar and bar.id or (pad and pad.id or nil)
    if t.kind then
      local o = bar or pad
      steps[#steps + 1] = { kind = t.kind, id = t.id, x = t.x, y = t.y, z = o and o.z or 0 }
    end
  end
  if found and chest then
    steps[#steps + 1] = { kind = 'chest', id = chest.id, x = chest.x, y = chest.y, z = chest.z or 0 }
    path[#path].kind, path[#path].id = 'chest', chest.id
  end

  local map, onPath = {}, {}
  for _, t in ipairs(path) do onPath[t.key] = true end
  for y = by1, by0, -1 do
    local row = {}
    for x = bx0, bx1 do
      local k = pkey(x, y)
      local ch = onPath[k] and '*' or '.'
      local c = cells[k]
      if (not c) or c.blocked then ch = 'X' end
      if pads[k] then ch = 'P' end
      if barriers[k] then ch = 'B' end
      if chest and chest.x == x and chest.y == y then ch = 'C' end
      if x == sx and y == sy then ch = '@' end
      if onPath[k] and ch == '.' then ch = '*' end
      row[#row + 1] = ch
    end
    map[#map + 1] = table.concat(row)
  end

  local plan = {
    sig = sig,
    room = rkey(here),
    path = path,
    steps = steps,
    map = map,
    origin = string.format('%d,%d', bx0, by1),
    ok = found,
    cost = found and dist[goalK] or nil,
    note = found and nil or 'no route to the chest in the middle',
  }
  -- Only a plan that got somewhere is cached: a BLOCKED one says nothing about the room,
  -- it says this position had no route in the box it was given - caching it froze the room
  -- as unsolvable for the rest of the floor ("maze plan: BLOCKED ... chest none", then the
  -- bot stood there). The next pass re-plans from wherever the player is by then.
  D.mazePlan = found and plan or nil

  -- The full dump goes out when the PLAN changes (steps, route length, obstacles),
  -- not on every tile the player walks over: the console write is the slowest thing
  -- in this function and it was costing a re-log per step.
  local logSig = table.concat({ rkey(here), tostring(found), #steps, #path, nBar, nPad }, '/')
  if D.mazeLogSig ~= logSig then
    D.mazeLogSig = logSig
    log(string.format('maze plan: %s | %d collision tile(s) | %d tile(s) | %d crossing(s) | %d barrier(s) %d pedestal(s) | room %s box %d,%d-%d,%d | you %d,%d | chest %s',
      found and 'route found' or 'BLOCKED', scan.n or 0, #path, #steps, nBar, nPad,
      rkey(here), bx0, by0, bx1, by1, sx, sy,
      chest and (chest.id .. '@' .. chest.x .. ',' .. chest.y) or 'none'))
    if found then
      local st, pt = {}, {}
      for n, s in ipairs(steps) do st[#st + 1] = string.format('%d.%s %d@%d,%d', n, s.kind, s.id, s.x, s.y) end
      for _, t in ipairs(path) do pt[#pt + 1] = t.x .. ',' .. t.y end
      log('maze steps: ' .. table.concat(st, ' '))
      log('maze path: ' .. table.concat(pt, ' '))
    end
    -- the map itself only goes to the log once per room: it is the same 14 lines and
    -- writing it after every cleared crossing is pure console cost
    if D.mazeMapSig ~= rkey(here) then
      D.mazeMapSig = rkey(here)
      log(string.format('maze map origin %d,%d  X wall, P pedestal, B barrier, C chest, * route, @ you', bx0, by1))
      for _, row in ipairs(map) do log('maze map ' .. row) end
    end
  end

  -- green dots on the tiles that get walked, red on the ones that must be cleared.
  -- +0.5 on x/y: a mark placed on the integer tile corner sits in the corner of the
  -- square, half a tile off the middle of it.
  API.ClearMarkTiles()
  D.mazeMarks = nil
  if found then
    local walk, cross = {}, {}
    for _, t in ipairs(path) do
      local pt = FFPOINT.new(t.x + 0.5, t.y + 0.5, chest and chest.z or 0)
      if t.kind then cross[#cross + 1] = pt else walk[#walk + 1] = pt end
    end
    -- Kept so the dots can be re-stamped while the plan is being worked: they now
    -- expire after D.MAZE_MARK_MS (30 s), so a maze that takes longer than that
    -- would otherwise lose its route halfway through.
    D.mazeMarks = { walk = walk, cross = cross, z = chest and chest.z or 0,
      goal = chest and FFPOINT.new(chest.x + 0.5, chest.y + 0.5, chest.z or 0) or nil }
    D.mazeMarksAt = 0        -- force the stamp even if the refresh timer is running
    D.mazeMarkRefresh(D.mazeMarks)
    if chest then
      log(string.format('maze chest: id %d name "%s" at %d,%d plane %s',
        chest.id, tostring(chest.name), chest.x, chest.y, tostring(chest.z)))
    end
    log(string.format('maze marks: %d green tile(s), %d red tile(s)', #walk, #cross))
    say(string.format('maze: %d tiles over %d crossing(s)', #path, #steps - 1))
  else
    say('maze: no route to the middle')
  end

  return mazeExecute(plan, here)
end

local function solveFlipTiles(world, here, px, py)
	if not here then return false end
	local green, yellow = flipBoard(here, px, py, world)

	local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
	for _, list in ipairs({ green, yellow }) do
		for _, t in ipairs(list) do
			if t.x < minx then minx = t.x end
			if t.x > maxx then maxx = t.x end
			if t.y < miny then miny = t.y end
			if t.y > maxy then maxy = t.y end
		end
	end

	-- THE BOARD'S OWN STATE THIS FLOOR. Only needed to tell a finished board from a board
	-- that is still streaming in; a room another puzzle owns is left alone.
	local key = rkey(here)
	local st = S.pondState[key]
	if st and st.kind and st.kind ~= 'flip' then st = nil end
	if not st then
		st = {}
		S.pondState[key] = st
		st.kind = 'flip'
	end
	if st.solved then return false end

	-- ONE COLOUR IS THE FINISHED BOARD, not "no puzzle here". Live: a solved board is 25
	-- "Yellow tile" props in a 5x5 box and every one of them still offers "Imbue", so the
	-- colour is the only signal there is - and returning false for that state left the room
	-- unsolved for ever, so the route kept walking the player back into a room with nothing
	-- left in it. It is written off only when the tiles FILL their box (a board still
	-- streaming in leaves gaps) and the box is the board this room has been showing; with no
	-- history it has to be the live board size, so a complete-looking 3x3 corner of a 5x5
	-- board that is still loading cannot pass for the whole thing.
	if #green == 0 or #yellow == 0 then
		local list = (#green > 0) and green or yellow
		if #list == 0 then return false end
		local w, h = maxx - minx + 1, maxy - miny + 1
		local colour = (#green > 0) and 'green' or 'yellow'
		local fills = w == h and w >= D.FLIP_MIN_BOARD and (w * h) == #list
		local known = st.flipW and st.flipH and st.flipW == w and st.flipH == h
		if fills and (known or (st.flipW == nil and w >= D.FLIP_BOARD)) then
			puzzleMarkSolved(here, string.format('the whole %dx%d board is %s', w, h, colour))
			return false
		end
		log(string.format('flip tiles: %d %s tile(s) in a %dx%d box - not the whole board, leaving it',
			#list, colour, w, h))
		return true
	end

	local w, h = maxx - minx + 1, maxy - miny + 1
	if w ~= h or w < D.FLIP_MIN_BOARD or (w * h) ~= (#green + #yellow) then
		log(string.format('flip tiles: %d x %d board with %d of %d tiles loaded - not acting on it',
			w, h, #green + #yellow, w * h))
		return true
	end
	-- a mixed board is the real size: remember it, so its finished state is recognised
	st.flipW, st.flipH = w, h

	-- Both target colours are planned and the cheaper one is taken: Force costs the
	-- player health, so a plan needing fewer forces wins even if it needs more
	-- imbues, and the tie-break is the imbue count.
	local function planFor(wantGreen)
		local wrong = {}
		for i = 1, w * h do wrong[i] = 0 end
		for _, t in ipairs(green) do
			if not wantGreen then wrong[(t.y - miny) * w + (t.x - minx) + 1] = 1 end
		end
		for _, t in ipairs(yellow) do
			if wantGreen then wrong[(t.y - miny) * w + (t.x - minx) + 1] = 1 end
		end
		local plan, left = flipSolve(w, h, wrong)
		if not plan then return nil end
		return { plan = plan, left = left, green = wantGreen }
	end

	local a, b = planFor(true), planFor(false)
	local chosen = a
	if a and b then
		if #b.plan.force < #a.plan.force
			or (#b.plan.force == #a.plan.force and #b.plan.imbue < #a.plan.imbue) then
			chosen = b
		end
	elseif b then
		chosen = b
	end
	if not chosen then return false end
	local plan, left, wantGreen = chosen.plan, chosen.left, chosen.green
	log(string.format('flip tiles: %d green %d yellow -> %d imbue(s) + %d force(s), target %s',
		#green, #yellow, #plan.imbue, left, wantGreen and 'green' or 'yellow'))

	local function tileAt(idx)
		local x = minx + ((idx - 1) % w)
		local y = miny + math.floor((idx - 1) / w)
		-- re-read before every click: the previous one flipped up to five tiles, so
		-- the object handles in the old scan are stale
		local _, _, now = flipBoard(here, px, py, world)
		return x, y, now[pkey(x, y)]
	end

	for _, idx in ipairs(plan.imbue) do
		local x, y, t = tileAt(idx)
		if not t then
			log(string.format('flip tiles: no tile at %d,%d - board changed, re-solving', x, y))
			return true
		end
		say(string.format('imbuing tile %d,%d', x, y))
		D.clickObject(D.FLIP_ACT, t.obj)
		API.RandomSleep2(700, 250, 400)
		waitStill(3000)
	end

	-- Leftovers are the illegal part of the state: they can only be cleared by
	-- flipping a single tile, which is the tile's second option ("Force").
	for _, idx in ipairs(plan.force) do
		local x, y, t = tileAt(idx)
		if t then
			local wasGreen = t.green
			say(string.format('forcing tile %d,%d', x, y))
			log(string.format('flip tiles: forcing %d,%d (single-tile flip)', x, y))
			D.clickObject(D.FLIP_ACT, t.obj, API.OFF_ACT_GeneralObject_route1)			API.RandomSleep2(700, 250, 400)
			waitStill(3000)
			local _, _, after = flipBoard(here, px, py, world)
			local now = after[pkey(x, y)]
			if now and now.green == wasGreen then
				warn(string.format('flip tiles: force on %d,%d did nothing - option 2 route is wrong', x, y))
			end
		end
	end
	return true
end

--------------------------------------------------------------------
-- icy pressure pads (sliding room)
--------------------------------------------------------------------
-- Ice room with four pads: the floor slides you until something stops you, so a
-- plain tile click overshoots. Sliding is deterministic, which makes it a graph
-- search instead of a guess: from any tile there are at most 8 moves (one per
-- direction), each landing on a known tile - the last walkable tile before a
-- wall, or a pad, which stops the slide. Breadth-first over that graph reaches
-- every pad, one slide per pass. (ShadowDungeon's IcyPads.java has no solver: it
-- sets LeaveDungeon and skips the floor.)
-- The four pressure pads are "Button" objects, ids confirmed live in the room:
-- 49325 at 6866,5100 / 49324 at 6867,5091 / 49326 at 6877,5098 / 49327 at 6877,5091
-- (they have no actions - the room is solved by sliding over them, not by clicking).
D.ICY_PADS = { 49320, 49321, 49322, 49323, 49324, 49325, 49326, 49327 }
D.ICY_PAD_SET = {}
for _, id in ipairs(D.ICY_PADS) do D.ICY_PAD_SET[id] = true end

-- The pad ids are not stable between floors: a live room had 49320-49323 while the
-- first one seen had 49324-49327, and a hard-coded four-id list missed the puzzle
-- completely. The name is what identifies them - "Button", no option on it, and the
-- room is solved by sliding over it rather than clicking it.
function D.icyPadObj(o)
	if not o then return false end
	-- A record whose entity has left the world throws from the userdata metamethod
	-- ("memory allocation error: block too big"), and this is the ONE place that reads
	-- every object on the floor, so a single dead record killed the whole run (live
	-- 11:30 "Script failed: memory allocation error: block too big").
	local ok, id, nm, act = pcall(function()
		return o.Id, o.Name, o.Action
	end)
	if not ok then return false end
	if D.ICY_PAD_SET[id] then return true end
	local n = string.lower(tostring(nm or ''))
	if not (string.find(n, 'button', 1, true) or string.find(n, 'pressure pad', 1, true)) then
		return false
	end
	return (act or '') == ''
end
D.ICY_STEPS = {
	{ 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
	{ 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
}

-- Where a slide in (dx,dy) from (x,y) ends. A slide stops on anything you can
-- stand on: one of the four pressure pads (the goal), a resting tile in front of a
-- door, or the last walkable tile before an obstacle - the room has four obstacles
-- that exist precisely to stop a slide and let you pick a new direction.
-- A slide stops as soon as it is NEXT TO an obstacle, not when it runs into it:
-- the wiki puts that boundary at the obstacle's 3x3 area. Modelling it as "the
-- next tile is solid" let the plan send the player diagonally past a barrel, and in
-- the room the barrel stopped it a tile early - which is what "tries to get on from
-- the corner but the barrels are in the way" looked like.
local function icyTouchesObstacle(world, x, y)
	for _, n in ipairs(D.ICY_STEPS) do
		if not world.walk[pkey(x + n[1], y + n[2])] then return true end
	end
	return false
end

-- Tiles in front of a doorway: walkable, so the player can stand there and pick a
-- direction instead of sliding through. In the icy room that is the only place
-- besides the pads where stopping is possible.
local function icyRestTiles(world)
	local rest = {}
	for _, d in ipairs(world.doors or {}) do
		for _, n in ipairs(D.DIR4) do
			local k = pkey(d.x + n[1], d.y + n[2])
			if world.walk[k] then rest[k] = true end
		end
	end
	return rest
end

-- Tiles crossed by a slide - the whole path, because the pads activate by being
-- slid OVER, not by being stopped on: "You slide onto the button, activating it.
-- You have completed 1 of 4." Tracking only where the slide ends is what made the
-- bot re-target the last pad for ever while sliding across it every time.
local function icyPath(world, x, y, dx, dy, pads, stops, visited, through)
	local cx, cy = x, y
	local crossed = {}
	for _ = 1, 64 do
		local nx, ny = cx + dx, cy + dy
		local k = pkey(nx, ny)
		if visited then visited[#visited + 1] = k end
		-- A doorway tile is blocked collision, so the ice carries the player into it
		-- and on into the next room: that is the way out of this puzzle. Without this
		-- check the path stopped one tile short and the exit was never found.
		if through and through[k] then return nx, ny, crossed end
		if pads[k] then crossed[#crossed + 1] = k return nx, ny, crossed end
		if stops[k] then return nx, ny, crossed end
		if not world.walk[k] then return cx, cy, crossed end
		if icyTouchesObstacle(world, nx, ny) and not icyTouchesObstacle(world, cx, cy) then
			return nx, ny, crossed
		end
		cx, cy = nx, ny
	end
	return cx, cy, crossed
end

-- The pressure pads of this room: four "Button" objects lying on the ice, read by id.
-- The box the four of them share is the room - the room set is NOT used, because
-- Daemonheim merges rooms once a doorway is open, and a room key would then follow us
-- into the room next door and turn its normal walking into slides.
local function icyPads(world, px, py)
	local pads, list = {}, {}
	-- The pass's own AllObject array already holds every object: no extra scan.
	for _, o in ipairs(world.objs or {}) do
		if D.icyPadObj(o) then
			local ok, t = pcall(function() return o.Tile_XYZ end)
			if ok and t then
				local x, y = math.floor(t.x), math.floor(t.y)
				if px and math.abs(x - px) <= 16 and math.abs(y - py) <= 16 then
					pads[pkey(x, y)] = true
					list[#list + 1] = { x = x, y = y }
				end
			end
		end
	end
	return pads, list
end

D.icyHit = {}          -- pad tiles already slid across (confirmed by the chat counter)
-- Pad TILES seen on this floor. Activating a pad changes its graphics/id, so the live
-- object list shrinks as the puzzle is solved - but the tile still stops a slide and
-- the four tiles are what "pads left" is counted against.
D.icyPadTiles = {}
D.icySolves = 0        -- how many times the remaining set was rebuilt
D.icyBad = {}          -- "tile>dx,dy" slides the room refused (model disagrees with the game)
D.icyLastSig = nil     -- the slide issued last pass, to notice one that went nowhere
D.icyRepeat = 0
D.iceStuck = {}        -- pad boxes the slide layer gave up on
D.icyTiles = {}        -- tiles the player stood on while the slide layer was in charge
-- One Daemonheim room is about 13 tiles across. A remembered pad box wider than this has
-- swallowed other rooms and must be rebuilt from the pads in front of us (see icyPads).
D.ICY_BOX_MAX = 20
-- How many pads it takes to call a room an ICE room. The puzzle has four; three is the
-- floor in case one was already activated before the layer ever saw it. One pad is
-- scenery - the barrel room has a pressure pad lying on its floor - and the solver must
-- not start sliding there.
D.ICY_MIN_PADS = 3
-- And how far from us those pads may be while the room is being recognised: half a room,
-- so a pad in the next room through the wall cannot seed the box.
D.ICY_PAD_NEAR = 9
-- A room with NO ice in it must stop costing anything. Every pass used to pay for the
-- pad scan in every room, on maps that have no ice at all ("there is no icy pads on this
-- map" - live). After this many fruitless looks in one room the layer switches itself off
-- there, and comes back the moment we stand in a different room.
D.ICY_LOOK_PASSES = 20
-- One pad look per this many ms while the floor has not shown an ice room yet, so the
-- search for a room that is not there cannot run at pass rate.
D.ICY_LOOK_MS = 2000
-- Owned passes with no pad crossed and no change in the client's counter before the room
-- is written off. The solver holding a pass blocks all routing, so this is the bound on
-- how long "thinking" may last in the pad room.
D.ICY_STALL_MS = 25000

-- The boss room stays OFF LIMITS until every other doorway on the floor is done.
-- One boolean, flipped once, and only from the check below - nothing else may
-- open the boss room, so "it went to the boss too early" cannot come back.
D.bossOpen = false
-- Set once, when the floor's boss DIES: nothing on this floor is left to do and the
-- only objective is the end ladder. Not to be confused with D.bossOpen, which is the
-- opposite phase - "every door is done, now go and do the boss".
D.bossDown = false
D.iceStuckHere = nil   -- set when that happens, so the main loop can write the room off

-- Asleep instead of "no": in this room the walk-based door/room logic must never
-- run, because walking is disabled on the ice and every walk it plans is a dead end.
-- Returning true keeps the main chain on the slide layer and costs one pass.
local function iceIdle()
	API.RandomSleep2(500, 200, 300)
	return true
end

-- Is the puzzle done? Only the client knows: "You slide onto the button, activating
-- it. You have completed 4 of 4." The pads themselves stay in the room afterwards.
local function icyDone()
	return (chat.icyCount or 0) >= 4
end

local function solveIcyPads(world, here, px, py, done, skip)
	-- A barrel room has a pressure pad on the floor, and this solver reads it as an ice
	-- square ("icy pads: 1 pad(s) at 10725,4886" in the live barrel room). The barrel
	-- puzzle owns the room until it is solved, and a room this solver has FINISHED is
	-- not an ice room either: once the barrel room's npcs turn into scenery the barrel
	-- solver has no reason to keep claiming it, but its pressure pad is still lying
	-- there and would start a slide in a room that is already done.
	if D.barrelRoomBusy(here) or D.barrelDoneHere(here) then return false end
	if not px then return false end
	-- CHEAP GATE FIRST, BEFORE THE SCAN. This solver used to read - and lower-case - the
	-- name of EVERY object on the floor, in every room, on every pass, before it asked
	-- whether the player was anywhere near the ice. That is the "it thinks really hard
	-- and cannot decide" pause in rooms that hold no ice at all: a few hundred object
	-- reads and a few hundred string copies per pass, several passes a second. The
	-- remembered box answers the same question from two number compares.
	--
	-- THE BOX BELONGS TO ONE ROOM. It is remembered so the room is still recognised after
	-- its own pads have been activated and left the scan, but nothing ever cleared it:
	-- once a pad room was found, the gate refused every other room for the rest of the
	-- run and the next ice room - on this floor or the next - was never looked at. The
	-- box, the tiles stood on while sliding and the look budget are all per room, so they
	-- are dropped together the moment the player is standing in a different one.
	local hereKey = D.here and rkey(D.here) or nil
	local box = D.icyBox
	if box and D.icyBoxRoom ~= hereKey then
		D.icyBox, D.icyBoxRoom = nil, nil
		D.icyTiles = {}
		D.icyLook, D.icyLookAt = 0, nil
		box = nil
	end
	if D.icyFloorNone then
		-- The latch is per ROOM, not per floor: a floor can be all statue rooms until the
		-- pad room turns up two rooms later, and that room must get its look back.
		if D.icyNoneRoom == hereKey then return false end
		D.icyFloorNone, D.icyNoneRoom, D.icyLook, D.icyLookAt = nil, nil, 0, nil
	end
	if box then
		local nearBox = px >= box.x1 - 2 and px <= box.x2 + 2
			and py >= box.y1 - 2 and py <= box.y2 + 2
		if not (nearBox or D.icyTiles[pkey(px, py)]) then return false end
	else
		-- No pad room on this floor yet: look, but not on every pass. A map whose only
		-- puzzle is, say, the statue room has no ice at all, and it still paid for a full
		-- pad scan in every room several times a second.
		local now = API.SystemTime()
		if D.icyLookAt and (now - D.icyLookAt) < D.ICY_LOOK_MS then return false end
		D.icyLookAt = now
	end
	local pads, list = icyPads(world, px, py)
	-- THE ICE ROOM IS THE ONLY ROOM THIS SOLVER MAY RUN IN, and the room is defined by
	-- the pads themselves: a cluster of them, at most one Daemonheim room wide, standing
	-- around the player. A single pad is scenery (the barrel room has one pressure pad on
	-- its floor) and pads from two different rooms are two different puzzles, so neither
	-- may open the layer. Once the room IS known the box is remembered for the floor -
	-- pads leave the scan as they are activated, and the room must still be recognised
	-- after its own pads are gone.
	if not box then
		-- Seeding: the pads have to be near US (D.ICY_PAD_NEAR, half a room) and there
		-- have to be at least D.ICY_MIN_PADS of them, or this is not an ice room.
		local near = {}
		for _, q in ipairs(list) do
			if math.abs(q.x - px) <= D.ICY_PAD_NEAR and math.abs(q.y - py) <= D.ICY_PAD_NEAR then
				near[#near + 1] = q
			end
		end
		if #near < D.ICY_MIN_PADS then
			-- NO ICE ON THIS FLOOR. A floor whose only puzzle is the statue room has no
			-- pads anywhere, and this solver still looked in every room on every pass.
			-- After D.ICY_LOOK_PASSES fruitless looks the floor is written off for ice and
			-- the layer stops looking entirely until the next ladder.
			D.icyLook = (D.icyLook or 0) + 1
			if D.icyLook >= D.ICY_LOOK_PASSES then
				D.icyFloorNone = true
				D.icyNoneRoom = D.here and rkey(D.here) or nil
				if not D.icyFloorNoneLogged then
					D.icyFloorNoneLogged = true
					log('icy pads: no pad room here - the slide layer is off until we enter another room')
				end
			end
			return false
		end
		-- A room another puzzle has already finished is not an ice room whatever is lying
		-- in it: pads are ordinary scenery once their own puzzle is done.
		if here and S.pondState then
			local done = S.pondState[rkey(here)]
			if done and done.solved then return false end
		end
		local x1, y1, x2, y2 = near[1].x, near[1].y, near[1].x, near[1].y
		for _, q in ipairs(near) do
			x1, y1 = math.min(x1, q.x), math.min(y1, q.y)
			x2, y2 = math.max(x2, q.x), math.max(y2, q.y)
		end
		if (x2 - x1) > D.ICY_BOX_MAX or (y2 - y1) > D.ICY_BOX_MAX then return false end
		D.icyBox = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
		D.icyBoxRoom = hereKey      -- the room this box belongs to; see the gate at the top
		box = D.icyBox
		pads, list = {}, near
		for _, q in ipairs(near) do pads[pkey(q.x, q.y)] = true end
	else
		-- A BOX ONLY GROWS FROM PADS THAT BELONG TO IT. icyPads looks 16 tiles around the
		-- player, which reaches into the neighbouring room, and the old union took those
		-- pads in: one button next door widened the box a little more each pass until the
		-- slide search covered most of the floor. Pad-like objects outside the box are not
		-- this room's business and are dropped.
		local keep = {}
		for _, q in ipairs(list) do
			if q.x >= box.x1 - 2 and q.x <= box.x2 + 2
				and q.y >= box.y1 - 2 and q.y <= box.y2 + 2 then
				keep[#keep + 1] = q
			end
		end
		list = keep
		pads = {}
		for _, q in ipairs(list) do pads[pkey(q.x, q.y)] = true end
		if #list > 0 then
			local x1, y1, x2, y2 = box.x1, box.y1, box.x2, box.y2
			for _, q in ipairs(list) do
				x1, y1 = math.min(x1, q.x), math.min(y1, q.y)
				x2, y2 = math.max(x2, q.x), math.max(y2, q.y)
			end
			if (x2 - x1) <= D.ICY_BOX_MAX and (y2 - y1) <= D.ICY_BOX_MAX then
				box.x1, box.y1, box.x2, box.y2 = x1, y1, x2, y2
			end
		end
	end
	-- Two tiles of margin around the pads reaches the stopping tiles in front of the
	-- doorways and stops at the walls: just outside a doorway is a different tile, so
	-- the room next door is never claimed. Tiles the player has actually stood on while
	-- sliding are remembered too, in case a variant has its pads well inside the room.
	box = D.icyBox
	if not box then return false end
	local onIceTile = D.icyTiles[pkey(px, py)]
	local inBox = px >= box.x1 - 2 and px <= box.x2 + 2 and py >= box.y1 - 2 and py <= box.y2 + 2
	-- ONLY IN THE PAD ROOM. Either we are inside the pad box, or we are on a tile this
	-- puzzle has already seen us slide on and that tile is still within the room holding
	-- those pads. Anything else - the room next door, the corridor, the boss room - is
	-- not this solver's business, whatever pad-like scenery it happens to contain.
	if not inBox then
		local nearRoom = onIceTile
			and px >= box.x1 - D.ICY_PAD_NEAR and px <= box.x2 + D.ICY_PAD_NEAR
			and py >= box.y1 - D.ICY_PAD_NEAR and py <= box.y2 + D.ICY_PAD_NEAR
		if not nearRoom then return false end
	end
	D.icyTiles[pkey(px, py)] = true
	local roomKey = pkey(box.x1, box.y1)
	if #list > 0 and not D.icySeenLog then
		D.icySeenLog = true
		local at = {}
		for _, q in ipairs(list) do at[#at + 1] = string.format('%d,%d', q.x, q.y) end
		log(string.format('icy pads: %d pad(s) at %s', #list, table.concat(at, ' ')))
	end
	if D.iceStuck[roomKey] then return false end
	D.iceRoomKey = roomKey

	-- WATCHDOG. Returning true from this solver means "the ice owns this pass" and the main
	-- loop plans nothing while it does, so a solver that holds the room without making
	-- progress looks exactly like the bot thinking. Live: 51 s of silence at 7064,270 with
	-- no click in between, ending in "solver icy pads threw". Progress is a pad crossed or
	-- the client's pad counter moving; if neither happens for D.ICY_STALL_MS the room is
	-- written off instead of ground at for ever.
	local progress = chat.icyCount or 0
	for _ in pairs(D.icyHit) do progress = progress + 1 end
	if D.icyWatchRoom ~= roomKey or D.icyWatchMark ~= progress then
		D.icyWatchRoom, D.icyWatchMark, D.icyWatchAt = roomKey, progress, API.SystemTime()
	elseif D.icyWatchAt and (API.SystemTime() - D.icyWatchAt) > D.ICY_STALL_MS then
		if not D.icyStallLogged then
			D.icyStallLogged = true
			log(string.format('icy pads: no progress in the pad room for %ds - giving up on it',
				math.floor(D.ICY_STALL_MS / 1000)))
		end
		D.iceStuck[roomKey] = true
		D.iceStuckHere = true
		return false
	end

	-- Remember the pad TILES and plan from those, not from the live objects. A pad that
	-- has been slid over changes its graphics/id (and can drop out of the scan
	-- entirely), and dropping it from `pads` also removed it from the slide STOP set -
	-- so the model started sliding straight through pads that are still there.
	D.icyPadTiles = D.icyPadTiles or {}
	for _, q in ipairs(list) do D.icyPadTiles[pkey(q.x, q.y)] = { x = q.x, y = q.y } end
	pads, list = {}, {}
	for k, q in pairs(D.icyPadTiles) do
		if q.x >= box.x1 - 2 and q.x <= box.x2 + 2
			and q.y >= box.y1 - 2 and q.y <= box.y2 + 2 then
			pads[k] = true
			list[#list + 1] = q
		end
	end
	table.sort(list, function(a, b)
		if a.y ~= b.y then return a.y < b.y end
		return a.x < b.x
	end)

	local stopSet = icyRestTiles(world)
	for k in pairs(pads) do stopSet[k] = true end
	-- Which doorway is worth sliding to? The room has several, and leaving through
	-- the first one found is how the bot kept sliding back out the way it came while
	-- the unexplored doors sat on the other side. Score the tile in front of every
	-- doorway: unexplored work behind it (+2), never walked through (+2), openable
	-- without a key (+1), and never the boss room.
	local doorSide, sideScore = {}, {}
	local heldK, unknownK = heldKeys()
	for _, d in ipairs(world.doors or {}) do
		local score = 0
		if not D.traversed[dkey(d)] then score = score + 2 end
		if doorLeadsToWork(world, d, here, S.done, skip) then score = score + 2 end
		if not doorNoKey(world, d) and doorClickable(d, world, heldK, unknownK) then
			score = score + 1
		end
		if D.doorLeadsToBossRoom(world, d, here and here.idx) then score = 0 end
		-- Do not slide out into a room already written off as empty, or back into the
		-- one we just came from: that is the ice-room / dead-end loop.
		if D.doorLeadsToDeadRoom(world, d, here and here.idx, S.visitedEmpty, S.arrivedFrom) then
			score = score - 4
		end
		for _, n in ipairs(D.DIR4) do
			local k = pkey(d.x + n[1], d.y + n[2])
			if world.walk[k] then
				doorSide[k] = true
				if score > (sideScore[k] or -1) then sideScore[k] = score end
			end
		end
	end

	if icyDone(here, list) then
		if not D.icySolvedLogged then
			D.icySolvedLogged = true
			if here then puzzleMarkSolved(here, '4 of 4 icy pads') end
		end

		local hereKey = pkey(px, py)
		local hereScore = (doorSide[hereKey] and (sideScore[hereKey] or 0)) or -1
		local bestScore = -1
		for _, v in pairs(sideScore) do
			if v > bestScore then bestScore = v end
		end

		-- Leave through the doorway beside the pad we are standing on. A doorway
		-- already walked through is still a way OUT of the ice room.
		local function leaveHere()
			local pick, fallback = nil, nil
			for _, d in ipairs(world.doors or {}) do
				local beside = false
				for _, n in ipairs(D.DIR4) do
					if d.x + n[1] == px and d.y + n[2] == py then beside = true break end
				end
				if beside and not doorNoKey(world, d) and doorClickable(d, world, heldK, unknownK) then
					if D.traversed[dkey(d)] then
						fallback = fallback or d
					else
						pick = pick or d
					end
				end
			end
			local d = pick or fallback
			if not d then
				D.icyIdle = (D.icyIdle or 0) + 1
				if D.icyIdle > 40 then
					if not D.icyDoorLogged then
						D.icyDoorLogged = true
						log(string.format('icy pads: standing on the pad %d,%d with no usable door beside it - giving up on this room',
							px, py))
					end
					D.iceStuck[roomKey] = true
					D.iceStuckHere = true
					return false
				end
				return iceIdle()
			end
			local before = roomNearRooms(world.rooms, px, py)
			D.icyDoorTries = 0
			say(string.format('using the %s door %d from the pad', tostring(d.action), d.id))
			log(string.format('icy pads: on the door-side pad %d,%d, opening door %d "%s" (%s)%s',
				px, py, d.id, tostring(d.obj and d.obj.Name), tostring(d.action),
				pick and '' or ' (already used - still the way out)'))
			if openDoor(d, world) then
				local px2, py2 = ptile()
				if not crossedDoorway(d, px, py, px2, py2) then
					-- the door has only just opened: one click on the Enter leaf is
					-- what walks us out of the room
					local leaf = enterLeaf(world, d)
					say('stepping through the door')
					D.clickObject('Enter', leaf.obj)
					API.RandomSleep2(700, 250, 400)
					waitStill(3000)
					px2, py2 = ptile()
				end
				local after = roomNearRooms(world.rooms, px2, py2)
				if (after and before and after.idx ~= before.idx)
					or crossedDoorway(d, px, py, px2, py2) then
					markDoorway(d, world)
					clearReach()
					-- same rule as everywhere else: only a real room change sets "came from"
					if before and after and after.idx ~= before.idx then S.arrivedFrom = rkey(before) end
					log(string.format('icy pads: through door %d - out of the room', d.id))
					D.icyIdle = 0
				end
				D.dirty = true
			end
			return iceIdle()
		end

		-- No other pad in the room is worth sliding to: leave from this one. This is
		-- what stops the endless west/east ping-pong between two pads whose doorways
		-- score the same - whichever pad is best, the bot uses its door.
		if hereScore >= 0 and hereScore >= bestScore then
			return leaveHere()
		end

		-- Slide to the pad whose doorway scores strictly better than this one.
		local startK = pkey(px, py)
		local prev, seen, queue, head = {}, { [startK] = true }, { { px, py } }, 1
		local goal = nil
		while head <= #queue and head <= 400 and not goal do
			local cur = queue[head]
			head = head + 1
			for _, n in ipairs(D.ICY_STEPS) do
				local lx, ly = icyPath(world, cur[1], cur[2], n[1], n[2], pads, stopSet)
				local k = pkey(lx, ly)
				if (lx ~= cur[1] or ly ~= cur[2]) and not seen[k] then
					if doorSide[k] and not pads[k] and (sideScore[k] or 0) > hereScore then
						goal = { fromX = cur[1], fromY = cur[2], dx = n[1], dy = n[2], x = lx, y = ly }
						break
					end
					seen[k] = true
					prev[k] = { fromX = cur[1], fromY = cur[2], dx = n[1], dy = n[2] }
					queue[#queue + 1] = { lx, ly }
				end
			end
		end
		if not goal then
			if hereScore >= 0 then
				log(string.format('icy pads: no better pad reachable from %d,%d - leaving through this one', px, py))
				return leaveHere()
			end
			if not D.icyDoorLogged then
				D.icyDoorLogged = true
				log(string.format('icy pads: no slide from %d,%d reaches a door-side pad', px, py))
			end
			D.iceStuck[roomKey] = true
			D.iceStuckHere = true
			return false
		end
		local dx, dy = goal.dx, goal.dy
		local cx, cy = goal.fromX, goal.fromY
		while not (cx == px and cy == py) do
			local pv = prev[pkey(cx, cy)]
			if not pv then break end
			dx, dy = pv.dx, pv.dy
			cx, cy = pv.fromX, pv.fromY
		end
		say(string.format('sliding to the door pad: %d,%d', px + dx, py + dy))
		log(string.format('icy pads: pads done, sliding %d,%d dir %d,%d -> door-side pad %d,%d (score %d > %d)',
			px, py, dx, dy, goal.x, goal.y, sideScore[pkey(goal.x, goal.y)] or 0, hereScore))
		D.walkTile(px + dx, py + dy, 0)
		API.RandomSleep2(900, 300, 500)
		waitStill(4000)
		return true
	end

	-- Puzzle not done yet: slide across the pads that are left. A pad stops the slide
	-- with the player standing on it, so "crossed" and "landed on" are the same tile.
	local need = {}
	for _, pad in ipairs(list) do
		local k = pkey(pad.x, pad.y)
		if not D.icyHit[k] then need[#need + 1] = pad end
	end
	if #need == 0 then
		D.icySolves = D.icySolves + 1
		if D.icySolves > 2 then
			log(string.format('icy pads: chat says %d of 4 but every pad looks used - giving up', chat.icyCount or 0))
			D.iceStuck[roomKey] = true
			D.iceStuckHere = true
			return false
		end
		D.icyHit = {}
		log('icy pads: counter disagrees with the plan - rebuilding the pad set')
		for _, pad in ipairs(list) do need[#need + 1] = pad end
	end

	local function freshHits(crossed)
		local n = 0
		for _, k in ipairs(crossed) do
			if not D.icyHit[k] then n = n + 1 end
		end
		return n
	end

	-- One slide per pass. If the player is still on the same tile afterwards, the slide
	-- model and the room disagree about that direction - drop the direction instead of
	-- clicking it for ever.
	local start = pkey(px, py)
	local pick = nil
	for _, n in ipairs(D.ICY_STEPS) do
		local lx, ly, crossed = icyPath(world, px, py, n[1], n[2], pads, stopSet)
		local sig = start .. '>' .. n[1] .. ',' .. n[2]
		if not pick and freshHits(crossed) > 0 and not D.icyBad[sig] then
			pick = { n = n, lx = lx, ly = ly, sig = sig, crossed = crossed }
		end
	end
	if pick then
		local n = pick.n
		if D.icyLastSig == pick.sig then
			D.icyRepeat = (D.icyRepeat or 0) + 1
			if D.icyRepeat >= 2 then
				D.icyBad[pick.sig] = true
				D.icyRepeat = 0
				log(string.format('icy pads: sliding %d,%d dir %d,%d went nowhere - dropping that direction',
					px, py, n[1], n[2]))
				return iceIdle()
			end
		else
			D.icyRepeat = 0
		end
		D.icyLastSig = pick.sig
		for _, k in ipairs(pick.crossed) do D.icyHit[k] = true end
		say(string.format('sliding for a pad: %d,%d', px + n[1], py + n[2]))
		log(string.format('icy pads: %d left, sliding %d,%d dir %d,%d -> %d,%d (crosses %d pad(s))',
			#need, px, py, n[1], n[2], pick.lx, pick.ly, #pick.crossed))
		D.walkTile(px + n[1], py + n[2], 0)
		API.RandomSleep2(900, 300, 500)
		waitStill(4000)
		return true
	end

	local prev2, seen2, queue2, head2 = {}, { [start] = true }, { { px, py } }, 1
	local hit = nil
	while head2 <= #queue2 and head2 <= 400 and not hit do
		local cur = queue2[head2]
		head2 = head2 + 1
		for _, n in ipairs(D.ICY_STEPS) do
			local lx, ly, crossed = icyPath(world, cur[1], cur[2], n[1], n[2], pads, stopSet)
			if lx ~= cur[1] or ly ~= cur[2] then
				local k = pkey(lx, ly)
				if freshHits(crossed) > 0 then
					hit = { x = lx, y = ly, dx = n[1], dy = n[2], fromX = cur[1], fromY = cur[2] }
					break
				end
				if not seen2[k] then
					seen2[k] = true
					prev2[k] = { fromX = cur[1], fromY = cur[2], dx = n[1], dy = n[2] }
					queue2[#queue2 + 1] = { lx, ly }
				end
			end
		end
	end
	if not hit then
		if not D.icyLogged then
			D.icyLogged = true
			log(string.format('icy pads: no slide from %d,%d leads to a pad still needed', px, py))
		end
		return iceIdle()
	end
	local dx, dy = hit.dx, hit.dy
	local cx, cy = hit.fromX, hit.fromY
	while not (cx == px and cy == py) do
		local pv = prev2[pkey(cx, cy)]
		if not pv then break end
		dx, dy = pv.dx, pv.dy
		cx, cy = pv.fromX, pv.fromY
	end
	local sig2 = start .. '>' .. dx .. ',' .. dy
	if D.icyLastSig == sig2 then
		D.icyRepeat = (D.icyRepeat or 0) + 1
		if D.icyRepeat >= 3 then
			log(string.format('icy pads: the repositioning slide %d,%d dir %d,%d went nowhere - giving up on this room',
				px, py, dx, dy))
			D.iceStuck[roomKey] = true
			D.iceStuckHere = true
			return false
		end
	else
		D.icyRepeat = 0
	end
	D.icyLastSig = sig2
	say(string.format('sliding to %d,%d', px + dx, py + dy))
	log(string.format('icy pads: %d left, repositioning %d,%d dir %d,%d', #need, px, py, dx, dy))
	D.walkTile(px + dx, py + dy, 0)
	API.RandomSleep2(900, 300, 500)
	waitStill(4000)
	return true
end

	------------------------------------------------------------------
	-- exports: what Dung.lua and the other two modules may call
	------------------------------------------------------------------
	X.isPondskater, X.pondskaters, X.pondReset, X.puzzleMarkSolved = isPondskater, pondskaters, pondReset, puzzleMarkSolved
	X.puzzleOwn, X.puzzleClaim, X.solvePondskaters, X.puzzleDone = puzzleOwn, puzzleClaim, solvePondskaters, puzzleDone
	X.repairAction, X.looksBarrel, X.cid, X.standOn = repairAction, looksBarrel, cid, standOn
	X.solveFerrets, X.flipBoard, X.flipSolve, X.bridgeOurs = solveFerrets, flipBoard, flipSolve, bridgeOurs
	X.bridgePick, X.mzHas, X.mzOr, X.MZ_N = bridgePick, mzHas, mzOr, MZ_N
	X.MZ_E, X.MZ_S, X.MZ_W, X.MZ_DIRS = MZ_E, MZ_S, MZ_W, MZ_DIRS
	X.mazeTiles, X.mazeExecute, X.mazeRoom, X.solveFlipTiles = mazeTiles, mazeExecute, mazeRoom, solveFlipTiles
	X.icyTouchesObstacle, X.icyRestTiles, X.icyPath, X.icyPads = icyTouchesObstacle, icyRestTiles, icyPath, icyPads
	X.iceIdle, X.icyDone, X.solveIcyPads = iceIdle, icyDone, solveIcyPads

	return bind
end
