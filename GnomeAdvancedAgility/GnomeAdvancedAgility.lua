local API = require("api")

print("Run Lua script GnomeAdvancedAgility.")

local log_tile = FFPOINT.new(2480,3437,0)
local log_id = 69526
local net_tile = FFPOINT.new(2474,3429,0)
local net_id = 69383
local branch_tile = FFPOINT.new(2473,3423,0)
local branch_id = 69508
local branch2_tile = FFPOINT.new(2473,3420,0)
local branch2_id = 69506
local sign_tile = FFPOINT.new(2475,3419,0)
local sign_id = 69514
local swingpipes_tile = FFPOINT.new(2486,3419,0)
local swingpipes_id = 43529
local downpipe_tile = FFPOINT.new(2485,3432,0)
local downpipe_id = 69389

function DoRandomStuff()
    if (API.Math_RandomNumber(1000) > 990) then
        API.PIdle1()
    end
    API.DoRandomEvents()
    if (API.Math_RandomNumber(1000) > 990) then
        API.PIdle2()
    end 
end
function PrintAtEnd()
    local currentXp = API.GetSkillXP("AGILITY")
    diffXp = math.abs(currentXp - startXp)
    local elapsedMinutes = (os.time() - startTime) / 60
    xpPH = ((diffXp * 60) / elapsedMinutes)
    print("Total xps  " .. tostring(diffXp))
    print("Xps per hour  " .. tostring(xpPH))
    print("End")
end

API.SetDrawTrackedSkills(true)
--main loop
while(API.Read_LoopyLoop())
do-----------------------------------------------------------------------------------
DoRandomStuff()
if (API.Dist_FLP(log_tile) < 7 and API.GetFloorLv_2() == 0) then
    API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ log_id },15);
    API.RandomSleep2(600, 1050, 5000)
    API.WaitUntilMovingandAnimEnds(15,2)
end
DoRandomStuff()
if (API.Dist_FLP(net_tile) < 5 and API.GetFloorLv_2() == 0) then
    API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ net_id },10);
    API.RandomSleep2(600, 1050, 5000)
    API.WaitUntilMovingandAnimEnds(15,2)
end
DoRandomStuff()
if (API.Dist_FLP(branch_tile) < 5 and API.GetFloorLv_2() == 1) then
    API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ branch_id },10);
    API.RandomSleep2(600, 1050, 5000)
    API.WaitUntilMovingandAnimEnds(15,2)
end
DoRandomStuff()
if (API.Dist_FLP(branch2_tile) < 5 and API.GetFloorLv_2() == 2) then
    API.DoAction_Object1(0x34,API.OFF_ACT_GeneralObject_route0,{ branch2_id },10);
    API.RandomSleep2(600, 1050, 5000)
    API.WaitUntilMovingandAnimEnds(15,2)
end
DoRandomStuff()
if (API.Dist_FLP(sign_tile) < 5 and API.GetFloorLv_2() == 3) then
    API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ sign_id },10);
    API.RandomSleep2(600, 1050, 5000)
    API.WaitUntilMovingandAnimEnds(15,2)
end
DoRandomStuff()
if (API.Dist_FLP(swingpipes_tile) < 5 and API.GetFloorLv_2() == 3) then
    API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ swingpipes_id },10);
    API.RandomSleep2(600, 1050, 5000)
    API.WaitUntilMovingandAnimEnds(15,2)
end
DoRandomStuff()
if (API.Dist_FLP(downpipe_tile) < 5 and API.GetFloorLv_2() == 3) then
    API.DoAction_Object1(0xb5,API.OFF_ACT_GeneralObject_route0,{ downpipe_id },10);
    API.RandomSleep2(600, 1050, 5000)
    API.WaitUntilMovingandAnimEnds(15,2)
end
API.RandomSleep2(200, 1050, 12000)
end----------------------------------------------------------------------------------
PrintAtEnd()