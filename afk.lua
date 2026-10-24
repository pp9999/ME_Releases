local API = require("api")
print("Run Lua port fish script afker.")

local prev_xp_check = 0
local loopsofnoxp_check = 0
API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents(true)
    if (prev_xp_check ~= API.GatherEvents_xp_check()) then
        prev_xp_check = API.GatherEvents_xp_check()
        loopsofnoxp_check = 0
    else
        loopsofnoxp_check = loopsofnoxp_check + 1
    end
    if (loopsofnoxp_check > 3) then
        API.Write_LoopyLoop(false)
    end

    if not API.CheckAnim(100) then
        if Inventory:Contains(1517) then
            API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route0,{ 134174,134175,134176,134177,134178 },50);
            API.RandomSleep2(5000, 300, 400)
        else
            API.DoAction_Object1(0x41,API.OFF_ACT_GeneralObject_route3,{ 131378 },50);
            API.RandomSleep2(5000, 300, 400)

        end
    end

API.RandomSleep2(1000, 3000, 4000)
--API.Write_LoopyLoop(false)
end