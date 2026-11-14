local API = require("api")

local D = {}
local S = require("dung_state")   -- floor/room state, see dung_state.lua

local NeededTOReach_NPCS = {}
local NeededTOReach_NPCS_boss = {}---global map
local NeededTOReach_GIFOODS = {}
local NeededTOReach_KEYS_local = {}
local NeededTOReach_KEYS_global = {}---global map
local NeededTOReach_OBJECTS_local = {}---objects stand on tile
local NeededTOReach_OBJECTS_global = {}---global map
local NeededTOReach_BLOCKERS = {}

-- The sub-modules own the map, the puzzle rooms (puzzles.lua)
-- and the boss fights (bosses.lua). They are installed near the bottom of this chunk,
-- once every helper they call back into is in scope - but the functions THIS chunk
-- still calls are needed here from the very first function below, so they are
-- declared here and filled in by that install block. A local declared after the
-- function that uses it is not a local to that function at all: the call would be a
-- nil global.
local blockingDoor, bossAttack, bossDoorReachable, buildGraph, deadEnds
local doorClickable, doorInRoom, doorLeadsToRoom, doorLeadsToWork, doorNoKey
local doorReachable, doorRecent, doorwayOpen, farLeafOf, findBoss
local findHop, findLadder, frontierHop, getWorld, isBossDoor
local leaveRoom, markDoorway, nearestKeyOnFloor, pondReset, pondskaters
local puzzleDone, puzzleMarkSolved, roomAt, roomNearRooms, scanWorld
local solveFerrets, solveFlipTiles, solveIcyPads, solvePondskaters, takeFloorChanged
local takeLadder, tryOpen

-- Bumped on every edit that has to be visible in the console: the log line at
-- startup is the only way to tell "the fix does nothing" from "the client is
-- still running the previous copy of this file".
D.BUILD = 'b2026-11-06 11:18 horde-block-cooldown'

--------------------------------------------------------------------
-- interaction config
--------------------------------------------------------------------

-- action opcodes, taken from the DLL DoAction debug output rather than guessed:
--   Guardian door 'Enter' -> 0x39 / GeneralObject_route0 / dispatch tile at player plane
--   attack NPC            -> 0x2a / AttackNPC_route   (46 of 51 repo call sites)
--   talk to NPC           -> 0x29 / InteractNPC_route
D.ACT_OBJ    = 0x39
D.ACT_ATTACK = 0x2a
D.ACT_TALK   = 0x29
D.ROUTE_OBJ  = API.OFF_ACT_GeneralObject_route0
D.ROUTE_ATK  = API.OFF_ACT_AttackNPC_route
D.ROUTE_PICKUP = API.OFF_ACT_Pickup_route
D.ROUTE_TALK = API.OFF_ACT_InteractNPC_route
D.ACT_TAKE   = 0x2d -- ground item pickup

-- room grid per dungeon size, in rooms
D.LAYOUT = {
	[1] = { 4, 4 },
	[2] = { 4, 8 },
	[3] = { 8, 8 },
}
D.layout = 1

-- A room sits on the floor's lattice as 16x16 tiles: a 1-tile wall on every edge and
-- 14x14 of floor inside. Measured live, not assumed - the room the player stood in was
-- floor 8785..8798 x 1057..1070 (exactly 14x14, walls on 8784/8799 and 1056/1071), and
-- the maze chest, "the chest in the centre of the room", stood on 8791,1047: the dead
-- centre of cell 8784..8799 x 1040..1055. A 4x4 floor is then exactly one 64x64
-- region, which is the origin the room-centre dots are laid out from.
D.ROOM_CELL   = 16
D.ROOM_INNER  = 14
-- The centre of a cell is half a cell, as a FLOAT: a 16-tile cell spans 16 continuous
-- tiles, so its middle is the line between the two middle tiles (origin + 8.0), not the
-- middle of either of them (origin + 7.5). The dot is drawn on that line.
D.ROOM_CENTRE = D.ROOM_CELL / 2
-- THE ROOM TEST. A room is one wall, 14 floor tiles and one wall across, so its floor is
-- every tile within 7 of the centre on the low side and 6 on the high side (the centre is
-- the line BETWEEN the two middle tiles): 7 + 6 + the line = 14. That is the limit a
-- puzzle judges by - a prop, a doorway, a chest or a pedestal inside it is this room's
-- business, anything beyond belongs to the room next door - and it is judged on the
-- lattice, so it cannot shrink when the room blob is cut short.
D.ROOM_RADIUS = 7

--------------------------------------------------------------------
-- ids
--------------------------------------------------------------------

-- NOTE: 51258 ("Door"/"Open") is a prison-cell prop inside rooms, not a dungeon
-- door - it must never be used for progression. Dungeon doorways are 50342
-- ("Door"/"Enter") and sit on the room perimeter, outside the walkable bbox.
-- Guardian doors ("Guardian door") are matched by NAME, not by id: the id list had
-- 50346/50347/50348 + 53949 + 55763 and anything missing from it silently became an
-- ordinary door, so a guardian room could be walked through with its guardians alive.
-- Everything with a readable name is name-matched; only doors whose name is just
-- "Door" need the id tables below.
D.DOOR_NAME_KINDS = {
	['guardian door'] = 'guardian',
}

-- THE BOSS DOOR IS NOT A DOORWAY. Two things make it its own case:
--   * it is a type 12 DECOR named "Boss door" standing at the boss room's entrance, and
--     the client only creates it once the floor is finished and the room is open - so
--     "I cannot see it" says nothing about whether this floor has a boss room;
--   * its leaf is a blocked tile that offers "Enter" - a doorway into the boss, which is
--     the player's call, never the door task's.
-- So it gets its own record flag and its own dot colour, it is never paired and never
-- clicked by D.openLocalDoors. THE NAME IS THE ONLY HANDLE: the leaf id is not stable
-- (50351 and 50352 have both been read live), and every boss door record has a readable
-- name, so no id table is kept here.
-- How close a doorway has to stand to the boss door marker to BE the way in. The marker
-- stands in the boss room, one tile from the doorway it belongs to (live: a leaf at
-- 8616,479 beside the doorway at 8616,480), and the doorway itself is an ordinary door of
-- some kind - normal, guardian or key, "doesn't matter which". Two tiles covers the marker
-- being one step in and the doorway's own leaves being on either face.
D.BOSS_PASSAGE_R = 2
function D.isBossDoor(o)
	local name = string.lower(D.objName(o) or '')
	return name ~= '' and string.find(name, D.BOSS_DOOR_NAME or 'boss door', 1, true) ~= nil
end

D.DOOR_BACK     = { 55762, 50342, 50343, 50344, 53948 }
D.DOOR_BASIC    = {
	53967, 53964, 55749, 55745, 53952, 53955, 53973, 55743, 55761, 55747,
	55755, 50304, 50320, 50321, 50322, 50303, 50302, 49306, 49335, 49336,
	50341, 50339, 50338, 50340, 49337, 49338, 49375, 49625, 50312, 50313,
	50311, 50276, 50277, 50275, 50285, 50297, 50296, 50298, 50290, 50291,
	50292, 50284, 50285, 50286, 55740, 53959, 53957,
}
D.DOOR_PUZZLE   = {
	33654, 49306, 49335, 49336, 49337, 49338, 49375, 49376, 49377, 49378,
	49379, 49380, 49387, 49388, 49389, 49462, 49463, 49464, 49504, 49505,
	49506, 49516, 49517, 49518, 49564, 49565, 49566, 49574, 49575, 49576,
	49577, 49578, 49579, 49603, 49604, 49605, 49606, 49607, 49608, 49625,
	49626, 49627, 49644, 49645, 49646, 49650, 49651, 49652, 49677, 49678,
	49679, 53987, 53988, 53989, 53990, 53992, 54001, 54006, 54067, 54070,
	54071, 54072, 54073, 54000, 54106, 54107, 54108, 54109, 54236, 54274,
	54284, 54299, 54300, 54315, 54316, 54317, 54318, 54319, 54320, 54335,
	54360, 54361, 54362, 54363, 54404, 54417, 54620, 55478, 55479, 55480,
	55481, 56079, 56081, 56526, 56527, 56528, 56529,
}


D.KEY_ITEMS = {
	yellow  = { 18234, 18236, 18238, 18240, 18242, 18244, 18246, 18248 },
	green   = { 18250, 18252, 18254, 18256, 18258, 18260, 18262, 18264 },
	blue    = { 18266, 18268, 18270, 18272, 18274, 18276, 18278, 18280 },
	orange  = { 18202, 18204, 18206, 18208, 18210, 18212, 18214, 18216 },
	silver  = { 18218, 18220, 18222, 18224, 18226, 18228, 18230, 18232 },
	purple  = { 18282, 18284, 18286, 18288, 18290, 18292, 18294, 18296 },
	crimson = { 18298, 18300, 18302, 18304, 18306, 18308, 18310, 18312 },
	gold    = { 18314, 18316, 18318, 18320, 18322, 18324, 18326, 18328 },
}


