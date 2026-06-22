local API = require("api")
local APIOSRS = require("apiosrs")


local NPCs = {517,516,11952,11953}
local ITEMs = {
25419,
365,379,385,
560,561,562,563,564,565,
985,987,1623,1621,1619,1617,
207,209,211,213,215,217,219,2485,3051,
5231,22879,
5295,5296,5297,5298,5299,5300,5301,5302,5303,5304
}
local FOODs = {365}
local currentfail = 0
local tetherpoint = API.PlayerCoordfloat()
while API.Read_LoopyLoop() do

    if API.GetHPrecent() < 70 then
        APIOSRS.RL_ClickEntity(93, FOODs)
        print("Eat foods")
    end

    if not API.CheckAnim(50) and not API.ReadPlayerMovin() and not Inventory:IsFull() then
        --check ground for items, if found click on them, else click on NPCs
        if not APIOSRS.RL_ClickEntity(3, ITEMs, 10 ) then
            --check location, if too far away walk back to tether point
            if API.Dist_FLP(tetherpoint) > 15 then
                local rand_x = math.random(-2,2)
                local rand_y = math.random(-2,2)
                APIOSRS.RL_ClickTile(tetherpoint.x + rand_x,tetherpoint.y + rand_y,true)
                print("Walking back to tether point")
                API.RandomSleep2(7200, 1000, 2000)
            end
            APIOSRS.RL_ClickEntity(1, NPCs, 25 )
            API.RandomSleep2(200, 1000, 2000)
        end
    end

    if Inventory:IsFull() or API.GetHPrecent() < 40 then
        APIOSRS.RL_ClickEntity(93, {13114} )
        API.RandomSleep2(700, 100, 200)
        API.Write_LoopyLoop(false)
        print("Teleporting out")
    end
    
    API.RandomSleep2(700, 1777,12777)
end