local API = require("api")
local MAX_IDLE_TIME_MINUTES = 5

API.SetDrawTrackedSkills(true)


API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do

    if API.InvItemcount_String("Dragon Bones") == 0 then

        API.DoAction_NPC(0x33,API.OFF_ACT_InteractNPC_route4,{ 1786 },50)

        API.RandomSleep2(1000, 2000, 2500)   
        repeat until API.WaitUntilMovingEnds(5,2)
            
        if API.Invfreecount_() == 28 then
            break
            print("Banking fail")
        end
    end
    
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route1,{ 122374 },50)


    repeat
        API.RandomSleep2(3000, 2000, 2500) 
        API.PIdle2()
    until API.WaitUntilMovingandAnimEnds(5,2)
    

end




