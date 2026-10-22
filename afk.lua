local API = require("api")
print("Run Lua port fish script afker.")


API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()

if API.StarPathReachable() then
    API.DoAction_NPC(0xc8,API.OFF_ACT_InteractNPC_route,{ 25540 },50)
end

API.RandomSleep2(1000, 3000, 4000)
API.Write_LoopyLoop(false)
end