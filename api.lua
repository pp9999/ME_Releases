local API = {}

--- API Version will increase with breaking changes
API.VERSION = 1.072

--[[
Known shortcuts
Ctrl+shift == mark tiles
Insert == disable rendering
Home == hide focus window
Ctrl+home == unhide window
End == end Script
Page_up == disable ImGui
Page_down == enable ImGui
]]--

--- General action on some objects, like bank chest
API.OFF_ACT_GeneralObject_route00 = GeneralObject_route00

--- General action on some objects, like bank chest
API.OFF_ACT_GeneralObject_route0 = GeneralObject_route0

--- General action on some objects
API.OFF_ACT_GeneralObject_route1 = GeneralObject_route1

--- General action on some objects
API.OFF_ACT_GeneralObject_route2 = GeneralObject_route2

--- General action on some objects
API.OFF_ACT_GeneralObject_route3 = GeneralObject_route3

--- default act npc 0x29
API.OFF_ACT_InteractNPC_route = InteractNPC_route

--- default attack npc
API.OFF_ACT_AttackNPC_route = AttackNPC_route

--- second option
API.OFF_ACT_InteractNPC_route2 = InteractNPC_route2

--- third option
API.OFF_ACT_InteractNPC_route3 = InteractNPC_route3

--- fourth option
API.OFF_ACT_InteractNPC_route4 = InteractNPC_route4

--- default item pickup
API.OFF_ACT_Pickup_route = Pickup_route

--- walk to tile
API.OFF_ACT_Walk_route = Walk_route

--- special face route for bladed dive, familiar attack, use in inv
API.OFF_ACT_Bladed_interface_route = Bladed_interface_route

--- option in chat box
API.OFF_ACT_GeneralInterface_Choose_option = GeneralInterface_Choose_option

---
API.OFF_ACT_Vs_player_attack_route = Vs_player_attack_route

--- General action on lootwindow, also most numbererfaces
API.OFF_ACT_GeneralInterface_route = GeneralInterface_route

--- note stuff, use item on empty inv spot, use item on item
API.OFF_ACT_GeneralInterface_route1 = GeneralInterface_route1

--- take bob/store bob/drop items
API.OFF_ACT_GeneralInterface_route2 = GeneralInterface_route2

---
API.OFF_ACT_Vs_player_follow_route = Vs_player_follow_route

---
API.OFF_ACT_Vs_player_trade_route = Vs_player_trade_route

---
API.OFF_ACT_Vs_player_examine_route = Vs_player_examine_route

--- Bladed dive teleport
API.OFF_ACT_Special_walk_route = Special_walk_route

--- use on fire
API.GeneralObject_route_useon = GeneralObject_route_useon

API.GeneralObject_route_examine = GeneralObject_route_examine
API.InteractNPC_route_examine = InteractNPC_route_examine
API.Grounditems_route_examine = Grounditems_route_examine

--- somtimes text on interface
---@return number
API.I_00textP = I_00textP

--- somtimes other text on interface
---@return number
API.I_itemids3 = I_itemids3

--- somtimes item ids
---@return number
API.I_itemids = I_itemids

--- somtimes item stack size
---@return number
API.I_itemstack = I_itemstack

---@return number
API.I_slides = I_slides

---@return number
API.I_buffb = I_buffb

--- checks if bool is true. it is now always enabled so means nothing now. IsCacheLoaded check is more sensible nows
---@return boolean
API.CacheEnabled = CacheEnabled

-- Get those from "Splats diagnosis"
---@param clear boolean clean array
---@return SPLAT
function API.GatherEvents_splat_check(clear)
	return GatherEvents_splat_check(clear)
end


-- Turn on/off default on
---@param state boolean
---@return void
function API.TurnOffMrHasselhoff(state)
	return TurnOffMrHasselhoff(state)
end

-- Turn on/off default on, Limit actions 1 per frame
---@param state boolean
---@return void
function API.SetDoActionLimit(state)
	return SetDoActionLimit(state)
end

-- Turn on/off default off, Simulate mouse movement pre click
---@param state boolean
---@return void
function API.SetMouseMove(state)
	return SetMouseMove(state)
end

-- Turn on/off default on, disable doaction
---@param state boolean
---@return void
function API.SetDoAction(state)
	return SetDoAction(state)
end

-- Turn on/off default on, disable software flag override
---@param state boolean
---@return void
function API.SetHookModifaction(state)
	return SetHookModifaction(state)
end

-- Turn on/off default on. FM random movement
---@param state boolean
---@return void
function API.SetFMRandom(state)
	return SetFMRandom(state)
end

-- current world of localplayer
---@return number
function API.GetWorldNR()
	return GetWorldNR()
end

-- Check if Cache is successfully loaded
---@return boolean
function API.IsCacheLoaded()
	return IsCacheLoaded()
end

-- Dont let selection reset, using ability on action or item on item
-- Before selective doAction
---@return boolean
function API.DoAction_DontResetSelection()
	return DoAction_DontResetSelection()
end

-- Unhhook THE hook
---@return void
function API.UnhookRs3Hook()
	return UnhookRs3Hook()
end

-- if it still can reset returns true
---@return bool
function API.IsAuraResetAvailable()
	return IsAuraResetAvailable()
end

-- if it still can reset returns true
---@return bool
function API.IsAuraXPAvailable()
	return IsAuraXPAvailable()
end

-- check if has items to reclaim from death
---@return bool
function API.HasDeathItemsReclaim()
	return HasDeathItemsReclaim()
end

-- in area, normal area not quests
---@return bool
function API.IsInDeathOffice()
	return IsInDeathOffice()
end

-- if it is then returns true
---@return bool
function API.IsPremiumMember()
	return IsPremiumMember()
end

---@return table|string
function API.ReturnConsoleLog()
	return ReturnConsoleLog()
end

---@return table|string
function API.ReturnScriptLog()
	return ReturnScriptLog()
end

-- @param path string expects cpp format // double slashes
---@return table|string
function API.ReadTextString(path)
	return ReadTextString(path)
end

-- @param append bool either to clear or add
-- @param text string
-- @param path string expects cpp format // double slashes
---@return void
function API.StoreTextString(path, text, append)
	return StoreTextString(path, text, append)
end

-- @param append bool either to clear or add
-- @param text table|string
-- @param path string expects cpp format // double slashes
---@return void
function API.StoreTextStringArray(path, text, append)
	return StoreTextStringArray(path, text, append)
end

-- returns 4 strings per player, name, prev name, full world name, note
-- its NOT interface read, it is own separate table
---@return table|string
function API.ReadFriendList()
	return ReadFriendList()
end

-- returns 3 strings per player, name, prev name, note
-- its NOT interface read, it is own separate table
---@return table|string
function API.ReadIgnoreList()
	return ReadIgnoreList()
end

-- returns 2 strings per player, name, full world name
-- its NOT interface read, it is own separate table
---@return table|string
function API.ReadFriendChatList()
	return ReadFriendChatList()
end

--Hide rendering, switch
function API.HidePlayers()
	return HidePlayers()
end

--Hide rendering, switch
function API.HideNPCs()
	return HideNPCs()
end

--Read localplayer name from data pointer
---@return string
function API.ReadLPNameP()
	return ReadLPNameP()
end

--[[
Attack 0
Defence 2
Strength 4
Hittpoints 6
Range 8
Prayer 10
Magic 12
Cooking 14
Woodcutting 16
Fletching 18
Fishing 20
Firemaking 22
Crafting 24
Smithing 26
Mining 28
Herblaw 30
Agility 32
Thieving 34
Slayer 36
Farming 38
Runecrafting 40
Hunter 42
Construction 44
Summoning 46
Dungeoneering 48
Divination 50
Invention 52
Archaeology 54
Necromancy 56
]]--
---@param nr number +1 is boosted
---@return number
function API.GetSkillsTableSkill(nr)
	return GetSkillsTableSkill(nr)
end

--Tries to calculate correct coords for interface. Only works if internal data is correct
---@param mad InterfaceComp5
---@return table|WPOINT 4 corner points of the cube
function API.InterfacesCombineFullFM(mad)
	return InterfacesCombineFullFM(mad)
end

-- Disable ImGui for script runtime so it dosent mess with script. Page down to enable again or if script ends it gets enabled again
function API.DisableImGui()
	return DisableImGui()
end

-- Read pixel color at coordinates
---@param at_x number
---@param at_y number
---@return table of summary rgb colors, [1] red, [2] green, [3] blue, [4] sum
function API.ReadDCColor(at_x,at_y)
	return ReadDCColor(at_x,at_y)
end

-- check tiles in list against tile +- range
---@param occtiles table|FFPOINT will be trunc, tiles to avoid
---@param size number, dangerous tile area size to avoid, 0 is 1 tile, 1 is 3x3, 2 is 5x5 etc
---@param range number, how big virtual area to generate tiles
---@param BlockedTiles table|FFPOINT 1 tile size extra blocked tiles
---@return  table|FFPOINT tiles that isnt near our occtiles 
function API.Math_FreeTilesTile(tile,occtiles,size,range,BlockedTiles,DrawDebugTiles)
	DrawDebugTiles = DrawDebugTiles or false
	return Math_FreeTilesTile(tile,occtiles,size,range,BlockedTiles,DrawDebugTiles)
end

-- check tiles in list against localplayer +- range
---@param occtiles table|FFPOINT will be trunc
---@param size number
---@param range number
---@param BlockedTiles table|FFPOINT 1 tile size extra blocked tiles
---@return  table|FFPOINT tiles that isnt near our occtiles 
function API.Math_FreeTiles(occtiles,size,range,BlockedTiles,DrawDebugTiles)
	DrawDebugTiles = DrawDebugTiles or false
	return Math_FreeTiles(occtiles,size,range,BlockedTiles,DrawDebugTiles)
end

-- Make it flat
---@param tile FFPOINT
---@return FFPOINT
function API.Math_FlattenFloat(tile)
	return Math_FlattenFloat(tile)
end

-- Make it flat
---@param tiles table|FFPOINT
---@return table|FFPOINT
function API.Math_FlattenFloatArray(tiles)
	return Math_FlattenFloatArray(tiles)
end

-- by distance from tile
---@param objects table|AllObject
---@return table|AllObject
function API.Math_SortAODistFromA(tile,objects)
	return Math_SortAODistFromA(tile,objects)
end

--by distance from localplayer
---@param objects table|AllObject
---@return table|AllObject
function API.Math_SortAODistA(objects)
	return Math_SortAODistA(objects)
end

-- by distance from tile
---@param objects table|AllObject
---@return AllObject
function API.Math_SortAODistFrom(tile,objects)
	return Math_SortAODistFrom(tile,objects)
end

--by distance from localplayer
---@param objects table|AllObject
---@return AllObject
function API.Math_SortAODist(objects)
	return Math_SortAODist(objects)
end

---@return number
function API.Local_PlayerInterActingWith_UID()
	return Local_PlayerInterActingWith_UID()
end

---@param id number
---@return AllObject
function API.GetMapIcon(id)
	return GetMapIcon(id)
end

---@param id number
---@param x number
---@param y number
---@return AllObject
function API.GetMapIconTile(id,x,y)
	return GetMapIconTile(id,x,y)
end

---@param id number
---@return AllObject|table
function API.GetMapIcons(id)
	return GetMapIcons(id)
end

---@return AllObject|table
function API.GetALLMapIcons()
	return GetALLMapIcons()
end

---@param id number
---@return boolean
function API.DoAction_Icon(id)
	return DoAction_Icon(id)
end

---@param id number
---@param x number
---@param y number
---@return boolean
function API.DoAction_IconTile(id,x,y)
	return DoAction_IconTile(id,x,y)
end

---@param idobj AllObject
---@return boolean
function API.DoAction_IconObj(idobj)
	return DoAction_IconObj(idobj)
end

---@param point FFPOINT
---@return FFPOINT
function API.Math_TileToGlobal(point)
	return Math_TileToGlobal(point)
end

---@param point FFPOINT
---@return FFPOINT
function API.Math_TileToLocal(point)
	return Math_TileToLocal(point)
end

---@return EventData
function API.GatherEvents_chat_check()
	return GatherEvents_chat_check()
end
---@return EventData
function API.GatherEvents_xp_check()
	return GatherEvents_xp_check()
end
---@return EventData
function API.GatherEvents_glisten_check()
	return GatherEvents_glisten_check()
end

--- Player position against tile and get distance
---@param wp WPOINT
---@return number
function API.Dist_FLPW(wp)
	return Dist_FLPW(wp)
end

--- Player position against tile and get distance
---@param fp FFPOINT
---@return number
function API.Dist_FLP(fp)
	return Dist_FLP(fp)
end

--- get container data
---@param cont_id number -- container id
---@return inv_Container_struct[]
function API.Container_Get_all(cont_id)
	return Container_Get_all(cont_id)
end

--- get container data
---@param item_id number -- find item
---@param cont_vec inv_Container_struct[] -- container
---@return inv_Container_struct
function API.Container_Findfrom(cont_vec,item_id)
	return Container_Findfrom(cont_vec,item_id)
end

--- get container data
---@param item_id number -- find item
---@param cont_id number -- container id
---@return inv_Container_struct
function API.Container_Get_s(cont_id,item_id)
	return Container_Get_s(cont_id,item_id)
end

--- Check if items are there by table of ids
---@param item_ids number[] -- find items
---@param cont_id number -- container id
---@return boolean
function API.Container_Check_Items(cont_id,item_ids)
	return Container_Check_Items(cont_id,item_ids)
end

--- get container data, get all items with those ids
---@param item_id number[] -- find items
---@param cont_id number -- container id
---@return inv_Container[]_struct
function API.Container_Get_AllItems(cont_id,item_ids)
	return Container_Get_AllItems(cont_id,item_ids)
end


--- get container
---@param cont_id number
---@return boolean --is container with id found
function API.Container_Get_Check(cont_id)
	return Container_Get_Check(cont_id)
end

--- get container data
---@param targetID number can be -1
---@return General_Container[] --vectors of custom tables
function API.GetContainerSettings(targetID)
	return GetContainerSettings(targetID)
end

--- Encodes a Lua table to a JSON string
-- @return string The JSON-encoded string
function API.JsonEncode(jsonString)
	return JsonEncode(jsonString)
end

--- Decodes a JSON string to a Lua table.
-- @return table The decoded Lua table.
function API.JsonDecode(jsonString)
	return JsonDecode(jsonString)
end

--- check
---@return boolean
function API.IsMember()
	return IsMember()
end

--- print out to DeBox in ME graphic debug
---@param text string
---@param level number
---@param time boolean
---@return void
function API.printlua(text, level, time)
	return printlua(text, level, time)
end

--- enable render
---@return void
function API.EnableRThread()
	return EnableRThread()
end

--- disable render
---@return void
function API.DisableRThread()
	return DisableRThread()
end

---@return number
function API.Get_RSExeStart()
	return Get_RSExeStart()
end

---@return number
function API.Get_RSExeSize()
	return Get_RSExeSize()
end

---@return number
function API.Get_HWND_GL()
	return Get_HWND_GL()
end

---@return number
function API.Get_HWND()
	return Get_HWND()
end

---@return number
function API.Get_PID()
	return Get_PID()
end

---@return number
function API.Get_HANDLE()
	return Get_HANDLE()
end

---@return number
function API.Read_fake_mouse_do()
	return Read_fake_mouse_do()
end

---@param state boolean
---@return number
function API.Write_fake_mouse_do(state)
	return Write_fake_mouse_do(state)
end

--- get localplayer name.
---@return string
function API.GetLocalPlayerName()
	return GetLocalPlayerName()
end

--- get localplayer memory address. is zero when not logged in or not found
---@return number
function API.GetLocalPlayerAddress()
	return GetLocalPlayerAddress()
end

--- draw button, CreateIG_answer before loop once
---@param data IG_answer
---@return void
function API.DrawBox(data)
	return DrawBox(data)
end

--- draw line between points, start is start and size is end
---@param data IG_answer
---@return void
function API.DrawLine(data)
	return DrawLine(data)
end

--- draw progressbar, CreateIG_answer before loop once
--- uses radius for progress bar length/progress
--- autosizes to contents
---@param data IG_answer
---@param ondbl boolean
---@return void
function API.DrawProgressBar(data,ondbl)
	return DrawProgressBar(data,ondbl)
end

--- draw droplist, CreateIG_answer before loop once
---@param data IG_answer
---@param ondbl boolean
---@return void
function API.DrawListBox(data,ondbl)
	return DrawListBox(data,ondbl)
end

--- draw comb, CreateIG_answer before loop once
---@param data IG_answer
---@param ondbl boolean
---@return void
function API.DrawComboBox(data,ondbl)
	return DrawComboBox(data,ondbl)
end

--- draw ImGui table
--- data format
--[[
	local runs = 10
	local metrics = {
		{"Script","Necro Essence"},
		{"Runs",tostring(10)},
	}
]]
---@param data table
---@return void
function API.DrawTable(data)
	return DrawTable(data)
end

---@param val number
---@param addr number
---@return boolean
function API.Mem_Write_char(addr, val)
	return Mem_Write_char(addr, val)
end

---@param val number
---@param addr number
---@return boolean
function API.Mem_Write_short(addr, val)
	return Mem_Write_short(addr, val)
end

---@param val number
---@param addr number
---@return boolean
function API.Mem_Write_int(addr, val)
	return Mem_Write_int(addr, val)
end

---@param val number
---@param addr number
---@return boolean
function API.Mem_Write_uint64(addr, val)
	return Mem_Write_uint64(addr, val)
end

---@param addr number
---@return number
function API.Mem_Read_char(addr)
	return Mem_Read_char(addr)
end

---@param addr number
---@return number
function API.Mem_Read_short(addr)
	return Mem_Read_short(addr)
end

---@param addr number
---@return number
function API.Mem_Read_int(addr)
	return Mem_Read_int(addr)
end

---@param addr number
---@return number
function API.Mem_Read_uint64(addr)
	return Mem_Read_uint64(addr)
end

---@param status string
---@return void
function API.Write_ScripCuRunning0(status)
	return Write_ScripCuRunning0(status)
end

---@param status string
---@return void
function API.Write_ScripCuRunning1(status)
	return Write_ScripCuRunning1(status)
end

---@param status string
---@return void
function API.Write_ScripCuRunning2(status)
	return Write_ScripCuRunning2(status)
end

--- Return material storagedata
---@return table|IInfo
function API.MaterialStorage()
	return MaterialStorage()
end

---Return trade window item array
---Default will return your own trade window (your offer) param set to "their" will return their offer
---@param which string optional "their" or default "self"
---@return table|IInfo
function API.TradeWindow(which)
	return TradeWindow(which)
end

--- Return array of bank inventory
---@return table|IInfo
function API.FetchBankInvArray()
	return FetchBankInvArray()
end

--- Return array of bankdata
---@return table|IInfo
function API.FetchBankArray()
	return FetchBankArray()
end

--- Return miniprogressbar, smithing heat, arch progress
---@return number
function API.LocalPlayer_HoverProgress()
	return LocalPlayer_HoverProgress()
end

--- change paint state
---@param value boolean
---@return void
function API.Write_Doaction_paint(value)
	return Write_Doaction_paint(value)
end

--- save setting from file
---@param value number --0-255
---@param settingfilename string
---@return number
function API.LoadIntSetting(settingfilename, value)
	return LoadIntSetting(settingfilename, value)
end

--- save setting to file
---@param value number --0-255
---@param slot number slot --0-30
---@param settingfilename string
---@return void
function API.SaveIntSetting(settingfilename, slot, value)
	return SaveIntSetting(settingfilename, slot, value)
end

--- draw tickbox at, CreateIG_answer before loop once
---@param data IG_answer
---@return void
function API.DrawCheckbox(data)
	return DrawCheckbox(data)
end

--- draw filled square at, CreateIG_answer before loop once
---@param data IG_answer
---@return void
function API.DrawSquareFilled(data)
	return DrawSquareFilled(data)
end

--- draw text at, CreateIG_answer before loop once
---@param data IG_answer
---@return void
function API.DrawTextAt(data)
	return DrawTextAt(data)
end

--- draw text at, CreateIG_answer before loop once
---@param data IG_answer
---@return void
function API.DrawTextAtBG(data)
	return DrawTextAtBG(data)
end

--- create data struct pointer
---@return IG_answer
function API.CreateIG_answer()
	return CreateIG_answer()
end

--- Delete all data, maybe dont touch during running
function API.DeleteIG_answers()
	return DeleteIG_answers()
end

--- create empty AllObject --couldnt figure out how to do it in lua
---@return AllObject
function API.Create_AO_struct()
	return Create_AO_struct()
end

--- Delete all data
function API.DeleteAllObject_list()
	return DeleteAllObject_list()
end

--- create FFPOINT
---@param x number
---@param y number
---@param z number
---@return FFPOINT
function API.CreateFFPOINT(x,y,z)
	return CreateFFPOINT(x,y,z)
end

--- get current tick count
---@return number
function API.Get_tick()
	return Get_tick()
end

--- count ticks
---@param val number --how many ticks
---@return boolean
function API.Count_ticks(val)
	return Count_ticks(val)
end

--- check if tick is happening
---@return boolean
function API.Check_tick()
	return Check_tick()
end

--- sleep how many ticks, on avarage tick is 600m
---@param count number --number of ticks
---@return boolean
function API.Sleep_tick(count)
	return Sleep_tick(count)
end

--- check if it is
---@param ability_name string
---@return boolean
function API.isAbilityAvailable(ability_name)
	return isAbilityAvailable(ability_name)
end

--- check if processing/crafting/progress window is open
---@return boolean
function API.isProcessing()
	return isProcessing()
end

--- get player facing direction in angles
---@return number
function API.calculatePlayerOrientation()
	return calculatePlayerOrientation()
end

