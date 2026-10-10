local APIOSRS = {}

--- API Version will increase with breaking changes
APIOSRS.VERSION = 1.000

---@class MenuEntryData
---@field option string
---@field target string
---@field identifier number
---@field param0 number
---@field param1 number
---@field isWidget boolean

--Few functions are mapped onto original api rest are missing. animation is
--[[ some tested and working are:

API.CheckAnim(10) -- checks if player is doing an animation, argument is delay in ms between checks, returns -1 if not animating and animation id if animating. not sure if it can be used to check for specific animations or just if player is doing something
API.ReadPlayerAnim() -- checks if player is doing an animation, returns -1 if not animating and animation id if animating. not sure if it can be used to check for specific animations or just if player is doing something
Inventory:IsOpen()
Inventory:Contains(itemid)
Bank:IsOpen()
Bank:Contains(itemid)
API.ReadPlayerMovin()
Bank:InventoryContains(itemid)
Bank:FindInventoryItemSlot(itemId)
Bank:DepositInventory()
Bank:DepositAll

--]]


--- Checks if item is selected in inventory
-- @return boolean
function APIOSRS.RL_IsWidgetSelected()
	return RL_IsWidgetSelected()
end

--- Attempts to click an entity in the game world using a mouse, object must be on screen and even then it is doubtful success chance
--- type isnt actual osrs type but was set to match ui. type 0 is object, type 1 is npc, type 2 is player, type 3 is grounditem = not working, type 5 is projectile
--- type 93 inventory
-- @param type number
-- @param entityID []number ids in {}
-- @param max_distance number
-- @param localtile boolean
-- @param tilex number
-- @param tiley number
-- @param action string optional will overide default
-- @param names string[] optional names will be used for finding objects
-- @return boolean
function APIOSRS.RL_ClickEntity(type, entityID, max_distance, localtile, tilex, tiley, action, names)
	max_distance = max_distance or 15
	localtile = localtile or false
	tilex = tilex or 0
	tiley = tiley or 0
	action = action or ""
	names = names or {}
	return RL_ClickEntity(type, entityID, max_distance, localtile, tilex, tiley, action, names)
end

function APIOSRS.RL_ClickSpellbook(spellname, spriteid)
	spriteid = spriteid or 0	
	return RL_ClickSpellbook(spellname, spriteid)
end

function APIOSRS.RL_ClickTile(tilex, tiley, minimap)
	minimap = minimap or false
	return RL_ClickTile(tilex, tiley, minimap)
end

-- @return MenuEntryData[]
function APIOSRS.RL_GetFirstMenuEntry()
	return RL_GetFirstMenuEntry()
end

--[[
Value	Tab
0	Combat Options
1	Skills
2	Quest List
3	Inventory
4	Equipment
5	Prayer
6	Spellbook
7	Clan Chat
8	Friends
9	Ignore List
10	Logout
11	Settings
12	Emotes
13	Music
--]]
-- @return number
function APIOSRS.RL_GetOpenTab()
	return RL_GetOpenTab()
end

--[[
VK_F1,  // 0  - Combat Options
VK_F2,  // 1  - Skills
VK_F3,  // 2  - Quest List
VK_ESCAPE,  // 3  - Inventory
VK_F4,  // 4  - Equipment
VK_F5,  // 5  - Prayer
VK_F6,  // 6  - Magic
VK_F7,  // 7  - Clan Chat
VK_F8,  // 8  - Friends List
VK_F9, // 9  - Account Management
VK_F10, // 10 - Logout/previously options
VK_F11, // 11 - Emotes
VK_F12, // 12 - Music
--]]
function APIOSRS.RL_OpenTab(tab)
	return RL_OpenTab(tab)
end

--complex
function APIOSRS.RL_ClickWig(widgetid, spriteid, action, name, xoffset, rightside, yoffset, bottomside)
	return RL_ClickWig(widgetid, spriteid, action, name, xoffset, rightside, yoffset, bottomside)
end

--clicks x
function APIOSRS.RL_ClickCloseBank()
	return RL_ClickCloseBank()
end

--checks
function APIOSRS.RL_IsBankOpen()
	return RL_IsBankOpen()
end

--deposit all button
function APIOSRS.RL_ClickBankDepositAll()
	return RL_ClickBankDepositAll()
end

--deposit some items
function APIOSRS.RL_ClickBankInvDepositAllExcept(items_not)
	return RL_ClickBankInvDepositAllExcept(items_not)
end

-- @return boolean
function APIOSRS.RL_IsQuickPrayerActive()
	return RL_IsQuickPrayerActive()
end

-- @return boolean
function APIOSRS.RL_IsInWilderness()
	return RL_IsInWilderness()
end

-- @return boolean
function APIOSRS.RL_IsPoisoned()
	return RL_IsPoisoned()
