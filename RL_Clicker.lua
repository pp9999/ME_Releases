local API = require("api")
local APIOSRS = require("apiosrs")


local NPCs = {2170,2169} --
local stalls = {51935}
local currentfail = 0
while API.Read_LoopyLoop() do
    
    local countloops = 0
    while (API.CheckAnim(200) or API.ReadPlayerMovin()) and API.Read_LoopyLoop() do
        countloops = countloops + 1
        if countloops > 500 then
            print("Stuck in animation, stopping script")
            API.Write_LoopyLoop(false)
        end
        API.RandomSleep2(200, 1000, 2000)
    end

    if not API.ReadPlayerMovin() and not Inventory:IsFull() then
        --APIOSRS.RL_ClickEntity(1, NPCs, 15 )
        APIOSRS.RL_ClickEntity(0, stalls, 5 )
        API.RandomSleep2(200, 1000, 2000)
    end
    API.RandomSleep2(700, 1777,12777)
end