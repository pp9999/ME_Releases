-- afk_gui.lua
-- AFK fisher with a native RS3 plugin-style UI panel.
--
-- The panel is not a plugin. It is built inside the client plugin Lua state
-- through GamePlugin.Exec and uses the same ui.* components that official
-- plugins use. The MemoryError Lua thread only pushes text/numbers into it.

--[==[
===============================================================================
 GAMEPLUGIN / CLIENT PLUGIN API EXAMPLES
===============================================================================
This script runs in MemoryError's Lua state. The client plugin API lives in the
game process and is reached through the GamePlugin bridge.

Rules:
  * Do not call ui.*, Player, NPCList, Event, config, id, var, etc. directly
    from this script. Those globals exist only in the client plugin Lua VM.
  * Use GamePlugin.Exec / Eval / GetJson to run client-side code.
  * Use GamePlugin.CallExe for simple client functions that do not need
    client userdata.
  * Use GamePlugin.Exec for UI creation and callbacks. Keep created objects in
    a global table inside the client VM so Lua does not garbage collect them.
  * Event callbacks must be created inside the client VM. A Lua function from
    this script cannot be passed through CallExe.
  * GamePlugin.Exec is queued to the game thread and can wait up to 5 seconds.
  * The bridge functions are saved before require("api") and restored after it,
    because older api.lua versions defined empty GamePlugin stubs.

-------------------------------------------------------------------------------
 0. BRIDGE AVAILABILITY
-------------------------------------------------------------------------------
if GamePlugin and GamePlugin.IsAvailable() then
    local state = GamePlugin.GetLuaState()
    print("client plugin Lua state:", state)
end

-------------------------------------------------------------------------------
 1. CALLING CLIENT FUNCTIONS
-------------------------------------------------------------------------------
local level = GamePlugin.CallExe("Player.GetCombatLevel")

local entity = GamePlugin.Player.GetEntity()
if entity then
    print(entity.coordGrid.x, entity.coordGrid.z, entity.displayName)
end

-- Raw string form. Returns "OK|<value>" or "ERR|<error>".
local raw = GamePlugin.Call("World.IsMembers")
if type(raw) == "string" and raw:sub(1, 3) == "OK|" then
    print(raw:sub(4))
end

-- Typed expression form. Returns the first return value as a Lua value.
local members = GamePlugin.CallTyped("World.IsMembers")

-- JSON form for expressions that return tables or client userdata.
local json = GamePlugin.GetJson("Player.GetEntity().coordGrid")
print(json)

-------------------------------------------------------------------------------
 2. READING GAME DATA
-------------------------------------------------------------------------------
-- Player:
local combat = GamePlugin.Player.GetCombatLevel()
local runEnergy = GamePlugin.Player.GetRunEnergy()
local weight = GamePlugin.Player.GetWeight()
local playerEntity = GamePlugin.Player.GetEntity()

-- Nearby NPCs:
for _, npc in ipairs(GamePlugin.NPCList.All()) do
    print(npc.uid, npc.displayName, npc.coordGrid.x, npc.coordGrid.z)
end

-- Filtered lists:
local goblins = GamePlugin.NPCList.ByName("Goblin")
local nearbyNpcs = GamePlugin.NPCList.ByDistance(10)

-- Objects:
for _, loc in ipairs(GamePlugin.LocList.ByDistance(10)) do
    print(loc.uid, loc.name, loc.coordGrid.x, loc.coordGrid.z)
end

-- Ground items:
for _, item in ipairs(GamePlugin.ObjStackList.All()) do
    print(item.uid, item.item and item.item.name, item.itemCount)
end

-- Inventory. Find() takes an inventory type such as id.Inv.INV.
-- Methods on the returned object need GetJson or Exec.
local backpack = GamePlugin.Inventory.Find(GamePlugin.id.Inv.INV)
local inventoryJson = GamePlugin.GetJson("Inventory.Find(id.Inv.INV):GetSlots()")

-- Grand Exchange:
local slots = GamePlugin.GrandExchange.MaxOffers()
local offer = GamePlugin.GrandExchange.GetOffer(1)
if offer then
    print(offer.item.name, offer.price, offer.itemCount, offer.soldCount)
end

-- World:
local isMembers = GamePlugin.World.IsMembers()
local ping = GamePlugin.World.GetPing()
local ground = GamePlugin.World.GetGroundHeight(0, 3200, 3200, 0)

-- Config and id providers:
local headbar = GamePlugin.config.Headbar.FromID(7)
local adrenaline = GamePlugin.config.Headbar.ADRENALINE_DEFAULT
local magicHitmark = GamePlugin.id.Hitmark.MAGIC_DAMAGE

-- Keyboard and mouse:
local shift = GamePlugin.Keyboard.IsShiftDown()
local mx = GamePlugin.Mouse.GetX()
local my = GamePlugin.Mouse.GetY()

-- Chat:
GamePlugin.Chat.AddMessage("Hello from the script")

-------------------------------------------------------------------------------
 3. CLIENT-SIDE EVENTS
-------------------------------------------------------------------------------
-- Events are client objects. Subscribe inside the client VM and log, or write
-- into a global table that the MemoryError script can read.
GamePlugin.Exec([[
    _G.MY_EVENTS = _G.MY_EVENTS or {}
    _G.MY_EVENTS.chat = {}

    Event.ChatMessage.Subscribe(function(event)
        local text = tostring(event and event.message or event)
        table.insert(_G.MY_EVENTS.chat, text)
        if #_G.MY_EVENTS.chat > 20 then
            table.remove(_G.MY_EVENTS.chat, 1)
        end
    end)

    Event.InventoryUpdated.Subscribe(function(event)
        log("inventory updated")
    end)

    -- Event.Logic.Subscribe(eventID, function() ... end)
]])

-- Read the collected events from the script:
local chatJson = GamePlugin.GetJson("_G.MY_EVENTS.chat")

-- Unsubscribe from inside the client VM. Keep the function reference in a
-- client global if you need to unsubscribe later.

-------------------------------------------------------------------------------
 4. NATIVE UI COMPONENTS
-------------------------------------------------------------------------------
-- All of this runs inside the client VM. The same API is used by the panel
-- created by this script.
GamePlugin.Exec([[
    local host = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)

    local root = ui.Layer.new(host)
    root:SetPos(40, 120)
    root:SetSize(300, 180)
    root.clickthrough = false
    root:MoveToFront()

    local bg = ui.Rectangle.new(root)
    bg:SetPos(0, 0)
    bg:SetSize(300, 180)
    bg.fill = true
    bg.rgba = 0x14100AEE
    bg.clickthrough = true

    local title = ui.Text.new(root)
    title:SetPos(12, 8)
    title:SetSize(276, 24)
    title.content = "Example panel"
    title.font = id.Font.CINZEL_13PT_BOLD
    title.rgba = 0xF2C66DFF
    title.isShadowed = true
    title.maxLines = 1

    local label = ui.Text.new(root)
    label:SetPos(12, 40)
    label:SetSize(276, 20)
    label.content = "Status: ready"
    label.font = id.Font.MUSEO_SANS_15PT_REGULAR
    label.rgba = 0xE7D7B0FF
    label.alignHorizontal = ui.AlignMode.TOPLEFT
    label.alignVertical = ui.AlignMode.CENTRE

    local button = ui.Layer.new(root)
    button:SetPos(12, 80)
    button:SetSize(100, 26)
    button.clickthrough = false

    button:Subscribe(ui.Hook.ONCLICK, function()
        label.content = "Clicked"
        return false
    end)
    button:Subscribe(ui.Hook.ONMOUSEOVER, function()
        return false
    end)
    button:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        return false
    end)
]])

