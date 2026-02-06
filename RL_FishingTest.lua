local API = require("api")
local APIOSRS = require("apiosrs")

while API.Read_LoopyLoop() do

    if not API.CheckAnim(100) then
        APIOSRS.RL_ClickEntity(1, { 1519})
    end
    print("Test:".. tostring(Inventory:IsFull()))

    API.RandomSleep2(5500, 777,777)
end