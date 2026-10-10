local API = require("api")
local APIOSRS = require("apiosrs")



while API.Read_LoopyLoop() do
   
APIOSRS.DoAction_Interface2(149, 0, 1, 3, 1331)


    API.RandomSleep2(700, 1777,12777)
    API.Write_LoopyLoop(false)
end