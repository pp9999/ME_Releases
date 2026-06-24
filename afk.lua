local API = require("api")
print("Run Lua port fish script afker.")

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    print("Loop")
    if API.WaitUntilMovingandAnimEnds(4,2) then
        if API.Buffbar_GetIDstatus(51490,false).conv_text > 0 then
            if not Inventory:IsFull() then
            local obj = API.ReadAllObjectsArray({1}, {25220}, {})
            if #obj > 0 then
                API.DoAction_NPC__Direct(0x3c, API.OFF_ACT_InteractNPC_route, obj[1])
                API.MarkTiles({obj[1].Tile_XYZ},0,0,2,false,false,WPOINT.new(0,0,0),WPOINT.new(0,0,0))
                API.RandomSleep2(1600, 4300, 300)
                print("Fishin")
            end
            end
        end
    end

API.RandomSleep2(8600, 2300, 300)
end