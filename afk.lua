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
    --API.RandomSleep2(500, 300, 600)
    --API.DoAction_Object1(0x24,API.OFF_ACT_GeneralObject_route00,{66573},20)

API.RandomSleep2(55600, 12300, 63300)
end