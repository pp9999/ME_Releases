# RL (RuneLite) OSRS — Scripting Helper

> **Engine:** MemoryError Lua scripting layer for Old School RuneScape via RuneLite.  
> **Files:** `apiosrs.lua` (full OSRS API) + select functions from `api.lua` that are actively used in scripts.

---

## Table of Contents

1. [Script Boilerplate](#1-script-boilerplate)
2. [APIOSRS — Full Reference](#2-apiosrs--full-reference)
   - [RL_IsWidgetSelected](#rl_iswidgetselected)
   - [RL_ClickEntity](#rl_clickentity)
   - [RL_ClickSpellbook](#rl_clickspellbook)
   - [RL_ClickTile](#rl_clicktile)
   - [RL_GetFirstMenuEntry](#rl_getfirstmenuentry)
   - [RL_GetOpenTab](#rl_getopenTab)
   - [RL_OpenTab](#rl_opentab)
3. [API — Functions Used in Scripts](#3-api--functions-used-in-scripts)
   - [Loop Control](#loop-control)
   - [Sleep / Timing](#sleep--timing)
   - [Animation / Movement Checks](#animation--movement-checks)
   - [Object / World Scanning](#object--world-scanning)
   - [Container / Inventory Checks](#container--inventory-checks)
   - [Status Display](#status-display)
   - [ImGui Overlays](#imgui-overlays)
4. [Data Types](#4-data-types)
   - [MenuEntryData](#menuentrydata)
   - [AllObject](#allobject)
5. [Tab Index Reference](#5-tab-index-reference)
6. [Entity Type Reference](#6-entity-type-reference)
7. [Quick-Start Examples](#7-quick-start-examples)

---

## 1. Script Boilerplate

```lua
local API    = require("api")
local APIOSRS = require("apiosrs")

-- Main loop
API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do

    -- your logic here

    API.RandomSleep2(600, 200, 400)
end
```

> `API.Write_LoopyLoop(false)` or pressing **End** stops the script.

---

## 2. APIOSRS — Full Reference

All functions below are available via `APIOSRS.*`. The library wraps native `RL_*` engine calls.

---

### RL_IsWidgetSelected

```lua
APIOSRS.RL_IsWidgetSelected() --> boolean
```

Returns `true` if an item is currently selected (highlighted) in the inventory (i.e. after clicking "Use" on an item).

**Example:**
```lua
APIOSRS.RL_ClickEntity(93, { 946 })   -- click knife
API.RandomSleep2(300, 100, 200)
if APIOSRS.RL_IsWidgetSelected() then
    APIOSRS.RL_ClickEntity(93, { 1511 })  -- click logs
end
```

---

### RL_ClickEntity

```lua
APIOSRS.RL_ClickEntity(type, entityID, max_distance, localtile, tilex, tiley) --> boolean
```

Attempts to click/interact with a game entity. The entity must be visible on screen.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | `number` | **required** | Entity type (see [Entity Type Reference](#6-entity-type-reference)) |
| `entityID` | `number[]` | **required** | Table of one or more IDs to match e.g. `{1234}` or `{1234, 5678}` |
| `max_distance` | `number` | `15` | Maximum tile distance to search |
| `localtile` | `boolean` | `false` | If `true`, `tilex`/`tiley` are local tile coords (0–63) for precise tile targeting |
| `tilex` | `number` | `0` | Local tile X (only used when `localtile = true`) |
| `tiley` | `number` | `0` | Local tile Y (only used when `localtile = true`) |

**Returns:** `true` if the action was dispatched.

**Examples:**
```lua
-- Click an NPC by ID (Fishing Spot 8523), default distance
APIOSRS.RL_ClickEntity(1, { 8523 }, 12)

-- Click an item in inventory (type 93)
APIOSRS.RL_ClickEntity(93, { 22826 })

-- Click a specific game object on a known local tile
APIOSRS.RL_ClickEntity(0, { 27384 }, 25, true, 63, 40)

-- Click with multiple possible IDs (picks closest/first match)
APIOSRS.RL_ClickEntity(0, { 27384, 27395, 27406 }, 25, true, 58, 43)
```

> **Note:** Type `93` targets the inventory interface directly. For world objects use types 0 (objects), 1 (NPCs), or 2 (players).

---

### RL_ClickSpellbook

```lua
APIOSRS.RL_ClickSpellbook(spellname, spriteid) --> boolean
```

Clicks a spell in the spellbook by name.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `spellname` | `string` | **required** | Partial or full spell name e.g. `"High"` for High Alchemy |
| `spriteid` | `number` | `0` | Optional sprite ID override |

**Example:**
```lua
-- Click High Alchemy spell
APIOSRS.RL_ClickSpellbook("High", 0)
```

---

### RL_ClickTile

```lua
APIOSRS.RL_ClickTile(tilex, tiley, minimap) --> boolean
```

Walks to a tile by clicking it on the main game view or minimap.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tilex` | `number` | **required** | Local tile X coordinate (0–63) |
| `tiley` | `number` | **required** | Local tile Y coordinate (0–63) |
| `minimap` | `boolean` | `false` | If `true`, clicks on the minimap instead of the game world |

**Example:**
```lua
-- Walk to local tile via minimap
APIOSRS.RL_ClickTile(65, 64, true)
API.RandomSleep2(3500, 800, 1500)
```

---

### RL_GetFirstMenuEntry

```lua
APIOSRS.RL_GetFirstMenuEntry() --> MenuEntryData[]
```

Returns the current right-click context menu entries.

**Returns:** Array of [`MenuEntryData`](#menuentrydata) tables.

**Example:**
```lua
local entries = APIOSRS.RL_GetFirstMenuEntry()
for _, entry in ipairs(entries) do
    print(entry.option .. " -> " .. entry.target)
end
```

---

### RL_GetOpenTab

```lua
APIOSRS.RL_GetOpenTab() --> number
```

Returns the index of the currently open side panel tab.

**Returns:** A number from the [Tab Index Reference](#5-tab-index-reference).

**Example:**
```lua
if APIOSRS.RL_GetOpenTab() ~= 3 then
    APIOSRS.RL_OpenTab(3)  -- open Inventory
end
```

---

### RL_OpenTab

```lua
APIOSRS.RL_OpenTab(tab) --> boolean
```

Opens a side panel tab by index.

| Parameter | Type | Description |
|-----------|------|-------------|
| `tab` | `number` | Tab index (see [Tab Index Reference](#5-tab-index-reference)) |

**Keybind mapping:**

| Tab | Key sent |
|-----|----------|
| 0 – Combat Options | F1 |
| 1 – Skills | F2 |
| 2 – Quest List | F3 |
| 3 – Inventory | Escape |
| 4 – Equipment | F4 |
| 5 – Prayer | F5 |
| 6 – Magic/Spellbook | F6 |
| 7 – Clan Chat | F7 |
| 8 – Friends List | F8 |
| 9 – Account Management | F9 |
| 10 – Logout | F10 |
| 11 – Emotes | F11 |
| 12 – Music | F12 |

**Example:**
```lua
-- Open Prayer tab
APIOSRS.RL_OpenTab(5)
```

---

## 3. API — Functions Used in Scripts

Only the `api.lua` functions that are actively used across the included OSRS scripts are documented here.

---

### Loop Control

#### `API.Write_LoopyLoop(bool)`
```lua
API.Write_LoopyLoop(true)   -- start / keep running
API.Write_LoopyLoop(false)  -- stop the script
```
Sets the main loop boolean. Call `true` before your `while` loop.

#### `API.Read_LoopyLoop()`
```lua
while API.Read_LoopyLoop() do ... end
```
Returns `0` or `1` (falsy/truthy). Use as the `while` condition.

---

### Sleep / Timing

#### `API.RandomSleep2(wait, sleep, sleep2)`
```lua
API.RandomSleep2(wait, sleep, sleep2)
```
Sleeps for a randomised duration. All values in **milliseconds**.

| Parameter | Description |
|-----------|-------------|
| `wait` | Base guaranteed wait time (100% always sleeps this) |
| `sleep` | Random extra sleep added on top of `wait` |
| `sleep2` | Rare additional random sleep (infrequent) |

**Examples:**
```lua
API.RandomSleep2(600, 200, 400)    -- short tick delay
API.RandomSleep2(2500, 1000, 2000) -- wait for animation/action
API.RandomSleep2(700, 1777, 12777) -- variable fishing-style wait
```

#### `API.SystemTime()`
```lua
local t = API.SystemTime() --> number (milliseconds)
```
Returns the current system time in milliseconds. Use to build cooldown timers.

```lua
local cooldown = API.SystemTime()

-- later in loop:
if API.SystemTime() - cooldown > 600 then
    -- do something
    cooldown = API.SystemTime() + 200  -- set next allowed time
end
```

---

### Animation / Movement Checks

#### `API.CheckAnim(loops)`
```lua
API.CheckAnim(loops) --> boolean
```
Returns `true` if the local player is currently animating. `loops` is the number of internal checks to perform (higher = more confident).

```lua
if not API.CheckAnim(100) then
    -- player is idle, do next action
end
```

---

### Object / World Scanning

#### `API.ReadAllObjectsArray(types, ids, names)`
```lua
API.ReadAllObjectsArray(types, ids, names) --> AllObject[]
```
Scans the game world and returns all matching objects.

| Parameter | Type | Description |
|-----------|------|-------------|
| `types` | `number[]` | Object types to scan. Use `{-1}` for all. See [Entity Type Reference](#6-entity-type-reference) |
| `ids` | `number[]` | Filter by IDs. Use `{}` to skip |
| `names` | `string[]` | Filter by names. Use `{}` to skip |

**Common usage — scan for NPCs (type 1) and projectiles (type 5):**
```lua
local objects = API.ReadAllObjectsArray({1, 5}, {}, {})
for _, obj in ipairs(objects) do
    if obj.Type == 1 and obj.Id == 3127 then
        print("Found NPC: " .. obj.Name .. " anim: " .. obj.Anim)
    end
    if obj.Type == 5 and obj.Id == 2652 then
        print("Projectile incoming! Distance: " .. obj.Distance)
    end
end
```

**AllObject fields commonly used in OSRS scripts:**

| Field | Type | Description |
|-------|------|-------------|
| `obj.Id` | `number` | Entity/item ID |
| `obj.Type` | `number` | Object type (0=object, 1=npc, 5=projectile, 12=decor) |
| `obj.Anim` | `number` | Current animation ID |
| `obj.Distance` | `number` | Distance from local player |
| `obj.Name` | `string` | Entity name |
| `obj.TileX/Y/Z` | `number` | World tile coordinates |
| `obj.Tile_XYZ` | `FFPOINT` | Tile as FFPOINT (for `API.MarkTiles`) |

---

### Container / Inventory Checks

#### `API.Container_Check_Items(cont_id, item_ids)`
```lua
API.Container_Check_Items(cont_id, item_ids) --> boolean
```
Returns `true` if **any** of the given item IDs exist in the specified container.

| Parameter | Description |
|-----------|-------------|
| `cont_id` | Container ID. `93` = player inventory |
| `item_ids` | `number[]` — table of item IDs to check |

```lua
-- Check if inventory has any prayer potions
if API.Container_Check_Items(93, {139, 141, 143, 2434}) then
    -- drink pot
end

-- Check if inventory has food
if API.Container_Check_Items(93, {13441, 385, 7946}) then
    -- eat food
end
```

> **Tip:** The `Inventory:Contains()` / `Inventory:ContainsAny()` class methods are a more readable alternative for inventory slot 93.

---

### Status Display

#### `API.Write_ScripCuRunning0(status)`
```lua
API.Write_ScripCuRunning0(msg) --> void
```
Writes a status string to the ME script status line 0 (visible in the overlay). Useful for showing current script state.

```lua
API.Write_ScripCuRunning0("Watering tile 3 (stage 2)")
```

---

### ImGui Overlays

These are used together to draw persistent text/UI overlays on the game screen. Call `CreateIG_answer()` **once before the loop**, then the draw calls **outside** the loop register them as persistent overlays.

#### `API.CreateIG_answer()`
```lua
local box = API.CreateIG_answer() --> IG_answer
```
Creates an overlay element data structure.

#### `API.DrawTextAt(data)` / `API.DrawTextAtBG(data)`
```lua
API.DrawTextAt(data)    -- draw text (no background)
API.DrawTextAtBG(data)  -- draw text with background box
```
Registers a text overlay at a screen position.

#### `API.DrawComboBox(data)`
```lua
API.DrawComboBox(data)
```
Renders a dropdown/combo-box overlay. Populate `data.stringsArr` with options; read selection from `data.int_value`.

**Full overlay setup example (from `OSRS_hespori.lua`):**
```lua
-- Setup ONCE, before the loop
local textBox = API.CreateIG_answer()
textBox.box_name   = "Status"
textBox.box_start  = FFPOINT.new(5, 50, 0)   -- screen pixel position
textBox.box_size   = FFPOINT.new(95, 20, 0)  -- width, height
textBox.string_value = ""
textBox.colour     = ImColor.new(255, 255, 255)
API.DrawTextAtBG(textBox)

local selector = API.CreateIG_answer()
selector.box_name  = "BossSelect"
selector.box_start = FFPOINT.new(100, 50, 0)
selector.box_size  = FFPOINT.new(220, 50, 0)
selector.colour    = ImColor.new(255, 255, 255)
selector.stringsArr = { "Hespori", "Jad", "Scurrius" }
API.DrawComboBox(selector)

-- In the loop, just update the value:
while API.Read_LoopyLoop() do
    textBox.string_value = "Praying range"

    local selected = selector.int_value  -- 0-based index
end
```

#### `API.MarkTiles(tiles, fortime, color, thick, filled, square, pixelshape, pixellocation)`
```lua
API.MarkTiles(tiles, fortime, color, thick, filled, square, pixelshape, pixellocation)
```
Draws tile highlights on the game world.

| Parameter | Description |
|-----------|-------------|
| `tiles` | `FFPOINT[]` — table of tile coordinates, use `obj.Tile_XYZ` from `AllObject` |
| `fortime` | Milliseconds to keep the highlight on screen |
| `color` | Hex colour e.g. `0xFF0000` for red (optional, default 0) |
| `thick` | Line thickness float (optional) |
| `filled` | `boolean` — fill the tile square |
| `square` | `boolean` — force square shape |
| `pixelshape` | `WPOINT` — override box pixel size |
| `pixellocation` | `WPOINT` — override pixel position |

```lua
-- Highlight a death mechanic tile for 5 seconds
API.MarkTiles({ obj.Tile_XYZ }, 5000)

-- Highlight with red color, filled
API.MarkTiles({ obj.Tile_XYZ }, 3000, 0xFF0000, 2, true, false,
    WPOINT.new(0,0,0), WPOINT.new(0,0,0))
```

---

## 4. Data Types

### MenuEntryData

Returned by `APIOSRS.RL_GetFirstMenuEntry()`.

| Field | Type | Description |
|-------|------|-------------|
| `option` | `string` | Action text e.g. `"Talk-to"`, `"Attack"` |
| `target` | `string` | Target entity name |
| `identifier` | `number` | Internal identifier |
| `param0` | `number` | Parameter 0 |
| `param1` | `number` | Parameter 1 |
| `isWidget` | `boolean` | True if this is a widget/interface action |

---

### AllObject

Returned by `API.ReadAllObjectsArray()` and other scan functions.

| Field | Type | Description |
|-------|------|-------------|
| `Id` | `number` | Entity/NPC/item ID |
| `Type` | `number` | Object type (see [Entity Type Reference](#6-entity-type-reference)) |
| `Name` | `string` | Display name |
| `Anim` | `number` | Current animation ID (`0` = idle) |
| `Distance` | `number` | Distance from local player in tiles |
| `TileX` | `number` | World X tile coordinate |
| `TileY` | `number` | World Y tile coordinate |
| `TileZ` | `number` | Plane / floor level |
| `Tile_XYZ` | `FFPOINT` | Tile as FFPOINT (pass to `API.MarkTiles`) |
| `Life` | `number` | Entity HP / life points |
| `Floor` | `number` | Floor/plane level |
| `Mem` | `number` | Memory address |

---

## 5. Tab Index Reference

Used by `APIOSRS.RL_GetOpenTab()` and `APIOSRS.RL_OpenTab()`.

| Index | Tab Name |
|-------|----------|
| `0` | Combat Options |
| `1` | Skills |
| `2` | Quest List |
| `3` | Inventory |
| `4` | Equipment |
| `5` | Prayer |
| `6` | Spellbook / Magic |
| `7` | Clan Chat |
| `8` | Friends List |
| `9` | Account Management |
| `10` | Logout |
| `11` | Emotes |
| `12` | Music |

---

## 6. Entity Type Reference

Used by `APIOSRS.RL_ClickEntity()` and `API.ReadAllObjectsArray()`.

| Type | Description |
|------|-------------|
| `0` | Game Object (trees, rocks, chests, patches, etc.) |
| `1` | NPC (monsters, fishing spots, shops, etc.) |
| `2` | Player |
| `3` | Ground Item *(not working in RL_ClickEntity)* |
| `5` | Projectile (arrows, spells, bolts) |
| `12` | Decor / Wall objects |
| `93` | Inventory interface (for clicking inventory items) |

---

## 7. Quick-Start Examples

### High Alchemy Bot

```lua
local API    = require("api")
local APIOSRS = require("apiosrs")

local ITEM_TO_ALCH = 13307  -- item ID to alch

API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do

    APIOSRS.RL_ClickSpellbook("High", 0)
    API.RandomSleep2(2500, 1000, 2000)

    APIOSRS.RL_ClickEntity(93, { ITEM_TO_ALCH })
    API.RandomSleep2(2500, 1000, 2000)

    API.RandomSleep2(1700, 1777, 12777)
end
```

---

### Fishing Bot with Cutting

```lua
local API    = require("api")
local APIOSRS = require("apiosrs")

local FISHING_SPOT = 8523
local KNIFE = 946
local RAW_FISH = { 22826, 22829, 22832, 22835 }

local safetyloopcheck = 0
API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do

    if safetyloopcheck > 35 then
        API.Write_LoopyLoop(false)
    end

    if not API.CheckAnim(100) then
        if not Inventory:IsFull() then
            APIOSRS.RL_ClickEntity(1, { FISHING_SPOT }, 12)
            safetyloopcheck = safetyloopcheck + 1
        else
            safetyloopcheck = 0
            if Inventory:Contains({ KNIFE }) and Inventory:ContainsAny(RAW_FISH) then
                APIOSRS.RL_ClickEntity(93, { KNIFE })
                API.RandomSleep2(200, 777, 1777)
                if APIOSRS.RL_IsWidgetSelected() then
                    for _, fishId in ipairs(RAW_FISH) do
                        local count = Inventory:InvItemcount(fishId)
                        if count > 0 then
                            APIOSRS.RL_ClickEntity(93, { fishId })
                            API.RandomSleep2(1000 * count, 1000, 10000)
                        end
                    end
                end
            end
        end
    end

    API.RandomSleep2(700, 1777, 12777)
end
```

---

### Farming Patch Bot (Plant / Water / Harvest)

```lua
local API    = require("api")
local APIOSRS = require("apiosrs")

local SEEDS       = { 13423, 13424, 13425 }
local EMPTY_PATCH = 27383
local CAN         = 13353
local STAGE4      = { 27393, 27404, 27415 }  -- harvestable

local function walkTo(x, y)
    APIOSRS.RL_ClickTile(x, y, true)
    API.RandomSleep2(3500, 800, 1500)
end

local function selectSeed()
    APIOSRS.RL_ClickEntity(93, SEEDS)
    API.RandomSleep2(600, 200, 300)
    return APIOSRS.RL_IsWidgetSelected()
end

local function plant(tx, ty)
    if selectSeed() then
        APIOSRS.RL_ClickEntity(0, { EMPTY_PATCH }, 25, true, tx, ty)
        API.RandomSleep2(2500, 600, 1000)
    end
end

local function water(tx, ty, waterableIds)
    APIOSRS.RL_ClickEntity(0, waterableIds, 25, true, tx, ty)
    API.RandomSleep2(2000, 500, 800)
end

local function harvest(tx, ty)
    APIOSRS.RL_ClickEntity(0, STAGE4, 25, true, tx, ty)
    API.RandomSleep2(2500, 600, 1000)
end

API.Write_LoopyLoop(true)
-- state machine loop goes here ...
```

---

*Last updated: February 2026 | API VERSION: APIOSRS 1.000*