-- Native UI notes:
--   Components:
--     ui.Layer, ui.Rectangle, ui.Text, ui.Sprite, ui.Canvas, ui.Button,
--     ui.InputField, ui.ComboField, ui.Model, ui.ModelGroup
--   Layout:
--     SetPos(x, y, xAnchor, yAnchor)
--     SetSize(w, h, wAnchor, hAnchor)
--     ui.AlignMode.CENTRE / TOPLEFT / TOPRIGHT / BOTTOMLEFT / BOTTOMRIGHT
--   Hooks:
--     ui.Hook.ONCLICK / ONMOUSEOVER / ONMOUSELEAVE / ONHOLD / ONRELEASE /
--     ONDRAG / ONDRAGCOMPLETE
--   Parent and constants:
--     ui.Interfaces:GetComponent(id.Component.*)
--     ui.Interfaces:GetInterface(interfaceID)
--     id.Font.*, id.Sprite.*, id.Component.*, id.Interface.*, id.StyleSheet.*
--   Visibility and lifetime:
--     component.hidden = true hides the component and its children
--     component:Destroy() removes it
--     Keep the root in a client global so it stays alive

-------------------------------------------------------------------------------
 5. PERSISTENT CLIENT-SIDE PANEL
-------------------------------------------------------------------------------
-- Create once, then update from the script. This is the pattern used by
-- ME_AFK_PANEL in this file.
GamePlugin.Exec([[
    _G.MY_PANEL = _G.MY_PANEL or {}

    function _G.MY_PANEL.Create()
        local host = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
        if not host then return false end

        local root = ui.Layer.new(host)
        root:SetPos(40, 120)
        root:SetSize(280, 120)
        root.clickthrough = false
        root:MoveToFront()

        local bg = ui.Rectangle.new(root)
        bg:SetPos(0, 0)
        bg:SetSize(280, 120)
        bg.fill = true
        bg.rgba = 0x14100AEE

        _G.MY_PANEL.label = ui.Text.new(root)
        _G.MY_PANEL.label:SetPos(12, 12)
        _G.MY_PANEL.label:SetSize(256, 20)
        _G.MY_PANEL.label.font = id.Font.MUSEO_SANS_15PT_REGULAR
        _G.MY_PANEL.label.rgba = 0xE7D7B0FF
        _G.MY_PANEL.label.content = "waiting"

        _G.MY_PANEL.root = root
        return true
    end

    function _G.MY_PANEL.SetStatus(text)
        if _G.MY_PANEL.label then
            _G.MY_PANEL.label.content = tostring(text)
        end
    end
]])

