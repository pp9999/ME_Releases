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
-- @return boolean
function APIOSRS.RL_ClickEntity(type, entityID, max_distance, localtile, tilex, tiley)
	max_distance = max_distance or 15
	localtile = localtile or false
	tilex = tilex or 0
	tiley = tiley or 0
	return RL_ClickEntity(type, entityID, max_distance, localtile, tilex, tiley)
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

function APIOSRS.RL_ClickWig(widgetid, spriteid, action, name, xoffset, rightside, yoffset, bottomside)
	return RL_ClickWig(widgetid, spriteid, action, name, xoffset, rightside, yoffset, bottomside)
end

function APIOSRS.RL_ClickCloseBank()
	return RL_ClickCloseBank()
end

function APIOSRS.RL_IsBankOpen()
	return RL_IsBankOpen()
end

function APIOSRS.RL_ClickBankDepositAll()
	return RL_ClickBankDepositAll()
end
















































































return APIOSRS