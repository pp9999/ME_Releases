local API = require("api")
local APIOSRS = require("apiosrs")


local NPCs = {5553} --
local currentfail = 0
while API.Read_LoopyLoop() do
    
    local countloops = 0
    while (API.CheckAnim(20) or API.ReadPlayerMovin()) and API.Read_LoopyLoop() do
        countloops = countloops + 1
        if countloops > 500 then
            print("Stuck in animation, stopping script")
            API.Write_LoopyLoop(false)
        end
        API.RandomSleep2(200, 1000, 2000)
    end

    if not API.ReadPlayerMovin() then
        APIOSRS.RL_ClickEntity(1, NPCs, 20 )
        API.RandomSleep2(200, 1000, 2000)
    end
    API.RandomSleep2(700, 1777,12777)
end