if GamePlugin.Exec("return _G.MY_PANEL.Create()") == "OK|true" then
    GamePlugin.CallExe("MY_PANEL.SetStatus", "running")
end

-------------------------------------------------------------------------------
 6. PLUGIN MANAGER
-------------------------------------------------------------------------------
local plugins = GamePlugin.GetPlugins()
if type(plugins) == "table" then
    for _, plugin in ipairs(plugins) do
        print(plugin.name, plugin.identifier, plugin.version,
              plugin.enabled, plugin.remoteId)
    end
end

-- Dump a plugin source to <MemoryError base>/PluginDumps/<identifier>/:
-- GamePlugin.DumpPlugin(identifier)

-- Install a local plugin folder without restarting the client:
-- GamePlugin.InstallLocalPlugin(folder, remoteId)

-- Mark the Mod.io auth state as authenticated (local development only):
-- GamePlugin.SkipAuth()

-------------------------------------------------------------------------------
 7. FUNCTION DISCOVERY
-------------------------------------------------------------------------------
-- GetFunctions returns the client API surface. withAddresses=true is slower.
local functions = GamePlugin.GetFunctions(false)
if type(functions) == "table" then
    for _, fn in ipairs(functions) do
        print(fn.name, fn.path, fn.params, fn.vararg, fn.cfunction)
    end
end

local function findClientFunction(name)
    local list = GamePlugin.GetFunctions(false)
    if type(list) ~= "table" then return nil end
    for _, fn in ipairs(list) do
        if fn.name == name then return fn end
    end
    return nil
end

-------------------------------------------------------------------------------
 8. USEFUL GLOBALS IN THE CLIENT VM
-------------------------------------------------------------------------------
--   Player, World, Camera, Chat, Inventory, NPCList, LocList, ObjStackList,
--   GrandExchange, Event, ui, id, config, var, Plugin, log
--   config.* and id.* contain IDs and config providers.
--   Event.* contains client event sources.
--   Plugin.resources contains files from the loaded plugin package.
--   Use GamePlugin.GetJson / GamePlugin.Exec to inspect unknown objects.
===============================================================================
]==]

-- api.lua defines GamePlugin doc stubs at the end (outside its if-false block),
-- and those stubs overwrite the real C++ bridge functions. Save the bridge
-- functions first, then restore them after require("api").
local GP_BRIDGE = {}
if type(GamePlugin) == "table" then
    for key, value in pairs(GamePlugin) do
        if type(value) == "function" then
            GP_BRIDGE[key] = value
        end
    end
end

local API = require("api")

if type(GamePlugin) == "table" then
    for key, value in pairs(GP_BRIDGE) do
        GamePlugin[key] = value
    end
