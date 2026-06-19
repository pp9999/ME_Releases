local API = require("api")
local APIOSRS = require("apiosrs")


local NPCs = {6143}
local ITEMs = {25419,365}
local FOODs = {365}
local currentfail = 0
while API.Read_LoopyLoop() do

    print("Eat foods" .. tostring(API.GetHPrecent()))
    if API.GetHPrecent() < 70 then
        APIOSRS.RL_ClickEntity(93, FOODs)
        print("Eat foods")
    end

    if not API.CheckAnim(50) and not API.ReadPlayerMovin() and not Inventory:IsFull() then
        if not APIOSRS.RL_ClickEntity(3, ITEMs, 10 ) then
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