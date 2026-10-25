---@class ItemsNeeded
---@field inventoryItems number[]
---@field equippedItems number[]

---@class SlayerTask
---@field id number
---@field name string
---@field location FFPOINT
---@field range number
---@field npcIds number[]
---@field itemsNeeded? ItemsNeeded
---@field otherConditions? function
---@field specialActions? function

---@type table<number, SlayerTask>
local Tasks = {
    [91] = {
        id = 91,
        name = "Spiritual Mages",
        location = FFPOINT.new(0, 0, 0),
        range = 50,
        npcIds = { 6221, 16962, 6257, 6278, 6231 },
    },
    [112] = {
        id = 112,
        name = "Grotworms",
        location = FFPOINT.new(0, 0, 0),
        range = 50,
        npcIds = { 15462, 15463 },
    },
    [152] = {
        id = 152,
        name = "Corrupted creatures",
        location = FFPOINT.new(0, 0, 0),
        range = 50,
        npcIds = {},
    },
    [172] = {
        id = 172,
        name = "Vile blooms",
        location = FFPOINT.new(0, 0, 0),
        range = 50,
        npcIds = { 26565, 26566, 26563, 26567 },
    },
    [173] = {
        id = 173,
        name = "Dragons",
        location = FFPOINT.new(0, 0, 0),
        range = 50,
        npcIds = {},
    },
    [179] = {
        id = 179,
        name = "Nodon dragonkin",
        location = FFPOINT.new(0, 0, 0),
        range = 50,
        npcIds = {},
    },
}

return Tasks