end

local UI_SETUP = [====[
local ok, err = pcall(function()
    assert(type(ui) == "table", "ui API is not available")
    assert(ui.Interfaces ~= nil, "ui.Interfaces is not available")
    assert(ui.Layer ~= nil and ui.Layer.new ~= nil, "ui.Layer.new is not available")
    assert(type(id) == "table", "id table is not available")
    assert(id.Component ~= nil, "id.Component is not available")

    local FONT_TITLE = id.Font and id.Font.CINZEL_13PT_BOLD or nil
    local FONT_BODY = id.Font and id.Font.MUSEO_SANS_15PT_REGULAR or nil

    local C_BG = 0x14100AEE
    local C_HEADER = 0x221B10EE
    local C_BORDER = 0x4A3F2FFF
    local C_TRACK = 0x2A241AFF
    local C_GOLD = 0xF2C66DFF
    local C_TEXT = 0xE7D7B0FF
    local C_DIM = 0xA89C84FF
    local C_GREEN = 0x7FD97FFF
    local C_BUTTON = 0x2E261AFF
    local C_BUTTON_HOVER = 0x3E3424FF
    local C_STOP = 0x4A2222FF
    local C_STOP_HOVER = 0x6A2E2EFF

    local function resolveParent()
        local parent
        pcall(function()
            parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
        end)
        if parent then return parent end

        pcall(function()
            parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
        end)
        if parent then return parent end

        for _, iid in ipairs({ 1477, 1448, 1432, 1483 }) do
            local ok2, comp = pcall(function()
                return ui.Interfaces:GetComponent(iid, 0)
            end)
            if ok2 and comp then return comp end
        end
        return nil
    end

    local function rect(parent, x, y, w, h, rgba, fill)
        local r = ui.Rectangle.new(parent)
        r:SetPos(x, y)
        r:SetSize(w, h)
        r.fill = fill ~= false
        r.rgba = rgba
        r.clickthrough = true
        return r
    end

    local function label(parent, x, y, w, h, content, font, rgba, align)
        local t = ui.Text.new(parent)
        t:SetPos(x, y)
        t:SetSize(w, h)
        t.content = content or ""
        t.font = font
        t.rgba = rgba or C_TEXT
        t.isShadowed = true
        t.maxLines = 1
        t.alignHorizontal = align or ui.AlignMode.TOPLEFT
        t.alignVertical = ui.AlignMode.CENTRE
        t.clickthrough = true
        return t
    end

    local function setText(component, value)
        if component then component.content = tostring(value or "") end
    end

    local function button(parent, x, y, w, h, caption, rgba, hover, onclick)
        local layer = ui.Layer.new(parent)
        layer:SetPos(x, y)
        layer:SetSize(w, h)
        layer.clickthrough = false

        local bg = rect(layer, 0, 0, w, h, rgba, true)
        bg.clickthrough = true
        local txt = label(layer, 0, 0, w, h, caption, FONT_BODY, C_TEXT, ui.AlignMode.CENTRE)
        txt.clickthrough = true

        layer:Subscribe(ui.Hook.ONMOUSEOVER, function()
            bg.rgba = hover
            return false
        end)
        layer:Subscribe(ui.Hook.ONMOUSELEAVE, function()
            bg.rgba = rgba
            return false
        end)
        layer:Subscribe(ui.Hook.ONCLICK, function()
            if onclick then onclick() end
            return false
        end)
        return layer
    end

    ME_AFK_PANEL = ME_AFK_PANEL or {}
    local P = ME_AFK_PANEL
    P.stopRequested = false

    function P.Create()
        local parent = resolveParent()
        if not parent then return false end

        P.closed = false
        if P.handle then pcall(function() P.handle:Destroy() end) end
        if P.root then pcall(function() P.root:Destroy() end) end
        P.handle = nil
        P.root = nil

        P.interfaceID = parent.interfaceID

        local root = ui.Layer.new(parent)
        root:SetPos(40, 120)
        root:SetSize(340, 268)
        root.clickthrough = false
        root:MoveToFront()
        P.root = root

        local function sprite(spriteID)
            local component = ui.Sprite.new(root)
            component.spriteID = spriteID
            component.clickthrough = true
            return component
        end

        local bg = sprite(id.Sprite.RS3_MODAL_WINDOW_CONTENT_TILE)
        bg:SetPos(8, 32)
        bg:SetSize(-16, -40, 1.0, 1.0)
        bg.isTiling = true

        local left = sprite(id.Sprite.RS3_MODAL_WINDOW_1_SIDE_TILE)
        left:SetPos(0, 32)
        left:SetSize(8, -48, 0, 1.0)
        left.isTiling = true

        local right = sprite(id.Sprite.RS3_MODAL_WINDOW_1_SIDE_TILE)
        right:SetPos(-8, 32, 1.0)
        right:SetSize(8, -48, 0, 1.0)
        right.isFlippedHorizontally = true
        right.isTiling = true

        local bottom = sprite(id.Sprite.RS3_MODAL_WINDOW_1_BOTTOM_TILE)
        bottom:SetPos(16, -8, 0, 1.0)
        bottom:SetSize(-32, 8, 1.0, 0)
        bottom.isTiling = true

        local bl = sprite(id.Sprite.RS3_MODAL_WINDOW_1_BOTTOM_CORNER)
        bl:SetPos(0, -16, 0, 1.0)
        bl:SetSize(16, 16)

        local br = sprite(id.Sprite.RS3_MODAL_WINDOW_1_BOTTOM_CORNER)
        br:SetPos(-16, -16, 1.0, 1.0)
        br:SetSize(16, 16)
        br.isFlippedHorizontally = true

        local tl = sprite(id.Sprite.RS3_MODAL_WINDOW_1_TITLE_CORNER)
        tl:SetSize(28, 32)

        local tcl = sprite(id.Sprite.RS3_MODAL_WINDOW_1_TITLE_TILE)
        tcl:SetPos(28, 0)
        tcl:SetSize(64, 32)

        local tc = sprite(id.Sprite.RS3_MODAL_WINDOW_1_TITLE_END)
        tc:SetPos(92, 0)
        tc:SetSize(-220, 32, 1.0, 0)
        tc.isTiling = true

        local tcr = sprite(id.Sprite.RS3_MODAL_WINDOW_1_TOP_TILE)
        tcr:SetPos(-128, 0, 1.0)
        tcr:SetSize(64, 32)

        local tr = sprite(id.Sprite.RS3_MODAL_WINDOW_1_CLOSE_CORNER)
        tr:SetPos(-64, 0, 1.0)
        tr:SetSize(64, 32)

        local close = sprite(id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML)
        close:SetPos(-28, 7, 1.0)
        close:SetSize(20, 20)
        close.clickthrough = false
        close:Subscribe(ui.Hook.ONMOUSEOVER, function()
            close.spriteID = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_OVR
            return false
        end)
        close:Subscribe(ui.Hook.ONMOUSELEAVE, function()
            close.spriteID = id.Sprite.RS3_BTN_MODAL_WINDOW_1_CLOSE_NML
            return false
        end)
        close:Subscribe(ui.Hook.ONCLICK, function()
            P.closed = true
            P.Destroy()
            return false
        end)

        label(root, 12, 2, 292, 28, "AFK HELPER", FONT_TITLE, 0xF4E4B8FF, ui.AlignMode.CENTRE)

        label(root, 16, 40, 70, 18, "STATUS", FONT_BODY, C_DIM)
        P.statusLabel = label(root, 86, 40, 130, 18, "IDLE", FONT_BODY, C_DIM)
        P.runtimeLabel = label(root, 220, 40, 104, 18, "00:00:00", FONT_BODY, C_TEXT)

        rect(root, 16, 62, 308, 1, C_BORDER, true)

        label(root, 16, 68, 90, 14, "LOOPS", FONT_BODY, C_DIM)
        P.loopsLabel = label(root, 16, 82, 90, 20, "0", FONT_BODY, C_TEXT)

        label(root, 122, 68, 100, 14, "XP GAINED", FONT_BODY, C_DIM)
        P.xpLabel = label(root, 122, 82, 100, 20, "0", FONT_BODY, C_TEXT)

        label(root, 236, 68, 88, 14, "XP / HR", FONT_BODY, C_DIM)
        P.xphLabel = label(root, 236, 82, 88, 20, "0", FONT_BODY, C_GOLD)

        rect(root, 16, 110, 308, 1, C_BORDER, true)

        label(root, 16, 116, 80, 16, "PROGRESS", FONT_BODY, C_DIM)
        P.detailLabel = label(root, 100, 116, 224, 16, "", FONT_BODY, C_TEXT)

        rect(root, 16, 136, 308, 8, C_TRACK, true)
        P.barWidth = 306
        P.barFill = rect(root, 17, 137, 1, 6, C_GOLD, true)

        P.footerLabel = label(root, 16, 150, 308, 16, "", FONT_BODY, C_DIM)

        button(root, 224, 226, 100, 26, "STOP", C_STOP, C_STOP_HOVER, function()
            P.stopRequested = true
            setText(P.statusLabel, "STOPPING")
        end)
        button(root, 112, 226, 84, 26, "HIDE", C_BUTTON, C_BUTTON_HOVER, function()
            if P.root then P.root.hidden = true end
            if P.handle then P.handle.hidden = false end
        end)
        button(root, 16, 226, 88, 26, "CLOSE", C_BUTTON, C_BUTTON_HOVER, function()
            P.closed = true
            P.Destroy()
        end)

        local handle = ui.Layer.new(parent)
        handle:SetPos(40, 120)
        handle:SetSize(72, 24)
        handle.clickthrough = false
        handle.hidden = true
        P.handle = handle

        rect(handle, 0, 0, 72, 24, C_BG, true)
        local hb = rect(handle, 0, 0, 72, 24, C_BORDER, false)
        hb.outlineThickness = 1
        label(handle, 0, 0, 72, 24, "AFK", FONT_TITLE, C_GOLD, ui.AlignMode.CENTRE)
        handle:Subscribe(ui.Hook.ONCLICK, function()
            if P.root then P.root.hidden = false end
            handle.hidden = true
            return false
        end)

        return true
    end

    function P.Update(state)
        state = state or {}
        if P.closed then return true end

        local valid = true
        if P.interfaceID then
            local okCheck, iface = pcall(function()
                return ui.Interfaces:GetInterface(P.interfaceID)
            end)
            valid = okCheck and iface ~= nil
        end

        if not P.root or not valid then
            P.root = nil
            P.handle = nil
            local okCreate, created = pcall(P.Create)
            if not okCreate or not created then return false end
        end

        setText(P.statusLabel, state.status or "IDLE")
        if P.statusLabel then
            P.statusLabel.rgba = state.running and C_GREEN or C_DIM
        end
        setText(P.runtimeLabel, state.runtime or "00:00:00")
        setText(P.loopsLabel, state.loops or 0)
        setText(P.xpLabel, state.xp or 0)
        setText(P.xphLabel, state.xph or 0)
        setText(P.detailLabel, state.detail or "")
        setText(P.footerLabel, state.footer or "")

        local progress = tonumber(state.progress) or 0
        if progress < 0 then progress = 0 end
        if progress > 1 then progress = 1 end
        if P.barFill then
            P.barFill:SetSize(math.max(1, math.floor(P.barWidth * progress)), 6)
        end
        return true
    end

    function P.IsStopRequested()
        return P.stopRequested == true
    end

    function P.Destroy()
        if P.handle then pcall(function() P.handle:Destroy() end) end
        if P.root then pcall(function() P.root:Destroy() end) end
        P.root = nil
        P.handle = nil
    end

    if not P.Create() then
        error("no UI parent found")
    end
    return "created"
end)

if not ok then
    error(err)
end
return err
]====]