--- is localplayer facing in direction of tile. to be safeside it should be more than 1 tile away
---@param Tile WPOINT
---@param howfar number -- in tiles
---@param errorrange number -- starts from 0 - 1
---@return boolean
function API.IsPlayerInDirection(Tile, howfar, errorrange)
	return IsPlayerInDirection(Tile, howfar, errorrange)
end

--- is localplayer facing in direction of tile
---@param input WPOINT -- tile 
---@param angle number -- int
---@param steps number -- int
---@return table|WPOINT
function API.Math_AnglePixels(input,angle,steps)
	return Math_AnglePixels(input,angle,steps)
end

--- is localplayer facing in direction of tile
---@param ArrayOfPoints table|WPOINT -- vectors of tiles to check vs
---@param OnePoint WPOINT -- tile vs
---@param inrangeof number -- how far to predict
---@return boolean
function API.Math_PointsCrossEach(ArrayOfPoints, OnePoint, inrangeof)
	return Math_PointsCrossEach(ArrayOfPoints, OnePoint, inrangeof)
end

--- get facing direction in angles
---@param mem_addr number --AllObject MemE
---@return number
function API.calculateOrientation(mem_addr)
	return calculateOrientation(mem_addr)
end

--- Create FFPOINT vector
function API.CreateFFPointArray(points)
	local arr = CreateArrayFFPOINT()

	for i,v in ipairs(points) do
		arr:add(FFPOINT:new(v[1], v[2], v[3]))
	end

	return arr
end

--- Random number
---@param numbersize number
---@return number
function API.Math_RandomNumber(numbersize)
	return Math_RandomNumber(numbersize)
end

--- Write script loop boolean
---@param bools boolean
function API.Write_LoopyLoop(bools)
	return Write_LoopyLoop(bools)
end

--- Read script loop boolean
---@return number 0 or 1, false or true
function API.Read_LoopyLoop()
	return Read_LoopyLoop()
end

--- Get window in pixels
---@return WPOINT
function API.GetRsResolution2()
	return GetRsResolution2()
end

--- Get 4 box
---@return QWPOINT
function API.GetRSCornersReal()
	return GetRSCornersReal()
end

--- Distance between 2 objets
---@param object1 AllObject
---@param object2 AllObject
---@return number
function API.Math_DistanceA(object1, object2)
	return Math_DistanceA(object1, object2)
end

--- Calculate pixels
---@param entity FFPOINT
---@return FFPOINT
function API.Math_W2Sv2(entity)
	return Math_W2Sv2(entity)
end

--- Calculate pixels
---@param entity FFPOINT
---@return WPOINT
function API.Math_W2Sv2W(entity)
	return Math_W2Sv2W(entity)
end

--- Distance between 2 objets
---@param object1 WPOINT
---@param object2 WPOINT
---@return number
function API.Math_DistanceRounded(object1, object2)
	return Math_DistanceRounded(object1, object2)
end

--- Distance between 2 objets
---@param object1 WPOINT
---@param object2 WPOINT
---@return number
function API.Math_DistanceW(object1, object2)
	return Math_DistanceW(object1, object2)
end

--- Distance between 2 objets
---@param object1 FFPOINT
---@param object2 FFPOINT
---@return number
function API.Math_DistanceF(object1, object2)
	return Math_DistanceF(object1, object2)
end

--- Save FFPOINTs to disk
---@param name string
---@param array_points table|FFPOINT
---@return boolean
function API.SaveFFPOINTs(name, array_points)
	return SaveFFPOINTs(name, API.CreateFFPointArray(array_points))
end

---@param name string
---@return table|FFPOINT
function API.LoadFFPOINTs(name)
	return LoadFFPOINTs(name)
end

---@return WPOINT
function API.GetTilesUnderCurrentMouse()
	return GetTilesUnderCurrentMouse()
end

---@return FFPOINT
function API.GetTilesUnderCurrentMouseF()
	return GetTilesUnderCurrentMouseF()
end

---@param xy WPOINT
---@return WPOINT
function API.TilesToPixelsWW(xy)
	return TilesToPixelsWW(xy)
end

---@param xy FFPOINT
---@return WPOINT
function API.TilesToPixelsFW(xy)
	return TilesToPixelsFW(xy)
end

---@param xy FFPOINT
---@return FFPOINT
function API.TilesToPixelsFF(xy)
	return TilesToPixelsFF(xy)
end

---@param xy WPOINT
---@return FFPOINT
function API.TilesToPixelsWF(xy)
	return TilesToPixelsWF(xy)
end

---@param mxy WPOINT
---@return boolean
function API.ScreenFilter(mxy)
	return ScreenFilter(mxy)
end

---@param SummPointer number
---@param howmanyBytes number --something like 250
---@return string
function API.ReadChars(SummPointer, howmanyBytes)
	return ReadChars(SummPointer, howmanyBytes)
end

---@param SummPointer number
---@param howmanyBytes number --something like 250
---@return string
function API.ReadCharsLimitPointer(SummPointer, howmanyBytes)
	return ReadCharsLimitPointer(SummPointer, howmanyBytes)
end

---@param SummPointer number
---@param howmanyBytes number --something like 250
---@return string
function API.ReadCharsLimit(SummPointer, howmanyBytes)
	return ReadCharsLimit(SummPointer, howmanyBytes)
end

---@param SummPointer number
---@return string
function API.ReadCharsPointer(SummPointer)
	return ReadCharsPointer(SummPointer)
end

---@param limitx number
---@param limity number
---@return boolean
function API.CheckCoordLimit(limitx, limity)
	return CheckCoordLimit(limitx, limity)
end

---@param limitx number --float
---@param limity number --float
---@return boolean
function API.CheckCoordLimit2(limitx, limity)
	return CheckCoordLimit2(limitx, limity)
end

---@param limitx number --float
---@param limity number --float
---@return boolean
function API.CheckVisibleLimit(limitx, limity)
	return CheckVisibleLimit(limitx, limity)
end

---@return boolean
function API.PlayerLoggedIn()
	return PlayerLoggedIn()
end

---dosent work
---@param text string
---@return boolean
function API.Select_Option(text)
	return Select_Option(text)
end

---@param text string
---@return number --char
function API.Dialog_Option(text)
	return Dialog_Option(text)
end

---@return string
function API.Dialog_Read_NPC()
	return Dialog_Read_NPC()
end

---@return string
function API.Dialog_Read_Player()
	return Dialog_Read_Player()
end

---@param search_word string
---@return boolean
function API.Dialog_compare_sayd(search_word)
	return Dialog_compare_sayd(search_word)
end

---@return boolean
function API.Check_Dialog_Open()
	return Check_Dialog_Open()
end

---@return boolean
function API.Check_continue_Open()
	return Check_continue_Open()
end

---@return boolean
function API.Check_continue_Open_NPC()
	return Check_continue_Open_NPC()
end

---@return boolean
function API.Check_continue_Open_Player()
	return Check_continue_Open_Player()
end

---@return number
function API.GetFloorLv_2()
	return GetFloorLv_2()
end

---@param item table|number
---@return boolean
function API.FindGItemBool_(item)
	return FindGItemBool_(item)
end

---@param NPC_name string
---@param maxdistance number
---@return table|AllObject
function API.FindNPCbyName(NPC_name, maxdistance)
	return FindNPCbyName(NPC_name, maxdistance)
end

---@return number
function API.ReadPlayerAnim()
	return ReadPlayerAnim()
end

---@param GetCombatData boolean if true get hp and name
---@return Target_data
function API.ReadTargetInfo99(GetCombatData)
GetCombatData = GetCombatData or true
	return ReadTargetInfo99(GetCombatData)
end

---@return AllObject
function API.ReadLpInteracting()
	return ReadLpInteracting()
end

---@param animated_also boolean
---@param hp number
---@return table|AllObject
function API.OthersInteractingWithLpNPC(animated_also, hp)
	return OthersInteractingWithLpNPC(animated_also, hp)
end

---@param look_stance boolean
---@return table|AllObject
function API.OthersInteractingWithLpPl(look_stance)
	return OthersInteractingWithLpPl(look_stance)
end

---@param spot number
---@return string
function API.ReadText(spot)
	return ReadText(spot)
end

---@return FFPOINT
function API.PlayerCoordfloat()
	return PlayerCoordfloat()
end

---@return FFPOINT
function API.PlayerCoordfloatRaw()
	return PlayerCoordfloatRaw()
end

---@param addr number
---@return WPOINT
function API.GetProjectileDestination(addr)
	return GetProjectileDestination(addr)
end

---@param allObj AllObject
---@return WPOINT
function API.GetProjectileDestination(allObj)
	return GetProjectileDestination(allObj)
end

---@return void
function API.RandomSleep()
	return RandomSleep()
end

---@param wait number 100% sleep
---@param sleep number random sleep
---@param sleep2 number rare random sleep
---@return void
function API.RandomSleep2(wait, sleep, sleep2)
	return RandomSleep2(wait, sleep, sleep2)
end

---@param asciii string
---@return void
function API.TypeOnkeyboard(asciii)
	return TypeOnkeyboard(asciii)
end

---@param asciii string
---@return void
function API.TypeOnkeyboard2(asciii)
	return TypeOnkeyboard2(asciii)
end

---@param Loops number
---@return boolean
function API.CheckAnim(Loops)
	return CheckAnim(Loops)
end

---@return boolean
function API.ReadPlayerMovin()
	return ReadPlayerMovin()
end

---@return boolean
function API.ReadPlayerMovin2()
	return ReadPlayerMovin2()
end

-- old
--[[AllObject Types 
0 obj
1 npc
2 player
3 ground item
4 highlights
5 projectiles
8 tiles
12 decor
--]]
---@param obj table|number
---@param maxdistance number
---@param type table|number
---@return table|AllObject
function API.GetAllObjArrayInteract(obj, maxdistance, type)
	return GetAllObjArrayInteract(obj, maxdistance, type)
end

-- old
--[[AllObject Types 
0 obj
1 npc
2 player
3 ground item
4 highlights
5 projectiles
8 tiles
12 decor
--]]
---@param obj table|string
---@param maxdistance number
---@param type table|number
---@return table|AllObject
function API.GetAllObjArrayInteract_str(obj, maxdistance, type)
	return GetAllObjArrayInteract_str(obj, maxdistance, type)
end

-- old
---@param tile WPOINT
---@param item number
---@return boolean
function API.CheckTileforItems(tile, item)
	return CheckTileforItems(tile, item)
end

---@return WPOINT
--[[
returns x,y coords of the mouse cusor relative to the game window
]]
function API.GetMLoc()
	return GetMLoc()
end

---@param mK number --char
---@return void
function API.KeyPress_(mK)
	return KeyPress_(mK)
end

---@param mK number
---@return void
function API.KeyPress_2(mK)
	return KeyPress_2(mK)
end

---@return number
function API.SystemTime()
	return SystemTime()
end

---@param Data void*
---@param Size number
---@param InitialValue number
---@return number
function API.CRC32CheckSum(Data, Size, InitialValue)
	return CRC32CheckSum(Data, Size, InitialValue)
end

---@return string
function API.FindSideText()
	return FindSideText()
end

---@param ObjectName table|string
---@param maxdistance number
---@return table|AllObject
function API.FindObject_string(ObjectName, maxdistance)
	return FindObject_str(ObjectName, maxdistance)
end

---@param types table|number -- possible types are: 0,1,2,3,5,8,12,all -1
---@param ids table|number --place {-1} unless you know ids
---@param names table|string --leave empty with {}
---@return table|AllObject
function API.ReadAllObjectsArray(types, ids, names)
	return ReadAllObjectsArray(types, ids, names)
end

-- legacy, use Inventory class one instead
---@return table|IInfo
function API.ReadInvArrays33()
	return ReadInvArrays33()
end

---@return void
function API.Get_shop()
	return Get_shop()
end

---@return number
function API.GetPray_()
	return GetPray_()
end

---@return number
function API.GetPrayMax_()
	return GetPrayMax_()
end

-- Read from VBs
---@param id number
---@param pos number --0-31
---@return number
function API.VB_GetBit(id,pos)
	return VB_GetBit(id,pos)
end

-- number to bitset booleans and then check bit value at pos
---@param value number
---@param pos number --0-31
---@return boolean
function API.CheckBooleanBit(value,pos)
	return CheckBooleanBit(value,pos)
end

-- number to bitset booleans and then check bits value at poss
---@param value number
---@param poss table|number --0-31
---@return boolean
function API.CheckBooleanBits(value,poss)
	return CheckBooleanBits(value,poss)
end

-- Get bits from int
---@param value number
---@param poss table|number --0-31
---@return table|number
function API.GetBooleanBits(value,poss)
	return GetBooleanBits(value,poss)
end

---@param to_print number
---@return void
function API.VB_PrintBits_all(to_print)
	return VB_PrintBits_all(to_print)
end

---@return boolean
function API.GetInCombBit()
	return GetInCombBit()
end

---@return boolean
function API.IsTargeting()
	return IsTargeting()
end

---@return number
function API.GetAddreline_()
	return GetAddreline_()
end

---@return number
function API.GetAdrenalineFromInterface()
	return GetAdrenalineFromInterface()
end

--- smithing 85, bank open 24, 1 log out menu, 8 chat open, 9 quick chat open, 13 teleport options, 18 clue, 24 bank, 30 lode, 57 glider
--- status of blocking intefaces
--- checks both set1 and set2 any match in those 2 bytes
---@param status number
---@param debug boolean
---@return boolean
function API.Compare2874Status(status, debug)
	return Compare2874Status(status, debug)
end

--- varbit 7755 bank check, 64 = open
---@return boolean
function API.CheckBankVarp()
	return CheckBankVarp()
end

---@return number
function API.GetG3095Status()
	return GetG3095Status()
end

---@return number
function API.GetHP_()
	return GetHP_()
end

---@return number
function API.GetHPMax_()
	return GetHPMax_()
end

---@return number
function API.GetHPrecent()
	return GetHPrecent()
end

---@return number
function API.GetPrayPrecent()
	return GetPrayPrecent()
end

---@return number
function API.GetSummoningPoints_()
	return GetSummoningPoints_()
end

---@return number
function API.GetSummoningMax_()
	return GetSummoningMax_()
end

--Set the maximum idle time in minutes
--Automatically send keypresses to avoid idle kick
--@return void
function API.SetMaxIdleTime(minutes)
	return SetMaxIdleTime(minutes)
end

---@return void
function API.PIdle1()
	return PIdle1()
end

---@return void
function API.PIdle22()
	return PIdle22()
end

---@return void
function API.PIdle2()
	return PIdle2()
end

---@param x number
---@param xrange number
---@param y number
---@param yrange number
---@param zfloor number
---@return boolean
function API.PInArea(x, xrange, y, yrange, zfloor)
	return PInArea(x, xrange, y, yrange, zfloor)
end

---@param norm_tile WPOINT
---@param range number
---@return boolean
function API.PInAreaW(norm_tile, range)
	return PInAreaW(norm_tile, range)
end

---@param codes number --char
---@param sleep number
---@param rand number
---@return boolean
function API.KeyboardPress(codes, sleep, rand)
	return KeyboardPress(codes, sleep, rand)
end

---@param codes number
---@param sleep number
---@param rand number
---@return boolean
function API.KeyboardPress2(codes, sleep, rand)
	return KeyboardPress2(codes, sleep, rand)
end

-- Non-blocking key down/up (hold/release)
function API.KeyboardDown(codes)
	return KeyboardDown(codes)
end

function API.KeyboardUp(codes)
	return KeyboardUp(codes)
end

-- Non-blocking key hold API with optional timeout
-- Start holding a key (posts KEYDOWN if not held). timeout_ms = 0 means no timeout
function API.KeyboardHoldStart(codes, timeout_ms)
	return KeyboardHoldStart(codes, timeout_ms or 0)
end

-- Stop holding a key (posts KEYUP if held)
function API.KeyboardHoldStop(codes)
	return KeyboardHoldStop(codes)
end

-- Release all held keys
function API.KeyboardHoldStopAll()
	return KeyboardHoldStopAll()
end

-- Service function to auto-release expired holds (called internally every ~50ms)
function API.KeyboardHoldService()
	return KeyboardHoldService()
end

-- Query if a key is currently held
function API.KeyboardIsHeld(codes)
	return KeyboardIsHeld(codes)
end

-- Inspect current held keys (array of KeyHoldInfo)
function API.KeyboardHoldInspect()
	return KeyboardHoldInspect()
end

---@param sleeptime number
---@param location string "C:\\Windows\\Media\\ringout.wav"
---@return void
function API.Play_sound(sleeptime, location)
	return Play_sound(sleeptime, location)
end

---@param ItemCoord FFPOINT
---@param map_limit boolean
---@return FFPOINT
function API.ToMapFFPOINT(ItemCoord, map_limit)
	return ToMapFFPOINT(ItemCoord, map_limit)
end

---@param id number
---@return VB
function API.VB_FindPSett(id)
	return VB_FindPSett(id)
end

-- use this instead VB_FindPSett. Almost same as VB_FindPSett
---@param id number 
---@return VB
function API.VB_FindPSettinOrder(id)
	return VB_FindPSettinOrder(id)
end

--- return 32 slot boolean array
---@param id number
---@return table|number
function API.VB_FindPSett2(id)
	return VB_FindPSett2(id)
end

--- make int number into 32 slot boolean array
---@param var number
---@return string
function API.VB_IntToBit(var)
	return VB_IntToBit(var)
end

--- get bit slot on int var
---@param id number
---@param spot_index number --1 to 32 slot on int
---@return number
function API.VB_FindPSett3int(id, spot_index)
	return VB_FindPSett3int(id, spot_index)
end

--- get 2 bit slots on int var
---@param id number
---@param spot_index1 number
---@param spot_index2 number
---@return WPOINT
function API.VB_FindPSett3wpoint(id, spot_index1, spot_index2)
	return VB_FindPSett3wpoint(id, spot_index1, spot_index2)
end

---@param start number
---@param end number
---@param checked_var number
---@return boolean
function API.Math_VarBetween(start, endd, checked_var)
	return Math_VarBetween(start, endd, checked_var)
end

---@return boolean
function API.LootWindowOpen_2()
	return LootWindowOpen_2()
end

---@return table|IInfo
function API.LootWindow_GetData()
	return LootWindow_GetData()
end

---@param Except_item table|number
---@param Inventory_stacks boolean
---@return number
function API.LootWindow_space_needed(Except_item, Inventory_stacks)
	return LootWindow_space_needed(Except_item, Inventory_stacks)
end

---@param to string
---@param remove string
---@return string
function API.Filter(to, remove)
	return Filter(to, remove)
end

---@param sentence string
---@param keyword string
---@return string
function API.String_Filter(sentence, keyword)
	return String_Filter(sentence, keyword)
end

---@param to string
---@return string
function API.String_Filter2(to)
	return String_Filter2(to)
end

---@param to string
---@return string
function API.Filter22(to)
	return Filter22(to)
end

---@param to string
---@return string
function API.String_Filter3(to)
	return String_Filter3(to)
end

--old
---@return boolean
function API.FindChooseOptionOpen()
	return FindChooseOptionOpen()
end

--old
---@return boolean
function API.FindChooseOptionOpenClose()
	return FindChooseOptionOpenClose()
end

---@param value number
---@param arrayof table|Bbar
---@return boolean
function API.Math_Bbar_ValueEquals(value, arrayof)
	return Math_Bbar_ValueEquals(value, arrayof)
end

---@param arrayof1 table|number
---@param arrayof2 table|Bbar
---@return table|number
function API.Math_Bbar_ValueEqualsArr(arrayof1, arrayof2)
	return Math_Bbar_ValueEqualsArr(arrayof1, arrayof2)
end

---@param value number
---@param arrayof table|AllObject
---@return boolean
function API.Math_AO_ValueEquals(value, arrayof)
	return Math_AO_ValueEquals(value, arrayof)
end

---@param name string
---@param arrayof table|IInfo
---@return boolean
function API.Math_IInfo_ValueEqualsStr(name, arrayof)
	return Math_IInfo_ValueEqualsStr(name, arrayof)
end

---@param name table|string
---@param arrayof table|IInfo
---@return boolean
function API.Math_IInfo_ValueEqualsStrArr(name, arrayof)
	return Math_IInfo_ValueEqualsStrArr(name, arrayof)
end

---@param value number
---@param arrayof table|IInfo
---@return boolean
function API.Math_IInfo_ValueEqualsStack(value, arrayof)
	return Math_IInfo_ValueEqualsStack(value, arrayof)
end

---@param arrayof1 table|number
---@param arrayof2 table|AllObject
---@return boolean
function API.Math_AO_ValueEqualsArr(arrayof1, arrayof2)
	return Math_AO_ValueEqualsArr(arrayof1, arrayof2)
end

---@param arrayof1 table|number
---@param arrayof2 table|AllObject
---@return table|number
function API.Math_AO_ValueEqualsArr2(arrayof1, arrayof2)
	return Math_AO_ValueEqualsArr2(arrayof1, arrayof2)
end

---@param inputaddresses table|number
---@param target number
---@return boolean
function API.Math_Compare_int(inputaddresses, target)
	return Math_Compare_int(inputaddresses, target)
end

---@return boolean
function API.ReadNPCInFocus_0()
	return ReadNPCInFocus_0()
end

---@param index number
---@param debug boolean
---@return boolean
function API.ReadNPCInFocus(index, debug)
	return ReadNPCInFocus(index, debug)
end

---@param index number
---@param NPC_id number
---@param debug boolean
---@return boolean
function API.GetCheckNPCInFocus(index, NPC_id, debug)
	return GetCheckNPCInFocus(index, NPC_id, debug)
end

---@param entity FFPOINT
---@return FFPOINT
function API.W2ScreenNat_F(entity)
	return W2ScreenNat_F(entity)
