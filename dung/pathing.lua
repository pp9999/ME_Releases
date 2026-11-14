-- pathing.lua - the map model, the BFS route search and the walker.
--
-- Split out of Dung.lua, which keeps the main loop, the click/action helpers, the
-- puzzle rooms (puzzles.lua) and the boss strategies (bosses.lua). Everything that
-- answers a MAP question lives here: the world scan, room segmentation, the doorway
-- graph, the BFS over the client's own walk set, the "is this room / this door still
-- worth going to" rules, and the walker that follows the drawn route door by door.
--
-- Dung.lua installs it once, after the helpers it hands over are in scope:
--
--   local bindPathing = require("pathing")(D, API, S, H, X)
--   ...
--   bindPathing()        -- second pass, after every module is installed
--
--   D    the shared script table: all state, and every D.* entry point
--   API  the engine wrapper
--   S    dung_state, the per-floor state that outlives a rescan
--   H    helpers that stay in Dung.lua (log/say/ptile/pkey, click + action helpers)
--   X    the table the three sub-modules share their functions through
--
-- The puzzle functions used here are forward-declared and filled in by bind(): the
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
	-- solved in puzzles.lua - bound by bind(), see the header
	------------------------------------------------------------------
	local pondReset, pondskaters, puzzleDone, puzzleMarkSolved
	local function bind()
		pondReset = X.pondReset
		pondskaters = X.pondskaters
		puzzleDone = X.puzzleDone
		puzzleMarkSolved = X.puzzleMarkSolved
	end

--------------------------------------------------------------------
-- world model: rooms are the connected walkable areas. Doorway tiles are
-- Blocked, so every room is its own connected component - no walking needed.
--------------------------------------------------------------------

-- Type 99 walk tiles are only emitted within 50 tiles of the player
-- (MEX::GetAllWalkTiles / kWalkTileRadius) and that is smaller than a Daemonheim
-- floor: a single scan saw 2 rooms where the floor had 11 and never found the
-- boss door. The tiles are therefore kept for the whole floor and every scan
-- adds to them, so the room graph grows while the player explores instead of
-- forgetting every room left behind.
-- set by walkSet() the moment the player is in a different instance region, so
-- the caller can drop all per-floor state (pond puzzles, write-offs, targets)

local function floorReset()
	S.floorTiles, S.floorDoorTiles = {}, {}
	S.floorDirs = {}
	S.floorDoors = {}
	D.doorMemLog = nil
	D.shutSuspect = {}
	D.walkPruned = 0
	S.wallFaces, S.wallFaceLogged = 0, nil
	S.floorOrigin = nil
end

local function takeFloorChanged()
	if S.floorChanged then
		S.floorChanged = false
		return true
	end
	return false
end

local function walkSet()
	local px, py = ptile()
	if S.floorOrigin then
		-- the next floor is a different instance region entirely
		if math.abs(px - S.floorOrigin.x) > 200 or math.abs(py - S.floorOrigin.y) > 200 then
			floorReset()
			S.floorChanged = true
		end
	end
	if not S.floorOrigin then S.floorOrigin = { x = px, y = py } end
	-- NO PLANE FILTER HERE: the type 99 records carry z = 1 for tiles the player stands on
	-- at plane 0 (live: tile 14737,1245 z=1 while the player is at 14737,1245 z=0), so
	-- comparing them against API.PlayerCoord().z would drop every tile in the set.
	for _, o in ipairs(API.ReadAllObjectsArray({ 99 }, {}, {}) or {}) do
		local t = o.Tile_XYZ
		if t then
			local k = pkey(t.x, t.y)
			if o.Name == 'Walk' then
				S.floorTiles[k] = true
				-- ...and WHICH WAY the tile may be left. A type 99 record is the combined
				-- blocker of one tile, and Unique_Id carries the directions it may be
				-- walked out of (N=1 E=2 S=4 W=8, the wall cuts already removed). Without
				-- this the tile of a wall reads as plain floor: the search then steps
				-- THROUGH the wall face, which is how a barrel room's bits nine tiles
				-- away "had a path" over a one-tile wall while the client answered
				-- "You can't reach that" to every click (live: room 8609:449, the bits at
				-- 8620,455 seen as reachable from 8611,456 five times in a row).
				-- 0 is not a real mask on a walkable tile - fail open instead of walling
				-- the floor off if a record ever reports it.
				local m = math.floor(tonumber(o.Unique_Id) or 15) % 16
				if m == 0 then m = 15 end
				local prev = S.floorDirs[k]
				local mask = prev and D.dirAnd(prev, m) or m
				-- counted per TILE and only when it changes, so the one-off log below
				-- reports the room's wall sides instead of the number of scans
				if mask ~= 15 and mask ~= prev then S.wallFaces = (S.wallFaces or 0) + 1 end
				S.floorDirs[k] = mask
			elseif S.floorTiles[k] then
				-- THE CLIENT TOOK THE TILE BACK. This set only ever grew before: a tile seen
				-- as "Walk" once stayed walkable for the rest of the floor, so a wall that
				-- the client later reported as "Blocked" (a room loading its walls, a
				-- rebuilt wall in the collapsing room, a barrier coming back) was still a
				-- corridor to the BFS - and the route drew a straight line through it, which
				-- is the "somehow pathed through walls". Doorway tiles are unaffected: they
				-- are gates in D.walkBfs whether the tile is walkable or not.
				S.floorTiles[k] = nil
				S.floorDirs[k] = nil
				D.walkPruned = (D.walkPruned or 0) + 1
				if D.walkPruned <= 8 then
					log(string.format('walk tile %d,%d is "%s" in the client - pruned from the walk set (%d)',
						math.floor(t.x), math.floor(t.y), tostring(o.Name), D.walkPruned))
				end
			end
		end
	end
	if not S.wallFaceLogged and (S.wallFaces or 0) > 0 then
		S.wallFaceLogged = true
		log(string.format('walk set: %d tile(s) carry wall sides - the searches will not cross them',
			S.wallFaces))
	end
	return S.floorTiles
end

-- Segmented without the doorway tiles: once a door is unlocked its tile becomes
-- walkable and would fuse the two rooms it joins into one blob.
local function segmentSet()
	local s = {}
	for k in pairs(S.floorTiles) do
		if not S.floorDoorTiles[k] then s[k] = true end
	end
	return s
end

D.MIN_ROOM_TILES = 25

