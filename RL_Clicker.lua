local API = require("api")
local APIOSRS = require("apiosrs")


local NPCs = {2098,2099,2100,2101,2102,2103} --
local currentfail = 0
while API.Read_LoopyLoop() do
    
    local countloops = 0
    while (API.CheckAnim(50) or API.ReadPlayerMovin()) and API.Read_LoopyLoop() do
        countloops = countloops + 1
        if countloops > 500 then
            print("Stuck in animation, stopping script")
            API.Write_LoopyLoop(false)
        end
        API.RandomSleep2(200, 1000, 2000)
    end
    if API.ReadPlayerMovin() then
        API.RandomSleep2(2000, 1000, 2000)
        APIOSRS.RL_ClickEntity(1, NPCs, 8 )
        API.RandomSleep2(2000, 1000, 2000)
    end
    API.RandomSleep2(4700, 1777,12777)
end