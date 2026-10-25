---@class SlayerMaster
---@field id number
---@field name string
---@field slayerLevelRequirement number
---@field combatLevelRequirement number
---@field location FFPOINT
---@field otherConditions function

---@type table<string, SlayerMaster>
local SlayerMasters = {
    ["Laniakea"] = {
        id = 26558,
        name = "Laniakea",
        slayerLevelRequirement = 90,
        combatLevelRequirement = 120,
        location = FFPOINT.new(5668, 2138, 0),
        otherConditions = function() return true end
    },
}

return SlayerMasters