end

---@param player string
---@return boolean
function API.PlayerInterActing_(player)
	return PlayerInterActing_(player)
end

---@param player string
---@return boolean
function API.IsInCombat_(player)
	return IsInCombat_(player)
end

---@return boolean
function API.LocalPlayer_IsInCombat_()
	return LocalPlayer_IsInCombat_()
end

---@return string
function API.Local_PlayerInterActingWith_()
	return Local_PlayerInterActingWith_()
end

---@return number
function API.Local_PlayerInterActingWith_Id()
	return Local_PlayerInterActingWith_Id()
end

---@param player string
---@return number
function API.GetPlayerAnimation_(player)
	return GetPlayerAnimation_(player)
end

---@param player string
---@param loops number
---@return boolean
function API.IsPlayerAnimating_(player, loops)
	return IsPlayerAnimating_(player, loops)
end

---@param player string
---@return boolean
function API.IsPlayerMoving_(player)
	return IsPlayerMoving_(player)
end

---@param player1 string
---@param entity string
---@return boolean
function API.PlayerInterActingWithCompare_(player1, entity)
	return PlayerInterActingWithCompare_(player1, entity)
end

---@return number
function API.GetGameState2()
	return GetGameState2()
end

---@return number
function API.GetAngle()
	return GetAngle()
end

---@return number
function API.GetTilt()
	return GetTilt()
end

---@return boolean
function API.GetQuickPray()
	return GetQuickPray()
end

---@return number
function API.GetTargetHealth()
	return GetTargetHealth()
end

---@return boolean
function API.GetRun()
	return GetRun()
end

---@return boolean
function API.GetRun2()
	return GetRun2()
end

---@return WPOINT
function API.PlayerCoord()
	return PlayerCoord()
end

--- WPOINT.x `RegionX`<br>
--- WPOINT.y `RegionY`<br>
--- WPOINT.z `RegionId`
---@return WPOINT
function API.PlayerRegion()
	return PlayerRegion()
end

--- Check if player is in an instanced area (x >= 6400 or y >= 6400)
---@return boolean
function API.InInstancedArea()
	return InInstancedArea()
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return table|WPOINT
function API.Math_Bresenham_line(x1, y1, x2, y2)
	return Math_Bresenham_line(x1, y1, x2, y2)
end

---@param xy1 WPOINT
---@param xy2 WPOINT
---@return table|WPOINT
function API.Math_Bresenham_lineW(xy1, xy2)
	return Math_Bresenham_lineW(xy1, xy2)
end

---@param xy1 FFPOINT
---@param xy2 FFPOINT
---@return table|WPOINT
function API.Math_Bresenham_lineF(xy1, xy2)
	return Math_Bresenham_lineF(xy1, xy2)
end

---@param tilexy FFPOINT
---@return WPOINT
function API.Bresenham_step(tilexy)
	return Bresenham_step(tilexy)
end

---@param obj table|number
---@param maxdistance number
---@param sens number --float
---@return boolean
function API.FindObjRot(obj, maxdistance, sens)
	return FindObjRot(obj, maxdistance, sens)
end

---@param ItemXY FFPOINT
---@param currxy FFPOINT
---@param sens number --float
---@return boolean
function API.RotateCamera(ItemXY, currxy, sens)
	return RotateCamera(ItemXY, currxy, sens)
end

---@param obj table|number
---@param maxdistance number
---@return FFPOINT
function API.FindObjTileName(obj, maxdistance)
	return FindObjTileName(obj, maxdistance)
end

---@param Line_index number
---@param size number
---@return table|string
function API.GetChatMessage(Line_index, size)
	return GetChatMessage(Line_index, size)
end

---@param ascii_num string
---@return number
function API.AsciiToNumbers32(ascii_num)
	return AsciiToNumbers32(ascii_num)
end

---@param ascii_num string
---@return number
function API.AsciiToNumbers64(ascii_num)
	return AsciiToNumbers64(ascii_num)
end

---@param item number
---@return WPOINT
function API.BankGetItem(item)
	return BankGetItem(item)
end

---@param item number
---@return number
function API.BankGetItemStack_Inv(item)
	return BankGetItemStack_Inv(item)
end

---@param item number
---@return WPOINT
function API.BankGetItem_Inv(item)
	return BankGetItem_Inv(item)
end

---@return WPOINT
function API.BankGetLimits()
	return BankGetLimits()
end

---@return boolean
function API.BankGetVisItemsPrint()
	return BankGetVisItemsPrint()
end

-- check is the bank open
---@return boolean
function API.BankOpen2()
	return BankOpen2()
end

---@param pin number
---@return boolean
function API.DoBankPin(pin)
	return DoBankPin(pin)
end

---@param bar Bbar
---@return number
function API.Bbar_ConvToSeconds(bar)
	return Bbar_ConvToSeconds(bar)
end

---@param print_all_out boolean
---@return table|Bbar
function API.Buffbar_GetAllIDs(print_all_out)
	return Buffbar_GetAllIDs(print_all_out)
end

--[[
Some ids:
perfect juju pot:33234
hittpoints over:1236
yak track:25830
citadel boost:12327
wise perk:26341
grace of elves,porters:51490
overloaded:26093
super/anti-fire,wyrmfire:14692
anti-poison:14693
poison+++ 14694
prayer renewal:14695
elder overload:49039
cinder core:48544
pulse core: 34918
scripture of wen 52117
aftershock: 26466
range pray:26044
magic pray:26041
mele pray: 26040
soulsplit: 26033
turmoil:   26019
anguish:   26020
torment:   26021
malevolenc:29262
desolation:29263
affliction:29264
glacial emprace stack:14766
The Hole buff:51729
Lemon sour:35054
masterstroke:49087
--]]
---@param id number
---@param debug boolean
---@return Bbar
function API.Buffbar_GetIDstatus(id, debug)
	return Buffbar_GetIDstatus(id, debug)
end

---@param text string
---@param limit number
---@return ChatTexts
function API.ChatFind(text, limit)
	return ChatFind(text, limit)
end

---old
---@return table|ChatTexts
function API.ChatGetMessages()
	return ChatGetMessages()
end

---@return number
function API.ChatPortableTime()
	return ChatPortableTime()
end

---@return boolean
function API.CheckDoItemOpen()
	return CheckDoItemOpen()
end

---@return boolean
function API.CheckDoToolOpen()
	return CheckDoToolOpen()
end

---@return boolean
function API.CheckFamiliar()
	return CheckFamiliar()
end

---@param print_all_out boolean
---@return table|Bbar
function API.DeBuffbar_GetAllIDs(print_all_out)
	return DeBuffbar_GetAllIDs(print_all_out)
end

---@param id number
---@param debug boolean
---@return Bbar
function API.DeBuffbar_GetIDstatus(id, debug)
	return DeBuffbar_GetIDstatus(id, debug)
end

---@param debug? boolean
---@return table|TargetBuff[]
function API.ReadTargetBuffsDetailed(debug)
	return ReadTargetBuffsDetailed(debug or false)
end

---@param id number|string varbit ID, sprite/buff ID, or name. Use API.TargetBuffs enum for known buffs.
---@return boolean
function API.TargetHasBuff(id)
	return TargetHasBuff(id)
end

---@return boolean
function API.DEPOInterfaceCheckvarbit()
	return DEPOInterfaceCheckvarbit()
end

---@return boolean
function API.EquipInterfaceCheckvarbit()
	return EquipInterfaceCheckvarbit()
end

---@param name string
---@param model_ids table|number
---@return boolean
function API.FindModelCompare(name, model_ids)
	return FindModelCompare(name, model_ids)
end

---@param bar_nr number
---@return table|Abilitybar
function API.GetABarInfo(bar_nr)
	return GetABarInfo(bar_nr)
end

--print all 0-2
---@return void
function API.GetABarInfo_DEBUG()
	return GetABarInfo_DEBUG()
end

---@param bar_nr number
---@param ability_id number
---@return Abilitybar
function API.GetAB_id(bar_nr, ability_id)
	return GetAB_id(bar_nr, ability_id)
end

---@param bar_nr number
---@param ability_name string
---@return Abilitybar
function API.GetAB_name(bar_nr, ability_name)
	return GetAB_name(bar_nr, ability_name)
end

---@param obj number
---@param distance number
---@param type number
---@param adjust_tile WPOINT
---@return AllObject
function API.GetAllObj_dist(obj, distance, type, adjust_tile)
	return GetAllObj_dist(obj, distance, type, adjust_tile)
end

---@param slot number
---@return IInfo
function API.GetEquipSlot(slot)
	return GetEquipSlot(slot)
end

---@return string
function API.GetFamiliarName()
	return GetFamiliarName()
end

---@param entity_base number
---@param debug boolean
---@return table|number
function API.GetModel_ids(entity_base, debug)
	return GetModel_ids(entity_base, debug)
end

---@return boolean
function API.IsSkillsPanelOpen()
	return IsSkillsPanelOpen()
end

---@return boolean
function API.ToggleSkillsPanelVisibility()
	return ToggleSkillsPanelVisibility()
end

---@param index number
---@return Skill
function API.GetSkillById(index)
	return GetSkillById(index)
end

--[[
ATTACK
STRENGTH
RANGED
MAGIC
DEFENCE
CONSTITUTION
PRAYER
SUMMONING
DUNGEONEERING
AGILITY
THIEVING
SLAYER
HUNTER
SMITHING
CRAFTING
FLETCHING
HERBLORE
RUNECRAFTING
COOKING
CONSTRUCTION
FIREMAKING
WOODCUTTING
FARMING
FISHING
MINING
DIVINATION
INVENTION
ARCHAEOLOGY
NECROMANCY
--]]
---@param name string
---@return Skill
function API.GetSkillByName(name)
	return GetSkillByName(name)
end

--[[
ATTACK
STRENGTH
RANGED
MAGIC
DEFENCE
CONSTITUTION
PRAYER
SUMMONING
DUNGEONEERING
AGILITY
THIEVING
SLAYER
HUNTER
SMITHING
CRAFTING
FLETCHING
HERBLORE
RUNECRAFTING
COOKING
CONSTRUCTION
FIREMAKING
WOODCUTTING
FARMING
FISHING
MINING
DIVINATION
INVENTION not known
ARCHAEOLOGY
NECROMANCY
--]]
---@param name string
---@return number
function API.GetSkillXP(name)
	return GetSkillXP(name)
end

--- check if inventory open 
---@return boolean
function API.InventoryInterfaceCheckvarbit()
	return InventoryInterfaceCheckvarbit()
end

---@return boolean
function API.LODEInterfaceCheckvarbit()
	return LODEInterfaceCheckvarbit()
end

---@param entity_base number
---@param model_ids table|number
---@return boolean
function API.ModelCompare(entity_base, model_ids)
	return ModelCompare(entity_base, model_ids)
end

---@return void
function API.PrintEquipSlots()
	return PrintEquipSlots()
end

---@param bar_nr number
---@return void
function API.print_GetABarInfo(bar_nr)
	return print_GetABarInfo(bar_nr)
end

--use containers instead
---@return table|IInfo
function API.ReadEquipment()
	return ReadEquipment()
end

---@param boxtext string
---@param secondedit boolean
---@return table|string
function API.ScriptAskBox(boxtext, secondedit)
	return ScriptAskBox(boxtext, secondedit)
end

---@param boxtext string
---@param textchoices table|string
---@param button_name1 string
---@param button_name2 string
---@param Make string
---@param Edit string
---@return returntext
function API.ScriptDialogWindow2(boxtext, textchoices, button_name1, button_name2, Make, Edit)
	return ScriptDialogWindow2(boxtext, textchoices, button_name1, button_name2, Make, Edit)
end

---@param boxtext string
---@param password boolean
---@param arrtype number
---@param filename string
---@return table --<NAMEdata> prob not needed never
function API.ScriptDialogWindow_input(boxtext, password, arrtype, filename)
	return ScriptDialogWindow_input(boxtext, password, arrtype, filename)
end

---@param input table|string
---@return table|number
function API.StringsToInts(input)
	return StringsToInts(input)
end

--it keeps thread in a loop until either ticks expire or howmanychecks fails to detect any action
---@return boolean
---@param tick_sleeps number --how many 600ms to wait
---@param howmanychecks number --how many times to check if actions is still going
---@return boolean --true is when howmanychecks fails to detect action, false is when loop ends successfully = something is still going
function API.WaitUntilMovingEnds(tick_sleeps, howmanychecks)
	return WaitUntilMovingEnds(tick_sleeps, howmanychecks)
end

--it keeps thread in a loop until either ticks expire or howmanychecks fails to detect any action
---@return boolean
---@param tick_sleeps number --how many 600ms to wait
---@param howmanychecks number --how many times to check if actions is still going
---@return boolean --true is when howmanychecks fails to detect action, false is when loop ends successfully = something is still going
function API.WaitUntilMovingandAnimEnds(tick_sleeps, howmanychecks)
	return WaitUntilMovingandAnimEnds(tick_sleeps, howmanychecks)
end

--it keeps thread in a loop until either ticks expire or howmanychecks fails to detect any action
---@return boolean
---@param tick_sleeps number --how many 600ms to wait
---@param howmanychecks number --how many times to check if actions is still going
---@return boolean --true is when howmanychecks fails to detect action, false is when loop ends successfully = something is still going
function API.WaitUntilMovingandAnimandCombatEnds(tick_sleeps, howmanychecks)
	return WaitUntilMovingandAnimandCombatEnds(tick_sleeps, howmanychecks)
end

---@param wait_time number
---@param random_time number
---@param reset boolean
---@return boolean
function API.Wait_Timer(wait_time, random_time, reset)
	return Wait_Timer(wait_time, random_time, reset)
end

---@param walktile WPOINT
---@param stopdistance number
---@return boolean
function API.WalkUntilClose(walktile, stopdistance)
	return WalkUntilClose(walktile, stopdistance)
end

---@param xp number
---@param elite boolean ---optional
---@return number
function API.XPLevelTable(xp)
	return XPLevelTable(xp)
end

---@param level number
---@param elite boolean ---optional
---@return number
function API.XPForLevel(level)
	return XPForLevel(level)
end

---@return boolean
function API.DoContinue_Dialog()
	return DoContinue_Dialog()
end

--Partial match will do. If all is correct then goes direclty to action
---@param text string
---@return boolean
function API.DoDialog_Option(text)
	return DoDialog_Option(text)
end

--- m_action and offset is from doaction debug
--- use exact_match for exact string match
---@param name string
---@param m_action number
---@param offset number
---@param exact_match boolean
---@return boolean
function API.DoAction_Ability(name, m_action, offset, exact_match)
	return DoAction_Ability(name, m_action, offset, exact_match)
end

--- m_action and offset is from doaction debug
--- use exact_match for exact string match
---@param name string
---@param m_action number
---@param offset number
---@param checkenabled boolean
---@param checkcooldown boolean
---@param exact_match boolean
---@return boolean
function API.DoAction_Ability_check(name, m_action, offset, checkenabled, checkcooldown, exact_match)
	return DoAction_Ability_check(name, m_action, offset, checkenabled, checkcooldown, exact_match)
end

---@param Ab Abilitybar
---@param m_action number
---@param offset number
---@return boolean
function API.DoAction_Ability_Direct(Ab, m_action, offset)
	return DoAction_Ability_Direct(Ab, m_action, offset)
end

---@param id number
---@param m_action number
---@param offset number
---@return boolean
function API.DoAction_Bank(id, m_action, offset)
	return DoAction_Bank(id, m_action, offset)
end

---@param itemname string
---@param m_action number
---@param offset number
---@return boolean
function API.DoAction_Bank_str(itemname, m_action, offset)
	return DoAction_Bank(itemname, m_action, offset)
end

---@param id number
---@param m_action number
---@param offset number
---@return boolean
function API.DoAction_Bank_Inv(id, m_action, offset)
	return DoAction_Bank_Inv(id, m_action, offset)
end

--For 2 part action. Dive/Bladeddive/bombs from interface ab -> then this
---@param normal_tile WPOINT
---@return boolean
function API.DoAction_SpecialWalk(normal_tile)
	return DoAction_SpecialWalk(normal_tile)
end

--For Dive
---@param normal_tile WPOINT
---@return boolean
function API.DoAction_Dive_Tile(normal_tile)
	return DoAction_Dive_Tile(normal_tile)
end

--For Bladed Dive
---@param normal_tile WPOINT
---@return boolean
function API.DoAction_BDive_Tile(normal_tile)
	return DoAction_BDive_Tile(normal_tile)
end

--For Bladed Dive and just Dive
---@param normal_tile WPOINT
---@param sleep number
---@return boolean
function API.DoAction_Dive_Tile_sleep(normal_tile,sleep)
	return DoAction_Dive_Tile(normal_tile,sleep)
end

---@param normal_tile WPOINT
---@param errorrange number
---@return boolean
function API.DoAction_Surge_Tile(normal_tile, errorrange)
	return DoAction_Surge_Tile(normal_tile, errorrange)
end

--Auto-retaliate button
---@return boolean
function API.DoAction_Button_AR()
	return DoAction_Button_AR()
end

--call familiar button
--[[
0 - call familiar
1 - cast special //legendary = no
2 - attack //legendary = can't
3 - summon pet
4 - dismiss
5 - follower details
6 - interact
7 - renew familiar
8 - give bob
9 - take bob
10 - restore points
]]--
---@param Possible_order number
---@return boolean
function API.DoAction_Button_FO(Possible_order)
	return DoAction_Button_FO(Possible_order)
end

--generate health
---@return boolean
function API.DoAction_Button_GH()
	return DoAction_Button_GH()
end

--quickpray
---@return boolean
function API.DoAction_Button_QP()
	return DoAction_Button_QP()
end

---@param action number
---@param route number
---@param obj AllObject
---@return boolean
function API.DoAction_G_Items_Direct(action, route, obj)
	return DoAction_G_Items_Direct(action, route, obj)
end

---@param action number
---@param obj table|number
---@param maxdistance number
---@param tile FFPOINT
---@param radius number --float
---@return boolean
function API.DoAction_G_Items_r_norm(action, obj, maxdistance, tile, radius)
	return DoAction_G_Items_r_norm(action, obj, maxdistance, tile, radius)
end

---@param action number
---@param obj table|number
---@param maxdistance number
---@param tile FFPOINT
---@param radius number --float
---@return boolean
function API.DoAction_G_Items_r_normSTACKs(action, obj, maxdistance, tile, radius)
	return DoAction_G_Items_r_normSTACKs(action, obj, maxdistance, tile, radius)
end

---@param command1 number
---@param command2 number
---@param command3 number
---@param numbererface1 number
---@param numbererface2 number
---@param numbererface3 number
---@param offset number
---@param pixel_x number
---@param pixel_y number
---@return boolean
function API.DoAction_Interface(command1, command2, command3, numbererface1, numbererface2, numbererface3, offset, pixel_x, pixel_y)
	return DoAction_Interface(command1, command2, command3, numbererface1, numbererface2, numbererface3, offset, pixel_x, pixel_y)
end

--1 That mini logout button attached to minimap
---@return boolean
function API.DoAction_Logout_mini()
	return DoAction_Logout_mini()
end

--2 pick logout from settings menu
---@return boolean
function API.DoAction_then_lobby()
	return DoAction_then_lobby()
end

--clicks loot all button if open
---@return boolean
function API.DoAction_LootAll_Button()
	return DoAction_LootAll_Button()
end

---@param ids table|number
---@param maxdistance number
---@param tile FFPOINT
---@param radius number --float
---@return boolean
function API.DoAction_Loot_w(ids, maxdistance, tile, radius)
	return DoAction_Loot_w(ids, maxdistance, tile, radius)
end

---@param ids table              - item ids to loot
---@param maxdistance number     - maximum distance to search for items
---@param max_item_count number  - max items to loot in one call
---@param keycode number         - ASCII key code for loot window shortcut
---@param keymod number          - 0 for no modifier, 1 or 2 for shift or alt respectively
---@return boolean
function API.DoAction_Loot_k(ids, maxdistance, max_item_count, keycode, keymod)
	return DoAction_Loot_k(ids, maxdistance, max_item_count, keycode, keymod)
end

---@return boolean
function API.DoAction_Loot_w_Close()
	return DoAction_Loot_w_Close()
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param tile WPOINT
---@param ignore_star boolean
---@param health number
---@return boolean
function API.DoAction_NPC(action, offset, objects, maxdistance, tile, ignore_star, health)
	return DoAction_NPC(action, offset, objects, maxdistance, tile, ignore_star, health)
end

---Do action on player, find by name, attack
---@param obj table player names to search for
---@param maxdistance number maximum distance to search
---@return boolean
function API.DoAction_VS_Player_Attack(obj, maxdistance)
	return DoAction_VS_Player_Attack(obj, maxdistance)
end

---Do action on player, find by name, trade
---@param obj table player names to search for
---@param maxdistance number maximum distance to search
---@return boolean
function API.DoAction_VS_Player_Trade(obj, maxdistance)
	return DoAction_VS_Player_Trade(obj, maxdistance)
end

---Do action on player, find by name, examine
---@param obj table player names to search for
---@param maxdistance number maximum distance to search
---@return boolean
function API.DoAction_VS_Player_Examine(obj, maxdistance)
	return DoAction_VS_Player_Examine(obj, maxdistance)
end

---Do action on player, find by name, follow
---@param obj table player names to search for
---@param maxdistance number maximum distance to search
---@return boolean
function API.DoAction_VS_Player_Follow(obj, maxdistance)
	return DoAction_VS_Player_Follow(obj, maxdistance)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param bottom_left WPOINT
---@param top_right WPOINT
---@return boolean
function API.DoAction_NPC_In_Area(action, offset, obj, maxdistance, bottom_left, top_right, ignore_star, health)
	return DoAction_NPC_In_Area(action, offset, obj, maxdistance, bottom_left, top_right, ignore_star, health)
