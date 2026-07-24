local API = require("api")
local APIOSRS = require("apiosrs")

print("Run Lua")

API.Write_LoopyLoop(true)

TestingApiType = 0

while(API.Read_LoopyLoop())
do
    if TestingApiType == 0 then
        local success = APIOSRS.RL_ClickEntity(1, {1634}, 25)
        print(success)
    elseif TestingApiType == 1 then
        local success = API.RL_ClickEntity(1, {1634}, 25)
        print(success)
    elseif TestingApiType == 2 then
        local success = RL_ClickEntity(1, {1634}, 25)
        print(success)
    end
    break
end