end

-- @return boolean
function APIOSRS.RL_IsProtectFromMagic()
	return RL_IsProtectFromMagic()
end

-- @return boolean
function APIOSRS.RL_IsProtectFromMelee()
	return RL_IsProtectFromMelee()
end

-- @return boolean
function APIOSRS.RL_IsProtectFromMissiles()
	return RL_IsProtectFromMissiles()
end

-- Wintertodt kill timer countdown (varbit 7980)
-- @return number
function APIOSRS.RL_GetWintertodtTimer()
	return RL_GetWintertodtTimer()
end

-- Wintertodt warmth/brazier heat level (varbit 11434)
-- @return number
function APIOSRS.RL_GetWintertodtWarmth()
	return RL_GetWintertodtWarmth()
end

-- Query any varbit by ID at runtime.
-- See: https://static.runelite.net/runelite-api/apidocs/net/runelite/api/Varbits.html
-- @param varbitId number
-- @return number  raw varbit value, or -1 on failure
function APIOSRS.Rl_GetVarbit(varbitId)
	return Rl_GetVarbit(varbitId)
end

--https://static.runelite.net/runelite-api/apidocs/constant-values.html#net.runelite.api.SpriteID
--UNUSED_PRAYER_PROTECT_FROM_SUMMONING	944
-- draws a sprite above the local player's head
-- @param spriteId number
function APIOSRS.RL_DrawSpriteHead(spriteId)
	return RL_DrawSpriteHead(spriteId)
end

-- draws sprites at a list of world positions
-- @param spriteTargets WPOINT[] where WPOINT is x = coord x, y = coord y, z = spriteId
function APIOSRS.RL_DrawSprites(spriteTargets)
	return RL_DrawSprites(spriteTargets)
end

---@class AllObject
---@field Id number
---@field Name string
---@field Type number  0=Object 1=NPC 2=Player 3=GroundItem 4=WorldEntity 5=Projectile
---@field Distance number
---@field Anim number
---@field Cmb_lv number
---@field Life number
---@field Amount number
---@field Action string
---@field Bool1 number
---@field Floor number
---@field CalcX number
---@field CalcY number
---@field TileX number
---@field TileY number
---@field Mem number
---@field MemE number
---@field Tile_XYZ {x:number, y:number, z:number}
---@field Pixel_XYZ {x:number, y:number, z:number}
---@field Head_XYZ {x:number, y:number, z:number}
---@field Start_Tile_XYZ {x:number, y:number, z:number}
---@field End_Tile_XYZ {x:number, y:number, z:number}

--- Returns all entities currently tracked by the engine.
--- Filters: types 0=Object 1=NPC 2=Player 3=GroundItem 4=WorldEntity 5=Projectile
-- @param types number[]|nil   entity type filter list
-- @param names string[]|nil   entity name filter list
-- @param ids number[]|nil     entity ID filter list
-- @return AllObject[]
function APIOSRS.ReadAllObjectsArray(types, ids, names)
	types    = types    or {-1}
	names    = names    or {}
	ids      = ids      or {}
	return ReadAllObjectsArray(types, ids, names)
end

--- returns first found
-- @param types number[]|nil   entity type filter list
-- @param names string[]|nil   entity name filter list
-- @param ids number[]|nil     entity ID filter list
-- @param distance number  	   distance filter, only returns object if distance is less than this value, default 50
-- @return AllObject
function APIOSRS.ReadAllObjectsArrayFirst(types, ids, names, distance)
	types    = types    or {-1}
	names    = names    or {}
	ids      = ids      or {}
	distance    = distance or 50
	local object = ReadAllObjectsArray(types, ids, names)
    if object ~= nil and #object > 0 and object[1].Distance < distance then
		return object[1]
	else
		return nil
	end
end

--- Calculates the tile distance between two AllObject entries using their world coordinates.
--- Useful when you need the separation between two arbitrary entities rather than
--- the distance from the local player.
-- @param obj1 AllObject
-- @param obj2 AllObject
-- @return number  Euclidean tile distance, or -1 if either argument is nil
function APIOSRS.GetDistanceBetweenObjects(obj1, obj2)
	if obj1 == nil or obj2 == nil then return -1 end
	local dx = obj1.Tile_XYZ.x - obj2.Tile_XYZ.x
	local dy = obj1.Tile_XYZ.y - obj2.Tile_XYZ.y
	return math.sqrt(dx * dx + dy * dy)
end














































