local function log(message)
    print("[AFK] " .. tostring(message))
end

local function gpAvailable()
    if GamePlugin == nil then
        return false, "GamePlugin is nil"
    end
    if type(GamePlugin.IsAvailable) ~= "function" then
        return false, "GamePlugin.IsAvailable is not a function"
    end
    local ok, available = pcall(GamePlugin.IsAvailable)
    if not ok then
        return false, "GamePlugin.IsAvailable error: " .. tostring(available)
    end
    if available ~= true then
        return false, "client plugin state not initialized"
    end
    return true
end

local uiReady = false
local uiLastTry = 0
local lastNativeTry = 0

local lastGpReason = nil

local function setupUi(force)
    local available, reason = gpAvailable()
    if not available then
        if lastGpReason ~= reason then
            log("ERROR: native UI unavailable: " .. tostring(reason))
            lastGpReason = reason
        end
        return false, reason
    end
    lastGpReason = nil
    if uiReady and not force then
        return true
    end

    local ok, result = pcall(GamePlugin.Exec, UI_SETUP)
    if not ok then
        log("ERROR: UI setup exception: " .. tostring(result))
        return false, tostring(result)
    end

    if type(result) == "string" and result:sub(1, 3) == "OK|" then
        uiReady = true
        log("UI ready (" .. result:sub(4) .. ")")
        return true
    end

    log("ERROR: UI setup failed: " .. tostring(result))
    return false, tostring(result)
