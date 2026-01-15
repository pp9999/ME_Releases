local API = require("api")
print("Run Lua port fish script afker.")
API.TurnOffMrHasselhoff(true)
API.Write_fake_mouse_do(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    API.DoAction_Interface(0x2e,0xffffffff,1,906,95,-1,API.OFF_ACT_GeneralInterface_route)

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

    if not API.CheckAnim(120) then
        API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route0,{ 106598 },10)
        API.RandomSleep2(5400, 1300, 400)
        API.KeyboardPress31(0x20, 30, 80)
        if not Inventory:Contains(1511) then
            API.Write_LoopyLoop(false)
        end
    end
API.RandomSleep2(5600, 2300, 300)
end