end

---@param action number
---@param offset number
---@param obj table|string
---@param maxdistance number
---@param ignore_star boolean
---@param health number
---@return boolean
function API.DoAction_NPC_str(action, offset, objects, maxdistance, ignore_star, health)
	return DoAction_NPC_str(action, offset, objects, maxdistance, ignore_star, health)
end

---@param action number
---@param offset number
---@param object AllObject
---@return boolean
function API.DoAction_NPC__Direct(action, offset, object)
	return DoAction_NPC__Direct(action, offset, object)
end

---@param action number
---@param offset number
---@param object AllObject
---@return boolean
function API.DoAction_Object_Direct(action, offset, object)
	return DoAction_Object_Direct(action, offset, object)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@return boolean
function API.DoAction_Object_furthest(action, offset, obj, maxdistance)
	return DoAction_Object_furthest(action, offset, obj, maxdistance)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param tile WPOINT
---@param tile_range number max distance FROM tile to found object, tile and tile_range range cant be zero
---@return boolean
function API.DoAction_Object_r(action, offset, obj, maxdistance, tile, tile_range)
	return DoAction_Object_r(action, offset, obj, maxdistance, tile, tile_range)
end

---@param normal_tile WPOINT
---@return boolean
function API.DoAction_Tile(normal_tile)
	return DoAction_Tile(normal_tile)
end

---@param normal_tile FFPOINT
---@return boolean
function API.DoAction_TileF(normal_tile)
	return DoAction_TileF(normal_tile)
end

---@param obj AllObject
---@param offset number
---@return boolean
function API.DoAction_VS_Player_action_Direct(obj, offset)
	return DoAction_VS_Player_action_Direct(obj, offset)
end

---@param normal_tile FFPOINT
---@param sleep number --50 is ok number
---@return boolean
function API.DoAction_WalkerF1(normal_tile, sleep)
	return DoAction_WalkerF(normal_tile, sleep)
end

---@param normal_tile FFPOINT
---@return boolean
function API.DoAction_WalkerF(normal_tile)
	return DoAction_WalkerF(normal_tile)
end

---@param normal_tile FFPOINT
---@param sleep number --50 is ok number
---@return boolean
function API.DoAction_WalkerF1(normal_tile, sleep)
	return DoAction_WalkerF(normal_tile, sleep)
end

---@param normal_tile WPOINT
---@return boolean
function API.DoAction_WalkerW(normal_tile)
	return DoAction_WalkerW(normal_tile)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param highlight table|number
---@return boolean
function API.DOFindHl(action, offset, obj, maxdistance, highlight)
	return DOFindHl(action, offset, obj, maxdistance, highlight)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param highlight table|number
---@param localp_dist number --float
---@return boolean
function API.DOFindHLvsLocalPlayer(action, offset, obj, maxdistance, highlight, localp_dist)
	return DOFindHLvsLocalPlayer(action, offset, obj, maxdistance, highlight, localp_dist)
end

--- wide array of randoms
---@param waitTime number wait time before interacting
---@param sleepTime number sleep time AFTER interacting
---@param catchpengs boolean catch pengs
---@return boolean
function API.DoRandomEvents(waitTime, sleepTime, catchpengs)
	waitTime = waitTime or 600
	sleepTime = sleepTime or 1200
	catchpengs = catchpengs or false
	return DoRandomEvents(waitTime, sleepTime, catchpengs)
end

--- single random ncp
---@return boolean
function API.DoRandomEvent(randnpc)
	return DoRandomEvent(randnpc)
end

---@param value number
---@param arrayof table|number
---@return boolean
function API.Math_ValueEquals(value, arrayof)
	return Math_ValueEquals(value, arrayof)
end

--[[AllObject Types 
0 obj
1 npc
2 player
3 ground item
4 highlights
5 projectiles
8 tiles
12 decor
--]]
---@param obj table|number
---@param maxdistance number
---@param type table|number {}
---@return AllObject
function API.GetAllObjArrayFirst(obj, maxdistance, type)
	return GetAllObjArrayFirst(obj, maxdistance,type)
end

--[[AllObject Types 
0 obj
1 npc
2 player
3 ground item
4 highlights
5 projectiles
8 tiles
12 decor
--]]
---@param obj table|number
---@param maxdistance number
---@param type table|number {}
---@param tile WPOINT
---@return AllObject
function API.GetAllObjArrayFirstTile(obj, maxdistance, type, tile)
	return GetAllObjArrayFirstTile(obj, maxdistance,type, tile)
end

--[[AllObject Types 
0 obj
1 npc
2 player
3 ground item
4 highlights
5 projectiles
8 tiles
12 decor
--]]
---@param obj table|number
---@param maxdistance number
---@param type table|number {}
---@return table|AllObject
function API.GetAllObjArray1(obj, maxdistance, type)
	return GetAllObjArray(obj, maxdistance,type)
end

--[[AllObject Types 
0 obj
1 npc
2 player
3 ground item
4 highlights
5 projectiles
8 tiles
12 decor
--]]
---@param obj table|number
---@param maxdistance number
---@param type table|number {}
---@param tile WPOINT
---@return table|AllObject
function API.GetAllObjArray2(obj, maxdistance, type, tile)
	return GetAllObjArray(obj, maxdistance, type, tile)
end

---@param tile WPOINT
---@return boolean
function API.CheckTileforObjects1(tile)
	return CheckTileforObjects(tile)
end

---@param tile WPOINT
---@param object number
---@param thresh number --float
---@return boolean
function API.CheckTileforObjects2(tile, object, thresh)
	return CheckTileforObjects(tile, object, thresh)
end

---@param text string
---@return boolean
function API.SideTextEq1(text)
	return SideTextEq(text)
end

---@param text table|string
---@return boolean
function API.SideTextEq2(text)
	return SideTextEq(text)
end

---@param xstart number
---@param xend number
---@param xcurrent number
---@param ystart number
---@param yend number
---@param ycurrent number
---@return boolean
function API.InArea21(xstart, xend, xcurrent, ystart, yend, ycurrent)
	return InArea2(xstart, xend, xcurrent, ystart, yend, ycurrent)
end

---@param xstart number --float
---@param xend number --float
---@param xcurrent number --float
---@param ystart number --float
---@param yend number --float
---@param ycurrent number --float
---@return boolean
function API.InArea22(xstart, xend, xcurrent, ystart, yend, ycurrent)
	return InArea2(xstart, xend, xcurrent, ystart, yend, ycurrent)
end

---@param norm_tile FFPOINT
---@param range number --float
---@return boolean
function API.PInAreaF1(norm_tile, range)
	return PInAreaF(norm_tile, range)
end

---@param norm_tile FFPOINT
---@param range number
---@return boolean
function API.PInAreaF2(norm_tile, range)
	return PInAreaF(norm_tile, range)
end

---@param xstart number
---@param xend number
---@param ystart number
---@param yend number
---@return boolean
function API.PInArea21(xstart, xend, ystart, yend)
	return PInArea2(xstart, xend, ystart, yend)
end

---@param xstart number --float
---@param xend number --float
---@param ystart number --float
---@param yend number --float
---@return boolean
function API.PInArea22(xstart, xend, ystart, yend)
	return PInArea2(xstart, xend, ystart, yend)
end

--- Ascii numeric values, 1 is 49, enter is 17, space is 32
---@param codes number
---@param sleep number
---@param rand number
---@return boolean
function API.KeyboardPress31(codes, sleep, rand)
	return KeyboardPress31(codes, sleep, rand)
end

--- Ascii numeric values, 1 is 49, enter is 17, space is 32
---@param codes number
---@param keymod number 0 = non, 1 = shift, 2 = ctrl, 3 = alt 
---@return boolean
function API.KeyboardPress32(codes, keymod)
	return KeyboardPress32(codes, keymod)
end

--- Ascii numeric values, 1 is 49, enter is 17, space is 32
---@param codes number
---@param keymod number 0 = non, 1 = shift, 2 = ctrl, 3 = alt 
---@return boolean
function API.KeyboardPress33(codes, keymod, sleep, rand)
	return KeyboardPress33(codes, keymod, sleep, rand)
end

---@param value number
---@param arrayof table|IInfo
---@return boolean
function API.Math_IInfo_ValueEquals1(value, arrayof)
	return Math_IInfo_ValueEquals(value, arrayof)
end

---@param value table|IInfo
---@param arrayof table|IInfo
---@return boolean
function API.Math_IInfo_ValueEquals2(value, arrayof)
	return Math_IInfo_ValueEquals(value, arrayof)
end

---@param number number --double
---@return number
function API.Math_RandomNumber1(number)
	return Math_RandomNumber(number)
end

---@param number number --float
---@return number
function API.Math_RandomNumber2(number)
	return Math_RandomNumber(number)
end

---@param number number
---@return number
function API.Math_RandomNumber3(number)
	return Math_RandomNumber(number)
end

---@param spot number
---@return WPOINT
function API.W2ScreenNat1(spot)
	return W2ScreenNat(spot)
end

---@param entity FFPOINT
---@return WPOINT
function API.W2ScreenNat2(entity)
	return W2ScreenNat(entity)
end

---@param loop number
---@return boolean
function API.Local_PlayerInterActingWith_21(loop)
	return Local_PlayerInterActingWith_2(loop)
end

---@param loop number
---@param name string
---@return boolean
function API.Local_PlayerInterActingWith_22(loop, name)
	return Local_PlayerInterActingWith_2(loop, name)
end

---@param player string
---@return string
function API.PlayerInterActingWith_1(player)
	return PlayerInterActingWith_(player)
end

---@param localmem number
---@return string
function API.PlayerInterActingWith_2(localmem)
	return PlayerInterActingWith_(localmem)
end

---@param target_under boolean
---@param lv_ID table|InterfaceComp5
---@return table|IInfo
function API.ScanForInterfaceTest2Get(target_under, lv_ID)
	if type(lv_ID[1]) == "table" then
		local ids = {}
		
		for i = 1, #lv_ID do
			local comp = InterfaceComp5:new(lv_ID[i][1], lv_ID[i][2], lv_ID[i][3], lv_ID[i][4])
			table.insert(ids, comp)
		end
		
		return ScanForInterfaceTest2Get(target_under, ids)
	end
	
	return ScanForInterfaceTest2Get(target_under, lv_ID)
end

--- Checks if an interface is open by its size/ID. 
--- Used for determining if interfaces with no VB and floating popup windows are open.
---@param ID number The interface ID to check
---@return boolean True if the interface is open (has size > 0), false otherwise
function API.GetInterfaceOpenBySize(ID)
	return GetInterfaceOpenBySize(ID)
end

---@param item number
---@return number
function API.BankGetItemStack1(item)
	return BankGetItemStack(item)
end

---@param itemname string
---@return number
function API.BankGetItemStack_str(itemname)
	return BankGetItemStack(itemname)
end

---@param item table|number
---@return table|number
function API.BankGetItemStack2(item)
	return BankGetItemStack(item)
end

---@param slot number
---@param id number
---@return boolean
function API.EquipSlotEq1(slot, id)
	return EquipSlotEq(slot, id)
end

---@param slot number
---@param txt string
---@return boolean
function API.EquipSlotEq2(slot, txt)
	return EquipSlotEq(slot, txt)
end

-- probl some old scripts use it
---@param ability_name string
---@return Abilitybar
function API.GetABs_name1(ability_name)
	return GetABs_name(ability_name)
end

-- get ability data by name
-- use exact_match for exact string match
---@param ability_name string
---@param exact_match boolean
---@return Abilitybar
function API.GetABs_name(ability_name, exact_match)
	return GetABs_name(ability_name, exact_match)
end

-- gets ability data by matching icon id
---@param ability_id number
---@return Abilitybar
function API.GetABs_id(ability_id)
	return GetABs_id(ability_id)
end

-- gets ability data by matching icon ids
---@param ability_ids number
---@return table|Abilitybar
function API.GetABs_ids(ability_ids)
	return GetABs_ids(ability_ids)
end

-- get ability data by names
---@param ability_names table|string
---@return table|Abilitybar
function API.GetABs_names(ability_names)
	return GetABs_names(ability_names)
end

-- gets ability data by matching icon ids, in order of input, for potions, super_restore = { 3024,3026,3028,3030 } <- full dose to smaller
---@param ability_ids number
---@return Abilitybar --single slot
function API.GetAB_ids(ability_ids)
	return GetAB_ids(ability_ids)
end

---@param action number
---@param obj table|number
---@param maxdistance number
---@return boolean
function API.DoAction_G_Items1(action, obj, maxdistance)
	return DoAction_G_Items(action, obj, maxdistance)
end

---@param action number
---@param obj table|number
---@param maxdistance number
---@param atTile WPOINT
---@return boolean
function API.DoAction_G_Items2(action, obj, maxdistance, atTile)
	return DoAction_G_Items(action, obj, maxdistance, atTile)
end

---@param action number
---@param obj table|number
---@param maxdistance number
---@param tile FFPOINT
---@param radius number --float
---@return boolean
function API.DoAction_G_Items_r1(action, obj, maxdistance, tile, radius)
	return DoAction_G_Items_r(action, obj, maxdistance, tile, radius)
end

---@param action number
---@param action_route number
---@param obj table|number
---@param maxdistance number
---@param tile FFPOINT
---@param radius number --float
---@return boolean
function API.DoAction_G_Items_r2(action, action_route, obj, maxdistance, tile, radius)
	return DoAction_G_Items_r(action, action_route, obj, maxdistance, tile, radius)
end

---@param id number
---@param random number
---@param m_action number
---@param offset number
---@return boolean
function API.DoAction_Inventory1(id, random, m_action, offset)
	return DoAction_Inventory(id, random, m_action, offset)
end

---@param ids table|number
---@param random number
---@param m_action number
---@param offset number
---@return boolean
function API.DoAction_Inventory2(ids, random, m_action, offset)
	return DoAction_Inventory(ids, random, m_action, offset)
end

---@param itemname string
---@param random number
---@param m_action number
---@param offset number
---@return boolean
function API.DoAction_Inventory3(itemname, random, m_action, offset)
	return DoAction_Inventory(itemname, random, m_action, offset)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@return boolean
function API.DoAction_Object1(action, offset, obj, maxdistance)
	return DoAction_Object(action, offset, obj, maxdistance)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param tile WPOINT
---@return boolean
function API.DoAction_Object2(action, offset, obj, maxdistance, tile)
	return DoAction_Object(action, offset, obj, maxdistance, tile)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param valid boolean
---@return boolean
function API.DoAction_Object_valid1(action, offset, obj, maxdistance, valid)
	return DoAction_Object_valid(action, offset, obj, maxdistance, valid)
end

---@param action number
---@param offset number
---@param obj table|number
---@param maxdistance number
---@param tile WPOINT
---@param valid boolean
---@return boolean
function API.DoAction_Object_valid2(action, offset, obj, maxdistance, tile, valid)
	return DoAction_Object_valid(action, offset, obj, maxdistance, tile, valid)
end

---@param action number
---@param offset number
---@param obj table|string
---@param maxdistance number
---@param valid boolean
---@return boolean
function API.DoAction_Object_string1(action, offset, obj, maxdistance, valid)
	return DoAction_Object_string(action, offset, obj, maxdistance, valid)
end

---@param action number
---@param offset number
---@param obj table|string
---@param maxdistance number
---@param tile WPOINT
---@param valid boolean
---@return boolean
function API.DoAction_Object_string2(action, offset, obj, maxdistance, tile, valid)
	return DoAction_Object_string(action, offset, obj, maxdistance, tile, valid)
end

---@param obj table|string
---@param maxdistance number
---@param checkcombat boolean
---@param xstart number
---@param xend number
---@param ystart number
---@param yend number
---@return boolean
function API.DoAction_VS_Player_Attack2(obj, maxdistance, checkcombat, xstart, xend, ystart, yend)
	return DoAction_VS_Player_Attack(obj, maxdistance, checkcombat, xstart, xend, ystart, yend)
end

---@param logline string
---@param level string --info debug warn error
function API.Log(logline, level)
	return Log(logline, level)
end

---@param logline string
function API.logInfo(logline)
	return Log(logline,'info')
end

---@param logline string
function API.logDebug(logline)
	return Log(logline,'debug')
end

---@param logline string
function API.logWarn(logline)
	return Log(logline,'warn')
end

---@param logline string
function API.logError(logline)
	return Log(logline,'error')
end

---Clears Log
function API.ClearLog()
	return ClearLog()
end

---@return TrackedSkill -- vector<TrackedSkill>
function API.GetTrackedSkills()
	return GetTrackedSkills()
end

---@return string -- Current time in the format hh:mm:ss
function API.FormattedTime()
	return FormattedTime()
end

---@return number -- script runtime in seconds
function API.ScriptRuntime()
	return ScriptRuntime()
end

---@return string -- script runtime in the format [hh:mm:ss]
function API.ScriptRuntimeString()
	return ScriptRuntimeString()
end

---@param val boolean
function API.SetDrawLogs(val)
	return SetDrawLogs(val)
end

--  API.MarkTiles({FFPOINT.new(3179,2705,0)},0,0,2,false,false,WPOINT.new(0,0,0),WPOINT.new(0,0,0)) something like this
---@param tiles FFPOINT[] table of FFPOINT Tile_XYZ from object tiles
---@param fortime number millisec how long hold it on screen
---@param color number hex number 0xnumber https://www.rapidtables.com/web/color/RGB_Color.html
---@param thick number line thickness in float
---@param filled boolean true filled
---@param square boolean true not square
---@param pixelshape WPOINT if pixel numbers here are present then use these as boxsize
---@param pixellocation WPOINT if numbers here then use these instead of tile calculations
function API.MarkTiles(tiles, fortime, color, thick, filled, square, pixelshape, pixellocation)
	MarkTiles(tiles, fortime, color, thick, filled, square, pixelshape, pixellocation)
end

--- clear table
function API.ClearMarkTiles()
	ClearMarkTiles()
end

---@param val boolean
function API.SetDrawTrackedSkills(val)
	return SetDrawTrackedSkills(val)
end

---Get item price from exchange API
---@param itemid number|table itemid or table of itemids to lookup
---@return number|table price of table of prices with itemid as key, price as value
---@overload fun(itemids: table): table
function API.GetExchangePrice(itemid)
	return GetExchangePrice(itemid)
end

---Logs to a file with the character name into Drops folder in your ME directory
---@param itemId number
---@param qty number
---@return boolean
function API.LogDrop(itemId,qty)
	return LogDrop(itemId,qty)
end

---Grand Exchange LUADoc

---@class OrderType
---@field BUY number
---@field SELL number
OrderType = OrderType

---
-- Represents an entry in the Grand Exchange.
---@class ExchangeEntry
---@field status number The status of the order.
---@field order_type OrderType The type of order Buy|Sell.
---@field item_id number The itemid of the order.
---@field price number The price of the order.
---@field quantity number The volume of the order.
---@field completed_quantity number The completed quantity of the order.
---@field completed_value number The completed value of the order.

GrandExchange = GrandExchange

--- Sets the delay offset for sleeps in Grand Exchange actions.
---@param offset number The sleep delay offset to be added.
---@return void
function GrandExchange:DelayOffset(offset) end

-- Retrieves the data for a specific slot from the GrandExchange table.
---@function GrandExchange:GetSlotData
---@param slot number The index of the slot to retrieve data for.
---@return ExchangeEntry ExchangeEntry data associated with the specified slot.
function GrandExchange:GetSlotData(slot) end

--[[
--- Places an order in the Grand Exchange.
--- NOTE: Use Queue() instead. PlaceOrder is deprecated and kept for backwards compatibility.
---@param type OrderType The type of order to place
---@param itemId number The ID of the item.
---@param itemName string The name of the item.
---@param price number The price of the item.
---@param quantity number The quantity of the item.
---@return number Order ID if successful, -1 if item not found or on error.
function GrandExchange:PlaceOrder(type, itemId, itemName, price, quantity)
    return self:Queue(type, itemName, price, quantity)
end
--]]

--- Queues a Grand Exchange order.
--- Supports multiple overloads:
--- - Queue(type, itemName, priceStr, quantity) - string price (e.g., "500" or "160%")
--- - Queue(type, itemId, priceStr, quantity) - string price with item ID
--- - Queue(type, itemName, price, quantity) - integer price
--- - Queue(type, itemId, price, quantity) - integer price with item ID
---@param type OrderType The type of order (BUY or SELL).
---@param itemNameOrId string|number The item name (string) or item ID (number).
---@param priceStrOrInt string|number The price as string (e.g., "500" or "160%") or integer.
---@param quantity number The quantity to buy/sell.
---@return number Order ID if successful, -1 if item not found or on error.
function GrandExchange:Queue(type, itemNameOrId, priceStrOrInt, quantity) end

--- Retrieves the data for all slots in the Grand Exchange.
---@return ExchangeEntry[] ExchangeEntry array containing the data for each slot.
function GrandExchange:GetData() end

--- Checks if the player is at the Grand Exchange.
---@return boolean True if the player is at the Grand Exchange
function GrandExchange:IsAtGE() end

--- Checks if the Grand Exchange window is open.
---@return boolean True if the Grand Exchange window is open
function GrandExchange:IsGEWindowOpen() end

--- Checks if the Grand Exchange search interface is open.
---@return boolean True if the Grand Exchange search interface is open
function GrandExchange:IsGESearchOpen() end

--- Collects items from the Grand Exchange to the player's inventory.
---@return boolean
function GrandExchange:CollectToInventory() end

--- Returns to the previous interface from the Grand Exchange.
---@return boolean
function GrandExchange:Back() end

--- Opens the Grand Exchange
---@return boolean
function GrandExchange:Open() end

--- Closes the Grand Exchange
---@return boolean
function GrandExchange:Close() end

