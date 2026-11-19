-- Shared mutable state for Dung.lua.
--
-- Why this file exists: a Lua 5.1 chunk may hold at most 200 LOCAL variables, and
-- Dung.lua kept hitting that ceiling. A constant written as `D.X = {...}` costs
-- nothing (it is a table field, not a local), but every `local <name> = ...` does -
-- so the floor/room state lives here, behind one `local S = require("dung_state")`.
--
-- This is one instance: created when the script loads, shared by everything that
-- requires it. Floor resets clear the tables in place; they never replace it.

return {
	------------------------------------------------------------------
	-- door bookkeeping
	------------------------------------------------------------------
	doorCutOff = {},            -- doorKey -> SystemTime of the last rejection
	doorQuiet = {},             -- doorKey -> true once the rejection was logged
	ladderBad = {},             -- ladderTileKey -> true, clicked and moved us nowhere

	-- room key the route came from, so target selection can refuse it
	arrivedFrom = nil,

	------------------------------------------------------------------
	-- floor / world cache
	------------------------------------------------------------------
	floorTiles = {},            -- walk tile set of the floor (type 99 "Walk")
	floorDoorTiles = {},        -- doorway tiles, excluded when segmenting rooms
	floorDirs = {},             -- tileKey -> the directions that tile may be left in (wall sides)
	floorOrigin = nil,          -- player tile when the floor began
	floorChanged = false,       -- set when a new floor was detected
	worldCache = nil,
	worldRoom = nil,
	worldAt = 0,
	lastTileCount = 0,          -- floor map size at the last iteration

	------------------------------------------------------------------
	-- room / door progress for the current floor
	------------------------------------------------------------------
	done = {},                  -- roomKey -> true, local logic finished
	badDoor = {},               -- doorKey -> true, tried and would not open
	attempts = {},              -- doorKey -> clicks that did not move us
	unwalkable = {},            -- doorKey -> true, no walk plan reaches it (yet)
	visitedEmpty = {},          -- roomKey -> true, stood there and found nothing
	leftRooms = {},             -- roomKey -> true, abandoned at least once
	leaveFails = {},            -- roomKey -> times a back door failed to move us out
	heldSig = '',               -- key-item signature of the last pass
	keyTries = 0,
	stuck = 0,                  -- passes without progress
	floorAge = 0,               -- iterations spent on this floor

	------------------------------------------------------------------
	-- combat / boss
	------------------------------------------------------------------
	attackFails = {},
	attackIgnoredUntil = {},
	attackSkipLogged = {},      -- npc uid -> SystemTime, so a skip logs once
	bossUidSeen = nil,
	bossMode = false,           -- floor explored, the boss is the last objective
	bossFought = false,         -- a boss has been engaged this floor
	bossFailed = false,         -- gave up on the boss room, do not re-enter
	bossWait = 0,               -- polls spent waiting for the boss to load/route
	sawHp = false,              -- a live HP reading has been seen (death guard)

	------------------------------------------------------------------
	-- puzzles
	------------------------------------------------------------------
	pondState = {},             -- roomKey -> { caught, solved, keyBase, quiet }
}
