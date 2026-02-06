local APIOSRS = {}

--- API Version will increase with breaking changes
APIOSRS.VERSION = 1.000

--Few functions are mapped onto original api rest are missing. animation is
[[-- some tested and working are:

--]]


--- Checks if item is selected in inventory
-- @return boolean
function APIOSRS.RL_IsWidgetSelected()
	return RL_IsWidgetSelected()
end

--- Attempts to click an entity in the game world using a mouse, object must be on screen and even then it is doubtful success chance
--- type isnt actual osrs type but was set to match ui. type 0 is object, type 1 is npc, type 2 is player, type 3 is grounditem = not working, type 5 is projectile
-- @param type integer
-- @param entityID []integer ids in {}
-- @param max_distance integer
-- @param localtile boolean
-- @param tilex integer
-- @param tiley integer
-- @return boolean
function APIOSRS.RL_ClickEntity(type, entityID, max_distance, localtile, tilex, tiley)
	max_distance = max_distance or 15
	localtile = localtile or false
	tilex = tilex or 0
	tiley = tiley or 0
	return RL_ClickEntity(type, entityID, max_distance, localtile, tilex, tiley)
end
























































































return APIOSRS