--- Returns the number of available slots in the Grand Exchange.
---@return number The number of available slots.
function GrandExchange:GetAvailableSlots() end

--- Returns the number of finished slots in the Grand Exchange.
---@return number The number of finished slots.
function GrandExchange:GetFinishedSlots() end

--- Returns the index of the next available slot in the Grand Exchange.
---@return number The index of the next available slot.
function GrandExchange:GetNextAvailableSlot() end

--- Opens a specific slot in the Grand Exchange.
---@param slot number The index of the slot to open.
---@return boolean True if the slot was successfully opened
function GrandExchange:OpenSlot(slot) end

--- Opens the next available slot in the Grand Exchange.
---@return boolean True if the next available slot was successfully opened
function GrandExchange:OpenNextAvailableSlot() end

--- Sets the quantity for an item in the Grand Exchange.
---@param quantity number The quantity to set.
---@return boolean True if the quantity was successfully set
function GrandExchange:SetQuantity(quantity) end

--- Sets the price for an item in the Grand Exchange.
---@param price number The price to set.
---@return boolean
function GrandExchange:SetPrice(price) end

--- Searches for an item in the Grand Exchange UI.
---@param itemId number The ID of the item to search for.
---@return number slotIndex of the item in the UI, or -1 if not found.
function GrandExchange:SearchForItemInUI(itemId) end

--- Selects an item in the Grand Exchange UI.
---@param itemId number The ID of the item to select.
---@return boolean True if the item was successfully selected.
function GrandExchange:SelectItem(itemId) end

--- Confirms an order in the Grand Exchange.
---@return boolean True if the order was successfully confirmed.
function GrandExchange:ConfirmOrder() end

--- Finds an order in the Grand Exchange by item ID.
---@param itemId number The ID of the item to find.
---@return number slotNumber slot number of the order, or -1 if not found.
function GrandExchange:FindOrder(itemId) end

--- Cancels an order in the Grand Exchange.
---@param slot number The slot number of the order to cancel.
---@return boolean True if the order was successfully canceled.
function GrandExchange:CancelOrder(slot) end

--- Inventory LUADoc
--- 
--- Represents an item in the Inventory.
---@class InventoryItem
---@field id number The ID of the item.
---@field name string The name of the item.
---@field amount number The size of the item stack.
---@field slot number The inventory slot the item is in.
---@field xp number The experience of the item.

--- Represents the Inventory system.
---@class Inventory
Inventory = Inventory

--- Checks whether the Inventory interface is currently open.
---@return boolean true if the Inventory is open, false otherwise.
function Inventory:IsOpen() end

--- Checks whether the Inventory is full.
---@return boolean true if the Inventory is full, false otherwise.
function Inventory:IsFull() end

--- Checks whether the Inventory is empty.
---@return boolean true if the Inventory is empty, false otherwise.
function Inventory:IsEmpty() end

---Checks if the Inventory contains a specific item or multiple items.
---Accepts a single item ID, a single item name, a table of item IDs, or a table of item names.
---@param item number|string|table
---@return boolean true if the Inventory contains the specified item(s), false otherwise.
function Inventory:Contains(item) end