--============================================================================
-- Entity actions. Interact with the game world without searching the mouse
-- menu: every entry does a real mouse click on the entity's own screen pixel
-- (AllObject.Pixel_XYZ) and rewrites the action it produced. No pixel
-- arguments are ever passed by scripts.
--
-- operation codes are legacy and map to 1-based menu options:
--   NPC      9..13          -> options 1..5   (9 = default click, e.g. Talk-to)
--   OBJECT   3..7           -> options 1..5   (3 = default click, e.g. Chop down)
--   GROUND   20,21,22,24,25 -> options 1..5   (20 = Take; note 23 is walk)
--   PLAYER   2045..2052     -> options 1..8
--   WALK     23
--
-- Selection rules:
--   npc/player: by Unique_Id (unique per entity, even with 1k same-id on screen).
--     Unique_Id is regenerated every client session - always resolve it from
--     ReadAllObjectsArray at runtime (health/coords/name), never hardcode.
--   objects/ground items: by config id + world tile (they have no unique id)
--============================================================================

--- Act on one specific entity table from ReadAllObjectsArray. The caller is
--- responsible for the entity being loaded in.
-- @param obj AllObject
-- @param operation number
-- @return boolean
function APIOSRS.DoAction_Direct(obj, operation)
	return OSRS_DoAction_Direct(obj, operation)
end

--- NPC/player by Unique_Id: first matching entity in the list, then Direct.
--- NOTE: Unique_Id is generated per client session (npc/player runtime key).
--- Never hardcode it - resolve it at runtime from ReadAllObjectsArray, for
--- example by health/coordinates/name, then pass it here.
-- @param uid number          AllObject.Unique_Id
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_UID(uid, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_UID(uid, operation, distance)
end

--- Nearest NPC by config id.
-- @param id number
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_NPC(id, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_NPC(id, operation, distance)
end

--- Nearest NPC by name.
-- @param name string
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_NPC_str(name, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_NPC_str(name, operation, distance)
end

--- Nearest player by name.
-- @param name string
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_Player(name, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_Player(name, operation, distance)
end

--- Nearest object by config id.
-- @param id number
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_DOBJ(id, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_DOBJ(id, operation, distance)
end

--- Nearest object by cache name (LocType).
-- @param name string
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_DOBJ_str(name, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_DOBJ_str(name, operation, distance)
end

--- Object by config id at an exact world tile.
-- @param id number
-- @param operation number
-- @param tilex number
-- @param tiley number
-- @param plane number|nil default 0 (0 = any plane)
-- @return boolean
function APIOSRS.DoAction_DOBJ_Tile(id, operation, tilex, tiley, plane)
	plane = plane or 0
	return OSRS_DoAction_DOBJ_Tile(id, operation, WPOINT.new(tilex, tiley, plane))
end

--- Nearest ground item by config id.
-- @param id number
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_GI(id, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_GI(id, operation, distance)
end

--- Nearest ground item by cache name (ObjType).
-- @param name string
-- @param operation number
-- @param distance number|nil default 10
-- @return boolean
function APIOSRS.DoAction_GI_str(name, operation, distance)
	distance = distance or 10
	return OSRS_DoAction_GI_str(name, operation, distance)
end

--- Ground item by config id at an exact world tile.
-- @param id number
-- @param operation number
-- @param tilex number
-- @param tiley number
-- @param plane number|nil default 0 (0 = any plane)
-- @return boolean
function APIOSRS.DoAction_GI_Tile(id, operation, tilex, tiley, plane)
	plane = plane or 0
	return OSRS_DoAction_GI_Tile(id, operation, WPOINT.new(tilex, tiley, plane))
end

--- Walk to a world tile by clicking its screen position.
-- @param tilex number
-- @param tiley number
-- @param plane number|nil default 0
-- @return boolean
function APIOSRS.DoAction_Tile(tilex, tiley, plane)
	plane = plane or 0
	return OSRS_DoAction_Tile(WPOINT.new(tilex, tiley, plane))
end

--- Interface action: click a component and substitute the option byte of the
--- widget task the click produced. The widget/slot/item come from the click;
--- only the option (raw engine byte: bank withdraw = 1, inventory "Wield" = 3)
--- is rewritten. Sniff valid option bytes with the key132 "DO:action" dump.
--- Component triple matches the interface draw cache ids, e.g. inventory
--- slot 1 = (149, 0, 1), bank slot 22 = (12, 12, 22).
-- @param id1 number         interface group id (e.g. 149 inventory, 12 bank)
-- @param id2 number         container component id (e.g. 0 inventory, 12 bank)
-- @param id3 number         slot/child id (e.g. 1)
-- @param option number      raw engine option byte (desc[2]); 0 = keep clicked
-- @param item_id number|nil item id override (desc[4]); 0/nil = keep clicked
-- @return boolean
function APIOSRS.DoAction_Interface2(id1, id2, id3, option, item_id)
	return OSRS_DoAction_Interface2(id1, id2, id3, option, item_id or 0)
end

return APIOSRS