local API = require("api")
print("Run Lua port fish script afker.")

while API.Read_LoopyLoop() do
    API.DoRandomEvents()

    if API.WaitUntilMovingandAnimEnds(4,2) then
        if API.Buffbar_GetIDstatus(51490,false).conv_text > 0 then
            local obj = API.ReadAllObjectsArray({1}, {25220}, {})
            if #obj > 0 then
                API.DoAction_NPC__Direct(0x3c, API.OFF_ACT_InteractNPC_route, obj[1])
                API.MarkTiles({obj[1].Tile_XYZ},0,0,2,false,false,WPOINT.new(0,0,0),WPOINT.new(0,0,0))
                API.RandomSleep2(1600, 4300, 300)
                print("Fishin")
            end
        end
    end
    --local OBJECTS_table = API.ReadAllObjectsArray({-1},{-1},{})

    local obj = API.ReadAllObjectsArray({12}, {66875}, {})
    if #obj > 0 then
        local freetiles = API.Math_FreeTiles({obj[1].Tile_XYZ},1,10,{},true)
        if #freetiles > 0 then
            print("ClosestTile" .. tostring(freetiles[1].x) .. "," .. tostring(freetiles[1].y))
        end
    end
    print("Inventory:IsFull():" .. tostring(Inventory:IsFull()))
    print("Inventory:IsEmpty():" .. tostring(Inventory:IsEmpty()))
    print("Inventory:Invfreecount():" .. tostring(Inventory:Invfreecount()))
    print("Inventory:Contains():" .. tostring(Inventory:Contains(44472)))   

API.RandomSleep2(600, 7300, 300)
end