end

local function updateUi(data)
    if not gpAvailable() then
        return false
    end

    if not uiReady then
        local now = os.time()
        if now - uiLastTry < 5 then
            return false
        end
        uiLastTry = now
        if not setupUi(false) then
            return false
        end
    end

    local ok, result = pcall(GamePlugin.CallExe, "ME_AFK_PANEL.Update", data)
    if not ok then
        log("ERROR: UI update error: " .. tostring(result))
        uiReady = false
        return false
    end
    if result ~= true then
        uiReady = false
        return false
    end
    return true
end

local function stopRequested()
    if not uiReady then
        return false
    end
    if not gpAvailable() then
        return false
    end
    local ok, result = pcall(GamePlugin.CallExe, "ME_AFK_PANEL.IsStopRequested")
    return ok and result == true
end

local function destroyUi()
    if not gpAvailable() then
        return
    end
    pcall(GamePlugin.Exec, "if type(ME_AFK_PANEL) == 'table' and ME_AFK_PANEL.Destroy then ME_AFK_PANEL.Destroy() end")
    uiReady = false
end

log("Run Lua port fish script afker with native UI.")

local prev_xp_check = 0
local loopsofnoxp_check = 0
local loops = 0
local nativeMode = false
local start_xp = tonumber(API.GetSkillXP("FISHING")) or 0

