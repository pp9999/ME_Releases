local API = require("api")
local APIOSRS = require("apiosrs")


local NPCs = {3887}
local Demon_NPCs = {2025, 2026, 2027, 2028, 2029}
local Rat_NPCs = {4501}
local FireGiant_NPCs = {7251,7252}
local bloodveld_NPCs = {7398,7276}
local ITEMs = {
25419,995,--specific items
365,378,379,384,385,--foods
554,555,556,557,558,559,--shity runes
560,561,562,563,564,565,566,--runes
30105,30107,985,987,1623,1621,1619,1617,--gems
207,209,211,213,215,217,219,2485,3051,--herbs
5231,22879,5295,5296,5297,5298,5299,5300,5301,5302,5303,5304,--seeds
23083,11037,--obscure items
24361,24362,24363,24364,24365,24366,--clue scrolls
1373,1333,1147,--high alchables
1369,1181,1159,1121,1111,--low value high alchables
13474,13495,--ensouled
19677,19679,19681,19683,19685,--ancient shards
892--arrows
}
local FOODs = {365}
local PRAYPOTs = {143,141,139,2434}
local currentfail_pickup = 0
local currentfail_npcs = 0
local currentfail_cant_tether = 0
local tetherpoint = API.PlayerCoordfloat()
local itemtoalch = {2504,1150,1128,1114,3055,1360,1202,3055,1378,1348,1404,1374,1334,1402,1094,1320
,3055,3203,1164,1124,1214,1186,1306,1080,1433,9432,71,2500,1373,1333,1147,1369,1181,1159,1121,1111}
local ensouled_heads = {13474,13495}
::start::
while API.Read_LoopyLoop() do

    if currentfail_pickup > 50 then
        API.Write_LoopyLoop(false)
        print("currentfail_pickup >, stopping script")
    end
    if currentfail_npcs > 50 then
        API.Write_LoopyLoop(false)
        print("currentfail_npcs >, stopping script")
    end
    if currentfail_cant_tether > 50 then
        API.Write_LoopyLoop(false)
        print("currentfail_cant_tether >, stopping script")
    end

    if API.GetHPrecent() < 70 then
        APIOSRS.RL_OpenTab(3)
        if APIOSRS.RL_GetOpenTab() == 3 then
            APIOSRS.RL_ClickEntity(93, FOODs)
            print("Eat foods")
        end
    end

    if API.GetPrayPrecent() < 40 then
        APIOSRS.RL_OpenTab(3)
        if APIOSRS.RL_GetOpenTab() == 3 then
            APIOSRS.RL_ClickEntity(93, PRAYPOTs)
            print("Drink")
        end
    end

    if Inventory:Contains(ensouled_heads) and Inventory:Contains({19634}) then
        APIOSRS.RL_OpenTab(3)
        if APIOSRS.RL_GetOpenTab() == 3 then
            APIOSRS.RL_ClickEntity(93, {19634})
            print("Banking ensouled heads")
            currentfail_pickup = currentfail_pickup +1
            API.RandomSleep2(200, 1000, 2000)
        end
    end

    ::highstart::
    if Inventory:Contains(itemtoalch) and Inventory:Contains({561}) and 
    (Inventory:Contains({554}) or Inventory:Contains({12791})) then
        if APIOSRS.RL_GetOpenTab() ~= 6 then
            APIOSRS.RL_OpenTab(6)
            print("wrong tab, opening spellbook")
            API.RandomSleep2(2000, 100, 200)
        end
        if APIOSRS.RL_GetOpenTab() == 6 then
            if not APIOSRS.RL_IsWidgetSelected() then
                APIOSRS.RL_ClickSpellbook("High Level Alchemy",0)
                print("high alch")
                API.RandomSleep2(500, 1000, 2000)
            else
                APIOSRS.RL_OpenTab(3)
                print("spell already selected")
                API.RandomSleep2(2000, 1000, 2000)
            end
        end
        if APIOSRS.RL_GetOpenTab() == 3 then
            if APIOSRS.RL_IsWidgetSelected() then
                APIOSRS.RL_ClickEntity(93, itemtoalch )
                print("clicking item")
                API.RandomSleep2(200, 1000, 2000)
                if APIOSRS.RL_GetOpenTab() ~= 3 then
                    APIOSRS.RL_OpenTab(3)
                    API.RandomSleep2(500, 1000, 2000)
                end
                if Inventory:Contains(itemtoalch) and Inventory:Contains({561}) and 
                (Inventory:Contains({554}) or Inventory:Contains({12791})) then
                    goto highstart
                end
            end
        end
    end

    --check location, if too far away walk back to tether point
    if API.Dist_FLP(tetherpoint) > 15 then
        local rand_x = math.random(-2,2)
        local rand_y = math.random(-2,2)
        APIOSRS.RL_ClickTile(tetherpoint.x + rand_x,tetherpoint.y + rand_y,true)
        print("Walking back to tether point")
        API.RandomSleep2(7200, 1000, 2000)
    end

    if not API.ReadPlayerMovin() and not Inventory:IsFull() then
        --check ground for items
        if APIOSRS.RL_ClickEntity(3, ITEMs, 5 ) then
            print("Picking up items")
            currentfail_npcs = 0
            currentfail_pickup = currentfail_pickup +1
            API.RandomSleep2(700, 1000, 2000)
            goto start
        end
    end

    if not API.CheckAnim(50) and not API.ReadPlayerMovin() then
        APIOSRS.RL_ClickEntity(1, bloodveld_NPCs, 15 )
        print("Npcs murder")
        currentfail_pickup = 0;
        currentfail_cant_tether = 0
        currentfail_npcs = currentfail_npcs +1
        API.RandomSleep2(400, 1000, 2000)
    end
 

    if API.GetHPrecent() < 30 then
        APIOSRS.RL_ClickEntity(93, {13114} )
        API.RandomSleep2(700, 100, 200)
        API.Write_LoopyLoop(false)
        print("Teleporting out")
    end
    
    API.RandomSleep2(700, 1777,12777)
end