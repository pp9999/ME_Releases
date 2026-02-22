local API = require("api")
local APIOSRS = require("apiosrs")

local golovanova_seed = 13423
local golovanova1 = 27384--watered is +1
local golovanova2 = 27387
local golovanova3 = 27390
local golovanova4 = 27393

local bologano_seed = 13424
local bologano1 = 27395
local bologano2 = 27398
local bologano3 = 27401
local bologano4 = 27404

local logavano_seed = 13425
local logavano1 = 27406
local logavano2 = 27409
local logavano3 = 27412
local logavano4 = 27415

local seeds = { golovanova_seed, bologano_seed, logavano_seed }
local seeded_objects = { golovanova1, golovanova2, golovanova3, golovanova4, bologano1, bologano2, bologano3, bologano4, logavano1, logavano2, logavano3, logavano4 }

local empty_patch = 27383
local grifallicwateringcan = 13353

--tiles are in format {x,y,z} z=growthstage: 0=empty, 1=seeded, 2=watered, 3=fully grown
local tile1 = { x=63,y=40,z=0 } local tile2 = { x=58,y=40,z=0 } local tile3 = { x=63,y=43,z=0 } local tile4 = { x=58,y=43,z=0 }
local tile5 = { x=63,y=46,z=0 } local tile6 = { x=58,y=46,z=0 } local tile7 = { x=63,y=49,z=0 } local tile8 = { x=58,y=49,z=0 }
--local tile9 = { x=63,y=55,z=0 } local tile10 = { x=58,y=55,z=0 } local tile11 = { x=63,y=58,z=0 } local tile12 = { x=58,y=58,z=0 }
--local tile13 = { x=63,y=61,z=0 } local tile14 = { x=58,y=61,z=0 } local tile15 = { x=63,y=64,z=0 } local tile16 = { x=58,y=64,z=0 }

local tiles = { tile1, tile2, tile3, tile4, tile5, tile6, tile7, tile8 }

local starttile = { x=65,y=64,z=0 }
local midtile = { x=65,y=49,z=0 }
local ACTIVE_tile = { 0,0,0 }
local currenttile = 1
local currentgrowth = 0
local currentfail = 0
local newstart = false
local newstart2 = false
::continue::
while API.Read_LoopyLoop() do

if currentfail > 10 then
    API.Write_LoopyLoop(false)
    print("much fail")
    goto continue
end 

    --check inventory for needed items
    if Inventory:Contains({golovanova_seed,bologano_seed,logavano_seed}) and Inventory:Contains({grifallicwateringcan}) then
        --move to starting tile
        if newstart then
            newstart = false
            --APIOSRS.RL_ClickTile(starttile.x,starttile.y, true)
            --print("moving to starting tile")
            --API.RandomSleep2(7000, 1000, 12000)
        end

        --find next empty tile
        currenttile = -1
        for _, t in ipairs(tiles) do
            if t.z == 0 then
                currenttile = _
                break
            end
        end
        --use mouse on seed in inventory
        if currenttile ~= -1 then
            APIOSRS.RL_ClickEntity(93, seeds)
            API.RandomSleep2(500, 1000, 2000)
            --check if seed is selected
            if APIOSRS.RL_IsWidgetSelected() then
                --use seed on tile/object
                local trycount1 = 0
                while true do
                trycount1 = trycount1 + 1
                if APIOSRS.RL_ClickEntity(0, { empty_patch }, 25, true, tiles[currenttile].x, tiles[currenttile].y) then
                    tiles[currenttile].z = 1--mark tile as seeded
                    currentfail = currentfail + 1
                    print("plant")
                    if newstart2 then
                        newstart2 = false
                        API.RandomSleep2(4500, 1000, 2000)
                    end
                    API.RandomSleep2(2200, 500, 1000)
                    break;
                end
                if trycount1 > 4 then
                    print("plant failed")
                    break;
                end
                end
            end
            local trycount2 = 0
            while true do
            trycount2 = trycount2 + 1
            if APIOSRS.RL_ClickEntity(0, seeded_objects, 20, true, tiles[currenttile].x, tiles[currenttile].y) then
                tiles[currenttile].z = 1--mark tile as seeded
                print("water")                
                API.RandomSleep2(500, 1000, 2000)
                break;
            end
            if trycount2 > 4 then
                print("water failed")
                break;
            end
            end
        else
            --watch for un-watered tiles or harvestable tiles and water/harvest them
            if APIOSRS.RL_ClickEntity(0, seeded_objects, 20, true) then
                API.RandomSleep2(700, 500, 1000)
            end
            --check until all patches are empty then reset
            local counted = 0
            local objects = API.ReadAllObjectsArray({-1},{},{})
            for _, obj in ipairs(objects) do
                if (obj ~= nil and obj.Type == 0 and obj.Id == empty_patch) then
                    for _, t in ipairs(tiles) do
                        if (obj.CalcX == t.x and obj.CalcY == t.y) then
                            counted = counted + 1
                            break
                        end
                    end
                end
            end
            if counted == 8*9 then
                for i = 1, #tiles do
                    tiles[i].z = 0
                end
                print("all empty start again")
                currentfail = 0
                newstart = true
                newstart2 = true
                goto continue
            end
        end
    end
    API.RandomSleep2(1400, 1777, 3777)
end