API.SetDrawTrackedSkills(true)

if setupUi(false) then
    nativeMode = true
else
    log("ERROR: native UI could not be created; running without a panel.")
end

while API.Read_LoopyLoop() do
    loops = loops + 1
    API.DoRandomEvents(true)

    if stopRequested() then
        log("Stop requested from panel.")
        break
    end

    if not nativeMode then
        local now = os.time()
        if now - lastNativeTry >= 5 then
            lastNativeTry = now
            if setupUi(false) then
                nativeMode = true
                log("Native UI available.")
            end
        end
    end

    local current_xp_check = API.GatherEvents_xp_check()
    if (#current_xp_check > 0 and prev_xp_check ~= current_xp_check[1].exp) then
        prev_xp_check = current_xp_check[1].exp
        loopsofnoxp_check = 0
    else
        loopsofnoxp_check = loopsofnoxp_check + 1
    end

    local current_xp = tonumber(API.GetSkillXP("FISHING")) or start_xp
    local gained = math.max(0, current_xp - start_xp)
    local elapsed = tonumber(API.ScriptRuntime()) or 0
    local xph = 0
    if elapsed > 0 then
        xph = math.floor(gained * 3600 / elapsed)
    end

    local status = "FISHING"
    local running = true
    local detail = "Idle checks are clean."
    if loopsofnoxp_check > 0 then
        status = "WAITING FOR XP"
        running = false
        detail = string.format("No-XP checks: %d / 10", loopsofnoxp_check)
    end
    if Inventory:IsFull() then
        status = "INVENTORY FULL"
        running = false
        detail = "Inventory is full."
    end

    local data = {
        status = status,
        running = running,
        runtime = API.ScriptRuntimeString(),
        loops = loops,
        xp = gained,
        xph = xph,
        progress = math.min(1, loopsofnoxp_check / 10),
        detail = detail,
        footer = "Mockup panel driven by the script.",
    }

    if nativeMode then
        if not updateUi(data) then
            log("ERROR: native UI update failed; retrying.")
            nativeMode = false
            uiReady = false
        end
    end

    if loopsofnoxp_check > 10 then
        API.Write_LoopyLoop(false)
    end

    if not API.CheckAnim(100) then
        if not Inventory:IsFull() then
            API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route0, { 109001 }, 6)
            API.RandomSleep2(5000, 300, 400)
        end
    end

    API.RandomSleep2(1000, 3000, 4000)
end

API.Write_LoopyLoop(false)
destroyUi()
log("Stopped.")