local function segment(walk)
	local rooms, seen = {}, {}
	for k in pairs(walk) do
		if not seen[k] then
			local sx, sy = k:match('^(%-?%d+):(%-?%d+)$')
			sx, sy = tonumber(sx), tonumber(sy)
			local queue = { { sx, sy } }
			seen[k] = true
			local tiles, set = {}, {}
			local minx, maxx, miny, maxy = sx, sx, sy, sy
			local head = 1
			while head <= #queue do
				local x, y = queue[head][1], queue[head][2]
				head = head + 1
				tiles[#tiles + 1] = { x, y }
				set[pkey(x, y)] = true
				if x < minx then minx = x end
				if x > maxx then maxx = x end
				if y < miny then miny = y end
				if y > maxy then maxy = y end
				local n = { { x + 1, y }, { x - 1, y }, { x, y + 1 }, { x, y - 1 } }
				for i = 1, 4 do
					local nk = pkey(n[i][1], n[i][2])
					if walk[nk] and not seen[nk] then
						seen[nk] = true
						queue[#queue + 1] = { n[i][1], n[i][2] }
					end
				end
			end
			if #tiles >= D.MIN_ROOM_TILES then
				rooms[#rooms + 1] = {
					idx = #rooms + 1, tiles = tiles, set = set,
					minx = minx, maxx = maxx, miny = miny, maxy = maxy,
					cx = math.floor((minx + maxx) / 2), cy = math.floor((miny + maxy) / 2),
				}
			end
		end
	end
	return rooms
end

-- Which room a tile belongs to (nil when it is a doorway / wall).
local function roomAt(rooms, x, y)
	for i = 1, #rooms do
		if rooms[i].set[pkey(x, y)] then return rooms[i] end
	end
	return nil
end

-- Room under the player, tolerating the doorway tiles. Doorway tiles are cut out
-- of the segmentation (an unlocked door turns walkable and would fuse both rooms),
-- so a player standing IN a doorway owns no tile at all - which used to log
-- "not standing in a recognised room" and stall the run right after opening a door.
local function roomNearRooms(rooms, x, y)
	local r = roomAt(rooms, x, y)
	if r then return r end
	for rad = 1, 3 do
		local best, bestD = nil, math.huge
		for dx = -rad, rad do
			for dy = -rad, rad do
				if math.abs(dx) == rad or math.abs(dy) == rad then
					local cand = roomAt(rooms, x + dx, y + dy)
					if cand then
						local d = dx * dx + dy * dy
						if d < bestD then bestD, best = d, cand end
					end
				end
			end
		end
		if best then return best end
	end
	return nil
end

-- Doorways are cut into the wall: there is often a blocked row between the door
-- tile and the floor, so a door belongs to a room when any of its tiles is
-- within two steps. Without this radius every door has no side, the room graph
-- has no edges and the bot stops after the first room.
D.DOOR_REACH = 2

-- Which rooms this doorway tile leads INTO, one per direction. A doorway sits in a
-- wall, so at most four rooms can be involved and each of them is straight out along
-- one axis - a box search over ±2 tiles also caught DIAGONAL rooms, so a door on a
-- wall corner claimed a room it does not touch and the route then walked at a wall
-- (live: "route step: door 50343 at 7280,2232 -> room 7265:2225" was not a doorway of
-- that room at all). Directional, up to two tiles out to allow the blocked row that
-- sometimes separates the doorway from the floor.
local function roomTouch(owner, x, y)
	local sides = {}
	local function add(idx)
		if not idx then return end
		for j = 1, #sides do
			if sides[j] == idx then return end
		end
		sides[#sides + 1] = idx
	end
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for i = 1, #dirs do
		for step = 1, 2 do
			local idx = owner[pkey(x + dirs[i][1] * step, y + dirs[i][2] * step)]
			if idx then
				add(idx)
				break
			end
		end
	end
	-- A CORNER DOORWAY HAS NO ROOM ON ANY AXIS. On a diagonal wall the floor either side of
	-- the leaf is diagonal from it, so the four axis probes all answer nil and the doorway
	-- ends up in no room at all: live, "door 50344 "Door" Enter at 7279,312 ... edge=0
	-- sides=0", which no plan can route to and no counter can call done. Only asked when the
	-- axis probes found nothing, so an ordinary doorway keeps the rooms it had.
	if #sides == 0 then
		local diag = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
		for i = 1, #diag do
			for step = 1, 2 do
				local idx = owner[pkey(x + diag[i][1] * step, y + diag[i][2] * step)]
				if idx then
					add(idx)
					break
				end
			end
		end
	end
	return sides
end

-- Same query, but keeping the DIRECTION each room was found in. A doorway joins the
-- rooms on OPPOSITE sides of its wall; joining any two rooms that happen to be near the
-- tile is what produced graph edges that do not exist, and routes that walked at walls.
local function roomSidesDir(owner, x, y)
	local out = {}
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for i = 1, #dirs do
		for step = 1, 2 do
			local idx = owner[pkey(x + dirs[i][1] * step, y + dirs[i][2] * step)]
			if idx then
				out[#out + 1] = { dir = dirs[i], room = idx }
				break
			end
		end
	end
	return out
end

-- The room(s) this doorway tile shares an edge with. Each leaf of a 2-tile
-- doorway touches exactly one room by edge, and that is the side it is clicked
-- from; the far leaf is physically behind the near one and cannot be reached.
local function edgeRooms(owner, x, y)
	local set = {}
	local r1 = owner[pkey(x, y - 1)]
	if r1 then set[r1] = true end
	local r2 = owner[pkey(x, y + 1)]
	if r2 then set[r2] = true end
	local r3 = owner[pkey(x - 1, y)]
	if r3 then set[r3] = true end
	local r4 = owner[pkey(x + 1, y)]
	if r4 then set[r4] = true end
	return set
end

-- Full scan: rooms with their contents, plus doorways with the rooms they join.
local function scanWorld()
	-- Phase timing, logged by getWorld for a scan that crossed its warn threshold:
	-- "it is slow" is useless without knowing WHICH pass costs the time.
	D.scanPhase = {}
	local pt = API.SystemTime()
	local function mark(what)
		local n = API.SystemTime()
		D.scanPhase[#D.scanPhase + 1] = string.format('%s %dms', what, n - pt)
		pt = n
	end
	walkSet()
	mark('walktiles')
	local seg = segmentSet()
	mark('segment-set')
	local tileCount = 0
	for _ in pairs(seg) do tileCount = tileCount + 1 end
	local rooms = segment(seg)
	mark(string.format('segment(%d tiles, %d rooms)', tileCount, #rooms))

	-- tile -> room index, so door/entity tests are O(1)
	local owner = {}
	for i = 1, #rooms do
		for k in pairs(rooms[i].set) do owner[k] = i end
	end

	-- startpathreach must stay -1 here. Anything other than -1 makes the DLL run
	-- an A* per entity, and this scan runs every iteration, so three reach
	-- filters were the entire reason combat crawled. The room/edge model below
	-- already restricts every candidate to the room the player stands in.
	--
	-- One call for every type. npcs are NOT in here: the room model is made of
	-- objects, and copying every npc into Lua on every pass bought nothing - no
	-- routing decision reads an npc any more. Anything that does want them (what is
	-- attacking us in this room, the boss, a construct, a monolith pillar) asks
	-- D.npcScan() for them, which is one cached read shared by all of those.
	local all = D.objScan(true)
	mark(string.format('objscan(%d objects)', #all))
	local objs, keys = {}, {}
	for _, o in ipairs(all) do
		if o.Type == 3 then
			if D.KEY_SET[o.Id] then keys[#keys + 1] = o end
		else
			objs[#objs + 1] = o
		end
	end

	local bar = {}
	for _, o in ipairs(objs) do
		if o.Id == D.BARRICADE then
			local t = o.Tile_XYZ
			bar[pkey(t.x, t.y)] = true
		end
	end

	local doors = {}
	for _, o in ipairs(objs) do
		local kind = D.doorKind[o.Id]
		local meta = D.doorMeta[o.Id]
		local nm = string.lower(o.Name or '')
		-- Name-matched doors first: "Guardian door" (and anything else added to
		-- D.DOOR_NAME_KINDS). Ids are only a fallback for doors called just "Door".
		local nameKind = D.DOOR_NAME_KINDS[nm]
		if nameKind then
			kind, meta = nameKind, nil
		end
		-- Key doors are recognised by NAME and nothing else: 64 keys share 384 door
		-- ids, the id swaps when a door unlocks (50266 "Unlock" -> 50411 "Enter"),
		-- and a variant missing from an id table made the door invisible. "Gold
		-- rectangle door" carries the colour and the shape, which is the whole
		-- key requirement, so there is no id fallback. The name must also say
		-- "door", or a "Gold crescent" statue would become a key door.
		local item = nil
		if string.find(nm, 'door', 1, true) then item = D.doorKeyFromName(o.Name) end
		if item then
			kind, meta = 'key', D.KEY_COLOR[item]
		end
		-- Skill doors: matched by NAME (D.SKILL_DOOR_NAMES, straight off the wiki's
		-- table). No ids - the same door has several model ids, and a missing id made
		-- the Augmented door invisible while the floor was declared finished with that
		-- doorway shut. The action check is only a second net.
		local skill = D.SKILL_DOOR_NAMES[nm]
		if not kind and skill then
			kind, meta = 'skill', skill
		elseif not kind and D.SKILL_ACTS[o.Action or '']
			and string.find(nm, 'door', 1, true) then
			kind, meta = 'skill', 'skill'
		end
		-- Bool1 == 1 / empty Action means the object offers no option at all: it does
		-- not exist as a door, so it must not exist in the model either. Shipping it
		-- in the map is what produced clicks on "There is no interaction on
		-- object!" and fake doorways in the worth/dead-end maths.
		if kind and D.interactable(o) then
			local t = o.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			doors[#doors + 1] = {
				id = o.Id, kind = kind, meta = meta, obj = o,
				name = o.Name,          -- plain string: Name off the userdata can throw
				action = o.Action, x = x, y = y,
				-- x/y are the floor()ed copies used for keying and logging; the
				-- FFPOINT is kept so distance checks do not have to rebuild it
				tile = t,
				dist = o.Distance,
				item = item,
				sides = roomTouch(owner, x, y),
				sideDirs = roomSidesDir(owner, x, y),
				-- rooms this leaf shares an EDGE with. A doorway is two tiles
				-- thick, so both leaves see both rooms within DOOR_REACH; only the
				-- edge room is on the side the leaf can actually be clicked from.
				edge = edgeRooms(owner, x, y),
				-- a barricade shares the doorway tile; such a door usually cannot
				-- be passed, so it is tried only as a last resort
				-- Informational only. "Barricade" (25636) is the Wall+Decor pair that
				-- sits on EVERY dungeon doorway, so it says nothing about whether a
				-- particular door can be opened - treating it as a blocker skipped
				-- every door in the room.
				sealed = bar[pkey(x, y)] or false,
			}
		end
	end

	-- The object scan hands back ONE object per tile, and a doorway tile can carry
	-- two: the decor leaf (a known door id) and an object that only counts as a door
	-- by its name. Live proof: tile 7264,2216 holds decor 50343 "Door" AND object
	-- 137190 "Door". Whichever of the two the scan picks decides whether that leaf
	-- exists in the model at all, and when it picks 137190 - an id in no table - the
	-- doorway looks single-leafed. The bot then has only the FAR leaf to click and
	-- every attempt is answered "You can't reach that". A "Door" one tile along the
	-- same axis as a known leaf is that leaf's partner, so it inherits its kind.
	local leafAt = {}
	for i = 1, #doors do leafAt[pkey(doors[i].x, doors[i].y)] = doors[i] end
	for _, o in ipairs(objs) do
		local t = o.Tile_XYZ
		local x, y = math.floor(t.x), math.floor(t.y)
		if not leafAt[pkey(x, y)] and D.interactable(o)
			and string.find(string.lower(o.Name or ''), 'door', 1, true)
			-- THE BOSS DOOR IS A MARKER, NOT A DOORWAY. It stands INSIDE the boss room, one
			-- tile from the doorway into it, so this "a Door next to a known leaf inherits its
			-- kind" rule adopted it as a key leaf: live 07:31:17, "doorway leaf 50352 "Boss
			-- door" at 14728,4688 adopted as key: its partner 50511 is at 14728,4687". It then
			-- counted as an unopened doorway for the rest of the floor ("50352 Enter at
			-- 14728,4688 item=18262 nevercrossed far key UNFINISHED"), which keeps the boss
			-- gate shut - the one doorway that can never be opened held the floor open for
			-- ever. It is collected separately as world.bossDoor.
			and not string.find(string.lower(o.Name or ''), D.BOSS_DOOR_NAME, 1, true) then
			local partner = leafAt[pkey(x - 1, y)] or leafAt[pkey(x + 1, y)]
				or leafAt[pkey(x, y - 1)] or leafAt[pkey(x, y + 1)]
			if partner then
				local rec = {
					id = o.Id, kind = partner.kind, meta = partner.meta, obj = o,
					name = o.Name, action = o.Action, x = x, y = y, tile = t,
					dist = o.Distance, item = partner.item,
					sides = roomTouch(owner, x, y),
					sideDirs = roomSidesDir(owner, x, y),
					edge = edgeRooms(owner, x, y),
					sealed = bar[pkey(x, y)] or false,
					partnerOf = pkey(partner.x, partner.y),
				}
				doors[#doors + 1] = rec
				leafAt[pkey(x, y)] = rec
				D.leafLog = D.leafLog or {}
				if not D.leafLog[pkey(x, y)] then
					D.leafLog[pkey(x, y)] = true
					log(string.format('doorway leaf %d "%s" at %d,%d adopted as %s: its partner %d is at %d,%d',
						o.Id, tostring(o.Name), x, y, tostring(partner.kind),
						partner.id, partner.x, partner.y))
				end
			end
		end
	end

	-- DOORWAYS SEEN EARLIER ON THIS FLOOR STAY IN THE MODEL. The client only streams objects
	-- within about 32 tiles, so a doorway discovered a minute ago drops out of world.doors
	-- the moment the player walks away: the route planner cannot target it any more,
	-- D.mapDoorsDone cannot count it, and the bot tours the floor instead of going back to
	-- the one doorway it has not opened. Live: the shut Guardian door at 8616,480 was
	-- "never detected" again once the player stood 35 tiles off, and no route ever led back.
	-- The remembered copy is PLANNING ONLY - tile, id, kind and the last action seen, with
	-- `memory` set so D.doorwayOpen never calls a stale "Enter" an open door. Clicks still
	-- come from the live scan (D.clickScanned) or from openDoor's id + tile fallback, and
	-- the room edges are re-derived here because room indices are rebuilt on every scan.
	S.floorDoors = S.floorDoors or {}
	local seenK = {}
	for i = 1, #doors do
		local rec = doors[i]
		rec.memory = nil
		S.floorDoors[pkey(rec.x, rec.y)] = rec
		seenK[pkey(rec.x, rec.y)] = true
	end
	local recalled = 0
	local rpx, rpy = ptile()
	-- A SKILL OBSTACLE THAT HAS BEEN USED UP IS NOT A DOORWAY ANY MORE. "Runed door"
	-- (Imbue-energy), "Wooden barricade", "Flammable debris" and the rest are obstacles
	-- standing IN FRONT of a doorway: using them DELETES the object, it never turns into an
	-- "Enter" leaf, and the way through is the ordinary Door leaf on the neighbouring tile.
	-- Keeping the dead leaf in the floor map made the route plan to it for the rest of the
	-- floor - live 06:50: "walk plan: door 50280 "Runed door" (Imbue-energy) at 14744,4705 is
	-- the end of the drawn route" AFTER "You successfully imbue the rune door with energy",
	-- then "not clicking object 50280 ... it is a ghost", then a ground walk to the tile to
	-- make the client load an object that no longer exists. Only judged CLOSE (the client
	-- streams objects around the player, so absence far away means nothing) and only for a
	-- skill leaf that is missing while its partner leaf is live.
	D.skillMiss = D.skillMiss or {}
	for k, rec in pairs(S.floorDoors) do
		if seenK[k] then
			D.skillMiss[k] = nil
		elseif rec.x and rec.y then
			local near = math.max(math.abs(rec.x - rpx), math.abs(rec.y - rpy)) <= D.SKILL_GONE_NEAR
			local gone = false
			-- (1) ITS TILE IS PLAIN FLOOR NOW, so nothing stands there any more. Every doorway
			-- tile in this dungeon stays Blocked even when the door is open - that is why the
			-- walk set cannot be used to call a door open - so a doorway tile that reads
			-- "Walk" means the leaf OBJECT is gone, not open. Live 07:13: after the blue
			-- triangle door was unlocked, the front (Unlock) leaf 50240 at 14750,4696 vanished
			-- and that tile became Walk/dirs 13, while the passage came back on 14751,4696
			-- (50513 Enter) and 14752,4696 (50344 Enter). Keeping the vanished leaf in the
			-- floor map made it a memory door for ever - and D.doorwayOpen always answers
			-- "shut" for a memory door, so it counts as unfinished, keeps the boss gate
			-- closed and pulls the route back to a leaf that does not exist.
			if near and S.floorTiles[k] then gone = true end
			if not gone and near and rec.kind == 'skill' then
				local partnerLive = false
				for i = 1, #doors do
					local o = doors[i]
					if not o.memory and math.abs(o.x - rec.x) <= 1 and math.abs(o.y - rec.y) <= 1
						and (o.action == 'Enter' or o.action == 'Open') then
						partnerLive = true
						break
					end
				end
				local worked = D.skillWorked and D.skillWorked[k]
				local workedLongAgo = worked and (API.SystemTime() - worked) > D.SKILL_GONE_MS
				if workedLongAgo or partnerLive then
					D.skillMiss[k] = (D.skillMiss[k] or 0) + 1
					-- two scans, or one after we really worked it: a single streaming gap must
					-- never delete a doorway that is still there
					if (workedLongAgo and D.skillMiss[k] >= 1) or D.skillMiss[k] >= 2 then
						gone = true
					end
				end
			end
			if gone then
				S.floorDoors[k] = nil
				D.skillMiss[k] = nil
				-- the tile is ordinary floor now: let the segmentation use it, or the two
				-- rooms stay split around a doorway that no longer stands there
				S.floorDoorTiles[k] = nil
				-- ONLY THIS LEAF IS DONE - NOT THE DOORWAY BEHIND IT. Using a skill obstacle
				-- deletes the obstacle, and unlocking a key door replaces its Unlock leaf; in
				-- both cases the REAL doorway is what the client streams next (live:
				-- 50513 at 14751,4696 and 50344 at 14752,4696). Marking the neighbouring leaf
				-- traversed, or merely "used just now", said we had already walked through a
				-- doorway we had never entered, so it was never opened and never crossed.
				D.traversed[dkey(rec)] = true
				if D.skillWorked then D.skillWorked[k] = nil end
				D.dirty = true
				D.skillGoneLog = D.skillGoneLog or {}
				if not D.skillGoneLog[k] then
					D.skillGoneLog[k] = true
					log(string.format(
						'door leaf %d "%s" at %d,%d is gone from the client (%s) - dropping it from the floor plan',
						rec.id, tostring(rec.name), rec.x, rec.y,
						S.floorTiles[k] and 'its tile is plain floor now' or 'used up'))
				end
			end
		end
	end
	for k, rec in pairs(S.floorDoors) do
		if not seenK[k] then
			rec.memory = true
			rec.obj = nil        -- the userdata behind that old scan is long gone
			rec.sides = roomTouch(owner, rec.x, rec.y)
			rec.edge = edgeRooms(owner, rec.x, rec.y)
			-- the stored distance is from wherever we stood a minute ago; several selectors
			-- rank doorways by it, so it has to be measured from HERE
			rec.dist = math.sqrt((rec.x - rpx) ^ 2 + (rec.y - rpy) ^ 2)
			doors[#doors + 1] = rec
			seenK[k] = true
			recalled = recalled + 1
		end
	end
	if recalled > 0 then
		D.doorMemLog = D.doorMemLog or {}
		local nowMs = API.SystemTime()
		if not D.doorMemLog.at or (nowMs - D.doorMemLog.at) > 60000 then
			D.doorMemLog.at = nowMs
			log(string.format(
				'floor map: %d doorway(s) seen earlier are out of streaming range - kept in the plan',
				recalled))
		end
	end

	-- A DOORWAY THAT BELONGS TO NO ROOM IS INVISIBLE TO EVERY ROOM-BASED RULE. It stands in
	-- the model (so it shows in the dump) but no room lists it, no graph edge exists and no
	-- route can end on it - which from outside reads as "the global never finds this leaf".
	-- Say so, once per tile per floor, and name the nearest mapped floor so the cause is
	-- obvious: a floor map that does not cover that area yet is a different problem from a
	-- doorway with two rooms.
	do
		local orphan = 0
		for i = 1, #doors do
			local d = doors[i]
			if not d.memory and next(d.sides) == nil then
				orphan = orphan + 1
				D.orphanLog = D.orphanLog or {}
				local ok = D.orphanLog[pkey(d.x, d.y)]
				if not ok then
					D.orphanLog[pkey(d.x, d.y)] = true
					-- nearest owned tile, for the message only
					local bestD, bestIdx = math.huge, nil
					for r = 1, 6 do
						for dx = -r, r do
							for dy = -r, r do
								local idx = owner[pkey(d.x + dx, d.y + dy)]
								if idx then
									local dd = math.max(math.abs(dx), math.abs(dy))
									if dd < bestD then bestD, bestIdx = dd, idx end
								end
							end
						end
						if bestIdx then break end
					end
					log(string.format(
						'door %d "%s" at %d,%d is in NO room of the floor map (%s) - it stays in the plan but cannot be routed to until the floor around it is mapped',
						d.id, tostring(d.name), d.x, d.y,
						bestIdx and string.format('nearest room %d:%d is %d tile(s) away',
							rooms[bestIdx].minx, rooms[bestIdx].miny, bestD)
							or 'no floor mapped within 6 tiles'))
				end
			end
		end
		if orphan > 0 then D.orphanCount = orphan end
	end

	for i = 1, #rooms do rooms[i].enemies, rooms[i].keys, rooms[i].doors = {}, {}, {} end
	mark(string.format('doors(%d leaves)', #doors))

	-- Doorway reachability, asked of the CLIENT'S OWN WALK SET in pure Lua instead of
	-- by the engine. startpathreach = 1 runs a client A* per object, and the timing
	-- said exactly what that cost: "door-reach 1289ms" of a 1300ms scan, every pass.
	-- One BFS from the player answers every doorway at once, and it is the answer the
	-- script actually acts on (tryOpen refuses on D.doorWalkReach, not on this flag).
	-- Doorways beyond D.DOOR_TEST_DIST stay `reach = nil` ("not judged"), which is what
	-- doorReachable expects for a door in another room.
	if #doors > 0 then
		local px, py = ptile()
		local seen, q, head = { [pkey(px, py)] = true }, { { px, py } }, 1
		local tolNear = {}
		if S.floorTiles[pkey(px, py)] then
			-- 4-way BFS over the walkable floor, recording every tile reached
			while head <= #q do
				local cur = q[head]
				head = head + 1
				local ck = pkey(cur[1], cur[2])
				for i = 1, 4 do
					local nx, ny = cur[1] + D.DIR4[i][1], cur[2] + D.DIR4[i][2]
					local k = pkey(nx, ny)
					if not seen[k] and S.floorTiles[k] and D.wallOpen(ck, k, i) then
						seen[k] = true
						q[#q + 1] = { nx, ny }
					end
				end
			end
			-- a doorway counts as reachable when the tile BESIDE it is reachable: the
			-- leaf itself is a blocked tile, so tolerance 1 is the whole test
			for k in pairs(seen) do
				local x, y = k:match('^(%-?%d+):(%-?%d+)$')
				x, y = tonumber(x), tonumber(y)
				for dx = -1, 1 do
					for dy = -1, 1 do tolNear[pkey(x + dx, y + dy)] = true end
				end
			end
		end
		for i = 1, #doors do
			local d = doors[i]
			if math.abs(d.x - px) <= D.DOOR_TEST_DIST and math.abs(d.y - py) <= D.DOOR_TEST_DIST then
				-- no walk set at all means the map is not built: do not judge (nil).
				-- A false verdict has to be assigned explicitly - "false or nil" is nil,
				-- which would make every doorway read "not judged".
				if next(tolNear) then
					d.reach = tolNear[pkey(d.x, d.y)] == true
				end
			end
		end
	end
	mark('door-reach')

	-- npcs are not part of this scan (see the type list above): r.enemies stays
	-- empty and the pillar is looked up on demand by D.monoPillar, which reads the
	-- shared D.npcScan() list only in a room that actually needs it.
	for _, k in ipairs(keys) do
		local t = k.Tile_XYZ
		local idx = owner[pkey(t.x, t.y)]
		if idx then
			local r = rooms[idx]
			r.keys[#r.keys + 1] = k
		end
	end
	for _, d in ipairs(doors) do
		-- only the leaf a room shares an edge with may be listed for that room
		for side in pairs(d.edge) do
			local r = rooms[side]
			if r then r.doors[#r.doors + 1] = d end
		end
	end

	-- keep the doorway tiles for the rest of the floor: an unlocked doorway turns
	-- walkable, and segmenting through it would merge both rooms
	for _, d in ipairs(doors) do S.floorDoorTiles[pkey(d.x, d.y)] = true end

	-- Which room holds the boss. The npc itself is not loaded until the player is
	-- close, so the map markers are used first: the carcass inside the behemoth's
	-- room and the boss door (a type 12 decor with "boss door" in its name).
	-- The dungeon can hold several objects with that name, so the door is chosen
	-- by proximity to the boss anchor rather than by scan order - picking the
	-- first one aimed the bot at a door on the far side of the map.
	local bossRooms = {}
	for _, o in ipairs(objs) do
		if string.find(string.lower(o.Name or ''), D.BOSS_DOOR_NAME, 1, true) then
			local t = o.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			bossRooms[#bossRooms + 1] = {
				id = o.Id, obj = o, name = o.Name, action = o.Action, x = x, y = y,
				dist = o.Distance,
				sides = roomTouch(owner, x, y),   -- both sides of the entrance
				edge = edgeRooms(owner, x, y),
			}
		end
	end

	-- The boss door is a single decor standing INSIDE the boss room, so the room it
	-- stands in is the boss room - no need to guess which side of it we want. That
	-- also means the boss room is entered through an ordinary doorway; the boss
	-- door itself is only the marker.
	local bossRoom = nil
	local anchorX, anchorY = nil, nil
	-- entities sit ON their own tile and are solid (the carcass tile is Blocked in
	-- the live client), so the nearest owned tile is used instead of the entity's
	local function roomNear(x, y, maxR)
		for r = 0, maxR or 4 do
			for dx = -r, r do
				for dy = -r, r do
					if math.abs(dx) == r or math.abs(dy) == r then
						local idx = owner[pkey(x + dx, y + dy)]
						if idx then return idx end
					end
				end
			end
		end
		return nil
	end

	for _, bd in ipairs(bossRooms) do
		bossRoom = roomNear(bd.x, bd.y)
		if bossRoom then break end
	end
	if not bossRoom then
		-- no boss door drawn: the only other way to place the boss room is the boss
		-- npc itself, so this is the one place the world model asks for npcs, and
		-- D.npcScan caches the read for everything else that needs it.
		for _, n in ipairs(D.npcScan()) do
			if D.BOSSES[D.bossKey(n.Name)] then
				local t = n.Tile_XYZ
				anchorX, anchorY = math.floor(t.x), math.floor(t.y)
				bossRoom = roomNear(anchorX, anchorY)
				if bossRoom then break end
			end
		end
	end
	if not bossRoom then
		for _, o in ipairs(objs) do
			if string.find(string.lower(o.Name or ''), D.CARCASS_NAME, 1, true) then
				local t = o.Tile_XYZ
				anchorX, anchorY = math.floor(t.x), math.floor(t.y)
				bossRoom = roomNear(anchorX, anchorY)
				if bossRoom then break end
			end
		end
	end

	-- keep the boss door nearest the boss anchor (npc/carcass); with no anchor,
	-- the first one found is as good as any
	local bossDoor = bossRooms[1] or nil
	if anchorX and #bossRooms > 1 then
		local best = math.huge
		for _, bd in ipairs(bossRooms) do
			local d = (bd.x - anchorX) ^ 2 + (bd.y - anchorY) ^ 2
			if d < best then best, bossDoor = d, bd end
		end
	end
	if bossDoor then
		bossDoor.index = 1
		-- Remembered for the floor: the marker streams in and out with the region, and
		-- a single scan without it made the bot forget the boss entrance and unlock
		-- that very door (live: door 50260 at 14945,1432 one tile from the marker at
		-- 14943,1432, unlocked and walked through with the floor unfinished). Once seen,
		-- it stays known until the ladder resets the floor.
		D.bossDoorTile = { x = bossDoor.x, y = bossDoor.y }
	end

	-- A walkable tile inside the boss room, used as a stable anchor. Room indices
	-- are rebuilt on every scan and their order is not stable, so storing an index
	-- made the bot think it had arrived after a single doorway.
	local bossAnchor = nil
	if bossRoom and rooms[bossRoom] then
		local tiles = {}
		for k in pairs(rooms[bossRoom].set) do tiles[#tiles + 1] = k end
		table.sort(tiles)
		local tx, ty = tiles[1]:match('^(%-?%d+):(%-?%d+)$')
		if tx then bossAnchor = { x = tonumber(tx), y = tonumber(ty) } end
	end

	-- pathing uses every walkable tile known for the floor (a tile only becomes
	-- walkable once the door in it is unlocked), rooms use the doorway-free set
	return { rooms = rooms, doors = doors, walk = S.floorTiles, objs = objs,
		tileCount = tileCount,
		bossRoom = bossRoom, bossDoor = bossDoor, bossAnchor = bossAnchor }
end

--------------------------------------------------------------------
-- room graph: two rooms are linked when a doorway joins them
--------------------------------------------------------------------

local function buildGraph(world, held, unknown)
	local rooms = world.rooms
	local adj = {}
	for i = 1, #rooms do adj[i] = {} end

	local function link(a, b, door)
		if a == b then return end
		for _, e in ipairs(adj[a]) do
			-- ONE EDGE PER DOORWAY, not one per leaf. The pair-union below adds both leaves of
			-- a doorway, and two leaves one tile apart are the SAME passage - keeping both put
			-- two identical edges between the same rooms and let findHop pick whichever leaf
			-- the scan happened to list first. Two doorways that are more than a tile apart
			-- are parallel passages and both stay.
			if e.room == b and (e.door == door
				or (e.door and door
					and math.abs(e.door.x - door.x) <= 1
					and math.abs(e.door.y - door.y) <= 1)) then return end
		end
		adj[a][#adj[a] + 1] = { room = b, door = door }
	end

	-- A leaf is entered from the room it shares an edge with and leads to the
	-- room beyond. Each leaf therefore contributes exactly one direction, and the
	-- two leaves of a doorway give the edge both ways without any tile guessing.
	for _, d in ipairs(world.doors) do
		local dirs = d.sideDirs
		local linked = false
		-- A doorway joins the rooms on OPPOSITE sides of its wall. Joining any two
		-- rooms found near the tile created graph edges that do not exist, so the route
		-- planned through a doorway that leads nowhere and the click hit a wall.
		if dirs then
			for i = 1, #dirs do
				for j = i + 1, #dirs do
					local a, b = dirs[i], dirs[j]
					if a.dir[1] == -b.dir[1] and a.dir[2] == -b.dir[2] and a.room ~= b.room then
						link(a.room, b.room, d)
						link(b.room, a.room, d)
						linked = true
					end
				end
			end
		end
		if not linked then
			for from in pairs(d.edge) do
				for _, to in ipairs(d.sides) do
					if to ~= from then link(from, to, d) end
				end
			end
		end
	end
	-- A DOORWAY IS ONE PASSAGE, NOT TWO RECORDS. Each leaf brings its own idea of the
	-- rooms beside it, and the two can disagree: live, the opened key doorway
	-- 50221/50494 at 7262,264 carried sides=1 edge=1 on its Unlock leaf and sides=2
	-- edge=0 on its Enter leaf, so NEITHER leaf produced an edge and the room behind it
	-- was unroutable. The bot then reported "key 18218 is in room 7265:257 but nothing we
	-- can open leads there yet" and, one pass later, "no key on the floor" - with the key
	-- lying 8 tiles behind a door it had opened itself. Union the rooms the two leaves
	-- name and link them both ways, using the leaf that can actually be clicked.
	local function roomsOf(d)
		local out = {}
		for _, s in ipairs(d.sides or {}) do if s then out[s] = true end end
		for s in pairs(d.edge or {}) do out[s] = true end
		return out
	end
	for i = 1, #world.doors do
		local a = world.doors[i]
		if a.kind ~= 'boss' then
			for j = i + 1, #world.doors do
				local b = world.doors[j]
				if b.kind ~= 'boss'
					and math.abs(a.x - b.x) <= 1 and math.abs(a.y - b.y) <= 1 then
					local ra, rb = roomsOf(a), roomsOf(b)
					-- BOTH leaves become edges. Which one can be clicked depends on the key
					-- state - the Unlock leaf while we hold the key, the Enter leaf once the
					-- door is open and the key is spent - and the graph has no business
					-- guessing: every consumer filters its edges with doorClickable.
					for x in pairs(ra) do
						for y in pairs(rb) do
							if x ~= y then
								link(x, y, a) link(y, x, a)
								link(x, y, b) link(y, x, b)
							end
						end
					end
				end
			end
		end
	end
	-- A SINGLE-LEAF DOORWAY WITH TWO ROOMS IS STILL A PASSAGE. The loop above needs the
	-- partner leaf, and a corner or thick-wall doorway very often streams only one of them:
	-- live, "door 50344 "Door" Enter at 7279,312 ... edge=0 sides=0/1" - one leaf, no edge
	-- rooms, and therefore no edge in the graph, so the doorway stood in the floor map and no
	-- route could ever reach it. When a lone leaf names exactly two rooms, those two rooms are
	-- the two sides of the wall it sits in. Three or more is left alone - that is a junction,
	-- and a wrong edge walks the player at a wall.
	for i = 1, #world.doors do
		local d = world.doors[i]
		if d.kind ~= 'boss' then
			local partner = false
			for j = 1, #world.doors do
				local o = world.doors[j]
				if o ~= d and math.abs(o.x - d.x) <= 1 and math.abs(o.y - d.y) <= 1 then
					partner = true
					break
				end
			end
			local sides = d.sides or {}
			if not partner and #sides == 2 and sides[1] ~= sides[2] then
				link(sides[1], sides[2], d)
				link(sides[2], sides[1], d)
				D.singleLeafLog = D.singleLeafLog or {}
				local sk = dkey(d)
				if not D.singleLeafLog[sk] then
					D.singleLeafLog[sk] = true
					log(string.format(
						'door %d "%s" at %d,%d is the only leaf in the scan: linking its two rooms %d and %d so it can be routed to',
						d.id, tostring(d.name), d.x, d.y, sides[1], sides[2]))
				end
			end
		end
	end
	return adj
end

-- Rooms holding nothing worth the walk: no living enemy, no ground key, and no
-- door that opens onto a room still outstanding. Everything this needs is already
-- in the scan, so a room can be judged from a distance - the player only has to
-- be somewhere to actually solve it. The room we are standing in is ignored,
-- otherwise the doorway we just came through would keep every room alive.
-- A key door is only worth a trip when its key exists on this floor at all -
-- either already held or lying on the floor where the map can see it. Otherwise
-- the door can never open and exploring towards it is wasted time.
local function keyObtainable(world, item, held)
	if not item then return false end
	if held[item] then return true end
	for i = 1, #world.rooms do
		for _, k in ipairs(world.rooms[i].keys) do
			if k.Id == item then return true end
		end
	end
	return false
end

-- Is this doorway physically approachable from inside room `r`? The whole floor
-- map is known (walk tiles are kept for the floor), so this needs no visit: a
-- doorway whose four neighbours are all outside the room belongs to another part
-- of the map, whatever list it ended up in.
D.DIR4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- The engine's wall bits, in the same order as D.DIR4 (N=1 E=2 S=4 W=8, y grows
-- north). DIR4_BIT is the side of the tile a step LEAVES through; DIR4_OPP is the
-- same side as seen from the tile it ENTERS - that is the one the other tile's own
-- mask has to allow.
D.DIR4_BIT = { 2, 8, 1, 4 }
D.DIR4_OPP = { 8, 2, 4, 1 }
-- Honour the per-tile wall sides in the shared search. Lua 5.1 has no bitwise
-- operators here, so both helpers are arithmetic.
D.WALL_FACES = true

function D.dirBit(v, bit)
	return math.floor((v or 0) / bit) % 2 == 1
end

-- Strictest of two masks: a tile claimed by several type 99 records is only open
-- where EVERY record agrees it is.
function D.dirAnd(a, b)
	local out = 0
	if D.dirBit(a, 1) and D.dirBit(b, 1) then out = out + 1 end
	if D.dirBit(a, 2) and D.dirBit(b, 2) then out = out + 2 end
	if D.dirBit(a, 4) and D.dirBit(b, 4) then out = out + 4 end
	if D.dirBit(a, 8) and D.dirBit(b, 8) then out = out + 8 end
	return out
end

-- May a step from tile `fk` to tile `tk` be taken in direction `i` (a D.DIR4 index)?
-- Both tiles have to allow their own side of the shared edge. A tile with no mask -
-- a doorway leaf, a floor the scan has not covered yet - counts as open: a missing
-- record must never wall the floor off.
function D.wallOpen(fk, tk, i)
	if not D.WALL_FACES then return true end
	local dirs = S.floorDirs
	if not dirs then return true end
	local fm, tm = dirs[fk], dirs[tk]
	if not fm or not tm then return true end
	return D.dirBit(fm, D.DIR4_BIT[i]) and D.dirBit(tm, D.DIR4_OPP[i])
end

local function doorInRoom(r, d)
	if not r or not r.set then return true end
	for _, n in ipairs(D.DIR4) do
		if r.set[pkey(d.x + n[1], d.y + n[2])] then return true end
	end
	return false
end

-- Reachability of a door from where we stand: the client path-tests the door
-- object itself. A doorway tile is blocked collision, which was the reason this
-- used to be asked about the neighbours - the engine already knows how to answer
-- for a clickable object, so the object is what gets asked.
D.DOOR_CUTOFF_TTL = 6000   -- a rejection is re-tested later: things get unblocked
-- Daemonheim rooms are 16x16, so a doorway more than a room away cannot be part of
-- the decision being made right now. Asking the client for a path across the whole
-- floor, for every door, every iteration, is what produced the wall of "cannot be
-- reached from here" lines. Past this range the answer comes from memory only.
D.DOOR_TEST_DIST = 20
-- A doorway further than this is not "in the room we are standing in", whatever the
-- door/room edge model says: 13x13 walkable, 14x14 with the inner walls, so 13 is the
-- furthest a doorway of this room can be - and a merged room otherwise turns every
-- doorway on the floor into a candidate for "the nearest door of this room".
D.ROOM_DOOR_DIST = 14
-- Is this doorway physically inside the room the player is standing in? Measured
-- Chebyshev (tiles along the worse axis), not straight-line: a doorway in the far
-- corner of OUR room is 13 tiles on each axis, so 18 by Euclid and would be thrown
-- away, while a doorway of the next room is never within 13 in both axes. This is the
-- one rule for "can the local room plan touch it" - the router owns everything else.
function D.doorInMyRoom(d)
	if not d or not d.x then return false end
	local px, py = ptile()
	return math.max(math.abs(d.x - px), math.abs(d.y - py)) <= D.ROOM_DOOR_DIST
end

-- A DOORWAY IS IN THIS ROOM ONLY IF WE CAN WALK TO IT INSIDE THE ROOM'S OWN TILES.
-- Chebyshev distance cannot tell a doorway of this room from one across a wall in the next
-- room: live, a Guardian door at 15696,1080 was 12,11 tiles away - well inside
-- D.ROOM_DOOR_DIST - reported "door in this room", clicked through the wall, and stayed
-- shut. The room's tile set knows the difference: a breadcrumb search over it costs a room
-- (~170 tiles) and answers exactly the question, "is that doorway on this side of the wall".
-- Returns true when it cannot judge (no tile set, or the player is standing off the room),
-- so nothing that used to work is blocked by a missing map.
function D.doorReachableInRoom(here, d)
	if not here or not here.set or not d or not d.x then return true end
	local set = here.set
	if not here._num then
		local n = {}
		for k in pairs(set) do
			local sx, sy = k:match('^(%-?%d+):(%-?%d+)$')
			if sx then n[tonumber(sx) * 65536 + tonumber(sy)] = true end
		end
		here._num = n
	end
	local num = here._num
	local px, py = ptile()
	local start = px * 65536 + py
	if not num[start] then return true end
	local goals = {}
	for _, n in ipairs(D.DIR4) do
		goals[(d.x + n[1]) * 65536 + (d.y + n[2])] = true
	end
	local seen, queue, head = { [start] = true }, { start }, 1
	while head <= #queue and head <= 900 do
		local cur = queue[head]
		head = head + 1
		if goals[cur] then return true end
		local cx, cy = math.floor(cur / 65536), cur % 65536
		for _, n in ipairs(D.DIR4) do
			local nk = (cx + n[1]) * 65536 + (cy + n[2])
			if num[nk] and not seen[nk] then
				seen[nk] = true
				queue[#queue + 1] = nk
			end
		end
	end
	return false
end

-- Is this tile inside the room the player is standing in? Same rule as D.doorInMyRoom
-- plus the room's own rectangle, with a little slack because the props of a puzzle room
-- stand against the wall, outside the walkable rect. Used by the room solvers before
-- they touch anything: a puzzle room's objects are the whole floor's objects as far as
-- the scan is concerned, and the construct room is the case that hurt - the solver
-- found a Damaged construct 30 tiles away and started taking stones for it.
function D.tileInHere(here, x, y, slack)
	if not here or not x or not y then return false end
	x, y = math.floor(x), math.floor(y)
	local s = slack or 0
	local px, py = ptile()
	if math.max(math.abs(x - px), math.abs(y - py)) > D.ROOM_DOOR_DIST + s then
		return false
	end
	return x >= here.minx - s and x <= here.maxx + s
		and y >= here.miny - s and y <= here.maxy + s
end
local function doorReachable(d)
	local k = dkey(d)
	-- The scan already asked the engine about EVERY doorway in one pass, with
	-- startpathreach = 1 ("path ends within one tile of the object"). That is the
	-- cheap, authoritative answer - no per-door scan is needed when it exists.
	if d and d.reach then
		D.reachSeen = D.reachSeen or {}
		D.reachSeen[k] = true
		return true
	end
	-- Both answers are honoured from the cache before the client is asked.
	if D.reachSeen and D.reachSeen[k] then return true end
	local cut = S.doorCutOff[k]
	if cut and API.SystemTime() - cut < D.DOOR_CUTOFF_TTL then return false end
	if d and d.reach == false then
		-- The scan's own verdict, but it is a BATCH answer taken at scan time with
		-- startpathreach = 1 on the object: a doorway whose tile is blocked (every
		-- doorway is, and a skill doorway keeps its blocked leaf) answers false even
		-- when we could walk right up to it. Live example: the Augmented door was
		-- disassembled, the doorway it became (leaf 50343 at 7263,2216) came back
		-- "unreachable", and the barred door and guardian door behind it became
		-- unreachable with it - the bot bounced between the two rooms it still had.
		-- StarPath at tolerance 1 asks the same question NOW ("can I path within one
		-- tile of it"), which is exactly what clicking a doorway needs.
		if D.tileReachable(d.x, d.y, (d.obj and d.obj.Tile_XYZ and d.obj.Tile_XYZ.z) or 0, 1) then
			D.reachSeen = D.reachSeen or {}
			D.reachSeen[k] = true
			S.doorCutOff[k] = nil
			return true
		end
	else
		-- o.Distance is already the player-to-entity distance the scan reports, so
		-- the range gate needs no extra maths.
		if d and d.dist and d.dist > D.DOOR_TEST_DIST then
			-- nil = not judged (too far to matter), not "unreachable"
			return nil
		end
		if entityReachable(d.obj and d.obj.Type, d.id, d.x, d.y) then
			-- remembered for the floor: "is it done?" must not flip as the bot walks
			-- between rooms, or the floor-complete counter resets on every lap
			D.reachSeen = D.reachSeen or {}
			D.reachSeen[k] = true
			return true
		end
	end
	-- The rejection expires and is retested (things get unblocked), but the log
	-- line is worth exactly once per door: a merged room repeatedly rejects the
	-- same eight far doorways and buried the dump in identical lines.
	if not S.doorQuiet[dkey(d)] then
		S.doorQuiet[dkey(d)] = true
		-- tostring: doorReachable is also asked about the boss-door marker, which is
		-- a decor record rather than a scanned doorway and can lack fields
		log(string.format('door %s at %s,%s cannot be reached from here - ignoring it',
			tostring(d.id), tostring(d.x), tostring(d.y)))
	end
	S.doorCutOff[dkey(d)] = API.SystemTime()
	return false
end

-- Can this doorway be clicked from where we stand right now? Being next to it is
-- proof by itself (the cached verdict may be from the other side of it); otherwise
-- the engine's path test decides. Routing hops are clicked directly, so they must
-- pass this - a hop the client cannot path to lands nothing and repeats forever.
function D.doorClickableNow(d)
	if not d then return false end
	local px, py = ptile()
	if math.abs(px - d.x) <= 2 and math.abs(py - d.y) <= 2 then return true end
	local r = doorReachable(d)
	if r ~= nil then return r end
	-- The batched scan only path-tests doorways around the player, so a far one is
	-- "not judged" (nil). Ask the engine about this single door before clicking it:
	-- one path find at the moment of use instead of one per door per pass.
	return entityReachable(d.obj and d.obj.Type, d.id, d.x, d.y)
end

-- Is there floor we can actually walk to within `tol` tiles of this doorway? The
-- answer comes from D.walkBfs - the same search the walk display draws - so the
-- green dots and the click decision can never disagree.
function D.doorWalkReach(d, tol, world)
	if not d then return false, 'no door' end
	tol = tol or 1
	local px, py = ptile()
	if math.max(math.abs(px - d.x), math.abs(py - d.y)) <= tol then return true, 'next to it' end
	local bfs = D.walkBfs(world)
	if not bfs then return true, 'no walk map' end
	if D.walkReach(bfs, d.x, d.y, tol) then
		return true, string.format('path from %d,%d (%d tiles walked)', px, py, #bfs.order)
	end
	-- CANNOT JUDGE IS NOT A REFUSAL. The walk set only covers floor the client has streamed
	-- around the player during this floor, so a target in an area it has never seen answers
	-- "not reached" for the trivial reason that nothing there is mapped. Refusing on that
	-- would lock the bot out of every unexplored part of the floor - the exact failure that
	-- made "starved of doors" runs give up with doorways still standing. Only refuse when the
	-- area around the target IS mapped and still cannot be reached from here: that is real
	-- evidence of a wall, an unopened door or a separate room.
	if not D.areaMapped(bfs, d.x, d.y, D.REACH_SLACK) then
		return true, string.format('the walk set does not cover %d,%d yet (%d tiles walked)', d.x, d.y, #bfs.order)
	end
	return false, string.format('%d tiles walked, none within %d of it', #bfs.order, tol)
end

-- IS THE FLOOR AROUND (x,y) IN THE WALK SET AT ALL? The walk set is terrain the client has
-- streamed around the player during this floor, so "not reachable" only means something
-- when the ground around the target is mapped. Without this test every target in an area
-- the bot has not walked yet answers "no path" and gets refused for the wrong reason.
D.REACH_SLACK = 3
function D.areaMapped(bfs, x, y, rad)
	if not (bfs and bfs.walk and x and y) then return false end
	rad = rad or D.REACH_SLACK
	local fx, fy = math.floor(x), math.floor(y)
	for dx = -rad, rad do
		for dy = -rad, rad do
			if bfs.walk[pkey(fx + dx, fy + dy)] then return true end
		end
	end
	return false
end

-- MAY THIS OBJECT BE CLICKED FROM WHERE WE STAND? One question, asked by EVERY click on an
-- object, so a door, a skill obstacle, a puzzle prop or a chest can never be clicked through
-- a wall: live, "Drain" on a divine door was dispatched through a wall, and the only reach
-- tests in the script lived inside openDoor (doors only) and behind a "gap > 2" gate that
-- let a door two tiles away across a wall through.
-- The order is cheapest-first and each step can only make the answer MORE permissive, so
-- this cannot lock the bot out of something it can really reach:
--   1. standing on or beside it            -> allowed, no proof needed
--   2. the client's walk set reaches it    -> allowed
--   3. the walk set does not cover it yet  -> allowed (nothing to judge on)
--   4. StarPath can path to it             -> allowed
--   5. otherwise                           -> refused, with the reason
function D.objectReachOK(x, y, z)
	if not (x and y) then return true, 'no tile' end
	local fx, fy = math.floor(x), math.floor(y)
	local px, py = ptile()
	if math.max(math.abs(fx - px), math.abs(fy - py)) <= 1 then return true, 'standing beside it' end
	local bfs = nil
	local okBfs, res = pcall(function() return D.walkBfs(S.worldCache) end)
	if okBfs then bfs = res end
	if bfs and D.walkReach(bfs, fx, fy, 1) then return true, 'walk set reaches it' end
	if not (bfs and D.areaMapped(bfs, fx, fy, D.REACH_SLACK)) then
		-- nothing mapped around it: the client's own path finder is the only answer there is
		if D.tileReachable(fx, fy, z or 0, 1) then return true, 'StarPath reaches it' end
		return true, 'the walk set does not cover it yet'
	end
	if D.tileReachable(fx, fy, z or 0, 1) then return true, 'StarPath reaches it' end
	return false, 'the mapped floor around it cannot be reached from here'
end

-- A doorway whose click was refused because the client cannot path to it. The
-- sweep re-runs several times a second and would otherwise pick the same door for
-- ever ("not clicking door 50272 ... not reachable from here" 40 seconds straight),
-- so the refusal is remembered for a few seconds - long enough for the route
-- planner (nearby open doors, backtracking) to take over instead.
D.REFUSE_TTL = 6000
D.refusedAt = {}
-- A doorway we looked at and did NOT click (out of range with no walk to it, or still
-- inside the no-recross window). Scoped the same way as the refusal above and short:
-- it only has to outlast the decision the sweep re-makes several times a second.
D.NO_ACT_TTL = 5000
D.noActAt = {}

-- A doorway we planned a walk to and could not reach: the collision map says a wall is
-- between us and it. Scoped to the room it was judged from (another room may approach
-- the same doorway freely) and expiring, because walls only change when a door opens.
D.WALL_TTL = 8000
function D.wallBlockedNow(d)
	if not d then return true end
	local e = D.wallHit and D.wallHit[dkey(d)]
	if not e then return false end
	if (API.SystemTime() - e.t) > D.WALL_TTL then return false end
	local here = D.here
	return (here and e.room == rkey(here)) or e.room == ''
end

function D.doorRefusedNow(d)
	if not d then return true end
	-- A doorway the click path already decided NOT to act on - out of range with no
	-- walk to it, or still inside the "don't go straight back" window - is not
	-- re-nominated for a few seconds. Nothing changed in that time (we did not move),
	-- so the decision cannot change either; re-making it every pass is a stalled floor
	-- (live: the same "sweep: door 50344 ... prio 9" line every 1.5 s for 90 s).
	local s = D.noActAt and D.noActAt[dkey(d)]
	if s and (API.SystemTime() - s) < D.NO_ACT_TTL then return true end
	-- reachability re-tested and now positive: eligible again immediately
	if d.reach ~= false then return false end
	local e = D.refusedAt[dkey(d)]
	if not e then return false end
	if (API.SystemTime() - e.t) >= D.REFUSE_TTL then return false end
	-- A room is four walls and at most four doorways: if a leaf cannot be pathed to
	-- from here, no amount of walking inside the room changes that - the leaf faces
	-- the room on its OTHER side (doors are paired to rooms by a +/-2 tile radius).
	-- So the refusal is scoped to the room we were standing in: the moment the
	-- route puts us in another room the doorway is a candidate again.
	local here = D.here
	if not here or e.room ~= rkey(here) then return false end
	return true
end
-- Is this doorway still worth opening from `fromRoom`? Daemonheim rooms are very
-- often empty, so the doorway itself is the objective - a doorway we already
-- walked through is not, and neither is one we wrote off.

-- The client answered "you'll need the key" for this doorway. That is the only
-- trustworthy answer: a locked shape door reads "Enter" just like an unlocked one,
-- so the action text cannot be used to tell them apart. Recorded per doorway (both
-- leaves) and kept until a new key turns up.
local function doorNoKey(world, d)
	if not d then return false end
	if D.noKeyDoor[dkey(d)] then return true end
	if not world then return false end
	for _, o in ipairs(world.doors or {}) do
		local sameAxis = (o.x == d.x and math.abs(o.y - d.y) <= 1)
			or (o.y == d.y and math.abs(o.x - d.x) <= 1)
		if sameAxis and D.noKeyDoor[dkey(o)] then return true end
	end
	return false
end

-- Both leaves of a Daemonheim doorway exist ALL the time: "Enter" is always there.
-- The door is still locked while the "Unlock" leaf one tile away exists; that leaf
-- vanishes from the world scan once the door is unlocked, and only then does
-- "Enter" actually pass. So the state of a doorway is "is there an Unlock leaf in
-- the live scan", never "which action does this leaf show".
-- The boss room's own marker door is NOT a doorway leaf: it stands one tile from a
-- real doorway, and pairing the two declared a closed door "open".
-- The name is cached on the door record by the scan (`name`). Reading it off the
-- AllObject userdata here threw "caught (...) exception" in metamethod 'index' for
-- one object in the live scan and killed the whole script inside bestRouteTarget.
local function doorName(d)
	if type(d) ~= 'table' then return '' end
	if type(d.name) == 'string' then return d.name end
	d.name = D.objName(d.obj)
	return d.name
end

local function isBossDoor(d)
	if type(d) ~= 'table' then return false end
	return string.find(string.lower(doorName(d)), D.BOSS_DOOR_NAME, 1, true) ~= nil
end

local function doorwayLocked(world, d)
	if not d then return false end
	-- A DOORWAY WE HAVE WALKED THROUGH IS NOT LOCKED, whatever its leaves still say.
	-- Daemonheim leaves the Unlock leaf standing on a key door after it opens, and the key
	-- is gone from its cvar the moment it is spent - so the doorway read "locked" for ever
	-- afterwards, and BOTH leaves became unclickable (the Unlock one needs a key we no
	-- longer hold, the Enter one is refused because some leaf of the doorway says Unlock).
	-- Every route through a door the bot had opened itself was cut that way: live,
	-- "REFUSED door 50221 ... needs 18228 cvar 1825 value 0" every few seconds while the
	-- silver triangle key 18218 lay 8 tiles behind that very doorway. Crossing is proof;
	-- a locked door cannot be walked through.
	if D.traversed and D.traversed[dkey(d)] then return false end
	if d.action == 'Unlock' then return true end
	if not world then return false end
	for _, o in ipairs(world.doors or {}) do
		local sameAxis = (o.x == d.x and math.abs(o.y - d.y) <= 1)
			or (o.y == d.y and math.abs(o.x - d.x) <= 1)
		if sameAxis and o.action == 'Unlock'
			and not (D.traversed and D.traversed[dkey(o)]) then
			return true
		end
	end
	return false
end

-- Has this DOORWAY already refused to let us through? Asked of both leaves, because the
-- walker takes whichever leaf is nearer: a write-off recorded on one leaf has to silence
-- the other or the bot ping-pongs between them. Live 12:20:56-12:21:09, 50344 "Door" at
-- 7087,264 and 50501 "Yellow corner door" at 7088,264 - one doorway, two tiles - were
-- picked alternately and each clicked "by id and tile" three times while neither was even
-- in the live scan, until the pair finally came back and the crossing landed.
local function doorwaySuspect(world, d)
	if not D.shutSuspect then return false end
	if D.shutSuspect[dkey(d)] then return true end
	for _, o in ipairs((world and world.doors) or {}) do
		local sameAxis = (o.x == d.x and math.abs(o.y - d.y) <= 1)
			or (o.y == d.y and math.abs(o.x - d.x) <= 1)
		if sameAxis and D.shutSuspect[dkey(o)] then return true end
	end
	return false
end

-- Can this leaf actually be clicked right now? A locked doorway may only be
-- opened through its Unlock leaf, and only when we hold that key.
-- A DOORWAY IS OPEN WHEN ITS TILES ARE WALKABLE - the action word is not the state. This
-- used to answer "open when BOTH leaves are loaded", and a SHUT two-leaf doorway loads both
-- leaves as soon as the player is near it: live, leaves 50344 "Enter" at 8015,1272 and
-- 8016,1272 both reported action Enter while both tiles answered blocked=true. Every shut
-- door therefore read "already open", the sweep logged "walking through", and the click went
-- at a door that could not be entered ("it enters closed doors instantly") while the door
-- stayed shut. The walk set is built from the map's "Walk" tiles, so a passable doorway tile
-- is IN it and a shut one is not.
-- BUT THE WALK TEST ALONE CANNOT SEE AN OPEN DOOR IN THIS DUNGEON. Every doorway of floor
-- 8609:449 (21 of them, live 12:56-12:58) left its own tile Blocked/cuts=1 in the type 99
-- scan - an unlocked door that has been walked through reads exactly like a shut one - and
-- the client streams ONE leaf per doorway there, so the pair-tile test below never fires
-- either. The model called all 21 doorways shut: the route "opened" every open door it
-- passed (23 clicks in one log), and the boss gate (D.mapDoorsDone wants every doorway open
-- or crossed) could never finish, which is the "it cannot find the last door" loop.
-- The action word is only trusted on a SINGLE-leaf doorway (the shut case above had both
-- leaves, and a guardian door reads Enter whether it is shut or not).
-- The action word is only trusted on a doorway that is not a guardian one (a guardian leaf
-- reads Enter whether it is shut or not) and that has not already failed to let us through
-- (D.shutSuspect, set after two Enter clicks in a row did nothing).
local function doorwayOpen(world, d)
	if not d then return false end
	-- A doorway kept from an earlier scan is UNKNOWN, not open: its action is whatever it
	-- said minutes ago, and calling a stale "Enter" an open door would route the bot through
	-- a door that is shut by now. Unknown counts as "go and look", which is what the sweep
	-- does with a shut door.
	if d.memory then return false end
	if d.action == 'Enter' and d.kind ~= 'guardian'
		and not doorwaySuspect(world, d) and not doorwayLocked(world, d) then
		-- A DOORWAY WHOSE LEAF OFFERS "Enter" IS OPEN. A shut basic door offers "Open" and a
		-- shut key door offers "Unlock"; across a whole floor (37 door records) not one
		-- doorway ever read "Open". This rule was once limited to single-leaf doorways
		-- because a shut two-leaf doorway was seen reading Enter on both leaves - but that
		-- measurement rested on those tiles being blocked, and EVERY doorway tile is blocked,
		-- open or shut, so it proved nothing. The result of the doubt was worse than the risk:
		-- every two-leaf doorway of floor 8593:449 read Enter, was walked through, and still
		-- counted as "not done", so the boss gate never opened over them ("it says something
		-- isn't done", live 13:37).
		return true
	end
	-- THE OTHER SIDE OF THE DOORWAY MAY BE A PLAIN OPEN DOOR. A Daemonheim key door shows
	-- "Unlock" on the side it has to be opened from, and its partner leaf one tile away is
	-- an ordinary "Door" offering Enter - the global scanner sees it, and it is the leaf that
	-- actually passes. Reading only this leaf called the doorway locked for ever after the
	-- key had been used, so the room behind it (the one with the unopened doorways in it)
	-- could never be reached: live, "Your party used a key: Yellow shield key" and the walker
	-- then bounced between the two doors of its own room and stood down.
	if world and d.kind ~= 'guardian' and not isBossDoor(d) then
		for _, o in ipairs(world.doors or {}) do
			local sameAxis = (o.x == d.x and math.abs(o.y - d.y) <= 1)
				or (o.y == d.y and math.abs(o.x - d.x) <= 1)
			if sameAxis and dkey(o) ~= dkey(d)
				and (o.action == 'Enter' or o.action == 'Open')
				and o.kind ~= 'guardian' and not o.memory and not isBossDoor(o)
				and not doorwaySuspect(world, o) then
				-- ... BUT ONLY IF NO LEAF OF THE DOORWAY IS AN UNLOCK LEAF. A locked key door
				-- still reads "Enter" from its far side, and taking that as "open" made the
				-- walker click Enter on the LOCKED leaf of the yellow wedge doorway 50230 at
				-- 7080,302 - nothing happened, no crossing, and the bot stood there with the
				-- key for it in the pack.
				if not doorwayLocked(world, d) then return true end
			end
		end
	end
	if not (world and world.walk and d.x and d.y) then return false end
	if world.walk[pkey(d.x, d.y)] then return true end
	-- the pair tile of the doorway is the one that usually becomes walkable (the leaf we
	-- hold can be the shut half while the other half is passable)
	for _, n in ipairs(D.DIR4) do
		local k = pkey(d.x + n[1], d.y + n[2])
		if S.floorDoorTiles[k] and world.walk[k] then return true end
	end
	return false
end

-- Exposed for doorWalkReach, which is declared above it and can only see globals.
D.doorwayOpen = doorwayOpen

local function doorClickable(d, world, held, unknown)	if doorwayLocked(world, d) then
		return d.action == 'Unlock' and hasKeyFor(d, held, unknown)
	end
	return d.action ~= 'Unlock'
end

-- Is this doorway still worth opening when standing in room `fromRoom`? Daemonheim
-- rooms are very often empty, so the doorway itself is the objective - a doorway
-- we already walked through is not, one we wrote off is not, and neither is one
-- that is not reachable from inside this room.
local function doorWorth(d, world, held, unknown, fromRoom, badDoor)
	if S.badDoor and S.badDoor[dkey(d)] then return false end
	if D.traversed[dkey(d)] then return false end
	if doorNoKey(world, d) then return false end
	local r = fromRoom and world.rooms[fromRoom] or nil
	if not doorInRoom(r, d) then return false end
	if doorClickable(d, world, held, unknown) then return true end
	local _, item = hasKeyFor(d, held, unknown)
	return keyObtainable(world, item, held)
end

-- The doorway of this room that is still worth opening, if any.
local function roomDoorWork(r, world, held, unknown, badDoor)
	for _, d in ipairs(r.doors) do
		if doorWorth(d, world, held, unknown, r.idx, S.badDoor) then return d end
	end
	return nil
end

-- Crossing a doorway marks the doorway, not the leaf we happened to click. The
-- two leaves of one Daemonheim doorway are DIFFERENT objects: the dump shows a
-- "back" door 50342 at 14376,1231 and a "guardian" door 50346 at 14376,1232 for
-- the same gap, so matching on id+kind left the other side looking unexplored and
-- the bot walked straight back in through it. The leaves of one doorway always sit
-- one tile apart along the passage axis, so any leaf sharing that tile pair is the
-- same doorway - whatever its id, kind or action.
local function markDoorway(d, world, now)
	local canon = dkey(d)
	local stamp = now or API.SystemTime()
	D.traversed[canon] = true
	D.doorUsed[canon] = stamp
	-- a doorway we just walked through is proven alive: any "no option on any leaf"
	-- strikes it collected while the scan was missing it are not evidence of anything
	if D.deadTries then
		D.deadTries[canon] = nil
		for i = 1, #D.DIR4 do
			D.deadTries[(d.x + D.DIR4[i][1]) .. ',' .. (d.y + D.DIR4[i][2])] = nil
		end
	end
	-- walked through: whatever made it look shut is settled
	if D.shutSuspect then D.shutSuspect[canon] = nil end
	for _, o in ipairs(world.doors) do
		local sameAxis = (o.x == d.x and math.abs(o.y - d.y) <= 1)
			or (o.y == d.y and math.abs(o.x - d.x) <= 1)
		if sameAxis then
			local k = dkey(o)
			D.traversed[k] = true
			D.doorUsed[k] = stamp
			if D.shutSuspect then D.shutSuspect[k] = nil end
			if k < canon then canon = k end
		end
	end
	-- The FAR leaf is not loaded until after the crossing, so at this moment there is
	-- nothing to pair it with: the neighbour tile is stamped too, without needing an
	-- object there. Without this the other half of the doorway looked untouched and
	-- the bot went straight back through it 0.8 s later (live: 14959,1448 ->
	-- 14912:1408, then 14960,1448 -> 14945:1441, four crossings in twenty seconds).
	for i = 1, #D.DIR4 do
		local nk = (d.x + D.DIR4[i][1]) .. ',' .. (d.y + D.DIR4[i][2])
		D.doorUsed[nk] = stamp
	end
	return canon
end

-- Newest crossing stamp for this DOORWAY, not just this leaf: the two leaves sit one
-- tile apart and either of them may be the one re-picked next pass.
local function doorwayUsedAt(d)
	local best = D.doorUsed[dkey(d)]
	for i = 1, #D.DIR4 do
		local t = D.doorUsed[(d.x + D.DIR4[i][1]) .. ',' .. (d.y + D.DIR4[i][2])]
		if t and (not best or t > best) then best = t end
	end
	return best
end

-- Crossed a moment ago: the room behind it is where we just came from. Used to
-- stop the route planner bouncing between two rooms that both still have unused
-- doorways, which is what the run looked like from the outside.
local function doorRecent(d)
	local t = doorwayUsedAt(d)
	return t ~= nil and (API.SystemTime() - t) < D.DOOR_REUSE_MS
end

-- The boss-door marker is a decor record, and the client only walks to it when a
-- real path exists. Standing two tiles away on the other side of a CLOSED doorway
-- is not reachable, so the marker itself is path-tested.
local function bossDoorReachable(d)
	if not d or not d.x or not d.y then return false end
	return entityReachable(d.obj and d.obj.Type, d.id, d.x, d.y)
end



-- Both leaves of the doorway this leaf belongs to.
local function doorwayLeaves(world, d)
	local out = { d }
	for _, o in ipairs(world.doors or {}) do
		if (o.x == d.x and math.abs(o.y - d.y) <= 1)
			or (o.y == d.y and math.abs(o.x - d.x) <= 1) then
			out[#out + 1] = o
		end
	end
	return out
end

-- The room(s) actually on the OTHER side of this doorway. d.sides is a square
-- radius around the door tile, so it drags in rooms that are merely nearby - and
-- that is how the dead-end doorway reported "leads to a room with work": a third
-- room within reach was not skipped. A leaf's edge room is precisely the side it
-- is clicked from, so the far side is the leaves' edge rooms minus ours.
local function doorFarRooms(world, d, hereIdx)
	local out = {}
	local seenEdge = false
	for _, o in ipairs(doorwayLeaves(world, d)) do
		for side in pairs(o.edge or {}) do
			seenEdge = true
			if side ~= hereIdx then out[side] = true end
		end
	end
	-- A DOORWAY IN A THICK WALL HAS NO EDGE ROOM. `edge` asks the four tiles touching the
	-- leaf, and Daemonheim often leaves a blocked row between a doorway and the floor either
	-- side of it - `sides` (D.DOOR_REACH = 2 tiles out) is what finds the rooms there, and
	-- buildGraph has always used sideDirs, which is the same wider probe. Reading only
	-- `edge` here made every such doorway lead NOWHERE to every room-based rule while the
	-- router happily linked its rooms: live, "door 50344 "Door" Enter at 7279,312 ...
	-- edge=0 sides=0" and "50331 "Magical barrier" Dispel ... edge=0 sides=1" - a doorway in
	-- the floor map that no plan could ever head for. Falling back only when `edge` produced
	-- no OTHER room keeps ordinary doorways exactly as they were.
	if next(out) == nil then
		for _, o in ipairs(doorwayLeaves(world, d)) do
			for _, side in ipairs(o.sides or {}) do
				if side ~= hereIdx then out[side] = true end
			end
		end
	end
	-- Nothing anywhere: report the room the leaf admittedly touches (our own) so callers can
	-- at least tell "a doorway of this room" from "a doorway with no map at all".
	if next(out) == nil and seenEdge then
		for _, o in ipairs(doorwayLeaves(world, d)) do
			for side in pairs(o.edge or {}) do out[side] = true end
		end
	end
	return out
end

-- The one room this doorway leads INTO (nil when the map cannot tell). Used by the
-- far-door routing: roomNearRooms() answers "which room is this tile near", and a
-- doorway is paired to rooms within two tiles, so it usually answers OUR room - the
-- door then looked like it had nowhere to go and the bot never routed through the
-- open doorways towards it.
function D.doorFarRoom(world, d, hereIdx)
	for side in pairs(doorFarRooms(world, d, hereIdx)) do
		if side ~= hereIdx then return world.rooms[side] end
	end
	return nil
end

-- Does this doorway open into the boss room? The boss room is the floor's LAST
-- objective, so the ordinary door sweep must never walk into it: that is how the
-- bot ended up in the fight with half the floor unexplored.
function D.doorLeadsToBossRoom(world, d, hereIdx)
	-- Geometry first: the "Boss door" marker stands one tile from the doorway that
	-- leads into the boss room, and that is true whether or not room segmentation
	-- managed to tell the two rooms apart (in one blob it never does).
	local bd = world.bossDoor or D.bossDoorTile
	if bd and bd.x and d.x then
		-- ±2 tiles, not ±1: when the way in is a KEY door the leaf sits a couple of
		-- tiles along the boss room's wall from the marker (live: marker 7288,655,
		-- gold rectangle door 7288,657). The ±1 window missed it, the sweep spent the
		-- key on it and walked into To'Kash with the floor half explored.
		if math.abs(d.x - bd.x) <= 2 and math.abs(d.y - bd.y) <= 2 then return true end
	end
	-- A boss npc already on screen right behind this doorway settles it whatever the
	-- marker says: the npc only streams in within ~20 tiles, so a doorway a few tiles
	-- from it is a way into its room.
	local bl = D.bossLive
	if bl and bl.Tile_XYZ and d.x then
		local bt = bl.Tile_XYZ
		if math.abs(d.x - math.floor(bt.x)) <= 4 and math.abs(d.y - math.floor(bt.y)) <= 4 then
			return true
		end
	end
	local boss = world.bossRoom
	if not boss then return false end
	if hereIdx and hereIdx == boss then return false end   -- already inside it
	for side in pairs(doorFarRooms(world, d, hereIdx)) do
		if side == boss then return true end
	end
	for _, n in ipairs(D.DIR4) do
		local r = roomNearRooms(world.rooms, d.x + n[1], d.y + n[2])
		if r and r.idx == boss and r.idx ~= hereIdx then return true end
	end
	return false
end

--------------------------------------------------------------------
-- Tiles a search must not walk over because an obstacle is standing there.
--
-- ORDINARY NPCS DO NOT BLOCK - the client walks under/through them, so a monster in a
-- doorway must never make that doorway "unreachable". The BARREL npcs are special: they
-- are solid furniture, the puzzle is solved by pushing them, and every plan around them
-- has to go AROUND them. The walk set is terrain only (type 99 "Walk" tiles), so they
-- are invisible to a search over it and have to be added here by hand.
--------------------------------------------------------------------
-- Matched on the live ids first (11072 pushed, 11075 broken), then on the exact name,
-- so a future npc with "barrel" somewhere in its name cannot become an obstacle.
D.BARREL_NPC_NAMES = { ['barrel'] = true, ['broken barrel'] = true }

function D.barrelBlocks()
	local out = {}
	local ids = D.BARREL_IDS
	local fixIds = D.BARREL_FIX_IDS
	for _, n in ipairs(D.npcScan()) do
		local nm = string.lower(D.objName(n))
		if (ids and ids[n.Id]) or (fixIds and fixIds[n.Id]) or D.BARREL_NPC_NAMES[nm] then
			local t = n.Tile_XYZ
			if t then out[pkey(t.x, t.y)] = true end
		end
	end
	return out
end

--------------------------------------------------------------------
-- THE pathfinder. One BFS over the client's own walk set, with doorways as the
-- gates. `through` decides which doorways are open to the search:
--   true  - every doorway on the map (the planned route: what the walk display
--           draws, door by door, across the whole floor)
--   false - only doorways we have really crossed and the map reports open
--           (where the player can physically get to right now)
-- The boss room is shut in both modes until the floor is cleared.
-- Cached per standing tile for a pass, so a loop over twenty doorways runs one BFS.
--------------------------------------------------------------------
D.BFS_CAP = 6000
-- What crossing a doorway costs the walk search, in tiles of walking. Nothing else in
-- the search is weighted, so this is the single knob that decides "is a doorway a
-- shortcut or a detour": with the old cost of 1, going through the next room and back
-- tied with walking down the room we stand in, and the route clicked doorways it did
-- not need. 8 tiles is well above the ~4 a doorway detour saves and well below the
-- length of any real journey.
D.DOOR_COST = 8
-- What a step between two DIFFERENT rooms costs when it is not a doorway. Rooms are joined
-- by doorways; a tile boundary is not a passage, and treating it as one walked the bot to
-- the room beside the key doors instead of around to their entrance. Priced, not forbidden:
-- the room blob can split one room in two, and a hard wall there would strand the bot.
D.ROOM_BREAK_COST = 200
-- How many times a doorway may answer "no option on any leaf" before it is written off
-- as a dead object. One read is not evidence: the object scan is a snapshot, and a
-- doorway the client walks through happily can be missing from it for a single pass.
D.DEAD_TRIES = 3
-- A SKILL OBSTACLE ("Runed door", "Wooden barricade", "Flammable debris" ...) is deleted
-- from the client when it is used, instead of turning into an "Enter" leaf. Judged only
-- within this range - the client streams objects around the player, so absence further
-- away means nothing - and only after this long past the click, so the animation and the
-- client's own removal of the object are not mistaken for "it was never there".
D.SKILL_GONE_NEAR = 15
D.SKILL_GONE_MS = 4000
function D.walkBfs(world, through)
	world = world or S.worldCache
	if not world or not world.walk or next(world.walk) == nil then return nil end
	local px, py = ptile()
	D.bfsCache = D.bfsCache or {}
	local slot = through and 1 or 2
	local c = D.bfsCache[slot]
	if c and c.world == world and c.px == px and c.py == py
		and (API.SystemTime() - c.at) < 1000 then
		return c
	end
	local walk = world.walk
	-- Standing on a pad or a doorway tile is normal, so seed from the nearest floor.
	local sx, sy, seedBest = px, py, 99
	if not walk[pkey(px, py)] then
		sx = nil
		for dx = -2, 2 do
			for dy = -2, 2 do
				if walk[pkey(px + dx, py + dy)] then
					local v = math.abs(dx) + math.abs(dy)
					if v > 0 and v < seedBest then seedBest, sx, sy = v, px + dx, py + dy end
				end
			end
		end
		if not sx then return nil end
	end
	local bossLocked = not D.bossOpen
	local hereIdx = world.room and world.room.idx
	-- gate[tile] = the door record standing on that tile, not just `true`: the route
	-- has to hand back the OBJECT to click, or a doorway the scan does not carry can
	-- never be acted on and the route is a picture instead of a plan.
	-- gateCost[tile] = what crossing that doorway costs THIS search. A doorway crossed a
	-- moment ago leads back into the room we just left, so it is priced out of the plan:
	-- live, the bot cleared a room, left it by door 50344 and the very next route step took
	-- it straight back in through 50502 - the partner leaf of the doorway it had walked in
	-- by five seconds earlier - before it got on with the room it actually wanted. The
	-- partner leaf counts because doorUsed is recorded per tile and checked on the four
	-- neighbours. Still finite, so a dead end can always be backed out of.
	local gate, gateCost = {}, {}
	local now = API.SystemTime()
	for _, d in ipairs(world.doors or {}) do
		local k = pkey(d.x, d.y)
		local use = false
		if through then
			if not (bossLocked and (isBossDoor(d) or D.doorLeadsToBossRoom(world, d, hereIdx))) then
				use = true
			end
		elseif d.kind == 'guardian' and D.traversed[dkey(d)] then
			-- (a guardian doorway never reads "open" - its leaf says Enter whether it is
			-- passable or not - so having walked through it is the only proof there is)
			use = true
		elseif D.doorwayOpen and D.doorwayOpen(world, d) then
			-- AN OPEN DOORWAY WE HAVE NOT CROSSED YET IS STILL A WAY THROUGH. This used to
			-- demand D.traversed as well, which made the plain walk set stop at every doorway
			-- into a room this run had not entered yet. nextGoalDoor requires its goal to be
			-- reachable in THIS search, so every key door in an unvisited room was excluded
			-- from the planner: live, the keys for the gold pentagon and yellow wedge doors
			-- were in the pack and neither door could ever become the end of a route - the bot
			-- toured the doors of the rooms it had already seen instead, one lap after another.
			use = true
		end
		if use then
			gate[k] = d
			local cost = D.DOOR_COST
			local usedAt = D.doorUsed and D.doorUsed[dkey(d)]
			for i = 1, 4 do
				local t = D.doorUsed and D.doorUsed[(d.x + D.DIR4[i][1]) .. ',' .. (d.y + D.DIR4[i][2])]
				if t and (not usedAt or t > usedAt) then usedAt = t end
			end
			if usedAt and (now - usedAt) < (D.RECROSS_MS or 12000) then
				cost = D.DOOR_COST * 6
			end
			gateCost[k] = cost
		end
	end
	local sk = pkey(sx, sy)
	-- The walk set is TERRAIN (type 99 "Walk" tiles): it says nothing about what is
	-- standing on it, so a search over it walks straight through the barrel line. A
	-- barrel npc is a real obstacle with no collision record in that set, so its tiles
	-- are taken out of the neighbour test here - once, for every user of this search.
	local blocked = D.barrelBlocks and D.barrelBlocks() or {}
	-- The walk set says a tile is floor; it does not say which of its four sides a
	-- wall closes off, so a plain 4-connected search steps straight through a wall
	-- face and calls the far side reachable. Every step below therefore goes through
	-- D.wallOpen, which holds the exit mask the client reported for each tile (see
	-- walkSet). Live, that false step is what made a barrel room's bits nine tiles
	-- away look reachable through a one-tile wall while the client answered
	-- "You can't reach that" to every click.
	-- DOORWAYS ARE NOT FREE. The walk set is terrain, so a doorway tile is walkable
	-- like any other, and a plain BFS counts crossing a doorway as one step. That made
	-- cutting through the next room and back out as cheap as walking down the room we
	-- are in: the dots showed 34 path tiles and TWO doorway crossings for a door 30
	-- tiles away IN THE SAME ROOM, and the walker dutifully clicked "Enter" on those
	-- doorways - which is the bot bouncing through the same doorway (live: door 50344
	-- at 11279,2600 crossed three times while the purple crescent door it actually had
	-- to open stood 30 tiles up the same room). Crossing a doorway now costs
	-- D.DOOR_COST steps, so a search only uses one when it has to. Costs are small
	-- integers, so the queue is one bucket per cost - no heap needed.
	-- ROOMS ARE JOINED BY DOORWAYS AND BY NOTHING ELSE. The walk set is terrain: it says
	-- "this tile is floor", never which room that floor belongs to, and where two rooms come
	-- within a tile of each other the exit masks that D.wallOpen reads can be missing for
	-- that boundary - so the search steps straight from one room into the next. That is not
	-- a passage: live, the route walked the bot to the room standing BESIDE the unopened key
	-- doors - same level, a few tiles away, no way through - and stopped there, while the
	-- real way in was west through two doorways. A step that changes room anywhere other than
	-- a doorway is now refused, so the search has to find the doors.
	local roomOf = world.roomOf
	if not roomOf then
		roomOf = {}
		for _, r in ipairs(world.rooms or {}) do
			for k in pairs(r.set or {}) do roomOf[k] = r.idx end
		end
		world.roomOf = roomOf
	end
	local dist, prev, order = { [sk] = 0 }, {}, {}
	local buckets, top, maxC = { [0] = { { sx, sy } } }, 0, 0
	local settled, pops = {}, 0
	while pops < D.BFS_CAP do
		local cur
		while top <= maxC do
			local b = buckets[top]
			if b and #b > 0 then cur = table.remove(b) break end
			top = top + 1
		end
		if not cur then break end
		local ck = pkey(cur[1], cur[2])
		if not settled[ck] then
			settled[ck] = true
			pops = pops + 1
			order[#order + 1] = cur
			local cd = dist[ck]
			for i = 1, 4 do
				local nx, ny = cur[1] + D.DIR4[i][1], cur[2] + D.DIR4[i][2]
				local k = pkey(nx, ny)
				local wallOk = gate[k] or gate[ck] or D.wallOpen(ck, k, i)
				if wallOk and not settled[k] and not blocked[k] and (walk[k] or gate[k]) then
					local stepCost = gate[k] and (gateCost[k] or D.DOOR_COST) or 1
					-- A ROOM CHANGE THAT IS NOT A DOORWAY IS PRICED OUT, NOT FORBIDDEN. The
					-- room blob sometimes splits one physical room in two, so a hard wall here
					-- could strand the bot inside a room it can walk through; a heavy cost gives
					-- the search the right answer without that risk. Live: the route walked to
					-- the room standing BESIDE the unopened key doors - same level, a few tiles
					-- away, no way through - because that step was as cheap as floor, while the
					-- real way in was west through two doorways (6 tiles + 2 doors).
					if not gate[k] and not gate[ck] then
						local ra, rb = roomOf[ck], roomOf[k]
						if ra and rb and ra ~= rb then stepCost = stepCost + D.ROOM_BREAK_COST end
					end
					local nc = cd + stepCost
					if not dist[k] or nc < dist[k] then
						dist[k] = nc
						prev[k] = ck
						local b = buckets[nc]
						if not b then b = {} buckets[nc] = b end
						b[#b + 1] = { nx, ny }
						if nc > maxC then maxC = nc end
					end
				end
			end
		end
	end
	-- gateCost is kept on the result so the drawn route can say what each doorway cost
	-- this search: a doorway crossed a moment ago is priced D.DOOR_COST * 6, which is
	-- the whole reason a plan either does or does not go back out of the room it is in.
	c = { world = world, px = px, py = py, at = API.SystemTime(), walk = walk,
		gate = gate, gateCost = gateCost, dist = dist, prev = prev, order = order,
		seed = sk, blocked = blocked }
	D.bfsCache[slot] = c
	return c
end

-- Is (x,y) reachable in this search? Tolerance 1 by default: the tile we want is
-- often a pad or a doorway and the floor BESIDE it is the thing we walk to.
-- No map at all answers true - refuse to judge, never refuse to act.
function D.walkReach(bfs, x, y, tol)
	if not bfs then return true end
	tol = tol or 1
	x, y = math.floor(x), math.floor(y)
	for dx = -tol, tol do
		for dy = -tol, tol do
			if bfs.dist[pkey(x + dx, y + dy)] then return true end
		end
	end
	return false
end

-- The doorway at the end of the drawn route: nearest closed door the plan can
-- reach, walked-through or written-off doors only when nothing better is left,
-- boss room never (D.walkBfs keeps it shut). Returns (door, endKey, bfs).
-- A room whose only unfinished doors are ones we hold no key for is INVISIBLE to the goal
-- loop above: doorClickable is false for them, so they can never be the end of a route.
-- The floor then reads "20 unopened doorway(s)" while the router tours the doors it can
-- open - one lap of the corridor after another, past the doorway that leads to them. This
-- asks the other question: does this room hold a door that is shut and that we cannot pay
-- for? The key may be inside it, and seeing the door beats another lap.
local function roomHoldsLockedDoor(r, world, held, unknown)
	if not r then return false end
	for _, d in ipairs(world.doors or {}) do
		if doorInRoom(r, d) then
			local k = dkey(d)
			if not D.traversed[k] and not (S.badDoor and S.badDoor[k]) and not isBossDoor(d)
				and not doorwayOpen(world, d) and not doorNoKey(world, d)
				and not doorClickable(d, world, held, unknown) then
				return true
			end
		end
	end
	return false
end

function D.nextGoalDoor(world, bfs)
	bfs = bfs or D.walkBfs(world, true)
	if not bfs then return nil end
	-- A GOAL THE PLAYER CANNOT WALK TO IS NOT A GOAL. The through-door BFS used below
	-- (slot 1) reaches tiles on the far side of SHUT doorways, so a doorway on the other
	-- side of two rooms looked like the nearest end of the route, the walker went for it
	-- every pass, and openDoor's own reach test refused it ("not walkable from where we
	-- stand: 134 tiles walked, none within 1 of it"). That is the "it thinks really hard
	-- and cannot decide" loop: same goal, same refusal, ten seconds apart, forever.
	-- The plain BFS (slot 2) is what the player can actually reach right now.
	local plain = D.walkBfs(world)
	local pdist = plain and plain.dist or nil
	local walk, dist = bfs.walk, bfs.dist
	local hereIdx = (world.room and world.room.idx) or (D.here and D.here.idx)
	local held, unknown = heldKeys()
	local goalX, goalY, goalTier, goalD, endKey, goalDoor = nil, nil, nil, nil, nil, nil
	for _, d in ipairs(world.doors or {}) do
		local dk = dkey(d)
		-- A GUARDIAN DOORWAY THAT LEADS INTO THE BOSS ROOM IS THE BOSS ENTRANCE. Live: the
		-- guardian leaf 50348 at 8616,480 is paired with 50352 "Boss door" at 8616,479 -
		-- guarding it and opening it are the same doorway, so while the boss gate is shut it
		-- is held back like any other boss way; the gate opens once the map is done.
		local bossWay = (not D.bossOpen)
			and (isBossDoor(d) or D.doorLeadsToBossRoom(world, d, hereIdx))
		-- A door we cannot open is not the end of a route: no key for it, or the
		-- client already told us it needs one ("you'll need the key").
		-- AND "OPEN" IS NOT "DONE" HERE EITHER. Only shut doorways used to be targets, so a
		-- leaf that reads "Enter" without ever having been walked through (this floor's 49377
		-- at 7072,264) could never be the end of a route: the planner kept ending at the
		-- guardian doorway instead and the west side was never opened. D.doorwayUnfinished
		-- adds exactly those doorways - never crossed, never written off, still leading
		-- somewhere undone - so they are explored instead of assumed.
		local roomHere = world.room or D.here
		local unfinished = D.doorwayUnfinished(world, d, roomHere, S.done, S.badDoor)
		if (not D.doorwayOpen(world, d) or unfinished) and not bossWay
			and not doorNoKey(world, d)
			and doorClickable(d, world, held, unknown) then
			-- THREE TIERS, cheapest first: a door into a room we know is empty (or back into
			-- the room we just came from) is the least useful thing on the floor, and a door
			-- already crossed or written off is worse still. Without the empty tier the sweep
			-- walked to the nearest shut door regardless - live: it pathed all the way to the
			-- crimson diamond door at 8031,1224 with nothing behind it, one room after another.
			local dead = D.doorLeadsToDeadRoom(world, d, hereIdx, S.visitedEmpty, S.arrivedFrom)
			local tier = 2
			if not (S.badDoor[dk] or D.traversed[dk]) then
				tier = dead and 1 or 0
			end
			-- TIER -1: PROGRESS DOORS. A locked doorway we already hold the key for, and any
			-- guardian doorway. Both are one-off progress that stays shut for everything
			-- else, so they are worth crossing half the floor for and must never lose to a
			-- nearer ordinary door. Distance always won before, which is the live "it goes
			-- into every room until it finds the room with the unopened door".
			-- Only while it is still work: a doorway already walked through or written off
			-- is in tier 2 and must never pull the route back across the floor.
			-- SKILL DOORS COUNT AS PROGRESS TOO: one interaction opens them (they cannot be
			-- "locked out" like a key door failing), and the room behind has not been seen.
			-- Without this they sat at tier 0 and lost on distance to any nearer ordinary
			-- door, so the sweep toured the corridor and left the barricade standing.
			-- A GUARDIAN DOORWAY IS ONLY PROGRESS WHILE IT HAS NOT ALREADY REFUSED. It opens by
			-- killing the guardians behind it, which is the room's own business (the fight
			-- branch, and D.localWorkPending), not something a walk across the floor achieves.
			-- Once a click on it has produced nothing, it stops being worth 108 tiles of walking
			-- and drops to an ordinary doorway: live 07:31, the route went 108 tiles to the
			-- guardian door at 14728,4719, clicked Enter five times with no walk and no
			-- animation, then reversed to a second guardian doorway at 14767,4680 and got
			-- "You can't reach that" - two same-id guardian doorways 39 tiles apart, ping-ponged.
			if tier < 2 then
				if d.kind == 'guardian' then
					if (S.attempts[dkey(d)] or 0) == 0 then tier = -1 end
				elseif d.action == 'Unlock' or d.kind == 'skill' then
					tier = -1
				end
			end
			-- AND SO IS A DOORWAY THAT LEADS TO THE DOORS WE CANNOT OPEN YET. Those are what
			-- the keys are for and there are only a few of them, while ordinary doorways are
			-- endless: live, the route toured the open-able doors of a corridor ("one map end
			-- to another") and walked straight past the yellow shield door whose room holds
			-- the locked key doors. Tier -1 puts those rooms ahead of another lap.
			if tier == 0 then
				for side in pairs(doorFarRooms(world, d, hereIdx)) do
					if roomHoldsLockedDoor(world.rooms[side], world, held, unknown) then
						tier = -1
						break
					end
				end
			end
			-- A DOORWAY THAT LEADS NOWHERE IS THE LAST THING ON THE FLOOR. doorwayUnfinished
			-- answers "is this doorway still work" for the floor counters, and a SHUT doorway
			-- is always work there whatever stands behind it - which the route then acted on,
			-- touring a map of dead ends from one to the next. A shut door into a room with
			-- nothing in it and no way on is kept available (a floor with nothing else must
			-- still finish) but ranked below every door that leads somewhere.
			if tier >= 0 and D.doorLeadsToWork
				and not D.doorLeadsToWork(world, d, roomHere, S.done, nil) then
				tier = 2
			end
			-- THE LAST DOORWAY WE COULD STILL OPEN IS ALWAYS THE GOAL. Same rule as
			-- D.doorwayUnfinished: opening it is not touring empty rooms, it is the only way
			-- the floor can still be explored or finished. Without this the plan vanished the
			-- instant the walker crossed the neighbouring doorway - the dots kept drawing a
			-- route the planner had already abandoned (live 03:00, door 50344 at 7432,4127).
			if tier == 2 and D.doorwayUnfinished
				and D.doorwayUnfinished(world, d, roomHere, S.done, S.badDoor) then
				local others = 0
				for _, o in ipairs(world.doors or {}) do
					if o ~= d then
						local ok2 = dkey(o)
						if not D.traversed[ok2] and not (S.badDoor and S.badDoor[ok2])
							and not isBossDoor(o) and not doorNoKey(world, o) then
							others = others + 1
							break
						end
					end
				end
				if others == 0 then tier = 0 end
			end
			-- WHERE THE ROUTE STOPS IN FRONT OF THIS DOORWAY. The four orthogonal neighbours
			-- first - that is the tile the click comes from - and only then the surrounding
			-- box. A doorway at a corner or in a thick wall has NO orthogonal floor tile in
			-- the walk set: every neighbour is wall, and the floor it is clicked from is
			-- diagonal two tiles out. With the orthogonal-only test such a doorway could
			-- never become the end of a route at all, while the dots happily drew a path to
			-- it: live, "map walk: 16 path dots, 2 junction dots ... end at door 50344
			-- (7432,4127)" at 02:56:02, and one pass later "every doorway left leads nowhere
			-- - standing still", with 50344 sitting in the dump as
			-- "nevercrossed reachable UNFINISHED" for the rest of the floor. The dots pointed
			-- at the right door and the walker never took the path.
			local nk, nd = nil, nil
			local function tryStop(nx, ny)
				local k = pkey(nx, ny)
				local v = dist[k]
				if walk[k] and v and (not pdist or pdist[k]) and (not nd or v < nd) then
					nk, nd = k, v
				end
			end
			for i = 1, 4 do tryStop(d.x + D.DIR4[i][1], d.y + D.DIR4[i][2]) end
			if not nk then
				-- same tolerance D.nearestReached uses, and the plain BFS still has to reach
				-- it, so a diagonal stop cannot smuggle in a doorway behind a wall
				for dx = -1, 1 do
					for dy = -1, 1 do
						if dx ~= 0 or dy ~= 0 then tryStop(d.x + dx, d.y + dy) end
					end
				end
			end
			if nk and (not goalD or tier < goalTier or (tier == goalTier and nd < goalD)) then
				goalTier, goalD, goalX, goalY, endKey, goalDoor = tier, nd, d.x, d.y, nk, d
			end
		end
	end
	if not endKey then
		-- Nothing we can OPEN is in reach: walk to the room that holds the doors we cannot
		-- open yet, instead of another lap of the corridor. Nearest such doorway wins, and
		-- only doorways we can actually walk through (plain/Enter leaves that are reachable
		-- in the plain BFS) are candidates - the walker must be able to take the step.
		local bestD, bestDoor, bestEnd
		for _, d in ipairs(world.doors or {}) do
			local dk = dkey(d)
			if not D.traversed[dk] and not S.badDoor[dk] and not isBossDoor(d)
				and (d.action == 'Enter' or d.action == 'Open')
				and not doorNoKey(world, d)
				and not ((not D.bossOpen) and D.doorLeadsToBossRoom(world, d, hereIdx)) then
				local holds = false
				for side in pairs(doorFarRooms(world, d, hereIdx)) do
					if roomHoldsLockedDoor(world.rooms[side], world, held, unknown) then holds = true end
				end
				if holds then
					for i = 1, 4 do
						local nk = pkey(d.x + D.DIR4[i][1], d.y + D.DIR4[i][2])
						local nd = dist[nk]
						if walk[nk] and nd and (not pdist or pdist[nk])
							and (not bestD or nd < bestD) then
							bestD, bestDoor, bestEnd = nd, d, nk
						end
					end
				end
			end
		end
		if bestDoor then
			D.lockedWalkLog = D.lockedWalkLog or {}
			local lk = dkey(bestDoor)
			if not D.lockedWalkLog[lk] then
				D.lockedWalkLog[lk] = true
				log(string.format('no openable doorway in reach - walking to %d at %d,%d to reach the key doors behind it',
					bestDoor.id, bestDoor.x, bestDoor.y))
			end
			return bestDoor, bestEnd, bfs
		end
		return nil
	end
	-- NOTHING WORTH GOING TO IS NOT A REASON TO WALK SOMEWHERE. Tier 2 is "this doorway
	-- leads nowhere at all" - the only reason it was ever walked to was that something had to
	-- be picked, which is the one-room-to-the-next tour. Standing still is the right answer:
	-- D.doorwayUnfinished no longer calls a dead end work, so the floor counters can finish
	-- and the boss gate can open instead.
	if goalTier and goalTier >= 2 then
		if not D.deadEndIdleLog then
			D.deadEndIdleLog = true
			-- NAME THE DOOR AND COUNT WHAT IS LEFT. "Every doorway left leads nowhere" on its
			-- own hid the case where a genuinely unfinished doorway (50344 at 7432,4127, dumped
			-- as "nevercrossed reachable UNFINISHED") simply never produced a stop tile - the
			-- reader cannot tell "nothing left" from "the one thing left was skipped".
			local nOpen = 0
			if D.floorDoorsLeft then
				local okN, n = pcall(D.floorDoorsLeft, world, world.room or D.here, S.badDoor)
				if okN and type(n) == 'number' then nOpen = n end
			end
			log(string.format(
				'every doorway left leads nowhere (best is door %d at %d,%d, tier %d; %d doorway(s) still unfinished on the floor) - standing still instead of touring empty rooms',
				goalDoor and goalDoor.id or -1, goalX or -1, goalY or -1, goalTier, nOpen))
		end
		return nil
	end
	if goalDoor and goalTier == -1 then
		D.keyGoalLog = D.keyGoalLog or {}
		local gk = dkey(goalDoor)
		if not D.keyGoalLog[gk] then
			D.keyGoalLog[gk] = true
			if goalDoor.kind == 'guardian' then
				log(string.format(
					'guardian door %d at %d,%d is the route end - heading there from %d tiles off',
					goalDoor.id, goalDoor.x, goalDoor.y, goalD))
			elseif goalDoor.action == 'Unlock' and goalDoor.item then
				log(string.format(
					'key in the pack opens door %d "%s" (%s) at %d,%d - routing straight there, %d tiles off',
					goalDoor.id, tostring(goalDoor.name), tostring(goalDoor.item),
					goalDoor.x, goalDoor.y, goalD))
			else
				-- NOT a key we hold: this doorway is the way to the rooms that hold the
				-- locked key doors. Saying "key in the pack opens door ... (nil)" here sent
				-- the reader looking for a key that does not exist.
				log(string.format(
					'doorway %d "%s" (%s) at %d,%d leads to the locked key doors - routing there, %d tiles off',
					goalDoor.id, tostring(goalDoor.name), tostring(goalDoor.action),
					goalDoor.x, goalDoor.y, goalD))
			end
		end
	end
	local g = bfs.gate[pkey(goalX, goalY)]
	if not g then
		for _, d in ipairs(world.doors or {}) do
			if d.x == goalX and d.y == goalY then g = d break end
		end
	end
	if not g then return nil end
	-- a real goal is being returned, so the next time the floor runs dry it gets to say so
	D.deadEndIdleLog = nil
	return g, endKey, bfs
end

--------------------------------------------------------------------
-- Is a PROGRESS doorway still waiting on this floor? A guardian door, or a locked door
-- whose key is in the pack: one-off doors that the floor route exists to reach. Cheap on
-- purpose - it only reads the door list, no search - so the walker can ask it before
-- deciding whether this room's own doorway is worth taking the pass for.
function D.progressDoorPending(world)
	local held, unknown = heldKeys()
	for _, d in ipairs((world and world.doors) or {}) do
		local k = dkey(d)
		if not D.traversed[k] and not (S.badDoor and S.badDoor[k])
			and not doorwayOpen(world, d) then
			-- the way into the boss room is not progress while the boss gate is shut: the
			-- route would be refused at the click anyway (tryOpen checks it), so counting it
			-- here would keep every room plan off for nothing
			local bossWay = (not D.bossOpen)
				and (isBossDoor(d) or D.doorLeadsToBossRoom(world, d, nil))
			if not bossWay then
				if d.kind == 'guardian' then return true end
				-- a locked door only counts while we can actually pay for it: a key door we
				-- hold no key for outranks nothing and would otherwise freeze every room plan
				-- on the floor for the whole run
				if d.action == 'Unlock' and hasKeyFor(d, held, unknown) then return true end
			end
		end
	end
	return false
end

--------------------------------------------------------------------
-- The local room plan. A puzzle solver working, the room's own doorway being
-- opened, a fight in progress: the bot is busy INSIDE this room, and the floor
-- route answers a question nobody is asking. The BFS over the walk set is the most
-- expensive thing the planner does, so it is not calculated at all while a local
-- plan is in action. Every local action refreshes the stamp and it expires on its
-- own, so routing comes back the moment the room stops acting.
--------------------------------------------------------------------
D.LOCAL_PLAN_TTL = 2500
D.localPlanAt = 0

-- A boss fight is a local plan that lasts as long as the fight does. The 2.5 s default
-- is fine for a solver that acts every pass, but an attack pass can sleep 20 s: the
-- stamp expired in between, the walk map drew its green dots again ("path calc in the
-- boss room") and the door sweep below was free to pick a doorway and walk the bot back
-- out of the room. Whoever starts a fight notes the plan with this TTL instead.
D.BOSS_PLAN_TTL = 45000

-- A room solver OWNS its room while it is working. This is a plain flag, not a timer:
-- the 2.5 s stamp above is refreshed by every solver action, but a solver that is
-- waiting for an animation or for a prop to disappear returns false for a pass or two,
-- and in that gap the stamp lapses, the pathfinder plans a walk and the bot leaves the
-- room it was working. A solver that gives up must not freeze the floor, so the flag is
-- dropped after D.SOLVER_QUIET_PASSES passes in a row with no action from it.
D.solverRoom = nil          -- rkey of the room a solver is working
D.solverQuiet = 0           -- passes since that solver last acted
D.SOLVER_QUIET_PASSES = 3

-- Is a room solver holding THIS room right now?
function D.solverHoldsRoom(here)
	return here ~= nil and D.solverRoom ~= nil and D.solverRoom == rkey(here)
end

function D.noteLocalPlan(ttl)
	D.localPlanAt = API.SystemTime()
	D.localPlanTtl = ttl or D.LOCAL_PLAN_TTL
end

function D.localPlanActive()
	return D.localPlanAt > 0
		and (API.SystemTime() - D.localPlanAt) < (D.localPlanTtl or D.LOCAL_PLAN_TTL)
end

function D.clearLocalPlan()
	D.localPlanAt = 0
	D.localPlanTtl = nil
	D.localPlanHard = nil
	D.mapDotPaused = nil
end

--------------------------------------------------------------------
-- Where the route ends. A KEY LYING ON THE FLOOR OUTRANKS EVERY DOORWAY: a key is
-- the only thing that opens the doors we hold no key for, so the walk goes and
-- fetches it before another door is opened. "Nearest" is nearest BY WALKING, from
-- the same search the walker uses (D.walkBfs), and a key behind a doorway we cannot
-- open is simply not reachable yet - the route then ends at that doorway instead.
--------------------------------------------------------------------
D.KEY_WALK_TRIES = 3   -- failed takes before the plan stops chasing one key
D.keyWalkFail = {}     -- key tile -> failed takes, cleared when the floor changes

-- The nearest ground key the planned walk reaches. Returns (keyRecord, endKey),
-- endKey being the floor tile the route stops on: the key's own tile when it is
-- walkable, otherwise the tile beside it (a ground item sits on a Blocked tile).
function D.nextGoalKey(bfs)
	if not bfs then return nil end
	local dist = bfs.dist
	local best, bestD, bestEnd = nil, nil, nil
	for _, k in ipairs(D.objScan()) do
		if k.Type == 3 and D.KEY_SET[k.Id] then
			local x, y = math.floor(k.Tile_XYZ.x), math.floor(k.Tile_XYZ.y)
			local kk = pkey(x, y)
			-- a key whose take kept failing is not chased for ever
			if (D.keyWalkFail[kk] or 0) < D.KEY_WALK_TRIES then
				local d, ex, ey = dist[kk], x, y
				if not d then
					for i = 1, 4 do
						local nx, ny = x + D.DIR4[i][1], y + D.DIR4[i][2]
						local nd = dist[pkey(nx, ny)]
						if nd and (not d or nd < d) then d, ex, ey = nd, nx, ny end
					end
				end
				if d and (not bestD or d < bestD) then
					bestD, best, bestEnd = d, k, pkey(ex, ey)
				elseif not d then
					-- THE KEY IS ON THE FLOOR AND THE WALK MAP CANNOT SEE IT. Without this the
					-- only trace was "no key on the floor", which reads as "there is no key"
					-- when in fact there is one a few tiles inside a room that has not been
					-- scanned into the walk set yet. Say which one, once per tile.
					D.keyNoWalkLog = D.keyNoWalkLog or {}
					if not D.keyNoWalkLog[kk] then
						D.keyNoWalkLog[kk] = true
						log(string.format(
							'key %d "%s" at %d,%d is on the floor but no tile beside it is in the walk map (%d tiles walked) - it has to be walked up to through the doorway route instead',
							k.Id, D.objName(k), x, y, #(bfs.order or {})))
					end
				end
			end
		end
	end
	return best, bestEnd
end

-- The plan for this pass: where the walk ends and every doorway crossed to get
-- there. Nil when nothing on the floor is worth walking to.
--   kind  'key'  - the route ends on a ground key; the doors are only the way there
--   kind  'door' - the route ends at `door`, the next doorway to open
-- `doors` holds every doorway crossed, in walking order; on a door plan the goal is
-- the LAST entry, which is what D.walkPath stops in front of.
function D.routePlan(world)
	-- A local room plan owns the pass: no floor route is calculated while it runs - and
	-- the same goes for a room a solver is working, which is what "the pathfinder is
	-- interrupting local room solving" was: the solver's own stamp lapsed between two of
	-- its actions and the route walker took the pass.
	-- EXCEPT WHILE A PROGRESS DOORWAY IS STILL WAITING (a guardian door, or a locked door
	-- we hold the key for): that is the one thing the floor route exists for, and the stamp
	-- a room-door click armed was keeping the route off for its whole lifetime, so the
	-- player kept opening rooms while the dots pointed at the goal.
	if D.localPlanActive() then
		-- A PROGRESS DOORWAY OUTRANKS THE ROOM'S GUESSES - but not its FACTS. "A guardian door,
		-- or a locked door whose key is in the pack" is one-off progress, and a props guess or a
		-- solver holding the room must not keep the route away from it. ENEMIES IN THE ROOM ARE
		-- NOT A GUESS: live 07:28:39 the walker stood down with "enemies in this room" and the
		-- very next pass unlocked the green wedge door, because progressDoorPending answered
		-- true and waved the stand-down aside. The fight branch never ran, so the room was left
		-- with the monster alive and the local priority silently dropped.
		if not (D.progressDoorPending(world) and not D.localPlanHard) then return nil end
	end
	if D.solverHoldsRoom(D.here) then return nil end
	local bfs = D.walkBfs(world, true)
	if not bfs then return nil end

	local key, keyEnd = D.nextGoalKey(bfs)
	if key then
		local route, k = {}, keyEnd
		while k do
			route[#route + 1] = k
			k = bfs.prev[k]
		end
		local doors, shut = {}, nil
		for i = #route, 1, -1 do
			local d = bfs.gate[route[i]]
			if d then
				doors[#doors + 1] = d
				-- A shut doorway is never walked through blind: the route stops in
				-- front of it and the caller opens it with tryOpen, then the walk to
				-- the key carries on from the next room.
				if not D.doorwayOpen(world, d) then shut = d break end
			end
		end
		if not shut then
			return { kind = 'key', key = key, doors = doors, endKey = keyEnd, bfs = bfs }
		end
		local held, unknown = heldKeys()
		-- Shut AND unopenable: the key is out of reach for now, so this pass falls
		-- through to the ordinary door rule instead of chasing it.
		if not (doorNoKey(world, shut) or not doorClickable(shut, world, held, unknown)) then
			return { kind = 'door', door = shut, doors = doors, endKey = keyEnd, bfs = bfs }
		end
	end

	local goal, endKey = D.nextGoalDoor(world, bfs)
	if not goal or not endKey then return nil end
	local route, k = {}, endKey
	while k do
		route[#route + 1] = k
		k = bfs.prev[k]
	end
	local held, unknown = heldKeys()
	local doors = {}
	for i = #route, 1, -1 do
		local d = bfs.gate[route[i]]
		if d then
			-- Shut and unopenable ends the walk there: the route beyond it is a picture,
			-- not a walk (this is what pointed the dots at a silver wedge door we hold no
			-- key for). The last door we CAN use becomes the route's end.
			if not D.doorwayOpen(world, d)
				and (doorNoKey(world, d) or not doorClickable(d, world, held, unknown)) then
				if #doors == 0 then return nil end
				return { kind = 'door', door = doors[#doors], doors = doors, bfs = bfs }
			end
			if d ~= goal then doors[#doors + 1] = d end
		end
	end
	doors[#doors + 1] = goal
	return { kind = 'door', door = goal, doors = doors, endKey = endKey, bfs = bfs }
end

-- Every doorway the drawn route crosses, in walking order, with the white-dot door
-- last. This is the list the walker clicks through, one per room boundary.
function D.pathDoors(world)
	local plan = D.routePlan(world)
	if not plan then return nil end
	return plan.doors, plan.door, plan.bfs
end

-- Next doorway to act on and the one the route ends at. Nil when the route ends on
-- a ground key instead: there is no door to open while the plan is fetching one.
function D.nextDoorPlan(world)
	local plan = D.routePlan(world)
	if not plan or plan.kind ~= 'door' then return nil end
	local first = plan.doors[1]
	if not first then return nil end
	if (S.attempts[dkey(first)] or 0) >= D.SKILL_TRIES then return nil end
	return first, plan.door
end

-- Nearest floor we can really walk to, within three tiles of (x,y). This is the
-- replacement for the old radius hunt, which only asked "is it walkable" and so
-- happily picked the far side of a wall.
function D.walkSpotNear(world, x, y)
	local bfs = D.walkBfs(world)
	if not bfs then return nil end
	local bx, by, best = nil, nil, 10
	for _, t in ipairs(bfs.order) do
		local d = (t[1] - x) ^ 2 + (t[2] - y) ^ 2
		if d < best then best, bx, by = d, t[1], t[2] end
	end
	return bx, by
end

-- Does this doorway open into a room the bot has never stood in? Target selection
-- uses this to stop the up-and-down shuttling: several doorways joining the same two
-- rooms all "lead to a room with work", so the bot kept crossing one, finding the
-- next one behind it, and crossing back.
function D.doorLeadsToNewRoom(world, d, hereIdx, visited)
	if not visited then return true end
	local any = false
	for side in pairs(doorFarRooms(world, d, hereIdx)) do
		any = true
		local r = world.rooms[side]
		if r and not visited[rkey(r)] then return true end
	end
	return not any      -- no far room known: do not block on a guess
end

-- Does this doorway open into a room already abandoned as empty (or the room we just
-- came from)? The ice room uses this: its exits are few, and without the penalty the
-- bot slid out into the same dead end, was sent straight back, and looped.
function D.doorLeadsToDeadRoom(world, d, hereIdx, visitedEmpty, cameFrom)
	for side in pairs(doorFarRooms(world, d, hereIdx)) do
		local r = world.rooms[side]
		if r then
			local k = rkey(r)
			if (S.visitedEmpty and S.visitedEmpty[k]) or (cameFrom and cameFrom == k) then
				return true
			end
		end
	end
	return false
end

-- Are all the NON-boss doorways on this floor done with? Traversed, written off as
-- unreachable, or permanently locked without a key all count as done.
function D.mapDoorsDone(world, hereIdx, badDoor)
	-- A monolith room is not "unreachable", it is LOCKED: none of its doors open
	-- until the pillar is charged, so clicking them does nothing at all. Counting
	-- them as done is how the bot announced a cleared dungeon with an unfinished
	-- monolith room standing in it (door 49462 at 6904,5072).
	for _, r in ipairs(world.rooms or {}) do
		if r.monolith or D.monoPillarCache[rkey(r)] then
			local st = D.monoState[rkey(r)]
			if not (st and st.solved) then
				D.monoGateLog = D.monoGateLog or {}
				local mk = rkey(r)
				if not D.monoGateLog[mk] then
					D.monoGateLog[mk] = true
					log(string.format(
						'room %s holds an uncharged monolith - its doors stay shut until the puzzle is done',
						mk))
				end
				return false, nil
			end
		end
	end
	for _, d in ipairs(world.doors or {}) do
		if not isBossDoor(d) and not D.doorLeadsToBossRoom(world, d, hereIdx) then
			-- Deliberately NO reachability test: this asks about the FLOOR, and a
			-- doorway on the other side of the map is still work to do.
			-- AND "OPEN" IS NOT "DONE": a doorway that reads Enter but was never walked
			-- through is still a way on (D.doorwayUnfinished, shared with the two counters
			-- in Dung.lua so all three can never disagree again).
			if D.doorwayUnfinished(world, d, hereIdx and world.rooms[hereIdx], S.done, S.badDoor)
				and not doorNoKey(world, d) then
				return false, d
			end
		end
	end
	return true
end

-- A room nobody wants to go back to can still hold the only way on. The statue room of
-- floor 7073:257 was marked done the moment its puzzle was solved, and the doorway it
-- still had (49377 at 7072,264) then counted for nothing: every route into that room
-- read "no work", the bot toured the rooms it had left and the floor ended with the west
-- side unexplored ("boss room stays closed: door 49377 ... is still not done" on repeat).
-- A doorway nobody has walked through and nobody has written off IS work, wherever it
-- stands, so the room holding it is worth walking back into.
local function roomHoldsDoorWork(world, r, bad, viaDoor)
	if not r then return false end
	-- `viaDoor` is the doorway we would come IN by, and it must not count as work: it is
	-- by definition uncrossed before we walk through it, so counting it made EVERY room look
	-- worth entering - a dead end with one door read as "holds an open doorway" and the bot
	-- walked in, found nothing, and had to cross back out.
	local function isVia(d)
		if not (viaDoor and viaDoor.x and viaDoor.y) then return false end
		return math.abs(d.x - viaDoor.x) <= 1 and math.abs(d.y - viaDoor.y) <= 1
	end
	for _, d in ipairs(world.doors or {}) do
		if doorInRoom(r, d) and not isVia(d) then
			local k = dkey(d)
			if not D.traversed[k] and not (bad and bad[k]) and not isBossDoor(d) then
				return true
			end
		end
	end
	return false
end

-- IS THIS ROOM WORTH WALKING INTO? Answered from the MAP and the LIVE scans only - no
-- memory of the previous run. That is the whole point: a restart re-scans the floor, so
-- "we have been here before" is not available, and it is not needed either - a room that
-- was emptied still reads empty. What counts as worth it:
--   * a doorway standing in it that nobody has crossed and nobody wrote off,
--   * something lying on its floor (a key, loot, a chest).
-- NOT counted: monsters and npcs. Those are the LOCAL room logic's business - the walker
-- clears the room it is standing in (D.localWorkPending / liveEnemies) - and they must not
-- pull the floor route across the map. The one global objective is the BOSS, and that is
-- gated separately: D.bossOpen only flips once every doorway on the floor is done.
-- Room finished flags are not counted either: they are a guess made from the outside, and
-- relying on them is what made a restart tour a map it had already half finished.
local function roomWorthEntering(world, r, viaDoor)
	if not (r and r.set) then return false end
	if roomHoldsDoorWork(world, r, S.badDoor, viaDoor) then return true end
	for _, o in ipairs(D.objScan()) do
		local ok, ty, t = pcall(function() return o.Type, o.Tile_XYZ end)
		if ok and ty == 3 and t then
			local x, y = math.floor(t.x), math.floor(t.y)
			if r.set[pkey(x, y)] then return true end
		end
	end
	return false
end

-- ONE ROOM DEEP IS NOT ENOUGH. A doorway can open into a room with nothing left in it
-- while the doors that matter stand one room further on: live, the yellow shield door at
-- 7071,296 was ignored from inside its own room because the room behind it held nothing,
-- and the key doors it exists to reach were one room beyond that. This walks the room
-- graph D.ROOM_LOOK rooms deep asking the same question of each room.
D.ROOM_LOOK = 4
local function roomLeadsToWork(world, r, depth, seen, viaDoor)
	local k = rkey(r)
	if seen[k] then return false end
	seen[k] = true
	if roomWorthEntering(world, r, viaDoor) then return true end
	if depth <= 0 then return false end
	for _, d in ipairs(world.doors or {}) do
		if doorInRoom(r, d) then
			for side in pairs(doorFarRooms(world, d, r.idx)) do
				local nr = world.rooms[side]
				if nr and rkey(nr) ~= k and roomLeadsToWork(world, nr, depth - 1, seen, d) then
					return true
				end
			end
		end
	end
	return false
end

-- Does this doorway lead anywhere worth going? Judged from the map and the live scans,
-- with the room graph lookahead above - never from a saved "done" flag.
local function doorLeadsToWork(world, d, here, done, skip)
	-- A SKILL DOOR IS WORK IN ITS OWN RIGHT. It is a shut doorway we can open with a skill
	-- (mine / dispel / chop / force-bar / repair ...), and the room behind it has not been
	-- seen - the same one-off progress a key door is. Judging it by "what does the far room
	-- hold" hid them from the floor map: live, "Pile of rocks" (Mine) at 7240,286 and
	-- "Magical barrier" (Dispel) at 7278,312 both came out "finished" because the only
	-- untried doorway in the room behind them was their OWN partner leaf (excluded by the
	-- viaDoor rule), so the ground could be walked twice, the boss gate could open over them
	-- and a whole wing stayed shut behind a pile of rocks. Key doors were already exempt.
	if d.kind == 'skill' and not (D.traversed and D.traversed[dkey(d)]) then return true end
	-- Memoised per world (one scan): the lookahead touches the whole room graph, and this
	-- question is asked for every doorway several times per pass.
	local ck = dkey(d) .. '|' .. tostring(here and here.idx) .. '|' .. (skip and 's' or '')
	if world.workCache and world.workCache[ck] ~= nil then return world.workCache[ck] end
	local res, other = nil, false
	for side in pairs(doorFarRooms(world, d, here and here.idx)) do
		other = true
		local r = world.rooms[side]
		if r and res == nil then
			-- Seed the walk with the room we are standing in, not with the far room: seeding
			-- the far room marks it visited and the lookahead answers "nothing" before it
			-- ever looks past it.
			local seed = {}
			if here then seed[rkey(here)] = true end
			if roomLeadsToWork(world, r, D.ROOM_LOOK, seed, d) then res = true end
		end
	end
	-- No room on the far side at all: the door is closed, so the room behind it has
	-- not been drawn yet. Nothing can be judged about it from the map, and an
	-- unopened door is exactly what exploring is for - so this counts as work.
	if res == nil then res = not other end
	world.workCache = world.workCache or {}
	world.workCache[ck] = res
	return res
end

-- Exposed for nextGoalDoor, which is declared earlier in this file and can only see D.
D.doorLeadsToWork = doorLeadsToWork

-- IS THIS DOORWAY STILL A WAY ON? The action word is not the state. Every doorway can
-- read "Enter", and this floor proved it: 49377 at 7072,264 read "Enter" while it would
-- not open, would not let the player walk through it, and answered
-- "object id?:49377 might be wrong" to every dispatch form. Counting only "not open"
-- doorways let a floor with THREE never-crossed doorways report
-- "0 unopened doorway(s)", flip the boss gate and give up ("no boss appeared in the boss
-- room - giving up on this floor") while the west half was still unexplored.
-- A doorway we have never walked through still counts while it leads to a room this run
-- has not done; once both sides are done (or it is written off) it stops counting, so a
-- map that really is finished still finishes.
function D.doorwayUnfinished(world, d, here, done, bad)
	if not d then return false end
	local k = dkey(d)
	if D.traversed[k] then return false end
	if bad and bad[k] then return false end
	-- ONE QUESTION FOR OPEN AND SHUT ALIKE: does this doorway lead anywhere worth going?
	-- A shut door used to count as work whatever stood behind it, which kept a floor of dead
	-- ends "unfinished" for ever - the route walked from one empty room to the next because
	-- each of them still counted, and the boss gate never opened over them. Now a doorway
	-- into a room with nothing in it and no way on is simply not work: the bot stands still
	-- (or goes to the boss) instead of touring.
	local leads = doorLeadsToWork(world, d, here, done or S.done, nil) == true
	if leads then return true end
	-- ... EXCEPT WHEN IT IS THE LAST DOORWAY ON THE FLOOR WE COULD STILL OPEN. "Leads
	-- nowhere" is judged with the entry doorway excluded, so a doorway whose far room holds
	-- nothing but the doorway itself always reads as no work - and then it is never opened,
	-- the floor is called finished over it, and the boss gate opens on an unopened door.
	-- Live 03:00: the dots drew 16 tiles to door 50344 at 7432,4127, the walker crossed the
	-- neighbouring doorway, and the plan evaporated: "every doorway left leads nowhere ...
	-- 0 doorway(s) still unfinished" while the dump printed "nevercrossed reachable
	-- UNFINISHED" for that same doorway. Opening the last one is not touring - it is how the
	-- floor gets explored and finished - so it stays work while it is the only thing left.
	local n = 0
	for _, o in ipairs((world and world.doors) or {}) do
		if o ~= d then
			local k2 = dkey(o)
			if not D.traversed[k2] and not (bad and bad[k2])
				and not isBossDoor(o) and not doorNoKey(world, o) then
				n = n + 1
				if n > 0 then break end
			end
		end
	end
	if n == 0 then return true end
	return false
end

-- THE ONE ANSWER TO "WHAT IS LEFT ON THIS FLOOR". The same question used to be answered
-- in three places - D.mapDoorsDone, the boss gate and the per-room sweep - each with its
-- own idea of "unopened", so the same bug (counting only SHUT doorways while every leaf
-- can read "Enter") lived in all three and fixing one left the others lying. The three
-- CALLERS stay, because they ask at three different scopes, but they now share this.
-- Returns: how many doorways are unfinished, how many of those lead to the boss room,
-- how many were written off, and the first unfinished doorway (for logging).
function D.floorDoorsLeft(world, here, badDoor)
	local hereIdx = here and here.idx
	local nOpen, nBoss, nBad, first = 0, 0, 0, nil
	for _, d in ipairs((world and world.doors) or {}) do
		if D.doorwayUnfinished(world, d, here, S.done, badDoor) and not doorNoKey(world, d) then
			nOpen = nOpen + 1
			first = first or d
			if isBossDoor(d) or D.doorLeadsToBossRoom(world, d, hereIdx) then
				nBoss = nBoss + 1
			end
		elseif badDoor and badDoor[dkey(d)] then
			nBad = nBad + 1
		end
	end
	return nOpen, nBoss, nBad, first
end

-- The doorway this room wants opened: shut, physically in this room, and worth
-- opening. This is the LOCAL room plan - while it exists the bot is busy here and no
-- floor route is calculated (D.noteLocalPlan). The sweep and D.runRoute both come
-- through here, so "the room plan is in action" always names the same doorway the
-- sweep is about to click.
function D.roomDoorPlan(world, here, held, unknown, skip)
	if not here or not world then return nil end
	local best, bestD = nil, math.huge
	for _, d in ipairs(world.doors or {}) do
		local k = dkey(d)
		-- "In this room" comes from the door/room edge model, which a merged room
		-- stretches across the whole floor: a Guardian door 53 tiles away was picked
		-- as the nearest door of THIS room and then refused every pass. The room is
		-- 13x13, so 12 tiles is the furthest a doorway of this room can be - anything
		-- past D.ROOM_DOOR_DIST belongs to the router.
		-- NO exceptions. A "far leaf of a merged room" escape was tried here twice and
		-- both times it put a doorway from the next room into the local plan: a guardian
		-- door 21 tiles away ("You can't reach that", blacklisted) and then door 50344,
		-- 46 tiles away on the other side of the map, clicked over and over. Neither the
		-- room's tile set nor the physical walk BFS can tell them apart, because a blob
		-- that spans the floor contains the tile beside every doorway on it and open
		-- doorways make all of it walkable. The router routes to a far doorway; the local
		-- plan is only ever for a doorway we could stand next to inside one room.
		local inRoom = doorInRoom(here, d) and D.doorInMyRoom(d) and D.doorReachableInRoom(here, d)
		if inRoom
			and not D.clickExhausted(d.id, d.x, d.y, d.action or 'Enter')
			and not (S.badDoor and S.badDoor[k]) and not D.traversed[k]
			and not doorRecent(d) and not isBossDoor(d)
			and doorClickable(d, world, held, unknown)
			-- no reach filter: the batch startpathreach answer calls every blocked
			-- doorway tile "unreachable", which threw away the doorway a skill door
			-- becomes once it opens, and everything behind it
			and not doorNoKey(world, d)
			-- already refused from this room (no path within one tile): picking it
			-- again just re-logs and refuses, so let the routing branches take the
			-- pass instead.
			and not D.doorRefusedNow(d)
			and not D.wallBlockedNow(d)
			and (D.bossOpen or not D.doorLeadsToBossRoom(world, d, here.idx))
			and not doorwayOpen(world, d)
			-- WORTH OPENING AT ALL. One test now, shared with the floor counters and the
			-- route: does this doorway lead anywhere worth going. The old extra escape
			-- ("not the room we came from") kept a doorway into a room already found
			-- empty as a local plan, so the bot opened it, crossed into the empty room
			-- and had to come back - the one-empty-room-at-a-time tour. A key door we
			-- can pay for is always worth it, and so is a doorway we have ALREADY
			-- started working: a skill door needs several interactions, and dropping it
			-- between two chops because the room behind it looks empty is how the bot
			-- abandoned a barricade mid-chop and walked off along the floor path.
			and (d.action == 'Unlock' or (S.attempts[k] or 0) > 0
				or doorLeadsToWork(world, d, here, S.done, skip)) then
			local v = d.dist or math.huge
			if v < bestD then bestD, best = v, d end
		end
	end
	return best
end

-- Room corner keys are minx:miny of the segmented tiles, and those move when a
-- doorway opens (the door tiles join the room) - so the room we came from cannot
-- be matched by string equality a moment later.
local function nearRoomKey(a, b)
	if not b then return false end
	if a == b then return true end
	local ax, ay = string.match(a, '^(%-?%d+):(%-?%d+)$')
	local bx, by = string.match(b, '^(%-?%d+):(%-?%d+)$')
	if not (ax and bx) then return false end
	return math.abs(tonumber(ax) - tonumber(bx)) <= 2
		and math.abs(tonumber(ay) - tonumber(by)) <= 2
end

-- Does this doorway open into the room we walked in from? Going straight back is
-- what the "tries random doors and walks back" behaviour looked like from outside.
local function doorLeadsToRoom(world, d, key)
	if not key then return false end
	for side in pairs(doorFarRooms(world, d, nil)) do
		local r = world.rooms[side]
		if r and nearRoomKey(rkey(r), key) then return true end
	end
	return false
end

-- How many separate DOORWAYS a room has. r.doors holds leaves, and the two
-- leaves of one Daemonheim doorway both sit on the same tile pair - so a leaf
-- room with a single doorway still reports 2 doors, which is exactly why an empty
-- dead end kept looking like it had "a doorway leading on".
local function distinctDoorways(r)
	local groups = {}
	for _, d in ipairs(r.doors or {}) do
		-- Only doorways that physically touch this room count. r.doors is built from
		-- leaf edges, and a leaf on the room's wall can be attributed to the room
		-- next door - which made a one-doorway dead end look like a corridor.
		if doorInRoom(r, d) then
			local found = false
			for i = 1, #groups do
				local g = groups[i]
				if (g.x == d.x and math.abs(g.y - d.y) <= 1)
					or (g.y == d.y and math.abs(g.x - d.x) <= 1) then
					found = true
					break
				end
			end
			if not found then groups[#groups + 1] = { x = d.x, y = d.y } end
		end
	end
	return #groups
end

-- Is spending a KEY on this doorway justified? Kept for reference only: the sweep
-- now treats every affordable key door as top priority, because the room behind a
-- lock is unjudged by definition and the key is worthless until it is spent.
-- (Was: require the far room to hold a key, be the boss room, or have a way on.)
function D.doorKeyWorth(world, d, here)
	local known, worth = false, false
	for side in pairs(doorFarRooms(world, d, here and here.idx)) do
		local r = world.rooms[side]
		if r then
			known = true
			if #r.keys > 0 or world.bossRoom == side or distinctDoorways(r) >= 2 then
				worth = true
			end
		end
	end
	if not known then return true end
	return worth
end

-- First doorway on the route from `here` to room `target`, following the parent
-- map findTarget() returned. Several leaves can join the same room, so only one
-- that can actually be used counts.
local function firstHop(world, adj, here, target, prev, held, unknown, badDoor)
	local step = target
	while prev[step] and prev[step] ~= here.idx do step = prev[step] end
	for _, e in ipairs(adj[here.idx] or {}) do
		if e.room == step and not S.badDoor[dkey(e.door)]
			and not doorRecent(e.door) and not doorNoKey(world, e.door)
			and doorClickable(e.door, world, held, unknown) then
			return e.door
		end
	end
	return nil
end

-- Objects of these ids that the client can walk to, asking only about the ones
-- AROUND the player. Everything in another room is unreachable by definition, and
-- startpathreach = 1 costs one client path find PER OBJECT, so a floor-wide scan
-- is both pointless and slow (64 key ids + 26 door ids per pass). Two cheap steps
-- instead: a tile scan with the filter off, a distance cut, then one path-tested
-- call for the handful that survive.
D.NEAR_RADIUS = 20
-- How many live path tests the route planner may spend looking for a doorway it can
-- click, and how many route searches it may spend looking for a plan. Every test is
-- a client path query, and the scan already costs ~800 ms.
D.ROUTE_TEST_MAX = 4
D.ROUTE_BFS_MAX = 4
-- Keys are worth looking further than a door: a floor is about 64 tiles across and
-- a key left in a room three rooms away is still a key we need. The id filter keeps
-- this cheap - it only pre-selects the handful of ground keys on the floor.
D.KEY_RADIUS = 64
function D.reachNear(typ, ids, px, py, radius)
	local nearIds = {}
	-- pinned: the second scan's records are handed out of this function (see D.keepScan)
	for _, o in ipairs(D.keepScan(API.ReadAllObjectsArray(typ, ids, {}, D.NO_REACH)) or {}) do
		local t = o.Tile_XYZ
		local x, y = math.floor(t.x), math.floor(t.y)
		if math.abs(x - px) <= (radius or D.NEAR_RADIUS)
			and math.abs(y - py) <= (radius or D.NEAR_RADIUS) then
			nearIds[#nearIds + 1] = o.Id
		end
	end
	local out = {}
	if #nearIds == 0 then return out end
	for _, o in ipairs(D.keepScan(API.ReadAllObjectsArray(typ, nearIds, {}, D.REACH_LOCAL)) or {}) do
		out[#out + 1] = o
	end
	return out
end

-- The nearest key the client can actually walk to, anywhere on the floor. Keys are
-- ground items (type 3) and the reach pass filters with startpathreach = 1, so a key
-- behind a closed door only appears once that door is open.
local function nearestKeyOnFloor()
	local px, py = ptile()
	local best, bestD = nil, math.huge
	for _, k in ipairs(D.reachNear({ 3 }, D.KEY_IDS, px, py, D.KEY_RADIUS) or {}) do
		local t = k.Tile_XYZ
		local x, y = math.floor(t.x), math.floor(t.y)
		local d = (x - px) * (x - px) + (y - py) * (y - py)
		if d < bestD then bestD, best = d, { obj = k, x = x, y = y, d = d } end
	end
	return best
end

-- Nearest ground key on the floor, whether or not it can be walked to right now.
-- The reach pass in nearestKeyOnFloor hides every key behind a closed door, and a
-- key behind a closed door is precisely the one that has to be fetched: the bot
-- walked past an orange rectangle key 18 tiles away because tolerance-1 pathing
-- said "no path". Reachability is the router's problem, not the scanner's.
function D.keyOnFloorAny()
	local px, py = ptile()
	local best, bestD = nil, math.huge
	for _, k in ipairs(D.objScan()) do
		if k.Type == 3 and D.KEY_SET[k.Id] then
			local t = k.Tile_XYZ
			local x, y = math.floor(t.x), math.floor(t.y)
			if math.abs(x - px) <= D.KEY_RADIUS and math.abs(y - py) <= D.KEY_RADIUS then
				local d = (x - px) * (x - px) + (y - py) * (y - py)
				if d < bestD then bestD, best = d, { obj = k, x = x, y = y, d = d } end
			end
		end
	end
	return best
end

local function deadEnds(world, held, unknown, done, badDoor, hereIdx)
	local skip = {}
	for i = 1, #world.rooms do
		local r = world.rooms[i]
		local k = rkey(r)
		if not S.done[k] then
			-- A room is worth a trip when it holds a key or a doorway LEADING ON -
			-- never merely because it holds monsters, and never merely because it has
			-- the doorway we would walk in through. That last case is what sent the bot
			-- into leaf rooms with nothing in them: from outside, the room's only
			-- doorway is untried, so it looked like work, and inside it is just a dead
			-- end.
			-- The count is of DOORWAYS, not leaves: counting leaves made every leaf
			-- room look like it had two doors and it has no way out of it either.
			--
			-- A LEAF (one doorway) is only worth entering for a key. Enemies in a
			-- dead end are worth nothing - the room leads nowhere, so the trip is
			-- wasted even if something there can be killed.
			local leaf = distinctDoorways(r) < 2
			local work = #r.keys > 0
			if not work and not leaf then
				work = roomDoorWork(r, world, held, unknown, S.badDoor) ~= nil
			end
			if not work and world.bossRoom == i then
				-- the boss npc may not have streamed in yet: never skip his room
				work = true
			end
			-- Enemies are deliberately NOT work. A room holding nothing but monsters
			-- leads nowhere and its trip is wasted, so counting them made the bot
			-- cross the floor into rooms with nothing in them.
			if not work then skip[k] = true end
		end
	end
	return skip
end

-- Single next step toward one specific room, used for the forced walk to the boss
-- room where the normal "is it worth going" rules do not apply.
local function findHop(world, adj, startIdx, goalIdx, held, unknown, badDoor)
	if startIdx == goalIdx then return nil end
	local prev, seen = {}, { [startIdx] = true }
	local queue, head = { startIdx }, 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		for _, e in ipairs(adj[cur]) do
			-- Nothing may hop through the boss room before the floor is cleared: the
			-- backtrack picked door 50435 at 10703,4328 (the boss doorway) every
			-- second and tryOpen refused it every second ("it leads into the boss
			-- room and the floor is not finished") - that is the stuck-here loop.
			local bossWay = not D.bossOpen
				and (isBossDoor(e.door) or D.doorLeadsToBossRoom(world, e.door, nil))
			-- The FIRST hop is clicked from where we stand, so it has to be reachable
			-- now. Deeper hops are only graph planning - those rooms are reached by
			-- walking, so they are not tested here.
			if not bossWay and not seen[e.room] and not S.badDoor[dkey(e.door)]
				and doorClickable(e.door, world, held, unknown)
				and (cur ~= startIdx or D.doorClickableNow(e.door)) then
				seen[e.room] = true
				prev[e.room] = { from = cur, door = e.door }
				if e.room == goalIdx then
					local step = goalIdx
					while prev[step] and prev[step].from ~= startIdx do step = prev[step].from end
					return prev[step] and prev[step].door or nil
				end
				queue[#queue + 1] = e.room
			end
		end
	end
	return nil
end

-- Is this room still worth walking into? The dungeon's whole content is rooms joined
-- by doorways, so "worth it" is deliberately simple: something to pick up, a doorway we
-- can open, a room nobody has entered, or the boss room once every door is done.
function D.roomWorthy(world, r, held, unknown)
	local key = rkey(r)
	if S.done[key] then return false end
	if S.visitedEmpty and S.visitedEmpty[key] then return false end
	if #(r.keys or {}) > 0 then return true, 'key on the floor' end
	for _, d in ipairs(r.doors or {}) do
		local k = dkey(d)
		if not D.traversed[k] and not (S.badDoor and S.badDoor[k])
			and not doorwayOpen(world, d) and doorClickable(d, world, held, unknown) then
			return true, string.format('door %d to open', d.id)
		end
	end
	if world.bossRoom == r.idx and D.bossOpen then return true, 'boss room' end
	-- "Nobody has stood here yet" used to be a reason on its own, and that is what
	-- walked the bot into empty dead ends: every room it had not visited was a goal,
	-- including the one-tile leaf rooms with nothing in them behind the doorway it had
	-- just come through. Worse, room keys are minx:miny and change whenever the
	-- segmentation merges or splits a room, so D.visitedRooms stops matching and the
	-- room it is standing in becomes "unexplored" again - the bot then walked back and
	-- forth through the same two doorways. Exploration is driven by DOORWAYS (the loop
	-- above: an untried doorway we can open is work), never by the absence of a record.
	return false
end

-- The doorway clicker is defined much further down the chunk, and a local function
-- is only visible to the code that comes after it.
local tryOpen
local crossedDoorway

-- The walk ended on a ground key: pick it up. That is the plan's whole purpose, so
-- the pass is spent here and the caller does not fall through to the door sweep.
-- Success is read from the key ring (heldKeys), not from the ground scan: the item
-- lingers there for a moment after the loot window takes it. When the id was already
-- in the ring the ring cannot answer, so the ground scan decides - that is the one
-- case where "still on the floor" is a failed take.
function D.takePlannedKey(plan, world)
	local k = plan and plan.key
	if not k then return false end
	local x, y = math.floor(k.Tile_XYZ.x), math.floor(k.Tile_XYZ.y)
	local kk = pkey(x, y)
	local px, py = ptile()
	D.keyWalkFail = D.keyWalkFail or {}
	-- OUT OF CLICK RANGE. There is no "walking" to do here: a ground-tile click at a tile
	-- 26 tiles away is not a walk, it is a click into whatever the client's pathfinder
	-- decides, and with doorways or walls in between it answers "You can't reach that" and
	-- the bot stands there - live: "walk plan: key 18300 "" at 8055,1259 is 26 tiles away -
	-- walking to 8055,1259 first" with every door on the floor shut. Movement is driven by
	-- OBJECTS, so the key itself is clicked and the client walks us over; and if the client
	-- says there is no path, nothing is clicked at all and the route keeps opening doorways.
	if math.max(math.abs(px - x), math.abs(py - y)) > D.CLICK_RANGE then
		local kz = (k.Tile_XYZ or {}).z or 0
		if not (D.tileReachable(x, y, kz, 1) or D.tileReachable(x, y, kz, 2)) then
			D.keyWalkFail[kk] = (D.keyWalkFail[kk] or 0) + 1
			log(string.format('walk plan: key %d "%s" at %d,%d is %d tiles away and the client has no path to it - not walking at it (%d/%d)',
				k.Id, D.objName(k), x, y, math.max(math.abs(px - x), math.abs(py - y)),
				D.keyWalkFail[kk], D.KEY_WALK_TRIES))
			return false
		end
		log(string.format('walk plan: key %d "%s" at %d,%d is %d tiles away over a path the client can walk - clicking the key and letting the client walk us over',
			k.Id, D.objName(k), x, y, math.max(math.abs(px - x), math.abs(py - y))))
		say(string.format('taking key %d', k.Id))
		D.takeFloorItem(k, { k.Id }, 'key')
		API.RandomSleep2(600, 200, 300)
		return true
	end
	local tries = D.keyWalkFail[kk] or 0
	local had = heldKeys()[k.Id] == true
	say(string.format('taking key %d at %d,%d', k.Id, x, y))
	log(string.format('walk plan: key %d "%s" on the floor at %d,%d is the end of the drawn route (try %d/%d)',
		k.Id, D.objName(k), x, y, tries + 1, D.KEY_WALK_TRIES))
	D.takeFloorItem(k, { k.Id }, 'key')

	local got = heldKeys()[k.Id] == true
	if got and not had then
		D.keyWalkFail[kk] = nil
		say('key picked up')
		log(string.format('key %d picked up from %d,%d', k.Id, x, y))
		return true
	end
	local still = false
	for _, o in ipairs(D.objScan(true)) do
		if o.Type == 3 and o.Id == k.Id then
			local t = o.Tile_XYZ
			if math.floor(t.x) == x and math.floor(t.y) == y then still = true break end
		end
	end
	if not still then
		D.keyWalkFail[kk] = nil
		return true
	end
	D.keyWalkFail[kk] = tries + 1
	D.dirty = true
	if D.keyWalkFail[kk] >= D.KEY_WALK_TRIES then
		warn(string.format('key %d at %d,%d did not come off the floor in %d tries - the plan stops chasing it',
			k.Id, x, y, D.KEY_WALK_TRIES))
	else
		warn(string.format('key %d at %d,%d still on the floor after try %d/%d',
			k.Id, x, y, D.keyWalkFail[kk], D.KEY_WALK_TRIES))
	end
	return true
end

-- Walk the drawn route to its end, then act on it: a ground key is picked up, a
-- doorway is opened. The walking is D.walkPath (one doorway click per room
-- boundary); this function only decides what the route ends at.
function D.runRoute(world, here, skip)
	if not (world and here) then return false end
	-- A PROGRESS DOORWAY ON THE FLOOR OUTRANKS EVERY LOCAL PLAN. A guardian door, or a
	-- locked door whose key is in the pack, is one-off progress and it is what the drawn
	-- route exists to reach; opening whatever ordinary door this room happens to have sends
	-- the player the other way while the dots point at the goal (live 13:29: a 58-dot route
	-- to the guardian door at 8616,480, and the player walked through a "back" door one tile
	-- away instead - "the dots go the right way, the player goes the other way"). Doorways
	-- on the way are still opened as the walk reaches them, so nothing is skipped - the route
	-- is just no longer detoured to every room on the floor. A room a puzzle solver owns
	-- keeps its pass either way.
	local progress = D.progressDoorPending(world)
	if progress and D.solverHoldsRoom and D.solverHoldsRoom(here) then return false end
	-- Otherwise the room plan owns the pass: nothing is routed or walked across the floor.
	if not progress and D.localPlanActive() then return false end
	local held, unknown = heldKeys()
	-- The room's OWN doorway outranks the floor route: while this room still has a
	-- doorway worth opening, that is the local plan - the sweep opens it, and drawing
	-- a route somewhere else would only fight it. Same predicate as the sweep, so the
	-- two can never disagree about whether the room is busy.
	if not D.bossOpen and not progress
		and D.roomDoorPlan(world, here, held, unknown, skip) then return false end
	D.setStateNow('walking the floor route')
	local plan = D.routePlan(world)
	if not plan then return false end
	-- The route ends on a key and no doorway is left between us and it: take it.
	-- This is the one thing that outranks opening a door.
	if plan.kind == 'key' and #plan.doors == 0 then return D.takePlannedKey(plan, world) end
	-- THE FLOOR WALK MUST NOT END THE RUN. walkPath reads live engine userdata (rooms,
	-- props, the walk set) and a transient engine error in there used to kill the script
	-- mid-floor - this is the same guard D.localRoom gives the room solvers.
	local okWalk, moved, w2 = pcall(D.walkPath, world)
	if not okWalk then
		local now = API.SystemTime()
		if not D.walkFailAt or (now - D.walkFailAt) > 10000 then
			D.walkFailAt = now
			warn(string.format('floor walk threw: %s - the route is re-planned next pass', tostring(moved)))
		end
		D.dirty = true
		return false
	end
	if w2 then world = w2 end
	-- Re-plan on the rescan: walking one doorway can bring a key into the walk set,
	-- or write a door off, and that has to change the goal in the same pass.
	plan = D.routePlan(world)
	if not plan then return moved end
	if plan.kind == 'key' then
		if #plan.doors == 0 then return D.takePlannedKey(plan, world) end
		return moved
	end
	local d, goal = plan.doors[1], plan.door
	if not d or d ~= goal then return moved end
	D.noWorkLogged = nil
	local gk = dkey(d)
	if D.routeSig ~= gk then
		D.routeSig = gk
		log(string.format('walk plan: door %d "%s" (%s) at %d,%d is the end of the drawn route',
			d.id, tostring(d.name), tostring(d.action), d.x, d.y))
	end
	say(string.format('opening door %d', d.id))
	tryOpen(d, world, here, S.attempts, S.badDoor, true)
	return true
end

-- One step back towards the nearest room that still has a doorway nobody has
-- tried. A dead-end room's own doorway is always traversed, so target selection
-- refuses it and the bot can stand in such a room forever; this is the way out.
-- Returns the doorway to click and the room it leads towards.
-- The doorway to actually MOVE towards this pass, as a plan rather than a click.
-- Returns (hop, goalDoor, goalRoom):
--   * hop == goalDoor  - that doorway can be clicked from where we stand: open it.
--   * hop ~= goalDoor  - the goal is in another room: click `hop`, the first doorway
--                        on a route of doors we are able to open, and the next pass
--                        plans the step after it.
--   * nil              - nothing on the floor can be reached yet.
-- The old code fed the highest-priority door straight to tryOpen, so a key door 69
-- tiles away behind an unopened doorway answered "no path within one tile" and was
-- refused once a second, thirty times in a row, while the bot never started
-- pathing towards it. Returning nil here is what lets the caller go and explore
-- instead of clicking through a wall.
function D.bestRouteTarget(world, adj, here, held, unknown, skip)
	-- The floor walker is off while a local room plan is in action: no candidate
	-- scoring, no room-graph routing, nothing that reaches past this room.
	if D.localPlanActive() then return nil end
	-- How many doorways are still shut? When exactly ONE is left, it is the floor's only
	-- objective and every worth/dead-end rule is noise: live, "route to door 50214 ...
	-- door 50444 ... skipping it" repeated while that one doorway stayed shut.
	local nShut = 0
	for _, d in ipairs(world.doors or {}) do
		local k = dkey(d)
		if not D.traversed[k] and not (S.badDoor and S.badDoor[k])
			and not isBossDoor(d) and not doorwayOpen(world, d) then
			nShut = nShut + 1
		end
	end
	local lastOne = (nShut == 1)
	-- Is the doorway WORTH opening? Opening it costs a walk and a click, and the room
	-- behind it may be one we have already been in and found empty, or the one we just
	-- came from. Scoring it first is what stops the bot forcing its way into every
	-- room it can reach.
	local cands = {}
	for _, d in ipairs(world.doors or {}) do
		local k = dkey(d)
		if not S.badDoor[k] and not D.traversed[k] and not isBossDoor(d)
			and not (S.unwalkable and S.unwalkable[k])
			and not (doorRecent(d) and not lastOne) and not doorNoKey(world, d)
			and doorClickable(d, world, held, unknown)
			and (D.bossOpen or not D.doorLeadsToBossRoom(world, d, here and here.idx))
			and not doorwayOpen(world, d) then
			local worth = 0
			if doorLeadsToWork(world, d, here, S.done, skip) then worth = worth + 4 end
			if D.doorLeadsToDeadRoom(world, d, here and here.idx, S.visitedEmpty, S.arrivedFrom) then
				worth = worth - 6          -- known empty / the room we came from
			end
			if D.doorLeadsToNewRoom(world, d, here and here.idx, D.visitedRooms) then
				worth = worth + 2          -- never stood in it
			end
			-- A key door we can pay for is always worth it: the key is worthless until
			-- it is spent and the room behind it was never judged from inside.
			if d.action == 'Unlock' and d.kind == 'key' then worth = worth + 3 end
			-- WORTH NOTHING, WALK NOWHERE. A doorway whose far room is known, holds
			-- nothing and has no way on is a dead end: it used to score exactly 0 and
			-- the `worth >= 0` test kept it, so "closest openable door" walked the bot
			-- from one empty room to the next for as long as the floor had any. Only a
			-- doorway that leads somewhere (or the floor's very last one) is a target
			-- now, and standing still is the answer when none does.
			if worth > 0 or lastOne then
				cands[#cands + 1] = { d = d, worth = worth }
			end
		end
	end
	table.sort(cands, function(a, b)
		if a.worth ~= b.worth then return a.worth > b.worth end
		local pa, pb = D.DOOR_PRIO[a.d.kind] or 9, D.DOOR_PRIO[b.d.kind] or 9
		if pa ~= pb then return pa < pb end
		return (a.d.dist or math.huge) < (b.d.dist or math.huge)
	end)
	for i = #cands, 1, -1 do cands[i] = cands[i].d end

	-- 1. A doorway we can already click. A doorway IN THIS ROOM (within
	-- D.CLICK_RANGE) is always attemptable: the click makes the client walk to it, and
	-- the only authority on whether that works is the client's answer ("You can't
	-- reach that" - handled by the chat reader). The batch reach flag was used to
	-- reject them, and it is a startpathreach answer about a BLOCKED tile taken at
	-- scan time: the disassembled Augmented doorway (7063,2216) and the barred door
	-- beyond it both came back "unreachable" and the floor was called finished with
	-- three doors shut. StarPath cannot answer in an instance either.
	local tested = 0
	for _, d in ipairs(cands) do
		if d.reach == true then return d, d end
		if (d.dist or math.huge) <= D.CLICK_RANGE then return d, d end
		if d.reach == nil and tested < D.ROUTE_TEST_MAX then
			tested = tested + 1
			if D.doorClickableNow(d) then return d, d end
		end
	end

	-- 2. Otherwise route towards one: the first doorway on a chain of doors we can
	-- open that ends in the goal's room.
	tested = 0
	for _, d in ipairs(cands) do
		if tested < D.ROUTE_BFS_MAX then
			tested = tested + 1
			local fr = D.doorFarRoom(world, d, here and here.idx)
				or roomNearRooms(world.rooms, d.x, d.y)
			if fr and here and fr.idx ~= here.idx then
				local hop = findHop(world, adj, here.idx, fr.idx, held, unknown, S.badDoor)
				if hop then return hop, d, fr end
			end
		end
	end
	return nil
end

local function frontierHop(world, adj, hereIdx, held, unknown, badDoor, skip, avoidKey)
	local seen, queue, head = { [hereIdx] = true }, { hereIdx }, 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		local room = world.rooms[cur]
		-- A room already known to hold nothing is never the goal of a walk: its own
		-- single doorway is the one we would enter through, so it always looks like
		-- a frontier from the outside and the bot kept walking into empty leaves.
		-- It stays usable as a room to pass THROUGH (findHop below ignores skip).
		if room and cur ~= hereIdx and room.idx == cur
			and not (skip and skip[rkey(room)])
			and not (D.visitedRooms and D.visitedRooms[rkey(room)])
			and not nearRoomKey(rkey(room), avoidKey) then
			for _, d in ipairs(room.doors or {}) do
				local k = dkey(d)
				if not D.traversed[k] and not S.badDoor[k] and doorClickable(d, world, held, unknown) then
					local hop = findHop(world, adj, hereIdx, cur, held, unknown, S.badDoor)
					-- Never hop through a doorway that was just used: that is the
					-- back-and-forth between two rooms that both still had one
					-- untried door. Also skip a frontier that is the room we came
					-- from - the corner keys are not stable, hence nearRoomKey.
					-- and never through one the client cannot walk to: the click
					-- lands nowhere, the player never moves, and the pass repeats
					-- itself forever (dump: 24 tiles away, "still on this side" x6).
					if hop and not doorRecent(hop) then return hop, cur end
				end
			end
		end
		for _, e in ipairs(adj[cur] or {}) do
			if not seen[e.room] then
				seen[e.room] = true
				queue[#queue + 1] = e.room
			end
		end
	end
	return nil
end

-- Which doorway cuts the route to a room, ignoring whether we can open it. Used
-- only to explain a give-up: "cannot be reached" is useless without naming the
-- door that is in the way.
local function blockingDoor(world, adj, startIdx, goalIdx, held, unknown)
	if startIdx == goalIdx then return nil end
	local prev, seen = {}, { [startIdx] = true }
	local queue, head = { startIdx }, 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		for _, e in ipairs(adj[cur]) do
			if not seen[e.room] then
				seen[e.room] = true
				prev[e.room] = { from = cur, door = e.door }
				if e.room == goalIdx then
					local step = goalIdx
					while prev[step] and prev[step].from ~= startIdx do step = prev[step].from end
					if not prev[step] then return nil end
					local d = prev[step].door
					if not hasKeyFor(d, held, unknown) then return d end
					return nil
				end
				queue[#queue + 1] = e.room
			end
		end
	end
	return nil
end

-- Breadth-first over the room graph: expands one ring at a time (1x4, 4x4, 8x8).
-- Two passes so content always beats exploring: keys first, then the nearest room
-- with a doorway nobody has walked through yet.
--
-- `avoidKey` is the room we arrived from, as its stable minx:miny key (room
-- indices are rebuilt on every rescan). Daemonheim rooms are mostly empty, so two
-- rooms with unopened doors kept choosing each other as "the room with work" and
-- the bot walked the same doorway forever. Refusing the room we just left breaks
-- that cycle; the room is still reachable when it holds a key or an enemy.
local function findTarget(world, adj, startIdx, done, held, unknown, badDoor, skip, avoidKey, onlyKey)
	for pass = 1, 2 do
		local queue, dist, prev = { startIdx }, { [startIdx] = 0 }, {}
		local head = 1
		while head <= #queue do
			local cur = queue[head]
			head = head + 1
			local r = world.rooms[cur]
			local ring = dist[cur]
			local isOnly = onlyKey ~= nil and rkey(r) == onlyKey

			if cur ~= startIdx and (onlyKey == nil or isOnly)
				and not S.done[rkey(r)] and not (skip and skip[rkey(r)]) then
				local why = nil
				if pass == 1 then
					-- intrinsic work: something to pick up. Enemies are not work - a room
					-- with nothing but monsters leads nowhere, and routing to it is how
					-- the bot walked into rooms that were empty of anything useful.
					if #r.keys > 0 then
						why = string.format('%d key(s)', #r.keys)
					end
				elseif not nearRoomKey(rkey(r), avoidKey) then
					-- Unexplored doorway: the room behind it is the unknown part. Only a
					-- doorway this room can actually open, into a room that is not
					-- already known to hold nothing, is worth the walk. Walking to a
					-- room just because it still has a door we have not used yet is
					-- what sent runs into empty leaves.
					for _, d in ipairs(r.doors or {}) do
						local k = dkey(d)
						if not D.traversed[k] and not S.badDoor[k]
							and doorClickable(d, world, held, unknown) then
							local other = false
							for side in pairs(d.sides or {}) do
								local o = world.rooms[side]
								if o and side ~= r.idx then
									other = true
									local ok2 = rkey(o)
									if not S.done[ok2] and not (skip and skip[ok2]) then
										why = string.format('%d door(s)', #r.doors)
									end
								end
							end
							-- Closed door with nothing drawn behind it: unknown, and
							-- unknown is what exploration is for.
							if not other then why = string.format('%d door(s) undrawn', #r.doors) end
						end
					end
				end
				if why then
					return cur, ring, prev, why
				end
			end

			for _, e in ipairs(adj[cur]) do
				local d = e.door
				if doorClickable(d, world, held, unknown) and not S.badDoor[dkey(d)]
					and not doorNoKey(world, d) and not dist[e.room] then
					dist[e.room] = ring + 1
					prev[e.room] = cur
					queue[#queue + 1] = e.room
				end
			end
		end
	end
	return nil
end

-- The client walks the player into range and interacts. Wait for the walk to
-- finish before clicking, and let the click land before the next one.
local function openDoor(d, world)
	if not D.canClickNow(3000) then
		D.moveGuardLog = D.moveGuardLog or {}
		local mk = dkey(d)
		if not D.moveGuardLog[mk] then
			D.moveGuardLog[mk] = true
			log(string.format('door %d at %d,%d: still walking - holding the click', d.id, d.x, d.y))
		end
		return false     -- nothing clicked, so the caller must not count an attempt
	end
	local px0, py0 = ptile()
	-- the walk has just ended, but the client is still settling the arrival. Going
	-- straight in from here is what produced the double door click.
	API.RandomSleep2(350, 150, 250)
	-- THE wall test. startpathreach = 1 asks "can the client path to within one tile
	-- of this leaf", which a closed door in this room passes (the path only has to
	-- reach the tile beside it) and a door through a wall fails. That distinction is
	-- the whole filter, and it is the only thing that stops clicks through a wall -
	-- verified live: a guardian door three tiles away across a wall answers false at
	-- tolerance 1, while closed key doors in the same room answer true.
	-- startpathreach = 1 ("can the client path to within one tile of it") is the wall
	-- test, and it is the ONLY thing that stops clicks through a wall - a closed door
	-- still passes it (the path only has to reach the tile beside the leaf), so it
	-- does not block doors we still have to open. Verified live: a guardian door three
	-- tiles away across a wall answers false at tolerance 1.
	-- Reach check, scoped to what it can actually answer: a doorway further than the
	-- room (D.CLICK_RANGE) needs the client to agree it can be pathed to, otherwise the
	-- click lands nowhere. A doorway INSIDE the room is always attempted - the click
	-- walks the player to it, and the batch startpathreach flag calls every blocked
	-- doorway tile "unreachable" (it rejected the doorway a disassembled skill door
	-- becomes, and the barred door and guardian door behind it, then declared the floor
	-- finished). StarPath cannot answer inside an instance either, so the client's own
	-- "You can't reach that" reply is the authority there.
	local farDoor = math.max(math.abs(d.x - px0), math.abs(d.y - py0)) > D.CLICK_RANGE
	if farDoor and not D.doorClickableNow(d) then
		D.refusedAt[dkey(d)] = { t = API.SystemTime(), room = D.here and rkey(D.here) or '' }
		if not D.noReachLogged then D.noReachLogged = {} end
		local nk = dkey(d)
		if not D.noReachLogged[nk] then
			D.noReachLogged[nk] = true
			log(string.format('door %d at %d,%d is not in this room and has no path to it - not clicking it',
				d.id, d.x, d.y))
		end
		return false
	end
	-- Test, don't walk. A doorway can be 11 tiles away and behind a wall (the room
	-- segmentation merges rooms, and the graph joins rooms it should not), and the
	-- click is then answered "You can't reach that" and the door gets blacklisted for
	-- the floor. The client's own walk set answers that with a BFS at tolerance 1:
	-- a closed doorway of THIS room still passes (the tile beside it is walkable),
	-- a doorway with a wall or another room in between does not. This replaces the
	-- old walk-plan test, which only ran when the room model claimed the door was in
	-- our room - exactly the case where the model was already wrong.
	-- THE WALL TEST RUNS AT EVERY DISTANCE. It used to be `gap > 2`, on the reasoning that a
	-- doorway of this room is always attempted - which let a door TWO TILES away across a wall
	-- through (the reported "clicked Drain on a divine door through walls"). D.doorWalkReach
	-- now answers "cannot judge" instead of "no" when the walk set has not mapped the area, so
	-- running it unconditionally cannot lock the bot out of a doorway it has not walked to yet.
	do
		local ok, why = D.doorWalkReach(d, 1, world)
		if not ok then
			D.wallHit, D.noReachLogged = D.wallHit or {}, D.noReachLogged or {}
			D.wallHit[dkey(d)] = { t = API.SystemTime(), room = D.here and rkey(D.here) or '' }
			if not D.noReachLogged[dkey(d)] then
				D.noReachLogged[dkey(d)] = true
				log(string.format(
					'door %d at %d,%d is not walkable from %d,%d (%s) - that is through a wall, skipping it',
					d.id, d.x, d.y, px0, py0, tostring(why)))
			end
			return false
		end
	end
	local item = d.item
	-- last line of defence: re-read the keys right before clicking. Every caller
	-- is supposed to have checked already, and a locked door we cannot pay for
	-- must never be clicked no matter which path got here.
	local held, unknown = heldKeys()
	if not hasKeyFor(d, held, unknown) then
		-- A KEY DOOR THAT IS ALREADY OPEN IS NOT A KEY DOOR ANY MORE. Daemonheim keeps the
		-- Unlock leaf standing after the key is spent, so this test refused the doorway for
		-- ever afterwards and cut every route through a door the bot had opened itself (live:
		-- "REFUSED door 50221 ... needs 18228 cvar 1825 value 0" every few seconds, with the
		-- silver triangle key 18218 lying 8 tiles behind that very doorway). The way through
		-- an opened key door is its partner leaf, which is an ordinary Enter leaf.
		local alt = nil
		if d.action == 'Unlock' then
			for _, o in ipairs((world and world.doors) or {}) do
				local sameAxis = (o.x == d.x and math.abs(o.y - d.y) <= 1)
					or (o.y == d.y and math.abs(o.x - d.x) <= 1)
				if sameAxis and dkey(o) ~= dkey(d)
					and (o.action == 'Enter' or o.action == 'Open')
					and (D.traversed[dkey(d)] or D.traversed[dkey(o)]) then
					alt = o
					break
				end
			end
		end
		if alt then
			log(string.format(
				'door %d at %d,%d has already been opened - acting on its Enter leaf %d at %d,%d instead of unlocking it again',
				d.id, d.x, d.y, alt.id, alt.x, alt.y))
			d, item = alt, alt.item
		else
			warn(string.format('REFUSED door %d "%s" %s: needs %s cvar %s value %s',
				d.id, tostring(d.obj and d.obj.Name), tostring(d.action),
				tostring(item), tostring(item and D.keyCvar[item]),
				tostring(item and readKeyVar(D.keyCvar[item]))))
			return false
		end
	end
	say(string.format('%s door %d "%s"', d.kind, d.id, tostring(d.action)))
	-- THE LEAF WE ACT ON MUST BE THE LEAF ON OUR SIDE. The scan hands back whichever leaf
	-- it saw, and a doorway's other leaf sits one tile away behind the wall: clicking it
	-- is answered "You can't reach that", the player never moves and the doorway stays
	-- shut however many times it is tried (live: the Guardian door 50348 and 50344 both
	-- logged "unreachable" while the sweep kept clicking them). D.leafInReach asks the
	-- walk BFS which leaf has floor we can walk to, so that is the one clicked; the record
	-- `d` still owns the key, the tries and the write-off.
	local tgt = ((d.action == 'Enter' or d.action == 'Open') and D.leafInReach(world, d)) or d
	if tgt.x ~= d.x or tgt.y ~= d.y or tgt.id ~= d.id then
		log(string.format('door %d at %d,%d: acting on the near leaf %d at %d,%d - the other side is behind the wall',
			d.id, d.x, d.y, tgt.id, tgt.x, tgt.y))
	end
	if d.action == 'Unlock' and d.kind == 'key' then
		local cvar = item and D.keyCvar[item]
		warn(string.format('KEY DOOR %d "%s" unlocking with %s cvar %s value %s',
			d.id, tostring(d.obj and d.obj.Name), tostring(item), tostring(cvar),
			tostring(cvar and readKeyVar(cvar))))
	end
	-- A disabled object (Bool1 = 1) is still in the client - the engine only marks it
	-- - and the engine DROPS any interact aimed at it. The world model is a cache
	-- (D.WORLD_TTL), so the click is decided on the LIVE object on that tile, and
	-- the live record is what gets sent.
	local live, dead = D.liveObjectAt(tgt.id, tgt.x, tgt.y)
	if live == false then
		D.refusedAt[dkey(d)] = { t = API.SystemTime(), room = D.here and rkey(D.here) or '' }
		log(string.format(
			'door %d at %d,%d is disabled in the live scan (Bool1=%s action "%s") - the engine would drop the click',
			tgt.id, tgt.x, tgt.y, tostring(dead and dead.Bool1), tostring(dead and dead.Action)))
		return false
	end
	if not live then
		D.refusedAt[dkey(d)] = { t = API.SystemTime(), room = D.here and rkey(D.here) or '' }
		log(string.format('door %d at %d,%d is not in the live scan any more - not clicking it',
			tgt.id, tgt.x, tgt.y))
		-- A doorway REMEMBERED from an older scan (S.floorDoors) that is not there any more
		-- when we stand beside it was never a doorway, or is gone with its room. Drop it, or
		-- the floor can never be counted finished and the bot keeps walking back to nothing.
		if d.memory and S.floorDoors
			and math.max(math.abs(d.x - px0), math.abs(d.y - py0)) <= 8 then
			S.floorDoors[pkey(d.x, d.y)] = nil
			S.badDoor[dkey(d)] = true
			log(string.format('door %d at %d,%d is not there any more - forgotten for this floor',
				d.id, d.x, d.y))
		end
		return false
	end
	-- Still animating from the previous interaction (an unlock in progress, a chop,
	-- a barricade being forced)? Clicking now is dropped by the client AND the world
	-- cache still shows the old leaf, so the caller's "still closed" verdict would be
	-- about a door that is in the middle of opening. Wait the animation out, then
	-- re-read the live object - it may be gone (opened) even though the cached leaf
	-- has not refreshed yet.
	if D.playerBusy() then
		if not D.waitAnim(2500) then
			log(string.format('door %d at %d,%d: player is still animating - not clicking it again',
				d.id, d.x, d.y))
			return false
		end
		local live2 = D.liveObjectAt(tgt.id, tgt.x, tgt.y)
		if not live2 then
			-- the door changed state while we waited: the next pass will see the
			-- new leaf and click Enter, which is the crossing
			return false
		end
		live = live2
	end
	-- Hold the doorway from the click itself, not from the answer. A click on a doorway
	-- across the room is a WALK and the crossing happens at the end of it, so a pass that
	-- lands in the middle of that walk must not click the doorway again - that is the
	-- live "second click when we were already on the other side".
	D.noteDoorClickAt(tgt.x, tgt.y)
	local mx0, my0 = ptile()
	-- THE ROUTE IS THE CLIENT FUNCTION THE DLL USES TO ACTION THE OBJECT
	-- (D.ROUTE_OBJ = API.OFF_ACT_GeneralObject_route0). A leaf that route0 cannot
	-- action is not necessarily dead - it may be handled by another of the object
	-- routes - so a click that produced NOTHING at all escalates one rung, and the
	-- doorway is only written off once every named route has been tried. The ladder is
	-- built here, inside Lua, because these constants are not exported to the bridge.
	if not D.OBJ_ROUTES then
		D.OBJ_ROUTES = {}
		for _, r in ipairs({
			D.ROUTE_OBJ,
			API.OFF_ACT_GeneralObject_route1,
			API.OFF_ACT_GeneralObject_route2,
			API.OFF_ACT_GeneralObject_route3,
			API.OFF_ACT_GeneralObject_route00,
		}) do
			if r then D.OBJ_ROUTES[#D.OBJ_ROUTES + 1] = r end
		end
		if #D.OBJ_ROUTES == 0 then D.OBJ_ROUTES[1] = D.ROUTE_OBJ end
	end
	local doorK = dkey(d)
	D.routeIdx = D.routeIdx or {}
	local ri = D.routeIdx[doorK] or 1
	if ri > #D.OBJ_ROUTES then ri = #D.OBJ_ROUTES end
	D.clickObjectDirect(tgt.action, live, D.OBJ_ROUTES[ri])
	-- remember what we clicked: the client's answer ("you'll need the key") has no
	-- target in it, so the answer is only usable if we know which doorway it was
	D.lastDoorTile = dkey(d)
	-- A SKILL OBSTACLE IS DELETED BY USING IT. Note the moment: if this leaf is missing
	-- from the next live scan while we are still close, it is gone for good and the floor
	-- plan has to forget it (see scanWorld). Without this the route kept targeting a runed
	-- door it had already imbued - "walk plan: door 50280 "Runed door" (Imbue-energy) ...
	-- is the end of the drawn route" long after "You successfully imbue the rune door".
	if d.kind == 'skill' then
		D.skillWorked = D.skillWorked or {}
		D.skillWorked[dkey(d)] = API.SystemTime()
		D.skillMiss = D.skillMiss or {}
		D.skillMiss[dkey(d)] = nil
	end
	-- Wait for the walk the click started instead of a fixed sleep: the caller waits
	-- for the doorway itself (farLeafOf) before clicking again, so a long fixed wait
	-- here is pure latency. An Unlock is the exception - the key has to be spent
	-- server side before the leaf reads "Enter".
	--
	-- settle() is useless on its own right after a click: the walk only starts on
	-- the next game tick, so isMoving() is still false and it returns at once. That
	-- is what let the callers fire a second click 280 ms later, inside the tick the
	-- client had not answered yet.
	if d.action == 'Unlock' or d.kind == 'skill' then
		-- Hold the doorway from the moment it is clicked. The leaf only changes after
		-- the server spends the key, and without this stamp the next pass picked the
		-- same leaf again: one gold rectangle door was clicked at 47.4 / 50.6 / 53.3 s
		-- and had already been unlocked by the FIRST of those.
		D.doorUsed[dkey(d)] = API.SystemTime()
		-- A click on a door that is 9 tiles away only starts a WALK: the unlock or the
		-- repair happens on arrival, so "no player animation 1.2 s after the click"
		-- says nothing. Wait the walk out first, then the animation that follows it.
		local px0, py0 = ptile()
		D.waitMove(px0, py0, 8000)
		if not D.waitAnimStart(1500) then
			-- neither moved nor animated: the client really did drop this one. Logged
			-- once per door, and the caller still decides - the leaf may be gone.
			D.noAnimLogged = D.noAnimLogged or {}
			local nk = dkey(d)
			if not D.noAnimLogged[nk] then
				D.noAnimLogged[nk] = true
				log(string.format(
					'door %d "%s" %s: click produced no walk and no animation at all',
					d.id, tostring(d.obj and d.obj.Name), tostring(d.action)))
			end
		end
		-- the key is spent / the door gives way a moment after the animation
		API.RandomSleep2(500, 200, 300)
	else
		API.RandomSleep2(700, 200, 300)
	end
	-- A SHUT door that answers NOTHING escalates the route ladder instead of being
	-- written off on the spot: no walk, no animation and the leaf still there means
	-- THIS ROUTE reached nothing, not that the door is dead. Only after the last
	-- named route has also produced nothing is the doorway dropped for this floor.
	-- A door that ever moves us or plays an animation clears the rung, so a slow but
	-- working door is never written off.
	if d.action ~= 'Unlock' and d.kind ~= 'skill' then
		local px1, py1 = ptile()
		if px1 == mx0 and py1 == my0 and not D.playerBusy() and D.liveObjectAt(d.id, d.x, d.y) then
			if ri < #D.OBJ_ROUTES then
				D.routeIdx[doorK] = ri + 1
				say('that door did not answer - trying another action route')
				log(string.format(
					'door %d "%s" at %d,%d %s: route %d produced no walk and no animation - trying route %d of %d next',
					d.id, tostring(d.name), d.x, d.y, tostring(d.action), ri, ri + 1, #D.OBJ_ROUTES))
			elseif S.badDoor then
				D.routeIdx[doorK] = nil
				S.badDoor[doorK] = true
				say('that door will not open - taking another way')
				if d.kind == 'guardian' then
					-- A GUARDIAN DOORWAY IS NOT OPENED BY CLICKING IT. It opens when the
					-- guardians that guard it are dead, so "answered nothing" here is not a
					-- broken door - it is a door whose room still has to be cleared. Say that
					-- instead of "written off", which reads like the doorway is gone.
					log(string.format(
						'guardian door %d at %d,%d answered nothing on all %d action route(s) - it opens when its guardians die, not by clicking; leaving it to the room',
						d.id, d.x, d.y, #D.OBJ_ROUTES))
				else
					log(string.format(
						'door %d "%s" at %d,%d %s answered nothing on all %d action route(s) - written off for this floor',
						d.id, tostring(d.name), d.x, d.y, tostring(d.action), #D.OBJ_ROUTES))
				end
			end
		else
			D.routeIdx[doorK] = nil
		end
	end
	settle()
	return true
end

-- The leaf that actually walks you through a doorway: the Unlock leaf only
-- unlocks, the Enter/Open leaf on the same doorway is what moves the player.
local function enterLeaf(world, d)
	-- THE LEAF HAS TO BE THE ONE ON OUR SIDE. The old rule returned the first same-axis
	-- Enter/Open leaf in scan order, which is the far leaf about as often as the near one:
	-- clicking it is answered "You can't reach that", the player never moves and the
	-- doorway stays shut (live: the Guardian door 50348 and 50344 both logged
	-- "unreachable" while the sweep kept clicking them). D.leafInReach asks the walk BFS
	-- which leaf actually has floor we can walk to, so that answer wins outright.
	local reach = D.leafInReach(world, d)
	if reach and D.interactable(reach.obj) then return reach end
	local near = nil
	for _, o in ipairs(world.doors or {}) do
		-- no option on it = nothing to click; the client answers "There is no
		-- interaction on object!" and the player never moves
		if (o.action == 'Enter' or o.action == 'Open') and not isBossDoor(o)
			and D.interactable(o.obj) then
			-- the same tile first: a +/-1 tolerance alone happily hands back the
			-- doorway next to it, which is how the wrong door got clicked open
			if o.x == d.x and o.y == d.y then return o end
			local sameAxis = (o.x == d.x and math.abs(o.y - d.y) <= 1)
				or (o.y == d.y and math.abs(o.x - d.x) <= 1)
			if sameAxis and not near then near = o end
		end
	end
	return reach or near or d
end

-- ONE DOORWAY, ONE CLICK. A click that has just gone out has to hold until its walk has
-- played out; a second click while the player is on the move only retargets the walk the
-- client already has in hand. The two leaves of a Daemonheim doorway sit one tile apart and
-- either may be the one picked next, so the stamp covers the tile AND its four neighbours -
-- that is what stops "clicks the doorway and then the previous (or forward) door side in
-- the same second".
function D.noteDoorClickAt(x, y)
	if not (x and y) then return end
	x, y = math.floor(x), math.floor(y)
	local now = API.SystemTime()
	D.openClickAt = D.openClickAt or {}
	D.openClickAt[x .. ',' .. y] = now
	for i = 1, #D.DIR4 do
		D.openClickAt[(x + D.DIR4[i][1]) .. ',' .. (y + D.DIR4[i][2])] = now
	end
end

-- The click did not move us: drop the stamp so the next pass may click at once.
function D.forgetDoorClick(x, y)
	if not (x and y) then return end
	x, y = math.floor(x), math.floor(y)
	D.openClickAt = D.openClickAt or {}
	D.openClickAt[x .. ',' .. y] = nil
	for i = 1, #D.DIR4 do
		D.openClickAt[(x + D.DIR4[i][1]) .. ',' .. (y + D.DIR4[i][2])] = nil
	end
end

function D.doorClickInFlight(x, y, holdMs)
	if not (x and y) then return false end
	x, y = math.floor(x), math.floor(y)
	D.openClickAt = D.openClickAt or {}
	local now = API.SystemTime()
	holdMs = holdMs or D.DOOR_CLICK_HOLD or 1500
	-- A click that started a walk is STILL IN FLIGHT until the player stops: the live
	-- case was a doorway clicked from eight tiles away, whose crossing finished 5 s
	-- later - the 1.5 s hold had lapsed mid-walk and the next pass clicked the same
	-- doorway from the far side, earning "You can't reach that."
	local moving = (D.walkLive and D.walkLive()) or (D.isMovingNow and D.isMovingNow())
	local walkHold = D.DOOR_WALK_HOLD or 12000
	for i = 0, #D.DIR4 do
		local kx, ky = x, y
		if i > 0 then kx, ky = x + D.DIR4[i][1], y + D.DIR4[i][2] end
		local t = D.openClickAt[kx .. ',' .. ky]
		if t then
			local age = now - t
			if age < holdMs or (moving and age < walkHold) then return true end
		end
	end
	return false
end

-- Run to a doorway the client can path to. Clicking the DOOR is what makes the client
-- walk the player over and interact; a ground-tile click cannot do it, because the
-- doorway's own tile is blocked collision. Ground tiles stay only for places where there
-- is nothing at all to click (stepping stones, pads, platforms).
function D.approachDoor(d, world)
	if not (d and world) then return false end
	if D.stopped() then return false end
	local leaf = enterLeaf(world, d)
	local act = (leaf.action == 'Open') and 'Open' or 'Enter'
	local lx, ly = leaf.x or d.x, leaf.y or d.y
	local lz = (leaf.obj and leaf.obj.Tile_XYZ or {}).z
	D.lastDoorTile = dkey(d)
	-- remembered before the click: D.walkPath refuses to click this doorway again for
	-- D.DOOR_CLICK_HOLD, and a door opened from here was otherwise clicked a second time
	-- from under the opening animation
	D.noteDoorClickAt(lx, ly)
	if not D.clickScanned(leaf.obj, act, lx, ly, lz, 20) then
		D.clickObject(act, d.id, lx, ly, lz, 50)
	end
	return true
end

-- Rooms the bot has actually stood in and left because there was nothing to do
-- there. The door model can be optimistic about a merged room (doorways from the
-- next room over are attached to it), so being there and finding nothing is the
-- only trustworthy "this is a dead end" - and it must be remembered, otherwise
-- the route planner happily sends it back in, twice and more.

-- Last way out of a room: every doorway here has been used already, so nothing is
-- selectable and the bot used to sit in the dead end until the run stopped. Cross
-- back out through the nearest reachable doorway - the room behind it still has
-- untried doors. Only reachable ones are clicked, so this never asks the client
-- for something it will answer with "You can't reach that".

local function leaveRoom(world, here, markEmpty, skip)
	if not here then return false end
	-- One abandonment per room per floor. Without this the two rooms that still had
	-- nothing but locked key doors crossed each other eight times in twenty seconds
	-- (live: 7265:2209 <-> 7265:2193, "trapped in room ... crossed back out" each way).
	-- The second attempt is not a new idea, it is the same one again.
	S.leftRooms = S.leftRooms or {}
	if S.leftRooms[rkey(here)] then return false end
	-- S.leaveFails only existed as a floor-reset assignment, so the very first back door
	-- that failed before any reset ran (a script started mid-floor) crashed the chunk on
	-- a nil index. It is a default in dung_state now and guarded here as well.
	S.leaveFails = S.leaveFails or {}
	S.visitedEmpty = S.visitedEmpty or {}
	local px, py = ptile()
	-- No room sweep here: walking around to widen the object scan is navigation, and the
	-- rule for this script is that a ground-tile walk is only ever used inside a special
	-- puzzle or a boss sequence. If the way out is not visible yet, the door sweep and the
	-- router keep looking; they do not wander.
	-- Evidence for the dump: every doorway the map puts INSIDE this room and why
	-- none of them was clicked. Without it "it walked in and straight back out" is
	-- unanswerable - is the door missing from the room's list, or is it rejected?
	local before = roomNearRooms(world.rooms, px, py)
	local report, held, unknownK = {}, heldKeys()
	for _, d in ipairs(world.doors or {}) do
		if doorInRoom(here, d) and not D.traversed[dkey(d)] then
			report[#report + 1] = string.format('%d/%s%s', d.id, tostring(d.action),
				hasKeyFor(d, held, unknownK) and '/openable' or '/locked')
		end
	end
	if #report > 0 then
		log(string.format('room %s left with doors inside it: %s',
			rkey(here), table.concat(report, ' ')))
	end
	local back, backD = nil, math.huge
	local deadDoor, deadDoorD = nil, math.huge
	-- world.doors, not here.doors: the room's own list is built from leaf edges and
	-- a doorway on the room's wall can be listed for the room next door, which left
	-- this one with nothing to click even though the door was right there.
	for _, d in ipairs(world.doors or {}) do
		if doorInRoom(here, d) and not doorNoKey(world, d)
			and (doorReachable(d) or D.traversed[dkey(d)]) then
			local dx, dy = d.x - px, d.y - py
			local v = dx * dx + dy * dy
			-- A DOOR INTO A DEAD END IS NOT A WAY OUT. Live: "door 50298 at 12040,671 did
			-- not get us out of room 12032:640" - the nearest doorway was picked whatever
			-- was behind it, and behind it was a room with nothing in it, so the way out
			-- led straight back in. A doorway into a room we already abandoned, or one
			-- deadEnds() already knows holds nothing, is only used when this room has no
			-- other doorway at all.
			local leads = doorLeadsToWork(world, d, here, S.done, skip)
				and not D.doorLeadsToDeadRoom(world, d, here.idx, S.visitedEmpty, S.arrivedFrom)
			if leads then
				if v < backD then backD, back = v, d end
			elseif v < deadDoorD then deadDoorD, deadDoor = v, d end
		end
	end
	if not back then back, backD = deadDoor, deadDoorD end
	if not back then return false end
	say('no way on - crossing back out')
	if not openDoor(back, world) then return false end
	D.dirty = true
	-- the click opened it; walking out is a second click on the Enter leaf, but only
	-- once the walk it started has actually been seen to start and stop. Checking
	-- "did not move" a few hundred ms after the click is meaningless: the walk only
	-- begins on the next game tick.
	D.waitMove(px, py, 6000)
	local px2, py2 = ptile()
	if px2 == px and py2 == py then
		local bl = enterLeaf(world, back)
		D.clickScanned(bl.obj, 'Enter', bl.x, bl.y, (bl.obj and bl.obj.Tile_XYZ or {}).z, 20)
		API.RandomSleep2(700, 250, 400)
		waitStill(3000)
		px2, py2 = ptile()
	end
	-- Did we actually get to the other side of that doorway? The room key cannot answer
	-- this: segmentation merges rooms, and inside one blob a crossing changes no key - which
	-- turned every successful exit into "door 50298 did not get us out of room ..." and kept
	-- the escape being re-planned. crossedDoorway is the geometric answer (which side of the
	-- doorway we were on, and which side we are on now).
	local after = roomNearRooms(world.rooms, px2, py2)
	local movedOut = crossedDoorway(back, px, py, px2, py2)
		or (before and after and after.idx ~= before.idx)
	if movedOut then
		if before then S.arrivedFrom = rkey(before) end
		S.leftRooms[rkey(here)] = true      -- one abandonment per room, see the top
		if markEmpty then S.visitedEmpty[rkey(here)] = true end
		log(string.format('trapped in room %s - nothing left there, crossed back out through door %d at %d,%d',
			before and rkey(before) or rkey(here), back.id, back.x, back.y))
		return true
	end
	S.leaveFails[rkey(here)] = (S.leaveFails[rkey(here)] or 0) + 1
	log(string.format('door %d at %d,%d did not get us out of room %s (%d,%d -> %d,%d)',
		back.id, back.x, back.y, before and rkey(before) or '?', px, py, px2, py2))
	return false
end

-- A door that is clicked but does not move the player is retried up to 3 times,
-- then written off so the bot never grinds on the same doorway.
-- Which side of the doorway a tile is on, along the doorway's own axis.
local function doorSide(d, x, y)
	local dx, dy = x - d.x, y - d.y
	if math.abs(dx) >= math.abs(dy) then
		return (dx >= 0) and 1 or -1, dx
	end
	return (dy >= 0) and 1 or -1, dy
end

-- Did the player end up on the far side of this doorway? The rooms cannot answer
-- this: segmentation merges several rooms into one blob, and inside a blob a
-- crossing changes no room key - which made every doorway report "opened but not
-- crossed" and kept the bot walking the same three of them.
function crossedDoorway(d, px, py, px2, py2)
	-- THE AXIS IS FIXED BY WHERE WE STARTED. doorSide() picks the dominant axis of the
	-- player's offset, and that axis flips when a walk changes |dx| against |dy| - so a walk
	-- that never touched the doorway still reported a crossing. Live: a walk from 8609,487
	-- towards the guardian door at 8616,480 starts on the exact diagonal (|dx| == |dy|), so
	-- one step sideways moved the answer from "this side" to "the other side" and the
	-- doorway was marked walked through with the door still shut - it then stayed out of
	-- every route for the rest of the floor. Both ends are measured on ONE axis now.
	local dx0, dy0 = px - d.x, py - d.y
	local axisX = math.abs(dx0) >= math.abs(dy0)
	local v0 = axisX and dx0 or dy0
	if v0 == 0 then return false end       -- started on the doorway tile itself
	-- ...and the crossing has to happen AT the doorway: two tiles is the depth of a
	-- Daemonheim doorway (two leaves, one tile each); anything further walked around it.
	if math.max(math.abs(px2 - d.x), math.abs(py2 - d.y)) > 2 then return false end
	local v1 = axisX and (px2 - d.x) or (py2 - d.y)
	-- BEING LEVEL WITH THE DOORWAY IS NOT BEING THROUGH IT, AND NEITHER IS WALKING PAST IT.
	-- v1 == 0 means the player ended up on the doorway's own line but beside the leaf - which
	-- is exactly where a walk that stops in front of a door lands. Live 07:17:51, the gold
	-- diamond doorway 50265 at 14750,4712 was marked crossed while the player stood at
	-- 14750,4711, one tile NORTH of the door he had just unlocked: the doorway went into
	-- D.traversed and doorUsed, so every later attempt to enter it was suppressed and the floor
	-- kept planning through a door it had never passed.
	-- A passage tile and the tile beyond a doorway share a row (or a column), so the player
	-- must END on the doorway's own line: walking one tile PAST it on the neighbouring row
	-- is not crossing it either.
	if v1 == 0 then return false end
	local perpEnd = axisX and (py2 - d.y) or (px2 - d.x)
	if perpEnd ~= 0 then return false end
	return (v1 >= 0) ~= (v0 >= 0)
end


-- Is this doorway OPEN? A doorway is two leaves, one per side, and the client only
-- loads the far side once the door is open - a closed doorway shows a single leaf.
-- The types are random (one leaf is Object 0, the other Decor 12, either way round),
-- the action word is not: both sides read "Enter". Verified live: 50346
-- "Guardian door" type 0 at 14168,4527 paired with 50342 "Door" type 12 at
-- 14168,4528, while the closed key door at 14168,4536 stood alone.
local function farLeafOf(d)
	for _, o in ipairs(D.objScan()) do
		if (o.Action or '') == 'Enter'
			and not string.find(string.lower(o.Name or ''), D.BOSS_DOOR_NAME, 1, true) then
			local t = o.Tile_XYZ
			local dx = math.abs(math.floor(t.x) - d.x)
			local dy = math.abs(math.floor(t.y) - d.y)
			if (dx == 0 and dy == 1) or (dy == 0 and dx == 1) then
				return o
			end
		end
	end
	return nil
end


tryOpen = function(d, world, here, attempts, badDoor, allowFar)
	-- Hard stop, one choke point: until D.bossOpen is flipped no code path may click
	-- a doorway that leads into the boss room - not the sweep, not a hop, not the
	-- boss routing itself.
	if not D.bossOpen and D.doorLeadsToBossRoom(world, d, here and here.idx) then
		if not D.bossRefuseLog then
			D.bossRefuseLog = true
			log(string.format('refusing door %d "%s" at %d,%d: it leads into the boss room and the floor is not finished',
				d.id, tostring(d.obj and d.obj.Name), d.x, d.y))
		end
		return false
	end
	-- Second chance at the same rule, asked of the LIVE scan: the boss door marker only
	-- streams in when it is close, so the world model above can be blind to it at the
	-- exact moment a key door is being unlocked - and a key door is exempt from every
	-- other "is it worth it" test, so it gets opened and the bot walks into the boss
	-- room. This is the last check before the key is spent.
	if not D.bossOpen and D.nearBossMarker(d) then
		D.bossRefuseLog = D.bossRefuseLog or false
		if not D.bossMarkerLog then
			D.bossMarkerLog = {}
			local mk = dkey(d)
			if not D.bossMarkerLog[mk] then
				D.bossMarkerLog[mk] = true
				log(string.format(
					'refusing door %d "%s" at %d,%d: the boss door marker is right beside it - that is the boss room',
					d.id, tostring(d.obj and d.obj.Name), d.x, d.y))
			end
		end
		return false
	end

	-- ALWAYS click the leaf on OUR side of the doorway. A doorway is two objects one
	-- tile apart, one facing each room; the far one answers "You can't reach that".
	-- The deciding fact is which leaf we can WALK to: from this room the near leaf has
	-- walkable floor beside it, the far leaf only has the other room's floor, which is
	-- not reachable - so a BFS on the client's walk set with tolerance 1 separates them
	-- exactly (D.doorWalkReach). The player's position along the doorway axis is only
	-- the fallback for when the BFS cannot separate them.
	-- the leaf the caller asked for, kept because the choice below may swap it and the
	-- wall refusal has to be remembered against the doorway the route keeps picking
	local origKey = dkey(d)
	if here then
		local pxd, pyd = ptile()
		local sibs = {}
		for _, o in ipairs(world.doors or {}) do
			if o ~= d and ((o.y == d.y and math.abs(o.x - d.x) == 1)
				or (o.x == d.x and math.abs(o.y - d.y) == 1)) then
				sibs[#sibs + 1] = o
			end
		end
		local chosen, how = nil, nil
		if #sibs > 0 then
			local reach = {}
			if D.doorWalkReach(d, 1, world) then reach[#reach + 1] = d end
			for _, o in ipairs(sibs) do
				if D.doorWalkReach(o, 1, world) then reach[#reach + 1] = o end
			end
			if #reach == 1 then
				chosen, how = reach[1], 'only one leaf is walkable from here'
			else
				-- both (or neither) answer reachable: use the axis rule
				local pc = (sibs[1].y == d.y) and pxd or pyd
				local ldc = (sibs[1].y == d.y) and d.x or d.y
				local odc = (sibs[1].y == d.y) and sibs[1].x or sibs[1].y
				local want = (pc >= math.max(ldc, odc)) and math.max
					or (pc <= math.min(ldc, odc)) and math.min
					or nil
				if want then
					chosen = (want(ldc, odc) == ldc) and d or sibs[1]
					how = 'leaf on the player side of the doorway'
				end
			end
		end
		if chosen and chosen ~= d then
			D.noReachLogged = D.noReachLogged or {}
			local lk = 'leaf' .. dkey(d)
			if not D.noReachLogged[lk] then
				D.noReachLogged[lk] = true
				log(string.format(
					'door %d at %d,%d is the far leaf - using %d at %d,%d instead (%s, player %d,%d)',
					d.id, d.x, d.y, chosen.id, chosen.x, chosen.y, how, pxd, pyd))
			end
			d = chosen
		elseif #sibs == 0 then
			-- no second leaf in the scan: nothing to choose from. Say so once, because
			-- otherwise "it still clicks the far side" cannot be told apart from "the
			-- doorway only has one record".
			D.noReachLogged = D.noReachLogged or {}
			local nk = 'single' .. dkey(d)
			if not D.noReachLogged[nk] then
				D.noReachLogged[nk] = true
				log(string.format(
					'door %d at %d,%d has no sibling leaf in the scan - doorway is single-leaf here (player %d,%d)',
					d.id, d.x, d.y, pxd, pyd))
			end
		else
			D.noReachLogged = D.noReachLogged or {}
			local sk = 'kept' .. dkey(d)
			if not D.noReachLogged[sk] then
				D.noReachLogged[sk] = true
				log(string.format('door %d at %d,%d kept: player %d,%d is on its side of the doorway',
					d.id, d.x, d.y, pxd, pyd))
			end
		end
	end

	local key = dkey(d)
	-- One gate every leaf has to pass before it is clicked: the client's walk set must
	-- reach a tile within one tile of it. Checked here as well as in openDoor because
	-- the leaf chosen above may not be the one the caller asked for, and a doorway
	-- behind a wall (or the far leaf of a doorway whose near leaf is the right click)
	-- must never be clicked - the client answers "You can't reach that" and the
	-- doorway gets written off for the floor.
	do
		local ok, why = D.doorWalkReach(d, 1, world)
		if not ok then
			D.wallHit = D.wallHit or {}
			local st = { t = API.SystemTime(), room = D.here and rkey(D.here) or '' }
			D.wallHit[key] = st
			if origKey then D.wallHit[origKey] = st end
			local pk = 'wall' .. key
			D.noReachLogged = D.noReachLogged or {}
			if not D.noReachLogged[pk] then
				D.noReachLogged[pk] = true
				log(string.format(
					'door %d "%s" at %d,%d is not walkable from where we stand (%s) - not clicking it',
					d.id, tostring(d.name), d.x, d.y, tostring(why)))
			end
			-- SkILL DOORS are the exception. The floor walk set is assembled from scans around
			-- the player, so the far end of a merged room (and every room not walked into
			-- yet) is missing from it and reads as "behind a wall" - which left a Broken key
			-- door that plainly exists unopened for a whole floor. For a door of the room we
			-- are standing in, inside click range, trust the client: it owns the real
			-- pathfinder, and a refusal comes back as "You can't reach that", which is
			-- handled (and blacklists the doorway) instead of being guessed at here.
			local sameRoom = here and doorInRoom(here, d)
			local hx, hy = ptile()
			local near = math.max(math.abs(d.x - hx), math.abs(d.y - hy)) <= D.CLICK_RANGE
			local nmSkill = string.lower(tostring(d.name or ''))
			if sameRoom and near and (D.SKILL_DOOR_NAMES[nmSkill] or d.action == 'Unlock') then
				local lk = 'wallpass' .. key
				local nowMs = API.SystemTime()
				D.wallPassLog = D.wallPassLog or {}
				if not D.wallPassLog[lk] or (nowMs - D.wallPassLog[lk]) > 6000 then
					D.wallPassLog[lk] = nowMs
					log(string.format('door %d "%s" at %d,%d: walk set says no path, but it is in this room - clicking and letting the client path there',
						d.id, tostring(d.name), d.x, d.y))
				end
				D.approachDoor(d, world)
				API.RandomSleep2(700, 250, 400)
				D.dirty = true
				return false
			end
			return false
		end
	end
	-- Straight back through the doorway we just came in by is never the plan: live,
	-- door 50347 was crossed three times in twenty seconds ("used 3 times - writing
	-- it off") because every pass re-picked it as the nearest openable door. Six
	-- seconds after a crossing the choice has to be something else.
	local crossedAt = doorwayUsedAt(d)
	if crossedAt and (API.SystemTime() - crossedAt) < D.RECROSS_MS then
		-- Nothing is clicked here, so say so once and let the selectors skip this
		-- doorway for a few seconds: they would otherwise pick it again next pass.
		D.noActAt[dkey(d)] = API.SystemTime()
		if not D.recrossLog then
			D.recrossLog = {}
			if not D.recrossLog[key] then
				D.recrossLog[key] = true
				log(string.format('door %d at %d,%d was crossed %dms ago - not going straight back through it',
					d.id, d.x, d.y, API.SystemTime() - crossedAt))
			end
		end
		return false
	end
	local px, py = ptile()
	-- A doorway is only ever clicked from close range WHEN IT IS BEHIND SOMETHING. Clicking
	-- one from across the room does not open anything - the client tries to path the player
	-- and drops the click when another doorway or a wall is in the way (live: door 50348
	-- "Guardian door" at 12072,672 clicked FOUR TIMES from 12087,689, seventeen tiles and
	-- several rooms away, until the click budget refused it for the rest of the floor).
	-- But a doorway in the SAME OPEN AREA is just far: clicking it IS the walk, the client
	-- pathfinds to it itself. A ground-tile click ("DoAction_Tile:Ground") is not the tool
	-- for a doorway - objects drive this game - so the split is by what is BETWEEN us and it,
	-- not by distance alone.
	local stepDist = math.max(math.abs(d.x - px), math.abs(d.y - py))
	if stepDist > D.CLICK_RANGE then
		D.farDoorLog = D.farDoorLog or {}
		local fk = dkey(d)
		if not D.doorBetween(world, px, py, d.x, d.y, D.enteredDoorSkip()) then
			-- same enclosure: click the door and let the client walk us over
			if not D.farDoorLog[fk] then
				D.farDoorLog[fk] = true
				log(string.format('door %d at %d,%d is %d tiles away but nothing is between us - clicking it and letting the client walk us over',
					d.id, d.x, d.y, stepDist))
			end
			if D.doorWalkReach(d, 1, world) then
				say(string.format('walking over to door %d', d.id))
				D.approachDoor(d, world)
				API.RandomSleep2(900, 300, 500)
				settle()
				D.dirty = true
			else
				D.noActAt[dkey(d)] = API.SystemTime()
			end
			return false
		end
		-- a doorway BETWEEN us and it: this is several rooms away and the walker has to
		-- cross the doorway in between first. Nothing is clicked or walked here.
		if not D.farDoorLog[fk] then
			D.farDoorLog[fk] = true
			log(string.format('door %d at %d,%d is %d tiles away behind another doorway - the route has to get us there first, not clicking it',
				d.id, d.x, d.y, stepDist))
		end
		D.noActAt[dkey(d)] = API.SystemTime()
		return false
	end
	local before = roomNearRooms(world.rooms, px, py)

	-- Standing ON the doorway tile: the door click can never move us, so it is
	-- answered with nothing and the same pass repeats. Step off first.
	if px == d.x and py == d.y and d.action ~= 'Unlock' then
		local spot = nil
		for _, n in ipairs(D.DIR4) do
			if world.walk[pkey(d.x + n[1], d.y + n[2])] then
				spot = { d.x + n[1], d.y + n[2] }
				break
			end
		end
		if spot then
			log(string.format('standing on doorway %d at %d,%d - the door leaf itself is the way off it',
				d.id, d.x, d.y))
			D.approachDoor(d, world)
			API.RandomSleep2(700, 250, 400)
			return false
		end
	end

	-- Everything a crossing implies, in one place: the doorway is marked used, the
	-- room pair remembered, the hallway counter bumped. False = still on the near side.
	local function crossed(px2, py2)
		local after = roomNearRooms(world.rooms, px2, py2)
		local through = crossedDoorway(d, px, py, px2, py2)
		local movedRoom = before and after and after.idx ~= before.idx
		-- A ROOM CHANGE IS NOT A CROSSING ON ITS OWN. roomNearRooms answers with the nearest
		-- room of a merged, optimistic graph, so a few tiles of ordinary walking inside one
		-- blob changed the answer and marked whichever doorway was under the cursor as
		-- walked through - it stayed shut for the rest of the floor and no route ever went
		-- back to it (live: the "unopened guardian door that pathing does not path to").
		-- The crossing only counts if the player ENDS UP AT the doorway.
		local nearDoor = math.max(math.abs(px2 - d.x), math.abs(py2 - d.y)) <= 3
		if not (through or (movedRoom and nearDoor)) then return false end
		S.attempts[key] = 0
		local canon = markDoorway(d, world)
		-- Remember exactly which doorway we came through. The "You can't reach that."
		-- handler uses this to tell a late refusal for THIS crossing from a refusal for a
		-- door that really is behind a wall; using the wider doorUsed stamp (which covers
		-- the crossed doorway's neighbours as well) let unreachable doors be clicked for
		-- ever, and the client walked the player into the wall each time.
		D.crossed = { tile = dkey(d), canon = canon, at = API.SystemTime() }
		clearReach()
		-- Only a crossing that actually changed the room sets "arrived from". On a merged
		-- blob the room key does not change, so setting it made every doorway of the blob
		-- look like "the way back", all of them got skipped, the planner had no plan and the
		-- last resort picked a door at random - that is the "stepped through and straight
		-- back" loop on the last guardian door.
		if before and movedRoom then S.arrivedFrom = rkey(before) end
		local used = (D.travCount[canon] or 0) + 1
		D.travCount[canon] = used
		if used >= 3 then
			-- Both leaves, or the write-off only covers the half we happened to click
			-- and the other half is picked again a second later.
			S.badDoor[canon] = true
			for i = 1, #D.DIR4 do
				S.badDoor[(d.x + D.DIR4[i][1]) .. ',' .. (d.y + D.DIR4[i][2])] = true
			end
			log(string.format('doorway %s (door %d) used %d times - writing it off', canon, d.id, used))
		end
		if before and after then D.traversed[pairKey(before.idx, after.idx)] = true end
		D.dirty = true
		log(string.format('through door %d at %d,%d into room %d:%d (%s)', d.id, d.x, d.y,
			after and after.minx or -1, after and after.miny or -1,
			(through and not movedRoom) and 'crossed by position, room key unchanged' or 'room changed'))
		return true
	end

	-- Are we on the far side of this doorway RIGHT NOW? The room cache notices a crossing
	-- about a second late, and a pass that lands in that gap clicks the side it came from:
	-- live, an Enter went out 4.4 s after the open click with the player already through the
	-- doorway, and the client answered it with "You can't reach that." Only trusted within
	-- two tiles of the doorway, so a walk across the open floor cannot flip the answer.
	local function alreadyThrough()
		local cxp, cyp = ptile()
		if math.max(math.abs(cxp - d.x), math.abs(cyp - d.y)) > 2 then return false end
		return crossed(cxp, cyp)
	end

	-- The leaf to click for a crossing, read from the LIVE scan ON THAT TILE rather than from
	-- the cached world record. A doorway leaf changes id when it opens (50266 "Unlock" ->
	-- 50411 "Enter") and its action changes with it, so the cached record described a door
	-- that no longer exists: the click was dispatched with the OLD action at the OLD id and
	-- the client dropped it - which reads as "it steps into a closed door too fast" and cost
	-- a whole extra pass (and sometimes a write-off) per crossing.
	local function liveLeafAt(x, y, force)
		local best, bestAct, bestGap = nil, nil, nil
		for _, o in ipairs(D.objScan(force == true)) do
			local tx, ty = D.objTile(o)
			if tx then
				local dx = math.abs(math.floor(tx) - math.floor(x))
				local dy = math.abs(math.floor(ty) - math.floor(y))
				local a = tostring(D.objGet(o, 'Action') or '')
				if dx <= 1 and dy <= 1 and (a == 'Enter' or a == 'Open')
					and (tonumber(D.objGet(o, 'Bool1')) or 0) ~= 1 then
					-- the tile that was asked for comes first: a +/-1 tolerance alone hands
					-- back the leaf on the OTHER side of the doorway, and clicking that one
					-- from this side is the click the client answers "You can't reach that."
					local gap = dx + dy
					if not best or gap < bestGap then best, bestAct, bestGap = o, a, gap end
				end
			end
		end
		return best, bestAct
	end

	-- One click on a leaf, then wait for the walk it started to finish.
	local function clickLeaf(leaf, settleMs)
		local act = (leaf.action == 'Open') and 'Open' or 'Enter'
		local x0, y0 = ptile()
		local lx, ly = leaf.x or d.x, leaf.y or d.y
		local lz = (leaf.obj and leaf.obj.Tile_XYZ or {}).z
		-- hold the doorway from the dispatch, so no other path can click it again mid-walk
		D.noteDoorClickAt(lx, ly)
		local liveL, liveAct = liveLeafAt(lx, ly, true)
		if liveL then
			act = liveAct
			D.clickObjectDirect(act, liveL)
		elseif not D.clickScanned(leaf.obj, act, lx, ly, lz, 20) then
			-- A doorway at the far end of a merged room is outside the object scan, so there
			-- is no live record to click. Fall back to the id + tile form: the client
			-- resolves the object itself and walks the player to it. The id is the LEAF's
			-- own: the two leaves of one doorway can carry different ids (50342 "back" vs
			-- 50346 "guardian"), and sending the other one with this tile resolves nothing.
			D.clickObject(act, leaf.id or d.id, lx, ly, lz, 50)
		end
		say(string.format('%s door %d "%s"', tostring(d.kind or ''), d.id, act))
		D.lastDoorTile = dkey(d)
		API.RandomSleep2(settleMs or 400, 150, 250)
		-- move guard: wait for the walk to start AND finish before judging the click
		D.waitMove(x0, y0, 6000)
		local x2, y2 = ptile()
		return x2, y2
	end

	local function beside(x2, y2)
		return math.abs(x2 - d.x) <= 1 and math.abs(y2 - d.y) <= 1
	end

	-- 1. Already open: click its Enter leaf ONCE and wait. The doorway tile stays
	-- blocked collision even when the door is open (live check: 12815,664
	-- blocked=true), so a tile walk to the far side has no path at all - the plan
	-- fails and the leaf click is the only way through. That click makes the client
	-- walk the player over, which takes a couple of seconds; a pass that re-checks
	-- "did we move?" before then and clicks again is precisely the open-door spam
	-- in the log (door 50320 clicked 3x for one crossing).
	if doorwayOpen(world, d) then
		-- Already through it: the crossing only has to be recorded, clicking now hits the
		-- side we came from.
		if alreadyThrough() then return true end
		-- The doorway guard is shared with D.walkPath and covers the tile AND its
		-- neighbours, so a click from either side of the doorway holds the other off for
		-- one crossing - the leaves sit one tile apart and either may be picked next.
		-- The hold is the short one on purpose: D.doorClickInFlight keeps it alive for as
		-- long as that click still has the player walking, so a flat five seconds only
		-- added idle time standing beside a door that was already open.
		if D.doorClickInFlight(d.x, d.y, D.DOOR_CLICK_HOLD) then
			-- the crossing is still in progress: clicking again is the spam
			return true
		end
		if not D.canClickNow(2500) then return true end
		D.noteDoorClickAt(d.x, d.y)
		S.attempts[key] = (S.attempts[key] or 0) + 1
		local leaf = enterLeaf(world, d)
		-- No option on any leaf is NOT proof of a dead object. The object scan is a
		-- snapshot, and a doorway the client will happily walk us through can be missing
		-- from it for a pass. Live: 50344 at 7064,272 was written off as dead at 12:00:43
		-- and used to cross at 12:00:48, and the write-off had already cost the floor its
		-- plan ("no plan: 12 unopened doorway(s) ... none routable through doors we can
		-- open"). So: ask the client to resolve the object from its id and tile, and only
		-- write the doorway off once that has failed D.DEAD_TRIES times.
		if not (leaf.obj and D.interactable(leaf.obj)) then
			D.deadTries = D.deadTries or {}
			local tries = (D.deadTries[key] or 0) + 1
			D.deadTries[key] = tries
			local lx, ly = leaf.x or d.x, leaf.y or d.y
			-- DISABLED OBJECTS ARE NOT CLICKED. liveObjectAt answers false for a leaf that
			-- exists but offers no option (the engine drops the interact and the player never
			-- moves) and nil for one that is simply outside the scan radius, where clicking by
			-- id and tile is the only way to reach it. Only the second case may be clicked.
			local live = D.liveObjectAt(d.id, lx, ly)
			if live == false then
				if tries >= D.DEAD_TRIES then
					S.badDoor[key] = true
					log(string.format('door %d at %d,%d is disabled in the live scan %d times - writing the doorway off',
						d.id, d.x, d.y, tries))
				else
					log(string.format('door %d at %d,%d is disabled in the live scan - not clicking it (%d/%d)',
						d.id, d.x, d.y, tries, D.DEAD_TRIES))
				end
				return false
			end
			local byId = D.clickObject('Enter', d.id, lx, ly,
				(leaf.obj and leaf.obj.Tile_XYZ or {}).z, 20)
			if byId then
				D.lastDoorTile = dkey(d)
				log(string.format('door %d at %d,%d is outside the scan radius - clicked it by id and tile (try %d)',
					d.id, d.x, d.y, tries))
				return true
			end
			-- Nothing clickable at this doorway yet: it is not in the live scan, which means
			-- the client has not loaded its leaves. Clicking a ghost is refused (D.clickObject),
			-- so walk to the doorway instead - the client loads what is around the player, and
			-- the next pass has a real leaf to click.
			local px, py = ptile()
			local bx, by, bd = nil, nil, math.huge
			for _, n in ipairs(D.DIR4) do
				local nx, ny = d.x + n[1], d.y + n[2]
				if world and world.walk and world.walk[pkey(nx, ny)] then
					local dd = math.max(math.abs(nx - px), math.abs(ny - py))
					if dd > 0 and dd < bd then bd, bx, by = dd, nx, ny end
				end
			end
			if bx and bd > 0 and bd <= D.DOOR_NEAR then
				if not D.ghostWalked or D.ghostWalked ~= key then
					D.ghostWalked = key
					log(string.format('door %d at %d,%d has no loaded leaf - walking to %d,%d so the client loads it',
						d.id, d.x, d.y, bx, by))
				end
				D.walkTile(bx, by, 0)
				API.RandomSleep2(600, 200, 300)
				return false
			end
			if tries < D.DEAD_TRIES then
				log(string.format('door %d at %d,%d has no option on any leaf - not writing it off yet (%d/%d)',
					d.id, d.x, d.y, tries, D.DEAD_TRIES))
				return false
			end
			S.badDoor[key] = true
			log(string.format('door %d at %d,%d has no option on any leaf %d times - dead object, dropping it',
				d.id, d.x, d.y, tries))
			return false
		end
		say(string.format('walking through door %d', d.id))
		log(string.format('door %d at %d,%d is already open - one Enter click ("%s"), then waiting (try %d)',
			d.id, d.x, d.y, tostring(leaf.action), S.attempts[key]))
		local sent = D.clickScanned(leaf.obj, 'Enter', leaf.x or d.x, leaf.y or d.y,
			(leaf.obj and leaf.obj.Tile_XYZ or {}).z, 20)
		if not sent and not leaf.obj then
			-- no live record for the leaf at all: the id + tile form lets the client
			-- resolve the object and walk us to it
			sent = D.clickObject('Enter', d.id, leaf.x or d.x, leaf.y or d.y,
				(leaf.obj and leaf.obj.Tile_XYZ or {}).z, 20)
		end
		D.lastDoorTile = dkey(d)
		-- A SKILL leaf can be clicked from this "already open" branch too: the runed door
		-- reads Enter like any passable doorway (its only option is Imbue-energy and the walk
		-- plan goes for the crossing), and THAT click is what imbues it and deletes it. Live
		-- 06:50:18 clicked it here, "You successfully imbue the rune door" at 06:50:22, and
		-- the leaf was a ghost four seconds later - so the moment has to be recorded on this
		-- path as well, or scanWorld never learns the obstacle is gone.
		if sent and d.kind == 'skill' then
			D.skillWorked = D.skillWorked or {}
			D.skillWorked[dkey(d)] = API.SystemTime()
			D.skillMiss = D.skillMiss or {}
			D.skillMiss[dkey(d)] = nil
		end
		if not sent then			-- The click gate refused it: NOTHING was dispatched, so this is not a dead
			-- door and must not be counted or reported as a failed crossing. Live, a
			-- doorway whose click budget had been spent by Force-bar attempts logged
			-- "the Enter click did not move us" four times without one click leaving
			-- the client, which reads as "the door is broken" when it is not.
			log(string.format(
				'door %d at %d,%d: the Enter click was refused before it was sent (click cap on this tile) - not a failed crossing',
				d.id, d.x, d.y))
			-- nothing left the client, so the doorway must not be held off either
			D.forgetDoorClick(d.x, d.y)
			D.dirty = true
			return true
		end
		-- move guard + sleep: the walk begins next tick, so poll for it to APPEAR rather than
		-- waiting for the whole walk to finish. A crossing is a tile or two; sitting out a
		-- full 3 s stop test per open door is the "for opened thinks days" complaint.
		local moved = false
		local t0 = API.SystemTime()
		while (API.SystemTime() - t0) < (D.DOOR_WALK_WAIT or 1500) do
			local cx, cy = ptile()
			if cx ~= px or cy ~= py then moved = true break end
			API.RandomSleep2(150, 50, 100)
		end
		local x2, y2 = ptile()
		local was = crossed(x2, y2)     -- marks the doorway and logs when it crossed
		if was or moved or x2 ~= px or y2 ~= py then
			S.attempts[key] = 0
			D.dirty = true
			return true
		end
		-- NOT ONE STEP. The click was dropped - the leaf had already changed id, or the
		-- client was still turning us round. Holding the doorway for D.OPEN_RECLICK_MS
		-- (five seconds) after a click that never left the client is what makes an OPEN door
		-- feel like the bot has fallen asleep: it stands there with nothing to wait for.
		-- Drop the anti-spam stamp so the next pass clicks again at once.
		D.forgetDoorClick(d.x, d.y)
		log(string.format('door %d at %d,%d is open but the Enter click did not move us (try %d) - retrying next pass',
			d.id, d.x, d.y, S.attempts[key]))
		-- TWO FAILED Enter clicks in a row: the leaf says Enter but it is not passable, so
		-- stop believing the action word for this doorway (D.doorwayOpen) and treat it as
		-- shut from now on. Cleared the moment a crossing actually happens (markDoorway).
		if S.attempts[key] >= 2 then
			D.shutSuspect = D.shutSuspect or {}
			D.shutSuspect[dkey(d)] = true
			log(string.format('door %d at %d,%d reads Enter but never lets us through - treating it as SHUT from now on',
				d.id, d.x, d.y))
		end
		D.dirty = true
		return true
	end

	-- 2. Closed: click it open, wait until the far leaf really is loaded, and only
	-- then click again to step through. Clicking the second time before the door has
	-- opened is the double click that looked like spam.
	-- A SKILL DOOR THAT REFUSES FOR A LEVEL IS DONE FOR THIS RUN. "You need a Smithing
	-- level of 71..." comes back as a chat line, and the chat is pumped once per main-loop
	-- pass - so it arrives after this call. Remembering the sequence number per doorway and
	-- looking at it on the NEXT attempt turns "eight identical clicks and 80 seconds" into
	-- one written-off doorway, which matters now that an uncrossed skill door holds the
	-- whole floor open (D.doorLeadsToWork).
	if d.kind == 'skill' then
		D.skillLvl = D.skillLvl or {}
		local seen = D.skillLvl[key] or 0
		if (chat.needLevel or 0) > seen then
			S.badDoor[key] = true
			D.dirty = true
			log(string.format(
				'skill door %d "%s" at %d,%d refused for a level we do not have - written off for this floor',
				d.id, tostring(d.name), d.x, d.y))
			return false
		end
		D.skillLvl[key] = chat.needLevel or 0
	end
	if not openDoor(d, world) then
		-- refused before dispatch: nothing was clicked, so this is not an attempt
		-- and the door must stay re-usable in case the key turns up later
		return false
	end
	D.dirty = true

	-- A SKILL door (Chop, Mine, Force-bar, Imbue-energy, ...) does not open from one
	-- click: the click starts the skill and the door gives way after the animation.
	-- Checking for the far leaf immediately concluded "stayed CLOSED" while the
	-- player was still chopping, wrote the door off after ONE try and moved on - and
	-- the pass after that re-clicked it, which is the slow repeated clicking.
	local skill = (d.kind == 'skill')
	-- An Unlock needs the same patience as a skill door: the key is spent server
	-- side, the player is animating, and the leaf only reads "Enter" afterwards. Four
	-- 350 ms polls concluded "stayed closed" while the unlock was still playing, and
	-- the next pass clicked the same door again (50238, three clicks for one unlock).
	-- A GUARDIAN door needs it too, and for a different reason: it is often the only
	-- doorway on the floor with no second leaf, so D.farLeafOf can never answer "open" for
	-- it, and the single-try write-off below blacklisted it after one click (live: 50348 at
	-- 8616,480 "stayed CLOSED after the click - written off" while its guardians were still
	-- alive). Guardian doors are worked like skill doors instead: several interactions, no
	-- instant write-off.
	local slow = skill or d.action == 'Unlock' or d.kind == 'guardian'
	local x2, y2, other
	-- openDoor already waited the walk AND the animation for a slow door, so the leaf
	-- is normally there on the first look: four polls, not eight. Each poll costs a
	-- fresh object sweep and this loop is one of the long silent pauses.
	local waits = 4
	for wait = 1, waits do
		settle()
		x2, y2 = ptile()
		if crossed(x2, y2) then return true end
		other = farLeafOf(d)          -- one live object scan per wait, not two
		if other then break end
		-- while skilling or unlocking, wait the animation out instead of polling
		if slow then
			D.waitAnim(1200)
			API.RandomSleep2(400, 150, 250)
		else
			API.RandomSleep2(350, 100, 200)
		end
	end
	if not other then
		S.attempts[key] = (S.attempts[key] or 0) + 1
		if slow then
			-- Skill doors legitimately need several interactions (a barricade can take
			-- a few chops) and an unlock can take more than one interaction when a key
			-- is missing for one leaf. Keep the door alive until D.SKILL_TRIES.
			if S.attempts[key] >= D.SKILL_TRIES then S.badDoor[key] = true end
			D.dirty = true
			log(string.format('%s door %d at %d,%d still closed after the click (try %d/%d) - will keep working it',
				skill and 'skill' or 'unlock', d.id, d.x, d.y, S.attempts[key], D.SKILL_TRIES))
			return true
		end
		-- Everything else: ONE try. The client's own answer ("You can't reach that."
		-- / the door stays single-leaf) is definitive, so a retry only repeats a click
		-- on a door that will not open.
		if d.action ~= 'Unlock' then S.badDoor[key] = true end
		D.dirty = true
		log(string.format('door %d at %d,%d stayed CLOSED after the click - written off (%s)',
			d.id, d.x, d.y, (x2 ~= px or y2 ~= py) and 'moved but stayed on this side' or 'no movement at all'))
		return false
	end

	-- open now: one click to walk through, and one retry if that did not take
	-- something the previous pass clicked may still be walking us there: a click now
	-- retargets that walk and the doorway crossing it was making
	--
	-- AND NOT FROM THE OTHER SIDE. The open (or unlock) click above is itself the crossing:
	-- the client walks the player over, opens the door and carries on through it, so by the
	-- time the far leaf is on screen the player may already be past the doorway. Live, the
	-- Enter went out 4.4 s after the open click with the player already through, and the
	-- client answered it with "You can't reach that." - the room cache only notices about a
	-- second later, so the position is read here instead of waiting for it.
	if alreadyThrough() then return true end
	-- a click that is still playing out must not be repeated (the hold also covers the
	-- walk a doorway click starts, see D.doorClickInFlight)
	if D.doorClickInFlight(d.x, d.y) then
		D.dirty = true
		return true
	end
	if not D.canClickNow(2500) then return true end
	if D.unlockInFlight(d) then
		-- the key turn is still in flight; an Enter now is silently refused by the gate
		D.dirty = true
		return true
	end
	x2, y2 = clickLeaf(enterLeaf(world, d), 600)
	if crossed(x2, y2) then return true end
	if beside(x2, y2) then
		local x3, y3 = clickLeaf(enterLeaf(world, d), 700)
		if crossed(x3, y3) then return true end
		x2, y2 = x3, y3
	end
	S.attempts[key] = (S.attempts[key] or 0) + 1
	-- An OPEN door is never written off. The only thing that can fail here is our own click
	-- landing, and removing an open doorway from the graph can leave the whole floor
	-- unroutable: live, the crimson key door was blacklisted after two Enter clicks that
	-- the "Unlock still in flight" cooldown had swallowed (7 s), and the bot then looped for
	-- a minute on a barred door 19 tiles away with no route to anything.
	if S.attempts[key] % 4 == 1 then
		log(string.format('door %d at %d,%d is OPEN (far leaf loaded) - %s (try %d) - keeping it in play',
			d.id, d.x, d.y, (x2 ~= px or y2 ~= py) and 'still on this side' or 'could not walk to it',
			S.attempts[key]))
	end
	D.dirty = true
	return true
end

-- Doors are opened by clicking the OBJECT and nothing else: the client runs the
-- player to it and interacts. Walking tile by tile to a door is what produced the
-- stream of clicks on random-looking floor tiles ("walk plan: 6 steps to
-- 14344,1262" to reach a door 7 tiles). The one case the client cannot path to is
-- a door that is not reachable from here, and that is rejected up front by
-- doorReachable instead of being papered over with a hand-rolled walk.

--------------------------------------------------------------------
-- world cache: the layout only changes when we act or change room, so the full
-- scan is reused instead of rebuilt on every single iteration
--------------------------------------------------------------------
D.WORLD_TTL = 8000
local function getWorld(px, py)
	local room = S.worldCache and roomNearRooms(S.worldCache.rooms, px, py)
	if S.worldCache and not D.dirty and room and S.worldRoom == room.idx
		and (API.SystemTime() - S.worldAt) < D.WORLD_TTL then
		S.worldCache.room = room
		return S.worldCache
	end
	local t0 = API.SystemTime()
	S.worldCache = scanWorld()
	local cost = API.SystemTime() - t0
	S.worldAt = API.SystemTime()
	D.dirty = false
	room = roomNearRooms(S.worldCache.rooms, px, py)
	S.worldRoom = room and room.idx or nil
	S.worldCache.room = room
	if cost > 400 then
		warn(string.format('world scan took %dms (%d rooms, %d doors): %s',
			cost, #S.worldCache.rooms, #S.worldCache.doors,
			table.concat(D.scanPhase or {}, ', ')))
	end
	return S.worldCache
end

--------------------------------------------------------------------
-- walking the drawn route, doorway by doorway
--   * the leaf on the side we can stand on is the one clicked (BFG tolerance 1)
--   * 400ms, then wait for movement / player animation, then 400ms more
--   * repeat until the white-dot door is the next one on the route; that door is
--     OPENED by the caller, never walked through blind
--------------------------------------------------------------------
D.PATH_STEPS = 8
D.pathLog = {}

-- THE ROOM AFTER A DOORWAY IS NOT THERE YET. Its props, the npcs standing in it and the
-- room blob the segmentation builds from them all arrive with the next map stream, a
-- second or two behind the player. Judging the room on the scan taken the instant we step
-- in answers "nothing here", and the walker then carries straight on through the next
-- doorway - which is the reported flaw ("carries on with path, has no idea we are in the
-- puzzle room"). So every crossing INTO A ROOM WE HAVE NOT STOOD IN waits
-- D.DOOR_SETTLE_MS, rescans, and only then judges the room - and it judges the room AT
-- THE PLAYER, not `world.room` from before the walk.
D.DOOR_SETTLE_MS = 2500

-- The walker's own puzzle question. The room solvers each know their prop, but they are
-- judged from the room blob (D.tileInHere) and the blob is the unreliable part - a merged
-- blob spans a wall, one physical room is split into several keys - so a solver can look
-- at "its" room and answer "not here" while the bot is standing in it. The walker only
-- needs the coarse question "does the room I just walked into still hold puzzle props?",
-- so it asks the object scan by name fragment. Fragments, not ids: the ids differ per
-- floor and theme. A false positive costs a stand-down, never the floor - the guesses are
-- counted per room and after D.GUESS_BREAKS the walk carries on regardless.
-- EVERY puzzle room the florr can hold has to be in here, so the list is doubly covered:
--   D.PUZZLE_MARK   - the prop names, including the ones with no action at all
--                     (icy pads are "Button" objects and are solved by sliding over them),
--   D.PUZZLE_ACTION - the verbs only a puzzle prop uses ("Go-through" on a toxin-maze
--                     barrier, "Imbue" on a flip tile, "Scare" on a ferret, ...). Anything
--                     the names miss is caught by its verb.
-- Resource furniture is deliberately absent from both: wisps are "Harvest", rocks "Mine",
-- trees "Chop down", fishing spots "Net"/"Bait", and none of those verbs are listed.
D.PUZZLE_MARK = {
	'construct', 'collapsing strut', 'support strut', 'debris', 'broken barrel',
	'monolith', 'lodestone', 'groove', 'ferret', 'pondskater', 'flip tile',
	'rune tile', 'icy pad', 'icy block', 'button', 'pressure pad',
	'coffin', 'jewellery box', 'damaged wall', 'broken pot', 'statue', 'lever',
	'barrier', 'pedestal', 'crystal', 'magical',
}
D.PUZZLE_ACTION = {
	'repair', 'destroy', 'investigate', 'charge', 'imbue', 'force', 'carve', 'arm',
	'scare', 'catch', 'turn', 'pull', 'push', 'jump', 'stomp', 'bless', 'rotate',
	'go-through', 'check', 'search', 'light', 'attune', 'shake', 'chisel', 'sharpen',
}
D.PUZZLE_NEAR = 12         -- tiles: a puzzle prop this close is in the room we walked into
-- Markers that are ALSO plain dungeon scenery, so the name only counts when the object
-- really offers an option. "Pedestal" 52055 (type 12 decor, no action) stands in ordinary
-- rooms; the toxin maze's pedestal offers "Mine". Matching the word alone made scenery read
-- as an unsolved puzzle and stood the floor route down for five seconds a pass.
D.PUZZLE_MARK_NEEDS_ACTION = {
	pedestal = true,
}
-- Scenery that shares a verb with a real puzzle prop but is NOT dungeon content. The
-- Necromancy ritual site's props stand inside the base camp's bounds (live: Pedestal
-- 137198 "Create" at 7089,258, Glyph spot 137200 "Draw glyph" at 7089,257, Light source
-- spot 137206 "Place light source" at 7089,259) and "light" is a genuine puzzle verb
-- (Poltergeist's fire burners: Interact(Burned_Full, "Light")), so the verb list cannot
-- simply drop it. The props are ignored by ID instead, which is exact.
D.PUZZLE_IGNORE_ID = {
	[137198] = true, [137200] = true, [137206] = true,   -- Necromancy ritual site props
	[52004] = true, [52005] = true,                       -- base camp statues by the exit (decor)
	-- Base camp "Runecrafting altar": its only option is "Imbue", which is the flip-tile
	-- verb, so every pass through the start room read "an unsolved puzzle in this room
	-- (imbue "runecrafting altar")", paused the floor route for 5 s and kept the bot from
	-- carrying on west to the room it still had to open.
	[50037] = true,
}
D.GUESS_BREAKS = 4         -- stand-downs for one guess in one room before the walk ignores it
-- A doorway this close is clickable whatever the walk model believes: clicking needs
-- distance, not a planned walk, and the wall masks that the walk set carries can hide a
-- doorway the player is standing next to.
D.DOOR_NEAR = 3
D.PUZZLE_HOLD_MS = 5000    -- how long a puzzle-props stand-down keeps the floor route paused
D.localBreaks = {}         -- 'room|kind' -> stand-downs (per room per floor)
D.ROOM_ENEMY_NEAR = 10     -- an attackable npc this close with no doorway between is here

-- Which leaf of this doorway can we act on? A doorway is two objects one tile
-- apart; the one whose side has floor we can walk to is the click. Nil when
-- neither side is in reach - the doorway is behind something shut.
function D.leafInReach(world, d)
	local phys = D.walkBfs(world)
	local px, py = ptile()
	local best, bestD = nil, math.huge
	for _, o in ipairs(world.doors or {}) do
		if (o.action == 'Enter' or o.action == 'Open') and not isBossDoor(o)
			and (not o.obj or D.interactable(o.obj))
			and math.abs(o.x - d.x) <= 1 and math.abs(o.y - d.y) <= 1
			and D.walkReach(phys, o.x, o.y, 1) then
			local dd = math.max(math.abs(o.x - px), math.abs(o.y - py))
			if dd < bestD then bestD, best = dd, o end
		end
	end
	if best then return best end
	-- AND PROXIMITY IS ENOUGH. The walk set is built from the map's "Walk" tiles plus the
	-- wall masks that come with them, and a doorway's neighbours can be masked off even
	-- while the player stands right beside it: live, the route's first hop at 7064,287 read
	-- "neither side is in reach" from two tiles away, the walker returned without doing
	-- anything, and every pass did the same - the bot standing still and "really confused"
	-- while the door it wanted was in arm's reach. Clicking a doorway needs distance, not a
	-- planned walk, so anything within D.DOOR_NEAR tiles is a leaf we can act on.
	if d and math.max(math.abs(d.x - px), math.abs(d.y - py)) > D.DOOR_NEAR then return nil end
	if d and (d.action == 'Enter' or d.action == 'Open') and D.interactable(d.obj) and not isBossDoor(d) then
		return d
	end
	for _, o in ipairs(world.doors or {}) do
		if (o.action == 'Enter' or o.action == 'Open') and not isBossDoor(o)
			and D.interactable(o.obj)
			and math.abs(o.x - d.x) <= 1 and math.abs(o.y - d.y) <= 1
			and math.max(math.abs(o.x - px), math.abs(o.y - py)) <= D.DOOR_NEAR then
			return o
		end
	end
	return nil
end

-- Puzzle props standing in this room, as a name fragment, or nil. `here` is the room the
-- player is in (it may be nil - the blob loses us often) and `world` carries the doorways
-- used to decide what is "here": a doorway on the line between us and the prop is what
-- makes it the NEXT room's business, and that test outranks the blob. Otherwise the prop
-- counts when the blob holds its tile or when it stands within D.PUZZLE_NEAR.
-- PUZZLES ARE NOT ALL OBJECTS. The magical construct is an NPC ("DoAction_NPC: Damaged
-- construct", live), and so are the pondskaters and the ferrets; a scan of types 0/3/12
-- only is why the walker walked past a construct standing four tiles away. Both scans are
-- read here, and an attackable npc is left to the enemy branch instead.
-- Is this prop OURS TO JUDGE - i.e. standing in the room we just walked into? Asked FIRST,
-- before the name and the action and long before the doorway line walk, because it is the
-- cheap test: a prop 30 tiles away in another room is not judged at all. Only a prop in
-- our own room blob, or within D.PUZZLE_NEAR of us with no doorway between, is.
local function propOurs(world, here, doorTile, skip, t)
	if not t then return false end
	local x, y = math.floor(t.x), math.floor(t.y)
	if doorTile[x .. ',' .. y] then return false end
	-- Cheap filter first: a prop that is neither in our room blob nor within reach is not
	-- judged at all. Only what survives that gets the doorway line walk.
	local inRoom = here and here.set and here.set[pkey(x, y)]
	if not inRoom then
		local px, py = ptile()
		if math.max(math.abs(x - px), math.abs(y - py)) > D.PUZZLE_NEAR then return false end
	end
	-- The doorway on the line outranks the room blob: the blob is exactly what spans walls,
	-- so trusting it would claim the next room's props as ours - the reported "tries to do
	-- the puzzle outside of the room". Nothing behind a doorway is ours, except the doorway
	-- we just walked in through (skip).
	local px2, py2 = ptile()
	return not D.doorBetween(world, px2, py2, x, y, skip)
end

-- Puzzle props standing IN THIS ROOM, as a name/verb with the prop, or nil.
-- PUZZLES ARE NOT ALL OBJECTS. The magical construct is an NPC ("DoAction_NPC: Damaged
-- construct", live), and so are the pondskaters and the ferrets; a scan of types 0/3/12
-- only is why the walker walked past a construct standing four tiles away. Both scans are
-- read here, and an attackable npc is left to the enemy branch instead.
-- ONLY THIS ROOM IS JUDGED: every record is filtered by its tile first (bot room blob, or
-- within D.PUZZLE_NEAR with no doorway between), so a prop across the floor is never named,
-- never matched and never line-walked. Records are read behind one pcall each, because a
-- record whose entity has since gone throws from the userdata metamethod.
function D.puzzlePropsHere(here, world, skip)
	-- A room the solvers have already declared solved is not guessed at again: the props of
	-- a finished puzzle stay where they are (pulled levers, armed statues, drained buttons).
	if here and S.pondState then
		local done = S.pondState[rkey(here)]
		if done and done.solved then return nil end
	end
	-- SLIDING STATUES ARE SOLVED BY THEIR POSITIONS, not by a saved flag: the moment the
	-- four sliding statues copy the four fixed ones the room is done, whichever solver
	-- did it and whatever the room key is now. Without this, a room whose doors have
	-- already been unlocked (rooms merge through open doors and the blob key changes)
	-- kept its statues reading as pending work for the rest of the floor.
	if here and D.slidingMatched and D.slidingMatched(world, here) then
		if D.slidingMarkSolved then D.slidingMarkSolved(here) end
		return nil
	end
	-- The room's own doorway tiles are the walker's business, never a puzzle prop.
	local doorTile = {}
	for _, d in ipairs((world and world.doors) or {}) do doorTile[d.x .. ',' .. d.y] = true end

	local function read(o)
		local ok, id, ty, t, nm, act = pcall(function()
			return o.Id, o.Type, o.Tile_XYZ, o.Name, o.Action
		end)
		if not ok then return nil end
		return id, ty, t, tostring(nm or ''), tostring(act or ''), o
	end

	local function byName(nm, act, o)
		if nm == '' then return nil end
		act = act or ''
		local low = string.lower(nm)
		for i = 1, #D.PUZZLE_MARK do
			local mid = D.PUZZLE_MARK[i]
			if string.find(low, mid, 1, true) then
				-- A NAME ALONE IS NOT ENOUGH FOR SOME PROPS. "Pedestal" is dungeon furniture
				-- (52055 "Pedestal", type 12 decor, NO option) as well as the toxin maze's
				-- pedestal (an object whose option is Mine). Matching the word alone made every
				-- room holding a bit of scenery read as an unsolved puzzle: live 07:25, "path:
				-- standing down in room 14721:4705 - an unsolved puzzle in this room
				-- (pedestal [pedestal])" - there was no puzzle in that room at all, and each
				-- stand-down paused the floor route for D.PUZZLE_HOLD_MS. These markers only
				-- count when the object actually offers an option.
				if D.PUZZLE_MARK_NEEDS_ACTION[mid] then
					if not (o and act ~= '' and D.interactable(o)) then return nil end
				end
				return mid .. ' [' .. low .. ']'
			end
		end
		return nil
	end

	local function byAction(act, nm)
		local low = string.lower(act)
		if low == '' then return nil end
		for i = 1, #D.PUZZLE_ACTION do
			if string.find(low, D.PUZZLE_ACTION[i], 1, true) then
				return string.format('%s "%s"', D.PUZZLE_ACTION[i], string.lower(nm))
			end
		end
		return nil
	end

	for _, o in ipairs(D.objScan()) do
		local id, ty, t, nm, act, rec = read(o)
		if ty and (ty == 0 or ty == 12) and not D.PUZZLE_IGNORE_ID[id]
			and propOurs(world, here, doorTile, skip, t) then
			local hit = byName(nm, act, rec) or byAction(act, nm)
			if hit then return hit, o end
		end
	end
	for _, n in ipairs(D.npcScan()) do
		local id, ty, t, nm, act, rec = read(n)
		if t and not D.PUZZLE_IGNORE_ID[id] and act ~= 'Attack'
			and propOurs(world, here, doorTile, skip, t) then
			local hit = byName(nm, act, rec) or byAction(act, nm)
			if hit then return hit, n end
		end
	end
	return nil
end

-- Is there LOCAL WORK standing in this room that outranks walking the floor route?
-- The order is the one the main loop uses:
--   1. enemies standing in the room - the room is cleared first,
--   2. a puzzle - the solver owns the room until it is done,
--   3. a key lying on this room's floor - it is taken before any door,
--   4. a locked chest in reach - the keys come first, then the loot.
-- Door opening is only left to the path walker once none of that is pending. Returns a
-- reason string plus its kind ('enemies' / 'enemies-near' / 'puzzle' / 'props' / 'key' /
-- 'chest'), or nil when the room is free.
-- `guesses` adds the two questions the walker only asks ONCE, on arrival (D.judgeArrival):
--   'props'        - puzzle props just stand here (they also stand there when the puzzle
--                    is already solved, so it is a guess and it is budgeted), and
--   'enemies-near' - an attackable npc beside us that the room blob does not cover. The
--                    blob is wrong in both directions, but an npc the blob DOES cover is
--                    liveEnemies' business and is reported without the flag, so the main
--                    chain and this function never disagree about a real enemy.
function D.localWorkPending(here, world, guesses, skip)
	local px, py = ptile()
	-- 1. enemies: THE SAME LIST THE FIGHT BRANCH USES. This used to be its own copy of the
	-- filter without liveEnemies' reachability test, so the walker stood down for a monster the
	-- main chain then refused to engage: live 07:28:39, "path: standing down in room 14721:4673
	-- - enemies in this room" and the very next line walked off to unlock the green wedge door.
	-- Nothing fought the monster because liveEnemies had already rejected it; the only thing the
	-- stand-down achieved was to hand the pass back to a chain that then ignored it. One list,
	-- one decision.
	for _, n in ipairs(liveEnemies(here, px, py) or {}) do
		local ok, t = pcall(function() return n.Tile_XYZ end)
		if ok and t then
			local x, y = math.floor(t.x), math.floor(t.y)
			if here and here.set and here.set[pkey(x, y)] then return 'enemies in this room', 'enemies' end
		end
	end
	-- 1b. the guess: an attackable npc beside us that the room map does NOT cover. Budgeted,
	-- because the blob is wrong in both directions and this test has no reachability filter.
	if guesses then
		for _, n in ipairs(D.npcScan()) do
			local ok, act, life, nm, t = pcall(function()
				return n.Action, n.Life, n.Name, n.Tile_XYZ
			end)
			if ok and act == 'Attack' and (life or 0) > 0 and not D.BOSSES[D.bossKey(nm)] then
				if t then
					local x, y = math.floor(t.x), math.floor(t.y)
					if not (here and here.set and here.set[pkey(x, y)])
						and math.max(math.abs(x - px), math.abs(y - py)) <= D.ROOM_ENEMY_NEAR
						and not D.doorBetween(world, px, py, x, y, skip) then
						return 'enemies beside us that the room map misses', 'enemies-near'
					end
				end
			end
		end
	end
	-- 2. a puzzle: a solver owns this room right now. (The plan TTL that holds the route
	--    off is deliberately NOT counted here - this function is what sets it, so
	--    counting it would report a puzzle that is not there.)
	if here and D.solverHoldsRoom(here) then return 'a puzzle in this room', 'puzzle' end
	-- 2b. a solver may not have taken the room yet - it has not had a pass in it. The props
	--     standing around us answer for it.
	if guesses then
		local prop = D.puzzlePropsHere(here, world, skip)
		if prop then
			-- no extra quotes: both producers already quote or bracket the prop name
			return string.format('an unsolved puzzle in this room (%s)', prop), 'props'
		end
	end
	-- 3. a key on the floor of this room
	if here then
		local ok, keys = pcall(keysInRoom, here)
		if ok and keys and #keys > 0 then return 'a key on the floor', 'key' end
	end
	-- 4. a locked chest IN REACH, after the keys. Free loot is still work: without this the
	--    walker judged a room with only a chest left "free" and routed away, so the chest the
	--    player was standing next to was never opened. "In reach" is the same test
	--    D.solveChests uses (a walkable tile beside it that the client can path to), so the
	--    two never disagree - otherwise this would hold the route for a chest the solver is
	--    going to refuse and the bot would never leave the room.
	if here and not D.chestRoomBlocked(here) then
		for _, o in ipairs(D.objScan()) do
			local ok, loot, t = pcall(function() return D.isLootChest(o), o.Tile_XYZ end)
			if ok and loot and t then
				local x, y = math.floor(t.x), math.floor(t.y)
				local z = math.floor(t.z or 0)
				local k = x .. ',' .. y
				local d = (x - px) ^ 2 + (y - py) ^ 2
				if not (D.chestDone and D.chestDone[k])
					and d <= D.CHEST_WALK_MAX * D.CHEST_WALK_MAX
					and not D.doorBetween(world, px, py, x, y, skip) then
					local sx, sy = D.walkSpotNear(world, x, y)
					if sx and (D.tileReachable(sx, sy, z, 1) or D.tileReachable(sx, sy, z, 2)) then
						return 'a locked chest in reach', 'chest'
					end
				end
			end
		end
	end
	-- 5. Daemonheim food on this room's floor, after the keys and after the chest: healing
	--    is worth more than loot, but a key opens the floor and a chest is a one-off. Ten
	--    pieces is enough (D.FOOD_MAX) - past that the pack space is worth more.
	if here and D.foodHeld() < D.FOOD_MAX then
		local food = foodInRoom(here)
		if #food > 0 then return 'Daemonheim food on the floor', 'food' end
	end
	return nil
end

-- The room we stand in, judged the way the walker needs it: FROM THE PLAYER'S TILE on the
-- world just scanned. `world.room` is the room the cache was built around and D.here is
-- the previous pass's idea - after a doorway both can still name the room we LEFT, and a
-- walker that checks the room it left never sees the puzzle room it is standing in.
-- `notIdx` is that room: the player's own tile is asked first, then the doorstep radius,
-- and the room we just walked out of is never the answer.
function D.roomHere(world, px, py, notIdx)
	local function ok(r) return r and (not notIdx or r.idx ~= notIdx) end
	if world and world.rooms then
		local r = roomAt(world.rooms, px, py)
		if ok(r) then return r end
		r = roomNearRooms(world.rooms, px, py)
		if ok(r) then return r end
	end
	local r = (world and world.room) or D.here
	if ok(r) then return r end
	return nil
end

-- Stop the walk and hand the room to the main chain. Logged once per distinct reason so a
-- walker that stands down every pass does not flood the console.
function D.standDown(localWork, where, ttl, hard)
	D.noteLocalPlan(ttl)
	-- `hard` marks a stand-down for a FACT rather than a guess (enemies standing in this room).
	-- D.routePlan still lets a progress doorway through a guessed stand-down, but never through
	-- one of these: the fight branch has to get the pass.
	D.localPlanHard = hard or nil
	D.setStateNow('holding - ' .. tostring(localWork))
	if D.pathHoldWhy ~= localWork then
		D.pathHoldWhy = localWork
		if where then
			log(string.format('path: standing down in room %s - %s', tostring(where), localWork))
		else
			log(string.format('path: standing down - %s', localWork))
		end
		say('local work first: ' .. localWork)
	end
	return false
end

-- Give a room's guess budget back. Not called from the solver wrapper any more (that reset
-- is exactly what made the walker re-guess for ever in a room whose solver acted on
-- something else); it is here for a caller that KNOWS a room was re-opened, e.g. after the
-- floor's puzzle state is rebuilt.
function D.clearBreaks(rk)
	if not rk then return end
	local prefix = rk .. '|'
	for k in pairs(D.localBreaks) do
		if string.sub(k, 1, #prefix) == prefix then D.localBreaks[k] = nil end
	end
end

-- Judge the room we have just walked into and, when it still has work, stop the walk on
-- the spot: the main chain takes it in its own order (clear it, do the puzzle, take the
-- keys) and the doorway is the walker's job again only once nothing is pending. Only the
-- GUESSES are budgeted (props left behind by a solved puzzle, an npc the room map misses);
-- a fact - an enemy the map puts in this room, or a solver that owns it - holds the walk on
-- every pass until it is gone. Returns the (possibly rescanned) world and whether the walk
-- stood down.
function D.judgeArrival(world, px, py, leaf, fromIdx)
	-- The doorway we came through is remembered: it is not a wall between us and this
	-- room's props, and both this test and the room solvers have to know that.
	if leaf and leaf.x and leaf.y then D.enteredDoor = { x = leaf.x, y = leaf.y } end
	local skip = D.enteredDoorSkip()
	local arrived = D.roomHere(world, px, py, fromIdx)
	local rk = arrived and rkey(arrived)
	-- The room is a second or two behind the player: its props, its npcs and the blob
	-- itself all arrive with the next stream, so a room we have never stood in is waited
	-- out and rescanned before it is judged. A room we already walked through does not
	-- need it - nothing new is going to appear there.
	if rk and not (D.visitedRooms and D.visitedRooms[rk]) then
		say(string.format('entered room %s - checking it', rk))
		API.RandomSleep2(D.DOOR_SETTLE_MS, 250, 500)
		D.dirty = true
		world = getWorld(px, py)
		arrived = D.roomHere(world, px, py, fromIdx) or arrived
		rk = arrived and rkey(arrived)
	end
	if rk and D.visitedRooms then D.visitedRooms[rk] = true end
	local localWork, kind = D.localWorkPending(arrived, world, true, skip)
	if not localWork then		if rk then
			local ak = 'enter' .. rk
			if not D.pathLog[ak] then
				D.pathLog[ak] = true
				log(string.format('path: entered room %s at %d,%d via door %d - nothing local to do, carrying on',
					rk, px, py, leaf and leaf.id or -1))
			end
		end
		D.pathHoldWhy = nil
		return world, false
	end
	if (kind == 'props' or kind == 'enemies-near') then
		-- A GUESS IS ALWAYS BUDGETED, EVEN WHEN THE ROOM HAS NO NAME. `rk` is nil whenever the
		-- player's tile is not in any room blob - standing on a doorway, or a blob the
		-- segmentation has just split - and keying the budget on it meant the budget never
		-- ran: the walker stood down for the same groove prop on every pass and the floor
		-- route was never planned again ("it does not seem to be able to formulate a plan",
		-- live 14:47:51 and 14:47:59 with the identical reason). With no room to key on, the
		-- reason itself is the key, so the same guess is answered "carry on" after
		-- D.GUESS_BREAKS passes just as it is inside a room.
		local bk = (rk and (rk .. '|' .. kind)) or ('noroom|' .. kind .. '|' .. tostring(localWork))
		local n = D.localBreaks[bk] or 0
		if n >= D.GUESS_BREAKS then
			if n == D.GUESS_BREAKS then
				D.localBreaks[bk] = n + 1
				warn(string.format('path: no room here and it still shows %s after %d stand-downs - carrying on',
					tostring(localWork), D.GUESS_BREAKS))
			end
			return world, false
		end
		D.localBreaks[bk] = n + 1
	end
	D.standDown(localWork, rk, (kind == 'props') and D.PUZZLE_HOLD_MS or nil, kind == 'enemies')
	return world, true
end

-- Walk the route: one doorway click per room boundary, then wait for the client to
-- finish walking us through it. Returns (moved, world) - `world` is the rescan after
-- the last step, so the caller sees the rooms we just entered.
function D.walkPath(world)
	if not (world and world.walk) then return false, world end
	local px, py = ptile()
	for step = 1, D.PATH_STEPS do
		-- The run can be stopped between two doorways (End key, or a solver ending the
		-- floor). A multi-step walk is not allowed to keep clicking after that.
		if D.stopped() then return false, world end
		-- LOCAL RULES BREAK THE WALK. A route crosses several doorways in one pass, and
		-- the rooms it passes through may have enemies, an unsolved puzzle or a key on the
		-- floor; carrying straight on to the far door and leaving them is the flaw. The
		-- room is judged AT THE PLAYER on the world as it is now - the room we left is not
		-- the room we are in, and checking the wrong one is what let the walker walk
		-- through a puzzle room without noticing it. Any stand-down returns at once, so
		-- the main chain gets the pass.
		local busyRoom = D.roomHere(world, px, py)
		local localWork, localKind = D.localWorkPending(busyRoom, world, nil, D.enteredDoorSkip())
		if localWork then
			D.standDown(localWork, busyRoom and rkey(busyRoom), nil, localKind == 'enemies')
			return false, world
		end
		D.pathHoldWhy = nil
		local plan = D.routePlan(world)
		if not plan then return false, world end
		local doors = plan.doors
		-- Nothing left to cross: the goal doorway is the next one (the caller opens
		-- it), or the walk has reached the floor around a key (the caller takes it).
		if #doors == 0 or doors[1] == plan.door then return true, world end
		local d = doors[1]
		local leaf = D.leafInReach(world, d)
		if not leaf then
			local lk = 'noreach' .. dkey(d)
			if not D.pathLog[lk] then
				D.pathLog[lk] = true
				log(string.format('path: door %d "%s" at %d,%d is on the route but neither side is in reach',
					d.id, tostring(d.name), d.x, d.y))
			end
			return false, world
		end
		-- A DOORWAY IS WALKED THROUGH ONLY WHEN IT IS OPEN. The leaf reads "Enter" on a shut
		-- door too (a closed key door shows Enter before it is unlocked), so this clicked
		-- "Enter" at a door that was not open - "it enters closed doors instantly" - and the
		-- click did nothing, which then cost the entire wait below.
		-- BUT OPEN IT, DO NOT GIVE THE PASS AWAY. Handing back here dropped the whole route
		-- and the chain fell through to leaveRoom, which crossed straight back out of the room
		-- the route had just entered - the live "trapped in room 14769:1265 ... crossed back
		-- out" right after the plan had drawn a 70-tile route through that very doorway, and
		-- again in the next room, ending in "NO WORK LEFT". The doorway on our own route is
		-- ours to open; the next pass walks through it.
		if not doorwayOpen(world, d) then
			local sk = 'shut' .. dkey(d)
			if not D.pathLog[sk] then
				D.pathLog[sk] = true
				log(string.format('path: door %d "%s" at %d,%d is shut - opening it before the walk continues',
					d.id, tostring(d.name), d.x, d.y))
			end
			if D.approachDoor(d, world) then
				API.RandomSleep2(900, 300, 500)
				return true, world
			end
			return false, world
		end
		local act = (leaf.action == 'Open') and 'Open' or 'Enter'
		local lz = (leaf.obj and leaf.obj.Tile_XYZ or {}).z
		local lk = act .. dkey(leaf)
		if not D.pathLog[lk] then
			D.pathLog[lk] = true
			log(string.format('path: %s door %d "%s" at %d,%d - step %d, %d doorway(s) to the end of the route',
				act, leaf.id, tostring(leaf.name), leaf.x, leaf.y, step, #doors - 1))
		end
		-- ONE CLICK PER DOORWAY PER CROSSING. A click still playing out must not be repeated,
		-- and a player who is still walking must not be retargeted. Without this the next
		-- step re-planned from INSIDE the doorway - still on the near side, nothing recorded
		-- as traversed - and clicked the doorway again: the live "clicks the doorway and the
		-- previous door side (or the forward one) in the same second", two Door clicks 1.6 s
		-- apart for one crossing, three in 3 s at 12:38:26.
		if D.doorClickInFlight(leaf.x, leaf.y) then return false, world end
		if not D.canClickNow(2500) then return false, world end
		D.noteDoorClickAt(leaf.x, leaf.y)
		say(string.format('walking through door %d', leaf.id))
		if not D.clickScanned(leaf.obj, act, leaf.x, leaf.y, lz, 20) then
			D.clickObject(act, leaf.id, leaf.x, leaf.y, lz, 100)
		end
		-- WAIT FOR THE WHOLE CROSSING, NOT THE FIRST TILE. Breaking out as soon as the
		-- player had moved one tile re-planned mid-walk, where the doorway is still shut on
		-- the near side and nothing is recorded as used - that is what produced the second
		-- click. The doorway is marked used the moment the walk starts, and the pass waits
		-- for the player to stand still before the next step decides anything.
		local nx, ny = px, py
		local t0 = API.SystemTime()
		while (API.SystemTime() - t0) < (D.DOOR_WALK_WAIT or 1500) do
			nx, ny = ptile()
			if nx ~= px or ny ~= py then break end
			API.RandomSleep2(150, 50, 100)
		end
		if nx == px and ny == py then
			-- nothing was sent (or it was refused): the doorway must stay clickable
			D.forgetDoorClick(leaf.x, leaf.y)
			-- A CLICK SENT FROM A DIAGONAL IS NOT A CROSSING. The player was standing one tile
			-- NORTH of the approach tile (14750,4711 against the doorway at 14751/14752,4712)
			-- and every "Enter" from there moved nothing while the client happily walked to the
			-- doorway when asked to. One pass walking onto the floor beside the leaf - the same
			-- step the ghost-leaf path already takes - puts the player where the click comes
			-- from, and the next pass crosses normally.
			local approach = D.doorApproach or {}
			local dk2 = dkey(d)
			if not approach[dk2] then
				local bfs0 = D.walkBfs(world)
				for i = 1, #D.DIR4 do
					local ax, ay = leaf.x + D.DIR4[i][1], leaf.y + D.DIR4[i][2]
					if world.walk[pkey(ax, ay)] and D.walkReach(bfs0, ax, ay, 0)
						and (ax ~= px or ay ~= py) then
						approach[dk2] = true
						D.doorApproach = approach
						log(string.format(
							'path: %s on door %d moved nothing from %d,%d - walking to the doorway floor at %d,%d to cross from there',
							act, leaf.id, px, py, ax, ay))
						D.walkTile(ax, ay, lz)
						API.RandomSleep2(600, 200, 300)
						return false, world
					end
				end
			end
			log(string.format('path: %s on door %d did not move us from %d,%d', act, leaf.id, px, py))
			return false, world
		end
		-- the crossing is happening: this doorway belongs to the way we came from now
		local canon = markDoorway(d, world)
		D.crossed = { tile = dkey(d), canon = canon, at = API.SystemTime() }
		local walkUntil = API.SystemTime() + (D.DOOR_CROSS_WAIT or 3500)
		while API.SystemTime() < walkUntil do
			nx, ny = ptile()
			if not isMoving() then
				local sx, sy = nx, ny
				API.RandomSleep2(200, 80, 150)
				local ex, ey = ptile()
				if ex == sx and ey == sy and not isMoving() then break end
			end
			API.RandomSleep2(120, 50, 80)
		end
		px, py = ptile()
		D.dirty = true
		world = getWorld(px, py)
		-- THE CHECK AFTER THE DOORWAY, not before the next one: wait for the new room to
		-- register, rescan, and stop here if it has work of its own.
		local stood
		world, stood = D.judgeArrival(world, px, py, leaf, busyRoom and busyRoom.idx)
		if stood then return false, world end
	end
	return true, world
end

--------------------------------------------------------------------
-- map walk displayer: paints D.walkBfs - THE pathfinder - onto the floor so the
-- route the bot believes it has can be checked by eye. Same search the reach
-- tests and the walk helpers use, so the dots cannot disagree with the bot.
--   green dots   - the walk path
--   two red dots - the tiles either side of a doorway the path goes through
--   white dot    - where the path stops: a ground key, or a closed doorway
--------------------------------------------------------------------
D.MAPDOT_ON = true
D.MAPDOT_MS = 1600      -- how long one stamp stays on the floor (just over the refresh,
                        -- so a skipped clear can never stack three paths on top of each other)
D.MAPDOT_REFRESH = 1000 -- at most one BFS + stamp per this many ms
D.MAPDOT_SIZE = 9       -- dot box in pixels
-- The tile the sweep is working on this pass, and how long that stays "the plan". The
-- dots draw THIS, not a second opinion: the sweep re-publishes it every pass it acts,
-- so it lapses on its own when the sweep stops.
D.SWEEP_TARGET_MS = 6000
D.sweepTarget = nil

function D.noteSweepTarget(t)
	if not (t and t.x and t.y) then return end
	t.at = API.SystemTime()
	D.sweepTarget = t
end

-- The merged walker's "go to a tile that is not a graph doorway" step: the boss door
-- marker, the end ladder, a key on the floor. It publishes the target first (so the
-- dots draw the walk) and then takes the reachable floor beside it. This exists because
-- those three used to carry their own copy of "walkSpotNear then walkTile", and each
-- copy walked somewhere the dots never showed. One implementation, one picture.
function D.gotoTile(world, t)
	if not (world and t and t.x and t.y) then return false end
	if D.stopped() then return false end
	D.noteSweepTarget(t)
	local tx, ty = D.walkSpotNear(world, t.x, t.y)
	if not tx then return false end
	D.walkTile(tx, ty, t.z)
	return true, tx, ty
end

-- The tile a search really reaches next to (x,y). A doorway tile and a key's tile are
-- often unwalkable themselves, so a route has to stop on the floor beside them - and
-- "beside" means the four orthogonal neighbours first: a diagonal tile is not where the
-- click comes from, and taking the cheapest one of the nine made the drawn path stop
-- one tile short of the door it was walking to.
function D.nearestReached(bfs, x, y, tol)
	if not bfs or not x or not y then return nil end
	tol = tol or 1
	x, y = math.floor(x), math.floor(y)
	local best, bestKey = nil, nil
	local function poke(nx, ny)
		local k = pkey(nx, ny)
		local d = bfs.dist[k]
		if d and (not best or d < best) then best, bestKey = d, k end
	end
	for _, n in ipairs(D.DIR4) do poke(x + n[1], y + n[2]) end
	if bestKey then return bestKey, best end
	for dx = -tol, tol do
		for dy = -tol, tol do
			if dx ~= 0 or dy ~= 0 then poke(x + dx, y + dy) end
		end
	end
	return bestKey, best
end

-- The walked route to endKey, split into path dots (green) and doorway junctions (red:
-- the tiles either side of each doorway the route crosses). ONE implementation, used
-- by the floor route and by the local room plan, so the two pictures cannot drift
-- apart from each other or from the search.
function D.routeDots(bfs, endKey)
	local green, red = {}, {}
	if not (bfs and endKey) then return green, red end
	local route, k = {}, endKey
	while k do
		local x, y = k:match('^(%-?%d+):(%-?%d+)$')
		if not x then break end
		route[#route + 1] = { tonumber(x), tonumber(y) }
		k = bfs.prev[k]
	end
	for i = 1, math.floor(#route / 2) do
		local j = #route - i + 1
		route[i], route[j] = route[j], route[i]
	end
	local gate = bfs.gate
	local i = 1
	while i <= #route do
		local tx, ty = route[i][1], route[i][2]
		if gate[pkey(tx, ty)] then
			local j = i
			while j + 1 <= #route and gate[pkey(route[j + 1][1], route[j + 1][2])] do j = j + 1 end
			local before, after = route[i - 1], route[j + 1]
			if before then red[#red + 1] = FFPOINT.new(before[1], before[2], 0) end
			if after then red[#red + 1] = FFPOINT.new(after[1], after[2], 0) end
			i = j + 1
		else
			green[#green + 1] = FFPOINT.new(tx, ty, 0)
			i = i + 1
		end
	end
	return green, red
end

function D.stampDots(list, colour, size)
	if list and #list > 0 then
		API.MarkTiles(list, D.MAPDOT_MS, colour, 1, true, true,
			FFPOINT.new(size, size, 0), FFPOINT.new(0, 0, 0))
	end
end

-- A stamp lives D.MAPDOT_MS while a new one is drawn every D.MAPDOT_REFRESH, so two
-- or three paths are on the floor at once and the old ones look like the new path
-- FORKING. Drop them before stamping the next one - unless the maze solver is drawing
-- its own route, which lives 30 s and must not be wiped every second.
function D.clearOldDots()
	local now = API.SystemTime()
	if D.mazeMarksAt and (now - D.mazeMarksAt) < (D.MAZE_MARK_MS or 30000) then return false end
	API.ClearMarkTiles()
	return true
end

--------------------------------------------------------------------
-- Console trace of the drawn route. The dots are a picture on the floor and two
-- overlapping plans are indistinguishable on it; the log can say exactly what the
-- dots should be. Printed once per plan (not per pass), in two forms:
--   route sweep: 42 tiles from 8611,456 to 8623,456, 1 doorway crossing(s)
--   route E2 N3 [door 49679 8623,456] E5 S1      <- run list, so a doubling back shows
--   route ....................                    <- the same walk as a box:
--   route ...#..#..........       * path   + doorway the route crosses
--   route ...#@.#..........       @ start  X end   . floor   # blocked   B barrel
--------------------------------------------------------------------
D.PATH_TRACE = false    -- console echo of a plan; the FILE below is the debug artifact,
                        -- and echoing every plan to the console is real lag (see D.TRACE_MIN_MS)
D.PATH_TRACE_MAX = 72   -- longest side of the printed box, in tiles
-- A plan is recomputed every pass and each pass moves the player, so the drawn walk changes
-- every second. Writing that to the file (or the console) on every change is what made the
-- game lag hard in a room the bot was standing in: this is the floor between two trace
-- blocks, and one block still lands whenever the walk really turns round.
D.TRACE_MIN_MS = 4000

-- EVERY PLAN IS ALSO WRITTEN TO THIS FILE. The dots only show the newest plan, and the
-- interesting question is always about the plan before it ("it went back through the
-- door it came in by, then five seconds later turned round"), so each plan is appended
-- as a block: time, what the plan was for, player tile, the doorway crossings with what
-- they cost that search, the run list, every route tile, and the box picture. One block
-- per plan - a plan is recomputed only when its destination changes - and the file is
-- truncated once it passes D.ROUTE_FILE_BYTES so a long run cannot fill the disk.
D.ROUTE_FILE = ((os and os.getenv and os.getenv('USERPROFILE')) or '.') ..
	'\\MemoryError\\Lua_Scripts\\dung\\dung_route.txt'
D.ROUTE_FILE_BYTES = 2 * 1024 * 1024
D.ROUTE_CHARS = 0

local function routeFileAppend(text)
	local ok = pcall(function()
		D.ROUTE_CHARS = (D.ROUTE_CHARS or 0) + #text
		local mode = 'a'
		if not D.ROUTE_STARTED or D.ROUTE_CHARS > D.ROUTE_FILE_BYTES then
			D.ROUTE_STARTED, D.ROUTE_CHARS, mode = true, #text, 'w'
		end
		local f = io.open(D.ROUTE_FILE, mode)
		if not f then return end
		f:write(text)
		f:close()
	end)
	if not ok then D.ROUTE_FILE_OK = false end
	if ok and not D.ROUTE_FILE_SAID then
		D.ROUTE_FILE_SAID = true
		log('route trace file: ' .. D.ROUTE_FILE)
	end
end

function D.traceRoute(bfs, endKey, tag, info)
	if not (bfs and endKey) then return end
	local route, k = {}, endKey
	local guard = 0
	while k and guard < 4096 do
		local x, y = k:match('^(%-?%d+):(%-?%d+)$')
		if not x then break end
		route[#route + 1] = { tonumber(x), tonumber(y) }
		k = bfs.prev[k]
		guard = guard + 1
	end
	if #route < 2 then return end
	for i = 1, math.floor(#route / 2) do
		local j = #route - i + 1
		route[i], route[j] = route[j], route[i]
	end
	tag = tostring(tag or 'route')
	local gate = bfs.gate or {}
	local gateCost = bfs.gateCost or {}
	local sx, sy = route[1][1], route[1][2]
	local ex, ey = route[#route][1], route[#route][2]
	local runs, cross, cur, n, doors = {}, {}, nil, 0, 0
	local lastDoorKey
	local function flush()
		if cur then runs[#runs + 1] = cur .. n end
		cur, n = nil, 0
	end
	for i = 2, #route do
		local dx = route[i][1] - route[i - 1][1]
		local dy = route[i][2] - route[i - 1][2]
		local d = (dx == 1 and 'E') or (dx == -1 and 'W') or (dy == 1 and 'N') or (dy == -1 and 'S') or '?'
		local kIn, kOut = pkey(route[i][1], route[i][2]), pkey(route[i - 1][1], route[i - 1][2])
		local g = gate[kIn] or gate[kOut]
		-- A doorway owns the tile it stands on, so the step ONTO it and the step OFF it
		-- both find it in `gate` and it was listed twice ("3 doorway(s)" for a walk that
		-- crosses two). One crossing per doorway, in walking order.
		local gk = g and pkey(g.x, g.y)
		if g and gk ~= lastDoorKey then
			lastDoorKey = gk
			flush()
			doors = doors + 1
			local cost = gateCost[kIn] or gateCost[kOut] or D.DOOR_COST
			cross[#cross + 1] = string.format('door %d @%d,%d action=%s cost=%d%s',
				g.id or 0, g.x, g.y, tostring(g.action), cost,
				(cost > (D.DOOR_COST or 6) and ' (crossed recently - priced up)' or ''))
			runs[#runs + 1] = string.format('[door %d %d,%d]', g.id or 0, g.x, g.y)
			cur, n = d, 1
		elseif d == cur then
			n = n + 1
		else
			flush()
			cur, n = d, 1
		end
	end
	flush()

	local ok, stamp = pcall(os.date, '%Y-%m-%d %H:%M:%S')
	if not ok or not stamp then stamp = tostring(API.SystemTime()) end
	local px, py = ptile()
	local body = {}
	body[#body + 1] = string.format('player %d,%d | start %d,%d -> end %d,%d | %d tiles | %d doorway(s)',
		px, py, sx, sy, ex, ey, #route, doors)
	if info and info ~= '' then body[#body + 1] = 'goal: ' .. tostring(info) end
	for i = 1, #cross do body[#body + 1] = 'cross: ' .. cross[i] end
	local flat = {}
	for i = 1, #route do flat[i] = route[i][1] .. ',' .. route[i][2] end
	local sig = table.concat(flat, ' ')
	-- ONE BLOCK PER PLAN THAT ACTUALLY CHANGED, at most one per D.TRACE_MIN_MS. The plan is
	-- rebuilt every pass and the player moves every pass, so an unthrottled trace writes a
	-- block and echoes 10-20 console lines per second - that is the "lagging real hard".
	if sig == D.traceSig then return end
	local traceNow = API.SystemTime()
	if D.traceAt and (traceNow - D.traceAt) < D.TRACE_MIN_MS then return end
	D.traceSig, D.traceAt = sig, traceNow
	body[#body + 1] = 'runs: ' .. table.concat(runs, ' ')
	body[#body + 1] = 'route: ' .. sig

	local minx, maxx, miny, maxy = sx, sx, sy, sy
	for _, t in ipairs(route) do
		if t[1] < minx then minx = t[1] end
		if t[1] > maxx then maxx = t[1] end
		if t[2] < miny then miny = t[2] end
		if t[2] > maxy then maxy = t[2] end
	end
	minx, maxx, miny, maxy = minx - 1, maxx + 1, miny - 1, maxy + 1
	if (maxx - minx) > D.PATH_TRACE_MAX or (maxy - miny) > D.PATH_TRACE_MAX then
		body[#body + 1] = string.format('box: %dx%d tiles - run list only',
			maxx - minx + 1, maxy - miny + 1)
	else
		local onPath = {}
		for _, t in ipairs(route) do onPath[pkey(t[1], t[2])] = true end
		for y = maxy, miny, -1 do
			local row = {}
			for x = minx, maxx do
				local k = pkey(x, y)
				if x == sx and y == sy then row[#row + 1] = '@'
				elseif x == ex and y == ey then row[#row + 1] = 'X'
				elseif gate[k] then row[#row + 1] = '+'
				elseif onPath[k] then row[#row + 1] = '*'
				elseif bfs.blocked and bfs.blocked[k] then row[#row + 1] = 'B'
				elseif bfs.walk and not bfs.walk[k] then row[#row + 1] = '#'
				else row[#row + 1] = '.' end
			end
			body[#body + 1] = 'box: ' .. table.concat(row)
		end
	end

	routeFileAppend(string.format('=== %s  %s\n%s\n', stamp, tag, table.concat(body, '\n')))
	if D.PATH_TRACE then
		for i = 1, #body do log('route ' .. tag .. ': ' .. body[i]) end
	end
end

-- Dots for the tile the SWEEP is walking to. The sweep is the thing that decides what
-- this pass is for, so its target is what the dots have to show: the walk to that
-- doorway (or key), drawn from the PHYSICAL walk set (through = false) - the same search
-- the sweep's own room test uses - so the green dots ARE the path the bot is taking, and
-- the last one lands on the tile it is about to click.
function D.drawPathToTarget(world, t)
	if not (t and t.x and t.y) then return false end
	local bfs = D.walkBfs(world, false)
	local endKey = D.nearestReached(bfs, t.x, t.y, 1)
	if not endKey then return false end
	local green, red = D.routeDots(bfs, endKey)
	D.clearOldDots()
	D.stampDots(green, 0x00FF00, D.MAPDOT_SIZE)
	D.stampDots(red, 0xFF0000, D.MAPDOT_SIZE)
	D.stampDots({ FFPOINT.new(t.x, t.y, 0) }, 0xFFFFFF, D.MAPDOT_SIZE + 4)
	local sig = string.format('%s:%s,%s,%s', tostring(t.kind), tostring(t.id),
		tostring(t.x), tostring(t.y))
	if D.mapDotSig ~= sig then
		D.mapDotSig = sig
		log(string.format('map walk: sweep path - %d path dots, %d junction dots to %s %s at %d,%d',
			#green, #red, tostring(t.kind or 'door'), tostring(t.id), t.x, t.y))
	end
	-- The trace throttles itself (route digest + D.TRACE_MIN_MS), so asking every pass costs
	-- nothing and still captures a plan that keeps its goal and turns the walk round.
	D.traceRoute(bfs, endKey, 'sweep', string.format('sweep target %s %s at %d,%d%s',
		tostring(t.kind or 'door'), tostring(t.id), t.x, t.y,
		(t.why and (' - ' .. tostring(t.why))) or ''))
	return true
end

function D.showWalkMap(world)
	if not D.MAPDOT_ON or not world or not world.walk then return end
	-- Nothing to draw for a run that has been stopped: the dots are the picture of what
	-- the bot is doing, and it is doing nothing.
	if D.stopped() then
		D.sweepTarget = nil
		return
	end
	-- A fight in the boss room is not a walk: no BFS, no dots.
	if D.bossNearHere then
		if not D.mapDotPaused then
			D.mapDotPaused = true
			log('map walk: dots off - fighting in the boss room')
		end
		return
	end
	local now = API.SystemTime()
	if D.mapDotAt and (now - D.mapDotAt) < D.MAPDOT_REFRESH then return end
	D.mapDotAt = now
	-- THE SWEEP'S OWN PATH FIRST. The sweep is what decides this pass - open this
	-- room's doorway, take that key, route to that door - and the dots exist to show
	-- what the bot is doing, so they draw the walk to the tile the sweep picked. This is
	-- the same search (D.walkBfs, physical walk set) the sweep decides on, so the dots
	-- and the click cannot disagree.
	local st = D.sweepTarget
	if st and st.at and (now - st.at) < D.SWEEP_TARGET_MS then
		if D.drawPathToTarget(world, st) then return end
	end
	-- No sweep target this pass: a room solver working the room has no single tile to
	-- draw, so say why the dots are off instead of leaving a stale path on the floor.
	if D.localPlanActive() then
		if not D.mapDotPaused then
			D.mapDotPaused = true
			log('map walk: route paused - the room plan is in action here')
		end
		return
	end
	D.mapDotPaused = nil

	-- ONE PLANNER. D.routePlan is the route the walker actually walks - D.walkPath
	-- hands the very same object to tryOpen - so the dots are not a second opinion
	-- about where to go, they ARE that plan, drawn. Before this the display ran its own
	-- goal search (nextGoalKey / nextGoalDoor plus two fallbacks) while the sweep
	-- decided with roomDoorPlan and bestRouteTarget: two systems, two answers, and the
	-- dots pointed somewhere the bot never went.
	local plan = D.routePlan(world)
	if not plan then return end
	local endKey = plan.endKey
	-- Some plans stop in front of their doorway without an endKey (the walk is over
	-- before that doorway is opened): draw to the tile beside it.
	if not endKey and plan.door then
		endKey = D.nearestReached(plan.bfs, plan.door.x, plan.door.y, 1)
	end
	if not endKey then return end

	local green, red = D.routeDots(plan.bfs, endKey)
	D.clearOldDots()
	D.stampDots(green, 0x00FF00, D.MAPDOT_SIZE)
	D.stampDots(red, 0xFF0000, D.MAPDOT_SIZE)
	local gx, gy, gid, gkind
	if plan.kind == 'key' and plan.key and plan.key.Tile_XYZ then
		gkind, gid = 'key', plan.key.Id
		gx, gy = math.floor(plan.key.Tile_XYZ.x), math.floor(plan.key.Tile_XYZ.y)
	elseif plan.door then
		gkind, gid = 'door', plan.door.id
		gx, gy = plan.door.x, plan.door.y
	end
	if not gx then return end
	D.stampDots({ FFPOINT.new(gx, gy, 0) }, 0xFFFFFF, D.MAPDOT_SIZE + 4)

	-- One line per destination, not per pass: the dot lists are rebuilt every second and the
	-- player moves with them, so logging on the drawn tiles alone is a line (and a trace
	-- block) every second - that is the lag, not useful evidence.
	local sig = string.format('%s:%s,%s,%s', tostring(gkind), tostring(gid),
		tostring(gx), tostring(gy))
	if D.mapDotSig ~= sig then
		D.mapDotSig = sig
		log(string.format('map walk: %d path dots, %d junction dots, %d doorways on the floor - end at %s %s (%d,%d)',
			#green, #red, #(world.doors or {}), tostring(gkind), tostring(gid), gx, gy))
	end
	D.traceRoute(plan.bfs, endKey, 'route', string.format(
		'floor route to %s %s at %d,%d | %d doorway(s) on the floor | %d dot(s)',
		tostring(gkind), tostring(gid), gx, gy, #(world.doors or {}), #green))
end

-- Taking the end ladder moves the run onto the next floor, so every per-floor
-- fact belongs to the floor being left: which rooms are finished, which doors
-- were written off, and whether the boss had already been reached.
local function takeLadder(ladder, world, here)
	local t = ladder.Tile_XYZ
	local px, py = ptile()
	local lx, ly = math.floor(t.x), math.floor(t.y)
	-- The ladder sits INSIDE a wall tile, so it is never walkable and no path test ever
	-- calls it reachable - both are true of every end ladder in Daemonheim. That also means
	-- there is nothing to WALK to: a ground-tile click at a tile 20+ away is not a walk, it
	-- is a click into the client's pathfinder (the "walking to 8055,1259 first" line that
	-- made no sense with the doors shut). The ladder itself is the object - click it from
	-- anywhere and the client walks the player over, which is what the comment below already
	-- says the near case does. So the far branch is gone and there is ONE click path.
	say('taking the end ladder')
	-- Log the click explicitly: the status line is not in the console, so "it walked
	-- next to the ladder and did nothing" was unreadable from the dump. If the object
	-- click cannot be dispatched (stale AllObject, object missing from the live scan),
	-- fall back to an id click instead of silently returning.
	local act = ladder.Action
	if act == nil or act == '' then act = 'End dungeon' end
	log(string.format('end ladder %d at %d,%d - clicking "%s" (dist %d)',
		ladder.Id, lx, ly, tostring(act), math.max(math.abs(lx - px), math.abs(ly - py))))
	local clicked = D.clickScanned(ladder, act, lx, ly, t.z, 20)
	if not clicked then
		log(string.format('end ladder %d at %d,%d: object click not dispatched - trying an id click',
			ladder.Id, lx, ly))
		D.clickObject(act, ladder.Id, lx, ly, t.z, 20)
	end
	API.RandomSleep2(1500, 400, 700)
	settle()
	local px2, py2 = ptile()
	if px2 == px and py2 == py then
		-- A ladder click that moves us nowhere means we are not in the ladder's
		-- room, whatever the model says. Reset the per-floor tables only after THREE
		-- dead clicks: writing the floor's exit off on the first one is how the bot
		-- ended a run with the ladder two tiles away.
		D.ladderFails = D.ladderFails or {}
		local lk = lx .. ',' .. ly
		D.ladderFails[lk] = (D.ladderFails[lk] or 0) + 1
		D.dirty = true
		if D.ladderFails[lk] >= 3 then
			S.ladderBad[lk] = true
			log(string.format('ladder at %d,%d did not move us after %d clicks - writing it off',
				lx, ly, D.ladderFails[lk]))
		else
			log(string.format('ladder at %d,%d did not move us (%d/3) - trying again next pass',
				lx, ly, D.ladderFails[lk]))
		end
		return false
	end
	-- The floor is over: the client is either showing the statistics screen or the
	-- "Time until next dungeon" countdown. Wait for the NEW floor to be announced
	-- ("Floor N High Complexity" / "Dungeon Size: ...") instead of a blind sleep - the
	-- countdown is ~30 s and acting during it means acting on the old map, which is how
	-- the bot announced "ALL MAP DOORS DONE - 1 unopened doorway" on a floor it had
	-- just left. Cap it, because a missed chat line must not hang the run.
	D.floorLeaving = true
	local t0 = API.SystemTime()
	local announced = false
	-- Anchor the sequence number NOW, so the announcement of the floor we just finished
	-- cannot satisfy the test and end the wait immediately.
	D.floorWaitSeq = chat.floorNew or 0
	while (API.SystemTime() - t0) < D.FLOOR_WAIT_MS do
		-- The chat is polled BY THE MAIN LOOP, so a sleep here would never see the
		-- announcement: drain it inside the wait.
		drainChat()
		if chat.floorNew and chat.floorNew > (D.floorWaitSeq or 0) then
			announced = true
			break
		end
		if S.floorChanged then break end          -- the map origin already jumped
		API.RandomSleep2(600, 200, 350)
	end
	D.floorWaitSeq = chat.floorNew or D.floorWaitSeq
	D.floorLeaving = nil
	log(string.format('floor finished: next floor %s after %dms',
		announced and 'announced in chat' or (S.floorChanged and 'map jumped' or 'never announced'),
		API.SystemTime() - t0))
	S.done, S.badDoor, S.attempts = {}, {}, {}
	S.leaveFails = {}
	D.traversed = {}
	D.crossed = nil
	D.travCount = {}
	D.doorUsed = {}
	D.noKeyDoor = {}
	S.arrivedFrom = nil
	S.unwalkable = {}
	S.ladderBad = {}
	clearReach()
	pondReset()
	S.lastTileCount = 0
	floorReset()
	S.bossMode, S.bossFought, S.bossFailed = false, false, false
	D.bossOpen, D.bossWaitLog, D.bossCheck, D.bossRefuseLog = false, nil, 0, nil
	-- The ladder has been taken: the boss-down verdict and the ladder line belong to the
	-- floor that just ended. floorReset() below clears S.floorOrigin, which stops the
	-- "moved 200+ tiles" test from ever firing on the new floor, so this is the ONLY place
	-- these can be cleared - without it the next floor is "cleared" before it starts and
	-- the bot just waits out a floor end that already happened.
	D.bossDown, D.bossDownAt = false, nil
	D.ladderSaid = nil
	D.bossSeenName = nil
	D.bossDoorTile = nil        -- the boss entrance is remembered per floor only
	D.routeSig = nil
	D.visitedRooms, D.reachSeen = {}, {}
	D.noWorkLogged = nil
	S.bossWait = 0
	S.keyTries, S.stuck = 0, 0
	S.leftRooms = {}
	S.visitedEmpty = {}
	S.floorAge = 0
	S.streamTiles, S.streamStill = 0, 0
	D.monoPillarCache = {}
	D.lodeDone, D.lodeClickAt, D.lodeCrystal = nil, nil, nil
	D.lodeActive, D.lodeNoPath = nil, nil
	D.lodeWasOn, D.lodeDodge, D.lodeLast = nil, nil, nil
	D.lodeTries, D.lodePlanLog = nil, nil
	D.lodeHops = nil
	D.chestDone = {}
	D.bridgeTry, D.bridgeWorked, D.bridgeDone = {}, {}, {}
	D.grapTry = {}
	D.chestBlockedLog = nil
	D.npcCache, D.npcCacheAt = nil, 0
	D.dirty = true
end

	------------------------------------------------------------------
	-- exports: what Dung.lua, puzzles.lua and bosses.lua may call
	------------------------------------------------------------------
	X.floorReset, X.takeFloorChanged, X.walkSet, X.segmentSet = floorReset, takeFloorChanged, walkSet, segmentSet
	X.segment, X.roomAt, X.roomNearRooms, X.roomTouch = segment, roomAt, roomNearRooms, roomTouch
	X.roomSidesDir, X.edgeRooms, X.scanWorld, X.buildGraph = roomSidesDir, edgeRooms, scanWorld, buildGraph
	X.keyObtainable, X.doorInRoom, X.doorReachable, X.doorNoKey = keyObtainable, doorInRoom, doorReachable, doorNoKey
	X.doorName, X.isBossDoor, X.doorwayLocked, X.doorwayOpen = doorName, isBossDoor, doorwayLocked, doorwayOpen
	X.doorwayUnfinished = D.doorwayUnfinished
	X.roomHoldsDoorWork = roomHoldsDoorWork
	X.floorDoorsLeft = D.floorDoorsLeft
	X.doorClickable, X.doorWorth, X.roomDoorWork, X.markDoorway = doorClickable, doorWorth, roomDoorWork, markDoorway
	X.doorwayUsedAt, X.doorRecent, X.bossDoorReachable, X.doorwayLeaves = doorwayUsedAt, doorRecent, bossDoorReachable, doorwayLeaves
	X.doorFarRooms, X.doorLeadsToWork, X.nearRoomKey, X.doorLeadsToRoom = doorFarRooms, doorLeadsToWork, nearRoomKey, doorLeadsToRoom
	X.distinctDoorways, X.firstHop, X.nearestKeyOnFloor, X.deadEnds = distinctDoorways, firstHop, nearestKeyOnFloor, deadEnds
	X.findHop, X.tryOpen, X.crossedDoorway, X.frontierHop = findHop, tryOpen, crossedDoorway, frontierHop
	X.blockingDoor, X.findTarget, X.openDoor, X.enterLeaf = blockingDoor, findTarget, openDoor, enterLeaf
	X.leaveRoom, X.doorSide, X.farLeafOf, X.getWorld = leaveRoom, doorSide, farLeafOf, getWorld
	X.propOurs, X.takeLadder = propOurs, takeLadder

	return bind
end
