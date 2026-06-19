local API = require("api")
local APIOSRS = require("apiosrs")


local bruma_root = 20695 
local bruma_kindling = 20696
local knife = 946
local hammer = 2347
local tinderbox = 590
local bruma_roots = 29311
local brazier_burning = 29314
local brazier_light = 29312
local brazier_broken = 29313;
local near_brazier = FFPOINT.new(1639, 3996, 0)
local foods = { 329, 20702, 20701, 20700, 20699  } --add foods here
local roots = {29311}
while API.Read_LoopyLoop() do
    --print("RL_GetWintertodtTimer:" .. tostring(APIOSRS.RL_GetWintertodtTimer()))
    --print("RL_GetWintertodtWarmth:" .. tostring(APIOSRS.RL_GetWintertodtWarmth()))
    if APIOSRS.RL_GetWintertodtTimer() == 0 then-- 0 game is going on
        if APIOSRS.RL_GetWintertodtWarmth() < 600 then
            APIOSRS.RL_ClickEntity(93, foods)
            API.RandomSleep2(300, 1000, 2000)
        end
        if API.Dist_FLP(near_brazier) < 3 then
            if Inventory:Contains(hammer) then
                if APIOSRS.RL_ClickEntity(0, {brazier_broken} , 4) then
                    print("repair")
                    API.RandomSleep2(300, 500, 2000)
                end
            end
            if APIOSRS.RL_ClickEntity(0, {brazier_light} , 4) then
                print("light")
                API.RandomSleep2(300, 500, 2000)
            end
            if (not API.CheckAnim(25)) then
                --full load, move to spot and start fletching
                if Inventory:Contains(bruma_root) and Inventory:Contains(knife) then
                    APIOSRS.RL_ClickEntity(93, {knife})
                    API.RandomSleep2(300, 500, 2000)
                    if APIOSRS.RL_IsWidgetSelected() then
                        APIOSRS.RL_ClickEntity(93, {bruma_root})
                        print("Fletching")
                        API.RandomSleep2(500, 1000, 2000)
                    else
                        print("Failed to select knife")
                    end
                end
                --start fireing, all are fletched
                if Inventory:Contains(bruma_kindling) and not Inventory:Contains(bruma_root) then
                    APIOSRS.RL_ClickEntity(0, {brazier_burning} , 4)
                    print("Feeding fire")
                    API.RandomSleep2(500, 1000, 2000)                    
                end
            end
        end
        if (not API.CheckAnim(25)) then
            if APIOSRS.RL_GetWintertodtTimer() == 0 then
                --shoulndt be
                if APIOSRS.RL_IsWidgetSelected() then
                    local rand = API.Math_RandomNumber(3)-1
                    APIOSRS.RL_ClickTile(near_brazier.x - rand,near_brazier.y,true)
                    print("Un-widget")
                end
                --get roots until full
                if not Inventory:Contains(bruma_kindling) and Inventory:Contains(knife) and not Inventory:IsFull() then
                    APIOSRS.RL_ClickEntity(0, roots, 10)
                    print("Chopin")
                    API.RandomSleep2(1500, 1000, 2000)
                end
                --Walk to brazier if full
                if Inventory:Contains(bruma_root) and Inventory:Contains(knife) and Inventory:IsFull() then
                    if API.Dist_FLP(near_brazier) > 3 then
                        print("Move next to brazier")
                        local rand = API.Math_RandomNumber(3)-1
                        APIOSRS.RL_ClickTile(near_brazier.x - rand,near_brazier.y,true)
                        API.RandomSleep2(900, 500, 2000)
                    end
                    API.RandomSleep2(1500, 1000, 2000)
                end    
            end 
        end
    end

    API.RandomSleep2(200, 677,3777)
end