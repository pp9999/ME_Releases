local API = require("api")
print("Run afker.")

--Flies 32766,32767,32768,32769
--trees VP 12768
--mid 3512,1644 60851 = 1 aka true
--east upper 3546,1659 60850 = 1
--east lower 3558,1621 60849 = 1
--west upper 3488,1681 60852 = 1
API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    if not API.CheckAnim(10) and not API.ReadPlayerMovin2() then
        if not Inventory:IsFull() then
            API.DoAction_NPC(0x2a,API.OFF_ACT_InteractNPC_route,{ 32769,32768,32767,32766 },20)
            API.RandomSleep2(1000, 300, 400)     
        end
    end
    
API.RandomSleep2(1000, 3000, 4000)
end