--- Checks if the Inventory contains all of the specified items.
---
--- Accepts a list of item IDs or a list of item names.
---@param items table|number|string
---@return boolean true if the Inventory contains all of the items, `false otherwise.
function Inventory:ContainsAll(items) end

--- Checks if the Inventory contains any of the specified items.
---
--- Accepts a list of item IDs or a list of item names.
---@param items table|number|string
---@return boolean true if the Inventory contains any of the items, false otherwise.
function Inventory:ContainsAny(items) end

--- Checks if the Inventory contains only the specified items.
---
--- Accepts a list of item IDs or a list of item names.
---@param items table|number|string
---@return boolean true if the Inventory contains only the specified items, false otherwise.
function Inventory:ContainsOnly(items) end

--- Checks whether an item is currently selected in the Inventory.
---@return boolean true if an item is selected, false otherwise.
function Inventory:IsItemSelected() end

--- Retrieves the number of free spaces in the Inventory.
---@return number The number of free spaces in the Inventory.
function Inventory:FreeSpaces() end

--- Retrieves the experience of a specific item in the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to check.
---@return number itemXP The experience of the item. Returns -1 if not found or an error occurs.
function Inventory:GetItemXp(item) end

--- Gets the current amount of a specific item in the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to check.
---@return number amount The current amount of the item in the Inventory.
function Inventory:GetItemAmount(item) end

--- Eats a specified item from the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to eat.
---@return boolean true if the item was eaten, false otherwise.
function Inventory:Eat(item) end

--- Uses a specified item from the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to use.
---@return boolean true if the item was used, false otherwise.
function Inventory:Use(item) end

--- Rubs a piece of jewelry from the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to rub.
---@return boolean true if the item was rubbed, false otherwise.
function Inventory:Rub(item) end

--- Equips a specified item from the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to equip.
---@return boolean true if the item was equipped, false otherwise.
function Inventory:Equip(item) end

--- Drops a specified item from the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to drop.
---@return boolean true if the item was successfully dropped, false otherwise.
function Inventory:Drop(item) end

--- Notes a specified item in the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to note.
---@return boolean true if the item was noted, false otherwise.
function Inventory:NoteItem(item) end

--- Uses one item on another in the Inventory.
---
--- Accepts either an item ID or an item name for both source and target.
---@param source number|string The item ID (number) or item name (string) to use.
---@param target number|string The item ID (number) or item name (string) to use the source on.
---@return boolean true if the items were used successfully, false otherwise.
function Inventory:UseItemOnItem(source, target) end

--- Retrieves all items currently in the Inventory.
---
--- Returns a list of `InventoryItem` objects.
---@return InventoryItem[] List of all current inventory items.
function Inventory:GetItems() end

--- Retrieves all occurrences of a specific item from the Inventory.
---
--- Accepts an item ID or item name.
---@param item number|string The item ID (number) or item name (string) to retrieve.
---@return InventoryItem[] List of matching inventory items.
function Inventory:GetItem(item) end

--- Retrieves the item information for the given slot.
---
---@param slot number The slot index to retrieve the item from.
---@return InventoryItem The item information for the specified slot.
function Inventory:GetSlotData(slot) end

--@param coords bool get pixels coords, not needed if you dont plan use this data for clicking
---@return number
function Inventory:ReadInvArrays33(coords) end

---@return number
function Inventory:Invfreecount() end

---@return boolean
function Inventory:IsItemSelected() end

---@param item number
---@return number
function Inventory:InvItemcount(item) end

---@param item number
---@return boolean
function Inventory:InvItemFound(item) end

---@param items number[]
---@return boolean
function Inventory:InvItemFounds(items) end

---@param item string
---@return number
function Inventory:InvItemcount_String(item) end

---@param items string[]
---@return number
function Inventory:InvItemcountStack_Strings(items) end

---@param items number[]
---@return number
function Inventory:InvItemcounts(items) end

---@param item number
---@return number
function Inventory:InvStackSize(item) end

---@param item number
---@return boolean
function Inventory:NoteStuff(item) end

---@param items number[]
---@return boolean
function Inventory:CheckInvStuffCheckAll(items) end

---@param items number[]
---@param size number
---@param sizeorstack number
---@return boolean
function Inventory:CheckInvStuffCheckAllSS(items, size, sizeorstack) end


--- Generic DoAction function to perform a custom action on an item.
---
--- Accepts an item ID or item name along with action parameters.
---@param target number|string The item ID (number) or item name (string) to perform the action on.
---@param action number The action identifier (m_action).
---@param offset number The offset value, typically an OFF_ACT.
---@return boolean true if the action was successful, false otherwise.
function Inventory:DoAction(target, action, offset) end


--- Equipment LUADoc

--- Represents an item in the player's worn Equipment.
---@class EquipmentItem
---@field id number The ID of the item.
---@field name string The name of the item.
---@field amount number The size of the item stack.
---@field slot number The equipment slot the item is in.
---@field xp number The experience of the item.

--- Represents an ESlot item
---@class ESlot
---@field HEAD number
---@field CAPE number
---@field NECK number
---@field MAINHAND number
---@field BODY number
---@field OFFHAND number
---@field BOTTOM number
---@field GLOVES number
---@field BOOTS number
---@field RING number
---@field AMMO number
---@field AURA number
---@field POCKET number

--- Represents the Equipment system.
---@class Equipment
Equipment = Equipment

--- Retrieves the experience of an item in a specific slot.
---@param slot ESlot The equipment slot (e.g., ESlot.HEAD).
---@return number The experience of the item in the specified slot.
function Equipment:GetItemXp(slot) end

--- Checks whether the Equipment interface is currently open.
---@return boolean true if the Equipment is open, false otherwise.
function Equipment:IsOpen() end

--- Attempts to open the Equipment interface.
---@return boolean true if the Equipment was successfully opened, false otherwise.
function Equipment:OpenInterface() end

--- Checks whether the Equipment is empty.
---@return boolean true if the Equipment is empty, false otherwise.
function Equipment:IsEmpty() end

--- Checks whether the Equipment is full.
---@return boolean true if the Equipment is full, false otherwise.
function Equipment:IsFull() end

---Checks if the Equipment contains a specific item or multiple items.
---Accepts a single item ID, a single item name, a table of item IDs, or a table of item names.
---@param item number|string|table The item ID, item name
---@return boolean true if the Equipment contains the specified item(s), false otherwise.
function Equipment:Contains(item) end

--- Checks if the Equipment contains all items in the provided list.
---
--- Accepts a list of item IDs or names.
---@param items number[]|string[] A table containing item IDs (number) or names (string).
---@return boolean true if the Equipment contains all the specified items, false otherwise.
function Equipment:ContainsAll(items) end

--- Checks if the Equipment contains any item in the provided list.
---
--- Accepts a list of item IDs or names.
---@param items number[]|string[] A table containing item IDs (number) or names (string).
---@return boolean true if the Equipment contains any of the specified items, false otherwise.
function Equipment:ContainsAny(items) end

--- Checks if the Equipment contains only the items in the provided list.
---
--- Accepts a list of item IDs or names.
---@param items number[]|string[] A table containing item IDs (number) or names (string).
---@return boolean true if the Equipment contains only the specified items, false otherwise.
function Equipment:ContainsOnly(items) end

--- Unequips a specified item.
---
--- Accepts an item ID or name.
---@param item number|string The item ID (number) or name (string) to unequip.
---@return boolean true if the item was successfully unequipped, false otherwise.
function Equipment:Unequip(item) end

---@param item number|string The equipment slot to perform the action on.
---@param action number The action to perform (1,2,3 etc. Take from doAction debug).
---@return boolean true if the action was successful, false otherwise.
function Equipment:DoAction(item,action) end

--- Retrieves the item data from a specific slot.
---@param slot ESlot The equipment slot; e.g., ESlot.HEAD or ESlot.OFFHAND.
---@return EquipmentItem The item data in the specified slot.
function Equipment:GetSlotData(slot) end

--- Retrieves all items currently equipped.
---@return EquipmentItem[] Table of EquipmentItems containing all equipped items.
function Equipment:GetItems() end

--- Retrieves the equipped Helm item.
---@return EquipmentItem The item currently in the Helm slot.
function Equipment:GetHelm() end

--- Retrieves the equipped Cape item.
---@return EquipmentItem The item currently in the Cape slot.
function Equipment:GetCape() end

--- Retrieves the equipped Neck item.
---@return EquipmentItem The item currently in the Neck slot.
function Equipment:GetNeck() end

--- Retrieves the equipped Mainhand item.
---@return EquipmentItem The item currently in the Mainhand slot.
function Equipment:GetMainhand() end

--- Retrieves the equipped Body item.
---@return EquipmentItem The item currently in the Body slot.
function Equipment:GetBody() end

--- Retrieves the equipped Offhand item.
---@return EquipmentItem The item currently in the Offhand slot.
function Equipment:GetOffhand() end

--- Retrieves the equipped Bottom item.
---@return EquipmentItem The item currently in the Bottom slot.
function Equipment:GetBottom() end

--- Retrieves the equipped Gloves item.
---@return EquipmentItem The item currently in the Gloves slot.
function Equipment:GetGloves() end

--- Retrieves the equipped Boots item.
---@return EquipmentItem The item currently in the Boots slot.
function Equipment:GetBoots() end

--- Retrieves the equipped Ring item.
---@return EquipmentItem The item currently in the Ring slot.
function Equipment:GetRing() end

--- Retrieves the equipped Ammunition item.
---@return EquipmentItem The item currently in the Ammunition slot.
function Equipment:GetAmmo() end

--- Retrieves the equipped Aura item.
---@return EquipmentItem The item currently in the Aura slot.
function Equipment:GetAura() end

--- Retrieves the equipped Pocket item.
---@return EquipmentItem The item currently in the Pocket slot.
function Equipment:GetPocket() end


--- Represents the Interact system.
---@class Interact
Interact = Interact

--- Sets the default sleep time after interactions.
---@param wait number 100% sleep
---@param sleep number random sleep
---@param sleep2 number rare random sleep
function Interact:SetSleep(wait, sleep, sleep2) end

--- Carries out DoAction to the specified NPC (in place of DoAction_NPC)
---@param name string The Name of the NPC
---@param action string The Action to do against the NPC (e.g. "Attack")
---@param tile WPOINT Optional - coordinate to search around. if not specified will use player location.
---@param distance number Optional - max distance to search across. defaults to 60 if not specified.
---@retun boolean If action was sent or not
function Interact:NPC(name, action, tile, distance) end

--- Carries out DoAction to the specified Object (in place of DoAction_Object)
---@param name string The Name of the Object
---@param action string The Action to do against the Object (e.g. "Search")
---@param tile WPOINT Optional - coordinate to search around. if not specified will use player location.
---@param distance number Optional - max distance to search across. defaults to 60 if not specified.
---@retun boolean If action was sent or not
function Interact:Object(name, action, tile, distance) end

--- Represents the Familiars class.
---@class Familiars
Familiars = Familiars

--- Returns whether you have a familiar summoned or not.
---@return boolean
function Familiars:HasFamiliar() end

--- Returns whether you have a familiar summoned or not. VB check
---@return boolean
function Familiars:HasFamiliar2() end

--- Returns whether you have a familiar summoned or not. VB check
---@return boolean
function Familiars:HasFamiliarBOB() end

--- Returns the name of the familiar you have summoned.
---@return string
function Familiars:GetName() end

--- Returns the amount of seconds (in chunks of 30) that the familiar has remaining.
---@return number
function Familiars:GetTimeRemaining() end

--- Returns whether or not you have a pouch available in your inventory to renew the familiar.
---@return boolean
function Familiars:CanRenew() end

--- Returns the number of spell points you have remaining (out of 60).
---@return number
function Familiars:GetSpellPoints() end

--- Returns Summoning points left.
---@return number
function Familiars:GetSummoningPoints() end

--- Returns Summoning level
---@return number
function Familiars:GetSummoningLevel() end

--- Returns the health of your familiar
---@return number
function Familiars:GetHealth() end

--- Returns the health of your familiar
---@return number
function Familiars:GetHealthMax() end

--- Casts the familiar's special attack
---@return boolean
function Familiars:CastSpecialAttack() end

--- Returns number slots from, 32 always even your bob dont have that much
---@return number
function Familiars:Storage_FreeAm() end

--- Returns list of stored items, 32 always even your bob dont have that much
---@return number[]
function Familiars:Storage_List() end

--- Checks if item is on familiar
---@return boolean
function Familiars:Storage_Contains(item) end

--- Checks if it is open
---@return boolean
function Familiars:FamiliarTabOpen() end

--- Checks if it is open
---@return boolean
function Familiars:Storage_InterfaceOpen() end

--- Checks if open if not then open
---@return boolean
function Familiars:SwitchToStorage() end

--- Checks if open then does it
---@return boolean
function Familiars:GiveAllBurden() end

--- Checks if open then does it
---@return boolean
function Familiars:TakeAllBurden() end

--- Checks if open then does it
---@return boolean
function Familiars:Storage_InterfaceTake(item) end

---@class TickEvent
TickEvent = TickEvent

--Register a function to be called every game tick 
--#################NO SLEEP HERE#################
---@param callback function
---@return void
function TickEvent.Register(callback) end

---@return number
function TickEvent.GetCounter() end

---@class item
Item = Item

--[[
Common Item Parameter Names (for HasParam):
  "bankable", "alchable"
Usage:
  item:HasParam("bankable")   -- by param name
]]

--- Accepts an item ID or name.
---@param item number|string The Item ID or Name of the item to search for
---@param tradeable boolean filter - if not specified, it will not care if tradeable or not. Otherwise it will filter for tradeable=true/false
---@return ItemData
function Item:Get(item, tradeable) end

---@param item string Input Item Name here
---@param partial_match boolean optional flag to partially match item name (defaults to strict match)
---@return table Returns a table of ItemData objects that matched your search string
function Item:GetAll(item, partial_match) end

---@class DiscordEmbed
local DiscordEmbed = {}

---@return DiscordEmbed a new DiscordEmbed object
function DiscordEmbed.new() end

--- Sets the title of the embed message.
---@param title string The title of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:SetTitle(title) end

--- Sets the description of the embed message.
---@param description string The description of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:SetDescription(description) end

--- Sets the color of the embed message.
---@param color number The color of the embed message, specified as an integer (e.g., 0xFF0000 for red).
---@return DiscordEmbed self
function DiscordEmbed:SetColor(color) end

--- Sets the URL of the embed message.
---@param url string The URL of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:SetUrl(url) end

--- Sets the timestamp of the embed message.
---@param timestamp number The timestamp of the embed message (UNIX TIME) 
---@return DiscordEmbed self
function DiscordEmbed:SetTimestamp(timestamp) end

--- Sets the footer of the embed message.
---@param footer EmbedFooter The footer of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:SetFooter(footer) end

--- Sets the image of the embed message.
---@param image EmbedImage The image of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:SetImage(image) end

--- Sets the thumbnail of the embed message.
---@param thumbnail EmbedThumbnail The thumbnail of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:SetThumbnail(thumbnail) end

--- Sets the author of the embed message.
---@param author EmbedAuthor The author of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:SetAuthor(author) end

--- Adds a field to the embed message.
---@param field EmbedField The field of the embed message.
---@return DiscordEmbed self
function DiscordEmbed:AddField(field) end

---@class Discord
Discord = Discord

--- Sends an embed message to a Discord webhook.
---This function constructs an embed message with a title, description, color, and optional user mention, 
---and sends it to the specified Discord webhook URL from settings.json
---
---@param title string The title of the embed message.
---@param description string The description of the embed message.
---@param color number The color of the embed message, specified as an integer (e.g., 16711680 for red).
---@param mention boolean A flag to mention a user. If true, the user will be mentioned in the message. 
---@return boolean Returns true if the message was successfully sent, false otherwise.
function Discord:SendEmbed(title, description, color, mention) end

--- Sends an embed message to a Discord webhook.
---This function constructs an embed message with a title, description, color, and optional user mention, 
---and sends it to the specified Discord webhook URL from settings.json
---
---@param embed DiscordEmbed an embed builder object.
---@param mention boolean A flag to mention a user. If true, the user will be mentioned in the message. 
---@return boolean Returns true if the message was successfully sent, false otherwise.
function Discord:SendEmbedEx(embed, mention) end

---@class Quest
Quest = Quest

--- Accepts a quest ID or exact name.
---@param quest number|string The Quest ID or exact name to search for
---@return QuestData
function Quest:Get(quest) end

--- *Cache required* Looks up a varbit value
--- E.g VB lookup for SoulSplit would now be API.GetVarbitValue(16779)
--- But using our traditional varp/vb functions it would have to look like API.VB_FindPSettinOrder(3275, 0).state >> 18 & 1
---@param id number varbit ID
---@return number varbit current value
function API.GetVarbitValue(id)
	return GetVarbitValue(id)
end


--- Takes the top level varp ID and returns all of the associated varbit objects for that Varp
---@param id number varp ID
---@return table|Varbit
function API.GetVarbitsFromVarp(id)
	return GetVarbitsFromVarp(id)
end

--- Represents the SOC class.
---@class SOC
SOC = SOC

-- Message minimum size is 24 bytes, 23 bytes are reserved for info, after that is THE message
-- 0-7 bytes are PID in string form
-- 8-12 is player name
-- 21 byte 1 is hide debug text
-- 22 byte is operation code, not used
-- to send from other systems to ME server write 23 zero bytes and then message bytes
--[[
only few commands via messages are directly to the server currently
"DirectCommand::Server_Close(true)"
"DirectCommand::Server_Close(false)"
"DirectCommand::Server_Debug(true)"
"DirectCommand::Server_Debug(false)"
--]]

--- Starts a server for the SOC (Socket Object Communication) system.
---@param port number The port to start the server on.
---@param forcereset boolean reset started boolean.
---@return boolean if successful
function SOC:StartServer(port,forcereset) end

--- Sees only local status
---@return boolean True if the server was successfully started, false otherwise.
function SOC:IsServerStarted() end

--- Asks form server. Returns false if it cant find server.
---@return boolean True if the server was successfully started, false otherwise.
function SOC:AskIsServerStarted() end

---@param type number 0 all clients, 1 player, 2 PID
---@param ident string player name or PID
---@param stext string message to send
---@return boolean if successful
function SOC:MessageClients(type, ident, stext) end

--- Starts a client for the SOC (Socket Object Communication) system.
---@param port number The port to start the server on.
---@param forcereset boolean reset started boolean.
---@return boolean if successful
function SOC:StartClient(port,forcereset) end

--- Sees only local status
---@return boolean True if the client was successfully started, false otherwise.
function SOC:IsClientStarted() end

---@param stext string message to send
---@return boolean if successful
function SOC:MessageServer(stext) end

--- Get whole message that are stored here but server sent a while ago
---@return string
function SOC:ClientAskMessage() end

--- Get whole messages that are stored here but server sent a while ago
---@return string[]
function SOC:ClientAskMessages() end

--- Client sent message on server
---@return string
function SOC:ServerAskMessage() end

--- Client sent message on server
---@param timeoutMs number timeout in milliseconds
---@return string
function SOC:ServerAskMessage2(timeoutMs) end

--- Client sent messages on server
---@return string[]
function SOC:ServerAskMessages() end

--- Request server and server socket to be closed
-- @param clear boolean If true then clear previous data
---@return void
function SOC:Server_Close(clear) end

--- Request client and server client to be closed
-- @param clear boolean If true then clear previous data
---@return void
function SOC:Client_Close(clear) end

--- Debug server
-- @param onoff boolean
---@return void
function SOC:Server_Debug(onoff) end

---@class Achievement
Achievement = Achievement

--- Accepts an Achievement ID OR exact name, returns AchievementData object
---@param achievement number|string The Achievement ID or exact name to search for
---@return AchievementData
function Achievement:Get(achievement) end

--- Returns all achievements as a table of AchievementData objects
---@return AchievementData[]
function Achievement:GetAll() end

---@class Struct
Struct = Struct

--- Accepts a Struct ID, returns StructData object
---@param id Number
---@return StructData
function Struct:Get(id) end

--- Returns all structs as a table of StructData objects
---@return StructData[]
function Struct:GetAll() end

---@class DBRow
DBRow = DBRow

--- Accepts a DBRow ID and returns a DBRowData object with parsed column data
---@param id number The DBRow ID to look up
---@return DBRowData
function DBRow:Get(id) end

--- Returns all DBRow entries belonging to a specific table ID
---@param tableId number The table ID to filter by
---@return DBRowData[]
function DBRow:GetByTable(tableId) end

---- CAUTION THESE FUNCTIONS USE MOUSE ----
---- DEPRECATED FUNCTIONS ----
---- UNCOMMENT IF YOU REALLY WANNA USE ----

--[[

---@return boolean
function API.BankAllItems()
	return BankAllItems()
end

---@param Except_item table|number
---@return boolean
function API.BankAllItem_InvExceptintM(Except_item)
	return BankAllItem_InvExceptintM(Except_item)
end

---@param Except_item table|string
---@return boolean
function API.BankAllItem_InvExceptstrM(Except_item)
	return BankAllItem_InvExceptstrM(Except_item)
end

---@param id number
---@param mouse number
---@return boolean
function API.BankClickItem(id, mouse)
	return BankClickItem(id, mouse)
end

---@param id number
---@param mouse number
---@return boolean
function API.BankClickItem_Inv(id, mouse)
	return BankClickItem_Inv(id, mouse)
end

---@param id number
---@param choose_text string
---@return boolean
function API.BankClickItem_InvChoose(id, choose_text)
	return BankClickItem_InvChoose(id, choose_text)
end

---@return void
function API.BankClose()
	return BankClose()
end

---@param txt_to_find string
---@return boolean
function API.SelectToolOpen(txt_to_find)
	return SelectToolOpen(txt_to_find)
end

---@param Except_itemv table|number
---@return boolean
function API.LootWindow_Loot(Except_itemv)
	return LootWindow_Loot(Except_itemv)
end

---@param choice string
---@return boolean
function API.SelectCOption_(choice)
	return SelectCOption_(choice)
end

---@param choice string
---@param user string
---@return WPOINT
function API.SelectCOption2(choice, user)
	return SelectCOption2(choice, user)
end

---@param choice string
---@param user string
---@return boolean
function API.SelectCOption2_(choice, user)
	return SelectCOption2_(choice, user)
end

---@param choice string
---@return WPOINT
function API.SelectCOption(choice)
	return SelectCOption(choice)
end

---@param choice string
---@param move boolean
---@return boolean
function API.SelectCOption_Click(choice, move)
	return SelectCOption_Click(choice, move)
end

---@return boolean
function API.OpenEquipInterface2()
	return OpenEquipInterface2()
end

---@return boolean
function API.OpenInventoryInterface2()
	return OpenInventoryInterface2()
end

--old
---@param xy table|number c POINT
---@param mouse number
---@return void
function API.ClickTile_1(xy, mouse)
	return ClickTile_(xy, mouse)
end

--old
---@param x number
---@param y number
---@param z number
---@param mouse number
---@return void
function API.ClickTile_2(x, y, z, mouse)
	return ClickTile_(x, y, z, mouse)
end

---@param Except_item table|number
---@param maxdistance number
---@param accuracy number
---@param tilespot WPOINT
---@param maxdistance2 number
---@param items_to_eat table|number
---@return boolean
function API.FindGItem_AllBut2(Except_item, maxdistance, accuracy, tilespot, maxdistance2, items_to_eat)
	return FindGItem_AllBut2(Except_item, maxdistance, accuracy, tilespot, maxdistance2, items_to_eat)
end

---old
---@param ItemCoord2 FFPOINT
---@return boolean
function API.ClickMapTile_(ItemCoord2)
	return ClickMapTile_(ItemCoord2)
end

---old
---@param ItemCoord2 table|number --c POINT
---@return boolean
function API.ClickMapTile_2(ItemCoord2)
	return ClickMapTile_2(ItemCoord2)
end

---@param tilexy FFPOINT
---@param distance number
---@return void
function API.Map_Walker1(tilexy, distance)
	return Map_Walker1(tilexy, distance)
end

---@param tilexy2 WPOINT
---@param distance number
---@return void
function API.Map_Walker1NT(tilexy2, distance)
	return Map_Walker1NT(tilexy2, distance)
end

---@param tilexy FFPOINT
---@param distance number
---@return void
function API.Map_Walker2(tilexy, distance)
	return Map_Walker2(tilexy, distance)
end

---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@return boolean
function API.FindObj1(obj, maxdistance, accuracy, usemap, action, sidetext)
	return FindObj(obj, maxdistance, accuracy, usemap, action, sidetext)
end

---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext table|string
---@return boolean
function API.FindObj2(obj, maxdistance, accuracy, usemap, action, sidetext)
	return FindObj(obj, maxdistance, accuracy, usemap, action, sidetext)
end

---@param AllStuff2 table|AllObject
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@return boolean
function API.ClickAllObj1(AllStuff2, accuracy, usemap, action, sidetext)
	return ClickAllObj(AllStuff2, accuracy, usemap, action, sidetext)
end

---@param AllStuff2 table|AllObject
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext table|string
---@return boolean
function API.ClickAllObj2(AllStuff2, accuracy, usemap, action, sidetext)
	return ClickAllObj(AllStuff2, accuracy, usemap, action, sidetext)
end

---@param dx number
---@param dy number
---@return number
function API.Hypot(dx, dy)
	return Hypot(dx, dy)
end

---@param x number
---@param y number
---@param rx number
---@param ry number
---@return boolean
function API.MoveMouse2(x, y, rx, ry)
	return MoveMouse2(x, y, rx, ry)
end

---@param x number
---@param y number
---@return boolean
function API.MoveMouse3(x, y)
	return MoveMouse3(x, y,)
end

---@param sleep number
---@param rand number
---@return boolean
function API.MouseLeftClick(sleep, rand)
	return MouseLeftClick(sleep, rand)
end

---@param sleep number
---@param rand number
---@return boolean
function API.MouseRightClick(sleep, rand)
	return MouseRightClick(sleep, rand)
end

---@param x number
---@param y number
---@param sleep number
---@param random number
---@return boolean
function API.Post_MouseLeftClick(x, y, sleep, random)
	return Post_MouseLeftClick(x, y, sleep, random)
end

---@param x number
---@param y number
---@param sleep number
---@param random number
---@return boolean
function API.Post_MouseRightClick(x, y, sleep, random)
	return Post_MouseRightClick(x, y, sleep, random)
end

-- old
---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@param highlight table|number
---@return boolean
function API.FindHl(obj, maxdistance, accuracy, usemap, action, sidetext, highlight)
	return FindHl(obj, maxdistance, accuracy, usemap, action, sidetext, highlight)
end

-- old
---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@return boolean
function API.FindObjCheck(obj, maxdistance, accuracy, usemap, action, sidetext)
	return FindObjCheck(obj, maxdistance, accuracy, usemap, action, sidetext)
end

-- old
---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param objtile WPOINT
---@param usemap boolean
---@param action number
---@param sidetext string
---@return boolean
function API.FindObjTile(obj, maxdistance, accuracy, objtile, usemap, action, sidetext)
	return FindObjTile(obj, maxdistance, accuracy, objtile, usemap, action, sidetext)
end

---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@return boolean
function API.FindObjCheck_1(obj, maxdistance, accuracy, usemap, action, sidetext)
	return FindObjCheck_(obj, maxdistance, accuracy, usemap, action, sidetext)
end

---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@param tile WPOINT
---@return boolean
function API.FindObjCheck_2(obj, maxdistance, accuracy, usemap, action, sidetext, tile)
	return FindObjCheck_(obj, maxdistance, accuracy, usemap, action, sidetext, tile)
end

---@param objIds table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@param hlIds table|number
---@param localp_dist number --float
---@return boolean
function API.FindHLvsLocalPlayer(objIds, maxdistance, accuracy, usemap, action, sidetext, hlIds, localp_dist)
	return FindHLvsLocalPlayer(objIds, maxdistance, accuracy, usemap, action, sidetext, hlIds, localp_dist)
end

---@param obj table|number
---@param maxdistance number
---@param accuracy number
---@param usemap boolean
---@param action number
---@param sidetext string
---@return boolean
function API.FindHObj(obj, maxdistance, accuracy, usemap, action, sidetext)
	return FindHObj(obj, maxdistance, accuracy, usemap, action, sidetext)
end

---@param npc table|number
---@param maxdistance number
---@param accuracy number
---@param lifepoint number
---@param tilespot WPOINT
---@param maxdistance2 number
---@param action number
---@param sidetext string
---@return boolean
function API.FindNPCss(npc, maxdistance, accuracy, lifepoint, tilespot, maxdistance2, action, sidetext)
	return FindNPCss(npc, maxdistance, accuracy, lifepoint, tilespot, maxdistance2, action, sidetext)
end

---@param npc table|number
---@param maxdistance number
---@param accuracy number
---@param lifepoints number
---@param tilespot WPOINT
---@param maxdistance2 number
---@param action number
---@param sidetext table|string
---@return boolean
function API.FindNPCssMulti(npc, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
	return FindNPCssMulti(npc, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
end

---@param NPC_name string
---@param maxdistance number
---@param accuracy number
---@param lifepoints number
---@param tilespot WPOINT
---@param maxdistance2 number
---@param action number
---@param sidetext string
---@return boolean
function API.FindNPCssSTRRem(NPC_name, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
	return FindNPCssSTRRem(NPC_name, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
end

---@param NPC_name string
---@param maxdistance number
---@param accuracy number
---@param lifepoints number
---@param tilespot WPOINT
---@param maxdistance2 number
---@param action number
---@param sidetext string
---@return boolean
function API.FindNPCssSTR(NPC_name, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
	return FindNPCssSTR(NPC_name, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
end

---@param NPC_names table|string
---@param maxdistance number
---@param accuracy number
---@param lifepoints number
---@param tilespot WPOINT
---@param maxdistance2 number
---@param action number
---@param sidetext string
---@return boolean
function API.FindNPCssSTRs(NPC_names, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
	return FindNPCssSTRs(NPC_names, maxdistance, accuracy, lifepoints, tilespot, maxdistance2, action, sidetext)
end

---@return void
function API.RandomEvents()
	return RandomEvents()
end

---- END OF DEPRECATED GOODNESS ----

--]]

--- Represents the Perks system for managing augmented items and invention perks
---@class Perks
Perks = Perks

--- Gets all augmented items from both inventory and equipment
---@return AugmentedItem[] Array of all augmented items
function Perks:GetAllAugmentedItems() end

--- Gets all augmented items from equipment only
---@return AugmentedItem[] Array of augmented items in equipment
function Perks:GetEquipmentPerks() end

--- Gets all augmented items from inventory only
---@return AugmentedItem[] Array of augmented items in inventory
function Perks:GetInventoryPerks() end

--- Checks if a specific perk is currently equipped
---@param perkIdOrName number|string The ID or name of the perk to check
---@return boolean True if the perk is equipped, false otherwise
function Perks:IsPerkEquipped(perkIdOrName) end

--- Checks if a specific perk is in the inventory
---@param perkIdOrName number|string The ID or name of the perk to check
---@return boolean True if the perk is in inventory, false otherwise
function Perks:IsPerkInInventory(perkIdOrName) end

--- Gets all perks from the main hand weapon
---@return PerkInfo[] Array of perks on the main hand weapon
function Perks:GetMainHandPerks() end

--- Gets all perks from the off-hand weapon/shield
---@return PerkInfo[] Array of perks on the off-hand item
function Perks:GetOffHandPerks() end

--- Gets all perks from the chest armor
---@return PerkInfo[] Array of perks on the chest armor
function Perks:GetChestPerks() end

--- Gets all perks from the leg armor
---@return PerkInfo[] Array of perks on the leg armor
function Perks:GetLegsPerks() end

--- Gets the augmented item from a specific slot
---@param slot number The slot number to check
---@param fromEquipment boolean True to check equipment, false for inventory
---@return AugmentedItem The augmented item in the specified slot
function Perks:GetAugmentedItemFromSlot(slot, fromEquipment) end

--- Gets the item experience from a specific slot
---@param slot number The slot number to check
---@param fromEquipment boolean True to check equipment, false for inventory
---@return number The item experience value
function Perks:GetItemExpFromSlot(slot, fromEquipment) end

--- Finds all items that have a specific perk
---@param perkIdOrName number|string The ID or name of the perk to search for
---@return AugmentedItem[] Array of items containing the specified perk
function Perks:FindItemsWithPerk(perkIdOrName) end

--- Gets the perk ID by its name
---@param perkName string The name of the perk
---@return number The perk ID, or -1 if not found
function Perks:GetPerkIdByName(perkName) end

--- Represents the Script Manager configuration system for creating dynamic script UIs
---@class SM
SM = SM

--- Creates a new tab in the configuration window
--- Subsequent configuration elements will be grouped under this tab until another tab is created
---@param tabName string The display name for the tab
function SM:AddTab(tabName) end

--- Creates a dropdown selection element with predefined options
--- The selected value is passed to scripts as an index (0-based)
---@param label string The display label for the dropdown
---@param key string The unique key used to access the value in the CONFIG table
---@param options string[] Array of option strings to display in the dropdown
---@param defaultValue string The default selected option (must match one of the options)
function SM:Dropdown(label, key, options, defaultValue) end

--- Creates a checkbox element for boolean values
--- The value is passed to scripts as a boolean
---@param label string The display label for the checkbox
---@param key string The unique key used to access the value in the CONFIG table
---@param defaultValue boolean The default checked state (true or false)
function SM:Checkbox(label, key, defaultValue) end

--- Creates a text input field for string values
--- The value is passed to scripts as a string
---@param label string The display label for the text input
---@param key string The unique key used to access the value in the CONFIG table
---@param defaultValue string The default text content
function SM:TextInput(label, key, defaultValue) end

--- Creates a password input field with masked characters
--- The value is passed to scripts as a string
---@param label string The display label for the password input
---@param key string The unique key used to access the value in the CONFIG table
---@param defaultValue string The default password content
function SM:PasswordInput(label, key, defaultValue) end

--- Creates a number input field for integer values
--- The value is passed to scripts as an integer
---@param label string The display label for the number input
---@param key string The unique key used to access the value in the CONFIG table
---@param defaultValue number The default numeric value
---@param minValue number|nil Optional minimum allowed value
---@param maxValue number|nil Optional maximum allowed value
function SM:NumberInput(label, key, defaultValue, minValue, maxValue) end

--- Creates a slider element for numeric values with visual range selection
--- The value is passed to scripts as a float
---@param label string The display label for the slider
---@param key string The unique key used to access the value in the CONFIG table
---@param minValue number The minimum value of the slider range
---@param maxValue number The maximum value of the slider range
---@param defaultValue number The default slider position
function SM:Slider(label, key, minValue, maxValue, defaultValue) end

--- Creates a string array element where users can add/remove string values
--- The value is passed to scripts as a Lua table array of strings
---@param label string The display label for the array
---@param key string The unique key used to access the value in the CONFIG table
---@param customArray string[]|nil Optional initial custom array values
---@param defaultArray string[]|nil Optional default values shown as reference
function SM:AddStringArray(label, key, customArray, defaultArray) end

--- Creates a number array element where users can add/remove integer values
--- The value is passed to scripts as a Lua table array of numbers
---@param label string The display label for the array
---@param key string The unique key used to access the value in the CONFIG table
---@param customArray number[]|nil Optional initial custom array values
---@param defaultArray number[]|nil Optional default values shown as reference
function SM:AddNumberArray(label, key, customArray, defaultArray) end

--- Creates a standalone tile coordinate input with X, Y, Z fields
--- The value is passed to scripts as a Lua table {x=, y=, z=}
---@param label string The display label for the tile
---@param key string The unique key used to access the value in the CONFIG table
---@param defaultValue table|nil Optional default tile {x=, y=, z=} or nil for 0,0,0
function SM:Tile(label, key, defaultValue) end

--- Creates a tile array element where users can add/remove XYZ coordinate values
--- The value is passed to scripts as a Lua table array of {x=, y=, z=} tables
---@param label string The display label for the array
---@param key string The unique key used to access the value in the CONFIG table
---@param customArray table[]|nil Optional initial custom array values
---@param defaultArray table[]|nil Optional default values shown as reference
function SM:AddTileArray(label, key, customArray, defaultArray) end

--- Creates a custom array element with mixed field types per row
--- The value is passed to scripts as a Lua table array of arrays
--- Field types: "text", "number", "checkbox", "dropdown", "slider", "tile"
---@param label string The display label for the array
---@param key string The unique key used to access the value in the CONFIG table
---@param fieldTypes table Array of field type strings: {"text", "number", "checkbox", "dropdown", "slider", "tile"}
---@param fieldLabels table|nil Optional array of labels for each field: {"Item", "Count", "Enabled"}
---@param extraParams table|nil Optional table of tables for dropdown/slider params (one per field, empty {} if not needed). Tile stored as "x,y,z" string
---@param customArray table[]|nil Optional initial custom array values
---@param defaultArray table[]|nil Optional default values shown as reference
function SM:AddCustomArray(label, key, fieldTypes, fieldLabels, extraParams, customArray, defaultArray) end

--[[
Configuration System Usage:

1. Create a config.lua file in your script's directory
2. Use SM: functions to define configuration elements
3. Access values in your script via the global CONFIG table

Example config.lua:
```lua
SM:AddTab("Combat")
SM:Dropdown("Prayer Type", "prayerType", {"Curses", "Prayers"}, "Curses")
SM:Checkbox("Hard Mode", "hardMode", false)

SM:AddTab("Settings")
SM:TextInput("Player Name", "playerName", "")
SM:Slider("Wait Time", "waitTime", 100, 5000, 1000)
SM:Tile("Tile to move", "tileToMove", {x=3000, y=3000, z=0})

SM:AddTab("Arrays")
SM:AddStringArray("Item Names", "itemNames", {}, {"Oak logs", "Raw lobster"})
SM:AddNumberArray("Item IDs", "itemIds", {}, {1511, 377})
SM:AddTileArray("Bank Tiles", "bankTiles", {}, {})

-- Simple CustomArray without labels or extra params
SM:AddCustomArray("Simple List", "simpleList", {"text", "number", "checkbox"}, {}, {}, {}, {})

-- CustomArray with labels
SM:AddCustomArray("Basic Config", "basicConfig", {"text", "number", "checkbox"}, {"Item Name", "Min Value", "Loot?"}, {}, {}, {})

-- CustomArray with dropdown and slider
SM:AddCustomArray("Advanced Config", "advancedConfig", {"dropdown", "number", "slider"}, {"Mode", "Count", "Speed"}, {{"Easy", "Medium", "Hard"}, {}, {"0", "100", "50"}}, {}, {})
```

Example script usage:
```lua
if CONFIG then
    if CONFIG.prayerType == 0 then
        -- User selected "Curses" (first option)
    elseif CONFIG.prayerType == 1 then
        -- User selected "Prayers" (second option)
    end

    if CONFIG.hardMode then
        -- Hard mode is enabled
    end

    local playerName = CONFIG.playerName or "DefaultName"
    local waitTime = CONFIG.waitTime or 1000

    -- Tile example
    if CONFIG.tileToMove then
        print("Tile: X=" .. CONFIG.tileToMove.x .. " Y=" .. CONFIG.tileToMove.y .. " Z=" .. CONFIG.tileToMove.z)
    end

    -- Array examples
    if CONFIG.itemNames then
        for i, name in ipairs(CONFIG.itemNames) do
            print("Item " .. i .. ": " .. name)
        end
    end

    if CONFIG.bankTiles then
        for i, tile in ipairs(CONFIG.bankTiles) do
            print("Tile " .. i .. ": X=" .. tile.x .. " Y=" .. tile.y .. " Z=" .. tile.z)
        end
    end

    -- CustomArray examples
    if CONFIG.basicConfig then
        for i, config in ipairs(CONFIG.basicConfig) do
            local itemName = config[1]    -- text field
            local minValue = config[2]    -- number field
            local shouldLoot = config[3]  -- checkbox (boolean)
            print("Config " .. i .. ": " .. itemName .. " (min: " .. minValue .. ", enabled: " .. tostring(shouldLoot) .. ")")
        end
    end

    if CONFIG.advancedConfig then
        for i, config in ipairs(CONFIG.advancedConfig) do
            local mode = config[1]     -- dropdown index (0=Easy, 1=Medium, 2=Hard)
            local count = config[2]    -- number field
            local speed = config[3]    -- slider value (float 0-100)
            print("Advanced " .. i .. ": mode=" .. mode .. ", count=" .. count .. ", speed=" .. speed)
        end
    end