D.KEY_IDS, D.KEY_SET, D.KEY_COLOR = {}, {}, {}
for color, list in pairs(D.KEY_ITEMS) do
	for i = 1, #list do
		D.KEY_IDS[#D.KEY_IDS + 1] = list[i]
		D.KEY_SET[list[i]] = true
		D.KEY_COLOR[list[i]] = color
	end
end


D.ACT_DEFAULT = 0x39

-- Skill doors are matched by NAME, never by id: the wiki's skill-door table is a list
-- of names, the same door exists under several model ids (539xx / 557xx variants), and
-- ids go stale with every model added - the Augmented door (137186) was invisible to
-- this script for exactly that reason. Key = the name lower-cased, value = the option the
-- door itself offers, i.e. the thing that is clicked. `true` = the live option has not
-- been recorded yet, so any option counts and the name alone identifies the door.
-- SINGLE-LEAF SKILL DOORS. These have a front and NO back leaf at all, and the prop is
-- replaced the moment the skill lands - so (a) they must never be looked for as a pair,
-- and (b) their option text is not worth trusting. The NAME alone identifies them; the
-- list is separate so the exception is visible instead of being buried in the table above.
D.SKILL_DOOR_SINGLE = {
	['Divine door'] = true,
}

D.SKILL_DOOR_NAMES = {
	['Runed door']            = 'Imbue',
	['Barred door']           = 'Force-bar',
	['Pile of rocks']         = 'Mine',
	['Flammable debris']      = 'Burn',
	['Magical barrier']       = 'Dispel',
	['Dark spirit']           = 'Exorcise',
	['Wooden barricade']      = 'Chop down',
	['Broken key door']       = 'Repair-key',
	['Broken pulley door']    = 'Fix-pulley',
	['Locked door']           = 'Disarm ',
	['Padlocked door']        = 'Pick-lock',
	['Ramokee exile']         = 'Dismiss',
	['Liquid lock door']      = 'Add compounds',
	-- Live action is "Prune-vines", not "Prune" (checked in the client): the exact-text
	-- test missed it, the door fell through to the pair search, was marked as a pair and
	-- was never clicked. D.skillDoorMatch now matches word-prefixes too, so either text
	-- works - the table keeps the live one.
	['Vine-covered door']     = 'Prune-vines',
	['Collapsing doorframe']  = 'Repair',
	['Augmented door']        = 'Disassemble',
	['Mound of dirt']         = 'Excavate',
}
D.SKILL_DOOR_NAMES_FIND = {}
for id in pairs(D.SKILL_DOOR_NAMES) do
	D.SKILL_DOOR_NAMES_FIND[#D.SKILL_DOOR_NAMES_FIND + 1] = id
end
for id in pairs(D.SKILL_DOOR_SINGLE) do
	D.SKILL_DOOR_NAMES_FIND[#D.SKILL_DOOR_NAMES_FIND + 1] = id
end

-- Skill-door actions, kept only as a second net: an object whose only option is one of
-- these and whose name says "door" (or matches a skill name above) is a door even if
-- the name lookup misses. Note "Mine" is deliberately excluded - the toxin maze's
-- "Pedestal" offers Mine and is not a door.
D.SKILL_ACTS = {
	['Chop'] = true, ['Chop down'] = true, ['Chop-down'] = true,
	['Disassemble'] = true, ['Force-bar'] = true, ['Imbue-energy'] = true,
	['Fix-pulley'] = true, ['Repair'] = true, ['Burn'] = true,
	['Pick-lock'] = true, ['Dismiss'] = true, ['Dispel'] = true,
	['Prune'] = true, ['Excavate'] = true, ['Exorcise'] = true, ['Imbue'] = true,
}

-- floor-complete ladder only. 51156 "Dungeon exit" is the dungeon's entrance
-- stairs ("Climb up") - touching it leaves the dungeon, so it must be ignored.
D.LADDER_IDS        = { 49695, 49696, 49698, 49697, 49699, 49700, 53747, 53748, 55483, 55484 }

D.SMUGGLER   = 11226
D.GROUP_STONE = 18829

-- Two ids, both seen live: 10975 offers "Activate" (start) and becomes 10978
-- "Count-charges" the moment the click lands (progress). The CHARGED state keeps
-- the same id and the same option, so "done" can never come from the id - it is
-- read from the room instead (see solveMonolith).
D.MONOLITH_IDS      = { 10975, 10976, 10977, 12175, 12971 }
D.MONOLITH_PROGRESS = { 10978, 10979, 10980, 12176, 12972 }
D.MONOLITH_ANIM     = 13072   -- passive animation of a charging monolith
D.MONOLITH_SET, D.MONOLITH_ACTIVE_SET = {}, {}
for i = 1, #D.MONOLITH_IDS do D.MONOLITH_SET[D.MONOLITH_IDS[i]] = true end
for i = 1, #D.MONOLITH_PROGRESS do D.MONOLITH_ACTIVE_SET[D.MONOLITH_PROGRESS[i]] = true end

-- Per-room puzzle state for the monolith, and the room whose door write-offs must
-- be dropped once the pillar is charged. On D because the boss gate (defined much
-- earlier in the file than the puzzle itself) has to see them.
D.monoState = {}
D.monoGateLog = {}
D.monoClearRoom = nil
D.leaderState = {}       -- room key -> { tries, solved } for follow-the-leader

-- Is this npc a monolith (any theme variant, activated or not)? On D, not a
-- local: the 200-local budget is shared by everything in this file.
function D.isMonolith(n)
	if D.MONOLITH_SET[n.Id] or D.MONOLITH_ACTIVE_SET[n.Id] then return true end
	return string.find(string.lower(n.Name or ''), 'monolith', 1, true) ~= nil
end

--------------------------------------------------------------------
-- derived tables
--------------------------------------------------------------------

D.doorKind, D.doorMeta = {}, {}
local function idxDoors(list, kind, meta)
	for i = 1, #list do
		D.doorKind[list[i]] = kind
		if meta then D.doorMeta[list[i]] = meta end
	end
end

idxDoors(D.DOOR_BACK, 'back')
idxDoors(D.DOOR_BASIC, 'basic')
idxDoors(D.DOOR_PUZZLE, 'puzzle')
-- Guardian doors and skill doors are recognised by NAME in scanWorld: an id table for
-- them is one update behind the game and made whole doorways invisible.

-- Key doors are matched by their own name: 64 keys share 384 door ids, so ids are
-- useless for telling one key door from another. The name carries colour and
-- shape, and the shape order below was read from the item cache
-- ("Orange triangle key" .. etc). There is no id table and no id fallback.
D.SHAPES = { 'triangle', 'diamond', 'rectangle', 'pentagon', 'corner', 'crescent', 'wedge', 'shield' }

local function doorKeyFromName(name)
	local n = string.lower(name or '')
	local ci, shape = nil, nil
	for i = 1, #D.KEY_COLOUR_ORDER do
		if string.find(n, D.KEY_COLOUR_ORDER[i], 1, true) then ci = i break end
	end
	for i = 1, #D.SHAPES do
		if string.find(n, D.SHAPES[i], 1, true) then shape = i - 1 break end
	end
	if not ci or not shape then return nil end
	return D.KEY_ITEMS[D.KEY_COLOUR_ORDER[ci]][shape + 1]
end

D.doorKeyFromName = doorKeyFromName

-- key item -> key varclient. Base 1812, colour order by item id, shape = index.
-- Verified: cvar 1815 = 1 while holding 18208 (orange pentagon).
D.KEY_VARC_BASE = 1812
D.KEY_COLOUR_ORDER = { 'orange', 'silver', 'yellow', 'green', 'blue', 'purple', 'crimson', 'gold' }
D.keyCvar = {}
for ci, name in ipairs(D.KEY_COLOUR_ORDER) do
	local items = D.KEY_ITEMS[name]
	for shape = 0, 7 do
		D.keyCvar[items[shape + 1]] = D.KEY_VARC_BASE + (ci - 1) * 8 + shape
	end
end

local function pkey(x, y)
	-- The engine hands back a NaN/inf tile for an object that is spawning or being removed,
	-- and math.floor of that is still a float with no integer representation, so
	-- string.format('%d') throws - "bad argument #2 to 'format'" from the toxin-maze scan
	-- killed the whole script. Such a prop has no usable tile: give it a key that is on no
	-- grid and let every caller's bounds test reject it.
	local fx, fy = math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0)
	if fx ~= fx or fy ~= fy
		or fx == math.huge or fx == -math.huge
		or fy == math.huge or fy == -math.huge
		or math.abs(fx) > 9007199254740992 or math.abs(fy) > 9007199254740992 then
		return 'off:off'
	end
	return string.format('%d:%d', fx, fy)
end
-- Room key. nil-safe on purpose: the room is only known once the grid around the player
-- has been read, and a solver handed a nil room used to die here - live, 19 passes of
-- "solver pondskaters threw: attempt to index a nil value (local 'r')" in one run.
local function rkey(r)
	if not r then return '?' end
	return r.minx .. ':' .. r.miny
end
-- print() is the only channel that reaches the debug text window in this DLL
-- build (API.logInfo/logError land in the in-game script log only), so every
-- line goes through print and the buffer is dumped to disk when the run ends.
local function log(m) print('[Dung] ' .. m) end
local function warn(m) print('[Dung] ! ' .. m) end
-- the same text is mirrored into the ImGui status box, so keep the last one
local function say(m) D.status = m API.Write_ScripCuRunning0('Dung: ' .. m) end
-- What the loop is doing RIGHT NOW, in one short line for the on-screen window: each branch
-- of the main chain sets it when it takes the pass, so the window cannot show a stale
-- "puzzle" while the bot is actually looting keys. `say` is the human sentence that goes to
-- the client, this is the machine state that the ImGui window draws.
function D.setStateNow(s) D.stateNow = s end
local function code(a) return D.CODE[a] or D.ACT_DEFAULT end
local function ptile() local p = API.PlayerCoord(); return math.floor(p.x), math.floor(p.y) end

-- Doors are keyed by the doorway TILE, never by id. A key door swaps id when it
-- is unlocked (50266 "Unlock" -> 50411 "Enter"), so an id-based key makes the
-- same physical door look brand new and it gets opened a second time.
local function dkey(d) return d.x .. "," .. d.y end

-- Doorways already walked through this floor. Both leaves are marked when a
-- doorway is used (see markDoorway), so the doorway behind us never looks worth
-- going back to and the bot cannot ping-pong between two rooms. The room pair is
-- recorded as well, which is all that is known when segmentation merges an area
-- into one blob.
D.traversed = {}
D.travCount = {}
-- How long the loop may stand frozen with the same state and status before it says so.
-- A pass that decides nothing, clicks nothing and logs nothing is invisible in the
-- console, and "it does not do anything" is exactly what that looks like from outside.
D.IDLE_WARN_MS = 12000
-- Doorways the client told us we have no key for ("you'll need the key").
D.noKeyDoor = {}
D.lastDoorTile = nil

local function pairKey(a, b)
	if a > b then a, b = b, a end
	return a .. '-' .. b
end

-- Is any doorway tile on the straight line between two tiles? StarPath answers "can I
-- walk to the boss", which is TRUE across a floor of open doorways - it says nothing
-- about being in the same room. A doorway between us and the npc is the fact that
-- matters: the corridor is one tile wide, so the leaves of that doorway sit inside the
-- rectangle spanned by the two tiles. Enemies and bosses never stand on a doorway.
-- Is a doorway ON THE LINE between two tiles? This used to be a BOUNDING BOX test - any
-- doorway inside the rectangle spanned by the two tiles counted, and a whole wall with no
-- doorway on the line counted as "no doorway between us". That is how a boss in the next
-- room (visible over/through a wall, within D.BOSS_ENGAGE_DIST, no doorway inside the
-- rectangle) satisfied "we are in its room" and the fight started from outside. A line
-- walk is the fact being asked for; the 1-tile band covers the 1-2 tile wide corridor a
-- doorway sits in, because a diagonal line can slip past the two door tiles.
-- `skip` excuses one doorway (both its leaves): the one we walked in through.
function D.doorBetween(world, x1, y1, x2, y2, skip)
	if not world then return false end
	local doors = world.doors or {}
	local byTile = {}
	for _, d in ipairs(doors) do byTile[d.x .. ',' .. d.y] = d end
	local skipSet = nil
	if skip and skip.x and skip.y then
		for _, d in ipairs(doors) do
			if math.abs(d.x - skip.x) <= 1 and math.abs(d.y - skip.y) <= 1 then
				skipSet = skipSet or {}
				skipSet[d.x .. ',' .. d.y] = true
			end
		end
	end
	local x, y = math.floor(x1), math.floor(y1)
	local tx, ty = math.floor(x2), math.floor(y2)
	local dx, dy = math.abs(tx - x), math.abs(ty - y)
	local sx = (x < tx) and 1 or -1
	local sy = (y < ty) and 1 or -1
	local err = dx - dy
	while true do
		for _, n in ipairs({ { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local k = (x + n[1]) .. ',' .. (y + n[2])
			local d = byTile[k]
			if d and not (skipSet and skipSet[k]) then return true, d end
		end
		if x == tx and y == ty then break end
		local e2 = 2 * err
		if e2 > -dy then err = err - dy x = x + sx end
		if e2 < dx then err = err + dx y = y + sy end
	end
	return false
end


-- EVERY PUZZLE BELONGS TO ONE ROOM, and this is the single test that says so. The room
-- blob cannot answer it - it merges through open doorways and splits one room in two - so
-- the answer is the doorway line: a doorway standing between us and the prop means the
-- prop is the next room's business. Props close enough that no doorway can sit between us
-- and them skip the walk (D.ROOM_NEAR: two tiles of prop plus the corridor a doorway
-- needs).
-- Solvers that scan by a radius are the ones that get this wrong, and it is not cosmetic:
-- the icy-pad solver's pad box grew from pads in the next room until its slide search
-- covered most of the floor ("solver icy pads threw: not enough memory", "it thinks really
-- hard and cannot decide"), and a boss in the next room used to satisfy "we are in its
-- room" the same way.
-- The doorway we walked in through is not a wall between us and the room's props: it
-- sits one tile from where we land, so the doorway line test finds it on every
-- question and every "is this really our room?" answer comes back no. It is excused
-- only while we are still standing next to it, and only that doorway.
-- Nothing sets D.enteredDoor any more - the doorway walker is gone with the map half -
-- so this answers nil and every caller falls back to the plain line test. It stays
-- because D.propInMyRoom calls it unguarded.
D.ENTERED_DOOR_R = 4
function D.enteredDoorSkip()
	local d = D.enteredDoor
	if not (d and d.x and d.y) then return nil end
	local px, py = ptile()
	if math.max(math.abs(px - d.x), math.abs(py - d.y)) > D.ENTERED_DOOR_R then return nil end
	return d
end

D.ROOM_NEAR = 4
function D.propInMyRoom(world, px, py, x, y, skip)
	if not (px and py and x and y) then return true end
	if math.max(math.abs(x - px), math.abs(y - py)) <= D.ROOM_NEAR then return true end
	if not world or not D.doorBetween then return true end
	if skip == nil then skip = D.enteredDoorSkip() end
	return not D.doorBetween(world, px, py, x, y, skip)
end

-- Reading .Name off a live AllObject can throw ("caught (...) exception" in metamethod
-- 'index' killed a run inside isBossDoor), so every code path that runs per door per
-- pass goes through this instead of touching the userdata directly.
function D.objName(o)
	if o == nil then return '' end
	local ok, v = pcall(function() return o.Name end)
	if ok and type(v) == 'string' then return v end
	return ''
end

-- Any other field, read the same way. The scan hands back raw engine userdata, and an
-- entity removed between the scan and the read leaves a dead pointer behind: then even
-- `o.Action` throws inside the engine's __index, which takes the whole script with it.
function D.objGet(o, key)
	if o == nil then return nil end
	local ok, v = pcall(function() return o[key] end)
	if ok then return v end
	return nil
end

-- Tile x,y of a scanned entity, nil when it cannot be read or is a NaN/inf tile (a prop
-- that is spawning or being removed reports one, and math.floor of it has no integer
-- representation - string.format('%d') then throws and kills the run).
function D.objTile(o)
	if o == nil then return nil end
	local ok, x, y = pcall(function()
		local t = o.Tile_XYZ
		if not t then return nil end
		return t.x, t.y
	end)
	if not ok then return nil end
	x, y = tonumber(x), tonumber(y)
	if not x or not y or x ~= x or y ~= y then return nil end
	if math.abs(x) > 1e15 or math.abs(y) > 1e15 then return nil end
	return x, y
end

-- Can this prop be clicked at all? Two independent signals, and neither alone is
-- enough:
--   Bool1 == 1   -> the client has no action on it (a lit lodestone, a spent object)
--   Action == '' -> no option text even when Bool1 reads 0
-- Read behind pcall: a record that outlived its entity throws from the engine's
-- __index, and a record that cannot be read is not interactable.
function D.interactable(o)
	if o == nil then return false end
	local ok, b1, act = pcall(function() return o.Bool1, o.Action end)
	if not ok then return false end
	if (tonumber(b1) or 0) == 1 then return false end
	return type(act) == 'string' and act ~= ''
end

local function clearReach()
	S.doorCutOff = {}
end

-- Where the player came from, as a room key. Target selection refuses this room
-- (unless it holds a key or an enemy) so two empty rooms cannot shuttle the bot
-- back and forth through the same doorway.

--------------------------------------------------------------------
-- chat events: the only trustworthy "puzzle solved" signal in Daemonheim
--------------------------------------------------------------------
-- Completed puzzles announce themselves in chat, and a locked door answers
-- "You'll need the key" while its puzzle is unsolved. GatherEvents_chat_check
-- DRAINS its buffer, so it is polled once per iteration into a ring buffer of
-- our own - otherwise the message is gone before the puzzle logic looks at it.
local chat = {
	lines          = {},   -- our own ring of sanitised lines
	seq            = 0,    -- sequence number of the last line added
	solvedSeq      = 0,    -- last generic "puzzle solved" message
	pondSeq        = 0,    -- pondskater completion text (needs a pond room)
	keySeq         = 0,    -- last "you need the key" message
	icyCount       = 0,    -- "You have completed N of 4" from the icy pad room
	icySeq         = 0,
	grooveSafe     = 0,    -- "There's definitely no trap here" (suspicious grooves)
	grooveTrap     = 0,    -- "There's definitely a trap here" / "set it off from a distance"
	noReach        = 0,    -- "You can't reach that." - a click the client refused
	needLevel      = 0,    -- "You need a <skill> level of N" - a skill door we cannot open
	barrierRefused = 0,    -- toxin maze: "unable to move through the barrier" - Go-through failed
	barrierDispelled = 0,  -- toxin maze: "You dispel the magical barrier" - Go-through worked
	floorCountdown = 0,    -- "Time until next dungeon: N" - the floor is over
	floorNew       = 0,    -- "Floor N High Complexity" / "Dungeon Size: ..." - new floor
	lastSolvedLine = nil,  -- the exact message that finished a puzzle
	cursor         = 0,    -- non-destructive reader position
	probed         = false,
	handledSolved  = 0, handledKey = 0, handledPond = 0, handledNoReach = 0,
}
D.CHAT_KEEP = 40
D.CHAT_SOLVED = {
	'you have solved', 'puzzle solved', 'solved the puzzle',
	'puzzle complete', 'puzzle has been', 'puzzle is solved',
	-- Daemonheim's own wording when a puzzle room unlocks ("the doors in the room
	-- are now unlocked") - this is what Monolith.java listens for. "fully charged"
	-- must NOT be in here: a locked door answers "It won't open until the monolith
	-- has been fully charged", which marked the room solved on the refusal itself.
	'now unlocked',
}
-- Pondskater-specific completion text. It says nothing about "puzzle", and the
-- same wording can arrive while the bot is on another floor, so it only counts
-- when the room we are standing in is one we have actually seen skaters in.
D.CHAT_POND = {
	'deactivate the magical seals', 'magical seals', 'retrieving the key',
}
D.CHAT_NEEDKEY = { "need the key", "need a key", "you'll need" }

local function matchesAny(line, patterns)
	for i = 1, #patterns do
		if string.find(line, patterns[i], 1, true) then return patterns[i] end
	end
	return nil
end

-- The whole event, not just .text: GatherEvents_chat_check fills name/name2/name3
-- and chat_type as well, and a split message ("<player> says:" + body) only makes
-- sense as a whole. Everything is joined into one line so pattern matching sees
-- all of it too.
local function chatWhole(ev)
	local parts = {}
	-- The event structs carry uninitialised tail bytes, so some events arrive as
	-- binary rubbish (the dump was half garbage lines). Anything outside printable
	-- ASCII is stripped, and a field with nothing printable left is dropped.
	local function clean(v)
		if type(v) ~= 'string' or v == '' then return nil end
		v = v:gsub('[^\32-\126]', '')
		v = v:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
		-- uninitialised event bytes survive the ASCII filter as stray punctuation;
		-- a real message always has letters in it
		local _, letters = v:gsub('%w', '')
		if letters < 3 then return nil end
		return v
	end
	local function add(v)
		local c = clean(v)
		if c then parts[#parts + 1] = c end
	end
	add(ev.chat_type and ('[' .. ev.chat_type .. ']'))
	add(ev.name)
	add(ev.name2)
	add(ev.name3)
	add(ev.text)
	if type(ev.skillName) == 'string' and ev.skillName ~= '' then
		parts[#parts + 1] = 'skill=' .. ev.skillName
			.. (type(ev.exp) == 'number' and ('+' .. tostring(ev.exp)) or '')
	end
	if type(ev.ItemID) == 'number' and ev.ItemID > 0 then
		parts[#parts + 1] = 'item=' .. tostring(ev.ItemID)
			.. (type(ev.ItemAM) == 'number' and ('x' .. tostring(ev.ItemAM)) or '')
	end
	if #parts == 0 then return nil end
	return table.concat(parts, ' ')
end

-- GatherEvents_chat_check returns a VECTOR<EventData> (Detours.cpp:1114), i.e. a
-- Lua array of events - not a single event. Reading it as one object meant .text
-- was always nil and no chat was ever seen.
local function handleChatEvent(ev)
	if ev == nil then return end
	local whole = chatWhole(ev)
	if not whole then return end
	local line = string.lower(whole)
	chat.lines[#chat.lines + 1] = line
	if #chat.lines > D.CHAT_KEEP then table.remove(chat.lines, 1) end
	chat.seq = chat.seq + 1
	if chat.seq == 1 then log('chat events are flowing') end
	local solved = matchesAny(line, D.CHAT_SOLVED)
	local pond = matchesAny(line, D.CHAT_POND)
	if solved then
		chat.solvedSeq = chat.seq
		chat.lastSolvedLine = whole
	elseif pond then
		chat.pondSeq = chat.seq
		chat.lastSolvedLine = whole
	end
	-- Skeletal Horde: the Divine skinweaver is the one who calls out the tunnels. The java
	-- boss blocks a tunnel only while it has a message, so the chat line is the trigger -
	-- blocking them unprompted is wasted clicks.
	if string.find(line, 'tunnel', 1, true) then chat.hordeAt = API.SystemTime() end
	-- Har'Lakk the Riftsplitter casts a portal THROUGH THE TILE THE PLAYER STANDS ON and
	-- announces it ("miasma", "flame portal", "cut you"). Standing in it is the whole
	-- damage source, so the cast tile and the time are recorded here - the boss logic
	-- (D.bossLogic.riftsplitter) steps off it. Same trigger and 10 s lifetime as
	-- MegaDungeon's Riftsplitter.java.
	if string.find(line, 'miasma', 1, true) or string.find(line, 'flame portal', 1, true)
		or string.find(line, 'cut you', 1, true) then
		local rpx, rpy = ptile()
		chat.riftPortals = chat.riftPortals or {}
		chat.riftPortals[#chat.riftPortals + 1] = { x = rpx, y = rpy, at = API.SystemTime() }
		if #chat.riftPortals > 4 then table.remove(chat.riftPortals, 1) end
	end
	-- Stomp's crystal phase. The boss announces it ("enters a defensive stance ... no
	-- longer protecting the portal's lodestones") and then repeats "Stomp is currently
	-- invulnerable!" for as long as it lasts. Those lines are the ONLY signal that
	-- separates "the lodestones want charging" from "the lodestones are scenery": they
	-- offer "Charge" before, during and after the fight (read live in the boss room).
	--
	-- TWO stamps, because the two lines are not the same thing: the stance line OPENS a
	-- phase (what was placed for the last one must be forgotten), while "currently
	-- invulnerable" only says the phase is still on - and it is also what our own
	-- wasted swing produces, so it must never reset the placement count.
	if string.find(line, 'defensive stance', 1, true) then
		chat.stompPhaseAt = API.SystemTime()
		chat.stompPhaseStart = chat.stompPhaseAt
	elseif string.find(line, 'currently invulnerable', 1, true) then
		chat.stompPhaseAt = API.SystemTime()
	end
	-- Shadow-Forger Ihlakhizan announces the stat-draining flash before it fires ("...
	-- begins to glow ..."). The boss ANIMATION (13030) is the primary trigger; this line
	-- arms the same hide for a frame the scan misses. Restricted to the boss's own name so
	-- a player saying "glow" cannot send the bot behind a pillar.
	if string.find(line, 'glow', 1, true)
		and (string.find(line, 'ihlakhizan', 1, true)
			or string.find(line, 'shadow-forger', 1, true)) then
		chat.shadowGlowAt = API.SystemTime()
	end
	local key = matchesAny(line, D.CHAT_NEEDKEY)
	if key then chat.keySeq = chat.seq end
	-- Icy pad room reports its own progress: sliding OVER a square activates it, and
	-- the counter is the only trustworthy "how many are left" signal.
	local icyN = string.match(line, 'completed%s+(%d+)%s+of%s+4')
	if icyN then
		chat.icyCount, chat.icySeq = tonumber(icyN) or 0, chat.seq
	end
	-- Suspicious grooves: investigating a tile answers whether it is trapped. These
	-- chat lines ARE the puzzle: the object does not rename itself on this floor
	-- (live 14:23: "grooves: 7240,275 answered "Suspicious grooves" (check)" twice in a
	-- row after real investigations), so the answer only ever arrives here.
	if string.find(line, 'definitely no trap', 1, true)
		or string.find(line, 'no trap', 1, true)
		or string.find(line, 'sense no trap', 1, true) then
		chat.grooveSafe = chat.seq
	elseif string.find(line, 'definitely a trap', 1, true)
		or string.find(line, 'set it off from a distance', 1, true)
		-- plain find: the hyphen is literal here, so it must NOT be escaped ('trap%-sense'
		-- looked for a backslash and never matched the live line at all)
		or string.find(line, 'trap-sense', 1, true)
		or string.find(line, 'trap sense', 1, true) then
		chat.grooveTrap = chat.seq
	end
	-- A SKILL DOOR CAN REFUSE FOR A LEVEL, not for the click ("You need a Smithing level
	-- of 71 to open this door"). Without this the only signal was "the far leaf never
	-- appeared", which took D.SKILL_TRIES attempts - and while the doorway stayed
	-- unfinished the whole floor stayed open behind it.
	if (string.find(line, 'level of', 1, true) or string.find(line, 'level to', 1, true))
		and (string.find(line, 'need', 1, true) or string.find(line, 'requir', 1, true)) then
		chat.needLevel = chat.seq
	elseif string.find(line, 'not high enough', 1, true)
		or string.find(line, 'do not have the required', 1, true)
		or string.find(line, "don't have the required", 1, true) then
		chat.needLevel = chat.seq
	end
	-- Floor transitions. After the end ladder the dungeon takes ~30 s to come back
	-- ("Time until next dungeon: 30 ... 1"), and only then is the new floor announced
	-- ("Floor 14 High Complexity" / "Dungeon Size: Small"). Those two messages are what
	-- say the previous floor is really over - a fixed sleep either wastes 10 s or acts
	-- on the old map for the last half of the countdown.
	if string.find(line, 'time until next dungeon', 1, true) then
		chat.floorCountdown = chat.seq
	elseif string.find(line, 'high complexity', 1, true)
		or string.find(line, 'dungeon size', 1, true) then
		chat.floorNew = chat.seq
	end
	-- "You can't reach that." is the client refusing a click on something it cannot
	-- path to. Repeating that click is exactly what looks like a bot and gets
	-- accounts flagged, so the doorway is written off from the first refusal.
	if string.find(line, "can't reach that", 1, true)
		or string.find(line, 'cant reach that', 1, true) then
		chat.noReach = chat.seq
	end
	-- The toxin maze's answer to a "Go-through" that did NOT work. Without it the only
	-- signals were "You can't reach that" (which a refused barrier does not say) and how
	-- close the player ended up - and a refused click still walks the player NEXT to the
	-- barrier, so "standing beside it" was read as "went through it" and the solver skipped
	-- barriers it had never dispelled.
	if string.find(line, 'unable to move through the barrier', 1, true) then
		chat.barrierRefused = chat.seq
	end
	if string.find(line, 'dispel the magical barrier', 1, true) then
		chat.barrierDispelled = chat.seq
	end

	-- Echo everything the game says, and which rule it tripped. This is the only
	-- way to see why a puzzle did or did not register: the buffer drains on read,
	-- so a missed message can never be inspected afterwards.
	if icyN then
		log(string.format('chat: %s -> icy pads %s of 4', whole, icyN))
	elseif chat.grooveSafe == chat.seq then
		log(string.format('chat: %s -> groove is SAFE', whole))
	elseif chat.grooveTrap == chat.seq then
		log(string.format('chat: %s -> groove is TRAPPED', whole))
	elseif solved then
		log(string.format('chat: %s -> puzzle solved (rule "%s")', whole, solved))
	elseif pond then
		log(string.format('chat: %s -> pondskater done (rule "%s")', whole, pond))
	elseif key then
		log(string.format('chat: %s -> needs a key (rule "%s")', whole, key))
	elseif D.CHAT_ECHO_ALL then
		log(string.format('chat: %s', whole))
	end
end

-- GatherEvents_chat_read is the NON-destructive, cursor-based variant
-- (Sol2v3_loader.cpp:2554). GatherEvents_chat_check clears the whole ring on
-- read, and the DLL's own consumers (ChatBot, WebSocket, chat debug window) poll
-- the same ring - so whichever gets there first wins and the script sees nothing.
-- Cursor first, destructive drain only as a fallback.

local function drainChat()
	local reader = API.GatherEvents_chat_read or GatherEvents_chat_read
	if not chat.probed then
		chat.probed = true
		log(string.format('chat pump: read=%s check=%s',
			type(reader), type(API.GatherEvents_chat_check)))
	end
	-- sol callables can surface as userdata with a __call metamethod, so both
	-- shapes are accepted rather than trusting type() == 'function'
	local rt = type(reader)
	if rt == 'function' or rt == 'userdata' then
		local res = reader(chat.cursor)
		if type(res) ~= 'table' then return end
		if type(res.seq) == 'number' then chat.cursor = res.seq end
		local evs = res.events
		if type(evs) == 'table' then
			for _, ev in ipairs(evs) do handleChatEvent(ev) end
		end
		return
	end
	if not API.GatherEvents_chat_check then return end
	local res = API.GatherEvents_chat_check()
	if res == nil then return end
	-- the check returns a VECTOR<EventData> (Detours.cpp:1114), i.e. a Lua array
	if type(res) ~= 'table' or res.text ~= nil or res.name ~= nil then
		handleChatEvent(res)
		return
	end
	for _, ev in ipairs(res) do handleChatEvent(ev) end
end

-- Set false to only echo the messages that actually matched a rule.
D.CHAT_ECHO_ALL = true

-- "Solved" is taken once per message, so a stale line cannot clear every room.
local function takeChatSolved()
	if chat.solvedSeq > chat.handledSolved then
		chat.handledSolved = chat.solvedSeq
		return true
	end
	return false
end

local function takeChatNeedKey()
	if chat.keySeq > chat.handledKey then
		chat.handledKey = chat.keySeq
		return true
	end
	return false
end

function D.takeChatNoReach()
	if chat.noReach > chat.handledNoReach then
		chat.handledNoReach = chat.noReach
		return true
	end
	return false
end

local function takeChatPond()
	if chat.pondSeq > chat.handledPond then
		chat.handledPond = chat.pondSeq
		return true
	end
	return false
end

local function countKeys(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function inList(t, v)
	for i = 1, #t do
		if t[i] == v then return true end
	end
	return false
end

-- Raw varclient read. VC_FindPSett returns the VB usertype, so .state is read by
-- indexing; a negative state means the node is not set.
local function readVC(id)
	local vb = API.VC_FindPSett(id)
	if vb == nil then return nil end
	if type(vb) == 'number' then
		if vb == -1 then return 0 end
		return (vb >= 0) and vb or nil
	end
	local state = vb.state
	if state == nil then return nil end
	if state == -1 then return 0 end
	return (state >= 0) and state or nil
end

-- These two can come back as true/false or 1/0; 0 is truthy in Lua, so compare
-- explicitly instead of relying on the value being a boolean.
local function isMoving()
	local v = API.ReadPlayerMovin2()
	return v == true or v == 1
end

-- LocalPlayer_IsInCombat_ says the player is fighting something; varclient 2059
-- holds our own combat target and is above 0 only while we actually have one.
-- Being in combat is the pair of them, and having a target on its own is what
-- makes another attack click pointless.
D.VARC_TARGET = 2059
-- Quick prayers: varclient 182 is above 0 while they are running (verified live by
-- the user), and API.DoAction_Button_QP() is the button that toggles them.
D.VARC_QUICKPRAY = 182
D.QP_RETRY_MS = 5000
D.QP_TRIES = 2

-- Current prayer points. API.GetPray_() is the number the prayer orb shows; a press
-- with none left only earns "You need to recharge your Prayer at an altar".
function D.prayerPoints()
	local ok, v = pcall(API.GetPray_)
	if ok and type(v) == 'number' then return v end
	return 0
end

function D.quickPrayOn()
	-- The engine's own reader is the authority - it is what the quick-prayer orb
	-- shows. cvar 182 is checked second: in a live run the button was pressed six
	-- times with 631/740 prayer points and the cvar still read 0, while the player
	-- snapshot said quickPrayEnabled=false, so the cvar alone cannot be trusted to
	-- stop the retries (each retry would toggle the prayers back off).
	local ok, v = pcall(API.GetQuickPray)
	if ok and (v == true or v == 1) then return true end
	local c = readVC(D.VARC_QUICKPRAY)
	return c ~= nil and c > 0
end

-- Turn quick prayers on for a boss fight. Never spams the button: while the cvar
-- still reads 0 the click is retried at most every D.QP_RETRY_MS, and a single log
-- line says what the cvar was when it was switched on.
function D.ensureQuickPray()
	-- Points first. Prayer points are what quick prayers need, and pressing the button
	-- with an empty bar does nothing except spam "You need to recharge your Prayer at
	-- an altar" into the chat (live: three presses at 0 points before the fight).
	local pts = D.prayerPoints()
	if pts <= 0 then
		if not D.qpNoPoints then
			D.qpNoPoints = true
			log(string.format('boss room: %s prayer points - quick prayers cannot be switched on',
				tostring(pts)))
		end
		return false
	end
	D.qpNoPoints = nil
	if D.quickPrayOn() then
		D.qpLogged = nil
		D.qpTries = 0
		return true
	end
	-- Two presses per floor at most: the button toggles, so retrying blind when the
	-- state cannot be read just switches the prayers on and off.
	if (D.qpTries or 0) >= D.QP_TRIES then return false end
	local now = API.SystemTime()
	if now - (D.qpAt or 0) < D.QP_RETRY_MS then return false end
	D.qpAt = now
	D.qpTries = (D.qpTries or 0) + 1
	say('quick prayers on')
	if not D.qpLogged then
		D.qpLogged = true
		log(string.format('boss room: quick prayers off (quickPray=%s cvar %d = %s) - pressing the quick-prayer button',
			tostring(API.GetQuickPray and (pcall(API.GetQuickPray))),
			D.VARC_QUICKPRAY, tostring(readVC(D.VARC_QUICKPRAY))))
	end
	-- pcall: this is called from inside the boss fight, so a missing/renamed engine
	-- hook must not take the whole loop down with it.
	local ok, res = pcall(API.DoAction_Button_QP)
	if not ok then
		D.qpFailed = true
		log(string.format('quick-prayer button failed: %s', tostring(res)))
		return false
	end
	return res
end

-- PROTECT FROM RANGED, LOOKED UP LIKE "EAT FOOD". The prayer can be dragged onto the action
-- bar, so turning it on is the same click the eating code already sends - it lands with the
-- inventory closed and a fight already running, which a prayer-book click does not.
D.protectAbility, D.protectAbilityAt, D.protectAbilityName = nil, 0, nil
function D.prayerAbilityGet(name)
	local want = name or 'Protect from Ranged'
	if D.protectAbility and D.protectAbilityName == want
		and (API.SystemTime() - (D.protectAbilityAt or 0)) < 120000 then
		-- the record is cached, its state is not: a bar swap leaves the old record behind
		-- with enabled = false, and a press with it clicks nothing
		if D.protectAbility.enabled then return D.protectAbility end
		D.protectAbility = nil
	end
	local ok, ab = pcall(function() return API.GetABs_name1(want) end)
	if ok and ab and ab.enabled then
		D.protectAbility, D.protectAbilityName, D.protectAbilityAt = ab, want, API.SystemTime()
		return ab
	end
	D.protectAbility, D.protectAbilityAt = nil, API.SystemTime()
	return nil
end

-- THE PROTECTION PRAYERS REPORT WHETHER THEY ARE ON. 16746 reads 1 while "Protect from
-- Ranged" is active and 0 while it is not, and the magic and melee ones are the pair either
-- side of it (16745 / 16747) - all three checked by the user in the client. So nothing here
-- has to guess, count presses or worry about the ability being a toggle: read the flag, press
-- only when it is 0, and after the press wait HALF A TICK - the flag is written on the game
-- tick, so reading it immediately after the click only ever reports "still 0".
--
-- WHICH VARBIT, per prayer. Only a prayer whose flag has been checked in the client is in
-- here. A prayer that is missing cannot be read back at all, and that is its own case in
-- D.ensurePrayerAbility: it is pressed ONCE per room and then taken on trust, because the
-- ability is a toggle and a blind second press switches it back off.
D.PRAYER_VARBIT = {
	['Protect from Ranged'] = 16746,
	['Protect from Magic']  = 16745,
	['Protect from Melee']  = 16747,
}
D.PRAY_HALF_TICK_MS = 300
-- TWO SPEEDS. Until the flag has answered 1 once, a press that did not take is retried
-- quickly - the click can land while the bar is still swapping, and sitting out 20 s is
-- exactly the "the prayer came on late" the boss does not forgive. Once it has been on,
-- a press is only worth sending again after the flag has read 0 for a while.
D.PROTECT_RETRY_MS = 1200
D.PROTECT_REPRESS_MS = 20000
D.PROTECT_TRIES = 5

-- true = the flag says on, false = it says off (or the read failed, so try again),
-- nil = this prayer has no varbit at all and there is nothing to read back.
function D.prayerOn(name)
	local vp = D.PRAYER_VARBIT[name or 'Protect from Ranged']
	if not vp then return nil end
	local ok, v = pcall(API.VP_FindPSettBit, vp)
	if ok and tonumber(v) then return tonumber(v) > 0 end
	return false
end

-- Turn one prayer ability on, if it is not already on. Prayer points first, exactly like the
-- quick prayer: a press with an empty bar only earns "You need to recharge your Prayer at an
-- altar" and the prayer still does not exist afterwards.
function D.ensurePrayerAbility(name, roomKey)
	name = name or 'Protect from Ranged'
	local pts = D.prayerPoints()
	if pts <= 0 then
		if not D.protectNoPoints then
			D.protectNoPoints = true
			log(string.format('boss room: %s prayer points - "%s" cannot be turned on',
				tostring(pts), tostring(name)))
		end
		return false
	end
	D.protectNoPoints = nil
	local on = D.prayerOn(name)
	-- NO VARBIT: the press was already sent for this room, and there is no way to read the
	-- state back - a second press on a toggle is the prayer switched off again, so stop.
	if on == nil and D.prayerPressed and D.prayerPressed[name] == roomKey then
		D.protectOn, D.bossPrayerName = true, name
		return true
	end
	if on == true then
		D.protectToldOn = nil
		D.protectOn, D.protectTries, D.bossPrayerName = true, 0, name
		return true
	end
	-- the flag says off; do not hammer the bar while the press is still landing
	local wait = D.protectOn and D.PROTECT_REPRESS_MS or D.PROTECT_RETRY_MS
	if D.protectAt and (API.SystemTime() - D.protectAt) < wait then return false end
	if not D.protectOn and (D.protectTries or 0) >= D.PROTECT_TRIES then return false end
	local ab = D.prayerAbilityGet(name)
	if not ab then
		if not D.protectNoAbility then
			D.protectNoAbility = true
			log(string.format('boss room: "%s" is not on the action bar - the boss hits at full strength',
				tostring(name)))
		end
		return false
	end
	local ok, done = pcall(function()
		return API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
	end)
	if not (ok and done == true) then return false end
	D.protectAt = API.SystemTime()
	-- half a tick: the flag is written on the tick, not on the click
	API.RandomSleep2(D.PRAY_HALF_TICK_MS, 100, 100)
	local now = D.prayerOn(name)
	if now == nil then
		-- no flag for this prayer: the press is taken on trust, once for this room
		D.prayerPressed = D.prayerPressed or {}
		D.prayerPressed[name] = roomKey or true
		D.protectOn, D.protectTries, D.bossPrayerName = true, 0, name
		if D.prayerTrusted ~= name then
			D.prayerTrusted = name
			log(string.format('boss room: "%s" pressed with %s prayer points - nothing to read it back with, so it is taken on trust until the floor changes',
				tostring(name), tostring(pts)))
		end
		say(string.format('%s on', tostring(name)))
		return true
	end
	if now then
		D.protectOn, D.protectTries, D.bossPrayerName = true, 0, name
		if not D.protectToldOn then
			D.protectToldOn = true
			log(string.format('boss room: "%s" switched on (%s prayer points, varbit %d -> 1)',
				tostring(name), tostring(pts), D.PRAYER_VARBIT[name]))
		end
		say(string.format('%s on', tostring(name)))
	else
		-- the press did not take: keep the retry window short instead of waiting out the
		-- re-press delay that belongs to a prayer that was already up
		D.protectTries = (D.protectTries or 0) + 1
		log(string.format('boss room: "%s" pressed with %s prayer points, varbit %d still 0 - retry %d/%d in %d ms',
			tostring(name), tostring(pts), D.PRAYER_VARBIT[name],
			D.protectTries, D.PROTECT_TRIES, D.PROTECT_RETRY_MS))
	end
	return now
end

-- Which prayer each boss needs. Only the fights worth a prayer are listed.
D.BOSS_PRAYER = {
	sagittare = 'Protect from Ranged',
	-- the night-gazer hits with magic: MegaDungeon's NightGazer.java turns on
	-- PROTECT_FROM_MAGIC (or DEFLECT_MAGIC on an ancient book) before the first swing
	['night-gazer khighorahk'] = 'Protect from Magic',
	-- Skeletal Horde: the wave spells are magic, so PROTECT_FROM_MAGIC goes up before the
	-- arena and stays up for the fight. The room is keyed on the Divine skinweaver, so both
	-- names the fight can be spotted under carry the same prayer (bosses.lua: D.HORDE_PRAYER).
	['divine skinweaver'] = 'Protect from Magic',
	['skeletal horde'] = 'Protect from Magic',
	-- Shadow-Forger Ihlakhizan: the orange beam is unclassified damage and Protect from
	-- Magic does nothing to it, so a melee-range fight uses PROTECT FROM MELEE (the wiki's
	-- own recommendation). The flash itself ignores prayer - only the pillar stops it.
	['shadow-forger ihlakhizan'] = 'Protect from Melee',
}

-- WHERE THE PRAYER MAY GO ON: INSIDE THE ROOM, NOT ON THE WAY TO IT. The press used to
-- land as soon as a boss npc was inside 14 tiles, which meant the prayer (and its retry
-- loop) started while the player was still in the doorway or the room before - live: it
-- activated without ever going into the boss room. The gate is the player's distance to
-- their own room's CENTRE (the lattice line at +8.0). EVERY ROOM IS THE SAME CELL - 16
-- tiles across, 14 of floor - so this is one rule for all of them, not a per-boss one. The
-- distances, counted from the centre: floor 1..7, the far wall line 7, the near wall line
-- 8, the next room's floor from 9. So < 8 is the whole floor of THIS room in every room,
-- and it also takes the far wall line: a doorway is at 7 or at 8 depending on which side of
-- the room it is on, which is why this is only half a doorway test. It does not need to be
-- one - what it must rule out is pressing from the room before, and 9 > 8 does that.
D.BOSS_PRAYER_ROOM_R = 8

-- Called once per pass, before the fight branch, and again from inside the walk waits
-- (D.bossPrayerPoll) - `list` lets the poll hand in its own cheap npc sweep.
function D.bossPrayerStep(px, py, list)
	if not D.roomCellAt then return false end
	-- already up: one varbit read and out, before any npc scan. This runs from inside the
	-- walk waits, so the quiet case has to be free.
	local _, _, pi, pj = D.roomCellAt(px, py)
	local roomKey = pi .. ':' .. pj
	if D.protectOn then
		local on = D.prayerOn(D.bossPrayerName)
		-- a prayer with no varbit is "dealt with" once it has been pressed for this room
		-- (D.prayerPressed): there is nothing to read, and re-pressing a toggle is the
		-- prayer switched off again
		if on == true then return true end
		if on == nil and D.prayerPressed and D.prayerPressed[D.bossPrayerName or ''] == roomKey then
			return true
		end
	end
	-- IN THE ROOM, NOT AT THE DOOR (see D.BOSS_PRAYER_ROOM_R)
	local cx = math.floor(px / 64) * 64 + pi * D.ROOM_CELL + D.ROOM_CENTRE
	local cy = math.floor(py / 64) * 64 + pj * D.ROOM_CELL + D.ROOM_CENTRE
	if math.max(math.abs(px - cx), math.abs(py - cy)) >= D.BOSS_PRAYER_ROOM_R then return false end
	local best, bestD = nil, math.huge
	for _, n in ipairs(list or D.npcScan() or {}) do
		local key = D.bossKey and D.bossKey(n.Name) or string.lower(tostring(n.Name or ''))
		local prayer = D.BOSS_PRAYER[key]
		if prayer and (tonumber(D.objGet(n, 'Life')) or 0) > 0 then
			local bx, by = D.objTile(n)
			if bx then
				bx, by = math.floor(bx), math.floor(by)
				-- Chebyshev, the "tiles away" the game itself counts
				local d = math.max(math.abs(bx - px), math.abs(by - py))
				-- OUR OWN ROOM ONLY: a boss in the next cell is a boss we have not walked in
				-- on yet, and the prayer is not paid for until we have
				local _, _, bi, bj = D.roomCellAt(bx, by)
				if bi == pi and bj == pj then
					D.bossPrayerSeen = key
					if d < bestD then best, bestD = prayer, d end
				end
			end
		end
	end
	if not best and D.bossPrayerSeen then
		-- the npc is missing from this scan (a door animation, a wall between us and it):
		-- standing in its room is reason enough to keep the prayer it needs up
		local bossRoom = D.bossRoomKey and D.bossRoomKey(px, py)
		if bossRoom and bossRoom == (pi .. ':' .. pj) then
			best = D.BOSS_PRAYER[D.bossPrayerSeen]
		end
	end
	if not best then return false end
	return D.ensurePrayerAbility(best, roomKey)
end

-- IS A BOSS PRAYER WORTH LOOKING FOR RIGHT NOW? The poll below runs on every step of
-- every walk, and an npc scan is not free, so the search is only armed where the boss can
-- be: the boss room, a room beside it, or anywhere once the boss has been seen on this
-- floor.
function D.bossPrayerArmed(px, py)
	if D.bossPrayerSeen then return true end
	local bossRoom = D.bossRoomKey and D.bossRoomKey(px, py)
	if not bossRoom then return false end
	if D.routeGoal == bossRoom then return true end
	local si, sj = string.match(bossRoom, '^(%-?%d+):(%-?%d+)$')
	if not si then return false end
	local _, _, pi, pj = D.roomCellAt(px, py)
	return math.max(math.abs(tonumber(si) - pi), math.abs(tonumber(sj) - pj)) <= 1
end

-- CALLED FROM INSIDE THE WALK WAITS, which is where the five seconds went: the pass that
-- clicks the boss-room doorway is blind for as long as the walk takes (D.waitMove up to
-- 6 s, then D.waitWalkDone up to 4 s), and that is exactly when the boss streams in and
-- starts shooting. Pressing from the next pass is already late, so press from here.
-- The no-reach scan is the cheap one and the whole point: this decision only needs the
-- boss's NAME, and a boss behind a still-closing door is still a boss.
D.PRAYER_POLL_MS = 350
D.prayerPollAt = 0
function D.bossPrayerPoll()
	if D.stopped() then return false end
	local now = API.SystemTime()
	if (now - (D.prayerPollAt or 0)) < D.PRAYER_POLL_MS then return false end
	D.prayerPollAt = now
	-- already up: one varbit read, no scan. Steady state has to be free.
	if D.protectOn then
		if D.prayerOn(D.bossPrayerName) == true then return true end
		-- a prayer with no varbit cannot be polled at all: once it has been pressed it stays
		-- "on" for the floor, and polling it again would only re-press a toggle
		if D.PRAYER_VARBIT[D.bossPrayerName or ''] == nil and D.bossPrayerName then return true end
	end
	local px, py = ptile()
	if not D.bossPrayerArmed(px, py) then return false end
	local ok, list = pcall(function()
		return D.keepScan(API.ReadAllObjectsArray({ 1 }, {}, {}, D.NO_REACH))
	end)
	return D.bossPrayerStep(px, py, ok and list or {})
end

-- THE FLOOR IS OVER WHEN THE END LADDER APPEARS. A "Ladder" whose action reads
-- "End dungeon" is created the moment the boss dies (confirmed live in the client), so
-- its presence IS the boss-down verdict - nothing here has to watch health, the chat or
-- the boss npc. It outranks every other task on the floor: after the boss there is
-- nothing left that matters.
--
-- Matched by ACTION only - not by name and not by Bool1. The action string is what the
-- client itself puts in the menu, so a ladder it will not let us use reports '' and is
-- skipped for free, while a Bool1 test would only add a way to miss a good ladder. The
-- old name-matching finder also caught ordinary scenery with "ladder" in the name, and
-- the one click that ends the floor must not land on the wrong object.
D.LADDER_ACTION = 'End dungeon'

-- Returns true when the ladder was taken (the caller then yields the pass).
-- NOTE: the old pathing.lua `takeLadder` is NOT reachable from here - that module is not
-- required by this file at all, so `takeLadder` is a nil local and calling it took the
-- whole script down with "attempt to call a nil value (upvalue 'takeLadder')". The click
-- lives in D.takeEndLadder below, built on the click helper this file actually has.
function D.endLadderStep(px, py)
	if D.floorLeaving then return false end
	-- one attempt per window: a ladder that did not move us is retried (three strikes
	-- write it off), but a ladder that is already being walked to is not clicked again
	if D.ladderAt and (API.SystemTime() - D.ladderAt) < D.LADDER_RETRY_MS then return false end
	local best, bestD = nil, math.huge
	local want = string.lower(D.LADDER_ACTION)
	for _, o in ipairs(D.objScan() or {}) do
		local act = D.objGet(o, 'Action')
		act = type(act) == 'string' and string.lower(act) or ''
		if tonumber(D.objGet(o, 'Type')) ~= 3 and act == want then
			local lx, ly = D.objTile(o)
			if lx then
				lx, ly = math.floor(lx), math.floor(ly)
				local k = lx .. ',' .. ly
				if not (S.ladderBad and S.ladderBad[k]) then
					local d = math.max(math.abs(lx - px), math.abs(ly - py))
					if d < bestD then best, bestD = o, d end
				end
			end
		end
	end
	if not best then return false end
	local lx, ly = D.objTile(best)
	lx, ly = math.floor(lx), math.floor(ly)
	if not D.bossDown then
		D.bossDown, D.bossDownAt = true, API.SystemTime()
		log(string.format('boss down: "End dungeon" ladder %s at %d,%d (%d tiles away) - the floor is finished',
			tostring(D.objGet(best, 'Id')), lx, ly, bestD))
	end
	D.setStateNow('floor finished - taking the end ladder')
	D.ladderAt = API.SystemTime()
	return D.takeEndLadder(best) == true
end

-- TAKING IT. Clicking the ladder ends the floor: the client answers with the score screen
-- and a countdown, then the next floor streams in at a different map base. So the pass that
-- clicked waits for the move - carrying on and planning against a floor that is already
-- over is exactly the "announced ALL MAP DOORS DONE on the floor it had just left" bug.
--
-- Two waits, because they answer different questions:
--   LADDER_MOVE_MS   did the click do anything at all? (no movement = failed click)
--   LADDER_FLOOR_MS  has the next floor arrived? (map base changed, or a real teleport)
D.LADDER_MOVE_MS = 4000
D.LADDER_FLOOR_MS = 45000
D.LADDER_RETRY_MS = 6000
function D.takeEndLadder(o)
	local x, y = D.objTile(o)
	if not (x and y) then return false end
	x, y = math.floor(x), math.floor(y)
	local key = x .. ',' .. y
	local act = D.objGet(o, 'Action')
	if type(act) ~= 'string' or act == '' then act = D.LADDER_ACTION end
	local px, py = ptile()
	local base = math.floor(px / 64) .. ':' .. math.floor(py / 64)
	say('taking the end ladder')
	log(string.format('end ladder %s at %d,%d - clicking "%s" (dist %d)',
		tostring(D.objGet(o, 'Id')), x, y, act, math.max(math.abs(x - px), math.abs(y - py))))
	-- the canonical text, so D.CODE resolves to the "End dungeon" opcode (0x29) whatever
	-- casing the client reports
	if not D.clickObject(D.LADDER_ACTION, o) then
		log(string.format('end ladder at %d,%d: click not dispatched (click budget or stale record)', x, y))
		return false
	end
	local t0 = API.SystemTime()
	local moved = false
	while not D.stopped() and (API.SystemTime() - t0) < D.LADDER_MOVE_MS do
		local nx, ny = ptile()
		if nx ~= px or ny ~= py or isMoving() then moved = true break end
		API.RandomSleep2(200, 80, 120)
	end
	if not moved then
		D.ladderFails = D.ladderFails or {}
		D.ladderFails[key] = (D.ladderFails[key] or 0) + 1
		if D.ladderFails[key] >= 3 then
			S.ladderBad[key] = true
			log(string.format('end ladder at %d,%d has not moved us after %d clicks - writing it off',
				x, y, D.ladderFails[key]))
		else
			log(string.format('end ladder at %d,%d did not move us (%d/3) - trying again in %d ms',
				x, y, D.ladderFails[key], D.LADDER_RETRY_MS))
		end
		return false
	end
	-- the floor is over: wait for the next one. The map base is the signal that cannot
	-- flap - the tile alone can cross a 64-boundary on the walk to the ladder itself.
	D.floorLeaving = true
	local t1 = API.SystemTime()
	local left, why = false, 'not seen'
	while not D.stopped() and (API.SystemTime() - t1) < D.LADDER_FLOOR_MS do
		local nx, ny = ptile()
		local nbase = math.floor(nx / 64) .. ':' .. math.floor(ny / 64)
		if nbase ~= base then left, why = true, 'map base moved to ' .. nbase break end
		if math.abs(nx - px) > 40 or math.abs(ny - py) > 40 then
			left, why = true, string.format('moved to %d,%d', nx, ny)
			break
		end
		API.RandomSleep2(700, 250, 400)
	end
	D.floorLeaving = nil
	log(string.format('floor finished: end ladder taken, next floor %s after %dms',
		why, API.SystemTime() - t1))
	return true
end

local function engineInCombat()
	local v = API.LocalPlayer_IsInCombat_()
	return v == true or v == 1
end

local function hasTarget()
	local v = readVC(D.VARC_TARGET)
	return v ~= nil and v > 0
end

local function inCombat()
	return engineInCombat() and hasTarget()
end

-- Clicks sent while the player is still walking get dropped, so wait until the
-- character has actually stopped before dispatching the next action.
local function settle(rounds)
	for i = 1, rounds or 12 do
		if not isMoving() then return true end
		API.RandomSleep2(250, 100, 150)
	end
	return not isMoving()
end

-- Every click on a door / object / npc asks this first. A click sent while the player
-- is still walking is dropped by the client and retargets the walk it already had in
-- hand, which is how a door click "did nothing" and then got written off two passes
-- later. Waits for the walk to finish; false means it did not finish in time, so the
-- caller must not click on this pass.
-- A key turn on this doorway (or on the leaf one tile away) was sent less than
-- D.CLICK_GAP_UNLOCK ago: an Enter click now is refused by the click gate, so the pass
-- should wait the turn out instead of burning one of its tries.
function D.unlockInFlight(d)
	if not d or not d.x or not d.y then return false end
	local now = API.SystemTime()
	for dy = -1, 1 do
		for dx = -1, 1 do
			local t = D.lastClickAt[(math.floor(d.x) + dx) .. ',' .. (math.floor(d.y) + dy) .. '/Unlock']
			if t and (now - t) < D.CLICK_GAP_UNLOCK then return true end
		end
	end
	return false
end

-- MAY WE CLICK RIGHT NOW? Not "isMoving() is false" - that flaps between two steps of the
-- same walk (ReadPlayerMovin2 is only true inside a movement tick), and the old version
-- therefore answered "yes" in the gaps: a doorway click then went out while the player was
-- still crossing and RETARGETED the walk, which is the reported "it started to go through,
-- then jumped back" (08:21:27 Door, 08:21:31 Guardian door - one crossing, two clicks).
-- D.stillNow() uses the tile, which cannot flap: it must have held still for a step window.
function D.stillNow()
	if isMoving() then return false end
	if D.walkLive and D.walkLive() then return false end
	return true
end

function D.canClickNow(maxMs)
	if D.stillNow() then return true end
	local t0 = API.SystemTime()
	local limit = t0 + (maxMs or 2500)
	while API.SystemTime() < limit do
		API.RandomSleep2(120, 40, 80)
		if D.stillNow() then return true end
	end
	return false
end

-- The door-click hold asks this on every check, so it must not sleep the way
-- D.canClickNow does: a guard that waits is not a guard.
function D.isMovingNow()
	return isMoving()
end

-- ReadPlayerMovin2() is only true inside a movement tick, so a walk reads "not moving"
-- between its steps - D.settle/D.canClickNow can return "stopped" in the middle of one,
-- and that is how a second door click went out while the player was still walking.
-- The player's TILE is the signal that cannot flap: it changed within D.STEP_MS means the
-- walk is still live.
D.STEP_MS = 900

function D.walkLive()
	local px, py = ptile()
	local k = (px or 0) .. ',' .. (py or 0)
	local now = API.SystemTime()
	if D.tileKey == nil then
		D.tileKey, D.tileAt = k, now
		return false
	end
	if D.tileKey ~= k then
		D.tileKey, D.tileAt = k, now
		return true
	end
	return (now - (D.tileAt or 0)) < D.STEP_MS
end

-- Same idea for tile clicks. A walk that keeps being re-issued because the player
-- never actually arrives (pads, puzzle tiles, a plan the client refuses) is the
-- other way to spam: every tile click is capped too.
D.WALK_LIMIT = 3
-- The walkable area of a room is 13x13; counting the inner walls it is 14x14, so the
-- furthest a doorway tile can be from a player tile of the SAME room is 13. 14 is used
-- as the hard limit: anything past it is a bad pick from the merged room graph and is
-- skipped rather than walked to (clicking a doorway walks the player there by itself).
D.CLICK_RANGE = 14

-- How long to watch for a doorway crossing to START. A crossing is one or two tiles and
-- the client begins it on the next tick (~600 ms), but the player COORDINATE lags the visible
-- walk by up to about a second: a one-tile hop between the two leaves of a doorway completes
-- on screen while PlayerCoord still answers the old tile. At 1500 ms that lag was read as "the
-- click did nothing": the walker forgot the click, walked to the doorway floor and clicked the
-- other leaf, so the player visibly hopped leaf-to-leaf while the console kept reporting the
-- same tile. 2600 ms covers a tick plus the coordinate update with room to spare.
D.DOOR_WALK_WAIT = 2600
-- ... and if the player still looks in motion when that window closes, keep watching this
-- much longer before calling the click a failure (bounded, so a stuck walk cannot hang the pass).
D.DOOR_MOVE_GRACE = 2500

-- How long one doorway crossing may take from the click to the player standing still
-- again. The walk is one or two tiles, so this is generous on purpose: the pass holds
-- here instead of deciding anything from mid-walk (see D.walkPath).
D.DOOR_CROSS_WAIT = 3500
-- A doorway clicked this long ago is not clicked again. One click starts the walk
-- through it; a second one while the player is on the move only retargets the walk the
-- client already has in hand ("it clicks the doorway and the previous/forward door side
-- in the same second").
D.DOOR_CLICK_HOLD = 1500
-- And it stays held for as long as that click has the player walking, up to this cap:
-- a doorway clicked from across the room starts a walk that takes several seconds, and
-- the crossing happens at the END of it. Live, the second click went out 4.4 s after the
-- first while the player was already through the doorway, and the client answered it
-- with "You can't reach that." A doorway 14 tiles away needs ~9 s of walking.
D.DOOR_WALK_HOLD = 12000

-- How long to wait for the next floor to be announced after the end ladder. The
-- dungeon needs ~30 s ("Time until next dungeon: 30 � 1"), so this covers the whole
-- countdown with slack; the wait exits early when the announcement arrives.
D.FLOOR_WAIT_MS = 60000
D.walkCount = {}

-- Has the run been stopped? The loop flag is what the End key and
-- API.Write_LoopyLoop set, and it can go false in the MIDDLE of an iteration: a solver
-- that decides the floor is over calls Write_LoopyLoop(false) and the rest of that same
-- pass keeps running, and a sleep already in progress finishes after the stop too. Any
-- walk or click dispatched after that is the "it keeps trying to walk even though the
-- script has stopped" case. The engine answers 0/1 on some builds and false/true on
-- others, so both spellings count as stopped.
function D.stopped()
	local v = API.Read_LoopyLoop()
	return v == false or v == nil or v == 0
end



D.CODE = {
	['Enter'] = 0x39, ['Open'] = 0x39, ['Unlock'] = 0xc3,
	['Chop-down'] = 0x3b, ['Burn'] = 0x41, ['End dungeon'] = 0x29,
	-- Invention skill door: "Augmented door" offers only Disassemble (live id 137186).
	['Disassemble'] = 0x3b, ['Repair'] = 0x39, ['Fix-pulley'] = 0x39,
	-- Broken key door: its only option is "Repair-key", same slot as Repair.
	['Repair-key'] = 0x39,
	['Force-bar'] = 0x39, ['Imbue-energy'] = 0x39, ['Pick-lock'] = 0x39,
	-- Vine-covered door: the live option is "Prune-vines" and it is the only one, so the
	-- same slot as Enter/Open. 'Prune' is kept for the name the wiki uses.
	['Prune-vines'] = 0x39, ['Prune'] = 0x39,
	-- Fremennik camp crates: each crate offers exactly one option, so the same slot again.
	['Smith-battleaxes'] = 0x39, ['Cook-fish'] = 0x39, ['Fletch-bows'] = 0x39,
	-- Coloured recess: the shelves' only option, same slot.
	['Mix liquid'] = 0x39, ['Mix Liquid'] = 0x39,
	-- Stomp's lodestone: its only option is "Charge" (live: "Blue lodestone",
	-- 49278/49279). Same slot again - it is a single-option prop.
	['Charge'] = 0x39,
	['Chop'] = 0x3b, ['Chop down'] = 0x3b,
	['Take'] = 0x2d, ['Attack'] = 0x2a, ['Talk-to'] = 0x29,
	-- Levers ("Switch"): the only option, so the same slot as Enter/Open. Without an
	-- entry here it fell back to ACT_DEFAULT anyway, but saying it keeps the opcode
	-- out of "it happens to be the same number" territory.
	['Pull'] = 0x39,
	-- Barrel puzzle: "Push" is the barrel's only option, same slot again; the broken
	-- barrel's only option is "Fix".
	['Push'] = 0x39, ['Fix'] = 0x39,
	-- Toxin maze: the barrier is 'Go-through' and the pedestal 'Mine'. Both are the
	-- object's only option, so they take the same slot as Enter/Open.
	['Go-through'] = 0x39, ['Mine'] = 0x39,
	-- Collapsing room: "Rocky debris" offers only Destroy (live ids 49615-49618).
	['Destroy'] = 0x39,
	-- Unhappy ghost: the jewellery box is filled, the remains blessed. Both are the
	-- prop's only option, same slot again.
	['Fill'] = 0x39, ['Bless-remain'] = 0x39,
	-- Skeletal Horde tunnel: the only option on it is Block.
	['Block'] = 0x39,
	-- Sleeping guards: "Pickpocket" is the guard's first option while it sleeps,
	-- the same slot as Push / Pull.
	['Pickpocket'] = 0x39, ['Steal'] = 0x39,
	-- Night-gazer arena: the corner "Pillar of light" offers only Light while it is out,
	-- and nothing once it is lit (live id 49265). Same slot again.
	['Light'] = 0x39,
	-- Grapple bridge: every step is the prop's ONLY option - the stash (Plunder /
	-- Take-from), the wheel (Spin), the hook crate (Retrieve / Take-from), the anvil
	-- (Smith), the winch (Operate), the chasm (Grapple) and the tightrope the grapple
	-- spawns (Walk-the, or Cross-the on the older model). The held Meatcorn / broken
	-- hook is used by the client automatically, so no item ever goes on the cursor
	-- except the rope-and-head combination. Same slot as Enter/Open.
	['Plunder'] = 0x39, ['Take-from'] = 0x39, ['Retrieve'] = 0x39,
	['Spin'] = 0x39, ['Smith'] = 0x39, ['Operate'] = 0x39, ['Grapple'] = 0x39,
	['Walk-the'] = 0x39, ['Cross-the'] = 0x39,
}

local readKeyVar = readVC

-- Daemonheim keys are never inventory items - they live in the ring, one varclient
-- per colour/shape, and the key is consumed by unlocking. So the cvars are the
-- only source; an inventory lookup only ever produced false "we have it" answers.
-- The ring changes only when a key is picked up or spent, so a read every pass is plenty:
-- D.KEY_SET is 64 ids and this is asked from two places per pass (the door dots and the
-- key pickups). Re-reading 64 settings nodes twice a pass was a cost for an answer that
-- cannot change between two passes.
D.KEYRING_TTL = 1500
local function heldKeys()
	local now = API.SystemTime()
	if D.keyRing and (now - (D.keyRingAt or 0)) < D.KEYRING_TTL then
		return D.keyRing.held, D.keyRing.unknown
	end
	local held, unknown = {}, false
	for item, cvar in pairs(D.keyCvar) do
		local v = readKeyVar(cvar)
		if v == nil then
			unknown = true
		elseif v > 0 then
			held[item] = true
		end
	end
	D.keyRing, D.keyRingAt = { held = held, unknown = unknown }, now
	return held, unknown
end

local function keyHeld(item, held, unknown)
	if held[item] then return true end
	if unknown then
		local v = readKeyVar(D.keyCvar[item])
		if v ~= nil and v > 0 then return true end
	end
	return false
end

-- KEYS ON THE FLOOR - the list the "Pick up keys" step in the main loop loots, rebuilt
-- every pass, and the rooms it makes the route walk to (D.keyRooms).
--
-- READ FROM THE PASS'S OWN PROP SWEEP (D.objScan, types {0,3,12,99}). A dedicated
-- `ReadAllObjectsArray({3}, D.KEY_IDS, {}, ...)` scan was tried first and returned ZERO
-- records in the client even with a key one tile away - the live diagnostic said
-- "0 ground key(s) scanned" while the key was standing there - so the type-3 id scan
-- cannot be trusted to see ground items at all. The pass sweep already has them (that is
-- why findLadder skips `o.Type ~= 3`), it is already pinned, and reading it costs one walk
-- over a list that exists instead of a second scan.
--
-- Then two filters of our own:
--   ring   a key already on the ring is worth nothing: D.KEY_SET is 64 ids and the same
--          colour/shape spawns twice on a floor. The cvars are read ONCE per pass, not
--          once per key (heldKeys), because each read is a settings lookup.
-- The sleeping guards' "Guard room key" is not on the ring - it is an ordinary inventory
-- item (D.GUARD_KEY) - so it gets its own test, and only when the pack does not have one.
-- Nearest first.
function D.floorKeys(px, py)
	local out = {}
	if not (px and py) then return out end
	local held, unknown = heldKeys()
	local guard = nil
	for _, o in ipairs(D.objScan() or {}) do
		if tonumber(D.objGet(o, 'Type')) == 3 then
			local id = tonumber(D.objGet(o, 'Id'))
			if id and (id == D.GUARD_KEY or D.KEY_SET[id]) then
				local x, y = D.objTile(o)
				if x then
					x, y = math.floor(x), math.floor(y)
					local want = false
					if id == D.GUARD_KEY then
						if guard == nil then guard = D.guardHoldsKey() end
						want = not guard
					else
						want = not keyHeld(id, held, unknown)
					end
					if want then
						local t = D.objGet(o, 'Tile_XYZ')
						out[#out + 1] = { o = o, x = x, y = y, id = id,
							d = math.max(math.abs(x - px), math.abs(y - py)),
							z = math.floor(tonumber(D.objGet(t, 'z')) or 0) }
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

--------------------------------------------------------------------
-- actions
--------------------------------------------------------------------

-- Objects are dispatched by ID with a tile hint, never by the cached AllObject:
-- the Direct variant sends the object's unique id, the engine answers
-- "object id?:50368 might be wrong" and DROPS the click - which is how a closed
-- door could be clicked for ever without ever opening. Same lesson as the NPC
-- attack click. Table field, not a local: every local is spent from this file's
-- 200-local budget, and D.* entries cost nothing.
-- Hard cap on clicks per object tile. "You can't reach that" repeated a hundred
-- times is a ban risk, so no doorway is ever clicked more than this many times per
-- floor, whatever the caller thinks.
D.CLICK_LIMIT = 4
-- How long a doorway stays written off. Long enough not to re-walk a dead end every pass,
-- short enough that a floor whose only remaining work is behind a written-off doorway gets
-- found in the same run (see the expiry in the main loop).
D.BAD_DOOR_TTL = 45000
-- A pass that blocks this long is a symptom, not normal work: warn with the state line so
-- a stall names itself instead of showing up as a 50-second hole in the console.
D.PASS_WARN_MS = 8000
-- How many passes in a row with no clickable and no routable doorway before the floor is
-- treated as explored and the boss room is allowed. Three is enough to ride out a scan that
-- landed mid-door-click; a real dead end is obvious by then, and waiting longer is the
-- "runs around with nothing left to do" tour.
D.NO_REACH_PASSES = 3
D.CLICK_LIMIT_TILE = 12 -- per tile, across all of its options (see D.clickGate)
D.JUMP_CLICK_LIMIT = 600
-- Skill doors and unlocks are INTERACTED WITH REPEATEDLY on purpose: a wooden barricade
-- takes a few chops and the sweep keeps working one until D.SKILL_TRIES. Their budget is
-- therefore the try budget, not the ordinary four clicks.
D.SKILL_CLICK_LIMIT = 8
D.clickCount = {}

-- The client only answers on game ticks (~600 ms). Two clicks on the same object
-- inside one tick are two real clicks and one reaction: the second one is aimed at
-- an object that has not opened/moved yet, and that is exactly what a double click
-- looks like. Every object click passes through here, so the gap is enforced once,
-- centrally, for doors, walls and grooves alike.
D.CLICK_GAP = 900
-- A key turn is not a click-step: the player walks to the door first, then the key is
-- spent server side. Live measurement of one orange wedge unlock: click at 14.563,
-- walk arrived ~20.5, "You unlock the door" at 22.0 - and the script had already sent
-- the same Unlock again at 20.516, which is the second DoAction_Object line in the
-- client log for one door. Nothing may be re-sent to that tile until the turn lands.
D.CLICK_GAP_UNLOCK = 7000
-- Skill doors (Chop / Mine / Force-bar / Imbue-energy ...) take several successful
-- interactions before they give way, so they are worked, not written off after one.
D.SKILL_TRIES = 8
D.OPEN_RECLICK_MS = 5000   -- one Enter click per open doorway per crossing
D.RECROSS_MS = 12000       -- no straight back through a doorway just crossed
D.lastClickAt = {}
D.lastClickLog = {}



-- A door click starts a walk, and the walk can take several seconds. Judging the
-- click while the player is still moving is what counted a working door as a
-- failure, so wait for the player to stop before deciding.
local function waitStill(maxMs)
	local t0 = API.SystemTime()
	while isMoving() and (API.SystemTime() - t0) < (maxMs or 4000) do
		API.RandomSleep2(200, 50, 100)
	end
end

-- Wait for the walk a click started, properly: right after a click the player is
-- still standing still (the walk only begins on the next game tick), so "has not
-- moved" proves nothing yet. This waits for movement to APPEAR, then for it to
-- stop, and only then reports. Without the first half every check ran inside the
-- tick the client had not answered and every doorway looked dead - which is what
-- made the bot click the same open door over and over.
function D.waitMove(x0, y0, maxMs)
	local t0 = API.SystemTime()
	local limit = maxMs or 6000
	local started = isMoving()
	while (API.SystemTime() - t0) < limit do
		-- STOPPING HAS TO BE IMMEDIATE. Pressing End only takes effect when the loop
		-- reaches Read_LoopyLoop again, so a pass that is inside a six-second wait keeps
		-- clicking and walking afterwards - "it is still drawing paths and running" after
		-- the script was told to stop. Every poll checks the flag.
		if D.stopped() then return false end
		local x, y = ptile()
		if x ~= x0 or y ~= y0 or isMoving() then started = true end
		if started and not isMoving() then
			API.RandomSleep2(300, 100, 150)
			return true
		end
		if not started and (API.SystemTime() - t0) > 2000 then return false end
		-- a walk into the boss room is the one wait that must not swallow the prayer
		if D.bossPrayerPoll then D.bossPrayerPoll() end
		API.RandomSleep2(150, 60, 100)
	end
	return started
end

-- WAIT FOR THE WALK TO BE OVER: the tile must HOLD STILL for a whole step window, not merely
-- read "not moving" once. ReadPlayerMovin2() is only true inside a movement tick, so between
-- two steps of the same walk every sample says "stopped" - which is how a pass carried on
-- mid-crossing, re-planned and clicked the next doorway, retargeting the walk and pulling the
-- player back out of the door it had just started through (live 08:21:27 Door, 08:21:31
-- Guardian door, for one crossing). The tile is the signal that cannot flap.
function D.waitWalkDone(maxMs, graceMs)
	local t0 = API.SystemTime()
	local limit = t0 + (maxMs or D.DOOR_CROSS_WAIT or 3500)
	local hard = limit + (graceMs or D.DOOR_MOVE_GRACE or 2500)
	local lx, ly = ptile()
	local stillSince = nil
	while true do
		local now = API.SystemTime()
		local x, y = ptile()
		if x ~= lx or y ~= ly then
			lx, ly, stillSince = x, y, nil
		end
		local moving = isMoving() or (D.walkLive and D.walkLive()) or false
		if moving then
			stillSince = nil
		else
			stillSince = stillSince or now
			-- idle AND the tile has not changed for a step window: the walk is really over
			if (now - stillSince) >= (D.STEP_MS or 900) then return true end
		end
		if now >= hard then return false end
		if now >= limit and not moving then return true end
		if D.bossPrayerPoll then D.bossPrayerPoll() end
		API.RandomSleep2(120, 40, 80)
	end
end

-- DID THE PLAYER ACTUALLY LEAVE THIS TILE? One implementation, used by every doorway-- crossing, because the naive "poll ptile() for 1.5 s and give up" produced the visible
-- leaf-to-leaf hop: the walk between two door leaves is one tile, the client renders it
-- immediately but PlayerCoord keeps answering the OLD tile for up to a second, so the click
-- was judged a failure and the other leaf was clicked - which walked the player back.
-- Returns true only on a REAL tile change (a mere isMoving() must never count: that would
-- mark a doorway crossed that we never went through, the false-crossing bug).
-- While the player still looks in motion at the end of the normal window, it keeps watching
-- for up to D.DOOR_MOVE_GRACE more, so a slow client is waited out instead of retried.
function D.leftTile(x0, y0, maxMs)
	local t0 = API.SystemTime()
	local limit = t0 + (maxMs or D.DOOR_WALK_WAIT or 2600)
	local hard = limit + (D.DOOR_MOVE_GRACE or 2500)
	while true do
		local now = API.SystemTime()
		-- End must stop the pass at once: the dots keep being stamped and the door keeps
		-- being clicked otherwise, for up to the whole grace window.
		if D.stopped() then return false, x0, y0 end
		local x, y = ptile()
		if x ~= x0 or y ~= y0 then return true, x, y end
		if now >= hard then break end
		if now >= limit then
			-- normal window is over: only a player that still looks in motion earns the grace
			if not isMoving() and not (D.walkLive and D.walkLive()) then
				-- one last look after the client settles, then call it
				API.RandomSleep2(300, 100, 200)
				x, y = ptile()
				if x ~= x0 or y ~= y0 then return true, x, y end
				break
			end
		end
		API.RandomSleep2(130, 40, 90)
	end
	local x, y = ptile()
	return (x ~= x0 or y ~= y0), x, y
end

-- Is the player in the middle of an interaction animation? Unlocking a door,
-- forcing a barricade, chopping or mining all play a player animation, and the
-- server only spends the key / opens the door when that animation finishes. The
-- world cache still shows the old leaf the whole time, so a pass that decides "still
-- closed" while the player is animating clicks the same key door again - door 50238
-- was clicked three times in five seconds for one unlock.
function D.playerBusy()
	return (API.ReadPlayerAnim() or 0) > 0
end

-- Wait for the player's animation to finish. Returns true when the player is idle
-- (or never animated), false when the cap ran out while still animating.
function D.waitAnim(maxMs)
	local t0 = API.SystemTime()
	local limit = maxMs or 8000
	while (D.playerBusy() or API.ReadPlayerMovin2()) and (API.SystemTime() - t0) < limit do
		API.RandomSleep2(200, 60, 120)
	end
		API.RandomSleep2(400, 60, 120)
	return not D.playerBusy()
end

-- Wait for an animation to APPEAR (the click can take a tick to start it) and then
-- finish. Returns true if an animation was seen at all.
function D.waitAnimStart(maxMs)
	local t0 = API.SystemTime()
	local limit = maxMs or 10500
	local seen = false
	while (API.SystemTime() - t0) < limit do
		if D.playerBusy() then
			seen = true
			break
		end
		API.RandomSleep2(150, 50, 100)
	end
	if seen then D.waitAnim(4000) end
	return seen
end

--------------------------------------------------------------------
-- Daemonheim food: eaten when the hitpoints drop, picked up off the floor
--------------------------------------------------------------------
-- The ids come from the client's own item cache (ids 18120-18178), which is the same set
-- the wiki lists as Daemonheim food: the ten cooked fish, and the gissel / edicap filled
-- potatoes that heal far more. Burnt food (18179+) is deliberately absent - it heals
-- nothing. Each fish has two ids in the cache, so both are listed.
D.DH_FOOD = {
	[18159] = true,   -- Heim crab
	[18161] = true,   -- Red-eye
	[18163] = true,   -- Dusk eel
	[18165] = true,   -- Giant flatfish
	[18167] = true,   -- Short-finned eel
	[18169] = true,   -- Web snipper
	[18171] = true,   -- Bouldabass
	[18173] = true,   -- Salve eel
	[18175] = true,   -- Blue crab
	[18177] = true,   -- Cave moray
}
D.FOOD_MAX = 10            -- ten pieces carried is enough; the rest stays on the floor
-- HOW MANY SLOTS THE FOOD LOOT ALWAYS LEAVES FREE. Eating must never fill the pack: a
-- full pack cannot take a key, a puzzle piece or the ladder's leftovers, so the sweep
-- stops ten slots short whatever the food count says.
D.FOOD_RESERVE = 10
D.FOOD_EAT_AT = 60         -- eat below this percent of max life points
D.FOOD_EAT_MS = 1600       -- the eating animation / tick gap between two bites
D.FOOD_IDS = {}			   --load up the food table for the bot to use
for id in pairs(D.DH_FOOD) do
    D.FOOD_IDS[#D.FOOD_IDS + 1] = id
end

-- The one key that is not on the key ring. The sleeping guards' room drops a plain
-- "Guard room key" into the inventory, and its door carries no colour and no shape in
-- its name, so nothing about it can be read off the ring. Everything else is the ring.
D.GUARD_KEY = 17363
function D.guardHoldsKey()
	local ok, items = pcall(function() return Inventory:GetItems() end)
	if not ok or not items then return false end
	for _, it in ipairs(items) do
		local ok2, id2 = pcall(function() return it.id end)
		if ok2 and id2 == D.GUARD_KEY then return true end
	end
	return false
end

-- How much Daemonheim food is in the pack (both kinds together). One GetItems call, not
-- one lookup per id: there are nearly sixty ids.
function D.foodHeld()
	local ok, items = pcall(function() return Inventory:GetItems() end)
	if not ok or not items then return 0 end
	local n = 0
	for _, it in ipairs(items) do
		local ok2, id2, amt = pcall(function() return it.id, it.amount end)
		if ok2 and id2 and D.DH_FOOD[id2] then n = n + (tonumber(amt) or 1) end
	end
	return n
end

-- FOOD ON THIS ROOM'S FLOOR - LOCAL ONLY, on purpose. A key is worth a walk across the
-- floor (D.floorKeys); a crab is not, so food is never a route goal and this list only
-- ever holds what is inside the room we are standing in.
--
-- This is the list the "Get foods" branch reads, and that list was the reason the branch
-- had never run: its assignment is commented out at the top of the loop, so
-- `#NeededTOReach_GIFOODS > 0` was false for ever and the pack only ever held what the
-- floor started with.
--
-- The 1-tile reach test is the client's own path find, applied PER CANDIDATE after the
-- room filter - the scan itself is unfiltered (see D.floorKeys: `startpathreach` is a
-- path-length limit, and 0 means "on the tile we are standing on", which is how the
-- original food line found nothing).
function D.roomFoodLocal(here, px, py)
	local out = {}
	if not (px and py) then return out end
	local x1, y1, x2, y2 = D.roomFloorAt(px, py)
	if here and here.minx then x1, y1, x2, y2 = here.minx, here.miny, here.maxx, here.maxy end
	-- same source as D.floorKeys: the pass's own prop sweep, not a type-3 scan (see there)
	for _, o in ipairs(D.objScan() or {}) do
		if tonumber(D.objGet(o, 'Type')) == 3 then
			local id = tonumber(D.objGet(o, 'Id'))
			local x, y = D.objTile(o)
			if id and D.DH_FOOD[id] and x then
				x, y = math.floor(x), math.floor(y)
				if x >= x1 - 1 and x <= x2 + 1 and y >= y1 - 1 and y <= y2 + 1 then
					local t = D.objGet(o, 'Tile_XYZ')
					local z = math.floor(tonumber(D.objGet(t, 'z')) or 0)
					local d = math.max(math.abs(x - px), math.abs(y - py))
					-- same rule as D.takeFloorItem: anything within two tiles is taken
					-- without asking the client, and the path find only decides for the rest
					if d <= 2 or D.tileReachable(x, y, z, D.REACH_LOCAL) then
						out[#out + 1] = { o = o, x = x, y = y, z = z, d = d, id = id }
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

-- The "Eat Food" ability on the action bar. Preferred over clicking the item: it is the
-- one-click route the game itself offers, and it works while the inventory is closed or a
-- fight is running. The bar record is cached and re-read every couple of minutes - a bar can
-- be swapped while the script runs, and a stale record clicks nothing.
D.foodAbility, D.foodAbilityAt = nil, 0
function D.foodAbilityGet()
	if D.foodAbility and (API.SystemTime() - (D.foodAbilityAt or 0)) < 120000 then
		return D.foodAbility
	end
		local ok, ab = pcall(function() return API.GetABs_name1('Eat Food') end)
		if ok and ab and ab.enabled then
			D.foodAbility, D.foodAbilityAt = ab, API.SystemTime()
			return ab
		end
	D.foodAbility, D.foodAbilityAt = nil, API.SystemTime()
	return nil
end

-- Eat while below D.FOOD_EAT_AT percent. THE ABILITY ONLY - "Eat Food" on the bar. No
-- inventory click: the ability is the route the game offers and the one the pack is checked
-- against. If it is not on the bar nothing is eaten, and that is said once so it is obvious
-- why the character stopped healing.
function D.eatFood()
	local pc = nil
	local ok, p = pcall(function() return API.GetHPrecent() end)
	if ok and tonumber(p) then pc = tonumber(p) end
	if not pc or pc >= D.FOOD_EAT_AT then return false end
	if (API.SystemTime() - (D.lastEatAt or 0)) < D.FOOD_EAT_MS then return true end
	if D.foodHeld() <= 0 then return false end
	local ab = D.foodAbilityGet()
	if not ab then
		if not D.noFoodAbilityLog then
			D.noFoodAbilityLog = true
			log('eating: the "Eat Food" ability is not on the action bar - cannot heal')
			say('no Eat Food ability on the bar')
		end
		return false
	end
	local okA, done = pcall(function()
		return API.DoAction_Ability_Direct(ab, 1, API.OFF_ACT_GeneralInterface_route)
	end)
	if not (okA and done == true) then return false end
	say(string.format('eating - %d%% life points', math.floor(pc)))
	log(string.format('eating at %d%% life points with the Eat Food ability', math.floor(pc)))
	D.lastEatAt = API.SystemTime()
	API.RandomSleep2(600, 200, 300)
	return true
end

-- Is the floor still arriving? The map only ever grows as it streams in, so the
-- walk-tile count is the signal: new tiles = still streaming, two passes with no
-- new tiles = arrived. Anything is better than the old blind twelve-pass wait.
function D.mapStreaming(world)
	local n = world.tileCount or 0
	if n > (S.streamTiles or 0) then
		S.streamTiles = n
		S.streamStill = 0
		return true
	end
	S.streamStill = (S.streamStill or 0) + 1
	return S.streamStill < 2
end

--------------------------------------------------------------------
-- sub-modules: the map/pathfinder half, the puzzle rooms and the bosses
--------------------------------------------------------------------

-- The helpers those files may call back into. One table, built once, so a helper
-- that is renamed or removed breaks here instead of quietly becoming a nil global
-- inside a sub-module. Every entry is a local of this chunk, defined above.
local H = {
	attack = attack, chat = chat, clearReach = clearReach,
	code = code, countKeys = countKeys, dkey = dkey,
	doorKeyFromName = doorKeyFromName, drainChat = drainChat,
	engineInCombat = engineInCombat, entityReachable = entityReachable,
	foodInRoom = foodInRoom, hasKeyFor = hasKeyFor, heldKeys = heldKeys,
	inCombat = inCombat, isMoving = isMoving, keysInRoom = keysInRoom,
	liveEnemies = liveEnemies, log = log, pairKey = pairKey,
	pkey = pkey, ptile = ptile, readKeyVar = readKeyVar,
	rkey = rkey, say = say, settle = settle,
	waitStill = waitStill, warn = warn,
}

-- X is what the modules share with each other: calls the puzzle
-- bookkeeping (a solved room is never guessed at again) and puzzles.lua calls the
-- doorway helpers (the icy pads slide the player through one). They cannot see each
-- other's locals, so the functions are published here.
local X = {}
-- The door predicates the puzzle module binds when it loads. They are thin reads of
-- world.doors, which D.localWorld fills from the door objects: a doorway is open when its
-- own tile is floor, ours when it stands in or against this room, and clickable when we
-- stand on the floor beside it. Nothing here routes anywhere - that half is gone.
X.doorInRoom = function(here, d) return D.tileInHere(here, d.x, d.y, 1) end
X.doorwayOpen = function(world, d) return (world.walk and world.walk[pkey(d.x, d.y)]) == true end
X.doorNoKey = function(world, d) return d.kind == 'locked' end
X.doorClickable = function(d, world) return d.kind ~= 'locked' and world.walk[pkey(d.sx, d.sy)] == true end
-- Nothing is known about the room beyond a doorway, so "work behind it" never counts.
X.doorLeadsToWork = function() return false end
-- Did the step from one tile to the other go through this doorway? One step is one tile,
-- so "the doorway is on or beside the step" is the whole answer.
X.crossedDoorway = function(d, x1, y1, x2, y2)
	local lox, hix = math.min(x1, x2), math.max(x1, x2)
	local loy, hiy = math.min(y1, y2), math.max(y1, y2)
	return d.x >= lox - 1 and d.x <= hix + 1 and d.y >= loy - 1 and d.y <= hiy + 1
end
-- The leaf to click: the record of this doorway whose room-side tile is floor.
X.enterLeaf = function(world, d)
	if world.walk[pkey(d.sx, d.sy)] then return d end
	for _, other in ipairs(world.doors or {}) do
		if math.abs(other.x - d.x) <= 1 and math.abs(other.y - d.y) <= 1
			and other.kind ~= 'locked' and world.walk[pkey(other.sx, other.sy)] then
			return other
		end
	end
	return nil
end
X.openDoor = function(d, world)
	local leaf = X.enterLeaf(world, d)
	if not leaf then return false end
	D.clickObject(leaf.act, leaf.obj)
	return true
end
-- How many rooms the player is standing in. The room model holds one, so this is 0 or 1 -
-- it exists because the ice solver uses it to notice that a slide carried the player into
-- the next room, which cannot happen here.
X.roomNearRooms = function(rooms, px, py)
	for _, r in ipairs(rooms or {}) do
		if D.tileInHere(r, px, py, 0) then return 1 end
	end
	return 0
end
-- A doorway that was walked through marks both its faces, so the one behind the player
-- is never a destination again.
X.markDoorway = function(d, world)
	for _, other in ipairs((world and world.doors) or {}) do
		if math.abs(other.x - d.x) <= 1 and math.abs(other.y - d.y) <= 1 then
			D.traversed[dkey(other)] = true
		end
	end
	D.lastDoorTile = { x = d.x, y = d.y }
end
local bindPuzzles = require("puzzles")(D, API, S, H, X)
local bindBosses  = require("bosses")(D, API, S, H, X)

-- Second pass: every module is installed, so what they import from each other now
-- exists and can be bound into their forward-declared locals.
bindPuzzles()
bindBosses()

-- The chunk-level names this half of the script still uses, taken from the exports
-- the modules just published.
blockingDoor = X.blockingDoor
bossAttack = X.bossAttack
bossDoorReachable = X.bossDoorReachable
buildGraph = X.buildGraph
deadEnds = X.deadEnds
doorClickable = X.doorClickable
doorInRoom = X.doorInRoom
doorLeadsToRoom = X.doorLeadsToRoom
doorLeadsToWork = X.doorLeadsToWork
doorNoKey = X.doorNoKey
doorReachable = X.doorReachable
doorRecent = X.doorRecent
doorwayOpen = X.doorwayOpen
-- also on D, for dumpWorld: the state dump is declared above these imports and can
-- only see D, and "why is this doorway not a goal" is exactly what it has to answer
D.doorwayUnfinished, D.roomHoldsDoorWork = X.doorwayUnfinished, X.roomHoldsDoorWork
D.doorFarRooms, D.doorLeadsToWork = X.doorFarRooms, X.doorLeadsToWork
farLeafOf = X.farLeafOf
findBoss = X.findBoss
findHop = X.findHop
findLadder = X.findLadder
frontierHop = X.frontierHop
getWorld = X.getWorld
isBossDoor = X.isBossDoor
leaveRoom = X.leaveRoom
markDoorway = X.markDoorway
nearestKeyOnFloor = X.nearestKeyOnFloor
pondReset = X.pondReset
pondskaters = X.pondskaters
puzzleDone = X.puzzleDone
puzzleMarkSolved = X.puzzleMarkSolved
roomAt = X.roomAt
roomNearRooms = X.roomNearRooms
scanWorld = X.scanWorld
solveFerrets = X.solveFerrets
solveFlipTiles = X.solveFlipTiles
solveIcyPads = X.solveIcyPads
solvePondskaters = X.solvePondskaters
takeFloorChanged = X.takeFloorChanged
takeLadder = X.takeLadder
tryOpen = X.tryOpen

--------------------------------------------------------------------
-- main loop
--------------------------------------------------------------------

-- Any room solver that takes the pass is a LOCAL room plan: the bot is busy inside
-- this room, so the floor route is not calculated until it stops. Wrapped here, at
-- the one place the solvers are called, so every one of them is covered without
-- having to remember to mark itself. A table field, not a local: a local would be
-- one more of the 200 this file may have.
-- WHICH solver took the pass is a mapping from the solver function itself, so no call
-- site has to pass a name and a new solver only needs one line here to be named on the
-- state line. Missing from the table = it still works, it is just called "puzzle room".
D.SOLVER_LABEL = {
	[D.solveGrappleBridge] = 'grapple bridge',
	[D.solveBarrels] = 'barrels',
	[D.solveMaze] = 'toxin maze',
	[D.solveMonolith] = 'monolith',
	[D.solveFollowLeader] = 'follow the leader',
	[D.solveGrooves] = 'grooves',
	[D.solveStatues] = 'statues',
	[D.solveSlidingStatues] = 'sliding statues',
	[D.solveSleepingGuards] = 'sleeping guards',
	[D.solveSwitches] = 'levers',
	[D.solveConstruct] = 'construct',
	[D.solveGhost] = 'unhappy ghost',
	[D.solveCollapse] = 'collapsing room',
	[D.solveBridge] = 'damaged bridge',
	[solvePondskaters] = 'pondskaters',
	[solveFerrets] = 'ferrets',
	[solveFlipTiles] = 'flip tiles',
	[solveIcyPads] = 'icy pads',
	[D.solveCamp] = 'fremennik camp',
	[D.solveRecess] = 'coloured recess',
}

function D.localRoom(fn, ...)
	-- ONE BAD SOLVER MUST NOT END THE RUN. Every solver reads live engine userdata, and a
	-- prop removed between the scan and the read throws inside the engine's __index
	-- ("[C]: in metamethod 'index'") - which used to kill the script mid-floor instead of
	-- costing one pass.
	local okCall, busy = pcall(fn, ...)
	if not okCall then
		local label = tostring(D.SOLVER_LABEL[fn] or 'solver')
		local now = API.SystemTime()
		D.solverFailAt = D.solverFailAt or {}
		-- the window shows this: when no solver holds a room, "nothing is happening" is
		-- useless - the reason it is nothing is the answer
		D.solverFail = string.format('%s threw: %s', label, tostring(busy))
		if not D.solverFailAt[label] or (now - D.solverFailAt[label]) > 10000 then
			D.solverFailAt[label] = now
			log(string.format('solver %s threw: %s - room skipped this pass', label, tostring(busy)))
		end
		return false
	end
	D.solverFail = nil
	if busy then
		-- the solver acted: this room is its room, and the floor route stays unplanned
		D.solverRoom, D.solverQuiet, D.solverFn = rkey(D.here), 0, fn
		-- the floor route is not planned while a solver holds the room; the hook that
		-- used to say so lived in the pathing half and is gone with it
		if D.noteLocalPlan then D.noteLocalPlan() end
		-- NOTHING IS RESET HERE ANY MORE. This used to hand the walker's puzzle-guess budget
		-- back on every solver action, so any solver acting on anything in the room reset the
		-- count and the walker re-guessed for ever: live, a room with "Stack of barrels" decor
		-- produced "path: standing down ... (barrel [barrel])" every twenty seconds while the
		-- sweep kept routing out and back. The budget is per room per floor now, and props a
		-- genuinely solved puzzle leaves behind are handled where they are judged (a solved
		-- room is not guessed at at all).
		D.setStateNow('puzzle room - ' .. tostring(D.SOLVER_LABEL[fn] or 'solver working'))
	elseif D.solverRoom and D.solverRoom == rkey(D.here) then
		-- it did nothing this pass (waiting for an animation, a rescan, a prop to go):
		-- keep the room a moment longer, but not for ever - a solver that has given up
		-- must let the router take over.
		D.solverQuiet = (D.solverQuiet or 0) + 1
		if D.solverQuiet > (D.SOLVER_QUIET_PASSES or 3) then
			D.solverRoom, D.solverQuiet, D.solverFn = nil, 0, nil
		end
	end
	return busy
end

-- On-screen state through the direct ImGui bind: the callback runs every frame
-- and reads live state, so nothing has to be poked from the main loop.
-- The boss npc only streams in within about 20 tiles, so which boss it is gets
-- written down when it is seen at the boss door, and the window says plainly
-- when it is still unknown instead of leaving the run guessing.
-- ClearRender first: a callback left behind by an earlier run of this script
-- keeps drawing a stale window and the new one never shows.
ClearRender()
DrawImGui(function()
  ImGui.SetNextWindowPos(6, 38, ImGuiCond.FirstUseEver)
  if ImGui.Begin('Dung##dung_ui') then
    if D.bossDown then
      ImGui.TextColored(0.45, 1.0, 0.45, 1.0, 'Boss: DOWN - the "End dungeon" ladder is up')
    elseif D.bossLive then
      ImGui.TextColored(0.45, 1.0, 0.45, 1.0, string.format('Boss: %s (%s) - in sight',
        tostring(D.bossLive.Name), tostring(D.BOSSES[D.bossLiveLogic or ''])))
    elseif D.bossSeenName then
      ImGui.TextColored(1.0, 0.85, 0.35, 1.0, string.format('Boss: %s (%s) - not loaded, remembered',
        D.bossSeenName, tostring(D.BOSSES[D.bossSeenName])))
    else
      ImGui.TextColored(0.75, 0.75, 0.75, 1.0, 'Boss: UNKNOWN - no boss npc seen at the boss door yet')
    end
    ImGui.Text('Doing: ' .. tostring(D.status or 'starting'))
    -- WHICH ROOM OF THE FLOOR: the cell the player stands in, by the same lattice the
    -- purple dots are drawn on (D.roomCellAt), numbered row-major from the south-west
    -- corner of the layout. Read live in the callback, so it changes the moment a doorway
    -- is crossed instead of one pass behind.
    do
      local rpx, rpy = ptile()
      local rnum, ri, rj = D.roomNumber(rpx, rpy)
      local lay = D.LAYOUT[D.layout or 1] or D.LAYOUT[1]
      local rcx, rcy = D.roomCellAt(rpx, rpy)
      ImGui.TextColored(0.80, 0.62, 1.0, 1.0, string.format(
        'Room %d/%d  (col %d, row %d)  centre %d,%d', rnum, lay[1] * lay[2],
        ri + 1, rj + 1, rcx, rcy))
    end
    -- WHICH PUZZLE, right now: D.localRoom records the solver that took the pass and the
    -- room key it took it in, and clears both when the room is released, so this line
    -- cannot disagree with the branch the loop is actually in. A solver with no entry in
    -- D.SOLVER_LABEL still shows - it is a puzzle room, it just has no name yet.
    do
      local label = D.solverFn and (D.SOLVER_LABEL[D.solverFn] or 'puzzle room') or nil
      if label then
        ImGui.TextColored(0.85, 0.75, 1.0, 1.0, string.format('Puzzle: %s  [%s]',
          tostring(label), tostring(D.solverRoom or '?')))
      elseif D.solverFail then
        -- nothing holds a room: say WHY, the throw is the reason the pass did nothing
        ImGui.TextColored(1.0, 0.45, 0.45, 1.0, 'Puzzle: ' .. tostring(D.solverFail))
      else
        ImGui.TextColored(0.55, 0.55, 0.60, 1.0, 'Puzzle: none')
      end
    end
    -- The state line: the branch that took the last pass, and the room it took it in. It is
    -- set by the branch itself (D.setStateNow), so it can never lag behind what the bot is
    -- actually doing - the "Doing" line above is the sentence the last solver wrote, this is
    -- where the loop is.
    local stateNow = tostring(D.stateNow or 'starting')
    if D.here then stateNow = stateNow .. '  [' .. rkey(D.here) .. ']' end
    if D.solverRoom and D.here and D.solverRoom == rkey(D.here) then
      stateNow = stateNow .. ' (solver holds this room)'
    end
    ImGui.TextColored(0.55, 0.80, 1.0, 1.0, 'State: ' .. stateNow)
  end
  ImGui.End()
end)

--------------------------------------------------------------------
-- scan lifetime: a record is a POINTER INTO the scan that produced it
--------------------------------------------------------------------
-- ME::ReadAllObjectsArray returns one std::vector<AllObject>, and sol2 hands that
-- table out as a single userdata whose elements are pushed BY REFERENCE
-- (sol/stack_push.hpp as_reference_tag -> a raw pointer at the vector element).
-- So the moment the returned table is collected - the usual temporary in
-- `for _, o in ipairs(API.ReadAllObjectsArray(...))` - every record taken from it
-- points into freed memory. Plain ints (Id, Type, Tile_XYZ) often still read, but
-- Name/Action are std::string and copying one out of freed memory dies inside
-- sol2's catch-all as "caught (...) exception" - the exact error the unhappy ghost
-- and collapsing room solvers threw on every pass, and why D.objName/D.objGet have
-- to exist at all. Pinning the returned table keeps every record of it valid; the
-- pins are dropped when the next pass starts, by which time nothing may hold a
-- record of the old one.
--
-- A LATER CALL DOES NOT REACH INTO THE EARLIER ONE: each call allocates its own vector,
-- so two scans live side by side and an earlier table that is still referenced keeps
-- working. What is never allowed is the unpinned temporary:
-- `for _, o in ipairs(API.ReadAllObjectsArray(...))` puts every record it hands out at
-- the mercy of the collector the moment the loop ends.
D.scanPins = {}
function D.keepScan(list)
	if list ~= nil then
		D.scanPins = D.scanPins or {}
		D.scanPins[#D.scanPins + 1] = list
	end
	return list
end

local function filterObjects(ids, names, filterBool1)
	local OBJECTS_global = D.keepScan(API.ReadAllObjectsArray({0,12}, ids, names)) or {}
	local OBJECTS = {}
	if filterBool1 then
		for _, o in ipairs(OBJECTS_global) do
			if o.Bool1 == 0 then	
				OBJECTS[#OBJECTS + 1] = o
			end
		end
	else
		return OBJECTS_global
	end
	return OBJECTS
end

--------------------------------------------------------------------
-- puzzle objects: props and map tiles from ONE sweep
--------------------------------------------------------------------

-- Everything a puzzle room needs arrives in a single ReadAllObjectsArray call:
--   0 Object, 12 Decor  - the real props (switch, barriers, pedestals, chest)
--   3 GroundItem        - the four objectives that are dropped, not placed: barrel
--                         bits, the power crystal, the ghost ring, the stomp crystal
--   99 CombinedBlocker  - the tile records the maze search runs on
-- The engine appends the 99 records AFTER the entity scan, so the ids/names filters
-- never reach them, and their Tile_XYZ z means nothing: a 99 record is a tile's
-- combined blocker, not an object. Splitting the answer here means no caller has to
-- know that - `objs` are entities, `cells` is the grid.
--
-- cells[k] = { x, y, cuts, blocked }, one per tile. Two records on one tile are
-- merged: the Cmb_lv wall cuts (low nibble N=1 E=2 S=4 W=8) are OR'd, and blocked
-- wins over standable (Bool1 = 1 is a solid tile; a tile with cuts is still
-- standable, which is why the two are separate fields).

-- Lua 5.1 has no bitwise operators and `0` is truthy in this runtime, so the mask
-- maths is arithmetic - the same reason puzzles.lua carries its own pair.
local function maskHas(v, bit) return math.floor((v or 0) / bit) % 2 == 1 end
local function maskOr(a, b)
	if a == 0 then return b end
	if b == 0 then return a end
	local out, bit = 0, 1
	while bit <= 15 do
		if maskHas(a, bit) or maskHas(b, bit) then out = out + bit end
		bit = bit * 2
	end
	return out
end

-- Every call is a fresh sweep: the room changes between calls (a barrier opens, a
-- pedestal is used, a barrel is pushed), so a cached answer is the one thing that must
-- never be returned.
function D.puzzleScan()
	local objs, cells = {}, {}
	-- the records copied into `objs` point into this scan: pin it (see D.keepScan)
	for _, o in ipairs(D.keepScan(API.ReadAllObjectsArray({ 0, 3, 12, 99 }, {}, {})) or {}) do
		-- the tile read is protected and NaN-guarded: a prop that is spawning or
		-- being removed reports a tile math.floor cannot represent
		local x, y = D.objTile(o)
		if x then
			x, y = math.floor(x), math.floor(y)
			if D.objGet(o, 'Type') == 99 then
				local k = pkey(x, y)
				local cuts = math.floor(tonumber(D.objGet(o, 'Cmb_lv')) or 0)
				local blocked = (tonumber(D.objGet(o, 'Bool1')) or 0) == 1
				local c = cells[k]
				if c then
					c.cuts = maskOr(c.cuts, cuts)
					c.blocked = c.blocked or blocked
				else
					cells[k] = { x = x, y = y, cuts = cuts, blocked = blocked }
				end
			else
				objs[#objs + 1] = o
			end
		end
	end
	return { objs = objs, cells = cells }
end

-- The object half of the same sweep, under the name the puzzle and boss modules
-- already call. A second scan type set would be a second sweep, and the four
-- ground-item lookups are the reason 3 is in it.
--
-- A pass reads the world ONCE (D.puzzleScan at the top of the main loop) and publishes
-- the props as D.passObjs, so the sixteen D.objScan() calls in the puzzle modules all
-- read that same list instead of sweeping the whole map again each: the chain of
-- solvers runs on every pass, and one sweep each was the difference between "it thinks"
-- and "it is stuck". Nothing is stored between passes - D.passObjs is cleared at the
-- top of every iteration - so a call made outside a pass still reads the world itself.
function D.objScan()
	if D.passObjs then return D.passObjs end
	return D.puzzleScan().objs
end

-- The props as they are RIGHT NOW, ignoring the pass's snapshot. For the handful of
-- readers that judge a change this same pass made - a "Jump-over" the puzzle has just
-- re-created, a pedestal that was mined, a chest that was clicked.
function D.objsFresh()
	return D.puzzleScan().objs
end

-- NPCs are their own sweep: twelve lookups in the two modules (pondskaters, statues,
-- barrels, the monolith's shades, guards, the construct, both bosses) all want the
-- same list, so it is read once and shared. The props above are one sweep per pass
-- (D.objScan) because a puzzle prop changes the room; an npc list is only used to
-- choose a target from, so an npc that walked a tile in 700 ms is still that target.
-- -1 is "no reach filter": it has to be SEEN here, and whether the client can path to
-- it is asked per candidate, not for the list.
D.NPC_TTL = 700
D.npcCache, D.npcCacheAt = nil, 0
function D.npcScan(force)
	local now = API.SystemTime()
	if not force and D.npcCache and (now - D.npcCacheAt) < D.NPC_TTL then
		return D.npcCache
	end
	-- pinned as well: D.npcCache is dropped mid-pass on purpose (a wake-up, a kill),
	-- and the npc records the callers still hold must not die with it
	--
	-- THE REACH FILTER IS OFF (-1), which is what the note above always said: a value of
	-- 0 asks the client for a path find to EVERY npc and drops the ones it refuses - and
	-- it refused the one npc that matters. Live, in Stomp's boss room: the boss stood at
	-- 9736,1083 with "Attack" and 2626 life, was never in this list, so neither the boss
	-- strategy nor the room-clear branch ever clicked him ("Stomp is currently
	-- invulnerable!" in chat was auto-retaliate, and there is not one DoAction_NPC line
	-- for the whole fight). Reach is asked per candidate by D.roomNpcs, where a boss
	-- click does not need it.
	D.npcCache = D.keepScan(API.ReadAllObjectsArray({ 1 }, {}, {}, D.NO_REACH)) or {}
	D.npcCacheAt = now
	return D.npcCache
end

-- THE ROOM'S OWN ENEMIES - not the floor's. The fight branch used to read a list that was
-- never assigned at all, and the call it was meant to make,
-- ReadAllObjectsArray({ 1 }, {}, {}, 0), asks the client for a path find PER NPC on the
-- floor (any startpathreach but -1 does: see D.NO_REACH). So the room is decided in Lua
-- first and the client is only asked about the handful that survive:
--
--   room    - the NPC stands inside this room's floor box (D.roomFloorAt), with one tile
--             of slack for a monster standing in the doorway
--   alive   - Life > 1: an npc that is dying is not a target
--   Attack  - its own option is Attack. Every puzzle npc in a dungeon offers Push, Catch,
--             Mine or Talk instead, so this drops them without a name table to maintain
--   reach   - D.tileReachable(x, y, z, 0) - the tolerance-0 answer the fight wants - ONE
--             call per survivor, cached per tile for D.NPC_REACH_MS so a stationary
--             monster is not re-pathed on every 500 ms pass
--
-- Returns plain Lua records { obj, x, y, z, name, life }; `obj` is the engine record and
-- stays valid because D.npcScan pins the scan behind it.
D.NPC_REACH_MS = 1500
D.npcReach = {}
function D.roomNpcs(here, px, py)
	local x1, y1, x2, y2 = D.roomFloorAt(px, py)
	if here and here.minx then
		x1, y1, x2, y2 = here.minx, here.miny, here.maxx, here.maxy
	end
	local now = API.SystemTime()
	local out = {}
	for _, n in ipairs(D.npcScan() or {}) do
		local nx, ny = D.objTile(n)
		if nx then
			nx, ny = math.floor(nx), math.floor(ny)
			if nx >= x1 - 1 and nx <= x2 + 1 and ny >= y1 - 1 and ny <= y2 + 1 then
				local life = tonumber(D.objGet(n, 'Life')) or 0
				if life > 1 and D.objGet(n, 'Action') == 'Attack' then
					local name = D.objName(n)
					-- A BOSS IS NOT A ROOM MONSTER. Its reported tile is a 4x4 footprint the
					-- client will not path onto (live: Stomp at 9736,1083, "Attack", 2626
					-- life - reach refused at tolerance 0), and a boss click is re-sent from
					-- wherever the player stands anyway, so reach is asked for everything
					-- else and skipped for a boss.
					local isBoss = D.bossKey ~= nil and D.BOSSES ~= nil
						and D.BOSSES[D.bossKey(name)] ~= nil
					local okZ, tz = pcall(function() return n.Tile_XYZ.z end)
					local nz = okZ and math.floor(tonumber(tz) or 0) or 0
					local k = pkey(nx, ny)
					local hit = D.npcReach[k]
					if not isBoss and not (hit and (now - hit.at) < D.NPC_REACH_MS) then
						hit = { ok = D.tileReachable(nx, ny, nz, 0), at = now }
						D.npcReach[k] = hit
					end
					if isBoss or (hit and hit.ok) then
						out[#out + 1] = { obj = n, x = nx, y = ny, z = nz,
							name = name, life = life }
					end
				end
			end
		end
	end
	return out
end

--------------------------------------------------------------------
-- the room the solvers see, and the two clicks they need
--------------------------------------------------------------------

-- A Daemonheim room is self-contained: there is no floor route to plan inside it and
-- no doorway to walk through, so "world" is the grid around the player plus the props
-- standing on it. The flood fill stops at a wall cut on either side of an edge, at a
-- doorway, and at D.ROOM_MAX_R as a backstop.
D.ROOM_MAX_R, D.ROOM_MAX_TILES = 16, 400

-- { dx, dy, cut bit of the tile we leave, cut bit of the tile we enter }
local STEP = {
	{ 0, 1, 1, 4 }, { 1, 0, 2, 8 }, { 0, -1, 4, 1 }, { -1, 0, 8, 2 },
}

-- A doorway is a one-tile gap in a wall line: the frame either side of it stays solid
-- whether the leaf is open or shut. That is the only thing about a doorway that does
-- not change with its state, which is exactly what the room needs - walking through an
-- OPEN doorway used to run the fill into the corridor and the next room, and the four
-- walls then measured the wrong rectangle, so the door task clicked doors that were
-- already open and doors that were never ours.
local function chokepoint(cells, x, y, dx, dy)
	local a = cells[pkey(x - dy, y - dx)]
	local b = cells[pkey(x + dy, y + dx)]
	return a ~= nil and b ~= nil and a.blocked and b.blocked
end

-- The same question without a direction: is this tile a one-tile opening in a wall line,
-- so that standing on it means standing IN a doorway (or in a corridor, which is the
-- same shape). The fill must not start from such a tile, or it would run out both ways.
local function isGap(cells, x, y)
	local l, r = cells[pkey(x - 1, y)], cells[pkey(x + 1, y)]
	if l and r and l.blocked and r.blocked then return true end
	local u, d = cells[pkey(x, y - 1)], cells[pkey(x, y + 1)]
	return u ~= nil and d ~= nil and u.blocked and d.blocked
end

function D.roomFromCells(cells, px, py)
	if not cells then return nil end
	local sx, sy = math.floor(px), math.floor(py)
	local seed = cells[pkey(sx, sy)]
	if not (seed and not seed.blocked and not isGap(cells, sx, sy)) then
		-- standing on a barrier, a pad, or in the doorway itself: no free cell under us,
		-- so seed from the closest one. Every solver stands still while it thinks, and a
		-- nil room switches all of them off at once.
		local bx, by, bd = nil, nil, 99
		for dx = -2, 2 do
			for dy = -2, 2 do
				local c = cells[pkey(sx + dx, sy + dy)]
				-- how far the candidate is from the tile we are standing on (Chebyshev,
				-- like every other distance in this file); 0 is the tile itself, which is
				-- the one we already know is not floor
				local d = math.max(math.abs(dx), math.abs(dy))
				if c and not c.blocked and d > 0 and d < bd
					and not isGap(cells, sx + dx, sy + dy) then
					bd, bx, by = d, sx + dx, sy + dy
				end
			end
		end
		if not bx then return nil end
		sx, sy = bx, by
		seed = cells[pkey(sx, sy)]
	end
	local set, tiles = { [pkey(sx, sy)] = true }, { { x = sx, y = sy } }
	local head, n = 1, 1
	local minx, maxx, miny, maxy = sx, sx, sy, sy
	while head <= #tiles and n < D.ROOM_MAX_TILES do
		local cur = tiles[head]
		head = head + 1
		local a = cells[pkey(cur.x, cur.y)]
		for i = 1, 4 do
			local d = STEP[i]
			local nx, ny = cur.x + d[1], cur.y + d[2]
			local nk = pkey(nx, ny)
			if not set[nk]
				and math.abs(nx - sx) <= D.ROOM_MAX_R and math.abs(ny - sy) <= D.ROOM_MAX_R then
				local b = cells[nk]
				if b and not b.blocked
					and not maskHas(a and a.cuts or 0, d[3])
					and not maskHas(b.cuts, d[4])
					and not chokepoint(cells, nx, ny, d[1], d[2]) then
					set[nk] = true
					tiles[#tiles + 1] = { x = nx, y = ny }
					n = n + 1
					if nx < minx then minx = nx elseif nx > maxx then maxx = nx end
					if ny < miny then miny = ny elseif ny > maxy then maxy = ny end
				end
			end
		end
	end
	return {
		minx = minx, maxx = maxx, miny = miny, maxy = maxy,
		cx = math.floor((minx + maxx) / 2), cy = math.floor((miny + maxy) / 2),
		set = set, tiles = tiles, n = n,
	}
end

-- WHICH ROOM, from the floor's lattice instead of from the blob. Every tile knows the
-- room it stands in: a room is D.ROOM_CELL wide, the floor is a grid of them, and a 4x4
-- layout is exactly one 64x64 region - so the region corner is the lattice origin.
-- Answers the room's centre (a float: its true middle) and the cell index.
function D.roomCellAt(x, y)
	local bx = math.floor(x / 64) * 64
	local by = math.floor(y / 64) * 64
	local i = math.floor((x - bx) / D.ROOM_CELL)
	local j = math.floor((y - by) / D.ROOM_CELL)
	return bx + i * D.ROOM_CELL + D.ROOM_CENTRE,
		by + j * D.ROOM_CELL + D.ROOM_CENTRE, i, j
end

-- The room's number on the floor, 1..nx*ny, row-major from the lattice's south-west
-- corner - the same cell D.roomCentreDots stamps a purple dot on. Clamped, so a tile
-- outside the layout still answers a room instead of nil.
function D.roomNumber(x, y)
	local lay = D.LAYOUT[D.layout or 1] or D.LAYOUT[1]
	local nx, ny = lay[1], lay[2]
	local _, _, i, j = D.roomCellAt(x, y)
	i = math.max(0, math.min(nx - 1, i))
	j = math.max(0, math.min(ny - 1, j))
	return j * nx + i + 1, i, j
end

-- The floor of the room the tile at (x, y) stands in: its cell's interior, both corners.
-- A cell is D.ROOM_CELL across - wall, 14 floor, wall - and its centre is a float, so the
-- floor is centre-7 .. centre+6. This is the box every puzzle, doorway and prop test uses.
function D.roomFloorAt(x, y)
	local cx, cy = D.roomCellAt(x, y)
	return math.floor(cx - D.ROOM_RADIUS), math.floor(cy - D.ROOM_RADIUS),
		math.floor(cx + D.ROOM_RADIUS - 1), math.floor(cy + D.ROOM_RADIUS - 1)
end

-- Is this tile inside the room the player stands in? The lattice answers it, not the
-- blob: the whole floor of the room says yes and the doorway tiles in its walls (one
-- further out) say no.
function D.tileInPlayerRoom(x, y)
	if not (x and y) then return false end
	local px, py = ptile()
	local x1, y1, x2, y2 = D.roomFloorAt(px, py)
	local fx, fy = math.floor(x), math.floor(y)
	return fx >= x1 and fx <= x2 and fy >= y1 and fy <= y2
end

function D.localWorld(puzzle, px, py)
	puzzle = puzzle or D.puzzleScan()
	local here = D.roomFromCells(puzzle.cells, px, py)
	-- THE ROOM'S OWN SQUARE, NOT THE BLOB'S BOX. The fill stops at a choke point and a
	-- one-tile throat is a choke, so a room split by a maze corridor measured 9x5 and
	-- everything outside that stub was "not this room" - the chest 7 tiles out, the
	-- switch, the pedestals. The lattice knows the room: its centre is half a cell from
	-- its wall and its floor is 14 wide, so the room is every tile within D.ROOM_RADIUS
	-- of that centre. The blob stays as it is (its tiles, its set, its count) - only the
	-- box every puzzle judges by is the room's.
	if here then
		local cx, cy = D.roomCellAt(px, py)
		local x1, y1, x2, y2 = D.roomFloorAt(px, py)
		here.bcx, here.bcy = here.cx, here.cy
		here.bminx, here.bmaxx = here.minx, here.maxx
		here.bminy, here.bmaxy = here.miny, here.maxy
		here.cx, here.cy = cx, cy
		here.minx, here.maxx = x1, x2
		here.miny, here.maxy = y1, y2
	end
	local walk = {}
	for k, c in pairs(puzzle.cells) do
		if not c.blocked then walk[k] = true end
	end
	local world = {
		objs = puzzle.objs,        -- the props, as scanned
		walk = walk,               -- every standable tile (the slide/pad maths and the doors)
		rooms = here and { here } or {},
		room = here,
	}
	-- doors: this room's own doorways, and every doorway on the map for the dots
	world.doors, world.doorDots = D.roomDoors(world, px, py)
	return world, here
end

function D.SearchPairs(world, in_obj, ifnamepair)
	-- The pair search now runs for every doorway on the map, not just the room's, and it
	-- walks every prop: a record that lost its entity throws out of the engine's __index
	-- on the tile read (the reason D.objTile/D.objGet exist), so both sides are protected.
	local ok, t1 = pcall(function() return in_obj.Tile_XYZ end)
	if not (ok and t1) then return false end
	local action = D.objGet(in_obj, 'Action')
	for _, o in ipairs(world.objs or {}) do
		if tonumber(D.objGet(o, 'Type')) ~= 3 and o ~= in_obj then
			local ok2, t2 = pcall(function() return o.Tile_XYZ end)
			if not (ok2 and t2) then
				return false
			end
			local dist = API.Math_Distance(t1, t2)
			if ifnamepair then
				if (tonumber(D.objGet(o, 'Bool1')) or 0) == 0
					and dist > 0.5 and dist < 2 and D.objName(o) == ifnamepair then
					return true--there should be only one
				end
			else
				if action == 'Unlock' then--
					return false--ignore keys
				end
				-- ONLY A DOORWAY CAN BE THE OTHER FACE OF A DOORWAY. Any prop within two
				-- tiles used to count, so the maze barrier standing beside a doorway made
				-- that doorway "paired": live, door 49338 at 8792,1040 was paired with
				-- barrier 49341 at 8791,1041 - red dot, never clicked, room sealed shut.
				--
				-- Bool1 0 IS PART OF THAT TEST. Dropping it (to let a solved skill door
				-- pair with the plain door that replaces it) paired every doorway that had
				-- a DECOR back face beside it - the Guardian door started reading as a pair
				-- - because a decor/back face reports Bool1 1. A real door face is Bool1 0,
				-- and the same tile still counts, so a replacement plain door pairs without
				-- letting decorations in.
				if (tonumber(D.objGet(o, 'Bool1')) or 0) == 0
					and dist < 2 and D.looksLikeDoor(o) and not D.isSkillDoor(o) then
					return true--there should be only one
				end
			end
		end
	end
	return false
end

-- Could this prop be a doorway at all? The scan carries every prop on the map, so the
-- full D.doorKindOf read - name family, and a pair search over every prop for a key door -
-- only runs on a prop whose id or name can answer "door". These are the same id table and
-- name families D.doorKindOf itself tests, so nothing a door is recognised by is missed.
function D.looksLikeDoor(o)
	local id = tonumber(D.objGet(o, 'Id'))
	if id and D.doorKind[id] then return true end
	local name = D.objName(o)
	if name == '' then return false end
	if D.SKILL_DOOR_NAMES[name] then return true end
	-- Key doors are named "<colour> <shape> door" in every case seen live, but the name
	-- alone is what D.doorKindOf unlocks on, so a name the key table can resolve counts
	-- even if the word "door" is missing.
	if D.doorKeyFromName and D.doorKeyFromName(name) then return true end
	return string.find(string.lower(name), 'door', 1, true) ~= nil
end

-- Doorways and the key ring in one answer: only a key door ever answers with a value.
--   nil   - no key is involved (every doorway that is not an unopened key door)
--   true  - an unopened key door and the ring has NO key for it  -> the blue dot
--   false - an unopened key door and the ring holds its key      -> nothing stands in the way
-- The test is the one D.doorKindOf's "key doors, unopened needs key" branch makes -
-- "Unlock" plus a name the key table resolves - so `key` cannot drift from that branch.
function D.doorKeyMissing(o, held, unknown)
	if D.objGet(o, 'Action') ~= 'Unlock' then return nil end
	local item = D.doorKeyFromName(D.objName(o))
	if not item then return nil end
	return not keyHeld(item, held, unknown)
end

-- DOES THIS PROP OFFER THE OPTION ITS SKILL-DOOR NAME EXPECTS? The live option is what
-- the engine reports and it is NOT always the text in the table: "Vine-covered door"
-- answers "Prune-vines", not "Prune" (checked live), and some doors carry a trailing
-- space ("Disarm "). A door that fails this test is not a skill door at all - it falls
-- through to D.SearchPairs, gets marked as a pair, and is never clicked, which is exactly
-- what happened to the vine.
--
-- So the comparison is normalised (lower case, hyphens read as spaces, runs collapsed,
-- trimmed) and a live word-prefix counts: "prune-vines" starts with "prune" + a word
-- break. `true` in the table means the option has not been recorded yet, in which case any
-- option identifies the door.
local function normAct(s)
	s = string.lower(tostring(s or ''))
	s = string.gsub(s, '[%-_]+', ' ')
	s = string.gsub(s, '%s+', ' ')
	return (string.gsub(s, '^%s*(.-)%s*$', '%1'))
end

function D.skillDoorMatch(name, act)
	-- a single-leaf skill door: name only, whatever option the client is showing
	if D.SKILL_DOOR_SINGLE and D.SKILL_DOOR_SINGLE[name] then return true end
	local want = D.SKILL_DOOR_NAMES[name]
	if not want then return false end
	if want == true then return type(act) == 'string' and act ~= '' end
	local w, a = normAct(want), normAct(act)
	if a == '' then return false end
	if a == w then return true end
	return string.sub(a, 1, #w + 1) == w .. ' '
end

-- Options a PLAIN doorway offers. A prop answering one of these is an ordinary door even
-- if its name still says otherwise: a solved skill door is deleted and a normal door is
-- created in its place, and the new record can keep the old name ("Divine door") - which,
-- with the name-only rule for single-leaf skill doors, would keep that doorway flagged
-- "skill, never paired" for the rest of the floor.
D.PLAIN_DOOR_ACTS = {
	['Enter'] = true, ['Open'] = true, ['Walk through'] = true,
	['Walk-through'] = true, ['Pass'] = true, ['Go through'] = true, ['Go-through'] = true,
}

-- Is this doorway one of the SKILL doors? A skill door is never paired: the prop
-- disappears when the skill is used on it and a plain doorway is left behind, so there is
-- no second leaf to look for.
function D.isSkillDoor(o)
	local name = D.objName(o)
	if name == '' then return false end
	local act = D.objGet(o, 'Action')
	if D.PLAIN_DOOR_ACTS[act] then return false end
	return D.skillDoorMatch(name, act)
end

-- Every doorway the map carries, one record per doorway tile, with three remarks:
-- `outsideRoom` - true when the door stands outside this room's range (the box test below,
-- with the tile of slack a perimeter record needs); `key` - nil for every doorway that
-- needs no key at all, true for an unopened key door whose key the ring does not hold,
-- false for one whose key we do hold; `skill` - true for a skill door, the one doorway
-- that is never paired (it gets a single green dot - and the white out-of-range dot under
-- it - while the doorway tile beside it stays dark; see D.openRoomDoor); `boss` - true for
-- the BOSS DOOR, which is not a doorway at all: it is a decor the client only creates when
-- the boss room is open, it is never paired, never clicked and it is drawn gold;
-- `bossPassage` - true for the ordinary doorway standing in front of that decor (whatever
-- kind of door it is), the way into the boss room, drawn gold once it is open.
-- A doorway is a door OBJECT: it says door (by name or id table) and stands on a blocked
-- tile with floor on the room's side.
--
-- Both faces of one doorway are on the map (live: "Door" at 9968,3720 and "Guardian door"
-- at 9967,3720), so each record is kept and each carries the tile beside it on OUR side -
-- one step from the door toward the player. Only the near face has floor there, which is
-- what makes it the room's own, and that tile is where the player stands to click.
function D.doorRecords(world, px, py)
	local all = {}
	local held, unknown = heldKeys()
	-- the room this pass already worked out, and one record per door tile
	local here = world and world.room
	local byTile = {}
	for _, o in ipairs(world.objs or {}) do
		-- THE BOSS DOOR IS TESTED FIRST. It is a DECOR, and a decor can report Bool1 = 1
		-- (solid) - the filter below would drop it before its name was ever read - and it
		-- carries no "door" id, so nothing else in this loop would look at it twice.
		local bossDoor = D.isBossDoor(o)
		-- A DOOR IS KEPT WHATEVER ITS Bool1 SAYS. Bool1 1 is the blocker flag on decor, but
		-- an OPEN doorway reports it too - and dropping those records is why a plain door
		-- that replaced a solved skill door never reached the pairing pass at all. Props
		-- that are not doors still need Bool1 0.
		if bossDoor
			or D.looksLikeDoor(o)
			or ((tonumber(D.objGet(o, 'Bool1')) or 0) == 0
				and (tonumber(D.objGet(o, 'Type')) or 0) ~= 3) then
			local x, y = D.objTile(o)
			if x then
				x, y = math.floor(x), math.floor(y)
				-- A doorway in the room next door is not this room's business, and the
				-- scan carries every prop that is loaded, not just the ones around us.
				-- The record stands ON the perimeter, so the box test carries a tile of
				-- slack - it is never inside the room's own set.
				local mine = not here
					or (here.set and here.set[pkey(x, y)])
					or (x >= here.minx - 1 and x <= here.maxx + 1
						and y >= here.miny - 1 and y <= here.maxy + 1)
				local Candidate = (not bossDoor) and D.looksLikeDoor(o)
					and D.doorKindOf(world, o, held, unknown) or nil
				if Candidate or bossDoor then
					-- `key` is nil unless this is an unopened key door: true when the
					-- ring has no key for it (the blue dot), false when it does. Nothing
					-- else - normal, guardian, skill, already-unlocked - needs a key.
					local keyMissing = (not bossDoor) and D.doorKeyMissing(o, held, unknown) or nil
					-- `skill` is the boolean the pairing loop below reads: a skill door
					-- is never paired (the prop is gone once the skill lands).
					local skill = (not bossDoor) and D.isSkillDoor(o) or false
					-- ONE RECORD PER TILE. A single doorway is several objects on the
					-- same tile (the near leaf, the far leaf's decor, a plain "Door"),
					-- and counting each of them is how "13-14 doors" came out of a room
					-- with four doorways. The real doorway's object is the one kept, an
					-- Object beats a Decor - but `skill` stays true for the tile if ANY
					-- object on it is a skill prop: that doorway is blocked either way.
					local k = pkey(x, y)
					local prev = byTile[k]
					-- BOOL1 DOES NOT TELL A DOORWAY FROM A DECORATION. Live, tile
					-- 11503,2984 carries 17162 "Door" (type 0, the solid leaf that opens -
					-- solid_mem on the tile points at it, Bool1 1) and 50344 "Door" (type
					-- 12 back face, also Bool1 1). Clicking the decor does nothing, so the
					-- real door OBJECT is what gets kept; Bool1 is only a tie-breaker.
					local oType = tonumber(D.objGet(o, 'Type')) or 0
					local oAct = D.objGet(o, 'Action')
					local oClosed = (tonumber(D.objGet(o, 'Bool1')) or 0) == 0
					if not prev then
						prev = { obj = o, x = x, y = y, Candidate = Candidate,
							outsideRoom = not mine, key = keyMissing, skill = skill,
							boss = bossDoor, closed = oClosed }
						byTile[k] = prev
						all[#all + 1] = prev
					else
						local objType = tonumber(D.objGet(o, 'Type')) or 0
						local prevType = tonumber(D.objGet(prev.obj, 'Type')) or 0
						local pClosed = prev.closed
						-- THE REAL DOOR OBJECT BEATS ITS DECOR BACK FACE, first of all;
						-- then a clickable face over a solid one; then the skill prop.
						local better = (objType == 0 and prevType ~= 0)
							or (objType == prevType and oClosed and not pClosed)
							or (objType == prevType and oClosed == pClosed and prev.skill and not skill)
						if bossDoor and not prev.boss then
							-- the boss door wins its own tile outright, and never as a
							-- doorway: nothing may click it
							prev.obj, prev.Candidate, prev.boss = o, nil, true
							prev.outsideRoom, prev.key = not mine, nil
						elseif better then
							prev.obj, prev.Candidate = o, Candidate
							prev.outsideRoom, prev.key = not mine, keyMissing
							prev.closed = oClosed
						end
						prev.skill = prev.skill or skill
					end
				end
			end
		end
	end
	for _, d in ipairs(all) do
		-- A skill door is never paired: the prop disappears when the skill is used and a
		-- plain doorway is left behind, so the answer is false by definition and the
		-- search would only walk every prop on the map to say so. A boss door is not a
		-- doorway at all (see D.isBossDoor) - it is never paired either.
		d.Pair = (not d.skill and not d.boss) and D.SearchPairs(world, d.obj)--paired doorway
	end
	-- THE PASSAGE TO THE BOSS. The boss door marker stands inside the boss room and the
	-- doorway it belongs to is an ordinary doorway of some kind, so the marker names it:
	-- any doorway within D.BOSS_PASSAGE_R of a boss door record is flagged, whatever kind
	-- of door it is. The flag is what the dot pass draws gold once that doorway is OPEN -
	-- the marker alone says "the boss room is there", the pair says "this is the way in".
	local bossMarks = {}
	for _, d in ipairs(all) do
		if d.boss then bossMarks[#bossMarks + 1] = d end
	end
	if #bossMarks > 0 then
		for _, d in ipairs(all) do
			if not d.boss then
				for _, b in ipairs(bossMarks) do
					if math.max(math.abs(d.x - b.x), math.abs(d.y - b.y)) <= D.BOSS_PASSAGE_R then
						d.bossPassage = true
						break
					end
				end
			end
		end
	end
	return all
end

-- world.doors stays this room's own doorways - the list D.doorBetween and the puzzle
-- solvers read, where one record from the room next door would be a walk through a wall.
-- The whole map's list comes back second, for the dots only.
function D.roomDoors(world, px, py)
	local all = D.doorRecords(world, px, py)
	local doors = {}
	for _, d in ipairs(all) do
		if not d.outsideRoom then doors[#doors + 1] = d end
	end
	return doors, all
end

-- What a doorway record is, and the action to send. nil = not a doorway.
function D.doorKindOf(world, o, held, unknown)
	local act = D.objGet(o, 'Action')
	if type(act) ~= 'string' or act == '' then return nil end
	local raw = D.objName(o)

	--guardian doors
	if string.find(raw, 'Guardian door', 1, true) then return true end

	--key doors, unopened needs key
	if act == 'Unlock' then--only front matters for unlocking
		local keyItem = D.doorKeyFromName(raw)
		if keyItem then
			if D.SearchPairs(world, o, raw) then
				return true
			end
		end
	end

	--key doors, opened
	if act == 'Enter' then
		local keyItem = D.doorKeyFromName(raw)
		if keyItem then
			if not D.SearchPairs(world, o, raw) then
				return true
			end	
		end
	end

	if D.skillDoorMatch(raw, act) then return true end--the skill door: its own option unlocks it

	--normal doors
	if D.doorKind[D.objGet(o, 'Id')] then--can only properly identify normal doors by id
		return true
	end
	-- A NORMAL DOOR THE ID TABLES DO NOT KNOW. Live: tile 11503,2984 is blocked by the
	-- type 0 object 17162 "Door" (solid_mem points at it) which offers "Enter", but 17162
	-- is in no id table - while the DECOR back face 50344 standing on the same tile IS in
	-- D.DOOR_BACK. So the only candidate was the decoration, the route clicked that for
	-- ever and the doorway never opened. A prop whose name says door and whose option is a
	-- plain doorway action is a doorway whatever its id.
	if D.PLAIN_DOOR_ACTS[act] and string.find(string.lower(raw), 'door', 1, true) then
		return true
	end
	return nil
end

-- The wall a doorway stands on, seen from the player: 1 north, 2 east, 3 south, 4 west.
function D.doorWallOf(px, py, x, y)
	local dx, dy = x - px, y - py
	if math.abs(dx) > math.abs(dy) then return dx > 0 and 2 or 4 end
	return dy > 0 and 1 or 3
end

-- The tile beside a doorway on our side of it: one step from the door toward the player.
function D.doorSide(x, y, px, py)
	local dx, dy = px - x, py - y
	if math.abs(dx) > math.abs(dy) then return x + (dx > 0 and 1 or -1), y end
	return x, y + (dy > 0 and 1 or -1)
end

-- How long a dot stays on the floor. The engine needs a number here: a nil `fortime`
-- is not "forever", it is an exception out of the native MarkTiles.
--
-- DOTS ARE NO LONGER WIPED EVERY PASS. A blanket ClearMarkTiles used to run at the top
-- of every iteration, so every dot a pass did not reach - a solver that took the room, an
-- enemy fight, a key pickup, a doorway click that sits in D.waitAnim - blinked off the
-- floor until the next stamp, and the grid looked like it was being erased and redrawn.
-- A stamp now simply lives out its own life and the next pass refreshes it, so only the
-- tiles that STOP being stamped go away (a doorway that opened, a room we left). The
-- value is the gap between two stamps of the same tile: an idle pass is ~0.5 s, a pass
-- spent clicking a doorway or waiting an animation is several seconds, so this has to be
-- comfortably longer than a slow pass or the dots flicker anyway.
D.MAPDOT_MS = 8000

function D.stampDots(list, colour, size, shape)
	if not (list and #list > 0) then return end
	-- Dots are decoration. The engine refuses a tile it cannot project - a prop that has
	-- been removed, a tile that is no longer loaded - by throwing out of MarkTiles, and
	-- that used to end the run. Nothing worth a run happens here.
	local ok = pcall(API.MarkTiles, list, D.MAPDOT_MS, colour, 1, true, shape,
		FFPOINT.new(size, size, 0), FFPOINT.new(0, 0, 0))
	if not ok then
		local key = tostring(colour) .. ':' .. tostring(size)
		D.dotFail = D.dotFail or {}
		if not D.dotFail[key] then
			D.dotFail[key] = true
			log(string.format('mark tiles: the engine refused %d dot(s) in colour %s - not stamping that shape again',
				#list, tostring(colour)))
		end
	end
end

-- THE CENTRE OF EVERY ROOM ON THE FLOOR, as a tile. Orientation only: this is not a
-- door, it is not a target and nothing reads it back, so no door dot moves because of
-- it - D.roomCentreDots only ever returns the tiles it drew.
--
-- The lattice comes from the region the player stands in (a 4x4 floor is one 64x64
-- region, see D.ROOM_CELL) and a cell's centre is half a cell from its wall
-- (D.ROOM_CENTRE, a float). A layout cell with no floor on it is not a room, and a dot on
-- a tile the floor does not carry is a tile the engine refuses, so only cells that own
-- floor are stamped.
function D.roomCentreDots(world, px, py)
	local lay = D.LAYOUT[D.layout or 1] or D.LAYOUT[1]
	local nx, ny = lay[1], lay[2]
	local bx = math.floor(px / 64) * 64
	local by = math.floor(py / 64) * 64
	local walk = (world and world.walk) or {}
	local list, rooms = {}, 0
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			local cx = bx + i * D.ROOM_CELL + D.ROOM_CENTRE
			local cy = by + j * D.ROOM_CELL + D.ROOM_CENTRE
			-- the floor probe is on whole tiles (the walk set is keyed by them), and +-2
			-- stays inside this cell's 14-tile interior, so a prop parked on the centre
			-- still finds the room's own floor and cannot borrow a neighbour's
			local mx, my = math.floor(cx), math.floor(cy)
			local has = false
			for dx = -2, 2 do
				for dy = -2, 2 do
					if walk[pkey(mx + dx, my + dy)] then has = true end
				end
			end
			if has then
				rooms = rooms + 1
				-- the purple dot is the ONLY dot that is centred: it goes on the cell's
				-- true middle (a float), while the door dots keep their own tile
				-- coordinates exactly as they were
				list[#list + 1] = FFPOINT.new(cx, cy, 0)
			end
		end
	end
	return list, rooms, nx * ny
end

D.DOOR_WALL = { 'north', 'east', 'south', 'west' }   -- clockwise, 1..4
-- A clicked doorway takes a tick or two to change: a mined prop disappears, a key door
-- swaps to its open leaf, the leaves swap from "Open" to "Enter". The next scan can still
-- see it half opened and a second click lands on nothing - so no door is clicked at all
-- for this long after one was.
D.DOOR_CLICK_COOLDOWN = 2500
D.doorClickedAt = 0
-- How long the doorway is given to play its action out before the pass carries on.
D.DOOR_CLICK_WAIT = 900
D.DOOR_CLICK_WAIT2 = 400
D.DOOR_ANIM_WAIT = 3000   -- cap for D.waitAnim: mining/unlocking animation

-- THE WORK THE DOTS DESCRIBE: open this room's own doorways.
--
-- What is left after the room's puzzles, keys and enemies are done is the way out, so
-- every green dot is clicked, each with its own option - a skill prop with 'Mine',
-- 'Chop down', 'Repair'..., a key door with 'Unlock', a plain door with 'Open'. Only
-- these are left alone:
--   paired - D.SearchPairs found the other leaf, so that doorway is already open (the
--            red dot) and there is nothing left to click
--   key    - an unopened key door whose key the ring does not hold (`key == true`, the
--            blue dot); with the key (`false`) the Unlock option is sent like any other
--   outside- a doorway outside the room's range (the white dot) is not this room's exit
-- A doorway whose own tile is already floor (world.walk) is open too, however it is
-- paired, so it is skipped by the same rule the doorway predicates use.
-- A DoAction_Object_Direct is fire-and-forget: the engine takes the click whether or not
-- it can do anything with it, so the answer says nothing about the door. That is why the
-- only rate limiting here is time - the cooldown above, D.clickAllowed's per-tile budget,
-- and D.unlockInFlight for a key turn that is still on its way - and not "it was clicked,
-- so do not try again".
-- One doorway per pass, nearest first.
-- CROSSING A TIGHTROPE IS A DOORWAY-SHAPED ACTION, NOT A PUZZLE STEP.
--
-- The rope is a pair of walkable tiles that are one click apart (D.walkPairs), so the walk
-- model can tell that the far half of the room is reachable - but the engine will not walk
-- across a chasm, so the click has to be made here, by whoever wants the other side. One
-- click, the same cooldown a doorway click takes, and nothing remembered afterwards: the
-- next pass simply sees the player standing somewhere else, which is what makes crossing
-- BACK work without a flag.
function D.crossTightrope(pair, why, now)
	if not (pair and pair.obj) then return false end
	local act = pair.act ~= '' and pair.act or 'Walk-the'
	log(string.format('tightrope at %d,%d: crossing (%s "%s")%s',
		pair.x, pair.y, act, tostring(pair.name), why and (' - ' .. why) or ''))
	local ok = D.clickObject(act, pair.obj)
	if not ok then
		log(string.format('tightrope at %d,%d: %s refused - the click budget is spent',
			pair.x, pair.y, act))
		return false
	end
	-- the cooldown at the top of the door task is what stops the rope being clicked twice
	-- while the crossing is still landing. The route has its own cooldown on the doorway
	-- it just aimed at, so that is stamped as well - otherwise the next pass re-clicks the
	-- far-side doorway before the crossing lands and earns "You can't reach that".
	D.doorClickedAt = now or API.SystemTime()
	D.doorStep = nil
	D.routeClicked, D.routeClickedAt = pkey(pair.x, pair.y), D.doorClickedAt
	API.RandomSleep2(D.DOOR_CLICK_WAIT, D.DOOR_CLICK_WAIT2, D.DOOR_CLICK_WAIT2)
	D.waitAnim(D.DOOR_ANIM_WAIT)
	return true
end

-- Does this room still owe us the half on the other side of its rope? The doorway over
-- there is `outsideRoom` for the blob we are standing in, so it can never become the door
-- task's `best` - which is exactly why the crossing is decided here instead. Only a
-- doorway the walk could reach THROUGH the rope counts (that is what D.walkNeedsCross
-- answers), so a door in another room can never make the bot cross.
-- Does this room still owe us the half on the other side of its rope? The doorway over
-- there is `outsideRoom` for the blob we are standing in, so it can never become the door
-- task's `best` - which is exactly why the crossing is decided here instead. Only a
-- doorway in THIS room cell, on the far side of the pair, counts (see D.walkNeedsCross),
-- so a door in another room can never make the bot cross.
function D.walkCrossingWork(world)
	if not (D.walkPairs and D.walkNeedsCross) then return false end
	local pairs = D.walkPairs(world)
	if #pairs == 0 then return false end
	local px, py = ptile()
	local walk = (world and world.walk) or {}
	for _, d in ipairs((world and (world.doorDots or world.doors)) or {}) do
		if not d.boss and d.Candidate and not d.Pair and d.key ~= true
			and not walk[pkey(d.x, d.y)]
			and not (D.traversed and D.traversed[dkey(d)]) then
			local pair = D.walkNeedsCross(world, px, py, d.x, d.y, pairs)
			if pair then
				return D.crossTightrope(pair,
					string.format('the doorway at %d,%d is on the other side', d.x, d.y))
			end
		end
	end
	-- A KEY ON THE OTHER HALF IS THE SAME KIND OF WORK. The loot step only takes keys the
	-- client can path to, so a key across the chasm is logged as "far", never enters
	-- NeededTOReach_KEYS_local, and the room sits holding a key the bot can see and never
	-- fetches. D.floorKeys already drops the ones the ring holds, so nothing is crossed for
	-- a key we already have.
	if D.floorKeys then
		for _, k in ipairs(D.floorKeys(px, py)) do
			local pair = D.walkNeedsCross(world, px, py, k.x, k.y, pairs)
			if pair then
				return D.crossTightrope(pair,
					string.format('the key at %d,%d is on the other side', k.x, k.y))
			end
		end
	end
	return false
end

function D.openLocalDoors(world, px, py)
	local doors = (world and (world.doorDots or world.doors)) or {}
	local now = API.SystemTime()
	-- NEVER WALK OUT OF A BOSS FIGHT. While the player is standing in a live boss's room this
	-- task stands down: its click walks the player THROUGH the doorway, and the way out of
	-- the arena is exactly the "it walked to the front of the room and left" failure. Only the
	-- player's own room counts - a boss seen through the closed door of the next room must
	-- still let the passage be opened (see D.bossArenaHot).
	if D.bossArenaHot and D.bossArenaHot(px, py) then
		API.RandomSleep2(300, 150, 250)
		return false
	end
	-- the doorway clicked last pass is still changing - leave the whole door set alone
	if (now - (D.doorClickedAt or 0)) < D.DOOR_CLICK_COOLDOWN then return false end
	-- CROSS THE TIGHTROPE FIRST when the room still owes us a doorway on the other side
	-- of it. This has to run BEFORE the nearest-door choice below: the doorway over there
	-- is `outsideRoom` for the blob we are standing in, so it can never be `best`, and the
	-- near half's own doors would keep winning every pass while the far half stayed shut
	-- (live: the bot opened the west doorway, walked out of the room and never came back
	-- for the guardian doorway beyond the chasm).
	-- Only a doorway the walk could reach THROUGH the rope counts (see D.walkNeedsCross),
	-- so a door in another room can never make the bot cross, and once both halves are
	-- open there is nothing left to trigger it.
	if D.walkCrossingWork and D.walkCrossingWork(world) then return true end
	local best, bestDist = nil, nil
	for _, d in ipairs(doors) do
		if d.Candidate and not d.Pair and not d.boss
			and d.key ~= true and not d.outsideRoom
			and not (world.walk and world.walk[pkey(d.x, d.y)])
			and not D.unlockInFlight(d) then
			local dist = math.max(math.abs(d.x - px), math.abs(d.y - py))
			if not bestDist or dist < bestDist then best, bestDist = d, dist end
		end
	end
	if not best then return false end
	local act = D.objGet(best.obj, 'Action')
	local clicked = D.clickObject(act, best.obj)
	if not clicked then
		log(string.format('door %d,%d: %s refused - the click budget is spent',
			best.x, best.y, tostring(act)))
		return false
	end
	-- The click on a doorway walks the player THROUGH it. The tile we open it from is
	-- remembered so D.doorStay can put us back on the room's side of it.
	local stepx, stepy = D.doorSide(best.x, best.y, px, py)
	D.doorStep = { x = stepx, y = stepy }
	D.doorClickedAt = now
	log(string.format('door %d,%d: opening (%s)', best.x, best.y, tostring(act)))
	-- Give the action time to land before anything looks at the doorway again: the
	-- prop has to disappear / swap leaves, and a scan inside that window sees it half
	-- opened. The wait is on top of D.waitAnim, which is what actually waits out the
	-- mining/unlocking animation the click started.
	API.RandomSleep2(D.DOOR_CLICK_WAIT, D.DOOR_CLICK_WAIT2, D.DOOR_CLICK_WAIT2)
	D.waitAnim(D.DOOR_ANIM_WAIT)
	return true
end

function D.openRoomDoor(world, px, py)
	local dotslistdots = {}
	local doorlinkdots = {}
	local outsidedots = {}
	local weddonthavekeysdots = {}
	local bossdots = {}
	local bosspassdots = {}
	-- Every doorway the map carries, not just this room's: the dots are the floor's
	-- doorways, wherever they stand. The record's remarks say which is which -
	-- `outsideRoom` for the room's range, `key` (nil / true / false) for the key ring.
	local doors = (world and (world.doorDots or world.doors)) or {}
	-- A skill prop stands in a doorway: the prop is what gets clicked, and the door behind
	-- it cannot be used until the skill lands. So the prop gets ONE green dot (and the
	-- white out-of-range dot under it when it is out of reach) while the doorway tile
	-- beside it is left dark - the same "one dot per doorway that can be used" the key
	-- doors get (D.doorKindOf drops a key door's back leaf when it answers paired).
	-- A skill prop never gets a red or blue dot: it has no pair and no key.
	local skillTiles = {}
	for _, d in ipairs(doors) do
		if d.skill then
			local sx, sy = D.objTile(d.obj)
			if sx then
				skillTiles[#skillTiles + 1] = { x = math.floor(sx), y = math.floor(sy) }
			end
		end
	end
	local function hiddenBySkill(x, y)
		for i = 1, #skillTiles do
			local s = skillTiles[i]
			if math.abs(s.x - x) <= 1 and math.abs(s.y - y) <= 1 then return true end
		end
		return false
	end
	local outside, noKey, bossDoors, bossPassage = 0, 0, 0, 0
	for _, d in ipairs(doors) do
		if d.outsideRoom then outside = outside + 1 end
		if d.key then noKey = noKey + 1 end
		if d.boss then bossDoors = bossDoors + 1 end
		if d.bossPassage then bossPassage = bossPassage + 1 end
	end
	-- One line per change, not one per pass: this runs about once a second. The boss
	-- counts are here on purpose: the boss door only exists in the client once the floor is
	-- finished and the boss room is open, so "0 boss door(s)" is the normal state until
	-- the last room is done, and this line is where that changes. The passage count is the
	-- doorway (and its pair's back leaf) standing in front of that marker. `remembered` is
	-- appended when the gold came out of D.bossDoorMem instead of the live scan.
	local remark = #doors .. '/' .. outside .. '/' .. noKey .. '/' .. #skillTiles .. '/'
		.. bossDoors .. '/' .. bossPassage

	--possible data are from D.doorRecords: obj, Candidate, Pair, outsideRoom, key, skill, boss, bossPassage
	-- THE BOSS MARKER IS REMEMBERED. The pass's prop sweep only carries what the client has
	-- streamed in, so the gold disappeared the moment the player walked far enough away -
	-- and "where is the boss room" is the last thing that should need a walk back. The tile
	-- is written down here (plain numbers: an engine record belongs to the scan that made
	-- it) and stamped from memory for the rest of the floor.
	local liveBoss, livePass = {}, {}
	D.bossPassageMem = D.bossPassageMem or {}
	for _, d in ipairs(doors) do
		-- D.objTile is the protected read (pcall + NaN guard): touching Tile_XYZ on a
		-- record that is being removed throws out of the userdata's metamethod
		local x, y = D.objTile(d.obj)
		if x and y then
			x, y = math.floor(x), math.floor(y)
			if d.boss then
				-- the boss door: its own colour, its own size, and no other dot on that
				-- tile - it is not a doorway to open, it is the way into the boss room
				bossdots[#bossdots + 1] = FFPOINT.new(x, y, 0)
				local k = pkey(x, y)
				liveBoss[k] = true
				D.bossDoorMem = { x = x, y = y, id = tonumber(D.objGet(d.obj, 'Id')),
					at = API.SystemTime() }
			else
				-- THE PASSAGE TO THE BOSS is the doorway in front of the marker, whatever
				-- kind of door it is - live: an "Orange corner door" one tile from the
				-- "Boss door" decor, with its own back leaf another tile on (the same pair
				-- shape every other doorway has). It is gold whether it is open or shut:
				-- gold says "this leads to the boss", and its ordinary colour is stamped
				-- underneath so the door task still reads it like any other doorway.
				if d.bossPassage then
					bosspassdots[#bosspassdots + 1] = FFPOINT.new(x, y, 0)
					local k = pkey(x, y)
					livePass[k] = true
					D.bossPassageMem[k] = { x = x, y = y, at = API.SystemTime() }
				end
				if d.skill then
					-- the skill prop itself: one green dot, and the white out-of-range dot
					-- under it when the prop stands outside the room's range - exactly the
					-- pair any other doorway gets, just without red or blue
					local t = FFPOINT.new(x, y, 0)
					dotslistdots[#dotslistdots + 1] = t
					if d.outsideRoom then
						outsidedots[#outsidedots + 1] = t
					end
				elseif not hiddenBySkill(x, y) then
					local t = FFPOINT.new(x, y, 0)
					if d.Candidate then
						dotslistdots[#dotslistdots + 1] = t
						if d.outsideRoom then
							outsidedots[#outsidedots + 1] = t
						end
					end
					if d.Pair then
						doorlinkdots[#doorlinkdots + 1] = t
						if d.outsideRoom then
							outsidedots[#outsidedots + 1] = t
						end
					end
					if d.key then
						weddonthavekeysdots[#weddonthavekeysdots + 1] = t
					end
				end
			end
		end
	end
	-- NOTHING STREAMED IN: draw the marker and the passage from memory, in the same colour
	-- and at the same sizes, so "where is the boss room" survives a walk to the far end of
	-- the floor. Only tiles the live scan did not already cover are added.
	local remembered = false
	if D.bossDoorMem and not liveBoss[pkey(D.bossDoorMem.x, D.bossDoorMem.y)] then
		bossdots[#bossdots + 1] = FFPOINT.new(D.bossDoorMem.x, D.bossDoorMem.y, 0)
		bossDoors = bossDoors + 1
		remembered = true
	end
	for k, t in pairs(D.bossPassageMem or {}) do
		if not livePass[k] then
			bosspassdots[#bosspassdots + 1] = FFPOINT.new(t.x, t.y, 0)
			bossPassage = bossPassage + 1
			remembered = true
		end
	end
	remark = remark .. (remembered and '/r' or '')
	if D.doorDotRemark ~= remark then
		D.doorDotRemark = remark
		log(string.format('door dots: %d door(s) on the map, %d outside the room range, %d without their key, %d skill doorway(s) green only, %d boss door(s) gold, %d boss passage(s) gold%s',
			#doors, outside, noKey, #skillTiles, bossDoors, bossPassage,
			remembered and ' (remembered)' or ''))
	end
	--this will be future of pathbuilding
	D.stampDots(weddonthavekeysdots, 0x0000FF, 22 , true)-- doors we dont have keys for, if we have then it is green
	D.stampDots(outsidedots, 0xFFFFFF, 18 , true)-- doors outside the room range aka out of click range
	D.stampDots(doorlinkdots, 0xFF0000, 14 , false)-- doorlink aka doorway, used to traverse to the next room
	D.stampDots(dotslistdots, 0x00FF00, 8, true)-- unlockable door if not outside then fine to click
	D.stampDots(bossdots, 0xFFD700, 24, true)-- the boss door: gold, biggest, and never clicked by the door task
	D.stampDots(bosspassdots, 0xFFD700, 20, true)-- the open doorway in front of it: gold too, the way into the boss room
	-- nothing local is left to do, so the doorways are the work now
	return D.openLocalDoors(world, px, py)
end

--------------------------------------------------------------------
-- GLOBAL ROUTING: the next room worth walking to, and the doorway that gets there
--------------------------------------------------------------------
-- The floor is a lattice of rooms joined by doorways, so the route is a BFS over ROOMS -
-- one hop per doorway. Nothing here walks tiles: a doorway is clicked from its NEAR face,
-- the record D.doorRecords marked `outsideRoom == false` (the leaf standing in the room the
-- player is in), and that click is what moves the player through it.
--
-- It only runs where the pass has no local work left: enemies, food, the room's own puzzle
-- and its own doorways all come first, and a solver holding the room never gets this far.
--
-- PRIORITY - the best task first, then the nearest room that has it:
--   1. a room with an unopened doorway on it (the green dot) - that is how a floor opens
--   2. a room with a LIVE puzzle prop in it
--   3. the boss room, from the boss door marker - last, only when nothing else is left
-- There is deliberately no "walk into unexplored rooms" entry: the bot sees every loaded
-- prop on the floor from where it stands, so a room is worth walking to only when the scan
-- says it holds a task. Visiting rooms to find out what is in them is what sent it into a
-- toxin maze that had been solved hours earlier.
local function ckey(i, j) return i .. ':' .. j end

-- WHAT COUNTS AS A PUZZLE ROOM. This used to be a list of words in the prop's name, and
-- "Barrel", "Bridge", "Statue", "Lever" and even "Locked chest" are ordinary scenery in
-- half the rooms on a floor - so every room looked like a puzzle room and the router
-- ping-ponged between two of them ("why is this room a goal?"). An ID belongs to exactly
-- one thing, so the sets come from the puzzle module's own tables, and only the props whose
-- ids drift between floors keep a NAME test - and only the names no ordinary room has.
D.ROUTE_PUZZLE_NAMES = { 'barrier', 'pedestal', 'monolith', 'sphinx', 'geyser',
	'divine', 'crystal' }
-- every id set / id array the puzzle solvers carry, by their name on D
D.ROUTE_PUZZLE_TABLES = {
	'MAZE_CHESTS', 'MAZE_BARRIERS', 'MAZE_PEDESTALS',
	'GHOST_COFFIN_IDS', 'GHOST_OPEN_IDS', 'GHOST_WALL_IDS', 'GHOST_BOX_IDS', 'GHOST_POT_IDS',
	'COLLAPSE_ROCK_IDS', 'COLLAPSE_FIX_IDS',
	'BRIDGE_ROCK_IDS', 'BRIDGE_FIX_IDS', 'BRIDGE_AGILE_IDS', 'BRIDGE_WOODBOX_IDS',
	'BARREL_IDS', 'BARREL_FIX_IDS', 'BARREL_FIXED_IDS',
	'FERRET_IDS', 'FLIP_IDS', 'PONDSKATER_IDS', 'LODESTONE_IDS', 'LEADER_IDS',
	-- Fremennik camp: three crates that each offer a skill action
	'CAMP_CRATES',
}
function D.routePuzzleSet()
	if D.routePuzzleIds then return D.routePuzzleIds end
	local set = {}
	for _, name in ipairs(D.ROUTE_PUZZLE_TABLES) do
		for k, v in pairs(D[name] or {}) do
			-- { [11072] = true } is a map, { 12089, 12091 } is an array: take whichever
			-- side holds a number
			if type(v) == 'number' then
				set[v] = true
			elseif type(k) == 'number' then
				set[k] = true
			end
		end
	end
	D.routePuzzleIds = set
	return set
end

-- Is this prop a puzzle prop, and WHICH puzzle? One id lookup, or one of the few
-- unmistakable names - and it has to be LIVE WORK, not a prop the room is finished with.
--
-- The maze family is its own kind ('maze' / 'mazechest') because a beaten maze leaves props
-- behind: the pedestals the route never mined still offer "Mine" and still carry their ids,
-- so an id-only test called a finished room a puzzle room and the router walked back in. A
-- maze room is ONLY a maze while its centre chest is still live - that is the marker the
-- puzzle itself is identified by (D.mazeCentreChest).
function D.routePuzzleKind(o)
	local id = tonumber(D.objGet(o, 'Id'))
	local b1 = tonumber(D.objGet(o, 'Bool1')) or 0
	local act = D.objGet(o, 'Action')
	if type(act) ~= 'string' then act = '' end
	if D.MAZE_CHESTS and id and D.MAZE_CHESTS[id] then
		return b1 == 0 and 'mazechest' or nil
	end
	if D.MAZE_BARRIERS and id and D.MAZE_BARRIERS[id] then
		return act == 'Go-through' and 'maze' or nil
	end
	if D.MAZE_PEDESTALS and id and D.MAZE_PEDESTALS[id] then
		return act == 'Mine' and 'maze' or nil
	end
	if b1 == 1 then return nil end          -- spent / disabled / solid: not work
	if id and D.routePuzzleSet()[id] then return 'other' end
	local nm = string.lower(D.objName(o) or '')
	if nm == '' then return nil end
	-- the props whose ids drift between floors: the option is what makes them work
	if string.find(nm, 'pedestal', 1, true) then return act == 'Mine' and 'maze' or nil end
	if string.find(nm, 'barrier', 1, true) then return act == 'Go-through' and 'maze' or nil end
	for i = 1, #D.ROUTE_PUZZLE_NAMES do
		if string.find(nm, D.ROUTE_PUZZLE_NAMES[i], 1, true) then return 'other' end
	end
	return nil
end

function D.isRoutePuzzleProp(o)
	return D.routePuzzleKind(o) ~= nil
end

-- Has a solver already finished this room? S.pondState is the shared per-room record every
-- solver marks (`solved`), and the maze records its own finish. A solved room is not a
-- puzzle goal and not "unexplored" - there is nothing there to walk to.
function D.routeRoomSolved(k, px, py)
	local si, sj = string.match(k, '^(%-?%d+):(%-?%d+)$')
	if not si then return false end
	local key = (math.floor(px / 64) * 64 + tonumber(si) * D.ROOM_CELL + 1) .. ':'
		.. (math.floor(py / 64) * 64 + tonumber(sj) * D.ROOM_CELL + 1)
	local st = S.pondState and S.pondState[key]
	if st and st.solved then return true end
	if D.mazeRoomDone and D.mazeRoomDone == key then return true end
	return false
end
D.routeVisited = {}      -- room key -> true once we have stood in it, this floor
D.routeGoal = nil        -- the room key we are heading for (the marked one)
D.ROUTE_MAX_HOPS = 6
D.ROUTE_IDLE_LOG = 30000 -- "no goal room" is worth a line every 30 s, never a silent stall

-- The two rooms a doorway joins. The doorway stands IN a wall, and a wall between two rooms
-- is two tiles thick (each room carries its own), so the floor is looked for up to three
-- tiles out on each axis - stepping out one tile finds the opposite room's wall, not its
-- floor, which is why a shut doorway read as "joins one room" and no route was ever found.
function D.doorRooms(world, d)
	local walk = (world and world.walk) or {}
	local a, b = nil, nil
	for i = 1, 4 do
		local s = D.DIR4[i]
		local hx, hy = nil, nil
		for r = 1, 3 do
			local nx, ny = d.x + s[1] * r, d.y + s[2] * r
			if walk[pkey(nx, ny)] then
				hx, hy = nx, ny
				break
			end
		end
		if hx then
			local _, _, ci, cj = D.roomCellAt(hx, hy)
			local k = ckey(ci, cj)
			if not a then
				a = k
			elseif k ~= a then
				b = k
				break
			end
		end
	end
	if a and b then return a, b end
	-- THE TWO CELLS THE DOORWAY STANDS BETWEEN, read from the TILE GRID instead of the
	-- walk set. `world.walk` is the LOADED room's floor, so a doorway on that room's edge
	-- resolved to one side only and D.roomRoute had no edge to cross - live: "one step
	-- closer and pathing starts, one step back and it stops". The four tiles around the
	-- doorway are in the layout cells whatever has been cached.
	local seen, order = {}, {}
	for i = 1, 4 do
		local s = D.DIR4[i]
		local _, _, ci, cj = D.roomCellAt(d.x + s[1], d.y + s[2])
		if ci and cj then
			local k = ckey(ci, cj)
			if not seen[k] then
				seen[k] = true
				order[#order + 1] = k
			end
		end
	end
	if not a and order[1] then a = order[1] end
	if not b then
		for i = 1, #order do
			if order[i] ~= a then b = order[i] break end
		end
	end
	return a, b
end

-- Can a route cross this doorway? A doorway whose tile is walkable is open; anything else
-- has to be opened by us, which rules out the doors we cannot open - a key door whose key
-- is not on the ring, and a boss door. A SKILL DOOR IS CROSSABLE: it is worked like any
-- other door (D.SKILL_TRIES clicks of its own option), and refusing it here meant a room
-- behind a "Fix-pulley" door was unreachable in the plan - the dot was green and the bot
-- never walked to it. A paired doorway (`Pair`, the red dot) is a doorway that already
-- has both its faces, i.e. it is already open, so it is a corridor like any other.
function D.doorRoutable(world, d)
	if d.boss then return false end
	if d.key == true then return false end
	if world.walk and world.walk[pkey(d.x, d.y)] then return true end
	return (d.Candidate or d.Pair) and true or false
end

-- BFS over rooms: dist[room] = doorways crossed, prev[room] = { from, door }.
function D.roomRoute(world, startKey)
	local doors = (world and (world.doorDots or world.doors)) or {}
	local dist, prev = { [startKey] = 0 }, {}
	local q, head = { startKey }, 1
	while head <= #q do
		local cur = q[head]
		head = head + 1
		for _, d in ipairs(doors) do
			if D.doorRoutable(world, d) then
				local a, b = D.doorRooms(world, d)
				local to = nil
				if a and b then
					if a == cur then to = b elseif b == cur then to = a end
				end
				if to and dist[to] == nil then
					dist[to] = dist[cur] + 1
					prev[to] = { from = cur, door = d }
					q[#q + 1] = to
				end
			end
		end
	end
	return dist, prev
end

-- What each room holds, for the priority above. Cheap: the pass's own prop list and door
-- records, one walk over each, only when a route is actually being decided.
function D.roomFacts(world, px, py)
	local facts = {}
	local bx = math.floor(px / 64) * 64
	local by = math.floor(py / 64) * 64
	local function slotKey(k)
		local f = facts[k]
		if not f then
			local si, sj = string.match(k, '^(%-?%d+):(%-?%d+)$')
			si, sj = tonumber(si), tonumber(sj)
			if not si then return nil end
			-- roomKey, NOT key: `key` is the flag for "a key is lying on this room's floor"
			-- (set below from D.keyRooms), and the two collided - every room with a facts
			-- entry carries this string, so `f.key` was truthy for the whole floor and the
			-- route called every room "priority 2 key on the floor".
			f = { roomKey = k, i = si, j = sj,
				cx = bx + si * D.ROOM_CELL + D.ROOM_CENTRE,
				cy = by + sj * D.ROOM_CELL + D.ROOM_CENTRE }
			facts[k] = f
		end
		return f
	end
	local function slot(x, y)
		local _, _, i, j = D.roomCellAt(x, y)
		return slotKey(ckey(i, j))
	end
	for _, d in ipairs((world and (world.doorDots or world.doors)) or {}) do
		-- a doorway that still has to be opened is work in the room on either side of it:
		-- from one side we walk up to it, from the other we have just come through it.
		-- A SKILL DOOR COUNTS - it is opened by working its own option, so the room it
		-- stands in is worth routing to (without this the green dot was drawn and the
		-- router never sent the player near it).
		if not d.boss and d.Candidate and not d.Pair and d.key ~= true
			and not (world.walk and world.walk[pkey(d.x, d.y)]) then
			local a, b = D.doorRooms(world, d)
			if a then slotKey(a).door = true end
			if b then slotKey(b).door = true end
		end
	end
	for _, o in ipairs((world and world.objs) or {}) do
		local kind = D.routePuzzleKind(o)
		if kind then
			local ox, oy = D.objTile(o)
			if ox then
				local f = slot(math.floor(ox), math.floor(oy))
				if kind == 'mazechest' then
					f.mazeChest = true
				elseif kind == 'maze' then
					f.mazeProp = true
				else
					f.puzzle = true
				end
			end
		end
	end
	-- A BEATEN MAZE IS NOT A PUZZLE ROOM. Its unmined pedestals and its barriers keep their
	-- ids and their options long after the chest was looted, so a maze prop only counts when
	-- the room's centre chest is still live - the chest is the maze, exactly as
	-- D.mazeCentreChest decides it for the solver.
	for _, f in pairs(facts) do
		if f.mazeChest then
			f.puzzle = true
		elseif f.mazeProp then
			f.mazeProp = nil
		end
	end
	-- A KEY ON THIS ROOM'S FLOOR THAT THE RING DOES NOT HOLD is work in its own right.
	-- D.keyRooms is built once per pass from the client's own path test (D.floorKeys, no
	-- distance cap), so this is the GLOBAL key task: a key two rooms away is a room the
	-- route will walk to, instead of a key door that sits shut for the rest of the floor.
	for k in pairs(D.keyRooms or {}) do
		local f = slotKey(k)
		if f then f.hasKey = true end
	end
	return facts
end

-- The room the boss door stands in, from the live marker or the remembered one.
function D.bossRoomKey(px, py)
	local m = D.bossDoorMem
	if not m then return nil end
	local _, _, i, j = D.roomCellAt(m.x, m.y)
	return ckey(i, j)
end

-- One step: pick the goal room, mark it, and click the near-face doorway of the first hop.
-- Returns true when a doorway was clicked (the caller waits out the walk).
function D.routeStep(world, here, px, py)
	if not (world and world.walk) then return false end
	-- NEVER ROUTE AWAY FROM A LIVE BOSS. While a boss is in sight the fight owns the
	-- floor: the router picking a doorway is how the bot walked out of Stomp's arena at
	-- 19:58:47 (after a pace click had already thrown it 42 tiles across the map) and then
	-- spent the rest of the run two rooms away from a boss at full health. The stamp is
	-- fresh-only, so a boss seen once cannot freeze the route for the rest of the floor.
	local liveAt = tonumber(D.bossLiveAt) or 0
	if D.bossLive and (API.SystemTime() - liveAt) < 4000 then
		API.RandomSleep2(300, 150, 250)
		return false
	end
	local _, _, ci, cj = D.roomCellAt(px, py)
	local start = ckey(ci, cj)
	D.routeVisited[start] = true

	local dist, prev = D.roomRoute(world, start)
	local facts = D.roomFacts(world, px, py)
	local bossKey = D.bossRoomKey(px, py)

	-- NO STRAIGHT BACK INTO THE ROOM WE JUST LEFT. Live, the route alternated 2:2 <-> 3:2
	-- five times in a row (a key it could not pick up against a boss room goal) and the
	-- player just walked the same doorway both ways. A room left within D.RECROSS_MS is not
	-- a destination; once the timer is out it is fair game again.
	local now = API.SystemTime()
	if not D.routeHere or D.routeHere.key ~= start then
		D.routeLeft = D.routeHere
		D.routeHere = { key = start, at = now }
	end
	local justLeft = nil
	if D.routeLeft and D.routeHere and (now - (D.routeHere.at or 0)) < D.RECROSS_MS then
		justLeft = D.routeLeft.key
	end

	local best, bestPri, bestWhy, bestDist = nil, 99, nil, nil
	for k, d in pairs(dist) do
		local f = facts[k]
		-- A KEY ROOM IS WORTH A LONG WALK. Everything else has to be close by - a doorway
		-- one room over is a decision for this pass - but the key can be at the far end of
		-- the floor and the route is the only thing that can carry the bot there. With the
		-- plain cap, a floor whose keys sat 7+ doorways away logged "no goal room - 2 key
		-- room(s) known" for five minutes with the bot standing still (live 10:43-10:48,
		-- keys in 1:0 and 3:0, start 3:3). The cap is a hop count, not a distance, and a
		-- lattice room three cells away is often more than six doorway hops.
		local keyRoom = f and f.hasKey
		if k ~= start and (keyRoom or d <= D.ROUTE_MAX_HOPS) and k ~= justLeft then
			local pri, why = nil, nil
			local solved = D.routeRoomSolved(k, px, py)
			-- A ROOM IS A DESTINATION ONLY IF IT HOLDS A KNOWN TASK. The bot sees every
			-- loaded prop on the floor from where it stands, so "walk over there and have a
			-- look" is not a reason to go anywhere - it is how the route kept arriving in
			-- rooms that had nothing left in them (the finished toxin maze). The old
			-- "unexplored room" priority is gone on purpose.
			--
			-- THE KEY ROOM COMES FIRST. It used to sit under "unopened door", and a floor
			-- always has another openable doorway within ROUTE_MAX_HOPS, so the key room
			-- never won: the bot toured doorways for ever while the key it needed sat in a
			-- room it had already mapped (live: keys logged in 1:0/3:0/3:3 while the goal
			-- stayed "1 unopened door"). A key is progress - it is the only thing that opens
			-- some of those doors - and the route hops through doorways anyway, so walking
			-- it to the key room opens the doors on the way.
			if f and f.hasKey then
				-- a key we do not hold outranks everything but the boss: the doors it opens
				-- are usually the only thing standing between this room and the rest of the
				-- floor
				pri, why = 1, 'key on the floor'
			elseif f and f.door then
				pri, why = 2, 'unopened door'
			elseif f and f.puzzle and not solved then
				-- a puzzle in a room we already stood in is normally the local chain's work,
				-- but the router only gets the pass when nothing local is held, so a still
				-- live puzzle there means the solvers let it go - it is worth a look
				pri, why = 3, 'puzzle'
			elseif bossKey and k == bossKey then
				pri, why = 4, 'boss room'
			end
			if pri and (pri < bestPri or (pri == bestPri and d < bestDist)) then
				best, bestPri, bestWhy, bestDist = k, pri, why, d
			end
		end
	end
	-- nothing left anywhere: the floor is done as far as the route can see
	if not best then
		D.routeGoal = nil
		-- AND SAY SO. A silent "no goal" is indistinguishable from a stuck script: live, a
		-- floor stood still for two minutes with a key on the floor and nothing to route
		-- to, and the log said nothing at all. One line every D.ROUTE_IDLE_LOG ms.
		-- The key count alone was not enough to tell the two failures apart - "a key room
		-- we cannot reach" and "a key room 9 hops away" both read as "2 key room(s)
		-- known" - so the nearest one's hop count is printed next to it.
		local nowIdle = API.SystemTime()
		if not D.routeIdleAt or (nowIdle - D.routeIdleAt) > D.ROUTE_IDLE_LOG then
			D.routeIdleAt = nowIdle
			local keyRooms, keyBestD = 0, nil
			for k in pairs(D.keyRooms or {}) do
				keyRooms = keyRooms + 1
				local kd = dist[k]
				if kd and (not keyBestD or kd < keyBestD) then keyBestD = kd end
			end
			log(string.format('route: no goal room - %d key room(s) known (%s), %d doorway(s) on the map',
				keyRooms, keyBestD and (keyBestD .. ' hop(s) away') or 'none the room graph can reach',
				#((world and (world.doorDots or world.doors)) or {})))
		end
		return false
	end
	D.routeIdleAt = nil
	D.routeGoal = best
	-- the destination room: a big white square with the purple dot on top of it, on the
	-- room's centre tile. The centre comes from the room KEY, not from `facts`: a room
	-- chosen for being unexplored or for holding the boss marker has no facts entry, and
	-- the marker must be drawn for every goal, not only the ones a prop created.
	local si, sj = string.match(best, '^(%-?%d+):(%-?%d+)$')
	if si then
		local bx = math.floor(px / 64) * 64
		local by = math.floor(py / 64) * 64
		local t = FFPOINT.new(bx + tonumber(si) * D.ROOM_CELL + D.ROOM_CENTRE,
			by + tonumber(sj) * D.ROOM_CELL + D.ROOM_CENTRE, 0)
		D.stampDots({ t }, 0xFFFFFF, 24, true)
		D.stampDots({ t }, 0x800080, 8, true)
	end

	-- the first hop: walk the prev chain back until the room we are standing in
	local hop, guard = best, 0
	while prev[hop] and prev[hop].from ~= start and guard < 32 do
		hop = prev[hop].from
		guard = guard + 1
	end
	if not (prev[hop] and prev[hop].from == start) then return false end

	-- click the NEAR FACE of that doorway: `outsideRoom == false` is the record standing in
	-- the room we are in, and that is the only one the client accepts a click on. A record
	-- that is not `closed` is still clickable - a shut door reports Bool1 1 - so this only
	-- prefers a closed face when the tile offers both; D.doorRecords has already picked the
	-- door OBJECT over its decor back face (live: 17162 opened, 50344 did nothing).
	local click = nil
	for _, d in ipairs(world.doorDots or world.doors or {}) do
		if not d.outsideRoom and not d.boss then
			local a, b = D.doorRooms(world, d)
			local other = nil
			if a == start then other = b elseif b == start then other = a end
			if other == hop then
				if d.closed then
					click = d
					break
				end
				if not click then click = d end
			end
		end
	end
	if not click and not prev[hop].door.outsideRoom then click = prev[hop].door end
	if not click then
		log(string.format('route: room %s -> %s needs the doorway between them, none in this room',
			start, tostring(hop)))
		return false
	end
	if D.routeClicked and D.routeClicked == pkey(click.x, click.y)
		and (API.SystemTime() - (D.routeClickedAt or 0)) < D.DOOR_CLICK_COOLDOWN then
		return false
	end
	-- THE DOORWAY MAY BE BEHIND A TIGHTROPE. The route works on room cells, and both
	-- halves of a grapple room are the same cell - so the hop it picked can be on the
	-- far side of the rope, where the client answers "You can't reach that" (live 10:31:
	-- four clicks at 12448,1816 from the north half, then the doorway was written off).
	-- The pair says which side of the rope each is on, so the crossing is spent here and
	-- the doorway is clicked on the next pass, from the side the click works from.
	if D.walkNeedsCross then
		local pair = D.walkNeedsCross(world, px, py, click.x, click.y)
		if pair then
			return D.crossTightrope(pair,
				string.format('the route wants the doorway at %d,%d', click.x, click.y))
		end
	end
	local act = D.objGet(click.obj, 'Action')
	if not D.clickObject(act, click.obj) then return false end
	D.routeClicked, D.routeClickedAt = pkey(click.x, click.y), API.SystemTime()
	log(string.format('route: %s -> room %s (goal %s, priority %d %s) - clicking the doorway %d,%d (%s)',
		start, tostring(hop), tostring(best), bestPri, tostring(bestWhy), click.x, click.y, tostring(act)))
	API.RandomSleep2(D.DOOR_CLICK_WAIT, D.DOOR_CLICK_WAIT2, D.DOOR_CLICK_WAIT2)
	return true
end

-- The click that opens a doorway also walks the player THROUGH it, and the door task is
-- not a route to the next room. The doorway stays open - the next pass sees the floor and
-- skips that wall - and the player is put back on the room's side of it.
D.doorStep = nil
function D.doorStay(here)
	local step = D.doorStep
	if not step then return false end
	D.doorStep = nil
	local px, py = ptile()
	if here and D.tileInHere(here, px, py, 0) then return false end
	D.walkTile(step.x, step.y)
	return true
end

-- Is this tile part of the room? The walk set answers it when the tile is in it; a
-- tile that fell out of the blob - debris, a pad, the tile a prop stands on - is still
-- ours while it is inside the room box, which is why the box test carries slack.
function D.tileInHere(here, x, y, slack)
	if not (here and x and y) then return false end
	local fx, fy = math.floor(x), math.floor(y)
	if here.set and here.set[pkey(fx, fy)] then return true end
	slack = slack or 0
	return fx >= here.minx - slack and fx <= here.maxx + slack
		and fy >= here.miny - slack and fy <= here.maxy + slack
end

-- Reachability, asked of the client's own planner rather than modelled here.
function D.tileReachable(x, y, z, tol)
	if not x or not y then return false end
	local ok, res = pcall(API.StarPathReachable,
		FFPOINT.new(math.floor(x), math.floor(y), math.floor(z or 0)), true, tol or 0)
	return ok and res == true
end

-- The four orthogonal steps as { dx, dy }: north, east, south, west (+y is north, the
-- same order the maze's own table uses).
D.DIR4 = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }

-- Passed to API.ReadAllObjectsArray as "do not filter by path reach". The API turns a
-- nil into -1 anyway, so this changes nothing - it is here because a solver reading it
-- as a missing constant is a long afternoon.
D.NO_REACH = -1

-- THE OBJECT TYPES every prop scan asks for: game objects (0) and decoration (12). Both
-- are needed - a "Crumbling wall" in the statue room is decor (live id 49649, type 12),
-- while doors and most puzzle props are type 0. This was never defined, so seven scans in
-- puzzles.lua passed nil and the statue solver could never find the wall it was told to
-- mine.
D.OBJ_TYPES = { 0, 12 }

-- ... and the opposite: "the client must be able to path to within one tile of it". It
-- costs ONE client path find PER RECORD the scan returns, so it only ever belongs on a
-- call whose id/type list is already tiny. puzzles.lua's crystal solver used it for a
-- whole floor while this constant did not exist and the call silently read -1 (no filter
-- at all) - the comment there promised a reach filter that was not happening.
D.REACH_LOCAL = 1

-- ONE WALK OVER THE ROOM'S OWN FLOOR, from the player's tile: dist[key] = steps, key
-- from pkey. The tiles come from the pass's walk set (world.walk), so a wall, a prop
-- or a shut door is simply not in it.
--
-- Two tile families are refused on top of that, because both solvers that read this
-- are asking "can we get there WITHOUT crossing something":
--   doorway  - the tile a doorway stands on IS the crossing, so an open door does not
--              link the room to the next one here (bridgeOurs decides room membership
--              with exactly this answer)
--   barrel   - a barrel standing in the throat must never be walked through, which is
--              what makes this a pushing-side test and not a floor test
--
-- Nothing is read from the engine except the npc list (already cached): the caller
-- hands in the pass's world.

-- A TIGHTROPE IS A PAIR OF TILES, NOT A DOORWAY, AND NOT A WALK EITHER.
--
-- Doorways are pairs of leaves, but a doorway pair joins two 16-tile LATTICE CELLS
-- (`D.doorRooms` asks `D.roomCellAt`), and the two halves of a grapple room are the SAME
-- cell: live, 12456,1814 and 12456,1816 both resolve to cell i=2 j=1 of that region. A
-- room-graph edge through the rope would therefore be a self-loop the router ignores.
--
-- So the pair lives here, in the tile model - but it does NOT make the walk cross. A
-- chasm is not walkable and D.walkBfs must keep saying so: that answer is what stops the
-- bot clicking things through a wall or over a gap, and bridgeOurs and the icy-pad solver
-- read it for exactly that. What the pair buys is the one fact the door task needs:
-- WHICH SIDE of the rope the player is on, and which side the doorway it wants is on.
-- Getting from one side to the other is a click (D.crossTightrope), never a walk step.
--
-- The rope is 5x1 with its origin at one END of it (live: "Tightrope" 54242 at 12456,1815
-- spanning 12456..12460), so the origin alone says nothing about which line is blocked.
-- Each tile of the footprint is probed, and the answer is the axis where BOTH sides carry
-- floor and the tile between them does not - proof that the rope bridges a blocked line
-- rather than standing next to one.
D.GRAP_PAIR_PROBE = 2   -- how far out to look for the floor on either side of the rope
D.GRAP_PAIR_SPAN  = 4   -- tiles to walk along the rope from its origin (5x1 measured live)
function D.walkPairs(world)
	local out = {}
	local ids = D.GRAP_TIGHTROPE_IDS
	if not (world and world.walk and ids) then return out end
	local walk = world.walk
	for _, o in ipairs(world.objs or {}) do
		local id = tonumber(D.objGet(o, 'Id'))
		if id and ids[id] then
			local tx, ty = D.objTile(o)
			if tx then
				local ox, oy = math.floor(tx), math.floor(ty)
				-- ONE PAIR PER ROPE, AND THE NEAREST ONE. The rope spans five tiles
				-- (live: 12456..12460 at y=1815) and the floor is not the same on every
				-- column - the clean crossing can sit one tile PAST the object's end, at
				-- 12461 where both 1814 and 1816 are floor, while the columns under the
				-- rope only find floor two tiles out. So every column is scored and the
				-- cheapest pair wins, instead of the first one found.
				--
				-- THE PROBE TILE ITSELF MUST BE BLOCKED. Live, the tile the rope is LAID
				-- ON is walkable (12460-12462 at y=1815 answer "Walk" - the rope is not a
				-- gap), so a probe that accepts any tile finds 12460 and 12462 either side
				-- of 12461,5 and calls THAT the crossing - a pair along the rope, which
				-- reads as "the player is already on the right side" and the rope is then
				-- ignored altogether. A pair only means anything when the tile between its
				-- two ends is the thing that cannot be walked.
				local best, bestCost = nil, nil
				for i = 0, D.GRAP_PAIR_SPAN + 1 do
					local cols = { { ox + i, oy }, { ox, oy + i } }
					for c = 1, 2 do
						local x, y = cols[c][1], cols[c][2]
						if not walk[pkey(x, y)] then
							for axis = 1, 2 do
								local dx, dy = (axis == 1) and 1 or 0, (axis == 1) and 0 or 1
								local pd, nd, posX, posY, negX, negY = nil, nil, nil, nil, nil, nil
								for r = 1, D.GRAP_PAIR_PROBE do
									local ax, ay = x + dx * r, y + dy * r
									local bx, by = x - dx * r, y - dy * r
									if not pd and walk[pkey(ax, ay)] then
										pd, posX, posY = r, ax, ay
									end
									if not nd and walk[pkey(bx, by)] then
										nd, negX, negY = r, bx, by
									end
								end
								if pd and nd then
									local cost = pd + nd
									if not bestCost or cost < bestCost then
										bestCost = cost
										best = { a = { x = posX, y = posY },
											b = { x = negX, y = negY }, x = x, y = y,
											-- which axis the pair splits on: 'x' means the
											-- floor is east/west of the blocked line
											axis = (axis == 1) and 'x' or 'y' }
									end
								end
							end
						end
					end
				end
				if best then
					best.id = id
					best.obj = o
					best.act = tostring(D.objGet(o, 'Action') or '')
					best.name = D.objName(o)
					out[#out + 1] = best
				end
			end
		end
	end
	return out
end

-- Is (x,y) on the FAR SIDE of a tightrope from where the player stands? This is a
-- question about the rope's PAIR, not about the walk: the player cannot walk across a
-- chasm, so D.walkBfs keeps answering "unreachable" over there and must keep doing so -
-- that is what stops the bot clicking things through a chasm. What the pair buys is the
-- one fact the door task needs: the two tiles it joins know which line is blocked, so
-- "the doorway I want is on the other side of the rope" is a comparison of sides.
--
-- Only a target in the SAME room cell counts: the rope's line runs on for ever, and a
-- doorway in the room next door is not "behind the rope".
function D.walkNeedsCross(world, px, py, x, y, pairs)
	if not (px and py and x and y) then return nil end
	pairs = pairs or D.walkPairs(world or {})
	if #pairs == 0 then return nil end
	local _, _, ci, cj = D.roomCellAt(x, y)
	for _, pair in ipairs(pairs) do
		local _, _, pi, pj = D.roomCellAt(pair.x, pair.y)
		if pi == ci and pj == cj then
			-- the axis the pair splits on, and the line between its two tiles
			local horiz = (pair.axis == 'x')
			local mid = horiz and ((pair.a.x + pair.b.x) / 2) or ((pair.a.y + pair.b.y) / 2)
			local p0 = horiz and (px - mid) or (py - mid)
			local p1 = horiz and (x - mid) or (y - mid)
			-- standing ON the line (p == 0) is "no opinion", not "the same side"
			if p0 ~= 0 and p1 ~= 0 and ((p0 > 0) ~= (p1 > 0)) then return pair end
		end
	end
	return nil
end

function D.walkBfs(world)
	if not (world and world.walk) then return nil end
	local px, py = ptile()
	px, py = math.floor(px), math.floor(py)
	local start = pkey(px, py)

	local doorTiles
	for _, d in ipairs(world.doors or {}) do
		doorTiles = doorTiles or {}
		doorTiles[pkey(d.x, d.y)] = true
	end
	local barrelTiles
	for _, n in ipairs(D.npcScan() or {}) do
		local nm = string.lower(tostring(n.Name or ''))
		local id = n.Id
		if (D.BARREL_NPC_NAMES and D.BARREL_NPC_NAMES[nm])
			or (D.BARREL_IDS and D.BARREL_IDS[id])
			or (D.BARREL_FIX_IDS and D.BARREL_FIX_IDS[id]) then
			-- live records: the tile read can throw on one that is being removed
			local ok, t = pcall(function() return n.Tile_XYZ end)
			if ok and t then
				barrelTiles = barrelTiles or {}
				barrelTiles[pkey(t.x, t.y)] = true
			end
		end
	end

	local function free(k)
		return world.walk[k] and not (doorTiles and doorTiles[k])
			and not (barrelTiles and barrelTiles[k])
	end

	local dist, q, head = {}, {}, 1
	if free(start) then
		dist[start] = 0
		q[1] = { px, py }
	else
		-- standing on a prop, a pad or a doorway: the tile itself is not floor, so the
		-- walk starts from the floor around it (one step already spent)
		for i = 1, 4 do
			local nx, ny = px + D.DIR4[i][1], py + D.DIR4[i][2]
			local k = pkey(nx, ny)
			if free(k) then
				dist[k] = 1
				q[#q + 1] = { nx, ny }
			end
		end
		if #q == 0 then return nil end
	end

	while head <= #q do
		local cur = q[head]
		head = head + 1
		local d0 = dist[pkey(cur[1], cur[2])]
		for i = 1, 4 do
			local nx, ny = cur[1] + D.DIR4[i][1], cur[2] + D.DIR4[i][2]
			local k = pkey(nx, ny)
			if dist[k] == nil and free(k) then
				dist[k] = d0 + 1
				q[#q + 1] = { nx, ny }
			end
		end
	end
	return { dist = dist, start = { x = px, y = py }, n = #q }
end

-- Can we stand on that tile, or within `tol` of it? Chebyshev, like every other
-- distance in this file (D.propInMyRoom, D.ROOM_NEAR): tol 1 is "the eight tiles
-- around it", which is what picking something up from beside it needs.
function D.walkReach(bfs, x, y, tol)
	if not (bfs and bfs.dist and x and y) then return false end
	local fx, fy = math.floor(x), math.floor(y)
	tol = math.floor(tol or 0)
	for dx = -tol, tol do
		for dy = -tol, tol do
			local d = bfs.dist[pkey(fx + dx, fy + dy)]
			if d then return true, d end
		end
	end
	return false
end

-- NEAREST FLOOR WE CAN REALLY WALK TO, within three tiles of (x,y). puzzles.lua calls
-- this in five places and it only ever existed in the pathing half, which this script
-- does not load - so every one of those calls was a call on nil ("solver statues threw:
-- attempt to call a nil value (field 'walkSpotNear')", live, on every pass). Same
-- contract as the pathing version, built on the D.walkBfs above: bfs.dist is the walk
-- over the ROOM's own floor, so a spot behind a wall is simply not in it.
function D.walkSpotNear(world, x, y)
	if not (world and x and y) then return nil end
	local bfs = D.walkBfs(world)
	if not (bfs and bfs.dist) then return nil end
	local bx, by, best = nil, nil, nil
	for k in pairs(bfs.dist) do
		local sx, sy = k:match('^(-?%d+):(-?%d+)$')
		sx, sy = tonumber(sx), tonumber(sy)
		if sx then
			local d = (sx - x) ^ 2 + (sy - y) ^ 2
			if d <= 9 and (not best or d < best) then
				best, bx, by = d, sx, sy
			end
		end
	end
	return bx, by
end

-- TILE CLICK. Nothing here waits for a walk to land or routes around a doorway: a
-- puzzle is a click away, and the client owns the path. The only guard is the tile
-- we already clicked from the tile we are still standing on, so a target the client
-- refuses cannot be clicked for ever.
D.WALK_LIMIT = 3
function D.walkTile(x, y, z)
	if D.stopped() or not x or not y then return false end
	local fx, fy = math.floor(x), math.floor(y)
	local px, py = ptile()
	if fx == px and fy == py then return false end
	local from, to = px .. ',' .. py, fx .. ',' .. fy
	if D.walkFrom == from and D.walkTo == to then
		D.walkTries = (D.walkTries or 0) + 1
		if D.walkTries > D.WALK_LIMIT then
			if D.walkTries == D.WALK_LIMIT + 1 then
				log(string.format('refusing to click tile %d,%d again (%d tries from %d,%d)',
					fx, fy, D.WALK_LIMIT, px, py))
			end
			return false
		end
	else
		D.walkFrom, D.walkTo, D.walkTries = from, to, 1
	end
	local ok, sent = pcall(API.DoAction_Tile, FFPOINT.new(fx, fy, math.floor(z or 0)))
	return ok and sent == true
end

-- One click budget per object tile: two clicks inside a game tick are one intent, and
-- the cap is what keeps "You can't reach that" from repeating down the console.
D.CLICK_WINDOW = 20000
D.clickLog = {}
function D.clickAllowed(x, y)
	local fx, fy = math.floor(x), math.floor(y)
	local k = fx .. ',' .. fy
	local now = API.SystemTime()
	local hist = D.clickLog[k]
	if not hist then hist = {} D.clickLog[k] = hist end
	local recent, last = 0, nil
	for i = #hist, 1, -1 do
		if (now - hist[i]) > D.CLICK_WINDOW then
			table.remove(hist, i)
		else
			recent = recent + 1
			last = hist[i]
		end
	end
	if last and (now - last) < D.CLICK_GAP then return false end
	if recent >= D.CLICK_LIMIT then
		log(string.format('not clicking %d,%d: %d clicks in %d s',
			fx, fy, D.CLICK_LIMIT, math.floor(D.CLICK_WINDOW / 1000)))
		return false
	end
	hist[#hist + 1] = now
	return true
end

-- The live record of an id standing on a tile, with the three answers the callers
-- test for:
--   object    -> present and it offers an option (clickable)
--   false, o  -> present but no option: it must never be clicked
--   nil       -> not there any more (a door that just opened loses its leaf)
function D.liveObjectAt(id, x, y)
	local o = D.objAt(id, x, y)
	if not o then return nil end
	-- ground items are never the door/prop this asks about, even if an id collides
	if (tonumber(D.objGet(o, 'Type')) or 0) == 3 then return nil end
	if D.interactable(o) then return o end
	return false, o
end

-- OBJECT CLICK - the only click entry point.
--
--   D.clickObject(action, obj[, route])
--
-- The engine is handed the scanned record itself (DoAction_Object_Direct). `action` is
-- the menu text ('Pull', 'Go-through', 'Open' ...) or an opcode; D.CODE turns it into
-- the action slot. Every click passes the budget below, so a prop can never be
-- hammered whatever the caller does.
function D.clickObject(action, o, route)
	if o == nil then return false end
	local x, y = D.objTile(o)
	if not (x and y) then return false end
	if not D.clickAllowed(x, y) then return false end
	local ok, sent = pcall(API.DoAction_Object_Direct, code(action), route or D.ROUTE_OBJ, o)
	if ok and sent then
		-- remember WHAT was sent where: D.unlockInFlight asks this before another click
		-- on the same doorway, so an Enter cannot follow a key turn a tick too soon
		D.lastClickAt = D.lastClickAt or {}
		D.lastClickAt[math.floor(x) .. ',' .. math.floor(y) .. '/' .. tostring(action)] = API.SystemTime()
		log(string.format('%s %s at %d,%d', tostring(action),
			tostring(D.objGet(o, 'Id')), math.floor(x), math.floor(y)))
	end
	return ok and sent == true
end

-- The live record for an id standing on a tile. A plan step carries only the id and
-- the tile it was planned from, and a click needs the record itself. Read fresh: the
-- caller is about to hand this record to the engine, so it must not be a prop that the
-- plan's own last click removed.
function D.objAt(id, x, y)
	if not (id and x and y) then return nil end
	local fx, fy = math.floor(x), math.floor(y)
	for _, o in ipairs(D.objsFresh()) do
		if D.objGet(o, 'Id') == id then
			local ox, oy = D.objTile(o)
			if ox and math.floor(ox) == fx and math.floor(oy) == fy then return o end
		end
	end
	return nil
end

-- Ground items are taken in two steps: click the item (the player walks onto it and
-- the loot window opens), then collect from it. The click is a direct pointer action
-- and asks nothing, so reachability is asked here first - an item behind a wall is the
-- "walked past the key" run. Tolerance 1 then 2, because an item usually sits on a
-- tile that is not walkable itself.
D.LOOT_DIST = 20
function D.takeFloorItem(obj, ids, what, reserveFree)
	if obj == nil then return false end
	local x, y = D.objTile(obj)
	if not (x and y) then return false end
	local ix, iy = math.floor(x), math.floor(y)
	local t = D.objGet(obj, 'Tile_XYZ')
	local iz = math.floor(tonumber(D.objGet(t, 'z')) or 0)
	local px, py = ptile()
	if math.max(math.abs(ix - px), math.abs(iy - py)) > 2
		and not D.tileReachable(ix, iy, iz, 1)
		and not D.tileReachable(ix, iy, iz, 2) then
		D.takeRefuseLog = D.takeRefuseLog or {}
		local k = ix .. ',' .. iy
		if not D.takeRefuseLog[k] then
			D.takeRefuseLog[k] = true
			log(string.format('not taking %s at %s: the client says there is no path to it',
				tostring(what or 'item'), k))
		end
		return false
	end
	-- collect around the ITEM, not the player: the same item sits in every room, and a
	-- player-centred sweep reaches the ones behind walls
	local rad = math.max(math.abs(ix - px), math.abs(iy - py)) + 1
	log(string.format('taking %s at %d,%d from %d,%d (radius %d)',
		tostring(what or 'item'), ix, iy, px, py, rad))
	settle()
	pcall(API.DoAction_G_Items_Direct, D.ACT_TAKE, D.ROUTE_PICKUP, obj)
	API.RandomSleep2(1400, 500, 800)
	settle()
	pcall(API.DoAction_Loot_p, ids, {}, D.LOOT_DIST, API.PlayerCoordfloat(), rad, {
		allowStackablesAlreadyHeld = true,
		useLootAll = true, allowStackables = true,
		-- only food reserves slots, so the pack can never block a key or a puzzle piece
		reserve = tonumber(reserveFree) or 0,
	})
	if isMoving() then
		API.RandomSleep2(2200, 800, 1200)
	else
		API.RandomSleep2(1400, 500, 800)
	end
	settle()
	return true
end


API.SetDrawTrackedSkills(true)
say('starting')
log('build ' .. tostring(D.BUILD) .. ' loaded into the client')
::continue::
while API.Read_LoopyLoop() do

	-- The chat buffer drains on every read, so it must be polled every iteration -
	-- this is where a completed puzzle announces itself.
	drainChat()
	-- NO ClearMarkTiles HERE. Dots live D.MAPDOT_MS and are refreshed by the pass that
	-- stamps them (see D.MAPDOT_MS): wiping the floor at the top of every iteration only
	-- erased the dots of a pass that never got to its stamp - a solver holding the room,
	-- a fight, a doorway click - so the grid blinked off and on. Only the maze solver
	-- still clears the floor, and only when it lays down a new route (puzzles.lua).
	-- last pass's props are not this pass's map: every pass starts with no snapshot
	-- (see D.objScan), and the sweep below publishes this pass's own. The scan
	-- containers pinned behind those records go with it (see D.keepScan).
	D.passObjs = nil
	D.scanPins = {}

--------------------------------------------------------------------
-- LOCAL LOGIC: enemies -> keys -> food -> puzzles -> doors (boss last on the floor)
-- Enemies first: a room with something to kill is a fight, not a shopping trip, and the
-- fight branch holds the pass until its list is empty. Keys and food come next and are
-- gated on !D.solverFn, so a puzzle already being worked is never interrupted - they only
-- run in a room whose puzzle has not started (or has let go). Keys before food: the keys
-- open the floor, the food only heals.
--------------------------------------------------------------------
		
		---Readability tests
		--NeededTOReach_NPCS is built per pass from D.roomNpcs (see the fight branch below):
		--ReadAllObjectsArray({1},{},{},0) path-finds once per NPC on the whole floor, so the
		--room is decided in Lua first and the client is only asked about what survives.
		--NeededTOReach_NPCS_boss = API.ReadAllObjectsArray({1},{},{})---global map
		--NeededTOReach_GIFOODS = API.ReadAllObjectsArray({3},D.FOOD_IDS,{},1)---local map
		--NeededTOReach_KEYS_local = API.ReadAllObjectsArray({3},D.KEY_IDS,{},0)
		--NeededTOReach_KEYS_global = API.ReadAllObjectsArray({3},D.KEY_IDS,{})---global map
		--NeededTOReach_OBJECTS_local = API.ReadAllObjectsArray({0,12},D.DOOR_BASIC,D.SKILL_DOOR_NAMES_FIND,1)---objects stand on tile
		--NeededTOReach_OBJECTS_global = filterObjects(D.DOOR_BASIC,D.SKILL_DOOR_NAMES_FIND,true)---global map for doors
		---Puzzle props (0/12) and map tiles (99) from one sweep; .cells is the BFS grid
		local puzzle = D.puzzleScan()
		---Everything this pass asks about props answers from this one list (D.objScan)
		D.passObjs = puzzle.objs
		---The room the solvers take: the grid around us and the props standing on it.
		---No floor route, no door walking - a puzzle is solved from inside its room.
		local px, py = ptile()
		local world, here = D.localWorld(puzzle, px, py)
		D.here = here

		---A FLOOR IS ITS OWN MAP AREA. A ladder down takes us to a different base, and the
		---boss marker remembered on the floor we left must not be drawn on the new one.
		local floorBase = math.floor(px / 64) .. ':' .. math.floor(py / 64)
		if D.floorBase ~= floorBase then
			D.floorBase = floorBase
			D.bossDoorMem, D.bossPassageMem = nil, nil
			-- the boss prayer belongs to the floor it was raised on: the sighting and the
			-- short retry window start over, so the next fight gets one prompt press
			D.bossPrayerSeen, D.protectOn, D.protectTries = nil, nil, nil
			D.protectNoAbility, D.protectNoPoints, D.protectToldOn = nil, nil, nil
			-- and the prayers that were pressed "on trust" (no varbit to read) start over,
			-- or the next floor's fight would never press them again
			D.prayerPressed, D.bossPrayerName, D.prayerTrusted = nil, nil, nil
			-- the horde fight's own clocks - the last tunnel blocked, the last bite, the last
			-- trip to the skinweaver - belong to the floor they were written on
			D.hordeBlockAt, D.hordeEatAt, D.hordeHealAt, D.hordeTalkAt = nil, nil, nil, nil
			-- the shadow-forger's hide belongs to the arena it was walked on: a stale tile
			-- from the last floor is not cover in this one
			D.sfHide, D.sfArmed, D.sfHides, D.sfNoCover, D.sfAnims = nil, nil, nil, nil, nil
			-- the end ladder belongs to the floor it stood on, and so do its attempts
			D.bossDown, D.bossDownAt, D.ladderAt, D.ladderFails = nil, nil, nil, nil
			S.ladderBad = {}
			-- the route's memory of the floor goes with it: which rooms we have stood in, and
			-- the room we were heading for
			D.routeVisited, D.routeGoal = {}, nil
		end

		---PURPLE: the centre of every room on the floor, drawn before any solver takes
		---the pass so the grid stays on the floor while a puzzle is being worked.
		local centres, roomsOnFloor, cells = D.roomCentreDots(world, px, py)
		D.stampDots(centres, 0x800080, 6, true)
		-- One line per room ENTERED, not per change of the floor count: the map streams in,
		-- so "how many cells carry floor" climbed 11 -> 15 in a few seconds and wrote a line
		-- each time. Which room we are in is the fact worth a line.
		local myRoom, myI, myJ = D.roomNumber(px, py)
		if D.roomDotRemark ~= myRoom then
			D.roomDotRemark = myRoom
			log(string.format('room %d/%d (col %d, row %d) - %d of %d layout cells carry floor, purple dot on every centre',
				myRoom, cells, myI + 1, myJ + 1, roomsOnFloor, cells))
		end

		
		---EATING IS LOCAL WORK, NOT PART OF THE FIGHT. It used to sit inside the enemy
		---branch below, so a room with nothing to attack never healed at all: the toxin room
		---ticked the run down with a full pack of food in it and nothing ever ate. It runs at
		---the FRONT of the local tasks now, before enemies, keys and puzzles.
		---It does not interrupt a puzzle: while a solver holds the room (D.solverFn) the eat
		---check is skipped entirely, and eating never takes the pass either - it is one
		---ability click and the pass carries on to whatever is next.
		if not D.solverFn and D.eatFood() then
			D.setStateNow('eating - low life points')
		end

		---PROTECT FROM RANGED for the bosses that shoot (Sagittare), the same way eating
		---works: an action-bar ability, pressed once per boss room, and only with prayer
		---points to pay for it. The press usually lands earlier than this line: the walk
		---into the boss room polls it too (D.bossPrayerPoll), because a pass stuck in a
		---six-second wait is exactly when the arrows start.
		D.bossPrayerStep(px, py)

		---THE END LADDER: a "Ladder" with the action "End dungeon" exists only once the
		---boss is dead, so seeing it ends the floor. This is before keys, doors and the
		---route on purpose - nothing left in the dungeon matters after the boss.
		if D.endLadderStep(px, py) then
			goto continue
		end

		---BOSS MECHANICS, BEFORE THE ROOM CLEAR. A Daemonheim boss is not "a monster in the
		---room": the night-gazer's pillars and shadow ARE the fight, and the room-clear
		---branch below would spend every pass swinging at it while the arena stayed dark. A
		---strategy that acts (a pillar lit, a step off the shadow) takes the pass; one that
		---does not leaves the attack to the ordinary branch.
		if not D.solverFn and D.bossStrategyStep(world, here, px, py) then
			goto continue
		end

		---THE ROOM'S OWN ENEMIES, refreshed every pass (D.roomNpcs): inside this room's
		---floor, alive, offering Attack, and reachable at tolerance 0. It used to be a list
		---nobody ever filled, so the whole branch below never ran.
		NeededTOReach_NPCS = D.roomNpcs(here, px, py)

		---Clear room of enemies
		if #NeededTOReach_NPCS > 0 then
			if not inCombat() then
				for _, n in ipairs(NeededTOReach_NPCS) do
					-- the record is a plain Lua one (D.roomNpcs): the tile distance is
					-- Chebyshev from the player, and `obj` is the engine record the click
					-- needs
					local d = math.max(math.abs(n.x - px), math.abs(n.y - py))
					if d < 14 then
						D.setStateNow(string.format('clearing the room - %s (%d in sight)',
						tostring(n.name), #NeededTOReach_NPCS))
						API.DoAction_NPC__Direct(D.ACT_ATTACK, API.OFF_ACT_AttackNPC_route, n.obj)
						API.RandomSleep2(1200, 400, 600)
						goto continue
					end
				end
			else
				-- IN COMBAT: the fight plays out on its own, so this pass does nothing -
				-- but it must still yield. This branch used to go straight back to the
				-- top of the loop with no sleep and no action, which spun the whole pass
				-- (every world read, every solver) as fast as the engine answered.
				D.setStateNow(string.format('in combat - %d in sight', #NeededTOReach_NPCS))
				API.RandomSleep2(600, 200, 400)
				goto continue
			end
		end

		---KEYS AND FOOD ARE SCANNED HERE, AFTER THE FIGHT, NOT AT THE TOP OF THE PASS.
		---Nothing is clicked by this block - it fills the lists the two branches below
		---read - but it costs two client scans and one path find per key, and the fight
		---branch does not need either. A pass that is fighting now pays for the fight.
		---
		---KEYS: anywhere on the floor. D.floorKeys finds them (unfiltered scan, ring
		---checked); the split below asks the client's own path test per candidate. In
		---reach = a loot click; out of reach = a ROOM the route can walk to (D.keyRooms),
		---which is the global key task.
		local keysOnFloor = D.floorKeys(px, py)
		NeededTOReach_KEYS_local, D.keyRooms = {}, {}
		local keySig = {}
		for _, k in ipairs(keysOnFloor) do
			-- local = close enough for a loot click AND reachable. Two tiles is taken as
			-- reachable without asking the client - the same rule D.takeFloorItem applies -
			-- so a key that dropped next to the player can never be filtered out by a
			-- failed path find.
			local reach = (k.d <= 2) or D.tileReachable(k.x, k.y, k.z, D.REACH_LOCAL)
			local _, _, ki, kj = D.roomCellAt(k.x, k.y)
			-- THE ROOM IS A DESTINATION EVEN WHEN THE CLIENT SAYS "CAN'T PATH THERE YET".
			-- A key lying in a room whose doorway is still shut reads as unreachable - the
			-- pathfinder refuses to route through a closed door - and filling D.keyRooms only
			-- from the reachable keys deadlocked a floor: live, the only work left was a
			-- silver key just west of the player and a silver shield door waiting for it, the
			-- key's room was dropped, no other door qualified as a goal either, and the route
			-- went silent for two minutes with the bot standing still. Reachability now only
			-- decides whether the key can be LOOTED from where we stand; the room is planned
			-- either way, and D.roomRoute only ever crosses doorways we can open, so this can
			-- never name a room behind a door we do not have the key for.
			D.keyRooms[ckey(ki, kj)] = true
			if k.d <= (D.LOOT_DIST or 20) and reach then
				NeededTOReach_KEYS_local[#NeededTOReach_KEYS_local + 1] = k
			end
			keySig[#keySig + 1] = string.format('%d@%d,%d r%d,%d room %d:%d%s',
				k.id or -1, k.x, k.y, math.floor(k.x / 64) * 64, math.floor(k.y / 64) * 64,
				ki, kj, reach and '' or ' far')
		end
		---NAME THE KEY. "the route wants room 3:2 for its key, but there is no key there"
		---is answerable only by the record that produced the fact, and the sweep can hand
		---back a key that the entity list never shows - or one standing in another region,
		---whose region-local cell collides with this floor's. One line per change.
		keySig = table.concat(keySig, '; ')
		if D.keySigLogged ~= keySig then
			D.keySigLogged = keySig
			log('keys on the floor: ' .. (keySig ~= '' and keySig or 'none'))
		end
		---FOOD is this room only: it is local work and never a reason to walk anywhere
		---(see D.roomFoodLocal).
		NeededTOReach_GIFOODS = D.roomFoodLocal(here, px, py)

		---KEYS, THEN FOOD, as their own step - NOT as elseifs of the solver chain.
		---Both are gated on !D.solverFn, so a puzzle is still never interrupted, but a
		---solver that merely answers "true, I am working here" no longer starves them: in
		---the chain they were the last two clauses, so any room where one of the eighteen
		---solvers kept claiming the pass never looted anything at all.
		if not D.solverFn then
			---Pick up keys: the ones the ring does not hold, nearest first.
			local k = NeededTOReach_KEYS_local[1]
			if k then
				local kcolor = D.KEY_COLOR[tonumber(D.objGet(k.o, 'Id'))] or 'guard room'
				D.setStateNow(string.format('looting keys - %s key at %d,%d (%d in reach)',
					tostring(kcolor), k.x, k.y, #NeededTOReach_KEYS_local))
				-- takeFloorItem: one Take click on the record, then a Loot sweep around the
				-- spot for the rest, with the reachability check and its own logging
				D.takeFloorItem(k.o, D.KEY_IDS, kcolor .. ' key')
				goto continue
			end
			---Get foods: local only, and ten slots always stay free (D.FOOD_RESERVE) so
			---eating can never fill the pack and block a key or a puzzle piece.
			---D.FOOD_MAX pieces is the cap - past that the rest stays on the floor.
			local f = D.foodHeld() < D.FOOD_MAX and NeededTOReach_GIFOODS[1] or nil
			if f then
				D.setStateNow(string.format('looting food - %d piece(s) in this room, %d in the pack',
					#NeededTOReach_GIFOODS, D.foodHeld()))
				D.takeFloorItem(f.o, D.FOOD_IDS, 'food', D.FOOD_RESERVE)
				goto continue
			end
		end

		---puzzle solvers
		if D.localRoom(D.solveGrappleBridge, world, here, px, py) then
			-- 0. grapple bridge / winch bridge: plunder meatcorn -> spin the rope ->
			-- retrieve and repair a climbing hook -> combine them -> Grapple the chasm,
			-- which spawns the tightrope the room is crossed by. FIRST in the chain: the
			-- room is full of "Stack of barrels" decor and a spinning wheel and anvil, so
			-- every other solver has something to say about it, and the java's own
			-- detection (no winch = leave the dungeon) is exactly what must not happen.

		elseif D.localRoom(D.solveBarrels, world, here, px, py) then
			-- 1a. barrels: pushed aside for the broken bits, the broken barrel repaired
			-- in the middle, then the fixed barrel pushed from pipe to pipe until full.
			-- FIRST of the room solvers: a barrel room also carries a pressure pad, two
			-- bonus chests and stones, and the chest / icy-pad solvers both fired in it
			-- and stole the passes ("locked chest ... walking to", "icy pads: 1 pad(s) at
			-- 10725,4886") while the bits were lying reachable.
			-- Every push spends the pass: it moves one tile and changes what is legal
			-- next, so re-planning in the same pass would only click a barrel twice.

		elseif D.localRoom(D.solveMaze, world, here, px, py) then
			-- 1g. toxin maze: planned, then barriers and the chest are clicked. It goes
			-- FIRST because every pass spent in another solver is a pass the maze does
			-- not get: the lever solver alone was logging "1 lever(s) here did not
			-- register" ten times between two barrier clicks. It returns false for any
			-- room that is not a maze, so nothing else is affected.

		elseif D.localRoom(D.solveMonolith, world, here, px, py) then
			-- 1a. monolith room: activate the pillar, then keep the shades off it.
			-- Its doors are locked until it is charged, so nothing else can be done
			-- in here and the loop must not route away.

		elseif D.localRoom(D.solveSlidingStatues, world, here, px, py) then
			-- 1a. sliding statues: push the four sliding statues onto the tiles that
			-- copy the fixed row. It runs BEFORE follow-the-leader because both rooms
			-- are full of npcs called "Statue": that solver matches any statue by
			-- name, and a statue that is being pushed is not a leader playing an
			-- emote. This one needs both statue families (ids 10942-10953 and
			-- 10954-10965), so it can never answer for a leader room.

		elseif D.localRoom(D.solveSleepingGuards, world, here, px, py) then
			-- 1a. sleeping guards: steal the plain "Guard room key" off a sleeping
			-- brute (killing an awake one drops it instead - the fight branch above
			-- owns that). Its only job is the key; the doorway logic unlocks with it,
			-- which is why hasKeyFor() asks D.guardHoldsKey for keyless "Unlock" doors.

		elseif D.localRoom(D.solveFollowLeader, world, here, px, py) then
			-- 1b. follow the leader: pad nearest the statue, then copy its emote

		elseif D.localRoom(D.solveGrooves, world, here, px, py) then
			-- 1c. suspicious grooves: investigate a row, step onto the safe tile

		elseif D.localRoom(D.solveStatues, world, here, px, py) then
			-- 1d. three weapon statues: mine a block, carve the weapon, arm the statue

		elseif D.localRoom(D.solveSwitches, world, here, px, py) then
			-- 1e. levers ("5 switches"): pull every lever in the room

		elseif D.localRoom(D.solveConstruct, world, here, px, py) then
			-- 1f. magical construct: stone -> carve -> imbue -> repair

		elseif D.localRoom(D.solveGhost, world, here, px, py) then
			-- 1g. unhappy ghost: repair the room, unlock the coffin, bless the remains.
			-- Returns false for every room that is not a ghost room (nothing else has a
			-- coffin / jewellery box / damaged wall / broken pot in it), so nothing
			-- else in the chain changes.

		elseif D.localRoom(D.solveCollapse, world, here, px, py) then
			-- 1h. collapsing room: repair a broken collapsing structure, otherwise
			-- destroy the "Rocky debris". Only props inside this room are touched.

		elseif D.localRoom(D.solveBridge, world, here, px, py) then
			-- 1i. damaged bridge: raid the crate for wood and Repair, or jump the
			-- "Unfinished bridge"; the stone route mines a rock, carves the stone and
			-- repairs. Only bridges inside this room are touched.

		elseif D.localRoom(solvePondskaters, here, px, py) then
			-- 1b. a puzzle room: catch the pondskaters before moving on

		elseif D.localRoom(solveFerrets, world, here, px, py) then
			-- 1c. coloured ferrets: scare the one that is off its plate

		elseif D.localRoom(solveFlipTiles, world, here, px, py) then
			-- 1d. rune/flip tiles: turn the whole board one colour

		elseif D.localRoom(solveIcyPads, world, here, px, py, S.done, skip) then
			-- 1e. icy pads: slide onto each of the squares

		elseif D.localRoom(D.solveCamp, world, here, px, py) then
			-- 1j. Fremennik camp: three crates, one skill action each (Smith-battleaxes,
			-- Cook-fish, Fletch-bows). Matched by id, so it can never answer for another
			-- room, and it stops by itself once no crate offers an action.

		elseif D.localRoom(D.solveRecess, world, here, px, py) then
			-- 1k. coloured recess: push each Block npc onto the recess of its colour. The
			-- pushing is D.barrelPush in its "the prop has to reach that tile" mode, one
			-- push per pass.

	end

	---EVERYTHING ABOVE IS LOCAL WORK: enemies, the room's own puzzle, keys, food. Until
	---all of it is done, a pass must not fall through to the doors or the boss - a solver
	---that took the pass still holds the room (D.localRoom clears D.solverFn only when the
	---room goes quiet), and walking off mid-puzzle is what this section exists to stop.
	if D.solverFn then
		-- A solver holds this room, so the rest of the pass stands down. It must still
		-- yield: not every solver sleeps before it returns true (the maze's teleport
		-- wait does not), and going straight back to the top re-read the whole world.
		API.RandomSleep2(150, 50, 100)
		goto continue
	end

	---4. the room's doors: last, because a doorway is only worth opening once nothing
	---inside the room is left to do. The dots are drawn on the way, one doorway is
	---opened per pass (nearest first, paired/skill/keyless doorways left alone).
	if D.openRoomDoor(world, px, py) then
		D.waitMove(px, py, 6000)
		D.waitWalkDone(4000)
		if D.doorStay(here) then
			D.waitWalkDone(3000)
		end
		goto continue
	end

	---5. THE FLOOR ROUTE: no local work left in this room, so walk to the next room that
	---has some (an unopened doorway, a puzzle, an unexplored room, the boss room last).
	---The destination is marked white-square-under-purple; the doorway is clicked from the
	---side we are standing on. A solver holding the room never reaches this line, and the
	---doors above are tried first, so local work always wins.
	if D.routeStep(world, here, px, py) then
		D.waitMove(px, py, 6000)
		D.waitWalkDone(4000)
		goto continue
	end



	---doors: nothing here yet, so every pass with no local work re-reads the room

	





	API.RandomSleep2(400, 150, 250)
end

-- Dump the debug buffer next to the other ME logs so a finished run can be read
-- back without a screenshot of the on-screen window.
-- Leaving the route dots on the floor after a run is litter, and so is the status line:
-- the last "Dung: ..." text stayed on screen after the loop exited, which reads as "the
-- script is still running" long after it has stopped.
API.Write_ScripCuRunning0('Dung: stopped')
API.ClearMarkTiles()
API.SaveConsoleToFile('dung_debug.txt', false)
