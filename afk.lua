local API = require("api")
print("Run Lua port fish script afker.")

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    print("Loop")
    if API.WaitUntilMovingandAnimEnds(4,2) then
        --if API.Buffbar_GetIDstatus(51490,false).conv_text > 0 then
            if not Inventory:IsFull() then
            local obj = API.ReadAllObjectsArray({1}, {14907}, {})
            if #obj > 0 then

                
                API.RandomSleep2(1600, 4300, 300)
                print("Fishin")
            end
            end
        --end
    end

API.RandomSleep2(55600, 12300, 63300)
end