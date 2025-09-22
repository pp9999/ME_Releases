--[[
@title SuperSimpleBaniteMiner
@description Mines Banite rocks super simple
@author Fiddley
@date 22/09/2025
@version 1.0.0
--]]

local API = require("api")

local BANITE_ROCK_IDS = {113142, 113140, 113141}
local SPARKLE_IDS = {7164, 7165}
local OBJECT_TYPE = 0

local function findRock()
    -- find sparkles
    local sparkles = API.GetAllObjArray1(SPARKLE_IDS, 25, {4})
    local rocks = API.GetAllObjArrayInteract(BANITE_ROCK_IDS, 25, {0})

    print("Rocks: " .. tostring(#rocks) .. "  Sparkles: " .. tostring(#sparkles))

    if #rocks == 0 then return nil end

    -- Sparkle prio
    if #sparkles > 0 then
        for _, rock in pairs(rocks) do
            for _, spark in pairs(sparkles) do
                if math.abs(rock.Tile_XYZ.x - spark.Tile_XYZ.x) < 1 and
                   math.abs(rock.Tile_XYZ.y - spark.Tile_XYZ.y) < 1 then
                    print("Clicking sparkling rock ID " .. rock.Id)
                    return rock
                end
            end
        end
    end

    -- else tkae first rock
    print("Clicking normal rock ID " .. rocks[1].Id)
    return rocks[1]
end

local function clickRock(rock)
    if not rock then return end
    API.DoAction_Object2(0x3a, API.OFF_ACT_GeneralObject_route0, { rock.Id }, 25, WPOINT.new(rock.Tile_XYZ.x, rock.Tile_XYZ.y, rock.Tile_XYZ.z))
    API.RandomSleep2(200, 400, 600)
end

------------------------------------------
-- Main loop
------------------------------------------
API.SetMaxIdleTime(15)
print("Super Simple Banite Miner started")

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    math.randomseed(os.time())

    local rock = findRock()
    clickRock(rock)

    API.RandomSleep2(500, 800, 1200) -- iets langefre delay tussen clicks
end