local API = require("api")
print("Run Lua port fish script afker.")

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    print("Loop")
    if API.WaitUntilMovingandAnimEnds(4,2) then
        --if API.Buffbar_GetIDstatus(51490,false).conv_text > 0 then
            if not Inventory:IsFull() then
            local obj = API.ReadAllObjectsArray({1}, {99}, {})
            if #obj > 0 then

                
                API.RandomSleep2(1600, 4300, 300)
                print("Fishin")
            end
            end
        --end
    end
    --API.DoAction_Inventory1(0x14c6,0,0,API.OFF_ACT_Bladed_interface_route)
    --API.RandomSleep2(5500, 300, 600)
    --API.DoAction_Object1(0x24,API.OFF_ACT_GeneralObject_route00,{8558},20)

    API.DoAction_DontResetSelection()
    API.DoAction_Ability("High level alchemy",0,API.OFF_ACT_Bladed_interface_route)
    API.RandomSleep2(800, 300, 600)
    API.DoAction_Inventory1(47315,0,0,API.OFF_ACT_GeneralInterface_route1)


API.RandomSleep2(12600, 3300, 4300)
end