local API = require("api")
local APIOSRS = require("apiosrs")


local stars = {41229,41228,41227,41226,41225,41224,41223,41222,41221}
while API.Read_LoopyLoop() do
    if (not API.CheckAnim(30)) then
        print("afk")
        if APIOSRS.RL_ClickEntity(0, stars, 6) then
            print("Mine")
            API.RandomSleep2(300, 500, 2000)
        end
    end
    API.RandomSleep2(1700, 1777,12777)
end