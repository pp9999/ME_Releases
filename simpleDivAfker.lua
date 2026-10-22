local API = require("api")
print("Run Lua.")

--18204,18205 chronicle
--wisps 18150,18150,18151,18152,18153,18154,18155,18156,18157,18158,18159,18160,18161,18162,18163,18164
--springs 18173,18173,18174,18175,18176,18177,18178,18179,18180,18181,18182,18183,18184,18185,18186,18187
--crater 87306, 93489
API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()

    if not Inventory:IsFull() then
        API.DoAction_NPC(0x2a,API.OFF_ACT_InteractNPC_route,{ 18204,18205 },10)
        API.RandomSleep2(4000, 300, 400)
    end
    --print(tostring(API.CheckAnim(100)) .. " " .. tostring(Inventory:IsFull()))
    if not API.CheckAnim(100) then
        if not Inventory:IsFull() then
            API.DoAction_NPC(0x2a,API.OFF_ACT_InteractNPC_route,{ 18187,18164 },12)
              API.RandomSleep2(600, 300, 400)
              if not API.ReadPlayerMovin2() then
                if not API.CheckAnim(100) then
                    API.DoAction_NPC(0x2a,API.OFF_ACT_InteractNPC_route,{ 18186,18163 },12)
                end
            end
        else
           API.DoAction_Object1(0xc8,API.OFF_ACT_GeneralObject_route0,{ 87306, 93489 },10);          
        end
        API.RandomSleep2(2000, 300, 400)
    end
 
API.RandomSleep2(1000, 3000, 4000)
end