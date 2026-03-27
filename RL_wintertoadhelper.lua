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
while API.Read_LoopyLoop() do
    print("RL_GetWintertodtTimer:" .. tostring(APIOSRS.RL_GetWintertodtTimer()))
    print("RL_GetWintertodtWarmth:" .. tostring(APIOSRS.RL_GetWintertodtWarmth()))

    if API.Dist_FLP(near_brazier) < 3 then
        if Inventory:Contains(bruma_root) or Inventory:Contains(bruma_kindling) then
            if APIOSRS.RL_ClickEntity(0, {brazier_light} , 4) then
                print("light")
                API.RandomSleep2(300, 1000, 2000)
            end
        end
        if Inventory:Contains(hammer) then
            if APIOSRS.RL_ClickEntity(0, {brazier_broken} , 4) then
                print("repair")
                API.RandomSleep2(300, 1000, 2000)
            end
        end
        if (not API.CheckAnim(30) and not API.ReadPlayerMovin()) then
            if Inventory:Contains(bruma_root) and Inventory:Contains(knife) then
                APIOSRS.RL_ClickEntity(93, {knife})
                API.RandomSleep2(300, 500, 2000)
                APIOSRS.RL_ClickEntity(93, {bruma_root})
                print("Fletching")
                API.RandomSleep2(500, 1000, 2000)
            end
            if Inventory:Contains(bruma_kindling) and not Inventory:Contains(bruma_root) then
                APIOSRS.RL_ClickEntity(0, {brazier_burning} , 4)
                print("Feeding fire")
                API.RandomSleep2(500, 1000, 2000)
            end
        end
    end





    API.RandomSleep2(1700, 1777,10777)
end