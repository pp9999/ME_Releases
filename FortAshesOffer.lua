local API = require("api")
print("Run Lua.")

--set ashes onto Load last preset
local ashes = { 20268 }
API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()

    if not API.ReadPlayerMovin() then
        if not API.CheckAnim(80) then
            if Inventory:Contains(ashes) then
                API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route2,{ 114831 },10);           
                API.RandomSleep2(3000, 300, 400)
            else
                API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route3,{ 125115 },10);           
                API.RandomSleep2(3000, 300, 400)
                while API.ReadPlayerMovin() do
                    API.RandomSleep2(30, 30, 40)
                end
                API.RandomSleep2(500, 300, 400)
                if not Inventory:Contains(ashes) then
                    print("No ashes in bank")
                    API.Write_LoopyLoop(false)
                end
            end
        end
    end
 
API.RandomSleep2(1000, 1000, 4000)
end