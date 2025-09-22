local API = require("api")


local function isOnFire(bush)
    local fireBushes = API.GetAllObjArray1({3952}, 30, {4})
    for j = 1, #fireBushes do
        if bush.TileX == fireBushes[j].TileX and bush.TileY == fireBushes[j].TileY then
            return true
        end
    end
    return false
end

API.SetMaxIdleTime(10)
API.SetDrawTrackedSkills(true)
API.Write_LoopyLoop(true)
while(API.Read_LoopyLoop() and API.PlayerLoggedIn())
do-----------------------------------------------------------------------------------

    math.randomseed(os.time())

    if not API.PInArea21(2388, 2421, 3358, 3388) then
        local random = math.random(-4, 4)
        API.DoAction_Tile(WPOINT.new(2403 + random,3373 + random,0))
        API.RandomSleep2(3000, 600, 600)
    end
    

    local shakingBushes = API.GetAllObjArray1({26808}, 30, {0})
    
    if #shakingBushes > 0 and API.InvItemFound1(19805) then
        for i = 1, #shakingBushes do
            if (API.Mem_Read_int(shakingBushes[i].Mem + 0x2F4) ~= 0) and not isOnFire(shakingBushes[i]) then
                API.DoAction_Object2(0x2a,API.OFF_ACT_GeneralObject_route0,{ shakingBushes[i].Id },50,WPOINT.new(shakingBushes[i].TileX / 512,shakingBushes[i].TileY / 512,0))
                API.RandomSleep2(600, 100, 200)
                break
            end
        end
    end

    
    if API.GetAllObjArray1({19807}, 20, {3})[1] ~= nil and API.GetAllObjArray1({2827}, 20, {5})[1] == nil then
        API.DoAction_G_Items_r2(0x42, 2416, { 19807 }, 30, FFPOINT.new(0, 0, 0), 0)
        API.RandomSleep2(1200, 600, 600)
    end
    local sprites = API.GetAllObjArray1({12342, 12343, 12344}, 20, {1})
    if #sprites > 0 then
        for i = 1, #sprites do
            API.DoAction_NPC(0xa7,API.OFF_ACT_InteractNPC_route,{ sprites[i].Id },50)
            API.RandomSleep2(600, 100, 100)
        end

    end
    
    API.DoRandomEvents()
    API.RandomSleep2(250, 100, 200)
end----------------------------------------------------------------------------------
