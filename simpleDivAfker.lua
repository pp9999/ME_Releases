local API = require("api")
print("Run Lua.")

API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()

    if not Inventory:IsFull() then
        API.DoAction_NPC(0x2a,API.OFF_ACT_InteractNPC_route,{ 18204,18205 },10)
        API.RandomSleep2(4000, 300, 400)
    end
    print(tostring(API.CheckAnim(100)) .. " " .. tostring(Inventory:IsFull()))
    if not API.CheckAnim(100) then
        if not Inventory:IsFull() then
            API.DoAction_NPC(0x2a,API.OFF_ACT_InteractNPC_route,{ 18159 },10)
        else
           API.DoAction_Object1(0xc8,API.OFF_ACT_GeneralObject_route0,{ 87306, 93489 },20);          
        end
        API.RandomSleep2(2000, 300, 400)
    end
 
API.RandomSleep2(1000, 3000, 4000)
end