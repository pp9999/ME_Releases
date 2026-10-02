local API = require("api")
print("Run Lua.")

API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()

if not API.ReadPlayerMovin2() then
    local optimalbeam = API.ReadAllObjectsArray({0,12},{125061},{})
    if optimalbeam ~= nil and #optimalbeam > 0 then
        local firstbeam = optimalbeam[1];
        if firstbeam.Distance > 2 then
            API.DoAction_Object_Direct(0x29,API.OFF_ACT_GeneralObject_route0,firstbeam)
            print("Optimal construction spot has moved, clicking new")
            API.RandomSleep2(6000, 500, 2000)
        end
    else
        print("No beams found")
        API.RandomSleep2(1000, 3000, 4000)
    end
end

API.RandomSleep2(500, 500, 2000)
end