end
```

Notes:
- Dropdown values are 0-based indices
- All values are optional and should be checked before use
- Configuration is automatically saved/loaded per script
- Each script can have its own independent configuration
- Arrays are 1-indexed Lua tables
- Default arrays are shown as reference but not editable
- Users can add/remove items using +/- buttons in the UI
--]]

--- Represents an HTTP response from a request.
---@class HttpResponse
---@field statusCode number The HTTP status code (200 = success, 403 = forbidden, 404 = not found, 500 = server error).
---@field body string The response body content from the server.


---@class Http
Http = Http

--- Sends an HTTP POST request with JSON data to an allowed host.
--- 
--- Examples:
--- -- Basic POST request
--- local data = API.JsonEncode({message = "Hello", player = API.GetLocalPlayerName()})
--- local response = Http:Post("http://localhost:3000/api/data", data)
--- 
--- -- POST request with headers
--- local headers = {"Authorization: Bearer your-token", "X-Custom-Header: value"}
--- local response = Http:Post("http://api.example.com/data", data, headers)
--- 
--- if response.statusCode == 200 then
---     print("Success: " .. response.body)
--- end
---@param url string The complete URL to send the request to.
---@param jsonData string JSON-formatted string containing the data to send.
---@param headers? string[] Optional array of header strings in "Name: Value" format.
---@return HttpResponse The response table with statusCode and body fields.
function Http:Post(url, jsonData, headers) end

--- Sends an HTTP GET request to an allowed host.
--- 
--- Examples:
--- -- Basic GET request
--- local response = Http:Get("http://api.example.com/player/stats")
--- 
--- -- GET request with headers
--- local headers = {"Authorization: Bearer your-token", "X-API-Key: your-key"}
--- local response = Http:Get("http://api.example.com/player/stats", headers)
--- 
--- if response.statusCode == 200 then
---     local data = API.JsonDecode(response.body)
---     print("Level: " .. data.level)
--- end
---@param url string The complete URL to send the request to.
---@param headers? string[] Optional array of header strings in "Name: Value" format.
---@return HttpResponse The response table with statusCode and body fields.
function Http:Get(url, headers) end

-------------------------------------------------------------------------------
-- ImGui Direct Bindings
-------------------------------------------------------------------------------
-- These bindings expose Dear ImGui functions directly to Lua scripts.
-- Use DrawImGui(function() ... end) to register a render callback, then call
-- ImGui.Begin(), ImGui.Text(), ImGui.Button() etc. inside it.
--
-- Out-parameter pattern: widgets that modify a value return (changed, newValue).
--   local changed, value = ImGui.Checkbox("Enable", myBool)
--   if changed then myBool = value end
--
-- Example usage:
--   local speed = 50.0
--   local enabled = true
--   DrawImGui(function()
--       ImGui.Begin("My Window")
--       ImGui.Text("Hello from Lua!")
--       if ImGui.Button("Click Me") then print("clicked") end
--       local c1, v1 = ImGui.SliderFloat("Speed", speed, 0, 100)
--       if c1 then speed = v1 end
--       local c2, v2 = ImGui.Checkbox("Enabled", enabled)
--       if c2 then enabled = v2 end
--       ImGui.End()
--   end)
-------------------------------------------------------------------------------

if false then -- LuaDoc stubs for IDE autocompletion only; never executed at runtime

---@class ImGui
ImGui = ImGui

--- Register a render callback. The function is called every frame.
--- All ImGui calls must happen inside this callback.
---@param func function The render callback function
function DrawImGui(func) end

--- Clears all registered render callbacks.
function ClearRender() end

-- ============================================================================
-- Windows
-- ============================================================================

--- Begin a new window. Must be paired with ImGui.End().
---@param name string Window title / ID
---@param flags? number ImGuiWindowFlags (default 0)
---@return boolean visible Whether the window content should be rendered (not collapsed/clipped)
function ImGui.Begin(name, flags) end

--- Begin a closable window. Returns open state and visibility.
---@param name string Window title / ID
---@param open boolean Whether the window is open (pass current state)
---@param flags? number ImGuiWindowFlags (default 0)
---@return boolean open Whether the window is still open (false if user closed it)
---@return boolean visible Whether the window content should be rendered
function ImGui.Begin(name, open, flags) end

--- End the current window. Must match a Begin() call.
function ImGui.End() end

--- Begin a child region. Must be paired with EndChild().
---@param id string Child region ID
---@param sx? number Width (0 = auto)
---@param sy? number Height (0 = auto)
---@param child_flags? number ImGuiChildFlags (default 0)
---@param window_flags? number ImGuiWindowFlags (default 0)
---@return boolean visible
function ImGui.BeginChild(id, sx, sy, child_flags, window_flags) end

--- End the current child region.
function ImGui.EndChild() end

--- Set position of next window.
---@param x number X position
---@param y number Y position
---@param cond? number ImGuiCond (default 0 = Always)
---@param pivot_x? number Pivot X (0-1, default 0)
---@param pivot_y? number Pivot Y (0-1, default 0)
function ImGui.SetNextWindowPos(x, y, cond, pivot_x, pivot_y) end

--- Set size of next window.
---@param x number Width
---@param y number Height
---@param cond? number ImGuiCond (default 0 = Always)
function ImGui.SetNextWindowSize(x, y, cond) end

--- Set collapsed state of next window.
---@param collapsed boolean
---@param cond? number ImGuiCond (default 0)
function ImGui.SetNextWindowCollapsed(collapsed, cond) end

--- Set next window to be focused.
function ImGui.SetNextWindowFocus() end

--- Set background alpha of next window.
---@param alpha number Alpha value (0.0 - 1.0)
function ImGui.SetNextWindowBgAlpha(alpha) end

--- Get current window position.
---@return number x
---@return number y
function ImGui.GetWindowPos() end

--- Get current window size.
---@return number width
---@return number height
function ImGui.GetWindowSize() end

--- Get current window width.
---@return number
function ImGui.GetWindowWidth() end

--- Get current window height.
---@return number
function ImGui.GetWindowHeight() end

--- Returns true if the current window is appearing (e.g. first frame).
---@return boolean
function ImGui.IsWindowAppearing() end

--- Returns true if the current window is collapsed.
---@return boolean
function ImGui.IsWindowCollapsed() end

--- Returns true if the current window is focused.
---@param flags? number ImGuiFocusedFlags (default 0)
---@return boolean
function ImGui.IsWindowFocused(flags) end

--- Returns true if the current window is hovered.
---@param flags? number ImGuiHoveredFlags (default 0)
---@return boolean
function ImGui.IsWindowHovered(flags) end

-- ============================================================================
-- Text
-- ============================================================================

--- Display text (safe, no format string interpretation).
---@param text string
function ImGui.Text(text) end

--- Display colored text.
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number Alpha (0-1)
---@param text string
function ImGui.TextColored(r, g, b, a, text) end

--- Display grayed-out (disabled) text.
---@param text string
function ImGui.TextDisabled(text) end

--- Display text with word wrapping at the current content region width.
---@param text string
function ImGui.TextWrapped(text) end

--- Display text+label aligned the same way as value+label widgets.
---@param label string
---@param text string
function ImGui.LabelText(label, text) end

--- Display text with a bullet point.
---@param text string
function ImGui.BulletText(text) end

--- Display a horizontal separator line with text in the middle.
---@param text string
function ImGui.SeparatorText(text) end

--- Display raw text without any formatting.
---@param text string
function ImGui.TextUnformatted(text) end

-- ============================================================================
-- Layout
-- ============================================================================

--- Draw a horizontal separator line.
function ImGui.Separator() end

--- Place next widget on the same line as the previous one.
---@param offset_from_start_x? number Offset from region start (default 0)
---@param spacing? number Spacing between items (default -1 = auto)
function ImGui.SameLine(offset_from_start_x, spacing) end

--- Undo a SameLine() or force a new line when in a horizontal layout.
function ImGui.NewLine() end

--- Add vertical spacing.
function ImGui.Spacing() end

--- Move content position to the right by indent_w or style.IndentSpacing.
---@param indent_w? number (default 0 = use style.IndentSpacing)
function ImGui.Indent(indent_w) end

--- Move content position to the left.
---@param indent_w? number (default 0 = use style.IndentSpacing)
function ImGui.Unindent(indent_w) end

--- Lock horizontal starting position. Must be paired with EndGroup().
function ImGui.BeginGroup() end

--- Unlock horizontal starting position + capture the whole group bounding box.
function ImGui.EndGroup() end

--- Vertically align upcoming text baseline to FramePadding.y.
function ImGui.AlignTextToFramePadding() end

--- Add an invisible item of given size for layout purposes.
---@param sx number Width
---@param sy number Height
function ImGui.Dummy(sx, sy) end

--- Get height of a line of text.
---@return number
function ImGui.GetTextLineHeight() end

--- Get height of a line of text plus spacing.
---@return number
function ImGui.GetTextLineHeightWithSpacing() end

--- Set cursor position (local to window).
---@param x number
---@param y number
function ImGui.SetCursorPos(x, y) end

--- Set cursor X position (local to window).
---@param x number
function ImGui.SetCursorPosX(x) end

--- Set cursor Y position (local to window).
---@param y number
function ImGui.SetCursorPosY(y) end

--- Get cursor position (local to window).
---@return number x
---@return number y
function ImGui.GetCursorPos() end

---@return number
function ImGui.GetCursorPosX() end

---@return number
function ImGui.GetCursorPosY() end

--- Get cursor position in screen coordinates.
---@return number x
---@return number y
function ImGui.GetCursorScreenPos() end

--- Set cursor position in screen coordinates.
---@param x number
---@param y number
function ImGui.SetCursorScreenPos(x, y) end

--- Get available content region size.
---@return number width
---@return number height
function ImGui.GetContentRegionAvail() end

-- ============================================================================
-- Buttons & Basic Widgets
-- ============================================================================

--- A clickable button. Returns true when clicked.
---@param label string Button text
---@param sx? number Width (default 0 = auto)
---@param sy? number Height (default 0 = auto)
---@return boolean clicked
function ImGui.Button(label, sx, sy) end

--- A small button that fits within text flow.
---@param label string
---@return boolean clicked
function ImGui.SmallButton(label) end

--- A button without visible frame. Useful for custom hit regions.
---@param id string Widget ID
---@param sx number Width
---@param sy number Height
---@param flags? number ImGuiButtonFlags (default 0)
---@return boolean clicked
function ImGui.InvisibleButton(id, sx, sy, flags) end

--- A button with an arrow glyph.
---@param id string Widget ID
---@param dir number ImGuiDir (0=Left, 1=Right, 2=Up, 3=Down)
---@return boolean clicked
function ImGui.ArrowButton(id, dir) end

--- A checkbox. Returns (changed, newValue).
---@param label string
---@param value boolean Current value
---@return boolean changed Whether the value changed this frame
---@return boolean value The new value
function ImGui.Checkbox(label, value) end

--- A radio button group helper. Returns (changed, newValue).
---@param label string
---@param value number Current selected value
---@param v_button number The value this button represents
---@return boolean changed
---@return number value
function ImGui.RadioButton(label, value, v_button) end

--- Display a progress bar.
---@param fraction number Progress value (0.0 to 1.0)
---@param sx? number Width (default -FLT_MIN = fill available)
---@param sy? number Height (default 0 = auto)
---@param overlay? string Optional overlay text
function ImGui.ProgressBar(fraction, sx, sy, overlay) end

--- Draw a small circle (bullet point).
function ImGui.Bullet() end

-- ============================================================================
-- Input Widgets
-- ============================================================================

--- Single-line text input. Returns (changed, newText).
---@param label string
---@param text string Current text value
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return string text The new text value
function ImGui.InputText(label, text, flags) end

--- Multi-line text input. Returns (changed, newText).
---@param label string
---@param text string Current text value
---@param sx? number Width (default 0)
---@param sy? number Height (default 0)
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return string text
function ImGui.InputTextMultiline(label, text, sx, sy, flags) end

--- Single-line text input with a hint/placeholder. Returns (changed, newText).
---@param label string
---@param hint string Placeholder text shown when empty
---@param text string Current text value
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return string text
function ImGui.InputTextWithHint(label, hint, text, flags) end

--- Integer input. Returns (changed, newValue).
---@param label string
---@param value number Current value
---@param step? number Step amount (default 1)
---@param step_fast? number Fast step amount (default 100)
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.InputInt(label, value, step, step_fast, flags) end

--- Float input. Returns (changed, newValue).
---@param label string
---@param value number Current value
---@param step? number Step amount (default 0)
---@param step_fast? number Fast step amount (default 0)
---@param format? string Display format (default "%.3f")
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.InputFloat(label, value, step, step_fast, format, flags) end

--- Double input. Returns (changed, newValue).
---@param label string
---@param value number Current value
---@param step? number Step amount (default 0)
---@param step_fast? number Fast step amount (default 0)
---@param format? string Display format (default "%.6f")
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.InputDouble(label, value, step, step_fast, format, flags) end

--- Float2 input (table of 2 floats). Returns (changed, newTable).
---@param label string
---@param values table Table with 2 float values {v1, v2}
---@param format? string Display format (default "%.3f")
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return table values
function ImGui.InputFloat2(label, values, format, flags) end

--- Int2 input (table of 2 ints). Returns (changed, newTable).
---@param label string
---@param values table Table with 2 int values {v1, v2}
---@param flags? number ImGuiInputTextFlags (default 0)
---@return boolean changed
---@return table values
function ImGui.InputInt2(label, values, flags) end

-- ============================================================================
-- Drag Widgets
-- ============================================================================

--- Drag integer input. Click and drag to change value. Returns (changed, newValue).
---@param label string
---@param value number Current value
---@param speed? number Drag speed (default 1.0)
---@param min? number Minimum value (default 0)
---@param max? number Maximum value (default 0)
---@param format? string Display format (default "%d")
---@param flags? number ImGuiSliderFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.DragInt(label, value, speed, min, max, format, flags) end

--- Drag float input. Click and drag to change value. Returns (changed, newValue).
---@param label string
---@param value number Current value
---@param speed? number Drag speed (default 1.0)
---@param min? number Minimum value (default 0)
---@param max? number Maximum value (default 0)
---@param format? string Display format (default "%.3f")
---@param flags? number ImGuiSliderFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.DragFloat(label, value, speed, min, max, format, flags) end

-- ============================================================================
-- Slider Widgets
-- ============================================================================

--- Integer slider. Returns (changed, newValue).
---@param label string
---@param value number Current value
---@param min number Minimum value
---@param max number Maximum value
---@param format? string Display format (default "%d")
---@param flags? number ImGuiSliderFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.SliderInt(label, value, min, max, format, flags) end

--- Float slider. Returns (changed, newValue).
---@param label string
---@param value number Current value
---@param min number Minimum value
---@param max number Maximum value
---@param format? string Display format (default "%.3f")
---@param flags? number ImGuiSliderFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.SliderFloat(label, value, min, max, format, flags) end

--- Angle slider (value in radians, displayed in degrees). Returns (changed, newValue).
---@param label string
---@param v_rad number Current value in radians
---@param min_deg? number Min degrees (default -360)
---@param max_deg? number Max degrees (default +360)
---@param format? string Display format (default "%.0f deg")
---@param flags? number ImGuiSliderFlags (default 0)
---@return boolean changed
---@return number v_rad
function ImGui.SliderAngle(label, v_rad, min_deg, max_deg, format, flags) end

--- Vertical integer slider. Returns (changed, newValue).
---@param label string
---@param sx number Width
---@param sy number Height
---@param value number Current value
---@param min number Minimum
---@param max number Maximum
---@param format? string Display format (default "%d")
---@param flags? number ImGuiSliderFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.VSliderInt(label, sx, sy, value, min, max, format, flags) end

--- Vertical float slider. Returns (changed, newValue).
---@param label string
---@param sx number Width
---@param sy number Height
---@param value number Current value
---@param min number Minimum
---@param max number Maximum
---@param format? string Display format (default "%.3f")
---@param flags? number ImGuiSliderFlags (default 0)
---@return boolean changed
---@return number value
function ImGui.VSliderFloat(label, sx, sy, value, min, max, format, flags) end

-- ============================================================================
-- Color Widgets
-- ============================================================================

--- RGB color editor. Returns (changed, r, g, b).
---@param label string
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param flags? number ImGuiColorEditFlags (default 0)
---@return boolean changed
---@return number r
---@return number g
---@return number b
function ImGui.ColorEdit3(label, r, g, b, flags) end

--- RGBA color editor. Returns (changed, r, g, b, a).
---@param label string
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number Alpha (0-1)
---@param flags? number ImGuiColorEditFlags (default 0)
---@return boolean changed
---@return number r
---@return number g
---@return number b
---@return number a
function ImGui.ColorEdit4(label, r, g, b, a, flags) end

--- RGB color picker. Returns (changed, r, g, b).
---@param label string
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param flags? number ImGuiColorEditFlags (default 0)
---@return boolean changed
---@return number r
---@return number g
---@return number b
function ImGui.ColorPicker3(label, r, g, b, flags) end

--- RGBA color picker. Returns (changed, r, g, b, a).
---@param label string
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number Alpha (0-1)
---@param flags? number ImGuiColorEditFlags (default 0)
---@return boolean changed
---@return number r
---@return number g
---@return number b
---@return number a
function ImGui.ColorPicker4(label, r, g, b, a, flags) end

--- Display a color square button. Returns true when clicked.
---@param desc_id string Widget ID
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number Alpha (0-1)
---@param flags? number ImGuiColorEditFlags (default 0)
---@param sx? number Width (default 0)
---@param sy? number Height (default 0)
---@return boolean clicked
function ImGui.ColorButton(desc_id, r, g, b, a, flags, sx, sy) end

-- ============================================================================
-- Combo / Selection
-- ============================================================================

--- Begin a combo box (manual item submission). Must be paired with EndCombo() when returns true.
---@param label string
---@param preview string Preview text shown when combo is closed
---@param flags? number ImGuiComboFlags (default 0)
---@return boolean open True if the combo popup is open
function ImGui.BeginCombo(label, preview, flags) end

--- End a combo box. Only call if BeginCombo() returned true.
function ImGui.EndCombo() end

--- Simple combo box from a Lua table of strings. Returns (changed, newIndex).
--- Note: index is 0-based to match C++ ImGui convention.
---@param label string
---@param current number Current selected index (0-based)
---@param items table Array of string items
---@param max_height? number Max popup height in items (default -1 = use default)
---@return boolean changed
---@return number current The new selected index
function ImGui.Combo(label, current, items, max_height) end

--- Begin a list box. Must be paired with EndListBox() when returns true.
---@param label string
---@param sx? number Width (default 0)
---@param sy? number Height (default 0)
---@return boolean open
function ImGui.BeginListBox(label, sx, sy) end

--- End a list box. Only call if BeginListBox() returned true.
function ImGui.EndListBox() end

--- A selectable item. Returns true when clicked.
---@param label string
---@param selected? boolean Current selection state (default false)
---@param flags? number ImGuiSelectableFlags (default 0)
---@param sx? number Width (default 0)
---@param sy? number Height (default 0)
---@return boolean clicked
function ImGui.Selectable(label, selected, flags, sx, sy) end

-- ============================================================================
-- Trees
-- ============================================================================

--- Begin a tree node. Returns true if open. Must call TreePop() if true.
---@param label string
---@return boolean open
function ImGui.TreeNode(label) end

--- Begin a tree node with flags. Returns true if open. Must call TreePop() if true.
---@param label string
---@param flags? number ImGuiTreeNodeFlags (default 0)
---@return boolean open
function ImGui.TreeNodeEx(label, flags) end

--- Pop the current tree node. Only call if TreeNode/TreeNodeEx returned true.
function ImGui.TreePop() end

--- A collapsing header. Returns true when open.
---@param label string
---@param flags? number ImGuiTreeNodeFlags (default 0)
---@return boolean open
---@return boolean visible
function ImGui.CollapsingHeader(label, flags) end

--- A closable collapsing header. Returns (visible, open).
---@param label string
---@param open boolean Current open state
---@param flags? number ImGuiTreeNodeFlags (default 0)
---@return boolean visible Whether the header content is visible
---@return boolean open Whether the header is still open
function ImGui.CollapsingHeader(label, open, flags) end

--- Set next TreeNode/CollapsingHeader open state.
---@param is_open boolean
---@param cond? number ImGuiCond (default 0)
function ImGui.SetNextItemOpen(is_open, cond) end

-- ============================================================================
-- Tabs
-- ============================================================================

--- Begin a tab bar. Must be paired with EndTabBar().
---@param id string Tab bar ID
---@param flags? number ImGuiTabBarFlags (default 0)
---@return boolean open
function ImGui.BeginTabBar(id, flags) end

--- End a tab bar. Only call if BeginTabBar() returned true.
function ImGui.EndTabBar() end

--- Begin a tab item. Must be paired with EndTabItem() when returns true.
---@param label string Tab label
---@param open? boolean Whether the tab has a close button (nil = no close button)
---@param flags? number ImGuiTabItemFlags (default 0)
---@return boolean selected Whether this tab is currently selected
---@return boolean open Whether the tab is still open (relevant if close button shown)
function ImGui.BeginTabItem(label, open, flags) end

--- End a tab item. Only call if BeginTabItem() returned true.
function ImGui.EndTabItem() end

-- ============================================================================
-- Tables
-- ============================================================================

--- Begin a table. Must be paired with EndTable() when returns true.
---@param id string Table ID
---@param columns number Number of columns
---@param flags? number ImGuiTableFlags (default 0)
---@param outer_sx? number Outer width (default 0)
---@param outer_sy? number Outer height (default 0)
---@param inner_width? number Inner width (default 0)
---@return boolean open
function ImGui.BeginTable(id, columns, flags, outer_sx, outer_sy, inner_width) end

--- End a table. Only call if BeginTable() returned true.
function ImGui.EndTable() end

--- Advance to next row in a table.
---@param flags? number ImGuiTableRowFlags (default 0)
---@param min_row_height? number (default 0)
function ImGui.TableNextRow(flags, min_row_height) end

--- Advance to next column. Returns true if column is visible.
---@return boolean visible
function ImGui.TableNextColumn() end

--- Set current column index.
---@param column_index number
---@return boolean visible
function ImGui.TableSetColumnIndex(column_index) end

--- Setup a column (call between BeginTable and first row).
---@param label string Column header label
---@param flags? number ImGuiTableColumnFlags (default 0)
---@param init_width? number Initial width (default 0)
---@param user_id? number User ID (default 0)
function ImGui.TableSetupColumn(label, flags, init_width, user_id) end

--- Submit all column headers row. Usually called after all TableSetupColumn() calls.
function ImGui.TableHeadersRow() end

--- Get number of columns in current table.
---@return number
function ImGui.TableGetColumnCount() end

-- ============================================================================
-- Menus
-- ============================================================================

--- Begin a menu bar inside the current window. Must be paired with EndMenuBar().
--- Window must have ImGuiWindowFlags.MenuBar flag.
---@return boolean open
function ImGui.BeginMenuBar() end

--- End a menu bar.
function ImGui.EndMenuBar() end

--- Begin a full-screen menu bar. Must be paired with EndMainMenuBar().
---@return boolean open
function ImGui.BeginMainMenuBar() end

--- End the main menu bar.
function ImGui.EndMainMenuBar() end

--- Begin a sub-menu. Must be paired with EndMenu() when returns true.
---@param label string Menu label
---@param enabled? boolean Whether the menu is enabled (default true)
---@return boolean open
function ImGui.BeginMenu(label, enabled) end

--- End a sub-menu.
function ImGui.EndMenu() end

--- A menu item. Returns true when activated.
---@param label string
---@param shortcut? string Shortcut text displayed on the right
---@param selected? boolean Whether item shows a checkmark (default false)
---@param enabled? boolean Whether item is enabled (default true)
---@return boolean activated
function ImGui.MenuItem(label, shortcut, selected, enabled) end

-- ============================================================================
-- Popups
-- ============================================================================

--- Open a popup by string ID (call in response to user action).
---@param id string Popup ID
---@param flags? number ImGuiPopupFlags (default 0)
function ImGui.OpenPopup(id, flags) end

--- Begin a popup. Must be paired with EndPopup() when returns true.
---@param id string Popup ID
---@param flags? number ImGuiWindowFlags (default 0)
---@return boolean open
function ImGui.BeginPopup(id, flags) end

--- Begin a modal popup (blocks interaction with background). Must be paired with EndPopup().
---@param name string Popup name/ID
---@param flags? number ImGuiWindowFlags (default 0)
---@return boolean open
function ImGui.BeginPopupModal(name, flags) end

--- End a popup. Only call if BeginPopup/BeginPopupModal returned true.
function ImGui.EndPopup() end

--- Open popup on right-click of the last item. Must be paired with EndPopup().
---@param id? string Override popup ID
---@param flags? number ImGuiPopupFlags (default 1 = right click)
---@return boolean open
function ImGui.BeginPopupContextItem(id, flags) end

--- Open popup on right-click of the current window. Must be paired with EndPopup().
---@param id? string Override popup ID
---@param flags? number ImGuiPopupFlags (default 1 = right click)
---@return boolean open
function ImGui.BeginPopupContextWindow(id, flags) end

--- Close the current popup.
function ImGui.CloseCurrentPopup() end

--- Check if a popup is open.
---@param id string Popup ID
---@param flags? number ImGuiPopupFlags (default 0)
---@return boolean open
function ImGui.IsPopupOpen(id, flags) end

-- ============================================================================
-- Tooltips
-- ============================================================================

--- Set a text tooltip for the preceding item (shortcut for BeginTooltip+Text+EndTooltip).
---@param text string
function ImGui.SetTooltip(text) end

--- Begin a tooltip. Must be paired with EndTooltip().
---@return boolean
function ImGui.BeginTooltip() end

--- End a tooltip.
function ImGui.EndTooltip() end

-- ============================================================================
-- Item Status / Queries
-- ============================================================================

--- Is the last item hovered?
---@param flags? number ImGuiHoveredFlags (default 0)
---@return boolean
function ImGui.IsItemHovered(flags) end

--- Is the last item active (being clicked/held)?
---@return boolean
function ImGui.IsItemActive() end

--- Is the last item focused (for keyboard/gamepad nav)?
---@return boolean
function ImGui.IsItemFocused() end

--- Was the last item clicked?
---@param button? number ImGuiMouseButton (default 0 = left)
---@return boolean
function ImGui.IsItemClicked(button) end

--- Is the last item visible (not clipped)?
---@return boolean
function ImGui.IsItemVisible() end

--- Was the last item value edited this frame?
---@return boolean
function ImGui.IsItemEdited() end

--- Was the last item just made active?
---@return boolean
function ImGui.IsItemActivated() end

--- Was the last item just made inactive?
---@return boolean
function ImGui.IsItemDeactivated() end

--- Was the last item just made inactive and had its value changed?
---@return boolean
function ImGui.IsItemDeactivatedAfterEdit() end

--- Get bounding rect min of the last item (screen space).
---@return number x
---@return number y
function ImGui.GetItemRectMin() end

--- Get bounding rect max of the last item (screen space).
---@return number x
---@return number y
function ImGui.GetItemRectMax() end

--- Get size of the last item.
---@return number width
---@return number height
function ImGui.GetItemRectSize() end

--- Make last item the default focused item in a window.
function ImGui.SetItemDefaultFocus() end

-- ============================================================================
-- Style
-- ============================================================================

--- Push a color style override. Must be paired with PopStyleColor().
---@param idx number ImGuiCol enum value
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number Alpha (0-1)
function ImGui.PushStyleColor(idx, r, g, b, a) end

--- Pop color style overrides.
---@param count? number Number to pop (default 1)
function ImGui.PopStyleColor(count) end

--- Push a float style variable override. Must be paired with PopStyleVar().
--- Also supports ImVec2 style vars: ImGui.PushStyleVar(idx, x, y)
---@param idx number ImGuiStyleVar enum value
---@param val number Float value (or x for ImVec2 vars)
---@param y? number Y value (for ImVec2 style vars)
function ImGui.PushStyleVar(idx, val, y) end

--- Pop style variable overrides.
---@param count? number Number to pop (default 1)
function ImGui.PopStyleVar(count) end

--- Set width of upcoming items. -1 = use default, >0 = fixed width, <0 = align to right edge.
---@param width number
function ImGui.PushItemWidth(width) end

--- Reset item width to default.
function ImGui.PopItemWidth() end

-- ============================================================================
-- Mouse / Input Queries
-- ============================================================================

--- Is the mouse button currently held down?
---@param button number ImGuiMouseButton (0=left, 1=right, 2=middle)
---@return boolean
function ImGui.IsMouseDown(button) end

--- Was the mouse button clicked this frame?
---@param button number ImGuiMouseButton
---@param repeat_? boolean Allow repeated clicks when held (default false)
---@return boolean
function ImGui.IsMouseClicked(button, repeat_) end

--- Was the mouse button double-clicked this frame?
---@param button number ImGuiMouseButton
---@return boolean
function ImGui.IsMouseDoubleClicked(button) end

--- Was the mouse button released this frame?
---@param button number ImGuiMouseButton
---@return boolean
function ImGui.IsMouseReleased(button) end

--- Is the mouse being dragged?
---@param button number ImGuiMouseButton
---@param lock_threshold? number Distance threshold (default -1 = use io default)
---@return boolean
function ImGui.IsMouseDragging(button, lock_threshold) end

--- Get current mouse position.
---@return number x
---@return number y
function ImGui.GetMousePos() end

--- Get mouse drag delta since clicking.
---@param button? number ImGuiMouseButton (default 0)
---@param lock_threshold? number (default -1)
---@return number dx
---@return number dy
function ImGui.GetMouseDragDelta(button, lock_threshold) end

--- Reset the mouse drag delta.
---@param button? number ImGuiMouseButton (default 0)
function ImGui.ResetMouseDragDelta(button) end

--- Is the key currently held down?
---@param key number ImGuiKey value
---@return boolean
function ImGui.IsKeyDown(key) end

--- Was the key pressed this frame?
---@param key number ImGuiKey value
---@param repeat_? boolean Allow repeated presses when held (default true)
---@return boolean
function ImGui.IsKeyPressed(key, repeat_) end

--- Was the key released this frame?
---@param key number ImGuiKey value
---@return boolean
function ImGui.IsKeyReleased(key) end

-- ============================================================================
-- Scroll
-- ============================================================================

--- Get horizontal scroll position.
---@return number
function ImGui.GetScrollX() end

--- Get vertical scroll position.
---@return number
function ImGui.GetScrollY() end

--- Set horizontal scroll position.
---@param scroll_x number
function ImGui.SetScrollX(scroll_x) end

--- Set vertical scroll position.
---@param scroll_y number
function ImGui.SetScrollY(scroll_y) end

--- Get maximum horizontal scroll.
---@return number
function ImGui.GetScrollMaxX() end

--- Get maximum vertical scroll.
---@return number
function ImGui.GetScrollMaxY() end

--- Adjust horizontal scroll to make current cursor position visible.
---@param center_ratio? number (default 0.5)
function ImGui.SetScrollHereX(center_ratio) end

--- Adjust vertical scroll to make current cursor position visible.
---@param center_ratio? number (default 0.5)
function ImGui.SetScrollHereY(center_ratio) end

-- ============================================================================
-- Columns (legacy API, prefer Tables)
-- ============================================================================

--- Set up columns layout (legacy). Prefer using BeginTable/EndTable instead.
---@param count? number Number of columns (default 1 = end columns)
---@param id? string Columns ID
---@param border? boolean Show column borders (default true)
function ImGui.Columns(count, id, border) end

--- Next column in legacy column layout.
function ImGui.NextColumn() end

--- Get current column index (legacy columns).
---@return number
function ImGui.GetColumnIndex() end

--- Get column width (legacy columns).
---@param column_index? number (default -1 = current)
---@return number
function ImGui.GetColumnWidth(column_index) end

--- Set column width (legacy columns).
---@param column_index number
---@param width number
function ImGui.SetColumnWidth(column_index, width) end

--- Get column offset (legacy columns).
---@param column_index? number (default -1 = current)
---@return number
function ImGui.GetColumnOffset(column_index) end

--- Get number of columns (legacy columns).
---@return number
function ImGui.GetColumnsCount() end

-- ============================================================================
-- Plots
-- ============================================================================

--- Draw a line plot from a Lua table of floats.
---@param label string
---@param values table Array of float values
---@param offset? number Starting index offset (default 0)
---@param overlay? string Overlay text
---@param scale_min? number Y-axis min (default FLT_MAX = auto)
---@param scale_max? number Y-axis max (default FLT_MAX = auto)
---@param sx? number Graph width (default 0 = fill)
---@param sy? number Graph height (default 0 = auto)
function ImGui.PlotLines(label, values, offset, overlay, scale_min, scale_max, sx, sy) end

--- Draw a histogram from a Lua table of floats.
---@param label string
---@param values table Array of float values
---@param offset? number Starting index offset (default 0)
---@param overlay? string Overlay text
---@param scale_min? number Y-axis min (default FLT_MAX = auto)
---@param scale_max? number Y-axis max (default FLT_MAX = auto)
---@param sx? number Graph width (default 0 = fill)
---@param sy? number Graph height (default 0 = auto)
function ImGui.PlotHistogram(label, values, offset, overlay, scale_min, scale_max, sx, sy) end

-- ============================================================================
-- ID Stack
-- ============================================================================

--- Push a string ID onto the ID stack. Must be paired with PopID().
--- Useful to differentiate widgets with the same label.
---@param id string|number String or integer ID
function ImGui.PushID(id) end

--- Pop the ID stack.
function ImGui.PopID() end

-- ============================================================================
-- Utility
-- ============================================================================

--- Calculate text size in pixels.
---@param text string
---@param hide_after_double_hash? boolean (default false)
---@param wrap_width? number (default -1 = no wrap)
---@return number width
---@return number height
function ImGui.CalcTextSize(text, hide_after_double_hash, wrap_width) end

--- Get current frame height (font size + frame padding).
---@return number
function ImGui.GetFrameHeight() end

--- Get current frame height including spacing.
---@return number
function ImGui.GetFrameHeightWithSpacing() end

end -- if false (LuaDoc stubs)

-- ============================================================================
-- ImGui Enum Constants
-- ============================================================================
-- All enums are available as global tables. Use bitwise OR (|) to combine flags.
-- Examples:
--   ImGui.Begin("My Window", ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize)
--   ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
--
-- Available enum tables:
--   ImGuiWindowFlags      - Window behavior flags (NoTitleBar, NoResize, NoMove, etc.)
--   ImGuiInputTextFlags   - Text input flags (CharsDecimal, ReadOnly, Password, etc.)
--   ImGuiTreeNodeFlags    - Tree node flags (Selected, DefaultOpen, Leaf, Bullet, etc.)
--   ImGuiSelectableFlags  - Selectable flags (SpanAllColumns, AllowDoubleClick, Disabled)
--   ImGuiComboFlags       - Combo box flags (HeightSmall, HeightLarge, NoArrowButton, etc.)
--   ImGuiTabBarFlags      - Tab bar flags (Reorderable, AutoSelectNewTabs, etc.)
--   ImGuiTabItemFlags     - Tab item flags (UnsavedDocument, SetSelected, Leading, etc.)
--   ImGuiTableFlags       - Table flags (Resizable, Borders, RowBg, ScrollX, ScrollY, etc.)
--   ImGuiTableColumnFlags - Table column flags (WidthStretch, WidthFixed, NoSort, etc.)
--   ImGuiColorEditFlags   - Color edit flags (NoAlpha, NoPicker, HDR, Float, etc.)
--   ImGuiSliderFlags      - Slider/Drag flags (Logarithmic, NoInput, AlwaysClamp, etc.)
--   ImGuiPopupFlags       - Popup flags (MouseButtonRight, NoReopen, AnyPopup, etc.)
--   ImGuiCol              - Color indices for PushStyleColor (Text, WindowBg, Button, etc.)
--   ImGuiStyleVar         - Style variable indices for PushStyleVar (Alpha, FramePadding, etc.)
--   ImGuiDir              - Directions (None, Left, Right, Up, Down)
--   ImGuiCond             - Conditions (Always, Once, FirstUseEver, Appearing)
--   ImGuiMouseButton      - Mouse buttons (Left, Right, Middle)

---@class Bank
Bank = Bank

--- Returns true if bank is open, false otherwise
---@return boolean
function Bank:IsOpen() end

--- Returns true if the PIN interface is currently open, false otherwise. Can return a false positive is collection box is open
---@return boolean
function Bank:IsPINOpen() end

--- Enters the provided 4-digit PIN into the bank's PIN entry interface
---@param digit1 number
---@param digit2 number
---@param digit3 number
---@param digit4 number
---@return boolean
function Bank:EnterPIN(digit1, digit2, digit3, digit4) end

--- Checks if bank contains ALL of the requested item(s)
---@param ItemID number|table Single item ID or table of item IDs
---@return boolean
function Bank:Contains(ItemID) end

--- Checks if bank contains ANY of the requested item(s)
---@param ItemID number|table Single item ID or table of item IDs
---@return boolean
function Bank:ContainsAny(ItemID) end

--- Get the total amount of the requested item in the bank
---@param ItemID number Item ID to count
---@return number
function Bank:GetItemAmount(ItemID) end

--- Checks if the bank is currently set to note withdrawal mode
---@return boolean
function Bank:IsNoteModeEnabled() end

--- Sets the bank withdrawal mode to noted or unnoted
---@param enabled boolean True to enable note mode, false to disable
---@return boolean
function Bank:SetNoteMode(enabled) end

--- Withdraws a specific amount of item(s) from the bank
---@param ItemID number|table Single item ID or table of item IDs
---@param amount number Amount to withdraw
---@return boolean
function Bank:Withdraw(ItemID, amount) end

--- Withdraws all of the requested item(s) from the bank
---@param ItemID number|table Single item ID or table of item IDs
---@return boolean
function Bank:WithdrawAll(ItemID) end

--- Withdraws item(s) from the bank to your Beast of Burden
---@param ItemID number|table Single item ID or table of item IDs
---@param amount number Amount to withdraw
---@return boolean
function Bank:WithdrawToBoB(ItemID, amount) end

--- Withdraws all of the requested item(s) from the bank to your Beast of Burden
---@param ItemID number|table Single item ID or table of item IDs
---@return boolean
function Bank:WithdrawAllToBoB(ItemID) end

--- Deposits a specific amount of item(s) to the bank
---@param ItemID number|table Single item ID or table of item IDs
---@param amount number Amount to deposit
---@return boolean
function Bank:Deposit(ItemID, amount) end

--- Deposits all of the requested item(s) to the bank
---@param ItemID number|table Single item ID or table of item IDs
---@return boolean
function Bank:DepositAll(ItemID) end

--- Deposits your entire inventory into the bank
---@return boolean
function Bank:DepositInventory() end

--- Deposits all equipped items into the bank
---@return boolean
function Bank:DepositEquipment() end

--- Deposits your Beast of Burden's inventory into the bank
---@return boolean
function Bank:DepositSummon() end

--- Deposits your money pouch into MY bank
---@return boolean
function Bank:DepositMoneyPouch() end

--- Equips a specific amount of item(s) directly from the bank
---@param ItemID number|table Single item ID or table of item IDs
---@param amount number Amount to equip
---@return boolean
function Bank:Equip(ItemID, amount) end

--- Equips all of the requested item(s) directly from the bank
---@param ItemID number|table Single item ID or table of item IDs
---@return boolean
function Bank:EquipAll(ItemID) end

--- Saves the current inventory setup to the specified preset slot
---@param presetNumber number Preset slot to save to (1-18)
---@return boolean
function Bank:SavePreset(presetNumber) end

--- Loads the specified preset
---@param presetNumber number Preset slot to load (1-18)
---@return boolean
function Bank:LoadPreset(presetNumber) end

--- Saves the current Beast of Burden preset
---@return boolean
function Bank:SaveSummonPreset() end

--- Loads the Beast of Burden preset
---@return boolean
function Bank:LoadSummonPreset() end

--- Deposits logs from wood boxes in your inventory into the bank
---@return boolean
function Bank:WoodBoxDepositLogs() end

--- Deposits wood spirits from wood boxes in your inventory into the bank
---@return boolean
function Bank:WoodBoxDepositWoodSpirits() end

--- Deposits ores from ore boxes in your inventory into the bank
---@return boolean
function Bank:OreBoxDepositOres() end

--- Deposits stone spirits from ore boxes in your inventory into the bank
---@return boolean
function Bank:OreBoxDepositStoneSpirits() end

--- Deposits soil from a soil box in your inventory into the bank
---@return boolean
function Bank:SoilBoxDepositSoil() end

--- Returns true if the Deposit Box interface is currently open, false otherwise
---@return boolean
function Bank:DepositBoxIsOpen() end

--- Deposits your entire inventory into a deposit box
---@return boolean
function Bank:DepositBoxDepositInventory() end

--- Deposits all equipped items into a deposit box
---@return boolean
function Bank:DepositBoxDepositEquipment() end

--- Deposits your Beast of Burden's inventory into a deposit box
---@return boolean
function Bank:DepositBoxDepositSummon() end

--- Deposits your money pouch into MY deposit box
---@return boolean
function Bank:DepositBoxDepositMoneyPouch() end

--- Deposits a specific amount of item(s) into a deposit box
---@param ItemID number|table Single item ID or table of item IDs
---@param amount number Amount to deposit (1, 5, or 10)
---@return boolean
function Bank:DepositBoxDeposit(ItemID, amount) end

--- Deposits all of the requested item(s) into a deposit box
---@param ItemID number|table Single item ID or table of item IDs
---@return boolean
function Bank:DepositBoxDepositAll(ItemID) end

--- Returns true if the Collection Box interface is currently open, false otherwise. Can return a false positive if the PIN interface is open
---@return boolean
function Bank:CollectionBoxIsOpen() end

--- Checks if there are any items to collect in the collection box
---@return boolean
function Bank:CollectionBoxHasItems() end

--- Checks if a specific item is available to collect in the collection box
---@param itemId number Item ID to search for
---@return boolean
function Bank:CollectionBoxContains(itemId) end

--- Collects all items from the collection box to your inventory
---@return boolean
function Bank:CollectionBoxCollectToInventory() end

--- Collects all items from the collection box to your bank
---@return boolean
function Bank:CollectionBoxCollectToBank() end

--- World hopping utility
---@class WorldHop
WorldHop = WorldHop

--- Hops to a world. If worldNum is 0 or omitted, hops to a random valid world.
--- Works in both Lobby and In-Game.
---@param worldNum? number Optional world number
---@return boolean
function WorldHop:Hop(worldNum) end

--- Opens the world switcher interface.
--- Works in both Lobby and In-Game.
---@return boolean
function WorldHop:Open() end

--- Returns true if the world switcher interface is currently open.
---@return boolean
function WorldHop:IsOpen() end

--- Returns the current world number.
---@return number
function WorldHop:GetCurrentWorld() end

--- Returns a random valid world number.
---@param membersOnly? boolean Optional, defaults to true
---@return number
function WorldHop:GetRandomWorld(membersOnly) end

return API